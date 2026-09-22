# Implementation Plan: Task #242

- **Task**: 242 - orchestrate partial-with-blocker stops redispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/242_orchestrate_partial_with_blocker_stops_redispatch/reports/01_orchestrate_partial_blocker_stops_redispatch.md
- **Artifacts**: plans/01_partial-blocker-stops-redispatch.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

An implementer that returns `.orchestrator-handoff.json` with `status: "partial"` and a populated
`blockers[]` entry is re-dispatched to `implement` every cycle until the budget runs out, because
`orchestrate-cycle-postflight.sh` never writes state.json's `status` field for a `partial`
outcome. Since `status` stays `implementing`, `orchestrate-triage-classify.sh`'s already-written,
already-tested `partial + blockers, no continuation -> needs_human` row is unreachable dead code.
The fix is to make that one status write happen — gated on a non-empty handoff `blockers[]` — so
the existing classifier row fires and the existing `needs_human` wiring (append to `failed_tasks`,
emit a visible `out_blocked_rows` entry) stops the futile redispatch. Definition of done: the
blocked-external case leaves state.json at `partial`, is excluded from redispatch for the rest of
the run with a visible row, and raises a blocker-research aux signal; the ordinary in-progress
partial case is byte-for-byte unchanged.

### Research Integration

The research report established the defect mechanism by direct read and is adopted in full for:
the fix location (`orchestrate-cycle-postflight.sh`'s `partial|failed|blocked)` case arm at
line ~792), the mechanism (`skill_postflight_update ... "partial"`, mirroring the `needs_research)`
arm's call shape at line ~809), the rejection of `status = "blocked"` as the target (a task with
empty `dependencies[]` routes to the **silent** `skip` bucket in the multi-task engine — worse
than the original defect), the blocker-research aux-gate widening, the choice of
`context/contracts/wrap-up.md` as the single DRY edit point for agent guidance, and the test
strategy.

**One research decision is narrowed by this plan.** Research Decision 1 recommended calling
`skill_postflight_update ... partial` **unconditionally** on every `partial` outcome, arguing it
is observationally identical for empty-`blockers[]` partials because the classifier routes both
`implementing` and bare `partial` to `implement`. That argument holds *within the classifier* but
not outside it, and the plan therefore adopts the **blockers-gated** form instead. Evidence
gathered at plan time:

- `scripts/orchestrate-batch-admit.sh`'s `is_in_flight` predicate covers
  `researching|planning|implementing` and **not** `partial`. Flipping every ordinary in-progress
  partial to `status: "partial"` would silently drop those tasks out of the in-flight set used for
  batch admission — a live behavior change in a file a concurrent sibling task is editing this
  same cycle.
- `scripts/git-snapshot.sh`'s no-argument task inference selects the single task whose status is
  `implementing`; an ordinary partial would stop resolving.

The gated form costs one conditional, confines the new behavior exactly to the defect, and
satisfies the dispatch's explicit requirement that ordinary in-progress partials keep their
current behaviour. Research Decision 5's test assertions (which read state.json `status` as
*unchanged* for the empty-`blockers[]` case) are internally consistent with the gated form and are
adopted verbatim; they contradict the unconditional form, which is a second reason to prefer
gating.

Two risks the research flagged for implementation-time checking were resolved at plan time and
need no further investigation:

- **Monotonic-max clamp**: `scripts/lib/status-vocabulary.sh` ranks only the linear-progress
  subset; `partial` is deliberately **unranked**, and `status_vocabulary_would_regress` returns
  false (clamp does not apply) whenever either side is unranked. The clamp can never skip this
  write. Pass `$clamp_mode` through unchanged, as the sibling arms do.
- **`$handoff` availability at the aux gate**: `$handoff` is in scope there — line ~974 already
  reads `.blockers` out of it into `churn_blockers_json` a few lines above the gate.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the dispatch context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- A `partial` dispatch outcome carrying a non-empty handoff `blockers[]` writes
  `status: "partial"` to state.json, activating the existing classifier row.
- That task is excluded from further `implement` dispatch for the rest of the run, visibly (an
  `out_blocked_rows` entry, never a silent `skip`).
- The existing blocker-research aux signal also fires for this case, with its description derived
  from the handoff rather than from the never-written `.active_projects[].blockers` string.
- Implementer contracts state when to return `blocked` vs `partial`-with-blockers, in one shared
  place rather than ~60 agent files.
