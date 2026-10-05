# Implementation Plan: Handoff Required-Field Gate and Durable Validation Trace

- **Task**: 337 - Resolve the handoff-field gap: writers omit required `blockers`/`summary`, and a hard HANDOFF VALIDATION FAILED is printed and then dropped with no durable trace
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/337_handoff_required_fields_and_dropped_failure/reports/01_handoff-required-fields-dropped-failure.md
- **Artifacts**: plans/01_handoff-required-fields-trace.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Close the handoff-field gap in both directions decided by research: adopt **option (i),
writer-side obligation**, implemented as a write-time content check inside the already-registered
`PostToolUse` hook that fires on every Write/Edit of `.orchestrator-handoff.json`; and wire the
**mandatory durable trace** so a failed `validate-handoff.sh` run leaves an `events.jsonl`
`system_defect` row plus a `detected_defects[]` entry instead of scrollback only. Both sites
record under one new Signal A class, `HANDOFF_VALIDATION_FAILED`. The same pass rules on the two
companion WARNs (`sorry_inventory`, `continuation_path`): both are relaxed by *tightening their
trigger conditions*, never by touching any FAIL-producing check. Definition of done: an invalid
handoff is rejected at write time with a fix-forward banner, and any invalid handoff that still
reaches postflight is durably recorded; a clean `implemented` handoff emits zero WARNs; no
required field is removed from the validator's required set.

**All edits target the source store (`agent-system/extensions/**`), never `.claude/**`**, per
`rules/source-store-deploy-boundary.md`. The deploy is a single cutover in the final phase.

### Research Integration

The plan implements the research report's Decisions 1-6 and Recommendations 1-8 with one
deliberate refinement (recorded below). Key findings carried forward:

- `validate-handoff.sh` is already correctly strict; the defect is entirely downstream. Its one
  live invocation (`skill_corroborate_phase_counts`, `scripts/skill-base.sh:1543-1548`) discards
  the exit code via `|| true`, and no other consumer reads it. The COMPLETION-CLAIM GATE reads
  only `phases_completed`/`phases_total`, so both measured incidents completed via Case 2/3.
- The root cause is hand-authored JSON under per-agent prose, with no shared composer and no
  write-time gate. The prose block is byte-identical across 42 agent files, and task 341 proved
  it works only when someone re-issues it by hand for that one dispatch.
- `hooks/validate-handoff-location.sh` is the proven enforcement precedent: same matcher
  (`Write|Edit`), same exit-2 fix-forward posture, same `system-defect-record.sh` call. It is
  already registered in `merge-sources/settings-hooks.json` and already listed in
  `manifest.json`, so extending it needs no registration churn.
- A new Bash-script writer must NOT be introduced as the enforcement mechanism: this codebase
  already closed the Bash-redirect coverage gap by *deleting* that class of writer.

**Deliberate refinement of Recommendation 3.** Research proposed threading a `handoff_valid`
signal out of `skill_corroborate_phase_counts` as a fourth stdout token. This plan instead
**moves the validator invocation out of that function** and into the postflight handoff-present
read path. Reasons: (a) the function is only reached when `dispatch_status = "implemented"`, so
the recommended wiring would leave *plan*-phase handoffs — `core/agents/planner-agent.md` carries
the identical prose block — with no validation at all, failing the task's "repo-wide and
consistently" requirement; (b) schema validation is not a phase-count corroborator's job; (c) all
three existing `IFS=' ' read -r cpc_a cpc_b cpc_c` call sites parse the final token with a
suffix-strip, so a fourth token would silently corrupt `plan_markers_verified` at every site that
was not updated. Moving the call leaves those three sites untouched.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch context; `specs/ROADMAP.md` was not consulted and
no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Oblige every handoff writer mechanically: a required-field content check that fires on every
  actual Write/Edit of `.orchestrator-handoff.json`, which no per-dispatch forgetting can bypass.
- Make a failed handoff validation durable in both channels named by the dispatch: an
  `events.jsonl` `system_defect` row and a `detected_defects[]` entry the batch template renders.
- Extend validation coverage from implement-only to every handoff-writing phase (plan included).
- Rule on `sorry_inventory` and `continuation_path` in this same pass, with the ruling recorded in
  `docs/architecture/handoff-schema.md` and argued from the schema's actual consumers.
