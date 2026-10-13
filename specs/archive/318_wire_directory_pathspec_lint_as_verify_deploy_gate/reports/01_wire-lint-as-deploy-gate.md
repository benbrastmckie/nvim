# Research Report: Task #318

- **Task**: 318 - Wire the directory-pathspec boundary lint into `verify-deploy.sh` as a numbered gate
- **Started**: 2026-10-12T14:16:00Z
- **Completed**: 2026-10-12T14:40:00Z
- **Effort**: small (single-gate wiring)
- **Dependencies**: shares `verify-deploy.sh` with the Gate-8-parallelism task (do not run concurrently); shares `scripts/tests/test-verify-deploy-context-budget.sh` with the SKILL.md trim task (ordering dependency, do not run concurrently)
- **Sources/Inputs**: `agent-system/extensions/core/scripts/verify-deploy.sh` (full read of gates 1, 16-22, header, arg-parsing, zero-check-under-filter tail), `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` (header + CLI contract), live run of that lint and its fixture test, `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`, `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`, `agent-system/extensions/core/context/standards/git-staging-scope.md` lines 695-730, `agent-system/extensions/core/manifest.json`, `specs/304_out_of_repo_pathspec_aborts_whole_commit/summaries/01_out-of-repo-pathspec-containment-summary.md`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The lint exists exactly as the dispatch describes**: `lint-directory-pathspec-boundary.sh` is registered in `manifest.json`, has a 14-case fixture test that passes (verified live: `14 passed, 0 failed`), and reports **0 violations** against the live source store right now (verified live: `Total violations: 0`, exit 0). Wiring it as a **blocking** gate today is safe.
- **Placement decision: append as a new trailing Gate 23, do NOT insert it next to Gate 17.** The dispatch's own hint ("determine whether this becomes a new trailing gate or is inserted next to gate 17") resolves cleanly in favor of trailing placement: by-number citations of the existing gates 18-22 are heavy and would all be silently invalidated by an insertion-triggered renumbering — **131 files cite "gate 20" by number alone** (test assertions, doc prose, the context-budget test's own header), with 16-30 files each citing gates 18/19/21/22. Appending Gate 23 after Gate 22 requires zero renumbering and zero citation fixes.
- **This decision contradicts a pre-existing doc sentence this task is scoped to fix.** `context/standards/git-staging-scope.md:717-719` currently says "the natural wiring point (`verify-deploy.sh` gate 17, alongside its sibling)" — written before this research determined that inserting beside gate 17 is the wrong call. Per the dispatch's batching note, this exact bullet is this task's to own; implement must correct this sentence to describe the trailing-Gate-23 decision and the renumbering rationale, not merely flip "Not yet wired" to "wired."
- **No collision with task 304's work.** Task 304 extended the *existing*, already-wired `lint-scoped-commit-boundary.sh` (Gate 17's lint) with a new "RULE 3" — it did not create a new script, and it did not touch `lint-directory-pathspec-boundary.sh` or any gate numbering. The two lints remain distinct and complementary exactly as this task's dispatch and `git-staging-scope.md` already describe (opposite failure modes: no-pathspec-at-all vs. too-wide-a-pathspec).
- **Mechanical change inventory is small and fully enumerated below** (one new gate block, six numeric-range updates in `verify-deploy.sh`, eight count updates in `test-verify-deploy-gate-selection.sh`, one doc bullet in `git-staging-scope.md`). No change is needed to Gate 20's own test, the manifest, or any other doc — confirmed by direct inspection, not assumed.

## Context & Scope

Research-only dispatch for task 318 (`task_type: meta`). The work is to wire an existing, already-passing lint into `verify-deploy.sh` as a new numbered gate, following Gate 17's shape exactly, and to rule on (a) gate number/placement and its renumbering blast radius, and (b) blocking-vs-advisory tier. The dispatch's HARD CONSTRAINT (never weaken the lint to make the gate green) is not implicated — the lint is clean today. Implementation and verification are explicitly out of scope for this phase; this report rules on the two open questions and hands implement a precise, line-level change list.

## Findings

### Codebase Patterns

