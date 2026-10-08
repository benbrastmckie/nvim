# Implementation Plan: Task #335

- **Task**: 335 - Promote the modified_files-vs-file_scope excursion advisory into a staging-time
  gate, so the per-cycle commit stops carrying paths the advisory already named
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: 284 (completed — own-task-directory exemption in WORK (h))
- **Research Inputs**: specs/335_gate_modified_files_excursion_at_staging/reports/01_excursion-filter-staging-gate.md
- **Artifacts**: plans/01_excursion-filter-staging-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, git-staging-scope.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-postflight.sh` already computes, in WORK (h), exactly the set of
`modified_files` entries that fall outside the dispatching task's declared `file_scope`
(`excursions_json`), logs them as an ADVISORY, and then throws the verdict away. WORK (i), 240
lines later in the same flat script, independently re-reads the same `.modified_files[]` from the
same `.return-meta.json` and appends every entry — excursions included — to `stage_paths` for
`git-commit-scoped.sh`. This plan makes WORK (i) consult WORK (h)'s already-computed verdict
instead of re-deriving the list, and drops the excursion paths from the staged set
(drop-and-warn, never refuse), which is the only one of the three candidate rulings that needs no
change to `git-commit-scoped.sh`'s exit-code contract. Done means: one derivation of the staged
set, one verdict on it; the ruling and its reason recorded in the script header and in
`git-staging-scope.md`; and a synthesised postflight-shaped regression fixture that is red before
the change and green after.

All edits land in the source store (`agent-system/extensions/core/**`), never `.claude/**`, per
`rules/source-store-deploy-boundary.md`.

### Research Integration

Key findings carried from `reports/01_excursion-filter-staging-gate.md`, each re-derived against
the live source store at plan-authoring time (2026-10-08) rather than trusted as carried figures:

- **Current line numbers** (the dispatch's own are stale by its own admission): WORK (h) at
  `orchestrate-cycle-postflight.sh:1445-1481`; WORK (i) at `:1706-1769`; file is 2008 lines.
  Re-confirmed by `grep -n 'WORK (h)\|WORK (i)\|excursions_json'`.
- **No plumbing needed.** WORK (h) sets `meta_file`, `modified_files_json` and `excursions_json`
  as plain top-level shell variables, unconditionally (the `if length>0` guard sits *after*
  `excursions_json='[]'`, and WORK (h) itself is not inside `is_live` or any
  `research_gate_failed` branch). The script has only two functions (`usage`, `is_live`), neither
  between the two sites, so both variables are directly readable at WORK (i).
- **Fail-open is structural, not new code** (work item 4). A task with no declared `file_scope`
  never enters WORK (h)'s `length>0` guard, so `excursions_json` keeps its `'[]'` default and a
  filter subtracting it subtracts nothing.
- **The `specs/` carve-out is structural** (work item 5). `TASK_DIR/`, `TODO.md`, `STATE_FILE`
  and `plan_path` are appended at `:1712-1713` in a statement *before* the `modified_files` loop;
  a filter sited inside that loop structurally cannot reach them.
- **An existing test asserts the pre-fix shape as an invariant.** The `707_candidate` block
  ("Invariant: the excursion advisory never changes exit code or verdict", `:1158-1189`) feeds
  `completely/unrelated/excursion.sh` as a `modified_files` entry but never creates it on disk, so
  `git-commit-scoped.sh`'s pre-existing V2 unmatched-pathspec tolerance already drops it today.
  That fixture therefore cannot distinguish pre-fix from post-fix behaviour and must be MODIFIED
  (real on-disk file, assertion on commit contents), not merely supplemented.
- **Work item 3 (`orchestrator-postflight.sh` Stage 9) → decline.** Orphan status re-confirmed by
  three independent sources (`skill-base.sh:991`, `:1185`;
  `context/reference/state-management-schema.md:288`) plus zero invocation sites repo-wide. A
  gate in dead code is not worth the edit; the decline is recorded, not silently skipped.
- **The out-of-repository-pathspec task is `not_started` with no artifacts.** Its repository-
  containment predicate has not landed, so this plan composes nothing from it and pre-empts
  nothing.
- **The tests run against the source store directly.** `setup_sandbox` copies the SUT and every
  collaborator from `$CORE_DIR` (`agent-system/extensions/core/scripts`) into a synthetic
  `$WORKDIR/.claude/scripts/` tree, so a source-store edit is exercised by the suite with no
  deploy step in between.

### Prior Plan Reference

No prior plan. This is round 1 (`next_artifact_number: 2`, so `artifact_number: 1`).

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are added (`specs/ROADMAP.md` does exist in the repository;
this plan simply does not claim alignment it did not verify).

## Goals & Non-Goals

**Goals**:

- WORK (i) derives its staged set ONCE, from the array WORK (h) already parsed
  (`modified_files_json`), and checks it against WORK (h)'s verdict (`excursions_json`) — closing
  the literal "independently re-reads the SAME `.modified_files[]`" defect.
- An excursion path is dropped from `stage_paths` with a loud, per-path warning, and the rest of
  the commit proceeds (drop-and-warn). The ruling and its reason are recorded in the script
  header.
- A task with no declared `file_scope` commits exactly as it does today (fail open).
- The `specs/` carve-out (`TASK_DIR/`, `TODO.md`, `state.json`, `plan_path`) and the existing
  `modified_count -eq 0` warning branch both stay green; neither becomes a refusal.
- The new behaviour is recorded in `context/standards/git-staging-scope.md` adjacent to its
  "Fail-Safe Direction" section, with the dated 2026-10-04 observation as empirical basis and
  that observation's phase-commit provenance stated accurately.
- The script header and the plan/report state explicitly that this gate does not cover
  in-dispatch phase commits, pointing at
  `agent-system/extensions/core/agents/general-implementation-agent.md`'s
  `#### Phase-Commit Containment Self-Check` heading as the owner of that surface.
- A synthesised postflight-shaped regression fixture fails before the change and passes after.

**Non-Goals**:

- Any change to `scripts/git-commit-scoped.sh`, including a new exit code. If the ruling were to
  require one, that is a FOLLOW-UP owned by the out-of-repository-pathspec task's exit-code
  contract (see Decisions below). The recommended design needs none.
- Adding the gate to `scripts/orchestrator-postflight.sh` Stage 9 (declined; see Phase 4).
- Redefining what `file_scope` means, or touching how it is harvested
  (`plan-file-scope-harvest.sh`, `backfill-file-scope.sh`) or consumed by admission/contention.
- Fixing the own-task-directory filter false positive (dependency 284's completed work).
- The in-dispatch phase-commit staging surface (the sibling task's, already landed).
- Claiming anywhere, in any artifact, that this gate would have prevented the observed
  2026-10-04 commit. It would not have: that commit was a mid-dispatch PHASE commit, not a
  postflight commit.

## Decisions

1. **Ruling on what an excursion does: drop the excursion paths and commit the rest**
   (drop-and-warn, never refuse). Reason, to be recorded verbatim in the script header: it is the
   only candidate that filters `stage_paths` upstream, inside this script, leaving
   `git-commit-scoped.sh`'s exit-code contract (V2/V3/V5/V6/V7, exits 0/1/2/3/4) completely
   untouched — the dropped path is never passed, so no gate there is exercised differently than
   today; it matches `context/standards/git-staging-scope.md`'s own recorded "Under-stage, never
   over-stage" fail-safe direction; and it matches the ruling the sibling phase-commit task
   independently reached at its own layer on the identical predicate. Refusing the commit is
   rejected: it would convert a detection-only channel into a hard failure with no opt-out, on a
   predicate whose own promotion criterion is only now being met, against every fail-open
   precedent this codebase has set for scope/concurrency guards. Widening `file_scope` is out of
   scope by the task's own terms.
2. **This change IS the promotion dependency 284 deferred**, not a departure from its
   "stay advisory" ruling. 284's recorded two-part promotion criterion (bake-in with zero
   false-positive advisories; a repo-relative schema check on `modified_files`) was written
   against promoting to a *blocking* gate — a refusal. Drop-and-warn is a third posture that
   needs neither half: an absolute-path `modified_files` entry (284's named counter-example)
   is dropped rather than committed, which under "under-stage, never over-stage" is the
   fail-safe direction and leaves the path on disk for manual review, not a blocked dispatch.
   The header must state this distinction explicitly rather than claiming 284's criterion is
   satisfied.
3. **`modified_count` keeps counting every REPORTED entry**, not every staged one. This preserves
   the existing `modified_count -eq 0` warning's meaning ("nothing was reported", per
   `git-staging-scope.md`'s sanctioned wording, which must not acquire a second convention). A
   separate counter tracks dropped excursions for the new warning line.
4. **Terminology is borrowed from the sibling phase-commit task** for one vocabulary across the
   two layers: "Containment predicate" (one concrete path vs. one task's own scope, as distinct
   from the Overlap-family `--task`/V5 check), "drop-and-warn, never refuse the whole commit",
   "fail OPEN on a missing/malformed `file_scope`".
5. **Work item 3 is declined**, with the three-source orphan evidence as the recorded reason.
6. **`issue-record.sh` is NOT called from the drop path.** The sibling task's phase-commit
   recipe records a `--class "scope excursion"` issue because it runs inside an agent dispatch
   that owns a task directory. This script already has its own established, structured diagnostic
   channels (stderr `notice_prefix` warnings and `system-defect-record.sh`), and the dispatch
   does not ask for a defect record; a stderr warning plus the pre-existing ADVISORY is the
   proportionate signal. Recorded as a decision so a later reader does not read the omission as
   an oversight.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Reusing `excursions_json` creates an ordering dependency: a future refactor that moves WORK (h) after WORK (i), or wraps either in a function, silently breaks the filter (unset variable under `set -u`, or an empty default that drops nothing) | H | M | Phase 4 adds an explicit header note recording the ordering dependency; Phase 2 reads the variable with no `:-` default fallback on `excursions_json` so a future `set -u` violation fails loudly rather than degrading to a silent no-op |
| The all-entries-are-excursions edge: every reported path is dropped, leaving `stage_paths` as only the four `specs/` entries — could trip `git-commit-scoped.sh`'s V3 degenerate-pathspec refusal (exit 2) or V6 (exit 4) | M | L | Shape is identical to today's already-working `modified_count -eq 0` path, so no new refusal is expected; Phase 3 adds an explicit fixture for it rather than relying on that reasoning |
| The modified `707_candidate` fixture's new commit-contents assertion needs a real prior state for the excursion path, or it tests nothing | M | M | Phase 1 creates AND commits the excursion file in the fixture's existing `commit_fixture` baseline, then modifies it, so `git show --name-only HEAD` has a genuine present/absent distinction |
| Concurrent sibling (plan dispatch, same cycle) declares `agent-system/extensions/core/agents/general-implementation-agent.md` in its `file_scope` — the file whose `#### Phase-Commit Containment Self-Check` heading Phase 4 must cite | M | M | Phase 4 re-greps for that exact heading immediately before writing the pointer; if it has moved or been renamed, cite the file plus the nearest surviving durable heading rather than a stale anchor. Never edit that file — it is outside this task's `file_scope` |
| `shellcheck`'s resolved Nix store binary was missing at research time | M | M | Phase 6 establishes a pre-change baseline on the unmodified file first and diffs against it; if the binary is genuinely unavailable, record that fact explicitly as an unmet acceptance item rather than reporting a clean run |
| Writing a gate into a file on `context/reference/orchestrator-critical-paths.json` (self-modification admission gate) | M | H (certain) | Declared in the task description, not dodged; the change is one conditional inside the commit path and is exercised end-to-end by the suite's own sandboxed copy of the script before any deploy |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4, 5 | 2 |
| 4 | 6 | 3, 4, 5 |

Phases within the same wave can execute in parallel. Wave 3's three phases touch three
different files (test suite / script header / standards doc) and so are genuinely parallel-safe.

---

### Phase 1: Red regression fixture for the excursion shape [COMPLETED]

**Goal**: Turn the existing `707_candidate` excursion block into a fixture that can actually
distinguish pre-fix from post-fix behaviour, and confirm it is RED against the unmodified script.

**Tasks**:

- [x] Re-read `scripts/tests/test-orchestrate-cycle-postflight.sh:1158-1189` immediately before
      editing (a sibling may be live on the shared tree). *(completed)*
- [x] In the `707_candidate` block, create the excursion path as a real file
      (`mkdir -p "$WORKDIR/completely/unrelated" && echo v1 > "$WORKDIR/completely/unrelated/excursion.sh"`)
      BEFORE the existing `commit_fixture` call, so the fixture's baseline commit tracks it.
      Note `commit_fixture` only adds `specs/ .claude/`, so add this path explicitly in the
      fixture (an extra, targeted `git add` of that one path, not a widened `commit_fixture`).
      *(completed)*
- [x] After the baseline commit, modify the file (`echo v2 > ...`) so there is a real,
      uncommitted change at an excursion path for the SUT's commit to either carry or drop.
      *(completed)*
- [x] Keep all three existing assertions (exit 0, `verdict=ok`, ADVISORY logged) — they remain
      true under the chosen ruling and are the invariant half of this case. *(completed)*
- [x] Add the new assertion on COMMIT CONTENTS: `git -C "$WORKDIR" show --name-only --format= HEAD`
      must NOT list `completely/unrelated/excursion.sh`, and MUST list the summary path
      `specs/707_candidate/summaries/01_x-summary.md`. *(completed: summary file also given a
      genuine post-baseline content change, v1->y2, so its presence in the commit is a real
      distinction rather than a tautology)*
- [x] Add a companion assertion that the dropped path is still dirty on disk afterwards
      (`git -C "$WORKDIR" status --porcelain -- completely/unrelated/excursion.sh` is non-empty) —
      proving "under-staged and left for review", not "lost". *(completed)*
- [x] Run the suite and record that the new assertion FAILS while the three pre-existing ones
      PASS. A green run here means the fixture is not exercising the defect — stop and fix the
      fixture before proceeding. *(completed: 2 of the 3 new assertions FAIL pre-fix — both
      attributable to the single excursion-commit defect, FAIL line names
      completely/unrelated/excursion.sh — the three pre-existing assertions PASS; 193 passed, 2
      failed overall, no other case regressed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the `707_candidate` excursion block is at
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh:1158-1189` and
the file is 2933 lines (re-derived by `grep -n`/`wc -l` at plan-authoring time 2026-10-08, not
carried from the research report). Confirm by `grep -n "excursion" ` on that file before editing;
line numbers drift with every sibling edit, so locate the block by its `info "Invariant:
modified_files-vs-file_scope excursion..."` string, never by line number.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - make the
  excursion path real and on-disk; add commit-contents and left-on-disk assertions

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` runs to
  completion (exit 1 expected) with exactly the new commit-contents assertion reported `[FAIL]`
  and no other previously-passing case regressing.
- The FAIL line names `completely/unrelated/excursion.sh`, confirming the assertion reaches the
  intended path rather than failing for a fixture-setup reason.

---

### Phase 2: Make WORK (i) consult WORK (h)'s verdict [COMPLETED]

**Goal**: One derivation of the staged set, one verdict on it — WORK (i) iterates the array WORK
(h) already parsed and skips every entry WORK (h) named an excursion, with a loud per-path
warning. Phase 1's fixture goes green.

**Tasks**:

- [x] Re-read `orchestrate-cycle-postflight.sh:1706-1769` immediately before editing. *(completed)*
- [x] Replace WORK (i)'s `while IFS= read -r f; ... done < <(jq -r '.modified_files[]? // empty'
      "$meta_file" 2>/dev/null)` process substitution with one that iterates
      `modified_files_json` (the array WORK (h) already parsed from the same file in the same
      run), e.g. `< <(jq -r '.[]? // empty' <<<"$modified_files_json")`. Drop the now-redundant
      `meta_file=` re-assignment at WORK (i) only if nothing else below it reads that variable —
      check before removing. *(completed: redundant `meta_file=` re-assignment at WORK (i)
      removed; confirmed the top-level `meta_file` set by WORK (h) at line 1446 is the only
      remaining one and nothing else in WORK (i) read the local re-assignment)*
- [x] Inside the loop, test each non-empty entry for membership in `excursions_json`
      (`jq -e --arg p "$f" 'any(.[]; . == $p)' <<<"$excursions_json" >/dev/null`) and, on a hit,
      `continue` without appending to `stage_paths`, after emitting a warning naming the dropped
      path and the reason, e.g.:
      `${notice_prefix} EXCURSION DROPPED: '<path>' is outside task <N>'s declared file_scope — not staged for this cycle's commit (left uncommitted on disk for review). Containment predicate: drop-and-warn, never refuse.` *(completed, verbatim)*
- [x] Read `excursions_json` with NO `:-` default fallback, so a future refactor that moves WORK
      (h) after WORK (i) fails loudly under `set -u` instead of silently dropping nothing.
      *(completed)*
- [x] Keep `modified_count` incrementing for every REPORTED entry (Decision 3) and add a separate
      `excursion_dropped_count`; emit one summary line when it is `> 0`. *(completed)*
- [x] Leave the `modified_count -eq 0` branch and its sanctioned warning wording byte-identical.
      *(completed, unchanged)*
- [x] Leave the four `specs/` carve-out appends at `:1712-1713` untouched and outside the loop.
      *(completed, unchanged)*
- [x] Re-run Phase 1's fixture: all four assertions green. *(completed: all 5 assertions in the
      block pass — exit 0/verdict=ok, ADVISORY logged, excursion NOT in commit, summary IS in
      commit, dropped path remains dirty on disk)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: WORK (h) is at `orchestrate-cycle-postflight.sh:1445-1481` and WORK (i) at
`:1706-1769`, with `modified_files_json` (`:1447`) and `excursions_json` (`:1462`, `:1475`) both
set unconditionally at top level with no function boundary before WORK (i) — all re-derived at
plan-authoring time 2026-10-08 by direct read, not carried. Confirm at implementation time by
`grep -n 'excursions_json\|modified_files_json\|WORK (i)'` and by checking that neither site sits
inside `is_live` or a `research_gate_failed` branch (WORK (h) does not; WORK (i) does, which is
why the filter is sited in WORK (i)).

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - WORK (i) staging loop:
  iterate `modified_files_json`, skip `excursions_json` members with a per-path warning, add the
  dropped counter

**Verification**:

- Phase 1's four assertions all PASS.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0
  (no other case regressed).
- `grep -c "jq -r '.modified_files\[\]" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
  returns 0 — the second independent read of the field is gone, which is work item (1)'s literal
  acceptance condition.
- Full gate set for this tier: `bash .claude/scripts/verify-deploy.sh` (source-store path
  `agent-system/extensions/core/scripts/verify-deploy.sh`) run and its result recorded; any
  pre-existing failure must be shown to pre-date this change by running it against the unmodified
  baseline first.

---

### Phase 3: Remaining regression coverage [NOT STARTED]

**Goal**: Prove the three structural claims (fail-open, `specs/` carve-out, zero-`modified_files`)
rather than asserting them, and cover the one genuinely new edge the filter introduces.

**Tasks**:

- [ ] Add a LIVE (not `--dry-run`) fail-open fixture: a candidate with `"file_scope": []`, a real
      on-disk source file outside any `specs/` path listed in `modified_files`, asserting the
      path IS present in `git show --name-only --format= HEAD`. The existing `708_candidate`
      block is `--dry-run` and commits nothing, so it cannot carry this case — use a fresh
      candidate number.
- [ ] Add a `specs/` carve-out fixture: a candidate whose declared `file_scope` names only a
      source path (so `TASK_DIR/`, `TODO.md` and `state.json` would all be "excursions" if they
      were ever tested), asserting the task-directory and state paths ARE in the commit. This
      documents the structural invariant that the four carve-out appends sit outside the filtered
      loop.
- [ ] Add the all-entries-dropped edge fixture: every `modified_files` entry is an excursion, so
      `stage_paths` reduces to the four `specs/` entries. Assert exit 0, `verdict=ok`, a commit
      WAS created (`HEAD` advanced), and no V3/V6 refusal (not exit 2, not exit 4) — the one case
      this change newly makes reachable.
- [ ] Confirm, do not duplicate, the zero-`modified_files` case: locate the existing
      "no modified_files reported" coverage and assert its sanctioned warning wording is
      unchanged; add a case only if none exists.
- [ ] Use fixture numbers not already present in the file, referred to as "candidate #N", never
      "task N", per `rules/no-task-references-in-deliverables.md`.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: candidate numbers 718-719 and 712-714 appear unused in
`test-orchestrate-cycle-postflight.sh` (the used set re-derived at plan-authoring time by
`grep -oE '[0-9]{3}_candidate'` plus a check for variable-suffixed fixtures `_710`/`_711`, which
ARE used). Confirm with a fresh grep for both the `{N}_candidate` directory form and the `_{N}`
variable-suffix form before claiming a number is free.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - fail-open,
  `specs/` carve-out, all-dropped edge, and zero-`modified_files` confirmation cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0
  with every new case reported `[PASS]`.
- The fail-open case is confirmed genuinely load-bearing by temporarily asserting its inverse
  (expect FAIL), then restoring — a case that passes for the wrong reason proves nothing.

---

### Phase 4: Record the ruling in the script header [NOT STARTED]

**Goal**: The script's own header carries the ruling, its reason, the promotion-criterion
distinction, the declined work item, the phase-commit non-coverage pointer, and the ordering
dependency — so a future reader never has to reconstruct any of it from the code.

**Tasks**:

- [ ] Re-read the header's work-item list (`orchestrate-cycle-postflight.sh`, items (h) and (i))
      immediately before editing.
- [ ] Amend item (h)'s "detection only, never a gate" language: the advisory is now also the
      input to item (i)'s staging filter. Do not delete 284's two existing RULING blocks — add to
      them.
- [ ] Expand item (i) with the RULING: drop-and-warn, never refuse, with the reason from
      Decision 1 (no change to `git-commit-scoped.sh`'s exit-code contract; matches
      `git-staging-scope.md`'s "Under-stage, never over-stage" fail-safe direction; matches the
      sibling layer's independently-reached ruling on the same predicate).
- [ ] Record the Decision 2 distinction explicitly: drop-and-warn is a third posture, NOT the
      blocking promotion 284's two-part criterion gates, and 284's absolute-path counter-example
      is handled fail-safe by dropping rather than by being corrected.
- [ ] Record work item 3's DECLINE with its reason: `scripts/orchestrator-postflight.sh` Stage 9
      assembles `stage_paths` the same way and has no excursion computation, but is confirmed
      orphaned by `skill-base.sh:991`, `skill-base.sh:1185`,
      `context/reference/state-management-schema.md:288` and zero repo-wide invocation sites — a
      gate in dead code is not worth the edit. Record it as declined, not omitted.
- [ ] Record the phase-commit non-coverage (work item 7): this filter runs at postflight, so it
      structurally cannot reach an in-dispatch phase commit, which has no postflight in scope.
      Name the owning surface: `agent-system/extensions/core/agents/general-implementation-agent.md`'s
      `#### Phase-Commit Containment Self-Check`. Re-grep for that exact heading first — a
      concurrent sibling is live on that file this cycle; if it has moved, cite the file plus the
      nearest surviving durable heading. Never edit that file.
- [ ] Record the ordering dependency: item (i)'s filter reads item (h)'s `excursions_json`, so
      (h) must stay before (i) and neither may be wrapped in a function without explicit
      threading (`declare -g` or a parameter).
- [ ] Use no task numbers anywhere in the header (this file is outside `specs/**`); cite
      filenames and headings only.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the header work-item list spans roughly `:30-95` with item (h) at `:50` and
item (i) at `:77`, and the `#### Phase-Commit Containment Self-Check` heading exists at
`general-implementation-agent.md:338` — both re-derived at plan-authoring time 2026-10-08.
Confirm both by grep at implementation time; the second is on a file a concurrent sibling
declares in its own `file_scope`, so it is the likelier of the two to have moved.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - header items (h) and
  (i): ruling, reason, promotion-criterion distinction, declined work item 3, phase-commit
  non-coverage pointer, ordering dependency

**Verification**:

- Diff read-through confirms every changed hunk lies inside the `#`-comment header block (the
  `prose` tier's own criterion) — no executable line touched by this phase.
- `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
  task-number occurrence in the edited file.
- The cited heading resolves: `grep -n '#### Phase-Commit Containment Self-Check'
  agent-system/extensions/core/agents/general-implementation-agent.md` returns a hit.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` still
  exits 0 (a comment-only edit must not move it; several cases grep the script's own anchor
  comments, so this is not a vacuous check).

---

### Phase 5: Record the new behaviour in `git-staging-scope.md` [NOT STARTED]

**Goal**: The standard records what the staging layer now does, so a reader is not left to open
the script for it — with the empirical basis stated accurately and the non-claim explicit.

**Tasks**:

- [ ] Re-read `context/standards/git-staging-scope.md`'s "Fail-Safe Direction" section.
- [ ] Add a new subsection adjacent to "Fail-Safe Direction" (the new behaviour is a refinement
      of exactly that direction), NOT inside the existing V2/V3/V5/V6/V7 gate table — those
      gates all live inside `git-commit-scoped.sh`, whereas this filter is sited one layer above,
      in the caller. State that relationship explicitly so the placement is self-explaining.
- [ ] State the behaviour: at per-cycle postflight, a self-reported `modified_files` entry
      outside the dispatching task's declared `file_scope` (the Containment predicate, own task
      directory implicitly in scope) is dropped from the staged set with a loud warning and left
      uncommitted on disk; the rest of the commit proceeds; an absent or empty `file_scope` fails
      OPEN and drops nothing; the four `specs/` carve-out paths are never tested.
- [ ] Record the empirical basis: the dated 2026-10-04 observation in the Verification repository
      — ten generated Typst files in one commit, of which the task's declared `file_scope` named
      exactly one, so scoping held for every declared path and failed only for undeclared ones:
      the signature of an unvalidated staging list, not a mis-declared scope.
- [ ] State that observation's provenance accurately and prominently: that commit was a
      mid-dispatch PHASE commit, NOT produced by `orchestrate-cycle-postflight.sh` (its file list
      carries no `state.json`, no `TODO.md` and no task-directory entry other than the plan file,
      whereas the postflight commit unconditionally stages all three). It is the evidence that the
      predicate is worth enforcing, not a case this filter catches. Say, in those terms, that no
      claim is made that this change would have prevented it.
- [ ] Add the forward pointer for the surface this layer cannot reach:
      `agents/general-implementation-agent.md`'s `#### Phase-Commit Containment Self-Check`.
- [ ] No task numbers (this file is outside `specs/**`).

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: `git-staging-scope.md` is 564 lines with "Fail-Safe Direction" at `:218` and
"Exit-Code Contract and Safety Gates" at `:428` (re-derived at plan-authoring time 2026-10-08 by
`grep -n '^#'`). Confirm by grep before inserting; insert by section heading, never by line
number.

**Files to modify**:

- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new subsection adjacent
  to "Fail-Safe Direction" recording the staging-layer Containment filter, its empirical basis,
  the phase-commit provenance qualifier and non-claim, and the forward pointer

**Verification**:

- Diff read-through: the edit is confined to prose in one new subsection; no existing sanctioned
  wording (notably the `no modified_files reported` warning text) altered.
- `grep -i "would have prevented\|would have caught" ` over the file returns only the explicit
  NON-claim sentence, never an affirmative one.
- `bash .claude/scripts/check-task-references.sh` reports no new task-number occurrence.
- The document's own "Related Documentation" section still resolves (no dangling new reference).

---

### Phase 6: Final gates and artifact audit [NOT STARTED]

**Goal**: Every acceptance condition is demonstrated, not assumed, and the one prohibited claim
is confirmed absent from every artifact this task produced.

**Tasks**:

- [ ] Run `shellcheck -x` on the edited script and require **exit status 0**, which is the
      acceptance condition; a baseline run against the unmodified file
      (`git show HEAD:<path>` into a temp file) is taken only to attribute any pre-existing
      finding, never as a substitute for the exit check. There is no wrapper entry point for
      shellcheck in this repository (verified: `scripts/lint/` holds twelve `lint-*.sh` scripts,
      none of them a shellcheck runner; the ACCEPTANCE line and
      `context/standards/shell-strict-mode.md` name the tool directly), so the bare invocation IS
      the sanctioned one here. If the binary is unresolvable in this environment (a broken Nix
      store path was observed at research time), record that explicitly as an unmet acceptance
      item — do not report a clean run that did not happen.
- [ ] Confirm the script is strict-mode conformant per `context/standards/shell-strict-mode.md`
      (the new code must not rely on an unset-variable fallback for `excursions_json`).
- [ ] Run the full suite: `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      → exit 0.
- [ ] Run the three sanctioned lints that govern this exact surface, each checked by exit status:
      `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh`,
      `bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh`
      (the new fixture adds a targeted `git add` — confirm it is not read as a directory
      pathspec), and
      `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`.
- [ ] Run the nearest sibling suites to catch collateral damage in the shared commit path:
      `test-lint-scoped-commit-boundary.sh`, `test-lint-postflight-boundary.sh` and
      `test-guard-destructive-git.sh` → each exit 0.
- [ ] Run `bash .claude/scripts/verify-deploy.sh` (source-store path
      `agent-system/extensions/core/scripts/verify-deploy.sh`) and record the result; any failure
      must be shown pre-existing against the baseline or fixed.
- [ ] Audit every artifact this task produced (this plan, the report, the summary, the script
      header, `git-staging-scope.md`) for any claim that this gate would have prevented the
      observed 2026-10-04 commit: `grep -rin "would have prevented\|would have caught\|prevented
      the observed"` across them. Only the explicit non-claims may match.
- [ ] Confirm no `.claude/**` file was hand-edited: `git status --short -- .claude/` shows no
      edit attributable to this task (a deploy-produced change is a separate, declared step and
      not part of this task's `file_scope`).
- [ ] Walk the seven work items and the ACCEPTANCE line item by item in the summary, each with
      the command or diff that demonstrates it.

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- none planned (verification-only phase; any fix it surfaces is committed against the phase that
  owns the file)

**Verification**:

- Full gate set for this tier: `bash .claude/scripts/verify-deploy.sh` (source-store path
  `agent-system/extensions/core/scripts/verify-deploy.sh`) exits 0, or every failure is
  demonstrated pre-existing against the baseline; the postflight suite exits 0; all three sibling
  suites exit 0; all three lints exit 0; and `shellcheck -x` exits 0 or its unavailability is
  recorded as an unmet item.
- The prohibited-claim grep returns only non-claims.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      exits 0 after Phase 2, with the modified `707_candidate` block's new commit-contents
      assertion passing — and demonstrated RED against the unmodified script in Phase 1.
- [ ] Fail-open: a candidate with empty `file_scope` commits every reported `modified_files`
      entry, unfiltered (live fixture, not `--dry-run`).
- [ ] `specs/` carve-out: `TASK_DIR/`, `TODO.md`, `state.json` and the plan path are in the
      commit even when the declared `file_scope` names none of them.
- [ ] Zero `modified_files`: the existing warning fires with its sanctioned wording, unchanged,
      and nothing from source is committed.
- [ ] All-entries-dropped edge: exit 0, `verdict=ok`, a commit is still created from the `specs/`
      paths, and no V3 (exit 2) or V6 (exit 4) refusal.
- [ ] `grep -c "jq -r '.modified_files\[\]"` on the script returns 0 — the second independent read
      is gone.
- [ ] `shellcheck -x` exits 0 on the edited script per
      `context/standards/shell-strict-mode.md`, or its unavailability explicitly recorded.
- [ ] `bash .claude/scripts/verify-deploy.sh` result recorded.
- [ ] `lint-scoped-commit-boundary.sh`, `lint-directory-pathspec-boundary.sh` and
      `lint-postflight-boundary.sh` each exit 0.
- [ ] `test-lint-scoped-commit-boundary.sh`, `test-lint-postflight-boundary.sh` and
      `test-guard-destructive-git.sh` each exit 0.
- [ ] No task-number reference introduced outside `specs/**`.
- [ ] No artifact claims this gate would have prevented the observed 2026-10-04 commit.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — WORK (i) staging
  filter consulting WORK (h)'s verdict; header ruling, declined work item, phase-commit
  non-coverage pointer, ordering-dependency note
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — modified
  excursion fixture plus fail-open, carve-out, all-dropped and zero-`modified_files` cases
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new subsection adjacent
  to "Fail-Safe Direction"
- `specs/335_gate_modified_files_excursion_at_staging/summaries/01_*-summary.md` — execution
  summary with the per-work-item and per-acceptance-condition walk-through
- FOLLOW-UP recorded, not performed: if a future ruling needs a distinguishable
  `git-commit-scoped.sh` exit code for "commit succeeded but dropped a `file_scope` excursion",
  that belongs to the out-of-repository-pathspec task, which owns that exit-code contract.

## Rollback/Contingency

All three target files are tracked and every phase commits per sub-step, so the ordinary recovery
is fix-forward (correct the source) or a targeted `git revert` of this task's own commits — never
a tree-discarding operation. If a rollback that would discard uncommitted work becomes genuinely
necessary, follow `context/contracts/recovery.md`'s rollback rung for the exact invocation shape
(including its out-of-scope override flag) rather than improvising; for an ordinary defensive
checkpoint before the Phase 2 edit, use `bash .claude/scripts/git-snapshot.sh 335 --no-revert`,
which is durable without reverting the working tree.

Partial-landing contingency: Phases 1-3 (test suite) and Phases 4-5 (records) are independently
revertible. The one ordering constraint that must not be left half-applied is Phase 2 without
Phase 4 — a staging filter whose ruling is not recorded in the header is exactly the
undocumented-behaviour condition this task exists to end. If the task must stop after Phase 2,
Phase 4 is the next thing to land, ahead of Phase 3's additional coverage.
