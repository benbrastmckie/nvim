# Implementation Plan: Task #425

- **Task**: 425 - State files dropped as file_scope excursions
- **Status**: [COMPLETED]
- **Effort**: 2.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/425_state_files_dropped_as_file_scope_excursions/reports/01_state-files-excursion-predicate.md
- **Artifacts**: plans/01_state-files-excursion-allowlist.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-postflight.sh`'s WORK (h) containment predicate compares every
`.return-meta.json` `modified_files` entry against the task's own declared `file_scope`, with no
exemption for the two shared state files the engine writes on behalf of every task. When a task
reports `specs/TODO.md` and `specs/state.json` in `modified_files` — which production dispatches
routinely do — both are classified as excursions, producing a false `ADVISORY` line, a false
`EXCURSION DROPPED` line per file, and an inflated `excursion_dropped_count`. This plan adds a
third literal-path splice to `effective_file_scope_json` (mirroring `git-commit-scoped.sh`'s
already-landed V10 allowlist at a sibling containment site), pins the new behavior plus the
unchanged drop-and-warn behavior for a genuine excursion with new fixtures in
`test-orchestrate-cycle-postflight.sh`, and records the landing in `git-staging-scope.md`'s
"Three Containment sites" section. Done when the two state files produce no excursion diagnostic,
an arbitrary out-of-scope path is still dropped and warned exactly as today, and the full gate set
is green.

### Research Integration

The research report confirms the dispatch's root-cause location exactly (WORK (h)'s
`effective_file_scope_json` / `excursions_json` computation, `orchestrate-cycle-postflight.sh`
lines 1571-1604) and refines the dispatch's hypothesis in one load-bearing way, which this plan
adopts:

- **The files are not actually dropped from the commit today.** WORK (i) seeds
  `stage_paths=("${TASK_DIR}/" "$(dirname "$STATE_FILE")/TODO.md" "$STATE_FILE")` unconditionally
  *before* the per-entry excursion loop runs, so the loop's `continue` on a classified excursion
  only skips a redundant second append. Verified empirically against the dispatch's own cited
  incident: task 170's cycle-1 commit `0a64d476e` contains both `specs/TODO.md` and
  `specs/state.json` in its diff, even though that cycle's `.return-meta.json` listed both in
  `modified_files` and neither is in that task's 19-entry declared `file_scope`.
- **The confirmed harm is therefore the false diagnostic plus the inflated counter**, not
  commit-time data loss — and the "no loss" property rests entirely on that separate,
  undocumented-as-deliberate carve-out. The fix is still exactly the allowlist the dispatch asks
  for; the plan additionally documents the carve-out so a future reader cannot mistake either
  layer for sufficient on its own, and does not remove it.
- **Fix site**: WORK (h)'s splice, not WORK (i)'s loop. WORK (h) is the single producer of
  `excursions_json`, which drives both the `ADVISORY` line (WORK (h) itself, line 1603) and the
  `EXCURSION DROPPED` line plus counter (WORK (i), lines 1859-1872). One splice silences both
  false positives at their source with no change to the loop, the commit call, or the carve-out.
- **Precedent**: `git-commit-scoped.sh:499` already carries
  `containment_scope_arr+=("specs/TODO.md" "specs/state.json")`. `git-staging-scope.md`'s "Three
  Containment sites, not one" section is explicit that this V10 guard does not subsume WORK
  (h)/(i), so the allowlist genuinely has to be added at this second site.
- **Test gap**: no existing case in `test-orchestrate-cycle-postflight.sh` ever places
  `specs/TODO.md` or `specs/state.json` inside `modified_files`, which is the sole trigger for
  the false positives. The existing "Invariant: modified_files-vs-file_scope excursion never
  changes exit code or verdict" block (~line 1203) and "specs/ carve-out" block (~line 1310) give
  the exact harness shape to extend.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Not consulted — this dispatch's context carries no `roadmap_path` and no `roadmap_flag`, so no
roadmap phases are added and no roadmap item is claimed.

## Goals & Non-Goals

**Goals**:
- WORK (h)'s excursion predicate stops classifying `specs/TODO.md` and `specs/state.json` as
  excursions, eliminating the false `ADVISORY` line, the false `EXCURSION DROPPED` lines, and
  their contribution to `excursion_dropped_count`.
- The drop-and-warn behavior for every other out-of-`file_scope` path stays byte-for-byte
  unchanged, pinned by a test in the same run that allowlists the two state files.
- The `excursion_dropped_count` summary line counts only genuine excursions.
- The relationship between WORK (h)'s new allowlist and WORK (i)'s pre-existing unconditional
  `stage_paths` carve-out is documented at both the code site and in `git-staging-scope.md`.

**Non-Goals**:
- Removing, consolidating, or "simplifying away" WORK (i)'s unconditional `stage_paths`
  carve-out. It stays as an independent second layer; it is the only thing guaranteeing no real
  commit-time loss today.
- Promoting the advisory into a gate, or changing exit codes, verdicts, or any
  `excursions_json` consumer semantics.
- Widening the allowlist beyond the two engine-written literals the dispatch names.
- Touching `is_contained_v10()` / `is_contained()` or any glob-matching predicate (task 440's
  territory; research confirmed the two defects are disjoint and need no dependency edge).
- Changing `git-commit-phase.sh`'s site-2 self-check or `git-commit-scoped.sh`'s V10.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The splice is read as license to keep adding "convenience" literals, eroding predicate precision | M | M | The in-code comment states the *criterion* (engine-written on behalf of every task, never declarable in any task's own `file_scope`), not just the two paths, so a future addition must meet that bar |
| A reviewer concludes the fix is cosmetic (research proved no commit-time loss) and skips it | M | L | Overview and Research Integration state plainly that the false diagnostic is the confirmed harm that spawned the task, and that "no loss" is a fragile property of a separate carve-out |
| New fixture passes accidentally (tautological — would pass pre-fix too) | H | M | Phase 2 includes an explicit pre-fix reproduction check against a scratch copy of the script with the splice disabled; the fixture must fire the false `EXCURSION DROPPED` there and not fire against the real script |
| `startswith` semantics make `specs/state.json` also admit `specs/state.json.tmp` | L | L | Accepted: identical to V10's own literal-prefix behavior and to every existing entry in this predicate; no new semantics are introduced. Noted here rather than special-cased |
| A sibling task commits into the same source-store tree this cycle | M | M | Three concurrent siblings (427, 400, 422) have disjoint `file_scope`s — none names `orchestrate-cycle-postflight.sh`, its test suite, or `git-staging-scope.md`. Still re-read each file immediately before editing and stage only this task's own explicit file list, never a directory or glob |
| Deployed `.claude/` tree edited by mistake instead of the source store | H | L | Every phase names its edit target under `agent-system/extensions/core/`; Phase 4 regenerates `.claude/` from the source store via `deploy-headless.sh` |

### Rejected alternative: deriving the allowlist from `$STATE_FILE`

A derived form (`state_file_rel="${STATE_FILE#"$PROJECT_ROOT"/}"` plus its sibling `TODO.md`)
would keep WORK (h) congruent with WORK (i)'s own carve-out, which *is* derived. It is declined:
`run_sut` in the test suite always passes `--state-file specs/state.json`, and no caller anywhere
passes a non-standard path, so the derived branch would be untested complexity with its own
degenerate cases (a `dirname` of `.` for a bare filename). The literal form matches V10's landed
precedent exactly and is what Phase 1's comment flags for joint review should `$STATE_FILE` ever
be relocated.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Splice the engine-written state-file allowlist into WORK (h) [COMPLETED]

**Goal**: `excursions_json` no longer contains `specs/TODO.md` or `specs/state.json`, so neither
the WORK (h) `ADVISORY` line nor WORK (i)'s `EXCURSION DROPPED` line and counter can fire for
them.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` lines
      1565-1605 immediately before editing (concurrency: three siblings are live this cycle).
      *(completed)*
