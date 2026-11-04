# Research Report: Task #468

**Task**: 468 - Core docs architecture, guide, reference and template set audit for structural
correctness and single-authority topic ownership
**Started**: 2026-11-03
**Completed**: 2026-11-03
**Effort**: large (29 files, ~6500 lines)
**Dependencies**: None declared (8 non-terminal records' territory is a scope boundary, not a
dependency edge — see Decisions)
**Sources/Inputs**: Codebase read of every file under `agent-system/extensions/core/docs/`
(29 files), `agent-system/extensions/core/commands/*.md`, `agent-system/extensions/core/
merge-sources/claudemd.md`, a full-corpus relative-link resolver script, and
`lint-dead-command-recommendations.sh`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `lint-dead-command-recommendations.sh` already passes clean against `core/docs/` (0 violations
  across 33 candidate `Next:`/`Run` lines) — the regression it guards against is not present, but
  that lint only catches one narrow shape. A much larger population of dead `/research`, `/plan`,
  `/implement` references survives in prose, tables, and illustrative examples, because they never
  match the `Next:`/`Run /X` shape the lint scans for.
- 21 concrete broken-link/broken-reference sites were found across 10 files, dominated by a single
  systemic bug: 7 files use the breadcrumb `[Back to Docs](../README.md)` (13 occurrences) when the
  real file is `docs-README.md`, not `README.md` — confirmed broken in both the source store and the
  deployed `.claude/docs/` tree (no rename happens at deploy time).
- Three duplication instances exist, one already named in the dispatch (command syntax across
  `merge-sources/claudemd.md`, `commands/*.md`, `docs/guides/user-guide.md`) and one newly found
  (the Three-Layer Architecture explanation, duplicated between `architecture/system-overview.md`,
  already correct and detailed, and `guides/component-selection.md`, stale and still showing
  `/research, /plan, /implement` as Layer 1 examples).
- The 8-record scope boundary bites concretely in two places: `architecture/batch-admit-schema.md`
  (owned by 274) names dead files `commands/research.md`/`commands/plan.md`/`commands/implement.md`
  as a "second consumer," and `architecture/handoff-schema.md` (owned by 378/428/450) defines its
  `phase` field by reference to "`/research` skill completed" etc. Both need a structural fix that
  brushes against what those records own; both are flagged for deferral rather than decided here.
- Recommended authorities: `commands/orchestrate.md` for full flag/option semantics (it is the
  machine-loaded instruction Claude Code executes, so it cannot be reduced to a pointer);
  `merge-sources/claudemd.md` for the one-line quick-reference table (already correctly minimal);
  `docs/guides/user-guide.md` for the comprehensive walkthrough, which should stop duplicating
  `orchestrate.md`'s full Options table and link to it instead; `architecture/system-overview.md`
  for the Three-Layer Architecture explanation.

## Context & Scope

This is a research-phase dispatch (task 468, dispatch_seq 4) auditing every file under
`agent-system/extensions/core/docs/` (the SOURCE STORE for `.claude/docs/`) for: dead command
surfaces (`/research`, `/plan`, `/implement` as user-invocable commands — confirmed there is no
`agent-system/extensions/*/commands/research.md`, `plan.md`, or `implement.md` anywhere;
`/orchestrate` is the sole lifecycle driver), superseded status transitions, stale routing
tables/inventories, broken relative links, and topic duplication lacking a single authority. Three
distinct required outcomes govern the scope (dead-surface correction, single-authority
consolidation, and adding a specific missing link to four named files), bounded by an explicit
exclusion: eight non-terminal records each own a substantive assertion in one or more of these
same files, and this task must not decide what those documents *assert* — only flag structural
sites that touch their territory, for the plan to route around or defer.

