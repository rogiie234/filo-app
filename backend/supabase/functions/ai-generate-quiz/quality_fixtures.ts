// Maintained synthetic fixtures; no private lesson, credentials or provider output.
import { sampleOutput, types } from "./quiz.ts";
import type { Input, Question } from "./quiz.ts";
import type { Objective } from "./quality.ts";
import type { ModelCall } from "./pipeline.ts";
import { record, sourceSpans, renderPlan } from "./planning.ts";
import type { ApplicationPlan } from "./planning.ts";
import type { ReviewVerdict } from "./review.ts";

export const source = "SELECT retrieves database records. Primary keys uniquely identify rows. A Database Management System (DBMS) manages databases. Foreign keys reference related tables. Backups restore data after accidental loss. Data is raw facts; information is processed data. First Normal Form requires atomic values. Second Normal Form builds on First Normal Form. Third Normal Form builds on Second Normal Form.";
export const facts = ["SELECT retrieves database records.", "Primary keys uniquely identify rows.", "A Database Management System (DBMS) manages databases.", "Foreign keys reference related tables.", "Backups restore data after accidental loss.", "Data is raw facts; information is processed data."];
export const objective = (id = 0, type: Question["type"] = "multiple_choice"): Objective => ({
  id, type, difficulty: "easy", objective: facts[id % facts.length], assessment_task: "Identify the concept described by this source fact: " + facts[id % facts.length],
  fact: facts[id % facts.length], evidence: facts[id % facts.length],
});
export const request = (): Input => ({ texts: [source], counts: { multiple_choice: 1, true_false: 1, identification: 1, essay: 1 },
  difficulty: "easy", mode: "generate", topic_focus: "", current_prompts: [] });
export function candidate(o: Objective): Record<string, unknown> {
  const value: Record<string, unknown> = { objective_id: o.id, type: o.type, points: 1, explanation: "Checks the learning objective.",
    ...(o.plan ? { plan: o.plan } : { evidence: o.evidence }),
    ...(o.type === "multiple_choice" ? o.fact === facts[4] ? { prompt: "What helps restore data after accidental loss?", correct_answer: "Backups", distractors: ["Indexes", "Constraints", "Transactions"] } :
      o.fact === facts[5] ? { prompt: "What does data consist of?", correct_answer: "Raw facts", distractors: ["Processed reports", "Database software", "Related tables"] } :
      { prompt: "Which SQL operation retrieves database records?", correct_answer: "SELECT", distractors: ["INSERT", "UPDATE", "DELETE"] } :
      o.type === "true_false" ? { prompt: "A primary key uniquely identifies rows.", correct_boolean: true } :
      o.type === "identification" ? { prompt: "Which software manages databases?", accepted_answers: ["DBMS", "Database Management System"] } :
      { prompt: "Explain how foreign keys connect related tables.", sample_answer: "Foreign keys reference related tables.", rubric: [{ key_point: "Reference related tables", points: 1 }] }),
  };
  if (o.plan) {
    value.prompt = [...o.plan.scenario.facts.map((f) => f.text), value.prompt].join(" ");
    if (Array.isArray(value.distractors)) value.distractors = value.distractors.map((text, i) => ({ text,
      category: o.plan!.answer_category, misconception: `Confuses alternative ${i + 1}`,
      why_incorrect: "This alternative does not satisfy the selected rule." }));
  }
  if (o.plan?.task_kind) Object.assign(value, renderPlan(o.plan, o.type));
  return value;
}
export function plannedObjective(id = 0, type: Question["type"] = "multiple_choice", difficulty: Input["difficulty"] = "easy"): Objective {
  const o = { ...objective(id, type), difficulty };
  const c = candidate(o);
  const outcome = type === "multiple_choice" ? String(c.correct_answer) : type === "true_false" ? "true" :
    type === "identification" ? "DBMS" : "Foreign keys reference related tables.";
  const facts = difficulty === "easy" ? [] : [{ id: "f1", text: "The example uses stored database records." }];
  const steps = difficulty === "easy" ? [] : [{ id: "a1", facts: ["f1"], depends_on: [] as string[], outcome }];
  if (difficulty === "hard") steps.push({ id: "a2", facts: [], depends_on: ["a1"], outcome });
  return { ...o, plan: { ...(difficulty === "medium" ? { task_kind: type === "identification" ? "diagnosis" as const : type === "essay" ? "outcome" as const : "decision" as const } : {}), source_refs: sourceSpans([source]).map((s) => s.id), scenario: { facts, goal: String(c.prompt), ...(difficulty === "medium" ? { case: { fact_id: "f1", inputs: ["record A", "record B"], action: "Read these records while keeping their stored values unchanged." } } : {}) }, steps,
    expected_outcome: outcome, contrast: difficulty === "easy" ? { fact_id: "", replacement: "", outcome: "" } :
      { fact_id: "f1", replacement: "The example has no stored records.", outcome: "The rule cannot be applied to existing records." }, answer_category: "Supported alternatives" } };
}
export function reviewAtLevel(v: Record<string, unknown>, level: ReviewVerdict["cognitive_level"]) {
  return { ...v, cognitive_level: level, application: { ...(v.application as object),
    inferences: level === "recall" ? 0 : level === "interpretation" ? 1 : 2 } };
}

