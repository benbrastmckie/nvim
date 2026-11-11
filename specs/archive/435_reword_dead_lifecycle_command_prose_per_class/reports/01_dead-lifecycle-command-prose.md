# Research Report: Task #435

**Task**: 435 - Reword, per class and per site, the architectural and phase-versus-command prose naming the three deleted lifecycle commands, with a blanket find-and-replace explicitly forbidden
**Started**: 2026-11-07T20:22:00Z
**Completed**: 2026-11-07T21:10:00Z
**Effort**: medium
**Dependencies**: Task 434 (companion lint; completed), Task 407 (artifact-round derivation; completed) — both resolved, no longer blocking
**Sources/Inputs**: Codebase exploration (`agent-system/extensions/**`), live grep re-measurement, archived task 407/434 artifacts, live script inspection (`orchestrate-stage5-postflight.sh`, `skill-base.sh`), the deployed `check-record-versioning.sh` gate run against two candidate files
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both declared dependencies are terminal and resolved favorably: task 434 (completed) already
  retargeted the 187-ish literal `Next:`/`Run` recommendation lines onto `/orchestrate` and wired
  gate 24 (`lint-dead-command-recommendations.sh`, now green with 0 violations over the whole
  corpus); task 407 (completed) changed `skill_read_artifact_number()`'s *read*-side resolution to
  `max(stored next_artifact_number, highest on-disk MM prefix + 1)` but did **not** change *who*
  advances the counter. This task can proceed with no open question against either dependency.
- **Re-measured remaining scope (2026-11-07, after 434 and the 2026-11-03 `core/docs/` exclusion,
  using a boundary-aware regex that excludes `plans`/`planner`/`planned`/`implementation`/
  `researcher`-style suffix false-positives and `plan-format.md`-style filename false-positives)**:
  **223 files, 948 occurrences** of `/implement` (172 files/377), `/research` (161 files/317)
  and `/plan` (127 files/254) combined — materially lower than the dispatch's
  quoted pre-434, pre-exclusion "~1,440" figure. `core` alone carries 106 files / 477 occurrences,
  heavily concentrated in `core/context/` (65 files / 352 occurrences — the single largest
  concentration by a wide margin). The other 18 extensions carry 117 files / ~471 occurrences,
  led by `founder` (33 files), `present` (19) and `cslib` (11); several extensions in the
  dispatch's "21 other extensions" figure now carry only 1-3 hit files each.
- **The two revise.md incidental findings are fully resolved by direct inspection — concrete fix
  text is below, not left to the plan to re-derive**:
  1. Line 145 (class-1 worked example, as the dispatch specified): `unlike /research/plan/implement, /revise has no terminal-status ABORT` -> `unlike a research/plan/implement dispatch, /revise has no terminal-status ABORT`. Verified still true: `/orchestrate`'s terminal-status gate (`is_terminal_status()` in `orchestrate-cycle-plan.sh`) still blocks an unforced dispatch on a terminal task, exactly as before the three commands were deleted; `/revise`'s GATE IN exemption is unchanged. No substantive claim changes, only the command-name token.
  2. Line 99 (record-versioning, pre-existing, confirmed via the live `check-record-versioning.sh` gate — **ADVISORY, not BLOCKING**, same tier the gate assigns the analogous hit in `system-overview.md:15`, see Risks): `skill_cleanup no longer deletes it at the skill's own Stage 9` -> `skill_cleanup does not delete it at the skill's own Stage 9`. Verified current: `skill_cleanup()` (`scripts/skill-base.sh:1390`) never removes `.return-meta.json`; ownership sits with the calling command's own last step, exactly as `revise.md`'s own "Cleanup" paragraph (lines 97-102) already states.
  3. Line 12 (artifact-round claim entangled with the dead command): `Only /research advances the artifact number to start a new round.` **This claim is not just stale on the command name — it has been incomplete since task 126 (2026-09-01, pre-dating 407), not because of anything 407 changed.** `orchestrate-stage5-postflight.sh`'s live "A2 P1/P2" logic advances `next_artifact_number` on `researched` **unconditionally**, OR on a **forced** `/orchestrate --plan`/`--implement` dispatch that skips research (an unforced plan/implement dispatch does not advance; it shares the round its preceding research opened). Recommended replacement: `Only a research-phase dispatch — or a forced /orchestrate --plan/--implement dispatch that skips research — advances the artifact number to start a new round; an unforced plan or implement dispatch shares the round its preceding research already opened.` 407's actual contribution (self-healing the *read* against on-disk `MM_` prefixes) does not need to be mentioned in this sentence; it is a resilience detail, not part of "who advances".
