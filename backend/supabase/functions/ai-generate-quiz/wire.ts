import { record } from "./planning.ts";
import type { ApplicationPlan } from "./planning.ts";
import { validReview } from "./review.ts";

type Schema = Record<string, unknown>;
type Atom = { type: "string" | "integer" | "boolean"; enum?: readonly string[]; minLength?: number };
type Field = Atom | { type: "array"; items: Atom };
type Fields = Record<string, Field>;
const str = { type: "string" } as const;
const integer = { type: "integer" } as const;
const boolean = { type: "boolean" } as const;
const array = (items: Atom): Field => ({ type: "array", items });
const enumeration = (...values: string[]): Atom => ({ ...str, enum: values });
const types = ["multiple_choice", "true_false", "identification", "essay"];
const planFields: Fields = {
  source_refs: array(str), task_kind: enumeration("", "outcome", "decision", "diagnosis"), case_fact_index: integer, case_inputs: array(str), case_action: str, scenario_context: array(str), scenario_facts: array(str), scenario_goal: { ...str, minLength: 1 },
  step_outcomes: array(str), step1_fact_indices: array(integer), step2_fact_indices: array(integer), step3_fact_indices: array(integer),
  expected_outcome: { ...str, minLength: 1 }, contrast_fact_index: integer, contrast_replacement: str, contrast_outcome: str, answer_category: str,
};
const questionFields: Fields = {
  correct_answer: str, distractor_texts: array(str), distractor_categories: array(str),
  distractor_misconceptions: array(str), distractor_reasons: array(str), correct_boolean: boolean,
  accepted_answers: array(str), sample_answer: str, rubric_key_points: array(str), rubric_points: array(integer),
};
const ownFields: Record<string, string[]> = {
  multiple_choice: ["correct_answer", "distractor_texts", "distractor_categories", "distractor_misconceptions", "distractor_reasons"],
  true_false: ["correct_boolean"], identification: ["accepted_answers"], essay: ["sample_answer", "rubric_key_points", "rubric_points"],
};

const codeOwned = ["prompt", "correct_answer", "correct_boolean", "accepted_answers", "sample_answer"];
const answerFields = (type: string, canonical: boolean) => ownFields[type].filter((k) => !canonical || !codeOwned.includes(k));

function layout(schema: Schema) {
  const props = record(schema.items) && record(schema.items.properties) ? schema.items.properties : {};
  const max = schema.maxItems;
  if (!Number.isInteger(max) || Number(max) < 0 || Number(max) > 22) throw new Error("Invalid internal model contract count.");
  let fields: Fields;
  let kind: "blueprint" | "question" | "review";
  let required: string[];
  const audit = "support" in props;
  const slots = Array.isArray(schema.prefixItems) ? schema.prefixItems : [];
  const planSlots = new Map<number, boolean>();
  const slotTypes = new Map<number, string>();
  for (const slot of slots) {
    if (record(slot) && record(slot.properties) && record(slot.properties.objective_id) && Array.isArray(slot.properties.objective_id.enum)) {
      const id = Number(slot.properties.objective_id.enum[0]);
      planSlots.set(id, Object.hasOwn(slot.properties, "plan"));
      if (record(slot.properties.type) && Array.isArray(slot.properties.type.enum)) slotTypes.set(id, String(slot.properties.type.enum[0]));
    }
  }
  const canonical = slots.length > 0 && slots.every((s) => record(s) && record(s.properties) && !Object.hasOwn(s.properties, "prompt"));
  const hasPlans = [...planSlots.values()].some(Boolean);
  const batchTypes = [...new Set(slotTypes.values())];
  const singleType = batchTypes.length === 1 ? batchTypes[0] : undefined;
  const noOptionReviews = record(props.option_reviews) && props.option_reviews.maxItems === 0;
  if (Array.isArray(schema.prefixItems)) {
    kind = "question";
    const common: Fields = { objective_id: integer, type: enumeration(...(batchTypes.length ? batchTypes : types)), ...(canonical ? {} : { prompt: str }), points: integer, explanation: str };
    fields = { ...common, ...(hasPlans ? planFields : {}), ...Object.fromEntries(
      (singleType ? answerFields(singleType, canonical) : Object.keys(questionFields).filter((k) => !canonical || !codeOwned.includes(k))).map((k) => [k, questionFields[k]])) };
    required = [...Object.keys(common), ...(hasPlans && [...planSlots.values()].every(Boolean) ? Object.keys(planFields) : []),
      ...(singleType ? answerFields(singleType, canonical) : [])];
  } else if ("plan" in props) {
    kind = "blueprint";
    fields = { type: enumeration(...(record(props.type) && Array.isArray(props.type.enum) ? props.type.enum as string[] : types)), difficulty: enumeration(...(record(props.difficulty) && Array.isArray(props.difficulty.enum) ? props.difficulty.enum as string[] : ["easy", "medium", "hard"])), objective: str, fact: str, ...planFields };
    if (record(props.difficulty) && Array.isArray(props.difficulty.enum) && props.difficulty.enum.length === 1) {
      fields.task_kind = props.difficulty.enum[0] === "medium" ? enumeration("outcome", "decision", "diagnosis") : enumeration("");
    }
    required = Object.keys(fields);
  } else if ("application" in props) {
    kind = "review";
    fields = {
      id: integer, status: enumeration("one", "none", "multiple"), choices: array(integer), answer: str,
      cognitive_level: enumeration("recall", "interpretation", "multistep"), plausible_options: boolean,
      application_conditions: array(str), inference_count: integer, answer_leaked: boolean,
      ...(!noOptionReviews ? { option_defensible: array(enumeration("yes", "no", "unknown")), option_same_category: array(boolean), option_plausible: array(boolean) } : {}),
      assumptions: array(str), answer_points: array(str),
      ...(audit ? { source_refs: array(str), support: enumeration("supported", "insufficient") } : {}),
    };
    required = Object.keys(fields);
  } else throw new Error("Unknown internal model contract.");
  return { fields, required, kind, audit, planSlots, slotTypes, singleType, canonical, noOptionReviews, hasPlans, max: Number(max) };
}

