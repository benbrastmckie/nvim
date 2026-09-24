# Implementation Plan: Task #254

- **Task**: 254 - Implement chapter-quality-check.sh with its test harness, then wire the standard and checker into the typst agents, skills, manifest and index
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: Task 253 (chapter-quality standard) - complete
- **Research Inputs**: specs/254_typst_chapter_quality_checker_and_wiring/reports/01_chapter-quality-checker-wiring.md
- **Artifacts**: plans/01_chapter-quality-checker-wiring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement `chapter-quality-check.sh` as the mechanical backstop for the already-complete
`context/project/typst/standards/chapter-quality.md` specification (336 lines, 15 dual-tagged
rules), then register and wire it through six distinct contract surfaces so content work runs it
before declaring a chapter done. The edit target is the source store
`agent-system/extensions/typst/` exclusively; nothing is hand-authored under `.claude/**`. The
two concerns are phase-separated exactly as the dispatch requires: Phases 1-6 (Group A) touch
`scripts/` only and are verified by running the checker and its suite; Phases 7-10 (Group B) touch
registration and contract files and are verified by reading contracts and by a deploy into a
scratch target. Definition of done is the dispatch's nine acceptance criteria, each mapped to a
phase below.

### Research Integration

The research report supplies the authoritative rule transcription source (all 15 rules with their
`[BLOCKING|ADVISORY / MECHANICAL|JUDGED]` tags), the confirmed structural precedent
(`typst-element-lint.sh`, 341 lines, and `tests/test-typst-element-lint.sh`, 331 lines), the six
wiring sites with their exact existing element-lint analogs, and three findings this plan acts on
directly:

- **Rules 1.2 and 1.3 are in scope; the two Interface-Contract checks are not.** The checker
  implements 1.2 (backticked path resolution) and 1.3 (`@key` resolution) itself, and never
  implements the standard's `local:name-resolution` / `local:chapter-source-coverage` checks,
  which belong to a consuming repository. Phase 1 states this distinction in the script header.
- **The repo-root / `.bib` resolution question is open and is resolved by this plan** (see
  Decisions below) rather than left to implementation-time improvisation.
- **Acceptance criterion 8 cannot be checked by a plain `deploy-headless.sh` run here**, because
  `typst` is not among this repo's active extensions. Phase 10 uses the scratch-repo pattern
  already proven by `scripts/tests/test-deploy-propagation.sh`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh`: a Class B strict-mode checker
  mirroring `typst-element-lint.sh`'s structure, emitting a per-chapter score plus findings each
  carrying dimension, rule and BLOCKING/ADVISORY severity.
- Exit code driven by blocking findings only; no ANTI-FLUFF DENSITY finding can ever change it.
- All 8 JUDGED rules emitted as structured reviewer prompts, never silently skipped.
- Placement delegated to `typst-element-lint.sh`, never re-implemented.
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh`: a green suite
  demonstrating the blocking/advisory split in both directions plus the judged-prompt emission.
- Six wiring files updated so the checker is a pre-completion gate, the standard is loadable
  context for both typst agents, and the capability is discoverable from CLAUDE.md.

**Non-Goals**:
- Implementing the name-resolution or chapter-source-coverage checks (repo-local by contract).
- A second placement implementation of any kind.
- Re-tagging, renaming or inventing any rule. The standard's classification is authoritative;
  an unimplementable-as-classified rule is resolved by amending the standard in the SAME commit
  as the checker change, per the checker header's own instruction.
- Promoting any ADVISORY rule to BLOCKING (requires a documented review pass against real
  chapters first).
- Resolving `EXTENSION.md`'s `### Scope` tension (content work routes to `lean4`/`formal`/
  `general`) against wiring the gate into `typst-implementation-agent`. The dispatch's literal
  instruction is followed as written; the tension is noted in Risks for a follow-up.
- Loading the `typst` extension into this repo's own `.claude-extensions.json`.

## Decisions

These are settled here so they are not re-litigated at implementation time.

1. **Per-chapter score definition.** The standard defines no score; the dispatch requires one. The
   score is a *reporting convention*, not a rule: it introduces no new rule and re-tags nothing.
   It is computed solely from the standard's own inventory and reported per file as
   `MECHANICAL <passed>/<evaluated> | BLOCKING <n> | ADVISORY <n> | JUDGED <n> prompts pending`.
   The judged count is always printed alongside the mechanical ratio precisely so a green score
   can never be read as full coverage. Defined in the script header (Phase 1) and mirrored as a
   short non-rule `## Per-Chapter Score` reporting subsection added to `chapter-quality.md` in the
   same commit, marked explicitly as introducing no rule.
