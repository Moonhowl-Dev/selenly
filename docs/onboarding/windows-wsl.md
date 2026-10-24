# Onboarding: development environment on Windows (WSL 2)

This guide takes you from a clean Windows machine to a working Selenly environment. It takes about an hour, mostly spent waiting for downloads.

**The rule:** code, JDK, Node, Docker and the AI agent all run in Ubuntu on WSL 2. Windows only provides the editor and the browser. Keep the repository on the Linux file system (`~/projekty/selenly`), **never** on `/mnt/c`.

Up to date as of October 2026. If something stopped working, check [Known pitfalls](#known-pitfalls) and fix this guide in a PR.

## Fast track

For people who already know WSL. Every step is described in detail below.

1. WSL 2 + Ubuntu, `.wslconfig` based on [wslconfig.example](wslconfig.example).
2. Docker: Docker Desktop with WSL integration **or** Docker Engine in Ubuntu, never both.
3. Tools with one command in Ubuntu:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Moonhowl-Dev/selenly/main/scripts/setup-wsl.sh | bash
   ```
4. Git identity, SSH key, `gh auth login`.
5. Repository and check:
   ```bash
   gh repo clone Moonhowl-Dev/selenly ~/projekty/selenly
   cd ~/projekty/selenly && (cd frontend && pnpm install) && ./scripts/doctor.sh
   ```

## Before you start: reading the commands

- **Two terminals.** Some commands go into **PowerShell** (the line starts with `PS C:\Users\...>`), others into **Ubuntu** (the line looks like `jan@laptop:~$`). Each block says which one. The **Terminal** app (Windows Terminal) is the easiest, because it has tabs for both.
- **Pasting:** `Ctrl+Shift+V` or right-click. When pasting several lines, Terminal asks for confirmation.
- **`sudo`** runs a command as the Linux administrator and asks for your password. The password is **not shown** while you type, not even as asterisks. That is normal.
- **`~`** is your home folder in Linux, i.e. `/home/your_name`.

## 0. Requirements

- Windows 11, or Windows 10 22H2 with current security updates.
- Virtualization enabled: Task Manager → Performance → CPU → **Virtualization: Enabled**. If it is disabled, enable Intel VT-x or AMD SVM in the BIOS/UEFI.
- At least 16 GB of RAM, 32 GB is comfortable.
- A GitHub account with access to the **Moonhowl-Dev** organization (ask the owner for an invitation).
- Optional: a Claude Pro/Max plan or an API key, if you want to use Claude Code.

Write down your Windows version (`Win+R` → `winver`) and the amount of RAM and logical processors from Task Manager. You will need them in step 2.

## 1. WSL 2 and Ubuntu

In PowerShell **run as administrator**, check whether WSL is already installed:

```powershell
wsl -l -v
```

If the list shows `Ubuntu` with `2` in the VERSION column, skip to `wsl --update`. Otherwise install it:

```powershell
wsl --install -d Ubuntu
wsl --update
```

If Windows asks for a restart, do it. On first launch Ubuntu asks for a user name (lowercase, no spaces, no special characters) and a password. This password is only for this Linux, not for Windows.

Then update the packages in Ubuntu:

```bash
sudo apt update && sudo apt upgrade -y
```

**Check:** in PowerShell, `wsl -l -v` shows `Ubuntu` with `2`, and `wsl --version` prints the WSL version. If `wsl --version` fails, you have an old WSL: run `wsl --update`.

If the list contains old distributions, read [Known pitfalls](#known-pitfalls) before you remove anything.

## 2. `.wslconfig`: how many resources Linux gets

WSL 2 is a virtual machine. The `.wslconfig` file on the Windows side sets how much RAM and how many processors it may use. The limit covers all of WSL, including Docker Desktop containers.

1. In PowerShell (normal, not as administrator):
   ```powershell
   notepad $env:USERPROFILE\.wslconfig
   ```
   When asked whether to create the file, answer **Yes**.
2. Paste the content of [wslconfig.example](wslconfig.example) and adjust the values:

   | RAM in the computer | `memory=` |
   |---|---|
   | 16 GB | `8GB` |
   | 32 GB | `16GB` |
   | 64 GB | `24GB` |

   `processors=`: with 12 or more logical processors use `8`; with fewer, use your count minus 2.

   **Windows 11 22H2+:** you can enable the `networkingMode=mirrored` line (remove the `#`). **Windows 10:** leave it disabled, because this mode does not work there. `localhost` between Windows and WSL works without it.
3. Save (`Ctrl+S`). Quit Docker Desktop if it is running. In PowerShell:
   ```powershell
   wsl --shutdown
   ```
   Wait about 10 seconds and open Ubuntu.

**Check:** in Ubuntu, `nproc` shows the value of `processors=`. Do not check with `free -h`: the default 50% of RAM often equals the configured value, so that test proves nothing.

## 3. Docker: pick one option

| | A. Docker Desktop with WSL integration | B. Docker Engine in Ubuntu |
|---|---|---|
| When | you also use Docker for projects on Windows | you only need Docker in WSL |
| Pros | GUI, one Docker for all your projects | lighter, same setup as CI and the server |
| Cons | heavier; the app must be running | no GUI |
| License | free for personal use and small businesses | open source |

**Never install both.** The Docker documentation explicitly advises against Docker Engine in a WSL distribution next to Docker Desktop, because the two engines get in each other's way.

### A. Docker Desktop

1. Install or update Docker Desktop: in PowerShell, `winget install Docker.DockerDesktop` (or `winget upgrade Docker.DockerDesktop`).
2. Start Docker Desktop. In **Settings → General**, check **Use WSL 2 based engine** (on newer systems it is on by default and may be hidden).
3. In **Settings → Resources → WSL Integration**, enable integration with the default distribution and the toggle next to **Ubuntu**. Click **Apply & restart**. If there is no WSL Integration tab, right-click the whale icon and choose **Switch to Linux containers**.
4. Optional: in **General**, check **Start Docker Desktop when you sign in to your computer**. Without a running Docker Desktop, `docker` does not work in Ubuntu.

**Check** in a new Ubuntu tab: `which docker` shows a Linux path (usually `/usr/bin/docker`, not `/mnt/c/...`), and `docker run --rm hello-world` prints "Hello from Docker!".

### B. Docker Engine in Ubuntu

Commands from the official Docker documentation (https://docs.docker.com/engine/install/ubuntu/). First remove any unofficial packages:

```bash
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc | cut -f1)
```

Add the Docker repository and install:

```bash
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Docker without `sudo` (membership in the `docker` group effectively gives administrator rights in this Linux):

```bash
sudo usermod -aG docker $USER
```

Then run `wsl --shutdown` in PowerShell and open Ubuntu again.

**Check:** `docker run --rm hello-world` without `sudo`, and `docker compose version`. Docker Engine needs systemd (`ps -p 1 -o comm=` returns `systemd`).

## 4. Tools: one script

[`scripts/setup-wsl.sh`](../../scripts/setup-wsl.sh) installs:

- **Java** via SDKMAN, in the version from [`.sdkmanrc`](../../.sdkmanrc),
- **Node** via fnm, in the version from [`.node-version`](../../.node-version), plus **pnpm**,
- **GitHub CLI** (`gh`) from the official repository,
- **Claude Code** (skip it with `--no-claude`),
- helper packages: `git`, `curl`, `zip`, `unzip`, `keychain`.

You can run the script as many times as you like: it skips whatever is already installed. It also adds one block marked `selenly dev env` to `~/.bashrc`, so fnm switches the Node version automatically when you enter the repository folder.

Before cloning the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/Moonhowl-Dev/selenly/main/scripts/setup-wsl.sh | bash
```

From the repository:

```bash
./scripts/setup-wsl.sh
```

A good habit: before piping anything into `bash`, open the URL in a browser and read what the script does.

When it finishes, open a new terminal tab so the `PATH` changes take effect.

## 5. Git, SSH key and GitHub

The script does not do these steps, because they need you.

### Git

The repository is public, so everyone can see the email address in every commit. Use GitHub's private address: go to **github.com/settings/emails**, check **Keep my email addresses private** and copy the address that looks like `12345678+login@users.noreply.github.com`.

```bash
git config --global user.name "Your Name"
git config --global user.email "12345678+login@users.noreply.github.com"
git config --global init.defaultBranch main
git config --global core.editor nano
```

`core.editor nano` makes Git open a simple editor instead of vim. If you ever get stuck in vim anyway: `Esc`, then `:q!` and Enter.

### SSH key

```bash
ssh-keygen -t ed25519 -C "$(whoami) WSL"
```

Keep the default location (Enter). Set a passphrase: the private key ends up in every copy of the system (e.g. `wsl --export`), and with a passphrase such a copy is useless to anyone else. To avoid typing it on every `git push`, add `keychain` (installed by the script in step 4):

```bash
echo 'eval "$(keychain --eval --quiet id_ed25519)"' >> ~/.bashrc
source ~/.bashrc
```

Keychain asks for the passphrase once after every WSL restart.

The private key (`~/.ssh/id_ed25519`, without `.pub`) **never** leaves your computer: do not paste it into a chat, an issue or the repository.

### Logging in to GitHub

```bash
gh auth login
```

| Question | Answer |
|---|---|
| Where do you use GitHub? | **GitHub.com** |
| Preferred protocol for Git operations? | **SSH** |
| Upload your SSH public key? | **`~/.ssh/id_ed25519.pub`** |
| Title for your SSH key | the computer's name, e.g. **Laptop WSL** |
| How would you like to authenticate? | **Login with a web browser** |

`gh` shows a one-time code. If the browser does not open by itself, go to **github.com/login/device** in your Windows browser and enter the code.

### Testing the connection

```bash
ssh -T git@github.com
```

On the first connection SSH shows the server's key fingerprint. Compare it with GitHub's official Ed25519 fingerprint (https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints):

```
SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
```

Type `yes` only if it matches. A correct reply contains `Hi <login>! You've successfully authenticated`.

## 6. Repository and check

```bash
mkdir -p ~/projekty
gh repo clone Moonhowl-Dev/selenly ~/projekty/selenly
cd ~/projekty/selenly
(cd frontend && pnpm install)
./scripts/doctor.sh
```

`pnpm install` in `frontend/` also installs the Git hooks ([lefthook](../../lefthook.yml)): before every commit, the staged files are formatted and auto-fixed.

[`scripts/doctor.sh`](../../scripts/doctor.sh) changes nothing: it only checks the environment and suggests a fix for every problem. Everything should be ✅. Items marked ⚠️ are worth a look; items marked ❌ must be fixed. If you get stuck, paste the output to whoever is helping you.

## 7. Editors

- **VS Code** (frontend): install the **WSL** extension on Windows, then run `code .` in Ubuntu inside the repository folder. VS Code will offer the extensions from [`.vscode/extensions.json`](../../.vscode/extensions.json), including ESLint and Prettier; they install on the WSL side.
- **IntelliJ IDEA** (backend): open `\\wsl.localhost\Ubuntu\home\<your_name>\projekty\selenly` and point it to the JDK inside WSL (`~/.sdkman/candidates/java/current`). If indexing is slow, use Remote Development to WSL. Install the **palantir-java-format** plugin, so the IDE formats Java exactly like `./gradlew spotlessApply`.
- **Terminal:** make Ubuntu the default profile (Settings → Startup → Default profile). Every new tab then starts in `~`.
- **Browser** stays on Windows: `localhost:5173` (Vite) and `localhost:8080` (Spring) work without extra configuration.
- **Claude Code** (optional): start `claude` in the repository root. The browser and database access for its MCP servers need two one-time steps: [docs/ai-tools.md](../ai-tools.md#setup).

## Daily habits

- When you enter Ubuntu via `wsl -d Ubuntu` from PowerShell, you land in `/mnt/c/...`. Start with `cd ~`.
- With Docker Desktop: the app must be running for `docker` and Testcontainers tests to work.
- After changing `.wslconfig`: quit Docker Desktop → `wsl --shutdown` → start Docker Desktop again.
- Docker Desktop is shared by all your projects. When a port is taken, check `docker ps` and stop the conflicting container with `docker stop <name>`.

## Known pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `nproc` shows all processors despite `.wslconfig` | the file was not loaded: wrong name (`.wslconfig.txt`) or WSL not restarted | `doctor.sh` detects both; `Rename-Item $env:USERPROFILE\.wslconfig.txt .wslconfig`, then `wsl --shutdown` |
| `free -h` "confirms" `.wslconfig` although the file is missing | the default 50% of RAM equals the configured value | check with `nproc` or `doctor.sh` |
| `networkingMode=mirrored` changes nothing | mirrored mode only works on Windows 11 22H2+ | on Windows 10 remove that line |
| Docker Desktop shows an error after `wsl --shutdown` | the Docker Desktop engine runs inside WSL | quit Docker Desktop before `wsl --shutdown`, start it afterwards |
| `docker pull`: `error getting credentials ... docker-credential-desktop.exe` | `~/.docker/config.json` left over from Docker Desktop, but you use Docker Engine | `mv ~/.docker ~/.docker-old-desktop` |
| Conflicts and strange Docker errors | Docker Engine in Ubuntu and Docker Desktop at the same time | pick one option from step 3 |
| Gradle, pnpm and Vite are very slow, Vite misses changes | repository on `/mnt/c` | clone it into `~/projekty` |
| `bad interpreter: /bin/bash^M` | file saved with CRLF (Windows) line endings | `sed -i 's/\r$//' <file>`; `.gitattributes` protects new commits |
| `gh` reports API errors, version 2.45 or 2.46 | `gh` from the Ubuntu repository instead of the official one | `sudo apt remove gh`, then `./scripts/setup-wsl.sh` |
| `command not found` right after installing | the terminal has not loaded the new `PATH` | new tab or `source ~/.bashrc` |
| `wsl -d <name>`: `ERROR_PATH_NOT_FOUND`, `Failed to attach disk` | the distribution's disk was deleted (e.g. the Store app was uninstalled), only the entry remains | run `Test-Path` on the `ext4.vhdx` path from the message; if `False`, `wsl --unregister <name>` |
| Postgres does not start, port 5432 in use | a container from another project on the shared Docker Desktop | `docker ps`, then `docker stop <name>` |
| SSH key passphrase after every restart | keychain keeps the key unlocked until WSL restarts | this is expected |
| Stuck in an editor during `git commit` | vim opened | `Esc`, `:q!`, Enter; then `git config --global core.editor nano` |

**Before you remove anything from WSL** (`wsl --unregister` deletes the distribution with all its files, irreversibly): look inside first (`wsl -d <name>`, then `ls -A ~`), and if in doubt make a backup: `wsl --export <name> C:\wsl-backup\<name>.tar`.

## Changing tool versions

Versions are pinned in the repository, so everyone works with the same ones:

- **Java:** the `java=` line in [`.sdkmanrc`](../../.sdkmanrc). Available versions: `sdk list java | grep -- -tem`. After a change, everyone runs `sdk env install` in the repository folder.
- **Node:** the number in [`.node-version`](../../.node-version). fnm switches automatically when you enter the folder; if the version is missing, `fnm use --install-if-missing`.

Renovate proposes new versions of both in pull requests (see "Dependency updates" in the [README](../../README.md#dependency-updates)). After such a PR is merged, run `sdk env install` or `fnm use --install-if-missing`, then `./scripts/doctor.sh`.
