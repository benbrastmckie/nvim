# Research Report: Task #407

**Task**: 407 - Derive artifact round from existing artifacts
**Started**: 2026-11-04T00:00:00Z
**Completed**: 2026-11-04T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core source store), grep/read of skill-base.sh, orchestrate-build-dispatch.sh, orchestrate-cycle-plan.sh, commands/task.md, context/contracts/conclusion-stage.md, skills/skill-reviser/SKILL.md, state-management-schema.md, scripts/tests/test-orchestrate-build-dispatch.sh, literature-create-setup-task.sh
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root cause described in the task is confirmed exactly, line-for-line, in the source store:
  `skill-base.sh`'s `skill_read_artifact_number()` (function starts line 557) reads
  `.next_artifact_number // 1` on line 570, so an absent field is defaulted to the string `"1"`
  before the very next line's `[ "$next_num" = "null" ]` check runs — that check can now only
  ever see the literal defaulted `"1"`, never `null`, so the legacy directory-fallback branch
  (lines 578-583) is unreachable whenever the field is merely absent. The fix is almost
  certainly in this one function.
- The simplest correct fix is to drop the `// 1` default on the read (line 570) so an absent
  field surfaces as jq's literal `"null"` string, which the existing `[ "$next_num" = "null" ]`
  guard already handles — restoring, not rewriting, the function's own intended control flow.
- The existing fallback (lines 578-583) must *also* change: it currently counts files
  (`ls ... | wc -l`) in a single artifact-type directory and ignores `mode` entirely. The task
  requires max-prefix-not-count semantics, and a file count silently collapses a sequence gap.
  **`skills/skill-reviser/SKILL.md`'s Stage 3a (not in the dispatch's named surfaces) already
  implements exactly this max-prefix reconciliation** — scanning the whole task directory
  (`find specs/{NNN}_{slug} -name "[0-9][0-9]_*.md"`, recursive across reports/plans/summaries)
  for the max on-disk prefix and bumping up to `max+1` whenever the counter-derived number is
  `<=` that max. This is directly reusable prior art, not a pattern to invent from scratch.
- No creation-time path in this repository's core extension currently writes a non-empty
  `artifacts[]` at task-creation time: `/task` (`commands/task.md` Step 6) never sets
  `artifacts` or `next_artifact_number` at all; conclusion-stage Step 4c (channel c) always
  writes `"artifacts": []`; `literature-create-setup-task.sh` (the one site that does set
  `next_artifact_number`, to 1) also always writes `"artifacts": []`. The observed defect's
  "pre-supplied findings" scenario (a report committed alongside task creation, with
  `artifacts[]` hand-populated) is not reproducible through any automated core creation path
  today — it requires manual state.json authorship or an external/future creation path.
  **Consequence**: the round-resolution fix in `skill_read_artifact_number()` is necessary and
  sufficient for the observed defect; a creation-time write is defense-in-depth, not a
  requirement, since no current call site needs it.
- The dispatch names `orchestrate-cycle-plan.sh` as "the minting surface," inherited verbatim
  from the originating record. A full-file grep finds **zero** occurrences of
  `next_artifact_number` in that file; every "mint" comment there is about `dispatch_seq`, an
  unrelated counter. Recommend dropping the three TERRITORY EDGES declared against it, per the
  dispatch's own stated escape hatch.

## Context & Scope

Researched where and how `next_artifact_number` is read, written, and defaulted across the
core extension's source store (`/home/benjamin/.config/nvim/agent-system/extensions/core`,
resolved from `.claude-extensions.json`'s per-extension `source_dir`, confirmed present), to
determine the minimal correct fix for: a task created with a pre-supplied artifact (already on
disk, already linked in `state.json`'s `artifacts[]`) must not mint round 1 again and collide
with/shadow that artifact; it must mint (max existing MM prefix) + 1.

Scope covers: the round-resolution read path (`skill_read_artifact_number`), its only orchestrate
call site (`orchestrate-build-dispatch.sh`), the `task_lookup_entry` archive-aware lookup it
depends on, every identified task-creation write path in core, the regression test fixture
pattern already proven for this script, and `skill-reviser/SKILL.md`'s independent (and more
correct) implementation of the same concept for plan revisions.

