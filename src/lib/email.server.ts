const RESEND_SEND_ENDPOINT = "https://api.resend.com/emails";
const MAX_RESEND_SEND_ATTEMPTS = 3;
const INITIAL_RETRY_DELAY_MS = 250;

type EmailType = "organization_invitation";

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