29 files were read in full or by targeted section: `docs-README.md`, `fork-patterns.md`, 13
`guides/*.md` files (including `guides/development/context-index-migration.md`), 2
`examples/*.md`, 6 `architecture/*.md`, 4 `reference/**/*.md` (one of which,
`reference/standards/agent-frontmatter-standard.md`, is explicitly excluded from file_scope per
the dispatch and was read only to confirm nothing elsewhere needs to *change* its content — only
other files' *links to it*), and 3 `templates/*.md`.

## Findings

### 1. Dead command surfaces (`/research`, `/plan`, `/implement` as invocable commands)

Confirmed ground truth: `find agent-system/extensions/*/commands -name '*.md'` enumerates 48
real command files across all loaded extensions; none is named `research.md`, `plan.md`, or
`implement.md`. `/orchestrate` is the only lifecycle driver. The following sites present one of
these three as a literal, runnable command — this is the defect; a phase-name or dispatch-name
mention ("the research phase", "the implement dispatch") is correct and must be left alone.

**Tables presenting dead commands as currently available**:
- `architecture/system-overview.md:90-92` — "Available commands" table lists `/research`,
  `/plan`, `/implement` as current rows (no `/orchestrate` row at all in that table).
- `guides/component-selection.md:92-93` — "Examples" table lists `/research`/`/implement` as
  example commands with purposes "Conduct task research"/"Execute implementation".
- `guides/component-selection.md:12` — ASCII diagram: "Layer 1: Commands User-facing entry points
  (/research, /plan, /implement)".
- `guides/component-selection.md:164,310` — "Pattern 2: New Language Support" shows
  `/research (existing)` as the entry point, and "No command needed — existing `/research` routes
  by language".
- `guides/copy-claude-directory.md:13` — bullet: "Task Management Commands: `/task`, `/research`,
  `/plan`, `/implement`".
- `guides/copy-claude-directory.md:236-240` — a literal runnable Quick Start block:
  `/research 1`, `/plan 1`, `/implement 1` as commands to type.
- `guides/creating-commands.md:69` — "Model Selection" table row "Dispatch commands (`/research`,
  `/plan`, `/implement`)" — directly contradicts the correct statement 40 lines later (line 109)
  in the SAME FILE that these were retired and `/orchestrate` dispatches agents directly with no
  intervening skill-dispatch layer.
- `guides/creating-commands.md:201-204` — "Example Commands to Study" table cites
  `.claude/commands/research.md` and `.claude/commands/implement.md` as files to read; neither
  file exists anywhere in the corpus.
- `guides/creating-extensions.md:463,507` — the generic research/implementation skill TEMPLATE
  text says "Invoked by the orchestrator when: Command is `/research`" (and `/implement`) — the
  skill templates themselves are current (extension domain task types still route through their
  own research/implementation skills), but the invocation condition naming a command that doesn't
  exist is wrong; it should describe dispatch by `/orchestrate` for that phase.
