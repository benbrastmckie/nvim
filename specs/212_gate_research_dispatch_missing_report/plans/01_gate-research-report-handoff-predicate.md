# Implementation Plan: Task #212

- **Task**: 212 - Postflight honesty: gate research on a report file and derive the handoff-writer predicate from the dispatch row
- **Status**: [NOT STARTED]
- **Effort**: 8.5 hours
- **Dependencies**: 194 (completed), 213 (completed)
- **Research Inputs**: specs/212_gate_research_dispatch_missing_report/reports/01_gate-research-report-handoff-predicate.md
- **Artifacts**: plans/01_gate-research-report-handoff-predicate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two defects share one root fix in `orchestrate-cycle-postflight.sh`. (1) The absent-handoff
branch excuses every agent not on a two-name hard-mode allowlist, so a research (or base-mode
implement) dispatch that writes neither `.orchestrator-handoff.json` nor `.return-meta.json`
yields `verdict=failed` with only a WARN: no defect gets recorded, and the findings the agent
sent by message are dropped. (2) A research dispatch can report `researched` when its report
file is missing or empty, and postflight still moves the task forward. The fix has four parts.
Writer status is derived from the dispatch itself instead of the agent name. A report-file gate
is added for the research phase. The orchestrator lead gets a narrow, script-backed way to save
message-only findings as a clearly tagged recovered report. Every research agent contract is
hardened against the harness's generic "do not write report files" note.

**Edit target**: the source store `agent-system/extensions/core/**` and
`agent-system/extensions/*/agents/**`. Never edit `.claude/**` by hand. Phase 6 redeploys.

### Research Integration

- **WORK (a) answered, current behavior**: a message-only research return is NOT silently
  accepted. `have_outcome=false` skips the status transition and the verdict resolves to
  `failed`, so the task is never marked `researched`. The gaps: (i) no defect is recorded for
  any non-allowlisted agent, (ii) message-borne findings are lost, (iii) a `researched` outcome
  whose report file is missing or empty is still trusted (no existence check in the `researched)`
  branch).
- **Root cause confirmed by direct observation**: the harness appends a generic subagent
  "Notes:" block ("Do NOT Write report/summary/findings/analysis .md files...") that contradicts
  the research agents' only deliverable. It does not come from the repo, so the fix goes in the
  contract layer: an explicit override clause.
- `context/contracts/recovery.md` does NOT define `[PARTIAL]` dispatch semantics (it covers git
  fix-forward and rollback). This plan does not cite it for that purpose.
- `ARTIFACTS_MISSING_ON_SUCCESS` is already in `system-defect-record.sh`'s closed enum and
  documented as "not currently computed anywhere". This plan wires its first detector.

### Decisions

- **D1, predicate shape**: a **default-true derived predicate plus an explicit opt-out flag**.
  Postflight gains `--handoff-expected true|false` (default `true`). The default holds because
  every caller today is a `dispatch[]` row (Move 3 loops `dispatch[]` only, and Move 2 passes
  `handoff_path` to every such row). The flag turns that invariant into part of the script's CLI
  contract, so it no longer rests only on SKILL.md prose. It follows the existing
  `--force-invoked`/`--dispatch-seq` idiom. No change to `orchestrate-cycle-plan.sh`'s row shape
  is needed, since the default already covers every current row. That keeps the edit away from
  the completed cycle-plan work. `is_contractual_handoff_writer()` and its agent-name list are
  deleted. Rationale: this is self-maintaining as agents and extensions are added. It fails
  toward detection, not toward excusal. An aux path that ever does reach postflight can say so
  explicitly.
- **D2, infra-exempt cycles still record**: the absent-handoff defect is recorded whether or not
  `transport_error` is set, matching the current contractual-writer branch, which does not
  condition on it. The message is annotated with `transport_error=` and `meta_touched=` so
  triage can tell the two cases apart. Loop-control (`infra_exempt_cycle`) is unchanged.
  Rationale: the observed context-exhaustion case must record, and a transport classification
  must not reopen the silent-excusal hole.
- **D3, report gate outcome**: a research dispatch with no usable report ends with
  `verdict=failed`, task status unchanged (never `researched`). A later cycle or `/orchestrate`
  call re-dispatches it. It is not moved to task-status `[PARTIAL]`, because under
  `status-markers.md` that is an implementation-phase exception state.