- Close the untested gap for the exact measured defect: no fixture currently asserts that a
  handoff missing `blockers` is rejected.

**Non-Goals**:
- **Relaxing any FAIL-producing check in `validate-handoff.sh`.** `status`, `summary`,
  `artifacts`, `blockers`, `phases_completed`, `phases_total` stay exactly as strict. This is the
  dispatch's explicit non-goal and nothing in this plan approaches it.
- Option (ii), postflight-side normalization (absent `blockers` -> `[]`, `summary` derived from
  `.return-meta.json`). Rejected per research Decision 1: it substitutes a value the dispatching
  agent never composed and treats the symptom at every future read site forever.
- Gating task completion on handoff validity. The dispatch asks for a durable trace, not a new
  terminal gate; a new gate could strand tasks whose work is genuinely complete. The recorder is
  loud and durable but non-gating, and stays independent of the completion-deploy gate (the
  second measured instance showed those two gates firing independently — do not couple them).
- A composing/JSON-assembly helper script (research Recommendation 9). An agent can decline to
  call a helper, so it cannot be the enforcement point; it is dropped rather than built as
  decoration.
- Touching the skeleton FAIL branch of Check 3, or the `needs_research` status value already
  present in the validator's accept list but absent from its `--help` text (pre-existing, out of
  scope).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Three edit targets (`skill-base.sh`, `orchestrate-cycle-postflight.sh`, `system-defect-record.sh`) are declared orchestrator-critical paths; the live `/orchestrate` cycle executing this task runs that same machinery | H | M | Source-store edits do not take effect until deploy. Do NOT deploy before Phase 7: the running cycle keeps using the pre-change `.claude/` tree throughout Phases 1-6. Run `bash -n` on every edited script before each commit. |
| A buggy content check in the hook could exit 2 on a *valid* handoff write, blocking the implementing dispatch's own report | H | L | The check is fail-safe by construction: it skips quietly (exit 0) when the handoff file is unreadable or `validate-handoff.sh` cannot be resolved, and reuses the validator wholesale rather than re-deriving the field logic. Phase 3's suite must pass before Phase 7's deploy. Rollback: `git checkout` the hook in the source store and redeploy. |
| The hook's existing test harness feeds synthetic, non-existent paths, so a naive content check would break every current accept fixture | M | H | Mandated design: the content check runs only when the path exists and is readable. Verified intent — `run_hook` in `scripts/tests/test-validate-handoff-location.sh` never creates the file it names. |
| Adding a fourth stdout token to `skill_corroborate_phase_counts` would silently corrupt `plan_markers_verified` at all three suffix-stripping call sites | H | M | Avoided entirely: the refinement above moves the call instead of widening the contract. No call site's parse shape changes. |
| Relaxing the two WARNs drifts into relaxing a FAIL | H | L | Phase 4 is scoped to exactly two code regions (the `else`/non-skeleton branch of Check 3, and the pre-Check-4 continuation capture block) with a diff review before commit; Check 3's skeleton arm and Check 5 are untouched. A `reject-no-blockers` fixture is added in the same phase as a tripwire. |
| Double-recording when the write-time hook fires and the handoff still reaches postflight invalid | L | M | `system-defect-record.sh`'s existing dedup (identity key `{defect_class}:{attributed_path}`) handles it; the two sites deliberately share one class name, exactly as four sites already share `HANDOFF_STALE_OR_ABSENT`. |
| Phase 6 touches 42 files across ~20 extensions, beyond the dispatch's named `core/**` edit target | M | M | The block is byte-identical in all 42 files, so the edit is one mechanical append verified by a before/after count. Phase 6 is isolated, last-but-one, and explicitly droppable without weakening the fix; the cross-extension reach is required by "repo-wide and consistently" because handoff writers are cross-extension. |
| Sibling tasks 322/325 are dispatched into this same working tree this cycle | M | M | Declared sibling scopes (`git-commit-scoped.sh`, `todo.md`, `skill-todo/SKILL.md`, `git-staging-scope.md`) do not intersect any file below. Re-read each file immediately before editing; stage explicit file lists only, never a directory or glob pathspec. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 3 | 1 |
| 3 | 5, 6 | 2, 3, 4 |
| 4 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Name the `HANDOFF_VALIDATION_FAILED` defect class [COMPLETED]

