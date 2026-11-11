# Plan Artifact Standard

**Scope:** All plan artifacts produced by a plan-phase dispatch, /revise, an implement-phase dispatch (phase planning), /review (when drafting follow-on work), and related agents.

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
6. **Lean Challenge Statements** (lean/lean4 plans only) – under `## Lean Challenge Statements`, present only when the plan's `task_type` is `lean`/`lean4`; see below (including the zero-Lean-goals marker shape for a plan with no theorem deliverable).
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
  - **Tier Justification:** (conditional — required on every non-final phase, omitted on the
    final phase) — one sentence naming the specific covering check (for a tier below `full`) or
    the specific cross-cutting surface no cheaper tier covers (for a non-final `full`). See
    `## Verification Tiers` below for the full field spec, the two narrowing mechanisms, and the
    `__FULL_SWEEP__` honesty case.
  - **Files to modify:** (required) the phase's file list, one `- \`path/to/file\`` entry per
    line, each optionally followed by ` - {what changes}` free text that is not part of the path;
    a wrapped continuation line belongs to the preceding entry rather than starting a new one; a
    line that is not a backtick-path entry (for example a "none planned" prose sentinel)
    contributes no path. This formalizes an already-universal convention — the planner template
    emits it unconditionally directly after **Scope Hypothesis** — rather than introducing a new
    one; "required" describes existing practice, not an aspiration. See "Consumers of this field"
    below for who depends on this shape and how.

    **One path per line; a continuation line belongs to the preceding entry.** Each real path
    takes its own `` - `path` `` line. The anti-pattern is two shapes that both silently drop a
    path rather than erroring: a second backtick-delimited path joined onto the same entry line
    by a comma (only the first survives harvest), and a wrapped continuation line that itself
    begins with a backtick but carries no leading `- ` marker (it contributes nothing — it is
    read as prose, not as a second entry). Widening the harvester's grammar to recover either
    shape was considered and rejected (a token scan would also sweep in an unrelated
    backtick-quoted token sitting in the same block's free prose, trading a silent drop for
    silent garbage); the authoring fix is to give every real path its own `` - `path` `` line.

    **Never name a deployed-tree (`.claude/**`) path directly in this list.** `.claude/` is a
    gitignored, disposable deploy artifact regenerated from this source store
    (`rules/source-store-deploy-boundary.md`); a `file_scope` entry naming a path under it is
    never legitimate; and `scripts/plan-file-scope-harvest.sh` enforces this with a loud
    drop-and-warn refusal. A phase whose steps touch the deployed tree only by *invoking*
    whole-tree regeneration declares that honestly with the `` `__WHOLE_TREE__` `` sentinel
    instead — see "Whole-tree-claim declaration rule" below.

    **The sanctioned way to name a source-store file is the path exactly as it is spelled on
    disk.** A deliverable whose real home is an extension's source store
    (`.claude-extensions.json`'s per-extension `source_dir`) is named with the ordinary
    source-store-relative form already in universal use —
    `agent-system/extensions/<name>/path/inside/it` — never a shell variable standing in for
    `source_dir`'s own value. This form needs no new notation: it is already an ordinary in-repo
    path in the repository that owns the source store, and `scripts/lib/source-store-path-lib.sh`
    classifies it correctly wherever the source store resolves to a different repository (see
    `context/standards/git-staging-scope.md`'s different-repository containment nuance).

    **An unexpanded shell variable is never a legitimate entry, and is refused at harvest time.**
    A `$VAR` or `${VAR}` form standing in for a value — no assignment for it runs anywhere on the
    commit path — matches nothing downstream and is silently useless. `scripts/plan-file-scope-harvest.sh`'s
    final refusal stage drops any such entry with a loud, non-fatal warning naming the entry and
    the sanctioned alternative above, alongside its existing deployed-tree refusal (both compose
    over the same final merged array); `scripts/validate-artifact.sh`'s authoring-shape advisory
    scan flags the same shape earlier still, at plan-acceptance time, without failing the
    artifact. Neither refusal is one specific invented token — both are shape-based, so a future
    invented variable spelling is refused the same way a known one is.

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
- `scripts/validate-artifact.sh` — a fourth consumer, added later than the three above (see the
  "Enforcement level (Files to modify)" subsection below under `## Verification Tiers`), and the
  only one of the four that distinguishes "no `Files to modify` header anywhere in this phase"
  from the legitimate "header present, zero paths" sentinel case — the other three, and the
  harvester itself, treat both shapes identically.

**The heading text `Files to modify` is frozen.** The first two consumers above embed it
verbatim in a prompt directive or a ported grep, where a mismatch fails silently with no parse
error — never rename or rephrase this heading without auditing both.

**Correction-target existence obligation.** `Files to modify` names two different kinds of
target under one flat list: a path the phase will CREATE, and a path that already exists and
that the phase will CORRECT, AMEND, or RETIRE. Only the second kind carries an existence
obligation.

*(a) The general rule.* When a plan names an existing artifact as the thing to correct, amend,
or retire, the author confirms at authoring time that it exists, and the entry's annotation
states what the implementer does if it turns out not to. A correction task against a path that
is absent is not a task; it is a sentence that cannot be executed, leaving the implementer only
the choice of skipping it or inventing a target — neither of which is a sound substitute for
authoring-time confirmation.

*(b) The stronger prohibition, for a dispatch-created sidecar.* A plan MUST NOT make a phase's
goal turn on correcting a machine-written orchestration sidecar — a file whose existence is
contingent on whether a particular auxiliary dispatch has run, and whose content, if it appears
at all, is written by that dispatch rather than by anyone the plan can consult. The sanctioned
carrier for a route decision, a retirement, or a withdrawn recommendation is the durable record
instead: the task's own description in `specs/state.json`, or a file under that task's
`records/` directory. Name the carrier the phase actually updates, not a sidecar the plan cannot
guarantee is present.

An artifact's existence is a quantity the plan does not control, so a plan that assumes it —
in either direction, present or absent — is wrong the moment the quantity moves. This is the
general reason behind rule (a): authoring-time confirmation is a check against the world as it
stood at authoring time, not a guarantee that holds at implementation time, so the entry's
annotation must still say what to do if that check stops matching the world by the time the
phase runs.

**Whole-tree-claim declaration rule.** A phase whose steps invoke whole-tree regeneration (the
deploy script, or the extension picker's reload/regenerate entries) MUST additionally declare
the reserved sentinel `` `__WHOLE_TREE__` `` as its own entry in that phase's `Files to modify`
block, alongside whatever real files the phase also lists. This is the producer-side half of the
whole-tree-claim admission dimension `orchestrate-batch-admit.sh` reads
(`defer_reason: "whole_tree_claim"`): regenerating the entire deployed tree is an implicit scope
claim over that whole tree, which no real declared path can express, so the plan declares the
claim honestly via this one reserved token rather than leaving it undeclarable. The token is
harvested by `scripts/plan-file-scope-harvest.sh` into `active_projects[].file_scope` verbatim,
with **zero parser change** — that script is already path-shape-agnostic, treating every
backtick-delimited entry as an opaque string. The sentinel is deliberately **slashless**, which
makes it structurally **inert** in both consumers of `file_scope` that compare declared paths
against each other: the Overlap predicate (`scopes_overlap_first` in
`scripts/lib/file-scope-overlap.sh`) finds no exact match and no directory-prefix relation
against any real path, and the Containment predicate (`path_covered_by_scope`, consumed by
`git-snapshot.sh`) never treats any real path as falling under `` `__WHOLE_TREE__`/ ``. Two
DIFFERENT plans each declaring this same literal token DO produce an ordinary exact match
against EACH OTHER under `scopes_overlap_first` — that is not a false positive; it is the exact
detection signal the admission dimension reads to recognize a same-claim pair. See
`context/patterns/file-footprint-overlap.md`'s reserved-sentinel note and
`context/patterns/batch-orchestration-guardrails.md`'s whole-tree-claim subsection for the full
mechanism and hazard rationale.

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
`has_nonconforming_phase_headings` before selection, closing the gap. A site that stops hard on
an inconclusive scan — a single-shot leaf worker whose check runs strictly before any subagent is
dispatched, so no handoff write is owed yet — is deliberately postured differently from the
long-running orchestration loop (`skill-orchestrate`'s H1 per-phase dispatch branch), which
instead routes an inconclusive scan to its own established `EXIT (partial, ...)` terminal-condition
convention rather than a raw process exit — the difference is leaf-worker precondition vs.
orchestration-loop terminal state, not an inconsistency. (Two former leaf-worker examples of this
posture — core's own standalone hard-mode implementer skill, and the per-domain `-hard`
implementation skills, e.g. `skill-lean-implementation-hard` — are both now deleted outright:
the former was merged into `skill-orchestrate`'s H1 branch, and the latter's domain-specific
behavior migrated onto `hard_contracts` contract injection into the standard skills, which carry
no equivalent pre-dispatch resume-point scan of their own.)

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
`commands/task.md`'s `/task --review` Step 3 phase enumeration, and `skill-orchestrate`'s
recovery-count and `next_phase` greps (both effort modes, one engine). Reference sites by
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

**The final phase, defined once because the rules below are conditioned on it**: a plan's final
phase is its highest-numbered phase, which MUST be a terminal node of the dependency graph (no
other phase depends on it) and MUST depend, directly or transitively, on every other phase in the
plan. The transitivity requirement is what makes that phase's `full` gate meaningful — it must
observe all of the task's work — and it removes the one ambiguity a bare "terminal node" reading
would leave open: a last wave containing two mutually independent terminal phases would otherwise
yield two candidate "final" phases. A single-phase plan's only phase is its final phase.

**Tie-break rule**: for the final phase, and for genuine uncertainty at any phase, apply the
strictest applicable tier (full > interface > local > prose) — this half of the rule is
unqualified and unchanged. For a **non-final** phase, the tie-break is cost-aware rather than
reflexively upward: state, in `**Tier Justification**:` (below), why the declared tier is the
*cheapest* one that actually covers the edit's blast radius. "Uncertain" and "non-final" are not
the same condition — a non-final phase with a genuinely uncertain blast radius still applies the
strictest tier; the cost-aware half applies only once the blast radius is actually known.

**Why this qualification exists — the cost of guessing wrong is not symmetric.** A `full`
declaration is a real, repeated cost, not a formality: per
`context/contracts/phase-closure.md:167-169`, a phase's declared verification "has been run in
this dispatch and observed green" and is "never trusted on sight" — so every non-final phase that
declares `full` pays a complete gate run, including Gate 8's full shell-suite battery, which is
the dominant cost of that run on a loaded host. See
`context/standards/shell-script-testing.md` for the measured wall-clock figures on an idle versus
a loaded host; this file cites that location by reference rather than restating numbers that go
stale. The tie-break's old, unqualified form optimized only for "never miss a real break" and
ignored this cost entirely, which is why a planner following it correctly landed on `full` by
default for every phase, not only the final one.

**`**Tier Justification**:` — required on every non-final phase, omitted on the final phase.**
The final phase's `full` is mandated by the invariant below, not chosen, so it carries no
justification line. Every non-final phase carries exactly one `**Tier Justification**:` line,
one sentence, never an essay:

- A non-final phase declaring a tier **below** `full` names the specific check that covers the
  edit — the command, not a description of one — and the claim is honest only when the author
  ran `suite_selection_select` over the phase's `Files to modify` paths and the line's suite
  names or sentinel match that output verbatim, never an asserted guess at what the selector
  would return. Two narrowing mechanisms exist today:
  - a suite subset within Gate 8: `bash .claude/scripts/tests/run-all.sh --only SUITE[,SUITE,...]`
    in a deploy-target repository, or `bash agent-system/extensions/core/scripts/tests/run-all.sh --only SUITE[,SUITE,...]`
    as the source-store-repository form — see "Batch-aware deferral" below for the
    resolve-whichever-exists rule governing which of the two names an entry point that actually
    resolves in the repository the dispatch is running in. `scripts/lib/suite-selection-lib.sh`'s
    `suite_selection_select` function resolves a touched path to its covering suite basenames (see
    `context/standards/shell-script-testing.md`'s suite-selection-lib.sh subsection);
  - a gate subset of the full aggregator: `bash .claude/scripts/verify-deploy.sh --only-gate N[,M,...]`.
  - **The `__FULL_SWEEP__` case**: `suite_selection_select` returns the sentinel
    `__FULL_SWEEP__` for a touched path with no mapped suite — this is the normal, expected
    result for a pure-guidance markdown edit (a context/contract/agent-definition file with no
    executable surface), not a tool failure. When it returns the sentinel, **no suite covers
    that file**, and the justification MUST NOT claim one. Claiming the sentinel is itself a
    measurable claim, subject to the same run-and-match obligation as a suite-list claim above: a
    justification asserting `__FULL_SWEEP__` for a path the selector actually maps to one or more
    real suites is exactly as dishonest as a fabricated suite name, not a lesser omission. The
    honest covering check then depends on WHERE the touched path lives — three sub-cases, not
    one:
    - **(a) Every touched path lies entirely under `specs/**`.** `--only-gate 3,4` is never the
      answer here: `specs/**` is the task-reference lint's own exempt tree by design (category 1
      of its taxonomy), and doc-lint has no bearing on `specs/**` content at all. The honest
      check is `bash .claude/scripts/validate-artifact.sh <path> <type>` for a report/plan/
      summary artifact, or — for any other `specs/**` file — the `prose` row's diff
      read-through.
    - **(b) A source-store, non-`specs/**` markdown edit** (a `context/`, `rules/`, `agents/`, or
      similar file under the resolved source store). A gate subset remains the right answer —
      ordinarily `--only-gate 3,4` (doc-lint and task-reference lint) — but the invocation's
      `TARGET` MUST be a repository root that already holds a deployed `.claude/` tree AND the
      `agent-system/extensions` source store simultaneously: `--only-gate 3,4 <source_dir>` (the
      resolved `source_dir` passed as `TARGET`) CANNOT work, because a source-store directory has
      no `.claude/` subdirectory and gate0 exits 2 before gate selection is even consulted. See
      `verify-deploy.sh`'s own `TARGET_REPO CONTRACT` header paragraph for the authority behind
      this requirement — this file is a consumer of that contract, not a second copy of it. The
      no-argument form (`TARGET` defaulting to `$(pwd)`) is correspondingly two-faced rather than
      uniformly unsafe: for an ordinary deploy-consumer dispatch, `$(pwd)` is the consumer repo
      root, which lacks `agent-system/extensions`, so both gates silently SKIP and nothing is
      checked; but when run FROM the source-store repository's own root, `$(pwd)` there is
      simultaneously the deploy consumer and the source store, so it is itself a valid,
      non-skipping `TARGET` — the no-argument form is unsafe only outside that repository.
      Copy-pasteable shape, with `TARGET` the source-store repository's own root (resolve that
      root as the directory containing `.claude-extensions.json`, not `<source_dir>` itself):
      `bash <repo_root>/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <repo_root>`.
    - **(c) A deploy-consumer-tree path with no mapped suite** (the touched file lives in a
      consumer repo's own tree, not the source store — e.g. a repo-specific doc outside
      `specs/**`). Doc-lint (gate 3) still correctly SKIPs there by design — it has nothing to
      check outside the source store — but the task-reference lint (gate 4) is a real check in
      every deploy-consumer repo. The subset here is `--only-gate 4`, not `3,4`: naming gate 3
      would make every selected gate SKIP, reaching the zero-check-under-filter condition (see
      `verify-deploy.sh`'s own header) rather than attesting to anything.

    Whichever sub-case applies, the chosen check runs together with whatever in-phase check the
    tier table above already prescribes for that tier (e.g. the `local` row's "build or lint of
    that single module", read for a markdown file as the diff read-through / lint pass the row
    already names).
- A non-final phase declaring `full` names the specific cross-cutting surface that no cheaper
  tier covers (shared tactics, core types, global config, or similar) — the worked example at
  `context/workflows/task-breakdown.md`'s `full` phase is the documented model for this shape.

**A cheaper non-final tier never discharges the doc-sync-pin evidence, and `--skip-slow` is never
a tier.** Per ROADMAP Settled decision 15 (see `context/standards/shell-script-testing.md:178-183`),
Gate 8's deployed-tree coverage is knowingly reduced under `--skip-slow`, so a `--skip-slow` pass
is not evidence that doc-sync pins hold. The same honesty constraint applies to a selected-subset
pass under `--only`/`--only-gate`: narrowing which checks run for cost reasons is never read as
equivalent to the full run it replaces for *that phase's own purpose*, and neither mechanism is
itself a fifth tier — both are *how* a non-final phase's declared tier gets discharged, never a
substitute for declaring one.

**Non-negotiable invariant**: tiering governs GRANULARITY ONLY — how often and how broadly
verification runs *during* a phase. The full gate set still runs before a phase closes and before
a task completes, unchanged. `full` is textually identical in strictness to today's existing
requirement; tiers `prose`, `local`, and `interface` are added *below* it and redefine nothing
about it. A tiering scheme that weakens the final gate is wrong, not a trade-off.

A phase declaring `full` names `bash .claude/scripts/verify-deploy.sh` — or the complete set of
gates it aggregates — in its own verification criteria. A `full` declaration whose task list
reaches only a hand-picked subset of validators does not satisfy the tier, however plausible the
subset looks in isolation.

### Batch-aware deferral

A dispatch-time batch override narrows what a *single* dispatch must independently discharge when
that dispatch is one of several `implement`-phase dispatches inside one `/orchestrate` batch
invocation. The override is carried on the dispatch file itself — a `## Batch Gate Deferral`
section the engine composes alongside dispatch-time payloads such as `concurrent_siblings`
territory — never by editing the plan's own `**Verification Tier**:` field. The plan's declared
tier is the CEILING the standalone path (a single-task implement-phase dispatch, or a single-task
`/orchestrate N`, neither of which ever carries the override) must meet, unchanged.

**What the override changes**: the final phase's own in-dispatch obligation narrows from the
complete gate set to a scoped tier (`local` or `interface`) naming a concrete narrowing
invocation — `bash .claude/scripts/tests/run-all.sh --only SUITE[,SUITE...]` or
`bash .claude/scripts/verify-deploy.sh --only-gate N[,M...]` in a deploy-target repository, or
the parallel `bash agent-system/extensions/core/scripts/tests/run-all.sh --only SUITE[,SUITE...]`
/ `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate N[,M...]` form when the
dispatch is composed from inside the agent-system source-store repository itself — covering only
the files that dispatch itself touched. The composer resolves and interpolates whichever of the
two actually exists in the repository the dispatch is running in (never a hardcoded path that
cannot resolve there); if neither exists, the directive degrades to stating the full gate set as
such instead of naming a dead path.

**What the override does not change**: the phase's `**Verification Tier**: full` field in the
plan file stays exactly as written — it is never edited, rewritten, or demoted by the override's
presence. The complete gate set is still owed, once, before the batch concludes, discharged by
the once-per-invocation batch-level stage (`context/contracts/batch-gate-stage.md`), not
forgiven. A phase closing under the override records, in its own verification notes, that the
full set was deferred to the batch stage rather than independently run.

**Unmappable criterion**: a phase's own declared verification criterion sometimes names a
repository-specific check that neither narrowing invocation above can express — no suite
basename the `run-all.sh --only` form resolves, no gate number the `verify-deploy.sh
--only-gate` form resolves. The override's narrowing does not reach a check it cannot name. In
that case the implementer runs the named check directly instead of either narrowing invocation
— scoped to this phase's own touched files where the check itself supports scoping — and
records that direct run as the scoped discharge. An unmappable criterion is never waived,
dropped, or treated as satisfied by a narrowing that does not actually reach it; the override
narrows which invocation covers a phase's verification, it never shrinks the set of checks a
phase's own criteria require.

This is not a fifth tier and not a weakening of the vocabulary above — exactly parallel to the
"`--skip-slow` is never a tier" ruling two paragraphs above: narrowing *which dispatch* runs the
full set, for cost and contention reasons under concurrency, is never read as equivalent to
running it; it only relocates WHEN and WHERE the full set runs. The non-negotiable invariant
above is preserved in aggregate across the batch — the complete gate set still runs, once, before
the batch's tasks are done — rather than per task.

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

### Scope-Hypothesis / task-list self-consistency obligation

The obligation above governs a `**Scope Hypothesis**:` line as a claim about the WORLD —
something to confirm or correct once implementation starts. This subsection governs a different
failure: a `**Scope Hypothesis**:` line that is inconsistent with that same phase's own task
list, as written by the same author in the same phase. No implementation-time confirmation can
repair that case, because the phase is unsatisfiable as written, not merely mis-estimated.

**(a) The authoring obligation.** A phase's `**Scope Hypothesis**:` and that phase's task list
are two assertions by the same author about the same phase. An author who writes a Scope
Hypothesis naming what is deliberately EXCLUDED from the phase MUST check every task in that
same phase against the exclusion before the phase is written.

**(b) The implementer's rule for when it happens anyway.** Authoring discipline cannot close
this gap entirely, so when a phase's task list is found, during implementation, to require what
that phase's own Scope Hypothesis excludes: preserve what the task list requires — the
statement, the declaration, the thing the phase exists to produce — over the scope prediction;
record the deviation in place with the reason (see "Reasoned Exclusions (format)" below); and
propagate any consequence to later phases that named the same identifiers. Never silently drop
the task to protect the prediction, and never silently widen the prediction without saying so.

**Why the pinned-block precedence reasoning does not transfer here.** A sibling rule for a
different surface pair — a plan's Verification criteria against its own pinned Lean Challenge
Statements block, in the lean extension's `rules/plan-compliance.md` "Statement Fidelity"
section — resolves its contradiction by precedence, because one of its two surfaces is pinned
and immutable by design after plan time. Neither a `**Scope Hypothesis**:` line nor a task list
is pinned or immutable, so no immutability argument is available to decide which surface wins
here, which is exactly why condition (b) above is argued from what the phase exists to produce
instead of from precedence. The two rules are siblings in the same class of defect — a plan
asserting two things about itself that cannot both hold — but each is decided on its own surface
pair; neither restates the other.

### Cross-phase ceiling consistency obligation

The obligation above governs each `**Scope Hypothesis**:` estimate on its own, pointed forward at
implementation-time confirmation, one phase at a time. It does not govern the relation BETWEEN
those estimates and a numeric ceiling the same plan cites for the same quantity. That relation is
a plan-time arithmetic fact, checkable before any implementation begins, and this subsection
closes that gap.

When a plan cites a numeric ceiling for some quantity (a line count, a file count, a token
budget, or any other countable dimension) AND one or more phases carry a `**Scope Hypothesis**:`
estimating that same quantity, the plan MUST NOT assert anywhere in its own prose — Goals &
Non-Goals, Risks & Mitigations, Rollback/Contingency, or a phase block — that the quantity stays
under or within that ceiling when the plan's own per-phase estimates, summed against any stated
starting baseline, already exceed it. A plan that cites a ceiling and separately estimates toward
it must let its own arithmetic settle whether a conformance claim is true; it must never assert
conformance that its own numbers contradict.

Where the author expects the quantity to approach or cross the ceiling, the plan says so and
names its own contingency — widening the ceiling via whatever escape valve governs that ceiling,
splitting a phase, or re-scoping — rather than asserting conformance its own numbers contradict.

This subsection and the counts-are-hypotheses obligation above are complementary, and neither
discharges the other: `**Scope Hypothesis**:` governs each estimate's forward-looking
confirmation one phase at a time, while this subsection governs the relation between those
estimates and a ceiling the same plan quotes. A plan can satisfy one while violating the other.

(Worked example, illustrative only — the governing vocabulary above is deliberately generic and
names no linter: a plan citing a 1500-line ceiling from a Lean `longFile` linter, with per-phase
line estimates of 110, 120, 95, 10, 90, 80, and 130 against a 959-line starting file, sums to
roughly 1594 — past the cited ceiling — while the plan's Rollback/Contingency section asserts the
file "stays well under 1500". That plan violates this obligation regardless of which linter or
unit the ceiling happens to come from.)

**Decision and rejected alternatives.** This obligation is enforced by a mechanical, advisory
check added to `scripts/validate-artifact.sh`'s existing per-phase plan loop (see "Enforcement
level" below), not by an authoring rule alone and not by a planner-agent checklist item. An
authoring rule alone was rejected: the originating incident was an author failing to do the
arithmetic, so a rule asking the same author to do the same arithmetic again, with nothing
checking the result, has no backstop. A planner-agent checklist item was rejected: an agent
prompt is far more volatile than a format document paired with a tested script, leaves no
durable record that the check ran, produces no counted residue, and offers no promotion path to
a stronger guarantee.

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

### Enforcement level (Cross-phase ceiling consistency)

The cross-phase ceiling consistency check added to `scripts/validate-artifact.sh`'s per-phase
plan loop (see "Cross-phase ceiling consistency obligation" above) follows the same
advisory-first pattern as the two enforcement subsections on this page: a detected contradiction
emits a warning via `log_warn`, never an error, so default-mode validation exits 0 on the
warning alone. `--strict` mode promotes it today through the same pre-existing
`total_issues = errors + warnings` branch the other two checks already rely on; no new
strictness logic is added for this check. **Promotion criterion**: promote the warning to an
error once a default-mode sweep of every non-terminal plan under `specs/` shows zero plans newly
warning. Measured residue at this check's authoring: **0 of 14 non-terminal plans under `specs/`
with a linked plan artifact newly warn** in default mode. Re-measure rather than trusting this
count before promoting — the active-plan corpus turns over continuously, and this count reflects
only the 14 non-terminal, plan-linked tasks present in `specs/state.json` at authoring time, not
every non-terminal task (most carry no plan artifact yet).

### Enforcement level (Files to modify)

This is the same pattern as the `### Enforcement level` subsection immediately above for
`**Verification Tier**:`, applied to the per-phase `Files to modify` field, with one addition:
`Files to modify` is enforced at **two tiers**, not one, because a plan can be missing the
field in *some* phases (a partial gap) or in *every* phase (a whole-plan gap), and the two have
different severity. A whole-plan gap means `plan-file-scope-harvest.sh` harvests nothing at all
for that plan, so the task's `file_scope` stays `null` — invisible to the orchestrator's
admission overlap gate, not merely under-declared.

- **Per-phase tier**: advisory-first, exactly like `Verification Tier` — a phase missing the
  field emits a warning, not an error, so default-mode validation of plans authored before this
  field was enforced continues to pass. `--strict` mode enforces it today (via the same
  `total_issues = errors + warnings` branch `Verification Tier` already relies on).
- **Whole-plan tier**: error by default, not advisory. Landed at this level (rather than
  mirroring the per-phase tier's advisory posture) because a plan-time sweep of the active-plan
  corpus found exactly one plan where every phase omitted the field — repaired as this
  enforcement change's own regression fixture — against only two plans with a lesser,
  per-phase-only gap. Error-by-default on the whole-plan tier therefore newly failed exactly the
  one plan this change already repairs, while error-by-default on the per-phase tier would have
  newly failed two unrelated, otherwise-unaffected plans.

**Promotion criterion**: promote the per-phase warning to an error once no non-terminal plan
under `specs/` has any phase lacking the field. As measured at this check's authoring, the
residue is **5 omitting phases across 2 plans**: the exhaustive-enumeration-by-default plan
(1 of 7 phases) and one plan round of the branch-budget engine-totality task (4 of 13 phases in
that specific round; the task's other plan rounds each declare the field on every phase). This
is recorded here for a future task to execute, not done by the task that introduced this
enforcement — re-measure at that time rather than trusting this count to still hold.

See "Consumers of this field" above for `validate-artifact.sh`'s place as the fourth consumer of
this field, and `scripts/plan-file-scope-harvest.sh`'s own header comment for the cross-reference
recording that the no-header/empty-header distinction this enforcement draws is deliberately
made only here, never in the harvester itself.

### Enforcement level (Files to modify authoring shape)

Distinct from the presence check immediately above (which asks only whether the `Files to
modify` header exists in a phase's block): this check scans a PRESENT block's own entry lines
for three authoring shapes that each silently drop a path from the harvester's output rather
than erroring — surfaced at plan-acceptance time, where the author can still fix them, instead
of at implement time via a `git-commit-phase.sh` drop. advisory-first, by the same pattern as
`Verification Tier` and the per-phase `Files to modify` presence tier above: each hit emits a
warning, never an error, so default-mode validation exits 0 on these warnings alone; `--strict`
mode enforces it today via the same `total_issues = errors + warnings` branch.

- **Wrapped-continuation shape**: an entry line whose immediately following line, leading
  whitespace stripped, itself begins with a backtick. The harvester's entry grammar requires a
  leading `- ` marker, so this line is read as prose, not a second entry — the author's likely
  intent (a second path) is dropped without any error.
- **Comma-join shape**: an entry line carrying a second backtick-delimited path joined by a
  comma. Only the first path is harvested; the second is silently dropped.
- **Deployed-tree-path shape**: an entry naming a path equal to `.claude`/`.claude/` or prefixed
  `.claude/` instead of the `` `__WHOLE_TREE__` `` sentinel (see "Whole-tree-claim declaration
  rule" above and `scripts/plan-file-scope-harvest.sh`'s own deployed-tree refusal, which drops
  such an entry at harvest time rather than erroring).

**Promotion criterion**: promote these three warnings to errors once a plan-time sweep of the
active-plan corpus under `specs/` finds no occurrence of any of the three shapes outside this
task's own fixtures. Not yet measured as of this check's introduction — re-measure before
promoting rather than assuming the residue is zero.

See `scripts/plan-file-scope-harvest.sh`'s "Deployed-tree refusal" header subsection for the
harvest-time enforcement this check is advisory-side of, and `test-validate-artifact.sh` for the
fixture pinning each shape's warning, its `--strict` promotion, and the no-false-positive
negative case for a correctly-authored block.

### Enforcement level (Tier Justification measurement)

The measurement obligation above — that a `**Tier Justification**:` line naming a suite subset or
invoking `__FULL_SWEEP__` is honest only when it matches `suite_selection_select`'s actual output
for the phase's `Files to modify` paths — is enforced by a mechanical, advisory-first check in
`scripts/validate-artifact.sh`'s existing per-phase `plan` loop, the same enforcing consumer
already named by the "Enforcement level" and "Enforcement level (Cross-phase ceiling
consistency)" subsections above. A detected mismatch emits a warning via `log_warn`, never an
error, so default-mode validation exits 0 on the warning alone; `--strict` mode promotes it today
through the same pre-existing `total_issues = errors + warnings` branch the other checks on this
page already rely on — no new strictness logic is added for this check.

**Decision and rejected alternative.** A mechanical lint was chosen over a prose-only
requirement because the filed defect is precisely the failure a prose-only rule cannot prevent:
an author asserted the selector's output without running it, and the assertion was false, with
nothing in the standard requiring the claim to be checked. A prose-only requirement asks the same
author to do the same thing again with nothing backstopping the result — it was rejected for
exactly the reason a prose-only authoring rule was rejected for the cross-cutting-ceiling
obligation above. Weighed against that: the selector costs roughly what a `grep` costs (no
build, no test execution, no filesystem mutation — see `context/standards/shell-script-testing.md`
for the measured figures this file cites by reference) and re-running it once per non-final phase
at plan-authoring or plan-validation time does not inherit a `full` gate's cost, so the mechanical
check does not make the standard materially more expensive to satisfy than the prose-only
requirement it replaces.

**Scope**: bounded to claims grounded in `suite_selection_select` — a suite-list claim or a
`__FULL_SWEEP__` claim. It does not extend to the gate-subset mechanism
(`--only-gate N[,M,...]`), which is not grounded in `suite_selection_select` and is not
implicated by either defect this check was added to close.

**Promotion criterion**: promote the warning to an error once a default-mode sweep of every
non-terminal, plan-linked task under `specs/` shows zero plans newly warning. This is recorded
here for a future task to execute, not done by the task that introduces this check. Measured
residue at this check's authoring: **5 of 11 non-terminal plans under `specs/` with a linked plan
artifact newly warn** in default mode. Re-measure rather than trusting this count before
promoting — the active-plan corpus turns over continuously, and this count reflects only the
11 non-terminal, plan-linked tasks present in `specs/state.json` at authoring time. Much of this
residue predates the obligation this check enforces (plans authored before the measurement
requirement existed), exactly the same shape the per-phase `Verification Tier` and
`Files to modify` enforcement subsections above already carry for their own residues.

### Naming a tool's entry point in verification criteria

A phase's verification criteria that invoke a lint, static-analysis, or other external tool MUST
name the repository's own sanctioned entry point for that tool — never the bare underlying
binary. An unresolvable or broken bare binary can exit as if it ran cleanly while producing no
findings at all, so a criterion naming it inherits none of whatever hardening the repository's
own entry point applies around resolution failure. Such a criterion MUST also check the invoked
command's exit status, never rely on only a diff of captured stdout against a baseline: a tool
broken identically on both sides of that diff makes "no new findings" vacuously true, and
nothing distinguishes that from a genuine clean pass. **Enforcement level**: advisory prose only
— there is no corresponding `scripts/validate-artifact.sh` check today.

### Verification sweep independence

A phase's verification criteria that re-sweep an enumeration a prior phase or artifact already
produced MUST NOT reuse that enumeration's own pattern family to confirm it — see
`context/formats/report-format.md`'s `## Carried-Figure Discipline` section, "The verification-independence rule" paragraph, for the full rule and the worked example of the false-green
failure mode it closes. This is a pointer only; the rule itself is stated once, there, not
restated here.

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
`` `comm` ``, or `` `a`, `b` and `c` `` for more than one), and each bullet's identifiers must
LEAD the bullet — the backtick-delimited list begins at the bullet's first non-whitespace
content after its `- ` marker, with any descriptive prose for that bullet following afterward
(e.g. `` - `comm` -- commutativity of addition. ``); this section carries the literal, exact
signature each identifier resolves to, with
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

### Zero Lean Goals (no theorem deliverable)

Gating stays binary on `task_type`: a lean/lean4 plan with no theorem deliverable still carries
the `## Lean Challenge Statements` section — it is never omitted on the strength of having
nothing to prove. To declare zero goals, the section MUST contain the verbatim marker line

```
<!-- lean-challenge-statements:none -->
```

and no ```` ```lean ```` fenced blocks; surrounding rationale prose is permitted around the
marker. `- **Goals**:` MUST name zero identifiers in this case — a marker alongside a non-empty
`- **Goals**:` list is a self-inconsistency, not a valid zero-goal declaration. The rationale for
why the plan has no theorem deliverable MUST be recorded under the plan's `## Decisions` section.

Three contrasts distinguish this shape from its neighbors:

- A merely-empty section — present, with no fenced blocks and no marker — is malformed, not a
  zero-goal declaration, and still fails loudly (`lean-challenge-snapshot.sh` exits `71`).
- Omitting the section entirely is NOT equivalent to declaring zero goals: an absent section
  means a pre-R1-feature legacy plan, and the snapshot tool still falls back to its R2
  git-baseline route rather than recognizing a deliberate no-op.
- The marker is a deliberate, explicit opt-out — never a default a plan falls into by leaving the
  section empty or unwritten.

See `context/project/lean4/domain/challenge-snapshot.md`'s Exit-Code Vocabulary table for exit
code `72` and its Zero-Goal Marker subsection for the full recognition mechanics.

## Goal Polarity (optional, lean/lean4 plans)

An optional plan-level metadata line, consumed by `lean-plan-compliance-check.sh`'s Final
Verification Stage spot-check (the step that extracts the backticked identifiers named under
`- **Goals**:` and greps the resolved Lean source roots for a matching declaration):

```
- **Goal Polarity**: refutation
```

**Default (field absent)**: every existing plan, and every plan that does not need this field,
is completely unaffected — the spot-check's default behaviour is unchanged: every named
identifier MUST be present (declared) in the resolved source roots, exactly as documented for
`## Lean Challenge Statements` above.

**`refutation`**: declares that this plan's Goals name identifiers that must be ABSENT from the
tree, not present — a refutation task, where success means no weakened substitute for the named
identifier(s) was published anywhere. The spot-check inverts accordingly: every named identifier
absent from the resolved source roots is `passed`; any one present is `failed`, naming it. Use
this value only when every identifier named under `- **Goals**:` shares this same polarity.

**Mixed-polarity ruling**: a plan whose Goals block genuinely mixes identifiers that must exist
with identifiers that must be absent cannot be expressed by this single global field — declare an
explicit non-`refutation` value (e.g. `mixed`) rather than leaving the field absent (which would
wrongly apply must-exist semantics to an identifier that must be absent, or leaving it at
`refutation` would wrongly apply must-be-absent semantics to one that must exist). The
spot-check's response to any explicitly declared, non-`refutation` value is to record
`compliance_check: "skipped"` with a stated reason, rather than guessing — the honest outcome a
human previously had to reach by hand, now reached mechanically.

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
plan-time hypothesis. Alongside that overcount case, a reasoned exclusion may also close a Scope
Hypothesis that was found to contradict its own phase's task list — see "Scope-Hypothesis /
task-list self-consistency obligation" above for that case and the rule for preserving the task
list over the prediction.

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

**A decision gate that is already `[BLOCKED]` at plan-authoring time** is a distinct case from
the worked example above, whose gate executes and is measured while the plan runs. A gate
blocked before any phase executes has no consistent position under the final-phase
transitive-dependency rule above: an executable phase cannot depend on a phase that will never
complete, so such a gate MUST be exempt from the literal depends-on edge that rule would
otherwise impose. Place the gate in wave 1 with `Depends on: none`, alongside the plan's first
executable phase, rather than threading a dependency edge through it. In exchange, the final
phase MUST re-observe the blocked gate's own measurement by name inside its own verification
criteria, and the Dependency Analysis wave-table note MUST state this re-observation explicitly
— together these two MUSTs keep the gate's decision load-bearing on the final phase's own
verification despite its exemption from the depends-on edge.

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

**Ownership of the plan-level Status field.** The plan-level `- **Status**:` field above is
owned by `update-plan-status.sh`, invoked from `update-task-status.sh` postflight — never by a
phase's own checklist, verification criteria, or other phase-body prose. No `**Tasks**:` item and
no `**Verification**:` criterion may instruct a writer to hand-set this field; an implementation
agent that refuses such an instruction, per `context/contracts/plan-status-ownership.md`, is
acting correctly, and the defect lies in authoring the instruction at all. When a plan is
expected to come to rest at `[BLOCKED]`, write that expectation into the relevant phase heading
instead — mark it `[BLOCKED]` (see "Decision gates and contingency branches" above for a plan
containing a pre-decided `[BLOCKED]` gate), or close any bypassed phase `[COMPLETED WITH
EXCLUSIONS]` with its own `#### Reasoned Exclusions` record — and let the implementer's own
return (`.return-meta.json` status, the handoff's `blockers[]`) carry the outcome forward for
postflight to stamp onto this field.

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
