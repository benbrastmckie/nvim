# Implementation Plan: Task #332

- **Task**: 332 - Books observer: the per-task convention observation record
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 298 (books context corpus), 329 (issue log + `tags` seam), 330 (dispatch metrics + `--backfill` precedent), 331 (topic-keyed observer seam) — all four `completed`
- **Research Inputs**: specs/332_books_observer_convention_observation_record/reports/01_books-observer-design.md
- **Artifacts**: plans/01_books-observer-record.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Register the books extension's own post-task observer on the generic topic/task_type-keyed
observer seam and build `books-observe.sh`, which writes ONE OBSERVATION RECORD PER BOOKS TASK
joining the generic per-task records (`issues.jsonl`, `metrics.jsonl`) with books-specific facts,
so that "is this convention actually working?" is answerable from accumulated evidence. All edits
land in the SOURCE STORE at `agent-system/extensions/books/**` — never `.claude/**`, which is a
gitignored deploy artifact regenerated from the source store. Definition of done: the seven
deliverable files exist in the source store, the observer is registered and documented such that
`check-extension-docs.sh` Rule X passes, the fixture test suite covers the join plus the five
named acceptance behaviors, and shellcheck is clean per `context/standards/shell-strict-mode.md`.

### Research Integration

The research report is load-bearing and changes the shape of this work in four ways:

1. **The record's schema is not a blank slate.** The consuming repository
   `~/Projects/Logos/Verification` has already designed it: `docs/book-evidence.md` plus
   `books/schema/book-evidence-{snapshot,run,observation}-v1.md` name the agent system's books
   extension as the record's **sole writer**, define the seven-dimension/polarity vocabulary with
   exact key spellings, and give the repo-side/agent-side field split. The plan conforms to that
   vocabulary verbatim rather than re-deriving one: `maintainability`, `cross_pollination`,
   `guardrails_qa`, `token_cost_efficiency`, `readability`, `intuitive_exposure`,
   `compiling_composing`; polarity `positive`/`negative`.
