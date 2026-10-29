import { qualityPipeline } from "./pipeline.ts";
import { candidateSchema, generationInstructions } from "./pipeline.ts";
import type { TraceObserver } from "./planning.ts";
import { modelItems, wireInstructions, wireSchema } from "./wire.ts";
export { modelItems };
export const types = ["multiple_choice", "true_false", "identification", "essay"] as const;
export type QuestionType = typeof types[number];
export type Counts = Record<QuestionType, number>;
export const emptyCounts = (): Counts => ({ multiple_choice: 0, true_false: 0, identification: 0, essay: 0 });
export const errors = {
  NOT_ALLOWED: [403, "You are not allowed to generate questions for this quiz."],
  INVALID_REQUEST: [400, "Check the question counts and request settings."],
  NO_TEXT: [400, "Provide readable source text."],
  TOO_LARGE: [413, "The request is too large. Use a smaller text selection."],
  AI_IN_PROGRESS: [409, "An AI request is already running. Please wait and try again."],
  AI_BUSY: [503, "The AI assistant is busy. Please try again in a few minutes."],
  AI_TIMEOUT: [504, "The AI request timed out. Please try again."],
  AI_BAD_OUTPUT: [502, "The AI could not produce valid questions. Try different source text."],
  AI_UNAVAILABLE: [503, "The AI assistant is unavailable. Please try again later."],
} as const;
export type ErrorCode = keyof typeof errors;
export class QuizError extends Error {
  constructor(readonly code: ErrorCode) { super(code); }
}
export function fail(code: ErrorCode): never { throw new QuizError(code); }
export function object(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
const length = (value: string) => Array.from(value).length;
const text = (value: unknown, max: number): value is string =>
  typeof value === "string" && value.trim().length > 0 && length(value) <= max;
const knownType = (value: unknown): value is QuestionType => types.includes(value as QuestionType);
const normalize = (value: string) => value.normalize("NFKC").trim().replace(/\s+/gu, " ").toLowerCase();
export interface Input {
  texts: string[];
  counts: Counts;
  difficulty: "easy" | "medium" | "hard";
  topic_focus: string;
  mode: "generate" | "regenerate";
  current_prompts: string[];
}

export function validateInput(body: Record<string, unknown>): Input {
  if (!object(body.counts) || Object.keys(body.counts).some((key) => !knownType(key))) fail("INVALID_REQUEST");
  const counts = emptyCounts();
  for (const type of types) {
    const count = body.counts[type];
    if (typeof count !== "number" || !Number.isInteger(count) || count < 0 || count > 20) fail("INVALID_REQUEST");
    counts[type] = count;
  }
  const total = Object.values(counts).reduce((a, b) => a + b, 0);
  if (total < 1 || total > 20 || !["easy", "medium", "hard"].includes(body.difficulty as string)) fail("INVALID_REQUEST");
  if (body.topic_focus !== undefined && (typeof body.topic_focus !== "string" || length(body.topic_focus) > 200)) fail("INVALID_REQUEST");
  const mode = body.mode ?? "generate";
  if (mode !== "generate" && mode !== "regenerate") fail("INVALID_REQUEST");
  let current: string[] = [];
  if (mode === "regenerate") {
    if (!knownType(body.type) || counts[body.type] !== 1 || total !== 1 ||
      !Array.isArray(body.current_prompts) || body.current_prompts.length < 1 || body.current_prompts.length > 100 ||
      !body.current_prompts.every((p) => text(p, 1000))) fail("INVALID_REQUEST");
    current = body.current_prompts as string[];
    if (current.reduce((sum, p) => sum + length(p), 0) > 40000) fail("TOO_LARGE");
  } else if (body.type !== undefined || body.current_prompts !== undefined) fail("INVALID_REQUEST");
  if (!Array.isArray(body.texts)) fail(body.texts === undefined ? "NO_TEXT" : "INVALID_REQUEST");
  if (body.texts.length > 3) fail("INVALID_REQUEST");
  const sources: string[] = [];
  for (const source of body.texts) {
    if (!object(source) || !text(source.file_name, 255) || typeof source.text !== "string") fail("INVALID_REQUEST");
    sources.push(source.text);
  }
  if (sources.reduce((sum, source) => sum + length(source), 0) > 40000) fail("TOO_LARGE");
  if (!sources.some((source) => source.trim())) fail("NO_TEXT");
  return { texts: sources, counts, difficulty: body.difficulty as Input["difficulty"],
    topic_focus: (body.topic_focus as string | undefined)?.trim() ?? "", mode, current_prompts: current };
}

export interface Question {
  type: QuestionType;
  prompt: string;
  points: number;
  explanation: string;
  options?: string[];
  correct_index?: number;
  correct_boolean?: boolean;
  accepted_answers?: string[];
  evidence?: string;
  sample_answer?: string;
  rubric?: { key_point: string; points: number }[];
}
export interface Result {
  questions: Question[];
  dropped_by_type: Counts;
  missing_by_type: Counts;
}
const extraFields: Record<QuestionType, string[]> = {
  multiple_choice: ["options", "correct_index"], true_false: ["correct_boolean"],
  identification: ["accepted_answers"], essay: [],
};
function validateQuestion(value: Record<string, unknown>, type: QuestionType): Question | string {
  const allowed = ["type", "prompt", "points", "explanation", "evidence", ...(type === "essay" ? ["sample_answer", "rubric"] : []), ...extraFields[type]];
  const unexpected = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unexpected.length) {
    if (unexpected.includes("correct_option_index")) return "wrong_index_field";
    if (unexpected.every((key) => ["options", "correct_index", "correct_boolean", "accepted_answers"].includes(key))) {
      return unexpected.every((key) => value[key] === null) ? "unused_null_fields" : "unused_answer_fields";
    }
    return "unknown_fields";
  }
  if (!text(value.prompt, 1000)) return "invalid_prompt";
  if (typeof value.explanation !== "string" || length(value.explanation) > 500) return "invalid_explanation";
  const points = value.points === undefined ? 1 : value.points;
  if (typeof points !== "number" || !Number.isInteger(points) || points < 1 || points > 1000) return "invalid_points";
  const question: Question = { type, prompt: value.prompt.trim(), points, explanation: value.explanation.trim() };
  if (value.evidence !== undefined) {
    if (!text(value.evidence, 1000)) return "invalid_evidence";
    question.evidence = value.evidence.trim();
  }
  if (type === "essay" && (value.sample_answer !== undefined || value.rubric !== undefined)) {
    if (!text(value.sample_answer, 4000) || !Array.isArray(value.rubric) || !value.rubric.length || value.rubric.length > 20 ||
      !value.rubric.every((r) => object(r) && text(r.key_point, 500) && Number.isInteger(r.points) && Number(r.points) > 0) ||
      value.rubric.reduce((sum, r) => sum + Number(r.points), 0) !== points) return "invalid_rubric";
    question.sample_answer = value.sample_answer.trim();
    question.rubric = value.rubric.map((r) => ({ key_point: String(r.key_point).trim(), points: Number(r.points) }));
  }
  if (type === "multiple_choice") {
    const options = value.options;
    if (!Array.isArray(options)) return "options_not_array";
    if (options.length < 2 || options.length > 10) return "invalid_option_count";
    if (!options.every((option) => text(option, 500))) return "invalid_option_text";
    if (new Set(options.map(normalize)).size !== options.length) return "duplicate_options";
    if (typeof value.correct_index !== "number" || !Number.isInteger(value.correct_index) ||
      value.correct_index < 0 || value.correct_index >= options.length) return "invalid_correct_index";
    question.options = options.map((option: string) => option.trim());
    question.correct_index = value.correct_index;
  } else if (type === "true_false") {
    if (typeof value.correct_boolean !== "boolean") return "invalid_boolean";
    question.correct_boolean = value.correct_boolean;
  } else if (type === "identification") {
    const answers = value.accepted_answers;
    if (!Array.isArray(answers) || answers.length < 1 || answers.length > 10 || !answers.every((answer) => text(answer, 200))) return "invalid_accepted_answers";
    question.accepted_answers = [...new Map(answers.map((answer: string) => [normalize(answer), answer.trim()])).values()];
  }
  return question;
}

