# Implementation Summary: Task #332

- **Task**: 332 - Books observer: the per-task convention observation record
- **Status**: [COMPLETED]
- **Started**: 2026-10-04T07:35:00Z
- **Completed**: 2026-10-04T09:45:00Z
- **Effort**: ~2.5 hours across 6 phases
- **Dependencies**: 298, 329, 330, 331 (all completed)
- **Artifacts**: plans/01_books-observer-record.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Registered the books extension's own post-task observer on the generic topic/task_type-keyed
observer seam and built `books-observe.sh`, which writes ONE OBSERVATION record per books-topic
task, joining the generic per-task records (`issues.jsonl`, `metrics.jsonl`) with books-specific
facts (`book_requires` churn, Validated-by marker promotions, and — present-or-`absent` — RUN-log
tier outcomes, vacuous passes, and a snapshot before/after delta). All eight touched files land in
the SOURCE STORE at `agent-system/extensions/books/**`, exactly matching the plan's Scope
Hypothesis.

**REQUIRED DEPLOYMENT CAVEAT, stated plainly**: none of this takes effect in any consuming
repository until the user (i) **loads the books extension there** — it is not currently loaded in
`~/Projects/Logos/Verification`, the one real consuming repository measured during research — and
(ii) **redeploys core**. Both are the user's own actions; this task cannot perform or verify
either. Until both happen, `books-observe.sh` is inert everywhere outside this source store.

## What Changed

- `agent-system/extensions/books/context/project/books/standards/observation-record.md` — new.
  The full OBSERVATION record schema: required/optional/omitted-never-zeroed field posture, the
  seven dimensions (`maintainability`, `cross_pollination`, `guardrails_qa`,
  `token_cost_efficiency`, `readability`, `intuitive_exposure`, `compiling_composing`) with
  verbatim key spellings cited from `docs/book-evidence.md`, the polarity rule, the paired-burden
  schema requirement (including the `tags.burden`/`tags.convention_decision` read contract added
  during Phase 3/4), the computed-vs-supplied division of labour, the probe ownership boundary
  (D3), vacuous passes as a first-class field, dual provenance marking (D2, per-group `source`
  markers), and the record location (D1: per-task canonical file plus a derived digest log).
- `agent-system/extensions/books/context/project/books/patterns/signal-tagging.md` — new. The
  working-agent guide for populating `tags.dimension`/`tags.polarity`/`tags.burden` on an
  `issues.jsonl` entry: one worked example per dimension (all seven), a paired-burden example,
  and a "what NOT to do" section.
