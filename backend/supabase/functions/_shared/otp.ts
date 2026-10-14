import { createClient } from "@supabase/supabase-js";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status,
    headers: { ...corsHeaders, "Content-Type": "application/json" } });
}
export function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing configuration: ${name}`);
  return value;
}
export function adminClient() {
  const secrets = Deno.env.get("SUPABASE_SECRET_KEYS");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    (secrets ? JSON.parse(secrets).default : undefined);
  if (!key) throw new Error("Missing backend database key");
  return createClient(requiredEnv("SUPABASE_URL"), key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}
export async function authenticate(req: Request) {
  const match = req.headers.get("Authorization")?.match(/^Bearer\s+(\S+)$/i);
  if (!match) return null;
  const token = match[1];
  const admin = adminClient();
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user?.email) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const encoded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = encoded.padEnd(Math.ceil(encoded.length / 4) * 4, "=");
    const bytes = Uint8Array.from(atob(padded), (c) => c.charCodeAt(0));
    // getUser validated this token before its claims are read.
    const claims = JSON.parse(new TextDecoder().decode(bytes));
    if (claims.sub !== data.user.id || typeof claims.session_id !== "string" ||
      !isUuid(claims.session_id) || typeof claims.exp !== "number" ||
      claims.exp <= Date.now() / 1000) return null;
    return { admin, userId: data.user.id, email: data.user.email,
      sessionId: claims.session_id as string };
  } catch { return null; }
}
export function validDeviceHash(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
}
export function generateCode(): string {
  const values = new Uint32Array(1);
  do { crypto.getRandomValues(values); } while (values[0] >= 4_294_000_000);
  return String(values[0] % 1_000_000).padStart(6, "0");
}
export async function hashCode(challengeId: string, code: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", encoder.encode(requiredEnv("OTP_HASH_SECRET")),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(`${challengeId}:${code}`));
  return Array.from(new Uint8Array(signature)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
export function otpError(result: { error: string; retry_after?: number; attempts_remaining?: number }) {
  const statuses: Record<string, number> = {
    INVALID_REQUEST: 400, USER_NOT_FOUND: 401, OTP_WRONG: 400,
    OTP_EXPIRED: 410, OTP_LOCKED: 429, OTP_RESEND_TOO_SOON: 429,
    OTP_USED: 409, OTP_NOT_READY: 409,
  };
  return json({ error: { code: result.error },
    ...(result.retry_after !== undefined ? { retry_after: result.retry_after } : {}),
    ...(result.attempts_remaining !== undefined ? { attempts_remaining: result.attempts_remaining } : {}),
  }, statuses[result.error] ?? 500);
}
