# Research Report: Task #603

**Task**: 603 - Make specs/ROADMAP.md a wholly generated artifact backed by state.json roadmap
entries, and add a `/roadmap [instruction]` command/skill/agent that maintains them
**Started**: 2026-11-11
**Completed**: 2026-11-11
**Effort**: large (schema + generator rewrite + new command/skill/agent + migration + a
`-hard`-free judgment agent)
**Dependencies**: None declared on this record; task 602 (next-batch suggestion) has a
declared edge running *behind* 603 per the live `## Next` Run 1 rationale, because 602's
own open questions are answered differently once this lands
**Sources/Inputs**: Codebase (`.claude/scripts/roadmap-integration.sh`,
`.claude/context/formats/roadmap-format.md`, `.claude/context/patterns/roadmap-update.md`,
`.claude/context/reference/state-management-schema.md`, `.claude/context/schemas/state-schema.json`,
`.claude/scripts/validate-state.sh`, `.claude/scripts/state-write.sh`,
`.claude/scripts/update-task-status.sh`, `.claude/scripts/generate-todo.sh`,
`.claude/scripts/lint/lint-roadmap-batch-proposals.sh`, `specs/state.json`, `specs/ROADMAP.md`,
task 313's plan/report/summary)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `specs/ROADMAP.md` is already *partly* generated (`## Open work` and `## Next`'s coverage
  appendix). What is missing from state.json is a structured home for **batches**: today a
  batch's membership, order and rationale exist only as hand-typed `/orchestrate` lines plus
  "Why this order:" prose inside `## Next`, recovered on each regenerate by a retention parser
  that reads the file it is about to overwrite. Moving that judgment into state.json is the
  whole point of this task, and it is achievable without disturbing the file's six genuinely
  authored/measured sections.
- Recommend a **new top-level `roadmap_batches` array** in `specs/state.json` (sibling to
  `active_projects`/`active_topics`), where **array position is the batch's priority** — no new
  priority field, no reuse of the existing per-task `priority` enum (which is a different,
  already-live axis: see Decision 2). Each batch entry carries `task_ids`, a one-line
  `description` (the anti-fluff field the template bounds), a free-text `rationale` (the
  lossless home for the current "Why this order:" prose, itself unbounded — see Decision 3), and
  an optional `flags` string (the authored CLI segment, e.g. `--hard`).
- The six remaining `## ` sections (`Goal`, `Gate state`, `Checks before and after every call`,
  `Settled decisions (do not re-litigate)`, `Standing rules`, `Unfiled observations`) should
  **stay authored directly in the markdown file**, exactly as today — see Decision 1 for the
  full per-section ruling the dispatch asked for. `## Gate state` in particular cannot be
  generated at all (it is measured by running suites, not derived from any field this or any
  other script could hold), and the other four are long-form prose essays, not structured data a
  `/roadmap` agent would ever revise with the same kind of judgment it applies to batches.
- Edge writes already have exactly one sanctioned path (`update-task-status.sh preflight <N>
  edge_only <session> --depends-on-add=[M]`, itself a thin wrapper around `state-write.sh`'s
  mutex-guarded write) and `/roadmap`'s batch/priority/description writes should go through
  `state-write.sh` directly — never a new direct writer. The audit-evidence gate in
  `state-write.sh` fires only when a write introduces a **new** `active_projects` entry; a
  `/roadmap` write never does that, so no `--audit-verdict`/`--audit-override` plumbing is
  needed for this command at all.
- Task 313 (the advisory batch-proposal lint) is **completed**, and its own plan and script
  header already name this task's objective (by slug, `roadmap-as-generated-artifact`, not by
  number) as the accepted trigger for its parse layer needing rescoping. That lint's entire
  subject — hand-typed `## Next` Run lines — disappears once batches live in state.json and
  `/roadmap` is the only write path; see Decision 4 for the disposition this report files
  without editing 313 itself.
