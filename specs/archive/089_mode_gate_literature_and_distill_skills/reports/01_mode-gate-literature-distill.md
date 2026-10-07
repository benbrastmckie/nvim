# Research Report: Task #89

**Task**: 89 - Apply mode-gated section convention to skill-literature and skill-distill
**Started**: 2026-10-02T00:00:00Z
**Completed**: 2026-10-02T00:00:00Z
**Effort**: medium (mechanical split across two files, 8 extractions total, several cross-reference repoints)
**Dependencies**: 87 (pilot: skill-email-cleanup mode-gated extraction)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/literature/skills/skill-literature/SKILL.md`,
  `agent-system/extensions/memory/skills/skill-distill/SKILL.md`,
  `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md`,
  `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh`,
  `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md` (pilot
  precedent), `agent-system/extensions/{literature,memory}/manifest.json`
- `specs/state.json` task 89 entry (original description/baseline figures)
**Artifacts**:
- This report: `specs/089_mode_gate_literature_and_distill_skills/reports/01_mode-gate-literature-distill.md`
**Standards**: report-format.md, subagent-return.md, mode-gated-section-loading.md

## Executive Summary

- The formalized convention (`context/patterns/mode-gated-section-loading.md`, piloted on
  `skill-email-cleanup/SKILL.md` in task 87) applies cleanly to both target files. Both are
  extension-owned surfaces, so per the convention's **Path Selection Rule** both extractions
  belong under their own extension's `context/project/<ext>/` subtree — **not**
  `.claude/context/formats/`, despite task 89's own description text suggesting that path for
  distill (see Decisions below).
- **`skill-literature/SKILL.md` has grown since task 89 was filed**: actual current size is
  100,460 B, not the 84,265 B baseline in the task description (created 2026-08-24, last touched
  2026-10-03). The seven target mode sections now total **84,308 B (83.9% of the current file)**,
  up from the ~65,772 B/78% originally estimated — the extraction is now worth measurably more
  than when the task was authored, not less.
- `skill-distill/SKILL.md` is byte-identical to its task-89 baseline (93,044 B); the one target
  section, `## Auto Distill Complete`, is confirmed at exactly 43,254 B (46.5%), matching the
  task description precisely.
- The **fence-interior heading hazard** flagged in the task description is real and verified: six
  lines inside unlabeled ` ``` ` example-output fences in `skill-literature/SKILL.md` start with
  `## ` (`## Literature Status`, `## Literature Scan Results` ×2, `## Literature Validation
  Report`, `## Conversion Complete`, `## Index Entry Added`). A boundary scan keyed on "next `##`
  line" rather than "next `## Mode:` line" misplaces several mode-section boundaries. The
  `skill-distill/SKILL.md` extraction has no such hazard — the target heading occurs exactly once
  in the file and is already the last section (clean tail-cut to EOF).
- Three prose cross-references point from the parts of `skill-literature/SKILL.md` that stay
  inline (the shared `Error Handling` section) into mode sections that will move (`Mode: Rebuild`
  ×2, `Mode: Convert` ×2 — one line references both). These need repointing to the new file paths
  after extraction. `skill-distill/SKILL.md` has zero external cross-references into `Auto
  Distill Complete` — it is the simpler of the two extractions.
- Recommended approach for `skill-literature`: extract the seven modes in the task's enumerated
  list (Ingest, Validate, Convert, Index, Search, Import Pipeline, Rebuild) to
  `agent-system/extensions/literature/context/project/literature/patterns/<mode>-mode.md`, one
  file per mode, following the email pilot's framing-line and pointer wording exactly. Leave
  `Mode: Status (Default)` and `Mode: Scan` inline (default branch and below-threshold,
  respectively) and leave the shared `Sub-Index Management` / `Error Handling` / `Standards
  Reference` sections inline (genuinely cross-mode, referenced from multiple modes).

## Context & Scope

