# Implementation Plan: Task #399 - Consolidate slides.md command

- **Task**: 399 - Consolidate slides commands
- **Created**: 2026-04-10T00:00:00Z
- **Status**: [IMPLEMENTING]
- **Effort**: 3-5 hours
- **Dependencies**: None
- **Research**: specs/399_consolidate_slides_commands/reports/01_consolidate-slides-commands.md
- **Research Inputs**: specs/399_consolidate_slides_commands/reports/01_consolidate-slides-commands.md
- **Artifacts**: plans/01_consolidate-slides-commands.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, plan-format-enforcement.md
- **Type**: meta
- **Lean Intent**: false

## Executive Summary

Fold `.claude/extensions/filetypes/commands/slides.md` into `.claude/extensions/filetypes/commands/convert.md` (adding `--format beamer|polylux|touying` and `--theme` support with conditional dispatch to `skill-presentation` when source is `.pptx`/`.ppt` with a slide output format). Delete the old `slides.md`. Then rename `.claude/extensions/present/commands/talk.md` to `.claude/extensions/present/commands/slides.md` and update all cross-references in both extensions' manifests, docs, skills, agents, and index-entries. The two operations are sequenced so the `/slides` namespace is vacated in filetypes before it is claimed by present, avoiding transient symlink collisions.

## Context & Goals

### Research Integration

The research report (01_consolidate-slides-commands.md) recommends folding into `convert.md` because slides.md and convert.md live in the same extension, share the same command shape (`SOURCE [OUTPUT]`), and both delegate to file-converter skills. Folding into `talk.md` was rejected because talk.md is a stateful task-lifecycle creator (mutates state.json/TODO.md, runs forcing questions, produces Slidev decks), not a stateless file converter. The report catalogs ~25-30 reference sites across 19 files, including manifests, EXTENSION.md, README.md, index-entries.json (6 entries in filetypes), conversion-tables.md, skill-presentation/SKILL.md, and several present-extension counterparts. It also identifies a symlink-collision risk during partial updates that drives phase ordering: filetypes fold must complete (and symlinks regenerate) before present rename takes effect.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

### Goals

- Fold `filetypes/commands/slides.md` into `filetypes/commands/convert.md` preserving all functionality (Beamer/Polylux/Touying output, `--format`, `--theme`, python-pptx+pandoc dispatch).
- Delete `filetypes/commands/slides.md`.
- Rename `present/commands/talk.md` -> `present/commands/slides.md` and rewrite internal `/talk` references.
- Update every manifest, EXTENSION.md, README.md, index-entries, skill, and agent cross-reference so doc-lint (`check-extension-docs.sh`) passes with zero failures.
- Sequence the operations to avoid transient `/slides` symlink collision if both extensions are ever loaded simultaneously mid-change.

### Non-Goals

- Renaming `talk-agent` to `slides-agent` or `skill-talk` to `skill-slides` (task does not request this; leaves internal naming as-is).
- Updating historical task artifacts under `specs/*` or `archive/*`.
- Updating founder extension `slides.md` references (those are Slidev content filenames, unrelated to the `/slides` slash command).
- Adding new functionality beyond what slides.md already provided.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Symlink collision - both extensions claiming `/slides` mid-change | H | M | Sequence phases: delete filetypes slides.md and update its manifest BEFORE renaming talk.md -> slides.md; commit filetypes fold as one atomic unit, present rename as a separate atomic unit |
| `check-extension-docs.sh` doc-lint failure | M | H | Apply all manifest + README + source file edits for each extension as a single commit; run the script as verification gate in Phase 6 |
| Loss of functionality (forgetting `--theme` or `--format touying`) during fold | H | M | Explicit checklist in Phase 1 comparing slides.md arg parsing and dispatch block against convert.md extension; preserve all options |
| Stale orphan symlink at `.claude/commands/slides.md` after old manifest uninstall | M | L | Phase 2 explicitly removes `.claude/commands/slides.md` symlink if present before any reinstall |
| User muscle-memory confusion (`/slides foo.pptx` = old converter) | M | H | Phase 4 adds migration note to present/README.md pointing to `/convert --format=beamer` for pptx extraction |
| `skill-presentation` SKILL.md trigger still names `/slides` | M | H | Phase 2 updates skill-presentation/SKILL.md:25 explicitly |
| Missed grep variant (linked references, escaped slashes) | M | M | Phase 6 re-runs `rg '/slides\b' .claude/` and `rg '/talk\b' .claude/` with exclusions for specs/ and archive/ |
| `filetypes/index-entries.json` over- or under-loads context after `/slides` -> `/convert` replacement | L | M | Phase 2 re-reads each entry to confirm paths remain semantically appropriate for `/convert` domain |
| `talk-agent.md` name mismatch with `/slides` command causes confusion | L | L | Phase 4 documents the intentional preservation in present/README.md |

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

