import { createHash, randomUUID, X509Certificate } from "node:crypto";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { encryptFiscalSecret } from "@/lib/fiscal/secretStorage";
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
    const metadata = this.readCertificateMetadata(input.certificatePem);
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
    const { error } = await supabaseAdmin.from("certificate_history").insert({
      org_id: input.orgId,
      device_id: input.deviceUuid,
      certificate_id: input.certificateId,
      event_type: "renewal_due",
      event_payload: { reason: input.reason ?? "certificate_expiry" } as never,
    } as never);
    if (error) throw new Error(error.message);
  }

  readCertificateMetadata(certificatePem: string) {
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
