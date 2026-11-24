# Research Report: Task #690

**Task**: 690 - Delete the orphaned milestone-ref-land.sh utility and its references
**Started**: 2026-11-23T18:22:00Z
**Completed**: 2026-11-23T19:05:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/**, specs/TODO.md, specs/state.json)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's measured premise holds on a light re-check: `milestone-ref-land.sh` has no
  lifecycle caller anywhere in this source store (scripts/, hooks/, any extension), and the
  script's own header already self-documents this ("STANDING: no lifecycle script calls this
  script, and it is not a landing mechanism").
- The full reference set is exactly: the script, its test suite, one `suite-classification.data`
  row (a mechanical gap not named in the dispatch's deletion list), one comment-only credit in
  `test-milestone-review-handoff.sh`, two `manifest.json` rows, and two context documents.
- `review-stack-prepare.sh` already implements the identical `git commit-tree` +
  compare-and-swap `git update-ref` idiom to build and restack the review ref — this is the exact
  use-site `context/patterns/ref-plumbing-landing.md`'s own "Landing Mechanism" section already
  names. Re-pointing that document's "worked implementation" citation to `review-stack-prepare.sh`
  keeps the pattern anchored to a live, runnable script rather than leaving it undocumented.
- The "record that owns handoff printing of the review stack" is task 692 ("Handoff prints
  review stack"), already `[COMPLETED]`; its sibling tasks 691 and 693 are also `[COMPLETED]`.
  No active task currently touches `test-milestone-review-handoff.sh`, so the dispatch's "declare
  the shared territory and order behind it" instruction is satisfied by recording that there is
  presently no live race, not by adding a dependency edge.
- Recommended approach: proceed with the deletion list as given, adding one unlisted item
  (removing the stale `suite-classification.data` row) and re-pointing — not merely stripping —
  the two context documents' implementation citation to `review-stack-prepare.sh`.

## Context & Scope

This research covers only the deletion scoped to this repository's source store
(`agent-system/extensions/core/**`), per the dispatch's siting instruction. The consumer
repository's live ref writer (the unexplained `refs/heads/milestone/P1` advances) is explicitly
out of scope — that investigation and remedy belong in that repository, which is the only one
whose tree contains the edit target for unwiring whatever is running the script there (or
re-deriving the idiom by hand from the context document). This report does not re-run the
exhaustive dual-repository grep the dispatch already reports as measured; it performs a narrower,
targeted re-check sufficient to ground a deletion plan with exact line numbers and exact
decisions on the two ambiguous items the dispatch leaves open (the context-document re-pointing
choice, and the test-suite shared-territory question).

## Findings

### Codebase Patterns

**Full reference inventory** (source store, `agent-system/extensions/core/`):

1. `scripts/milestone-ref-land.sh` (244 lines) — the script itself. Sources only
   `lib/common.sh` and `deploy-root-guard.sh`, both shared by many other scripts; deleting it
   orphans no exclusive library dependency.
2. `scripts/tests/test-milestone-ref-land.sh` (368 lines) — its dedicated suite.
3. `scripts/tests/suite-classification.data:155` — `test-milestone-ref-land.sh	unit	-`. **Not
   named in the dispatch's deletion list (steps 1-5)**, but a mechanical consequence of deleting
   item 2: the file's own header states "Adding a suite is a DATA EDIT here, never a
   documentation edit... this file cannot silently drift out of sync with the corpus." Checked
   `lint-unit-integration-boundary.sh`'s handling of a row naming a suite no longer discovered:
   it logs `log_info "stale classification row (no longer discovered): ..."` and reports it as a
   `[INFO]` count that "do[es] not affect" the exit code (0/1 per actual violations). So leaving
   the row would not break verification, but it is dead data the file's own stated discipline
   argues against leaving behind.
4. `scripts/tests/test-milestone-review-handoff.sh:8` — a **comment-only** credit: "Follows the
   deployed-shape sandbox convention established by test-milestone-ref-land.sh
   (deploy-root-guard.sh's default structural check requires the script's own directory to end
   in /.claude or /.opencode)." Confirmed by reading the full file: nothing sources, invokes, or
   functionally depends on `test-milestone-ref-land.sh`; it is a credit line only.
5. `manifest.json:289` — `"milestone-ref-land.sh",` in the scripts array.
6. `manifest.json:440` — `"tests/test-milestone-ref-land.sh",` in the tests array. Confirmed
   these are the only two occurrences in the file.
7. `context/patterns/ref-plumbing-landing.md:8-9` (Audience line: "...and
   `agent-system/extensions/core/scripts/milestone-ref-land.sh`, the worked implementation.")
   and `:32` (Landing Mechanism section: "`scripts/milestone-ref-land.sh` implements the idiom
   as a snapshot utility; no lifecycle script calls it.").
8. `context/standards/git-workflow-narrative.md:272` — "`scripts/milestone-ref-land.sh` is
   retired as a landing mechanism, confirmed by its own header, and stays on disk as a hand-run
   snapshot utility whose ref is a parallel history." This sentence's final clause ("stays on
   disk") becomes false the moment the file is deleted and cannot be left as-is.

No reference exists in any hook (checked every extension's `hooks/` directory, not just core's),
in any other extension's scripts, or in `index.json`/`index-entries.json` beyond the ordinary
`line_count` fields for items 7 and 8 (98 and 324 respectively today), which step 5 of the
dispatch's own list (`generate-context-line-counts.sh --check`) already covers once the prose
length changes.

**The superseding-implementation finding.** `review-stack-prepare.sh` already implements the
exact idiom `ref-plumbing-landing.md` defines — confirmed by grep: `git commit-tree` at lines
1020, 1048, and 1292, and three-argument compare-and-swap `git update-ref` at lines 1049 and
1403, building and restacking the review ref. This is not a coincidental similarity: it is
*literally* the use-site `ref-plumbing-landing.md`'s own "Landing Mechanism" section already
names as the idiom's current application ("The case the ruling record names is the review ref:
... built at review time from the landing proofs..."). That section already correctly describes
*what* builds the review ref; it simply still cites the wrong script as *how*. `milestone-ref-land.sh`
is a dead, never-called utility that happens to implement the same primitives in isolation;
`review-stack-prepare.sh` is the live, lifecycle-wired script that does the same job for the one
case the document says matters.

**Territory check on `test-milestone-review-handoff.sh`.** The dispatch names "the record that
owns handoff printing of the review stack" and asks the plan to declare shared territory and
order behind it rather than race it. That record is task 692, "Handoff prints review stack"
(`specs/TODO.md`, entry "### 692. Handoff prints review stack"), whose Phase 5 scope was: call
`review-stack-prepare.sh cut --milestone <id>` then `show` from inside
`scripts/milestone-review-handoff.sh`, writing/printing the result in place of the two lines
printed before. Task 692's status in `specs/TODO.md` is `[COMPLETED]`, as are its siblings 691
("Restack review stack when parent merges") and 693 ("Merge command stack mode") — confirmed via
both `specs/TODO.md` status lines and absence from `specs/state.json`'s `active_projects`
(neither 691, 692, nor 693 appears there, consistent with completed/archived status). None of
the three touches the header-comment line this record needs to edit (692's deliverable was the
handoff script's post-listing behavior, not the test file's sandbox-convention comment).
**Conclusion: there is no live task currently editing `test-milestone-review-handoff.sh`; the
"declare order" instruction is satisfied by recording this finding in the plan, not by adding a
dependency edge to an already-completed task.**

### External Resources

Not applicable — this is a pure internal deletion/cleanup scoped to the source store; no external
documentation or best-practice research applies.

## Recommendations

1. **Delete** `scripts/milestone-ref-land.sh` and `scripts/tests/test-milestone-ref-land.sh` as
   the dispatch's step 1 directs.
2. **Remove the manifest rows** at `manifest.json:289` and `manifest.json:440` (step 2).
3. **Also remove** the stale `suite-classification.data:155` row
   (`test-milestone-ref-land.sh	unit	-`) in the same commit as steps 1-2. Not strictly required
   for `lint-unit-integration-boundary.sh` to pass (a stale row is INFO-only), but it is the same
   kind of dead reference the rest of the deletion list targets, and the file's own header treats
   drift as the thing to avoid.
4. **Re-point, not merely strip**, the two context documents' implementation citations:
   - `ref-plumbing-landing.md:8-9` (Audience line) and `:32` (Landing Mechanism section): change
     the named "worked implementation" from `milestone-ref-land.sh` to
     `review-stack-prepare.sh`, since the latter already is the use-site the Landing Mechanism
     section describes. Retain every other section verbatim — the Idiom, Concurrency-Safety
     Property, Compare-And-Swap Obligation, and Prohibition sections are script-agnostic
     ("any script that needs to build or advance a ref...") and name no implementation at all
     outside the two sentences above.
   - `git-workflow-narrative.md:272`: drop the now-false "stays on disk as a hand-run snapshot
     utility" clause. Recommend replacing the sentence with one stating the script was removed
     because no lifecycle caller used it, and that `review-stack-prepare.sh` is where the idiom's
     compare-and-swap property is exercised today — reusing language already present in that
     file's neighboring prose rather than inventing new draft-history phrasing (avoid "no longer",
     "previously", "used to" per `no-record-versioning-in-deliverables.md`; state the current
     design plainly instead, e.g. "The idiom's compare-and-swap property is exercised today by
     `scripts/review-stack-prepare.sh`, which builds and restacks the review ref using the same
     primitives.").
5. **Reword** `test-milestone-review-handoff.sh:8`'s comment to describe the sandbox convention
   itself rather than credit a file that will no longer exist, e.g.: "Follows the deployed-shape
   sandbox convention required by deploy-root-guard.sh's default structural check (the script's
   own directory must end in /.claude or /.opencode)." No behavior change; this is a comment-only
   edit, independently safe regardless of the (already-completed) 692/691/693 work.
6. **Reconcile** `index-entries.json` line counts via `generate-context-line-counts.sh --check`
   (dispatch step 5) after the two context-document edits land.
7. **Redeploy** via `deploy-headless.sh` using the bounded-wait idiom (`timeout 540`, Bash tool
   timeout 600000) per the dispatch's source-store boilerplate, and confirm a clean verify.
8. Do **not** add any task or dependency edge for the consumer repository's live ref writer; that
   remains explicitly out of scope per the siting rule, and this deletion cannot regress that
   repository's behavior either way (its deployed tree already lacks the script, per the
   dispatch's measured sweep).

## Decisions

- Treat this as a straightforward deletion of an orphaned utility, its test, its manifest rows,
  and one unlisted stale data row, rather than any form of repair.
- The ref-plumbing idiom's TECHNIQUE content in `ref-plumbing-landing.md` is retained in full;
  only the specific "worked implementation" citation moves, from `milestone-ref-land.sh` to
  `review-stack-prepare.sh`.
- The "declare the shared territory and order behind it" instruction for
  `test-milestone-review-handoff.sh` is discharged by recording, in the plan, that the owning
  record (692) and its siblings (691, 693) are already complete and never touched the comment
  line in question — no dependency edge is added.
- `suite-classification.data`'s stale row is added as an explicit sub-step rather than left for a
  future, unscoped cleanup, since it is the same class of dead reference the rest of this record
  targets.

## Risks & Mitigations

- **Risk**: Deleting the script could appear to strip the ref-plumbing pattern document of its
  only concrete, runnable example. **Mitigation**: `review-stack-prepare.sh` is a live,
  lifecycle-wired script using the identical primitives (confirmed by grep at the line numbers
  above); re-pointing the citation preserves a runnable reference instead of leaving the pattern
  unanchored.
- **Risk**: Manifest-sync tests (e.g. a `test-manifest-scripts-sync.sh`-class check) could fail
  if the file deletions and the manifest-row removals land in different commits. **Mitigation**:
  sequence them together, as the dispatch's own step ordering already implies.
- **Risk**: A redeploy that runs before the context-document edits settle could leave a stale
  deployed copy. **Mitigation**: the dispatch's own ordering (edit source store, then redeploy)
  already covers this; just don't invert it.
- **Risk (explicitly out of scope, noted for completeness)**: the consumer repository's live ref
  writer remains unidentified. This deletion cannot make that worse — the consumer repository's
  deployed tree already lacks the script per the dispatch's measured sweep — but it also cannot
  fix it; that remains a separate, differently-sited task.

## Context Extension Recommendations

- **Topic**: pattern-document implementation citations going stale across a migration.
- **Gap**: `ref-plumbing-landing.md`'s "worked implementation" naming pattern (an Audience-line
  pointer to one script) has no mechanical staleness check — the implementation migrated from
  `milestone-ref-land.sh` to `review-stack-prepare.sh` silently, discovered only by this research
  pass's grep, not by any existing lint.
- **Recommendation**: none proposed as a new context file; the existing deletion-list and
  line-count-reconciliation mechanisms already in this system are sufficient for this one
  instance, and a general staleness-detection mechanism for cross-references is a larger,
  separately-scoped concern not warranted by a single occurrence.

## Appendix

- Search queries used: `grep -rn "milestone-ref-land" agent-system/`, `grep -n "commit-tree\|update-ref" scripts/review-stack-prepare.sh`, `grep -n "^### 69[123]\." specs/TODO.md`, `jq -r '.active_projects[]...' specs/state.json`.
- References: `agent-system/extensions/core/scripts/milestone-ref-land.sh`,
  `agent-system/extensions/core/scripts/review-stack-prepare.sh`,
  `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md`,
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md`,
  `agent-system/extensions/core/scripts/tests/suite-classification.data`,
  `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh`,
  `specs/TODO.md` (tasks 691, 692, 693).
