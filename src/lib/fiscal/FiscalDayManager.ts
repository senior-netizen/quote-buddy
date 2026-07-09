import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";
import type { FiscalDayRow } from "./types";

export class FiscalDayManager {
  constructor(private readonly supabase: SupabaseClient<Database>) {}

  async requireOpenDay(orgId: string): Promise<FiscalDayRow> {
    const { data, error } = await this.supabase
      .from("fiscal_days")
      .select("id, fiscal_day_no, status")
      .eq("org_id", orgId)
      .eq("status", "open")
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error("Open a fiscal day before creating fiscal receipts");
    return data;
  }
}