**Gate 17's exact template** (`verify-deploy.sh:935-966`), which the new gate must copy line-for-line in shape:

```bash
# Gate 17: scoped-commit boundary lint (lint-scoped-commit-boundary.sh --verbose)
#
# Same source-store-vs-deploy-consumer [SKIP] posture as the sibling lint gates (6, 7, 9, 11, 12):
# only the source store (agent-system/extensions/core/**) is validated, regardless of which copy
# (source store or deployed .claude/) invoked this script. Invokes the source-store copy
# directly, resolving REPO_ROOT the same way gate 12 does.
if gate_selected 17; then
say "17. Scoped-commit boundary lint (lint-scoped-commit-boundary.sh --verbose)"
CURRENT_GATE="gate17"
if [ ! -d "$TARGET/agent-system/extensions" ]; then
  say "  [SKIP] $TARGET is a deploy consumer, not the source store -- scoped-commit boundary lint does not apply"
elif [ ! -f "$TARGET/agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh" ]; then
  fail "lint-scoped-commit-boundary.sh not found in source store"
else
  scoped_commit_lint_output=$(cd "$TARGET" && REPO_ROOT="$TARGET" bash "$TARGET/agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh" --verbose 2>&1)
  scoped_commit_lint_status=$?
  if [ "$scoped_commit_lint_status" -eq 0 ]; then
    pass "scoped-commit boundary lint reports no hand-rolled bare git-commit call sites"
  else
    fail "scoped-commit boundary lint reported hand-rolled bare git-commit call sites" \
         "re-run for detail: bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh --verbose" ""
    if [ "$FINDINGS" = "true" ]; then
      while IFS= read -r scoped_commit_lint_line; do
        FINDINGS_LIST+=("FINDING gate17 ${scoped_commit_lint_line#*VIOLATION\] }")
      done < <(printf '%s\n' "$scoped_commit_lint_output" | grep -F '[VIOLATION]')
    fi
  fi
fi

say ""

fi
```

Gates 18/19/21/22 (the lint gates added after 17) all follow this identical shape with only the variable-name prefix, the lint filename, and the gate number changed — confirming this is the established idiom, not a one-off.

**`lint-directory-pathspec-boundary.sh`'s CLI contract matches Gate 17's assumptions exactly**: `--verbose` flag (line 107), `[VIOLATION]` prefix on findings (line 314), `exit 0` on clean (line 352), `exit 1` on violations found (line 369), `exit 2` on usage error (lines 126/167/244). No adapter or new mechanism is needed — the new gate block is a pure copy of Gate 17's shape with `scoped_commit` renamed to a directory-pathspec-specific prefix (e.g. `dir_pathspec_lint_*`) and the filename/gate-number swapped.

**Live verification performed this phase** (not merely trusted from the dispatch):
```
$ REPO_ROOT="$(pwd)" bash agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh --verbose
...
Files checked: 1303
Candidate tokens exempted: 460
Candidate tokens skipped (exclude-magic): 1
Total violations: 0
exit=0

$ bash agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh
Results: 14 passed, 0 failed
exit=0
```
Both confirm the dispatch's "CURRENT STATE (verified)" claims as still true at research time.

**Gate numbering and the renumbering blast radius.** `verify-deploy.sh` currently runs gates 1-22 (confirmed: `grep -n 'CURRENT_GATE="gate'` shows gate1 through gate22, in order, with gate22 — the shellcheck lint — immediately preceding the zero-check-under-filter tail at line 1204). The `--only-gate` validator hardcodes the range `1-22` in six places (`verify-deploy.sh:83,86,89,125,131,137`). A citation sweep for existing gate numbers found:

| Gate # | Files citing it by number (repo-wide) |
|---|---|
| 18 | 16 |
| 19 | 16 |
| 20 | 131 |
| 21 | 17 |
| 22 | 30 |

Gate 20 alone (the orchestrator context-budget lock) is cited 131 times — test assertions in `test-verify-deploy-gate-selection.sh` and `test-verify-deploy-context-budget.sh`, that test's own header prose, and other doc cross-references. Inserting the new gate next to Gate 17 (i.e. as the new "gate 18") would shift every one of gates 18-22 up by one, silently invalidating all of these citations — exactly the hazard the dispatch flagged by name ("the gate-20 citations in the orchestrator context-budget work"). Appending as **Gate 23** (after the current last gate, 22, and before the zero-check-under-filter tail) requires renumbering nothing.

