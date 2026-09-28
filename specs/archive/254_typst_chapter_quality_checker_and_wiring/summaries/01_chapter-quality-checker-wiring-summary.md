# Implementation Summary: Task #254

- **Task**: 254 - Implement chapter-quality-check.sh with its test harness, then wire the standard and checker into the typst agents, skills, manifest and index
- **Status**: [COMPLETED]
- **Started**: 2026-09-24T20:10:17Z
- **Completed**: 2026-09-24T21:40:00Z
- **Effort**: ~4 hours
- **Dependencies**: Task 253 (chapter-quality standard) - complete
- **Artifacts**: plans/01_chapter-quality-checker-wiring.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented `chapter-quality-check.sh` (a 15-rule mechanical/judged checker mirroring
`typst-element-lint.sh`'s structure) and its test harness in the source store
(`agent-system/extensions/typst/`), then wired both the checker and the standard it enforces
through all six registration/contract surfaces (manifest, index, both typst agents, the
implementation skill, and EXTENSION.md). All 10 plan phases completed; the two-group
phase separation (Group A: checker + tests, Group B: wiring) held throughout, with a green
commit at every phase boundary.

## What Changed

- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` — new, executable. A
  Class B (`set -uo pipefail`) checker implementing the standard's 7 MECHANICAL rules (1.2,
  1.3, 1.5, 3.2 BLOCKING; 2.1, 2.3, 3.3 ADVISORY), emitting all 8 JUDGED rules (1.1, 1.4, 2.2,
  3.1, 3.4, 4.1, 4.2, 4.3) as structured `[JUDGED]` reviewer prompts, and delegating placement
  to the sibling `typst-element-lint.sh` rather than re-implementing it. Prints a per-chapter
  `SCORE` line (`MECHANICAL <passed>/<evaluated> | BLOCKING <n> | ADVISORY <n> | JUDGED <n>
  prompts pending`) per file.
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` — new,
  executable. 59 inline-heredoc-fixture cases: compliant fixture, one case per MECHANICAL
  BLOCKING rule (plus a negative control for 1.5), advisory-only non-vacuity case, an
  ANTI-FLUFF-only case proving 2.1/2.3 never affect exit code, judged-prompt-emission case
  (all 8 rule ids asserted), placement-delegation cases (BLOCKING and ADVISORY), a grep-based
  regression guard against a second placement implementation, and the CLI contract.
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` — added
  a `## Per-Chapter Score` non-rule reporting-convention subsection (336 -> 359 lines).
- `agent-system/extensions/typst/manifest.json` — registered `chapter-quality-check.sh` and
  `tests/test-chapter-quality-check.sh` in `provides.scripts`.
- `agent-system/extensions/typst/index-entries.json` — added a context entry for
  `project/typst/standards/chapter-quality.md` (`load_when.agents`: both typst agents;
  `load_when.task_types`: `["typst"]`).
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` — added the
  chapter-quality gate at Stage 4C (per phase) and Stage 5 (whole-document final pass),
  alongside the existing element-lint gate, plus Critical Requirements MUST DO item 8.
- `agent-system/extensions/typst/agents/typst-research-agent.md` — Stage 2 now names
  `chapter-quality.md` as context to load when research feeds chapter content.
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` — Stage 5b
  self-review paragraph extended to also run the chapter-quality gate; the MUST NOT
  cross-reference sentence extended to note the correspondence.
- `agent-system/extensions/typst/EXTENSION.md` — added a Common Operations bullet advertising
  `chapter-quality-check.sh`, mirroring the element-lint bullet's shape.

## Decisions

- Followed the plan's 7 pre-settled decisions verbatim (per-chapter score definition,
  repo-root/bibliography resolution via `#bibliography(...)` declaration or single-candidate
  fallback with a NOT EVALUATED branch, under-firing path-shape heuristic for Rule 1.2, exact
  CLI shape, placement composition via the sibling lint, Class B strict mode, and the
  deployed-path convention in wiring prose).
- Emitted every `[JUDGED]` prompt with its severity axis inline (`[<rule> / <dimension> /
  <severity> once resolved]`) so a reviewing agent knows what the rule counts as once
  adjudicated — an addition beyond the plan's literal task list, kept because it directly
  serves the "green mechanical score is not full coverage" requirement.

## Plan Deviations

- **Phase 3 (retroactive fix applied during Phase 5)**: Rule 2.1's claim-counting heuristic
  originally also counted semantic-element invocations (`definition`/`theorem`/`.../rule-list`)
  as claims, alongside `@key` citations. That element-name list collided textually with the
  Phase 5/10 placement-regression grep
  (`grep -nE 'definition|theorem|lemma|corollary|remark|rule-block|rule-list'
  scripts/chapter-quality-check.sh`), which exists to prove no second placement implementation
  was added. Simplified Rule 2.1's claim count to `@key` citations only — simpler, avoids the
  ambiguity, and keeps the placement/claim-ratio boundary the script's SCOPE BOUNDARY draws.
  Recorded in `progress/phase-5-progress.json`'s `deviations` array.
