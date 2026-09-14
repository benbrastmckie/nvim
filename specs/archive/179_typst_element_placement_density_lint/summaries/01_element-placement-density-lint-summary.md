# Implementation Summary: Task #179

- **Task**: 179 - Add a mechanical element-placement and density lint to the typst extension
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T02:00:00Z
- **Completed**: 2026-09-08T03:55:00Z
- **Effort**: ~2 hours
- **Dependencies**: None (semantic-element-usage.md prerequisite already merged)
- **Artifacts**: plans/01_element-placement-density-lint.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Added `typst-element-lint.sh`, a mechanical backstop for `standards/semantic-element-usage.md`'s
Universal Placement Rule and density/sparingness guidance, since the "prose alone is enough"
hypothesis was already tested and falsified in this extension (a 25-item `#remark` checklist
landed as the first body content after `= Agency` in `08-agency.typ` despite an existing
"Opening paragraph" prose requirement in the chapter template). The script implements one
blocking check (semantic element as first body content after any heading, no intervening prose)
and two advisory checks (remark item-count threshold, remark-vs-theorem-family density), ships a
37-assertion self-contained test suite, and is wired into `typst-implementation-agent.md`
alongside — never replacing — `typst compile`, at both the per-file Stage 4C self-review and the
whole-document Stage 5 final pass. All six plan phases completed with no deviations from the
plan.

## What Changed

- `agent-system/extensions/typst/scripts/typst-element-lint.sh` — New. Bash + single embedded
  AWK program implementing all three checks in one per-file pass: check 1 (placement, blocking,
  exit 1), check 2 (remark item-count via bracket-depth matching over `[`/`]` with comment/quote
  stripping, advisory), check 3 (remark-vs-theorem-family density with a floor of 3, advisory).
  Class B strict mode (`set -uo pipefail`). CLI: `[--verbose] [--help] PATH...` (file or
  recursively-scanned directory); exit 0 = pass, 1 = placement failures, 2 = usage/environment
  error.
- `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` — New. Narrow,
  fixture-driven suite per `shell-script-testing.md`'s convention: inline heredoc fixtures for
  the plan's nine required cases (a)-(i) plus a warnings-only-exits-0 case, CLI usage/help cases,
  and a directory-scan case. 37 assertions, all passing, no dependency on the Logos/Theory
  repository or network access.