## Findings

### Codebase Patterns

**The bug, confirmed at the exact cited location.**
`agent-system/extensions/core/scripts/skill-base.sh`, function `skill_read_artifact_number()`
(starts line 557):

```bash
next_num=$(task_lookup_entry "$task_number" specs/state.json | jq -r '.next_artifact_number // 1')
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  # Legacy fallback: count existing artifacts in directory
  ...
  count=$(ls "${fallback_task_dir}/${artifact_dir}"*[0-9][0-9]*.md 2>/dev/null | wc -l) || count=0
  ARTIFACT_NUMBER=$((count + 1))
elif [ "$mode" = "current" ]; then
  ARTIFACT_NUMBER="$next_num"
else
  # mode = "prev"
  ...
fi
```

`jq -r '.next_artifact_number'` on an object lacking that key yields the literal string `null`
(not empty) — exactly what the very next line's guard checks for. The `// 1` default intercepts
that before the guard ever runs, so the guard is dead code for the absent-field case; it only
still fires for a literally-`null` stored value (which nothing in this codebase writes). This
matches the dispatch's ROOT CAUSE paragraph verbatim; the deployed-copy line numbers it cited
(skill-base.sh ~557) land on the exact same line in the source store — no drift here.
`orchestrate-build-dispatch.sh`'s call site drifted slightly (comment at source-store line 269
vs. the dispatch's cited deployed-copy line 241 — expected per the dispatch's own
re-derive-before-editing instruction) but the call itself is unchanged:

```bash
case "$phase" in
  research) artifact_mode="current"; artifact_dir="reports/" ;;
  plan)     artifact_mode="prev";    artifact_dir="plans/" ;;
  implement) artifact_mode="prev";   artifact_dir="summaries/" ;;
esac
skill_read_artifact_number "$task_number" "$PADDED_NUM" "$PROJECT_NAME" "$artifact_dir" "$artifact_mode"
```

`skill_read_artifact_number` is this orchestrate flow's *only* call site (confirmed by a
repo-wide grep); `context/patterns/skill-lifecycle.md` separately notes that no `SKILL.md`
(the non-orchestrate, slash-command path) calls it by name either — those skills use their own
inline `jq` instead (see skill-reviser below).

**`task_lookup_entry` (archive-aware) is already correct and need not change.**
`scripts/lib/task-lookup-lib.sh`'s `task_lookup_entry()` returns the active entry, falling back
to the normalized archive only when absent from `active_projects` — this is the mechanism the
dispatch calls out as a "preserve" item, and it requires no change: the bug is entirely in how
the *returned* `.next_artifact_number` field is defaulted and interpreted, not in which record is
looked up.

**Prior art already solves the max-prefix requirement — in a sibling file, not the named
surfaces.** `skills/skill-reviser/SKILL.md`, Stage 3a ("Calculate Artifact Number"), has the
*same* `// 1` default bug on its own independent inline read:

```bash
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)
...
artifact_number=$next_num
# Reconciliation: scan all task subdirs for max artifact number on disk
padded_num=$(printf "%03d" "$task_number")
max_on_disk=$(find "specs/${padded_num}_${project_name}" -name "[0-9][0-9]_*.md" 2>/dev/null \
  | sed 's|.*/\([0-9][0-9]\)_.*|\1|' | sort -n | tail -1)
max_on_disk=${max_on_disk:-0}
max_on_disk=$((10#$max_on_disk))
if [ "$artifact_number" -le "$max_on_disk" ]; then
  artifact_number=$((max_on_disk + 1))
fi
```

