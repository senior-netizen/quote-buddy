import type { FdmsEnv } from "@/lib/fiscal/zimra.server";

export type StoredCertificate = {
  id: string;
  deviceId: string;
  certificatePem: string;
  serialNumber: string | null;
  thumbprint: string;
  validFrom: string | null;
  validTo: string | null;
};

export class CertificateManager {
  private readonly renewalWindowMs = 30 * 24 * 60 * 60 * 1000;

  private async loadNodeCrypto() {
    return import("node:crypto");
  }

  private async loadNodeFs() {
    return import("node:fs/promises");
  }

  private async loadNodePath() {
    return import("node:path");
  }

  private async loadSupabaseAdmin() {
    const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
    return supabaseAdmin;
  }

  private async loadCsrGenerator() {
    const { CsrGenerator } = await import("@/lib/fiscal/CsrGenerator");
    return new CsrGenerator();
  }

  private async loadSecretStorage() {
    const { encryptFiscalSecret } = await import("@/lib/fiscal/secretStorage");
    return { encryptFiscalSecret };
  }

  readStartupConfig(env = process.env) {
    const fdmsEnv = (env.FDMS_ENV as FdmsEnv | undefined) ?? "test";
    return {
      fdmsEnv,
      apiBase: (env.FDMS_API_BASE?.replace(/\/+$/, "") ?? (fdmsEnv === "test" ? "https://fdmsapitest.zimra.co.zw" : "https://fdmsapi.zimra.co.zw")),
      deviceSerial: env.FDMS_DEVICE_SERIAL,
      deviceModel: env.FDMS_DEVICE_MODEL ?? "Server",
      companyName: env.FDMS_COMPANY_NAME,
      certDir: env.FDMS_CERT_DIR,
      caCert: env.FDMS_CA_CERT,
    };
  }

  async provisionTestCertificate() {
    const config = this.readStartupConfig();
    if (config.fdmsEnv !== "test") {
      console.info("[fdms-cert] Skipping certificate provisioning because FDMS_ENV is not test.");
      return { provisioned: false, reason: "not_test_environment" as const };
    }

    const missing = Object.entries({
      FDMS_API_BASE: config.apiBase,
      FDMS_DEVICE_SERIAL: config.deviceSerial,
      FDMS_COMPANY_NAME: config.companyName,
      FDMS_CERT_DIR: config.certDir,
    })
      .filter(([, value]) => !value)
      .map(([key]) => key);
    if (missing.length) {
      throw new Error(
        `FDMS test certificate provisioning is missing required environment variables: ${missing.join(", ")}`,
      );
    }

    const { mkdir } = await this.loadNodeFs();
    const { join } = await this.loadNodePath();
    const certPath = join(config.certDir!, "client.crt");
    const keyPath = join(config.certDir!, "client.key");
    await mkdir(config.certDir!, { recursive: true, mode: 0o700 });

    const existing = await this.readExistingCertificate(certPath, keyPath);
    if (existing?.status === "valid") {
      console.info("[fdms-cert] Existing FDMS client certificate is valid; skipping registration.");
      return { provisioned: false, reason: "valid_certificate_reused" as const, certificate: existing.metadata };
    }
    if (existing?.status === "expiring_soon") {
      console.info("[fdms-cert] Existing FDMS client certificate is within renewal window; requesting replacement.");
    } else if (existing?.status === "expired") {
      console.info("[fdms-cert] Existing FDMS client certificate is expired; requesting replacement.");
    } else {
      console.info("[fdms-cert] FDMS client certificate/key pair not found; requesting initial certificate.");
    }

    const privateKeyPem = await this.ensurePrivateKey(keyPath);
    const csrGenerator = await this.loadCsrGenerator();
    const csrPem = await csrGenerator.generateWithPrivateKey(
      {
        commonName: config.deviceSerial!,
        organizationName: config.companyName!,
        countryName: "ZW",
      },
      privateKeyPem,
    );

    const certificatePem = await this.requestCertificateWithRetry({
      apiBase: config.apiBase!,
      deviceSerial: config.deviceSerial!,
      deviceModel: config.deviceModel,
      companyName: config.companyName!,
      csrPem,
    });

    const metadata = await this.readCertificateMetadata(certificatePem);
    if (!metadata.validTo) throw new Error("FDMS registration succeeded but returned an invalid certificate.");
    await this.atomicWrite(certPath, certificatePem, 0o600);
    console.info("[fdms-cert] FDMS client certificate provisioned successfully.", {
      serialNumber: metadata.serialNumber,
      validTo: metadata.validTo,
    });
    return { provisioned: true, certificate: metadata };
  }

