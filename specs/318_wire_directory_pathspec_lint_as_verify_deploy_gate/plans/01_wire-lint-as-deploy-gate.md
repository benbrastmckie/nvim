# Implementation Plan: Task #318

- **Task**: 318 - Wire the directory-pathspec boundary lint into `verify-deploy.sh` as a numbered gate
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: 265, 304 (both complete). Do not run concurrently with the Gate-8-parallelism task or the SKILL.md/gate-20 trim task (shared `verify-deploy.sh` / `test-verify-deploy-context-budget.sh`). Task 392 depends on this task and runs after it.
- **Research Inputs**: specs/318_wire_directory_pathspec_lint_as_verify_deploy_gate/reports/01_wire-lint-as-deploy-gate.md
- **Artifacts**: plans/01_wire-lint-as-deploy-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`scripts/lint/lint-directory-pathspec-boundary.sh` exists, is manifest-registered, has a passing
14-case fixture test, and reports 0 violations across the source store — but it is enforced only
when run by hand, while its sibling `lint-scoped-commit-boundary.sh` is enforced on every deploy
as gate 17. This plan closes that asymmetry by appending the lint as a new **trailing blocking
gate 23** in `scripts/verify-deploy.sh`, copying gate 17's block shape verbatim, widening the
`--only-gate` accepted range from `1-22` to `1-23`, updating the one dependent test suite that
hard-codes the gate count, and correcting the one `git-staging-scope.md` bullet that currently
asserts a now-superseded wiring point.

The placement decision is the substantive ruling: **append, never insert beside gate 17.** The
research measured the renumbering blast radius at 210 by-number citation sites across gates 18-22
(131 for gate 20 alone); appending costs zero renumbering and zero citation fixes.

### Research Integration

The report's placement ruling (trailing gate 23), tier ruling (blocking, matching every other
lint gate), and mechanical change inventory are adopted wholesale. Three additions this plan makes
on top of the report, from state re-verified at plan time against the currently committed file
(the report was written against the file as it stood before commit `7da3e047a` landed):

1. **The report's `verify-deploy.sh` line numbers are stale.** The file is now 1238 lines (was
   ~1204). Gate 22's block now closes at line 1202 and the zero-check-under-filter tail begins at
   line 1203. The six `1-22` range sites are now at lines 83, 86 (`twenty-two`), 89, 125, 131, 137.
   Every edit below is specified by anchor text, not line number, for exactly this reason.
2. **`test-verify-deploy-gate-selection.sh` case (c) hard-codes `23` as an INVALID gate id**
   (`invalid_cases=("abc" "0" "23" "1,abc" "1,99")`, around line 149). This is a genuine
   pre-existing assertion that adding gate 23 inverts, and the research report did not catch it.
   Left unfixed, case (c) fails loudly. This file also is NOT in the task's declared `file_scope`
   — see "Scope note" below.
3. **The source-store SKIP guard is required, and gate 4's de-guarding does not transfer.**
   Commit `7da3e047a` removed gate 4's source-store-only SKIP guard on the reasoning that
   `check-task-references.sh` carries no `agent-system/extensions` dependency. That disproof is
   explicitly scoped to gate 4 and does NOT apply here: `lint-directory-pathspec-boundary.sh`
   defaults its scan root to `$PROJECT_ROOT/agent-system/extensions` and **exits 2 with
   `ERROR: default scan root not found`** when that directory is absent (verified by reading
   lines 161-170 of the lint). So gate 23 keeps gate 17's guard, and the new gate block's comment
   must say so rather than leaving a future reader to re-litigate it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

### Scope note: one file must be added to `file_scope`

The task's declared `file_scope` is three files
(`verify-deploy.sh`, `test-verify-deploy-context-budget.sh`, `git-staging-scope.md`). The work
genuinely requires a fourth, `scripts/tests/test-verify-deploy-gate-selection.sh`, and genuinely
requires **no edit at all** to `test-verify-deploy-context-budget.sh` (see Phase 5). The fourth
file is named in Phase 3's `**Files to modify**` block, which `scripts/plan-file-scope-harvest.sh`
harvests into `--file-scope-add` at this plan round's postflight — so the widening happens
mechanically, with no manual state edit, provided the phase block is left intact.

## Goals & Non-Goals

