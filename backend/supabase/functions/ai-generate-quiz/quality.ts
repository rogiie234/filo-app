import type { Input, Question } from "./quiz.ts";
import type { ApplicationPlan } from "./planning.ts";

export interface Objective {
  id: number;
  type: Question["type"];
  difficulty: Input["difficulty"];
  objective: string;
  assessment_task: string;
  fact: string;
  evidence: string;
  plan?: ApplicationPlan;
}

export function difficultyDirection(difficulty: Input["difficulty"], observed: string): "too_easy" | "too_hard" | null {
  const expected = { easy: 0, medium: 1, hard: 2 }[difficulty];
  const actual = ["recall", "interpretation", "multistep"].indexOf(observed);
  if (actual < 0 || actual === expected) return null;
  return actual < expected ? "too_easy" : "too_hard";
}
export const spacing = (s: string) => s.normalize("NFKC").replace(/\s+/gu, " ").trim();
const folded = (s: string) => spacing(s).toLowerCase();
const words = (s: string): string[] => folded(s).match(/[\p{L}\p{N}]+/gu) ?? [];
const stop = new Set("a an the is are be was were what which how does do of in on to and or not true false according lesson statement following".split(" "));
export function overlap(a: string, b: string): number {
  const x = new Set(words(a).filter((w) => !stop.has(w)));
  const y = new Set(words(b).filter((w) => !stop.has(w)));
  if (!x.size || !y.size) return folded(a) === folded(b) ? 1 : 0;
  return [...x].filter((w) => y.has(w)).length / Math.max(x.size, y.size);
}
export function grounded(evidence: string, sources: string[]): boolean {
  return spacing(evidence).length >= 12 && sources.some((s) => spacing(s).includes(spacing(evidence)));
}

export function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state += 0x6D2B79F5;
    let x = state;
    x = Math.imul(x ^ (x >>> 15), x | 1);
    x ^= x + Math.imul(x ^ (x >>> 7), x | 61);
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}
export function shuffled<T>(items: T[], random: () => number): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}
export function arrangeMC(answer: string, distractors: string[], seed: number, position?: number) {
  const random = seededRandom(seed);
  const options = shuffled(distractors, random);
  const correct_index = position ?? Math.floor(random() * 4);
  options.splice(correct_index, 0, answer);
  return { options, correct_index };
}
export function balancePositions(questions: Question[], seed: number): Question[] {
  const count = questions.filter((q) => q.type === "multiple_choice").length;
  const random = seededRandom(seed);
  const order = shuffled([0, 1, 2, 3], random);
  const positions = shuffled(Array.from({ length: count }, (_, i) => order[i % 4]), random);
  let index = 0;
  return questions.map((q) => {
    if (q.type !== "multiple_choice") return q;
    const answer = q.options![q.correct_index!];
    const distractors = q.options!.filter((_, i) => i !== q.correct_index);
    return { ...q, ...arrangeMC(answer, distractors, seed + index, positions[index++]) };
  });
}

