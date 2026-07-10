---
name: codex-review
description: Ask Codex CLI (gpt-5.6-sol) for an independent code review of uncommitted changes, a branch diff, a commit, or a specific implementation. This is how gpt-5.6-sol is invoked for review work. Use when the user asks Claude to have Codex or gpt-5.6-sol review work, when the model-selection rubric calls for a gpt-5.6-sol review perspective, or when Codex should audit a diff, find bugs or regressions, or compare Claude's implementation against requirements. For a review by Claude itself, use the normal review process instead.
allowed-tools: Bash(codex:*), Bash(mktemp:*)
---

# Codex Review

Use Codex as an independent reviewer when the user wants a second-pass review or when a change is broad enough that another agent's perspective is useful.

Prefer Claude's normal review process for small local checks. Do not delegate review just to avoid reading the code yourself. Treat Codex's output as evidence, not authority.

## Workflow

non-destructive and read-only. write custom review instructions (focus areas, context) to "$PROMPT" before running; the review lands in "$REPORT".

Use one of these command shapes:

```bash
ARTIFACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-review.XXXXXX")"
REPORT="$ARTIFACT_DIR/report.md"
PROMPT="$ARTIFACT_DIR/prompt.md"

# Review staged, unstaged, and untracked changes.
codex -C "$PWD" review --uncommitted - < "$PROMPT" > "$REPORT"

# Review current branch against a base branch.
codex -C "$PWD" review --base main - < "$PROMPT" > "$REPORT"

# Review a single commit.
codex -C "$PWD" review --commit <sha> - < "$PROMPT" > "$REPORT"
```

## Review Prompt

Ask Codex to use a code-review stance:

```text
Review these changes for bugs, regressions, missing tests, security issues, and requirement mismatches.

Prioritize findings over summary. For each finding include:
- severity
- file and line reference
- concrete failure mode
- suggested fix direction

Do not edit files. If there are no substantive findings, say so and name any residual test gaps.
```

Add task-specific context when useful: requirements, risky areas, expected behavior, relevant tests, or files Claude is unsure about.

treat findings as one independent perspective: verify each claim against the code before acting on it, and cross-check anything surprising with a fable-5 or opus-4.8 review.