- `guides/creating-extensions.md:668-671` — "Test Routing" walkthrough: "Run research: `/research
  {task_number}`".
- `guides/permission-configuration.md:703-704` — "Test Commands" example: `/research 123  # or
  appropriate command`.
- `templates/README.md:97-98` — illustrative frontmatter example uses the heading "# /research
  Command" as its sample command name; confusing specifically because `/research` is a real,
  dead surface rather than a neutral placeholder.
- `examples/fix-it-flow-example.md:409-411` — "Next Steps" numbered list: step 2 correctly says
  "Run `/orchestrate 650` to begin", but step 3 says "Progress through /research -> /plan ->
  /implement cycle" with a leading slash on each, visually indistinguishable from an invocable
  command list right next to a real one. Recommend dropping the slashes ("the research -> plan ->
  implement phases") to read unambiguously as phase names.

**Architecture/reference-territory dead-command references (inside the 8-record scope boundary — see Decisions)**:
- `architecture/batch-admit-schema.md:308-311` — "Second consumer" paragraph names
  `commands/research.md`'s, `commands/plan.md`'s, and `commands/implement.md`'s "Step 2.5/Step 3.5
  plain-multi-task two-pass structure" as the second consumer of `collision_scope ==
  "in_batch"`. This file is owned by record 274 (`next_admissible_batch_suggestion`). **Flagged
  for deferral**: correcting the dead file names requires deciding what currently implements that
  second consumer (`/orchestrate`'s own multi-task batch logic, almost certainly, but confirming
  and restating it is a substantive claim about batch admission that 274 owns).
- `architecture/handoff-schema.md:184-188` — the `phase` field's definition: "`"research"`:
  `/research` skill completed", "`"plan"`: `/plan` skill completed", "`"implement"`: `/implement`
  skill completed". This file is owned by 378, 428, and 450. **Flagged for deferral**: rewording
  what currently produces each phase value (no skill layer at all today, per
  `system-overview.md`'s own correct note) touches the same field three separate open records
  reason about.
- `architecture/handoff-schema.md:876-881` — a sample JSON's `files_modified` array lists
  `.claude/commands/research.md`, `.claude/commands/plan.md`, `.claude/commands/implement.md` as
  illustrative file paths. This is a literal example value, not a schema assertion — **safe to
  fix** (swap for three files that actually exist) without touching anything 378/428/450 own.
- `reference/standards/agent-frontmatter-standard.md:204,217` mentions "`/research`, `/plan`, and
  `/implement`" as commands users invoke with model-override flags. **Out of scope entirely** —
  this file is explicitly excluded from file_scope per the dispatch (431's audit verdict was
  duplicate-of-open against it). Not actioned; noted only so the audit record is complete.

### 2. Record-versioning phrasing on the dead-command topic

Several of the sites above (and a few structurally-correct ones) narrate the *removal* of
`/research`/`/plan`/`/implement` rather than stating the current design, which risks
`rules/no-record-versioning-in-deliverables.md`:
- `architecture/system-overview.md:9-10` — "the standalone `/research`, `/plan`, `/implement`
  commands and the base lifecycle research/plan/implement skills **have been deleted**."
- `guides/creating-commands.md:108-110` — "...there is no intervening skill-dispatch layer:
  `/research`, `/plan`, and `/implement` **were retired**, and `/orchestrate` dispatches agents
  directly."
- `guides/creating-extensions.md:969-971` — "...not from the single-task `/research`/`/plan`/
  `/implement` skills" (lists an extinct option as a contrast case).

These are already largely correct about the *current* mechanism (direct agent dispatch, no skill
layer) and only need the removal-narration reworded to a positive current-state statement, e.g.
"`/orchestrate` is the sole lifecycle entry point for research/plan/implement phases; it
dispatches agents directly, with no intervening skill-dispatch layer for these phases." This is a
phrasing fix, not a factual correction — low risk, but worth calling out explicitly since the
dispatch binds both no-task-reference and no-record-versioning rules.

### 3. Broken relative links / broken references (21 concrete sites, 10 files)

**Systemic breadcrumb bug — `../README.md` should be `../docs-README.md`** (confirmed broken in
both the source store and the deployed `.claude/docs/` tree; no file named plain `README.md`
exists at `agent-system/extensions/core/docs/`, only `docs-README.md`):
- `architecture/extension-system.md:3,659`
- `guides/creating-extensions.md:3,1118`
- `architecture/system-overview.md:332` (note: line 336's `[README.md](../../README.md)` is a
  *different*, correctly-resolving link to `core/README.md` two levels up — do not touch it)
- `guides/user-installation.md:3,327`
- `guides/adding-domains.md:3,471`
- `guides/user-guide.md:3,918`
- `guides/copy-claude-directory.md:3,272`

13 occurrences total. The fix is mechanical and uniform: `../README.md` -> `../docs-README.md` in
every breadcrumb line above.

**Wrong relative depth — `../commands/README.md` should be `../../commands/README.md`**:
- `guides/copy-claude-directory.md:3,272` — "Commands Reference" link resolves to
  `docs/commands/README.md` (doesn't exist); the real file is `core/commands/README.md`, one
  level further up.

**Deploy-root-style paths used as literal relative links (no `../` prefix at all)** — these
resolve relative to the *containing file's own directory*, not the deploy root, so they are
broken regardless of source/deploy context:
- `guides/permission-configuration.md:825-827` — `[Frontmatter Standard](.claude/context/
  formats/frontmatter.md)`, `[Delegation](.claude/context/orchestration/delegation.md)`, `[State
  Management](.claude/context/orchestration/state-management.md)`. All three targets exist (at
  `core/context/formats/frontmatter.md` and `core/context/orchestration/{delegation,
  state-management}.md`) — only the relative prefix is wrong; correct form from
  `docs/guides/` is `../../context/formats/frontmatter.md` etc.
- `guides/development/context-index-migration.md:247-248` — `[Context Discovery
  Patterns](.claude/context/patterns/context-discovery.md)` and `[Agent Frontmatter
  Standard](.claude/docs/reference/standards/agent-frontmatter-standard.md)`. Both targets exist;
  correct relative forms from `docs/guides/development/` are
  `../../../context/patterns/context-discovery.md` and
  `../../reference/standards/agent-frontmatter-standard.md` respectively. (Fixing this link is
  fixing a *referrer*, not the excluded target file itself — safe and in scope.)

**Wrong target entirely**:
- `guides/creating-skills.md:300` — `@.claude/context/patterns/fork-patterns.md` — no such file
  exists. The real file is `agent-system/extensions/core/docs/fork-patterns.md`, i.e. deployed
  `.claude/docs/fork-patterns.md`. This single wrong reference is compounded by the next finding
  (fork-patterns.md isn't discoverable from the docs hub either).

**Not a defect — false-positive class worth naming for the implementer**: every `[CLAUDE.md]
(../CLAUDE.md)` / `(../../CLAUDE.md)` link (in `docs-README.md` and `guides/user-guide.md`,
`guides/user-installation.md`, `architecture/system-overview.md`) resolves to a file that does
not exist in the *source store* (`CLAUDE.md` is generated at merge/deploy time from
`merge-sources/claudemd.md` across all loaded extensions) but does exist in the *deployed*
`.claude/` tree. A relative-link checker run against the source store will flag these; they are
expected and should be excluded from the "pass" criterion rather than "fixed", since there is no
source-store file to point them at.

### 4. Stale component inventories

- `docs-README.md`'s own "Documentation Map" code-block tree (lines 11-46) and its "Guides"/
  "Related Documentation" sections never mention `fork-patterns.md`, even though it is a top-level
  file directly alongside `docs-README.md` itself. Combined with finding 3's wrong reference to
  it, this file is effectively undiscoverable from the documentation hub.
- `architecture/system-overview.md:90-92`'s "Available commands" table (finding 1) is simultaneously
  a dead-command-surface defect and a stale-inventory defect: it is missing `/orchestrate`
  entirely and missing newer commands like `/project-overview`, `/please`, `/zulip` that exist in
  `merge-sources/claudemd.md`'s Command Reference table.

### 5. Duplication / single-authority gaps (3 instances)

1. **Command syntax** (the instance named in the dispatch). Three sites restate `/orchestrate`'s
   flags: `commands/orchestrate.md` (lines 41-60, the full canonical Options table, each row with
   detailed semantics and pointers into `orchestrate-state-machine.md`); `merge-sources/
   claudemd.md` (lines 98-120, a one-line-per-command Command Reference table, already minimal
   and already pointing into `orchestrate-state-machine.md` for forcing-flag/cycle-budget detail
   — this file needs no change); `docs/guides/user-guide.md` (lines ~415-429, a flags table that
   is a near-verbatim restatement of `orchestrate.md`'s Options table, down to identical prose per
   flag). `commands/orchestrate.md` cannot be reduced to a pointer — Claude Code loads it directly
   as the command's own instructions, so it must stay self-contained. `user-guide.md`'s
   duplicate table is the one to reduce: replace with a short "most commonly used flags" subset
   (or drop entirely) plus a link to `../../commands/orchestrate.md`'s Options section for the
   full, current reference.

2. **Three-Layer Architecture explanation** (newly found, not named in the dispatch).
   `architecture/system-overview.md:17-...` has a detailed, already-current diagram (uses
   `orchestrate.md`, `skill-orchestrate`, and correctly notes the Layer 2 collapse for
   core-command direct dispatch). `guides/component-selection.md:7-18` and `:239-244` duplicate
   the same three-layer concept with a stale diagram (dead `/research, /plan, /implement`
   examples, no mention of the direct-dispatch collapse). Recommend: `system-overview.md` is the
   authority for *what* the three layers are and how they currently compose; `component-selection.md`
   keeps its unique value (the decision tree for "which component do I create") but trims its own
   architecture-explanation preamble to a one-paragraph summary plus a link to
   `../architecture/system-overview.md#three-layer-architecture`, and updates its retained
   examples/diagrams (lines 12, 239-244) to not show dead commands.