- Regression tests pin both the new behavior and the preservation of the old one.

**Non-Goals**:
- Changing `orchestrate-cycle-plan.sh`. Its `needs_human` handling already appends to
  `failed_tasks` and emits a visible row; deliverable point 2 is satisfied by making the
  classifier reachable, and is *demonstrated* by a test rather than implemented by new code.
- Changing `docs/architecture/handoff-schema.md`. A concurrent sibling task owns that file this
  cycle, and the schema already permits `blockers[]` on a `partial` handoff — nothing there is
  wrong. Guidance goes to `context/contracts/wrap-up.md` instead.
- Changing the `failed)` or `blocked)` dispatch-status behavior. A literal `blocked` outcome
  already stops same-run redispatch via `failed_tasks`, independent of state.json `status`.
- Introducing a new verdict value or a new state.json status value. `partial` and
  `postflight:partial` already exist and are already schema-validated.
- Touching the single-task engine's Stage 4 handoff triage in `skills/skill-orchestrate/SKILL.md`
  (out of the dispatch's named scope; flagged by research as a separate follow-up concern).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Splitting `partial` out of the shared `partial\|failed\|blocked)` arm accidentally changes `failed`/`blocked` behavior | H | L | Keep the residual `failed\|blocked)` arm's body byte-identical, including its stderr message; diff-read the hunk before committing |
| `partial` + `user_decision` payload interaction — a partial outcome can also carry a `user_decision` relay (WORK (e), ~line 900) | M | L | The state-transition case switch runs first and independently; `user_decision` only affects the verdict field. Phase 4 adds a fixture combining the two and asserts both the status write and the `ask_user` verdict |
| Widened aux gate double-fires if the task later returns a literal `blocked` outcome | L | M | `aux_pending` is single-slot-per-task by design; a fresh signal overwrites the pending one. No new risk over today's `blocked` path |
| Concurrent sibling tasks editing the same shared tree | M | M | This plan's file scope is disjoint from every declared sibling scope (verified against the dispatch's territory block). Re-read each file immediately before editing; stage explicit file lists only, never a directory or glob pathspec |
| Classifier only inspects the handoff for `partial`/`blocked` rows, so the fix depends on the handoff file surviving to the next cycle | M | L | Confirmed at plan time: `orchestrate-triage-classify.sh` resolves the handoff via `task_lookup_dir` from the task directory, which persists across cycles. Phase 5's end-to-end test exercises exactly this path |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 5 | 1 |
| 3 | 4 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Write `status: "partial"` on a blocker-bearing partial outcome [COMPLETED]

- **Goal:** Make `orchestrate-cycle-postflight.sh` transition state.json to `partial` when a
  `partial` dispatch outcome carries a non-empty handoff `blockers[]`, so
  `orchestrate-triage-classify.sh`'s existing `partial + blockers, no continuation -> needs_human`
  row becomes reachable.
- **Tasks:**
  - [x] Re-read `scripts/orchestrate-cycle-postflight.sh` around the status-transition case switch
        (the `partial|failed|blocked)` arm, currently line ~792) before editing. *(completed)*
  - [x] Split a dedicated `partial)` arm out ahead of the existing arm; narrow the residual arm to
        `failed|blocked)` with its body and stderr message left byte-identical. *(completed)*
  - [x] In the new `partial)` arm, compute the handoff blocker count from the in-scope `$handoff`
        (`jq -r '(.blockers // []) | length'`, with the same non-numeric guard
        `orchestrate-triage-classify.sh` uses: `case "$n" in ''|*[!0-9]*) n=0 ;; esac`). *(completed)*
  - [x] When the count is greater than zero and `is_live`, call
        `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "" "$TASK_DIR" "$clamp_mode"`,
        mirroring the `needs_research)` arm's invocation shape at line ~809. Add the matching
        `[dry-run] would ...` branch, as every sibling arm has. *(deviation: altered — this call
        was a no-op until a matching `partial)` arm was added to `skill_postflight_update` itself
        in `scripts/skill-base.sh`, which had no case for status="partial" and silently skipped
        the write; see Files to modify below)*
  - [x] When the count is zero, keep today's behavior exactly: emit the existing
        "recognized exception outcome / no state.json transition performed" notice and write
        nothing. *(completed)*
  - [x] Add a short cross-reference comment on the new arm pointing at
        `orchestrate-triage-classify.sh`'s `partial + blockers` table row, explaining that the
        status write is what makes that row reachable. *(completed)*
  - [x] Add the reciprocal one-line comment on that table row in
        `scripts/orchestrate-triage-classify.sh` pointing back at this arm. Comment only — do not
        alter the table's contents or any classifier logic. *(completed)*
