import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { useQuery, useMutation } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import {
  getFiscalConfig,
  updateFiscalConfig,
  onboardFiscalDeviceSecrets,
  testDeviceConnection,
  openFiscalDay,
  closeFiscalDay,
  listFiscalDays,
  getCurrentFiscalDay,
} from "@/lib/fiscal.functions";

export const Route = createFileRoute("/settings/fiscal")({ component: FiscalSettings });

type Form = {
  enabled: boolean;
  environment: "test" | "prod";
  device_id: string;
  device_serial: string;
  device_model: string;
  activation_key: string;
  tax_payer_name: string;
  tax_payer_tin: string;
  vat_number: string;
  trade_name: string;
  device_operating_mode: string;
  certificate_pem: string;
  private_key_pem: string;
};

function FiscalSettings() {
  const router = useRouter();
  const getConfig = useServerFn(getFiscalConfig);
  const updateConfig = useServerFn(updateFiscalConfig);
  const onboardSecrets = useServerFn(onboardFiscalDeviceSecrets);
  const testConn = useServerFn(testDeviceConnection);
  const openDay = useServerFn(openFiscalDay);
  const closeDay = useServerFn(closeFiscalDay);
  const listDays = useServerFn(listFiscalDays);
  const currentDay = useServerFn(getCurrentFiscalDay);

  const { data: config, refetch: refetchConfig } = useQuery({
    queryKey: ["fiscal-config"],
    queryFn: () => getConfig(),
  });
  const { data: currDay, refetch: refetchCurrDay } = useQuery({
    queryKey: ["fiscal-current-day"],
    queryFn: () => currentDay(),
  });
  const { data: days, refetch: refetchDays } = useQuery({
    queryKey: ["fiscal-days"],
    queryFn: () => listDays(),
  });

  const [form, setForm] = useState<Form>({
    enabled: false,
    environment: "test",
    device_id: "",
    device_serial: "",
    device_model: "",
    activation_key: "",
    tax_payer_name: "",
    tax_payer_tin: "",
    vat_number: "",
    trade_name: "",
    device_operating_mode: "Online",
    certificate_pem: "",
    private_key_pem: "",
  });

  useEffect(() => {
    if (!config) return;
    setForm((f) => ({
      ...f,
      enabled: config.enabled,
      environment: config.environment,
      device_id: config.device_id ?? "",
      device_serial: config.device_serial ?? "",
      device_model: config.device_model ?? "",
      activation_key: "",
      tax_payer_name: config.tax_payer_name ?? "",
      tax_payer_tin: config.tax_payer_tin ?? "",
      vat_number: config.vat_number ?? "",
      trade_name: config.trade_name ?? "",
      device_operating_mode: config.device_operating_mode,
      // Leave PEMs blank in the UI even if stored — write-only.
      certificate_pem: "",
      private_key_pem: "",
    }));
  }, [config]);

  const save = useMutation({
    mutationFn: async () => {
      const { activation_key, certificate_pem, private_key_pem, ...configPayload } = form;
      if (activation_key || certificate_pem || private_key_pem) {
        await onboardSecrets({
          data: {
            ...(activation_key ? { activation_key } : {}),
            ...(certificate_pem ? { certificate_pem } : {}),
            ...(private_key_pem ? { private_key_pem } : {}),
          },
        });
      }
      return updateConfig({ data: configPayload });
    },
    onSuccess: () => {
      toast.success("Fiscal settings saved");
      refetchConfig();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed"),
  });

  const test = useMutation({
    mutationFn: () => testConn(),
    onSuccess: (r) => (r.ok ? toast.success(r.message) : toast.error(r.message)),
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
  });

  const open = useMutation({
    mutationFn: () => openDay(),
    onSuccess: () => {
      toast.success("Fiscal day opened");
      refetchCurrDay();
      refetchDays();
      refetchConfig();
      router.invalidate();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
  });

  const close = useMutation({
    mutationFn: () => closeDay(),
    onSuccess: () => {
      toast.success("Fiscal day closed");
      refetchCurrDay();
      refetchDays();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed"),
  });

  return (
    <div className="space-y-10 max-w-3xl">
      <section>
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-medium">ZIMRA Fiscalisation</h2>
            <p className="text-sm text-muted-foreground mt-1">
              Register your device with the Zimbabwe Revenue Authority's FDMS to submit invoices as
              fiscal receipts.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Switch
              id="enabled"
              checked={form.enabled}
              onCheckedChange={(v) => setForm((f) => ({ ...f, enabled: v }))}
            />
            <Label htmlFor="enabled">Enabled</Label>
          </div>
        </div>

        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          <div>
            <Label>Environment</Label>
            <select
              value={form.environment}
              onChange={(e) =>
                setForm((f) => ({ ...f, environment: e.target.value as "test" | "prod" }))
              }
              className="mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
            >
              <option value="test">Sandbox (fdmsapitest.zimra.co.zw)</option>
              <option value="prod">Production (fdmsapi.zimra.co.zw)</option>
            </select>
          </div>
          <div>
            <Label>Device ID</Label>
            <Input
              value={form.device_id}
              onChange={(e) => setForm((f) => ({ ...f, device_id: e.target.value }))}
            />
          </div>
          <div>
            <Label>Device Serial Number</Label>
            <Input
              value={form.device_serial}
              onChange={(e) => setForm((f) => ({ ...f, device_serial: e.target.value }))}
            />
          </div>
          <div>
            <Label>Device Model</Label>
            <Input
              value={form.device_model}
              onChange={(e) => setForm((f) => ({ ...f, device_model: e.target.value }))}
            />
          </div>
          <div className="sm:col-span-2">
            <Label>Activation Key</Label>
            <Input
              type="password"
              value={form.activation_key}
              onChange={(e) => setForm((f) => ({ ...f, activation_key: e.target.value }))}
            />
          </div>
          <div>
            <Label>Taxpayer name</Label>
            <Input
              value={form.tax_payer_name}
              onChange={(e) => setForm((f) => ({ ...f, tax_payer_name: e.target.value }))}
            />
            <p className="text-xs text-muted-foreground mt-1">
              Enter this exactly as shown as the ZIMRA Company Name on the activation record.
            </p>
          </div>
          <div>
            <Label>Trade name</Label>
            <Input
              value={form.trade_name}
              onChange={(e) => setForm((f) => ({ ...f, trade_name: e.target.value }))}
            />
            <p className="text-xs text-muted-foreground mt-1">
              Enter this exactly as shown as the ZIMRA Trade Name on the activation record, even if
              it differs from the company name.
            </p>
          </div>
          <div>
            <Label>TIN</Label>
            <Input
              value={form.tax_payer_tin}
              onChange={(e) => setForm((f) => ({ ...f, tax_payer_tin: e.target.value }))}
            />
          </div>
          <div>
            <Label>VAT number</Label>
            <Input
              value={form.vat_number}
              onChange={(e) => setForm((f) => ({ ...f, vat_number: e.target.value }))}
            />
          </div>
        </div>

        <div className="mt-6 space-y-4">
          <div>
            <Label>Device certificate (PEM)</Label>
            <Textarea
              rows={5}
              placeholder={
                config?.has_certificate
                  ? "•••••••••• (saved — paste a new one to replace)"
                  : "-----BEGIN CERTIFICATE-----"
              }
              value={form.certificate_pem}
              onChange={(e) => setForm((f) => ({ ...f, certificate_pem: e.target.value }))}
            />
          </div>
          <div>
            <Label>Device private key (PEM)</Label>
            <Textarea
              rows={5}
              placeholder={
                config?.has_private_key
                  ? "•••••••••• (saved — paste a new one to replace)"
                  : "-----BEGIN PRIVATE KEY-----"
              }
              value={form.private_key_pem}
              onChange={(e) => setForm((f) => ({ ...f, private_key_pem: e.target.value }))}
            />
            <p className="text-xs text-muted-foreground mt-1">
              Stored encrypted at rest. Used for the mTLS handshake against FDMS.
            </p>
          </div>
        </div>

        <div className="mt-6 flex gap-2">
          <Button onClick={() => save.mutate()} disabled={save.isPending}>
            {save.isPending ? "Saving…" : "Save settings"}
          </Button>
          <Button
            variant="outline"
            onClick={() => test.mutate()}
            disabled={test.isPending || !config?.enabled}
          >
            {test.isPending ? "Testing…" : "Test connection"}
          </Button>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-medium">Fiscal Day</h2>
        <p className="text-sm text-muted-foreground mt-1">
          A fiscal day must be open before invoices can be submitted to FDMS.
        </p>
        <div className="mt-4 rounded-lg border border-hairline p-4">
          {currDay ? (
            <div className="flex items-center justify-between gap-3">
              <div>
                <div className="text-sm">
                  Day <span className="font-mono">#{currDay.fiscal_day_no}</span> is{" "}
                  <span className="font-medium">OPEN</span>
                </div>
                <div className="text-xs text-muted-foreground">
                  Opened {new Date(currDay.opened_at).toLocaleString()}
                </div>
              </div>
              <Button variant="outline" onClick={() => close.mutate()} disabled={close.isPending}>
                {close.isPending ? "Closing…" : "Close day"}
              </Button>
            </div>
          ) : (
            <div className="flex items-center justify-between gap-3">
              <div className="text-sm text-muted-foreground">No open fiscal day.</div>
              <Button onClick={() => open.mutate()} disabled={open.isPending || !config?.enabled}>
                {open.isPending ? "Opening…" : "Open day"}
              </Button>
            </div>
          )}
        </div>

        {days && days.length > 0 && (
          <div className="mt-4 rounded-lg border border-hairline overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-xs uppercase tracking-wider text-muted-foreground">
                <tr>
                  <th className="text-left p-3">Day</th>
                  <th className="text-left p-3">Opened</th>
                  <th className="text-left p-3">Closed</th>
                  <th className="text-left p-3">Status</th>
                </tr>
              </thead>
              <tbody>
                {days.map((d) => (
                  <tr key={d.id} className="border-t border-hairline">
                    <td className="p-3 font-mono">#{d.fiscal_day_no}</td>
                    <td className="p-3">{new Date(d.opened_at).toLocaleString()}</td>
                    <td className="p-3">
                      {d.closed_at ? new Date(d.closed_at).toLocaleString() : "—"}
                    </td>
                    <td className="p-3 uppercase text-xs">{d.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
