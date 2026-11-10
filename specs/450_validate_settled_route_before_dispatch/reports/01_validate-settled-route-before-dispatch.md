# Research Report: Validate a Settled Route's Obligation-Discharge Claim Before Dispatch

**Task**: 450 - Require a settled user-decision route to name the obligation it discharges, and check that claim before a dispatch spends a cycle on it
**Started**: 2026-11-10T08:35:26Z
**Completed**: 2026-11-10T08:38:49Z
**Effort**: Medium (schema + contract + composer-emission change, three files plus two test suites)
**Dependencies**: None blocking; territory edges declared in the dispatch (447 semantic-reconcile, 449/407/443/274/275/378/328/435/448 serialization-only)
**Sources/Inputs**:
- Direct read of `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` (writer)
- Direct read of `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (composer, Prior Decisions + Premise Re-Validation blocks)
- Direct read of `agent-system/extensions/core/context/standards/user-decision-contract.md`
- Direct read of `agent-system/extensions/core/docs/architecture/handoff-schema.md`'s "Decisions File Schema" section
- Direct read of `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`'s "Prior Decisions vs. Current Description: Precedence" section
- Direct read of `agent-system/extensions/core/context/formats/report-format.md`'s "Carried-Figure Discipline" / "The premise a dispatch acts on" / Owner-ruling subsections
- Direct read of `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`'s Move 4 (batched `AskUserQuestion` relay and record-decision call site)
- `grep` over `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` and `test-orchestrate-build-dispatch.sh` for existing fixture shapes
- `specs/state.json` / `specs/TODO.md` for territory/duplicate context
**Artifacts**:
- This report: `specs/450_validate_settled_route_before_dispatch/reports/01_validate-settled-route-before-dispatch.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- The dispatch's factual claims are all confirmed by direct read: `.decisions.json`'s schema
  (four required fields, no obligation field), `user_decision-contract.md` (no obligation/route
  language), and `orchestrate-state-machine.md`'s precedence section (staleness only, not
  validity) are exactly as described.
- **Reconciliation with 447 resolved: its premise-re-validation mechanism does NOT already cover
  this case**, so this record's scope stays full (candidates 1/2/3 all remain live), not narrowed
  to candidate 1 alone. Two independent reasons: (a) it reads a different source (the task
  `description` text, never `.decisions.json`); (b) its six trigger shapes are lexical
  carried-figure patterns (counts, pass/fail, citations), not an obligation-discharge claim about
  a chosen route.
- That same adjacent work supplies the decisive architectural precedent for *which* mechanism to
  choose: report-format.md records an explicit **Owner ruling** — "the composer EMITS, it never
  ADJUDICATES" — and states in writing that general semantic conflict detection was *rejected* for
  the structurally closest existing feature in this same composer script. Building candidate (2)
  (a validator that judges whether a route "actually discharges" an obligation) as a general
  mechanism would reproduce exactly the shape already rejected one function away.
- **Recommendation: (1)+(3), not (1)+(2).** Make the claim recordable (schema field, backward
  compatible, modeled on the existing optional `description_fingerprint` precedent) and require it
  at proposal time (amend `user-decision-contract.md`), then propagate it to the implementer with
  an explicit "verify before you start, and raise a NEW blocking question if not discharged"
  instruction — mirroring the emit/adjudicate split already adopted for premise re-validation.
  Candidate (2) is not ruled out by cost alone (the dispatch's own fallback framing is cost-based)
  but by cheapness vs. a mechanical check only ever being a narrow, case-specific lexical grep —
  which this task's own regression fixture (a contrary dependency already stated in the plan's
  findings) could satisfy, but which does not generalize, and generalizing it is exactly what the
  Owner ruling forecloses for this composer.