Despite carrying the identical `// 1` defaulting bug, this code *already* produces the
task-173-equivalent correct answer for a pre-supplied artifact: `next_num` defaults to `"1"`,
`artifact_number` starts at `1`, then the reconciliation scan finds `max_on_disk=1` (the
pre-supplied `01_...md`), and because `1 <= 1`, bumps to `2`. This is precisely the
max-prefix-plus-one semantics the task wants, implemented as a second, independent
safety-net step rather than by fixing the primary read. **This is directly portable**: the
same scan-and-bump step, generalized across the task directory (not one artifact-type
subdirectory), would fix `skill_read_artifact_number()`'s fallback without needing to also fix
the `// 1` default — though fixing the default too is still correct and removes dead code.
`skill-reviser/SKILL.md` is not in the dispatch's named SURFACES list; it is additional
evidence/pattern, not a file this task is obligated to touch, but its logic is the strongest
available reference implementation.

**No core creation path currently produces the triggering condition.**
- `commands/task.md` Step 6 (ordinary `/task "description"` creation, lines 227-245): the new
  `active_projects` entry template sets `project_number`, `project_name`, `status`, `task_type`,
  `description`, `topic`, `created`, `last_updated` — **no `artifacts` field and no
  `next_artifact_number` field at all**. A grep of the whole file for "artifact" turns up only
  prose about directory naming conventions, never a write.
- `context/contracts/conclusion-stage.md` Step 4c (channel c, follow-up-task-as-child creation,
  lines 316-326): writes `"artifacts": []` explicitly (always empty) and no
  `next_artifact_number` field.
- `agent-system/extensions/literature/scripts/literature-create-setup-task.sh`: the *only* site
  anywhere in the deployed tree that sets `next_artifact_number` (to `1`) — and it also always
  writes `"artifacts": []`. Confirmed by the dispatch's own ROOT CAUSE paragraph and verified
  directly in this research pass.

Given this, the specific "task created with a pre-supplied report already linked in
`artifacts[]`" scenario observed for task 173 in the other repository cannot currently arise
through any automated core creation path in *this* repository — it requires either manual
`state.json` authorship (as apparently happened for task 173) or some creation path outside
core/literature not found in this search. This does not make the defect unreal (the round-
resolution bug fires for *any* task entry lacking `next_artifact_number`, which per
`state-management-schema.md` is "zero occurrences in the current active snapshot" — i.e. nearly
every live task today is on the buggy codepath, just without a pre-existing file to collide
with yet); it does mean the creation-time half of "Implement at task creation... or at
round-resolution time... or both" has no natural, necessary call site in core today.

**Stale description detail — `orchestrate-cycle-plan.sh` is not a `next_artifact_number`
surface.** The dispatch's SURFACES list names `core/scripts/orchestrate-cycle-plan.sh` "as the
minting surface." A full grep of that file for `next_artifact_number` returns zero matches;
every "mint" reference in it concerns `dispatch_seq` (a different, unrelated per-dispatch
counter — see its own header comment at line 6 and inline comments at lines 1515-2804). The
actual `next_artifact_number` *mutation* (not read) sites in core are:
- `orchestrator-postflight.sh` line ~363 (increment, research-only)
- `orchestrate-stage5-postflight.sh` line ~274 (advance on forced/non-forced research completion)
- `orchestrate-cycle-postflight.sh` line ~1608 (advance, same semantics)
- `skills/skill-reviser/SKILL.md` Stage 8a (increment on revision)
- `commands/task.md` Step 6 / `conclusion-stage.md` Step 4c (creation; currently never writes
  the field at all — the gap this task targets, if a creation-time fix is chosen)

None of these increment/mutation sites are named in the dispatch's SURFACES list either, which
is fine (this task is read-side/creation-side, not increment-side), but it reinforces that
`orchestrate-cycle-plan.sh` specifically is not implicated.