**Gate 20 does not measure `verify-deploy.sh` itself**, so adding a new gate block to `verify-deploy.sh` has no bearing on Gate 20's own per-file-ceiling checks — those measure only `commands/orchestrate.md` and `skills/skill-orchestrate/SKILL.md` (confirmed by reading `verify-deploy.sh:1058-1065`'s `BUDGET_CONFIG` resolution). The declared ordering dependency with the SKILL.md-trim task is about shared test-file edits (`test-verify-deploy-context-budget.sh`), not a content interaction — safe to treat as pure sequencing, not a design constraint on the new gate's shape.

**The `git-staging-scope.md` bullet this task owns** (`context/standards/git-staging-scope.md:712-720`) currently reads:

> `.claude/scripts/lint/lint-directory-pathspec-boundary.sh` — the complementary mechanical guardrail against the OPPOSITE failure mode... **Not yet** wired as a `verify-deploy.sh` gate: the natural wiring point (`verify-deploy.sh` gate 17, alongside its sibling) is itself an orchestrator-critical path, and the task that introduced this lint was scoped to exclude touching any critical path — see that task's summary for the follow-up.

This sentence's *own* premise ("the natural wiring point... gate 17, alongside its sibling") is superseded by this research's placement finding. Implement must rewrite this to state the lint is wired as Gate 23 (a trailing gate, deliberately not inserted beside Gate 17) and give the one-line renumbering rationale — not just toggle "Not yet" to "now."

**Task 304 boundary, resolved.** Task 304's summary (`specs/304_.../summaries/01_...-summary.md:23,51,56`) shows it added a new "RULE 3" *inside* the already-wired `lint-scoped-commit-boundary.sh` (Gate 17's own lint script) and a matching Case 11 in that lint's own test — it introduced no new script and touched no gate numbering. `lint-directory-pathspec-boundary.sh` (this task's target) was untouched by task 304. The two lints remain exactly as complementary and non-overlapping as `git-staging-scope.md` already documents (one guards "no pathspec at all," the other guards "pathspec present but too wide"). There is no collision to resolve beyond the shared-doc-region note the dispatch already records (this task owns only the one cross-reference bullet above; the exit-code table in the same file belongs to task 304).

### External Resources

Not applicable — this is a pure codebase-internal wiring task with no external dependency.

## Decisions

- **Gate number: 23 (new trailing gate), not an insertion beside Gate 17.** Rationale: zero renumbering, zero citation breakage, versus 131+16+16+17+30 = 210 by-number citation sites that an insertion would silently invalidate.
- **Tier: blocking**, matching Gate 17 and every other lint gate in this battery (6, 7, 9, 11, 12, 17, 18, 19, 21, 22 are all blocking `fail()` on violation, not `warn()`). The lint reports 0 violations against the live source store as of this research pass — confirmed by direct execution, not inherited from the dispatch's claim.
- **Re-verify "0 violations" at implement time** per the dispatch's own caveat — the source store is a live multi-task working tree and may have changed between this research pass and implementation.

## Recommendations

Implement should apply exactly these mechanical changes, in this order:

1. **`agent-system/extensions/core/scripts/verify-deploy.sh`**:
   - Insert a new Gate 23 block, copied from Gate 17's shape (see Findings above), between the end of the current Gate 22 block (`fi` at line 1203) and the "Zero-check-under-filter" comment (line 1204). Use a distinct variable prefix (e.g. `dir_pathspec_lint_output`/`_status`/`_line`) to avoid colliding with Gate 17's `scoped_commit_lint_*` names, matching how Gates 18/19/21/22 each use their own distinct prefix.
   - Update the hardcoded range `1-22` → `1-23` at lines 83, 89, 125, 131, 137, and `twenty-two` → `twenty-three` at line 86.
   - Optional, low-cost, not required by this task: the header's Findings-mode paragraph (around line 71-75) already says "across all eighteen gates (gate0 through gate17)" — stale since before this task (the true count was already 22 before this change). Flagging only; fixing it is not this task's scope and should not be bundled in without a deliberate choice to widen scope slightly, per the dispatch's framing of staying narrow.
