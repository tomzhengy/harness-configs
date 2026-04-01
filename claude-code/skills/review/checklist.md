# pre-landing review checklist

## instructions

review the `git diff origin/<base>` output for the issues listed below. be specific, cite
`file:line` and suggest fixes. skip anything that's fine. only flag real problems.

**two-pass review:**

- **pass 1 (CRITICAL):** SQL & data safety, race conditions, LLM output trust boundary,
  shell injection, enum completeness. highest severity.
- **pass 2 (INFORMATIONAL):** remaining categories. lower severity but still actioned.

all findings get action via fix-first review: obvious mechanical fixes are applied
automatically, genuinely ambiguous issues are batched into a single user question.

**output format:**

```
Pre-Landing Review: N issues (X critical, Y informational)

**AUTO-FIXED:**
- [file:line] Problem -> fix applied

**NEEDS INPUT:**
- [file:line] Problem description
  Recommended fix: suggested fix
```

if no issues found: `Pre-Landing Review: No issues found.`

be terse. for each issue: one line describing the problem, one line with the fix.
no preamble, no summaries, no "looks good overall."

---

## review categories

### pass 1 -- CRITICAL

#### SQL & data safety

- string interpolation in SQL (even if values are `.to_i`/`.to_f`, use parameterized queries)
- TOCTOU races: check-then-set patterns that should be atomic `WHERE` + `update_all`
- bypassing model validations for direct DB writes (Rails: update_column; Django: QuerySet.update(); Prisma: raw queries)
- N+1 queries: missing eager loading for associations used in loops/views

#### race conditions & concurrency

- read-check-write without uniqueness constraint or catch duplicate key error and retry
- find-or-create without unique DB index, concurrent calls can create duplicates
- status transitions that don't use atomic `WHERE old_status = ? UPDATE SET new_status`
- unsafe HTML rendering (.html_safe/raw/dangerouslySetInnerHTML/v-html) on user-controlled data (XSS)

#### LLM output trust boundary

- LLM-generated values (emails, URLs, names) written to DB or passed to mailers without format validation
- structured tool output (arrays, hashes) accepted without type/shape checks before database writes
- LLM-generated URLs fetched without allowlist (SSRF risk)
- LLM output stored in knowledge bases or vector DBs without sanitization (stored prompt injection)

#### shell injection

- `subprocess.run()` / `subprocess.call()` / `subprocess.Popen()` with `shell=True` AND f-string interpolation
- `os.system()` with variable interpolation, replace with `subprocess.run()` using argument arrays
- `eval()` / `exec()` on LLM-generated code without sandboxing

#### enum & value completeness

when the diff introduces a new enum value, status string, tier name, or type constant:

