# No Record-Versioning Language in Deliverables

<!-- Deliberately eager (no `paths:` frontmatter): this rule gates writes across the entire
repo -- any deliverable file, in any location, could be about to receive version-labeled or
draft-history prose. A glob narrow enough to matter would have to be "**/*", which buys nothing
over no frontmatter at all (see `source-store-deploy-boundary.md` and `pr-prohibition.md` for the
same reasoning applied to their own universal-scope rules). This is a deliberate decision, not an
omission. -->

## Path Pattern

Applies to: the entire repository EXCEPT `specs/**/*` (task-management artifacts), git commit
messages, and PR/branch metadata.

## Principle

Deliverable files — docs/**, README.md, code, and other work product — MUST state the current
design only and MUST NOT narrate their own draft history. Specifically forbidden: page-level
version labels in titles or status lines ("The X convention (v2)"; "**Status**: v2, accepted
<date>; supersedes v1"); "this is the second version" / "supersedes v1" framing; a supersession
or disposition table mapping an earlier draft's decisions onto the current ones; "(v1 Decision N)"
attributions on rejected alternatives; and phrasing relative to an unstated past ("no longer",
"previously", "formerly", "used to", "carried forward from v1", "withdrawn", "every v1 field
removed").

Rejected alternatives are KEPT — they are the point of a decision record — but stated on their
own merits, never attributed to an earlier draft of the same document. Task numbers are
renumbered during vault operations and prior drafts leave no trace a future reader can verify;
cite durable anchors instead: a filename, a section heading, a decision-record name, or a
verified fact.

## Exceptions (version language IS permitted here)

- `specs/**` artifacts (task descriptions, plans, reports, summaries, `TODO.md`, `state.json`,
  `ROADMAP.md`) — the PRIMARY exemption.
- Git commit messages and PR/branch metadata.
- Three durable, non-record version axes: software/toolchain pins (`Lean v4.31.0`), file-format
  and schema versions (`book.toml` `schema = 2`, `book-cert-v2.md`), and CI cache-key epoch
  segments (`pnpm-v1-`, `lake-recheck-v3-`).
- A dated, cross-document amendment note recording that a decision a record OWNS was amended
  (`**Amended by** <doc>, <date>:`) — a real change to an accepted decision, not a draft lineage.

## Full Taxonomy and Enforcement

The full exemption taxonomy (including the per-category BLOCKING/ADVISORY tier and the
`version-ok` marker convention for a user-permitted exception beyond the four zones above) lives
in `.claude/context/standards/record-version-exemptions.md` — load it before adding, exempting,
or reviewing any version-language occurrence. The mechanical source of truth for detection
patterns, durable-axis discrimination, and exemption logic is
`scripts/lib/record-version-patterns.sh`, the single library both planned enforcement consumers
— a repo-wide lint and a write-time hook, neither built yet — will source rather than redefine.
