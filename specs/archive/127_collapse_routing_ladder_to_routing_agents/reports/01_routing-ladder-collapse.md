# Research Report: Collapse Routing Ladder to routing_agents

**Task**: 127 - Collapse routing ladder to routing agents
**Started**: 2026-10-02T00:00:00Z
**Completed**: 2026-10-02T00:00:00Z
**Effort**: medium (mostly mechanical manifest edits; one load-bearing cross-extension fix)
**Dependencies**: task 121 (hard-mode file deletions), task 124, task 125 (command deletions) — all confirmed landed
**Sources/Inputs**: codebase exploration (manifest.json ×20, manifest-routing-lib.sh, command-route-skill.sh, command-route-agent.sh, lint-routing-wiring.sh, verify-deploy.sh, test-routing-resolution.sh, check-extension-docs.sh, epi.md), archived design report specs/archive/116_core_agent_system_consolidation/reports/03_target-state-design.md (section A3/A4)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dependency chain is confirmed landed: `/research`, `/plan`, `/implement` are deleted
  (task 125), and core's hard-mode skill/agent files are deleted with core's own
  `routing`/`routing_hard`/`routing_agents_hard` blocks already removed (task 121). Core's
  manifest already shows the end-state shape (`routing_agents` only).
- **Critical correction to the task's own DEPENDS ON premise**: `command-route-skill.sh` is
  **not** caller-free today. `agent-system/extensions/epidemiology/commands/epi.md` (a live,
  non-deleted command) directly sources it at its own "Step 2: Delegate" stage for `/epi {N}`
  task-number resume. This is not a surprise discovery requiring interpretation — the codebase
  already documents it verbatim in `test-routing-resolution.sh`'s own comments: *"The one
  surviving command-route-skill.sh caller is the epidemiology extension's /epi command."*
  Retiring the script (Work item 2) will break `/epi {N}` resume unless `epi.md` is migrated
  first (concrete fix below — low-risk, one-line-equivalent change).
- Scope of manifest edits is now precisely counted: 17 of 19 non-core manifests declare a
  `routing` block (all but `literature`/`slidev`, which are `routing_exempt`); only `cslib` and
  `lean` declare `routing_hard`. `routing_agents_hard` (cslib, lean) is **not** touched by this
  task — it remains live, consumed by `command-route-agent.sh`'s `--hard` branch, until a
  separate, not-yet-dispatched follow-on task migrates cslib/lean off dedicated hard-mode agent
  files onto the already-built (but currently unused by any manifest) `hard_contracts`
  dispatch-prep injection mechanism. Post-task-127 state is a **two-block** model
  (`routing_agents` + `routing_agents_hard`), matching Work item 3's literal wording, not the
  one-block end state the task's CONTEXT prose loosely describes (that one-block state is the
  *eventual* target, after the separate follow-on task, not this task's own deliverable).
- Work item 5's audit (colon-suffixed `routing_agents` values) found **zero live instances**
  anywhere across all 20 manifests. `present`'s only colon-suffixed value
  (`"present:grant": "skill-grant:assemble"`) lives in `routing.implement` (a skill name), which
  disappears entirely with the `routing` block removal — moot, as the task description itself
  anticipated for "the routing half." No `routing_agents`/`routing_agents_hard` value anywhere
  carries a `:` suffix, so there is nothing to "settle" beyond recording the audit's negative
  result.
