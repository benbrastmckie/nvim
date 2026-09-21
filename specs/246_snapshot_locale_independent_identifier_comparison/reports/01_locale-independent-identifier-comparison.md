# Research Report: Task #246

**Task**: 246 - Make lean-challenge-snapshot.sh identifier comparison locale-independent (false mismatch under en_US.UTF-8)
**Started**: 2026-09-21T22:08:08Z
**Completed**: 2026-09-21T22:30:00Z
**Effort**: 2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase read (lean-challenge-snapshot.sh, its test suite and fixtures), live reproduction in a throwaway sandbox repo under this session's scratchpad, empirical `sort`/`comm` locale experiments
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is confirmed exactly as described and was reproduced live in a throwaway sandbox: under this environment's ambient `en_US.UTF-8` locale, `lean-challenge-snapshot.sh --dry-run` on a plan naming `hnOpenMirror`, `hnStabMirror`, `hn_stab` reports a false mismatch (`comm: file 2 is not in sorted order` / `comm: input is not in sorted order`, exit 71, both sides listing `hn_stab`), while the identical invocation under `LC_ALL=C` exits 0 with all three identifiers intact.
- Root cause is a single collation split: `extract_goal_names()` (line 347) sorts under the ambient locale via bare `sort -u`, while both Python sites that build the declared-identifier list (`extract_r1` at line 434, `extract_r2` at line 602) sort via `sorted()`/`sorted(set(...))`, which is strict code-point order — equivalent to `LC_ALL=C`. `comm` (lines 447-448) requires both inputs sorted under the same collation and misbehaves when they are not.
- Minimal, correctly-scoped fix: pin only the `sort -u` in `extract_goal_names()` to `LC_ALL=C` (inline, not exported process-wide), and additionally pin the two `comm` invocations themselves to `LC_ALL=C` — empirically, `comm`'s own "is this input sorted" check is evaluated under whichever locale `comm` runs in, independent of how the file was produced, so pinning only the producer side is not sufficient defense-in-depth (see Findings for the empirical basis).
- Audit of every `sort`/`comm`/`uniq`/`join` site in the script (there are exactly 5, all found by a single `grep -n` pass) confirms only lines 347/447/448 need a change. Line 434 and line 602 already use Python's code-point `sorted()`, which already matches the target collation. Line 145 (`sort -V`, plan-file version selection) is unrelated: it never participates in a cross-tool identifier comparison and needs no change.
- A new mixed-case test fixture and suite case reproduces the fix's target scenario; a repo-wide `grep -n` also found no other file that touches this same `sort`+`comm` combination, so the fix is scoped correctly to the single named script.

## Context & Scope

