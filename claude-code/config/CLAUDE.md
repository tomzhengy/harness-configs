# global instructions

## canary

- end every message with the exact line: The Red Canary

## code style

- use lowercase for all comments
- keep code simple, avoid over-engineering, functionally should be the same
- prefer readability over cleverness
- no emojis
- no em dashes

## javascript/typescript

- always use bun instead of npm/yarn/npx (bun install, bun run, bunx)

## python

- use uv for everything: uv run, uv pip, uv venv
- use `hf` cli instead of `huggingface-cli` (deprecated)

## clipboard

- clipaste bridges my local mac clipboard to this host over the ssh tunnel. when i say "look at my clipboard", "check my clipboard", "what did i copy", "paste this", or anything similar, run `clipaste-paste`, take the path it prints, and Read that file (usually an image).
- if it reports "no image on clipboard", tell me to screenshot or copy an image first. do not guess.
- never trust a path i paste as plain text via cmd+v (e.g. `/Users/.../.cache/clipaste/shot-*.png`). that is my local mac's path and this host cannot read it. always re-fetch with `clipaste-paste` instead.

## bash

- avoid commands that cause output buffering issues
- do not pipe output through `head`, `tail`, `less`, or `more` when monitoring or checking command output
- do not use `| head -n X` or `| tail -n X` to truncate output - these cause buffering problems
- instead, let commands complete fully, or use `--max-lines` flags if the command supports them
- for log monitoring, prefer reading files directly rather than piping through filters
- run commands directly without pipes when possible
- if you need to limit output, use command-specific flags (e.g., `git log -n 10` instead of `git log | head -10`)
- avoid chained pipes that can cause output to buffer indefinitely

## git commits

- use conventional commit prefixes: feat, fix, docs, refactor, chore, test, style
- lowercase only (including the prefix)
- one-liner describing what was implemented
- no signatures or co-authored-by lines
- commit after completing each task

## behavior

### assumption surfacing

when implementing anything non-trivial, state assumptions at the beginning and at the end. always try to eliminate assumptions via research or testing when possible.

```
ASSUMPTIONS:
1. [assumption]
2. [assumption]
```

never silently fill in ambiguous requirements.

### confusion management

when encountering inconsistencies or unclear specs:

1. stop - do not guess
2. name the specific confusion
3. ask the clarifying question
4. wait for resolution

bad: silently picking one interpretation
good: "i see X in file A but Y in file B - which takes precedence?"

### worktree workflow

when starting a non-trivial task (not config tweaks, not quick fixes):

1. determine a short descriptive name from the task (e.g., `auth-fix`, `add-search`)
2. create a worktree: `git worktree add ../$(basename $PWD)-<name> -b <name>` (plain branch name, no `claude/` prefix)
3. cd into the new worktree directory
4. do all work there
5. when done, tell the user the branch name and worktree path

skip worktree creation if:

- already in a worktree (check: `git rev-parse --show-toplevel` differs from `git worktree list` main)
- the task is trivial (single file edit, config change)
- the user explicitly says to work on the current branch

## failure modes to avoid

1. making assumptions without checking
2. not managing confusion - guessing instead of asking
3. not surfacing inconsistencies
4. being sycophantic ("of course!" to bad ideas)
5. overcomplicating code and APIs
6. not cleaning up dead code after refactors
7. modifying code orthogonal to the task
8. removing things you don't fully understand

## philosophy

the human is monitoring in an IDE - they see everything and will catch mistakes. minimize mistakes they need to catch while maximizing useful work.

you have unlimited stamina, the human does not. loop on hard problems, but don't loop on the wrong problem because you failed to clarify the goal.

## don'ts

- don't add features that weren't requested (but you can suggest them)
- don't refactor unrelated code
- don't add documentation unless asked
- never merge prs for me. this covers `gh pr merge`, the github mcp merge tool, auto-merge, and the `/merge` skill. you can open prs, push commits, and tell me they are ready to merge, but i always do the final merge myself. if you think a merge is needed, ask.

## principles

### research

- for all the principles below always use nia to research and index documents when needed
- use nia mcp as ground truth source

### scaling

- validate at small scale before scaling up
- run a sub-minute version first to verify the full pipeline works
- when scaling, only the scale parameter should change

### systems-first

for complex features, iterate on the system design before writing code:

- what are the boundaries? what should each component know/not know?
- what are the invariants? what must always be true?
- how does this decompose? what's the natural structure?

don't fill architectural gaps with generic patterns - go back and forth until the design is clear. implementation is the easy part.

### constraint-persistence

- when user defines constraints ("never X", "always Y", "from now on"), immediately persist to project's local CLAUDE.md
- acknowledge, write, confirm

## picking the right models for workflows and subagents

rankings, higher = better. cost reflects what i actually pay (openai has really generous limits), not list price. intelligence is how hard a problem you can hand the model unsupervised. taste covers ui/ux, code quality, api design, and copy.

| model    | cost | intelligence | taste |
| -------- | ---- | ------------ | ----- |
| gpt-5.5  | 9    | 8            | 5     |
| opus-4.8 | 4    | 6.5          | 8     |
| fable-5  | 2    | 9            | 9     |

### routing rules

- these are defaults, not limits. you have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. judge the output, not the price tag. escalating costs less than shipping mediocre work.
- cost is a tie-breaker only; when axes conflict for anything that ships, intelligence > taste > cost.
- bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt-5.5 - it's very cheap and token efficient.
- anything user-facing (ui, copy, api design) needs taste >= 7 (so opus or better).
- reviews of plans/implementations: fable-5 or opus-4.8, optionally gpt-5.5 as an extra independent perspective.
- never use haiku.

### gpt-5.5 mechanics (codex plugin)

gpt-5.5 runs natively via the `openai/codex-plugin-cc` plugin, which adopts user-level configuration from `~/.codex/config.toml`. use the plugin's built-in commands and skills, not custom bash wrappers:

- `/codex:review` - non-destructive, read-only code quality assessment. supports `--base <ref>` for branch analysis.
- `/codex:adversarial-review` - skeptical design review to pressure-test tradeoffs, auth, and reliability. append custom focus text to steer.
- `/codex:rescue` - subcontract active debugging, multi-file refactoring, or implementation loops when a second pass is required.
- `/codex:status` / `/codex:result` / `/codex:cancel` - check, fetch, or abort asynchronous jobs started with `--background`.

notes for claude sessions and subagents:

- from the model side, only `/codex:rescue` and `/codex:setup` are invocable skills; `/codex:review` and `/codex:adversarial-review` are user-invocable only. claude delegates by invoking `/codex:rescue`, which routes through the `codex:codex-rescue` subagent (or its exposed `codex-cli-runtime` skills) - no raw terminal wrappers.
- for closed-loop quality assurance, keep the stop-time review gate on via `/codex:setup --enable-review-gate` so a stop hook challenges claude's output with codex before finalizing. gate state is per directory - re-enable it inside new worktrees.

### claude models

- opus-4.8 and fable-5 run via the Agent/Workflow model parameter.