**Goal**: Add the one new Signal A instance both detection sites will record under, so Phases 2
and 3 have a class name the recorder accepts.

**Tasks**:
- [x] Add `HANDOFF_VALIDATION_FAILED` to the closed `--defect-class` `case` in
      `scripts/system-defect-record.sh` (the `AMBIENT_BINDING_MISMATCH|RECOVERY_DECLINED|RETURN_META_SCHEMA_VIOLATION)` arm). *(completed)*
- [x] Update the three places in that script that state the enum's size or membership: the header
      comment ("One of the sixteen Signal A instances"), the `--defect-class` usage text's
      class list, the `sixteen-value enum` comment above the `case`, and the invalid-class error
      message. All must read seventeen/seventeenth consistently. *(completed)*
- [x] Add a "A seventeenth instance, `HANDOFF_VALIDATION_FAILED`, was added deliberately..."
      paragraph to `context/patterns/system-defect-discrimination.md`, immediately after the
      existing sixteenth-instance (`RETURN_META_SCHEMA_VIOLATION`) paragraph. State: what it
      names (a dispatch's `.orchestrator-handoff.json` fails `validate-handoff.sh`'s
      required-field checks — `status`, `summary`, `artifacts`, `blockers`, `phases_completed`,
      `phases_total`); the two detecting sites; the split attribution rule (postflight uses
      `--dispatched-agent`, the hook leaves Signal B unresolved); and, following that section's
      own convention, that none of the sixteen pre-existing instances was reworded to cover it. *(completed)*
- [x] Add one row to the **Class (a) — loud but unactioned** registry table for the postflight
      site (`scripts/orchestrate-cycle-postflight.sh`, detecting site
      `cycle-postflight-handoff-validation`), modeled on the existing Return-meta schema probe
      row. *(completed)*
- [x] Amend the **Class (c) — ephemeral** table's `validate-handoff-location.sh` row so its
      "Detects" and "Defect class" cells name the second, content check and
      `HANDOFF_VALIDATION_FAILED` alongside the existing location check and `HANDOFF_MISLOCATED`. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: 2 files (`scripts/system-defect-record.sh`,
`context/patterns/system-defect-discrimination.md`) and exactly 4 occurrences of the enum
size/membership wording inside the first. Confirm at implementation time with
`grep -rn "sixteen\|RETURN_META_SCHEMA_VIOLATION" agent-system/extensions/core/scripts/system-defect-record.sh`
and re-read both files before editing (sibling-concurrency rule).

**Files to modify**:
- `agent-system/extensions/core/scripts/system-defect-record.sh` - add the class to the closed
  enum; update the four size/membership wordings
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - seventeenth-
  instance paragraph; one new Class (a) row; amend the Class (c) hook row

**Verification**:
- `bash -n agent-system/extensions/core/scripts/system-defect-record.sh` exits 0.
- `bash agent-system/extensions/core/scripts/system-defect-record.sh --help` lists the new class.
- A probe call with `--defect-class HANDOFF_VALIDATION_FAILED` no longer exits 1 on the enum
  check (it may still refuse for unresolvable Signal B attribution — that is a different, correct
  refusal; distinguish the two by the error text).
- No occurrence of "sixteen" referring to this enum remains in the script.

---

### Phase 2: Wire the durable trace at postflight [COMPLETED]

**Goal**: Replace the discarded `|| true` with a real recorder, on a path that sees every
handoff-writing phase rather than `implemented` only, without gating completion.

**Tasks**:
- [x] In `scripts/skill-base.sh`, remove the `if [ -n "$handoff_path" ] && [ -f "$handoff_path" ]`
      block that invokes `bash .claude/scripts/validate-handoff.sh ... || true` from
      `skill_corroborate_phase_counts` (around lines 1543-1548), and update that function's
      header comment to state that handoff schema validation now lives at the postflight
      handoff-present read path, with the reason (all-status coverage; separation of concerns).
      Leave the `handoff_path` parameter accepted-and-ignored OR removed — whichever keeps all
      three existing call sites valid without touching them; record which was chosen in the
      commit message. *(completed)*
