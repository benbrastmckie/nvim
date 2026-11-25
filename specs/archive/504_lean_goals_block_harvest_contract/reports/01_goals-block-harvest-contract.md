# Research Report: Task #504

**Task**: 504 - Lean Goals-block harvest contract (MEASURED {871, iss_1793913951568_HzkOMJ})
**Started**: 2026-11-22
**Completed**: 2026-11-22
**Effort**: small (script change + fixture/test additions)
**Dependencies**: None
**Research Inputs**: Codebase exploration (source store), empirical repro against the live
script, git history of both Goals-block readers, cross-repo issue-log citation
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The decision is settled: **(a) — narrow the script.** `lean-plan-compliance-check.sh`'s legacy
  Goals-prose fallback harvest (used when no `## Lean Challenge Statements` section yields names,
  or under refutation polarity) still does a whole-range backtick sweep, while its sibling reader
  `lean-challenge-snapshot.sh`'s `extract_goal_names()` was narrowed to a per-bullet
  **leading-identifier-run** on 2026-11-04 (commit `8d3ab3283`) — the same commit that wrote
  `plan-format.md`'s current "identifiers must LEAD the bullet" contract language. The document
  already states decision (a)'s contract, and one of the two readers already implements it,
  tested against exactly this failure class (preamble prose, trailing prose, both keyword and
  non-keyword tokens). `lean-plan-compliance-check.sh`'s fallback is the one reader out of step.
- The already-landed `CHALLENGE-STATEMENTS-PREFERRED HARVEST` (2026-11-09, commit `614922216`)
  **already closes the common case**: for a well-formed lean plan (Challenge Statements section
  present and populated, must-exist polarity — the mandatory shape per `plan-format.md`), the
  Goals-prose fallback is never reached at all, so today's script already passes the exact
  prose shape that caused the measured defect, verified empirically below. The MEASURED defect at
  task 871 predates that harvest-preference feature by four days.
- The fallback is still live, and still buggy, in two residual cases: (1) `goal_polarity:
  refutation` plans, which explicitly bypass the Challenge-preferred harvest unconditionally, and
  (2) any lean/lean4 plan whose `## Lean Challenge Statements` section is missing, mis-headed, or
  otherwise yields zero declaration names (a contract violation the script does not itself
  enforce, so it degrades silently to the legacy path instead of erroring). Verified empirically:
  a Goals bullet reading `` `foo_bar` -- ... pre-existing lemma `plusValidIn_reflectTime` and
  `lcN_plusValidZTime`, for binder `P` with hypothesis `hP`. `` with no Challenge Statements
  section present currently produces `COMPLIANCE_CHECK: failed` with four spurious `[MISSING]`
  lines (`hP`, `lcN_plusValidZTime`, `P`, `plusValidIn_reflectTime`) even though the plan's one
  real goal (`foo_bar`) is present and correctly reported `[OK]`.
- The existing shape-based exclusions (`is_excluded_token`: reserved keywords, lowercase-rooted
  dotted projections, filename-shaped tokens) **cannot** close this gap by addition: binder names
  (`P`, `hP`) and ordinary-looking pre-existing identifiers have no distinguishing shape to
  exclude on. Only a *positional* narrowing (leading-run) generalizes, which is exactly what
  `lean-challenge-snapshot.sh` already proved out.
- A second, narrower, explicitly out-of-scope-for-this-decision finding: the Goals-range `sed`
  start anchor in `lean-plan-compliance-check.sh` (`^\*\*Goals\*\*`) does not accept the
  list-item `- **Goals**:` header shape that `lean-challenge-snapshot.sh`'s own `START_RE`
  (`^-?\s?\*\*Goals\*\*`) already accepts — verified empirically (the spot-check silently
  reports `skipped (no non-keyword identifiers found...)` for a plan using that shape, rather
  than finding the real goal). This is a related but distinct divergence in which *header* shapes
  the two readers accept, not the harvest-breadth question this record owns; flagged for the
  implementer touching this code region, not folded into the Recommendations below.