export function flatPlan(p: ApplicationPlan) {
  const ids = p.scenario.facts.map((f) => f.id);
  const indices = (n: number) => p.steps[n]?.facts.map((id) => ids.indexOf(id)) ?? [];
  return {
    source_refs: p.source_refs, task_kind: p.task_kind ?? "", case_fact_index: p.scenario.case ? ids.indexOf(p.scenario.case.fact_id) : -1,
    case_inputs: p.scenario.case?.inputs ?? [], case_action: p.scenario.case?.action ?? "", scenario_context: p.scenario.context ?? [], scenario_facts: p.scenario.facts.map((f) => f.text), scenario_goal: p.scenario.goal,
    step_outcomes: p.steps.map((s) => s.outcome), step1_fact_indices: indices(0), step2_fact_indices: indices(1), step3_fact_indices: indices(2),
    expected_outcome: p.expected_outcome, contrast_fact_index: ids.indexOf(p.contrast.fact_id),
    contrast_replacement: p.contrast.replacement, contrast_outcome: p.contrast.outcome, answer_category: p.answer_category,
  };
}
export function flatReview(v: Record<string, unknown>) {
  const { application, option_reviews, ...common } = v;
  const app = application as ReviewVerdict["application"];
  const options = [...(option_reviews as ReviewVerdict["option_reviews"])].sort((a, b) => a.index - b.index);
  return { ...common, application_conditions: app.conditions, inference_count: app.inferences, answer_leaked: app.answer_leaked,
    option_defensible: options.map((o) => o.defensible), option_same_category: options.map((o) => o.same_category), option_plausible: options.map((o) => o.plausible) };
}
export function flatItem(v: unknown): unknown {
  if (!record(v)) return v;
  if (record(v.application)) return flatReview(v);
  const { plan, distractors, rubric, ...common } = v;
  const result: Record<string, unknown> = { ...common, ...(record(plan) ? flatPlan(plan as unknown as ApplicationPlan) : {}) };
  if (Array.isArray(distractors)) {
    result.distractor_texts = distractors.map((d) => d.text); result.distractor_categories = distractors.map((d) => d.category);
    result.distractor_misconceptions = distractors.map((d) => d.misconception); result.distractor_reasons = distractors.map((d) => d.why_incorrect);
  }
  if (Array.isArray(rubric)) {
    result.rubric_key_points = rubric.map((r) => r.key_point); result.rubric_points = rubric.map((r) => r.points);
  }
  return result;
}
export function modelFixture(): ModelCall {
  const answers = new Map<number, Record<string, unknown>>();
  return async (system, data) => {
    if (system.includes("BLUEPRINT stage")) {
      const d = data as { requested_types: Question["type"][]; difficulty: Input["difficulty"] };
      return [...d.requested_types, d.requested_types[0], d.requested_types[0]].map((t, i) => plannedObjective(i, t, d.difficulty))
        .map((o) => ({ type: o.type, difficulty: o.difficulty, objective: o.objective, fact: o.fact, plan: o.plan }));
    }
    if (system.includes("GENERATION stage")) {
      return (data as { objectives: Objective[] }).objectives.map((o) => {
        const c = candidate(o); answers.set(o.id, c);
        const d = data as { retained_plan_ids?: number[]; render_from_plan?: boolean };
        const rendered = { ...c };
        if (d.render_from_plan) for (const k of ["prompt", "correct_answer", "correct_boolean", "accepted_answers", "sample_answer"]) delete rendered[k];
        if (d.retained_plan_ids?.includes(o.id)) delete rendered.plan;
        return rendered;
      });
    }
    const audit = system.includes("SOURCE AUDIT stage");
    const questions = audit ? (data as { questions: unknown }).questions : data;
    return (questions as { id: number; type: Question["type"]; prompt: string; options?: string[] }[]).map((q) => {
      const answer = answers.get(q.id) ?? candidate(plannedObjective(q.id, q.type));
      const correct = q.options ? q.options.indexOf(answer.type === "true_false" ? "True" : String(answer.correct_answer)) : -1;
      return { id: q.id, status: "one", cognitive_level: "recall", plausible_options: true,
        choices: q.options ? [correct] : [],
        answer: answer.type === "identification" ? "DBMS" : answer.type === "essay" ? "Foreign keys reference related tables." : "",
        application: { conditions: [q.prompt], inferences: 0, answer_leaked: false }, assumptions: [],
        option_reviews: q.type === "multiple_choice" ? q.options!.map((_, index) => ({ index, defensible: index === correct ? "yes" : "no", same_category: true, plausible: true })) : [],
        answer_points: q.type === "essay" ? ["Foreign keys reference related tables."] : [],
        ...(audit ? { support: "supported", source_refs: sourceSpans([source]).map((s) => s.id) } : {}) };
    });
  };
}
export function fetchFixture(): typeof fetch {
  const model = modelFixture();
  return async (_url, init) => {
    const body = JSON.parse(String(init!.body));
    const raw = await model(body.systemInstruction.parts[0].text, JSON.parse(body.contents[0].parts[0].text), {});
    const fields = body.generationConfig.responseFormat.text.schema.properties.items.items.properties;
    const items = Array.isArray(raw) ? raw.map(flatItem).map((v) => {
      if (!record(v) || !Object.hasOwn(v, "inference_count") || Object.hasOwn(fields, "option_defensible")) return v;
      const { option_defensible: _d, option_same_category: _c, option_plausible: _p, ...review } = v;
      return review;
    }) : raw;
    return Response.json({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify({ items }) }] } }] });
  };
}


export function directFetchFixture(): typeof fetch {
  return async (_url, init) => {
    const body = JSON.parse(String(init!.body));
    const input = JSON.parse(body.contents[0].parts[0].text) as Input;
    const questions = JSON.parse(sampleOutput(input)) as Record<string, unknown>[];
    const grouped = Object.fromEntries(types.map((type) => [type, questions.filter((q) => q.type === type)
      .map(({ type: _type, ...q }) => ({ ...q, evidence: "Synthetic test evidence.",
        ...(type === "essay" ? { sample_answer: "A synthetic answer.", rubric: [{ key_point: "A synthetic point.", points: 1 }] } : {}),
      }))]));
    return Response.json({ candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify(grouped) }] } }] });
  };
}
