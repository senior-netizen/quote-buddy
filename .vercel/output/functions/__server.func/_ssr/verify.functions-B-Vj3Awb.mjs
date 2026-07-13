import { c as createServerRpc } from "./createServerRpc-wV0Vk4NU.mjs";
import { supabaseAdmin } from "./client.server-BMj2q4-x.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { c as computeDocHash, s as signVerifyToken, v as verifyToken } from "./verifySign.server-CnraXCan.mjs";
import { c as createServerFn } from "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/react.mjs";
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
import "crypto";
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
import "stream";
import "../_libs/isbot.mjs";
const issueVerifyToken_createServerFn_handler = createServerRpc({
  id: "62aee870b7d352bb450ac12ee2012d64454b03b21e0c3fb64dc9fcd5484a053d",
  name: "issueVerifyToken",
  filename: "src/lib/verify.functions.ts"
}, (opts) => issueVerifyToken.__executeServer(opts));
const issueVerifyToken = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => {
  if (!d?.id || typeof d.id !== "string" || d.id.length > 64) throw new Error("Invalid id");
  return d;
}).handler(issueVerifyToken_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: doc,
    error
  } = await supabaseAdmin.from("documents").select("id, doc_type, doc_number, issue_date, due_date, line_items, tax_rate, discount, subtotal, tax_amount, total, notes, user_id, client:clients(company_name, email)").eq("id", data.id).eq("user_id", context.userId).maybeSingle();
  if (error || !doc) throw new Error("Document not found");
  const client = doc.client ?? {
    company_name: "—",
    email: null
  };
  const canonical = {
    doc_type: doc.doc_type,
    doc_number: doc.doc_number,
    issue_date: doc.issue_date,
    due_date: doc.due_date,
    line_items: doc.line_items ?? [],
    tax_rate: Number(doc.tax_rate),
    discount: Number(doc.discount),
    subtotal: Number(doc.subtotal),
    tax_amount: Number(doc.tax_amount),
    total: Number(doc.total),
    notes: doc.notes,
    client: {
      company_name: client.company_name,
      email: client.email
    }
  };
  const hash = await computeDocHash(canonical);
  const sig = signVerifyToken(doc.id, hash);
  return {
    id: doc.id,
    hash,
    sig
  };
});
const publicVerify_createServerFn_handler = createServerRpc({
  id: "e95f2d768f72026d754fdf5fc3e00d936a621aec6c0ca5a383b442f2538d02ec",
  name: "publicVerify",
  filename: "src/lib/verify.functions.ts"
}, (opts) => publicVerify.__executeServer(opts));
const publicVerify = createServerFn({
  method: "POST"
}).inputValidator((d) => {
  if (!d?.id || !d?.sig || !d?.hash) throw new Error("Missing fields");
  if (d.id.length > 64 || d.sig.length > 128 || d.hash.length !== 64) throw new Error("Bad input");
  if (!/^[a-f0-9]{64}$/.test(d.hash)) throw new Error("Bad hash");
  return d;
}).handler(publicVerify_createServerFn_handler, async ({
  data
}) => {
  if (!verifyToken(data.id, data.hash, data.sig)) {
    return {
      status: "invalid_signature"
    };
  }
  const {
    data: doc,
    error
  } = await supabaseAdmin.from("documents").select("id, doc_type, doc_number, issue_date, total, line_items, tax_rate, discount, subtotal, tax_amount, due_date, notes, org_id, client:clients(company_name, email)").eq("id", data.id).maybeSingle();
  if (error || !doc) return {
    status: "not_found"
  };
  const client = doc.client ?? {
    company_name: "—",
    email: null
  };
  const canonical = {
    doc_type: doc.doc_type,
    doc_number: doc.doc_number,
    issue_date: doc.issue_date,
    due_date: doc.due_date,
    line_items: doc.line_items ?? [],
    tax_rate: Number(doc.tax_rate),
    discount: Number(doc.discount),
    subtotal: Number(doc.subtotal),
    tax_amount: Number(doc.tax_amount),
    total: Number(doc.total),
    notes: doc.notes,
    client: {
      company_name: client.company_name,
      email: client.email
    }
  };
  const currentHash = await computeDocHash(canonical);
  if (currentHash !== data.hash) {
    return {
      status: "tampered",
      reason: "Document contents differ from the issued version."
    };
  }
  const {
    data: orgProf
  } = await supabaseAdmin.from("organization_profiles").select("name").eq("org_id", doc.org_id).maybeSingle();
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
    client_company: client.company_name
  };
});
export {
  issueVerifyToken_createServerFn_handler,
  publicVerify_createServerFn_handler
};
