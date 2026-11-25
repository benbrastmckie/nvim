# Implementation Plan: Task #504

- **Task**: 504 - Lean Goals-block harvest contract (MEASURED {871, iss_1793913951568_HzkOMJ})
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/504_lean_goals_block_harvest_contract/reports/01_goals-block-harvest-contract.md
- **Artifacts**: plans/01_goals-block-harvest-contract.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research settled the decision: **(a) narrow the script.** `lean-plan-compliance-check.sh`'s
legacy Goals-prose fallback harvest still sweeps every backticked identifier-shaped token in the
whole Goals range, while its sibling reader `lean-challenge-snapshot.sh`'s `extract_goal_names()`
was narrowed to a per-bullet **leading-identifier-run** on 2026-11-04 — in the same commit that
wrote `plan-format.md`'s current "identifiers must LEAD the bullet" contract language. The
document is already right and one of the two readers already implements it; this plan brings the
second reader into line, re-baselines the test cases that the narrowing legitimately changes, and
adds the regression coverage the record's own VERIFICATION clause demands.

No documentation is widened (rejected alternative (b)), and no deployed `.claude/**` file is
hand-authored: every edit lands in the source store at
`/home/benjamin/.config/nvim/agent-system/extensions/lean/`, re-derived at planning time from
`.extensions.lean.source_dir` in `.claude-extensions.json`.

### Research Integration

Findings carried into the phases below:

- The port target is a *positional* rule, not another shape exclusion. `is_excluded_token()`
  cannot be extended to exclude binder names (`P`, `hP`) or ordinary cross-referenced
  pre-existing identifiers (`plusValidIn_reflectTime`, `lcN_plusValidZTime`) — they have no
  distinguishing shape. Only the leading-run narrowing structurally removes this class.
- `is_excluded_token()` is **kept as a redundant second guard**, not removed, matching
  `lean-challenge-snapshot.sh`'s own stated precedent for its `LEAN_KEYWORDS` list.
- The two readers stay independently implemented (bash/grep here, Python there) per the existing
  "SHARED FRAGILITY" convention; no attempt is made to unify them.
- The already-landed `CHALLENGE-STATEMENTS-PREFERRED HARVEST` masks the fallback for any
  well-formed must-exist plan, so a new regression fixture carrying a populated
  `## Lean Challenge Statements` section would route through the already-working preferred path
  and prove nothing. Phase 2's regression case deliberately omits that section.
