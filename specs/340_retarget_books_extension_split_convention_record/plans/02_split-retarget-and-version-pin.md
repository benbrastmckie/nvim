# Implementation Plan: Task #340

- **Task**: 340 - Retarget the books extension to the split convention record and pin the convention version
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: None
- **Research Inputs**: `specs/340_retarget_books_extension_split_convention_record/reports/02_split-retarget-grammar-and-anchors.md`, `specs/340_retarget_books_extension_split_convention_record/reports/01_seed-books-extension-split-retarget.md`
- **Artifacts**: plans/02_split-retarget-and-version-pin.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The books extension is correct against a convention-record file shape the consuming repository no
longer has: `docs/book-convention.md` was split into one file per decision under
`docs/book-convention/NN-slug.md` (H1 `# Decision N: ...`, carrying a reduced one-line
`- **Validated by**:` marker ending in an evidence pointer) plus a paired
`docs/book-convention-evidence/NN-slug.md`, leaving the flat file as a slim index. Three
consequences follow, two of them silent: the observer's promotion detection sees one decision
instead of eighteen (and already mis-reads the fault-frame record), the revise sub-mode's research
step silently drops every candidate whose marker it cannot quote, and the observer test fixture is
written in the obsolete flat shape so the suite stays green through all of it.

This plan retargets the extension in four content waves — observer plus fixtures, the two
sub-mode patterns, the six stale anchors plus the figure refresh, and the convention-version pin
with its non-blocking preflight comparison — then closes with a single phase that reconciles
`index-entries.json` line counts and runs the full gate set. Every edit lands in the source store
(`agent-system/extensions/books/**`), never under `.claude/**`.

### Research Integration

Findings from `reports/02_split-retarget-grammar-and-anchors.md` that this plan acts on directly:

- **Unicode, not ASCII.** The reduced marker's pointer arrow is `→` (U+2192) and the fault-frame
  heading dash is `—` (U+2014). The task description's `->` and `--` renderings are markdown
  transcription artifacts. All new regex and string logic matches the real characters.
- **The reference grammar, verbatim.** `lint-validated-by.sh:206-210` carries the per-record
  heading regex table; `:216-241` carries `DIR_HEADING_RE='^# Decision [0-9]+[[:space:]]*:'`,
  `expand_dir_shape()`, and the unconditional flat-path scan. Copy, cite by path, do not shell out.
- **The promotion comparison is new logic, not a reuse.** The observer today compares the entire
  marker line (`$prev != $a_marker`); `lint-validated-by.sh`'s `strip_marker_prefix()` strips only
  the label. Cutting at the literal `→ full exercise history and citations:` exists in neither
  script and must be written.
- **The census does not need correcting.** The live markers give 2 binding (Decisions 5, 14) /
  15 `partially` / 1 `none yet` (Decision 18) — exactly what `known-gap-register.md:31` already
  states. Only its dated SHA (`7281c81`) and date (2026-10-03) are stale against HEAD `a07ae5f`
  (2026-10-05). Do **not** overwrite 2/15/1 with the task description's 1/15/2.
- **`books/tool/book-snapshot.sh` does not exist** in the reference consuming repository. The
  observer already guards with `[ -x "$snapshot_probe" ]` and falls through to the documented
  `"absent"` sentinel. The acceptance item is satisfied by recording this, not by code.
- **The six anchors resolve** to concrete decision files (table reproduced in Phase 5).
- **`check-extension-docs.sh` imposes no manifest schema conflict** — a new top-level
  `convention_version` / `measured_at_commit` pair is safe. Its one figure check (Rule R,
  `check_line_count_accuracy`, blocking) validates `index-entries.json`'s `line_count` against
  each context file's actual `wc -l` — which **every** prose phase below perturbs.
- **Review has no existing live-read step.** `books-review-submode.md` sources
  `convention_decision` strings purely from `issues.jsonl` tags. "The same treatment" means
  *adding* a marker-quoting step, not editing one.
