#!/usr/bin/env bash
# ots-block-height.sh
# Reads the Bitcoin block height out of an OpenTimestamps .ots proof
# by parsing the proof's own attestation chain locally. No calendar
# server, no full node, no network call.
#
# Requires: opentimestamps-client (pip install opentimestamps-client)

set -euo pipefail

ots_block_height() {
  local proof="$1"
  ots info "$proof" 2>/dev/null | grep -oE 'height=[0-9]+' | head -n1 | grep -oE '[0-9]+'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "usage: $(basename "$0") <file.ots>" >&2
    exit 1
  fi

  height="$(ots_block_height "$1")"
  if [[ -z "$height" ]]; then
    echo "no confirmed block height found in $1 (proof may still be pending upgrade)" >&2
    exit 1
  fi

  echo "$height"
fi
