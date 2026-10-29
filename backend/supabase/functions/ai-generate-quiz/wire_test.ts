import { modelItems, wireInstructions, wireSchema } from "./wire.ts";
import { candidateSchema } from "./pipeline.ts";
import { reviewSchema } from "./review.ts";
import { candidate, flatItem, flatPlan, plannedObjective } from "./quality_fixtures.ts";
import { planSchema } from "./planning.ts";

function assert(v: unknown): asserts v { if (!v) throw new Error("Assertion failed"); }
function canonical(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(canonical);
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b)).map(([k, x]) => [k, canonical(x)]));
  return v;
}
function equal(a: unknown, b: unknown) { assert(JSON.stringify(canonical(a)) === JSON.stringify(canonical(b))); }
const blueprint = { type: "array", maxItems: 2, items: { properties: { plan: planSchema } } };
const draft = () => ({ type: "multiple_choice", difficulty: "medium", objective: "Apply a rule", fact: "Source rule", ...flatPlan(plannedObjective(0, "multiple_choice", "medium").plan!) });

Deno.test("flat provider schema declares primitive fields and required planning data", () => {
  for (const schema of [blueprint, candidateSchema([plannedObjective()]), reviewSchema(1), reviewSchema(1, true)]) {
    const wire = wireSchema(schema), item = wire.properties.items.items;
    assert(item.required.length > 10);
    for (const field of Object.values(item.properties)) {
      assert(field.type !== ("object" as string));
      if (field.type === "array") assert(["string", "integer", "boolean"].includes(field.items.type));
    }
    assert(!JSON.stringify(wire).includes("prefixItems"));
  }
  assert(wireSchema(blueprint).properties.items.items.required.includes("scenario_facts"));
});

Deno.test("flat plans reconstruct Easy Medium and dependent Hard without inventing text", () => {
  for (const difficulty of ["easy", "medium", "hard"] as const) {
    const o = plannedObjective(0, "multiple_choice", difficulty);
    const expected = { type: o.type, difficulty, objective: o.objective, fact: o.fact, plan: o.plan };
    equal(modelItems({ items: [flatItem(expected)] }, blueprint), [expected]);
  }
  const good = draft();
  for (const patch of [{ step1_fact_indices: [1] }, { step1_fact_indices: [0, 0] }, { step2_fact_indices: [0] },
    { contrast_fact_index: -1 }, { step_outcomes: ["a", "b", "c", "d"] }, { scenario_facts: ["a", "b", "c", "d", "e"] },
    { scenario_goal: undefined }, { plan: {} }, { unexpected: true }]) {
    equal(modelItems({ items: [{ ...good, ...patch }, good] }, blueprint), [null, modelItems({ items: [good] }, blueprint)![0]]);
  }
  for (const value of [{ items: [good, good, good] }, { items: [], extra: true }, [good]]) equal(modelItems(value, blueprint), null);
  equal(modelItems({ items: [JSON.stringify(good)] }, blueprint), [null]);
});

Deno.test("flat question variants preserve keys rubric and distractors and reject mismatched arrays", () => {
  for (const type of ["multiple_choice", "true_false", "identification", "essay"] as const) {
    const o = plannedObjective(0, type), q = candidate(o), schema = candidateSchema([o]);
    if (type === "true_false") q.correct_boolean = false;
    equal(modelItems({ items: [flatItem(q)] }, schema), [q]);
    equal(modelItems({ items: [{ ...(flatItem(q) as object), wrong_field: true }] }, schema), [null]);
    const bad = { ...(flatItem(q) as Record<string, unknown>) };
    if (type === "multiple_choice") bad.distractor_reasons = ["only one"];
    else if (type === "essay") bad.rubric_points = [];
    else if (type === "true_false") bad.correct_boolean = "false";
    else bad.accepted_answers = [1];
    equal(modelItems({ items: [bad] }, schema), [null]);
  }
});

Deno.test("flat review and source audit preserve independent decisions and indexed option judgments", () => {
  const flat = { id: 0, status: "one", choices: [2], answer: "", cognitive_level: "interpretation", plausible_options: true,
    application_conditions: ["A condition"], inference_count: 1, answer_leaked: false,
    option_defensible: ["no", "no", "yes", "no"], option_same_category: [true, true, true, true], option_plausible: [true, true, true, true],
    assumptions: [], answer_points: [] };
  const decoded = modelItems({ items: [flat] }, reviewSchema(1))![0] as Record<string, unknown>;
  equal(decoded.application, { conditions: ["A condition"], inferences: 1, answer_leaked: false });
  equal((decoded.option_reviews as { index: number }[]).map((o) => o.index), [0, 1, 2, 3]);
  const audit = { ...flat, source_refs: ["s1.1"], support: "insufficient" };
  equal(modelItems({ items: [audit] }, reviewSchema(1)), [null]);
  const result = modelItems({ items: [audit] }, reviewSchema(1, true))![0] as Record<string, unknown>;
  equal(result.support, "insufficient"); equal(result.source_refs, ["s1.1"]);
  for (const patch of [{ option_plausible: [] }, { inference_count: "1" }, { status: "maybe" }, { application: {} }])
    equal(modelItems({ items: [{ ...flat, ...patch }] }, reviewSchema(1)), [null]);
});

