import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import type { Database, Json } from "@/integrations/supabase/types";
import { computeReceiptHash } from "@/lib/fiscal/receiptHash";
import { FiscalCounterManager as ReceiptCounterManager } from "@/lib/fiscalCounterManager";
import {
  openDay as fdmsOpenDay,
  closeDay as fdmsCloseDay,
  submitReceipt as fdmsSubmitReceipt,
  getDeviceConfig,
  type FdmsDevice,
  type FdmsEnv,
} from "@/lib/fiscal/zimra.server";
import { computeTotals as calculateTotals } from "@/lib/calc";
import type { LineItem } from "@/lib/calc";

type UserClient = SupabaseClient<Database>;

type ReceiptStatus = "Draft" | "Ready" | "Signed" | "Submitted" | "Accepted" | "Rejected" | "Retrying" | "Cancelled";

async function appendReceiptStatus(
  documentId: string,
  orgId: string,
  status: ReceiptStatus,
  message?: string,
  metadata?: Json,
) {
  const { error } = await supabaseAdmin.from("receipt_status").insert({
    document_id: documentId,
    org_id: orgId,
    status,
    message: message ?? null,
    metadata: metadata ?? null,
  });
  if (error) throw new Error(error.message);
}

/**
 * Load the prior accepted receipt hash for the ZIMRA hash chain.
 *
 * ZIMRA starts a new previousReceiptHash chain for each fiscal day, so the
 * first accepted receipt on a device's fiscal day intentionally receives an
 * empty previous hash. The device filter prevents receipts from other active or
 * historical devices in the same organization from being linked into this
 * device's chain.
 */
async function loadPreviousReceiptHash(
  orgId: string,
  deviceId: string,
  fiscalDayNo: number,
): Promise<string> {
  const { data: acceptedStatusesForHash, error: statusError } = await supabaseAdmin
    .from("current_receipt_status")
    .select("document_id")
    .eq("org_id", orgId)
    .eq("status", "Accepted");
  if (statusError) throw new Error(statusError.message);

  const acceptedIdsForHash = (acceptedStatusesForHash ?? [])
    .map((r) => r.document_id)
    .filter((documentId): documentId is string => Boolean(documentId));
  if (!acceptedIdsForHash.length) return "";

  const { data: prevRow, error: prevError } = await supabaseAdmin
    .from("documents")
    .select("receipt_hash")
    .eq("org_id", orgId)
    .eq("fiscal_device_id", deviceId)
    .eq("fiscal_day_no", fiscalDayNo)
    .in("id", acceptedIdsForHash)
    .not("receipt_hash", "is", null)
    .order("receipt_global_no", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (prevError) throw new Error(prevError.message);

  return prevRow?.receipt_hash ?? "";
}

// ============================================================
// Types
// ============================================================

export type FiscalConfig = {
  org_id: string;
  enabled: boolean;
  environment: "test" | "prod";
  device_id: string | null;
  device_serial: string | null;
  device_address: string | null;
  device_model: string | null;
  device_model_name: string | null;
  device_model_version: string | null;
  tax_payer_name: string | null;
  tax_payer_tin: string | null;
  vat_number: string | null;
  trade_name: string | null;
  has_certificate: boolean;
  has_private_key: boolean;
  has_activation_key: boolean;
  device_address: string | null;
  device_model_version: string | null;
  device_operating_mode: string;
  last_fiscal_day_no: number | null;
  last_receipt_global_no: number;
  last_receipt_counter: number;
};

export type FiscalDay = {
  id: string;
  fiscal_day_no: number;
  opened_at: string;
  closed_at: string | null;
  status: "open" | "closed" | "error";
  totals: Json | null;
};

// ============================================================
// Helpers (server-only)
// ============================================================

async function ensureAdmin(supabase: UserClient, userId: string, orgId: string) {
  const { data } = await supabase.rpc("has_org_role", {
    _user_id: userId,
    _org_id: orgId,
    _min_role: "admin",
  });
  if (!data) throw new Error("Admin or owner role required");
}


const SECRET_FIELD_PATTERN = /(activation[_-]?key|private[_-]?key|certificate|cert(ificate)?[_-]?pem|secret|authorization|bearer|token)/i;

function redactString(value: string): string {
  return value
    .replace(/-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----/g, "[REDACTED_PEM]")
    .replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/gi, "Bearer [REDACTED]");
}

