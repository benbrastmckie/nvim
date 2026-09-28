# Implementation Summary: Task #129

- **Task**: 129 - Empirically audit `\b` word-boundary grep patterns for compositional failure under the deployed grep
- **Status**: [COMPLETED]
- **Started**: 2026-09-26T11:07:00Z
- **Completed**: 2026-09-26T13:10:00Z
- **Effort**: ~2 hours
- **Dependencies**: 88, 128, 261 (state.json) — sequencing-only, to avoid a file-footprint collision on `skill-orchestrate/SKILL.md`
- **Artifacts**: plans/01_word-boundary-portability-audit.md, reports/01_word-boundary-grep-audit.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task independently re-executed the research phase's empirical `\b` word-boundary grep audit
— every genuine grep-pattern `\b` site in the source store, run through the mechanism that
actually exercises it in production, with a positive and (where applicable) negative input
recorded per site — and landed a portability guidance note so the defect class does not recur.
Zero repairs were required anywhere: every site re-tested WORKING. The dispatch-framing correction
the research phase surfaced (the deployed grep is invocation-context-dependent, not uniformly
ugrep) was independently re-verified as the first fact established, before any per-site work.

## Corrected Dispatch Framing

The dispatch's "the deployed grep is ugrep 7.8.4" is precise only for a command an agent types or
pastes directly into its own Bash-tool shell. A `\b` pattern inside a `.sh` script or hook
*executed* as a subprocess (`bash file.sh`, `./file.sh`, the hook runner) resolves `grep` to GNU
grep 3.12, which does not exhibit the compositional defect at all. This was re-verified directly
(not assumed) in Phase 1: `type grep` at the Bash-tool top level shows a non-exported shell
function that `exec`'s the Claude Code binary as `ugrep`; `env -i bash -lc`, a nested `bash -c`,
and a literal `bash probe.sh` all report GNU grep 3.12 instead. The dispatch's own gate-failure
pattern reproduces NOMATCH under top-level `-E`, MATCH under top-level `-P`, and MATCH inside a
`.sh` file (GNU grep) — the compositional defect is genuinely ugrep-specific and is not
uniformly "the deployed grep" for every file class the dispatch names.

The dispatch's "CONFIRMED INSTANCE" (`lean-sorry-census.sh` double-counting `sorry` inside
`set_option warn.sorry false in`) is also stale: the source-store copy was already fixed by commit
`232b05b7f` (a Python `(?<![.\w])sorry\b` negative-lookbehind), and the sibling test suite already
carries the exact fixture and an anti-vacuous guard. Re-run here: 17/17 pass. No code change was
made.

## Per-Site Evidence Table

Every row below was re-executed directly during this implementation (Phase 1 for the two
ugrep-exposed Markdown sites, Phase 2 for every `.sh`/hook site), not cited from the research
report.

