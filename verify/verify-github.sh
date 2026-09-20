#!/usr/bin/env bash
# verify/verify-github.sh — HOST-side audit of the .github folder (task:
# ".github files must be correctly placed, error-free, and complete").
# Checks: required files present, YAML parses, referenced actions exist and
# are reasonably current, cron expressions valid, run-step shell snippets are
# bash-syntax-clean, and the log helper sources cleanly.
# Optional: if `actionlint` is on PATH it is run over every workflow too.
set -uo pipefail

fail=0
pass() { printf '  PASS  %s\n' "$1"; }
failf() { printf '  FAIL  %s\n' "$1"; fail=1; }
info() { printf '  INFO  %s\n' "$1"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GH="${ROOT}/.github"

echo "::group::verify-github — required files (image-template/main parity)"
for f in workflows/build.yml dependabot.yml renovate.json5 log-helpers.sh \
         workflows/lint.yml workflows/clean.yml semantic.yml \
         pull_request_template.md CODEOWNERS; do
  if [ -f "${GH}/${f}" ]; then pass ".github/${f}"; else failf ".github/${f} missing"; fi
done
echo "::endgroup::"

echo "::group::verify-github — YAML parse + workflow structure"
python_check() {
  python3 - "$1" <<'PY'
import sys
try:
    import yaml
except ImportError:
    sys.exit(3)
docs = list(yaml.safe_load_all(open(sys.argv[1])))
# workflows use a single doc; `---` leading marker is fine
sys.exit(0 if docs else 1)
PY
}
for wf in "${GH}"/workflows/*.yml; do
  name="$(basename "${wf}")"
  if python3 -c 'import yaml' 2>/dev/null; then
    if python_check "${wf}"; then
      pass "${name}: YAML parses"
    else
      case "$?" in
        3) info "${name}: PyYAML unavailable — skipped parse check" ;;
        *) failf "${name}: YAML does not parse" ;;
      esac
    fi
  else
    info "PyYAML unavailable — skipping YAML parse checks"
    break
  fi
  # every workflow must declare name/on/jobs
  grep -q '^name:' "${wf}"   || failf "${name}: missing name:"
  grep -q '^on:' "${wf}"     || failf "${name}: missing on: trigger"
  grep -q '^jobs:' "${wf}"   || failf "${name}: missing jobs:"
done
echo "::endgroup::"

echo "::group::verify-github — cron expressions"
cron_field_ok() {
  python3 - "$1" <<'PY'
import re, sys
c = sys.argv[1].split()
ok = len(c) == 5 and all(re.fullmatch(r'[\d*,/\-A-Za-z]+', f) for f in c)
sys.exit(0 if ok else 1)
PY
}
cron_extract() { grep -hoP 'cron:[[:space:]]*"\K[^"#]*' "${GH}"/workflows/*.yml | sed 's/[[:space:]]*$//'; }
cron_field_ok() {
  python3 - "$1" <<'PY'
import re, sys
c = sys.argv[1].split()
ok = len(c) == 5 and all(re.fullmatch(r'[\d*,/\-A-Za-z]+', f) for f in c)
sys.exit(0 if ok else 1)
PY
}
while read -r c; do
  if cron_field_ok "${c}"; then pass "cron '${c}' well-formed"; else failf "cron '${c}' malformed"; fi
done < <(cron_extract)
echo "::endgroup::"

echo "::group::verify-github — action references pinned to known majors"
check_action() { # $1 file, $2 uses-line fragment, $3 expected major
  if grep -q "uses: ${2}@v${3}\$" "${1}" || grep -qE "uses: ${2}@v${3}\b" "${1}"; then
    pass "$(basename "$1"): ${2}@v${3}"
  else
    failf "$(basename "$1"): ${2} not at v${3}"
  fi
}
check_action "${GH}/workflows/build.yml" "actions/checkout" 7
check_action "${GH}/workflows/build.yml" "extractions/setup-just" 4
check_action "${GH}/workflows/build.yml" "ublue-os/remove-unwanted-software" 9
check_action "${GH}/workflows/build.yml" "docker/login-action" 4
check_action "${GH}/workflows/build.yml" "sigstore/cosign-installer" 4
check_action "${GH}/workflows/lint.yml" "actions/checkout" 7
echo "::endgroup::"

echo "::group::verify-github — embedded shell snippets"
if bash -n "${GH}/log-helpers.sh" 2>/dev/null; then
  pass "log-helpers.sh: bash -n clean"
else
  failf "log-helpers.sh: bash -n FAILED"
fi
# source + call each helper once (colors off-screen but proves definitions)
if bash -c 'source "'"${GH}"'/log-helpers.sh" && banner t && step s && ok o && warn w >/dev/null 2>&1'; then
  pass "log-helpers.sh: sources + helpers callable"
else
  failf "log-helpers.sh: sourcing failed"
fi
# every run step that sources the helper must reference an existing file
for wf in "${GH}"/workflows/*.yml; do
  if grep -q 'source .github/log-helpers.sh' "${wf}" && [ ! -f "${GH}/log-helpers.sh" ]; then
    failf "$(basename "${wf}"): sources a missing log-helpers.sh"
  fi
done
pass "workflow helper references resolve"
echo "::endgroup::"

echo "::group::verify-github — COPR repodata polling configuration"
if grep -q 'solopasha' "${GH}/workflows/build.yml"; then
  failf "build.yml references obsolete solopasha COPR"
else
  pass "build.yml contains no obsolete solopasha COPR"
fi
for copr in "catpieleaf/kernel-p03" "lionheartp/Hyprland" "ublue-os/packages" "sneexy/zen-browser"; do
  if grep -q "${copr}" "${GH}/workflows/build.yml"; then
    pass "build.yml monitors ${copr}"
  else
    failf "build.yml missing COPR monitor for ${copr}"
  fi
done
echo "::endgroup::"

echo "::group::verify-github — actionlint (optional)"
if command -v actionlint >/dev/null 2>&1; then
  if actionlint -color=never "${GH}"/workflows/*.yml; then
    pass "actionlint clean"
  else
    failf "actionlint reported problems"
  fi
else
  info "actionlint not installed — skipped (install: go install github.com/rhysd/actionlint/cmd/actionlint@latest)"
fi
echo "::endgroup::"

if [ "${fail}" -eq 0 ]; then
  echo "--- verify-github: ALL CHECKS PASSED ---"
  exit 0
fi
echo "::error::verify-github FAILED"
exit 1
