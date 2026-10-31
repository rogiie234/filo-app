import test from 'node:test';
import assert from 'node:assert/strict';
import { claims, parseEvent, verifyEvents, terminalRow, run, PROJECT } from './student_ai_security.mjs';

const id = '11111111-1111-4111-8111-111111111111';
const logId = '22222222-2222-4222-8222-222222222222';
const request = { id, endpoint: 'ai-chat', kind: 'chat', logId, error: null, provider: 'real' };
const event = (name, values = {}) => ({ tag: 'filo_ai_dev_v1', request_id: id, endpoint: 'ai-chat', event: name,
  log_id: ['acquired', 'complete'].includes(name) ? logId : null, error: null, ...values });

test('log evidence requires start, finish, acquisition and an observed positive provider control', () => {
  const events = ['request', 'acquired', 'provider_attempt', 'provider_settled', 'complete'].map((name) => event(name));
  assert.equal(verifyEvents([request], events), true);
  assert.equal(verifyEvents([request], []), false);
  assert.equal(verifyEvents([request], events.filter((row) => row.event !== 'provider_attempt')), false);
  assert.equal(verifyEvents([request], events.filter((row) => row.event !== 'complete')), false);
  const refusal = { ...request, logId: null, error: 'NOT_ALLOWED', provider: 'none' };
  const denied = [event('request'), event('complete', { log_id: null, error: 'NOT_ALLOWED' })];
  assert.equal(verifyEvents([refusal], denied), true);
  assert.throws(() => verifyEvents([refusal], [...denied, event('provider_attempt')]), { code: 'REFUSED_OR_SIMULATED_PROVIDER_CALL' });
});

test('trace parser rejects extra content and treats unrelated runtime lines as unrelated', () => {
  assert.deepEqual(parseEvent(JSON.stringify(event('request'))), event('request'));
  assert.equal(parseEvent('worker booted'), null);
  assert.equal(parseEvent('{"tag":"other"}'), null);
  assert.throws(() => parseEvent(JSON.stringify({ ...event('request'), answer: 'private' })), { code: 'UNSAFE_TRACE_SHAPE' });
});

test('terminal rows require matching identity, kind, outcome and timestamps', () => {
  const row = { id: logId, user_id: id, kind: 'chat', status: 'success', error_code: null,
    created_at: '2026-10-31T00:00:00Z', finished_at: '2026-10-31T00:00:01Z' };
  terminalRow(row, request, id);
  for (const patch of [{ status: 'started' }, { finished_at: null }, { error_code: 'AI_BUSY' }, { kind: 'flashcards' }, { content: 'private' }]) {
    assert.throws(() => terminalRow({ ...row, ...patch }, request, id), { code: 'INVALID_TERMINAL_LEDGER_ROW' });
  }
});

test('token claims reject foreign projects, missing sessions and insufficient lifetime', () => {
  const value = { sub: id, session_id: logId, role: 'authenticated', iss: `https://${PROJECT}.supabase.co/auth/v1`, exp: Date.now() / 1000 + 3600 };
  const token = (claims) => `header.${Buffer.from(JSON.stringify(claims)).toString('base64url')}.signature`;
  assert.equal(claims(token(value)).sub, id);
  for (const patch of [{ iss: 'https://production.invalid/auth/v1' }, { session_id: null }, { exp: 0 }, { role: 'service_role' }]) {
    assert.throws(() => claims(token({ ...value, ...patch })), { code: 'FRESH_DEV_SESSION_REQUIRED' });
  }
});

test('runner refuses missing or foreign explicit project before making any request', async () => {
  const forbidden = () => { throw new Error('Must not make a network request'); };
  await assert.rejects(run({}, forbidden), { code: 'EXPLICIT_DEV_PROJECT_REQUIRED' });
  await assert.rejects(run({ FILO_AI_PROJECT_REF: 'production' }, forbidden), { code: 'EXPLICIT_DEV_PROJECT_REQUIRED' });
});

test('a transport failure after enabling switches still restores both switches', async () => {
  const names = ['STUDENT_A', 'STUDENT_B', 'UNVERIFIED', 'INSTRUCTOR'];
  const identities = names.map((name, index) => ({ name, sub: `${index + 1}1111111-1111-4111-8111-111111111111`,
    session_id: `${index + 1}2222222-2222-4222-8222-222222222222`, role: 'authenticated',
    iss: `https://${PROJECT}.supabase.co/auth/v1`, exp: Date.now() / 1000 + 3600 }));
  const tokens = identities.map((value) => `header.${Buffer.from(JSON.stringify(value)).toString('base64url')}.signature`);
  const env = { FILO_AI_PROJECT_REF: PROJECT, SUPABASE_ACCESS_TOKEN: 'fake-management',
    FILO_AI_SERVICE_ROLE_KEY: 'sb_secret_fake', FILO_AI_ANON_KEY: 'fake-public',
    ...Object.fromEntries(names.map((name, index) => [`FILO_AI_${name}_TOKEN`, tokens[index]])) };
  const writes = [];
  const fakeFetch = async (url, init) => {
    const path = new URL(url).pathname, headers = new Headers(init.headers);
    if (String(url).startsWith('https://api.supabase.com/')) {
      if (path.endsWith('/secrets')) writes.push(JSON.parse(init.body));
      return Response.json({ id: PROJECT });
    }
    if (path === '/auth/v1/user') return Response.json({ id: identities[tokens.indexOf(headers.get('Authorization').slice(7))].sub });
    if (path === '/rest/v1/profiles') {
      const instructor = new URL(url).searchParams.get('id') === `eq.${identities[3].sub}`;
      return Response.json([{ role: instructor ? 'instructor' : 'student', deleted_at: null }]);
    }
    if (path === '/rest/v1/verified_sessions') {
      return Response.json(new URL(url).searchParams.get('session_id') === `eq.${identities[2].session_id}` ? [] : [{ session_id: logId }]);
    }
    if (path === '/rest/v1/ai_usage_log') return Response.json([]);
    if (path.startsWith('/functions/v1/')) {
      if (headers.has('Authorization')) throw new Error('private transport failure');
      return Response.json({ error: { code: 'NOT_ALLOWED' } }, { status: 403, headers: {
        'x-filo-ai-test-id': headers.get('x-filo-ai-test-id') ?? id, 'x-filo-ai-test-mode': 'off',
      } });
    }
    throw new Error('Unexpected mock path');
  };
  const report = await run(env, fakeFetch);
  assert.equal(report.overall, 'failed'); assert.equal(report.cleanup, 'complete');
  assert.deepEqual(writes.at(-1), [{ name: 'AI_TEST_MODE', value: 'off' }, { name: 'AI_DEV_TRACE', value: 'off' }]);
  assert.ok(!JSON.stringify(report).includes('private transport failure'));
  assert.ok(!JSON.stringify(report).includes(tokens[0]));
});
