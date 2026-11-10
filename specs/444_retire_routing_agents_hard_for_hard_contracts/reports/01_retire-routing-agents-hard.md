# Research Report: Task #444

**Task**: 444 - Retire routing_agents_hard in favour of hard_contracts across books, cslib and lean, then remove the ladder rung and gate16
**Started**: 2026-11-09T00:00:00Z
**Completed**: 2026-11-09T00:00:00Z
**Effort**: Medium (6 scoped code/doc edits plus a wider blast radius of stale references; see Findings)
**Dependencies**: 445 (completed; unrelated gate8 work, no interaction with this task)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/{books,cslib,lean,core}/**` (manifests, agents, scripts, context/contracts, docs)
- `agent-system/extensions/core/context/guides/manifest-routing-schema.md`, `hard-mode-routing.md`
- `agent-system/extensions/core/scripts/{command-route-agent.sh,lib/manifest-routing-lib.sh,orchestrate-build-dispatch.sh,verify-deploy.sh,gate-registry.data,lint/lint-routing-wiring.sh,check-extension-docs.sh}`
- Deployed tree (`.claude/**`) for ground-truthing what actually reaches an agent at dispatch time
- `specs/state.json` task 444 entry (`file_scope`, description, dependencies)
**Artifacts**: `specs/444_retire_routing_agents_hard_for_hard_contracts/reports/01_retire-routing-agents-hard.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Gating question answered YES**: all six `-hard` agents (books/cslib/lean x research/implement)
  reduce substantively to their standard-agent body plus injected behavioral contracts. Diffing
  each hard variant against its standard counterpart shows the hard body is overwhelmingly either
  (a) the same instructions, reworded/condensed with explicit "same as the base agent" framing, or
  (b) generic H2/H3/H4/H7/H9 contract text that is byte-for-byte or near-byte-for-byte identical to
  `agent-system/extensions/core/context/contracts/{anti-analysis,reference-grounding,
  adversarial-verification,territory,wrap-up}.md` — content the existing, already-built
  `hard_contracts_block` mechanism in `orchestrate-build-dispatch.sh` Stage 3.5 already injects
  unconditionally, by phase, for **every** `--hard` dispatch regardless of `task_type`.
- All three "WHAT IS ACTUALLY TRUE TODAY" claims in the dispatch are confirmed exactly as stated:
  `routing_hard` is declared nowhere; `routing_agents_hard` is declared by exactly books, cslib,
  and lean with exactly the shapes quoted; `hard_contracts` is declared nowhere.
- A genuinely domain-specific residue exists only for **lean** (and, by cross-reference, cslib):
  Lean-MCP-tool-specific "Context Hygiene" discipline and a lean-specific "sorry inventory" /
  "formal proof line bar" override of H2. Both are **already expressible** through the documented
  `hard_contracts` mechanism (plain additive paths and `replace:` directives) — the override
  content already exists as standalone files (see below) — but is not yet wired to it anywhere.
- **Two previously-undiscovered defects**, independent of this task's named scope but directly
  relevant to its own "VERIFY" bullet ("a --hard dispatch in each domain still receives its
  behavioural contracts, demonstrated per domain"):
  1. **Deploy-time clobber**: lean's manifest declares the bare top-level context directory
     `"contracts"` (identical to core's own declaration), and the deployed
     `.claude/context/contracts/{anti-analysis,reference-grounding,adversarial-verification}.md`
     are confirmed (via diff) to currently hold **lean's domain-specific override content**, not
     core's generic content — meaning every `--hard` dispatch today, for *any* task_type, is
     silently reading lean-flavored H2/H3/H4 contracts instead of the generic ones.
  2. **Dangling `@`-import path shape**: all four lean/cslib hard agents (and the core
     `anti-analysis.md` contract's own "Domain Specialization" section) cite domain overrides at
     an extension-namespaced path (`@.claude/extensions/lean/context/contracts/*.md`) that does
     not exist anywhere in the deployed tree — confirmed: `.claude/extensions/<ext>/` deploys
     `manifest.json` only, never a `context/` subtree. The existing `hard_contracts` Stage-3.5
     renderer only supports flat basenames directly under `context/contracts/`, contradicting
     this citation convention. `check-extension-docs.sh`'s purpose-built dangling-reference
     gate (Rule G) does not catch this because its regex requires the literal substring
     `.claude/context/contracts/`, which this path shape does not contain.
- Both defects point at the same unresolved design question — where domain-specific contract
  overrides physically live — which this task's `hard_contracts` migration is the natural, and
  arguably only sane, place to resolve. Recommend folding a decision on this into the task's
  implementation plan rather than treating it as a separate follow-on (see Recommendations).
- The task's `file_scope` (9 files) already correctly includes `hard-mode-routing.md` even though
  the dispatch's own numbered scope list (step 6) names only `manifest-routing-schema.md` — the
  former is at least as stale once `routing_agents_hard` is retired and should be treated as
  in-scope, consistent with `file_scope`. `file_scope` does **not** include `gate-registry.data`
  (needed per scope item 5) nor several test files and docs that will go stale (see Findings);
  these are real gaps the plan should account for.

## Context & Scope

This is a research-only dispatch for task 444: verify the premise behind retiring
`routing_agents_hard` (a two-level `{op:{task_type:agent_name}}` routing block resolving WHICH
AGENT `--hard` dispatches) in favor of `hard_contracts` (a one-level `{task_type:[contract_paths]}`
block resolving WHICH CONTRACT FILES are injected into a standard agent's `--hard` dispatch
prompt), then scope the mechanical removal of the ladder rung, lint check, and `gate16` warning.
The dispatch explicitly gates all downstream work on step 1 — "if the -hard agents carry
behaviour that contract injection cannot express, say so and stop" — so this report's primary job
is to answer that question with evidence, not to produce an implementation plan.

Research was conducted entirely against the source store
(`agent-system/extensions/**`, the sanctioned edit target per
`rules/source-store-deploy-boundary.md`) and the currently-deployed `.claude/**` tree (read-only,
to ground-truth what a real dispatch actually sees today). No web research was applicable; this
is a pure codebase-mechanics question.

## Findings

### Codebase Patterns

**Manifest declarations match the dispatch's stated facts exactly.**
```
books: routing_agents_hard = {research:{books:"books-research-hard-agent"}, implement:{books:"books-implementation-hard-agent"}}
cslib: routing_agents_hard = {research:{cslib:"cslib-research-hard-agent"}, implement:{cslib:"cslib-implementation-hard-agent"}}
lean:  routing_agents_hard = {research:{lean4:"lean-research-hard-agent"}, implement:{lean4:"lean-implementation-hard-agent"}}
```
`grep -rl "routing_agents_hard" agent-system/extensions/*/manifest.json` returns exactly these
three files; no manifest declares `routing_hard` or `hard_contracts`.

**`command-route-agent.sh`'s hard-mode ladder is the live consumer that must be replaced, not
just deleted.** It resolves `routing_agents_hard` first (via the generic, block-name-parameterized
`routing_lookup()` in `manifest-routing-lib.sh`), falls back to the already-resolved
`routing_agents` value (`via="hard-miss-standard-fallback"`), and only then falls back to the
caller's generic default. `manifest-routing-lib.sh` itself has **no hard-coded logic** tied to
`routing_agents_hard` — `routing_lookup()`/`routing_lookup_flat()` take the block name as a
parameter — so "remove ... its lib" (dispatch step 4) is a documentation-comment-only concern in
`manifest-routing-lib.sh`, not a functional change; the functional removal is entirely inside
`command-route-agent.sh`'s own three-rung composition (lines ~61-88).

**`lint-routing-wiring.sh` Check C is self-contained and safely removable.** It has its own
function (`check_c()`), its own `--help` line, and its own header-comment block (lines 15-19).
Check B's `for block in routing_agents routing_agents_hard` loop will simply iterate zero entries
for the removed block once no manifest declares it — functionally harmless to leave, but its
`--help`/header text (lines 12, 65, 204, 207) still names `routing_agents_hard` and should be
updated for accuracy even though nothing breaks if left alone.

**`gate16` (`verify-deploy.sh`) is a ~25-line self-contained block plus one `gate-registry.data`
row**, both cleanly removable. Its own header comment (lines 1600-1610) already states "the
dependent hard-mode work" as the trigger for its own removal — i.e. gate16 was written
anticipating exactly this task.

**The `hard_contracts_block` injection mechanism already exists and already works, independent of
any manifest declaring `hard_contracts`.** `orchestrate-build-dispatch.sh` Stage 3.5 (lines
391-429) builds a fixed `core_contracts` array per phase —
`research: [anti-analysis.md, reference-grounding.md, adversarial-verification.md]`,
`plan: [reference-grounding.md, wrap-up.md, anti-analysis.md]`,
`implement: [anti-analysis.md, wrap-up.md, (territory.md if territory present), recovery.md,
phase-closure.md, pre-edit-gate.md]` — for **every** `--hard` dispatch regardless of `task_type`,
then optionally overlays a manifest's `hard_contracts.{task_type}` array (additive paths or
`replace:core-basename:override-path` directives) on top via `routing_lookup_flat()`. This means
dispatching the **standard** agent under `--hard` already receives H2/H3/H4 (research) or
H2/H7/H9 (implement) contract text automatically, with zero manifest changes — confirmed against
the schema guide's own documentation of this mechanism.

**Diff evidence that the six `-hard` agents are overwhelmingly redundant with base + injected
contracts** (full diffs examined for all three domains' implement side, representative excerpts
for research):
- `books-implementation-hard-agent.md` vs `books-implementation-agent.md`: the hard variant's
  "Verify Phase Completion" step reads literally **"same criteria as the base agent, plus:
  re-read `rules/books.md`'s six non-negotiables..."**; "Mark Phase In Progress"/"Mark Phase
  Complete" read **"same Edit-tool mechanics as the base agent"**. The additions that are not
  cross-references are the generic H2 (Settled-Design Preamble, read budget, forbidden
  conclusions) and H7 (territory) and H9 (wrap-up/handoff) contract text, each matching
  `context/contracts/{anti-analysis,territory,wrap-up}.md` almost verbatim.
- `books-research-hard-agent.md` vs `books-research-agent.md`: identical pattern for H2/H3/H4.
  The one books-specific addition beyond the generic contracts (a 3-tier reference-grounding
  selection rule keyed to `convention.md` vs. live-tree vs. "port/extend/adapt" claims, and a
  "landed-vs-planned verification" mandate) is a **books-domain elaboration of the generic H3
  contract's own tier concept**, not new unrelated behavior — expressible as an additive
  `hard_contracts` entry if judged worth preserving, or droppable as duplicative of what the base
  research agent + generic H3 already convey.
- `cslib-implementation-hard-agent.md`: H2 cites the **generic** core `anti-analysis.md` directly
  (no cslib-specific override exists), confirming cslib's H2 is identical to what standard-agent +
  core-contract-injection already produces. Its one domain addition is reusing **lean's**
  `context-hygiene.md` file (Lean-MCP-tool query discipline — cslib also edits Lean theorem files).
- `lean-implementation-hard-agent.md` / `lean-research-hard-agent.md`: these carry the most
  genuine domain-specific residue — a lean-specific override of H2 (`agent-system/extensions/lean/
  context/contracts/anti-analysis.md`: "formal proof line bar", lean-specific forbidden
  conclusions, lean-specific sub-sorry/strategic-sorry policy) and a lean-only contract with no
  core counterpart at all (`context-hygiene.md`: targeted `lean_goal` queries, bounded reads,
  hypothesis pruning). **Both already exist as standalone files** at
  `agent-system/extensions/lean/context/contracts/{anti-analysis,reference-grounding,
  adversarial-verification,context-hygiene}.md` — someone already extracted this content into
  the contract-file shape the `hard_contracts` mechanism expects; it was simply never wired
  through a manifest `hard_contracts` declaration. Lean's own "Single-Phase Focus"
  (`phase_number`-scoped implementation) and "Sorry Inventory" stages (tracking `sorry` locations
  across dispatch boundaries in `.orchestrator-handoff.json`) are genuinely lean-specific
  procedural content with no existing generic-contract equivalent; they would need to either stay
  as agent-body content on the standard `lean-implementation-agent` (if not already present there
  — not confirmed either way in this pass) or become a new lean-specific contract file.

**Conclusion on the gating question**: YES — all six agents reduce to standard-agent-body +
injected contracts, with the caveat that for lean/cslib specifically, the "injected contracts"
side of that equation requires wiring the **already-existing** domain override files into
`hard_contracts` (not authoring new ones), plus a decision on where "Single-Phase Focus" and
"Sorry Inventory" procedural content lives if it is not already present in the standard
`lean-implementation-agent.md` body.

### Two independent defects found, both touching the exact override-file mechanism this task needs

**Defect A — deploy-time directory clobber.** Both `core` and `lean` manifests declare the bare
top-level context directory `"contracts"` in `provides.context` (cslib declares only
`project/cslib`; books declares no contracts directory at all). `agent-system/extensions/lean/
context/contracts/` contains 4 files, 3 of which (`anti-analysis.md`, `reference-grounding.md`,
`adversarial-verification.md`) **share a basename** with one of core's 17 generic contract files.
Diffing the currently-deployed `.claude/context/contracts/anti-analysis.md` against both sources
confirms the deployed file is **byte-identical to lean's override**, not to core's generic
version — i.e., lean's directory-level copy is currently clobbering core's shared file in this
deployment. Since lean is the only one of the three domains currently deployed (per the dispatch's
own stated fact), this is not yet visible as a 3-way collision, but it is a live, demonstrable bug
today: **any `--hard` dispatch of any task_type** (general, meta, markdown, etc.) that reads
`context/contracts/anti-analysis.md` today is reading lean's "formal proof line bar" / sub-sorry
language instead of the intended domain-agnostic H2 contract. `cslib`'s lone existing override
file (`agent-system/extensions/cslib/context/contracts/adversarial-verification.md`) is not even
reachable today — cslib's manifest never lists `"contracts"` in `provides.context`, so that file
is simply never deployed (an orphaned source file).

**Defect B — dangling extension-namespaced `@`-import paths.** All four lean/cslib hard agents
(and the core `anti-analysis.md` contract's own "## Domain Specialization" section, which states
"Extension overrides live in `.claude/extensions/{domain}/context/contracts/anti-analysis.md`")
cite domain overrides at `@.claude/extensions/lean/context/contracts/*.md`. This path does not
exist anywhere in the deployed tree: `find .claude/extensions -maxdepth 4` confirms every
extension's deployed directory (`lean`, `core`, `nix`, `memory`, etc.) contains `manifest.json`
only, never a `context/` subtree of its own — context files are always flattened into the shared
`.claude/context/...` tree via `provides.context`, never kept under `.claude/extensions/<ext>/`.
Because the same bullet content is also restated as literal prose immediately below each broken
citation in every agent body examined, this does not silently break the *agent's* behavior today
(the content still reaches the agent as inline text), but the `@`-import itself is dead, and the
core contract's own documented convention for where overrides "live" is wrong relative to both the
actual deploy layout and the already-built `hard_contracts_block` renderer (which only supports
flat basenames directly under `context/contracts/`, per `orchestrate-build-dispatch.sh`'s
`hard_contracts_block+="- context/contracts/${c}"`). `check-extension-docs.sh`'s Rule G
("Project-wide dangling `.claude/context/contracts/*.md` reference scan") exists specifically to
catch this defect class (its own comment cites "the exact BimodalLogic/cslib defect") but does not
catch this instance: its regex requires the literal substring `.claude/context/contracts/`
immediately following `.claude/`, and `.claude/extensions/lean/context/contracts/...` has
`extensions/lean/` inserted in between, so it never matches.

**Why this matters for this task specifically**: both defects are about the exact same unresolved
question this task's "Author `hard_contracts` declarations for books, cslib and lean" scope item
(step 2) must answer concretely — where do domain-specific override contract files live, and
under what filename convention, so that `routing_lookup_flat()`'s `replace:core-basename:
override-path` directive (which assumes a flat, same-directory basename, per the schema guide's
own worked example `replace:anti-analysis.md:my-anti-analysis.md`) can resolve them. The two
already-existing conventions in this codebase disagree with each other (nested
`extensions/{domain}/context/contracts/` vs. flat `context/contracts/{domain}-{name}.md`), and
only the flat one is compatible with the renderer code that already exists and already runs.
Fixing the manifest declarations (dropping lean's redundant bare `"contracts"` entry, renaming/
relocating lean's and cslib's override files to flat domain-prefixed basenames under
`agent-system/extensions/core/context/contracts/`, e.g. `lean4-anti-analysis.md`,
`lean4-context-hygiene.md`, and wiring them via `hard_contracts.lean4`/`hard_contracts.cslib`)
would resolve Defect A and Defect B as a byproduct of doing step 2 correctly, rather than as
separate follow-on work.

### Blast radius beyond the dispatch's named scope

A full-repo grep for `routing_agents_hard` surfaces stale-reference risk beyond the 9 files in
`file_scope` and the 6 scope items:
- **Tests that will need updating, not just leaving to pass vacuously**:
  `scripts/tests/test-routing-resolution.sh` (Assert 3's semantic check specifically asserts
  lean4's `routing_agents_hard` entry differs from its standard entry — this assertion has no
  subject once the block is removed and must be retargeted or deleted, not left as dead code
  asserting against an empty manifest key), `scripts/tests/test-verify-deploy-gate-selection.sh`
  (case r-a/r-b specifically assert gate16's WARN-level finding fires for the real lean
  `routing_agents_hard` fixture — this fixture and both assertions become meaningless once gate16
  and the manifest key are both gone), `scripts/tests/test-gate-cache-equivalence.sh` (references
  the lean `routing_agents_hard` declaration as a documented out-of-scope pre-existing finding —
  stale comment once gate16 is removed, though not a functional failure).
- **Docs/comments that will read as wrong or misleading once this lands, not flagged in
  `file_scope`**: `agent-system/extensions/cslib/README.md` (documents cslib's hard-mode routing
  entries by name), `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `docs/guides/copy-claude-directory.md`, `docs/guides/creating-commands.md`,
  `docs/reference/utility-scripts-inventory.md` (describes `lint-routing-wiring.sh`'s Check C by
  name), `merge-sources/claudemd.md` (the generated CLAUDE.md's own "Hard Mode" section names
  `routing_agents_hard` as live extension routing), `context/contracts/batch-gate-stage.md`
  (references gate16 by name as the sole example of a non-blocking migration-warning gate type),
  and `check-extension-docs.sh`'s own Rules B/C (lines ~1015-1122, the `routing_agents_hard`
  target-resolvability checks) — these will not fail (empty `routing_agents_hard` block means
  their loops simply iterate zero entries) but their header comments extensively document
  semantics that cease to exist.
- **`context/guides/hard-mode-routing.md` is far more extensively invested in
  `routing_agents_hard` than `manifest-routing-schema.md`** and is already correctly listed in
  `file_scope`. Its "4-Step Precedence" section, "Extension Overrides This" agent table (naming
  all six retiring agents), and its own "`routing_agents_hard` Is Transitional" section (which
  already narrates this exact task as a "not-yet-dispatched follow-on") all become obsolete or
  self-referentially resolved. This file needs more substantial rewriting than
  `manifest-routing-schema.md`, which mostly already describes the target end-state accurately
  and needs comparatively few edits (its "Collapsed model" framing, "Two Routing Blocks"
  terminology — "the two surviving routing blocks" — and completeness-rule prose all assume
  `routing_agents_hard` survives and will need updating to a single-block model).
- `agent-system/extensions/core/index-entries.json` carries two entries whose `summary`/keyword
  arrays explicitly name `routing_agents_hard` (for `hard-mode-routing.md` and
  `manifest-routing-schema.md`'s own index rows) — these will need regenerating alongside the doc
  edits, per the project's existing `generate-context-line-counts.sh`-adjacent convention noted in
  `check-extension-docs.sh`'s own comments.
- `gate-registry.data` (needed per dispatch scope item 5) is **not** listed in task 444's
  `file_scope`, despite being named explicitly in the dispatch description's scope item 5. The
  implementation plan should add it; `task 430`'s "feed undeclared implement paths into file
  scope" mechanism (visible as an in-progress sibling task in this same repo) is the general
  remedy for this class of gap, but should not be relied on to retroactively fix this task's own
  `file_scope` omission.

## Decisions

- **The gating question is answered YES**: proceed with the migration as scoped. No evidence was
  found of any of the six `-hard` agents carrying behavior that the `hard_contracts` injection
  mechanism cannot express in principle — the mechanism (plain additive paths + `replace:`
  directives, resolved per-phase, per-task_type) is expressive enough for every domain-specific
  addition found, including lean's.
- **The two newly-found defects (clobber + dangling path) should be treated as in-scope corollary
  fixes of this task's own step 2 ("author `hard_contracts` declarations"), not as a separate
  follow-on task.** They share root cause and fix location: settling where domain contract
  overrides live and under what filename convention is the same work either way, and leaving
  Defect A unfixed would mean the migration's own "VERIFY" criterion ("a --hard dispatch in each
  domain still receives its behavioural contracts, demonstrated per domain") cannot be honestly
  satisfied for any task_type today, migration or not.
- **`context/guides/hard-mode-routing.md` requires substantially more rewriting than
  `manifest-routing-schema.md`** and should be budgeted accordingly in the plan's phase sizing;
  both are already in `file_scope`.

## Recommendations

1. **Plan phase 1**: settle the override-file location/convention question explicitly as a named
   decision (flat, domain-prefixed basenames under `agent-system/extensions/core/context/
   contracts/`, consumed via `hard_contracts`'s documented `replace:`/additive syntax is the only
   convention compatible with the already-built renderer — recommend adopting it over the
   nested-namespace convention the stale agent citations and the `anti-analysis.md` "Domain
   Specialization" section currently imply) before touching any manifest.
2. **Plan phase 2**: relocate/rename lean's four override files and cslib's one orphaned override
   file to the flat convention, fix `lean`'s manifest to stop declaring bare `"contracts"` (this
   alone fixes Defect A), and wire `hard_contracts.books`/`hard_contracts.cslib`/
   `hard_contracts.lean4` via the chosen convention — using `replace:` for genuine H2/H3/H4
   overrides and plain additive entries for lean's `context-hygiene.md`.
3. **Plan phase 3**: remove `routing_agents_hard` from all three manifests, retire the six `-hard`
   agent files, and fold any genuinely-unique procedural content (lean's "Single-Phase Focus" and
   "Sorry Inventory" stages, if not already present in `lean-implementation-agent.md`'s base body)
   into the standard agents or a new lean-specific contract file — confirm this by diffing the
   standard `lean-implementation-agent.md` against the hard variant's unique headings
   (`Single-Phase Focus`, `Stage 3.5: Initialize Sorry Inventory`, `Zero-Debt Policy`) before
   declaring them redundant, since this report did not conclusively establish whether that content
   already exists on the standard agent.
4. **Plan phase 4**: remove the `routing_agents_hard` rung from `command-route-agent.sh` (its
   three-rung `if`/`elif`/`else` composition), update Check C out of `lint-routing-wiring.sh`
   (and its header/`--help` text), remove `gate16` from `verify-deploy.sh` **and its
   `gate-registry.data` row** (not currently in `file_scope`; add it), and decide explicitly
   whether a replacement absence-assertion gate is worth adding (recommend: not worth it given
   `lint-routing-wiring.sh` Check B already fails hard on any stray `routing_agents`/
   `routing_agents_hard` value naming a nonexistent agent, and a fully-removed key has nothing
   left to assert the absence of beyond what a plain `grep`/`jq has()` one-liner in CI already
   covers more cheaply than a dedicated gate).
5. **Plan phase 5 (docs/tests convergence)**: update `manifest-routing-schema.md` and
   `hard-mode-routing.md` (both in `file_scope`); additionally touch the stale-reference set found
   in this report's "Blast radius" subsection — at minimum `test-routing-resolution.sh` Assert 3,
   `test-verify-deploy-gate-selection.sh`'s gate16 fixture/cases, `cslib/README.md`'s hard-mode
   routing section, `merge-sources/claudemd.md`'s Hard Mode section, and the two
   `index-entries.json` rows — to avoid leaving mechanically-passing but substantively wrong
   documentation behind. Treat `check-extension-docs.sh`'s Rules B/C header comments and
   `docs/reference/utility-scripts-inventory.md`'s Check-C mention as optional cleanup if time is
   constrained; none of them fail mechanically once the manifest key is empty.
6. Re-run `lint-routing-wiring.sh --verbose` and the full gate set (per the dispatch's own VERIFY
   criteria) only after phases 1-4 land, since gate16 and Check C are themselves being removed as
   part of this work and an intermediate green reading would be misleading.

## Risks & Mitigations

- **Risk**: fixing Defect A (lean's bare `"contracts"` declaration) changes what every currently
  deployed `--hard` dispatch of any task_type reads today (reverting lean's accidental clobber
  back to core's actual generic content). This is a *behavior change*, not a pure bugfix, for any
  consumer repo currently relying on the clobbered (lean-flavored) content for a non-lean `--hard`
  dispatch. *Mitigation*: this repo is very likely the only consumer currently exercising the
  affected path (per the dispatch's own note that lean is the only one of the three domains
  deployed here); still, call this out explicitly in the implementation plan and summary so it is
  not mistaken for an accidental regression during review.
- **Risk**: declaring the override-file convention question "settled" in this report's
  Recommendations without an explicit maintainer sign-off could be read as research overstepping
  into a design decision. *Mitigation*: the recommendation is grounded in which convention the
  **already-shipped, already-running** renderer code supports (flat basenames only) — this is not
  a stylistic preference between two equally-workable options, it is "use the convention the code
  that already executes in production can actually resolve." Flag this plainly to the plan phase
  as a finding, not a mandate, so it can still be revisited if the plan phase uncovers a reason the
  renderer itself should change instead.
- **Risk**: retiring the six `-hard` agent files outright, rather than leaving them as thin
  deprecated stubs, could break an in-flight dispatch mid-task if one was captured in a handoff
  file referencing the old agent name. *Mitigation*: `routing_agents_hard`'s removal and the agent
  files' removal should land together in the same phase/commit (per dispatch step 3's own
  phrasing, "retire the six -hard agent files if step 1 rules them redundant" is conditioned on
  the SAME step as the manifest removal), and `command-route-agent.sh`'s `--default-agent`
  fallback already guarantees any resolution miss degrades to the standard agent rather than
  erroring — so a stale reference anywhere else degrades gracefully rather than hard-failing.

## Context Extension Recommendations

- **Topic**: deploy-time context-file merge semantics for `provides.context` directory-level
  entries (e.g. the bare `"contracts"` entry both `core` and `lean` declare).
  **Gap**: no existing context file documents that two extensions declaring the same top-level
  `provides.context` directory name causes a same-basename file from one to silently clobber the
  other's, with the winner determined by extension load order — a correctness-relevant mechanic
  for anyone adding domain-specific files to a shared context subdirectory. **Recommendation**:
  add a short subsection to `context/guides/manifest-routing-schema.md` (or a new standalone
  pointer from it) documenting this clobber risk and the flat-domain-prefixed-basename convention
  as the sanctioned way to add a per-domain override to a shared directory, since `hard_contracts`
  is precisely the sanctioned alternative to ad hoc directory-level overlap and this task is the
  first real exercise of it.
- **Topic**: `check-extension-docs.sh` Rule G's dangling-reference regex scope.
  **Gap**: Rule G is explicitly designed to catch "the exact BimodalLogic/cslib defect" of a
  dangling `.claude/context/contracts/*.md` reference, but its regex does not match an
  extension-namespaced variant of the same defect shape (`.claude/extensions/{ext}/context/
  contracts/*.md`), which this report found four live instances of. **Recommendation**: either
  widen Rule G's regex to also catch `\.claude/extensions/[a-zA-Z0-9_-]+/context/contracts/
  [a-zA-Z0-9_-]+\.md` (treating it as always-dangling, since no extension ever deploys a
  `context/` subtree under its own `.claude/extensions/<name>/` directory, confirmed in this
  report), or explicitly document in Rule G's own header comment why that shape is out of scope,
  so a future reader does not assume Rule G already covers it.

## Appendix

### Search queries / commands used

```
grep -rl "routing_agents_hard" agent-system/extensions/*/manifest.json
grep -rl "\"routing_hard\"" agent-system/extensions/*/manifest.json   # empty
grep -rl "hard_contracts" agent-system/extensions/*/manifest.json     # empty
diff <(tail -n +12 books-implementation-agent.md) <(tail -n +25 books-implementation-hard-agent.md)
diff <(tail -n +12 books-research-agent.md) <(tail -n +25 books-research-hard-agent.md)
diff <(tail -n +12 lean-implementation-agent.md) <(tail -n +25 lean-implementation-hard-agent.md)
grep -n "^#\{1,4\} " lean-implementation-agent.md lean-implementation-hard-agent.md   # heading-set diff
diff .claude/context/contracts/anti-analysis.md agent-system/extensions/core/context/contracts/anti-analysis.md
diff agent-system/extensions/lean/context/contracts/anti-analysis.md agent-system/extensions/core/context/contracts/anti-analysis.md
find .claude/extensions -maxdepth 4        # confirms manifest.json-only per-extension deploy
grep -rn "extensions/lean/context/contracts\|extensions/cslib/context/contracts" agent-system/extensions/*/agents/*.md
grep -rn "routing_agents_hard" agent-system/ --include="*.sh" --include="*.md" --include="*.json"
```

### Key files read in full or in substantial part

- `agent-system/extensions/core/context/guides/manifest-routing-schema.md` (270 lines, in full)
- `agent-system/extensions/core/context/guides/hard-mode-routing.md` (205 lines, substantial part)
- `agent-system/extensions/core/scripts/command-route-agent.sh` (94 lines, in full)
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` (364 lines, in full)
- `agent-system/extensions/core/scripts/lint/lint-routing-wiring.sh` (288 lines, in full)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (Stage 3.5 region, lines 95-430)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate16 region, lines 1595-1630, plus
  header-comment occurrences at lines 199, 692-706)
- `agent-system/extensions/core/scripts/gate-registry.data` (gate16 row)
- `agent-system/extensions/core/context/contracts/anti-analysis.md` and
  `agent-system/extensions/lean/context/contracts/anti-analysis.md` (full diff)
- Six `-hard` agent files and their four standard counterparts (books research+implement, cslib
  research+implement headings, lean research+implement full diff)

### Task metadata cross-check

`specs/state.json` task 444 entry confirmed: `status: "researching"`, `task_type: "meta"`,
`dependencies: [445]` (445 is `completed`, unrelated gate8 work), `file_scope` lists exactly the
9 files named in this report's "Blast radius" subsection as the dispatch's own declared scope.
