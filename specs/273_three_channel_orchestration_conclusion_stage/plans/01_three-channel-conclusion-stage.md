# Implementation Plan: Task #273

- **Task**: 273 - Three-channel orchestration conclusion stage with per-channel approval, as a
  distinct post-postflight stage
- **Status**: [IMPLEMENTING]
- **Effort**: 16 hours
- **Dependencies**: 271 (completed), 184 (archived/satisfied), 329 (archived/satisfied),
  306 (completed) — none blocking
- **Research Inputs**: specs/273_three_channel_orchestration_conclusion_stage/reports/01_three-channel-conclusion-stage.md
- **Artifacts**: plans/01_three-channel-conclusion-stage.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md, git-staging-scope.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This plan builds a new **Move 5 conclusion stage** for `/orchestrate`: once per invocation, after
Move 4 has emitted the consolidated output and closed batch state, the stage aggregates the
per-task `issues.jsonl` logs of every touched task, classifies each open/worked-around entry into
exactly one of three channels, presents each channel as an evidence-citing proposal behind its
own independent approval gate, and executes only the channels the user approved — then commits
its own output through four separately-scoped `git-commit-scoped.sh` invocations.

The executable stage body and the derivation contract both land in one new file,
`context/contracts/conclusion-stage.md`, with `skills/skill-orchestrate/SKILL.md` carrying only a
short Move 5 pointer stanza. This mirrors the existing `context/patterns/lit-stage4a-flow.md`
single-executable-block precedent and — measured, not assumed — keeps the stage's legitimately
Edit-and-build-capable body out of the region `verify-deploy.sh`'s gate 9
(`scripts/lint/lint-postflight-boundary.sh`) scans for postflight violations.

Mechanical work (filtering, cross-task class grouping, win separation, unknown-class tallying,
citation assembly, and the per-channel approval ledger) goes into one new script,
`scripts/orchestrate-conclusion-aggregate.sh`, which makes the load-bearing acceptance claim —
that no channel can fire on another's approval — mechanically testable rather than prose-only.
Judgment work (classifying an entry into exactly one channel, visibly overriding a
`suggested_channel` hint) stays with the orchestrator lead, where it belongs.

### Research Integration

The research report settled four things this plan carries forward without re-litigating:

1. **The 184 reconciliation verdict is RESOLUTION B (scope-limited coexistence)**, with
   Resolution A's rationale recorded. 184's "do NOT auto-create tasks" clause shares one
   antecedent with its two sibling clauses ("In `orchestrate-cycle-postflight.sh`, when the final
   implement handoff carries `skeleton=true` and a non-empty `sorry_inventory[]`"), and its
   delivered implementation, plus its standing documentation in `status-markers.md`'s
   `[COMPLETED]` section, confirm that narrow scope. Nothing in 184 is overturned, nothing in
   184's archived artifacts is edited, and this plan's deliverables state the coexistence boundary
   using durable anchors only.
2. **`issues.jsonl` / `issue-record.sh` is the correct and sole payload carrier** of the four
   named existing channels. `metadata.detected_defects` and the "System Defects Detected" table
   are rejected as a *general-contribution* carrier — structurally engine-written only, never
   subagent-written, with an accumulate-then-render contract incompatible with gated proposals.
   They stay exactly as they are, rendering unconditionally and independently.
3. **Addition 2's "measured complication" is stale** and this plan re-verified that at authoring
   time: the live `agent-system/extensions/core/scripts/roadmap-integration.sh` exists (690
   lines) alongside the quarantined `scripts/deprecated/roadmap-integration.sh` (944 lines). The
   roadmap update consumes the live script; `file_scope` is corrected in Phase 1.
4. **Move 5, once per invocation, after Move 4's full finalization sequence**, is the right
   placement — never inside `orchestrate-cycle-postflight.sh`, never interleaved with per-task
   Move 3.

Three research items were explicitly left to planning and are decided here (see Decisions).

### Prior Plan Reference

No prior plan. This is round 1 for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no ROADMAP.md was
consulted and no roadmap review/update phases are added to this plan. (Distinct from the
*subject matter* of Phase 7's roadmap-update step, which is a feature this task builds, not a
planning-time roadmap consultation.)

## Decisions

Recorded here so the implementer does not re-open them, and so a future reader sees the
reasoning rather than only the outcome.

- **D1 — The stage body lives in `context/contracts/conclusion-stage.md`, not inline in
  SKILL.md.** `scripts/lint/lint-postflight-boundary.sh` (verify-deploy.sh gate 9) scans skill
  `SKILL.md` content appearing after a postflight section for Edit-on-source, build-command, and
  MCP patterns. Move 5 legitimately performs exactly those operations and sits textually after
  Move 3 (Postflight). Siting the body in a pointed-to contract file follows the established
  `lit-stage4a-flow.md` pattern and avoids manufacturing a lint exemption. Contingency if the
  lint still flags the pointer stanza: see Risks R2.
- **D2 — The approval gate is backed by a durable, per-channel ledger**, written and read by
  `orchestrate-conclusion-aggregate.sh` (`--record-approval` / `--check-approval`), one record
  per channel per invocation. Without this the "no channel fires on another's approval"
  acceptance criterion could only be asserted in prose; with it, Phase 4's suite proves it.
  Each channel's execution step reads *only its own* channel's ledger record, and an absent
  record reads as not-approved (fail-closed — the one place in this task where a guard defect
  must block rather than fail open).
- **D3 — The roadmap update invokes `--regenerate` only; `--prune` is out of scope.**
  `--regenerate` is idempotent and retention-aware, so it is safe unattended; `--prune` removes
  content outright, which is a stronger unattended action than this stage should take without
  its own approval. Recorded as a deliberate choice per the research report's Risk flag, not a
  default. `--prune` at conclusion is a candidate follow-up, not silently dropped.
- **D4 — The mandatory-contribution enforcement is contract wording plus a conclusion-time
  visibility report, not a blocking gate.** The issue-log contract states that recording is
  *always* non-fatal; a blocking presence gate would contradict it directly. Instead: an explicit
  MUST in the two shared dispatch contracts and in the dispatch file's own generated "## Issue
  Log" section (which already reaches every dispatch kind — research, plan, implement, and aux —
  making it the answer to "which existing carrier"), an optional
  `metadata.issue_log_contribution` attestation on `.return-meta.json`, and a
  "dispatches that contributed nothing" line in the aggregator's own report so the gap is
  visible at exactly the moment someone can act on it.
