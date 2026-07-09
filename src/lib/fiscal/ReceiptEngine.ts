import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/integrations/supabase/types";
import { ReceiptValidator } from "./ReceiptValidator";
import { FiscalCounterManager } from "./FiscalCounterManager";
import { FiscalDayManager } from "./FiscalDayManager";
import type { FiscalConfigRow, ReceiptCreationPlan, ReceiptDraft } from "./types";

export class ReceiptEngine {
  private readonly validator = new ReceiptValidator();
  private readonly days: FiscalDayManager;
  private readonly counters: FiscalCounterManager;

  constructor(private readonly supabase: SupabaseClient<Database>) {
    this.days = new FiscalDayManager(supabase);
    this.counters = new FiscalCounterManager(supabase);
  }

  async planCreation(draft: ReceiptDraft): Promise<ReceiptCreationPlan> {
    const totals = this.validator.validateDraft(draft);
    const config = await this.loadFiscalConfig(draft.orgId);
    const fiscalized = draft.docType === "invoice" && Boolean(config?.enabled);

    if (!fiscalized) {
      return { fiscalized: false, state: "Draft", fiscalDayNo: null, counters: null, ...totals };
    }

    this.validator.validateReceiptReady(draft);
    const openDay = await this.days.requireOpenDay(draft.orgId);
    const counters = await this.counters.allocate(draft.orgId);

    return {
      fiscalized: true,
      state: "Ready",
      fiscalDayNo: openDay.fiscal_day_no,
      counters,
      ...totals,
    };
  }

  private async loadFiscalConfig(orgId: string): Promise<FiscalConfigRow | null> {
    const { data, error } = await this.supabase
      .from("organization_fiscal_config")
      .select("org_id, enabled, currency, last_receipt_counter, last_receipt_global_no")
      .eq("org_id", orgId)
      .maybeSingle();
    if (error) throw new Error(error.message);
    return data as FiscalConfigRow | null;
  }
}
