import { createFileRoute } from "@tanstack/react-router";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import {
  authenticateApiRequest,
  errorResponse,
  jsonResponse,
  optionsResponse,
} from "@/lib/apiAuth.server";

export const Route = createFileRoute("/api/public/v1/organization")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        const { data, error } = await supabaseAdmin
          .from("organization_profiles")
          .select("org_id, name, short_name, address, phone, emails, website, currency, default_tax_rate, tin, praz, duns, registration, logo_url")
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Organization not found");
        return jsonResponse({ data });
      },
    },
  },
});
