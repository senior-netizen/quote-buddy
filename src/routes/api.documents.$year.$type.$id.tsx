import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";
import {
  logMissingServerConfig,
  serverConfigMissingJsonResponse,
  supabaseAdmin,
} from "@/integrations/supabase/client.server";
import { buildDef, buildDocPath, type DocForPdf } from "@/lib/pdfDef";
import { computeDocHash, type CanonicalDoc } from "@/lib/docHash";
import { signVerifyToken } from "@/lib/verifySign.server";
import type { LineItem } from "@/lib/calc";

/**
 * Serves a PDF for an authenticated user's document under a structured path:
 *   /api/documents/{year}/{quotes|invoices}/{docId}.pdf
 *
 * The {year} and {type} segments must match the document's actual values —
 * this prevents path enumeration and makes URLs self-describing.
 */
export const Route = createFileRoute("/api/documents/$year/$type/$id")({
  server: {
    handlers: {
      GET: async ({ request, params }) => {
        // Strip ".pdf" suffix from id segment
        const idRaw = params.id.endsWith(".pdf") ? params.id.slice(0, -4) : params.id;
        const previewMode = new URL(request.url).searchParams.get("preview") === "1";

        // Auth: Bearer token in Authorization header only.
        // Never accept the JWT via query string — it would leak into access
        // logs, browser history, and Referer headers.
        const authHeader = request.headers.get("authorization");
        const token = authHeader?.startsWith("Bearer ")
          ? authHeader.slice("Bearer ".length)
          : null;

        if (!token) {
          return new Response("Unauthorized", { status: 401 });
        }

        const SUPABASE_URL = process.env.SUPABASE_URL;
        const SUPABASE_PUBLISHABLE_KEY =
          process.env.SUPABASE_PUBLISHABLE_KEY ?? process.env.VITE_SUPABASE_PUBLISHABLE_KEY;
        const missingSupabaseAuthConfig = [
          ...(!SUPABASE_URL ? ["SUPABASE_URL"] : []),
          ...(!SUPABASE_PUBLISHABLE_KEY
            ? ["SUPABASE_PUBLISHABLE_KEY", "VITE_SUPABASE_PUBLISHABLE_KEY"]
            : []),
        ];

        if (missingSupabaseAuthConfig.length > 0) {
          logMissingServerConfig(missingSupabaseAuthConfig, "document-pdf-route-auth-client");

          return serverConfigMissingJsonResponse();
        }

        const userClient = createClient<Database>(SUPABASE_URL!, SUPABASE_PUBLISHABLE_KEY!, {
          global: { headers: { Authorization: `Bearer ${token}` } },
          auth: { storage: undefined, persistSession: false, autoRefreshToken: false },
        });
        const { data: claimsRes, error: claimsErr } = await userClient.auth.getClaims(token);
        if (claimsErr || !claimsRes?.claims?.sub) {
          return new Response("Unauthorized", { status: 401 });
        }
        const userId = claimsRes.claims.sub as string;

        // Fetch via admin client, then enforce ownership ourselves
        const { data: doc, error } = await supabaseAdmin
          .from("documents")
          .select("*, client:clients(company_name, address, email, phone)")
          .eq("id", idRaw)
          .maybeSingle();
        if (error || !doc) return new Response("Not found", { status: 404 });
        if (doc.user_id !== userId) return new Response("Forbidden", { status: 403 });

        // Validate path segments match the document
        const expectedYear = doc.issue_date.slice(0, 4);
        const expectedType =
          doc.doc_type === "invoice"
            ? "invoices"
            : doc.doc_type === "credit_note"
              ? "credit-notes"
              : doc.doc_type === "debit_note"
                ? "debit-notes"
                : doc.doc_type === "receipt"
                  ? "receipts"
                  : "quotes";
        if (params.year !== expectedYear || params.type !== expectedType) {
          return new Response("Not found", { status: 404 });
        }

        const client = (doc.client as unknown as {
          company_name: string;
          address: string | null;
          email: string | null;
          phone: string | null;
        } | null) ?? { company_name: "—", address: null, email: null, phone: null };

        const lineItems = (doc.line_items as unknown as LineItem[]) ?? [];

        // Load the issuing org's brand profile
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

        // Build verify URL (signed, matches client behaviour)
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
        const origin = url.origin;
        const verifyUrl = `${origin}/verify/${doc.id}?sig=${encodeURIComponent(sig)}&h=${hash}`;

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

        // Build PDF on server using pdfmake
        const def = await buildDef(docForPdf);
        // Dynamic import keeps pdfmake out of the client bundle for this route
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

        const storagePath = buildDocPath(docForPdf);
        const filename = `${doc.doc_number}.pdf`;
        const disposition = previewMode ? "inline" : "attachment";

        return new Response(new Uint8Array(bytes), {
          status: 200,
          headers: {
            "Content-Type": "application/pdf",
            "Content-Disposition": `${disposition}; filename="${filename}"`,
            "X-Document-Path": storagePath,
            "Cache-Control": "private, no-store",
          },
        });
      },
    },
  },
});