- The mirror-image fixture (an option set framed as open when it is not) folded in on 2026-11-04
  is NOT itself a decision-recording case — it was caught during research, before any
  `user_decision` was ever raised — so the chosen mechanism must be expressed as a shared,
  self-check obligation on the PROPOSING agent (an option is listed only if its alternatives are
  not already structurally excluded by the task's own artifacts), not only as a post-answer check.
  `user-decision-contract.md`'s existing "When NOT to Raise One" section is the natural landing
  site for this half.
- No duplicate or absorption candidate found beyond the already-declared territory edges; 447 is
  the only genuine semantic neighbor and is now reconciled rather than assumed disjoint.

## Context & Scope

This task researches, but does not implement, a mechanism to close a gap in the
`/orchestrate` user-decision pipeline: a `user_decision` answer recorded to
`specs/{NNN}_{slug}/.decisions.json` and later relayed into a dispatch file's `## Prior
Decisions` section carries no record of *what obligation the chosen route was supposed to
discharge*, and nothing in the pipeline ever checks that claim before the next dispatch spends a
cycle acting on it. The live incident cited in the dispatch (carried-unverified from an external
log, not re-measurable here) is a settled phase-merge decision that left a separate, independent
circularity across three phases untouched; the cost was two further phases closing `[BLOCKED]`.

Scope is bounded to: (a) confirming the four candidates and the "fail open" / "don't re-litigate"
/ "single sanctioned writer" / "backward compatible" constraints are accurately grounded against
the live source store; (b) resolving the required reconciliation with the adjacent task that
already extended this same composer's carried-figure obligation ("447" in the dispatch's own
territory-edge numbering); (c) recommending ONE mechanism (or a stated combination) with the
reasoning a planner can carry forward unchanged.

Out of scope: writing the actual schema/contract/composer changes (implementation), and
resolving cross-repo representation of the originating incident (noted in the dispatch as `#401`,
unrelated to this record).

## Findings

### Codebase Patterns

**The decision pipeline, confirmed field-for-field:**
- `orchestrate-record-decision.sh` is confirmed as the single writer: five required arguments
  (`--task --session --cycle --question --answer`), `flock -x` held across
  read → merge → validate → atomic `mv`, root-array-type validation both before and after merge,
  object-wrapped input refused with exit 2 and the pre-existing file left byte-identical. It
  already carries exactly one OPTIONAL field beyond the four required ones —
  `description_fingerprint` (sha256 of the description at answer time, omitted entirely rather
  than empty-stringed when `sha256sum` is unavailable) — added via a two-branch `jq -c -n` call
  rather than an unconditional `+` merge. This is the precedent to imitate for a new
  `obligation`-shaped field: optional, additive, two-branch, never a schema-breaking rewrite.
- `handoff-schema.md`'s "Decisions File Schema (`.decisions.json`)" section is confirmed as the
  one authoritative schema definition; it documents `description_fingerprint` the same way the
  script implements it, confirming writer and doc are already in lockstep for this exact
  precedent.
