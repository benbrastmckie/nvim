# Implementation Plan: Task #89

- **Task**: 89 - Apply the mode-gated section convention to skill-literature and skill-distill
- **Status**: [IMPLEMENTING]
- **Effort**: 9.75 hours
- **Dependencies**: 87 (pilot: `skill-email-cleanup` mode-gated extraction — complete, its output is this plan's literal template)
- **Research Inputs**: `specs/089_mode_gate_literature_and_distill_skills/reports/01_mode-gate-literature-distill.md`
- **Artifacts**: plans/01_mode-gate-literature-distill.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/context/patterns/mode-gated-section-loading.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/git-workflow.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

Apply the `mode-gated-section-loading.md` convention — marker pair, imperative pointer,
heading promotion, index registration, measured delta — to the two largest remaining instances:
`skill-literature/SKILL.md` (seven mutually exclusive `## Mode:` sections, 84,308 B of a
100,460 B file) and `skill-distill/SKILL.md` (nine mutually exclusive `### Sub-Mode:` sections,
65,329 B of a 93,044 B file). Work proceeds bottom-up within each file, one extraction per green
sub-step, with every boundary re-located by literal marker text rather than by a heading scan.
All writes target the **source store** (`agent-system/extensions/**`), never `.claude/**`.

**One premise in the task description is factually wrong and this plan deliberately corrects it.**
The description (and the research report, which repeated it) states that `skill-distill/SKILL.md`
contains a `## Auto Distill Complete` section of 43,254 B — 46% of the file — that is an
`--auto`-only output template to be moved out. Direct verification shows that string at line 1495
is **inside a fenced block** (139 fence delimiters precede it; it is the sample output `--auto`
prints), not a document heading. The file's only real `##` headings are at lines 11, 21, and 278.
The 43,254 B figure is the fence-interior-heading artifact itself: a boundary scan from that fake
heading to EOF sweeps up five complete, unrelated sub-mode specifications (`revise`, `meta`,
`review`, `learn`, `dream`) plus `Distill Log Schema` and `State Integration`. Executing the
description literally would move `/distill --revise`, `--meta`, `--review`, `--learn` and
`--dream`'s entire specifications into a file an agent is told to read **only** when `--auto`
runs, leaving five sub-modes unspecified — precisely the failure mode the convention's
"Whole-Section vs. Reference-Appendix Risk" section warns about. The real `### Sub-Mode: auto`
section is 3,358 B and stays inline (below the extraction bar, and `--auto` is an automated,
frequently-taken branch).

The task's **intent** (take `/distill` from ~42.4k tokens toward ~32k by removing branch-only
prose from a surface loaded on every invocation) and its **acceptance bar** (both distill paths
verified working; measured reductions reported) are preserved and in fact exceeded: extracting
the nine above-bar `### Sub-Mode:` sections removes 65,329 B rather than the described 43,254 B.
Phase 1 records this correction with the verification command that establishes it.

### Research Integration

- The report's literature findings are confirmed independently and used as-is: the nine real
  `## Mode:` heading lines (101, 171, 267, 346, 730, 1318, 1496, 1783, 1938), the six
  fence-interior fake `## ` headings (239, 315, 334, 644, 1291, 1483), and the seven target
  spans' byte sizes all reproduce exactly.
- The report's **Path Selection Rule** decision is adopted: both extractions land in their own
  extension's context subtree, not core's `context/formats/`, despite the task description's
  informal wording. Verified consequence: neither `manifest.json` needs an edit —
  `literature`'s `provides.context` is `["project/literature", "guides"]` and `memory`'s is
  `["project/memory"]`, both wholesale directory declarations, and the email pilot proves a
  nested `patterns/` subdirectory deploys recursively.
- The report's bottom-up ordering, its instruction to re-verify every span by direct read, and
  its exclusion of `Mode: Status` (default branch) and `Mode: Scan` (1,846 B) are adopted
  unchanged.
- **Corrected against the report**: (a) the distill premise above; (b) the report's cross-
  reference sweep scoped greps to the inline-staying regions only, so it missed the *inter-mode*
  couplings — `handle_import()` (inside Import Pipeline) calls `handle_convert()` (defined inside
  Convert), and Rebuild's Job 4 prose cites `handle_convert()`/`handle_ingest()` at lines 2162,
  2163, 2211, 2253. Those become cross-*file* references and are handled explicitly in Phase 3;
  (c) `Mode: Import Pipeline (Steps 8-12)` is **not** a dispatch case — the `case "$mode"` block
  at lines 85-92 has no `import` arm; it is reached from Search Step 7, so its pointer must also
  appear inside the extracted search file, not only in `SKILL.md`.
- **Naming deviation from the report, with cause**: the report proposed `<mode>-mode.md`. This
  plan uses `literature-<mode>-mode.md` and `distill-<submode>-submode.md` instead, matching the
  pilot's own surface-prefixed name (`email-cleanup-all-mode.md`) and avoiding confusion with
  the pre-existing, unrelated `project/literature/patterns/literature-command-modes.md` (which
  documents the `/literature` Mode A/B *command-usage* distinction — a different "mode" concept).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Extract the seven named `skill-literature` mode sections to
  `agent-system/extensions/literature/context/project/literature/patterns/literature-<mode>-mode.md`,
  each replaced by a stub heading plus an imperative `READ ... now and follow it exactly.` pointer.
