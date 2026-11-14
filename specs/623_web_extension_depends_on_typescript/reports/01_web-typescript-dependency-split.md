# Research Report: Task #623

**Task**: 623 - Make the web extension depend on the typescript extension and split the shared TypeScript context down a layer
**Started**: 2026-11-13T00:00:00Z
**Completed**: 2026-11-13T00:00:00Z
**Effort**: medium
**Dependencies**: Task 621 (COMPLETED), Task 622 (COMPLETED)
**Sources/Inputs**: Codebase (`agent-system/extensions/web/`, `agent-system/extensions/typescript/`, `agent-system/extensions/slidev/`, `agent-system/extensions/founder/`, `agent-system/extensions/core/`)
**Artifacts**: specs/623_web_extension_depends_on_typescript/reports/01_web-typescript-dependency-split.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Adding `"typescript"` to `web`'s `manifest.json` `dependencies` array is mechanically safe:
  `web -> typescript -> core` is a 2-level chain with no cycle, far under the loader's
  depth-5 limit, and the loader already de-duplicates an already-loaded dependency (confirmed
  from `lua/neotex/plugins/ai/shared/extensions/init.lua`'s loading-stack / depth-check logic).
- The manifest edit alone does **not** cause web-dispatched agents to actually load the
  typescript context tree. `web-research-agent.md` and `web-implementation-agent.md` discover
  context through their own **static, hand-authored** `## Context References` `@`-pointer
  lists, not through a dynamic `index.json` `load_when` query at dispatch time. Neither file
  currently references any `project/typescript/` path. Fulfilling "Astro work auto-loads the
  base TypeScript context" requires a second, concrete edit: add one `@`-reference line to each
  of those two agent files pointing at `@.claude/context/project/typescript/README.md` — exactly
  the one-line pattern `typescript-research-agent.md` itself uses for its own README, relying on
  that README's own "Loading Strategy" section for on-demand discovery of the rest.
- The line-level split in `web/context/project/web/domain/typescript-web.md` is narrow: exactly
  two subsections duplicate generic material that already exists, independently authored, in
  the `typescript` extension's context tree — `### Common Zod Patterns` (lines 204-232, 29
  lines, duplicating `typescript/.../patterns/zod-validation-patterns.md`'s "Core Primitives")
  and `## Import Aliases` (lines 234-247, 14 lines, duplicating
  `typescript/.../patterns/path-alias-patterns.md`'s "Using an Alias"). Everything else in the
  303-line file (tsconfig Astro presets, `interface Props`, `astro/types` utilities, content
  collection types, `astro check`, `env.d.ts`, the Astro-vs-`.ts` table) is genuinely
  Astro-specific and stays.
- Recommended approach: trim the two duplicate subsections out of `typescript-web.md`, replace
  each with a one-line cross-reference pointer to the corresponding `typescript` extension file,
  and do not create any new file in `typescript`'s tree (the generic content is already there).

## Context & Scope

This is the research phase for a `meta` task whose deliverable is entirely inside the source
store (`agent-system/extensions/`), per the dispatch's hard constraint and
`.claude/rules/source-store-deploy-boundary.md`. Scope is the four `WHAT TO DO` items in the
task description: (1) declare the `typescript` dependency in `web/manifest.json`, (2) execute a
line-level split of `web/context/project/web/domain/typescript-web.md`, (3) update both
extensions' `index-entries.json`, (4) re-verify clean standalone/combined deploys and the
dependency auto-load path (circular detection, depth limit 5). Neither `web`'s nor
`typescript`'s rule files (`web-astro.md`, `typescript-rules.md`) are named in the task
description and are treated as out of scope for the edit itself, though one adjacent
duplication in `web-astro.md` is flagged below as a follow-up, not acted on.

Prerequisite tasks 621 (built the `typescript` extension) and 622 (validated its generic
toolchain detection against a real external repo) are both `[COMPLETED]`; their summaries
confirm the `typescript` extension's 20-file baseline has not drifted and its four merge targets
(`installed files`, `claudemd`, `index`, `opencode_json`) all work end-to-end via a scratch-target
deploy test. Neither `web` nor `typescript` is currently loaded in this repository's own
`.claude-extensions.json` (loaded set: `literature`, `nix`, `lean`, `email`, `approvals`, `nvim`,
`sapience`, `core`), so no live deploy state is at risk from this task's edits.

## Findings

### Codebase Patterns

**Dependency/loader mechanics** (`lua/neotex/plugins/ai/shared/extensions/init.lua`, confirmed
against `agent-system/extensions/core/context/guides/extension-development.md`'s "##
Dependencies" section):
- `max_depth = 5`; a loading stack is threaded through the recursive `manager.load()` calls; an
  extension name appearing twice in that stack fails with `"Circular dependency detected: A ->
  B -> C -> A"`; the stack-length check against `max_depth` fires independently of an explicit
  cycle.
- `web`'s current `dependencies: ["core"]` plus the planned addition of `"typescript"` gives a
  resolution order `web -> [core, typescript] -> typescript -> [core]` (already loaded, skipped).
  Maximum stack depth reached is 2 — far under 5, no cycle possible (neither `core` nor
  `typescript` depends on `web`).
- "If a dependency fails to load, the parent extension also fails (before copying any files)" —
  so a `typescript`-load failure during a `web` load aborts the whole `web` load cleanly, not a
  partial/dirty state.
- Unload safety is a **hard block**, not merely a warning: once `web` is loaded, unloading
  `typescript` is refused with `"ERROR: Cannot unload 'typescript' -- required by: web"` until
  `web` itself is unloaded first. Worth stating in the plan's verification checklist, since it
  changes the unload-ordering expectation for whoever tests this interactively.

**The actual agent-side context-loading channel is static, not the `index.json` `load_when`
gate.** This is the single most important, non-obvious finding of this research pass. Two
superficially plausible mechanisms exist in this codebase and only one of them is what
`web-research-agent`/`web-implementation-agent` actually use:
1. `index.json`'s `load_when.agents`/`load_when.task_types` arrays, documented extensively in
   `context/patterns/context-discovery.md` as a jq-queryable discovery layer, consumed by
   `validate-context-budgets.sh` (token-budget enforcement) and `validate-wiring.sh`
   (informational per-task_type entry counts). This is real and load-bearing for those two
   scripts, but it is a **validation/budget** mechanism, not the thing that puts a file path in
   front of a dispatched agent.
2. Each agent `.md` file's own hand-authored `## Context References` section: a fixed list of
   `@.claude/context/...` pointers, resolved by the harness's directory-relative `@`-import
   mechanism at dispatch time. This is the channel that actually determines what an agent loads.
   Grepping `web-research-agent.md` and `web-implementation-agent.md` for `load_when`/`jq
   `/`index.json` found **zero** matches in either file — neither agent queries the index at
   all. Their `## Context References` sections list only `project/web/**` paths; **no**
   `project/typescript/**` path appears in either file today.

Confirmed by contrast: `typescript-research-agent.md`'s own `## Context References` section
eagerly lists exactly **one** file — `@.claude/context/project/typescript/README.md` — and
relies on that README's own "## Loading Strategy" section (a plain-text decision table, not a
mechanical index) for the agent to decide which of the other 7 files to `Read` on demand. This
is the established, minimal convention in this codebase: eagerly reference the tree's own
README, not every leaf file.

**Consequence for item 1 ("so Astro work auto-loads the base TypeScript context")**: the
manifest `dependencies` edit guarantees the `typescript` extension's files are *physically
present* under `.claude/context/project/typescript/` whenever `web` is loaded (deploy-time
effect), but by itself changes nothing about what either web agent actually reads. Making the
stated goal literally true requires a second edit — adding one `@`-reference line to each of
`web-research-agent.md` and `web-implementation-agent.md`'s `## Context References` sections,
pointing at `@.claude/context/project/typescript/README.md`, mirroring
`typescript-research-agent.md`'s own pattern exactly. Without this second edit, item 1 is only
partially fulfilled: the dependency loads and deploys correctly, but no agent behavior changes.

**Precedent for cross-extension context sharing via a declared dependency** —
`founder`'s `dependencies: ["core", "slidev"]` plus `slidev`'s own `index-entries.json`: every
`slidev` entry's `load_when.agents` list directly names the *consuming* extensions' own agents
(`deck-planner-agent`, `deck-builder-agent`, `slidev-assembly-agent`, `slide-planner-agent`,
`slide-critic-agent` — none of these are `slidev`'s own agents; `slidev` has no agents of its
own and is `routing_exempt: true`). This establishes that naming a foreign extension's agents
inside another extension's `index-entries.json` `load_when.agents` array is an accepted,
precedented pattern in this codebase — but it does not, by itself, explain how
`web-research-agent`/`web-implementation-agent` would ever come to read that index entry, since
(per the finding above) those two agents never query `index.json` at all. The `slidev` case
works because `founder`'s own agents presumably *do* perform an index.json query somewhere in
their own prompts/skills (not verified in this pass — out of scope, no `founder`-agent files
were read) — if so, that is a different, unverified mechanism from `web`'s. This report does not
assert `slidev`'s pattern is proof that `index.json` edits alone would work for `web`; the
`web-research-agent.md`/`web-implementation-agent.md` grep result is the directly verified fact
for this task's two specific agents.

**`typescript-web.md` line-level audit** (303 lines total,
`agent-system/extensions/web/context/project/web/domain/typescript-web.md`):

| Lines | Section | Astro/browser-specific or generic? | Disposition |
|-------|---------|-------------------------------------|--------------|
| 1-36 | `## tsconfig.json Setup` (incl. Astro preset table) | Astro-specific (`astro/tsconfigs/*` presets; the `@components`/`@layouts`/etc. alias names are an *applied example* of the generic alias pattern, not a restatement of it) | STAYS |
| 38-69 | `## Type-Safe Component Props` | Astro-specific (`Astro.props`, `interface Props`) | STAYS |
| 71-90 | `### Complex Props` | Astro-specific | STAYS |
| 92-123 | `## Built-in Type Utilities` (`HTMLAttributes`, `ComponentProps`) | Astro-specific (`astro/types`) | STAYS |
| 125-151 | `### Route Type Inference` | Astro-specific (`astro:content`, `getStaticPaths`) | STAYS |
| 153-166 | `### Content Collection Types` | Astro-specific (`CollectionEntry`) | STAYS |
| 168-202 | `## Content Collection Schemas with Zod` (top part: `defineCollection`, `glob` loader, applied schema) | Astro-specific usage of Zod inside `astro:content` | STAYS |
| **204-232** | **`### Common Zod Patterns`** | **Generic** — same 6 canonical Zod primitives (enum, `coerce.date`, url, min/max, nested object, discriminated union), independently restated, already covered by `typescript/.../patterns/zod-validation-patterns.md`'s "Core Primitives" section | **MOVE** (trim + pointer) |
| **234-247** | **`## Import Aliases`** | **Generic** — the "replace a deep relative import with an `@` alias" pattern, already covered by `typescript/.../patterns/path-alias-patterns.md`'s "Using an Alias" section; only the closing clause ("Astro resolves them automatically") is Astro-specific | **MOVE** (trim + pointer, keep the one Astro-specific clause) |
| 249-270 | `## Type Checking` (`astro check`) | Astro-specific (`astro check` is Astro's own compiler wrapper, distinct from generic `tsc --noEmit`) | STAYS |
| 272-291 | `## env.d.ts` | Astro-specific (`.astro/types.d.ts` reference) | STAYS |
| 293-303 | `## TypeScript in Astro Components vs .ts Files` | Astro-specific comparison table | STAYS |

Net effect of the split: typescript-web.md shrinks by roughly 43 lines (plus whatever pointer
text replaces them, likely 2-6 lines), landing around 265-270 lines; no new file is created in
`typescript`'s tree because the generic content these two subsections duplicate already exists
there, independently authored.

**`typescript-rules.md` vs. `web-astro.md` — out-of-scope but worth flagging.** `web-astro.md`'s
"## TypeScript Standards" table (its own lines ~112-120: no `any`, explicit return types,
`interface` over `type`, type-only imports) duplicates generic style-guide content already in
`typescript/context/project/typescript/standards/typescript-style-guide.md`. This is a rule
file, not a context file, and is not named by the task description's `WHAT TO DO` list (which
names only `typescript-web.md`). Both rule files load independently via the harness's
path-glob mechanism (`.claude/rules/*.md` `paths:` frontmatter), so no functional conflict
exists from leaving it as-is — just duplicated prose. Recorded as a follow-up recommendation,
not acted on in this task's scope.

**`index-entries.json` accounting.** `web/index-entries.json`'s `typescript-web.md` entry
currently declares `"line_count": 303`; this must be corrected to the post-split actual `wc -l`
count (`generate-context-line-counts.sh --write`, or a manual edit) — `check-extension-docs.sh`'s
Rule R and `validate-context-budgets.sh`'s token-budget math both depend on this being exact.
No corresponding `typescript`-side `index-entries.json` entry needs a *new* row, since no new
file is being created there — the two files whose content these sections conceptually duplicate
(`zod-validation-patterns.md`, `path-alias-patterns.md`) already have their own accurate entries
and are untouched by this task's split. "Update BOTH extensions' index-entries.json to match the
moved files" (task item 3) is therefore satisfied for `typescript`'s side by confirming no change
is needed there (nothing moved *into* it, because it was already present) — this should be
stated explicitly in the plan/summary rather than silently skipped, so a future reviewer does not
read "no diff" as "forgotten."

### External Resources

Not applicable — this is a pure codebase-internal refactor of this repository's own extension
system; no external documentation, library, or API was consulted.

## Recommendations

1. **Manifest edit**: add `"typescript"` to `agent-system/extensions/web/manifest.json`'s
   `dependencies` array (`["core", "typescript"]`). Low risk per the loader-mechanics finding
   above.
2. **Content split**: in `typescript-web.md`, delete the `### Common Zod Patterns` subsection
   (lines 204-232) and replace with a one-line pointer such as "See the `typescript` extension's
   `patterns/zod-validation-patterns.md` for the generic Zod primitives this builds on." Delete
   `## Import Aliases` (lines 234-247) except its final Astro-specific clause, replaced with a
   pointer to `typescript`'s `patterns/path-alias-patterns.md`. Do not touch any other section.
3. **Make the dependency functionally meaningful** (addresses the gap identified above, not
   explicitly named by the task's four `WHAT TO DO` items but necessary for item 1's own stated
   goal to actually hold): add one `@`-reference line to each of
   `agent-system/extensions/web/agents/web-research-agent.md` and
   `.../web-implementation-agent.md`'s existing `## Context References` sections:
   `` `@.claude/context/project/typescript/README.md` - Generic TypeScript context tree index ``
   — mirroring `typescript-research-agent.md`'s own one-line pattern exactly, so the rest of the
   `typescript` tree is discovered on demand via that README's "Loading Strategy" table rather
   than eagerly listing all 7 leaf files.
4. **`index-entries.json` updates**: recompute `web/index-entries.json`'s `typescript-web.md`
   `line_count` to the actual post-split line count (prefer running
   `generate-context-line-counts.sh --write` over a hand count, to match the tool
   `check-extension-docs.sh`'s Rule R re-checks against). Confirm, and state explicitly in the
   implementation summary, that no `typescript`-side `index-entries.json` row needs to change.
5. **Verification (item 4)**: reuse the scratch-target deploy procedure task 621 already
   documented in `typescript/README.md`'s "### Verifying This Extension's Own Deploy" subsection,
   extended to three cases against a disposable scratch git repo: (a) load `typescript` alone,
   (b) load `web` alone and confirm `typescript` auto-loads as a dependency with no confirmation
   dialog, files for both extensions present, and all four of each extension's merge targets
   correct, (c) load both together via `web`, then attempt `manager.unload("typescript")` and
   confirm the hard-block error naming `web` as the dependent. Run the existing lints
   (`lint-routing-wiring.sh`, `lint-extension-readme-table.sh`, `lint-agent-contracts.sh`,
   `lint-shellcheck.sh`, `check-extension-docs.sh`) against both extensions afterward.
6. Treat the `web-astro.md`/`typescript-rules.md` duplicate "TypeScript Standards" table as a
   separate, future follow-up task — out of this task's named scope.

## Decisions

- The line-level split is narrow: exactly two subsections of `typescript-web.md` (43 lines) are
  generic and duplicate already-existing `typescript` extension content; everything else in the
  file is genuinely Astro-specific and stays. No new file is created under
  `typescript/context/project/typescript/`.
- The `index.json` `load_when` gate was considered and rejected as the primary fix for making the
  dependency functionally load context for web agents, because `web-research-agent.md`/
  `web-implementation-agent.md` do not query it; the static per-agent `## Context References`
  `@`-pointer list is the verified real channel, and the plan should edit that instead (or in
  addition, if the plan separately wants `index.json`-based discoverability for some other
  future consumer — this report does not rule that out, only identifies it as non-essential for
  item 1's own stated goal).

## Risks & Mitigations

- **Risk**: trimming `typescript-web.md`'s two subsections without adding the cross-reference
  pointer silently drops coverage a web-implementation-agent previously had inline, with no
  compensating discovery path (since, per the finding above, that agent does not otherwise see
  `typescript`'s tree). **Mitigation**: the plan must treat recommendation 3 (static
  `@`-reference pointer in both web agent files) as a hard requirement of this task's completion
  criteria, not an optional nice-to-have — otherwise item 1's own stated goal ("so Astro work
  auto-loads the base TypeScript context") is not actually met even though the manifest diff
  looks correct.
- **Risk**: `line_count` drift in `web/index-entries.json` after the trim, silently breaking
  `validate-context-budgets.sh`'s token-budget math and failing `check-extension-docs.sh`'s
  Rule R on a later `verify-deploy.sh` run. **Mitigation**: use
  `generate-context-line-counts.sh --write` rather than a hand-computed count.
- **Risk**: a future maintainer re-adds the duplicated Zod/alias prose to `typescript-web.md`
  without realizing it now lives in `typescript`'s tree, re-introducing drift. **Mitigation**:
  the pointer text itself (recommendation 2) should name the exact target file, not just say
  "see the typescript extension," so the duplication is easy to recognize and avoid re-creating.

## Context Extension Recommendations

- **Topic**: cross-extension context discoverability for a dependency relationship.
- **Gap**: `context/guides/extension-development.md`'s "## Dependencies" section documents the
  *loader* mechanics (auto-load, circular detection, depth limit, unload-block) thoroughly, but
  says nothing about how a dependent extension's *agents* are expected to actually come to read
  the dependency's context tree. This task's research had to reverse-engineer the answer (static
  per-agent `## Context References` lists, not `index.json` `load_when`) by grepping two
  specific agent files; a future extension author declaring a similar dependency (not just
  `web`/`typescript`) would hit the same ambiguity.
- **Recommendation**: add a short subsection to `extension-development.md`'s "## Dependencies"
  section (or a new `context/patterns/` file it links to) stating explicitly that declaring a
  `dependencies` entry only guarantees the dependency's files are deployed, and that any agent
  which should actually *read* the dependency's context tree needs its own
  `## Context References` pointer added by hand — with `typescript-research-agent.md`'s
  one-line-to-its-own-README pattern as the recommended minimal template.

## Appendix

- Files read in full or in relevant part: `agent-system/extensions/web/manifest.json`,
  `agent-system/extensions/typescript/manifest.json`,
  `agent-system/extensions/web/context/project/web/domain/typescript-web.md`,
  `agent-system/extensions/web/index-entries.json`,
  `agent-system/extensions/typescript/index-entries.json`,
  `agent-system/extensions/typescript/context/project/typescript/README.md`,
  `agent-system/extensions/typescript/context/project/typescript/patterns/zod-validation-patterns.md`,
  `agent-system/extensions/typescript/context/project/typescript/patterns/path-alias-patterns.md`,
  `agent-system/extensions/typescript/context/project/typescript/domain/tsconfig-reference.md`,
  `agent-system/extensions/typescript/context/project/typescript/standards/typescript-style-guide.md`,
  `agent-system/extensions/web/context/project/web/README.md`,
  `agent-system/extensions/core/context/guides/extension-development.md` (Dependencies section),
  `lua/neotex/plugins/ai/shared/extensions/init.lua` (dependency resolution, circular detection,
  depth limit, unload-block — grepped, not read in full),
  `agent-system/extensions/slidev/manifest.json`, `agent-system/extensions/slidev/index-entries.json`,
  `agent-system/extensions/founder/manifest.json`,
  `agent-system/extensions/web/agents/web-research-agent.md`,
  `agent-system/extensions/web/agents/web-implementation-agent.md`,
  `agent-system/extensions/typescript/agents/typescript-research-agent.md`,
  `agent-system/extensions/web/rules/web-astro.md`,
  `agent-system/extensions/typescript/rules/typescript-rules.md`,
  `agent-system/extensions/core/context/patterns/context-discovery.md`,
  `specs/621_typescript_extension_implementation/summaries/01_typescript-extension-verification-closeout-summary.md`.
- Searches: `grep -rln "circular"` across `.claude/scripts/`; `grep -n "load_when|task_type|index.json|jq "` against both web agent files (zero matches, the key negative finding); `grep -rln "typescript-web"` repo-wide; `python3`-based `jq`-equivalent scan of every extension's `index-entries.json` for a multi-value `task_types` precedent (none found).
- Prior task artifacts consulted: task 621's implementation summary (typescript extension baseline, scratch-target deploy-verification procedure); task 622's TODO.md entry (generic toolchain validation against `sf1-engine`, unrelated to this task's dependency-wiring question).
