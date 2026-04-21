import { createHmac } from "crypto";

function getSecret(): string {
  const s = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!s) throw new Error("Missing signing secret");
  return s;
}

/** Signs `${id}|${hash}` with HMAC-SHA256, returns base64url. */
export function signVerifyToken(id: string, hash: string): string {
  const mac = createHmac("sha256", getSecret()).update(`${id}|${hash}`).digest();
  return Buffer.from(mac)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

export function verifyToken(id: string, hash: string, sig: string): boolean {
  const expected = signVerifyToken(id, hash);
  if (expected.length !== sig.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ sig.charCodeAt(i);
  return diff === 0;
}