- The Goals-range *header-shape* gap (`lean-plan-compliance-check.sh` does not accept the
  list-item `- **Goals**:` form its sibling's `START_RE` accepts) stays out of scope, flagged in
  a code comment rather than silently fixed.
- The stale `plan_goals_preamble.md` fixture comment ("because the snapshot tool reads every
  backticked token here as a Goal") misstates already-fixed behaviour and is corrected.

**One consequence the research report did not surface, established during this planning pass and
driving Phase 1's shape.** The report's Decisions section judged the "mis-parses the existing
fixture shapes" risk to not materialize, on the grounds that
`plan_r19_multiline_paren_goals.md`, `plan_r18_paren_goals.md`, `plan_list_item_goals.md` and
`plan_goals_preamble.md` already pass the leading-run algorithm. That is correct but incomplete:
those are `lean-challenge-snapshot.sh`'s fixtures. `lean-plan-compliance-check.sh`'s **own** test
suite places identifiers in trailing-prose positions in four of its nineteen cases, and a drop-in
port changes their harvested name sets. Simulated directly against each case's Goals block:

| Case | Subject of the case | Harvested today | Harvested after the narrowing |
|------|---------------------|-----------------|-------------------------------|
| C13 | archived refutation plan's real Goals shape | `LadderCons`, `ladderCons_localRun`, `ladderRealized` (+ keyword-excluded `box`, `sorry`, `stab`) | *(none — the bullet's first content is prose)* |
| C14 | declaration kinds beyond theorem/def | `Frame`, `Short`, `Tree`, `hidden` | `Frame` |
| C15 | structure-field fallback | `Frame`, `Frame.factoring`, `carrier`, `factoring` | `factoring` |
| C16 | dotted-name / module-path resolution | + `Mods.Deep` | *(drops `Mods.Deep`)* |

C18 (harvest exclusions) is unaffected — `Frame` leads its bullet. Baseline confirmed green
(19 passed, 0 failed) before this analysis, so these four are a consequence of the change, not
pre-existing failures. Phase 1 therefore pre-declares the fallout as an atomic batch rather than
leaving an implementer to meet four red cases mid-phase.

The research's top-listed risk — bash/grep drift from the proven Python — was also discharged at
planning time: the recommended two-stage form was run against the measured-defect shape (yields
`foo_bar` alone), a four-identifier conformant run (yields all four), and a prose-leading bullet
(yields nothing).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context, and no `roadmap_flag` is set; no
roadmap consultation applies.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged three description lines as carried-figure trigger shapes. Each checked
against the prior report and against live state:

1. *"The script and the document cannot both be right"* — **confirmed, with one refinement.** The
   disagreement is real but localized to the script's *fallback* branch
   (`lean-plan-compliance-check.sh` lines ~227-230); the `CHALLENGE-STATEMENTS-PREFERRED HARVEST`
   branch, which landed four days after the measured defect, does not disagree with the document
   at all. The document is the side that is right.
2. *"can never resolve as declarations introduced by the plan, so the Final Verification
   spot-check would have failed permanently"* — **confirmed.** The report reproduced it live:
   four spurious `[MISSING]` lines (`hP`, `lcN_plusValidZTime`, `P`,
   `plusValidIn_reflectTime`) with `COMPLIANCE_CHECK: failed`, exit 1, alongside a correct
   `[OK] foo_bar`.
3. *"this task's declared `file_scope` do not resolve inside this repository and a phase commit
   here cannot carry them"* — **refuted, exactly as the migration preamble predicted.**
   Re-verified live: `git -C agent-system rev-parse --show-toplevel` returns
   `/home/benjamin/.config/nvim`, i.e. `agent-system/` is part of this repository's own git tree,
   not a separate one. `jq -r '.extensions.lean.source_dir' .claude-extensions.json` resolves to
   `/home/benjamin/.config/nvim/agent-system/extensions/lean` and all three target files exist
   there. Expect no containment drops; a phase commit here carries these paths normally.

## Goals & Non-Goals

**Goals**:

- Narrow `lean-plan-compliance-check.sh`'s Goals-prose fallback harvest to a per-bullet
  leading-identifier-run extraction, so descriptive backticks in Goals prose are safe again and
  the stripped-backticks workaround is not the settled answer.
- Keep the script's own dotted `IDENT_PCRE` and `is_excluded_token()` second guard intact, so the
  landed dotted-name and declaration-kind widenings are not regressed by the narrowing.
- Re-baseline the four affected existing test cases explicitly — three by rewriting their Goals
  bullets into the already-documented contract-conformant shape, one (C13) by recording its new,
  honest verdict with a stated supersession, never a silent re-baseline.
- Add the record's required regression coverage: a Goals block citing a pre-existing lemma and a
  binder name in prose, with no `## Lean Challenge Statements` section, which the check does not
  fail on, asserting the exact harvested set rather than only the verdict.
- Correct the stale `plan_goals_preamble.md` fixture comment that misstates already-fixed
  behaviour.
- Leave both readers' documented contract (`plan-format.md`) untouched, because it already states
  the rule this plan implements.

**Non-Goals**:

- Widening `plan-format.md` to make "no backticks in Goals prose except goal identifiers" an
  authoring rule (rejected alternative (b)). The document already states the opposite and
  correct rule.
- Fixing the Goals-range *header-shape* acceptance gap (list-item `- **Goals**:` recognition).
  Flagged in a code comment in Phase 1; a separate record is the right home for deciding whether
  to widen this script's range anchor to match its sibling's `START_RE`.
- Unifying the bash and Python leading-run implementations into shared code. The existing
  "SHARED FRAGILITY" cross-reference convention is extended, not replaced.
- Editing `lean-challenge-snapshot.sh`, `test-lean-challenge-snapshot.sh`,
  `rules/plan-compliance.md`, `manifest.json`, or `lean-implementation-agent.md` — all declared in
  concurrent siblings' `file_scope` this cycle (tasks 451 and 537), and none require a change here.
- Adding the `context/project/lean4/patterns/goals-block-reader-parity.md` context file the
  research recommends. The research itself scopes it as a follow-up *after* this fix lands, and
  registering a new context file would require editing
  `agent-system/extensions/lean/index-entries.json`, which concurrent sibling task 398 declares in
  its own `file_scope` this cycle. Recorded as a follow-up observation in Phase 4 instead.
- Regenerating the deployed `.claude/**` tree. Deployment is the loader's own lifecycle step, and
  a whole-tree regeneration this cycle would serialize against four concurrent siblings for no
  benefit to this record. No phase here makes a whole-tree claim.
- BimodalLogic backlog records #813 (Challenge-block precedence / snapshot prerequisites) and
  #824 (fixture-dependent gate statements), per the dispatch's own Scope Boundary.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The bash/grep port drifts from the proven Python behaviour (a PCRE quirk around `and\b`, or a mis-split of the run-then-extract two-stage form) | M | L | Discharged at planning time: the two-stage form was run against three shapes (measured-defect prose, a four-identifier conformant run, a prose-leading bullet) and matched the Python's output on each. Phase 1 ports that exact two-stage structure rather than attempting a single combined regex, and Phase 2's assertions pin the harvested *set*, not just the verdict |
| The port silently regresses the landed dotted-name widening by copying the Python's own non-dotted `LEAN_IDENT_PATTERN` (`[^\W\d][\w']*`) instead of this script's dotted `IDENT_PCRE` | H | M | Named explicitly as a Phase 1 task and in Phase 1's verification: C16/C17 (dotted resolution) are the covering cases, and both must stay green. The two identifier patterns deliberately differ and must not be unified |
| The new regression fixture is written with a populated `## Lean Challenge Statements` section, routing through the already-fixed preferred-harvest path and proving nothing | H | M | Phase 2 asserts the absence of that section in the fixture body and asserts the exact harvested set; Phase 2's companion case pins the preferred-harvest precedence separately, so the two paths cannot be confused |
| C13's re-baseline to `skipped` is read by a future maintainer as a silent weakening of the check | M | M | Follow the suite's own C5/C6 precedent: an explicit `SUPERSEDED` header comment naming what changed and why, plus a companion case preserving C13's actual regression intent (refutation polarity's failed-without / passed-with asymmetry) on a contract-conformant Goals shape |
| A concurrent sibling edits one of the three target files between read and write | M | L | None of the four concurrent siblings (398, 451, 463, 537) declares any of this plan's three files. Re-read each file immediately before editing, stage only this task's own hunks with an explicit file list, and never run `git-snapshot.sh` in its reverting default mode, per the dispatch's concurrency note |
| Editing `plan_goals_preamble.md` perturbs `test-lean-challenge-snapshot.sh`'s expectations | L | L | The edited text is non-bulleted preamble prose, which that script's leading-run reader structurally never scans; Phase 3 nonetheless runs the snapshot suite as its verification |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Narrow the fallback harvest and re-baseline the four affected cases [COMPLETED]