## Context & Scope

This record settles ONE disagreement: `lean-plan-compliance-check.sh`'s Goals-block harvest
versus `plan-format.md`'s `## Lean Challenge Statements` section's documented contract on what a
plan's `**Goals**` block contributes as goal declarations. The script's own header already
documents two prior narrowings (reserved-keyword denylist; colon-optional Goals range) plus a
third (`DECLARATION-KIND AND DOTTED-NAME WIDENING`'s harvest exclusions) and a fourth mechanism
(`CHALLENGE-STATEMENTS-PREFERRED HARVEST`) that changes which *section* is read, not how the
Goals-prose range itself is parsed when it is the active source. This research traced:

1. The exact mechanism in both scripts that read a plan's Goals block
   (`lean-plan-compliance-check.sh`'s fallback harvest and `lean-challenge-snapshot.sh`'s
   `extract_goal_names()`), per the dispatch's instruction to verify the mechanism rather than
   trust the summary.
2. The cross-repo provenance of the MEASURED defect (BimodalLogic task 871,
   `iss_1793913951568_HzkOMJ`), including the actual plan text that triggered it.
3. Whether the already-landed `CHALLENGE-STATEMENTS-PREFERRED HARVEST` (which postdates the
   measured defect) already closes the gap for well-formed plans, verified empirically rather
   than by inspection alone.
4. The existing test fixture conventions for both scripts' suites, to ground the Verification
   section's required regression fixture.

Out of scope, per the dispatch's own Scope Boundary: BimodalLogic backlog records #813 (Challenge
block precedence/snapshot-prerequisite rules) and #824 (fixture-dependent gate statement under
`lean-challenge-snapshot.sh`) — neither touched. Also out of scope: the Goals-range *header-shape*
acceptance gap (list-item form) noted above — it is adjacent code, not this disagreement.

## Findings

### Codebase Patterns

**The two Goals-block readers, and their current divergence.**

- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` lines 227-230 (legacy
  fallback, active when no Challenge Statements names are harvested):
  ```
  goal_names_raw=$(sed -n '/^\*\*Goals\*\*/,/^\*\*/p' "$plan_file" \
    | grep -oP '`'"$IDENT_PCRE"'`' | tr -d '`' | sort -u)
  ```
  This sweeps **every** backticked identifier-shaped token in the whole Goals range — bullet
  leads, trailing prose on the same bullet, and multi-line continuation prose alike — then only
  afterward subtracts `is_excluded_token()`'s shape-based denylist (keywords, lowercase-dotted
  projections, filename extensions).

- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`'s `extract_goal_names()`
  (lines 460-528) was rewritten in commit `8d3ab3283` ("lean-challenge-snapshot: narrow the
  Goals harvest to an identifier-leading bullet position", 2026-11-04) to a **leading-identifier-
  run** extraction: only a bulleted line's maximal run of backtick-delimited identifiers
  immediately after its `- ` marker (tokens separated only by whitespace, `,`, `/`, or `and`)
  contributes names; everything after that run on the same bullet, every non-bulleted preamble
  or interstitial line, and the bullet-marker line's own non-identifier content are structurally
  never scanned. The same commit added `plan-format.md`'s current contract language ("identifiers
  must LEAD the bullet... with any descriptive prose for that bullet following afterward") —
  i.e., the document was written specifically to describe this reader's behaviour.

- `lean-challenge-snapshot.sh`'s own test suite (`test-lean-challenge-snapshot.sh`) has a
  dedicated case, **R14**, whose header comment states explicitly: *"This is the measured
  residual this record exists to close: ... a bullet reading (trailing prose only) '...
  established in the `Nu` namespace, providing a `witness` for the `EUFix` operator when the flag
  is `true`.'"* — the identical failure *shape* (non-keyword, non-filename-shaped tokens in
  trailing bullet prose) as this record's MEASURED defect, already reproduced, fixed, and pinned
  for the sibling script. R7 (keyword-shaped trailing tokens) and R8 (preamble-paragraph tokens,
  explicitly citing a real landed-plan regression) are the other two legs of the same
  leading-run narrowing's test coverage.

