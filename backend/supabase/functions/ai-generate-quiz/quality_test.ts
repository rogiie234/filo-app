import type { ApplicationPlan } from "./planning.ts";
import { generate, QuizError } from "./quiz.ts";
import type { Question } from "./quiz.ts";
import {
  agrees, answerVariants, arrangeMC, balancePositions, blindPayload, duplicateObjective, gluedWords,
  difficultyDirection, grounded, nearDuplicateOptions, questionRules, setRules, spacing,
} from "./quality.ts";
import { blindReviewRequest, candidateSchema, cognitiveCriteria, generationInstructions, parseCandidate, qualityPipeline } from "./pipeline.ts";
import { candidate, fetchFixture, modelFixture, objective, request, reviewAtLevel, source } from "./quality_fixtures.ts";
import type { Objective } from "./quality.ts";

function assert(value: unknown, message = "Assertion failed"): asserts value { if (!value) throw new Error(message); }
function equal(a: unknown, b: unknown) { assert(JSON.stringify(a) === JSON.stringify(b), `${JSON.stringify(a)} != ${JSON.stringify(b)}`); }
const mc = (): Question => parseCandidate(candidate(objective()), objective(), request(), 12)!;

Deno.test("seeded shuffle is deterministic, balanced and preserves the answer across drops", () => {
  equal(arrangeMC("correct", ["a", "b", "c"], 12), arrangeMC("correct", ["a", "b", "c"], 12));
  const items = Array.from({ length: 6 }, (_, id) => ({ question: { ...mc(), correct_index: 0, options: ["correct", "a", "b", "c"] }, objective: objective(id) }));
  assert([...setRules(items).values()].flat().includes("answer_position_skew"));
  for (const n of [1, 3, 6, 20]) {
    const balanced = balancePositions(Array.from({ length: n }, mc), 99);
    const counts = [0, 0, 0, 0];
    for (const q of balanced) { counts[q.correct_index!]++; equal(q.options![q.correct_index!], "SELECT"); }
    assert(Math.max(...counts) - Math.min(...counts) <= 1);
    equal(balanced, balancePositions(Array.from({ length: n }, mc), 99));
  }
});

Deno.test("source evidence is normalized, contiguous, nonempty and from a single source", () => {
  assert(grounded("SELECT\n retrieves database records.", [source]));
  assert(!grounded("A fabricated source excerpt.", [source]));
  assert(!grounded("", [source]));
  assert(!grounded("SELECT retrieves", ["SELECT", "retrieves"]));
  equal(spacing(" a\n\t b "), "a b");
  assert(questionRules({ ...mc(), evidence: "Backups restore data after accidental loss." }, objective(), request()).includes("objective_alignment"));
});

Deno.test("MC rejects missing keys, duplicates, near duplicates, banned options and stem copies", () => {
  const o = objective();
  const invalid = { ...candidate(o), correct_answer: undefined };
  equal(parseCandidate(invalid, o, request(), 1), null);
  const q = mc();
  assert(questionRules({ ...q, correct_index: 10 }, o, request()).includes("missing_correct_option"));
  for (const option of ["SELECT", "select", "All of the above", q.prompt]) {
    const bad = { ...q, options: ["SELECT", option, "UPDATE", "DELETE"], correct_index: 0 };
    assert(questionRules(bad, o, request()).length > 0);
  }
  equal(parseCandidate({ ...candidate(o), correct_index: 0 }, o, request(), 1), null);
  equal(parseCandidate({ ...candidate(o), distractors: ["x", "y"] }, o, request(), 1), null);
});

Deno.test("blind solver catches supplied missing-correct-option and ambiguous normal-form failures", () => {
  const flawed = { ...mc(), prompt: "What is the difference between data and information?", correct_index: 0,
    options: ["Data has been processed to provide meaning, whereas data is raw facts", "Information is raw facts", "They are identical", "Information is exclusively in tables"] };
  assert(!agrees(flawed, { id: 0, status: "none", choices: [], answer: "" }));
  assert(!agrees(flawed, { id: 0, status: "one", choices: [2], answer: "" }));
  assert(!agrees({ ...mc(), prompt: "Which normal form requires atomic values?" }, { id: 0, status: "multiple", choices: [0, 1, 2], answer: "" }));
  // Pure structural checks cannot establish a semantic answer's truth; solver disagreement is required.
});

