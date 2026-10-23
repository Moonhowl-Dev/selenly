#!/usr/bin/env bash
# Checks whether the Selenly development environment is ready.
# It changes nothing, it only reads. For every problem it suggests a fix.
# You can paste the output to whoever is helping you with the setup.
#
# Usage: ./scripts/doctor.sh
# Exit code: 0 = no errors (❌), 1 = there are errors.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
WARN=0
FAIL=0

section() { printf '\n%s\n' "$*"; }
pass() {
  PASS=$((PASS + 1))
  printf '  ✅ %s\n' "$1"
}
warn() {
  WARN=$((WARN + 1))
  printf '  ⚠️  %s\n' "$1"
  if [[ -n "${2:-}" ]]; then printf '      → %s\n' "$2"; fi
}
fail() {
  FAIL=$((FAIL + 1))
  printf '  ❌ %s\n' "$1"
  if [[ -n "${2:-}" ]]; then printf '      → %s\n' "$2"; fi
}
has() { command -v "$1" >/dev/null 2>&1; }

# Expected versions from the files in the repository
EXPECTED_JAVA="$(grep -E '^java=' "$REPO_ROOT/.sdkmanrc" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]')"
EXPECTED_NODE="$(head -1 "$REPO_ROOT/.node-version" 2>/dev/null | tr -d '[:space:]')"

printf 'Selenly doctor · %s\n' "$(date '+%Y-%m-%d %H:%M')"

# ---------------------------------------------------------------------------
section "System"

IS_WSL=0
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=1
  # shellcheck disable=SC1091
  pass "WSL 2 · $(. /etc/os-release && echo "$PRETTY_NAME")"
else
  warn "WSL not detected. Windows-specific checks will be skipped."
fi

case "$REPO_ROOT" in
  /mnt/*)
    fail "The repository is on the Windows drive: $REPO_ROOT" \
      "Clone it into ~/projekty. On /mnt/c, Gradle, pnpm and Vite are several times slower and Vite may miss file changes."
    ;;
  *) pass "Repository on the Linux file system: ${REPO_ROOT/#$HOME/\~}" ;;
esac

if [[ "$(ps -p 1 -o comm= 2>/dev/null)" == "systemd" ]]; then
  pass "systemd is running"
else
  warn "systemd is not running" \
    "Required by Docker Engine (Docker Desktop does not need it). Add a [boot] section with systemd=true to /etc/wsl.conf and run wsl --shutdown."
fi

# ---------------------------------------------------------------------------
section "WSL resources (.wslconfig)"

CPUS="$(nproc)"
MEM_GB="$(awk '/^MemTotal/ {printf "%.0f", $2 / 1024 / 1024}' /proc/meminfo)"

if ((MEM_GB >= 12)); then
  pass "RAM: ${MEM_GB} GB, processors: ${CPUS}"
elif ((MEM_GB >= 7)); then
  warn "RAM: ${MEM_GB} GB, processors: ${CPUS}" \
    "Keycloak, Postgres and tests at the same time may be tight. If the computer has 32 GB, set memory=16GB in .wslconfig."
else
  fail "RAM: ${MEM_GB} GB, processors: ${CPUS}" \
    "Not enough for Keycloak, Postgres and tests at the same time. Increase memory in .wslconfig (template: docs/onboarding/wslconfig.example)."
fi

if ((IS_WSL)); then
  # The Windows user folder (e.g. C:\Users\Jan). "cd /mnt/c" avoids cmd.exe's warning about UNC paths.
  WSLCONFIG=""
  if has cmd.exe && has wslpath; then
    WIN_PROFILE="$(cd /mnt/c 2>/dev/null || true; timeout 10 cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')"
    if [[ -n "$WIN_PROFILE" && "$WIN_PROFILE" != *%USERPROFILE%* ]]; then
      WSLCONFIG="$(wslpath -u "$WIN_PROFILE" 2>/dev/null)/.wslconfig"
    fi
  fi

  if [[ -z "$WSLCONFIG" ]]; then
    warn "Could not read the Windows user folder" \
      "Check the file manually in PowerShell: Get-Content \$env:USERPROFILE\\.wslconfig"
  elif [[ -f "$WSLCONFIG" ]]; then
    # Checked via the processor count, because the default 50% RAM often equals the configured value.
    CFG_CPUS="$(tr -d '\r' <"$WSLCONFIG" | grep -E '^[[:space:]]*processors[[:space:]]*=' | tail -1 |
      cut -d= -f2 | sed 's/#.*//' | tr -d '[:space:]')"
    if [[ -n "$CFG_CPUS" && "$CFG_CPUS" != "$CPUS" ]]; then
      fail ".wslconfig has processors=$CFG_CPUS, but nproc shows $CPUS: the file was not loaded" \
        "Quit Docker Desktop, run wsl --shutdown in PowerShell, wait 10 s and open Ubuntu again."
    else
      pass ".wslconfig is present and loaded"
    fi
  elif [[ -f "${WSLCONFIG}.txt" ]]; then
    fail "Found .wslconfig.txt instead of .wslconfig (Notepad added the extension)" \
      "In PowerShell: Rename-Item \$env:USERPROFILE\\.wslconfig.txt .wslconfig, then wsl --shutdown"
  else
    warn "No .wslconfig: WSL uses the default settings" "Template: docs/onboarding/wslconfig.example"
  fi