// Source-vocabulary splits detect spacing loss without guessing how to rewrite an answer.
export function gluedWords(value: string, source: string): boolean {
  const vocabulary = new Set(words(source));
  // Whereas is a conjunction, not spacing loss between source words where/as.
  for (const w of "maintain describe explain identify assess answer correct incorrect not is are can must should whereas".split(" ")) vocabulary.add(w);
  return words(value).some((word) => {
    if (!/^[a-z]{5,}$/u.test(word) || vocabulary.has(word)) return false;
    for (let i = 2; i <= word.length - 2; i++) {
      if (vocabulary.has(word.slice(0, i)) && vocabulary.has(word.slice(i))) return true;
    }
    return false;
  });
}
export function answerVariants(answers: string[], source: string, prompt = ""): string[] {
  const result = new Map(answers.map((a) => [folded(a), spacing(a)]));
  for (const match of source.matchAll(/([\p{L}][\p{L} -]{2,100}?)\s*\(([A-Z][A-Z0-9]{1,9})\)/gu)) {
    const acronym = match[2];
    const tokens = match[1].trim().split(/\s+/u);
    // Use only an expansion whose initials agree, rather than a whole preceding sentence.
    for (let start = tokens.length - 1; start >= 0; start--) {
      const expansion = tokens.slice(start).join(" ");
      const initials = tokens.slice(start).map((w) => w[0]).join("").toUpperCase();
      // Source-explicit acronyms can include internal letters (Database -> DB in DBMS).
      const letters = new RegExp("^" + [...acronym].join("[\\p{L} -]*") + "[\\p{L} -]*$", "iu");
      if (initials !== acronym && !letters.test(expansion)) continue;
      if (result.has(folded(acronym)) || result.has(folded(expansion))) {
        result.set(folded(acronym), acronym);
        result.set(folded(expansion), expansion);
      }
      break;
    }
  }
  for (const match of source.matchAll(/\b([A-Z][A-Z0-9]{1,9})\s+stands for\s+([^.!?\n]{3,200})/gu)) {
    const [acronym, expansion] = [match[1], spacing(match[2])];
    if (result.has(folded(acronym)) || result.has(folded(expansion))) {
      result.set(folded(acronym), acronym);
      result.set(folded(expansion), expansion);
    }
  }
  const asksExpansion = /\b(?:stand(?:s)? for|expand|full (?:name|form))\b/iu.test(prompt) && !/\bwhat acronym stands for\b/iu.test(prompt);
  const asksAcronym = /\b(?:what|which)\s+acronym\b/iu.test(prompt);
  return [...result.values()].filter((a) => !(asksAcronym && !/^[A-Z][A-Z0-9]{1,9}$/u.test(a)))
    .filter((a) => !(asksExpansion && /^[A-Z][A-Z0-9]{1,9}$/u.test(a) &&
    words(prompt).includes(a.toLowerCase()))).slice(0, 10);
}
export function duplicateObjective(a: Objective, b: Objective): boolean {
  return a.id === b.id || folded(a.fact) === folded(b.fact) || overlap(a.fact, b.fact) >= 0.8;
}

export function nearDuplicateOptions(a: string, b: string): boolean {
  if (folded(a) === folded(b)) return true;
  // Lexical similarity must not erase a changed number, ordinal or negation; blind solving checks meaning.
  const markers = (s: string) => words(s).filter((w) => /\d/u.test(w) ||
    /^(?:first|second|third|fourth|fifth|not|no|never|without)$/u.test(w)).sort().join(" ");
  return markers(a) === markers(b) && overlap(a, b) >= 0.9;
}

