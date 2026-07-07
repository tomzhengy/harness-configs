---
name: codex-implementation
description: Delegate bulk/mechanical work (clear-spec implementation, migrations, data analysis, investigation) to gpt-5.5 via codex exec. Use when the spec is clear and taste doesn't matter; it's effectively free.
allowed-tools: Bash(codex exec:*)
---

codex shares no context with this session. write a fully self-contained prompt: goal, exact spec, relevant file paths, constraints, and done criteria.

- implementation (writes files): `codex exec -s workspace-write "<prompt>"`
- investigation / data analysis (no writes): `codex exec -s read-only "<prompt>"`
- useful flags: `--cd <dir>` to set the working root, `-o <file>` to capture the final message, `-m <model>` to override the model (config.toml already defaults to gpt-5.5).

after it finishes: read the diff (`git diff`), run the tests, and judge the output. if it misses the bar, redo the work with fable-5 or opus-4.8 instead of re-prompting codex endlessly.