**Regression test fixture pattern (ready to extend).**
`scripts/tests/test-orchestrate-build-dispatch.sh` builds a fixture repo
(`$WORKDIR/fixture-repo`) with a real `specs/state.json` and real artifact files, invokes the
real (unstubbed) `orchestrate-build-dispatch.sh` + `skill-base.sh` via
`SKILL_REPO_ROOT="$FIXTURE" bash "$SUT" ...`, and asserts on the composed dispatch file's
`artifact_number: N` line. The existing Group 1 fixture (lines 106-125) sets
`"next_artifact_number": 2` with one pre-existing `01_fixture-report.md`, asserting
`artifact_number: 2` for `mode=current`. The dispatch's required new case — **no**
`next_artifact_number` field, one pre-existing `01_...md` artifact present and linked — slots
into this exact pattern: a new fixture entry (or a second `run_sut research` invocation against
a second fixture task number) omitting `next_artifact_number`, with `artifacts: [{"type":
"report", "path": ".../reports/01_....md", ...}]` and the file present on disk, asserting
`artifact_number: 2`.

### External Resources

Not applicable — this is a pure internal shell/jq logic defect with no external library or API
surface.

## Recommendations

1. **Fix `skill_read_artifact_number()` in `agent-system/extensions/core/scripts/skill-base.sh`
   (the necessary and sufficient fix)**:
   - Remove the `// 1` default on the primary read (line 570) so an absent field surfaces as
     jq's literal `"null"`, re-arming the existing `[ "$next_num" = "null" ] || [ -z "$next_num" ]`
     guard exactly as originally intended.
   - Replace the fallback's file-*count* (`ls ... | wc -l`) with a max-*prefix* scan across the
     **whole task directory** (not just the one `artifact_dir` passed in), modeled directly on
     `skill-reviser/SKILL.md`'s Stage 3a reconciliation (`find ... -name "[0-9][0-9]_*.md" | sed
     ... | sort -n | tail -1`, `10#` to strip leading-zero octal interpretation, bump to
     `max_on_disk + 1`). Scanning the whole task dir (not one subdirectory) matches the "round"
     concept: reports/plans/summaries share one sequence.
   - Apply `mode` to the fallback result too (currently it is ignored there): for `mode=prev`,
     the fallback's derived "next" value must still go through the same `-1` (floor 1) adjustment
     the non-fallback branches already apply, so a plan/implement dispatch hitting the fallback
     shares the same round as a preceding research dispatch rather than minting its own.
   - Consider extracting the reconciliation scan into a small shared helper (e.g. in
     `scripts/lib/`) so `skill-base.sh` and `skills/skill-reviser/SKILL.md` stop maintaining two
     copies of the same max-prefix logic — a de-duplication opportunity surfaced by this
     research, not a requirement.
2. **Extend `scripts/tests/test-orchestrate-build-dispatch.sh`** with the dispatch-required case:
   a fixture task entry with no `next_artifact_number` field and one pre-existing/linked
   `01_...md` report, asserting `artifact_number: 2` for a `mode=current` (research) dispatch.
   Also worth adding (not required by the dispatch, but cheap given the fixture is already
   there): the same absent-field-plus-pre-supplied-artifact case for `mode=prev` (plan/implement),
   to lock in the mode-awareness fix above.
3. **Creation-time write — treat as optional defense-in-depth, not a required surface.** No
   identified core creation path both allows pre-supplied non-empty `artifacts[]` and is
   reachable before the first dispatch, so there is no concrete call site in core requiring a
   creation-time `next_artifact_number` write for this specific defect. If the plan still wants
   belt-and-suspenders creation-time coverage, the two live creation sites to touch are
   `commands/task.md` Step 6 and `context/contracts/conclusion-stage.md` Step 4c — but
   `literature-create-setup-task.sh` already demonstrates the intended write (`"artifacts": []`
   alongside `"next_artifact_number": 1`) can be done safely when a path legitimately needs it.
4. **Drop the three TERRITORY EDGES against `orchestrate-cycle-plan.sh`** declared in the
   dispatch (reviser-agent handoff contradiction, whole-tree-regeneration scope-claim,
   shared-verify-deploy-gate-run) — this task's chosen fix touches `skill-base.sh` and its test
   file, and optionally `commands/task.md`/`conclusion-stage.md`; none of these overlap
   `orchestrate-cycle-plan.sh`, which this research confirms carries no `next_artifact_number`
   logic at all.