Deno.test("source-vocabulary checks flag glued words without changing legitimate source words", () => {
  for (const value of ["isnot", "maintainreferential"]) assert(gluedWords(value, source + " referential integrity"));
  assert(!gluedWords("Database Management System", source));
  assert(questionRules({ ...mc(), explanation: "It isnot correct." }, objective(), request()).includes("glued_words"));
});

Deno.test("TF giveaway absolutes need explicit evidence and acronym variants come only from source", () => {
  const q: Question = { type: "true_false", prompt: "An untested backup is always recoverable.", points: 1,
    explanation: "Assess recovery.", evidence: "Backups restore data after accidental loss.", correct_boolean: false };
  assert(questionRules(q, objective(1, "true_false"), request()).includes("unsupported_absolute"));
  const exact = "All primary key values are unique.";
  assert(!questionRules({ ...q, prompt: exact, evidence: exact }, objective(1, "true_false"), { ...request(), texts: [exact] }).includes("unsupported_absolute"));
  equal(answerVariants(["DBMS"], source), ["DBMS", "Database Management System"]);
  equal(answerVariants(["ACID"], source), ["ACID"]);
  equal(answerVariants(["ACID"], "ACID stands for Atomicity, Consistency, Isolation, and Durability."), ["ACID", "Atomicity, Consistency, Isolation, and Durability"]);
});

Deno.test("duplicate fact detection crosses types and option length cue is a quiz-level check", () => {
  const a = { question: mc(), objective: objective() };
  const b = { question: { ...mc(), type: "true_false" as const, prompt: "SELECT retrieves records." }, objective: { ...objective(1, "true_false"), fact: a.objective.fact } };
  assert(duplicateObjective(a.objective, b.objective));
  equal(setRules([a, b]).get(0), ["duplicate_fact"]);
  const long = { ...mc(), options: ["The correct supported answer is considerably longer than every other alternative", "one", "two", "three"], correct_index: 0 };
  assert(setRules([{ question: long, objective: objective() }]).get(0)?.includes("answer_length_cue"));
});

Deno.test("expansion identification does not accept the acronym already supplied by the question", () => {
  const sql = "Structured Query Language (SQL) is used to interact with databases.";
  equal(answerVariants(["SQL"], sql, "What does the acronym SQL stand for?"), ["Structured Query Language"]);
  equal(answerVariants(["Structured Query Language", "SQL"], sql, "What is the full name of SQL?"), ["Structured Query Language"]);
  equal(answerVariants(["ACID"], "ACID stands for Atomicity, Consistency, Isolation, and Durability.",
    "What acronym stands for Atomicity, Consistency, Isolation, and Durability?"), ["ACID"]);
  equal(answerVariants(["Data Query Language", "DQL"],
    "SELECT is often described as Data Query Language (DQL), although classifications vary."), ["Data Query Language", "DQL"]);
  equal(answerVariants(["XYZ"], "No expansion is available.", "What does XYZ stand for?"), []);
});

Deno.test("essay requires sample answer and rubric points matching question points", () => {
  const o = objective(3, "essay");
  const q = parseCandidate(candidate(o), o, request(), 1)!;
  equal(questionRules(q, o, request()), []);
  assert(questionRules({ ...q, sample_answer: undefined }, o, request()).includes("missing_sample_answer"));
  assert(questionRules({ ...q, points: 2 }, o, request()).includes("rubric_points"));
  equal(parseCandidate({ ...candidate(o), rubric: [] }, o, request(), 1), null);
});

Deno.test("blind payload has no key, evidence, source, explanations, objectives or rubric", () => {
  const payload = blindPayload([{ question: mc(), objective: objective() }]);
  equal(Object.keys(payload[0]), ["id", "type", "prompt", "options"]);
  const text = JSON.stringify(payload);
  for (const key of ["correct_index", "evidence", "explanation", "source", "fact", "assessment_task", "sample_answer", "rubric"]) assert(!text.includes(key));
  const schema = candidateSchema([objective()]);
  assert(schema.prefixItems[0].required.includes("correct_answer"));
  assert(!schema.prefixItems[0].required.includes("correct_index"));
});