- **D4, message recovery is lead-side but script-backed**: postflight stays read-only over prose
  (Context Flatness) and cannot see the Agent tool's return text anyway. It emits a new output
  field, `report_missing: true`. In Move 3 the lead writes the agent's returned text **verbatim**
  to a capture file and calls a new helper, `orchestrate-recover-message-findings.sh`. The helper
  owns naming, the "recovered from agent message" banner, and the never-clobber rule. This is a
  named, narrow exception to Postflight Boundary item 5. Persisting a subagent's own
  already-produced text verbatim is preservation, not authorship. It is documented in the
  boundary text itself, not assumed.
- **D5, reproduction (WORK d)**: no live multi-agent reproduction. The mechanism was observed
  directly in the research dispatch's own system prompt, and a live miss would not disprove it.
  The outcome ("confirmed by direct observation, live repro not attempted, rationale") is
  recorded in the implementation summary.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap consultation requested for this dispatch.

## Goals & Non-Goals

**Goals**:
- An absent handoff with declined return-meta recovery from ANY lifecycle dispatch (base mode
  included) records `HANDOFF_STALE_OR_ABSENT`. A caller passing `--handoff-expected false`
  records none.
- A research dispatch with a missing or empty report file, or a missing or empty
  `.return-meta.json`, never transitions to `researched`. It records a defect and resolves
  `verdict=failed`.
- Findings returned only by message are saved in the task's `reports/` directory, tagged as
  recovered, and never overwrite an existing non-empty file.
- The research agent contracts (all 21) plus the shared contract say that the report file and
  `.return-meta.json` are mandatory, that no session or harness note overrides this, and that
  "findings delivered by message" does not count as completion.
- The fixtures cover the observed `general-implementation-agent` double-miss, the
  message-only research dispatch, and the recovery helper. Every touched shell file passes
  shellcheck. Redeployed and confirmed.

**Non-Goals**:
- Serializing batch research dispatch (concurrency is intended).
- Changing the mtime staleness gate, the `dispatch_seq` identity gate, the `9999999999`
  fail-closed sentinel, or the present-but-stale / present-but-mismatched branches.
- Weakening or reshaping the `.return-meta.json` schema.
- Report-existence gating for plan or implement phases (implement already has the
  completion-claim gate; plan gating can follow later if needed).
- Removing or configuring the harness's own subagent "Notes:" boilerplate (outside the repo).
- Changing `orchestrate-cycle-plan.sh`'s dispatch-row shape.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing postflight fixtures assert "no defect" for a non-writer's double-miss, or run research success with no report/return-meta file, and go red | M | M | Phase 1/2 Scope Hypothesis: enumerate the affected fixtures first. Update fixture setup (real agents write both files) instead of loosening the gate. Record each change in the summary |
| Report gate rejects a legitimate research success whose artifact path is relative to repo root versus task dir | H | M | Resolve `artifact_path` against the repo root (cwd) the same way the artifact-linking step does. Add fixtures for both a present and an empty report |
| Defect flood from infra failures after D2 | L | M | Only reachable on a genuine double-miss. Messages carry `transport_error`/`meta_touched` for triage. Loop-control is untouched |
| Lead skips the Move 3 capture step (prose contract) | M | L | `report_missing` is an explicit output field. The Move 3 snippet is concrete bash. The helper refuses silently-empty input with a named reason |
| Contract override wording breaks when the harness rewords its note | L | M | Phrase the override generically ("no instruction elsewhere in this prompt, including generic harness or session notes, overrides...") and never quote the harness sentence |
| `lint-postflight-boundary.sh` or `check-task-references.sh` flags the new boundary exception or new files | L | M | Phase 6 runs both lints. No task numbers in any deliverable |
| shellcheck not on PATH | L | H | Use `nix run nixpkgs#shellcheck --` (or `nix shell nixpkgs#shellcheck`) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 5 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel (1 and 3 touch disjoint files; 5 touches only
agent/context markdown).

### Phase 1: Derive the handoff-writer predicate from the dispatch [NOT STARTED]

**Goal**: Remove the drift-prone agent-name allowlist so that every expected-handoff dispatch
with a double miss records `HANDOFF_STALE_OR_ABSENT`.