- **A third, out-of-scope-but-adjacent record-versioning finding, deliberately NOT recommended for inclusion**: `system-overview.md:15` carries the same defect family ("Superseded note" / "used to") directly adjacent to its own dead-command sentence, and 44 files in the current dead-command hit-set contain `no longer|previously|formerly|used to|withdrawn|superseded`-family text. The live gate (`check-record-versioning.sh`) rates `system-overview.md:15` **ADVISORY**, identical tier to the revise.md line the dispatch *does* fold in. The dispatch names only the revise.md pair; expanding to the other 43 candidate files would be scope growth beyond what was authorized and duplicate the already-completed, dedicated record-versioning taxonomy/lint/hook work (tasks 280-282, archived). Recommendation: leave these alone; the live non-blocking gate already surfaces them for whoever eventually works that backlog.
- **The 328 (markdown-corpus-consolidation) overlap advisory in the dispatch is now moot**: 328 is `completed` (archived). Its landed phases touched only `scripts/`/`scripts/lib/` test-harness dedup work; its one markdown-facing phase (`03_markdown-duplicate-inventory-classification`) produced only an inventory/classification artifact under its own `specs/` tree and never executed an actual merge or deletion of `context/`/`docs/` prose files. The race condition the dispatch anticipated (this sweep rewording a file 328 was about to merge/delete) never materialized and cannot recur — 328 will not dispatch again.
- **Live, same-cycle territory collision is real and current** (unlike 328): sibling tasks 420 and 430 are concurrently dispatched this cycle and declare `file_scope` on six files that are *also* live dead-command hit sites in this task's own scope: `core/context/patterns/batch-orchestration-guardrails.md` (420), `core/scripts/orchestrate-cycle-plan.sh` (420), `core/context/formats/return-metadata-file.md` (430), `core/context/standards/git-staging-scope.md` (430), `core/scripts/update-task-status.sh` (430), `core/agents/general-implementation-agent.md` (430). These are advisory-tier collisions per the dispatch's own Territory contract (re-read-before-edit, scoped single-file commits), not a dependency edge — but the implementation plan should name them explicitly as higher-collision-risk sites to re-check immediately before editing.

## Context & Scope

Researched the current, post-434/post-407 state of the dead-lifecycle-command-prose sweep: a
fresh occurrence count with a boundary-aware pattern (to avoid the raw-substring over-count a
naive `grep -oF '/plan'` produces against `plans/`, `planner-agent.md`, `plan-format.md`, etc.),
a resolution of both dependency edges against their actual landed outcomes, direct verification
of the two revise.md incidental findings (including running the live record-versioning gate
rather than inferring severity), and a check of the 328 concurrency advisory against what 328
actually landed. Did not write or edit any file — this is a research dispatch; the corrected
occurrence counts, the revise.md fix text, and the partition recommendation below are inputs to
the planning phase, not applied here.

## Findings

### Codebase Patterns

**Measurement methodology.** A literal-substring grep (`grep -oF '/plan'`) overcounts badly:
`/plan` matches inside `specs/plans/`, `/planner-agent.md`, `/plan-format.md`, `/planned`, etc.,
and `/implement` matches inside `/implementation-agent.md`. The corrected pattern used throughout
this report is a PCRE boundary match:
```
(?<![A-Za-z0-9_/.-])/(implement|research|plan)(?![A-Za-z0-9_.-])
```
— a literal slash not immediately preceded by another path/word character (excludes nested path
segments like `commands/implement.md`), followed by the bare command name not immediately followed
by a letter/digit/`.`/`-` (excludes `/implementation`, `/plans`, `/planner`, `/plan-format.md`).
This is a heuristic, not a parser — it will still count a handful of legitimate non-recommendation
prose uses (e.g. a worked example literally typing `/research 309`), which is exactly the
"architectural reference" class this task exists to reword, so it is the right inclusion.

**Current per-extension distribution** (files containing >=1 hit, `core/docs/` excluded per the
2026-11-03 scope amendment):

| Extension | Files | Extension | Files |
|---|---|---|---|
| core | 106 | email | 4 |
| founder | 33 | web | 3 |
| present | 19 | rust | 3 |
| cslib | 11 | nix | 3 |
| memory | 8 | books | 3 |
| literature | 6 | z3 | 2 |
| lean | 6 | typst | 2 |
| epidemiology | 5 | python | 2 |
| nvim | 4 | latex | 2 |
| | | formal | 1 |

**`core`'s internal distribution** (106 files / 477 occurrences):

| Subdirectory | Files | Occurrences |
|---|---|---|
| `context/` | 65 | 352 |
| `scripts/` | 21 | 51 |
| `commands/` | 6 | 24 |
| `agents/` | 5 | 15 |
| `skills/` | 5 | 12 |
| `hooks/` | 2 | 10 |
| `README.md` | 1 | 10 |
| `templates/` | 1 | 3 |