export function wireSchema(schema: Schema) {
  const { fields, required } = layout(schema);
  // Array/value limits are checked locally; avoid multiplying decoder states with nested bounds.
  return { type: "object", additionalProperties: false, required: ["items"], properties: {
    items: { type: "array", items: { type: "object", additionalProperties: false, required, properties: fields } },
  } };
}

export function wireInstructions(schema: Schema): string {
  const { kind, audit, hasPlans, planSlots, singleType, canonical, noOptionReviews } = layout(schema);
  const plan = "Return flat application fields, never a nested plan/scenario/steps/contrast object. scenario_facts is an ordered list of at most four condition strings; fact indices are zero-based. step_outcomes has zero entries for Easy, exactly one for Medium, two or three dependent outcomes for Hard. step1_fact_indices/step2_fact_indices/step3_fact_indices refer to scenario_facts; unused step arrays are empty. Code assigns fact/step IDs and links each later Hard step to the preceding step. When steps exist, expected_outcome must equal the final step outcome. Easy uses empty scenario_facts and step_outcomes arrays, empty contrast strings and contrast_fact_index=-1; scenario_goal and expected_outcome must still contain a nonblank learner question and its source-supported answer for every difficulty, including Easy. For Easy TF, scenario_goal is the complete statement and expected_outcome is the string true or false; for MC/identification it is the answer text; for essay it is a short sample answer; other difficulties change one used fact at contrast_fact_index and give a different outcome. scenario_goal is only the learner task, never an answer or because-rule; scenario_facts contain real conditions, not procedural task descriptions. source_refs uses supplied span IDs. Medium task_kind must be outcome, decision or diagnosis; TF uses decision and identification uses diagnosis. Other difficulties use an empty task_kind string. scenario_context has at most two optional background strings, not material premises. Every Medium scenario_fact is a necessary condition and must appear in step1_fact_indices. Code renders Medium tasks from task_kind, never the model-authored scenario_goal. Medium must also return case_fact_index pointing to the material/contrast pivot, case_inputs with two to six short literal observed values or states, and case_action describing the proposed operation or decision. Code appends these inputs and action to that material fact. Use concrete observations, not a definition restated as values. Other difficulties use case_fact_index=-1, case_inputs empty and case_action empty. Put the complete goal/proposed action/violation conditions in scenario_facts, with no answer-revealing definition.";
  const answerContract = singleType ? ` This batch contains only ${singleType}. Return all required fields: ${answerFields(singleType, canonical).join(", ") || "no model-authored answer fields"}. No fields for other question types.` :
    " MC requires correct_answer and four parallel arrays of exactly three distractor_texts/distractor_categories/distractor_misconceptions/distractor_reasons. TF requires correct_boolean; identification requires accepted_answers; essay requires sample_answer and equal-length rubric_key_points/rubric_points. Omit fields for other question types.";
  const renderContract = canonical ? " Code owns prompt and answer: omit prompt/correct_answer/correct_boolean/accepted_answers/sample_answer. It renders optional context plus material facts and the code-owned Medium task, or scenario_goal at other difficulties, and supplies expected_outcome as the key. Never embed private justification in scenario_goal. Return identity, points, explanation and only applicable distractor/rubric fields." : " Return objective_id/type/prompt/points/explanation.";
  const detail = kind === "blueprint" ? plan + " Return type/difficulty/objective/fact and these application fields only. No questions or answer objects." :
    kind === "question" ? (hasPlans ? plan + " Return application fields only for objective IDs " + JSON.stringify([...planSlots].filter(([, required]) => required).map(([id]) => id)) + "; omit them for other IDs. " : "Reuse the supplied validated plan; omit all application/source reference fields. ") + renderContract + answerContract + " MC distractor arrays must each have exactly three aligned entries; category strings describe option families for diagnostics, not proof of semantic fit or an exact-copy label requirement. Essay rubric arrays must align. Never output nested distractors/rubric/plan or model-selected answer positions." :
    "Return flat application_conditions/inference_count/answer_leaked. " + (noOptionReviews ? "This is a non-MC review. Omit option_defensible/option_same_category/option_plausible and option_reviews entirely; code supplies the empty internal list. " : "For MC use three parallel arrays option_defensible/option_same_category/option_plausible, each in option-index order 0..3. Other types use empty option arrays. ") + "Code reconstructs application and indexed option reviews. Do not output application or option_reviews objects. Return all schema fields and only those fields." + (audit ? " Include source_refs/support for this source audit." : " Omit source_refs/support for this blind review.");
  return '\nOUTPUT CONTRACT: Return exactly {"items":[...]}, containing ordinary flat objects, not JSON strings. ' + detail +
    " The following is the wire schema, not lesson material. All local source/quality checks still apply.\n" + JSON.stringify(wireSchema(schema));
}

