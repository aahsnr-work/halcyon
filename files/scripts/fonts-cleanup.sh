#!/usr/bin/env bash
# halcyon Step F — fonts, safe removal (prompt §5.1)
set -uo pipefail
PROTECT='^(fontconfig|fontpackages|dejavu-sans-fonts|dejavu-sans-mono-fonts)(-|$)'
removed=()
kept=()
while read -r pkg; do
  [ -n "${pkg}" ] || continue
  if echo "${pkg}" | grep -Eq "${PROTECT}"; then
    kept+=("${pkg}")
    continue
  fi
  reqs="$(rpm -q --whatrequires "${pkg}" 2>/dev/null || true)"
  if [ -z "${reqs}" ] || echo "${reqs}" | grep -q 'no package requires'; then
    if rpm -e --nodeps "${pkg}"; then
      removed+=("${pkg}")
    else
      kept+=("${pkg}")
    fi
  else
    kept+=("${pkg} (required)")
  fi
done < <(rpm -qa '*fonts*' | sort)
echo "fonts removed: ${removed[*]:-none}"
echo "fonts kept:    ${kept[*]:-none}"
fc-cache -f >/dev/null 2>&1 || true
exit 0
