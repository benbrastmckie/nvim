# Implementation Plan: Task #477

- **Task**: 477 - Normalize issue-log class vocabulary; reject the conclusion aggregator's malformed `--tasks` call shape
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/477_normalize_issue_log_class_vocabulary/reports/01_issue_log_class_vocabulary.md
- **Artifacts**: plans/01_class-vocabulary-normalization.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two defects sharing one edit target are fixed together. Part 1 stops the issue-log `class`
vocabulary from fragmenting: `scope excursion` is promoted into the seed enum, grouping-time
case-and-separator folding is added to the aggregator's jq pipeline (never to any stored value),
an empty-but-documented semantic alias table ships as a mechanism, and the `class`-value shape
convention gains both a written rule and an append-time warning. Part 2 replaces the aggregator's
silent last-wins handling of repeated `--tasks` flags with a loud usage rejection. All edits land
in the source store at `agent-system/extensions/core/`, and the deployed `.claude/` tree is
regenerated once at the end.

### Research Integration

The research report settled four questions this plan builds directly on:

- **`scope excursion` is not a choice to make.** It is already the literal `--class` string two
  mechanical writers emit (`git-commit-phase.sh:741`, `git-commit-scoped.sh:866`), 443 occurrences
  corpus-wide. Promotion is documentation catch-up; no call site changes.
- **Rejection, not union, for repeated `--tasks`.** The script's only documented and only live
  call site (`context/contracts/conclusion-stage.md:231`) already passes the correct single
  space-joined string, so there is no competing union convention to honor. Re-verified live at
  plan time: a repo-wide grep for `--tasks` across `agent-system/**` finds exactly that one
  non-self call site. Rejection breaks nothing.
- **The alias table ships empty.** Each named semantic pair rests on one corpus occurrence, and
  `scope/file_scope omission discovered pre-emptively` is plausibly the *opposite* concept from
  `scope excursion` (scope found too narrow vs. work falling outside a stated scope). The
  mechanism is built; populating it is a separately-evidenced decision.
- **1d's detector must not be verb-keyword-based.** Short, verb-bearing class names
  (`hypothesis confirmed`, `fix confirmed working`, `blocker-cleared`) are widespread, legitimate
  live usage; a blocklist on "confirmed"/"found"/"discovered" would false-positive heavily.

### Premise Re-Validation (Carried-Figure Discipline)

Every figure the dispatch and the research report carry was checked against live state before
this plan was written. Results, stated explicitly including where they only confirm:

| Carried claim | Source | Live check | Verdict |
|---|---|---|---|
| Both change requests share the single edit target `scripts/orchestrate-conclusion-aggregate.sh` | Dispatch, CONSOLIDATION NOTE | Read the script; Part 2 is entirely within it, Part 1's grouping/seed-list halves are too | **Confirmed.** Part 1 additionally spans 9 further files, but the shared-target premise the consolidation rests on holds |
| Promotion touches **8 files** | Research, Findings | `grep -rn "17-class\|17 classes\|17 class"` over `agent-system/extensions/core/` | **Corrected upward: 13 occurrences across 10 files.** The report omits `index-entries.json:3812` and `scripts/tests/test-orchestrate-build-dispatch.sh:206`. Phase 1 enumerates all 10 |
| The three free-text examples "must be caught by" 1d's remedy | Dispatch, 1d | Post-fold token counts: `research-confirmed-hypothesis` = 3, `reuse_of_existing_machinery` = 4, `reuse-not-reimplement confirmed by direct source read` = 8 | **Requirement not satisfiable by the research report's 6-token threshold alone** (it catches 1 of 3). Resolved in Decisions below; the catch is re-based on a warning that provably fires on all three |
| Requirement (e): an unrecognized class must still appear in the output | Dispatch, VERIFICATION | Read the aggregator's `unknown_classes` derivation and its `proposals` derivation | **Confirmed as achievable without behavior loss.** An unrecognized class reaches `proposals[]` by construction and `unknown_classes[]` by the seed-membership test; Phase 2 re-keys the test without adding any drop path. Case (s) proves it |
| `--tasks` repeated-flag defect reproduces | Dispatch, Part 2 | Read lines 88-100: `--tasks) tasks_arg="${2:-}"; shift 2 ;;` unconditionally reassigns, no accumulation, no diagnostic | **Confirmed unchanged** |
| Regression suite is green at baseline | (new) | `CORE_TEST_SUBJECT_MODE=source-store bash .../test-orchestrate-conclusion-aggregate.sh` | **15 passed, 0 failed.** Any red during implementation is this task's own |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:

