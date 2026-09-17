#!/usr/bin/env bash
# halcyon brew.yml verification (prompt §5.7) — build-order-aware split:
# at this point (module order 7) only the BASE brew payload can be checked;
# the Brewfile + user unit are copied later (files.yml's files module,
# order 9) and are verified in files-verify.sh (see NOTES.md deviation O).
set -euo pipefail

echo "::group::brew-verify — base brew payload"
echo "--- Checking base brew payload ---"

BREW_TARBALL=/usr/share/homebrew.tar.zst
if test -f "${BREW_TARBALL}"; then
  size=$(du -h "${BREW_TARBALL}" | cut -f1)
  echo "  PASS  ${BREW_TARBALL} present (${size})"
else
  echo "  FAIL  ${BREW_TARBALL} missing — brew.yml base payload not installed"
  echo "::endgroup::"
  exit 1
fi

echo "--- brew-verify complete ---"
echo "::endgroup::"
