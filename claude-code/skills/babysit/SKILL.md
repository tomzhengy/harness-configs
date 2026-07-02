---
name: babysit
description: Continuously babysit the user's open GitHub PRs from a dedicated loop session. Run /babysit in a fresh chat to start a perpetual loop - each cycle finds the user's open authored PRs, then for each one fixes failing CI, syncs/resolves base conflicts, addresses review-bot comments (Cursor Bugbot, Codex, Copilot), pushes, and replies on threads, then schedules the next cycle. Never merges, never opens duplicate PRs. Use when the user wants hands-off PR maintenance running on its own. Optional args - interval (default 15m) and a scope filter (org or owner/repo).
---

# babysit - recurring PR maintenance loop

Run this in a dedicated fresh chat. It turns the session into a perpetual PR
babysitter: each cycle does one maintenance pass over your open PRs, then
schedules the next cycle itself. Keep this session separate from the chat you
actually work in so its output never clutters your working session.

## invocation

`/babysit [interval] [scope]`

- `interval` - how often to run a cycle. e.g. `15m`, `30m`, `1h`. default `15m`.
  each tick is capped at 1h (ScheduleWakeup max).
- `scope` - optional filter for which PRs to babysit: a GitHub org (`freesolo-co`)
  or a single repo (`freesolo-co/flash`). default: all open PRs you authored.

parse these from the arguments given to /babysit. if none given, use the defaults.

## each cycle (what THIS session does)

Keep this session lean. Do not do the heavy scanning/fixing inline here - delegate
each PR to a subagent so the noisy work stays isolated and this session only
accumulates short summaries. Steps:

1. discover the target PRs authored by the user:
   `gh search prs --author @me --state open --json repository,number,title,url,headRefName`
   if a scope arg was given, filter to that org or repo. de-dupe. if there are no
   open PRs, print a one-line "no open PRs this cycle" and skip to scheduling.

2. for EACH open PR, spawn a subagent (Agent tool, general-purpose) and hand it the
   per-PR cycle brief below along with the PR's repo (owner/name), number, url, and
   head branch. run the subagents in parallel (one message, multiple Agent calls).
   each subagent does the full fix cycle and returns ONE tight line: what it found,
   what it did, and status.

3. print a compact summary for this cycle - one line per PR that had activity
   (repo#num - what was done - status). PRs with nothing to do get no line. end with
   a single counter line: `cycle done HH:MM - N PRs checked, M acted on`. do NOT
   reprint a growing cumulative table each cycle; one cycle, one short block.

4. schedule the next cycle (see "scheduling" below).

## per-PR cycle brief (what EACH subagent does)

You are babysitting one PR: `<repo> #<num>` on branch `<head>`. Fix what needs
fixing, push, reply to reviewers, and report back one line. Never merge.

1. gather everything that needs fixing on this PR:
   a. review-bot feedback: Copilot review, Cursor Bugbot, Codex review, plus any
   other PR review + inline comments. when reading inline comments
   (`gh api repos/<repo>/pulls/<num>/comments`), capture each comment's `id`
   alongside its path/line/body so you can post a threaded reply later (step 4).
   b. failing CI / status checks: `gh pr checks <num> --repo <repo>`. for any
   failing check, read its logs (`gh run view <run-id> --log-failed`) to find the
   root cause.
   c. build issues: check out the PR branch locally and confirm it builds/typechecks
   with the repo's own tooling (bun install + bun run build / tsc / biome / lint /
   tests). reproduce failures locally when possible.
   d. base sync / merge conflicts:
   `gh pr view <num> --repo <repo> --json mergeable,mergeStateStatus,baseRefName`.
   use the PR's actual baseRefName (some repos target `dev`, not `main`).
   mergeStateStatus BEHIND = base advanced with no conflicts; mergeable
   CONFLICTING / mergeStateStatus DIRTY = real conflicts with base.