Deno.test("retained plans omit application fields and mixed repairs bind fields to exact objective IDs", () => {
  const a = plannedObjective(0), b = plannedObjective(1);
  const full = candidate(a), { plan: _plan, ...compact } = full;
  const schema = candidateSchema([a, b], [a.id]);
  const decoded = modelItems({ items: [flatItem(compact), flatItem(candidate(b))] }, schema)!;
  equal(decoded, [compact, candidate(b)]);
  equal(modelItems({ items: [flatItem(full)] }, schema), [null]);
  equal(modelItems({ items: [{ ...flatItem(compact) as object, objective_id: 99 }] }, schema), [null]);
  const retained = wireSchema(candidateSchema([a], [a.id]));
  assert(!Object.hasOwn(retained.properties.items.items.properties, "scenario_facts"));
  assert(!Object.hasOwn(retained.properties.items.items.properties, "source_refs"));
  assert(JSON.stringify(retained).length < JSON.stringify(wireSchema(candidateSchema([a]))).length);
  const { plan: _other, ...missingRepair } = candidate(b);
  equal(modelItems({ items: [flatItem(missingRepair)] }, schema), [null]);
});

Deno.test("blueprint wire preserves requested difficulty and active type enums without relabelling", () => {
  const schema = { ...blueprint, items: { properties: { plan: planSchema,
    difficulty: { enum: ["medium"] }, type: { enum: ["multiple_choice"] } } } };
  const fields = wireSchema(schema).properties.items.items.properties;
  equal(fields.difficulty, { type: "string", enum: ["medium"] });
  equal(fields.type, { type: "string", enum: ["multiple_choice"] });
  const good = draft();
  assert(modelItems({ items: [good] }, schema)![0]);
  equal(modelItems({ items: [{ ...good, difficulty: "easy" }, { ...good, type: "essay" }] }, schema), [null, null]);
});

Deno.test("single-type generation requires applicable fields and forbids the observed MC essay mixture", () => {
  const required: Record<string, string[]> = {
    multiple_choice: ["correct_answer", "distractor_texts", "distractor_categories", "distractor_misconceptions", "distractor_reasons"],
    true_false: ["correct_boolean"], identification: ["accepted_answers"], essay: ["sample_answer", "rubric_key_points", "rubric_points"],
  };
  for (const type of ["multiple_choice", "true_false", "identification", "essay"] as const) {
    const o = plannedObjective(0, type), schema = candidateSchema([o], [0]);
    const item = wireSchema(schema).properties.items.items;
    equal(item.properties.type, { type: "string", enum: [type] });
    for (const field of required[type]) assert(item.required.includes(field));
    for (const other of Object.keys(required).filter((k) => k !== type))
      for (const field of required[other]) assert(!Object.hasOwn(item.properties, field));
  }
  const o = plannedObjective(), schema = candidateSchema([o], [0]);
  const { plan: _plan, ...q } = candidate(o);
  const good = flatItem(q) as Record<string, unknown>;
  const { distractor_categories: _c, distractor_misconceptions: _m, distractor_reasons: _r, ...missing } = good;
  equal(modelItems({ items: [{ ...missing, sample_answer: "", rubric_key_points: [], rubric_points: [] }] }, schema), [null]);
  equal(modelItems({ items: [missing] }, schema), [null]);
  equal(modelItems({ items: [{ ...good, sample_answer: "Unrelated field" }] }, schema), [null]);
  equal(modelItems({ items: [good] }, schema), [q]);
});

Deno.test("typed non-MC review omits option judgments and reconstructs an empty internal list without changing the verdict", () => {
  const verdict = { id: 0, status: "one", choices: [1], answer: "", cognitive_level: "interpretation", plausible_options: true,
    application_conditions: ["A stated condition"], inference_count: 1, answer_leaked: false, assumptions: [], answer_points: [] };
  for (const type of ["true_false", "identification", "essay"] as const) {
    const row = { ...verdict, choices: type === "true_false" ? [1] : [], answer: type === "true_false" ? "" : "A source-supported response" };
    const schema = reviewSchema(1, false, type), properties = wireSchema(schema).properties.items.items.properties;
    assert(!Object.hasOwn(properties, "option_defensible"));
    const result = modelItems({ items: [row] }, schema)![0] as Record<string, unknown>;
    equal(result.option_reviews, []); equal(result.choices, row.choices); equal(result.cognitive_level, "interpretation");
    equal(modelItems({ items: [{ ...row, option_defensible: ["yes", "no"], option_same_category: [true, true], option_plausible: [true, true] }] }, schema), [null]);
    const audit = modelItems({ items: [{ ...row, source_refs: ["s1.1"], support: "supported" }] }, reviewSchema(1, true, type))![0] as Record<string, unknown>;
    equal(audit.option_reviews, []); equal(audit.source_refs, ["s1.1"]);
  }
  const mixed = wireSchema(reviewSchema(2)).properties.items.items;
  assert(mixed.required.includes("option_defensible"));
  const mc = wireSchema(reviewSchema(1, false, "multiple_choice")).properties.items.items;
  assert(mc.required.includes("option_defensible"));
});

