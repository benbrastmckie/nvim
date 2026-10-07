# Plan Artifact Standard

**Scope:** All plan artifacts produced by /plan, /revise, /implement (phase planning), /review (when drafting follow-on work), and related agents.

## Metadata (Markdown block, required)
- Use a single **Status** field with status markers (`[NOT STARTED]`, `[IMPLEMENTING]`, `[PARTIAL]`, `[BLOCKED]`, `[ABANDONED]`, `[COMPLETED]`) per status-markers.md.
- Do **not** use YAML front matter. Use a Markdown metadata block at the top of the plan.
- Required fields: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type.
- Status timestamps belong where transitions happen (e.g., in phases or a short Started/Completed line under the status). Avoid null placeholder fields.
- Standards must reference this file plus status-markers.md, artifact-management.md, and tasks.md.

### Example Metadata Block
```
# Implementation Plan: {title}
- **Task**: {id} - {title}
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/MM_{short-slug}.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: markdown
```

## Plan Metadata Schema

Plans may include a `plan_metadata` object in state.json with fields: `phases` (int), `total_effort_hours` (int), `complexity` (simple/medium/complex), `research_integrated` (bool), `plan_version` (int), `dependency_waves` (array of phase-number arrays for parallel execution groups), and `reports_integrated` (array of `{path, integrated_in_plan_version, integrated_date}` objects). Plans without `reports_integrated` use empty array default.

**Hard-mode skeleton fields** (`--hard` plans only, optional otherwise): `skeleton` (bool, default
`false`) — `true` when this plan's critical path ends in one or more planned strategic-sorry
division points instead of covering full scope with more/larger phases; `follow_up_tasks` (array
of int, default `[]`) — the real, allocated (plain-integer, never dotted) task numbers of the
follow-up tasks created to discharge those division points. The field name `skeleton` reuses
`wrap-up.md`'s implement-time `skeleton` boolean verbatim so plan-time intent and implement-time
outcome are diffable. **No live planning skill or agent currently populates these fields or the
`{{FOLLOWUP:i}}` placeholder-token substitution that used to feed them**: core's own standalone
hard-mode planner (which owned this substitution) is deleted, `--hard` planning for core task
types now resolves to the same `planner-agent` standard mode uses (which never implemented this
mechanism), and no cslib or lean planning agent has ever implemented it either. This schema
section is retained as the field's documented shape for the day a hard-mode planning path is
reintroduced, not as a description of live behavior.

```json
{
  "phases": 5,
  "total_effort_hours": 8,
  "complexity": "medium",
  "research_integrated": true,
  "plan_version": 1,
  "dependency_waves": [[1], [2, 3], [4, 5]],
  "reports_integrated": [
    {
      "path": "reports/01_{short-slug}.md",
      "integrated_in_plan_version": 1,
      "integrated_date": "2026-01-05"
    }
  ],
  "skeleton": false,
  "follow_up_tasks": []
}
```

## Structure
1. **Overview** – 2-4 sentences: problem, scope, constraints, definition of done. May include "Research Integration" subsection listing integrated reports.
2. **Goals & Non-Goals** – bullets.
3. **Risks & Mitigations** – bullets.
4. **Implementation Phases** – under `## Implementation Phases`, preceded by a **Dependency Analysis** wave table (see below), with each phase at level `###` and including a status marker at the end of the heading.
5. **Planned Strategic Sorries** (hard-mode skeleton plans only) – under `## Planned Strategic Sorries`, present only when `plan_metadata.skeleton: true`; see below.
6. **Lean Challenge Statements** (lean/lean4 plans only) – under `## Lean Challenge Statements`, present only when the plan's `task_type` is `lean`/`lean4`; see below.
7. **Testing & Validation** – bullets/tests to run.
8. **Artifacts & Outputs** – enumerate expected outputs with paths.
9. **Rollback/Contingency** – brief plan if changes must be reverted.

**A Rollback/Contingency step that reverts uncommitted work is a snapshot-then-rollback
recipe, not a bare precautionary checkpoint.** When this section calls for taking a
backup of the working tree before a genuine rollback (git reset/checkout/clean or similar),
point at `context/contracts/recovery.md`'s rollback rung for the exact invocation shape,
including its out-of-scope override flag for the deliberate whole-tree case — never emit a
bare `git-snapshot.sh {N}` as a routine start-of-phase precaution; see
`agents/planner-agent.md`'s MUST NOT list for the rationale and `--no-revert`'s alternative
role as a durable, non-reverting checkpoint.

