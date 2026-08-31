#!/usr/bin/env bash
set -euo pipefail

# toolbox-bootstrap/setup-host.sh
# Host-side bootstrap — everything that lives in $HOME (shared across toolboxes).
# Run ONCE per machine / Silverblue host (not inside toolbox).
# Handles: dotfiles, oh-my-zsh + powerlevel10k, zsh plugins, nerd fonts (via GitHub).
#
# Idempotent. Safe to re-run. Uses GitHub as source for omz/p10k/fonts.

DRY_RUN=false
WITH_FONTS=true
UPDATE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --without-fonts) WITH_FONTS=false ;;
    --update) UPDATE=true ;;
    --help|-h)
      cat <<'HELP'
Usage: setup-host.sh [OPTIONS]

Host bootstrap — installs everything that persists in $HOME via GitHub.

  --dry-run        Print what would run, don't mutate
  --without-fonts  Skip nerd fonts download
  --update         git pull existing clones + refresh fonts
  --help           This message

Installs:
  dotfiles  (.zshrc/.p10k.zsh/.zshenv from ./dotfiles/)
  omz       (ohmyzsh/ohmyzsh)
  p10k      (romkatv/powerlevel10k)
  plugins   (zsh-autosuggestions, zsh-syntax-highlighting)
  fonts     (MesloLGS NF — p10k recommended, via romkatv/powerlevel10k-media)

Re-runnable. Run from host, not inside toolbox (checks $container).
HELP
      exit 0
      ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m ok\033[0m %s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}
ensure_git_clone() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    ok "exists $dest"
    if [[ "$UPDATE" == true ]]; then
      log "updating $dest"
      run "git -C \"$dest\" pull --ff-only --quiet || true"
    fi
  else
    log "clone $url → $dest"
    run "git clone --depth=1 \"$url\" \"$dest\""
  fi
}

if [[ -n "${container:-}" ]] || [[ -f /run/.containerenv ]]; then
  warn "You appear to be INSIDE a toolbox (\$container set)."
  warn "setup-host.sh is for the HOST — it writes to \$HOME which is shared, but"
  warn "prefer to run it from the host shell. Continuing anyway in 3s…"
  sleep 3 || true
fi
[[ "$DRY_RUN" == true ]] && warn "DRY RUN — no changes will be made"

# ── dotfiles ───────────────────────────────────────────────────────────────
# Source is ./dotfiles/ next to this script. Backs up existing files once.
install_dotfile() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then warn "missing source $src — skip"; return 0; fi
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    ok "$dst up to date"
    return 0
  fi
  if [[ -f "$dst" && ! -f "$dst.pre-toolbox-bootstrap" ]]; then
    log "backup $dst → $dst.pre-toolbox-bootstrap"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] cp \"$dst\" \"$dst.pre-toolbox-bootstrap\""
    else
      cp "$dst" "$dst.pre-toolbox-bootstrap"
    fi
  fi
  log "install $src → $dst"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] cp \"$src\" \"$dst\""
  else
    cp "$src" "$dst"
  fi
}

log "Dotfiles ($SCRIPT_DIR/dotfiles → \$HOME)"
install_dotfile "$SCRIPT_DIR/dotfiles/.zshrc"  "$HOME/.zshrc"
install_dotfile "$SCRIPT_DIR/dotfiles/.p10k.zsh" "$HOME/.p10k.zsh"
install_dotfile "$SCRIPT_DIR/dotfiles/.zshenv" "$HOME/.zshenv"

# ── oh-my-zsh / powerlevel10k / plugins (all via GitHub) ─────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

ensure_git_clone "https://github.com/ohmyzsh/ohmyzsh" "$HOME/.oh-my-zsh"

# p10k may live in $ZSH/themes (legacy) or $ZSH_CUSTOM/themes — handle both
if [[ -d "$HOME/.oh-my-zsh/themes/powerlevel10k" ]] || [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  ok "powerlevel10k already installed"
  if [[ "$UPDATE" == true ]]; then
    for d in "$HOME/.oh-my-zsh/themes/powerlevel10k" "$ZSH_CUSTOM/themes/powerlevel10k"; do
      [[ -d "$d/.git" ]] && run "git -C \"$d\" pull --ff-only --quiet || true"
    done
  fi
else
  ensure_git_clone "https://github.com/romkatv/powerlevel10k" "$ZSH_CUSTOM/themes/powerlevel10k"
fi

ensure_git_clone "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
ensure_git_clone "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

if [[ ! -d "$ZSH_CUSTOM/plugins/kubectl-autocomplete" ]]; then
  warn "custom plugin kubectl-autocomplete not found — create $ZSH_CUSTOM/plugins/kubectl-autocomplete if you use it"
fi

# ── nerd fonts (GitHub, not dnf) ─────────────────────────────────────────
# MesloLGS NF is p10k's recommended font. Fetch 4 variants from powerlevel10k-media.
if [[ "$WITH_FONTS" == true ]]; then
  FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
  NEED_FONTS=false
  for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
    [[ -f "$FONT_DIR/$f" ]] || NEED_FONTS=true
  done
  if [[ "$NEED_FONTS" == false && "$UPDATE" == false ]]; then
    ok "MesloLGS NF already in $FONT_DIR"
  else
    log "nerd fonts → $FONT_DIR (MesloLGS NF via github.com/romkatv/powerlevel10k-media)"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] mkdir -p \"$FONT_DIR\" && curl -fLo … (4 fonts) && fc-cache -f"
    else
      mkdir -p "$FONT_DIR"
      base="https://github.com/romkatv/powerlevel10k-media/raw/master"
      for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
        # encode space as %20
        url="$base/${f// /%20}"
        dest="$FONT_DIR/$f"
        if [[ -f "$dest" && "$UPDATE" == false ]]; then
          ok "exists $f"
          continue
        fi
        echo "  $f"
        curl -fLo "$dest" "$url"
      done
      if command -v fc-cache &>/dev/null; then
        fc-cache -f "$FONT_DIR" 2>/dev/null || fc-cache -f 2>/dev/null || true
        ok "fc-cache done"
      else
        warn "fc-cache not found — fonts installed but cache not refreshed (install fontconfig)"
      fi
    fi
  fi
else
  log "skip fonts (--without-fonts)"
fi

# ── default shell (host only) ────────────────────────────────────────────
if [[ "${SHELL:-}" != *"zsh"* ]]; then
  if command -v zsh &>/dev/null; then
    log "setting default shell to zsh"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] chsh -s \$(which zsh)"
    else
      chsh -s "$(which zsh)" 2>/dev/null || warn "chsh failed — run manually: chsh -s \$(which zsh)"
    fi
  else
    warn "zsh not found on host — install it (dnf install zsh / apt install zsh) then re-run"
  fi
else
  ok "SHELL is zsh ($SHELL)"
fi

# ── summary ──────────────────────────────────────────────────────────────
log "Done."
if [[ "$DRY_RUN" == true ]]; then
  warn "Dry run — rerun without --dry-run to apply"
else
  ok "Host ready — open a new terminal or: exec zsh"
  echo ""
  echo "Next for toolbox: toolbox enter && ./setup-toolbox.sh  (or --minimal / --dry-run)"
  echo "Fonts: set your terminal font to 'MesloLGS NF' for p10k to render correctly."
fi
