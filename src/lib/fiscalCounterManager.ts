import { supabaseAdmin } from "@/integrations/supabase/client.server";

export type FiscalCounterAllocation = {
  fiscalDayNo: number;
  receiptGlobalNo: number;
  receiptCounter: number;
  receiptTypeCounter: number | null;
  invoiceNo: string;
};

type AllocationRow = {
  fiscal_day_no: number;
  receipt_global_no: number;
  receipt_counter: number;
  receipt_type_counter: number | null;
  invoice_no: string;
};

export class FiscalCounterManager {
  static async allocateInvoiceCounters(
    orgId: string,
    documentId: string,
  ): Promise<FiscalCounterAllocation> {
    const { data, error } = await supabaseAdmin.rpc("allocate_fiscal_receipt_counters", {
      _org_id: orgId,
      _document_id: documentId,
      _receipt_type: "FiscalInvoice",
      _requires_receipt_type_counter: true,
    });

    if (error) throw new Error(error.message);

    const row = Array.isArray(data) ? (data[0] as AllocationRow | undefined) : undefined;
    if (!row) throw new Error("Fiscal counter allocation failed");

    return {
      fiscalDayNo: row.fiscal_day_no,
      receiptGlobalNo: Number(row.receipt_global_no),
      receiptCounter: Number(row.receipt_counter),
      receiptTypeCounter:
        row.receipt_type_counter === null ? null : Number(row.receipt_type_counter),
      invoiceNo: row.invoice_no,
    };
  }

  static async markSubmitted(documentId: string, submittedAt: string): Promise<void> {
    const { error } = await supabaseAdmin
      .from("receipt_history")
      .update({ status: "submitted", submitted_at: submittedAt } as never)
      .eq("document_id", documentId);
    if (error) throw new Error(error.message);
  }

  static async markFailed(documentId: string): Promise<void> {
    const { error } = await supabaseAdmin
      .from("receipt_history")
      .update({ status: "failed" } as never)
      .eq("document_id", documentId);
    if (error) throw new Error(error.message);
  }
}
