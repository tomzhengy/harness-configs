---
name: codex-review
description: Get an independent gpt-5.6-sol code review via codex review. Use as an extra perspective alongside fable-5/opus-4.8 reviews of plans or implementations.
allowed-tools: Bash(codex review:*)
---

non-destructive and read-only. pick the scope:

- uncommitted changes (staged, unstaged, untracked): `codex review --uncommitted`
- branch against a base: `codex review --base main`
- a single commit: `codex review --commit <sha>`

steer it by appending custom instructions, e.g. `codex review --base main "focus on error handling and concurrency"`.

treat findings as one independent perspective: verify each claim against the code before acting on it, and cross-check anything surprising with a fable-5 or opus-4.8 review.