Task 89 asks for the mode-gated section-loading convention — formalized in
`context/patterns/mode-gated-section-loading.md` and proven on `skill-email-cleanup/SKILL.md`
(task 87, dependency of this task) — to be applied to the two next-largest instances of the
same problem: `skill-literature/SKILL.md` (seven independent, mutually-exclusive `## Mode: X`
sections) and `skill-distill/SKILL.md` (one large `--auto`-only output template). This research
phase verifies the task description's figures against the live files, confirms the convention's
mechanics apply without modification, locates every extraction boundary precisely (accounting
for the fence-interior heading hazard), and surfaces the cross-reference and path-selection
decisions the planning phase needs to resolve before dispatching implementation.

Out of scope (not requested by task 89, not investigated beyond noting their existence):
`Mode: Status`, `Mode: Scan`, `Sub-Index Management`, `Error Handling`, and `Standards Reference`
in `skill-literature/SKILL.md` — these stay inline per the convention's "When NOT to Extract"
rules and are discussed only to confirm that exclusion is correct, not to plan their extraction.

## Findings

### Convention Mechanics (from task 87's pilot, reused verbatim)

`context/patterns/mode-gated-section-loading.md` defines:
- A paired `<!-- branch-gated:begin condition="..." -->` / `<!-- branch-gated:end -->` marker,
  chosen specifically because a single "find the next `##` heading" scan is corrupted by
  fence-interior heading-shaped text (see below) — the paired marker's end is wherever the
  literal end-marker string is, independent of what's inside the span.
