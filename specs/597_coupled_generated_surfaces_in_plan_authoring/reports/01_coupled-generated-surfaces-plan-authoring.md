# Research Report: Task #597

- **Task**: 597 - Coupled generated surfaces in plan authoring
- **Started**: 2026-11-12T05:04:48Z
- **Completed**: 2026-11-12T05:30:00Z
- **Effort**: ~3 hours (research)
- **Dependencies**: None (task 596 `generated_file_scope_vs_readonly_risk` holds a hard dependency
  *on* this task, not the reverse; task 599 `batch_gate_deferral_narrowing_for_project_sources`
  shares file territory on `plan-format.md` but no dependency edge)
- **Sources/Inputs**:
  - `agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`
  - `agent-system/extensions/lean/index-entries.json`, `agent-system/extensions/lean/EXTENSION.md`,
    `agent-system/extensions/lean/manifest.json`
  - `agent-system/extensions/core/context/formats/plan-format.md`
  - `agent-system/extensions/core/agents/planner-agent.md`
  - `agent-system/extensions/core/context/patterns/context-discovery.md`
  - `agent-system/extensions/core/scripts/validate-artifact.sh`
  - `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
  - `agent-system/extensions/core/context/standards/repo-level-declarations.md`
  - `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh`
  - `specs/state.json` (tasks 596, 599, 597 cross-reference)
  - Mathlib4 source (`Mathlib/Tactic/Linter/Style.lean`, `master` branch, fetched live) for the
    `longFile` linter's actual arithmetic
- **Artifacts**: `specs/597_coupled_generated_surfaces_in_plan_authoring/reports/01_coupled-generated-surfaces-plan-authoring.md` (this file)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Defect A's "reach gap" claim is confirmed mechanically, not merely asserted: `plan-authoring-gate-collisions.md`'s `index-entries.json` entry lists `load_when.agents: ["lean-research-agent", "lean-implementation-agent"]` only — `planner-agent` (the sole plan-phase agent for `lean4`, per `manifest.json`'s `routing_agents.plan.lean4`) is absent — and `planner-agent.md` itself contains no stage, checklist item, or conditional pointer that reads this file, confirming the gap end to end.
- A naive "fix" of adding `planner-agent` to that entry's `agents[]` array is unsound: `context-discovery.md`'s own documented "Adaptive Context Loading" query ORs the `agents[]`, `task_types[]`, and `commands[]` dimensions independently, so a `planner-agent` match alone (true for every task type, since `planner-agent` is the shared plan agent across all domains) would load lean-specific gate guidance into every non-lean plan dispatch. The recommended reach mechanism is therefore a direct conditional pointer inside `planner-agent.md` (task_type-gated), not an index-entries change — see Recommendations.
- Defect B's Condition 7 text ("the linter accepts a baseline `N` only when `N - 200 <= lines < N`") does not match the Mathlib `longFile` linter's actual source. The live Mathlib `master` source was fetched and read directly: the linter computes `candidate = max(defValue, (lastLine / 100) * 100 + 200)` and accepts the declared limit `N` only when `N == candidate` or `N + 100 == candidate` (i.e. `N ∈ {candidate - 100, candidate}`) — a derivation that reproduces **both** cited data points exactly (2967 lines → expected 3100; 3200 lines against a 3200 limit → expected 3400), which the task's own hypothesized `(floor(lines/100) + 2) * 100` formula also happens to equal, but the acceptance-window inequality and the "incremental re-tightening" consequence were previously stated wrong.
- The remedy-(iii) advisory check (a repo-declared coupling list, not hardcoded BimodalLogic paths) has a near-exact existing precedent to model on: `derived_artifact_probes` in `.claude-extensions.json` (documented in `context/standards/repo-level-declarations.md`, read by `scripts/lib/derived-artifact-probe-lib.sh`) is already a fail-open-on-absence, repo-declared array consumed by a mechanical script — but it is wired only into implement-postflight staleness checking, not into plan-time declaration-completeness checking, and its schema (`component`/`check_command`/`derived_output_dirs`) has no field for "what source pattern triggers this coupling," so a new, differently-shaped declaration (e.g. `coupled_generated_surfaces: [{trigger_glob, generated_paths, note}]`) is needed rather than reusing the existing array.
- Prior-record disposition is now explicit per the dispatch's own instruction: task 596 (`generated_file_scope_vs_readonly_risk`) already carries a hard dependency on this task (596 was filed as an explicit REFINEMENT of this task's remedy (i), confirmed live in `specs/state.json`), and task 599 (`batch_gate_deferral_narrowing_for_project_sources`) shares `plan-format.md` file territory but targets a different mechanism (the Batch Gate Deferral directive's narrowing forms) with no dependency edge onto this task. Neither of the two genuinely dead prior records (`#885`/`per_phase_generated_surface_gates_and_batch_defer`, `#785`/`lean_plan_gate_collision_authoring_guidance`) needs any action here — both stayed behind in the source repository's archive per the dispatch's own migration-provenance note, so "decide explicitly, do not silently resurrect" is already satisfied by that note, not by anything this research phase needed to adjudicate.