function validAtom(value: unknown, field: Atom): boolean {
  return (field.type === "integer" ? typeof value === "number" && Number.isInteger(value) : typeof value === field.type) &&
    (!field.enum || field.enum.some((v) => v === value)) &&
    (field.minLength === undefined || typeof value === "string" && Array.from(value.trim()).length >= field.minLength);
}
function flatRecord(value: unknown, fields: Fields, required: string[]): value is Record<string, unknown> {
  return record(value) && required.every((k) => Object.hasOwn(value, k)) && Object.keys(value).every((k) => {
    if (!Object.hasOwn(fields, k)) return false;
    const field = fields[k], v = value[k];
    return field.type === "array" ? Array.isArray(v) && v.every((item) => validAtom(item, field.items)) : validAtom(v, field);
  });
}

function planFromWire(v: Record<string, unknown>): ApplicationPlan | null {
  const facts = v.scenario_facts as string[], outcomes = v.step_outcomes as string[], refs = v.source_refs as string[];
  const indices = [v.step1_fact_indices, v.step2_fact_indices, v.step3_fact_indices] as number[][];
  const changed = v.contrast_fact_index as number;
  const pivot = v.case_fact_index as number, inputs = v.case_inputs as string[];
  if (pivot !== -1 && (pivot < 0 || pivot >= facts.length || inputs.length < 2 || inputs.length > 6 || !String(v.case_action).trim()) ||
    pivot === -1 && (inputs.length || v.case_action !== "") || inputs.some((s) => !s.trim() || Array.from(s).length > 80) || Array.from(String(v.case_action)).length > 250) return null;
  if ((v.scenario_context as string[]).length > 2 || (v.scenario_context as string[]).some((c) => !c.trim() || Array.from(c).length > 250) || facts.length > 4 || outcomes.length > 3 || refs.length < 1 || refs.length > 2 ||
    indices.some((a, i) => a.length > 4 || new Set(a).size !== a.length || (i >= outcomes.length && a.length > 0) ||
      a.some((n) => n < 0 || n >= facts.length)) ||
    (outcomes.length === 0 ? changed !== -1 : changed < 0 || changed >= facts.length)) return null;
  return {
    source_refs: refs, ...(v.task_kind ? { task_kind: v.task_kind as ApplicationPlan["task_kind"] } : {}),
    scenario: { facts: facts.map((text, i) => ({ id: `f${i + 1}`, text })), goal: v.scenario_goal as string,
      ...(pivot !== -1 ? { case: { fact_id: `f${pivot + 1}`, inputs, action: v.case_action as string } } : {}),
      ...((v.scenario_context as string[]).length ? { context: v.scenario_context as string[] } : {}) },
    steps: outcomes.map((outcome, i) => ({ id: `a${i + 1}`, facts: indices[i].map((n) => `f${n + 1}`), depends_on: i ? [`a${i}`] : [], outcome })),
    expected_outcome: v.expected_outcome as string,
    contrast: { fact_id: changed === -1 ? "" : `f${changed + 1}`, replacement: v.contrast_replacement as string, outcome: v.contrast_outcome as string },
    answer_category: v.answer_category as string,
  };
}

