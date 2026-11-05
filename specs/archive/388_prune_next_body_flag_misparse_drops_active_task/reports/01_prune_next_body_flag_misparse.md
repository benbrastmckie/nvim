# Research Report: Task #388

**Task**: 388 - Fix prune_next_body() mis-parsing a Run line when a CLI flag precedes the rationale comment.
**Started**: 2026-10-14T00:00:00Z
**Completed**: 2026-10-14T00:00:00Z
**Effort**: small (single function + its sibling counter, both in one file)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/roadmap-integration.sh`, `context/formats/roadmap-format.md`, `scripts/tests/test-roadmap-generation.sh`), originating issue log (`specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/issues.jsonl`), isolated `awk`/`jq` reproduction in a scratch script
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed and precisely isolated the defect: `prune_next_body()`'s `gsub(/[ \t]/, "", tasklist)`
  step strips **all** whitespace from the pre-comment portion of a Run line, which silently
  fuses a trailing CLI flag onto the last task id (`"714 --hard"` -> `"714--hard"`). That fused
  token never matches the plain-numeric `active[]` lookup, so a genuinely active task is treated
  as terminal and dropped — with no error, no warning, exit 0.
- Reproduced four concrete failure shapes with a standalone harness replaying the real function
  byte-for-byte (see Appendix): active-task loss when kept < n2 (flag survives nowhere), total
  flag loss even in the merely-partial-keep path, and — the worst case — **total line
  disappearance** when the flagged Run line names only one task and that task is active
  (`kept=0`, `n2=1`, neither output branch fires).
- Found and confirmed an **identical sibling defect** in `count_pruned_next_ids()` (lines
  600-616): its own whitespace-collapse produces the same fused token, which it feeds to
  `jq -e --argjson n "$id"`; since `"714--hard"` is not valid JSON, jq exits non-zero, and the
  `if !` wrapper interprets that as "not active" — so the diagnostic `pruned=`/`retained=`
  stderr counters are *also* corrupted by the same root cause, independent of the content bug.
- Both the classic (`## Next`) and stage (run-order section) code paths call the unmodified
  `prune_next_body()` (confirmed via `mode_prune_classic`/`mode_prune_stage` call sites), so the
  defect is layout-independent exactly as the task description states.
- The documented grammar in `context/formats/roadmap-format.md` ("Next Grammar" /
  "Parsing Patterns Summary") does not mention CLI flags in a Run line at all
  (`^/orchestrate ([\d, ]+)(\s{3}# (.+))?$`) — the live BimodalLogic roadmap's use of flags is
  outside the documented grammar, which is a planning-phase question to resolve (see
  Recommendations), not something this report decides.
- Zero existing test coverage: `scripts/tests/test-roadmap-generation.sh`'s `--prune` cases
  (classic Case group 3, stage Phase 5) never construct a Run line containing a CLI flag, in
  either layout — which is exactly how this went unnoticed until live verification surfaced it.

## Context & Scope

This task was spawned from a `kind: issue`, `severity: costly` entry recorded during task 371's
implementation (`specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/issues.jsonl`,
entry `iss_1791594170949_tEAVNS`): a read-only verification of `roadmap-integration.sh --prune`
against the live, stage-based `specs/ROADMAP.md` in `~/Projects/BimodalLogic` surfaced that an
active task silently vanished from a Run line. Task 371 deliberately did not fix this — the
function is shared and outside that task's declared `file_scope` — so it was logged and spawned
as a new, scoped task instead.

The scope here is research only: locate and precisely characterize the defect in
`prune_next_body()` (and, as discovered, its sibling `count_pruned_next_ids()`), confirm it
reproduces identically in both roadmap layouts, and surface everything the planning phase needs
to scope a correct, minimal fix plus the test cases the task description requires: a flagged Run
line with a comment, a flagged line without a comment, an unflagged line with a comment, and
multiple flags — across both layouts.

