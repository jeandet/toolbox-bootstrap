# toolbox-bootstrap

One-shot cozy env bootstrap for Fedora Toolbox (Silverblue).

Home (`~`) survives `toolbox create` — the container rootfs does not. This script restores the container side in one go.

## Quick start

```bash
# New Fedora box
toolbox create --distro fedora --release 43   # or 44
toolbox enter

# Inside the box
~/Documents/prog/toolbox-bootstrap/setup-toolbox.sh
exec zsh
```

## Modes

| Command | What it does |
|---------|--------------|
| `setup-toolbox.sh` | **Full by default** — shell + dev + Qt + k8s + FPGA + perf |
| `setup-toolbox.sh --minimal` | Shell cozy only (zsh/omz/p10k, fzf/zoxide/bat/lsd, etc.) |
| `setup-toolbox.sh --without-k8s` | Full minus podman/helm/kubectl |
| `setup-toolbox.sh --without-fpga` | Full minus ARM/FPGA toolchain |
| `setup-toolbox.sh --without-qt` | Skip Qt6 devel (uses `~/Qt` SDK if present) |
| `setup-toolbox.sh --dry-run` | Print what would run, no changes |
| `setup-toolbox.sh --update-toolchains` | Also `rustup update` + git pull oh-my-zsh/p10k |

Re-runnable — safe to run twice. Flags compose (e.g. `--without-k8s --without-fpga`).

## What it installs

Top-level packages only — `dnf` pulls deps, stays robust across releases.

- **Shell cozy**: `zsh`, `fzf`, `zoxide`, `bat`, `lsd`, `thefuck`, `powerline`, `direnv`, `neovim`, `htop`/`btop`, `gh`/`meld`, `ruby` + `gem:colorls`
- **Dev core**: `gcc`/`gcc-c++`/`clang`, `cmake`/`meson`/`ninja`, `python3-devel`/`pipx`, `fmt`/`spdlog`, `perf`/`strace`
- **Qt6** (fallback if `~/Qt/6.11.1/gcc_64` missing): `qt6-qtbase/svg/tools/declarative-devel`
- **K8s**: `podman`, `helm`, `kubernetes1.34-client` (provides `kubectl`)
- **FPGA**: `arm-none-eabi-gcc-cs` (+c++, newlib), `openocd`, `dfu-util`, `yosys`

Shell layer: clones/updates `oh-my-zsh`, `powerlevel10k`, `zsh-autosuggestions`, `zsh-syntax-highlighting` into `~/.oh-my-zsh/custom`. Your `~/.zshrc` + `~/.p10k.zsh` already persist in home — script never overwrites them.

Home-persisted toolchains (`~/.cargo`, `~/.nvm`, `~/.local/bin/{uv,pixi,micromamba,meson,ninja}`) are verified, not reinstalled, unless missing.

## Verify

```bash
zsh --version
meson --version; ninja --version; cmake --version
kubectl version --client 2>/dev/null || kubectl --help | head -1
arm-none-eabi-gcc --version; yosys -V | head -1
```

## Updating

```bash
git -C ~/Documents/prog/toolbox-bootstrap pull
~/Documents/prog/toolbox-bootstrap/setup-toolbox.sh --update-toolchains
```
