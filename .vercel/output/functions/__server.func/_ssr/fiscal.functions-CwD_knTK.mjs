import { w as createSsrRpc } from "./router-BDMLDL80.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { c as createServerFn } from "./index.mjs";
import { o as object, s as string, _ as _enum, b as boolean } from "../_libs/zod.mjs";
const getFiscalConfig = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("21c9ee1831c97b4f9b584fa79f48a4f00c4d074733709bd4563c6771b1737191"));
const updateSchema = object({
  enabled: boolean().optional(),
  environment: _enum(["test", "prod"]).optional(),
  device_id: string().nullable().optional(),
  device_serial: string().nullable().optional(),
  device_address: string().nullable().optional(),
  device_model: string().nullable().optional(),
  device_model_name: string().nullable().optional(),
  device_model_version: string().nullable().optional(),
  activation_key_secret_ref: string().nullable().optional(),
  tax_payer_name: string().nullable().optional(),
  tax_payer_tin: string().nullable().optional(),
  vat_number: string().nullable().optional(),
  trade_name: string().nullable().optional(),
  certificate_secret_ref: string().nullable().optional(),
  private_key_secret_ref: string().nullable().optional(),
  device_operating_mode: string().optional()
}).strict();
const updateFiscalConfig = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => updateSchema.parse(data)).handler(createSsrRpc("ae82a81d5d9218ce267825c9c94ebf3e394b99dcf6384a46776ad985c5f8f043"));
const secureOnboardingSchema = object({
  activation_key: string().min(1).optional(),
  certificate_pem: string().min(1).optional(),
  private_key_pem: string().min(1).optional(),
  key_id: string().min(1).default("server-managed"),
  valid_from: string().datetime().nullable().optional(),
  valid_until: string().datetime().nullable().optional()
}).strict();
const onboardFiscalDeviceSecrets = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => secureOnboardingSchema.parse(data)).handler(createSsrRpc("38a97d9c9d765dc240e136351e6fd81fcabf21702dc80ed69b3880ef8424ce6f"));
const testDeviceConnection = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("c276c80f7dd2c23a283c99a9de94889fe3c329369162f7e1ad23fba93ec1fc5e"));
const openFiscalDay = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("96108773d83181d2a0248149fecb5d6176770cc4ba97e7b6c019d4747c9ea510"));
const closeFiscalDay = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("193fc5971a8908606af82fcef861697128c26abaf78286d771fcf90cb9327770"));
const listFiscalDays = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("b73683f3df0dbdedf64cccb0f889ee0840b5683df33bbd67f4e60b523aa55a00"));
const submitInvoiceToZimra = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((data) => object({
  documentId: string().uuid()
}).parse(data)).handler(createSsrRpc("ccfaa7b3e8430b8438e213dfaf47a4ba9469d265ffde5307bb6dfe41ac9d2a6c"));
const getCurrentFiscalDay = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(createSsrRpc("8071501d4737b90b81697bc956d93debcb5ebaaa4a88a9cab55afea92c40ee50"));
export {
  openFiscalDay as a,
  getCurrentFiscalDay as b,
  closeFiscalDay as c,
  getFiscalConfig as g,
  listFiscalDays as l,
  onboardFiscalDeviceSecrets as o,
  submitInvoiceToZimra as s,
  testDeviceConnection as t,
  updateFiscalConfig as u
};
