# Implementation Plan: Task #429

- **Task**: 429 - script-inventory.sh undercounts untracked files
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: None (no research report; planned directly from the task description plus
  targeted reads of `script-inventory.sh`, its test suite, and its one consumer)
- **Artifacts**: plans/01_untracked-corpus-enumeration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`script-inventory.sh` enumerates its corpus with `git ls-files`, which is tracked-files-only, so a
newly created in-corpus file is invisible to every counted figure until `git add` runs. The fix
unions the tracked enumeration with `git ls-files --others --exclude-standard` at both tracked
enumeration sites (the shared `enumerate_candidates`, which serves the script and test-suite
figures, and the separate inline markdown block), surfaces the untracked contribution on **stdout**
so it survives the consumer's `2>/dev/null`, and pins the behaviour with a git-fixture regression
case. A read-only measurement phase runs first, because the old-versus-new delta can only be
computed while the old behaviour is still in place.

### Research Integration

No research report exists for this round. The task description already carried the defect, the
direct observation that confirmed it (a new `lib/lint-corpus-scan-lib.sh` did not move the
`scripts=` count until staged), the two candidate remedies, the test requirement, and the edit
target. The following facts were established by reading the code during planning rather than
assumed:

- **A partial remedy is already in place and is inert at the one consumer.** The script already
  computes `UNTRACKED_CANDIDATES` via `enumerate_untracked_matches` and prints a
  `WARNING: script-inventory: N untracked script file(s) ... NOT reflected in the counts below`
  line, deliberately keeping those files out of the counts to preserve numeric comparability with
  recorded baselines. But `verify-deploy.sh:1987` invokes the probe as
  `bash "$_VD_SCRIPT_INVENTORY" --root "$TARGET" --size-line 2>/dev/null || true` — stderr is
  discarded outright. At the only standing consumer the warning does not exist, so the undercount
  is still effectively silent there. This is the decisive fact behind the approach chosen below.
- **The markdown figures carry the same defect, and the warning does not cover them at all.** The
  `--size-line` markdown enumeration (`git ls-files -z -- 'agent-system/extensions/**/*.md'`) is a
  separate inline block, and `enumerate_untracked_matches` is only ever called with the `*.sh`
  pattern. At plan time the working tree holds 1 untracked in-corpus `.md` file and 0 untracked
  in-corpus `.sh` files, so today the undercount is live on `md_files`/`md_lines` specifically.
