import { otpEmailAssets } from "./otp_email_assets.ts";

/** Email content and inline artwork; no account data or remote image requests. */
export function otpEmail(code: string) {
  if (code.length !== 6 || !/^[0-9]{6}$/.test(code)) throw new Error("Invalid verification code format");
  return {
    subject: "Your Filo verification code",
    attachments: Object.entries(otpEmailAssets).map(([name, content]) => ({
      filename: `filo-${name}.png`,
      content,
      encoding: "base64" as const,
      contentType: "image/png",
      contentDisposition: "inline" as const,
      cid: `${name}.otp@filo`,
    })),
    text: `Your Filo verification code is:\n\n${code}\n\nEnter this code in Filo to verify your device. It expires in 10 minutes.\n\nCopy the six-digit code and paste it into Filo. Never share this code.\n\nIf you did not request this code, you can ignore this email.`,
    // Copy shortcuts belong to the mail client; a script/button cannot promise them.
    html: `<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Filo verification code</title>
<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<style>
:root { color-scheme: light dark; supported-color-schemes: light dark; }
@font-face { font-family: Nunito; src: local('Nunito'); font-style: normal; font-weight: 200 1000; }
@media (prefers-color-scheme: dark) {
  .email-bg { background-color:#0F1A17 !important; }
  .email-card { background-color:#16231F !important; border-color:#2B3F38 !important; }
  .email-text { color:#E8F1EB !important; }
  .email-muted { color:#A9BDB3 !important; }
  .email-code { background-color:#1B2B26 !important; border-color:#78978A !important; }
}
</style>
</head>
<body class="email-bg email-text" style="margin:0;padding:0;background-color:#F9FAF5;color:#14423A;font-family:Nunito,Arial,sans-serif;">
<table class="email-bg" role="presentation" style="width:100%;border-collapse:collapse;background-color:#F9FAF5;">
<tr><td align="center" style="padding:24px 16px;">
<table class="email-card" role="presentation" width="100%" style="max-width:480px;border-collapse:separate;border-spacing:0;background-color:#FFFFFF;border:1px solid #D9E2DA;border-radius:24px;">
<tr><td style="padding:32px 24px;">
<p style="margin:0 0 24px;"><img src="cid:brand.otp@filo" width="144" height="56" alt="filo" style="display:block;width:144px;height:56px;border:0;color:#14423A;font-size:30px;font-weight:900;"></p>
<h1 class="email-text" style="margin:0 0 12px;font-size:24px;line-height:1.3;">Verify your device.</h1>
<p class="email-muted" style="margin:0 0 24px;color:#4F625A;font-size:16px;line-height:1.6;">Enter this verification code in Filo to continue.</p>
<table role="presentation" width="100%" style="border-collapse:separate;border-spacing:0;">
<tr><td class="email-code" align="center" style="padding:20px 12px;background-color:#F0F5F0;border:1px solid #D9E2DA;border-radius:16px;">
<p class="email-text" style="margin:0;font-family:Consolas,monospace;font-size:36px;font-weight:700;line-height:1.3;direction:ltr;user-select:all;-webkit-user-select:all;">${code}</p>
</td></tr></table>
<p class="email-muted" style="margin:12px 0 24px;color:#4F625A;font-size:14px;line-height:1.6;">Select and copy the six-digit code, then paste it into Filo.</p>
<p class="email-text" style="margin:0 0 12px;font-size:16px;line-height:1.6;">This code expires in <strong>10 minutes</strong>. Never share it with anyone.</p>
<p class="email-muted" style="margin:0;color:#4F625A;font-size:14px;line-height:1.6;">If you did not request this code, you can ignore this email.</p>
</td></tr>
<tr><td style="padding:0;border-radius:0 0 24px 24px;"><img src="cid:leaves.otp@filo" width="480" alt="" style="display:block;width:100%;max-width:480px;height:auto;border:0;border-radius:0 0 24px 24px;"></td></tr>
</table>
<p class="email-muted" style="margin:16px 0 0;color:#4F625A;font-size:12px;line-height:1.5;">Filo &middot; Device verification</p>
</td></tr></table>
</body></html>`,
  };
}