- Work item 6 ("extend lint-routing-wiring.sh so any routing_agents value naming a nonexistent
  agent fails verify-deploy") **already exists**: `lint-routing-wiring.sh` Check B already
  validates every `routing_agents`/`routing_agents_hard` value against on-disk agent files and
  is already wired into `verify-deploy.sh` as gate 7 (hard FAIL, not a warning). This item
  appears to already be satisfied by prior work; treat it as "confirm and note," not "build."
- Documentation fallout extends well beyond the task's declared 4-path source-store edit list.
  `merge-sources/claudemd.md` (generates the deployed CLAUDE.md "Routing Mechanism" section) and
  `context/guides/hard-mode-routing.md` (an entire guide dedicated to `routing_hard`/
  `command-route-skill.sh` resolution) both describe the pre-collapse four-block model as current
  fact and will be actively wrong once this task lands. `docs/guides/creating-commands.md` and
  `docs/templates/command-template.md` teach new command authors to source the
  soon-to-be-retired script. These are flagged as necessary companions to this task, not
  optional polish — left alone, CLAUDE.md (read every session) would misstate a model that no
  longer exists.

## Context & Scope

Task 127 collapses the routing ladder's manifest surface from up to four blocks
(`routing`, `routing_hard`, `routing_agents`, `routing_agents_hard`) down to the subset that
remains meaningful now that `/research`/`/plan`/`/implement` (the skill-layer commands
`routing`/`routing_hard` existed to serve) are deleted. The task's own file-scope declaration
names exactly four source-store paths to edit: all 19 non-core `manifest.json` files,
`command-route-skill.sh`, `manifest-routing-schema.md`, and `lint-routing-wiring.sh`. This
research verifies the dependency preconditions, establishes the exact current state of every
manifest's routing blocks, confirms (and corrects) the task's own stated premise about
`command-route-skill.sh`'s caller set, and surfaces every file outside the declared scope whose
correctness depends on this collapse landing cleanly.

Reference consulted: `specs/archive/116_core_agent_system_consolidation/reports/03_target-state-design.md`
sections A3 (routing collapse decision) and A4 (hard mode as contract injection, including the
already-implemented `hard_contracts` manifest key and `routing_lookup_flat()` mechanism, and the
explicit "deploy-time warning, not hard error" migration-path decision for cslib/lean's
still-live `routing_hard`/`routing_agents_hard`).

## Findings

### Dependency preconditions — confirmed landed

- Task 125: deleted `/research`, `/plan`, `/implement` and the three associated skill
  directories (`skill-researcher`, `skill-planner`, `skill-implementer`), plus pruned dangling
  manifest routing and the live router default. `agent-system/extensions/core/commands/`
  confirms no `research.md`/`plan.md`/`implement.md` exist today.
- Task 121: deleted the seven core hard-mode lifecycle files (`skill-researcher-hard`,
  `skill-planner-hard`, `skill-implementer-hard`, `skill-orchestrate-hard`,
  `general-research-hard-agent.md`, `planner-hard-agent.md`,
  `general-implementation-hard-agent.md`) and removed core's own
  `routing_hard`/`routing_agents_hard` manifest blocks (verified: core's manifest today has
  `routing_hard: null`, `routing_agents_hard: null`, `routing: null`, `routing_agents` populated
  — i.e. core already shows the target end state for its own manifest). Task 121 explicitly left
  cslib's own live `routing_hard`/`routing_agents_hard` entries (`research.cslib`,
  `implement.cslib`) untouched, by design (per its own commit message and per A4(iii)'s decision
  below).
- `/revise` was independently confirmed to never reference `command-route-skill.sh` or
  `command-route-agent.sh` — the task description's claim that it "does not use this resolver
  and is unaffected" is correct.

### Current manifest routing-block inventory (all 20 manifest.json files)

| Manifest | `routing` | `routing_hard` | `routing_agents` | `routing_agents_hard` |
|---|---|---|---|---|
| core | false (already removed) | false | true | false |
| cslib | **true** | **true** | true | true |
| email | **true** | false | true | false |
| epidemiology | **true** | false | true | false |
| filetypes | **true** | false | true | false |
| formal | **true** | false | true | false |
| founder | **true** | false | true | false |
| latex | **true** | false | true | false |
| lean | **true** | **true** | true | true |
| literature | false (exempt) | false | false | false |
| memory | **true** | false | true | false |
| nix | **true** | false | true | false |
| nvim | **true** | false | true | false |
| present | **true** | false | true | false |
| python | **true** | false | true | false |
| rust | **true** | false | true | false |
| slidev | false (exempt) | false | false | false |
| typst | **true** | false | true | false |
| web | **true** | false | true | false |
| z3 | **true** | false | true | false |

Net removal scope for Work item (1): delete the `routing` key from **17 manifests** (all
non-core, non-exempt extensions); delete the `routing_hard` key from **2 manifests** (cslib,
lean). `routing_agents` and `routing_agents_hard` are **not** touched — every manifest keeps
whatever it already has in those two blocks, including cslib's and lean's live
`routing_agents_hard` entries.

