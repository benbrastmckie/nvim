# Research Report: Stop the Dispatch Composer Emitting a Superseded Prior Decision as Settled

**Task**: 427 - Stop the dispatch composer emitting a superseded Prior Decision as settled
**Started**: 2026-10-17T00:00:00Z
**Completed**: 2026-10-17T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `orchestrate-record-decision.sh`, `scripts/lib/deploy-ledger-lib.sh`, `orchestrate-cycle-plan.sh`,
  `scripts/skill-base.sh`, `scripts/tests/test-orchestrate-build-dispatch.sh`,
  `scripts/tests/test-orchestrate-record-decision.sh`
- Docs: `docs/architecture/handoff-schema.md` ("Decisions File Schema" section),
  `docs/architecture/orchestrate-state-machine.md`, `context/standards/push-consent-relay.md`,
  `skills/skill-orchestrate/SKILL.md` (Move 4)
- Live evidence: `specs/328_systematic_script_and_test_corpus_efficiency/.decisions.json` and
  `.dispatch/10.md` (the actual contradictory dispatch file that triggered this task)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The contradiction is real and reproducible: `specs/328_.../.dispatch/10.md` literally carries a
  `## Description` block containing an inline, hand-authored `== SCOPE WIDENED ... (operator
  decision, 2026-10-16) ==` block that reverses a `## Prior Decisions` entry timestamped a day
  earlier, under the composer's own unconditional "Treat these as settled" prose.
- Neither candidate staleness signal named in the dispatch is dependable as the sole detector:
  `state.json`'s per-task `last_updated` is bumped by many writes unrelated to the description
  (dispatch_seq_counter, pending_dispatch, cycle_count, status transitions — confirmed in
  `skill-base.sh`, `orchestrate-stage5-gates.sh`, `orchestrate-loop-guard-init.sh`), and the
  observed inline dated-marker convention (`== ... (operator decision, DATE) ==`) is a single
  ad hoc human convention with no schema, no scripted writer, and no second occurrence anywhere
  in the repository to confirm it generalizes.
- **Recommended mechanism**: an optional `description_fingerprint` field (sha256 of the task's
  description text, computed at answer time) added to *new* `.decisions.json` entries only.
  `orchestrate-build-dispatch.sh` recomputes the same hash over the *current* description at
  render time; a mismatch marks that entry `POTENTIALLY SUPERSEDED` inline and softens the
  blanket authority prose from unconditional to conditional — only when at least one entry
  actually mismatches. No existing entry is rewritten; entries without the field render exactly
  as they do today (graceful degradation), which keeps the no-conflict and no-`.decisions.json`
  cases byte-identical to current output.
- This reuses an idiom this exact codebase already has twice (`deploy-ledger-lib.sh`,
  `orchestrate-cycle-plan.sh`'s identical-dispatch convergence guard): `sha256sum` content
  fingerprinting with a documented, non-fatal degrade path when `sha256sum` is unavailable.

## Context & Scope

Task 427 was spawned from task 328's Conclusion-stage triage (issue `iss_1792178040823_YdbHiu`,
class `contract-conflict`) after a live `/orchestrate` run produced a dispatch file whose two
"authoritative" sections — `## Description` and `## Prior Decisions` — directly contradicted each
other on whether the markdown/context corpus was in scope, with the composer's own fixed prose
instructing the agent to "treat [the Prior Decision] as settled." The dispatched agent resolved
the conflict correctly by judgment, but nothing in the file itself would have told a different
agent, or a human skimming it, that a conflict existed at all.

The scope here is research-only: decide ONE coherent precedence rule (detection mechanism,
rendering behavior, and where the rule is documented) and verify it against the constraint that
`.decisions.json`'s existing records are never mutated. Implementation (editing
`orchestrate-build-dispatch.sh`, `orchestrate-record-decision.sh`, and
`docs/architecture/orchestrate-state-machine.md`) is left to the plan/implement phases that
follow; this report's `## Decisions` section pins the rule those phases should build.

## Findings

### Codebase Patterns