- A 7-step extraction procedure: mark, re-locate boundaries by literal marker text, create the
  destination file (promoting heading levels by one, with a mandatory "this is the complete and
  only specification" opening line), replace the marked span with an imperative `READ ... now and
  follow it exactly.` pointer, register the destination in `index-entries.json`, re-check inbound
  cross-references, measure and record before/after bytes.
- Bottom-up ordering when multiple sections in one file are extracted in one pass (process the
  last section first so earlier line numbers don't shift).
- A **Path Selection Rule**: core-owned surfaces extract to
  `agent-system/extensions/core/context/patterns/<name>.md`; extension-owned surfaces extract to
  that extension's own provided context subtree (e.g.
  `agent-system/extensions/email/context/project/email/patterns/<name>.md`). Pointers always use
  the deployed path form (`.claude/context/...`).
- Enforcement via `scripts/lint/lint-branch-gated-sections.sh` (wired as `verify-deploy.sh` Gate
  19): sums all marked spans in a file and fails above an 8,000 B threshold — a file with several
  small marked sections that sum above threshold fails even if no single section does.

The pilot, `skill-email-cleanup/SKILL.md`'s `` `--all` Mode `` section: 47,832 B → 30,656 B
(-35.9%), extracted to `email-cleanup-all-mode.md` (17,729 B). Its
`index-entries.json` entry and its `READ ... now and follow it exactly.` pointer are the direct
templates to replicate for both files in this task.

### `skill-literature/SKILL.md` — current structure and measured sizes

Source: `agent-system/extensions/literature/skills/skill-literature/SKILL.md`, currently
**100,460 B** (2,574 lines) — up from the 84,265 B recorded in the task description at authoring
time (2026-08-24). The file's own mode dispatch (`## Execution` → Step 4, lines 78-97) is a
literal `case "$mode" in status|scan|convert|validate|index|search|ingest|rebuild|*)` — eight
real modes plus the default, confirming the mutual-exclusivity premise the convention requires.

**Fence-interior heading hazard, verified**: scanning for `^## ` lines while tracking ` ``` `
fence state (rather than scanning line-start matches blindly) shows six false positives, all
inside unlabeled example-output fences:

| Line | Fake heading text | Real containing mode |
|------|--------------------|----------------------|
| 239 | `## Literature Status` | `Mode: Status` (not extracted) |
| 315, 334 | `## Literature Scan Results` | `Mode: Scan` (not extracted) |
| 644 | `## Literature Validation Report` | `Mode: Validate` |
| 1291 | `## Conversion Complete` | `Mode: Convert` |
| 1483 | `## Index Entry Added` | `Mode: Index` |

A line-start `## ` scan without fence tracking would treat these as real section boundaries and
truncate `Mode: Validate`, `Mode: Convert`, and `Mode: Index` far too early (e.g. it would end
`Mode: Validate` at line 643 instead of its real end at line 729, losing 86 lines of the mode's
own validation-report-template content). The correct boundary for every mode is **the next real
`## Mode: X` heading**, not the next `## `-prefixed line of any kind. All measurements below use
that corrected boundary (verified by direct read of the span, per the convention's step 2).

Measured byte spans, current file, each from its `## Mode: X` heading to the line before the next
`## Mode: Y` heading (or, for `Rebuild`, to the line before the first genuinely-shared trailing
section):

| Mode | Lines | Bytes | In task's "seven"? | Disposition |
|------|-------|-------|---------------------|--------------|
| Ingest | 101-170 | 1,917 | Yes | Extract |
| Status (Default) | 171-266 | 2,794 | No | Stay inline (default branch) |
| Scan | 267-345 | 1,846 | No | Stay inline (below threshold alone; task excludes it) |
| Validate | 346-729 | 18,484 | Yes | Extract |
| Convert | 730-1317 | 22,009 | Yes | Extract |
| Index | 1318-1495 | 5,451 | Yes | Extract |
| Search | 1496-1782 | 10,053 | Yes | Extract |
| Import Pipeline | 1783-1937 | 6,152 | Yes | Extract |
| Rebuild | 1938-2404 | 20,242 | Yes | Extract |
| Sub-Index Mgmt / Error Handling / Standards Reference | 2405-2574 | ~7,512 (remainder) | No | Stay inline (shared, cross-mode reference) |

Sum of the seven target modes: **84,308 B = 83.9% of the current 100,460 B file** (vs. the task
description's ~65,772 B/78% against the stale 84,265 B baseline). `Ingest` (1,917 B, exact match),
`Index` (5,451 vs. 5,234 B), `Search` (10,053 vs. 10,043 B), and `Import Pipeline` (6,152 vs.
5,785 B) are all within noise of the original description. `Validate` (18,484 vs. 5,989 B, +209%),
`Convert` (22,009 vs. 17,534 B, +26%), and `Rebuild` (20,242 vs. 20,170 B, flat) account for
essentially all of the growth — most likely from other, unrelated literature-extension work
landing on this file between task creation and now (e.g. the namespace-divergence hardening
visible in the current `Mode: Validate` body). This does not change the extraction plan, only the
expected token savings (higher than originally estimated).

**Shared trailing sections stay inline, confirmed by prose cross-reference, not just byte size**:
`Sub-Index Management` (per-repo `specs/literature-index.json` operations), `Error Handling`, and
`Standards Reference` are genuinely shared reference material, not a ninth mode. Confirming
evidence: `Error Handling` (line 2531/2535) explicitly says *"Job 1
(`rebuild_job1_dangling_ref_lint`) under 'Mode: Rebuild' above... edit
`rebuild_job1_dangling_ref_lint` under 'Mode: Rebuild' instead"* and (line 2545/2557) references
`Mode: Convert` twice. These are real prose dependencies from inline-staying content into content
that is about to move — see Risks below.

### `skill-distill/SKILL.md` — current structure and measured size

Source: `agent-system/extensions/memory/skills/skill-distill/SKILL.md`, **93,044 B** (2,497
lines) — byte-for-byte unchanged from the task description's baseline. Only one extraction
candidate exists: `## Auto Distill Complete`, a single heading occurring exactly once in the
file (`grep -c` confirms no other occurrence, including inside fences), beginning at line 1495
and running to the literal end of the file at line 2497 (no trailing content after it).

- Measured size: **43,254 B (46.5% of the file)** — exact match to the task description's
  figure, confirming no drift here.
- Content confirmed by direct read: the output table template, the "No Changes Needed" edge
  case, and a `memory_health`/`state.json` field-update-rules table that is specific to how
  `--auto` (and the other vault-mutating sub-modes it documents alongside) updates state — all of
  it genuinely `--auto`-path-specific, not shared reference material misplaced under this
  heading.
- **No fence-interior hazard applies to locating this section's boundaries**: it is a single,
  trailing section. The only hazard that could apply (a stray `## Auto Distill Complete` string
  inside an earlier fenced example) does not occur — confirmed by grep.
- **No inbound cross-references**: nothing elsewhere in the file points into this section by
  name. This is a strictly simpler extraction than any of the seven literature modes — a clean
  tail-cut with zero repointing work.

### Registration and manifest precedent

- `email-cleanup-all-mode.md`'s `index-entries.json` entry (`path`, `domain: "project"`,
  `subdomain: "email"`, `summary`, `line_count`, `keywords`, `load_when.commands: ["/email"]`) is
  the concrete template both extractions should follow — same field shape, `load_when.commands`
  set to `["/literature"]` or `["/distill"]` respectively.
- Both owning extensions' `manifest.json` list their context directories **wholesale**:
  `agent-system/extensions/literature/manifest.json`'s `provides.context` is
  `["project/literature", "guides"]`; `agent-system/extensions/memory/manifest.json`'s is
  `["project/memory"]`. Per the convention's "Registration Mechanics" section, **no
  `manifest.json` edit is needed** for new files placed under either of those trees — only the
  `index-entries.json` registration.
- `agent-system/extensions/literature/context/project/literature/patterns/` already exists and
  already holds domain-pattern files (e.g. `literature-command-modes.md`, which documents the
  *unrelated* `/literature` Mode A/B command-usage distinction — a naming collision in English
  only, not a structural one; do not confuse the two "mode" concepts). The seven new mode-section
  files belong in this same directory.
- `agent-system/extensions/memory/context/project/memory/` has no `patterns/` subdirectory yet
  (its files — `distill-usage.md`, `learn-usage.md`, etc. — sit flat). This is a planning
  decision point (see Decisions below).

## Decisions

- **Path for the distill extraction**: task 89's own description text says the `Auto Distill
  Complete` template "belongs in `context/formats/`". This conflicts with the now-formalized
  convention's Path Selection Rule, which the pilot (task 87) established and which applies
  uniformly: an extension-owned surface's extraction goes into **that extension's own** `context`
  subtree, not core's `context/formats/`. `context/formats/` (`agent-system/extensions/core/
  context/formats/`) is reserved for cross-cutting agent-system artifact formats (`report-format.
  md`, `plan-format.md`, `summary-format.md`, etc.) consumed by many agents across task types —
  not a single skill's single sub-mode's output template, which is domain-specific to the memory
  extension. **Recommendation**: follow the convention, not the task description's informal
  phrasing — extract to `agent-system/extensions/memory/context/project/memory/` (new file,
  flagged for the planner to name and to decide whether it merits a new `patterns/` subdirectory
  to mirror the `literature`/`email` extensions' existing convention, or sits flat alongside
  `distill-usage.md`). Either placement satisfies "no manifest edit needed" since `provides.
  context` lists `project/memory` wholesale.
- **Exclude `Mode: Status` and `Mode: Scan` from the literature extraction**, matching the task
  description's enumerated seven exactly. `Status` is the default branch (every invocation
  without an explicit mode flag takes it — convention's "When NOT to Extract: the default /
  most-frequently-taken branch"). `Scan` is small (1,846 B) and, combined with `Status` staying
  inline, the residual inline mode-specific content (2,794 + 1,846 = 4,640 B) stays safely under
  the lint's 8,000 B file-sum threshold alongside the always-inline `Sub-Index Management` /
  `Error Handling` / `Standards Reference` block.
- **Extraction destination naming for the seven literature modes**: one file per mode at
  `agent-system/extensions/literature/context/project/literature/patterns/<mode>-mode.md` (e.g.
  `ingest-mode.md`, `validate-mode.md`, `convert-mode.md`, `index-mode.md`, `search-mode.md`,
  `import-pipeline-mode.md`, `rebuild-mode.md`), one `index-entries.json` entry each.
- **Bottom-up extraction order for `skill-literature/SKILL.md`** (per the convention's explicit
  ordering rule, since 7 sections are extracted from one file in one pass): `Rebuild` (last),
  then `Import Pipeline`, `Search`, `Index`, `Convert`, `Validate`, `Ingest` (first) — i.e. process
  strictly in reverse of their current line order so earlier-section line numbers never shift
  mid-pass.

## Recommendations

1. **Apply the convention exactly as documented**, reusing the pilot's marker syntax, extraction
   procedure, imperative pointer wording (`READ .claude/context/... now and follow it exactly.`),
   and opening framing-line requirement ("this file is the COMPLETE and ONLY specification...")
   verbatim — no new mechanism is needed for either file.
2. **Literature**: extract the seven modes bottom-up as ordered in Decisions above. Before
   replacing each marked span, re-verify the boundary by direct read (not by remembered line
   numbers — each extraction shifts everything below it even working bottom-up within the
   earlier, still-to-be-processed sections above the current cut).
3. **Repoint the three literature cross-references** found in the always-inline `Error Handling`
   section: the two `Mode: Rebuild` references (lines ~2531, 2535 in the current file) and the two
   `Mode: Convert` references (lines ~2545, 2557) should be updated to name or link the new
   extracted file paths (`.claude/context/project/literature/patterns/rebuild-mode.md` and
   `convert-mode.md`) so a reader of `Error Handling` is not left following a mode name that no
   longer has a body in the same file. Verify no other prose cross-references were missed with a
   fresh repo-wide grep for `Mode: Rebuild`, `Mode: Convert`, etc. after all seven are moved, per
   the convention's mandatory step 6.
4. **Distill**: single clean tail-cut of `## Auto Distill Complete` (line 1495 to EOF) into one
   new file, framing-line promoted headings (`##`→`#`, `###`→`##`, `####`→`###`, preserving
   relative nesting throughout the section's internal table and edge-case subsections). No
   cross-reference repointing needed — confirmed zero inbound references.
5. **Verify the fence-interior hazard does not resurface** post-extraction: after each literature
   mode is cut out, re-run the `^## ` + fence-state scan (or equivalent) over the now-shorter
   `SKILL.md` to confirm no new false-positive heading-shaped lines were introduced by the edit
   itself (e.g. a leftover blank line misplacing a fence delimiter).
6. **Register all eight new files** in their respective `index-entries.json` using the
   `email-cleanup-all-mode.md` entry as the literal template (adjust `path`, `subdomain`,
   `summary`, `line_count` via `wc -l`, `keywords`, `load_when.commands`).
7. **Measure and report against both baselines named in the task's acceptance criteria**: the
   task says "measured reductions reported against the 46.2k and 42.4k baselines" (token
   estimates for `/literature` and `/distill` respectively, from the original task description).
   Report the *current*, corrected before/after byte counts (100,460 B and 93,044 B are the real
   "before" figures, not 84,265 B) alongside the ~4 B/token heuristic the convention doc itself
   uses, so the final numbers are traceable to a measurement, not an assumption. Expect the
   literature saving for a non-default-mode invocation to be noticeably larger than the task's
   original ~14,000-token estimate (roughly 84,308 B − the invoked mode's own bytes, divided by
   ~4), given the file's growth since authoring; expect the distill saving to match the original
   ~10,800-token estimate closely (43,254 B / ~4 ≈ 10,814 tokens), since that file is unchanged.
8. **Verify all nine literature modes (not just the seven extracted) and both distill paths
   (`--auto` and every other sub-mode) still dispatch correctly** post-extraction, per the task's
   acceptance criteria — a quick functional check that each `mode=X` still reaches a non-empty
   handler body (either inline or via the new `READ ... now` pointer) is sufficient; this is a
   structural refactor with no behavioral change intended.

## Risks & Mitigations

- **Risk**: a boundary-location script or manual edit uses a naive "next `## ` line" scan on
  `skill-literature/SKILL.md` and truncates `Validate`, `Convert`, or `Index` at a fence-interior
  fake heading, silently dropping real mode content (the output-template portion of that mode).
  **Mitigation**: locate every boundary by the literal `<!-- branch-gated:end -->` marker (placed
  immediately before the real next `## Mode:` heading) per the convention's design rationale, and
  confirm each span with a direct read before deleting it, exactly as this research did.
- **Risk**: the two `Error Handling` cross-references into `Mode: Rebuild`/`Mode: Convert` are
  missed during implementation, leaving a dangling reference to a section name that no longer has
  content at that location in the file. **Mitigation**: explicit grep for `Mode: Rebuild` and
  `Mode: Convert` (and, defensively, every other mode name) across the file after all seven
  extractions, per Recommendation 3 above and the convention's mandatory step 6.
- **Risk**: placing the distill extraction in `context/formats/` (per the task description's
  literal wording) rather than the memory extension's own tree would both violate the
  now-established convention and (per `context-layers.md`'s layer model) misclassify a
  skill-specific runtime template as a cross-cutting agent-system format. **Mitigation**: the
  planner should explicitly choose the memory-extension-owned path (see Decisions above) and note
  the deviation from the task description's wording as a deliberate, reasoned correction, not an
  oversight.
- **Risk**: the measured byte/token figures in any implementation summary are compared against
  the task description's stale 84,265 B literature baseline, producing a reduction percentage
  that doesn't reconcile with a fresh `wc -c` on the current file. **Mitigation**: Recommendation
  7 — always state both the current actual before-size and the task's original estimate, and
  reconcile the difference (file growth) explicitly rather than silently using one or the other.
- **Risk**: heading-level promotion inside the `Auto Distill Complete` extraction is applied only
  to the `##`/`###` levels mentioned in the convention's worked example, missing the `####`
  sub-subsections present in this file's own content (`#### Change Summary Display`, `#### "No
  Changes Needed" Edge Case`). **Mitigation**: the convention's rule is "promote by one level
  uniformly," not "only `##`/`###`" — apply the full shift (`##`→`#`, `###`→`##`, `####`→`###`)
  consistently.

## Context Extension Recommendations

None — this task's own output (the extracted pattern files, their index-entries.json
registrations) *is* the context extension. Filing a separate recommendation would be redundant
with the task's own deliverables (meta task type).

## Appendix

### Search/measurement commands used

```bash
# Real mode-section byte spans (fence-aware boundary = next "## Mode:" heading, not next "## ")
python3 - "$f" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8').readlines()
mode_lines = [(i, l.strip()) for i, l in enumerate(lines, 1) if l.startswith("## Mode:")]
mode_lines.append((len(lines)+1, "EOF"))
for (s, name), (e, _) in zip(mode_lines, mode_lines[1:]):
    span = lines[s-1:e-1]
    print(name, s, e-1, sum(len(x.encode('utf-8')) for x in span))
PY

# Fence-interior fake-heading detection (tracks ``` fence state while scanning for "## " lines)
python3 - "$f" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8').readlines()
in_fence = False
for i, l in enumerate(lines, 1):
    if l.rstrip().startswith("```"):
        in_fence = not in_fence; continue
    if l.startswith("## ") and in_fence:
        print(i, l.strip())
PY

# Cross-reference sweep
grep -n "Mode: " skill-literature/SKILL.md | grep -v "^[0-9]*:## Mode:"
grep -n -i "Auto Distill" skill-distill/SKILL.md
```

### References

- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` (the convention)
- `agent-system/extensions/core/scripts/lint/lint-branch-gated-sections.sh` (enforcement, Gate 19)
- `agent-system/extensions/email/context/project/email/patterns/email-cleanup-all-mode.md` (pilot
  output, task 87) and its `index-entries.json` entry (registration template)
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (100,460 B, 2,574 lines)
- `agent-system/extensions/memory/skills/skill-distill/SKILL.md` (93,044 B, 2,497 lines)
- `specs/state.json` project_number 89 entry (original task description and baseline figures)
