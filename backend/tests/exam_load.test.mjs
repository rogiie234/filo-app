// Owner-run calculation/scheduling self-check; never creates network fixtures.
import assert from 'node:assert/strict';
import { buildQuizFixture, nextSaveAt, statistics } from './exam_load.mjs';

const fixture = buildQuizFixture('00000000-0000-4000-8000-000000000001');
assert.equal(fixture.questions.length, 30);
assert.equal(fixture.options.length, 40);
assert.equal(fixture.keys.length, 26);
const fields = ['accepted_answers', 'correct_boolean', 'correct_option_id', 'question_id'];
for (const key of JSON.parse(JSON.stringify(fixture.keys))) {
  assert.deepEqual(Object.keys(key).sort(), fields);
  assert.equal([key.correct_option_id, key.correct_boolean, key.accepted_answers]
    .filter((value) => value !== null).length, 1);
}
assert.equal(fixture.keys.filter((k) => k.correct_option_id !== null).length, 10);
assert.equal(fixture.keys.filter((k) => k.correct_boolean !== null).length, 8);
assert.equal(fixture.keys.filter((k) => k.correct_boolean === false).length, 4);
assert.equal(fixture.keys.filter((k) => k.accepted_answers !== null).length, 8);

const rows = [100, 200, 300, 1000].map((ms, i) => ({
  duration_ms: ms, ok: i !== 3, error_code: i === 3 ? 'HTTP_429' : null,
}));
assert.deepEqual(statistics(rows, 10_000), {
  count: 4, average_ms: 400, p95_ms: 1000, slowest_ms: 1000,
  at_or_over_1s: 1,
  failures: 1, requests_per_second: 0.4, errors: { HTTP_429: 1 },
});
assert.equal(statistics([], 0).p95_ms, null);
assert.equal(statistics([], 0).requests_per_second, 0);
assert.equal(nextSaveAt(0, 1, -1000), 9000);
assert.equal(nextSaveAt(0, 60, 1000), 601000);
assert.equal(nextSaveAt(0, 2, 0, 19000), 28000);
assert.throws(() => nextSaveAt(0, 61, 0), /INVALID_TICK/);
assert.throws(() => nextSaveAt(0, 1, 1001), /INVALID_JITTER/);
console.log('PASS: mixed fixture bulk keys, summary calculations and scheduling boundaries');