**Current composer behavior** (`orchestrate-build-dispatch.sh:451-464,680-689`): when
`specs/{NNN}_{slug}/.decisions.json` exists and is non-empty, every entry is rendered verbatim as
`- Question: ... / Answer: ... / Answered in cycle C at T` under a hardcoded, unconditional
intro: *"Treat these as settled — do not re-ask a question already answered here."* The
`## Description` section (emitted separately, a few hundred lines earlier in the same file) is
whatever `state.json`'s current `.description` field holds — there is no cross-reference between
the two sections at all. The file carries a deliberate "byte-identical when absent/empty"
precedent already (confirmed in `scripts/tests/test-orchestrate-build-dispatch.sh` Group 10, Case
A/B): an absent or empty `.decisions.json` emits no `## Prior Decisions` section and changes
nothing else in the output.

**`.decisions.json` schema and writer** (`orchestrate-record-decision.sh`,
`docs/architecture/handoff-schema.md:1053-1094`): exactly four required fields
(`question`, `answer`, `cycle`, `timestamp`); additive-only, flock-guarded, single sanctioned
writer. The schema doc describes the shape as "at minimum" these four fields — there is no
dedicated JSON Schema file for `.decisions.json` (unlike `state.json`/`errors.json`) and the
existing test (`test-orchestrate-record-decision.sh:205`) asserts field presence via `has(...)`
rather than an exact-key-set match, so a new optional field is not a breaking schema change.

**No scripted writer touches the description field at all.** A repo-wide search of every script
under `agent-system/extensions/core/scripts/` found no `update-task-description.sh` or equivalent,
and `/task`'s own flag set (`--recover`, `--expand`, `--sync`, `--abandon`, `--review`) has no
description-amend mode. The `== SCOPE WIDENED ... (operator decision, 2026-10-16) ==` block
observed in `specs/328_.../.dispatch/10.md` was therefore appended to the description by direct,
unscripted edit (an operator or the orchestrate lead editing `state.json` mid-run) — a real but
entirely ad hoc convention, not a mechanism the composer can lean on as a stable, generalizable
signal.

**`last_updated` is too noisy to use as the staleness signal.** Confirmed writers that bump a
task's `state.json` `last_updated` for reasons having nothing to do with the description:
`skill-base.sh:1617` (`dispatch_seq_counter` write), `orchestrate-loop-guard-init.sh:169,196,221,235`
(`dispatch_seq_counter`, `cycle_count`, `pending_dispatch` writes), `orchestrate-stage5-gates.sh:239,275`
(`infra_failures` writes). A task can accumulate many `last_updated` bumps per `/orchestrate`
cycle without its description ever changing, so "decision timestamp precedes task `last_updated`"
would flag almost every Prior Decision as potentially stale — a false-positive rate high enough
to make the signal worthless (it would need to be ignored, defeating the point).

