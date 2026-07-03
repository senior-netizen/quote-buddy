import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import {
  authenticateApiRequest,
  errorResponse,
  jsonResponse,
  optionsResponse,
} from "@/lib/apiAuth.server";

const clientPatch = z.object({
  company_name: z.string().min(1).max(200).optional(),
  email: z.string().email().max(200).nullable().optional(),
  phone: z.string().max(50).nullable().optional(),
  address: z.string().max(500).nullable().optional(),
});

export const Route = createFileRoute("/api/public/v1/clients/$id")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { data, error } = await supabaseAdmin
          .from("clients")
          .select("id, company_name, email, phone, address, created_at, updated_at")
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Client not found");
        return jsonResponse({ data });
      },
      PATCH: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        let body: unknown;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = clientPatch.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        const { data, error } = await supabaseAdmin
          .from("clients")
          .update(parsed.data)
          .eq("id", params.id)
          .eq("org_id", auth.orgId)
          .select("id, company_name, email, phone, address, created_at, updated_at")
          .maybeSingle();
        if (error) return errorResponse(500, error.message);
        if (!data) return errorResponse(404, "Client not found");
        return jsonResponse({ data });
      },
      DELETE: async ({ request, params }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message);
        const { error, count } = await supabaseAdmin
          .from("clients")
          .delete({ count: "exact" })
          .eq("id", params.id)
          .eq("org_id", auth.orgId);
        if (error) return errorResponse(500, error.message);
        if (!count) return errorResponse(404, "Client not found");
        return jsonResponse({ deleted: true });
      },
    },
  },
});
