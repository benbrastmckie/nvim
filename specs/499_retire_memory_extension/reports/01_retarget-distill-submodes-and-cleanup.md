# Research Report: Task #499

**Task**: 499 - Retarget the store-coupled distill sub-modes and retire the memory extension (this dispatch covers Parts A, B, C, C2 only; Part D is out of scope per the SCOPE NARROWING section)
**Started**: 2026-11-10T19:30:00Z
**Completed**: 2026-11-10T20:10:00Z
**Effort**: large (touches 2 sub-mode specs, 6 deletions, 3 core callers, ~25 extension call sites, 1 new write-path wiring decision)
**Dependencies**: Task 496 (COMPLETED - sapience per-repo storage/injection), Task 497 (COMPLETED - telemetry sub-mode relocation)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/memory/**`, `agent-system/extensions/core/scripts/*.sh`, `agent-system/extensions/core/skills/skill-todo/SKILL.md`, `agent-system/extensions/sapience/**`
- `specs/TODO.md` entries for tasks 496, 497, 498, 499, 421
- `measure-eager-context.sh --check` live run (baseline measurement)
- Grep sweep across all 25+ extensions for `memory-retrieve.sh` / `memory-harvest.sh` references
**Artifacts**:
- This report: `specs/499_retire_memory_extension/reports/01_retarget-distill-submodes-and-cleanup.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Correction to the dispatch's stated premise**: `memory-retrieve.sh` is NOT already dead. Task
  496 swapped only the single call site inside `orchestrate-build-dispatch.sh`'s Stage 3.5 (core
  task types: general/meta/markdown). **25 live call sites across 12 extensions'
  research/implementation `SKILL.md` files** (python, web, cslib [x2 skill pairs], latex,
  epidemiology, email, z3, nvim, nix, rust, books, typst) each carry their own inline Stage 4a
  block that still calls `bash .claude/scripts/memory-retrieve.sh` directly, independent of the
  orchestrate-build-dispatch.sh call site. Part C's verification bullet ("no remaining reference
  anywhere in the source store points at... memory-retrieve.sh") cannot be satisfied by deleting
  the core script alone — every one of these 25 sites needs updating too.
- The fix is mechanical and low-risk: `sapience-retrieve.sh` has the **identical CLI signature**
  (`<description> <task_type> [focus_prompt]`) and emits the **identical `<memory-context>`
  envelope** as `memory-retrieve.sh` — it is a drop-in replacement, confirmed by reading both
  scripts. A find/replace of the script name (and the `.claude/scripts/` path, which is
  unchanged) across the 25 sites is sufficient; no caller-side logic changes.
- `memory-harvest.sh` is genuinely dead (its own header says so; grep confirms zero live callers)
  and can be deleted outright.
- `skill-todo/SKILL.md`'s HarvestMemories (Stage 7) + CreateMemories (Stage 14) write new
  `.memory/10-Memories/MEM-*.md` files and regenerate local indices at archival time. This
  live-time harvest is now fully redundant with `/distill --learn`'s retargeted retroactive sweep
  (Part A) once that sweep points at the hosted store: any task archived without harvesting
  simply falls into `--learn`'s existing "unharvested candidates" net. **Removing** the stage
  (rather than retargeting it to write per-task) avoids a bulk-write volume risk at archival time
  (`/todo` commonly archives many tasks per run; writing 3-8 permanent, unreviewed KOs per
  archived task per run could spike well past the stated per-task bound in a single invocation).
- Both `--revise` and `--learn` are internally coherent to retarget: their event/OTel ingestion,
  three-strikes threshold, and interactive-gate logic are store-agnostic already — only the
  terminal write operation changes from local `.md` file UPDATE/TOMBSTONE/CREATE to a
  `sapience-remember.sh` call. The one substantive design gap: `--revise`'s CONTRADICTED
  classification currently *tombstones or updates* a local record; against a no-delete-API store
  neither operation exists, so both collapse to "write one superseding note."
- Part B's six-way deletion is not a clean six-section removal: the Scoring Engine's composite
  score / health_score formula is still needed by the surviving `auto` sub-mode (it recalculates
  and writes `health_score` to `state.json`), while the Health Report Template and Maintenance
  Candidate Classification table exist only to serve the six sub-modes being deleted. The plan
  phase needs to prune surgically, not delete the whole "Scoring Engine" section.
- Part C2's shape (a) (amend `EXTENSION.md`'s wrapup instruction) is size-constrained: the eager
  context budget is measured live at 68606 bytes / 17151 tokens (`measure-eager-context.sh
  --check`, CHECK PASSED against the current baseline), and the dispatch states this is already
  over its recorded baseline — any `EXTENSION.md` growth must be offset or the net change must be
  size-neutral.

## Context & Scope

This dispatch researches Parts A, B, C, and C2 of task 499 as scoped by the dispatch's own
SCOPE NARROWING section, which overrides Part D: the memory extension remains installed and
registered; `.claude-extensions.json` is untouched; only files *inside*
`agent-system/extensions/memory/**` and the three named core callers are in scope for removal or
retargeting, plus the sapience-side write-wiring in Part C2.

Research covered: the current `skill-distill/SKILL.md` and its nine sub-mode specs (seven inline
+ five extracted pattern files), the three core callers named in Part C, the sapience extension's
retrieval/write scripts and their documentation, the orchestrate dispatch and postflight scripts
touching the memory/sapience context-injection pipeline, and a repo-wide grep for every reference
to the two core scripts slated for removal.

## Findings

### Codebase Patterns

**Current sub-mode inventory** (`skill-distill/SKILL.md`, post-task-497 relocation): 9 sub-modes
remain — `report`, `purge`, `merge`, `compress`, `refine`, `gc`, `auto`, `revise`, `learn`.
(`--meta`, `--review`, `--dream` already moved to core's `/telemetry` in task 497 and are out of
this task's scope entirely.) Five of the nine have extracted pattern files under
`agent-system/extensions/memory/context/project/memory/patterns/`: `distill-purge-submode.md`,
`distill-merge-submode.md`, `distill-compress-submode.md`, `distill-refine-submode.md`,
`distill-revise-submode.md`, `distill-learn-submode.md` (six files; `gc` and `auto` stay inline
in `SKILL.md`). The `/distill` command file (`commands/distill.md`) parses all nine flags into a
`sub_mode` variable and documents a "Section" anchor table for each.

**`--revise` (distill-revise-submode.md, 301 lines)**: reads `events-query.sh` exclusively
(summary-counts gate, then category=deviation/blocker, then event-type=reflection), optionally
joins OTel by `cc_session_id` when `CLAUDE_CODE_ENABLE_TELEMETRY=1`, classifies each
evidence-correlated memory as corroborated/contradicted/gap under a three-strikes recurrence
threshold, and on CONTRADICTED presents `AskUserQuestion` with UPDATE (rewrite body, old content
to `## History`) / TOMBSTONE (`tombstone_reason: "revise_superseded"`) / SKIP. On Gap it offers
CREATE (new local memory) or escalation to an Improvement Proposal (`--meta`, already relocated).
The degraded paths for `total_events: 0` and OTel-absent are already explicit, first-class, and
narrated (not silent) in the current spec — this already satisfies the dispatch's "must announce
explicitly" requirement; the only work is making the terminal write hosted-store-shaped.

**`--learn` (distill-learn-submode.md, 137 lines)**: scans `specs/archive/`/vaulted tasks for
`memory_candidates` with no recorded harvest, sources from transcript (30-day window) or
`history.jsonl` + archived specs artifacts (beyond that window), presents
TECHNIQUE/PATTERN/CONFIG/WORKFLOW/INSIGHT/SKIP classification via `AskUserQuestion` grouped by
task, then applies `/learn`'s own UPDATE/EXTEND/CREATE mechanics. Logs to its own
`.memory/learn-harvest-log.json`. This sub-mode's entire reason for existing — a second-chance
sweep over tasks whose candidates were "declined, skipped, or predate the harvest mechanism" — is
exactly the backstop that makes removing `skill-todo`'s live-time HarvestMemories stage safe (see
below): nothing is permanently lost, it just moves from "harvested at archival time" to
"harvested on `--learn`'s next retroactive pass."

**Scoring Engine / Health Report coupling (SKILL.md lines 47-276)**: the composite score
(staleness 0.3 + zero_retrieval 0.25 + size_penalty 0.2 + duplicate 0.25) feeds three consumers:
(1) the Health Report Template (`report` sub-mode, deleted), (2) the Maintenance Candidate
Classification table that `purge`/`merge`/`compress`/`refine` read their thresholds from (all
four deleted), and (3) `health_score`, which `auto` (NOT deleted) recalculates and writes to
`state.json`'s `memory_health` field every run. Deleting the six sub-modes therefore cannot be a
clean removal of six self-contained sections — the composite-score formula and `health_score`
calculation must be *retained* (consumed by `auto`), while the Health Report Template and
Maintenance Candidate Classification table (consumed only by the six being deleted) can go.

**`memory-retrieve.sh` reference sweep (Part C)** — the dispatch's claim under SCOPE NARROWING
("`memory-retrieve.sh` is already dead regardless of Part D: its sole dispatch call site was
swapped") is incomplete. Confirmed by direct grep across `agent-system/`:

| Call-site category | Count | Already migrated? |
|---|---|---|
| `orchestrate-build-dispatch.sh` Stage 3.5 (core task types: general/meta/markdown/etc. via `/orchestrate`) | 1 | Yes — calls `sapience-retrieve.sh` (task 496) |
| Per-extension research/implementation `SKILL.md` inline Stage 4a blocks | 25 | **No — all 25 still call `memory-retrieve.sh` directly** |

The 25 live sites, by extension (file path, line):
`python/skills/skill-python-implementation/SKILL.md:41`,
`python/skills/skill-python-research/SKILL.md:41`,
`web/skills/skill-web-implementation/SKILL.md:100`,
`web/skills/skill-web-research/SKILL.md:80`,
`cslib/skills/skill-cslib-research/SKILL.md:59`,
`cslib/skills/skill-pr-review-research/SKILL.md:137`,
`cslib/skills/skill-cslib-implementation/SKILL.md:71`,
`cslib/skills/skill-pr-review-implementation/SKILL.md:163`,
`latex/skills/skill-latex-implementation/SKILL.md:41`,
`latex/skills/skill-latex-research/SKILL.md:41`,
`epidemiology/skills/skill-epi-implement/SKILL.md:103`,
`epidemiology/skills/skill-epi-research/SKILL.md:102`,
`email/skills/skill-email-implementation/SKILL.md:57`,
`z3/skills/skill-z3-research/SKILL.md:41`,
`z3/skills/skill-z3-implementation/SKILL.md:41`,
`nvim/skills/skill-neovim-implementation/SKILL.md:44`,
`nvim/skills/skill-neovim-research/SKILL.md:44`,
`nix/skills/skill-nix-implementation/SKILL.md:44`,
`nix/skills/skill-nix-research/SKILL.md:44`,
`rust/skills/skill-rust-research/SKILL.md:41`,
`rust/skills/skill-rust-implementation/SKILL.md:41`,
`books/skills/skill-books-research/SKILL.md:41`,
`books/skills/skill-books-implementation/SKILL.md:45`,
`typst/skills/skill-typst-implementation/SKILL.md:41`,
`typst/skills/skill-typst-research/SKILL.md:41`.

All 25 follow the identical idiom: `memory_context=$(bash .claude/scripts/memory-retrieve.sh
"$description" "$task_type" ["$focus_prompt"|""] 2>/dev/null) || memory_context=""`, gated by
`if [ "$clean_flag" != "true" ]`. Confirmed by reading `sapience-retrieve.sh` directly: it takes
the **same three positional arguments** (`<description> <task_type> [focus_prompt]`), applies the
**same keyword-extraction stage verbatim** ("copied rather than reinvented" per its own header
comment), and emits the **same `<memory-context>` envelope**. The deployed path
(`.claude/scripts/`) is unchanged — both scripts deploy to the same directory name. This means
each of the 25 call sites needs only its script-name token changed, not its surrounding bash
logic, error-swallowing, or `clean_flag` gating.

Also found (not live call sites, documentation/comment-only, no code change needed but worth the
plan phase's awareness when doing the final "no remaining reference" sweep): `core/manifest.json`
(installed_files entry), `core/README.md`, `core/context/patterns/skill-lifecycle.md` (Stage 4a
table row), `core/context/patterns/context-protective-lead.md` (two mentions),
`core/context/standards/telemetry-guardrails.md`, `core/context/meta/meta-guide.md` (two
mentions), `email/context/project/email/design/email-to-memory-preferences.md` (several
mentions, rationale-level, in the email-side substrate being handled by the paused task 498),
`memory/EXTENSION.md`, `memory/README.md`, `memory/skills/skill-learn/README.md`,
`memory/skills/skill-distill/SKILL.md` (comment). All of these are prose references that will
also need updating or removing for the "no remaining reference" verification bullet to be
literally true, though they are lower-risk than the 25 executable call sites.

**`memory-harvest.sh` reference sweep** — genuinely dead. Its own header states: "this script is
presently uncalled (no caller in the skill/command pipeline). `memory_candidates` is consumed via
skill-todo's inline harvest logic (HarvestMemories stage), not via this script." Grep confirms:
the only non-comment, non-doc hits are self-references inside the script and its own usage
string; `sweep-invalidated-claims.sh` mentions it only in a comment describing a *potential*
future caller, never an actual invocation; `task-reference-exemptions.md` and
`shell-script-testing.md` mention it descriptively. Safe to delete with no caller-side follow-up
required (beyond the manifest entry and prose mentions).

**`skill-todo/SKILL.md` HarvestMemories/CreateMemories (Part C)** — Stage 7 ("HarvestMemories")
reads `memory_candidates` from each archived task's `state.json` entry, dedupes by keyword
overlap against `.memory/memory-index.json`, classifies into a three-tier
pre-selected/shown/hidden scheme, and surfaces via `AskUserQuestion` at Stage 9. Stage 14
("CreateMemories") then, for each user-approved candidate, writes a new
`.memory/10-Memories/MEM-{slug}.md` file from `.memory/30-Templates/memory-template.md` and
batch-regenerates `memory-index.json`, `index.md`, and `.memory/10-Memories/README.md`. This is
exactly the kind of local-vault write the hard sequencing constraint says must not happen going
forward as part of a store this task is migrating away from. Two retargeting options exist:

1. **Retarget**: call `sapience-remember.sh` per approved candidate instead of writing a local
   `.md` file. Risk: `/todo` archives a *batch* of tasks per invocation (TODO.md shows single
   runs archiving dozens), so a straightforward per-candidate retarget could produce far more
   than the stated 3-8-notes-per-completed-task bound in one `/todo` invocation, writing
   permanent, unreviewed KOs at a volume the sapience documentation explicitly warns against.
2. **Remove**: drop Stage 7/14 entirely. Every task's candidates that would have been harvested
   here simply remain unharvested at archival time and are picked up later by `--learn`'s
   existing retroactive sweep (Part A, already retargeted to the hosted store) on its own
   maintenance cadence — the sweep's whole design purpose is exactly this case ("declined,
   skipped, or predate the harvest mechanism"). No candidate is lost; it is deferred to a path
   that already has the volume-bounding conversation built into Part A/C2's design.

Option 2 appears lower-risk and requires no new bound-enforcement logic, since it reuses
machinery Part A is already retargeting; option 1 requires solving the same bound problem Part C2
flags as "load-bearing" a second time, independently, inside `skill-todo`. This report does not
rule definitively — the dispatch says "retarget... or remove it," leaving the choice open — but
flags Option 2 as the lower-risk reading of the evidence gathered.

**Part C2 — tagged-write wiring (verified, not re-derived)**:
- `orchestrate-build-dispatch.sh:355` already calls `sapience-retrieve.sh "$description"
  "$task_type" "$memory_arg3" 2>/dev/null || memory_context=""` — the retrieval half of the loop
  is confirmed live and already failure-degrading, satisfying that verification bullet without
  further work.
- `orchestrate-cycle-postflight.sh` has **no sapience/MCP call of any kind** (confirmed by grep)
  and does detect the `[IMPLEMENTING] -> [COMPLETED]` transition at a concrete point (around line
  2158: `if [ "$fresh_status" = "completed" ]; then ...`), which is the natural shape-(b) call
  site if that shape is chosen. `sapience_wrapup` itself is an MCP tool invokable only by the
  agent process, not by a bash script — `EXTENSION.md`'s existing "Postflight wrapup" paragraph is
  literally an instruction to the *agent*, not a script call, which is consistent with shape (a)
  being the natural fit (amend the agent-facing prose so the same agent moment also shells out to
  `sapience-remember.sh`) versus shape (b) requiring the orchestrator's own postflight script to
  independently synthesize note content without an agent in the loop to compose it.
- `measure-eager-context.sh --check` run live against this repo today: `TOTAL: 68606 B (17151
  tokens est.)`, `CHECK PASSED: no volatile-file hits`. This is the number the plan phase should
  re-run against after any `EXTENSION.md` edit to confirm size-neutrality, per the dispatch's hard
  constraint.
- `per-repo-scoping.md` (78 lines) already documents the full mechanism, both scripts, and the
  hazards narrative in detail — it has room to absorb any additional wiring-rationale prose moved
  out of `EXTENSION.md` to keep that file size-neutral, exactly as the dispatch directs.

### External Resources

Not applicable — this is a pure in-repo architectural migration; no external library/API research
was needed. All findings above were confirmed by direct file reads and grep against the live
source store, not from documentation or memory alone.

## Decisions

- Confirmed via direct script comparison that `sapience-retrieve.sh` is a true drop-in
  replacement for `memory-retrieve.sh` at the 25 extension call sites (identical signature,
  identical output envelope, identical deployed path) — the plan phase can treat this as a
  mechanical rename, not a logic change, at each site.
- Treated the dispatch's "memory-retrieve.sh is already dead" statement as refuted by direct
  evidence (25 live call sites found) rather than re-asserted; this report does not silently
  accept a premise contradicted by what was actually read.
- Did not choose between skill-todo's "retarget" vs. "remove" options for HarvestMemories/
  CreateMemories — left as an open decision for the plan phase, with Option 2 (remove) flagged as
  the lower-risk reading given the volume-bound hazard and the fact that `--learn`'s retroactive
  sweep already exists as a backstop.
- Did not choose between Part C2's shape (a) vs (b) — both remain plan-phase decisions per the
  dispatch's own instruction ("the plan phase chooses ONE and records why"); this report supplies
  the evidence (no existing postflight sapience call, the `completed` transition detection point,
  measured eager-budget baseline) needed to make that choice informed rather than re-deriving it.

## Recommendations

1. **Widen the Part C file-touch set beyond the three named callers** to include all 25 extension
   `SKILL.md` Stage 4a call sites (listed above under Findings) plus the documentation-only
   mentions in `core/manifest.json`, `core/README.md`, `core/context/patterns/skill-lifecycle.md`,
   `core/context/patterns/context-protective-lead.md`, `core/context/standards/
   telemetry-guardrails.md`, `core/context/meta/meta-guide.md`, and the memory extension's own
   `EXTENSION.md`/`README.md`/`skill-learn/README.md`/`skill-distill/SKILL.md` comment — without
   this, Part C's "no remaining reference anywhere in the source store" verification bullet will
   fail on the first grep sweep at verification time. The fix at each of the 25 live sites is a
   one-line script-name substitution (`memory-retrieve.sh` -> `sapience-retrieve.sh`), not a
   redesign.
2. **Delete `memory-harvest.sh` outright** with no caller-side follow-up beyond its manifest entry
   and prose mentions — confirmed dead, matching the dispatch's framing exactly.
3. **Prefer removing `skill-todo`'s HarvestMemories (Stage 7) + CreateMemories (Stage 14) stages**
   over retargeting them to per-candidate `sapience-remember.sh` writes, specifically because
   `--learn`'s retroactive sweep (once retargeted in Part A) already exists as a complete,
   volume-bounded backstop for exactly the candidates these stages would otherwise harvest at
   archival time — removing avoids introducing a second, independent bulk-write-volume problem
   that Part C2 already treats as load-bearing once.
4. **Treat Part B's six-way deletion as a scoring-engine prune, not six independent section
   deletions**: retain the composite-score formula and `health_score` calculation (consumed by
   the surviving `auto` sub-mode), delete the Health Report Template and Maintenance Candidate
   Classification table (consumed only by the six sub-modes being removed), and update the
   `/distill` command file's sub-mode table and the memory extension's `index-entries.json`
   accordingly.
5. **For `--revise`'s CONTRADICTED handling**, retarget both the UPDATE and TOMBSTONE branches to
   a single "write one superseding note via `sapience-remember.sh`" operation — carrying the old
   guidance's `## History` content and the new corrected guidance into the note body — since
   neither a rewrite-in-place nor a tombstone exists against a no-delete-API store, and the
   dispatch itself anticipates this exact collapse ("most likely writing a superseding note").
6. **For Part C2, re-run `measure-eager-context.sh --check` before and after** any `EXTENSION.md`
   edit, using today's measured baseline (68606 B / 17151 tokens) as the pre-edit number to diff
   against, and move any new wiring-rationale prose into `per-repo-scoping.md` (not eager-loaded)
   rather than growing `EXTENSION.md`'s own paragraph.

## Risks & Mitigations

- **Risk**: deleting `memory-retrieve.sh` without updating the 25 extension call sites would
  break memory-context injection for every non-core task type (python, web, cslib, latex,
  epidemiology, email, z3, nvim, nix, rust, books, typst) at their next research/implement
  dispatch. **Mitigation**: treat the 25-site update as mandatory, in-scope work for this task's
  Part C (not a follow-on), since Part C's own verification bullet already requires it to be
  true; the fix is mechanical (confirmed drop-in-compatible script).
- **Risk**: retargeting `skill-todo`'s HarvestMemories to write per-candidate against a
  no-delete-API, unreviewed-write store could silently exceed the per-task write bound across a
  multi-task archival batch. **Mitigation**: prefer removal (Recommendation 3) and rely on
  `--learn`'s existing, already-bound retroactive sweep instead of inventing a second bound
  mechanism.
- **Risk**: pruning the Scoring Engine section incompletely (e.g. deleting the whole section
  instead of just the Health Report Template / Classification table) would silently break
  `auto`'s `health_score` recalculation, which is NOT being deleted. **Mitigation**: explicit
  dependency note recorded above; plan phase should verify `auto`'s Auto Log Entry and State
  Integration table still resolve after the prune.
- **Risk**: `EXTENSION.md`'s Part C2 edit could push the eager-load budget further over its
  recorded baseline if not checked. **Mitigation**: the exact pre-edit baseline is now measured
  and recorded above (68606 B / 17151 tokens); re-run the same `--check` invocation post-edit
  before considering Part C2 done.

## Context Extension Recommendations

- **Topic**: per-extension Stage 4a memory-retrieval call sites.
- **Gap**: `skill-lifecycle.md`'s Stage 4a row documents `memory-retrieve.sh` as *the* mechanism,
  without noting that core task types and extension task types reach memory context through two
  independently-maintained paths (the shared `orchestrate-build-dispatch.sh` builder vs. each
  extension's own inline Stage 4a block). This split was not obvious from existing context and
  cost a full grep sweep to discover; a future caller-count change (e.g. retiring
  `sapience-retrieve.sh` itself, or adding a third retrieval source) would hit the same discovery
  cost again.
- **Recommendation**: after this task's Part C work lands, update `skill-lifecycle.md`'s Stage 4a
  row (or add a short note) stating explicitly that the call site is duplicated once per
  extension skill rather than centralized, so a future search for "every place memory context is
  injected" does not need to re-derive this from a repo-wide grep.

## Appendix

### Search queries / commands used

- `jq '.extensions.memory, .extensions.core, .extensions.sapience' .claude-extensions.json`
- `find agent-system/extensions/memory -maxdepth 4 -type f`
- `grep -rn "memory-retrieve.sh" agent-system/ --include="*.sh" --include="*.md" --include="*.json"`
- `grep -rn "memory-harvest.sh" agent-system/ --include="*.sh" --include="*.md" --include="*.json"`
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
- `grep -n "IMPLEMENTING\|COMPLETED\|wrapup\|sapience" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `grep -n "memory_context\|sapience-retrieve\|clean_flag" agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
- `grep -n "HarvestMemories\|memory_candidates\|memory-harvest\|Harvest" agent-system/extensions/core/skills/skill-todo/SKILL.md`

### Files read in full or substantially

- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` (811 lines, full)
- `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md` (full)
- `agent-system/extensions/memory/context/project/memory/patterns/distill-learn-submode.md` (full)
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` (full)
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` (full)
- `agent-system/extensions/sapience/EXTENSION.md` (full)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` (full)
- `agent-system/extensions/core/scripts/memory-retrieve.sh` (header + Phase 0/1)
- `agent-system/extensions/core/scripts/memory-harvest.sh` (header)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (Stages 7-9, 14)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (transition-detection region)
- `specs/TODO.md` entries for tasks 496, 497, 498, 499
- `agent-system/extensions/core/context/formats/report-format.md` (headings contract)

### Related records

- Task 496 (COMPLETED): built `sapience-retrieve.sh`/`sapience-remember.sh` and swapped the
  `orchestrate-build-dispatch.sh` call site.
- Task 497 (COMPLETED): relocated `--meta`/`--review`/`--dream` out of the memory extension into
  core; established the pattern this task's Part A follows for `--revise`/`--learn`.
- Task 498 (HOLD): the email preference-harvest tally substrate port, which gates Part D only;
  does not block this dispatch's Parts A/B/C/C2.
- Task 421 (`retarget_distill_meta_as_evidence_consumer`, NOT STARTED): `superset-of-open`
  relation noted in the dispatch; not independently re-verified here since it concerns `--meta`
  (already relocated under 497), outside this task's remaining scope.
