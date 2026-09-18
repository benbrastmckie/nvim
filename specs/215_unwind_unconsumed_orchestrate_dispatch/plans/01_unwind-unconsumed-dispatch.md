# Implementation Plan: Task #215

- **Task**: 215 - Unwind an unconsumed /orchestrate dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: 213 (per-run cycle-budget change; confirmed already live by research)
- **Research Inputs**: specs/215_unwind_unconsumed_orchestrate_dispatch/reports/01_unwind-unconsumed-dispatch.md
- **Artifacts**: plans/01_unwind-unconsumed-dispatch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a by-hand recovery script, `orchestrate-unwind-dispatch.sh`, that reverses every mutation
`orchestrate-cycle-plan.sh`'s live Move 1 makes for one task when Move 2 (the Agent call) never
ran: the preflight `status`/`last_updated`/`session_id` write, the task lock, the
`.dispatch/{seq}.md` file, `dispatch_seq_counter` and `pending_dispatch` in the durable
`.orchestrator-loop-guard`, and the run's multi-state file. The one missing input — the
pre-dispatch state — is captured by a small change to `orchestrate-cycle-plan.sh` that widens the
`pending_dispatch` record (non-replay branch only). Everything else reuses existing verbs
(`state-write.sh --regen-todo`, `task-lock.sh release`, `orchestrate-loop-guard-init.sh
--flush-seq/--clear-pending`, `git-commit-scoped.sh`). All edits land in the source store
`agent-system/extensions/core/**`, never `.claude/**`; a redeploy propagates them.

### Research Integration

- The amendment is already live: `cycle_count` in the guard file is inert; the durable fields to
  restore are `pending_dispatch` and `dispatch_seq_counter`. "Roll back the cycle count" is
  dropped from the durable file (only the multi-state file's `cycle_counts[t]` is touched, as
  best-effort).
- No new verb is needed in `orchestrate-loop-guard-init.sh` or `task-lock.sh`; `--record-pending`
  stores its JSON verbatim, so the wider record needs no change there.
- `update-task-status.sh` cannot write an arbitrary historical status; `state-write.sh` with a jq
  filter plus `--regen-todo` is the restore writer.
- Prior-image capture must sit immediately before `skill_preflight_update` (line ~1863) and be
  persisted only in the non-replay `else` branch (line ~1963); the replay branch must never
  overwrite the original record.
- Bare vs. suffixed session_id: the lock holder is the BARE session; `state.json.session_id` is
  suffixed for research/plan. The lock release must never key off the state.json value.
- `git-safety.md` has no `guard-destructive-git.sh` explanation today; the real one lives in
  `git-staging-scope.md`.
- Only `specs/state.json` and `specs/TODO.md` are tracked among the touched paths; everything else
  is gitignored, so a two-path scoped commit satisfies the porcelain-clean acceptance check.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Not consulted (no roadmap_path in dispatch).

## Decisions

1. **Where the pre-image lives**: inside `pending_dispatch`, as new optional fields
   `prior_status`, `prior_last_updated`, `prior_session_id`, and `prior_dispatch_seq_counter`
   (the durable guard value read via `orchestrate-loop-guard-init.sh --seed` before this cycle's
   `--flush-seq`). Rationale: `pending_dispatch` is already the single record that postflight
   clears as its first act, so the pre-image dies exactly when the dispatch is consumed — no
   second ledger to keep in sync. `prior_dispatch_seq_counter` is recorded instead of assuming
   `seq - 1`, so the rollback is exact even if the counter was seeded higher; `seq - 1` is only a
   fallback for a record that lacks the field.
2. **Legacy records** (a `pending_dispatch` written before this change, without the `prior_*`
   status fields): refuse with exit 2 and a message naming the missing fields. No override flags
   in this task (keeps the surface small; hand recovery remains available and is documented).
3. **Refusal gate** (all must hold, else exit nonzero, touching nothing):
   `pending_dispatch` present; its `dispatch_file` exists on disk; the task's
   `.return-meta.json` and `.orchestrator-handoff.json` are absent or older than the dispatch
   file (an agent's Stage 0 writes one of them, so a newer one means an agent started); the
   state.json entry's current `session_id` is one this dispatch could have written (bare `SID` or
   `SID_<task>`); and the lock is absent, stale, or held by `SID`. A fresh lock held by another
   session means another run is live: refuse.
4. **Lock release identity**: release with the bare `--session SID` (the task's own wording:
   "only if this session holds it"), after `task-lock.sh check` confirms the holder equals `SID`.
   If the holder differs (only reachable when the lock is stale), leave the lock and WARN; never
   force-remove. This follows the research's session-subtlety finding: the state.json value is
   never used for the release.