**Goals**:
- `lint-directory-pathspec-boundary.sh` runs as blocking gate 23 on every `verify-deploy.sh`
  invocation, with gate 17's exact block shape, `--verbose` handling, PASS/FAIL line format, and
  `[VIOLATION]`-scraping findings accumulation.
- `--only-gate 23` is accepted; `--only-gate 24` is still refused with the named range error.
- `test-verify-deploy-gate-selection.sh` passes with its gate-count assertions and its
  invalid-id list updated to match a 23-gate battery.
- `git-staging-scope.md`'s cross-reference bullet states the gate number and the
  deliberately-trailing placement rationale, replacing its superseded "natural wiring point is
  gate 17" sentence.
- Every other gate, and the three affected test suites, demonstrably unregressed.

**Non-Goals**:
- Renumbering any existing gate, or touching any by-number citation of gates 18-22.
- Broadening, weakening, or allowlisting anything in the lint's classifier to make the gate green
  (the dispatch's HARD CONSTRAINT; not implicated today — the lint is clean — but it stands).
- Adding a too-narrow-pathspec check. The dispatch's OBSERVATION section is explicit that this is
  out of scope and belongs in its own task if judged worthwhile. A green gate 23 certifies "no
  over-wide pathspec token, as written", never "pathspecs are correct".
- Fixing two pre-existing stale gate counts found during planning and deliberately **not**
  bundled: `verify-deploy.sh`'s header Findings-mode paragraph says "all eighteen gates (gate0
  through gate17)", and `context/standards/shell-script-testing.md:138` says "the full 20-gate
  battery". Both were already wrong before this task (the true count was 22). Fixing them would
  pull a file outside this task's scope into a batch where sibling tasks are live. Recorded here
  so the next toucher of either file has the finding.
- Any manual deploy of the edited source file into `.claude/**`. See Phase 5.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A `1-22` range site is missed, silently rejecting `--only-gate 23` | H | M | Phase 2 closes with `grep -n '1-22\|twenty-two'` on the file expecting zero hits, and a live `--only-gate 23` acceptance check |
| `test-verify-deploy-gate-selection.sh` case (c) still lists `23` as invalid | M | H if unaddressed | Phase 3 changes it to `24` explicitly and runs the suite |
| A long gate/test run is auto-backgrounded by the default 120s Bash tool timeout, stranding the dispatch | H | H | Every long step below carries the full bounded-wait idiom inline: Bash tool `timeout: 600000` **and** an inner `timeout 540`, output redirected to a log, read back with `grep`/`tail`. Never `run_in_background`, never a Monitor, never awaiting a harness notification |
| The lint develops a violation between plan time and implement time (live multi-task tree) | H | L | Phase 1 re-runs the lint before any wiring and treats a non-zero result as a stop-and-fix-the-site decision, never a classifier change |
| Gates 1/2/5 fail in the full battery because the deployed `.claude/` tree is stale relative to the source store | M | M | Phase 1's pre-change baseline log is the attribution instrument: a failure present in the baseline is pre-existing deploy staleness, not this task's regression. Resolution is the orchestrator's own next redeploy checkpoint, not a manual workaround |
| `test-four-tier-conflict.sh` Case 6 fails inside gate 8 | L | M | Known pre-existing flake (a `[1000ms,2000ms)` timing assertion measuring ~2.3-2.8s under concurrent load). If a suite run shows exactly that one failure, attribute it and move on — do not investigate |
| A sibling task edits `verify-deploy.sh` concurrently | H | L | Re-read the file immediately before each edit; stage only this task's own hunks with an explicit file list; if a foreign commit or foreign uncommitted modification appears, STOP and report per the dispatch's Territory block |
| Task 392's later edit to `verify-deploy.sh` collides | L | L | No collision foreseen: 392 edits the redeploy remedy strings around lines 178 and 298 and `external-process-wait.md`; this task's edits are the header range sites (83-137, in-place text substitution that adds no lines) and a block appended at the tail after line 1202. Phase 2 must substitute range text **in place** and not add header lines, so 392's anchors do not shift |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. This plan is deliberately linear: every
phase after the first either edits or asserts against the artifact the previous phase produced,
and the shared-tree concurrency note in the dispatch makes serialized, individually-committed
steps the safer shape.

---

### Phase 1: Re-verify the lint is clean and capture the pre-change baseline [COMPLETED]

