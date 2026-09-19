# shellcheck shell=sh
# halcyon image-path.sh — add helper scripts to PATH for all POSIX login/interactive shells.
#
# Homebrew is retired from the image (MIGRATION.md §8.7 — replaced by monorepo
# RPMs); only the halcyon helper scripts directory is added here.
case ":${PATH}:" in
  *:/usr/libexec/halcyon-image:*) ;;
  *) export PATH="${PATH}:/usr/libexec/halcyon-image" ;;
esac