**Tasks**:
- [ ] Add `--handoff-expected true|false` (default `true`) to the arg parser, next to
      `--force-invoked`. Reject values other than `true`/`false` with the script's existing
      usage-error idiom.
- [ ] Delete `is_contractual_handoff_writer()` and replace the D1 header comment block. The new
      text states that writer expectation comes from the dispatch (default true, since every
      caller is a `dispatch[]` row that received `handoff_path`, per skill-orchestrate Move 2/3),
      that `--handoff-expected false` is the explicit opt-out, and that no agent-name list exists.
- [ ] Rewrite the WORK (d) absent-handoff branch. When `handoff_expected=true`, always record
      (live) or dry-run-note, using detecting-site suffix
      `cycle-postflight-absent-expected-writer` and a message naming the agent, `transport_error`,
      and `meta_touched` (per D2). `meta_touched` is currently computed later, so hoist that
      computation above the branch without changing its value or later use. When
      `handoff_expected=false`, emit a neutral INFO line ("handoff not expected for this dispatch
      (--handoff-expected false); no defect recorded"). Remove the old WARN that told readers to
      edit the allowlist.
- [ ] Update the header's WORK (d) summary line and the `Usage:` block to match.
- [ ] Add fixtures to `scripts/tests/test-orchestrate-cycle-postflight.sh`:
      (A) `--agent general-implementation-agent --phase implement` with neither handoff nor
      return-meta, which reproduces the observed case. Assert `verdict=failed`, exactly one
      `HANDOFF_STALE_OR_ABSENT` defect row, and no allowlist WARN text on stderr.
      (B) Same setup with `--handoff-expected false`. Assert zero defect rows.
      (C) Same as (A) with `--agent general-research-agent --phase research`. Assert
      `verdict=failed`, one defect, and task status unchanged.
- [ ] Run the test file and shellcheck on both touched scripts.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Existing fixtures that assert the old non-writer behavior (for example,
any test grepping for "not on the contractual handoff-writer allowlist" or asserting 0 defects on
a double miss) are few, likely 0 to 2. Before editing, confirm with
`grep -n 'allowlist\|is_contractual\|non-writer' scripts/tests/test-orchestrate-cycle-postflight.sh`
and adjust only those assertions, recording each one.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`: flag, predicate
  removal, D1 comment, WORK (d) branch, Usage block
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`: fixtures A to C

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes
  in full.
- `grep -n is_contractual_handoff_writer agent-system/extensions/core/scripts/` returns nothing.
- shellcheck is clean on both files.

---

### Phase 2: Research report-file gate and `report_missing` output [NOT STARTED]

**Goal**: A research dispatch never advances to `researched` without a non-empty report file
and a non-empty `.return-meta.json`. Postflight tells the lead when findings need recovering.

**Tasks**:
- [ ] In the `researched)` status-transition branch, before `skill_postflight_update`, check:
      (i) `artifact_path` is non-empty and resolves to an existing, non-empty file (`-s`),
      resolved against the repo root like the WORK (g) artifact-link step; (ii)
      `${TASK_DIR}/.return-meta.json` exists and is non-empty. If either fails, skip the
      transition and the artifact link, set a `research_gate_failed=true` flag, record
      `ARTIFACTS_MISSING_ON_SUCCESS` (live) with detecting site
      `cycle-postflight-research-report-gate`, and append it to the detected-defect store the
      same way as the other defect sites.
- [ ] Make sure WORK (g) artifact linking, the artifact-round advance, and the WORK (i) commit
      are all skipped when `research_gate_failed=true`. Set `have_outcome=false` at the gate, or
      guard those blocks explicitly, whichever the code structure makes clearer. Resolve
      `verdict=failed` in the verdict ladder when `research_gate_failed=true`, even if a
      transport-exempt path would otherwise give `defer`. Leave `halt` false.
- [ ] Compute `report_missing` (bool). It is true when `phase=research` AND (no outcome was
      recovered, OR `research_gate_failed=true`) AND no non-empty report exists for this round.
      Emit it in both final `jq -n -c` output shapes. Update the header's `Output:` block and
      `docs/architecture/orchestrate-cycle-postflight.md` (if it documents the output shape) to
      list the new field.
- [ ] Update `context/patterns/system-defect-discrimination.md`: change the
      `ARTIFACTS_MISSING_ON_SUCCESS` row from "not currently computed anywhere" to name the new
      research-phase detector, and note that plan and implement are still not covered by it.
- [ ] Add fixtures:
      (D) handoff `status=researched` pointing to a nonexistent report: `verdict=failed`, status
      not `researched`, one `ARTIFACTS_MISSING_ON_SUCCESS`, `report_missing=true`.
      (E) Same, but the report exists and is empty: same assertions.
      (F) Report exists and is non-empty, `.return-meta.json` present: `verdict=ok`, status
      `researched`, `report_missing=false` (regression guard).
      (G) Fixture C from Phase 1 also asserts `report_missing=true`.
- [ ] Run the test file and shellcheck.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Some existing research-success fixtures may not create a report file or a
`.return-meta.json`, and will go red under the gate. Before editing, confirm with
`grep -n 'researched' scripts/tests/test-orchestrate-cycle-postflight.sh` and fix each one in its
fixture setup by creating the files, never by weakening the gate. Record the count.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`: report gate,
  verdict, `report_missing` output, header Output block
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`: fixtures D to G
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`: detector row
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md`: output field
  (only if that doc lists output fields)

**Verification**:
- The full postflight test file passes, and fixtures D to G pass.
- shellcheck is clean.

---

### Phase 3: Message-findings recovery helper [NOT STARTED]

**Goal**: A mechanical, idempotent script that saves an agent's message-borne findings into the
task's report directory without passing them off as a completed report.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/orchestrate-recover-message-findings.sh`
      (strict mode per `shell-strict-mode.md`) with usage:
      `--task-dir DIR --dispatch-seq N --message-file F --agent NAME --session SID [--dry-run]`.
- [ ] Read `${TASK_DIR}/.dispatch/${N}.md`'s `## Artifact Round` section for `artifact_padded`
      and `output_dir`, falling back to `reports/` and `01` with a named WARN. Target:
      `{output_dir}/{NN}_recovered-agent-message.md`. If that exists and is non-empty, use
      `-2`, `-3`... suffixes. Never overwrite.
- [ ] Write a header block: title "Recovered Research Findings (from agent message)", a bold
      banner saying this is NOT a completed research report and was saved verbatim from the
      dispatched agent's final message because the agent did not write its report file, plus
      provenance lines (agent, session, dispatch_seq, UTC timestamp). Follow it with the message
      text verbatim in a separate section.
- [ ] If the message file is missing or empty (whitespace only), write nothing and emit
      `{"recovered": false, "reason": "EMPTY_MESSAGE"}`. On success emit
      `{"recovered": true, "path": "..."}`. Always exit 0 (non-fatal to the loop). Never touch
      `state.json`, `.return-meta.json`, or the handoff.
- [ ] Create `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh`:
      success path (banner + verbatim body present); never-clobber (second run creates `-2`);
      empty message (no file created); missing dispatch file (fallback + WARN); `--dry-run` (no
      write); and an **acceptance end-to-end** fixture. The end-to-end fixture reuses the
      postflight sandbox pattern: a research dispatch with no report, no return-meta, and no
      handoff runs postflight, which gives `report_missing=true` and `verdict=failed`. The
      helper then writes the recovered file. Assert that the findings text is in `reports/`,
      that `state.json` status is still not `researched`, and that a defect row exists.
- [ ] shellcheck both new files and make them executable.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-recover-message-findings.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh` (new)

**Verification**:
- The new test file passes. The end-to-end fixture needs Phase 2's `report_missing` field. If
  run before Phase 2 lands, that one assertion is expected to be red and is re-run after Phase 2.
- shellcheck is clean.

---

### Phase 4: Wire recovery into skill-orchestrate Move 3 and amend the Postflight Boundary [NOT STARTED]

**Goal**: The lead saves message-only findings on every `report_missing=true` research dispatch
under an explicit, documented boundary exception.

**Tasks**:
- [ ] In `skills/skill-orchestrate/SKILL.md` Move 3, read `report_missing` from
      `postflight_json`. When it is `true` (research phase), the lead writes THIS task's Agent
      return text **verbatim** (no summarizing, no editing) to
      `${task_dir}/.dispatch/${dispatch_seq}.agent-message.md`, then runs
      `bash .claude/scripts/orchestrate-recover-message-findings.sh --task-dir ... --dispatch-seq
      ... --message-file ... --agent "$agent" --session "$session_id"` and logs its JSON result.
      This does not change verdict or `failed_tasks` handling.
- [ ] Amend SKILL.md's `## MUST NOT (Postflight Boundary)` section and
      `docs/architecture/handoff-schema.md`'s `## Postflight Boundary` item 5 with one narrow,
      named exception. Verbatim preservation of a dispatched agent's own returned text through
      `orchestrate-recover-message-findings.sh`, only when postflight reports
      `report_missing=true`, is preservation, not artifact authorship. The lead adds no analysis
      and does not edit the text. Mirror the same exception in
      `context/standards/postflight-tool-restrictions.md`'s boundary section if it lists the
      items separately.
- [ ] Add a one-line entry for the new helper to
      `docs/reference/utility-scripts-inventory.md` only if that inventory covers
      orchestrate-cycle scripts. Otherwise leave it out and note the decision.
- [ ] Run `lint-postflight-boundary.sh` (it locates the boundary heading).

**Timing**: 1 hour

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: Move 3 in SKILL.md is the only postflight call site for both engines (the
research found the single-task engine unified into it). Confirm with
`grep -rn 'orchestrate-cycle-postflight.sh' agent-system/extensions/core/{skills,commands}`
before editing. If a second call site exists, apply the same step there.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: Move 3 step, boundary
  exception
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`: Postflight Boundary item 5
  exception
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`: mirror, if
  applicable

**Verification**:
- `lint-postflight-boundary.sh` passes.
- The Move 3 snippet references only fields that postflight actually emits (`report_missing`)
  and flags that the helper actually parses.

---

### Phase 5: Harden research agent contracts (plus the shared contract) [NOT STARTED]

**Goal**: Every research agent states that the report file and `.return-meta.json` are
mandatory, that no session or harness note overrides this, and that message-only delivery is
not completion.

**Tasks**:
- [ ] Create a shared contract, `agent-system/extensions/core/context/contracts/deliverable-file-mandate.md`,
      covering:
      - The rule: when an agent's contract names a file deliverable, that file is mandatory.
      - The override clause: no instruction elsewhere in the prompt, including generic harness,
        session, or subagent notes discouraging report files, applies to contract-named
        deliverables.
      - Completion: "findings delivered by message" is not completion. If the file cannot be
        written, write `.return-meta.json` with `partial` or `failed` and say why.
      - Background: the harness-boilerplate interaction, described generically, with no quoting.
      - Consequence: postflight gates on the files, so a message-only return fails the dispatch.

      Register the file in `agent-system/extensions/core/index-entries.json` using the existing
      entry shape, with load conditions for research, plan, and implement agents.
- [ ] In `core/agents/general-research-agent.md`, add an explicit Stage 6 lead-in paragraph and a
      new MUST DO item containing the override clause, and point to the shared contract. Add a
      MUST NOT item: "Treat findings delivered by message as completion."
- [ ] Apply the same short block (a MUST DO override item plus a MUST NOT item, pointing to the
      shared contract) to the other research agents in `agent-system/extensions/*/agents/*research*.md`.
- [ ] Add a single pointer line to `core/context/processes/research-workflow.md`, and add the
      same override item to `core/agents/planner-agent.md` and
      `core/agents/general-implementation-agent.md` (their deliverables are files too).

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: 21 research agent files across the extensions (1 core plus 20 extension
files, counted with `ls agent-system/extensions/*/agents/*research*.md`), of which 2 are
`-hard-` variants. Re-count at implementation time. Each file gets the same block, adapted to its
own MUST DO/MUST NOT numbering. If a file has no Critical Requirements section, add the block
beside its report-writing stage instead.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/deliverable-file-mandate.md` (new)
- `agent-system/extensions/core/index-entries.json`: registration
- `agent-system/extensions/*/agents/*research*.md` (about 21 files)
- `agent-system/extensions/core/agents/planner-agent.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/context/processes/research-workflow.md`

**Verification**:
- `grep -L 'deliverable-file-mandate' agent-system/extensions/*/agents/*research*.md` returns
  nothing.
- `jq . agent-system/extensions/core/index-entries.json` parses.
- No task numbers appear in any edited file.

---

### Phase 6: Full gates, redeploy, confirm, record reproduction outcome [NOT STARTED]

**Goal**: Close with the full gate set, deploy to `.claude/`, and confirm that the deployed tree
carries every change.

**Tasks**:
- [ ] Run shellcheck on every touched or new `.sh` file
      (`nix run nixpkgs#shellcheck -- <files>` if shellcheck is not on PATH).
- [ ] Run the full postflight test file, the new helper test file, and the adjacent orchestrate
      suites: `test-orchestrate-recover-outcome.sh`, `test-orchestrate-cycle-plan.sh`,
      `test-orchestrate-build-dispatch.sh`.
- [ ] Run the repo lints: `check-task-references.sh` (no task numbers in deliverables),
      `lint-postflight-boundary.sh`, and any contract/doc lint that covers `index-entries.json`.
- [ ] Redeploy with `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default
      non-destructive mode). Then confirm:
      - `.claude/scripts/orchestrate-recover-message-findings.sh` exists.
      - `grep -c is_contractual_handoff_writer .claude/scripts/orchestrate-cycle-postflight.sh`
        returns 0.
      - `.claude/agents/general-research-agent.md` contains the override clause.
      - `.claude/context/contracts/deliverable-file-mandate.md` exists.
- [ ] Record in the implementation summary the WORK (a) finding and the D5 reproduction outcome:
      confirmed by direct observation of the harness "Notes:" block, with no live multi-agent
      reproduction attempted, and why.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5

**Verification Tier**: full

**Files to modify**:
- None beyond fixes surfaced by the gates. The deploy regenerates `.claude/**`, which must not
  be hand-edited.

**Verification**:
- All suites are green, shellcheck is clean, and the lints are clean.
- The deployed tree matches the source store for every touched file (`diff` on the source/deploy
  pairs listed above).

## Testing & Validation

- [ ] Fixture: the observed `general-implementation-agent` double miss now writes one
      `HANDOFF_STALE_OR_ABSENT` row.
- [ ] Fixture: `--handoff-expected false` double miss writes no defect (the aux-equivalent case).
- [ ] Fixture: a message-only research dispatch gives `verdict=failed` and `report_missing=true`,
      its status is never `researched`, and its findings are saved in `reports/` as a recovered
      file (end-to-end).
- [ ] Fixture: `researched` with a missing or empty report gives `ARTIFACTS_MISSING_ON_SUCCESS`
      and `verdict=failed`.
- [ ] Regression: `researched` with a real report still gives `verdict=ok`.
- [ ] Mtime, dispatch_seq, and sentinel fixtures (the existing Acceptance 1 to 3 series) are
      unchanged and green.
- [ ] shellcheck is clean on every touched shell file.
- [ ] Deployed `.claude/` reflects all source-store changes.

## Artifacts & Outputs

- `plans/01_gate-research-report-handoff-predicate.md` (this plan)
- Modified: `orchestrate-cycle-postflight.sh`, `test-orchestrate-cycle-postflight.sh`,
  `skill-orchestrate/SKILL.md`, `handoff-schema.md`, `system-defect-discrimination.md`, research
  agent contracts, `planner-agent.md`, `general-implementation-agent.md`, `research-workflow.md`,
  `index-entries.json`
- New: `orchestrate-recover-message-findings.sh` and its test,
  `context/contracts/deliverable-file-mandate.md`
- `summaries/01_gate-research-report-handoff-predicate-summary.md` (at implementation close)

## Rollback/Contingency

Every phase is committed per green sub-step, so a rollback is a `git revert` of the offending
phase commits in the source store, followed by a redeploy. Phases 1 and 2 share one script. If
Phase 2's gate proves too strict against real dispatches, revert Phase 2 alone. Phase 1's
predicate fix stands on its own. If message capture in Phase 4 proves unreliable in practice,
the fallback is to keep `report_missing` as a diagnostic output and rely on the Phase 1/2 defect
rows plus re-dispatch. The findings-loss risk stays documented in that case. An ordinary
defensive checkpoint before risky edits uses `git-snapshot.sh <N> --no-revert`, never the
default reverting form.