**Goal**: Establish, with live evidence rather than inherited claims, that (a) the lint reports 0
violations so wiring it as **blocking** is safe today, and (b) which gates (if any) already fail
before this task touches anything — the attribution instrument for Phase 5.

**Tasks**:
- [x] Re-run the lint against the live source store and confirm `Total violations: 0`, exit 0:
      `cd /home/benjamin/.config/nvim && timeout 300 bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh 2>&1 | tail -8`
      (Bash tool `timeout: 320000`.) If violations appear: STOP the phase, fix the violating call
      site or justify an allowlist entry in the lint's own Layer-3 allowlist — never broaden the
      classifier (HARD CONSTRAINT). *(completed: 1303 files checked, 0 violations, exit 0)*
- [x] Re-run the lint's fixture test and confirm `14 passed, 0 failed`:
      `cd /home/benjamin/.config/nvim && timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh 2>&1 | tail -5`
      (Bash tool `timeout: 320000`.) *(completed: 14 passed, 0 failed)*
- [x] Capture the **pre-change full-battery baseline**, with the complete bounded-wait idiom:
      Bash tool parameter `timeout: 600000`, inner `timeout 540`, output to a log, read back with
      grep — never `run_in_background`, never a Monitor, never awaiting a harness notification:
      ```
      cd /home/benjamin/.config/nvim && \
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh \
        /home/benjamin/.config/nvim \
        > /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-baseline.log 2>&1; \
      echo "exit=$?"; \
      grep -E '^\[verify-deploy\] (PASS|FAIL)' /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-baseline.log; \
      grep -E '^\s*\[FAIL\]' /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-baseline.log
      ```
- [x] Record the baseline `N` from the `PASS -- N check(s)` line (or the `FAIL -- F of N` line) and
      the exact list of any `[FAIL]` lines, verbatim, in the phase's progress notes. This number
      and this list are what Phase 5 compares against. *(completed: see progress file —
      --skip-slow baseline is `FAIL -- 1 of 35 check(s) failed`, sole FAIL is gate 5 manifest-driven
      verification citing 2 lean stale-deploy findings)*
- [x] If the inner `timeout 540` kills the run (`exit=124`), re-run once with `--skip-slow`
      appended and record that the baseline is a `--skip-slow` baseline, so Phase 5 compares
      like with like. Do not raise the inner timeout above 570 (the tool parameter is 600000).
      *(completed: the full non-skip-slow run did hit exit=124 inside gate 8's shell suite runner;
      re-ran once with --skip-slow per this contingency)*

**Timing**: 0.5 hours (dominated by the ~10-minute battery run)

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: This phase modifies no file at all; its covering checks are the two lint
commands above plus the baseline log's own `^\[verify-deploy\] (PASS|FAIL)` line, read back
directly.

**Files to modify**:
- none planned — this phase only reads and captures evidence

**Verification**:
- Lint reports `Total violations: 0` and exits 0.
- Fixture test reports `14 passed, 0 failed`.
- A baseline log exists, its PASS/FAIL line is recorded, and its `[FAIL]` lines (possibly none)
  are enumerated verbatim.

---

### Phase 2: Wire blocking Gate 23 into verify-deploy.sh [NOT STARTED]

**Goal**: Add the new trailing gate block and widen the `--only-gate` accepted range, with no
renumbering of any existing gate and no added header lines.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/verify-deploy.sh` immediately before editing
      (sibling tasks are live on this tree).
- [ ] Insert the new gate block **after** the `fi` that closes the gate 22 block and **before**
      the `# Zero-check-under-filter detection` comment. Copy gate 17's shape line-for-line,
      changing only: the gate number (`gate_selected 23`, `say "23. ..."`,
      `CURRENT_GATE="gate23"`, `FINDING gate23`), the lint filename, and the variable prefix. Use
      `dir_pathspec_lint_output` / `dir_pathspec_lint_status` / `dir_pathspec_lint_line` — a
      prefix distinct from gate 17's `scoped_commit_lint_*` and gate 22's `shellcheck_lint_*`,
      matching how every lint gate after 17 uses its own.
- [ ] Keep the source-store `[SKIP]` guard (`[ ! -d "$TARGET/agent-system/extensions" ]`). The
      block's comment must state **why** it is retained in the face of gate 4's de-guarding:
      this lint's default scan root IS `$PROJECT_ROOT/agent-system/extensions` and it exits 2
      with `ERROR: default scan root not found` when that directory is absent, so unlike
      `check-task-references.sh` it genuinely cannot run in a deploy consumer.
