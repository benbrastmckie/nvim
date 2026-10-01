# Research Report: Task #287

**Task**: 287 - No co-schedule build-heavy implement (Mode 2 admission rule)
**Started**: 2026-09-30
**Completed**: 2026-09-30
**Effort**: standard
**Dependencies**: specs/decisions/worktree-isolation-removal-verdict.md (Mode 2 Ruling section — the spec)
**Sources/Inputs**: Codebase read of `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`, `orchestrate-batch-admit.sh`, `tests/test-orchestrate-cycle-plan.sh`, `tests/known-failures.txt`, `context/standards/shell-strict-mode.md`, the decision record, and task #286's plan (prior-phase precedent)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The edit target is confirmed: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (the source store; `.claude/scripts/orchestrate-cycle-plan.sh` is its disposable deploy mirror and must not be hand-edited). `WORKTREE_ISOLATED_TASK_TYPES` is referenced nowhere else in any `.sh`/`.md` outside this one script and this task's own `specs/` artifacts, so renaming it is a single-file, zero-fan-out change.
- The correct insertion point is the existing per-task bucketing loop at `orchestrate-cycle-plan.sh:1786-1839` (the loop that builds `dispatch_candidates`/`out_deferred_rows`/`out_blocked_rows` from `eligible_tasks`). This loop already runs identically for both `--dry-run` and the live path (the live/dry-run fork happens later, downstream, at the lock-probe/H1/dry-run-row-builder stage), so placing the rule here gets byte-for-byte dry-run/live parity **for free**, with no second row builder to keep in sync.
- `task_types[$t]` (populated at lines 1152-1176, well before the bucketing loop) and `effective_group[$t]` (aliased to `g` at the top of the loop) are both already in scope at the insertion point — no new state needs to be threaded in.
- `task_selected_for_worktree_isolation(phase, ttype)` (lines 1985-1993) already encodes exactly the predicate this rule needs ("phase == implement AND task_type in the family array"). Reusing it as the sole reader of the renamed array satisfies the dispatch's "single array, single reader" requirement without writing a second iterator.
- The output schema for a deferred row is `{task, reason}` (free-text `reason` string — see the script's own header "Output" contract and every existing locally-produced deferred row, e.g. "locked by another session; deferring to a later cycle"). The richer `colliding_task_number`/`collision_scope`/`overlapping_path` fields the dispatch warns against reusing belong to `orchestrate-batch-admit.sh`'s `file_scope_collision` schema (a different script, out of scope) — the new rule does not need or produce that shape; it only needs its own distinguishable `reason` string.
- Recommended test home: append a new **Group 32** to `tests/test-orchestrate-cycle-plan.sh` (Group 31 is currently the last group, ending at line ~4501), following the file's established `write_state`/`reset_lock_dirs`/`run_sut`/`jqf`/`pass`/`fail` idiom.

## Context & Scope

Researched: where and how to implement the Mode 2 build-heavy co-scheduling admission rule inside `orchestrate-cycle-plan.sh`, per `specs/decisions/worktree-isolation-removal-verdict.md`'s "Mode 2 Ruling" section and the dispatch's own detailed specification. The dispatch is explicit that the spec itself ("never dispatch two build-heavy implement tasks in the same cycle", using the renamed `WORKTREE_ISOLATED_TASK_TYPES` array, implement-phase-scoped, own defer reason, no PATH shim) is not re-openable — this report focuses on *where in the existing code* each requirement lands, what already exists to reuse, and what the test suite needs, so the plan can go straight to file/line-level edits.

Out of scope (confirmed from the decision record's own "Scope Boundary Honored" section and task #286's plan, which already deliberately deferred all of this to the present task): the PATH-shim wrapper, the worktree-isolation *removal* itself (a separate, later task — `task_selected_for_worktree_isolation()` and its three existing call sites must keep working unchanged), the `MAX_TASKS` cap, and any `orchestrate-batch-admit.sh` edit.

## Findings

### Codebase Patterns

**1. The array and its sole current reader.**
```
agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1985
WORKTREE_ISOLATED_TASK_TYPES=("lean4" "cslib")
task_selected_for_worktree_isolation() {
  local phase="$1" ttype="$2" candidate
  [ "$phase" = "implement" ] || return 1
  for candidate in "${WORKTREE_ISOLATED_TASK_TYPES[@]}"; do
    [ "$ttype" = "$candidate" ] && return 0
  done
  return 1
}
```
Three call sites exist today, all of which must keep working unchanged (worktree isolation itself is not removed by this task):
- `build_contended_manifest()` (line 2205) — excludes an isolated task's `file_scope` from the contention manifest.
- The `--dry-run` row builder (line 2427) — sets `dry_isolation="worktree"` for the row's `isolation` field.
- The live row builder (line 2594) — the same, driving the actual `dispatch-worktree.sh provision` call.

Grep confirms `WORKTREE_ISOLATED_TASK_TYPES` has zero references anywhere else in `.sh`/`.md` files outside this one script and this task's own `specs/` artifacts (TODO.md, task #286's own report/plan/summary, and an archived task's handoff) — renaming it is self-contained.

**2. Where "build-heavy" co-scheduling needs to be decided: the shared bucketing loop.**
```
orchestrate-cycle-plan.sh:1784-1839 (abbreviated)
declare -a dispatch_candidates=()
for t in "${eligible_tasks[@]}"; do
  g="${effective_group[$t]}"
  case "$g" in
    needs_human) ... ; continue ;;
    forced_round_complete) ... ; continue ;;
    skip|terminal|exit_partial|"") continue ;;
  esac

  # Phase 5: forced implement with no plan artifact -> blocked
  if [ "$g" = "implement" ] && [ "${forced_this_cycle[$t]:-false}" = "true" ]; then
    ... blocked ...
  fi

  if [ "${admit_decision[$t]:-admit}" = "defer" ]; then
    out_deferred_rows+=("$(jq -n -c ... '{task:$t, reason:$r}')")
    continue
  fi
  dispatch_candidates+=("$t")
done
```
This loop runs for **every** cycle, in **both** `--dry-run` and live modes — the dry-run/live fork happens much later (at the lock-probe / H1 / per-mode row-builder stage, lines ~1842 onward and ~2417/~2583). `task_types[$t]` is already populated at lines 1152-1176 (before this loop), and `g` (the effective phase group) is already bound at the top of each iteration. This is the "same point in the same function" the dispatch's PLACEMENT section points at: the file_scope-collision defer (lines 1834-1837, fed by `orchestrate-batch-admit.sh`'s cross-task/cross-batch check) sits immediately before `dispatch_candidates+=("$t")`, and the new rule is the same shape of decision at the same point, just computed locally against the OTHER candidates already accepted into `dispatch_candidates` this cycle rather than against an external admission script's verdict.

