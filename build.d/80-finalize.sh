#!/usr/bin/env bash
# halcyon build stage 13 — finalize: third-party repo lifecycle end state.
# Each consuming stage already disabled its repos; this is the belt-and-braces
# sweep bazzite performs too (it deletes cached COPR repo files at finalize).
# The shipped image carries NO third-party repo files — updates arrive via
# image rebuilds (bootc); any repo can be re-enabled at runtime if needed.
set -euo pipefail
echo "::group::80-finalize — third-party repo sweep"
rm -f /etc/yum.repos.d/_copr*:*.repo /etc/yum.repos.d/_copr*.repo \
      /etc/yum.repos.d/vscode.repo \
      /etc/yum.repos.d/brave-browser*.repo \
      /etc/yum.repos.d/terra*.repo \
      /etc/yum.repos.d/fedora-nvidia.repo \
      /etc/yum.repos.d/negativo17*.repo \
      /etc/yum.repos.d/rpmfusion-*.repo
echo "  INFO  remaining repo files (Fedora only):"
ls /etc/yum.repos.d/
echo "::endgroup::"
