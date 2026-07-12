import { _ as _enum } from "../_libs/zod.mjs";
const SUPPORTED_DOCUMENT_TYPES = ["quote", "invoice", "credit_note", "debit_note", "receipt"];
const documentTypeSchema = _enum(SUPPORTED_DOCUMENT_TYPES);
const DEFAULT_DOCUMENT_TYPE = "quote";
function getDocumentTypeLabel(type) {
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
function getDocumentTypeShortLabel(type) {
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
function getDocumentTypePrefix(type) {
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
function getDueDateLabel(type) {
  return type === "invoice" || type === "credit_note" ? "Due date" : "Valid until";
}
function isFiscalDocumentType(type) {
  return type === "invoice";
}
export {
  DEFAULT_DOCUMENT_TYPE as D,
  getDocumentTypeShortLabel as a,
  getDocumentTypeLabel as b,
  getDueDateLabel as c,
  documentTypeSchema as d,
  getDocumentTypePrefix as g,
  isFiscalDocumentType as i
};