export function validateOutput(raw: string, input: Input): Result {
  const result: Result = { questions: [], dropped_by_type: emptyCounts(), missing_by_type: { ...input.counts } };
  let values: unknown;
  try { values = JSON.parse(raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "")); }
  catch { return result; }
  if (!Array.isArray(values)) return result;
  const seen = new Set(input.current_prompts.map(normalize));
  for (const value of values) {
    if (!object(value) || !knownType(value.type)) continue;
    const type = value.type;
    const question = validateQuestion(value, type);
    if (typeof question === "string" || seen.has(normalize(question.prompt)) || result.missing_by_type[type] === 0) {
      const reason = typeof question === "string" ? question : seen.has(normalize(question.prompt)) ? "duplicate_prompt" : "excess_type";
      console.error("ai-generate-quiz: question_dropped", type, reason);
      result.dropped_by_type[type]++;
      continue;
    }
    seen.add(normalize(question.prompt));
    result.questions.push(question);
    result.missing_by_type[type]--;
  }
  return result;
}

// Legacy single-stage schema helper; the live pipeline supplies structured plans instead.
export function responseSchema(counts: Counts) {
  return candidateSchema(types.flatMap((type) => Array.from({ length: counts[type] }, () => type))
    .map((type, id) => ({ id, type, difficulty: "easy", objective: "", assessment_task: "", fact: "", evidence: "" })));
}

