# Research Report: Task #449

- **Task**: 449 - Site the Batch Gate Deferral directive where it is read before the phase's verification is launched
- **Started**: 2026-11-09
- **Completed**: 2026-11-09
- **Effort**: ~1 hour (research)
- **Dependencies**: 328, 360, 407, 414, 444, 445, 446, 448 (all completed/archived)
- **Sources/Inputs**: Codebase (agent-system/extensions/core/**), task's own archived evidence (task 417 plan + issues.jsonl), task 445's completed summary
- **Artifacts**: specs/449_hoist_batch_gate_deferral_directive/reports/01_batch-gate-deferral-siting.md
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The cited miss is confirmed genuine: task 417's dispatch_seq 5, Phase 4, was that plan's own
  final (4th of 4) phase and its only `**Verification Tier**: full` phase. The Batch Gate
  Deferral directive genuinely applied there — the defect is siting/recency, not scoping. The
  HARD CONSTRAINTS' alternate branch ("if it did not [apply], the defect is the scoping") does
  not fire.
- Of the three candidate mechanisms, Option (1) (hoist ahead of `## Plan`) is recommended as the
  mechanism to implement. Option (2) (restate inside `## Phase Mission`) is structurally
  unavailable for the common, non-hard-mode dispatch shape that produced the cited miss — that
  section is emitted only under hard mode's per-phase dispatch. Option (3) (batch-aware
  aggregator) is the most robust in principle but carries a concrete false-positive risk today:
  8 stale `.orchestrator-multi-state-*.json` files already sit in `specs/.orchestration/` with no
  cleanup path, so a naive "does a multi-state file exist" detector would misfire against a
  legitimate standalone run.
- Task 445 (completed) and this record's option (3) both touch `verify-deploy.sh` but at
  disjoint mechanisms (Gate 8's own exit-code semantics vs. a new batch-detection layer around
  invocation) — no reconciliation conflict found; the "reconcile during research" directive is
  discharged with "no action needed."
- A reusable position-assertion pattern already exists in `scripts/tests/test-orchestrate-build-dispatch.sh`
  (Group 15, Case 2: `grep -n` each heading, compare line numbers) that the VERIFY section's new
  fixture can copy directly.

## Context & Scope

Researched the siting defect described in the task: `## Batch Gate Deferral` is emitted by
`orchestrate-build-dispatch.sh` as the 9th-or-10th of the dispatch file's sections (section count
has grown since the task's own line-number snapshot — see Findings below), sitting immediately
after `## Plan`/`## Phase Mission` and before `## Handoff`. The task asks for exactly one chosen
mechanism (of three candidates) to be recorded with reasoning, plus confirmation of whether the
final-phase-only scoping was actually satisfied in the cited incident. This report covers only
the choice-of-mechanism analysis and the supporting verification of premises; the actual edit and
test extension are left to the plan/implement phases.

## Findings

### Codebase Patterns

**Current section emission order** (re-derived fresh; the task description's own line numbers
have already drifted, exactly as its "re-derive before editing" caveat anticipated):
`## Identity` (569) -> `## Description` (586) -> `## Artifact Round` (594) -> `## Research
Artifact` (601, plan phase only) -> `## Prior Plan` (606, plan phase only) -> `## Plan` (614,
implement phase only) -> `## Continuation` (635, implement phase only) -> `## Phase Mission`
(647, implement + hard-mode `--phase-number` only) -> `## Batch Gate Deferral` (682, implement +
`--batch-gate-deferral` only) -> `## Handoff` (725) -> `## Issue Log` (737) -> `## Territory`
(770, conditional) -> `## Prior Decisions` (817, conditional) -> `## Premise Re-Validation` (836,
conditional) -> `## Outstanding Gate Finding` (858, conditional) -> `## Wait Discipline` (872) ->
`## User-Decision Contract` (882). The two sections after `## Prior Decisions` (`## Premise
Re-Validation`, `## Outstanding Gate Finding`) did not exist at this task's creation time — they
are a different task's already-landed work (the territory edge note anticipating a "premise
re-validation checklist" from a since-completed task). Their presence confirms that territory
edge resolved in the anticipated order (landed first) and does not otherwise affect this
record's own section-ordering decision. `## Batch Gate Deferral` itself is unmoved relative to
`## Plan` and `## Phase Mission` — the premise the task description describes is still live.

**Emission condition is NOT final-phase-scoped at the composer level.** `orchestrate-cycle-plan.sh`
sets `--batch-gate-deferral` on `build_args` whenever `[ "$g" = "implement" ] && [ "$_bgd_task_count"
-gt 1 ]` (`_bgd_task_count` read from the invocation-level `.task_numbers` count, deliberately not
the per-cycle dispatch count). This fires for *every* implement-phase dispatch of every task in a
genuine multi-task batch — there is no separate "is this dispatch the plan's final phase"
predicate at the composer. The final-phase-only restriction is entirely the *consuming* agent's
own job, stated once in `general-implementation-agent.md`'s Stage 4C: "Batch Gate Deferral (final
phase only): before running this phase's verification, check whether the dispatch file ... carries
a `## Batch Gate Deferral` section. If it does, **and this is the plan's final phase declaring
`**Verification Tier**: full`**, discharge the phase against the scoped tier..." (current lines
~510-521; the task description's "469-470"/"1023" line numbers have drifted to ~510 and ~1078
respectively — same text, confirmed unchanged in substance).

**The ordinary (non-hard-mode) dispatch shape processes every plan phase inside ONE dispatch.**
`general-implementation-agent.md` runs a phase loop internally ("Only then proceed to Stage 4D-iii
and the next phase," "After all phases complete: ...", "Backstop: after all phases complete,
perform a fresh read of the plan file..."). `## Phase Mission` is gated on `$phase_number` being
set, and `$phase_number`/`--phase-number` is exclusively an H1 hard-mode construct (one dispatch
per plan-phase). **The cited 417 miss was this ordinary shape**: one dispatch (seq 5) covering
multiple phases, reaching Phase 4 only after Phases 1-3's own work, with the dispatch file read
once at dispatch start. This matters directly for Option (2) below.

**Confirmed: the cited miss's phase genuinely carried the obligation.** Task 417's archived plan
(`specs/archive/417_resolve_gate20_eager_load_budget_overage/plans/01_gate20-eager-load-headroom.md`)
has exactly 4 phases; Phase 4 ("Redeploy and run the full gate set") is both the last phase and
the only one declaring `**Verification Tier**: full` (Phases 1-3 all declare `prose`). The
archived issue entry (`iss_1792315896632_CrEg7F`, `specs/archive/417_.../issues.jsonl`) confirms
the agent's own account: it ran the complete `verify-deploy.sh` aggregator, 9 of 38 checks failed
as contention timeouts (1-min load avg 52.70, 24 cores, 21 concurrent gate processes), and none
of the 9 touched this task's own 3 files or its actual target (gate20, independently 4/4 PASS).
This closes the HARD CONSTRAINTS branch cleanly: the directive applied; the defect is purely
siting/recency, not scoping.

**Reconciliation with task 445 (completed) — no conflict found.** 445's summary
(`specs/445_gate8_expected_vs_new_failure_distinction/summaries/01_gate8-expected-new-distinction-summary.md`)
shows its change is entirely internal to `gate8_run()`'s own exit-code branching (EXPECTED vs. NEW
failure classification via `run-all.sh --fail-on-new` and the `[run-all] Failing suites (` roster
header) — it never touches invocation-level batch detection. Any option-(3) batch-aware check
would sit at a different layer (verify-deploy.sh's entry point or run-all.sh's own argument
handling, before gate selection), not inside gate8_run(). Same file, disjoint mechanism, as the
task description already anticipated; no further action needed to reconcile.

**Option (3)'s concrete obstacle: stale multi-task state files.** The invocation-scoped batch
state file lives at `specs/.orchestration/.orchestrator-multi-state-<session_id>.json`
(`runtime_mt_state_path()` in `scripts/lib/runtime-file-patterns.sh`). No `rm` of this path was
found anywhere in `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, or
`skill-orchestrate.sh` — it is apparently never cleaned up. The live repository currently carries
8 such files from sessions spanning Nov 6-8, several recording `.task_numbers | length > 1`. A
naive "does any multi-state file with `task_numbers > 1` exist" detector inside `verify-deploy.sh`
would therefore misfire against a brand-new standalone (single-task) run. A correct
implementation needs the session_id of the *invoking* dispatch threaded into `verify-deploy.sh`
(new CLI plumbing, not present today) so detection can scope to that one file, plus some liveness
signal beyond mere presence — confirming the task description's own characterization of option
(3) as "the largest change" and its fail-open requirement as load-bearing, not precautionary.

**Reusable test pattern already exists for position-pinning.** `test-orchestrate-build-dispatch.sh`
Group 15, Case 2 (around line 1010) already asserts a block is "present VERBATIM and positioned
before `## Wait Discipline`" using exactly the technique the VERIFY section calls for:
`grep -n "^## ..." "$LAST_DISPATCH_FILE" | head -1 | cut -d: -f1` for each heading, then a numeric
`-lt` comparison with a named pass/fail. Group 19 (around line 1271) already covers
`--batch-gate-deferral` presence/content/byte-identity-when-absent, but not position — the new
fixture the VERIFY section asks for can extend Group 19 using Group 15's exact idiom.

### External Resources

Not applicable — this is a purely internal composer/agent-contract question with no external
dependency; no web research was needed or performed.

## Recommendations

**Recommended mechanism: Option (1) — hoist `## Batch Gate Deferral` to immediately after
`## Description`, ahead of `## Artifact Round`/`## Plan`.**

Reasoning, weighing all three:

- **Option (2) (restate in `## Phase Mission`) does not reach the dispatch shape that actually
  failed.** The cited miss was an ordinary (non-hard-mode) dispatch, which never emits `## Phase
  Mission` at all. Implementing option (2) literally as described would require inventing a new
  per-phase restatement point inside the ordinary dispatch's own internal loop (not a dispatch-file
  section the composer can emit once), which is a materially different and larger change than the
  task description's framing suggests, and is hard to pin with the VERIFY section's own
  position-fixture approach (there is no stable heading to measure against in the common case).
  A narrower reading of option (2) — restating the obligation inside
  `general-implementation-agent.md`'s own Stage 4C prose — is *already done* today (that is
  exactly where the "final phase only" check text lives); the cited miss happened anyway, by the
  agent's own account, because the full run was started before the dispatch file's directive was
  re-consulted. Restating prose that already exists at point-of-use does not change that ordering
  failure.
- **Option (3) (batch-aware aggregator) is the most robust in principle but is not safely buildable
  today without first solving a session-identity/liveness problem that does not yet exist.** The
  8 stale multi-state files currently sitting in `specs/.orchestration/` (never cleaned up) mean a
  naive detector would false-positive against standalone runs — exactly the risk the task's own
  HARD CONSTRAINTS flagged ("the detection must fail OPEN"). Building this correctly requires new
  plumbing (session_id threaded into `verify-deploy.sh`/`run-all.sh`) that is out of proportion to
  the single measured incident this task closes, though it remains a reasonable *future*
  enhancement once that plumbing exists for other reasons.
- **Option (1) is cheap, directly addresses the described root cause (buried after the dispatch
  file's single largest section), and is trivially testable with the Group 15 position-pin idiom
  already in the test file.** It does not, by itself, fully solve the "read once at dispatch start,
  forgotten several phases later" recency problem for a long multi-phase plan — but it raises the
  odds of the directive being seen at all (both at the initial top-to-bottom read, and on any
  re-read prompted by Stage 4C's existing "check whether the dispatch file carries a section"
  instruction, which no longer requires scrolling past the plan body to find it), at the lowest
  implementation and testing cost, and with no new false-positive surface.

**Suggested landing point**: immediately after `## Description` (echo call ~line 593, before
`## Artifact Round`), rather than immediately after `## Identity`. Rationale: `## Description` is
itself scope-defining content the reader needs before any constraint on *how* to execute makes
sense, while `## Identity` is pure bookkeeping (task number, session id). Landing the directive
right after the task's own description, and before the Plan/Continuation/Phase-Mission block it
constrains, keeps the file's existing "identity/description, then everything else" shape intact
while still placing it well ahead of the large `## Plan` body. This is an implementation-time
detail for the plan phase to confirm, not a load-bearing research conclusion.

**For the plan phase**: extend `test-orchestrate-build-dispatch.sh` Group 19 with a fixture using
the exact Group 15 Case 2 idiom — `grep -n "^## Batch Gate Deferral"`, `grep -n "^## Plan"`,
`grep -n "^## Phase Mission"`, numeric comparison asserting the deferral heading's line number is
less than both others whenever all three are present — so a future accidental reordering fails
the suite rather than silently reintroducing this defect.

## Decisions

- Confirmed the directive genuinely applied to the cited miss's phase (417's Phase 4 was that
  plan's final and only `full`-tier phase) — the HARD CONSTRAINTS' "scoping defect" branch does
  not apply; no widening of the final-phase-only restriction is warranted.
- Confirmed no reconciliation conflict with task 445's completed `verify-deploy.sh` changes
  (disjoint mechanism within the same file).
- Recommend Option (1) (hoist after `## Description`) as the chosen mechanism, with Options (2)
  and (3) recorded as considered-and-not-chosen for the reasons above (option 2 structurally
  inapplicable to the dispatch shape that failed; option 3 deferred pending session-identity
  plumbing that does not exist today).

## Risks & Mitigations

- **Risk**: hoisting alone may not fully prevent a repeat if an agent still starts verification
  before re-checking the (now earlier-sited) section. **Mitigation**: this is explicitly the
  residual risk option (1) accepts per the analysis above; the existing Stage 4C instruction to
  check before running verification is unchanged and remains the operative control — hoisting
  only makes that check cheaper and more reliable to perform, not automatic.
- **Risk**: a future addition of a new dispatch-file section between `## Description` and
  `## Batch Gate Deferral` could silently erode the hoist's benefit over time. **Mitigation**: the
  recommended position-pinning test fixture (see Recommendations) catches any reordering that
  would move `## Batch Gate Deferral` back toward or past `## Plan`.
- **Risk**: stale `.orchestrator-multi-state-*.json` accumulation (noted above) is itself an
  unaddressed hygiene gap, independent of this task. **Mitigation**: out of scope here; flagged
  as a Context Extension Recommendation below rather than fixed in this record.

## Context Extension Recommendations

- **Topic**: multi-task batch state file lifecycle.
- **Gap**: no context file documents that `specs/.orchestration/.orchestrator-multi-state-<session_id>.json`
  files are never cleaned up after a batch invocation completes, which is exactly the fact that
  makes option (3) above non-trivial. `context/patterns/batch-orchestration-guardrails.md` and
  `context/contracts/batch-gate-stage.md` document the mechanism's *use* but not its *cleanup* (or
  lack thereof).
- **Recommendation**: a future task considering any batch-state-file consumer (this one's option
  3, or a `/refresh`-style cleanup) should record the lifecycle (creation, on-disk lifetime,
  absence of cleanup) in one of those two files or a new one, rather than each consumer
  rediscovering it independently via `ls specs/.orchestration/`.

## Appendix

- Search queries / commands used: `grep -n '^[[:space:]]*echo "## '` over
  `orchestrate-build-dispatch.sh`; `grep -n "Batch Gate Deferral" -r` over the source store;
  `grep -n "batch_gate_deferral\|batch-gate-deferral"` over `orchestrate-cycle-plan.sh`;
  `grep -n "^### Phase\|Verification Tier"` over task 417's archived plan; `jq` queries over
  `specs/state.json` for dependency/task status; `ls`/`find` over `specs/.orchestration/` for
  stale multi-state files; targeted `sed -n` reads of `phase-closure.md`, `plan-format.md`,
  `batch-gate-stage.md`, `orchestrate-state-machine.md`, and `general-implementation-agent.md`.
- Key files read: `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `scripts/orchestrate-cycle-plan.sh`, `scripts/lib/runtime-file-patterns.sh`,
  `agents/general-implementation-agent.md`, `context/contracts/phase-closure.md`,
  `context/contracts/batch-gate-stage.md`, `context/formats/plan-format.md`,
  `docs/architecture/orchestrate-state-machine.md`,
  `scripts/tests/test-orchestrate-build-dispatch.sh`,
  `specs/archive/417_resolve_gate20_eager_load_budget_overage/plans/01_gate20-eager-load-headroom.md`,
  `specs/archive/417_resolve_gate20_eager_load_budget_overage/issues.jsonl`,
  `specs/445_gate8_expected_vs_new_failure_distinction/summaries/01_gate8-expected-new-distinction-summary.md`.