- [x] In `scripts/orchestrate-cycle-postflight.sh`, inside the handoff-present branch
      (`[ -f "$handoff_file" ] && [ "$handoff_stale" != "true" ]`), after the existing `jq`
      field reads and the `Dispatch result:` notice and before the WORK (c) corroboration block,
      invoke the validator once: resolve it deploy-tree-first with a source-store fallback (mirror
      `skill_corroborate_phase_counts`'s own `_cpc_lib_candidates` idiom rather than hardcoding
      `.claude/scripts/validate-handoff.sh`, so a source-store-only checkout does not record a
      false failure from exit 127), capture the exit code without letting `set -e` abort, and
      stream its output to stderr. *(completed)*
- [x] On non-zero exit: print a loud `${notice_prefix} ERROR: HANDOFF VALIDATION FAILED — ...`
      line naming the handoff path, then, gated on `is_live`, copy the stale-handoff recorder
      template verbatim (the `--defect-class HANDOFF_STALE_OR_ABSENT` block) changing only the
      class name to `HANDOFF_VALIDATION_FAILED`, the detecting site to
      `${detecting_site_prefix}:cycle-postflight-handoff-validation`, the message, and the
      attribution — use `--dispatched-agent "$agent_name"` (not `--attributed-path`), since the
      dispatched agent authored the malformed JSON. Follow it with the matching
      `skill_orchestrate_append_detected_defect "$defect_store" ...` call. Add the
      `[dry-run] would record HANDOFF_VALIDATION_FAILED` else-arm. *(completed)*
- [x] Carry `--extra-detail-json` with the failing field names when they are cheap to derive from
      the captured validator output (grep its `[FAIL]` lines); omit the flag rather than guess. *(completed)*
- [x] Assert non-gating explicitly in a code comment: this block must not assign
      `dispatch_status`, must not set `handoff_stale`, and must not influence the script's exit
      code or the completion-claim gate. It is a recorder, not a gate. *(completed)*
- [x] Update `scripts/tests/test-corroborate-phase-counts.sh`: retarget Fixture H (which exists
      solely to pin the now-removed in-function diagnostic as non-gating) to assert the function
      no longer invokes the validator at all, and update the header note at lines ~87-91 that
      explains the `cd "$REPO_ROOT"` requirement for the cwd-relative validator path. *(completed)*
- [x] Add cases to `scripts/tests/test-orchestrate-cycle-postflight.sh` modeled on the existing
      `RETURN_META_SCHEMA_VIOLATION` cases 950/951/952: (a) an `implemented` handoff missing
      `blockers` records exactly one `HANDOFF_VALIDATION_FAILED` defect attributed to the
      dispatched agent's own source-store file; (b) `--dry-run` prints the would-record line and
      writes nothing; (c) a clean handoff produces no `HANDOFF_VALIDATION_FAILED` mention on
      stderr; (d) a `planned`-status handoff missing `summary` also records — the coverage this
      phase's refinement exists to add. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: 4 files, and exactly 3 existing call sites of
`skill_corroborate_phase_counts` (`orchestrate-cycle-postflight.sh:648` and `:729`,
`orchestrate-stage5-gates.sh:192`), of which only the first passes a handoff path. Confirm at
implementation time with
`grep -rn "skill_corroborate_phase_counts" agent-system/extensions/core/` and verify no call site
parses a fourth stdout token before and after the edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - remove the log-only validator invocation
  from `skill_corroborate_phase_counts`; update its header comment
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add the validate-and-
  record block to the handoff-present read path
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` - retarget
  Fixture H and its header note
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - four new
  cases

**Verification**:
- `bash -n` clean on both edited scripts.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` exits 0
  with the new cases passing.
- `bash agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` exits 0.
- Manual probe: run the postflight script `--dry-run` against a scratch task dir holding a
  deliberately `blockers`-less handoff and confirm the `[dry-run] would record
  HANDOFF_VALIDATION_FAILED` line appears and no file is written.
- `grep -n "validate-handoff" agent-system/extensions/core/scripts/skill-base.sh` returns nothing.

---

### Phase 3: Add the write-time required-field gate to the hook [COMPLETED]

