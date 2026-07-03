import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import {
  authenticateApiRequest,
  errorResponse,
  jsonResponse,
  optionsResponse,
} from "@/lib/apiAuth.server";
import { computeTotals, type LineItem } from "@/lib/calc";

const lineItem = z.object({
  description: z.string().min(1).max(500),
  quantity: z.number().finite().min(0),
  unit_price: z.number().finite().min(0),
});

const docInput = z.object({
  client_id: z.string().uuid(),
  doc_type: z.enum(["quote", "invoice"]),
  doc_number: z.string().min(1).max(50),
  issue_date: z.string(),
  due_date: z.string().nullable().optional(),
  line_items: z.array(lineItem).min(1),
  tax_rate: z.number().finite().min(0).max(100).default(0),
  discount: z.number().finite().min(0).default(0),
  notes: z.string().max(2000).nullable().optional(),
});

export const Route = createFileRoute("/api/public/v1/documents")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const url = new URL(request.url);
        const limit = Math.min(Number(url.searchParams.get("limit") ?? 50) || 50, 200);
        const offset = Math.max(Number(url.searchParams.get("offset") ?? 0) || 0, 0);
        const type = url.searchParams.get("type");
        let q = supabaseAdmin
          .from("documents")
          .select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at")
          .eq("org_id", auth.orgId)
          .order("created_at", { ascending: false })
          .range(offset, offset + limit - 1);
        if (type === "quote" || type === "invoice") q = q.eq("doc_type", type);
        const { data, error } = await q;
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data, limit, offset });
      },
      POST: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        let body: unknown;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = docInput.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const input = parsed.data;

        // verify the client belongs to this org
        const { data: client } = await supabaseAdmin
          .from("clients")
          .select("id")
          .eq("id", input.client_id)
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (!client) return errorResponse(400, "client_id not found in this organization");

        const totals = computeTotals(input.line_items as LineItem[], input.tax_rate, input.discount);

        const { data: org } = await supabaseAdmin
          .from("organizations")
          .select("created_by")
          .eq("id", auth.orgId)
          .maybeSingle();
        const userId = org?.created_by;
        if (!userId) return errorResponse(500, "Organization has no owner");

        const { data, error } = await supabaseAdmin
          .from("documents")
          .insert({
            org_id: auth.orgId,
            user_id: userId,
            client_id: input.client_id,
            doc_type: input.doc_type,
            doc_number: input.doc_number,
            issue_date: input.issue_date,
            due_date: input.due_date ?? null,
            line_items: input.line_items,
            tax_rate: input.tax_rate,
            discount: input.discount,
            subtotal: totals.subtotal,
            tax_amount: totals.tax_amount,
            total: totals.total,
            notes: input.notes ?? null,
          })
          .select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at")
          .single();
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data }, { status: 201 });
      },
    },
  },
});
