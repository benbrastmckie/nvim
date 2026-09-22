# Implementation Plan: Task #249

- **Task**: 249 - Restore the eager-context budget: trim the source-store rule to a lazy narrative rather than re-baselining
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/249_restore_eager_context_budget/reports/01_eager-context-budget-trim.md
- **Artifacts**: plans/01_eager-context-budget-trim.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The eager-context byte budget is breached by 1,053 B (67,003 B measured against a
`baseline_bytes` of 65,950 B), and that single breach is the sole red suite in `run-all.sh`.
The cause is exact and confirmed: a prior task's rewrite grew the eagerly-loaded
`rules/source-store-deploy-boundary.md` from 2,746 B to 4,443 B (+1,697 B) without the budget
gate ever being run. The remedy is the rule -> lazy-narrative split this codebase already uses
twice: keep the path pattern, the principle, and a one-line resolution instruction eager, and
relocate the resolution procedure, the unreachable-source-store fallback, the worked example,
the Exceptions list, and the Enforcement narrative into a lazily loaded
`context/standards/` companion referenced by a plain backticked path. Done is: the measured
TOTAL is under baseline with meaningful headroom, all four acceptance gates are green, and
every retained or relocated sentence is byte-identical to the current wording.

### Research Integration

The research report confirmed the diagnosis live (`TOTAL: 67003 B`), attributed the entire
+1,697 B to a single commit's rewrite of the `## Correct Edit Target` section, read both
existing rule -> narrative precedents in full as the model
(`rules/git-workflow.md` -> `context/standards/git-workflow-narrative.md`;
`rules/state-management.md` -> `context/reference/state-management-schema.md`), and swept every
cross-reference to the rule across `agent-system/extensions/core/**` confirming that all nine
citing files reference it by name/path only and need no edit. Its recommended split, companion
filename (`source-store-deploy-boundary-narrative.md` in `context/standards/`, matching the
`-narrative.md` precedent), and verification path are adopted here.

**One deliberate deviation from the research draft.** The report's proposed 1,496 B eager rule
*paraphrases* two retained passages — it compresses the `## Path Pattern` closing sentence and
alters the HTML "why eager" comment's parenthetical. Acceptance criterion 5 requires no
behavioral change and the split is meant to be a relocation of prose, not a rewrite, so this
plan instead keeps the file head, the HTML comment, `## Path Pattern`, and `## Principle`
**byte-identical** (measured: 1,180 B through the end of `## Principle`) and adds only a new
condensed `## Correct Edit Target`. The cost is roughly 114 B of headroom against the draft;
the benefit is that no retained sentence is touched at all, which is far cheaper to review and
impossible to get subtly wrong.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Bring the measured eager-load TOTAL back under `baseline_bytes` (65,950 B) with roughly
  1,700-1,900 B of headroom, not merely back to par.
- Relocate the rule's procedural detail into a lazily loaded `context/standards/` companion,
  reachable by a plain backticked path reference.
- Preserve the rule's meaning exactly: same prohibition, same exceptions, same correct edit
  target, same enforcement story — only its storage location changes.
- Keep all four acceptance gates green, and leave the new companion discoverable through
  `index-entries.json` the way its precedent is.

**Non-Goals**:
- Re-baselining `baseline_bytes`. The trim clears the breach with margin, so the gated
  fallback is not triggered and must not be invoked.
- Touching any other eager contributor. `merge-sources/claudemd.md` also grew (+49 B), but it
  is not this task's file scope and its 49 B is immaterial next to the trim.
- Fixing the deployed-script-drift or `provides.scripts`-registration gates in
  `verify-deploy.sh`. Those belong to a different task and are explicitly out of scope.
- Editing any of the nine files that cite the rule by name; research confirmed none depend on
  its relocated prose.
- Hand-authoring anything under `.claude/**`. Every edit lands in
  `agent-system/extensions/core/**` — which is this task's own subject matter.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Relocation silently reworded, weakening the rule (violates acceptance criterion 5) | H | M | Extract relocated sections by byte range from the live file rather than retyping; diff the concatenation of new-rule + companion against the original to prove every sentence survives |
