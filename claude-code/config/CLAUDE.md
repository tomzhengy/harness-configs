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

before implementing anything non-trivial, state assumptions:

```
ASSUMPTIONS:
1. [assumption]
2. [assumption]
-> correct me now or i'll proceed with these.
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

### change summaries

after modifications, summarize:

```
CHANGES MADE:
- [file]: [what changed and why]

NOT TOUCHED:
- [file]: [why left alone]

CONCERNS:
- [risks or things to verify]
```

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

Rankings, higher = better. Cost reflects what I actually pay (OpenAI has really generous limits), not list price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model    | cost | intelligence | taste |
| -------- | ---- | ------------ | ----- |
| gpt-5.5  | 9    | 8            | 5     |
| opus-4.8 | 4    | 8            | 8     |
| fable-5  | 2    | 9            | 9     |

How to apply:

- These are defaults, not limits. You have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Cost is a tie-breaker only; when axes conflict for anything that ships, intelligence > taste > cost.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations): gpt-5.5 - it's very cheap and token efficent.
- Anything user-facing (UI, copy, API design) needs taste >= 7 (so Opus or better).
- Reviews of plans/implementations: fable-5 or opus-4.8, optionally gpt-5.5 as an extra independent perspective.
- Never use Haiku.
- Mechanics: gpt-5.5 is handled natively via the `openai/codex-plugin-cc` plugin inside Claude Code, automatically adopting your user-level configurations from `~/.codex/config.toml`. Avoid writing custom bash scripts; instead, utilize the plugin's built-in tools and skills:
  - `/codex:review` - Run non-destructive, read-only code quality assessments. Supports `--base <ref>` for branch analysis.
  - `/codex:adversarial-review` - Perform a skeptical design review to pressure-test tradeoffs, auth, and reliability. Append custom focus text at the end of the command to steer the focus.
  - `/codex:rescue` - Subcontract active debugging, multi-file refactoring, or implementation loops to Codex when a second pass is required.
  - `/codex:status` / `/codex:result` / `/codex:cancel` - Use these to check, fetch, or abort asynchronous jobs when using the `--background` flag on heavy tasks.
- Claude models (opus-4.8, fable-5) run via the Agent/Workflow model parameter.

Using gpt-5.5 inside workflows and subagents:

- Subagents and automated workflows should call the plugin's native slash commands or its exposed `codex-cli-runtime` skills to delegate tasks directly, omitting the need for raw terminal wrappers.
- For closed-loop quality assurance, keep the review gate turned on via `/codex:setup --enable-review-gate`. This ensures a stop hook automatically challenges Claude's outputs using Codex before finalizing, preventing broken code or weak design assumptions from reaching the main session unvetted.
