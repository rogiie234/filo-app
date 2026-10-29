import { captureQuality } from "./ai_quality_trace.ts";
import { directSchema, generateDirect, parseDirectOutput } from "../supabase/functions/ai-generate-quiz/direct.ts";
import { request } from "../supabase/functions/ai-generate-quiz/quality_fixtures.ts";
import { QuizError, sampleOutput, validateInput, types } from "../supabase/functions/ai-generate-quiz/quiz.ts";
import type { Input, QuestionType } from "../supabase/functions/ai-generate-quiz/quiz.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value { if (!value) throw new Error(message); }
function equal(a: unknown, b: unknown) { assert(JSON.stringify(a) === JSON.stringify(b), `${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
const input = (): Input => ({ ...request(), counts: { multiple_choice: 6, true_false: 2, identification: 2, essay: 1 } });
const usageMetadata = { promptTokenCount: 100, cachedContentTokenCount: 0, candidatesTokenCount: 50, thoughtsTokenCount: 0, totalTokenCount: 150 };
const output = (settings = input()): Record<string, unknown>[] => JSON.parse(sampleOutput(settings)).map((q: Record<string, unknown>) => ({
  ...q, evidence: "Synthetic test evidence.",
  ...(q.type === "essay" ? { sample_answer: "A supported sample answer.", rubric: [{ key_point: "A supported point.", points: 1 }] } : {}),
}));
const grouped = (rows = output()) => Object.fromEntries(types.map((type) => [type, rows.filter((q) => q.type === type)
  .map(({ type: _type, ...q }) => q)])) as Record<QuestionType, Record<string, unknown>[]>;
const response = (text: string, finishReason = "STOP") => Response.json({ usageMetadata,
  candidates: [{ finishReason, content: { parts: [{ text }] } }] });

Deno.test("direct comparison generates11mixed items with exactly one call and a grouped schema", async () => {
  let calls = 0;
  const report = await captureQuality(input(), "private-key", "fixture-model", async (url, init) => {
    calls++;
    assert(!String(url).includes("private-key"));
    equal(new Headers(init!.headers).get("x-goog-api-key"), "private-key");
    const body = JSON.parse(String(init!.body));
    equal(body.generationConfig, { responseFormat: { text: { mimeType: "APPLICATION_JSON", schema: directSchema(input()) } } });
    const schema = body.generationConfig.responseFormat.text.schema;
    equal(schema.required, [...types]); equal(schema.additionalProperties, false);
    for (const type of types) {
      equal(schema.properties[type].maxItems, input().counts[type]);
      for (const field of ["prompt", "points", "explanation", "evidence"]) assert(schema.properties[type].items.required.includes(field));
      assert(!("type" in schema.properties[type].items.properties));
    }
    equal(schema.properties.multiple_choice.items.properties.options.minItems, 4);
    equal(schema.properties.multiple_choice.items.properties.options.maxItems, 4);
    assert(schema.properties.essay.items.required.includes("sample_answer"));
    assert(schema.properties.essay.items.required.includes("rubric"));
    equal(JSON.parse(body.contents[0].parts[0].text), input());
    assert(!body.systemInstruction.parts[0].text.includes("BLUEPRINT stage"));
    return response(JSON.stringify(grouped()));
  }, "direct");
  equal(calls, 1); equal(report.error, null); equal(report.summary.pipeline, "direct-v2");
  equal(report.summary.provider_calls, 1); equal(report.summary.returned, 11);
  equal(report.summary.returned_by_type, input().counts);
  equal(report.summary.missing_by_type, { multiple_choice: 0, true_false: 0, identification: 0, essay: 0 });
  equal(report.summary.tokens.totalTokenCount.observed_total, 150);
  equal(report.events.filter((e) => e.stage === "provider_timing").map((e) => e.purpose), ["direct_generation"]);
  assert(!JSON.stringify(report).includes("private-key"));
});

Deno.test("direct comparison retains partial valid output without semantic rejection or repair", async () => {
  const rows = output();
  rows[0].correct_index = 99;
  rows[1].prompt = rows[2].prompt;
  let calls = 0;
  const report = await captureQuality(input(), "private-key", "fixture-model", async () => {
    calls++; return response(JSON.stringify(grouped(rows)));
  }, "direct");
  equal(calls, 1); equal(report.error, null); equal(report.summary.returned, 9);
  equal(report.summary.missing_by_type.multiple_choice, 2);
  equal(report.result!.dropped_by_type.multiple_choice, 2);
  assert(report.events.some((e) => e.stage === "result" && e.independently_verified === false));
});

Deno.test("direct comparison invalid JSON and truncated output fail once with usage retained", async () => {
  for (const [text, finish] of [["not json", "STOP"], [JSON.stringify(grouped()), "MAX_TOKENS"], ["[]", "STOP"]]) {
    let calls = 0;
    const report = await captureQuality(input(), "private-key", "fixture-model", async () => {
      calls++; return response(text, finish);
    }, "direct");
    equal(calls, 1); equal(report.error, "AI_BAD_OUTPUT"); equal(report.result, null);
    equal(report.summary.tokens.totalTokenCount.observed_total, 150);
  }
});

Deno.test("direct comparison busy and offline fail once with unknown usage", async () => {
  for (const status of [429, 503, 400, 403]) {
    let calls = 0;
    const report = await captureQuality(input(), "private-key", "fixture-model", async () => {
      calls++; return new Response("private provider details", { status });
    }, "direct");
    equal(calls, 1); equal(report.error, [429, 503].includes(status) ? "AI_BUSY" : "AI_UNAVAILABLE");
    equal(report.summary.tokens.promptTokenCount.observed_total, null);
    assert(!JSON.stringify(report).includes("private provider details"));
  }
  const offline = await captureQuality(input(), "private-key", "fixture-model", async () => { throw new TypeError("offline"); }, "direct");
  equal(offline.error, "AI_UNAVAILABLE"); equal(offline.summary.provider_calls, 1);
});

Deno.test("direct comparison deadline abort and oversize output stay bounded", async () => {
  for (const deadline of [Date.now() - 1, Date.now() + 10]) {
    let calls = 0;
    try {
      await generateDirect(input(), "private-key", "fixture-model", deadline, () => {
        calls++; return new Promise<Response>(() => {});
      });
      throw new Error("Expected timeout");
    } catch (error) { assert(error instanceof QuizError); equal(error.code, "AI_TIMEOUT"); }
    assert(calls <= 1);
  }
  const large = await captureQuality(input(), "private-key", "fixture-model", async () => new Response("x".repeat(262145)), "direct");
  equal(large.error, "AI_BAD_OUTPUT");
});

Deno.test("direct comparison observer failure does not affect output and private raw text redacts keys", async () => {
  const result = await generateDirect(input(), "private-key", "fixture-model", Date.now() + 45000,
    async () => response(JSON.stringify(grouped())), () => { throw new Error("observer"); });
  equal(result.questions.length, 11);
  const failed = await captureQuality(input(), "private-key", "fixture-model", async () => response("private-key"), "direct");
  equal(failed.error, "AI_BAD_OUTPUT"); assert(!JSON.stringify(failed).includes("private-key"));
});

Deno.test("direct comparison uses existing validated request and regeneration limits", async () => {
  const body = { texts: [{ file_name: "fixture.txt", text: "A supported source." }], counts: input().counts, difficulty: "easy" };
  equal(validateInput(body).counts, input().counts);
  for (const invalid of [{ ...body, texts: [] }, { ...body, texts: [{ file_name: "fixture.txt", text: "x".repeat(40001) }] }]) {
    let rejected = false;
    try { validateInput(invalid); } catch (error) { rejected = error instanceof QuizError; }
    assert(rejected);
  }
  const settings = { ...input(), mode: "regenerate" as const, counts: { multiple_choice: 1, true_false: 0, identification: 0, essay: 0 }, current_prompts: ["Existing prompt"] };
  const report = await captureQuality(settings, "private-key", "fixture-model", async (_url, init) => {
    equal(JSON.parse(JSON.parse(String(init!.body)).contents[0].parts[0].text).current_prompts, settings.current_prompts);
    return response(JSON.stringify(grouped(output(settings))));
  }, "direct");
  equal(report.summary.returned, 1);
});


Deno.test("direct-v2 requires common fields and essay metadata locally without inventing content", () => {
  for (const type of types) for (const field of ["prompt", "points", "explanation", "evidence", ...(type === "essay" ? ["sample_answer", "rubric"] : [])]) {
    const rows = grouped();
    delete rows[type][0][field];
    const result = parseDirectOutput(JSON.stringify(rows), input());
    equal(result.questions.length, 10); equal(result.dropped_by_type[type], 1); equal(result.missing_by_type[type], 1);
  }
  for (const field of ["explanation", "evidence", "sample_answer"]) {
    const rows = grouped(); rows.essay[0][field] = "   ";
    equal(parseDirectOutput(JSON.stringify(rows), input()).dropped_by_type.essay, 1);
  }
  const rows = grouped(); rows.true_false[0].correct_boolean = false;
  equal(parseDirectOutput(JSON.stringify(rows), input()).questions.filter((q) => q.type === "true_false")[0].correct_boolean, false);
});

Deno.test("direct-v2 rejects invalid MC shapes and rubric totals while retaining other valid items", () => {
  for (const options of [["A", "B", "C"], ["A", "B", "C", "D", "E"], ["A", "A", "C", "D"]]) {
    const rows = grouped(); rows.multiple_choice[0].options = options;
    const result = parseDirectOutput(JSON.stringify(rows), input());
    equal(result.questions.length, 10); equal(result.dropped_by_type.multiple_choice, 1);
    equal(result.missing_by_type.multiple_choice, 1);
  }
  const rows = grouped(); rows.essay[0].points = 2;
  const result = parseDirectOutput(JSON.stringify(rows), input());
  equal(result.questions.length, 10); equal(result.dropped_by_type.essay, 1);
});

Deno.test("direct-v2 malformed groups fail closed and short or excessive groups preserve counts", () => {
  for (const raw of [[], null, {}, { ...grouped(), essay: null }, { ...grouped(), extra: [] }]) {
    let rejected = false;
    try { parseDirectOutput(JSON.stringify(raw), input()); }
    catch (error) { rejected = error instanceof QuizError && error.code === "AI_BAD_OUTPUT"; }
    assert(rejected);
  }
  const rows = grouped(); rows.essay = [];
  let result = parseDirectOutput(JSON.stringify(rows), input());
  equal(result.questions.length, 10); equal(result.missing_by_type.essay, 1); equal(result.dropped_by_type.essay, 0);
  rows.multiple_choice.push({ ...rows.multiple_choice[0], prompt: "An excess prompt" });
  result = parseDirectOutput(JSON.stringify(rows), input());
  equal(result.questions.length, 10); equal(result.dropped_by_type.multiple_choice, 1);
  rows.multiple_choice[0].type = "essay";
  result = parseDirectOutput(JSON.stringify(rows), input());
  equal(result.questions.length, 9); equal(result.dropped_by_type.multiple_choice, 2);
  const settings = { ...input(), counts: { multiple_choice: 1, true_false: 0, identification: 0, essay: 0 } };
  const schema = directSchema(settings);
  equal(schema.properties.essay.maxItems, 0);
  equal(parseDirectOutput(JSON.stringify(grouped(output(settings))), settings).questions.length, 1);
});