function redactSecrets<T>(value: T): T {
  if (typeof value === "string") return redactString(value) as T;
  if (Array.isArray(value)) return value.map((item) => redactSecrets(item)) as T;
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, entry]) => [
        key,
        SECRET_FIELD_PATTERN.test(key) ? "[REDACTED]" : redactSecrets(entry),
      ]),
    ) as T;
  }
  return value;
}

function redactFdmsError(error: { message: string; raw?: unknown }) {
  return { ...error, message: redactString(error.message), raw: redactSecrets(error.raw) };
}


async function activeEncryptedPayload(orgId: string, table: "device_certificates" | "device_keys") {
  const { data } = await (supabaseAdmin as any)
    .from(table)
    .select("encrypted_payload")
    .eq("org_id", orgId)
    .eq("active", true)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  return (data?.encrypted_payload as string | null | undefined) ?? null;
}

async function hasActiveFiscalSecret(orgId: string, table: "device_certificates" | "device_keys") {
  const { data } = await (supabaseAdmin as any)
    .from(table)
    .select("id")
    .eq("org_id", orgId)
    .eq("active", true)
    .limit(1)
    .maybeSingle();
  return Boolean(data);
}

async function activeOrgId(supabase: UserClient, userId: string): Promise<string> {
  const { data } = await supabase
    .from("profiles")
    .select("active_org_id")
    .eq("user_id", userId)
    .maybeSingle();
  const id = data?.active_org_id ?? null;
  if (!id) throw new Error("No active organization");
  return id;
}

function stripSecrets(row: Record<string, unknown>, secretState?: { hasCertificate: boolean; hasPrivateKey: boolean }): FiscalConfig {
  return {
    org_id: row.org_id as string,
    enabled: Boolean(row.enabled),
    environment: (row.environment as "test" | "prod") ?? "test",
    device_id: (row.device_id as string) ?? null,
    device_serial: (row.device_serial as string) ?? null,
    device_address: (row.device_address as string) ?? null,
    device_model: (row.device_model as string) ?? null,
    device_model_name: ((row.device_model_name ?? row.device_model) as string) ?? null,
    device_model_version: (row.device_model_version as string) ?? null,
    tax_payer_name: (row.tax_payer_name as string) ?? null,
    tax_payer_tin: (row.tax_payer_tin as string) ?? null,
    vat_number: (row.vat_number as string) ?? null,
    trade_name: (row.trade_name as string) ?? null,
    has_certificate: secretState?.hasCertificate ?? Boolean(row.certificate_secret_ref),
    has_private_key: secretState?.hasPrivateKey ?? Boolean(row.private_key_secret_ref),
    has_activation_key: Boolean(row.activation_key_secret_ref ?? row.activation_key_encrypted ?? row.activation_key),
    device_address: (row.device_address as string) ?? null,
    device_model_version: (row.device_model_version as string) ?? null,
    device_operating_mode: (row.device_operating_mode as string) ?? "Online",
    last_fiscal_day_no: (row.last_fiscal_day_no as number) ?? null,
    last_receipt_global_no: Number(row.last_receipt_global_no ?? 0),
    last_receipt_counter: Number(row.last_receipt_counter ?? 0),
  };
}


type FdmsConfig = Record<string, unknown>;

type FdmsTaxConfig = {
  taxCode: string;
  taxPercent: number;
  taxID?: number;
};

type ReceiptPaymentPayload = { moneyTypeCode: string; paymentAmount: number };

const DEFAULT_RECEIPT_TYPE = "FiscalInvoice";
const DEFAULT_MONEY_TYPE_CODE = "Cash";
const TAX_CONFIG_ARRAY_KEYS = ["taxes", "taxRates", "taxTable", "vatRates", "applicableTaxes", "taxConfigurations"];
const MONEY_TYPE_ARRAY_KEYS = ["moneyTypes", "paymentTypes", "payments", "paymentMethods", "moneyTypeCodes"];

function asRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function findConfigArray(config: FdmsConfig, keys: string[]): unknown[] {
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

function firstString(record: Record<string, unknown>, keys: string[]): string | null {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) return value.trim();
    if (typeof value === "number" && Number.isFinite(value)) return String(value);
  }
  return null;
}

function firstNumber(record: Record<string, unknown>, keys: string[]): number | null {
  for (const key of keys) {
    const value = record[key];
    const number = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN;
    if (Number.isFinite(number)) return number;
  }
  return null;
}

