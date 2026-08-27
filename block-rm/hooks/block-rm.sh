#!/usr/bin/env bash
# block-rm.sh - PreToolUse(Bash) hook. Blocks rm (and find -delete) outside
# tmp dirs and tells the agent to use trash instead, so a bad delete is
# recoverable. Built after an agent deleted 392 files fixing one bad URL
# token; a rule an agent can talk itself out of is not a rule.
#
# Exit 0 = allow. Exit 2 = block (stderr shown to the model).
# Fails open on parse errors: better to miss a case than block legit work.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
CMD="$(printf '%s' "$payload" | python3 -c '
import sys,json
try:
    d=json.load(sys.stdin)
    if (d.get("tool_name") or "") != "Bash": print(""); raise SystemExit
    print(d.get("tool_input",{}).get("command",""))
except Exception:
    print("")' 2>/dev/null || true)"
[ -z "$CMD" ] && exit 0

# docker rm / docker rmi / docker container rm remove containers and images,
# not files. Mask them out before the file-rm match so they are not blocked.
CMD_FOR_RM="$(printf '%s' "$CMD" | sed -E 's#[^ ;&|]*docker[[:space:]]+(container[[:space:]]+)?(rm|rmi)([[:space:]]|$)#docker-remove\3#g')"

# Skip read-only commands that merely CONTAIN "rm" as a search pattern
# (grep/cat/find-print self-match problem), but only when the whole command
# is a single reader with no chaining. A chained command like
# "ls -la && rm important.txt" must fall through to the rm and find -delete
# checks below, so this shortcut only fires when there is no ; && || | pipe
# anywhere in CMD. Without that guard, a reader first word alone let the
# whole command through, rm included.
first_word="$(printf '%s' "$CMD" | awk '{print $1}')"
if ! printf '%s' "$CMD" | grep -qE '[;&|]'; then
  case "$first_word" in
    grep|rg|cat|head|tail|less|awk|sed|wc|diff|ls|find|echo|printf|python3|jq)
      case "$first_word" in
        find) printf '%s' "$CMD" | grep -q -- '-delete' || exit 0 ;;
        *) exit 0 ;;
      esac
      ;;
  esac
fi

block() { printf '%s\n' "$1" >&2; exit 2; }

# ---- rm ------------------------------------------------------------------
# Match rm as a command: at the start, after ; & | or inside a quoted string
# (covers ssh 'rm ...'). Allow only when every path argument lives under a
# tmp dir.
if printf '%s' "$CMD_FOR_RM" | grep -qE "(^|[;&|\"'[:space:]])rm[[:space:]]" ; then
  paths="$(printf '%s' "$CMD" | grep -oE "(^|[;&|\"'[:space:]])rm[[:space:]]+[^;&|\"']*" | head -1 \
           | sed -E 's/.*rm[[:space:]]+//' | tr ' ' '\n' | grep -vE '^-|>|^[0-9]*$' || true)"
  safe=1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in
      /tmp/*|/private/tmp/*|/var/folders/*|"$TMPDIR"*|/private/var/folders/*) ;;
      *) safe=0 ;;
    esac
  done <<< "$paths"
  if [ "$safe" -ne 1 ]; then
    block "BLOCKED: rm outside tmp is forbidden on this machine.
Use trash instead (recoverable):  trash <paths>
For remote hosts, prefer a rename to *.trash-\$(date +%s) over deletion.
tmp paths (/tmp, /var/folders, \$TMPDIR) are exempt."
  fi
fi

# find -delete is rm in a trenchcoat
if [ "$first_word" = "find" ] && printf '%s' "$CMD" | grep -q -- '-delete'; then
  printf '%s' "$CMD" | grep -qE 'find\s+(/tmp|/private/tmp|/var/folders|\$TMPDIR)' || \
    block "BLOCKED: find -delete outside tmp is forbidden. Use trash, or find ... -exec trash {} +"
fi

exit 0