Concretely, tracking "has a build-heavy implement candidate already been admitted this cycle" with one scalar (e.g. `build_heavy_implement_admitted=""`, holding the first such task number once set) and checking it immediately before `dispatch_candidates+=("$t")` reuses `task_selected_for_worktree_isolation "$g" "${task_types[$t]:-}"` as the single predicate for "is this an implement-phase, build-heavy candidate" — satisfying "keep it a single array with a single reader" literally: the renamed array still has exactly one function that iterates it, and the new call site calls that function rather than re-reading the array.

**3. The deferred-row output shape is `{task, reason}` — free text, no new JSON field.**
The script's own header ("Output" section, ~line 213) documents the contract once:
```
deferred: [{task, reason}], blocked: [{task, reason}]
```
Every locally-produced deferred row already uses a free-text `reason` string (no `defer_reason` enum, no `collision_scope`): e.g. `"locked by another session; deferring to a later cycle"` (line 1859), `"task not found in state.json; cannot resolve project directory"` (line 2453), `"dispatch-worktree.sh provision failed; deferring to a later cycle rather than falling through to a shared-tree dispatch"` (line 2605). The dispatch's warning not to "overload the file_scope collision reason, whose payload carries a colliding task number, status and overlapping path" refers to the **richer** schema `orchestrate-batch-admit.sh` emits for its own `file_scope_collision`/`self_modifying`/`session_active` verdicts (documented in that script's header, lines ~124-186, and relayed into `admit_reason[$rt]`/`defer_ledger` at `orchestrate-cycle-plan.sh:1748-1779`) — a *different* script and a *different*, already-structured defer-reason vocabulary that the dispatch does not authorize touching. The new rule is purely local to `orchestrate-cycle-plan.sh` and needs only a distinct, identifiable `reason` string (e.g. naming the colliding task number inline in the text, the same way other local reasons already embed detail as prose rather than as separate JSON fields — see the `MAX_INFRA_FAILURES`/`MAX_CYCLES` reason strings at lines 1575/1590, which interpolate counts into the text).

