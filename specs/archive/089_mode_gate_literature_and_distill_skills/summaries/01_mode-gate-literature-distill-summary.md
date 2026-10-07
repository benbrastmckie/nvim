# Implementation Summary: Task #89

- **Task**: 89 - Apply the mode-gated section convention to skill-literature and skill-distill
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T00:00:00Z
- **Completed**: 2026-10-03T02:45:00Z
- **Effort**: ~3.5 hours (vs. 9.75-hour estimate)
- **Dependencies**: 87 (pilot: skill-email-cleanup mode-gated extraction)
- **Artifacts**: plans/01_mode-gate-literature-distill.md
- **Standards**: plan-format.md, status-markers.md, mode-gated-section-loading.md, artifact-formats.md, source-store-deploy-boundary.md, git-workflow.md

## Overview

Applied the mode-gated-section-loading convention to the two largest remaining instances:
`skill-literature/SKILL.md` (seven `## Mode:` sections) and `skill-distill/SKILL.md` (nine
`### Sub-Mode:` sections). All sixteen extractions proceeded bottom-up, one green sub-step per
section, with every boundary re-located by literal marker text (or, for distill, by the
discovered 0-or-1-blank-line separator) rather than by a naive heading scan. `skill-literature/SKILL.md`
shrank from 100,460 B to 17,386 B (82.7%); `skill-distill/SKILL.md` shrank from 93,044 B to
30,289 B (67.4%). Sixteen new context files were created, registered in their owning extension's
`index-entries.json`, deployed, and verified end to end.

## Corrected Premise (carried forward so the 43,254 B figure is not repeated)

The task description (and the research report) stated that `skill-distill/SKILL.md` contains a
`## Auto Distill Complete` section of 43,254 B that is an `--auto`-only output template. Direct
verification showed that string is **inside a fenced code block** (a sample-output template) at
line 1495, not a real document heading — the file's only real `##` headings are at lines 11, 21,
278. The 43,254 B figure was the fence-interior-heading artifact itself: a boundary scan from
that fake heading to EOF swept up five complete, unrelated sub-mode specifications. Per the
batched `AskUserQuestion` decision recorded in `.decisions.json`, the distill scope was
re-derived to the real above-bar `### Sub-Mode:` sections (nine of them, 64,329 B measured —
also correcting the plan's own "65,329 B" sum, an arithmetic slip against its own, individually
correct, per-item figures).

## What Changed

### Literature (7 new files, `agent-system/extensions/literature/`)
- `skills/skill-literature/SKILL.md` — seven mode sections replaced by stub pointers
- `context/project/literature/patterns/literature-rebuild-mode.md` — new (467 lines)
- `context/project/literature/patterns/literature-import-pipeline-mode.md` — new (158 lines)
- `context/project/literature/patterns/literature-search-mode.md` — new (292 lines; gained an
  explicit `READ ... literature-import-pipeline-mode.md` pointer at Step 7, since Import
  Pipeline has no `case "$mode"` dispatch arm of its own)
- `context/project/literature/patterns/literature-index-mode.md` — new (177 lines)
- `context/project/literature/patterns/literature-convert-mode.md` — new (587 lines)
- `context/project/literature/patterns/literature-validate-mode.md` — new (383 lines)
- `context/project/literature/patterns/literature-ingest-mode.md` — new (69 lines)
- `index-entries.json` — seven new entries

### Distill (9 new files, `agent-system/extensions/memory/`)
- `skills/skill-distill/SKILL.md` — nine sub-mode sections replaced by stub pointers; `## Shared
  Sub-Mode Skeleton`'s wording updated to distinguish inline (`gc`, `auto`, `report`) from
  extracted-file specifications
- `context/project/memory/patterns/distill-dream-submode.md` — new (129 lines)
- `context/project/memory/patterns/distill-learn-submode.md` — new (137 lines)
- `context/project/memory/patterns/distill-review-submode.md` — new (91 lines)
- `context/project/memory/patterns/distill-meta-submode.md` — new (203 lines)
- `context/project/memory/patterns/distill-revise-submode.md` — new (295 lines)
- `context/project/memory/patterns/distill-refine-submode.md` — new (223 lines)
- `context/project/memory/patterns/distill-compress-submode.md` — new (199 lines)
- `context/project/memory/patterns/distill-merge-submode.md` — new (257 lines)
- `context/project/memory/patterns/distill-purge-submode.md` — new (192 lines)
- `index-entries.json` — nine new entries

### Shared infrastructure fix
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` — the file-level
  allowlist entry for the Import Pipeline's deliberate raw `git add`/`git commit -m` (it runs
  inside the separate `$LITERATURE_DIR` content repo, which has no `git-commit-scoped.sh`) was
  keyed on `skill-literature/SKILL.md`'s old path. Moved with the content to
  `literature-import-pipeline-mode.md`, the new home of that documented exception.

## Decisions

- Both extractions land in their own extension's `context/` subtree
  (`agent-system/extensions/{literature,memory}/context/project/{literature,memory}/patterns/`),
  not core's `context/formats/` — neither extension's `manifest.json` needed an edit since both
  declare their `project/<name>` context directory wholesale.
- File naming uses `literature-<mode>-mode.md` / `distill-<submode>-submode.md` (matching the
  pilot's own surface-prefixed style), not the research report's bare `<mode>-mode.md`, to avoid
  colliding with the pre-existing, unrelated `literature-command-modes.md`.
- Heading promotion shift is `(original heading level - 1)`: literature's `##`-level sections
  shift by 1 (`## -> #`, `### -> ##`); distill's `###`-level sections shift by 2
  (`### -> #`, `#### -> ##`) — both normalize to the section becoming the destination file's
  single H1, per the convention's requirement, rather than a fixed one-hash reduction.
