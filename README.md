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
- **skill-based workflow ports** - local skills cover planning, commit messages, transcript redaction, worktree merges, code review, and nia research
- **strict review skill** - codex includes the thermo-nuclear code quality review skill from the claude setup as an explicit/manual skill
- **explicit native gaps** - codex does not currently replicate claude's custom statusline scripting, transcript scroll keybinding, away/back phone-call commands, babysit's claude-specific loop scheduling, or claude-only plugin marketplace entries in this repo

## cursor harness features

- **rule parity** - `cursor/rules/global.mdc` mirrors the current claude/codex global instructions (bun-first js/ts, assumption surfacing, worktree workflow, commit and pr style) and `cursor/rules/nia.mdc` carries the nia research rules; both install as always-on user rules in `~/.cursor/rules`
- **hook parity** - `cursor/hooks.json` ports worktree exposure (`sessionStart`), post-edit biome/prettier format plus bun lint (`afterFileEdit`), and the glass done-sound (`stop`) to cursor's native hook system; `~/.cursor/hooks.json` is shared by the ide and the cli
- **skill cross-discovery** - cursor natively discovers skills from `~/.claude/skills` and the codex skill dirs, so babysit, agent-transcript, call-user, thermo-nuclear-code-quality-review, plan, commit-message, and friends work in cursor without copies; `disable-model-invocation` skills stay slash-invoke only
- **away-mode commands** - `/away` and `/back` slash commands (`cursor/commands/`) drive the same `~/.claude/scripts/away-mode.sh` control plane and call-user protocol as the claude setup, so the phone-call blocker alerts work from cursor sessions too
- **custom statusline** - `cursor/statusline.sh` ports the claude statusline (dir, git branch, model, context usage) to the cursor cli statusLine spec, in cool blue to tell cursor sessions apart from claude's warm orange
- **cli notifications + max permissions** - `cursor/cli-config.json` keeps the full-permission allowlist and adds os notifications plus the statusline wiring
- **explicit native gaps** - cursor has no permission-prompt hook event (enable the ide's built-in agent notification sound instead), no user-global instructions file for the cli (the rules dir is ide-side; project-level `AGENTS.md` still applies), and babysit's ScheduleWakeup rescheduling is claude-specific (cursor sessions should use the built-in /loop skill for recurring runs)

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

### cursor setup

from the `harness-configs` directory, run:

```bash
./cursor/setup.sh          # copy mode
./cursor/setup.sh --link   # symlinks for repo authors
```

the script installs rules, commands, hooks, and the statusline script under `~/.cursor` (override with `CURSOR_HOME`), and merges `cursor/cli-config.json` into `~/.cursor/cli-config.json` with jq. `cli-config.json` is always merged as a real file, never symlinked, because the cursor cli rewrites it at runtime. existing files are backed up before modification. restart cursor afterwards so hooks, rules, and commands reload.

skills are intentionally not duplicated for cursor: it discovers the claude skills in `~/.claude/skills` (installed by the root `setup.sh`) and codex skills natively.

### cursor mcp servers

use `cursor/mcp.json` as a reference template and merge those entries into `~/.cursor/mcp.json` with your API keys (github + nia, the same two servers as the claude config). cursor does not expand `${VAR}` placeholders, so replace them with real values in the live file:

```bash
# edit ~/.cursor/mcp.json and add the github + nia entries from cursor/mcp.json,
# substituting your GITHUB_PERSONAL_ACCESS_TOKEN and NIA_API_KEY
```

restart cursor (or reload mcp servers in settings) after editing.

### cursor cli permissions

`cursor/cli-config.json` grants the cursor cli (cursor-agent) full permissions: every shell command, read, write, web fetch, and mcp tool is auto-allowed with an empty deny list. it also enables os notifications and points the cli statusline at `~/.cursor/statusline.sh`. `cursor/setup.sh` merges it into `~/.cursor/cli-config.json` for you.

note: the permission grant is the persistent equivalent of running with `--force` / `--yolo`. only the cursor cli reads `cli-config.json`; the cursor ide app has its own auto-run setting in the app settings ui.

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
    expose-worktrees.sh     # surfaces claude worktrees as sibling symlinks
    keybindings.json        # transcript scroll keybinding

  rules/
    nia.md                  # nia research assistant rules

  scripts/
    away-mode.sh            # away-mode control plane (enable/disable)
    call-me.sh              # twilio dial plane, gated by away mode

  skills/
    away/                   # /away - arm phone-call blocker alerts
    back/                   # /back - disarm away mode
    call-user/              # place a call on blockers while away
    babysit/                # recurring open-PR maintenance loop
    agent-transcript/       # redact and insert agent transcripts into PRs
    thermo-nuclear-code-quality-review/
                            # manual-use strict maintainability review skill

cursor/
  setup.sh                 # cursor installer (copy or --link)
  mcp.json                 # reference MCP server entries (github, nia) for ~/.cursor/mcp.json
  cli-config.json          # cursor-agent config: full permissions, notifications, statusline
  statusline.sh            # custom cli statusline with git branch, model, context
  hooks.json               # cursor lifecycle hooks (ide + cli)
  hooks/
    expose-worktrees.sh    # surfaces cursor-managed worktrees as sibling symlinks
    post-edit-format.sh    # best-effort biome/prettier plus bun lint after edits
    sound.sh               # non-blocking macos sound helper for hooks
  rules/
    global.mdc             # global instructions ported from CLAUDE.md/AGENTS.md
    nia.mdc                # nia research assistant rules
  commands/
    away.md                # /away - arm the phone-call blocker alerts
    back.md                # /back - disarm away mode

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
    agent-transcript/       # redact and insert agent transcripts into PRs
    plan/                  # implementation planning skill
    nia-research/          # nia-first external research skill
    commit-message/        # commit title generation skill
    worktree-merge/        # worktree merge and cleanup skill
    code-reviewer/         # manual-use only review skill
    code-simplifier/       # manual-use only simplification skill
    thermo-nuclear-code-quality-review/
                            # manual-use strict maintainability review skill

clipaste/
  setup-local.sh           # local-side installer for clipboard image paste over ssh
  README.md                # clipaste setup, usage on a macos remote, and fallback
```
