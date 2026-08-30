#!/usr/bin/env bash
# verify-before-stop.sh -- Stop hook that blocks an agent from ending its
# turn on a bare claim of "done". Before the stop is allowed, it checks
# that a git diff exists against the claimed files, that a named test
# command actually ran and exited 0, and that any file the task claims to
# have written is present on disk (optionally containing a required
# string). Any check can be skipped by leaving its variable unset.
#
# Wire into the Stop event. Reads the hook payload as JSON on stdin,
# writes the failing checks to stderr, and exits 2 to block or 0 to allow.
set -uo pipefail

INPUT=$(cat)

# Claude Code sets stop_hook_active=true when this hook already blocked
# once for the current stop attempt. Allow the stop on the second pass so
# one unmet check can't trap the session in a retry loop.
if command -v jq >/dev/null 2>&1; then
  STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
else
  # No jq on this machine: fall back to a grep parse of the flat JSON field.
  STOP_HOOK_ACTIVE=$(echo "$INPUT" | grep -o '"stop_hook_active"[[:space:]]*:[[:space:]]*true' >/dev/null && echo true || echo false)
fi
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

FAILURES=()

# 1. A diff must actually exist against the paths the task claimed to touch.
if [ -n "${VERIFY_DIFF_PATHS:-}" ]; then
  for path in $VERIFY_DIFF_PATHS; do
    if [ -z "$(git diff --name-only -- "$path" 2>/dev/null)" ] && \
       [ -z "$(git diff --cached --name-only -- "$path" 2>/dev/null)" ]; then
      FAILURES+=("no diff found against $path")
    fi
  done
fi

# 2. The project's own test command must run and pass.
if [ -n "${VERIFY_TEST_CMD:-}" ]; then
  if ! bash -c "$VERIFY_TEST_CMD" >/tmp/verify-before-stop.log 2>&1; then
    FAILURES+=("test command failed: $VERIFY_TEST_CMD (see /tmp/verify-before-stop.log)")
  fi
fi

# 3. Any claimed deliverable file must exist, and optionally contain a
#    required string.
if [ -n "${VERIFY_DELIVERABLE_FILES:-}" ]; then
  for file in $VERIFY_DELIVERABLE_FILES; do
    if [ ! -f "$file" ]; then
      FAILURES+=("deliverable missing: $file")
    elif [ -n "${VERIFY_DELIVERABLE_GREP:-}" ] && ! grep -q "$VERIFY_DELIVERABLE_GREP" "$file"; then
      FAILURES+=("deliverable $file does not contain: $VERIFY_DELIVERABLE_GREP")
    fi
  done
fi

if [ "${#FAILURES[@]}" -eq 0 ]; then
  exit 0
fi

{
  echo "Blocked: this stop was not verified."
  for f in "${FAILURES[@]}"; do
    echo "- $f"
  done
} >&2
exit 2
