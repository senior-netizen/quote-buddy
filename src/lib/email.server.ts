const RESEND_API_BASE_URL = "https://api.resend.com";
const RESEND_SEND_ENDPOINT = `${RESEND_API_BASE_URL}/emails`;
const MAX_RESEND_SEND_ATTEMPTS = 3;
const INITIAL_RETRY_DELAY_MS = 250;

type EmailType = "organization_invitation";

export type EmailConfigurationCheck = {
  ok: boolean;
  appOriginConfigured: boolean;
  resendApiKeyConfigured: boolean;
  resendFromEmailConfigured: boolean;
  resendApiReachable: boolean;
  fromDomain: string | null;
  fromDomainVerified: boolean | null;
  messages: string[];
};

type ResendDomain = {
  name?: string;
  status?: string;
  capabilities?: {
    sending?: string;
  };
};

type SendEmailParams = {
  to: string;
  subject: string;
  html: string;
  text: string;
  type: EmailType;
};

type ResendErrorContext = {
  emailType: EmailType;
  recipient: string;
  attempt: number;
  maxAttempts: number;
  status?: number;
  reason: string;
};

class ResendSendError extends Error {
  status?: number;
  transient: boolean;

  constructor(message: string, options: { status?: number; transient: boolean }) {
    super(message);
    this.name = "ResendSendError";
    this.status = options.status;
    this.transient = options.transient;
  }
}

function getConfiguredAppOrigin(): string | null {
  return process.env.APP_ORIGIN || process.env.PUBLIC_APP_ORIGIN || null;
}

function getFromEmailDomain(from: string): string | null {
  const angleMatch = from.match(/<[^@<>\s]+@([^<>\s]+)>/);
  const emailLike = angleMatch?.[0] ?? from;
  const domainMatch = emailLike.match(/@([^>\s]+)>?$/);
  return domainMatch?.[1]?.toLowerCase() ?? null;
}

function isDomainUsableForSending(domain: ResendDomain): boolean {
  return domain.status === "verified" || domain.capabilities?.sending === "enabled";
}

export async function verifyInvitationEmailConfiguration(): Promise<EmailConfigurationCheck> {
  const appOrigin = getConfiguredAppOrigin();
  const apiKey = process.env.RESEND_API_KEY || null;
  const from = process.env.RESEND_FROM_EMAIL || null;
  const fromDomain = from ? getFromEmailDomain(from) : null;
  const messages: string[] = [];

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
      messages,
    };
  }

  try {
    const response = await fetch(`${RESEND_API_BASE_URL}/domains`, {
      headers: { Authorization: `Bearer ${apiKey}` },
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
        messages,
      };
    }

    const payload = (await response.json()) as { data?: ResendDomain[] };
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
      messages: messages.length > 0 ? messages : ["Invitation email configuration is ready."],
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
      messages,
    };
  }
}

function getRequiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not configured`);
  return value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isTransientStatus(status: number): boolean {
  return status === 408 || status === 429 || status >= 500;
}

function isNetworkLikeError(error: unknown): boolean {
  if (error instanceof TypeError) return true;
  if (error instanceof DOMException && error.name === "AbortError") return true;

  const code = typeof error === "object" && error !== null && "code" in error ? String(error.code) : "";
  return ["ECONNRESET", "ETIMEDOUT", "ECONNREFUSED", "EAI_AGAIN", "ENOTFOUND"].includes(code);
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) => {
    switch (char) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      case "'":
        return "&#39;";
      default:
        return char;
    }
  });
}

function summarizeResendError(error: unknown): Pick<ResendErrorContext, "status" | "reason"> {
  if (error instanceof ResendSendError) {
    return { status: error.status, reason: error.message };
  }
  if (error instanceof Error) {
    return { reason: error.name || "network_error" };
  }
  return { reason: "unknown_error" };
}

function shouldRetryResendError(error: unknown): boolean {
  if (error instanceof ResendSendError) return error.transient;
  return isNetworkLikeError(error);
}

function logResendAttemptFailure(error: unknown, context: Omit<ResendErrorContext, "reason" | "status">): void {
  const summary = summarizeResendError(error);
  console.warn("Resend email send attempt failed", {
    ...context,
    ...summary,
  });
}

async function resendSendWithRetry(params: SendEmailParams): Promise<void> {
  let apiKey: string;
  let from: string;

  try {
    apiKey = getRequiredEnv("RESEND_API_KEY");
    from = getRequiredEnv("RESEND_FROM_EMAIL");
  } catch {
    console.warn("Resend email configuration is missing", {
      emailType: params.type,
      recipient: params.to,
      reason: "missing_email_configuration",
    });
    throw new Error("Unable to send invitation email. Please verify the email configuration.");
  }

  let lastError: unknown;

  for (let attempt = 1; attempt <= MAX_RESEND_SEND_ATTEMPTS; attempt++) {
    try {
      const response = await fetch(RESEND_SEND_ENDPOINT, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from,
          to: params.to,
          subject: params.subject,
          html: params.html,
          text: params.text,
        }),
      });

      if (!response.ok) {
        throw new ResendSendError(`Resend returned HTTP ${response.status}`, {
          status: response.status,
          transient: isTransientStatus(response.status),
        });
      }

      return;
    } catch (error) {
      lastError = error;
      const retryable = shouldRetryResendError(error);
      logResendAttemptFailure(error, {
        emailType: params.type,
        recipient: params.to,
        attempt,
        maxAttempts: MAX_RESEND_SEND_ATTEMPTS,
      });

      if (!retryable || attempt === MAX_RESEND_SEND_ATTEMPTS) break;
      await sleep(INITIAL_RETRY_DELAY_MS * 2 ** (attempt - 1));
    }
  }

  const retryable = shouldRetryResendError(lastError);
  throw new Error(
    retryable
      ? "Unable to send invitation email after multiple attempts. Please try again shortly."
      : "Unable to send invitation email. Please verify the invitation details and email configuration.",
  );
}

export async function sendOrganizationInvitationEmail(params: {
  email: string;
  organizationName: string;
  role: "owner" | "admin" | "member";
  inviteUrl: string;
}): Promise<void> {
  const escapedOrganizationName = escapeHtml(params.organizationName);
  const escapedRole = escapeHtml(params.role);
  const escapedInviteUrl = escapeHtml(params.inviteUrl);
  const subject = `You're invited to join ${params.organizationName}`;
  const text = [
    `You've been invited to join ${params.organizationName} as a ${params.role}.`,
    "",
    `Accept the invitation: ${params.inviteUrl}`,
    "",
    "If you were not expecting this invitation, you can ignore this email.",
  ].join("\n");
  const html = `
    <p>You've been invited to join <strong>${escapedOrganizationName}</strong> as a <strong>${escapedRole}</strong>.</p>
    <p><a href="${escapedInviteUrl}">Accept the invitation</a></p>
    <p>If you were not expecting this invitation, you can ignore this email.</p>
  `;

  await resendSendWithRetry({
    to: params.email,
    subject,
    html,
    text,
    type: "organization_invitation",
  });
}
