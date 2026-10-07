# Research Report: Task #332

**Task**: 332 - Books observer: the per-task convention observation record
**Started**: 2026-10-04T00:21:00Z
**Completed**: 2026-10-04T01:10:00Z
**Effort**: 4-8 hours (per task metadata)
**Dependencies**: 298 (books context corpus), 329 (issue log), 330 (dispatch metrics), 331 (observer seam) — all four are `completed`
**Sources/Inputs**:
- Codebase: `agent-system/extensions/books/**`, `agent-system/extensions/core/**` (manifest-routing-lib.sh, run-task-observers.sh, dispatch-metrics.sh, issue-record.sh, check-extension-docs.sh, creating-extensions.md, shell-strict-mode.md)
- Consuming repository `~/Projects/Logos/Verification`: `docs/book-evidence.md`, `books/schema/book-evidence-{snapshot,run,observation}-v1.md`, `docs/book-convention.md`, `specs/state.json`, ten completed books-topic task directories, `books/scripts/lint-validated-by.sh`, `books/scripts/certify.sh`
- `specs/state.json` (this repository) for task 298/329/330/331/332 status
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The consuming repository has already designed the exact record this task builds the writer for.** `docs/book-evidence.md` and its three `books/schema/book-evidence-{snapshot,run,observation}-v1.md` companions in `~/Projects/Logos/Verification` name the agent system's books extension as the **sole writer** of an OBSERVATION record, define the seven-dimension/polarity vocabulary verbatim, and even state the exact repo-side vs. agent-side field split this task's dispatch describes. This is not a coincidence the implementer needs to reconcile from scratch — it is a pre-existing contract to read and satisfy, and the vocabulary should be copied verbatim (`maintainability`, `cross_pollination`, `guardrails_qa`, `token_cost_efficiency`, `readability`, `intuitive_exposure`, `compiling_composing`; polarity `positive`/`negative`).
- **Neither of the two repo-side probes this task is allowed to depend on exists yet.** Per `book-evidence-snapshot-v1.md` and `book-evidence-run-v1.md` themselves: "no script exists yet that writes this shape," for both the SNAPSHOT probe (`books/tool/`, path not yet pinned) and the RUN log (`specs/books-evidence/runs.jsonl`, writer not yet built). `books-observe.sh` must therefore implement the "invoke if present, else absent" contract literally — today, on the one real corpus this task will be measured against, it will resolve to absent/omitted for every tier-run and snapshot-delta field, and that is the CORRECT, non-defective output, not a sign the join is broken.
- **All three generic prerequisites are implemented and live in the source store** (`issue-record.sh`, `dispatch-metrics.sh`, `run-task-observers.sh` + `routing_resolve_observers()`), but **none has ever been exercised in the consuming repository**: none of the ten completed books-topic task directories there has an `issues.jsonl`, a `metrics.jsonl`, or an observer wired up (books extension not loaded there; core not yet redeployed with these three capabilities). `--backfill` is therefore not optional polish — for the measured corpus, every one of the ten completed tasks needs it to produce anything beyond stub records.
- **The dispatch's "task 298 has not yet run" premise is stale.** Task 298 completed in this repository on 2026-10-03 and already landed the 17-file books context corpus (16 documents + README) with an established index-entries.json tiering convention (README.md eagerly loaded for the four books agents + `task_types: ["books"]`; every other document `on_demand: true` with empty `load_when`). This task's two new files should be registered into that existing convention, not into an assumed-empty tree. Recorded to `issues.jsonl` (severity `minor`) rather than silently worked around.
- **The manifest `observers` schema, matching contract, and invocation contract are fully specified** in `docs/guides/creating-extensions.md`'s "Post-Task Observers" section (which already uses `books` as its own worked example) and mechanically enforced by `check-extension-docs.sh`'s Rule X — both are reproduced in full below so the plan phase does not need to re-derive them.
- **Recommended approach**: build `books-observe.sh` as a repo-agnostic, fail-soft reader that (1) always reads the generic `issues.jsonl`/`metrics.jsonl` records for its `$4` task-dir argument, (2) computes `book_requires` churn and Validated-by marker promotions itself via pure `git diff`/`grep` over the task's own commit range (both are mechanically derivable today, independent of any unbuilt repo-side probe), (3) reads `specs/books-evidence/runs.jsonl` and `specs/books-evidence/snapshot-*.json` **when they exist**, filtered/bracketed to the task, and (4) invokes a conventional snapshot-probe script path **when present on disk**, omitting (never zeroing) every field it cannot derive.

