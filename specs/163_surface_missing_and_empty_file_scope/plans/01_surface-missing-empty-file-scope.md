# Implementation Plan: Task #163

- **Task**: 163 - Surface missing and empty file_scope
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/163_surface_missing_and_empty_file_scope/reports/01_missing-empty-file-scope-visibility.md
- **Artifacts**: plans/01_surface-missing-empty-file-scope.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

An absent, literal-null, empty, or glob-shaped `file_scope` is invisible to every existing
detector: `validate-state.sh` Checks 8/9 default absent values away with `.file_scope // []`, and
`orchestrate-predispatch-review.sh` Class B flags a present-but-literal-null value only, by
documented design. This plan adds four new WARN-only detectors — two checks in
`validate-state.sh` (missing/empty/null, and glob-shaped entries) and two new report classes in
`orchestrate-predispatch-review.sh` (F and G) — plus a `--strict` flag on `validate-state.sh`
mirroring `validate-artifact.sh`'s advisory-first precedent, and fixture-based regression tests
for all of it. Definition of done: default-mode `validate-state.sh` reports the missing/empty
count and still exits 0; the promotion criterion is written into the script header; the
predispatch review surfaces absent scope in a new class; no repair path manufactures `[]` on an
absent key; both scripts stay shellcheck-clean at the current baseline.

### Research Integration

The research report (`reports/01_missing-empty-file-scope-visibility.md`) changes three things
about the dispatch's own framing, and this plan follows the report:

1. **The addendum's "Class C" instruction is a drafting slip.** Classes A-E are already occupied
   in `orchestrate-predispatch-review.sh`; Class C is self-modification / declaration coarseness.
   New classes **F** (missing/empty/null) and **G** (glob) are used instead. This is recorded as
   decision D3 below, not silently substituted.
2. **Glob entries are not "invalid" and must not be rejected as such.** `file-footprint-overlap.md`'s
   Non-Goals section deliberately excludes glob matching from the symmetric Overlap predicate,
   while the separate Containment predicate (`path_covered_by_scope()`, consumed by
   `git-snapshot.sh`) already matches globs correctly. The WARN wording is therefore "invisible to
   overlap-based collision detection," never "forbidden syntax" (decision D6).
3. **The dispatch's cited counts (37/38, 27/49, 22/17/5) no longer reproduce** — both corpora are
   live, continuously-orchestrated trackers; this repo reads 1-of-29 non-terminal today.
   Exact-count assertions go against hand-crafted fixtures (this suite's existing Check 8/9
   convention); any run against a live `specs/state.json` is an informational measurement, never a
   test assertion (decision D9).

Also carried forward: `validate-state.sh` has **no `--strict` flag today** (only `--deep`,
`--fix`, `--session-id`, `--allow-artifact-removal`), so replicating `validate-artifact.sh`'s
three-part rollout means adding the flag itself — its own phase, not a one-liner. Both target
scripts are already correctly strict-mode classified (`validate-state.sh` Class B, `set -uo
pipefail`; `orchestrate-predispatch-review.sh` Class A, `set -euo pipefail`) and both are clean at
`shellcheck --severity=warning` today; two pre-existing info-level notes (SC1091, SC2016) are the
baseline, not regressions to fix here.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- `validate-state.sh` gains **Check 10** (missing / literal-null / empty-array `file_scope`,
  reported as three distinguishable sub-states with counts) and **Check 11** (glob-shaped entry),
  both WARN-only in default mode over non-terminal `active_projects[]`, matching Check 8/9's
  population.
- The advisory-first promotion criterion for both new checks is written verbatim into
  `validate-state.sh`'s own header comment block, citing `plan-format.md`'s Enforcement level
  subsection as the precedent — and is **not** promoted by this task.
- `validate-state.sh` gains a `--strict` flag whose semantics copy `validate-artifact.sh`'s
  exactly (warnings become exit-blocking), so the new checks are enforceable today by an opt-in
  caller.
- `orchestrate-predispatch-review.sh` gains **Class F** (missing/empty/null `file_scope` on a
  batch candidate) and **Class G** (glob-shaped entry on a batch candidate), matching Classes
  C/D/E's report shape (header always printed, explicit "0 findings" negative, never omitted).
- No repair path ever manufactures `file_scope: []` on an absent key — asserted by a regression
  test, not just by inspection.