  async readExistingCertificate(certPath: string, keyPath: string) {
    const { readFile } = await this.loadNodeFs();
    const { createPrivateKey } = await this.loadNodeCrypto();
    const [certExists, keyExists] = await Promise.all([this.exists(certPath), this.exists(keyPath)]);
    if (!certExists || !keyExists) return null;
    const certificatePem = await readFile(certPath, "utf8");
    const privateKeyPem = await readFile(keyPath, "utf8");
    try {
      createPrivateKey(privateKeyPem);
    } catch {
      throw new Error(
        `Invalid private key at ${keyPath}. Replace it with a valid RSA private key or remove it so provisioning can create one.`,
      );
    }
    const metadata = await this.readCertificateMetadata(certificatePem);
    if (!metadata.validTo) throw new Error(`Invalid client certificate at ${certPath}. Remove it to request a replacement.`);
    const validToMs = Date.parse(metadata.validTo);
    if (validToMs <= Date.now()) return { status: "expired" as const, metadata };
    if (validToMs <= Date.now() + this.renewalWindowMs) return { status: "expiring_soon" as const, metadata };
    return { status: "valid" as const, metadata };
  }

  async ensurePrivateKey(keyPath: string) {
    const { readFile } = await this.loadNodeFs();
    const { createPrivateKey } = await this.loadNodeCrypto();
    if (await this.exists(keyPath)) {
      const privateKeyPem = await readFile(keyPath, "utf8");
      try {
        createPrivateKey(privateKeyPem);
      } catch {
        throw new Error(
          `Invalid private key at ${keyPath}. Fix or remove the file before FDMS certificate provisioning can continue.`,
        );
      }
      return privateKeyPem;
    }
    const { generateKeyPairSync } = await this.loadNodeCrypto();
    const { privateKey } = generateKeyPairSync("rsa", {
      modulusLength: 2048,
      publicExponent: 0x10001,
      privateKeyEncoding: { type: "pkcs8", format: "pem" },
      publicKeyEncoding: { type: "spki", format: "pem" },
    });
    await this.atomicWrite(keyPath, privateKey, 0o600);
    console.info("[fdms-cert] Generated new 2048-bit RSA private key for FDMS provisioning.");
    return privateKey;
  }

