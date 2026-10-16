import { createClient } from "npm:@supabase/supabase-js@2";

// No user JWT is accepted: only the dedicated scheduler secret authorizes purge.
Deno.serve(async (req) => {
  const reply = (body: unknown, status = 200) =>
    Response.json(body, { status });
  if (req.method !== "POST") return reply({ error: "POST required" }, 405);
  const secret = Deno.env.get("PURGE_DELETED_SECRET");
  if (!secret) return reply({ error: "Scheduler secret missing" }, 503);
  const supplied = req.headers.get("x-purge-secret") ?? "";
  const hash = async (value: string) => new Uint8Array(
    await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)),
  );
  const [expected, actual] = await Promise.all([hash(secret), hash(supplied)]);
  let difference = 0;
  for (let i = 0; i < expected.length; i++) difference |= expected[i] ^ actual[i];
  if (difference !== 0) return reply({ error: "Unauthorized" }, 401);

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const started = Date.now();
  const expiredBefore = new Date(started - 14 * 86400000).toISOString();
  const { data: classes, error } = await db.from("classes")
    .select("id").lt("deleted_at", expiredBefore)
    .order("deleted_at").order("id").limit(25);
  if (error) return reply({ error: "Could not load expired classes" }, 500);
  const purged: string[] = [];
  const failed: string[] = [];
  let deferred = false;
  for (const entry of classes ?? []) {
    if (Date.now() - started > 90000) { deferred = true; break; }
    try {
      // Read metadata recursively by prefix, including unreferenced uploads.
      // Always take the first page: successful Storage API deletes shrink it.
      while (true) {
        if (Date.now() - started > 90000) { deferred = true; break; }
        const { data: files, error: listError } = await db.rpc(
          "list_deleted_class_files", { p_class: entry.id },
        );
        if (listError) throw listError;
        if (!files?.length) break;
        for (const bucket of ["banners", "materials", "submissions"]) {
          const paths = files.filter((f: { bucket_id: string }) => f.bucket_id === bucket)
            .map((f: { name: string }) => f.name);
          if (!paths.length) continue;
          const { error: removeError } = await db.storage.from(bucket).remove(paths);
          if (removeError) throw removeError;
        }
      }
      if (deferred) break;
      const { data: removed, error: deleteError } = await db.rpc(
        "finish_deleted_class_purge", { p_class: entry.id },
      );
      if (deleteError) throw deleteError;
      if (removed) purged.push(entry.id);
    } catch (error) {
      failed.push(entry.id);
      console.error("Class purge failed; retained for retry", entry.id, error);
    }
  }
  return reply({ purged, failed, deferred, batchLimit: 25 }, failed.length ? 500 : 200);
});