- **D5 — `scripts/orchestrate-cycle-postflight.sh` is NOT edited by this task**, although it
  stays declared in `file_scope`. Nothing in this design needs a per-task-postflight change, and
  that file carries pre-existing collisions with three other open tasks. The declaration is kept
  (not removed) so that if implementation discovers a genuinely required small edit, the
  containment self-check does not drop it from a commit.
- **D6 — Channel (a) reuses `general-implementation-agent` with a purpose-built dispatch body**
  rather than defining a new agent. Research found no precedent for a "final cleanup agent" and
  no behavior that agent lacks; a new agent type would duplicate its `source-store-deploy-boundary`
  and scope-excursion conventions for no gain. The novelty is the dispatch body (a synthesized,
  cross-task, user-approved fix list), not the agent.

## Goals & Non-Goals

**Goals**:
- A Move 5 conclusion stage that runs once per `/orchestrate` invocation, strictly after Move 4.
- Three channels — (a) direct fixes, (b) agent-system changes via `meta-builder-agent`,
  (c) follow-up tasks as children via `parent_task` — each firing only on its own explicit
  approval, mechanically proven.
- Every proposal derived from aggregated `issues.jsonl` entries and citing them (task number plus
  `entry_id`); recurring classes grouped across tasks into one proposal; `kind: "win"` entries
  summarised and never actioned.
- Upstream contribution made mandatory for every dispatch kind, through the existing carrier.
- A roadmap update at conclusion that invokes the existing generator's `--regenerate` mode.
- A new allowed/prohibited table in `postflight-tool-restrictions.md` covering both the stage's
  tool surface and its per-channel commit surface.
- The stage's own output committed via four separately-scoped `git-commit-scoped.sh` invocations.

**Non-Goals**:
- Editing `scripts/git-commit-scoped.sh` (task 304's territory — this task writes the contract
  and invokes the script).
- Editing `context/patterns/roadmap-update.md` or any other roadmap-generation artifact (task
  306's territory — the third-caller reconciliation is *flagged* for the user, never silently
  edited).
- Editing task 184's archived artifacts or `status-markers.md`'s skeleton-plan terminus paragraph
  (Resolution B leaves both exactly as written).
