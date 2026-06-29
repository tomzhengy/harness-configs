# harness-configs

claude code and codex cli config files. please feel free to add suggestions!! i enjoy optimizing my agent workflows.

## claude code features

- **granular bash permissions** - read-only commands auto-allowed, write commands (git add/commit/merge/checkout/worktree) explicitly permitted
- **sound notifications** - async ping on permission prompts, idle prompts, auth, elicitations, and plan mode responses; glass sound when done
- **auto-formatting** - biome runs automatically when a project has biome config; otherwise prettier runs
- **auto-linting** - bun lint runs automatically after file changes
- **git worktree workflow** - auto-creates worktrees for non-trivial tasks to isolate branches across sessions
- **behavioral guardrails** - assumption surfacing, confusion management, change summaries
- **systems-first design** - iterates on system design before writing code
- **nia research rules** - integrated nia mcp for external code/docs research and indexing
- **custom statusline** - git branch, model, and context info

## codex harness features

- **instruction parity** - codex `AGENTS.md` mirrors the current claude workflow rules: bun-first js/ts, assumption surfacing, worktree workflow, post-edit checks, and nia-first research
- **broad command rules** - codex `rules/default.rules` mirrors the current claude command-family allowlist rather than the older tighter readme wording
- **hook parity** - codex `hooks.json` ports worktree exposure, permission/stop sounds, and post-edit format/lint hooks using codex's native hook system
- **portable mcp startup** - codex mcp config uses `bunx` for github, `uvx` for nia, and documented env forwarding instead of hard-coded local binary paths
- **skill-based workflow ports** - local skills cover planning, commit messages, worktree merges, code review, and nia research
- **strict review skill** - codex includes the thermo-nuclear code quality review skill from the claude setup as an explicit/manual skill
- **explicit native gaps** - codex does not currently replicate claude's custom statusline scripting, transcript scroll keybinding, or claude-only plugin marketplace entries in this repo

## installation

### quick install (30 seconds)

open claude code and paste this:

```
Install harness-configs: run git clone --depth 1 https://github.com/tomzhengy/harness-configs.git ~/.claude/skills/_harness-configs && cd ~/.claude/skills/_harness-configs && ./setup.sh
```

claude will clone the repo and run the setup script. the script merges settings into your existing config (additive only, never removes your settings), appends CLAUDE.md instructions, and copies rules and skills into place. existing files are backed up before modification.

requires `jq` (`brew install jq` on macOS, `sudo apt-get install jq` on linux).

### manual install

```bash
git clone https://github.com/tomzhengy/harness-configs.git
cd harness-configs
./setup.sh
```

### for repo authors

use `--link` to create symlinks instead of copies, so edits flow back to the repo:

```bash
./setup.sh --link
```

### updating

pull the latest changes and re-run setup. the script is idempotent:

```bash
cd ~/.claude/skills/_harness-configs  # or wherever you cloned
git pull
./setup.sh
```

### environment variables

copy `.env.example` to `.env`, add your api keys, then load it in your shell:

```bash
cp .env.example .env
# edit .env with your keys
set -a
source .env
set +a
```

### mcp servers

use `claude-code/config/mcp.json` as a reference template and merge those entries into `~/.claude.json` with your API keys. the gpu bootstrap script handles this merge automatically.

### cursor mcp servers

use `cursor/mcp.json` as a reference template and merge those entries into `~/.cursor/mcp.json` with your API keys (github + nia, the same two servers as the claude config). cursor does not expand `${VAR}` placeholders, so replace them with real values in the live file:

```bash
# edit ~/.cursor/mcp.json and add the github + nia entries from cursor/mcp.json,
# substituting your GITHUB_PERSONAL_ACCESS_TOKEN and NIA_API_KEY
```

restart cursor (or reload mcp servers in settings) after editing.

### cursor cli permissions

`cursor/cli-config.json` is a reference template that grants the cursor cli (cursor-agent) full permissions: every shell command, read, write, web fetch, and mcp tool is auto-allowed with an empty deny list. copy it to `~/.cursor/cli-config.json` (global config):

```bash
cp cursor/cli-config.json ~/.cursor/cli-config.json
```

note: this is the persistent equivalent of running with `--force` / `--yolo`. only the cursor cli reads `cli-config.json`; the cursor ide app has its own auto-run setting in the app settings ui.

### codex cli setup

from the `harness-configs` directory, run:

```bash
./codex/setup.sh --link
```

copy mode is the default if you do not want symlinks:

```bash
./codex/setup.sh
```

the script installs codex config, global instructions, rules, and hooks under
`CODEX_HOME` (default `~/.codex`). skills are installed under the current
documented user-skill path, `~/.agents/skills`. if your local codex build still
loads personal skills from `~/.codex/skills`, override the target:

```bash
CODEX_SKILLS_DIR="$HOME/.codex/skills" ./codex/setup.sh --link
```

manual symlink equivalent:

```bash
mkdir -p ~/.codex
mkdir -p ~/.agents/skills
ln -sf $(pwd)/codex/config.toml ~/.codex/config.toml
ln -sf $(pwd)/codex/AGENTS.md ~/.codex/AGENTS.md
ln -sf $(pwd)/codex/instructions.md ~/.codex/instructions.md
ln -sf $(pwd)/codex/hooks.json ~/.codex/hooks.json
ln -sfn $(pwd)/codex/rules ~/.codex/rules
ln -sfn $(pwd)/codex/hooks ~/.codex/hooks
for skill in codex/skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.agents/skills/"$(basename "$skill")"
done
```

