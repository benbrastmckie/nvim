# Record-Versioning Exemption Taxonomy

Companion to `rules/no-record-versioning-in-deliverables.md` (the always-eager principle). This
file carries the full exemption taxonomy, the per-category BLOCKING/ADVISORY tiering, and the
enforcement narrative, loaded on demand. The mechanical source of truth for detection patterns,
durable-axis discrimination, and exemption logic is `scripts/lib/record-version-patterns.sh` —
this document describes (never redefines) that behavior.

## Why This Rule Exists

The companion rule and this taxonomy are the durable guard against a defect pattern already
observed and already corrected once in the Verification repository: `books/convention.md`
(formerly `docs/book-convention.md`) shipped carrying 68 `v1`/`v2` mentions across 1,705 lines, a
<!-- version-ok:begin quotes the forbidden vocabulary itself, describing a historical incident
     this rule already corrected -- category: self-referential description of the motivating
     anti-pattern instance, not a live instance of it -->
22-line "How this record relates to v1" supersession table with 15 disposition rows, eight
`(v1 Decision N)`-attributed rejected alternatives, and an "Every v1 field removed" migration
table — while both "versions" were dated the same day and nothing in the repository had ever
<!-- version-ok:end -->
been built against v1 (no `book.toml` existed anywhere at the time). The file documented its own
authoring process rather than its design, and the label leaked outward into
`records/architecture-decisions.md` (formerly `docs/architecture-decisions.md`), `docs/README.md`,
and the repository's own task-tracking artifacts. It was also off house style: every other
decision record in `records/architecture-decisions.md` carries a bare "**Status**: accepted,
<date>" with no page version. The de-versioning sweep that corrected this is already committed
(`docs: state the book convention without version history`); this rule and its mechanical library
are the guard against recurrence.

## State the Current Design Instead

When a deliverable needs to explain a decision or a convention, state what the design IS, not
how it came to be that way across drafts. Rejected alternatives are KEPT — they are the point of
a decision record — but stated on their own merits, never attributed to an earlier numbered draft
of the same document.

**Before** (observed anti-pattern, illustrative only):
<!-- version-ok:begin quoted historical anti-pattern, category: page-level version labels -->
```markdown
## The book convention (v2)

**Status**: v2, accepted 2026-09-30; supersedes v1

### How this record relates to v1

| v1 Decision | v1 Ruling | v2 Disposition |
|---|---|---|
| Decision 3 | Certificates carry a schema array | Superseded — every v1 field removed |

The module-registration mechanism (v1 Decision 7) was rejected because it coupled registration to
build order.
```
<!-- version-ok:end -->

**After**:
```markdown
## The book convention

**Status**: accepted, 2026-09-30

The module-registration mechanism is rejected because it couples registration to build order.
```

The second form states the design on its own merits. Nothing is lost: the rejected alternative is
still recorded, just not laundered through an implied prior draft that the reader never saw and
that, in the motivating case, was never built against — both "versions" were dated the same day.

## Exemption Taxonomy

Version language is permitted, marker-free, in exactly four zones. Everything else is governed by
the Forbidden Categories and Tiers table below.

| Category | Verdict | Marker required? | Example |
|----------|---------|-------------------|---------|
| 1. `specs/**` artifacts | Path-level exemption, no marker | No | Task descriptions, plans, reports, summaries, `completion_summary` fields, `TODO.md`, `state.json`, `ROADMAP.md` — this is the PRIMARY exemption |
| 2. Git commit messages; PR/branch metadata | Not a deliverable file at all | No | `task {N}: revise plan (v{V})` |
| 3a. Software/toolchain versions (durable axis) | Not record-versioning language | No | `Lean v4.31.0`, `actions/checkout@v4`, `Tailwind CSS v4` (narrow, literal named-tool anchor, never a generic capitalized-phrase-before-`vN` heuristic — see the Design Principle section for why) |
| 3b. File-format and schema versions (durable axis) | Not record-versioning language | No | `book.toml` `schema = 2`, `books/schema/book-toml-v2.md`, `` `book-cert-v2.md` ``, `Global Index Schema (v2)` (a `schema`/`format` noun within 40 characters of a bare `vN` token) |
| 3c. CI cache-key epoch segments (durable axis) | Not record-versioning language | No | `pnpm-v1-`, `lake-recheck-v3-` in a cache-key table |
| 4. Dated cross-document amendment note | Records a real change to an accepted decision, not a draft lineage | No | `**Amended by** [books/convention.md](...), 2026-09-30: this decision fixes identity to the certificate.` |