**Goal**: Replace `lean-plan-compliance-check.sh`'s whole-range Goals-prose backtick sweep with a
per-bullet leading-identifier-run extraction, and bring the four existing test cases whose
harvested sets legitimately change under that narrowing back to green — deliberately, with each
change's rationale recorded in the case's own header comment.

**Tasks**:

- [x] Re-read `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` immediately
      before editing (concurrency note), confirming the fallback branch is still the
      `else` arm of the `if [ -n "$challenge_names_raw" ]` conditional at approximately
      lines 227-230. *(completed)*
- [x] Replace the fallback harvest's single whole-range sweep with the two-stage leading-run
      form: stage one matches each line's bullet marker and its maximal leading run of
      backtick-delimited identifiers separated only by whitespace, `,`, `/`, or `and`
      (`grep -oP '^\s*-\s*\K(?:` + backtick + `$IDENT_PCRE` + backtick + `|[\s,/]|and\b)+'`);
      stage two re-extracts the individual backticked tokens from the captured run with the
      script's existing `grep -oP` + `tr -d` + `sort -u` pipeline. A non-bulleted line
      (preamble prose, interstitial prose, a wrapped continuation line) matches nothing in stage
      one and so is never scanned — the single per-line bullet check is the entire gate, mirroring
      the Python's structural preamble exclusion without a dedicated flag.
      *(deviation: altered — the literal `\s*-\s*\K` quantifiers are plain/greedy, and grep -P
      verifiably backtracks them to donate the bullet's own single separating space to the
      `(?:...)+` alternation (which itself accepts a bare whitespace character) whenever the
      bullet's first content is non-backtick prose, producing a spurious one-character match
      instead of no match at all — reproduced live against the C13 archived-plan shape before
      editing. Implemented as `^\s*+-\s*+\K(?:...)+` instead, with POSSESSIVE `*+` quantifiers on
      the two prefix pieces only; the alternation's own quantifier and contents are unchanged from
      the plan's literal text. Re-verified against all three of the plan's own research-time test
      shapes (measured-defect prose, four-identifier conformant run, prose-leading bullet) plus
      the Scope Hypothesis table below, all matching exactly)*
