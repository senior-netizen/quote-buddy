import {
  isSupabaseServerConfigError,
  SERVER_CONFIG_MISSING_CODE,
  supabaseAdmin,
} from "@/integrations/supabase/client.server";

const KEY_PREFIX = "qsk_live_";

async function sha256Hex(input: string): Promise<string> {
  const buf = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Generate a new API key. Returns { key, prefix, hash }. Only `key` is ever returned to the user. */
export async function generateApiKey(): Promise<{ key: string; prefix: string; hash: string }> {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const secret = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  const key = `${KEY_PREFIX}${secret}`;
  const hash = await sha256Hex(key);
  const prefix = key.slice(0, KEY_PREFIX.length + 6);
  return { key, prefix, hash };
}

export async function hashApiKey(key: string): Promise<string> {
  return sha256Hex(key);
}

export type ApiAuthResult =
  | { ok: true; orgId: string; keyId: string }
  | { ok: false; status: number; message: string; code?: string };

/** Validate a Bearer API key. Returns the org_id it authorizes. */
export async function authenticateApiRequest(request: Request): Promise<ApiAuthResult> {
  const h = request.headers.get("authorization");
  if (!h || !h.toLowerCase().startsWith("bearer ")) {
    return { ok: false, status: 401, message: "Missing bearer token" };
  }
  const token = h.slice(7).trim();
  if (!token.startsWith(KEY_PREFIX)) {
    return { ok: false, status: 401, message: "Invalid API key format" };
  }
  const hash = await sha256Hex(token);
  try {
    const { data, error } = await supabaseAdmin
      .from("api_keys")
      .select("id, org_id, revoked_at")
      .eq("key_hash", hash)
      .maybeSingle();
    if (error || !data) return { ok: false, status: 401, message: "Invalid API key" };
    if (data.revoked_at) return { ok: false, status: 401, message: "API key revoked" };
    // fire-and-forget last-used update
    supabaseAdmin
      .from("api_keys")
      .update({ last_used_at: new Date().toISOString() })
      .eq("id", data.id)
      .then(() => {})
      .catch((error) => {
        console.error("Failed to update API key last_used_at", {
          message: error instanceof Error ? error.message : String(error),
        });
      });
    return { ok: true, orgId: data.org_id, keyId: data.id };
  } catch (error) {
    if (isSupabaseServerConfigError(error)) {
      console.error("API service unavailable due to missing Supabase configuration", {
        missingVariables: error.missingVariables,
      });
      return {
        ok: false,
        status: 500,
        message: "API service is temporarily unavailable",
        code: SERVER_CONFIG_MISSING_CODE,
      };
    }

    console.error("API authentication failed unexpectedly", {
      message: error instanceof Error ? error.message : String(error),
    });
    return { ok: false, status: 500, message: "API authentication is temporarily unavailable" };
  }
}

export function jsonResponse(body: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "content-type": "application/json",
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type",
      "access-control-allow-methods": "GET, POST, PATCH, DELETE, OPTIONS",
      ...(init.headers ?? {}),
    },
  });
}

export function errorResponse(status: number, message: string, code?: string) {
  if (code === SERVER_CONFIG_MISSING_CODE) {
    return jsonResponse({ error: { code } }, { status });
  }

  return jsonResponse({ error: { status, message, ...(code ? { code } : {}) } }, { status });
}

export function optionsResponse() {
  return new Response(null, {
    status: 204,
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "authorization, content-type",
      "access-control-allow-methods": "GET, POST, PATCH, DELETE, OPTIONS",
      "access-control-max-age": "86400",
    },
  });
}
