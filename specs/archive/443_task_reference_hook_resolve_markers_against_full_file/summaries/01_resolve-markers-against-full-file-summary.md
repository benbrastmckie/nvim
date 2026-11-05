# Implementation Summary: Task #443

- **Task**: 443 - Task-reference hook resolve markers against full file
- **Status**: [COMPLETED]
- **Started**: 2026-10-19T00:00:00Z
- **Completed**: 2026-10-19T04:10:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_resolve-markers-against-full-file.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The write-time task-reference gate (`hooks/validate-no-task-references.sh`) previously scanned
only the current Edit call's own `new_string` payload, so a file-wide `task-ref-ok:begin`/`:end`
exemption pair living outside the edited span was structurally invisible to it, forcing redundant
nested marker pairs around every new fixture literal. This task replaced the shared library's
boolean-toggle marker parser with a depth-counting parser carrying an explicit well-formedness
verdict, taught the hook to resolve an Edit's exemption against the reconstructed post-edit file
(region-aware, over the inserted lines only), gave the repo-wide lint a named diagnostic for an
invalid marker parse, and documented the resulting resolution semantics — closing the exact gap
the dispatch observed while keeping the Write path, the fail-open contract, and every
pre-existing assertion unchanged.

## What Changed

- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` — `strip_exempt_regions`
  rewritten as a depth-counting parser with a well-formedness verdict (unterminated `begin` or a
  stray `end` grants no exemption from the outermost still-open `begin` through EOF); added
  `exempt_line_mask` (one `1`/`0` per input line) and `marker_balance_report` (a one-line
  diagnostic, silent when well-formed), all sharing one `_trp_scan` awk program.
- `agent-system/extensions/core/hooks/validate-no-task-references.sh` — unified tool-input
  parsing into one `TOOL_JSON` object; discriminates Write vs. Edit by field presence
  (`content` -> Write, `old_string`/`new_string` -> Edit), never by `tool_name`. Write path is
  byte-for-byte unchanged. Edit path reconstructs the post-edit file (`old_string` spliced to
  `new_string` via literal bash parameter expansion, never sed/regex), records each insertion's
  1-based line range, and exits 0 iff every inserted line is exempt per `exempt_line_mask` —
  otherwise scans only the non-exempt inserted lines. Any untrustworthy reconstruction (empty
  `old_string`, unreadable file, zero occurrences, or an ambiguous occurrence count) degrades to
  exactly today's payload-only scan of `new_string` alone.
- `agent-system/extensions/core/scripts/check-task-references.sh` — additive named
  "UNBALANCED MARKER in `<file>`: `<report>`" finding via `marker_balance_report`, contributing
  to the exit-1 count like an ordinary citation finding; silent on a well-formed parse.
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` — new
  "### Resolution Algorithm (Region-Aware Marker Exemption)" subsection under the existing
  "## Enforcement" section, stating the Edit/Write resolution basis, the validity rule, nested-
  pair depth resolution, the degrade condition, and the "a marker token named in prose is itself
  a marker" hazard, all without embedding the literal substring in the new prose itself.
- `agent-system/extensions/core/scripts/tests/test-task-reference-patterns-lib.sh` — new,
  dedicated parser suite (19 assertions across 9 cases): well-formed pair, nested pairs, stray
  end, unterminated begin, unterminated begin after a well-formed pair, inline form, same-line
  begin+end, no markers, and mask arity.
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` — new
  `run_hook_edit`/`hook_edit_exit_code` helpers plus the dispatch's six-case matrix and two
  degenerate Edit cases (11 new assertions; 45 total, all green, every pre-existing one
  unchanged).
- `agent-system/extensions/core/scripts/tests/test-check-task-references.sh` — new nested-pair
  regression fixture (`docs/nested-pair.md`) confirming the lint's whole-file behavior is
  unaffected by the library's internal rewrite.
- Five test files rebalanced for marker hygiene ahead of the parser change (`test-git-commit-
  phase.sh`, `test-git-commit-scoped.sh`, `test-orchestrate-record-decision.sh`,
  `test-check-task-references.sh`, `test-gate-cache-equivalence.sh`): redundant nested `begin`
  blocks removed and prose mentions of the literal marker token reworded to generic phrasing.
- `agent-system/extensions/core/manifest.json` / `scripts/tests/suite-cost-hints.txt` — new test
  script registered; advisory cost hint added.
- `agent-system/extensions/core/index-entries.json` — `task-reference-exemptions.md`'s declared
  `line_count` regenerated (140 -> 181) via `generate-context-line-counts.sh --write`.
- A regenerated `.claude/` deploy tree (all nine touched source-store files plus the new test
  script verified byte-identical against the deployed copies).

## Decisions

- Region-aware resolution over the reconstructed post-edit file (not a whole-file boolean) was
  adopted, matching the research report's recommendation: a whole-file boolean would be a
  standing bypass and diverge from the repo-wide lint's own region-based stripping.
- The "outermost still-open begin" rule (depth 0->1 transition that never returns to 0) names the
  start of the non-exempt span on an invalid parse — stricter than a "last unterminated begin"
  reading, and deliberately so.
- A line carrying BOTH a begin and an end marker substring is treated as a self-contained pair
  with no net stack effect, rather than inheriting the old toggle's begin-checked-first quirk.
  This decision was pinned by a dedicated test case and later proved its value directly: Phase
  5's post-redeploy verification caught a genuine stray end in pre-existing prose
  (`test-validate-no-task-references.sh`'s own header) that every naive ad-hoc balance-trace
  snippet used throughout this implementation — copied from the plan's own Phase 1 text — had
  been unable to see, because that snippet shares the old toggle's blind spot for a same-line-
  both-tokens line.
- Every new fixture token or citation needed as deliberately-unbalanced or deliberately-citing
  test data is composed at runtime from concatenated parts (marker tokens) or kept in its own
  variable assignment with a trailing inline `# task-ref-ok` comment (citations), so no new file
  this task added destabilizes the repo's own marker-hygiene trace.

