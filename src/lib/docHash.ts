import type { LineItem } from "./calc";

export type CanonicalDoc = {
  doc_type: string;
  doc_number: string;
  issue_date: string;
  due_date: string | null;
  line_items: LineItem[];
  tax_rate: number;
  discount: number;
  subtotal: number;
  tax_amount: number;
  total: number;
  notes: string | null;
  client: { company_name: string; email: string | null };
};

/** Stable JSON: sorted keys, normalized numbers, no whitespace. */
function canonicalize(d: CanonicalDoc): string {
  const norm = {
    client: { company_name: d.client.company_name, email: d.client.email ?? null },
    discount: Number(d.discount),
    doc_number: d.doc_number,
    doc_type: d.doc_type,
    due_date: d.due_date ?? null,
    issue_date: d.issue_date,
    line_items: d.line_items.map((li) => ({
      description: li.description,
      quantity: Number(li.quantity),
      unit_price: Number(li.unit_price),
    })),
    notes: d.notes ?? null,
    subtotal: Number(d.subtotal),
    tax_amount: Number(d.tax_amount),
    tax_rate: Number(d.tax_rate),
    total: Number(d.total),
  };
  return JSON.stringify(norm);
}

async function sha256Hex(input: string): Promise<string> {
  const buf = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function computeDocHash(d: CanonicalDoc): Promise<string> {
  return sha256Hex(canonicalize(d));
}
