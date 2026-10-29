// Maintained C1/B1 calibration runner. One optional owner-run call; no quiz generation/deployment.
import { blindReviewRequest } from "../supabase/functions/ai-generate-quiz/pipeline.ts";
import { agrees, spacing } from "../supabase/functions/ai-generate-quiz/quality.ts";
import { reviewRules, validReview } from "../supabase/functions/ai-generate-quiz/review.ts";
import type { Question } from "../supabase/functions/ai-generate-quiz/quiz.ts";
import { modelItems, modelRequest, readLimited } from "../supabase/functions/ai-generate-quiz/quiz.ts";

export const referenceURL = new URL("../../docs/ai-quality-calibration.md", import.meta.url);
export const boundaryURL = new URL("../../docs/ai-quality-check.md", import.meta.url);
const approvedBoundaryHash = "4a3a74cffbc65e8696e9a8f24fa32e666ad26040345ae1f7a393d761cc49deaf";
const approvedHash = "f950b95a492bec1afe104744723b6ab94799a8d0090e9ee3c536ddb333bd3780";
type Level = "recall" | "interpretation";
export interface CalibrationItem { id: string; question: Question; level: Level; status: "one" | "none"; submittedLevel: Level }
const definitions: { id: string; type: Question["type"]; level: Level; key?: number | boolean | string[]; rubric?: Question["rubric"] }[] = [
  { id: "C1-E-MC", type: "multiple_choice", level: "recall", key: 1 },
  { id: "C1-M-MC", type: "multiple_choice", level: "interpretation", key: 3 },
  { id: "C1-E-TF", type: "true_false", level: "recall", key: true },
  { id: "C1-M-TF", type: "true_false", level: "interpretation", key: false },
  { id: "C1-E-ID", type: "identification", level: "recall", key: ["UNIQUE", "UNIQUE constraint"] },
  { id: "C1-M-ID", type: "identification", level: "interpretation", key: ["UNIQUE", "UNIQUE constraint"] },
  { id: "C1-E-ESS", type: "essay", level: "recall", rubric: [{ key_point: "Defines data as raw facts", points: 1 }, { key_point: "Defines information as processed organized data providing meaning", points: 1 }] },
  { id: "C1-M-ESS", type: "essay", level: "interpretation", rubric: [{ key_point: "Classifies individual Units values as raw data", points: 1 }, { key_point: "Classifies the calculated summary total as information", points: 1 }, { key_point: "Connects aggregation processing to a meaningful summary", points: 1 }] },
  { id: "C1-N-LEVEL", type: "true_false", level: "recall", key: true },
  { id: "C1-N-KEY", type: "multiple_choice", level: "recall" },
];