**Goal**: Make required-field compliance unforgettable, by extending the one hook that already
fires on every Write/Edit of `.orchestrator-handoff.json`.

**Tasks**:
- [x] In `hooks/validate-handoff-location.sh`, after the location allow-branch (the
      `grep -Eq '(^|/)specs/(OC_)?[0-9]{3,}_...'` match) and *in place of* its bare
      `echo '{}'; exit 0`, add a required-field content check against the just-written file. *(completed)*
- [x] Resolve the validator as a sibling of the existing `SYSTEM_DEFECT_RECORD` resolution
      (`$SCRIPT_DIR/../scripts/validate-handoff.sh`). **Fail safe**: if the validator is absent
      or not readable, or if `$FILE` does not exist or is not readable, print `{}` and exit 0
      silently — never exit 2 on an unknowable input. This is what keeps the existing suite's
      synthetic, non-existent paths passing. *(completed)*
- [x] Capture the validator's exit code under `set -euo pipefail` without aborting, and keep its
      output for the banner. *(completed)*
- [x] On validator FAIL: print a loud fix-forward banner to stderr in the shape of the existing
      MISPLACED banner — name the file, quote the validator's `[FAIL]` lines, state that
      `summary` must be a non-empty 2-4 sentence string and `blockers` a JSON array (`[]` is
      normal for a clean return), and give the remediation order (re-write the file at the same
      path with the missing fields; do not delete it). Then call `system-defect-record.sh` with
      `--defect-class HANDOFF_VALIDATION_FAILED`, `--detecting-site
      "hooks/validate-handoff-location.sh"`, `--attributed-path
      "unresolved:hooks/validate-handoff-location.sh"` (Signal B deliberately unresolved at a bare
      PostToolUse invocation, exactly as the existing `HANDOFF_MISLOCATED` call does),
      `--extra-detail-json` carrying the file path and failing-field list, and the existing
      `${CC_SESSION_ID:+...}`/`${CWD:+...}` passthroughs. `exit 2`. *(completed)*
- [x] On validator PASS (including pass-with-warnings, exit 0): `echo '{}'` and `exit 0`,
      preserving the hook's JSON-channel discipline. *(completed)*
- [x] Update the hook's header: it now performs two checks, so state both, and add a note that
      the filename is retained deliberately (renaming would churn `manifest.json`,
      `merge-sources/settings-hooks.json`, the test suite path and every doc citation for no
      behavioral gain). Keep the existing COVERAGE LIMITATION paragraph intact and extend it:
      the content check inherits the same Write/Edit-only blindness to Bash-redirect writes, and
      the Phase 2 postflight recorder is the mechanism-agnostic backstop for that path. *(completed)*
- [x] Extend `scripts/tests/test-validate-handoff-location.sh`: keep every existing fixture
      unchanged (they must still pass, proving the fail-safe), and add on-disk fixtures — a
      conforming handoff at a valid task path exits 0 with no banner; the same path with
      `blockers` absent exits 2 with the required-field banner; with `summary` absent exits 2;
      with unparsable JSON exits 2; and a case where the sibling validator is removed from the
      copied layout exits 0 silently (the fail-safe). Add an `assert_field_rejected` helper beside
      the existing `assert_misplaced`, and have the on-disk fixtures create the file under the
      `$WORKDIR` specs-shaped path the payload names. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: 2 files, no registration changes — the hook is already listed in