function configuredTaxes(config: FdmsConfig): FdmsTaxConfig[] {
  return findConfigArray(config, TAX_CONFIG_ARRAY_KEYS)
    .map(asRecord)
    .filter((tax): tax is Record<string, unknown> => Boolean(tax))
    .map((tax) => {
      const taxCode = firstString(tax, ["taxCode", "code", "taxID", "taxId", "id"]);
      const taxPercent = firstNumber(tax, ["taxPercent", "taxPercentage", "taxRate", "rate", "percent"]);
      const taxID = firstNumber(tax, ["taxID", "taxId", "id"]);
      return taxCode && taxPercent !== null ? { taxCode, taxPercent, taxID: taxID ?? undefined } : null;
    })
    .filter((tax): tax is FdmsTaxConfig => Boolean(tax));
}

function configuredMoneyTypeCodes(config: FdmsConfig): Set<string> {
  return new Set(
    findConfigArray(config, MONEY_TYPE_ARRAY_KEYS)
      .map((entry) => {
        if (typeof entry === "string") return entry;
        const record = asRecord(entry);
        return record ? firstString(record, ["moneyTypeCode", "code", "name", "id"]) : null;
      })
      .filter((code): code is string => Boolean(code)),
  );
}

function resolveTaxConfig(config: FdmsConfig, taxRate: number): FdmsTaxConfig {
  const tax = configuredTaxes(config).find((entry) => Math.round(entry.taxPercent * 100) === Math.round(taxRate * 100));
  if (!tax) throw new Error(`Unsupported ZIMRA tax rate ${taxRate}%; refresh FDMS GetConfig or configure an allowed tax rate for this device`);
  return tax;
}

function validateReceiptPayments(config: FdmsConfig, payments: ReceiptPaymentPayload[], receiptTotal: number) {
  const allowedCodes = configuredMoneyTypeCodes(config);
  if (allowedCodes.size) {
    for (const payment of payments) {
      if (!allowedCodes.has(payment.moneyTypeCode)) throw new Error(`Unsupported ZIMRA payment type ${payment.moneyTypeCode}`);
    }
  }
  const paid = payments.reduce((sum, payment) => sum + Number(payment.paymentAmount || 0), 0);
  if (Math.round(paid) !== Math.round(receiptTotal)) throw new Error("Receipt payments must equal the receipt total");
}

function validateReceiptLines(lines: Array<{ receiptLineNo: number; receiptLinePrice: number; receiptLineQuantity: number; receiptLineTotal: number }>, taxInclusive: boolean) {
  if (taxInclusive !== false) throw new Error("Only tax-exclusive receipt lines are supported by this invoice model");
  for (const line of lines) {
    const expected = Math.round(Number(line.receiptLineQuantity) * Number(line.receiptLinePrice) * 100);
    if (expected !== Math.round(Number(line.receiptLineTotal))) {
      throw new Error(`Receipt line ${line.receiptLineNo} total does not match quantity × price`);
    }
  }
}

async function fetchAndStoreDeviceConfig(orgId: string, env: FdmsEnv, device: FdmsDevice): Promise<FdmsConfig> {
  const result = await getDeviceConfig(env, device);
  if (!result.ok) throw new Error(`FDMS GetConfig failed: ${redactFdmsError(result.error).message}`);
  await (supabaseAdmin as any).from("device_configuration").insert({
    org_id: orgId,
    device_id: orgId,
    fdms_device_id: device.deviceId,
    environment: env,
    source: "fdms",
    configuration: result.data as never,
  });
  return result.data as FdmsConfig;
}

async function latestDeviceConfig(orgId: string, env: FdmsEnv, device: FdmsDevice): Promise<FdmsConfig> {
  const { data, error } = await (supabaseAdmin as any)
    .from("device_configuration")
    .select("configuration")
    .eq("org_id", orgId)
    .eq("fdms_device_id", device.deviceId)
    .eq("environment", env)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data?.configuration as FdmsConfig | null) ?? fetchAndStoreDeviceConfig(orgId, env, device);
}

type FiscalDayCounter = {
  receiptType: string;
  receiptCurrency: string;
  taxCode?: string;
  taxPercent?: number;
  moneyTypeCode?: string;
  receiptQuantity?: number;
  receiptTotalAmount?: number;
  taxAmount?: number;
  paymentAmount?: number;
};