- [x] Keep this script's own **dotted** `IDENT_PCRE` in both stages. Do NOT substitute
      `lean-challenge-snapshot.sh`'s non-dotted `LEAN_IDENT_PATTERN` (`[^\W\d][\w']*`): the two
      patterns differ deliberately, and this script's dotted form is what the landed
      `DECLARATION-KIND AND DOTTED-NAME WIDENING` depends on. *(completed)*
- [x] Keep `is_excluded_token()` applied to the harvested set unchanged, as a redundant second
      guard rather than removed, matching `lean-challenge-snapshot.sh`'s own stated precedent for
      its `LEAN_KEYWORDS` list. *(completed)*
- [x] Add a new named section to the script's header comment block — a third entry alongside
      `RESERVED-KEYWORD DENYLIST` and `COLON-OPTIONAL GOALS RANGE` — stating that the Goals-prose
      fallback now harvests only each bullet's leading identifier run, that this is the behaviour
      `plan-format.md`'s `## Lean Challenge Statements` section already documents, and that it
      mirrors (independently, not as shared code) `lean-challenge-snapshot.sh`'s
      `extract_goal_names()`. Include the `SHARED FRAGILITY` cross-reference in the same shape the
      sibling script uses. *(completed: LEADING-IDENTIFIER-RUN GOALS-PROSE HARVEST section added)*
- [x] Add a one-line comment at the Goals-range `sed` call recording the deferred header-shape
      gap: this script's range anchor (`^\*\*Goals\*\*`) does not accept the list-item
      `- **Goals**:` form that `lean-challenge-snapshot.sh`'s `START_RE` (`^-?\s?\*\*Goals\*\*`)
      accepts, and that divergence is deliberately out of this change's scope — pointing at
      `specs/504_lean_goals_block_harvest_contract/reports/01_goals-block-harvest-contract.md`.
      Do not fix it here. *(completed)*
- [x] Run the suite and confirm the failing set is exactly C13, C14, C15, C16 (this is the
      Scope Hypothesis's confirmation step — if a fifth case fails, or one of these four passes,
      STOP and reconcile before editing any test case). *(completed: confirmed exactly C13, C14,
      C15, C16 failed, 15 passed — matches the Scope Hypothesis exactly)*
- [x] Rewrite C14's Goals bullet into the already-documented contract-conformant leading-run
      shape (the four identifiers as one leading backtick list separated by `,`/`and`, with the
      descriptive prose following), preserving the case's subject — declaration-kind recognition —
      exactly. Add a one-line note in its header comment that the bullet was brought into
      conformance with the leading-run contract, not that its subject changed. *(completed)*
- [x] Rewrite C15's Goals bullet the same way (`factoring`, `Frame.factoring` and `carrier` as a
      leading run), preserving the structure-field-fallback subject and the same header note.
      *(completed)*
- [x] Rewrite C16's Goals bullet the same way, with `Mods.Deep` moved into the leading run so the
      module-path fallback stays exercised, and the same header note. *(completed)*
- [x] Re-baseline C13 WITHOUT altering its fixture text. Its Goals bullet is the archived
      refutation plan's real shape — prose-leading, with the identifiers cited mid-sentence — and
      preserving it verbatim is the whole point of the case. Its new honest outcome is
      `COMPLIANCE_CHECK: skipped` (exit 0) for both the no-polarity and the with-polarity run,
      because a non-conformant Goals block now contributes zero identifiers. Record this in a
      `SUPERSEDED` header comment in the same explicit shape C5 and C6 already use, naming the
      narrowing that superseded it and stating that the archived plan's Goals block is
      non-conformant under the documented contract. *(completed)*
- [x] Add companion case C20 preserving C13's actual regression intent on a contract-conformant
      Goals shape: the same refutation scenario with the identifiers leading the bullet, asserting
      `failed` without the `- **Goal Polarity**: refutation` line and `passed` with it. This keeps
      the polarity asymmetry pinned now that C13 itself skips. *(completed)*
