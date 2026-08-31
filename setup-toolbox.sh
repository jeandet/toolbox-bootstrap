#!/usr/bin/env bash
set -euo pipefail

# toolbox-bootstrap/setup-toolbox.sh
# Idempotent cozy env bootstrap for Fedora Toolbox.
# Full by default (shell dnf + dev + qt + k8s + fpga + perf). Use --minimal for shell dnf only.
# Home stuff (omz/p10k/dotfiles/fonts) is in setup-host.sh (host, via GitHub).
# Top-level packages only — dnf pulls deps, stays robust across Fedora releases.

DRY_RUN=false
MINIMAL=false
WITHOUT_K8S=false
WITHOUT_FPGA=false
WITHOUT_QT=false
WITHOUT_PERF=false
UPDATE_TOOLCHAINS=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --minimal) MINIMAL=true ;;
    --without-k8s) WITHOUT_K8S=true ;;
    --without-fpga) WITHOUT_FPGA=true ;;
    --without-qt) WITHOUT_QT=true ;;
    --without-perf) WITHOUT_PERF=true ;;
    --update-toolchains) UPDATE_TOOLCHAINS=true ;;
    --help|-h)
      cat <<'HELP'
Usage: setup-toolbox.sh [OPTIONS]

Full by default (everything). Options to slim down:

  --minimal              Shell dnf only (zsh + CLI tools; omz/p10k via setup-host.sh)
  --without-k8s          Skip podman/helm/kubectl
  --without-fpga         Skip ARM/FPGA toolchain (arm-none-eabi, openocd, yosys, etc.)
  --without-qt           Skip Qt6 devel packages (uses ~/Qt SDK if present)
  --without-perf         Skip perf/strace
  (home stuff: use setup-host.sh on host — this script is dnf-only)
  --dry-run              Print what would run, don't mutate
  --update-toolchains    Also run rustup update / nvm checks
  --help                 This message

Re-runnable. Safe to run twice. Toolbox-aware (warns if outside container).
HELP
      exit 0
      ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
  esac
done

# Minimal implies all extras off unless explicitly re-enabled (not supported — keep simple)
if [[ "$MINIMAL" == true ]]; then
  WITHOUT_K8S=true
  WITHOUT_FPGA=true
  WITHOUT_QT=true
  WITHOUT_PERF=true
fi