## Context & Scope

This is a **meta** task in the agent-system source store (`agent-system/extensions/books/...`,
never `.claude/**`). It registers the books extension's own post-task observer on the
topic/task_type-keyed observer seam (task 331) and writes the observer script that produces one
OBSERVATION record per books-family task, joining the generic per-task records (issue log, task
330) with books-specific facts, for a consuming repository such as `~/Projects/Logos/Verification`.
Scope is bounded by `file_scope` to seven files: `books-observe.sh`, its test, `manifest.json`,
two new context documents, and `index-entries.json`/`EXTENSION.md`.

The research below establishes (1) the exact, already-enforced manifest/registration contract,
(2) the exact shape of the two generic logs the observer joins, (3) the consuming repository's own
pre-existing, detailed design for the record this task writes (a major, load-bearing discovery —
this is not a blank-slate schema design), and (4) the measured gap between that design and what
actually exists on disk today, which determines how defensively `books-observe.sh` must degrade.

## Findings

### Codebase Patterns

**Observer manifest schema** (`docs/guides/creating-extensions.md`, confirmed against
`scripts/lib/manifest-routing-lib.sh`'s `routing_resolve_observers()` and
`check-extension-docs.sh`'s `check_observers_resolve`/`check_observers_documented`, i.e. Rule X):

```json
{
  "observers": {
    "books-observe": {
      "script": "scripts/books-observe.sh",
      "topic": "books",
      "task_type": "books",
      "timeout_seconds": 30
    }
  }
}
```

- `script` is required; resolves by **basename** against the deployed `.claude/scripts/`
  directory and **must** also appear in `provides.scripts` (as `"books-observe.sh"`) or it never
  deploys (Rule X, `check_observers_resolve`). The test file must likewise be added as
  `"tests/test-books-observe.sh"` to `provides.scripts` (mirroring `books-certify.sh`/
  `test-books-certify.sh`'s existing pair in this same manifest).
- At least one of `topic`/`task_type` is required; the dispatch asks for **both** (`"books"`),
  which resolves `matched_on: "both"` only when both match — the task's own routing table already
  declares `task_type: "books"` at the manifest top level, so this is consistent.
- `timeout_seconds` optional, default 30. No other key is permitted (any stray key fails Rule X).
- **Matching is prefix-aware** on both `topic` and `task_type`: a declared `books` matches
  `books:certify` too (segment before the first `:`). This extension already has a
  `books:certify` compound route, so the observer will also fire for certify-flavored dispatches —
  intentional and consistent with "match topic OR task_type."
- **Resolution is resolve-ALL** (every matching declaration across every loaded extension fires;
  never first-match-wins), in manifest-glob order then sorted observer key.
- **Documentation requirement (Rule X, `check_observers_documented`)**: the observer key or its
  script's basename **must** appear in the extension's own `README.md` (not just `EXTENSION.md`).
  The current `README.md`'s "Directory Map" lists `scripts/` as "books-certify.sh (the one
  declared passthrough script) + tests" — this line needs updating to mention `books-observe.sh`,
  and a short line/row should name it explicitly (e.g. in a new "Observer" subsection), or Rule X
  fails the check mechanically at `/meta`/`/review` time.

**Observer execution contract** (same guide section, `run-task-observers.sh`):

```
$1 task_number   $2 task_type   $3 topic   $4 task_dir   $5 session_id   $6 resting_status
```

Invoked via `timeout <timeout_seconds> <resolved_script> "$@"` from
`orchestrate-cycle-postflight.sh`, **after** that dispatch's own `issue-record.sh` and
`dispatch-metrics.sh` calls have already written their records for `$4` — this ordering is a
documented, binding guarantee the observer may rely on. The observer's own exit code is recorded
as one `task_observer_run` event (`success`/`deviation`) and otherwise **completely ignored**: it
can never change task status, never fail a dispatch, never block. A missing, non-executable,
crashing, or hanging `books-observe.sh` produces nothing worse than a `deviation` event.
`run-task-observers.sh` itself picks the timeout binary and redirects the observer's stdout/stderr
to a scratch file it discards — **the observer's own stdout is not read by anything**, so
`books-observe.sh` writing its OBSERVATION record is the only effect that matters; printing a
summary to stdout is purely a debugging convenience, not part of the contract.

**Generic per-task records the observer joins** (`context/formats/issue-log.md`,
`context/formats/dispatch-metrics.md`):

- `specs/{NNN}_{SLUG}/issues.jsonl` — one JSON object per line, `kind: issue|win`, open `class`
  enum (15 seed classes), closed `severity` (`blocking|costly|minor|none`), and an **open `tags`
  object** that is explicitly the extension seam this task is told to use: "This is the seam an
  extension's own dimension-tagging scheme uses to attach extension-specific structured metadata
  ... without requiring any change to `issue-record.sh`, this document, or the core schema."
  `books-observe.sh` reads this file and groups entries by `tags.dimension`/`tags.polarity` once
  the signal-tagging pattern (a deliverable of this task) is adopted by working agents; it never
  invents a tag for an entry that lacks one.
- `specs/{NNN}_{SLUG}/metrics.jsonl` — one line per dispatch, `phase`/`agent`/`outcome`/
  `dispatch_seq`/`session_id` required; `tokens`, `tool_calls`, `model`, `commits`, `churn`,
  `gate_runs`, `transcript` all **omitted, never zeroed**, when the figure could not be
  determined. `--backfill N` is the documented precedent for deriving what is still derivable from
  `git log` phase-commits when a task predates live capture, marking every recovered field
  `backfilled: true` plus a `figure_provenance` map of `measured`/`derived` per present figure.
  **`books-observe.sh --backfill` should mirror this exact marking contract** rather than invent
  its own.
- Neither file is pre-created; both are lazily created on first write, never gitignored, and both
  are append-only via `flock`-guarded `jq -c -n`. The observer only ever reads them.

**Shell strict-mode class** (`context/standards/shell-strict-mode.md`): `books-observe.sh` is an
ordinary, non-counter, non-sourced script — Class A default (`set -euo pipefail`) unless an
`-e`-hostile construct is found during implementation, in which case document the exception
inline per that doc's admission tests. `scripts/tests/test-books-observe.sh` is Class B
(`set -uo pipefail` + `PASSED`/`FAILED` counters + `pass()`/`fail()`/`info()` helpers), mirroring
`scripts/tests/test-books-certify.sh`'s and `scripts/tests/test-books-gate.sh`'s existing shape
exactly (fixture-driven, isolated `mktemp -d` git repo per case, no dependency on a real
`specs/` tree or the external consuming repository). `books-gate.sh` additionally demonstrates
this extension's established JSON-emission idiom with **no `jq` dependency** (`json_string`/
`json_array` helper functions using `sed`/`awk`) for a script that must run standalone in any
consuming repository — `books-observe.sh` should follow the same no-extra-dependency discipline
for its own JSON construction, or depend on `jq` only as an optional enhancement with a documented
fallback (the generic logs it reads are already `jq`-friendly, but the repo it runs in is not
guaranteed to have `jq`, matching the care `books-gate.sh` already takes).

