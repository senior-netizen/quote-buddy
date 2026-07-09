import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import type { Json } from "@/integrations/supabase/types";
import { ReceiptEngine } from "@/lib/fiscal";

const lineItemSchema = z.object({
  description: z.string(),
  quantity: z.number(),
  unit_price: z.number(),
});

const createDocumentSchema = z.object({
  clientId: z.string().uuid(),
  docType: z.enum(["quote", "invoice"]),
  docNumber: z.string().min(1),
  issueDate: z.string().min(1),
  dueDate: z.string().nullable(),
  lineItems: z.array(lineItemSchema),
  taxRate: z.number(),
  discount: z.number(),
  notes: z.string().nullable(),
});

async function activeOrgId(userId: string): Promise<string> {
  const { data } = await supabaseAdmin
    .from("profiles")
    .select("active_org_id")
    .eq("user_id", userId)
    .maybeSingle();
  const id = data?.active_org_id ?? null;
  if (!id) throw new Error("No active organization");
  return id;
}

async function generateDocumentNumber(type: "quote" | "invoice", orgId: string): Promise<string> {
  const prefix = type === "quote" ? "QT" : "INV";
  const year = new Date().getFullYear();
  const like = `${prefix}-${year}-%`;
  const { data, error } = await supabaseAdmin
    .from("documents")
    .select("doc_number")
    .eq("org_id", orgId)
    .like("doc_number", like)
    .order("doc_number", { ascending: false })
    .limit(1);
  if (error) throw new Error(error.message);
  const last = data?.[0]?.doc_number;
  const seq = last ? parseInt(String(last).split("-").pop() || "0", 10) : 0;
  const next = Number.isNaN(seq) ? 1 : seq + 1;
  return `${prefix}-${year}-${String(next).padStart(4, "0")}`;
}

export const getNextDocumentNumber = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => z.object({ docType: z.enum(["quote", "invoice"]) }).parse(data))
  .handler(async ({ data, context }) => {
    const orgId = await activeOrgId(context.userId);
    return await generateDocumentNumber(data.docType, orgId);
  });

export const listDocumentClients = createServerFn({ method: "GET" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const orgId = await activeOrgId(context.userId);
    const { data, error } = await supabaseAdmin
      .from("clients")
      .select("id, company_name, address, email, phone")
      .eq("org_id", orgId)
      .order("company_name");
    if (error) throw new Error(error.message);
    return data ?? [];
  });

export const createDocument = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((data: unknown) => createDocumentSchema.parse(data))
  .handler(async ({ data, context }): Promise<string> => {
    const orgId = await activeOrgId(context.userId);
    const { data: client, error: clientError } = await supabaseAdmin
      .from("clients")
      .select("company_name, address, email, phone")
      .eq("id", data.clientId)
      .eq("org_id", orgId)
      .maybeSingle();
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
        buyer: client,
      });

      const { data: inserted, error } = await supabaseAdmin
        .from("documents")
        .insert({
          user_id: context.userId,
          org_id: orgId,
          client_id: data.clientId,
          doc_type: data.docType,
          doc_number: attemptNumber,
          issue_date: data.issueDate,
          due_date: data.dueDate || null,
          line_items: data.lineItems as unknown as Json,
          tax_rate: data.taxRate,
          discount: data.discount,
          subtotal: plan.subtotal,
          tax_amount: plan.tax_amount,
          total: plan.total,
          notes: data.notes || null,
          fiscal_status: plan.fiscalized ? plan.state : "draft",
          fiscal_day_no: plan.fiscalDayNo,
          receipt_global_no: plan.counters?.receiptGlobalNo ?? null,
          receipt_counter: plan.counters?.receiptCounter ?? null,
        })
        .select("id")
        .single();

      if (!error) return inserted.id;
      if ((error as { code?: string }).code === "23505" && attempt < MAX_ATTEMPTS) {
        attemptNumber = await generateDocumentNumber(data.docType, orgId);
        continue;
      }
      throw new Error(error.message);
    }
    throw new Error("Could not allocate a unique document number. Please try again.");
  });
