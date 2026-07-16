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

const docPatch = z.object({
  doc_number: z.string().min(1).max(50).optional(),
  issue_date: z.string().optional(),
  due_date: z.string().nullable().optional(),
  line_items: z.array(lineItem).min(1).optional(),
  tax_rate: z.number().finite().min(0).max(100).optional(),
  discount: z.number().finite().min(0).optional(),
  notes: z.string().max(2000).nullable().optional(),
});

export const Route = createFileRoute("/api/public/v1/documents/$id")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        const { data, error } = await supabaseAdmin
          .from("documents")
          .select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at, client:clients(id, company_name, email, phone, address)")
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Document not found");
        return jsonResponse({ data });
      },
      PATCH: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        let body: unknown;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = docPatch.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const patch = parsed.data;

        // Recompute totals if line_items / tax_rate / discount changed
        const { data: current } = await supabaseAdmin
          .from("documents")
          .select("line_items, tax_rate, discount")
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (!current) return errorResponse(404, "Document not found");

        const items = (patch.line_items ?? (current.line_items as unknown as LineItem[])) as LineItem[];
        const taxRate = patch.tax_rate ?? Number(current.tax_rate);
        const discount = patch.discount ?? Number(current.discount);
        const totals = computeTotals(items, taxRate, discount);

        const { data, error } = await supabaseAdmin
          .from("documents")
          .update({
            ...patch,
            subtotal: totals.subtotal,
            tax_amount: totals.tax_amount,
            total: totals.total,
          })
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .select("id, doc_type, doc_number, client_id, issue_date, due_date, subtotal, tax_rate, tax_amount, discount, total, notes, line_items, created_at, updated_at")
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Document not found");
        return jsonResponse({ data });
      },
      DELETE: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        const { error, count } = await supabaseAdmin
          .from("documents")
          .delete({ count: "exact" })
          .eq("id", params.id)
          .eq("org_id", auth.orgId);
        if (error) return errorResponse(500, error.message);
        if (!count) return errorResponse(404, "Document not found");
        return jsonResponse({ deleted: true });
      },
    },
  },
});
