#!/usr/bin/env bash
# Installs the tools needed to work on Selenly in Ubuntu on WSL 2:
# Java (SDKMAN), Node (fnm), pnpm, GitHub CLI and Claude Code.
#
# Safe to run repeatedly: anything already installed is skipped.
# It deliberately does NOT do the steps that need you: Docker, Git identity,
# SSH key and GitHub login. Those are described in docs/onboarding/windows-wsl.md.
#
# Usage (from the repository):
#   ./scripts/setup-wsl.sh
#   ./scripts/setup-wsl.sh --no-claude      # skip Claude Code
#
# Usage before cloning the repository:
#   curl -fsSL https://raw.githubusercontent.com/Moonhowl-Dev/selenly/main/scripts/setup-wsl.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/Moonhowl-Dev/selenly/main/scripts/setup-wsl.sh | bash -s -- --no-claude

set -eo pipefail

# Defaults used when the script runs outside the repository (e.g. via curl | bash).
# Inside the repository, versions are read from .sdkmanrc and .node-version.
DEFAULT_JAVA_VERSION="25.0.4-tem"
DEFAULT_NODE_VERSION="24"
INSTALL_CLAUDE=1

usage() {
  cat <<'EOF'
Usage: setup-wsl.sh [--no-claude]

Installs Java (SDKMAN), Node (fnm), pnpm, GitHub CLI and Claude Code.
  --no-claude   do not install Claude Code
  -h, --help    show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-claude) INSTALL_CLAUDE=0 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }
