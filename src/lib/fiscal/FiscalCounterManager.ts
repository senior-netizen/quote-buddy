import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";
import type { FiscalCounters } from "./types";

export class FiscalCounterManager {
  constructor(private readonly supabase: SupabaseClient<Database>) {}

  async allocate(orgId: string): Promise<FiscalCounters> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const { data: current, error: loadError } = await this.supabase
        .from("organization_fiscal_config")
        .select("last_receipt_global_no, last_receipt_counter")
        .eq("org_id", orgId)
        .single();
      if (loadError) throw new Error(loadError.message);

      const receiptGlobalNo = Number(current.last_receipt_global_no ?? 0) + 1;
      const receiptCounter = Number(current.last_receipt_counter ?? 0) + 1;
      const { data: updated, error } = await this.supabase
        .from("organization_fiscal_config")
        .update({ last_receipt_global_no: receiptGlobalNo, last_receipt_counter: receiptCounter })
        .eq("org_id", orgId)
        .eq("last_receipt_global_no", current.last_receipt_global_no)
        .eq("last_receipt_counter", current.last_receipt_counter)
        .select("org_id")
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (updated) return { receiptGlobalNo, receiptCounter };
    }
    throw new Error("Could not allocate fiscal counters. Please try again.");
  }
}
