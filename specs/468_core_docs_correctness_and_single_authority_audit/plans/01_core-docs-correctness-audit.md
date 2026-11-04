# Implementation Plan: Task #468

- **Task**: 468 - Core docs architecture, guide, reference and template set audit for structural
  correctness and single-authority topic ownership
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/468_core_docs_correctness_and_single_authority_audit/reports/01_core-docs-correctness-audit.md
- **Artifacts**: plans/01_core-docs-correctness-audit.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Correct structural defects across the 29 markdown files under
`agent-system/extensions/core/docs/` — dead `/research`/`/plan`/`/implement` command surfaces,
broken relative links, stale command inventories, and three duplication instances — then
establish one authoritative home per duplicated topic with pointers elsewhere. Work proceeds as a
serial chain of per-site edit phases (shared file territory makes parallel waves unsafe), each
gated by a cheap re-derivation of the link resolver and the dead-command classification, closing
with a full gate run and a redeploy to a clean `verify-deploy.sh`.

The edit target is the SOURCE STORE: `agent-system/extensions/core/docs/`, confirmed via
`.claude-extensions.json`'s `.extensions.core.source_dir` =
`/home/benjamin/.config/nvim/agent-system/extensions/core`. Nothing is hand-authored under
`.claude/**`; the deployed tree is refreshed only by `deploy-headless.sh` in the final phase.

### Research Integration

The research report's per-site classification is adopted as the plan's working register and was
spot-checked at planning time; every site verified held up, including the subtle case that a
naive global find/replace would break (see the Scope Hypotheses below). Three additions and one
scope narrowing were derived at planning time and are folded in:

- `architecture/orchestrate-state-machine.md:239` presents `` `/implement {N}` `` as a runnable
  resume command inside the "On cycle limit" paragraph — a dead surface the research enumeration
  did not reach, and one sitting in boundary-owned territory (see Boundary Register, close call B).
