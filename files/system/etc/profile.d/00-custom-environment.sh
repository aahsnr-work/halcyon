#!/usr/bin/env bash
# System-wide environment variables for /etc/profile.d/
# This script is sourced by /etc/profile and must be POSIX-compliant

# XDG Base Directory Specification
export XDG_BIN_HOME="${HOME}/.local/bin"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"

# Backup Directory
export BACKUP_DIR="${HOME}/backup"

# Default Applications
export TERMINAL="kitty"
export BROWSER="brave"
export EDITOR="nvim"
export VISUAL="emacsclient -c -a emacs"
export PAGER="bat --paging=always --style=plain"

# Prepend "$1" to $PATH when not already in.
# This function API is accessible to scripts in /etc/profile.d
pathprepend() {
  case ":$PATH:" in
  *:"$1":*) ;;
  *)
    PATH="$1${PATH:+:$PATH}"
    ;;
  esac
}

# Prepend custom directories to PATH (in reverse order of priority)
# Last prepended = highest priority
pathprepend "${HOME}/.npm-global/bin"
pathprepend "${HOME}/.config/emacs/bin"
pathprepend "${HOME}/.local/bin"
pathprepend "${HOME}/.cache/.bun/bin"
pathprepend "${HOME}/.bun/bin"
pathprepend "${HOME}/go/bin"
pathprepend "${HOME}/.cargo/bin"
pathprepend "${HOME}/bin"

# Nix & Home-Manager User Profiles
pathprepend "/nix/var/nix/profiles/default/bin"
pathprepend "${HOME}/.nix-profile/bin"

# Belt-and-suspenders: ensure system paths are always present.
#
# Normally /etc/profile's pathmunge() calls happen before profile.d/ is
# sourced, so these dirs are already in PATH.  However some session starters
# (greetd → tuigreet → start-hyprland) propagate the PAM/systemd-user
# environment directly to child processes without re-running /etc/profile.
# If /etc/environment.d/10-homebrew.conf ever produces a broken PATH (e.g.
# during a generator run where $PATH is unset), those sessions would end up
# with no system binaries.  Explicitly appending here covers that corner case
# without disturbing the priority of user-space dirs already prepended above.
for _syspath in /sbin /bin /usr/sbin /usr/bin /usr/local/sbin /usr/local/bin; do
  pathprepend "${_syspath}"
done
unset _syspath

# Export PATH
export PATH
