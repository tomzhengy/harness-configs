---
name: codex-implementation
description: Delegate implementation, migrations, tests, experiments, investigation, and data analysis directly to a gpt-5.6-sol subagent. This is the default implementation path when taste-sensitive design is not the primary constraint.
---

# Direct Sol implementation

Spawn the `sol-worker` subagent or a general-purpose Agent/Workflow worker with `model: "gpt-5.6-sol"`. Do not use a Sonnet wrapper and do not launch `codex exec` for ordinary delegated work.

Give the worker a self-contained assignment:

- goal and exact requirements
- relevant file paths and repository context
- constraints and invariants
- commands to validate the result
- concrete done criteria

Use `effort: "high"` by default. Use `xhigh` or `max` for unusually hard work, and lower effort for bounded mechanical tasks.

For parallel workers that write files, use `isolation: "worktree"`. Read-only investigation and analysis workers do not need worktree isolation.

After the worker finishes, inspect the diff, run the relevant tests, and judge the output. If it misses the bar, escalate to Fable 5 or Opus 4.8 instead of repeatedly prompting the same worker.