- `orchestrate-build-dispatch.sh`'s `## Prior Decisions` emission (around its `prior_decisions_block`
  variable) reads `.decisions.json`, recomputes the current description's fingerprint, and marks
  an entry `POTENTIALLY SUPERSEDED` only on a fingerprint mismatch — confirmed to be a
  **staleness** check only; it has no path that reads or reasons about the entry's `answer` text
  structurally. The emitted instruction text ("Treat these as settled — do not re-ask a question
  already answered here") is confirmed verbatim.
- `orchestrate-state-machine.md`'s "Prior Decisions vs. Current Description: Precedence" section
  is confirmed to state a 4-point precedence rule entirely about description-vs-decision
  staleness; it contains no validity/obligation/route language.
- `user-decision-contract.md` is confirmed to define `question`/`options`/`recommended`/`blocking`
  as the complete `user_decision` field shape, with no obligation-naming requirement anywhere in
  the file, including its "When NOT to Raise One" section — the dispatch's claim that a grep for
  route/unblock/obligation/discharge/validate returns nothing is accurate.

**The reconciliation with the adjacent composer work (dispatch's "447"):**
- `orchestrate-build-dispatch.sh` already implements a second, structurally similar mechanism: a
  `premise_revalidation_block`, emitted as a `## Premise Re-Validation` section, present **only**
  when the task directory already holds a prior report/plan/summary artifact. Its content is a
  `grep -nE` lexical sweep of the CURRENT `## Description` text for six fixed trigger-class
  shapes: an "N of M" ratio, an exit-status/code number, PASS/FAIL words, a `gate{N}` token,
  always/never/cannot/is-required language, or a count-of-{B,KB,MB,lines,files,suites,cases,tests}
  pattern.
- `report-format.md`'s "The premise a dispatch acts on" subsection and its following "Owner
  ruling" are the governing design statement for that mechanism: *"The dispatch composer EMITS...
  The composer never adjudicates whether the two agree... The receiving agent ADJUDICATES."* The
  very next paragraph states, in writing: *"Mechanical conflict DETECTION is excluded... Deciding
  that a prior artifact's measurement contradicts a description's claim is a semantic relation
  between arbitrary spans — exactly the shape the rejected general contradiction detector failed
  on."*
- **This does not already cover a settled route as an acted-on premise**, for two independent
  reasons, both verifiable by direct read rather than by inference:
  1. **Different data source.** The Premise Re-Validation sweep runs over `$description` (the
     task's `## Description` text) only. It never reads `.decisions.json`. A decision's `answer`
     text — the "route" in the dispatch's terminology — is invisible to this mechanism unless the
     description happens to independently restate it, which is not guaranteed and not the normal
     case (the cited incident's route lived in the decision record, not in a re-edited
     description).
  2. **Different claim shape.** Even granting a hypothetical restatement, the six trigger
     patterns are lexical carried-figure shapes (a stated count, a pass/fail word, a citation, an
     absolute-language word). "Does the chosen route discharge a stated obligation" is not a
     carried figure in that sense — it is a structural/semantic claim about whether an option
     closes a goal, which is precisely the class of judgment the Owner ruling assigns to the
     *receiving agent*, never to the composer.
  - **Ruling recorded per the dispatch's own instruction**: this record's scope does **not**
    narrow to candidate (1) alone. The full three-candidate scope (and the chosen combination
    below) stands.
  - **But the adjacent precedent is still the single most load-bearing finding of this research**,
    because it answers the *mechanism-choice* question directly: this codebase has already, in
    this exact script, considered and explicitly rejected building a general route/claim
    validator into the composer, on grounds (semantic-relation-between-arbitrary-spans,
    rejected-general-contradiction-detector) that apply to candidate (2) with no material
    difference. Candidate (2) is not merely costly here — it would be the second instance of the
    pattern this codebase has one paragraph ago written down, in the same file, as out of scope
    for a composer.

**Where candidate (2)'s insertion point would be, if chosen anyway:** `skill-orchestrate/SKILL.md`
Move 4's branch is confirmed as the single call site that both calls
`orchestrate-record-decision.sh` (after the batched `AskUserQuestion` relay) and precedes the next
cycle's Move 1 dispatch composition — i.e., "between recording and dispatching" names an existing,
single seam, not a seam that would need to be invented. This matters for a planner: if the ruling
below is ever revisited, the insertion point is already known and narrow.

**The mirror-image fixture (folded in 2026-11-04, from a second, unrelated originating incident):**
- A dispatch framed `openValid_reflectTime` as an "implementer's call" alternative route to a
  direct proof, when the alternative was already structurally excluded by an import cycle visible
  in the task's own artifacts. This was caught during research — layered into the same phase,
  before any `user_decision` was ever raised, so no cycle was spent.
- This is the mirror polarity of the main incident: main incident = an option *claimed* to
  discharge an obligation but didn't; mirror = an option set *claimed* to be open (multiple live
  alternatives) when only one alternative was structurally live. Both are "a route reaches a
  dispatch carrying authority and no checkability," per the dispatch's own framing.
- Because the mirror case never reaches `.decisions.json` (it was resolved before asking), a
  schema field on the ANSWER (candidate 1) cannot, by itself, be "expressible over" this polarity.
  The natural generalization is a shared obligation-naming discipline applied at the point an
  agent is about to *propose* a `user_decision` at all: before listing `options`, name why each
  option is not already structurally excluded by prior artifacts — the same move
  `user-decision-contract.md`'s existing "When NOT to Raise One" bullet ("A prior artifact in this
  task already answered the same question — cite it, don't re-ask") already gestures at, just not
  yet stated as a check against structural exclusion specifically.

### External Resources

Not applicable — this is a closed, internal orchestration-mechanism question with no external
library or documentation dependency. No web research was performed; all findings are grounded in
direct reads of the source store named above.

## Decisions

- **Reconciliation ruling (required by the dispatch): 447's premise-re-validation mechanism does
  NOT already cover a settled route as an acted-on premise.** Scope stays the full three-candidate
  set; this record is not narrowed to candidate (1) alone. Grounds: different read source
  (`description` vs. `.decisions.json`) and different claim shape (lexical carried-figure vs.
  obligation-discharge). Recorded above under Findings with the specific code/doc citations.
- **Mechanism ruling: prefer (1)+(3) over (1)+(2).** The dispatch's own preference order
  ("(1)+(2) if the validation in (2) can be made cheap; fall back to (1)+(3) if it cannot") is
  honored, but the basis for ruling (2) out is sharper than cost: it is the architectural
  precedent already on record in this exact composer script (Owner ruling: composer emits,
  receiving agent adjudicates; general conflict detection explicitly excluded in writing one
  section away). A planner implementing (2) anyway would need to either (a) build a narrow,
  case-specific lexical check that only catches the cited shape (a named-entity match between the
  decision's answer and a contrary-dependency statement already present in the plan's own
  findings) — which is "cheap and specific" exactly as the dispatch describes, but does not
  generalize and does not discharge the obligation for any future incident shaped differently — or
  (b) build a general semantic validator, which repeats a pattern this codebase has already
  rejected. (1)+(3) avoids both horns: the schema field makes the claim recordable and
  greppable, the contract amendment requires it to be named, and the receiving agent — who has the
  phase's own full context, exactly as the Owner ruling already assigns for the adjacent
  mechanism — verifies it and raises a NEW, specific blocking question if the route does not hold.
- **The schema field must be optional and additive**, following the `description_fingerprint`
  precedent exactly: a two-branch `jq -c -n` call in `orchestrate-record-decision.sh`, never an
  unconditional merge; omitted entirely (never empty-string) when the obligation cannot be named;
  a bare four-field legacy entry remains fully valid.
- **The mirror-image fixture is a required test case for whichever mechanism lands**, per the
  2026-11-04 fold's own instruction, and is satisfied at the PROPOSAL side (an amendment to
  `user-decision-contract.md`'s option-naming discipline — "When NOT to Raise One" is the natural
  site), not at the schema side, since the mirror incident never produced a `.decisions.json`
  entry to carry a field on.

## Recommendations

1. **Candidate (1), schema + contract (land first, it is the dependency of everything else):**
   - Add an optional field (name TBD by the planner — `obligation` or `discharges` are reasonable
     candidates) to `.decisions.json` entries via `orchestrate-record-decision.sh`, following the
     `description_fingerprint` two-branch-`jq` pattern exactly. Update
     `handoff-schema.md`'s "Decisions File Schema" section to document it the same way
     `description_fingerprint` is documented there today (shape, writer, omission rule).
   - Amend `user-decision-contract.md`'s Field Shape section: an option offered as a ROUTE (not a
     pure preference) must name the specific obligation it discharges before it may be set as
     `recommended`/`options`. Extend the "When NOT to Raise One" section with the mirror-image
     half: an option is listed only when its alternatives are not already structurally excluded
     by facts already present in the task's own artifacts (prior report/plan findings) — citing
     this task's own folded fixture as the worked example without using a task-number reference in
     the deliverable text itself (per `no-task-references-in-deliverables.md`; cite the mechanism
     by name, not by number, in the landed prose).