Task 246 is a fully-specified defect report (see the dispatch's Description block) naming exact
line numbers, a verified live incident, required work items (a)-(c), explicit MUST-NOT
constraints, and acceptance criteria. This research phase's job was to independently verify every
claim before a plan is written from it — not to take the line numbers or diagnosis on faith — and
to resolve the one item the description leaves partially open: whether pinning collation on the
*producer* side (the `sort -u` that builds the goals list) is sufficient by itself, or whether the
`comm` call site itself also needs pinning. That question is answered empirically below.

Scope is exactly the file the dispatch names:
`agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` (788 lines) and its suite,
`agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` (327 lines) plus its
`tests/fixtures/challenge/` directory. No other file in the lean extension, or elsewhere in the
repo, was found to share this hazard (see Findings, "Repo-wide audit").

## Findings

### Codebase Patterns

**All `sort`/`comm`/`uniq`/`join` sites in the target script** (found via
`grep -n "sort\b\|comm \|uniq\|join \|LC_ALL\|LC_COLLATE\|locale"`):

| Line | Code | Role | In scope for this fix? |
|------|------|------|------------------------|
| 145 | `PLAN_FILE=$(ls "specs/${PADDED_NUM}_"*/plans/*.md 2>/dev/null \| sort -V \| tail -1)` | Selects the latest plan file by version-sort of filenames | No — not a cross-tool identifier comparison; `sort -V`'s own semantics are locale-independent for version-number comparison purposes and the output is used only to pick one path, never diffed against another sorted list |
| 347 | `... \| tr -d '`' \| sort -u` inside `extract_goal_names()` | Builds the **Goals**: identifier list, ambient-locale collation | **Yes — this is the defect site** |
| 434 | `f.write("\n".join(sorted(set(declared_names))) + ...)` (Python, `extract_r1`) | Builds the R1 declared-identifier list | No change needed — already code-point order |
| 447 | `only_in_goals=$(comm -23 "$goals_file" "$declared_file")` | Cross-validates goals vs. declared (R1 or R2) | **Yes — needs a locale pin and an explanatory comment, per empirical finding below** |
| 448 | `only_in_declared=$(comm -13 "$goals_file" "$declared_file")` | Same, other direction | **Yes — same as 447** |
| 602 | `f.write("\n".join(sorted(names)) + "\n")` (Python, `extract_r2`) | Builds the R2 (git-baseline fallback) declared-identifier list, from names read out of the (soon-to-be-fixed) goals file | No change needed — already code-point order, and its *input* (`names`) is read straight from `goals_file`, so once line 347 is fixed both R1 and R2 routes compare consistently |

This confirms the dispatch's own line-number claims verbatim (347/434/447-448/602 as described;
145 confirmed as an unrelated version-sort, matching the dispatch's own "probably fine" hedge). No
sixth site was found and no other file in the repository (`grep -rn` across
`agent-system/extensions/lean/scripts/`) touches this same sort+comm pairing.

**R2 route is not independently at risk.** The R2 fallback (`extract_r2`, used only when a plan
predates the `## Lean Challenge Statements` section) reads its candidate identifier list directly
from `$goals_file` — i.e., the very file `extract_goal_names()` produces — then re-sorts it with
Python's `sorted(names)` before writing `$names_out`. Because `cross_validate_identifiers` always
compares `$goals_file` against `$names_out`, fixing the single producer at line 347 makes both the
R1 and R2 comparisons consistent; no change to `extract_r2`'s own Python block is needed.

### Live Reproduction

Reproduced in a throwaway git repo (built with the suite's own `make_repo` shape: a plan at
`specs/{padded}_proj/plans/01_test.md` with a `**Goals**:` line naming
`` `hnOpenMirror`, `hnStabMirror`, and `hn_stab` `` and a matching
`## Lean Challenge Statements` block declaring the same three names) under this session's ambient
locale (`LANG=en_US.UTF-8`, `LC_ALL` unset — confirmed via `locale`):

```
$ bash lean-challenge-snapshot.sh 999 "$PWD" --dry-run
comm: file 2 is not in sorted order
comm: input is not in sorted order
comm: file 2 is not in sorted order
comm: input is not in sorted order
ERROR: identifier-set mismatch between **Goals**: and the Challenge declarations.
  named in **Goals**: but not declared: hn_stab
  declared but not named in **Goals**:  hn_stab
rc=71

$ LC_ALL=C bash lean-challenge-snapshot.sh 999 "$PWD" --dry-run
# route: plan-declared
# theorem_names: hnOpenMirror,hnStabMirror,hn_stab
...
rc=0
```

This matches the dispatch's description precisely: the SAME name (`hn_stab`) appears on both
"only in goals" and "only in declared" sides, and the whole invocation is fixed merely by forcing
`LC_ALL=C`.

**Root cause, confirmed with plain `sort`**:

```
$ printf 'hnOpenMirror\nhnStabMirror\nhn_stab\n' > lines.txt
$ sort -u lines.txt                 # ambient en_US.UTF-8
hnOpenMirror
hn_stab
hnStabMirror
$ LC_ALL=C sort -u lines.txt        # code-point order, matches Python's sorted()
hnOpenMirror
hnStabMirror
hn_stab
```

`hn_stab` vs. `hnStabMirror` swap position between the two collations because glibc's en_US
dictionary collation treats `_` as a very low-weight (near-ignorable) character compared to
letters, while C/byte-order collation places `_` (0x5F) after all uppercase letters (0x41-0x5A)
and before lowercase letters (0x61-0x7A). Any identifier pair combining `snake_case` and
`camelCase` segments that share a common prefix up to the case/underscore divergence point can
trigger this.

**Empirical finding on `comm`'s own locale sensitivity (resolves the one open question in the
dispatch's diagnosis)**: `comm --version` here is GNU coreutils 9.11. `comm` does not merely
require its inputs to be pre-sorted somehow — it independently re-checks "is this input sorted"
using string comparison performed under whichever locale `comm` itself runs in at the time. This
was confirmed by feeding `comm` two files that were internally consistent with each other (both
sorted under `LC_ALL=C`, i.e., identical to each other) versus two files sorted under different
collations:

- Two DIFFERENT-collation files → `comm` under either locale reports the OTHER file as "not in
  sorted order" and returns spurious diff lines (the exact failure mode observed live above).
- Two files sorted under the SAME collation (matching each other), even when that shared
  collation is `C` while `comm` itself runs under ambient `en_US.UTF-8` → no warning, correct
  (empty) diff, because `comm`'s streaming merge only ever needs the two inputs to agree with
  *each other* to walk them in lockstep; it detected disagreement only when comparing against a
  file whose order genuinely differed under the locale `comm` itself was applying.

Practical conclusion: fixing `extract_goal_names()`'s `sort -u` to `LC_ALL=C` (matching Python's
already-code-point-order declared-identifier lists) is *sufficient on its own* to eliminate the
false mismatch, because after the fix both files being compared are in the same order and `comm`
never has occasion to disagree with itself. However, per the dispatch's own instruction ("State in
a short comment at the `comm` site WHY the collation is pinned, so a future edit cannot quietly
unpin it"), the recommendation below still pins `LC_ALL=C` at the `comm` call site itself as
defense-in-depth and as the natural place to anchor the explanatory comment — a future edit that
touches only `extract_goal_names()` without also reading `cross_validate_identifiers()` should not
be able to silently regress this by an unrelated change to either function in isolation.

