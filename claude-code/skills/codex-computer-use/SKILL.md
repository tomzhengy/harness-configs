---
name: codex-computer-use
description: Delegate tasks that need a live browser or gui interaction (click-through verification, web flows, visual checks) to codex with computer use enabled.
allowed-tools: Bash(codex exec:*)
---

codex's `computer_use` and `browser_use` features are stable and enabled (check with `codex features list`).

run: `codex exec --enable computer_use --enable browser_use "<prompt>"`

the prompt must be self-contained: the url or app to drive, the exact flow to click through, and what to observe and report back. add `-s workspace-write` only if codex needs to save screenshots or files into the workspace.

relay what codex observed verbatim where it matters (error text, rendered values); don't paraphrase away the evidence.
