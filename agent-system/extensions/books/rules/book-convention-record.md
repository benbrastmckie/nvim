---
paths: ["**/docs/book-convention.md", "**/docs/book-convention/**", "**/docs/book-convention-evidence/**"]
---

# Book Convention Record Editing Rules

Non-negotiables for **editing the convention record itself**, not for authoring a book. Each
item states its measured failure mode, not just the rule.

## 1. A named-instance marker is binding

A decision whose `Validated by` marker **names an instance** is binding (a bare `<instance>` or
the exercised clauses of `partially, <instance> — <clauses>`). Work that cannot satisfy it
**stops**, researches the conflict, **escalates to the repository owner** for a ruling, and lands
that ruling as an amendment to the clause's text plus an updated marker.
(`docs/book-convention/17-documentation-reconciliation-and-book-health.md`, "The escalation
protocol".)

## 2. Neither silent departure nor silent compliance

Departing without a ruling leaves the record describing a convention the tree no longer follows;
complying silently with a clause the work has shown wrong leaves a known defect in force. Both
are refused — escalation is the only outcome. (Same section.)

## 3. `none yet` is a hypothesis, not a constraint

A `none yet` clause needs no escalation. It is amended **in place** by the first work that
exercises it, which then **promotes its marker**. (Same section.)

## 4. The split-record edit contract

"An updated marker" means editing the decision file's **one-line reduced marker** — keeping its
value vocabulary (`<instance>` / `partially, <instance> — <clauses>` / `none yet`) and its
evidence pointer — **and** appending a dated
`## <ISO date> — <Newly exercised | Extended | Amended | Re-measured> by <instance>` entry to the
paired file under `docs/book-convention-evidence/`. (`docs/book-convention-evidence/README.md`,
"Ruling 5's file-split mechanics paragraph", marker and evidence-file templates in the same
README. Append-only is mechanically enforced by `books/scripts/check-evidence-append-only.sh`,
every finding blocking.)

## 5. No new artifact, no register

The ruling lands in the task's existing `.decisions.json`; proposals are **transient**; **the
marker is the status**. (Decision 17's "No new artifact" paragraph; the no-register rule in
`docs/book-evidence.md`'s "The review protocol" — "the harness computes and proposes; it never
decides" — with triage vocabulary **revise now / defer / reject**.)

## 6. Citations are durable anchors

Cite a file path, a `file:line`, a decision number or a script name — never a task number in the
record (`rules/no-task-references-in-deliverables.md`). Every backtick citation must survive an
edit: `books/scripts/check-citation-inventory.sh`'s zero-citation-loss **multiset** guarantee
passes a span that moves between files and fails one that disappears from the set entirely.

## 7. The convention version line bumps

Classify the change against Decision 19's bump table, declare it in the same change's
`CHANGELOG.md` `## [Unreleased]` bullet, and the extension's pin (`manifest.json`'s
`convention_version` / `measured_at_commit`, and the corpus `README.md`'s "Convention version pin
and staleness comparison") is then stale and says so — the pin leg is **advisory, never
blocking** (`books/scripts/check-convention-version.sh` CHECK4), because the extension deploys on
its own schedule. (`docs/book-convention/19-convention-versioning-and-lockstep.md`, clauses 2, 3, 5.)

## Scope Boundary

This rule governs *editing* the record — the escalation protocol, the split-file edit contract
and the version bump. It does not restate the convention's own substance (see
`context/project/books/patterns/record-maintenance.md`) and does not cover book-directory or
book-module content, which is `rules/books.md`'s territory.