All phases are sequential: each depends on the file-state established by the previous phase. No parallelism is safe because phases 1-2 vacate the `/slides` namespace and phases 3-4 reclaim it; interleaving risks symlink collision and doc-lint failure.

---

### Phase 1: Fold slides.md into convert.md [COMPLETED]

**Goal**: Extend `convert.md` with slides.md's argument parsing, format/theme flags, and conditional delegation to `skill-presentation`, so `/convert` fully absorbs `/slides` functionality.

**Files**:
- `.claude/extensions/filetypes/commands/convert.md` (modify)

**Steps**:
1. Update frontmatter `description:` to `Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF, PPTX to Beamer/Polylux/Touying)`.
2. Update frontmatter `argument-hint:` to `SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying] [--theme NAME]`.
3. Update title line 7 and overview paragraph to mention slide-format output.
4. Extend Arguments section (lines 11-14) with `--format` and `--theme` entries copied from `slides.md:15-16`.
5. Append slide-conversion examples from `slides.md:18-35` into convert.md's Usage Examples section (lines 16-33).
6. Extend Supported Conversions table (convert.md:36-45) with three rows: `PPTX | Beamer | python-pptx + pandoc`, `PPTX | Polylux | python-pptx -> Typst`, `PPTX | Touying | python-pptx -> Typst`.
7. Remove convert.md:47 note `For presentation conversions, use /slides.` (replace with a note that spreadsheet-to-table still goes through `/table`).
8. Extend GATE IN argument parser (convert.md:58-74) to parse `--format` and `--theme` flags using the slides.md parser block as a template (slides.md:77-102). Keep positional `source_path` and `output_path` detection.
9. Add output-path inference for slide formats: when source is `.pptx`/`.ppt` AND `--format` is set, infer `.tex` (beamer/latex) or `.typ` (polylux/touying). Integrate into the existing `Determine Output Path` block (convert.md:84-110) by adding new case arms alongside the `pdf|docx|xlsx|pptx|html|...` branch.
10. Add output-format validation block (adapted from slides.md:160-170) after source-format validation.
11. Modify STAGE 2 DELEGATE (convert.md:116-128): add a conditional -- if source extension is `pptx`/`ppt` AND `--format` is in `{beamer,polylux,touying}`, invoke `skill-presentation` with args `source_path={source_path} output_path={output_path} output_format={output_format} theme={theme} session_id={session_id}`; otherwise invoke the existing `skill-filetypes`.
12. Extend the CHECKPOINT 2 GATE OUT metadata validation (convert.md:132) to note that `slide_count` is expected when the slide dispatch path was taken.
13. Update the Unsupported format error message (convert.md:223-227) to list `pptx (with --format for slide output)`.
14. Update DELEGATE Failure block (convert.md:229-247) to include the python-pptx/pandoc installation hint from slides.md:288-299 when slide dispatch is taken.

