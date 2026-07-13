import { r as reactExports, j as jsxRuntimeExports } from "../_libs/react.mjs";
import { u as useRouter } from "../_libs/tanstack__react-router.mjs";
import { h as useServerFn, L as Label, I as Input, T as Textarea, B as Button, o as cn } from "./router-BDMLDL80.mjs";
import { u as useQuery, a as useMutation } from "../_libs/tanstack__react-query.mjs";
import { t as toast } from "../_libs/sonner.mjs";
import { R as Root, T as Thumb } from "../_libs/radix-ui__react-switch.mjs";
import { o as onboardFiscalDeviceSecrets, u as updateFiscalConfig, t as testDeviceConnection, c as closeFiscalDay, a as openFiscalDay, g as getFiscalConfig, l as listFiscalDays, b as getCurrentFiscalDay } from "./fiscal.functions-CwD_knTK.mjs";
import "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/qrcode.mjs";
import "../_libs/tanstack__router-core.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "node:stream";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "../_libs/isbot.mjs";
import "../_libs/tanstack__query-core.mjs";
import "./client-U3FzjMwq.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "../_libs/radix-ui__react-slot.mjs";
import "../_libs/radix-ui__react-compose-refs.mjs";
import "../_libs/class-variance-authority.mjs";
import "../_libs/clsx.mjs";
import "../_libs/tailwind-merge.mjs";
import "../_libs/radix-ui__react-label.mjs";
import "../_libs/radix-ui__react-primitive.mjs";
import "../_libs/radix-ui__react-dialog.mjs";
import "../_libs/radix-ui__primitive.mjs";
import "../_libs/radix-ui__react-context.mjs";
import "../_libs/radix-ui__react-id.mjs";
import "../_libs/@radix-ui/react-use-layout-effect+[...].mjs";
import "../_libs/@radix-ui/react-use-controllable-state+[...].mjs";
import "../_libs/@radix-ui/react-dismissable-layer+[...].mjs";
import "../_libs/@radix-ui/react-use-callback-ref+[...].mjs";
import "../_libs/@radix-ui/react-use-escape-keydown+[...].mjs";
import "../_libs/radix-ui__react-focus-scope.mjs";
import "../_libs/radix-ui__react-portal.mjs";
import "../_libs/radix-ui__react-presence.mjs";
import "../_libs/radix-ui__react-focus-guards.mjs";
import "../_libs/react-remove-scroll.mjs";
import "../_libs/react-remove-scroll-bar.mjs";
import "../_libs/react-style-singleton.mjs";
import "../_libs/get-nonce.mjs";
import "../_libs/use-sidecar.mjs";
import "../_libs/use-callback-ref.mjs";
import "../_libs/aria-hidden.mjs";
import "./auth-middleware-DJP7Badx.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "./client.server-BMj2q4-x.mjs";
import "./calc-BF6zAv6d.mjs";
import "./docTypes-CsATll0j.mjs";
import "../_libs/zod.mjs";
import "./verifySign.server-CnraXCan.mjs";
import "../_libs/lucide-react.mjs";
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "../_libs/dijkstrajs.mjs";
import "fs";
import "../_libs/pngjs.mjs";
import "zlib";
import "assert";
import "buffer";
import "../_libs/radix-ui__react-use-previous.mjs";
import "../_libs/radix-ui__react-use-size.mjs";
const Switch = reactExports.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ jsxRuntimeExports.jsx(
  Root,
  {
    className: cn(
      "peer inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50 data-[state=checked]:bg-primary data-[state=unchecked]:bg-input",
      className
    ),
    ...props,
    ref,
    children: /* @__PURE__ */ jsxRuntimeExports.jsx(
      Thumb,
      {
        className: cn(
          "pointer-events-none block h-4 w-4 rounded-full bg-background shadow-lg ring-0 transition-transform data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0"
        )
      }
    )
  }
));
Switch.displayName = Root.displayName;
const emptyExpected = {
  tax_payer_tin: "",
  vat_number: "",
  tax_payer_name: "",
  trade_name: "",
  device_id: "",
  has_activation_key: null,
  device_address: "",
  device_model: "",
  device_model_version: ""
};
function normalizeComparable(value) {
  return (value ?? "").trim().replace(/\s+/g, " ").toLowerCase();
}
function isExpectedProvided(expected) {
  return Object.entries(expected).some(([key, value]) => key === "has_activation_key" ? value !== null : Boolean(value.trim()));
}
function compareText(current, expected, options) {
  const expectedNormalized = normalizeComparable(expected);
  if (!expectedNormalized && !options?.allowBlankExpected) return "not_checked";
  return normalizeComparable(current) === expectedNormalized ? "match" : "mismatch";
}
function statusClass(status) {
  if (status === "match") return "text-emerald-600";
  if (status === "mismatch") return "text-destructive";
  return "text-muted-foreground";
}
function statusLabel(status) {
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
  const {
    data: config,
    refetch: refetchConfig
  } = useQuery({
    queryKey: ["fiscal-config"],
    queryFn: () => getConfig()
  });
  const {
    data: currDay,
    refetch: refetchCurrDay
  } = useQuery({
    queryKey: ["fiscal-current-day"],
    queryFn: () => currentDay()
  });
  const {
    data: days,
    refetch: refetchDays
  } = useQuery({
    queryKey: ["fiscal-days"],
    queryFn: () => listDays()
  });
  const [expected, setExpected] = reactExports.useState(emptyExpected);
  const [expectedImport, setExpectedImport] = reactExports.useState("");
  const [form, setForm] = reactExports.useState({
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
    private_key_pem: ""
  });
  reactExports.useEffect(() => {
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
      private_key_pem: ""
    }));
  }, [config]);
  const save = useMutation({
    mutationFn: async () => {
      const {
        activation_key,
        certificate_pem,
        private_key_pem,
        ...configPayload
      } = form;
      if (activation_key || certificate_pem || private_key_pem) {
        await onboardSecrets({
          data: {
            ...activation_key ? {
              activation_key
            } : {},
            ...certificate_pem ? {
              certificate_pem
            } : {},
            ...private_key_pem ? {
              private_key_pem
            } : {}
          }
        });
      }
      return updateConfig({
        data: configPayload
      });
    },
    onSuccess: () => {
      toast.success("Fiscal settings saved");
      refetchConfig();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Save failed")
  });
  const test = useMutation({
    mutationFn: () => testConn(),
    onSuccess: (r) => r.ok ? toast.success(r.message) : toast.error(r.message),
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed")
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
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed")
  });
  const close = useMutation({
    mutationFn: () => closeDay(),
    onSuccess: () => {
      toast.success("Fiscal day closed");
      refetchCurrDay();
      refetchDays();
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : "Failed")
  });
  const validationRows = reactExports.useMemo(() => {
    const rows = [{
      label: "TIN",
      status: compareText(form.tax_payer_tin, expected.tax_payer_tin),
      current: form.tax_payer_tin || "—",
      expected: expected.tax_payer_tin || "—"
    }, {
      label: "VAT number",
      status: compareText(form.vat_number, expected.vat_number, {
        allowBlankExpected: true
      }),
      current: form.vat_number || "Blank",
      expected: expected.vat_number || "Blank allowed"
    }, {
      label: "Company / taxpayer name",
      status: compareText(form.tax_payer_name, expected.tax_payer_name),
      current: form.tax_payer_name || "—",
      expected: expected.tax_payer_name || "—"
    }, {
      label: "Trade name",
      status: compareText(form.trade_name, expected.trade_name),
      current: form.trade_name || "—",
      expected: expected.trade_name || "—"
    }, {
      label: "Device ID",
      status: compareText(form.device_id, expected.device_id),
      current: form.device_id || "—",
      expected: expected.device_id || "—"
    }, {
      label: "Activation key presence",
      status: expected.has_activation_key === null ? "not_checked" : Boolean(config?.has_activation_key) === expected.has_activation_key ? "match" : "mismatch",
      current: config?.has_activation_key ? "Saved" : "Not saved",
      expected: expected.has_activation_key === null ? "—" : expected.has_activation_key ? "Should be saved" : "Should be absent"
    }, {
      label: "Device address",
      status: compareText(config?.device_address, expected.device_address),
      current: config?.device_address || "Not saved in fiscal settings",
      expected: expected.device_address || "—"
    }, {
      label: "Device model name",
      status: compareText(form.device_model_name, expected.device_model),
      current: form.device_model_name || "—",
      expected: expected.device_model || "—"
    }, {
      label: "Device model version",
      status: compareText(form.device_model_version, expected.device_model_version),
      current: form.device_model_version || "Not saved in fiscal settings",
      expected: expected.device_model_version || "—"
    }];
    return rows.filter((row) => row.status !== "not_checked");
  }, [config, expected, form]);
  const hasExpectedValues = isExpectedProvided(expected);
  function importExpectedDetails() {
    try {
      const parsed = JSON.parse(expectedImport);
      setExpected({
        tax_payer_tin: String(parsed.tax_payer_tin ?? parsed.tin ?? ""),
        vat_number: String(parsed.vat_number ?? parsed.vatNumber ?? ""),
        tax_payer_name: String(parsed.tax_payer_name ?? parsed.taxpayerName ?? parsed.companyName ?? ""),
        trade_name: String(parsed.trade_name ?? parsed.tradeName ?? ""),
        device_id: String(parsed.device_id ?? parsed.deviceId ?? ""),
        has_activation_key: typeof parsed.has_activation_key === "boolean" ? parsed.has_activation_key : typeof parsed.activationKeyPresent === "boolean" ? parsed.activationKeyPresent : null,
        device_address: String(parsed.device_address ?? parsed.deviceAddress ?? ""),
        device_model: String(parsed.device_model ?? parsed.deviceModelName ?? ""),
        device_model_version: String(parsed.device_model_version ?? parsed.deviceModelVersion ?? "")
      });
      toast.success("Activation details imported for this checklist");
    } catch {
      toast.error("Paste valid JSON activation details to import");
    }
  }
  return /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "space-y-10 max-w-3xl", children: [
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-lg font-medium", children: "ZIMRA Fiscalisation" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-sm text-muted-foreground mt-1", children: "Register your device with the Zimbabwe Revenue Authority's FDMS to submit invoices as fiscal receipts." })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center gap-2", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Switch, { id: "enabled", checked: form.enabled, onCheckedChange: (v) => setForm((f) => ({
            ...f,
            enabled: v
          })) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { htmlFor: "enabled", children: "Enabled" })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 grid gap-4 sm:grid-cols-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Environment" }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("select", { value: form.environment, onChange: (e) => setForm((f) => ({
            ...f,
            environment: e.target.value
          })), className: "mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("option", { value: "test", children: "Sandbox (fdmsapitest.zimra.co.zw)" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("option", { value: "prod", children: "Production (fdmsapi.zimra.co.zw)" })
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Device ID" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.device_id, onChange: (e) => setForm((f) => ({
            ...f,
            device_id: e.target.value
          })) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Device Serial Number" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.device_serial, onChange: (e) => setForm((f) => ({
            ...f,
            device_serial: e.target.value
          })) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Device Model" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.device_model_name, onChange: (e) => setForm((f) => ({
            ...f,
            device_model_name: e.target.value
          })) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "sm:col-span-2", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Activation Key" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { type: "password", value: form.activation_key, onChange: (e) => setForm((f) => ({
            ...f,
            activation_key: e.target.value
          })) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Taxpayer name" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.tax_payer_name, onChange: (e) => setForm((f) => ({
            ...f,
            tax_payer_name: e.target.value
          })) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-xs text-muted-foreground mt-1", children: "Enter this exactly as shown as the ZIMRA Company Name on the activation record." })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Trade name" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.trade_name, onChange: (e) => setForm((f) => ({
            ...f,
            trade_name: e.target.value
          })) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-xs text-muted-foreground mt-1", children: "Enter this exactly as shown as the ZIMRA Trade Name on the activation record, even if it differs from the company name." })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "TIN" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.tax_payer_tin, onChange: (e) => setForm((f) => ({
            ...f,
            tax_payer_tin: e.target.value
          })) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "VAT number" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: form.vat_number, onChange: (e) => setForm((f) => ({
            ...f,
            vat_number: e.target.value
          })) })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 rounded-lg border border-hairline p-4 space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("h3", { className: "text-sm font-medium", children: "Activation details checklist" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-xs text-muted-foreground mt-1", children: "Optional per-organization helper. Enter or import expected activation details to compare them with the saved settings above. Secret values are not shown; activation key validation checks saved/absent status only." })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "grid gap-3 sm:grid-cols-2", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected TIN" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.tax_payer_tin, onChange: (e) => setExpected((v) => ({
              ...v,
              tax_payer_tin: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected VAT number (blank allowed)" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.vat_number, onChange: (e) => setExpected((v) => ({
              ...v,
              vat_number: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected company / taxpayer name" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.tax_payer_name, onChange: (e) => setExpected((v) => ({
              ...v,
              tax_payer_name: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected trade name" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.trade_name, onChange: (e) => setExpected((v) => ({
              ...v,
              trade_name: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected device ID" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.device_id, onChange: (e) => setExpected((v) => ({
              ...v,
              device_id: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected activation key state" }),
            /* @__PURE__ */ jsxRuntimeExports.jsxs("select", { value: expected.has_activation_key === null ? "" : expected.has_activation_key ? "saved" : "absent", onChange: (e) => setExpected((v) => ({
              ...v,
              has_activation_key: e.target.value === "" ? null : e.target.value === "saved"
            })), className: "mt-1 w-full rounded-md border border-input bg-background px-3 py-2 text-sm", children: [
              /* @__PURE__ */ jsxRuntimeExports.jsx("option", { value: "", children: "Do not check" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("option", { value: "saved", children: "Should be saved" }),
              /* @__PURE__ */ jsxRuntimeExports.jsx("option", { value: "absent", children: "Should be absent" })
            ] })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected device address" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.device_address, onChange: (e) => setExpected((v) => ({
              ...v,
              device_address: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected device model name" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.device_model, onChange: (e) => setExpected((v) => ({
              ...v,
              device_model: e.target.value
            })) })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Expected device model version" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Input, { value: expected.device_model_version, onChange: (e) => setExpected((v) => ({
              ...v,
              device_model_version: e.target.value
            })) })
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Import expected details (JSON)" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 3, value: expectedImport, onChange: (e) => setExpectedImport(e.target.value), placeholder: '{"tin":"...","vatNumber":null,"deviceId":"...","activationKeyPresent":true}' }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-2 flex gap-2", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { type: "button", variant: "outline", onClick: importExpectedDetails, children: "Import checklist values" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { type: "button", variant: "ghost", onClick: () => setExpected(emptyExpected), children: "Clear checklist" })
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "rounded-md border border-hairline overflow-hidden", children: hasExpectedValues ? /* @__PURE__ */ jsxRuntimeExports.jsxs("table", { className: "w-full text-sm", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("thead", { className: "bg-muted/40 text-xs uppercase tracking-wider text-muted-foreground", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Check" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Status" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Saved" }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Expected" })
          ] }) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("tbody", { children: validationRows.map((row) => /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "border-t border-hairline", children: [
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "p-3", children: row.label }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: `p-3 font-medium ${statusClass(row.status)}`, children: statusLabel(row.status) }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "p-3", children: row.current }),
            /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "p-3", children: row.expected })
          ] }, row.label)) })
        ] }) : /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "p-3 text-sm text-muted-foreground", children: "Enter expected activation details to run the checklist. No global defaults are applied." }) })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 space-y-4", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Device certificate (PEM)" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 5, placeholder: config?.has_certificate ? "•••••••••• (saved — paste a new one to replace)" : "-----BEGIN CERTIFICATE-----", value: form.certificate_pem, onChange: (e) => setForm((f) => ({
            ...f,
            certificate_pem: e.target.value
          })) })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx(Label, { children: "Device private key (PEM)" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx(Textarea, { rows: 5, placeholder: config?.has_private_key ? "•••••••••• (saved — paste a new one to replace)" : "-----BEGIN PRIVATE KEY-----", value: form.private_key_pem, onChange: (e) => setForm((f) => ({
            ...f,
            private_key_pem: e.target.value
          })) }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-xs text-muted-foreground mt-1", children: "Stored encrypted at rest. Used for the mTLS handshake against FDMS." })
        ] })
      ] }),
      /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "mt-6 flex gap-2", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => save.mutate(), disabled: save.isPending, children: save.isPending ? "Saving…" : "Save settings" }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "outline", onClick: () => test.mutate(), disabled: test.isPending || !config?.enabled, children: test.isPending ? "Testing…" : "Test connection" })
      ] })
    ] }),
    /* @__PURE__ */ jsxRuntimeExports.jsxs("section", { children: [
      /* @__PURE__ */ jsxRuntimeExports.jsx("h2", { className: "text-lg font-medium", children: "Fiscal Day" }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("p", { className: "text-sm text-muted-foreground mt-1", children: "A fiscal day must be open before invoices can be submitted to FDMS." }),
      /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-4 rounded-lg border border-hairline p-4", children: currDay ? /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between gap-3", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "text-sm", children: [
            "Day ",
            /* @__PURE__ */ jsxRuntimeExports.jsxs("span", { className: "font-mono", children: [
              "#",
              currDay.fiscal_day_no
            ] }),
            " is",
            " ",
            /* @__PURE__ */ jsxRuntimeExports.jsx("span", { className: "font-medium", children: "OPEN" })
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "text-xs text-muted-foreground", children: [
            "Opened ",
            new Date(currDay.opened_at).toLocaleString()
          ] })
        ] }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { variant: "outline", onClick: () => close.mutate(), disabled: close.isPending, children: close.isPending ? "Closing…" : "Close day" })
      ] }) : /* @__PURE__ */ jsxRuntimeExports.jsxs("div", { className: "flex items-center justify-between gap-3", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "text-sm text-muted-foreground", children: "No open fiscal day." }),
        /* @__PURE__ */ jsxRuntimeExports.jsx(Button, { onClick: () => open.mutate(), disabled: open.isPending || !config?.enabled, children: open.isPending ? "Opening…" : "Open day" })
      ] }) }),
      days && days.length > 0 && /* @__PURE__ */ jsxRuntimeExports.jsx("div", { className: "mt-4 rounded-lg border border-hairline overflow-hidden", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("table", { className: "w-full text-sm", children: [
        /* @__PURE__ */ jsxRuntimeExports.jsx("thead", { className: "bg-muted/40 text-xs uppercase tracking-wider text-muted-foreground", children: /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { children: [
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Day" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Opened" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Closed" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("th", { className: "text-left p-3", children: "Status" })
        ] }) }),
        /* @__PURE__ */ jsxRuntimeExports.jsx("tbody", { children: days.map((d) => /* @__PURE__ */ jsxRuntimeExports.jsxs("tr", { className: "border-t border-hairline", children: [
          /* @__PURE__ */ jsxRuntimeExports.jsxs("td", { className: "p-3 font-mono", children: [
            "#",
            d.fiscal_day_no
          ] }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "p-3", children: new Date(d.opened_at).toLocaleString() }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "p-3", children: d.closed_at ? new Date(d.closed_at).toLocaleString() : "—" }),
          /* @__PURE__ */ jsxRuntimeExports.jsx("td", { className: "p-3 uppercase text-xs", children: d.status })
        ] }, d.id)) })
      ] }) })
    ] })
  ] });
}
export {
  FiscalSettings as component
};