Deno.test("typed pipeline returns backward-compatible fields with metadata and direct non-MC construction", async () => {
  const fixture = modelFixture();
  let calls = 0;
  const result = await qualityPipeline(request(), (...args) => { calls++; return fixture(...args); }, 12, () => 10000);
  equal(calls, 6);
  equal(result.questions.length, 4);
  equal(result.missing_by_type, { multiple_choice: 0, true_false: 0, identification: 0, essay: 0 });
  assert(result.questions.every((q) => !!q.evidence));
  assert(!JSON.stringify(result).includes("correct_answer"));
  assert(result.questions[3].sample_answer && result.questions[3].rubric);
});

Deno.test("invalid application selects a matching spare without resetting the slot action budget", async () => {
  const fixture = modelFixture();
  const generations: number[][] = [];
  const result = await qualityPipeline(request(), async (system, data, schema) => {
    if (system.includes("GENERATION stage")) {
      const ids = (data as { objectives: Objective[] }).objectives.map((o) => o.id);
      generations.push(ids);
      const values = await fixture(system, data, schema) as Record<string, unknown>[];
      return values.map((v) => (data as { objectives: Objective[] }).objectives.find((o) => o.id === v.objective_id)?.plan?.expected_outcome === "SELECT" ? { ...v, plan: { ...(v.plan as object), source_refs: ["missing"] } } : v);
    }
    return fixture(system, data, schema);
  }, 12, () => 10000);
  equal(generations, [[0], [3], [0]]);
  // Replacement keeps the slot ID but uses the distinct backup objective.
  equal(result.dropped_by_type.multiple_choice, 1);
  equal(result.questions.length, 4);
});

Deno.test("solver disagreement is source-audited without declaring the generator wrong", async () => {
  const fixture = modelFixture();
  let blindCalls = 0;
  let audits = 0;
  const result = await qualityPipeline(request(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("SOURCE AUDIT stage")) { audits++; return raw; }
    if (system.includes("Blindly solve")) {
      blindCalls++;
      return (raw as Record<string, unknown>[]).map((v) => v.id === 0 ? { ...v, status: "none", choices: [] } : v);
    }
    return raw;
  }, 12, () => 10000);
  equal(blindCalls, 3);
  equal(audits, 1);
  equal(result.questions.length, 4);
});

Deno.test("malformed verifier cannot pass; bounded failures log fixed rules without private content", async () => {
  const fixture = modelFixture();
  const logs: unknown[][] = [];
  const original = console.info;
  console.info = (...args) => logs.push(args);
  try {
    const result = await qualityPipeline(request(), (system, data, schema) => system.includes("Blindly solve") ? Promise.resolve({ private: source }) : fixture(system, data, schema), 1, () => 10000);
    equal(result.questions.length, 0);
    assert(result.dropped_by_type.multiple_choice > 0);
    const serialized = JSON.stringify(logs);
    assert(serialized.includes("verifier_disagreements"));
    assert(!serialized.includes("SELECT") && !serialized.includes("Database"));
  } finally { console.info = original; }
});

Deno.test("verified provider failures still fail closed without emitting an unverified quiz", async () => {
  const fixture = fetchFixture();
  let calls = 0, verifierCalls = 0;
  try {
    // Exercise the verifier failure, not the separate short-deadline admission guard.
    await generate(request(), "key", "model", Date.now() + 110000, (url, init) => {
      calls++;
      const body = JSON.parse(String(init!.body));
      if (body.systemInstruction.parts[0].text.includes("Blindly solve")) {
        verifierCalls++;
        return Promise.resolve(new Response("private error", { status: 429 }));
      }
      return fixture(url, init);
    });
    throw new Error("Expected AI_BUSY");
  } catch (error) { assert(error instanceof QuizError && error.code === "AI_BUSY"); }
  assert(verifierCalls >= 1 && verifierCalls <= 2); assert(calls >= 3 && calls <= 5);
});