**Verification**:
- `convert.md` contains the string `--format beamer|polylux|touying` in its frontmatter.
- `convert.md` contains the string `skill-presentation` in STAGE 2.
- `grep -n 'use /slides' .claude/extensions/filetypes/commands/convert.md` returns nothing.
- All four output formats (markdown, pdf, tex, typ) appear in path-inference logic.
- File is still valid markdown with consistent heading levels.

---

### Phase 2: Delete slides.md and update filetypes extension metadata [COMPLETED]

**Goal**: Remove `filetypes/commands/slides.md` from the repo and the filetypes extension's manifest/docs/index, update `skill-presentation` trigger, and scrub the filetypes extension of all `/slides` command references.

**Files**:
- `.claude/extensions/filetypes/commands/slides.md` (delete)
- `.claude/extensions/filetypes/manifest.json` (modify)
- `.claude/extensions/filetypes/EXTENSION.md` (modify)
- `.claude/extensions/filetypes/README.md` (modify)
- `.claude/extensions/filetypes/index-entries.json` (modify)
- `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` (modify)
- `.claude/extensions/filetypes/context/project/filetypes/README.md` (modify)
- `.claude/extensions/filetypes/skills/skill-presentation/SKILL.md` (modify)
- `.claude/commands/slides.md` (delete if exists as symlink)

**Steps**:
1. `rm .claude/extensions/filetypes/commands/slides.md`.
2. If `.claude/commands/slides.md` exists (as a symlink from prior install), `rm` it to avoid orphaned symlink.
3. Edit `filetypes/manifest.json:26` - remove the `"slides.md"` entry from `provides.commands` array (keep array valid JSON).
4. Edit `filetypes/EXTENSION.md:22` - remove the `/slides` row from the commands table; optionally annotate the `/convert` row to mention pptx slide-format support.
5. Edit `filetypes/README.md`:
   - Line 13: remove `/slides` row from command table.
   - Lines 79-90: remove the `/slides` section entirely; expand `/convert` section nearby to mention beamer/polylux/touying.
   - Line 128: remove `slides.md` entry from directory tree listing.
   - Line 208: remove or merge the `/slides` row in the outputs table into the `/convert` row.
6. Edit `filetypes/index-entries.json` - at lines 20, 45, 98, 120, 143, 167, replace `"/slides"` with `"/convert"` in `load_when.commands` arrays. If the entry already has `"/convert"`, simply remove the `"/slides"` element rather than duplicating.
7. Edit `filetypes/context/project/filetypes/domain/conversion-tables.md`:
   - Line 23: change heading `## Presentation Conversions (via /slides)` to `## Presentation Conversions (via /convert)`.
   - Lines 68-70: update example commands from `/slides ...` to `/convert ... --format beamer`.
   - Lines 125, 129: same command example updates.
8. Edit `filetypes/context/project/filetypes/README.md`:
   - Line 45: update `/slides` reference.
   - Line 61: update path reference to drop slides.md.
   - Line 86: update command example from `/slides` to `/convert --format`.
9. Edit `filetypes/skills/skill-presentation/SKILL.md:25` - change trigger `User explicitly runs /slides command` to `User runs /convert with pptx source and --format beamer|polylux|touying`.

**Verification**:
- `test ! -f .claude/extensions/filetypes/commands/slides.md` (file absent).
- `jq '.provides.commands | index("slides.md")' .claude/extensions/filetypes/manifest.json` returns `null`.
- `rg '/slides\b' .claude/extensions/filetypes/` returns zero matches (or only matches on intentional migration notes pointing to `/convert`).
- `rg 'slides\.md' .claude/extensions/filetypes/manifest.json` returns nothing.
- `rg '"/slides"' .claude/extensions/filetypes/index-entries.json` returns nothing.

---

### Phase 3: Rename talk.md to slides.md [COMPLETED]

**Goal**: Move `present/commands/talk.md` to `present/commands/slides.md` and rewrite internal `/talk` slash-command references inside the file.

**Files**:
- `.claude/extensions/present/commands/talk.md` -> `.claude/extensions/present/commands/slides.md` (rename)