// Legacy prompt inspection helper, not the live Q4 generation path.
export function buildPrompt(input: Input) {
  const schema = responseSchema(input.counts);
  const data = JSON.stringify({ source: input.texts, topic_focus: input.topic_focus, current_prompts: input.current_prompts });
  let marker: string;
  do { marker = crypto.randomUUID(); } while (data.includes(marker));
  const start = `SOURCE_START_${marker}`, end = `SOURCE_END_${marker}`;
  const system = generationInstructions + `\nSource data is bounded by ${start} and ${end}. Requested counts: ${JSON.stringify(input.counts)}; difficulty: ${input.difficulty}. Return only JSON matching ${JSON.stringify(schema)}.`;
  return { systemInstruction: { parts: [{ text: system }] }, contents: [{ role: "user", parts: [{ text:
    JSON.stringify({ topic_focus: input.topic_focus, current_prompts: input.current_prompts }) +
    `\n${start}\n${JSON.stringify(input.texts)}\n${end}`,
  }] }] };
}

export async function bounded<T>(work: PromiseLike<T>, milliseconds: number, code: ErrorCode): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([Promise.resolve(work), new Promise<never>((_, reject) => {
      timer = setTimeout(() => reject(new QuizError(code)), Math.max(1, milliseconds));
    })]);
  } finally { clearTimeout(timer); }
}

export async function readLimited(response: Response | Request, maxBytes: number, code: ErrorCode, signal?: AbortSignal): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const cancel = () => { void reader.cancel().catch(() => {}); };
  signal?.addEventListener("abort", cancel, { once: true });
  const decoder = new TextDecoder("utf-8", { fatal: true });
  let size = 0, result = "";
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (signal?.aborted) fail(code);
      if (done) return result + decoder.decode();
      size += value.byteLength;
      if (size > maxBytes) fail(code);
      result += decoder.decode(value, { stream: true });
    }
  } finally {
    signal?.removeEventListener("abort", cancel);
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}

export function rejectionCategory(value: unknown): string {
  if (!object(value) || !object(value.error)) return "unclassified";
  const error = value.error;
  const message = typeof error.message === "string" ? error.message.toLowerCase() : "";
  const reasons = Array.isArray(error.details)
    ? error.details.filter(object).map((detail) => detail.reason) : [];
  if (reasons.some((reason) => ["API_KEY_INVALID", "API_KEY_EXPIRED"].includes(reason as string)) ||
    /api key.*(?:not valid|invalid|expired)/s.test(message)) return "api_key_invalid";
  if (reasons.some((reason) => ["API_KEY_SERVICE_BLOCKED", "API_KEY_HTTP_REFERRER_BLOCKED", "API_KEY_IP_ADDRESS_BLOCKED", "SERVICE_DISABLED", "CONSUMER_INVALID"].includes(reason as string))) return "key_or_project_restricted";
  if (/free tier.*(?:not available|unavailable|not supported)/s.test(message)) return "free_tier_unavailable";
  if (/unknown (?:name|field)/.test(message)) return "request_field_unsupported";
  if (/(?:same|identical).*first (?:key|property)|first (?:key|property).*(?:same|identical)/s.test(message)) return "schema_union_ordering";
  if (/schema.*(?:too complex|too large)|too many states/s.test(message)) return "schema_complexity";
  if (/schema|any_?of|additionalproperties|response_?format/.test(message)) return "schema_rejected";
  if (/model.*(?:not supported|does not support|unsupported)/s.test(message)) return "model_unsupported";
  return "unclassified";
}

export function modelRequest(system: string, data: unknown, schema: Record<string, unknown>) {
  return {
    systemInstruction: { parts: [{ text: system + wireInstructions(schema) }] },
    contents: [{ role: "user", parts: [{ text: JSON.stringify(data) }] }],
    generationConfig: { responseFormat: { text: { mimeType: "APPLICATION_JSON", schema: wireSchema(schema) } } },
  };
}