2. **`agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`**: update every hardcoded `22`/`seq 1 22` to `23` — lines 4, 26, 30 (comment prose), 135 and 181 (`seq 1 22` → `seq 1 23`), 143 and 185 (assertion/pass-message text citing "22 gates"/"all 22 gate headers"), and the "1..22" comment at line 131. These are the test's own correctness-affecting assertions (case (b): every gate id runs clean standalone; case (d): all gate headers appear in a no-flag run) — they will under-count without this update, not merely read stale.
3. **`context/standards/git-staging-scope.md:712-720`**: rewrite the "Not yet wired" sentence to state the lint is wired as `verify-deploy.sh` gate 23 (a deliberately trailing placement, not inserted beside gate 17, to avoid renumbering the heavily-cited gates 18-22 — cite the rationale briefly). Stay inside this one bullet; the exit-code table elsewhere in the same file belongs to a different live task per the dispatch's batching note.
4. **Verification** (per dispatch's CLOSE BY): run `bash .claude/scripts/verify-deploy.sh` (full battery, ~2.8 min — use the Bash tool's own `timeout` parameter explicitly, e.g. 600000ms, with an inner `timeout 540`, output redirected to a file) and confirm the new gate appears, passes, and the `PASS -- N check(s)` count increments by one over the pre-change baseline. Re-run `scripts/tests/test-lint-directory-pathspec-boundary.sh` and `test-verify-deploy-gate-selection.sh` and confirm no regression.
5. No change needed to: `manifest.json` (lint already registered), `test-verify-deploy-context-budget.sh` (Gate 20 does not measure `verify-deploy.sh`), or any other doc (citation sweep found no other by-number reference to the lint or to a gate count needing a bump).

## Risks & Mitigations

- **Risk**: implement forgets one of the six `1-22` sites in `verify-deploy.sh` or one of the eight count sites in the gate-selection test, leaving a stale range that silently rejects `--only-gate 23`. **Mitigation**: the full line-number list is enumerated above; implement should `grep -n "1-22\|seq 1 22\|twenty-two"` after editing to confirm zero remaining hits before considering the change complete.
- **Risk**: a sibling task in this same batch (Gate-8-parallelism, or the SKILL.md-trim task) edits `verify-deploy.sh` or `test-verify-deploy-context-budget.sh` concurrently. **Mitigation**: both are declared `dependencies[]` edges per the dispatch; do not run this task concurrently with either.
- **Risk**: the lint develops a violation between this research pass and implementation (the source store is live and multi-task). **Mitigation**: dispatch and this report both call for re-running the lint at implement time before wiring it as blocking; if a violation appears, fix the site or add an allowlist entry — never weaken the classifier (HARD CONSTRAINT, unaffected by this research).

## Context Extension Recommendations

None — this is a `task_type: meta` task touching only existing, already-documented mechanisms (gate idiom, lint CLI contract, doc cross-reference). No new context file is warranted.

## Appendix

- Search/verification commands used: `grep -n "CURRENT_GATE=\"gate" verify-deploy.sh`; `grep -rn "[Gg]ate N\b"` sweep for N in 18-22 across `--include="*.md" --include="*.sh" --include="*.json"`; live execution of `lint-directory-pathspec-boundary.sh --verbose` and `test-lint-directory-pathspec-boundary.sh`; `grep -n "lint-directory-pathspec-boundary" --include="*.md"` repo-wide (found only the one `git-staging-scope.md` bullet); `grep -n "lint-directory-pathspec-boundary\|lint-scoped-commit-boundary" manifest.json` (both registered).
- References: `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh`, `agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh`, `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`, `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`, `agent-system/extensions/core/context/standards/git-staging-scope.md`, `specs/304_out_of_repo_pathspec_aborts_whole_commit/summaries/01_out-of-repo-pathspec-containment-summary.md`.
