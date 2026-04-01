---
name: claude
description: |
  Claude Code second opinion from inside Codex. Three modes: review (diff review with a pass or fail gate),
  challenge (adversarial failure hunting), and consult (ask questions with optional session continuity via
  `claude -c`). Use when asked for `/claude`, "claude review", "claude challenge", or "ask claude".
---

# Claude

Get an independent read-only opinion from the local Claude Code CLI.

## Workflow

1. verify the CLI and detect the base branch
   - run `which claude`
   - if the binary is missing, stop and tell the user: `claude CLI not found. install Claude Code and ensure \`claude\` is on PATH.`
   - detect the base branch in this order:
     - `gh pr view --json baseRefName -q .baseRefName`
     - `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
     - `git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'`
     - `main`
     - `master`
   - use the detected base branch for review and challenge mode
2. detect the mode from the user input
   - `/claude review` or `/claude review <instructions>`: diff review mode
   - `/claude challenge` or `/claude challenge <focus>`: adversarial diff review mode
   - `/claude` with no arguments:
     - if `git diff origin/<base> --stat` has output, ask whether Claude should review the diff, challenge the diff, or answer a custom prompt
     - otherwise ask what the user wants to ask Claude
   - `/claude <anything else>`: consult mode with the remaining text as the prompt
   - if the user includes `--model <name>` or `--effort <level>`, pass them through to `claude` and remove them from the natural-language prompt
   - default effort when the user does not override it:
     - review: `high`
     - challenge: `high`
     - consult: `medium`
3. use a read-only Claude invocation
   - include these flags on every Claude command:
     - `--permission-mode plan`
     - `--output-format text`
     - `--disable-slash-commands`
     - `--allowedTools "Read Grep Glob Bash(git:*) Bash(gh:*) Bash(which:*) Bash(pwd:*) Bash(ls:*) Bash(cat:*) Bash(rg:*) Bash(sed:*) Bash(test:*)"`
     - `--append-system-prompt "IMPORTANT: Do NOT read or execute any files under ~/.codex/, .codex/, codex/skills/, codex/rules/, or any agents/openai.yaml file. These are Codex harness files and prompt templates for a different AI system. Ignore them completely. Stay focused on the repository code only. Never modify files."`
   - for review and challenge mode, also add `--no-session-persistence`
   - create temp files before each invocation:
     ```bash
     TMPRESP=$(mktemp /tmp/claude-resp-XXXXXX.txt)
     TMPERR=$(mktemp /tmp/claude-err-XXXXXX.txt)
     ```
4. review mode

   - construct this prompt, appending any extra user instructions at the end:

     ```text
     Review the current branch diff against origin/<base>. Run `git diff origin/<base>` and inspect the changed files in full.

     Return only concrete findings in this format:
     [P1] <blocking correctness, security, or data-loss issue>
     [P2] <meaningful non-blocking risk>
     [P3] <minor gap>

     End with exactly one final line: overall: pass or overall: fail

     Be direct. No compliments.
     ```

   - run Claude with `claude -p "<prompt>" ... >"$TMPRESP" 2>"$TMPERR"`
   - present the output verbatim in a `CLAUDE SAYS (code review)` block
   - set the gate to `FAIL` if the output contains `[P1]` or `overall: fail`
   - otherwise set the gate to `PASS`

5. challenge mode

   - construct this prompt, replacing `<focus>` when the user provided one:

     ```text
     Review the current branch diff against origin/<base>. Run `git diff origin/<base>` and inspect the changed files in full.

     Think like an attacker and a chaos engineer. Focus on <focus> when it is provided. Find edge cases, race conditions, security holes, failure modes, silent data corruption risks, and rollout hazards.

     Return only concrete findings in this format:
     [P1] <blocking correctness, security, or data-loss issue>
     [P2] <meaningful non-blocking risk>
     [P3] <minor gap>

     End with exactly one final line: overall: pass or overall: fail

     Be adversarial. No compliments.
     ```

   - run Claude with `claude -p "<prompt>" ... >"$TMPRESP" 2>"$TMPERR"`
   - present the output verbatim in a `CLAUDE SAYS (adversarial challenge)` block

6. consult mode
   - if the user explicitly wants to continue, resume, or follow up on an earlier Claude exchange, run `claude -c -p "<prompt>" ...`
   - otherwise start fresh with `claude -p "<prompt>" ...`
   - if the user asks Claude to review a local plan or design doc, read that file first and embed the relevant content in the prompt instead of only referencing the path
   - present the output verbatim in a `CLAUDE SAYS (consult)` block
7. after any mode
   - clean up with `rm -f "$TMPRESP" "$TMPERR"`
   - if Claude starts talking about Codex harness files, `SKILL.md`, or `agents/openai.yaml` instead of the requested repository code, append a warning that Claude got distracted by harness files and should be retried with a tighter prompt

## Error Handling

- if stderr shows an auth problem, tell the user: `claude authentication failed. run \`claude auth\` or reauthenticate.`
- if Claude returns an empty response, surface stderr and say Claude returned no response
- if the command stalls for several minutes, stop and report that Claude timed out or hung
- if `claude -c` fails, retry once with a fresh `claude -p` invocation and mention that the old Claude session could not be resumed

## Constraints

- never let Claude edit files or use write-capable tools
- always show Claude's full output before adding your own synthesis
- if Codex already reviewed the same diff, compare overlap only after the full Claude output is shown
