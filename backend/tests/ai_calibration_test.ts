import { calibrationRequest, loadCalibration, loadBoundaryCalibration, referenceURL, boundaryURL, runCalibration, scoreCalibration } from "./ai_calibration.ts";
import { flatReview } from "../supabase/functions/ai-generate-quiz/quality_fixtures.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value { if (!value) throw new Error(message); }
function equal(a: unknown, b: unknown) { assert(JSON.stringify(a) === JSON.stringify(b), `${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
const document = () => Deno.readTextFile(referenceURL);
const answers = ["", "", "", "", "UNIQUE", "UNIQUE constraint", "Data is raw facts. Information is processed data providing meaning.",
  "Individual Units values are raw data. The total is information because aggregation processing creates a meaningful summary.", "", ""];
const keys = [[1], [3], [0], [1], [], [], [], [], [0], []];
function verdicts(items: Awaited<ReturnType<typeof loadCalibration>>) {
  return items.map((item, id) => ({ id, status: item.status, choices: keys[id], answer: answers[id], cognitive_level: item.level, plausible_options: true,
    application: { conditions: [item.question.prompt], inferences: item.level === "recall" ? 0 : 1, answer_leaked: false }, assumptions: [],
    option_reviews: item.question.options?.map((_, index) => ({ index, defensible: keys[id].includes(index) ? "yes" : "no", same_category: true, plausible: true })) ?? [],
    answer_points: item.question.rubric?.map((r) => r.key_point) ?? [] }));
}

Deno.test("C1 loads accepted reference only; payload is key/label/rubric free", async () => {
  const text = await document();
  const items = await loadCalibration(text);
  equal(items.length, 10);
  equal(items[0].question.prompt, "Which SQL statement retrieves data?");
  equal(items[1].question.options, ["DELETE", "UPDATE", "INSERT", "SELECT"]);
  assert(items[8].question.prompt.startsWith("Determine if backups"));
  equal(items[9].status, "none");
  const request = calibrationRequest(items);
  for (const row of request.data) {
    assert(!("correct_index" in row) && !("correct_boolean" in row));
    assert(!("accepted_answers" in row) && !("rubric" in row));
    assert(!("difficulty" in row) && !("expected_level" in row));
    assert(!("evidence" in row) && !("assessment_task" in row));
    assert(!(JSON.stringify(row).includes("C1-M-") || JSON.stringify(row).includes("C1-E-")));
  }
  let rejected = false;
  try { await loadCalibration(text.replace("Which SQL statement retrieves data?", "Which SQL statement deletes data?")); } catch { rejected = true; }
  assert(rejected, "Edited C1 must fail before network use");
});

Deno.test("C1 separates solving, cognitive agreement and negative-control false accepts", async () => {
  const items = await loadCalibration(await document());
  const correct = verdicts(items);
  const score = scoreCalibration(items, correct);
  equal(score.solving_agreements, 10);
  equal(score.level_agreements, 9);
  equal(score.level_scored_items, 9);
  equal(score.false_accepts, 0);
  equal(score.false_rejects, 0);
  const bad = correct.map((v) => ({ ...v }));
  bad[8].cognitive_level = "interpretation";
  bad[8].application = { ...bad[8].application, inferences: 1 };
  bad[9] = { ...bad[9], status: "one", choices: [0] };
  bad[9].option_reviews = bad[9].option_reviews.map((o) => ({ ...o, defensible: o.index === 0 ? "yes" : "no" }));
  equal(scoreCalibration(items, bad).false_accepts, 2);
  equal(scoreCalibration(items, [...correct, correct[0]]).rows[0].malformed, true);
  equal(scoreCalibration(items, []).false_rejects, 8);
});

Deno.test("C1 live runner makes one mocked call, no answer leakage or automatic retry", async () => {
  const text = await document();
  const items = await loadCalibration(text);
  let calls = 0;
  const fetcher: typeof fetch = async (url, init) => {
    calls++;
    assert(!String(url).includes("private-key"));
    equal(new Headers(init!.headers).get("x-goog-api-key"), "private-key");
    const payload = JSON.parse(String(init!.body));
    equal(payload.generationConfig.responseFormat.text.mimeType, "APPLICATION_JSON");
    equal(payload.generationConfig.responseFormat.text.schema.required, ["items"]);
    equal(payload.generationConfig.responseFormat.text.schema.properties.items.items.type, "object");
    assert(payload.generationConfig.responseFormat.text.schema.properties.items.items.required.includes("inference_count"));
    assert(payload.systemInstruction.parts[0].text.includes("OUTPUT CONTRACT:"));
    const data = JSON.parse(payload.contents[0].parts[0].text);
    equal(data.length, 10);
    assert(!JSON.stringify(data).includes('"correct_index"'));
    return Response.json({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify({ items: verdicts(items).map(flatReview) }) }] } }] });
  };
  equal((await runCalibration(text, "private-key", "approved-model", fetcher)).calls, 1);
  equal(calls, 1);
  calls = 0;
  let message = "";
  try { await runCalibration(text, "private-key", "approved-model", () => { calls++; return Promise.resolve(new Response("private provider data", { status: 429 })); }); }
  catch (error) { message = (error as Error).message; }
  equal(calls, 1);
  assert(message.includes("HTTP 429") && !message.includes("private"));
});


const boundaryDocument = () => Deno.readTextFile(boundaryURL);
function boundaryVerdicts(items: Awaited<ReturnType<typeof loadBoundaryCalibration>>) {
  return items.map((item, id) => ({ id, status: "one", choices: item.question.options ? [1] : [],
    answer: item.question.type === "identification" ? "DBMS" : "", cognitive_level: item.level, plausible_options: true,
    application: { conditions: [item.question.prompt], inferences: item.level === "recall" ? 0 : 1, answer_leaked: false },
    assumptions: [], answer_points: [], option_reviews: item.question.options?.map((_, index) => ({ index,
      defensible: index === 1 ? "yes" : "no", same_category: true, plausible: true })) ?? [] }));
}

Deno.test("B1 loads only its frozen accepted section and keeps keys and labels out of blind payload", async () => {
  const report = await boundaryDocument();
  const items = await loadBoundaryCalibration(report);
  equal(items.map((i) => [i.id, i.level]), [["B1-R-ID", "recall"], ["B1-D-MC", "interpretation"]]);
  equal(items[0].question.accepted_answers, ["DBMS", "Database Management System"]);
  equal(items[1].question.correct_index, 1);
  equal(items[1].question.options?.length, 4);
  assert(items[1].question.prompt.includes("41, 41 and 62"));
  equal(await loadBoundaryCalibration(report + "\n## Unrelated new evidence\nLater result."), items);
  for (const row of calibrationRequest(items).data) {
    for (const key of ["correct_index", "accepted_answers", "expected_level", "difficulty", "evidence", "assessment_task"])
      assert(!(key in row));
    assert(!JSON.stringify(row).includes("B1-"));
  }
  const start = report.indexOf("## B1 owner-accepted difficulty-boundary supplement");
  const prefix = report.slice(0, start), section = report.slice(start);
  for (const edited of [prefix + section.replace("41, 41 and 62", "41, 42 and 62"),
    prefix + section.replace("Accepted label: **Medium / interpretation**", "Accepted label: **Easy / recall**"), "No accepted section"]) {
    let rejected = false;
    try { await loadBoundaryCalibration(edited); } catch { rejected = true; }
    assert(rejected, "Modified B1 must stop before network use");
  }
});

Deno.test("B1 one-call comparison separates correct answers from a false difficulty rejection", async () => {
  const report = await boundaryDocument(), items = await loadBoundaryCalibration(report);
  const rows = boundaryVerdicts(items);
  const score = scoreCalibration(items, rows, "B1");
  equal(score.reference, "B1"); equal(score.solving_agreements, 2); equal(score.level_agreements, 2);
  equal(score.false_rejects, 0);
  const rejected = rows.map((v) => v.id === 1 ? { ...v, cognitive_level: "recall",
    application: { ...v.application, inferences: 0 } } : v);
  const disagreement = scoreCalibration(items, rejected, "B1");
  equal(disagreement.solving_agreements, 2); equal(disagreement.level_agreements, 1);
  equal(disagreement.false_rejects, 1);
  let calls = 0;
  const fetcher: typeof fetch = async (_url, init) => {
    calls++;
    const body = JSON.parse(String(init!.body));
    const data = JSON.parse(body.contents[0].parts[0].text);
    equal(data.length, 2);
    assert(!JSON.stringify(data).includes('"correct_index"'));
    return Response.json({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify({ items: rows.map(flatReview) }) }] } }] });
  };
  const result = await runCalibration(report, "private-key", "approved-model", fetcher, "B1");
  equal(result.reference, "B1"); equal(result.calls, 1); equal(calls, 1);
  calls = 0;
  let failed = false;
  try {
    await runCalibration(report, "private-key", "approved-model", () => { calls++; return Promise.resolve(new Response("private", { status: 503 })); }, "B1");
  } catch { failed = true; }
  assert(failed); equal(calls, 1);
  calls = 0;
  try { await runCalibration("Changed reference", "private-key", "approved-model", fetcher, "B1"); } catch { /* Expected before network. */ }
  equal(calls, 0);
});