- `architecture/orchestrate-state-machine.md:948-955` and `:1393-1397` carry record-versioning
  prose ("used to", "that batch commit is retired", "byte-for-byte unchanged from before this
  design existed") — deferred, not fixed (Boundary Register, deferral 3).
- `guides/copy-claude-directory.md` has **three** `](../commands/README.md)` occurrences (lines 3,
  267, 272), not the two the report names.
- The record-versioning forbidden vocabulary occurs ~56 times across `core/docs/`, ~53 of them
  inside the three boundary-owned architecture files. A corpus-wide remediation is therefore
  declared out of scope; see Scope Narrowing below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch (`roadmap_path` absent, `roadmap_flag` not set).
No ROADMAP.md consultation or update phase applies.

## Goals & Non-Goals

**Goals**:
- Every file under `agent-system/extensions/core/docs/` is free of `/research`, `/plan`,
  `/implement` presented as user-invocable command surfaces, while every genuine phase-name and
  dispatch-name reference ("the research phase", "the implement dispatch") is preserved verbatim.
- Every relative link in the tree resolves, with one documented exclusion class.
- `architecture/system-overview.md`'s command inventory and `docs-README.md`'s documentation map
  reflect the current component set.
- Each duplicated topic has exactly one named authority and a pointer from every other site.
- The `agent-system/extensions/README.md` link is present at each bare "the extension picker"
  prose mention in the four named files.
- The source store is redeployed to a clean `verify-deploy.sh`.

**Non-Goals**:
- Changing what any of the eight boundary-owned documents **asserts** (see Boundary Register).
- Any edit to `reference/standards/agent-frontmatter-standard.md` — excluded from `file_scope`
  entirely; only other files' links *pointing at* it are corrected.
- The 22 per-extension READMEs, `agent-system/extensions/core/README.md`, and
  `agent-system/extensions/README.md` itself.
- Adding a standing relative-link lint to the repo (the research report's own Context Extension
  recommendation) — a follow-up task, not this one. The link check in this plan is a throwaway
  resolver run from the scratchpad.
- A corpus-wide record-versioning remediation (see Scope Narrowing).
- Any dedup overlapping the `agent-system/extensions/core/docs/` territory that task 328
  Phase 19 claims. No dependency edge is declared in either direction; a `file_scope_collision`
  advisory against 328 in a batched dispatch is the intended visibility surface, not an error.

## Scope Boundary: The Load-Bearing Constraint

**This task is scoped to STRUCTURAL correctness only**: dead command surfaces, stale routing
tables and inventories, broken relative links, and duplication. Eight non-terminal records each
own a specific SUBSTANTIVE change to an individual file in this scope:

| Record | Slug | Owns substantive content in |
|--------|------|------------------------------|
| 274 | next_admissible_batch_suggestion | architecture/batch-admit-schema.md |
| 378 | reviser_agent_handoff_contract_contradiction | architecture/handoff-schema.md |
| 387 | whole_tree_regeneration_scope_claim | architecture/orchestrate-state-machine.md |
| 420 | warn_plan_size_exceeds_cycle_budget | architecture/orchestrate-state-machine.md |
| 428 | enforce_planner_agent_terminal_write | architecture/handoff-schema.md |
| 438 | dependency_edge_rationale_semantic_check | reference/standards/multi-task-creation-standard.md |
| 450 | validate_settled_route_before_dispatch | architecture/handoff-schema.md, architecture/orchestrate-state-machine.md |
| 431 | durable_record_for_gate_enforced_verbatim_fragments | reference/standards/agent-frontmatter-standard.md |

This plan declares **NO dependency edges** on any of them. The boundary, not serialization, is
what keeps them from colliding. Nothing in this plan changes what any of those documents asserts
about handoff contracts, batch admission, cycle budgets, regeneration scope, dependency-edge
rationale, planner terminal writes, route validation, or verbatim-fragment exclusion classes.

### Boundary Register — deferrals

Each site below is a place where a structural fix cannot be made without taking a position on a
substantive question one of those records owns. **Each is DEFERRED, not decided.**

1. **`architecture/batch-admit-schema.md:308-311`** (record 274). The "second consumer"
   paragraph names `commands/research.md`'s, `commands/plan.md`'s and `commands/implement.md`'s
   "Step 2.5/Step 3.5 plain-multi-task two-pass structure" as the second consumer of
   `collision_scope == "in_batch"`. Those three files do not exist. Correcting the names requires
   first establishing what currently implements that consumer — a substantive claim about batch
   admission that 274 owns. **DEFER.** Leave the paragraph byte-for-byte unchanged.
2. **`architecture/handoff-schema.md:184-188`** (records 378, 428, 450). The `phase` field's
   definition reads "`"research"`: `/research` skill completed", and the same shape for `plan`
   and `implement`. Rewording what currently *produces* each phase value touches the same field
   three separate open records reason about. **DEFER.** Leave the three definition lines
   unchanged.
3. **`architecture/orchestrate-state-machine.md:948-955` and `:1393-1397`** (records 387, 420,
   450). Record-versioning prose ("MT mode used to fire exactly one commit...", "that batch
   commit is retired", "byte-for-byte unchanged from before this design existed") sits inside the
   MT-commit-granularity and batch-gate-deferral-invariance assertions. Restating it positively
   requires restating the assertion. **DEFER.**
4. **The record-versioning vocabulary class in the three boundary-owned architecture files**
   (~53 occurrences: `handoff-schema.md` ~20, `batch-admit-schema.md` ~15,
   `orchestrate-state-machine.md` ~18). **DEFER as a class** — see Scope Narrowing.
5. **`reference/standards/agent-frontmatter-standard.md:204,217`** mention `/research`, `/plan`
   and `/implement` as commands users invoke with model-override flags. **OUT OF SCOPE
   ENTIRELY** — the file is excluded from `file_scope` per the dispatch (431's audit verdict was
   duplicate-of-open against it). Recorded here only so the audit trail is complete.
6. **`reference/standards/multi-task-creation-standard.md:54`** (record 438) reads "would route
   to different research/plan/..." — a genuine phase-name reference with no leading slash.
   **Correct as written; no edit.** Named here because it is the only `/research|/plan|/implement`
   match in 438's file and a sweep must not touch it.

### Boundary Register — close calls, fixed narrowly

Each is a standalone, individually reviewed micro-edit, **never folded anonymously into a bulk
find/replace**:

- **A. `architecture/handoff-schema.md:876-881`** (records 378, 428, 450). A sample JSON's
  `files_modified` array lists `.claude/commands/research.md`, `.claude/commands/plan.md`,
  `.claude/commands/implement.md`. This is illustrative example data, not a schema assertion:
  swapping in three paths that exist changes nothing those records own. **FIX** (Phase 4).
- **B. `architecture/orchestrate-state-machine.md:239`** (records 387, 420). The "On cycle limit"
  message reads: ``Run `/orchestrate {N}` again to continue, or `/implement {N}` to resume
  manually.`` The fix changes only the named invocation surface, never the limit or budget
  semantics. **FIX NARROWLY, WITH A CONDITIONAL ABORT** (Phase 4): if implementation finds any
  script or skill emitting that sentence verbatim, the doc cannot be corrected in isolation —
  reclassify the site as a deferral and record it, rather than making the doc disagree with the
  engine.

### Boundary adjustment at planning time

The dispatch anticipated that this boundary would need adjustment. Two adjustments are made:

1. `architecture/orchestrate-state-machine.md` was not in the research report's dead-surface
   enumeration at all. It gains one close-call fix (B) and one deferral (3) above.
2. **Scope Narrowing on record-versioning prose.** The dispatch's CONSTRAINTS bind
   `rules/no-record-versioning-in-deliverables.md`, but the forbidden vocabulary occurs ~56 times
   across `core/docs/`, with ~53 inside the three boundary-owned architecture files — where
   remediation means restating the very assertions the boundary protects. Record-versioning
   remediation in this task is therefore narrowed to: (a) the three sites the research report
   names (`architecture/system-overview.md:9-10`, `guides/creating-commands.md:108-110`,
   `guides/creating-extensions.md:969-971`), and (b) any occurrence falling inside an edit hunk
   already being changed for another reason. Everything else is recorded in Phase 7's register
   and left for a follow-up record. A corpus-wide pass is a scope expansion this task declines,
   not an omission.

## Authority Decisions (one home per topic)

| Topic | Authority | Pointers reduced to |
|-------|-----------|---------------------|
| `/orchestrate` full flag/option semantics | `agent-system/extensions/core/commands/orchestrate.md`, "Options" section — cannot be a pointer; Claude Code loads it directly as the command's own instructions | `docs/guides/user-guide.md`'s duplicate Options table (Phase 5) |
| One-line command quick reference | `agent-system/extensions/core/merge-sources/claudemd.md`, "Command Reference" table — already minimal and already pointing into `orchestrate-state-machine.md` for forcing-flag/cycle-budget detail | no change needed |
| Comprehensive lifecycle walkthrough and troubleshooting | `docs/guides/user-guide.md` | no change (it is the authority for this topic) |
| Three-Layer Architecture explanation | `docs/architecture/system-overview.md` | `docs/guides/component-selection.md`'s architecture preamble (Phase 5) |
| Current core command inventory | `docs/architecture/system-overview.md`'s "Available commands" table, rebuilt from `agent-system/extensions/core/commands/*.md` (Phase 4) | — |
| What the extension picker is / how to use it | `agent-system/extensions/README.md` | the eight bare prose mentions in four files get a link added, not a rewritten explanation (Phase 6) |
| Documentation map / file inventory | `docs/docs-README.md` | — (gains the missing `fork-patterns.md` entry, Phase 6) |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A bulk find/replace of `/research`/`/plan`/`/implement` rewrites a correct phase-name or path-literal mention | H | H | Per-site read-and-classify before every edit; never a blind global substitution. Phase 1 produces the classified register; the acceptance grep re-classifies, it does not pattern-match |
| A global `../README.md` -> `../docs-README.md` replace breaks `docs-README.md`'s own three occurrences, which correctly resolve to `core/README.md` | H | H | Phase 2 enumerates the 13 breadcrumb occurrences in 7 named files explicitly and excludes `docs-README.md` by name; the link resolver re-run catches a regression |
| A structural fix drifts into deciding what one of the eight records owns | H | M | The Boundary Register above; close calls A and B are standalone reviewed micro-edits with B carrying a conditional abort |
| `lint-dead-command-recommendations.sh` passing is mistaken for corpus cleanliness | M | M | It already passes at baseline (0 violations, 33 candidates, 33 exempted) and only sees the `Next:`/`Run /X` shape. Treat it as a regression guard; the dead-surface acceptance criterion is a separate classified grep over tables and prose |
| The relative-link check is a bespoke script, not a standing tool | M | H | Phase 1 writes the resolver once into the scratchpad and every later phase re-runs that same file, so the final check is identical to the baseline check |
| Source-store `CLAUDE.md` links flagged as broken (13 hits) are "fixed" into something wrong | M | M | `CLAUDE.md` is generated at merge/deploy time; there is no source-store file to point at. The resolver excludes `CLAUDE.md` targets by name, as a documented exclusion class, and the exclusion is stated in Phase 7's acceptance note |
| Hand-patching a deployed file instead of redeploying | H | L | Phase 7 redeploys via `deploy-headless.sh` to `RESULT=landed_verify_clean` using the bounded-wait idiom; no `.claude/**` file is edited in any phase |
| Territory collision with task 328 Phase 19 | M | M | Advisory only, by design; no dependency edge either way |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |

The chain is fully serial because the phases share file territory: `user-guide.md` is touched in
Phases 2 and 5; `component-selection.md` in Phases 3 and 5; `system-overview.md` in Phases 2 and
4; `creating-extensions.md` in Phases 2, 3 and 6; `adding-domains.md` in Phases 2 and 6. Shared
territory is a reason to serialize within one task, not to parallelize.

---

### Phase 1: Re-derive the defect register and capture baselines [NOT STARTED]

**Goal**: Replace every approximate line number with a re-derived one, confirm or correct the
research report's per-site classification, and capture the two baseline measurements every later
phase compares against. No file under `agent-system/**` is modified in this phase.

**Tasks**:
- [ ] Confirm the edit target: read `.extensions.core.source_dir` from
      `/home/benjamin/.config/nvim/.claude-extensions.json` and verify it is
      `/home/benjamin/.config/nvim/agent-system/extensions/core`.
- [ ] Write a throwaway relative-link resolver to the scratchpad directory (walk every `*.md`
      under `agent-system/extensions/core/docs/`, resolve each `](path)` that is not
      `http`/`#`/`mailto:` against the containing file's own directory, report every target that
      does not exist). Exclude targets whose basename is `CLAUDE.md` as a documented class
      (merge-time-generated; no source-store file exists to point at). Record the baseline defect
      list and count.
- [ ] Run `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/core/docs/`
      and record the baseline verdict.
- [ ] Re-derive every line number in this plan's per-phase site lists by grep, and record the
      classified register to the scratchpad: for each raw `/research|/plan\b|/implement` match in
      `core/docs/` (excluding `reference/standards/agent-frontmatter-standard.md`), classify as
      `dead-surface` / `phase-name-correct` / `path-literal-correct` / `boundary-deferral`.
- [ ] Reconcile the register against this plan's Boundary Register. Any newly discovered site
      inside one of the eight records' files is added to the deferral list, never silently fixed.
- [ ] Record an issue-log entry for any register delta against the research report.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: This phase modifies no tracked file at all — its only outputs are
scratchpad working files — so the `prose` row's diff read-through over `git status --short`,
confirming zero changes under `agent-system/**`, is the complete covering check.

**Scope Hypothesis**: The research report's site enumeration is a hypothesis, not a fact: this
phase's classified grep over all raw matches is what confirms it. Three specific deltas are
already known and must be confirmed: (a) `guides/copy-claude-directory.md` has three
`](../commands/README.md)` occurrences, not two; (b) `architecture/orchestrate-state-machine.md`
contributes sites the report did not enumerate; (c) `docs-README.md`'s three `](../README.md)`
occurrences resolve correctly to `core/README.md` and are NOT defects. Confirm each by grep
before Phase 2 edits anything.

**Files to modify**: none (read-only derivation; outputs go to the scratchpad directory)

**Verification**:
- The resolver runs and prints a baseline defect list; the expected shape is ~21 genuine defects
  plus the excluded `CLAUDE.md` class.
- `lint-dead-command-recommendations.sh` baseline verdict recorded (expected: green).
- `git status --short` shows no change under `agent-system/**`.

---

### Phase 2: Mechanical relative-link repair [NOT STARTED]

**Goal**: Every broken relative link in the tree resolves, with the `CLAUDE.md` class the sole
documented exclusion.

**Tasks**:
- [ ] `](../README.md)` -> `](../docs-README.md)` at the 13 breadcrumb occurrences in exactly
      these 7 files: `architecture/extension-system.md` (2), `guides/creating-extensions.md` (2),
      `architecture/system-overview.md` (1), `guides/user-installation.md` (2),
      `guides/adding-domains.md` (2), `guides/user-guide.md` (2),
      `guides/copy-claude-directory.md` (2). **Do NOT touch `docs-README.md`'s own three
      occurrences** — from `core/docs/docs-README.md`, `../README.md` resolves to
      `core/README.md`, which exists. Likewise leave `architecture/system-overview.md`'s
      `](../../README.md)` alone; it is a different, correctly-resolving link.
- [ ] `](../commands/README.md)` -> `](../../commands/README.md)` at all occurrences in
      `guides/copy-claude-directory.md` (re-derive the count; expected 3).
- [ ] `guides/permission-configuration.md`: three deploy-root-style links
      (`](.claude/context/formats/frontmatter.md)`,
      `](.claude/context/orchestration/delegation.md)`,
      `](.claude/context/orchestration/state-management.md)`) -> `](../../context/...)` form.
- [ ] `guides/development/context-index-migration.md`: two links ->
      `](../../../context/patterns/context-discovery.md)` and
      `](../../reference/standards/agent-frontmatter-standard.md)`. This corrects a *referrer*,
      not the excluded target file.
- [ ] `guides/creating-skills.md`: the `@.claude/context/patterns/fork-patterns.md` reference ->
      the real file, `](../fork-patterns.md)` relative to `docs/guides/`.
- [ ] Re-run the Phase 1 resolver; confirm the defect list is empty apart from the `CLAUDE.md`
      exclusion class.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Every edit is a markdown link target within a single file's own text with
no executable surface, so the covering check is the Phase 1 resolver re-run plus
`bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
(the `__FULL_SWEEP__` source-store sub-case: no suite maps to these paths, and the TARGET must
name the source store explicitly or both gates silently SKIP).

**Scope Hypothesis**: The occurrence counts above (13 breadcrumbs / 3 `../commands/README.md` / 3
+ 2 deploy-root-style / 1 wrong target) are re-derived hypotheses. Confirm each by grep
immediately before editing, and confirm after editing that the grep for the old form returns only
the deliberately-excluded `docs-README.md` lines.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/extension-system.md` - breadcrumb link target
- `agent-system/extensions/core/docs/architecture/system-overview.md` - one breadcrumb-class link
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - breadcrumb link target
- `agent-system/extensions/core/docs/guides/user-installation.md` - breadcrumb link target
- `agent-system/extensions/core/docs/guides/adding-domains.md` - breadcrumb link target
- `agent-system/extensions/core/docs/guides/user-guide.md` - breadcrumb link target
- `agent-system/extensions/core/docs/guides/copy-claude-directory.md` - breadcrumb + commands-ref depth
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - three relative prefixes
- `agent-system/extensions/core/docs/guides/development/context-index-migration.md` - two relative prefixes
- `agent-system/extensions/core/docs/guides/creating-skills.md` - wrong fork-patterns target

**Verification**:
- Phase 1 resolver reports zero defects outside the `CLAUDE.md` exclusion class.
- `grep -rn '](\.\./README\.md)' agent-system/extensions/core/docs/` returns only
  `docs-README.md` lines.
- `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` green.

---

### Phase 3: Dead-command-surface correction in guides, templates and examples [NOT STARTED]

**Goal**: No file under `docs/guides/`, `docs/templates/` or `docs/examples/` presents
`/research`, `/plan` or `/implement` as a user-invocable command; every genuine phase-name
reference survives untouched.

**Tasks**:
- [ ] `guides/component-selection.md`: the Layer 1 ASCII-diagram example (`~:12`), the "Examples"
      table rows (`~:92-93`), and the "Pattern 2: New Language Support" entry point and
      "No command needed" note (`~:164`, `~:310`) — restate in terms of `/orchestrate`. The
      architecture-preamble trim is Phase 5's work, not this phase's.
- [ ] `guides/copy-claude-directory.md`: the "Task Management Commands" bullet (`~:13`) and the
      literal Quick Start block (`~:236-240`) — the Quick Start becomes `/orchestrate 1` for the
      plain lifecycle walk, or the explicit `--research`/`--plan`/`--implement` forcing form if
      the surrounding prose needs per-phase steps.
- [ ] `guides/creating-commands.md`: correct the "Model Selection" table row (`~:69`) that still
      names `/research`, `/plan`, `/implement` as dispatch commands, so it agrees with the
      already-correct statement ~40 lines later in the same file; and reword that later statement
      (`~:108-110`) from removal-narration ("were retired") to a positive current-state sentence.
      Also correct the "Example Commands to Study" table (`~:201-204`), which cites
      `.claude/commands/research.md` and `.claude/commands/implement.md` — neither exists; cite
      real command files instead.
- [ ] `guides/creating-extensions.md`: the generic research/implementation skill TEMPLATE text
      (`~:463`, `~:507`) whose invocation condition reads "Command is `/research`" / `/implement`
      — restate as dispatch by `/orchestrate` for that phase. The templates themselves stay:
      extension domain task types do still route through their own research/implementation
      skills. Also the "Test Routing" walkthrough (`~:668-671`), and the contrast case at
      `~:969-971` that cites the extinct single-task skills as an alternative.
- [ ] `guides/permission-configuration.md`: the "Test Commands" example (`~:703-704`).
- [ ] `templates/README.md`: the illustrative frontmatter example (`~:97-98`) using
      "# /research Command" as its sample name — replace with a neutral placeholder or a real
      command, so a dead surface is not modelled as a template.
- [ ] `examples/fix-it-flow-example.md`: the "Next Steps" step 3 (`~:411`) reading "Progress
      through /research -> /plan -> /implement cycle" — drop the leading slashes so it reads as
      phase names, consistent with preserving genuine phase-name references.
- [ ] Apply the record-versioning phrasing fix in the same edit at the two sites it rides on
      here (`creating-commands.md:~108-110`, `creating-extensions.md:~969-971`).
- [ ] Re-run the Phase 1 classified grep and the resolver.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: Every edit is prose, table, or fenced-example text inside a single
guide/template/example file with no executable surface, so the covering check is the Phase 1
classified grep plus
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` together
with `lint-dead-command-recommendations.sh` over `core/docs/`.

**Scope Hypothesis**: The nine site groups above are a hypothesis with approximate line numbers.
Confirm each by a read of the surrounding lines before editing, and classify each individually —
a site that turns out to be a correct phase-name or path-literal reference is left alone and the
register is corrected, never force-fitted to the list.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/component-selection.md` - dead-command examples and diagram
- `agent-system/extensions/core/docs/guides/copy-claude-directory.md` - command bullet + Quick Start block
- `agent-system/extensions/core/docs/guides/creating-commands.md` - Model Selection row, retirement wording, Example Commands table
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - skill-template invocation conditions, Test Routing, contrast case
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - Test Commands example
- `agent-system/extensions/core/docs/templates/README.md` - sample command name in frontmatter example
- `agent-system/extensions/core/docs/examples/fix-it-flow-example.md` - Next Steps step 3 phrasing

**Verification**:
- The classified grep over `docs/guides/`, `docs/templates/`, `docs/examples/` reports zero
  `dead-surface` rows.
- No `phase-name-correct` or `path-literal-correct` row from Phase 1's register changed.
- `lint-dead-command-recommendations.sh` green; resolver still clean.
- `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` green.

---

### Phase 4: Architecture-tree corrections and command-inventory rebuild [NOT STARTED]

**Goal**: `architecture/system-overview.md`'s command inventory is current; the two boundary
close-call sites are fixed narrowly and recorded; every boundary deferral is left byte-for-byte
unchanged.

**Tasks**:
- [ ] Rebuild `architecture/system-overview.md`'s "Available commands" table from the actual
      inventory (`ls agent-system/extensions/core/commands/*.md`, excluding `README.md`):
      `/task`, `/revise`, `/review`, `/project-overview`, `/todo`, `/errors`, `/meta`, `/fix-it`,
      `/zulip`, `/refresh`, `/tag`, `/orchestrate`, `/spawn`, `/merge`, `/please`. Re-derive the
      list at implementation time rather than trusting this enumeration. Drop the `/research`,
      `/plan`, `/implement` rows and add a one-line note that loaded extensions contribute
      further commands, pointing at the authority for those rather than listing them.
- [ ] Reword `architecture/system-overview.md:~9-10` from removal-narration ("the standalone
      `/research`, `/plan`, `/implement` commands ... have been deleted") to a positive
      current-state sentence naming `/orchestrate` as the sole lifecycle entry point that
      dispatches agents directly.
- [ ] **Close call A** — `architecture/handoff-schema.md:~876-881`: in the sample JSON's
      `files_modified` array, replace the three non-existent `.claude/commands/{research,plan,
      implement}.md` paths with three paths that exist. Illustrative data only; assert nothing new
      about the handoff contract. Record this as a reviewed micro-edit in the phase notes.
- [ ] **Close call B** — `architecture/orchestrate-state-machine.md:~239`: first grep the source
      store's `scripts/`, `skills/` and `commands/` trees for the sentence "to resume manually".
      **If any script or skill emits it verbatim, ABORT this edit**, reclassify the site as a
      deferral, and record why. Otherwise change only the named invocation surface
      (`/implement {N}` -> the `/orchestrate` forcing form), touching no word of the cycle-limit
      or budget semantics. Record as a reviewed micro-edit.
- [ ] **Confirm the deferrals are untouched**: `architecture/batch-admit-schema.md:~308-311`,
      `architecture/handoff-schema.md:~184-188`, and
      `architecture/orchestrate-state-machine.md:~948-955` / `~1393-1397` must appear in
      `git diff` only if they were not changed at all — i.e. verify each by diff inspection that
      no hunk overlaps them.
- [ ] Re-run the classified grep and the resolver.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: The edits are a markdown table, one prose sentence, and one JSON
example-literal inside three files with no executable surface, so the covering check is a
`git diff` read-through proving no hunk overlaps a Boundary-Register deferral, plus
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>`.

**Scope Hypothesis**: The current core command list above is a hypothesis derived from a
directory listing at planning time; re-derive it from `agent-system/extensions/core/commands/*.md`
at implementation time, since a command added or removed since planning would make the rebuilt
table wrong in exactly the way this task exists to fix. Close call B's safety also rests on a
hypothesis — that no script emits the cycle-limit sentence verbatim — which the first task in
that bullet tests before any edit.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/system-overview.md` - command inventory table, lifecycle sentence
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - `files_modified` sample paths only (close call A)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - cycle-limit message invocation surface only (close call B, conditional)

**Verification**:
- `git diff` confirms no hunk in `batch-admit-schema.md` at all, and no hunk in
  `handoff-schema.md` or `orchestrate-state-machine.md` overlapping a Boundary-Register deferral.
- The rebuilt command table matches the live `commands/*.md` inventory exactly.
- Classified grep reports zero `dead-surface` rows in `docs/architecture/` outside the deferrals.
- `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` green.

---

### Phase 5: Single-authority consolidation [NOT STARTED]

**Goal**: The two duplicated topics have exactly one authority each, with the duplicate sites
reduced to pointers.

**Tasks**:
- [ ] `guides/user-guide.md`'s `/orchestrate` Options table (`~:415-431`) is a near-verbatim
      restatement of `commands/orchestrate.md`'s Options table, and has already drifted (it omits
      `--allow-scope-collision`). Replace it with a short "most commonly used flags" subset — or
      drop the table entirely — plus a link to `../../commands/orchestrate.md`'s Options section
      as the authority for the full, current reference. Concise over exhaustive.
- [ ] `guides/component-selection.md`'s architecture-explanation preamble (`~:7-18`) and its
      second three-layer rendering (`~:239-244`) are reduced to a one-paragraph summary plus a
      link to `../architecture/system-overview.md`'s Three-Layer Architecture section. The file
      keeps its unique value — the "which component do I create" decision tree — intact.
- [ ] Verify no new duplication was introduced: the pointer text must not restate the
      authority's content, only name it.
- [ ] Re-run the resolver (both edits add links) and the classified grep.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: Both edits are prose and markdown-table changes inside two guide files
with no executable surface, so the covering check is the Phase 1 resolver re-run (the new
pointers are relative links that must resolve) plus
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>`.

**Scope Hypothesis**: The claim that `commands/orchestrate.md` is the only full-semantics
authority and that `merge-sources/claudemd.md` needs no change is a planning-time hypothesis
based on reading all three sites; re-read `merge-sources/claudemd.md`'s Command Reference table
at implementation time to confirm it is still minimal and still points into
`orchestrate-state-machine.md` before leaving it unchanged.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/user-guide.md` - Options table reduced to a pointer
- `agent-system/extensions/core/docs/guides/component-selection.md` - architecture preamble reduced to a pointer

**Verification**:
- `guides/user-guide.md` no longer restates the full flag set; a resolving link to
  `../../commands/orchestrate.md` is present.
- `guides/component-selection.md` retains its decision tree and carries a resolving link to
  `../architecture/system-overview.md`.
- Resolver clean; classified grep unchanged from Phase 4.

---

### Phase 6: Extension-picker links and documentation-map inventory [NOT STARTED]

**Goal**: Every bare "the extension picker" prose mention in the four named files carries a link
to the single authority, and `fork-patterns.md` is discoverable from the documentation hub.

**Tasks**:
- [ ] Add a link to `agent-system/extensions/README.md` at each bare picker mention, re-deriving
      each line number first. Relative depth by directory: from `docs/guides/*.md` and
      `docs/architecture/*.md` use `../../../README.md`; from `docs/reference/standards/*.md` use
      `../../../../README.md`. Sites: `guides/adding-domains.md` (`~:39`, `~:171-174`),
      `guides/creating-extensions.md` (`~:11`, `~:636`, `~:679`),
      `architecture/extension-system.md` (`~:33`, `~:547`),
      `reference/standards/extension-slim-standard.md` (`~:5`, `~:196`). Add a link, not a
      rewritten explanation — the authority keeps the explanation.
- [ ] Fix the incidental duplicated-word typo "the the extension picker" in
      `guides/adding-domains.md:~39` in the same edit.
- [ ] Leave `docs-README.md:~140` and `guides/user-guide.md:~769` alone: both already carry the
      Extension Catalog link in the same sentence, and neither is among the four named files.
- [ ] Add `fork-patterns.md` to `docs-README.md`'s "Documentation Map" tree and to its Guides /
      Related Documentation section, so the file is reachable from the hub as well as from the
      link Phase 2 corrected in `creating-skills.md`.
- [ ] Re-run the resolver to confirm all nine new/changed links resolve.

**Timing**: 0.75 hours

**Depends on**: 5

**Verification Tier**: local

**Tier Justification**: The edits add relative links and one tree entry across four guide,
architecture and reference files with no executable surface, so the covering check is the Phase 1
resolver re-run over every added link plus
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>`.

**Scope Hypothesis**: Both the eight picker-mention line numbers and the three relative-depth
forms are hypotheses — the dispatch's own numbers were explicitly approximate and were re-derived
once at planning time. Re-derive by `grep -rn 'extension picker'` and verify each computed
relative path resolves on disk (the resolver re-run is the confirmation) before closing the phase.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/adding-domains.md` - two picker links, "the the" typo
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - three picker links
- `agent-system/extensions/core/docs/architecture/extension-system.md` - two picker links
- `agent-system/extensions/core/docs/reference/standards/extension-slim-standard.md` - two picker links
- `agent-system/extensions/core/docs/docs-README.md` - `fork-patterns.md` added to map and related sections

**Verification**:
- `grep -rn 'extension picker' agent-system/extensions/core/docs/` shows a resolving link in
  every matched sentence of the four named files.
- `fork-patterns.md` appears in `docs-README.md`'s map tree and related list.
- Resolver clean.

---

### Phase 7: Full gate set, acceptance checks, and redeploy [NOT STARTED]

**Goal**: Every acceptance criterion in the dispatch is demonstrated green, the source store is
redeployed, and the deferral register is recorded in the summary.

**Tasks**:
- [ ] Run the Phase 1 relative-link resolver across the whole `core/docs/` tree; it must report
      zero defects outside the documented `CLAUDE.md` exclusion class. State the exclusion class
      and its justification explicitly in the summary rather than treating it as a silent pass.
- [ ] Run the classified dead-surface grep across all of `core/docs/` (excluding
      `reference/standards/agent-frontmatter-standard.md`) and confirm every remaining
      `/research|/plan|/implement` match classifies as `phase-name-correct`,
      `path-literal-correct`, or a named Boundary-Register deferral. Phase-name and dispatch-name
      references must be shown PRESERVED, not substituted — report the per-site classification,
      not a bare match count.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh agent-system/extensions/core/docs/`
      — green.
- [ ] Confirm the authority/pointer table at the head of this plan holds in the shipped tree:
      each topic's authority carries the content, each pointer carries only a link.
- [ ] Re-confirm by `git diff` that no substantive assertion owned by the eight records changed:
      no hunk in `batch-admit-schema.md` or
      `reference/standards/{agent-frontmatter-standard,multi-task-creation-standard}.md` at all,
      and in `handoff-schema.md` / `orchestrate-state-machine.md` only the two close-call
      micro-edits (A and B, B possibly aborted).
- [ ] Record the full deferral register — the six deferrals, the two close calls with their
      outcomes, and the record-versioning scope narrowing with its ~53 untouched occurrences — in
      the task summary, and recommend a follow-up record for each deferred class.
- [ ] Redeploy via `deploy-headless.sh`, using the bounded-wait idiom (`timeout 540`, Bash tool
      timeout raised to 600000), to `RESULT=landed_verify_clean`. Never hand-patch a deployed
      file in place of a redeploy. Read `context/patterns/bounded-build-waiter.md` before
      backgrounding anything.
- [ ] Run the complete gate set:
      `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim/agent-system/extensions/core`
      — clean.

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the counts it reports on — six deferrals, two close
calls, and ~53 untouched record-versioning occurrences in the three boundary-owned architecture
files. Re-derive each from the final diff and a fresh grep before writing them into the summary;
report the derived figures, not these.

**Files to modify**: none (verification and redeploy only; the redeploy regenerates `.claude/**`)

**Verification**:
- The complete gate set via
  `bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim/agent-system/extensions/core`
  passes, with no `--skip-slow`, no `--only-gate` narrowing, and no suite subset — all 23 gates,
  including Gate 8's full shell-suite battery.
- `deploy-headless.sh` reached `RESULT=landed_verify_clean`.
- `lint-dead-command-recommendations.sh` green over `core/docs/`.
- Relative-link resolver reports zero defects outside the stated `CLAUDE.md` exclusion class.
- The classified dead-surface grep's per-site report shows every surviving match as a preserved
  phase name, a path literal, or a named deferral.

---

## Testing & Validation

- [ ] Relative-link resolver clean across all 29 files in `core/docs/`, `CLAUDE.md` exclusion
      class stated and justified.
- [ ] Classified dead-surface grep: zero `dead-surface` rows outside the Boundary Register.
- [ ] Every `phase-name-correct` and `path-literal-correct` site from Phase 1's register is
      byte-for-byte unchanged in the final diff.
- [ ] `lint-dead-command-recommendations.sh` green.
- [ ] `verify-deploy.sh` clean over the source store (full gate set, no narrowing).
- [ ] `deploy-headless.sh` reached `RESULT=landed_verify_clean`.
- [ ] No hunk anywhere under `.claude/**` authored by hand.
- [ ] No task-number citation and no record-versioning phrasing introduced in anything landing
      under `agent-system/**`.

## Artifacts & Outputs

- Corrected markdown across up to 18 files under `agent-system/extensions/core/docs/`.
- A regenerated `.claude/` deploy tree (produced by `deploy-headless.sh`, not hand-authored).
- A task summary carrying the authority/pointer table and the full deferral register.
- Scratchpad-only working outputs: the throwaway relative-link resolver and the classified
  dead-surface register (deliberately not repo deliverables; a standing link lint is a
  recommended follow-up, out of scope here).

## Rollback/Contingency

- All work is markdown text in the source store with no schema or behavioral surface, so any
  phase can be reverted by `git checkout` of the named files from the phase's parent commit; the
  per-phase commits make the granularity one phase.
- Before any phase whose edit set feels larger than its hypothesis predicted, take a defensive
  checkpoint with `bash .claude/scripts/git-snapshot.sh 468 --no-revert` (durable, does not
  revert the working tree). The default reverting form belongs only to a genuine rollback.
- If close call B's pre-edit grep finds a script emitting the cycle-limit sentence verbatim, do
  not edit the doc: reclassify as a deferral, record it, and continue — the phase still closes.
- If the full gate set fails in Phase 7 on something this task did not touch, record it and
  report rather than widening scope to fix it; if it fails on something this task did touch, fix
  forward in the source store and redeploy, never by hand-patching `.claude/**` and never by
  discarding uncommitted work.