### `present`'s custom `critique` op survives unchanged

`present/manifest.json` declares a fourth op, `critique`, inside both `routing` and
`routing_agents` (`routing_agents.critique.present:slides = "slide-critic-agent"`). Verified:
`command-route-agent.sh`'s `$1` (`op`) parameter is a plain string passed straight into
`routing_lookup()`'s `.[$b][$op][$tt]` jq path — there is no hardcoded `research|plan|implement`
enum anywhere in the ladder itself, so an extension-specific op resolves identically to the
three standard ones. The task description's "(plus any extension-specific op like present's
critique)" carve-out requires no special-case code; only the manifest edit (drop
`routing.critique`, keep `routing_agents.critique`) is needed.

### Work item 5 — colon-suffixed `routing_agents` audit (present + all extensions)

`present/manifest.json`'s `routing.implement` block carries the known defect:
`"present:grant": "skill-grant:assemble"` and `"present:slides": "skill-slides:assemble"` — a
workflow_type encoded into a skill-name string that no consumer ever splits, resolving to a
nonexistent skill directory. This lives entirely inside the `routing` block (skill names), which
is deleted wholesale by Work item (1) — moot, exactly as the task description predicted for "the
routing half."

A mechanical jq sweep of every manifest's `routing_agents` and `routing_agents_hard` values
(`contains(":")`) across all 20 manifests returned **zero matches**. `present`'s own
`routing_agents.implement` values (`grant-agent`, `budget-agent`, `timeline-agent`,
`funds-agent`, `slidev-assembly-agent`) are all clean, unsuffixed agent names — the
colon-suffix defect does **not** have a `routing_agents`-side counterpart anywhere today.

**Conclusion for item 5**: no encoding decision needs to be built (no resolver split, no
suffix-stripping convention) because there is no live instance to settle. Recommend recording
this negative audit result as a one-line note in `manifest-routing-schema.md` (e.g. under the
"Agent Names Are Declared, Never Derived" section) so a future reviewer does not re-open the
question without first re-running the same audit.

### Work item 6 — nonexistent-agent-fails-verify-deploy — already implemented

`lint-routing-wiring.sh` Check B ("every value in `.routing_agents` / `.routing_agents_hard`
names an agent file that exists somewhere under `agent-system/extensions/*/agents/`... A
declaration pointing at a non-existent agent is a FAIL") already does exactly what item 6 asks
for, and is already invoked as `verify-deploy.sh` gate 7 (`routing_lint_output=$(... bash
lint-routing-wiring.sh --verbose ...)`, hard `fail` on nonzero exit — not merely a warning).
`test-routing-resolution.sh` Assert 2 independently re-verifies the same property.

This item's described defect ("a manifest naming a nonexistent dispatch target, shipped
silently") appears to have already been fixed by whatever prior work introduced Check B (a
single, undated commit message "task 981 phase 5: routing wiring-validation lint and
verify-deploy gate7" — task numbers this low predate the current numbering sequence, i.e. this
landed well before task 127 was authored). Recommend the plan treat item 6 as **verify, not
build**: confirm Check B still runs correctly once `routing`/`routing_hard` are removed (it does
not read those blocks at all, so removal is a no-op for Check B), and close the item with a note
rather than writing new lint logic.

### Work item 3/4 — re-scoping Checks A and C