export function questionRules(q: Question, objective: Objective, input: Input): string[] {
  const rules = new Set<string>();
  const source = input.texts.join("\n");
  if (!q.evidence || !grounded(q.evidence, input.texts)) rules.add("unsupported_evidence");
  const answer = q.type === "multiple_choice" ? q.options?.[q.correct_index!] ?? "" :
    q.type === "identification" ? q.accepted_answers?.join(" ") ?? "" : q.sample_answer ?? "";
  if (overlap(q.prompt + " " + answer, objective.fact) === 0 ||
    overlap(q.prompt + " " + answer, q.evidence ?? "") === 0) rules.add("objective_alignment");
  const strings = [q.prompt, q.explanation, ...(q.options ?? []), ...(q.accepted_answers ?? []),
    q.sample_answer ?? "", ...(q.rubric ?? []).map((r) => r.key_point)];
  if (strings.some((s) => gluedWords(s, source))) rules.add("glued_words");
  if (q.type !== objective.type) rules.add("objective_type");
  if (q.type === "multiple_choice") {
    const options = q.options ?? [];
    if (options.length !== 4) rules.add("four_options");
    if (!Number.isInteger(q.correct_index) || q.correct_index! < 0 || q.correct_index! >= options.length) rules.add("missing_correct_option");
    for (let i = 0; i < options.length; i++) {
      if (/\b(?:all|none) of (?:the )?above\b/iu.test(options[i])) rules.add("all_none_above");
      if (overlap(options[i], q.prompt) >= 0.9) rules.add("stem_restatement");
      for (let j = 0; j < i; j++) {
        if (nearDuplicateOptions(options[i], options[j])) rules.add("near_duplicate_options");
      }
    }
  } else if (q.type === "true_false") {
    if (/\b(always|never|only|all|any|exclusively|guaranteed)\b/iu.test(q.prompt) &&
      !folded(q.evidence ?? "").includes(folded(q.prompt).replace(/[.!?]+$/u, ""))) rules.add("unsupported_absolute");
  } else if (q.type === "identification") {
    const variants = answerVariants(q.accepted_answers ?? [], source, q.prompt);
    if (!variants.length || (q.accepted_answers ?? []).some((a) => !variants.some((b) => folded(a) === folded(b)))) rules.add("answer_echoes_prompt");
    if (variants.some((a) => !(q.accepted_answers ?? []).some((b) => folded(a) === folded(b)))) rules.add("missing_answer_variant");
  } else {
    if (!q.sample_answer?.trim()) rules.add("missing_sample_answer");
    if (!q.rubric?.length || q.rubric.some((r) => !r.key_point.trim() || !Number.isInteger(r.points) || r.points <= 0) ||
      q.rubric.reduce((sum, r) => sum + r.points, 0) !== q.points) rules.add("rubric_points");
  }
  return [...rules];
}
export function setRules(items: { question: Question; objective: Objective }[]): Map<number, string[]> {
  const rules = new Map<number, string[]>();
  const add = (id: number, rule: string) => rules.set(id, [...new Set([...(rules.get(id) ?? []), rule])]);
  for (let i = 0; i < items.length; i++) for (let j = 0; j < i; j++) {
    if (duplicateObjective(items[i].objective, items[j].objective) || overlap(items[i].question.prompt, items[j].question.prompt) >= 0.8) {
      add(items[i].objective.id, "duplicate_fact");
      add(items[j].objective.id, "duplicate_fact");
    }
  }
  const mc = items.filter((i) => i.question.type === "multiple_choice");
  const long = mc.filter(({ question: q }) => {
    const answer = q.options![q.correct_index!]?.length ?? 0;
    const other = q.options!.filter((_, i) => i !== q.correct_index).map((s) => s.length);
    return answer > Math.max(...other) * 2 && answer - Math.max(...other) > 20;
  });
  if (long.length > mc.length / 2) for (const i of long) add(i.objective.id, "answer_length_cue");
  const counts = [0, 0, 0, 0];
  for (const { question } of mc) counts[question.correct_index!]++;
  if (mc.length >= 4 && Math.max(...counts) - Math.min(...counts) > 1) {
    for (const i of mc) add(i.objective.id, "answer_position_skew");
  }
  return rules;
}

export interface Verdict { id: number; status: "one" | "none" | "multiple"; choices: number[]; answer: string }
export function blindPayload(items: { question: Question; objective: { id: number } }[]) {
  return items.map(({ question: q, objective }) => ({ id: objective.id, type: q.type, prompt: q.prompt,
    ...(q.type === "multiple_choice" ? { options: q.options } : q.type === "true_false" ? { options: ["True", "False"] } : {}) }));
}
export function agrees(q: Question, verdict: Verdict): boolean {
  if (verdict.status !== "one") return false;
  if (q.type === "multiple_choice" || q.type === "true_false") {
    return verdict.choices.length === 1 && verdict.choices[0] === (q.type === "multiple_choice" ? q.correct_index : q.correct_boolean ? 0 : 1);
  }
  if (q.type === "identification") return q.accepted_answers!.some((a) => folded(a) === folded(verdict.answer));
  // shortcut: essay agreement is lexical rubric coverage, retain instructor review for semantic grading.
  return !!verdict.answer.trim() && q.rubric!.every((r) => overlap(r.key_point, verdict.answer) >= 0.15 ||
    words(r.key_point).filter((w) => !stop.has(w)).some((w) => words(verdict.answer).includes(w)));
}