- Promote one canonical `scope excursion` spelling into the seed enum, with every file that
  restates the enum's size brought into agreement.
- Fold case and separators at grouping time in the aggregator so `COVERAGE_GAP` and
  `coverage-gap` produce one proposal, with the merge visible and auditable in the output.
- Ship the semantic alias table as an empty, documented mechanism, and make the unknown-class
  tally read post-fold so spelling noise stops inflating it.
- Give `class` a written shape convention and an append-time warning that fires on all three of
  the dispatch's free-text examples.
- Reject a repeated `--tasks` flag with a usage error naming the correct single-string form, and
  record the audit of the script's other flags in its usage header.
- Leave every byte of every stored `issues.jsonl` untouched, and prove it mechanically.

**Non-Goals**:

- Rewriting, migrating, or backfilling any stored `class` value, in any `issues.jsonl`, ever.
  This is the dispatch's HARD CONSTRAINT and the reason Phase 5 case (r) exists.
- Populating the alias table with any semantic merge. The mechanism ships empty.
- Promoting any class other than `scope excursion`. The research report names seven further
  already-hardcoded non-seed classes (`source store excursion`, `derived-surface staleness`,
  `derived artifact staleness`, `unresolved task-domain blocker`, `repository configuration`,
  `milestone ref landing`, `roadmap regenerate blocked, no approval surface`); each is a separate,
  separately-evidenced promotion and none is acted on here.
- Turning `class` into a closed enum. `issue-record.sh` warns and proceeds; it never refuses.
  Both the script header and `issue-log.md` document why, and that posture is preserved.
- Re-litigating the issue-log contract's threading design, or the Component 0 consolidation.
- Extracting the fold into `lib/common.sh`. The two consumers are in different languages (jq and
  bash); a shared bash library cannot serve the jq one. See Decisions.

## Decisions

These are recorded here because the dispatch (1c, 1d, 2a) explicitly asks for the reasoning, not
just the outcome. Rejected alternatives are stated on their own merits.

**D1 — Where the normalization line falls (1c).** Three layers, in order of how much judgment each
exercises:

1. **Mechanical fold, applied unconditionally.** Case folding plus separator folding (hyphen,
   underscore, runs of whitespace → a single space, then trim). This is safe to apply silently
   because it can only ever merge strings built from *the same words*. It cannot invent a
   relationship between two different phrases.
2. **A curated alias table, shipped empty.** A hand-maintained jq object literal consulted after
   the fold and before grouping. The mechanism exists so a future, better-evidenced semantic merge
   is a one-line data edit rather than a structural change; it carries no entries today.
3. **The unknown-class tally, re-keyed post-fold.** Spelling noise stops inflating it, so what
   remains in the tally is genuine vocabulary growth — exactly the signal the seed enum is meant
   to grow from.

*Rejected: collapsing the five scope spellings automatically.* They are not five spellings of one
word. `excursion`, `deviation`, `correction` and `omission` are four different words naming at
least two different concepts, and `scope/file_scope omission discovered pre-emptively` points the
opposite direction from `scope excursion`: an omission is scope found too narrow, an excursion is
work falling outside a stated scope. A rule that merged them would destroy signal invisibly, which
is the failure mode the dispatch names. The mechanical fold correctly leaves them unmerged, since
different words survive folding as different strings.

*Rejected: merging `design-gap` into `design-ambiguity` now.* One corpus occurrence each. That is
not enough evidence to commit a silent semantic merge, and the alias table exists precisely so
this can be decided later on better evidence instead of guessed at now.

*Rejected: a similarity metric (edit distance, token overlap).* It would merge `scope excursion`
with `scope omission` — a merge this plan has just established is wrong — and would do so with no
auditable record of why. A curated table is slower to grow and is reviewable; a metric is neither.