- [ ] The comment must also state the `--only-gate 23`-alone consequence explicitly: in a
      deploy-consumer tree the gate SKIPs, `CHECKS` reaches 0, and the zero-check-under-filter
      condition correctly exits 2 with `cannot attest` rather than printing
      `PASS -- 0 check(s)`. This is the intended, already-correct behavior shared with gates
      3/5/6/7/9/11/12/17/18/19/21/22 — no special handling, and no new mechanism, is needed.
- [ ] Invoke the lint exactly as gate 17 invokes its sibling — the source-store copy directly,
      with `REPO_ROOT` set and `cd "$TARGET"`:
      `(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh" --verbose 2>&1)`.
      `fail` on a non-zero status, with the re-run hint naming the source-store path, and
      accumulate `FINDING gate23` lines by scraping `[VIOLATION]` under `--findings`. Blocking
      (`fail`), not advisory (`warn`) — matching gates 6, 7, 9, 11, 12, 17, 18, 19, 21, 22.
- [ ] Widen the accepted range **by in-place text substitution only, adding no lines**: `1-22` →
      `1-23` at the four occurrences in the header/validator, `twenty-two` → `twenty-three` at the
      header's one occurrence, and the `-gt 22` bound → `-gt 23` in the validator loop. Anchor on
      the text, not on line numbers.
- [ ] Confirm syntax and the absence of stale range text:
      `bash -n agent-system/extensions/core/scripts/verify-deploy.sh && grep -n '1-22\|twenty-two\|gt 22' agent-system/extensions/core/scripts/verify-deploy.sh`
      — expect `bash -n` silent and the grep to find nothing.
- [ ] Confirm the gate runs and passes standalone against the source store (single-gate run, fast;
      Bash tool `timeout: 600000`, inner `timeout 540`, log + grep):
      ```
      cd /home/benjamin/.config/nvim && \
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow \
        --only-gate 23 /home/benjamin/.config/nvim \
        > /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-gate23.log 2>&1; \
      echo "exit=$?"; \
      cat /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-gate23.log
      ```
      Expect exit 0, one gate header (`23. `), a `[PASS]` line, and `PASS -- 1 check(s)`.
- [ ] Confirm `--only-gate 24` is still refused: expect exit 2 and
      `ERROR: --only-gate: gate id '24' is out of range (must be 1-23)`.
- [ ] Commit this file's hunks alone, with an explicit file list (never a directory or glob add).

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to `verify-deploy.sh` and is purely additive (a new
gate block plus a widened accepted range that breaks no existing caller); it is covered by
`bash -n` plus `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 23 /home/benjamin/.config/nvim`
and the `--only-gate 24` refusal check, with the dependent test suite deliberately deferred to
Phase 3, which owns it.

**Scope Hypothesis**: Six range-text sites (four `1-22`, one `twenty-two`, one `-gt 22`) and one
appended block, with no existing gate renumbered. Confirm at implement time with
`grep -n '1-22\|twenty-two\|gt 22'` returning zero hits and
`grep -c 'CURRENT_GATE="gate' verify-deploy.sh` returning 24 (gate0 through gate23).

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - append the blocking gate 23 block after gate 22's closing `fi` and before the zero-check-under-filter tail; widen the `--only-gate` accepted range to `1-23` in place

**Verification**:
- `bash -n` clean; `grep -n '1-22\|twenty-two\|gt 22'` finds nothing.
- `--only-gate 23` against the source store: exit 0, exactly one gate header, `PASS -- 1 check(s)`.
- `--only-gate 24`: exit 2 with the named out-of-range error citing `1-23`.
- `grep -c 'CURRENT_GATE="gate'` returns 24.

---

### Phase 3: Update the gate-selection test suite [NOT STARTED]

**Goal**: Bring `test-verify-deploy-gate-selection.sh` into agreement with a 23-gate battery,
including the invalid-id assertion that adding gate 23 inverts.

**Tasks**:
- [ ] Re-read the file immediately before editing.
- [ ] Change `invalid_cases=("abc" "0" "23" "1,abc" "1,99")` to use `24` in place of `23`. This is
      the load-bearing fix: with gate 23 now valid, the old list asserts exit 2 for an id that is
      accepted, and case (c) fails. Leave `abc`, `0`, `1,abc`, `1,99` untouched.