## Implementation Phases (format)
- Heading: `### Phase N: {name} [STATUS]`
- Valid `[STATUS]` values: `[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`,
  `[COMPLETED WITH EXCLUSIONS]`, `[PARTIAL]`, `[BLOCKED]`. See "Plan-level vs. phase-level
  markers" below for the three-way distinction between `[COMPLETED]`, `[PARTIAL]`, and
  `[COMPLETED WITH EXCLUSIONS]`, and status-markers.md's `[COMPLETED WITH EXCLUSIONS]`
  subsection for the full outcome definition and admission test.
- Under each phase include:
  - **Goal:** short statement
  - **Tasks:** bullet checklist
  - **Timing:** expected duration or window
  - **Depends on:** phase numbers this phase requires (e.g., `none`, `1`, `1, 3`). Absence means sequential (depends on all prior phases).
  - **Verification Tier:** (required) one of `prose`, `local`, `interface`, `full` — see
    `## Verification Tiers` below for the full vocabulary and blind-spot definitions.
  - **Commit Mode:** (optional, default `per-substep`) `per-substep` or `atomic-batch` — see
    `## Verification Tiers` below.
  - **Scope Hypothesis:** (conditional — required whenever the phase asserts a count, an
    enumerated file list, or a scope estimate) — see `## Verification Tiers` below.
  - **Files to modify:** (required) the phase's file list, one `- \`path/to/file\`` entry per
    line, each optionally followed by ` - {what changes}` free text that is not part of the path;
    a wrapped continuation line belongs to the preceding entry rather than starting a new one; a
    line that is not a backtick-path entry (for example a "none planned" prose sentinel)
    contributes no path. This formalizes an already-universal convention — the planner template
    emits it unconditionally directly after **Scope Hypothesis** — rather than introducing a new
    one; "required" describes existing practice, not an aspiration. See "Consumers of this field"
    below for who depends on this shape and how.

    A generator may render every per-phase field, including this one, as its own top-level list
    item (a leading `- ` before the bold label, e.g. `- **Files to modify**:`) rather than a bare
    `**Field:**` line — this document's own compact example template (below, under
    `## Implementation Phases (format)`'s worked example) already does this for every field, so
    it is a sanctioned rendering, not a malformed one. The list-item entries under such a header
    are then indented one level (e.g. `  - \`path\``) rather than sitting at column 0. The
    harvester tolerates an optional single leading list-marker on both the header line and each
    entry line; do not treat the indented form as invalid.
  - **Owner:** (optional)
  - **Started/Completed/Blocked/Abandoned:** timestamp lines when status changes (ISO8601). Do not leave null placeholders.

**Field-punctuation tolerance**: generator sites in this codebase use two conventions for phase
field labels — `**Field:**` (colon inside the bold) and `**Field**:` (colon outside the bold).
Both forms are accepted for every per-phase field above, including `**Verification Tier**:` /
`**Verification Tier:**` and `**Files to modify**:` / `**Files to modify:**`; do not treat one
form as invalid because a generator site used the other.

**Consumers of this field**: `Files to modify` has three independent consumers, two of which
depend only on the heading string, not on list-item shape:

- `agents/general-implementation-agent.md` — reads "Files to modify/create per phase" when
  extracting from the plan (heading-name stability only).
- `scripts/orchestrate-cycle-plan.sh` — composes the H1 territory block's `owned_files` by
  pointing an agent at the phase's `Files to modify` location; it does not parse the list itself
  (heading-name stability only). `skills/skill-orchestrate/SKILL.md` calls this script for its
  dispatch-file composition rather than carrying its own independent copy of the territory logic
  (confirmed live — `SKILL.md` has no "territory" or "Files to modify" text of its own), so this
  is one consumer, not two, despite the two-file split a prior draft of this section assumed.
- `scripts/plan-file-scope-harvest.sh` — the one consumer that actually depends on list-item
  shape: it parses each phase's block to harvest `active_projects[].file_scope` at plan-postflight
  time.

**The heading text `Files to modify` is frozen.** The first two consumers above embed it
verbatim in a prompt directive or a ported grep, where a mismatch fails silently with no parse
error — never rename or rephrase this heading without auditing both.

