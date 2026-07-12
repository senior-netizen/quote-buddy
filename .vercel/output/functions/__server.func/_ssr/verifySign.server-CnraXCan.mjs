import { createHmac } from "crypto";
function canonicalize(d) {
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
      unit_price: Number(li.unit_price)
    })),
    notes: d.notes ?? null,
    subtotal: Number(d.subtotal),
    tax_amount: Number(d.tax_amount),
    tax_rate: Number(d.tax_rate),
    total: Number(d.total)
  };
  return JSON.stringify(norm);
}
async function sha256Hex(input) {
  const buf = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function computeDocHash(d) {
  return sha256Hex(canonicalize(d));
}
function getSecret() {
  const s = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!s) throw new Error("Missing signing secret");
  return s;
}
function signVerifyToken(id, hash) {
  const mac = createHmac("sha256", getSecret()).update(`${id}|${hash}`).digest();
  return Buffer.from(mac).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function verifyToken(id, hash, sig) {
  const expected = signVerifyToken(id, hash);
  if (expected.length !== sig.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ sig.charCodeAt(i);
  return diff === 0;
}
export {
  computeDocHash as c,
  signVerifyToken as s,
  verifyToken as v
};
