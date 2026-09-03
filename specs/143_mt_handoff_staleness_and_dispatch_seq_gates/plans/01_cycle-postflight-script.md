# Implementation Plan: Build `orchestrate-cycle-postflight.sh`

- **Task**: 143 - Build orchestrate-cycle-postflight.sh: per-task postflight as one script (absorbs the MT handoff gates)
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: 147 (`orchestrate-cycle-plan.sh`, satisfied and archived)
- **Research Inputs**: specs/143_mt_handoff_staleness_and_dispatch_seq_gates/reports/01_cycle-postflight-consolidation.md
- **Artifacts**: plans/01_cycle-postflight-script.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`: one script that
performs everything the orchestrator lead does after an agent returns, for both engines, emitting
one JSON line. It is Stage A.4 of `specs/PATH.md` and the last of the three per-cycle scripts
(after `orchestrate-build-dispatch.sh` and `orchestrate-cycle-plan.sh`). The originally-scoped
work — porting single-task Stage 5's mtime staleness gate and `dispatch_seq` identity gate to the
multi-task path — is delivered by construction, because both paths call the one script. Three
absorbed sibling gaps land alongside: writer-contract-aware defect recording (the spurious
`HANDOFF_STALE_OR_ABSENT` on a contractual non-writer), the multi-task artifact-round advance, and
the `modified_files`-vs-`file_scope` excursion advisory. Definition of done: both engines call the
script, the fixture suite proves all five acceptance conditions, a live multi-task cycle runs
through it, bytes removed from `SKILL.md` are reported, and the full gate run is green.

### Research Integration

The research report settles scope and maps every WORK item onto existing precedent:

- **Gate pair to port verbatim in spirit**: `skill-orchestrate/SKILL.md` Stage 5's staleness gate
  (mtime vs `dispatch_start_ts`, fail-closed default `9999999999`) and its `dispatch_seq` identity
  gate (between the `dispatch-seq-gate:begin`/`:end` sentinels). Stage MT-4 step 1 was confirmed by
  direct reading to have **neither** — it trusts the handoff whenever the file exists.
- **~70% of the logic already exists** in `orchestrate-stage5-gates.sh` (stray sweep, recovery
  orchestration, corroboration, infra discrimination), `orchestrate-stage5-postflight.sh` (status
  case ladder, completion-claim gate, artifact link, artifact-round advance), and
  `orchestrate-recover-outcome.sh` (read-only return-meta reader). The new script merges these
  concerns into one per-task call and adds the three genuinely new behaviors.
- **Two live incidents are fixture material**: `evt_1787614360544_SgKpRP` (a still-live predecessor
  whose late handoff carried a *newer* mtime than the resume's window — only `dispatch_seq` caught
  it) and `evt_1788246742189_Fodegl` (a woken predecessor that **git-restored** its own deleted
  `.orchestrator-handoff.json` *and* `.return-meta.json` with a fresh in-window mtime). The second
  proves both that "clear the handoff at dispatch start" is defeated outright, and that the
  return-meta recovery path shares the exposure and is currently unguarded.
- **Schema gap confirmed**: `.return-meta.json` has no `dispatch_seq` field today. Resolved by
  Decision D2 below.
- **CLI convention**: copy `orchestrate-cycle-plan.sh`'s `--session SID --state-file F` flag parser
  (`while [ "$#" -gt 0 ]` case loop, `usage()` heredoc, `--help`), including its
  `mt_state_file="$(dirname "$STATE_FILE")/.orchestrator-multi-state-${session_id}.json"` derivation.

### Design Decisions

The research report left two questions explicitly open for this plan. Both are resolved here; the
implementer records the chosen mechanism in `docs/architecture/handoff-schema.md` next to the
existing "Handoff Writers" table (Phase 3).

**D1 — Writer-contract determination: recorded-agent-name allowlist (research report Option 1).**
The script resolves "was THIS dispatch's writer contractually expected to produce a handoff?" by
reading the agent name the dispatch composer already recorded for this task this cycle
(`research_agents[$t]` / `implement_agents[$t]` on the multi-state file, written by
`orchestrate-cycle-plan.sh`; the literal `planner-agent` for the plan phase) and testing it against
a small, single-site allowlist of contractual handoff writers — today, only the cslib and lean
hard-mode implementation agents. Combined with `dispatch_seq[$t]`, that pair *is* this dispatch's
identity, satisfying the dispatch's "keyed on dispatch identity, not on phase alone" requirement.
Option 2 (re-running the manifest routing ladder) is rejected: it re-executes a resolution the
dispatch already performed once, in a second place that can drift from the first.

The allowlist's staleness hazard is handled by direction, not by hope: **an agent name absent from
the allowlist is treated as a NON-writer (no defect recorded for an absent handoff) and MUST emit a
loud, named `WARN` naming the unrecognized agent.** Rationale: base mode is the overwhelming
default and every core agent is a non-writer, so recording on unknown would reproduce exactly the
spurious-defect bug this task absorbs; the WARN keeps an unregistered third-party writer visible
rather than silent. This suppression narrows *only* the absent-handoff recording — a present but
seq-mismatched or mtime-stale handoff still records `HANDOFF_STALE_OR_ABSENT` unconditionally,
regardless of writer contract.

**D2 — Add `dispatch_seq` to the `.return-meta.json` channel (not the narrower mtime-only fix).**
Acceptance condition (3) requires the git-restored predecessor shape to be rejected by *recovery*,
and mtime is provably inert against it (the restored file's mtime fell inside the successor's
window). The field is therefore added to the return-metadata schema and to the core agent contracts
that write the file; agents already receive `dispatch_seq` in both their dispatch context object and
their dispatch file's Identity section, so no new plumbing is needed to produce it. The consumer
degrades exactly as the handoff gate already does: a `.return-meta.json` with no `dispatch_seq`
produces a `WARN` and falls back to mtime-only discrimination, never a hard failure — so writers
that have not yet adopted the field keep working through the transition.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` exists in this repository and no `roadmap_path` was provided in the dispatch
context. `specs/PATH.md` is the governing sequencing document instead: this task is its Stage A.4,
and completing it closes absorbed backlog entries for the recording-order defect, the multi-task
artifact-round advance, and the excursion advisory.

