---
name: claude
description: |
  Claude Code second opinion from inside Codex. Three modes: review (diff review with a pass or fail gate),
  challenge (adversarial failure hunting), and consult (ask questions with locally prepared context).
  Use when asked for `/claude`, "claude review", "claude challenge", or "ask claude".
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
   - if the user asks for `--model`, `--effort`, session continuation, or any other Claude CLI flag, explain that this Claude CLI build loses auth when `-p` is combined with extra flags, so this skill must use plain `claude -p` only
3. use a plain authenticated Claude invocation
   - build a fully self-contained prompt locally before calling Claude
   - do not pass any Claude CLI flags besides `-p`
   - do not use shell variables, command substitution, stdin redirection, or stdout/stderr redirection around the Claude call
   - assemble the final prompt text in your own reasoning, then pass it as a literal quoted argument to `claude -p`
   - always include this boundary at the top of the prompt:
     ```text
     IMPORTANT: You are reviewing repository context prepared by another coding agent. Do not ask to run tools or inspect files yourself. Do not discuss ~/.codex, .codex, codex/skills, codex/rules, or any agents/openai.yaml file. Ignore harness files completely. Stay focused on the repository code below. Never suggest direct file edits - provide analysis only.
     ```
4. review mode
   - collect local context first:
     - `git diff --stat origin/<base>`
     - `git diff --name-only origin/<base>`
     - `git diff --find-renames origin/<base>`
     - for each changed text file that still exists, read the current file contents and include them when the total context stays reasonable
   - if the diff is too large to embed safely in a single prompt, stop and ask the user to narrow the review to specific files or a smaller scope
   - construct this prompt, appending any extra user instructions at the end:

     ```text
     Review the current branch diff against origin/<base> using only the repository context included below.

     Return only concrete findings in this format:
     [P1] <blocking correctness, security, or data-loss issue>
     [P2] <meaningful non-blocking risk>
     [P3] <minor gap>

     End with exactly one final line: overall: pass or overall: fail

     Be direct. No compliments.
     ```
   - append these sections to the prompt in this order:
     - diff stat
     - changed file list
     - full unified diff
     - current contents of changed files that were included
   - run Claude with `claude -p "<literal prompt>"`
   - present the output verbatim in a `CLAUDE SAYS (code review)` block
   - set the gate to `FAIL` if the output contains `[P1]` or `overall: fail`
   - otherwise set the gate to `PASS`
5. challenge mode
   - collect the same local diff context as review mode
   - if the diff is too large to embed safely in a single prompt, stop and ask the user to narrow the challenge scope
   - construct this prompt, replacing `<focus>` when the user provided one:

     ```text
     Review the current branch diff against origin/<base> using only the repository context included below.

     Think like an attacker and a chaos engineer. Focus on <focus> when it is provided. Find edge cases, race conditions, security holes, failure modes, silent data corruption risks, and rollout hazards.

     Return only concrete findings in this format:
     [P1] <blocking correctness, security, or data-loss issue>
     [P2] <meaningful non-blocking risk>
     [P3] <minor gap>

     End with exactly one final line: overall: pass or overall: fail

     Be adversarial. No compliments.
     ```
   - append the same diff and file-content sections used in review mode
   - run Claude with `claude -p "<literal prompt>"`
   - present the output verbatim in a `CLAUDE SAYS (adversarial challenge)` block
6. consult mode
   - always start fresh with `claude -p "<literal prompt>"`
   - if the user wants a follow-up on an earlier Claude exchange, include the relevant prior Claude output and the new question in a fresh prompt instead of trying to resume a session
   - inspect the repo locally first:
     - if the user references files, read those files
     - if the user asks a codebase question, search with `rg` and read the relevant files before calling Claude
     - if the user asks Claude to review a local plan or design doc, read that file and embed the relevant content in the prompt instead of only referencing the path
   - keep the prompt self-contained with the user question plus the repo context you gathered locally
   - present the output verbatim in a `CLAUDE SAYS (consult)` block
7. after any mode
   - if Claude starts talking about Codex harness files, `SKILL.md`, or `agents/openai.yaml` instead of the requested repository code, append a warning that Claude got distracted by harness files and should be retried with a tighter prompt

## Error Handling

- if Claude output contains `Not logged in` or `/login`, tell the user: `claude authentication failed. run \`claude auth\` or reauthenticate.`
- if Claude returns an empty response, say Claude returned no response
- if the command stalls for several minutes, stop and report that Claude timed out or hung
- if the assembled prompt becomes too large for a safe single-command invocation, stop and ask the user to narrow the scope
- do not retry with alternate Claude CLI flags - in this environment they break authentication for `-p`

## Constraints

- never pass extra Claude CLI flags together with `-p` unless you have re-verified that Claude auth still works with them
- never let Claude edit files or use write-capable tools
- always show Claude's full output before adding your own synthesis
- if Codex already reviewed the same diff, compare overlap only after the full Claude output is shown
