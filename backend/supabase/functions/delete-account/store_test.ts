import { createClient } from "@supabase/supabase-js";
import { createStore } from "./store.ts";
import { Denied } from "./deletion.ts";

function assert(ok: unknown, message = "Assertion failed"): asserts ok {
  if (!ok) throw new Error(message);
}
function db(fetcher: typeof fetch) {
  return createClient("https://example.invalid", "fake-service-key", {
    auth: { persistSession: false, autoRefreshToken: false }, global: { fetch: fetcher },
  });
}

Deno.test("adapter forwards only token-derived account/session to the server-only begin RPC", async () => {
  const store = createStore(db(async (input, init) => {
    const req = new Request(input, init);
    assert(req.url.endsWith("/rest/v1/rpc/begin_student_account_deletion"));
    const body = await req.json();
    assert(body.p_user === "student" && body.p_session === "session" && Object.keys(body).length === 2);
    return Response.json(null);
  }));
  await store.begin("student", "session");
});

Deno.test("adapter converts only SQLSTATE 42501 to a permission denial", async () => {
  for (const code of ["42501", "XX000"]) {
    const store = createStore(db(async () => Response.json({ code, message: "private database detail" }, { status: 403 })));
    let caught: unknown;
    try { await store.begin("student", "session"); } catch (error) { caught = error; }
    assert(caught instanceof Error && (caught instanceof Denied) === (code === "42501"));
    assert(!caught.message.includes("private"));
  }
});

Deno.test("adapter deletes avatar bytes via Storage API, never direct metadata DELETE", async () => {
  const store = createStore(db(async (input, init) => {
    const req = new Request(input, init);
    assert(req.method === "DELETE" && req.url.endsWith("/storage/v1/object/avatars"));
    const body = await req.json();
    assert(JSON.stringify(body.prefixes) === JSON.stringify(["student/old.png", "student/nested/new.png"]));
    return Response.json([]);
  }));
  await store.remove(["student/old.png", "student/nested/new.png"]);
});

Deno.test("adapter tolerates already-missing Auth only, other deletion failures remain failures", async () => {
  const user = "a371c882-042f-4b75-9c51-31d65b6fc961";
  for (const code of ["user_not_found", "unexpected_failure"]) {
    const store = createStore(db(async (input, init) => {
      const req = new Request(input, init);
      assert(req.method === "DELETE" && req.url.endsWith(`/auth/v1/admin/users/${user}`));
      return Response.json({ code, msg: "private email" }, { status: code === "user_not_found" ? 404 : 500,
        headers: { "X-Supabase-Api-Version": "2024-01-01" } });
    }));
    let caught: unknown;
    try { await store.deleteLogin(user); } catch (error) { caught = error; }
    assert(code === "user_not_found" ? !caught : caught instanceof Error);
  }
});

Deno.test("recovery selection filters completed/leased jobs and bounds work", async () => {
  const store = createStore(db(async (input, init) => {
    const url = new URL(new Request(input, init).url);
    assert(url.pathname.endsWith("/account_deletions"));
    assert(url.searchParams.get("completed_at") === "is.null");
    assert(url.searchParams.get("or")?.includes("lease_until.is.null"));
    assert(url.searchParams.get("limit") === "10");
    assert(url.searchParams.get("order")?.includes("attempted_at"));
    return Response.json([{ user_id: "student" }]);
  }));
  assert(JSON.stringify(await store.pending()) === '["student"]');
});