Zones 3a–3c are the three **durable, non-record** version axes: they describe a real external or
mechanical version (a pinned toolchain release, a schema's own format version, a cache key's
invalidation epoch), never a document's own draft history. `scripts/lib/record-version-patterns.sh`'s
`strip_durable_axis_lines` recognizes these shapes mechanically, with no marker — see the Design
Principle section below for why shape-based discrimination, not a string whitelist, is required.

Two further bare-major-version shapes are mechanical for the same reason, matched against the
same two axes: a schema/format-anchored form (axis 3b — a `schema`/`format` noun within 40
characters of a bare `vN` token, either order, e.g. `Global Index Schema (v2)`) and a
named-external-tool form (axis 3a — deliberately a narrow, literal anchor on a specific tool name,
e.g. `Tailwind`/`Tailwind CSS` followed by `vN`, NOT a generic "capitalized phrase before `vN`"
heuristic). The generic heuristic was tried and rejected: it also matches genuine page-title
violations sharing the same surface shape ("Draft System v2", "Himalaya Plugin Architecture V2"),
which must stay BLOCKING. Both new shapes are matched case-sensitively (lowercase `v` only) for
the same reason — an uppercase `V<N>` page-title label must never be swept into this exemption.

Beyond these four zones, an exception requires **explicit user permission**, expressed through the
Marker Convention below.

## Forbidden Categories and Tiers

| Category | Tier | Description | Example |
|----------|------|--------------|---------|
| Page-level version label | BLOCKING | A heading or `**Status**:` line carrying a version label for the page itself | `## The X convention (v2)`; `**Status**: v2, accepted <date>; supersedes v1` |
| Version-qualified supersession | BLOCKING | `supersede(s/d)`/`supersession` with an adjacent `v[0-9]` token. The bare word is NOT matched — it is live, legitimate usage throughout ordinary decision-record prose (one rule superseding another, one record amending another) | `supersedes v1`; `v2 of this document supersedes the earlier draft` |
| `(v1 Decision N)` attribution | BLOCKING | A rejected alternative attributed to a numbered decision in an earlier draft | `(v1 Decision 4)` |
| Version-qualified migration claim | BLOCKING | A claim about what changed between page versions | `carried forward from v1`; `every v1 field removed` |
| Bare past-tense vocabulary | ADVISORY (escalates to BLOCKING if the same line also carries a non-durable-axis `v[0-9]` token) | `no longer`, `previously`, `formerly`, `used to`, `withdrawn` — the most false-positive-prone category; 50+ matches were found in accepted, non-versioning decision-record prose during calibration | `This option is no longer supported.` (ADVISORY alone); `This clause no longer applies now that v2 ships.` (BLOCKING, escalated) |
| Disposition-table heuristic | ADVISORY, undercalibrated | A heading matching `relates? to v[0-9]`, or a table header row carrying both a decision-number column and a `v[0-9]`-shaped column label. Zero real positive instances exist in the calibration corpus — shipped as a low-confidence heuristic pending a real positive, not forced into a brittle BLOCKING regex | A heading reading "How this record relates to v1"; a table header `| v1 Decision | v1 Ruling | v2 Disposition |` |

Both the BLOCKING and ADVISORY tiers are exported as single grouping variables
(`RV_BLOCKING_ERE`, `RV_ADVISORY_ERE`) from `scripts/lib/record-version-patterns.sh`. Neither the
planned repo-wide lint nor the planned write-time hook chooses its own tier for any category —
both inherit the tiering from the library.

## Marker Convention

A line containing the substring `version-ok:begin` opens an exempt region that runs through (and
includes) the next line containing `version-ok:end`; comment syntax is irrelevant (markdown
`<!-- -->`, shell `#`, Lua `--`) since the token is matched as a plain substring, not parsed as a
comment. A single line containing the substring `version-ok` (that is not itself a begin/end
marker line) is itself exempt (inline form).

