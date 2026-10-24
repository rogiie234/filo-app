// DEV-only maintained load harness. Node 22+, built-ins only; owner executes.
// Auth REST contracts: https://github.com/supabase/auth-js/blob/master/src/GoTrueAdminApi.ts
// Native fetch/abort: https://nodejs.org/api/globals.html#fetch
import { randomBytes, randomUUID } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync, renameSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { setTimeout as sleep } from 'node:timers/promises';

export const PROJECT = 'fiobwfzmqcffbpixzvbq';
const BASE = `https://${PROJECT}.supabase.co`;
const OUTPUT = join(dirname(fileURLToPath(import.meta.url)), '.exam-load');
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const SAVE_COUNT = 60;
const INTERVAL = 10_000;
const DURATION = 600_000;
const mark = (id) => `M8 load ${id}`;
const check = (ok, code) => { if (!ok) throw Object.assign(new Error(code), { code }); };
const safeCode = (value, fallback = 'REQUEST_FAILED') =>
  typeof value === 'string' && /^[A-Za-z0-9_]{1,80}$/.test(value) ? value : fallback;

export function validateSaveReceipt(receipts, question, revision) {
  check(Array.isArray(receipts) && receipts.length === 1
    && receipts[0]?.question_id === question && receipts[0].revision === revision
    && !receipts[0].error_code && !receipts[0].error_message
    && typeof receipts[0].saved_at === 'string'
    && Number.isFinite(Date.parse(receipts[0].saved_at)), 'INVALID_SAVE_RESPONSE');
}

export function nextSaveAt(barrier, tick, jitter, lastStart = -Infinity) {
  check(Number.isInteger(tick) && tick >= 1 && tick <= SAVE_COUNT, 'INVALID_TICK');
  check(Number.isFinite(jitter) && Math.abs(jitter) <= 1000, 'INVALID_JITTER');
  // Never compress delayed saves into a catch-up burst; report the resulting lag.
  return Math.max(barrier + tick * INTERVAL + jitter, lastStart + 9000);
}

export function statistics(rows, durationMs) {
  const values = rows.map((r) => r.duration_ms).sort((a, b) => a - b);
  const errors = {};
  for (const row of rows.filter((r) => !r.ok)) {
    errors[row.error_code] = (errors[row.error_code] ?? 0) + 1;
  }
  return {
    count: rows.length,
    average_ms: values.length ? values.reduce((a, b) => a + b, 0) / values.length : null,
    p95_ms: values.length ? values[Math.ceil(values.length * 0.95) - 1] : null,
    slowest_ms: values.at(-1) ?? null,
    at_or_over_1s: values.filter((v) => v >= 1000).length,
    failures: rows.filter((r) => !r.ok).length,
    requests_per_second: durationMs > 0 ? rows.length / (durationMs / 1000) : 0,
    errors,
  };
}

export function buildQuizFixture(quizId) {
  const questions = [], options = [], keys = [];
  for (let i = 0; i < 30; i++) {
    const type = i < 10 ? 'multiple_choice' : i < 18 ? 'true_false' : i < 26 ? 'identification' : 'essay';
    const question = { id: randomUUID(), quiz_id: quizId, position: i, type, points: 1, prompt: `Load question ${i + 1}` };
    // PostgREST bulk JSON rows require identical keys, including unused columns.
    const key = { question_id: question.id, correct_option_id: null, correct_boolean: null, accepted_answers: null };
    const definition = { ...question };
    if (type === 'multiple_choice') {
      const choices = Array.from({ length: 4 }, (_, p) => ({ id: randomUUID(), question_id: question.id, position: p, text: `Option ${p + 1}` }));
      options.push(...choices); key.correct_option_id = choices[0].id;
      definition.correctOption = choices[0].id;
    } else if (type === 'true_false') {
      key.correct_boolean = i % 2 === 0; definition.correctBoolean = key.correct_boolean;
    } else if (type === 'identification') key.accepted_answers = ['Green Leaf'];
    if (type !== 'essay') keys.push(key);
    questions.push(definition);
  }
  return { questions, options, keys };
}