- [ ] Change both `for n in $(seq 1 22); do` loops to `$(seq 1 23)` — case (b) (every gate id runs
      clean standalone against `FIXTURE_RICH`) and case (d) (every gate header appears in a
      no-flag run against `FIXTURE_CHEAP`).
- [ ] Update the count text in the two `pass` messages (`all 22 gates run clean standalone`,
      `all 22 gate headers appear`) and the four header/comment prose occurrences (the
      `full 22-gate battery` line, the `all 22 gate headers (case (d))` line, the
      `Case (d) asserts only that all 22 gate headers appear` line, and case (d)'s own
      `all 22 gate numbers appear` comment) to 23.
- [ ] Confirm no stale count remains: `grep -n '22' agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`
      — every surviving hit must be a deliberate reference to gate 22 itself, not to the battery
      size. Expect none of the latter.
- [ ] Run the suite with the complete bounded-wait idiom (Bash tool `timeout: 600000`, inner
      `timeout 540`, log + grep — never `run_in_background`, never a Monitor):
      ```
      cd /home/benjamin/.config/nvim && \
      timeout 540 bash agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh \
        > /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/gate-selection.log 2>&1; \
      echo "exit=$?"; \
      grep -E '^\[(PASS|FAIL)\]|^Results:' /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/gate-selection.log
      ```
      Expect exit 0 and `Results: 9 passed, 0 failed` (the suite's current case count; 9 was its
      state after commit `7da3e047a`). A different pass count is acceptable only if every line is
      `[PASS]` and `0 failed` — record the number either way rather than asserting a stale one.
- [ ] Commit this file's hunks alone, with an explicit file list.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: Phase 2 widened an externally visible accepted-argument range whose call
sites span multiple files, so this phase runs the one enumerated direct dependent that asserts
against it end-to-end: `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`.

**Scope Hypothesis**: Eight edit sites in one file (one `invalid_cases` list, two `seq 1 22`
loops, two `pass`-message strings, three prose/comment counts). Confirm at implement time with
`grep -n '22'` on the file, leaving only genuine gate-22 references.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - change the invalid-gate-id list from `23` to `24`, widen both `seq 1 22` loops to `seq 1 23`, update the five count-bearing prose/assertion strings

**Verification**:
- `grep -n '22'` leaves only deliberate gate-22 references.
- The suite exits 0 with `0 failed`; cases (b), (c) and (d) all report `[PASS]`.

---

### Phase 4: Correct the git-staging-scope.md cross-reference bullet [NOT STARTED]

**Goal**: Replace the bullet's superseded "not yet wired / the natural wiring point is gate 17"
sentence with the actual ruling and its rationale.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` immediately
      before editing. Three live tasks share this file with distinct regions; **this task owns
      only** the `lint-directory-pathspec-boundary.sh` bullet (the "complementary mechanical
      guardrail" bullet, currently around lines 712-720). Do not touch the exit-code table or the
      task-scoped pathspec carve-out ruling — those belong to other live tasks.
- [ ] Replace the final sentence of that bullet (the `**Not yet** wired as a \`verify-deploy.sh\`
      gate: the natural wiring point (\`verify-deploy.sh\` gate 17, alongside its sibling)...`
      sentence, through `see that task's summary for the follow-up.`) with prose stating: the lint
      is wired as `verify-deploy.sh` **gate 23**, a blocking gate; the placement is deliberately
      trailing rather than inserted beside gate 17, because inserting there would renumber gates
      18-22 and silently invalidate the heavy by-number citations of those gates (gate 20 alone is
      cited in over a hundred files); and a green gate 23 certifies "no bare shared-directory
      pathspec token, as written", not that pathspecs are correct.
- [ ] Leave the immediately preceding `lint-scoped-commit-boundary.sh` bullet's "wired as
      `verify-deploy.sh` gate 17" text exactly as it is — gate 17 did not move.
- [ ] State the current design only: no "previously", "no longer", "formerly", or draft-history
      framing, and no task-number citation (`no-record-versioning-in-deliverables.md`,
      `no-task-references-in-deliverables.md` — this file is outside `specs/**`). Cite the lint
      filename and the gate number as the durable anchors.
