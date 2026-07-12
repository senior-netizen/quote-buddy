import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useServerFn } from "@tanstack/react-start";
import { useQuery, useMutation } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
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

type ValidationExpected = {
  tax_payer_tin: string;
  vat_number: string;
  tax_payer_name: string;
  trade_name: string;
  device_id: string;
  has_activation_key: boolean | null;
  device_address: string;
  device_model: string;
  device_model_version: string;
};

type Form = {
  enabled: boolean;
  environment: "test" | "prod";
  device_id: string;
  device_serial: string;
  device_address: string;
  device_model_name: string;
  device_model_version: string;
  activation_key: string;
  tax_payer_name: string;
  tax_payer_tin: string;
  vat_number: string;
  trade_name: string;
  device_operating_mode: string;
  certificate_pem: string;
  private_key_pem: string;
};


const emptyExpected: ValidationExpected = {
  tax_payer_tin: "",
  vat_number: "",
  tax_payer_name: "",
  trade_name: "",
  device_id: "",
  has_activation_key: null,
  device_address: "",
  device_model: "",
  device_model_version: "",
};

function normalizeComparable(value: string | null | undefined) {
  return (value ?? "").trim().replace(/\s+/g, " ").toLowerCase();
}

function isExpectedProvided(expected: ValidationExpected) {
  return Object.entries(expected).some(([key, value]) =>
    key === "has_activation_key" ? value !== null : Boolean((value as string).trim()),
  );
}

function compareText(current: string | null | undefined, expected: string, options?: { allowBlankExpected?: boolean }) {
  const expectedNormalized = normalizeComparable(expected);
  if (!expectedNormalized && !options?.allowBlankExpected) return "not_checked" as const;
  return normalizeComparable(current) === expectedNormalized ? "match" as const : "mismatch" as const;
}

function statusClass(status: "match" | "mismatch" | "not_checked") {
  if (status === "match") return "text-emerald-600";
  if (status === "mismatch") return "text-destructive";
  return "text-muted-foreground";
}