**4. Header-contract documentation precedent.**
The script's header already carries a dedicated paragraph for `task_selected_for_worktree_isolation()`'s semantics (around line 215: "`isolation` ... is selected by `task_selected_for_worktree_isolation()` — phase == 'implement' AND a lean4/cslib-family task_type — and is emitted identically in BOTH modes"), and separate numbered "Decision N" paragraphs for other behavioral rules (Decision 1: per-task cycle budget; Decision 2: aux_dispatch[]). The dispatch's "documented in the script's header contract to the same standard as the existing reasons" is best satisfied by one of:
(a) extending the existing isolation paragraph to also state the new rule (since both now read the same renamed array), or
(b) adding a new, short "Decision" paragraph for the Mode 2 admission rule, pointing at the decision record.
Either satisfies the standard; (a) keeps the single BUILD_HEAVY_TASK_TYPES explanation in one place since both consumers (worktree isolation and co-scheduling) now read the same array via the same function.

**5. `defer_ledger` is optional, not required.** `self_modifying`/`file_scope_collision`/`session_active` each push an entry into the persistent `defer_ledger` field (`orchestrate-cycle-plan.sh:1767-1776`), but a grep across the extension finds no consumer that reads `defer_ledger` contents for behavior — `skill-orchestrate/SKILL.md` only lists it as a carried-through `mt_state_file` field name. The dispatch's acceptance criteria name only the `deferred[]` row (output contract), not `defer_ledger`. Treat a `defer_ledger` entry for the new reason as optional symmetry, not a requirement — the planner can decide either way without affecting the four named test cases.

**6. Ordering/race nuance worth flagging to the planner (not a blocker).** The bucketing loop decides "first build-heavy implement candidate in `eligible_tasks` order wins" before the later lock-probe (`task-lock.sh check`, line ~1843) runs. If that first-admitted candidate is later deferred by the lock probe (held by another session), the second build-heavy candidate — already deferred by the new rule — does not get a second chance this cycle; the cycle dispatches zero build-heavy implement tasks instead of one. This mirrors the existing `file_scope_collision` admission decision's own relationship to the lock probe (also decided before, not re-validated after) and does not violate the "deferred, never failed" contract (the task simply waits for the next cycle), but is worth a one-line note in the plan so it isn't rediscovered as a surprise.

### External Resources

Not applicable — this is a pure in-repo scripting/bash task with no external API or library surface. No web research was needed or performed.

## Recommendations