2. **Candidate (3), propagation to the implementer (land second, it is additive over (1) and
   needs the field to exist first):**
   - Extend `orchestrate-build-dispatch.sh`'s `## Prior Decisions` emission to render the named
     obligation inline per entry when present (absent-safe: an entry with no obligation field
     renders exactly as today — byte-identical-when-absent, matching the existing
     `description_fingerprint`/premise-revalidation precedent), with an explicit instruction
     block: *verify the chosen route discharges the named obligation before beginning phase work;
     if it does not, return a NEW, specific blocking `user_decision` naming the second obstruction
     — never re-ask the original question.*
   - Do not touch the `## Prior Decisions` heading string or the `POTENTIALLY SUPERSEDED` marker
     logic; both already have consumers and the dispatch's hard constraints forbid changing them.
3. **Rule out candidate (2) as a general mechanism**, recording the Owner-ruling precedent found
   above as the reason, rather than silently dropping it. If a future task wants a narrow,
   case-specific mechanical check for one recurring shape (e.g., a named-entity string match
   between a decision's answer and a plan's own stated contrary-dependency sentence), the known
   insertion seam is `skill-orchestrate/SKILL.md` Move 4's branch, immediately after the
   `orchestrate-record-decision.sh` call and before the next cycle's Move 1 — but this report
   recommends against building that now, given the precedent above.