- Wiring `/todo` to `--prune` or `/review` to `--regenerate` (a pre-existing, independently
  recorded gap in the roadmap generator's own caller contract).
- Any mid-run surface for the issue log. The capture-only boundary is preserved; review happens
  only at this stage.
- Merging `detected_defects` / "System Defects Detected" into the new stage.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `lint-postflight-boundary.sh` (verify-deploy gate 9) flags the new Move 5 content in SKILL.md | M | M | D1 sites the body in a pointed-to contract file. If the pointer stanza still trips it, add `scripts/lint/lint-postflight-boundary.sh` to `file_scope` and register a named, documented exemption — never weaken the lint's general predicate. Recorded in `issues.jsonl` at plan time. |
| New scripts silently fail to deploy because `manifest.json`'s `provides.scripts` is file-granular | H | H if unaddressed | Phase 1 adds `manifest.json` to `file_scope`; Phase 4 registers both new scripts and verifies via a deploy + deployed-path existence check. |
| An undeclared path is silently dropped from a phase commit (the implementation agent's commit recipe drops out-of-scope paths with a warning) | H | H if unaddressed | Phase 1 corrects and widens `file_scope` *before* any other phase, and re-measures overlap with `scripts/lib/file-scope-overlap.sh`. |
| Concurrent sibling tasks (295, 296, 368 this cycle; 272/274/275/299/350/284/304/335 pre-existing on the orchestrator surfaces) touch the same files | M | M | Re-read every target file immediately before editing; stage explicit file lists only, never a directory or glob pathspec; pass `--task 273` to `git-commit-scoped.sh` so the contended-path lease applies. |
| The new scripts cannot be exercised from the source store (`deploy-root-guard.sh` refuses) | M | H | Every phase whose verification runs a script states the `bash .claude/scripts/deploy-headless.sh` step first and exercises the deployed `.claude/scripts/` copy, exactly as `test-issue-record.sh` already does. |
| Task-number references leak into deliverables outside `specs/**` (the 184/306/304 reconciliations are naturally phrased with task numbers) | M | H | Every phase that writes prose names durable anchors only — file paths, section headings, mechanism names. Phase 9's gate runs `check-task-references.sh`. The `task-ref-ok` marker is used only where a category genuinely applies, never to paper over a lazy reference. |
| The three approval gates drift into one combined question during implementation | H | L | The gates are batched into one relay *call set* (the existing Move 4 convention) but are three separate questions with three separate ledger records; Phase 4's suite fails if one answer marks another channel approved. |
| Channel (b)'s anti-bypass constraint is weakened while wiring the dispatch | H | L | Phase 9's fixture asserts `meta-builder-agent.md`'s FORBIDDEN list is unchanged and that the channel (b) step restates "creates TASKS, never implementation". |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5, 6 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 7 | 3 (P4); 2, 3, 6 (P7) |
| 5 | 8 | 2, 7 |
| 6 | 9 | 4, 5, 7, 8 |

Phases within the same wave can execute in parallel; their file sets are disjoint by
construction.

---

### Phase 1: Correct and widen `file_scope`; confirm deploy granularity [COMPLETED]

**Goal**: Make every file this plan touches declared before any edit happens, so no later phase's
commit silently drops a path, and re-measure the overlap picture the task description recorded.

**Tasks**:
- [x] Re-read the current `file_scope` for task 273 from `specs/state.json` (10 entries). *(completed: actually found 21 entries already present — a prior /task amendment had already applied the 9 planned additions; only the deprecated->live roadmap path swap remained)*
- [x] Replace `agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh` with
      `agent-system/extensions/core/scripts/roadmap-integration.sh` (the live path; the
      deprecated copy is quarantined and irrelevant — see Research Integration item 3). *(completed)*
- [x] Add: `agent-system/extensions/core/manifest.json`,
      `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`,
      `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh`,
      `agent-system/extensions/core/context/contracts/conclusion-stage.md`,
      `agent-system/extensions/core/context/contracts/phase-closure.md`,
      `agent-system/extensions/core/context/contracts/wrap-up.md`,
      `agent-system/extensions/core/context/formats/issue-log.md`,
      `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
      `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`.
      *(completed: all nine were already present in state.json's file_scope before this dispatch)*
- [x] Write the change via `bash .claude/scripts/state-write.sh` only — never a direct Edit of
      `specs/state.json`, and never a wholesale `.artifacts = [...]` style assignment. *(completed)*
- [x] Determine whether `manifest.json`'s `provides.context` is directory-granular or
      file-granular; if file-granular, the new `context/contracts/conclusion-stage.md` needs a
      registration entry too (handled in Phase 4 alongside the scripts). *(completed: directory-granular — `provides.context` lists bare directory names such as "contracts", so no per-file registration entry is needed for `conclusion-stage.md`; Phase 4 drops that sub-step)*
- [x] Re-run `bash .claude/scripts/lib/file-scope-overlap.sh` (or its own documented entry point)
      against the widened scope and record the resulting collision set. *(completed: sourced the
      lib and ran `scopes_overlap` against every other open task's declared file_scope. Collision
      set — task 272 (commands/orchestrate.md); 274, 275 (skills/skill-orchestrate/SKILL.md);
      280, 281, 282, 306, 313, 347, 355, 366 (manifest.json); 284, 335, 350
      (scripts/orchestrate-cycle-postflight.sh); 299 (scripts/orchestrate-build-dispatch.sh); 304
      (context/formats/return-metadata-file.md); 351, 354
      (docs/architecture/orchestrate-state-machine.md); 368 (context/contracts/phase-closure.md).
      This is wider than the task description's own 2026-10-07 snapshot (which named only the
      304/return-metadata-file.md collision as new), reflecting tasks filed since that snapshot.
      None of these require a new dependency edge per the task description's standing convention
      (manifest.json and the other shared orchestrator-surface files are registration points with
      many legitimate concurrent declarers; `git-commit-scoped.sh --task 273`'s contended-path
      lease is the live-concurrency guard, not a static file_scope edge). Recorded here for Phase
      9's citation.)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the declared `file_scope` currently holds exactly 10
entries and grows to 19 after one replacement and nine additions. Confirm at implementation time
with `jq '.active_projects[] | select(.project_number==273) | .file_scope | length'
specs/state.json` before and after. A second carried figure — the live
`scripts/roadmap-integration.sh` at 690 lines versus the deprecated copy at 944, sourced from
this plan's own authoring-time measurement rather than from the task description's stale
2026-10-07 note — is confirmed by `wc -l` on both paths. If the live script is absent at
implementation time, STOP and report rather than falling back to the deprecated path.

**Files to modify**:
- `specs/state.json` - correct and widen task 273's `file_scope` via `state-write.sh`

**Verification**:
- `jq` read-back shows 19 entries, the deprecated roadmap path absent and the live one present.
- `bash .claude/scripts/generate-todo.sh` run afterwards; `git status --short` shows only
  `specs/state.json` and `specs/TODO.md` modified by this phase.
- The overlap re-measurement output is captured in the phase's commit message or progress notes
  so Phase 9 can cite it.

---

### Phase 2: The derivation contract (`context/contracts/conclusion-stage.md`) [COMPLETED]

**Goal**: Write the new contract file's *derivation* half — where the stage's content comes from,
how entries are classified, and what the coexistence boundary with the skeleton-plan follow-up
mechanism is. The executable stage body is added to the same file in Phase 7.

**Tasks**:
- [x] Create `context/contracts/conclusion-stage.md` with an Overview stating the stage runs once
      per `/orchestrate` invocation, strictly after the batch's own state is closed and committed.
- [x] Write the **evidence base** section: the per-task `specs/{NNN}_{SLUG}/issues.jsonl` logs of
      every task the invocation touched are the sole payload source. State that
      `metadata.detected_defects` and the "System Defects Detected" table are a separate,
      unconditional, ungated observation channel that is never merged into or subsumed by this
      stage, and name the structural reason (engine-written only, never subagent-written).
- [x] Write the **filter predicate**: entries whose `resolution` is `open` or `worked_around`
      enter classification; `kind: "win"` entries are summarised in the report and generate no
      channel item; `resolution: "fixed_inline"` entries are already closed.
- [x] Write the **exactly-one-channel rule**: every classified entry lands in exactly one of
      (a) fix-now, (b) agent-system change, (c) follow-up task. An entry may not appear in two
      channels.
- [x] Write the **hint-versus-decision rule**: `suggested_channel` is a hint; the orchestrator's
      judgment is the decision; an overridden hint is overridden visibly, naming both the hint and
      the chosen channel.
- [x] Write the **cross-task grouping rule**: recurring classes across tasks become one proposal
      citing every contributing entry, never one proposal per task. State that this recurrence is
      the reason the derivation is worth doing at all, being invisible from any single task.
- [x] Write the **citation requirement**: each proposal cites its entries as task number plus
      `entry_id`. A proposal with no citation is not presentable.
- [x] Write the **unknown-class tally** section, discharging the consumer obligation
      `context/formats/issue-log.md` already records as this stage's job.
- [x] Write the **review-only-at-this-stage** section as the explicit complement of the issue
      log's capture-only boundary, including the instruction that a mid-run surface, if ever
      added, is added by amending this contract rather than improvised in a writer.
- [x] Write the **coexistence boundary** section recording the Resolution B verdict *using
      durable anchors only*: the skeleton-plan strategic-sorry follow-up mechanism in
      `scripts/orchestrate-cycle-postflight.sh`'s `implemented)` case, documented in
      `context/standards/status-markers.md`'s `[COMPLETED]` section, governs one trigger
      (`skeleton == true` plus a non-empty `sorry_inventory[]`), one detecting site, and one
      payload shape, and is unchanged by this stage. This stage is task-type-agnostic, fires once
      per invocation, derives from the aggregated issue logs, and gates creation behind explicit
      per-channel approval. Record that the losing alternative — a narrow overturn of that
      mechanism's "the human files any follow-up" clause — was rejected because the two
      mechanisms are disjoint rather than contradictory, and because both readings reach the same
      operational result while only one requires rewriting a narrowly-scoped, already-implemented
      and already-documented ruling. **No task numbers anywhere in this file.**
- [x] Add the two flags the research report requires be surfaced rather than silently fixed:
      (i) whether the roadmap generator's documented caller split needs a sentence naming
      `/orchestrate`'s conclusion stage as a caller — that file is another task's territory, so
      this is a flag, not an edit; (ii) the pre-existing, independently recorded gap that neither
      `/todo` nor `/review` wires either generator mode yet. Phrase both with durable anchors.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - new file (derivation
  half)
- `agent-system/extensions/core/context/formats/issue-log.md` - point its "Unknown-Class Tally —
  A Note for the Conclusion Stage" and "CAPTURE ONLY" sections at the now-existing contract file,
  replacing the "a separate, dedicated backlog item" phrasing with the real path

**Verification**:
- Diff read-through confirms every changed hunk is prose, with zero compile or elaboration
  surface.
- `bash .claude/scripts/check-task-references.sh` is clean for both files.
- Every path referenced in the new file resolves (`test -f` each).
- `grep -c 'detected_defects' context/contracts/conclusion-stage.md` is non-zero — the rejection
  rationale for the other carrier is present, as the acceptance criterion requires.

---

### Phase 3: The aggregator and approval-ledger script [NOT STARTED]

**Goal**: Build `scripts/orchestrate-conclusion-aggregate.sh` — the mechanical half of the stage:
aggregation, grouping, tallying, citation assembly, and the per-channel approval ledger.

**Tasks**:
- [ ] Create the script with `set -euo pipefail` per `context/standards/shell-strict-mode.md`,
      sourcing `lib/common.sh`, resolving `PROJECT_ROOT` via `common_repo_root`, and sourcing
      `deploy-root-guard.sh` so it refuses to run from the source store (same posture as
      `issue-record.sh`).
- [ ] Implement `--aggregate --session SID --tasks "N N N"`: for each task, resolve its directory
      via `lib/task-lookup-lib.sh`, read `issues.jsonl` if present, and emit one JSON document on
      stdout with: `proposals[]` grouped by `class` across tasks (each carrying
      `citations[] = [{task, entry_id}]`, `severity_max`, `suggested_channel_hints[]`),
      `wins[]` (summary-only), `unknown_classes[]` (classes outside the 15-class seed enum, with
      per-class counts across tasks), and `no_contribution_tasks[]` (touched tasks whose log is
      absent or empty).
- [ ] Filter to `resolution` in `{open, worked_around}` for `proposals[]`; route `kind: "win"` to
      `wins[]` regardless of resolution; exclude `fixed_inline` non-win entries.
- [ ] Implement `--record-approval --session SID --channel a|b|c --answer yes|no`: write one
      record per channel into a per-invocation ledger under `specs/.orchestration/`
      (`mkdir -p` first), each channel's record independent of the others'.
- [ ] Implement `--check-approval --session SID --channel a|b|c`: exit 0 only when *that*
      channel's own record says `yes`; exit non-zero for `no`, for an absent record, for a
      malformed ledger, and for any internal error. **Fail closed** — document inline that this
      is the one deliberate exception to this codebase's usual fail-open guard posture, and why.
- [ ] Implement `--help` emitting the header usage block (the `sed -n` pattern the sibling
      scripts use), and a documented exit-code table.
- [ ] Add a header comment naming `context/contracts/conclusion-stage.md` as the contract this
      script implements against, and stating that classification into channels is deliberately
      NOT done here (it is the lead's judgment).

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the 15-class seed enum used for the unknown-class tally
is exactly the table in `context/formats/issue-log.md`'s "Seed Class Enum" section, and that
`issue-record.sh` already carries a copy of that list for its own leniency warning. Confirm at
implementation time by diffing the two lists; if they differ, the script reads the format doc's
list and the discrepancy is recorded via `issue-record.sh` rather than silently picking one.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - new script

**Verification**:
- `shellcheck` clean on the new script, invoked directly with its **exit status checked** — not a
  stdout diff against a baseline. Measured at plan-authoring time: this repository provides no
  wrapper entry point for shellcheck (`context/standards/shell-strict-mode.md` does not name one,
  `verify-deploy.sh` has no shellcheck gate, and every in-repo occurrence is an inline
  `# shellcheck` directive), so the bare binary is the only available invocation. Confirm the
  binary actually resolved — a `command -v shellcheck` check first — so an unresolvable binary
  cannot exit as if it ran cleanly.
- `bash .claude/scripts/deploy-headless.sh`, then `bash .claude/scripts/orchestrate-conclusion-aggregate.sh --help`
  exits 0 and prints the usage block.
- A manual smoke run of `--aggregate` against this task's own `issues.jsonl` (4 entries at plan
  time) emits valid JSON — `jq . ` parses it — with at least one proposal carrying a
  `{task, entry_id}` citation.
