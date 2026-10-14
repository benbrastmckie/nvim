# Research Report: Task #379

**Task**: 379 - Make specs/archive/state.json validatable by validate-state.sh
**Started**: 2026-10-14T00:00:00Z
**Completed**: 2026-10-14T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (`validate-state.sh`, `test-validate-state.sh`, `state-schema.json`,
`state-management-schema.md`, `task-abandon-mode.md`, `skill-todo/SKILL.md`, `state-write.sh`),
live reproduction against this repo's own `specs/archive/state.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Root cause confirmed by live reproduction: `validate-state.sh`'s base-mode checks are hard-wired
  to `.active_projects[]`; `specs/archive/state.json` carries `archived_projects` /
  `completed_projects` instead, so Checks 2 (required fields) correctly FAIL, but Checks 5, 6, and
  7 silently log a **false PASS** — the jq pipeline errors ("Cannot iterate over null"), produces
  zero output lines, and the script's "zero bad entries found" logic reads that as "nothing wrong"
  rather than "could not check." This is the concrete shape of the dispatch's requirement 2 ("a
  silent inability to validate is the defect") and must be closed regardless of which fix
  direction is chosen.
- `state-schema.json`'s own header already documents, as a *deliberate* prior decision, that
  `specs/archive/state.json` is out of scope for the active schema because its shape is
  "materially different, looser" — this was a known gap, not an oversight, which is why a new,
  separate check path (not a forced fit into the active schema) is the right shape for the fix.
- `/task --abandon`'s archive insert (the exact write this task is about) lands in
  `completed_projects` with `status: "abandoned"` and a timestamp field named `abandoned` — a
  third shape, distinct from both `skill-todo`'s `archived_projects` insert (`archived_at`) and
  its `completed_projects` insert. Any new check set must be verified against this literal shape,
  not only a synthetic one.
- Live measurement against this repo's real `specs/archive/state.json` (328 `completed_projects`
  entries, 48 `archived_projects` entries) found 24 `project_number` values present in **both**
  arrays simultaneously (e.g. project 31: `abandoned` in `archived_projects`, `orphan_archived` in
  `completed_projects`) and an `orphan_archived` status value that is not a member of the active
  schema's 13-value enum. Any new duplicate/status check over the archive must start **advisory
  (WARN)**, not FAIL, or it immediately regresses against this repository's own current data —
  mirroring this script's own established advisory-first/PROMOTION CRITERION idiom used
  throughout for every comparable rollout (Checks 3/4/8/9/10/11, D6).
- Recommended direction: an explicit `--archive` mode flag (not silent shape auto-detection),
  running a separate, deliberately looser check set against `archived_projects` /
  `completed_projects`, with the same PASS/WARN/FAIL idiom already used elsewhere in this script.

## Context & Scope

Task 379 requires that an archive insert (specifically the one `/task --abandon` performs into
`specs/archive/state.json`) be validatable by the standard gate (`validate-state.sh`). The
direction is deliberately left open — teach the script the archive's shape, or add an explicit
mode — but two requirements are fixed: (1) an archive insert must be validatable by the standard
gate, and (2) the gate must never land in a state where it neither validates the archive nor says
it cannot (no silent, undetected inability). The existing test suite
(`agent-system/extensions/core/scripts/tests/test-validate-state.sh`) must be extended to cover
whichever archive shape is chosen. `file_scope` for this task is exactly those two files:
`agent-system/extensions/core/scripts/validate-state.sh` and
`agent-system/extensions/core/scripts/tests/test-validate-state.sh`. This research reproduces and
diagnoses the defect against the live codebase and the live `specs/archive/state.json`, and scopes
the fix options available within that file_scope.

The source-store edit target is `agent-system/extensions/core/**`, never `.claude/**` (per
`rules/source-store-deploy-boundary.md`); all file paths below are the source-store copies.

## Findings

### Codebase Patterns

**Live reproduction of the defect.** Running
`bash agent-system/extensions/core/scripts/validate-state.sh specs/archive/state.json` against
this repository produces:

```
[PASS] JSON is valid and parsable
[FAIL] Required top-level field missing: next_project_number
[FAIL] Required top-level field missing: active_projects
[WARN] Unknown top-level field: archived_projects
[PASS] No unknown active_projects[] entry fields
jq: error (at .../specs/archive/state.json:14413): Cannot iterate over null (null)
[PASS] All active_projects[].status values are members of the closed enum
jq: error (at .../specs/archive/state.json:14413): Cannot iterate over null (null)
[PASS] All active_projects[].project_number values are numbers
jq: error (at .../specs/archive/state.json:14413): Cannot iterate over null (null)
[PASS] All active_projects[].task_type values are non-empty strings
...
Failed:   2
STATE VALIDATION FAILED  (exit 1)
```