2. **Repo-root and bibliography resolution (Rules 1.2, 1.3).** Repo root is
   `git rev-parse --show-toplevel` run from each checked file's directory, falling back to the
   checked file's own directory when that fails. The `.bib` file is resolved by (a) the filename
   argument of a `#bibliography("...")` call in the checked file if present, else (b) the single
   `*.bib` found under the repo root. Zero or multiple candidates with no explicit declaration
   emits a named environment note (`[INFO]` line stating the reason) and evaluates Rule 1.3 as
   NOT EVALUATED for that file - never as a blocking failure. Documented as a KNOWN LIMITATION.
3. **Path-shape heuristic (Rule 1.2) biases toward under-firing.** A backtick token is treated as
   path-shaped only when it contains `/` or ends in a known file extension. Since 1.3/1.2 are
   BLOCKING, a false positive on a correct chapter is the failure mode that gets gates switched
   off; the bias is deliberate and documented as a KNOWN LIMITATION.
4. **CLI is exactly `[--verbose] [--help] PATH...`** as the dispatch specifies. No `--root` or
   `--bib` override options are added; resolution is automatic per Decision 2.
5. **Placement composition.** The checker locates the sibling lint as
   `$(dirname "$0")/typst-element-lint.sh`, invokes it per file with `--verbose`, maps its
   `[FAIL]` to a BLOCKING placement finding and `[WARN]` to ADVISORY, and exits 2 with an
   environment error if the sibling is absent - never a silent pass.
6. **Strict-mode class.** Both new scripts are Class B (`set -uo pipefail`, no `-e`) per
   `context/standards/shell-strict-mode.md`, matching the sibling pair exactly.
7. **Deployed-path convention in wiring prose.** Agent/skill/EXTENSION text refers to
   `.claude/scripts/chapter-quality-check.sh` (the deployed path), matching the existing
   element-lint wiring in the same files - not the source-store path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blocking MECHANICAL rule (1.2/1.3) fires on a correct chapter, causing the gate to be switched off | H | M | Decisions 2-3: under-firing bias, NOT EVALUATED branch for unresolvable bibliography, both documented as KNOWN LIMITATIONS; Phase 6 asserts the compliant-fixture silent case |
| Conflating Rules 1.2/1.3 with the repo-local Interface-Contract checks (omitting the former or implementing the latter) | H | M | Phase 1 header states the boundary explicitly; Phase 10 greps for `name-resolution`/`chapter-source-coverage` implementations and asserts absence |
| A second placement implementation creeps in | H | L | Decision 5 (delegate to sibling); Phase 10 acceptance grep over the checker for placement regexes |
| An ANTI-FLUFF finding reaches the exit code through a shared counter | H | M | Phase 1 separates `BLOCKING_COUNT` from `ADVISORY_COUNT` at the emission layer, before any rule is implemented; Phase 6 asserts an ANTI-FLUFF-only fixture exits 0 |
| A JUDGED rule is silently omitted, making green a false assurance | H | M | Phase 4 drives prompts from a single declared `JUDGED_RULES` list; Phase 6 asserts the emitted prompt set equals the standard's 8-rule JUDGED set by count and by rule id |
| Acceptance criterion 8 unverifiable in this repo (`typst` not an active extension) | M | H | Phase 10 uses the `test-deploy-propagation.sh` scratch-repo pattern; do NOT add `typst` to this repo's `.claude-extensions.json` |
| Hand-edited JSON breaks the deploy silently | M | M | Phase 7 runs `jq .` on both files before the phase closes |
| `EXTENSION.md` Scope paragraph tension with wiring the gate into `typst-implementation-agent` | L | H | Follow the dispatch literally; record the tension in the implementation summary as a follow-up candidate, do not resolve it here |
| Task-number references leak into extension deliverables | M | L | Phase 10 runs the repo-wide task-reference check over the touched paths |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7, 8, 9 | 6 |
| 8 | 10 | 7, 8, 9 |

