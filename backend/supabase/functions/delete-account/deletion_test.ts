import { createHandler, createRecoveryHandler, Denied, OwnedClasses, processDeletion } from "./deletion.ts";
import type { Failure, Store } from "./deletion.ts";

function assert(ok: unknown, message = "Assertion failed"): asserts ok {
  if (!ok) throw new Error(message);
}
function equal(a: unknown, b: unknown) {
  assert(JSON.stringify(a) === JSON.stringify(b), `Expected ${JSON.stringify(b)}, got ${JSON.stringify(a)}`);
}
const identity = { userId: "student", sessionId: "verified-session" };
const request = (body = "{}", url = "https://example.invalid/delete-account") => new Request(url, {
  method: "POST", headers: { Authorization: "Bearer mock" }, body,
});

function fixture() {
  const calls: string[] = [];
  let pages = [["student/current.png", "student/obsolete.jpg"], ["student/nested/photo.webp"]];
  let busy = false;
  let complete = false;
  let login = true;
  let failure: string | null = null;
  const store: Store = {
    async begin(user, session) {
      calls.push(`begin:${user}:${session}`);
      if (failure === "denied") throw new Denied();
      if (failure === "begin") throw new Error("private database detail");
    },
    async claim(user) {
      calls.push(`claim:${user}`);
      if (complete || busy) return null;
      if (failure === "claim") throw new Error("private database detail");
      busy = true;
      return "lease";
    },
    async nextClass() { calls.push("next-class"); return null; },
    async classFiles() { throw new Error("No class expected"); },
    async purgeClass() { throw new Error("No class expected"); },
    async avatars() {
      calls.push("list");
      if (failure === "list") throw new Error("private path");
      return pages[0] ?? [];
    },
    async remove(bucket, paths) {
      calls.push("remove");
      equal(bucket, "avatars");
      if (failure === "remove") throw new Error("private path");
      equal(paths, pages[0]);
      pages.shift();
    },
    async prepare() {
      calls.push("prepare");
      assert(pages.length === 0, "Auth preparation before avatar removal");
      if (failure === "prepare") throw new Error("private database detail");
    },
    async deleteLogin() {
      calls.push("auth");
      if (failure === "auth") throw new Error("private email");
      login = false;
    },
    async finish() {
      calls.push("finish");
      assert(!login && pages.length === 0);
      if (failure === "finish") throw new Error("private database detail");
      complete = true;
      busy = false;
    },
    async release(_user, _lease, error: Failure) {
      calls.push(`release:${error}`);
      if (failure === "release") throw new Error("private database detail");
      busy = false;
    },
    async pending() { calls.push("pending"); return ["student"]; },
  };
  return { store, calls, fail(value: string | null) { failure = value; },
    pages(value: string[][]) { pages = value; },
    get complete() { return complete; }, get login() { return login; } };
}

Deno.test("self deletion binds to validated identity and completes after all pages/Auth", async () => {
  const f = fixture();
  const response = await createHandler(f.store, async () => identity)(request());
  equal(response.status, 200);
  equal(await response.json(), { status: "deleted" });
  equal(f.calls, ["begin:student:verified-session", "claim:student", "next-class", "list", "remove", "list", "remove",
    "list", "prepare", "auth", "finish"]);
  assert(f.complete);
});

Deno.test("anonymous/invalid/revoked tokens cannot nominate a deletion", async () => {
  const f = fixture();
  const response = await createHandler(f.store, async () => null)(request());
  equal(response.status, 401);
  equal(f.calls, []);
});

Deno.test("unverified and mismatched session denials stop all cleanup", async () => {
  const f = fixture();
  f.fail("denied");
  const response = await createHandler(f.store, async () => identity)(request());
  equal(response.status, 403);
  equal(f.calls, ["begin:student:verified-session"]);
  assert(f.login);
});

