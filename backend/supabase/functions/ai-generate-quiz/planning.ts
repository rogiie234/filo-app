import type { Input, Question } from "./quiz.ts";
import { spacing } from "./quality.ts";

export interface SourceSpan { id: string; file: number; index: number; start: number; end: number; text: string }
export interface ApplicationPlan {
  source_refs: string[];
  task_kind?: "outcome" | "decision" | "diagnosis";
  scenario: { facts: { id: string; text: string }[]; goal: string; context?: string[]; case?: { fact_id: string; inputs: string[]; action: string } };
  steps: { id: string; facts: string[]; depends_on: string[]; outcome: string }[];
  expected_outcome: string;
  contrast: { fact_id: string; replacement: string; outcome: string };
  answer_category: string;
}
export const record = (v: unknown): v is Record<string, unknown> => !!v && typeof v === "object" && !Array.isArray(v);
const text = (v: unknown, max = 500): v is string => typeof v === "string" && !!v.trim() && Array.from(v).length <= max;
const ids = (v: unknown, max = 4): v is string[] => Array.isArray(v) && v.length <= max &&
  v.every((s) => text(s, 60)) && new Set(v).size === v.length;
const exact = (v: Record<string, unknown>, fields: string[]) => Object.keys(v).length === fields.length && fields.every((k) => k in v);
const same = (a: string, b: string) => spacing(a).toLowerCase() === spacing(b).toLowerCase();
const str = { type: "string" };
const strings = (max: number) => ({ type: "array", maxItems: max, items: str });
const obj = (properties: Record<string, unknown>) => ({ type: "object", additionalProperties: false,
  required: Object.keys(properties), properties });
export const planSchema = obj({
  source_refs: { ...strings(2), minItems: 1 }, task_kind: { ...str, enum: ["", "outcome", "decision", "diagnosis"] },
  scenario: obj({ case: obj({ fact_id: str, inputs: strings(6), action: str }), context: strings(2), facts: { type: "array", maxItems: 4, items: obj({ id: str, text: str }) }, goal: str }),
  steps: { type: "array", maxItems: 3, items: obj({ id: str, facts: strings(4), depends_on: strings(3), outcome: str }) },
  expected_outcome: str, contrast: obj({ fact_id: str, replacement: str, outcome: str }), answer_category: str,
});

export function sourceSpans(sources: string[]): SourceSpan[] {
  return sources.flatMap((source, file) => {
    const value = spacing(source);
    const spans: SourceSpan[] = [];
    // shortcut: sentence segmentation is heuristic; long sentences retain bounded word/Unicode fallback.
    const ends = [...new Intl.Segmenter("en", { granularity: "sentence" }).segment(value)]
      .map((s) => s.index + s.segment.trimEnd().length);
    let sentence = 0, start = 0;
    while (start < value.length) {
      let end = Math.min(start + 400, value.length);
      if (end < value.length) {
        while (sentence < ends.length && ends[sentence] <= start) sentence++;
        let next = sentence;
        while (next < ends.length && ends[next] <= end) next++;
        if (next > sentence) end = ends[next - 1];
        else {
          const boundary = value.lastIndexOf(" ", end);
          if (boundary > start) end = boundary;
        }
        if (/[\uD800-\uDBFF]/u.test(value[end - 1]) && /[\uDC00-\uDFFF]/u.test(value[end])) end--;
      }
      const index = spans.length;
      spans.push({ id: `s${file + 1}.${index + 1}`, file, index, start, end, text: value.slice(start, end) });
      start = end;
      while (value[start] === " ") start++;
    }
    return spans;
  });
}

export function evidenceFor(refs: string[], spans: SourceSpan[]): string | null {
  if (!refs.length || refs.length > 2 || new Set(refs).size !== refs.length) return null;
  const selected = refs.map((id) => spans.find((s) => s.id === id));
  if (selected.some((s) => !s)) return null;
  const values = selected as SourceSpan[];
  if (values.some((s, i) => s.file !== values[0].file || (i > 0 && s.index !== values[i - 1].index + 1))) return null;
  const evidence = values.map((s, i) => (i > 0 && s.start > values[i - 1].end ? " " : "") + s.text).join("");
  return evidence.length >= 12 && Array.from(evidence).length <= 1000 ? evidence : null;
}