Phases within the same wave can execute in parallel. Wave 7's three phases touch disjoint file
sets (JSON registration / agent contracts / skill+EXTENSION) and are territory-clean.

---

### Phase 1: Checker Skeleton, Header Contract and Emission Framework [COMPLETED]

**Goal**: `chapter-quality-check.sh` exists with its full documented header, the mandated CLI,
file/directory resolution, the finding-emission framework with separated blocking/advisory
counters, the per-chapter score, and the exit-code logic - before any rule is implemented.

**Tasks**:
- [x] Create `agent-system/extensions/typst/scripts/chapter-quality-check.sh`, `chmod +x`,
      `#!/usr/bin/env bash`, `set -uo pipefail` with the Class B admission comment citing
      `context/standards/shell-strict-mode.md`, mirroring `typst-element-lint.sh`'s opening. *(completed)*
- [x] Write the header block in `typst-element-lint.sh`'s section order: `PURPOSE.` (why prose
      alone was insufficient), `CHECKS.` (numbered, each tagged BLOCKING/ADVISORY inline),
      `SEVERITY SPLIT (do not change without a documented review pass against real chapters)`
      stating that no ANTI-FLUFF rule ever blocks, `RULE INVENTORY` sourced verbatim from
      `context/project/typst/standards/chapter-quality.md` with the instruction that the two are
      updated in the same commit, `SCOPE BOUNDARY` stating Rules 1.2/1.3 are implemented here
      while `local:name-resolution` and `local:chapter-source-coverage` are NOT,
      `KNOWN LIMITATIONS`, `CLI.`, `EXIT CODES.` *(completed)*
- [x] Seed `KNOWN LIMITATIONS` with the carried-over element-lint limitations that apply
      unchanged (no Typst math-mode parsing, no raw-block parsing, start-of-line matching only)
      plus Decisions 2-3's limitations. *(completed)*
- [x] Implement the arg loop: `--verbose|-v`, `--help|-h`, `--`, positional `PATH...`; unknown
      `-*` -> usage + exit 2; empty PATHS -> exit 2; nonexistent PATH -> exit 2. *(completed)*
- [x] Implement path resolution: a file used directly; a directory via
      `find "$p" -type f -name '*.typ' -print0 | sort -z`. *(completed)*