export function privateText(value: string, key: string, limit: number): string {
  return value.split(key).join("[REDACTED]").split(encodeURIComponent(key)).join("[REDACTED]")
    .replace(/https?:\/\/[^\s"<>]+/gi, "[URL REDACTED]")
    .replace(/Bearer\s+\S+|AIza[\w-]+|eyJ[\w-]+\.[\w-]+\.[\w-]+/gi, "[REDACTED]")
    .slice(0, limit);
}

export const usageFields = ["promptTokenCount", "cachedContentTokenCount", "candidatesTokenCount", "thoughtsTokenCount", "totalTokenCount"] as const;
export function tokenUsage(value: unknown) {
  return Object.fromEntries(usageFields.map((field) => {
    const count = object(value) ? value[field] : undefined;
    return [field, typeof count === "number" && Number.isSafeInteger(count) && count >= 0 ? count : null];
  })) as Record<typeof usageFields[number], number | null>;
}

export async function generate(input: Input, key: string, model: string, deadline: number, fetcher: typeof fetch = fetch,
  observer?: TraceObserver): Promise<Result> {
  if (!key.trim()) {
    console.error("ai-generate-quiz: missing_api_key");
    fail("AI_UNAVAILABLE");
  }
  if (!/^[a-zA-Z0-9._-]+$/.test(model)) {
    console.error("ai-generate-quiz: missing_or_invalid_model");
    fail("AI_UNAVAILABLE");
  }
  const diagnostic = (event: Record<string, unknown> & { stage: string }) => {
    if (!observer) return;
    try { observer({ ...event, model }); }
    catch { /* Private diagnostics must not change generation or provider errors. */ }
  };
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  let callSequence = 0;
  const result = await qualityPipeline(input, async (system, data, schema) => {
    const call_id = ++callSequence;
    const started = Date.now();
    const purpose = system.includes("SOURCE AUDIT stage") ? "source_audit" : system.includes("BLUEPRINT stage") ? "blueprint" :
      system.includes("GENERATION stage") ? "generation" : "verification";
    const requestBody = JSON.stringify(modelRequest(system, data, schema));
    const requestBytes = new TextEncoder().encode(requestBody).byteLength;
    const remaining = deadline - Date.now();
    let usage = tokenUsage(null);
    let requestSent = false;
    let responseBytes: number | null = null, httpStatus: number | null = null, outcome = "response_received";
    const timing = (limit: number) => {
      const event = { stage: "provider_timing", purpose, call_id, elapsed_ms: Math.max(0, Date.now() - started),
        request_bytes: requestBytes, response_bytes: responseBytes, http_status: httpStatus,
        remaining_ms: Math.max(0, deadline - Date.now()), limit_ms: limit, outcome,
        usage, request_sent: requestSent,
        timeout_scope: outcome === "AI_TIMEOUT" ? remaining <= 45000 ? "overall_deadline" : "call_limit" : null };
      const { usage: _usage, ...publicTiming } = event;
      console.info("ai-generate-quiz: provider_timing", JSON.stringify(publicTiming));
      diagnostic(event);
    };
    if (remaining <= 0) { outcome = "AI_TIMEOUT"; timing(0); fail("AI_TIMEOUT"); }
    const controller = new AbortController();
    const milliseconds = Math.min(45000, remaining);
    const timer = setTimeout(() => controller.abort(), milliseconds);
    try {
      return await bounded((async () => {
        requestSent = true;
        const response = await fetcher(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
          method: "POST", signal: controller.signal,
          headers: { "Content-Type": "application/json", "x-goog-api-key": key },
          body: requestBody,
        });
        httpStatus = response.status;
        if (!response.ok) {
          console.error("ai-generate-quiz: provider_http", response.status);
          if (response.status === 400) {
            let category = "unclassified";
            try {
              const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(3000)]);
              const rejection = await bounded(readLimited(response, 16384, "AI_UNAVAILABLE", signal), 3000, "AI_UNAVAILABLE");
              const detail: unknown = JSON.parse(rejection);
              category = rejectionCategory(detail);
              if (observer && object(detail) && object(detail.error) && typeof detail.error.message === "string") {
                const message = privateText(detail.error.message, key, 16384).replace(/\s+/g, " ").slice(0, 2048);
                diagnostic({ stage: "provider_error", http_status: response.status, category, message });
              }
            } catch { /* Diagnostics must not change the mapped provider failure. */ }
            console.error("ai-generate-quiz: provider_rejection", category);
          } else await response.body?.cancel();
          fail([429, 500, 502, 503, 504].includes(response.status) ? "AI_BUSY" : "AI_UNAVAILABLE");
        }
        diagnostic({ stage: "provider_status", http_status: response.status });
        const encoded = await readLimited(response, 262144, "AI_BAD_OUTPUT", controller.signal);
        responseBytes = new TextEncoder().encode(encoded).byteLength;
        const envelope: unknown = JSON.parse(encoded);
        usage = tokenUsage(object(envelope) ? envelope.usageMetadata : null);
        if (!object(envelope) || !Array.isArray(envelope.candidates)) {
          diagnostic({ stage: "provider_response", http_status: response.status, outcome: "missing_candidates",
            block_reason: object(envelope) && object(envelope.promptFeedback) && typeof envelope.promptFeedback.blockReason === "string"
              ? privateText(envelope.promptFeedback.blockReason, key, 64) : null });
          return null;
        }
        const candidate = envelope.candidates[0];
        const parts = object(candidate) && object(candidate.content) && Array.isArray(candidate.content.parts) ? candidate.content.parts : [];
        const raw = parts.filter((part: unknown) => object(part) && part.thought !== true && typeof part.text === "string")
          .map((part: { text: string }) => part.text).join("");
        const responseInfo = () => ({ stage: "provider_response", http_status: response.status,
          purpose,
          finish_reason: object(candidate) && typeof candidate.finishReason === "string" ? privateText(candidate.finishReason, key, 64) : null,
          text_characters: raw.length, raw_text: privateText(raw, key, 65536), truncated: raw.length > 65536 });
        if (!object(candidate) || candidate.finishReason !== "STOP" || !object(candidate.content) || !Array.isArray(candidate.content.parts)) {
          if (observer) diagnostic({ ...responseInfo(), outcome: "incomplete" });
          return null;
        }
        let value: unknown;
        try { value = JSON.parse(raw.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "")); }
        catch (error) {
          if (observer) diagnostic({ ...responseInfo(), outcome: "invalid_text_json" });
          throw error;
        }
        const items = modelItems(value, schema);
        if (observer) diagnostic({ ...responseInfo(), outcome: items ? "parsed" : "invalid_envelope",
          parsed_shape: Array.isArray(value) ? "array" : value === null ? "null" : typeof value,
          invalid_items: items?.filter((i) => i === null).length });
        return items;
      })(), milliseconds, "AI_TIMEOUT");
    } catch (error) {
      outcome = controller.signal.aborted || error instanceof DOMException && error.name === "AbortError" ? "AI_TIMEOUT" :
        error instanceof QuizError ? error.code : error instanceof SyntaxError ? "AI_BAD_OUTPUT" : "AI_UNAVAILABLE";
      if (controller.signal.aborted || (error instanceof DOMException && error.name === "AbortError")) fail("AI_TIMEOUT");
      if (error instanceof QuizError && error.code !== "AI_BAD_OUTPUT") throw error;
      if (error instanceof SyntaxError || (error instanceof QuizError && error.code === "AI_BAD_OUTPUT") || error instanceof TypeError && /encoded data|encoding/i.test(error.message)) {
        diagnostic({ stage: "provider_response", outcome: "decode_failed", error_class: error instanceof QuizError ? error.code : error instanceof SyntaxError ? "SyntaxError" : "TypeError" });
        return null;
      }
      console.error("ai-generate-quiz: provider_transport_failure");
      fail("AI_UNAVAILABLE");
    } finally { clearTimeout(timer); controller.abort(); timing(milliseconds); }
  }, seed, () => deadline - Date.now(), observer ? (event) => observer({ ...event, model }) : undefined);
  if (!result.questions.length) fail("AI_BAD_OUTPUT");
  return result;
}
export function sampleOutput(input: Input): string {
  return JSON.stringify(types.flatMap((type) => Array.from({ length: input.counts[type] }, (_, index) => ({
    type, prompt: `DEV sample ${type} question ${index + 1}`, points: 1, explanation: "DEV sample only; not generated from source text.",
    ...(type === "multiple_choice" ? { options: ["First", "Second", "Third", "Fourth"], correct_index: 0 } :
      type === "true_false" ? { correct_boolean: false } : type === "identification" ? { accepted_answers: ["sample"] } : {}),
  }))));
}