`manifest.json`, `index-entries.json`, `merge-sources/`, `root-files/` now show **zero** hits —
434 already cleared these (they were part of its sub-class B structural fix to
`command-output.md` and its own manifest/index registration housekeeping).

**Worked examples of both classes, drawn from the current corpus** (for the plan's judgment
calibration, not as a worklist):

- *Class 1 (phase vs. command), concentrated and systemic in one file*:
  `core/context/processes/research-workflow.md` is a whole document built around the dead
  `/research` command's exact CLI shape — `Usage: /research TASK_NUMBER [PROMPT]`,
  `Resume with: /research {task_number}`, `/research 197 --divide`. This is not a one-line fix;
  the file's own premise (a standalone research command with its own usage grammar) no longer
  exists. The plan should treat this file as a candidate for substantial rewrite around the
  `research`-phase-of-`/orchestrate` model, not a token substitution.
- *Class 1, routing-table shape*: `core/context/orchestration/orchestrator.md:80-85,239` —
  `- /research: Extension type -> extension agent, default -> general-research-agent`,
  `Examples: /plan -> planner, /revise -> reviser`, `**Used by**: /plan, /revise, /review, /todo,
  /task` — these are stale per-command routing-table rows from before task 124 deleted the three
  commands; today's routing is `task_type` -> agent (CLAUDE.md's Skill-to-Agent Mapping table),
  not per-command. Needs rewording to phase-name framing (`research phase: ... `), not a bare
  `/orchestrate` substitution (which would be false three times over, exactly the dispatch's
  warning).
- *Class 2 (architectural/dispatch-model), worked-example shape*:
  `core/context/reference/artifact-numbering-and-versioning.md:21-31` renders an "Example Flow"
  literally typing `/research 309`, `/plan 309`, `/implement 309` as the mechanism for how
  `next_artifact_number` advances. This is the authoritative doc 407's summary names for the
  normalization rule; its own worked example is now internally inconsistent with the commands
  that produce that behavior today (`/orchestrate 309` dispatching each phase). Rewording this
  file's example is a natural companion to revise.md's artifact-round sentence (same subject
  matter, same underlying rule) and the plan should sequence them adjacently.
- *Class 2, self-naming comment inside a script* (not even user-facing prose):
  `core/scripts/skill-base.sh`'s `skill_cleanup()` doc-comment (immediately above the function,
  ~line 1383) reads "see each of `commands/{research,plan,implement,revise,orchestrate}.md` for
  its site" — a stale file-path list naming three files that do not exist. This is squarely
  class-2 (architectural reference inside implementation commentary, never rendered to a user)
  and should be corrected to the three that do exist (`revise.md`, `orchestrate.md`) when that
  comment is touched; it is a 1-line fix with no ambiguity.

### External Resources

Not applicable — pure codebase research, no external API/library involved.

## Recommendations

1. **Partition by extension first, then by `core` subdirectory, sizing phases to roughly
   15-30 files each** (matching the existing per-objective granularity convention elsewhere in
   this codebase's plans): e.g. Phase A = `core/context/` (65 files, the single largest and most
   judgment-dense tranche — likely worth two phases given its size and the class-1/class-2 mix
   within it), Phase B = `core/scripts/+commands/+agents/+skills/+hooks/+templates/+README` (40
   files, mostly short comment/doc-string sites), Phase C = the three incidental `revise.md`
   fixes (small, self-contained, can also simply open Phase A or run standalone first since it
   has concrete, already-derived fix text above), Phase D..N = the 18 other extensions grouped by
   size (`founder`+`present` together ~52 files; `cslib`+`memory`+`literature`+`lean` together
   ~31 files; the remaining 13 extensions with 1-5 files each, batched together as one
   low-judgment-density phase). This mirrors the dispatch's own instruction that "a single phase
   must not attempt the whole 360-file sweep" while keeping each phase's per-site judgment load
   bounded.
2. **Treat `core/context/processes/research-workflow.md` (and any sibling file found to share its
   shape during Phase A) as a flagged, not mechanical, site**: skim every file in the `context/`
   tranche for whether it is a *document about* a dead command (needs restructuring around the
   phase model) versus a document that merely *mentions* one in passing (needs a local reword).
   The two need different effort budgets within the same phase.
3. **Apply the three revise.md fixes verbatim as derived above** (Executive Summary items 1-3) —
   no further research is needed on any of the three; they are fully resolved facts, not open
   questions, and the plan can cite this report's line numbers directly.
4. **Do not touch `system-overview.md:15`'s record-versioning phrasing, or the other ~43 files'
   incidental `no longer`/`used to`/`previously` hits, as part of this task.** They are a
   different, confirmed-advisory-tier, already-gated defect class with its own completed
   taxonomy/lint/hook lineage (280-282); folding them in here would be exactly the
   scope-growth-via-bundling the dispatch's own commentary on "a one-line task is an instance of
   [a bias toward adding machinery]" warns against when applied in the other direction (bundling
   unrelated work into an already-large task rather than filing a trivial one). The plan may
   still reword the *dead-command* half of `system-overview.md:15`'s sentence (that part is
   squarely in scope, since it names `/research`/`/plan`/`/implement`), leaving the
   "Superseded note"/"used to" phrasing exactly as-is.