- [x] Implement the finding emitter carrying `{dimension, rule, severity, location, message}`
      (the standard's shared finding-record shape), with `[FAIL]`/`[WARN]`/`[INFO]` colored
      output and SEPARATE `TOTAL_BLOCKING` / `TOTAL_ADVISORY` counters. *(completed)*
- [x] Implement the per-chapter score line per Decision 1 and the final summary banner. *(completed)*
- [x] Implement exit: `1` iff `TOTAL_BLOCKING > 0`; `0` otherwise regardless of advisory count;
      `2` for usage/environment errors. *(completed)*
- [x] Add the non-rule `## Per-Chapter Score` reporting subsection to
      `context/project/typst/standards/chapter-quality.md` per Decision 1, in THIS phase's commit. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the header carries eight named sections and that
`typst-element-lint.sh`'s three limitations transfer unchanged. Confirm by diffing the new header's
section list against `sed -n '1,70p' scripts/typst-element-lint.sh` before closing the phase.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - new file
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` - add the
  non-rule `## Per-Chapter Score` subsection only; no rule text, tag or name changes

**Verification**:
- `bash scripts/chapter-quality-check.sh --help` exits 0 and prints the CLI shape.
- No PATH, and a nonexistent PATH, each exit 2 with usage guidance.
- A trivial compliant `.typ` fixture exits 0 and prints a score line.
- A directory argument scans recursively and deterministically.
- `bash -n` clean.

---

### Phase 2: MECHANICAL BLOCKING Rules (1.2, 1.3, 1.5, 3.2) [NOT STARTED]

**Goal**: the four mechanical rules the standard tags BLOCKING are implemented and drive exit 1.

**Tasks**:
- [ ] Implement the shared line pre-processing pass mirroring `typst-element-lint.sh`: strip
      double-quoted string contents, strip `// ` comment tails, trim - matching against the
      stripped/trimmed line, except where a rule explicitly needs the comment text (1.5).
- [ ] Rule 3.2 (heading depth bounded at `===`, no level-4+): per-line start-of-line marker-depth
      grep. BLOCKING.
- [ ] Rule 1.5 (`CONFIRM` comment well-formed): a `// CONFIRM:` marker with an empty payload after
      the prefix is a finding; a marker with non-empty claim text passes. Open markers are legal -
      the rule checks shape only. BLOCKING.
- [ ] Implement repo-root resolution per Decision 2 (`git rev-parse --show-toplevel` from the
      checked file's directory, fallback to that directory).
- [ ] Rule 1.2 (backticked path resolves against the live tree): extract backtick-delimited
      tokens, keep only path-shaped ones per Decision 3, test existence relative to repo root and
      to the checked file's directory; resolving under either counts as resolved. BLOCKING.
- [ ] Implement bibliography resolution per Decision 2, including the NOT EVALUATED `[INFO]`
      branch for zero/multiple unresolvable candidates.
- [ ] Rule 1.3 (`@key` resolves in the project `.bib`): extract `@key` occurrences per
      `patterns/bibliography.md`'s citation syntax, grep the resolved `.bib` for a matching entry
      key. BLOCKING when the bib resolved; NOT EVALUATED otherwise.
- [ ] Record every heuristic introduced here in the header's `KNOWN LIMITATIONS`.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly four MECHANICAL-BLOCKING rules (1.2, 1.3, 1.5,
3.2). Confirm at implementation time by re-grepping
`grep -n 'BLOCKING / MECHANICAL' context/project/typst/standards/chapter-quality.md` and matching
the returned rule numbers one-for-one against the implemented set.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - add the four checks and the
  root/bib resolution helpers

**Verification**:
- A scratch fixture violating each of 1.2, 1.3, 1.5, 3.2 independently produces a `[FAIL]` naming
  that rule, its dimension and its location, and exits 1.
- A compliant fixture exits 0 with no `[FAIL]`.
- A fixture in a directory with no resolvable `.bib` prints the NOT EVALUATED `[INFO]` line and
  still exits 0 when nothing else fails.

---

### Phase 3: MECHANICAL ADVISORY Rules (2.1, 2.3, 3.3) [NOT STARTED]

**Goal**: the three mechanical advisory rules are implemented, report their thresholds inline, and
provably cannot change the exit code.

**Tasks**:
- [ ] Declare thresholds as named constants near the top of the script, mirroring
      `typst-element-lint.sh`'s `ITEM_THRESHOLD`/`DENSITY_FLOOR` pattern, each carrying an
      `UNREVIEWED` comment matching the standard's own disclosure language.
- [ ] Rule 2.1 (claim-to-word ratio per section): compute per `==`/`===` section, warn below the
      threshold, and report the threshold used in the finding message as the standard requires.
      ADVISORY.
- [ ] Rule 2.3 (hedging/filler seed list): declare the seed list as a named array drawn from
      `standards/textbook-standards.md`'s Professional Tone "Avoid" column (including the
      standard's own examples: "it seems", "arguably", "it is worth noting that", "needless to
      say"); report the list contents or version alongside each finding. ADVISORY.
- [ ] Rule 3.3 (paragraph length bounded): per-paragraph word/line count against the named
      constant, reporting the threshold used. ADVISORY.
- [ ] Assert at the emission layer that these three rules increment `TOTAL_ADVISORY` only, never
      `TOTAL_BLOCKING`.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly three MECHANICAL-ADVISORY rules (2.1, 2.3, 3.3)
and that no ANTI-FLUFF rule is ever BLOCKING. Confirm by re-grepping
`grep -n 'ADVISORY / MECHANICAL' context/project/typst/standards/chapter-quality.md` and by
confirming the ANTI-FLUFF dimension preamble's blanket advisory statement still stands.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - add the three advisory checks
  and their named threshold constants

**Verification**:
- A fixture tripping all three advisory rules and nothing else exits 0 while printing all three
  `[WARN]` findings, each naming the threshold or list it used.
- The same fixture's score line reports a non-zero ADVISORY count with exit status 0.

---

### Phase 4: JUDGED Rule Reviewer Prompts (1.1, 1.4, 2.2, 3.1, 3.4, 4.1, 4.2, 4.3) [NOT STARTED]

**Goal**: every rule the standard classifies as JUDGED is emitted as a structured prompt naming
the rule, the location, and what the reviewer must decide - never silently skipped.

**Tasks**:
- [ ] Declare a single `JUDGED_RULES` table (rule id, dimension, severity, decision question)
      transcribed verbatim from the standard, with the same "update in the same commit"
      instruction the rule inventory carries.
- [ ] Emit one structured prompt per judged rule per checked file, in the shared finding-record
      shape, with an explicit reviewer-prompt marker distinguishing it from `[FAIL]`/`[WARN]`.
- [ ] Give location-bearing judged rules a concrete anchor where one is derivable without judging
      (e.g. 2.2 anchors each `==`/`===` heading line; 4.2 anchors the file when no dedicated
      open-questions location is found); otherwise anchor the file.
- [ ] Ensure judged prompts increment neither `TOTAL_BLOCKING` nor `TOTAL_ADVISORY`, and are
      counted in their own `TOTAL_JUDGED` reported in the score line.
- [ ] State in the header that a green exit asserts mechanical coverage only, with judged rules
      pending reviewer adjudication.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly eight JUDGED rules (1.1, 1.4, 2.2, 3.1, 3.4, 4.1,
4.2, 4.3). Confirm by `grep -c '/ JUDGED\]' context/project/typst/standards/chapter-quality.md`
and matching the returned rule ids one-for-one against `JUDGED_RULES`.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - add `JUDGED_RULES` and the
  prompt emitter

**Verification**:
- A minimal compliant fixture still emits all eight reviewer prompts and exits 0.
- Each prompt names its rule id, its dimension, a location, and the decision the reviewer must
  make.
- The emitted prompt rule-id set equals the standard's JUDGED set exactly (no omissions, no
  extras).