function buildFiscalDayCounters(receipts: Array<{ total: unknown; tax_amount: unknown; tax_rate: unknown; line_items: unknown; discount: unknown }>, receiptCurrency: string, config: FdmsConfig) {
  const counters = new Map<string, FiscalDayCounter>();
  const add = (key: string, patch: FiscalDayCounter, amountKey: "receiptTotalAmount" | "taxAmount" | "paymentAmount", amount: number, quantity = 0) => {
    const current = counters.get(key) ?? patch;
    current[amountKey] = Math.round((Number(current[amountKey] ?? 0) + amount) * 100) / 100;
    if (quantity) current.receiptQuantity = Number(current.receiptQuantity ?? 0) + quantity;
    counters.set(key, current);
  };
  for (const receipt of receipts) {
    const taxRate = Number(receipt.tax_rate ?? 0);
    const tax = resolveTaxConfig(config, taxRate);
    const totals = calculateTotals((receipt.line_items as unknown as LineItem[]) ?? [], taxRate, Number(receipt.discount ?? 0));
    add(`SaleByTax:${tax.taxCode}:${receiptCurrency}`, { receiptType: DEFAULT_RECEIPT_TYPE, receiptCurrency, taxCode: tax.taxCode, taxPercent: tax.taxPercent }, "receiptTotalAmount", totals.total, 1);
    add(`SaleTaxByTax:${tax.taxCode}:${receiptCurrency}`, { receiptType: DEFAULT_RECEIPT_TYPE, receiptCurrency, taxCode: tax.taxCode, taxPercent: tax.taxPercent }, "taxAmount", totals.tax_amount);
    add(`Payment:${DEFAULT_MONEY_TYPE_CODE}:${receiptCurrency}`, { receiptType: DEFAULT_RECEIPT_TYPE, receiptCurrency, moneyTypeCode: DEFAULT_MONEY_TYPE_CODE }, "paymentAmount", totals.total);
  }
  return Array.from(counters.values());
}

// ============================================================
// Server functions
// ============================================================

/** Fetch fiscal config for the caller's active org. Never returns cert/key material. */
export const getFiscalConfig = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FiscalConfig | null> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    const { data } = await supabaseAdmin
      .from("organization_fiscal_config")
      .select("*")
      .eq("org_id", orgId)
      .maybeSingle();
    if (!data) return null;
    return stripSecrets(data as Record<string, unknown>, {
      hasCertificate: await hasActiveFiscalSecret(orgId, "device_certificates"),
      hasPrivateKey: await hasActiveFiscalSecret(orgId, "device_keys"),
    });
  });

const updateSchema = z.object({
  enabled: z.boolean().optional(),
  environment: z.enum(["test", "prod"]).optional(),
  device_id: z.string().nullable().optional(),
  device_serial: z.string().nullable().optional(),
  device_address: z.string().nullable().optional(),
  device_model: z.string().nullable().optional(),
  device_model_name: z.string().nullable().optional(),
  device_model_version: z.string().nullable().optional(),
  activation_key_secret_ref: z.string().nullable().optional(),
  tax_payer_name: z.string().nullable().optional(),
  tax_payer_tin: z.string().nullable().optional(),
  vat_number: z.string().nullable().optional(),
  trade_name: z.string().nullable().optional(),
  certificate_secret_ref: z.string().nullable().optional(),
  private_key_secret_ref: z.string().nullable().optional(),
  device_operating_mode: z.string().optional(),
}).strict();

export const updateFiscalConfig = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => updateSchema.parse(data))
  .handler(async ({ data, context }): Promise<FiscalConfig> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    await ensureAdmin(context.supabase, context.userId, orgId);

    // Normalize: turn empty strings into nulls
    const cleaned: Record<string, unknown> = { ...data };
    for (const k of Object.keys(cleaned)) {
      if (cleaned[k] === "") cleaned[k] = null;
    }

    const { data: existing } = await supabaseAdmin
      .from("organization_fiscal_config")
      .select("org_id")
      .eq("org_id", orgId)
      .maybeSingle();

    if (existing) {
      const { data: updated, error } = await supabaseAdmin
        .from("organization_fiscal_config")
        .update(cleaned as never)
        .eq("org_id", orgId)
        .select("*")
        .single();
      if (error) throw new Error(error.message);
      return stripSecrets(updated as Record<string, unknown>);
    }

    const insertPayload = { ...cleaned, org_id: orgId } as never;
    const { data: inserted, error } = await supabaseAdmin
      .from("organization_fiscal_config")
      .insert(insertPayload)
      .select("*")
      .single();
    if (error) throw new Error(error.message);
    return stripSecrets(inserted as Record<string, unknown>);
  });