- [x] Insert a third splice into `effective_file_scope_json`, after the derived-output-prefix
      splice (currently ending at line 1593) and before the `excursions_json=$(jq -c -n ...)`
      computation (currently line 1599):
      `effective_file_scope_json=$(echo "$effective_file_scope_json" | jq -c '. + ["specs/TODO.md", "specs/state.json"]')`,
      guarded in the same defensive shape as the two existing splices (assign to a temp, and only
      overwrite `effective_file_scope_json` on `jq` success, so a `jq` failure is a no-op rather
      than an empty scope). *(completed)*
- [x] Add the comment block above the splice stating: these two paths are written by
      `update-task-status.sh` and this postflight on behalf of EVERY task and are never
      declarable in any task's own `file_scope`; this mirrors `git-commit-scoped.sh`'s V10
      allowlist at a sibling, non-subsuming containment site; see `git-staging-scope.md`'s "Three
      Containment sites, not one". State the admission criterion, not merely the two paths.
      *(completed)*
- [x] Add a one-line note recording that the allowlist is deliberately literal (not derived from
      `$STATE_FILE`) and that relocating `$STATE_FILE` requires reviewing this splice and WORK
      (i)'s `stage_paths` seed together. *(completed)*
- [x] Add a one-line comment at WORK (i)'s `stage_paths=(...)` seed (currently line 1843) noting
      it is an independent second layer now reinforced by — not superseded by — WORK (h)'s
      allowlist, and that removing it would reintroduce genuine loss. *(completed)*
