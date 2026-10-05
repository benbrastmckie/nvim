# Record-Maintenance Diagnostics

Where the diagnostics that certify a **record edit** live, the order to run them, and what each
certifies. This file names no convention substance — that lives in the record itself
(`docs/book-convention/`) and in this corpus's own domain documents; see
`rules/book-convention-record.md` for the editing obligations these diagnostics back.

## The four diagnostics, in run order

Cheapest and most structural first, so a structural break is found before a currency heuristic
is read.

1. **`books/scripts/lint-validated-by.sh`** — twelve checks. **Blocking**: CHECK 1 (marker
   presence/well-formedness), CHECK 2 (instance liveness), and — once `docs/book-convention/`
   exists — CHECK 5 (cross-link integrity), CHECK 6 (anchor liveness), CHECK 7 (index/content
   agreement), CHECK 8 (orphaned-decision detection), CHECK 9 (decision status), CHECK 10
   (clause-list resolution), CHECK 11 (record currency). **Advisory** (printed, never changes the
   exit code): CHECK 3 (marker promotion owed), CHECK 4 (unescalated departure), CHECK 12
   (currency signals). The split follows the script's own stated reason: the blocking checks are
   fully mechanical exact-text checks against a confirmed-green baseline, so a false positive
   would be a bug in the script; the advisory ones are heuristics over free text and dates, so
   "the lint detects, the repository owner rules."
2. **`books/scripts/check-citation-inventory.sh`** — the zero-citation-loss **multiset** guard: a
   backtick-delimited span moving from one file to another (e.g. during a decision's migration
   into its own file) is a pass; a span disappearing from the set entirely is a FAIL.
3. **`books/scripts/check-evidence-append-only.sh`** — the append-only guard over
   `docs/book-convention-evidence/NN-*.md` (`README.md` excluded, being the directory's
   migration-contract document). Every finding is blocking; append-only is a property of **each
   commit**, not of the end state, so a rewritten entry is caught exactly like a dropped one. No
   reachable `.git` yields one INFO line and exit 0, reported rather than treated as green.
4. **`books/scripts/check-convention-version.sh`** — the three-surface version comparison.
   **Blocking**: CHECK1 (record line), CHECK2 (generated manual binding), CHECK3
   (record-vs-manual mismatch), CHECK5 (amendment ↔ `CHANGELOG.md` bullet). **Advisory**: CHECK4,
   the extension-pin leg — the extension deploys from another repository on its own schedule, so
   its lag is a deploy event there, not a defect here; an absent corpus is one INFO line.

A green run of all four certifies marker and structural integrity, citation survival, evidence
append-only history and version lockstep — and certifies **nothing** about whether a ruling was
correct.

## The snapshot probe and the observer

The extension ships **no** snapshot probe ("PROBE OWNERSHIP BOUNDARY (D3)",
`scripts/books-observe.sh`): the observer tests for an executable `books/tool/book-snapshot.sh`
**in the consuming repository** and invokes it (`--diff <before> <after> --json`) when present.
The observer itself is `books-observe.sh` — topic/`task_type`-keyed, advisory, non-blocking. **The
repository owns probes; the extension owns the join** — the observer joins
`issues.jsonl`/`metrics.jsonl` with books-specific facts and invokes a probe that lives in the
consuming repository, never shipping one itself.

## `/books` sub-mode boundaries

`/books --review` is **strictly read-only**: it never proposes, never writes, never creates a
task, never edits the convention, and never advances a watermark
(`patterns/books-review-submode.md`). `/books --revise` **never edits the record**: it proposes
tasks, and the tasks do the work (`patterns/books-revise-submode.md`).

## Where the records live

- **SNAPSHOT**: `specs/books-evidence/snapshot-{ISO_DATE}.json` — one file per snapshot, an
  append-only directory.
- **RUN**: `specs/books-evidence/runs.jsonl` — one shared append-only log.
- **OBSERVATION**: `specs/{NNN}_{SLUG}/book.observation.json` — one per task, beside
  `.decisions.json` — plus the append-only digest log `specs/books-evidence/observations.jsonl`
  (one line per write).