type FiscalSecretStorage = typeof import("@/lib/fiscal/secretStorage");

const fiscalSecretStorageModule = "@/lib/fiscal/secretStorage";

async function loadFiscalSecretStorage(): Promise<FiscalSecretStorage> {
  return import(/* @vite-ignore */ fiscalSecretStorageModule);
}

const secureOnboardingSchema = z.object({
  activation_key: z.string().min(1).optional(),
  certificate_pem: z.string().min(1).optional(),
  private_key_pem: z.string().min(1).optional(),
  key_id: z.string().min(1).default("server-managed"),
  valid_from: z.string().datetime().nullable().optional(),
  valid_until: z.string().datetime().nullable().optional(),
}).strict();

async function assertFiscalSecretStorageReady(data: z.infer<typeof secureOnboardingSchema>) {
  if (data.activation_key || data.certificate_pem || data.private_key_pem) {
    await loadFiscalSecretStorage();
  }
}

async function ensureFiscalConfigRow(orgId: string) {
  const { error } = await supabaseAdmin
    .from("organization_fiscal_config")
    .upsert({ org_id: orgId } as never, { onConflict: "org_id", ignoreDuplicates: true });
  if (error) throw new Error(error.message);
}

/** Dedicated server-side onboarding flow for encrypting and storing fiscal secrets. */
export const onboardFiscalDeviceSecrets = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => secureOnboardingSchema.parse(data))
  .handler(async ({ data, context }): Promise<{ ok: true }> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    await ensureAdmin(context.supabase, context.userId, orgId);

    await assertFiscalSecretStorageReady(data);
    await ensureFiscalConfigRow(orgId);

    const { encryptFiscalSecret, sha256Hex } = await loadFiscalSecretStorage();

    const now = new Date().toISOString();
    const validFrom = data.valid_from ?? now;

    if (data.activation_key) {
      await supabaseAdmin
        .from("organization_fiscal_config")
        .update({
          activation_key_encrypted: await encryptFiscalSecret(data.activation_key),
          activation_key_id: data.key_id,
          activation_key_secret_ref: `organization_fiscal_config:${orgId}:activation_key_encrypted`,
        } as never)
        .eq("org_id", orgId);
    }

    if (data.certificate_pem) {
      await (supabaseAdmin as any).from("device_certificates").update({ active: false }).eq("org_id", orgId);
      const { data: certRow, error } = await (supabaseAdmin as any)
        .from("device_certificates")
        .insert({
          org_id: orgId,
          encrypted_payload: await encryptFiscalSecret(data.certificate_pem),
          key_id: data.key_id,
          thumbprint: await sha256Hex(data.certificate_pem),
          active: true,
          valid_from: validFrom,
          valid_until: data.valid_until ?? null,
        })
        .select("id")
        .single();
      if (error) throw new Error(error.message);
      await supabaseAdmin
        .from("organization_fiscal_config")
        .update({ certificate_secret_ref: `device_certificates:${certRow.id}` } as never)
        .eq("org_id", orgId);
    }

    if (data.private_key_pem) {
      await (supabaseAdmin as any).from("device_keys").update({ active: false }).eq("org_id", orgId);
      const { data: keyRow, error } = await (supabaseAdmin as any)
        .from("device_keys")
        .insert({
          org_id: orgId,
          encrypted_payload: await encryptFiscalSecret(data.private_key_pem),
          key_id: data.key_id,
          thumbprint: await sha256Hex(data.private_key_pem),
          active: true,
          valid_from: validFrom,
          valid_until: data.valid_until ?? null,
        })
        .select("id")
        .single();
      if (error) throw new Error(error.message);
      await supabaseAdmin
        .from("organization_fiscal_config")
        .update({ private_key_secret_ref: `device_keys:${keyRow.id}` } as never)
        .eq("org_id", orgId);
    }

    return { ok: true };
  });

async function loadOrganizationCurrency(orgId: string): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("organization_profiles")
    .select("currency")
    .eq("org_id", orgId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data?.currency?.trim() || "USD").toUpperCase();
}