**Index/registration pattern for the two new context files** (`index-entries.json`, task 298's
already-landed convention): `context/project/books/README.md` carries
`load_when: {agents: [books-research-agent, books-implementation-agent,
books-research-hard-agent, books-implementation-hard-agent], task_types: [books]}` (eagerly
loaded for every books dispatch); all 16 other documents carry `on_demand: true` with empty
`load_when`. Given the dispatch's own instruction that "the agents are instructed how to tag by a
books context file injected for books-topic dispatches" — i.e. tagging must actually reach working
agents, not sit behind an on-demand lookup they may never trigger — **`patterns/signal-tagging.md`
should get the same eager `load_when` as `README.md`** (the four agents + `task_types: [books]`),
while `standards/observation-record.md` (the full schema/standard, aimed at the observer's own
author/reviewer rather than every dispatch) is a reasonable `on_demand: true` entry matching the
other 16.

### External Resources — the Consuming Repository's Own Pre-Existing Design

This is the most significant finding and should drive the plan directly. `docs/book-evidence.md`
in `~/Projects/Logos/Verification` (task 182 there, completed 2026-10-03) is a **catalogue and
authority ruling**, not yet a built harness, that:

1. Defines the **exact same seven dimensions**, in the same order, as this dispatch's (a)-(g)
   list — verbatim key spellings: `maintainability`, `cross_pollination`, `guardrails_qa`,
   `token_cost_efficiency`, `readability`, `intuitive_exposure`, `compiling_composing`. Polarity
   is `positive`/`negative`. **Recommendation: adopt these exact key strings in
   `observation-record.md`/`signal-tagging.md`**, citing `docs/book-evidence.md` by filename (never
   by task number, per `no-task-references-in-deliverables.md`) as the vocabulary's origin, so a
   future cross-repository rollup never has to reconcile two differently-spelled enumerations.
