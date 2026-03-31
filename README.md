# harness-configs

claude code and codex cli config files. please feel free to add suggestions!! i enjoy optimizing my agent workflows.

## claude code features

- **granular bash permissions** - read-only commands auto-allowed, write commands (git add/commit/merge/checkout/worktree) explicitly permitted
- **sound notifications** - async ping on permission prompts, idle prompts, auth, elicitations, and plan mode responses; glass sound when done
- **auto-formatting** - prettier runs automatically on every file edit/write
- **auto-linting** - bun lint runs automatically after file changes
- **git worktree workflow** - auto-creates worktrees for non-trivial tasks to isolate branches across sessions
- **behavioral guardrails** - assumption surfacing, confusion management, change summaries
- **systems-first design** - iterates on system design before writing code
- **plan agent** - architecture planning agent using opus model for deeper reasoning
- **/commit command** - auto-generate commit messages from git changes
- **/merge command** - merge a worktree branch back into the target branch and clean up
- **nia research rules** - integrated nia mcp for external code/docs research and indexing
- **custom statusline** - git branch, model, and context info

## codex harness features

- **instruction parity** - codex `AGENTS.md` mirrors the current claude workflow rules: bun-first js/ts, assumption surfacing, worktree workflow, post-edit checks, and nia-first research
- **broad command rules** - codex `rules/default.rules` mirrors the current claude command-family allowlist rather than the older tighter readme wording
- **skill-based workflow ports** - local skills replace the claude plan agent and the `/commit` and `/merge` commands
- **manual-use review tools** - local `code-reviewer` and `code-simplifier` skills replace the disabled claude agents without making them implicit
- **explicit native gaps** - codex does not currently replicate claude's sound notifications, custom statusline scripting, edit-triggered hooks, or swift plugin support in this repo

## setup

### 1. environment variables

copy `.env.example` to `.env`, add your api keys, then load it in your shell:

```bash
cp .env.example .env
# edit .env with your keys
set -a
source .env
set +a
```

### 2.1 claude code symlinks

from the `harness-configs` directory, symlink these to `~/.claude/`:

```bash
ln -s $(pwd)/claude-code/config/settings.json ~/.claude/settings.json
ln -s $(pwd)/claude-code/config/CLAUDE.md ~/.claude/CLAUDE.md
ln -s $(pwd)/claude-code/config/statusline-command.sh ~/.claude/statusline-command.sh
ln -s $(pwd)/claude-code/agents ~/.claude/agents
ln -s $(pwd)/claude-code/rules ~/.claude/rules
ln -s $(pwd)/claude-code/commands ~/.claude/commands
```

for MCP servers, use `claude-code/config/mcp.json` as a reference template and merge those entries into `~/.claude.json`. the gpu bootstrap script already handles that merge automatically.

### 2.2 codex cli setup

from the `harness-configs` directory, symlink these files to `~/.codex/`:

```bash
mkdir -p ~/.codex
mkdir -p ~/.codex/skills
ln -sf $(pwd)/codex/config.toml ~/.codex/config.toml
ln -sf $(pwd)/codex/AGENTS.md ~/.codex/AGENTS.md
ln -sf $(pwd)/codex/instructions.md ~/.codex/instructions.md
ln -sfn $(pwd)/codex/rules ~/.codex/rules
for skill in codex/skills/*; do
  ln -sfn "$(pwd)/$skill" ~/.codex/skills/"$(basename "$skill")"
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

## structure

```
claude-code/
  config/
    settings.json           # model, permissions, statusline, hooks (prettier, lint, sounds)
    mcp.json                # reference MCP server entries for ~/.claude.json
    CLAUDE.md               # global instructions (style, behavior, principles)
    statusline-command.sh   # custom statusline with git branch, model, context

  agents/
    plan.md                 # architecture planning
    disabled/
      code-reviewer.md      # proactive code review (disabled)
      code-simplifier.md    # proactive code simplification (disabled)

  rules/
    nia.md                  # nia research assistant rules

  commands/
    commit.md               # /commit - generate commit messages
    merge.md                # /merge - merge worktree branch and clean up

codex/
  config.toml              # model, approval, sandbox, and mcp config
  AGENTS.md                # codex instructions plus local skill inventory
  instructions.md          # thin pointer back to AGENTS.md
  rules/
    default.rules          # mirrored command allow rules
  skills/
    plan/                  # implementation planning skill
    nia-research/          # nia-first external research skill
    commit-message/        # commit title generation skill
    worktree-merge/        # worktree merge and cleanup skill
    code-reviewer/         # manual-use only review skill
    code-simplifier/       # manual-use only simplification skill

gpu-setup/
  Dockerfile                # runpod pytorch gpu environment
  bootstrap.sh              # system setup script
  entrypoint.sh             # container entrypoint
```