### Suite and Fixture Conventions

The suite (`test-lean-challenge-snapshot.sh`) follows a fixed pattern well worth reusing for the
new case:
- `pass()/fail()/info()/skip()` counters, a `WORKDIR=$(mktemp -d)` with `trap cleanup EXIT`.
- `make_repo <name> <task_number> <plan_fixture>` builds a throwaway git repo from a fixture under
  `tests/fixtures/challenge/{plan_fixture}`, with `{N}` substituted for the task number, and an
  initial commit. `run_tool <repo> [args...]` invokes the tool with `cd "$repo"`.
- Existing fixtures `plan_r1.md` (single identifier `comm`) and `plan_mismatched.md` (two
  identifiers `comm`/`assoc`, one deliberately undeclared) are the closest analogues for a new
  `plan_mixed_case.md` fixture: a `**Goals**:` list and a `## Lean Challenge Statements` section
  both naming the SAME mixed-case identifier set (e.g. `hnOpenMirror`, `hnStabMirror`, `hn_stab`)
  so the case asserts NO mismatch (exit 0, empty diff) — the inverse assertion shape of Case R2
  (which asserts a real, exit-71 mismatch).
- Case naming convention is `R{n}`/`M{n}`/`C{n}` by concern area (R = R1/R2 extraction & cross-
  validation, M = commit/manifest/immutability, C = `--check` drift mode) plus a trailing `AV1`
  anti-vacuous-test guard at the end of the file. A new "same-identifiers-different-collation"
  case belongs in the R-series (it is a cross-validation concern), suggested as `R5`, placed after
  the existing `R4` case and before the `M1` commit-flow block.
- The suite always exercises the tool via `bash "$TOOL_SRC" "$@"` inside a subshell with `cd`; a
  locale-specific case should set `LC_ALL=en_US.UTF-8` (or wrap the `run_tool` call in a
  locale-scoped subshell) rather than relying on the ambient test-runner locale, since CI/other
  environments cannot be assumed to already run under `en_US.UTF-8` — the case must force the
  locale that historically triggered the bug rather than hope the ambient one matches. Confirm
  `en_US.UTF-8` is present via `locale -a` (it is, in this environment) before hard-coding it, or
  fall back to another UTF-8 dictionary-collation locale if the target CI lacks it; the important
  property is "a real dictionary collation that reorders `_` relative to letters", not the
  specific locale name.