function statusLabel(status: "match" | "mismatch" | "not_checked") {
  if (status === "match") return "Match";
  if (status === "mismatch") return "Review";
  return "Not checked";
}

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

  const [expected, setExpected] = useState<ValidationExpected>(emptyExpected);
  const [expectedImport, setExpectedImport] = useState("");

  const [form, setForm] = useState<Form>({
    enabled: false,
    environment: "test",
    device_id: "",
    device_serial: "",
    device_address: "",
    device_model_name: "Server",
    device_model_version: "v1",
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
      device_address: config.device_address ?? "",
      device_model_name: config.device_model_name ?? config.device_model ?? "Server",
      device_model_version: config.device_model_version ?? "v1",
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


  const validationRows = useMemo(() => {
    const rows = [
      { label: "TIN", status: compareText(form.tax_payer_tin, expected.tax_payer_tin), current: form.tax_payer_tin || "—", expected: expected.tax_payer_tin || "—" },
      { label: "VAT number", status: compareText(form.vat_number, expected.vat_number, { allowBlankExpected: true }), current: form.vat_number || "Blank", expected: expected.vat_number || "Blank allowed" },
      { label: "Company / taxpayer name", status: compareText(form.tax_payer_name, expected.tax_payer_name), current: form.tax_payer_name || "—", expected: expected.tax_payer_name || "—" },
      { label: "Trade name", status: compareText(form.trade_name, expected.trade_name), current: form.trade_name || "—", expected: expected.trade_name || "—" },
      { label: "Device ID", status: compareText(form.device_id, expected.device_id), current: form.device_id || "—", expected: expected.device_id || "—" },
      { label: "Activation key presence", status: expected.has_activation_key === null ? "not_checked" as const : Boolean(config?.has_activation_key) === expected.has_activation_key ? "match" as const : "mismatch" as const, current: config?.has_activation_key ? "Saved" : "Not saved", expected: expected.has_activation_key === null ? "—" : expected.has_activation_key ? "Should be saved" : "Should be absent" },
      { label: "Device address", status: compareText(config?.device_address, expected.device_address), current: config?.device_address || "Not saved in fiscal settings", expected: expected.device_address || "—" },
      { label: "Device model name", status: compareText(form.device_model, expected.device_model), current: form.device_model || "—", expected: expected.device_model || "—" },
      { label: "Device model version", status: compareText(config?.device_model_version, expected.device_model_version), current: config?.device_model_version || "Not saved in fiscal settings", expected: expected.device_model_version || "—" },
    ];
    return rows.filter((row) => row.status !== "not_checked");
  }, [config, expected, form]);

  const hasExpectedValues = isExpectedProvided(expected);

  function importExpectedDetails() {
    try {
      const parsed = JSON.parse(expectedImport) as Partial<ValidationExpected> & {
        tin?: string;
        vatNumber?: string | null;
        taxpayerName?: string;
        companyName?: string;
        tradeName?: string;
        deviceId?: string;
        activationKeyPresent?: boolean;
        deviceAddress?: string;
        deviceModelName?: string;
        deviceModelVersion?: string;
      };
      setExpected({
        tax_payer_tin: String(parsed.tax_payer_tin ?? parsed.tin ?? ""),
        vat_number: String(parsed.vat_number ?? parsed.vatNumber ?? ""),
        tax_payer_name: String(parsed.tax_payer_name ?? parsed.taxpayerName ?? parsed.companyName ?? ""),
        trade_name: String(parsed.trade_name ?? parsed.tradeName ?? ""),
        device_id: String(parsed.device_id ?? parsed.deviceId ?? ""),
        has_activation_key: typeof parsed.has_activation_key === "boolean" ? parsed.has_activation_key : typeof parsed.activationKeyPresent === "boolean" ? parsed.activationKeyPresent : null,
        device_address: String(parsed.device_address ?? parsed.deviceAddress ?? ""),
        device_model: String(parsed.device_model ?? parsed.deviceModelName ?? ""),
        device_model_version: String(parsed.device_model_version ?? parsed.deviceModelVersion ?? ""),
      });
      toast.success("Activation details imported for this checklist");
    } catch {
      toast.error("Paste valid JSON activation details to import");
    }
  }

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

        <div className="mt-6 rounded-lg border border-hairline p-4 space-y-4">
          <div>
            <h3 className="text-sm font-medium">Activation details checklist</h3>
            <p className="text-xs text-muted-foreground mt-1">
              Optional per-organization helper. Enter or import expected activation details to compare them with the saved settings above.
              Secret values are not shown; activation key validation checks saved/absent status only.
            </p>
          </div>
          <div className="grid gap-3 sm:grid-cols-2">
            <div><Label>Expected TIN</Label><Input value={expected.tax_payer_tin} onChange={(e) => setExpected((v) => ({ ...v, tax_payer_tin: e.target.value }))} /></div>
            <div><Label>Expected VAT number (blank allowed)</Label><Input value={expected.vat_number} onChange={(e) => setExpected((v) => ({ ...v, vat_number: e.target.value }))} /></div>
            <div><Label>Expected company / taxpayer name</Label><Input value={expected.tax_payer_name} onChange={(e) => setExpected((v) => ({ ...v, tax_payer_name: e.target.value }))} /></div>
            <div><Label>Expected trade name</Label><Input value={expected.trade_name} onChange={(e) => setExpected((v) => ({ ...v, trade_name: e.target.value }))} /></div>
            <div><Label>Expected device ID</Label><Input value={expected.device_id} onChange={(e) => setExpected((v) => ({ ...v, device_id: e.target.value }))} /></div>
            <div><Label>Expected activation key state</Label><select value={expected.has_activation_key === null ? "" : expected.has_activation_key ? "saved" : "absent"} onChange={(e) => setExpected((v) => ({ ...v, has_activation_key: e.target.value === "" ? null : e.target.value === "saved" }))} className="mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"><option value="">Do not check</option><option value="saved">Should be saved</option><option value="absent">Should be absent</option></select></div>
            <div><Label>Expected device address</Label><Input value={expected.device_address} onChange={(e) => setExpected((v) => ({ ...v, device_address: e.target.value }))} /></div>
            <div><Label>Expected device model name</Label><Input value={expected.device_model} onChange={(e) => setExpected((v) => ({ ...v, device_model: e.target.value }))} /></div>
            <div><Label>Expected device model version</Label><Input value={expected.device_model_version} onChange={(e) => setExpected((v) => ({ ...v, device_model_version: e.target.value }))} /></div>
          </div>
          <div>
            <Label>Import expected details (JSON)</Label>
            <Textarea rows={3} value={expectedImport} onChange={(e) => setExpectedImport(e.target.value)} placeholder={'{"tin":"...","vatNumber":null,"deviceId":"...","activationKeyPresent":true}'} />
            <div className="mt-2 flex gap-2"><Button type="button" variant="outline" onClick={importExpectedDetails}>Import checklist values</Button><Button type="button" variant="ghost" onClick={() => setExpected(emptyExpected)}>Clear checklist</Button></div>
          </div>
          <div className="rounded-md border border-hairline overflow-hidden">
            {hasExpectedValues ? (
              <table className="w-full text-sm"><thead className="bg-muted/40 text-xs uppercase tracking-wider text-muted-foreground"><tr><th className="text-left p-3">Check</th><th className="text-left p-3">Status</th><th className="text-left p-3">Saved</th><th className="text-left p-3">Expected</th></tr></thead><tbody>{validationRows.map((row) => (<tr key={row.label} className="border-t border-hairline"><td className="p-3">{row.label}</td><td className={`p-3 font-medium ${statusClass(row.status)}`}>{statusLabel(row.status)}</td><td className="p-3">{row.current}</td><td className="p-3">{row.expected}</td></tr>))}</tbody></table>
            ) : (
              <div className="p-3 text-sm text-muted-foreground">Enter expected activation details to run the checklist. No global defaults are applied.</div>
            )}
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