Exit code 1 is in fact correct here (driven solely by Check 2's two required-field FAILs), but
Checks 5 ("status enum membership"), 6 ("project_number is a number"), and 7 ("task_type is a
non-empty string") each **falsely PASS**. Each is implemented as a `while read` loop fed by a jq
pipeline over `.active_projects[]` with no `// []` fallback
(`validate-state.sh:596-623`); when that key is absent, jq raises a runtime error, the pipeline
produces zero stdout lines, the `while` loop body never executes, and the bad-count variable stays
at its initialized zero — which the script's own logic reads as "verified clean," not "unable to
verify." This is the textbook shape of the dispatch's requirement 2: these three checks do not
merely fail to validate the archive, they **actively misreport** that they did and found nothing
wrong. Whatever shape the fix takes, this false-PASS failure mode must be eliminated for the
archive case specifically (e.g. by having the archive-specific checks operate on the correct
top-level keys from the start, never falling through to the active-mode jq pipelines at all when
in archive mode).

**`state-schema.json`'s own documented scope boundary.** The schema's top-level `description`
field (`agent-system/extensions/core/context/schemas/state-schema.json:5`) already states, as a
settled prior decision: "this schema targets the ACTIVE state store (specs/state.json) only.
specs/archive/state.json has a materially different, looser shape (archived_projects/
abandoned_projects/completed_projects arrays with many one-off historical fields such as
researching_2, plan_metadata, previous_status) and is deliberately NOT validated against this
schema." This confirms the gap is a known, named, prior scoping decision — not an accidental
omission — which argues for a parallel/separate archive-specific check set rather than trying to
retrofit the archive into the existing `active_projects`-shaped schema and `KNOWN_*_FIELDS`
allowlists (Checks 3/4). Note this comment is itself slightly stale: `researching_2` and
`plan_metadata` do not currently appear anywhere in the live archive file (see below) — a sign
that the archive's field set has already been cleaned up once since this comment was written, and
will likely keep drifting, reinforcing that any new archive check set should treat unknown fields
as advisory (WARN), not FAIL, from day one.

**The archive file's actual top-level and per-entry shape (measured against the live file).**
`specs/archive/state.json` has exactly two top-level keys today: `archived_projects` (48 entries,
all `status: "abandoned"`) and `completed_projects` (328 entries, `status` ∈
`{abandoned, completed, expanded, orphan_archived}`). There is **no** top-level
`next_project_number`, and **no** `abandoned_projects` array in the live file, even though
`validate-state.sh`'s own `--deep` dependency/parentage checks defensively read
`(.archived_projects // [])`, `(.abandoned_projects // [])`, and `(.completed_projects // [])` when
looking up "known project numbers" in the sibling archive
(`validate-state.sh:893-894, 1002-1003`). A repo-wide grep for `abandoned_projects` found no writer
anywhere in `agent-system/extensions/` — it is dead vocabulary defensively tolerated by the `// []`
idiom, not a live third array. Any new archive-mode check set should recognize
`archived_projects`/`completed_projects` as the two real top-level arrays and treat
`abandoned_projects` as merely tolerated (present-but-empty is fine; absent is fine; its absence
must never be flagged as a defect).

Per-entry field sets, measured directly from the live file:
- `archived_projects[]` entries carry: `abandon_reason, archived_at, artifacts, created,
  dependencies, description, effort, file_scope, last_updated, next_artifact_number, priority,
  project_name, project_number, session_id, status, task_type, title, topic`.
- `completed_projects[]` entries carry a largely overlapping but distinct set: `abandoned,
  archived, archived_at, artifacts, blockers, blocks_note, completion_summary, created,
  dependencies, description, detected_artifacts, effort, file_scope, last_updated,
  memory_candidates, next_artifact_number, parent_task, priority, project_name, project_number,
  session_id, source, status, subtasks, task_type, title, topic`.

Both sets are richer and messier than the active schema's `KNOWN_ENTRY_FIELDS` allowlist (Check
4), confirming that reusing Check 3/4's allowlist mechanism verbatim for archive entries would
immediately produce a wall of (at best advisory) unknown-field noise.

**`/task --abandon`'s own archive-insert shape (the literal write this task is about).** Per
`agent-system/extensions/core/context/patterns/task-abandon-mode.md` (lines 36-50, read-only —
this file is declared `file_scope` for a different concurrent sibling task and must not be
edited here), the abandon flow writes:

```
bash .claude/scripts/state-write.sh \
  '.completed_projects = [$task | .status = "abandoned" | .abandoned = $ts] + .completed_projects' \
  --state-file specs/archive/state.json ...
```

This inserts into **`completed_projects`** (not `archived_projects`), setting `status: "abandoned"`
and a timestamp field named **`abandoned`** (not `archived_at`). This is a third, distinct shape
from `skill-todo/SKILL.md`'s own two archive-insert call sites (one into `archived_projects` with
`archived_at` for already-abandoned active tasks, one into `completed_projects` with `archived_at`
for completed/expanded tasks — `skill-todo/SKILL.md:442-535`). A fixture that only reproduces one
of these three shapes would not actually prove the gate validates the write this task names;
coverage should include the literal `/task --abandon` shape (`completed_projects` entry with
`status: "abandoned"` and an `abandoned` timestamp key, no `archived_at`).

