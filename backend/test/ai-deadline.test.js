const test = require('node:test');
const assert = require('node:assert/strict');
const { withAiDeadline, AI_TIMEOUT_MESSAGE } = require('../dist/ai/ai-deadline.utils');

test('returns completed work and propagates errors', async () => {
  assert.equal(await withAiDeadline(async () => 'answer', 100), 'answer');
  await assert.rejects(withAiDeadline(async () => { throw new Error('failed'); }, 100), /failed/);
});

test('hung upstream work has a bounded deadline', async () => {
  await assert.rejects(withAiDeadline(() => new Promise(() => {}), 15),
    { message: AI_TIMEOUT_MESSAGE });
});

test('expired work cannot start another provider attempt', async () => {
  let remaining;
  await assert.rejects(withAiDeadline(check => {
    remaining = check;
    return new Promise(() => {});
  }, 15));
  assert.throws(() => remaining(), { message: AI_TIMEOUT_MESSAGE });
});