- **Bash `read` field-splitting bug found and fixed during Phase 2**: the original rule-check
  implementations used `IFS=: read -r lnum content` to parse `grep -n` output, which silently
  drops a trailing empty field (corrupting lines ending in a delimiter, e.g. `// CONFIRM:`
  with an empty payload). Replaced with `IFS= read -r rawline` plus manual `%%:*` / `#*:`
  substring splitting in all four affected functions. Not a plan deviation in substance (the
  plan did not prescribe a specific parsing mechanism), but noted here since it required
  revisiting Phase 2 code after Phase 2 had otherwise verified green with a less-adversarial
  fixture. Recorded in `progress/phase-2-progress.json`'s `approaches_tried`.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both).
- Tests: `test-chapter-quality-check.sh` — 59 passed, 0 failed.
  `test-typst-element-lint.sh` (sibling regression) — 37 passed, 0 failed, unchanged.
- Files verified: Yes — both new scripts exist, executable, in the source store; no files
  hand-authored under `.claude/**`.
- Acceptance criteria (from the dispatch), each with recorded evidence:
  1. Both new files exist in the source store; nothing hand-authored under `.claude/**`
     (confirmed via the scratch-repo deploy check below).
  2. Test suite green: 59 passed, 0 failed, demonstrating the blocking/advisory split in both
     directions.
  3. Blocking fixture (level-4 heading) exits 1; advisory-only fixture (200-word single
     paragraph) exits 0 with 2 `[WARN]` lines printed.
  4. ANTI-FLUFF-only fixture (Rules 2.1 + 2.3 firing, nothing else) exits 0 explicitly, with 0
     `[FAIL]` lines.
  5. `grep -c '/ JUDGED\]' chapter-quality.md` = 8; the checker's `JUDGED_RULES` table = {1.1,
     1.4, 2.2, 3.1, 3.4, 4.1, 4.2, 4.3} — exact match, no omissions or extras.
  6. `grep -nE 'definition|theorem|lemma|corollary|remark|rule-block|rule-list'
     scripts/chapter-quality-check.sh` returns exactly one hit, a header-prose line explaining
     the boundary — no placement-matching logic.
  7. `jq .` clean on both `manifest.json` and `index-entries.json`; `provides.scripts` lists
     all four scripts; the `chapter-quality.md` index entry has both typst agents in
     `load_when.agents`.
  8. Scratch-repo deploy (via `deploy-headless.sh` bootstrapping `core`, then
     `manager.load('typst', {force=true})` following `test-deploy-propagation.sh`'s pattern)
     confirmed both new scripts under `.claude/scripts/`, the index entry merged into
     `.claude/context/index.json`, the `EXTENSION.md` section merged into `.claude/CLAUDE.md`
     (3 `chapter-quality-check.sh` mentions in the deployed implementation agent, 1 in the
     deployed research agent, 4 `chapter-quality` mentions in the deployed skill). This repo's
     own `.claude-extensions.json` was left untouched — `typst` was never added to it.
  9. `check-task-references.sh --quiet agent-system/extensions/typst` — 0 unexempted
     occurrences.

## Impacts

- Content authors working through `typst-implementation-agent` (or the implementation skill's
  Stage 5b inline fallback) now have a mechanical BLOCKING gate on chapter prose quality,
  parallel to the existing element-placement gate, before a phase or task can be marked
  complete.
- `typst-research-agent` now surfaces the chapter-quality bar at research time for chapter-
  content tasks, so research is calibrated to what the chapter will later be checked against.
- The extension's discoverable capability surface (`EXTENSION.md` / deployed `CLAUDE.md`) now
  advertises the chapter-quality checker alongside the element lint.

## Follow-ups

- `EXTENSION.md`'s `### Scope` paragraph states that content-creation work (chapters, prose)
  routes to `lean4`/`formal`/`general`, not to `typst` — in some tension with wiring a
  chapter-quality gate into `typst-implementation-agent`, whose own overview note already
  states content authorship is out of scope. Per the plan's Non-Goals, this tension was left
  unresolved and followed literally as dispatched; a future task could reconcile the Scope
  note with the gate's presence (e.g. by clarifying that the gate exists for whichever agent
  DOES touch `.typ` chapter content, formatting-agent or otherwise).
- Rules 2.1 (claim-to-word ratio) and 3.3 (paragraph length) use UNREVIEWED numeric thresholds
  with no corpus observation behind them yet, exactly as `chapter-quality.md` itself
  discloses; per the standard's severity-split rationale, promoting either to BLOCKING
  requires a documented review pass against real chapters first (not performed as part of
  this task, since no real chapter corpus was checked here — the consuming repository owns
  that observation).
- The `local:name-resolution` and `local:chapter-source-coverage` Interface Contract checks
  remain unimplemented by design (owned by a consuming repository's own `typst/scripts/`, per
  the standard's own contract) — this is a Non-Goal, not an oversight.

## References

- `specs/254_typst_chapter_quality_checker_and_wiring/plans/01_chapter-quality-checker-wiring.md`
- `specs/254_typst_chapter_quality_checker_and_wiring/reports/01_chapter-quality-checker-wiring.md`
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md`
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` (structural precedent)