1. **Rename** `WORKTREE_ISOLATED_TASK_TYPES` -> `BUILD_HEAVY_TASK_TYPES` in place at line 1985, updating its header comment (currently describing the worktree-isolation rationale) to state its now-dual meaning: driving both (a) the pre-existing, unremoved worktree-isolation predicate and (b) the new build-heavy co-scheduling admission rule. Leave `task_selected_for_worktree_isolation()`'s name and the three existing call sites (lines 2205, 2427, 2594) untouched — only the array identifier changes.
2. **Add the admission check** inside the existing bucketing loop (`orchestrate-cycle-plan.sh:1786-1839`), immediately before `dispatch_candidates+=("$t")` at line 1838 (i.e., after the existing `admit_decision` defer check), using a single scalar tracking the first build-heavy implement task admitted this cycle and calling `task_selected_for_worktree_isolation "$g" "${task_types[$t]:-}"` to test candidacy. On a second (or later) hit, push to `out_deferred_rows` with a distinct, grep-able `reason` string (never the literal `file_scope_collision`) naming the colliding in-cycle task number, and `continue` instead of adding to `dispatch_candidates`.
3. **Document** the rule in the header, either by extending the existing isolation paragraph or adding a short new "Decision" paragraph beside it, naming the decision record and the renamed array.
4. **Tests**: add **Group 32** to `tests/test-orchestrate-cycle-plan.sh` (current file ends after Group 31, ~line 4501), reusing the established fixture idiom (`write_state` with `active_projects[]`, `reset_lock_dirs`, `run_sut --session X [--dry-run] -- <tasks>`, `jqf` queries against `.dispatch`/`.deferred`). Cover the four dispatch-named cases:
   - (i) two build-heavy (`lean4`/`cslib`) `status: "implementing"` candidates in one invocation -> `.dispatch` has 1 entry, `.deferred` has 1 entry whose `reason` names the new rule (and ideally the colliding task number).
   - (ii) one build-heavy + one `general` implement candidate -> both dispatch (`.dispatch | length == 2`).
   - (iii) two build-heavy candidates where one is `status: "researched"` (plan phase) and the other `status: "implementing"` (implement phase) -> both dispatch (phase-scoping confirmed; the plan-phase one isn't gated at all since `task_selected_for_worktree_isolation` returns false for `phase != "implement"`).
   - (iv) the same two-build-heavy-implement fixture run once live and once `--dry-run` -> identical `.deferred[].reason` text (byte-for-byte), confirming the shared-loop placement delivers parity without a second code path.
   Note the Group 31 header's own documented discovery: `orchestrate-batch-admit.sh`'s pre-existing in-batch `file_scope_collision` check already defers one of two same-cycle candidates sharing an identical or directory-nested `file_scope`. Keep each build-heavy fixture's `file_scope` either empty or on clearly disjoint paths (as the dispatch's own Mode 2 framing specifies — "provably DISJOINT source footprints") so that pre-existing check never fires and the new rule is what's actually exercised; the two build-heavy test task directories should also stay off any `critical_paths` entry so `self_modifying` stays false and doesn't confound the fixture (follow Group 30's existing `lean4`/`cslib` fixtures, which already use empty `file_scope` safely).
5. **Shellcheck**: the new code is plain `[ ]`/`case`/scalar-variable bash consistent with the surrounding Class-A (`set -euo pipefail`) script; no subshell, no unguarded command whose nonzero exit needs tolerating, so no new shellcheck suppressions should be needed. Run `shellcheck` on the file after editing per `context/standards/shell-strict-mode.md`'s Class A expectations.
6. **Run the full suite** (`tests/run-all.sh` or at minimum `tests/test-orchestrate-cycle-plan.sh`) and diff against `tests/known-failures.txt` to confirm no new failures, per the dispatch's acceptance criteria.

## Decisions

- Confirmed edit target: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` only (source store). No other script or doc requires a parallel edit for the rename (verified via repo-wide grep).
- Confirmed insertion point: the shared bucketing loop at lines 1786-1839, which already executes identically for `--dry-run` and live, making the "byte-for-byte... matching how the deleted isolation decision was surfaced in both row builders" requirement automatically satisfied without writing two row builders.
- Confirmed output shape: a plain `{task, reason}` entry in `out_deferred_rows`/the final `deferred[]` array; no new JSON field, no touch to `orchestrate-batch-admit.sh`'s richer `file_scope_collision` schema.
- Confirmed reuse strategy for "single array, single reader": the new call site invokes the existing `task_selected_for_worktree_isolation()` predicate rather than iterating the renamed array a second time.
- `defer_ledger` entry for the new reason: left as an implementation-discretion item (optional), since no consumer reads it and the dispatch's acceptance criteria do not name it.

## Risks & Mitigations

- **Risk**: a future reader finds `task_selected_for_worktree_isolation()`'s name confusing once it also gates co-scheduling. **Mitigation**: the header comment update (Recommendation 3) states the dual purpose explicitly; a function rename is deliberately NOT recommended here because the function's existing worktree-isolation call sites and name remain accurate until the separate removal task deletes them — renaming now would be churn against a predicate the dispatch explicitly says must keep working unchanged.
- **Risk**: a test fixture accidentally also trips the pre-existing in-batch `file_scope_collision` check (Group 31's own documented discovery), making it look like the new rule works when the OLD check actually fired. **Mitigation**: Recommendation 4 states the disjoint/empty `file_scope` fixture requirement explicitly, mirroring Group 30's own safe pattern.
- **Risk**: ordering-dependent flakiness in which build-heavy candidate gets admitted vs. deferred. **Mitigation**: not a correctness risk (deferred, never failed, per the decision record), but tests should assert on counts/reason content rather than on which specific task number dispatched, unless the plan explicitly pins iteration order via `eligible_tasks` input order (which `run_sut`'s positional task-number arguments already control deterministically).

## Context Extension Recommendations

None. This is a narrowly-scoped script change inside an already well-documented file; no new `.claude/context/` topic is warranted. The decision record and this script's own header remain the correct homes for this rule's rationale.

## Appendix

- Searches/reads performed: `grep -n` sweeps of `orchestrate-cycle-plan.sh` for `WORKTREE_ISOLATED_TASK_TYPES`, `task_selected_for_worktree_isolation`, `file_scope`, `deferred`/`out_deferred_rows`, `defer_ledger`; full reads of lines 1-260 (header contract), 1120-1250 (status/task_types population), 1600-1880 (admission + bucketing loop), 1980-2260 (predicate, sibling territory, contended manifest), 2330-2433 (H1 + dry-run row builder); `grep -rln WORKTREE_ISOLATED_TASK_TYPES` repo-wide; reads of `orchestrate-batch-admit.sh`'s header (defer_reason schema) and `specs/decisions/worktree-isolation-removal-verdict.md` in full; `tests/test-orchestrate-cycle-plan.sh` Group 30/31 (lines 4089-4501) for fixture idiom and the glob-blind-spot discovery note; `context/standards/shell-strict-mode.md` for the script's strict-mode class; `tests/known-failures.txt` existence check; task #286's plan for prior-phase precedent confirming this task is where the mechanism was deliberately deferred to.
- No external documentation or web search was consulted (pure in-repo bash task).
