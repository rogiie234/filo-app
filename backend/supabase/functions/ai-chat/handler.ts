import { authenticate, corsHeaders, isUuid, json } from "../_shared/otp.ts";
import { answerResult, bounded, ChatError, errors, fail, generate, readLimited, validateInput } from "./chat.ts";
import type { ErrorCode, Result } from "./chat.ts";

const DEV_URL = "https://fiobwfzmqcffbpixzvbq.supabase.co";
interface Dependencies {
  authenticate: typeof authenticate;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
}
export function createHandler(overrides: Partial<Dependencies> = {}) {
  const deps: Dependencies = { authenticate, env: (name) => Deno.env.get(name), fetch, ...overrides };
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
    if (request.method !== "POST") return json({ error: { code: "INVALID_REQUEST", message: "Use POST for this request." } }, 405);
    let auth: Awaited<ReturnType<typeof authenticate>> = null;
    let logId: string | null = null;
    let failure: ErrorCode | null = null;
    let result: Result | undefined;
    try {
      auth = await bounded(deps.authenticate(request), 8000, "AI_UNAVAILABLE");
      if (!auth) fail("NOT_ALLOWED");
      const { admin, userId, sessionId } = auth;
      const session = await admin.from("verified_sessions").select("session_id")
        .eq("session_id", sessionId).eq("user_id", userId).abortSignal(AbortSignal.timeout(5000)).maybeSingle();
      if (session.error) fail("AI_UNAVAILABLE");
      if (!session.data) fail("NOT_ALLOWED");
      const profile = await admin.from("profiles").select("role,deleted_at")
        .eq("id", userId).abortSignal(AbortSignal.timeout(5000)).maybeSingle();
      if (profile.error) fail("AI_UNAVAILABLE");
      if (!profile.data || profile.data.role !== "student" || profile.data.deleted_at !== null) fail("NOT_ALLOWED");

      let body: unknown;
      try {
        body = JSON.parse(await bounded(readLimited(request, 524288, "TOO_LARGE", AbortSignal.timeout(5000)), 5000, "INVALID_REQUEST"));
      } catch (error) {
        if (error instanceof ChatError) throw error;
        fail("INVALID_REQUEST");
      }
      const input = validateInput(body);
      const begin = await admin.rpc("begin_ai_request", { p_user: userId, p_kind: input.mode })
        .abortSignal(AbortSignal.timeout(5000));
      if (begin.error) fail("AI_UNAVAILABLE");
      if (begin.data === null) fail("AI_IN_PROGRESS");
      if (typeof begin.data !== "string" || !isUuid(begin.data)) fail("AI_UNAVAILABLE");
      logId = begin.data;

      const testMode = deps.env("AI_TEST_MODE") ?? "off";
      if (testMode !== "off" && testMode !== "") {
        if (deps.env("SUPABASE_URL") !== DEV_URL) fail("AI_UNAVAILABLE");
        if (testMode === "sample") {
          result = answerResult(input.mode === "summary"
            ? "DEV sample summary.\nMain ideas:\n- This is a fixed sample, not a summary of your files."
            : "DEV sample answer. This is a fixed sample, not an answer based on your question or files.", input);
        } else if (testMode === "unexpected") {
          throw new Error("DEV simulated unexpected failure");
        } else if (Object.hasOwn(errors, testMode)) {
          fail(testMode as ErrorCode);
        } else fail("AI_UNAVAILABLE");
      } else {
        result = await generate(input, deps.env("GEMINI_API_KEY") ?? "", deps.env("GEMINI_MODEL") ?? "", deps.fetch);
      }
    } catch (error) {
      failure = error instanceof ChatError ? error.code : "AI_UNAVAILABLE";
    } finally {
      if (logId && auth) {
        let finished = false;
        // Repeat the idempotent metadata-only update once if finalization is not confirmed.
        for (let attempt = 0; attempt < 2 && !finished; attempt++) {
          try {
            const finish = await auth.admin.rpc("finish_ai_request", {
              p_id: logId, p_status: failure ? "failed" : "success", p_error: failure,
            }).abortSignal(AbortSignal.timeout(5000));
            finished = !finish.error;
          } catch { /* Return a sanitized error when bookkeeping cannot be confirmed. */ }
        }
        if (!finished) failure = "AI_UNAVAILABLE";
      }
    }
    if (failure) {
      const [status, message] = errors[failure];
      return json({ error: { code: failure, message } }, status);
    }
    return json(result);
  };
}