export async function loadCalibration(document: string): Promise<CalibrationItem[]> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(spacing(document)));
  const hash = [...new Uint8Array(digest)].map((n) => n.toString(16).padStart(2, "0")).join("");
  if (hash !== approvedHash) throw new Error("C1 reference differs from owner-accepted content; stop and review the revision.");
  const sections = new Map(document.split(/^### /mu).slice(1).map((s) => [s.split(/\s/u)[0], s.slice(s.indexOf("\n") + 1).split(/^## /mu)[0]]));
  return definitions.map((d) => {
    const body = sections.get(d.id);
    if (!body) throw new Error("C1 reference item missing.");
    const paragraphs = body.trim().split(/\r?\n\s*\r?\n/u);
    const index = d.id === "C1-N-LEVEL" ? 1 : 0;
    const question: Question = { type: d.type, prompt: spacing(paragraphs[index]), points: d.rubric?.reduce((sum, r) => sum + r.points, 0) ?? 1, explanation: "" };
    if (d.type === "multiple_choice") {
      question.options = paragraphs[index + 1].split(/\r?\n/u).map((s) => spacing(s.replace(/^[A-D]\.\s*/u, "")));
      if (question.options.length !== 4) throw new Error("C1 multiple-choice options malformed.");
      if (typeof d.key === "number") question.correct_index = d.key;
    } else if (d.type === "true_false") question.correct_boolean = d.key as boolean;
    else if (d.type === "identification") question.accepted_answers = d.key as string[];
    else question.rubric = d.rubric;
    return { id: d.id, question, level: d.level, status: d.id === "C1-N-KEY" ? "none" : "one", submittedLevel: d.id === "C1-N-LEVEL" ? "interpretation" : d.level };
  });
}

export async function loadBoundaryCalibration(report: string): Promise<CalibrationItem[]> {
  const start = report.indexOf("## B1 owner-accepted difficulty-boundary supplement - 2026-10-28");
  if (start < 0) throw new Error("B1 accepted reference missing; stop and review the revision.");
  const end = report.indexOf("\n## ", start + 1);
  const document = report.slice(start, end < 0 ? undefined : end);
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(spacing(document)));
  const hash = [...new Uint8Array(digest)].map((n) => n.toString(16).padStart(2, "0")).join("");
  if (hash !== approvedBoundaryHash) throw new Error("B1 reference differs from owner-accepted content; stop and review the revision.");
  const sections = new Map(document.split(/^### /mu).slice(1).map((s) => [s.split(/\s/u)[0].replace(/:$/u, ""), s]));
  return (["B1-R-ID", "B1-D-MC"] as const).map((id): CalibrationItem => {
    const body = sections.get(id);
    if (!body) throw new Error("B1 reference item missing.");
    const prompt = spacing([...body.matchAll(/^> (.+)$/gmu)].map((m) => m[1]).join(" "));
    if (!prompt) throw new Error("B1 question missing.");
    const recall = id === "B1-R-ID";
    const question: Question = { type: recall ? "identification" : "multiple_choice", prompt, points: 1, explanation: "" };
    if (recall) question.accepted_answers = ["DBMS", "Database Management System"];
    else {
      const options = [...body.matchAll(/^([A-D])\. (.+)$/gmu)];
      if (options.length !== 4 || options.some((m, i) => m[1] !== "ABCD"[i])) throw new Error("B1 multiple-choice options malformed.");
      question.options = options.map((m) => spacing(m[2]));
      question.correct_index = 1;
    }
    return { id, question, level: recall ? "recall" : "interpretation", status: "one", submittedLevel: recall ? "recall" : "interpretation" };
  });
}

export function calibrationRequest(items: CalibrationItem[]) {
  return blindReviewRequest(items.map((item, id) => ({ question: item.question, objective: { id } })));
}
export function scoreCalibration(items: CalibrationItem[], values: unknown, reference: "C1" | "B1" = "C1") {
  const rows = items.map((item, id) => {
    const matches = Array.isArray(values) ? values.filter((v) => !!v && typeof v === "object" && (v as { id?: unknown }).id === id) : [];
    const v = matches.length === 1 && validReview(matches[0]) ? matches[0] : null;
    const answer_agrees = !!v && (item.status === "none" ? v.status === "none" : agrees(item.question, v));
    // Cognitive level is not scored when the control has no defensible answer.
    const level_agrees = item.status === "none" ? null : !!v && v.cognitive_level === item.level;
    const findings = v ? reviewRules(item.question, v, item.submittedLevel === "recall" ? "easy" : "medium")
      .filter((r) => !(item.status === "none" && r === "verifier_key_mismatch")) : ["verifier_malformed"];
    const reviewer_accepts = !!v && v.status === "one" && !findings.length;
    const expected_accept = item.status === "one" && item.level === item.submittedLevel;
    return { id: item.id, malformed: !v, answer_agrees, expected_level: item.status === "none" ? null : item.level,
      observed_level: v?.cognitive_level ?? null, level_agrees, reviewer_accepts, expected_accept,
      false_accept: !expected_accept && reviewer_accepts, false_reject: expected_accept && !reviewer_accepts, findings,
      // Synthetic reference answers only; useful for manual review of lexical essay/variant agreement.
      solver_answer: item.question.type === "essay" || item.question.type === "identification" ? v?.answer ?? null : null };
  });
  return { reference, items: rows.length, solving_agreements: rows.filter((r) => r.answer_agrees).length,
    level_agreements: rows.filter((r) => r.level_agrees === true).length, level_scored_items: rows.filter((r) => r.level_agrees !== null).length,
    false_accepts: rows.filter((r) => r.false_accept).length, false_rejects: rows.filter((r) => r.false_reject).length, rows };
}

export async function runCalibration(document: string, key: string, model: string, fetcher: typeof fetch = fetch, reference: "C1" | "B1" = "C1") {
  if (!key.trim() || !/^[a-zA-Z0-9._-]+$/u.test(model)) throw new Error("Set private GEMINI_API_KEY and exact approved GEMINI_MODEL locally.");
  const items = await (reference === "B1" ? loadBoundaryCalibration(document) : loadCalibration(document));
  const review = calibrationRequest(items);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 45000);
  try {
    const response = await fetcher(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST", signal: controller.signal, headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify(modelRequest(review.system, review.data, review.schema)),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error(`Calibration HTTP ${response.status}; no retry performed.`);
    }
    const envelope = JSON.parse(await readLimited(response, 262144, "AI_BAD_OUTPUT", controller.signal));
    const candidate = envelope?.candidates?.[0];
    if (candidate?.finishReason !== "STOP" || !Array.isArray(candidate?.content?.parts)) throw new Error("Incomplete calibration response.");
    const raw = candidate.content.parts.filter((p: { thought?: boolean; text?: unknown }) => p.thought !== true && typeof p.text === "string")
      .map((p: { text: string }) => p.text).join("");
    const decoded = modelItems(JSON.parse(raw), review.schema);
    if (!decoded) throw new Error("Invalid calibration transport envelope.");
    const result = scoreCalibration(items, decoded, reference);
    return { ...result, model, calls: 1, verifier: "current shared blindReviewRequest" };
  } finally { clearTimeout(timer); controller.abort(); }
}

if (import.meta.main) {
  try {
    const reference = Deno.args.includes("--boundary") ? "B1" : "C1";
    const document = await Deno.readTextFile(reference === "B1" ? boundaryURL : referenceURL);
    if (Deno.args.includes("--check")) {
      const items = await (reference === "B1" ? loadBoundaryCalibration(document) : loadCalibration(document));
      console.log(JSON.stringify({ reference, items: items.length, status: "reference checked; NO model call" }));
    } else if (Deno.args.includes("--live")) {
      console.log(JSON.stringify(await runCalibration(document, Deno.env.get("GEMINI_API_KEY") ?? "", Deno.env.get("GEMINI_MODEL") ?? "", fetch, reference), null, 2));
    } else throw new Error("Choose --check (offline) or --live (one owner-run Gemini call); add --boundary for B1.");
  } catch (error) {
    // Never print raw provider/transport errors, payloads or credentials.
    const message = error instanceof Error && /^(?:C1 |B1 |Set private |Calibration HTTP |Incomplete calibration|Choose --)/u.test(error.message)
      ? error.message : "Calibration failed; response invalid or transport unavailable. No automatic retry.";
    console.error(message);
    Deno.exitCode = 1;
  }
}
