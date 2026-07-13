import { c as createServerRpc } from "./createServerRpc-wV0Vk4NU.mjs";
import { r as requireSupabaseAuth } from "./auth-middleware-DJP7Badx.mjs";
import { supabaseAdmin } from "./client.server-BMj2q4-x.mjs";
import { c as createServerFn } from "./index.mjs";
import "../_libs/seroval.mjs";
import "../_libs/react.mjs";
import { o as object, s as string, n as number, a as array, _ as _enum } from "../_libs/zod.mjs";
import "../_libs/supabase__supabase-js.mjs";
import "../_libs/supabase__postgrest-js.mjs";
import "../_libs/supabase__realtime-js.mjs";
import "../_libs/supabase__phoenix.mjs";
import "../_libs/supabase__storage-js.mjs";
import "../_libs/iceberg-js.mjs";
import "../_libs/supabase__auth-js.mjs";
import "tslib";
import "../_libs/supabase__functions-js.mjs";
import "./createMiddleware-BvN2ghIY.mjs";
import "node:async_hooks";
import "../_libs/h3-v2.mjs";
import "../_libs/rou3.mjs";
import "../_libs/srvx.mjs";
import "node:stream";
import "../_libs/tanstack__router-core.mjs";
import "../_libs/tanstack__history.mjs";
import "../_libs/cookie-es.mjs";
import "../_libs/seroval-plugins.mjs";
import "node:stream/web";
import "../_libs/tanstack__react-router.mjs";
import "../_libs/react-dom.mjs";
import "async_hooks";
import "util";
import "crypto";
import "stream";
import "../_libs/isbot.mjs";
function escapeHtml(value) {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
function formatExpirationDate(value) {
  if (!value) {
    return "the invitation expiration date";
  }
  const date = typeof value === "string" ? new Date(value) : value;
  if (Number.isNaN(date.getTime())) {
    return String(value);
  }
  return new Intl.DateTimeFormat("en", {
    dateStyle: "long",
    timeStyle: "short",
    timeZone: "UTC"
  }).format(date);
}
function buildInvitationUrl(appUrl, token) {
  return `${appUrl.replace(/\/$/, "")}/invite/${encodeURIComponent(token)}`;
}
function createInvitationEmailTemplate({
  appUrl,
  token,
  organizationName,
  inviterNameOrEmail,
  expiresAt
}) {
  const invitationUrl = buildInvitationUrl(appUrl, token);
  const expirationDate = formatExpirationDate(expiresAt);
  const subject = `You've been invited to join ${organizationName}`;
  const safeOrganizationName = escapeHtml(organizationName);
  const safeInviterNameOrEmail = escapeHtml(inviterNameOrEmail);
  const safeExpirationDate = escapeHtml(expirationDate);
  const safeInvitationUrl = escapeHtml(invitationUrl);
  const html = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(subject)}</title>
  </head>
  <body style="margin:0;padding:0;background-color:#f6f7fb;font-family:Arial,Helvetica,sans-serif;color:#172033;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;border-collapse:collapse;background-color:#f6f7fb;">
      <tr>
        <td align="center" style="padding:32px 16px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;max-width:600px;border-collapse:collapse;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 8px 28px rgba(23,32,51,0.08);">
            <tr>
              <td style="padding:32px 28px 12px 28px;">
                <p style="margin:0 0 12px 0;font-size:14px;line-height:20px;color:#667085;">Invitation to collaborate</p>
                <h1 style="margin:0;font-size:28px;line-height:34px;font-weight:700;color:#172033;">Join ${safeOrganizationName}</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:12px 28px 0 28px;">
                <p style="margin:0;font-size:16px;line-height:26px;color:#344054;">${safeInviterNameOrEmail} invited you to join <strong style="font-weight:700;color:#172033;">${safeOrganizationName}</strong> on Quote Buddy.</p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:28px;">
                <a href="${safeInvitationUrl}" style="display:inline-block;width:100%;max-width:280px;box-sizing:border-box;border-radius:999px;background-color:#172033;color:#ffffff;text-decoration:none;text-align:center;font-size:16px;line-height:22px;font-weight:700;padding:14px 22px;">Accept Invitation</a>
              </td>
            </tr>
            <tr>
              <td style="padding:0 28px 24px 28px;">
                <p style="margin:0 0 16px 0;font-size:14px;line-height:22px;color:#667085;">This invitation expires on <strong style="font-weight:700;color:#344054;">${safeExpirationDate} UTC</strong>.</p>
                <p style="margin:0 0 8px 0;font-size:14px;line-height:22px;color:#667085;">If the button does not work, copy and paste this invitation URL into your browser:</p>
                <p style="margin:0;word-break:break-all;font-size:14px;line-height:22px;color:#175cd3;"><a href="${safeInvitationUrl}" style="color:#175cd3;text-decoration:underline;">${safeInvitationUrl}</a></p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
  const text = [
    `You've been invited to join ${organizationName}`,
    "",
    `${inviterNameOrEmail} invited you to join ${organizationName} on Quote Buddy.`,
    "",
    `Accept the invitation: ${invitationUrl}`,
    `This invitation expires on ${expirationDate} UTC.`,
    "",
    `If the link above does not work, copy and paste this URL into your browser: ${invitationUrl}`
  ].join("\n");
  return { subject, html, text };
}
const RESEND_API_BASE_URL = "https://api.resend.com";
const RESEND_SEND_ENDPOINT = `${RESEND_API_BASE_URL}/emails`;
const MAX_RESEND_SEND_ATTEMPTS = 3;
const INITIAL_RETRY_DELAY_MS = 250;
class ResendSendError extends Error {
  status;
  transient;
  constructor(message, options) {
    super(message);
    this.name = "ResendSendError";
    this.status = options.status;
    this.transient = options.transient;
  }
}
function getConfiguredAppOrigin() {
  return process.env.APP_ORIGIN || process.env.PUBLIC_APP_ORIGIN || null;
}
function getFromEmailDomain(from) {
  const angleMatch = from.match(/<[^@<>\s]+@([^<>\s]+)>/);
  const emailLike = angleMatch?.[0] ?? from;
  const domainMatch = emailLike.match(/@([^>\s]+)>?$/);
  return domainMatch?.[1]?.toLowerCase() ?? null;
}
function isDomainUsableForSending(domain) {
  return domain.status === "verified" || domain.capabilities?.sending === "enabled";
}
async function verifyInvitationEmailConfiguration() {
  const appOrigin = getConfiguredAppOrigin();
  const apiKey = process.env.RESEND_API_KEY || null;
  const from = process.env.RESEND_FROM_EMAIL || null;
  const fromDomain = from ? getFromEmailDomain(from) : null;
  const messages = [];
  if (!appOrigin) messages.push("APP_ORIGIN or PUBLIC_APP_ORIGIN is required to build invitation links.");
  if (!apiKey) messages.push("RESEND_API_KEY is required to authenticate with Resend.");
  if (!from) messages.push("RESEND_FROM_EMAIL is required so Resend knows the sender address.");
  if (from && !fromDomain) messages.push("RESEND_FROM_EMAIL must contain a valid email address domain.");
  if (!apiKey || !from || !fromDomain) {
    return {
      ok: false,
      appOriginConfigured: Boolean(appOrigin),
      resendApiKeyConfigured: Boolean(apiKey),
      resendFromEmailConfigured: Boolean(from),
      resendApiReachable: false,
      fromDomain,
      fromDomainVerified: null,
      messages
    };
  }
  try {
    const response = await fetch(`${RESEND_API_BASE_URL}/domains`, {
      headers: { Authorization: `Bearer ${apiKey}` }
    });
    if (!response.ok) {
      messages.push(`Resend API returned HTTP ${response.status} while checking domains.`);
      return {
        ok: false,
        appOriginConfigured: Boolean(appOrigin),
        resendApiKeyConfigured: true,
        resendFromEmailConfigured: true,
        resendApiReachable: false,
        fromDomain,
        fromDomainVerified: null,
        messages
      };
    }
    const payload = await response.json();
    const matchingDomain = payload.data?.find((domain) => domain.name?.toLowerCase() === fromDomain) ?? null;
    const fromDomainVerified = matchingDomain ? isDomainUsableForSending(matchingDomain) : false;
    if (!matchingDomain) {
      messages.push(`The sender domain ${fromDomain} was not found in Resend.`);
    } else if (!fromDomainVerified) {
      messages.push(`The sender domain ${fromDomain} is not verified or enabled for sending in Resend.`);
    }
    return {
      ok: Boolean(appOrigin) && fromDomainVerified,
      appOriginConfigured: Boolean(appOrigin),
      resendApiKeyConfigured: true,
      resendFromEmailConfigured: true,
      resendApiReachable: true,
      fromDomain,
      fromDomainVerified,
      messages: messages.length > 0 ? messages : ["Invitation email configuration is ready."]
    };
  } catch (error) {
    messages.push(error instanceof Error ? error.message : "Unable to reach Resend API.");
    return {
      ok: false,
      appOriginConfigured: Boolean(appOrigin),
      resendApiKeyConfigured: true,
      resendFromEmailConfigured: true,
      resendApiReachable: false,
      fromDomain,
      fromDomainVerified: null,
      messages
    };
  }
}
function getRequiredEnv(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
function isTransientStatus(status) {
  return status === 408 || status === 429 || status >= 500;
}
function isNetworkLikeError(error) {
  if (error instanceof TypeError) return true;
  if (error instanceof DOMException && error.name === "AbortError") return true;
  const code = typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
  return ["ECONNRESET", "ETIMEDOUT", "ECONNREFUSED", "EAI_AGAIN", "ENOTFOUND"].includes(code);
}
function summarizeResendError(error) {
  if (error instanceof ResendSendError) {
    return { status: error.status, reason: error.message };
  }
  if (error instanceof Error) {
    return { reason: error.name || "network_error" };
  }
  return { reason: "unknown_error" };
}
function shouldRetryResendError(error) {
  if (error instanceof ResendSendError) return error.transient;
  return isNetworkLikeError(error);
}
function logResendAttemptFailure(error, context) {
  const summary = summarizeResendError(error);
  console.warn("Resend email send attempt failed", {
    ...context,
    ...summary
  });
}
async function resendSendWithRetry(params) {
  let apiKey;
  let from;
  try {
    apiKey = getRequiredEnv("RESEND_API_KEY");
    from = getRequiredEnv("RESEND_FROM_EMAIL");
  } catch {
    console.warn("Resend email configuration is missing", {
      emailType: params.type,
      recipient: params.to,
      reason: "missing_email_configuration"
    });
    throw new Error("Unable to send invitation email. Please verify the email configuration.");
  }
  let lastError;
  for (let attempt = 1; attempt <= MAX_RESEND_SEND_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(RESEND_SEND_ENDPOINT, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          from,
          to: params.to,
          subject: params.subject,
          html: params.html,
          text: params.text
        })
      });
      if (!response.ok) {
        throw new ResendSendError(`Resend returned HTTP ${response.status}`, {
          status: response.status,
          transient: isTransientStatus(response.status)
        });
      }
      return;
    } catch (error) {
      lastError = error;
      const retryable2 = shouldRetryResendError(error);
      logResendAttemptFailure(error, {
        emailType: params.type,
        recipient: params.to,
        attempt,
        maxAttempts: MAX_RESEND_SEND_ATTEMPTS
      });
      if (!retryable2 || attempt === MAX_RESEND_SEND_ATTEMPTS) break;
      await sleep(INITIAL_RETRY_DELAY_MS * 2 ** (attempt - 1));
    }
  }
  const retryable = shouldRetryResendError(lastError);
  throw new Error(
    retryable ? "Unable to send invitation email after multiple attempts. Please try again shortly." : "Unable to send invitation email. Please verify the invitation details and email configuration."
  );
}
async function sendOrganizationInvitationEmail(params) {
  const appUrl = params.appUrl ?? getConfiguredAppOrigin();
  if (!appUrl) throw new Error("Application origin is not configured");
  const template = createInvitationEmailTemplate({
    appUrl,
    token: params.token,
    organizationName: params.organizationName,
    inviterNameOrEmail: params.inviterNameOrEmail?.trim() || "Your team",
    expiresAt: params.expiresAt
  });
  await resendSendWithRetry({
    to: params.email,
    subject: template.subject,
    html: template.html,
    text: template.text,
    type: "organization_invitation"
  });
}
async function loadActiveOrg(userId) {
  await supabaseAdmin.from("profiles").upsert({
    user_id: userId
  }, {
    onConflict: "user_id"
  });
  const {
    data: profile
  } = await supabaseAdmin.from("profiles").select("active_org_id").eq("user_id", userId).maybeSingle();
  let activeOrgId = profile?.active_org_id ?? null;
  if (!activeOrgId) {
    const {
      data: first
    } = await supabaseAdmin.from("organization_members").select("org_id").eq("user_id", userId).order("created_at", {
      ascending: true
    }).limit(1).maybeSingle();
    if (first) {
      activeOrgId = first.org_id;
      await supabaseAdmin.from("profiles").update({
        active_org_id: activeOrgId
      }).eq("user_id", userId);
    }
  }
  if (!activeOrgId) return null;
  const {
    data: member
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", userId).eq("org_id", activeOrgId).maybeSingle();
  if (!member) {
    await supabaseAdmin.from("profiles").update({
      active_org_id: null
    }).eq("user_id", userId);
    return loadActiveOrg(userId);
  }
  const {
    data: org
  } = await supabaseAdmin.from("organizations").select("id, name").eq("id", activeOrgId).maybeSingle();
  if (!org) return null;
  const {
    data: prof
  } = await supabaseAdmin.from("organization_profiles").select("*").eq("org_id", activeOrgId).maybeSingle();
  const fallback = {
    org_id: activeOrgId,
    name: org.name,
    short_name: null,
    logo_url: null,
    emails: [],
    website: null,
    registration: null,
    tin: null,
    duns: null,
    praz: null,
    currency: "USD",
    default_tax_rate: 15,
    address: null,
    phone: null,
    payment_instructions: null
  };
  return {
    org_id: activeOrgId,
    org_name: org.name,
    role: member.role,
    profile: prof ? {
      ...fallback,
      ...prof,
      emails: prof.emails ?? []
    } : fallback
  };
}
const getActiveOrg_createServerFn_handler = createServerRpc({
  id: "a712b874dcb0ba56f949ac0ba011125a966c33b5fee3f7860a15c94f9f419f84",
  name: "getActiveOrg",
  filename: "src/lib/org.functions.ts"
}, (opts) => getActiveOrg.__executeServer(opts));
const getActiveOrg = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(getActiveOrg_createServerFn_handler, async ({
  context
}) => {
  return loadActiveOrg(context.userId);
});
const getMyOrganizations_createServerFn_handler = createServerRpc({
  id: "f6df55ef7fb88800491b81ab55dd21438f9af2d5b3f72405fa4a43d34dd4b4c8",
  name: "getMyOrganizations",
  filename: "src/lib/org.functions.ts"
}, (opts) => getMyOrganizations.__executeServer(opts));
const getMyOrganizations = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).handler(getMyOrganizations_createServerFn_handler, async ({
  context
}) => {
  const {
    data
  } = await supabaseAdmin.from("organization_members").select("role, org:organizations(id, name)").eq("user_id", context.userId).order("created_at", {
    ascending: true
  });
  return (data ?? []).map((r) => {
    const o = r.org;
    return o ? {
      id: o.id,
      name: o.name,
      role: r.role
    } : null;
  }).filter((x) => x !== null);
});
const setActiveOrg_createServerFn_handler = createServerRpc({
  id: "fd7499eddb13ac796ed2536f123650591c4c896dc31515c9627671dfd3a67093",
  name: "setActiveOrg",
  filename: "src/lib/org.functions.ts"
}, (opts) => setActiveOrg.__executeServer(opts));
const setActiveOrg = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(setActiveOrg_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("id").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m) throw new Error("Not a member of that organization");
  await supabaseAdmin.from("profiles").upsert({
    user_id: context.userId,
    active_org_id: data.org_id
  }, {
    onConflict: "user_id"
  });
  return {
    ok: true
  };
});
const createOrganization_createServerFn_handler = createServerRpc({
  id: "84b0c2eecdbf4659ef0c593620079dbe3c2111e6a133e76e79a176da6d860713",
  name: "createOrganization",
  filename: "src/lib/org.functions.ts"
}, (opts) => createOrganization.__executeServer(opts));
const createOrganization = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  name: string().trim().min(1).max(200)
}).parse(d)).handler(createOrganization_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: org,
    error
  } = await supabaseAdmin.from("organizations").insert({
    name: data.name,
    created_by: context.userId
  }).select("id").single();
  if (error) throw new Error(error.message);
  return {
    org_id: org.id
  };
});
const ProfileUpdateSchema = object({
  name: string().trim().min(1).max(200),
  short_name: string().trim().max(80).optional().nullable(),
  logo_url: string().trim().url().max(2e3).optional().nullable(),
  emails: array(string().trim().email().max(255)).max(10).default([]),
  website: string().trim().max(255).optional().nullable(),
  registration: string().trim().max(80).optional().nullable(),
  tin: string().trim().max(80).optional().nullable(),
  duns: string().trim().max(80).optional().nullable(),
  praz: string().trim().max(80).optional().nullable(),
  currency: string().trim().min(1).max(8),
  default_tax_rate: number().min(0).max(100),
  address: string().trim().max(500).optional().nullable(),
  phone: string().trim().max(40).optional().nullable(),
  payment_instructions: string().trim().max(1e3).optional().nullable()
});
const updateOrganizationProfile_createServerFn_handler = createServerRpc({
  id: "f9486fae176dc8b4aebdd0a79c382df56fe80902ff4ee323327d968d2f5514c9",
  name: "updateOrganizationProfile",
  filename: "src/lib/org.functions.ts"
}, (opts) => updateOrganizationProfile.__executeServer(opts));
const updateOrganizationProfile = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid(),
  patch: ProfileUpdateSchema
}).parse(d)).handler(updateOrganizationProfile_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m || m.role !== "admin" && m.role !== "owner") {
    throw new Error("Only admins or owners can update organization profile");
  }
  await supabaseAdmin.from("organizations").update({
    name: data.patch.name
  }).eq("id", data.org_id);
  const {
    error
  } = await supabaseAdmin.from("organization_profiles").update({
    name: data.patch.name,
    short_name: data.patch.short_name ?? null,
    logo_url: data.patch.logo_url ?? null,
    emails: data.patch.emails,
    website: data.patch.website ?? null,
    registration: data.patch.registration ?? null,
    tin: data.patch.tin ?? null,
    duns: data.patch.duns ?? null,
    praz: data.patch.praz ?? null,
    currency: data.patch.currency,
    default_tax_rate: data.patch.default_tax_rate,
    address: data.patch.address ?? null,
    phone: data.patch.phone ?? null,
    payment_instructions: data.patch.payment_instructions ?? null
  }).eq("org_id", data.org_id);
  if (error) throw new Error(error.message);
  return {
    ok: true
  };
});
const listMembers_createServerFn_handler = createServerRpc({
  id: "9eb59f5b6ed98c991d38bc0c6f97b2596050741426092f4a6d6b418df4973982",
  name: "listMembers",
  filename: "src/lib/org.functions.ts"
}, (opts) => listMembers.__executeServer(opts));
const listMembers = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(listMembers_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("id").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m) throw new Error("Not a member");
  const {
    data: rows
  } = await supabaseAdmin.from("organization_members").select("id, user_id, role, created_at").eq("org_id", data.org_id).order("created_at", {
    ascending: true
  });
  if (!rows) return [];
  const out = [];
  for (const r of rows) {
    let email = null;
    try {
      const {
        data: u
      } = await supabaseAdmin.auth.admin.getUserById(r.user_id);
      email = u?.user?.email ?? null;
    } catch {
      email = null;
    }
    out.push({
      id: r.id,
      user_id: r.user_id,
      email,
      role: r.role,
      created_at: r.created_at
    });
  }
  return out;
});
async function randomToken() {
  const {
    randomBytes
  } = await import("node:crypto");
  return randomBytes(32).toString("hex");
}
function isUniqueConstraintError(error) {
  return error?.code === "23505" || error?.status === 409;
}
const verifyEmailConfiguration_createServerFn_handler = createServerRpc({
  id: "2256e1bfd5d91b72f7e1fc49d84f822d96b2cdbd133520f127a379ab8773a788",
  name: "verifyEmailConfiguration",
  filename: "src/lib/org.functions.ts"
}, (opts) => verifyEmailConfiguration.__executeServer(opts));
const verifyEmailConfiguration = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(verifyEmailConfiguration_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m || m.role !== "admin" && m.role !== "owner") {
    throw new Error("Only admins or owners can verify email configuration");
  }
  return verifyInvitationEmailConfiguration();
});
const inviteMember_createServerFn_handler = createServerRpc({
  id: "b426aeeef2518b0319c52f7c77edfbcff23decd9c46a9eccdeda2c88b8fd6ecb",
  name: "inviteMember",
  filename: "src/lib/org.functions.ts"
}, (opts) => inviteMember.__executeServer(opts));
const inviteMember = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid(),
  email: string().trim().email().max(255),
  role: _enum(["owner", "admin", "member"])
}).parse(d)).handler(inviteMember_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m || m.role !== "admin" && m.role !== "owner") {
    throw new Error("Only admins or owners can invite");
  }
  if (data.role === "owner" && m.role !== "owner") {
    throw new Error("Only owners can invite other owners");
  }
  const token = await randomToken();
  const {
    data: inv,
    error
  } = await supabaseAdmin.from("organization_invitations").insert({
    org_id: data.org_id,
    email: data.email.toLowerCase(),
    role: data.role,
    token,
    invited_by: context.userId
  }).select("id, token, expires_at").single();
  if (error) throw new Error(error.message);
  const {
    data: org
  } = await supabaseAdmin.from("organizations").select("name").eq("id", data.org_id).maybeSingle();
  const {
    data: inviterProfile
  } = await supabaseAdmin.from("profiles").select("display_name").eq("user_id", context.userId).maybeSingle();
  const appOrigin = process.env.APP_ORIGIN ?? process.env.PUBLIC_APP_ORIGIN;
  if (!appOrigin) throw new Error("Application origin is not configured");
  await sendOrganizationInvitationEmail({
    email: data.email.toLowerCase(),
    appUrl: appOrigin,
    token: inv.token,
    organizationName: org?.name ?? "your organization",
    inviterNameOrEmail: inviterProfile?.display_name ?? context.claims.email ?? null,
    expiresAt: inv.expires_at
  });
  return {
    id: inv.id,
    token: inv.token,
    expires_at: inv.expires_at
  };
});
const listInvitations_createServerFn_handler = createServerRpc({
  id: "cf705c555671f0b12ea8d915d942b8fdc5adeafb09d0597e28fff6c239955315",
  name: "listInvitations",
  filename: "src/lib/org.functions.ts"
}, (opts) => listInvitations.__executeServer(opts));
const listInvitations = createServerFn({
  method: "GET"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  org_id: string().uuid()
}).parse(d)).handler(listInvitations_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m || m.role !== "admin" && m.role !== "owner") {
    throw new Error("Only admins or owners can view invitations");
  }
  const {
    data: rows
  } = await supabaseAdmin.from("organization_invitations").select("id, email, role, token, expires_at, accepted_at, created_at").eq("org_id", data.org_id).is("accepted_at", null).order("created_at", {
    ascending: false
  });
  return rows ?? [];
});
const revokeInvitation_createServerFn_handler = createServerRpc({
  id: "aaf774323bd8740e9a9bb00cf585ba963e2c90da6cb3b4272491b50cda9e7e8f",
  name: "revokeInvitation",
  filename: "src/lib/org.functions.ts"
}, (opts) => revokeInvitation.__executeServer(opts));
const revokeInvitation = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  id: string().uuid(),
  org_id: string().uuid()
}).parse(d)).handler(revokeInvitation_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: m
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!m || m.role !== "admin" && m.role !== "owner") {
    throw new Error("Only admins or owners can revoke invitations");
  }
  await supabaseAdmin.from("organization_invitations").delete().eq("id", data.id).eq("org_id", data.org_id);
  return {
    ok: true
  };
});
const removeMember_createServerFn_handler = createServerRpc({
  id: "4bf7f32b4392bf2b7eeab37fa0189fbe8e625a84022323b98d66ad05ac9580f3",
  name: "removeMember",
  filename: "src/lib/org.functions.ts"
}, (opts) => removeMember.__executeServer(opts));
const removeMember = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  id: string().uuid(),
  org_id: string().uuid()
}).parse(d)).handler(removeMember_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: caller
  } = await supabaseAdmin.from("organization_members").select("role, user_id").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!caller) throw new Error("Not a member");
  const {
    data: target
  } = await supabaseAdmin.from("organization_members").select("user_id, role").eq("id", data.id).maybeSingle();
  if (!target) throw new Error("Member not found");
  const isSelf = target.user_id === context.userId;
  const isAdmin = caller.role === "owner" || caller.role === "admin";
  if (!isSelf && !isAdmin) throw new Error("Not allowed");
  if (target.role === "owner" && caller.role !== "owner") {
    throw new Error("Only owners can remove owners");
  }
  if (target.role === "owner") {
    const {
      count
    } = await supabaseAdmin.from("organization_members").select("id", {
      count: "exact",
      head: true
    }).eq("org_id", data.org_id).eq("role", "owner");
    if ((count ?? 0) <= 1) throw new Error("Cannot remove the last owner");
  }
  await supabaseAdmin.from("organization_members").delete().eq("id", data.id);
  return {
    ok: true
  };
});
const changeMemberRole_createServerFn_handler = createServerRpc({
  id: "5b6fb3943afd9658925d57f7c7db2425dc5e088f15813e85c5dceab2bf210015",
  name: "changeMemberRole",
  filename: "src/lib/org.functions.ts"
}, (opts) => changeMemberRole.__executeServer(opts));
const changeMemberRole = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  id: string().uuid(),
  org_id: string().uuid(),
  role: _enum(["owner", "admin", "member"])
}).parse(d)).handler(changeMemberRole_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: caller
  } = await supabaseAdmin.from("organization_members").select("role").eq("user_id", context.userId).eq("org_id", data.org_id).maybeSingle();
  if (!caller || caller.role !== "owner" && caller.role !== "admin") {
    throw new Error("Only admins or owners can change roles");
  }
  if (data.role === "owner" && caller.role !== "owner") {
    throw new Error("Only owners can promote to owner");
  }
  const {
    data: target
  } = await supabaseAdmin.from("organization_members").select("user_id, role").eq("id", data.id).maybeSingle();
  if (!target) throw new Error("Member not found");
  if (target.role === "owner" && data.role !== "owner") {
    const {
      count
    } = await supabaseAdmin.from("organization_members").select("id", {
      count: "exact",
      head: true
    }).eq("org_id", data.org_id).eq("role", "owner");
    if ((count ?? 0) <= 1) throw new Error("Cannot demote the last owner");
  }
  await supabaseAdmin.from("organization_members").update({
    role: data.role
  }).eq("id", data.id);
  return {
    ok: true
  };
});
const getInvitation_createServerFn_handler = createServerRpc({
  id: "8a1a326815219806a6afe2fbfebff5f7a631ade78d6eb18a322567b5a24c0d37",
  name: "getInvitation",
  filename: "src/lib/org.functions.ts"
}, (opts) => getInvitation.__executeServer(opts));
const getInvitation = createServerFn({
  method: "POST"
}).inputValidator((d) => object({
  token: string().trim().min(1).max(128)
}).parse(d)).handler(getInvitation_createServerFn_handler, async ({
  data
}) => {
  const {
    data: inv
  } = await supabaseAdmin.from("organization_invitations").select("org_id, email, role, expires_at, accepted_at, org:organizations(name)").eq("token", data.token).maybeSingle();
  if (!inv) return {
    status: "not_found"
  };
  if (inv.accepted_at) return {
    status: "accepted"
  };
  if (new Date(inv.expires_at).getTime() < Date.now()) return {
    status: "expired"
  };
  const orgName = inv.org?.name ?? "Organization";
  return {
    status: "ok",
    org_id: inv.org_id,
    org_name: orgName,
    email: inv.email,
    role: inv.role,
    expires_at: inv.expires_at
  };
});
const acceptInvitation_createServerFn_handler = createServerRpc({
  id: "f0e3a4b46b51e1ef7c6ad701ca9ea4a1f855dd767589c6e69b9392d20bfa8c39",
  name: "acceptInvitation",
  filename: "src/lib/org.functions.ts"
}, (opts) => acceptInvitation.__executeServer(opts));
const acceptInvitation = createServerFn({
  method: "POST"
}).middleware([requireSupabaseAuth]).inputValidator((d) => object({
  token: string().trim().min(1).max(128)
}).parse(d)).handler(acceptInvitation_createServerFn_handler, async ({
  data,
  context
}) => {
  const {
    data: inv
  } = await supabaseAdmin.from("organization_invitations").select("id, org_id, email, role, expires_at, accepted_at").eq("token", data.token).maybeSingle();
  if (!inv) throw new Error("Invitation not found");
  if (inv.accepted_at) throw new Error("Invitation already used");
  if (new Date(inv.expires_at).getTime() < Date.now()) throw new Error("Invitation expired");
  const userEmail = context.claims.email?.toLowerCase();
  if (userEmail && userEmail !== inv.email.toLowerCase()) {
    throw new Error(`This invitation is for ${inv.email}. Sign in with that email to accept.`);
  }
  const {
    error: insErr
  } = await supabaseAdmin.from("organization_members").insert({
    org_id: inv.org_id,
    user_id: context.userId,
    role: inv.role
  });
  if (insErr && !isUniqueConstraintError(insErr)) {
    throw new Error(`Failed to add organization membership: ${insErr.message}`);
  }
  await supabaseAdmin.from("organization_invitations").update({
    accepted_at: (/* @__PURE__ */ new Date()).toISOString()
  }).eq("id", inv.id);
  await supabaseAdmin.from("profiles").upsert({
    user_id: context.userId,
    active_org_id: inv.org_id
  }, {
    onConflict: "user_id"
  });
  return {
    org_id: inv.org_id
  };
});
const getDocumentIssuerBrand_createServerFn_handler = createServerRpc({
  id: "6ad53436a5e87e5dc7122d5cc9863663c4018b62b43d563e9efdcd77a69e5723",
  name: "getDocumentIssuerBrand",
  filename: "src/lib/org.functions.ts"
}, (opts) => getDocumentIssuerBrand.__executeServer(opts));
const getDocumentIssuerBrand = createServerFn({
  method: "POST"
}).inputValidator((d) => object({
  id: string().trim().min(1).max(64)
}).parse(d)).handler(getDocumentIssuerBrand_createServerFn_handler, async ({
  data
}) => {
  const {
    data: doc
  } = await supabaseAdmin.from("documents").select("org_id").eq("id", data.id).maybeSingle();
  if (!doc) return null;
  const {
    data: prof
  } = await supabaseAdmin.from("organization_profiles").select("name, short_name, website, logo_url").eq("org_id", doc.org_id).maybeSingle();
  return prof ? {
    name: prof.name,
    short_name: prof.short_name,
    website: prof.website,
    logo_url: prof.logo_url
  } : null;
});
export {
  acceptInvitation_createServerFn_handler,
  changeMemberRole_createServerFn_handler,
  createOrganization_createServerFn_handler,
  getActiveOrg_createServerFn_handler,
  getDocumentIssuerBrand_createServerFn_handler,
  getInvitation_createServerFn_handler,
  getMyOrganizations_createServerFn_handler,
  inviteMember_createServerFn_handler,
  listInvitations_createServerFn_handler,
  listMembers_createServerFn_handler,
  removeMember_createServerFn_handler,
  revokeInvitation_createServerFn_handler,
  setActiveOrg_createServerFn_handler,
  updateOrganizationProfile_createServerFn_handler,
  verifyEmailConfiguration_createServerFn_handler
};
