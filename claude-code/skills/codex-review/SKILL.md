---
name: codex-review
description: Get an independent gpt-5.6-sol code review via codex review. Use as an extra perspective alongside fable-5/opus-4.8 reviews of plans or implementations.
allowed-tools: Bash(codex:*), Bash(mktemp:*)
---

non-destructive and read-only. write custom review instructions (focus areas, context) to "$PROMPT" before running; the review lands in "$REPORT".

## Workflow

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

treat findings as one independent perspective: verify each claim against the code before acting on it, and cross-check anything surprising with a fable-5 or opus-4.8 review.