Deno.test("short or malformed blueprints do not invent objectives or invoke generation", async () => {
  let calls = 0;
  for (const blueprint of [null, [], [{ type: "multiple_choice", difficulty: "easy", objective: "Unquoted objective", fact: "Unknown fact", evidence: "Invented excerpt." }]]) {
    const result = await qualityPipeline(request(), () => { calls++; return Promise.resolve(blueprint); }, 1, () => 10000);
    equal(result.questions, []);
    equal(result.missing_by_type, request().counts);
  }
  equal(calls, 3);
});

Deno.test("exhausted questions stay missing when no same-type spare exists", async () => {
  const fixture = modelFixture();
  const generations: number[][] = [];
  const result = await qualityPipeline(request(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as unknown[]).slice(0, 4);
    if (system.includes("GENERATION stage")) {
      generations.push((data as { objectives: Objective[] }).objectives.map((o) => o.id));
      return (raw as Record<string, unknown>[]).map((v) => v.objective_id === 0 ? { ...v, distractors: ["SELECT", "SELECT", "SELECT"] } : v);
    }
    return raw;
  }, 42, () => 10000);
  equal(generations, [[0], [3], [0], [0]]);
  equal(result.questions.length, 3);
  equal(result.dropped_by_type.multiple_choice, 1);
  equal(result.missing_by_type.multiple_choice, 1);
});

Deno.test("deadline guard returns only completed verified work and starts no late generation", async () => {
  const fixture = modelFixture();
  let calls = 0;
  const result = await qualityPipeline(request(), (...args) => { calls++; return fixture(...args); }, 1, () => 0);
  equal(calls, 1);
  equal(result.questions, []);
  equal(result.missing_by_type, request().counts);
});

Deno.test("Medium rejects correctly solved recall questions instead of silently labelling them Medium", async () => {
  const fixture = modelFixture();
  const result = await qualityPipeline({ ...request(), difficulty: "medium" }, fixture, 1, () => 10000);
  equal(result.questions, []);
  equal(result.missing_by_type, request().counts);
  assert(result.dropped_by_type.multiple_choice > 0);
});

Deno.test("blind distractor review repairs/drops weak MC alternatives while retaining other types", async () => {
  const fixture = modelFixture();
  const result = await qualityPipeline(request(), async (system, data, schema) => {
    const raw = await fixture(system, data, schema);
    if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => ({ ...v, plausible_options: false }));
    return raw;
  }, 1, () => 10000);
  equal(result.questions.length, 3);
  assert(result.questions.every((q) => q.type !== "multiple_choice"));
  equal(result.missing_by_type.multiple_choice, 1);
});

Deno.test("run statistics identify pipeline revision and trusted difficulty without question content", async () => {
  const logs: unknown[][] = [];
  const original = console.info;
  console.info = (...args) => logs.push(args);
  try {
    await qualityPipeline(request(), modelFixture(), 1, () => 10000);
    equal(logs.length, 1);
    equal(logs[0][0], "ai-generate-quiz: quality_stats");
    const stats = JSON.parse(String(logs[0][1]));
    equal(stats.pipeline_revision, "Q4.14");
    equal(stats.difficulty, "easy");
    equal(stats.calls, 6);
    equal(stats.difficulty_mismatches, {
      too_easy: { multiple_choice: 0, true_false: 0, identification: 0, essay: 0 },
      too_hard: { multiple_choice: 0, true_false: 0, identification: 0, essay: 0 },
    });
    assert(!JSON.stringify(stats).includes("SELECT") && !JSON.stringify(stats).includes(source));
  } finally { console.info = original; }
});

Deno.test("blueprint requires a concrete assessment task and passes it only to generation", async () => {
  const fixture = modelFixture();
  let generated = false;
  await qualityPipeline(request(), async (system, data, schema) => {
    if (system.includes("GENERATION stage")) {
      generated = true;
      assert((data as { objectives: Objective[] }).objectives.every((o) => !!o.assessment_task));
    }
    return fixture(system, data, schema);
  }, 1, () => 10000);
  assert(generated);
  const invalidFixture = modelFixture();
  const result = await qualityPipeline(request(), async (system, data, schema) => {
    const raw = await invalidFixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as Record<string, unknown>[]).map((o) => ({ ...o, plan: null }));
    throw new Error("Invalid blueprint must not reach generation");
  }, 1, () => 10000);
  equal(result.questions, []);
});

