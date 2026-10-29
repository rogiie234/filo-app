import type { Input, Question } from "./quiz.ts";
import { agrees, difficultyDirection, overlap, spacing } from "./quality.ts";
import type { Verdict } from "./quality.ts";
import { record } from "./planning.ts";

export interface ReviewVerdict extends Verdict {
  cognitive_level: "recall" | "interpretation" | "multistep";
  plausible_options: boolean;
  application: { conditions: string[]; inferences: number; answer_leaked: boolean };
  option_reviews: { index: number; defensible: "yes" | "no" | "unknown"; same_category: boolean; plausible: boolean }[];
  assumptions: string[];
  answer_points: string[];
}
const str = { type: "string" };
const strings = { type: "array", maxItems: 6, items: str };
const boolean = { type: "boolean" };
const obj = (properties: Record<string, unknown>) => ({ type: "object", additionalProperties: false,
  required: Object.keys(properties), properties });
export function reviewSchema(n: number, audit = false, questionType?: Question["type"]) {
  return { type: "array", maxItems: n, items: obj({
    id: { type: "integer" }, status: { ...str, enum: ["one", "none", "multiple"] },
    choices: { type: "array", maxItems: 4, items: { type: "integer" } }, answer: str,
    cognitive_level: { ...str, enum: ["recall", "interpretation", "multistep"] }, plausible_options: boolean,
    application: obj({ conditions: strings, inferences: { type: "integer", minimum: 0, maximum: 3 }, answer_leaked: boolean }),
    option_reviews: { type: "array", maxItems: questionType && questionType !== "multiple_choice" ? 0 : 4, items: obj({ index: { type: "integer" },
      defensible: { ...str, enum: ["yes", "no", "unknown"] }, same_category: boolean, plausible: boolean }) },
    assumptions: strings, answer_points: strings,
    ...(audit ? { source_refs: { ...strings, maxItems: 2 }, support: { ...str, enum: ["supported", "insufficient"] } } : {}),
  }) };
}
const texts = (v: unknown): v is string[] => Array.isArray(v) && v.length <= 6 &&
  v.every((s) => typeof s === "string" && !!s.trim() && Array.from(s).length <= 500);
export function validReview(v: unknown): v is ReviewVerdict {
  if (!record(v) || !Number.isInteger(v.id) || !["one", "none", "multiple"].includes(String(v.status)) ||
    !Array.isArray(v.choices) || v.choices.length > 4 || !v.choices.every((c) => Number.isInteger(c) && c >= 0 && c < 4) ||
    new Set(v.choices).size !== v.choices.length || typeof v.answer !== "string" || Array.from(v.answer).length > 4000 ||
    !["recall", "interpretation", "multistep"].includes(String(v.cognitive_level)) || typeof v.plausible_options !== "boolean" ||
    !record(v.application) || !texts(v.application.conditions) || !Number.isInteger(v.application.inferences) ||
    Number(v.application.inferences) < 0 || Number(v.application.inferences) > 3 || typeof v.application.answer_leaked !== "boolean" ||
    !Array.isArray(v.option_reviews) || v.option_reviews.length > 4 || !texts(v.assumptions) || !texts(v.answer_points)) return false;
  return v.option_reviews.every((o) => record(o) && Number.isInteger(o.index) && Number(o.index) >= 0 && Number(o.index) < 4 &&
    ["yes", "no", "unknown"].includes(String(o.defensible)) && typeof o.same_category === "boolean" && typeof o.plausible === "boolean");
}

export function reviewRules(q: Question, v: ReviewVerdict, difficulty: Input["difficulty"]): string[] {
  const rules = new Set<string>();
  if (v.status === "none") rules.add("verifier_none");
  if (v.status === "multiple") rules.add("verifier_multiple");
  if (v.status === "one" && !agrees(q, v)) rules.add("verifier_key_mismatch");
  if (difficultyDirection(difficulty, v.cognitive_level)) rules.add("verifier_difficulty");
  const app = v.application;
  if (app.answer_leaked) rules.add("verifier_answer_leak");
  if (app.conditions.some((quote) => !spacing(q.prompt).includes(spacing(quote)))) rules.add("verifier_application");
  if (difficulty !== "easy" && (!app.conditions.length || app.answer_leaked ||
    (difficulty === "medium" ? app.inferences !== 1 : app.inferences < 2))) rules.add("verifier_application");
  if (v.assumptions.length) rules.add("verifier_assumptions");
  if (q.type === "multiple_choice") {
    const options = v.option_reviews;
    if (options.length !== 4 || new Set(options.map((o) => o.index)).size !== 4) rules.add("verifier_malformed");
    else {
      const yes = options.filter((o) => o.defensible === "yes").map((o) => o.index).sort();
      if (options.some((o) => o.defensible === "unknown") || yes.length !== 1 ||
        v.status !== "one" || v.choices.length !== 1 || yes[0] !== v.choices[0]) rules.add("verifier_ambiguity");
      if (!v.plausible_options || options.some((o) => !o.same_category || !o.plausible)) rules.add("verifier_distractors");
    }
  } else if (v.option_reviews.length) rules.add("verifier_malformed");
  if (q.type === "essay" && (!v.answer_points.length || q.rubric!.some((r) =>
    !v.answer_points.some((p) => overlap(r.key_point, p) >= 0.3)))) rules.add("verifier_rubric_coverage");
  return [...rules];
}