- One shared jq `def is_glob_entry` added to `FILE_SCOPE_OVERLAP_JQ_DEFS`, reusing the same
  `*`/`?`/`[` character class as the two existing bash transcriptions, instead of a third
  independent transcription.
- Fixture-based regression coverage for every new check and class, in the two existing suites.

**Non-Goals**:
- **No promotion of any new WARN to an error in default mode.** The promotion criterion is
  recorded for a future task, per the `validate-artifact.sh` precedent the dispatch names as
  binding.
- **No change to admission behavior.** `orchestrate-batch-admit.sh` is not edited; neither new
  class excludes, defers, or writes. `orchestrate-cycle-plan.sh`'s Decision 4 deferral of
  "should a coarse/absent/glob scope affect admission" stays deferred.
- **No change to the Overlap predicate itself.** `scopes_overlap_first` is not taught about
  globs; `file-footprint-overlap.md`'s Non-Goals section stands.
- **No edit to `orchestrate-cycle-plan.sh`.** The research report's suggested cross-reference
  pointer comment at its existing bash glob transcription is deliberately deferred: that file is
  inside concurrent sibling task 199's declared `file_scope` this same cycle.
- **No `--repair`/`--fix` extension.** Neither new class nor check gains a repair branch.
- No fix of the two pre-existing shellcheck info-level notes (SC1091, SC2016).

## Decisions

Recorded here because the dispatch explicitly requires the rulings be written down; each is also
transcribed into the relevant script's header comment during the phase that implements it.

- **D1 — Two new checks, not a widened Check 8/9.** Checks 8 and 9 answer different questions
  (blast radius; intra-array duplication) and both legitimately operate on an entry *list*.
  Absence is a property of the field, not of an entry, so it gets its own check. New Check 10
  (missing/empty/null) and Check 11 (glob), appended after Check 9, over the same non-terminal
  population.
- **D2 — EMPTY vs ABSENT are distinct states, and all three variants warn, distinguishably.**
  Check 10 reports three separately-labelled sub-states with their own counts: *missing key* (an
  omission), *literal null* (a schema-default violation, already Class B's territory in the other
  script), and *empty array* (possibly a deliberate "this task touches nothing" assertion). All
  three warn, because the task title covers "and empty"; they are labelled separately so a future
  promotion can bind to the first two only. Supporting data point recorded alongside the ruling:
  the historical BimodalLogic measurement of "22 lacking a usable value" tallied missing-key plus
  literal-null and excluded empty-array — i.e. the original measurement itself already treated
  empty-array as the lesser concern.
- **D3 — Class F and Class G, never "Class C".** The 2026-09-22 addendum says to surface glob
  entries in "Class C", but Class C has since been established as self-modification / declaration
  coarseness. Reusing the letter would splice unrelated findings into an existing, documented
  section. New letters F (missing/empty/null) and G (glob) are used, and this correction is
  recorded in the script header so it is not mistaken for an unexplained deviation from the
  dispatch.
- **D4 — Absent is not null for repair purposes; neither new detector touches a repair path.**
  `--fix` in `validate-state.sh` is already gated behind `if has("file_scope")`, and `--repair` in
  `orchestrate-predispatch-review.sh` matches on `== null`, which an absent key does not satisfy
  in jq. Both remain untouched: no new field is added to `--repair`'s field list, and no
  `// null`-style widening is introduced. Normalizing an absent key to `[]` would manufacture an
  empty declaration that then looks deliberate — worse than the absence it replaces.
- **D5 — `--strict` is added to `validate-state.sh`, copying `validate-artifact.sh` exactly.**
  The same `total_issues=$((errors + warnings))`-vs-`total_issues=$errors` branch, global in
  scope. Documented consequence, stated in the header rather than hidden: under `--strict`, the
  pre-existing Check 8 and Check 9 warnings also become exit-blocking. This is safe today —
  no caller passes `--strict` (enumerated in Phase 4).
- **D6 — Glob WARN wording is "invisible to overlap-based collision detection", not "invalid".**
  A glob entry is already correctly matched by the Containment predicate; only the symmetric
  Overlap predicate (Check 8, Classes C/D/E) is deliberately glob-free. The message names the
  concrete consequence and suggests declaring a directory or file entry when collision detection
  must see it.