---

### Phase 5: Placement Composition with typst-element-lint.sh [NOT STARTED]

**Goal**: the Universal Placement Rule is enforced by delegating to the existing lint, with its
findings aggregated into this checker's severity semantics - and no second implementation exists.

**Tasks**:
- [ ] Resolve the sibling as `$(dirname "$0")/typst-element-lint.sh`; a missing sibling is an
      environment error (exit 2) with a named message, never a silent pass.
- [ ] Invoke the sibling per checked file with `--verbose`; map `[FAIL]` to a BLOCKING placement
      finding and `[WARN]` to an ADVISORY finding, re-emitted in this checker's finding-record
      shape with the delegated source named in the message.
- [ ] Document the delegation in the header's `CHECKS.` and `SCOPE BOUNDARY` sections, stating
      that two independent placement implementations would diverge.
- [ ] Confirm no placement regex was added to this checker: `grep -nE 'definition|theorem|lemma|corollary|remark|rule-block|rule-list' scripts/chapter-quality-check.sh`
      returns only header prose and the delegation call, no matching logic.

**Timing**: 45 minutes

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts placement is the only rule delegated to the sibling lint.
Confirm by re-reading `chapter-quality.md`'s `## Deferrals and Ownership`
`### standards/semantic-element-usage.md` subsection and checking no second rule is deferred there
to the element lint.

**Files to modify**:
- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` - add the delegation

**Verification**:
- A fixture with a semantic element standing as first body content after a heading produces a
  BLOCKING placement finding and exit 1.
- A fixture tripping only the sibling's advisory checks exits 0 with the advisory finding printed.
- The grep above confirms no second placement implementation.

---

### Phase 6: Test Harness [NOT STARTED]

**Goal**: `tests/test-chapter-quality-check.sh` exists, is green, and demonstrates the
blocking/advisory split in both directions plus judged-prompt emission.

**Tasks**:
- [ ] Create `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` following
      `tests/test-typst-element-lint.sh`'s shape: `set -uo pipefail`, `SCRIPT_DIR` via
      `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, `CHECKER="${SCRIPT_DIR}/../chapter-quality-check.sh"`,
      `PASSED`/`FAILED` counters with `pass()`/`fail()`/`info()` helpers per
      `context/standards/shell-script-testing.md`, `WORKDIR="$(mktemp -d)"` with
      `trap 'rm -rf "$WORKDIR"' EXIT`, inline-heredoc fixtures only (no committed fixture files).
- [ ] Implement `assert_exit`, `assert_contains`, `assert_not_contains` parameterized by case name,
      printing actual output on failure.
