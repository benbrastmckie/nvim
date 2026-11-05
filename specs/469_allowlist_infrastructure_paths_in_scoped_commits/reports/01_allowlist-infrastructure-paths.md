# Research Report: Task #469

**Task**: 469 - Allowlist infrastructure paths in scoped commits
**Started**: 2026-11-04T00:00:00Z
**Completed**: 2026-11-04T00:00:00Z
**Effort**: medium
**Dependencies**: None (concurrent-territory note only; see Risks & Mitigations)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/git-commit-scoped.sh`,
`orchestrate-cycle-postflight.sh`, `git-commit-phase.sh`, `errors-append.sh`,
`events-append.sh`, `lib/derived-artifact-probe-lib.sh`), `context/standards/git-staging-scope.md`,
archived task #467's `issues.jsonl`/`.orchestrator-handoff.json`/progress files, `git log`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed the three Containment sites exist exactly as the dispatch describes, and pinned
  their exact literal-allowlist locations: `git-commit-scoped.sh:499` (V10,
  `containment_scope_arr`) and `orchestrate-cycle-postflight.sh:1670` (WORK (h),
  `effective_file_scope_json`) each hand-copy `("specs/TODO.md" "specs/state.json")`;
  `git-commit-phase.sh`'s own Containment Self-Check (lines ~229-282) carries **no** allowlist
  at all today because its two fixed paths are pre-excluded from testing rather than admitted
  through it (see Findings).
- A full grep of every `git-commit-scoped.sh` caller (scripted call sites in
  `orchestrate-cycle-postflight.sh`, `orchestrator-postflight.sh`, `git-commit-phase.sh`,
  `commands/task.md`, `skill-meta/SKILL.md`, `skill-spawn/SKILL.md`, `commands/errors.md`,
  `commands/review.md`, `orchestrate-unwind-dispatch.sh`) found **no script that literally names
  `specs/events.jsonl` in a pathspec** — confirming the dispatch's own task-creation-time finding
  rather than overturning it.
- The one mechanism that CAN carry an arbitrary path like `specs/events.jsonl` into a commit
  pathspec without any script hardcoding it is the agent-self-reported `modified_files` field on
  `.return-meta.json`, consumed by WORK (h)/(i) in `orchestrate-cycle-postflight.sh`. This is
  the most plausible real end-to-end route for a future recurrence and is exactly the route an
  honest-reporting agent takes if it ever runs `events-append.sh` (or any script that appends to
  `specs/events.jsonl`) directly and then reports that file as touched.
- **Decision (Outcome 2): consolidate into ONE canonical shared library**, modelled directly on
  the already-proven `scripts/lib/derived-artifact-probe-lib.sh` pattern (a sourced function
  returning a JSON array, consumed identically by multiple sites). This is the third hand-copy of
  the same two-literal pair; a fourth infrastructure path must cost one edit, not three.
- **List membership (Outcome 2): `specs/TODO.md`, `specs/state.json`, `specs/events.jsonl`,
  `specs/errors.json`.** The first two are already admitted; `specs/errors.json` meets the same
  "engine-written on behalf of every/many tasks, never declarable in any task's own file_scope"
  bar via `errors-append.sh`, and the repo's own `.gitignore` comment explicitly pairs it with
  `events.jsonl` as a deliberately-tracked durable store. No other `specs/*` top-level file
  (`CHANGE_LOG.md`, `ROADMAP.md`, `README.md`) meets the bar — see Decisions for the per-file
  rejection reasoning.
- Recommended fix shape: a new `scripts/lib/engine-written-state-paths-lib.sh` exporting
  `engine_written_state_paths` (prints the 4-entry JSON array, no repo-declaration lookup
  needed — these are fixed literals, not a `.claude-extensions.json`-declared set like the
  derived-output probes); sourced by all three sites, replacing each site's own hand-copied
  literal splice. Site 2 (`git-commit-phase.sh`) needs a **new** splice into its tested
  `file_scope_arr` (it currently has none), not a widening of its untested fixed set.

## Context & Scope

Task #467 (archived, type `meta`) recorded a `scope excursion` issue at task-creation time:
`git-commit-scoped.sh dropped 'specs/events.jsonl' from a commit pathspec: not contained in task
#467's declared file_scope`. `specs/events.jsonl` is a tracked, non-gitignored, 7000+-line
append-only event store every task's lifecycle writes to via `scripts/events-append.sh`
(invoked from `skill-base.sh`'s `_events_append_observable` wrapper at preflight/
context_injection/postflight stages, and directly by `run-task-observers.sh`,
`system-defect-record.sh`, `command-gate-out.sh`). It is infrastructure, never a task's own
territory, so no task's declared `file_scope` will ever legitimately contain it — yet it is
currently dropped by all three Containment sites whenever it reaches their pathspec, each
producing identical symptoms once admitted (`EXCURSION DROPPED` at Site 1, a per-site
`issue-record.sh --class "scope excursion"` call at Sites 2/3).

This research traces: (1) the exact current state of each Containment site's allowlist; (2) the
real end-to-end path by which `specs/events.jsonl` reached a commit pathspec for task #467
specifically, to the extent it is mechanically reconstructible; (3) what the canonical shared
definition should contain and how it should be structured; (4) what the standard doc and the
test suites need updated/added.

## Findings

### Codebase Patterns

**Site 1 — `orchestrate-cycle-postflight.sh` WORK (h)/(i).** WORK (h) (lines ~1619-1680) builds
`effective_file_scope_json` by splicing, in order: the task's own declared `file_scope`, the
task's own directory (`task_dir_rel`), every repo-declared derived-output prefix (via
`derived_probe_output_prefixes`, sourced from `lib/derived-artifact-probe-lib.sh`), and finally
the literal `["specs/TODO.md", "specs/state.json"]` at line 1670. It then classifies every
`modified_files` entry not covered by this set into `excursions_json` — **advisory only, never
blocking, never affecting exit code or verdict** (confirmed by
`test-orchestrate-cycle-postflight.sh`'s existing invariant test at ~line 1503-1562, which proves
a genuinely out-of-scope path is logged via an `ADVISORY` line and still committed... wait, that
invariant actually proves the opposite for WORK (h)'s advisory vs. WORK (i)'s drop — see below).
WORK (i) (lines ~1909-1945) then re-walks `modified_files_json` and **drops** (not just
advises) any entry present in `excursions_json`, logging `EXCURSION DROPPED` and never adding it
to `stage_paths` — this is the actual staging-time enforcement, layered on top of WORK (h)'s
detection.

**Site 2 — `git-commit-phase.sh`'s Phase-Commit Containment Self-Check** (lines ~196-282).
`stage_paths` starts as the **fixed, never-tested** set `("${task_dir}/" "specs/TODO.md"
"specs/state.json" [plan_path])`. Only the SEPARATE `files_touched` array (derived from the
dispatch's own progress file) is run through `is_contained()` against the task's raw
`file_scope_arr` — which, unlike Sites 1 and 3, is **not** spliced with the two engine-written
literals at all, because those two never need to pass through this test (they are already
unconditionally in the fixed set). This means Site 2 currently has **zero** engine-written-state
allowlist of its own; it has simply never needed one, because `files_touched` populated from a
progress file is not where `specs/TODO.md`/`specs/state.json` would ever appear. If
`specs/events.jsonl` (or `specs/errors.json`) ever appears in a `files_touched` entry, Site 2
*would* drop it today, with its own distinct message (`"git-commit-phase.sh dropped '...' from a
phase commit pathspec..."`, not the V10 wording) — the dispatch's citation does not match this
message, so Site 2 was not the historical trigger for task #467, but it is an equally real,
currently-unguarded hole for the same class of path and must be closed for Outcome 1 to be true
at all three sites.

**Site 3 — V10 inside `git-commit-scoped.sh`** (lines ~463-520 build `containment_scope_arr`;
line 499 is the literal splice; the `is_contained_v10` drop fires at lines ~635-658, including
the exact `issue-record.sh --what-happened "git-commit-scoped.sh dropped '${p}' from a commit
pathspec: not contained in task #${contention_task_number}'s declared file_scope."` call that
matches task #467's recorded issue verbatim). This check is **opt-in on `--task`** and
independently re-derives `file_scope` from `specs/state.json` rather than trusting anything the
caller passed in — it does not know about or reuse WORK (h)'s `excursions_json` at all.

### External Resources

Not applicable — this is a pure in-repo mechanism; no external documentation informs the fix.

### Reconstructing the end-to-end path for task #467

The recorded issue (`iss_1793767328647_oTTy6O`, `phase: null`, `dispatch_seq: null`, timestamp
`2026-11-04T04:42:08Z`) carries **no `--phase`/`--dispatch-seq`** — this is diagnostic: Site 2's
own `issue-record.sh` call passes `--phase implement` unconditionally, and Site 1's WORK (i)
passes neither `--phase` nor `--dispatch-seq` to ITS OWN error-path `issue-record.sh` call either,
but Site 1's drop message text is `"EXCURSION DROPPED: ... not staged for this cycle's commit"`,
not the V10 wording actually recorded. Only Site 3's own internal call (inside
`git-commit-scoped.sh`, fired whenever `--task` is given and the resolved pathspec entry fails
`is_contained_v10`) emits exactly the recorded wording with no `--phase`/`--dispatch-seq` flags.
This match is exact and unambiguous: **the historical drop was Site 3 (V10), fired by some
`--task 467`-supplying caller whose pathspec named `specs/events.jsonl` directly.**

The timestamp (`04:42:08Z` = `2026-11-03 20:42:08 -0800`) is **identical to the second**
with the `"task 467: create orchestrate-first docs restructure and core docs audit records"`
commit (`6e044bc20`) — i.e. the task-CREATION commit, not any research/plan/implement dispatch.
`commands/task.md` Step 7 (the documented creation-commit template, also mirrored in
`skill-meta/SKILL.md`) passes `--task {N}` with a **fixed, two-entry** pathspec
(`specs/TODO.md specs/state.json`) — a template no script enforces verbatim, since these
`commands/*.md`/`SKILL.md` files are natural-language procedures an agent composes real bash
from at runtime, not literally interpreted scripts. The mechanical conclusion this research can
support directly: **no currently-documented, literal call-site pathspec contains
`specs/events.jsonl`,** consistent with the dispatch's own grep finding. The most likely real
mechanism is that the agent executing task #467's creation step had, in the same turn, already
caused a write to `specs/events.jsonl` (every lifecycle stage appends to it) and — reasonably,
since the file was genuinely dirty in the working tree at that moment — included it in the `--
<pathspec>` list it composed for the Step 7 commit, following the general instruction to commit
what it had touched. This is not a scripted defect at a single fixed call site; it is a
structural hazard inherent in `specs/events.jsonl` being tracked, frequently dirty, and
plausible for *any* `--task`-supplying caller (scripted or agent-composed) to name. **No
widening of a specific script's literal pathspec is needed or sufficient** — the fix belongs
entirely in the allowlist the Containment predicate checks against, exactly as Outcome 1 frames
it, not in finding and patching one specific staging call site.

This also means Outcome 3's own staging-side caution ("if the path reaches `git-commit-scoped.sh`
only via a `modified_files`-derived pathspec, the staging side must be fixed too") is answered:
**no staging-side fix is needed.** `specs/events.jsonl` already reaches `git-commit-scoped.sh`
today via at least one real path (the task-creation commit observed for #467); the defect is
purely that the Containment predicate rejects it once there, not that nothing stages it.

### Candidate list membership

| Path | Writer | Engine-written on behalf of every/many tasks? | Verdict |
|---|---|---|---|
| `specs/TODO.md` | `generate-todo.sh` / `update-task-status.sh` | Yes, every task | Already allowlisted |
| `specs/state.json` | `state-write.sh` / `update-task-status.sh` | Yes, every task | Already allowlisted |
| `specs/events.jsonl` | `events-append.sh` (called from `skill-base.sh`, `run-task-observers.sh`, `command-gate-out.sh`, `system-defect-record.sh`, etc.) | Yes, every dispatch's lifecycle stages | **Add** |
| `specs/errors.json` | `errors-append.sh` | Yes, error tracking across tasks; `.gitignore`'s own comment pairs it explicitly with `events.jsonl` as a "deliberately NOT ignored... durable store" | **Add** |
| `specs/CHANGE_LOG.md` | `skill-todo` archival | Only at archival time, not every task's lifecycle | Reject — fails the "every task" bar |
| `specs/ROADMAP.md` | User-maintained (per root `CLAUDE.md`) | No — explicitly read-only for agents | Reject |
| `specs/README.md` | Static, hand-authored | No | Reject |

## Recommendations

1. Create `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh`, structurally
   modelled on `lib/derived-artifact-probe-lib.sh`'s header/contract style (sourced, never
   executed, sets no shell options, fail-open posture documented), exporting one function —
   e.g. `engine_written_state_paths` — that prints the compact JSON array
   `["specs/TODO.md","specs/state.json","specs/events.jsonl","specs/errors.json"]`. No
   repo-declaration lookup is needed (unlike the derived-output probes, this set is a fixed
   constant of the core engine, not a per-repo `.claude-extensions.json` declaration), but a
   function (not a bare constant file) keeps the call-site shape identical to the existing
   `derived_probe_output_prefixes` precedent and leaves room for a future repo-level override
   without a second migration.
2. Replace `git-commit-scoped.sh:499`'s literal `containment_scope_arr+=("specs/TODO.md"
   "specs/state.json")` with a sourced call to `engine_written_state_paths`, appending every
   returned entry.
3. Replace `orchestrate-cycle-postflight.sh:1670`'s literal
   `jq -c '. + ["specs/TODO.md", "specs/state.json"]'` splice with the same sourced call (pass
   the JSON array to `jq --argjson`, mirroring the existing `derived_output_prefixes_json`
   splice immediately above it at line ~1657).
4. Add a **new** splice at `git-commit-phase.sh`'s Containment Self-Check (before `is_contained`
   is defined/used, ~line 229), appending `engine_written_state_paths`'s entries into
   `file_scope_arr` — this site currently has none, so this is a net-new allowlist, not a
   migration of an existing literal.
5. Update `context/standards/git-staging-scope.md`'s two named paragraphs per Outcome 4:
   - "Three Containment sites, not one." — add a sentence noting Site 2 now also carries the
     engine-written-state allowlist (previously true only of Sites 1 and 3).
   - "Site 1 carries its own engine-written-state allowlist." — rename/reword to reflect the
     canonical shared source (no site "carries its own" anything any more) and update the
     4-entry membership.
6. Test fixtures (Outcome 5), using the existing proven patterns as templates:
   - In `test-git-commit-scoped.sh`: extend the Z-series (`build_repo_with_scope`, used by
     Z1-Z18) with a case asserting `--task N -- specs/events.jsonl` (and `specs/errors.json`)
     commits cleanly with zero V10 drops, paired with an unchanged negative case (an arbitrary
     out-of-scope path like the existing Z6 pattern) proving drop-and-warn still fires for a
     genuine excursion.
   - In `test-orchestrate-cycle-postflight.sh`: extend the existing "excursion never changes
     exit code or verdict" test block (~lines 1503-1562, which already uses
     `completely/unrelated/excursion.sh` as its genuine-excursion fixture) with a sibling
     assertion: add `"specs/events.jsonl"` to the same dispatch's `modified_files`, confirm it is
     **not** reported as an `ADVISORY` excursion and **is** present in the resulting commit's
     file list, while `completely/unrelated/excursion.sh` is still dropped and still warned.
   - Add the matching case to `git-commit-phase.sh`'s own test suite (not named in the dispatch
     but structurally required by Outcome 1's "at any of the three Containment sites" — flag
     this as in-scope for the plan to confirm/schedule).
7. For Outcome 3's "verify by observing an actual commit that carries an events.jsonl delta":
   the implementation phase should, after landing the fix, perform one real end-to-end
   verification — e.g. dispatch a trivial task through the normal lifecycle (which
   unconditionally appends to `specs/events.jsonl` via existing preflight/postflight hooks),
   explicitly include `specs/events.jsonl` in that dispatch's `modified_files` or in a
   `git-commit-scoped.sh --task N` pathspec, and confirm via `git show --stat`/`git log -p` that
   the resulting commit's tree actually carries the `specs/events.jsonl` delta — not just that
   V10/WORK(h) no longer flag it.

## Decisions

- **One canonical shared library, not three hand-copied literals** (Outcome 2, first half).
  Rationale: this is documented as the third occurrence of the same two-literal splice pattern,
  and `lib/derived-artifact-probe-lib.sh` already proves the sourced-function-returning-JSON-array
  shape works cleanly across exactly these same call sites (`orchestrate-cycle-postflight.sh` and
  `git-commit-scoped.sh` both already source it for a sibling concept). A fourth infrastructure
  path should cost one line in one file, not a three-site edit.
- **List membership: `specs/TODO.md`, `specs/state.json`, `specs/events.jsonl`,
  `specs/errors.json` — nothing wider** (Outcome 2, second half). Each entry is justified
  individually against the existing code comment's own admission bar ("engine-written on behalf
  of every task, not merely 'these two paths'"); `CHANGE_LOG.md`/`ROADMAP.md`/`README.md` are
  explicitly rejected (see table above) to avoid weakening the excursion guard, per the dispatch's
  own caution.
- **No staging-side fix is needed** (Outcome 3). The reconstructed end-to-end path shows
  `specs/events.jsonl` already reaches a `--task`-supplying `git-commit-scoped.sh` invocation in
  production (task #467's creation commit); the defect is confined to the Containment
  allowlist, not to any caller failing to stage the path in the first place.
- **Site 2 needs a new splice, not a widened existing one.** `git-commit-phase.sh`'s Containment
  Self-Check has never carried an engine-written-state allowlist (its two fixed paths bypass the
  test entirely); closing Outcome 1 "at any of the three Containment sites" requires adding one
  net-new splice there, not migrating an existing literal as at Sites 1 and 3.

## Risks & Mitigations

- **Concurrent territory.** Per the dispatch's own note, open tasks #461 (declares
  `git-commit-scoped.sh`), #430/#446 (declare `git-commit-phase.sh`/`git-staging-scope.md`) touch
  the same files. No dependency edge exists; if any of these are batch-co-scheduled with #469,
  serialize rather than run as parallel siblings, per `context/contracts/territory.md`.
- **Over-widening the allowlist weakens the excursion guard.** Mitigated by the explicit
  per-candidate justification table above and by deliberately rejecting `CHANGE_LOG.md`/
  `ROADMAP.md`/`README.md` despite all three living under `specs/`.
- **Site 2's self-check is documented as "deliberately redundant, not load-bearing" relative to
  Site 3** (`git-staging-scope.md`'s existing "Site 3 therefore structurally subsumes site 2's
  own reach" paragraph). Adding Site 2's splice is still required by Outcome 1's literal wording
  ("at any of the three Containment sites") and keeps its own independent issue-log entry
  accurate; it is not redundant with Site 3 for a path that never reaches Site 3 (e.g. a
  phase-commit caller that drops it before V10 ever sees it).

## Context Extension Recommendations

- **Topic**: canonical engine-written-infrastructure-path allowlist.
- **Gap**: `context/standards/git-staging-scope.md` currently documents the allowlist as
  something "Site 1 carries", implying a per-site literal; once a shared library exists this
  framing is stale even for Sites 1 and 3, let alone the new Site 2 splice.
- **Recommendation**: the plan/implementation phase should fold the library's existence and its
  4-entry membership into `git-staging-scope.md`'s existing two named paragraphs directly
  (Recommendation 5 above), rather than leaving the standard describing the pre-fix hand-copied
  shape.

## Appendix

- Search queries / commands used: targeted `grep -n` over
  `git-commit-scoped.sh`/`orchestrate-cycle-postflight.sh`/`git-commit-phase.sh` for
  `specs/TODO.md`, `containment_scope_arr`, `effective_file_scope_json`, `issue-record`,
  `is_contained_v10`; `git log --oneline --all | grep "task 467"` and
  `git log -p --follow -- commands/task.md`; direct reads of
  `specs/archive/467_orchestrate_first_workflow_docs_restructure/issues.jsonl`,
  `.orchestrator-handoff.json`, and all six `progress/phase-N-progress.json` files; `.gitignore`
  for the `events.jsonl`/`errors.json` deliberate-tracking comment.
- Key files referenced: `agent-system/extensions/core/scripts/git-commit-scoped.sh` (V10: lines
  ~463-520, ~600-700, issue-record at ~654-658), `orchestrate-cycle-postflight.sh` (WORK (h):
  ~1619-1680; WORK (i): ~1909-1945), `git-commit-phase.sh` (fixed scope: ~196-198; self-check:
  ~229-282), `context/standards/git-staging-scope.md` (~342-390), `scripts/lib/
  derived-artifact-probe-lib.sh` (precedent pattern), `scripts/errors-append.sh`,
  `scripts/events-append.sh`, `commands/task.md` (Step 7), `skills/skill-meta/SKILL.md`.
