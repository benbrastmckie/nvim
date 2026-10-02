# Research Report: Task #320

**Task**: 320 - Run the orphaned .return-meta.json validator in the lifecycle, and give it the
partial_progress checks it lacks
**Started**: 2026-10-02T00:00:00Z
**Completed**: 2026-10-02T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/validate-return-meta.sh`,
  `orchestrate-cycle-postflight.sh`, `orchestrate-recover-outcome.sh`, `skill-base.sh`,
  `system-defect-record.sh`, `lint-agent-contracts.sh`
- Docs: `context/formats/return-metadata-file.md`, `context/patterns/system-defect-discrimination.md`,
  `docs/reference/utility-scripts-inventory.md`
**Artifacts**:
- `specs/320_return_meta_producer_side_validation/reports/01_producer_side_validation.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `validate-return-meta.sh` (322 lines, tested, documented) already implements Checks 1-5
  (JSON parsability, status vocabulary, artifacts-array shape) but has **zero coverage of
  `partial_progress`** and **zero executing call sites** anywhere in the repo — confirmed by a
  repo-wide search for actual invocation (not comments/docs/manifest/tests). It is an orphaned
  utility.
- The fix is two independent, additive pieces: (1) a new Check 6 inside the validator for
  `partial_progress`'s type (must be object when present) and conditional presence (must be
  absent unless `status` is `in_progress`/`partial`); (2) a single warn-only call site in
  `scripts/orchestrate-cycle-postflight.sh`, the only live per-task postflight body (confirmed:
  `orchestrator-postflight.sh` is an orphaned script with no live callers per its own header and
  `skill-base.sh:909`'s comment).
- **Critical scoping constraint, not previously surfaced in the dispatch**: a naive call site
  that reacts to the validator's overall exit code (any FAIL) would resurrect a *different*,
  already-identified and **deliberately deferred** blocker —
  `lint-agent-contracts.sh:635`'s Deferred Follow-Up item 1/2 — because Check 2 (status
  vocabulary) rejects intentional non-canonical success vocabularies several registered agents
  already use in production (`legal-analysis-agent`'s `"consulted"`, `slidev-assembly-agent`'s
  `"assembled"`, every `filetypes/*` vocabulary). Wiring the whole validator's exit code as the
  trigger would flood every such agent's ordinary, correct dispatch with a false-positive
  warning. The call site must react **only** to `partial_progress`-related output lines, not to
  the validator's aggregate exit code.
- Recommended new system-defect class: `RETURN_META_SCHEMA_VIOLATION`, added to the closed
  15-value enum in `system-defect-record.sh` and to `system-defect-discrimination.md`'s Signal A
  table, per that document's own "extending the vocabulary is an explicit decision, not a silent
  act" contract. Attribution uses the existing `--dispatched-agent NAME` resolver (no new
  agent-name → file-path logic needed).
- `orchestrate-cycle-postflight.sh` is correctly excluded from this task's own `file_scope`
  (already declared by 8 open tasks); the chosen call site is instead recorded in
  `proposed_file_scope` below for the plan phase to harvest, per the dispatch's own instruction.

## Context & Scope

Researched: where `validate-return-meta.sh` currently stands relative to its own documented
contract, whether a runtime call site already exists anywhere in the lifecycle, what the
precedent for wiring a sibling validator (`validate-artifact.sh`) into postflight looks like, and
— critically — whether any existing, already-decided constraint would be violated by a naive
implementation of the call site. The dispatch file's own "Reconciliation against the source
store" section had already ruled out building a new validator (the sibling exists) and named the
two gaps (`partial_progress` coverage; zero call sites) precisely, so this research phase's job
was to pin down the exact check logic, the exact call-site mechanics, and surface any blocker the
dispatch framing had not already named.

Out of scope (per the dispatch): choosing to widen task 270 (jq null-safety audit) to also cover
this incident's failure class; it is explicitly a different class (read-site TYPE error, not a
mutation-site null error) and task 270 remains unwidened by this task.

## Findings

### Codebase Patterns

**`validate-return-meta.sh`'s existing structure** (`agent-system/extensions/core/scripts/validate-return-meta.sh`):
Five sequential checks, each incrementing `PASSED`/`FAILED`/`WARNINGS` counters via
`log_pass`/`log_fail`/`log_warn` helpers, with a terminal summary line and exit code (`0` valid,
`1` invalid — any `FAILED > 0`, `3` file not found). Check 2 (status) and Check 3/4 (artifacts
shape) already source two shared libraries
(`scripts/lib/return-meta-status-vocabulary.sh`, `scripts/lib/return-meta-artifacts-lib.sh`) so
the status enum and artifacts-shape rules have exactly one definition, consumed by this
validator, `orchestrate-recover-outcome.sh`, and `lint-agent-contracts.sh`'s Check E alike. There
is no existing check for `partial_progress` at all (`grep -n partial_progress
validate-return-meta.sh` returns nothing, confirmed again in this pass).

