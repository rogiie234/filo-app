import { isUuid } from "./otp.ts";

export const DEV_URL = "https://fiobwfzmqcffbpixzvbq.supabase.co";
export const HOLD_MS = 12000;
type Event = "request" | "acquired" | "provider_attempt" | "provider_settled" | "complete";

// DEV metadata only: never pass request bodies, user identity or exception text here.
export function devTrace(request: Request, endpoint: string, env: (name: string) => string | undefined,
  emit: (message: string) => void = console.log) {
  const enabled = env("SUPABASE_URL") === DEV_URL && env("AI_DEV_TRACE") === "on";
  const supplied = request.headers.get("x-filo-ai-test-id") ?? "";
  const id = isUuid(supplied) ? supplied : crypto.randomUUID();
  function event(event: Event, logId: string | null = null, error: string | null = null) {
    if (enabled) emit(JSON.stringify({ tag: "filo_ai_dev_v1", request_id: id, endpoint, event, log_id: logId, error }));
  }
  event("request");
  return {
    event,
    fetch(fetcher: typeof fetch): typeof fetch {
      return async (url, init) => {
        event("provider_attempt");
        try { return await fetcher(url, init); }
        finally { event("provider_settled"); }
      };
    },
    response(response: Response, logId: string | null, error: string | null) {
      event("complete", logId, error);
      if (enabled) {
        response.headers.set("x-filo-ai-test-id", id);
        const mode = env("AI_TEST_MODE") || "off";
        response.headers.set("x-filo-ai-test-mode", ["off", "sample", "hold", "unexpected", "AI_BUSY", "AI_TIMEOUT", "AI_BAD_OUTPUT", "AI_BLOCKED", "AI_UNAVAILABLE", "NOT_ALLOWED", "INVALID_REQUEST", "NO_TEXT", "TOO_LARGE", "AI_IN_PROGRESS"].includes(mode) ? mode : "invalid");
        if (logId) response.headers.set("x-filo-ai-log-id", logId);
      }
      return response;
    },
  };
}