Deno.test("canonical generation contract omits duplicate stems and keys and never accepts replacement prose", () => {
  for (const type of ["multiple_choice", "true_false", "identification", "essay"] as const) {
    const o = plannedObjective(0, type), schema = candidateSchema([o], [0], true);
    const fields = wireSchema(schema).properties.items.items.properties;
    const { plan: _plan, prompt: _prompt, correct_answer: _mc, correct_boolean: _tf, accepted_answers: _id, sample_answer: _essay, ...metadata } = candidate(o);
    const good = flatItem(metadata);
    assert(modelItems({ items: [good] }, schema)![0]);
    for (const key of ["prompt", "correct_answer", "correct_boolean", "accepted_answers", "sample_answer"]) {
      assert(!Object.hasOwn(fields, key));
      equal(modelItems({ items: [{ ...good as object, [key]: "Untrusted replacement" }] }, schema), [null]);
    }
  }
});


Deno.test("Medium wire preserves intent and separate context while rejecting malformed role data", () => {
  const o = plannedObjective(0, "multiple_choice", "medium");
  const plan = { ...o.plan!, scenario: { ...o.plan!.scenario, context: ["Background setting for the exercise."] } };
  const value = { type: o.type, difficulty: o.difficulty, objective: o.objective, fact: o.fact, plan };
  equal(modelItems({ items: [flatItem(value)] }, blueprint), [value]);
  const good = flatItem(value) as Record<string, unknown>;
  for (const patch of [{ task_kind: "recall" }, { scenario_context: "not an array" },
    { scenario_context: ["a", "b", "c"] }, { scenario_context: ["x".repeat(251)] },
    { step1_fact_indices: [1] }]) equal(modelItems({ items: [{ ...good, ...patch }] }, blueprint), [null]);
});


Deno.test("flat Medium case fields preserve repeated inputs and reject missing or out-of-range pivots", () => {
  const o = plannedObjective(0, "multiple_choice", "medium");
  const value = { type: o.type, difficulty: o.difficulty, objective: o.objective, fact: o.fact, plan: o.plan };
  const good = flatItem(value) as Record<string, unknown>;
  equal(modelItems({ items: [good] }, blueprint), [value]);
  for (const patch of [{ case_fact_index: 9 }, { case_inputs: [] }, { case_inputs: ["x".repeat(81), "b"] }, { case_action: "" }])
    equal(modelItems({ items: [{ ...good, ...patch }] }, blueprint), [null]);
  const { case_inputs: _inputs, ...missing } = good;
  equal(modelItems({ items: [missing] }, blueprint), [null]);
});

Deno.test("Easy plans require nonblank tasks and keys while reasoning arrays stay empty", () => {
  const schema = { ...blueprint, items: { properties: { plan: planSchema,
    difficulty: { enum: ["easy"] } } } };
  const fields = wireSchema(schema).properties.items.items.properties;
  equal(fields.scenario_goal, { type: "string", minLength: 1 });
  equal(fields.expected_outcome, { type: "string", minLength: 1 });
  assert(wireInstructions(schema).includes("scenario_goal and expected_outcome must still contain"));
  for (const type of ["multiple_choice", "true_false", "identification", "essay"] as const) {
    const o = plannedObjective(0, type, "easy");
    const expected = { type, difficulty: "easy", objective: o.objective, fact: o.fact, plan: o.plan };
    const good = flatItem(expected) as Record<string, unknown>;
    equal(good.scenario_facts, []);
    equal(good.step_outcomes, []);
    equal(modelItems({ items: [good] }, schema), [expected]);
    for (const key of ["scenario_goal", "expected_outcome"]) {
      for (const blank of ["", " \t\n"]) {
        equal(modelItems({ items: [{ ...good, [key]: blank }, good] }, schema), [null, expected]);
      }
    }
    if (type === "true_false") {
      const decoded = modelItems({ items: [{ ...good, expected_outcome: "false" }] }, schema)![0] as { plan: { expected_outcome: string } };
      equal(decoded.plan.expected_outcome, "false");
    }
  }
});