## Goals & Non-Goals

**Goals**:

- One script, `orchestrate-cycle-postflight.sh <task_number> --session SID --state-file F`,
  performing WORK items (a) through (j) in order and emitting one compact JSON line:
  `{task, phase, status, phases_completed, phases_total, verdict, user_decision?, note}`.
- The mtime staleness gate and the `dispatch_seq` identity gate apply on **both** engine paths by
  construction, with byte-identical semantics and the same fail-closed `9999999999` default.
- `orchestrate-recover-outcome.sh` gains a `dispatch_seq` identity check with graceful degradation.
- A contractual non-writer leaving no fresh handoff records **no** defect; a seq-mismatched late
  write from a live or resurrected predecessor still does.
- A `user_decision` payload is relayed intact as verdict `ask_user`, with status left exactly as the
  agent left it.
- Both engines call the script; the prose it replaces leaves `SKILL.md` for `docs/architecture/`.

**Non-Goals**:

- Deleting the single-task engine (that is task 88's job; both engines call this script until then).
- Any gate strengthening or weakening beyond the two ported gates — the excursion check is
  **advisory/detection only**, per the absorbed task's own recommendation.
- Building the `.decisions.json` writer or any asking behavior. The script never asks and never
  decides; the lead owns both.
- Reading report, plan, summary, or handoff **prose** (Context Flatness Constraint). Count-only
  greps and named-field `jq` reads are the only permitted contact with those files.
- Batch commits. Every commit is per-task and scoped, via `git-commit-scoped.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `dispatch-seq-gate:begin`/`:end` sentinel region in `SKILL.md` is extracted and `eval`ed by `test-handoff-dispatch-identity.sh`; removing it on cutover silently breaks that suite | H | H | Phase 7 is `Commit Mode: atomic-batch` over a declared file set: retarget the suite at the script's gate and remove the SKILL.md region in one batch, never separately |
| Script-boundary swallowing a loop-control decision (the risk `orchestrate-stage5-postflight.sh`'s header already names) | H | M | Same mitigation as precedent: the script computes and prints a verdict; the lead applies loop control. `verdict` is the only channel; the script never halts, never re-dispatches, never asks |
| Suppressing the absent-handoff defect too broadly re-swallows a genuine clobber | H | M | D1 narrows suppression to the *absent* case only; a present stale/mismatched handoff always records. Acceptance (4) tests both directions |
| The allowlist goes stale when a third extension adds a hard-mode writer | M | M | Unknown agent → non-writer **plus a loud named WARN** (D1); single-site allowlist documented next to `handoff-schema.md`'s Handoff Writers table |
| `.return-meta.json` writers do not emit `dispatch_seq` during the transition, leaving recovery gate inert | M | H | Graceful degradation with a named WARN (D2), mirroring the handoff gate's existing empty-field behavior; core agent contracts updated in Phase 1 so the field starts flowing immediately |
| Two engines temporarily disagree on gate semantics during cutover | M | M | Cut over in one phase (7), after the fixture suite is green (6); acceptance requires both engines visibly agree |
| The fail-closed `9999999999` sentinel is re-derived differently in the new script | M | L | Preserve the literal exactly; Phase 6 asserts it by grep across all three sites |
| Excursion advisory mistaken for a gate | M | L | Detection and logging only; no exit-code or verdict influence. Stated in the script header and asserted by a fixture |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7 | 6 |

Phases within the same wave can execute in parallel. Phases 2-5 each edit the same new script file
and are therefore deliberately serialized rather than parallelized.

---

### Phase 1: `dispatch_seq` on the return-meta channel [COMPLETED]

**Goal**: Close the schema gap that makes acceptance condition (3) reachable — `.return-meta.json`
carries `dispatch_seq`, and `orchestrate-recover-outcome.sh` gates on it with graceful degradation.

**Tasks**:
- [x] Add a `dispatch_seq` field specification to `context/formats/return-metadata-file.md`:
      optional top-level integer, producer-owned, echoed verbatim from the dispatch context /
      dispatch-file Identity section; absent means "writer predates the contract". *(completed)*
- [x] Add the field to the copyable contract fragment
      `context/contracts/return-meta-artifacts-template.md` so agents inherit it from one place. *(completed)*
- [x] Update the core agent contracts that write `.return-meta.json` under `/orchestrate`
      (`general-research-agent`, `planner-agent`, `general-implementation-agent`) to echo it. *(completed)*
- [x] Extend `orchestrate-recover-outcome.sh` with an OPTIONAL third positional
      `<expected_dispatch_seq>`, appended after `<window_start_ts>` so every existing 2-arg call
      site keeps working unchanged. *(completed)*
- [x] Implement the comparison: empty/absent field on the file → `WARN` + degrade to mtime-only;
      mismatch → `recovered=false` with a named reason token (mirror the existing reason-token
      convention already in that script); match → proceed. *(completed)*
- [x] Create `scripts/tests/test-orchestrate-recover-outcome.sh` covering: no-arg backward
      compatibility, absent-field degradation, match, mismatch, and the git-restored shape
      (fresh in-window mtime + predecessor `dispatch_seq`). *(completed)*
- [x] Register the new test in `manifest.json`'s scripts list. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: three core agent contracts are asserted to be the complete set of
`/orchestrate`-dispatched `.return-meta.json` writers for core task types. Confirm at implementation
time with `grep -rl 'return-meta\.json' agent-system/extensions/*/agents/` and reconcile against
`lint-agent-contracts.sh`'s own agent enumeration before treating the list as closed; widen the
edit if the grep names more.

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new `dispatch_seq` field spec
- `agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md` - field in the copyable template
- `agent-system/extensions/core/agents/*.md` (the three named above) - echo the field
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` - optional 3rd arg + comparison
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` - new suite
- `agent-system/extensions/core/manifest.json` - register the new test

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` passes.
- Existing 2-arg call sites still pass: `bash .../tests/test-orchestrate-cycle-plan.sh` and any
  suite touching `orchestrate-stage5-gates.sh` stay green.
- `bash .claude/scripts/lint-agent-contracts.sh` (or its source-store equivalent) reports no new
  failures.

---

### Phase 2: Script skeleton, CLI, and the two handoff gates (WORK a) [COMPLETED]

**Goal**: `orchestrate-cycle-postflight.sh` exists, parses its flags per the sibling convention, and
performs the guarded handoff read — both gates, both engines, one implementation.

**Tasks**:
- [x] Create `scripts/orchestrate-cycle-postflight.sh` with a header stating purpose, the
      two-engine contract, the MUST-NOT list (no prose reads, no batch commits, no gate weakening,
      never asks, state.json only via `update-task-status.sh` / `state-write.sh`), and the output
      JSON field list. *(completed)*
- [x] Copy `orchestrate-cycle-plan.sh`'s flag parser verbatim in shape: `while [ "$#" -gt 0 ]` case
      loop, `usage()` heredoc, `--help`, required `--session` / `--state-file` validation. *(completed)*
- [x] Accept: `<task_number>` positional; `--session`, `--state-file`, `--phase`, `--task-dir`,
      `--plan-path`, `--task-type`, `--agent`, `--cycle-count`, `--transport-error`,
      `--force-invoked`, `--loop-guard-file` (single-task engine; when omitted the defect/infra
      store is the derived multi-state file), `--dry-run`. *(deviation: altered — added --dispatch-seq/--dispatch-start-ts/--command-suffix flags, absent from this literal enumeration, because neither single-task engine persists a per-cycle dispatch_seq/dispatch_start_ts anywhere for this script to derive them from; see the script's own header for the full rationale and the graceful-degradation fallback)*
- [x] Derive the multi-state path exactly as the sibling does:
      `"$(dirname "$STATE_FILE")/.orchestrator-multi-state-${session_id}.json"`. *(completed)*
- [x] Implement the mtime staleness gate: `stat -c %Y || stat -f %m || echo 0` against
      `dispatch_start_ts[$t]` with the literal `9999999999` fail-closed default; older → mark stale. *(completed)*
- [x] Implement the `dispatch_seq` identity gate: read `.dispatch_seq` off the handoff; empty →
      `WARN` and degrade to mtime-only; mismatch against `dispatch_seq[$t]` → mark stale. Same
      `HANDOFF_STALE_OR_ABSENT` defect class for both, with the two distinct detecting-site
      suffixes (`:stale-handoff`, `:dispatch-seq-mismatch`) preserved. *(deviation: altered — detecting-site suffixes are `:cycle-postflight-stale-handoff` / `:cycle-postflight-dispatch-seq-mismatch` rather than the single-task engine's own `:stale-handoff`/`:dispatch-seq-mismatch`, to keep this script's own detecting sites distinguishable from SKILL.md's still-live inline gates until Phase 7's cutover removes them)*
- [x] Route defect recording through `system-defect-record.sh` plus
      `skill_orchestrate_append_detected_defect` against the resolved defect store (loop guard or
      multi-state file — both carry `.detected_defects` with the same entry shape). *(completed)*
- [x] Emit a provisional output JSON line so the script is runnable end-to-end from this phase on. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - new file

**Verification**:
- `bash -n` clean; `shellcheck` (or the repo's shell lint) clean.
- `--help` prints usage; missing `--session`/`--state-file` exits with the sibling's error shape.
- Hand-run against a scratch fixture directory: a stale-mtime handoff and a seq-mismatched handoff
  each mark stale and append one `detected_defects` entry.
- `grep -c 9999999999` confirms the sentinel is the same literal used by the two precedent scripts.

---

### Phase 3: Recovery, corroboration, and writer-contract-aware recording (WORK b, c, d) [COMPLETED]

**Goal**: A stale or absent handoff routes into the existing return-meta recovery path — now
seq-checked — and defect recording respects the per-dispatch writer contract.

**Tasks**:
- [x] Call `orchestrate-recover-outcome.sh` with `<task_dir> <window_start_ts>
      <expected_dispatch_seq>` whenever the handoff is missing or gated stale; populate
      `dispatch_status`, `phases_completed`, `phases_total`, `plan_markers_verified="absent"`, and
      artifact path/type/summary from its JSON. *(completed)*
- [x] Port the evidence-corroboration arms unchanged: `PHASES_ZERO_ON_SUCCESS` calling
      `skill_corroborate_phase_counts` (count-only greps, unchanged bounds), and the sibling
      `ARTIFACTS_SHAPE_MISMATCH` arm's non-fatal recorder call. *(completed)*
- [x] Implement D1's writer-contract resolution: read this cycle's recorded agent name for this
      task, test against the single-site contractual-writer allowlist, and consult it **before**
      recording `HANDOFF_STALE_OR_ABSENT` for an *absent* handoff. *(completed)*
- [x] Unknown agent name → treat as non-writer AND emit the loud named `WARN` required by D1. *(completed)*
- [x] Keep the present-but-stale / present-but-mismatched recordings unconditional — the writer
      contract never suppresses those. *(completed)*
- [x] Port the non-recovered branch: infra-failure discrimination (two corroborating signals) and
      the sanctioned phase-marker recovery grep, diagnostic only. *(completed)*
- [x] Record D1's chosen mechanism in `docs/architecture/handoff-schema.md`, immediately after the
      existing "Handoff Writers" table, as the one place a future writer registers. *(completed)*

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - recovery, corroboration, writer-contract block
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - record the resolution mechanism

**Verification**:
- Scratch-fixture run: absent handoff + base-mode agent → recovery succeeds, zero
  `detected_defects` appended.
- Scratch-fixture run: absent handoff + an allowlisted hard-mode writer → one defect appended.
- Scratch-fixture run: present handoff with mismatched `dispatch_seq` → defect appended regardless
  of agent name.
- Unknown agent name emits the WARN and appends nothing.

---

### Phase 4: Status transition, artifact link, round advance, excursion advisory (WORK f, g, h) [COMPLETED]

**Goal**: The script performs the state transitions and artifact bookkeeping the two precedent
postflight paths perform, plus the multi-task artifact-round advance that has no current mechanism,
plus the advisory excursion check.

**Tasks**:
- [x] Port the `researched|planned|implemented|partial|failed|blocked|*` case ladder, including the
      `skill_gate_completion_claim` gate on `implemented` (allow → `skill_postflight_update ...
      implemented "warn"`; refuse → no transition, task stays `implementing`, and the
      `META_MISSING_AFTER_NARRATION` caller-side discriminant still appends). *(completed)*
- [x] Transition via `update-task-status.sh` with the monotonic-max clamp threaded from
      `--force-invoked`, so a forced earlier phase never regresses status. *(completed)*
- [x] Port `skill_propagate_completion_summary` on an allowed `implemented`, reusing this task's own
      recovery JSON when present rather than re-reading. *(completed)*
- [x] Artifact link via `skill_link_artifacts` (same-type supersession, append-only otherwise). *(completed)*
- [x] Artifact-round advance via `state-write.sh`: unconditional on `researched`, and additionally
      on a **forced** `planned`/`implemented` — closing the multi-task gap. Verify the call graph
      first: the single-task advance lives in `orchestrate-stage5-postflight.sh`, **not**
      `orchestrator-postflight.sh`, which `/orchestrate` never calls. *(completed)*
- [x] Excursion advisory: read `modified_files[]` from this task's `.return-meta.json`, read
      `file_scope[]` from `state.json`, log every path outside the declared scope. Detection only —
      it must not influence exit code, `verdict`, or any transition. *(completed)*
- [x] Off-schema `dispatch_status` (including `null`, empty, `in_progress`): emit the existing
      banner, record `OFF_SCHEMA_STATUS`, perform no transition, and surface it through `verdict`. *(completed: banner/record/no-transition land in Phase 4; the `offschema_dispatch_status` field is exposed for Phase 5's own verdict-mapping task to consume, per the plan's own phase split)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the artifact-round advance is asserted to have exactly one live site
(`orchestrate-stage5-postflight.sh`) and `orchestrator-postflight.sh` is asserted to have zero
`/orchestrate` call sites. Confirm both at implementation time with
`grep -rn 'orchestrator-postflight.sh\|next_artifact_number' agent-system/extensions/core/` before
adding the new advance, so this does not become a second double-incrementing site.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - transition, link, advance, excursion

**Verification**:
- Fixture run per status value confirms the correct transition or correct no-op.
- A forced `planned` advances `next_artifact_number`; an unforced `planned` does not.
- A `modified_files` entry outside `file_scope` logs the advisory and changes neither exit code nor
  verdict.

---

### Phase 5: `user_decision` relay, commit, multi-state update, lock release, output (WORK e, i, j) [COMPLETED]

**Goal**: The script's tail — relay, commit, state, lock — and the single JSON line contract are
complete, so the script is callable as one unit.

**Tasks**:
- [x] `user_decision` relay: when `.return-meta.json` or the handoff carries `user_decision`, emit
      `verdict: "ask_user"` with the payload **relayed verbatim** (never re-derived or rephrased)
      and leave `status` exactly as the agent left it. The script never asks and never writes
      `.decisions.json`. *(completed)*
- [x] Per-task scoped commit via `git-commit-scoped.sh --message ... --session ...
      --honest-index-rows ... -- "${stage_paths[@]}"`, with the staging set built from `task_dir/`,
      `specs/TODO.md`, `specs/state.json`, the plan path on implement dispatches, and every
      `modified_files[]` entry. Never a batch commit. *(completed)*
- [x] Emit the canonical zero-`modified_files` fail-safe warning verbatim (the only sanctioned
      wording — do not invent a second). *(completed)*
- [x] Commit-message selection keyed off `dispatch_status` and the post-gate `fresh_status`, per the
      Standard Actions table in `rules/git-workflow.md`; every branch, including off-schema, assigns
      a message so none falls through unassigned. *(completed)*
- [x] Commit failure is non-blocking: log and continue to the lock release, which must never be
      withheld. *(completed)*
- [x] Multi-state update: `current_statuses`, `completed_tasks`, `failed_tasks`, and accumulate this
      task's `modified_files` into `cycle_modified_files` (accumulated here, not re-read later,
      because postflight cleanup may remove the `.return-meta.json`). *(completed: scoped to the multi-task engine only — single-task callers, identified by a non-empty --loop-guard-file, have no current_statuses/completed_tasks/failed_tasks bookkeeping at all, since there is inherently only one task in single-task mode; see the script's own WORK (j) comment)*
- [x] Unconditional per-task lock release: `task-lock.sh release "$task_num" "$session_id"` with the
      **bare** session_id, matching the acquire invariant. *(completed: scoped to the multi-task engine only — single-task mode holds its task lock across the WHOLE invocation, released once at the outer command-gate-out.sh boundary this per-cycle script does not own; see the script's own WORK (j) comment)*
- [x] Assemble and print the single compact JSON line:
      `{task, phase, status, phases_completed, phases_total, verdict, user_decision?, note}` with
      `verdict` ∈ `ok|defer|blocked|failed|ask_user`. *(completed)*
- [x] Honour `--dry-run`: identical decision output, zero side effects (no commit, no state write,
      no lock release, no defect recording). *(completed)*

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - relay, commit, state, lock, output
- `agent-system/extensions/core/manifest.json` - register the new script

**Verification**:
- `jq -e .` accepts the stdout of every branch; stdout is exactly one line in every mode.
- A fixture `user_decision` round-trips byte-identically into the output.
- `--dry-run` against a fixture leaves `git status`, the state file, and the lock directory
  unchanged.

---

### Phase 6: Fixture regression suite [COMPLETED]

**Goal**: `test-orchestrate-cycle-postflight.sh` proves all five acceptance conditions against
fixtures modelled on the two live incidents and the spurious-defect case.

**Tasks**:
- [x] Create `scripts/tests/test-orchestrate-cycle-postflight.sh` using
      `test-orchestrate-cycle-plan.sh`'s sandbox model (copy real collaborators into a synthetic
      `$WORKDIR/.claude/scripts/` tree; stub only collaborators whose own behavior is out of scope). *(completed)*
- [x] Acceptance (1): a handoff whose mtime predates the dispatch window routes to recovery rather
      than being trusted. *(completed)*
- [x] Acceptance (2): a handoff whose `dispatch_seq` does not match the minted value routes to
      recovery — including the incident shape where the mtime is *newer* than the window and the
      mtime gate alone would pass it. *(completed)*
- [x] Acceptance (3): a git-restored predecessor `.return-meta.json` (fresh in-window mtime,
      predecessor `dispatch_seq`) is rejected by recovery. *(completed)*
- [x] Acceptance (4): both directions — a contractual non-writer with no handoff records **no**
      defect; a genuine seq-mismatched late write still records one. *(completed)*
- [x] Acceptance (5): a `user_decision` payload is relayed intact with status unchanged. *(completed)*
- [x] Invariant assertions: the `9999999999` sentinel is literal and shared; the excursion check
      never changes exit code or verdict; `--dry-run` mutates nothing. *(completed)*
- [x] Follow the suite naming discipline — fixture numbers are synthetic, described as
      "candidate #N"/"project #N", never "task N", per
      `rules/no-task-references-in-deliverables.md`. *(completed)*
- [x] Register the suite in `manifest.json` (`run-all.sh` discovers it automatically). *(completed)*

**Timing**: 2 hours

**Depends on**: 5

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: five acceptance conditions plus three invariants are asserted to be the
complete coverage bar, taken from the dispatch's ACCEPTANCE sentence. Confirm at implementation time
by re-reading `.dispatch/6.md`'s ACCEPTANCE line and mapping each clause to a named test case; add
cases if the mapping leaves a clause uncovered.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - new suite
- `agent-system/extensions/core/manifest.json` - register the suite

**Verification**:
- The suite exits 0 with every case reported PASS.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` discovers and runs it.

---

### Phase 7: Both-engine cutover, prose relocation, full gate run [NOT STARTED]

**Goal**: Both engines call the script, the replaced prose leaves `SKILL.md` for
`docs/architecture/`, and the acceptance bar's live-run and byte-count obligations are met.

**Tasks**:
- [ ] Replace Stage MT-4's per-task postflight steps 1-6 with one call to the new script per
      dispatched task, consuming its JSON line.
- [ ] Replace single-task Stage 5's gate pair, gates call, and postflight tail with the same call,
      preserving the caller-side application of loop-control state (`halt` / `cycle_count` /
      `EXIT (partial)`), which stays in `SKILL.md` by the precedent scripts' own boundary rule.
- [ ] Retarget `test-handoff-dispatch-identity.sh` at the script's gate — it currently extracts and
      `eval`s the `dispatch-seq-gate:begin`/`:end` sentinel region — and remove that region from
      `SKILL.md` **in the same atomic batch**.
- [ ] Relocate the replaced narrative prose to `docs/architecture/` (alongside
      `orchestrate-state-machine.md` / `handoff-schema.md`), leaving `SKILL.md` with the call and a
      pointer, never a duplicate of the script's contract.
- [ ] Measure and report bytes removed from `SKILL.md` (`wc -c` before/after, recorded in the
      implementation summary).
- [ ] Run a live multi-task `/orchestrate` cycle through the script and record the outcome.
- [ ] Run the full gate set.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: full

**Commit Mode**: atomic-batch

**Scope Hypothesis**: the declared atomic batch is exactly
`skill-orchestrate/SKILL.md` + `scripts/tests/test-handoff-dispatch-identity.sh` (+ the relocated
`docs/architecture/` file), and the byte-removal figure is asserted only as "measured", not as a
pre-committed number. Confirm the batch's file set at implementation time with
`grep -rn 'dispatch-seq-gate:begin' agent-system/extensions/` before staging; if a third file
references the sentinel, it joins the batch rather than being committed separately.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - both engines call the script; sentinel region and replaced prose removed
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - retargeted at the script
- `agent-system/extensions/core/docs/architecture/` - relocated prose

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` fully green, including the retargeted
  identity suite.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` green.
- A live multi-task cycle completes with per-task JSON lines and per-task scoped commits.
- `grep -c 'dispatch-seq-gate' skill-orchestrate/SKILL.md` returns 0; bytes removed reported.

---

## Testing & Validation

- [x] `test-orchestrate-recover-outcome.sh` — new suite, all cases pass (Phase 1). *(completed)*
- [x] `test-orchestrate-cycle-postflight.sh` — acceptance (1)-(5) plus the three invariants (Phase 6). *(completed: 21/21 assertions pass)*
- [ ] `test-handoff-dispatch-identity.sh` — retargeted and green (Phase 7).
- [ ] `scripts/tests/run-all.sh` — every suite in every extension green.
- [ ] `scripts/verify-deploy.sh` — full gate run green.
- [ ] `lint-agent-contracts.sh` — no new failures after the `dispatch_seq` contract edit.
- [ ] Live multi-task `/orchestrate` cycle driven through the new script, per-task scoped commits
      observed (never a batch commit).
- [ ] Bytes removed from `SKILL.md` measured and reported.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-outcome.sh` (new)
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (modified)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified, net shrink)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (modified) plus the relocated
  postflight narrative under `docs/architecture/`
- `agent-system/extensions/core/manifest.json` (modified — script and two test registrations)
- `specs/143_mt_handoff_staleness_and_dispatch_seq_gates/summaries/01_*-summary.md`

**Files beyond the declared `file_scope`** (the excursion this plan knowingly requires, named here
so it is not discovered at commit time): `context/formats/return-metadata-file.md`,
`context/contracts/return-meta-artifacts-template.md`, the three core agent contract files under
`agents/`, `scripts/tests/test-orchestrate-cycle-postflight.sh`, and
`scripts/tests/test-handoff-dispatch-identity.sh`. All follow from Decision D2 and Phase 7's atomic
batch. The implementer should report them in `modified_files` as normal; `file_scope` is
descriptive, not enforcing.

## Rollback/Contingency

Phases 1-6 are additive: the new script has no caller until Phase 7, and
`orchestrate-recover-outcome.sh`'s new argument is optional and appended, so every existing call
site is unaffected. Reverting any of those phases is a plain `git revert` of that phase's commits
with no behavioral exposure.

Phase 7 is the only phase that changes live behavior. Its `atomic-batch` commit mode means the
cutover lands as one revertible unit: reverting it restores both engines' inline gates, the sentinel
region, and the original `test-handoff-dispatch-identity.sh` target together, leaving the new script
in the tree but uncalled. If the live multi-task run surfaces a defect after the batch has landed,
revert the batch first and re-run the fixture suite against the reproduced shape before re-cutting
over — never patch forward on a live engine with a red suite.
