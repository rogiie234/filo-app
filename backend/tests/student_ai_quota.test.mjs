import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { PROJECT, schedule, statistics, validateConfig, ownsFixture, run } from './student_ai_quota.mjs';
import { writeFileSync } from 'node:fs';

const now = Date.parse('2026-10-31T20:00:00+08:00');
const config = () => ({ project: PROJECT, analyst_retained: true, analyst_evidence: 'SA-01 owner confirmation', timezone: 'Asia/Manila', off_peak_confirmed: true,
  window_start: '2026-10-31T19:59:00+08:00', window_end: '2026-10-31T21:00:00+08:00', revision: 'revision-123', model: 'recorded-model', tier: 'Free', quota_evidence: 'AI Studio snapshot 1',
  configuration_checked: true, test_mode: 'off', quota_checked_at: new Date(now).toISOString(), rpm: 10, tpm: 10000, rpd: 2000, baseline_requests_today: 0, remaining_requests_today: 2000 });

test('fixed schedules have 15 calls per student with 20-second cadence and spread starts', () => {
  let total = 0;
  for (const size of [10, 20, 40]) {
    const rows = schedule(size); total += rows.length;
    assert.equal(rows.length, size * 15);
    assert.equal(rows.at(-1).at_ms < 300000, true);
    for (let student = 0; student < size; student++) {
      const calls = rows.filter((r) => r.student === student);
      assert.equal(calls.length, 15);
      assert.equal(calls[1].at_ms - calls[0].at_ms, 20000);
    }
    assert.equal(rows[1].at_ms, 20000 / size);
  }
  assert.equal(total, 1050);
  assert.throws(() => schedule(30), /INVALID_CLASS_SIZE/);
});

test('DEV, analyst, fresh quota, switch and Manila time gates fail closed', () => {
  assert.equal(validateConfig(config(), now).project, PROJECT);
  for (const patch of [{ project: 'production' }, { analyst_retained: false }, { off_peak_confirmed: false }, { test_mode: 'sample' },
    { window_end: '2026-10-31T20:30:00+08:00' }, { quota_checked_at: '2026-10-30T20:00:00+08:00' }, { remaining_requests_today: 1049 }, { rpm: null }]) {
    assert.throws(() => validateConfig({ ...config(), ...patch }, now));
  }
  assert.throws(() => validateConfig(config(), now - 120000));
});

test('statistics retain failures, skipped calls, HTTP counts and first observed refusal', () => {
  const rows = [
    { attempted: true, outcome: 'SUCCESS', http_status: 200, started_ms: 0, finished_ms: 100, duration_ms: 100, late_ms: 0 },
    { attempted: true, outcome: 'AI_BUSY', http_status: 503, started_ms: 10, finished_ms: 200, duration_ms: 190, late_ms: 2 },
    { attempted: true, outcome: 'CLIENT_TIMEOUT', http_status: null, started_ms: 20, finished_ms: 90020, duration_ms: 90000, late_ms: 1500 },
    { attempted: false, outcome: 'MISSED_SCHEDULE' },
  ];
  const s = statistics(10, rows);
  assert.equal(s.scheduled, 150); assert.equal(s.attempted, 3); assert.equal(s.completed, 2); assert.equal(s.skipped, 1);
  assert.equal(s.categories.AI_BUSY, 1); assert.equal(s.slowest_ms, 90000); assert.equal(s.average_ms, 90290 / 3);
  assert.equal(s.first_refusal.requests_started, 3); assert.equal(s.first_refusal.target_rpm, 30);
  assert.equal(statistics(10, []).average_ms, null);
});

test('only fully tagged synthetic accounts belong to this run; config extras are not saved', () => {
  const runId = randomUUID(), user = { id: randomUUID(), email: `m11.${runId}.1@example.invalid`, app_metadata: { filo_ai_quota_run: runId } };
  assert.equal(ownsFixture(user, runId), true);
  assert.equal(ownsFixture(user, randomUUID()), false);
  assert.equal(ownsFixture({ ...user, email: 'real@example.com' }, runId), false);
  assert.equal(ownsFixture({ ...user, app_metadata: {} }, runId), false);
  assert.equal(JSON.stringify(validateConfig({ ...config(), token: 'PRIVATE_SENTINEL' }, now)).includes('PRIVATE_SENTINEL'), false);
});

test('failed switch probe still cleans up and never starts a provider workload or stores bodies', async () => {
  const root = mkdtempSync(join(tmpdir(), 'filo-quota-')), path = join(root, 'config.json'), output = join(root, 'run');
  const current = Date.now();
  const manila = (ms) => new Date(ms + 8 * 3600000).toISOString().replace('Z', '+08:00');
  writeFileSync(path, JSON.stringify({ ...config(), window_start: manila(current - 1000), window_end: manila(current + 3600000), quota_checked_at: new Date(current).toISOString() }));
  const jwt = (value) => `header.${Buffer.from(JSON.stringify(value)).toString('base64url')}.signature`;
  const calls = [];
  try {
    const manifest = await run('run', path, output, { env: { FILO_LOAD_SERVICE_ROLE_KEY: jwt({ ref: PROJECT, role: 'service_role' }), FILO_LOAD_ANON_KEY: jwt({ ref: PROJECT, role: 'anon' }) },
      fetcher: async (url, options) => {
        calls.push({ url, method: options.method ?? 'GET' });
        if (url.includes('/functions/')) return new Response(JSON.stringify({ error: { code: 'NOT_ALLOWED', message: 'PRIVATE_SENTINEL' } }), { status: 403, headers: { 'x-filo-ai-test-mode': 'sample' } });
        assert.equal(url.includes('/auth/v1/admin/users?'), true);
        return Response.json({ users: [] });
      } });
    assert.equal(manifest.cleanup, 'verified'); assert.equal(manifest.scenarios.length, 0);
    assert.equal(manifest.gaps.includes('DEV_TRACE_ON_AND_TEST_MODE_OFF_REQUIRED'), true);
    assert.equal(calls.filter((c) => c.url.includes('/functions/')).length, 1);
    assert.equal(calls.some((c) => c.url.includes('/token')), false);
    assert.equal(readFileSync(join(output, 'manifest.json'), 'utf8').includes('PRIVATE_SENTINEL'), false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('recovery refuses deletion when a manifest user is no longer owned by the run', async () => {
  const root = mkdtempSync(join(tmpdir(), 'filo-quota-')), runId = randomUUID(), userId = randomUUID();
  writeFileSync(join(root, 'manifest.json'), JSON.stringify({ project: PROJECT, run_id: runId, users: [userId], scenarios: [], gaps: [], cleanup: 'pending' }));
  const jwt = `header.${Buffer.from(JSON.stringify({ ref: PROJECT, role: 'service_role' })).toString('base64url')}.signature`;
  const methods = [];
  try {
    const result = await run('cleanup', '-', root, { env: { FILO_LOAD_SERVICE_ROLE_KEY: jwt, FILO_LOAD_ANON_KEY: 'sb_publishable_mock_public' },
      fetcher: async (url, options) => {
        methods.push(options.method ?? 'GET');
        assert.equal(url.includes('/functions/'), false);
        return url.includes('?') ? Response.json({ users: [] }) : Response.json({ id: userId, email: 'unrelated@example.invalid' });
      } });
    assert.equal(result.cleanup, 'incomplete');
    assert.equal(result.gaps.includes('CLEANUP_OWNERSHIP_MISMATCH'), true);
    assert.equal(methods.includes('DELETE'), false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