fi

# ---------------------------------------------------------------------------
section "Git and GitHub"

if has git; then
  pass "git $(git --version | awk '{print $3}')"

  name="$(git config --global user.name)"
  email="$(git config --global user.email)"
  if [[ -z "$name" || -z "$email" ]]; then
    fail "user.name or user.email is missing in the Git config" \
      "git config --global user.name \"Your Name\" && git config --global user.email \"<noreply address from github.com/settings/emails>\""
  elif [[ "$email" == *@users.noreply.github.com ]]; then
    pass "Commit author: $name <$email>"
  else
    warn "Commit author: $name <$email>" \
      "The repository is public, so everyone will see this email. Consider the noreply address from github.com/settings/emails."
  fi

  if [[ "$(git config --get core.autocrlf)" == "true" ]]; then
    fail "core.autocrlf=true" \
      "In WSL turn it off: git config --global core.autocrlf false. Line endings are handled by .gitattributes."
  fi

  if [[ -f "$REPO_ROOT/lefthook.yml" ]]; then
    hooks_dir="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-path hooks 2>/dev/null)"
    if grep -qs lefthook "$hooks_dir/pre-commit"; then
      pass "Git hooks installed (lefthook): formatting runs before every commit"
    else
      warn "Git hooks are not installed: commits will not be formatted automatically" \
        "cd frontend && pnpm install (it runs lefthook install), or: cd frontend && pnpm exec lefthook install"
    fi
  fi

  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Files whose working copy has CRLF although it should be LF (.bat and .cmd are skipped).
    crlf_files="$(git -C "$REPO_ROOT" ls-files --eol 2>/dev/null |
      awk -F'\t' '$1 ~ /w\/(crlf|mixed)/ && $2 !~ /\.(bat|cmd)$/ {print $2}' | head -5)"
    if [[ -n "$crlf_files" ]]; then
      fail "Files with CRLF line endings: $(echo "$crlf_files" | paste -sd ' ')" \
        "A Windows tool saved them. Fix each one: sed -i 's/\\r\$//' <file>"
    else
      pass "Line endings in the repository: LF"
    fi
  fi
else
  fail "git is missing" "sudo apt install -y git"
fi

if compgen -G "$HOME/.ssh/id_*.pub" >/dev/null; then
  pass "SSH key: $(compgen -G "$HOME/.ssh/id_*.pub" | head -1 | sed "s|^$HOME|~|")"
else
  fail "No SSH key in ~/.ssh" "ssh-keygen -t ed25519 -C \"$(whoami) WSL\" (step 5 of the onboarding guide)"
fi

# -n: ssh does not read stdin; BatchMode: it never prompts, it just fails.
ssh_out="$(timeout 15 ssh -n -T -o BatchMode=yes -o ConnectTimeout=8 git@github.com 2>&1)"
if [[ "$ssh_out" == *"successfully authenticated"* ]]; then
  pass "GitHub over SSH: $(echo "$ssh_out" | grep -o 'Hi [^!]*' | sed 's/^Hi //')"
elif [[ "$ssh_out" == *"Host key verification failed"* ]]; then
  warn "GitHub is not in ~/.ssh/known_hosts yet" \
    "Connect once manually (ssh -T git@github.com) and compare the key fingerprint with docs/onboarding/windows-wsl.md, step 5."
else
  warn "Could not connect to GitHub over SSH" \
    "The key may be locked with a passphrase (open a new tab, keychain will ask) or not added to GitHub (gh ssh-key list)."
fi

if has gh; then
  ghv="$(gh --version | head -1 | awk '{print $3}')"
  case "$ghv" in
    2.45.* | 2.46.*)
      fail "gh $ghv from the Ubuntu repository: this version does not work correctly with the GitHub API" \
        "sudo apt remove gh, then ./scripts/setup-wsl.sh (installs the official version)"
      ;;
    *) pass "gh $ghv" ;;
  esac

  if timeout 15 gh auth status >/dev/null 2>&1; then
    pass "gh is logged in"
    perm="$(cd "$REPO_ROOT" && timeout 15 gh repo view --json viewerPermission -q .viewerPermission 2>/dev/null)"
    case "$perm" in
      ADMIN | MAINTAIN | WRITE) pass "Repository permission: $perm" ;;
      READ | TRIAGE)
        warn "Repository permission: $perm (no write access)" \
          "Ask the organization owner for write access."
        ;;
      *) ;;
    esac
  else
    fail "gh is not logged in" "gh auth login (GitHub.com → SSH → Login with a web browser)"
  fi
