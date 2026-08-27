// Tests for gates.mjs. Fixtures use escape codes instead of the literal
// marks themselves, for the same reason gates.mjs does: keep the actual
// glyphs out of the source text.
//
// Run: node --test _gates.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  deAiViolations, verifiedNumbers, groundingViolations, momentViolations,
} from './_gates.mjs';

test('the de-AI gate catches every banned mark', () => {
  assert.deepEqual(deAiViolations('a clean sentence about agents.'), []);
  assert.deepEqual(deAiViolations('a thought \u2014 then more'), ['em-dash']);
  assert.deepEqual(deAiViolations('X \u2192 Y'), ['arrow']);
  assert.deepEqual(deAiViolations('he said \u201Chello\u201D'), ['smart quote']);
  assert.deepEqual(deAiViolations('wait\u2026 no'), ['ellipsis character']);
  assert.deepEqual(deAiViolations('ship it \u{1F680}'), ['emoji']);
  assert.deepEqual(deAiViolations('read this \u0023buildinpublic'), ['hashtag']);
});

test('a hash mark that is not a hashtag is allowed through', () => {
  assert.deepEqual(deAiViolations('the \u00231 plumber spot costs $2'), []);
});

test('verifiedNumbers pulls numbers 10 and higher out of a string', () => {
  const source = 'preamble with 9 in it, then 392 files and about 400 model calls';
  const found = verifiedNumbers(source);
  assert.ok(found.has('392'));
  assert.ok(found.has('400'));
  assert.ok(!found.has('9'), 'single-digit numbers are ordinary prose');
});

test('the grounding gate rejects a number nobody checked', () => {
  const allowed = new Set(['392']);
  assert.deepEqual(groundingViolations('it deleted 392 files', allowed), []);
  assert.deepEqual(groundingViolations('it deleted 500 files', allowed),
    ['unsourced number "500"']);
});

test('the grounding gate ignores small numbers as ordinary prose', () => {
  assert.deepEqual(groundingViolations('I have 3 kids and 2 jobs', new Set()), []);
});

test('the grounding gate accepts a verified integer written with decimals', () => {
  assert.deepEqual(groundingViolations('the rate was 47.2 percent', new Set(['47'])), []);
  assert.deepEqual(groundingViolations('the rate was 48.2 percent', new Set(['47'])),
    ['unsourced number "48.2"']);
});

test('the grounding gate reads a comma-grouped number as one figure', () => {
  assert.deepEqual(groundingViolations('5,688 messages', new Set(['5688'])), []);
});

test('a moment that states the point and stops passes', () => {
  const good = "The reflex to delete everything and start over isn't my agent's. It's mine.";
  assert.deepEqual(momentViolations(good), []);
});

test('a moment that explains itself is rejected', () => {
  const explained = 'My agent told me the job was big, then did half of it, because it wanted to look diligent.';
  assert.ok(momentViolations(explained).some((b) => b.includes('because')));
  const reversal = 'The dangerous failure is not the wrong answer, it is the unraised one.';
  assert.ok(momentViolations(reversal).some((b) => b.includes('reversal')));
});

test('ordinary past-tense narration is not a reversal, and mid-text because passes', () => {
  assert.deepEqual(momentViolations("It wasn't ready, it was late. I shipped it anyway."), []);
  assert.deepEqual(momentViolations('The meeting wasn\'t canceled, it was moved to Tuesday.'), []);
  assert.deepEqual(momentViolations('I deleted the files because I panicked. Then I sat there.'), []);
  assert.ok(momentViolations('I said thanks because it sounded like diligence.').some((b) => b.includes('because')));
});
