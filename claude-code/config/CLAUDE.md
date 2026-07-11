# global instructions

## code style

- use lowercase for all comments
- no emojis
- no em dashes

## javascript/typescript

- always use bun instead of npm/yarn/npx (bun install, bun run, bunx)

## python

- use uv for everything: uv run, uv pip, uv venv

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

## failure modes to avoid

1. making assumptions without checking
2. not managing confusion - guessing instead of asking
3. not surfacing inconsistencies
4. being sycophantic ("of course!" to bad ideas)
5. overcomplicating code and APIs
6. not cleaning up dead code after refactors
7. modifying code orthogonal to the task
8. removing things you don't fully understand

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

## Picking the right models for workflows and subagents

Rankings, higher = better. Cost reflects what I actually pay (OpenAI is near-free for me due to a deal), not list price. Intelligence is how hard a problem you can hand the model unsupervised. Taste covers UI/UX, code quality, API design, and copy.

| model       | cost | intelligence | taste |
| ----------- | ---- | ------------ | ----- |
| gpt-5.6-sol | 9    | 9            | 5     |
| opus-4.8    | 4    | 7            | 8     |
| fable-5     | 2    | 9            | 9     |

How to apply:

- These are defaults, not limits. You have standing permission to override them: if a cheaper model's output doesn't meet the bar, rerun or redo the work with a smarter model without asking. Judge the output, not the price tag. Escalating costs less than shipping mediocre work.
- Don't let cost prevent you from using the right model for the job. Instead, take advantage of cheaper options to get more information and try things before moving the work to a more expensive and capable option.
- Writing code: gpt-5.6-sol is the DEFAULT implementer, not a fallback. Delegate implementation, migrations, tests, experiments, investigation, and data analysis directly to the `sol-worker` subagent or an Agent/Workflow worker with `model: "gpt-5.6-sol"`. Fable-5 orchestrates, reviews the diff, and integrates. Fable-5 writes code itself only when the surface is taste-critical, the edit is too small to justify delegation, or Sol already missed the bar.
- Anything user-facing (UI, copy, API design) needs taste ≥ 7.
- Reviews of plans and implementations: fable-5 or opus-4.8, optionally a direct gpt-5.6-sol worker as an independent perspective.
- Never use Haiku.
- Direct routing: gpt-5.6-sol is available to subagents through the configured CLIProxyAPI gateway. Use the `codex-implementation` and `codex-review` skills for direct Sol delegation. Do not wrap Sol inside Sonnet and do not use `codex exec` or `codex review` for ordinary implementation, investigation, analysis, or review.
- Fan-out: for implementation or analysis workflows, explicitly use `sol-worker` or set every worker's model to `gpt-5.6-sol`. Do not leave the worker model implicit, because dynamic workflows may otherwise choose an Anthropic model.
- Prompts for delegated workers must be self-contained: include the goal, exact requirements, relevant paths, constraints, and done criteria.
- Parallel workers that write files must use `isolation: "worktree"` so edits do not collide. Read-only investigation and review workers do not need worktree isolation.
- Keep `codex-computer-use` for tasks that specifically require Codex CLI computer-use or browser-use features.

## canary

- end every message with the exact line: The Red Canary