**This codebase already has a proven content-fingerprint idiom.** `scripts/lib/deploy-ledger-lib.sh`
(lines 46-141) and `orchestrate-cycle-plan.sh` (lines 2115-2690, its "identical-dispatch
convergence guard") both hash content with `sha256sum` and degrade gracefully
(`command -v sha256sum >/dev/null 2>&1 || return 2`, rendering a `CANNOTVERIFY` sentinel or simply
disabling the guard for that run) when the tool is unavailable — never a hard failure. Both the
writer (`orchestrate-record-decision.sh`, via its existing `task_entry` jq value) and the reader
(`orchestrate-build-dispatch.sh`, via its existing `description="$DESCRIPTION"`, itself sourced
from `skill-base.sh:366`'s `jq -r '.description // ""'`) already extract the description from the
identical `state.json` field through the identical jq expression shape, so a fingerprint computed
by one and verified by the other is apples-to-apples with no normalization needed.

**The one related precedent in this codebase (push-consent-relay.md's ".decisions.json Replay
Hazard") was resolved by construction, not by special-casing the renderer** — a push authorization
answer is safe to replay verbatim into a later cycle's Prior Decisions because the actual
authorization lives in a separate, single-use grant token the renderer never reads. That precedent
does not transfer here: this task's symptom is an ordinary scope decision being contradicted by a
later description edit, where nothing analogous to the grant-token separation exists — the
Description text *is* the authoritative current instruction, and the renderer is exactly the
place a mismatch needs to be surfaced.

### External Resources

Not applicable — this is a pure in-repo composition/presentation problem with no external
library or API involved.

## Decisions

1. **Detection mechanism: content fingerprint, not inline-marker parsing and not `last_updated`.**
   Add an optional `description_fingerprint` field (sha256 hex digest of the task's `description`
   text, computed with `sha256sum`) to `.decisions.json` entries **written from this point
   forward only** — `orchestrate-record-decision.sh` computes it from the same `task_entry` it
   already resolves, using the established `command -v sha256sum` degrade idiom (omit the field
   entirely, never an empty-string placeholder, when `sha256sum` is unavailable at write time).
   Rejected alternatives: (a) parsing the inline `== ... (operator decision, DATE) ==` convention
   — it is unschemed, has exactly one observed occurrence, and is authored by hand with no
   enforcement, so a parser built against it would be fragile and would not generalize to a
   differently-phrased future edit; (b) comparing the decision's `timestamp` against the task's
   `last_updated` — demonstrated above to be too noisy (bumped by unrelated per-cycle writes) to
   produce a trustworthy signal.

2. **Rendering rule: inline `POTENTIALLY SUPERSEDED` marking, conditional intro prose.**
   `orchestrate-build-dispatch.sh` recomputes `sha256sum` over the *current* description at
   render time. For each Prior Decision entry carrying `description_fingerprint`, a mismatch
   appends an inline note to that entry ("POTENTIALLY SUPERSEDED — the task description has
   changed since this answer was recorded; follow the current `## Description` instead") and
   switches the section's intro prose from today's unconditional "Treat these as settled" to a
   conditional form naming the exception and stating that, on conflict, the current `##
   Description` governs. This fires **only when at least one entry in that render actually
   mismatches** — an entry lacking the field (every pre-existing record, and any future record
   written while `sha256sum` was unavailable) is never marked, and a render where every entry
   matches (or no entries carry the field) stays byte-identical to today's output, satisfying the
   no-conflict byte-identity requirement and the existing absent/empty-file precedent in Group 10
   of the test suite. A separate `## Conflicting Inputs` callout section was considered and
   rejected as the primary mechanism — heavier-weight for no added legibility over marking the
   specific entry in the section that already exists for exactly this content, directly beside
   the `## Description` a reader must already consult.

3. **Precedence rule, stated once:** add a new section to
   `docs/architecture/orchestrate-state-machine.md` (sited near the existing Move 4 /
   `AskUserQuestion` / `.decisions.json` material) stating, for both the composer and a human
   reader: `.decisions.json` is historical and immutable — a decision is never rewritten once
   recorded. The task's current `## Description` is always the authoritative instruction. A
   Prior Decision is rendered `POTENTIALLY SUPERSEDED` exactly when its recorded
   `description_fingerprint` no longer matches the current description's hash; on such a
   conflict, the current Description governs and the agent should follow it, not the superseded
   answer. A Prior Decision carrying no `description_fingerprint` (every record predating this
   feature) cannot be verified against the current description and renders as settled — a known,
   accepted limitation stemming directly from the constraint against rewriting existing records,
   not a silent gap.

## Recommendations

- **Writer change** (`orchestrate-record-decision.sh`): read `description` from the already-held
  `task_entry` (`jq -r '.description // empty'`, mirroring `skill-base.sh:366`'s extraction
  exactly) and, when `sha256sum` is on `PATH`, add `description_fingerprint` to the `jq -c -n`
  entry construction (`orchestrate-record-decision.sh:153-158`). Update
  `docs/architecture/handoff-schema.md`'s "Decisions File Schema" section (lines 1053-1094) to
  document the fifth field as documented-optional, following the existing
  "documented-optional... absence means X" convention already used throughout `state-schema.json`.
- **Reader change** (`orchestrate-build-dispatch.sh`): at the existing prior-decisions read block
  (lines 451-464), when `sha256sum` is available, compute it over `$description` once; for each
  entry carrying `description_fingerprint`, compare and track whether any entry mismatched. Thread
  that boolean into the render block (lines 680-689) to select between today's prose and the
  conditional variant, and append the inline marker to only the mismatching entry/entries.
- **Doc change** (`docs/architecture/orchestrate-state-machine.md`): add the precedence section
  described in Decision 3 above.
- **Test extension** (`scripts/tests/test-orchestrate-build-dispatch.sh`, extending the existing
  Group 10): add fixtures for (a) a decision whose `description_fingerprint` matches the current
  description — renders exactly as today (no marker, unconditional prose) — reusing and
  reaffirming the no-conflict byte-identity precedent named in the task's VERIFY item 1; (b) a
  decision whose `description_fingerprint` was computed against an earlier description, with the
  fixture's current description changed afterward — renders with the `POTENTIALLY SUPERSEDED`
  marker and conditional intro prose (VERIFY item 2); (c) the pre-existing Case A/B (absent/empty
  `.decisions.json`) already in the suite continue to cover VERIFY item 3 unchanged; (d) the
  pre-existing Case C fixture (an entry with only the four legacy fields, no
  `description_fingerprint`) already demonstrates VERIFY item 4 once the reader change ships,
  since that entry has no field to match against and must render without error exactly as it does
  today — this report flags it as "already covered by an existing fixture," not as new work, so
  the plan phase should confirm rather than re-author it. `test-orchestrate-record-decision.sh`
  should gain a corresponding case asserting the new field appears when `sha256sum` is present and
  is correctly omitted (not emitted empty) when it is not.
- **Non-goal held**: nothing is silently suppressed. The superseded entry's question, answer,
  cycle, and timestamp remain fully visible in the rendered dispatch — only an explanatory marker
  and a conditional qualifier are added.

## Risks & Mitigations

- **Risk**: `sha256sum` unavailable on some execution host, at either write or read time. —
  **Mitigation**: graceful degrade matching the two existing in-repo precedents exactly: omit the
  field at write time (not an empty placeholder); skip the comparison and fall back to today's
  unconditional rendering at read time. Never a hard failure in either script.
- **Risk**: an inconsequential description edit (e.g. a typo fix) will still flip the fingerprint
  and mark an unrelated decision `POTENTIALLY SUPERSEDED`, even though nothing material changed.
  — **Accepted tradeoff**: exact content fingerprinting is deliberately strict. The task's own
  NON-GOAL ("a reader must still see what was answered, when, and why it no longer governs... not
  to pick a winner behind the agent's back") makes over-surfacing the safer failure mode than
  under-surfacing; a human or agent reading a spuriously marked entry loses a few seconds
  confirming it still holds, versus a real conflict silently governing wrong.
- **Risk**: every `.decisions.json` entry recorded before this feature ships permanently cannot
  be fingerprint-checked. — **Accepted, by the task's own constraint**: retroactively mutating
  existing records is explicitly prohibited. This report treats it as a documented limitation
  (stated in the new precedence section, Decision 3) rather than something to engineer around.

## Context Extension Recommendations

- **Topic**: Prior Decisions vs. current Description precedence.
- **Gap**: `docs/architecture/orchestrate-state-machine.md` has no section stating how a Prior
  Decision relates to a later change in the task's own Description — this gap is exactly what
  let the task 328 contradiction reach a dispatched agent unflagged.
- **Recommendation**: add the section named in Decision 3 above during the plan/implement phases;
  this is the primary deliverable the dispatch's SCOPE item (3) asks for ("stated once... so the
  composer and a human reading a dispatch apply the same rule").

## Appendix

### Search queries / paths examined
- `grep -n "Prior Decision\|decisions.json\|treat these as settled" orchestrate-build-dispatch.sh`
- `grep -rn "last_updated" agent-system/extensions/core/scripts/*.sh` (noise-confirmation)
- `grep -rln "fingerprint\|sha256sum\|shasum" agent-system/extensions/core/scripts/*.sh`
- `grep -n "Decisions File Schema" -A 60 docs/architecture/handoff-schema.md`
- `grep -n "Prior Decision\|decisions_file" scripts/tests/test-orchestrate-build-dispatch.sh`
- Live fixture inspection: `specs/328_systematic_script_and_test_corpus_efficiency/.decisions.json`
  and `.dispatch/10.md` (lines 155-184), the actual contradictory file cited by the spawning issue.

### Confirmed file_scope coverage
All six files named in this task's `file_scope` were read and are accounted for in the
Recommendations above: `orchestrate-build-dispatch.sh`, `test-orchestrate-build-dispatch.sh`,
`orchestrate-record-decision.sh`, `test-orchestrate-record-decision.sh`,
`orchestrate-state-machine.md`, `handoff-schema.md`.