- `agent-system/extensions/typst/manifest.json` — `provides.scripts` populated with
  `["typst-element-lint.sh", "tests/test-typst-element-lint.sh"]` (was `[]`). `provides.hooks`
  and `provides.rules` left as `[]` per plan's non-goals.
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` — Stage 4C: added a
  mechanical-lint invocation immediately alongside the existing prose structural self-review
  (per-file, blocking on placement `[FAIL]`, advisory `[WARN]` must be reported). Stage 5: added
  a whole-document lint pass alongside `typst compile`, guarding a run that resumed mid-plan and
  skipped a per-phase Stage 4C. Critical Requirements: added MUST DO #7 naming the lint; MUST NOT
  #7/#8 (the prose Universal Placement Rule and tracking-content-location bullets from the
  semantic-element-usage.md contract) left untouched.
- `agent-system/extensions/typst/EXTENSION.md` — Language Routing table's Implementation Tools
  cell extended to name the lint alongside `typst compile`; a new Common Operations line shows
  the invocation and its blocking/advisory split.

## Decisions

- Implemented all three checks as a single embedded AWK program (heredoc inside the bash
  script), driven per-file from a bash loop, rather than three separate passes or scripts —
  comment/quote stripping and element detection are computed once per line and reused by every
  check.
- A fixed 7-field tab-separated protocol (`SEVERITY\tCHECK\tFILE\tf1\tf2\tf3\tf4`, unused
  trailing fields as `-`) carries findings from the AWK program to the bash wrapper's colored
  PASS/FAIL/WARN output, avoiding variable-field-count parsing ambiguity.
- Check 2's bracket-depth matcher treats a remark's title-parens (`("Title")`) as
  bracket-neutral by construction (since quoted string contents are stripped before counting),
  so the body-open `[` never needs to be located by a separate parse step — the whole line's net
  `[`/`]` delta from the point the remark is detected is sufficient.
- Check 1 resets its "awaiting first content" state on every heading encountered, regardless of
  prior state, so nested headings with no intervening body (e.g. `= Foo` immediately followed by
  `== Bar`) are handled correctly without a special case.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash/awk script, no build step)
- Tests: Passed — `bash agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh`
  reports 37 passed, 0 failed, exit 0.
- `bash -n` clean on both the lint script and its test. `shellcheck` was not run — not installed
  on this system (not found on PATH); the plan's own task wording treats this as conditional
  ("if available on PATH"), so this is an environment limitation, not a skipped requirement.
- `jq . agent-system/extensions/typst/manifest.json` parses; both `provides.scripts` entries
  confirmed present.
- Files verified: Yes (both new scripts exist, executable, non-empty; all three edited files
  confirmed by grep to carry the expected content).

### Acceptance evidence (Phase 5, verbatim observed output against `08-agency.typ`)

```
[FAIL] .../08-agency.typ:57: element '#remark' opens as the first body content after heading at
line 55 ("= Agency <sec-agency>"), with no intervening prose. ...
[WARN] .../08-agency.typ:57: remark spans lines 57-88 with 25 enumerated items (advisory,
threshold 3). ...
[INFO] .../08-agency.typ: 23 remarks, 39 theorem-family elements

Summary
-------
Files checked: 1
Failures:      1
Warnings:      1

TYPST ELEMENT LINT FAILED (1 placement failures)
```

All four acceptance criteria confirmed:
1. Placement FAIL reported at line 57 (the `#remark`) following the `= Agency` heading at line
   55 — matches the plan's Scope Hypothesis exactly.
2. No finding references any line in the pre-heading region (lines 1-53, the `#import`/`#let`
   macro-and-comment block) — confirmed structurally (check 1 never scans before the first
   heading) and by inspection of the one FAIL reported.
3. No finding references the post-result remarks at lines 208, 237, 353 (the standard's endorsed
   usage) — only one FAIL was reported, and it is not at any of those lines.
4. Density findings are advisory: check 3 stayed silent on this file (23 remarks vs 39
   theorem-family elements — correctly below the ratio threshold), and the run's exit code (1)
   is driven solely by the check-1 placement failure; the check-2 item-count warning did not
   affect it.

### Corpus-wide run (informational, not a lint defect)

Running the lint against the entire `typst/manual/chapters/` directory (12 files) found 40
placement failures across 8 of 12 chapters — not just `08-agency.typ`. Manual inspection of a
representative sample (7+ instances spanning `03-dynamics.typ`, `07-normative.typ`,
`09-game-theory.typ`, `10-spatial.typ`, `02-constitutive.typ`, `04-verification.typ`, and
`06-epistemic.typ`) confirmed every sampled instance is a genuine Universal Placement Rule
violation — a heading (chapter or section) immediately followed by a semantic element with zero
intervening prose — including two more instances of the exact motivating pattern (a
`#remark("Formalization Status")[` standing as a chapter's first body content, in
`07-normative.typ`, `10-spatial.typ`, and `06-epistemic.typ`). **No correct document was flagged
by check 1** in the sampled set, satisfying the Phase 5 contingency ("if any correct document is
flagged, that is a blocking defect in the check"): no such defect was found, so no fix was
required before Phase 6. Fixing these additional 39 pre-existing findings across the corpus is
explicitly out of scope for this task (`08-agency.typ` and every other chapter are read-only test
fixtures here) and is left as follow-up cleanup work. The Logos/Theory repository's
`typst/manual/chapters/` directory was confirmed byte-for-byte unmodified via
`git -C ~/Projects/Logos/Theory status --porcelain` / `diff --stat` both before and after this
corpus-wide read-only run.

## Impacts

- The typst extension now has mechanical script infrastructure for the first time
  (`provides.scripts` was `[]`); `provides.hooks` and `provides.rules` remain `[]`.
- `typst-implementation-agent.md`'s verification path gains a mechanical backstop alongside its
  existing prose self-review and `typst compile` gate — future implementation work on `.typ`
  chapters will be blocked on introducing a new placement violation, and warned (non-blocking) on
  item-count/density signals.
- The corpus-wide run surfaced 39 additional, pre-existing instances of the same defect pattern
  across 7 other chapters, which were previously undetected by any mechanical or (evidently)
  prose-based means. This is useful information for a future cleanup task but requires no action
  from this task.

## Follow-ups

- A future task could address the 39 additional placement violations found across
  `typst/manual/chapters/` by the corpus-wide run (see Verification section above for the
  per-chapter breakdown) — out of scope here since this task's mandate was the lint mechanism,
  not corpus cleanup.
- The item-count threshold (3, check 2) has no textual anchor in `semantic-element-usage.md` and
  is explicitly documented as unreviewed; per Constraint 2, promoting it (or the density check)
  to blocking requires a documented review pass against real chapters first, which this task
  intentionally left undone.

## References

- Plan: `specs/179_typst_element_placement_density_lint/plans/01_element-placement-density-lint.md`
- Research: `specs/179_typst_element_placement_density_lint/reports/01_element-placement-density-lint.md`
- Standard: `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`
- Script: `agent-system/extensions/typst/scripts/typst-element-lint.sh`
- Test suite: `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh`