2. Names **three evidence record kinds** — SNAPSHOT, RUN, OBSERVATION — each with its own
   `books/schema/book-evidence-*-v1.md` schema document. **OBSERVATION is this task's own
   deliverable**, and `book-evidence-observation-v1.md` states so explicitly: *"The record's sole
   writer is the agent system's books extension — software outside this repository... This
   repository supplies one named probe (the repo-side half), whose `--json` output the extension
   reads and folds into the record it writes."* It gives an exact **repo-side vs. agent-side field
   split**:
   - Repo-side (the probe this repository supplies, build-free, derived from `git log`,
     `.decisions.json`, directory listings): `phase_wall_clock[]`, `commit_churn.{inside_specs,
     outside_specs}`, `plan_version_count`, `decision_count`, `hand_harvested_signals[]` (each
     `{signal, dimension, polarity, source}`, read from `.decisions.json`).
   - Agent-side (this extension's own job, from `events.jsonl`/`state.json`, **not** to be
     re-implemented by the repository): `dispatch_count`, `lifecycle_transitions[]`,
     `agent_process_cost`.
   - Every field group carries its own `source: collected|backfilled` marker — **per field group,
     not one record-wide marker** — with `backfilled` never conflated with `collected` because a
     reconstruction cannot carry a real host fingerprint or a live-timer wall-clock. This is the
     OBSERVATION-specific refinement of the same backfill-marking discipline
     `dispatch-metrics.md`'s `figure_provenance` already establishes generically; `books-observe.sh`
     should carry **both**: the generic `figure_provenance` shape for the joined
     issues/metrics data, and this per-field-group `source` marker for the books-specific groups,
     since the two conventions serve the same purpose at different granularities and neither
     subsumes the other cleanly.
   - **Location**: `specs/{NNN}_{SLUG}/book.observation.json`, one file per task, beside
     `.decisions.json`, committed once at the task's natural completion boundary. This is a
     **different location** from where this dispatch's "appended to a log" language might suggest
     — the repo's own design is **one file per task**, not one shared append-only log (that shape
     is reserved for RUN, at `specs/books-evidence/runs.jsonl`). The plan should resolve this
     explicitly: either follow the repo's already-ruled-on per-task-file location (recommended,
     since it is an existing, owner-ruled contract) or deviate and justify why; it should not
     silently pick one without naming the tension.