**Why no caller already invokes `validate-state.sh` against the archive.** `state-write.sh`'s own
header (`state-write.sh:96-99`) explains that `generate-todo.sh`'s TODO.md regeneration is
deliberately never run against archive/vault targets, since TODO.md reflects only the live state;
it is silent on `validate-state.sh` specifically, but the practical effect is the same — no
existing caller (`commands/task.md`, `verify-deploy.sh` gate 10, `test-init-specs.sh`,
`test-validate-state.sh` itself) passes an archive path to `validate-state.sh` today. Wiring a new
caller (e.g. having `/task --abandon` or `skill-todo` call `validate-state.sh --archive` against
the write it just made) is a natural follow-on but is **outside this task's `file_scope`**
(`validate-state.sh` and `test-validate-state.sh` only) and is not required by the dispatch's two
fixed requirements — the requirement is that the gate becomes *capable* of validating the archive
when invoked, not that a new caller is added.

**Measured duplicate-project_number and off-enum-status counts (concrete rollout-risk data).**
Over the live archive file: 0 duplicate `project_number` values *within* `archived_projects`
alone; 0 *within* `completed_projects` alone; but **24** `project_number` values appear in *both*
arrays (e.g. project 31 is `abandoned` in `archived_projects` and `orphan_archived` in
`completed_projects`, with `archived_at: null` in the latter). `orphan_archived` is not a member
of `scripts/lib/status-vocabulary.sh`'s closed 13-value enum. Both findings are evidence of
historical reconciliation noise, not evidence of an active, ongoing defect this task is scoped to
fix — but they are decisive for the new check set's enforcement level: if a new "archive entry
status must be terminal" or "no cross-array duplicate project_number" check defaults to FAIL, it
fails immediately against this repository's own current, real data, the same mistake the active
schema's Checks 3/4/8/9/10/11 and D6 originally avoided by going advisory-first with a named
PROMOTION CRITERION.

### External Resources

No external (web) research was needed — this is a self-contained, codebase-internal shell/jq
defect with no external library or API surface involved.

## Decisions

- The defect is real, reproducible, and matches the dispatch's "VERIFIED NOT A REGRESSION" claim:
  it fails identically against the archive file regardless of recent history, because the script
  has never had any code path for this shape.
- The false-PASS behavior of Checks 5/6/7 against the archive's shape (not just Check 2's correct
  FAIL) is itself part of the defect this task must close — a fix that only addresses the two
  required-field FAILs while leaving Checks 5/6/7 free to silently false-PASS under `--archive`
  mode would not satisfy requirement 2 ("a silent inability to validate is the defect").
- `abandoned_projects` is confirmed dead/unused vocabulary (no writer found repo-wide); a new
  archive check set should tolerate its presence or absence without treating either as a finding,
  consistent with how `validate-state.sh` already treats it defensively elsewhere.
- Any new archive-scoped duplicate-project_number or status-membership check must start
  WARN/advisory (not FAIL), given the 24 live cross-array duplicates and the `orphan_archived`
  off-enum status actually present in this repository's own archive today.
- The `/task --abandon` insert shape (`completed_projects` entry, `status: "abandoned"`,
  `abandoned` timestamp key) is the shape named by this task's description and must be one of the
  fixtures the extended test suite exercises, not merely a synthetic archive-shaped fixture.

## Recommendations

1. **Add an explicit `--archive` mode flag** (over silent shape-based auto-detection). Rationale:
   this script's own idiom already gates every mode-shifting behavior behind an explicit flag
   (`--deep`, `--fix`, `--strict`), each documented with its own promotion/rollout posture;
   auto-detecting "this must be an archive file" from the absence of `active_projects` is less
   predictable and carries a subtle hazard — a genuinely corrupted *live* `specs/state.json` that
   has lost its `active_projects` key could, in principle, be silently re-routed into the looser
   archive checks instead of correctly FAILing Check 2, masking a real defect in the file that
   matters most. An explicit flag has no such ambiguity and costs nothing: no existing caller
   passes an archive path today (confirmed above), so there is no backward-compatibility
   constraint forcing auto-detection.