- Running the script from `agent-system/extensions/core/scripts/` fails loudly (deploy-root-guard
  working as intended).

---

### Phase 4: Aggregator test suite and manifest registration [NOT STARTED]

**Goal**: Prove the load-bearing claims mechanically, and make both new scripts actually deploy.

**Tasks**:
- [ ] Create `scripts/tests/test-orchestrate-conclusion-aggregate.sh` modelled structurally on
      `scripts/tests/test-issue-record.sh`: `set -uo pipefail`, `pass()/fail()/info()` helpers,
      `PASSED`/`FAILED` counters, exit 0 all-pass / 1 any-fail / 2 environment error, and the same
      deploy-tree-first / source-store-fallback script resolution plus `mktemp -d` scratch project
      root with a scratch `specs/state.json` and real scratch task directories.
- [ ] Case: `resolution` filtering — an `open` entry and a `worked_around` entry appear in
      `proposals[]`; a `fixed_inline` non-win entry does not.
- [ ] Case: win separation — a `kind: "win"` entry appears in `wins[]` and in no proposal.
- [ ] Case: cross-task grouping — three scratch tasks each recording the same `class` produce
      exactly ONE proposal carrying THREE citations, not three proposals.
- [ ] Case: citation presence — every emitted proposal carries a non-empty `citations[]` with both
      a task number and an `entry_id`.
