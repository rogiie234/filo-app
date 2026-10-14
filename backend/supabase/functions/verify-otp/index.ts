import { authenticate, corsHeaders, hashCode, isUuid, json, otpError, validDeviceHash } from "../_shared/otp.ts";

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
    if (typeof body?.challenge_id !== "string" || !isUuid(body.challenge_id) ||
      typeof body?.code !== "string" || !/^\d{6}$/.test(body.code) ||
      !validDeviceHash(body?.device_hash)) {
      return json({ error: { code: "INVALID_REQUEST",
        message: "Provide a challenge_id, six-digit code string, and lowercase SHA-256 device_hash." } }, 400);
    }
    // Canonicalize the UUID to match the identifier used when hashing at issuance.
    const challengeId = body.challenge_id.toLowerCase();
    const codeHash = await hashCode(challengeId, body.code);
    const { data, error } = await auth.admin.rpc("verify_device_otp", {
      p_id: challengeId, p_user_id: auth.userId, p_session_id: auth.sessionId,
      p_device_hash: body.device_hash, p_code_hash: codeHash,
    });
    if (error || !data) return json({ error: { code: "OTP_STORAGE_FAILED" } }, 500);
    if (data.error) return otpError(data);
    if (data.verified !== true) return json({ error: { code: "OTP_STORAGE_FAILED" } }, 500);
    return json({ verified: true });
  } catch {
    return json({ error: { code: "INTERNAL_ERROR" } }, 500);
  }
});