2. BEFORE making any code change (including resolving conflicts), recover the
   originating Claude session that built this PR so you fix things with full intent
   and in the same working style:
   - build distinctive search strings: the branch name, the worktree path it was
     developed in (PRs are built in `.claude/worktrees/<name>` worktrees), changed
     file paths, and distinctive symbols from the diff.
   - `rg -l --glob '*.jsonl' "<branch>|<distinctive-symbol>|<changed-file>" /Users/minitom/.claude/projects/`
   - transcripts live at `/Users/minitom/.claude/projects/<cwd-slug>/<session-uuid>.jsonl`
     (cwd-slug = working dir with `/` replaced by `-`). the most relevant are usually
     under the PR's worktree slug and the repo's main slug. EXCLUDE this babysit
     session's own transcript so you don't just re-read your own notes.
   - read the matching transcript(s): extract the human's real instructions/intent
     (lines with `"type":"user"` that are real text, not tool_result or `<...>`
     synthetic messages) and the assistant's key decisions. understand WHY the code
     is shaped this way before changing it. if a finding contradicts a deliberate,
     documented design choice, prefer flagging it over overriding it.
   - if no originating session is found, note that and proceed from the PR
     description and code comments.

3. apply fixes, guided by the recovered intent, in a checkout/worktree of the PR
   branch:
   - review bots: make the changes that are clearly correct and in scope.
   - CI / build: fix build errors, type errors, lint failures, and failing checks so
     they go green.
   - base sync: if BEHIND base (base advanced, no conflicts), merge base in -
     `git fetch origin <base>` then `git merge origin/<base>` (or
     `gh pr update-branch <num> --repo <repo>`) - then re-run the repo's build/tests
     and push.
   - merge conflicts: if CONFLICTING, merge `origin/<base>` into the PR branch
     locally and resolve guided by the recovered intent and each side's purpose; run
     the repo's tests/build to confirm the resolution before committing. if any
     resolution is ambiguous or risky, do NOT guess - `git merge --abort`, leave the
     branch untouched, and flag it with the specific conflicting files.
   - skip suggestions or "fixes" that are wrong, risky, out of scope, or ambiguous,
     and note why. do not paper over a real failure (e.g. do not delete or skip a
     legitimately failing test just to make CI pass) - fix the underlying cause; if
     unclear, leave it for the next cycle with a note.

4. commit (conventional commit style: lowercase prefix like fix/chore/feat/merge,
   one-liner, no signatures or co-authored-by lines) and push back to the PR branch.
   then, for EVERY review-bot finding you acted on this cycle, REPLY on that exact
   comment thread - both for findings you fixed AND for findings you deliberately
   did not change:
   - inline review comment: threaded reply with
     `gh api --method POST repos/<repo>/pulls/<num>/comments/<comment_id>/replies -f body="<reply>"`
     using the `id` you captured in step 1a.
   - fixed: state what changed and the commit SHA, e.g. "Fixed in <sha>: <one-line>."
   - deliberately not changed: reply with the disposition and reason, e.g.
     "Won't change: <reason>." or "Already handled in <sha>." or "Flagged as a
     follow-up: <reason>."
   - PR-level summary review (not anchored to a line): reply as a normal issue
     comment: `gh api --method POST repos/<repo>/issues/<num>/comments -f body="..."`.
   - keep replies to one or two sentences. do NOT reply to deploy/CI bot noise
     (vercel, mintlify), to already-resolved/outdated comments you did not act on
     this cycle, or on a PR another active session is currently driving (there, only
     flag - do not act).

5. return ONE line: `<repo>#<num> - <what you did this cycle> - <status>`. if nothing
   needed doing, return `<repo>#<num> - clean`.

hard rules for every subagent:

- never merge the PR (no `gh pr merge`, no auto-merge, no `/merge`). fix, push, reply
  only - the user does the final merge.
- never open a new PR for the same work; push all fixes to the existing PR branch.
  you MAY note (not open) a genuinely orthogonal in-scope issue for the user.
- do not touch a PR that is already merged or closed.

## scheduling the next cycle

After printing this cycle's summary, keep the loop alive: call ScheduleWakeup with
`delaySeconds` = the interval in seconds (15m = 900, 30m = 1800, 1h = 3600, capped at
3600), `prompt` = `/babysit <interval> <scope>` (pass the same interval and scope so
the next tick repeats identically), and a one-line `reason` like
"next PR babysit cycle in <interval>". This is /loop dynamic mode - each tick does one
pass then reschedules, so running /babysit once keeps it going until you stop the
session. Always reschedule, even on a "no open PRs" cycle, so newly opened PRs get
picked up.