- [ ] Case: unknown-class tally — an entry with a class outside the seed enum is counted in
      `unknown_classes[]`.
- [ ] Case: `no_contribution_tasks[]` — a touched task with no `issues.jsonl`, and one with an
      empty file, both appear.
- [ ] **Case (acceptance-critical): per-channel approval isolation.** Record `yes` for channel (a)
      only; assert `--check-approval` exits 0 for (a) and non-zero for (b) and (c). Repeat for (b)
      and (c). Assert an unrecorded channel reads not-approved, a `no` reads not-approved, and a
      truncated/malformed ledger reads not-approved.
- [ ] Register both new scripts in `manifest.json`'s `provides.scripts`
      (`orchestrate-conclusion-aggregate.sh`, `tests/test-orchestrate-conclusion-aggregate.sh`),
      and register `context/contracts/conclusion-stage.md` in `provides.context` if Phase 1 found
      that array to be file-granular.
- [ ] Optionally add a `suite-cost-hints.txt` row for the new suite (advisory only).

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts `scripts/tests/run-all.sh` discovers suites by glob
(`scripts/tests/test-*.sh` in every extension plus the deployed tree) and therefore needs no
registry entry for the new suite, while `manifest.json`'s `provides.scripts` IS file-granular
(229 entries at plan time) and does. Confirm both at implementation time: grep `run-all.sh`'s
discovery loop, and `jq '.provides.scripts | length' manifest.json`. If `provides.scripts` turns
out to be directory-granular, drop the registration step and record why.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - new
  suite
- `agent-system/extensions/core/manifest.json` - register the new script and suite (and the new
  context file if required)
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - optional advisory row

**Verification**:
- `bash .claude/scripts/deploy-headless.sh`, then the deployed
  `.claude/scripts/orchestrate-conclusion-aggregate.sh` and
  `.claude/scripts/tests/test-orchestrate-conclusion-aggregate.sh` both exist (proving the
  manifest registration took effect).
- The new suite passes (exit 0) with every case above reported PASS.
- `bash .claude/scripts/tests/test-issue-record.sh` still passes (the carrier's own suite is
  untouched by this plan but must not regress).
- `shellcheck` clean on the new suite (bare binary with exit status checked and a preceding
  `command -v shellcheck` resolution check — see Phase 3's note on the absence of a repository
  wrapper).

---

### Phase 5: Make upstream contribution mandatory for every dispatch kind [NOT STARTED]

**Goal**: Turn issue-log contribution from encouragement into a stated requirement reaching
research, plan, implement and aux dispatches alike, through the existing carrier — no new channel
invented.

**Tasks**:
- [ ] `context/contracts/phase-closure.md`, "Record issues and wins during the phase" section:
      change "AS SOON AS an event worth recording happens" to an explicit MUST, state that this
      applies to **every** dispatch kind (research, plan, implement, aux), and add that a dispatch
      with genuinely nothing to record attests that rather than silently recording nothing.
      Preserve the existing "Non-fatal, always" paragraph verbatim — the mandate is on the
      *attempt*, never on the outcome.
- [ ] `context/contracts/wrap-up.md`: strengthen the existing `blockers[]` / `dead_ends` pairing
      into an explicit MUST at those write sites, citing the overwrite hazard already documented
      in `context/formats/issue-log.md`'s relation table.
- [ ] `scripts/orchestrate-build-dispatch.sh`, the generated "## Issue Log" dispatch-file section:
      strengthen its wording to mandatory, and record inline (in a shell comment) that this
      section is the chosen contribution carrier *because* it already reaches every dispatch kind
      — the recorded answer to "which of the existing carriers". Change only the emitted text and
      the comment; do not alter the section's placement or the non-fatal call form.
- [ ] `context/formats/return-metadata-file.md`: add a new `### issue_log_contribution (optional)`
      subsection under Field Specifications documenting a `metadata.issue_log_contribution`
      attestation — an integer count of entries this dispatch recorded, where `0` is a valid,
      meaningful value asserting "considered, nothing to record". State that it is advisory
      observability, never a gate, and cross-reference the MIRROR note already in the `errors`
      section.
- [ ] `scripts/issue-record.sh` header: note that contribution is now mandatory per
      `phase-closure.md`, and that the conclusion-stage consumer named in
      `context/formats/issue-log.md` now exists at `context/contracts/conclusion-stage.md`. Header
      comment only — no behavior change to the writer.
- [ ] Re-read each file immediately before editing (sibling tasks are live on this tree this
      cycle).

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/context/contracts/phase-closure.md` - mandatory wording
- `agent-system/extensions/core/context/contracts/wrap-up.md` - mandatory wording at the
  `blockers[]`/`dead_ends` write sites
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - emitted "## Issue Log"
  section text plus carrier-rationale comment
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new
  `issue_log_contribution` subsection
- `agent-system/extensions/core/scripts/issue-record.sh` - header note only

**Verification**:
- `shellcheck` clean on `orchestrate-build-dispatch.sh` and `issue-record.sh` (exit status
  checked, preceded by a `command -v shellcheck` resolution check — see Phase 3's note).
- `bash .claude/scripts/tests/test-issue-record.sh` passes.
- A dispatch-file build smoke test: run `orchestrate-build-dispatch.sh` against a scratch or
  existing task and confirm the emitted file still carries a well-formed "## Issue Log" section
  with the resolved `--task-dir` and the non-fatal call form intact.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` clean (the two contract files are within its
  corpus).
