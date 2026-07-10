---
name: codex-implementation
description: Delegate code writing and bulk work (implementation, migrations, tests, data analysis, investigation) to gpt-5.6-sol via codex exec. This is the DEFAULT way to write code - gpt-5.6-sol matches Claude's intelligence and is effectively free, so Claude orchestrates and reviews instead of typing the code itself. Only skip delegation for taste-critical surfaces (UI, copy, API design) or edits too small to be worth a handoff.
allowed-tools: Bash(codex exec:*), Agent
---

always run codex through a thin sonnet wrapper subagent (Agent tool, `model: 'sonnet'`, `effort: 'low'`, label prefixed `gpt-5.6-sol:`) rather than inline Bash in the main session - inline runs are invisible; wrapper subagents show up in the UI so the user can monitor progress.

codex shares no context with this session or the wrapper. write a fully self-contained prompt: goal, exact spec, relevant file paths, constraints, and done criteria.

- implementation (writes files): `codex exec --skip-git-repo-check -s workspace-write "<prompt>"`
- investigation / data analysis (no writes): `codex exec --skip-git-repo-check -s read-only "<prompt>"`
- always pass `--skip-git-repo-check`: without it codex refuses to run in untrusted non-git directories (e.g. tmp scratch dirs).
- useful flags: `--cd <dir>` to set the working root, `-o <file>` to capture the final message, `-m <model>` to override the model (config.toml already defaults to gpt-5.6-sol).

after it finishes: read the diff (`git diff`), run the tests, and judge the output. if it misses the bar, redo the work with fable-5 or opus-4.8 instead of re-prompting codex endlessly.