- **No hook exists and none may be added** (`manifest.json`'s `"hooks": []`).

Two items the research explicitly left to this plan, decided here:

1. **Transitional duplicate markers** (a decision present in the flat index and in a directory
   file at once). Decided in Phase 1: keep the observer's existing per-path keying. Each resolved
   path gets its own `before_map`, so a heading present in both shapes is diffed within its own
   file only and never across shapes — structurally preventing a stale-flat-vs-fresh-directory
   false promotion with no dedup logic. Each promotion entry gains a `source_path` field so a
   transitional duplicate is visible rather than silently merged. The observer deliberately does
   **not** mirror `lint-validated-by.sh`'s duplicate-marker *finding*: the lint accumulates
   one pass per key and can compare shapes; the observer's before/after diff is structurally
   per-path and has no place to raise one.
2. **Where the preflight comparison lives.** Decided in Phase 6: one named section in
   `context/project/books/README.md` (which already owns the normative-record paragraph and the
   "where the two disagree, the record wins" framing), referenced by one-line pointers from the
   two sub-modes' Edge Case Checks and from `skill-books-review/SKILL.md`'s Shared Sub-Mode
   Skeleton step 1. No new rule file, no hook, no new script.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; `specs/ROADMAP.md` was not consulted.

## Goals & Non-Goals

**Goals**:
- The observer resolves `Validated by` promotions across all three records in **both** shapes,
  with the correct per-record heading grammar, including the fault-frame `### Decision N —` form
  it mis-reads today.
- An evidence-pointer-only edit counts as **no** promotion.
- The observer test suite can fail: directory-shaped, transitional flat-plus-directory,
  fault-frame-heading, and pointer-only-edit fixtures all present and asserted.
- The revise sub-mode quotes a reduced marker for every decision in either shape and records the
  paired evidence file path; its hard return fires only when neither shape exists.
- The review sub-mode quotes live markers alongside its Burdens table and carries the convention
  version in its report header.
- The six line-range anchors cite `docs/book-convention/NN-slug.md` instead.
- `README.md:10`, `tooling-inventory.md:134`, and `known-gap-register.md:3` carry dated, measured
  figures.
- A `convention_version` / `measured_at_commit` pin exists, is mirrored as prose, is an optional
  observation-record field, and a non-blocking comparison reports mismatch and absence exactly
  once each.
- Gates green: `verify-deploy.sh`, `check-extension-docs.sh`, `check-task-references.sh`, and all
  three `scripts/tests/test-books-*.sh` suites.

**Non-Goals**:
- No new command, flag, hook, rule file, or repo-side script (`manifest.json`'s `"hooks": []`
  stays empty).
- No edit under `.claude/**` — that tree is a disposable deploy artifact. No deployment into any
  consuming repository; that is the owner's action.
- No change to the consuming repository (`~/Projects/Logos/Verification`) — read-only throughout.
- **No corpus-wide re-measurement.** The `2026-10-03` / `7281c81` dated-measurement convention
  appears in at least ten corpus files (`authoring-workflow.md`, `reconciliation-contract.md`,
  `certify-guide.md`, `certify-ledger-and-records.md`, `status-and-trust-vocabularies.md`,
  `forgery-probe-discipline.md`, `book-toml-v2.md`, `identity-and-versioning.md`,
  `tooling-inventory.md:3,48,181`, and others). Those figures measure Lean modules, manifests and
  tooling line counts that the convention-record split does not touch. Only the three figure
  sites this plan names are refreshed; re-measuring the rest is separate work.
- No correction to `known-gap-register.md`'s 2/15/1 census (it is already correct).
- No change to `schema_version: "observation-v1"`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new regex is written with ASCII `->` / `--` instead of `→` / `—`, silently matching nothing | H | M | Phase 2's fault-frame and pointer-only fixtures fail on ASCII look-alikes; Phase 1 copies the characters by `sed -n` extraction from `lint-validated-by.sh`, never retyped from the task description |
| `awk` regex matching on multibyte `—` behaves differently across `awk` implementations | M | M | Phase 2's fault-frame fixture is the proof; if `awk` proves unreliable on the literal, fall back to a byte-class alternation (`(\xe2\x80\x94|-)`) and record the deviation in the issue log |
| A prose edit changes a file's line count and Rule R (`check_line_count_accuracy`, blocking) fails `check-extension-docs.sh` | M | H | `index-entries.json` is owned exclusively by Phase 7, which reconciles every `line_count` mechanically from `wc -l` after all content phases land; no earlier phase touches that file |
| The transitional-shape decision produces a spurious promotion in real use | M | L | Per-path keying (Phase 1 decision 1) makes a cross-shape comparison structurally impossible; Phase 2's transitional fixture asserts it |
| The directory shape is read from git history, where a glob cannot be expanded | M | M | Phase 1 enumerates directory members with `git ls-tree -r --name-only "$h" -- docs/book-convention/` at each commit (and `"$h^"` for the before side), not a working-tree glob |
| A file written into the source store cites a task number and trips `check-task-references.sh` | M | L | Every phase cites durable anchors (filenames, decision numbers, section headings); Phase 7 runs the lint |
| Adding `convention_version` to `manifest.json` trips an undeclared-key check | L | L | Research confirmed `check-extension-docs.sh` walks only known keys and rejects no sibling; Phase 6 runs the check immediately |
| A sibling task editing the shared working tree is mistaken for a regression | L | M | Concurrent sibling (task 339) is scoped to `agent-system/extensions/typst/**` only — zero overlap; re-read before edit, stage only this task's hunks, never a directory or glob `git add` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3, 4, 5 | -- |
| 2 | 2, 6 | 1 (for 2); 3, 4, 5 (for 6) |
| 3 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Wave 1's four phases touch four disjoint
file sets. `index-entries.json` is touched by Phase 7 alone.

---

### Phase 1: Observer discovery grammar and value-prefix promotion comparison [COMPLETED]

**Goal**: `books-observe.sh` resolves `Validated by` markers across all three records in both the
flat and directory shapes, with the correct per-record heading grammar, and treats an
evidence-pointer-only edit as no promotion.

**Tasks**:
- [x] Extract the reference grammar verbatim from the consuming repository's
      `books/scripts/lint-validated-by.sh:191-241` (read-only; `sed -n` the literal characters
      rather than retyping them, so `—` and `→` survive). *(completed)*
- [x] Replace the flat `validated_by_files="..."` string (around `:311`, in `observe_run_core`'s
      BOOKS FACT 2 block) with a per-record heading-regex table mirroring
      `RECORD_HEADING_RE` / `GOVERNED_BASENAMES_ORDER` / `DIR_HEADING_RE` /
      `DIR_RECORD_LOGICAL_BASE` / `DIR_RECORD_DIRNAME`. *(completed)*
- [x] Add a header comment citing `books/scripts/lint-validated-by.sh` by path as the grammar's
      origin, and stating that the observer copies the grammar rather than shelling out to that
      lint, because it must run standalone in any consuming repository. *(completed)*
- [x] Generalize `extract_validated_by_pairs` (around `:128-135`) to take the heading regex as an
      `awk -v` parameter, and to strip the heading prefix generically (`^#+[[:space:]]+`) so
      `## Decision 13: ...`, `# Decision 13: ...` and `### Decision 13 — ...` all yield the same
      durable heading text. *(completed)*
- [x] Add directory expansion: for each commit, enumerate `docs/book-convention/*.md` with
      `git ls-tree -r --name-only "$h" -- docs/book-convention/` (and `"$h^"` for the before
      side), filter to `*.md`, sort by numeric prefix. Scan the flat `docs/book-convention.md`
      **unconditionally** in addition, pre-, mid-, and post-migration alike. *(completed: union
      of h/h^ directory members, plain `sort -u` suffices since basenames are zero-padded)*
- [x] Add the value-prefix-only promotion comparison: strip the label
      (`sed -E 's/^- \*\*Validated by\*\*: ?//'`, as `strip_marker_prefix()` does), then cut at
      the first occurrence of the literal `→ full exercise history and citations:`; a marker with
      no pointer (every flat-file marker) is compared whole. Compare prefixes, not whole lines.
      *(completed: `marker_value_prefix()`, verified with a manual sandbox fixture that a
      pointer-only edit produces zero promotion entries)*
- [x] Keep `before_map` per resolved path (reset per path, as today) so a transitional duplicate
      heading is never compared across shapes; add a `source_path` field to each promotion entry
      so the duplicate is visible in the record. *(completed)*
- [x] Leave `schema_version: "observation-v1"` and the snapshot-probe branch unchanged. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the edit is confined to `scripts/books-observe.sh` and
that `extract_validated_by_pairs` has exactly one call site pair (before/after) inside
`observe_run_core`. Confirm at implementation time with
`grep -n 'extract_validated_by_pairs\|validated_by_files' agent-system/extensions/books/scripts/books-observe.sh`
before editing; if another caller exists, enumerate it and widen the dependent set.

**Files to modify**:
- `agent-system/extensions/books/scripts/books-observe.sh` - heading-regex table, parameterized
  extractor, directory expansion via `git ls-tree`, value-prefix promotion comparison,
  `source_path` on promotion entries, grammar-provenance header comment

**Verification**:
- `bash -n agent-system/extensions/books/scripts/books-observe.sh` parses.
- `shellcheck agent-system/extensions/books/scripts/books-observe.sh` raises no new finding
  relative to its pre-edit baseline (capture the baseline first).
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` — the existing suite
  (the enumerated direct dependent) still passes, including Case 1's flat-shape promotion.
- `grep -c '→ full exercise history and citations:' books-observe.sh` is non-zero and the
  matched bytes are the real U+2192, confirmed with `grep -P '\x{2192}'`.

---

### Phase 2: Observer fixtures — remove the false green [COMPLETED]

**Goal**: the observer suite can fail against a drifted record shape. Four new fixtures cover the
shapes the split introduced, and Case 1 is explicitly labeled as the flat-shape case rather than
standing in for the whole grammar.

**Tasks**:
- [x] Relabel Case 1 ("THE JOIN") so its `## Decision 13: Exposure policy` fixture is named as
      the **flat-index** shape specifically, with an assertion comment stating that it alone
      cannot detect directory-shape drift (this is the false green's removal: the obsolete
      fixture stays valid as one shape among four, instead of silently representing all of them).
      *(completed)*
- [x] Add a **directory-shaped** fixture: `docs/book-convention/13-exposure-policy.md` with an H1
      `# Decision 13: Exposure policy` and a reduced marker carrying the
      `→ full exercise history and citations: [...](../book-convention-evidence/13-exposure-policy.md)`
      pointer; promote its value and assert one promotion with the durable heading
      `Decision 13: Exposure policy`. *(completed: Case 8)*
- [x] Add a **transitional** fixture: the same decision present in both the flat index and a
      directory file, with differing values. Assert the per-path keying behavior decided in
      Phase 1 — each shape diffed within its own file, no cross-shape promotion — and assert
      `source_path` distinguishes the two. *(completed: Case 9)*
- [x] Add a **fault-frame** fixture: `docs/fault-frame-design.md` with `### Decision N — ...`
      headings (real U+2014) and multiple markers; assert each marker is attributed to its own
      nearest preceding heading, not all to one. This fixture is the proof the pre-existing
      mis-read is fixed. *(completed: Case 10)*
- [x] Add a **pointer-only-edit** fixture: edit only the `→ full exercise history and
      citations: ...` tail of a reduced marker and assert `validated_by_promotions` is absent or
      has zero entries — this MUST NOT count as a promotion. *(completed: Case 11)*
- [x] Update the suite's header comment to name the shapes covered alongside the seven existing
      named acceptance behaviors. *(completed)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly four new fixture cases plus one relabel, all
within `scripts/tests/test-books-observe.sh` (341 lines pre-edit, Case 1 at roughly `:96-130`,
cases running through `:300`). Confirm the case boundaries and the next free case number with
`grep -n '^# Case\|^# ═' agent-system/extensions/books/scripts/tests/test-books-observe.sh`
before inserting.

**Files to modify**:
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` - Case 1 relabel plus four
  new fixture cases using the existing `init_repo`/`commit_files`/`assert_json` helpers

**Verification**:
- `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` reports 0 failed, and
  the passed count has risen by the number of new assertions.
- **Negative control** (the false green's real test): temporarily revert Phase 1's heading-regex
  table to the single `^## Decision` regex and confirm the directory, transitional, and
  fault-frame cases FAIL; restore. A fixture set that stays green against the pre-Phase-1
  observer has not removed the false green.
- `grep -P '\x{2014}'` confirms the fault-frame fixture's dash is the real em dash.

---

### Phase 3: Revise sub-mode — shape-tolerant research step and hard return [COMPLETED]

**Goal**: the revise sub-mode's mandatory research step enumerates the directory shape, quotes the
reduced marker verbatim, records the paired evidence path, and its hard return fires only when
neither shape exists.

**Tasks**:
- [x] Rewrite the "Mandatory Preliminary Research Step" (around `:83-116`) so the decision set is
      enumerated from `docs/book-convention/*.md` sorted by numeric prefix, **plus** any
      `## Decision` heading remaining in the flat `docs/book-convention.md` index. *(completed)*
- [x] State that the durable heading text is the decision file's **H1** (`# Decision N: ...`) in
      the directory shape, and the `## Decision N: ...` heading in the flat shape. *(completed)*
- [x] State that the marker quoted verbatim is the **one-line reduced** marker, including its
      `→ full exercise history and citations:` pointer, and add a third capture item: the paired
      `docs/book-convention-evidence/NN-slug.md` path, so a proposal can cite the exercise
      history. *(completed)*
- [x] Keep the three-form marker vocabulary table and the drop-if-unquotable bar unchanged in
      substance; adjust only the file-shape wording around them. *(completed)*
- [x] Amend Edge Case Check 4 (`:45-52`) so the HARD early return fires only when **neither**
      `docs/book-convention.md` nor the `docs/book-convention/` directory can be found; update
      its displayed message to name both shapes. *(completed)*
- [x] Update the live-marker paragraph (`:114`) and the `lint-validated-by.sh` reference so they
      name the directory-plus-index shape rather than a single flat file. *(completed)*
- [x] Leave the closed-discovery rule, ranking, and `--dry-run` sections untouched. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the edits are confined to
`books-revise-submode.md` and that it has exactly four Edge Case Checks with the hard return at
number 4. Confirm with
`grep -n 'book-convention\|^[0-9]\.' agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md`
before editing; if a fifth check or a second flat-file read exists, enumerate and cover it.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md` -
  Mandatory Preliminary Research Step, Edge Case Check 4, live-marker paragraph

**Verification**:
- Diff read-through confirming every changed hunk is prose inside this one file.
- `grep -n 'docs/book-convention' <file>` shows no remaining claim that the record is a single
  flat file, and at least one reference each to `docs/book-convention/` and
  `docs/book-convention-evidence/`.
- `grep -c 'book-convention-evidence' <file>` is non-zero (the new third capture item exists).
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the deployed
  equivalent) reports no new task-number citation.

---

### Phase 4: Review sub-mode — add a live-marker step and a versioned report header [NOT STARTED]

**Goal**: the review sub-mode quotes live reduced markers alongside its Burdens table and its
dated report header carries the convention version.

**Tasks**:
- [ ] Add a marker-quoting step to "Execution: Burdens Created vs. Burdens Lifted (Paired)"
      (`:155-172`): for each bearing Decision named on a `burdens_created`/`burdens_lifted` entry,
      read the live decision file (directory shape first, flat index second, same enumeration
      rule as Phase 3) and carry its verbatim reduced marker and paired evidence path into the
      table — stated as an **addition**, since this sub-mode has no live-read step today and
      sources `convention_decision` purely from `issues.jsonl` tags.
- [ ] Add two columns (or a stated adjacent line, whichever keeps the table readable at 100
      columns) for the live marker and the evidence path, and state the degraded behavior when a
      named Decision resolves to neither shape: report it as a named unresolvable-decision
      finding, never a fabricated marker, consistent with the Omit-Never-Zero rule at `:173`.
- [ ] Add a convention-version line to the "Execution: Output" dated-report template (`:194-201`),
      carrying the pinned `convention_version` and the comparison verdict from Phase 6.
- [ ] Extend Edge Case Checks (`:27-51`) with a non-blocking note that neither shape being present
      degrades the Burdens table rather than returning early (review is a report-owing sub-mode;
      only the revise sub-mode hard-returns).
- [ ] Leave the Funnel Rule, the read-only boundary, and the Log Entry section untouched.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the review sub-mode has **no** existing step that reads
`docs/book-convention.md` directly (research finding), so this is an addition and not an edit.
Confirm with
`grep -n 'book-convention' agent-system/extensions/books/context/project/books/patterns/books-review-submode.md`
returning no match before writing; a match means an existing step must be edited instead.

**Files to modify**:
- `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md` -
  Burdens section (new live-marker step and table columns), Output report-header template, Edge
  Case Checks note

**Verification**:
- Diff read-through confirming every changed hunk is prose inside this one file.
- `grep -n 'convention_version\|book-convention/' <file>` shows the report header carries the
  version and the enumeration names the directory shape.
- The read-only boundary is intact: `grep -n 'only write' <file>` still names the dated report as
  the sub-mode's sole write.
- `check-task-references.sh` reports no new task-number citation.

---

### Phase 5: Retarget the six anchors and refresh the three stale figures [NOT STARTED]

**Goal**: no corpus file cites a `docs/book-convention.md:NNN` line range, and the three figures
the split invalidated are dated and measured.

**Tasks**:
- [ ] Retarget the six line-range anchors, dropping the `:LINE-RANGE` suffix entirely and citing
      the decision file path while keeping the existing "Decision N" prose that every one of the
      six already carries:

      | Corpus file:line | Cites | New target |
      |---|---|---|
      | `standards/metadata-split.md:4` | Decision 6 (`:610-798`) | `docs/book-convention/06-where-metadata-lives.md` |
      | `domain/book-toml-v2.md:8` | Decision 7 (`:799-906`) | `docs/book-convention/07-book-toml-v2-schema.md` |
      | `domain/certificate-ledger-and-records.md:8` | Decisions 8 (`:907-1092`), 9, 11 | `docs/book-convention/08-computed-dependencies-and-book-cert-json.md`, `09-trust-unit-is-the-export.md`, `11-versioning-rule.md` |
      | `domain/identity-and-versioning.md:9` | Decision 9 (`:1093-1213`), Decision 11 (`:1367-1497`) | `docs/book-convention/09-trust-unit-is-the-export.md`, `11-versioning-rule.md` |
      | `domain/layer-vocabulary-and-matrix.md:7-8` | Decision 2 (`:245-326`), Decision 3 (`:327-424`) | `docs/book-convention/02-layer-vocabulary.md`, `03-layer-import-matrix.md` |
      | `domain/status-and-trust-vocabularies.md:7` | Decision 12 (`:1498-1575`) | `docs/book-convention/12-status-vocabulary-and-trust-block.md` |

- [ ] Refresh `context/project/books/README.md:9-13`: replace "3,212 lines" with the measured
      slim-index line count (343 at HEAD `a07ae5f`, re-measured at implementation time) and state
      that `docs/book-convention.md` is now the slim index over `docs/book-convention/NN-slug.md`
      plus `docs/book-convention-evidence/NN-slug.md`. Keep "eighteen accepted decisions" and
      keep the "where the two disagree, the record wins" framing verbatim.
- [ ] Refresh `tools/tooling-inventory.md:134`: keep "eighteen `Validated by` markers" (the count
      is correct) but name the directory-plus-index shape, since the markers no longer all live in
      one file.
- [ ] Refresh `domain/known-gap-register.md:3`: bump the date and the git SHA to the measured
      HEAD, and name the `convention_version` pin (Phase 6) as the staleness handle the prose SHA
      previously served as. **Do not touch the 2/15/1 census at `:31`** — it is already correct;
      re-verify it mechanically per the register's own "How to refresh this file" section and
      record the re-verification in the issue log.
- [ ] Do **not** touch any other `2026-10-03` / `7281c81` dated measurement in the corpus (see
      Non-Goals) — those measure Lean modules, manifests and tooling unaffected by the split.
      `domain/certificate-ledger-and-records.md:9-10` carries such a measurement line adjacent to
      an anchor being retargeted; retarget the anchor and leave the measurement line alone.
- [ ] Do **not** edit `index-entries.json` — Phase 7 owns it.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly six anchor sites and exactly three figure sites.
Confirm the anchor count at implementation time with
`grep -rn 'book-convention\.md:[0-9]\|book-convention\.md.*(`:[0-9]' agent-system/extensions/books/context/project/books/`
and the figure sites with `grep -rn '3,212\|7281c81' <same tree>`; a seventh anchor or a fourth
split-invalidated figure is in scope and must be covered, while a dated measurement unrelated to
the convention record is not.

**Files to modify**:
- `.../context/project/books/standards/metadata-split.md` - Decision 6 anchor
- `.../context/project/books/domain/book-toml-v2.md` - Decision 7 anchor
- `.../context/project/books/domain/certificate-ledger-and-records.md` - Decisions 8/9/11 anchors
- `.../context/project/books/domain/identity-and-versioning.md` - Decisions 9/11 anchors
- `.../context/project/books/domain/layer-vocabulary-and-matrix.md` - Decisions 2/3 anchors
- `.../context/project/books/domain/status-and-trust-vocabularies.md` - Decision 12 anchor
- `.../context/project/books/README.md` - slim-index line count and shape description
- `.../context/project/books/tools/tooling-inventory.md` - marker-shape description at `:134`
- `.../context/project/books/domain/known-gap-register.md` - header date, SHA, pin reference

**Verification**:
- `grep -rn 'book-convention\.md.*:[0-9]\+-[0-9]\+' agent-system/extensions/books/context/` returns
  no match (zero remaining line-range citations).
- `grep -rn '3,212' agent-system/extensions/books/` returns no match.
- Diff read-through confirming every changed hunk is prose and that no `2026-10-03` measurement
  outside the three named figure sites was altered:
  `git diff -- agent-system/extensions/books/context/ | grep -c '^-.*2026-10-03'` equals the
  number of intentionally refreshed date lines (1, in `known-gap-register.md`).
- The 2/15/1 census at `known-gap-register.md:31` is byte-identical pre- and post-edit.
- `check-task-references.sh` reports no new task-number citation.

---

### Phase 6: The convention-version pin and the non-blocking preflight comparison [NOT STARTED]

**Goal**: a structured `convention_version` / `measured_at_commit` pin replaces the prose git SHA
as the staleness handle, a non-blocking comparison against the record reports mismatch and absence
exactly once each, and `convention_version` is an optional observation-record field.

**Tasks**:
- [ ] Add top-level `"convention_version"` and `"measured_at_commit"` to
      `agent-system/extensions/books/manifest.json` (research confirmed `check-extension-docs.sh`
      walks only known keys and rejects no sibling). Set `convention_version` to the value read
      from the record if the record carries a `- **Convention version**:` line, and to the
      explicit sentinel `"unversioned"` if it does not — which, per research, is the current
      state in the reference consuming repository.
- [ ] Mirror the pin as prose in `context/project/books/README.md`'s normative-record paragraph,
      keeping the "where the two disagree, the record wins and this corpus is stale" framing.
- [ ] Add one named section to `context/project/books/README.md` — "Convention version pin and
      staleness comparison" — stating the whole comparison once: read
      `- **Convention version**:` from the consuming repository's `docs/book-convention.md`;
      on mismatch report **once** that the record wins and the corpus is stale; on an absent line
      report **once** that the record is unversioned; **never blocking**; **no hook** (the
      extension has none by design and must not gain one); no new script, no new rule file.
- [ ] Reference that section with a one-line pointer from
      `skill-books-review/SKILL.md`'s Shared Sub-Mode Skeleton step 1 (Edge Case Checks) so both
      `/books` sub-modes inherit it once, and from each sub-mode file's own Edge Case Checks
      (`books-review-submode.md`, `books-revise-submode.md`) — a pointer, not a third copy of the
      procedure.
- [ ] Add `convention_version` as an **optional** field to
      `context/project/books/standards/observation-record.md`'s field table, and note the
      `- **Convention version**:` record marker there as its source.
- [ ] Record the snapshot-probe confirmation in `observation-record.md`'s Probe Ownership Boundary
      discussion: the probe name and contract are `books/tool/book-snapshot.sh` with `--json` and
      `--diff A B --json`; it is **absent** in the reference consuming repository, which exercises
      the documented `"absent"` sentinel rather than indicating a defect.
- [ ] Confirm `manifest.json`'s `"hooks": []` is still empty and no `observers` entry gained a
      script.
- [ ] Do **not** edit `index-entries.json` — Phase 7 owns it.

**Timing**: 1.5 hours

**Depends on**: 3, 4, 5

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that `manifest.json` accepts two new top-level keys with
no gate conflict, and that the comparison has exactly three consuming sites (the shared skeleton
plus two sub-mode files). Confirm the gate claim by running
`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` immediately
after the manifest edit, and the site count with
`grep -rln 'Edge Case Checks' agent-system/extensions/books/skills/ agent-system/extensions/books/context/project/books/patterns/`.

**Files to modify**:
- `agent-system/extensions/books/manifest.json` - `convention_version`, `measured_at_commit`
- `.../context/project/books/README.md` - pin prose mirror plus the comparison section
- `.../context/project/books/standards/observation-record.md` - optional `convention_version`
  field, version-marker note, snapshot-probe confirmation
- `agent-system/extensions/books/skills/skill-books-review/SKILL.md` - skeleton step 1 pointer
- `.../context/project/books/patterns/books-review-submode.md` - Edge Case Checks pointer
- `.../context/project/books/patterns/books-revise-submode.md` - Edge Case Checks pointer

**Verification**:
- `python3 -c "import json;json.load(open('agent-system/extensions/books/manifest.json'))"` parses,
  and `jq -r '.convention_version, .measured_at_commit, (.hooks|length)'` prints the two values
  and `0`.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes for
  the books extension (the enumerated direct dependent of the manifest change).
- `grep -rc 'Convention version' agent-system/extensions/books/` shows the procedure stated once
  in `README.md` and referenced (not restated) at the three consuming sites.
- `grep -n 'blocking\|hook' README.md`'s new section states non-blocking and no-hook explicitly.
- `check-task-references.sh` reports no new task-number citation.

---

### Phase 7: Line-count reconciliation and the full gate sweep [NOT STARTED]

**Goal**: `index-entries.json`'s `line_count` values match the edited files, and every gate the
acceptance criteria name is green.

**Tasks**:
- [ ] Re-measure `wc -l` for every context file touched by Phases 3-6 and update its `line_count`
      in `agent-system/extensions/books/index-entries.json` (Rule R,
      `check_line_count_accuracy`, is **blocking**).
- [ ] Reconcile the full `index-entries.json` set mechanically, not only the files this task
      edited, so a pre-existing drift is surfaced rather than inherited; if a file this task never
      touched is already drifted, record it in the issue log and fix the count (a one-line
      mechanical correction), noting it as pre-existing.
- [ ] Run the complete gate set and record each result:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/verify-deploy.sh`,
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`,
      `bash .claude/scripts/check-task-references.sh`,
      `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh`,
      `bash agent-system/extensions/books/scripts/tests/test-books-gate.sh`,
      `bash agent-system/extensions/books/scripts/tests/test-books-certify.sh`.
- [ ] Walk the acceptance list item by item and record the evidence for each: promotions resolved
      in both shapes with per-record grammar; pointer-only edit counts as no promotion; both
      sub-modes quote reduced markers; six anchors retargeted; figures dated and measured; pin
      present and comparison reporting mismatch and absence once each without blocking;
      fault-frame fixture proving the mis-read is fixed.
- [ ] Confirm nothing was written under `.claude/**` by this task:
      `git status --short -- .claude/` is empty (the deployed tree is regenerated by deploy, never
      hand-authored).

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that only the `line_count` values of files edited in
Phases 3-6 need updating. Confirm by reconciling the whole file mechanically (a loop comparing
each entry's `line_count` against `wc -l`) rather than editing only the expected subset; any
additional mismatch found is either this task's unnoticed side effect or pre-existing drift, and
the issue log records which.

**Files to modify**:
- `agent-system/extensions/books/index-entries.json` - `line_count` values for every edited
  context file

**Verification**:
- The full gate set above exits 0 for every member — this is the `full` tier's complete set, not a
  hand-picked subset.
- A reconciliation loop over `index-entries.json` reports zero `line_count` mismatches.
- `git status --short -- .claude/` is empty.
- Every acceptance item has a recorded evidence line.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/books/scripts/tests/test-books-observe.sh` — 0 failed, with
      the four new shape fixtures asserted.
- [ ] Negative control: the directory, transitional, and fault-frame fixtures FAIL against the
      pre-Phase-1 single-regex observer (proving the false green is gone).
- [ ] `bash agent-system/extensions/books/scripts/tests/test-books-gate.sh` — 0 failed.
- [ ] `bash agent-system/extensions/books/scripts/tests/test-books-certify.sh` — 0 failed.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/verify-deploy.sh` — exit 0.
- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` —
      exit 0, books extension passing (Rule R included).
- [ ] `bash .claude/scripts/check-task-references.sh` — no new task-number citation in the source
      store.
- [ ] `bash -n` and `shellcheck` clean on `books-observe.sh` relative to its pre-edit baseline.
- [ ] `grep -rn 'book-convention\.md.*:[0-9]\+-[0-9]\+' agent-system/extensions/books/context/`
      returns no match.
- [ ] `git status --short -- .claude/` is empty.

## Artifacts & Outputs

- `agent-system/extensions/books/scripts/books-observe.sh` — directory-tolerant per-record
  heading grammar, value-prefix promotion comparison, `source_path` on promotion entries
- `agent-system/extensions/books/scripts/tests/test-books-observe.sh` — four new shape fixtures,
  Case 1 relabeled
- `agent-system/extensions/books/context/project/books/patterns/books-revise-submode.md` —
  shape-tolerant research step and hard return
- `agent-system/extensions/books/context/project/books/patterns/books-review-submode.md` —
  live-marker step, versioned report header
- Six retargeted anchor files under `context/project/books/{standards,domain}/`
- `context/project/books/README.md` — refreshed figure, pin mirror, comparison section
- `context/project/books/tools/tooling-inventory.md`,
  `context/project/books/domain/known-gap-register.md` — refreshed figures
- `context/project/books/standards/observation-record.md` — optional `convention_version` field,
  snapshot-probe confirmation
- `agent-system/extensions/books/skills/skill-books-review/SKILL.md` — skeleton pointer
- `agent-system/extensions/books/manifest.json` — the pin
- `agent-system/extensions/books/index-entries.json` — reconciled `line_count` values
- `specs/340_retarget_books_extension_split_convention_record/summaries/02_*-summary.md`

## Rollback/Contingency

Every phase is a scoped commit on `master` under the `task {N}: ...` convention, so any single
phase reverts with `git revert <sha>` without disturbing the others. The content phases are
independent by file set (Wave 1's four phases share no file), so a failed phase does not strand
its siblings.

If Phase 1's `awk` multibyte matching proves unreliable across implementations, the contingency is
the byte-class alternation noted in the risk table, not abandoning the grammar copy. If Phase 6's
manifest keys unexpectedly trip a gate, the pin falls back to prose in `README.md` alone (the
mirror already planned) with the structured pair deferred — the comparison procedure itself is
unaffected, since it reads the record, not the manifest.

Nothing in this task writes outside `agent-system/extensions/books/**` and `specs/340_*/`, and
nothing is pushed or deployed; a full abandonment is `git revert` over this task's commits with no
external side effect to undo. The consuming repository is read-only throughout, so no rollback
there is possible or needed.
