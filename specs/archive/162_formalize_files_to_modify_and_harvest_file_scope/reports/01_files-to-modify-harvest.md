# Research Report: Task #162

- **Task**: 162 - Formalize "Files to modify" and harvest file_scope
- **Started**: 2026-09-09T17:00:00Z
- **Completed**: 2026-09-09T17:03:00Z
- **Effort**: ~1.5 hours (research)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/context/formats/plan-format.md` (per-phase field list, existing
    "Consumers of this heading contract" precedent, Scope Hypothesis definition)
  - `agent-system/extensions/core/agents/planner-agent.md` (phase template, line 319)
  - `agent-system/extensions/core/agents/general-implementation-agent.md` (line 65 consumer)
  - `agent-system/extensions/core/scripts/update-task-status.sh` (existing `--file-scope-add`
    mechanism)
  - `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (Stage 7 plan/research
    postflight wiring)
  - `agent-system/extensions/core/scripts/reconcile-task-status.sh` (two additional `postflight
    plan` call sites)
  - `agent-system/extensions/core/skills/skill-reviser/SKILL.md` (third `postflight plan` call
    site, /revise path)
  - `agent-system/extensions/core/context/schemas/state-schema.json` (`file_scope` field
    definition)
  - `agent-system/extensions/core/context/standards/shell-strict-mode.md` (new-script strict-mode
    default)
  - `specs/*/plans/*.md` (18 local plan files, grammar survey)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- `**Files to modify**:` is confirmed present in **18/18** local plan files under `specs/*/plans/`
  (dispatch's "10/10" figure is now stale simply because more tasks exist; coverage is still
  100%). Only the colon-outside-bold punctuation `**Files to modify**:` occurs locally — zero
  occurrences of `**Files to modify:**` — but the format doc's existing field-punctuation
  tolerance rule should still accept both, matching every other per-phase field.
- The planner's own template (`planner-agent.md:319`) places `**Files to modify**:` immediately
  after `**Scope Hypothesis**:` and before `**Verification**:` — this is the natural insertion
  point in `plan-format.md`'s per-phase field list (between `Scope Hypothesis` and `Owner`).
- `update-task-status.sh` already has a **directly reusable** union-merge mechanism:
  `--file-scope-add=<json-array>`, routed through `state-write.sh` (the single mutex-guarded
  writer), currently hard-restricted to `operation=postflight && target_status=research`. Widening
  this restriction to also accept `target_status=plan` is the lowest-risk way to satisfy "write via
  state-write.sh, do not hand-roll a jq read-modify-write" — no new write path is needed, only a
  new caller of the existing one.