**Steps**:
1. `git mv .claude/extensions/present/commands/talk.md .claude/extensions/present/commands/slides.md` (preserves history).
2. Edit the new `slides.md`:
   - Line 8: change `# /talk Command` to `# /slides Command`.
   - Lines 18-21: replace `/talk "..."`, `/talk 500`, `/talk /path/...`, `/talk 500 --design` with `/slides ...` equivalents.
   - Line 286: update `Next: /talk {N} --design` to `Next: /slides {N} --design`.
   - Line 311: update error message `Run /talk $task_number first` to `Run /slides $task_number first`.
   - Line 440: update error guidance `suggesting /talk for talk tasks` to `suggesting /slides for talk tasks`.
   - Leave frontmatter `description:` and `allowed-tools:` unchanged (description still describes the function; only command surface name changes).
3. Do NOT change internal variable names like `input_type="task_number"` or state fields like `task_type: "talk"` -- those are data-layer identifiers, not command surface.

**Verification**:
- `test -f .claude/extensions/present/commands/slides.md` (file exists).
- `test ! -f .claude/extensions/present/commands/talk.md` (old file gone).
- `rg '^# /talk Command' .claude/extensions/present/commands/slides.md` returns nothing.
- `rg '/talk\b' .claude/extensions/present/commands/slides.md` returns zero matches.
- `git log --follow .claude/extensions/present/commands/slides.md` shows history from the old talk.md (confirms git mv).

---

### Phase 4: Update present extension metadata and cross-references [NOT STARTED]

**Goal**: Update present extension's manifest, EXTENSION.md, README.md, index-entries, skill-talk, agent, and domain docs to reflect the rename from `/talk` to `/slides`.

**Files**:
- `.claude/extensions/present/manifest.json` (modify)
- `.claude/extensions/present/EXTENSION.md` (modify)
- `.claude/extensions/present/README.md` (modify)
- `.claude/extensions/present/index-entries.json` (modify)
- `.claude/extensions/present/skills/skill-talk/SKILL.md` (modify)
- `.claude/extensions/present/agents/talk-agent.md` (modify)
- `.claude/extensions/present/context/project/present/domain/presentation-types.md` (modify)

**Steps**:
1. Edit `present/manifest.json:10` - change `"talk.md"` to `"slides.md"` in `provides.commands`.
2. Edit `present/EXTENSION.md:29-31` - rename `/talk` -> `/slides` in all three commands table rows.
3. Edit `present/README.md`:
   - Line 21: rename `/talk` -> `/slides` in commands table row.
   - Line 69: rename section header `/talk Command` -> `/slides Command`.
   - Lines 74-76: rename `/talk` usage examples -> `/slides`.
   - Add a brief migration note: `Note: This command was previously named /talk. For PPTX slide conversion (not research talk creation), use /convert --format=beamer.`
4. Edit `present/index-entries.json`:
   - Line 350: replace `"/talk"` with `"/slides"` in `load_when.commands`.
   - Line 364: same replacement.
5. Edit `present/skills/skill-talk/SKILL.md`:
   - Line 34: change `/talk command with task number` to `/slides command with task number`.
   - Line 50: change `--design workflow handled at command level (talk.md)` to `--design workflow handled at command level (slides.md)`.
   - Line 303: change `Use /talk for talk-type tasks` to `Use /slides for talk-type tasks`.
   - Do NOT rename the skill itself (still `skill-talk`).
6. Edit `present/agents/talk-agent.md`:
   - `rg '/talk\b' .claude/extensions/present/agents/talk-agent.md` to find slash-command references.
   - Replace any `/talk` slash-command references with `/slides`.
   - Preserve path references like `talks/{N}_...` (those are artifact directory names, not command references).
7. Edit `present/context/project/present/domain/presentation-types.md:3` - change `the /talk command` to `the /slides command`.
8. Add a parallel compatibility note in `filetypes/context/project/filetypes/domain/conversion-tables.md` (near the presentation section): `Note: /slides in the present extension is a distinct research-talk task-creation command; for PPTX file conversion, use /convert --format=beamer.`