ok()   { printf '    ✅ %s\n' "$*"; }
info() { printf '    ·  %s\n' "$*"; }
warn() { printf '    ⚠️  %s\n' "$*"; }
die()  { printf '\n❌ %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

# Where is the repository? With "curl | bash" there is no script file, so no repository either.
REPO_ROOT=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

JAVA_VERSION="$DEFAULT_JAVA_VERSION"
NODE_VERSION="$DEFAULT_NODE_VERSION"
if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/.sdkmanrc" ]]; then
  v="$(grep -E '^java=' "$REPO_ROOT/.sdkmanrc" | head -1 | cut -d= -f2 | tr -d '[:space:]' || true)"
  [[ -n "$v" ]] && JAVA_VERSION="$v"
fi
if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/.node-version" ]]; then
  v="$(head -1 "$REPO_ROOT/.node-version" | tr -d '[:space:]' || true)"
  [[ -n "$v" ]] && NODE_VERSION="$v"
fi

# ---------------------------------------------------------------------------
step "Checking the system"

[[ $EUID -ne 0 ]] || die "Run this script as your normal user, without sudo. It asks for your password when it needs it."

if grep -qi microsoft /proc/version 2>/dev/null; then
  ok "WSL"
else
  warn "WSL not detected. Continuing, but this script is meant for Ubuntu on WSL 2."
fi

# shellcheck source=/dev/null
. /etc/os-release
if [[ "${ID:-}" == "ubuntu" ]]; then
  ok "${PRETTY_NAME:-Ubuntu}"
else
  warn "Detected ${PRETTY_NAME:-an unknown system}. This script was tested on Ubuntu."
fi

if [[ -n "$REPO_ROOT" && "$REPO_ROOT" == /mnt/* ]]; then
  warn "The repository is on the Windows drive ($REPO_ROOT). Move it to ~/projekty; everything is slow on /mnt/c."
fi

info "Java: $JAVA_VERSION, Node: $NODE_VERSION"

# ---------------------------------------------------------------------------
step "System packages (apt)"

info "sudo may ask for your Ubuntu password"
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl wget git zip unzip keychain >/dev/null
ok "curl, wget, git, zip, unzip, keychain"

# ---------------------------------------------------------------------------
step "Configuring ~/.bashrc"

# Added before SDKMAN is installed, because SDKMAN wants its own block at the very end of the file.
BASHRC="$HOME/.bashrc"
if grep -qF "# >>> selenly dev env >>>" "$BASHRC" 2>/dev/null; then
  ok "Selenly block already in ~/.bashrc"
else
  cat >>"$BASHRC" <<'EOF'

# >>> selenly dev env >>>
# Added by scripts/setup-wsl.sh: programs in ~/.local/bin (e.g. Claude Code) and fnm.
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$PATH"
if command -v fnm >/dev/null 2>&1; then
  # --use-on-cd: fnm switches the Node version when you enter a folder with a .node-version file.
  eval "$(fnm env --use-on-cd --shell bash)"
fi
# <<< selenly dev env <<<
EOF
  ok "added the Selenly block to ~/.bashrc"
fi
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$PATH"

# ---------------------------------------------------------------------------
step "Java $JAVA_VERSION (SDKMAN)"

export SDKMAN_DIR="$HOME/.sdkman"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  ok "SDKMAN already installed"
else
  info "installing SDKMAN"
  curl -fsSL "https://get.sdkman.io" | bash >/dev/null
  ok "installed SDKMAN"
fi

# SDKMAN's scripts are not written for "set -e", so it is turned off while they run.
set +e
# shellcheck source=/dev/null
source "$SDKMAN_DIR/bin/sdkman-init.sh"
# No "set as default?" prompts (with "curl | bash" there is nobody to answer them).
# shellcheck disable=SC2034  # read by the sdk function
sdkman_auto_answer=true

if [[ -d "$SDKMAN_DIR/candidates/java/$JAVA_VERSION" ]]; then
  ok "Java $JAVA_VERSION already installed"
else
  info "installing Java $JAVA_VERSION"
  sdk install java "$JAVA_VERSION"
  if [[ ! -d "$SDKMAN_DIR/candidates/java/$JAVA_VERSION" ]]; then
    die "Could not install Java $JAVA_VERSION. If 'sdk list java | grep -- -tem' no longer lists it, update .sdkmanrc (see docs/onboarding/windows-wsl.md)."
  fi
  ok "installed Java $JAVA_VERSION"
fi
sdk default java "$JAVA_VERSION" >/dev/null
set -e

# ---------------------------------------------------------------------------
step "Node $NODE_VERSION (fnm) and pnpm"

if has fnm; then
  ok "fnm already installed"
else
  info "installing fnm"
  # --skip-shell: fnm does not edit ~/.bashrc, because the Selenly block above does.
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell >/dev/null
  has fnm || die "fnm is not available after installation (expected in ~/.local/share/fnm)."
  ok "installed fnm"
fi

eval "$(fnm env --shell bash)"
fnm use --install-if-missing "$NODE_VERSION" >/dev/null
fnm default "$(node -v)" >/dev/null
ok "Node $(node -v) (default version)"

if has pnpm; then
  ok "pnpm $(pnpm -v) already installed"
else
  npm install -g pnpm >/dev/null
  ok "installed pnpm $(pnpm -v)"
fi

# ---------------------------------------------------------------------------
step "GitHub CLI (gh)"

if has gh; then
  ghv="$(gh --version | head -1 | awk '{print $3}')"
  case "$ghv" in
    2.45.* | 2.46.*)
      warn "gh $ghv comes from the Ubuntu repository and does not work correctly with the GitHub API."
      warn "Remove it (sudo apt remove gh) and run this script again."
      ;;
    *) ok "gh $ghv already installed" ;;
  esac
else
  # The official GitHub CLI apt repository (cli.github.com), not the Ubuntu package.
  info "adding the official GitHub CLI repository"
  sudo mkdir -p -m 755 /etc/apt/keyrings
  tmp="$(mktemp)"
  wget -nv -O "$tmp" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  # shellcheck disable=SC2024  # the temp file is ours; sudo is only needed to write the target
  sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg <"$tmp" >/dev/null
  rm -f "$tmp"
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  sudo mkdir -p -m 755 /etc/apt/sources.list.d
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq gh >/dev/null
  ok "installed $(gh --version | head -1)"
fi

# ---------------------------------------------------------------------------
if [[ $INSTALL_CLAUDE -eq 1 ]]; then
  step "Claude Code"
  if has claude; then
    ok "Claude Code $(claude --version 2>/dev/null | awk '{print $1}') already installed (it updates itself)"
  else
    info "installing Claude Code (requires a Claude Pro/Max plan or an API key)"
    curl -fsSL https://claude.ai/install.sh | bash
    ok "installed Claude Code"
  fi
fi

# ---------------------------------------------------------------------------
step "Docker (check only, this script does not install it)"

if has docker && timeout 20 docker info >/dev/null 2>&1; then
  ok "Docker responds"
else
  warn "Docker is not working in this Ubuntu. Pick one of the two options: docs/onboarding/windows-wsl.md, step 3."
fi

# ---------------------------------------------------------------------------
step "Done"

cat <<'EOF'
    This script deliberately skips the steps that need you:
      1. Docker: Docker Desktop with WSL integration, or Docker Engine (step 3)
      2. Git: name and email, ideally the noreply address from github.com/settings/emails (step 5)
      3. SSH key and GitHub login: ssh-keygen, gh auth login (step 5)

    Open a new terminal tab (or run: source ~/.bashrc) so the PATH changes take effect.
EOF

if [[ -n "$REPO_ROOT" && -x "$REPO_ROOT/scripts/doctor.sh" ]]; then
  printf '\nRunning the environment check...\n'
  "$REPO_ROOT/scripts/doctor.sh" </dev/null || true
else
  printf '\n    After cloning the repository, run: ./scripts/doctor.sh\n'
fi