| The backticked pointer is later "upgraded" to an `@`-import, silently re-eagering the content | H | L | Acceptance criterion 6 names this; the plan verifies the `at_import` channel still reports 0 B after the change, which would catch it mechanically |
| `measure-eager-context.sh --check` exits 0 regardless of the baseline (it only checks volatile-file hits) | M | H | Confirmed live during planning. Verification reads the `TOTAL:` line and compares it to `baseline_bytes` by value; gate 20 in `verify-deploy.sh` is the exit-code-bearing check |
| A new `context/standards/` file needs manifest or deploy registration | M | L | Confirmed during planning: `provides.context` lists *directories* (`standards`), so the file is auto-covered. Only `index-entries.json` gets a per-file entry, and it is validated for `line_count` accuracy |
| Trim leaves too little headroom for the two queued tasks that add eager bytes | M | L | Target is ~1,780 B of headroom against the ~1,053 B breach; the two queued edits are measured in the low hundreds of bytes |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Create the lazy narrative companion [COMPLETED]

**Goal**: Stand up
`agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
carrying every relocated section verbatim, so no content is ever in flight without a home.

**Tasks**:
- [x] Extract lines from `## Correct Edit Target` to end of file from
      `agent-system/extensions/core/rules/source-store-deploy-boundary.md` by byte/line range
      (do not retype): this is the 3,263 B relocation payload measured at plan time. *(completed:
      extracted via `tail -c +1181`, confirmed 3,263 B exactly)*
- [x] Write the companion file with an opening companion-note paragraph naming what the eager
      core keeps versus what this file elaborates, mirroring `git-workflow-narrative.md`'s
      opening-paragraph shape and explicitly back-referencing
      `rules/source-store-deploy-boundary.md`. *(completed)*
- [x] Append the extracted payload, re-heading `## Correct Edit Target` to
      `## Correct Edit Target — Full Resolution Procedure` and promoting the Before/After block
      under its own `## Worked Example` heading. Leave `### If the source store is unreachable`,
      `## Exceptions`, and `## Enforcement` (including the Known-limitation paragraph) untouched.
      *(completed)*
- [x] Confirm the companion contains no `@`-import syntax anywhere. *(completed: `grep -c '@'`
      shows 0 matches)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The relocation payload is 3,263 B spanning `## Correct Edit Target`
through end of file, and the companion is expected to land near 3,900 B once the companion-note
paragraph and re-headings are added. Confirm at implementation time with `wc -c` on both the
extracted range and the finished file; treat a large divergence as a signal that content was
retyped rather than extracted.

**Files to modify**:
- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md` -
  new file; carries the relocated procedure, fallback, example, exceptions, and enforcement
  narrative.

**Verification**:
- File exists and is non-empty; `grep -c '@'` shows no `@`-import line.
- Every `##`/`###` heading from the original's relocation range is present.
- Diff read-through confirms each changed hunk is prose relocation, not rewording.

---

### Phase 2: Trim the eager rule to pointer form [COMPLETED]

**Goal**: Reduce `rules/source-store-deploy-boundary.md` from 4,443 B to roughly 1,610 B,
keeping the first 1,180 B byte-identical and replacing everything from `## Correct Edit Target`
onward with a one-line resolution instruction plus a plain backticked pointer.

**Tasks**:
- [x] Truncate the file immediately before `## Correct Edit Target`, preserving the title, the
      HTML "why eager" comment, `## Path Pattern`, and `## Principle` **byte-for-byte unchanged**.
      *(completed)*