- **D7 — One shared jq `def is_glob_entry` in `FILE_SCOPE_OVERLAP_JQ_DEFS`.** Same `*`/`?`/`[`
  character class as `path_covered_by_scope()`'s and `_sibling_territory_classify_entry()`'s
  existing bash transcriptions, so the forms cannot silently diverge on what counts as
  glob-shaped.
- **D8 — Scope extension beyond the declared `file_scope`, recorded deliberately.** The task's
  declared `file_scope` names the two scripts. D7 additionally requires
  `scripts/lib/file-scope-overlap.sh`, and the test phases require
  `scripts/tests/test-validate-state.sh` and `scripts/tests/test-orchestrate-predispatch-review.sh`.
  None of the four collides with any concurrent sibling's declared scope (139, 162, 244, 43, 199,
  207, 167 — checked against this dispatch's Territory block).
- **D9 — Exact counts are fixture-asserted; live runs are measurements.** No test asserts a
  literal count against any live `specs/state.json`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new jq `def` spliced into `FILE_SCOPE_OVERLAP_JQ_DEFS` collides with a name in one of the four consumer programs | H | L | Phase 1 enumerates and re-runs every consumer (`validate-state.sh`, `orchestrate-predispatch-review.sh`, `orchestrate-batch-admit.sh`, `task-lock.sh`) before closing; `interface` tier |
| Hardcoding the dispatch's stale counts (38/49/22/17/5) into a test or acceptance check | M | M | D9: fixtures carry all exact assertions; the live run in Phase 8 reports whatever the then-current number is |
| Wording the glob WARN as a rejection, contradicting `file-footprint-overlap.md`'s Non-Goals | M | M | D6 fixes the wording; Phase 3 re-reads the Non-Goals section before authoring the message |
| A future `--repair` widening normalizes absent keys to `[]` | H | L | D4 keeps both detectors out of the repair paths; Phase 6 adds an explicit regression test that `--fix` does not add a `file_scope` key to an entry lacking one |
| `--strict` silently promotes pre-existing Check 8/9 warnings for an unsuspecting caller | M | M | D5 documents the consequence in the header; Phase 4 enumerates callers and confirms none passes `--strict` |
| Sibling task edits the same tree this cycle | M | M | Re-read each target immediately before editing; commit only this task's own hunks; never a directory or glob `git add`; `orchestrate-cycle-plan.sh` (task 199's territory) is explicitly out of scope |
| Reusing Class letter C per the addendum's literal text | M | L | D3, recorded in the script header as an explicit correction |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 2, 3 |
| 5 | 6, 7 | 4, 5 |
| 6 | 8 | 6, 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Shared `is_glob_entry` jq def [COMPLETED]

**Goal**: One canonical glob-shape predicate exists in jq, in the same library that already owns
`norm`/`scopes_overlap_first`, so Checks 11 and Class G both consume it rather than transcribing
a third copy.

**Tasks**:
- [x] Re-read `scripts/lib/file-scope-overlap.sh`'s `FILE_SCOPE_OVERLAP_JQ_DEFS` heredoc (quoted
      `<<'JQDEFS'` — no bash expansion occurs inside it) immediately before editing. *(completed)*
- [x] Add `def is_glob_entry: test("[*?\\[]");` to the heredoc with a comment stating: the
      character class is identical to `path_covered_by_scope()`'s and
      `_sibling_territory_classify_entry()`'s existing bash `case` transcriptions; a glob entry is
      invisible to the symmetric Overlap predicate **by design** per
      `context/patterns/file-footprint-overlap.md`'s Non-Goals, while the Containment predicate in
      this same file already matches it. *(completed)*