No source file was modified during this research pass; all reproduction ran against an extracted
copy of the real function in a scratch script, confirmed byte-identical to the live function body
at `agent-system/extensions/core/scripts/roadmap-integration.sh:677-716`.

## Findings

### Codebase Patterns

**Location of the defect**: `agent-system/extensions/core/scripts/roadmap-integration.sh:680-716`
(`prune_next_body()`). The deployed mirror `.claude/scripts/roadmap-integration.sh` is currently
byte-identical to this source-store file (`diff` confirmed empty), so the fix's canonical edit
target is the source-store path per `.claude/rules/source-store-deploy-boundary.md`; a redeploy
propagates it to `.claude/scripts/roadmap-integration.sh` afterward.

**Call sites** (both reuse the function unmodified, per the comment at line 919):
- `mode_prune_classic()` (around line 962): `new_next=$'\n'"$(prune_next_body "$RM_NEXT")"` —
  classic layout's `## Next` section.
- `mode_prune_stage()` (around line 936): `RM_SECTION_BODIES[$run_order_idx]="$(prune_next_body
  "${RM_SECTION_BODIES[$run_order_idx]}")"` — stage layout's run-order section.

**Exact mechanism** (lines 680-716):
```awk
pos = index(line, "   # ")
if (pos > 0) { rationale = substr(line, pos); core = substr(line, 1, pos - 1) }
tasklist = core
sub(/^\/orchestrate /, "", tasklist)
gsub(/[ \t]/, "", tasklist)              # <-- strips the space before a flag too
n2 = split(tasklist, ids, ",")
...
for (k = 1; k <= n2; k++) {
  if (ids[k] in active) { joined = ... ; kept++ }
}
if (kept == n2) { print line }                        # only when EVERY id matched
else if (kept > 0) { print "/orchestrate " joined rationale }   # flag is NEVER re-emitted
# kept == 0 -> nothing printed at all -- the whole line vanishes
```
`gsub(/[ \t]/, "", tasklist)` removes the separator space between the comma-separated id list
and a following `--flag` token, fusing them (`"714 --hard"` -> `"714--hard"`) before the
comma-split. The fused token can never be `in active[]` (that map holds only plain numeric task
ids), so:
1. Any Run line carrying at least one CLI flag can never take the `kept == n2` ("print the
   original line verbatim") branch, even when every real task id is active — the fused token
   always counts as "not kept", so `kept < n2` unconditionally whenever a flag is present.
2. The partial-keep branch (`kept > 0`) rebuilds the line purely from the ids that matched
   `active[]`; the flag is not one of those ids, so it is **silently discarded** even in the
   "mostly correct" outcome.
3. When the Run line names exactly one task and that task is active, the fused token
   (`"714--hard"`) is the *only* entry, `kept` is `0` (it never matches), and `n2` is `1`
   (`kept == n2` fails: `0 != 1`). Neither output branch fires, so **the entire line is dropped
   with zero trace** — the most severe shape of this defect, matching the stage-layout
   reproduction already recorded in the originating issue log
   (`/orchestrate 1,2 --hard   # rationale` with task 1 terminal and task 2 active collapsing to
   an empty line).

**Sibling defect — `count_pruned_next_ids()` (lines 600-616)**: performs the same
whitespace-collapse (`ids_csv="${ids_csv//[[:space:]]/}"`) and feeds the fused token to
`jq -e --argjson n "$id" '... index($n) ...'`. A fused token like `"714--hard"` is not valid JSON,
so `jq --argjson` errors (`jq: invalid JSON text passed to --argjson`, exit 2); the `if !`
wrapper around it treats any non-zero jq exit as "not active," so this function *also*
mis-identifies the active task as pruned. This only affects the diagnostic
`pruned=`/`retained=` stderr marker counts (documented in `roadmap-format.md`'s "Stderr Marker
and Failure Diagnostics" section) — it has no effect on file content — but it shares the exact
root cause and should be fixed in the same pass for consistency, since a mis-reported `pruned=`
count on a content-loss run would otherwise mask the very failure this task exists to fix.

**Grammar gap**: `context/formats/roadmap-format.md`'s "Next Grammar" section documents
`^/orchestrate ([\d, ]+)(\s{3}# (.+))?$` and the "Parsing Patterns Summary" table repeats the
same regex for "Next Run line" — neither admits a CLI flag token at all. The live BimodalLogic
roadmap that triggered this task's discovery evidently authors Run lines with flags in practice
(`/orchestrate 716,714 --hard   # rationale`), which is outside this documented grammar. This is
a real gap between the spec and observed authored content, not a parsing edge case invented for
this report.

**Test coverage gap**: `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh`
(822 lines) has `--prune` coverage for both layouts (classic: "Case group 3" starting at line
393; stage: "Phase 5" starting at line 631), but every fixture Run line in both groups is a bare
comma-separated id list — none include a CLI flag token in either layout. This is precisely why
the defect reached a live file undetected.

### External Resources

Not applicable — this is a self-contained shell/awk/jq parsing defect with no external library or
API involvement.

## Decisions

- Confirmed root cause: `gsub(/[ \t]/, "", tasklist)` in `prune_next_body()` strips the separator
  space between the task-id list and a trailing CLI flag, fusing them into one token that can
  never match the active-id lookup.
- Confirmed the defect is layout-independent: both `mode_prune_classic` and `mode_prune_stage`
  call the identical, unmodified function.
- Confirmed a second, independent manifestation of the same root cause in the sibling counting
  function `count_pruned_next_ids()`, affecting only the stderr diagnostic counters (not file
  content).
- Confirmed via reproduction that the worst-case failure is total, silent disappearance of a
  single-task flagged Run line (`kept=0`, `n2=1`), not merely a wrong partial result.
- Scoped this report to characterization only; no code change was made (research phase).

## Recommendations

1. **Fix `prune_next_body()` to separate the flag segment from the task-id list before
   whitespace-stripping**, e.g.: split `core` (the pre-rationale portion, already carved off by
   the existing `pos`/`rationale` logic) on the first run of whitespace into `tasklist` (first
   token) and a `flags` remainder (everything after); whitespace-strip and comma-split only
   `tasklist`; preserve `flags` verbatim; re-splice it back into both output branches (the
   unchanged-line branch already preserves it implicitly since it prints `line` unmodified — only
   the partial-keep reconstruction and any would-be all-active fast path need to explicitly
   re-append ` ` + `flags` before `rationale`).
2. **Fix `count_pruned_next_ids()` with the same token-separation approach** so its `jq -e
   --argjson` lookup only ever receives a plain numeric id, never a fused flag token — this
   closes the diagnostic-counter corruption alongside the content-loss fix, in the same edit
   pass, since both functions share one root cause and one file.
3. **Add test cases to `scripts/tests/test-roadmap-generation.sh`, in both the classic
   ("Case group 3") and stage ("Phase 5") `--prune` groups**, covering at minimum the four
   scenarios the task description names plus the single-task total-disappearance case this
   research surfaced as the most severe shape:
   - a flagged Run line with a comment, mixed active/terminal ids (expect: flag preserved,
     terminal id dropped, active id(s) kept)
   - a flagged Run line with a comment, all-active ids (expect: entire line incl. flag
     preserved verbatim)
   - a flagged line with no comment
   - an unflagged line with a comment (regression guard — this already works correctly)
   - multiple flags (`--hard --lit`) on one Run line
   - a single-task flagged Run line where that task is active (regression guard against total
     line loss)
4. **Resolve the grammar-gap question during planning**, not as a research-phase decision: either
   (a) extend `context/formats/roadmap-format.md`'s "Next Grammar" and "Parsing Patterns Summary"
   regex to formally admit an optional flag segment between the task-id list and the rationale
   comment, matching observed live-file authoring practice, or (b) explicitly document CLI flags
   in a Run line as an out-of-grammar authored convention that the generator must nonetheless
   round-trip losslessly. Given the task's own description cites a real, currently-authored live
   file using flags this way, option (a) (documenting reality) is the more consistent outcome,
   but this is the planning phase's call, not this report's.
5. **Keep the fix confined to `roadmap-integration.sh`** — no other file needs to change for the
   defect itself; only the format doc (if option 4a is chosen) and the test file are secondary
   touches.

## Risks & Mitigations

- **Risk**: a fix that re-splices the flag segment could reintroduce spacing drift (e.g. doubled
  spaces, or losing the exact `   # ` 3-space separator convention the grammar depends on).
  **Mitigation**: the four-plus test cases in Recommendation 3 must assert the exact output
  string, not just "contains the flag," to catch spacing regressions.
- **Risk**: fixing `count_pruned_next_ids()` changes the `pruned=`/`retained=` stderr marker
  values for any existing fixture that happens to rely on the old (wrong) counts.
  **Mitigation**: re-run the full existing test suite after the fix; any count assertion that
  changes should be re-verified against hand-computed expected values, not just accepted as
  "different."
- **Risk**: scope creep into redefining the Next Grammar more broadly than flag support (e.g.
  trying to support arbitrary trailing text). **Mitigation**: Recommendation 4 scopes the grammar
  change narrowly to "an optional flag segment," matching exactly what the live file and the task
  description describe — nothing broader.

## Context Extension Recommendations

- **Topic**: CLI-flag-bearing Run lines in `ROADMAP.md`.
- **Gap**: `context/formats/roadmap-format.md`'s "Next Grammar" section and "Parsing Patterns
  Summary" table do not mention CLI flags in a Run line, even though real authored roadmaps
  (confirmed in the originating issue log and this task's own description) use them.
- **Recommendation**: once the planning phase resolves the grammar-gap question
  (Recommendation 4 above), update `roadmap-format.md`'s Next Grammar regex and summary table to
  reflect the chosen outcome, so the generation contract stops silently diverging from observed
  authoring practice.

## Appendix

**Reproduction harness** (ran against the function body copied verbatim from
`roadmap-integration.sh:680-716`, with `active_ids_json='["714","716"]'`):

| Input | Expected (714, 716 both active) | Actual output |
|---|---|---|
| `/orchestrate 716,714 --hard   # rationale text` | line unchanged (both active, flag kept) | `/orchestrate 716   # rationale text` (714 dropped, flag lost) |
| `/orchestrate 716,714 --hard` (no comment) | line unchanged | `/orchestrate 716` (714 dropped, flag lost) |
| `/orchestrate 716,714   # rationale text` (no flag) | line unchanged | `/orchestrate 716,714   # rationale text` (correct — no flag, no bug) |
| `/orchestrate 716,714 --hard --lit   # rationale text` | line unchanged | `/orchestrate 716   # rationale text` (714 dropped, both flags lost) |
| `/orchestrate 714 --hard   # rationale text` (single active task) | line unchanged | **(nothing printed — entire line vanishes)** |

Sibling-defect confirmation:
```
$ id="714--hard"; jq -e --argjson n "$id" '. as $a | $a | index($n) != null' <<<'["714","716"]'
jq: invalid JSON text passed to --argjson
(exit 2)
```

**Search queries / commands used**:
- `grep -rn "prune_next_body"` across the repo to locate definition and both call sites.
- `sed -n` ranges over `roadmap-integration.sh` (lines 650-780, 900-965, 596-640) to read the
  function, its call sites, and the sibling counter in full.
- `grep -n` over `context/formats/roadmap-format.md` for the Next Grammar and Parsing Patterns
  Summary sections.
- `grep -n "prune"` over `scripts/tests/test-roadmap-generation.sh` to confirm the existing
  `--prune` test groups and their lack of flag-bearing fixtures.
- `diff` between the source-store and deployed copies of `roadmap-integration.sh` to confirm the
  canonical edit target.
- Standalone bash/awk/jq reproduction script in the session scratchpad replaying the real
  function against five representative inputs plus one jq-based sibling-defect confirmation.
