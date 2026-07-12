import { c as createServerRpc } from "./createServerRpc-wV0Vk4NU.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { supabaseAdmin } from "./client.server-BMj2q4-x.mjs";
import { c as computeTotals, r as rowTotal } from "./calc-BF6zAv6d.mjs";
import { d as documentTypeSchema, g as getDocumentTypePrefix } from "./docTypes-CsATll0j.mjs";
import { c as createServerFn } from "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/react.mjs";
import { o as object, n as number, s as string, a as array } from "../_libs/zod.mjs";
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
class FiscalCounterManager {
  constructor(supabase) {
    this.supabase = supabase;
  }
  supabase;
  async allocate(orgId) {
    for (let attempt = 0; attempt < 5; attempt++) {
      const { data: current, error: loadError } = await this.supabase.from("organization_fiscal_config").select("last_receipt_global_no, last_receipt_counter").eq("org_id", orgId).single();
      if (loadError) throw new Error(loadError.message);
      const receiptGlobalNo = Number(current.last_receipt_global_no ?? 0) + 1;
      const receiptCounter = Number(current.last_receipt_counter ?? 0) + 1;
      const { data: updated, error } = await this.supabase.from("organization_fiscal_config").update({ last_receipt_global_no: receiptGlobalNo, last_receipt_counter: receiptCounter }).eq("org_id", orgId).eq("last_receipt_global_no", current.last_receipt_global_no).eq("last_receipt_counter", current.last_receipt_counter).select("org_id").maybeSingle();
      if (error) throw new Error(error.message);
      if (updated) return { receiptGlobalNo, receiptCounter };
    }
    throw new Error("Could not allocate fiscal counters. Please try again.");
  }
}
class FiscalDayManager {
  constructor(supabase) {
    this.supabase = supabase;
  }
  supabase;
  async requireOpenDay(orgId) {
    const { data, error } = await this.supabase.from("fiscal_days").select("id, fiscal_day_no, status").eq("org_id", orgId).eq("status", "open").maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error("Open a fiscal day before creating fiscal receipts");
    return data;
  }
}
class ReceiptValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ReceiptValidationError";
  }
}
class ReceiptValidator {
  validateDraft(draft) {
    if (!draft.orgId) throw new ReceiptValidationError("No active organization");
    if (!draft.clientId) throw new ReceiptValidationError("Select a client");
    if (!draft.docNumber.trim()) throw new ReceiptValidationError("Document number missing");
    if (!draft.issueDate) throw new ReceiptValidationError("Issue date is required");
    this.validateLines(draft.lineItems);
    this.validateTotals(draft);
    return computeTotals(draft.lineItems, draft.taxRate, draft.discount);
  }
  validateReceiptReady(draft) {
    const totals = this.validateDraft(draft);
    this.validateBuyer(draft);
    this.validateTaxes(draft, totals.tax_amount);
    this.validatePayments(draft, totals.total);
    return totals;
  }
  validateLines(lines) {
    if (!lines.length) throw new ReceiptValidationError("Add at least one line item");
    lines.forEach((line, index) => {
      if (!line.description.trim()) throw new ReceiptValidationError(`Line ${index + 1} needs a description`);
      if (!Number.isFinite(Number(line.quantity)) || Number(line.quantity) <= 0) {
        throw new ReceiptValidationError(`Line ${index + 1} needs a positive quantity`);
      }
      if (!Number.isFinite(Number(line.unit_price)) || Number(line.unit_price) < 0) {
        throw new ReceiptValidationError(`Line ${index + 1} needs a valid unit price`);
      }
      if (rowTotal(line) < 0) throw new ReceiptValidationError(`Line ${index + 1} total is invalid`);
    });
  }
  validateBuyer(draft) {
    if (!draft.buyer?.company_name?.trim()) throw new ReceiptValidationError("Buyer name is required for fiscal receipts");
  }
  validateTotals(draft) {
    if (!Number.isFinite(Number(draft.taxRate)) || Number(draft.taxRate) < 0) {
      throw new ReceiptValidationError("Tax rate must be zero or greater");
    }
    if (!Number.isFinite(Number(draft.discount)) || Number(draft.discount) < 0) {
      throw new ReceiptValidationError("Discount must be zero or greater");
    }
    const totals = computeTotals(draft.lineItems, draft.taxRate, draft.discount);
    if (totals.subtotal < 0 || totals.tax_amount < 0 || totals.total < 0) {
      throw new ReceiptValidationError("Receipt totals cannot be negative");
    }
  }
  validateTaxes(_draft, taxAmount) {
    if (!Number.isFinite(taxAmount) || taxAmount < 0) throw new ReceiptValidationError("Tax amount is invalid");
  }
  validatePayments(draft, total) {
    const payments = draft.payments?.length ? draft.payments : [{ moneyTypeCode: "Cash", amount: total }];
    const paid = payments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
    if (Math.round(paid * 100) !== Math.round(total * 100)) {
      throw new ReceiptValidationError("Payments must equal the receipt total");
    }
  }
}
class ReceiptEngine {
  constructor(supabase) {
    this.supabase = supabase;
    this.days = new FiscalDayManager(supabase);
    this.counters = new FiscalCounterManager(supabase);
  }
  supabase;
  validator = new ReceiptValidator();
  days;
  counters;
  async planCreation(draft) {
    const totals = this.validator.validateDraft(draft);
    const config = await this.loadFiscalConfig(draft.orgId);
    const fiscalized = draft.docType === "invoice" && Boolean(config?.enabled);
    if (!fiscalized) {
      return { fiscalized: false, state: "Draft", fiscalDayNo: null, counters: null, ...totals };
    }
    this.validator.validateReceiptReady(draft);
    const openDay = await this.days.requireOpenDay(draft.orgId);
    const counters = await this.counters.allocate(draft.orgId);
    return {
      fiscalized: true,
      state: "Ready",
      fiscalDayNo: openDay.fiscal_day_no,
      counters,
      ...totals
    };
  }
  async loadFiscalConfig(orgId) {
    const { data, error } = await this.supabase.from("organization_fiscal_config").select("org_id, enabled, last_receipt_counter, last_receipt_global_no").eq("org_id", orgId).maybeSingle();
    if (error) throw new Error(error.message);
    return data;
  }
}
const lineItemSchema = object({
  description: string(),
  quantity: number(),
  unit_price: number()
});
const createDocumentSchema = object({
  clientId: string().uuid(),
  docType: documentTypeSchema,
  docNumber: string().min(1),
  issueDate: string().min(1),
  dueDate: string().nullable(),
  lineItems: array(lineItemSchema),
  taxRate: number(),
  discount: number(),
  notes: string().nullable()
});
async function activeOrgId(userId) {
  const {
    data
  } = await supabaseAdmin.from("profiles").select("active_org_id").eq("user_id", userId).maybeSingle();
  const id = data?.active_org_id ?? null;
  if (!id) throw new Error("No active organization");
  return id;
}
async function generateDocumentNumber(type, orgId) {
  const prefix = getDocumentTypePrefix(type);
  const year = (/* @__PURE__ */ new Date()).getFullYear();
  const like = `${prefix}-${year}-%`;
  const {
    data,
    error
  } = await supabaseAdmin.from("documents").select("doc_number").eq("org_id", orgId).like("doc_number", like).order("doc_number", {
    ascending: false
  }).limit(1);
  if (error) throw new Error(error.message);
  const last = data?.[0]?.doc_number;
  const seq = last ? parseInt(String(last).split("-").pop() || "0", 10) : 0;
  const next = Number.isNaN(seq) ? 1 : seq + 1;
  return `${prefix}-${year}-${String(next).padStart(4, "0")}`;
}
const getNextDocumentNumber_createServerFn_handler = createServerRpc({
  id: "30bf6b89af29e3b571a688483b15fef5a113de06e9ceb35278995eea8dbbfc73",
  name: "getNextDocumentNumber",
  filename: "src/lib/documents.functions.ts"
}, (opts) => getNextDocumentNumber.__executeServer(opts));
const getNextDocumentNumber = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => object({
  docType: documentTypeSchema
}).parse(data)).handler(getNextDocumentNumber_createServerFn_handler, async ({
  data,
  context
}) => {
  const orgId = await activeOrgId(context.userId);
  return await generateDocumentNumber(data.docType, orgId);
});
const listDocumentClients_createServerFn_handler = createServerRpc({
  id: "293f0c3d8e09ee1044d9afc326adfce7991af79a1fb6c566a7d37357ed0f84a6",
  name: "listDocumentClients",
  filename: "src/lib/documents.functions.ts"
}, (opts) => listDocumentClients.__executeServer(opts));
const listDocumentClients = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(listDocumentClients_createServerFn_handler, async ({
  context
}) => {
  const orgId = await activeOrgId(context.userId);
  const {
    data,
    error
  } = await supabaseAdmin.from("clients").select("id, company_name, address, email, phone").eq("org_id", orgId).order("company_name");
  if (error) throw new Error(error.message);
  return data ?? [];
});
const createDocument_createServerFn_handler = createServerRpc({
  id: "076f0d27c3d7b1fba7365afd1647231a0b13d6f0dd851a947be0c6d6c54fdc74",
  name: "createDocument",
  filename: "src/lib/documents.functions.ts"
}, (opts) => createDocument.__executeServer(opts));
const createDocument = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => createDocumentSchema.parse(data)).handler(createDocument_createServerFn_handler, async ({
  data,
  context
}) => {
  const orgId = await activeOrgId(context.userId);
  const {
    data: client,
    error: clientError
  } = await supabaseAdmin.from("clients").select("company_name, address, email, phone").eq("id", data.clientId).eq("org_id", orgId).maybeSingle();
  if (clientError) throw new Error(clientError.message);
  if (!client) throw new Error("Client not found");
  const engine = new ReceiptEngine(supabaseAdmin);
  const MAX_ATTEMPTS = 5;
  let attemptNumber = data.docNumber;
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    const plan = await engine.planCreation({
      orgId,
      userId: context.userId,
      clientId: data.clientId,
      docType: data.docType,
      docNumber: attemptNumber,
      issueDate: data.issueDate,
      dueDate: data.dueDate || null,
      lineItems: data.lineItems,
      taxRate: data.taxRate,
      discount: data.discount,
      notes: data.notes || null,
      buyer: client
    });
    const {
      data: inserted,
      error
    } = await supabaseAdmin.from("documents").insert({
      user_id: context.userId,
      org_id: orgId,
      client_id: data.clientId,
      doc_type: data.docType,
      doc_number: attemptNumber,
      issue_date: data.issueDate,
      due_date: data.dueDate || null,
      line_items: data.lineItems,
      tax_rate: data.taxRate,
      discount: data.discount,
      subtotal: plan.subtotal,
      tax_amount: plan.tax_amount,
      total: plan.total,
      notes: data.notes || null,
      fiscal_status: plan.fiscalized ? plan.state : "draft",
      fiscal_day_no: plan.fiscalDayNo,
      receipt_global_no: plan.counters?.receiptGlobalNo ?? null,
      receipt_counter: plan.counters?.receiptCounter ?? null
    }).select("id").single();
    if (!error) return inserted.id;
    if (error.code === "23505" && attempt < MAX_ATTEMPTS) {
      attemptNumber = await generateDocumentNumber(data.docType, orgId);
      continue;
    }
    throw new Error(error.message);
  }
  throw new Error("Could not allocate a unique document number. Please try again.");
});
export {
  createDocument_createServerFn_handler,
  getNextDocumentNumber_createServerFn_handler,
  listDocumentClients_createServerFn_handler
};
