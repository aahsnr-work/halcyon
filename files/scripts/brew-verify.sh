#!/usr/bin/env bash
# halcyon brew.yml verification (prompt §5.7) — build-order-aware split:
# at this point (module order 7) only the BASE brew payload can be checked;
# the Brewfile + user unit are copied later (files.yml's files module,
# order 9) and are verified in files-verify.sh (see NOTES.md deviation O).
set -euo pipefail
test -f /usr/share/homebrew.tar.zst   # base brew payload intact (untouched!)
