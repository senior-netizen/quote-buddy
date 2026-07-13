import { supabaseAdmin } from "@/integrations/supabase/client.server";
import type { FdmsEnv } from "@/lib/fiscal/zimra.server";

export type DeviceConfigurationSnapshot = {
  orgId: string;
  deviceUuid: string;
  fdmsDeviceId: string;
  environment: FdmsEnv;
  configuration: Record<string, unknown>;
  source: "fdms" | "manual";
};

export class ConfigurationManager {
  async storeSnapshot(input: DeviceConfigurationSnapshot) {
    const { data, error } = await (supabaseAdmin as unknown as {
      from: (relation: string) => {
        insert: (row: Record<string, unknown>) => {
          select: (cols: string) => {
            single: () => { data: Record<string, unknown> | null; error: { message: string } | null };
          };
        };
      };
    }).from("device_configuration").insert({
      org_id: input.orgId,
      device_id: input.deviceUuid,
      fdms_device_id: input.fdmsDeviceId,
      environment: input.environment,
      source: input.source,
      configuration: input.configuration as never,
    } as never).select("*").single();
    if (error) throw new Error(error.message);
    return data as Record<string, unknown>;
  }

  async latest(deviceUuid: string) {
    const { data, error } = await (supabaseAdmin as unknown as {
      from: (relation: string) => {
        select: (cols: string) => {
          eq: (col: string, value: string) => {
            order: (col: string, opts: { ascending: boolean }) => {
              limit: (count: number) => {
                maybeSingle: () => { data: Record<string, unknown> | null; error: { message: string } | null };
              };
            };
          };
        };
      };
    }).from("device_configuration").select("*").eq("device_id", deviceUuid).order("created_at", { ascending: false }).limit(1).maybeSingle();
    if (error) throw new Error(error.message);
    return data as Record<string, unknown> | null;
  }
}
