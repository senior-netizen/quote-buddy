/**
 * Thin client for the ZIMRA FDMS (Fiscalisation Data Management System) API.
 *
 * Two environments:
 *   test → https://fdmsapitest.zimra.co.zw
 *   prod → https://fdmsapi.zimra.co.zw
 *
 * IMPORTANT — mTLS:
 * The FDMS API requires a client TLS certificate issued to the device
 * (`certificate_pem` + `private_key_pem` in `organization_fiscal_config`).
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

type CloudflareMtlsBinding = {
  fetch: typeof fetch;
};

type FdmsTransport = {
  fetch(url: string, init: RequestInit): Promise<Response>;
};

function mtlsUnavailableResponse(): Response {
  return new Response(
    JSON.stringify({
      title: "ZIMRA FDMS mTLS is not configured",
      detail:
        "FDMS requires mutual TLS. Configure the Cloudflare Workers mTLS binding ZIMRA_FDMS_MTLS_CERT, or provide decrypted device certificate and private key PEM material in a Node/server runtime.",
      code: "FDMS_MTLS_UNAVAILABLE",
    }),
    { status: 495, headers: { "Content-Type": "application/json" } },
  );
}

function hasDevicePem(
  device: FdmsDevice,
): device is FdmsDevice & { certificatePem: string; privateKeyPem: string } {
  return Boolean(device.certificatePem?.trim() && device.privateKeyPem?.trim());
}

function cloudflareMtlsBinding(): CloudflareMtlsBinding | null {
  const binding = (globalThis as Record<string, unknown>)[CLOUDFLARE_MTLS_BINDING];
  return binding &&
    typeof binding === "object" &&
    "fetch" in binding &&
    typeof binding.fetch === "function"
    ? (binding as CloudflareMtlsBinding)
    : null;
}

function isNodeRuntime(): boolean {
  return typeof process !== "undefined" && Boolean(process.versions?.node);
}

async function nodeMtlsFetch(
  url: string,
  init: RequestInit,
  device: FdmsDevice & { certificatePem: string; privateKeyPem: string },
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

function fdmsTransport(device: FdmsDevice): FdmsTransport | null {
  const binding = cloudflareMtlsBinding();
  if (binding) {
    return { fetch: (url, init) => binding.fetch(url, init) };
  }
  if (isNodeRuntime() && hasDevicePem(device)) {
    return { fetch: (url, init) => nodeMtlsFetch(url, init, device) };
  }
  return null;
}

async function fdmsFetch(
  env: FdmsEnv,
  path: string,
  init: RequestInit,
  device: FdmsDevice,
): Promise<Response> {
  const transport = fdmsTransport(device);
  if (!transport) return mtlsUnavailableResponse();

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
  return await transport.fetch(url, { ...init, headers });
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
