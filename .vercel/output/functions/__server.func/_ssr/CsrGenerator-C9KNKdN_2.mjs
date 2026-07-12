const OIDS = {
  commonName: "2.5.4.3",
  organizationName: "2.5.4.10",
  organizationalUnitName: "2.5.4.11",
  countryName: "2.5.4.6",
  serialNumber: "2.5.4.5",
  sha256WithRsaEncryption: "1.2.840.113549.1.1.11"
};
function len(length) {
  if (length < 128) return Buffer.from([length]);
  const bytes = [];
  let value = length;
  while (value > 0) {
    bytes.unshift(value & 255);
    value >>= 8;
  }
  return Buffer.from([128 | bytes.length, ...bytes]);
}
function tlv(tag, value) {
  return Buffer.concat([Buffer.from([tag]), len(value.length), value]);
}
function seq(...values) {
  return tlv(48, Buffer.concat(values));
}
function set(...values) {
  return tlv(49, Buffer.concat(values));
}
function oid(value) {
  const parts = value.split(".").map(Number);
  const encoded = [40 * parts[0] + parts[1]];
  for (const part of parts.slice(2)) {
    const stack = [part & 127];
    let current = part >> 7;
    while (current > 0) {
      stack.unshift(current & 127 | 128);
      current >>= 7;
    }
    encoded.push(...stack);
  }
  return tlv(6, Buffer.from(encoded));
}
function printable(value) {
  return tlv(19, Buffer.from(value, "ascii"));
}
function utf8(value) {
  return tlv(12, Buffer.from(value, "utf8"));
}
function attr(type, value) {
  const stringValue = type === "countryName" ? printable(value.slice(0, 2).toUpperCase()) : utf8(value);
  return set(seq(oid(OIDS[type]), stringValue));
}
function pem(label, der) {
  const body = der.toString("base64").match(/.{1,64}/g)?.join("\n") ?? "";
  return `-----BEGIN ${label}-----
${body}
-----END ${label}-----
`;
}
class CsrGenerator {
  async generate(subject, keySize = 2048) {
    const { createHash, generateKeyPairSync } = await import("node:crypto");
    const { privateKey, publicKey } = generateKeyPairSync("rsa", {
      modulusLength: keySize,
      publicExponent: 65537,
      privateKeyEncoding: { type: "pkcs8", format: "pem" },
      publicKeyEncoding: { type: "spki", format: "pem" }
    });
    const csrPem = await this.generateWithPrivateKey(subject, privateKey);
    return {
      csrPem,
      privateKeyPem: privateKey,
      publicKeyPem: publicKey,
      keyAlgorithm: "RSA",
      keySize,
      csrFingerprint: createHash("sha256").update(csrPem).digest("hex")
    };
  }
  async generateWithPrivateKey(subject, privateKeyPem) {
    const { createPrivateKey, createPublicKey, createSign } = await import("node:crypto");
    const privateKey = createPrivateKey(privateKeyPem);
    const publicKey = createPublicKey(privateKey).export({ type: "spki", format: "pem" });
    const subjectName = seq(
      attr("commonName", subject.commonName),
      ...subject.organizationName ? [attr("organizationName", subject.organizationName)] : [],
      ...subject.organizationalUnitName ? [attr("organizationalUnitName", subject.organizationalUnitName)] : [],
      ...subject.countryName ? [attr("countryName", subject.countryName)] : [],
      ...subject.serialNumber ? [attr("serialNumber", subject.serialNumber)] : []
    );
    const publicKeyDer = Buffer.from(String(publicKey).replace(/-----[^-]+-----|\s/g, ""), "base64");
    const certificationRequestInfo = seq(
      tlv(2, Buffer.from([0])),
      subjectName,
      publicKeyDer,
      tlv(160, Buffer.alloc(0))
    );
    const signer = createSign("RSA-SHA256");
    signer.update(certificationRequestInfo);
    signer.end();
    const signature = signer.sign(privateKeyPem);
    const csrDer = seq(
      certificationRequestInfo,
      seq(oid(OIDS.sha256WithRsaEncryption), tlv(5, Buffer.alloc(0))),
      tlv(3, Buffer.concat([Buffer.from([0]), signature]))
    );
    return pem("CERTIFICATE REQUEST", csrDer);
  }
}
export {
  CsrGenerator
};