function credentials(needsAnon) {
  const service = process.env.FILO_LOAD_SERVICE_ROLE_KEY;
  check(service, 'MISSING_SERVICE_ROLE_KEY');
  let claims;
  try { claims = JSON.parse(Buffer.from(service.split('.')[1], 'base64url').toString()); }
  catch { check(false, 'REQUIRES_LEGACY_SERVICE_ROLE_JWT'); }
  check(claims.role === 'service_role' && claims.ref === PROJECT, 'SERVICE_KEY_NOT_DEV');
  const anon = process.env.FILO_LOAD_ANON_KEY;
  check(!needsAnon || anon, 'MISSING_ANON_OR_PUBLISHABLE_KEY');
  if (anon?.startsWith('eyJ')) {
    let publicClaims;
    try { publicClaims = JSON.parse(Buffer.from(anon.split('.')[1], 'base64url').toString()); }
    catch { check(false, 'INVALID_PUBLIC_KEY'); }
    check(publicClaims.ref === PROJECT && publicClaims.role === 'anon', 'PUBLIC_KEY_NOT_DEV');
  } else if (anon) {
    check(/^sb_publishable_[A-Za-z0-9_-]+$/.test(anon), 'REQUIRES_PUBLIC_ANON_OR_PUBLISHABLE_KEY');
  }
  return { service, anon };
}

function saveManifest(dir, manifest) {
  const path = join(dir, 'manifest.json');
  writeFileSync(`${path}.tmp`, JSON.stringify(manifest, null, 2), { mode: 0o600 });
  renameSync(`${path}.tmp`, path);
}