- [ ] Run the doc-gate subset, naming an explicit source-store TARGET (the no-argument form would
      resolve TARGET to the consumer root and silently SKIP both gates):
      ```
      cd /home/benjamin/.config/nvim && \
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow \
        --only-gate 3,4 /home/benjamin/.config/nvim \
        > /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-doc-gates.log 2>&1; \
      echo "exit=$?"; \
      cat /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-doc-gates.log
      ```
      (Bash tool `timeout: 600000`.) Expect exit 0 and two real, non-SKIP `[PASS]` lines.
- [ ] Commit this file's hunks alone, with an explicit file list.

**Timing**: 0.25 hours

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: The edit is confined to one markdown bullet with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` and no suite covers it; the honest covering
check is plan-format.md's sub-case (b) —
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
— run together with the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - rewrite the closing sentence of the `lint-directory-pathspec-boundary.sh` cross-reference bullet to state the gate-23 wiring and the trailing-placement rationale

**Verification**:
- Diff read-through confirms every changed hunk lies inside that one bullet.
- The bullet names gate 23, states the no-renumbering rationale, and contains no version-history
  or task-number language.
- `--only-gate 3,4` against the source store: exit 0, two non-SKIP `[PASS]` lines.

---

### Phase 5: Full gate set, suite regression sweep, and baseline comparison [NOT STARTED]

**Goal**: Close the task against the complete gate set, prove the check count incremented by
exactly one over Phase 1's baseline, and prove the three affected suites are unregressed.

**Tasks**:
- [ ] Run the complete gate set against the source store, with the full bounded-wait idiom (Bash
      tool `timeout: 600000`, inner `timeout 540`, log + grep; never `run_in_background`, never a
      Monitor, never awaiting a harness notification):
      ```
      cd /home/benjamin/.config/nvim && \
      timeout 540 bash agent-system/extensions/core/scripts/verify-deploy.sh \
        /home/benjamin/.config/nvim \
        > /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-final.log 2>&1; \
      echo "exit=$?"; \
      grep -E '^\[verify-deploy\] (PASS|FAIL)' /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-final.log; \
      grep -E '^23\. |^\s*\[PASS\] directory-pathspec|^\s*\[FAIL\]' /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/vd-final.log
      ```
- [ ] Confirm the `23. ` gate header appears, its `[PASS]` line appears, and the
      `PASS -- N check(s)` total is **exactly one greater** than Phase 1's recorded baseline `N`.
- [ ] Attribute, do not investigate, any failure that was already present in Phase 1's baseline
      `[FAIL]` list: those are pre-existing (most likely deployed-`.claude/`-tree staleness
      against the source store, which the orchestrator's own next redeploy checkpoint resolves).
      A failure **absent** from the baseline is this task's regression and must be fixed before
      the phase closes.
- [ ] If gate 8 reports exactly one failing suite and it is `test-four-tier-conflict.sh` Case 6
      (a `[1000ms,2000ms)` timing assertion measuring ~2.3-2.8s under concurrent load), attribute
      it as the known pre-existing flake and move on.
- [ ] Re-run the lint's own fixture test and confirm no regression:
      `cd /home/benjamin/.config/nvim && timeout 300 bash agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh 2>&1 | tail -5`
      (Bash tool `timeout: 320000`.) Expect `14 passed, 0 failed`.
- [ ] Re-run the gate-selection suite and confirm `0 failed` (same bounded-wait shape as Phase 3).
- [ ] Run `test-verify-deploy-context-budget.sh` — it is in this task's `file_scope` and needs
      **no edit**, but its baseline case is the one deliberate full-battery `verify-deploy.sh`
      invocation in the suite, so it now exercises gate 23 and must be shown green. Gate 23 runs
      for real against that suite's `FIXTURE` (an rsync copy of `agent-system/extensions/`, so the
      lint's default scan root exists and resolves), and the lint enumerates via `find`, not
      `git ls-files`, so the fixture's on-disk content suffices with no fixture change. Full
      bounded-wait idiom (Bash tool `timeout: 600000`, inner `timeout 540`, log + grep):
      ```
      cd /home/benjamin/.config/nvim && \
      timeout 540 bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh \
        > /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/context-budget.log 2>&1; \
      echo "exit=$?"; \
      grep -E '^\[(PASS|FAIL)\]|^Results:' /tmp/claude-1000/-home-benjamin--config-nvim/0305212c-2357-4737-a558-613261194a3f/scratchpad/context-budget.log
      ```
      Expect exit 0. Its baseline-sanity assertion (`baseline_rc -eq 0`) is the specific line that
      would catch a gate 23 that fails inside a fixture tree.
- [ ] Do **not** run `deploy-headless.sh` or hand-copy anything into `.claude/**`. The dispatch's
      CLOSE BY names `bash .claude/scripts/verify-deploy.sh`, i.e. the deployed copy; that copy
      carries gate 23 only after a redeploy, and the orchestrator's own next redeploy checkpoint
      performs it. The source-store run above is the authoritative evidence for this phase, and
      this substitution is a deliberate, recorded deviation from the dispatch's literal wording,
      not an oversight. Expect the completion-deploy gate to refuse completion while the deployed
      `core` tree is stale; that resolves on the next cycle without a manual workaround.
- [ ] Commit the task's completion state with an explicit file list.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- none planned — this phase only verifies

**Verification**:
- The complete gate set (`bash agent-system/extensions/core/scripts/verify-deploy.sh <source_dir>`,
  all 23 gates plus gate0, gate 8's full shell battery included — no `--skip-slow`, no
  `--only-gate`) runs, the `23. ` header and its `[PASS]` line appear, and the
  `PASS -- N check(s)` total is exactly Phase 1's baseline plus one.
- Every `[FAIL]` line, if any, is present verbatim in Phase 1's baseline list, or is the known
  `test-four-tier-conflict.sh` Case 6 flake.
- `test-lint-directory-pathspec-boundary.sh`: `14 passed, 0 failed`.
- `test-verify-deploy-gate-selection.sh`: `0 failed`.
- `test-verify-deploy-context-budget.sh`: exit 0, including its full-battery baseline-sanity case.

---

## Testing & Validation

- [ ] `lint-directory-pathspec-boundary.sh` reports 0 violations immediately before the gate is
      wired as blocking (Phase 1) and the gate passes in the full battery (Phase 5).
- [ ] `--only-gate 23` is accepted and attests to one real check against the source store;
      `--only-gate 24` is refused with the named `1-23` range error.
- [ ] `test-verify-deploy-gate-selection.sh` passes, with cases (b), (c) and (d) all green under a
      23-gate battery.
- [ ] `test-lint-directory-pathspec-boundary.sh` still reports `14 passed, 0 failed`.
- [ ] `test-verify-deploy-context-budget.sh` passes, including its full-battery baseline case.
- [ ] No existing gate number changed: `grep -c 'CURRENT_GATE="gate'` is 24, and gates 17-22 keep
      their numbers.
- [ ] The total `PASS -- N check(s)` count incremented by exactly one over the pre-change baseline.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` — blocking gate 23 and a `1-23`
  `--only-gate` range.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — assertions
  updated to a 23-gate battery.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — corrected
  cross-reference bullet.
- Four verification logs under this session's scratchpad (baseline, gate-23 standalone,
  gate-selection, context-budget) — evidence only, not deliverables.
- An execution summary at `specs/318_wire_directory_pathspec_lint_as_verify_deploy_gate/summaries/01_wire-lint-as-deploy-gate-summary.md`.
- Issue-log entries recorded **as they arise** via `bash .claude/scripts/issue-record.sh
  --task-dir ... --kind issue|win --class ... --severity ... --what-happened ... --phase implement
  --dispatch-seq <seq>`, non-fatally. A dispatch with genuinely nothing to record attests that
  explicitly in its handoff prose.

## Rollback/Contingency

Every phase commits its own file's hunks separately, so reverting is a per-file `git revert` of
that phase's commit — no snapshot is required and none should be taken in `git-snapshot.sh`'s
default reverting mode (sibling tasks are live on this tree; use `--no-revert` if a defensive
checkpoint is genuinely wanted).

The gate itself has a zero-code rollback: `--only-gate` is additive and the gate block is the
last one in the file, so reverting Phase 2's commit alone restores a 22-gate battery exactly, and
Phase 3's and Phase 4's commits are independently revertible (a stale "23" in a test assertion or
a doc bullet is a cosmetic inconsistency, not a failure).

If wiring reveals lint violations, the contingency is to fix the violating call site or justify an
allowlist entry in the lint's own Layer-3 allowlist — never to broaden the classifier so the
finding disappears, and never to wire the gate as advisory to dodge a real finding.
