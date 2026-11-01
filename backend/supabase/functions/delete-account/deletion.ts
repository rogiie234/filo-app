import { json } from "../_shared/otp.ts";

export type Failure = "storage" | "auth" | "database" | "deferred";
export interface Store {
  begin(user: string, session: string): Promise<void>;
  claim(user: string): Promise<string | null>;
  nextClass(user: string, lease: string): Promise<string | null>;
  classFiles(user: string, lease: string, classId: string): Promise<{ bucket_id: string; name: string }[]>;
  purgeClass(user: string, lease: string, classId: string): Promise<void>;
  avatars(user: string, lease: string): Promise<string[]>;
  remove(bucket: string, paths: string[]): Promise<void>;
  prepare(user: string, lease: string): Promise<void>;
  deleteLogin(user: string): Promise<void>;
  finish(user: string, lease: string): Promise<void>;
  release(user: string, lease: string, error: Failure): Promise<void>;
  pending(): Promise<string[]>;
}
export class Denied extends Error {}
export class OwnedClasses extends Error {
  constructor(readonly count: number) { super("Owned classes exist"); }
}
export type Identity = { userId: string; sessionId: string };

// Shared by self-deletion and scheduled recovery; only a live lease can finish a job.
export async function processDeletion(store: Store, user: string,
  deadline = Date.now() + 80000): Promise<boolean> {
  let lease: string | null = null;
  let stage: Failure = "database";
  try {
    lease = await store.claim(user);
    if (!lease) return false;
    for (let page = 0; ; page++) {
      if (Date.now() >= deadline || page >= 8) { stage = "deferred"; throw new Error(); }
      stage = "database";
      const classId = await store.nextClass(user, lease);
      if (!classId) break;
      const files = await store.classFiles(user, lease, classId);
      if (!files.length) {
        await store.purgeClass(user, lease, classId);
        continue;
      }
      stage = "storage";
      for (const bucket of ["banners", "materials", "submissions"]) {
        const paths = files.filter((file) => file.bucket_id === bucket).map((file) => file.name);
        if (!paths.length) continue;
        if (Date.now() >= deadline) { stage = "deferred"; throw new Error(); }
        await store.remove(bucket, paths);
      }
    }
    for (let page = 0; ; page++) {
      if (Date.now() >= deadline || page >= 8) { stage = "deferred"; throw new Error(); }
      stage = "database";
      const paths = await store.avatars(user, lease);
      if (!paths.length) break;
      stage = "storage";
      await store.remove("avatars", paths);
    }
    stage = "database";
    await store.prepare(user, lease);
    stage = "auth";
    await store.deleteLogin(user);
    stage = "database";
    await store.finish(user, lease);
    return true;
  } catch {
    if (lease) {
      try { await store.release(user, lease, stage); } catch { /* Lease expires for recovery. */ }
    }
    return false;
  }
}

async function emptyObject(req: Request): Promise<boolean> {
  if (new URL(req.url).search) return false;
  const reader = req.body?.getReader();
  if (!reader) return false;
  const chunks: Uint8Array[] = [];
  let size = 0;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    const read = async () => {
      while (true) {
        const part = await reader.read();
        if (part.done) break;
        size += part.value.length;
        if (size > 256) return false;
        chunks.push(part.value);
      }
      const bytes = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
      const value = JSON.parse(new TextDecoder().decode(bytes));
      return value !== null && typeof value === "object" && !Array.isArray(value) && Object.keys(value).length === 0;
    };
    return await Promise.race([read(), new Promise<boolean>((resolve) => {
      timer = setTimeout(() => { void reader.cancel().catch(() => {}); resolve(false); }, 5000);
    })]);
  } catch { return false; }
  finally {
    clearTimeout(timer);
    try { await reader.cancel(); } catch { /* A closed/aborted stream needs no cleanup. */ }
  }
}

export function createHandler(store: Store, authenticate: (req: Request) => Promise<Identity | null>) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return json({});
    if (req.method !== "POST") return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    try {
      const identity = await authenticate(req);
      if (!identity) return json({ error: { code: "NOT_AUTHENTICATED" } }, 401);
      if (!await emptyObject(req)) return json({ error: { code: "INVALID_REQUEST" } }, 400);
      await store.begin(identity.userId, identity.sessionId);
      const done = await processDeletion(store, identity.userId);
      return json({ status: done ? "deleted" : "pending" }, done ? 200 : 202);
    } catch (error) {
      if (error instanceof OwnedClasses) {
        return json({ error: { code: "OWNED_CLASSES_EXIST", count: error.count } }, 409);
      }
      return json({ error: { code: error instanceof Denied ? "NOT_ALLOWED" : "UNAVAILABLE" } },
        error instanceof Denied ? 403 : 503);
    }
  };
}

export function createRecoveryHandler(store: Store, secret: string | undefined) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return json({ error: { code: "METHOD_NOT_ALLOWED" } }, 405);
    if (!secret) return json({ error: { code: "UNAVAILABLE" } }, 503);
    const supplied = req.headers.get("x-account-deletion-secret") ?? "";
    const digest = async (value: string) => new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)));
    const [a, b] = await Promise.all([digest(secret), digest(supplied)]);
    let difference = 0;
    for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
    if (difference) return json({ error: { code: "NOT_AUTHENTICATED" } }, 401);
    try {
      const users = await store.pending();
      const deadline = Date.now() + 80000;
      let completed = 0;
      for (const user of users) {
        if (Date.now() >= deadline) break;
        if (await processDeletion(store, user, deadline)) completed++;
      }
      return json({ completed, pending: users.length - completed });
    } catch { return json({ error: { code: "UNAVAILABLE" } }, 503); }
  };
}
