export type Notice = {
  id: string; recipient_id: string; class_id: string | null; type: string;
  title: string; body: string | null; target_type: string | null; target_id: string | null;
};
export type Token = { id: string; user_id: string; fcm_token: string; registration_version: string };
export type Outcome = { status: "sent" | "invalid_token" | "failed"; error?: "provider" | "timeout" | "transport" };
export interface Store {
  notice(id: string): Promise<Notice | null>;
  muted(n: Notice): Promise<boolean>;
  tokens(user: string): Promise<Token[]>;
  claim(n: Notice, t: Token): Promise<string>;
  finish(n: Notice, t: Token, result: Outcome, error?: "cleanup"): Promise<void>;
  remove(t: Token): Promise<void>;
}
export interface Sender { prepare(): Promise<void>; send(n: Notice, t: Token): Promise<Outcome> }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function sameSecret(expected: string, actual: string) {
  const digest = async (s: string) => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
  const [a, b] = await Promise.all([digest(expected), digest(actual)]);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0;
}
async function envelope(req: Request): Promise<string> {
  if (Number(req.headers.get("content-length")) > 65536) throw new Error("body");
  const reader = req.body?.getReader();
  if (!reader) throw new Error("body");
  const chunks: Uint8Array[] = []; let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 65536) throw new Error("body");
      chunks.push(value);
    }
  } finally { await reader.cancel(); reader.releaseLock(); }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  const x = JSON.parse(new TextDecoder().decode(bytes));
  if (x?.type !== "INSERT" || x?.schema !== "public" || x?.table !== "notifications" ||
    x.old_record !== null || typeof x.record?.id !== "string" || !uuid.test(x.record.id)) throw new Error("event");
  return x.record.id;
}
export function createHandler(secret: string | undefined, store: Store, sender: Sender) {
  return async (req: Request): Promise<Response> => {
    const reply = (data: unknown, status = 200) => Response.json(data, { status });
    if (req.method !== "POST") return reply({ error: "POST required" }, 405);
    if (!secret || secret.length < 32) return reply({ error: "Webhook not configured" }, 503);
    if (!await sameSecret(secret, req.headers.get("x-push-secret") ?? "")) return reply({ error: "Unauthorized" }, 401);
    let id: string;
    try { id = await envelope(req); } catch { return reply({ error: "Invalid notification INSERT event" }, 400); }
    try {
      const n = await store.notice(id);
      if (!n) return reply({ outcome: "missing", attempted: 0 });
      if (await store.muted(n)) return reply({ outcome: "muted", attempted: 0 });
      const tokens = await store.tokens(n.recipient_id);
      if (!tokens.length) return reply({ outcome: "no_tokens", attempted: 0 });
      await sender.prepare();
      const counts = { attempted: 0, sent: 0, invalid_token: 0, failed: 0, skipped: 0, record_errors: 0 };
      // Bounded parallelism keeps one failed phone from blocking other phones.
      for (let start = 0; start < tokens.length; start += 5) {
        await Promise.all(tokens.slice(start, start + 5).map(async (t) => {
          if (t.user_id !== n.recipient_id) { counts.skipped++; return; }
          let claimed: string;
          try { claimed = await store.claim(n, t); }
          catch { counts.record_errors++; return; }
          if (claimed !== "claimed") { counts.skipped++; return; }
          counts.attempted++;
          let outcome: Outcome;
          try { outcome = await sender.send(n, t); }
          catch { outcome = { status: "failed", error: "transport" }; }
          counts[outcome.status]++;
          let cleanup: "cleanup" | undefined;
          if (outcome.status === "invalid_token") {
            try { await store.remove(t); } catch { cleanup = "cleanup"; counts.record_errors++; }
          }
          try { await store.finish(n, t, outcome, cleanup); }
          catch { counts.record_errors++; }
        }));
      }
      return reply({ outcome: "processed", ...counts }, counts.record_errors ? 500 : 200);
    } catch { return reply({ error: "Push processing unavailable; inbox retained" }, 503); }
  };
}
