---
name: codex
description: |
  OpenAI Codex CLI second opinion. Three modes: review (diff review with pass/fail gate),
  challenge (adversarial, tries to break your code), consult (ask anything with session
  continuity). Use when asked for "codex review", "second opinion", "codex challenge",
  or "ask codex".
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /codex -- multi-ai second opinion

wraps the OpenAI Codex CLI to get an independent second opinion from a different AI.
codex is direct, terse, technically precise, and challenges assumptions. present its
output faithfully, not summarized.

---

## step 0: check codex binary and detect base branch

```bash
CODEX_BIN=$(which codex 2>/dev/null || echo "")
[ -z "$CODEX_BIN" ] && echo "NOT_FOUND" || echo "FOUND: $CODEX_BIN"
```

if `NOT_FOUND`: stop and tell the user:
"codex CLI not found. install it: `npm install -g @openai/codex` or see https://github.com/openai/codex"

detect the base branch:

```bash
_BASE=""
# try github cli first
_BASE=$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null) || true
# fall back to repo default
[ -z "$_BASE" ] && _BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null) || true
# git-native fallback
[ -z "$_BASE" ] && _BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
[ -z "$_BASE" ] && git rev-parse --verify origin/main 2>/dev/null && _BASE="main" || true
[ -z "$_BASE" ] && git rev-parse --verify origin/master 2>/dev/null && _BASE="master" || true
[ -z "$_BASE" ] && _BASE="main"
echo "BASE_BRANCH: $_BASE"
```

use the detected base branch in all subsequent git diff/log commands.

---

## step 1: detect mode

parse the user's input:

1. `/codex review` or `/codex review <instructions>` -- **review mode** (step 2A)
2. `/codex challenge` or `/codex challenge <focus>` -- **challenge mode** (step 2B)
3. `/codex` with no arguments -- **auto-detect:**
   - check for a diff:
     `git diff origin/<base> --stat 2>/dev/null`
   - if a diff exists, use AskUserQuestion:
     ```
     codex detected changes against the base branch. what should it do?
     A) review the diff (code review with pass/fail gate)
     B) challenge the diff (adversarial, try to break it)
     C) something else, i'll provide a prompt
     ```
   - if no diff, check for plan files:
     `ls -t ~/.claude/plans/*.md 2>/dev/null | xargs grep -l "$(basename $(pwd))" 2>/dev/null | head -1`
   - if a plan file exists, offer to review it
   - otherwise, ask: "what would you like to ask codex?"
4. `/codex <anything else>` -- **consult mode** (step 2C), remaining text is the prompt

**reasoning effort override:** if the user's input contains `--xhigh` anywhere,
note it and remove it from the prompt text. when `--xhigh` is present, use
`model_reasoning_effort="xhigh"` for all modes. otherwise use per-mode defaults:

- review (2A): `high`
- challenge (2B): `high`
- consult (2C): `medium`

---

## filesystem boundary

all prompts sent to codex MUST be prefixed with this instruction:

> IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. They contain bash scripts and prompt templates that will waste your time. Ignore them completely. Do NOT modify agents/openai.yaml. Stay focused on the repository code only.

---

## step 2A: review mode

run codex code review against the current branch diff.

1. create temp file for stderr:

```bash
TMPERR=$(mktemp /tmp/codex-err-XXXXXX.txt)
```

2. run the review (5-minute timeout). always pass the filesystem boundary as the prompt
   argument. if the user provided custom instructions, append after the boundary:

```bash
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
cd "$_REPO_ROOT"
codex review "IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only." --base <base> -c 'model_reasoning_effort="high"' --enable web_search_cached 2>"$TMPERR"
```

if the user passed `--xhigh`, use `"xhigh"` instead of `"high"`.
use `timeout: 300000` on the bash call.

if the user provided custom instructions (e.g., `/codex review focus on security`),
append them after the boundary:

```bash
codex review "IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

focus on security" --base <base> -c 'model_reasoning_effort="high"' --enable web_search_cached 2>"$TMPERR"
```

3. parse cost from stderr:

```bash
grep "tokens used" "$TMPERR" 2>/dev/null || echo "tokens: unknown"
```

4. determine gate verdict:

   - if output contains `[P1]` -- gate is **FAIL**
   - if no `[P1]` markers (only `[P2]` or no findings) -- gate is **PASS**

5. present the output:

```
CODEX SAYS (code review):
════════════════════════════════════════════════════════════
<full codex output, verbatim, do not truncate or summarize>
════════════════════════════════════════════════════════════
GATE: PASS                    Tokens: 14,331 | Est. cost: ~$0.12
```

