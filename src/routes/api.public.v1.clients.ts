import { createFileRoute } from "@tanstack/react-router";
import { z } from "zod";
import { supabaseAdmin } from "@/integrations/supabase/client.server";
import {
  authenticateApiRequest,
  errorResponse,
  jsonResponse,
  optionsResponse,
} from "@/lib/apiAuth.server";

const clientInput = z.object({
  company_name: z.string().min(1).max(200),
  email: z.string().email().max(200).nullable().optional(),
  phone: z.string().max(50).nullable().optional(),
  address: z.string().max(500).nullable().optional(),
});

export const Route = createFileRoute("/api/public/v1/clients")({
  server: {
    handlers: {
      OPTIONS: async () => optionsResponse(),
      GET: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        const url = new URL(request.url);
        const limit = Math.min(Number(url.searchParams.get("limit") ?? 50) || 50, 200);
        const offset = Math.max(Number(url.searchParams.get("offset") ?? 0) || 0, 0);
        const { data, error } = await supabaseAdmin
          .from("clients")
          .select("id, company_name, email, phone, address, created_at, updated_at")
          .eq("org_id", auth.orgId)
          .order("created_at", { ascending: false })
          .range(offset, offset + limit - 1);
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data, limit, offset });
      },
      POST: async ({ request }) => {
        const auth = await authenticateApiRequest(request);
        if (!auth.ok) return errorResponse(auth.status, auth.message, auth.code);
        let body: unknown;
        try {
          body = await request.json();
        } catch {
          return errorResponse(400, "Invalid JSON body");
        }
        const parsed = clientInput.safeParse(body);
        if (!parsed.success) return errorResponse(400, parsed.error.message);
        // Need a user_id for the NOT NULL column; use the org creator as system owner.
        const { data: org } = await supabaseAdmin
          .from("organizations")
          .select("created_by")
          .eq("id", auth.orgId)
          .maybeSingle();
        const userId = org?.created_by;
        if (!userId) return errorResponse(500, "Organization has no owner");
        const { data, error } = await supabaseAdmin
          .from("clients")
          .insert({
            org_id: auth.orgId,
            user_id: userId,
            company_name: parsed.data.company_name,
            email: parsed.data.email ?? null,
            phone: parsed.data.phone ?? null,
            address: parsed.data.address ?? null,
          })
          .select("id, company_name, email, phone, address, created_at, updated_at")
          .single();
        if (error) return errorResponse(500, error.message);
        return jsonResponse({ data }, { status: 201 });
      },
    },
  },
});