3. **"The extension picker" mentioned with no link** (the dispatch's outcome 3, not strictly a
   duplication case but the same single-authority principle: one authoritative place —
   `agent-system/extensions/README.md` — explains what the picker is and how to use it; every
   other mention should point there). Confirmed current line numbers (re-derived; the dispatch's
   own numbers were approximate and are superseded by these):
   - `guides/adding-domains.md:39` ("...are loaded via the the extension picker." — also has an
     incidental duplicated-word typo, "the the", worth fixing in the same edit) and `:171-174`
     ("Extensions are managed via the extension picker: 1. **Loading**... 2. **Unloading**...").
   - `guides/creating-extensions.md:11,636,679`.
   - `architecture/extension-system.md:33,547`.
   - `reference/standards/extension-slim-standard.md:5,196`.

   Correct relative paths to `agent-system/extensions/README.md`, confirmed by an existing working
   link elsewhere in the corpus (`guides/user-guide.md:765` already links to it correctly as
   `../../../README.md`):
   - From `docs/guides/*.md` (adding-domains.md, creating-extensions.md): `../../../README.md`
   - From `docs/architecture/*.md` (extension-system.md): `../../../README.md`
   - From `docs/reference/standards/*.md` (extension-slim-standard.md): `../../../../README.md`

## Decisions