**Consumers of this heading contract**: the exact `### Phase N: {name} [STATUS]` shape above is
parsed by three independent mechanisms, so a future change to the format must account for all
three: `update-phase-status.sh` (mutates a single phase's status in place), `update-plan-status.sh`
(the plan-level status-field equivalent), and `update-task-status.sh`'s opt-in `--phase-check`
backstop (counts conforming headings across the whole plan to decide whether an implement
postflight transition may proceed). All three treat this heading — never the `- [ ]`/`- [x]`
task checklist — as the authoritative phase-completion signal. The plan-level `- **Status**:`
field parsed by `update-plan-status.sh` has its own, separate trailing-text rule — see
"Trailing annotations on the plan-level Status line" under "Plan-level vs. phase-level markers"
below; the two grains are cross-referenced but not conflated.

### Canonical phase-heading shape

The phase-number portion of `### Phase N: {name} [STATUS]` is `{N}`, an integer with **at most
one optional decimal sub-level**: `3` or `3.1` are both valid; `3.1.2` is not. This is the one
canonical shape every consumer below is written against — copy it verbatim rather than
re-deriving a pattern at a new call site.

**Letter-suffixed sub-phases (`3a`) are deliberately not supported by any consumer and must not
be used.** This is a decision, not an unimplemented feature: no script or agent in this codebase
recognizes a letter suffix on a phase number, and none is planned to. Decimal sub-phasing (`3.1`)
is the only supported sub-phase form. **This prohibition was re-affirmed, not merely repeated**,
after a triggering artifact used `3a`/`3b`/`3c`: the general fix for that observed gap is loud
non-conformance detection (below) rather than a widened grammar, because widening admits exactly
one new token shape and leaves the next unanticipated one (`3-alt`, `III`) just as silent as
before. An author reaching for `3a` should write `3.1` instead.

**Non-conforming headings**: a line matching `^### Phase ` whose number token or status marker
falls outside the canonical vocabulary on this page produces a loud, named, per-heading warning
at every accounting site, and renders the enclosing count INCONCLUSIVE. It is never silently
dropped, collapsed into an adjacent number, or counted toward either TOTAL or DONE. This is a
closed contract, not an aspiration: `scripts/lib/phase-heading-patterns.sh` is the one sourced
anchor implementing it, and every consumer site listed below either sources that library or is
documented as deliberately parameter-driven.

**Ordering obligation for filtered scans**: a `PHASE_HEADING_ERE`-filtered grep admits conforming
headings only, so a non-conforming heading is not merely unmatched by it — it is **invisible** to
it. A consumer that derives a **selection or a count** from such a filtered grep must therefore
call `has_nonconforming_phase_headings` over the **whole file first**, before the filtered scan,
and take a named INCONCLUSIVE branch on a hit; checking conformance only on the filtered result
(rather than the whole file) leaves the check structurally unreachable. This is not a new rule —
it is what "closed contract, not an aspiration" above requires end-to-end — but it is worth
stating explicitly because the failure mode is silent: the resume-scan sites now run
`has_nonconforming_phase_headings` before selection, closing the gap. Sites that stop hard on an
inconclusive scan (`skill-lean-implementation-hard`'s resume-point scan — a single-shot leaf
worker whose check runs strictly before any subagent is dispatched, so no handoff write is owed
yet; core's own standalone hard-mode implementer skill once had an equivalent scan, before it was
merged into `skill-orchestrate` and deleted) are deliberately postured differently from the
long-running orchestration loop (`skill-orchestrate`'s H1 per-phase dispatch branch), which
instead routes an inconclusive scan to its own established `EXIT (partial, ...)` terminal-condition
convention rather than a raw process exit — the difference is leaf-worker precondition vs.
orchestration-loop terminal state, not an inconsistency.

**`[DESCOPED]` is not a recognized phase-heading status marker and must not be used.** Whole-phase
descoping uses `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record (below)
enumerating 100% of the phase's remaining items — see `context/standards/status-markers.md`'s
`[COMPLETED WITH EXCLUSIONS]` subsection for why "all remaining items" is a valid, intended case
of that outcome's five-condition admission test rather than a degenerate one.

**Canonical regex forms** (copy verbatim; do not re-derive):

| Form | Pattern |
|------|---------|
| ERE (`grep -E`) heading match | `^### Phase [0-9]+(\.[0-9]+)?:` |
| ERE phase-number extraction | `grep -oE '^### Phase [0-9]+(\.[0-9]+)?' \| grep -oE '[0-9]+(\.[0-9]+)?'` |
| BRE (`grep`, no `-E`) heading match | `^### Phase [0-9][0-9]*\(\.[0-9][0-9]*\)\{0,1\}:` |

These forms, the closed six-value status-marker enum, and the non-conforming-heading detector are
all exported from `scripts/lib/phase-heading-patterns.sh` — the single sourced anchor for this
grammar. Do not re-derive an inline pattern at a new call site; source the library instead.

**Consumer sites of this shape** (blast radius for any future change to it): found live by
`grep -rl 'phase-heading-patterns.sh' agent-system/extensions` — the same self-verifying
"grep for sourcers" mechanism `task-reference-patterns.sh`'s consumers are found by, replacing a
hand-maintained prose list here that was already demonstrably incomplete. As of the library's
introduction this includes `update-task-status.sh`'s `count_plan_phases()` (TOTAL/DONE
phase-accounting regexes), `scripts/validate-artifact.sh` (phase-presence check, phase-line
enumeration, phase-number extraction, and marker-enum validation), `update-phase-status.sh`
(the one deliberately parameter-driven site), `general-implementation-agent.md`'s Stage 5a
marker-repair block (both effort modes — core's own standalone hard-mode implementation agent is
deleted and merged into this one),
`commands/task.md`'s `/task --review` Step 3 phase enumeration, `skill-lean-implementation-hard`'s
resume-point scan, and `skill-orchestrate`'s recovery-count and `next_phase` greps (both effort
modes, one engine). Reference sites by
script/skill and function/stage name, never by line number — line numbers drift on every edit and
are not a stable anchor.

