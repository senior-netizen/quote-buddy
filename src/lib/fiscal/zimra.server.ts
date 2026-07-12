/**
 * Thin client for the ZIMRA FDMS (Fiscalisation Data Management System) API.
 *
 * Two environments:
 *   test → https://fdmsapitest.zimra.co.zw
 *   prod → https://fdmsapi.zimra.co.zw
 *
 * IMPORTANT — mTLS:
 * The FDMS API requires a client TLS certificate issued to the device
 * (loaded through encrypted fiscal secret storage, never plaintext database columns).
 * On Cloudflare Workers, outbound mTLS is provided via the platform-level
 * `mtls_certificates` binding named `ZIMRA_FDMS_MTLS_CERT`. If neither that
 * binding nor Node-compatible decrypted PEM material is available, this module
 * fails closed before any FDMS network request is attempted.
 *
 * This module keeps the request/response shapes and payload builders
 * portable so the transport can be swapped without touching business logic.
 */

const ENDPOINTS = {
  test: "https://fdmsapitest.zimra.co.zw",
  prod: "https://fdmsapi.zimra.co.zw",
} as const;

export type FdmsEnv = "test" | "prod";

export type FdmsDevice = {
  deviceId: string;
  deviceSerialNo: string | null;
  activationKey: string | null;
  certificatePem: string | null;
  privateKeyPem: string | null;
};

export type FdmsTaxpayerVerificationRequest = {
  taxpayerTin: string;
  vatNumber?: string | null;
};

export type FdmsTaxpayerVerificationResponse = {
  taxpayerTin?: string;
  taxpayerName?: string;
  vatNumber?: string;
  tradeName?: string;
  isValid?: boolean;
} & Record<string, unknown>;

export type FdmsDeviceRegistrationRequest = {
  taxpayerTin: string;
  vatNumber?: string | null;
  deviceSerialNo: string;
  deviceModelName?: string;
  deviceModelVersion?: string;
  deviceBranchName?: string | null;
};

export type FdmsDeviceRegistrationResponse = {
  deviceId?: string | number;
  deviceSerialNo?: string;
  activationKey?: string;
} & Record<string, unknown>;

export type FdmsCertificateIssueRequest = {
  deviceId: string;
  activationKey: string;
  csr: string;
};

export type FdmsCertificateIssueResponse = {
  certificatePem?: string;
  certificate?: string;
  serialNumber?: string;
  thumbprint?: string;
  validFrom?: string;
  validTo?: string;
} & Record<string, unknown>;

export type FdmsError = {
  status: number;
  code?: string;
  message: string;
  raw?: unknown;
};

export type FdmsResult<T> = { ok: true; data: T } | { ok: false; error: FdmsError };

function baseUrl(env: FdmsEnv): string {
  return ENDPOINTS[env];
}

const CLOUDFLARE_MTLS_BINDING = "ZIMRA_FDMS_MTLS_CERT";
const FDMS_CA_CERT_ENV = "FDMS_CA_CERT";

type CloudflareMtlsBinding = {
  fetch: typeof fetch;
};

type FdmsTransport = {
  fetch(url: string, init: RequestInit): Promise<Response>;
};

function mtlsErrorResponse(code: string, detail: string): Response {
  return new Response(
    JSON.stringify({
      title: "ZIMRA FDMS mTLS is not configured",
      detail,
      code,
    }),
    { status: 495, headers: { "Content-Type": "application/json" } },
  );
}

function missingClientCertificateResponse(): Response {
  return mtlsErrorResponse(
    "FDMS_CLIENT_CERT_MISSING",
    "No client certificate found. Attempting automatic registration... FDMS requests that require mTLS cannot be sent until ZIMRA issues and stores a client certificate for this device.",
  );
}

function missingPrivateKeyResponse(): Response {
  return mtlsErrorResponse(
    "FDMS_PRIVATE_KEY_MISSING",
    "Missing private key for the ZIMRA client certificate. Restore the encrypted device private key before FDMS requests can be sent.",
  );
}

function missingCaCertificateResponse(path: string): Response {
  return mtlsErrorResponse(
    "FDMS_CA_CERT_MISSING",
    `Missing ZIMRA CA certificate at ${path}. Configure ${FDMS_CA_CERT_ENV} before FDMS requests can be sent.`,
  );
}

function invalidCertificateResponse(): Response {
  return mtlsErrorResponse(
    "FDMS_CLIENT_CERT_INVALID",
    "Invalid ZIMRA client certificate. Re-issue the device certificate before FDMS requests can be sent.",
  );
}

function expiredCertificateResponse(validTo: string): Response {
  return mtlsErrorResponse(
    "FDMS_CLIENT_CERT_EXPIRED",
    `Expired ZIMRA client certificate (expired at ${validTo}). Re-issue the device certificate before FDMS requests can be sent.`,
  );
}