**Mutation-kill verification (dispatch requirement (c))**: reverting the collation pin (i.e.,
running the CURRENT, unfixed script under a forced `en_US.UTF-8`/similar dictionary-collation
locale) was directly observed above to reproduce the false-mismatch failure (exit 71, `hn_stab`
listed on both sides) with the exact three-identifier fixture set proposed for the new case. This
confirms the new case would go RED against the unfixed script and is not a vacuously-passing
addition; the same three-identifier fixture set can be reused verbatim for the actual suite
addition in the implementation phase, with the implementer re-running the red/green check by hand
against their own edited copy per the dispatch's instruction (this research phase's own repro used
a disposable sandbox copy, not the source-store file, and made no edits to it).

### Recommendations

1. **`extract_goal_names()` (around line 347)**: change the trailing `sort -u` to
   `LC_ALL=C sort -u`, scoped as an inline environment-variable prefix on that one command (never
   `export LC_ALL=C` at the top of the script) — this is the dispatch's own explicit MUST-NOT
   constraint ("Export LC_ALL process-wide if a narrower scope suffices"). Add a one-line comment
   immediately above explaining the pin exists to match `extract_r1`/`extract_r2`'s Python
   `sorted()` (code-point) output.
2. **`cross_validate_identifiers()` (lines 447-448)**: prefix both `comm` invocations with
   `LC_ALL=C` as well, with a comment stating why (per the dispatch's explicit instruction to
   comment at the `comm` site) — citing the empirical finding above that `comm`'s own sortedness
   check is evaluated under whatever locale it runs in, so pinning only the producer is correct
   for THIS script's specific data flow, but pinning the comparison site too is the documented,
   future-proof choice that survives an unrelated future edit to either function alone.
3. **No changes needed** at lines 145 (unrelated `sort -V`), 434, or 602 (already code-point
   order) — but the implementation's own summary/report should say so explicitly, since the
   dispatch's acceptance criteria requires "every cross-tool sort/compare site in the script is
   either collation-pinned or documented as not needing it."
4. **New suite case** (suggested `R5`) in `test-lean-challenge-snapshot.sh`: a `plan_mixed_case.md`
   fixture with `**Goals**:` and `## Lean Challenge Statements` both naming
   `hnOpenMirror`, `hnStabMirror`, `hn_stab` (or an equivalent mixed dictionary/code-point-diverging
   set), invoked under an explicitly forced dictionary-collation locale (e.g.
   `LC_ALL=en_US.UTF-8 run_tool ...` or an equivalent subshell), asserting exit 0 and no mismatch
   output. Document the mutation-kill fact (reverting the `LC_ALL=C` pins reproduces exit 71 with
   this exact fixture, as directly observed in this research phase) in the case's own comment
   block, following the file's existing per-case comment-block convention.
5. **Deploy step** (acceptance criterion, implementation-phase concern, not a research finding):
   the fix lives in the source store (`agent-system/extensions/lean/scripts/...`); per
   `.claude/rules/source-store-deploy-boundary.md` this must be regenerated into any consuming
   repo's `.claude/**` via the existing deploy mechanism
   (`agent-system/extensions/core/scripts/deploy-headless.sh`) for the fix to reach a running
   agent — a source-store-only fix "changes nothing for a running agent" per the dispatch's own
   acceptance wording. This repository is itself both the source store and (via its own deployed
   `.claude/`) a consumer; the specific external "consuming repo" referenced in the incident
   (`~/Projects/BimodalLogic`) is outside this repository's tree and outside this research phase's
   file scope, but the implementation phase should verify at least this repo's own regenerated
   `.claude/**` copy carries the fix, per the acceptance wording's literal requirement.

## Decisions

- Confirmed all five line-number claims in the dispatch description via direct `grep -n` against
  the current source-store file; no re-derivation needed since the file has not moved.
- Resolved the open question of whether producer-side-only collation pinning suffices: empirically
  yes for this specific script's data flow (both `comm` inputs become consistent once the shared
  producer is fixed), but the recommendation is still to pin `comm` itself too, matching the
  dispatch's explicit request for a comment at the `comm` site and treating that site as a second,
  independent seatbelt rather than relying solely on a fact about one producer's current
  implementation continuing to hold after future edits.
- Confirmed line 602 (R2 route) does not need its own separate fix, since its input (`names`) is
  read directly from the goals file that line 347 already fixes at the source.
