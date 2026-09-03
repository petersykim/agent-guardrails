# ots-block-height

Pulls the Bitcoin block height a `.ots` timestamp proof points to, without making a network call.

## Why

`ots verify` confirms a proof by calling out to a calendar server or a full node. If neither is reachable, verification stalls, even though the proof already contains everything needed to answer "what block was this stamped in." `ots info <file>` parses the proof's own attestation chain locally and prints that height in its output. This script just extracts it, so any pipeline that ships timestamped receipts (contracts, ledgers, build artifacts) can read the confirmed height as an instant, offline check instead of waiting on infrastructure the proof doesn't need.

## Install

1. Install the OpenTimestamps client: `pip install opentimestamps-client`
2. Save `ots-block-height.sh` and make it executable: `chmod +x ots-block-height.sh`
3. Stamp and upgrade a file as usual so the proof carries a confirmed attestation:
   `ots stamp myfile.json && ots upgrade myfile.json.ots`
4. Run it directly: `./ots-block-height.sh myfile.json.ots`, or source it and call `ots_block_height <file>` from your own script.

## What to change

- **Grep pattern.** This targets `height=NNNN`, the format the current `opentimestamps-client` prints in `ots info` output for a Bitcoin attestation. If your installed version prints a different phrasing (older clients have shown forms like `Bitcoin block NNNNNN`), widen the pattern, for example: `grep -oE 'height=[0-9]+|[Bb]lock[[:space:]]+[0-9]+' | grep -oE '[0-9]+' | head -n1`.
- **Pending proofs.** A freshly stamped proof that hasn't been upgraded yet has no confirmed block attestation. The script exits 1 with a message in that case; if your pipeline calls this before running `ots upgrade`, handle that exit code rather than treating it as an error.
- **Multiple attestations.** A proof can carry more than one attestation path if it was submitted to several calendars. The script takes the first height found; if you need every height, drop the `head -n1`.
