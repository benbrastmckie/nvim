# Implementation Summary: Repo-Wide Lint Consumer for Record-Versioning

- **Task**: 281 - Build the repo-wide lint consumer for the record-versioning rule
- **Status**: [COMPLETED]
- **Started**: 2026-10-12T15:04:08Z
- **Completed**: 2026-10-13T03:40:00Z
- **Effort**: ~9 hours across two dispatches (seq 23 planning; seq 25 implement, stalled once
  after Phase 1 and re-prompted)
- **Dependencies**: 280 (rule/taxonomy/library task), 251
- **Artifacts**: plans/01_repo-wide-lint-consumer.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

Built the repo-wide lint consumer for `rules/no-record-versioning-in-deliverables.md`:
`scripts/check-record-versioning.sh` and its fixture test, driven entirely by
`scripts/lib/record-version-patterns.sh`. The plan budgeted four library-fix phases ahead of the
two deliverable-build phases, because the shared pattern library's original heading discriminator
flooded on `#`-comment lines in shell scripts (251 BLOCKING findings in this repo, 213 in the
Logos/Verification acceptance target) before any narrowing landed. All eight plan phases are
closed; this repo's own source-store residue is now exactly the three enumerated, out-of-scope
Himalaya docs.

## What Changed

- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` — blank-instead-of-delete
  line-number fidelity fix; `rv_is_markdown_path`, `rv_grep_blocking`, `rv_grep_advisory` added as
  the sole matching API; heading-form discriminator split into a bare-parenthesized
  (any-heading-level) branch and an H1-only page-title branch, both gated to markdown paths only;
  non-heading BLOCKING group matched case-sensitively against non-markdown paths to avoid
  colliding with this corpus's uppercase `V<N>` invariant-label convention; two new durable-axis
  shapes (schema/format-anchored, and a narrow literal Tailwind/Tailwind-CSS anchor — deliberately
  not a generic capitalized-phrase-before-`vN` heuristic, which was tried and rejected because it
  also swallowed genuine page-title violations)
- `agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh` — 20 new
  assertions across the line-number-fidelity, path-class-gating, label-position-narrowing,
  case-sensitivity, and durable-axis-extension work; self-referential fixture block wrapped in a
  `version-ok:begin`/`end` pair with a header NOTE
- `agent-system/extensions/core/scripts/check-record-versioning.sh` — new file, the first
  deliverable: modeled on `check-task-references.sh`, with the BLOCKING/ADVISORY two-tier
  contract as its one new surface (two counters, tier-labeled finding lines, ADVISORY never
  affects the exit code). Includes a `declare -F` guard added during Phase 8 acceptance testing
  that fails loudly (exit 2) when the sourced library is stale/incompatible, rather than silently
  reporting a false clean pass
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` — new file, the
  second deliverable: 17 assertions covering all four required behaviors plus sibling-parity
  cases (specs/** exemption, gitignore exclusion, PATH_SCOPE forms, durable-axis no-finding, and
  a regression guard for the stale-library defect found during acceptance testing)
- `agent-system/extensions/core/manifest.json` — registered both new scripts
  (`provides.scripts` and the tests list)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — catalogue bullet
  for the new lint
- `agent-system/extensions/core/rules/no-record-versioning-in-deliverables.md` — marked its own
  quoted forbidden-vocabulary examples exempt (self-referential, category: test fixture for the
  reference-pattern detector itself)
- `agent-system/extensions/core/context/standards/record-version-exemptions.md` — marked its own
  quoted historical-incident example exempt; documented the two new durable-axis shapes
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — de-versioned
  the `## Absent file_scope Hazard: The Split Admission Posture (v6)` heading and its body's
  "through v5" reference, per a binding ruling from the dispatching session
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — de-versioned the
  "post-v5, where it previously always did" line, per the same binding ruling

## Decisions

- **Named-tool durable-axis anchor is narrow and literal, not a generic heuristic.** A
  capitalized-phrase-before-`vN` pattern was tried and rejected: it also matched "Draft System
  v2" and would have matched "Himalaya Plugin Architecture V2" — both genuine, un-swept
  page-title violations that must stay BLOCKING. The literal `Tailwind`/`Tailwind CSS` anchor
  covers the only measured real instance without this collision.
- **Non-markdown BLOCKING matching is case-sensitive; markdown stays case-insensitive.** This
  corpus's `V<N>` uppercase internal-invariant-label convention (`V5 contended-path lease`, `the
  V8 mismatch predicate`) collided with the past-tense-escalation pattern under case-insensitive
  matching in `.sh` comments; record-version tokens are lowercase by convention, so narrowing the
  non-markdown case to case-sensitive sheds the false-positive class with zero measured loss of a
  real positive.
- **A stale/incompatible library is an environment error (exit 2), never a silent pass.** Found
  during Phase 8 acceptance testing: calling an undefined `rv_grep_blocking` inside a pipeline
  whose stderr is redirected to `/dev/null` produced a silent no-op, making a genuinely broken
  invocation indistinguishable from a clean repo. `check-record-versioning.sh` now verifies all
  five required library functions are defined before scanning.
- **The two judgment-call residue lines are de-versioned in place, not exempted.** A binding
  ruling from the dispatching session settled the open question (is the "numbered-ruling idiom" a
  legitimate convention or a real instance of the anti-pattern?) in favor of de-versioning; the
  surrounding `(vN Ruling)`-suffixed headings elsewhere in `batch-admit-schema.md` were
  deliberately left untouched since "Ruling" breaks the bare-parenthesized shape and they were
  never part of the measured residue.

## Plan Deviations

- **Phase 6** (test-check-record-versioning.sh): built 332 lines / 13 case blocks (16 `[PASS]`
  lines) against a hypothesized 260-300 lines / 12-14 cases — modestly over, attributable to the
  extra tier-split-specific cases the two-tier contract requires beyond the single-tier sibling.
- **Phase 8**: the judgment-call-line disposition's planned mechanism (raise a non-blocking
  `user_decision`) was overridden by a binding ruling to de-version directly instead — applied as
  instructed, not re-raised. A fifth residue class (deploy staleness of this repo's own core, and
  of Verification's deployed core) was not among the plan's named four classes but was
  independently confirmed, attributed, and resolved by verification technique (temporary
  fixed-library substitution, restored byte-identical) rather than by a workaround.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on every touched file)
- Tests: `test-record-version-patterns.sh` 50/50 PASS; `test-check-record-versioning.sh` 17/17
  PASS — both verified against the real source-store library via a scratch-copy technique
  (deploy-tree-first resolution in the real test harness means the officially-wired run only
  reflects source-store edits after the next redeploy)
- Shellcheck: 0 findings at `-S warning` on all five touched/created `.sh` files
- Files verified: Yes — all ten touched files confirmed on disk; two new files confirmed present
  and executable

## Impacts

- Once this repo's `core` extension is redeployed, a repo-wide `check-record-versioning.sh` run
  against this repo drops from 251 BLOCKING findings to 3 (the enumerated Himalaya docs) — a
  reduction confirmed directly, not estimated.
- The Logos/Verification acceptance target's named-files sub-claim (zero BLOCKING on
  `docs/ci.md`, `docs/consuming.md`, `docs/stability-and-versioning-policy.md`) is met today,
  confirmed against the fixed library. The repo-wide sub-claim (exit 0 with no arguments) is
  blocked purely on that repo's own deploy cycle, which is out of this task's scope.
- A latent silent-false-pass defect in the deliverable script itself was caught and closed before
  any consumer could rely on it, with a permanent regression test.

## Follow-ups

- This repo's own `core` extension needs a redeploy before `check-record-versioning.sh`'s
  no-argument run against this repo, and `test-record-version-patterns.sh`'s run via the
  officially-wired `run-all.sh`, both reflect this task's committed fixes (currently both show
  stale-library-induced false failures that are NOT real regressions — independently reconfirmed
  clean against the real source-store library throughout this task).
- The Logos/Verification repo's own deployed `core` needs a separate redeploy, after this repo's,
  before its repo-wide `check-record-versioning.sh` run exits 0 (currently 14 BLOCKING, all
  inside its own deployed `.claude/` copies of files this task fixed at the source).
- `hooks/validate-no-record-versioning.sh` (the write-time guard) does not exist yet — explicitly
  out of scope for this task (task 282).
- **Non-blocking user decision** (see `.return-meta.json`): three Himalaya plugin docs
  (`lua/neotex/plugins/tools/himalaya/docs/ARCHITECTURE_V2.md`, `ARCHITECTURE_V3.md`,
  `DRAFT_SYSTEM_V2.md`) carry genuine, un-swept page-level version-labeled H1 titles. They are
  absent from the Verification repo and do not gate its acceptance bar. Recommended: leave as-is
  — the version label is in the filename of a live, user-facing config, so remediation means
  renaming files a person actively uses, not merely editing prose.
- Two cosmetic test infrastructure gaps logged but not fixed (outside this task's scope):
  `check-task-references.sh` carries the same post-strip line-number-drift defect this task fixed
  for its own library (`test-record-version-patterns.sh`/`test-check-record-versioning.sh`'s own
  deploy-tree-first library resolution means in-dispatch source-store edits are invisible to
  `run-all.sh` until the next redeploy — recorded as an issue, not a defect in the test design
  itself, since the convention is deliberate and shared with `test-phase-heading-patterns.sh`).

## References

- `specs/281_record_versioning_repo_wide_lint/plans/01_repo-wide-lint-consumer.md`
- `specs/281_record_versioning_repo_wide_lint/reports/01_repo-wide-lint-consumer-research.md`
- `specs/281_record_versioning_repo_wide_lint/progress/phase-1-progress.json` through
  `phase-8-progress.json`
- `specs/281_record_versioning_repo_wide_lint/issues.jsonl`