- **trace it through every consumer.** read (don't just grep) each file that switches on,
  filters by, or displays that value. if any consumer doesn't handle the new value, flag it.
- **check allowlists/filter arrays.** search for arrays containing sibling values and verify
  the new value is included where needed.
- **check `case`/`if-elsif` chains.** if existing code branches on the enum, does the new
  value fall through to a wrong default?
- this step requires reading code OUTSIDE the diff. use grep to find all references to
  sibling values, then read those files.

### pass 2 -- INFORMATIONAL

#### async/sync mixing (python)

- synchronous `subprocess.run()`, `open()`, `requests.get()` inside `async def` endpoints
- `time.sleep()` inside async functions, use `asyncio.sleep()`
- sync DB calls in async context without `run_in_executor()` wrapping

#### column/field name safety

- verify column names in ORM queries against actual DB schema
- check `.get()` calls on query results use the column name that was actually selected

#### dead code & consistency

- version mismatch between PR title and VERSION/CHANGELOG files
- CHANGELOG entries that describe changes inaccurately

#### LLM prompt issues

- 0-indexed lists in prompts (LLMs reliably return 1-indexed)
- prompt text listing available tools/capabilities that don't match what's wired up
- word/token limits stated in multiple places that could drift

#### completeness gaps

- shortcut implementations where the complete version would cost <30 minutes
- test coverage gaps where adding missing tests is straightforward
- features implemented at 80-90% when 100% is achievable with modest additional code

#### time window safety

- date-key lookups that assume "today" covers 24h
- mismatched time windows between related features

#### type coercion at boundaries

- values crossing Ruby->JSON->JS boundaries where type could change (numeric vs string)
- hash/digest inputs that don't call `.to_s` before serialization

#### view/frontend

- inline `<style>` blocks in partials (re-parsed every render)
- O(n\*m) lookups in views (Array#find in a loop instead of index_by hash)
- Ruby-side `.select{}` filtering on DB results that could be a `WHERE` clause

#### distribution & CI/CD pipeline

- CI/CD workflow changes: verify build tool versions, artifact names, secrets use `${{ secrets.X }}`
- new artifact types: verify a publish/release workflow exists
- version tag format consistency (`v1.2.3` vs `1.2.3`)

#### test gaps

- new code paths without corresponding tests
- error/edge case paths not covered
- regression tests missing for bug fixes

#### magic numbers & string coupling

- hardcoded numeric values that should be named constants
- string literals used as keys/identifiers in multiple places without a shared constant

#### conditional side effects

- side effects (emails, webhooks, billing charges) inside conditions that could fire unexpectedly
- missing guards on destructive operations

#### performance

- queries inside loops (N+1 pattern)
- missing database indexes on frequently queried columns
- unbounded collection operations (.all without pagination)
- large file reads without streaming

#### crypto & entropy

- `rand()` / `Math.random()` for security-sensitive values instead of SecureRandom/crypto
- `==` for comparing secrets/tokens instead of constant-time comparison
- truncating data instead of hashing for uniqueness

---

## severity classification

```
CRITICAL (blocking):                  INFORMATIONAL (advisory):
|- SQL & data safety                  |- async/sync mixing
|- race conditions & concurrency      |- column/field name safety
|- LLM output trust boundary          |- dead code & consistency
|- shell injection                    |- LLM prompt issues
|- enum & value completeness          |- completeness gaps
                                      |- time window safety
                                      |- type coercion at boundaries
                                      |- view/frontend
                                      |- distribution & CI/CD
                                      |- test gaps
                                      |- magic numbers & string coupling
                                      |- conditional side effects
                                      |- performance
                                      |- crypto & entropy
```

---

## fix-first heuristic

determines whether the agent auto-fixes a finding or asks the user.

```
AUTO-FIX (agent fixes without asking):     ASK (needs human judgment):
|- dead code / unused variables            |- security (auth, XSS, injection)
|- N+1 queries (missing eager loading)     |- race conditions
|- stale comments contradicting code       |- design decisions
|- magic numbers -> named constants        |- large fixes (>20 lines)
|- missing LLM output validation           |- enum completeness
|- version/path mismatches                 |- removing functionality
|- variables assigned but never read       |- anything changing user-visible
|- inline styles, O(n*m) view lookups        behavior
```

**rule of thumb:** if the fix is mechanical and a senior engineer would apply it without
discussion, it's AUTO-FIX. if reasonable engineers could disagree, it's ASK.

**critical findings default toward ASK** (inherently riskier).
**informational findings default toward AUTO-FIX** (more mechanical).

---

## confidence calibration

before including a finding, ask yourself:

- have i READ the surrounding code (not just the diff hunk)?
- could this be intentional? (check for comments, related tests, or documented reasons)
- is there a framework guarantee that makes this safe?
- am i confident enough to bet $100 on this being a real bug?

if the answer to the last question is no, either investigate further or skip it.
uncertain findings waste the user's time and erode trust.

---

## suppressions -- DO NOT flag these

- "X is redundant with Y" when the redundancy is harmless and aids readability
- "add a comment explaining why this threshold/constant was chosen"
- "this assertion could be tighter" when the assertion already covers the behavior
- suggesting consistency-only changes (wrapping a value to match how another is guarded)
- "regex doesn't handle edge case X" when the input is constrained and X never occurs
- "test exercises multiple guards simultaneously" (that's fine)
- eval threshold changes (tuned empirically, change constantly)
- harmless no-ops (e.g., `.reject` on an element never in the array)
- ANYTHING already addressed in the diff you're reviewing (read the FULL diff first)

---

## design review checklist (frontend files only)

only apply if the diff touches frontend files (.tsx, .jsx, .vue, .svelte, .css, .scss, .html).

### AI slop detection

- purple/violet/indigo gradient backgrounds or blue-to-purple color schemes
- the 3-column feature grid: icon-in-colored-circle + bold title + 2-line description, repeated 3x
- icons in colored circles as section decoration
- `text-align: center` on all headings, descriptions, and cards (>60% center alignment)
- uniform bubbly border-radius on every element (same large radius 16px+ everywhere)
- generic hero copy: "Welcome to", "Unlock the power of", "Your all-in-one solution"

### typography

- body text font-size < 16px
- more than 3 font families in the diff
- heading hierarchy skipping levels (h1 followed by h3 without h2)

### spacing & layout

- fixed widths without responsive handling
- missing max-width on text containers (lines >75 chars)
- `!important` in new CSS rules

### interaction states

- interactive elements missing hover/focus states
- `outline: none` without replacement focus indicator (accessibility)

### DESIGN.md violations (if DESIGN.md exists)

- colors not in the stated palette
- fonts not in the stated typography section
- spacing values outside the stated scale