`manifest.json`'s `hooks` array and already wired in `merge-sources/settings-hooks.json`'s
`PostToolUse` `Write|Edit` matcher. Confirm both at implementation time with
`grep -n "validate-handoff-location" agent-system/extensions/core/manifest.json agent-system/extensions/core/merge-sources/settings-hooks.json`
before concluding no third file is needed.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` - add the required-field
  content check, its banner, its recorder call, and the header update
- `agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` - five new
  fixtures plus the on-disk helper

**Verification**:
- `bash -n agent-system/extensions/core/hooks/validate-handoff-location.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` exits 0,
  with every pre-existing fixture still passing (this is the fail-safe proof, not a formality).
- Direct probe: pipe a synthetic PostToolUse payload naming an on-disk `blockers`-less handoff and
  confirm exit 2 plus the banner; repeat with a conforming file and confirm exit 0 and `{}` on
  stdout.

---

### Phase 4: Scope the two companion WARNs to the cases where they inform [COMPLETED]

**Goal**: Stop `sorry_inventory` and `continuation_path` from WARNing on ~100% of dispatches,
without weakening any FAIL check — and close the missing `blockers` reject fixture.

**Tasks**:
- [x] In `scripts/validate-handoff.sh`'s Check 3 `else` (non-skeleton) branch, remove the
      unconditional `log_warn "Optional field absent: sorry_inventory ..."`. Keep the
      `log_pass "Optional field present: sorry_inventory"` arm when the field *is* present, and
      leave a one-line comment recording why absence is silent here (hard-mode-only field; the
      schema already documents it so; every base-mode writer would otherwise WARN forever). *(completed)*
- [x] Leave the entire `if [[ "$skeleton" == "true" ]]` arm of Check 3 — all of its FAIL paths —
      byte-for-byte untouched. *(completed)*
- [x] Reduce the pre-Check-4 `continuation_path`/`continuation_context` block to pure variable
      capture: keep both `jq` reads (Check 5 depends on the variables), drop both the `log_warn`
      and the `log_pass`, and add a comment pointing at Check 5 as the single, correctly
      status-conditioned reporting site for this field. *(completed)*
- [x] Leave Check 5 ("Status/continuation consistency") unchanged — it already WARNs exactly when
      `status` is `partial`/`blocked` with no continuation pointer set. *(completed)*
- [x] Add two bullets to the `--help` "Validation rules" list recording the new scoping:
      `sorry_inventory` absence is not reported outside skeleton mode; continuation-pointer
      absence is reported only when `status` is `partial` or `blocked`. *(completed)*
- [x] In `scripts/tests/test-validate-handoff.sh`, add `assert_reject "reject-no-blockers"` — an
      otherwise-conforming `implemented` handoff with no `blockers` key, i.e. the exact shape
      measured in tasks 191 and 340, which no current fixture covers. *(completed)*
- [x] Add an `assert_accept_no_warn <name> <grep-pattern> <json>` helper (accept + assert the
      pattern does not appear in the captured output file) and use it to pin: a clean
      `implemented` handoff emits no `sorry_inventory` WARN and no continuation WARN. *(completed)*
- [x] Add an accept fixture with `status: "partial"`, no continuation pointer, asserting Check
      5's WARN still fires (`assert_accept` plus a positive grep) — the tripwire proving the
      relaxation did not silence the informative case. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: exactly 2 code regions change in `validate-handoff.sh` — the Check 3
`else` branch (around lines 229-236) and the continuation capture block (around lines 248-255) —
plus the `--help` text. Confirm with `grep -n "log_warn" agent-system/extensions/core/scripts/validate-handoff.sh`
before and after: the count must drop by exactly 2, and the surviving `log_warn` calls must be
the `dispatch_seq`, Check 5, Check 6, Check 7 and `artifacts[0].summary` ones. `grep -c log_fail`
must be unchanged.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-handoff.sh` - two WARN scopings and the
  `--help` rules bullets
- `agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` - `reject-no-blockers`,
  the no-WARN helper and its two fixtures, the partial-status tripwire

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-handoff.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` exits 0.
- A conforming `implemented` fixture now reports `Warnings: 0` (previously 2-3).
- `git diff` review before commit confirms no `log_fail` line and no part of the skeleton branch
  was touched.

---

### Phase 5: Record the rulings in the schema documentation [NOT STARTED]

**Goal**: Leave the decisions where the next reader finds them, so neither the wiring status nor
the WARN ruling is re-derived — and satisfy the dispatch's requirement that any relaxation be
argued from the schema's consumers in `handoff-schema.md`.

**Tasks**:
- [ ] Rewrite `docs/architecture/handoff-schema.md`'s **`validate-handoff.sh` wiring status**
      paragraph: it is no longer invoked from `skill_corroborate_phase_counts` at all; it now runs
      (a) at write time from the `PostToolUse` hook, exit 2 + `HANDOFF_VALIDATION_FAILED` on
      failure, and (b) once per handoff-present postflight for every phase, recording
      `HANDOFF_VALIDATION_FAILED` to `events.jsonl` and `detected_defects[]`. State plainly that
      it remains non-gating for task completion and is independent of the completion-deploy gate.
- [ ] Extend the **Path Resolution Contract** section's description of
      `hooks/validate-handoff-location.sh` to name its second, content check.
- [ ] In `### sorry_inventory (optional, array, hard-mode-only)`, record the ruling: absence is
      the expected universal case for every base-mode writer, the validator no longer WARNs on it
      outside skeleton mode, and the consumer argument — the only readers are the hard engine and
      the postflight `implemented)` skeleton-follow-up reporting, which the same document already
      calls a no-op for base-mode handoffs.
