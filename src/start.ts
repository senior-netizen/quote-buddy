import { createStart } from "@tanstack/react-start";
import { attachSupabaseAuth } from "@/integrations/supabase/auth-attacher";

let fdmsProvisioningStarted = false;

function startFdmsTestCertificateProvisioning() {
  if (
    fdmsProvisioningStarted ||
    typeof process === "undefined" ||
    !process.versions?.node ||
    process.env.FDMS_ENV !== "test"
  ) {
    return;
  }
  fdmsProvisioningStarted = true;
  void import("@/lib/fiscal/CertificateManager")
    .then(({ CertificateManager }) =>
      new CertificateManager().provisionTestCertificate().catch((error) => {
        console.error("[fdms-cert] Startup certificate provisioning failed.", {
          message: error instanceof Error ? error.message : "Unknown error",
        });
      }),
    )
    .catch((error) => {
      console.error("[fdms-cert] Startup certificate provisioning failed.", {
        message: error instanceof Error ? error.message : "Unknown error",
      });
    });
}

startFdmsTestCertificateProvisioning();

export const startInstance = createStart(() => ({
  functionMiddleware: [attachSupabaseAuth],
}));
