import { createHash, randomBytes, webcrypto } from "node:crypto";

function getFiscalSecretKey(): string | null {
  return process.env.FISCAL_SECRET_ENCRYPTION_KEY ?? null;
}

async function importFiscalSecretKey() {
  const secret = getFiscalSecretKey();
  if (!secret) throw new Error("FISCAL_SECRET_ENCRYPTION_KEY is required for fiscal secret storage");
  const bytes = Buffer.from(secret, "base64");
  if (![16, 24, 32].includes(bytes.byteLength)) {
    throw new Error("FISCAL_SECRET_ENCRYPTION_KEY must be base64-encoded AES key material");
  }
  return webcrypto.subtle.importKey("raw", bytes, "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function encryptFiscalSecret(plaintext: string): Promise<string> {
  const iv = randomBytes(12);
  const key = await importFiscalSecretKey();
  const cipher = await webcrypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plaintext));
  return `aes-gcm:v1:${iv.toString("base64")}:${Buffer.from(cipher).toString("base64")}`;
}

export async function decryptFiscalSecret(payload: string | null): Promise<string | null> {
  if (!payload) return null;
  const [, , ivB64, cipherB64] = payload.split(":");
  if (!ivB64 || !cipherB64) throw new Error("Invalid encrypted fiscal secret payload");
  const key = await importFiscalSecretKey();
  const plain = await webcrypto.subtle.decrypt(
    { name: "AES-GCM", iv: Buffer.from(ivB64, "base64") },
    key,
    Buffer.from(cipherB64, "base64"),
  );
  return new TextDecoder().decode(plain);
}

export function sha256Hex(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