## Dependency Analysis (format)

Place a **Dependency Analysis** wave table immediately after `## Implementation Phases` and before the first `### Phase`. Columns: **Wave** (execution order), **Phases** (can run in parallel within wave), **Blocked by** (prerequisite phases, `--` for none). Generate from per-phase `Depends on` fields. For fully sequential plans, each wave contains one phase.

```
**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.
```

## Verification Tiers

Every phase declares how broadly verification must run *during* the phase, matched to what its
edit class can actually break. This replaces an implicit "one strictness for everything" default
that made a comment-only phase pay a full-build-per-file toll. The tier set is **named and
ordered** — not numeric — so it cannot collide in polarity with the numeric Tier 1/2/3 system in
`context/contracts/reference-grounding.md` (where Tier 1 is strictest; see that file's
cross-reference note for how the two systems relate):

    prose  <  local  <  interface  <  full

Every tier below the top states what it does NOT cover, so a reader can see exactly what the
final gate remains responsible for catching.

| Tier | Applies to | In-phase verification | Does NOT cover (blind spot) |
|------|------------|------------------------|------------------------------|
| `prose` | Edits confined to comments, docstrings, markdown/prose, and other non-code text with zero compile or elaboration surface | Diff read-through confirming every changed hunk lies inside a comment/string/prose region | An edit that crosses out of the comment or string boundary; a doc-comment that is actually load-bearing (doctest, attribute, annotation, pragma) and does compile; broken cross-references or links |
| `local` | Edits confined to one module/file with no change to any externally visible signature | Build or lint of that single module only | Dynamic, untyped, or reflective call sites; behavior changes visible to other modules through unchanged signatures; downstream test failures; anything requiring the full test suite |
| `interface` | Changes a symbol's name, type, arity, or argument order where call sites span multiple files | Build of the changed module plus its enumerated direct dependents | Transitive breakage beyond the enumerated one-hop dependent set; semantic (non-type-level) downstream behavior change; the full test suite; import-graph and init-level checks |
| `full` | Edits that can change runtime, proof, or elaboration behavior anywhere: shared tactics, core types, global config | The complete gate set for the repository: `bash .claude/scripts/verify-deploy.sh` (source-store path: `agent-system/extensions/core/scripts/verify-deploy.sh`) | Nothing is deferred past this tier. This is the ceiling |

**Tie-break rule**: When uncertain, apply the strictest applicable tier (full > interface > local > prose).