5. **Multi-state file**: `--mt-state FILE` names it explicitly; otherwise the script looks for
   `specs/.orchestrator-multi-state-${SID}.json`. If found and it carries this task, it deletes
   `.dispatch_seq[t]`, decrements `.cycle_counts[t]` (floor 0), and restores
   `.dispatch_seq_counter`-style per-task fields to the prior value when present. If not found,
   this step is a logged no-op.
6. **Commit**: opt-in `--commit` flag; calls `git-commit-scoped.sh` with exactly
   `specs/state.json specs/TODO.md` and message `task {N}: unwind unconsumed {phase} dispatch
   (seq {S})`. Never uses destructive git.
7. **WORK (c), auto vs. by hand**: **by hand only**. Justification to record in the docs: (i)
   the existing UNCONSUMED DISPATCH REPLAY mechanism already gives the automatic answer to "a
   prepared dispatch was never consumed" (resume it without re-charging), and an auto-unwind
   would act on the identical signal in the opposite direction; (ii) no liveness signal can tell
   "the prior session is gone and the dispatch is unwanted" from "the prior session is about to
   reach Move 2" beyond lock staleness, which already backs the resume interpretation; (iii)
   discarding work is the destructive direction and should stay an explicit operator choice. The
   SKILL.md pointer tells the operator (and an orchestrating session that deliberately abandons a
   prepared row at the user's request) to run the script by hand.
8. **Doc placement for git-safety.md**: add a short "Recovering an Unconsumed Dispatch" subsection
   that first states in two sentences what `guard-destructive-git.sh` blocks (pointing to
   `git-staging-scope.md` for the full narrative), then names the unwind script as the sanctioned
   non-git recovery path. This makes "next to the guard-destructive-git.sh explanation" literally
   true without duplicating the full guard narrative.

## Goals & Non-Goals

**Goals**:
- `pending_dispatch` records the pre-dispatch status triple and `dispatch_seq_counter`.
- New `scripts/orchestrate-unwind-dispatch.sh <task_number> --session SID [--dry-run]
  [--commit] [--mt-state FILE]` that restores all Move 1 mutations exactly, or refuses.
- Fixture test proving exact restoration and the post-consumption refusal.
- Documentation in the state-machine doc, git-safety.md, SKILL.md Move 1, plus cross-references
  in `orchestrator-runtime-files.md` and `utility-scripts-inventory.md`.
- shellcheck clean; redeploy and confirm.

**Non-Goals**:
- Any exemption in `guard-destructive-git.sh`.
- Automatic invocation from the orchestrate loop.
- Recovering a dispatch whose file was already deleted by hand, or legacy records lacking the
  pre-image (documented as hand-recovery cases).
- Editing `.claude/**` directly.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pre-image captured on a replay cycle records the in-flight status | H | M | Persist only in the non-replay `else` branch; test that a replay cycle leaves the original `prior_status` untouched |
| Unwinding a dispatch an agent already started | H | L | Refusal gate checks return-meta/handoff mtime vs. dispatch file, and a fresh foreign lock |
| Tool unusable after hand deletion of the dispatch file | M | M | Docs say "run this before any manual cleanup"; refusal message says so too |
| state-write.sh arg conventions differ from research's sketch | M | L | Read `state-write.sh --help`/header before writing the call; fixture asserts exact field equality |
| Multi-state file field names differ from assumptions | L | M | Scope Hypothesis in Phase 2; best-effort step, never fatal |
| shellcheck not on PATH | L | H | Use `nix shell nixpkgs#shellcheck -c shellcheck ...` (or the repo's existing invocation) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Capture the pre-dispatch image in pending_dispatch [COMPLETED]

**Goal**: `orchestrate-cycle-plan.sh` records `prior_status`, `prior_last_updated`,
`prior_session_id`, `prior_dispatch_seq_counter` in `pending_dispatch` on every non-replay live
dispatch.

**Tasks**:
- [x] Immediately before `skill_preflight_update` (section (j), ~line 1863), read the task's
  current entry (`lookup_project`/`task_lookup_entry`, whichever the file already uses) into
  `_pd_prior_status`, `_pd_prior_last_updated`, `_pd_prior_session_id` (empty string when a field
  is absent). *(completed)*
- [x] Before the `--flush-seq` call in the `else` branch (~line 1961), read the durable counter
  via `orchestrate-loop-guard-init.sh --seed "$task_dir_abs"` into `_pd_prior_seq_counter`
  (confirm the `--seed` output shape first; default 0 when absent). If `--flush-seq` runs earlier
  than this point for the same cycle, move the read to before the earliest durable write.
  *(completed: captured in the existing top-of-script seed loop into a new `pd_prior_dsc[$t]`
  array, which is the earliest durable read this run -- not a second `--seed` call at the
  `--flush-seq` site, since an earlier aux-dispatch-emission flush for the same task could
  otherwise corrupt a re-read at that later point)*
- [x] Extend the `_pd_record_json` jq construction with the four `prior_*` fields. Leave the
  replay branch untouched. *(completed)*
- [x] Update the header comment block and `context/standards/orchestrator-runtime-files.md`'s
  `pending_dispatch` schema description with the new fields. *(completed)*
- [x] Add a test group to `scripts/tests/test-orchestrate-cycle-plan.sh` (follow Group 19's
  idiom): a live dispatch records the four fields with the pre-dispatch values; a second
  same-phase invocation (replay) leaves them unchanged. *(completed: Group 24, 2 cases, appended
  after Group 23)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: exactly one record construction site (`_pd_record_json`) and one durable
`--flush-seq` call precede the record in a live cycle; confirm with
`grep -n "flush-seq\|record-pending" scripts/orchestrate-cycle-plan.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - capture and persist pre-image
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new test group
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - schema note

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes,
  including the new group.

---

### Phase 2: Write orchestrate-unwind-dispatch.sh [COMPLETED]

**Goal**: a script that performs the unwind described in Decisions 2-6, with `--dry-run`.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh` with strict
  mode per `context/standards/shell-strict-mode.md`, a usage header, and args
  `<task_number> --session SID [--dry-run] [--commit] [--mt-state FILE]`. *(completed)*
- [x] Resolve the task dir via the existing lookup helpers (sourced lib, not hand-built paths).
  *(completed: `task_lookup_entry`/`task_lookup_dir` from `lib/task-lookup-lib.sh`)*
- [x] Read `pending_dispatch` with `orchestrate-loop-guard-init.sh --seed`; apply the refusal
  gate from Decision 3 and the legacy-record refusal from Decision 2. Each refusal prints the
  reason and, where relevant, "run this before any manual cleanup". *(completed)*
- [x] `--dry-run`: print each action it would take and exit 0 with no writes. *(completed;
  manually verified against a hand-built fixture -- no state.json/guard-file/dispatch-file
  mutation occurred)*
- [x] Unwind, in this order: (1) restore the state.json entry's `status`/`last_updated`/
  `session_id` via `state-write.sh` with `--regen-todo` (check its header for exact flags);
  (2) `--flush-seq` to `prior_dispatch_seq_counter` (fallback `seq - 1`); (3) `--clear-pending`;
  (4) delete the dispatch file; (5) patch the multi-state file per Decision 5; (6) release the
  lock per Decision 4; (7) with `--commit`, call `git-commit-scoped.sh` on the two tracked paths.
  *(completed; manually verified end-to-end including --commit against a real git fixture repo)*
- [x] Print a one-line summary of what was restored; exit codes: 0 success, 1 usage, 2 refused.
  *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: the multi-state file keys the task under `.dispatch_seq[t]` and
`.cycle_counts[t]` only; confirm against the `mt_state_file` field list in the header of
`orchestrate-cycle-plan.sh` and the "Loop-Owned Runtime State" section of the state-machine doc.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh` - new

**Verification**:
- `bash -n` passes; `--help` prints usage; `--dry-run` against a hand-built fixture writes
  nothing (checked with checksums).

---

### Phase 3: Fixture test [COMPLETED]

**Goal**: `scripts/tests/test-orchestrate-unwind-dispatch.sh` proves the acceptance criteria.

**Tasks**:
- [x] Build a temp git repo fixture (reuse setup idioms from `test-orchestrate-cycle-plan.sh`
  and `test-git-commit-scoped.sh`) with a RESEARCHED task, commit it clean, and snapshot the
  state.json entry and the guard file's `pending_dispatch`/`dispatch_seq_counter`. *(completed:
  `build_repo`/`prepare_dispatch` helpers; runs the REAL `orchestrate-cycle-plan.sh` end-to-end
  rather than hand-building `pending_dispatch`, so Phase 1's pre-image capture is exercised
  genuinely, not just asserted against a fixture)*
- [x] Case 1 (happy path): run `orchestrate-cycle-plan.sh` live for a plan dispatch, then the
  unwind script with `--commit`. Assert: state entry `status`/`last_updated`/`session_id` equal
  the snapshot exactly; TODO.md regenerated (matches `generate-todo.sh` output for the restored
  state); lock gone; dispatch file gone; `pending_dispatch` and `dispatch_seq_counter` equal the
  snapshot; `git status --porcelain -- specs/` empty. *(completed, all assertions pass)*
- [x] Case 2 (consumed): prepare a dispatch, run `--clear-pending` (what postflight does first),
  run the unwind; assert exit 2 and no file changed. *(completed)*
- [x] Case 3 (agent started): prepare a dispatch, touch a newer `.return-meta.json`; assert
  refusal. *(completed)*
- [x] Case 4 (`--dry-run`): assert no writes. *(completed; checksummed state.json/guard
  file/dispatch file plus lock presence)*
- [x] Case 5 (foreign fresh lock): assert refusal and the lock untouched. *(completed)*
- [x] Confirm `run-all.sh` discovers the new file by its name pattern. *(completed: matches the
  `scripts/tests/test-*.sh` glob run-all.sh already scans; no separate registration needed)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` - new

**Verification**:
- The new test passes; `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports no
  new failures.

---

### Phase 4: Documentation and the WORK (c) decision [COMPLETED]

**Goal**: document the script as the sanctioned recovery path and record the by-hand decision.

**Tasks**:
- [x] `docs/architecture/orchestrate-state-machine.md`: new subsection "Unwinding an Unconsumed
  Dispatch" after the MAX_CYCLES / loop-guard block: what Move 1 mutates, the script's refusal
  gate, "run it before any manual cleanup", by-hand-only rationale (Decision 7), and how it
  differs from `reconcile-task-status.sh`'s stale-status demotion. *(completed)*
- [x] `context/standards/git-safety.md`: subsection per Decision 8. *(completed: "Recovering an
  Unconsumed Dispatch" subsection placed right after "When to Use Git Safety")*
- [x] `skills/skill-orchestrate/SKILL.md` Move 1: one or two sentences after the `stop_json`
  handling pointing to the script for a prepared row that will not be issued. *(completed)*
- [x] `docs/reference/utility-scripts-inventory.md`: add an entry. *(completed)*
- [x] `context/standards/orchestrator-runtime-files.md`: cross-reference from the
  `pending_dispatch` subsection. *(completed in Phase 1's edit, when the `prior_*` fields were
  documented there)*
- [x] No task numbers in any of these files; run the repo's task-reference lint on them.
  *(completed: `bash .claude/scripts/check-task-references.sh` exits 0, no findings in any edited
  file)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/context/standards/git-safety.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`

**Verification**:
- `check-task-references.sh` (or equivalent lint) clean on the edited files; each doc names the
  script path and the by-hand rule.

---

### Phase 5: shellcheck, full suite, redeploy [NOT STARTED]

**Goal**: final gates.

**Tasks**:
- [ ] shellcheck the new script, the new test, and `orchestrate-cycle-plan.sh` (use
  `nix shell nixpkgs#shellcheck -c shellcheck` if not on PATH); fix findings.
- [ ] Run `scripts/tests/run-all.sh`; compare against the pre-change baseline so unrelated
  failures are not attributed to this task.
- [ ] Redeploy with `deploy-headless.sh` and run `verify-deploy.sh`; confirm
  `.claude/scripts/orchestrate-unwind-dispatch.sh` exists and matches the source store.
- [ ] Commit per-substep with scoped staging (explicit file lists, never directories).

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Files to modify**:
- none beyond fixes surfaced by the gates

**Verification**:
- shellcheck exits 0; test suite green for touched suites; deploy verification passes.

## Testing & Validation

- [ ] Pre-image fields recorded on live dispatch, preserved across replay (Phase 1 test group)
- [ ] Happy-path unwind restores state entry, TODO.md, lock, dispatch file, `pending_dispatch`,
  `dispatch_seq_counter` exactly, and leaves `git status --porcelain -- specs/` empty
- [ ] Refusal after postflight consumption, after an agent start, and under a foreign fresh lock
- [ ] `--dry-run` writes nothing
- [ ] shellcheck clean; redeploy verified

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh`
- Edits to `orchestrate-cycle-plan.sh`, its test, and five documentation files
- `specs/215_unwind_unconsumed_orchestrate_dispatch/summaries/01_unwind-unconsumed-dispatch-summary.md`

## Rollback/Contingency

Every change is additive: the new `prior_*` fields are optional and ignored by existing readers,
and the new script is invoked only by hand. Revert the task's commits with `git revert` to back
out. If Phase 1's capture proves unreliable, the script's legacy-record refusal keeps it inert
rather than wrong.
