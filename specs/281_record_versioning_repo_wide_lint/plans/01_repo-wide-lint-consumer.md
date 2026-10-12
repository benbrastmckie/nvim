# Implementation Plan: Repo-Wide Lint Consumer for Record-Versioning

- **Task**: 281 - Build the repo-wide lint consumer for the record-versioning rule
- **Status**: [IMPLEMENTING]
- **Effort**: 9 hours
- **Dependencies**: rule/taxonomy/library task (complete; `scripts/lib/record-version-patterns.sh` and `scripts/tests/test-record-version-patterns.sh` both exist and pass)
- **Research Inputs**: specs/281_record_versioning_repo_wide_lint/reports/01_repo-wide-lint-consumer-research.md
- **Artifacts**: plans/01_repo-wide-lint-consumer.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `scripts/check-record-versioning.sh` (the repo-wide lint consumer for
`rules/no-record-versioning-in-deliverables.md`) and its fixture test, modeled on the
`check-task-references.sh`/`test-check-task-references.sh` pair, with the one genuinely new
design surface being the BLOCKING/ADVISORY tier split (only BLOCKING affects the exit code).
The research phase established — and this plan re-derived independently at authoring time — that
the consumer script alone cannot meet the acceptance bar: the shared pattern library's
heading-form discriminator floods on `#`-comment lines in shell scripts, so the plan budgets
three library-fix phases ahead of the acceptance check rather than discovering the flood at
verification time. Definition of done: both deliverables exist, shellcheck clean, manifest and
inventory wired, the fixture test exercises all four required behaviors, and a no-argument run
against `/home/benjamin/Projects/Logos/Verification` exits 0.

