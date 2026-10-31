// M11-BE-04: owner-run DEV measurement. Node 22+, no dependencies or automatic retries.
import { randomBytes, randomUUID } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, renameSync, appendFileSync } from 'node:fs';
import { resolve, relative, dirname, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { setTimeout as sleep } from 'node:timers/promises';

export const PROJECT = 'fiobwfzmqcffbpixzvbq';
const BASE = `https://${PROJECT}.supabase.co`;
const UUID = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const APP = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const SCENARIO_MS = 390000, CLEANUP_MS = 600000, SETUP_MS = 600000;
const check = (ok, code) => { if (!ok) throw Object.assign(new Error(code), { code }); };
const code = (e) => /^[A-Z][A-Z0-9_]{0,79}$/.test(e?.code ?? '') ? e.code : 'TRANSPORT_OR_PROTOCOL_ERROR';
const label = (v) => typeof v === 'string' && /^[A-Za-z0-9_.:/@+ -]{1,200}$/.test(v);
const mark = (id) => `M11 quota ${id}`;

export function schedule(students) {
  check([10, 20, 40].includes(students), 'INVALID_CLASS_SIZE');
  return Array.from({ length: 15 }, (_, tick) => Array.from({ length: students }, (_, student) =>
    ({ student, tick, at_ms: tick * 20000 + student * 20000 / students }))).flat();
}

export function validateConfig(c, now = Date.now()) {
  check(c?.project === PROJECT, 'DEV_PROJECT_REQUIRED');
  check(c.analyst_retained === true && label(c.analyst_evidence), 'ANALYST_CONFIRMATION_REQUIRED');
  check(c.timezone === 'Asia/Manila' && c.off_peak_confirmed === true, 'OWNER_OFF_PEAK_REQUIRED');
  check([c.window_start, c.window_end].every((s) => typeof s === 'string' && s.endsWith('+08:00') && Number.isFinite(Date.parse(s))), 'MANILA_WINDOW_REQUIRED');
  check(now >= Date.parse(c.window_start) && now + SETUP_MS + 3 * SCENARIO_MS + CLEANUP_MS <= Date.parse(c.window_end), 'INSUFFICIENT_OFF_PEAK_WINDOW');
  check(label(c.revision) && label(c.model) && label(c.tier) && label(c.quota_evidence), 'DEPLOYMENT_AND_QUOTA_EVIDENCE_REQUIRED');
  check(c.configuration_checked === true && c.test_mode === 'off', 'LIVE_CONFIGURATION_CONFIRMATION_REQUIRED');
  check(Number.isFinite(Date.parse(c.quota_checked_at)) && now - Date.parse(c.quota_checked_at) >= 0 && now - Date.parse(c.quota_checked_at) <= 300000, 'FRESH_QUOTA_SNAPSHOT_REQUIRED');
  check(['rpm', 'tpm', 'rpd', 'baseline_requests_today', 'remaining_requests_today'].every((key) => Number.isFinite(c[key]) && c[key] >= 0), 'NUMERIC_QUOTA_REQUIRED');
  check(c.rpm > 0 && c.tpm > 0 && c.rpd > 0 && c.remaining_requests_today >= 1050, 'INSUFFICIENT_DAILY_QUOTA');
  check(c.remaining_requests_today + c.baseline_requests_today <= c.rpd, 'INCONSISTENT_QUOTA_SNAPSHOT');
  // Copy only the documented metadata, never arbitrary config fields into evidence.
  return Object.fromEntries(['project', 'analyst_retained', 'analyst_evidence', 'timezone', 'off_peak_confirmed', 'window_start', 'window_end', 'revision', 'model', 'tier', 'quota_evidence', 'configuration_checked', 'test_mode', 'quota_checked_at', 'rpm', 'tpm', 'rpd', 'baseline_requests_today', 'remaining_requests_today'].map((key) => [key, c[key]]));
}

export function statistics(students, rows) {
  const attempted = rows.filter((r) => r.attempted), completed = attempted.filter((r) => r.http_status !== null);
  const durations = attempted.map((r) => r.duration_ms);
  const categories = {}, http = {};
  for (const r of attempted) {
    categories[r.outcome] = (categories[r.outcome] ?? 0) + 1;
    if (r.http_status !== null) http[r.http_status] = (http[r.http_status] ?? 0) + 1;
  }
  const first = completed.filter((r) => r.http_status >= 400).sort((a, b) => a.finished_ms - b.finished_ms)[0];
  return { students, scheduled: students * 15, attempted: attempted.length, completed: completed.length,
    skipped: rows.filter((r) => !r.attempted).length, categories, http,
    average_ms: durations.length ? durations.reduce((a, b) => a + b, 0) / durations.length : null,
    slowest_ms: durations.length ? Math.max(...durations) : null,
    delayed: attempted.filter((r) => r.late_ms > 1000).length,
    first_refusal: first ? { elapsed_ms: first.finished_ms, outcome: first.outcome, http_status: first.http_status, requests_started: attempted.filter((r) => r.started_ms <= first.finished_ms).length, target_rpm: students * 3 } : null };
}

export function ownsFixture(user, runId) {
  return UUID.test(user?.id ?? '') && user.app_metadata?.filo_ai_quota_run === runId &&
    typeof user.email === 'string' && user.email.startsWith(`m11.${runId}.`) && user.email.endsWith('@example.invalid');
}

function outsideApp(path) {
  const target = resolve(path), rel = relative(APP, target);
  check(rel !== '' && (rel === '..' || rel.startsWith(`..${sep}`) || resolve(APP, rel) !== target), 'OUTPUT_MUST_BE_OUTSIDE_APP');
  return target;
}

export async function run(command, configPath, outputPath, { fetcher = fetch, env = process.env } = {}) {
  check(['run', 'cleanup'].includes(command), 'USE_RUN_OR_CLEANUP');
  check(Number(process.versions.node.split('.')[0]) >= 22, 'NODE_22_REQUIRED');
  const dir = outsideApp(outputPath);
  const service = env.FILO_LOAD_SERVICE_ROLE_KEY, anon = env.FILO_LOAD_ANON_KEY;
  let claims;
  try { claims = JSON.parse(Buffer.from(service.split('.')[1], 'base64url')); } catch { check(false, 'DEV_SERVICE_JWT_REQUIRED'); }
  check(claims.ref === PROJECT && claims.role === 'service_role', 'DEV_SERVICE_JWT_REQUIRED');
  check(typeof anon === 'string' && anon.length > 10, 'PUBLIC_KEY_REQUIRED');
  if (!anon.startsWith('sb_publishable_')) {
    let publicClaims;
    try { publicClaims = JSON.parse(Buffer.from(anon.split('.')[1], 'base64url')); } catch { check(false, 'DEV_PUBLIC_KEY_REQUIRED'); }
    check(publicClaims.ref === PROJECT && publicClaims.role === 'anon', 'DEV_PUBLIC_KEY_REQUIRED');
  }
  const config = command === 'run' ? validateConfig(JSON.parse(readFileSync(configPath, 'utf8'))) : null;
  let manifest;
  if (command === 'run') {
    mkdirSync(dir, { recursive: false, mode: 0o700 }); // Existing run directories cannot launch a second workload.
    manifest = { run_id: randomUUID(), project: PROJECT, users: [], config, scenarios: [], gaps: [], cleanup: 'pending', started_at: new Date().toISOString() };
  } else {
    manifest = JSON.parse(readFileSync(resolve(dir, 'manifest.json'), 'utf8'));
    check(manifest.project === PROJECT && UUID.test(manifest.run_id) && Array.isArray(manifest.users) && manifest.users.every((id) => UUID.test(id)), 'INVALID_MANIFEST');
  }
  const save = () => {
    writeFileSync(resolve(dir, 'manifest.tmp'), JSON.stringify(manifest, null, 2), { mode: 0o600 });
    renameSync(resolve(dir, 'manifest.tmp'), resolve(dir, 'manifest.json'));
  };
  save();
  const controller = new AbortController();
  const active = new Set();
  const interrupt = () => controller.abort();
  process.once('SIGINT', interrupt); process.once('SIGTERM', interrupt);
  async function request(path, { method = 'GET', body, token = service, publicKey = false } = {}) {
    const response = await fetcher(`${BASE}${path}`, { method, redirect: 'error', signal: AbortSignal.timeout(30000),
      headers: { apikey: publicKey ? anon : service, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body) });
    const value = await response.json().catch(() => null);
    check(response.ok, 'FIXTURE_REQUEST_FAILED');
    return value;
  }
  async function discover() {
    const owned = [];
    for (let page = 1; ; page++) {
      const value = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`);
      check(Array.isArray(value?.users), 'INVALID_USER_LIST');
      owned.push(...value.users.filter((user) => ownsFixture(user, manifest.run_id)));
      if (value.users.length < 1000) break;
    }
    return owned;
  }
  async function cleanup() {
    // Discovery recovers a user created successfully when the creation response was lost.
    const users = await discover();
    for (const id of manifest.users) {
      if (users.some((u) => u.id === id)) continue;
      const response = await fetcher(`${BASE}/auth/v1/admin/users/${id}`, { headers: { apikey: service, Authorization: `Bearer ${service}` }, redirect: 'error', signal: AbortSignal.timeout(30000) });
      check(response.status === 404, 'CLEANUP_OWNERSHIP_MISMATCH');
    }
    for (const user of users) {
      check(ownsFixture(user, manifest.run_id), 'CLEANUP_OWNERSHIP_MISMATCH');
      const profile = await request(`/rest/v1/profiles?id=eq.${user.id}&select=id,display_name`);
      check(Array.isArray(profile) && profile.every((p) => p.id === user.id && p.display_name === mark(manifest.run_id)), 'PROFILE_OWNERSHIP_MISMATCH');
      await request(`/rest/v1/profiles?id=eq.${user.id}`, { method: 'DELETE' });
      await request(`/auth/v1/admin/users/${user.id}`, { method: 'DELETE', body: { should_soft_delete: false } });
    }
    check((await discover()).length === 0, 'USERS_REMAIN_AFTER_CLEANUP');
    for (const id of new Set([...manifest.users, ...users.map((u) => u.id)])) {
      for (const table of ['profiles', 'verified_sessions']) {
        const key = table === 'profiles' ? 'id' : 'user_id';
        const rows = await request(`/rest/v1/${table}?${key}=eq.${id}&select=${key}&limit=1`);
        check(Array.isArray(rows) && rows.length === 0, 'FIXTURES_REMAIN_AFTER_CLEANUP');
      }
    }
    manifest.cleanup = 'verified';
  }
  function windowBudget(ms) {
    check(!controller.signal.aborted, 'INTERRUPTED');
    check(Date.now() + ms <= Date.parse(config.window_end), 'OFF_PEAK_BUDGET_EXHAUSTED');
  }
  async function modeProbe() {
    const response = await fetcher(`${BASE}/functions/v1/ai-chat`, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(30000),
      headers: { apikey: anon, 'Content-Type': 'application/json' }, body: '{}' });
    const body = await response.json().catch(() => null);
    check(response.status === 403 && body?.error?.code === 'NOT_ALLOWED' && response.headers.get('x-filo-ai-test-mode') === 'off', 'DEV_TRACE_ON_AND_TEST_MODE_OFF_REQUIRED');
  }
  try {
    if (command === 'run') {
      await modeProbe(); // Denied caller: no slot and no Gemini call.
      const actors = [], setupDeadline = Date.now() + SETUP_MS;
      for (let i = 0; i < 40; i++) {
        windowBudget(3 * SCENARIO_MS + CLEANUP_MS);
        check(Date.now() < setupDeadline, 'SETUP_BUDGET_EXHAUSTED');
        const email = `m11.${manifest.run_id}.${i}@example.invalid`, password = `Filo-${randomBytes(24).toString('hex')}aA1!`;
        const created = await request('/auth/v1/admin/users', { method: 'POST', body: { email, password, email_confirm: true, app_metadata: { filo_ai_quota_run: manifest.run_id } } });
        check(ownsFixture(created, manifest.run_id), 'INVALID_CREATED_USER');
        manifest.users.push(created.id); save();
        await request('/rest/v1/profiles', { method: 'POST', body: { id: created.id, role: 'student', display_name: mark(manifest.run_id) } });
        const session = await request('/auth/v1/token?grant_type=password', { method: 'POST', publicKey: true, body: { email, password } });
        const jwt = JSON.parse(Buffer.from(session.access_token.split('.')[1], 'base64url'));
        check(jwt.sub === created.id && UUID.test(jwt.session_id) && jwt.role === 'authenticated' && jwt.exp * 1000 > Date.now() + 3 * SCENARIO_MS + CLEANUP_MS, 'INVALID_OR_SHORT_SESSION');
        await request('/rest/v1/verified_sessions', { method: 'POST', body: { user_id: created.id, session_id: jwt.session_id } });
        actors.push(session.access_token);
        await sleep(2100, undefined, { signal: controller.signal });
      }
      for (const [index, students] of [10, 20, 40].entries()) {
        windowBudget((3 - index) * SCENARIO_MS + CLEANUP_MS);
        await modeProbe();
        const start = Date.now(), rows = [], pending = [];
        const record = (row) => { rows.push(row); appendFileSync(resolve(dir, 'requests.jsonl'), `${JSON.stringify({ students, ...row })}\n`, { mode: 0o600 }); };
        for (const item of schedule(students)) {
          const wait = start + item.at_ms - Date.now();
          if (wait > 0 && !controller.signal.aborted) await sleep(wait, undefined, { signal: controller.signal }).catch(() => {});
          const late = Date.now() - start - item.at_ms;
          if (controller.signal.aborted || Date.now() + 90000 + CLEANUP_MS > Date.parse(config.window_end) || late > 1000) {
            record({ ...item, attempted: false, outcome: controller.signal.aborted ? 'INTERRUPTED' : late > 1000 ? 'MISSED_SCHEDULE' : 'OFF_PEAK_BUDGET_EXHAUSTED' });
            continue;
          }
          const call = (async () => {
            const requestId = randomUUID(), started = Date.now();
            let status = null, outcome = 'CLIENT_TIMEOUT', logId = null;
            try {
              const response = await fetcher(`${BASE}/functions/v1/ai-chat`, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(90000),
                headers: { apikey: anon, Authorization: `Bearer ${actors[item.student]}`, 'Content-Type': 'application/json', 'x-filo-ai-test-id': requestId },
                body: JSON.stringify({ mode: 'chat', messages: [{ role: 'user', content: 'Explain photosynthesis in two short sentences.' }], sources: [{ name: 'synthetic.txt', text: 'Plants use sunlight to turn carbon dioxide and water into sugars, releasing oxygen. This process is photosynthesis.' }] }) });
              status = response.status;
              const body = await response.json().catch(() => null);
              logId = response.headers.get('x-filo-ai-log-id');
              if (!UUID.test(logId ?? '')) logId = null;
              outcome = response.ok && typeof body?.answer === 'string' && body.answer.trim() && Array.from(body.answer).length <= 4000 ? 'SUCCESS' : code(body?.error);
              if (response.headers.get('x-filo-ai-test-mode') !== 'off') { outcome = 'TEST_MODE_NOT_OFF'; controller.abort(); }
            } catch (error) { outcome = error?.name === 'TimeoutError' ? 'CLIENT_TIMEOUT' : 'TRANSPORT_ERROR'; }
            record({ ...item, request_id: requestId, log_id: logId, attempted: true, started_ms: started - start, finished_ms: Date.now() - start,
              late_ms: started - start - item.at_ms, duration_ms: Date.now() - started, http_status: status, outcome });
          })().catch(() => { controller.abort(); manifest.gaps.push('RESULT_WRITE_FAILED'); });
          active.add(call);
          call.finally(() => active.delete(call));
          pending.push(call);
        }
        await Promise.all(pending);
        const result = statistics(students, rows);
        manifest.scenarios.push({ ...result, started_at: new Date(start).toISOString(), cumulative_attempts: manifest.scenarios.reduce((n, s) => n + s.attempted, 0) + result.attempted });
        save();
        if (controller.signal.aborted) break;
      }
      manifest.gaps.push('Provider quota attribution and post-run AI Studio usage require owner review; AI_BUSY is not proof of quota exhaustion.', 'Measured recommendation and explicit owner acceptance pending.');
      if (manifest.scenarios.length !== 3 || manifest.scenarios.some((s) => s.attempted !== s.scheduled || s.completed !== s.attempted || s.delayed)) manifest.gaps.push('Interrupted, delayed, skipped or incomplete workload; do not infer full class capacity.');
    }
  } catch (error) { manifest.gaps.push(code(error)); }
  finally {
    await Promise.allSettled([...active]);
    try { await cleanup(); } catch (error) { manifest.cleanup = 'incomplete'; manifest.gaps.push(code(error)); }
    if (config && Date.now() > Date.parse(config.window_end)) manifest.gaps.push('OFF_PEAK_WINDOW_EXCEEDED_DURING_DRAIN_OR_CLEANUP');
    manifest.finished_at = new Date().toISOString(); save();
    process.removeListener('SIGINT', interrupt); process.removeListener('SIGTERM', interrupt);
  }
  const table = ['| Students | Scheduled | Attempted | Completed | Success | AI_BUSY | AI_TIMEOUT | AI_IN_PROGRESS | Average ms | Slowest ms | First refusal ms |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |',
    ...manifest.scenarios.map((s) => `| ${s.students} | ${s.scheduled} | ${s.attempted} | ${s.completed} | ${s.categories.SUCCESS ?? 0} | ${s.categories.AI_BUSY ?? 0} | ${s.categories.AI_TIMEOUT ?? 0} | ${s.categories.AI_IN_PROGRESS ?? 0} | ${s.average_ms?.toFixed(1) ?? '-'} | ${s.slowest_ms ?? '-'} | ${s.first_refusal?.elapsed_ms ?? '-'} |`)];
  writeFileSync(resolve(dir, 'results.md'), `${table.join('\n')}\n\nCleanup: ${manifest.cleanup}.\nRecommendation pending owner quota evidence review.\n`, { mode: 0o600 });
  return manifest;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  run(process.argv[2], process.argv[3], process.argv[4]).then((manifest) => {
    console.log(JSON.stringify({ run_id: manifest.run_id, scenarios: manifest.scenarios.length, cleanup: manifest.cleanup, review: 'pending' }));
    process.exitCode = manifest.cleanup === 'verified' && manifest.scenarios.length === 3 && manifest.scenarios.every((s) => s.attempted === s.scheduled && s.completed === s.attempted) ? 0 : 2;
  }).catch((error) => { console.error(code(error)); process.exitCode = 2; });
}