**`partial_progress`'s documented schema**
(`context/formats/return-metadata-file.md:231-247`): type `object`; include only when `status`
is `in_progress` or `partial`; required sub-fields `stage` (string) and `details` (string);
optional `phases_completed`, `phases_total`, `handoff_path`. The field is used in two worked
examples in the same file (an `in_progress` early-metadata example and a `partial`
mid-interruption example), both correctly object-shaped — the violation in the motivating
incident (a bare string, alongside `status: "researched"`) violates both the type rule and the
conditional-presence rule simultaneously, which is exactly the fixture the new check must catch.

**Zero executing call sites, reconfirmed**: every occurrence of `validate-return-meta.sh` across
`agent-system/` is a comment, a doc reference
(`docs/reference/utility-scripts-inventory.md:11`, `return-metadata-file.md:149`,
`return-meta-artifacts-template.md:67`), a test (`test-validate-return-meta.sh`,
`test-return-meta-status-vocabulary.sh`), or a warning-message *string* inside
`skill-base.sh:569` advising a human to run it by hand. No `bash .../validate-return-meta.sh`,
`exec`, or command-substitution invocation exists anywhere outside its own test suite.

**The sibling validator's precedent** (`validate-artifact.sh`, for report/plan/summary files):
has two live call sites, both already **warn-only by construction** — `skill-base.sh:618,710`
and `orchestrator-postflight.sh:286` (the latter orphaned, see below) call it with `--fix`,
discard stderr (`2>/dev/null`), and downgrade its non-zero exit to a counted warning rather than
aborting. This is the exact posture the dispatch asks for `validate-return-meta.sh`'s new call
site, and it is already a proven idiom in this codebase — no new pattern needs to be invented,
only applied to the new script.

**`orchestrator-postflight.sh` is an orphaned script with no live callers.** Its own header
(Stage 6/6a) and `skill-git-workflow/SKILL.md`'s "Relationship to `orchestrator-postflight.sh`"
section both say so explicitly ("confirmed by a repo-wide grep for actual invocation sites");
`skill-base.sh:909`'s inline comment independently confirms the same fact
("orchestrator-postflight.sh itself has no live callers; see its own header note"). The **only**
live per-task postflight body, for both the single-task and multi-task `/orchestrate` engines,
is `scripts/orchestrate-cycle-postflight.sh` — invoked from
`skills/skill-orchestrate/SKILL.md:185`. This settles the dispatch's open question ("the likely
integration point") definitively: there is exactly one candidate, not several.

**`orchestrate-cycle-postflight.sh`'s existing advisory-probe pattern is the exact template to
reuse.** The script already runs a structurally identical probe for a *different*,
narrower shape mismatch — `ARTIFACTS_SHAPE_MISMATCH` (a non-empty `artifacts` array yielding no
resolvable `.path`) — in two places: the "Advisory ARTIFACTS_SHAPE_MISMATCH probe (handoff-present
path)" block (~line 591) and the recovered-return-meta `evidence_reason` check (~line 652), both
calling `orchestrate-recover-outcome.sh`, logging an `EVIDENCE:`-prefixed notice to stderr, and
(when `is_live`) recording the defect via `system-defect-record.sh` plus
`skill_orchestrate_append_detected_defect` — **advisory only; the recovered outcome above is
explicitly documented as unaffected** by either probe. A near-identical third block
("RECOVERY_DECLINED", ~line 727-765) resolves attribution to the *dispatched agent's own file*
via `system-defect-record.sh --dispatched-agent "$agent_name"` (and independently re-derives the
same resolved path for the local `detected_defects[]` row via the identical
`agent-system/extensions/*/agents/${agent_name}.md` glob, commented as mirroring the recorder's
own resolver "verbatim"). All three blocks are strictly additive: they never alter
`dispatch_status`, `recovered`, or whether the task's status gets written. This is the exact
mechanics — unconditional check, stderr notice, `is_live`-gated defect record via
`--dispatched-agent`, zero effect on outcome — the new `partial_progress` probe should copy.