- [ ] In `### continuation_path`, record the ruling: absence is schematically correct whenever
      `status = "implemented"` (as that section already states), so the unconditioned WARN was
      redundant with the status-conditioned Check 5, which remains the single reporting site.
- [ ] In `### summary (required)` and `### blockers (required array; ...)`, add one sentence each
      noting that compliance is now enforced at write time by the `PostToolUse` hook, so a
      non-compliant write is rejected with a fix-forward banner rather than discovered later.
- [ ] Update `context/contracts/wrap-up.md`'s one-line description of the hook (around line 31)
      so it names both checks.

**Timing**: 1 hour

**Depends on**: 2, 3, 4

**Verification Tier**: prose

**Scope Hypothesis**: 2 files and 6 sections. Confirm the `handoff-schema.md` anchors at
implementation time by re-grepping for `log-only, non-gating`, `### sorry_inventory`,
`### continuation_path`, `### summary`, `### blockers` and `## Path Resolution Contract` — line
numbers will have shifted if Phases 2-4 touched this file at all.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - wiring status rewrite;
  path-resolution note; four field-section rulings
- `agent-system/extensions/core/context/contracts/wrap-up.md` - hook description now names both
  checks

**Verification**:
- Diff read-through confirms every changed hunk is prose, with no code fence altered.
- No stale claim survives: `grep -n "log-only, non-gating" agent-system/extensions/core/docs/architecture/handoff-schema.md`
  returns nothing, and `grep -rn "skill_corroborate_phase_counts" agent-system/extensions/core/docs/architecture/handoff-schema.md`
  no longer presents that function as the validator's call site.
- Every cross-reference named in the new text resolves to a file that exists.

---

### Phase 6: Point the 42 identical writer-prose blocks at the write-time gate [NOT STARTED]

**Goal**: An agent whose handoff write is rejected should recognize the banner as a documented
gate, not a novel failure. Comprehension only — the hook, not this prose, is the enforcement.

**Tasks**:
- [ ] Confirm the block is still byte-identical across all writers:
      `grep -rl "BOTH required top-level fields" agent-system/extensions/ --include=*.md | wc -l`
      and a spot diff of three files from different extensions.
- [ ] Append one sentence to the end of that block, in every file carrying it: a write-time
      `PostToolUse` gate validates the handoff on every Write/Edit and rejects a non-compliant
      write with `exit 2` plus a remediation banner, so a missing field surfaces immediately at
      the write rather than later in postflight.
- [ ] Apply mechanically (one scripted `sed`/`perl` pass over the grep-derived file list), never
      file-by-file by hand, so the 42 blocks cannot drift.
- [ ] Re-run the count: the new sentence must appear exactly as many times as the block does.
- [ ] Do not alter any other text in these files, and do not touch `core/agents/planner-agent.md`'s
      surrounding `dispatch_seq` or `artifacts`-shape paragraphs.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: atomic-batch

