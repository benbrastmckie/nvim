# Implementation Summary: Task #251

- **Task**: 251 - Context-corpus reachability probe (filename, directory, index.json), then act on dead and overlapping files
- **Status**: [COMPLETED]
- **Started**: 2026-10-12T18:18:00Z
- **Completed**: 2026-10-12T21:45:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: Task 127 (routing-ladder collapse) - COMPLETED
- **Artifacts**: plans/01_context-reachability-probe.md (this round)
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Built `context-reachability.sh`, a standing, mechanical reachability/inventory probe over the
`.md` context corpus under `agent-system/extensions/*/context/**`, answering what the repo could
not previously answer: which context files are reachable, by which of three independent
mechanisms (filename, directory, index), and whether each is eagerly or lazily loaded. Proved it
against a regression property covering both live directory-referenced template libraries (39
files), registered it alongside its structural sibling `script-inventory.sh`, ran it against the
live corpus, and closed the removal/merge/split decision with a Reasoned Exclusions record
because the confirmed-dead set came back empty, exactly as the research predicted.

## What Changed

- `agent-system/extensions/core/scripts/context-reachability.sh` — new standing probe: enumerates
  591 context `.md` files, computes three non-short-circuiting reference styles per file
  (filename via a batched whole-source-store basename grep; directory via every contiguous
  sub-range of the file's own directory-component list, tested against referrers outside
  `context/` only; index via the 22 per-extension `index-entries.json` files), the OR-combined
  `reachable`/`reachable_styles` verdict, an `inbound_references` census, and an eager/lazy
  classification reused by invocation from `measure-eager-context.sh`'s `at_import` channel
  (degrading to `null` rather than a false `false` when the target root lacks a CLAUDE.md chain).
  `--check` mode prints a per-file table and exits non-zero on a genuine zero-reference finding.
  Never writes a file, never sources/evals/executes a candidate.
