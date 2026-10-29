import { resolve, dirname, join } from "node:path";
import { applicationRules, evidenceFor, parsePlan, planSchema, reviewedConditionsMatch, renderPlan, mediumTask, sourceSpans } from "./planning.ts";
import type { TraceEvent } from "./planning.ts";
import { reviewRules, validReview } from "./review.ts";
import { checkBlueprint, parseCandidate, qualityPipeline, sourceAuditRequest } from "./pipeline.ts";
import type { ModelCall } from "./pipeline.ts";
import { candidate, fetchFixture, modelFixture, plannedObjective, request, reviewAtLevel, source } from "./quality_fixtures.ts";
import { grounded } from "./quality.ts";
import { generate, QuizError, tokenUsage, usageFields } from "./quiz.ts";
import { captureQuality, privateDestination, privateTracePath, traceCollector } from "../../../tests/ai_quality_trace.ts";

function assert(v: unknown, message = "Assertion failed"): asserts v { if (!v) throw new Error(message); }
function equal(a: unknown, b: unknown) { assert(JSON.stringify(a) === JSON.stringify(b), `${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
const single = () => ({ ...request(), counts: { multiple_choice: 1, true_false: 0, identification: 0, essay: 0 } });

function batchFixture(mixed = false) {
  const facts = ["Copper conducts electricity.", "Ice melts when heated.", "Roots absorb water.", "Leaves perform photosynthesis.",
    "Gravity attracts objects.", "Friction opposes motion.", "Sound travels through matter.", "Magnets attract iron.", "Light travels through vacuum.", "Clouds contain water droplets.", "Sensors record temperature."].slice(0, mixed ? 11 : 9);
  const answers = ["Copper", "Ice", "Roots", "Leaves", "Gravity", "Friction", "Sound", "Magnets", "Light", "Clouds", "Sensors"];
  const prompts = ["Which material conducts electricity?", "Which substance melts when heated?", "Which plant structures absorb water?",
    "Which organs perform photosynthesis?", "Which force attracts objects?", "Which force opposes motion?",
    "Which phenomenon travels through matter?", "Which objects attract iron?", "Which phenomenon travels through vacuum?",
    "Which formations contain water droplets?", "Explain what sensors record."];
  const input = { ...single(), texts: [facts.join(" ")], counts: mixed ? { multiple_choice: 6, true_false: 2, identification: 2, essay: 1 } : { ...single().counts, multiple_choice: facts.length } };
  const refs = sourceSpans(input.texts).map((s) => s.id);
  const stages: string[] = [];
  let remaining = 10000, malformed = false, expire = false;
  const call: ModelCall = async (system, data) => {
    if (system.includes("BLUEPRINT stage")) {
      stages.push("blueprint");
      return facts.map((fact, id) => {
        const type = !mixed || id < 6 ? "multiple_choice" : id < 8 ? "true_false" : id < 10 ? "identification" : "essay";
        return { type, difficulty: "easy", objective: fact, fact, plan: { ...plannedObjective().plan!, source_refs: refs,
          scenario: { facts: [], goal: type === "true_false" ? fact : prompts[id] },
          expected_outcome: type === "true_false" ? "true" : type === "essay" ? fact : answers[id] } };
      });
    }
    if (system.includes("GENERATION stage")) {
      const d = data as { objectives: { id: number; type: string; plan: unknown }[]; retained_plan_ids: number[]; render_from_plan?: boolean };
      assert(d.objectives.length <= 4);
      stages.push("generation");
      return d.objectives.map((o) => ({ objective_id: o.id, type: o.type, ...(d.render_from_plan ? {} : { prompt: prompts[o.id], correct_answer: answers[o.id] }), points: 1,
        explanation: "Supported by the lesson.",
        ...(d.retained_plan_ids.includes(o.id) ? {} : { plan: o.plan }),
        ...(o.type === "multiple_choice" ? { distractors: ["Stone", "Metal", "Glass"].map((text, i) => ({ text, category: "Supported alternatives",
          misconception: `Alternative ${i}`, why_incorrect: "Does not satisfy the stated rule." })) } :
          { rubric: [{ key_point: facts[o.id], points: 1 }] }) }));
    }
    stages.push("verification");
    assert(!system.includes("SOURCE AUDIT stage"));
    if (expire) remaining = 0;
    if (malformed) return null;
    const questions = data as { id: number; type: string; options?: string[] }[];
    assert(questions.length <= 4);
    return questions.map((q) => {
      const correct = q.type === "true_false" ? 0 : q.options?.indexOf(answers[q.id]) ?? -1;
      return { id: q.id, status: "one", choices: q.options ? [correct] : [], answer: q.type === "identification" ? answers[q.id] : q.type === "essay" ? facts[q.id] : "", cognitive_level: "recall", plausible_options: true,
        application: { conditions: [], inferences: 0, answer_leaked: false }, assumptions: [], answer_points: q.type === "essay" ? [facts[q.id]] : [],
        option_reviews: q.type === "multiple_choice" ? q.options!.map((_, index) => ({ index, defensible: index === correct ? "yes" : "no", same_category: true, plausible: true })) : [] };
    });
  };
  return { input, call, stages, timeLeft: () => remaining, breakVerifier: () => { malformed = true; }, expireAfterReview: () => { expire = true; } };
}

Deno.test("blueprint checks report distinct request plan and evidence failures", () => {
  const input = { ...single(), difficulty: "medium" as const };
  const o = plannedObjective(0, "multiple_choice", "medium");
  const value = { type: o.type, difficulty: o.difficulty, objective: o.objective, fact: o.fact, plan: o.plan };
  const spans = sourceSpans(input.texts);
  equal(checkBlueprint(value, input, o.type, spans).findings, []);
  const wrong = checkBlueprint({ ...value, difficulty: "easy", plan: { ...o.plan, steps: [] } }, input, o.type, spans).findings;
  for (const rule of ["blueprint_difficulty", "blueprint_plan", "blueprint_steps"]) assert(wrong.includes(rule));
  const refs = checkBlueprint({ ...value, plan: { ...o.plan, source_refs: ["missing"] } }, input, o.type, spans).findings;
  assert(refs.includes("blueprint_source_refs"));
  assert(checkBlueprint({ ...value, fact: "A fictional unsupported rule." }, input, o.type, spans).findings.includes("blueprint_unsupported_fact"));
  const extended = { ...input, texts: [source + " A separate background sentence adds context.".repeat(12)] };
  const extendedSpans = sourceSpans(extended.texts);
  const preceding = checkBlueprint({ ...value, plan: { ...o.plan, source_refs: [extendedSpans.at(-1)!.id] } }, extended, o.type, extendedSpans).findings;
  assert(preceding.includes("blueprint_fact_refs"));
});

Deno.test("generation waves contain at most two independently verified batches of four", async () => {
  const f = batchFixture();
  const result = await qualityPipeline(f.input, f.call, 12, f.timeLeft);
  equal(f.stages, ["blueprint", "generation", "generation", "verification", "verification", "generation", "verification"]);
  equal(result.questions.length, 9); equal(result.missing_by_type.multiple_choice, 0);
});

Deno.test("generation batches share thirteen calls and never spend a final call on unverified generation", async () => {
  const f = batchFixture(); f.breakVerifier();
  const result = await qualityPipeline(f.input, f.call, 12, f.timeLeft);
  equal(f.stages.length, 13); equal(f.stages.at(-1), "verification");
  equal(result.questions, []); equal(result.missing_by_type.multiple_choice, 9);
});

Deno.test("generation batching starts no late batch and returns only completed verified work", async () => {
  const f = batchFixture(); f.expireAfterReview();
  const result = await qualityPipeline(f.input, f.call, 12, f.timeLeft);
  equal(f.stages, ["blueprint", "generation", "generation", "verification"]);
  equal(result.questions.length, 4); equal(result.missing_by_type.multiple_choice, 5);
});

Deno.test("source references resolve only ordered adjacent spans of one file, including unspaced Unicode", () => {
  for (const content of [source, "词".repeat(800), "a".repeat(399) + "🙂" + "b".repeat(30)]) {
    const spans = sourceSpans([content, source]);
    const refs = spans.filter((s) => s.file === 0).slice(0, 2).map((s) => s.id);
    const evidence = evidenceFor(refs, spans);
    assert(evidence && grounded(evidence, [content]));
    equal(evidenceFor([refs[0], refs[0]], spans), null);
    equal(evidenceFor(["missing"], spans), null);
    equal(evidenceFor([refs[0], spans.find((s) => s.file === 1)!.id], spans), null);
    if (refs.length > 1) equal(evidenceFor([...refs].reverse(), spans), null);
  }
});

Deno.test("source spans retain complete bounded sentences and never relocate incorrect citations", () => {
  const first = "A short introduction ends here. ";
  const rule = "A supported rule " + "with conditions ".repeat(17) + "ends here.";
  const content = first.repeat(4) + rule + " Another supported rule ends here.";
  const spans = sourceSpans([content]);
  const supporting = spans.find((s) => s.text.includes(rule));
  assert(supporting);
  equal(evidenceFor([supporting.id], spans)!.includes(rule), true);
  const preceding = spans.find((s) => s.index === supporting.index - 1);
  assert(preceding && !evidenceFor([preceding.id], spans)!.includes(rule));
  equal(spans.map((s) => s.text).join(" "), content);
  equal(sourceSpans([content]), spans);
  for (const text of ["word ".repeat(350), "界".repeat(1100), "🙂".repeat(550)]) {
    const long = sourceSpans([text]);
    assert(long.every((s) => s.text.length <= 400 && s.text.length > 0));
    equal(long.map((s) => s.text).join(text.includes(" ") ? " " : ""), text.trim());
    assert(long.every((s) => !/^[\uDC00-\uDFFF]|[\uD800-\uDBFF]$/u.test(s.text)));
  }
});

Deno.test("canonical rendering separates context and material conditions and omits private proof", () => {
  const base = plannedObjective(0, "identification", "medium").plan!;
  const plan = { ...base, scenario: { context: ["An instructor is reviewing an example."], case: base.scenario.case, facts: [{ id: "f1", text: "The example uses stored database records." }], goal: "Which software manages these records?" },
    steps: [{ ...base.steps[0], facts: ["f1"], outcome: "DBMS" }], expected_outcome: "DBMS" };
  const rendered = renderPlan(plan, "identification")!;
  equal(rendered.prompt, "An instructor is reviewing an example. The example uses stored database records. [record A; record B] Read these records while keeping their stored values unchanged. Identify the requirement violated by this situation.");
  equal(rendered.accepted_answers, ["DBMS"]);
  assert(!String(rendered.prompt).includes("DBMS") && !String(rendered.prompt).includes("being identified"));
  const q = parseCandidate({ objective_id: 0, type: "identification", points: 1, explanation: "Checks the lesson.", plan, ...rendered },
    { ...plannedObjective(0, "identification", "medium"), plan }, { ...single(), difficulty: "medium" }, 12)!;
  assert(q && q.accepted_answers!.includes("Database Management System"));
  equal(applicationRules(q, plan), []);
});

Deno.test("canonical answer rendering rejects invalid boolean keys task justification and excessive prompts", () => {
  const plan = plannedObjective(0, "multiple_choice", "medium").plan!;
  equal(renderPlan(plan, "multiple_choice")!.correct_answer, plan.expected_outcome);
  equal(renderPlan(plan, "essay")!.sample_answer, plan.expected_outcome);
  equal(renderPlan({ ...plan, expected_outcome: "false" }, "true_false")!.correct_boolean, false);
  equal(renderPlan({ ...plan, expected_outcome: "not a boolean" }, "true_false"), null);
  equal(renderPlan({ ...plan, scenario: { ...plan.scenario, goal: "Identify it because the private rule gives the answer." } }, "identification"), null);
  equal(renderPlan({ ...plan, scenario: { ...plan.scenario, goal: "x".repeat(1001) } }, "multiple_choice"), null);
});

Deno.test("blind answer leakage is rejected even at Easy difficulty without changing the canonical key", () => {
  const o = plannedObjective(), q = parseCandidate(candidate(o), o, single(), 12)!;
  const correct = q.correct_index!;
  const verdict = { id: 0, status: "one", choices: [correct], answer: "", cognitive_level: "recall", plausible_options: true,
    application: { conditions: [], inferences: 0, answer_leaked: true }, assumptions: [], answer_points: [],
    option_reviews: q.options!.map((_, index) => ({ index, defensible: index === correct ? "yes" : "no", same_category: true, plausible: true })) };
  assert(validReview(verdict));
  assert(reviewRules(q, verdict, "easy").includes("verifier_answer_leak"));
  equal(q.correct_index, correct);
});

Deno.test("initial generation reuses the code-owned plan and rejects an unsolicited replacement", async () => {
  const fixture = modelFixture();
  const events: TraceEvent[] = [];
  let renders = 0;
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    // This case checks retained-plan repair; spare selection has separate coverage.
    if (system.includes("BLUEPRINT stage")) return (raw as unknown[]).slice(0, 1);
    if (system.includes("GENERATION stage")) {
      renders++;
      const retained = (data as { retained_plan_ids: number[] }).retained_plan_ids;
      assert((data as { objectives: object[] }).objectives.every((o) => !Object.hasOwn(o, "evidence")));
      const rows = raw as Record<string, unknown>[];
      if (renders === 1) {
        equal(retained, [0]); assert(!Object.hasOwn(rows[0], "plan"));
        return rows.map((v) => ({ ...v, plan: plannedObjective().plan }));
      }
      equal(retained, []);
      assert(Object.hasOwn(rows[0], "plan"));
    }
    return raw;
  }, 12, () => 10000, (e) => events.push(e));
  assert(events.some((e) => e.stage === "candidate" && (e.findings as string[]).includes("plan_invalid")));
  equal(renders, 2); equal(result.questions.length, 1);
  assert(!events.some((e) => e.stage === "spare"));
  equal(result.questions[0].options![result.questions[0].correct_index!], "SELECT");
});

Deno.test("a wire rejection repairs response format without relabelling the plan invalid or selecting a spare", async () => {
  const fixture = modelFixture(), events: TraceEvent[] = [];
  let renders = 0;
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    if (system.includes("GENERATION stage")) {
      renders++;
      if (renders === 1) return [null];
      const d = data as { retained_plan_ids: number[]; repairs: { errors: string[]; components: string[] }[] };
      equal(d.retained_plan_ids, [0]); equal(d.repairs[0].errors, ["candidate_wire"]); equal(d.repairs[0].components, ["format"]);
    }
    return await fixture(system, data, schema);
  }, 12, () => 10000, (e) => events.push(e));
  equal(renders, 2); equal(result.questions.length, 1);
  const failure = events.find((e) => e.stage === "candidate" && e.attempt === 1)!;
  equal(failure.findings, ["candidate_wire"]);
  assert(!events.some((e) => e.stage === "spare"));
});

Deno.test("a malformed repair response cannot erase an earlier Medium difficulty finding", async () => {
  const fixture = modelFixture();
  let renders = 0, reviews = 0;
  const result = await qualityPipeline({ ...single(), difficulty: "medium" }, async (system, data, schema) => {
    if (system.includes("GENERATION stage")) {
      renders++;
      if (renders === 2) return [null];
      if (renders === 3) {
        const d = data as { retained_plan_ids: number[]; repairs: { errors: string[]; observed_cognitive_level: string; difficulty_direction: string }[] };
        equal(d.retained_plan_ids, []);
        assert(d.repairs[0].errors.includes("verifier_difficulty") && d.repairs[0].errors.includes("candidate_wire"));
        equal(d.repairs[0].observed_cognitive_level, "recall"); equal(d.repairs[0].difficulty_direction, "too_easy");
      }
    }
    const raw = await fixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as unknown[]).slice(0, 1);
    if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => reviewAtLevel(v, ++reviews === 1 ? "recall" : "interpretation"));
    return raw;
  }, 12, () => 10000);
  equal(renders, 3); equal(result.questions.length, 1);
});

Deno.test("a real lesson fact with the wrong source reference is still rejected before generation", async () => {
  const intro = "An introductory sentence gives background. ".repeat(8);
  const rule = "SELECT retrieves database records.";
  const text = intro + rule + " More details provide additional background. ".repeat(5);
  const spans = sourceSpans([text]);
  const correct = spans.find((s) => s.text.includes(rule))!;
  const wrong = spans.find((s) => !s.text.includes(rule))!;
  assert(correct && wrong);
  const o = plannedObjective();
  let calls = 0;
  const result = await qualityPipeline({ ...single(), texts: [text] }, (system) => {
    calls++; assert(system.includes("BLUEPRINT stage"));
    return Promise.resolve([{ type: o.type, difficulty: o.difficulty, objective: o.objective, fact: rule,
      plan: { ...o.plan, source_refs: [wrong.id] } }]);
  }, 12, () => 10000);
  equal(calls, 1); equal(result.questions, []);
});

Deno.test("provider timing records bounded metadata on success provider error and deadline without content", async () => {
  const ok = await captureQuality(single(), "private-timing-key", "fixture-model", fetchFixture());
  const timing = ok.events.filter((e) => e.stage === "provider_timing");
  equal(timing.map((e) => e.purpose), ["blueprint", "generation", "verification"]);
  equal(new Set(timing.map((e) => e.call_id)).size, timing.length);
  assert(timing.every((e) => Number.isInteger(e.call_id) && Number(e.call_id) > 0));
  assert(timing.every((e) => Number(e.elapsed_ms) >= 0 && Number(e.request_bytes) > 0 && Number(e.response_bytes) > 0));
  const busy = await captureQuality(single(), "private-timing-key", "fixture-model", async () => new Response("private body", { status: 503 }));
  const failed = busy.events.find((e) => e.stage === "provider_timing")!;
  equal(failed.outcome, "AI_BUSY"); equal(failed.http_status, 503); equal(failed.response_bytes, null);
  const offline = await captureQuality(single(), "private-timing-key", "fixture-model", () => Promise.reject(new TypeError("private offline error")));
  equal(offline.events.find((e) => e.stage === "provider_timing")!.outcome, "AI_UNAVAILABLE");
  const deadline: TraceEvent[] = [];
  let calls = 0;
  try {
    await generate(single(), "private-timing-key", "fixture-model", Date.now() - 1, () => { calls++; throw new Error("Must not call"); }, (e) => deadline.push(e));
    throw new Error("Expected timeout");
  } catch (e) { assert(e instanceof QuizError && e.code === "AI_TIMEOUT"); }
  equal(calls, 0);
  const expired = deadline.find((e) => e.stage === "provider_timing")!;
  equal(expired.outcome, "AI_TIMEOUT"); equal(expired.timeout_scope, "overall_deadline"); equal(expired.limit_ms, 0);
  const serialized = JSON.stringify([...timing, failed, expired, ...offline.events.filter((e) => e.stage === "provider_timing")]);
  for (const privateText of ["private-timing-key", "private body", "source_refs", "scenario_facts", "correct_answer", source]) assert(!serialized.includes(privateText));
});

Deno.test("application plans require meaningful contrast references and dependent Hard steps", () => {
  const spans = sourceSpans([source]);
  const plan = plannedObjective(0, "multiple_choice", "medium").plan!;
  assert(parsePlan(plan, "medium", spans));
  equal(parsePlan({ ...plan, steps: [] }, "medium", spans), null);
  equal(parsePlan({ ...plan, contrast: { ...plan.contrast, outcome: plan.expected_outcome } }, "medium", spans), null);
  equal(parsePlan({ ...plan, contrast: { ...plan.contrast, replacement: plan.scenario.facts[0].text } }, "medium", spans), null);
  equal(parsePlan({ ...plan, steps: [{ ...plan.steps[0], facts: ["unknown"] }] }, "medium", spans), null);
  const hard = plannedObjective(0, "multiple_choice", "hard").plan!;
  assert(parsePlan(hard, "hard", spans));
  equal(parsePlan({ ...hard, steps: [hard.steps[0], { ...hard.steps[1], depends_on: [] }] }, "hard", spans), null);
});

Deno.test("plan output contract and parser retain nested array limits", () => {
  const schema = JSON.parse(JSON.stringify(planSchema));
  equal(schema.properties.source_refs.maxItems, 2);
  equal(schema.properties.scenario.properties.facts.maxItems, 4);
  equal(schema.properties.steps.maxItems, 3);
  equal(schema.properties.steps.items.properties.facts.maxItems, 4);
  equal(schema.properties.steps.items.properties.depends_on.maxItems, 3);
  const spans = sourceSpans([source]);
  const plan = plannedObjective(0, "multiple_choice", "medium").plan!;
  assert(parsePlan(plan, "medium", spans));
  const fourFacts = Array.from({ length: 4 }, (_, i) => ({ id: `f${i}`, text: `Scenario condition ${i}` }));
  const boundary = { ...plan, scenario: { ...plan.scenario, facts: fourFacts, case: { ...plan.scenario.case!, fact_id: fourFacts[0].id } },
    steps: [{ ...plan.steps[0], facts: fourFacts.map((f) => f.id) }],
    contrast: { ...plan.contrast, fact_id: fourFacts[0].id } };
  assert(parsePlan(boundary, "medium", spans));
  equal(parsePlan({ ...boundary, scenario: { ...boundary.scenario,
    facts: [...fourFacts, { id: "extra", text: "Additional scenario condition" }] } }, "medium", spans), null);
  equal(parsePlan({ ...boundary, steps: [{ ...boundary.steps[0], facts: [...boundary.steps[0].facts, "extra"] }] }, "medium", spans), null);
  equal(parsePlan({ ...plan, source_refs: ["s1.1", "s1.2", "s1.3"] }, "medium", spans), null);
  const hard = plannedObjective(0, "multiple_choice", "hard").plan!;
  equal(parsePlan({ ...hard, steps: [...hard.steps, hard.steps[0], hard.steps[1]] }, "hard", spans), null);
  equal(parsePlan({ ...hard, steps: [hard.steps[0], { ...hard.steps[1],
    depends_on: ["one", "two", "three", "four"] }] }, "hard", spans), null);
});

Deno.test("unsupported concept rule is rejected before generation despite valid reference IDs", async () => {
  const fixture = modelFixture();
  let calls = 0;
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    calls++;
    const raw = await fixture(system, data, schema) as Record<string, unknown>[];
    return [{ ...raw[0], fact: "A fabricated rule not stated in this material." }];
  }, 12, () => 10000);
  equal(calls, 1); equal(result.questions, []);
});

Deno.test("blueprint stage rejects mixed question fields without invoking generation", async () => {
  const fixture = modelFixture();
  let calls = 0;
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    calls++;
    assert(system.includes("PLANNING ONLY:") && !system.includes("MC: produce"));
    const raw = await fixture(system, data, schema) as Record<string, unknown>[];
    return raw.map((o) => ({ ...o, multiple_choice: { correct_answer: "Unexpected question" }, explanation: "Unexpected explanation" }));
  }, 12, () => 10000);
  equal(calls, 1); equal(result.questions.length, 0); equal(result.missing_by_type.multiple_choice, 1);
});

Deno.test("rendered questions retain required scenario facts, bind the key and use code-owned evidence", () => {
  const o = plannedObjective(0, "multiple_choice", "medium");
  const input = { ...single(), difficulty: "medium" as const };
  const q = parseCandidate(candidate(o), o, input, 12)!;
  assert(q && grounded(q.evidence!, input.texts));
  equal(applicationRules(q, o.plan!), []);
  assert(reviewedConditionsMatch(o.plan!, [String(renderPlan(o.plan!, "multiple_choice")!.prompt)]));
  assert(!reviewedConditionsMatch(o.plan!, ["An unrelated quoted part of the stem"]));
  assert(applicationRules({ ...q, prompt: "Which SQL command?" }, o.plan!).includes("scenario_missing"));
  assert(applicationRules({ ...q, correct_index: (q.correct_index! + 1) % 4 }, o.plan!).includes("plan_answer_mismatch"));
  equal(parseCandidate({ ...candidate(o), evidence: "Invented quotation" }, o, input, 12), null);
  const bad = candidate(o);
  bad.distractors = (bad.distractors as Record<string, unknown>[]).map((d) => ({ ...d, category: "Unrelated tools" }));
  // A model label alone cannot establish or disprove semantic option quality.
  assert(parseCandidate(bad, o, input, 12));
});

Deno.test("all review dimensions are recorded even when key, difficulty and distractors fail together", async () => {
  const fixture = modelFixture();
  const o = plannedObjective();
  await fixture("GENERATION stage", { objectives: [o] }, {});
  const q = parseCandidate(candidate(o), o, single(), 12)!;
  const rows = await fixture("Blindly solve", [{ id: 0, type: q.type, prompt: q.prompt, options: q.options }], {}) as Record<string, unknown>[];
  const v = { ...rows[0], choices: [(q.correct_index! + 1) % 4], plausible_options: false };
  assert(validReview(v));
  const findings = reviewRules(q, v, "medium");
  for (const rule of ["verifier_key_mismatch", "verifier_difficulty", "verifier_distractors", "verifier_ambiguity"]) assert(findings.includes(rule));
});

Deno.test("source audit payload withholds both answer keys, plans and explanations", () => {
  const o = plannedObjective();
  const q = parseCandidate(candidate(o), o, single(), 12)!;
  const audit = sourceAuditRequest([{ question: q, objective: o }], sourceSpans([source]));
  const payload = JSON.stringify(audit.data);
  for (const field of ["correct_index", "expected_outcome", "explanation", "accepted_answers", "sample_answer", "rubric"]) assert(!payload.includes(field));
  assert(audit.data.source.length > 0);
});

Deno.test("unresolved source audit withholds rather than rerolls or flips an answer", async () => {
  const fixture = modelFixture();
  let renders = 0;
  let audits = 0;
  const trace: TraceEvent[] = [];
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("GENERATION stage")) renders++;
    if (system.includes("SOURCE AUDIT stage")) {
      audits++;
      return (raw as Record<string, unknown>[]).map((v) => ({ ...v, support: "insufficient", source_refs: [] }));
    }
    if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => ({ ...v, status: "none", choices: [] }));
    return raw;
  }, 12, () => 10000, (e) => trace.push(e));
  equal(renders, 1); equal(audits, 1); equal(result.questions, []); equal(result.missing_by_type.multiple_choice, 1);
  assert(trace.some((e) => e.stage === "source_audit" && e.disposition === "unresolved"));
  const attempts = trace.filter((e) => typeof e.attempt === "number").map((e) => e.attempt as number);
  assert(Math.max(...attempts) <= 3);
});

Deno.test("source-supported alternative consumes a repair action and never silently rewrites the key", async () => {
  const fixture = modelFixture();
  let renders = 0;
  let blind = 0;
  const events: TraceEvent[] = [];
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("GENERATION stage")) renders++;
    if (system.includes("SOURCE AUDIT stage") || (system.includes("Blindly solve") && ++blind === 1)) {
      return (raw as Record<string, unknown>[]).map((v) => {
        const index = ((v.choices as number[])[0] + 1) % 4;
        return { ...v, choices: [index], option_reviews: (v.option_reviews as Record<string, unknown>[])
          .map((o) => ({ ...o, defensible: o.index === index ? "yes" : "no" })) };
      });
    }
    return raw;
  }, 12, () => 10000, (e) => events.push(e));
  equal(renders, 2); equal(result.questions.length, 1);
  equal(result.questions[0].options![result.questions[0].correct_index!], "SELECT");
  assert(events.some((e) => e.disposition === "supports_alternative"));
});

Deno.test("a malformed replacement cannot evict an already verified question", async () => {
  const fixture = modelFixture();
  let renders = 0;
  let tfReviews = 0;
  const result = await qualityPipeline(request(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("GENERATION stage") && (data as { objectives: { id: number }[] }).objectives.some((o) => o.id === 0)) {
      renders++;
      return (raw as Record<string, unknown>[]).map((v) => v.objective_id !== 0 ? v : renders === 1 ?
        { ...v, plan: null } : renders === 2 ? { ...v, prompt: "A primary key uniquely identifies rows." } : v);
    }
    if (system.includes("Blindly solve") && !system.includes("SOURCE AUDIT stage")) tfReviews += (data as { type: string }[]).filter((q) => q.type === "true_false").length;
    return raw;
  }, 12, () => 10000);
  equal(tfReviews, 1); equal(result.questions.filter((q) => q.type === "true_false").length, 1);
  equal(result.questions.length, 4);
});

Deno.test("options-only repair cannot silently change the stem, plan or correct answer", async () => {
  const fixture = modelFixture();
  const events: TraceEvent[] = [];
  let renders = 0;
  let reviews = 0;
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema) as Record<string, unknown>[];
    if (system.includes("BLUEPRINT stage")) return raw.slice(0, 1);
    if (system.includes("GENERATION stage") && ++renders === 2) return raw.map((v) => ({ ...v,
      prompt: "Unexpected replacement stem", correct_answer: "INSERT", plan: { ...(v.plan as object), expected_outcome: "INSERT" } }));
    if (system.includes("Blindly solve") && ++reviews === 1) return raw.map((v) => ({ ...v, plausible_options: false }));
    return raw;
  }, 12, () => 10000, (e) => events.push(e));
  equal(renders, 3); equal(result.questions.length, 1);
  assert(!events.some((e) => e.stage === "spare"));
  assert(events.some((e) => e.stage === "candidate" && e.attempt === 2 && (e.findings as string[]).includes("candidate_wire")));
  equal(result.questions[0].prompt, "Which SQL operation retrieves database records?");
  equal(result.questions[0].options![result.questions[0].correct_index!], "SELECT");
});

Deno.test("trace observer failures or mutations do not change normal results", async () => {
  const fixture = modelFixture();
  const result = await qualityPipeline(single(), fixture, 12, () => 10000, (event) => {
    if (event.stage === "result") (event.result as { questions: unknown[] }).questions.length = 0;
    else throw new Error("Private observer failure");
  });
  equal(result.questions.length, 1);
});

Deno.test("private trace collector is bounded and rejects destinations inside workspace", () => {
  const trace = traceCollector(60);
  const event = { stage: "sample" };
  trace.observe(event); event.stage = "changed";
  trace.observe({ stage: "x".repeat(100) });
  equal(trace.events[0].stage, "sample"); equal(trace.dropped, 1);
  const root = resolve("fixture-workspace");
  let rejected = false;
  try { privateTracePath(join(root, "backend", "trace.json"), root); } catch { rejected = true; }
  assert(rejected);
  equal(privateTracePath(join(dirname(root), "private-trace.json"), root), resolve(dirname(root), "private-trace.json"));
});

Deno.test("private runner captures mocked failures/success without transport credentials", async () => {
  const report = await captureQuality(single(), "private-api-key", "fixture-model", fetchFixture());
  assert(report.result && report.result.questions.length === 1);
  assert(report.events.some((e) => e.stage === "start" && e.model === "fixture-model"));
  assert(!JSON.stringify(report).includes("private-api-key"));
  const failure = await captureQuality(single(), "private-api-key", "fixture-model", () => Promise.resolve(new Response("private transport diagnostic", { status: 429 })));
  equal(failure.error, "AI_BUSY");
  assert(!JSON.stringify(failure).includes("private transport diagnostic"));
});

Deno.test("private traces preserve rejected blueprint shape and finish reason without thoughts, credentials or retries", async () => {
  const key = "private-api-key";
  const cases = [
    { finish: "STOP", text: '{"blueprint":[]}', outcome: "invalid_envelope", shape: "object" },
    { finish: "MAX_TOKENS", text: '[{"unfinished":', outcome: "incomplete", shape: undefined },
    { finish: "STOP", text: `{${key} Bearer secret-token ${"x".repeat(70000)}`, outcome: "invalid_text_json", shape: undefined },
  ];
  for (const c of cases) {
    let calls = 0;
    const report = await captureQuality(single(), key, "fixture-model", async () => {
      calls++;
      return Response.json({ candidates: [{ finishReason: c.finish, content: { parts: [
        { thought: true, text: "Hidden thought content" }, { text: c.text },
      ] } }] });
    });
    equal(calls, 1); equal(report.error, "AI_BAD_OUTPUT");
    assert(report.events.some((e) => e.stage === "provider_status" && e.http_status === 200));
    const event = report.events.find((e) => e.stage === "provider_response");
    assert(event && event.purpose === "blueprint");
    equal(event.outcome, c.outcome); equal(event.finish_reason, c.finish); equal(event.parsed_shape, c.shape);
    equal(event.text_characters, c.text.length); equal(event.truncated, c.text.length > 65536);
    assert(typeof event.raw_text === "string" && event.raw_text.length <= 65536);
    if (c.shape === "object") equal(event.raw_text, c.text);
    const serialized = JSON.stringify(report);
    assert(!serialized.includes(key) && !serialized.includes("secret-token") && !serialized.includes("Hidden thought content"));
  }
  for (const [body, outcome] of [
    [JSON.stringify({ promptFeedback: { blockReason: "SAFETY" } }), "missing_candidates"],
    [`Invalid envelope ${key}`, "decode_failed"],
  ]) {
    let calls = 0;
    const report = await captureQuality(single(), key, "fixture-model", async () => {
      calls++; return new Response(body, { status: 200 });
    });
    equal(calls, 1); equal(report.error, "AI_BAD_OUTPUT");
    assert(report.events.some((e) => e.stage === "provider_response" && e.outcome === outcome));
    assert(!JSON.stringify(report).includes(key));
  }
});

Deno.test("private destination checks resolved parents, Git ancestors and permission errors before AI work", async () => {
  const root = resolve("fixture-workspace");
  const external = join(dirname(root), "fixture-private");
  const missing = () => Promise.reject(new Deno.errors.NotFound());
  equal(await privateDestination(join(external, "trace.json"), { realPath: async () => external, lstat: missing }, root), join(external, "trace.json"));
  for (const io of [
    { realPath: async () => root, lstat: missing },
    { realPath: async () => external, lstat: async () => ({}) },
    { realPath: async () => external, lstat: () => Promise.reject(new Deno.errors.PermissionDenied()) },
  ]) {
    let rejected = false;
    try { await privateDestination(join(external, "trace.json"), io, root); } catch { rejected = true; }
    assert(rejected);
  }
});


Deno.test("deadline admission skips a batch without enough time for both calls", async () => {
  const f = batchFixture();
  const events: TraceEvent[] = [];
  const result = await qualityPipeline(f.input, f.call, 12, () => 9999, (e) => events.push(e));
  equal(f.stages, ["blueprint"]);
  equal(result.questions.length, 0);
  assert(events.some((e) => e.stage === "schedule_deferred"));
});

Deno.test("late timeout preserves verified work but excludes the interrupted batch", async () => {
  const f = batchFixture();
  let reviews = 0;
  const events: TraceEvent[] = [];
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    if (system.includes("Blindly solve") && ++reviews === 2) throw new QuizError("AI_TIMEOUT");
    return await f.call(system, data, schema);
  }, 12, f.timeLeft, (e) => events.push(e));
  equal(result.questions.length, 4);
  equal(result.missing_by_type.multiple_choice, 5);
  equal(result.dropped_by_type.multiple_choice, 5);
  assert(events.some((e) => e.stage === "timeout_partial"));
  assert(events.some((e) => e.stage === "result"));
});

Deno.test("timeout before any verified work remains an error", async () => {
  const f = batchFixture();
  let failed = false;
  try {
    await qualityPipeline(f.input, async (system, data, schema) => {
      if (system.includes("Blindly solve")) throw new QuizError("AI_TIMEOUT");
      return await f.call(system, data, schema);
    }, 12, f.timeLeft);
  } catch (error) { failed = error instanceof QuizError && error.code === "AI_TIMEOUT"; }
  assert(failed);
});

Deno.test("source audit waits for first-pass coverage and never rerolls unresolved disputes", async () => {
  const f = batchFixture();
  const order: string[] = [];
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    if (system.includes("SOURCE AUDIT stage")) {
      order.push("audit");
      return null;
    }
    const raw = await f.call(system, data, schema);
    if (system.includes("GENERATION stage")) order.push("generation");
    if (system.includes("Blindly solve")) {
      order.push("verification");
      return (raw as Record<string, unknown>[]).map((v) => ({ ...v, status: "none", choices: [] }));
    }
    return raw;
  }, 12, f.timeLeft);
  equal(order.filter((s) => s === "generation").length, 3);
  equal(order.filter((s) => s === "verification").length, 3);
  equal(order.at(-1), "audit");
  equal(result.questions.length, 0);
});

Deno.test("observed slow verification prevents starting an underfunded next batch", async () => {
  const f = batchFixture();
  let remaining = 110000, generations = 0;
  const events: TraceEvent[] = [];
  let releaseGeneration!: () => void;
  const reviewed = new Promise<void>((resolve) => { releaseGeneration = resolve; });
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    const raw = await f.call(system, data, schema);
    // Hold the peer generation until the slow review has consumed the shared deadline.
    if (system.includes("GENERATION stage") && ++generations === 2) await reviewed;
    if (system.includes("Blindly solve")) { remaining = 10000; releaseGeneration(); }
    return raw;
  }, 12, () => remaining, (e) => events.push(e));
  equal(f.stages, ["blueprint", "generation", "generation", "verification"]);
  equal(result.questions.length, 4);
  assert(events.some((e) => e.stage === "schedule_deferred" &&
    typeof e.required_ms === "number" && e.required_ms > 10000 && e.remaining_ms === 10000));
});

Deno.test("generation that consumes the remaining verification reserve is never accepted", async () => {
  const f = batchFixture();
  let remaining = 110000;
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    const raw = await f.call(system, data, schema);
    if (system.includes("GENERATION stage")) remaining = 3000;
    return raw;
  }, 12, () => remaining);
  equal(f.stages, ["blueprint", "generation", "generation"]);
  equal(result.questions.length, 0);
  equal(result.missing_by_type.multiple_choice, 9);
});

Deno.test("non-timeout provider errors are not hidden by partial recovery", async () => {
  const f = batchFixture();
  let reviews = 0, failed = false;
  try {
    await qualityPipeline(f.input, async (system, data, schema) => {
      if (system.includes("Blindly solve") && ++reviews === 2) throw new QuizError("AI_UNAVAILABLE");
      return await f.call(system, data, schema);
    }, 12, f.timeLeft);
  } catch (error) { failed = error instanceof QuizError && error.code === "AI_UNAVAILABLE"; }
  assert(failed);
});


Deno.test("category descriptions do not change parsed options or establish semantic quality", () => {
  const o = plannedObjective();
  const original = candidate(o), varied = candidate(o);
  varied.distractors = (varied.distractors as Record<string, unknown>[]).map((d, i) => ({ ...d,
    category: ["SQL operations", "Record changes", "Database commands"][i] }));
  const findings: string[] = [];
  equal(parseCandidate(varied, o, single(), 12, findings), parseCandidate(original, o, single(), 12));
  equal(findings, []);
});

Deno.test("candidate parser reports bounded field-specific failures without private values", () => {
  const o = plannedObjective(), c = candidate(o);
  const ds = c.distractors as Record<string, unknown>[];
  const cases: [Record<string, unknown>, string][] = [
    [{ ...c, objective_id: 999 }, "candidate_identity"],
    [{ ...c, prompt: "" }, "candidate_prompt"],
    [{ ...c, explanation: "x".repeat(501) }, "candidate_explanation"],
    [{ ...c, points: 0 }, "candidate_points"],
    [{ ...c, private_extra: "Private diagnostic marker" }, "candidate_fields"],
    [{ ...c, correct_answer: "" }, "candidate_correct_answer"],
    [{ ...c, distractors: ds.slice(1) }, "candidate_distractor_count"],
    [{ ...c, distractors: [{ ...ds[0], extra: true }, ...ds.slice(1)] }, "candidate_distractor_fields"],
    [{ ...c, distractors: [{ ...ds[0], text: "" }, ...ds.slice(1)] }, "candidate_distractor_text"],
    [{ ...c, distractors: [{ ...ds[0], category: "" }, ...ds.slice(1)] }, "candidate_distractor_category"],
    [{ ...c, distractors: [{ ...ds[0], misconception: "" }, ...ds.slice(1)] }, "candidate_distractor_misconception"],
    [{ ...c, distractors: [{ ...ds[0], why_incorrect: "" }, ...ds.slice(1)] }, "candidate_distractor_reason"],
    [{ ...c, distractors: ds.map((d) => ({ ...d, misconception: "Repeated misconception" })) }, "candidate_duplicate_misconception"],
  ];
  for (const [value, expected] of cases) {
    const findings: string[] = [];
    equal(parseCandidate(value, o, single(), 12, findings), null);
    equal(findings, [expected]);
  }
  for (const [type, key, invalid, expected] of [
    ["true_false", "correct_boolean", "true", "candidate_boolean"],
    ["identification", "accepted_answers", [], "candidate_accepted_answers"],
    ["essay", "sample_answer", "", "candidate_sample_answer"],
    ["essay", "rubric", [], "candidate_rubric"],
  ] as const) {
    const objective = plannedObjective(0, type), findings: string[] = [];
    equal(parseCandidate({ ...candidate(objective), [key]: invalid }, objective, single(), 12, findings), null);
    equal(findings, [expected]);
  }
});

Deno.test("label variations reach independent blind review rather than being dropped as shape errors", async () => {
  const fixture = modelFixture();
  let blindCalls = 0;
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("GENERATION stage")) return (raw as Record<string, unknown>[]).map((v) => ({ ...v,
      distractors: (v.distractors as Record<string, unknown>[]).map((d) => ({ ...d, category: "Alternative SQL action" })) }));
    if (system.includes("Blindly solve")) blindCalls++;
    return raw;
  }, 12, () => 110000);
  equal(blindCalls, 1); equal(result.questions.length, 1);
  equal(result.missing_by_type.multiple_choice, 0);
});

Deno.test("matching labels cannot bypass independent semantic distractor rejection", async () => {
  const fixture = modelFixture();
  let blindCalls = 0;
  const events: TraceEvent[] = [];
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as unknown[]).slice(0, 1);
    if (system.includes("Blindly solve")) {
      blindCalls++;
      return (raw as Record<string, unknown>[]).map((v) => ({ ...v,
        option_reviews: (v.option_reviews as Record<string, unknown>[]).map((r) => ({ ...r, same_category: false })) }));
    }
    return raw;
  }, 12, () => 110000, (e) => events.push(e));
  equal(blindCalls, 3); equal(result.questions, []);
  equal(result.missing_by_type.multiple_choice, 1);
  assert(events.some((e) => e.stage === "blind_review" && (e.findings as string[]).includes("verifier_distractors")));
});

Deno.test("specific candidate diagnostics reach format repair without retaining obsolete shape errors", async () => {
  const fixture = modelFixture();
  let generations = 0;
  const events: TraceEvent[] = [];
  const result = await qualityPipeline(single(), async (system, data, schema) => {
    if (system.includes("GENERATION stage") && ++generations === 2) {
      const repairs = (data as { repairs: { errors: string[]; components: string[] }[] }).repairs;
      equal(repairs[0].errors, ["candidate_distractor_reason"]);
      equal(repairs[0].components, ["format"]);
    }
    const raw = await fixture(system, data, schema);
    if (system.includes("GENERATION stage") && generations === 1) return (raw as Record<string, unknown>[]).map((v) => ({ ...v,
      distractors: (v.distractors as Record<string, unknown>[]).map((d) => ({ ...d, why_incorrect: "" })) }));
    return raw;
  }, 12, () => 110000, (e) => events.push(e));
  equal(generations, 2); equal(result.questions.length, 1);
  const finish = events.find((e) => e.stage === "finish")!;
  const failures = (finish.stats as { failures: Record<string, number> }).failures;
  equal(failures.candidate_distractor_reason, 1);
  assert(!Object.hasOwn(failures, "candidate_shape"));
});


Deno.test("Medium task templates constrain response intent without certifying difficulty", () => {
  const base = plannedObjective(0, "multiple_choice", "medium").plan!;
  for (const kind of ["outcome", "decision", "diagnosis"] as const) {
    const plan = { ...base, task_kind: kind, scenario: { ...base.scenario, goal: "Classify the command category." } };
    const rendered = renderPlan(plan, "multiple_choice")!;
    assert(String(rendered.prompt).endsWith(mediumTask(kind, "multiple_choice")!));
    assert(!String(rendered.prompt).includes("Classify the command category"));
  }
  equal(mediumTask("outcome", "identification"), null);
  equal(mediumTask("diagnosis", "true_false"), null);
  equal(renderPlan({ ...base, task_kind: "outcome" }, "identification"), null);
  equal(renderPlan({ ...base, task_kind: "diagnosis" }, "true_false"), null);
});

Deno.test("context may be omitted by the solver but every material condition must be covered", () => {
  const base = plannedObjective(0, "multiple_choice", "medium").plan!;
  const facts = [{ id: "f1", text: "The column stores several phone numbers in one field." },
    { id: "f2", text: "The proposed change separates phone numbers into individual values." }];
  const context = ["A database table is being evaluated during normalization."];
  const plan = { ...base, scenario: { ...base.scenario, facts, context },
    steps: [{ ...base.steps[0], facts: ["f1", "f2"] }] };
  assert(parsePlan(plan, "medium", sourceSpans([source])));
  assert(reviewedConditionsMatch(plan, [String(renderPlan(plan, "multiple_choice")!.prompt)]));
  assert(!reviewedConditionsMatch(plan, [facts[0].text]));
  assert(!reviewedConditionsMatch(plan, context));
  assert(!reviewedConditionsMatch(plan, [...facts.map((f) => f.text), ...context]));
  const rendered = renderPlan(plan, "multiple_choice")!;
  assert(String(rendered.prompt).includes(context[0]));
  assert(facts.every((f) => String(rendered.prompt).includes(f.text)));
});

Deno.test("Medium plan rejects missing task intent unused material facts and context-index dependencies", () => {
  const base = plannedObjective(0, "multiple_choice", "medium").plan!;
  const spans = sourceSpans([source]);
  const { task_kind: _task, ...missing } = base;
  equal(parsePlan(missing, "medium", spans), null);
  equal(parsePlan({ ...base, task_kind: "recall" }, "medium", spans), null);
  equal(parsePlan({ ...base, scenario: { ...base.scenario, facts: [...base.scenario.facts,
    { id: "unused", text: "An additional material condition is stated here." }] } }, "medium", spans), null);
  equal(parsePlan({ ...base, scenario: { ...base.scenario, context: ["Background setup for a class exercise."] },
    steps: [{ ...base.steps[0], facts: ["context0"] }] }, "medium", spans), null);
  equal(parsePlan({ ...base, scenario: { ...base.scenario, context: ["a", "b", "c"] } }, "medium", spans), null);
});

Deno.test("Medium missing material coverage has a distinct verifier code and remains excluded", async () => {
  const fixture = modelFixture();
  const events: TraceEvent[] = [];
  const result = await qualityPipeline({ ...single(), difficulty: "medium" }, async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as unknown[]).slice(0, 1);
    if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => ({
      ...reviewAtLevel(v, "interpretation"), application: { conditions: [], inferences: 1, answer_leaked: false } }));
    return raw;
  }, 12, () => 110000, (e) => events.push(e));
  equal(result.questions, []);
  assert(events.some((e) => e.stage === "blind_review" && (e.findings as string[]).includes("verifier_conditions")));
});


Deno.test("Medium solver can omit decorative context while independently covering material premises", async () => {
  const fixture = modelFixture();
  const material = "[record A; record B] Read these records while keeping their stored values unchanged.";
  const result = await qualityPipeline({ ...single(), difficulty: "medium" }, async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as Record<string, unknown>[]).slice(0, 1).map((v) => {
      const plan = v.plan as NonNullable<ReturnType<typeof plannedObjective>["plan"]>;
      return { ...v, plan: { ...plan, scenario: { ...plan.scenario, context: ["An instructor is reviewing a practice example."] } } };
    });
    if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => ({
      ...reviewAtLevel(v, "interpretation"), application: { conditions: [material], inferences: 1, answer_leaked: false } }));
    return raw;
  }, 12, () => 110000);
  equal(result.questions.length, 1);
  equal(result.missing_by_type.multiple_choice, 0);
  assert(result.questions[0].prompt.includes("An instructor is reviewing a practice example."));
});


Deno.test("mixed eleven-question first pass uses eight calls and reviews direct TF/ID without generation", async () => {
  const f = batchFixture(true), events: TraceEvent[] = [];
  let localReview = false;
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    if (system.includes("Blindly solve") && (data as { type: string }[]).every((q) => q.type !== "multiple_choice" && q.type !== "essay")) {
      localReview = true;
      equal((schema.items as { properties: { option_reviews: { maxItems: number } } }).properties.option_reviews.maxItems, 0);
    }
    return await f.call(system, data, schema);
  }, 12, f.timeLeft, (e) => events.push(e));
  equal(result.questions.length, 11);
  equal(result.missing_by_type, { multiple_choice: 0, true_false: 0, identification: 0, essay: 0 });
  equal(f.stages.length, 8); assert(localReview);
  const batches = events.filter((e) => e.stage === "generation_batch");
  equal(batches.find((e) => e.construction === "blueprint")!.slots, [6, 7, 8, 9]);
  equal(batches[0].question_type, "multiple_choice");
  equal(batches[1].question_type, "essay");
  assert(batches.filter((e) => e.construction === "provider").every((e) => ["multiple_choice", "essay"].includes(String(e.question_type))));
  equal((events.find((e) => e.stage === "finish")!.stats as { peak_inflight: number }).peak_inflight, 2);
});

Deno.test("provider batches overlap with at most two calls in flight and all work joined", async () => {
  const f = batchFixture();
  let active = 0, peak = 0, firstGenerations = 0;
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    active++; peak = Math.max(peak, active);
    try {
      if (system.includes("GENERATION stage") && firstGenerations < 2) {
        firstGenerations++;
        await Promise.resolve();
        equal(firstGenerations, 2);
      }
      return await f.call(system, data, schema);
    } finally { active--; }
  }, 12, f.timeLeft);
  equal(result.questions.length, 9); equal(peak, 2); equal(active, 0);
});

Deno.test("parallel failures join both workers and prefer a provider failure over timeout", async () => {
  const f = batchFixture();
  let active = 0, completed = 0, code = "";
  try {
    await qualityPipeline(f.input, async (system, data, schema) => {
      if (!system.includes("GENERATION stage")) return await f.call(system, data, schema);
      active++;
      try {
        await Promise.resolve();
        const first = (data as { objectives: { id: number }[] }).objectives[0].id === 0;
        throw new QuizError(first ? "AI_TIMEOUT" : "AI_BUSY");
      } finally { active--; completed++; }
    }, 12, f.timeLeft);
  } catch (error) { if (error instanceof QuizError) code = error.code; }
  equal(code, "AI_BUSY"); equal(active, 0); equal(completed, 2);
});

Deno.test("direct TF and identification candidates still fail closed on malformed blind results", async () => {
  const f = batchFixture(true);
  const result = await qualityPipeline(f.input, async (system, data, schema) => {
    if (system.includes("Blindly solve")) return null;
    return await f.call(system, data, schema);
  }, 12, f.timeLeft);
  equal(result.questions, []);
  equal(result.missing_by_type, f.input.counts);
});

Deno.test("Medium concrete inputs remain repeated literals bound to the material contrast pivot", () => {
  const base = plannedObjective(0, "multiple_choice", "medium").plan!;
  const plan = { ...base, scenario: { ...base.scenario, case: { fact_id: "f1", inputs: ["K8", "K8", "K9"], action: "Store the proposed rows." } } };
  const spans = sourceSpans([source]);
  assert(parsePlan(plan, "medium", spans));
  const rendered = renderPlan(plan, "multiple_choice")!;
  assert(String(rendered.prompt).includes("[K8; K8; K9] Store the proposed rows."));
  const { case: _case, ...missing } = plan.scenario;
  equal(parsePlan({ ...plan, scenario: missing }, "medium", spans), null);
  for (const patch of [{ fact_id: "missing" }, { inputs: ["one"] }, { inputs: Array(7).fill("x") },
    { inputs: ["x".repeat(81), "y"] }, { action: "" }])
    equal(parsePlan({ ...plan, scenario: { ...plan.scenario, case: { ...plan.scenario.case, ...patch } } }, "medium", spans), null);
});


const measuredUsage = { promptTokenCount: 100, cachedContentTokenCount: 20, candidatesTokenCount: 10, thoughtsTokenCount: 5, totalTokenCount: 115 };
async function measuredResponse(response: Response, usageMetadata: unknown = measuredUsage) {
  return Response.json({ ...await response.json(), usageMetadata });
}

Deno.test("usage diagnostics accept only nonnegative safe integers and retain unknowns", () => {
  equal(tokenUsage(measuredUsage), measuredUsage);
  for (const value of [undefined, null, [], "private text", { promptTokenCount: -1, cachedContentTokenCount: 1.5,
    candidatesTokenCount: "12", thoughtsTokenCount: Number.MAX_SAFE_INTEGER + 1, totalTokenCount: Infinity }]) {
    equal(Object.values(tokenUsage(value)), [null, null, null, null, null]);
  }
  equal(tokenUsage({ promptTokenCount: 0 }).promptTokenCount, 0);
});

Deno.test("usage summary totals every successful call without changing questions", async () => {
  const fixture = fetchFixture();
  const measured = await captureQuality(single(), "private-usage-key", "fixture-model", async (...args) => measuredResponse(await fixture(...args)));
  const baseline = await captureQuality(single(), "private-usage-key", "fixture-model", fetchFixture());
  equal(measured.error, null); equal(measured.summary.provider_calls, 3);
  equal(measured.summary.calls_missing_usage, 0); equal(measured.summary.returned, 1);
  equal(measured.summary.returned_by_type.multiple_choice, 1);
  assert(measured.summary.elapsed_ms >= 0);
  equal(measured.result!.questions[0].prompt, baseline.result!.questions[0].prompt);
  for (const field of usageFields) equal(measured.summary.tokens[field], {
    observed_total: measuredUsage[field] * 3, observed_calls: 3, missing_calls: 0,
  });
  for (const event of measured.events.filter((e) => e.stage === "provider_timing")) {
    equal(event.usage, measuredUsage); equal(event.model, "fixture-model");
    assert(!JSON.stringify(event).includes("private-usage-key"));
  }
  equal(baseline.summary.tokens.promptTokenCount, { observed_total: null, observed_calls: 0, missing_calls: 3 });
  equal(baseline.summary.calls_missing_usage, 3);
});

Deno.test("rejected candidate envelopes retain observed usage before validation", async () => {
  for (const body of [{ usageMetadata: measuredUsage }, { usageMetadata: measuredUsage,
    candidates: [{ finishReason: "MAX_TOKENS", content: { parts: [{ text: "invalid" }] } }] },
    { usageMetadata: measuredUsage, candidates: [{ finishReason: "STOP", content: { parts: [{ text: "invalid json" }] } }] }]) {
    const report = await captureQuality(single(), "private-usage-key", "fixture-model", async () => Response.json(body));
    equal(report.error, "AI_BAD_OUTPUT"); equal(report.summary.provider_calls, 1);
    equal(report.summary.tokens.promptTokenCount.observed_total, 100);
    equal(report.summary.returned, 0); equal(report.summary.error, report.error);
  }
});

Deno.test("malformed usage and throwing observers do not affect generation", async () => {
  const fixture = fetchFixture();
  const report = await captureQuality(single(), "private-usage-key", "fixture-model", async (...args) =>
    measuredResponse(await fixture(...args), { promptTokenCount: "100", totalTokenCount: 0 }));
  equal(report.error, null); equal(report.summary.calls_missing_usage, 3);
  equal(report.summary.tokens.promptTokenCount.observed_total, null);
  equal(report.summary.tokens.totalTokenCount.observed_total, 0);
  const result = await generate(single(), "private-usage-key", "fixture-model", Date.now() + 110000, fetchFixture(), () => { throw new Error("observer"); });
  equal(result.questions.length, 1);
  const offline = await captureQuality(single(), "private-usage-key", "fixture-model", async () => { throw new TypeError("offline"); });
  equal(offline.error, "AI_UNAVAILABLE"); equal(offline.summary.calls_missing_usage, 1);
  equal(offline.summary.tokens.totalTokenCount.observed_total, null);
});

Deno.test("usage includes joined concurrent peer after fatal provider failure exactly once", async () => {
  const fixture = fetchFixture();
  let renders = 0, release!: () => void;
  const ready = new Promise<void>((resolve) => { release = resolve; });
  const report = await captureQuality(request(), "private-usage-key", "fixture-model", async (url, init) => {
    const body = JSON.parse(String(init!.body));
    if (body.systemInstruction.parts[0].text.includes("GENERATION stage")) {
      const first = ++renders === 1;
      if (renders === 2) release();
      await ready;
      if (first) return new Response("busy", { status: 503 });
    }
    return measuredResponse(await fixture(url, init));
  });
  equal(renders, 2); equal(report.error, "AI_BUSY"); equal(report.summary.provider_calls, 3);
  equal(report.summary.calls_missing_usage, 1);
  equal(report.summary.tokens.promptTokenCount, { observed_total: 200, observed_calls: 2, missing_calls: 1 });
  equal(report.summary.returned, 0);
  equal(new Set(report.events.filter((e) => e.stage === "provider_timing").map((e) => e.call_id)).size, 3);
});

Deno.test("usage summary never invents counts for unstarted calls or unsafe totals", async () => {
  const unstarted = await captureQuality(single(), "", "fixture-model", async () => { throw new Error("Must not fetch"); });
  equal(unstarted.error, "AI_UNAVAILABLE"); equal(unstarted.summary.provider_calls, 0);
  equal(unstarted.summary.tokens.promptTokenCount.observed_total, null);
  const fixture = fetchFixture();
  const overflow = await captureQuality(single(), "private-usage-key", "fixture-model", async (...args) =>
    measuredResponse(await fixture(...args), { ...measuredUsage, totalTokenCount: Number.MAX_SAFE_INTEGER }));
  equal(overflow.error, null); equal(overflow.summary.tokens.totalTokenCount.observed_total, null);
  equal(overflow.summary.tokens.totalTokenCount.observed_calls, 3);
});