- [x] Re-run the full suite and confirm 20 passed, 0 failed. *(completed: 20 passed, 0 failed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: exactly four of the nineteen existing cases (C13, C14, C15, C16) change
their harvested name set under the narrowing, and C18 does not. Established by simulating the
leading-run algorithm against each case's Goals block during planning, not by running the
modified script. The implementer confirms it mechanically by running the suite immediately after
the script edit and before touching any test case, and compares the actual failing set against
this list; a divergence means the port is wrong, not that this hypothesis should be adjusted.

**Tier Justification**: `bash agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
is the exact covering check — it is this script's own characterization-plus-regression suite, and
its C16/C17 cases specifically cover the dotted-name resolution the port could regress.

**Files to modify**:

- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` - fallback Goals-prose
  harvest narrowed to the leading-identifier-run two-stage form; new header-comment section for
  the third narrowing with its `SHARED FRAGILITY` cross-reference; one-line deferred
  header-shape-gap comment at the `sed` call.
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` - C14/C15/C16
  Goals bullets rewritten into contract-conformant leading runs with per-case notes; C13
  re-baselined to `skipped` with an explicit `SUPERSEDED` header comment and its fixture text
  unchanged; new case C20 preserving the refutation-polarity regression on a conformant shape.

**Verification**:

- The full suite reports `Results: 20 passed, 0 failed` and exits 0.
- The measured defect's exact prose shape, with no `## Lean Challenge Statements` section, no
  longer produces spurious `[MISSING]` lines: a scratch plan whose Goals bullet reads
  `` - `foo_bar` -- ... pre-existing lemma `plusValidIn_reflectTime` and `lcN_plusValidZTime`, for
  binder `P` with hypothesis `hP`. `` yields `[OK] foo_bar` alone and
  `COMPLIANCE_CHECK: passed` (exit 0) — no `P`, `hP`, `plusValidIn_reflectTime`, or
  `lcN_plusValidZTime` line anywhere in the output.
- `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
  **exits 0** (its documented no-findings contract; exit 1 means findings, exit 70 means the
  binary is unresolvable and is a failure, never a skip). Confirmed clean at planning time, so
  exit 0 is the correct bar rather than a baseline diff.
- The script's header comment block names the third narrowing, and the `sed` call carries the
  deferred-gap comment.

---

### Phase 2: Add the record's required regression coverage [COMPLETED]

**Goal**: Pin the measured defect as a permanent regression case, and give the
`CHALLENGE-STATEMENTS-PREFERRED HARVEST` feature its first test coverage so the two harvest paths
cannot be confused by a future fixture author.

**Tasks**:

- [x] Re-read `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
      immediately before editing. *(completed)*
- [x] Add case C21 — the record's minimum verification bar. A plan whose Goals block cites a
      pre-existing lemma and a binder name in trailing prose, with **no**
      `## Lean Challenge Statements` section at all (so the fallback harvest is genuinely the
      active path, not the already-working preferred one), under default must-exist polarity.
      Assert the exact harvested set, not just the verdict: `[OK]` for the one leading identifier,
      `COMPLIANCE_CHECK: passed`, exit 0, and the explicit *absence* of any output line mentioning
      the prose-cited binder names or pre-existing lemma names. Name the measured provenance in
      the case's header comment. *(completed)*
- [x] State in C21's header comment why the fixture omits the Challenge Statements section: with
      one present and populated, the preferred harvest would take precedence and the case would
      pass today unchanged, proving nothing about this narrowing. *(completed)*
- [x] Add case C22 — the first coverage of the `CHALLENGE-STATEMENTS-PREFERRED HARVEST` feature.
      The same Goals prose as C21, but *with* a populated `## Lean Challenge Statements` section
      declaring the one real goal with a `sorry` body. Assert that the harvest source reported in
      the `skipped`/verdict path is the Challenge Statements section, that the one declared
      identifier is `[OK]`, and that no prose-cited token appears in the output. This pins the
      precedence that makes C21's fixture design load-bearing.
      *(deviation: altered — `harvest_source` is mechanically verified to be emitted only on the
      `skipped` verdict's own echo (the one call site in lean-plan-compliance-check.sh), never on
      a passing/failing one, so there is no literal "harvest source" string in stdout for a
      passing case like C22 to assert against. Asserted the same precedence structurally instead:
      exactly one `[OK]` line (the Challenge-declared `comm`) and the absence of every
      trailing-prose name, documented in C22's own header comment alongside why the exact-set
      assertion alone cannot distinguish the two harvest paths on this fixture (both would
      harvest `comm` as the leading Goals-bullet identifier too) and what does distinguish them
      (inspection of the `if [ -n "$challenge_names_raw" ]` dispatch))*
- [x] Re-run the full suite and confirm 22 passed, 0 failed. *(completed: 22 passed, 0 failed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the edit adds cases to one test file and changes no production code, so
`bash agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` is the
complete covering check for it.

**Files to modify**:

- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` - new case C21
  (measured-defect regression, no Challenge Statements section, exact-set assertion) and new case
  C22 (Challenge-preferred-harvest precedence, first coverage of that feature).

**Verification**:

- The full suite reports `Results: 22 passed, 0 failed` and exits 0.
- C21 fails when the Phase 1 narrowing is reverted locally (confirming the case actually
  exercises the fallback path rather than passing vacuously); restore the narrowing afterward.
- C21's fixture body contains no `## Lean Challenge Statements` heading, confirmed by reading it.

---

### Phase 3: Correct the stale `plan_goals_preamble.md` fixture comment [COMPLETED]

**Goal**: Remove the fixture prose that tells a future reader the snapshot tool reads every
backticked token in a Goals block as a Goal — a statement that has been false since the
leading-run narrowing landed in the very script the fixture serves.

**Tasks**:

- [x] Re-read
      `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md`
      immediately before editing. Confirm no concurrent sibling has modified it (none declares it
      in `file_scope`). *(completed: confirmed against the dispatch's own territory JSON — neither
      task 398 nor 451's file_scope lists this fixture)*
- [x] Correct the preamble paragraph's final sentence, which currently reads "No other identifier
      is backticked in this block, because the snapshot tool reads every backticked token here as
      a Goal." Replace it with a statement of the current rule: only a bullet's leading identifier
      run contributes goal names, so backticked identifiers in this preamble paragraph (and in any
      bullet's trailing prose) are never harvested. Keep the paragraph's actual purpose — the
      fixture exercises preamble-prose exclusion — intact, and keep every existing backticked
      token in it, since those tokens are precisely what the fixture is testing the exclusion of.
      *(completed)*
- [x] Change nothing else in the fixture: not the `**Goals**` bullets, not the
      `## Lean Challenge Statements` block, not the plan metadata header. *(completed: confirmed
      via `git diff` — only the preamble paragraph's final two sentences changed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
is the one suite that reads this fixture, and it is the complete covering check for a prose-only
edit to it.

**Files to modify**:

- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md` -
  preamble paragraph's stale claim about whole-block backtick harvesting corrected to the current
  leading-run rule.

**Verification**:

- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` exits 0 with
  no failed cases, unchanged from its pre-edit result.
- The fixture's `**Goals**` bullets, Challenge Statements block, and metadata header are
  byte-identical to their pre-edit state (`git diff` on the file shows only the preamble
  paragraph).

---

### Phase 4: Final verification and deferred-observation record [COMPLETED]

**Goal**: Confirm both lean test suites and the touched-path checks are green together, and record
the two deliberately deferred follow-ups so neither is rediscovered from scratch.

**Tasks**:

- [x] Run `bash agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
      and `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
      together and confirm both exit 0. *(completed: 22 passed/0 failed and 37 passed/0
      failed/0 skipped respectively, both exit 0)*
- [x] Run the repository's sanctioned shellcheck gate on both modified shell files —
      `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
      — and confirm it **exits 0**. Do not invoke the `shellcheck` binary directly, and do not
      substitute a stdout diff against a captured baseline for the exit-status check.
      *(completed: exits 0, 0 findings)*
- [x] Confirm `git status --short` shows exactly the three files this plan declares as modified,
      and nothing else; if a foreign modification or commit is present, STOP and report it after
      checking `git log` to confirm the work is not this task's own, per the dispatch's
      concurrency note. *(completed: this task's three declared files are fully committed with
      no pending diff; `git status --short` shows other paths, but every one belongs to a
      concurrently-dispatched sibling task's own in-flight work this cycle (451, 683, and the
      shared specs/ event logs) per this dispatch's own Territory/concurrency note — none
      overlaps this task's file_scope, so this is not a foreign modification of this task's own
      files and nothing was STOPped on)*
- [x] Record, in the implementation summary, the two deferred follow-ups as observations: (i) the
      Goals-range header-shape acceptance gap (list-item `- **Goals**:` not recognised by
      `lean-plan-compliance-check.sh`, already recognised by `lean-challenge-snapshot.sh`'s
      `START_RE`), which now has a code comment pointing at the research report; and (ii) the
      `context/project/lean4/patterns/goals-block-reader-parity.md` context file the research
      recommends, deferred because registering it requires editing
      `agent-system/extensions/lean/index-entries.json`, which concurrent sibling task 398
      declares in its own `file_scope` this cycle. *(completed — see summary)*
- [x] Record, in the implementation summary, that this is the **third** narrowing of one
      over-broad harvest, and that the two readers' harvest breadth is now in agreement while
      their accepted *header* shapes are not — the standing residual the parity context file in
      (ii) above would document. *(completed — see summary)*

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:

- *(none — this phase verifies and records; it edits no file outside `specs/`)*

**Verification**:

- Under `/orchestrate`, this phase's own in-dispatch obligation is the **scoped touched-path
  check** — both lean test suites above, plus
  `bash .claude/scripts/lint/lint-shellcheck.sh` over the two modified shell files exiting 0, run
  against this plan's three declared paths — together with an **explicit deferral of the complete
  gate set to the orchestration close** (Move 4). This phase does not invoke the full battery
  itself.
- Run standalone and outside `/orchestrate` (no orchestration close to defer to), this phase runs
  the complete gate set directly instead: `bash .claude/scripts/tests/run-all.sh` and
  `bash .claude/scripts/verify-deploy.sh`, each exiting 0, in addition to the scoped checks above.
- Both deferred follow-ups and the third-narrowing observation appear in the implementation
  summary.

---

## Testing & Validation

- [x] `bash agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` —
      22 passed, 0 failed, exit 0. *(completed)*
- [x] `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` —
      unchanged result, exit 0. *(completed: 37 passed, 0 failed, 0 skipped)*
- [x] The measured defect's exact prose shape, with no Challenge Statements section, yields only
      the leading identifier `[OK]` and `COMPLIANCE_CHECK: passed`. *(completed)*
- [x] C21 demonstrably fails against a locally reverted narrowing (non-vacuous regression).
      *(completed)*
- [x] C16/C17 stay green, confirming the dotted-name widening survived the port. *(completed)*
- [x] `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
      exits 0. *(completed)*
- [x] `git status --short` shows exactly the three declared files, plus this task's own `specs/`
      artifacts. *(completed: three declared files fully committed/clean; other working-tree
      entries are concurrent siblings' own in-flight work, outside this task's file_scope)*

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` — fallback Goals-prose
  harvest narrowed to the leading-identifier-run; header comment documenting the third narrowing;
  deferred header-shape-gap comment.
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` — C13
  re-baselined with explicit supersession, C14/C15/C16 bullets brought into contract conformance,
  new cases C20 (refutation-polarity regression on a conformant shape), C21 (measured-defect
  regression), C22 (Challenge-preferred-harvest precedence).
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md` — stale
  harvest claim corrected.
- `specs/504_lean_goals_block_harvest_contract/summaries/01_goals-block-harvest-contract-summary.md`
  — implementation summary carrying the two deferred follow-ups and the third-narrowing
  observation.

## Rollback/Contingency

Each phase is a single-concern edit to one or two files with a suite as its covering check, so the
ordinary contingency is to revert the phase's own commit. If the Phase 1 port proves
irreconcilable — for instance if the suite's failing set diverges from the Scope Hypothesis in a
way that implicates the dotted-`IDENT_PCRE` interaction rather than the fixtures — stop at the
Scope Hypothesis confirmation step, before any test case is edited, and report rather than
adjusting the hypothesis: the script change is the only thing committed at that point and is
revertible on its own.

For a rollback that must discard uncommitted work, take the snapshot first per
`context/contracts/recovery.md`'s rollback rung (which is also what makes the subsequent
destructive command admissible to `guard-destructive-git.sh`), then perform the revert. Do **not**
emit `git-snapshot.sh 504` in its default reverting form as a routine start-of-phase checkpoint;
if a defensive checkpoint is wanted before Phase 1's atomic batch, use
`bash .claude/scripts/git-snapshot.sh 504 --no-revert`, which is durable without reverting the
working tree — the correct form under this cycle's concurrency note, which forbids the reverting
default outright.
