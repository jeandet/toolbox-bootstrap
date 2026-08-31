# toolbox-bootstrap

Cozy env for Fedora Silverblue + Toolbox.

`~` survives `toolbox create` — the container rootfs does not. Two scripts split along that boundary:

- **`setup-host.sh`** — host, `~`-shared, via **GitHub** (dotfiles, oh-my-zsh, p10k, nerd fonts). Run once per machine.
- **`setup-toolbox.sh`** — container, **dnf** only (zsh + dev + qt + k8s + fpga). Run inside each new toolbox.

No distrobox, no hotspot.

## Quick start — new machine

```bash
git clone https://github.com/jeandet/toolbox-bootstrap ~/Documents/prog/toolbox-bootstrap

# 1) Host — dotfiles + omz/p10k + MesloLGS NF (GitHub)
~/Documents/prog/toolbox-bootstrap/setup-host.sh
exec zsh   # or open new terminal; set terminal font to "MesloLGS NF"

# 2) Toolbox — dnf packages
toolbox create --distro fedora --release 43
toolbox enter
~/Documents/prog/toolbox-bootstrap/setup-toolbox.sh   # full by default
exec zsh
```

## setup-host.sh (host, GitHub)

```bash
setup-host.sh                  # install dotfiles + omz/p10k/plugins + MesloLGS NF
setup-host.sh --dry-run        # preview
setup-host.sh --without-fonts  # skip fonts
setup-host.sh --update         # git pull omz/p10k + refresh fonts
```

Installs:

- **dotfiles** `dotfiles/.zshrc` → `~/.zshrc`, `dotfiles/.p10k.zsh` → `~/.p10k.zsh`, `dotfiles/.zshenv` → `~/.zshenv` (backs up originals to `*.pre-toolbox-bootstrap`)
- **oh-my-zsh** `ohmyzsh/ohmyzsh` → `~/.oh-my-zsh`
- **powerlevel10k** `romkatv/powerlevel10k` → `~/.oh-my-zsh/custom/themes/powerlevel10k` (also handles legacy `~/.oh-my-zsh/themes/powerlevel10k`)
- **plugins** `zsh-autosuggestions`, `zsh-syntax-highlighting` → `~/.oh-my-zsh/custom/plugins/`
- **nerd fonts** MesloLGS NF (4 variants, p10k-recommended) via `romkatv/powerlevel10k-media` → `~/.local/share/fonts` + `fc-cache -f`

Re-runnable, previews with `--dry-run`, refuses to be confused with the toolbox.

## setup-toolbox.sh (container, dnf)

```bash
setup-toolbox.sh                         # full by default
setup-toolbox.sh --minimal               # shell dnf only (zsh + fzf/zoxide/bat/lsd/…)
setup-toolbox.sh --without-k8s           # minus podman/helm/kubectl
setup-toolbox.sh --without-fpga          # minus ARM/FPGA
setup-toolbox.sh --without-qt            # skip Qt6 devel (uses ~/Qt SDK if present)
setup-toolbox.sh --without-perf          # skip perf/strace
setup-toolbox.sh --dry-run               # preview dnf transactions
setup-toolbox.sh --update-toolchains     # (reserved)
```

Top-level dnf only — deps pulled automatically, robust across releases:

- **Shell dnf**: `zsh`, `fzf`, `zoxide`, `bat`, `lsd`, `thefuck`, `powerline`, `direnv`, `neovim`, `htop`/`btop`, `gh`/`meld`, `ruby`
- **Dev**: `gcc`/`clang`, `cmake`/`meson`/`ninja`, `python3-devel`/`pipx`, `fmt`/`spdlog`, `perf`/`strace`
- **Qt6** (fallback if `~/Qt` missing): `qt6-qtbase/svg/tools/declarative-devel`
- **K8s**: `podman`, `helm`, `kubernetes1.34-client`
- **FPGA**: `arm-none-eabi-gcc-cs` (+c++, newlib), `openocd`, `dfu-util`, `yosys`

Re-runnable. Toolbox-aware (warns if run outside container).

## Dotfiles

Bundled in `dotfiles/`:

- `.zshrc` — sanitized from your current config (`$HOME`-portable, guarded completions, `lsd`→`colorls` fallback)
- `.p10k.zsh` — p10k rainbow (nerdfont-complete)
- `.zshenv` — `. "$HOME/.cargo/env"`

Edit them in-repo; `setup-host.sh` will deploy on next run.

## Verify

```bash
zsh --version; echo $ZSH_THEME
meson --version; ninja --version; cmake --version
kubectl version --client 2>/dev/null || kubectl --help | head -1
arm-none-eabi-gcc --version; yosys -V | head -1
fc-list | grep -i meslo | head
```

## Updating

```bash
git -C ~/Documents/prog/toolbox-bootstrap pull
~/Documents/prog/toolbox-bootstrap/setup-host.sh --update
~/Documents/prog/toolbox-bootstrap/setup-toolbox.sh
```