**Non-negotiable invariant**: tiering governs GRANULARITY ONLY — how often and how broadly
verification runs *during* a phase. The full gate set still runs before a phase closes and before
a task completes, unchanged. `full` is textually identical in strictness to today's existing
requirement; tiers `prose`, `local`, and `interface` are added *below* it and redefine nothing
about it. A tiering scheme that weakens the final gate is wrong, not a trade-off.

A phase declaring `full` names `bash .claude/scripts/verify-deploy.sh` — or the complete set of
gates it aggregates — in its own verification criteria. A `full` declaration whose task list
reaches only a hand-picked subset of validators does not satisfy the tier, however plausible the
subset looks in isolation.

### Commit modes

An orthogonal axis: a tier answers *how broad* verification must be; commit mode answers *at
what commit boundary* it is taken. The two fields are independent — `prose` + `atomic-batch` and
`interface` + `atomic-batch` are both legitimate combinations.

- `per-substep` (default): the existing Commit-Per-Green-Substep Mandate applies unchanged. See
  `rules/git-workflow.md`'s `### Commit-Per-Green-Substep Mandate` section, the authoritative
  home of this mode's rules.
- `atomic-batch`: the phase's declared file set is one `progress-file.md` objective; intermediate
  per-file states are expected red and MUST NOT be committed. See `rules/git-workflow.md`'s
  `### Commit-Per-Green-Substep Mandate` section for the full carve-out, including the
  anti-abuse guard against retroactively widening a batch — this document does not restate that
  language, so the two cannot drift into conflict.

### Counts-are-hypotheses obligation

Any count, file list, or scope estimate asserted in a plan is a hypothesis requiring
implementation-time confirmation, never a fact. When a phase asserts one, it carries a
**Scope Hypothesis:** line stating the hypothesis and how to confirm it at implementation time.
The implementation-side gate that consumes this obligation (i.e., that mechanically checks a
confirmation happened) is a separate, out-of-scope concern for this document — this section
defines the planner-side carrier field only.

**Carried figures are a different object from this obligation, and are at least as strict.** A
count, citation, command output, or mechanical claim *carried into this plan from another
record* (a research report, a prior plan version, another task's artifact, the task
description) is not the forward-looking estimate governed above — it is subject to the Carried-
Figure Discipline in `context/formats/report-format.md`: re-derive at authoring time, or mark
`CARRIED-UNVERIFIED` with the source named. The two obligations are complementary, not
alternatives: `**Scope Hypothesis**:` governs a claim this plan makes about future
implementation-time state; carried-figure discipline governs a claim this plan repeats from an
already-written record. A plan MAY discharge the re-derivation half through its own
`**Scope Hypothesis**:` line when re-deriving at plan-authoring time is genuinely not cheap,
provided that line names both the carried figure and the record it came from; a Scope Hypothesis
naming neither does not discharge it. The strictness ruling, stated explicitly: a plan is held
at least as strictly as a report, because a plan's figures drive execution — a stale carried
figure in a plan becomes a wrong action, not only a wrong belief.

**`**Scope Hypothesis**:` is deliberately not a harvest source for `file_scope`.** It is free-form
prose about a claim to confirm, not a structured file enumeration; the structured carrier for a
phase's file list is `Files to modify` (see "Consumers of this field" above), and
`plan-file-scope-harvest.sh` reads only that field.

### Enforcement level

Per-phase tier enforcement in `scripts/validate-artifact.sh` is **advisory-first**: a missing
`**Verification Tier**:` field emits a warning, not an error, so default-mode validation of
plans authored before this vocabulary existed continues to pass. `--strict` mode enforces it
today. **Promotion criterion**: promote the warning to an error once no non-terminal plan under
`specs/` lacks the field. This is recorded here for a future task to execute; it is not done by
the task that introduced this vocabulary. A separate, not-yet-built companion check is recorded
here for the same future execution: today's enforcement checks only the field's *presence*,
never whether a phase declaring `full` actually reaches a full-gate invocation in its own task
list — a plan-file content lint over that gap is a named future item, not yet built.

## Planned Strategic Sorries (format, hard-mode skeleton plans only)

Present only when `plan_metadata.skeleton: true` (see Plan Metadata Schema above). Placed
immediately after `## Implementation Phases`. Its columns map field-for-field to the `wrap-up.md`
`sorry_inventory` schema `{file, line, statement, strategic, assumption, why_deferred,
follow_up_task}` — reuse these field names verbatim; do not redefine, rename, or invent a
parallel schema. `strategic` is not a column because every row in this table is, by definition,
a planned strategic-sorry division point (`strategic: true` is implicit for the whole table).

