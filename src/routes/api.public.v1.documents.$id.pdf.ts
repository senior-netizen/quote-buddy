import { createFileRoute } from "@tanstack/react-router";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import {
  authenticateApiRequest,
  errorResponse,
  optionsResponse,
} from "@/lib/apiAuth.server";
import { buildDef, type DocForPdf } from "@/lib/pdfDef";
import { computeDocHash, type CanonicalDoc } from "@/lib/docHash";
import { signVerifyToken } from "@/lib/verifySign.server";
import type { LineItem } from "@/lib/calc";

/**
 * Returns the rendered PDF bytes for a document.
 *   GET /api/public/v1/documents/{id}/pdf
 *   ?disposition=inline|attachment (default: attachment)
 */
export const Route = createFileRoute("/api/public/v1/documents/$id/pdf")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);

        const url = new URL(request.url);
        const disposition =
          url.searchParams.get("disposition") === "inline" ? "inline" : "attachment";

        const { data: doc, error } = await supabaseAdmin
          .from("documents")
          .select("*, client:clients(company_name, address, email, phone)")
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!doc) return errorResponse(404, "Document not found");

        const client =
          (doc.client as unknown as {
            company_name: string;
            address: string | null;
            email: string | null;
            phone: string | null;
          } | null) ?? { company_name: "—", address: null, email: null, phone: null };

        const lineItems = (doc.line_items as unknown as LineItem[]) ?? [];

        const { data: orgProfile } = await supabaseAdmin
          .from("organization_profiles")
          .select("*")
          .eq("org_id", doc.org_id)
          .maybeSingle();

        let logoDataUrl: string | null = null;
        if (orgProfile?.logo_url) {
          try {
            const r = await fetch(orgProfile.logo_url);
            if (r.ok) {
              const buf = new Uint8Array(await r.arrayBuffer());
              const ct = r.headers.get("content-type") || "image/png";
              const b64 = Buffer.from(buf).toString("base64");
              logoDataUrl = `data:${ct};base64,${b64}`;
            }
          } catch { /* ignore */ }
        }

        const brand = {
          name: orgProfile?.name ?? "Your Company",
          short_name: orgProfile?.short_name ?? null,
          logo_data_url: logoDataUrl,
          emails: orgProfile?.emails ?? [],
          website: orgProfile?.website ?? null,
          registration: orgProfile?.registration ?? null,
          tin: orgProfile?.tin ?? null,
          duns: orgProfile?.duns ?? null,
          praz: orgProfile?.praz ?? null,
          currency: orgProfile?.currency ?? "USD",
          default_tax_rate: Number(orgProfile?.default_tax_rate ?? 15),
          address: orgProfile?.address ?? null,
          phone: orgProfile?.phone ?? null,
          payment_instructions: orgProfile?.payment_instructions ?? null,
        };

        const canonical: CanonicalDoc = {
          doc_type: doc.doc_type as CanonicalDoc["doc_type"],
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: lineItems,
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
        const verifyUrl = `${url.origin}/verify/${doc.id}?sig=${encodeURIComponent(sig)}&h=${hash}`;

        const docForPdf: DocForPdf = {
          doc_type: doc.doc_type as DocForPdf["doc_type"],
          doc_number: doc.doc_number,
          issue_date: doc.issue_date,
          due_date: doc.due_date,
          line_items: lineItems,
          tax_rate: Number(doc.tax_rate),
          discount: Number(doc.discount),
          subtotal: Number(doc.subtotal),
          tax_amount: Number(doc.tax_amount),
          total: Number(doc.total),
          notes: doc.notes,
          client,
          brand,
          verifyUrl,
          docHash: hash,
          signatureId: sig,
        };

        const def = await buildDef(docForPdf);
        const pdfMakeMod = (await import("pdfmake/build/pdfmake")) as unknown as {
          default: {
            vfs: Record<string, string>;
            createPdf: (def: unknown) => {
              getBuffer: (cb: (buffer: Uint8Array) => void) => void;
            };
          };
        };
        const pdfFontsMod = (await import("pdfmake/build/vfs_fonts")) as unknown as {
          default: { vfs?: Record<string, string>; pdfMake?: { vfs: Record<string, string> } };
        };
        const pdfMake = pdfMakeMod.default;
        pdfMake.vfs = pdfFontsMod.default.vfs ?? pdfFontsMod.default.pdfMake?.vfs ?? {};

        const bytes = await new Promise<Uint8Array>((resolve) => {
          pdfMake.createPdf(def).getBuffer((buf) => resolve(buf));
        });

        const filename = `${doc.doc_number}.pdf`;
        return new Response(new Uint8Array(bytes), {
          status: 200,
          headers: {
            "Content-Type": "application/pdf",
            "Content-Disposition": `${disposition}; filename="${filename}"`,
            "Cache-Control": "private, no-store",
            "access-control-allow-origin": "*",
          },
        });
      },
    },
  },
});