function unsupportedRuntimeMtlsResponse(): Response {
  return mtlsErrorResponse(
    "FDMS_MTLS_UNSUPPORTED_RUNTIME",
    `Unsupported runtime mTLS configuration. Configure the Cloudflare Workers mTLS binding ${CLOUDFLARE_MTLS_BINDING}, or run in Node with decrypted device certificate and private key PEM material plus ${FDMS_CA_CERT_ENV}.`,
  );
}

function asCloudflareMtlsBinding(value: unknown): CloudflareMtlsBinding | null {
  return value &&
    typeof value === "object" &&
    "fetch" in value &&
    typeof (value as { fetch?: unknown }).fetch === "function"
    ? (value as CloudflareMtlsBinding)
    : null;
}

async function cloudflareMtlsBinding(): Promise<CloudflareMtlsBinding | null> {
  const globalBinding = asCloudflareMtlsBinding(
    (globalThis as Record<string, unknown>)[CLOUDFLARE_MTLS_BINDING],
  );
  if (globalBinding) return globalBinding;

  const dynamicImport = new Function("specifier", "return import(specifier)") as (
    specifier: string,
  ) => Promise<{ env?: Record<string, unknown> }>;
  const workersModule = await dynamicImport("cloudflare:workers").catch(() => null);
  return asCloudflareMtlsBinding(workersModule?.env?.[CLOUDFLARE_MTLS_BINDING]);
}

function isNodeRuntime(): boolean {
  return (
    typeof process !== "undefined" &&
    Boolean(process.versions?.node) &&
    process.release?.name === "node"
  );
}

async function nodeMtlsFetch(
  url: string,
  init: RequestInit,
  device: FdmsDevice & { certificatePem: string; privateKeyPem: string },
  ca: string,
) {
  const { request } = await import("node:https");
  return await new Promise<Response>((resolve, reject) => {
    const headers = Object.fromEntries(new Headers(init.headers).entries());
    const req = request(
      url,
      {
        method: init.method ?? "GET",
        headers,
        cert: device.certificatePem,
        key: device.privateKeyPem,
        ca,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (chunk: Buffer | string) =>
          chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)),
        );
        res.on("end", () => {
          resolve(
            new Response(Buffer.concat(chunks), {
              status: res.statusCode ?? 0,
              statusText: res.statusMessage,
              headers: Object.fromEntries(
                Object.entries(res.headers)
                  .filter(
                    (entry): entry is [string, string | string[]] =>
                      typeof entry[1] === "string" || Array.isArray(entry[1]),
                  )
                  .map(([key, value]) => [key, Array.isArray(value) ? value.join(", ") : value]),
              ),
            }),
          );
        });
      },
    );
    req.on("error", reject);
    if (typeof init.body === "string" || init.body instanceof Uint8Array) {
      req.write(init.body);
    }
    req.end();
  });
}

type FdmsTransportResult =
  | { ok: true; transport: FdmsTransport }
  | { ok: false; response: Response };

async function nodeMtlsTransport(device: FdmsDevice): Promise<FdmsTransportResult> {
  const certificatePem = device.certificatePem?.trim();
  if (!certificatePem) return { ok: false, response: missingClientCertificateResponse() };

  const privateKeyPem = device.privateKeyPem?.trim();
  if (!privateKeyPem) return { ok: false, response: missingPrivateKeyResponse() };

  const { X509Certificate, createPrivateKey } = await import("node:crypto");
  try {
    const certificate = new X509Certificate(certificatePem);
    const expiresAt = Date.parse(certificate.validTo);
    if (Number.isFinite(expiresAt) && expiresAt <= Date.now()) {
      return { ok: false, response: expiredCertificateResponse(certificate.validTo) };
    }
    createPrivateKey(privateKeyPem);
  } catch {
    return { ok: false, response: invalidCertificateResponse() };
  }

  const caPath = process.env[FDMS_CA_CERT_ENV]?.trim();
  if (!caPath) return { ok: false, response: missingCaCertificateResponse(FDMS_CA_CERT_ENV) };

  const { readFile } = await import("node:fs/promises");
  let ca: string;
  try {
    ca = await readFile(caPath, "utf8");
  } catch {
    return { ok: false, response: missingCaCertificateResponse(caPath) };
  }
  if (!ca.trim()) return { ok: false, response: missingCaCertificateResponse(caPath) };

  return {
    ok: true,
    transport: {
      fetch: (url, init) =>
        nodeMtlsFetch(url, init, { ...device, certificatePem, privateKeyPem }, ca),
    },
  };
}

async function fdmsTransport(device: FdmsDevice): Promise<FdmsTransportResult> {
  const binding = await cloudflareMtlsBinding();
  if (binding) {
    return { ok: true, transport: { fetch: (url, init) => binding.fetch(url, init) } };
  }
  if (isNodeRuntime()) {
    return nodeMtlsTransport(device);
  }
  return { ok: false, response: unsupportedRuntimeMtlsResponse() };
}