5. **Update `context/reference/state-management-schema.md`'s "Backward Compatibility" section**
   (lines 208-214), which currently documents the count-based fallback as the intended behavior
   — it should be updated to describe the max-prefix behavior once the code changes, so the doc
   stays the source of truth rather than describing superseded logic.

## Decisions

- The fix is scoped to the round-*resolution* path (`skill_read_artifact_number()` in
  `skill-base.sh`) as the necessary surface; a creation-time write is recommended only as
  optional defense-in-depth, since no live core creation path currently needs it to avoid the
  observed collision.
- `skill-reviser/SKILL.md`'s existing reconciliation-scan pattern is adopted as the reference
  design for the fallback's max-prefix behavior rather than inventing a new algorithm.
- `orchestrate-cycle-plan.sh` is confirmed out of scope for the implementation; the plan should
  explicitly drop the three declared territory edges against it, per the dispatch's own
  stated escape hatch for exactly this situation.

## Risks & Mitigations

- **Risk**: scanning the whole task directory (not just the mode-appropriate subdirectory) for
  the fallback's max-prefix could pick up an artifact type irrelevant to the current dispatch
  if some future artifact type uses a non-`MM_` naming convention. *Mitigation*: constrain the
  glob/find pattern to the existing `[0-9][0-9]_*.md` two-digit-prefix convention (already used
  by `skill-reviser`), which only matches artifacts following the documented naming convention.
- **Risk**: changing fallback semantics from count-based to max-prefix-based could change
  behavior for any *existing* legacy task currently relying on the count-based fallback with a
  contiguous, gap-free sequence. *Mitigation*: for a gap-free sequence, count and max-prefix
  produce identical results by construction — only tasks with an actual gap (the exact case this
  task exists to fix) will see a different, now-correct number.
- **Risk**: applying `mode` inside the fallback branch is new logic not present today (the
  current fallback ignores `mode` entirely) — a plan/implement dispatch that hits the fallback
  today silently gets `mode=current` semantics regardless of its real mode. *Mitigation*: this is
  flagged explicitly in Recommendation 1 so the implementer verifies it is a true pre-existing
  gap and not working-as-intended; the new test case in Recommendation 2 should include a
  `mode=prev` fallback assertion to lock in the corrected behavior.

## Context Extension Recommendations

- **Topic**: Max-prefix artifact-round reconciliation.
- **Gap**: `context/reference/state-management-schema.md`'s "Unified Artifact Numbering" section
  documents the fallback as count-based (lines 208-214); once implemented, this contradicts the
  actual code.
- **Recommendation**: Update that section's fallback example to the max-prefix scan, and note
  that `skill_read_artifact_number()` and `skill-reviser/SKILL.md` Stage 3a now share the same
  reconciliation approach (or a shared helper, if extracted).

## Appendix

- Search queries / commands used: `jq` extraction of `.claude-extensions.json`'s `core.source_dir`;
  `grep -n "skill_read_artifact_number"` repo-wide; `sed -n` reads of
  `scripts/skill-base.sh` (lines 530-620), `scripts/orchestrate-build-dispatch.sh` (lines
  220-290), `commands/task.md` (lines 195-284), `context/contracts/conclusion-stage.md` (lines
  230-340), `scripts/lib/task-lookup-lib.sh` (lines 1-90), `skills/skill-reviser/SKILL.md` (lines
  85-135), `context/reference/state-management-schema.md` (lines 180-220); grep for
  `next_artifact_number` and `"artifacts":` repo-wide; grep for `mint` in
  `orchestrate-cycle-plan.sh`; inspection of `scripts/tests/test-orchestrate-build-dispatch.sh`
  (lines 80-305) for the existing fixture/assertion pattern.
- References: `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`,
  `agent-system/extensions/core/commands/task.md`,
  `agent-system/extensions/core/context/contracts/conclusion-stage.md`,
  `agent-system/extensions/core/skills/skill-reviser/SKILL.md`,
  `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`,
  `agent-system/extensions/literature/scripts/literature-create-setup-task.sh`.