**Verification**:
- `jq '.provides.commands' .claude/extensions/present/manifest.json` shows `slides.md` not `talk.md`.
- `rg '/talk\b' .claude/extensions/present/` excluding history/artifacts returns zero matches.
- `rg '"/talk"' .claude/extensions/present/index-entries.json` returns zero matches.
- README migration note is present.

---

### Phase 5: Update remaining cross-references outside both extensions [NOT STARTED]

**Goal**: Catch any residual `/slides` or `/talk` slash-command references in top-level `.claude/` docs, standards, and context files, and update or clarify them as needed.

**Files**:
- `.claude/docs/reference/standards/extension-slim-standard.md` (modify, cosmetic)
- `.claude/docs/guides/user-guide.md` (modify, optional expansion)
- `.claude/context/patterns/context-discovery.md` (review, may not need changes)
- `.claude/context/architecture/system-overview.md` (review, may not need changes)
- Any other files surfaced by grep in Phase 5 Step 1

**Steps**:
1. Run `rg -n '/slides\b|/talk\b' .claude/ --glob '!extensions/filetypes/**' --glob '!extensions/present/**' --glob '!specs/**' --glob '!archive/**'` to surface residual references.
2. For each hit, classify:
   - **Keep**: `/slides` references now correctly describe the present extension's renamed command (e.g., context-discovery.md:250-251 domain command list).
   - **Update**: References to old filetypes `/slides` converter should become `/convert --format=...`.
   - **Clarify**: Ambiguous references get a short note disambiguating filetypes vs present.
3. Edit `.claude/docs/reference/standards/extension-slim-standard.md:116` - if the sample table row references `/slides`, update the example to show `/convert` for filetypes.
4. Edit `.claude/docs/guides/user-guide.md:462-484` - optionally expand the `/convert` section with beamer/polylux/touying examples (adds discoverability).
5. Leave `.claude/context/architecture/system-overview.md:408` alone (only mentions `/convert` generically).
6. Leave `.claude/context/patterns/context-discovery.md:250-251` alone -- `/slides` still appears in the domain-command list, now owned by the present extension.

**Verification**:
- `rg -n '/slides\b' .claude/ --glob '!extensions/**' --glob '!specs/**' --glob '!archive/**'` output matches expected set (only present-extension-owned mentions remain).
- `rg -n '/talk\b' .claude/ --glob '!specs/**' --glob '!archive/**'` returns zero matches (or only historical commit-log references, not live doc references).

---

### Phase 6: Verification and doc-lint [NOT STARTED]

**Goal**: Run the repository's doc-lint script, perform residual-reference grep, and confirm both extensions still validate cleanly.

**Files**:
- None modified (verification only); possible small fixups to any files flagged.

**Steps**:
1. Run `.claude/scripts/check-extension-docs.sh` and capture output. It validates manifests against on-disk command files and checks README mentions against manifest entries.
2. If the script exits non-zero, inspect the failure messages, apply targeted fixes, and re-run. Common fixes: missing README mention of a renamed command, stale manifest entry, missing file referenced by manifest.
3. Run `rg -n '/slides\b' .claude/ --glob '!specs/**' --glob '!archive/**'` and verify each hit is in an expected location (present extension or compatibility note).
4. Run `rg -n '/talk\b' .claude/ --glob '!specs/**' --glob '!archive/**'` and verify zero live doc hits.
5. Run `rg -n 'filetypes/commands/slides' .claude/ --glob '!specs/**' --glob '!archive/**'` to catch lingering path references; expect zero.
6. Run `rg -n 'present/commands/talk\.md' .claude/ --glob '!specs/**' --glob '!archive/**'` to catch lingering renamed-file path references; expect zero.
7. If `.claude/scripts/validate-extension-index.sh` exists, run it to validate index-entries.json structure for both extensions.
8. Verify the two extensions can be re-installed cleanly: review `.claude/scripts/install-extension.sh` behavior for both filetypes and present (symlink creation should succeed without collision since only present now provides `slides.md`).
9. Spot-check `convert.md` by reading it end-to-end to confirm frontmatter, argument parsing, dispatch logic, and error messages are coherent.
10. Spot-check new `present/commands/slides.md` by reading it end-to-end to confirm all `/talk` rewrites landed.