- `bash .claude/scripts/check-task-references.sh` clean.

---

### Phase 6: The Move 5 boundary table and commit contract [NOT STARTED]

**Goal**: Land the new allowed/prohibited table in `postflight-tool-restrictions.md`, covering
both the stage's tool surface and its per-channel commit surface, as an explicit sibling of — not
a replacement for — the existing per-dispatch postflight table.

**Tasks**:
- [ ] Add a new top-level section after the existing "Exceptions" section (and before
      "Examples"), titled "## Conclusion Stage (Move 5) Tool Restrictions".
- [ ] Open it with the relationship statement: this table is **additive**; the existing table
      above governs the per-dispatch postflight boundary (Move 3), and this one governs a
      distinct, later actor. State that the conclusion stage runs only AFTER postflight has closed
      state and committed, and that nothing here relaxes the existing table for any other skill.
- [ ] Write the **allowed tool surface** table: `Read` on `specs/{NNN}_*/issues.jsonl`;
      `AskUserQuestion` (three independent per-channel gates); `Agent` dispatch (channel (a)'s
      implementation-agent dispatch, channel (b)'s `meta-builder-agent` dispatch); `Bash` on
      `orchestrate-conclusion-aggregate.sh`, `state-write.sh`, `generate-todo.sh`,
      `roadmap-integration.sh --regenerate`, `git-commit-scoped.sh`, and `manage-topics.sh set`;
      `Edit`/`Write` on source files **only** inside a channel-(a) dispatched agent's own turn,
      never in the stage body itself.
- [ ] Write the **prohibited** table: no mid-run surfacing of issue-log content (the capture-only
      complement); no channel executing without its own `--check-approval` pass; no reading of
      `reports/*.md`, `plans/*.md`, `summaries/*.md`, or `handoffs/*.md` (the Context Flatness
      Constraint still binds — `issues.jsonl` is explicitly not in that set); no editing
      `git-commit-scoped.sh` or the roadmap generator's caller contract; no `--prune`; no editing
      another task's archived artifacts.
- [ ] Write the **commit surface** table with one row per commit, each naming its
      `git-commit-scoped.sh` pathspec class and its message action, and stating explicitly that
      these are four separate invocations and must not be swept into one undifferentiated commit:
      | Commit | In scope to stage | Message action |
      channel (a) fixes → the approved fix list's own paths; channel (b) → nothing from the stage
      itself (the dispatched `meta-builder-agent` produces tasks in `specs/`, committed as task
      creation); channel (c) → `specs/state.json`, `specs/TODO.md`, and the new child task
      directories; roadmap → `specs/ROADMAP.md` only.
- [ ] State that every invocation passes `--session` and `--task`, and that a contended-path
      refusal (exit 3) means defer and re-sequence — never widen the pathspec.
- [ ] Add a cross-reference row to `## Related Documentation` pointing at
      `context/contracts/conclusion-stage.md`.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the commit surface decomposes into exactly four
invocations (three channels plus the roadmap edit), with channel (b) contributing no stage-level
commit of its own because its dispatched agent commits its task creation itself. Confirm at
implementation time by reading `agents/meta-builder-agent.md`'s own commit/postflight contract; if
that agent does not commit its own task creation, channel (b) gains a fifth row and the table
says so.

**Files to modify**:
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - new
  "## Conclusion Stage (Move 5) Tool Restrictions" section plus a Related Documentation row

**Verification**:
- Diff read-through confirms the existing tables, the `MUST NOT Section Template`, and the
  `skill-orchestrate` D4 exception are byte-unchanged.
- `bash .claude/scripts/lint/lint-postflight-boundary.sh --verbose` clean.
- `bash .claude/scripts/check-task-references.sh` clean.
- The new section names both a tool surface and a commit surface, as the acceptance criterion
  requires: `grep -c 'git-commit-scoped.sh'` in the new section is non-zero.

---

### Phase 7: The executable Move 5 stage body and the SKILL.md pointer [NOT STARTED]

**Goal**: Write the stage's executable body into `context/contracts/conclusion-stage.md` and add
the short Move 5 pointer stanza to `skills/skill-orchestrate/SKILL.md`.

**Tasks**:
- [ ] Append an "## The Executable Stage Body" section to `context/contracts/conclusion-stage.md`,
      written to be executed verbatim by the orchestrate lead (the `lit-stage4a-flow.md` pattern).
- [ ] **Step 1 — Aggregate**: invoke `orchestrate-conclusion-aggregate.sh --aggregate` with this
      invocation's session id and the full touched-task list; parse its JSON.
- [ ] **Step 2 — Classify (judgment, the lead's own)**: assign each proposal to exactly one
      channel; state the visible-override requirement for any `suggested_channel` hint not
      followed; compose each channel's proposal text with its citations; summarise `wins[]`;
      report `unknown_classes[]` and `no_contribution_tasks[]`.
- [ ] **Step 3 — Three independent gates**: one `AskUserQuestion` per non-empty channel, batched
      into one relay call set per the existing Move 4 convention, never combined into a single
      question. Each answer is recorded via `--record-approval` for that channel alone. State
      plainly: no channel may fire on another channel's approval, and none may fire without one.
- [ ] **Step 4a — Channel (a) execution**: gated on `--check-approval --channel a`; dispatch
      `general-implementation-agent` with a purpose-built body naming the approved fix list, its
      citations, and the `source-store-deploy-boundary` requirement. Then commit via
      `git-commit-scoped.sh` with the fix list's own pathspecs.
- [ ] **Step 4b — Channel (b) execution**: gated on `--check-approval --channel b`; dispatch
      `meta-builder-agent` with `collected_answers.confirmed: true` and the approved change
      request. **Restate the anti-bypass constraint in place**: that agent creates TASKS in
      `specs/`, never implementation, and never edits `.claude/**` or the source store — this
      stage hands it a change request and nothing more. Note that it cannot call
      `AskUserQuestion` itself, which is precisely why the gate is at the lead level before
      dispatch.
- [ ] **Step 4c — Channel (c) execution**: gated on `--check-approval --channel c`; create each
      approved follow-up as a CHILD of its originating task, reusing the task-creation pattern
      already proven in `skills/skill-spawn/SKILL.md`'s Stage 11 — `state-write.sh` with
      `parent_task` set to the originating task number and the parent's `topic` inherited, then
      `manage-topics.sh set`, then `generate-todo.sh`. Commit `specs/state.json`,
      `specs/TODO.md`, and the new task directories.
- [ ] **Step 5 — Roadmap update**: invoke `roadmap-integration.sh --regenerate`, consuming the
      existing generator — never reimplementing it. Record D3's reasoning inline (`--prune` is
      out of scope because it removes content). Commit `specs/ROADMAP.md` alone. Carry forward
      Phase 2's two flags for the user.
- [ ] **Step 6 — Report**: emit the conclusion report (wins summary, per-channel outcomes,
      unknown-class tally, zero-contribution dispatches, the two roadmap flags).
- [ ] Add "### Move 5: Conclusion" to `skills/skill-orchestrate/SKILL.md` immediately after Move
      4, as a short pointer stanza: when it runs (once per invocation, after Move 4's
      finalization completes), that its body is executed verbatim from
      `context/contracts/conclusion-stage.md`, and that its tool and commit surfaces are governed
      by `postflight-tool-restrictions.md`'s Conclusion Stage section. Keep the stanza free of
      Edit-on-source, build-command, and MCP patterns (D1 / Risk R2).
- [ ] Update SKILL.md's two existing `## MUST NOT` sections to name Move 5 as a distinct, later
      actor with its own boundary — so neither section reads as prohibiting the new stage, and
      neither is weakened for Move 3.
- [ ] Add `context/contracts/conclusion-stage.md` to SKILL.md's `## Context References` list.

**Timing**: 2 hours

**Depends on**: 2, 3, 6

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - the executable stage body
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 5 pointer stanza,
  Context References entry, and the two MUST NOT clarifications

**Verification**:
- `bash .claude/scripts/lint/lint-postflight-boundary.sh --verbose` clean — the decisive check for
  D1. If it flags the new SKILL.md content, apply Risk R2's contingency rather than removing the
  stanza.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` clean.
- `bash .claude/scripts/lint/lint-scoped-commit-boundary.sh` clean (the stage body names
  `git-commit-scoped.sh` invocations).
- `bash .claude/scripts/check-task-references.sh` clean.
- Diff read-through confirms Moves 1-4 are unchanged and the `detected_defects` constraint in
  Move 4 is untouched.
- Every script, flag, and path the body names resolves — each `--check-approval`,
  `--record-approval`, `--aggregate`, and `--regenerate` flag matches the real `--help` output.

---

### Phase 8: Architecture and command documentation [NOT STARTED]

**Goal**: Document the stage where the orchestrator's own architecture and command surfaces are
documented, as the acceptance criterion requires.

**Tasks**:
- [ ] `docs/architecture/orchestrate-state-machine.md`: add a new top-level "## Move 5: Conclusion
      Stage" section immediately after "## Consolidated Output and Exit-Status Resolution".
      Cover: placement (once per invocation, strictly after Move 4's full finalization sequence —
      consolidated output, residue check, session-registry release, `.dispatch/` removal, and the
      multi-task return-meta write); the derivation from the per-task issue logs; the three
      independent gates and the no-cross-firing invariant; the per-channel commit contract and its
      four scopes; and the coexistence boundary with the skeleton-plan follow-up mechanism, stated
      with durable anchors only.
- [ ] State explicitly in that section that `detected_defects` / "System Defects Detected" is a
      separate, unconditional, ungated channel that this stage neither consumes nor replaces, so
      a future reader does not merge them.
- [ ] `commands/orchestrate.md`: extend `## Output` with a "**Conclusion**" entry describing the
      stage's report — the per-channel proposals with their citations, the wins summary, the
      unknown-class tally, the zero-contribution dispatch list, and the two roadmap flags — and
      state its relationship to the adjacent "System Defects Detected" table (sibling, never
      merged; one is gated and proposal-shaped, the other unconditional and observation-shaped).
      Note that `--dry-run` ends before Move 5, consistent with that option's existing contract.
- [ ] `context/patterns/orchestrate-batch-results-template.md`: add the conclusion report block so
      the rendering is specified in one place rather than improvised per invocation.
- [ ] Re-read each file immediately before editing.

**Timing**: 1.5 hours

**Depends on**: 2, 7

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - new Move 5
  section
- `agent-system/extensions/core/commands/orchestrate.md` - `## Output` conclusion entry
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` -
  conclusion report block

**Verification**:
- Diff read-through confirms every changed hunk is prose and the existing Moves 1-4 narrative,
  the exit-status precedence table, and the System Defects Detected rows are unchanged.
- `bash .claude/scripts/check-task-references.sh` clean.
- `bash .claude/scripts/tests/test-double-loading-check.sh` (or the deployed double-loading check)
  clean — three documents now cross-reference the new contract file.
- Every path the new sections reference resolves.

---

### Phase 9: Cross-cutting fixtures and the full gate [NOT STARTED]

**Goal**: Land the cross-cutting fixtures the acceptance criteria name beyond Phase 4's
approval-isolation cases, then run the repository's complete gate set.

**Tasks**:
- [ ] **Commit-scope fixture**: extend the Phase 4 suite with a case that, in an isolated scratch
      git repository, stages and commits two distinct per-channel pathspec classes through
      `git-commit-scoped.sh` in two invocations, then asserts from `git log`/`git show --stat`
      that the two commits are separate and that each contains only its own channel's paths —
      per-channel staging scope distinguishable in the result, as the acceptance criterion
      requires. Do not edit `git-commit-scoped.sh` itself (task 304's territory).
- [ ] **Anti-bypass fixture**: add a case asserting (i) `agents/meta-builder-agent.md`'s FORBIDDEN
      list still contains its "creates TASKS only / never implements changes directly" and
      "cannot call AskUserQuestion" clauses, and (ii) the channel (b) step in
      `context/contracts/conclusion-stage.md` restates the task-creation-only constraint and
      passes `collected_answers.confirmed`. A grep-shaped contract assertion, in the same spirit
      as the existing contract lints.
- [ ] **Gate-intactness fixture**: assert the three channels' execution steps in the contract file
      each reference `--check-approval` with their own channel letter and no other's — the prose
      half of the invariant Phase 4 proves mechanically.
- [ ] Deploy and run the full gate set.
- [ ] Record any exclusion, substitution, or narrowed verification via `issue-record.sh` with
      `--class "cost-forced exclusion or substituted verification"` rather than leaving it
      unrecorded.

**Timing**: 2 hours

**Depends on**: 4, 5, 7, 8

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts three fixtures discharge the acceptance criteria Phase 4
does not already cover (commit-scope, anti-bypass, gate-intactness), and that
`bash .claude/scripts/verify-deploy.sh` is the repository's full gate set rather than a subset.
Confirm at implementation time by re-reading the task description's extended ACCEPTANCE list
against Phase 4's and this phase's case lists, and by reading `verify-deploy.sh`'s own numbered
gate sequence (gate 9 is the postflight boundary lint). If the acceptance list needs a fourth
fixture, add it here rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - the
  three fixtures above

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` succeeds.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set — passes, with gate 9
  (`lint-postflight-boundary.sh`) explicitly confirmed green.
- `bash .claude/scripts/tests/run-all.sh` passes, and its discovery includes the new suite.
- `shellcheck` clean across every shell file this task touched (exit status checked, preceded by a
  `command -v shellcheck` resolution check, never a stdout diff against a baseline).
- `bash .claude/scripts/check-task-references.sh` clean repository-wide.

---

## Testing & Validation

- [ ] Each of the three channels cannot fire without its own approval: `--check-approval` passes
      only for the channel whose own `yes` was recorded, and reads not-approved for an absent
      record, a `no`, and a malformed ledger (Phase 4, acceptance-critical).
- [ ] One channel's approval does not fire another: recording `yes` for exactly one channel leaves
      the other two not-approved (Phase 4).
- [ ] A subagent contribution demonstrably reaches the conclusion review through the existing
      `issues.jsonl` carrier, with the rejection rationale for the other named carriers recorded
      in `context/contracts/conclusion-stage.md` (Phases 2, 3, 4).
- [ ] Every dispatch kind contributes — research, plan, implement and aux — via the shared
      contracts and the generated dispatch-file section, not implement alone (Phase 5).
- [ ] Recurring classes across tasks produce one proposal with multiple citations, never one per
      task; `kind: "win"` entries are summarised and never actioned; every proposal carries a
      `{task, entry_id}` citation (Phase 4).
- [ ] The roadmap update invokes `roadmap-integration.sh --regenerate` rather than reimplementing
      it, and the caller-split reconciliation question is flagged for the user rather than
      resolved by a silent edit to another task's file (Phases 2, 7).
- [ ] The conclusion stage's own output commits through `git-commit-scoped.sh` with per-channel
      staging scope distinguishable in the result (Phase 9 fixture).
- [ ] The new allowed/prohibited table is present in `postflight-tool-restrictions.md` and covers
      both the tool surface and the commit surface (Phase 6).
- [ ] The `meta-builder-agent` anti-bypass constraint still holds for channel (b) (Phase 9
      fixture).
- [ ] `verify-deploy.sh` and `run-all.sh` both pass; shellcheck clean; `check-task-references.sh`
      clean (Phase 9).

## Artifacts & Outputs

New files:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh`

Modified files:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/context/contracts/phase-closure.md`
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/context/formats/issue-log.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
- `agent-system/extensions/core/scripts/issue-record.sh` (header only)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- `agent-system/extensions/core/manifest.json`
- `specs/state.json`, `specs/TODO.md` (Phase 1 `file_scope` correction)

Deliberately NOT modified: `scripts/git-commit-scoped.sh`, `context/patterns/roadmap-update.md`,
`scripts/roadmap-integration.sh`, `context/standards/status-markers.md`, task 184's archived
artifacts, and `scripts/orchestrate-cycle-postflight.sh` (see Non-Goals and D5).

## Rollback/Contingency

- Every phase commits separately through `git-commit-scoped.sh --task 273`, so any single phase
  can be reverted without disturbing the others.
- Before Phase 3's or Phase 9's riskier work, take a defensive checkpoint with
  `bash .claude/scripts/git-snapshot.sh 273 --no-revert` — the durable, non-reverting form. The
  default reverting form belongs only to a genuine rollback.
- The three new files are purely additive: deleting them plus reverting the `manifest.json`
  registration returns the system to its current behavior, because nothing existing calls them
  until Phase 7's pointer stanza lands.
- If Phase 7's lint contingency (Risk R2) cannot be resolved without weakening
  `lint-postflight-boundary.sh`'s general predicate, stop and report rather than loosening the
  lint — the stage body can stay in the contract file with the SKILL.md stanza reduced further.
- If a `git-commit-scoped.sh` contended-path refusal (exit 3) fires against a sibling task this
  cycle, defer that path and re-sequence; never widen the pathspec or force it.

## Flag for the User: Expand or Plan as One Unit

The task description directs the planning phase to flag immediately whether this should be
divided via `/task --expand`. **Recommendation: plan and execute as one unit, as planned here.**

The nine phases above are serially dependent on one shared design — a single new contract file, a
single boundary table, and a single Move 5 section — and splitting them across subtasks would
fragment each of those three single documents across multiple task territories, reintroducing
exactly the cross-task collisions on the orchestrator surfaces that the description's own
`file_scope` note already records against seven other open tasks. The phase granularity here
(1-2 hours each, six waves) already delivers what an expand would buy in reviewability, without
the territory cost. Recorded as a non-blocking `user_decision` on this dispatch's
`.return-meta.json`.