- `Link-Scan Procedure` / `Retrieval Exclusion` / `Health Report -- Tombstoned Memories Section`
  were confirmed **shared** between `purge` and `gc` (GC's own text explicitly names this
  three-section shared boundary) and left inline in `skill-distill/SKILL.md`;
  `distill-purge-submode.md`'s framing paragraph names them as living there.

## Plan Deviations

- **Boundary-marking mechanism** (all extraction phases): boundaries were located by literal
  next-heading text plus a verified separator pattern (literature's blank/`---`/blank; distill's
  discovered 0-or-1-blank-line pattern), confirmed by direct read each time, rather than by
  physically inserting the `branch-gated:begin`/`:end` comment pair first. This achieves the same
  fence-interior-heading-trap immunity the markers exist for — `grep -c branch-gated` was 0 at
  every point — without a transient marked-but-unextracted git state.
- **Commit granularity** (Phases 2-5): each phase's extractions were committed together in one
  commit rather than one commit per extraction, since the plan's own per-extraction verification
  (round-trip diff, byte recording) was still performed and recorded independently per extraction
  before the single commit.
- **Extraction tooling fence-aware heading-promotion fix** (discovered in Phase 3, applied
  throughout): a first-pass version of the extraction script promoted ANY line matching a heading
  pattern, including fence-interior sample-output text that only *looks* like a heading (e.g.
  `## Conversion Complete`, `## Literature Validation Report`, `## Index Entry Added`, and
  distill's `## History`/`## Connections` compress/merge examples). This is exactly the
  fence-interior-heading hazard the plan's own Risk table warns about, encountered on content
  fidelity rather than boundary detection. Caught via round-trip diff review before committing;
  fixed by tracking fenced-code-block state during promotion and regenerating the three affected
  literature files from the pre-extraction original before registering their index entries.
- **Distill boundary-pattern discovery**: the literature convention's blank/`---`/blank section
  separator does not hold in `skill-distill/SKILL.md`, which separates `### Sub-Mode:` sections
  with a variable 0-or-1 blank lines and no `---` at all. Discovered on the first distill
  extraction attempt (which failed its boundary assertion); the extraction tooling was extended
  with a `--no-dash-separator` mode rather than forcing a stylistic `---` insertion.
- **Pre-existing stale cross-reference, left unchanged**: `dream`'s and `revise`'s reference to
  an `### Overlap Scoring` formula does not resolve to any literal heading anywhere in the
  current file (confirmed by a full fence-aware heading scan) — the nearest match is `#### Pairwise
  Keyword Overlap Algorithm` inside `merge`. This predates this task and is out of its pure-
  relocation scope; left unchanged rather than inventing a guessed repoint target.
- **Scoped-commit-boundary lint regression, fixed in-task**: moving Import Pipeline's documented
  raw-git-commit exception out of `skill-literature/SKILL.md` broke that lint's path-keyed
  allowlist entry, surfaced by the post-deploy gate run. Fixed by moving the allowlist entry to
  the new file (see "What Changed" above) rather than leaving a known-regression in the gate set.

## Verification

- **Round-trip fidelity**: every one of the sixteen extractions' content was diffed against its
  pre-extraction span; all differences were exactly the intended heading promotions plus the
  enumerated, deliberate cross-reference repoints — no content lost, added, or reordered.
- **MANDATORY STOP preservation**: 19 occurrences before (distill) == 19 after, confirmed by
  `grep -c` across `SKILL.md` plus all nine new files.
- **Gate 19** (`lint-branch-gated-sections.sh --verbose`): 0 violations, both standalone at every
  commit boundary and inside the full `verify-deploy.sh` run.
- **`generate-context-line-counts.sh --check`**: literature 28/28 exact, memory 17/17 exact.
- **`check-extension-docs.sh`**: literature PASS, memory PASS (the only FAIL is `core`'s
  `claude-refresh.sh`, a concurrently-dispatched sibling task's own in-flight, uncommitted file —
  confirmed via `git status`/`git log`, not this task's regression).
- **Deploy + full gate set** (`deploy-headless.sh` then `verify-deploy.sh` without `--skip-slow`):
  all sixteen destination files deployed under `.claude/context/project/{literature,memory}/patterns/`;
  `.claude/context/index.json` carries all sixteen rows; `validate-context-index.sh` passes with
  0 errors / 0 warnings across 286 entries. Of 34 fast-gate checks, 3 failed — all three trace to
  the concurrently-running task 217's in-flight, uncommitted `claude-refresh.sh` work (confirmed
  by diffing deployed-vs-source and by `specs/.deploy-lock`'s own "another session's deploy
  appears in progress" warning), not to this task.
- **Full shell test suite** (`run-all.sh`, no `--skip-slow`): 103 passed, 5 failed — 3 already
  flagged `(EXPECTED)` by the runner itself, 1 (`test-claude-refresh-matcher.sh`) is task 217's
  own in-flight test, 1 (`test-typst-element-lint.sh`) traces to a pre-existing uncommitted
  `typst-element-lint.sh` modification that predates this session (visible in the conversation's
  starting `git status`). Every literature- and memory/distill-scoped test file passed.
- **Acceptance walk**: all 9 literature modes (`status`, `scan`, `convert`, `validate`, `index`,
  `search`, `ingest`, `rebuild`, plus the search-driven import flow) and all 12 distill sub-modes
  (`report`, `purge`, `merge`, `compress`, `refine`, `gc`, `auto`, `revise`, `meta`, `review`,
  `learn`, `dream`) reach a non-empty specification — inline for the default/excluded branches,
  via a verified-non-empty, correctly-framed extracted file for the rest.

## Measured-Reduction Report

| File | Before | After | Reduction |
|------|--------|-------|-----------|
| `skill-literature/SKILL.md` | 100,460 B | 17,386 B | 83,074 B (82.7%) |
| `skill-distill/SKILL.md` | 93,044 B | 30,289 B | 62,755 B (67.4%) |

Seven literature destination files total 88,378 B; nine distill destination files total
68,802 B. Combined relocated-content total (measured spans, Phase 1 figures): 84,308 B
(literature) + 64,329 B (distill) = **148,637 B**.

**Per-invocation loaded-byte totals** (`commands/<cmd>.md` + `SKILL.md` + the one selected
mode/sub-mode file; `literature.md` is 41,652 B, `distill.md` is 12,075 B, both unchanged):

- **`/literature`**: before, every invocation loaded 142,112 B (~35,528 tokens) regardless of
  mode. After, loaded bytes range from 61,397 B (`--ingest`, ~15,349 tokens, **~20,179 tokens
  saved**) to 81,546 B (`--convert`, ~20,386 tokens, **~15,142 tokens saved**) depending on which
  mode is dispatched.
- **`/distill`**: before, every invocation loaded 105,119 B (~26,280 tokens) regardless of
  sub-mode. After, the default/non-extracted path (`report`, `gc`, or `auto`) loads 42,364 B
  (~10,591 tokens, **~15,689 tokens saved**); a moved sub-mode ranges from 47,655 B (`--review`,
  ~11,914 tokens, **~14,366 tokens saved**) to 55,266 B (`--revise`, ~13,816 tokens, **~12,463
  tokens saved**).

**Reconciliation with the task's stated baselines**: the task description cited whole-invocation
baselines of ~46.2k tokens (`/literature`) and ~42.4k tokens (`/distill`). Those figures include
ambient context this task does not touch (rules, memory/literature injection, etc.) — the
command+`SKILL.md`-only baseline measured here is ~35.5k / ~26.3k tokens respectively, lower
than the stated whole-invocation figures because it excludes that ambient context. The honest,
verifiable claim is the byte-exact delta on the two surfaces this task actually edited, reported
above; the task's own stated token-reduction *direction and intent* (take both commands from a
large eager-loaded baseline toward a much smaller one) is achieved and, for distill, the
35,000-B-wider scope (nine sub-modes instead of the described single `--auto` template) exceeds
the originally stated target.

## Impacts

- Every `/literature` invocation now loads one of eight possible bodies (seven extracted modes
  or the default/scan inline body) instead of the whole 100 KB file unconditionally.
- Every `/distill` invocation now loads one of ten possible bodies (nine extracted sub-modes or
  the default/gc/auto inline body) instead of the whole 93 KB file unconditionally.
- A future author adding an eighth literature mode or a thirteenth distill sub-mode has a
  working, twice-proven template (plus the pilot) to follow.

## Follow-ups

- None required for task closure. If a future task wants to push further, the two remaining
  bash-heavy surfaces (noted but explicitly out of scope here) are: literature's 64.5%
  fenced-bash composition (a separate, adjacent "extract to `scripts/*.sh`" lever per the
  convention's own "Adjacent, Separate Lever" section) and distill's mis-nested heading levels
  (every sub-mode sits under an `##` that is really the file's second section) — restructuring
  the source file's own remaining hierarchy was an explicit non-goal of this task.
- The `### Overlap Scoring` stale cross-reference inside `dream`/`revise` (see Plan Deviations)
  is a pre-existing, independent documentation inaccuracy worth a small follow-up fix, but was
  left untouched here since repointing it would require guessing at a target this task has no
  authority to invent.

## References

- `specs/089_mode_gate_literature_and_distill_skills/plans/01_mode-gate-literature-distill.md`
- `specs/089_mode_gate_literature_and_distill_skills/reports/01_mode-gate-literature-distill.md`
- `specs/089_mode_gate_literature_and_distill_skills/progress/phase-{1..5}-progress.json`
- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md`
