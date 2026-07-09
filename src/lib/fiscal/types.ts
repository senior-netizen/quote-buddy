import type { Json } from "@/integrations/supabase/types";
import type { LineItem } from "@/lib/calc";

export type FiscalReceiptState = "Draft" | "Ready";

export type ReceiptBuyer = {
  company_name: string;
  address: string | null;
  email: string | null;
  phone: string | null;
};

export type ReceiptDraft = {
  orgId: string;
  userId: string;
  clientId: string;
  docType: "quote" | "invoice";
  docNumber: string;
  issueDate: string;
  dueDate: string | null;
  lineItems: LineItem[];
  taxRate: number;
  discount: number;
  notes: string | null;
  buyer?: ReceiptBuyer | null;
  payments?: { moneyTypeCode: string; amount: number }[];
};

export type FiscalConfigRow = {
  org_id: string;
  enabled: boolean;
  currency?: string | null;
  last_receipt_counter: number;
  last_receipt_global_no: number;
};

export type FiscalDayRow = {
  id: string;
  fiscal_day_no: number;
  status: string;
};

export type FiscalCounters = {
  receiptGlobalNo: number;
  receiptCounter: number;
};

export type ReceiptCreationPlan = {
  fiscalized: boolean;
  state: FiscalReceiptState;
  fiscalDayNo: number | null;
  counters: FiscalCounters | null;
  subtotal: number;
  tax_amount: number;
  total: number;
  fiscalResponse?: Json | null;
};