2. **Neither repo-side probe exists yet** — both schema documents say so verbatim ("no script
   exists yet that writes this shape"), and `specs/books-evidence/` does not exist at all. So the
   "invoke if present, record `absent` otherwise" contract is not a rare edge case: measured
   today it is the *only* path for every tier-run, certifier-class, vacuous-pass and
   snapshot-delta field. Producing `absent` there is CORRECT output, not a defect, and the test
   suite must assert that explicitly.
3. **Only two books-specific facts are mechanically computable today** with no probe dependency:
   `book_requires` churn (pure `git diff`/`grep` over the task's commit range) and Validated-by
   marker promotions keyed by a Decision's durable heading name (a `git diff` of
   `docs/book-convention.md` scoped to `- **Validated by**:` lines, with heading lookback). These
   are implemented unconditionally; everything else is present-or-`absent`.
4. **The dispatch's "task 298 has not yet run" premise is stale** — 298 completed and landed a
   17-file corpus with an established `index-entries.json` tiering convention. The two new context
   files register into that existing convention (research recorded this to `issues.jsonl` at
   severity `minor`). Research further recommends `patterns/signal-tagging.md` get the same
   **eager** `load_when` as the corpus `README.md` (the four books agents + `task_types: [books]`)
   because tagging must actually reach working agents, while `standards/observation-record.md`
   takes `on_demand: true` like the other sixteen documents.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists in this repository but no `roadmap_path` was supplied in this dispatch's
delegation context, so it was not consulted and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Register `observers.books-observe` in `manifest.json` matching BOTH topic `books` and task_type
  `books`, and declare both new scripts in `provides.scripts` so they actually deploy.
- Ship `scripts/books-observe.sh`: the join, computed-vs-supplied division of labour, polarity +
  seven-dimension validation, first-class vacuous passes, paired burdens, snapshot delta or
  `absent`, and a `--backfill` mode.
- Ship `scripts/tests/test-books-observe.sh`: fixture-driven, hermetic, no dependency on the
  external consuming repository.
- Ship the two context documents: the observation-record standard and the signal-tagging guide.
- Register both context files in `index-entries.json` and document the observer in `EXTENSION.md`
  **and `README.md`** (Rule X checks `README.md` specifically).

**Non-Goals**:
- Shipping a snapshot probe from the extension. The repository owns its probes and the contract
  for them; the extension owns the join. This boundary is binding (dispatch) and the observer's
  correctness must not depend on a probe existing.
- Triggering a build to produce any figure. The consuming repository's own "build-free" constraint
  applies to this side of the join too: an underivable figure is `absent`, never inferred as zero.
- Restructuring the books context corpus tree or editing any of the sixteen documents the corpus
  effort authored. This task ADDS two files to that tree.
- Adding lifecycle hooks. `manifest.json` has `provides.hooks: []` and no top-level `hooks` object;
  this task adds the `observers` block only.
- Loading the books extension in the consuming repository or redeploying core. Both are the
  user's actions (see "Required deployment caveat" below).
- Any write under `.claude/**`.

## Decisions

**D1 — Record location: per-task canonical file plus a derived accumulating log.** The dispatch
says the record is "appended to a log in the consuming repository's `specs/` tree";
`book-evidence-observation-v1.md` instead rules one file per task at
`specs/{NNN}_{SLUG}/book.observation.json`, beside `.decisions.json`. Resolution: write the
**canonical** record to the owner-ruled per-task path (an existing, settled contract this
extension should conform to, not re-litigate), and **additionally append a compact digest line**
to `specs/books-evidence/observations.jsonl` — explicitly defined in the standard as a
pointer/derived index over the canonical records, never a second source of truth. This satisfies
both the owner's ruling and the dispatch's cross-task-readability intent ("answerable from
accumulated evidence"). `specs/books-evidence/` is the directory the repository already reserves
for this family (`runs.jsonl` lives there), so no new convention is invented. The standard states
the primary/derived relationship so a later reader cannot mistake the digest for authority.

**D2 — Dual provenance marking, because neither convention subsumes the other.** Carry the
generic `backfilled: true` + `figure_provenance` (`measured`/`derived` per figure) shape from
`context/formats/dispatch-metrics.md` for the joined issues/metrics half, AND the per-field-group
`source: collected|backfilled` marker from `book-evidence-observation-v1.md` for the
books-specific groups. They mark the same concern at different granularities.

**D3 — Conventional probe path, pinned by this extension's own standard.** The repository's schema
deliberately leaves the probe path open ("the effort that builds it owns the exact script path"),
so the standard pins the basename the observer LOOKS FOR — `books/tool/book-snapshot.sh`, with
`--json` and `--diff A B` as the schema document itself describes — tests it for executability,
and records `"snapshot_delta": "absent"` otherwise. Looking for a path is not shipping a probe.

**D4 — No `jq` dependency for JSON emission.** Follow `books-gate.sh`'s established
`json_string`/`json_array` `sed`/`awk` helper idiom: the observer runs inside an arbitrary
consuming repository where `jq` is not guaranteed. `jq` may be used only as an optional
enhancement with a documented fallback on the READ side (the two generic logs it joins).

**D5 — Omit, never zero.** Every field the observer cannot derive is omitted (or carries the
literal string `absent` where the schema names that sentinel), never a `0` or a fabricated count.
A fail-soft shape mismatch omits the group rather than guessing.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `check-extension-docs.sh` Rule X fails: observer undocumented in `README.md`, or script absent from `provides.scripts` | H | H | Phase 6 updates `README.md` (Directory Map line + explicit Observer subsection) and adds BOTH `books-observe.sh` and `tests/test-books-observe.sh` to `provides.scripts`; the phase's `full` tier runs the check itself |
| Building against an imagined RUN-log / SNAPSHOT-probe shape that drifts from what the repository later builds | H | M | Read strictly through the schema documents' own field names and the documented `--json`/`--diff` read-path contracts; fail soft (omit, never guess) on any shape mismatch, mirroring `dispatch-metrics.sh`'s transcript-join fail-soft ladder |
| Vacuous passes get inferred rather than read, i.e. the single most expensive measured signal becomes second-class | H | M | Schema makes `vacuous_passes` a required first-class field; the test suite asserts it is populated from a supplied source or `absent`, never computed by negation of a pass |
| `--backfill`'s commit-subject grep over-matches a reused task number in the consuming repository's history | M | M | Inherit `dispatch-metrics.sh --backfill`'s documented limitation and caveat verbatim rather than attempting a stronger-than-precedent fix inside this task's scope |
| Dimension tags get guessed by the observer instead of read from `tags` | H | M | Standard states the computed-vs-supplied division explicitly; observer reads `tags.dimension`/`tags.polarity` and emits an `untagged_count` for entries lacking them — never a default tag; test asserts an untagged entry stays untagged |
| Context-vocabulary drift if a future `docs/book-evidence.md` revision respells a dimension key | M | L | Both new context files cite the origin document **by filename** so a future reviewer can diff the two vocabularies directly |
| Feature ships inert: books extension not loaded in the consuming repository and core not redeployed | H | H | The required deployment caveat is a tracked completion obligation (Phase 6 task item + Testing & Validation checklist item) |
| An accidental task-number reference lands in a source-store file | M | M | `rules/no-task-references-in-deliverables.md` applies to every file this task writes; cite durable anchors (filenames, Decision heading names) only. Phase 6's gate includes the repo-wide reference lint |
| A file hand-authored under `.claude/**` is silently wiped by the next deploy | H | L | Every phase's file list is source-store-only; `rules/source-store-deploy-boundary.md` |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 2, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Freeze the observation-record standard [COMPLETED]

**Goal**: Write `context/project/books/standards/observation-record.md` — the schema the script
then implements. This is first because every later phase reads its field names off this document.

**Tasks**:
- [x] Write the full OBSERVATION record schema: required keys, types, per-key
      required/optional/omitted-never-zeroed posture, and the record's own version marker. *(completed)*
- [x] Define the seven dimensions with definitions, using the verbatim key spellings
      (`maintainability`, `cross_pollination`, `guardrails_qa`, `token_cost_efficiency`,
      `readability`, `intuitive_exposure`, `compiling_composing`), mapping each to the
      dispatch's (a)-(g) prose. Record that `compiling_composing` carries IMPORT WEIGHT and
      COMPILATION WEIGHT as first-class sub-fields, not folded into a general performance note. *(completed)*
- [x] Define the polarity rule: every signal carries `positive` or `negative` plus one or more
      dimensions; a signal with no dimension is retained and counted as untagged, never defaulted. *(completed)*
- [x] Define the paired-burden rule as a SCHEMA requirement: `burdens_created[]` and
      `burdens_lifted[]` are both always present (default `[]`), never one without the other;
      each entry at minimum `{description, dimension, convention_decision}`. *(completed)*
- [x] Define the computed-versus-supplied division of labour: MECHANICAL fields are computed by
      the observer (tier runs, timings, churn, outcome classes, snapshot delta); DIMENSION TAGS
      are supplied by working agents through the `tags` object on issue-log entries and are READ,
      never guessed. *(completed)*
- [x] Define the probe ownership boundary (D3): the repository owns its probes and their contract;
      the extension owns the join; the looked-for conventional path and its `--json`/`--diff A B`
      read contract; `absent` when missing; the extension ships no probe. *(completed)*
- [x] Define vacuous passes as a first-class required field — a gate that passed while checking
      nothing — supplied, never inferred by negation. *(completed)*
- [x] Define the dual provenance marking (D2) and the omit-never-zero discipline (D5). *(completed)*
- [x] Define the record location and the primary/derived digest relationship (D1). *(completed)*
- [x] Summarize the consuming-repo-side field split generically ("if your consuming repository
      supplies a probe shaped like this contract, expect these fields"), citing
      `book-evidence-observation-v1.md` and `docs/book-evidence.md` by filename as the
      vocabulary's origin — without copying repo-specific prose, so the corpus stays usable by
      any consuming repository. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the dimension vocabulary is exactly seven keys with the spellings listed
above, and the polarity enum exactly `positive`/`negative`. Confirm at implementation time by
re-grepping `~/Projects/Logos/Verification/docs/book-evidence.md` and
`books/schema/book-evidence-observation-v1.md` for the key list before writing the table; if the
spellings differ, conform to the source document and note the divergence rather than keeping the
plan's list.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/standards/observation-record.md` - new: the full observation-record standard

**Verification**:
- File exists, non-empty, and contains a named section for each of: schema, seven dimensions,
  polarity rule, paired-burden rule, computed-vs-supplied, probe ownership boundary, vacuous
  passes, provenance marking, record location.
- No task-number references anywhere in the file (`rules/no-task-references-in-deliverables.md`).
- Every cross-reference is a filename or section heading, never a task number.

---

### Phase 2: Signal-tagging guide for working agents [COMPLETED]

**Goal**: Write `context/project/books/patterns/signal-tagging.md` so working agents know how to
populate `tags` on an issue-log entry — the open seam the observer reads and must never guess.

**Tasks**:
- [x] State the mechanism: `tags` is an open object on an `issues.jsonl` entry, written via
      `issue-record.sh`; core neither validates nor depends on its interior, which is precisely
      why it is this extension's tagging seam. No change to `issue-record.sh` or the core schema
      is needed or permitted. *(completed)*
- [x] Give the exact `tags` shape the observer reads (`dimension` — one or more of the seven
      keys — plus `polarity`), with the tagging obligation stated for both `kind: issue` and
      `kind: win` entries. *(completed)*
- [x] Give one worked example per dimension (seven worked examples), each a realistic books
      situation with the full tagging payload. *(completed)*
- [x] Give worked examples of a PAIRED burden: the created-burden entry and the lifted-burden
      entry recorded together, with the bearing convention Decision named by its durable heading
      name, so a later review cannot read half of a trade and call it a win. *(completed)*
- [x] State what NOT to do: do not invent dimension keys, do not omit polarity, do not tag
      retroactively at the end of a dispatch (record as signals arise), do not expect the observer
      to infer a tag. *(completed)*
- [x] Cite `docs/book-evidence.md` by filename as the vocabulary's origin, and
      `context/formats/issue-log.md` for the `tags` seam itself. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: seven worked examples, one per dimension, plus at least one paired-burden
example. Confirm by counting the rendered examples against the frozen dimension list from Phase 1
before closing the phase.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/signal-tagging.md` - new: the signal-tagging guide

**Verification**:
- File exists; every one of the seven dimension keys appears in a worked example.
- Dimension keys and polarity values match Phase 1's frozen vocabulary exactly (diff the two
  files' key lists).
- No task-number references.

---

### Phase 3: The observer script — live-mode join [COMPLETED]

**Goal**: Write `scripts/books-observe.sh` implementing the Phase 1 schema in live mode: the join,
the two unconditionally-computable books facts, the present-or-`absent` probe-dependent groups,
and the record write.

**Tasks**:
- [x] Script skeleton: header comment block (purpose, the six-positional-argument observer
      contract `$1 task_number $2 task_type $3 topic $4 task_dir $5 session_id $6 resting_status`,
      usage, exit codes, "advisory and non-blocking"), `set -euo pipefail` (Class A per
      `context/standards/shell-strict-mode.md`; document any `-e`-hostile construct inline per
      that document's admission tests if one is found), argument parsing tolerant of being called
      with the six positionals OR with `--backfill`. *(completed)*
- [x] Add the `json_string`/`json_array` no-`jq` emission helpers following `books-gate.sh`'s
      existing idiom (D4). *(completed)*
- [x] Join half (generic): read `$4/issues.jsonl` and `$4/metrics.jsonl`. Group issue entries by
      `tags.dimension` and `tags.polarity`; carry `kind`, `class`, `severity`; emit an
      `untagged_count` for entries carrying no usable tag. Aggregate the metrics records'
      dispatch count, phases, outcomes and wall-clock. Omit any group whose source file is absent. *(completed)*
- [x] Books fact 1 (`book_requires` churn): count over `.lean` files in the task's own commit
      range via `git diff`/`grep`, no probe, no build. *(completed)*
- [x] Books fact 2 (escalations and validation-marker promotions): `git diff` of
      `docs/book-convention.md` (and its documented siblings) over the task's commit range, scoped
      to `- **Validated by**:` lines, with heading lookback to attribute each change to its
      Decision's durable heading name. Record each promotion AGAINST that decision name. *(completed)*
- [x] Probe-dependent groups, strictly present-or-`absent`: verification-tier runs and outcomes
      with counts and time per tier (lake build, layer lint, certify, full gate, recheck),
      certifier outcome classes, refusals, warnings, and vacuous passes — read from the RUN log
      when it exists, filtered to this task; omit/`absent` otherwise, never a zeroed tally. *(completed)*
- [x] Snapshot before/after delta: test the conventional probe path (D3) for executability,
      invoke it if present, record `"snapshot_delta": "absent"` otherwise. Never synthesize a
      snapshot. *(completed)*
- [x] Paired burdens: always emit both `burdens_created[]` and `burdens_lifted[]` (default `[]`),
      sourced from tagged issue entries. *(completed)*
- [x] Validate polarity and dimension values against the frozen enums; an unrecognized value is
      reported in a dedicated field, never silently coerced or dropped. *(completed)*
- [x] Write the canonical record to the per-task path and append the derived digest line to the
      accumulating log (D1), creating the log's directory if needed. *(completed)*
- [x] Fail-soft throughout: any read failure, shape mismatch, or missing source omits its group
      and the script still exits 0. Nothing it does can block or fail a dispatch. *(completed)*
- [x] `chmod +x` the script. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the record has the field groups enumerated in Phase 1 and exactly two
books-specific facts are computable without any probe (`book_requires` churn, Validated-by
promotions). Confirm at implementation time by re-checking the consuming repository for a
`specs/books-evidence/` directory and for an executable probe at the conventional path; if either
now exists, the corresponding group moves from `absent` to populated and the phase's own tests
must cover both paths.

**Files to modify**:
- `agent-system/extensions/books/scripts/books-observe.sh` - new: the observer, live mode

**Verification**:
- `bash -n` parses; `shellcheck` clean per `context/standards/shell-strict-mode.md`.
- Invoked with the six positionals against a throwaway fixture task directory, writes a
  syntactically valid JSON record (validate by parsing it) and exits 0.
- Invoked against a fixture with NO `issues.jsonl`, NO `metrics.jsonl`, NO RUN log and NO probe,
  still exits 0 and still produces a record whose probe-dependent fields read `absent` and whose
  missing groups are omitted rather than zeroed.
- `burdens_created` and `burdens_lifted` both present in every emitted record.

---

### Phase 4: `--backfill` mode [COMPLETED]

**Goal**: Add `--backfill` for already-completed books tasks, deriving what is still derivable and
marking every derived figure, consistent with the per-dispatch metrics script's own backfill
posture.

**Tasks**:
- [x] Add the `--backfill` entry point (single task and whole-corpus forms), resolving task
      directories from the consuming repository's own `specs/` tree. *(completed)*
- [x] Derive what remains derivable from git history for a completed task; omit entirely what is
      not recoverable, never reconstruct a figure a live timer or host fingerprint would have
      supplied. *(completed)*
- [x] Mark every record `--backfill` writes with `backfilled: true` plus a populated
      `figure_provenance` map (`measured`/`derived` per present figure), mirroring
      `dispatch-metrics.sh --backfill`'s exact marking contract rather than inventing one. *(completed)*
- [x] Mark each books-specific field GROUP with its own `source: collected|backfilled`, never
      conflating `backfilled` with `collected` (D2). *(completed)*
- [x] Carry forward, in the script header and in the standard, the documented commit-subject-grep
      over-match limitation inherited from the metrics precedent. *(completed)*
- [x] Never overwrite a `collected` record with a `backfilled` one without saying so. *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/books/scripts/books-observe.sh` - add `--backfill` mode and its marking

**Verification**:
- `shellcheck` clean.
- `--backfill` against a fixture completed-task directory produces a record carrying
  `backfilled: true`, a non-empty `figure_provenance`, and a per-group `source` marker.
- A `--backfill` run over a fixture with no recoverable history produces a record with omitted
  groups rather than zeros, and still exits 0.

---

### Phase 5: Test suite [COMPLETED]

**Goal**: Write `scripts/tests/test-books-observe.sh` covering the six named acceptance behaviors,
fixture-driven and hermetic — no dependency on a real `specs/` tree or the external consuming
repository.

**Tasks**:
- [x] Class B strict mode (`set -uo pipefail`) with `PASSED`/`FAILED` counters and
      `pass()`/`fail()`/`info()` helpers, mirroring `scripts/tests/test-books-certify.sh` and
      `scripts/tests/test-books-gate.sh`'s existing shape; isolated `mktemp -d` git repo per case. *(completed)*
- [x] Test: THE JOIN — a fixture with both `issues.jsonl` and `metrics.jsonl` produces a record
      carrying both halves, grouped by dimension and polarity. *(completed)*
- [x] Test: THE ABSENT-PROBE PATH — no RUN log and no executable probe yields `absent` for the
      probe-dependent groups and the snapshot delta, with exit 0. This is the measured-today
      default and must be asserted as correct output. *(completed)*
- [x] Test: THE PAIRED-BURDEN REQUIREMENT — both `burdens_created[]` and `burdens_lifted[]` are
      always present (including as `[]`); a record with one and not the other is a test failure. *(completed)*
- [x] Test: POLARITY/DIMENSION VALIDATION — a valid tag is read through; an unrecognized
      dimension or polarity is reported in its dedicated field and never silently coerced; an
      untagged entry is counted untagged and never defaulted. *(completed)*
- [x] Test: BACKFILL MARKING — a `--backfill` record carries `backfilled: true`,
      `figure_provenance`, and per-group `source`; a live record does not carry `backfilled: true`. *(completed)*
- [x] Test: NON-BLOCKING FAILURE — a malformed/truncated `issues.jsonl`, an unreadable task
      directory, and a crashing probe each leave the script exiting 0 with the affected group
      omitted. *(completed)*
- [x] Test: VACUOUS PASS is a first-class field populated from a supplied source, never inferred
      by negation of a pass. *(completed)*
- [x] `chmod +x` the test script; run it green. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: seven test cases as enumerated (join, absent-probe, paired-burden,
polarity/dimension validation, backfill marking, non-blocking failure, vacuous pass). Confirm by
counting the implemented cases against this list before closing the phase; the dispatch's
acceptance list is the floor, not the ceiling.

**Files to modify**:
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` - new: the fixture suite

**Verification**:
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` exits 0 with all cases
  PASSED and zero FAILED.
- `shellcheck` clean on the test script.
- The suite runs with no reference to `~/Projects/Logos/Verification` and no network.

---

### Phase 6: Registration, documentation and final gate [NOT STARTED]

**Goal**: Declare the observer, deploy both scripts, register the two context files, document the
observer where Rule X actually looks, and run the full gate set.

**Tasks**:
- [ ] `manifest.json`: add the top-level `observers` block —
      `observers.books-observe` with `script: "scripts/books-observe.sh"`, `topic: "books"`,
      `task_type: "books"`, and a `timeout_seconds`. Both keys are declared deliberately: topic is
      the key that actually matches (the measured corpus carries topic `books` with task_type
      `lean4`/`general`/`typst`, never `books`), task_type is declared for the future
      books-native case. Add no other key — Rule X rejects strays.
- [ ] `manifest.json`: add `"books-observe.sh"` and `"tests/test-books-observe.sh"` to
      `provides.scripts`, mirroring the existing `books-certify.sh`/`test-books-certify.sh` pair.
      A script absent from `provides.scripts` never deploys and Rule X hard-fails on it.
- [ ] `manifest.json`: leave `provides.hooks: []` and add NO top-level `hooks` object — this task
      adds an observer, not a lifecycle hook.
- [ ] `index-entries.json`: register `project/books/patterns/signal-tagging.md` with the EAGER
      `load_when` (the four books agents + `task_types: ["books"]`), matching the corpus
      `README.md`'s convention, because tagging instructions must reach working agents rather than
      sit behind an on-demand lookup. Register
      `project/books/standards/observation-record.md` with `on_demand: true` and empty `load_when`,
      matching the other corpus documents. Populate `line_count`, `domain`, `subdomain`, `topics`,
      `summary`, `keywords` for both, in the shape the existing entries use.
- [ ] `README.md`: update the Directory Map `scripts/` line (currently names only
      `books-certify.sh`) to include `books-observe.sh`, and add a short Observer subsection naming
      the observer key and its script basename. Rule X's `check_observers_documented` checks
      `README.md` specifically — `EXTENSION.md` alone does not satisfy it.
- [ ] `EXTENSION.md`: document the observer (what it writes, where, and that it is advisory and
      non-blocking) and add the two new context files to the Context Pointers section.
- [ ] Record the REQUIRED DEPLOYMENT CAVEAT as a completion obligation for the implementation
      summary: none of this takes effect in the consuming repository until the user (i) LOADS the
      books extension there — it is currently not loaded — and (ii) REDEPLOYS core. Both are the
      user's actions, not this task's, and not something this task can verify. Omitting it leaves
      a feature that appears shipped and is inert.
- [ ] Run the full gate set and fix anything it reports.

**Timing**: 1 hour

**Depends on**: 2, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: seven source-store files are touched in total across all phases
(`books-observe.sh`, `tests/test-books-observe.sh`, `manifest.json`, `observation-record.md`,
`signal-tagging.md`, `index-entries.json`, `EXTENSION.md`) plus `README.md` as the eighth, added
because Rule X checks it specifically — the dispatch's own deliverable list names seven and omits
`README.md`. Confirm at implementation time with `git status --short` scoped to
`agent-system/extensions/books/`; if `README.md` turns out already to name the observer, drop
that edit rather than padding the change set.

**Files to modify**:
- `agent-system/extensions/books/manifest.json` - add `observers` block; add both scripts to `provides.scripts`
- `agent-system/extensions/books/index-entries.json` - register the two new context files with their tiering
- `agent-system/extensions/books/README.md` - Directory Map line + Observer subsection (Rule X requirement)
- `agent-system/extensions/books/EXTENSION.md` - document the observer; add the two context pointers

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set for this repository — passes.
- `bash .claude/scripts/check-extension-docs.sh` passes, with Rule X
  (`check_observers_resolve` + `check_observers_documented`) green for `books-observe`.
- `manifest.json` and `index-entries.json` both parse as valid JSON.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence in any file this task
  wrote.
- No file was written under `.claude/**`.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` — all cases pass.
- [ ] `shellcheck` clean on `books-observe.sh` and `test-books-observe.sh` per
      `context/standards/shell-strict-mode.md` (Class A for the observer, Class B for the test).
- [ ] `bash .claude/scripts/check-extension-docs.sh` — Rule X green for the new observer.
- [ ] `bash .claude/scripts/verify-deploy.sh` — full gate set passes.
- [ ] `manifest.json` and `index-entries.json` parse as valid JSON.
- [ ] Observer invoked with the six positional arguments against a fixture exits 0 and writes a
      parseable record; invoked against an empty fixture still exits 0 with `absent`/omitted
      fields rather than zeros.
- [ ] `--backfill` produces records marked `backfilled: true` with `figure_provenance` and
      per-group `source`.
- [ ] Every one of the seven dimension keys and both polarity values appear in the standard and in
      the tagging guide, spelled identically in both.
- [ ] No task-number reference in any source-store file written by this task.
- [ ] No write anywhere under `.claude/**`.
- [ ] The implementation summary states the deployment caveat plainly (extension not loaded in the
      consuming repository + core redeploy required, both user actions).

## Artifacts & Outputs

- `agent-system/extensions/books/scripts/books-observe.sh` — the observer, plus `--backfill`.
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` — the fixture suite.
- `agent-system/extensions/books/manifest.json` — the `observers` declaration and two
  `provides.scripts` entries.
- `agent-system/extensions/books/context/project/books/standards/observation-record.md` — the
  observation-record standard.
- `agent-system/extensions/books/context/project/books/patterns/signal-tagging.md` — the
  signal-tagging guide for working agents.
- `agent-system/extensions/books/index-entries.json` — both context files registered.
- `agent-system/extensions/books/EXTENSION.md` — the observer documented; context pointers added.
- `agent-system/extensions/books/README.md` — the observer named where Rule X checks.
- `specs/332_books_observer_convention_observation_record/summaries/01_*-summary.md` — the
  implementation summary, carrying the required deployment caveat.

## Rollback/Contingency

Every change is additive and confined to `agent-system/extensions/books/**`; nothing existing is
restructured. Per-substep commits mean any phase can be reverted individually with a targeted
revert of its own commits, leaving earlier phases intact.

The observer seam itself is the safety net for a partial landing: an observer that is missing,
non-executable, crashing or hanging produces a `deviation` event in `specs/events.jsonl` and
nothing else — it can never change task status, fail a dispatch, or block orchestration. So a
half-landed `books-observe.sh` degrades to no-observation, not to a broken lifecycle. The fastest
full disable is removing the `observers` block from `manifest.json` and redeploying.

If a rollback must discard uncommitted work rather than revert commits, take a durable checkpoint
first and follow `context/contracts/recovery.md`'s rollback rung for the exact invocation shape,
including its out-of-scope override flag — not a bare precautionary snapshot call.
