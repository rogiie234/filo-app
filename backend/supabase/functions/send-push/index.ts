import { createClient } from "@supabase/supabase-js";
import { createHandler } from "./push.ts";
import type { Store, Token } from "./push.ts";
import { createFcm } from "./fcm.ts";
const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false },
    global: { fetch: (input, init) => fetch(input, { ...init, signal: AbortSignal.timeout(10000) }) } });
function checked<T>(result: { data: T; error: unknown }): T {
  if (result.error) throw new Error("Push store unavailable");
  return result.data;
}
const store: Store = {
  async notice(id) {
    return checked(await db.from("notifications")
      .select("id,recipient_id,class_id,type,title,body,target_type,target_id").eq("id", id).maybeSingle());
  },
  async muted(n) {
    const rows = checked(await db.from("notification_settings").select("class_id")
      .eq("user_id", n.recipient_id).eq("type", n.type).eq("enabled", false)
      .or(n.class_id ? `class_id.is.null,class_id.eq.${n.class_id}` : "class_id.is.null").limit(1));
    return !!rows?.length;
  },
  async tokens(user) {
    const rows: Token[] = []; let after: string | undefined;
    while (true) {
      let query = db.from("device_tokens").select("id,user_id,fcm_token,registration_version")
        .eq("user_id", user).order("id").limit(200);
      if (after) query = query.gt("id", after);
      const page = checked(await query) ?? [];
      rows.push(...page);
      if (page.length < 200) return rows;
      after = page[page.length - 1].id;
    }
  },
  async claim(n, t) {
    return checked(await db.rpc("claim_push_delivery", { p_notification: n.id,
      p_token: t.id, p_user: t.user_id, p_version: t.registration_version }));
  },
  async finish(n, t, result, error) {
    checked(await db.from("push_deliveries").update({ status: result.status,
      error_code: error ?? result.error ?? null, finished_at: new Date().toISOString() })
      .eq("notification_id", n.id).eq("token_id", t.id).eq("status", "claimed"));
  },
  async remove(t) {
    checked(await db.rpc("delete_invalid_push_token", { p_token: t.id, p_user: t.user_id,
      p_version: t.registration_version }));
  },
};
Deno.serve(createHandler(Deno.env.get("PUSH_WEBHOOK_SECRET"), store,
  createFcm(Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON"))));
