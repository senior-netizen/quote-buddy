import { a as createMiddleware, s as supabase } from "./client-D9HpxjJv.mjs";
function dedupeSerializationAdapters(deduped, serializationAdapters) {
  for (let i = 0, len = serializationAdapters.length; i < len; i++) {
    const current = serializationAdapters[i];
    if (!deduped.has(current)) {
      deduped.add(current);
      if (current.extends) dedupeSerializationAdapters(deduped, current.extends);
    }
  }
}
var createStart = (getOptions) => {
  return {
    getOptions: async () => {
      const options = await getOptions();
      if (options.serializationAdapters) {
        const deduped = /* @__PURE__ */ new Set();
        dedupeSerializationAdapters(deduped, options.serializationAdapters);
        options.serializationAdapters = Array.from(deduped);
      }
      return options;
    },
    createMiddleware
  };
};
const attachSupabaseAuth = createMiddleware({ type: "function" }).client(
  async ({ next }) => {
    const { data } = await supabase.auth.getSession();
    const token = data.session?.access_token;
    return next({
      headers: token ? { Authorization: `Bearer ${token}` } : {}
    });
  }
);
let fdmsProvisioningStarted = false;
function startFdmsTestCertificateProvisioning() {
  if (fdmsProvisioningStarted || false || typeof process === "undefined" || !process.versions?.node || process.env.FDMS_ENV !== "test") {
    return;
  }
  fdmsProvisioningStarted = true;
  void import(
    /* @vite-ignore */
    "./CertificateManager-D7MuI3jH.mjs"
  ).then(
    ({ CertificateManager }) => new CertificateManager().provisionTestCertificate().catch((error) => {
      console.error("[fdms-cert] Startup certificate provisioning failed.", {
        message: error instanceof Error ? error.message : "Unknown error"
      });
    })
  ).catch((error) => {
    console.error("[fdms-cert] Startup certificate provisioning failed.", {
      message: error instanceof Error ? error.message : "Unknown error"
    });
  });
}
startFdmsTestCertificateProvisioning();
const startInstance = createStart(() => ({
  functionMiddleware: [attachSupabaseAuth]
}));
export {
  startInstance
};
