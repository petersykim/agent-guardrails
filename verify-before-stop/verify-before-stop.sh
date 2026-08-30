#!/usr/bin/env bash
# Stop-hook gate: an agent cannot end its turn on an unverified claim of "done."
# Reads Claude Code's Stop-hook JSON on stdin, checks the deliverable this run
# was configured to produce, and either allows the stop or blocks it with the
# specific claim that failed.
#
# Configure via environment (set in settings.json, see README):
#   VERIFY_TEST_CMD          shell command that must exit 0 (e.g. "npm test")
#   VERIFY_DIFF_PATHS        space-separated paths that must show a git diff
#                             against HEAD (files the task claimed to change)
#   VERIFY_DELIVERABLE_FILES space-separated files that must exist and be
#                             non-empty (files the task claimed to write)
#   VERIFY_DELIVERABLE_GREP  optional string that must appear in every file
#                             listed in VERIFY_DELIVERABLE_FILES
#
# Any variable left unset skips that check. Unset all four and the hook is a
# no-op that always allows the stop.

set -u

input="$(cat)"

# Stop hooks can be re-invoked after they already blocked once this turn.
# Refusing a second time risks an infinite loop, so on the replay we allow.
stop_hook_active="$(printf '%s' "$input" | grep -o '"stop_hook_active"[[:space:]]*:[[:space:]]*true' || true)"
if [ -n "$stop_hook_active" ]; then
  exit 0
fi

fail_reasons=()

# 1. Diff check: the claimed files must actually differ from HEAD.
if [ -n "${VERIFY_DIFF_PATHS:-}" ]; then
  for path in $VERIFY_DIFF_PATHS; do
    if [ ! -e "$path" ]; then
      fail_reasons+=("claimed file does not exist: $path")
      continue
    fi
    if git diff --quiet -- "$path" 2>/dev/null && git diff --cached --quiet -- "$path" 2>/dev/null; then
      fail_reasons+=("no diff against HEAD for claimed file: $path")
    fi
  done
fi

# 2. Test check: the named test command must actually run and pass.
if [ -n "${VERIFY_TEST_CMD:-}" ]; then
  if ! eval "$VERIFY_TEST_CMD" >/tmp/verify-before-stop.log 2>&1; then
    tail_lines="$(tail -n 5 /tmp/verify-before-stop.log 2>/dev/null)"
    fail_reasons+=("test command failed: ${VERIFY_TEST_CMD} (last lines: ${tail_lines})")
  fi
fi

# 3. Deliverable check: files claimed as written must exist on disk, non-empty,
#    and (optionally) contain the expected content.
if [ -n "${VERIFY_DELIVERABLE_FILES:-}" ]; then
  for f in $VERIFY_DELIVERABLE_FILES; do
    if [ ! -s "$f" ]; then
      fail_reasons+=("claimed deliverable missing or empty: $f")
      continue
    fi
    if [ -n "${VERIFY_DELIVERABLE_GREP:-}" ]; then
      if ! grep -q -- "$VERIFY_DELIVERABLE_GREP" "$f" 2>/dev/null; then
        fail_reasons+=("deliverable $f does not contain expected content: $VERIFY_DELIVERABLE_GREP")
      fi
    fi
  done
fi

if [ "${#fail_reasons[@]}" -eq 0 ]; then
  exit 0
fi

reason="Stop blocked, unverified claims of done:"
for r in "${fail_reasons[@]}"; do
  reason="$reason
- $r"
done

json_reason="$(printf '%s' "$reason" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)"
if [ -z "$json_reason" ]; then
  json_reason="\"$reason\""
fi

printf '{"decision": "block", "reason": %s}\n' "$json_reason"
exit 0
