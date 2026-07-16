import { createFileRoute } from "@tanstack/react-router";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import {
  authenticateApiRequest,
  errorResponse,
  jsonResponse,
  optionsResponse,
} from "@/lib/apiAuth.server";
import { computeDocHash, type CanonicalDoc } from "@/lib/docHash";
import { signVerifyToken } from "@/lib/verifySign.server";
import type { LineItem } from "@/lib/calc";

/**
 * Returns a verification URL + signed hash for a document.
 * Third parties can use this to prove a document was issued by this system.
 */
export const Route = createFileRoute("/api/public/v1/documents/$id/verify")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        const { data: doc, error } = await supabaseAdmin
          .from("documents")
          .select("id, doc_type, doc_number, issue_date, due_date, line_items, tax_rate, discount, subtotal, tax_amount, total, notes, client:clients(company_name, email)")
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!doc) return errorResponse(404, "Document not found");

        const client = (doc.client as unknown as { company_name: string; email: string | null } | null) ?? {
          company_name: "—",
          email: null,
        };
        const canonical: CanonicalDoc = {
          doc_type: doc.doc_type,
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: (doc.line_items as unknown as LineItem[]) ?? [],
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client: { company_name: client.company_name, email: client.email },
        };
        const hash = await computeDocHash(canonical);
        const sig = signVerifyToken(doc.id, hash);
        const origin = new URL(request.url).origin;
        const verify_url = `${origin}/verify/${doc.id}?sig=${encodeURIComponent(sig)}&h=${hash}`;
        return jsonResponse({ id: doc.id, hash, sig, verify_url });
      },
    },
  },
});