- Extract the nine above-bar `skill-distill` sub-mode sections to
  `agent-system/extensions/memory/context/project/memory/patterns/distill-<submode>-submode.md`
  on the same pattern.
- Register all sixteen destination files in their owning extension's `index-entries.json` with
  schema-conformant entries and `wc -l`-accurate `line_count` values.
- Repoint every cross-reference that the moves would leave dangling — inbound (inline-staying
  prose into moved content), inter-file (one extracted section into another), and relative-
  location wording ("above"/"below") whose referent is now in a different file.
- Verify all nine literature modes and all twelve distill sub-modes still reach a non-empty
  specification, deploy the source store, and pass the full gate set including Gate 19.
- Report measured before/after bytes per file, per extraction, and the token-equivalent delta
  reconciled against the task's stated 46.2k and 42.4k baselines.

**Non-Goals**:
- Any behavioral change to either command. This is a pure relocation refactor; content moves
  verbatim apart from heading promotion, the mandatory framing line, and cross-reference repoints.
- Extracting `Mode: Status` or `Mode: Scan` from literature, or `### Sub-Mode: auto` (3,358 B),
  `### GC Sub-Mode` (3,787 B), the `report`/default path, `Shared Sub-Mode Skeleton`,
  `Scoring Engine`, `Health Report Template`, `Distill Log Schema`, `State Integration`,
  `Sub-Index Management`, `Error Handling`, or `Standards Reference` — all are either the default
  branch, below the extraction bar, or genuinely shared across branches.
- Bash-to-`scripts/*.sh` extraction. The convention names it an adjacent, separate lever; it is
  not in this task's scope even though `skill-literature/SKILL.md` is 64.5% fenced bash.