- [x] Confirm the gating `if [ "$(echo "$file_scope_json" | jq 'length')" -gt 0 ]` guard and the
      `excursions_json='[]'` default at line 1571 are untouched (the fail-open path for a task
      declaring no `file_scope` must stay byte-identical). *(completed: verified via grep,
      both lines unchanged)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: The edit is confined to one bash script with no exported function or
signature change, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
is the suite that covers this file end-to-end, including the existing excursion and fail-open
cases this phase must not regress.

**Scope Hypothesis**: This phase asserts the edit is one ~6-line splice plus three comment
insertions at two sites in a single file, with no change to WORK (i)'s loop logic, the commit
call, or the `stage_paths` seed itself. Confirm by reading lines 1565-1605 and 1835-1875 before
editing and by `git diff --stat` showing exactly one changed file afterwards.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - third
  `effective_file_scope_json` splice plus its rationale comment in WORK (h); one-line
  reinforcement comment at WORK (i)'s `stage_paths` seed.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` passes.
- `shellcheck` on the file reports no new findings relative to its pre-edit baseline.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  is green — in particular the pre-existing "Invariant: modified_files-vs-file_scope excursion
  never changes exit code or verdict", "Fail-open: an empty declared file_scope commits every
  reported modified_files entry, unfiltered", and "specs/ carve-out" cases all still pass.

---

### Phase 2: Pin the allowlist and the surviving drop-and-warn with new fixtures [COMPLETED]

**Goal**: The suite proves all three VERIFY requirements from the dispatch — the two state files
are not dropped or warned about, an arbitrary out-of-scope path still is, and the counter reports
accurately in both cases — and proves the new fixture is capable of failing pre-fix.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      around the "Invariant: modified_files-vs-file_scope excursion..." block (~line 1203) and
      the "specs/ carve-out..." block (~line 1310) immediately before editing. *(completed)*