**Scope Hypothesis**: 42 files across ~20 extensions, each carrying a byte-identical 5-line
block (measured at planning time: `grep -rl "BOTH required top-level fields" --include=*.md`
returned 42, and the block's last line was identical in all 42). Re-measure before editing and
after; if the count differs from 42, stop and reconcile rather than proceeding on the stale
number. This phase is isolated and droppable: if the count has drifted or the block is no longer
identical, record that and skip it — the fix does not depend on it.

**Files to modify**:
- `agent-system/extensions/*/agents/*.md` - the 42 files whose handoff-authoring section carries
  the identical `**summary` and `blockers` are BOTH required top-level fields.**` block,
  enumerated at implementation time by the grep above rather than hardcoded here

**Verification**:
- Before/after counts of both the block and the new sentence are equal and equal to the measured
  file count.
- `git diff --stat` shows exactly that many files changed, each with a single-hunk addition.
- Diff read-through confirms every hunk lies inside the prose block.

---

### Phase 7: Deploy cutover and full gate [NOT STARTED]

**Goal**: Make the source-store changes live in `.claude/` and prove the whole gate set passes.

**Tasks**:
- [ ] Confirm Phases 1-6 are committed and the tree holds no unrelated staged changes
      (`git status --short`); sibling tasks may have committed in parallel — inspect, do not
      assume.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` (the non-destructive resync; not `--wipe`).
- [ ] Run `bash .claude/scripts/verify-deploy.sh` and require exit 0 — treat exit 2 as failure,
      per that script's own header.
- [ ] Run the full suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Spot-verify the deployed copies carry the changes:
      `grep -n "HANDOFF_VALIDATION_FAILED" .claude/scripts/system-defect-record.sh .claude/scripts/orchestrate-cycle-postflight.sh .claude/hooks/validate-handoff-location.sh`
      returns hits in all three, and `grep -c log_warn .claude/scripts/validate-handoff.sh`
      matches the source store.
- [ ] Note in the implementation summary that this dispatch's own `.orchestrator-handoff.json`
      write exercises the new write-time gate live, and record the observed outcome (pass, or the
      banner and what it said).

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- none planned (deploy regenerates `.claude/**`, which is a disposable artifact and is never
  hand-edited)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — this is the full gate set this tier names.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0, or any failure is a
  documented pre-existing entry in `scripts/tests/known-failures.txt`.
- The deployed-copy greps above all return the expected hits.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-handoff.sh` — including the
      new `reject-no-blockers` fixture and the zero-WARN assertions.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-handoff-location.sh` — every
      pre-existing fixture still passes (fail-safe proof) plus the five new content fixtures.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` —
      including the four new `HANDOFF_VALIDATION_FAILED` cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh` — with
      Fixture H retargeted.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` — whole-suite regression.
- [ ] `bash .claude/scripts/verify-deploy.sh` — deploy currency and hook registration.
- [ ] Negative check against the explicit non-goal: `git diff` over
      `scripts/validate-handoff.sh` shows no change to any `log_fail` line and no change to the
      `required_fields` array.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/system-defect-record.sh` (new defect class)
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (seventeenth
  instance; registry rows)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (durable trace)
- `agent-system/extensions/core/scripts/skill-base.sh` (validator call removed)
- `agent-system/extensions/core/hooks/validate-handoff-location.sh` (write-time content gate)
- `agent-system/extensions/core/scripts/validate-handoff.sh` (two WARN scopings)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `context/contracts/wrap-up.md` (rulings recorded)
- 42 `agent-system/extensions/*/agents/*.md` writer-prose blocks (Phase 6, droppable)
- Four extended test suites under `agent-system/extensions/core/scripts/tests/`
- A regenerated `.claude/` deploy tree (disposable artifact, not a committed deliverable)
- `specs/337_handoff_required_fields_and_dropped_failure/summaries/01_*-summary.md` at
  implementation close

## Rollback/Contingency

Every phase is an independently committed, source-store-only change, and nothing takes effect in
the live `.claude/` tree until Phase 7's deploy — so a defect found before that deploy is reverted
by `git revert` of the offending phase commit with no live impact.

If the new write-time gate misbehaves after Phase 7's deploy (the one change that can block an
agent's own handoff write), recover in this order: (1) `git revert` the Phase 3 commit in the
source store; (2) re-run `bash .claude/scripts/deploy-headless.sh`; (3) re-run
`bash .claude/scripts/verify-deploy.sh`. The hook's fail-safe design bounds the blast radius in
the meantime — it exits 0 silently whenever the handoff or the validator cannot be read, so the
worst realistic failure is a false exit 2 on one write, which the agent can act on by re-writing
the file.

If a rollback must discard uncommitted working-tree state rather than revert a commit, take the
snapshot first per `context/contracts/recovery.md`'s rollback rung (including its out-of-scope
override flag for a deliberate whole-tree case) — not a bare precautionary `git-snapshot.sh`
invocation, and never while a sibling task's work is uncommitted in this shared tree.