- [ ] Case: compliant fixture -> exit 0, no `[FAIL]`.
- [ ] Case per MECHANICAL BLOCKING rule (1.2, 1.3, 1.5, 3.2) -> `[FAIL]` naming that rule, exit 1.
- [ ] Case: advisory-only fixture -> exit 0 AND the advisory findings ARE printed (the non-vacuity
      guard; assert both the exit code and the presence of the `[WARN]` text).
- [ ] Case: ANTI-FLUFF-only fixture (2.1 and 2.3 firing, nothing else) -> exit 0 explicitly,
      proving no ANTI-FLUFF finding can change the exit code.
- [ ] Case: judged-prompt emission - all eight prompts present on a compliant fixture, asserted by
      rule id.
- [ ] Case: placement delegation - element-first-after-heading fixture -> BLOCKING, exit 1.
- [ ] Case: unresolvable bibliography -> NOT EVALUATED `[INFO]` printed, exit 0.
- [ ] CLI-contract cases: no PATH -> 2, nonexistent PATH -> 2, `--help` -> 0, directory scan works.
- [ ] Final `echo "$PASSED passed, $FAILED failed"`; exit 0 iff `FAILED == 0`.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts roughly 14 cases covering 4 blocking rules, 3 advisory
rules, 8 judged prompts and 4 CLI contracts. Confirm the final case list against the checker's
implemented rule set at implementation time rather than against this estimate; add cases for any
rule left uncovered.

**Files to modify**:
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` - new file, `chmod +x`

**Verification**:
- `bash scripts/tests/test-chapter-quality-check.sh` prints `N passed, 0 failed` and exits 0.
- `bash scripts/tests/test-typst-element-lint.sh` still green (no regression in the sibling).
- `bash -n` clean on both scripts.

---

### Phase 7: Registration - manifest.json and index-entries.json [NOT STARTED]

**Goal**: both new scripts are registered in `provides.scripts`, and the standard is registered as
a loadable context entry for both typst agents.

**Tasks**:
- [ ] Add `"chapter-quality-check.sh"` and `"tests/test-chapter-quality-check.sh"` to
      `manifest.json`'s `provides.scripts`, matching the existing element-lint pair's
      subdirectory-qualified convention.
- [ ] Add an `index-entries.json` entry for `project/typst/standards/chapter-quality.md` with
      `path`, `line_count` (the actual `wc -l` value at edit time - re-measure, do not copy an
      estimate, since Phase 1 amended the file), `load_when.agents`:
      `["typst-implementation-agent", "typst-research-agent"]`, `load_when.task_types`:
      `["typst"]`, `domain`: `"project"`, `subdomain`: `"typst"`, a one-sentence `summary`, and
      3-6 `keywords`.
- [ ] `jq . manifest.json` and `jq . index-entries.json` to confirm well-formedness.

**Timing**: 30 minutes

**Depends on**: 6

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts two new `provides.scripts` entries and exactly one new
index entry. Confirm the `line_count` by running `wc -l` on the standard after Phase 1's amendment
lands, not from the research report's pre-amendment 336.

**Files to modify**:
- `agent-system/extensions/typst/manifest.json` - two `provides.scripts` entries
- `agent-system/extensions/typst/index-entries.json` - one new context entry

**Verification**:
- `jq .` clean on both files.
- `jq -r '.provides.scripts[]' manifest.json` lists all four scripts.
- `jq -r '.entries[] | select(.path=="project/typst/standards/chapter-quality.md")' index-entries.json`
  returns the entry with both agents in `load_when.agents`.

---

### Phase 8: Agent Contract Wiring [NOT STARTED]

**Goal**: the checker is a pre-completion gate in `typst-implementation-agent.md` at all three
element-lint precedent sites, and the standard is named at `typst-research-agent.md`'s Stage 2.

**Tasks**:
- [ ] `typst-implementation-agent.md` Stage 4C "Verify Phase Completion": add a
      chapter-quality sub-bullet parallel to (never replacing) the existing element-lint bullet,
      running `bash .claude/scripts/chapter-quality-check.sh --verbose {changed .typ file}` for
      every `.typ` file created or modified in the phase; a BLOCKING finding blocks marking the
      phase complete exactly as a `typst compile` failure would; ADVISORY findings do not block but
      MUST be reported in the phase output; judged reviewer prompts must be answered, not skipped.
- [ ] `typst-implementation-agent.md` Stage 5 final verification: add the same invocation over
      every `.typ` file touched by the task, alongside - never replacing - `typst compile` and the
      element lint, with BLOCKING as the same blocking condition and ADVISORY findings reported in
      the implementation summary's Verification section.
- [ ] `typst-implementation-agent.md` Critical Requirements: add a MUST DO item stating the
      obligation at both stages, mirroring existing item 7's wording for the element lint.
- [ ] `typst-research-agent.md` Stage 2 ("Analyze Task and Load Context"): name
      `context/project/typst/standards/chapter-quality.md` as a context file to load when the
      research feeds chapter content, so research is calibrated to the bar the chapter will be
      measured against. (The `index-entries.json` `load_when` addition in Phase 7 already makes it
      auto-loadable; this inline mention is for discoverability parity.)
- [ ] No task-number references anywhere in these files.

**Timing**: 45 minutes

**Depends on**: 6

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts exactly three wiring sites in
`typst-implementation-agent.md`. Confirm by
`grep -n 'typst-element-lint.sh' agents/typst-implementation-agent.md` and adding a parallel
chapter-quality mention at each returned site, no more and no fewer.

**Files to modify**:
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` - Stage 4C, Stage 5,
  Critical Requirements MUST DO