Both forms **require a trailing reason naming one of the categories above** — carried on the
begin marker (block form) or the inline marker line (inline form); the end marker itself may be
bare. The reason is not validated mechanically; it is a human-review concern at this table, not a
parseable contract. This marker is the ONLY sanctioned way to permit version language beyond the
four Exemption Taxonomy zones, and only with explicit user permission — see the Before example
above for a worked instance of the block form.

## Enforcement

**Forward-looking: neither enforcement consumer exists yet.** This task ships the rule, this
taxonomy, and the shared library (`scripts/lib/record-version-patterns.sh`, calibrated to zero
BLOCKING findings and 53 ADVISORY findings against the Verification repository's `docs/`,
`README.md`, `books/`, and `records/` trees). The two planned consumers are separate, later tasks:

- A **repo-wide lint gate**, planned as `scripts/check-record-versioning.sh`, modeled on
  `scripts/check-task-references.sh`: enumerate every git-tracked file via `git ls-files`, skip
  `is_exempt_path` matches, pipe survivors through `strip_durable_axis_lines` then
  `strip_exempt_regions`, and exit non-zero on any BLOCKING finding outside the exempt zones.
- A **write-time guard hook**, planned as `hooks/validate-no-record-versioning.sh`, modeled on
  `hooks/validate-no-task-references.sh`: a blocking PreToolUse gate on `Write|Edit` that applies
  the same pipeline to new/edited content and denies the write on a BLOCKING finding, failing
  OPEN if the shared library cannot be sourced.

Both consumers will source `scripts/lib/record-version-patterns.sh` directly rather than
redefining any pattern, axis-discrimination rule, or tier — exactly as `check-task-references.sh`
and `validate-no-task-references.sh` share `task-reference-patterns.sh` today. A reader of this
document today should not be misled into believing either consumer is wired: running the
discriminator is, for now, a manual, one-off operation.

## Design Principle: Discriminate the Record-Version Axis by Structural Shape, Not a String Whitelist

The forbidden vocabulary overlaps heavily with legitimate uses of `v[0-9]`-shaped tokens: a
toolchain pin, a CI cache-key epoch, and a schema filename all look, at the token level,
identical to a page-level draft-history label. A naive regex matching bare `\bv[0-9]\b` is
therefore extremely noisy — eight files under `docs/` plus `README.md` in the Verification
repository match it, and every single one of those matches is legitimate durable-axis usage, not
a violation.

The three durable axes observed live in that repository, by concrete shape:

1. **Dotted semver / toolchain pins** — `v[0-9]+\.[0-9]+`, e.g. `Lean v4.31.0`, `v0.1.0`.
2. **Action/toolchain pins** — `@v[0-9]+`, e.g. `actions/checkout@v4`.
3. **CI cache-key epoch segments** — a hyphen-embedded `[a-z]+-v[0-9]+-` run, e.g. `pnpm-v1-`,
   `lake-recheck-v3-`, `elan-v2-`.
4. **Schema/file-format artifact identifiers** — a `v[0-9]+` token adjacent to `.md`, or embedded
   in (or immediately following) a backtick-quoted filename or identifier, e.g.
   `` `book-cert-v2.md` ``, `` `book-evidence-observation-v1` ``, `` `book.toml` v2 ``. Live
   calibration found that a schema document's own title — self-declaring its format version —
   is syntactically indistinguishable from a forbidden page-level label by token shape alone; only
   the backtick-quoted-identifier shape (the document naming itself) disambiguates it.

`strip_durable_axis_lines` recognizes each shape mechanically and drops the whole line before any
BLOCKING or ADVISORY pattern ever sees it — no `version-ok` marker is needed, because the line
was never a record-versioning violation to begin with. When a newly-encountered durable-axis
shape surfaces (a new cache-key naming convention, a new schema-identifier style), add it to
`strip_durable_axis_lines` directly. This is a mechanical extension of an already-settled
discrimination rule, not a reopening of this taxonomy's substantive ruling on what counts as
record-versioning language.