export function parsePlan(value: unknown, difficulty: Input["difficulty"], spans: SourceSpan[]): ApplicationPlan | null {
  if (!record(value) || !exact(value, ["source_refs", "scenario", "steps", "expected_outcome", "contrast", "answer_category", ...(Object.hasOwn(value, "task_kind") ? ["task_kind"] : [])]) ||
    !ids(value.source_refs, 2) || !evidenceFor(value.source_refs, spans) ||
    !text(value.expected_outcome) || !text(value.answer_category, 100) || !record(value.scenario) ||
    !exact(value.scenario, ["facts", "goal", ...(Object.hasOwn(value.scenario, "context") ? ["context"] : []), ...(Object.hasOwn(value.scenario, "case") ? ["case"] : [])]) || !text(value.scenario.goal) || !Array.isArray(value.scenario.facts) ||
    value.scenario.facts.length > 4 || !Array.isArray(value.steps) || value.steps.length > 3 || !record(value.contrast) ||
    !exact(value.contrast, ["fact_id", "replacement", "outcome"])) return null;
  const context = value.scenario.context;
  if (context !== undefined && (!Array.isArray(context) || context.length > 2 || !context.every((c) => text(c, 250)))) return null;
  if (difficulty === "medium" ? !["outcome", "decision", "diagnosis"].includes(String(value.task_kind)) : value.task_kind !== undefined || Array.isArray(context) && context.length > 0) return null;
  const facts: ApplicationPlan["scenario"]["facts"] = [];
  for (const f of value.scenario.facts) {
    if (!record(f) || !exact(f, ["id", "text"]) || !text(f.id, 60) || !text(f.text, 250)) return null;
    const id = f.id;
    const factText = spacing(f.text);
    if (facts.some((old) => old.id === id || same(old.text, factText))) return null;
    facts.push({ id, text: factText });
  }
  const steps: ApplicationPlan["steps"] = [];
  for (const s of value.steps) {
    if (!record(s) || !exact(s, ["id", "facts", "depends_on", "outcome"]) || !text(s.id, 60) ||
      !ids(s.facts) || !ids(s.depends_on, 3) || !text(s.outcome) || steps.some((old) => old.id === s.id) ||
      s.facts.some((id) => !facts.some((f) => f.id === id)) ||
      s.depends_on.some((id) => !steps.some((old) => old.id === id))) return null;
    steps.push({ id: s.id, facts: s.facts, depends_on: s.depends_on, outcome: spacing(s.outcome) });
  }
  const concrete = value.scenario.case;
  if (difficulty === "medium") {
    if (!record(concrete) || !exact(concrete, ["fact_id", "inputs", "action"]) ||
      !text(concrete.fact_id, 60) || !Array.isArray(concrete.inputs) || concrete.inputs.length < 2 || concrete.inputs.length > 6 ||
      !concrete.inputs.every((v) => text(v, 80)) || !text(concrete.action, 250) ||
      !steps[0]?.facts.includes(concrete.fact_id) || concrete.fact_id !== value.contrast.fact_id) return null;
  } else if (concrete !== undefined) return null;
  const c = value.contrast;
  if (![c.fact_id, c.replacement, c.outcome].every((v) => typeof v === "string")) return null;
  if (difficulty !== "easy") {
    const changed = facts.find((f) => f.id === c.fact_id);
    if (!changed || !text(c.replacement, 250) || !text(c.outcome) || same(changed.text, c.replacement as string) ||
      same(value.expected_outcome, c.outcome as string) || !steps.some((s) => s.facts.includes(changed.id)) ||
      !steps.length || !same(steps[steps.length - 1].outcome, value.expected_outcome) ||
      steps.some((s) => !s.facts.length && !s.depends_on.length)) return null;
    if (difficulty === "medium" && (steps.length !== 1 || steps[0].depends_on.length || facts.some((f) => !steps[0].facts.includes(f.id)))) return null;
    if (difficulty === "hard" && (steps.length < 2 || steps.slice(1).some((s, i) => !s.depends_on.includes(steps[i].id)))) return null;
  } else if (facts.length || steps.length || c.fact_id || c.replacement || c.outcome) return null;
  return { source_refs: value.source_refs, ...(difficulty === "medium" ? { task_kind: value.task_kind as ApplicationPlan["task_kind"] } : {}),
    scenario: { facts, goal: spacing(value.scenario.goal), ...(Array.isArray(context) && context.length ? { context: context.map((c) => spacing(c)) } : {}),
      ...(record(concrete) ? { case: { fact_id: concrete.fact_id as string, inputs: (concrete.inputs as string[]).map(spacing), action: spacing(concrete.action as string) } } : {}) }, steps,
    expected_outcome: spacing(value.expected_outcome), contrast: { fact_id: c.fact_id as string,
      replacement: spacing(c.replacement as string), outcome: spacing(c.outcome as string) }, answer_category: spacing(value.answer_category) };
}