## Context & Scope

Two plan-authoring defects in the agent system's Lean4-adjacent plan-authoring guidance, migrated
from the BimodalLogic repository, both touching
`agent-system/extensions/core/context/formats/plan-format.md` and
`agent-system/extensions/lean/context/project/lean4/patterns/plan-authoring-gate-collisions.md`:

- **Defect A**: a repo-agnostic "coupled generated surface" declaration obligation is missing
  from `plan-format.md`'s `Files to modify` contract, AND the Lean-specific instance of this
  problem (Condition 1 of `plan-authoring-gate-collisions.md`) is unreachable by the agent
  (`planner-agent`) that actually authors `lean4` plans.
- **Defect B**: Condition 7 of `plan-authoring-gate-collisions.md` states the `longFile` linter's
  baseline-acceptance window incorrectly.

This phase is scoped to research only: confirming both defects against primary sources (the
agent-system files themselves, and Mathlib's own linter source for Defect B), surveying the
existing mechanisms the remedies can model on, and resolving the explicit prior-record
disposition questions the dispatch requires before planning. No source-store file was edited in
this phase; `EDIT TARGET` in the dispatch names the plan/implement phases, not research.

## Findings

### Defect A — Confirmed Mechanically on Both Halves

**Half 1 (the guidance already exists).** `plan-authoring-gate-collisions.md`'s Condition 1 ("A
Lean Line-Count Change Trips Two Generated Surfaces") already states, verbatim, both generated
surfaces (the module-inventory blocks and `typst/generated/status.typ`), the hook-blocking
asymmetry between them, and the exact consequence the dispatch quotes: "a plan that adds or
removes Lean lines pre-authorizes the `--fix` run and carries `typst/generated/status.typ` in its
own file scope, in the same phase as the line-count change." This is not a missing-documentation
gap — the content is correct and already written.

**Half 2 (the reach gap).** Confirmed by direct inspection of three files, in order:

1. `agent-system/extensions/lean/manifest.json`'s `routing_agents.plan.lean4` resolves to
   `planner-agent` — the shared, core, cross-domain plan agent, not a lean-specific one.
2. `agent-system/extensions/lean/index-entries.json`'s entry for
   `project/lean4/patterns/plan-authoring-gate-collisions.md` declares
   `"load_when": {"agents": ["lean-research-agent", "lean-implementation-agent"], "task_types": ["lean4"]}`
   — `planner-agent` is absent from `agents[]`. Every other `project/lean4/**` entry in the same
   index file follows the identical two-agent pattern (`lean-research-agent` /
   `lean-implementation-agent`); none names `planner-agent`.
3. `agent-system/extensions/core/agents/planner-agent.md` was read in full. Its only Lean-specific
   content is a single output-template field, `**Lean Intent**: {true if lean, false otherwise}`
   (line 322), which is a boolean the agent *writes into the finished plan's metadata* — it is not
   a context-loading trigger, has no corresponding read step anywhere earlier in the agent, and no
   stage of the file (Stage 1 through Stage 4, including the 12-item phase-authoring checklist in
   Stage 4) mentions `plan-authoring-gate-collisions.md`, `typst/generated/status.typ`,
   `check-module-invariants.sh`, or any Lean-specific gate at all. The file's only reference to
   Lean-specific *context* is the generic `@.claude/context/patterns/context-discovery.md` pointer
   at the top, with no stage that actually invokes a task_type-scoped query before phase
   decomposition.

This confirms the dispatch's framing exactly: the content exists, is correct, and is provably
unreachable from the one agent that needs it at the one time it matters (before Stage 4's phase
decomposition, where the plan's `Files to modify` lists are fixed).

**Why the obvious "index-entries" fix is unsound.** `context-discovery.md`'s own documented
"Adaptive Context Loading (Recommended Pattern)" query is:

```bash
select(
  (.load_when.always == true) or
  any(.load_when.agents[]?; . == $agent) or
  any(.load_when.task_types[]?; . == $task_type) or
  any(.load_when.commands[]?; . == $cmd)
)
```

This is an **OR** across all three dimensions, not an AND. If `planner-agent` were simply added
to this one entry's `agents[]` array, the entry would match on the `agents[]` clause alone for
*every* `planner-agent` dispatch regardless of `$task_type` — because `planner-agent` is the
shared plan agent for every domain (`meta`, `general`, `markdown`, `nix`, `neovim`, `lean4`, …),
unlike `lean-research-agent`/`lean-implementation-agent`, which never run for a non-lean task in
the first place and so tolerate the OR semantics harmlessly. Adding `planner-agent` here would
load Lean-specific, BimodalLogic-shaped gate-collision guidance into every plan dispatch for every
other domain. `context-discovery.md`'s own "Check Command Scope" section states the general
version of this concern already (`project/*` entries must not leak into generic-command loading
scope) but the concrete mechanism doing the leaking here is the agent-dimension OR, which that
section does not cover. This is a genuine finding, not merely a restatement of the dispatch's
framing: the dispatch asked to "pick one and state why," and the "why not" for the index-entries
option is this OR-semantics cross-contamination risk, confirmed by reading the actual query
`context-discovery.md` documents as canonical.

A task_types-only query (`context-discovery.md`'s "Query by Language" pattern, which does not
consult `agents[]` at all) avoids the cross-contamination but has the opposite problem: filtering
on `task_types[] == "lean4"` alone would also surface all ~40 other `project/lean4/**` entries
tagged `lean4` (Mathlib overview, tactic patterns, templates, etc.) — appropriate for
`lean-research-agent`/`lean-implementation-agent`, but far too much budget and noise for a
plan-phase pass that needs exactly one file.

### Defect B — Condition 7 Is Wrong, and the Correct Rule Is Now Verified Against Both Citations

Mathlib's `Mathlib/Tactic/Linter/Style.lean` (fetched live from `master`) defines the `longFile`
linter's actual logic. Quoting the load-bearing lines verbatim:

```lean
let candidate := (lastLine / 100) * 100 + 200
let candidate := max candidate defValue
...
if linterBound == candidate || linterBound + 100 == candidate then return
else
  logLint0Disable linter.style.longFile stx
    m!"This file is {lastLine} lines long. \
      The current limit is {linterBound}, but it is expected to be {candidate}:\n\
      `set_option linter.style.longFile {candidate}`."
```

(`defValue` is `linter.style.longFileDefValue`, defaulting to 1500; `lastLine` is the file's
syntax tail position's line number.) In words: `candidate = max(1500, floor(lines/100)*100 + 200)`,
and the declared limit `N` is accepted **without warning** only when `N == candidate` or
`N == candidate - 100`. Two other branches warn in the two directions this doesn't cover
(`N` set too low relative to current `lines`; `N` left set above `defValue` for a file that no
longer needs it) but the task's Condition 7 is specifically about the acceptance-window
arithmetic, which this `candidate`/`±100` rule replaces.

This derivation was checked, not assumed, against **both** citations in the dispatch:

| Citation | `lines` | declared `N` | `candidate = max(1500, floor(lines/100)*100+200)` | Linter's actual demand | Matches dispatch's quoted message? |
|---|---|---|---|---|---|
| 853:iss_…MPP05G | 2967 | 3400 | 3100 | "expected to be 3100" | Yes — exact match |
| 838:iss_…vZ4XxM | 3200 | 3200 | 3400 | "expected to be 3400, not 3300" | Yes — exact match |

Both reproduce exactly, which is strong corroboration that the fetched `master` source reflects
the rule in effect, even though it was not checked against the exact pinned commit for the
originating repository's `Lean v4.33.0-rc1` toolchain (that repository's `lake-manifest.json` is
outside this session's reach — a different, currently-unavailable repository). The two-citation
match is the best available confirmation; a planning or implementation phase that can reach the
BimodalLogic repository directly should re-pin against the exact Mathlib commit its
`lake-manifest.json` names before finalizing the correction, rather than trusting this match
alone indefinitely.

The task's own hypothesis, `expected = (floor(lines/100) + 2) * 100`, is algebraically identical
to `candidate = floor(lines/100)*100 + 200` (distributing the `+2`) — so the hypothesis was
correct as a formula for `candidate`, but Condition 7's *acceptance window* around that candidate
(`N - 200 <= lines < N`) was wrong on two counts: (a) it inverts which variable the window is
centered on (it should bound `N` relative to `candidate`, not `lines` relative to `N` directly —
though the two are related, the rewritten form is the directly checkable one), and (b) it allows
a 200-wide window when the actual tolerance is ±0/−100 (two accepted values, not a continuous
range). The "single early bump to the final expected value is itself a new warning" consequence
the task draws is correct and is now directly explained by the source: setting `N` far ahead of
`candidate(lines)` fails `linterBound == candidate || linterBound + 100 == candidate` for the
*current* `lines`, regardless of intent — exactly what both citations show.

### Prior-Record Disposition (resolved, not deferred)

- Both prior records the dispatch names as dead (`#885` `per_phase_generated_surface_gates_and_batch_defer`,
  abandoned; `#785` `lean_plan_gate_collision_authoring_guidance`, completed) stayed behind in the
  source repository's archive per the dispatch's own migration-provenance note and were never
  migrated into this repository — there is nothing live here to abandon or re-litigate.
- Task **596** (`generated_file_scope_vs_readonly_risk`, `[not_started]`) is confirmed live in
  `specs/state.json` with `"dependencies": [595, 597, 599]` — it already carries the hard
  dependency on this task that its own `audit_verdict` ruling describes ("filed as a REFINEMENT
  of #912's remedy (i)... carries a hard dependency on #912," where `#912` is this task's number
  in the originating repository, now 597 here). No action is needed on 596 from this phase; its
  own research phase will re-check whether this task's landed remedy already distinguishes
  generator-written from hand-edited read-only scope.
- Task **599** (`batch_gate_deferral_narrowing_for_project_sources`, `[not_started]`) shares
  `plan-format.md` file territory (specifically its "Batch-aware deferral" subsection) but targets
  a structurally different mechanism — the `## Batch Gate Deferral` directive's narrowing forms
  (`run-all.sh --only`, `verify-deploy.sh --only-gate`) lacking a form for project-source-only
  phases — not the `Files to modify` coupled-generated-surface obligation this task adds. No
  dependency edge connects 599 to 597; both should be read as co-located but independent when 596
  or a plan for this task eventually touches `plan-format.md`.

## Decisions

- **Confirmed**: Defect A's content gap claim is false (the guidance exists and is correct);
  its reach gap claim is true and independently verified from the index entry and the agent file.
- **Confirmed**: Defect B's Condition 7 acceptance-window formula is wrong; the correct rule is
  `candidate = max(1500, floor(lines/100)*100 + 200)`, accept `N` iff `N ∈ {candidate-100,
  candidate}`, derived from Mathlib `master`'s actual linter source and verified exactly against
  both cited data points.
- **Decided**: the index-entries reach mechanism (option 3 of the dispatch's three) is not
  recommended without a change to `context-discovery.md`'s OR-based adaptive query semantics,
  because `planner-agent` is a cross-domain shared agent and an `agents[]`-only or OR-combined
  match would leak Lean-specific guidance into every other domain's plan dispatches. This is a
  reasoned rejection, not an oversight, and is carried into the Recommendations below as the
  "why" the dispatch asked for.
- **Decided**: no action needed on prior records `#885`/`#785` (both confirmed dead, outside this
  repository); task 596's dependency on this task and task 599's shared-but-independent status are
  both already correctly reflected in `specs/state.json` and need no correction from this phase.

## Recommendations

1. **Defect A, remedy (i) — plan-format.md obligation.** Add a new subsection to
   `agent-system/extensions/core/context/formats/plan-format.md`'s `Files to modify` contract,
   positioned parallel to the existing "Whole-tree-claim declaration rule" and "Correction-target
   existence obligation" subsections (both under the same `Files to modify` heading, ~lines
   196–245). Shape it the same way those two are shaped: a plain-language rule, a worked
   consequence, and a pointer to the enforcement subsection. Content: *a phase whose edits move a
   quantity that a generated artifact derives MUST declare that artifact's path in the same
   phase's `Files to modify` block and schedule its regeneration step in that same phase — not a
   later reconciliation phase — whenever the generating check is commit-blocking (enforced by a
   pre-commit hook or equivalent); a check that is advisory-only / later-verification-only may
   legitimately defer to a reconciliation phase.* This directly generalizes Condition 1's
   asymmetry (surface (b) cannot wait; surface (a) legitimately can) into repo-agnostic language.

2. **Defect A, remedy (ii) — reach mechanism: edit `planner-agent.md` directly, not
   `index-entries.json`.** Add a new numbered item to `planner-agent.md`'s Stage 4 phase-authoring
   checklist (after item 12, "Confirm a Correction Target Exists Before Naming It") — or a new
   Stage between Stage 3 and Stage 4 — that reads, generically (not hardcoding "lean4" as the only
   case, so the pattern extends to a future domain without a second edit here): *"If this
   dispatch's `task_type` has a domain-specific plan-authoring gotchas file (check
   `.claude/context/index.json` for a `project/**` entry whose `topics` or `keywords` name
   'plan-authoring' and whose `task_types[]` contains this dispatch's task_type), Read it before
   decomposing phases, and treat its enumerated conditions as additional checklist items for this
   plan."* This keeps the per-domain content itself in its own extension's `index-entries.json`
   (unchanged — `plan-authoring-gate-collisions.md`'s entry needs no edit), while making
   `planner-agent.md` the one place that knows to go looking, gated on `task_type` rather than on
   the agent-identity dimension that caused the OR-semantics hazard above. This is the
   "planner-agent context pointer keyed on lean intent" option the dispatch named, generalized
   slightly so it is not a second Lean-only special case stacked onto the existing "Lean Intent"
   field. If a future task finds this pattern recurring across three or more domains, the
   `hard_contracts`-style manifest-driven injection in `orchestrate-build-dispatch.sh`
   (`routing_lookup_flat "hard_contracts" "$task_type"`, already a generic per-task_type lookup
   precedent) is the natural next generalization — introduce a parallel, always-on
   `plan_context_pointers` manifest key then, rather than now, per the same
   "measure before promoting" discipline `plan-format.md`'s own enforcement subsections already
   use for other advisory checks.

3. **Defect A, remedy (iii) — advisory validate-artifact.sh check.** Model the new check on the
   existing `derived_artifact_probes` declaration in `.claude-extensions.json`
   (`context/standards/repo-level-declarations.md`, read by
   `scripts/lib/derived-artifact-probe-lib.sh`): same survivability pattern (a hand-authored
   sibling top-level key the loader never touches), same fail-open-on-absence guarantee (no key,
   no `jq`, empty array, or a malformed entry each yield zero effect with at most a named
   warning), same declaration point. It needs a **new**, differently-shaped array, though —
   `derived_artifact_probes`' schema (`component`/`check_command`/`derived_output_dirs`) has no
   field for "which source pattern triggers this coupling," because it was built for
   postflight staleness checking, not plan-time declaration-completeness checking. Propose:
   ```json
   "coupled_generated_surfaces": [
     {"trigger_glob": "FormalSystem/**/*.lean", "generated_paths": ["typst/generated/status.typ", "README.md", "FormalSystem/Metalogic/README.md"], "note": "line-count-derived surfaces; see plan-authoring-gate-collisions.md Condition 1"}
   ]
   ```
   The new `validate-artifact.sh` check reads this array the same way
   `derived_probe_entries` reads its own (reuse the read-and-validate-per-entry pattern from
   `derived-artifact-probe-lib.sh` rather than re-deriving it), and for each phase whose `Files to
   modify` entries match a `trigger_glob`, warns (advisory-first, same `--strict` promotion
   pattern as every other check on this page) if the same phase's `Files to modify` is missing any
   of that entry's `generated_paths`. Fail-open identically when the key is absent — this keeps
   the check entirely inert for every repository that declares nothing, including this one.

4. **Defect B.** Rewrite Condition 7 of `plan-authoring-gate-collisions.md` to state the verified
   rule: `candidate = max(1500, floor(lines/100)*100 + 200)`; accepted baseline values are exactly
   `{candidate - 100, candidate}`; any other declared value triggers "expected to be {candidate}."
   Keep the existing "Plan-authoring consequence" sentence (schedule both the baseline and its
   re-tightening as named phase work) — it is correct and does not depend on the exact window
   shape. Add one line noting the rule was derived from Mathlib `master` and verified against two
   independent citations rather than assumed, and that a plan or implementation phase with access
   to the originating repository should re-confirm against its pinned `lake-manifest.json` commit
   before treating this as permanently authoritative (toolchains and linter internals do drift).

5. **No action recommended** on prior records `#885`/`#785` or on tasks 596/599's existing
   dependency/territory state — all three are already correctly represented in `specs/state.json`
   and require no correction from this task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The fetched Mathlib `master` `longFile` source may not exactly match the pinned `Lean v4.33.0-rc1`/Mathlib commit the originating repository actually built against | M | L | Both cited data points reproduce exactly against the fetched source, which is strong corroboration; Recommendation 4 explicitly flags re-confirmation against the pinned commit as a follow-up rather than treating this as closed forever |
| A future planner-agent.md edit for remedy (ii) could itself become a growing list of per-domain special cases if written narrowly (e.g. literally `if task_type == "lean4"`) | M | M | Recommendation 2 is phrased generically (task_type-driven index lookup) specifically to avoid this; implementation phase should resist the temptation to hardcode "lean4" by name |
| The new `coupled_generated_surfaces` declaration (remedy iii) could be perceived as redundant with `derived_artifact_probes` and prompt an attempt to unify them, losing the distinct plan-time-vs-postflight-time purposes | L | M | Recommendation 3 states explicitly why the schemas differ (trigger pattern vs. check command) and why they serve different lifecycle stages; a planning phase should keep them as two declarations under `.claude-extensions.json`, not force one schema to serve both |

## Context Extension Recommendations

- **Topic**: cross-domain reach hazards of `context-discovery.md`'s OR-based adaptive query when
  a shared, cross-domain agent (e.g. `planner-agent`, `general-implementation-agent`,
  `general-research-agent`) is involved.
- **Gap**: `context-discovery.md` documents the OR semantics and a domain-scoping convention for
  `commands[]` ("Check Command Scope" section), but has no equivalent explicit warning for the
  `agents[]` dimension when the agent in question is shared across every domain rather than
  domain-exclusive (like `lean-research-agent`). This gap is exactly what made the "obvious" fix
  to Defect A's reach problem unsound, and the same hazard would recur for any future
  domain-specific content meant to reach `planner-agent`, `general-implementation-agent`, or
  `general-research-agent`.
- **Recommendation**: add a short subsection to `context-discovery.md`, near "Check Command
  Scope," naming this as a sibling hazard for the `agents[]` dimension — "a domain-specific entry
  must not add a cross-domain shared agent to `agents[]` under the OR-combined adaptive query; use
  a task_type-gated pointer inside that shared agent's own file instead" — so a future author does
  not rediscover this the same way this task did.

## Appendix

- Search/read commands used: direct `Read`/`grep`/`jq` inspection of
  `plan-authoring-gate-collisions.md`, `plan-format.md` (full `Files to modify` contract and all
  enforcement-level subsections), `planner-agent.md` (full file), `index-entries.json` (lean
  extension, full `load_when` survey across all ~40 `project/lean4/**` entries),
  `context-discovery.md` (full file), `repo-level-declarations.md` and
  `derived-artifact-probe-lib.sh` (header/schema), and `specs/state.json` queried via `jq` for
  tasks 596/599/597's descriptions, dependencies, and status.
- Web source: `https://raw.githubusercontent.com/leanprover-community/mathlib4/master/Mathlib/Tactic/Linter/Style.lean`
  (and its HTML mirror at `https://github.com/leanprover-community/mathlib4/blob/master/Mathlib/Tactic/Linter/Style.lean`),
  fetched via a delegated web-fetch pass; the `longFile` linter's full Lean source was quoted
  verbatim and cross-checked against both dispatch citations (see Findings table above).
- Dispatch file read in full before this research began:
  `specs/597_coupled_generated_surfaces_in_plan_authoring/.dispatch/4.md`.