- `specs/ROADMAP.md` and `specs/TODO.md` are both git-tracked today; TODO.md's generated-and-committed
  precedent settles the open question of whether ROADMAP.md keeps being committed (yes).

## Context & Scope

Researched: the current `specs/ROADMAP.md` generation mechanism end-to-end
(`roadmap-integration.sh`, `roadmap-format.md`, `roadmap-update.md`), the live file's actual
content (to see what the migration must preserve losslessly), `specs/state.json`'s real schema
and its enforcement chain (`state-schema.json`, `validate-state.sh`,
`state-management-schema.md`), the two sanctioned state-mutation paths
(`state-write.sh`, `update-task-status.sh`'s `edge_only` arm), the manifest registration
convention for a new skill/command/agent trio, and the disposition of the one record whose
premise this task changes (task 313's advisory lint).

Out of scope for this research pass (left to planning): the exact jq transform the new
`--regenerate` mode will run, the exact wording of the `/roadmap` agent's system prompt, and the
line-by-line diff of `roadmap-integration.sh` the implementation will produce.

## Findings

### Codebase Patterns

**Current generation split (`roadmap-format.md`, `roadmap-integration.sh`).** The file
recognizes two structural layouts, `classic` (eight literal `## ` headers) and `stage` (a
`## Stage N` header plus a fenced `/orchestrate` block), detected by `detect_layout()` before
either write mode touches the file; an `unknown` vocabulary is refused loudly
(`refuse_unrecognised_layout`), never guessed at — this is documented as a *permanent* property,
not a transitional guard. This repository's live `specs/ROADMAP.md` is `classic`. I found no
live `stage`-layout `ROADMAP.md` anywhere in this tree (the only `## Stage N` hits are unrelated
pipeline-doc headers in other extensions' agent/skill files) — I cannot confirm from this
repository alone whether any consumer repo currently uses the `stage` vocabulary, so I treat the
open question "does the classic/stage duality survive" as unresolved by evidence rather than
settled; see Decision 5.

For the `classic` layout, `roadmap-format.md`'s own Authored-vs-Generated table already
classifies six of eight sections as `authored-verbatim` or `measured-by-hand`, and only `## Next`
and `## Open work` as `generated`/`mixed`. `## Open work`'s per-task overrides
(`task:{N}:description`, `task:{N}:annotation`, `task:{N}:ext-blocked`) and `## Next`'s per-batch
rationale (`next:run:{i}:rationale`, `next:why-this-order`) are recovered by **`parse_retention()`**
(`roadmap-integration.sh:584`) reading the OLD file's body before it is overwritten — this is
"THE RETENTION PARSER" the dispatch names, and it is the piece that becomes dead weight once
those authored values live in `state.json` fields instead of inside the markdown this script is
about to rewrite.

**The live file's actual authored content is dense, not terse.** `specs/ROADMAP.md`'s current
`## Next` section (`specs/ROADMAP.md:101-306`) carries one fenced block of 8 `/orchestrate` lines
(the live batches) followed by a "Why this order:" section of roughly a dozen substantial
paragraphs — multi-sentence reasoning about territory collisions, claimant status, re-measurement
results, and edge rationale, not one-liners. A lossless migration of this prose (an explicit
acceptance criterion) cannot be squeezed into a template that bounds a batch's `description` to
one line; the two needs are served by two different fields (Decision 3).

**`priority` already exists on the task entry, has a real writer, and is not an ordering
signal.** Confirmed live: `priority` is a four-value enum (`critical`/`high`/`medium`/`low`) in
`state-schema.json:302-309`, populated on 15 of 142 `active_projects` entries (not 14 as the
dispatch's own measurement found a day earlier — the count moved by one record in the interim,
consistent with the file's own "re-derive, never remember" standing rule). Its schema comment
says it is "written by `/review`'s severity mapping... absent means unranked, NOT low." The only
script referencing `.priority` anywhere under `agent-system/extensions/core/{scripts,commands,skills,agents}`
is `issue-grouping.sh`, which is about issue-log severity, not task ordering — confirming the
dispatch's claim that no script consumes this field for roadmap ordering today.

**State mutation paths.** `state-write.sh` is the single mutex-guarded writer every other script
in the codebase shares (confirmed via its own header and via `update-task-status.sh`'s comment
"Routed through state-write.sh, the single mutex-guarded specs/state.json writer every other
writer in this codebase shares"). Its audit-evidence gate (`--audit-verdict`/`--audit-override`)
fires **only** when a write's jq transform introduces a genuinely new `active_projects`
`project_number` — "every status update, artifact link, `file_scope` edit, and
non-`active_projects` write... is byte-for-byte unaffected, gate or no gate" (its own header
comment). A `/roadmap` write edits `roadmap_batches` and existing tasks' fields; it creates no
task, so the gate never fires and no audit plumbing is needed.

Edge addition already has exactly one sanctioned arm: `update-task-status.sh preflight <N>
edge_only <session> --depends-on-add=[M]`. `edge_only` is a dedicated, preflight-only target
status invented specifically to let `--depends-on-add` reach a `not_started` task (previously
impossible, since every other status-changing path requires a real lifecycle transition); it
itself calls `state-write.sh` internally (`update-task-status.sh:1117-1162` region shows the
pattern for sibling no-op flag merges). `/roadmap`'s edge-adding judgment should shell out to
this script per task per missing edge; no new edge-writing code is warranted or permitted by the
dispatch.

**Schema/validator enforcement chain.** `state-schema.json` keeps `additionalProperties: false`
at the top level (`:169`) and on `definitions.projectEntry` (`:81`, `:109`, etc.), so a new
top-level `roadmap_batches` key must be added to `properties` there, to
`validate-state.sh`'s hand-copied `KNOWN_TOP_LEVEL_FIELDS`, and documented in
`state-management-schema.md`'s Top-Level Fields table — the same three-places-in-sync pattern
every other top-level field already follows (confirmed by that file's own drift-test note: "the
two **disagreeing on the field set**... remains a real defect, caught by the schema-to-validator
drift test in `scripts/tests/test-validate-state.sh`").

**Registration convention.** `agent-system/extensions/core/manifest.json`'s `provides.agents`,
`provides.commands`, and `provides.skills` are flat filename/dirname lists (confirmed against
the live `spawn-agent.md` / `spawn.md` / `skill-spawn` triple, which is also the closest existing
precedent for a standalone, non-task-type-routed command: `/spawn` is invoked directly, not
through the task-type routing table, exactly as `/roadmap` will be). The command-reference and
skill-to-agent-mapping tables the dispatch asks this task to extend live in
`agent-system/extensions/core/merge-sources/claudemd.md` (the source store for the deployed
`.claude/CLAUDE.md`), per `rules/source-store-deploy-boundary.md` — never edited at the deployed
path directly.

**`specs/ROADMAP.md` and `specs/TODO.md` are both git-tracked** (`git ls-files` confirms both;
`git log` shows real commits touching `specs/TODO.md`, e.g. "task 608: complete implementation").
TODO.md is wholly generated from `state.json` and stays committed; this is the direct precedent
for keeping a generated `specs/ROADMAP.md` committed too.

### External Resources

Not applicable — this is a self-contained codebase convention question with no external
dependency; no web research was performed.

## Decisions

1. **Per-section ruling for the six non-batch `classic` sections: all six stay authored directly
   in the markdown file, unchanged from today's mechanism.**
   - `## Goal` — authored-verbatim. No structured field in this task's scope would let an agent
     meaningfully revise it; it is a standing mission statement, not a measurement or a batch.
   - `## Gate state` — measured-by-hand, **cannot be generated at all** (the dispatch's own
     framing, confirmed by reading the live section: every bullet cites a freshly-run suite
     count, a probe result, or a lock-contention observation — none of it is derivable from
     `state.json`).
   - `## Checks before and after every call` — authored-verbatim; a fixed procedural checklist,
     not task data.
   - `## Settled decisions (do not re-litigate)` — authored-verbatim; owner rulings with no
     per-task or per-batch shape.
   - `## Standing rules` — authored-verbatim; same shape as Settled decisions.
   - `## Unfiled observations (none worth a task yet)` — authored-verbatim; a scratch list of
     observations not yet worth a task, explicitly pre-structured data.
   Only `## Open work` and `## Next` (batches) have the agent-revisable judgment shape this task
   is building `/roadmap` to hold. The GOAL's "wholly generated" framing is read here as "every
   section an agent's judgment can touch is generated, and the rendering path makes no
   judgments" — not as "every byte of the file is derived," which `## Gate state` alone rules
   out. This reading should be confirmed explicitly at plan time rather than assumed silently,
   since it narrows the literal GOAL text.

2. **Keep the existing per-task `priority` field exactly as-is; do not retire it, and do not
   reuse it for batch ordering.** It has a real, documented writer (`/review`'s severity mapping)
   and a real, if underused, semantic (per-task urgency, independent of dependency order — the
   dispatch's own example: "a wave-1 task may be low and a wave-3 task high"). Batch priority is
   a different axis entirely (which *group* runs first), and the natural, zero-new-field carrier
   for it is **the batch's position in the new `roadmap_batches` array** — exactly how the
   current `## Next` fenced block's line order already *is* the de facto priority signal today.
   This avoids manufacturing the "third unused axis" the dispatch warns against.

3. **The batch entry schema needs two authored text fields, not one**, because the dispatch's
   own acceptance criteria pull in two directions: the template wants a one-line, anti-fluff
   `description`, but the lossless-migration criterion requires preserving the live file's
   multi-paragraph "Why this order:" prose verbatim. Recommend:
   - `description` (string, required): one line, rendered under the batch's `/orchestrate` line
     comment (mirrors today's trailing `# {rationale}` on a Run line) — bounded the same way
     `## Open work`'s task lines are bounded (100 rendered characters total), per the dispatch's
     own instruction to reuse that discipline rather than inventing a second one.
   - `rationale` (string, optional, unbounded): the full authored prose, rendered verbatim under
     "Why this order:" exactly where it is today — this is the direct, lossless successor to
     `next:run:{i}:rationale`/`next:why-this-order`, now a first-class field instead of something
     recovered by parsing the file being overwritten.
   A worked compliant/non-compliant pair for `description` belongs in the template (planning
   deliverable, not written here): compliant — "Make the roadmap generated and close its two
   measured fillers"; non-compliant — a sentence that restates each member task's own title
   ("Fixes the roadmap, the suggester, the ceiling, and sapience retries").

4. **Task 313's disposition: superseded in its parsing mechanism, not merely narrowed, once this
   task lands — filed here per the dispatch's instruction, 313 left untouched.** 313 is
   `[COMPLETED]`. Its own plan's Risk table already named this exact outcome ("Record 603
   retires the `## Next` prose grammar this lint parses", Impact H / Likelihood M, "Accepted by
   the user's recorded decision") and its shipped script header (`lint-roadmap-batch-proposals.sh:74-79`)
   already states: "the task record `roadmap-as-generated-artifact`... will move batch membership
   out of this file's hand-authored `## Next` prose into state.json entries... When that lands,
   this script's entire parse layer... needs rescoping against the new source of truth." Once
   `/roadmap` is the only write path for batches, there is no more hand-typed `## Next` prose for
   this lint to validate — its subject matter (findings a/c/d/f, all keyed off parsing authored
   Run lines) disappears, not merely shrinks. This is a full supersession of the lint's parse
   layer, consistent with what its own authors foresaw and explicitly accepted as a follow-up
   cost; the owner of 313 should file the rescoping (or retirement) as its own task once this one
   lands, which is exactly the disposition the dispatch asked this report to record rather than
   act on.

5. **The classic/stage layout duality: insufficient evidence in this repository to settle it;
   recommend the planning phase ask the operator rather than assume.** This repository's live
   file is `classic`, and I found no live `stage`-layout roadmap anywhere in this tree to test
   the migration against. If the `stage` layout exists only in other consumer repositories not
   visible here, the safest planning posture is to keep both layouts recognized (preserving the
   Destructive-Overwrite Refusal's two-vocabulary acceptance set) but implement the state.json-backed
   batch rendering as the *only* generation strategy for `## Next`'s run-order section/coverage
   appendix under both layouts — i.e., collapse the generation logic, not the detection logic.
   This is a recommendation, not a settled ruling; it was not possible to validate against a real
   `stage`-layout file in this research pass.

6. **`/roadmap` writes go through `state-write.sh` directly for batch/priority/description
   fields, and through `update-task-status.sh preflight <N> edge_only ... --depends-on-add=[M]`
   for edges — never a new writer for either.** This directly answers the dispatch's third open
   question and is not a judgment call: it is the only path every other state mutation in this
   codebase already uses, and the audit-evidence gate cited as a possible objection does not
   apply (Decision 2 of the Findings section above; the gate fires only on new `active_projects`
   entries, which `/roadmap` never creates).

## Recommendations

- **Schema**: add a top-level `roadmap_batches` array to `state.json` (sibling to
  `active_projects`/`active_topics`), each entry: `task_ids` (array of existing `project_number`
  values), `description` (string, ≤100 rendered chars, required), `rationale` (string, optional,
  unbounded, authored), `flags` (string, optional, e.g. `"--hard"` or `"--hard --lit"`). Document
  in `state-management-schema.md`'s Top-Level Fields table; model in `state-schema.json`
  (`properties` + the top-level `additionalProperties: false` block); add to
  `validate-state.sh`'s `KNOWN_TOP_LEVEL_FIELDS` plus a new check validating every `task_ids`
  member exists, is non-terminal, and appears in at most one batch (no task silently duplicated
  across two batches).
- **Template**: a new `context/formats/` (or an addition to `roadmap-format.md`) spec for the
  rendered batch block and the entry shape together, with the 100-char bound stated explicitly
  and the compliant/non-compliant pair from Decision 3 above worked out in full.
- **Command/skill/agent**: `/roadmap [instruction]`, `skill-roadmap`,
  `roadmap-agent` (a judgment-bearing agent in the shape of `reviser-agent` — revises a
  structured artifact against an optional free-form instruction — rather than the
  thin-direct-execution shape of `skill-spawn`). No-argument invocation performs a full
  maintenance pass (clear cruft that can no longer accumulate once the file is generated from
  live state, revise priorities via batch reordering, revise descriptions, judge missing edges);
  an instruction argument scopes the same judgment to a stated focus. Register all three in
  `manifest.json`'s `provides.{agents,commands,skills}` lists per the `spawn`-trio precedent, and
  add the command-reference and skill-to-agent-mapping rows to
  `merge-sources/claudemd.md` (never the deployed `.claude/CLAUDE.md`), per
  `rules/source-store-deploy-boundary.md`.
- **Generator**: extend `roadmap-integration.sh`'s `--regenerate`/`--prune` to read
  `roadmap_batches` instead of running `parse_retention()`'s Next-side extraction; retire that
  extraction once the migration (next bullet) has run. Open-work's existing
  `task:{N}:description`/`annotation`/`ext-blocked` retention is a separate, already-working
  mechanism this task does not need to touch (the dispatch scopes the inversion to batches, and
  `## Open work`'s overrides are not the obligation 313 and the dispatch both call out).
- **Migration**: a one-time script (or a documented manual step, run once) that reads the
  current `specs/ROADMAP.md`'s `## Next` fenced block and "Why this order:" bullets and writes
  one `roadmap_batches` entry per Run line, splitting each paragraph of rationale onto its
  matching batch by position — this is the "read the current file once and seed the state.json
  entries from it" step the dispatch requires as part of this task, not a follow-up.
- **313's follow-up**: do not edit 313. Record (as done in Decision 4 above) that its parse layer
  is superseded by this task's landing, and leave the rescoping/retirement decision to a
  separately filed task against 313's own named follow-up risk.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| "Wholly generated" (GOAL text) is read too literally at plan time, scoping in `## Gate state` or other measured-by-hand prose that cannot actually be derived | State the narrower reading explicitly in the plan's Overview, citing Decision 1 above, before any phase touches those sections |
| A duplicated priority axis re-emerges if `roadmap_batches` ordering and the per-task `priority` enum are conflated during implementation | Decision 2 is explicit: never read `.priority` for batch order; batch order is array position only |
| Lossless-migration acceptance criterion is checked only by eyeballing, and a paragraph gets silently dropped or merged with its neighbor | The migration step should diff paragraph count before/after against the live file's "Why this order:" bullet count (a dozen, per this research pass) and fail loudly on a mismatch, not just report success |
| The `stage` layout is live in some other consumer repo this research could not see, and the new generation logic breaks it silently | Decision 5: keep the layout detection split, collapse only the rendering strategy; flag this explicitly for the operator at plan time rather than assuming `classic`-only is safe |
| A new top-level `roadmap_batches` key is added to `state-schema.json`/`validate-state.sh` out of sync (one updated, the other not) | The existing schema-to-validator drift test (`scripts/tests/test-validate-state.sh`) already catches this class of defect; run it as part of this task's own verification, not as an assumed pass |

## Context Extension Recommendations

- **Topic**: `state-management-schema.md`'s "Project Entry Fields" table currently omits
  `priority` even though it is modelled in `state-schema.json` and known to `validate-state.sh`
  (confirmed: three independent references in the validator, zero in that table).
- **Gap**: a reader consulting only `state-management-schema.md` (the documented, human-facing
  reference) would not learn that `priority` exists at all — it is schema/validator-only
  documentation today.
- **Recommendation**: add a `priority` row to the Project Entry Fields table (not part of this
  task's required scope, but a cheap, directly-adjacent fix worth doing in the same phase that
  adds `roadmap_batches`' own field documentation to that same table).

## Appendix

- Search/inspection commands used: `grep -n` over `roadmap-integration.sh`,
  `roadmap-format.md`, `roadmap-update.md`, `state-management-schema.md`, `state-schema.json`,
  `validate-state.sh`, `update-task-status.sh`, `state-write.sh`, `manifest.json`
  (via `python3 -c` JSON introspection); `git ls-files`/`git log` for the TODO.md/ROADMAP.md
  tracked-and-committed precedent; a repo-wide `grep -rln '## Stage [0-9]'` to probe for a live
  `stage`-layout roadmap (none found; all hits were unrelated agent/skill doc headers).
- Key files read in full or near-full: `.claude/context/formats/roadmap-format.md`,
  `.claude/context/patterns/roadmap-update.md`, `specs/ROADMAP.md` (entire live file),
  task 313's plan (`specs/313_advisory_lint_for_roadmap_batch_proposals/plans/01_roadmap-batch-proposal-lint.md`),
  `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` (header/comments).
- Not read in full (budget): `roadmap-integration.sh`'s full 1029-line body (read via targeted
  `grep -n` function-index and the `parse_retention`/`assemble_roadmap` region only);
  `validate-state.sh`'s full 1596-line body (read via targeted grep for `priority`/check
  numbering only). A planning-phase pass should read `roadmap-integration.sh`'s
  `mode_regenerate_classic`/`mode_prune` bodies in full before writing the implementation phases.