- [x] Enumerate every splicing consumer and confirm each still runs unchanged: `validate-state.sh`
      (Check 8, Check 9), `orchestrate-predispatch-review.sh` (Classes C/D/E), the
      `scopes_overlap()` bash wrapper in this same library, plus any other file found live by
      `grep -rl FILE_SCOPE_OVERLAP_JQ_DEFS agent-system/extensions`.
      *(deviation: altered — the actual `grep -rl` consumer set is 11 files, wider than this
      plan's hypothesized 4. CORRECTION TO PLAN PREMISE: `orchestrate-predispatch-review.sh` does
      NOT splice `FILE_SCOPE_OVERLAP_JQ_DEFS` anywhere today (confirmed:
      `grep -c FILE_SCOPE_OVERLAP_JQ_DEFS scripts/orchestrate-predispatch-review.sh` → 0); Classes
      C/D/E re-present `orchestrate-batch-admit.sh` subprocess verdicts and never splice the jq
      defs directly. This plan's own research-report input (`reports/01_...md`) asserted "both
      target scripts already splice this variable in," which is false for this script. Phase 5
      must therefore ADD sourcing of `file-scope-overlap.sh` to
      `orchestrate-predispatch-review.sh` (mirroring `validate-state.sh`'s deploy-tree-first /
      source-store-fallback pattern) before Class G can consume `is_glob_entry` — this is a new
      task, not a reuse of an existing splice. Most other consumers
      (`orchestrate-batch-admit.sh`, `task-lock.sh`, `orchestrate-cycle-plan.sh`,
      `git-snapshot.sh`, `system-defect-record.sh`, `update-task-status.sh`) are gated by
      `deploy-root-guard.sh` and refuse to run from this source-store tree, so "runs unchanged"
      was verified via: no duplicate `def is_glob_entry` anywhere (grep), `bash -n` on all 9
      non-library consumer files (all unedited, so unaffected by construction), a direct jq
      sanity check of the new def in isolation, and `validate-state.sh` (the one consumer
      runnable from the source store) executed end-to-end with byte-identical Check 8/9 output
      at exit 0.*
- [x] Sanity-check the predicate directly: `is_glob_entry` true for `*/agents/**`, `a?b`,
      `x[0].sh`; false for `a/b/c.sh` and `a/b/`. *(completed: confirmed via `jq -n` with the
      sourced library — all five cases match expectation)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: the consumer set of `FILE_SCOPE_OVERLAP_JQ_DEFS` is hypothesized to be
`validate-state.sh`, `orchestrate-predispatch-review.sh`, `orchestrate-batch-admit.sh`,
`task-lock.sh`, and this library's own `scopes_overlap()`. Confirm at implementation time with
`grep -rln 'FILE_SCOPE_OVERLAP_JQ_DEFS' agent-system/extensions` and re-run each hit found,
including any not listed here.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` - add `is_glob_entry` def plus
  its cross-reference comment inside the existing quoted heredoc

**Verification**:
- Every consumer enumerated above executes without a jq syntax or duplicate-definition error.
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` still exits 0
  with Check 8/9 output byte-identical to a pre-edit capture.
- `shellcheck --severity=warning` on the library is clean.

---

### Phase 2: `validate-state.sh` Check 10 — missing / null / empty `file_scope` [COMPLETED]

**Goal**: Default-mode `validate-state.sh` reports, as three distinguishable WARN sub-states with
counts, every non-terminal task whose `file_scope` is absent, literal null, or an empty array —
and still exits 0.

**Tasks**:
- [x] Re-read `validate-state.sh` around Check 8/Check 9 immediately before editing. *(completed)*
- [x] Add Check 10 after Check 9, following Check 9's exact shape: a `_check10_prog` jq program
      string, `jq -c` into a findings variable, a `length` count, a `log_pass` negative branch,
      and `while IFS=$'\t' read -r ... done < <(jq -r ... @tsv)` WARN loops. *(completed)*
- [x] Classify each non-terminal entry into exactly one of `missing_key`
      (`has("file_scope") | not`), `null_value` (`.file_scope == null`), `empty_array`
      (`.file_scope == []`); emit one WARN line per finding naming the `project_number`, the
      sub-state, and the `project_name`, plus one summary WARN line carrying the three counts and
      the non-terminal denominator. *(completed)*
- [x] Use the same non-terminal filter as Check 8 (`status` not in
      `{completed, abandoned, expanded}`), reusing its `is_terminal` def shape. *(completed)*
- [x] Cap the per-finding WARN list the way Check 8 does (first 10, then an "... and N more" line).
      *(completed)*
- [x] Extend the header comment's `# Base-mode checks (always run):` list with a Check 10 entry
      recording decision **D2** (empty vs absent vs null, all warn, separately labelled, with the
      historical-measurement data point) and the **promotion criterion**: promote the
      missing-key and literal-null sub-states from WARN to FAIL once no non-terminal task under
      `specs/` lacks a usable `file_scope`; the empty-array sub-state stays advisory indefinitely
      because an explicit `[]` may be a deliberate assertion. Cite `plan-format.md`'s
      `### Enforcement level` subsection as the precedent and state explicitly that this task does
      not perform the promotion. *(completed: also wrote the Check 11 header paragraph in the
      same edit, ahead of Phase 3's own script-body addition, for header prose contiguity — see
      Phase 3's own checklist for the corresponding decision)*
- [x] Confirm the Exit-codes header block still reads true (`Checks 8 and 9 ... are WARN-only`
      becomes `Checks 8, 9, 10 and 11`; leave the `--strict` mention to Phase 4). *(completed:
      also found and fixed a real regression this header growth exposed — see deviation below)*
- [x] *(deviation: altered — additional necessary fix not in the original task list)* The
      `--help` handler used a hardcoded `sed -n '2,107p' "$0"` range that went stale and silently
      truncated `--help` output partway through the `--deep mode` section the moment the header
      grew past its old end line (confirmed by running `--help` before the fix: it cut off
      mid-list). Replaced with a dynamic range,
      `awk 'NR==1{next} /^#/{print; next} {exit}' "$0"`, that reads every leading `#`-comment line
      from line 2 to the first non-`#` line and cannot go stale again as Phase 3/4 grow the header
      further. Verified: `--help` now prints the complete header (128 lines) including the
      previously-truncated `--deep mode additionally checks:` list.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this repo's live `specs/state.json` is hypothesized to yield exactly one
missing-key finding and zero null/empty findings among non-terminal entries. Confirm by running
the new check at implementation time and reporting whatever it returns — a different number is a
measurement, not a failure (D9).

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - new Check 10 block; header
  `Base-mode checks` list entry with the D2 ruling and the promotion criterion

**Verification**:
- `bash .../validate-state.sh specs/state.json` exits 0, prints the Check 10 summary WARN with
  three counts, and prints the per-finding WARN for the missing-key entry.
- A state file whose every non-terminal entry declares a non-empty `file_scope` produces the
  Check 10 `log_pass` line and no Check 10 WARN.
- `shellcheck --severity=warning` on the script is clean.

---

### Phase 3: `validate-state.sh` Check 11 — glob-shaped `file_scope` entries [NOT STARTED]

**Goal**: A glob-shaped entry is named in a WARN that states the real consequence — invisibility
to the Overlap-based checks — without claiming the shape is invalid.

**Tasks**:
- [ ] Re-read `context/patterns/file-footprint-overlap.md`'s Non-Goals section and this script's
      Check 8 block immediately before authoring the message text.
- [ ] Add Check 11 after Check 10, splicing `FILE_SCOPE_OVERLAP_JQ_DEFS` and using
      `is_glob_entry` from Phase 1 (never a locally re-derived regex).
- [ ] Scope to non-terminal `active_projects[]`, matching Checks 8/9/10.
- [ ] WARN message names the `project_number` and the offending entry verbatim, and states:
      this entry is never compared by the overlap-based checks (Check 8's coarseness scan, and
      `orchestrate-predispatch-review.sh` Classes C/D/E), so it collides with nothing; declare a
      directory or file entry if collision detection must see it. It must **not** say the entry is
      invalid or forbidden (**D6**).
- [ ] Add the Check 11 entry to the header `Base-mode checks` list, with its own promotion
      criterion: advisory indefinitely, since globs remain legitimate for the Containment
      consumer — recorded explicitly so a future reader does not mistake the absence of a
      promotion bar for an oversight.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - new Check 11 block; header
  `Base-mode checks` list entry

**Verification**:
- A fixture with a `*/agents/**` entry produces the named Check 11 WARN and exit 0.
- This repo's live `specs/state.json` produces the Check 11 `log_pass` negative (0 glob entries
  among non-terminal entries, per the research measurement — reconfirm, do not assume).
- `shellcheck --severity=warning` clean.

---

### Phase 4: `--strict` flag on `validate-state.sh` [NOT STARTED]

**Goal**: An opt-in caller can make warnings — including Checks 10 and 11 — exit-blocking today,
exactly as `validate-artifact.sh --strict` already does, without changing default-mode behavior
for any existing caller.

**Tasks**:
- [ ] Re-read `scripts/validate-artifact.sh`'s `--strict` parsing and its `total_issues` exit
      branch, and copy that shape rather than inventing a variant.
- [ ] Add `--strict` to `validate-state.sh`'s argument-parsing `case`, its `--help` text, and its
      `# Usage:` header block.
- [ ] Change the final exit branch so that under `--strict` the accumulated `WARNINGS` count joins
      `FAILED` in the exit-blocking total, and print a distinguishable summary line naming that
      strict mode caused the failure.
- [ ] Update the `# Exit codes:` header block: exit 1 also covers "at least one WARN-level finding
      under `--strict`".
- [ ] Record decision **D5** in the header, including the explicit consequence that pre-existing
      Check 8 and Check 9 warnings also become blocking under `--strict`.
- [ ] Enumerate every live caller and confirm none passes `--strict`, so default behavior is
      unchanged: `commands/task.md` (base mode, greps `file_scope` lines out of the output),
      `verify-deploy.sh` gate 10 (`--deep`), `scripts/tests/test-init-specs.sh`,
      `scripts/tests/test-validate-state.sh`, and anything else found by
      `grep -rn 'validate-state.sh' agent-system/extensions`.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: the caller set is hypothesized to be `commands/task.md`,
`verify-deploy.sh`, `test-init-specs.sh`, and `test-validate-state.sh`, none passing `--strict`.
Confirm with the grep above at implementation time and re-check any additional hit.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - `--strict` parsing, `--help`, header
  Usage/Exit-codes blocks, final exit branch

**Verification**:
- Default mode against this repo's `specs/state.json`: unchanged output plus the new checks, exit 0.
- `--strict` against the same file: exit 1 with the strict-mode summary line.
- `--strict` against a warning-free fixture: exit 0.
- `verify-deploy.sh` gate 10 still passes (it does not pass `--strict`, so warnings stay
  non-blocking there).
- `shellcheck --severity=warning` clean.

---

### Phase 5: `orchestrate-predispatch-review.sh` Classes F and G [NOT STARTED]

**Goal**: The pre-dispatch report surfaces a batch candidate's absent/null/empty `file_scope`
(Class F) and any glob-shaped entry (Class G), in the established class-section shape, with no
reach into `--repair`.

**Tasks**:
- [ ] Re-read the script's Class A/B jq block and the Class C/D/E report-rendering sections
      immediately before editing.
- [ ] Add a Class F generator alongside Class B in the same `ab_findings` jq program, scoped to
      `$cands` (batch candidates only, matching Classes A/B — never a global scan, which remains
      `validate-state.sh`'s job). Emit a `sub_state` field of `missing_key` / `null_value` /
      `empty_array` so the three states stay distinguishable (**D2**). Note that the `null_value`
      sub-state deliberately overlaps Class B's existing `file_scope` finding: Class B reports it
      as a type defect, Class F as a visibility defect, and both lines are printed rather than one
      suppressing the other.
- [ ] Add a Class G generator in the same block using `is_glob_entry` from Phase 1, splicing
      `FILE_SCOPE_OVERLAP_JQ_DEFS` (the script already splices it for Classes C/D/E — reuse that
      splice rather than adding a second).
- [ ] Add two report sections after Class E, matching the existing convention exactly: a
      `echo "-- Class F: ..."` header printed unconditionally, a populated finding list or an
      explicit accurate negative line, never a silently omitted section. Class G likewise. Follow
      Class E's precedent of stating precisely what the negative does and does not cover.
- [ ] Class G's message follows **D6**'s wording.
- [ ] Leave the `--repair` branch completely untouched: do not add `file_scope`-absence to its
      field list, and do not widen its `== null` predicate (**D4**). Add a comment at the
      `--repair` block stating that Classes F and G are report-only by design and why
      (normalizing an absent key to `[]` manufactures a declaration that then looks deliberate).
- [ ] Update the header's class roster: "reports FIVE classes" becomes seven, with Class F and
      Class G paragraphs; record **D3** (the addendum said "Class C"; that letter is taken by
      self-modification/coarseness, so F and G are used) in the Class F paragraph.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - Class F and Class G
  generators in the `ab_findings` jq program; two new report sections; header class roster and
  `--repair` comment

**Verification**:
- Running the script against a batch containing a candidate with no `file_scope` key prints the
  Class F finding; a candidate with a glob entry prints the Class G finding.
- A batch where every candidate declares a concrete non-empty scope prints both sections with
  their explicit negatives.
- `--repair` on a fixture whose candidate lacks the `file_scope` key writes nothing and does not
  add the key.
- The script keeps `set -euo pipefail` (Class A per `shell-strict-mode.md`) and is clean at
  `shellcheck --severity=warning`.

---

### Phase 6: Fixture tests for Checks 10, 11, `--strict`, and `--fix` non-manufacture [NOT STARTED]

**Goal**: Every new `validate-state.sh` behavior is pinned by a hand-crafted fixture, including
the negative guarantee that `--fix` never invents a `file_scope` key.

**Tasks**:
- [ ] Re-read `scripts/tests/test-validate-state.sh`'s Check 8/9 fixture section and its
      grep-the-validator-for-the-check-identifier resolution guard, and follow both conventions.
- [ ] Add a validator-resolution guard for the new checks (grep for `Check 10` / `Check 11`), so a
      stale deployed copy cannot produce a false green — mirroring the existing `FS_VALIDATOR` and
      `D5_VALIDATOR` precedent.
- [ ] Check 10 fixture: four non-terminal entries — one missing the key, one literal null, one
      empty array, one with a concrete entry — asserting all three WARN sub-state lines, the
      summary counts, and exit 0.
- [ ] Check 10 negative fixture: every non-terminal entry declares a non-empty scope → the
      `log_pass` line, no Check 10 WARN.
- [ ] Check 10 terminal-exclusion fixture: a `completed` entry with no `file_scope` produces no
      finding (confirming the non-terminal filter).
- [ ] Check 11 fixture: a `*/agents/**` entry → the named WARN, exit 0; plus a non-glob control
      entry that must not fire.
- [ ] `--strict` fixtures: the Check 10 fixture under `--strict` → exit 1; the warning-free
      fixture under `--strict` → exit 0.
- [ ] `--fix` non-manufacture fixture: an entry with no `file_scope` key (alongside an entry with
      exact duplicates, so `--fix` actually does work) → after repair, the first entry still has
      no `file_scope` key. Place the fixture inside this repo's own git tree the way the existing
      `--fix` fixture does, since `--fix` writes only through a deployed `state-write.sh`.
- [ ] Use synthetic `project_number` values and refer to them as "candidate #N"/fixture numbers,
      never "task N", per `no-task-references-in-deliverables.md`.

**Timing**: 1.25 hours

**Depends on**: 4, 5

**Verification Tier**: local

**Scope Hypothesis**: eight new fixture cases are anticipated (three Check 10, one Check 11 plus
control, two `--strict`, one `--fix`). Confirm the final count at implementation time from the
suite's own PASS tally rather than asserting this number in the plan.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - new fixture section and
  validator-resolution guard for Checks 10/11

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with every new
  case PASS and no pre-existing case regressed.
- Each new case fails loudly when the corresponding check is temporarily stubbed out (spot-check
  at least the Check 10 and `--fix` non-manufacture cases, to prove they are not vacuous).

---

### Phase 7: Fixture tests for Classes F and G [NOT STARTED]

**Goal**: Classes F and G are pinned by fixtures in the existing predispatch-review suite,
including their explicit negatives and `--repair`'s non-interference.

**Tasks**:
- [ ] Re-read `scripts/tests/test-orchestrate-predispatch-review.sh`, including its
      `orchestrate-batch-admit.sh` stubbing and its synthetic `$WORKDIR/.claude/scripts/` tree
      (needed for `deploy-root-guard.sh`'s parent-directory check).
- [ ] Class F fixture: candidates missing the key / literal null / empty array → all three lines,
      with the `null_value` candidate also still producing its existing Class B line.
- [ ] Class G fixture: a candidate with a glob entry → the named Class G line; a control candidate
      with concrete entries that must not fire.
- [ ] Negative fixture: all candidates declare concrete non-empty scopes → both new sections print
      their explicit negatives, and neither section is omitted.
- [ ] `--repair` fixture: a candidate with no `file_scope` key → no write, key still absent
      afterwards (the **D4** guarantee, asserted rather than assumed).
- [ ] Keep the suite's fixture-numbering convention ("candidate #N", never "task N").

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` - Class F
  and Class G fixture cases plus the `--repair` non-manufacture case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` exits 0
  with every new case PASS and no pre-existing case regressed.

---

### Phase 8: Acceptance sweep and live measurement [NOT STARTED]

**Goal**: Every acceptance line in the dispatch is checked against the real repository, and the
live figure is reported as a measurement rather than asserted as a fixed number.

**Tasks**:
- [ ] `shellcheck --severity=warning` on all four edited shell files; confirm the only remaining
      full-severity output is the two pre-existing info-level notes (SC1091, SC2016) — no new
      finding at any severity.
- [ ] Confirm strict-mode class conformance per `context/standards/shell-strict-mode.md`:
      `validate-state.sh` still Class B (`set -uo pipefail`, counter idiom),
      `orchestrate-predispatch-review.sh` still Class A (`set -euo pipefail`).
- [ ] Run both test suites plus `test-init-specs.sh` (a downstream consumer of
      `validate-state.sh`'s exit code) to green.
- [ ] Default-mode live run: `bash agent-system/extensions/core/scripts/validate-state.sh
      specs/state.json` — record the Check 10 sub-state counts, the non-terminal denominator, and
      the Check 11 result verbatim in the implementation summary, and confirm exit 0.
- [ ] Optional second live measurement against `~/Projects/BimodalLogic/specs/state.json` if it is
      still reachable, reported the same way. A number differing from the dispatch's cited
      27/49/22/17/5 is expected and is not a failure (**D9**); note the divergence explicitly.
- [ ] Confirm `commands/task.md`'s `file_scope` advisory grep now picks up the Check 10/11 WARN
      lines (they contain the literal string `file_scope`), and record whether that is desirable
      as-is — it is a free win, but flag it if the volume is excessive.
- [ ] Re-confirm the D4 guarantee end-to-end: neither `--fix` nor `--repair` manufactures `[]` on
      an absent key.
- [ ] Confirm no `.claude/**` file was edited (every change is in
      `agent-system/extensions/core/`), and no task number appears in any edited deliverable.

**Timing**: 0.5 hours

**Depends on**: 6, 7

**Verification Tier**: full

**Files to modify**:
- None (verification only; findings are recorded in the implementation summary)

**Verification**:
- All four acceptance lines from the dispatch hold: default-mode report + exit 0; promotion
  criterion in the header; predispatch review surfaces absent scope with the class decision
  documented; `--repair` does not manufacture `[]`; both scripts shellcheck-clean at the
  established baseline.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` → exit 0
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` → exit 0
- [ ] `bash agent-system/extensions/core/scripts/tests/test-init-specs.sh` → exit 0
- [ ] `shellcheck --severity=warning` clean on `validate-state.sh`,
      `orchestrate-predispatch-review.sh`, `lib/file-scope-overlap.sh`, and both edited test files
- [ ] Default-mode `validate-state.sh specs/state.json` → exit 0, Check 10 and Check 11 lines present
- [ ] `--strict` on a fixture with a Check 10 finding → exit 1; on a clean fixture → exit 0
- [ ] `--fix` and `--repair` fixtures confirm no `file_scope` key is ever manufactured
- [ ] No exact-count assertion anywhere binds to a live `specs/state.json`

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` — shared `is_glob_entry` jq def
- `agent-system/extensions/core/scripts/validate-state.sh` — Check 10, Check 11, `--strict`, and
  the header decision/promotion records
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` — Classes F and G plus
  the header class roster and `--repair` non-interference note
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — fixtures for Checks 10/11,
  `--strict`, and `--fix` non-manufacture
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — fixtures
  for Classes F and G plus `--repair` non-manufacture
- `specs/163_surface_missing_and_empty_file_scope/summaries/01_*-summary.md` — implementation
  summary carrying the live measurement figures

## Rollback/Contingency

Every phase is an additive edit to one file, committed per green sub-step, so the contingency is
per-phase `git revert` of that phase's own commit — no working-tree discard is required or
sanctioned. If a defensive checkpoint is wanted before Phase 1 (the only phase touching a shared
library with four consumers), use the durable, non-reverting form:
`bash .claude/scripts/git-snapshot.sh 163 --no-revert`. Do not invoke `git-snapshot.sh` in its
default reverting mode here — that idiom belongs only to a genuine rollback scenario, per
`context/contracts/recovery.md`'s rollback rung.

Partial-completion contingency: Phases 1-4 (`validate-state.sh` side) and Phase 5
(`orchestrate-predispatch-review.sh` side) are independently useful. If the task must stop early,
close it at a phase boundary with the completed side committed and green rather than leaving a
half-added check in either script; both new WARN families are non-blocking by construction, so a
partially landed set degrades to less detection, never to a broken gate.