- `agent-system/extensions/typst/agents/typst-research-agent.md` - Stage 2 context loading

**Verification**:
- `grep -c 'chapter-quality-check.sh' agents/typst-implementation-agent.md` returns 3.
- Each occurrence states the BLOCKING-blocks / ADVISORY-reported split explicitly.
- `grep -n 'chapter-quality.md' agents/typst-research-agent.md` returns the Stage 2 mention.
- Diff read-through confirms every changed hunk is prose; the element-lint wiring is intact and
  unmodified.

---

### Phase 9: Skill and EXTENSION.md Wiring [NOT STARTED]

**Goal**: the Stage 5b self-execution fallback reflects the new verification step, and the
capability is advertised in the extension's CLAUDE.md merge source.

**Tasks**:
- [ ] `skills/skill-typst-implementation/SKILL.md` Stage 5b "Self-review before writing metadata":
      extend the existing paragraph so the inline authoring path also runs
      `bash .claude/scripts/chapter-quality-check.sh --verbose` over the `.typ` content it touched
      when that content is chapter prose, with the same BLOCKING-blocks / ADVISORY-reported split,
      keeping the paragraph's existing `semantic-element-usage.md` self-review intact.
- [ ] `skills/skill-typst-implementation/SKILL.md` "MUST NOT (Document Structure)": extend the
      cross-reference sentence so the correspondence with the agent's Critical Requirements covers
      the chapter-quality gate too.
- [ ] `EXTENSION.md` "Common Operations": add a bullet mirroring the element-lint bullet's exact
      shape - command line, one-line description of what it backstops, and the blocking/advisory
      split summary (naming that ANTI-FLUFF findings never block).
- [ ] No task-number references anywhere in these files.

**Timing**: 30 minutes

**Depends on**: 6

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts two landing sites in `SKILL.md` and one in
`EXTENSION.md`. Confirm by grepping each file for `semantic-element-usage` and
`typst-element-lint.sh` respectively and placing the parallel mention at each returned site.