- `agent-system/extensions/books/scripts/books-observe.sh` — new, executable. The observer:
  live mode (six positional arguments per the generic observer contract) and `--backfill`
  (single task via glob-resolved `specs/*_*` directories, or `--all` via `specs/state.json`
  topic/task_type filtering with a documented fallback). No `jq` dependency for JSON emission
  (D4); `jq` used only as an optional, fallback-covered enhancement on the read side.
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` — new, executable,
  Class B. 47 fixture-driven cases across the seven named acceptance behaviors (the join, the
  absent-probe path, the paired-burden requirement, polarity/dimension validation, backfill
  marking, non-blocking failure, vacuous pass), hermetic (isolated `mktemp -d` git repos, no
  network, no dependency on a real `specs/` tree or the external consuming repository).
- `agent-system/extensions/books/manifest.json` — added the top-level `observers.books-observe`
  block (`topic: "books"`, `task_type: "books"`, `timeout_seconds: 30`) and both new scripts to
  `provides.scripts`.
- `agent-system/extensions/books/index-entries.json` — registered both new context files
  (`signal-tagging.md` eager for the four books agents + `task_types: ["books"]`;
  `observation-record.md` `on_demand: true`, matching the existing corpus convention).
- `agent-system/extensions/books/README.md` — Directory Map line updated; new Observer
  subsection (Rule X's `check_observers_documented` requirement).
- `agent-system/extensions/books/EXTENSION.md` — Observer section (trimmed to stay within Rule
  U's 60-line cap) and two new context pointers.

## Decisions

- Conformed verbatim to the consuming repository's own pre-existing OBSERVATION-record design
  (`docs/book-evidence.md`, `book-evidence-observation-v1.md`) rather than re-deriving a schema —
  per the research report's central finding.
- Added `tags.burden` (`created`/`lifted`) and `tags.convention_decision` as optional sub-fields
  on the open `tags` object — the concrete read contract `burdens_created[]`/`burdens_lifted[]`
  needed, beyond the dimension/polarity pair alone (discovered while implementing Phase 3,
  retrofitted into the already-committed Phase 1/2 documents).
- `book_requires_churn` and `validated_by_promotions` are computed identically in live and
  `--backfill` mode (both are pure `git diff`/`grep` reconstructions with no live-only
  alternative); only the per-group `source: collected|backfilled` marker differs between modes.
- `--backfill` task-directory resolution is a plain glob over `specs/*_*`, deliberately not via
  `scripts/lib/task-lookup-lib.sh`, since the observer must run standalone in an arbitrary
  consuming repository.
- Followed `books-gate.sh`'s established `json_string`/`json_array` no-`jq` emission idiom (D4).

## Plan Deviations

- None (implementation followed plan). Two implementation-time refinements were made and
  recorded via `issue-record.sh` rather than treated as plan deviations, since neither changed a
  phase's scope or files-to-modify list: the `tags.burden` schema addition (Decisions, above),
  and trimming EXTENSION.md to satisfy Rule U's 60-line cap (not called out explicitly in the
  plan's Phase 6 task list).

## Verification

- Build: N/A (shell scripts + markdown).
- Tests: `test-books-observe.sh` 47/47 PASS, 0 FAIL. Two real bugs were caught by this suite and
  fixed inline before it went green: a `book_requires`-churn grep off-by-one
  (`^\+[^+].*book_requires` → `^\+[^+]*book_requires`) and a jq `index()`-argument-context bug in
  the unrecognized-dimension detector.
- `shellcheck -S warning` clean on `books-observe.sh` and `test-books-observe.sh`.
- `bash .claude/scripts/check-extension-docs.sh`: all 22 extensions PASS, including `books`
  (Rule X — `check_observers_resolve` + `check_observers_documented` — green for
  `observers.books-observe`; one expected pre-deploy ADVISORY for the not-yet-deployed script).
- `bash .claude/scripts/verify-deploy.sh --skip-slow`: PASS, 33 checks, 0 failures.
- `bash .claude/scripts/tests/run-all.sh` (full sweep, deployed-mode discovery): 103 passed, 6
  failed (2 expected per `known-failures.txt`, 4 confirmed pre-existing and unrelated to this
  task via `git log` provenance on each failing suite — last touched by tasks 240, 260, 148, and
  an unrelated `meta:` commit), 2 skipped, 111 total.
- `manifest.json` and `index-entries.json` both parse as valid JSON.
- `bash .claude/scripts/check-task-references.sh` on every file this task wrote or amended: 0
  unexempted occurrences in each.
- `validate-artifact.sh` on the plan (`--strict`): PASS, 0 warnings.
- `git status --short agent-system/extensions/books/` confirmed exactly the plan's Scope
  Hypothesis: eight touched files, no more, no fewer.
- No file was written under `.claude/**`.

## Impacts

- `books-observe` is the first real consumer of the topic-keyed observer seam (built inert by a
  prior task); it remains inert in every repository until the deployment caveat above is
  satisfied.
- A future consuming repository that builds a RUN log (`specs/books-evidence/runs.jsonl`) or a
  snapshot probe (`books/tool/book-snapshot.sh`) will see `books-observe.sh` automatically start
  populating `verification_tiers`, `certifier_outcomes`, `vacuous_passes`, and `snapshot_delta`
  with no observer-side change required — the present-or-`absent` contract was built for exactly
  this transition.
- Working agents dispatched against a `books`-topic task now have a documented tagging contract
  (`signal-tagging.md`) they must follow for any of their `issues.jsonl` signal to reach the
  observation record's dimension/burden analysis.

## Follow-ups

- The deployment caveat above: loading the books extension and redeploying core are required,
  user-performed actions with no automated path in this task.
- A concrete `--backfill --all` run against the ten completed books-topic tasks in
  `~/Projects/Logos/Verification` is explicitly out of this task's reach (that repository is not
  this one, and the books extension is not loaded there yet); the mechanism is built and tested
  against fixtures, but has not been exercised against that real corpus.
- `context/project/books/README.md`'s own navigation table was deliberately left unedited — the
  plan's Phase 6 file list names `README.md` (the extension-root one) and `EXTENSION.md`, not the
  corpus-internal `context/project/books/README.md`, and the corpus's own convention already
  permits reaching a document "by the path in the table below, **or by grep**," so this is not a
  gap, only a note for a future corpus-maintenance pass.

## References

- Plan: `specs/332_books_observer_convention_observation_record/plans/01_books-observer-record.md`
- Research report: `specs/332_books_observer_convention_observation_record/reports/01_books-observer-design.md`
- Standard: `agent-system/extensions/books/context/project/books/standards/observation-record.md`
- Tagging guide: `agent-system/extensions/books/context/project/books/patterns/signal-tagging.md`
- Observer: `agent-system/extensions/books/scripts/books-observe.sh`
- Test suite: `agent-system/extensions/books/scripts/tests/test-books-observe.sh`
- Prior task's guide section: `agent-system/extensions/core/docs/guides/creating-extensions.md`'s
  "Post-Task Observers" section