async function loadDevice(orgId: string): Promise<{
  env: FdmsEnv;
  device: FdmsDevice;
  row: Record<string, unknown>;
}> {
  const { data } = await supabaseAdmin
    .from("organization_fiscal_config")
    .select("*")
    .eq("org_id", orgId)
    .maybeSingle();
  if (!data) throw new Error("Fiscal config not found");
  const configRow = data as Record<string, unknown>;
  const { decryptFiscalSecret } = await loadFiscalSecretStorage();
  if (!data.enabled) throw new Error("Fiscalisation is disabled for this organization");
  if (!data.device_id) throw new Error("Device ID is not configured");
  return {
    env: (data.environment as FdmsEnv) ?? "test",
    device: {
      deviceId: String(data.device_id),
      deviceSerialNo: (data.device_serial as string) ?? null,
      activationKey: await decryptFiscalSecret((configRow.activation_key_encrypted as string | null) ?? null),
      certificatePem: await decryptFiscalSecret(await activeEncryptedPayload(orgId, "device_certificates")),
      privateKeyPem: await decryptFiscalSecret(await activeEncryptedPayload(orgId, "device_keys")),
    },
    row: data as Record<string, unknown>,
  };
}

/** Test the connection to FDMS by fetching the device configuration. */
export const testDeviceConnection = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<{ ok: boolean; message: string; data?: Json }> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    await ensureAdmin(context.supabase, context.userId, orgId);
    const { env, device } = await loadDevice(orgId);
    try {
      const data = await fetchAndStoreDeviceConfig(orgId, env, device);
      return { ok: true, message: "Device reachable", data: data as unknown as Json };
    } catch (e) {
      return { ok: false, message: e instanceof Error ? e.message : "Network error" };
    }
  });

/** Open a new fiscal day for the org. */
export const openFiscalDay = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FiscalDay> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    await ensureAdmin(context.supabase, context.userId, orgId);
    const { env, device, row } = await loadDevice(orgId);

    // Ensure no day is currently open
    const { data: openRow } = await supabaseAdmin
      .from("fiscal_days")
      .select("id")
      .eq("org_id", orgId)
      .eq("status", "open")
      .maybeSingle();
    if (openRow) throw new Error("A fiscal day is already open");

    const nextDayNo = ((row.last_fiscal_day_no as number) ?? 0) + 1;
    const openedAt = new Date().toISOString();

    const res = await fdmsOpenDay(env, device, nextDayNo, openedAt);
    const status = res.ok ? "open" : "error";

    const { data: inserted, error } = await supabaseAdmin
      .from("fiscal_days")
      .insert({
        org_id: orgId,
        fiscal_day_no: nextDayNo,
        opened_at: openedAt,
        status,
        opening_response: res.ok ? (res.data as unknown as Json) : ({ error: redactFdmsError(res.error) } as unknown as Json),
      })
      .select("*")
      .single();
    if (error) throw new Error(error.message);

    if (res.ok) {
      await supabaseAdmin
        .from("organization_fiscal_config")
        .update({ last_fiscal_day_no: nextDayNo, last_receipt_counter: 0 })
        .eq("org_id", orgId);
    } else {
      throw new Error(`FDMS OpenDay failed: ${redactFdmsError(res.error).message}`);
    }

    return {
      id: inserted.id,
      fiscal_day_no: inserted.fiscal_day_no,
      opened_at: inserted.opened_at,
      closed_at: inserted.closed_at,
      status: inserted.status as "open" | "closed" | "error",
      totals: inserted.totals,
    };
  });

/** Close the currently open fiscal day. */
export const closeFiscalDay = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FiscalDay> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    await ensureAdmin(context.supabase, context.userId, orgId);
    const { env, device } = await loadDevice(orgId);
    const deviceConfig = await latestDeviceConfig(orgId, env, device);

    const { data: openRow } = await supabaseAdmin
      .from("fiscal_days")
      .select("*")
      .eq("org_id", orgId)
      .eq("status", "open")
      .maybeSingle();
    if (!openRow) throw new Error("No fiscal day is currently open");

    // Sum receipts accepted during this day. The current status comes from the immutable receipt_status event log.
    const { data: acceptedStatuses } = await supabaseAdmin
      .from("current_receipt_status")
      .select("document_id")
      .eq("org_id", orgId)
      .eq("status", "Accepted");
    const acceptedDocumentIds = (acceptedStatuses ?? [])
      .map((r) => r.document_id)
      .filter((documentId): documentId is string => Boolean(documentId));
    const { data: receipts } = acceptedDocumentIds.length
      ? await supabaseAdmin
          .from("documents")
          .select("total, tax_amount, tax_rate, discount, line_items")
          .eq("org_id", orgId)
          .eq("fiscal_day_no", openRow.fiscal_day_no)
          .in("id", acceptedDocumentIds)
      : { data: [] };
    const totals = buildFiscalDayCounters(receipts ?? [], await loadOrganizationCurrency(orgId), deviceConfig);
    const closedAt = new Date().toISOString();

    const res = await fdmsCloseDay(env, device, openRow.fiscal_day_no, totals, closedAt);
    if (!res.ok) {
      await supabaseAdmin
        .from("fiscal_days")
        .update({ status: "error", closing_response: { error: redactFdmsError(res.error).message } as unknown as Json })
        .eq("id", openRow.id);
      throw new Error(`FDMS CloseDay failed: ${redactFdmsError(res.error).message}`);
    }

    const { data: updated, error } = await supabaseAdmin
      .from("fiscal_days")
      .update({
        status: "closed",
        closed_at: closedAt,
        totals: totals as unknown as Json,
        closing_response: res.data as unknown as Json,
      })
      .eq("id", openRow.id)
      .select("*")
      .single();
    if (error) throw new Error(error.message);
    return {
      id: updated.id,
      fiscal_day_no: updated.fiscal_day_no,
      opened_at: updated.opened_at,
      closed_at: updated.closed_at,
      status: updated.status as "open" | "closed" | "error",
      totals: updated.totals,
    };
  });