- **The 8-record scope boundary is upheld exactly as the dispatch states it.** No dependency edge
  is declared on 274, 378, 387, 420, 428, 438, 450, or 431. `reference/standards/
  agent-frontmatter-standard.md` is excluded from file_scope entirely (content untouched); other
  files' *links pointing at it* remain correctable (finding 3's context-index-migration.md fix).
- **Two concrete deferral sites are named** (finding 1's architecture-territory bullets): the
  `commands/research.md`/`plan.md`/`implement.md` dead-file reference in
  `architecture/batch-admit-schema.md` (274's territory), and the `phase` field's "`/research`
  skill completed" etc. definitions in `architecture/handoff-schema.md` (378/428/450's
  territory). The plan should route these to whichever of those records lands first, or defer the
  exact rewording to this task's own later phase with explicit sign-off that it does not alter
  what the field/consumer *asserts* — only what it names as the current invocation surface.
  `handoff-schema.md`'s `files_modified` *example literal* (finding 1) is NOT a deferral site —
  it is illustrative data, safe to fix now.
- **Authority decisions** (finding 5): `commands/orchestrate.md` = authority for full flag/option
  semantics (cannot be a pointer; it is machine-loaded). `merge-sources/claudemd.md` = authority
  for the one-line quick-reference table (no change needed). `docs/guides/user-guide.md` =
  authority for the comprehensive prose walkthrough and troubleshooting; its duplicate Options
  table is reduced to a pointer. `architecture/system-overview.md` = authority for the
  Three-Layer Architecture explanation; `guides/component-selection.md` keeps its decision-tree
  content but points to `system-overview.md` for the architecture explanation itself.
  `agent-system/extensions/README.md` = authority for what the extension picker is; the four
  files in finding 5.3 get a link added at each site, not a rewritten explanation.
- **The record-versioning phrasing issue (finding 2) is in scope and should be fixed alongside
  the dead-command correction it rides on** — it is the same edit site in every case, not a
  separate pass.
- **The "Progress through /research -> /plan -> /implement cycle" phrasing in
  `fix-it-flow-example.md:411`** is judged ambiguous rather than cleanly "dead" or "correct": drop
  the leading slashes so it reads as phase names, consistent with the dispatch's instruction to
  preserve genuine phase-name references.

## Recommendations

1. Fix the 13 broken `../README.md` breadcrumb links (-> `../docs-README.md`) across the 7 files
   in finding 3 as one mechanical pass — same find/replace shape in every file, lowest risk,
   highest-count defect in the whole audit.
2. Fix the 2 `../commands/README.md` links (-> `../../commands/README.md`) in
   `copy-claude-directory.md`, the 5 `.claude/context/...`-as-relative-path links in
   `permission-configuration.md` and `context-index-migration.md` (add the correct `../../` or
   `../../../` prefix per site), and the 1 wrong `fork-patterns.md` reference in
   `creating-skills.md`.
3. Add `fork-patterns.md` to `docs-README.md`'s Documentation Map tree and Guides/Related section
   so finding 4's undiscoverability and finding 3's wrong reference are fixed together (a reader
   who hits the fixed link in `creating-skills.md` should also be able to find the file from the
   hub).
4. Correct every dead-command-surface site in finding 1 outside the 8-record boundary: replace
   `/research`/`/plan`/`/implement` as example or inventoried commands with `/orchestrate`
   (plus, where a table is meant to be a full command inventory, the other current commands it is
   missing — `system-overview.md`'s table specifically). Reword the Quick Start block in
   `copy-claude-directory.md` to `/orchestrate 1 --research`, `/orchestrate 1 --plan`,
   `/orchestrate 1 --implement` or simply `/orchestrate 1` for the plain lifecycle walk. Fix the
   internal contradiction in `creating-commands.md` between line 69 (stale) and line 109
   (correct) by correcting line 69's table row to describe `/orchestrate` as the one dispatch
   command.
5. Apply the record-versioning phrasing fix (finding 2) at the same three sites, in the same
   edit as their dead-command correction.
6. For the two 8-record-territory sites (finding 1's `batch-admit-schema.md` and
   `handoff-schema.md` bullets): either defer them to a later phase explicitly, or, if the plan's
   author judges the fix genuinely structural-only (naming the real current consumer/producer
   without asserting anything new about batch admission or the handoff contract), make the
   narrowest possible edit and say so plainly in the phase's own notes — never silently fold it
   into a routine dead-command sweep.
7. Reduce `user-guide.md`'s duplicate Options table to a pointer into `commands/orchestrate.md`
   (finding 5.1); trim `component-selection.md`'s architecture preamble and point to
   `system-overview.md` (finding 5.2), updating its own remaining dead-command examples.
8. Add the `agent-system/extensions/README.md` link at each of the eight sites in finding 5.3,
   using the three relative-depth forms given there; fix the incidental "the the" typo in
   `adding-domains.md:39` in the same edit.
9. Re-run `lint-dead-command-recommendations.sh` and a full relative-link check (excluding the
   `CLAUDE.md`-in-source-store false-positive class named in finding 3) after every phase that
   touches these files, not just once at the end.

## Risks & Mitigations

- **Risk**: fixing the `architecture/batch-admit-schema.md` or `handoff-schema.md` dead-reference
  sites drifts into deciding what 274/378/428/450 own. **Mitigation**: the deferral flag in
  Decisions; the plan should make these their own reviewed micro-edit, not bundled anonymously
  into a bulk find/replace.
- **Risk**: a bulk find/replace of `/research`/`/plan`/`/implement` strings could accidentally
  rewrite a correct phase-name/dispatch-name mention (the dispatch's own CRITICAL warning).
  **Mitigation**: every site in finding 1 was individually read in context and classified before
  being listed here; the plan should do the same per-site read rather than a blind global
  substitution, and `fix-it-flow-example.md:411` is the one judgment call flagged explicitly.
- **Risk**: `lint-dead-command-recommendations.sh` passing does not mean the corpus is clean —
  it only catches the `Next:`/`Run /X` shape (finding 1's larger population is in tables and
  prose the lint cannot see). **Mitigation**: treat the lint as a regression guard, not a
  completeness check; the acceptance criterion's grep for dead-command surfaces must cover
  tables and prose too.
- **Risk**: the relative-link checker used here is a bespoke one-off script, not a repo-standing
  tool; re-verification at implementation/verification time needs an equivalent check (or the
  same script) re-run, with the `CLAUDE.md` false-positive class explicitly excluded or the check
  run against the *deployed* tree where `CLAUDE.md` exists.

## Context Extension Recommendations

- **Topic**: relative-link correctness across `agent-system/extensions/*/docs/`.
- **Gap**: no standing lint checks markdown relative-link resolution; the `docs-README.md` <->
  `README.md` naming mismatch alone produced 13 broken links that a human reviewer would need to
  re-discover by hand next time.
- **Recommendation**: consider a follow-up task (outside this one's scope) to add a lint similar
  in spirit to `lint-dead-command-recommendations.sh` — enumerate every `*.md` under
  `agent-system/extensions/*/docs/` (and `context/`), resolve every `](relative/path)` link
  against the file's own directory, and fail on any target that doesn't exist, with an explicit,
  documented exclusion for links whose target is a merge-time-generated file (`CLAUDE.md`,
  `EXTENSION.md`) that only exists post-deploy.

## Appendix

Search queries / commands used:
- `find agent-system/extensions/core/docs -type f -name "*.md"` (file inventory)
- `grep -rn '/research[^-a-zA-Z_]\|/plan[^-a-zA-Z_]\|/implement[^-a-zA-Z_]'` across `core/docs/`
- `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh
  agent-system/extensions/core/docs/` (baseline: 0 violations, 33 candidates, 33 exempted)
- A bespoke Python relative-link resolver walking every `*.md` under `core/docs/`, resolving each
  `](path)` (excluding `http`/`#`/`mailto:`) against the containing file's directory, reporting
  any target that does not exist on disk — 34 raw hits, resolved by hand to 21 genuine defects
  plus the `CLAUDE.md` false-positive class (13 hits) documented in finding 3.
- `find agent-system/extensions/*/commands -name '*.md'` (confirms 48 real commands, none named
  research/plan/implement.md)
- Targeted `sed -n` reads of every site cited above, in context, to classify dead-surface vs.
  phase-name vs. deferral-boundary vs. false-positive.