3. States the **repository-owner ruling** that an accumulating evidence log of this kind is
   explicitly **not** the "parallel tension register" `docs/book-convention.md` Decision 17
   forbids — this ruling is already landed (`specs/182_.../.decisions.json`), so the extension
   does not need to re-litigate authority to write this record; it only needs to conform to the
   shape the ruling approved.
4. States the **"build-free" constraint** for both repo-side probes (SNAPSHOT and the
   OBSERVATION repo-side half): neither may trigger a build to produce a value; an unbuildable
   figure is reported as the literal string `"absent"`, never inferred as zero. `books-observe.sh`
   must preserve this discipline on its own side of the join as well.

**Neither upstream probe exists yet — confirmed by direct measurement, not assumed:**

- `books/schema/book-evidence-snapshot-v1.md`, verbatim: *"It is normative prose, not code — no
  script exists yet that writes this shape."* The probe's own path is not even pinned
  ("expected under `books/tool/`", exact name left to "the effort that builds it").
- `books/schema/book-evidence-run-v1.md`, verbatim: same "no script exists yet" statement for
  `specs/books-evidence/runs.jsonl`'s sole writer.
- Direct filesystem check: `find ~/Projects/Logos/Verification -iname "*snapshot*"` finds only the
  schema document itself and unrelated `git-snapshot.sh`/`lean-challenge-snapshot.sh` infrastructure
  — no `specs/books-evidence/` directory exists at all yet.

**Consequence for `books-observe.sh`'s design**: the dispatch's "Verification-tier runs and
outcomes... Certifier outcome classes; refusals; warnings. Vacuous passes..." field group has
**no backing data source in the one real consuming repository today**, independent of anything
this task builds. The only two books-specific facts that ARE mechanically computable *today*,
with no dependency on an unbuilt probe, are:

- **`book_requires` churn**: a pure `git diff`/`grep -c 'book_requires'` count over `.lean` files
  in the task's own commit range — no probe needed, derivable from git history alone, exactly like
  `dispatch-metrics.sh`'s own `churn` field.