**The already-landed Challenge-preferred harvest already masks the common case (verified).**

`lean-plan-compliance-check.sh`'s `CHALLENGE-STATEMENTS-PREFERRED HARVEST` (commit `614922216`,
2026-11-09) harvests from the `## Lean Challenge Statements` section's own declaration lines
instead of Goals prose whenever that section yields at least one name, for any non-refutation
plan. I constructed the MEASURED defect's exact prose shape with a Challenge Statements section
present and confirmed it passes cleanly today:

```
**Goals**:
- `foo_bar` -- the result, stated as a corollary of the pre-existing lemma
  `plusValidIn_reflectTime` and `lcN_plusValidZTime`, for binder `P` with hypothesis `hP`.

## Lean Challenge Statements
​```lean
theorem foo_bar (n : Nat) : n = n := sorry
​```
```
→ `[OK] foo_bar — found in the resolved source roots` / `COMPLIANCE_CHECK: passed` (exit 0).
None of `P`, `hP`, `plusValidIn_reflectTime`, `lcN_plusValidZTime` are harvested at all, because
the Goals-prose scan is never reached.

Cross-checked against the actual BimodalLogic task-871 plan
(`specs/archive/871_lcu_omega_chain_record_repair/plans/01_lcu-omega-chain-record-repair.md`,
gitignored, read directly): it DOES carry a populated `## Lean Challenge Statements` section with
exactly the three Goals identifiers (`stg_step`, `omega_chain`,
`lcN_reflectTime_plusValidZTime`) as its fenced block's top-level declarations, inside a
`Challenge` sub-namespace — the docstrings above those declarations are where `P`, `hP`,
`plusValidIn_reflectTime`, and `lcN_plusValidZTime` actually appear (as descriptive prose, not as
declaration lines), so today's preferred-harvest would not re-trigger this exact instance. The
measured defect occurred because, at the 2026-11-05 run that produced it, the
Challenge-preferred-harvest feature did not exist yet (it landed four days later) — confirmed via
`git log -S "CHALLENGE-STATEMENTS-PREFERRED"`.

**The fallback is still reachable and still buggy (verified).** Removing the Challenge Statements
section from the same repro (simulating either a `refutation`-polarity plan, which always
bypasses the preferred harvest, or any plan whose Challenge Statements section is missing/
mis-headed — not itself validated by this script) reproduces the failure live:

```
**Goals**:
- `foo_bar` -- the result, stated as a corollary of the pre-existing lemma
  `plusValidIn_reflectTime` and `lcN_plusValidZTime`, for binder `P` with hypothesis `hP`.
```
(no Challenge Statements section) →
```
  [OK] foo_bar — found in the resolved source roots
  [MISSING] hP — not found in the resolved source roots
  [MISSING] lcN_plusValidZTime — not found in the resolved source roots
  [MISSING] P — not found in the resolved source roots
  [MISSING] plusValidIn_reflectTime — not found in the resolved source roots
COMPLIANCE_CHECK: failed
```
(exit 1) — the exact permanently-failing symptom the dispatch describes, still live today in the
fallback path.