**Verification**:
- `check-extension-docs.sh` exits 0.
- All residual grep checks return expected results.
- Both `convert.md` and `present/commands/slides.md` read cleanly without dangling references or broken examples.
- Manifests and their on-disk commands are consistent.

---

## Testing & Validation

- [ ] `check-extension-docs.sh` passes with no warnings or errors for both filetypes and present extensions.
- [ ] `rg '/slides\b|slides\.md' .claude/extensions/filetypes/` returns only compatibility-note hits (no command definitions or manifest entries).
- [ ] `rg '/talk\b|talk\.md' .claude/extensions/present/` returns only `skill-talk`, `talk-agent`, or `talks/` path hits (all intentional preservations of internal naming).
- [ ] `convert.md` frontmatter lists `--format beamer|polylux|touying` in `argument-hint`.
- [ ] `convert.md` STAGE 2 contains conditional dispatch to `skill-presentation`.
- [ ] `present/commands/slides.md` exists; `present/commands/talk.md` does not.
- [ ] `filetypes/commands/slides.md` does not exist; `filetypes/commands/convert.md` does.
- [ ] Both manifests (`filetypes/manifest.json`, `present/manifest.json`) are valid JSON and their `provides.commands` arrays match on-disk files.
- [ ] `git log --follow .claude/extensions/present/commands/slides.md` shows full history from the pre-rename `talk.md`.

## Artifacts & Outputs

- Modified `.claude/extensions/filetypes/commands/convert.md` with folded slides functionality.
- Deleted `.claude/extensions/filetypes/commands/slides.md`.
- Renamed `.claude/extensions/present/commands/talk.md` -> `.claude/extensions/present/commands/slides.md`.
- Updated manifests, EXTENSION.md, README.md, index-entries.json, skill docs, agent docs, and domain docs across both extensions.
- Optional: updated `.claude/docs/reference/standards/extension-slim-standard.md` and `.claude/docs/guides/user-guide.md` sample text.
- Verification output from `check-extension-docs.sh`.

## Rollback Strategy

Each phase should be a separate git commit so rollback is granular:
- Commit A (Phases 1-2): filetypes fold + delete. Revert with `git revert {A}` to restore `slides.md` and roll back convert.md changes.
- Commit B (Phases 3-4): present rename + cross-refs. Revert with `git revert {B}` to restore `talk.md` and roll back present updates.
- Commit C (Phases 5-6): residual cross-refs + verification fixups. Revert with `git revert {C}`.

If rollback is needed mid-task, the key invariant is that the `/slides` symlink in `.claude/commands/` must match at most one extension's manifest. Run the uninstall/reinstall script for both extensions after any revert to resync symlinks.

## Appendix: References

- Research report: `specs/399_consolidate_slides_commands/reports/01_consolidate-slides-commands.md`
- Source files reviewed:
  - `.claude/extensions/filetypes/commands/slides.md` (308 lines)
  - `.claude/extensions/filetypes/commands/convert.md` (259 lines)
  - `.claude/extensions/present/commands/talk.md` (478 lines)
- Standards consulted:
  - `.claude/rules/workflows.md` (command lifecycle)
  - `.claude/rules/error-handling.md`
  - `.claude/rules/plan-format-enforcement.md`
  - `.claude/docs/reference/standards/extension-slim-standard.md`
- Scripts used for verification:
  - `.claude/scripts/check-extension-docs.sh` (doc-lint)
  - `.claude/scripts/install-extension.sh` (symlink regeneration)
