export type CsrSubject = {
  commonName: string;
  organizationName?: string | null;
  organizationalUnitName?: string | null;
  countryName?: string | null;
  serialNumber?: string | null;
};

export type GeneratedCsr = {
  csrPem: string;
  privateKeyPem: string;
  publicKeyPem: string;
  keyAlgorithm: "RSA";
  keySize: number;
  csrFingerprint: string;
};

const OIDS = {
  commonName: "2.5.4.3",
  organizationName: "2.5.4.10",
  organizationalUnitName: "2.5.4.11",
  countryName: "2.5.4.6",
  serialNumber: "2.5.4.5",
  sha256WithRsaEncryption: "1.2.840.113549.1.1.11",
};

function len(length: number): Buffer {
  if (length < 128) return Buffer.from([length]);
  const bytes: number[] = [];
  let value = length;
  while (value > 0) {
    bytes.unshift(value & 0xff);
    value >>= 8;
  }
  return Buffer.from([0x80 | bytes.length, ...bytes]);
}

function tlv(tag: number, value: Buffer): Buffer {
  return Buffer.concat([Buffer.from([tag]), len(value.length), value]);
}

function seq(...values: Buffer[]) {
  return tlv(0x30, Buffer.concat(values));
}

function set(...values: Buffer[]) {
  return tlv(0x31, Buffer.concat(values));
}

function oid(value: string): Buffer {
  const parts = value.split(".").map(Number);
  const encoded = [40 * parts[0] + parts[1]];
  for (const part of parts.slice(2)) {
    const stack = [part & 0x7f];
    let current = part >> 7;
    while (current > 0) {
      stack.unshift((current & 0x7f) | 0x80);
      current >>= 7;
    }
    encoded.push(...stack);
  }
  return tlv(0x06, Buffer.from(encoded));
}

function printable(value: string) {
  return tlv(0x13, Buffer.from(value, "ascii"));
}

function utf8(value: string) {
  return tlv(0x0c, Buffer.from(value, "utf8"));
}

function attr(type: keyof typeof OIDS, value: string) {
  const stringValue = type === "countryName" ? printable(value.slice(0, 2).toUpperCase()) : utf8(value);
  return set(seq(oid(OIDS[type]), stringValue));
}

function pem(label: string, der: Buffer) {
  const body = der.toString("base64").match(/.{1,64}/g)?.join("\n") ?? "";
  return `-----BEGIN ${label}-----\n${body}\n-----END ${label}-----\n`;
}

export class CsrGenerator {
  async generate(subject: CsrSubject, keySize = 2048): Promise<GeneratedCsr> {
    const { createHash, generateKeyPairSync } = await import("node:crypto");
    const { privateKey, publicKey } = generateKeyPairSync("rsa", {
      modulusLength: keySize,
      publicExponent: 0x10001,
      privateKeyEncoding: { type: "pkcs8", format: "pem" },
      publicKeyEncoding: { type: "spki", format: "pem" },
    });

    const csrPem = await this.generateWithPrivateKey(subject, privateKey);

    return {
      csrPem,
      privateKeyPem: privateKey,
      publicKeyPem: publicKey,
      keyAlgorithm: "RSA",
      keySize,
      csrFingerprint: createHash("sha256").update(csrPem).digest("hex"),
    };
  }

  async generateWithPrivateKey(subject: CsrSubject, privateKeyPem: string): Promise<string> {
    const { createPrivateKey, createPublicKey, createSign } = await import("node:crypto");
    const privateKey = createPrivateKey(privateKeyPem);
    const publicKey = createPublicKey(privateKey).export({ type: "spki", format: "pem" });
    const subjectName = seq(
      attr("commonName", subject.commonName),
      ...(subject.organizationName ? [attr("organizationName", subject.organizationName)] : []),
      ...(subject.organizationalUnitName ? [attr("organizationalUnitName", subject.organizationalUnitName)] : []),
      ...(subject.countryName ? [attr("countryName", subject.countryName)] : []),
      ...(subject.serialNumber ? [attr("serialNumber", subject.serialNumber)] : []),
    );
    const publicKeyDer = Buffer.from(String(publicKey).replace(/-----[^-]+-----|\s/g, ""), "base64");
    const certificationRequestInfo = seq(
      tlv(0x02, Buffer.from([0x00])),
      subjectName,
      publicKeyDer,
      tlv(0xa0, Buffer.alloc(0)),
    );
    const signer = createSign("RSA-SHA256");
    signer.update(certificationRequestInfo);
    signer.end();
    const signature = signer.sign(privateKeyPem);
    const csrDer = seq(
      certificationRequestInfo,
      seq(oid(OIDS.sha256WithRsaEncryption), tlv(0x05, Buffer.alloc(0))),
      tlv(0x03, Buffer.concat([Buffer.from([0x00]), signature])),
    );
    return pem("CERTIFICATE REQUEST", csrDer);
  }
}
