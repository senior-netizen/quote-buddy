import { computeTotals, rowTotal } from "@/lib/calc";
import type { ReceiptDraft } from "./types";

export class ReceiptValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ReceiptValidationError";
  }
}

export class ReceiptValidator {
  validateDraft(draft: ReceiptDraft) {
    if (!draft.orgId) throw new ReceiptValidationError("No active organization");
    if (!draft.clientId) throw new ReceiptValidationError("Select a client");
    if (!draft.docNumber.trim()) throw new ReceiptValidationError("Document number missing");
    if (!draft.issueDate) throw new ReceiptValidationError("Issue date is required");
    this.validateLines(draft.lineItems);
    this.validateTotals(draft);
    return computeTotals(draft.lineItems, draft.taxRate, draft.discount);
  }

  validateReceiptReady(draft: ReceiptDraft) {
    const totals = this.validateDraft(draft);
    this.validateBuyer(draft);
    this.validateTaxes(draft, totals.tax_amount);
    this.validatePayments(draft, totals.total);
    return totals;
  }

  private validateLines(lines: ReceiptDraft["lineItems"]) {
    if (!lines.length) throw new ReceiptValidationError("Add at least one line item");
    lines.forEach((line, index) => {
      if (!line.description.trim()) throw new ReceiptValidationError(`Line ${index + 1} needs a description`);
      if (!Number.isFinite(Number(line.quantity)) || Number(line.quantity) <= 0) {
        throw new ReceiptValidationError(`Line ${index + 1} needs a positive quantity`);
      }
      if (!Number.isFinite(Number(line.unit_price)) || Number(line.unit_price) < 0) {
        throw new ReceiptValidationError(`Line ${index + 1} needs a valid unit price`);
      }
      if (rowTotal(line) < 0) throw new ReceiptValidationError(`Line ${index + 1} total is invalid`);
    });
  }

  private validateBuyer(draft: ReceiptDraft) {
    if (!draft.buyer?.company_name?.trim()) throw new ReceiptValidationError("Buyer name is required for fiscal receipts");
  }

  private validateTotals(draft: ReceiptDraft) {
    if (!Number.isFinite(Number(draft.taxRate)) || Number(draft.taxRate) < 0) {
      throw new ReceiptValidationError("Tax rate must be zero or greater");
    }
    if (!Number.isFinite(Number(draft.discount)) || Number(draft.discount) < 0) {
      throw new ReceiptValidationError("Discount must be zero or greater");
    }
    const totals = computeTotals(draft.lineItems, draft.taxRate, draft.discount);
    if (totals.subtotal < 0 || totals.tax_amount < 0 || totals.total < 0) {
      throw new ReceiptValidationError("Receipt totals cannot be negative");
    }
  }

  private validateTaxes(_draft: ReceiptDraft, taxAmount: number) {
    if (!Number.isFinite(taxAmount) || taxAmount < 0) throw new ReceiptValidationError("Tax amount is invalid");
  }

  private validatePayments(draft: ReceiptDraft, total: number) {
    const payments = draft.payments?.length ? draft.payments : [{ moneyTypeCode: "Cash", amount: total }];
    const paid = payments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
    if (Math.round(paid * 100) !== Math.round(total * 100)) {
      throw new ReceiptValidationError("Payments must equal the receipt total");
    }
  }
}