else
  fail "GitHub CLI (gh) is missing" "./scripts/setup-wsl.sh"
fi

# ---------------------------------------------------------------------------
section "Project tools"

if has java; then
  # grep instead of head -1: with JAVA_TOOL_OPTIONS set, the first line is "Picked up ...".
  jv="$(java -version 2>&1 | grep -m1 'version "' | sed -E 's/.*version "([^"]+)".*/\1/')"
  want="${EXPECTED_JAVA%%-*}"
  if [[ -z "$want" ]]; then
    pass "Java $jv"
  elif [[ "$jv" == "$want" ]]; then
    pass "Java $jv (matches .sdkmanrc)"
  elif [[ "${jv%%.*}" == "${want%%.*}" ]]; then
    warn "Java $jv, but .sdkmanrc requires $EXPECTED_JAVA" "In the repository folder: sdk env install"
  else
    fail "Java $jv, but the project requires $EXPECTED_JAVA" "In the repository folder: sdk env install (or ./scripts/setup-wsl.sh)"
  fi
else
  fail "Java is missing" "./scripts/setup-wsl.sh"
fi

if has node; then
  nv="$(node -v | sed 's/^v//')"
  if [[ -z "$EXPECTED_NODE" || "$nv" == "$EXPECTED_NODE" || "$nv" == "$EXPECTED_NODE".* ]]; then
    pass "Node $nv"
  else
    fail "Node $nv, but .node-version requires $EXPECTED_NODE" "In the repository folder: fnm use --install-if-missing"
  fi
else
  fail "Node is missing" "./scripts/setup-wsl.sh"
fi

if has pnpm; then
  pass "pnpm $(pnpm -v 2>/dev/null)"
else
  fail "pnpm is missing" "npm install -g pnpm"
fi

# ---------------------------------------------------------------------------
section "Docker"

if ! has docker; then
  fail "The docker command is missing" \
    "Choose Docker Desktop with WSL integration or Docker Engine: docs/onboarding/windows-wsl.md, step 3."
else
  dinfo="$(timeout 20 docker info --format '{{.OperatingSystem}}|{{.ServerVersion}}' 2>&1)"
  drc=$?
  is_desktop=0
  if [[ $drc -eq 0 ]]; then
    dos="${dinfo%%|*}"
    dver="${dinfo##*|}"
    [[ "$dos" == *"Docker Desktop"* ]] && is_desktop=1
    pass "Docker $dver · $dos"
  elif [[ "$dinfo" == *"permission denied"* ]]; then
    fail "No permission to use Docker" \
      "sudo usermod -aG docker \$USER, then run wsl --shutdown in PowerShell and open Ubuntu again"
  else
    fail "Docker does not respond" \
      "Docker Desktop: start the app and check Settings → Resources → WSL Integration. Docker Engine: sudo systemctl status docker"
  fi

  if docker compose version >/dev/null 2>&1; then
    pass "$(docker compose version | head -1)"
  else
    fail "docker compose is missing" "Docker Desktop includes it. Docker Engine: sudo apt install docker-compose-plugin"
  fi

  if [[ $drc -eq 0 && $is_desktop -eq 0 ]] && grep -q 'desktop\.exe' "$HOME/.docker/config.json" 2>/dev/null; then
    # shellcheck disable=SC2088  # the tilde is meant as literal text in the message
    fail "~/.docker/config.json points to Docker Desktop (credsStore desktop.exe), but Docker Engine is running" \
      "mv ~/.docker ~/.docker-old-desktop (otherwise docker pull fails with a missing docker-credential-desktop.exe)"
  fi
fi

# ---------------------------------------------------------------------------
section "AI agent"

if has claude; then
  pass "Claude Code $(timeout 10 claude --version 2>/dev/null | awk '{print $1}')"
else
  warn "Claude Code is not installed (optional)" "curl -fsSL https://claude.ai/install.sh | bash"
fi

# ---------------------------------------------------------------------------
printf '\nResult: %d ✅  %d ⚠️  %d ❌\n' "$PASS" "$WARN" "$FAIL"
if ((FAIL > 0)); then
  echo "Fix the items marked ❌ (hints are below each one) and run again."
  exit 1
elif ((WARN > 0)); then
  echo "The environment works. Items marked ⚠️ are worth a look."
else
  echo "All set."
fi
