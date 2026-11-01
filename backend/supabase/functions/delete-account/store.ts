import { adminClient } from "../_shared/otp.ts";
import { Denied } from "./deletion.ts";
import type { Store } from "./deletion.ts";

export function createStore(db = adminClient((input, init) => fetch(input, {
  ...init,
  signal: init?.signal
    ? AbortSignal.any([init.signal, AbortSignal.timeout(10000)])
    : AbortSignal.timeout(10000),
}))): Store {
  async function rpc(name: string, args: Record<string, unknown>) {
    const { data, error } = await db.rpc(name, args).abortSignal(AbortSignal.timeout(10000));
    if (error) {
      if (error.code === "42501") throw new Denied();
      throw new Error("Deletion database unavailable");
    }
    return data;
  }
  return {
    async begin(user, session) { await rpc("begin_student_account_deletion", { p_user: user, p_session: session }); },
    async claim(user) { return await rpc("claim_account_deletion", { p_user: user }); },
    async avatars(user, lease) {
      const rows = await rpc("list_account_avatars", { p_user: user, p_lease: lease });
      return rows.map((row: { name: string }) => row.name);
    },
    async remove(paths) {
      const { error } = await db.storage.from("avatars").remove(paths);
      if (error) throw new Error("Deletion storage unavailable");
    },
    async prepare(user, lease) { await rpc("prepare_account_auth_deletion", { p_user: user, p_lease: lease }); },
    async deleteLogin(user) {
      const { error } = await db.auth.admin.deleteUser(user, false);
      // A prior attempt may have deleted Auth but lost its response.
      if (error && error.code !== "user_not_found") throw new Error("Deletion auth unavailable");
    },
    async finish(user, lease) { await rpc("finish_account_deletion", { p_user: user, p_lease: lease }); },
    async release(user, lease, error) {
      await rpc("release_account_deletion", { p_user: user, p_lease: lease, p_error: error });
    },
    async pending() {
      const { data, error } = await db.from("account_deletions").select("user_id")
        .is("completed_at", null).or(`lease_until.is.null,lease_until.lt.${new Date().toISOString()}`)
        .order("attempted_at", { nullsFirst: true }).order("requested_at")
        .limit(10).abortSignal(AbortSignal.timeout(10000));
      if (error) throw new Error("Deletion database unavailable");
      return (data ?? []).map((row) => row.user_id as string);
    },
  };
}