```
## Planned Strategic Sorries

| Division Point | File / Line / Statement | Assumption | Why Deferred | Follow-Up Task |
|-----------------|--------------------------|------------|---------------|----------------|
| {short label}   | TBD (plan-time provisional; confirmed by implementer) | {assumption} | {why_deferred} | {{FOLLOWUP:i}} |
```

- **Division Point**: short label identifying the division point (not a `sorry_inventory` field
  itself; provided for readability/cross-reference from phase text).
- **File / Line / Statement**: plan-time provisional, collapsed into one cell — write `TBD` (or a
  best-guess target file) until the implementer places the actual sorry and fills in `file`/
  `line`/`statement` in the implement-time `sorry_inventory`.
- **Assumption**: maps to `sorry_inventory.assumption` — fixed at plan time.
- **Why Deferred**: maps to `sorry_inventory.why_deferred` — fixed at plan time.
- **Follow-Up Task**: maps to `sorry_inventory.follow_up_task` — a plain-integer task-number
  string once resolved (never dotted, e.g. never `"774.2"`); documented as written by a planning
  agent as the literal placeholder token `{{FOLLOWUP:i}}` and substituted with the real allocated
  task number at postflight — see the "Hard-mode skeleton fields" section above for why no live
  planning path currently performs this substitution.

**Deviation flag**: An implementer-placed strategic sorry that does NOT correspond to a row on
this table is a plan-unanticipated deviation. It is evaluated under a weaker claim on the
`anti-analysis.md` 5-condition strategic-sorry test's condition 1 (not pre-declared) and MUST be
flagged in the implementation summary, not silently accepted as equivalent to a planned one.

## Lean Challenge Statements (format, lean/lean4 plans only)

Present only when the plan's `task_type` is `lean`/`lean4` — mirroring how
`## Planned Strategic Sorries` above is gated on `plan_metadata.skeleton: true`; this is not a
novel conditional-section shape, the precedent already exists in this same file. Non-lean plans
are completely unaffected by this section's existence: it is purely additive to the shared
`- **Goals**:`/`- **Non-Goals**:` bullet format defined under `## Goals & Non-Goals` above, which
remains unchanged for every task type.

This section exists to fix the *statement* of each theorem a lean plan commits to, not merely its
*identifier*. `- **Goals**:` bullets name identifiers only (a backtick-delimited list, e.g.
`` `comm` ``); this section carries the literal, exact signature each identifier resolves to, with
a `sorry` body, so a downstream tool (`lean-challenge-snapshot.sh` — see
`context/project/lean4/domain/challenge-snapshot.md` for the full design record) can turn a
plan into a trusted, immutable Challenge module *before* the implementation agent runs.

```
## Lean Challenge Statements

```lean
import Mathlib.Algebra.Group.Basic

theorem comm (n m : Nat) : n + m = m + n := sorry
```
```

- One or more ```` ```lean ```` fenced blocks. When more than one is present, they concatenate **in
  document order** to form the Challenge module body.
- Every declaration body in every block MUST be `sorry` — this section pins statements only, never
  a real proof. A snapshot tool consuming this section forces the body to `sorry` regardless of
  what the block actually contains, so authoring a non-`sorry` body here is harmless but
  discouraged (it does not do what it looks like it does).
- **The identifier set declared here MUST equal the identifier set named under `- **Goals**:`.**
  This is a hard requirement, not a style preference: a snapshot tool cross-validates the two sets
  and fails loudly on any disagreement (naming the specific identifiers unique to each side)
  rather than silently unioning, intersecting, or ignoring the mismatch. A plan that intends to
  prove `comm` and `assoc` must name both `comm` and `assoc` in this section's declarations, no
  more and no fewer.
- Include whatever `import` lines each fenced block needs to type-check standalone as an isolated
  Challenge module — this section is the sole source of import context for the assembled module,
  distinct from (and not automatically inherited from) any other file in the target project.

## Reasoned Exclusions (format)

Present whenever a phase heading carries `[COMPLETED WITH EXCLUSIONS]` (see
status-markers.md's `[COMPLETED WITH EXCLUSIONS]` subsection for the outcome's semantics and
five-condition admission test). Unlike `## Planned Strategic Sorries` above, this record is a
**per-phase subsection nested at `####` inside the phase body** — not a document-level `##`
section — because exclusions are phase-scoped by definition, whereas a skeleton's sorries span
phases.

