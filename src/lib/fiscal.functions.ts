import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import type { SupabaseClient } from "@supabase/supabase-js";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import type { Database, Json } from "@/integrations/supabase/types";
import { computeReceiptHash } from "@/lib/fiscal/receiptHash";
import {
  openDay as fdmsOpenDay,
  closeDay as fdmsCloseDay,
  submitReceipt as fdmsSubmitReceipt,
  getDeviceConfig,
  type FdmsDevice,
  type FdmsEnv,
} from "@/lib/fiscal/zimra.server";
import type { LineItem } from "@/lib/calc";
import { computeTotals } from "@/lib/calc";

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

// ============================================================
// Types
// ============================================================

export type FiscalConfig = {
  org_id: string;
  enabled: boolean;
  environment: "test" | "prod";
  device_id: string | null;
  device_serial: string | null;
  device_model: string | null;
  activation_key: string | null;
  tax_payer_name: string | null;
  tax_payer_tin: string | null;
  vat_number: string | null;
  trade_name: string | null;
  has_certificate: boolean;
  has_private_key: boolean;
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

function stripSecrets(row: Record<string, unknown>): FiscalConfig {
  return {
    org_id: row.org_id as string,
    enabled: Boolean(row.enabled),
    environment: (row.environment as "test" | "prod") ?? "test",
    device_id: (row.device_id as string) ?? null,
    device_serial: (row.device_serial as string) ?? null,
    device_model: (row.device_model as string) ?? null,
    activation_key: (row.activation_key as string) ?? null,
    tax_payer_name: (row.tax_payer_name as string) ?? null,
    tax_payer_tin: (row.tax_payer_tin as string) ?? null,
    vat_number: (row.vat_number as string) ?? null,
    trade_name: (row.trade_name as string) ?? null,
    has_certificate: Boolean(row.certificate_pem),
    has_private_key: Boolean(row.private_key_pem),
    device_operating_mode: (row.device_operating_mode as string) ?? "Online",
    last_fiscal_day_no: (row.last_fiscal_day_no as number) ?? null,
    last_receipt_global_no: Number(row.last_receipt_global_no ?? 0),
    last_receipt_counter: Number(row.last_receipt_counter ?? 0),
  };
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
    return stripSecrets(data as Record<string, unknown>);
  });