**SOURCE STORE IS THE EDIT TARGET.** Every path in this plan is relative to
`/home/benjamin/.config/nvim/agent-system/extensions/core` (resolved from
`.claude-extensions.json`'s `source_dir` for the `core` extension) unless stated otherwise.
Never hand-author under `.claude/**` — it is a disposable deploy artifact
(`rules/source-store-deploy-boundary.md`).

### Research Integration

Findings carried in and acted on:

- The library and its fixture suite are complete and match `record-version-exemptions.md`; this
  task defines **no patterns, exemptions, or tiers of its own** — it consumes
  `RV_BLOCKING_ERE`/`RV_ADVISORY_ERE`/`is_exempt_path`/`strip_durable_axis_lines`/
  `strip_exempt_regions` and, after Phase 1, the path-aware matching functions layered over them.
- `check-task-references.sh` is a direct, line-for-line template: `git ls-files` enumeration,
  exit codes 0/1/2, `--quiet`, optional positional `PATH_SCOPE` with `[SKIP]`-and-exit-0 on a
  nonexistent scope, `REPO_ROOT=$(pwd)` source-store override, `LIB_CANDIDATES` two-candidate
  array, `set -uo pipefail` (Class B per `shell-strict-mode.md`), no hard-coded directory list.
- Its test is an equally direct template, **minus Case 8** (lint/hook scope agreement):
  `hooks/validate-no-record-versioning.sh` does not exist and is out of scope, so there is no
  hook to agree with. Drop that case rather than inventing one.
- The two-tier reporting precedent is `typst-element-lint.sh`/`chapter-quality-check.sh`: two
  running counters, per-finding tier label, a Summary block printing both counts, exit code
  driven by the BLOCKING counter only, and a "PASSED WITH WARNINGS (N advisory findings)"-shaped
  message for the advisory-only case.
- The library pipeline order is `strip_durable_axis_lines` **then** `strip_exempt_regions` then
  the grep — one difference from the sibling, per the library's own documented Usage ordering.
- `docs/reference/utility-scripts-inventory.md` has **no** `check-task-references.sh` entry to
  copy; write a fresh bullet in that file's established style.
- `docs/setup-without-nix.md` does not exist in the Verification repo. Re-confirmed at this
  plan's authoring against that repo's current HEAD (`3ce21a60`; the research report measured
  `272d0d26`, so the repo has moved on and the claim still holds). Treat the three files that do
  exist as the binding part of that sub-claim.

Independently re-derived at plan-authoring time (not carried): the dry-run harness was re-run
against both repos using the live library. This repo: **251 BLOCKING across 45 files, 731
ADVISORY**. Verification repo: **213 BLOCKING across 44 files, 757 ADVISORY**. The research
report's 44-file figure for this repo is now 45; every other figure reproduced exactly.
`docs/ci.md`, `docs/consuming.md`, and `docs/stability-and-versioning-policy.md` each produce 0
BLOCKING findings, confirming that sub-claim holds.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included and ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:

- `scripts/check-record-versioning.sh`: repo-wide, `git ls-files`-driven, library-driven lint with
  BLOCKING/ADVISORY tier reporting and exit codes 0/1/2.
- `scripts/tests/test-check-record-versioning.sh`: fixture test exercising clean tree, blocking
  finding, advisory finding that does **not** change the exit code, and marker-exempted content.
- Narrow the library's heading-form discriminator so the lint is usable repo-wide rather than only
  over the `docs/`/`README.md`/`books/`/`records/` corpus it was calibrated against.
- A no-argument run against the Verification repo exits 0, achieved by fixing the discriminator
  and the corpus — never by relaxing a pattern to make it green.
- Wiring: `manifest.json` (`provides.scripts` + tests list) and
  `docs/reference/utility-scripts-inventory.md`.

**Non-Goals**:

- `hooks/validate-no-record-versioning.sh` (the write-time guard). Not built here; the fixture
  test therefore carries no lint/hook scope-agreement case.
- A `contracts/no-record-versioning-bullet.md` agent-frontmatter coverage contract (the
  task-reference pair's analogue). Recorded by the research phase for the future hook task.
- De-versioning this repo's own Neovim-plugin documentation
  (`lua/neotex/plugins/tools/himalaya/docs/ARCHITECTURE_V2.md`, `ARCHITECTURE_V3.md`,
  `DRAFT_SYSTEM_V2.md`) or the web extension's Tailwind headings. These are this-repo-only, are
  absent from the Verification repo, and so sit outside the stated acceptance bar. Phase 8
  enumerates them as a flagged follow-up.
- Fixing `check-task-references.sh`'s identical latent line-number drift (see Phase 1). Noted for
  awareness only; the sibling is not in this task's file scope.
- Any edit under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Narrowing the heading branch too aggressively drops a real positive (the existing `"## The widget convention (v2)"` assertion, or the himalaya-style version-labeled H1 title) | H | M | Phase 2's tasks name both shapes as assertions that MUST pass; the phase is not closeable while any existing assertion in `test-record-version-patterns.sh` regresses |
| Narrowing too timidly leaves the markdown-heading false positives (external-tool and numbered-ruling idioms) in place, and the acceptance run stays red | M | M | Phase 2 is judged against BOTH failure classes (code-comment conflation AND non-self-referential markdown headings), with a measured residue target, not against the `.sh` symptom that dominates the raw count |
| Temptation to relax a pattern, or to re-filter results inside the consumer script, to force exit 0 | H | M | Explicitly forbidden by the dispatch. All discrimination lives in the library (Phases 1-3); the consumer calls library functions and classifies nothing. Phase 8 requires the residue to be dispositioned by cause, not suppressed |
| The numbered-ruling heading idiom (`(v6 Ruling)`, `post-v5`) is a genuine judgment call the rule owner must settle | M | H | Phase 8 raises a NON-BLOCKING `user_decision` with a stated default (de-version the two lines in place) and proceeds under it rather than stalling |
| A sibling task edits a shared file mid-dispatch (task 318 holds `verify-deploy.sh`, its context-budget test, and `git-staging-scope.md`) | M | L | No overlap with this plan's file set. Per the territory contract: re-read every file immediately before editing, stage only this task's own hunks with an explicit file list, never `git-snapshot.sh` in reverting mode |
| A full-suite run shows exactly one failure in `test-four-tier-conflict.sh` Case 6 | L | M | Known pre-existing flake: a `[1000ms,2000ms)` timing assertion measuring ~2.3-2.8s under concurrent load. Attribute it and move on; do NOT investigate |
| The completion-deploy gate refuses to mark the task completed while the deployed `core` tree is stale | L | H | Expected. It resolves at the next cycle's redeploy checkpoint. Do not plan or attempt a manual workaround |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3, 6 | 2 (for 3), 5 (for 6) |
| 4 | 4, 7 | 3 (for 4), 5 and 6 (for 7) |
| 5 | 8 | 2, 3, 4, 6, 7 |

Phases within the same wave can execute in parallel.

---

### THE BOUNDED-WAIT IDIOM (applies to every step below that says so)

Every step that runs `run-all.sh`, `verify-deploy.sh`, `deploy-headless.sh`, or a repo-wide
`grep`/`git ls-files` sweep MUST be issued exactly this way. The idiom is written out inline in
each such step; this block is the rationale, not a substitute for the inline text.

- Set the **Bash tool's own `timeout` parameter to `600000`**. Its default is `120000` ms, and a
  call that runs longer is auto-backgrounded, which strands the dispatch.
- ALSO wrap the command in an inner shell `timeout 540`, redirect all output to a log file, echo
  the exit status, and read results back out of the log with `grep`.
- NEVER use `run_in_background`. NEVER arm a Monitor. NEVER await a harness notification.

This has stranded six dispatches in this repo today, including the orchestrator's own redeploy
checkpoint. It is a hard requirement, not advice.

Logs go under the implement dispatch's own scratchpad directory; `/tmp/rv-lint-*.log` is an
acceptable fallback if no scratchpad path is available.

---

### Phase 1: Library matching core — line-number fidelity and a path-aware matching API [COMPLETED]

**Goal**: Give `scripts/lib/record-version-patterns.sh` two things the consumer needs before it
can report honestly, with **zero change to any detection pattern**: strip functions that preserve
line numbering, and a path-aware matching API so the consumer never chooses an ERE, a case
sensitivity, or a path class for itself.

**Tasks**:

- [x] Re-read `scripts/lib/record-version-patterns.sh` and
      `scripts/tests/test-record-version-patterns.sh` immediately before editing (concurrent
      siblings are live on this tree).
- [x] Change `strip_durable_axis_lines` and `strip_exempt_regions` from **deleting** a stripped
      line to **blanking** it (emit an empty line in its place). Rationale, confirmed by direct
      measurement at plan-authoring time: both functions currently drop lines, so a downstream
      `grep -n` reports **post-strip** line numbers. Measured drift — a finding in
      `scripts/tests/test-git-commit-scoped.sh` reported at line 610 is really at line 611, and
      one in `extensions/lean/scripts/tests/test-lean-comparator-run.sh` reported at 549 is
      really at 550. Blanking is match-neutral (an empty line matches no BLOCKING or ADVISORY
      pattern) and restores one-to-one line correspondence. `strip_exempt_regions`'s awk
      `next` branches become `{ print "" ; next }`.
- [x] Add `rv_is_markdown_path <path>` — returns 0 for `*.md`/`*.markdown`, 1 otherwise. The
      single place the markdown/non-markdown path class is decided.
- [x] Add `rv_grep_blocking <path>` and `rv_grep_advisory <path>`: each reads already-stripped
      content on stdin and writes `LINENO:line` findings on stdout, encapsulating the ERE choice,
      the path class, and the `-i`/case-sensitivity decision. In THIS phase both simply wrap the
      existing `grep -nEi "$RV_BLOCKING_ERE"` / `grep -nEi "$RV_ADVISORY_ERE"` behavior with no
      pattern or case change — the functions are the seam Phase 2 narrows behind.
- [x] Keep `RV_BLOCKING_ERE`/`RV_ADVISORY_ERE` and every sub-pattern variable exported unchanged.
      This is purely additive: the existing fixture suite consumes the variables directly and must
      keep passing untouched.
- [x] Update the library header's numbered Usage block to document the new call order
      (`is_exempt_path` -> `strip_durable_axis_lines` -> `strip_exempt_regions` ->
      `rv_grep_blocking`/`rv_grep_advisory <path>`), and record that both consumers call the
      functions rather than matching the EREs by hand.
- [x] Add fixture assertions to `scripts/tests/test-record-version-patterns.sh`: (a) a
      blank-preservation case proving a stripped line keeps its position so a later line's
      reported number equals its real number; (b) `rv_is_markdown_path` true/false cases; (c)
      `rv_grep_blocking`/`rv_grep_advisory` returning the same verdicts as the direct-ERE
      assertions already in the file.
- [x] Lint both touched files through the repository's sanctioned shellcheck entry point,
      `bash scripts/lint/lint-shellcheck.sh --verbose <paths>` (never the bare `shellcheck`
      binary), per `context/standards/shell-strict-mode.md`, and check its exit status.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The line-number drift is asserted as real on the strength of two measured
instances (610 vs. 611; 549 vs. 550) re-derived at plan-authoring time. Confirm at implementation
time by reproducing both before the change and showing both report their real line numbers after
it; if the drift does not reproduce, drop the blanking sub-step and record why rather than
changing the functions on this plan's word.

**Files to modify**:
- `scripts/lib/record-version-patterns.sh` - blank-instead-of-delete in both strip functions; add `rv_is_markdown_path`, `rv_grep_blocking`, `rv_grep_advisory`; update the Usage header
- `scripts/tests/test-record-version-patterns.sh` - add blank-preservation, path-class, and matching-function assertions

**Tier Justification**: The covering check is
`timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh`,
the suite `suite-selection-lib.sh` resolves for both touched paths; nothing outside this library
and its own suite is reachable from a purely additive change that leaves every exported pattern
byte-identical.

**Verification**:
- Bounded-wait idiom, mandatory: set the Bash tool's own `timeout` parameter to `600000` (its
  `120000` default auto-backgrounds the call and strands the dispatch), and run
  `timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh > "$LOG" 2>&1; echo "exit=$?"`,
  then read results back with `grep -nE '\[FAIL\]|\[PASS\]|Results:' "$LOG" | tail -40`. No
  `run_in_background`, no Monitor, no harness notification.
- Every pre-existing assertion in `test-record-version-patterns.sh` still passes; FAILED count is 0.
- `bash scripts/lint/lint-shellcheck.sh --verbose <both touched paths>` exits 0.

---

### Phase 2: Narrow the heading-form discriminator [COMPLETED]

**Goal**: Eliminate the false-positive flood behind the acceptance bar — `RV_PAGE_LABEL_ERE`'s
heading branch (`^#{1,6}[[:space:]].*\bv[0-9]+\b`) firing on any line that merely starts with
1-6 `#` characters and contains a `vN` token anywhere later — without losing a single real
positive.

**Tasks**:

- [x] Re-read both files immediately before editing.
- [x] Apply **two** discriminators behind Phase 1's `rv_grep_*` seam. Neither alone is
      sufficient; this is the explicit judgment the research phase left to the plan:
      - **(i) Path-class gating.** The heading branch applies only when
        `rv_is_markdown_path` is true. A `#`-prefixed line in a `.sh`/`.yml`/`.toml`/`.gitignore`
        file is a comment, not an ATX heading. Measured effect: of this repo's 251 BLOCKING
        findings, 218 are in `.sh` files and 1 in `.gitignore`; of Verification's 213, 197 are
        `.sh`, 4 `.yml`, 2 `.toml`.
      - **(ii) Label-position narrowing inside markdown.** Replace the single
        "any heading, `vN` anywhere" branch with two narrower sub-branches:
        a **bare-parenthesized** form `^#{1,6}[[:space:]].*\(v[0-9]+\)` at any heading level, and
        a **page-title** form `^#[[:space:]].*\bv[0-9]+\b` restricted to H1. The
        `^\*\*Status\*\*:` branch is unchanged and stays path-class-agnostic.
- [x] Also narrow the **case sensitivity** of the non-heading branches for non-markdown paths.
      Measured residue cause: the `V<N>` uppercase internal-invariant-label convention
      (`Case V5's assertion`, `the V8 mismatch predicate`, `--task flag (V5 contended-path
      lease) and used to resolve`) collides with `RV_PAST_TENSE_ESCALATION_ERE`'s `\bv[0-9]+\b`
      adjacency under `grep -i`. Record-version tokens are lowercase by universal convention in
      this corpus; the three uppercase true positives are all markdown H1 titles, caught by
      sub-branch (ii) which stays case-insensitive. Preferred mechanism: `rv_grep_blocking`
      runs the escalation/supersession/migration/attribution group **case-sensitively** for a
      non-markdown path and case-insensitively for markdown. Acceptable fallback if that proves
      unworkable under test: gate the escalation branch itself to markdown paths. Whichever is
      chosen, re-run the corpus probe and record the measured effect — do not reason about it.
- [x] Preserve every existing assertion, naming these two explicitly as must-pass:
      `assert_blocking "page-level label, heading form" "## The widget convention (v2)"` (an H2
      with a bare-parenthesized token — this is why sub-branch (i) alone, restricted to H1, is
      wrong) and every `assert_not_blocking` real-negative case.
- [x] Add fixture assertions for the newly-discriminated shapes, as true negatives:
      `### Tailwind v4 Optimizations` (external-tool version in a non-H1 heading);
      `## Admission Posture for an Absent file_scope (v6 Ruling)` (parenthesized-with-noun,
      the numbered-ruling idiom); `# V3 safety gate` presented as a non-markdown path (shell
      comment); `Case V5's assertion is not vacuous` as a non-markdown path. And as true
      positives: `# Himalaya Plugin Architecture V2: Elegant Module Distribution` and
      `# Draft System v2 Documentation` (markdown H1 page-title labels — confirmed real,
      un-swept instances).
- [x] Lint both files through `bash scripts/lint/lint-shellcheck.sh --verbose <paths>` and check
      its exit status.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis, measured at plan-authoring time with a candidate implementation
of discriminators (i) and (ii) run over both corpora: BLOCKING drops from **251 to 27** in this
repo and from **213 to 19** in the Verification repo, and every residue line falls into one of
four named classes (self-referential rule/taxonomy/fixture files; bare tool-or-schema major
versions; the numbered-ruling idiom; uppercase `V<N>` invariant labels in `.sh` comments).
Confirm at implementation time by re-running the probe after the change and comparing the
residue line-for-line against those classes; a residue outside all four classes means the
discriminator is wrong, not that the class list needs widening.

**Files to modify**:
- `scripts/lib/record-version-patterns.sh` - split `RV_PAGE_LABEL_ERE`'s heading branch into the bare-parenthesized and H1-page-title sub-branches; path-class-gate it and the case sensitivity of the non-heading group inside `rv_grep_blocking`; update the pattern-block comments to state what each sub-branch does and does NOT match
- `scripts/tests/test-record-version-patterns.sh` - add the new true-negative and true-positive assertions above

**Tier Justification**: The covering check is
`run-all.sh --only test-record-version-patterns.sh`, the suite that owns both touched paths and
that encodes every calibrated positive and negative this narrowing must not regress; no consumer
of these patterns exists on disk yet (the hook is unbuilt and the lint lands in Phase 5), so
there is no cross-file surface a wider tier would reach.

**Verification**:
- Bounded-wait idiom, mandatory: Bash tool `timeout` parameter `600000` (the `120000` default
  auto-backgrounds and strands the dispatch), plus
  `timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh > "$LOG" 2>&1; echo "exit=$?"`,
  read back with `grep -nE '\[FAIL\]|Results:' "$LOG" | tail -40`. No `run_in_background`, no
  Monitor, no harness notification.
- FAILED count is 0, and the PASSED count is strictly greater than before this phase.
- Bounded-wait idiom, mandatory, for the corpus probe (a repo-wide sweep): Bash tool `timeout`
  parameter `600000`, and
  `timeout 540 bash <probe> /home/benjamin/.config/nvim > "$LOG1" 2>&1; echo "exit=$?"` then
  `timeout 540 bash <probe> /home/benjamin/Projects/Logos/Verification > "$LOG2" 2>&1; echo "exit=$?"`,
  read back with `grep -nE 'BLOCKING' "$LOG1" "$LOG2"`. The probe sources the live library and
  reproduces the consumer pipeline; it is a throwaway under the scratchpad, never committed.
- Residue decomposes entirely into the four named classes.

---

### Phase 3: Extend the durable-axis exemption to bare major-version mentions [COMPLETED]

**Goal**: Close the second, narrower library gap: `strip_durable_axis_lines` recognizes dotted
semver, `@vN` pins, hyphenated CI cache-key segments, and backtick/filename-anchored schema
identifiers, but not a **bare** `vN` naming a real external tool's or a schema's own major
version. These are durable-axis uses by the taxonomy's stated intent (axes a and b) that are not
mechanically recognized today.

**Tasks**:

- [x] Re-read both files immediately before editing.
- [x] Add durable-axis shapes covering the measured residue: a schema/format-anchored form
      (`Global Index Schema (v2)`, `missing required v2 fields` — a `schema`/`format` noun within
      a short span of a bare `vN`) and a named-external-tool form (`Tailwind CSS v4`). Keep each
      shape anchored to a concrete noun or a capitalized proper-noun run; do **not** add a bare
      `\bv[0-9]+\b` catch-all, which would gut the whole BLOCKING tier.
- [x] Verify the taxonomy's own motivating true positive is unaffected: `## The widget convention
      (v2)` has no schema/format/tool anchor and must stay BLOCKING.
- [x] Add fixture assertions: `## Global Index Schema (v2)` and `# Tailwind CSS v4 Reference` as
      true negatives; `## The widget convention (v2)` re-asserted as a true positive.
- [x] Update `context/standards/record-version-exemptions.md`'s durable-axis description to name
      the two newly-mechanical shapes, so the standard and the library do not drift.
- [x] Lint the library through `bash scripts/lint/lint-shellcheck.sh --verbose <paths>` and check
      its exit status.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase is hypothesized to clear 6 residue findings in this repo
(4 Tailwind headings across the `agent-system` and `.opencode` web trees, 2 `Global Index Schema
(v2)` headings in the literature extension) and 1 in the Verification repo
(`.claude/context/project/literature/domain/literature-index.md`). Confirm by re-running the
Phase 2 probe and diffing the residue; a cleared count below that means the anchors are too
narrow, above it means they are too broad and a true positive may have been swallowed.

**Files to modify**:
- `scripts/lib/record-version-patterns.sh` - add the schema/format-anchored and named-tool bare-major-version shapes to `strip_durable_axis_lines`, with a comment stating each shape and its anchor
- `scripts/tests/test-record-version-patterns.sh` - add the new true-negative and re-asserted true-positive cases
- `context/standards/record-version-exemptions.md` - document the two newly-mechanical durable-axis shapes

**Tier Justification**: The covering check is
`run-all.sh --only test-record-version-patterns.sh` for the two script paths, plus the `prose`
row's diff read-through for the standard's markdown edit, which `suite_selection_select` returns
`__FULL_SWEEP__` for (no suite covers a pure-guidance markdown file) — so no suite is claimed
for it.

**Verification**:
- Bounded-wait idiom, mandatory: Bash tool `timeout` parameter `600000` (the `120000` default
  auto-backgrounds and strands the dispatch), plus
  `timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh > "$LOG" 2>&1; echo "exit=$?"`,
  read back with `grep -nE '\[FAIL\]|Results:' "$LOG" | tail -40`. No `run_in_background`, no
  Monitor, no harness notification.
- FAILED count is 0; `## The widget convention (v2)` still asserts BLOCKING.
- The residue diff matches this phase's Scope Hypothesis.

---

### Phase 4: Mark the self-referential rule, taxonomy, and fixture files [COMPLETED]

**Goal**: Three source files necessarily quote the forbidden vocabulary as their own subject
matter and therefore self-flag. Mark them, mirroring exactly the
`task-ref-ok:begin`/`task-ref-ok:end` precedent `test-check-task-references.sh` already
established for the sibling lint.

**Tasks**:

- [x] Re-read each file immediately before editing.
- [x] Wrap the literal fixture strings in `scripts/tests/test-record-version-patterns.sh`'s
      `assert_blocking`/`assert_advisory` calls in `version-ok:begin` / `version-ok:end` pairs,
      each begin marker carrying a trailing reason naming its taxonomy category (the marker
      convention requires a reason on the begin/inline marker; the end marker may be bare).
- [x] Add a header NOTE to that test file explaining why its own source lines must be marked —
      copy the shape of `test-check-task-references.sh`'s equivalent header NOTE.
- [x] Mark the quoted forbidden-vocabulary lines in
      `rules/no-record-versioning-in-deliverables.md`'s Principle paragraph. **This is a
      planning-time discovery the research phase did not surface**: the rule file itself quotes
      `"supersedes v1"`, `"carried forward from v1"`, and `"every v1 field removed"` as its own
      examples, and self-flags on 2 lines.
- [x] Mark the equivalent quoted example in `context/standards/record-version-exemptions.md`
      (1 line — the "How this record relates to v1" supersession-table description).
- [x] Confirm `strip_exempt_regions` still strips correctly after Phase 1's blanking change
      (an inline `version-ok` line and a begin/end block both become blank lines, not deletions).

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis: exactly 3 files and 13 BLOCKING findings in this repo
(10 in `test-record-version-patterns.sh`, 2 in `no-record-versioning-in-deliverables.md`, 1 in
`record-version-exemptions.md`), and 13 correspondingly in the Verification repo's deployed
copies of the same three files. Confirm by re-running the Phase 2 probe after marking and showing
all three files absent from the residue; a surviving finding means a marker is misplaced, not
that the marker convention needs changing.

**Files to modify**:
- `scripts/tests/test-record-version-patterns.sh` - `version-ok:begin`/`end` pairs around every literal fixture string, plus the explanatory header NOTE
- `rules/no-record-versioning-in-deliverables.md` - mark the quoted forbidden-vocabulary examples in the Principle paragraph
- `context/standards/record-version-exemptions.md` - mark the quoted supersession-table example

**Tier Justification**: The covering check is
`run-all.sh --only test-record-version-patterns.sh` for the test file (marker lines must not
disturb a single assertion), plus the `prose` row's diff read-through for the two markdown files,
whose edits are comment-marker insertions only and for which `suite_selection_select` returns
`__FULL_SWEEP__` (no suite covers a pure-guidance markdown file).

**Verification**:
- Bounded-wait idiom, mandatory: Bash tool `timeout` parameter `600000` (the `120000` default
  auto-backgrounds and strands the dispatch), plus
  `timeout 540 bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-record-version-patterns.sh > "$LOG" 2>&1; echo "exit=$?"`,
  read back with `grep -nE '\[FAIL\]|Results:' "$LOG" | tail -40`. No `run_in_background`, no
  Monitor, no harness notification.
- FAILED count is 0 and the PASSED count is unchanged from Phase 3 (markers must not alter a
  single assertion's verdict).
- The three marked files are absent from the Phase 2 probe's residue.

---

### Phase 5: Build `scripts/check-record-versioning.sh` [COMPLETED]

**Goal**: The first deliverable: the repo-wide lint consumer, modeled line-for-line on
`check-task-references.sh`, with the BLOCKING/ADVISORY tier split as its one genuinely new
surface.

**Tasks**:

- [x] Copy `check-task-references.sh`'s structure wholesale and adapt: `set -uo pipefail`
      (Class B per `shell-strict-mode.md` — the script accumulates counts across files and must
      tolerate an individual no-match grep); `--quiet`; optional positional `PATH_SCOPE` with
      trailing slash stripped; `[SKIP]`-and-exit-0 on a nonexistent `PATH_SCOPE`; `-e` (not `-d`)
      existence check so a single-file scope is scanned; `"."` as the default enumeration path;
      `deploy-root-guard.sh` resolution with the `REPO_ROOT=$(pwd)` source-store override;
      exit 2 on an unknown flag or an unexpected extra argument.
- [x] `LIB_CANDIDATES` as a two-candidate array —
      `$REPO_ROOT/.claude/scripts/lib/record-version-patterns.sh` first, then
      `$REPO_ROOT/agent-system/extensions/core/scripts/lib/record-version-patterns.sh` — and
      exit 2 with both paths named when neither resolves. Never fall through to an inline pattern.
- [x] `scan_tree()` enumerating via `git -C "$REPO_ROOT" ls-files "$enum_path"`, skipping
      `is_exempt_path` matches, and piping each surviving file through
      `strip_durable_axis_lines | strip_exempt_regions` — in that order, per the library's
      documented Usage — then through `rv_grep_blocking "$rel"` and `rv_grep_advisory "$rel"`
      separately. **No hard-coded directory list**: the sibling's "Default to Repo-Wide Scope,
      Never a Hard-Coded Directory List" design principle is the reason a consumer repo with any
      layout is scanned in full rather than scanning nothing.
- [x] Two running counters (`TOTAL_BLOCKING`, `TOTAL_ADVISORY`), per the
      `typst-element-lint.sh`/`chapter-quality-check.sh` precedent. Per-finding lines carry their
      tier explicitly — use this rule's own `BLOCKING`/`ADVISORY` vocabulary, not the typst
      scripts' `FAIL`/`WARN` — and preserve the sibling's `^  {path}:{lineno}:` finding shape so
      the output is machine-greppable the same way.
- [x] A Summary block printing BOTH counts unconditionally, and exit codes: `0` when
      `TOTAL_BLOCKING` is 0 (with the advisory count stated in the pass message when it is
      nonzero — the "PASSED WITH WARNINGS (N advisory findings)" shape), `1` when
      `TOTAL_BLOCKING` is nonzero, `2` for environment/usage errors. ADVISORY findings MUST NOT
      affect the exit code.
- [x] Header comment documenting all three exit codes with their distinct meanings, the two-tier
      contract, every usage form, the `REPO_ROOT=$(pwd)` override and why it is required (the
      deployed path does not exist until a deploy runs), and a pointer to
      `record-version-exemptions.md` plus `rules/no-record-versioning-in-deliverables.md` as the
      single source of truth this script consumes and does not duplicate.
- [x] No task-number references anywhere in the file (the deliverable is outside `specs/**`).
- [x] Clean through `bash scripts/lint/lint-shellcheck.sh --verbose scripts/check-record-versioning.sh`
      (the sanctioned entry point, never the bare binary) per
      `context/standards/shell-strict-mode.md`; check its exit status.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesized at roughly 180-200 lines, by proportion to the sibling's 172
lines plus the second counter and the tier-labeled reporting. Confirm with `wc -l` at
implementation time; a figure far outside that range suggests either copied dead weight or a
missing sibling behavior, and the four required behaviors should be re-checked against the
sibling before closing the phase.

**Files to modify**:
- `scripts/check-record-versioning.sh` - new file (the first deliverable)

**Tier Justification**: The covering checks are `bash -n`, `scripts/lint/lint-shellcheck.sh`, and a
`REPO_ROOT=$(pwd)` smoke invocation of the new script against a single known-dirty file and a
single known-clean file; the script is a new leaf with no in-repo caller until Phase 7 wires it,
so no cheaper-tier blind spot is reachable from this edit.

**Verification**:
- `bash -n scripts/check-record-versioning.sh` exits 0, and
  `bash scripts/lint/lint-shellcheck.sh --verbose scripts/check-record-versioning.sh` exits 0.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-record-versioning.sh <a known-dirty file>` reports a tier-labeled finding and exits 1.
- The same invocation against a known-clean file exits 0.
- A nonexistent `PATH_SCOPE` prints `[SKIP]` and exits 0; an unknown flag exits 2.
- Bounded-wait idiom, mandatory, for the no-argument repo-wide run (a repo-wide sweep): Bash tool
  `timeout` parameter `600000` (the `120000` default auto-backgrounds and strands the dispatch),
  plus
  `timeout 540 env REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-record-versioning.sh > "$LOG" 2>&1; echo "exit=$?"`,
  read back with `grep -nE 'BLOCKING|ADVISORY|PASS|FAIL' "$LOG" | tail -40`. No
  `run_in_background`, no Monitor, no harness notification.

---

### Phase 6: Build `scripts/tests/test-check-record-versioning.sh` [NOT STARTED]

**Goal**: The second deliverable: a fixture test modeled on
`test-check-task-references.sh`, exercising all four acceptance behaviors.

**Tasks**:

- [ ] Copy the sibling test's structure: `mktemp -d WORKDIR` with a `trap cleanup EXIT`;
      `git init -q` throwaway fixture; `pass()`/`fail()`/`info()` with `PASSED`/`FAILED` counters
      and the exit-0-on-all-pass / exit-1-on-any-fail / exit-2-on-environment-error convention
      from `context/standards/shell-script-testing.md`; a `run_lint()` helper capturing stdout
      and exit status via a temp file.
- [ ] Build a **consumer-repo-shaped** fixture (`docs/`, `README.md`, a source dir, `.github/`,
      `specs/`) that deliberately contains none of this repo's own top-level directories — the
      fixture's whole point is proving the lint scans what a consumer repo actually ships. Mirror
      the source-store library layout inside the fixture so `LIB_CANDIDATES` resolves under
      `REPO_ROOT=$FIXTURE`.
- [ ] The four required cases, each asserted explicitly:
      - **clean tree** — a fixture subtree with no version language: exit 0, both counters 0.
      - **blocking finding** — exit 1, the finding line names the path and is labeled `BLOCKING`.
      - **advisory finding that does NOT change the exit code** — a file carrying only
        bare-past-tense vocabulary with no adjacent version token: exit **0**, with a nonzero
        ADVISORY count printed in the Summary. This is the single most important assertion in the
        file: it is the one that proves the tier split.
      - **marker-exempted content** — a `version-ok:begin`/`end` block: no finding reported.
- [ ] Additional sibling-parity cases: `specs/**` path exemption holds; a gitignored file carrying
      version language is never scanned (the `git ls-files` exclusion); `PATH_SCOPE` on a
      directory, on a single file, and on a nonexistent path (`[SKIP]`, exit 0); the per-finding
      line shape matches `^  [^:]+:[0-9]+:`; a durable-axis line (dotted semver, `@vN` pin, CI
      cache-key segment) produces no finding.
- [ ] **Omit the lint/hook scope-agreement case** (the sibling's Case 8).
      `hooks/validate-no-record-versioning.sh` does not exist and is out of scope — there is no
      hook to agree with, and inventing one is not this task's work.
- [ ] Wrap this test file's own literal fixture strings in `version-ok:begin`/`end` pairs with a
      header NOTE, exactly as Phase 4 did for the library's test and as
      `test-check-task-references.sh` does for its own.
- [ ] Clean through `bash scripts/lint/lint-shellcheck.sh --verbose scripts/tests/test-check-record-versioning.sh`;
      check its exit status.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesized at roughly 260-300 lines and 12-14 cases, by proportion to the
sibling's 312 lines / 11 cases minus Case 8 plus the tier-split cases. Confirm with `wc -l` and
the test's own `Results:` line at implementation time.

**Files to modify**:
- `scripts/tests/test-check-record-versioning.sh` - new file (the second deliverable)

**Tier Justification**: The covering check is running the new suite directly,
`timeout 540 bash agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh`,
which is by construction the one check that exercises every line of this file; it operates
entirely inside its own `mktemp` fixture and touches no repository state.

**Verification**:
- Bounded-wait idiom, mandatory: Bash tool `timeout` parameter `600000` (the `120000` default
  auto-backgrounds and strands the dispatch), plus
  `timeout 540 bash agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh > "$LOG" 2>&1; echo "exit=$?"`,
  read back with `grep -nE '\[FAIL\]|\[PASS\]|Results:' "$LOG" | tail -40`. No
  `run_in_background`, no Monitor, no harness notification.
- All cases PASS, FAILED count 0, exit 0.
- The advisory-only case is confirmed to exit **0** with a nonzero ADVISORY count — assert this
  by reading the case's own PASS line out of the log, not by inference.
- `bash scripts/lint/lint-shellcheck.sh --verbose scripts/tests/test-check-record-versioning.sh`
  exits 0.

---

### Phase 7: Wire the script and its test [NOT STARTED]

**Goal**: Register both deliverables so the deploy, the suite runner, and the operator-facing
inventory all know they exist.

**Tasks**:

- [ ] Re-read `manifest.json` immediately before editing (it is a high-traffic shared file).
- [ ] Add `"check-record-versioning.sh"` to `provides.scripts` at its locally alphabetical
      position — the sibling's entry is the `"check-task-references.sh"` line.
- [ ] Add `"tests/test-check-record-versioning.sh"` to the tests list — the sibling's entry is
      the `"tests/test-check-task-references.sh"` line.
- [ ] Add a fresh bullet to `docs/reference/utility-scripts-inventory.md` in that file's
      established dense single-bullet style: scope (every git-tracked file outside `specs/**`, via
      `git ls-files`, no hard-coded directory list), the two-tier contract (BLOCKING drives the
      exit code, ADVISORY is reported and never does), all three exit codes, the `--quiet` and
      `PATH_SCOPE` forms, and the `REPO_ROOT=$(pwd)` source-store override. Note in the bullet
      that the shared library is the sole source of patterns, exemptions, and tiers. There is
      **no** `check-task-references.sh` entry in this file to copy from — that is a pre-existing
      gap, noted for awareness and explicitly not this task's to fix for the sibling.
- [ ] Confirm `jq empty manifest.json` passes.
- [ ] No task-number references in either file.

**Timing**: 0.5 hours

**Depends on**: 5, 6

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Two one-line JSON insertions and one inventory bullet — three edits across
two files, no more. Confirm with `git diff --stat` at implementation time; a larger diff means
something unintended was touched in a shared file under concurrency.

**Files to modify**:
- `manifest.json` - add the script to `provides.scripts` and the test to the tests list
- `docs/reference/utility-scripts-inventory.md` - new catalogue bullet for the lint

**Tier Justification**: The covering check is
`bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` with
`<source_dir>` = `/home/benjamin/.config/nvim/agent-system/extensions/core` named explicitly
(the no-argument form defaults `TARGET` to `$(pwd)`, the consumer repo root, where both gates
silently SKIP and check nothing) — gate 3 is the doc-lint that validates manifest/README
cross-references and gate 4 the task-reference lint, together the only checks a manifest
registration plus a markdown catalogue bullet can break.

**Verification**:
- `jq empty manifest.json` exits 0.
- Bounded-wait idiom, mandatory: Bash tool `timeout` parameter `600000` (the `120000` default
  auto-backgrounds and strands the dispatch), plus
  `timeout 540 bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core > "$LOG" 2>&1; echo "exit=$?"`,
  read back with `grep -nE 'Gate 3|Gate 4|PASS|FAIL|SKIP' "$LOG" | tail -40`. No
  `run_in_background`, no Monitor, no harness notification.
- Both selected gates report PASS (neither SKIP — a SKIP here means `TARGET` was wrong and
  nothing was checked).
- `git diff --stat` shows exactly the two intended files.

---

### Phase 8: Acceptance verification and residue disposition [NOT STARTED]

**Goal**: Establish the acceptance bar with evidence, dispose of every remaining residue finding
by cause, and record what is deliberately left out.

**Tasks**:

- [ ] **Named-files sub-claim.** Run the finished lint against `docs/ci.md`, `docs/consuming.md`,
      and `docs/stability-and-versioning-policy.md` in the Verification repo individually, and
      confirm **zero BLOCKING findings** each. Record explicitly that
      `docs/setup-without-nix.md` **does not exist** at that repo's HEAD (re-confirmed at this
      plan's authoring: `git ls-files` finds no such path) — this is a factual mismatch in the
      acceptance text, not a lint failure, and MUST NOT be papered over by substituting a
      different file.
- [ ] **Repo-wide sub-claim.** Run the finished lint with no arguments against the Verification
      repo and require exit 0. Before this can pass, the deployed `core` tree in that repo must
      carry Phases 1-4's library and corpus fixes — 19 of its 19 measured residue findings are in
      its own deployed `.claude/` copies of this repo's source store, and none are in its own
      `docs/`, `books/`, or `records/` trees. Note: the completion-deploy gate refuses to mark
      this task completed while the deployed `core` tree is stale; that is expected and resolves
      at the next cycle's redeploy checkpoint. Do **not** attempt a manual workaround.
- [ ] **Disposition the two judgment-call residue lines**, raising a NON-BLOCKING
      `user_decision` on `.return-meta.json` and proceeding under the stated default rather than
      stalling. The two lines are
      `context/patterns/batch-orchestration-guardrails.md`'s `## Absent file_scope Hazard: The
      Split Admission Posture (v6)` heading and `docs/architecture/batch-admit-schema.md`'s
      `post-v5, where it previously always did` line. The question for the rule owner: is the
      numbered-ruling idiom a legitimate convention the taxonomy should admit as a new category
      with a mechanical exemption, or a real instance of the anti-pattern the rule targets?
      **Default this phase proceeds under**: de-version the two lines in place. It is the
      cheapest option, needs no taxonomy change, and needs no `version-ok` marker (which the
      taxonomy admits only with explicit user permission).
- [ ] **Enumerate the out-of-scope, this-repo-only residue** explicitly in the implementation
      summary, as a flagged follow-up and not a silent omission: the Neovim-plugin docs
      `lua/neotex/plugins/tools/himalaya/docs/ARCHITECTURE_V2.md`, `ARCHITECTURE_V3.md`, and
      `DRAFT_SYSTEM_V2.md` carry literal page-level version-labeled H1 titles — genuine,
      un-swept instances of the forbidden pattern outside the agent-system corpus the original
      de-versioning sweep covered, needing a content decision this task does not own. They are
      absent from the Verification repo and so do not gate the acceptance bar. Add this, also
      non-blocking, to the `user_decision`: whether to spawn a follow-up de-versioning task.
- [ ] Record in the summary whether a no-argument run against **this** repo exits 0 or 1, and
      why — a new lint that is red in its own home repo for enumerated, dispositioned reasons is
      an honest outcome; silently not reporting it is not.
- [ ] Run the complete gate set and confirm green.

**Timing**: 1.5 hours

**Depends on**: 2, 3, 4, 6, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Hypothesis carried from Phase 2's measurement: the Verification repo's
residue after Phases 1-4 is **0**, from a pre-fix 213. The 19 findings surviving the Phase 2
candidate narrowing are all in deployed copies of the three Phase 4 files plus the Phase 3
literature heading plus the Phase 2 case-sensitivity class plus the two judgment-call lines.
Confirm by running the finished lint, not the probe; if a residue class appears that Phases 1-4
did not predict, resolve which of "real miss in the sweep" or "discriminator bug" it is —
explicitly do not relax a pattern to make it green.

**Files to modify**:
- `context/patterns/batch-orchestration-guardrails.md` - de-version the `(v6)` heading per the stated default (re-read immediately before editing; no sibling holds this file)
- `docs/architecture/batch-admit-schema.md` - de-version the `post-v5 ... previously` line per the stated default

**Verification**:
- Bounded-wait idiom, mandatory, for the complete gate set: set the Bash tool's own `timeout`
  parameter to `600000` (its `120000` default auto-backgrounds the call and strands the
  dispatch), and run
  `timeout 540 bash /home/benjamin/.config/nvim/agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim/agent-system/extensions/core > "$LOG" 2>&1; echo "exit=$?"`,
  then read results back with `grep -nE 'Gate [0-9]+|PASS|FAIL|SKIP' "$LOG" | tail -60`. No
  `run_in_background`, no Monitor, no harness notification. This is the complete gate set this
  tier requires — including Gate 8 (the full shell test suite) and Gate 22 (shellcheck), which
  is where both new scripts and the modified library are exercised. If the log shows **exactly
  one** failure and it is `test-four-tier-conflict.sh` Case 6 (a `[1000ms,2000ms)` timing
  assertion measuring ~2.3-2.8s), attribute it to the known pre-existing flake under concurrent
  load and do not investigate.
- Bounded-wait idiom, mandatory, for each acceptance run (repo-wide sweeps): Bash tool `timeout`
  parameter `600000`, plus
  `timeout 540 bash /home/benjamin/Projects/Logos/Verification/.claude/scripts/check-record-versioning.sh > "$LOG" 2>&1; echo "exit=$?"`
  and one `timeout 540 ... check-record-versioning.sh docs/<file>` run per named file, each read
  back with `grep -nE 'BLOCKING|ADVISORY|PASS|FAIL' "$LOG" | tail -40`. No `run_in_background`,
  no Monitor, no harness notification.
- No-argument Verification-repo run exits 0.
- Each of the three existing named docs files produces zero BLOCKING findings.
- `scripts/tests/test-check-record-versioning.sh` and
  `scripts/tests/test-record-version-patterns.sh` both appear in the Gate 8 results as passing.

---

## Testing & Validation

- [ ] `run-all.sh --only test-record-version-patterns.sh` — FAILED 0, every pre-existing
      assertion intact, PASSED count strictly higher than before Phase 1.
- [ ] `test-check-record-versioning.sh` — all cases PASS, including the advisory-only case
      exiting 0 with a nonzero ADVISORY count.
- [ ] `bash scripts/lint/lint-shellcheck.sh --verbose` exits 0 over
      `check-record-versioning.sh`, `tests/test-check-record-versioning.sh`, and
      `lib/record-version-patterns.sh`, per `context/standards/shell-strict-mode.md` — the
      sanctioned entry point (Gate 22's own), never the bare `shellcheck` binary.
- [ ] `jq empty manifest.json`.
- [ ] `verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` — gates 3 and 4 PASS, neither
      SKIP.
- [ ] Full `verify-deploy.sh <source_dir>` green (sole permitted exception: the known
      `test-four-tier-conflict.sh` Case 6 timing flake).
- [ ] No-argument lint run against the Verification repo exits 0.
- [ ] `docs/ci.md`, `docs/consuming.md`, `docs/stability-and-versioning-policy.md` each produce
      zero BLOCKING findings.
- [ ] `bash scripts/check-task-references.sh` exits 0 over every file this task touched — no task-number
      references in deliverables outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/check-record-versioning.sh` (new — deliverable 1)
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` (new — deliverable 2)
- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` (modified — strip-function
  line-number fidelity, path-aware matching API, narrowed heading discriminator, extended
  durable-axis coverage)
- `agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh` (modified — new
  assertions plus `version-ok` markers)
- `agent-system/extensions/core/rules/no-record-versioning-in-deliverables.md` (modified — markers)
- `agent-system/extensions/core/context/standards/record-version-exemptions.md` (modified —
  markers plus durable-axis documentation)
- `agent-system/extensions/core/manifest.json` (modified — wiring)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (modified — catalogue bullet)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (modified —
  de-versioned heading, per Phase 8's stated default)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (modified — de-versioned
  line, per Phase 8's stated default)
- A NON-BLOCKING `user_decision` on `.return-meta.json` covering the numbered-ruling idiom and
  the follow-up de-versioning pass
- Implementation summary under `specs/281_record_versioning_repo_wide_lint/summaries/`

## Rollback/Contingency

Every phase commits per green sub-step, so rollback is per-commit `git revert` of this task's own
commits — no working-tree discard is needed and none is planned. The two new script files are
pure additions and can be deleted outright.

The library changes are the only edits with blast radius beyond this task, and they are staged to
be individually revertible: Phase 1 is additive with every exported pattern byte-identical,
Phase 2 is the behavioral narrowing, Phase 3 is additive durable-axis coverage, Phase 4 is marker
insertion only. If the narrowing in Phase 2 proves wrong, reverting that one commit restores the
pre-narrowing library while leaving Phase 1's API and line-number fidelity in place.

Should a genuine working-tree rollback become necessary, use the snapshot-then-rollback recipe in
`context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag. Do **not** emit a bare `git-snapshot.sh 281` as a routine
start-of-phase precaution; an ordinary defensive checkpoint uses `--no-revert`.

Concurrency note: sibling task 318 holds `verify-deploy.sh`, its context-budget test, and
`git-staging-scope.md` this same cycle. None overlaps this plan's file set. Per the territory
contract: re-read every file immediately before editing it, stage only this task's own hunks with
an explicit file list (never a directory or glob `git add`), and if a foreign commit or
uncommitted modification appears, STOP and report rather than proceeding.