**`agent_name` is in scope from argument parsing onward** (`orchestrate-cycle-postflight.sh:217,
237`), well before any handoff/recovery branching, so the new check can run early and
unconditionally (as soon as `TASK_DIR`/`attributed_path`/`detecting_site_prefix` are set, ~line
377) rather than being duplicated inside both the handoff-present and handoff-absent branches.

### Critical Finding Not Named in the Dispatch: the status-vocabulary noise hazard

`lint-agent-contracts.sh:619-635`'s own "Deferred follow-up insertion point" comment records a
**previously-identified, deliberately-deferred** blocker on wiring `validate-return-meta.sh`
into live chokepoints: item 1 ("WIRE A RUNTIME VALIDATOR INTO THE DISPATCH READ PATH") is
explicitly "Blocked on item 2" ("WIDEN `orchestrate-recover-outcome.sh`'s SUCCESS-OUTCOME
ACCEPTANCE SET"), because — verbatim — "wiring the 8-value rejection in today would newly break
several registered agents' intentional non-canonical vocabularies (e.g. `legal-analysis-agent`'s
`"consulted"`, `slidev-assembly-agent`'s `"assembled"`, every `filetypes/*` vocabulary)."

This matters directly for this task's call-site design: if the new postflight probe reacted to
`validate-return-meta.sh`'s **overall exit code** (any `FAILED > 0`), it would re-fire Check 2
(status vocabulary) for every dispatch from one of those agents — a false positive on
*correct, intentional* behavior, not a producer defect — on every single `/orchestrate` cycle
that dispatches them. That is a different failure mode from the blocked item (this task's probe
only *warns*, it never rejects/blocks the dispatch outcome the way item 1's "runtime validator in
the dispatch read path" would), but it would still manufacture continuous warning noise against
agents that are behaving exactly as designed, training operators to ignore the new signal —
precisely the anti-pattern `system-defect-discrimination.md`'s "Detection without attribution
must log only and never offer a task" section warns against for a structurally similar reason.

**Resolution**: the new call site must gate on `partial_progress`-specific output only — e.g.
grep the validator's stdout/stderr for lines naming `partial_progress` — not on the script's
aggregate exit code. This keeps the new signal exactly as narrow as this task's own Acceptance
criterion requires, reuses the single validator script as the one source of truth (no duplicated
check logic in the caller), and explicitly avoids silently re-opening the known-blocked, broader
status-vocabulary wiring question that items 1/2 above already named and deferred. (Narrowing to
`partial_progress`-only output does not touch Check 2 at all in this task — widening the
success-outcome acceptance set, item 2 above, remains fully out of scope here, exactly as the
dispatch's framing of this task already implies by naming only `partial_progress` in its
Acceptance section.)

### The new Check's exact logic (for `validate-return-meta.sh`)

Two rules, derived directly from `return-metadata-file.md:231-247`:

1. **Type-when-present**: if `.partial_progress` is present and non-null, it must be a JSON
   object; if an object, `.stage` and `.details` must both be non-empty strings (mirrors Check
   4's object-field-presence idiom for `artifacts[idx]`, same `log_fail` severity).
2. **Conditional presence**: if `.partial_progress` is present and non-null, `status` must be
   `in_progress` or `partial`; any other status value makes the field's mere presence a failure.

The regression fixture named in the dispatch (`"partial_progress": "Research complete; ..."`
alongside `"status": "researched"`) trips **both** rules at once — exactly the "two violations
in one field" the dispatch calls out — and is the minimal fixture
`test-validate-return-meta.sh` should gain a case for. Position in the script: appending as a new
"Check 6" after the existing Check 5 is the lowest-risk placement (no renumbering of existing
checks' comments/log lines); check order has no functional effect on the PASSED/FAILED/WARNINGS
totals or exit code.

Both rules should use `log_fail` (not `log_warn`) inside the script itself — per the dispatch's
own instruction, the validator's own exit-code contract stays strict; only the *caller's posture*
is downgraded to warn-only. This is also consistent with every existing check's severity choice
for a required-field/shape violation.

### The call site's exact mechanics (for `orchestrate-cycle-postflight.sh`)

Mirrors the "RECOVERY_DECLINED" block's agent-path-resolution idiom and the
"Advisory ARTIFACTS_SHAPE_MISMATCH probe" block's advisory-and-unconditional posture:

1. Run unconditionally once per dispatch (not duplicated per handoff-present/absent branch),
   placed right after `attributed_path`/`detecting_site_prefix` are set (~line 377), using
   `agent_name` (already in scope) for attribution.
2. `rm_validate_output=$(bash "${SCRIPT_DIR}/validate-return-meta.sh" "$meta_file" 2>&1)` —
   capture combined output; check `[ -f "$meta_file" ]` first (a dispatch that wrote nothing at
   all is a separate, already-handled case elsewhere in this script).
3. Filter the captured output to lines mentioning `partial_progress` (the noise-avoidance
   measure above). If that filtered set is non-empty:
   - Log one `WARN:`-prefixed notice to stderr via `$notice_prefix`, explicitly stating the
     dispatch still completes (matching the wording convention of every sibling advisory block).
   - When `is_live`: call `system-defect-record.sh --defect-class RETURN_META_SCHEMA_VIOLATION
     --detecting-site "${detecting_site_prefix}:cycle-postflight-return-meta-schema" --message
     "<filtered detail>" --dispatched-agent "$agent_name"`, then append the same row to the local
     `detected_defects[]` ledger via `skill_orchestrate_append_detected_defect`, resolving the
     attributed path with the identical `agent-system/extensions/*/agents/${agent_name}.md` glob
     the RECOVERY_DECLINED block already uses (fallback to `$attributed_path` if unresolved).
   - When `! is_live` (`--dry-run`): log the `[dry-run] would record ...` line, matching every
     sibling block's dry-run contract.
4. Never touch `dispatch_status`, `recovered`, `have_outcome`, or any status-write/commit logic —
   this block's only effects are a stderr line and (when live) a defect record; the Acceptance
   criterion ("the dispatch still completes and still persists its status") is satisfied by
   construction, not by any special-casing.

### External Resources

None consulted — this is a closed, fully codebase-internal question; no external documentation
applies to this repo's own internal validator-wiring contract.

## Decisions

- **Integration point is `orchestrate-cycle-postflight.sh`, not `orchestrator-postflight.sh`**:
  the latter is confirmed orphaned (no live callers anywhere), settling the dispatch's open
  question.
- **The call site must gate on `partial_progress`-specific validator output, not the validator's
  aggregate exit code** — to avoid resurrecting the already-known, deliberately-deferred
  status-vocabulary noise hazard documented in `lint-agent-contracts.sh:635`'s Deferred
  Follow-Up item 1/2. This is a narrower trigger than "wire the whole validator in," and is the
  one piece of this task's design not already implied by the dispatch's own framing.
- **New Signal A instance**: `RETURN_META_SCHEMA_VIOLATION`, following the precedent and the
  explicit-decision contract in `system-defect-discrimination.md` ("Extending the Signal A
  vocabulary is an explicit decision, not a silent act") — this task is that decision, recorded
  here, for this one new instance. Requires updating: `system-defect-record.sh`'s closed
  15→16-value enum (the `case` statement and its usage text), and
  `system-defect-discrimination.md`'s Signal A table plus a new named paragraph following the
  pattern used for `RECOVERY_DECLINED`/`AMBIENT_BINDING_MISMATCH`. The Detection-point registry's
  three-class taxonomy (a: loud-but-unactioned, b: computed-but-discarded, c: ephemeral) has no
  exact-fit existing class for "a new detector wired directly to the recorder at creation time
  (no discard, no separate consumer-site gap)" — the plan phase should decide which class this
  nearest resembles (closest: Class (a), since it is loud via stderr and the defect record is
  the "unactioned" tail until a future `/meta` habit reads it) rather than inventing a fourth
  class informally.
- **Attribution uses the existing `--dispatched-agent NAME` resolver** — no new agent-name →
  file-path logic is needed; `system-defect-record.sh` already globs
  `agent-system/extensions/*/agents/NAME.md`, and the RECOVERY_DECLINED block already shows the
  exact local-mirroring idiom for the `detected_defects[]` row.
- **This task does not widen task 270.** Per the dispatch, this incident's failure class
  (read-site TYPE error on an unguarded field) is different from 270's scope (jq mutation-site
  null-safety audit). If a future audit wants the read-site type-error class systematically,
  widening 270 is the cleaner home for it — not splitting it off here. Recorded explicitly, as
  instructed.

## Recommendations

1. Add the two-rule `partial_progress` check to `validate-return-meta.sh` as a new Check 6 (type
   when present; conditional presence tied to `status ∈ {in_progress, partial}`), using
   `log_fail` for both rules, placed after existing Check 5 to avoid renumbering.
2. Add the motivating bare-string fixture (`"partial_progress": "Research complete; ..."` with
   `"status": "researched"`) as a new case in `test-validate-return-meta.sh`, asserting both
   failure messages fire and exit code is `1`.
3. Add `RETURN_META_SCHEMA_VIOLATION` to `system-defect-record.sh`'s closed enum (case statement
   + usage/help text) and to `system-defect-discrimination.md`'s Signal A table (with a new named
   paragraph recording the explicit-decision rationale, per that document's own contract).
4. Wire the warn-only, `partial_progress`-output-gated call site into
   `orchestrate-cycle-postflight.sh` exactly as described in "The call site's exact mechanics"
   above — unconditional, early, using `--dispatched-agent "$agent_name"`, never affecting
   `dispatch_status`/`recovered`/status persistence.
5. Do not gate the new call site on the validator's aggregate exit code, and do not widen Check
   2's enforcement posture anywhere in this task — both would resurrect the already-deferred
   status-vocabulary blocker named in `lint-agent-contracts.sh:635` for agents with intentional
   non-canonical vocabularies.
6. One-line update to `docs/reference/utility-scripts-inventory.md`'s existing
   `validate-return-meta.sh` entry, noting it now has a live postflight call site (today's entry
   describes it only as a standalone, hand-run utility).

## Risks & Mitigations

- **Risk**: a careless implementation reacts to the validator's overall exit code, silently
  re-opening the deferred status-vocabulary blocker and flooding non-canonical-vocabulary agents
  with false-positive warnings. **Mitigation**: Decisions/Recommendations above pin the call site
  to `partial_progress`-specific output only; the plan phase should carry this constraint forward
  verbatim rather than re-deriving it.
- **Risk**: adding a 16th Signal A instance without updating `system-defect-discrimination.md`'s
  table leaves the recorder's enum and the discrimination doc's registry out of sync (the same
  drift class the doc itself warns against — "recorded here, in the document that owns the enum,
  rather than left implicit"). **Mitigation**: Recommendation 3 above bundles both edits as one
  task-scoped change.
- **Risk**: declaring `orchestrate-cycle-postflight.sh` in this task's own `file_scope` would add
  8 new serializing edges against already-open tasks (184, 263, 273, 279, 284, 285, 304, 315).
  **Mitigation**: per the dispatch's own instruction, this file is recorded only in
  `proposed_file_scope` below, for the plan phase's harvest mechanism to pick up — not in this
  research artifact's own task-level `file_scope`.

## Context Extension Recommendations

- **Topic**: `system-defect-discrimination.md`'s Detection-point registry taxonomy (Class a/b/c)
  has no documented class for "a newly-wired detector whose recorder call is live from the
  moment of creation, not computed-then-discarded." **Gap**: the plan phase (or a later
  follow-up) will need to classify `RETURN_META_SCHEMA_VIOLATION`'s registry row without a clean
  existing template. **Recommendation**: no new context file needed for this task alone: resolve
  by analogy to Class (a) in the plan's own artifact, and let a future task formalize a fourth
  class only if a second such instance arises.

## Appendix

### Search queries / commands used

- `grep -rn "validate-return-meta.sh" agent-system/extensions/core --include=*.sh --include=*.md`
  (confirmed zero executing call sites)
- `grep -n "partial_progress" agent-system/extensions/core/context/formats/return-metadata-file.md -A 20`
- `grep -rn "validate-artifact.sh" scripts/*.sh` (sibling call-site precedent)
- `grep -n "return-meta.json\|RETURN_META\|meta_file" scripts/orchestrator-postflight.sh scripts/orchestrate-cycle-postflight.sh scripts/orchestrate-recover-outcome.sh`
- `grep -n "attributed-path\|attributed_path" scripts/system-defect-record.sh scripts/orchestrate-cycle-postflight.sh scripts/skill-base.sh`
- `grep -n "defect-class\|defect_class\|KNOWN_DEFECT\|valid_defect" scripts/system-defect-record.sh`
- Read in full: `validate-return-meta.sh`, relevant sections of `orchestrate-cycle-postflight.sh`
  (lines 1-30, 330-800, 1090-1130), `orchestrate-recover-outcome.sh` (lines 1-300),
  `system-defect-record.sh` (lines 85-175), `system-defect-discrimination.md` (lines 1-250),
  `lint-agent-contracts.sh` (lines 600-660).

### proposed_file_scope (for plan-phase harvest, per dispatch's file_scope note)

```json
[
  "agent-system/extensions/core/scripts/validate-return-meta.sh",
  "agent-system/extensions/core/scripts/tests/test-validate-return-meta.sh",
  "agent-system/extensions/core/scripts/system-defect-record.sh",
  "agent-system/extensions/core/context/patterns/system-defect-discrimination.md",
  "agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh",
  "agent-system/extensions/core/docs/reference/utility-scripts-inventory.md"
]
```