- **Timing:** 1 hour
- **Depends on:** none
- **Verification Tier:** full
- **Scope Hypothesis:** This phase asserts the edit is confined to two files and that
  `skill_postflight_update`'s `"implement"` operation argument resolves `postflight:partial` to
  `STATE_STATUS="partial"`. Confirm at implementation time by reading
  `scripts/update-task-status.sh`'s `postflight:partial` case (~line 296) and by running the
  existing `scripts/tests/test-orchestrate-cycle-postflight.sh` suite green before adding new
  cases.
- **Files to modify:**
  - `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - split the `partial)`
    arm out, add the gated status write and cross-reference comment
  - `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - reciprocal
    cross-reference comment on the `partial + blockers` table row only
  - `agent-system/extensions/core/scripts/skill-base.sh` - *(deviation: altered — not in the
    original scope. `skill_postflight_update`'s own status case switch had no `partial)` arm, so
    the Phase 1 call site above was a silent no-op without it. Added a `partial)` arm calling
    `update-task-status.sh postflight <N> partial <session>`, mirroring the existing
    `needs_research)` arm's shape.)*
- **Verification:**
  - `bash -n` both edited scripts.
  - Existing `scripts/tests/test-orchestrate-cycle-postflight.sh` and
    `scripts/tests/test-orchestrate-triage-classify.sh` still pass unchanged. *(confirmed: 87/87
    and 57/57 pass, unchanged)*
  - The `failed|blocked)` arm's diff shows only the removal of `partial|` from its pattern.
    *(confirmed by diff read-through)*

---

### Phase 2: Widen the blocker-research aux gate to blocker-bearing partials [COMPLETED]

- **Goal:** Raise the existing `blocker-research` aux signal for a `partial` outcome with a
  populated `blockers[]`, so the operator gets the same "investigate this blocker" aux dispatch
  that a literal `blocked` outcome already produces.
- **Tasks:**
  - [x] Re-read the `if [ "$verdict" = "blocked" ]` aux-signal block (currently line ~1012). *(completed)*
  - [x] Widen the gate to also admit `dispatch_status == "partial"` with a non-empty handoff
        `blockers[]` (reuse the blocker count computed in Phase 1 rather than recomputing it, if
        it is still in scope at this point; otherwise recompute with the identical guarded
        expression). *(deviation: altered — the widened admission is additionally gated on
        `hard_mode != true`. Without that guard, the new gate overwrote the existing hard-mode
        churn/divergence-audit aux signal for the identical dispatch_status=partial+blockers[]
        shape on every hard-mode cycle, breaking 5 existing tests. Base mode has no equivalent
        mechanism, mirroring the drift-inspection sibling branch's own `hard_mode != true` guard.)*
  - [x] For the partial path, build `blocker_desc` from the handoff's `blockers[0].target` plus
        `why_it_failed` when present, instead of reading `.active_projects[].blockers` — that
        state.json string field is never written by any script and would degrade to
        `"Unspecified blocker"`. *(completed)*
  - [x] Leave the existing `verdict = "blocked"` path's `blocker_desc` derivation untouched. *(completed)*
  - [x] Preserve the existing live/dry-run split and the single-slot `aux_pending[$t]` write shape. *(completed)*
  - [x] Update the block's leading comment, which currently asserts the two branches are
        "naturally disjoint since dispatch_status='blocked' can never also be 'partial'" — that
        reasoning no longer describes the widened gate. *(completed)*
- **Timing:** 0.75 hours
- **Depends on:** 1
- **Verification Tier:** full
- **Files to modify:**
  - `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - widen the aux gate and
    add the handoff-derived description
- **Verification:**
  - `bash -n` passes. *(confirmed)*
  - Existing test suite still green. *(confirmed: 87/87, after the hard_mode-guard fix above; failed
    5/87 before it)*
  - A manual dry-run invocation over a partial+blockers fixture prints the
    `[dry-run] would record a blocker-research aux signal` line. *(confirmed via an ad hoc sandbox
    dry-run: prints both "would transition task ... to partial (blocker-bearing)" and "would
    record a blocker-research aux signal")*

---

### Phase 3: Blocked-vs-partial guidance in the shared handoff contract [COMPLETED]

- **Goal:** State the decision rule for `blocked` vs `partial`-with-blockers once, in the shared
  H9 wrap-up contract, and point the implementer agent contract at it.
- **Tasks:**
  - [x] Re-read `context/contracts/wrap-up.md` around its `status` field documentation (~line 43). *(completed)*
  - [x] Add a short subsection giving the rule: use `blocked` when no further implementation effort
        of any kind can proceed; use `partial` with a populated `blockers[]` entry and no
        continuation pointer when some phases completed but a specific remaining phase is blocked
        by a cause outside the agent's control (e.g. an external service or release asset that is
        unavailable) that no further attempt on that phase can close; do not use `failed`, which
        implies non-recoverable and discards credit for the completed phases. *(completed)*
  - [x] Note in that subsection that a blocker-bearing `partial` now stops same-run redispatch and
        raises a blocker-research aux signal, so returning it is the correct signal rather than a
        degraded one. *(completed)*
  - [x] Add a one-line pointer from `agents/general-implementation-agent.md`'s existing
        `.orchestrator-handoff.json` section (which already says "Use the shape defined by ...") to
        the new wrap-up.md subsection. Do not duplicate the rule text there. *(completed)*
  - [x] Do not edit `docs/architecture/handoff-schema.md` — a concurrent sibling task owns it this
        cycle, and the schema already permits `blockers[]` on a `partial` handoff. *(completed:
        not touched)*
  - [x] Do not edit the other ~60 implementer/research agent files; they already reference
        wrap-up.md by pointer. *(completed: not touched; confirmed via
        `grep -rl "orchestrator-handoff.json" agent-system/extensions/*/agents/*.md` — 64 hits,
        spot-checked general-research-agent.md, planner-agent.md,
        cslib/pr-review-implementation-agent.md — all three reference wrap-up.md's "Write
        location" and their own `status` vocabulary line, none restate a blocked-vs-partial rule
        inline (it did not previously exist anywhere), confirming the Scope Hypothesis)*
  - [x] Keep every task number out of both files (deliverables outside `specs/**`). *(completed)*
- **Timing:** 0.75 hours
- **Depends on:** none
- **Verification Tier:** prose
- **Scope Hypothesis:** This phase asserts exactly two files need editing, on the research finding
  that the ~60 agent files reference wrap-up.md rather than restating the contract. Confirm with
  `grep -rl "orchestrator-handoff.json" agent-system/extensions/*/agents/*.md` and by spot-checking
  two or three of the hits for a pointer rather than an inline copy; if any file restates the
  status vocabulary inline, record the finding rather than silently widening the edit set.
  *(confirmed holds — see task list above)*
- **Files to modify:**
  - `agent-system/extensions/core/context/contracts/wrap-up.md` - new blocked-vs-partial subsection
  - `agent-system/extensions/core/agents/general-implementation-agent.md` - one-line pointer
- **Verification:**
  - Diff read-through confirms both hunks are prose only. *(confirmed)*
  - `bash .claude/scripts/check-task-references.sh` (or the equivalent repo lint) reports no new
    task-number occurrences. *(confirmed: 0 occurrences in both scoped subtrees)*

---

### Phase 4: Postflight regression tests [COMPLETED]

- **Goal:** Pin the new status write and the preservation of the empty-`blockers[]` behavior in
  `scripts/tests/test-orchestrate-cycle-postflight.sh`.
- **Tasks:**
  - [x] Re-read the test harness, using the `acceptance (6)` case as the template — it already
        demonstrates the post-`run_sut` state.json read
        (`jq ... "$WORKDIR/specs/state.json"`) that these assertions need. *(completed)*
  - [x] New case: `partial` + non-empty `blockers[]`, no continuation pointer. Assert
        `active_projects[].status == "partial"`, `verdict == "defer"` (unchanged), `halt == false`,
        and that `aux_pending[<task>].kind == "blocker-research"` with a `blocker_desc` derived
        from the handoff (not `"Unspecified blocker"`). *(completed: fixture 830)*
  - [x] New case: `partial` + empty `blockers[]`. Assert `active_projects[].status` is **unchanged
        from its pre-run value** (`implementing`), `verdict == "defer"`, and that no
        `blocker-research` aux signal was recorded — this is the explicit
        "current defer behaviour must be preserved" check. *(completed: fixture 831)*
  - [x] New case: `partial` + non-empty `blockers[]` + a `user_decision` payload. Assert the status
        write still happens and the `user_decision` relay still resolves its own verdict, covering
        the interaction risk above. *(completed: fixture 832)*
  - [x] Assert on state.json and the defect store, not on the stdout line that merely echoes
        `dispatch_status` verbatim — that line is not evidence of a state write. *(completed)*
  - [x] Use fresh task numbers that do not collide with the existing fixtures. *(completed:
        830/831/832, none previously used)*
- **Timing:** 1.25 hours
- **Depends on:** 1, 2
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - three new
    cases
- **Verification:**
  - `bash scripts/tests/test-orchestrate-cycle-postflight.sh` passes, with the three new cases
    reporting `pass`. *(confirmed: 99/99, up from 87/87 baseline — 12 new assertions across the
    three new fixtures)*
  - Each new case fails when the Phase 1/2 edits are temporarily reverted (confirm at least the
    first one this way, so the test is known to be load-bearing rather than vacuous). *(confirmed:
    reverted orchestrate-cycle-postflight.sh to its pre-Phase-1 content and re-ran the suite —
    fixtures 830 and 832 both failed as expected (830: 4 assertions failed; 832: 1 assertion
    failed); fixture 831 has no positive assertion to break by construction (it pins the
    unchanged-behavior negative case) and correctly kept passing. Restored the fix afterward;
    suite is back to 99/99.)*

---

### Phase 5: End-to-end no-redispatch test [COMPLETED]

- **Goal:** Demonstrate deliverable point 2 directly — a task left at `status: "partial"` with a
  populated handoff `blockers[]` is not routed back into `implement` in the same run.
- **Tasks:**
  - [x] Re-read `scripts/tests/test-orchestrate-cycle-plan.sh` and follow its existing fixture and
        assertion conventions. *(completed; used Group 7's dry-run + `.blocked`/`.dispatch`
        assertion template)*
  - [x] Add a case whose state.json fixture has the task at `status: "partial"` with empty
        `dependencies[]`, and whose task directory carries an `.orchestrator-handoff.json` with a
        populated `blockers[]` and no continuation pointer. *(completed: Group 26, candidate #2701)*
  - [x] Assert the task appears in `out_blocked_rows` (visible, not a silent `skip`) and is absent
        from the dispatch rows / `eligible_tasks`. *(completed: asserted via the SUT's own
        `.blocked[]` output array, which is exactly what `out_blocked_rows` becomes in the
        emitted plan JSON)*
  - [x] Add the companion negative case: the same fixture with an empty `blockers[]` is still
        routed to `implement`. *(completed: Group 26 negative, candidate #2702)*
- **Timing:** 1 hour
- **Depends on:** 1
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - two new cases
- **Verification:**
  - `bash scripts/tests/test-orchestrate-cycle-plan.sh` passes with both new cases reporting
    `pass`. *(confirmed: 243/243, up from 238/238 baseline — 5 new assertions across the two
    fixtures)*

---

## Testing & Validation

- [ ] `bash -n` clean on every edited shell script.
- [ ] `scripts/tests/test-orchestrate-cycle-postflight.sh` passes, including the three new cases.
- [ ] `scripts/tests/test-orchestrate-cycle-plan.sh` passes, including the two new cases.
- [ ] `scripts/tests/test-orchestrate-triage-classify.sh` still passes (comment-only edit there).
- [ ] The blocker-bearing partial case leaves state.json at `partial`; the empty-blockers partial
      case leaves it at `implementing`.
- [ ] No new task-number references outside `specs/**`.
- [ ] Every edit landed under `agent-system/extensions/core/**`, never `.claude/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (comment only)
- `agent-system/extensions/core/context/contracts/wrap-up.md` (modified)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (modified)
- `specs/242_orchestrate_partial_with_blocker_stops_redispatch/summaries/01_*-summary.md`

## Rollback/Contingency

Each phase is a small, independently committed hunk, so rollback is `git revert` of the specific
commit — no working-tree discard is required and none should be performed. If the Phase 1 status
write turns out to have an unanticipated downstream consumer (the `is_in_flight` and
`git-snapshot.sh` consumers were checked at plan time; a third would be the surprise), narrow the
gate further rather than reverting the whole change: the blocker-bearing case is the only one that
must change behavior. Should a genuine whole-tree rollback ever be needed, use the snapshot-then-
rollback recipe in `context/contracts/recovery.md`'s rollback rung, including its out-of-scope
override flag — never a bare precautionary `git-snapshot.sh` call.