function materialText(plan: ApplicationPlan, fact: ApplicationPlan["scenario"]["facts"][number]): string {
  const c = plan.scenario.case;
  return c?.fact_id === fact.id ? spacing(`${fact.text} [${c.inputs.join("; ")}] ${c.action}`) : fact.text;
}

export function applicationRules(q: Question, plan: ApplicationPlan): string[] {
  const failures: string[] = [];
  const stem = spacing(q.prompt).toLowerCase();
  const used = new Set(plan.steps.flatMap((s) => s.facts));
  if (plan.scenario.facts.some((f) => used.has(f.id) && !stem.includes(materialText(plan, f).toLowerCase()))) failures.push("scenario_missing");
  if (q.type === "multiple_choice" && !same(q.options![q.correct_index!], plan.expected_outcome)) failures.push("plan_answer_mismatch");
  if (q.type === "identification" && !q.accepted_answers!.some((a) => same(a, plan.expected_outcome))) failures.push("plan_answer_mismatch");
  if (q.type === "true_false" && !same(String(q.correct_boolean), plan.expected_outcome)) failures.push("plan_answer_mismatch");
  if (q.type === "essay" && !same(q.sample_answer ?? "", plan.expected_outcome)) failures.push("plan_answer_mismatch");
  return failures;
}

// shortcut: task operators are English for this evaluation; localize before multilingual rollout.
export function mediumTask(kind: ApplicationPlan["task_kind"], type: Question["type"]): string | null {
  if (type === "true_false") return kind === "decision" ? "The proposed action meets the stated goal under these conditions." : null;
  if (type === "identification") return kind === "diagnosis" ? "Identify the requirement violated by this situation." : null;
  if (type === "essay") return kind === "outcome" ? "Explain the outcome that follows from these conditions using the lesson's rule." :
    kind === "decision" ? "Recommend an action that meets the stated goal and justify it using the lesson's rule." :
    kind === "diagnosis" ? "Explain the requirement violated by this situation and justify your diagnosis using the lesson's rule." : null;
  return kind === "outcome" ? "What outcome follows from these conditions?" :
    kind === "decision" ? "Which action meets the stated goal under these conditions?" :
    kind === "diagnosis" ? "Which requirement is violated by this situation?" : null;
}

export function renderPlan(plan: ApplicationPlan, type: Question["type"]): Record<string, unknown> | null {
  // The learner task cannot contain the planner's private because-rule justification.
  if (/\bbecause\b/iu.test(plan.scenario.goal) || Array.from(plan.scenario.goal).length > 500) return null;
  const used = new Set(plan.steps.flatMap((s) => s.facts));
  const task = plan.task_kind ? mediumTask(plan.task_kind, type) : plan.scenario.goal;
  if (!task) return null;
  const prompt = spacing([...(plan.scenario.context ?? []), ...plan.scenario.facts.filter((f) => used.has(f.id)).map((f) => materialText(plan, f)), task].join(" "));
  if (Array.from(prompt).length > 1000) return null;
  const answer = plan.expected_outcome;
  if (type === "true_false") {
    if (!["true", "false"].includes(answer.toLowerCase())) return null;
    return { prompt, correct_boolean: answer.toLowerCase() === "true" };
  }
  if (type === "identification") return Array.from(answer).length <= 200 ? { prompt, accepted_answers: [answer] } : null;
  return { prompt, ...(type === "multiple_choice" ? { correct_answer: answer } : { sample_answer: answer }) };
}

export function reviewedConditionsMatch(plan: ApplicationPlan, quotes: string[]): boolean {
  const used = new Set(plan.steps.flatMap((s) => s.facts));
  const material = plan.scenario.facts.filter((f) => used.has(f.id));
  const matches = (fact: string, quote: string) => {
    const a = spacing(fact).toLowerCase(), b = spacing(quote).toLowerCase();
    return b.length >= 12 && (a.includes(b) || b.includes(a));
  };
  if (quotes.some((q) => (plan.scenario.context ?? []).some((c) => matches(c, q)) && !material.some((f) => matches(materialText(plan, f), q)))) return false;
  return material.every((f) => quotes.some((quote) => matches(materialText(plan, f), quote)));
}

export type TraceEvent = { stage: string; slot?: number; attempt?: number; [key: string]: unknown };
export type TraceObserver = (event: TraceEvent) => void;
