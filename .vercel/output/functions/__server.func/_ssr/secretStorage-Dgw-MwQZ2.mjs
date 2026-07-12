async function loadCrypto() {
  return import("node:crypto");
}
function getFiscalSecretKey() {
  return process.env.FISCAL_SECRET_ENCRYPTION_KEY ?? null;
}
async function importFiscalSecretKey() {
  const secret = getFiscalSecretKey();
  if (!secret) throw new Error("FISCAL_SECRET_ENCRYPTION_KEY is required for fiscal secret storage");
  const bytes = Buffer.from(secret, "base64");
  if (![16, 24, 32].includes(bytes.byteLength)) {
    throw new Error("FISCAL_SECRET_ENCRYPTION_KEY must be base64-encoded AES key material");
  }
  const { webcrypto } = await loadCrypto();
  return webcrypto.subtle.importKey("raw", bytes, "AES-GCM", false, ["encrypt", "decrypt"]);
}
async function encryptFiscalSecret(plaintext) {
  const { randomBytes, webcrypto } = await loadCrypto();
  const iv = randomBytes(12);
  const key = await importFiscalSecretKey();
  const cipher = await webcrypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plaintext));
  return `aes-gcm:v1:${iv.toString("base64")}:${Buffer.from(cipher).toString("base64")}`;
}
export {
  encryptFiscalSecret
};