Deno.test("target fields, malformed/large bodies and query parameters are refused", async () => {
  for (const body of ['{"user_id":"victim"}', '{"session_id":"other"}', '{"target":"victim"}',
    "null", "[]", "", "{", '"text"', " ".repeat(257) + "{}"] ) {
    const f = fixture();
    equal((await createHandler(f.store, async () => identity)(request(body))).status, 400);
    equal(f.calls, []);
  }
  const f = fixture();
  equal((await createHandler(f.store, async () => identity)(request("{}", "https://example.invalid/delete-account?user_id=victim"))).status, 400);
  equal(f.calls, []);
});

Deno.test("method refusal and preflight do not authorize deletion", async () => {
  const f = fixture();
  const handler = createHandler(f.store, async () => { throw new Error(); });
  equal((await handler(new Request("https://example.invalid", { method: "GET" }))).status, 405);
  equal((await handler(new Request("https://example.invalid", { method: "OPTIONS" }))).status, 200);
  equal(f.calls, []);
});

Deno.test("database acceptance failure returns sanitized unavailable, not pending/success", async () => {
  const f = fixture(); f.fail("begin");
  const response = await createHandler(f.store, async () => identity)(request());
  equal(response.status, 503);
  equal(await response.json(), { error: { code: "UNAVAILABLE" } });
  assert(!f.calls.includes("auth"));
});

for (const [failure, stage] of [["list", "database"], ["remove", "storage"],
  ["prepare", "database"], ["auth", "auth"], ["finish", "database"]]) {
  Deno.test(`${failure} failure stays pending and resumes the same deletion`, async () => {
    const f = fixture(); f.fail(failure);
    const response = await createHandler(f.store, async () => identity)(request());
    equal(response.status, 202);
    equal(await response.json(), { status: "pending" });
    assert(!f.complete);
    assert(f.calls.includes(`release:${stage}`));
    if (["list", "remove", "prepare"].includes(failure)) assert(f.login);
    f.fail(null);
    assert(await processDeletion(f.store, "student"));
    assert(f.complete && !f.login);
  });
}

Deno.test("claim failure and competing request never report completion", async () => {
  const f = fixture(); f.fail("claim");
  assert(!await processDeletion(f.store, "student"));
  f.fail(null);
  const outcomes = await Promise.all([processDeletion(f.store, "student"), processDeletion(f.store, "student")]);
  equal(outcomes.sort(), [false, true]);
  equal(f.calls.filter((call) => call === "auth").length, 1);
});

Deno.test("completed deletion cannot run again and old token is refused", async () => {
  const f = fixture();
  assert(await processDeletion(f.store, "student"));
  assert(!await processDeletion(f.store, "student"));
  equal(f.calls.filter((call) => call === "auth").length, 1);
  equal((await createHandler(f.store, async () => f.login ? identity : null)(request())).status, 401);
});

Deno.test("large folders defer after bounded work, then resume remaining pages", async () => {
  const f = fixture();
  f.pages(Array.from({ length: 9 }, (_, i) => [`student/${i}.png`]));
  assert(!await processDeletion(f.store, "student"));
  assert(f.login && f.calls.includes("release:deferred"));
  assert(await processDeletion(f.store, "student"));
  assert(f.complete);
});

Deno.test("deadline stops cleanup before Auth and leaves retryable work", async () => {
  const f = fixture();
  assert(!await processDeletion(f.store, "student", 0));
  assert(f.login && f.calls.includes("release:deferred"));
});

Deno.test("failed lease release never reports success", async () => {
  const f = fixture(); f.fail("remove");
  const store = { ...f.store, async release() { throw new Error("private database detail"); } };
  assert(!await processDeletion(store, "student"));
  assert(!f.complete && f.login);
});

Deno.test("scheduler rejects missing/wrong secrets and user JWT alone", async () => {
  const f = fixture();
  equal((await createRecoveryHandler(f.store, undefined)(request())).status, 503);
  equal((await createRecoveryHandler(f.store, "scheduler-only")(request())).status, 401);
  equal(f.calls, []);
});

