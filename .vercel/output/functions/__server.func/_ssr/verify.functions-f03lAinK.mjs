import { w as createSsrRpc } from "./router-BDMLDL80.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { c as createServerFn } from "./index.mjs";
const issueVerifyToken = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => {
  if (!d?.id || typeof d.id !== "string" || d.id.length > 64) throw new Error("Invalid id");
  return d;
}).handler(createSsrRpc("62aee870b7d352bb450ac12ee2012d64454b03b21e0c3fb64dc9fcd5484a053d"));
const publicVerify = createServerFn({
  method: "POST"
}).inputValidator((d) => {
  if (!d?.id || !d?.sig || !d?.hash) throw new Error("Missing fields");
  if (d.id.length > 64 || d.sig.length > 128 || d.hash.length !== 64) throw new Error("Bad input");
  if (!/^[a-f0-9]{64}$/.test(d.hash)) throw new Error("Bad hash");
  return d;
}).handler(createSsrRpc("e95f2d768f72026d754fdf5fc3e00d936a621aec6c0ca5a383b442f2538d02ec"));
export {
  issueVerifyToken as i,
  publicVerify as p
};