5. **Name the six live territory-collision files explicitly in the plan** (listed in the
   Executive Summary's last bullet) as sites to re-read immediately before editing, per the
   dispatch's Territory contract — not a dependency edge, but a named risk the plan should
   acknowledge rather than silently discover mid-implementation.
6. **Re-run this report's measurement command at the start of implementation**, not just trust
   the counts here — `grep -rloP '(?<![A-Za-z0-9_/.-])/(implement|research|plan)(?![A-Za-z0-9_.-])' --include="*.md" --include="*.json" --include="*.sh" agent-system/extensions | grep -v '^agent-system/extensions/core/docs/'`
   — since concurrent sibling tasks (420, 430, and whatever else lands between this research
   dispatch and implementation) may have already touched some of the same files.

## Decisions

- The two dependency edges (434, 407) are resolved as fully satisfied; no further research
  against either is needed, and their landed artifacts (cited above) are the authoritative
  source for the revise.md fixes rather than re-deriving the rules from first principles.
- The system-overview.md and other 43-file record-versioning adjacency is explicitly a
  **non-finding for action** — confirmed present, confirmed advisory-tier via the live gate,
  confirmed out of this task's authorized scope. Recorded here so the plan does not need to
  re-discover and re-litigate it, and so a future reader does not mistake its absence from the
  implementation as an oversight.
- The 328 concurrency advisory in the Territory section is stale (328 is now terminal); the plan
  does not need to carry forward any "check whether 328 has an open phase" step.

## Risks & Mitigations

- **Risk**: the 223-file/948-occurrence figure will drift further before implementation starts
  (concurrent sibling tasks, or a `core/docs/`-adjacent task landing changes that touch files in
  this task's scope). *Mitigation*: Recommendation 6 above — re-run the measurement at
  implementation start, treat this report's numbers as a baseline snapshot, not a frozen
  worklist.
- **Risk**: a per-site judgment sweep at this volume (223 files) is inherently slow and
  error-prone if rushed; a contributor under time pressure may be tempted to fall back to the
  forbidden blanket substitution. *Mitigation*: the phase partition in Recommendation 1 is sized
  specifically to keep each phase's file count low enough for genuine per-site reading, and the
  two worked-example classes above give concrete calibration for what "judgment" means at each
  site (phase-name vs. dispatch-description vs. "leave as a literal user-typed example in a
  file that is itself being restructured").
- **Risk**: `core/context/` at 65 files / 352 occurrences is large enough that even split across
  two phases, a contributor could silently drop the `core/scripts/skill-base.sh` comment-level
  finding (not user-facing prose, easy to overlook in a prose-focused sweep). *Mitigation*: name
  it explicitly in the plan's `core/scripts/` phase (Recommendation 1's Phase B) rather than
  relying on the sweep to surface it incidentally.

## Context Extension Recommendations

none

## Appendix

- Search queries used: `grep -rlP '(?<![A-Za-z0-9_/.-])/(implement|research|plan)(?![A-Za-z0-9_.-])' --include="*.md" --include="*.json" --include="*.sh" .` (and `-o` variants) run from `agent-system/extensions/`, per-command variants, per-extension `cut -d/ -f1` tallies, per-`core`-subdirectory tallies; `git blame -L 255,275 agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh`; `bash .claude/scripts/check-record-versioning.sh <file>` against `revise.md` and `system-overview.md`; `grep -rlEi '\b(no longer|previously|formerly|used to|withdrawn|superseded)\b'` restricted to the dead-command hit-set.
- Key files read in full or substantial part: `agent-system/extensions/core/commands/revise.md`
  (whole file), `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` (A2 P1/P2
  region), `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (Stage 7a region),
  `agent-system/extensions/core/scripts/skill-base.sh` (`skill_cleanup`, `skill_read_artifact_number`
  regions), `agent-system/extensions/core/context/reference/artifact-numbering-and-versioning.md`,
  `agent-system/extensions/core/context/architecture/system-overview.md` (header region),
  `specs/archive/407_derive_artifact_round_from_existing_artifacts/summaries/01_artifact-round-max-prefix-summary.md`,
  `specs/archive/434_lint_and_fix_actionable_dead_command_references/summaries/01_lint-dead-command-recommendations-summary.md`
  and its paired research report, `specs/archive/328_systematic_script_and_test_corpus_efficiency/summaries/*.md`
  (all nine, to confirm no `context/`/`docs/` prose file was actually merged or deleted).
