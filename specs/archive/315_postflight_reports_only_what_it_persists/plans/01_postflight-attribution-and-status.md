# Implementation Plan: Task #315

- **Task**: 315 - Stop `orchestrate-cycle-postflight.sh` reporting an outcome it did not persist, and make its `HANDOFF_STALE_OR_ABSENT` attribution depend on the DIRECTION of a dispatch_seq mismatch
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None (deliberately — see Non-Concurrency Constraints below; eight live tasks share this file but none shares a region)
- **Research Inputs**: `specs/315_postflight_reports_only_what_it_persists/reports/01_postflight-attribution-and-status.md`
- **Artifacts**: plans/01_postflight-attribution-and-status.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/context/standards/shell-strict-mode.md`
  - `.claude/rules/git-workflow.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent honesty defects in `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
surfaced by one live incident. **Deliverable 1** makes the `dispatch_seq`-mismatch arm
direction-aware: a handoff *newer* than the cycle's minted seq is a composition/minting-side
authoring fault and is attributed to `orchestrate-cycle-plan.sh`, while the *older* direction keeps
today's `skill-orchestrate/SKILL.md` attribution byte-for-byte; the three-way documented
inconsistency (code vs. `commands/orchestrate.md` vs. `orchestrate-state-machine.md`) is reconciled
and the missing test direction is covered. **Deliverable 2** adds a new `persisted_status` field to
the emitted JSON rather than repurposing `.status`, so a consumer can tell "what the agent reported"
from "what this script actually persisted" — and threads that choice through `skill-orchestrate/SKILL.md`
Move 3 and the mirrored snippet in the architecture doc.

All edits target the source store under `agent-system/extensions/core/**`. Nothing under
`.claude/**` is hand-edited (`.claude/` is a regenerated deploy artifact —
`.claude/rules/source-store-deploy-boundary.md`).

### Research Integration

The research report is adopted nearly wholesale; its four Decisions (D1–D4) are carried into this plan
verbatim in intent:

- **D1** — newer direction attributes to `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  confirmed as the sole minting site for both engines (`skill_orchestrate_mint_dispatch_seq` in
  `skill-base.sh:1486`-adjacent is defined but uncalled; `orchestrate-cycle-plan.sh` mints via
  `mt_json.dispatch_seq_counter` arithmetic, and `skill-orchestrate/SKILL.md:138` only reads the
  minted value back out).
- **D2** — `defect_class` stays `HANDOFF_STALE_OR_ABSENT` for both directions; discrimination is
  carried by `attributed_source_path` + `detecting_site` + notice text only. No enum churn in
  `system-defect-record.sh`, no downstream triage consumer touched.
- **D3** — add `persisted_status`; do **not** swap `.status`. The decisive evidence is pre-existing:
  `test-orchestrate-cycle-postflight.sh`'s Acceptance (5) already asserts `.status == "partial"`
  in a fixture where `state.json` stays `"implementing"` throughout — i.e. the suite already locks
  in "echo the agent's self-report," and an empty-blocker `partial` outcome legitimately performs
  no transition *by design*. A straight swap would regress that passing test and degrade the
  `user_decision` relay's documented purpose (`:1091`).
- **D4** — the existing `fresh_status` read (`:1322`) is multi-task-engine-only and `is_live`-only
  and cannot be reused; a separate unconditional read is required immediately before the emit.

**One research recommendation is corrected by this plan.** The report proposed asserting the new
test case's attribution by reading `.detected_defects[-1].attributed_source_path` from the
loop-guard file in `test-handoff-dispatch-identity.sh`. That cannot work there: every case in that
suite runs with `--dry-run` (hardcoded in its `run_sut`), and **both** defect-recording calls are
inside `if is_live;` — under dry-run nothing is appended and only a `[dry-run] would record ...`
line reaches stderr. This plan therefore splits the coverage: the dry-run suite asserts the
attribution from an *enriched* dry-run notice (Phases 1–2), and the live attribution **row** is
asserted in `test-orchestrate-cycle-postflight.sh`, which runs without `--dry-run` and already
inspects `.detected_defects` at its Acceptance (4b) (Phase 3).

**Two additions beyond the report**, both verified during planning:

- `docs/architecture/orchestrate-state-machine.md:380-387` carries a **second, mirrored copy** of
  Move 3's `postflight_json` destructuring (`dispatch_status`/`verdict`/`halt`). Acceptance criterion 5
  names only `SKILL.md`, but leaving this mirror stale would re-create exactly the kind of
  code/doc divergence Deliverable 1 exists to fix. Phase 6 updates both.
- `commands/orchestrate.md:309`'s table gains a **second example row** for the newer direction, so
  the operator-facing table actually shows the new discrimination rather than only being corrected
  for the old one.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:

- A `dispatch_seq` mismatch is attributed by direction: newer-than-minted → `orchestrate-cycle-plan.sh`;
  older-than-minted → unchanged `skill-orchestrate/SKILL.md`.
- The two directions are distinguishable in the notice text, in the recorded `detected_defects` row
  (`attributed_source_path` + `detecting_site`), and in the dry-run "would record" line.
- The newer direction is covered by a new, non-vacuous test case that fails against the pre-fix script.
- The four existing cases in `test-handoff-dispatch-identity.sh` keep their current behaviour, case 2
  especially, now with an added attribution non-regression assertion.
- The emitted JSON carries `persisted_status` — `state.json`'s value read fresh at emit time — so
  `.status` can no longer be mistaken for proof of a transition.
- `.status` semantics are unchanged, and the `user_decision` relay at `:1091` still reports the
  agent's own reported status, proven by an unmodified-and-green Acceptance (5).
- `commands/orchestrate.md` and `orchestrate-state-machine.md` agree with the code on the attributed
  path, and the latter's "not a bug" exoneration is narrowed to the stale direction it actually covers.

**Non-Goals**:

- Fixing the seq-minting bug itself (owned separately against `orchestrate-cycle-plan.sh`; this task
  only introduces a *string literal* naming that file, never an edit to it).
- Re-doing task 285's severity-labelling split of the handoff-absent notice. Coordinate wording if
  both land; do not merge.
- Changing the `HANDOFF_STALE_OR_ABSENT` defect-class vocabulary or any triage consumer keyed on it.
- Changing the stale-**mtime** arm's behaviour (`:429-450`). It has no direction concept; only its
  *documented* attribution is corrected.
- Auditing every `postflight_json` consumer beyond the two found (SKILL.md Move 3 and the
  architecture doc's mirror). `test-orchestrate-recover-message-findings.sh:291-292` reads only
  `.report_missing`/`.verdict` and needs no change.
- Any edit under `.claude/**`, and any deploy/regeneration step.

## Non-Concurrency Constraints (not `dependencies[]` edges)

`dependencies` is intentionally empty. Eight live tasks declare
`scripts/orchestrate-cycle-postflight.sh` in `file_scope` — 285, 279, 284, 273, 263, 304, 184, 185 —
each on a different, explicitly fenced region. Do **not** batch this task in the same `/orchestrate`
wave as any of them. Task 263 is the one edge with semantic contact (it owns the `user_decision`
relay Deliverable 2 must not degrade); if 263 lands first, re-check its relay against the
`persisted_status` shape chosen here before starting Phase 4.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Numeric `-gt` on a non-numeric/empty `handoff_dispatch_seq` or `expected_dispatch_seq` errors under strict mode | H | M | Guard with the `case ... in ''\|*[!0-9]*)` idiom already used in this file (e.g. `partial_blocker_count` near `:946`); fall back to the existing older-direction behaviour on any non-numeric input — never error, never silently misattribute |
| Mutating the shared `attributed_path` variable (`:366`) to achieve the newer-direction attribution would silently change the mtime arm too | H | M | Shadow with a **branch-local** variable inside the mismatch arm only; leave `:366` untouched. Phase 2's case-3 and case-2 assertions catch a regression here |
| Attribution assertion lands only under `--dry-run`, where no defect row is written, making it look like row-level coverage when it is not | M | H (already hit in the report's recommendation) | Explicitly split: dry-run suite asserts the enriched stderr notice; live suite asserts the actual `detected_defects` row (Phase 3) |
| A straight `.status` swap would regress Acceptance (5) and degrade the `user_decision` relay | H | L (ruled out by D3) | Additive field only; Phase 8's gate re-runs Acceptance (5) **unmodified** as the criterion-6 proof |
| `persisted_status` read fails or the task row is absent, emitting an empty string a consumer cannot interpret | M | L | Named fallback `"unknown"`; never an empty string. Assert the fallback in Phase 5 |
| Adding a field to one `jq -n` emit block and not the other (there are two: `user_decision != null` and `else`) | M | M | Phase 4 explicitly edits both (`:1400-1418` and `:1419-1436`); Phase 5 asserts presence on an `ask_user` path *and* an ordinary path |
| Eight live tasks contend on this file; a sibling's in-flight edit could be mistaken for a regression | M | M | Non-concurrency constraint above; per the dispatch's territory note, re-read before editing, stage only this task's own hunks, never `git add` a directory or glob, never `git-snapshot.sh` in reverting mode |
| Narrowing the architecture doc's exoneration could accidentally weaken the still-valid older-direction claim | M | L | The edit is **additive** — append a narrowing clause after the existing sentence; do not rewrite the preceding scenario narrative |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 7 | 1 |
| 3 | 5, 6 | 4 |
| 4 | 8 | 1, 2, 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel. Note that Phase 4 edits the same file as
Phase 1, so it is sequenced behind Phase 1 to serialize edits to
`orchestrate-cycle-postflight.sh` even though it is logically independent of Deliverable 1.
Phases 2, 3 and 7 touch no file Phase 4 touches, so they are genuinely parallel with it.

---

### Phase 1: Direction-aware attribution in the dispatch_seq-mismatch arm [COMPLETED]

**Goal**: The mismatch arm distinguishes handoff-newer-than-minted (a composition/minting-side
authoring fault, attributed to `orchestrate-cycle-plan.sh`) from handoff-older-than-minted (genuine
staleness, attribution unchanged), in the error notice, the recorded row, and the dry-run line.

**Tasks**:

- [x] Re-read `scripts/orchestrate-cycle-postflight.sh:452-478` immediately before editing (sibling
      tasks share this file). *(completed)*
- [x] Inside the `elif [ -n "$expected_dispatch_seq" ] && [ "$handoff_dispatch_seq" != "$expected_dispatch_seq" ]`
      arm (currently `:456`), compute a branch-local direction. Guard both operands with the
      `case "$v" in ''|*[!0-9]*)` idiom before any numeric test; default to the older/indeterminate
      path on any non-numeric input:

      ```
      seq_direction="older"
      case "$handoff_dispatch_seq" in ''|*[!0-9]*) ;; *)
        case "$expected_dispatch_seq" in ''|*[!0-9]*) ;; *)
          [ "$handoff_dispatch_seq" -gt "$expected_dispatch_seq" ] && seq_direction="newer" ;;
        esac ;;
      esac
      ```
      *(completed)*

- [x] Introduce **branch-local** `mismatch_attributed_path`, `mismatch_site` and `mismatch_detail`
      variables. For `older`, set them to exactly today's values
      (`$attributed_path`, `${detecting_site_prefix}:cycle-postflight-dispatch-seq-mismatch`, and the
      current detail string) so the older path is byte-for-byte unchanged. For `newer`, set:
      `mismatch_attributed_path="agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"`,
      `mismatch_site="${detecting_site_prefix}:cycle-postflight-dispatch-seq-mismatch-newer"`, and a
      detail string naming the direction and the reasoning (e.g. "handoff dispatch_seq=N is NEWER
      than this cycle's minted dispatch_seq=M — this dispatch was composed with a seq this cycle's
      own mint never produced: a composition/minting-side authoring fault, not a stale predecessor
      artifact"). *(completed)*
- [x] **Do not touch `:366`'s `attributed_path`** — the mtime arm must keep using it unchanged. *(completed: verified unchanged)*
- [x] Replace the hardcoded arguments in both the `system-defect-record.sh` call and the
      `skill_orchestrate_append_detected_defect` call with the three branch-local variables. *(completed)*
- [x] Rewrite the `ERROR: DISPATCH_SEQ MISMATCH` stderr line so it names the direction explicitly
      and, for the newer direction, says the mismatch is attributed to the minting/composition site
      rather than framing it as a stale predecessor write. Keep the literal substring
      `DISPATCH_SEQ MISMATCH` — four existing assertions and the new case grep for it. *(completed: substring preserved in both branches)*
- [x] Enrich the dry-run branch's `[dry-run] would record HANDOFF_STALE_OR_ABSENT (dispatch_seq
      mismatch)` line to also name the direction and `attributed_path=${mismatch_attributed_path}`,
      mirroring the live helper's own stderr echo (`skill-base.sh:1499`). This is what makes the
      dry-run test case able to assert attribution at all. *(completed)*
- [x] Add a short comment above the direction block recording **why** the directions differ in
      attribution (the minting site is `orchestrate-cycle-plan.sh`; `skill-orchestrate/SKILL.md`
      only reads the already-minted value). *(completed)*
- [x] Run `shellcheck` on the file per `context/standards/shell-strict-mode.md`; resolve any new finding. *(completed: zero new findings — all remaining notices pre-exist this edit)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - direction discrimination
  inside the `dispatch_seq`-mismatch arm (`:452-478`); branch-local attribution/site/detail; enriched
  ERROR and dry-run notices. No change to `:366` or to the mtime arm.

**Verification**:

- `shellcheck` clean on the changed file.
- `bash scripts/tests/test-handoff-dispatch-identity.sh` still passes all four existing cases
  (case 2 especially — the older direction must be unchanged).
- Manual read-back: the `older` arm's three values are identical to the pre-edit literals.

---

### Phase 2: New dispatch-identity case for the newer direction [COMPLETED]

**Goal**: `test-handoff-dispatch-identity.sh` covers handoff-newer-than-minted and asserts the
attribution the new discrimination produces, non-vacuously (failing against the pre-fix script),
while proving case 2's older-direction attribution did not change.

**Tasks**:

- [x] Extend `run_case` with an optional 8th parameter `EXPECT_ATTRIBUTION`: when non-empty, grep
      `$LAST_STDERR` for that literal path and pass/fail a named assertion. Document in a comment
      **why** the assertion is stderr-based here and not row-based: every case in this suite runs
      `--dry-run`, and both defect-recording calls in the SUT are inside `if is_live;` — no row is
      written. Point at the live row-level coverage added in Phase 3. *(completed)*
- [x] Add case 5, mirroring case 2's shape with only the seq direction flipped:
      `run_case "case5-newer-than-minted" 805 6 5 0 "false" 'DISPATCH_SEQ MISMATCH' \
      'agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh'`, with a case-header comment
      explaining the direction's meaning and why it is attributed to the minting script. *(completed)*
- [x] Add the non-regression attribution argument to case 2:
      `'agent-system/extensions/core/skills/skill-orchestrate/SKILL.md'`. *(completed)*
- [x] Add a second assertion to case 5 that the stderr does **not** name
      `skills/skill-orchestrate/SKILL.md` as the attributed path, so a notice that named both paths
      could not satisfy the test. *(completed)*
- [x] Update the suite's header "Detection strategy" paragraph: it currently says "these four
      cases" — make it five and name the attribution dimension. *(completed)*
- [x] Update the trailing negative-control note to mention the direction branch. *(completed)*
- [x] Prove non-vacuity: run the new case against the pre-fix script (`git stash` the Phase 1 hunk,
      or run the suite with `SUT_SRC` pointed at `git show HEAD~1:...` copied to a temp path) and
      record in the commit body that case 5's attribution assertion **fails** pre-fix. Do not leave
      the tree stashed. *(completed: ran via a scratch copy at /tmp/prefix-check with SUT_SRC
      pointed at `git show HEAD~1:...orchestrate-cycle-postflight.sh`; case 5's and case 2's new
      attribution assertions both FAIL against the pre-fix script (2 failed, 11 passed), while
      their pre-existing accept/reject + stderr-grep assertions still pass — confirming
      non-vacuity. Scratch dir removed afterward; no tree left stashed.)*
- [x] Run the full suite; commit this green sub-step. *(completed: 13 passed, 0 failed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase assumes the newer direction can be exercised through the existing
`run_case`/`make_case_dir` harness with no structural change beyond one optional parameter (case 2's
shape differs only in `handoff_seq`). Confirm by running case 5 and observing it reach the mismatch
arm (stderr contains `DISPATCH_SEQ MISMATCH`) rather than the mtime arm or the absent-field WARN. If
the harness needs more than the one added parameter, say so in the phase's commit body rather than
silently widening the change.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - optional
  attribution parameter on `run_case`; new case 5; case 2 attribution non-regression; header and
  negative-control note updates.

**Verification**:

- `bash scripts/tests/test-handoff-dispatch-identity.sh` passes, now reporting five cases.
- Case 5's attribution assertion fails when run against the pre-fix script (recorded, then reverted).
- Case 2 still passes with the SKILL.md attribution asserted.

---

### Phase 3: Live attribution-row coverage in the postflight suite [COMPLETED]

**Goal**: The actual recorded `detected_defects` row — not just a notice string — is asserted for
both directions, in the suite that runs live and already inspects the loop-guard file.

**Tasks**:

- [x] Re-read `scripts/tests/test-orchestrate-cycle-postflight.sh:332-360` (Acceptance 4b) before
      editing. *(completed)*
- [x] Extend Acceptance (4b) — handoff seq 1 vs minted 3, i.e. the **older** direction — to also
      assert `.detected_defects[-1].attributed_source_path ==
      "agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"` and that
      `.detected_defects[-1].detecting_site` does **not** end in `-newer`. *(completed)*
- [x] Add Acceptance (4c), a copy of 4b's fixture with the seq direction flipped (handoff
      `dispatch_seq: 5` against `--dispatch-seq 3`, task `707_candidate`), asserting: a defect is
      recorded; `attributed_source_path ==
      "agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"`; `detecting_site` ends in
      `:cycle-postflight-dispatch-seq-mismatch-newer`; and `defect_class` is still
      `HANDOFF_STALE_OR_ABSENT` (D2 — no vocabulary churn). *(completed)*
- [x] Add a one-line comment in 4c naming this as the live, row-level counterpart to
      `test-handoff-dispatch-identity.sh`'s dry-run case 5. *(completed)*
- [x] Run the full suite; commit this green sub-step. *(completed: 138 passed, 0 failed; 4c's new
      assertions verified non-vacuous via a scratch copy at /tmp/prefix-check3 with SUT_SRC
      pointed at the pre-fix script — 3 of 4c's assertions FAIL pre-fix, as expected. Scratch dir
      removed afterward.)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - Acceptance (4b)
  gains older-direction attribution assertions; new Acceptance (4c) covers the newer direction's
  recorded row.

**Verification**:

- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` passes in full.
- 4c's attribution assertion fails against the pre-fix script (spot-checked the same way as Phase 2).

---

### Phase 4: Add `persisted_status` to the emitted JSON [COMPLETED]

**Goal**: The emitted JSON carries `state.json`'s actual current status for this task, read fresh at
emit time, in every call shape (both engines, live and `--dry-run`), with `.status` semantics
untouched.

**Tasks**:

- [x] Re-read `scripts/orchestrate-cycle-postflight.sh:1386-1436` immediately before editing.
      *(completed: line numbers had shifted to ~1430-1476 after Phase 1's insertion; re-read at
      the shifted location before editing)*
- [x] Immediately before the `if [ "$user_decision_json" != "null" ]` emit fork, add an
      unconditional read:

      ```
      persisted_status=$(jq -r --argjson num "$task_number" \
        '.active_projects[] | select(.project_number == $num) | .status // ""' \
        "$STATE_FILE" 2>/dev/null) || persisted_status=""
      [ -z "$persisted_status" ] && persisted_status="unknown"
      ```

      with a comment stating: this is a read, never a mutation, so it is correct under `--dry-run`
      (it reports the unchanged persisted value, which is the truth for a dry run); and it is
      deliberately **separate** from the multi-state `fresh_status` read near `:1322`, which is
      multi-task-engine-only and `is_live`-only and therefore cannot populate this field for the
      single-task engine or a dry run (research D4). *(completed)*
- [x] **Leave the existing `fresh_status` read and its multi-state bookkeeping untouched.** Do not
      refactor the two into one. *(completed: verified unchanged)*
- [x] Add `--arg persisted_status "$persisted_status"` and `persisted_status: $persisted_status` to
      **both** `jq -n` emit blocks (the `user_decision != "null"` block and the `else` block).
      *(completed)*
- [x] Update the output-schema docstring at `:106-107` to list `persisted_status`, and add two
      explanatory lines in the same comment block beneath it:
      `status` = the dispatch's own self-reported outcome (verbatim from the handoff or a recovered
      `.return-meta.json`); diagnostic and `user_decision`-relay use only; **never proof that a
      transition occurred**, and may differ from `persisted_status` by design (e.g. an
      empty-blocker `partial`, or a declined recovery where `have_outcome` stayed false).
      `persisted_status` = `state.json`'s current status for this task, read fresh at emit.
      *(completed)*
- [x] Amend the comment at `:671-677` (the RECOVERY_DECLINED diagnostic-only note) to point at
      `persisted_status` as the field a consumer should read when it needs the persisted truth. Keep
      the existing wording otherwise — task 285 owns a neighbouring notice split; coordinate, do not
      overwrite. *(completed)*
- [x] Run `shellcheck`; commit this green sub-step. *(completed: zero new findings; manual
      --dry-run invocation confirmed valid JSON emitting
      `"status":"implemented","persisted_status":"implementing"`; full suite 138/138 green,
      Acceptance (5)'s `.status == "partial"` assertion unmodified and still passing)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - unconditional
  `persisted_status` read before the emit fork; new field in both `jq -n` blocks; output-schema
  docstring at `:106-107`; pointer comment near `:671-677`.

**Verification**:

- `shellcheck` clean.
- A manual `--dry-run` invocation against any fixture emits valid JSON containing `persisted_status`.
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` still passes, Acceptance (5) **unmodified**
  and still asserting `.status == "partial"` (this is the criterion-6 proof).

---

### Phase 5: Test the discrimination itself [COMPLETED]

**Goal**: `persisted_status` is asserted, not merely present — including the one fixture where it
provably differs from `.status`, and the `"unknown"` fallback.

**Tasks**:

- [x] In `test-orchestrate-cycle-postflight.sh`'s Acceptance (5) block (task `706_candidate`,
      `state.json.status == "implementing"`, `.return-meta.json.status == "partial"`), **add** an
      assertion that `.persisted_status == "implementing"` while leaving the existing
      `.status == "partial"` assertion exactly as it is. This single fixture is the whole point of
      the field: two different values, both now legible. *(completed)*
- [x] Add an assertion on an ordinary (non-`ask_user`) path that `persisted_status` is present and
      non-empty, so the `else` emit block's copy of the field is covered too. *(completed: added
      to Acceptance (4a), task 704_candidate, verdict=ok)*
- [x] Add a case where the task row is absent from `state.json` (or the project number does not
      match) and assert `persisted_status == "unknown"` rather than an empty string. *(completed:
      new Acceptance (5b), task 709_candidate)*
- [x] Add a `--dry-run` assertion that `persisted_status` reports the unchanged pre-existing status —
      the behaviour the Phase 4 comment claims. *(completed: added to the existing
      "Invariant: --dry-run leaves git status, state.json, and the loop guard unchanged" block,
      task 708_candidate)*
- [x] Run the full suite; commit this green sub-step. *(completed: 142 passed, 0 failed; shellcheck
      clean; Acceptance (5)'s pre-existing `.status == "partial"` assertion confirmed textually
      unchanged via `git diff` context lines)*

**Timing**: 45 minutes

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - added
  `persisted_status` assertions (Acceptance 5 divergence case, `else`-block path, `"unknown"`
  fallback, dry-run read).

**Verification**:

- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` passes in full.
- Acceptance (5)'s pre-existing `.status == "partial"` assertion is textually unchanged in the diff.

---

### Phase 6: Update Move 3 and its mirrored copy [COMPLETED]

**Goal**: Both copies of the postflight-JSON reader capture the new field, and the contract text
states plainly which meaning `.status` carries.

**Tasks**:

- [x] Re-read `skills/skill-orchestrate/SKILL.md:170-200` before editing (task 309 is concurrently
      scoped to other SKILL.md files, not this one — re-read anyway). *(completed)*
- [x] In `SKILL.md`'s Move 3 destructuring (`:191-195`), add
      `persisted_status=$(echo "$postflight_json" | jq -r '.persisted_status // "unknown"')`.
      *(completed)*
- [x] Update the diagnostic echo at `:196` to show both:
      `dispatch result: $dispatch_status (verdict=$verdict, persisted=$persisted_status)`.
      *(completed)*
- [x] Add two or three sentences of contract text immediately around that block stating: `.status`
      is the **agent's self-report** and is used here for the diagnostic line only — all loop control
      keys off `$verdict`/`$halt`/`$infra_exempt_cycle`, never `$dispatch_status`; `.persisted_status`
      is what `state.json` actually says after this postflight; the two differing is documented,
      intentional behaviour, not a defect. *(completed)*
- [x] Apply the same destructuring and echo change to the **mirrored** snippet at
      `docs/architecture/orchestrate-state-machine.md:380-387`, so the doc's copy does not go stale.
      *(completed)*
- [x] Confirm no other `postflight_json` consumer needs updating: `test-orchestrate-recover-message-findings.sh:291-292`
      reads only `.report_missing`/`.verdict`. Record this check in the commit body. *(completed:
      confirmed via `grep -rn "postflight_json" --include=*.md --include=*.sh agent-system/` —
      the only consumers are SKILL.md, the architecture doc's mirror, and
      test-orchestrate-recover-message-findings.sh, which reads only `.report_missing`/`.verdict`
      and needs no change. That suite still passes in full: 23/23.)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 45 minutes

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - Move 3 destructuring, echo line,
  and new contract text on the two fields' meanings.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - the mirrored Move 3
  snippet at `:380-387`.

**Verification**:

- Diff read-through: every changed hunk lies inside a fenced bash block or prose paragraph; the added
  `jq -r` line matches the sibling lines' exact idiom.
- `grep -n "persisted_status" skills/skill-orchestrate/SKILL.md docs/architecture/orchestrate-state-machine.md`
  shows the field in both files.
- `grep -rn "postflight_json" --include=*.md --include=*.sh .` shows no remaining consumer that
  destructures `.status` without the new field alongside it.

---

### Phase 7: Reconcile the three-way documented attribution [COMPLETED]

**Goal**: The operator-facing table and the architecture doc agree with the code, and the "not a bug"
exoneration covers only the direction it actually describes.

**Tasks**:

- [x] `commands/orchestrate.md:309` — correct the existing example row's **Attributed Source Path** to
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and its **Detecting Site** to
      `skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff`, matching what the mtime arm's code
      actually records. (The row's Detail text, "handoff mtime predates this dispatch window," is a
      verbatim match for the mtime arm's message, so this row is about that arm — only its two
      wrong columns change.) *(completed)*
- [x] `commands/orchestrate.md` — add a **second** example row for the newer direction:
      `HANDOFF_STALE_OR_ABSENT` / `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` /
      `skill-orchestrate/SKILL.md:cycle-postflight-dispatch-seq-mismatch-newer` / "handoff dispatch_seq
      is newer than this cycle's minted value", so the table shows the discrimination rather than
      only being corrected for the old case. *(completed, plus a short explanatory paragraph
      distinguishing the two rows as directions of the same check)*
- [x] `docs/architecture/orchestrate-state-machine.md:318-322` — **append** a narrowing clause after
      the existing "None of this is a bug in the staleness gate..." sentence: the exoneration covers
      the handoff-**older**-than-minted direction this scenario describes; a handoff **newer** than the
      cycle's minted value is a different case, now attributed to
      `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (the minting/composition site),
      where the gate is refusing an artifact newer than the state it is compared against. Do not
      rewrite the preceding scenario narrative — it is accurate for the direction it covers.
      *(completed: appended, preceding narrative left untouched)*
- [x] `context/patterns/system-defect-discrimination.md:263` — add a one-line note to the
      stale-handoff registry row distinguishing its "Location" column (where the check lives in code)
      from `attributed_path` (who is blamed), and naming the new direction split. This is the fourth,
      adjacent inconsistency the research found; it is in scope here because leaving it is what
      re-creates the confusion this phase exists to remove. If it turns out to be owned by another
      live task's fenced region, skip it and say so explicitly rather than editing around them.
      *(completed: not owned by any other live task's fenced region — added a short clarifying
      paragraph after the registry table)*
- [x] Commit this green sub-step. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:

- `agent-system/extensions/core/commands/orchestrate.md` - corrected example row at `:309`; new
  newer-direction row.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - narrowing clause
  appended at `:318-322`.
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - Location vs.
  attributed_path note on the stale-handoff registry row.

**Verification**:

- Diff read-through confirming every hunk is prose or table text, no code region crossed.
- Every path and detecting-site string in the edited docs appears verbatim in
  `scripts/orchestrate-cycle-postflight.sh` — verify by grepping each literal in both files and
  comparing.
- No task-number references introduced outside `specs/**` (`.claude/rules/no-task-references-in-deliverables.md`).

---

### Phase 8: Final gate [COMPLETED]

**Goal**: Every acceptance criterion is demonstrated green together, on one tree, with no
sibling-task contamination in the commit.

**Tasks**:

- [x] `bash scripts/tests/test-handoff-dispatch-identity.sh` — all five cases pass. *(completed:
      13 passed, 0 failed)*
- [x] `bash scripts/tests/test-orchestrate-cycle-postflight.sh` — passes in full, including the
      unmodified Acceptance (5) `.status == "partial"` assertion (criterion 6's proof) and the new
      4b/4c attribution rows. *(completed: 142 passed, 0 failed)*
- [x] `bash scripts/tests/test-orchestrate-recover-message-findings.sh` — passes (the one other
      suite that reads the emitted JSON). *(completed: 23 passed, 0 failed)*
- [x] `shellcheck` clean on `scripts/orchestrate-cycle-postflight.sh` and both edited test scripts,
      per `context/standards/shell-strict-mode.md`. *(completed: zero new findings on all three —
      every remaining notice pre-exists this task's edits)*
- [x] Walk acceptance criteria 1–8 from the dispatch one by one and record, per criterion, the exact
      command or diff hunk that demonstrates it. Any criterion that cannot be demonstrated is
      reported as an explicit exclusion with evidence, never quietly dropped. *(completed — see the
      per-criterion mapping in the implementation summary)*
- [x] `git status --short` and `git diff --staged` review: confirm only this task's files are staged,
      nothing under `.claude/**`, and no sibling's in-flight modification was picked up. Stage an
      explicit file list — never a directory or glob pathspec. *(completed: `specs/state.json`,
      `specs/TODO.md`, `specs/events.jsonl`, `.claude-extensions.json`,
      `.memory/memory-index.json`, three `index-entries.json` files,
      `agent-system/extensions/typst/scripts/typst-element-lint.sh`,
      `agent-system/extensions/core/commands/task.md`, and a stray
      `specs/309_.../progress/phase-3-progress.json` are all concurrent sibling task 309's
      in-flight work or shared orchestrator bookkeeping — none is in this task's file_scope, so
      none is staged here. Only this task's own `specs/315_.../` artifacts and the seven edited
      source-store files are committed.)*
- [x] Commit the implementation completion. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1, 2, 3, 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:

- none planned (verification and commit only)

**Verification**:

- All three named suites green in one run on one tree.
- `shellcheck` clean on all three edited shell files.
- A per-criterion mapping (1–8) recorded in the summary artifact.

---

## Testing & Validation

- [ ] `bash scripts/tests/test-handoff-dispatch-identity.sh` passes with five cases; case 5's
      attribution assertion is proven to fail against the pre-fix script.
- [ ] Cases 1–4 of that suite keep their current behaviour, case 2 (older direction) especially, now
      with its attribution asserted.
- [ ] `bash scripts/tests/test-orchestrate-cycle-postflight.sh` passes in full, including new
      Acceptance (4c) and the `persisted_status` assertions.
- [ ] Acceptance (5)'s `.status == "partial"` assertion is unmodified and green — the evidence for
      acceptance criterion 6.
- [ ] `bash scripts/tests/test-orchestrate-recover-message-findings.sh` passes.
- [ ] `shellcheck` clean on all three edited shell files per `context/standards/shell-strict-mode.md`.
- [ ] Every doc-asserted attributed path and detecting-site string matches a literal in the script.
- [ ] No file under `.claude/**` was modified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (both deliverables)
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` (case 5, case 2 attribution)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (4b/4c attribution rows, `persisted_status`)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 3 + contract text)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (narrowing clause + mirrored Move 3)
- `agent-system/extensions/core/commands/orchestrate.md` (attribution table)
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (registry note)
- `specs/315_postflight_reports_only_what_it_persists/summaries/01_*-summary.md` (per-criterion acceptance mapping)

## Follow-ups (not in scope)

- The research's Context Extension Recommendation: a short subsection in
  `system-defect-discrimination.md` documenting "attribute by direction of a monotonic mismatch" as a
  reusable shape, once this ships. Phase 7 adds only the one-line registry note; the pattern writeup
  is a separate, optional task.
- If a consumer of the emitted JSON other than Move 3 and the architecture doc's mirror is found
  during implementation, note it rather than widening this task.

## Rollback/Contingency

Every phase commits independently, so rollback is per-phase `git revert` of that phase's commit —
no snapshot needed and none should be taken in `git-snapshot.sh`'s reverting default mode (siblings
share this working tree). If an intermediate phase must be abandoned, the plan's two deliverables are
independent: Phases 1–3 and 7 (Deliverable 1) can land without Phases 4–6 (Deliverable 2), and vice
versa, provided Phase 8's gate is re-scoped to the criteria the landed phases actually cover and the
exclusion is recorded explicitly.
