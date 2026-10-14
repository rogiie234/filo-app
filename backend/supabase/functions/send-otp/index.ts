// @deno-types="nodemailer-types"
import nodemailer from "nodemailer";
import { authenticate, corsHeaders, generateCode, hashCode, json, otpError, requiredEnv, validDeviceHash } from "../_shared/otp.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
  try {
    const auth = await authenticate(req);
    if (!auth) return json({ error: { code: "UNAUTHORIZED" } }, 401);
    let body;
    try { body = await req.json(); } catch {
      return json({ error: { code: "INVALID_REQUEST" } }, 400);
    }
    if (!validDeviceHash(body?.device_hash)) {
      return json({ error: { code: "INVALID_REQUEST", message: "device_hash must be a lowercase SHA-256 hex string." } }, 400);
    }
    const transport = nodemailer.createTransport({
      host: "smtp.gmail.com", port: 465, secure: true,
      auth: { user: requiredEnv("SMTP_USERNAME"), pass: requiredEnv("SMTP_PASSWORD") },
      connectionTimeout: 15_000, greetingTimeout: 15_000, socketTimeout: 30_000,
    });
    const from = requiredEnv("SMTP_FROM");
    const challengeId = crypto.randomUUID();
    const code = generateCode();
    const codeHash = await hashCode(challengeId, code);
    const { data, error } = await auth.admin.rpc("issue_device_otp", {
      p_id: challengeId, p_user_id: auth.userId, p_session_id: auth.sessionId,
      p_device_hash: body.device_hash, p_code_hash: codeHash,
    });
    if (error || !data) return json({ error: { code: "OTP_STORAGE_FAILED" } }, 500);
    if (data.error) return otpError(data);
    try {
      const info = await transport.sendMail({
        from, to: auth.email, subject: "Your Filo verification code",
        text: `Your Filo verification code is ${code}. It expires in 10 minutes.`,
      });
      if (!info.accepted?.length) throw new Error("SMTP recipient not accepted");
    } catch {
      await auth.admin.rpc("finish_device_otp_delivery", {
        p_id: challengeId, p_user_id: auth.userId, p_sent: false,
      });
      return json({ error: { code: "OTP_SEND_FAILED", message: "Could not send your code. Try again later." } }, 502);
    } finally { transport.close(); }
    const completion = await auth.admin.rpc("finish_device_otp_delivery", {
      p_id: challengeId, p_user_id: auth.userId, p_sent: true,
    });
    if (completion.error || completion.data !== true) {
      return json({ error: { code: "OTP_STORAGE_FAILED" } }, 500);
    }
    return json(data);
  } catch {
    // Do not return or log credentials, OTPs, tokens, or SMTP errors.
    return json({ error: { code: "INTERNAL_ERROR" } }, 500);
  }
});
