// Owner-operated private diagnostics. Hosted handlers never install this observer.
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { generate, object, QuizError, tokenUsage, usageFields, validateInput } from "../supabase/functions/ai-generate-quiz/quiz.ts";
import { directRevision, generateDirect } from "../supabase/functions/ai-generate-quiz/direct.ts";
import type { Input, Result } from "../supabase/functions/ai-generate-quiz/quiz.ts";
import type { TraceEvent } from "../supabase/functions/ai-generate-quiz/planning.ts";

const workspace = fileURLToPath(new URL("../../../", import.meta.url));
export function privateTracePath(path: string, root = workspace): string {
  const target = resolve(path);
  const fromRoot = relative(resolve(root), target);
  if (!fromRoot || (!isAbsolute(fromRoot) && fromRoot !== ".." && !fromRoot.startsWith(".." + sep))) {
    throw new Error("Trace output must be outside the Filo workspace and Git.");
  }
  return target;
}

export async function privateDestination(path: string, io: { realPath: (path: string) => Promise<string>;
  lstat: (path: string) => Promise<unknown> } = Deno, root = workspace): Promise<string> {
  const parent = await io.realPath(dirname(resolve(path)));
  const output = privateTracePath(resolve(parent, basename(path)), root);
  for (let directory = parent;; directory = dirname(directory)) {
    try {
      await io.lstat(join(directory, ".git"));
      throw new Error("Trace output cannot be inside a Git checkout or worktree.");
    } catch (error) { if (!(error instanceof Deno.errors.NotFound)) throw error; }
    if (dirname(directory) === directory) break;
  }
  return output;
}

export function traceCollector(maxBytes = 4 * 1024 * 1024) {
  const events: TraceEvent[] = [];
  let bytes = 0;
  let dropped = 0;
  return { events, get dropped() { return dropped; }, observe(event: TraceEvent) {
    const copy = structuredClone(event);
    const size = new TextEncoder().encode(JSON.stringify(copy)).length;
    if (events.length >= 500 || bytes + size > maxBytes) { dropped++; return; }
    bytes += size; events.push(copy);
  } };
}

export async function captureQuality(input: Input, key: string, model: string, fetcher: typeof fetch = fetch, pipeline: "quality" | "direct" = "quality") {
  const trace = traceCollector();
  const started = Date.now();
  const calls = new Map<number, TraceEvent>();
  let result: Result | null = null;
  let error: string | null = null;
  try {
    const generator = pipeline === "direct" ? generateDirect : generate;
    result = await generator(input, key, model, started + 110000, fetcher, (event) => {
      // Aggregate independently of the bounded private event buffer.
      if (event.stage === "provider_timing" && event.request_sent === true && Number.isSafeInteger(event.call_id) && Number(event.call_id) > 0) calls.set(Number(event.call_id), event);
      trace.observe(event);
    });
  } catch (failure) {
    error = failure instanceof QuizError ? failure.code : "AI_UNAVAILABLE";
  }
  const usage = [...calls.values()].map((event) => tokenUsage(event.usage));
  const tokens = Object.fromEntries(usageFields.map((field) => {
    const values = usage.map((row) => row[field]).filter((value): value is number => value !== null);
    const total = values.reduce((sum, value) => sum + value, 0);
    return [field, { observed_total: values.length && Number.isSafeInteger(total) ? total : null,
      observed_calls: values.length, missing_calls: calls.size - values.length }];
  }));
  const summary = { pipeline: pipeline === "direct" ? directRevision : "Q4.14", model, elapsed_ms: Math.max(0, Date.now() - started), provider_calls: calls.size,
    calls_missing_usage: usage.filter((row) => usageFields.some((field) => row[field] === null)).length,
    tokens, requested: Object.values(input.counts).reduce((sum, count) => sum + count, 0),
    returned: result?.questions.length ?? 0,
    returned_by_type: Object.fromEntries(Object.keys(input.counts).map((type) => [type, result?.questions.filter((q) => q.type === type).length ?? 0])),
    missing_by_type: result?.missing_by_type ?? input.counts, error };
  return { result, events: trace.events, dropped_events: trace.dropped, error, summary };
}

if (import.meta.main) {
  try {
    const arg = (name: string) => { const at = Deno.args.indexOf(name); return at >= 0 ? Deno.args[at + 1] : undefined; };
    const inputPath = arg("--input");
    if (!inputPath || !Deno.args.includes("--live")) throw new Error("Use --live [--direct] --input PRIVATE_REQUEST_JSON --trace OUTSIDE_WORKSPACE_JSON. This makes real AI calls.");
    const requestedPath = arg("--trace");
    if (!requestedPath) throw new Error("A private trace destination is required before calling AI.");
    const output = await privateDestination(requestedPath);
    // Reserve with createNew before paid work; never overwrite an old trace or follow a file symlink.
    const handle = await Deno.open(output, { createNew: true, write: true, mode: 0o600 });
    try {
      if ((await Deno.stat(inputPath)).size > 524288) throw new Error("Private request exceeds the existing request size limit.");
      const body: unknown = JSON.parse(await Deno.readTextFile(inputPath));
      if (!object(body)) throw new Error("Private request must be a JSON object.");
      const input = validateInput(body);
      const report = await captureQuality(input, Deno.env.get("GEMINI_API_KEY") ?? "", Deno.env.get("GEMINI_MODEL") ?? "", fetch,
        Deno.args.includes("--direct") ? "direct" : "quality");
      const bytes = new TextEncoder().encode(JSON.stringify(report, null, 2));
      let written = 0;
      while (written < bytes.length) {
        const count = await handle.write(bytes.subarray(written));
        if (!count) throw new Error("Private trace write stopped.");
        written += count;
      }
      console.log(JSON.stringify({ status: report.error ?? "completed", returned: report.result?.questions.length ?? 0,
        missing_by_type: report.result?.missing_by_type ?? input.counts, summary: report.summary, trace_saved: true, dropped_events: report.dropped_events }));
      if (report.error) Deno.exitCode = 1;
    } finally { handle.close(); }
  } catch {
    console.error("Private trace run stopped: check arguments, permissions, unused destination outside workspace, request, and private model environment. No automatic retry.");
    Deno.exitCode = 1;
  }
}
