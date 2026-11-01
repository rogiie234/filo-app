import { createHandler } from "./push.ts";
import type { Notice, Outcome, Sender, Store, Token } from "./push.ts";
import { classify, createFcm } from "./fcm.ts";
function assert(x: unknown, message = "Assertion failed"): asserts x { if (!x) throw new Error(message); }
function equal(a: unknown, b: unknown) { assert(JSON.stringify(a) === JSON.stringify(b), `${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
const secret = "synthetic-webhook-secret-at-least-32-characters";
const notice: Notice = { id: "11111111-1111-4111-8111-111111111111", recipient_id: "recipient",
  type: "announcement", class_id: "class", title: "Stored title", body: "Stored body",
  target_type: "post", target_id: "post" };
const token = (id: string, user = "recipient"): Token => ({ id, user_id: user, fcm_token: `synthetic-${id}`, registration_version: "v1" });
const event = (changes = {}) => ({ type: "INSERT", schema: "public", table: "notifications",
  record: { id: notice.id, recipient_id: "forged", title: "Forged title" }, old_record: null, ...changes });
function request(body: unknown = event(), key: string | null = secret, method = "POST", headers = {}) {
  return new Request("https://example.test/send-push", { method,
    headers: { ...(key ? { "x-push-secret": key } : {}), ...headers },
    ...(method === "POST" ? { body: JSON.stringify(body) } : {}) });
}
function fixture() {
  const state = { notice: structuredClone(notice) as Notice | null, tokens: [token("one"), token("two")],
    settings: [] as { class_id: string | null; type: string; enabled: boolean }[],
    claims: new Set<string>(), results: [] as string[], removed: [] as string[], sent: [] as string[],
    prepare: 0, storeCalls: 0, failClaim: false, failFinish: false, failCleanup: false,
    outcome: { status: "sent" } as Outcome, special: {} as Record<string, Outcome | "throw"> };
  const store: Store = {
    async notice() { state.storeCalls++; return state.notice; },
    async muted(n) { return state.settings.some((s) => s.type === n.type && !s.enabled && (s.class_id === null || s.class_id === n.class_id)); },
    async tokens() { return state.tokens; },
    async claim(n, t) {
      if (state.failClaim) throw new Error("store");
      if (t.registration_version !== "v1") return "stale";
      if (await store.muted(n)) return "muted";
      const id = n.id + t.id;
      if (state.claims.has(id)) return "duplicate";
      state.claims.add(id); return "claimed";
    },
    async finish(_n, t, result, error) { if (state.failFinish) throw new Error("store"); state.results.push(t.id + ":" + result.status + ":" + (error ?? "")); },
    async remove(t) { if (state.failCleanup) throw new Error("cleanup"); state.removed.push(t.id); },
  };
  const sender: Sender = { async prepare() { state.prepare++; }, async send(n, t) {
    equal(n, notice); state.sent.push(t.id);
    const special = state.special[t.id];
    if (special === "throw") throw new Error("transport");
    return special ?? state.outcome;
  } };
  return { state, store, sender, handle: createHandler(secret, store, sender) };
}
Deno.test("auth: missing/wrong secret and user/service JWTs do not touch storage", async () => {
  const f = fixture();
  for (const key of [null, "wrong"]) for (const jwt of ["user-jwt", "service-jwt"]) {
    equal((await f.handle(request(event(), key, "POST", { authorization: `Bearer ${jwt}` }))).status, 401);
  }
  equal(f.state.storeCalls, 0); equal(f.state.sent, []);
  equal((await f.handle(request(event(), secret, "GET"))).status, 405);
  equal((await createHandler(undefined, f.store, f.sender)(request())).status, 503);
});
Deno.test("envelope rejects malformed, oversized and non-insert events", async () => {
  const f = fixture();
  for (const body of [null, {}, event({ type: "UPDATE" }), event({ type: "DELETE" }),
    event({ table: "profiles" }), event({ schema: "other" }), event({ record: { id: "bad" } }),
    event({ old_record: {} }), event({ padding: "x".repeat(65536) })]) {
    equal((await f.handle(request(body))).status, 400);
  }
  equal((await f.handle(new Request("https://example.test", { method: "POST", headers: { "x-push-secret": secret }, body: "{" }))).status, 400);
  equal(f.state.storeCalls, 0);
});
Deno.test("fanout uses persisted notification, recipient-only phones and no inbox mutation", async () => {
  const f = fixture(); f.state.tokens.push(token("foreign", "other"));
  const result = await (await f.handle(request())).json();
  equal(result.sent, 2); equal(result.skipped, 1); equal(f.state.sent.sort(), ["one", "two"]);
  equal(f.state.notice, notice); equal(f.state.removed, []);
});
Deno.test("mute OR rule: global/class off wins; other type/class and explicit on do not mute", async () => {
  for (const settings of [
    [{ class_id: null, type: "announcement", enabled: false }],
    [{ class_id: "class", type: "announcement", enabled: false }],
    [{ class_id: null, type: "announcement", enabled: false }, { class_id: "class", type: "announcement", enabled: true }],
    [{ class_id: null, type: "announcement", enabled: true }, { class_id: "class", type: "announcement", enabled: false }],
  ]) {
    const f = fixture(); f.state.settings = settings;
    equal((await (await f.handle(request())).json()).outcome, "muted");
    equal(f.state.prepare, 0); equal(f.state.sent, []); equal(f.state.notice, notice);
  }
  const f = fixture(); f.state.settings = [
    { class_id: "other", type: "announcement", enabled: false },
    { class_id: null, type: "material", enabled: false }];
  equal((await (await f.handle(request())).json()).sent, 2);
});
Deno.test("missing inbox/no phones skip FCM without changing inbox", async () => {
  const f = fixture(); f.state.notice = null;
  equal((await (await f.handle(request())).json()).outcome, "missing");
  f.state.notice = structuredClone(notice); f.state.tokens = [];
  equal((await (await f.handle(request())).json()).outcome, "no_tokens"); equal(f.state.prepare, 0);
});
Deno.test("duplicate and concurrent webhook invocations claim each phone once", async () => {
  const f = fixture(); await Promise.all([f.handle(request()), f.handle(request())]);
  await f.handle(request()); equal(f.state.sent.sort(), ["one", "two"]); equal(f.state.claims.size, 2);
});
Deno.test("stale registration skipped; cleanup gets captured version, not new ownership", async () => {
  const f = fixture(); f.state.tokens[1].registration_version = "v2";
  f.state.outcome = { status: "invalid_token" };
  let captured: Token | undefined;
  f.store.remove = async (t) => { captured = structuredClone(t); };
  await f.handle(request()); equal(f.state.sent, ["one"]); equal(captured?.registration_version, "v1");
});
Deno.test("mixed delivery results clean only invalid tokens, retain inbox and do not resend failures", async () => {
  const f = fixture(); f.state.tokens.push(token("three"), token("four"));
  f.state.special = { two: { status: "invalid_token" }, three: { status: "failed", error: "timeout" }, four: "throw" };
  const result = await (await f.handle(request())).json();
  equal([result.sent, result.invalid_token, result.failed], [1, 1, 2]); equal(f.state.removed, ["two"]);
  equal(f.state.notice, notice); await f.handle(request()); equal(f.state.sent.length, 4);
});
Deno.test("claim/config/storage and cleanup failures retain inbox and suppress unsafe resends", async () => {
  const f = fixture(); f.state.failClaim = true;
  equal((await f.handle(request())).status, 500); equal(f.state.sent.length, 0);
  f.state.failClaim = false; f.state.failCleanup = true; f.state.failFinish = true;
  f.state.outcome = { status: "invalid_token" };
  equal((await f.handle(request())).status, 500); equal(f.state.notice, notice);
  await f.handle(request()); equal(f.state.sent.length, 2);
  const g = fixture(); g.sender.prepare = async () => { throw new Error("config"); };
  equal((await g.handle(request())).status, 503); equal(g.state.claims.size, 0); equal(g.state.notice, notice);
});
const fcmError = (code: string, message = "", extra: unknown[] = []) => ({ error: { message, details: [
  { "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", errorCode: code }, ...extra] } });
Deno.test("FCM cleanup classification requires definitive token evidence", () => {
  equal(classify(200, { name: "projects/test/messages/1" }).status, "sent");
  equal(classify(404, fcmError("UNREGISTERED")).status, "invalid_token");
  equal(classify(400, fcmError("INVALID_ARGUMENT", "The registration token is not a valid FCM registration token")).status, "invalid_token");
  for (const [status, body] of [[400, fcmError("INVALID_ARGUMENT", "Invalid message payload")],
    [404, {}], [401, fcmError("UNAUTHENTICATED")], [403, fcmError("SENDER_ID_MISMATCH")],
    [429, fcmError("QUOTA_EXCEEDED")], [500, fcmError("INTERNAL")], [503, fcmError("UNAVAILABLE")], [200, {}]] as const) {
    equal(classify(status, body).status, "failed");
  }
});
Deno.test("native OAuth JWT and HTTP v1 payload use fixed endpoints and cached access token", async () => {
  const keys = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", keys.privateKey));
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...der))}\n-----END PRIVATE KEY-----`;
  let oauth = 0; let sends = 0;
  const http: typeof fetch = async (input, init) => {
    if (String(input) === "https://oauth2.googleapis.com/token") {
      oauth++;
      const jwt = new URLSearchParams(String(init?.body)).get("assertion")!.split(".");
      const bytes = Uint8Array.from(atob(jwt[2].replaceAll("-", "+").replaceAll("_", "/")), (c) => c.charCodeAt(0));
      assert(await crypto.subtle.verify("RSASSA-PKCS1-v1_5", keys.publicKey, bytes, new TextEncoder().encode(jwt[0] + "." + jwt[1])));
      return Response.json({ access_token: "synthetic-access", expires_in: 3600 });
    }
    equal(String(input), "https://fcm.googleapis.com/v1/projects/test-project/messages:send"); sends++;
    const payload = JSON.parse(String(init?.body));
    equal(payload.message.notification, { title: notice.title, body: notice.body });
    equal(payload.message.data.notification_id, notice.id); equal(payload.message.token, "synthetic-one");
    return Response.json({ name: "projects/test-project/messages/1" });
  };
  const sender = createFcm(JSON.stringify({ project_id: "test-project", client_email: "synthetic@example.test", private_key: pem }), http);
  await sender.prepare(); await sender.prepare();
  equal((await sender.send(notice, token("one"))).status, "sent"); equal([oauth, sends], [1, 1]);
});
Deno.test("FCM transport/timeout failures preserve token eligibility", async () => {
  for (const error of [new DOMException("timeout", "TimeoutError"), new Error("network")]) {
    const sender = createFcm(undefined, () => Promise.reject(error));
    equal((await sender.send(notice, token("one"))).status, "failed");
  }
});