Deno.test("a scenario-based Medium candidate can pass independent interpretation review", async () => {
  const fixture = modelFixture();
  const result = await qualityPipeline({ ...request(), counts: { multiple_choice: 1, true_false: 0, identification: 0, essay: 0 }, difficulty: "medium" },
    async (system, data, schema) => {
      const raw = await fixture(system, data, schema);
      if (system.includes("BLUEPRINT stage")) return (raw as Record<string, unknown>[]).map((q) => {
        const plan = q.plan as ApplicationPlan;
        return { ...q, plan: { ...plan, scenario: { ...plan.scenario, facts: [{ id: "f1", text: "The requested action must read existing rows while keeping their stored values unchanged." }], goal: "Choose the action meeting the goal." } } };
      });
      if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => reviewAtLevel(v, "interpretation"));
      return raw;
    }, 1, () => 10000);
  equal(result.questions.length, 1);
  equal(result.missing_by_type.multiple_choice, 0);
});

Deno.test("option similarity preserves changed numbers, ordinals and negation, not cosmetic duplicates", () => {
  const base = "The table meets normal form requirements at level ";
  assert(!nearDuplicateOptions(base + "1", base + "2"));
  assert(!nearDuplicateOptions("First Normal Form", "Second Normal Form"));
  assert(!nearDuplicateOptions("The proposed change is valid", "The proposed change is not valid"));
  assert(nearDuplicateOptions("  SELECT  ", "select"));
  assert(nearDuplicateOptions("Records are retrieved from the table", "From the table, records are retrieved."),
    "Punctuation and word order must not hide options with identical content words");
});

Deno.test("Medium repair receives the rejected question and observed level without leaking them to blind review", async () => {
  const fixture = modelFixture();
  let generations = 0;
  let reviews = 0;
  const result = await qualityPipeline({ ...request(), difficulty: "medium",
    counts: { multiple_choice: 1, true_false: 0, identification: 0, essay: 0 } }, async (system, data, schema) => {
    if (system.includes("GENERATION stage")) {
      generations++;
      const repairs = (data as { repairs: { errors: string[]; previous_candidate?: { prompt: string }; observed_cognitive_level?: string; difficulty_direction: string | null }[] }).repairs;
      if (generations === 2) {
        assert(repairs[0].errors.includes("verifier_difficulty"));
        equal(repairs[0].observed_cognitive_level, "recall");
        equal(repairs[0].difficulty_direction, "too_easy");
        assert(repairs[0].previous_candidate?.prompt.endsWith("Which action meets the stated goal under these conditions?"));
      }
      const raw = await fixture(system, data, schema) as Record<string, unknown>[];
      return generations === 1 ? raw : raw.map((q) => {
        const plan = q.plan as ApplicationPlan;
        return { ...q, plan: { ...plan, scenario: { ...plan.scenario, facts: [{ id: "f1", text: "The requested action must read existing rows while keeping their stored values unchanged." }], goal: "Choose the action meeting the goal." } } };
      });
    }
    const raw = await fixture(system, data, schema);
    if (system.includes("BLUEPRINT stage")) return (raw as unknown[]).slice(0, 1);
    if (system.includes("Blindly solve")) {
      reviews++;
      assert(!JSON.stringify(data).includes("previous_candidate"));
      assert(!JSON.stringify(data).includes("observed_cognitive_level"));
      return (raw as Record<string, unknown>[]).map((v) => reviewAtLevel(v, reviews === 1 ? "recall" : "interpretation"));
    }
    return raw;
  }, 12, () => 10000);
  equal(generations, 2);
  equal(result.questions.length, 1);
  equal(result.missing_by_type.multiple_choice, 0);
});

