import { Resend } from "resend";

const DEFAULT_EMAIL_FROM = "My Platform <noreply@yourdomain.co.zw>";
const DEFAULT_REPLY_TO = "support@yourdomain.co.zw";

export type SendEmailInput = {
  to: string | string[];
  subject: string;
  html: string;
  text?: string;
  replyTo?: string;
};

export type SendInvitationEmailInput = {
  organizationName: string;
  inviterName?: string | null;
  inviterEmail?: string | null;
  recipientEmail: string;
  token: string;
  expiresAt: string | Date;
};

function getAppUrl(): string {
  return (process.env.APP_URL ?? "https://yourdomain.co.zw").replace(/\/$/, "");
}

export function buildInvitationUrl(token: string): string {
  return `${getAppUrl()}/invite/${encodeURIComponent(token)}`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export async function sendEmail({ to, subject, html, text, replyTo = DEFAULT_REPLY_TO }: SendEmailInput) {
  const resend = new Resend(process.env.RESEND_API_KEY);
  const { data, error } = await resend.emails.send({
    from: process.env.EMAIL_FROM ?? DEFAULT_EMAIL_FROM,
    to,
    subject,
    html,
    text,
    replyTo,
  });

  if (error) {
    throw new Error(error.message);
  }

  return data;
}

export async function sendInvitationEmail({
  organizationName,
  inviterName,
  inviterEmail,
  recipientEmail,
  token,
  expiresAt,
}: SendInvitationEmailInput) {
  const inviteUrl = buildInvitationUrl(token);
  const expiry = new Date(expiresAt).toLocaleString("en", {
    dateStyle: "medium",
    timeStyle: "short",
    timeZone: "UTC",
  });
  const inviter = inviterName || inviterEmail || "An administrator";
  const safeOrg = escapeHtml(organizationName);
  const safeInviter = escapeHtml(inviter);
  const safeInviteUrl = escapeHtml(inviteUrl);
  const safeExpiry = escapeHtml(expiry);

  return sendEmail({
    to: recipientEmail,
    subject: `You're invited to join ${organizationName}`,
    text: `${inviter} invited you to join ${organizationName}. Accept your invitation: ${inviteUrl}\n\nThis invitation expires ${expiry} UTC.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #111827;">
        <h1 style="font-size: 20px;">You're invited to join ${safeOrg}</h1>
        <p>${safeInviter} invited you to collaborate in ${safeOrg}.</p>
        <p>
          <a href="${safeInviteUrl}" style="display: inline-block; padding: 10px 16px; background: #111827; color: #ffffff; border-radius: 999px; text-decoration: none;">
            Accept invitation
          </a>
        </p>
        <p>Or copy and paste this link into your browser:</p>
        <p><a href="${safeInviteUrl}">${safeInviteUrl}</a></p>
        <p style="color: #6b7280; font-size: 13px;">This invitation expires ${safeExpiry} UTC.</p>
      </div>
    `,
  });
}
