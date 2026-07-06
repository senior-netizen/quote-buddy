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
 * `mtls_certificates` binding rather than runtime PEM. If the platform is
 * not configured for mTLS, requests will fail at the TLS handshake — the
 * error is stored on the document/day so the operator can see it.
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

export type FdmsError = {
  status: number;
  code?: string;
  message: string;
  raw?: unknown;
};

export type FdmsResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: FdmsError };

function baseUrl(env: FdmsEnv): string {
  return ENDPOINTS[env];
}

async function fdmsFetch(
  env: FdmsEnv,
  path: string,
  init: RequestInit,
  device: FdmsDevice,
): Promise<Response> {
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
      (body && typeof body === "object" && "title" in (body as Record<string, unknown>)
        ? String((body as Record<string, unknown>).title)
        : typeof body === "string"
          ? body
          : `FDMS request failed (${res.status})`);
    return {
      ok: false,
      error: { status: res.status, message: msg, raw: body },
    };
  }
  return { ok: true, data: body as T };
}

/** GET /Device/v1/{deviceID}/GetConfig — returns tax config, VAT number, etc. */
export async function getDeviceConfig(env: FdmsEnv, device: FdmsDevice) {
  const res = await fdmsFetch(env, `/Device/v1/${device.deviceId}/GetConfig`, { method: "GET" }, device);
  return parse<Record<string, unknown>>(res);
}

/** POST /Device/v1/{deviceID}/OpenDay — opens a fiscal day. */
export async function openDay(env: FdmsEnv, device: FdmsDevice, fiscalDayNo: number, openedAt: string) {
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
    { method: "POST", body: JSON.stringify({ fiscalDayNo, fiscalDayClosed: closedAt, fiscalDayCounters: totals }) },
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