- [x] Add one new case, modeled on those two blocks and using the same harness
      (`setup_sandbox`, `write_state`, `commit_fixture`, `run_sut`, assertions on `$LAST_STDERR`
      and `git show --name-only --format= HEAD`), with a fixture that:
      declares a non-empty `file_scope` naming neither state file; creates and baselines a real
      on-disk out-of-scope path (e.g. `completely/unrelated/excursion.sh` at v1, modified to v2
      post-baseline, following the existing block's own anti-tautology comment); and writes a
      `.return-meta.json` whose `modified_files` lists, together in one array, an in-scope
      artifact, `specs/TODO.md`, `specs/state.json`, and the genuine excursion path. *(completed:
      task 718 fixture, `completely/unrelated3/excursion3.sh`)*
- [x] Assert, in that one run: zero `EXCURSION DROPPED` lines naming `specs/TODO.md`; zero naming
      `specs/state.json`; zero `ADVISORY` lines naming either; exactly one `EXCURSION DROPPED`
      line naming the genuine excursion path; both state files present in the commit's
      `--name-only` output; the genuine excursion path absent from it and still dirty on disk
      afterwards; exit 0 and `verdict=ok`. *(completed)*
- [x] Assert the counter line reports `1 of N` (only the genuine excursion), matching the
      `excursion_dropped_count` summary wording at the script's line 1872, so the counter claim
      is pinned rather than inferred. *(completed: "1 of 4")*
- [x] Follow the suite's existing assertion style: match the literal `EXCURSION DROPPED` /
      `ADVISORY` substrings plus the specific path, never a loose pattern that would survive a
      wording change. *(completed)*
- [x] Pre-fix reproduction check (no commit of a red state) *(completed with one mechanical
      deviation: instead of copying the script to the scratchpad and pointing the test harness
      at the copy — `CORE_DIR`/`$SUT` resolution in the harness is not easily re-targeted without
      touching the harness itself — the real source-store file was backed up to the scratchpad,
      the new splice line was commented out in place, the suite was run directly against the
      disabled file, then the backup was restored and verified byte-identical via `md5sum` and a
      clean `git diff --stat`. Same evidentiary result: the new case failed with the false
      `EXCURSION DROPPED`/`ADVISORY` lines for both state files against the disabled version, and
      passed cleanly (274/0) after restoration. See phase-2-progress.json's `verification_notes`
      for the full record.)*
- [x] Run the whole suite (not only the new case) to confirm no existing case regressed.
      *(completed: 274 passed, 0 failed via `run-all.sh --only test-orchestrate-cycle-postflight.sh`)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit adds one self-contained case to a single test file with no
product-code surface at all, and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
runs exactly the suite being edited.

**Scope Hypothesis**: This phase asserts one new test block (~60-80 lines) in one file suffices,
with no change to `run_sut`, `write_state`, `commit_fixture`, or any existing case. Confirm by
`git diff --stat` showing a single changed file with additions only, and by the full-suite run
showing the pre-edit case count plus the new assertions.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - one new
  fixture case covering the allowlisted state files alongside a genuine excursion in the same
  run.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  is green with every new assertion passing.
- The pre-fix reproduction check above demonstrated the new case failing against a
  splice-disabled scratch copy (recorded in the phase notes), so the case is not tautological.

---

### Phase 3: Record the landing in git-staging-scope.md [COMPLETED]

**Goal**: The "Three Containment sites, not one" section states that site 1 now carries its own
engine-written-state allowlist, so a future reader does not re-derive the gap this task closed or
mistake either layer for sufficient alone.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/standards/git-staging-scope.md` lines
      340-372 immediately before editing. *(completed)*
- [x] In the "Three Containment sites, not one" section's site-1 bullet (or the paragraph
      immediately following it), add two to three sentences: site 1 now splices
      `specs/TODO.md` and `specs/state.json` into its own excursion comparison, mirroring site
      3's V10 allowlist; the unconditional `stage_paths` seed remains an independent second layer
      at the same site; and the "Site 1 is NOT subsumed by site 3" asymmetry is unchanged by this
      — the allowlist closed one specific blind spot, not the asymmetry itself. *(completed)*
- [x] Keep the existing "Site 1 is NOT subsumed by site 3" sentence intact; this is an addition,
      not a rewrite. *(completed)*
- [x] State the current design only — no draft-history or supersession framing (see
      `rules/no-record-versioning-in-deliverables.md`), and no task-number citations (see
      `rules/no-task-references-in-deliverables.md`); cite `orchestrate-cycle-postflight.sh`'s
      WORK (h) and `git-commit-scoped.sh`'s V10 by name instead. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The edit is markdown-only with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` and no suite covers it; the honest covering
check for this source-store, non-`specs/**` markdown edit is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
alongside the `prose` tier's own diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - site-1 allowlist note
  in the "Three Containment sites, not one" section.

**Verification**:
- Diff read-through confirming every changed hunk is prose inside that one section. *(confirmed:
  a single ~9-line addition, prose only, immediately after the preserved "Site 1 is NOT subsumed
  by site 3" sentence)*
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` (run with the project root as `TARGET_REPO`, per the script's own
  usage contract, rather than the source-store subpath literally named above) *(gate 4
  task-reference lint: PASS. Gate 3 doc-lint: FAIL, but every reported finding is pending-deploy
  drift — Phases 1-2's source-store edits and this phase's own git-staging-scope.md line-count
  change not yet reflected in the deployed tree or its index-entries.json line-count cache —
  resolved by Phase 4's deploy-headless.sh run and re-verified there; no finding is attributable
  to the content of this phase's own edit. See phase-3-progress.json's verification_notes for
  the full record.)*

---

### Phase 4: Deploy the source store and run the full gate set [COMPLETED]

**Goal**: The deployed `.claude/` tree carries the fix regenerated from the source store, and the
complete gate set is green across the whole repository.

**Tasks**:
- [x] Confirm no hand-authored edit landed under `.claude/**`: all three changed files are under
      `agent-system/extensions/core/` (`rules/source-store-deploy-boundary.md`). *(completed:
      verified via `git diff --stat` on the three deployed-tree paths showing zero diff)*
- [x] Regenerate the deploy tree: `bash .claude/scripts/deploy-headless.sh`. *(completed)*
- [x] Confirm the deployed copies match the source store for the three changed files (diff
      `.claude/scripts/orchestrate-cycle-postflight.sh`,
      `.claude/scripts/tests/test-orchestrate-cycle-postflight.sh`, and
      `.claude/context/standards/git-staging-scope.md` against their source-store originals).
      *(completed: byte-identical via `diff`)*
- [x] Run the complete gate set and confirm green. *(deviation: per dispatch .dispatch/9.md's
      Batch Gate Deferral directive — this task is one of several implement dispatches inside
      one multi-task /orchestrate batch cycle — this phase discharged against the scoped
      invocation covering the files this phase touched instead: `run-all.sh --only
      test-orchestrate-cycle-postflight.sh` (green against the deployed tree) and `verify-deploy.sh
      --skip-slow --only-gate 3,4` (doc-lint + task-reference lint, both PASS, confirming the
      Phase 3 drift is resolved). The complete, unscoped gate set is deferred to the batch stage,
      to run once for the whole invocation and be attributed back to this task via
      `modified_files`, per the directive. See phase-4-progress.json's `batch_gate_deferral` for
      the full record.)*
- [x] Sanity-check the live symptom is gone: the next postflight for a task declaring a non-empty
      `file_scope` emits no `EXCURSION DROPPED` or `ADVISORY` line naming `specs/TODO.md` or
      `specs/state.json`. *(completed: confirmed via the deployed-tree test-suite run above, which
      exercises this exact production code path, plus a direct grep confirming the deployed
      script carries the allowlist splice verbatim)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None directly. `.claude/**` is regenerated by `deploy-headless.sh`, never hand-edited.

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, no `--skip-slow`, no
  `--only-gate` narrowing — exits green. This includes Gate 8's full shell-suite battery, which
  is the only run that counts as evidence the doc-sync pins hold (a `--skip-slow` or selected
  subset pass does not). *(deferred to the batch stage per .dispatch/9.md's Batch Gate Deferral
  directive — see the Tasks annotation above; discharged here against `run-all.sh --only
  test-orchestrate-cycle-postflight.sh` plus `verify-deploy.sh --skip-slow --only-gate 3,4`,
  both green)*
- `bash .claude/scripts/deploy-headless.sh` completed without error and the three deployed files
  match their source-store originals. *(completed)*

---

## Testing & Validation

- [x] `bash -n` clean on both edited shell files.
- [x] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
      green, with the three pre-existing excursion/fail-open/carve-out cases still passing.
- [x] New fixture: zero `EXCURSION DROPPED` and zero `ADVISORY` lines naming `specs/TODO.md` or
      `specs/state.json`, and both files present in the cycle commit.
- [x] New fixture: the genuine out-of-`file_scope` path is still dropped, still warned with the
      literal `EXCURSION DROPPED` wording, still absent from the commit, and still dirty on disk.
- [x] New fixture: the `excursion_dropped_count` summary line counts only the genuine excursion.
- [x] Pre-fix reproduction check recorded: the new case fails against a splice-disabled scratch
      copy of the script. *(performed via backup/disable-in-place/restore on the real file rather
      than a separate scratch copy — see Phase 2's checklist annotation)*
- [x] `bash .claude/scripts/verify-deploy.sh` green (full gate set, Phase 4). *(deferred to the
      batch stage per .dispatch/9.md's Batch Gate Deferral directive; discharged against the
      scoped invocation documented in Phase 4's own Verification — see that phase for detail)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — WORK (h)
  engine-written state-file allowlist splice plus rationale comments at WORK (h) and WORK (i).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — new
  fixture case covering the allowlist and the surviving drop-and-warn in one run.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — site-1 allowlist note.
- Regenerated `.claude/` deploy tree (Phase 4, produced by `deploy-headless.sh`, not hand-edited).
- `specs/425_state_files_dropped_as_file_scope_excursions/summaries/01_*-summary.md` at
  implementation completion.

## Rollback/Contingency

Each phase edits one file and is committed on its own, so a single `git revert` of that phase's
commit restores prior behavior; the deploy tree is then restored by re-running
`bash .claude/scripts/deploy-headless.sh`. The change is additive and fail-open by construction —
the splice is guarded so a `jq` failure leaves `effective_file_scope_json` untouched, and WORK
(i)'s unconditional `stage_paths` seed is untouched throughout, so even a wholly ineffective
splice leaves the two state files committed exactly as they are today. If uncommitted work must
be discarded to recover, take a durable checkpoint first with
`bash .claude/scripts/git-snapshot.sh 425 --no-revert`, and use the reverting default form only
inside a genuine rollback per `context/contracts/recovery.md`'s rollback rung — never as a
routine checkpoint. Three sibling tasks share this working tree this cycle: never revert or clean
a path outside this task's own three files.
