import { createServerFn } from "@tanstack/react-start";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { computeDocHash, type CanonicalDoc } from "@/lib/docHash";
import { signVerifyToken, verifyToken } from "@/lib/verifySign.server";
import type { LineItem } from "@/lib/calc";

/** Issue a signed verification payload for a document the caller owns. */
export const issueVerifyToken = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: { id: string }) => {
    if (!d?.id || typeof d.id !== "string" || d.id.length > 64) throw new Error("Invalid id");
    return d;
  })
  .handler(async ({ data, context }) => {
    const { data: doc, error } = await supabaseAdmin
      .from("documents")
      .select("id, doc_type, doc_number, issue_date, due_date, line_items, tax_rate, discount, subtotal, tax_amount, total, notes, user_id, client:clients(company_name, email)")
      .eq("id", data.id)
      .eq("user_id", context.userId)
      .maybeSingle();
    if (error || !doc) throw new Error("Document not found");

    const client = (doc.client as unknown as { company_name: string; email: string | null } | null) ?? { company_name: "—", email: null };
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
    return { id: doc.id, hash, sig };
  });

export type VerifyResult =
  | {
      status: "authentic";
      doc_type: string;
      doc_number: string;
      issue_date: string;
      due_date: string | null;
      total: number;
      subtotal: number;
      tax_rate: number;
      tax_amount: number;
      issuer: string;
      client_company: string;
    }
  | { status: "tampered"; reason: string }
  | { status: "not_found" }
  | { status: "invalid_signature" };

/** Public — verifies a QR-issued document. No auth required. */
export const publicVerify = createServerFn({ method: "POST" })
  .inputValidator((d: { id: string; sig: string; hash: string }) => {
    if (!d?.id || !d?.sig || !d?.hash) throw new Error("Missing fields");
    if (d.id.length > 64 || d.sig.length > 128 || d.hash.length !== 64) throw new Error("Bad input");
    if (!/^[a-f0-9]{64}$/.test(d.hash)) throw new Error("Bad hash");
    return d;
  })
  .handler(async ({ data }): Promise<VerifyResult> => {
    if (!verifyToken(data.id, data.hash, data.sig)) {
      return { status: "invalid_signature" };
    }
    const { data: doc, error } = await supabaseAdmin
      .from("documents")
      .select("id, doc_type, doc_number, issue_date, total, line_items, tax_rate, discount, subtotal, tax_amount, due_date, notes, org_id, client:clients(company_name, email)")
      .eq("id", data.id)
      .maybeSingle();
    if (error || !doc) return { status: "not_found" };

    const client = (doc.client as unknown as { company_name: string; email: string | null } | null) ?? { company_name: "—", email: null };
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
    const currentHash = await computeDocHash(canonical);
    if (currentHash !== data.hash) {
      return { status: "tampered", reason: "Document contents differ from the issued version." };
    }
    // Resolve issuer from the org_id of the doc
    const { data: orgProf } = await supabaseAdmin
      .from("organization_profiles")
      .select("name")
      .eq("org_id", doc.org_id)
      .maybeSingle();
    const issuer = orgProf?.name ?? "Unknown issuer";
    return {
      status: "authentic",
      doc_type: doc.doc_type,
      doc_number: doc.doc_number,
      issue_date: doc.issue_date,
      due_date: doc.due_date,
      total: Number(doc.total),
      subtotal: Number(doc.subtotal),
      tax_rate: Number(doc.tax_rate),
      tax_amount: Number(doc.tax_amount),
      issuer,
      client_company: client.company_name,
    };
  });