# ── helpers ──────────────────────────────────────────────────────────────
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
is_toolbox() { [[ -n "${container:-}" ]] || [[ -f /run/.containerenv ]]; }
have_cmd() { command -v "$1" &>/dev/null; }
have_rpm() { rpm -q "$1" &>/dev/null; }
dnf_install() {
  # dnf is idempotent — just call it with the full list; it skips installed.
  # Batch into one transaction per group for speed.
  local pkgs=("$@")
  if [[ ${#pkgs[@]} -eq 0 ]]; then return 0; fi
  log "dnf install: ${pkgs[*]}"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] sudo dnf install -y ${pkgs[*]}"
  else
    sudo dnf install -y "${pkgs[@]}"
  fi
}
ensure_git_clone() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    ok "exists $dest"
    if [[ "$UPDATE_TOOLCHAINS" == true ]]; then
      log "updating $dest"
      run "git -C \"$dest\" pull --ff-only --quiet || true"
    fi
  else
    log "clone $url → $dest"
    run "git clone --depth=1 \"$url\" \"$dest\""
  fi
}
ensure_gem() {
  local gem="$1"
  if gem list -i "^${gem}$" &>/dev/null; then
    ok "gem $gem already installed"
  else
    log "gem install $gem"
    run "gem install \"$gem\""
  fi
}

# ── toolbox check ────────────────────────────────────────────────────────
if ! is_toolbox; then
  warn "Not inside a toolbox container (\$container empty, no /run/.containerenv)."
  warn "This script is for toolbox. It will still run, but prefer: toolbox enter && $0"
fi
if ! have_cmd dnf && ! have_cmd microdnf 2>/dev/null; then
  echo "dnf not found — are you on Fedora toolbox?" >&2
  exit 1
fi
if ! sudo -n true 2>/dev/null; then
  warn "sudo may prompt for password. Toolbox usually has passwordless sudo."
fi

# ── package lists (top-level only) ──────────────────────────────────────
# Shell dnf — zsh + CLI tools matching ~/.zshrc aliases (omz/p10k/dotfiles/fonts → setup-host.sh)
SHELL_PKGS=(
  zsh
  git gh meld
  curl wget unzip xz which man-db
  htop btop
  neovim
  powerline powerline-fonts
  fzf zoxide bat lsd
  direnv
  thefuck
  ruby rubygems
)

# Dev core — C/C++/Python native libs. meson/ninja already in ~/.local/bin via uv,
# but dnf copies are harmless and ensure system builds work without venv.
DEV_PKGS=(
  gcc gcc-c++ clang
  cmake ninja-build meson
  pkgconf-pkg-config
  python3-devel python3-pip pipx
  libffi-devel openssl-devel zlib-devel
  fmt-devel spdlog-devel
)
PERF_PKGS=(
  perf strace
)

# Qt — only if ~/Qt SDK not present or --without-qt not set.
# Your SciQLopPlots prefers ~/Qt/6.11.1/gcc_64 (meson needs it on PATH).
QT_PKGS=(
  qt6-qtbase-devel
  qt6-qtsvg-devel
  qt6-qttools-devel
  qt6-qtdeclarative-devel
)

# K8s / containers
K8S_PKGS=(
  podman
  helm
  kubernetes1.34-client
)

# FPGA / embedded
FPGA_PKGS=(
  arm-none-eabi-gcc-cs
  arm-none-eabi-gcc-cs-c++
  arm-none-eabi-newlib
  openocd
  dfu-util
  yosys
)

# ── install ──────────────────────────────────────────────────────────────
log "Toolbx bootstrap — full by default (use --minimal to slim)"
[[ "$DRY_RUN" == true ]] && warn "DRY RUN — no changes will be made"

dnf_install "${SHELL_PKGS[@]}"
dnf_install "${DEV_PKGS[@]}"
if [[ "$WITHOUT_PERF" == true ]]; then
  log "skip perf/strace (--without-perf / --minimal)"
else
  dnf_install "${PERF_PKGS[@]}"
fi

# Qt: skip if ~/Qt SDK exists and not forced, or if --without-qt
if [[ "$WITHOUT_QT" == true ]]; then
  log "skip Qt devel (--without-qt)"
elif [[ -d "$HOME/Qt/6.11.1/gcc_64" ]] || [[ -d "$HOME/Qt/6.10.3/gcc_64" ]]; then
  ok "Qt SDK found in ~/Qt — still installing dnf Qt devel as fallback"
  dnf_install "${QT_PKGS[@]}"
else
  dnf_install "${QT_PKGS[@]}"
fi

if [[ "$WITHOUT_K8S" == true ]]; then
  log "skip k8s (--without-k8s / --minimal)"
else
  dnf_install "${K8S_PKGS[@]}"
fi

if [[ "$WITHOUT_FPGA" == true ]]; then
  log "skip FPGA (--without-fpga / --minimal)"
else
  dnf_install "${FPGA_PKGS[@]}"
fi

# ── home is host-managed — nothing to do here ──────────────────────────
# omz / p10k / plugins / dotfiles / nerdfonts / cargo / nvm are installed
# via setup-host.sh on the HOST (home persists across toolbox resets).
# This script only installs dnf packages inside the container.
if [[ -f "$HOME/.zshrc" ]]; then ok "~/.zshrc present (host-managed)"; else warn "~/.zshrc missing — run setup-host.sh on host"; fi
for bin in uv pixi micromamba meson ninja; do
  if have_cmd "$bin"; then ok "$bin on PATH"; else warn "$bin not on PATH — check ~/.local/bin (host)"; fi
done

# ── summary ──────────────────────────────────────────────────────────────
log "Done."
if [[ "$DRY_RUN" == true ]]; then
  warn "Dry run — rerun without --dry-run to apply"
else
  ok "Re-enter toolbox or run: exec zsh"
  echo ""
  echo "Verify:"
  echo "  zsh --version; omz version 2>/dev/null || echo omz ok"
  echo "  meson --version; ninja --version; cmake --version"
  echo "  kubectl version --client 2>/dev/null || kubernetes1.34-client provides kubectl"
  echo "  arm-none-eabi-gcc --version; yosys -V | head -1"
fi