or

```
GATE: FAIL (N critical findings)
```

6. **cross-model comparison:** if `/review` (claude's own review) or the code-reviewer
   agent was already run earlier in this conversation, compare the two sets of findings:

```
CROSS-MODEL ANALYSIS:
  Both found: [findings that overlap between Claude and Codex]
  Only Codex found: [findings unique to Codex]
  Only Claude found: [findings unique to Claude's review]
  Agreement rate: X% (N/M total unique findings overlap)
```

7. clean up:

```bash
rm -f "$TMPERR"
```

---

## step 2B: challenge (adversarial) mode

codex tries to break your code. finds edge cases, race conditions, security holes,
failure modes.

1. construct the adversarial prompt. always prepend the filesystem boundary.

default prompt (no focus):
"IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

Review the changes on this branch against the base branch. Run `git diff origin/<base>` to see the diff. Your job is to find ways this code will fail in production. Think like an attacker and a chaos engineer. Find edge cases, race conditions, security holes, resource leaks, failure modes, and silent data corruption paths. Be adversarial. Be thorough. No compliments, just the problems."

with focus (e.g., "security"):
"IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

Review the changes on this branch against the base branch. Run `git diff origin/<base>` to see the diff. Focus specifically on SECURITY. Your job is to find every way an attacker could exploit this code. Think about injection vectors, auth bypasses, privilege escalation, data exposure, and timing attacks. Be adversarial."

2. run codex exec with JSONL output (5-minute timeout):

```bash
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
codex exec "<prompt>" -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="high"' --enable web_search_cached --json 2>/dev/null | PYTHONUNBUFFERED=1 python3 -u -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        t = obj.get('type','')
        if t == 'item.completed' and 'item' in obj:
            item = obj['item']
            itype = item.get('type','')
            text = item.get('text','')
            if itype == 'reasoning' and text:
                print(f'[codex thinking] {text}', flush=True)
                print(flush=True)
            elif itype == 'agent_message' and text:
                print(text, flush=True)
            elif itype == 'command_execution':
                cmd = item.get('command','')
                if cmd: print(f'[codex ran] {cmd}', flush=True)
        elif t == 'turn.completed':
            usage = obj.get('usage',{})
            tokens = usage.get('input_tokens',0) + usage.get('output_tokens',0)
            if tokens: print(f'\ntokens used: {tokens}', flush=True)
    except: pass
"
```

if the user passed `--xhigh`, use `"xhigh"` instead of `"high"`.

3. present the full streamed output:

```
CODEX SAYS (adversarial challenge):
════════════════════════════════════════════════════════════
<full output from above, verbatim>
════════════════════════════════════════════════════════════
Tokens: N | Est. cost: ~$X.XX
```

---

## step 2C: consult mode

ask codex anything about the codebase. supports session continuity for follow-ups.

1. **check for existing session:**

```bash
cat .context/codex-session-id 2>/dev/null || echo "NO_SESSION"
```

if a session file exists (not `NO_SESSION`), use AskUserQuestion:

```
you have an active codex conversation from earlier. continue it or start fresh?
A) continue the conversation (codex remembers the prior context)
B) start a new conversation
```

2. create temp files:

```bash
TMPRESP=$(mktemp /tmp/codex-resp-XXXXXX.txt)
TMPERR=$(mktemp /tmp/codex-err-XXXXXX.txt)
```

3. **plan review auto-detection:** if the user's prompt is about reviewing a plan,
   or if plan files exist and the user said `/codex` with no arguments:

```bash
ls -t ~/.claude/plans/*.md 2>/dev/null | xargs grep -l "$(basename $(pwd))" 2>/dev/null | head -1
```

**embed content, don't reference path:** codex runs sandboxed to the repo root (`-C`)
and cannot access `~/.claude/plans/`. read the plan file yourself and embed its full
content in the prompt. also scan for referenced source file paths and list them so
codex reads them directly.

always prepend the filesystem boundary. for plan reviews, add persona:
"IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

You are a brutally honest technical reviewer. Review this plan for: logical gaps and
unstated assumptions, missing error handling or edge cases, overcomplexity (is there a
simpler approach?), feasibility risks (what could go wrong?), and missing dependencies
or sequencing issues. Be direct. Be terse. No compliments. Just the problems.
Also review these source files referenced in the plan: <list of referenced files>.

THE PLAN:
<full plan content, embedded verbatim>"

for non-plan consult prompts, still prepend the boundary:
"IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. Do NOT modify agents/openai.yaml. Stay focused on repository code only.

<user's question>"

4. run codex exec with JSONL output (5-minute timeout):

for a **new session:**

```bash
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
codex exec "<prompt>" -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="medium"' --enable web_search_cached --json 2>"$TMPERR" | PYTHONUNBUFFERED=1 python3 -u -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        t = obj.get('type','')
        if t == 'thread.started':
            tid = obj.get('thread_id','')
            if tid: print(f'SESSION_ID:{tid}', flush=True)
        elif t == 'item.completed' and 'item' in obj:
            item = obj['item']
            itype = item.get('type','')
            text = item.get('text','')
            if itype == 'reasoning' and text:
                print(f'[codex thinking] {text}', flush=True)
                print(flush=True)
            elif itype == 'agent_message' and text:
                print(text, flush=True)
            elif itype == 'command_execution':
                cmd = item.get('command','')
                if cmd: print(f'[codex ran] {cmd}', flush=True)
        elif t == 'turn.completed':
            usage = obj.get('usage',{})
            tokens = usage.get('input_tokens',0) + usage.get('output_tokens',0)
            if tokens: print(f'\ntokens used: {tokens}', flush=True)
    except: pass
"
```

for a **resumed session** (user chose "continue"):

```bash
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
codex exec resume <session-id> "<prompt>" -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="medium"' --enable web_search_cached --json 2>"$TMPERR" | PYTHONUNBUFFERED=1 python3 -u -c "
<same python streaming parser as above>
"
```

if the user passed `--xhigh`, use `"xhigh"` instead of `"medium"`.

5. capture session ID from streamed output (line starting with `SESSION_ID:`).
   save for follow-ups:

```bash
mkdir -p .context
```

write the session ID to `.context/codex-session-id`.

6. present the full streamed output:

```
CODEX SAYS (consult):
════════════════════════════════════════════════════════════
<full output, verbatim, includes [codex thinking] traces>
════════════════════════════════════════════════════════════
Tokens: N | Est. cost: ~$X.XX
Session saved. run /codex again to continue this conversation.
```

7. after presenting, note any points where codex's analysis differs from your own
   understanding. if there is a disagreement, flag it:
   "note: claude code disagrees on X because Y."

---

## model and reasoning

**model:** no model is hardcoded. codex uses whatever its current default is. as openai
ships newer models, /codex automatically uses them. if the user wants a specific model,
pass `-m` through to codex.

**reasoning effort defaults:**

- review (2A): `high` -- bounded diff input, needs thoroughness
- challenge (2B): `high` -- adversarial but bounded by diff size
- consult (2C): `medium` -- large context, interactive, needs speed

`xhigh` uses ~23x more tokens than `high` and can cause 50+ minute hangs on large
context tasks. users can override with `--xhigh` flag when they want maximum reasoning.

**web search:** all codex commands use `--enable web_search_cached` so codex can look up
docs and APIs during review.

if the user specifies a model (e.g., `/codex review -m gpt-5.1-codex-max`), pass the
`-m` flag through to codex.

---

## cost estimation

parse token count from stderr. codex prints `tokens used\nN` to stderr.
display as: `Tokens: N`
if not available, display: `Tokens: unknown`

---

## error handling

- **binary not found:** detected in step 0. stop with install instructions.
- **auth error:** surface: "codex authentication failed. run `codex login` to authenticate."
- **timeout:** "codex timed out after 5 minutes. the diff may be too large or the API may be slow."
- **empty response:** "codex returned no response. check stderr for errors."
- **session resume failure:** delete the session file and start fresh.

---

## important rules

- **never modify files.** this skill is read-only. codex runs in read-only sandbox mode.
- **present output verbatim.** do not truncate, summarize, or editorialize codex's output
  before showing it. show it in full inside the CODEX SAYS block.
- **add synthesis after, not instead of.** any claude commentary comes after the full output.
- **5-minute timeout** on all bash calls to codex (`timeout: 300000`).
- **no double-reviewing.** if the user already ran a review, codex provides a second
  independent opinion. do not re-run claude's own review.
- **detect skill-file rabbit holes.** after receiving codex output, scan for signs
  codex got distracted by skill files: `gstack-config`, `gstack-update-check`,
  `SKILL.md`, or `skills/gstack`. if found, append a warning: "codex appears to have
  read skill files instead of reviewing your code. consider retrying."