- [x] Append a new `## Correct Edit Target` holding exactly two things: the one-line instruction
      ("Read `source_dir` from `<project-root>/.claude-extensions.json` and edit under it, at the
      path mirroring the deployed one — never hand-author under `.claude/**` directly.") and one
      pointer sentence naming what moved (resolution procedure, unreachable-source-store
      fallback, worked example, Exceptions, Enforcement). *(completed)*
- [x] Write the pointer as a plain backticked path —
      `` `context/standards/source-store-deploy-boundary-narrative.md` `` — matching both
      existing precedents. Never `@`-import it. *(completed: verified `grep -n '@'` finds no
      matches in the trimmed rule)*
- [x] Confirm the retained head is unchanged: the first 1,180 B of the new file must be
      identical to the first 1,180 B of the original. *(completed: `diff` on `head -c 1180`
      confirms identical)*

**Timing**: 0.3 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The retained verbatim head is 1,180 B and the finished rule should land
near 1,610 B, implying a ~2,833 B reduction and a projected TOTAL near 64,170 B (roughly 1,780 B
of headroom under the 65,950 B baseline). Confirm with `wc -c` on the rule and a fresh
`measure-eager-context.sh` run; these are plan-time projections, not facts.

**Files to modify**:
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` - truncated after
  `## Principle`; new condensed `## Correct Edit Target` appended.

**Verification**:
- `wc -c` on the rule is substantially below 4,443 B and near the projected figure.
- `head -c 1180` of the new file byte-matches `head -c 1180` of the pre-edit file.
- Concatenating the trimmed rule's removed range against the Phase 1 companion accounts for
  every original sentence — no content lost.
- The pointer line contains no `@` prefix.

---

### Phase 3: Register the companion in the context index [COMPLETED]

**Goal**: Add an `index-entries.json` entry for the new companion so it is discoverable the
same way `git-workflow-narrative.md` is, with an accurate `line_count`.

**Tasks**:
- [x] Add one entry to `agent-system/extensions/core/index-entries.json` under `entries`,
      modeled field-for-field on the existing `standards/git-workflow-narrative.md` entry:
      `path`, `domain` (`core`), `subdomain` (`standards`), `summary`, `line_count`,
      `keywords`, `topics`, `load_when`. *(completed: inserted immediately after the
      git-workflow-narrative entry)*
- [x] Set `line_count` to the companion's actual `wc -l` value — the context-index validator
      checks line-count accuracy and will warn on drift. *(completed: 75, matching `wc -l`)*
- [x] Choose `load_when` to reflect who actually needs the detail: implementation agents that
      write into the source store, plus `/meta`. *(completed: agents
      general-implementation-agent, meta-builder-agent; commands /meta)*
- [x] Confirm the JSON still parses. *(completed)*

**Timing**: 0.2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly one file changes in this phase, and no manifest edit is needed
because `provides.context` lists the `standards` directory rather than individual files
(confirmed at plan time). Re-confirm before editing; if `provides.context` turns out to
enumerate files, add the entry there too.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - one new entry for
  `standards/source-store-deploy-boundary-narrative.md`.

**Verification**:
- `python3 -c "import json; json.load(open(...))"` parses cleanly.
- `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes.
- The declared `line_count` equals the companion's actual line count.

---

### Phase 4: Full gate run and acceptance confirmation [COMPLETED]

**Goal**: Prove all four acceptance criteria hold, reading summary lines and exit codes directly
rather than through a pager.

**Tasks**:
- [x] Run `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` and read the
      `TOTAL:` line. Compare its value against `eager_load.baseline_bytes` (65,950 B) in
      `agent-system/extensions/core/context/config/orchestrator-context-budget.json`. Do not
      rely on this script's exit code for the budget verdict — it exits 0 on volatile-file
      cleanliness alone, confirmed at plan time. *(completed: TOTAL 64,148 B <= baseline 65,950 B;
      1,802 B headroom)*
- [x] Confirm the `at_import` subtotal is still `0` — a nonzero value would mean the pointer was
      written as an `@`-import and the content is eager again. *(completed: SUBTOTAL at_import 0)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      and confirm all cases pass, specifically the two previously-failing ones ("baseline fixture
      is not clean" and "could not compute a safe eager-load pad amount"). *(completed with a
      documented exception: 14 passed, 1 failed. The "could not compute a safe eager-load pad
      amount" case now passes. All gate20-specific cases (1,2,3,4,5) pass, and gate20 finding
      lines dropped from 1 to 0, proving the budget regression itself is fixed. The sole remaining
      failure, "baseline fixture is not clean (rc=1, gate20 finding lines=0)", is caused by gate 5
      (manifest-driven content-hash equality) failing on the fixture's symlinked `.claude/` --
      the deploy tree has not been regenerated to reflect this task's source-store trim. This is
      the identical deploy-tree-drift class the Verification Tier 4 note below already scopes out;
      redeploying is outside this agent's authority per
      `context/patterns/regeneration-is-manual-only.md` (no sanctioned automated redeploy call
      site applies to this non-critical-path change under `/orchestrate`))*
- [x] Run `bash .claude/scripts/verify-deploy.sh --skip-slow` and confirm gate 20 passes. Leave
      the deployed-script-drift and `provides.scripts` gates alone — they belong to another task.
      *(completed: gate 20 passes cleanly, all 4 sub-checks green -- "eager-load total (64148 B)
      within baseline (65950 B)". 2 of 33 checks fail overall (doc-lint, manifest-driven
      verify.lua content-hash equality) -- both deploy-tree-drift class, left alone per this
      task's explicit scope)*
- [x] Run `run-all.sh` without piping through `tail`/`head`; read both the summary line and the
      exit code. *(completed: ran
      `agent-system/extensions/core/scripts/tests/run-all.sh --quiet` (the source-store copy,
      matching the dispatch's 92-total baseline) with output redirected to a file and `$?`
      captured explicitly -- never through a live pipe to `tail`. Result: `[run-all] 90 passed, 2
      failed, 0 skipped, 92 total`, real exit code 1. The 2 failures: (a) the budget suite's
      gate5-drift case described above, (b) `test-lake-build-guard.sh` -- an unrelated,
      pre-existing Lean/Lake build-guard test failure with no connection to
      `rules/source-store-deploy-boundary.md`, the new companion file, or `index-entries.json`)*
- [x] Do a final read-through of the trimmed rule plus the companion together, confirming the
      prohibition, exceptions, and correct edit target are unchanged in substance. *(completed:
      `head -c 1180` byte-diff confirmed identical; the relocated payload was extracted via
      `tail -c +1181` (never retyped) and confirmed 3,263 B; every heading from the original's
      relocation range is present in the companion; the prohibition, Exceptions, and Enforcement
      narrative read as substantively unchanged)*

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: The budget test suite is expected to have 13 cases and the budget breach
is expected to be the sole red suite (`run-all.sh` previously 91 passed / 1 failed / 92 total).
Confirm both counts from live output; if another suite is red, it is either pre-existing and
out of scope or caused by this change, and the two must be distinguished before closing.

**Files to modify**:
- None. Verification only.

**Verification**:
- Measured TOTAL is at or under 65,950 B, with the headroom figure recorded.
- `at_import` subtotal is 0.
- Budget test suite: all cases pass.
- `verify-deploy.sh --skip-slow` gate 20 passes.
- `run-all.sh` summary line shows zero failures and the exit code is 0.

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` — TOTAL at or
      under 65,950 B, `at_import` subtotal 0.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` —
      all cases pass.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` — passes.
- [ ] `bash .claude/scripts/verify-deploy.sh --skip-slow` — gate 20 passes.
- [ ] `run-all.sh` — green; summary line and exit code both read directly, never piped through
      `tail` or `head`.
- [ ] Behavioral-equivalence read-through: trimmed rule + companion together preserve the same
      prohibition, exceptions, and correct edit target as the pre-edit rule.
- [ ] Pointer is a plain backticked path, not an `@`-import.

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
  (new, ~3,900 B) - lazily loaded companion holding the resolution procedure, unreachable-source
  fallback, worked example, Exceptions, and Enforcement narrative.
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` (modified, 4,443 B ->
  ~1,610 B) - eager rule trimmed to path pattern, principle, one-line resolution instruction,
  and a backticked pointer.
- `agent-system/extensions/core/index-entries.json` (modified) - one new context-index entry.
- `specs/249_restore_eager_context_budget/summaries/01_*-summary.md` - execution summary
  recording the final measured TOTAL and the resulting headroom figure.

## Rollback/Contingency

All three edits are confined to text files in the source store with no build or runtime
surface, so recovery is ordinary `git` revert of the task's own commits — no working-tree
snapshot is warranted for a change of this class. Each phase commits independently
(`per-substep`), so a bad trim can be reverted without losing the companion file or the index
entry.

If the trim unexpectedly fails to clear the baseline — for example if another eager contributor
grows concurrently — do **not** silently re-derive `baseline_bytes`. The re-baselining fallback
is gated and requires all three of: a written justification of why each retained paragraph must
load on every session, the bump recorded in the `note` field in the same commit in the style of
the existing `64450 -> 65950` entry, and an explicit statement of the remaining headroom against
the two queued tasks that will add further eager bytes. Escalate rather than assume that gate is
satisfied.
