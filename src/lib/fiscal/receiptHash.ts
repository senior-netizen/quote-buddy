/**
 * ZIMRA FDMS receipt hash.
 *
 * Per FDMS spec §5.2, the receipt hash is the SHA-256 (base64) of the
 * concatenation (in this exact order) of:
 *   deviceID
 *   receiptType (FiscalInvoice | CreditNote | DebitNote)
 *   receiptCurrency (ISO 4217)
 *   receiptGlobalNo
 *   receiptDate (yyyy-MM-ddTHH:mm:ss, no zone)
 *   receiptTotal (in cents, integer)
 *   concat(taxCode + taxPercent + taxAmount) for every tax line, sorted by taxCode
 *   previousReceiptHash (empty for the first receipt of the day)
 *
 * The 16-char verification code is the first 8 hex bytes of the same digest.
 */

export type ReceiptTax = {
  taxCode: string;
  taxPercent: number;
  taxAmount: number; // in cents
};

export type ReceiptHashInput = {
  deviceId: string | number;
  receiptType: "FiscalInvoice" | "CreditNote" | "DebitNote";
  receiptCurrency: string;
  receiptGlobalNo: number;
  receiptDate: string; // yyyy-MM-ddTHH:mm:ss
  receiptTotalCents: number;
  taxes: ReceiptTax[];
  previousReceiptHash: string;
};

function toBase64(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function toHex(bytes: Uint8Array): string {
  let out = "";
  for (let i = 0; i < bytes.length; i++) out += bytes[i].toString(16).padStart(2, "0");
  return out;
}

export async function computeReceiptHash(input: ReceiptHashInput): Promise<{
  hashBase64: string;
  hashHex: string;
  verificationCode: string;
  concatenated: string;
}> {
  const sortedTaxes = [...input.taxes].sort((a, b) => a.taxCode.localeCompare(b.taxCode));
  const taxPart = sortedTaxes
    .map((t) => `${t.taxCode}${t.taxPercent}${t.taxAmount}`)
    .join("");

  const concatenated =
    `${input.deviceId}` +
    `${input.receiptType}` +
    `${input.receiptCurrency}` +
    `${input.receiptGlobalNo}` +
    `${input.receiptDate}` +
    `${input.receiptTotalCents}` +
    `${taxPart}` +
    `${input.previousReceiptHash ?? ""}`;

  const enc = new TextEncoder().encode(concatenated);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", enc));
  const hashBase64 = toBase64(digest);
  const hashHex = toHex(digest);
  // 16-char human-readable verification code
  const verificationCode = hashHex.slice(0, 16).toUpperCase();
  return { hashBase64, hashHex, verificationCode, concatenated };
}