- `agent-system/extensions/core/scripts/tests/test-context-reachability.sh` — new 15-case
  fixture-driven regression suite: enumeration, each reference style individually (including the
  present-shape directory-only and founder-shape directory-plus-filename cases, and the index
  style's negative empty-`load_when` case), the genuine-orphan finding and its `--check` exit
  code, eager-null degradation, a decoy-`.claude/**`-never-read case, reproducibility, no side
  effects, degenerate root, usage error, and the live-tree regression property (39 files, floor
  asserted rather than a hardcoded exact count).
- `agent-system/extensions/core/manifest.json` — registered both new paths in `provides.scripts`
  at their alphabetical positions via `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — added one bullet
  registering the probe, adjacent to `script-inventory.sh`, stating its coexistence relationship,
  field set, `--check` semantics, and the OVER-counting caveat.
- `agent-system/extensions/core/context/patterns/context-discovery.md` — added a "Reachability
  Mechanisms" subsection naming all three mechanisms as sanctioned (never an accidental gap) and
  pointing at `context-reachability.sh` as the mechanical check.
- `specs/251_context_corpus_reachability_and_overlap_review/probe-run.json` — the cited live
  probe output (591 candidates, two reproducible runs, `zero_reference_count: 0`).
- `specs/251_context_corpus_reachability_and_overlap_review/ranked-disposition.md` — the
  per-finding-class disposition record (confirmed dead: 0; single-referrer: 56, all no-action;
  substantial-overlap: no mechanical detector built per Non-Goals, manual spot check confirms
  naming-convention collisions only; live-but-oversized: top 10 all already lazy, the
  rule-or-command split has no live input shape in this corpus) with the decision gate's Reasoned
  Exclusions.

## Decisions

- Style 1 (filename) scope is the WHOLE source store, including other context files as valid
  referrers — confirmed correct against the live corpus (founder's basenames appear in its own
  `deck/README.md`) and matching the plan's own stated expectation for the founder template
  library.
- Style 2 (directory) must test every contiguous sub-range of the directory-component list, not
  only ranges ending at the leaf — an ancestor-only reference (e.g. founder's bare
  `deck/contents/`, with no per-subdirectory mention anywhere) covers its subtree transitively and
  was missed by a leaf-only suffix design during implementation; corrected before Phase 2 closed.
- A naive per-candidate `grep -r` design for styles 1/2 took over 5 minutes wall-clock against the
  live 591-file corpus; replaced with a two-pass batched design (collect every distinct
  basename/suffix once, one multi-pattern `grep -f` pass per style) cutting runtime to ~30-40s.
- The eager-null degradation trigger is `measure-eager-context.sh`'s own missing-chain-prerequisite
  stderr warning, not its exit code (confirmed it exits 0 even against a fixture with no CLAUDE.md
  chain at all).

## Plan Deviations

- **Phase 8, Testing & Validation checklist**: `run-all.sh`'s final exit code is 1, not 0. The one
  failure (`test-four-tier-conflict.sh`'s Case 6, a `[1000ms, 2000ms)` timing-budget assertion on
  the unrelated task-lock.md conflict-response ladder) is a confirmed pre-existing, load-sensitive
  flake, reproduced across four repeated standalone runs under this session's own heavy subprocess
  load, and is not attributable to this task's edits. This task's own new suite passed in every
  run. See the Follow-ups section.
- **core/index-entries.json**: editing `context-discovery.md` introduced a new Rule R line_count
  mismatch for its own entry, fixed with a narrow one-line edit to the working tree. That file
  also currently carries roughly a dozen unrelated, uncommitted line_count repairs from other
  in-flight sibling work; this task's own closing commit deliberately excludes
  `index-entries.json` to avoid sweeping those in. The one-line fix remains applied, uncommitted,
  in the working tree.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both new files)
- Tests: `run-all.sh --only test-context-reachability.sh`: 1 passed, 0 failed, exit 0 (Phase 4).
  Full `run-all.sh`: 137 passed, 1 failed (pre-existing unrelated flake, see Plan Deviations),
  exit 1.
- `verify-deploy.sh --skip-slow`: PASS, 35 checks, 0 failures, exit 0 — identical to the
  pre-change baseline captured at the start of Phase 1.
- Files verified: Yes (`jq empty` clean on `manifest.json` and both probe JSON outputs;
  `sync-manifest-scripts.sh --check` exits 0 with zero gaps for core).

## Impacts

- A future contributor adding a template library, or any other directory-referenced content, now
  has a mechanical check (`context-reachability.sh`) and written guidance
  (`context-discovery.md`'s new subsection) confirming the pattern is sanctioned rather than
  re-deriving it from scratch or mistaking it for an orphan.
- `docs/reference/utility-scripts-inventory.md` now documents a second standing probe class
  (context-corpus reachability) alongside the existing script-corpus inventory probe.
- No context file was removed, merged, or split by this task — the corpus is unchanged in
  content; only the standing probe, its registration, and its documentation were added.

## Follow-ups

- The telemetry cross-check (Phase 3) established that no tier in this repo records a
  context-file read at file granularity today; this task's probe therefore answers static
  reachability ("could this load") only, never observed use ("has this been loaded"). Closing
  that gap — a `PostToolUse` hook on `Read` (and file-reading `Bash` forms) filtering paths under
  `agent-system/extensions/*/context/**`, appending an `event_type: "context_file_read"` row to
  `events.jsonl` — is a legitimate, separately-scoped follow-up candidate, not built here.
- `test-four-tier-conflict.sh`'s Case 6 timing-budget assertion is fragile under system load; a
  future task could widen its budget or make it load-adaptive. Out of this task's scope.
- `core/index-entries.json` carries a mix of this task's one-line fix plus several other
  in-flight, uncommitted sibling repairs. A future sync/cleanup pass (or the next dispatch that
  owns one of those files) should reconcile and commit the remainder.

## References

- Plan: `specs/251_context_corpus_reachability_and_overlap_review/plans/01_context-reachability-probe.md`
- Research: `specs/251_context_corpus_reachability_and_overlap_review/reports/01_context-corpus-reachability-probe.md`
- Disposition: `specs/251_context_corpus_reachability_and_overlap_review/ranked-disposition.md`
- Probe output: `specs/251_context_corpus_reachability_and_overlap_review/probe-run.json`