const updateSchema = z.object({
  enabled: z.boolean().optional(),
  environment: z.enum(["test", "prod"]).optional(),
  device_id: z.string().nullable().optional(),
  device_serial: z.string().nullable().optional(),
  device_model: z.string().nullable().optional(),
  activation_key: z.string().nullable().optional(),
  tax_payer_name: z.string().nullable().optional(),
  tax_payer_tin: z.string().nullable().optional(),
  vat_number: z.string().nullable().optional(),
  trade_name: z.string().nullable().optional(),
  certificate_pem: z.string().nullable().optional(),
  private_key_pem: z.string().nullable().optional(),
  device_operating_mode: z.string().optional(),
});

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
  if (!data.enabled) throw new Error("Fiscalisation is disabled for this organization");
  if (!data.device_id) throw new Error("Device ID is not configured");
  return {
    env: (data.environment as FdmsEnv) ?? "test",
    device: {
      deviceId: String(data.device_id),
      deviceSerialNo: (data.device_serial as string) ?? null,
      activationKey: (data.activation_key as string) ?? null,
      certificatePem: (data.certificate_pem as string) ?? null,
      privateKeyPem: (data.private_key_pem as string) ?? null,
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
      const res = await getDeviceConfig(env, device);
      if (!res.ok) return { ok: false, message: res.error.message };
      return { ok: true, message: "Device reachable", data: res.data as unknown as Json };
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
        opening_response: res.ok ? (res.data as unknown as Json) : ({ error: res.error } as unknown as Json),
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
      throw new Error(`FDMS OpenDay failed: ${res.error.message}`);
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
          .select("total, tax_amount")
          .eq("org_id", orgId)
          .eq("fiscal_day_no", openRow.fiscal_day_no)
          .in("id", acceptedDocumentIds)
      : { data: [] };
    const totalSales = (receipts ?? []).reduce((s, r) => s + Number(r.total ?? 0), 0);
    const totalTax = (receipts ?? []).reduce((s, r) => s + Number(r.tax_amount ?? 0), 0);
    const totals = { totalSales, totalTax, receiptCount: (receipts ?? []).length };
    const closedAt = new Date().toISOString();

    const res = await fdmsCloseDay(env, device, openRow.fiscal_day_no, totals, closedAt);
    if (!res.ok) {
      await supabaseAdmin
        .from("fiscal_days")
        .update({ status: "error", closing_response: { error: res.error.message } as unknown as Json })
        .eq("id", openRow.id);
      throw new Error(`FDMS CloseDay failed: ${res.error.message}`);
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

    const { env, device, row } = await loadDevice(orgId);

    const { data: openDay } = await supabaseAdmin
      .from("fiscal_days")
      .select("*")
      .eq("org_id", orgId)
      .eq("status", "open")
      .maybeSingle();
    if (!openDay) throw new Error("Open a fiscal day before fiscalising receipts");

    const lineItems = (doc.line_items as unknown as LineItem[]) ?? [];
    const totals = computeTotals(lineItems, Number(doc.tax_rate), Number(doc.discount));
    const receiptGlobalNo = Number(row.last_receipt_global_no ?? 0) + 1;
    const receiptCounter = Number(row.last_receipt_counter ?? 0) + 1;
    const receiptDate = new Date().toISOString().slice(0, 19); // yyyy-MM-ddTHH:mm:ss

    // Last accepted receipt hash → previousReceiptHash chain.
    const { data: acceptedStatusesForHash } = await supabaseAdmin
      .from("current_receipt_status")
      .select("document_id")
      .eq("org_id", orgId)
      .eq("status", "Accepted");
    const acceptedIdsForHash = (acceptedStatusesForHash ?? [])
      .map((r) => r.document_id)
      .filter((documentId): documentId is string => Boolean(documentId));
    const { data: prevRow } = acceptedIdsForHash.length
      ? await supabaseAdmin
          .from("documents")
          .select("receipt_hash")
          .eq("org_id", orgId)
          .in("id", acceptedIdsForHash)
          .order("receipt_global_no", { ascending: false })
          .limit(1)
          .maybeSingle()
      : { data: null };
    const previousReceiptHash = prevRow?.receipt_hash ?? "";

    // Build tax line: single VAT rate for the whole invoice (matches app model)
    const taxes = [
      {
        taxCode: "A",
        taxPercent: Number(doc.tax_rate),
        taxAmount: Math.round(totals.tax_amount * 100),
      },
    ];

    const { hashBase64, verificationCode } = await computeReceiptHash({
      deviceId: device.deviceId,
      receiptType: "FiscalInvoice",
      receiptCurrency: (row.currency as string) ?? "USD",
      receiptGlobalNo,
      receiptDate,
      receiptTotalCents: Math.round(totals.total * 100),
      taxes,
      previousReceiptHash,
    });

    const receiptPayload = {
      receiptType: "FiscalInvoice",
      receiptCurrency: "USD",
      receiptCounter,
      receiptGlobalNo,
      invoiceNo: doc.doc_number,
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
        taxCode: "A",
        taxPercent: Number(doc.tax_rate),
      })),
      receiptTaxes: [
        {
          taxCode: "A",
          taxPercent: Number(doc.tax_rate),
          taxAmount: Math.round(totals.tax_amount * 100),
          salesAmountWithTax: Math.round(totals.total * 100),
        },
      ],
      receiptPayments: [
        { moneyTypeCode: "Cash", paymentAmount: Math.round(totals.total * 100) },
      ],
      receiptTotal: Math.round(totals.total * 100),
      receiptPrintForm: "InvoiceA4",
      receiptDeviceSignature: {
        hash: hashBase64,
      },
    };

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
          fiscal_submitted_at: new Date().toISOString(),
        })
        .eq("id", doc.id);
      throw new Error(`FDMS SubmitReceipt failed: ${submission.error.message}`);
    }

    const qrUrl = `https://receipt.zimra.co.zw/${device.deviceId}/${receiptGlobalNo}/${verificationCode}`;

    await appendReceiptStatus(doc.id, orgId, "Accepted", "FDMS accepted receipt", submission.data as unknown as Json);

    await supabaseAdmin
      .from("documents")
      .update({
        fiscal_day_no: openDay.fiscal_day_no,
        receipt_global_no: receiptGlobalNo,
        receipt_counter: receiptCounter,
        receipt_hash: hashBase64,
        verification_code: verificationCode,
        receipt_qr_url: qrUrl,
        fiscal_submitted_at: new Date().toISOString(),
        fiscal_response: submission.data as unknown as Json,
        fiscal_error: null,
      })
      .eq("id", doc.id);

    await supabaseAdmin
      .from("organization_fiscal_config")
      .update({
        last_receipt_global_no: receiptGlobalNo,
        last_receipt_counter: receiptCounter,
      })
      .eq("org_id", orgId);

    return {
      receipt_global_no: receiptGlobalNo,
      receipt_counter: receiptCounter,
      verification_code: verificationCode,
      fiscal_day_no: openDay.fiscal_day_no,
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
