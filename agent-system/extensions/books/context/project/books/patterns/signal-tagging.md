# Signal Tagging for Working Agents

**This is for you if you are a books-research, books-implementation, or either `--hard` agent,
mid-dispatch.** `books-observe.sh` (this extension's post-task observer) reads your
`issues.jsonl` entries and joins them into the task's observation record — but only the entries
you tag. An untagged entry is counted as `untagged` and contributes nothing to the record's
dimension signals. **The observer never guesses a tag for you.** If a signal matters to the
convention's own health, tagging it is the only way it survives past this dispatch.

## The mechanism

`tags` is an **open object** on an `issues.jsonl` entry (`context/formats/issue-log.md`'s own
extension seam — core neither validates nor depends on its interior). You populate it at the same
`issue-record.sh` call that records the entry, via `--tags-json`:

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind issue --class "gate collision" --severity costly \
  --what-happened "..." \
  --tags-json '{"dimension": ["guardrails_qa"], "polarity": "negative"}' \
  >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2
```

**No change to `issue-record.sh`, to `context/formats/issue-log.md`, or to the core schema is
needed or permitted.** The seam already exists; this document only tells you how to fill it.

## The exact shape `books-observe.sh` reads

```json
{"dimension": ["readability", "compiling_composing"], "polarity": "positive"}
```

- `dimension`: one or more of the **seven keys** below, as a JSON array (even when tagging only
  one — the observer reads an array, not a bare string).
- `polarity`: exactly `"positive"` or `"negative"`. No third value, no default.

This obligation applies identically to **`kind: "issue"` and `kind: "win"` entries**. A `win` is
positive signal with no cost to fix — it still needs a dimension and a polarity (almost always
`"positive"`) so it is counted, not merely narrated.

## The seven dimensions, verbatim

Pinned by `standards/observation-record.md`, itself conforming to `docs/book-evidence.md`'s own
vocabulary — **spell these exactly as written, never abbreviated**:

`maintainability` | `cross_pollination` | `guardrails_qa` | `token_cost_efficiency` |
`readability` | `intuitive_exposure` | `compiling_composing`

## Worked examples — one per dimension

### (a) `maintainability`

A `book_policy` row was placed on a composite book whose members did not contain the subject it
named. The certifier reported `holds` with `checked_modules: []` — a silent pass that would have
misled whoever next touched that book's policy set.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind issue --class "vacuous or silent pass" --severity costly \
  --what-happened "book_policy row named a subject not in the certifying book's membership; certified holds with checked_modules: [] -- moved the row to the owning book and it caught two real violations." \
  --tags-json '{"dimension": ["maintainability"], "polarity": "negative"}' \
  --resolution fixed_inline
```

### (b) `cross_pollination`

A second customer's formalization reused a `book_requires` composition against this repository's
own exported book, with zero changes needed on either side — the exact cross-repository reuse the
metadata split is meant to make cheap.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind win --class "tooling bug or gap" --severity none \
  --what-happened "Customer B's book_requires'd our Layer.laws export directly; no renegotiation of the interface was needed, because book.toml's trust/provenance fields already answered their review question." \
  --tags-json '{"dimension": ["cross_pollination"], "polarity": "positive"}'
```

### (c) `guardrails_qa`

`books-gate.sh`'s layer lint reported `pass_vacuous`: zero of nine rules' file-halves matched any
discovered `.lean` path under the linted root, so the gate had checked nothing while exiting 0.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind issue --class "missing cheap verification tier" --severity minor \
  --what-happened "layer lint reported pass_vacuous (0 of 9 rules matched); the component's package root didn't match any rule's file-half, so lake build and the lint both looked green on a component the rules never touched." \
  --tags-json '{"dimension": ["guardrails_qa"], "polarity": "negative"}'
```

### (d) `token_cost_efficiency`

`books-gate.sh`'s cheap middle tier caught a layer violation in under a minute, avoiding the
ten-minute full-gate round trip that would otherwise have been the first catcher.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind win --class "missing cheap verification tier" --severity none \
  --what-happened "books-gate.sh caught a layer import violation in ~40s; without it the full gate (certify + Comparator rooms, ~10min) would have been the first catcher." \
  --tags-json '{"dimension": ["token_cost_efficiency"], "polarity": "positive"}' \
  --cost-value 9 --cost-unit minutes
```

### (e) `readability`

A reconciliation dispatch rewrote a guarantee's prose to cite the certifier's new statement text
directly, rather than paraphrasing — an engineer reading the rendered Typst document could now
explain the guarantee to a customer without opening the Lean source.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind win --class "tooling bug or gap" --severity none \
  --what-happened "Reconciled guarantee cites the certifier's own new statement text verbatim instead of a paraphrase; the rendered tier=overview document now reads as a standalone explanation." \
  --tags-json '{"dimension": ["readability"], "polarity": "positive"}'
```

### (f) `intuitive_exposure`

A book's `book.toml` set `status = "certified"` while a user-facing export was marked
`not_applicable` in the same certificate, with no visible explanation in the rendered document —
a user looking for that export found nothing pointing at why.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind issue --class "design-record defect or ambiguity" --severity minor \
  --what-happened "A not_applicable export had no corresponding phrase-table entry, so the rendered document silently omitted it with no pointer for a user looking for it by name." \
  --tags-json '{"dimension": ["intuitive_exposure"], "polarity": "negative"}' \
  --resolution worked_around
```

### (g) `compiling_composing`

A book's public import of the metadata provider module propagated the provider's own dependency
closure into every downstream consumer's PUBLIC import graph — the exact `import_weight` harm the
provider's private-import convention exists to prevent.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind issue --class "language or module-system gotcha" --severity costly \
  --what-happened "A module carried 'public import Books.Meta' instead of the private form; every downstream consumer's own public import closure now pulled in the provider's dependency, inflating import_weight for the whole subtree until the import was changed to private." \
  --tags-json '{"dimension": ["compiling_composing"], "polarity": "negative"}' \
  --resolution fixed_inline
```

## Worked example — a PAIRED burden

A convention change that lifts one burden usually creates another. Tag **both halves**, so a
later review cannot read half of a trade and call it a win. Both entries name the bearing
Decision by its durable heading text — never an invented identifier.

**Burden lifted**: moving certificate-identity computation out of hand-authored TOML and into the
certifier removed an entire class of stale-by-hand manifests.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind win --class "tooling bug or gap" --severity none \
  --what-happened "Decision 9's move of identity computation from book.toml into the certifier removed the 'forgot to bump the digest by hand' failure mode entirely -- zero hand-authored identity fields remain." \
  --tags-json '{"dimension": ["maintainability"], "polarity": "positive"}'
```

**Burden created**: the same move means a maintainer can no longer read a book's identity from
`book.toml` alone — they must run the certifier to see the current digest, which costs a build on
a component that previously needed none for this purpose.

```bash
bash .claude/scripts/issue-record.sh --task N \
  --kind issue --class "cost-forced exclusion or substituted verification" --severity minor \
  --what-happened "Because identity now lives only in book.cert.json, reading a book's current digest requires a certifier run (and therefore a build) where previously book.toml alone sufficed for a stale manual field -- Decision 9 traded staleness risk for a build dependency." \
  --tags-json '{"dimension": ["compiling_composing", "maintainability"], "polarity": "negative"}'
```

Both entries name the bearing Decision by its own durable heading text ("Decision 9's move...")
inside `what_happened`; `books-observe.sh` folds a tagged pair like this into the observation
record's `burdens_lifted[]` / `burdens_created[]` arrays when both entries are present for the
same task.

## What NOT to do

- **Do not invent a dimension key.** If none of the seven genuinely fits, tag nothing — do not
  stretch `intuitive_exposure` to cover a `guardrails_qa` finding because it is the one you
  remembered.
- **Do not omit polarity.** A tagged entry with a dimension but no polarity is as useless to the
  observer as an untagged one — it cannot be counted as a signal in either direction.
  `books-observe.sh` reports such an entry under `unrecognized_tags` rather than guessing.
- **Do not tag retroactively at the end of a dispatch.** Record `tags` at the same
  `issue-record.sh` call that creates the entry, as the event arises — exactly the same
  in-the-moment discipline `context/formats/issue-log.md` already requires for the entry itself.
  Reconstructing tags from memory at dispatch-end is exactly the free-prose failure mode the
  issue log was built to replace.
- **Do not expect the observer to infer a tag.** `books-observe.sh` reads `tags.dimension` and
  `tags.polarity`; it never classifies an entry's `what_happened` prose itself. An untagged entry
  stays untagged in the record, counted but not attributed to any dimension.

## Related

- `standards/observation-record.md` — the full schema these tags feed, including the
  computed-vs-supplied division of labour and the paired-burden schema requirement.
- `context/formats/issue-log.md` — the `tags` seam itself, the 15-class seed enum, and the
  severity scale.