function api(keys, dir, controller, measuredRows, scenario) {
  return async function request(path, {
    method = 'GET', body, token, stage = 'setup', operation = 'fixture', actor = 0,
    lag = 0, pacing = 0, validate, ignoreStop = false, notFoundOk = false,
  } = {}) {
    const began = performance.now();
    const timestamp = new Date().toISOString();
    let status = 0, data, errorCode = null, retryAfter = null;
    try {
      const key = token ? keys.anon : keys.service;
      const response = await fetch(`${BASE}${path}`, {
        method,
        headers: {
          apikey: key,
          Authorization: `Bearer ${token ?? keys.service}`,
          'Content-Type': 'application/json',
          Prefer: 'return=representation',
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        redirect: 'error',
        signal: AbortSignal.any([
          AbortSignal.timeout(15_000),
          ...(ignoreStop ? [] : [controller.signal]),
        ]),
      });
      status = response.status;
      retryAfter = response.headers.get('retry-after');
      const text = await response.text();
      try { data = text ? JSON.parse(text) : null; }
      catch { check(false, 'INVALID_JSON_RESPONSE'); }
      if (!response.ok && !(notFoundOk && status === 404)) {
        errorCode = safeCode(data?.code ?? data?.error_code, `HTTP_${status}`);
        check(false, errorCode);
      }
      if (notFoundOk && status === 404) data = null;
      // Auth Admin responses can be a user directly or wrapped as { user }.
      if (path.startsWith('/auth/v1/admin/users') && !path.includes('?') && data?.user) data = data.user;
      validate?.(data);
    } catch (error) {
      errorCode ??= controller.signal.aborted && !ignoreStop ? 'INTERRUPTED'
        : safeCode(error.code, error.name === 'TimeoutError' ? 'TIMEOUT' : 'TRANSPORT_OR_PROTOCOL_ERROR');
    }
    const row = {
      timestamp, stage, scenario: `${scenario}_students`, actor, rpc: operation,
      duration_ms: performance.now() - began,
      scheduling_lag_ms: Math.max(0, lag), http_status: status,
      pacing_delay_ms: Math.max(0, pacing),
      ok: errorCode === null, error_code: errorCode,
      retry_after_seconds: retryAfter !== null && /^\d+$/.test(retryAfter) ? Number(retryAfter) : null,
    };
    // Payloads, tokens, passwords, server messages and answer content never enter logs.
    appendFileSync(join(dir, stage === 'load' ? 'calls.jsonl' : 'lifecycle.jsonl'), `${JSON.stringify(row)}\n`);
    if (stage === 'load') measuredRows.push(row);
    if (errorCode) throw Object.assign(new Error(errorCode), { code: errorCode, status });
    return data;
  };
}

const rest = (table, query = '') => `/rest/v1/${table}${query ? `?${query}` : ''}`;
const rpc = (name) => `/rest/v1/rpc/${name}`;

async function setup(request, manifest, dir, signal) {
  const groups = [];
  let actorNumber = 0;
  for (let c = 0; c < manifest.students / 40; c++) {
    const people = [];
    for (let i = 0; i <= 40; i++) {
      const actor = actorNumber++;
      const email = `m8.${manifest.run_id}.${actor}@example.invalid`;
      const password = `Filo-${randomBytes(24).toString('hex')}aA1!`;
      const user = await request('/auth/v1/admin/users', {
        method: 'POST', operation: 'create_user', actor,
        body: { email, password, email_confirm: true,
          app_metadata: { filo_exam_load_run: manifest.run_id } },
        validate: (u) => check(UUID.test(u?.id), 'INVALID_CREATED_USER'),
      });
      manifest.users.push(user.id);
      saveManifest(dir, manifest);
      await request(rest('profiles'), {
        method: 'POST', operation: 'create_profile', actor,
        body: { id: user.id, role: i === 0 ? 'instructor' : 'student', display_name: mark(manifest.run_id) },
      });
      const auth = await request('/auth/v1/token?grant_type=password', {
        method: 'POST', operation: 'sign_in', actor,
        body: { email, password },
        validate: (s) => check(typeof s?.access_token === 'string' && s.user?.id === user.id, 'INVALID_AUTH_SESSION'),
      });
      const claims = JSON.parse(Buffer.from(auth.access_token.split('.')[1], 'base64url').toString());
      check(UUID.test(claims.session_id) && claims.sub === user.id && claims.role === 'authenticated', 'INVALID_SESSION_CLAIMS');
      await request(rest('verified_sessions'), {
        method: 'POST', operation: 'verify_fixture_session', actor,
        body: { user_id: user.id, session_id: claims.session_id },
      });
      people.push({ id: user.id, actor, token: auth.access_token, expires: claims.exp });
      // Authentication preparation is excluded from the measured exam workload.
      await sleep(2100, undefined, { signal });
      if (i % 10 === 0) console.log(`Prepared class ${c + 1}: ${i}/40 students`);
    }
    const owner = people[0];
    const group = {
      id: randomUUID(), quiz: randomUUID(), owner: owner.id,
      students: people.slice(1), questions: [],
    };
    const fixture = { id: group.id, quiz: group.quiz, owner: owner.id,
      students: group.students.map((s) => s.id), questions: [], options: [] };
    manifest.classes.push(fixture);
    saveManifest(dir, manifest);
    await request(rest('classes'), {
      method: 'POST', operation: 'create_class',
      body: { id: group.id, owner_id: owner.id, course: mark(manifest.run_id), section: `Load ${c + 1}`, school_year: '2026-2027' },
    });
    await request(rest('class_members'), {
      method: 'POST', operation: 'create_memberships',
      body: group.students.map((s) => ({ class_id: group.id, student_id: s.id, status: 'active' })),
    });
    await request(rest('quizzes'), {
      method: 'POST', operation: 'create_quiz',
      body: { id: group.quiz, class_id: group.id, author_id: owner.id, title: mark(manifest.run_id),
        type: 'exam', time_limit_minutes: 30, shuffle_questions: true, shuffle_options: true,
        show_correct_answers: false, opens_at: new Date(Date.now() - 60_000).toISOString(),
        closes_at: new Date(Date.now() + 45 * 60_000).toISOString() },
    });
    const { questions, options, keys } = buildQuizFixture(group.quiz);
    group.questions = questions;
    fixture.questions = group.questions.map((q) => q.id);
    fixture.options = options.map((o) => o.id);
    saveManifest(dir, manifest);
    await request(rest('questions'), {
      method: 'POST', operation: 'create_questions',
      body: group.questions.map(({ correctOption, correctBoolean, ...q }) => q),
    });
    await request(rest('question_options'), { method: 'POST', operation: 'create_options', body: options });
    await request(rest('answer_keys'), { method: 'POST', operation: 'create_keys', body: keys });
    await request(rpc('publish_quiz'), {
      method: 'POST', operation: 'publish_quiz', token: owner.token, body: { p_quiz: group.quiz },
      validate: (q) => check(q?.status === 'published', 'QUIZ_NOT_PUBLISHED'),
    });
    groups.push(group);
  }
  check(groups.flatMap((g) => g.students).every((s) => s.expires * 1000 > Date.now() + 15 * 60_000), 'TOKEN_LIFETIME_TOO_SHORT');
  return groups;
}

async function studentWork(request, group, student, barrier, signal) {
  const call = (name, body, validate, lag = 0, pacing = 0) => request(rpc(name), {
    method: 'POST', body, token: student.token, stage: 'load', operation: name,
    actor: student.actor, validate, lag, pacing,
  });
  const attempt = await call('start_exam', { p_quiz: group.quiz }, (s) =>
    check(UUID.test(s?.id) && s.student_id === student.id && s.quiz_id === group.quiz && s.status === 'in_progress', 'INVALID_START_RESPONSE'));
  student.attempt = attempt.id;
  const exam = await call('get_exam', { p_session: attempt.id }, (e) => {
    check(e?.session_id === attempt.id && Array.isArray(e.questions) && e.questions.length === 30, 'INVALID_EXAM_RESPONSE');
    check(new Set(e.questions.map((q) => q.id)).size === 30 && e.questions.every((q) => group.questions.some((f) => f.id === q.id && f.type === q.type)), 'INVALID_EXAM_QUESTIONS');
    check(e.questions.filter((q) => q.type === 'multiple_choice').every((q) =>
      Array.isArray(q.options) && q.options.length === 4 && new Set(q.options.map((o) => o.id)).size === 4
      && q.options.some((o) => o.id === group.questions.find((f) => f.id === q.id).correctOption)), 'INVALID_EXAM_OPTIONS');
    check(!/"(?:answer_keys|correct_option_id|correct_boolean|accepted_answers|is_correct|explanation)"\s*:/.test(JSON.stringify(e)), 'EXAM_PRIVACY_FAILURE');
  });
  const firstEvent = randomUUID();
  student.lastAnswers = new Map();
  student.successfulSaves = 0;
  let lastStart = -Infinity;
  for (let tick = 1; tick <= SAVE_COUNT; tick++) {
    const nominal = barrier + tick * INTERVAL + Math.random() * 2000 - 1000;
    const due = nextSaveAt(barrier, tick, nominal - barrier - tick * INTERVAL, lastStart);
    await sleep(Math.max(0, due - performance.now()), undefined, { signal });
    lastStart = performance.now();
    const q = group.questions.find((q) => q.id === exam.questions[(tick - 1) % 30].id);
    const answer = q.type === 'multiple_choice' ? { p_option: q.correctOption }
      : q.type === 'true_false' ? { p_bool: q.correctBoolean }
      : { p_text: q.type === 'identification' ? '  gReEn   lEaF  ' : `Synthetic essay revision ${tick}` };
    try {
      await call('save_answers', { p_session: attempt.id, p_answers: [{
        question_id: q.id, revision: tick,
        option_id: answer.p_option ?? null, bool_answer: answer.p_bool ?? null,
        text_answer: answer.p_text ?? null,
      }] },
        (receipts) => validateSaveReceipt(receipts, q.id, tick),
        lastStart - due, due - nominal);
      student.lastAnswers.set(q.id, answer);
      student.successfulSaves++;
    } catch { /* Keep every failed call; do not retry it or stop other students. */ }
    if ([15, 30, 45].includes(tick)) {
      const event = tick === 15 ? firstEvent : randomUUID();
      const body = { p_event: event, p_session: attempt.id, p_left_at: new Date().toISOString() };
      try { await call('log_leave', body); } catch { /* Recorded failure. */ }
      if (tick === 15) {
        try { await call('log_leave', body); } catch { /* Deliberate same-ID replay, not an error retry. */ }
      }
    }
  }
  await sleep(Math.max(0, barrier + DURATION - performance.now()), undefined, { signal });
  await call('submit_exam', { p_session: attempt.id }, (s) =>
    check(s?.status === 'submitted' && typeof s.submitted_at === 'string'
      && Object.keys(s).every((k) => ['status', 'submitted_at'].includes(k)), 'INVALID_SUBMIT_RESPONSE'));
  student.submitted = true;
}

async function verify(request, groups) {
  const failures = [];
  for (const group of groups) {
    const quizzes = await request(rest('quizzes', `select=locked_at,results_released_at,total_points,has_essay&id=eq.${group.quiz}`), {
      stage: 'verification', operation: 'read_quiz_state',
    });
    if (!(quizzes.length === 1 && quizzes[0].locked_at && quizzes[0].results_released_at === null
      && quizzes[0].total_points === 30 && quizzes[0].has_essay === true)) {
      failures.push({ check: 'QUIZ_LOCK_POINTS_OR_RESULT_RELEASE' });
    }
    const sessions = await request(rest('exam_sessions', `select=*&quiz_id=eq.${group.quiz}`), { stage: 'verification', operation: 'read_sessions' });
    check(Array.isArray(sessions), 'INVALID_VERIFICATION_RESPONSE');
    for (const student of group.students) {
      const attempts = sessions.filter((s) => s.student_id === student.id);
      if (attempts.length !== 1) { failures.push({ actor: student.actor, check: 'ATTEMPT_COUNT' }); continue; }
      const s = attempts[0];
      const answers = await request(rest('exam_answers', `select=*&session_id=eq.${s.id}&limit=100`), { stage: 'verification', operation: 'read_answers' });
      const leaves = await request(rest('leave_events', `select=id&session_id=eq.${s.id}&limit=100`), { stage: 'verification', operation: 'read_leaves' });
      const validAnswers = Array.isArray(answers) && answers.length === 30 && group.questions.every((q) => {
        const a = answers.find((a) => a.question_id === q.id);
        const sent = student.lastAnswers?.get(q.id);
        return a && sent && a.option_id === (sent.p_option ?? null) && a.bool_answer === (sent.p_bool ?? null)
          && a.text_answer === (sent.p_text ?? null)
          && (q.type === 'essay' ? a.points_awarded === null && a.is_correct === null
            : a.points_awarded === 1 && a.is_correct === true);
      });
      if (!(s.id === student.attempt && s.status === 'submitted' && s.attempt_no === 1 && s.submitted_at
        && student.submitted && student.successfulSaves === 60 && validAnswers
        && Array.isArray(leaves) && leaves.length === 3 && s.leave_count === 3
        && s.auto_score === 26 && s.essay_score === 0 && s.total_score === 26 && s.grading_complete === false)) {
        failures.push({ actor: student.actor, check: 'FINAL_STATE_OR_CALL_COUNT' });
      }
    }
  }
  return failures;
}

async function cleanup(request, manifest, dir) {
  manifest.cleanup = 'pending'; saveManifest(dir, manifest);
  // Recover a user created before a lost response or interrupted manifest write.
  const taggedUsers = [];
  for (let page = 1; ; page++) {
    const result = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`, {
      stage: 'cleanup', operation: 'find_tagged_users', ignoreStop: true,
    });
    check(Array.isArray(result?.users), 'INVALID_USER_LIST');
    taggedUsers.push(...result.users.filter((u) => u.app_metadata?.filo_exam_load_run === manifest.run_id));
    if (result.users.length < 1000) break;
  }
  const taggedIds = new Set(taggedUsers.map((u) => u.id));
  for (const id of manifest.users) {
    if (taggedIds.has(id)) continue;
    const result = await request(`/auth/v1/admin/users/${id}`, {
      stage: 'cleanup', operation: 'check_user_marker', ignoreStop: true, notFoundOk: true,
    });
    check(!result, 'USER_TAG_MISMATCH');
  }
  for (const fixture of manifest.classes) {
    const query = (table, filter) => request(rest(table, filter), { stage: 'cleanup', operation: `inspect_${table}`, ignoreStop: true });
    const classes = await query('classes', `select=id,owner_id,course&id=eq.${fixture.id}`);
    if (classes.length) {
      check(taggedIds.has(fixture.owner), 'OWNER_NOT_TAGGED');
      check(classes.length === 1 && classes[0].course === mark(manifest.run_id) && classes[0].owner_id === fixture.owner, 'CLASS_TAG_MISMATCH');
      const members = await query('class_members', `select=student_id&class_id=eq.${fixture.id}&limit=1000`);
      const quizzes = await query('quizzes', `select=id,author_id,title&class_id=eq.${fixture.id}&limit=1000`);
      const posts = await query('posts', `select=id&class_id=eq.${fixture.id}&limit=1`);
      check(members.length <= 40 && members.every((m) => fixture.students.includes(m.student_id))
        && quizzes.length <= 1 && quizzes.every((q) => q.id === fixture.quiz && q.author_id === fixture.owner && q.title === mark(manifest.run_id))
        && posts.length === 0, 'UNRELATED_CLASS_CONTENT');
      const questions = await query('questions', `select=id&quiz_id=eq.${fixture.quiz}&limit=1000`);
      const attempts = await query('exam_sessions', `select=student_id&quiz_id=eq.${fixture.quiz}&limit=1000`);
      const options = fixture.questions.length ? await query('question_options',
        `select=id&question_id=in.(${fixture.questions.join(',')})&limit=1000`) : [];
      check(questions.length <= 30 && questions.every((q) => fixture.questions.includes(q.id))
        && attempts.length <= 40 && attempts.every((s) => fixture.students.includes(s.student_id))
        && options.length <= 40 && options.every((o) => fixture.options.includes(o.id)), 'UNRELATED_QUIZ_CONTENT');
      await request(rest('classes', `id=eq.${fixture.id}`), { method: 'DELETE', stage: 'cleanup', operation: 'delete_class', ignoreStop: true });
    }
    check((await query('classes', `select=id&id=eq.${fixture.id}`)).length === 0
      && (await query('exam_sessions', `select=id&quiz_id=eq.${fixture.quiz}&limit=1`)).length === 0, 'CLASS_CLEANUP_INCOMPLETE');
  }
  // Auth tags are admin-set, and every deletion is scoped to an exact UUID.
  let removed = 0;
  for (const user of taggedUsers) {
    const profile = await request(rest('profiles', `select=id,display_name&id=eq.${user.id}`), { stage: 'cleanup', operation: 'inspect_profile', ignoreStop: true });
    check(profile.length === 0 || (profile.length === 1 && profile[0].display_name === mark(manifest.run_id)), 'PROFILE_TAG_MISMATCH');
    await request(rest('profiles', `id=eq.${user.id}`), { method: 'DELETE', stage: 'cleanup', operation: 'delete_profile', ignoreStop: true });
    await request(`/auth/v1/admin/users/${user.id}`, { method: 'DELETE', body: { should_soft_delete: false },
      stage: 'cleanup', operation: 'delete_auth_user', ignoreStop: true });
    const profileLeft = await request(rest('profiles', `select=id&id=eq.${user.id}`), { stage: 'cleanup', operation: 'verify_profile_removed', ignoreStop: true });
    check(profileLeft.length === 0, 'PROFILE_CLEANUP_INCOMPLETE');
    const authLeft = await request(`/auth/v1/admin/users/${user.id}`, {
      stage: 'cleanup', operation: 'verify_auth_removed', ignoreStop: true, notFoundOk: true,
    });
    check(authLeft === null, 'AUTH_CLEANUP_INCOMPLETE');
    const verifiedLeft = await request(rest('verified_sessions', `select=session_id&user_id=eq.${user.id}&limit=1`), {
      stage: 'cleanup', operation: 'verify_sessions_removed', ignoreStop: true,
    });
    check(verifiedLeft.length === 0, 'VERIFIED_SESSION_CLEANUP_INCOMPLETE');
    if (++removed % 10 === 0) console.log(`Cleanup: ${removed}/${taggedUsers.length} fixture users removed`);
  }
  manifest.cleanup = 'verified'; saveManifest(dir, manifest);
}

async function main() {
  check(Number(process.versions.node.split('.')[0]) >= 22, 'NODE_22_REQUIRED');
  const [command, argument, ...extra] = process.argv.slice(2);
  check(extra.length === 0 && ((command === 'run' && ['40', '120'].includes(argument))
    || (command === 'cleanup' && UUID.test(argument))), 'USAGE_run_40_OR_run_120_OR_cleanup_RUN_UUID');
  const keys = credentials(command === 'run');
  const runId = command === 'run' ? randomUUID() : argument;
  const dir = join(OUTPUT, runId);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const manifest = command === 'run' ? { version: 1, project: PROJECT, run_id: runId,
    students: Number(argument), created_at: new Date().toISOString(), users: [], classes: [], cleanup: 'pending' }
    : JSON.parse(readFileSync(join(dir, 'manifest.json'), 'utf8'));
  check(manifest.version === 1 && manifest.project === PROJECT && manifest.run_id === runId
    && [40, 120].includes(manifest.students) && Array.isArray(manifest.users) && manifest.users.every((id) => UUID.test(id))
    && Array.isArray(manifest.classes) && manifest.classes.every((c) => [c.id, c.quiz, c.owner, ...c.students, ...c.questions, ...c.options].every((id) => UUID.test(id))), 'INVALID_MANIFEST');
  saveManifest(dir, manifest);
  const controller = new AbortController(), rows = [];
  const onInterrupt = () => { console.log('Stopping workload; fixture cleanup will follow.'); controller.abort(); };
  process.on('SIGINT', onInterrupt); process.on('SIGTERM', onInterrupt);
  const request = api(keys, dir, controller, rows, manifest.students);
  console.log(`DEV ${PROJECT}; run ${runId}; local output ${dir}`);
  if (command === 'cleanup') {
    try {
      await cleanup(request, manifest, dir);
      const summaryFile = join(dir, 'summary.json');
      if (existsSync(summaryFile)) {
        const previous = JSON.parse(readFileSync(summaryFile, 'utf8'));
        previous.fixtures_removed = true; delete previous.cleanup_error;
        writeFileSync(summaryFile, JSON.stringify(previous, null, 2), { mode: 0o600 });
      }
      console.log('fixtures_removed=true');
    }
    finally { process.off('SIGINT', onInterrupt); process.off('SIGTERM', onInterrupt); }
    return;
  }
  const summary = {
    project: PROJECT, run_id: runId, students: manifest.students, classes: manifest.students / 40,
    environment: { node: process.version, platform: `${process.platform}/${process.arch}`, region_and_compute: 'OWNER_TO_RECORD' },
    measured_at: null, duration_ms: 0, expected_calls: manifest.students * 67,
    save_rpc: 'save_answers', answers_per_batch: 1,
    functional_complete: false, latency_target_pass: false, workload_on_time: false,
    verification_failures: [], dashboard: { baseline: null, during_load: null, availability: 'OWNER_OBSERVATION_PENDING' },
    limits_observed: 'Use recorded error codes/statuses and owner dashboard readings; no inference from published ceilings.',
  };
  let progress;
  try {
    const groups = await setup(request, manifest, dir, controller.signal);
    console.log('All accounts ready. START measured workload; capture dashboard metrics now.');
    summary.measured_at = new Date().toISOString();
    const barrier = performance.now();
    progress = setInterval(() => console.log(
      `Load ${Math.round((performance.now() - barrier) / 1000)}s: ${rows.length} calls, ${rows.filter((r) => !r.ok).length} failures`,
    ), 60_000);
    const outcomes = await Promise.allSettled(groups.flatMap((g) =>
      g.students.map((s) => studentWork(request, g, s, barrier, controller.signal))));
    clearInterval(progress);
    summary.duration_ms = performance.now() - barrier;
    summary.measured_finished_at = new Date().toISOString();
    summary.actor_failures = outcomes.filter((o) => o.status === 'rejected').length;
    if (!controller.signal.aborted) {
      console.log('Load complete; verifying stored attempts, answers, grading and leave counts.');
      summary.verification_failures = await verify(request, groups);
    }
    summary.functional_complete = !controller.signal.aborted && summary.actor_failures === 0
      && summary.verification_failures.length === 0 && rows.length === summary.expected_calls && rows.every((r) => r.ok);
  } catch (error) {
    summary.run_error = safeCode(error.code, 'SETUP_OR_VERIFICATION_ERROR');
    console.log(`Run stopped: ${summary.run_error}. See sanitized lifecycle.jsonl.`);
  } finally {
    clearInterval(progress);
    summary.overall = statistics(rows, summary.duration_ms);
    summary.by_rpc = Object.fromEntries([...new Set(rows.map((r) => r.rpc))].map((name) =>
      [name, statistics(rows.filter((r) => r.rpc === name), summary.duration_ms)]));
    summary.maximum_scheduling_lag_ms = Math.max(0, ...rows.map((r) => r.scheduling_lag_ms));
    summary.maximum_pacing_delay_ms = Math.max(0, ...rows.map((r) => r.pacing_delay_ms));
    summary.workload_on_time = rows.length === summary.expected_calls && summary.maximum_scheduling_lag_ms <= 1000;
    summary.latency_target_pass = rows.length === summary.expected_calls && rows.every((r) => r.ok && r.duration_ms < 1000);
    console.log('Cleaning run-tagged fixtures; keep this process open until cleanup finishes.');
    try { await cleanup(request, manifest, dir); summary.fixtures_removed = true; }
    catch (error) {
      summary.fixtures_removed = false; summary.cleanup_error = safeCode(error.code, 'CLEANUP_ERROR');
      console.log(`Cleanup pending: node tests/exam_load.mjs cleanup ${runId}`);
    }
    const lifecycle = existsSync(join(dir, 'lifecycle.jsonl'))
      ? readFileSync(join(dir, 'lifecycle.jsonl'), 'utf8').trim().split('\n').filter(Boolean).map((line) => JSON.parse(line)) : [];
    summary.phase_failures = Object.fromEntries(['setup', 'verification', 'cleanup'].map((stage) =>
      [stage, lifecycle.filter((r) => r.stage === stage && !r.ok).length]));
    writeFileSync(join(dir, 'summary.json'), JSON.stringify(summary, null, 2), { mode: 0o600 });
    process.off('SIGINT', onInterrupt); process.off('SIGTERM', onInterrupt);
    console.log(JSON.stringify(summary, null, 2));
    if (!summary.functional_complete || !summary.latency_target_pass || !summary.workload_on_time || !summary.fixtures_removed) process.exitCode = 1;
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => { console.error(safeCode(error.code, 'HARNESS_ERROR')); process.exitCode = 1; });
}