```
#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| {the excluded item} | {why it is not applicable} | {what confirms the reason -- command output, quoted match count, diff excerpt, or artifact reference} |
```

**Required**: this subsection is REQUIRED whenever the phase heading carries
`[COMPLETED WITH EXCLUSIONS]`. Its minimum columns are `Item`, `Reason`, `Evidence`.

**Field mapping to `sorry_inventory`**: this table is a field-for-field generalization of the
`wrap-up.md` `sorry_inventory` schema, so the family reads as one concept:
- `Item` generalizes `file`/`line`/`statement` to any domain — not every excluded item is a code
  location.
- `Reason` generalizes `assumption` + `why_deferred` into a single justification column.
- `Evidence` is the new obligation with no sorry-side counterpart: a sorry is *tracked* by a
  `follow_up_task`; an exclusion is *closed* by evidence instead.

`follow_up_task` is deliberately absent from this table. Its absence is the defining difference
between the two family members: a strategic sorry is deferred with a tracked follow-up, a
reasoned exclusion is decided and will not be revisited, so there is nothing to track.

**Relationship to Scope Hypothesis**: a reasoned exclusion is structurally the closing act of a
**Scope Hypothesis** (see "Counts-are-hypotheses obligation" above) whose asserted count turned
out to be an overcount — the Evidence column is where that confirmation lands. The record may be
written at plan time, as a pre-emptive declaration alongside the phase's Scope Hypothesis line, or
discovered mid-phase at implement time, with implement-time entries confirming or superseding any
plan-time hypothesis.

### Decision gates and contingency branches

A plan may — and routinely should — carry a **decision gate**: a phase whose own verification
measures a criterion (a sweep result, a benchmark, a comparison against a baseline) that decides
which of two downstream branches the rest of the plan takes. When the gate's criterion fails and
the plan's own contingency branch is taken instead of the phases the gate would otherwise have
unlocked, those bypassed phases are closed as `[COMPLETED WITH EXCLUSIONS]`, each with a
`#### Reasoned Exclusions` record (above) whose `Evidence` column cites the gate's own failing
measurement.

This is the intended representation, not a workaround — see status-markers.md's
`[COMPLETED WITH EXCLUSIONS]` subsection for the outcome's full five-condition admission test and
its "whole-phase exclusion is a valid, intended case" paragraph. A decision-gate/contingency-branch
plan is exactly the shape that test satisfies: the gate's failure is a deliberate decision (not
abandonment), tightly scoped to the bypassed phases, reasoned, evidenced by the gate's own
measurement, and leaves no residual work once the contingency branch runs instead.

**Worked example** (a seven-phase plan whose gate fails):

```
### Phase 1: Rerunnable Harness and Pre-Change Baseline [COMPLETED]
### Phase 2: Twenty-Plus-Seed Sweep of the Renamed Construction [COMPLETED]
### Phase 3: Land the Alpha-Rename in core.py [COMPLETED WITH EXCLUSIONS]

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Land the alpha-rename | Phase 2's gate failed (5/25 undecided vs. 2/25 baseline); the plan's own contingency branch (Phase 7) was taken instead | Sweep measurement recorded in Phase 2's own report |

### Phase 4: Full Example-Set Regression Diff [COMPLETED WITH EXCLUSIONS]
### Phase 5: Full Bimodal Suite and Gating Oracle Suite [COMPLETED WITH EXCLUSIONS]
### Phase 6: Correct the Stale Claims and Record the History [COMPLETED]
### Phase 7: CONDITIONAL -- Revert and Author an UNSTABLE entry [COMPLETED]
```

(Phases 4 and 5 each carry their own `#### Reasoned Exclusions` record, omitted above for
brevity, each citing the same Phase 2 measurement.)

**Do not leave the bypassed phases `[NOT STARTED]`.** A `[NOT STARTED]` phase is exactly what
deadlocks the completion gate: it reads as "not yet begun, resumable" to every phase-accounting
consumer, so a task whose contingency branch has already run and will never revisit that branch
is held open forever. `[PARTIAL]` is equally wrong here — nothing about the bypassed phases is
resumable or in progress; they were decided against, not interrupted.