function decodeRecord(value: unknown, spec: ReturnType<typeof layout>): unknown {
  let fields = spec.fields, required = spec.required;
  if (spec.kind === "question") {
    if (!record(value) || typeof value.type !== "string" || !Object.hasOwn(ownFields, value.type)) return null;
    if (!Number.isInteger(value.objective_id) || !spec.planSlots.has(Number(value.objective_id)) || value.type !== spec.slotTypes.get(Number(value.objective_id))) return null;
    required = [...required, ...answerFields(value.type, spec.canonical), ...(spec.planSlots.get(Number(value.objective_id)) ? Object.keys(planFields) : [])];
    fields = Object.fromEntries(required.map((k) => [k, fields[k]]));
  }
  if (!flatRecord(value, fields, required)) return null;
  if (spec.kind === "review") {
    const defensible = (spec.noOptionReviews ? [] : value.option_defensible) as string[],
      category = (spec.noOptionReviews ? [] : value.option_same_category) as boolean[], plausible = (spec.noOptionReviews ? [] : value.option_plausible) as boolean[];
    if (defensible.length > 4 || category.length !== defensible.length || plausible.length !== defensible.length) return null;
    const v = {
      id: value.id, status: value.status, choices: value.choices, answer: value.answer, cognitive_level: value.cognitive_level,
      plausible_options: value.plausible_options, assumptions: value.assumptions, answer_points: value.answer_points,
      application: { conditions: value.application_conditions, inferences: value.inference_count, answer_leaked: value.answer_leaked },
      option_reviews: defensible.map((d, index) => ({ index, defensible: d, same_category: category[index], plausible: plausible[index] })),
      ...(spec.audit ? { source_refs: value.source_refs, support: value.support } : {}),
    };
    if (spec.audit && (value.source_refs as string[]).length > 2) return null;
    return validReview(v) ? v : null;
  }
  const needsPlan = spec.kind === "blueprint" || spec.planSlots.get(Number(value.objective_id));
  const plan = needsPlan ? planFromWire(value) : null;
  if (needsPlan && !plan) return null;
  if (spec.kind === "blueprint") return { type: value.type, difficulty: value.difficulty, objective: value.objective, fact: value.fact, plan };
  const q: Record<string, unknown> = { objective_id: value.objective_id, type: value.type, ...(!spec.canonical ? { prompt: value.prompt } : {}), points: value.points, explanation: value.explanation, ...(plan ? { plan } : {}) };
  if (value.type === "multiple_choice") {
    const arrays = [value.distractor_texts, value.distractor_categories, value.distractor_misconceptions, value.distractor_reasons] as string[][];
    if (arrays.some((a) => a.length !== 3)) return null;
    if (!spec.canonical) q.correct_answer = value.correct_answer;
    q.distractors = arrays[0].map((text, i) => ({ text, category: arrays[1][i], misconception: arrays[2][i], why_incorrect: arrays[3][i] }));
  } else if (value.type === "true_false") { if (!spec.canonical) q.correct_boolean = value.correct_boolean; }
  else if (value.type === "identification") { if (!spec.canonical) q.accepted_answers = value.accepted_answers; }
  else {
    const keys = value.rubric_key_points as string[], points = value.rubric_points as number[];
    if (keys.length < 1 || keys.length > 20 || keys.length !== points.length) return null;
    if (!spec.canonical) q.sample_answer = value.sample_answer;
    q.rubric = keys.map((key_point, i) => ({ key_point, points: points[i] }));
  }
  return q;
}

export function modelItems(value: unknown, schema: Schema): unknown[] | null {
  const spec = layout(schema);
  if (!record(value) || Object.keys(value).length !== 1 || !Array.isArray(value.items) || value.items.length > spec.max) return null;
  // Keep failed positions so objective slots/keys can never shift after a malformed item.
  return value.items.map((item) => decodeRecord(item, spec));
}