**Why shape-based exclusion (the existing precedent) cannot close this gap by addition.**
`is_excluded_token()` already excludes reserved keywords, lowercase-rooted dotted projections,
and filename-shaped tokens (test case C18 in `test-lean-plan-compliance-check.sh` exercises
exactly this: a trailing-prose bullet with `` `fine.taskRel` ``, `` `Refinement.lean` ``, and
`` `LogosManual.pdf` `` is correctly excluded). But `P`, `hP`, and
`plusValidIn_reflectTime`/`lcN_plusValidZTime` have **no excludable shape** — they are plain,
well-formed identifier tokens, indistinguishable by pattern from a real Goal identifier. A fifth
shape-exclusion rule cannot be written for "looks like a binder name" or "looks like a
cross-referenced pre-existing lemma." Only a *positional* rule (leading-run) structurally removes
this class, which is precisely what `lean-challenge-snapshot.sh` already does.

**A related, narrower, out-of-scope-for-this-decision gap in header-shape acceptance (verified,
flagged only).** `lean-plan-compliance-check.sh`'s Goals-range start anchor
(`sed -n '/^\*\*Goals\*\*/,/^\*\*/p'`) requires a line starting literally with `**Goals**`. A
plan using the list-item header shape (`- **Goals**:` with nested `  - `comm`...` bullets — the
same shape `lean-challenge-snapshot.sh`'s own `START_RE` (`^-?\s?\*\*Goals\*\*`) already accepts,
and the same shape `plan_list_item_goals.md` exercises for that script's suite) is **not**
recognised at all by `lean-plan-compliance-check.sh`: the spot-check silently reports
`COMPLIANCE_CHECK: skipped (no non-keyword identifiers found...)` instead of finding the real
goal — verified empirically. This is a distinct divergence (which Goals *headers* the two readers
recognise) from the harvest-breadth disagreement this record owns, and is not folded into the
decision below, but it sits in the same code region any implementer of decision (a) will touch,
so it is flagged here rather than left to be rediscovered.

**Test coverage gap.** `test-lean-plan-compliance-check.sh` (559 lines, cases C1-C19) has **no**
case at all exercising the `CHALLENGE-STATEMENTS-PREFERRED HARVEST` feature introduced in commit
`614922216`, despite that feature's own multi-paragraph header-comment rationale. Any regression
fixture added for this record's fix must deliberately avoid a populated Challenge Statements
section (or use `refutation` polarity) — otherwise the Challenge-preferred harvest will mask the
fallback-harvest code path entirely and the new fixture will pass today, unchanged, proving
nothing about the fix.

### External Resources

Not applicable — this is a self-contained shell-script/documentation contract internal to this
repository's agent-system source store; no external library or API is involved.

## Recommendations

1. **Adopt decision (a).** Narrow `lean-plan-compliance-check.sh`'s legacy Goals-prose fallback
   harvest (`lean-plan-compliance-check.sh` lines ~227-230, the `else` branch of the
   `challenge_names_raw` conditional) to the same per-bullet **leading-identifier-run** algorithm
   `lean-challenge-snapshot.sh`'s `extract_goal_names()` already implements — independently
   reimplemented in bash/grep (matching this codebase's existing "SHARED FRAGILITY" convention
   for the two readers' colon-optional-range and `LEAN_KEYWORDS` duplication; do not attempt to
   unify the bash and Python implementations into shared code in this phase). Concretely:
   - For each line in the existing `sed`-extracted Goals range, first test whether it is a
     bulleted line (`^\s*-\s*`); a non-bulleted line (preamble or interstitial prose) contributes
     nothing, mirroring the Python's structural preamble exclusion.
   - For a bulleted line, extract the maximal leading run matching
     `(?:` + `` ` `` + `$IDENT_PCRE` + `` ` `` + `|[\s,/]|and\b)+` immediately after the bullet
     marker (two-stage `grep -oP`, matching the run first and then re-extracting individual
     backticked tokens from it — mirrors `LEADING_RUN_RE` then `TOKEN_RE.findall` in the Python).
   - Keep `is_excluded_token()` (`LEAN_KEYWORDS` plus the lowercase-dotted/filename-shaped
     exclusions) as a **redundant second guard**, not removed — matching
     `lean-challenge-snapshot.sh`'s own stated precedent ("`LEAN_KEYWORDS` is kept as a redundant
     second guard rather than removed").
   - This change touches only the fallback branch; the `CHALLENGE-STATEMENTS-PREFERRED HARVEST`
     branch, `find_decl_files`/`find_field_files`/`find_module_files`, and the
     `replacement_targets` integrity sweep are unaffected.
2. **Do not pursue decision (b).** Widening `plan-format.md` to document "no backticks in Goals
   prose except goal identifiers" as an explicit authoring rule would codify a workaround the
   codebase has already structurally obsoleted for one of its two readers (and the document
   already states the opposite: identifiers lead, prose follows, freely, backticks and all —
   verified in `plan_goals_preamble.md`'s own prose, which currently reads "No other identifier is
   backticked in this block, because the snapshot tool reads every backticked token here as a
   Goal" — a comment that is now **stale** relative to `lean-challenge-snapshot.sh`'s actual
   leading-run behaviour and should be corrected or removed when this record's fix lands, so a
   future reader is not misled by it).
3. **Do not expand this record to the header-shape gap** (list-item `- **Goals**:` recognition).
   Note it for the implementing agent as a one-line comment addition near the Goals-range `sed`
   call (pointing at this report) rather than silently fixing it as a drive-by, per the
   dispatch's scope discipline; a separate record is the right home for deciding whether to widen
   `lean-plan-compliance-check.sh`'s own `START_RE`-equivalent to match
   `lean-challenge-snapshot.sh`'s.
4. **Correct the stale `plan_goals_preamble.md` fixture comment** (the
   `lean-challenge-snapshot.sh` suite's own fixture, not a new file) as a small, independently
   justified cleanup alongside the main fix, since it directly misstates the current, already-
   fixed behaviour of the script it is a fixture for.

## Decisions

- **Decision: pursue (a), narrow the script** — `lean-plan-compliance-check.sh`'s Goals-prose
  fallback harvest will be rewritten to a leading-identifier-run extraction, matching
  `lean-challenge-snapshot.sh`'s already-landed, already-tested behaviour and the already-written
  `plan-format.md` contract. Rejected alternative (b) — widening the document to describe the
  script's over-broad behaviour as an authoring rule — is rejected on its own merits: it would
  formalise a workaround (stripping backticks from Goals prose) that this codebase has already
  structurally eliminated for one of its two Goals-block readers, and the keyword-exclusion
  precedent already in the script established narrowing-the-harvest as this codebase's
  consistent response to this exact class of false positive.
- **Decision: the risk the dispatch raised against (a) — that a leading-identifier rule
  mis-parses the multi-line and parenthesized Goals shapes the test fixtures cover — does not
  materialize**, because those fixtures (`plan_r19_multiline_paren_goals.md`,
  `plan_r18_paren_goals.md`, `plan_list_item_goals.md`, `plan_goals_preamble.md`) are
  `lean-challenge-snapshot.sh`'s OWN fixtures, already exercising and passing against the exact
  leading-identifier-run algorithm being ported — not an unproven design, but a proven one on
  precisely the shapes in question.
- **Decision: the header-shape (list-item `- **Goals**:`) recognition gap stays out of this
  record's scope**, per the dispatch's Scope Boundary discipline, and is handed to the
  implementing agent as a flagged-but-deferred observation rather than a silent drive-by fix.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A bash/grep reimplementation of the Python leading-run algorithm drifts subtly from the proven Python behaviour (e.g. a different PCRE quirk around `and\b` or the two-stage run-then-extract split) | M | M | Port the two-stage structure verbatim (match the run first, then re-extract tokens from the captured run substring) rather than attempting a single combined regex; add the SAME shape of regression fixture this report already demonstrated empirically (no-Challenge-Statements plan with prose-cited binder names and pre-existing lemma names) to the implementation's own verification, not only inherited from `lean-challenge-snapshot.sh`'s suite |
| A new fixture is added with a populated Challenge Statements section, accidentally exercising the ALREADY-FIXED preferred-harvest path instead of the fallback, producing a fixture that passes today unchanged and proves nothing | H (defeats the verification bar) | M (this report found zero existing test coverage of the preference logic, so there is no local precedent to copy from) | Explicitly omit (or mis-head) the Challenge Statements section in the new fixture, or use `refutation` polarity, and assert the exact harvested-name set (not just the verdict) so a future accidental re-widening is caught even if it does not flip pass/fail |
| The stale `plan_goals_preamble.md` fixture-comment correction is treated as in-scope for THIS record's edit but conflicts with sibling task territory on `lean-challenge-snapshot.sh`'s own test fixtures | L | L | Confirmed via the Territory block: no concurrent sibling in this cycle declares `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md` or `test-lean-challenge-snapshot.sh` in its `file_scope`; re-check immediately before editing per the standing concurrency note regardless |

## Context Extension Recommendations

- **Topic**: the two independently-maintained Goals-block readers' *header-shape* acceptance
  (colon-optional, parenthetical, list-item) is currently cross-referenced only in each script's
  own inline comments ("SHARED FRAGILITY... the two readers must not drift apart").
- **Gap**: nothing in `.claude/context/project/lean4/` centrally documents the full accepted
  Goals-block surface (header shapes AND harvest breadth) for both readers side by side, so the
  list-item header-shape gap found in this research (Findings, "related... gap") was discoverable
  only by independently testing both scripts, not by reading documentation.
- **Recommendation**: after this record's fix lands (bringing harvest breadth into agreement),
  a small follow-up context file under
  `context/project/lean4/patterns/goals-block-reader-parity.md` enumerating both readers' accepted
  header shapes and harvest rules side by side would let a future narrowing (or the deferred
  list-item header-shape fix) be checked against one table instead of two scripts' comments.

## Appendix

- Search queries / commands used:
  - `find agent-system/extensions/lean -iname "lean-plan-compliance-check.sh"`
  - `find agent-system -iname "plan-format.md"`
  - `git log --oneline -- agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh`
  - `git log --oneline --all -S "CHALLENGE-STATEMENTS-PREFERRED" -- .../lean-plan-compliance-check.sh`
  - `git log --oneline --all -S "LEADING_RUN_RE" -- .../lean-challenge-snapshot.sh`
  - `git show -s --format=%B 8d3ab3283` / `git show 8d3ab3283 -- .../plan-format.md`
  - `jq -c 'select(.entry_id=="iss_1793913951568_HzkOMJ")' ~/Projects/BimodalLogic/specs/archive/871_.../issues.jsonl`
  - Empirical repro: constructed `plan.md` / `plan_nochallenge.md` / `plan_listitem_nochallenge.md`
    fixtures in the scratchpad and ran `lean-plan-compliance-check.sh` directly against each,
    both with and without a `## Lean Challenge Statements` section.
- References:
  - `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` (the script under
    decision)
  - `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`'s `extract_goal_names()`
    (the sibling reader; the proven reference implementation for decision (a))
  - `agent-system/extensions/core/context/formats/plan-format.md`'s `## Lean Challenge
    Statements` section (the already-correct documented contract)
  - `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` (cases C1-C19;
    no case yet for the Challenge-preferred harvest)
  - `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` (cases R7, R8,
    R14 — the proven leading-run regression coverage to mirror)
  - `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md` (the
    stale-comment fixture)
  - BimodalLogic `specs/archive/871_lcu_omega_chain_record_repair/plans/01_lcu-omega-chain-record-repair.md`
    (the actual MEASURED-defect plan, read directly to confirm its Challenge Statements section)
  - BimodalLogic `specs/archive/871_lcu_omega_chain_record_repair/issues.jsonl`,
    `iss_1793913951568_HzkOMJ`