/** List fiscal days for the active org, newest first. */
export const listFiscalDays = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FiscalDay[]> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    const { data } = await supabaseAdmin
      .from("fiscal_days")
      .select("*")
      .eq("org_id", orgId)
      .order("fiscal_day_no", { ascending: false })
      .limit(50);
    return (data ?? []).map((r) => ({
      id: r.id,
      fiscal_day_no: r.fiscal_day_no,
      opened_at: r.opened_at,
      closed_at: r.closed_at,
      status: r.status as "open" | "closed" | "error",
      totals: r.totals,
    }));
  });

/** Submit an invoice as a fiscal receipt to FDMS. */
export const submitInvoiceToZimra = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => z.object({ documentId: z.string().uuid() }).parse(data))
  .handler(async ({ data, context }): Promise<{
    receipt_global_no: number;
    receipt_counter: number;
    verification_code: string;
    fiscal_day_no: number;
  }> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    await ensureAdmin(context.supabase, context.userId, orgId);

    const { data: doc, error: docErr } = await supabaseAdmin
      .from("documents")
      .select("*, client:clients(company_name, address, email, phone)")
      .eq("id", data.documentId)
      .eq("org_id", orgId)
      .maybeSingle();
    if (docErr || !doc) throw new Error("Document not found");
    if (doc.doc_type !== "invoice") throw new Error("Only invoices can be fiscalised");
    const { data: currentStatus } = await supabaseAdmin
      .from("current_receipt_status")
      .select("status")
      .eq("document_id", doc.id)
      .maybeSingle();
    if (currentStatus?.status === "Accepted") throw new Error("Already submitted to ZIMRA");

    const { env, device } = await loadDevice(orgId);
    const deviceConfig = await latestDeviceConfig(orgId, env, device);
    const allocation = await ReceiptCounterManager.allocateInvoiceCounters(orgId, doc.id);
    const receiptCurrency = await loadOrganizationCurrency(orgId);

    const lineItems = (doc.line_items as unknown as LineItem[]) ?? [];
    const totals = calculateTotals(lineItems, Number(doc.tax_rate), Number(doc.discount));
    const receiptGlobalNo = allocation.receiptGlobalNo;
    const receiptCounter = allocation.receiptCounter;
    const fiscalDayNo = allocation.fiscalDayNo;
    const receiptDate = new Date().toISOString().slice(0, 19); // yyyy-MM-ddTHH:mm:ss

    const previousReceiptHash = await loadPreviousReceiptHash(orgId, device.deviceId, fiscalDayNo);

    // Build tax line: single VAT rate for the whole invoice (matches app model).
    const taxConfig = resolveTaxConfig(deviceConfig, Number(doc.tax_rate));
    const taxes = [
      {
        taxCode: taxConfig.taxCode,
        taxPercent: taxConfig.taxPercent,
        taxAmount: Math.round(totals.tax_amount * 100),
      },
    ];

    const { hashBase64, verificationCode } = await computeReceiptHash({
      deviceId: device.deviceId,
      receiptType: "FiscalInvoice",
      receiptCurrency,
      receiptGlobalNo,
      receiptDate,
      receiptTotalCents: Math.round(totals.total * 100),
      taxes,
      previousReceiptHash,
    });

    const receiptPayload = {
      receiptType: "FiscalInvoice",
      receiptCurrency,
      receiptCounter,
      receiptGlobalNo,
      invoiceNo: allocation.invoiceNo,
      buyerData: doc.client
        ? {
            buyerRegisterName: (doc.client as { company_name: string }).company_name,
            buyerContacts: {
              email: (doc.client as { email: string | null }).email ?? undefined,
              phoneNo: (doc.client as { phone: string | null }).phone ?? undefined,
            },
            buyerAddress: (doc.client as { address: string | null }).address ?? undefined,
          }
        : undefined,
      receiptNotes: doc.notes ?? undefined,
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
        taxPercent: taxConfig.taxPercent,
      })),
      receiptTaxes: [
        {
          taxCode: taxConfig.taxCode,
          taxPercent: taxConfig.taxPercent,
          taxAmount: Math.round(totals.tax_amount * 100),
          salesAmountWithTax: Math.round(totals.total * 100),
        },
      ],
      receiptPayments: [
        { moneyTypeCode: DEFAULT_MONEY_TYPE_CODE, paymentAmount: Math.round(totals.total * 100) },
      ],
      receiptTotal: Math.round(totals.total * 100),
      receiptPrintForm: "InvoiceA4",
      receiptDeviceSignature: {
        hash: hashBase64,
      },
    };

    validateReceiptLines(receiptPayload.receiptLines, receiptPayload.receiptLinesTaxInclusive);
    validateReceiptPayments(deviceConfig, receiptPayload.receiptPayments, receiptPayload.receiptTotal);

    await appendReceiptStatus(doc.id, orgId, "Ready", "Receipt payload prepared");
    await appendReceiptStatus(doc.id, orgId, "Signed", "Receipt hash and verification code generated", {
      receipt_global_no: receiptGlobalNo,
      receipt_counter: receiptCounter,
      verification_code: verificationCode,
    } as unknown as Json);
    await appendReceiptStatus(doc.id, orgId, "Submitted", "Submitting receipt to FDMS");

    const submission = await fdmsSubmitReceipt(env, device, receiptPayload);

    if (!submission.ok) {
      await appendReceiptStatus(doc.id, orgId, "Rejected", submission.error.message, (submission.error.raw ?? null) as unknown as Json);
      await supabaseAdmin
        .from("documents")
        .update({
          fiscal_error: submission.error.message,
          fiscal_response: (submission.error.raw ?? null) as unknown as Json,
          fiscal_device_id: device.deviceId,
          fiscal_submitted_at: new Date().toISOString(),
        })
        .eq("id", doc.id);
      throw new Error(`FDMS SubmitReceipt failed: ${redactFdmsError(submission.error).message}`);
    }

    const qrUrl = `https://receipt.zimra.co.zw/${device.deviceId}/${receiptGlobalNo}/${verificationCode}`;
    const submittedAt = new Date().toISOString();

    await appendReceiptStatus(doc.id, orgId, "Accepted", "FDMS accepted receipt", submission.data as unknown as Json);

    await supabaseAdmin
      .from("documents")
      .update({
        fiscal_day_no: fiscalDayNo,
        fiscal_device_id: device.deviceId,
        receipt_global_no: receiptGlobalNo,
        receipt_counter: receiptCounter,
        receipt_hash: hashBase64,
        verification_code: verificationCode,
        receipt_qr_url: qrUrl,
        fiscal_submitted_at: submittedAt,
        fiscal_response: submission.data as unknown as Json,
        fiscal_error: null,
      })
      .eq("id", doc.id);

    await ReceiptCounterManager.markSubmitted(doc.id, submittedAt);

    return {
      receipt_global_no: receiptGlobalNo,
      receipt_counter: receiptCounter,
      verification_code: verificationCode,
      fiscal_day_no: fiscalDayNo,
    };
  });

/** Return the currently open fiscal day for the org, if any. */
export const getCurrentFiscalDay = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<FiscalDay | null> => {
    const orgId = await activeOrgId(context.supabase, context.userId);
    const { data } = await supabaseAdmin
      .from("fiscal_days")
      .select("*")
      .eq("org_id", orgId)
      .eq("status", "open")
      .maybeSingle();
    if (!data) return null;
    return {
      id: data.id,
      fiscal_day_no: data.fiscal_day_no,
      opened_at: data.opened_at,
      closed_at: data.closed_at,
      status: data.status as "open" | "closed" | "error",
      totals: data.totals,
    };
  });