| # | Site | File | Engine | Mechanism | Positive result | Negative result | Classification | Action |
|---|------|------|--------|-----------|------------------|------------------|-----------------|--------|
| 1 | `^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b` (lines 337, 416) | `lean/agents/lean-implementation-agent.md` | ugrep 7.8.4 (top-level Bash-tool) | direct execution against a Lean fixture | `name=foo_bar_baz` MATCH | `foo_bar_bazx`/`nonexistent_name` NOMATCH | WORKING | none |
| 2 | same pattern (line 348, `grep -rl`) | `lean/agents/lean-implementation-agent.md` | ugrep 7.8.4 | direct execution | `new_name=helper_widget` MATCH | — | WORKING | none |
| 3 | `\b${replaced}\b` (line 349) | `lean/agents/lean-implementation-agent.md` | ugrep 7.8.4 | direct execution | `replaced=old_name_helper` MATCH | `old_name_helperx` NOMATCH | WORKING | none |
| 4 | same pattern shape (line 491) | `lean/agents/lean-implementation-hard-agent.md` | ugrep 7.8.4 | direct execution | `name=foo_bar_baz` MATCH | `foo_bar_bazx`/`nonexistent_name` NOMATCH | WORKING | none |
| 5 | `--hard\b`, `(drop\|clear)\b` | `hooks/guard-destructive-git.sh` | GNU grep 3.12 (subprocess) | `test-guard-destructive-git.sh` | 50/50 pass | — | WORKING | none |
| 6 | `[A-Za-z0-9_-]+\.(sh\|sql)\b` | `scripts/check-extension-docs.sh` | GNU grep 3.12 | live deployed run, all extensions | PASS: all 21 extensions OK | — | WORKING | none |
| 7 | `Agent\b`, meta-pattern | `scripts/lint/lint-postflight-boundary.sh` | GNU grep 3.12 | `test-lint-postflight-boundary.sh` | 6/6 pass | — | WORKING | none |
| 8 | `$_seeded\b`, `\bexit\b`, `\breturn 1\b` | `scripts/test-session-runtime-files.sh` | GNU grep 3.12 | ran the harness itself | 6/6 pass | — | WORKING | none |
| 9 | `[0-9]+(GB\|MB\|G\|M)\b` (case 12b) | `scripts/tests/test-lake-build-guard.sh` | GNU grep 3.12 | ran the harness itself | 47/0 pass (case 12b PASS) | — | WORKING | none |
| 10 | P1 `\b(Definition\|Lemma\|Theorem\|Proposition\|Corollary\|Remark\|Example)\s+[0-9]+(\.[0-9]+)*\b` | `literature/scripts/literature-audit.sh` | GNU grep 3.12 | literal `grep -oE` against a built fixture | extracted `Theorem 3.1`, `Definition 2.4`, `Lemma 5` | `theoretically` probe: 0 matches | WORKING | none |
| 11 | P2 `\bTheorem\s+[A-Z]\b` | `literature/scripts/literature-audit.sh` | GNU grep 3.12 | same fixture | extracted `Theorem A` | — | WORKING | none |
| 12 | P3 `\bAxiom\s+[0-9]+(\.[0-9]+)*\b` | `literature/scripts/literature-audit.sh` | GNU grep 3.12 | same fixture (no Axiom present) | 0 matches (expected) | — | WORKING | none |
| 13 | `\bsorry\b` (documented hazard; actual impl. is Python lookbehind) | `lean/scripts/lean-sorry-census.sh` | n/a (Python re) | `test-lean-sorry-census.sh` | 17/17 pass incl. Fixtures A/B/D (`warn.sorry`) | — | WORKING (fixed upstream, commit `232b05b7f`) | none |
| 14 | `TASK_PATTERN`, `PHASE_PATTERN` | `scripts/lib/task-reference-patterns.sh` | GNU grep 3.12 | `test-validate-no-task-references.sh` | 31/31 pass | — | WORKING | none |
| 15 | 3 sites | `scripts/lib/task-type-detect.sh` | GNU grep 3.12 | `test-task-type-detect.sh` | 10/10 pass | — | WORKING | none |
| 16 | `\bTARGET\b` | `scripts/tests/test-census-count.sh` | GNU grep 3.12 | ran the harness itself | 8/8 pass | — | WORKING | none |
| 17 | `` lean_lib[[:space:]]+\`?${name}\b `` | `lean/scripts/lean-comparator-run.sh` | GNU grep 3.12 | `test-lean-comparator-run.sh` | 22/22 pass, 1 skip (unrelated: binary availability) | — | WORKING | none |
| 18 | `grep -q "sess_930\b"` (line 139) | `scripts/tests/test-orchestrate-recover-message-findings.sh` | GNU grep 3.12 | ran the harness itself | that specific assertion PASSED; overall 21/2 fail (both unrelated: acceptance-e2e) | — | WORKING | none |

**Non-sites confirmed by inspection** (no repair applicable):

- `literature-convert.sh`'s `\\begin\{` — false positive of the coarse initial sweep (literal
  LaTeX `\begin{`, not a word-boundary construct).
- `literature-chunk.sh`'s `XREF_PATTERN` — defined but never referenced elsewhere in the file;
  dead code, nothing running in production to repair.
- `generate-task-order.sh`'s `sed 's/\b\(.\)/\u\1/g'` — a `sed` `\b` construct, not a grep pattern;
  out of this audit's "grep pattern" scope.
- `roadmap-integration.sh`, `literature-fidelity-audit.sh`, `literature-search.sh`,
  `literature_combining_detect.py` — Python `re` calls, a different regex engine with no such
  compositional defect.
- `test-subagent-postflight-marker.sh`'s `\\backslash` — literal escaped text in a fixture
  string, not a regex `\b` construct.

**No WORKING pattern was rewritten anywhere in this task.**

## Discrepancies from the Research Report (recorded, not silently reconciled)

- `test-lake-build-guard.sh` case 3 (not `\b`-related — a command-substitution byte-equality
  assertion) **passed** on this implementation's run (47 passed, 0 failed), where the research
  report recorded it failing (46/1) on a stdout/stderr interleaving issue. Case 12b, the actual
  `\b` assertion, passed in both runs. This is recorded honestly as an observed discrepancy in the
  unrelated case, not absorbed or "fixed."
- `literature-audit.sh`'s "P4" (`\bFigure\s+[0-9]+(\.[0-9]+)*\b`) is printed only in the
  `audit_crossrefs()` header `echo` (a documentation label) — there is no `p4_count` computation
  or live `grep -oE` call for it anywhere in the script. Only P1–P3 are actual extraction sites.
  The research report's table described "four independent... patterns (P1–P4)"; this
  implementation found P4 documented-but-unimplemented, not a live site to test or repair.

## Administrative Follow-Ups (recorded, no cross-repo edit made)

- `lean-sorry-census.sh`'s regex fix (commit `232b05b7f`, 2026-08-10) and its fixture suite
  already exist in this repo's source store. The cslib consumer repo's own local task tracking
  this defect against a stale deployed copy should be abandoned with a pointer to commit
  `232b05b7f` and to this task, once that repo re-syncs its extension copy. No edit was made
  outside this repository.
- `literature-chunk.sh`'s `XREF_PATTERN` is dead code (defined, never referenced). Noted for
  whoever next touches that file; not removed here (no live risk to mitigate, per plan Non-Goals).

## What Changed

- `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md` — new file:
  the portability guidance note (invocation-context split, compositional defect explanation with
  worked bisection example, shape rule, delimiter-anchored preference, `-P` remedy,
  execute-before-commit obligation, engine-determination procedure).
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — added a
  pointer from the `HOOK_REGEX_BOUNDARY_DEFECT` paragraph to the new note.
- `agent-system/extensions/core/index-entries.json` — one new entry for the note
  (`standards/grep-word-boundary-portability.md`).
- `.claude/context/standards/grep-word-boundary-portability.md` and `.claude/context/index.json`
  — deploy output (regenerated, never hand-authored; confirmed byte-identical to the source copy).
- No production script or hook pattern was modified — every site tested WORKING.

## Decisions

- Treat "the deployed grep" as invocation-context-dependent in all future work, per the new
  guidance note; this correction was independently re-verified, not merely inherited from the
  research report.
- No pattern anywhere in scope was rewritten. A blanket `\b` removal would have been wrong:
  `guard-destructive-git.sh`'s `--hard\b`/`(drop|clear)\b` and every other site are live and
  re-confirmed WORKING.

## Plan Deviations

- None (implementation followed the plan). The two discrepancies from the research report noted
  above are recorded observations, not deviations from the plan's own tasks — the plan's Scope
  Hypothesis fields explicitly anticipated and required recording any such mismatch rather than
  silently reconciling it.

## Verification

- Build: N/A (no build system for this change)
- Tests: `test-guard-destructive-git.sh` 50/50; `test-lean-sorry-census.sh` 17/17;
  `test-lint-postflight-boundary.sh` 6/6; `test-session-runtime-files.sh` 6/6;
  `test-validate-no-task-references.sh` 31/31; `test-task-type-detect.sh` 10/10;
  `test-census-count.sh` 8/8; `test-lean-comparator-run.sh` 22/22 (1 unrelated skip);
  `test-lake-build-guard.sh` 47/0; `test-orchestrate-recover-message-findings.sh` 21/2 (2
  unrelated, pre-existing acceptance-e2e failures); `check-extension-docs.sh` PASS all
  extensions OK (deployed tree); `generate-context-line-counts.sh --check` CHECK PASSED (512/512
  exact); `validate-context-index.sh` PASSED (225 entries, 0 errors); `check-task-references.sh`
  PASS (0 unexempted occurrences in the new/edited files).
- Files verified: Yes — deployed note confirmed byte-identical to source via `diff`.

## Impacts

- Future `\b` grep-pattern authorship in this repo has a landed, indexed, deployed reference
  explaining why a pattern that "should" work can silently fail, and how to test it correctly
  before committing.
- No behavioral change to any production script, hook, or agent instruction — this task's
  footprint is additive documentation plus one index entry.

## Follow-ups

- The cslib consumer repo should abandon its local `lean-sorry-census.sh` defect task with a
  pointer to commit `232b05b7f` and this task, once it re-syncs its extension copy (out of this
  repository's scope to act on directly).
- `literature-chunk.sh`'s dead `XREF_PATTERN` could be removed by whoever next touches that file
  (no urgency; recorded here as a pointer, not actioned).

## References

- `specs/129_audit_word_boundary_regex_portability/plans/01_word-boundary-portability-audit.md`
- `specs/129_audit_word_boundary_regex_portability/reports/01_word-boundary-grep-audit.md`
- `specs/129_audit_word_boundary_regex_portability/progress/phase-1-progress.json` through
  `phase-5-progress.json`
- `agent-system/extensions/core/context/standards/grep-word-boundary-portability.md`
