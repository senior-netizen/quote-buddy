import { c as createServerRpc } from "./createServerRpc-wV0Vk4NU.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { supabaseAdmin } from "./client.server-BMj2q4-x.mjs";
import { c as computeTotals } from "./calc-BF6zAv6d.mjs";
import { c as createServerFn } from "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/react.mjs";
import { o as object, s as string, _ as _enum, b as boolean } from "../_libs/zod.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "node:stream";
import "../_libs/tanstack__router-core.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "../_libs/tanstack__react-router.mjs";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "../_libs/isbot.mjs";
function toBase64(bytes) {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}
function toHex(bytes) {
  let out = "";
  for (let i = 0; i < bytes.length; i++) out += bytes[i].toString(16).padStart(2, "0");
  return out;
}
async function computeReceiptHash(input) {
  const sortedTaxes = [...input.taxes].sort((a, b) => a.taxCode.localeCompare(b.taxCode));
  const taxPart = sortedTaxes.map((t) => `${t.taxCode}${t.taxPercent}${t.taxAmount}`).join("");
  const concatenated = `${input.deviceId}${input.receiptType}${input.receiptCurrency}${input.receiptGlobalNo}${input.receiptDate}${input.receiptTotalCents}${taxPart}${input.previousReceiptHash ?? ""}`;
  const enc = new TextEncoder().encode(concatenated);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", enc));
  const hashBase64 = toBase64(digest);
  const hashHex = toHex(digest);
  const verificationCode = hashHex.slice(0, 16).toUpperCase();
  return { hashBase64, hashHex, verificationCode, concatenated };
}
class FiscalCounterManager {
  static async allocateInvoiceCounters(orgId, documentId) {
    const { data, error } = await supabaseAdmin.rpc("allocate_fiscal_receipt_counters", {
      _org_id: orgId,
      _document_id: documentId,
      _receipt_type: "FiscalInvoice",
      _requires_receipt_type_counter: true
    });
    if (error) throw new Error(error.message);
    const row = Array.isArray(data) ? data[0] : void 0;
    if (!row) throw new Error("Fiscal counter allocation failed");
    return {
      fiscalDayNo: row.fiscal_day_no,
      receiptGlobalNo: Number(row.receipt_global_no),
      receiptCounter: Number(row.receipt_counter),
      receiptTypeCounter: row.receipt_type_counter === null ? null : Number(row.receipt_type_counter),
      invoiceNo: row.invoice_no
    };
  }
  static async markSubmitted(documentId, submittedAt) {
    const { error } = await supabaseAdmin.from("receipt_history").update({ status: "submitted", submitted_at: submittedAt }).eq("document_id", documentId);
    if (error) throw new Error(error.message);
  }
  static async markFailed(documentId) {
    const { error } = await supabaseAdmin.from("receipt_history").update({ status: "failed" }).eq("document_id", documentId);
    if (error) throw new Error(error.message);
  }
}
const ENDPOINTS = {
  test: "https://fdmsapitest.zimra.co.zw",
  prod: "https://fdmsapi.zimra.co.zw"
};
function baseUrl(env) {
  return ENDPOINTS[env];
}
const CLOUDFLARE_MTLS_BINDING = "ZIMRA_FDMS_MTLS_CERT";
const FDMS_CA_CERT_ENV = "FDMS_CA_CERT";
function mtlsErrorResponse(code, detail) {
  return new Response(
    JSON.stringify({
      title: "ZIMRA FDMS mTLS is not configured",
      detail,
      code
    }),
    { status: 495, headers: { "Content-Type": "application/json" } }
  );
}
function missingClientCertificateResponse() {
  return mtlsErrorResponse(
    "FDMS_CLIENT_CERT_MISSING",
    "No client certificate found. Attempting automatic registration... FDMS requests that require mTLS cannot be sent until ZIMRA issues and stores a client certificate for this device."
  );
}
function missingPrivateKeyResponse() {
  return mtlsErrorResponse(
    "FDMS_PRIVATE_KEY_MISSING",
    "Missing private key for the ZIMRA client certificate. Restore the encrypted device private key before FDMS requests can be sent."
  );
}
function missingCaCertificateResponse(path) {
  return mtlsErrorResponse(
    "FDMS_CA_CERT_MISSING",
    `Missing ZIMRA CA certificate at ${path}. Configure ${FDMS_CA_CERT_ENV} before FDMS requests can be sent.`
  );
}
function unsupportedRuntimeMtlsResponse() {
  return mtlsErrorResponse(
    "FDMS_MTLS_UNSUPPORTED_RUNTIME",
    `Unsupported runtime mTLS configuration. Configure the Cloudflare Workers mTLS binding ${CLOUDFLARE_MTLS_BINDING}, or run in Node with decrypted device certificate and private key PEM material plus ${FDMS_CA_CERT_ENV}.`
  );
}
function asCloudflareMtlsBinding(value) {
  return value && typeof value === "object" && "fetch" in value && typeof value.fetch === "function" ? value : null;
}
async function cloudflareMtlsBinding() {
  const globalBinding = asCloudflareMtlsBinding(
    globalThis[CLOUDFLARE_MTLS_BINDING]
  );
  if (globalBinding) return globalBinding;
  const dynamicImport = new Function("specifier", "return import(specifier)");
  const workersModule = await dynamicImport("cloudflare:workers").catch(() => null);
  return asCloudflareMtlsBinding(workersModule?.env?.[CLOUDFLARE_MTLS_BINDING]);
}
function isNodeRuntime() {
  return typeof process !== "undefined" && Boolean(process.versions?.node) && process.release?.name === "node";
}
async function nodeMtlsFetch(url, init, device, caCertPem) {
  const { createPrivateKey, X509Certificate } = await import("node:crypto");
  const { request } = await import("node:https");
  if (!caCertPem) {
    return mtlsErrorResponseWithCause(
      "FDMS_CA_CERT/FDMS_CA_CERT_PEM is required for Node FDMS mTLS requests. Set it to the ZIMRA FDMS CA certificate PEM file path or raw PEM contents.",
      "FDMS_CA_CERT_MISSING"
    );
  }
  const certificatePem = device.certificatePem;
  const privateKeyPem = device.privateKeyPem;
  if (!certificatePem || !privateKeyPem) {
    return mtlsErrorResponseWithCause(
      "The configured FDMS client certificate or private key is missing.",
      "FDMS_CLIENT_CERT_OR_KEY_MISSING"
    );
  }
  try {
    createPrivateKey(privateKeyPem);
  } catch (error) {
    return mtlsErrorResponseWithCause(
      "The configured FDMS private key is invalid. Provide a valid PEM private key or rerun certificate provisioning.",
      "FDMS_INVALID_PRIVATE_KEY",
      error
    );
  }
  try {
    const certificate = new X509Certificate(certificatePem);
    if (Date.parse(certificate.validTo) <= Date.now()) {
      return mtlsErrorResponseWithCause(
        `The configured FDMS client certificate expired on ${certificate.validTo}. Rerun certificate provisioning before making FDMS requests.`,
        "FDMS_CERTIFICATE_EXPIRED"
      );
    }
  } catch (error) {
    return mtlsErrorResponseWithCause(
      "The configured FDMS client certificate is invalid. Rerun certificate provisioning or replace the certificate PEM.",
      "FDMS_INVALID_CERTIFICATE",
      error
    );
  }
  return await new Promise((resolve, reject) => {
    const headers = Object.fromEntries(new Headers(init.headers).entries());
    const req = request(
      url,
      {
        method: init.method ?? "GET",
        headers,
        cert: certificatePem,
        key: privateKeyPem,
        ca: caCertPem
      },
      (res) => {
        const chunks = [];
        res.on(
          "data",
          (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk))
        );
        res.on("end", () => {
          resolve(
            new Response(Buffer.concat(chunks), {
              status: res.statusCode ?? 0,
              statusText: res.statusMessage,
              headers: Object.fromEntries(
                Object.entries(res.headers).filter(
                  (entry) => typeof entry[1] === "string" || Array.isArray(entry[1])
                ).map(([key, value]) => [key, Array.isArray(value) ? value.join(", ") : value])
              )
            })
          );
        });
      }
    );
    req.on(
      "error",
      (error) => reject(
        new Error(
          `FDMS mTLS setup/request failed. Check client certificate, private key, FDMS_CA_CERT, and ZIMRA network access. Cause: ${error.message}`
        )
      )
    );
    if (typeof init.body === "string" || init.body instanceof Uint8Array) {
      req.write(init.body);
    }
    req.end();
  });
}
function mtlsErrorResponseWithCause(message, code, cause) {
  return new Response(
    JSON.stringify({
      title: "ZIMRA FDMS mTLS setup failed",
      detail: message,
      code,
      cause: cause instanceof Error ? cause.message : void 0
    }),
    { status: 495, headers: { "Content-Type": "application/json" } }
  );
}
async function loadCaCertificatePem() {
  const configured = process.env.FDMS_CA_CERT_PEM ?? process.env.FDMS_CA_CERT;
  if (!configured?.trim()) return null;
  if (configured.includes("-----BEGIN CERTIFICATE-----")) return configured.trim();
  const { readFile } = await import("node:fs/promises");
  return readFile(configured, "utf8");
}
async function nodeMtlsTransport(device) {
  if (!device.certificatePem) {
    return { ok: false, response: missingClientCertificateResponse() };
  }
  if (!device.privateKeyPem) {
    return { ok: false, response: missingPrivateKeyResponse() };
  }
  let caPem;
  try {
    caPem = await loadCaCertificatePem();
  } catch (error) {
    return {
      ok: false,
      response: mtlsErrorResponseWithCause(
        `Unable to read FDMS CA certificate. Check FDMS_CA_CERT or FDMS_CA_CERT_PEM and file permissions.`,
        "FDMS_CA_CERT_UNREADABLE",
        error
      )
    };
  }
  if (!caPem) {
    return { ok: false, response: missingCaCertificateResponse("FDMS_CA_CERT/FDMS_CA_CERT_PEM") };
  }
  return {
    ok: true,
    transport: {
      fetch: (url, init) => nodeMtlsFetch(url, init, device, caPem)
    }
  };
}
async function fdmsTransport(device) {
  const binding = await cloudflareMtlsBinding();
  if (binding) {
    return { ok: true, transport: { fetch: (url, init) => binding.fetch(url, init) } };
  }
  if (isNodeRuntime()) {
    return nodeMtlsTransport(device);
  }
  return { ok: false, response: unsupportedRuntimeMtlsResponse() };
}
async function fdmsFetch(env, path, init, device) {
  const transport = await fdmsTransport(device);
  if (!transport.ok) return transport.response;
  const url = `${baseUrl(env)}${path}`;
  const headers = new Headers(init.headers);
  headers.set("Content-Type", "application/json");
  headers.set("Accept", "application/json");
  headers.set("DeviceModelName", "Server");
  headers.set("DeviceModelVersion", "v1");
  if (device.activationKey) {
    headers.set("Authorization", `Bearer ${device.activationKey}`);
  }
  try {
    return await transport.transport.fetch(url, { ...init, headers });
  } catch (error) {
    return mtlsErrorResponseWithCause(
      error instanceof Error ? error.message : "FDMS mTLS setup failed before the request could be completed.",
      "FDMS_MTLS_SETUP_FAILED",
      error
    );
  }
}
async function parse(res) {
  const text = await res.text();
  let body = void 0;
  try {
    body = text ? JSON.parse(text) : void 0;
  } catch {
    body = text;
  }
  if (!res.ok) {
    const msg = body && typeof body === "object" && "title" in body ? String(body.title) : typeof body === "string" ? body : `FDMS request failed (${res.status})`;
    const code = body && typeof body === "object" && "code" in body ? String(body.code) : void 0;
    return {
      ok: false,
      error: { status: res.status, code, message: msg, raw: body }
    };
  }
  return { ok: true, data: body };
}
async function getDeviceConfig(env, device) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/GetConfig`,
    { method: "GET" },
    device
  );
  return parse(res);
}
async function openDay(env, device, fiscalDayNo, openedAt) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/OpenDay`,
    { method: "POST", body: JSON.stringify({ fiscalDayNo, fiscalDayOpened: openedAt }) },
    device
  );
  return parse(res);
}
async function closeDay(env, device, fiscalDayNo, totals, closedAt) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/CloseDay`,
    {
      method: "POST",
      body: JSON.stringify({ fiscalDayNo, fiscalDayClosed: closedAt, fiscalDayCounters: totals })
    },
    device
  );
  return parse(res);
}
async function submitReceipt(env, device, payload) {
  const res = await fdmsFetch(
    env,
    `/Device/v1/${device.deviceId}/SubmitReceipt`,
    { method: "POST", body: JSON.stringify({ receipt: payload }) },
    device
  );
  return parse(res);
}
async function appendReceiptStatus(documentId, orgId, status, message, metadata) {
  const {
    error
  } = await supabaseAdmin.from("receipt_status").insert({
    document_id: documentId,
    org_id: orgId,
    status,
    message: message ?? null,
    metadata: metadata ?? null
  });
  if (error) throw new Error(error.message);
}
async function loadPreviousReceiptHash(orgId, deviceId, fiscalDayNo) {
  const {
    data: acceptedStatusesForHash,
    error: statusError
  } = await supabaseAdmin.from("current_receipt_status").select("document_id").eq("org_id", orgId).eq("status", "Accepted");
  if (statusError) throw new Error(statusError.message);
  const acceptedIdsForHash = (acceptedStatusesForHash ?? []).map((r) => r.document_id).filter((documentId) => Boolean(documentId));
  if (!acceptedIdsForHash.length) return "";
  const {
    data: prevRow,
    error: prevError
  } = await supabaseAdmin.from("documents").select("receipt_hash").eq("org_id", orgId).eq("fiscal_device_id", deviceId).eq("fiscal_day_no", fiscalDayNo).in("id", acceptedIdsForHash).not("receipt_hash", "is", null).order("receipt_global_no", {
    ascending: false
  }).limit(1).maybeSingle();
  if (prevError) throw new Error(prevError.message);
  return prevRow?.receipt_hash ?? "";
}
async function ensureAdmin(supabase, userId, orgId) {
  const {
    data
  } = await supabase.rpc("has_org_role", {
    _user_id: userId,
    _org_id: orgId,
    _min_role: "admin"
  });
  if (!data) throw new Error("Admin or owner role required");
}
const SECRET_FIELD_PATTERN = /(activation[_-]?key|private[_-]?key|certificate|cert(ificate)?[_-]?pem|secret|authorization|bearer|token)/i;
function redactString(value) {
  return value.replace(/-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----/g, "[REDACTED_PEM]").replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/gi, "Bearer [REDACTED]");
}
function redactSecrets(value) {
  if (typeof value === "string") return redactString(value);
  if (Array.isArray(value)) return value.map((item) => redactSecrets(item));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, SECRET_FIELD_PATTERN.test(key) ? "[REDACTED]" : redactSecrets(entry)]));
  }
  return value;
}
function redactFdmsError(error) {
  return {
    ...error,
    message: redactString(error.message),
    raw: redactSecrets(error.raw)
  };
}
async function activeEncryptedPayload(orgId, table) {
  const {
    data
  } = await supabaseAdmin.from(table).select("encrypted_payload").eq("org_id", orgId).eq("active", true).order("created_at", {
    ascending: false
  }).limit(1).maybeSingle();
  return data?.encrypted_payload ?? null;
}
async function hasActiveFiscalSecret(orgId, table) {
  const {
    data
  } = await supabaseAdmin.from(table).select("id").eq("org_id", orgId).eq("active", true).limit(1).maybeSingle();
  return Boolean(data);
}
async function activeOrgId(supabase, userId) {
  const {
    data
  } = await supabase.from("profiles").select("active_org_id").eq("user_id", userId).maybeSingle();
  const id = data?.active_org_id ?? null;
  if (!id) throw new Error("No active organization");
  return id;
}
function stripSecrets(row, secretState) {
  return {
    org_id: row.org_id,
    enabled: Boolean(row.enabled),
    environment: row.environment ?? "test",
    device_id: row.device_id ?? null,
    device_serial: row.device_serial ?? null,
    device_address: row.device_address ?? null,
    device_model: row.device_model ?? null,
    device_model_name: row.device_model_name ?? row.device_model ?? null,
    device_model_version: row.device_model_version ?? null,
    tax_payer_name: row.tax_payer_name ?? null,
    tax_payer_tin: row.tax_payer_tin ?? null,
    vat_number: row.vat_number ?? null,
    trade_name: row.trade_name ?? null,
    has_certificate: secretState?.hasCertificate ?? Boolean(row.certificate_secret_ref),
    has_private_key: secretState?.hasPrivateKey ?? Boolean(row.private_key_secret_ref),
    has_activation_key: Boolean(row.activation_key_secret_ref ?? row.activation_key_encrypted ?? row.activation_key),
    device_operating_mode: row.device_operating_mode ?? "Online",
    last_fiscal_day_no: row.last_fiscal_day_no ?? null,
    last_receipt_global_no: Number(row.last_receipt_global_no ?? 0),
    last_receipt_counter: Number(row.last_receipt_counter ?? 0)
  };
}
const DEFAULT_RECEIPT_TYPE = "FiscalInvoice";
const DEFAULT_MONEY_TYPE_CODE = "Cash";
const TAX_CONFIG_ARRAY_KEYS = ["taxes", "taxRates", "taxTable", "vatRates", "applicableTaxes", "taxConfigurations"];
const MONEY_TYPE_ARRAY_KEYS = ["moneyTypes", "paymentTypes", "payments", "paymentMethods", "moneyTypeCodes"];
function asRecord(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : null;
}
function findConfigArray(config, keys) {
  for (const key of keys) {
    const value = config[key];
    if (Array.isArray(value)) return value;
  }
  for (const value of Object.values(config)) {
    const record = asRecord(value);
    if (!record) continue;
    const found = findConfigArray(record, keys);
    if (found.length) return found;
  }
  return [];
}
function firstString(record, keys) {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value.trim();
    if (typeof value === "number" && Number.isFinite(value)) return String(value);
  }
  return null;
}
function firstNumber(record, keys) {
  for (const key of keys) {
    const value = record[key];
    const number = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN;
    if (Number.isFinite(number)) return number;
  }
  return null;
}
function configuredTaxes(config) {
  return findConfigArray(config, TAX_CONFIG_ARRAY_KEYS).map(asRecord).flatMap((tax) => {
    if (!tax) return [];
    const taxCode = firstString(tax, ["taxCode", "code", "taxID", "taxId", "id"]);
    const taxPercent = firstNumber(tax, ["taxPercent", "taxPercentage", "taxRate", "rate", "percent"]);
    const taxID = firstNumber(tax, ["taxID", "taxId", "id"]);
    if (!taxCode || taxPercent === null) return [];
    return [{
      taxCode,
      taxPercent,
      taxID: taxID ?? void 0
    }];
  });
}
function configuredMoneyTypeCodes(config) {
  return new Set(findConfigArray(config, MONEY_TYPE_ARRAY_KEYS).map((entry) => {
    if (typeof entry === "string") return entry;
    const record = asRecord(entry);
    return record ? firstString(record, ["moneyTypeCode", "code", "name", "id"]) : null;
  }).filter((code) => Boolean(code)));
}
function resolveTaxConfig(config, taxRate) {
  const tax = configuredTaxes(config).find((entry) => Math.round(entry.taxPercent * 100) === Math.round(taxRate * 100));
  if (!tax) throw new Error(`Unsupported ZIMRA tax rate ${taxRate}%; refresh FDMS GetConfig or configure an allowed tax rate for this device`);
  return tax;
}
function validateReceiptPayments(config, payments, receiptTotal) {
  const allowedCodes = configuredMoneyTypeCodes(config);
  if (allowedCodes.size) {
    for (const payment of payments) {
      if (!allowedCodes.has(payment.moneyTypeCode)) throw new Error(`Unsupported ZIMRA payment type ${payment.moneyTypeCode}`);
    }
  }
  const paid = payments.reduce((sum, payment) => sum + Number(payment.paymentAmount || 0), 0);
  if (Math.round(paid) !== Math.round(receiptTotal)) throw new Error("Receipt payments must equal the receipt total");
}
function validateReceiptLines(lines, taxInclusive) {
  if (taxInclusive !== false) throw new Error("Only tax-exclusive receipt lines are supported by this invoice model");
  for (const line of lines) {
    const expected = Math.round(Number(line.receiptLineQuantity) * Number(line.receiptLinePrice) * 100);
    if (expected !== Math.round(Number(line.receiptLineTotal))) {
      throw new Error(`Receipt line ${line.receiptLineNo} total does not match quantity × price`);
    }
  }
}
async function fetchAndStoreDeviceConfig(orgId, env, device) {
  const result = await getDeviceConfig(env, device);
  if (!result.ok) throw new Error(`FDMS GetConfig failed: ${redactFdmsError(result.error).message}`);
  await supabaseAdmin.from("device_configuration").insert({
    org_id: orgId,
    device_id: orgId,
    fdms_device_id: device.deviceId,
    environment: env,
    source: "fdms",
    configuration: result.data
  });
  return result.data;
}
async function latestDeviceConfig(orgId, env, device) {
  const {
    data,
    error
  } = await supabaseAdmin.from("device_configuration").select("configuration").eq("org_id", orgId).eq("fdms_device_id", device.deviceId).eq("environment", env).order("created_at", {
    ascending: false
  }).limit(1).maybeSingle();
  if (error) throw new Error(error.message);
  return data?.configuration ?? fetchAndStoreDeviceConfig(orgId, env, device);
}
function buildFiscalDayCounters(receipts, receiptCurrency, config) {
  const counters = /* @__PURE__ */ new Map();
  const add = (key, patch, amountKey, amount, quantity = 0) => {
    const current = counters.get(key) ?? patch;
    current[amountKey] = Math.round((Number(current[amountKey] ?? 0) + amount) * 100) / 100;
    if (quantity) current.receiptQuantity = Number(current.receiptQuantity ?? 0) + quantity;
    counters.set(key, current);
  };
  for (const receipt of receipts) {
    const taxRate = Number(receipt.tax_rate ?? 0);
    const tax = resolveTaxConfig(config, taxRate);
    const totals = computeTotals(receipt.line_items ?? [], taxRate, Number(receipt.discount ?? 0));
    add(`SaleByTax:${tax.taxCode}:${receiptCurrency}`, {
      receiptType: DEFAULT_RECEIPT_TYPE,
      receiptCurrency,
      taxCode: tax.taxCode,
      taxPercent: tax.taxPercent
    }, "receiptTotalAmount", totals.total, 1);
    add(`SaleTaxByTax:${tax.taxCode}:${receiptCurrency}`, {
      receiptType: DEFAULT_RECEIPT_TYPE,
      receiptCurrency,
      taxCode: tax.taxCode,
      taxPercent: tax.taxPercent
    }, "taxAmount", totals.tax_amount);
    add(`Payment:${DEFAULT_MONEY_TYPE_CODE}:${receiptCurrency}`, {
      receiptType: DEFAULT_RECEIPT_TYPE,
      receiptCurrency,
      moneyTypeCode: DEFAULT_MONEY_TYPE_CODE
    }, "paymentAmount", totals.total);
  }
  return Array.from(counters.values());
}
const getFiscalConfig_createServerFn_handler = createServerRpc({
  id: "21c9ee1831c97b4f9b584fa79f48a4f00c4d074733709bd4563c6771b1737191",
  name: "getFiscalConfig",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => getFiscalConfig.__executeServer(opts));
const getFiscalConfig = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(getFiscalConfig_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  const {
    data
  } = await supabaseAdmin.from("organization_fiscal_config").select("*").eq("org_id", orgId).maybeSingle();
  if (!data) return null;
  return stripSecrets(data, {
    hasCertificate: await hasActiveFiscalSecret(orgId, "device_certificates"),
    hasPrivateKey: await hasActiveFiscalSecret(orgId, "device_keys")
  });
});
const updateSchema = object({
  enabled: boolean().optional(),
  environment: _enum(["test", "prod"]).optional(),
  device_id: string().nullable().optional(),
  device_serial: string().nullable().optional(),
  device_address: string().nullable().optional(),
  device_model: string().nullable().optional(),
  device_model_name: string().nullable().optional(),
  device_model_version: string().nullable().optional(),
  activation_key_secret_ref: string().nullable().optional(),
  tax_payer_name: string().nullable().optional(),
  tax_payer_tin: string().nullable().optional(),
  vat_number: string().nullable().optional(),
  trade_name: string().nullable().optional(),
  certificate_secret_ref: string().nullable().optional(),
  private_key_secret_ref: string().nullable().optional(),
  device_operating_mode: string().optional()
}).strict();
const updateFiscalConfig_createServerFn_handler = createServerRpc({
  id: "ae82a81d5d9218ce267825c9c94ebf3e394b99dcf6384a46776ad985c5f8f043",
  name: "updateFiscalConfig",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => updateFiscalConfig.__executeServer(opts));
const updateFiscalConfig = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => updateSchema.parse(data)).handler(updateFiscalConfig_createServerFn_handler, async ({
  data,
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  await ensureAdmin(context.supabase, context.userId, orgId);
  const cleaned = {
    ...data
  };
  for (const k of Object.keys(cleaned)) {
    if (cleaned[k] === "") cleaned[k] = null;
  }
  const {
    data: existing
  } = await supabaseAdmin.from("organization_fiscal_config").select("org_id").eq("org_id", orgId).maybeSingle();
  if (existing) {
    const {
      data: updated,
      error: error2
    } = await supabaseAdmin.from("organization_fiscal_config").update(cleaned).eq("org_id", orgId).select("*").single();
    if (error2) throw new Error(error2.message);
    return stripSecrets(updated);
  }
  const insertPayload = {
    ...cleaned,
    org_id: orgId
  };
  const {
    data: inserted,
    error
  } = await supabaseAdmin.from("organization_fiscal_config").insert(insertPayload).select("*").single();
  if (error) throw new Error(error.message);
  return stripSecrets(inserted);
});
const fiscalSecretStorageModule = "@/lib/fiscal/secretStorage";
async function loadFiscalSecretStorage() {
  return import(
    /* @vite-ignore */
    fiscalSecretStorageModule
  );
}
const secureOnboardingSchema = object({
  activation_key: string().min(1).optional(),
  certificate_pem: string().min(1).optional(),
  private_key_pem: string().min(1).optional(),
  key_id: string().min(1).default("server-managed"),
  valid_from: string().datetime().nullable().optional(),
  valid_until: string().datetime().nullable().optional()
}).strict();
async function assertFiscalSecretStorageReady(data) {
  if (data.activation_key || data.certificate_pem || data.private_key_pem) {
    await loadFiscalSecretStorage();
  }
}
async function ensureFiscalConfigRow(orgId) {
  const {
    error
  } = await supabaseAdmin.from("organization_fiscal_config").upsert({
    org_id: orgId
  }, {
    onConflict: "org_id",
    ignoreDuplicates: true
  });
  if (error) throw new Error(error.message);
}
const onboardFiscalDeviceSecrets_createServerFn_handler = createServerRpc({
  id: "38a97d9c9d765dc240e136351e6fd81fcabf21702dc80ed69b3880ef8424ce6f",
  name: "onboardFiscalDeviceSecrets",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => onboardFiscalDeviceSecrets.__executeServer(opts));
const onboardFiscalDeviceSecrets = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => secureOnboardingSchema.parse(data)).handler(onboardFiscalDeviceSecrets_createServerFn_handler, async ({
  data,
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  await ensureAdmin(context.supabase, context.userId, orgId);
  await assertFiscalSecretStorageReady(data);
  await ensureFiscalConfigRow(orgId);
  const {
    encryptFiscalSecret,
    sha256Hex
  } = await loadFiscalSecretStorage();
  const now = (/* @__PURE__ */ new Date()).toISOString();
  const validFrom = data.valid_from ?? now;
  if (data.activation_key) {
    await supabaseAdmin.from("organization_fiscal_config").update({
      activation_key_encrypted: await encryptFiscalSecret(data.activation_key),
      activation_key_id: data.key_id,
      activation_key_secret_ref: `organization_fiscal_config:${orgId}:activation_key_encrypted`
    }).eq("org_id", orgId);
  }
  if (data.certificate_pem) {
    await supabaseAdmin.from("device_certificates").update({
      active: false
    }).eq("org_id", orgId);
    const {
      data: certRow,
      error
    } = await supabaseAdmin.from("device_certificates").insert({
      org_id: orgId,
      encrypted_payload: await encryptFiscalSecret(data.certificate_pem),
      key_id: data.key_id,
      thumbprint: await sha256Hex(data.certificate_pem),
      active: true,
      valid_from: validFrom,
      valid_until: data.valid_until ?? null
    }).select("id").single();
    if (error) throw new Error(error.message);
    await supabaseAdmin.from("organization_fiscal_config").update({
      certificate_secret_ref: `device_certificates:${certRow.id}`
    }).eq("org_id", orgId);
  }
  if (data.private_key_pem) {
    await supabaseAdmin.from("device_keys").update({
      active: false
    }).eq("org_id", orgId);
    const {
      data: keyRow,
      error
    } = await supabaseAdmin.from("device_keys").insert({
      org_id: orgId,
      encrypted_payload: await encryptFiscalSecret(data.private_key_pem),
      key_id: data.key_id,
      thumbprint: await sha256Hex(data.private_key_pem),
      active: true,
      valid_from: validFrom,
      valid_until: data.valid_until ?? null
    }).select("id").single();
    if (error) throw new Error(error.message);
    await supabaseAdmin.from("organization_fiscal_config").update({
      private_key_secret_ref: `device_keys:${keyRow.id}`
    }).eq("org_id", orgId);
  }
  return {
    ok: true
  };
});
async function loadOrganizationCurrency(orgId) {
  const {
    data,
    error
  } = await supabaseAdmin.from("organization_profiles").select("currency").eq("org_id", orgId).maybeSingle();
  if (error) throw new Error(error.message);
  return (data?.currency?.trim() || "USD").toUpperCase();
}
function readOptionalEnv(name) {
  const value = process.env[name]?.trim();
  return value ? value : null;
}
async function loadDevice(orgId) {
  const {
    data
  } = await supabaseAdmin.from("organization_fiscal_config").select("*").eq("org_id", orgId).maybeSingle();
  const configRow = data ?? {};
  const envActivationKey = readOptionalEnv("FDMS_ACTIVATION_KEY");
  const envCertificatePem = readOptionalEnv("FDMS_CLIENT_CERT_PEM") ?? readOptionalEnv("FDMS_CERTIFICATE_PEM");
  const envPrivateKeyPem = readOptionalEnv("FDMS_PRIVATE_KEY_PEM");
  const envDeviceId = readOptionalEnv("FDMS_DEVICE_ID");
  const hasEnvRuntimeMaterial = Boolean(envDeviceId || envActivationKey || envCertificatePem || envPrivateKeyPem);
  if (!data && !hasEnvRuntimeMaterial) throw new Error("Fiscal config not found");
  if (!data?.enabled && !hasEnvRuntimeMaterial) throw new Error("Fiscalisation is disabled for this organization");
  const encryptedActivationPayload = configRow.activation_key_encrypted ?? null;
  const encryptedCertificatePayload = await activeEncryptedPayload(orgId, "device_certificates");
  const encryptedPrivateKeyPayload = await activeEncryptedPayload(orgId, "device_keys");
  const hasEncryptedSecrets = Boolean(encryptedActivationPayload || encryptedCertificatePayload || encryptedPrivateKeyPayload);
  const decryptFiscalSecret = hasEncryptedSecrets ? (await loadFiscalSecretStorage()).decryptFiscalSecret : null;
  const activationKey = decryptFiscalSecret ? await decryptFiscalSecret(encryptedActivationPayload) : null;
  const certificatePem = decryptFiscalSecret ? await decryptFiscalSecret(encryptedCertificatePayload) : null;
  const privateKeyPem = decryptFiscalSecret ? await decryptFiscalSecret(encryptedPrivateKeyPayload) : null;
  const effectiveDeviceId = String(configRow.device_id ?? envDeviceId ?? "");
  if (!effectiveDeviceId) throw new Error("Device ID is not configured");
  return {
    env: configRow.environment ?? "test",
    device: {
      deviceId: effectiveDeviceId,
      deviceSerialNo: configRow.device_serial ?? readOptionalEnv("FDMS_DEVICE_SERIAL") ?? null,
      activationKey: activationKey ?? envActivationKey,
      certificatePem: certificatePem ?? envCertificatePem,
      privateKeyPem: privateKeyPem ?? envPrivateKeyPem
    },
    row: data ?? {}
  };
}
const testDeviceConnection_createServerFn_handler = createServerRpc({
  id: "c276c80f7dd2c23a283c99a9de94889fe3c329369162f7e1ad23fba93ec1fc5e",
  name: "testDeviceConnection",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => testDeviceConnection.__executeServer(opts));
const testDeviceConnection = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).handler(testDeviceConnection_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  await ensureAdmin(context.supabase, context.userId, orgId);
  const {
    env,
    device
  } = await loadDevice(orgId);
  try {
    const data = await fetchAndStoreDeviceConfig(orgId, env, device);
    return {
      ok: true,
      message: "Device reachable",
      data
    };
  } catch (e) {
    return {
      ok: false,
      message: e instanceof Error ? e.message : "Network error"
    };
  }
});
const openFiscalDay_createServerFn_handler = createServerRpc({
  id: "96108773d83181d2a0248149fecb5d6176770cc4ba97e7b6c019d4747c9ea510",
  name: "openFiscalDay",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => openFiscalDay.__executeServer(opts));
const openFiscalDay = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).handler(openFiscalDay_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  await ensureAdmin(context.supabase, context.userId, orgId);
  const {
    env,
    device,
    row
  } = await loadDevice(orgId);
  const {
    data: openRow
  } = await supabaseAdmin.from("fiscal_days").select("id").eq("org_id", orgId).eq("status", "open").maybeSingle();
  if (openRow) throw new Error("A fiscal day is already open");
  const nextDayNo = (row.last_fiscal_day_no ?? 0) + 1;
  const openedAt = (/* @__PURE__ */ new Date()).toISOString();
  const res = await openDay(env, device, nextDayNo, openedAt);
  const status = res.ok ? "open" : "error";
  const {
    data: inserted,
    error
  } = await supabaseAdmin.from("fiscal_days").insert({
    org_id: orgId,
    fiscal_day_no: nextDayNo,
    opened_at: openedAt,
    status,
    opening_response: res.ok ? res.data : {
      error: redactFdmsError(res.error)
    }
  }).select("*").single();
  if (error) throw new Error(error.message);
  if (res.ok) {
    await supabaseAdmin.from("organization_fiscal_config").update({
      last_fiscal_day_no: nextDayNo,
      last_receipt_counter: 0
    }).eq("org_id", orgId);
  } else {
    throw new Error(`FDMS OpenDay failed: ${redactFdmsError(res.error).message}`);
  }
  return {
    id: inserted.id,
    fiscal_day_no: inserted.fiscal_day_no,
    opened_at: inserted.opened_at,
    closed_at: inserted.closed_at,
    status: inserted.status,
    totals: inserted.totals
  };
});
const closeFiscalDay_createServerFn_handler = createServerRpc({
  id: "193fc5971a8908606af82fcef861697128c26abaf78286d771fcf90cb9327770",
  name: "closeFiscalDay",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => closeFiscalDay.__executeServer(opts));
const closeFiscalDay = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).handler(closeFiscalDay_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  await ensureAdmin(context.supabase, context.userId, orgId);
  const {
    env,
    device
  } = await loadDevice(orgId);
  const deviceConfig = await latestDeviceConfig(orgId, env, device);
  const {
    data: openRow
  } = await supabaseAdmin.from("fiscal_days").select("*").eq("org_id", orgId).eq("status", "open").maybeSingle();
  if (!openRow) throw new Error("No fiscal day is currently open");
  const {
    data: acceptedStatuses
  } = await supabaseAdmin.from("current_receipt_status").select("document_id").eq("org_id", orgId).eq("status", "Accepted");
  const acceptedDocumentIds = (acceptedStatuses ?? []).map((r) => r.document_id).filter((documentId) => Boolean(documentId));
  const {
    data: receipts
  } = acceptedDocumentIds.length ? await supabaseAdmin.from("documents").select("total, tax_amount, tax_rate, discount, line_items").eq("org_id", orgId).eq("fiscal_day_no", openRow.fiscal_day_no).in("id", acceptedDocumentIds) : {
    data: []
  };
  const totals = buildFiscalDayCounters(receipts ?? [], await loadOrganizationCurrency(orgId), deviceConfig);
  const closedAt = (/* @__PURE__ */ new Date()).toISOString();
  const res = await closeDay(env, device, openRow.fiscal_day_no, totals, closedAt);
  if (!res.ok) {
    await supabaseAdmin.from("fiscal_days").update({
      status: "error",
      closing_response: {
        error: redactFdmsError(res.error).message
      }
    }).eq("id", openRow.id);
    throw new Error(`FDMS CloseDay failed: ${redactFdmsError(res.error).message}`);
  }
  const {
    data: updated,
    error
  } = await supabaseAdmin.from("fiscal_days").update({
    status: "closed",
    closed_at: closedAt,
    totals,
    closing_response: res.data
  }).eq("id", openRow.id).select("*").single();
  if (error) throw new Error(error.message);
  return {
    id: updated.id,
    fiscal_day_no: updated.fiscal_day_no,
    opened_at: updated.opened_at,
    closed_at: updated.closed_at,
    status: updated.status,
    totals: updated.totals
  };
});
const listFiscalDays_createServerFn_handler = createServerRpc({
  id: "b73683f3df0dbdedf64cccb0f889ee0840b5683df33bbd67f4e60b523aa55a00",
  name: "listFiscalDays",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => listFiscalDays.__executeServer(opts));
const listFiscalDays = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(listFiscalDays_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  const {
    data
  } = await supabaseAdmin.from("fiscal_days").select("*").eq("org_id", orgId).order("fiscal_day_no", {
    ascending: false
  }).limit(50);
  return (data ?? []).map((r) => ({
    id: r.id,
    fiscal_day_no: r.fiscal_day_no,
    opened_at: r.opened_at,
    closed_at: r.closed_at,
    status: r.status,
    totals: r.totals
  }));
});
const submitInvoiceToZimra_createServerFn_handler = createServerRpc({
  id: "ccfaa7b3e8430b8438e213dfaf47a4ba9469d265ffde5307bb6dfe41ac9d2a6c",
  name: "submitInvoiceToZimra",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => submitInvoiceToZimra.__executeServer(opts));
const submitInvoiceToZimra = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => object({
  documentId: string().uuid()
}).parse(data)).handler(submitInvoiceToZimra_createServerFn_handler, async ({
  data,
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  await ensureAdmin(context.supabase, context.userId, orgId);
  const {
    data: doc,
    error: docErr
  } = await supabaseAdmin.from("documents").select("*, client:clients(company_name, address, email, phone)").eq("id", data.documentId).eq("org_id", orgId).maybeSingle();
  if (docErr || !doc) throw new Error("Document not found");
  if (doc.doc_type !== "invoice") throw new Error("Only invoices can be fiscalised");
  const {
    data: currentStatus
  } = await supabaseAdmin.from("current_receipt_status").select("status").eq("document_id", doc.id).maybeSingle();
  if (currentStatus?.status === "Accepted") throw new Error("Already submitted to ZIMRA");
  const {
    env,
    device
  } = await loadDevice(orgId);
  const deviceConfig = await latestDeviceConfig(orgId, env, device);
  const allocation = await FiscalCounterManager.allocateInvoiceCounters(orgId, doc.id);
  const receiptCurrency = await loadOrganizationCurrency(orgId);
  const lineItems = doc.line_items ?? [];
  const totals = computeTotals(lineItems, Number(doc.tax_rate), Number(doc.discount));
  const receiptGlobalNo = allocation.receiptGlobalNo;
  const receiptCounter = allocation.receiptCounter;
  const fiscalDayNo = allocation.fiscalDayNo;
  const receiptDate = (/* @__PURE__ */ new Date()).toISOString().slice(0, 19);
  const previousReceiptHash = await loadPreviousReceiptHash(orgId, device.deviceId, fiscalDayNo);
  const taxConfig = resolveTaxConfig(deviceConfig, Number(doc.tax_rate));
  const taxes = [{
    taxCode: taxConfig.taxCode,
    taxPercent: taxConfig.taxPercent,
    taxAmount: Math.round(totals.tax_amount * 100)
  }];
  const {
    hashBase64,
    verificationCode
  } = await computeReceiptHash({
    deviceId: device.deviceId,
    receiptType: "FiscalInvoice",
    receiptCurrency,
    receiptGlobalNo,
    receiptDate,
    receiptTotalCents: Math.round(totals.total * 100),
    taxes,
    previousReceiptHash
  });
  const receiptPayload = {
    receiptType: "FiscalInvoice",
    receiptCurrency,
    receiptCounter,
    receiptGlobalNo,
    invoiceNo: allocation.invoiceNo,
    buyerData: doc.client ? {
      buyerRegisterName: doc.client.company_name,
      buyerContacts: {
        email: doc.client.email ?? void 0,
        phoneNo: doc.client.phone ?? void 0
      },
      buyerAddress: doc.client.address ?? void 0
    } : void 0,
    receiptNotes: doc.notes ?? void 0,
    receiptDate,
    receiptLinesTaxInclusive: false,
    receiptLines: lineItems.map((li, idx) => ({
      receiptLineType: "Sale",
      receiptLineNo: idx + 1,
      receiptLineName: li.description,
      receiptLinePrice: li.unit_price,
      receiptLineQuantity: li.quantity,
      receiptLineTotal: Math.round(li.quantity * li.unit_price * 100),
      taxCode: taxConfig.taxCode,
      taxPercent: taxConfig.taxPercent
    })),
    receiptTaxes: [{
      taxCode: taxConfig.taxCode,
      taxPercent: taxConfig.taxPercent,
      taxAmount: Math.round(totals.tax_amount * 100),
      salesAmountWithTax: Math.round(totals.total * 100)
    }],
    receiptPayments: [{
      moneyTypeCode: DEFAULT_MONEY_TYPE_CODE,
      paymentAmount: Math.round(totals.total * 100)
    }],
    receiptTotal: Math.round(totals.total * 100),
    receiptPrintForm: "InvoiceA4",
    receiptDeviceSignature: {
      hash: hashBase64
    }
  };
  validateReceiptLines(receiptPayload.receiptLines, receiptPayload.receiptLinesTaxInclusive);
  validateReceiptPayments(deviceConfig, receiptPayload.receiptPayments, receiptPayload.receiptTotal);
  await appendReceiptStatus(doc.id, orgId, "Ready", "Receipt payload prepared");
  await appendReceiptStatus(doc.id, orgId, "Signed", "Receipt hash and verification code generated", {
    receipt_global_no: receiptGlobalNo,
    receipt_counter: receiptCounter,
    verification_code: verificationCode
  });
  await appendReceiptStatus(doc.id, orgId, "Submitted", "Submitting receipt to FDMS");
  const submission = await submitReceipt(env, device, receiptPayload);
  if (!submission.ok) {
    await appendReceiptStatus(doc.id, orgId, "Rejected", submission.error.message, submission.error.raw ?? null);
    await supabaseAdmin.from("documents").update({
      fiscal_error: submission.error.message,
      fiscal_response: submission.error.raw ?? null,
      fiscal_device_id: device.deviceId,
      fiscal_submitted_at: (/* @__PURE__ */ new Date()).toISOString()
    }).eq("id", doc.id);
    throw new Error(`FDMS SubmitReceipt failed: ${redactFdmsError(submission.error).message}`);
  }
  const qrUrl = `https://receipt.zimra.co.zw/${device.deviceId}/${receiptGlobalNo}/${verificationCode}`;
  const submittedAt = (/* @__PURE__ */ new Date()).toISOString();
  await appendReceiptStatus(doc.id, orgId, "Accepted", "FDMS accepted receipt", submission.data);
  await supabaseAdmin.from("documents").update({
    fiscal_day_no: fiscalDayNo,
    fiscal_device_id: device.deviceId,
    receipt_global_no: receiptGlobalNo,
    receipt_counter: receiptCounter,
    receipt_hash: hashBase64,
    verification_code: verificationCode,
    receipt_qr_url: qrUrl,
    fiscal_submitted_at: submittedAt,
    fiscal_response: submission.data,
    fiscal_error: null
  }).eq("id", doc.id);
  await FiscalCounterManager.markSubmitted(doc.id, submittedAt);
  return {
    receipt_global_no: receiptGlobalNo,
    receipt_counter: receiptCounter,
    verification_code: verificationCode,
    fiscal_day_no: fiscalDayNo
  };
});
const getCurrentFiscalDay_createServerFn_handler = createServerRpc({
  id: "8071501d4737b90b81697bc956d93debcb5ebaaa4a88a9cab55afea92c40ee50",
  name: "getCurrentFiscalDay",
  filename: "src/lib/fiscal.functions.ts"
}, (opts) => getCurrentFiscalDay.__executeServer(opts));
const getCurrentFiscalDay = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(getCurrentFiscalDay_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.supabase, context.userId);
  const {
    data
  } = await supabaseAdmin.from("fiscal_days").select("*").eq("org_id", orgId).eq("status", "open").maybeSingle();
  if (!data) return null;
  return {
    id: data.id,
    fiscal_day_no: data.fiscal_day_no,
    opened_at: data.opened_at,
    closed_at: data.closed_at,
    status: data.status,
    totals: data.totals
  };
});
export {
  closeFiscalDay_createServerFn_handler,
  getCurrentFiscalDay_createServerFn_handler,
  getFiscalConfig_createServerFn_handler,
  listFiscalDays_createServerFn_handler,
  onboardFiscalDeviceSecrets_createServerFn_handler,
  openFiscalDay_createServerFn_handler,
  submitInvoiceToZimra_createServerFn_handler,
  testDeviceConnection_createServerFn_handler,
  updateFiscalConfig_createServerFn_handler
};