- **Approach chosen: include untracked-but-not-ignored files in the counts** (the description's
  first option), not fail loudly (its second). Failing loudly is the wrong instrument here: the
  corpus line is deliberately additive-only, non-gating output (`verify-deploy.sh:1980-1990`, "No
  new gate row, no new check, no effect on CHECKS/FAILURES/FINDINGS_LIST") guarded by
  `|| true`, so a non-zero exit would be swallowed exactly as the warning is; and it would make the
  probe refuse during ordinary implementation work, when an in-corpus script is routinely unstaged
  for minutes at a time. Counting what is actually on disk makes the figure correct at the moment
  of measurement, which is precisely what a net-deletion acceptance criterion needs.
  `--others --exclude-standard` already honours `.gitignore`, and the
  `agent-system/extensions/**` pathspec already confines the scan to the source store, so the
  existing exclusion of gitignored and deploy-artifact paths is preserved by construction rather
  than re-implemented.
- **Comparability is handled by disclosure, not by suppression.** `--size-line` gains one trailing
  `untracked=N` field (appended at the END of the line) so a reader can always tell how much of a
  figure is provisional. End position is load-bearing: the existing suite asserts the counts with a
  substring `grep -q 'scripts=2 lines=8 ... md_lines=6'`, which an appended field leaves intact
  while a mid-line insertion would break.
- **Git fixtures are already a convention in this suite.** `test-script-inventory.sh` defines
  `mk_git_fixture()` (lines 78-84) and the `--size-line` case already builds a git fixture with an
  explicit `git add` list and a commit, so a fixture with one tracked and one deliberately
  unstaged in-corpus file needs no new harness machinery.
- **Baseline figures captured under the undercounting behaviour do exist**, in
  `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md`
  (lines ~138-168) and `plans/03_markdown-corpus-consolidation.md` (lines ~206-251), plus
  `handoffs/phase-1-handoff-20261016T164543Z.md`. Phase 1 dispositions them.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` lines 68-72 name this task explicitly as the instrument half of its first
orchestrate call, paired with its consumer under a dependency edge: "Fixing the instrument first is
cheap; after is a re-measure." This plan advances that item and nothing else. The plan does not
modify ROADMAP.md (`roadmap_flag` not set for this dispatch).

## Goals & Non-Goals

**Goals**:
- Every counted figure the probe emits (`scripts`, `lines`, `test_suites`, `test_lines`,
  `md_files`, `md_lines`, and the full-JSON `candidate_count`/`scripts`/`summary`) reflects
  untracked-but-not-ignored in-corpus files, not just tracked ones.
- The untracked contribution is visible on **stdout**, so it survives a consumer that discards
  stderr.
- `--size-line` stays exactly one line, exit 0, and stays cheap enough for per-gate invocation.
- A regression test pins both halves: an untracked in-corpus file IS counted, and a gitignored
  in-corpus file is NOT.
- The baseline-exposure question is answered in writing either way.

**Non-Goals**:
- Turning the corpus line into a gate, a check, or a non-zero exit path. It stays additive-only.
- Changing the corpus definition itself (the `tests/`-directory and `test-` basename exclusion
  rules, the `agent-system/extensions/**` scope, the composite ranking, duplicate-block detection).
- Retro-editing the recorded baseline figures inside task 328's plan files. 328 is an active task
  and those files are its territory; Phase 1 records the disposition here instead.
- Extending the same fix to sibling probes (`context-reachability.sh`, `assess-repo-health.sh`,
  `census-count.sh`) that share the `git ls-files` enumeration idiom. Out of scope; Phase 1 notes
  whether the exposure is real there so it can be filed separately.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Appending a field to `--size-line` breaks a stdout consumer | M | L | Only consumer is `verify-deploy.sh:1988`, which echoes the whole line after stripping the `script-inventory: ` prefix. Append at END, never mid-line; Phase 2 verification re-runs the consumer path |
| Existing `--size-line` substring assertion breaks | L | L | Assertion is a substring `grep -q`; appended-at-end field leaves it matching. Phase 3 re-runs the suite to confirm, not assumes |
| Union introduces a duplicate path (file both tracked and reported untracked) | M | L | `--others` is disjoint from tracked by definition, but the union is still passed through the existing `sort` with `-u` so a duplicate can never double-count |
| Counted figures become non-comparable to recorded baselines | M | H (by design) | Intended and disclosed: `untracked=N` on stdout plus `untracked_count` in JSON make every figure self-describing; Phase 1 records the baseline disposition |
| Non-git fixture regression (the `find` fallback) | M | L | The `find` fallback already sees untracked files; the union must stay inside the git branch only. Phase 3's existing non-git fixture cases are the covering check |
| Hand-editing `.claude/**` instead of the source store | H | L | Every edit target below is under `agent-system/extensions/core/`; Phase 4 redeploys |
| Record-versioning language leaking into the rewritten header | M | M | The existing header contains "That exclusion was previously SILENT"; the rewrite must state the current design only, with no "previously"/"no longer" framing (`.claude/rules/no-record-versioning-in-deliverables.md`) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Measure the Exposure and Disposition Recorded Baselines [COMPLETED]

**Goal**: While the tracked-only behaviour is still in place, quantify what it hides and answer the
description's baseline question in writing. This must run first — once Phase 2 lands, the old
figure is no longer obtainable without a revert.

**Tasks**:
- [x] Record the current tracked-only figure verbatim: `bash agent-system/extensions/core/scripts/script-inventory.sh --root . --size-line` *(completed: scripts=241 lines=96148 test_suites=174 test_lines=84259 md_files=931 md_lines=232238)*
- [x] Record the untracked in-corpus sets the tracked enumeration misses, for both patterns:
      `git ls-files --others --exclude-standard -- 'agent-system/extensions/**/*.sh'` and the same
      with `'agent-system/extensions/**/*.md'`, applying the `tests/`-dir and `test-` basename
      split so the delta is attributable per figure *(completed: 0 untracked .sh matches; 1
      untracked .md match — agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md,
      32 lines; the md enumeration has no tests/-dir split to apply)*
- [x] Compute the per-figure delta the union will produce (scripts/lines, test_suites/test_lines,
      md_files/md_lines) and record it *(completed: scripts +0, test_suites +0, md_files +1
      (+32 lines); predicted post-union figure scripts=241 lines=96148 test_suites=174
      test_lines=84259 md_files=932 md_lines=232270)*
- [x] Inspect the recorded baselines in
      `specs/328_systematic_script_and_test_corpus_efficiency/plans/01_corpus-consolidation-net-deletion.md`
      and `plans/03_markdown-corpus-consolidation.md`, and state the finding: whether each recorded
      figure was captured under the undercounting behaviour and therefore needs re-capturing, or
      whether it is unaffected. Do NOT edit those files *(completed: both files freeze the same
      Phase-1-close baseline, captured under the pre-fix tracked-only tool; re-capture is
      recommended before 328's pending final NET-accounting phase; disposition recorded in
      progress/phase-1-progress.json and the task summary, neither 328 plan file edited)*
- [x] Note whether the same `git ls-files` exposure is present in `context-reachability.sh`'s and
      `census-count.sh`'s enumerations, as a one-line out-of-scope observation for separate filing
      *(completed: context-reachability.sh shares the identical tracked-only exposure;
      census-count.sh has no hard-coded enumeration of its own, so it is not exposed)*
- [x] Record the findings in this task's own artifacts (progress notes and the eventual summary),
      and record a `--kind win`/`--kind issue` issue-log entry as appropriate *(completed:
      progress/phase-1-progress.json populated; issue-record.sh called with --kind issue
      --class measurement-exposure)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase changes no file under any test suite's coverage — its entire
output is measurement prose recorded in this task's artifacts, so no suite exists that could cover
it.

**Scope Hypothesis**: At plan time the working tree holds 0 untracked in-corpus `.sh` files and 1
untracked in-corpus `.md` file, making today's live undercount markdown-only and the `scripts=`
delta zero at this instant. Confirm by re-running both `git ls-files --others --exclude-standard`
commands at implementation time rather than carrying these numbers forward — the working tree will
have moved.

**Files to modify**:
- None (read-only measurement; findings land in this task's progress notes and summary)

**Verification**:
- The old figure, the untracked sets, and the per-figure delta are recorded verbatim, with the
  commands that produced them
- The baseline disposition is stated explicitly for both 328 plan files, with a yes/no on
  re-capture — not left implicit
- No file under `agent-system/**` or `specs/328_*/**` was modified by this phase

---

### Phase 2: Union the Enumerations and Disclose the Untracked Contribution [COMPLETED]

**Goal**: Make every counted figure reflect untracked-but-not-ignored in-corpus files, and make
that contribution legible on stdout.

**Tasks**:
- [x] In `enumerate_candidates()`, inside the git-work-tree branch only, emit the union of
      `git ls-files -z -- 'agent-system/extensions/**/*.sh'` and
      `git ls-files -z --others --exclude-standard -- 'agent-system/extensions/**/*.sh'`. Leave the
      non-git `find` fallback untouched (it already sees untracked files) *(completed)*
- [x] Apply the same union to the inline markdown enumeration in the `--size-line` block, with the
      `*.md` pattern *(completed)*
- [x] Make the downstream dedup/sort explicitly `sort -u` (both the `CANDIDATES` sort and the
      markdown/test-suite paths) so a path appearing in both streams can never double-count
      *(completed: CANDIDATES, TEST_SUITES, and MD_FILES all use sort -u)*
- [x] Keep `enumerate_untracked_matches` as the single source of the untracked set, and reuse the
      already-computed `UNTRACKED_CANDIDATES` for disclosure rather than re-shelling git
      *(completed)*
- [x] Reframe `warn_untracked_candidates()` to state what is true of the new behaviour: the named
      untracked files ARE included in the figures, so a figure is provisional with respect to a
      previously recorded baseline. Keep it stderr-only and keep it a no-op when the set is empty
      *(completed)*
- [x] Append `untracked=N` as the FINAL field of the `--size-line` output line (counting untracked
      in-corpus files across all three patterns, or a per-pattern breakdown if it stays one line).
      Preserve the exactly-one-line and exit-0 contracts *(completed: single combined total
      across the sh/non-test, sh/test, and md untracked sets)*
- [x] Add `untracked_count` and `untracked_paths` to the top-level JSON document (including the
      degenerate-root `jq -n` branch, so the schema is uniform), and a per-script `tracked` boolean
      derived from set membership *(completed)*
- [x] Rewrite the header's `UNTRACKED-CANDIDATE VISIBILITY` block and the `ENUMERATION` block to
      describe the union behaviour, the gitignore/source-store scoping it preserves, and the
      comparability disclosure. State the current design only: no "previously", "no longer", or
      draft-history framing (`.claude/rules/no-record-versioning-in-deliverables.md`), and no task
      numbers (`.claude/rules/no-task-references-in-deliverables.md`) *(completed; verified via
      grep -nE 'previously|no longer|formerly|task [0-9]' with no matches)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: The phase changes the `--size-line` stdout contract that
`verify-deploy.sh:1988` consumes, a cross-script surface the probe's own suite does not reach, so
`verify-deploy.sh --only-gate` on the corpus-line path plus `test-deploy-verify-wiring.sh` is
needed alongside `run-all.sh --only test-script-inventory.sh`.

**Scope Hypothesis**: The defect has exactly two tracked-enumeration sites to union —
`enumerate_candidates()` (serving both the script and the test-suite figures) and the inline
markdown block in the `--size-line` path — plus one existing untracked helper to reuse. Confirm by
grepping `git ls-files` in `agent-system/extensions/core/scripts/script-inventory.sh` and checking
that every hit is accounted for before declaring the phase done; a third tracked site would widen
this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/script-inventory.sh` - union both tracked enumerations with
  `--others --exclude-standard`; `sort -u`; reframed stderr disclosure; `untracked=` field on
  `--size-line`; `untracked_count`/`untracked_paths`/per-script `tracked` in JSON; rewritten
  `ENUMERATION` and `UNTRACKED-CANDIDATE VISIBILITY` header blocks

**Verification**:
- `bash agent-system/extensions/core/scripts/script-inventory.sh --root . --size-line` emits
  exactly one line, exits 0, and its figures equal the Phase 1 old figure plus the Phase 1 computed
  delta — matching the prediction, not merely "a number changed"
- `... --root . | jq -e '.untracked_count, .untracked_paths, (.scripts[0]|has("tracked"))'` succeeds
- `... --root . | jq .` parses with stderr NOT redirected (the disclosure line cannot corrupt the
  JSON parse)
- `bash agent-system/extensions/core/scripts/script-inventory.sh --root /tmp/<empty-dir>` still
  emits the degenerate-root document, now including `untracked_count: 0`
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-script-inventory.sh`
  passes (pre-existing cases, including the non-git fixtures, still green)
- The consumer path: `verify-deploy.sh` still prints one `[verify-deploy] corpus: ...` line, now
  carrying `untracked=`, with no new failure row
- `grep -nE 'previously|no longer|formerly|task [0-9]' agent-system/extensions/core/scripts/script-inventory.sh`
  returns no new occurrence

---

### Phase 3: Pin the Behaviour with a Git-Fixture Regression Case [COMPLETED]

**Goal**: A fixture that fails if the enumeration ever reverts to tracked-only, and that
simultaneously proves gitignored in-corpus files stay excluded.

**Tasks**:
- [x] Add a case to `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` using the
      existing `mk_git_fixture` helper: build an in-corpus tree with one tracked non-test script,
      one deliberately unstaged non-test script, one unstaged `tests/`-dir script, one unstaged
      `.md` file, and one unstaged file matched by a fixture `.gitignore` *(completed: the
      "Untracked inclusion" case)*
- [x] `git add` + commit only the tracked subset, mirroring the existing `--size-line` case's
      explicit staging list *(completed)*
- [x] Assert `--size-line` counts BOTH the tracked and the unstaged non-test scripts (and their
      combined line total), counts the unstaged test-suite and markdown files in their own figures,
      and does NOT count the gitignored file *(completed)*
- [x] Assert the `untracked=` field reports the expected count and appears on the single stdout line
      *(completed)*
- [x] Assert the exactly-one-line and exit-0 contracts still hold for this fixture *(completed)*
- [x] Assert the default JSON mode's `candidate_count` includes the unstaged script and that
      `untracked_paths` names it *(completed; also asserts untracked_count, per-script tracked,
      and gitignored-file absence)*
- [x] Extend the suite header's `# Cases:` block with the new case description, following the
      existing entry style *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: The edit is confined to `test-script-inventory.sh`, whose every assertion
is executed by `run-all.sh --only test-script-inventory.sh` — that one suite covers the whole blast
radius.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - new git-fixture case
  (tracked + untracked + gitignored in-corpus files) and the header `# Cases:` entry

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-script-inventory.sh`
  reports 0 FAILED, with the new case among the PASS lines
- Negative control: with the Phase 2 union temporarily reverted in a scratch copy, the new case
  FAILS — proving it actually pins the behaviour rather than passing vacuously
- The gitignored-file assertion fails if `--exclude-standard` is dropped (same scratch-copy check)

---

### Phase 4: Documentation, Redeploy, and Full Gate Set [NOT STARTED]

**Goal**: Bring the prose inventory in line with the implemented enumeration, regenerate the deploy
tree, and close the task against the complete gate set.

**Tasks**:
- [ ] Update the `script-inventory.sh` entry in
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` to describe the
      union enumeration, the preserved gitignore/source-store scoping, and the `untracked=` /
      `untracked_count` disclosure. Current design only — no draft-history or task-number language
- [ ] Redeploy the source store so `.claude/scripts/script-inventory.sh` and the deployed suite
      match: `bash .claude/scripts/deploy-headless.sh`
- [ ] Run the full test battery unfiltered: `bash agent-system/extensions/core/scripts/tests/run-all.sh`
- [ ] Run `bash .claude/scripts/verify-deploy.sh` with no gate filter and confirm the corpus line
      now carries `untracked=`
- [ ] Confirm the post-deploy `--size-line` figure equals the Phase 2 figure (deploy introduced no
      drift)
- [ ] Record the final figure and the Phase 1 baseline disposition in the task summary

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - revised
  `script-inventory.sh` entry
- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, regenerating the entire deployed
  `.claude/` tree

**Verification**:
- Complete gate set, unfiltered: `bash agent-system/extensions/core/scripts/tests/run-all.sh` (no
  `--only`) reports 0 failures; `bash .claude/scripts/verify-deploy.sh` (no `--only-gate`) reports
  PASS with no new findings
- `bash .claude/scripts/check-task-references.sh` and the record-version lint report no new
  occurrence under `agent-system/**`
- Deployed and source copies of both `script-inventory.sh` and `test-script-inventory.sh` are
  identical after the deploy
- `grep -n 'untracked' agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
  shows the enumeration is documented
- The task summary states the baseline-re-capture finding explicitly

---

## Testing & Validation

- [ ] `--size-line` counts an untracked, not-yet-staged in-corpus script, test-suite file, and
      markdown file
- [ ] A gitignored in-corpus file is still excluded from every figure
- [ ] `--size-line` remains exactly one line, exit 0, and the appended `untracked=` field leaves the
      existing substring assertion matching
- [ ] Default JSON mode parses cleanly with stderr unredirected, and exposes `untracked_count`,
      `untracked_paths`, and per-script `tracked`
- [ ] The degenerate-root document carries the same new keys
- [ ] The non-git `find`-fallback fixtures still pass unchanged
- [ ] `verify-deploy.sh` prints the corpus line with no new gate row or failure
- [ ] Full `run-all.sh` battery green, unfiltered
- [ ] Negative control confirms the new case fails against the tracked-only enumeration

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/script-inventory.sh` - union enumeration, `sort -u`,
  reframed stderr disclosure, `untracked=` stdout field, JSON `untracked_count`/`untracked_paths`/
  per-script `tracked`, rewritten header blocks
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` - new git-fixture
  regression case pinning untracked inclusion and gitignore exclusion
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - revised entry
- Regenerated `.claude/` deploy tree
- Task summary recording the old figure, the new figure, the per-figure delta, and the
  baseline-re-capture finding for the two recorded baseline sets

## Rollback/Contingency

All work is confined to two source-store files plus one doc, each tracked in git, so a revert is a
scoped `git revert` of this task's commits followed by `bash .claude/scripts/deploy-headless.sh` to
regenerate the deploy tree from the reverted source. Before the Phase 2 edit, take a non-reverting
checkpoint (`bash .claude/scripts/git-snapshot.sh 429 --no-revert`) so the pre-change probe
behaviour stays recoverable for the Phase 3 negative control without disturbing the working tree.

If the `untracked=` stdout field turns out to break an unanticipated consumer, the narrower
fallback is to keep the union (the correctness fix, which is the point of the task) and move the
disclosure to the JSON document and the stderr line alone, accepting that `verify-deploy.sh`'s
`2>/dev/null` hides it — a strictly smaller change than reverting the enumeration.

If the union proves to destabilise figures mid-implementation (for instance a large unstaged
scratch tree inside `agent-system/extensions/**` inflating a count), the contingency is NOT to
revert to tracked-only but to tighten the pathspec, since a scratch tree inside the source store is
itself a finding the probe should surface.