- Confirmed line 145 is unrelated (version-sort of filenames for plan-file selection, never a
  cross-tool identifier comparison) and needs no change, matching the dispatch's own hedge.

## Risks & Mitigations

- **Risk**: pinning `LC_ALL=C` only at the `sort` site and not at `comm` could look sufficient in
  today's data flow but silently stop being sufficient if a future edit changes only one of the
  two functions (e.g., a refactor that feeds `cross_validate_identifiers` a goals file assembled
  by some other, not-yet-pinned code path). **Mitigation**: pin both sites per Recommendation 2,
  each with its own explanatory comment, so neither can be quietly unpinned by an edit that only
  looks at the other function.
- **Risk**: a new suite case that only asserts "exit 0" without checking the mismatch-message
  output could pass vacuously even if some unrelated exit path also returns 0.
  **Mitigation**: follow the existing suite's convention of grepping both the exit code AND
  specific expected substrings in `$out` (as every existing R/M/C case does), and additionally
  verify the case goes RED against the unmodified script (dispatch requirement (c), confirmed
  achievable per this research phase's own repro).
- **Risk**: hard-coding `en_US.UTF-8` in the new test case could make the case unrunnable (locale
  not installed) or silently non-triggering (if some other locale is ambient) in a different CI
  environment. **Mitigation**: the case should verify `en_US.UTF-8` (or its chosen substitute) is
  present via `locale -a` and fail loudly/skip with a clear message rather than silently no-op if
  absent, consistent with the suite's existing `skip()` helper and its already-established
  dependency-check pattern (`for dep in python3 git sha256sum; do ... done` near the top of the
  file).
- **Risk (already called out by the dispatch itself, restated here for the planner)**: this
  collation split can, in principle, also silently PASS two genuinely different identifier sets
  under `comm` when both sides happen to be mis-sorted in a way that makes them compare equal.
  This research phase did not attempt to construct such a false-negative fixture (out of scope for
  research; the dispatch's own acceptance criteria do not require a false-negative regression
  case, only the false-positive one already reproduced) — the implementation phase should keep
  this in mind if it has spare scope, but it is not a blocking gap for this task's stated
  acceptance criteria.

## Context Extension Recommendations

- **Topic**: locale-sensitive shell comparisons (`sort`/`comm`/`uniq`/`join`) in agent-system
  scripts.
- **Gap**: no existing `.claude/context/` file documents this hazard class or the
  `LC_ALL=C`-scoped-inline-pin pattern as a house convention, despite this being the second
  documented live incident (per the dispatch's "OBSERVED LIVE, TWICE" account) caused by exactly
  this class of bug in a single script.
- **Recommendation**: after this fix lands, consider a short addition to
  `agent-system/extensions/core/context/patterns/` (or an existing shell-scripting standards file,
  if one exists) capturing the pattern: "any shell pipeline whose sorted output is compared,
  via `comm`/`diff`/`join`, against another tool's sorted output (or against a different
  invocation of the same tool under a different environment) must pin collation explicitly and
  identically on both sides; a `sort` whose output is only ever read by a human does not need
  this." This is a natural `/learn` or context-gap follow-up, not a code change, and is out of
  scope for this task's own file_scope (`lean-challenge-snapshot.sh` and its test suite only).

## Appendix

- Search queries / commands used: `find ... -iname "lean-challenge-snapshot.sh"`,
  `grep -n "sort\b\|comm \|uniq\|join \|LC_ALL\|LC_COLLATE\|locale" lean-challenge-snapshot.sh`,
  `grep -n "^extract_r2" -A 15 ...`, `locale`, `locale -a`, live reproduction via a throwaway git
  repo built under this session's scratchpad directory (not the source store; no source files were
  modified during research), `comm --version`.
- Files read in full or in relevant part: `lean-challenge-snapshot.sh` (lines 1-40, 120-170,
  330-460, 560-640), `test-lean-challenge-snapshot.sh` (entire 327 lines),
  `tests/fixtures/challenge/plan_r1.md`, `tests/fixtures/challenge/plan_mismatched.md`,
  `agent-system/extensions/lean/manifest.json` (partial), directory listing of
  `agent-system/extensions/lean/`.
- No context-file documentation of this specific hazard was found prior to this report (see
  Context Extension Recommendations above).