4. **Test extensions for the planner to schedule** (per the dispatch's VERIFY section, now
   grounded in the specific existing fixtures found):
   - `test-orchestrate-record-decision.sh`: mirror the existing `description_fingerprint`
     fixture shape (legacy four-field entry still validates; new-field entry round-trips;
     object-wrapped file still refused byte-identical; flock/atomic-mv unchanged) for the new
     obligation field.
   - `test-orchestrate-build-dispatch.sh`: mirror the existing Case A/B/C present-absent/empty/
     with-entries fixture group (around its "decisions absent/empty/present-with-entries" tests)
     for the new rendering, plus a dedicated fixture for the regression shape named in the
     dispatch (a recorded answer whose route does not discharge a stated obligation, with the
     contrary dependency already present in the plan's own findings) and the mirror-image fixture
     (an option presented as open whose alternatives are structurally excluded).

## Risks & Mitigations

- **Risk**: amending `user-decision-contract.md`'s "When NOT to Raise One" section to add a
  structural-exclusion check could be read as license to re-litigate. **Mitigation**: the
  dispatch's hard constraint already forbids this; phrase the amendment as a PROPOSAL-TIME
  self-check for the agent about to raise a `user_decision`, never a re-ask instruction for an
  already-recorded answer.
- **Risk**: a planner picks (1)+(2) anyway, re-deriving a narrow lexical check without reading the
  Owner-ruling precedent, and unintentionally reintroduces scope creep toward general semantic
  validation. **Mitigation**: this report names the exact section
  (`report-format.md`'s "Owner ruling — split by capability" paragraph) so the planner can read it
  directly rather than re-derive the same conclusion from scratch.
- **Risk**: the new field name collides with a future unrelated field, or the planner chooses a
  name inconsistent with `description_fingerprint`'s naming convention (snake_case, descriptive).
  **Mitigation**: flag `obligation` (or `discharges_obligation`) as the planner's naming decision
  to make explicitly, not implicitly.
- **Risk (fail-open constraint)**: candidate (3)'s instruction to "return a NEW blocking
  user_decision" if the route does not hold could itself be read as blocking-by-default, in
  tension with the dispatch's "Fail OPEN" hard constraint. **Mitigation**: the fail-open
  constraint governs MECHANICAL validation (candidate 2) failing to determine validity — it is not
  in tension with a receiving AGENT making an actual, informed adjudication that the route does
  not hold and correctly raising a new blocking question; that is the intended, working case, not
  a false refusal.

## Context Extension Recommendations

- **Topic**: Owner-ruling precedent reuse across composer features.
- **Gap**: `report-format.md`'s "Owner ruling — split by capability" paragraph is the only place
  this emit/adjudicate split is stated, and it is scoped to the Premise Re-Validation feature's
  own section. A future composer-touching task (this one included) has to re-derive, via direct
  code read, that the same ruling applies to a structurally similar case. There is no standalone
  cross-cutting standard file stating "the dispatch composer never performs semantic
  validation/adjudication; only emits and points" as a general design principle for this script.
- **Recommendation**: if a third such feature is proposed in the future, consider promoting this
  paragraph's principle out of `report-format.md` (where it reads as scoped to carried figures)
  into a standalone architecture note (e.g., under `docs/architecture/`) that
  `orchestrate-build-dispatch.sh`'s own header comment can point at directly. Not urgent enough to
  block this task; noted for the planner's awareness only.

## Appendix

**Search/read queries used**:
- Direct file reads: `orchestrate-record-decision.sh` (full), `user-decision-contract.md` (full),
  `handoff-schema.md` lines 1075-1129, `orchestrate-state-machine.md` lines 1230-1260,
  `report-format.md` lines 140-274, `skill-orchestrate/SKILL.md` lines 290-330.
- Targeted `grep -n` over `orchestrate-build-dispatch.sh` for: `Prior Decisions`,
  `description_fingerprint`, `POTENTIALLY SUPERSEDED`, `premise_revalidation_block`, `Premise`.
- Targeted `grep -n` over both test files for existing fixture naming (`description_fingerprint`,
  `Prior Decisions`, `POTENTIALLY SUPERSEDED`, Case A/B/C comments) to ground the Recommendations
  section's test-extension guidance in fixtures that actually exist today.
- `jq`/`grep` over `specs/state.json` and `specs/TODO.md` for territory/duplicate-check context
  (project_number 447's current records; cross-references to this task from other backlog
  entries' own duplicate-check prose).

**Key file paths** (source store; re-derive line numbers before editing, per the dispatch's own
provenance instruction):
- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh`
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (search: `prior_decisions_block`, `premise_revalidation_block`)
- `agent-system/extensions/core/context/standards/user-decision-contract.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (`## Decisions File Schema`)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (`## Prior Decisions vs. Current Description: Precedence`)
- `agent-system/extensions/core/context/formats/report-format.md` (`## Carried-Figure Discipline`, "The premise a dispatch acts on", "Owner ruling — split by capability")
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Move 4)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`