**Files to modify**:
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` - Stage 5b self-review
  paragraph and the MUST NOT cross-reference sentence
- `agent-system/extensions/typst/EXTENSION.md` - one Common Operations bullet

**Verification**:
- `grep -n 'chapter-quality' skills/skill-typst-implementation/SKILL.md EXTENSION.md` returns the
  three additions.
- The `EXTENSION.md` bullet's shape matches the element-lint bullet line-for-line in structure.
- Diff read-through confirms all changes are prose with no compile surface.

---

### Phase 10: Deploy Verification and Acceptance Sweep [NOT STARTED]

**Goal**: all nine acceptance criteria are demonstrated, including a clean deploy of the six
wiring files into a `.claude/` tree.

**Tasks**:
- [ ] Deploy check: following `scripts/tests/test-deploy-propagation.sh`'s pattern, create a
      scratch `mktemp -d` git repo, load the `typst` extension into it via the real deploy path,
      and confirm both new scripts land under `.claude/scripts/`, the index entry merges into
      `.claude/context/index.json`, and the `EXTENSION.md` section merges into `.claude/CLAUDE.md`.
      Do NOT add `typst` to this repo's own `.claude-extensions.json`.
- [ ] Criterion 1: confirm both new files exist in the source store and
      `git status --short .claude/` shows no hand-authored additions.
- [ ] Criterion 2: `bash scripts/tests/test-chapter-quality-check.sh` green, with the
      blocking/advisory cases both present.
- [ ] Criterion 3: re-run the blocking fixture (exit 1) and the advisory-only fixture (exit 0 with
      findings printed) and record both outputs.
- [ ] Criterion 4: re-run the ANTI-FLUFF-only fixture and record exit 0 explicitly.
- [ ] Criterion 5: diff the emitted judged rule-id set against the standard's JUDGED set; record
      the comparison.
- [ ] Criterion 6: run the Phase 5 placement grep and record that no second implementation exists.
- [ ] Criterion 7: `jq` assertions from Phase 7 re-run.
- [ ] Criterion 8: the deploy result above.
- [ ] Criterion 9: run `bash .claude/scripts/check-task-references.sh` (or the repo's task-reference
      lint) over the touched `agent-system/extensions/typst/**` paths; zero findings.
- [ ] Record each criterion's evidence for the implementation summary's Verification section,
      including any `EXTENSION.md` Scope tension noted as a follow-up candidate.

**Timing**: 1 hour

**Depends on**: 7, 8, 9

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts nine acceptance criteria and six wiring files. Confirm the
criterion list against the task description in `specs/state.json` at implementation time rather
than against this plan's transcription.

**Files to modify**:
- None (verification only). Any defect found here is fixed in the owning phase's file and
  re-verified.

**Verification**:
- All nine criteria have recorded evidence.
- Both extension test suites green.
- Scratch-repo deploy reproduces all six wiring surfaces with no error.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` -> `0 failed`
- [ ] `bash agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` -> `0 failed`
      (no regression in the sibling)
- [ ] `bash -n` clean on both new scripts
- [ ] Blocking fixture exits 1; advisory-only fixture exits 0 with findings printed
- [ ] ANTI-FLUFF-only fixture exits 0 (explicit demonstration)
- [ ] All eight judged reviewer prompts emitted on a compliant fixture
- [ ] `jq .` clean on `manifest.json` and `index-entries.json`
- [ ] Scratch-repo deploy reproduces the six wiring surfaces
- [ ] Task-reference lint clean over `agent-system/extensions/typst/**`

## Artifacts & Outputs

- `agent-system/extensions/typst/scripts/chapter-quality-check.sh` (new, executable)
- `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh` (new, executable)
- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` (amended:
  non-rule `## Per-Chapter Score` reporting subsection only)
- `agent-system/extensions/typst/manifest.json` (two `provides.scripts` entries)
- `agent-system/extensions/typst/index-entries.json` (one new context entry)
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` (three wiring sites)
- `agent-system/extensions/typst/agents/typst-research-agent.md` (Stage 2 context mention)
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` (two sites)
- `agent-system/extensions/typst/EXTENSION.md` (one Common Operations bullet)
- `specs/254_typst_chapter_quality_checker_and_wiring/summaries/01_*-summary.md` (implementation
  summary, with the acceptance-criteria evidence in its Verification section)

## Rollback/Contingency

Every phase commits at its own green milestone per `rules/git-workflow.md`'s
Commit-Per-Green-Substep Mandate, so a regression in Group B (Phases 7-10) is reverted by reverting
only its own commits without touching Group A's checker commits, and vice versa - which is exactly
the diagnosability the dispatch's phase separation exists to provide.

Both new files are additive: reverting Group A is `git rm` of the two new scripts plus reverting
the standard's `## Per-Chapter Score` subsection. The six wiring edits are all additive insertions
alongside the existing element-lint wiring, so reverting Group B restores the pre-task behavior
with the element lint fully intact.

If a rollback is needed while uncommitted work is present, take a snapshot first per
`context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag for the
deliberate whole-tree case) before running any command that discards working-tree changes. Do not
emit a bare default-mode snapshot call as a routine start-of-phase precaution; an ordinary
defensive checkpoint before risky work uses the durable, non-reverting `--no-revert` mode instead.

The scratch-repo deploy in Phase 10 never mutates this repository's `.claude/` tree or its
`.claude-extensions.json`, so it carries no rollback obligation of its own.