Deno.test("scheduler resumes cleanup without user credentials and returns counts only", async () => {
  const f = fixture();
  const req = new Request("https://example.invalid", { method: "POST", headers: { "x-account-deletion-secret": "scheduler-only" } });
  const response = await createRecoveryHandler(f.store, "scheduler-only")(req);
  equal(response.status, 200);
  equal(await response.json(), { completed: 1, pending: 0 });
  assert(f.complete && !f.calls.some((call) => call.startsWith("begin:")));
});

Deno.test("owned classes returns exact 409/count without cleanup or accepted deletion", async () => {
  for (const count of [1, 2, 5]) {
    const f = fixture();
    const store = { ...f.store, async begin() { throw new OwnedClasses(count); } };
    const response = await createHandler(store, async () => ({ userId: "instructor", sessionId: "verified" }))(request());
    equal(response.status, 409);
    equal(await response.json(), { error: { code: "OWNED_CLASSES_EXIST", count } });
    equal(f.calls, []);
    assert(f.login && !f.complete);
  }
});

Deno.test("instructor without classes follows the same confirmed account cleanup", async () => {
  const f = fixture();
  const response = await createHandler(f.store, async () => ({ userId: "instructor", sessionId: "verified" }))(request());
  equal(response.status, 200);
  equal(await response.json(), { status: "deleted" });
  assert(f.complete && !f.login);
  equal(f.calls[0], "begin:instructor:verified");
});

function classFixture() {
  const f = fixture(); f.pages([]);
  const remaining = ["recent-class", "old-class"];
  const files = new Map(remaining.map((id) => [id, [
    { bucket_id: "banners", name: `${id}/banner.png` },
    { bucket_id: "materials", name: `${id}/nested/file.pdf` },
    { bucket_id: "submissions", name: `${id}/post/student/work.png` },
  ]]));
  let fail: string | null = null;
  const store: Store = { ...f.store,
    async nextClass() { return remaining[0] ?? null; },
    async classFiles(_user, _lease, id) {
      if (fail === "list") throw new Error();
      return files.get(id) ?? [];
    },
    async remove(bucket, paths) {
      if (bucket === "avatars") return f.store.remove(bucket, paths);
      f.calls.push(`class-remove:${bucket}`);
      if (fail === bucket) throw new Error();
      const id = remaining[0];
      files.set(id, (files.get(id) ?? []).filter((file) => !paths.includes(file.name)));
    },
    async purgeClass(_user, _lease, id) {
      if (fail === "purge") throw new Error();
      equal(files.get(id), []);
      equal(remaining.shift(), id);
      f.calls.push(`purge:${id}`);
    },
    async prepare(user, lease) { equal(remaining, []); await f.store.prepare(user, lease); },
  };
  return { f, store, fail(value: string | null) { fail = value; } };
}

Deno.test("instructor classes purge all three buckets before Auth deletion", async () => {
  const { f, store } = classFixture();
  assert(await processDeletion(store, "instructor"));
  equal(f.calls.filter((call) => call.startsWith("class-remove:") || call.startsWith("purge:")), [
    "class-remove:banners", "class-remove:materials", "class-remove:submissions", "purge:recent-class",
    "class-remove:banners", "class-remove:materials", "class-remove:submissions", "purge:old-class",
  ]);
  assert(f.calls.indexOf("auth") > f.calls.indexOf("purge:old-class"));
});

for (const failure of ["list", "banners", "materials", "submissions", "purge"]) {
  Deno.test(`class ${failure} failure preserves login and resumes remaining cleanup`, async () => {
    const { f, store, fail } = classFixture(); fail(failure);
    assert(!await processDeletion(store, "instructor"));
    assert(f.login && !f.complete && !f.calls.includes("auth"));
    fail(null);
    assert(await processDeletion(store, "instructor"));
    assert(f.complete);
  });
}
