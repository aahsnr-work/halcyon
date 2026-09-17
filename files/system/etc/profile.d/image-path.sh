# shellcheck shell=sh
# halcyon image paths: helper scripts and Homebrew environment
case ":${PATH}:" in
  *:/home/linuxbrew/.linuxbrew/bin:*) ;;
  *) export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}" ;;
esac

case ":${PATH}:" in
  *:/usr/libexec/halcyon-image:*) ;;
  *) export PATH="/usr/libexec/halcyon-image:${PATH}" ;;
esac

export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
[ -d "/home/linuxbrew/.linuxbrew/share/man" ] && case ":${MANPATH:-}:" in *:/home/linuxbrew/.linuxbrew/share/man:*) ;; *) export MANPATH="/home/linuxbrew/.linuxbrew/share/man${MANPATH+:$MANPATH}:" ;; esac
[ -d "/home/linuxbrew/.linuxbrew/share/info" ] && case ":${INFOPATH:-}:" in *:/home/linuxbrew/.linuxbrew/share/info:*) ;; *) export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}" ;; esac