Current behavior: Check A asserts every `routing.{op}.{tt}` key has a `routing_agents.{op}.{tt}`
counterpart; Check C asserts every `routing_hard.{op}.{tt}` key has a
`routing_agents_hard.{op}.{tt}` counterpart. Once `routing`/`routing_hard` are deleted from every
manifest, both checks' outer `jq -r '(.routing // {}) | to_entries[]...'` loops iterate over an
empty object on every manifest — they still "pass" (vacuously, `any_manifest` stays true from the
manifest-discovery loop, zero keys to check means zero failures) but no longer validate anything
real. This matches the task's own framing ("re-scoped to check only `routing_agents`
completeness against itself") — the checks must be rewritten, not left to vacuously pass.

Recommended concrete re-scope (for the planner to adopt or refine): redefine Check A as an
**internal cross-op completeness check** on `routing_agents` alone — e.g., for each manifest,
collect the set of task_type keys declared under `routing_agents.research`,
`routing_agents.plan`, and `routing_agents.implement`; flag (FAIL or WARN — planner's call) any
task_type present in one op's key set but absent from another's, since a task_type routable for
research but silently falling to the generic default for plan/implement is the same "silent gap"
failure class Check A originally existed to catch. Check C has no surviving `routing_hard` data
to cross-check against; two reasonable dispositions: (a) retire Check C entirely (its
counterpart-key purpose is gone since there is no second source array for cslib/lean's
`routing_agents_hard` to be checked against), or (b) repurpose Check C to run the same
self-completeness logic as re-scoped Check A, but scoped to `routing_agents_hard` (research vs.
implement key parity) for the two manifests that still declare it. Option (b) keeps lint
coverage over cslib/lean's still-live hard-mode wiring, consistent with A4(iii)'s decision not to
let `routing_agents_hard` go unvalidated during its remaining (as-yet-undetermined-length)
transitional lifetime. This research recommends (b) as the safer default, but flags it as a
planner decision point, not a settled fact.

### Critical finding — `/epi` is a live, acknowledged surviving caller of `command-route-skill.sh`

`agent-system/extensions/epidemiology/commands/epi.md` (STAGE 2: RESEARCH DELEGATION, "Step 2:
Delegate") contains:

```bash
source .claude/scripts/command-route-skill.sh "research" "$task_type" "skill-epi-research" "${effort_flag:-}"
skill_name="$SKILL_NAME"
```

This is a genuine, active invocation — not a stale comment or an unreachable branch — reached
whenever `/epi {task_number}` resumes an existing epi task to delegate to research. The task's
own DEPENDS ON clause asserts "only the now-deleted /research, /plan, /implement, /revise-adjacent
paths called it" — this is incomplete. The codebase already knows about and documents this exact
gap: `test-routing-resolution.sh` (lines ~185-187) states verbatim: *"The one surviving
command-route-skill.sh caller is the epidemiology extension's /epi command, whose `epi` task type
was never declared in any `routing_hard` block and is therefore untouched by [a prior, narrower]
removal."* That prior removal only concerned `routing_hard` (core's); it explicitly left `/epi`'s
standard-mode `routing` dependency in place, correctly anticipating that a *later* task (this one)
would need to resolve it before fully retiring the script.

**Why this is low-risk to fix, not a blocker to the task overall**: `epidemiology/manifest.json`'s
`routing.research` block maps `epi`/`epi:study`/`epidemiology` all to `"skill-epi-research"` —
which is *exactly* the same string `epi.md` already passes as `command-route-skill.sh`'s own
`$3` (`default_skill`) argument. Once the `routing` block is deleted, sourcing
`command-route-skill.sh` would (if the file still existed) fall through to that same default and
produce an identical `SKILL_NAME`. The resolution behavior never actually depended on the
manifest declaration; the call was always going to resolve to its own default. This means the fix
is a pure simplification, not a behavior change: replace `epi.md`'s Step 2 three-line
`source .../command-route-skill.sh ...` block with a direct `skill_name="skill-epi-research"`
assignment (optionally retaining the `effort_flag` handling only if epi ever grows a `routing_hard`
entry — it currently has none, so even that can be dropped).

**Recommendation**: add `agent-system/extensions/epidemiology/commands/epi.md` to this task's
file scope. Without this fix, Work item (2)'s "retire command-route-skill.sh" cannot be done
safely — deleting the file while `/epi {N}` still sources it would break that command's
task-number-resume path at runtime (a `source: file not found` failure), not merely leave stale
documentation.

**Separately noted, not required by this task**: `epi.md`'s prose elsewhere ("After task creation,
the user runs `/research`, `/plan`, and `/implement` to complete the workflow"; "Next steps: 1.
/plan {N} ... 2. /implement {N} ...") references commands deleted by task 125 and was evidently
never updated at that time. This is a pre-existing doc-rot defect, independent of the routing
collapse. Fixing the `command-route-skill.sh` call is necessary for this task; fixing the
stale `/research`/`/plan`/`/implement` prose nearby is a natural adjacent cleanup while the file
is open, but is not load-bearing for this task's own correctness and is flagged here only so the
planner can decide whether to bundle it.

### Documentation fallout beyond the declared 4-path file scope

The following files assert the pre-collapse four-block model or the continued existence of
`command-route-skill.sh` as fact, and will be actively incorrect once this task lands. None are
in the task's declared `SOURCE STORE IS THE EDIT TARGET` list; each is flagged here as a
necessary companion edit, with rationale, for the planner to fold in or explicitly defer:

1. **`agent-system/extensions/core/merge-sources/claudemd.md`** (lines ~215-222) — generates the
   deployed CLAUDE.md "Routing Mechanism" section verbatim (visible today in this very session's
   injected CLAUDE.md content). States "Every routing consumer (`command-route-skill.sh` for
   skills, `command-route-agent.sh` for agents...)" and "the `routing_hard`/`routing_agents_hard`
   manifest blocks" and references "all four manifest blocks" in
   `manifest-routing-schema.md`. This is the single highest-visibility piece of fallout — every
   agent session reads generated CLAUDE.md. Recommend updating this section as part of this task
   (it is a small, surgical edit: drop the `command-route-skill.sh` mention, correct "four" to
   the current block count).
2. **`agent-system/extensions/core/context/guides/hard-mode-routing.md`** (175 lines) — an entire
   guide dedicated to `command-route-skill.sh`'s `routing_hard` resolution path, including an
   "Adding routing_hard Entries" how-to section that becomes actively wrong instructions (it
   would teach an extension author to add a block to a script that no longer reads it). Given
   `routing_agents_hard` still survives this task (cslib/lean), the guide cannot simply be
   deleted outright — parts of it (the agent-side `routing_agents_hard` resolution semantics,
   the `-hard` append-fallback note) remain accurate and relevant. Recommend a scoped rewrite
   (strip the `command-route-skill.sh`/`routing_hard` sections, keep the
   `routing_agents_hard`-specific content) rather than deletion. This is more than a one-line
   fix; size it as its own plan phase or sub-step.
3. **`agent-system/extensions/core/docs/guides/creating-commands.md`** and
   **`agent-system/extensions/core/docs/templates/command-template.md`** — both teach "STAGE 2:
   DELEGATE" as `source .claude/scripts/command-route-skill.sh ...` + Skill-tool invocation, as
   the canonical pattern for writing *any* new command. Post-retirement this actively misguides
   a future command author. Recommend updating both to the `command-route-agent.sh` +
   direct-agent-dispatch pattern that is now the actual live convention (as documented in
   `skill-orchestrate/SKILL.md` and this report's command-route-agent.sh findings above).
4. **`agent-system/extensions/core/context/standards/shell-strict-mode.md`** (line ~147) — lists
   `command-route-skill.sh` in an example enumeration of "sourced into a command/skill's own
   shell" scripts. Trivial one-token removal once the file is deleted.
5. **`agent-system/extensions/core/scripts/check-extension-docs.sh`** (Rule around lines
   907/931) — reads `.routing`/`.routing_hard` directly to validate routing targets are
   source-grounded. Once every manifest's `routing`/`routing_hard` keys are removed, these jq
   expressions iterate over empty objects and the rule becomes permanently vacuous (not broken,
   never fails, just dead weight). Not urgent, but worth a one-line note or a follow-up cleanup
   task; not recommended as in-scope for this task given it is read-only dead code after the
   collapse, not a correctness risk.
6. **`agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`** — Assert 1 builds
   its entire test matrix mechanically from every manifest's `.routing`/`.routing_hard` blocks.
   Once 17 manifests lose `routing` and 2 lose `routing_hard`, this matrix shrinks to near-zero
   (it will still correctly test `/epi`'s remaining default-fallback path and
   `routing_agents`/`routing_agents_hard` resolution via Assert 2, which is untouched). This is
   not a failure — the test continues to pass — but its coverage intent (validating
   `command-route-skill.sh` resolution) becomes moot once that script no longer has a manifest to
   resolve against for its sole surviving caller. Consistent with archived report A4(iv)'s
   "retarget, not delete" decision for test files whose underlying mechanism survives in a
   different shape, recommend a follow-up retarget of Assert 1's framing (or its removal, if
   Assert 2 alone is judged sufficient coverage post-collapse) rather than silent abandonment.
   Not required to land this task's own correctness, since the test will not fail either way.
7. **`agent-system/extensions/core/scripts/verify-deploy.sh`** gate 16 comment text (lines
   ~883-889) says "both blocks remain genuinely consulted by command-route-skill.sh (for
   /research, /plan, /implement) and by command-route-agent.sh until those two follow-on tasks
   land." This task is one of "those two follow-on tasks." The gate's actual jq logic
   (`has("routing_hard") or has("routing_agents_hard")`) needs no behavior change — it will
   correctly continue to WARN on cslib/lean's surviving `routing_agents_hard` — but the comment
   prose becomes stale and should be corrected for the next reader (small edit, not required for
   correctness since it is a comment only).

## Recommendations

1. **Expand file scope by exactly one load-bearing file**: add
   `agent-system/extensions/epidemiology/commands/epi.md` to the task's edit targets. Replace its
   Step 2 `source .../command-route-skill.sh ...` + `skill_name="$SKILL_NAME"` with a direct
   `skill_name="skill-epi-research"` assignment (verified behavior-identical, since that is
   already both the manifest's declared value and the call's own default argument). This is
   the one correction required before Work item (2) can be executed safely.
2. **Treat Work items 5 and 6 as audit-and-confirm, not build**: item 5 has zero live instances
   to settle (record the negative result in `manifest-routing-schema.md`); item 6 is already
   implemented by `lint-routing-wiring.sh` Check B and already wired into `verify-deploy.sh` gate
   7 (confirm it survives the manifest edits unchanged, since it never reads `routing`/
   `routing_hard`).
3. **Execute the manifest edits exactly as inventoried above**: delete `routing` from 17
   manifests, `routing_hard` from 2 (cslib, lean); leave `routing_agents` and
   `routing_agents_hard` untouched everywhere, including cslib/lean's hard-mode agent entries.
   Do not attempt to migrate cslib/lean onto `hard_contracts` as part of this task — that
   mechanism already exists in code (`orchestrate-build-dispatch.sh` Stage 3.5,
   `routing_lookup_flat()`) but adopting it for cslib/lean is explicitly a separate, larger,
   not-yet-dispatched follow-on task (per the archived design report's A4(iii) "deploy-time
   warning, not hard error" transitional decision, and per this task's own file scope, which
   names no agent/skill files for cslib or lean).
4. **Re-scope Check A as an internal `routing_agents` cross-op completeness check** (task_type
   present in one op must be present in all ops it's expected in) and **re-scope or retire Check
   C** for `routing_agents_hard`'s own internal completeness (recommend keeping it, scoped to
   cslib/lean, per the rationale in Findings above) — this is a planner decision to finalize, not
   a fully mechanical translation, since "completeness against itself" admits more than one
   reasonable concrete rule.
5. **Update `manifest-routing-schema.md`** (Work item 3) to: drop the `routing`/`routing_hard`
   rows from "The Five Blocks" table (leaving `routing_agents`, `routing_agents_hard`, and
   `hard_contracts` — a three-entry, not literally "two-block," table once `hard_contracts` is
   counted; the "two-block model" phrasing in Work item 3 appears to mean "two *routing* blocks"
   as distinct from the unrelated one-level `hard_contracts` key, which the document already
   treats as a separate category — recommend the updated doc state this distinction explicitly
   to avoid the ambiguity this research had to resolve by cross-referencing `verify-deploy.sh`
   gate 16); remove the "Completeness rule" paragraph's `routing`/`routing_hard` cross-check
   language and replace with the re-scoped Check A/C description from item 4 above; record the
   item-5 negative audit result; update "Adding Routing to a New Extension" example to drop the
   `routing` block from the sample JSON.
6. **Fold in or explicitly defer** the six adjacent-documentation items listed under "Documentation
   fallout" above. Items 1 (claudemd.md) and 3 (creating-commands.md/command-template.md) are
   recommended as in-scope for this task (high visibility, low edit cost, directly and
   immediately falsified by this task's own changes). Item 2 (hard-mode-routing.md) is
   recommended as in-scope but sized as its own phase given its length. Items 4, 5, 6, 7 are
   low-risk/low-visibility and can reasonably be deferred to a follow-up task without blocking
   this one's correctness — but should be named explicitly in the plan's exclusions rather than
   silently dropped, consistent with this repo's "finish or explicitly flag, never silently
   narrow" norm.
7. **No task-number references** belong in any of the manifest.json, script, or guide files
   touched — consistent with `no-task-references-in-deliverables.md`; this report itself lives
   under `specs/**` and is exempt.

## Decisions

- `routing_agents_hard` is **out of scope** for removal in this task; only `routing` and
  `routing_hard` are removed. This resolves the apparent tension between the task's CONTEXT prose
  ("only routing_agents remains meaningful") and its own WORK item 3 wording ("collapsed
  two-block model, down from four") in favor of the WORK items' literal, mechanical instructions,
  corroborated by `verify-deploy.sh` gate 16's comment describing two *separate* follow-on tasks
  (this one, for `command-route-skill.sh`/`routing`/`routing_hard`; a distinct future one, for
  `command-route-agent.sh`/`routing_agents_hard`).
- `agent-system/extensions/epidemiology/commands/epi.md` must be added to this task's file scope;
  retiring `command-route-skill.sh` is not safely executable without this companion fix.
- Work items 5 and 6 are resolved by audit (no live colon-suffix instances; nonexistent-agent
  guard already implemented and wired) rather than requiring new code.

## Risks & Mitigations

- **Risk**: deleting `command-route-skill.sh` without first migrating `epi.md` breaks `/epi {N}`
  resume. **Mitigation**: sequence the plan so `epi.md`'s migration lands in the same phase as
  (or strictly before) the script deletion; verify with a manual `/epi` dry run or at minimum a
  grep-confirmed absence of any remaining `command-route-skill.sh` source line before deleting
  the file.
- **Risk**: re-scoping Check A/C incorrectly could either (a) silently stop catching real gaps
  (too permissive) or (b) false-positive on legitimately asymmetric `routing_agents` declarations
  (e.g. a task_type that is genuinely research-only with no plan/implement phase — does any
  extension have this shape today? Not observed in this research; worth a planner spot-check
  before finalizing the rule). **Mitigation**: planner should enumerate every manifest's
  `routing_agents` key sets per op before finalizing the exact completeness predicate, rather
  than assuming full symmetry is always correct.
- **Risk**: scope creep from the documentation fallout list (7 adjacent files) ballooning this
  task beyond its declared file scope. **Mitigation**: the Recommendations section above already
  triages these into "fold in" vs. "defer, but name explicitly" — the plan should preserve that
  triage rather than either silently dropping all of them or silently expanding to fix all seven.

## Context Extension Recommendations

- **Topic**: routing-ladder collapse completion state. **Gap**: no existing context file records
  which of the two "follow-on tasks" `verify-deploy.sh` gate 16 refers to has landed and which
  remains (this task resolves one; `routing_agents_hard`'s eventual retirement is the other,
  currently undocumented as a tracked task). **Recommendation**: once this task completes,
  consider a short addendum to `context/guides/manifest-routing-schema.md` or a new tracked task
  entry explicitly naming the remaining follow-on (cslib/lean migration off dedicated hard-mode
  agent files onto `hard_contracts`), so gate 16's warning has a discoverable destination rather
  than being the only trace of that remaining work.

## Appendix

Search queries / commands used (representative, not exhaustive):
- `jq -r 'has("routing")'` etc. across `agent-system/extensions/*/manifest.json` (block inventory
  table)
- `grep -rln "command-route-skill"` / `"command-route-agent"` across `agent-system/` (caller
  census), narrowed to actual `source`/invocation lines vs. prose mentions
- `git log --oneline --all | grep -E "task 121:|task 124:|task 125:"` (dependency landing
  confirmation)
- Read: `manifest-routing-lib.sh`, `command-route-skill.sh`, `command-route-agent.sh`,
  `lint-routing-wiring.sh`, `manifest-routing-schema.md`, `hard-mode-routing.md`,
  `verify-deploy.sh` (gates 7, 16), `check-extension-docs.sh` (routing rules), `epi.md`,
  `test-routing-resolution.sh`, `specs/archive/116_core_agent_system_consolidation/reports/03_target-state-design.md`
  (sections A3, A4)