verify codex setup:

```bash
codex --help
ls -la ~/.codex
```

if prompted, run `codex` once and complete sign-in. keep your env vars loaded before launching codex so mcp tokens resolve correctly.

this repo targets the newer codex harness layout built around `AGENTS.md`, `rules/`, and `skills/`.
codex-managed system skills should stay in `~/.codex/skills/.system`, not in this repo.

### 3. runpod / docker gpu setup

for running claude code on a remote GPU instance (runpod, etc.):

**option a: docker image on runpod**

1. build and push the image to docker hub (or any registry runpod can pull from):

```bash
cd gpu-setup
docker build -t <your-dockerhub-username>/claude-gpu .
docker push <your-dockerhub-username>/claude-gpu
```

2. create a runpod template:

   - go to [runpod.io/console/user/templates](https://www.runpod.io/console/user/templates) and click **new template**
   - **template name**: `claude-gpu` (or whatever you want)
   - **container image**: `<your-dockerhub-username>/claude-gpu`
   - **container disk**: 20 GB (enough for deps and models)
   - **volume disk**: 50+ GB (mounted at `/workspace`, persists across restarts)
   - **volume mount path**: `/workspace`
   - **expose http ports**: `8888` (optional, for jupyter)
   - **expose tcp ports**: `22` (for ssh)
   - **environment variables**:

     | variable                       | required | description               |
     | ------------------------------ | -------- | ------------------------- |
     | `ANTHROPIC_API_KEY`            | yes      | claude api key            |
     | `GITHUB_PERSONAL_ACCESS_TOKEN` | no       | enables github MCP server |
     | `NIA_API_KEY`                  | no       | enables nia MCP server    |

   - leave **docker command** empty (the image uses its own entrypoint)
   - click **save template**

3. deploy a pod using the template:

   - go to **pods** > **deploy** and select your `claude-gpu` template
   - pick a GPU
   - click **deploy**
   - once running, grab the ssh command from the pod's **connect** menu
   - ssh in and run `claude`

the image is based on `runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404` and adds: bun, uv, pipx, claude code, and sshd. on boot, `bootstrap.sh` clones this config repo to `/workspace`, sets up symlinks, configures MCP servers, and strips macOS-only hooks (sound notifications, swift-lsp plugin).

**option b: bootstrap script on an existing instance**

if you already have a GPU instance running, just curl the bootstrap script:

```bash
curl -fsSL https://raw.githubusercontent.com/tomzhengy/harness-configs/main/gpu-setup/bootstrap.sh | bash
```

this installs everything and sets up config. it's idempotent so you can run it again after a restart.

**notes:**

- `/workspace` is used for persistent storage on runpod (survives restarts)
- claude oauth session is persisted to `/workspace/.claude.json`
- macOS-only hooks (afplay sounds, swift-lsp) are auto-stripped from settings.json
- `settings.json` is generated (not symlinked) so linux-incompatible entries don't break things

### clipaste (paste images into claude code over ssh)

claude code can't paste clipboard images when it runs on a remote machine over ssh -
the clipboard is local and ssh doesn't forward it. [clipaste](https://github.com/hqhq1025/clipaste)
bridges your local clipboard to the remote. run this on your **local** mac (the one
with the clipboard), not the remote:

```bash
cd clipaste
./setup-local.sh user@remote-host        # add -p PORT for a non-default ssh port
```

on a macos remote, paste with the `clipaste-paste` helper inside the remote claude
code session (it prints an image path to reference). see `clipaste/README.md` for
details, verification, and a no-daemon fallback.

## structure

```
setup.sh                        # install script (./setup.sh or ./setup.sh --link)

claude-code/
  config/
    settings.json           # model, permissions, statusline, hooks (biome, lint, sounds)
    mcp.json                # reference MCP server entries for ~/.claude.json
    CLAUDE.md               # global instructions (style, behavior, principles)
    statusline-command.sh   # custom statusline with git branch, model, context

  rules/
    nia.md                  # nia research assistant rules

cursor/
  mcp.json                 # reference MCP server entries (github, nia) for ~/.cursor/mcp.json
  cli-config.json          # reference cursor-agent config granting full permissions for ~/.cursor/cli-config.json

codex/
  setup.sh                 # codex installer (copy or --link)
  config.toml              # model, approval, sandbox, and mcp config
  AGENTS.md                # codex instructions plus local skill inventory
  instructions.md          # thin pointer back to AGENTS.md
  hooks.json               # codex lifecycle hooks
  hooks/
    expose-worktrees.sh    # surfaces managed codex worktrees as sibling symlinks
    post-edit-format.sh    # best-effort biome/prettier plus bun lint after edits
    sound.sh               # non-blocking macos sound helper for hooks
  rules/
    default.rules          # mirrored command allow rules
  skills/
    plan/                  # implementation planning skill
    nia-research/          # nia-first external research skill
    commit-message/        # commit title generation skill
    worktree-merge/        # worktree merge and cleanup skill
    code-reviewer/         # manual-use only review skill
    code-simplifier/       # manual-use only simplification skill
    thermo-nuclear-code-quality-review/
                            # manual-use strict maintainability review skill

gpu-setup/
  Dockerfile                # runpod pytorch gpu environment
  bootstrap.sh              # system setup script
  entrypoint.sh             # container entrypoint

clipaste/
  setup-local.sh           # local-side installer for clipboard image paste over ssh
  README.md                # clipaste setup, usage on a macos remote, and fallback
```