async function fdmsFetch(
  env: FdmsEnv,
  path: string,
  init: RequestInit,
  device: FdmsDevice,
): Promise<Response> {
  const transport = await fdmsTransport(device);
  if (!transport.ok) return transport.response;

  const url = `${baseUrl(env)}${path}`;
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("Accept", "application/json");
  headers.set("DeviceModelName", "Server");
  headers.set("DeviceModelVersion", "v1");
  // Some FDMS endpoints accept the activation key as a bearer for OpenDay etc.
  if (device.activationKey) {
    headers.set("Authorization", `Bearer ${device.activationKey}`);
  }
  return await transport.transport.fetch(url, { ...init, headers });
}

async function fdmsActivationFetch(
  env: FdmsEnv,
  path: string,
  init: RequestInit,
  activationKey?: string | null,
): Promise<Response> {
  const url = `${baseUrl(env)}${path}`;
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("Accept", "application/json");
  headers.set("DeviceModelName", "Server");
  headers.set("DeviceModelVersion", "v1");
  if (activationKey) {
    headers.set("Authorization", `Bearer ${activationKey}`);
  }
  return await fetch(url, { ...init, headers });
}

async function parse<T>(res: Response): Promise<FdmsResult<T>> {
  const text = await res.text();
  let body: unknown = undefined;
  try {
    body = text ? JSON.parse(text) : undefined;
  } catch {
    body = text;
  }
  if (!res.ok) {
    const msg =
      body && typeof body === "object" && "title" in (body as Record<string, unknown>)
        ? String((body as Record<string, unknown>).title)
        : typeof body === "string"
          ? body
          : `FDMS request failed (${res.status})`;
    const code =
      body && typeof body === "object" && "code" in (body as Record<string, unknown>)
        ? String((body as Record<string, unknown>).code)
        : undefined;
    return {
      ok: false,
      error: { status: res.status, code, message: msg, raw: body },
    };
  }
  return { ok: true, data: body as T };
}

/** GET /Device/v1/{deviceID}/GetConfig — returns tax config, VAT number, etc. */
export async function getDeviceConfig(env: FdmsEnv, device: FdmsDevice) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/GetConfig`,
    { method: "GET" },
    device,
  );
  return parse<Record<string, unknown>>(res);
}

/** POST /Taxpayer/v1/Verify — verifies a taxpayer TIN/VAT registration before device onboarding. */
export async function verifyTaxpayer(env: FdmsEnv, payload: FdmsTaxpayerVerificationRequest) {
  const res = await fdmsActivationFetch(env, "/Taxpayer/v1/Verify", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  return parse<FdmsTaxpayerVerificationResponse>(res);
}

/** POST /Device/v1/Register — registers a fiscal device and returns its FDMS device id/activation key. */
export async function registerDevice(env: FdmsEnv, payload: FdmsDeviceRegistrationRequest) {
  const res = await fdmsActivationFetch(env, "/Device/v1/Register", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  return parse<FdmsDeviceRegistrationResponse>(res);
}

/** POST /Device/v1/{deviceID}/IssueCertificate — exchanges a CSR for a device certificate. */
export async function issueDeviceCertificate(env: FdmsEnv, payload: FdmsCertificateIssueRequest) {
  const res = await fdmsActivationFetch(
    env,
    `/Device/v1/${payload.deviceId}/IssueCertificate`,
    { method: "POST", body: JSON.stringify({ csr: payload.csr }) },
    payload.activationKey,
  );
  return parse<FdmsCertificateIssueResponse>(res);
}

/** POST /Device/v1/{deviceID}/OpenDay — opens a fiscal day. */
export async function openDay(
  env: FdmsEnv,
  device: FdmsDevice,
  fiscalDayNo: number,
  openedAt: string,
) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/OpenDay`,
    { method: "POST", body: JSON.stringify({ fiscalDayNo, fiscalDayOpened: openedAt }) },
    device,
  );
  return parse<Record<string, unknown>>(res);
}

/** POST /Device/v1/{deviceID}/CloseDay — closes the current fiscal day. */
export async function closeDay(
  env: FdmsEnv,
  device: FdmsDevice,
  fiscalDayNo: number,
  totals: unknown,
  closedAt: string,
) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/CloseDay`,
    {
      method: "POST",
      body: JSON.stringify({ fiscalDayNo, fiscalDayClosed: closedAt, fiscalDayCounters: totals }),
    },
    device,
  );
  return parse<Record<string, unknown>>(res);
}

/** POST /Device/v1/{deviceID}/SubmitReceipt — submits a single receipt. */
export async function submitReceipt(env: FdmsEnv, device: FdmsDevice, payload: unknown) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/SubmitReceipt`,
    { method: "POST", body: JSON.stringify({ receipt: payload }) },
    device,
  );
  return parse<{ receiptID?: number; serverDate?: string } & Record<string, unknown>>(res);
}