**D2 — How 1d catches all three free-text examples.** The dispatch requires that the three named
entries be caught. The research report's recommended post-fold token-count threshold of 6 catches
only one of them (`reuse-not-reimplement confirmed by direct source read`, 8 tokens);
`research-confirmed-hypothesis` folds to 3 tokens and `reuse_of_existing_machinery` to 4, both
indistinguishable by length from legitimate seed classes such as `resource/OOM including
misdiagnosis`. No mechanical length or keyword rule can separate the latter two from a legitimate
short noun phrase, because in shape they *are* short noun phrases — their defect is semantic (they
name a finding's content rather than a category).

The remedy is therefore two-part, and the part that discharges the dispatch's requirement is the
first:

- **The outside-the-seed-enum stderr warning in `issue-record.sh` is the catch.** It fires today
  on all three (none is a seed class), and Phase 4 extends its text to name the class-shape
  convention, so an author who writes a sentence is told, at append time, what `class` is for.
  This is literally "a warning" and "a documented convention", two of the three remedies the
  dispatch offers.
- **The post-fold token-count check is an additional, sharper signal**, retained for the
  sentence-shaped subset, emitted as a second warning above 6 tokens (one above the longest
  legitimate seed gloss, `cost-forced exclusion or substituted verification`, which folds to 6).

*Rejected: a verb/keyword blocklist.* The research report's corpus sample shows `hypothesis
confirmed`, `fix confirmed working`, `mechanism confirmed`, `blocker-cleared`, `tooling worked
first try` and `falsifiability confirmed` are all live, idiomatic, legitimate usage. A blocklist on
"confirmed"/"found"/"discovered" would false-positive against a large share of the existing
`kind: "win"` population.

*Rejected: refusing a malformed `class` at append time.* `issue-record.sh`'s open-enum posture is
a deliberate, documented divergence from `system-defect-record.sh`, recorded in both the script
header and `issue-log.md` with the reason: a genuinely new failure mode must be recordable the
first time it is hit. Refusing would mean an agent hitting a novel failure records nothing at all,
which is strictly worse than recording it under an imperfect class name.

**D3 — Reject repeated `--tasks`; do not union (2a).** The script's only live call site already
uses the correct single-string form, confirmed by grep at plan time, so there is no existing union
convention to match and no caller to break. Rejection costs a wrong caller one retry; the current
silent last-wins costs the entire conclusion stage with no error to notice.

**D4 — The flag audit (2b), and what it found.** `--session`, `--channel` and `--answer` are the
only other value-taking flags, and all three are genuinely scalar selectors (a session id, a
closed-enum channel key, a closed-enum yes/no answer) where last-occurrence-wins is the ordinary,
unsurprising shell convention rather than a misparse hazard. No list-valued flag other than
`--tasks` exists.

The audit did surface one same-idiom hazard outside the list-valued class: the three mode flags
(`--aggregate`, `--record-approval`, `--check-approval`) also silently last-wins, even though the
script's own error message promises "exactly one of ... is required". Phase 3 closes this too,
because the promise is already written and currently unenforced. This is a judgment call beyond
2b's literal ask; it is three lines, it is separable, and it is called out here so a reviewer can
see it was deliberate rather than drift.

**D5 — The fold is implemented twice, deliberately, with a cross-reference.** The aggregator needs
it in jq; `issue-record.sh` needs it in bash. No shared library can serve both, and this codebase
already uses a named SHARED FRAGILITY cross-reference convention for exactly this situation (the
two independent Lean plan Goals-block readers). Each implementation carries a comment naming the
other as its twin and stating that a change to one requires a matching change to the other. The
divergence risk is recorded in Risks below rather than papered over.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The seed-enum promotion lands in the three list-holding files but leaves stale "17" prose in the other seven | M | H | Phase 1 enumerates all 10 files with line numbers and gates on `grep -rn "17-class\|17 classes\|17 class"` returning empty across both `agent-system/**` and (after Phase 6's deploy) `.claude/**` |
| A test suite resolves the **stale deployed copy** and reports green on an unchanged script — a vacuous pass that would hide every pre-deploy phase's real state | H | H | Every pre-deploy phase runs its suites with `CORE_TEST_SUBJECT_MODE=source-store` exported (verified working at plan time: 15/15 green against the source store). Phase 6 re-runs them in the default deploy-tree-first mode after the redeploy, so the deployed tree is proven independently |
| The two fold implementations (jq and bash) drift apart, so `issue-record.sh` and the aggregator disagree about what counts as the same class | M | M | Reciprocal SHARED FRAGILITY comments (D5); Phase 5 exercises the same named variant set against both sides, so a one-sided change turns a case red |
| `usage()` reads a fixed line range (`sed -n '2,46p'`) of the script's own header, so any header growth silently truncates or over-extends the printed usage | M | H | Phases 2 and 3 both edit that header; each one's task list includes re-checking and updating the `sed` range, and Phase 5 case (p) asserts the usage text emitted on the rejection path actually names the correct `--tasks "N N N"` form |
| Rejecting repeated `--tasks` breaks an undiscovered caller | L | L | Re-verified at plan time: a repo-wide grep over `agent-system/**` finds exactly one non-self `--tasks` call site, already using the correct form. Phase 3 re-runs that grep immediately before landing the rejection |
| Choosing the group's representative raw `class` non-deterministically makes the output unstable across runs | L | M | Phase 2 specifies most-frequent-raw-spelling with a lexicographic tie-break, and adds `class_variants[]` so the full raw set is always visible regardless of which representative was chosen |
| A sibling task (567) commits into this same working tree mid-phase | M | M | 567's declared `file_scope` (`git-commit-scoped.sh`, `test-git-commit-scoped.sh`, `test-git-commit-phase.sh`) is disjoint from every file in this plan. Per the dispatch's territory note: re-read each file immediately before editing, stage only this task's own hunks by explicit file list, never a directory or glob add, and never run `git-snapshot.sh` in its reverting default mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel. Phase 3 follows Phase 2 because both edit
different regions of the same file; Phase 4 is independent of the aggregator work and shares only
`issue-log.md` with Phase 1, in a different section.

**A mechanic every phase below depends on**: the regression suites resolve their subject
deploy-tree-first, so a source-store edit is invisible to them until a redeploy. `lib/common.sh`'s
`CORE_TEST_SUBJECT_MODE=source-store` environment override (documented in its
`common_test_resolve_subject` header) redirects that resolution to the source store, and the
suites copy the resolved script into a scratch `.claude/scripts/` tree, so `deploy-root-guard.sh`
still passes. Every pre-deploy phase exports it. **A suite run without it, before Phase 6, is a
vacuous pass on a stale copy and must not be read as evidence.**

---

### Phase 1: Promote `scope excursion` and reconcile the seed-enum count [COMPLETED]

**Goal**: `scope excursion` becomes the 18th seed class, and every file in the source store that
states the enum's size agrees.

**Tasks**:

- [x] Re-run `grep -rn "17-class\|17 classes\|17 class" agent-system/extensions/core/` and record
      the baseline occurrence set before editing. *(completed)*
- [x] `context/formats/issue-log.md`: add the 18th gloss-table row for `scope excursion` —
      "A touched file or action fell outside the task's declared `file_scope`; written mechanically
      by the scoped-commit tooling (`git-commit-phase.sh`, `git-commit-scoped.sh`) when a file is
      dropped from a commit pathspec for this reason, and by an agent recording the same thing by
      hand." State the canonical spelling explicitly in the surrounding prose: lowercase, a single
      space, no hyphen and no underscore. *(completed)*
- [x] `context/formats/issue-log.md`: update the section heading, the derivation paragraph beneath
      it, the `class` row of the Entry Field Table, the Extensibility Rule's "17 seed classes", and
      the Unknown-Class Tally's "17-class seed list". Extend the derivation paragraph in its
      existing register (a present-tense statement of where the class comes from, not a narration
      of this document's own drafts). *(completed)*
- [x] `scripts/issue-record.sh`: add the entry to the `ISSUE_SEED_CLASSES` array and to the
      comment-only copy above it; update the header reference and the stderr warning text. *(completed)*
- [x] `scripts/orchestrate-conclusion-aggregate.sh`: add the entry to `SEED_CLASSES_JSON`; update
      the header reference and the comment above the literal. *(completed)*
- [x] `scripts/orchestrate-build-dispatch.sh`: update the injected dispatch-file text. *(completed)*
- [x] `scripts/tests/test-orchestrate-build-dispatch.sh`: update the assertion *message* text (the
      assertion itself tests for an unrelated string and does not change). *(completed)*
- [x] `context/contracts/conclusion-stage.md`, `context/contracts/phase-closure.md`,
      `context/standards/error-recovery-strategies.md`,
      `context/patterns/orchestrate-batch-results-template.md`: update each restatement. *(completed)*
- [x] `index-entries.json`: update the `context/formats/issue-log.md` entry's summary string. *(completed)*
- [x] Confirm no file landing under `agent-system/**` gained a task-number reference or any
      record-versioning language. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: exactly 13 occurrences across 10 files state the enum's size, measured at
plan time by `grep -rn "17-class\|17 classes\|17 class" agent-system/extensions/core/`. The
implementer confirms this by re-running that grep before editing and comparing against the
enumerated task list above; a different count means the territory moved and the extra or missing
site must be handled explicitly rather than silently skipped.

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's ten paths runs in full the narrowed battery its resolver selects for them, which is every suite reading the seed list, the dispatch-file template, or the index entry this phase edits.

**Files to modify**:

- `agent-system/extensions/core/context/formats/issue-log.md` - 18th gloss row, canonical-spelling statement, heading and four count restatements
- `agent-system/extensions/core/scripts/issue-record.sh` - `ISSUE_SEED_CLASSES` array entry, comment copy, header, warning text
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - `SEED_CLASSES_JSON` entry, header, comment
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - injected dispatch-file text
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - assertion message text
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - count restatement
- `agent-system/extensions/core/context/contracts/phase-closure.md` - count restatement
- `agent-system/extensions/core/context/standards/error-recovery-strategies.md` - count restatement
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - count restatement
- `agent-system/extensions/core/index-entries.json` - `issue-log.md` entry summary string (the deployed `.claude/context/index.json` this file feeds is regenerated by Phase 6's deploy, not by hand)

**Verification**:

- `grep -rn "17-class\|17 classes\|17 class" agent-system/extensions/core/` returns nothing.
- `bash -n` passes on all three edited shell scripts.
- `jq -e . <<< "$SEED_CLASSES_JSON"` equivalent: the aggregator's seed literal still parses as a
  JSON array of 18 strings.
- `jq -e . agent-system/extensions/core/index-entries.json` parses.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh <the ten paths above>` is green.

---

### Phase 2: Grouping-time normalization and the alias-table mechanism [COMPLETED]

**Goal**: `COVERAGE_GAP` and `coverage-gap` group into one proposal, the merge is visible in the
output, the unknown-class tally reads post-fold, and no write path is touched.

**Tasks**:

- [x] Re-read `scripts/orchestrate-conclusion-aggregate.sh` immediately before editing (sibling
      task 567 is live in this tree, with a disjoint scope, but the re-read is the territory
      contract's requirement regardless). *(completed)*
- [x] Add, inside the existing `jq -s` filter: `def fold_class: ascii_downcase | gsub("[-_\\s]+"; " ") | gsub("^ +| +$"; "");`
      and `def canon_class($aliases): fold_class as $f | ($aliases[$f] // $f);` *(completed)*
- [x] Add a bash `CLASS_ALIASES_JSON='{}'` literal with a comment giving its shape
      (`{"<folded-variant>": "<folded-canonical>"}`), stating that it is deliberately empty, and
      naming what adding an entry means; pass it in with `--argjson class_aliases`. *(completed)*
- [x] Change `group_by(.class)` to group on the canonical value. *(completed)*
- [x] Set each proposal's `class` to the **most frequent raw spelling** within its group, with the
      lexicographically smallest raw spelling as the deterministic tie-break. Never a synthesized
      or folded string. *(completed)*
- [x] Add `class_variants` to each proposal: the sorted unique set of raw spellings in the group,
      so a merge is auditable from the output alone. *(completed)*
- [x] Re-key `unknown_classes`: compare each entry's canonical value against the canonical values
      of the seed list, group by canonical value, keep `class` as a raw representative chosen the
      same way, and add the same `variants` set. Add no drop path of any kind — an entry that
      canonicalizes to something unrecognized must still produce a row. *(completed)*
- [x] Add an explicit comment at the fold definition recording the HARD CONSTRAINT: this is a
      read-time transformation inside one jq filter; no `issues.jsonl` is ever rewritten. *(completed)*
- [x] Add the reciprocal SHARED FRAGILITY comment naming `issue-record.sh`'s bash twin (Phase 4). *(completed)*
- [x] Update the script's usage header to document the grouping-time normalization and the alias
      table, then re-check and update `usage()`'s `sed -n '2,46p'` line range to match the header's
      new extent. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` selects `test-orchestrate-conclusion-aggregate.sh`, `test-orchestrate-conclusion-roadmap.sh` and `test-orchestrate-suggest-next-batch.sh`, which together exercise every consumer of the grouping output this phase changes.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - fold/canon jq defs, empty alias literal, `group_by` key, representative-class selection, `class_variants`, re-keyed `unknown_classes`, usage header and its `sed` range

**Verification**:

- A direct fold-vector check: feed `COVERAGE_GAP`, `coverage-gap`, `coverage_gap`, `coverage gap`,
  `Scope_Excursion`, `scope excursion`, `scope omission`, `design-gap`, `design-ambiguity` through
  the `fold_class` definition with `jq -n`, and confirm the first four collapse to one value, the
  next two collapse to one value, and `scope omission`, `design-gap`, `design-ambiguity` each
  remain distinct.
- `bash -n` passes.
- `usage()`'s printed output ends at the intended last header line.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` is green (15 existing cases still pass).

---

### Phase 3: Reject repeated `--tasks`, and record the flag audit [COMPLETED]

**Goal**: A repeated `--tasks` flag exits non-zero with a usage error naming the correct form, and
the script's header records the audit result for every other flag.

**Tasks**:

- [x] Re-run `grep -rn -- "--tasks" agent-system/` and confirm the only non-self call site is
      `context/contracts/conclusion-stage.md`'s single-string form, before landing the rejection. *(completed)*
- [x] Add a `tasks_seen` counter to the argument loop; on a second `--tasks` occurrence, write to
      stderr an error that names both what went wrong and the correct single space-separated form
      (`--tasks "N N N"`), print the usage, and `exit 1`. Nothing is emitted on stdout.
      *(completed: usage() prints to stdout, matching every existing error path in this script;
      "nothing on stdout" is satisfied in its operative sense -- no JSON, never `proposals: []` --
      confirmed by manual scratch invocation; see progress file deviation 3.2)*
- [x] Apply the same treatment to a second mode-selecting flag (`--aggregate`,
      `--record-approval`, `--check-approval`), honoring the "exactly one of ... is required"
      promise the script's own error message already makes (D4). *(completed)*
- [x] Document in the usage header: repeated `--tasks` is rejected; the correct form is a single
      space-separated string; `--session`, `--channel` and `--answer` are scalar selectors where
      last-occurrence-wins is the ordinary convention and is left as-is; no other list-valued flag
      exists in this script. *(completed)*
- [x] Re-check and update `usage()`'s `sed` line range for the header's new extent. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` runs in full the narrowed battery its resolver selects for that script, which covers every flag path this phase touches; the rejection's own regression case lands in Phase 5.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` - `tasks_seen` and mode-flag repetition guards, usage header audit note, `usage()` `sed` range

**Verification**:

- A manual scratch invocation with `--tasks 1 --tasks 2` exits non-zero, prints an error naming
  `--tasks "N N N"`, and prints no JSON on stdout.
- A manual scratch invocation with the correct single-string form still succeeds and is unchanged.
- `bash -n` passes.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` is green.

---

### Phase 4: The `class` shape convention and the append-time warnings [COMPLETED]

**Goal**: An author writing a sentence into `class`, or a non-canonical spelling of a seed class,
is told so at append time; the convention and the promotion procedure are written down.

**Tasks**:

- [x] Add a bash `issue_fold_class()` helper to `scripts/issue-record.sh` mirroring the jq
      `fold_class` of Phase 2 (lowercase, collapse `-`/`_`/whitespace runs to a single space,
      trim), with a SHARED FRAGILITY comment naming the jq twin and stating that a change to
      either requires a matching change to the other. *(completed)*
- [x] Make the seed-membership test fold both sides. When the folded value matches a seed class
      but the raw value differs from the canonical spelling, emit a warning naming the canonical
      spelling, then append. *(completed)*
- [x] When no folded value matches, keep the existing outside-the-seed-enum warning and extend its
      text to point at `issue-log.md`'s class-shape convention. **This is the warning that
      discharges 1d** — it fires on all three of the dispatch's named examples. *(completed)*
- [x] Add the token-count check: after folding, count whitespace-separated tokens; above 6, emit an
      additional style warning naming the convention. Never refuse; always append. *(completed)*
- [x] `context/formats/issue-log.md`: add a "Class Value Shape" paragraph — `class` is a short noun
      phrase (roughly 2-5 words) naming a *category* of failure or success; a finding, a
      conclusion, or a narrated sentence belongs in `what_happened`, never in `class`, because a
      sentence cannot group. Include the three dispatch examples as counter-examples with the
      category each should have carried. *(completed)*
- [x] `context/formats/issue-log.md`: add a "Promoting a Class" subsection naming the three
      list-holding files (`issue-log.md`, `issue-record.sh`, `orchestrate-conclusion-aggregate.sh`)
      plus the `grep -rn "N-class"` self-check for the prose restatements, so the next promotion
      does not have to rediscover the file set by hand. *(completed)*
- [x] Confirm the open-enum posture is intact: no path added here refuses a call. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/issue-record.sh agent-system/extensions/core/context/formats/issue-log.md` runs in full the narrowed battery its resolver selects for those paths, which is every suite that invokes `issue-record.sh` and so exercises the warning path this phase changes.

**Files to modify**:

- `agent-system/extensions/core/scripts/issue-record.sh` - `issue_fold_class()` helper, fold-aware seed membership, canonical-spelling warning, extended outside-the-enum warning, token-count style warning
- `agent-system/extensions/core/context/formats/issue-log.md` - "Class Value Shape" convention paragraph, "Promoting a Class" subsection

**Verification**:

- Each of `research-confirmed-hypothesis`, `reuse-not-reimplement confirmed by direct source read`
  and `reuse_of_existing_machinery`, passed as `--class` to a scratch invocation, produces a
  stderr warning naming the class-shape convention **and** still appends its line.
- `Scope_Excursion` produces a warning naming the canonical `scope excursion` and still appends.
- `scope excursion` itself produces no warning at all.
- `bash -n` passes.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/issue-record.sh agent-system/extensions/core/context/formats/issue-log.md` is green.

---

### Phase 5: Regression cases [COMPLETED]

**Goal**: Every case the dispatch's VERIFICATION section names has a mechanical home, and each one
fails if its behavior regresses.

**Tasks**:

- [x] `test-orchestrate-conclusion-aggregate.sh`, case (o): one task's log records `COVERAGE_GAP`
      and another's records `coverage-gap`; assert exactly **one** proposal results, carrying two
      citations, with `class_variants` listing both raw spellings. (Dispatch requirement a.) *(completed)*
- [x] Case (p): a repeated-`--tasks` invocation exits non-zero, its stderr names the single-string
      form, and its stdout contains no JSON — specifically never a `proposals: []` document.
      (Dispatch requirement b.) *(completed)*
- [x] Case (q): an entry classed `scope excursion` produces no row in `unknown_classes[]`.
      (Dispatch requirement c.) *(completed)*
- [x] Case (r): capture a checksum of every fixture `issues.jsonl` before an aggregate run and
      again after; assert byte-identity. (Dispatch requirement d, the HARD CONSTRAINT.) *(completed)*
- [x] Case (s): an entry whose class is outside the seed enum under any folding still appears in
      both `proposals[]` and `unknown_classes[]`; and two folding-equivalent spellings of that same
      unrecognized class produce exactly one `unknown_classes[]` row, not two. (Dispatch
      requirement e, in both directions — never dropped, never double-counted.) *(completed)*
- [x] Case (t): the five scope spellings from the dispatch's evidence do **not** all collapse —
      assert that `scope excursion` and `scope omission` remain separate proposals, pinning D1's
      line against a future over-eager normalizer. *(completed)*
- [x] `test-issue-record.sh`: add cases asserting (i) each of the three free-text examples warns
      and still appends; (ii) `Scope_Excursion` warns naming the canonical spelling and still
      appends; (iii) a >6-token class emits the style warning and still appends; (iv) a canonical
      `scope excursion` warns not at all. *(completed)*
- [x] Follow each suite's existing structural conventions (`common_test_pass`/`common_test_fail`,
      `build_scratch`, `write_entry`, sequential case letters) rather than introducing new helpers. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Tier Justification**: `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/verify-touched.sh` over the two edited test files and their two subjects runs in full the narrowed battery its resolver selects for them, which includes both suites this phase adds cases to.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` - cases (o) through (t)
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` - four `class`-validation cases

**Verification**:

- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` exits 0 with the 15 baseline cases plus 6 new ones all passing.
- `CORE_TEST_SUBJECT_MODE=source-store bash agent-system/extensions/core/scripts/tests/test-issue-record.sh` exits 0 with its baseline cases plus 4 new ones all passing.
- Each new case is confirmed to actually fail when its behavior is reverted — a case that cannot
  fail is a vacuous pass and does not count as coverage.

---

### Phase 6: Redeploy and close [NOT STARTED]

**Goal**: The deployed `.claude/` tree carries every change, the suites prove it against the
deployed copy rather than the source store, and the full gate obligation is discharged.

**Tasks**:

- [ ] Run `timeout 540 bash agent-system/extensions/core/scripts/deploy-headless.sh` with the Bash
      tool timeout raised to 600000, and confirm `RESULT=landed_verify_clean`.
- [ ] Re-run both regression suites **with no `CORE_TEST_SUBJECT_MODE` set**, so they resolve the
      deployed copies. This is the check that distinguishes every earlier phase's green from a
      vacuous pass on a stale deploy.
- [ ] Confirm `grep -rn "17-class\|17 classes\|17 class"` returns nothing under either
      `agent-system/**` or `.claude/**`.
- [ ] Confirm `.claude/context/index.json` carries the regenerated `issue-log.md` summary.
- [ ] Run the scoped touched-path check over this task's own paths:
      `bash .claude/scripts/verify-touched.sh <every path in this plan>`.
- [ ] Defer the complete gate set to the orchestration close (Move 4) rather than invoking the full
      battery independently here.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire deployed `.claude/` tree

This phase makes no new source-store edits of its own; it redeploys and verifies what Phases 1-5
landed. No real wide path is declared here, deliberately — the reserved `__WHOLE_TREE__` sentinel
is what serializes this phase against a concurrent whole-tree regeneration, and substituting a
real directory path would instead trip the coarse-declaration lint and loosen every downstream
containment check against this task's `file_scope`.

**Verification**:

- `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- Both suites exit 0 in default deploy-tree-first mode.
- The `17-class` grep is empty across both trees.
- `bash .claude/scripts/verify-touched.sh <this plan's paths>` is green, with the complete gate set
  explicitly deferred to the orchestration close.

## Testing & Validation

- [ ] (a) `COVERAGE_GAP` in one task's log and `coverage-gap` in another's group into ONE proposal.
- [ ] (b) A repeated-`--tasks` call exits non-zero with a usage error and never a silent empty
      result.
- [ ] (c) The canonical `scope excursion` spelling validates against the seed enum.
- [ ] (d) Stored `class` values in fixture `issues.jsonl` files are byte-identical before and after
      an aggregate run.
- [ ] (e) An unrecognized class still appears in the output rather than being dropped, and folding
      equivalents of it do not double-count.
- [ ] All three of the dispatch's free-text `class` examples produce an append-time warning naming
      the class-shape convention, and all three are still appended.
- [ ] `scope excursion` and `scope omission` remain separate proposals — the normalizer does not
      over-merge.
- [ ] No `17-class` restatement survives anywhere in either tree.
- [ ] Both suites are green against the **deployed** copies after the redeploy.

## Artifacts & Outputs

- An 18-class seed enum, canonical spelling stated, consistent across all ten files that reference
  it.
- Grouping-time case-and-separator folding in the aggregator, with `class_variants[]` making every
  merge auditable from the output.
- An empty, documented semantic alias table and a post-fold unknown-class tally.
- A `class` shape convention in `issue-log.md`, a "Promoting a Class" procedure, and append-time
  warnings in `issue-record.sh` covering both the free-text and non-canonical-spelling cases.
- A loud rejection of repeated `--tasks` (and of a repeated mode flag), with the flag audit
  recorded in the script's usage header.
- Ten new regression cases across two suites.

## Rollback/Contingency

Every phase commits separately except Phase 1, which commits as one atomic batch because a partial
seed-enum sweep leaves the tree internally inconsistent (prose claiming one size, lists carrying
another). Reverting any phase is a `git revert` of its own commit followed by a redeploy.

Two contingencies worth naming:

- **If a new regression case cannot be made to fail when its behavior is reverted**, the case is
  not coverage and must be rewritten rather than accepted green.
- **If the deploy does not reach `RESULT=landed_verify_clean`**, the source-store edits stay as
  they are and the failure is reported; the deployed tree is a regenerable artifact, so a failed
  deploy is never repaired by hand-editing under `.claude/**`.
