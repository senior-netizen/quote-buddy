import { z } from "zod";

export const SUPPORTED_DOCUMENT_TYPES = ["quote", "invoice", "credit_note", "debit_note", "receipt"] as const;
export const documentTypeSchema = z.enum(SUPPORTED_DOCUMENT_TYPES);
export type DocumentType = (typeof SUPPORTED_DOCUMENT_TYPES)[number];

export const DEFAULT_DOCUMENT_TYPE: DocumentType = "quote";

export function getDocumentTypeLabel(type: DocumentType): string {
  switch (type) {
    case "invoice":
      return "Invoice";
    case "credit_note":
      return "Credit Note";
    case "debit_note":
      return "Debit Note";
    case "receipt":
      return "Receipt";
    case "quote":
    default:
      return "Quotation";
  }
}

export function getDocumentTypeShortLabel(type: DocumentType): string {
  switch (type) {
    case "invoice":
      return "Invoice";
    case "credit_note":
      return "Credit note";
    case "debit_note":
      return "Debit note";
    case "receipt":
      return "Receipt";
    case "quote":
    default:
      return "Quote";
  }
}

export function getDocumentTypePrefix(type: DocumentType): string {
  switch (type) {
    case "invoice":
      return "INV";
    case "credit_note":
      return "CN";
    case "debit_note":
      return "DN";
    case "receipt":
      return "RC";
    case "quote":
    default:
      return "QT";
  }
}

export function getDocumentTypePathSegment(type: DocumentType): string {
  switch (type) {
    case "invoice":
      return "invoices";
    case "credit_note":
      return "credit-notes";
    case "debit_note":
      return "debit-notes";
    case "receipt":
      return "receipts";
    case "quote":
    default:
      return "quotes";
  }
}

export function getDueDateLabel(type: DocumentType): string {
  return type === "invoice" || type === "credit_note" ? "Due date" : "Valid until";
}

export function isFiscalDocumentType(type: DocumentType): boolean {
  return type === "invoice";
}