2. **Give `--archive` mode its own, parallel check set**, not a relaxed variant of the existing
   `active_projects` checks: validate JSON parsability (shared with base mode); require at least
   one of `archived_projects` / `completed_projects` to be present and, if present, to be an array
   (mirroring Check 2's required-field posture, but against the correct keys); per-entry checks
   for `project_number` being a number and `project_name`/`task_type` presence; a status-enum
   check against a **widened, archive-scoped vocabulary** (the active 13-value enum plus the
   currently-observed terminal/legacy values such as `orphan_archived`), reported as WARN rather
   than FAIL for any value outside even that widened set, so the live file does not immediately
   regress while still surfacing genuinely new/unexpected values; a WARN-only unknown-top-level/
   unknown-entry-field check scoped to the per-array field sets measured above
   (`archived_projects` vs. `completed_projects` have different real field sets — do not merge
   them into one allowlist); and a WARN-only cross-array duplicate-`project_number` check (never
   FAIL initially, given the measured 24 live duplicates), each carrying the same kind of
   PROMOTION CRITERION comment this script already uses elsewhere so a future tightening pass has
   a stated, checkable bar rather than an arbitrary one.
3. **Close the false-PASS failure mode as part of this fix, independent of direction chosen.**
   Whatever archive-mode checks are added, they must read from `archived_projects`/
   `completed_projects` directly (with their own `// []` guards) rather than ever falling through
   to the existing `.active_projects[]`-keyed jq pipelines when `--archive` is active — the
   current Checks 5/6/7 must simply not run in archive mode (replaced by the per-entry archive
   checks in Recommendation 2), so the "jq error -> zero lines -> false PASS" pattern cannot recur
   for this file shape.
4. **Extend `test-validate-state.sh` with at least these fixtures** (within this task's
   `file_scope`): (a) a positive archive-shaped fixture (`archived_projects` + `completed_projects`
   arrays, each with a few well-formed entries) exits 0 under `--archive`; (b) a fixture
   reproducing the literal `/task --abandon` write shape (a `completed_projects` entry with
   `status: "abandoned"` and an `abandoned` timestamp key, no `archived_at`) exits 0 under
   `--archive`, directly proving the write named in this task's description is now validatable;
   (c) a defect fixture (e.g. a non-numeric `project_number`, or an off-vocabulary status beyond
   even the widened archive set) produces a nonzero exit with a named error under `--archive`;
   (d) a regression guard proving that running the validator **without** `--archive` against an
   archive-shaped file still correctly reports the two Check-2 FAILs and does **not** silently
   false-PASS Checks 5/6/7 (i.e. pins today's partially-correct, partially-broken base-mode
   behavior against this shape, or — if the chosen fix changes base-mode's handling of this
   case — asserts whatever the new, intentional base-mode behavior is, so a regression to the
   false-PASS pattern is caught); (e) a WARN-level (not FAIL) fixture reproducing the cross-array
   duplicate-`project_number` shape, confirming the new check does not regress against this
   repository's own live data.
5. **Treat wiring a new caller (e.g. `/task --abandon` running `validate-state.sh --archive`
   against its own write) as an optional follow-on, not part of this task.** It is outside the
   declared `file_scope` (`validate-state.sh` and `test-validate-state.sh` only), and the dispatch
   only requires the gate to be *capable* of validating the archive when invoked — not that every
   writer is updated to invoke it. If the implementer judges this in-scope anyway, `task-abandon-
   mode.md` is concurrently claimed by a sibling task's `file_scope` this cycle and must not be
   edited without first re-checking its current state for a sibling's in-flight changes.

## Context Extension Recommendations

- **Topic**: `state-schema.json`'s header comment describing `specs/archive/state.json`'s shape
  (mentioning `researching_2`, `plan_metadata` as example one-off fields).
  **Gap**: That comment is now stale — neither field appears in the live archive file, and the
  comment does not mention `orphan_archived` or the `/task --abandon`-specific `abandoned`
  timestamp-key shape documented in this report.
  **Recommendation**: Once an `--archive` mode exists and its own field-set/status-vocabulary
  decisions are finalized, refresh this comment to match (out of scope for this task's
  `file_scope`, but worth flagging for the implementer or a follow-up task).

## Appendix

- Commands run: `bash agent-system/extensions/core/scripts/validate-state.sh
  specs/archive/state.json` (live reproduction); various `jq` queries against
  `specs/archive/state.json` to measure top-level keys, per-array field sets, status-value sets,
  and cross-array `project_number` duplication.
- Files read: `agent-system/extensions/core/scripts/validate-state.sh`,
  `agent-system/extensions/core/scripts/tests/test-validate-state.sh`,
  `agent-system/extensions/core/context/schemas/state-schema.json`,
  `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `agent-system/extensions/core/context/patterns/task-abandon-mode.md` (read-only; declared
  `file_scope` of a concurrent sibling task this cycle),
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`,
  `agent-system/extensions/core/scripts/state-write.sh`,
  `agent-system/extensions/core/scripts/lib/status-vocabulary.sh`.
