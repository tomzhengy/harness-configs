---
name: review
description: |
  Pre-landing PR review. Two-pass analysis (critical + informational) against the base
  branch diff. Auto-fixes obvious issues, asks about ambiguous ones. Use when asked to
  "review this PR", "code review", "check my diff", or before merging/shipping.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

# pre-landing PR review

analyze the current branch's diff against the base branch for structural issues that
tests don't catch. two-pass review with fix-first handling.

---

## step 0: detect base branch

```bash
_BASE=""
_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null) || true
[ -z "$_BASE" ] && _BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null) || true
[ -z "$_BASE" ] && _BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
[ -z "$_BASE" ] && git rev-parse --verify origin/main 2>/dev/null && _BASE="main" || true
[ -z "$_BASE" ] && git rev-parse --verify origin/master 2>/dev/null && _BASE="master" || true
[ -z "$_BASE" ] && _BASE="main"
echo "BASE_BRANCH: $_BASE"
```

use the detected base branch in all subsequent git commands.

---

## step 1: check branch

1. run `git branch --show-current` to get the current branch.
2. if on the base branch, output: **"nothing to review, you're on the base branch."** and stop.
3. run `git fetch origin <base> --quiet && git diff origin/<base> --stat` to check for a diff.
   if no diff, output the same message and stop.

---

## step 1.5: scope drift detection

before reviewing code quality, check: did they build what was requested?

1. read commit messages: `git log origin/<base>..HEAD --oneline`
2. check for PR description: `gh pr view --json body -q .body 2>/dev/null || true`
3. read `TODOS.md` if it exists
4. identify the **stated intent** from these sources
5. run `git diff origin/<base>...HEAD --stat` and compare files changed against intent

evaluate:

**scope creep:**

- files changed that are unrelated to the stated intent
- new features or refactors not mentioned anywhere
- "while i was in there..." changes that expand blast radius

**missing requirements:**

- requirements from PR description/TODOS.md not addressed in the diff
- partial implementations (started but not finished)

output:

```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <1-line summary of what was requested>
Delivered: <1-line summary of what the diff actually does>
[if drift: list each out-of-scope change]
[if missing: list each unaddressed requirement]
```

this is **informational**, does not block the review.

---

## step 2: read the checklist

read the checklist file at the path relative to wherever this skill is installed.
the checklist is at `checklist.md` in the same directory as this SKILL.md file.

try these paths in order:

1. `.claude/skills/review/checklist.md` (project-local)
2. `~/.claude/skills/review/checklist.md` (user-global via symlink)

**if the file cannot be read, STOP and report the error.** do not proceed without it.

---

## step 3: get the diff

fetch the latest base branch:

```bash
git fetch origin <base> --quiet
```

run `git diff origin/<base>` to get the full diff. this includes both committed and
uncommitted changes against the latest base branch.

---

## step 4: critical pass (core review)

apply the CRITICAL categories from the checklist against the diff:
SQL & data safety, race conditions & concurrency, LLM output trust boundary,
shell injection, enum & value completeness.

then apply the INFORMATIONAL categories.

**enum completeness requires reading code OUTSIDE the diff.** when the diff introduces
a new enum value, use Grep to find all files referencing sibling values, then Read those
files to check if the new value is handled.

**confidence calibration:** before including a finding, apply the calibration rules from
the checklist. if you wouldn't bet $100 on it being a real bug, investigate further or skip.

follow the output format from the checklist. respect the suppressions.

---

## step 4.5: design review (conditional)

check if the diff touches frontend files:

```bash
git diff origin/<base> --name-only | grep -E '\.(tsx|jsx|vue|svelte|css|scss|html)$' || echo "NO_FRONTEND"
```

if `NO_FRONTEND`: skip silently.

if frontend files exist: apply the design review checklist section from checklist.md.
check for AI slop, typography issues, spacing/layout problems, interaction state gaps,
and DESIGN.md violations (if DESIGN.md exists).

---

## step 5: fix-first review

**every finding gets action, not just critical ones.**

output a summary header: `Pre-Landing Review: N issues (X critical, Y informational)`

### step 5a: classify each finding

for each finding, classify as AUTO-FIX or ASK per the fix-first heuristic in checklist.md.
critical findings lean toward ASK, informational findings lean toward AUTO-FIX.

### step 5b: auto-fix all AUTO-FIX items

apply each fix directly. for each one, output a one-line summary:
`[AUTO-FIXED] [file:line] Problem -> what you did`

### step 5c: batch-ask about ASK items

if there are ASK items remaining, present them in ONE AskUserQuestion:

- list each item with a number, severity label, problem, and recommended fix
- for each item, provide options: A) Fix as recommended, B) Skip
- include an overall RECOMMENDATION

example format:

```
i auto-fixed 5 issues. 2 need your input:

1. [CRITICAL] app/models/post.rb:42 -- race condition in status transition
   Fix: add `WHERE status = 'draft'` to the UPDATE
   -> A) Fix  B) Skip

2. [INFORMATIONAL] app/services/generator.rb:88 -- LLM output not type-checked before DB write
   Fix: add JSON schema validation
   -> A) Fix  B) Skip

RECOMMENDATION: fix both. #1 is a real race condition, #2 prevents silent data corruption.
```

if 3 or fewer ASK items, you may use individual AskUserQuestion calls instead of batching.

### step 5d: apply user-approved fixes

apply fixes for items where the user chose "Fix." output what was fixed.

if no ASK items exist (everything was AUTO-FIX), skip the question entirely.

### verification of claims

before producing the final review output:

- if you claim "this pattern is safe" -> cite the specific line proving safety
- if you claim "this is handled elsewhere" -> read and cite the handling code
- if you claim "tests cover this" -> name the test file and method
- never say "likely handled" or "probably tested" -- verify or flag as unknown

---

## step 5.5: documentation staleness check

cross-reference the diff against documentation files. for each `.md` file in the repo
root (README.md, ARCHITECTURE.md, CONTRIBUTING.md, CLAUDE.md, etc.):

1. check if code changes in the diff affect features/components described in that doc.
2. if the doc was NOT updated but the code it describes WAS changed, flag it:
   "documentation may be stale: [file] describes [feature] but code changed in this branch."

informational only, never critical.

---

## step 6: completion summary

output a final summary:

```
REVIEW COMPLETE
===============
Branch: <branch name>
Base: <base branch>
Scope: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Findings: N total (X critical, Y informational)
Auto-fixed: N
User-approved fixes: N
Skipped: N
Documentation: [current / N files may be stale]
```

---

## important rules

- **read the FULL diff before commenting.** do not flag issues already addressed in the diff.
- **fix-first, not read-only.** AUTO-FIX items are applied directly. ASK items only after
  user approval. never commit, push, or create PRs, that's for /commit or /ship.
- **be terse.** one line problem, one line fix. no preamble.
- **only flag real problems.** skip anything that's fine.
- **respect suppressions.** the checklist has a "DO NOT flag" section. follow it.
- **verify before claiming.** cite evidence for safety claims. "probably fine" is not acceptable.