Deno.test("difficulty directions follow ordered levels without treating unknown labels as too easy", () => {
  for (const [difficulty, expected] of [["easy", "recall"], ["medium", "interpretation"], ["hard", "multistep"]] as const) {
    equal(difficultyDirection(difficulty, expected), null);
    equal(difficultyDirection(difficulty, "unknown"), null);
  }
  equal(difficultyDirection("medium", "recall"), "too_easy");
  equal(difficultyDirection("medium", "multistep"), "too_hard");
  equal(difficultyDirection("easy", "interpretation"), "too_hard");
  equal(difficultyDirection("hard", "interpretation"), "too_easy");
});

Deno.test("generation and blind review share cognitive criteria without leaking the requested level", () => {
  const review = blindReviewRequest([{ question: mc(), objective: objective() }]);
  assert(generationInstructions.includes(cognitiveCriteria));
  assert(review.system.includes(cognitiveCriteria));
  equal(review.data, blindPayload([{ question: mc(), objective: objective() }]));
  assert(!JSON.stringify(review.data).includes("difficulty"));
  const q: Question = { type: "true_false", prompt: "A backup is guaranteed to be recoverable.", points: 1,
    explanation: "Check recovery.", evidence: "Backups restore data after accidental loss.", correct_boolean: false };
  assert(questionRules(q, objective(1, "true_false"), request()).includes("unsupported_absolute"));
});

Deno.test("Medium difficulty diagnostics separate directions by type and keep strict bounded rejection", async () => {
  for (const level of ["recall", "multistep"] as const) {
    const fixture = modelFixture();
    const logs: unknown[][] = [];
    const original = console.info;
    console.info = (...args) => logs.push(args);
    let generations = 0;
    try {
      const result = await qualityPipeline({ ...request(), difficulty: "medium",
        counts: { multiple_choice: 1, true_false: 0, identification: 0, essay: 0 } }, async (system, data, schema) => {
        if (system.includes("GENERATION stage")) {
          generations++;
          if (generations > 1) {
            const repairs = (data as { repairs: { difficulty_direction: string; observed_cognitive_level: string }[] }).repairs;
            equal(repairs[0].difficulty_direction, level === "recall" ? "too_easy" : "too_hard");
            equal(repairs[0].observed_cognitive_level, level);
          }
        }
        const raw = await fixture(system, data, schema);
        if (system.includes("BLUEPRINT stage")) {
          assert(system.includes("Keep private justification"));
          return (raw as unknown[]).slice(0, 1);
        }
        if (system.includes("Blindly solve")) return (raw as Record<string, unknown>[]).map((v) => reviewAtLevel(v, level));
        return raw;
      }, 12, () => 10000);
      equal(generations, 3);
      equal(result.questions, []);
      equal(result.missing_by_type.multiple_choice, 1);
      equal(result.dropped_by_type.multiple_choice, 1);
      const stats = JSON.parse(String(logs[0][1]));
      const direction = level === "recall" ? "too_easy" : "too_hard";
      const other = level === "recall" ? "too_hard" : "too_easy";
      equal(stats.difficulty_mismatches[direction], { multiple_choice: 3, true_false: 0, identification: 0, essay: 0 });
      equal(stats.difficulty_mismatches[other], { multiple_choice: 0, true_false: 0, identification: 0, essay: 0 });
      equal(stats.failures.verifier_difficulty, 3);
      equal(stats.retries, 2);
      assert(!JSON.stringify(stats).includes(source));
      assert(!JSON.stringify(stats).includes("SELECT"));
    } finally { console.info = original; }
  }
});


Deno.test("whereas remains a legitimate conjunction when source contains where and as separately", () => {
  const input = { ...request(), texts: [source + " Where values match as required. Referential integrity is maintained."] };
  const text = input.texts.join(" ");
  for (const conjunction of ["whereas", "Whereas", "WHEREAS"]) assert(!gluedWords(conjunction, text));
  const rules = questionRules({ ...mc(), explanation: "Data is raw, whereas information is processed." }, objective(), input);
  assert(!rules.includes("glued_words"));
  for (const glued of ["isnot", "maintainreferential", "whereasnot"]) assert(gluedWords(glued, text));
});