- **Important finding not named in the dispatch's three-consumer list**: `update-task-status.sh
  postflight <N> plan <session>` is called from **three** independent sites, not one —
  `orchestrator-postflight.sh` Stage 7, `reconcile-task-status.sh` (two call sites, lines 558 and
  678), and `skill-reviser/SKILL.md` Stage 7 (the `/revise` path). All three already have the
  plan file path in a local variable at their call site. Wiring the harvest into only
  `orchestrator-postflight.sh` (the dispatch's literal wording, "wire it into plan postflight")
  would silently miss `/revise` and the reconciliation self-healing path. This is a scope
  decision for the plan phase, not resolved here.
- Recommended rulings for the three open decisions: **union merge** (not overwrite), **re-harvest
  on every plan postflight including revisions** (safe because it's additive-only), and **harvest
  failure is a non-fatal warning** (matching the existing non-blocking posture of every other
  advisory step in this pipeline, including `--file-scope-add`'s own existing no-op branches).
- `**Scope Hypothesis**:` is prose about counts/estimates, not a structured file list — recommend
  it is **not** parsed by the harvester; only the `**Files to modify**:` block is a harvest
  source.

## Context & Scope

Task 162 asks to formalize the already-universal `**Files to modify**:` per-phase plan
convention in `plan-format.md`, and to build a harvester that populates `state.json`'s
`active_projects[].file_scope` from a plan's phases at plan-postflight time, using the existing
mutex-guarded `state-write.sh` writer rather than a new ad hoc jq read-modify-write. Three named
consumers of the *heading text* (not its grammar) must keep working unchanged. This report
verifies the dispatch's framing against current code, surveys the actual grammar in use, and
resolves the wiring-point and semantics questions the dispatch explicitly leaves open.

## Findings

### 1. Convention prevalence and grammar (verified against current repo state)

- `find specs/*/plans/*.md` → 18 plan files total; `grep -l '**Files to modify**:\|**Files to
  modify:**'` → 18/18 match. All 18 use the colon-outside-bold form (`**Files to modify**:`);
  none use `**Files to modify:**`. The dispatch's "10/10" was accurate at the time it was written;
  the task count has since grown, but coverage is still complete (100%), so the "near-total
  existing coverage" framing holds and is actually stronger than stated.
- List-item grammar observed across all sampled phases (e.g.
  `specs/197_forced_phase_on_terminal_and_archived_tasks/plans/01_forced-phase-terminal-archived-tasks.md`):
  ```
  **Files to modify**:
  - `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh` - new library
  - `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - source the library;
    `lookup_project` becomes a wrapper; inline archive jq removed
  ```
  Two grammar features the harvester must handle:
  1. **Backtick-quoted path + trailing description**: `- \`path\` - {description}`. The path is
     the only harvestable token; the description is free text and must be discarded.
  2. **Wrapped continuation lines**: a long description wraps onto an indented continuation line
     (no leading `- `). The harvester must not mistake a continuation line for a new list item
     (i.e., must only start a new file entry on a line matching `^- \`` after the field header,
     not on every non-blank line).
  3. **Sentinel "no files" phases exist**: one sampled phase (`... Phase 8 [same plan] ...`) uses
     `**Files to modify**:` followed by `- none planned (verification and deploy only); in
     practice also touched \`path\` and \`path\`` — i.e. prose describing zero-or-deviated files
     rather than a clean list. The harvester should tolerate a line that does not match the
     backtick-path pattern by simply contributing nothing from it (never erroring the whole
     harvest over one malformed/prose line in one phase).
  4. Both `**Files to modify**:` and `**Files to modify:**` must be accepted per the format's
     existing "Field-punctuation tolerance" rule (stated for every other per-phase field); even
     though only the first form is attested locally, this is the same rule already governing
     `**Verification Tier**:`/`**Verification Tier:**` and should not be special-cased.

### 2. Exact insertion point in plan-format.md

`plan-format.md`'s "Implementation Phases (format)" section currently lists, in order: `Goal`,
`Tasks`, `Timing`, `Depends on`, `Verification Tier`, `Commit Mode`, `Scope Hypothesis`, `Owner`,
`Started/Completed/Blocked/Abandoned`. The planner's own emitted template
(`planner-agent.md:295-322`) orders fields as: `Goal`, `Tasks`, `Timing`, `Depends on`,
`Verification Tier`, `Commit Mode`, `Scope Hypothesis`, **`Files to modify`**, `Verification`.
`Verification` itself is documented separately in plan-format.md's Testing & Validation guidance,
not in the per-phase field list — so the natural, template-matching insertion point for `**Files
to modify**:` in the per-phase field list is **immediately after `Scope Hypothesis` and before
`Owner`**.

### 3. Reusable write mechanism already exists

`update-task-status.sh` (header comments plus body, lines ~53-70 and ~220-236) already implements
exactly the union-merge semantics this task needs, under the flag `--file-scope-add=<json-array>`:

- Validates the value is a JSON array of strings (hard error on malformed input, never a silent
  drop).
- Currently **hard-restricted** to `operation==postflight && target_status==research` — any other
  combination is a validation error (line ~234).
- The merge itself: `.file_scope = ((.file_scope // []) + $add | unique)`, riding inside the
  *same* `state-write.sh` invocation `update_state_json()` already makes — never a second write,
  never a hand-rolled jq read-modify-write. This is precisely the mechanism the dispatch's WORK
  item 4 asks for.
- `orchestrator-postflight.sh` Stage 7 (lines ~342-361) already demonstrates the exact call
  pattern needed: for `operation_type == "research"`, it reads `proposed_file_scope` off the
  agent's `.return-meta.json` and forwards it as `--file-scope-add=<json>` if non-empty, wrapped
  in the existing non-blocking `|| echo "[postflight] WARNING: ... (non-blocking)"` pattern.

**Implication**: the lowest-risk implementation widens `--file-scope-add`'s restriction to also
permit `target_status==plan` (mirroring the existing `research` case exactly), and adds a
`plan`-branch analogous to the `research`-branch already in `orchestrator-postflight.sh` — except
the JSON array comes from running the new harvester over the plan file instead of from
`.return-meta.json`'s `proposed_file_scope`.

### 4. Three `postflight ... plan ...` call sites, not one

The dispatch's compatibility-constraints list names three consumers of the **heading text**
(`general-implementation-agent.md:65`, `skill-orchestrate`'s H1 territory block, and
`orchestrate-cycle-plan.sh`'s ported copy) — those are unaffected by this task since the heading
string itself is not changing. Separately, and not named in the dispatch, `bash
.../update-task-status.sh postflight $task_number plan $session_id` (the call this task must
attach the harvest to) is actually invoked from **three independent script locations**:

| Call site | File:context | Plan path already in scope? |
|---|---|---|
| `/orchestrate` main postflight | `orchestrator-postflight.sh` Stage 7 (~line 358) | Yes — local var `artifact_path`, populated at Stage 6 from this round's `.return-meta.json`, well before Stage 7 runs |
| Reconciliation self-heal (status desync recovery) | `reconcile-task-status.sh:558` and `:678` | Yes — local var `plan_file`, already passed to `link_artifact` on the line immediately before |
| `/revise` | `skill-reviser/SKILL.md` Stage 7 (~line 324) | Yes — local var `artifact_path`, used one stage earlier (Stage 6a) for artifact validation |

All three already hold the plan file path in a local variable at their existing call site, so
wiring the harvest into all three is mechanically small (harvester invocation + `--file-scope-add`
argument at each site) — but it is three edits, not one, and a plan that touches only
`orchestrator-postflight.sh` (matching the dispatch's literal "wire it into plan postflight"
wording read narrowly) would leave `/revise` and the reconciliation path silently uncovered. This
directly informs the "does a plan revision re-harvest?" open question below: the answer can only
be "yes, uniformly" if the `skill-reviser` call site is included in scope.

### 5. `file_scope` semantics already established as "prospective, additive, never validated"

`state-schema.json`'s `file_scope` field: *"Documented-optional. Anticipated repo-relative
paths/prefixes this task expects to touch (prospective, not filesystem-validated)."*
`update-task-status.sh`'s own `--file-scope-add` comment block states the same thing for its
existing research-time consumer: *"never a replacement, never subtractive"*; *"An empty array, or
an array whose members are all already present, leaves file_scope byte-for-byte unchanged."* This
is the same posture `plan-format.md:251`'s "counts are hypotheses" language and the dispatch's own
framing both converge on. There is no existing precedent anywhere in this codebase for an
*overwrite* semantics on `file_scope` — every existing writer (creation-time declaration, the
research `proposed_file_scope` consumer) is additive-only.

### 6. Scope Hypothesis is orthogonal prose, not a second file-list source

`plan-format.md`'s Scope Hypothesis field ("required whenever the phase asserts a count, an
enumerated file list, or a scope estimate... states the hypothesis and how to confirm it at
implementation time") is free-form prose about a *claim to verify*, not a structured,
machine-parseable file enumeration in its own right — even when that claim happens to be about a
file count. Its own definition explicitly routes structured file-list content through the
existing `Files to modify` carrier ("this section defines the planner-side carrier field only").
Treating it as a second harvest source would require prose-parsing (fragile) to extract paths
that, per the template ordering (§2 above), are already present verbatim in the adjacent `Files to
modify` block. No existing plan phase was found where Scope Hypothesis names a file not also
present in that phase's own `Files to modify` list.

## Decisions

These resolve the dispatch's "DECIDE, DO NOT ASSUME" list:

1. **Overwrite vs. union**: **Union** (additive merge only, matching the existing
   `--file-scope-add` semantics verbatim). Rationale: `file_scope` is documented prospective and
   every existing writer is additive; overwriting would discard creation-time declarations and any
   research-time `proposed_file_scope` merge that already landed for this task.
2. **Does a plan revision re-harvest?**: **Yes.** Every `postflight ... plan ...` call — including
   `/revise` — re-runs the harvest. Because the merge is additive-only, re-running is safe and
   idempotent: a revision that removes a phase's file mention does not retract it from
   `file_scope` (consistent with "prospective, never dropped" — file_scope is not expected to
   shrink), and a revision that adds phases contributes their new files. This requires the harvest
   to be wired at all three call sites identified in Finding 4, not only `orchestrator-postflight.sh`.
3. **Harvest failure: fatal or warning?**: **Non-fatal, loud warning**, matching every existing
   non-blocking posture in this pipeline (`update-task-status.sh`'s own failure at Stage 7 is
   already `|| echo "...WARNING:... (non-blocking)"`; the no-op file_scope merge branch inside
   `update-task-status.sh` itself already uses the same "Warning: ... (non-fatal)" wording). A
   plan postflight must never be blocked by a harvest that finds no files, a plan file with
   unusual formatting, or a script bug.
4. **Required-or-advisory field marking in plan-format.md**: Document `**Files to modify**:` as
   **required** in the structural field list (the planner template already emits it
   unconditionally and coverage is already 18/18, unlike Verification Tier which started sparse
   and used an advisory-first rollout). Any *enforcement* added to `validate-artifact.sh`,
   however, should still follow the same advisory-first / promote-later pattern
   `plan-format.md`'s own "Enforcement level" subsection already establishes for Verification
   Tier — documenting a field as required and gating validation on it immediately are separate
   concerns, and this codebase already has a working precedent for staging the two apart.

## Recommendations

1. **plan-format.md edits**:
   - Insert `- **Files to modify:** (required) list of \`path\` entries this phase touches, each
     optionally followed by \` - {description}\`; both punctuation forms accepted per the
     existing field-punctuation-tolerance rule.` into the per-phase field list, positioned between
     `Scope Hypothesis` and `Owner` (Finding 2).
   - Add a short "Consumers of this field" note, mirroring the existing "Consumers of this heading
     contract" subsection's structure, naming: `general-implementation-agent.md:65` (heading-name
     stability only), `skill-orchestrate`'s H1 territory block and `orchestrate-cycle-plan.sh`'s
     ported copy (heading-name stability only, per the dispatch's own nuance about these two never
     parsing the list themselves), and the new harvester script (grammar-parsing consumer, the one
     consumer that actually depends on list-item shape, not just the heading string).
   - Add a one-line cross-reference near Scope Hypothesis's definition stating it is not a harvest
     source (Finding 6), so a future reader does not "fix" the harvester into prose-parsing it.
2. **New script**: `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`. Class A
   strict mode (`set -euo pipefail`) per `shell-strict-mode.md`'s default-for-new-scripts rule —
   nothing about this script's purpose matches the Class B "keep going and report everything"
   admission test. Contract: one positional arg (plan file path); parses every `### Phase N:`
   section's `**Files to modify**:`/`**Files to modify:**` block per the grammar in Finding 1;
   unions and deduplicates paths across all phases in the file; emits a JSON array of strings to
   stdout (empty array `[]` when the plan has none or is malformed — never a non-zero exit for
   "found nothing," reserving non-zero exit for genuine usage errors like a missing file
   argument). Must be shellcheck-clean per the ACCEPTANCE criteria.
3. **update-task-status.sh**: widen the `--file-scope-add` restriction (currently `operation ==
   postflight && target_status == research` only) to also accept `target_status == plan`. No
   other change to the flag's validation or merge logic is needed — it is already exactly the
   union-merge this task requires.
4. **Wiring, at all three call sites from Finding 4** (scope decision for the plan phase to
   confirm, given Decision 2 above requires all three for uniform revision re-harvest):
   - `orchestrator-postflight.sh` Stage 7: add an `elif [ "$operation_type" = "plan" ]` branch
     mirroring the existing `research`/`proposed_file_scope` branch, but sourcing the JSON array
     from `bash .../plan-file-scope-harvest.sh "$artifact_path"` instead of
     `.return-meta.json`.
   - `reconcile-task-status.sh:558` and `:678`: compute the harvest from `$plan_file` immediately
     before each `update-task-status.sh postflight "$task_number" "plan" "$session_id"` call and
     pass `--file-scope-add=<json>`.
   - `skill-reviser/SKILL.md` Stage 7: same pattern, sourcing from the `$artifact_path` already
     validated in Stage 6a.
   - Each site should treat harvester failure or an empty result as a non-fatal no-op (Decision 3),
     matching the existing `[ -n "$proposed_file_scope" ] && [ "$proposed_file_scope" != "[]" ]`
     guard shape already used in `orchestrator-postflight.sh`.
5. Add a `tests/test-plan-file-scope-harvest.sh` (or fold into an existing
   `test-update-task-status.sh` if one exists) covering: both punctuation variants, backtick-path +
   trailing-description stripping, wrapped continuation lines, a "no files"/prose sentinel line
   that contributes nothing, multi-phase union+dedup, and a plan file with zero `Files to modify`
   occurrences (empty-array output, not an error).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer wires only `orchestrator-postflight.sh`, missing `/revise` and reconciliation call sites | `file_scope` silently stops accumulating on revised plans; inconsistent behavior depending on invocation path | Medium (dispatch's literal wording names only "plan postflight," singular) | This report's Finding 4 and Decision 2 explicitly call out all three sites; plan phase should enumerate all three as separate phase tasks or one shared phase |
| Harvester mis-parses a wrapped continuation line as a new file path | Spurious bogus path added to `file_scope` | Low-Medium (only one grammar shape observed locally, but plans are hand/LLM-authored prose) | Require the backtick-`path`-at-start-of-line anchor (`^- \``) for a new entry; treat every other non-blank line inside the field's list block as a continuation, not a new entry |
| A plan phase legitimately says "none planned" (verified example exists) | Harvester either errors or fabricates a path from that prose | Low (already observed once in 18 files) | Explicit no-match-contributes-nothing behavior (Recommendation 2), verified by a dedicated test case |
| Widening `--file-scope-add`'s restriction breaks its existing research-only guard's error message/tests | Existing tests asserting the restriction's exact error text could regress | Low | Update the restriction's validation-error message to name both allowed `target_status` values; grep existing tests for the current error string before editing |

## Appendix

- Grammar survey command: `grep -rc '\*\*Files to modify\*\*:' specs/*/plans/*.md` (18 files, all
  colon-outside-bold) vs. `grep -rc '\*\*Files to modify:\*\*'` (0 files).
- Template source: `agent-system/extensions/core/agents/planner-agent.md:295-322`.
- Existing reusable merge mechanism: `agent-system/extensions/core/scripts/update-task-status.sh`,
  `--file-scope-add` flag (header comment ~lines 53-70, validation ~lines 220-236, merge clause
  ~line 768).
- Existing analogous wiring to model the new `plan` branch on:
  `agent-system/extensions/core/scripts/orchestrator-postflight.sh` lines ~342-361 (the
  `research`/`proposed_file_scope` branch).
- Three `postflight ... plan ...` call sites: `orchestrator-postflight.sh` (~line 358),
  `reconcile-task-status.sh:558`, `reconcile-task-status.sh:678`,
  `skill-reviser/SKILL.md` (~line 324).