  private async requestCertificateWithRetry(input: {
    apiBase: string;
    deviceSerial: string;
    deviceModel: string;
    companyName: string;
    csrPem: string;
  }) {
    const transientStatuses = new Set([408, 425, 429, 500, 502, 503, 504]);
    let lastError: unknown;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        const res = await fetch(`${input.apiBase}/Device/v1/RegisterCertificate`, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json" },
          body: JSON.stringify({
            deviceSerialNo: input.deviceSerial,
            deviceModelName: input.deviceModel,
            companyName: input.companyName,
            csr: input.csrPem,
          }),
        });
        const text = await res.text();
        const body = this.parseResponseBody(text);
        if (!res.ok) {
          if (transientStatuses.has(res.status) && attempt < 3) {
            await this.sleep(attempt * 500);
            continue;
          }
          throw new Error(`FDMS registration failed with HTTP ${res.status}: ${this.safeErrorMessage(body)}`);
        }
        const certificatePem = this.extractCertificatePem(body);
        if (!certificatePem) throw new Error("FDMS registration response did not include a certificate PEM.");
        return certificatePem;
      } catch (error) {
        lastError = error;
        if (attempt < 3 && this.isTransientNetworkError(error)) {
          await this.sleep(attempt * 500);
          continue;
        }
        throw error;
      }
    }
    throw new Error(
      `FDMS registration failed after retries: ${lastError instanceof Error ? lastError.message : "unknown error"}`,
    );
  }

  private async atomicWrite(path: string, contents: string, mode: number) {
    const { rename, writeFile } = await this.loadNodeFs();
    const tmpPath = `${path}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(tmpPath, contents, { mode });
    await rename(tmpPath, path);
  }

  private async exists(path: string) {
    const { stat } = await this.loadNodeFs();
    return stat(path).then(() => true, () => false);
  }

  private parseResponseBody(text: string): unknown {
    try {
      return text ? JSON.parse(text) : undefined;
    } catch {
      return text;
    }
  }

  private extractCertificatePem(body: unknown): string | null {
    if (typeof body === "string" && body.includes("BEGIN CERTIFICATE")) return body;
    if (!body || typeof body !== "object") return null;
    const record = body as Record<string, unknown>;
    for (const key of ["certificatePem", "certificate", "clientCertificate", "certPem"]) {
      const value = record[key];
      if (typeof value === "string" && value.includes("BEGIN CERTIFICATE")) return value;
    }
    return null;
  }

  private safeErrorMessage(body: unknown) {
    if (typeof body === "string") return body.slice(0, 300);
    if (body && typeof body === "object") {
      const record = body as Record<string, unknown>;
      return String(record.title ?? record.message ?? record.error ?? "Registration request was rejected.");
    }
    return "Registration request was rejected.";
  }

  private isTransientNetworkError(error: unknown) {
    return (
      error instanceof TypeError ||
      (error instanceof Error && /ECONNRESET|ETIMEDOUT|ENOTFOUND|EAI_AGAIN/i.test(error.message))
    );
  }

  private sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async storeIssuedCertificate(input: {
    orgId: string;
    deviceUuid: string;
    fdmsDeviceId: string;
    environment: FdmsEnv;
    certificatePem: string;
    csrPem?: string | null;
    issuedBy?: string | null;
    response?: unknown;
  }): Promise<StoredCertificate> {
    const { randomUUID } = await this.loadNodeCrypto();
    const { encryptFiscalSecret } = await this.loadSecretStorage();
    const supabaseAdmin = await this.loadSupabaseAdmin();
    const metadata = await this.readCertificateMetadata(input.certificatePem);
    const certificateId = randomUUID();

    const { data, error } = await supabaseAdmin
      .from("device_certificates")
      .insert({
        id: certificateId,
        org_id: input.orgId,
        device_id: input.deviceUuid,
        fdms_device_id: input.fdmsDeviceId,
        environment: input.environment,
        certificate_pem: null,
        encrypted_payload: await encryptFiscalSecret(input.certificatePem),
        key_id: "server-managed",
        thumbprint: metadata.thumbprint,
        active: true,
        certificate_serial_number: metadata.serialNumber,
        certificate_thumbprint: metadata.thumbprint,
        valid_from: metadata.validFrom,
        valid_to: metadata.validTo,
        csr_pem: input.csrPem,
        issued_by: input.issuedBy,
        fdms_response: input.response as never,
      } as never)
      .select("*")
      .single();
    if (error) throw new Error(error.message);

    await supabaseAdmin.from("certificate_history").insert({
      org_id: input.orgId,
      device_id: input.deviceUuid,
      certificate_id: certificateId,
      event_type: "issued",
      event_payload: { thumbprint: metadata.thumbprint, validTo: metadata.validTo } as never,
    } as never);

    return {
      id: String((data as Record<string, unknown>).id),
      deviceId: input.deviceUuid,
      certificatePem: input.certificatePem,
      serialNumber: metadata.serialNumber,
      thumbprint: metadata.thumbprint,
      validFrom: metadata.validFrom,
      validTo: metadata.validTo,
    };
  }

  async recordRenewalDue(input: { orgId: string; deviceUuid: string; certificateId: string; reason?: string }) {
    const supabaseAdmin = await this.loadSupabaseAdmin();
    const { error } = await supabaseAdmin.from("certificate_history").insert({
      org_id: input.orgId,
      device_id: input.deviceUuid,
      certificate_id: input.certificateId,
      event_type: "renewal_due",
      event_payload: { reason: input.reason ?? "certificate_expiry" } as never,
    } as never);
    if (error) throw new Error(error.message);
  }

  async readCertificateMetadata(certificatePem: string) {
    const { createHash, X509Certificate } = await this.loadNodeCrypto();
    try {
      const cert = new X509Certificate(certificatePem);
      return {
        serialNumber: cert.serialNumber || null,
        thumbprint: cert.fingerprint256.replace(/:/g, "").toLowerCase(),
        validFrom: new Date(cert.validFrom).toISOString(),
        validTo: new Date(cert.validTo).toISOString(),
      };
    } catch {
      return {
        serialNumber: null,
        thumbprint: createHash("sha256").update(certificatePem).digest("hex"),
        validFrom: null,
        validTo: null,
      };
    }
  }
}