## Status Marker Requirements
- Use markers exactly as defined in status-markers.md.
- Every phase starts as `[NOT STARTED]` and progresses through valid transitions.
- Include timestamps when transitions occur; avoid null/empty metadata fields.
- Do not use emojis in headings or markers.

### Plan-level vs. phase-level markers

The plan-level **Status** field (Metadata block, above) and the per-phase heading marker
(`### Phase N: {name} [STATUS]`, Implementation Phases format, above) are two distinct
vocabularies at two distinct grains, and their divergence is intentional, not an oversight:

- Plan-level Status uses the six markers `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED,
  ABANDONED, COMPLETED}` — a subset of the fuller task-level vocabulary defined in
  status-markers.md.
- `ABANDONED` is deliberately plan/task-level only. No code path abandons a single phase while
  leaving sibling phases active — abandonment is a whole-document decision, so phase headings
  have no `[ABANDONED]` marker.
- Plan-level `[PARTIAL]` is an aggregate "this document is stalled/resumable" signal covering the
  whole plan. It is distinct from, and fully compatible with, any individual phase heading
  simultaneously carrying its own `[PARTIAL]` marker (e.g. a phase interrupted by context
  exhaustion) — the two `PARTIAL`s describe different grains of the same document and do not need
  to move together.
- Phase-heading markers additionally include `[COMPLETED WITH EXCLUSIONS]`, a phase-heading-only
  outcome absent from both the task-level vocabulary and the plan-level Status subset above. The
  three-way distinction: `[COMPLETED]` = nothing was excluded; `[PARTIAL]` = work remains and is
  resumable; `[COMPLETED WITH EXCLUSIONS]` = every remaining item was decided, justified, and will
  not be revisited. See status-markers.md's `[COMPLETED WITH EXCLUSIONS]` subsection for the full
  admission test and `## Reasoned Exclusions` above for its required record format.

#### Trailing annotations on the plan-level Status line

The plan-level Status line MUST begin `- **Status**: ` followed immediately by a single
`[...]` pair drawn from the six-value vocabulary above. Arbitrary trailing text after the
closing `]` is **accepted and preserved** across status transitions — this is what makes a
resumed plan's annotation (e.g. noting which phases were re-opened) survive a later stamp. Text
between the prefix and the opening `[`, or a line with no bracket pair at all, is malformed and
rejected loudly rather than silently accepted or silently ignored.

- **Accepted** (trailing annotation preserved verbatim across a stamp):
  `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)`
- **Rejected** (text intrudes before the bracket, not after it):
  `- **Status**: see [NOTE]`

`update-plan-status.sh` is the enforcing consumer. A malformed line produces a line-numbered
diagnostic to stderr naming the specific failing condition (missing `- **Status**:` prefix, no
bracket pair, or unexpected text before the bracket) and quoting the offending line verbatim,
rather than a single undifferentiated failure message.

See status-markers.md for the full task-level vocabulary and the cross-reference to this
subsection.

## Writing Guidance
- Keep phases small (1-2 hours each) per task-breakdown guidelines.
- Be explicit about dependencies and external inputs.
- Include lazy directory creation guardrail: commands/agents create the project root and `plans/` only when writing this artifact; do not pre-create `reports/` or `summaries/`.
- Keep language concise and directive; avoid emojis and informal tone.

## Example Skeleton
```
# Implementation Plan: {title}
- **Task**: {id} - {title}
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: None
- **Artifacts**: plans/MM_{short-slug}.md (this file)
- **Standards**: plan.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: markdown

## Overview
{summary}

## Goals & Non-Goals
- **Goals**: ...
- **Non-Goals**: ...

## Risks & Mitigations
- Risk: ... Mitigation: ...

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: {name} [NOT STARTED]
- **Goal:** ...
- **Tasks:**
  - [ ] ...
- **Timing:** ...
- **Depends on:** none
- **Verification Tier:** local

### Phase 2: ... [NOT STARTED]
- **Depends on:** 1
- **Verification Tier:** interface
- **Commit Mode:** atomic-batch
...

## Testing & Validation
- [ ] ...

## Artifacts & Outputs
- plans/MM_{short-slug}.md
- summaries/NN_{short-slug}-summary.md

## Rollback/Contingency
- ...
```