- Fixing the mis-nested heading levels in `skill-distill/SKILL.md` (every sub-mode is `###` under
  an `##` that is really the file's second section). Heading promotion inside each extracted file
  normalizes it per-file; restructuring the source file's own remaining hierarchy is out of scope.
- Any edit under `.claude/**` other than the sanctioned `deploy-headless.sh` regeneration.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A naive "next `##` line" boundary scan truncates `Validate`/`Convert`/`Index` at a fence-interior fake heading (lines 644/1291/1483), silently dropping real mode content | H | M | Place the `branch-gated:end` marker immediately above the next **real** `## Mode:` heading, then locate the span by literal marker text only; confirm every span by direct read and by the round-trip diff in each phase's verification |
| The same hazard in distill (it already produced the wrong task premise) recurs during implementation | H | M | Phase 1 re-runs the fence-state scan and records the real heading map; all distill spans are keyed on the `### Sub-Mode:`/`### X Sub-Mode` heading lines in that map, never on `## ` |
| A moved section's spec becomes unreachable because its pointer is missing or passively worded | H | L | Every stub uses the pilot's verbatim imperative form; Phase 6 walks all 9 literature modes and all 12 distill sub-modes and asserts each reaches a non-empty body or an existing, non-empty pointer target |
| Import Pipeline is reachable only from Search Step 7, so a `SKILL.md`-only pointer leaves a search-driven import unspecified | H | M | Phase 2 adds the import pointer **inside** the extracted search file at the Step 7 invocation point, in addition to the `SKILL.md` stub |
| `handle_convert()` is defined inside Convert but called from Import Pipeline and cited by Rebuild Job 4 — after extraction these are cross-file | M | H | Phase 3 repoints each occurrence to name the owning extracted file; Phase 3 verification greps every `handle_*` mention for an unresolved referent |
| "above"/"below" wording whose referent crossed a file boundary (23 occurrences in literature spans, 36 in distill spans) silently misdirects a reader | M | H | Per-extraction audit step in Phases 2-5: classify each occurrence intra-span (leave) vs. cross-boundary (repoint by file name); counts are hypotheses to confirm, not facts |
| Gate 19 fails mid-pass because several marked-but-unextracted spans sum over 8,000 B | L | M | Mark and extract **one section at a time** rather than marking all seven/nine up front, so every commit boundary is lint-clean |
| `index-entries.json` edits break Rule T schema conformance or carry stale `line_count` | M | M | Use the pilot entry as the literal field template (`path`, `domain`, `subdomain`, `summary`, `line_count`, `keywords`, `load_when.commands`; no `description`, no `tags`), then run `generate-context-line-counts.sh --check` and `check-extension-docs.sh` |
| Measured savings are reported against the task's stale/incorrect baselines and do not reconcile | M | H | Phase 6 reports byte-exact before/after for each changed file plus the ~4 B/token conversion, and states explicitly that the 46.2k/42.4k figures include ambient context this task does not touch |
| A sibling task's concurrent edit is mistaken for a regression, or is swept into a commit | M | M | Four siblings are dispatched this cycle, all scoped to `extensions/core/**` and `extensions/epidemiology/**` — disjoint from this task's `literature`/`memory` scope. Re-read each file immediately before editing; stage only this task's explicit file list, never a directory or glob add |
| Working literature and distill chains in parallel (waves 2-3) produces interleaved commits | L | M | The two chains touch disjoint files; each commit stages an explicit file list. Serialize if a single implementer executes both |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5 | 2 (for 3), 4 (for 5) |
| 4 | 6 | 3, 5 |

Phases within the same wave can execute in parallel (phases 2/3 touch only literature files;
phases 4/5 touch only memory files).

### Phase 1: Baseline Measurement and Corrected Boundary Map [COMPLETED]

**Goal**: Establish the measured before-state and a fence-aware boundary map that every later
phase keys on, and record the correction to the task's distill premise with the command that
proves it.

**Tasks**:
- [x] Record `wc -c -l` for `agent-system/extensions/literature/skills/skill-literature/SKILL.md`,
      `agent-system/extensions/memory/skills/skill-distill/SKILL.md`,
      `agent-system/extensions/literature/commands/literature.md`, and
      `agent-system/extensions/memory/commands/distill.md`. *(completed: literature SKILL.md
      2574 lines/100,460 B; distill SKILL.md 2497 lines/93,044 B; literature.md 761 lines/41,652 B;
      distill.md 274 lines/12,075 B)*
- [x] Run the fence-aware heading scan over both SKILL.md files (track ` ``` ` state while
      matching `^## ` / `^### `) and record: every real heading line number, every fence-interior
      fake heading, and each target section's span in lines and bytes. *(completed: recorded in
      progress/phase-1-progress.json)*
- [x] Record the premise correction: show that `## Auto Distill Complete` (line 1495) is
      fence-interior (odd count of fence delimiters above it) and that the file's only real `##`
      headings are at 11, 21, 278 — so the described 43,254 B `--auto` section does not exist as
      a section, and `### Sub-Mode: auto` is 3,358 B. *(completed: confirmed exactly)*
- [x] Confirm the extraction set and per-section byte sizes: literature `Ingest` 1,917 /
      `Validate` 18,484 / `Convert` 22,009 / `Index` 5,451 / `Search` 10,053 /
      `Import Pipeline` 6,152 / `Rebuild` 20,242 (sum 84,308); distill `purge` 6,124 /
      `merge` 8,077 / `compress` 5,996 / `refine` 6,974 / `revise` 12,427 / `meta` 8,796 /
      `review` 4,826 / `learn` 5,754 / `dream` 5,355 (sum 65,329). *(deviation: altered -- every
      literature figure confirmed exact, sum 84,308 confirmed; every distill per-item figure
      confirmed exact, but the correct sum of those nine figures is 64,329 B, not 65,329 B -- the
      plan text's own sum annotation has an arithmetic error. Using 64,329 B as the measured
      extraction total going forward.)*
- [x] Confirm no `manifest.json` edit is required by re-reading both extensions'
      `provides.context` arrays. *(completed: literature=["project/literature","guides"],
      memory=["project/memory"], both wholesale directory declarations)*
- [x] Write the map and the measurements into the task's progress/summary artifact under
      `specs/089_mode_gate_literature_and_distill_skills/` (no file outside `specs/` is modified
      in this phase). *(completed: progress/phase-1-progress.json)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the per-section byte figures and the 16-file extraction set above are
hypotheses carried from research plus this plan's own verification. Confirm each by re-running
the fence-aware span measurement at implementation time; if any span differs by more than a
rounding-level amount, record the new number and proceed with the measured value rather than the
planned one.

**Files to modify**:
- `specs/089_mode_gate_literature_and_distill_skills/**` only (measurement record). No source
  files change.

**Verification**:
- The recorded heading map reproduces the fence-aware scan's output exactly when re-run.
- The sum of the literature target spans equals the measured difference between the file total
  and the inline-staying regions.
- `git status --short` shows no modification outside `specs/`.

---

### Phase 2: Literature Extractions, Bottom-Up Part A — Rebuild, Import Pipeline, Search [COMPLETED]

**Goal**: Extract the three lowest literature mode sections, in strict bottom-up order, each as
one green sub-step comprising destination file + stub pointer + index entry.

**Tasks**:
- [x] For each of `Rebuild` (1938-2404), then `Import Pipeline` (1783-1937), then `Search`
      (1496-1782) — strictly in that order, re-reading the file before each to re-locate the span:
  - [x] Insert `<!-- branch-gated:begin condition="mode=<x>" -->` above the section's `## Mode:`
        heading and `<!-- branch-gated:end -->` immediately above the next real `## ` heading
        (never a fence-interior one); confirm the span by direct read. *(deviation: altered --
        boundaries were located by literal next-real-heading text plus the verified
        blank-line/`---`/blank-line pattern that precedes every real heading in this file,
        confirmed by direct read, rather than by physically inserting the marker-comment pair
        into the file first. This achieves the same literal-text boundary-location robustness
        the markers exist for -- fence-interior fake headings were never matched -- without a
        transient marked-but-unextracted git state; `grep -c branch-gated` is 0 at every point.)*
  - [x] Create `agent-system/extensions/literature/context/project/literature/patterns/literature-<mode>-mode.md`
        with the section's content verbatim, headings promoted one level uniformly
        (`##`->`#`, `###`->`##`, `####`->`###`), preceded by the mandatory framing line stating
        it is the COMPLETE and ONLY specification for that mode and must be followed exactly,
        worded on the pilot's model. *(completed: literature-rebuild-mode.md 467 lines/20,684 B,
        literature-import-pipeline-mode.md 154 lines/6,748 B, literature-search-mode.md 292
        lines/10,492+ B; round-trip diffs verified against `git show HEAD~N` -- no content lost,
        added, or reordered beyond heading promotion and the deliberate repoints below)*
  - [x] Replace the marked span (markers included) in `SKILL.md` with the stub: the original
        `## Mode: <X>` heading followed by
        `READ .claude/context/project/literature/patterns/literature-<mode>-mode.md now and follow it exactly.`
        *(completed for all three)*
  - [x] Audit the extracted file for "above"/"below" wording and for references to sections that
        did not move; repoint any cross-boundary referent by file name. *(completed: Rebuild's
        "Sub-Index Management > Validate" block below" repointed to name skill-literature/SKILL.md
        explicitly; five other above/below occurrences in Rebuild confirmed intra-span (no
        change); Import Pipeline had none; Search's Step 7 "Steps 8-12 below" repointed both as a
        bash comment and a new imperative READ pointer into literature-import-pipeline-mode.md,
        since Import Pipeline has no case "$mode" arm of its own. handle_convert() couplings
        inside Rebuild/Import Pipeline are left as-is -- Convert has not been extracted yet;
        deferred to Phase 3 per the plan's own Risk table.)*
  - [x] Add the `index-entries.json` entry (pilot field shape; `load_when.commands: ["/literature"]`).
        *(completed: three entries added, `generate-context-line-counts.sh --check` clean)*
  - [x] Record the extraction's before/after `SKILL.md` bytes and the destination file's bytes.
        *(completed: recorded in progress/phase-2-progress.json; SKILL.md 100,460 -> 64,421 B
        after all three)*
  - [x] Commit this sub-step with an explicit file list. *(deviation: altered -- all three
        extractions were committed together in one commit rather than three separate per-substep
        commits, since all three were completed in the same working session before the first
        commit was made. Each extraction's content is independently round-trip-verified above;
        Phase 3 reverts to one commit per extraction.)*
- [x] In `literature-search-mode.md`, at the Step 7 point where a `pdf_available` selection enters
      the import flow, add
      `READ .claude/context/project/literature/patterns/literature-import-pipeline-mode.md now and follow it exactly.`
      — Import Pipeline has no `case "$mode"` arm, so this is its only reachable pointer for a
      search-driven import. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts three sections at the line spans above and a count of
cross-boundary "above"/"below" occurrences (Rebuild 6, Search 1, Import Pipeline 0 total
occurrences, of which only some cross a boundary). Confirm each span by literal-marker read
before deleting, and confirm each occurrence's classification by reading its sentence, not by
the count.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — three spans replaced by
  stub pointers
- `agent-system/extensions/literature/context/project/literature/patterns/literature-rebuild-mode.md` — new
- `agent-system/extensions/literature/context/project/literature/patterns/literature-import-pipeline-mode.md` — new
- `agent-system/extensions/literature/context/project/literature/patterns/literature-search-mode.md` — new
- `agent-system/extensions/literature/index-entries.json` — three new entries

**Verification**:
- Round-trip per extraction: `diff <(git show HEAD~:<SKILL.md path> | sed -n '<S>,<E>p')
  <(tail -n +<first content line> <new file> | sed 's/^\(#\+\) /#\1 /')` differs only in the
  framing block and intentional repoints — no content line lost or reordered.
- No `branch-gated:` marker remains in `SKILL.md` after each sub-step
  (`grep -c branch-gated` is 0), so Gate 19 stays clean at every commit boundary.
- `python3 -c "import json;json.load(open('agent-system/extensions/literature/index-entries.json'))"`
  parses; `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`
  reports no mismatch for the new entries.
- Each new file's first content line asserts complete-and-only-specification status; each stub's
  pointer uses the imperative form (`grep -c "now and follow it exactly"` matches the number of
  stubs added).

---

### Phase 3: Literature Extractions Part B — Index, Convert, Validate, Ingest; Cross-Reference Repoint; Measurement [COMPLETED]

**Goal**: Finish the literature extraction set, repoint every remaining dangling reference, and
record the file's measured reduction.

**Tasks**:
- [x] Extract, in bottom-up order and by the same six-step per-section procedure as Phase 2:
      `Index` (1318-1495), `Convert` (730-1317), `Validate` (346-729), `Ingest` (101-170) —
      one green sub-step and one commit each. *(deviation: altered -- the extraction script's
      first-pass heading-promotion logic wrongly promoted three fence-interior sample-output
      "headings" inside Convert/Validate/Index (`## Conversion Complete`, `## Literature
      Validation Report` and 11 nested headings in its template, `## Index Entry Added`) --
      caught before committing via round-trip diff review, fixed by making promotion
      fence-aware, and all three destination files regenerated clean. See
      progress/phase-3-progress.json approaches_tried for the full account. All four extractions
      were committed together in one commit rather than four separate ones, matching Phase 2's
      already-recorded commit-granularity deviation.)*
- [x] Repoint the four inbound cross-references from inline-staying prose into moved content:
      lines ~2531 and ~2535 (Sub-Index Management, both citing `rebuild_job1_dangling_ref_lint`
      "under 'Mode: Rebuild' above") and ~2545 and ~2557 (Error Handling, both citing
      `Mode: Convert`) — each now naming the owning extracted file. *(completed)*
- [x] Repoint the inter-file handler couplings: `handle_import()`'s calls to `handle_convert()`
      (in `literature-import-pipeline-mode.md`, ~3 mentions), Rebuild Job 4's citations of
      `handle_convert()`/`handle_ingest()` (in `literature-rebuild-mode.md`, lines ~2162, 2163,
      2211, 2253 of the pre-extraction file), and `Standards Reference`'s `handle_convert()`
      mention (~2574) — each naming the file where the handler is now specified. *(completed:
      all four pre-extraction line citations repointed, plus the Standards Reference mention)*
- [x] Fresh repo-wide sweep per the convention's mandatory step 6:
      `grep -rn "Mode: Rebuild\|Mode: Convert\|Mode: Validate\|Mode: Search\|Mode: Index\|Mode: Ingest\|Mode: Import Pipeline" agent-system/`
      and `grep -rn "handle_convert\|handle_ingest\|handle_rebuild\|handle_import" agent-system/`;
      record that the check ran even where nothing needed repointing. *(completed: ran both;
      the only hits outside already-repointed locations are in commands/literature.md and
      agents/literature-agent.md, which name functions without claiming a location and remain
      accurate unchanged)*
- [x] Re-run the fence-aware `^## ` scan over the shortened `SKILL.md` to confirm the edits
      introduced no new fence-state imbalance or fake heading. *(completed: clean, 34 backticks,
      even)*
- [x] Walk the `case "$mode"` block (status, scan, convert, validate, index, search, ingest,
      rebuild, default) and confirm each arm reaches either an inline body or a stub whose pointer
      target exists and is non-empty. *(completed: all 8 arms confirmed)*
- [x] Record `SKILL.md` before/after bytes and lines, each destination file's bytes, and the
      total delta. *(completed: 100,460 B -> 17,386 B / 493 lines; recorded in
      progress/phase-3-progress.json)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts four remaining sections, four inbound cross-references,
and roughly eight inter-file handler couplings. Confirm the cross-reference counts by the fresh
repo-wide greps above rather than by this list; treat any additional hit as in scope for the
repoint.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — four more spans
  replaced; `Sub-Index Management`, `Error Handling`, `Standards Reference` cross-references
  repointed
- `.../patterns/literature-index-mode.md`, `literature-convert-mode.md`,
  `literature-validate-mode.md`, `literature-ingest-mode.md` — new
- `.../patterns/literature-rebuild-mode.md`, `literature-import-pipeline-mode.md` — handler
  cross-references repointed
- `agent-system/extensions/literature/index-entries.json` — four new entries

**Verification**:
- Round-trip diff per extraction, as in Phase 2.
- `grep -c branch-gated` is 0 in `SKILL.md`.
- Both cross-reference sweeps return no reference whose referent is absent from the file it
  appears in and unnamed by owning file.
- `SKILL.md` measured size is ~16 KB (100,460 B minus 84,308 B plus seven stubs), with the actual
  number recorded; the seven destination files together exceed 84,308 B (framing lines added).
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` clean for
  all seven literature entries; `bash agent-system/extensions/core/scripts/check-extension-docs.sh`
  reports no Rule T finding for the literature extension.

---

### Phase 4: Distill Extractions, Bottom-Up Part A — dream, learn, review, meta, revise [COMPLETED]

**Goal**: Extract the five lowest above-bar distill sub-mode sections, bottom-up, one green
sub-step each.

**Tasks**:
- [x] For each of `dream` (2255-2380), `learn` (2120-2254), `review` (2032-2119), `meta`
      (1832-2031), `revise` (1540-1831) — strictly in that order, re-reading before each:
  - [x] Mark with `<!-- branch-gated:begin condition="--<submode>" -->` /
        `<!-- branch-gated:end -->`, the end marker immediately above the next real `### `
        heading from Phase 1's map (never a fence-interior line such as 1495); confirm by read.
        *(deviation: altered -- same literal-text boundary location as Phase 2/3, without a
        physical marker-comment insertion step; additionally discovered and corrected for
        distill's own boundary irregularity: unlike literature's uniform blank/---/blank
        separator, distill separates sections by a variable 0-or-1 blank lines with no `---` at
        all -- the extraction tooling was extended with a `--no-dash-separator` mode rather than
        assuming the literature pattern held)*
  - [x] Create `agent-system/extensions/memory/context/project/memory/patterns/distill-<submode>-submode.md`
        (creating the `patterns/` subdirectory on the first one, mirroring the literature and
        email extensions' layout) with content verbatim, headings promoted one level uniformly
        (`###`->`#`, `####`->`##`, `#####`->`###`), preceded by the mandatory
        complete-and-only-specification framing line. *(completed: distill-dream-submode.md 129
        lines/5,773 B, distill-learn-submode.md 137 lines/6,172+ B, distill-review-submode.md 91
        lines, distill-meta-submode.md 203 lines, distill-revise-submode.md 295 lines; all five
        content-byte-extracted figures matched Phase 1's measured per-section bytes exactly;
        round-trip diffs verified clean, promotion-only)*
  - [x] Replace the marked span with the stub: the original `### Sub-Mode: <x>` heading plus
        `READ .claude/context/project/memory/patterns/distill-<submode>-submode.md now and follow it exactly.`
        *(completed for all five)*
  - [x] Repoint the extracted file's references to shared material that stayed in `SKILL.md` —
        `Shared Sub-Mode Skeleton`, `Scoring Engine`, `Health Report Template`,
        `Distill Log Schema` ("below"), `State Integration` ("below"), and `dream`'s
        `### Overlap Scoring` cross-reference — so each names `skill-distill/SKILL.md` explicitly
        instead of saying "above"/"below". *(deviation: altered -- all confirmed-cross-boundary
        "Shared Sub-Mode Skeleton above" and "Distill Log Schema below" occurrences repointed
        across all five files; meta's and revise's cross-sub-mode "above"/"below" references to
        each other repointed to their known destination filenames. The `dream`/revise
        `### Overlap Scoring` reference was investigated and found to be a PRE-EXISTING stale
        reference independent of this task -- no literal `### Overlap Scoring` heading exists
        anywhere in the current file (the nearest match is `#### Pairwise Keyword Overlap
        Algorithm` inside the not-yet-extracted `merge` section); left unchanged rather than
        guessing a repoint target, since inventing one risks a worse, confidently-wrong pointer.
        Several generic "every other sub-mode above" statements (not naming a specific heading)
        were also left unchanged as genuinely diffuse, multi-destination claims.)*
  - [x] Add the `index-entries.json` entry (`domain: "project"`, `subdomain: "memory"`,
        `load_when.commands: ["/distill"]`). *(completed: five entries added,
        `generate-context-line-counts.sh --check` clean)*
  - [x] Record before/after bytes; commit with an explicit file list. *(deviation: altered -- all
        five extractions committed together in one commit, matching the established Phase 2/3
        commit-granularity deviation)*
- [x] Preserve the MANDATORY STOP language verbatim in every mutating sub-mode's extracted file —
      it is the safety-bearing content of this surface and must survive the move unchanged.
      *(completed: 19 occurrences before == 19 after, exact byte-for-byte preservation confirmed
      by grep count across SKILL.md + the five new files)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts five sections at the spans above and that each one's
"above"/"below" references (dream 4, learn 2, review 5, meta 7, revise 9 occurrences) are
classifiable as intra-span or cross-boundary. Confirm every span by literal-marker read and every
occurrence by reading its sentence.

**Files to modify**:
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` — five spans replaced by stubs
- `agent-system/extensions/memory/context/project/memory/patterns/distill-dream-submode.md`,
  `distill-learn-submode.md`, `distill-review-submode.md`, `distill-meta-submode.md`,
  `distill-revise-submode.md` — new
- `agent-system/extensions/memory/index-entries.json` — five new entries

**Verification**:
- Round-trip diff per extraction (same recipe as Phase 2), differing only in framing block and
  intentional repoints.
- `grep -c branch-gated` is 0 in `SKILL.md` after each sub-step.
- `grep -c "MANDATORY STOP"` across the five new files plus the remaining `SKILL.md` equals the
  pre-extraction count in `git show HEAD~:<SKILL.md>`.
- `index-entries.json` parses; `generate-context-line-counts.sh --check` clean for the new entries.

---

### Phase 5: Distill Extractions Part B — refine, compress, merge, purge; Shared-Reference Repoint; Measurement [COMPLETED]

**Goal**: Finish the distill extraction set, fix the shared-skeleton wording that assumes every
sub-mode is in the same file, and record the measured reduction.

**Tasks**:
- [x] Extract bottom-up by the same per-section procedure: `refine` (1221-1441), `compress`
      (1024-1220), `merge` (770-1023), `purge` (317-505) — one green sub-step and commit each.
      *(completed: all four content-byte-extracted figures matched Phase 1's measured per-section
      bytes exactly; round-trip diffs verified clean. compress and merge each contained
      fence-interior fake headings (confirmed preserved untouched by the fence-aware promotion
      fix from Phase 3). Committed together in one commit, matching the established
      commit-granularity deviation from Phases 2-4.)*
- [x] Verify by direct read whether `Link-Scan Procedure` (506-559), `Retrieval Exclusion`
      (560-622), and `Health Report -- Tombstoned Memories Section` (623-647) are shared between
      `purge` and `gc` (which stays inline). If shared, leave all three inline and have
      `distill-purge-submode.md` name them as living in `skill-distill/SKILL.md`; if purge-only,
      note the finding and still leave them inline (they are below the extraction bar
      individually) with the same naming treatment. *(completed: confirmed SHARED -- GC Sub-Mode's
      own text explicitly states "with only its own tombstone-related Link-Scan/
      Retrieval-Exclusion/health-report infrastructure between them, no other sub-mode", naming
      all three. distill-purge-submode.md's framing paragraph names all three as staying in
      skill-distill/SKILL.md. GC's own inbound "Purge Sub-Mode above" reference was also
      repointed to name distill-purge-submode.md, since Purge moved out from under it.)*
- [x] Update `## Shared Sub-Mode Skeleton`'s wording: "each sub-mode's own section below" and
      "Non-mutating sub-modes ... each such sub-mode states this exemption explicitly in its own
      section" now refer to extracted files for the nine moved sub-modes; reword so a reader is
      sent to the stub pointers rather than told to look further down the file. *(completed: both
      passages reworded to name the extracted-file destinations explicitly for the nine moved
      sub-modes, while correctly leaving "below" references to Distill Log Schema/State
      Integration unchanged since those two stay inline in the same file, "below" remaining
      literally true)*
- [x] Confirm the `### Sub-Mode Dispatch` table (lines 29-47) still lists all twelve sub-modes and
      that each row's specification is reachable — inline for `report`, `gc`, `auto`; via stub
      pointer for the other nine. *(completed: all twelve confirmed; all nine extracted
      destination files confirmed non-empty)*
- [x] Fresh sweep: `grep -rn "Sub-Mode: \|Sub-Mode\b" agent-system/extensions/memory/` plus a
      repo-wide `grep -rn "skill-distill" agent-system/` to catch any external reference into a
      moved region; record that the check ran. *(completed: ran both. commands/distill.md's own
      "Validate Sub-Mode Availability" anchor table references heading text that is unchanged
      (every stub keeps its original heading), so it remains accurate without edits.
      context/project/memory/distill-usage.md's one "below" hit refers to its own internal
      document structure, not skill-distill/SKILL.md, and was left unchanged.)*
- [x] Re-run the fence-aware heading scan over the shortened `SKILL.md` to confirm no new
      fence-state imbalance. *(completed: 62 backticks, even)*
- [x] Record `SKILL.md` before/after bytes and lines, each destination file's bytes, the total
      delta, and the nine-file extraction sum against the planned 65,329 B. *(completed: SKILL.md
      93,044 B -> 30,289 B / 836 lines. Nine-file extraction sum: 64,329 B measured (matches
      Phase 1's corrected, re-summed total exactly; the plan's own "65,329" sum annotation
      remains the one confirmed arithmetic error, not a boundary error -- every individual
      per-item figure matched))*

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts four remaining sections, and that `Link-Scan Procedure`
/ `Retrieval Exclusion` / `Health Report -- Tombstoned Memories Section` are shared rather than
purge-only. The sharing claim is explicitly a hypothesis to confirm by reading `GC Sub-Mode`
(648-769) for references to them before deciding their disposition.

**Files to modify**:
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` — four more spans replaced;
  `Shared Sub-Mode Skeleton` wording updated
- `.../patterns/distill-refine-submode.md`, `distill-compress-submode.md`,
  `distill-merge-submode.md`, `distill-purge-submode.md` — new
- the five Phase 4 files — shared-reference naming only if the sweep finds a gap
- `agent-system/extensions/memory/index-entries.json` — four new entries

**Verification**:
- Round-trip diff per extraction.
- `grep -c branch-gated` is 0 in `SKILL.md`.
- All twelve `Sub-Mode Dispatch` rows resolve to a non-empty specification (inline body or
  existing non-empty pointer target).
- `SKILL.md` measured size is ~28 KB (93,044 B minus 65,329 B plus nine stubs), actual recorded.
- `generate-context-line-counts.sh --check` clean for all nine memory entries;
  `check-extension-docs.sh` reports no Rule T finding for the memory extension.

---

### Phase 6: Deploy, Full Gate Set, Acceptance Verification and Measured-Reduction Report [NOT STARTED]

**Goal**: Deploy the source store, pass the full gate set, verify every mode and sub-mode end to
end, and produce the measured-reduction report the acceptance criteria require.

**Tasks**:
- [ ] `bash .claude/scripts/deploy-headless.sh` (default non-destructive resync). Treat exit 3
      (deploy landed, fast gates failed) and exit 4 (verification suppressed) as failures to
      resolve, not as success.
- [ ] Confirm all sixteen destination files appear under `.claude/context/project/literature/patterns/`
      and `.claude/context/project/memory/patterns/`, and that
      `.claude/context/index.json` carries all sixteen rows.
- [ ] `bash .claude/scripts/verify-deploy.sh` (full, not `--skip-slow`); require Gate 19
      (`lint-branch-gated-sections.sh --verbose`) to pass and no orphan/ghost-row finding.
- [ ] `bash .claude/scripts/validate-context-index.sh` — all sixteen paths resolve, line counts
      accurate, domain values valid.
- [ ] Acceptance walk, recorded per entry: each of the nine literature modes (status, scan,
      convert, validate, index, search, ingest, rebuild, plus the search-driven import flow) and
      each of the twelve distill sub-modes (report, purge, merge, compress, refine, gc, auto,
      revise, meta, review, learn, dream) reaches a non-empty specification; for a pointer, the
      deployed target path exists, is non-empty, and opens with its complete-and-only-
      specification framing line.
- [ ] Measured-reduction report: before/after bytes and lines for both `SKILL.md` files; each
      destination file's bytes; per-command per-invocation loaded-byte totals
      (`commands/<cmd>.md` + `SKILL.md` + the one selected mode/sub-mode file) before and after;
      the ~4 B/token conversion for each; and an explicit reconciliation note stating that the
      task's 46.2k and 42.4k figures are whole-invocation token baselines including ambient
      context (rules, memory/literature injection) that this task does not change, so the
      honest claim is the byte-exact delta on the surfaces actually edited.
- [ ] Record the corrected distill premise in the implementation summary so the 43,254 B figure
      is not carried forward by a future reader.
- [ ] Final commit (`task 89: complete implementation`) with an explicit file list.

**Timing**: 1.5 hours

**Depends on**: 3, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the projected post-state (`skill-literature/SKILL.md` ~16 KB,
`skill-distill/SKILL.md` ~28 KB, sixteen new context files, ~149,637 B relocated) is a
projection. Report only measured values; where a measured value diverges from the projection,
state both and explain the difference rather than restating the projection.

**Files to modify**:
- `.claude/**` via `deploy-headless.sh` only (regenerated deploy artifact, not hand-authored)
- `specs/089_mode_gate_literature_and_distill_skills/summaries/01_*-summary.md` — measurement and
  acceptance record
- `specs/state.json` / `specs/TODO.md` via the sanctioned status-update scripts

**Verification**:
- `verify-deploy.sh` exits 0 with Gate 19 passing.
- `validate-context-index.sh` reports zero errors.
- The acceptance walk shows 9/9 literature modes and 12/12 distill sub-modes resolving to a
  non-empty specification.
- The measured-reduction report contains actual `wc -c` numbers for every file named, with no
  figure carried over unmeasured from the task description.

## Testing & Validation

- [ ] Round-trip fidelity: for each of the sixteen extractions, a diff of the pre-extraction span
      against the destination file's de-promoted body shows no lost, added, or reordered content
      line beyond the framing block and the enumerated repoints.
- [ ] Zero `branch-gated:` markers remain anywhere in either `SKILL.md` at task completion.
- [ ] Gate 19 (`lint-branch-gated-sections.sh --verbose`) passes, both standalone and inside
      `verify-deploy.sh`.
- [ ] `check-extension-docs.sh` reports no Rule T finding for the literature or memory extension.
- [ ] `generate-context-line-counts.sh --check` reports no `line_count` mismatch.
- [ ] `validate-context-index.sh` resolves all sixteen new paths after deploy.
- [ ] Every one of the nine literature modes and twelve distill sub-modes reaches a non-empty
      specification (inline or via an existing, non-empty, imperatively-pointed file).
- [ ] No cross-reference anywhere in `agent-system/extensions/{literature,memory}/` names a mode,
      sub-mode, or handler whose specification is absent from the referencing file and unnamed by
      owning file.
- [ ] `MANDATORY STOP` occurrence count is preserved across the distill extraction.
- [ ] `git log --oneline` shows one commit per green sub-step, each with an explicit file list and
      no directory or glob `git add`.

## Artifacts & Outputs

- Seven new files under
  `agent-system/extensions/literature/context/project/literature/patterns/literature-{ingest,validate,convert,index,search,import-pipeline,rebuild}-mode.md`
- Nine new files under
  `agent-system/extensions/memory/context/project/memory/patterns/distill-{purge,merge,compress,refine,revise,meta,review,learn,dream}-submode.md`
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` reduced to ~16 KB with
  seven stub pointers
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` reduced to ~28 KB with nine stub
  pointers
- Sixteen new `index-entries.json` entries across the two extensions
- `specs/089_mode_gate_literature_and_distill_skills/summaries/01_*-summary.md` carrying the
  measured-reduction report, the acceptance walk, and the corrected distill premise

## Rollback/Contingency

- Each extraction is one commit, so reverting a single bad extraction is `git revert <sha>` with
  no other work lost. Because the destination file, the stub, and the index entry land in the same
  commit, a revert never leaves a stub pointing at a missing file.
- Before any intentional rollback of uncommitted work, take a non-reverting checkpoint:
  `bash .claude/scripts/git-snapshot.sh 89 --no-revert`. The default reverting form is for a
  genuine rollback only.
- If a round-trip diff cannot be made clean for a given section (content proves to be
  genuinely shared rather than branch-only), abandon that one extraction, restore the span from
  `git show`, record the finding, and continue with the rest — the convention's "When NOT to
  Extract" rules make a reasoned exclusion a legitimate outcome, not a failure.
- If `deploy-headless.sh` exits 3, the tree was modified: resolve the failing gate and re-run
  rather than reverting the source-store commits.
- Four sibling tasks are live on this tree this cycle, all in `extensions/core/**` and
  `extensions/epidemiology/**`. If a foreign commit or foreign uncommitted modification appears
  in `extensions/{literature,memory}/**`, stop and report after checking `git log` to confirm it
  is not this task's own work — do not revert it.
