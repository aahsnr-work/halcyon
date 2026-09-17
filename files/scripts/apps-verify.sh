#!/usr/bin/env bash
# halcyon apps.yml post-install verification (prompt §5.3)
# NOTE: BlueBuild dnf module's repos.cleanup only DISABLES COPRs — it does not
# remove files:/URL-added repo files in CLI v0.9.37 (add_repos returns empty
# repo IDs; see NOTES.md deviation R), so this script removes them explicitly.
set -euo pipefail
dnf5 config-manager setopt terra.enabled=0    # restore base state (§1.11)
rm -f /etc/yum.repos.d/_copr*sneexy* /etc/yum.repos.d/_copr_sneexy*
rm -f /etc/yum.repos.d/vscode.repo /etc/yum.repos.d/brave-browser*.repo
command -v code brave-browser zen-browser zed emacs
# provenance (§1.21), HARD gates — each package must come from its intended
# source (COPR builds stamp "Fedora Copr - user <name>" as vendor; dnf5
# from-repo history is unavailable on rpm-ostree images, hence vendor checks):
rpm -q --qf '%{name} (vendor: %{VENDOR})\n' \
  code brave-browser brave-origin zen-browser zed emacs-pgtk || true
v="$(rpm -q --qf '%{VENDOR}' zen-browser)";   echo "$v" | grep -qi 'sneexy'   || { echo "ERROR: zen-browser vendor '$v' — must be the sneexy COPR (user directive)"; exit 1; }
v="$(rpm -q --qf '%{VENDOR}' zed)";           echo "$v" | grep -qi 'terra'    || { echo "ERROR: zed vendor '$v' — must be terra"; exit 1; }
v="$(rpm -q --qf '%{VENDOR}' code)";          echo "$v" | grep -qi 'microsoft' || { echo "ERROR: code vendor '$v' — must be Microsoft"; exit 1; }
v="$(rpm -q --qf '%{VENDOR}' brave-browser)"; echo "$v" | grep -qi 'brave'    || { echo "ERROR: brave-browser vendor '$v' — must be Brave"; exit 1; }
rpm -q brave-origin || echo 'NOTE: brave-origin unavailable this run (skip-unavailable)'
# /opt auto-relocation check (CLI >= v0.9.23, §1.19o):
ls -d /usr/lib/opt/brave.com 2>/dev/null || ls -d /opt/brave.com 2>/dev/null \
  || { echo 'ERROR: brave /opt content missing — check BlueBuild CLI version'; exit 1; }
ls /usr/lib/tmpfiles.d/ | grep -i brave || true
# repo hygiene gates (after explicit cleanup above)
dnf5 repolist --enabled | grep -Ei 'brave|^code|zen|terra' && { echo 'ERROR: repo cleanup failed'; exit 1; } || true
ls /etc/yum.repos.d/ | grep -Ei 'brave|vscode|sneexy' && { echo 'ERROR: repo file left behind'; exit 1; } || true