## Plan Deviations

- Phase 5's Tier Justification named `agent-system/extensions/core` as `verify-deploy.sh`'s
  TARGET argument; that path is not a repo root and the script errors on it. Ran with the repo
  root as TARGET instead — the shape the script's own usage documents.
- Per this dispatch's own Batch Gate Deferral directive, the complete `verify-deploy.sh` /
  `tests/run-all.sh` battery was not run independently in this dispatch; a scoped verification
  (`--only-gate 3,4,10` plus `--only` runs covering every touched suite) was run instead, with
  the full set deferred to the once-per-invocation batch-level stage.
- A retroactive fix landed in Phase 5 to a Phase-3-touched file
  (`test-validate-no-task-references.sh`): Phase 5's post-redeploy gate-4 re-run, using the real
  freshly-deployed parser, surfaced a genuine stray end in that file's own pre-existing header
  prose. Reworded; reconfirmed clean via a direct whole-tree sweep using the real
  `marker_balance_report` (not the simplified ad-hoc awk snippet used earlier).
- A scope-excursion was recorded (non-fatal): regenerating `index-entries.json`'s line_count for
  this task's own doc edit required committing that file directly (outside task 443's declared
  `file_scope`); doing so via a whole-file commit also swept in an already-present, correct,
  pre-existing-but-uncommitted entry for a different file that a concurrent sibling task had
  apparently already fixed. Content is correct either way; only the commit attribution landed
  under task 443 instead of its own task.
- A pre-existing, unrelated bug was discovered and reported, not fixed (out of this task's own
  scope and Phase 5 modifies no source files by design):
  `test-gate-cache-equivalence.sh`'s `REPO_ROOT` computation is off-by-one for the deployed path
  depth, landing one level above the real repo root and breaking that suite's own
  git-worktree-fixture setup when run via its deployed copy directly. Its source-store invocation
  is unaffected.

## Verification

- Build: N/A (shell scripts and markdown; no compiled build step)
- Tests: Passed — `test-task-reference-patterns-lib.sh` (19/19), `test-validate-no-task-
  references.sh` (45/45), `test-check-task-references.sh` (14/14), `test-manifest-scripts-
  sync.sh`, `test-script-inventory.sh`, `test-git-commit-phase.sh`, `test-git-commit-scoped.sh`,
  `test-orchestrate-record-decision.sh` all green via `run-all.sh --only ...`.
  `test-gate-cache-equivalence.sh` (source-store invocation): 15 passed, 2 failed — both failures
  are the pre-existing, documented load-sensitive gate10/gate4 timeout pair, unrelated to this
  task's edits (confirmed by isolated direct runs of the affected gates completing clean and fast
  outside the full battery's load).
- Files verified: Yes — all nine touched source-store files plus the new test script diff
  byte-identical against their deployed `.claude/` counterparts.
- Repo-wide lint: `check-task-references.sh --quiet` exits 0 on the clean tree; a seeded
  unterminated-begin scratch fixture produces the named "UNBALANCED MARKER in ..." finding and a
  non-zero exit, removing it restores exit 0.
- Whole-tree marker balance: zero imbalance under the real `marker_balance_report` (confirmed
  twice — once before the Phase 5 fix revealed a real stray end, once after).
- Live deployed hook: exercised end-to-end via real Edit/Write tool calls (not just synthetic
  payloads) — an Edit inside a file-wide marker pair with no nested pair is allowed; an unmarked
  citation is still blocked.
- Record-versioning / task-reference scan: `check-record-versioning.sh`'s 3 BLOCKING findings are
  all pre-existing, under `lua/neotex/plugins/tools/himalaya/docs/`, unrelated to this task; none
  under `agent-system/**`.

## Impacts

- Any future new test fixture or contributor-facing script in this repo that needs a marker
  pair no longer needs to duplicate it per edited region when a file-wide pair already exists —
  the hook now resolves exemption against the real post-edit file.
- The repo-wide lint now names an invalid marker parse explicitly instead of surfacing it only as
  a sudden pile of unrelated citation findings from the newly-unexempt trailing span.
- A latent class of self-tripping prose (a sentence that writes out the marker token in full) is
  now documented as a named hazard in `task-reference-exemptions.md`, and this task's own
  implementation hit that exact hazard twice (Phase 1's five pre-existing files, and Phase 5's
  late-discovered sixth instance), reinforcing that the hazard is real and recurring rather than
  theoretical.

## Follow-ups

- `test-gate-cache-equivalence.sh`'s `REPO_ROOT` off-by-one for deployed-path invocation (see
  Plan Deviations) is unassigned; a future task should recalibrate its path-depth arithmetic or
  switch it to `common.sh`'s git-aware `common_test_repo_root` helper.
- The commit-attribution mismatch for `index-entries.json`'s `shell-script-testing.md` entry
  (see Plan Deviations) may warrant a note to whichever sibling task owns that file if its own
  commit history is later audited.

## References

- Plan: `specs/443_task_reference_hook_resolve_markers_against_full_file/plans/01_resolve-markers-against-full-file.md`
- Research: `specs/443_task_reference_hook_resolve_markers_against_full_file/reports/01_resolve-markers-against-full-file.md`
- Progress files: `specs/443_task_reference_hook_resolve_markers_against_full_file/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/443_task_reference_hook_resolve_markers_against_full_file/handoffs/phase-{1..5}-handoff-*.md`