- **Escalations and validation-marker promotions, by Decision's durable name**: `docs/book-convention.md`
  (verified: headings are literally `## Decision 1: Book identity and membership` ...
  `## Decision 13: Exposure policy` ... through at least Decision 17/18, each with a
  `- **Validated by**: ` line per `books/scripts/lint-validated-by.sh`'s own documented contract) —
  a `git diff` of that file (and its two documented siblings, `docs/architecture-decisions.md`,
  `docs/fault-frame-design.md`) over the task's commit range, scoped to lines matching
  `- **Validated by**:`, directly yields which Decision's marker changed and what it changed to
  (`none yet` → `partially, ...` → a binding instance). This is the mechanically correct source
  for "recorded against the convention decision they bear on, by that decision's durable name" —
  the durable name is literally the heading text, available via `grep -B50 '^- \*\*Validated by' |
  grep '^## Decision'`-style lookback, not an invented identifier.

For the remaining books-specific facts (tier runs/outcomes, certifier classes, refusals, warnings,
vacuous passes, and the SNAPSHOT before/after delta), `books-observe.sh` should implement exactly
the dispatch's own stated contract — **invoke if present, record `absent` otherwise** — against:

- `specs/books-evidence/runs.jsonl`, filtered by `caller_context.task` matching the task number
  (when the file exists at all; omit the whole sub-object otherwise, never a zeroed tally).
- A snapshot probe at a **documented conventional path** this extension's own standard should pin
  (since the repository's own schema explicitly leaves the exact path an open contract — "the
  effort that builds it owns the exact script path"). Recommend `books/tool/book-snapshot.sh`
  as the default-looked-for basename with `--json`/`--diff A B` flags, matching the schema
  document's own `--diff A B` mode description verbatim; `books-observe.sh` tests for executability
  at that path before invoking, and records `"snapshot_delta": "absent"` when it is missing —
  never attempting to synthesize a snapshot itself (the extension must not ship a probe, per the
  dispatch's explicit prohibition).

### `.decisions.json` as the `hand_harvested_signals[]` source

Confirmed structurally present (though not universally — e.g. task 172 in the consuming repo has
none) on several completed books tasks there (`182`, `171`, `169`), each entry shaped
`{question, answer}` free-text pairs with no existing dimension/polarity classification. This
matches `book-evidence-observation-v1.md`'s own framing of `hand_harvested_signals[]` as "new, but
its source material (`.decisions.json` entries) already exists... this field is the first thing
to classify those entries against a fixed dimension/polarity vocabulary rather than leaving them
as free prose" — i.e. the repo's own design anticipates that classifying `.decisions.json` entries
is itself new work, consistent with this task's `tags`-seam-on-issues.jsonl approach (a parallel,
not identical, classification path: `.decisions.json` entries are classified as a repo-side
probe concern per the contract document, while `issues.jsonl` `tags` is the agent-side/extension
classification path this task actually builds). The plan should state which of the two paths
`books-observe.sh` itself reads from for `hand_harvested_signals[]`-equivalent data — most likely
neither directly (that field is explicitly repo-side, supplied by a probe this extension does not
ship), leaving the extension's own `tags`-on-`issues.jsonl` seam as the sole dimension/polarity
source it owns end-to-end.

## Recommendations

1. **Adopt the consuming repository's existing seven-dimension/polarity vocabulary verbatim** in
   both new context documents (`maintainability`, `cross_pollination`, `guardrails_qa`,
   `token_cost_efficiency`, `readability`, `intuitive_exposure`, `compiling_composing`;
   `positive`/`negative`), citing `docs/book-evidence.md` by filename as the origin, not
   reinventing a parallel spelling.
2. **Register the observer exactly per the already-specified schema** (`observers.books-observe`
   with `script`, `topic: "books"`, `task_type: "books"`, `timeout_seconds`), add both
   `books-observe.sh` and `tests/test-books-observe.sh` to `provides.scripts`, and mention the
   observer explicitly in `README.md` (not only `EXTENSION.md`) to satisfy Rule X.
3. **Resolve, as an explicit plan decision, the location mismatch**: this dispatch says "appended
   to a log"; the consuming repository's own owner-ruled contract says one file per task,
   `specs/{NNN}_{SLUG}/book.observation.json`. Recommend following the existing ruled contract
   (one file per task) rather than introducing a second, competing shared-log convention, since
   the repository owner has already settled this question for the OBSERVATION kind specifically
   (RUN is the one that is a shared append-only log).
4. **Implement the mechanically-certain fields first and unconditionally** (`book_requires` churn,
   Validated-by marker promotions by Decision name) via pure `git diff`/`grep` over the task's
   commit range — these need no upstream probe and work today.
5. **Implement the probe-dependent fields (tier runs/outcomes, vacuous passes, snapshot delta)
   strictly as present-or-absent**, reading `specs/books-evidence/runs.jsonl` and a conventional
   snapshot-probe path when they exist, and omitting the field group entirely (never a zero or a
   fabricated count) when they do not — which, measured today, is every real task in the only
   corpus available.
6. **`--backfill` should target the ten completed books-topic tasks** in
   `~/Projects/Logos/Verification` (`120`, `121`, `169`, `171`, `172`, `174`, `177`, `179`, `182`,
   `186`) as the first real corpus, mirroring `dispatch-metrics.sh --backfill N`'s exact marking
   discipline (`backfilled: true` + `figure_provenance`) for the generic-record half, and
   `book-evidence-observation-v1.md`'s per-field-group `source: collected|backfilled` marker for
   the books-specific half.
7. **Paired-burden schema requirement**: always emit both `burdens_created[]` and
   `burdens_lifted[]` keys (default `[]`), never one present without the other, each entry at
   minimum `{description, dimension, convention_decision}` — enforce this as an acceptance test
   in `test-books-observe.sh`, not merely a convention.
8. **The required completion-summary deployment caveat** (this feature is inert in the consuming
   repository until the user loads the books extension there and redeploys core) must appear
   plainly in the implementation summary — confirmed directly: the books extension is not among
   the extensions loaded in `~/Projects/Logos/Verification`'s own `.claude-extensions.json`
   equivalent state today (its ten completed books tasks all have `task_type` `lean4`/`general`/
   `typst`, never `books`, matching the dispatch's own measurement).

## Decisions

- Treat `docs/book-evidence.md` and its three schema documents in the consuming repository as
  **binding design input**, not merely background reading — the vocabulary, the field split, the
  location/commit policy, and the authority ruling are all already settled there and should be
  conformed to rather than re-derived independently.
- Record the stale "task 298 has not yet run" dispatch premise to `issues.jsonl` rather than
  silently correcting it without a trace (done during this research phase).
- Recommend resolving the "one file per task" vs. "appended to a log" tension explicitly in the
  plan, in favor of the owner-ruled per-task-file location, rather than leaving both descriptions
  to be reconciled ad hoc during implementation.

## Risks & Mitigations

- **Risk**: building `books-observe.sh` against an imagined RUN-log/SNAPSHOT-probe shape that
  later drifts from what the consuming repository actually builds. **Mitigation**: read both
  strictly through the schema documents' own field names and the documented `--json`/`--diff`
  read-path contracts, and fail soft (omit, never guess) on any shape mismatch, exactly as
  `dispatch-metrics.sh`'s transcript join already does for its own six-case fail-soft ladder.
- **Risk**: the two new context documents drifting from the repository's vocabulary if a future
  `docs/book-evidence.md` revision changes a dimension key spelling. **Mitigation**: cite the
  source document by name in both new files so a future reviewer can diff the two vocabularies
  directly, rather than copying the table with no provenance note.
- **Risk**: `--backfill`'s commit-subject-grep approach (the documented `dispatch-metrics.sh`
  Trap (d)) over-matching on a reused task number in the consuming repository's own history.
  **Mitigation**: inherit the same documented limitation and caveat rather than attempting a
  stronger-than-precedent fix within this task's scope.

## Context Extension Recommendations

- **Topic**: the repo-side OBSERVATION probe contract (`book-evidence-observation-v1.md`'s
  "repo-side fields" table) names a probe this repository has not yet built.
  **Gap**: no context file in this source store currently points an implementer at that contract
  document when working on `books-observe.sh`'s read side.
  **Recommendation**: the new `context/project/books/standards/observation-record.md` should
  explicitly name and summarize `book-evidence-observation-v1.md`'s field split (without copying
  the consuming-repo-specific prose verbatim, since this corpus must stay usable by any consuming
  repository, not only `~/Projects/Logos/Verification`), framed as "if your consuming repository
  supplies a probe shaped like this contract, these are the fields to expect."

## Appendix

- Search queries / commands used: `jq` queries over `specs/state.json` (this repo and the
  consuming repo) for task 298/329/330/331/332 and books-topic task status; `grep`/`find` over
  `agent-system/extensions/{books,core}/**` for the observer schema, manifest-routing-lib.sh's
  `routing_resolve_observers()`, `check-extension-docs.sh` Rule X, `issue-record.sh`/
  `dispatch-metrics.sh` headers, `shell-strict-mode.md`; `grep`/`find`/direct reads over
  `~/Projects/Logos/Verification`'s `docs/book-evidence.md`, `books/schema/book-evidence-*-v1.md`,
  `docs/book-convention.md` Decision headings, `books/scripts/lint-validated-by.sh`,
  `books/scripts/certify.sh`, and ten completed books-topic task directories for artifact
  presence (`issues.jsonl`, `metrics.jsonl`, `.decisions.json`).
- Key files read in full: `docs/guides/creating-extensions.md` (Post-Task Observers section),
  `context/formats/issue-log.md`, `context/formats/dispatch-metrics.md`,
  `books/schema/book-evidence-snapshot-v1.md`, `books/schema/book-evidence-run-v1.md`,
  `books/schema/book-evidence-observation-v1.md`, `docs/book-evidence.md`.
