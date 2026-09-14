# Research Report: Task #179

- **Task**: 179 - Add a mechanical element-placement and density lint to the typst extension
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T00:00:00Z
- **Effort**: 1-2 hours implementation
- **Dependencies**: task 178 (semantic-element usage contract) — COMPLETE, both semantically (element inventory/norms) and by file footprint (both tasks edit `typst-implementation-agent.md`)
- **Sources/Inputs**: codebase (`agent-system/extensions/typst/**`, sibling extensions' `scripts/`), live test fixture (`~/Projects/Logos/Theory/typst/manual/chapters/08-agency.typ`), `.claude/context/standards/shell-script-testing.md`, `.claude/context/standards/shell-strict-mode.md`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 178 (the semantic-element usage contract) is already merged: `standards/semantic-element-usage.md` exists with the full element inventory (`definition`, `theorem`, `lemma`, `corollary`, `example`, `proof`, `remark`, `rule-block`, `rule-list`), the Universal Placement Rule, and — critically for check 3 — an explicit textual density heuristic ("if a chapter has more remarks than theorems, that is a signal"). `typst-implementation-agent.md` already references this standard in prose (Stage 4C self-review, MUST NOT #7/#8); this task adds the mechanical backstop the file's own header describes as still missing.
- The extension has zero script infrastructure (`manifest.json`'s `provides.scripts: []`). Sibling extensions (`lean`, `nix`, `literature`, `core`) establish the conventions to follow: scripts live flat in `scripts/`, are listed as relative filenames in `manifest.json`'s `provides.scripts` array, are invoked from agent `.md` files as `bash .claude/scripts/{name}.sh {args}` (the deployed path, not the source-store path), and a narrow single-script test suite lives at `scripts/tests/test-{name}.sh` per `shell-script-testing.md`.
- The real defect in `08-agency.typ` was confirmed directly: `= Agency <sec-agency>` at line 55, immediately followed (line 57, zero intervening prose) by `#remark("Formalization Status")[` opening a 25-item `+`-enumerated list (confirmed count: exactly 25) closing at line 88. A second remark (`#remark("Decision: Divergences...")`) follows immediately after with still no prose, then a third (`#remark("Dependency")`) — three remarks in a row before any body prose exists. This is the concrete shape check 1 must fire on.
- The pre-heading region (lines 1-53: `#import`, chapter-local `#let` macros, and `//` comments) precedes the `= Agency` heading at line 55 and must never be scanned by check 1 — the check only ever looks *after* a `^= ` (or `^== `/`^=== `) match, so this region is out of scope by construction, not by a special-cased exemption.
- The file has 23 `#remark(...)` occurrences against 39 `#definition`/`#theorem`/`#lemma`/`#corollary`/`#example` occurrences in 973 lines — remarks do NOT outnumber results here, so the standard's own density heuristic (remarks > theorems) would correctly stay silent on this file's overall density even though it correctly fires on the placement defect. This is useful real-world calibration data for the advisory threshold.
- No numeric threshold for "how many items is too many" or "what density ratio is too high" exists anywhere in `standards/semantic-element-usage.md` — it is deliberately qualitative ("sparing", "Low"). The script must pick concrete numbers; the recommendation below anchors check 3's number on the standard's own stated ratio (remarks > theorem-family count) rather than inventing an unrelated metric, and flags check 2's item-count threshold as a genuine judgment call with no textual anchor.

## Context & Scope

Researched: (1) whether the prerequisite task-178 artifact this task depends on for its
threshold/element-inventory source actually exists and what it contains; (2) the current absence
of script infrastructure in the typst extension and what conventions sibling extensions use for
scripts, manifest wiring, and agent-verification wiring; (3) the concrete shape of the defect in
the live `08-agency.typ` test fixture (read-only — not to be modified) to ground the placement
and item-count checks in real line numbers and counts; (4) repo-wide shell-script conventions
(strict-mode class, test-suite location) that a brand-new script in this extension should follow
absent any typst-local precedent.

Out of scope (per dispatch): editing `08-agency.typ` or any other Logos/Theory chapter; inventing
a divergent threshold system instead of grounding it in `standards/semantic-element-usage.md`.

## Findings

### Codebase Patterns

- `agent-system/extensions/typst/manifest.json`: `provides.scripts: []`, `provides.hooks: []`,
  `provides.rules: []` — confirmed empty, as the dispatch states. `provides.scripts` in sibling
  manifests (`lean`, `nix`, `literature`) is a flat array of paths relative to that extension's
  own `scripts/` directory, e.g. `nix/manifest.json`: `["nix-preflight.sh", "nix-context.sh"]`.
  A test file is listed alongside its script: `lean/manifest.json` includes both
  `"lean-sorry-census.sh"` and `"tests/test-lean-sorry-census.sh"` as sibling array entries.
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` already carries prose
  referencing `standards/semantic-element-usage.md` from task 178: Stage 4C's "Structural
  self-review" (5 Self-Review Questions, executed per-file after every phase) and two MUST NOT
  bullets (#7 Universal Placement Rule, #8 tracking-list-in-remark). This confirms task 178
  landed the prose half; this task adds the mechanical half "alongside — not replacing" both the
  existing prose self-review and `typst compile`, per the dispatch's Scope C.
- Script-invocation convention (confirmed in `lean-implementation-agent.md`'s "Final
  Verification Stage (MANDATORY)" section, lines ~225-260): a numbered list of verification
  steps, each running `bash .claude/scripts/{script}.sh {args}` and recording a named field
  (e.g. `sorry_count`, `build_passed`). This is the deployed-path form (`.claude/scripts/...`),
  distinct from the source-store path (`agent-system/extensions/lean/scripts/...`) used only for
  editing — consistent with `.claude/rules/source-store-deploy-boundary.md`.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` is the closest existing
  exemplar of a lint script with a warning/failure severity split: header doc states exit codes
  (`0` = pass, warnings allowed; `1` = failures; `2` = environment/usage error), `--verbose`/
  `--help` flags, colored PASS/FAIL/WARN output. This maps directly onto the dispatch's
  constraint 2 (placement = failing check, density/item-count = advisory warning that does not
  fail the run).
- `.claude/context/standards/shell-script-testing.md` (core-scoped, but the only extant location
  rule in the repo): narrow single-script suites belong at `scripts/tests/test-{script}.sh`. No
  typst-local precedent exists to override this, so it is the applicable default.
- `.claude/context/standards/shell-strict-mode.md`: a script that "accumulates a
  PASSED/FAILED (or equivalent) counter across multiple independent checks/cases and reports a
  summary at the end" is Class B (`set -uo pipefail`, no `-e`) by design — this is exactly the
  lint script's shape (it must keep scanning after finding one violation, not abort at the first
  `grep`/`awk` nonzero exit), so Class B is the applicable default, not the Class A default for
  "ordinary" scripts.
- Other extensions favor bash for line-oriented scans (`grep`/`awk`/`sed`) and drop to Python
  only for genuinely stateful multi-line parsing (`literature_quality_gate.py`,
  `literature_combining_detect.py` — both operate on whole-document strings with regex state that
  would be unwieldy in pure bash). Check 1 (line-scan after a heading) is a natural bash/awk fit;
  check 2 (brace-matching over a `#remark(...)[...]` block to find its extent and count
  enumerated items) is more naturally expressed in awk/python than raw grep, since it needs to
  track bracket depth across lines.

### The Prerequisite Standard (task 178's artifact)

`agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`
(282 lines) is the authoritative source for element inventory and norms per Scope D. Key content
this lint must encode faithfully rather than re-derive:

- **Element inventory** (exact set the placement check must recognize as "opens with"):
  `#definition(`/`#definition[`, `#theorem(`/`[`, `#lemma`, `#corollary`, `#example`, `#proof[`,
  `#remark(`/`#remark[`, `#rule-block(`, `#rule-list(` — confirmed against
  `patterns/theorem-environments.md` and `patterns/rule-environments.md`'s actual call syntax.
- **Universal Placement Rule** (check 1's exact spec): "A semantic element MUST NOT be the first
  body content after a heading, with no intervening prose," applying uniformly across `=`, `==`,
  `===` headings.
- **Remark's density/placement entry** (checks 1 and 2's textual anchor): "never a chapter
  opener"; "never a long enumerated status or tracking list ... if a remark's body is a numbered
  or bulleted checklist tracking completion, formalization progress, or open items, it is not a
  remark." No numeric item-count threshold is stated.
- **Density heuristic** (check 3's textual anchor — the one place the standard gives a
  *comparable, countable* signal rather than a pure adjective): "If a chapter has more remarks
  than theorems, that is a signal the remarks are doing work that belongs [elsewhere] ... not
  evidence the chapter is unusually reflective."
- **Where Tracking Content Belongs**: explicitly names `specs/**`, an appendix, or a dedicated
  status section as the legal home for enumerated tracking content — useful for the lint's
  violation message text (point the author at the correct home, not just "this is wrong").
- **Self-Review Questions** (already exercised by the agent's Stage 4C prose review): questions
  1-3 map directly onto this lint's checks 1 and 2; the lint is the mechanical counterpart to a
  review step that already exists in prose form.

### Live Defect Confirmation (`08-agency.typ`, read-only test fixture)

Confirmed directly against the file at `~/Projects/Logos/Theory/typst/manual/chapters/08-agency.typ` (973 lines; NOT to be modified — out of scope per dispatch):

- Line 55: `= Agency <sec-agency>` — the chapter heading.
- Line 56: blank.
- Line 57: `#remark("Formalization Status")[` — the violating semantic element, zero intervening
  prose lines between heading and remark. This is the placement-check target.
- Lines 61-87: `#items[` wrapping a `+`-marked enumerated list; counted exactly 25 `+` items
  (confirms the dispatch's "25-item remark checklist" claim precisely).
- Line 88: `] <rem-agency-status>` closes the remark.
- Line 90: `#remark("Decision: Divergences Are Kept, Numbered, and Extended")[` — a SECOND remark
  immediately following the first with still no intervening prose, closing line 95.
- Line 106: `#remark("Dependency")[...]` — a THIRD remark, still before any body prose, closing
  line 109.
- Line 111: `== Syntactic Primitives <sec-agency-syntax>` — the first subsection heading; body
  prose does not actually begin until inside this subsection.
- Lines 1-53 (before line 55's heading): `#import`, 20+ chapter-local `#let` macro definitions,
  and `//` comment blocks explaining notation collision decisions — this is exactly the
  "~50 lines of legitimate pre-heading macro block" the dispatch's Constraint 1 names, and it
  must never trigger the lint (it is structurally out of scope for a check that only starts
  scanning after matching `^= `).
- Other remarks in the file DO follow substantial results, matching the standard's "legal"
  pattern: e.g. line 208 `#remark("STIT For Free")` follows a definition block ending line 204;
  line 237 `#remark("Independence Is Stipulated...")` follows the `<def-independence>` block
  ending line 233; line 353 `#remark("Refraining and the Null Move")` follows a proposition block
  ending line 346. These are the "silent on remarks that follow a substantial result" acceptance
  criterion's concrete counter-examples the lint must NOT flag.
- File-wide counts: 23 total `#remark(` occurrences vs. 39 total
  `#definition`/`#theorem`/`#lemma`/`#corollary`/`#example` occurrences across 973 lines. Applying
  the standard's own heuristic (remarks > theorem-family count) to this file yields **no**
  density flag at the whole-file level — useful evidence that the heuristic doesn't trivially
  fire on this file's aggregate, even though the file clearly *does* have the placement defect.
  This suggests check 3's signal and check 1's signal are usefully independent, not redundant.

## Decisions

- **Script location**: `agent-system/extensions/typst/scripts/typst-element-placement-lint.sh`
  (or equivalent single descriptive name) — flat in `scripts/`, per every sibling extension's
  convention; no subdirectory structure needed for a single script.
- **Test location**: `agent-system/extensions/typst/scripts/tests/test-typst-element-placement-lint.sh`,
  per `shell-script-testing.md`'s narrow-single-script rule (no typst-local precedent exists to
  override the repo default).
- **Language**: bash + awk for checks 1 and 3 (simple line-scan / count-and-compare); prefer awk
  (or a small embedded Python snippet, following `literature_quality_gate.py`'s precedent for
  genuinely multi-line stateful parsing) specifically for check 2's brace-matching over a
  `#remark(...)[...]` block, since tracking bracket depth across lines is unwieldy in pure grep.
  Either choice is viable; recommend awk first to keep the extension dependency-free (no python
  requirement is currently declared anywhere in the typst extension) unless the implementer finds
  the brace-matching logic materially clearer in Python.
- **Strict mode**: Class B (`set -uo pipefail`, no `-e`) per `shell-strict-mode.md`'s admission
  test — the script must keep scanning all chapters/all remarks after finding one violation and
  report a full summary, not abort at the first non-matching `grep`.
- **Severity split** (Constraint 2, direct implementation): check 1 (placement) is the blocking
  check — nonzero exit on any violation found. Checks 2 (item-count-in-remark) and 3 (per-file
  remark density) are advisory — always printed as warnings when triggered, but never contribute
  to a nonzero exit code. This maps onto `lint-agent-contracts.sh`'s existing "0 = pass, warnings
  allowed; 1 = failures" convention already used elsewhere in the repo.
- **Check 3's numeric threshold**: use the standard's own stated ratio — `#remark` count exceeds
  theorem-family (`#theorem`+`#lemma`+`#corollary`+`#definition`+`#example`) count for the file
  — rather than an invented raw-count or per-line-density number. This is textually grounded in
  `semantic-element-usage.md` ("if a chapter has more remarks than theorems, that is a signal"),
  satisfying Scope D directly. Confirmed on `08-agency.typ` that this ratio does not trivially
  trip (23 vs 39), so it is not a rule that fires on every document by construction.
- **Check 2's numeric threshold has no textual anchor** in the standard — it is a genuine
  implementation judgment call, not something this research can resolve by citation. Recommend
  the planner set an initial advisory threshold in the 3-5 item range (concretely: flag when a
  remark's enumerated body exceeds 3 items), given the confirmed real defect is 25 items (Vastly
  over any plausible threshold) and the standard's language ("sparing", "never a long enumerated
  ... list") implies even a handful of items is already suspect for a *remark* specifically
  (unlike an ordinary body list, which is unconstrained). Record this as advisory-only per
  Constraint 2 regardless of the exact number chosen, since it is unreviewed against a real
  corpus beyond this one file.
- **Manifest wiring**: add the script's filename (and its test's relative path) to
  `manifest.json`'s `provides.scripts` array, matching the `lean`/`nix` array-of-relative-paths
  shape exactly.
- **Agent wiring point**: `typst-implementation-agent.md` Stage 4C, immediately alongside the
  existing "Structural self-review (executed, not a reminder)" prose block — invoke the script
  there (`bash .claude/scripts/{name}.sh {file}` per changed `.typ` file, or over the whole
  chapters directory) as the mechanical counterpart to the prose Self-Review Questions, not as a
  new standalone stage. Also consider adding it to Stage 5's "Final Compilation Verification"
  alongside `typst compile`, per the dispatch's "alongside -- not replacing" instruction, so a
  run that skips per-phase Stage-4C review (e.g. resumed mid-plan) still gets one whole-document
  pass before final metadata.

## Risks & Mitigations

- **False positive on `#remark[` (no name argument)**: the element-opening regex must match both
  `#remark(` and `#remark[` forms (confirmed both appear live in `08-agency.typ`, e.g. line 234
  `#remark[`). Mitigation: match `#{element}\s*[\(\[]`, not `#{element}\(` alone.
- **Comment/blank-line skip logic drifting from the dispatch's exact spec**: the dispatch says
  "skip blank lines and `//` comments" when scanning for the first content line after a heading.
  A line that is only a Typst label (`<sec-foo>`) trailing the heading itself is part of the
  heading line, not a separate line, so no special-case needed there; but a `#import` or `#let`
  line appearing *after* a heading (unusual but not impossible) should probably NOT be treated as
  "prose" either — recommend the planner decide explicitly whether such lines count as
  intervening prose or should also be skipped, since the dispatch's spec only names blank lines
  and `//` comments.
- **Brace-matching correctness for check 2**: `#remark(...)[ ... ]` bodies can contain nested
  `[...]`/`(...)` (labels, math mode `$...$` with brackets, nested `#items[...]`) — a naive
  "count `]` until it hits zero" scan must track ALL bracket types the body may contain, not just
  the outermost `[...]`. The `08-agency.typ` fixture's first remark nests an `#items[...]` block
  one level inside the remark's own `[...]`, which is a good calibration case: matching must find
  the remark's own closing `]` at line 88, not the inner `#items[...]`'s closing `]` at line 87.
- **Item-count regex must count enumerated markers, not just non-blank lines**: `+ ` (Typst
  native enum marker) is the pattern seen live; the plan should not hard-code the document-local
  `#items[...]` wrapper macro name (that macro is defined in the Logos/Theory repo's own
  `template.typ`, not in this extension), since a future chapter or a different content repo
  using this extension's agent may use bare Typst `+`/`-`/numbered markers directly without the
  `items[...]` wrapper. Counting `+`/`-`/`\d+\.` marker lines within the matched brace span is
  more portable than keying on `items[`.
- **Unreviewed thresholds getting silently promoted to blocking**: Constraint 2 is explicit that
  density/item-count checks start advisory. Recommend the plan phase include an explicit note (in
  the script's own header comment, not just the plan) that promotion to blocking requires a
  documented review pass against real chapters — mirroring how `literature_quality_gate.py`
  documents which of its checks are "advisory only -- never a gate rejection" and why.

## Context Extension Recommendations

- `EXTENSION.md`'s "Common Operations" / "Language Routing" ("Implementation Tools" column
  currently reads `Read, Write, Edit, Bash (typst compile)`) does not yet mention the lint. Once
  implemented, the planner should add a one-line mention there so the merged root `CLAUDE.md`
  reflects the new mechanical check, consistent with how other extensions document their
  verification tooling in this table.
- No other context gaps identified — `standards/semantic-element-usage.md` and the two
  `patterns/*-environments.md` files together already fully specify the element inventory and
  mechanics this lint needs; no new standard file is required by this task (only the script and
  its wiring, per Scope A-C).

## Appendix

- Commands used: `jq '.provides.scripts'` across `lean`/`nix`/`literature` manifests; `grep -n`
  over `08-agency.typ` for headings/remarks/`#items[`; `wc -l` and count comparisons for
  remark-vs-theorem-family density; `find`/`grep` over `agent-system/extensions/core/scripts/**`
  for lint-script exemplars; direct reads of
  `standards/semantic-element-usage.md`, `patterns/theorem-environments.md`,
  `patterns/rule-environments.md`, `typst-implementation-agent.md`,
  `shell-script-testing.md`, `shell-strict-mode.md`.
- Companion task artifacts consulted: `specs/178_typst_semantic_element_usage_contract/{reports,plans,summaries}/01_*.md` (read for threshold-related mentions only; confirmed no numeric thresholds exist anywhere in that task's output either — the 282-line standard file is qualitative throughout).
