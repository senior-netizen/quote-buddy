export type InvitationEmailTemplateInput = {
  appUrl: string;
  token: string;
  organizationName: string;
  inviterNameOrEmail: string;
  expiresAt: Date | string;
};

export type EmailTemplate = {
  subject: string;
  html: string;
  text: string;
};

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function formatExpirationDate(value: Date | string): string {
  const date = typeof value === "string" ? new Date(value) : value;

  if (Number.isNaN(date.getTime())) {
    return String(value);
  }

  return new Intl.DateTimeFormat("en", {
    dateStyle: "long",
    timeStyle: "short",
    timeZone: "UTC",
  }).format(date);
}

function buildInvitationUrl(appUrl: string, token: string): string {
  return `${appUrl.replace(/\/$/, "")}/invite/${encodeURIComponent(token)}`;
}

export function createInvitationEmailTemplate({
  appUrl,
  token,
  organizationName,
  inviterNameOrEmail,
  expiresAt,
}: InvitationEmailTemplateInput): EmailTemplate {
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
    `If the link above does not work, copy and paste this URL into your browser: ${invitationUrl}`,
  ].join("\n");

  return { subject, html, text };
}
