---
name: codex-review
description: Ask a direct gpt-5.6-sol subagent for an independent review of uncommitted changes, a branch diff, a commit, or a specific implementation. Use when a second review perspective is useful.
---

# Direct Sol review

Spawn the `sol-worker` subagent or a general-purpose Agent/Workflow worker with `model: "gpt-5.6-sol"` and `effort: "high"`. Do not use a Sonnet wrapper, temporary prompt files, or `codex review`.

The assignment must be read-only and name the exact review target. Include task requirements, risky areas, expected behavior, relevant tests, and any files the orchestrator is unsure about.

Ask the worker to prioritize findings over summary. Each finding should include:

- severity
- file and line reference
- concrete failure mode
- suggested fix direction

The worker must not edit files. If there are no substantive findings, it should say so and identify any remaining test gaps.

Treat the result as one independent perspective. Inspect cited code before relaying a finding, separate confirmed issues from unverified suggestions, and cross-check surprising claims with Fable 5 or Opus 4.8.
