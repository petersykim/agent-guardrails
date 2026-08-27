// gates.mjs -- mechanical checks a draft must pass before a person reviews it.
// No dependencies. Each check is a plain regex or a plain loop over numbers,
// nothing that asks a model to grade its own output.
//
// A rule an agent can talk itself out of is not a rule, it is a suggestion
// with good formatting. So every check here runs on the string itself.

// Marks that show up in generated prose far more often than in human prose.
// Written as escapes, not literal glyphs, so this file's own source never
// contains the marks it is built to catch.
const BANNED = [
  [/\u2014/, 'em-dash'],
  [/\u2192/, 'arrow'],
  [/[\u201C\u201D\u2018\u2019]/, 'smart quote'],
  [/\u2026/, 'ellipsis character'],
  [/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u, 'emoji'],
  // Requires a letter right after the hash mark, so an ordinary use like
  // "the number-one plumber spot" is not caught, only a hash mark glued
  // to a word the way a hashtag is.
  [/(^|\s)\u0023[A-Za-z]\w*/, 'hashtag'],
];

export function deAiViolations(text) {
  return BANNED.filter(([re]) => re.test(text)).map(([, name]) => name);
}

// Collect every number from a source-of-truth string you supply (verified
// figures, a changelog, a spec) so a draft can be checked against it.
// Numbers under 10 are skipped as ordinary prose ("one", "3 kids") rather
// than the kind of specific figure that carries a factual claim.
export function verifiedNumbers(sourceText) {
  const found = new Set();
  for (const m of String(sourceText || '').matchAll(/\d[\d,.]*/g)) {
    const raw = m[0].replace(/[,.]$/, '').replace(/,/g, '');
    if (Number(raw) >= 10) found.add(raw);
  }
  return found;
}

// Every number in `text` must appear in `allowed`, or it fails as an
// unsourced claim. A verified integer written with added precision still
// counts as that figure (allowed has 47, draft says "47.2 percent"), so a
// grounded draft is not sent back over a rounding difference.
export function groundingViolations(text, allowed) {
  const bad = [];
  for (const m of String(text || '').matchAll(/\d[\d,]*(?:\.\d+)?/g)) {
    const raw = m[0].replace(/,/g, '');
    if (Number(raw) < 10) continue;
    if (allowed.has(raw) || allowed.has(raw.split('.')[0])) continue;
    bad.push(`unsourced number "${m[0]}"`);
  }
  return bad;
}

// Phrases generated prose reaches for to explain the point it just made,
// instead of trusting the reader to get it. The "not A, it is B" reversal is
// the most common tell, and only in its present-tense generalizing form:
// ordinary past-tense narration ("it wasn't ready, it was late") is left
// alone because it describes an event instead of delivering a lesson.
const EXPLAINERS = [
  [/\bwhich means\b/i, 'explains itself ("which means")'],
  [/\bturns out\b/i, 'explains itself ("turns out")'],
  [/\bthe (part|thing) that\b/i, 'names the meaning ("the part that")'],
  [/\bthat'?s (the|how|why|what)\b/i, 'delivers the lesson ("that\'s the...")'],
  [/\b(is|are)(n'?t| not) [^.!?]{2,60}[,;] (it|they|that) (is|are)\b/i, 'the "not A, it is B" reversal'],
  [/\b(is|are) not (a|an|the) [^.!?]{2,40}\. (it|they|that) (is|are)\b/i, 'the "not A. It is B" reversal'],
];

// "because" is a cheap clause only where the explanation hangs off the end
// of the text. Mid-text causation ("I deleted the files because I panicked.
// Then...") is narration and passes; a final sentence carrying "because" is
// the punchline being explained, and fails.
const LAST_SENTENCE_BECAUSE = /\bbecause\b[^.!?]*[.!?]?\s*$/i;

export function momentViolations(text) {
  const t = String(text || '').trim();
  const hits = EXPLAINERS.filter(([re]) => re.test(t)).map(([, name]) => name);
  if (LAST_SENTENCE_BECAUSE.test(t)) hits.push('explains itself at the end ("because")');
  return hits;
}
