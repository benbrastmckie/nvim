# Research Report: Task #284

**Task**: 284 - Exempt the dispatching task's own task directory from the postflight
modified_files-vs-file_scope excursion advisory
**Started**: 2026-10-08T00:00:00Z
**Completed**: 2026-10-08T00:00:00Z
**Effort**: small-to-medium (one script header + one check block + test fixtures; no new script)
**Dependencies**: None
**Sources/Inputs**: Codebase (orchestrate-cycle-postflight.sh, task-lookup-lib.sh,
skill-orchestrate/SKILL.md, return-metadata-file.md, git-staging-scope.md,
file-scope-overlap.sh, test-orchestrate-cycle-postflight.sh), specs/state.json,
specs/archive/state.json (tasks 100, 165, 270)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The excursion predicate lives in ONE place —
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, WORK item (h), currently
  at lines 1419-1436 (the dispatch's cited 1121-1132 is stale; the file has grown since task 100
  shipped this block — line numbers are not a stable anchor and the plan should re-grep, not
  trust either number).
- The resolved task directory this check needs is **already available verbatim** as `$TASK_DIR`,
  which is already correctly archive-aware (set once, upstream, via
  `task_lookup_dir()` in `scripts/lib/task-lookup-lib.sh:93-108`, and threaded through the single
  shared call site in `skill-orchestrate/SKILL.md:187-189` used by both the single-task and
  multi-task engines). No new archive-detection logic is needed — the fix only has to derive a
  repo-relative string from `$TASK_DIR` and splice it into the comparison.
- Both `modified_files` and `file_scope` are contractually **repo-relative** paths
  (`return-metadata-file.md`'s "Path form" note; confirmed empirically against every `file_scope`
  array read from live `state.json`). `$TASK_DIR` is absolute internally; the natural, dependency-free
  conversion is `${TASK_DIR#"$PROJECT_ROOT"/}` using the `$PROJECT_ROOT` variable the script
  already sets at line 198.
- Git-staging parity strongly supports the dispatch's own preference for exempting the **whole**
  task directory rather than an enumerated artifact-subdirectory allowlist:
  `context/standards/git-staging-scope.md` already stages the entire task directory (minus a
  small, named ephemeral-exclude set) for every commit regardless of `file_scope`, and
  `return-metadata-file.md` states outright: *"Paths under the task directory are harmless if
  listed — the fixed task-directory scope already stages `specs/{NNN}_{SLUG}/` regardless."* The
  advisory should match that existing posture rather than inventing a narrower one.
- One real, pre-existing format inconsistency was found and is **load-bearing for the
  advisory-vs-blocking decision**: `specs/299_.../​.return-meta.json`'s `modified_files` array holds
  **absolute** paths (e.g. `/home/.../specs/TODO.md`), in direct violation of the schema's
  repo-relative-only contract, and `validate-return-meta.sh` does not check `modified_files`'
  path form at all. An absolute-path entry will not match a repo-relative `file_scope` entry OR
  the new implicit task-directory member via `startswith`, so it remains a live false-positive
  (or false-negative-exemption) source independent of this fix. This is why the report recommends
  staying advisory now (see Decisions).
- Recommended design: append the repo-relative `$TASK_DIR` string (with a trailing `/`, matching
  the existing test fixture's own convention) as one extra element of the in-check `$fs` array,
  immediately before building `excursions_json` — no change to the matching logic itself. The
  existing fixture (`test-orchestrate-cycle-postflight.sh:1156-1189`, task `707_candidate`) already
  proves the `$p == $f or ($p | startswith($f))` predicate correctly treats a trailing-slash
  `file_scope` entry as a directory prefix, so this is a pure data-set change, not an algorithm
  change.

## Context & Scope

Scope is narrow and explicit per the dispatch: make the detection-only excursion advisory in
`orchestrate-cycle-postflight.sh`'s WORK (h) stop firing unconditionally on a task's own required
artifacts, by treating the dispatching task's own task directory as an implicit, unconditional
member of its `file_scope` for the duration of that one check. The dispatch separately asks for
(1) a repointed or restated cross-reference in task 270's recorded text, and (2) an explicit,
recorded (not silently skipped) ruling on whether the channel should stay advisory or be promoted
to a blocking gate — with an explicit instruction NOT to promote in this same change.

Out of scope, by the dispatch's own boundary and by this research: any null-safety fix inside
lines ~1419-1436 (owned by task 270, which audits a *different* defect class in the same file and
explicitly declines to touch this block unless its own audit finds a null-safety bug there); the
general `modified_files` absolute-vs-relative path inconsistency found below (a separate,
unaddressed schema-conformance gap, noted only because it bears on the advisory-vs-blocking
decision); and any refactor of the inline `startswith` predicate to reuse the canonical
`scripts/lib/file-scope-overlap.sh` directory-overlap library (noted as an optional, non-required
cleanup opportunity only).

## Findings

### Codebase Patterns

**Site and current code** (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
current lines 1419-1436):

```bash
# ─── WORK (h): modified_files vs file_scope excursion advisory (detection only) ────────────────
meta_file="${TASK_DIR}/.return-meta.json"
modified_files_json=$(jq -c '.modified_files // []' "$meta_file" 2>/dev/null) || modified_files_json='[]'
file_scope_json=$(jq -c --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .file_scope // []' "$STATE_FILE" 2>/dev/null) || file_scope_json='[]'
excursions_json='[]'
if [ "$(echo "$file_scope_json" | jq 'length')" -gt 0 ] 2>/dev/null; then
  excursions_json=$(jq -c -n --argjson mf "$modified_files_json" --argjson fs "$file_scope_json" \
    '[$mf[] | select(. as $p | any($fs[]; . as $f | $p == $f or ($p | startswith($f))) | not)]' 2>/dev/null) || excursions_json='[]'
  excursion_count=$(echo "$excursions_json" | jq 'length' 2>/dev/null) || excursion_count=0
  if [ "$excursion_count" -gt 0 ]; then
    echo "${notice_prefix} ADVISORY: task ${task_number} reported modified_files outside its declared file_scope: $(echo "$excursions_json" | jq -c '.')  (detection only — no gate, no exit-code, no verdict effect)." >&2
  fi
fi
```

The check only runs at all when `file_scope` is non-empty (`length > 0` guard) — a task with no
declared scope never produces this advisory today, consistent with task 165's separate, completed
ruling that an absent `file_scope` is a different problem handled elsewhere (admission posture,
not this advisory).

**`$TASK_DIR` is already the right anchor and already archive-aware.** The script normalizes its
`--task-dir` argument to an absolute path at lines 338-339 (`TASK_DIR="$PROJECT_ROOT/$task_dir_arg"`
when given relative). The value it receives is produced once, upstream, by
`task_lookup_dir()` (`scripts/lib/task-lookup-lib.sh:88-108`):

```bash
task_lookup_dir() {
  local project_number="$1" project_name="$2" repo_root="$3"
  local padded active_rel archive_rel
  padded=$(printf "%03d" "$project_number")
  active_rel="specs/${padded}_${project_name}"
  archive_rel="specs/archive/${padded}_${project_name}"
  if [ -d "${repo_root}/${active_rel}" ]; then printf '%s\n' "$active_rel"
  elif [ -d "${repo_root}/${archive_rel}" ]; then printf '%s\n' "$archive_rel"
  else printf '%s\n' "$active_rel"
  fi
}
```

— which is exactly the "resolve from the task directory the dispatch actually used, not the
active path" behavior the dispatch asks for. It is consumed via the single shared call site in
`skill-orchestrate/SKILL.md:181-189` (`task_dir_rel=$(jq -r --arg t "$t" '.task_dirs[$t]'
"$mt_state_file")`, itself populated at `orchestrate-cycle-plan.sh:2316-2322` from this same
`task_lookup_dir()` call). Both the single-task and multi-task engines pass through this one
`--task-dir` value into `orchestrate-cycle-postflight.sh` — the script's own header already notes
it performs "the WHOLE postflight body once, so both engines are structurally incapable of
disagreeing." **No new archive/active branching is needed in the fix; reading `$TASK_DIR` (already
resolved) is sufficient.**

**Path-form contract.** `context/formats/return-metadata-file.md`'s `modified_files` section is
explicit: *"Path form: entries are repo-relative paths, relative to the repository root. This is
load-bearing... Absolute paths are not permitted."* The same document and every `file_scope` array
actually read from `specs/state.json` (tasks 299, 272, 303, 165 all checked) are consistently
repo-relative. `$TASK_DIR` must therefore be converted to repo-relative form before comparison;
`$PROJECT_ROOT` (set at line 198 via `common_repo_root`) is already in scope for a simple
`${TASK_DIR#"$PROJECT_ROOT"/}` parameter expansion — no new helper or dependency required.

**Git-staging parity (the strongest argument for exempting the whole directory, not a
subdirectory allowlist).** `context/standards/git-staging-scope.md:13-29` already stages the
*entire* task directory for every operation's commit, carving out only five named ephemeral
runtime paths by exclusion pathspec (`.orchestrator-loop-guard`, `.orchestrator-churn-state.json`,
`.drift-inspection.json`, `.lock/`, `.dispatch/`) — not an allowlist of `reports/`/`plans/`/etc.
`return-metadata-file.md`'s own `modified_files` section states this in so many words: *"Paths
under the task directory are harmless if listed — the fixed task-directory scope already stages
`specs/{NNN}_{SLUG}/` regardless."* The advisory channel currently disagrees with the commit
pipeline's own posture (treating a within-task-directory path as noteworthy when the committer
already treats it as unconditionally in-scope). Exempting the whole directory brings the two into
agreement and matches the dispatch's own stated default ("prefer the whole directory unless there
is a concrete reason..."); this research found no such concrete reason — the staging parity is, if
anything, a concrete reason *for* whole-directory exemption.

**Existing test fixture already validates the matching mechanics for a trailing-slash directory
entry.** `scripts/tests/test-orchestrate-cycle-postflight.sh:1156-1189` ("Invariant: the excursion
advisory never changes exit code or verdict") declares `file_scope:
["specs/707_candidate/"]` for its fixture task and reports `modified_files` containing both
`specs/707_candidate/summaries/01_x-summary.md` (matches, no advisory) and
`completely/unrelated/excursion.sh` (does not match, advisory fires, and the test asserts it does).
This proves `$p == $f or ($p | startswith($f))` already correctly implements "is this path inside
this directory" for a trailing-slash entry — **the fix is a one-line addition to the `$fs` array
construction, not a predicate rewrite**, and this specific test's genuine-excursion case
(`completely/unrelated/excursion.sh`) remains correctly flagged after the fix (it is outside both
the declared scope and the task's own directory).

**Reusable directory-overlap library exists but is not used here.**
`scripts/lib/file-scope-overlap.sh` (consumed by `task-lock.sh` and
`orchestrate-batch-admit.sh`) is the codebase's canonical, single-source-of-truth directory-prefix
predicate (`norm`/`scopes_overlap_first` jq defs, with explicit glob-entry and path-normalization
handling per `context/patterns/file-footprint-overlap.md`). The excursion check instead
reimplements a simpler inline `startswith` test. Swapping to the canonical library is **not**
required by this task's scope (the dispatch asks only for an implicit-scope-member addition) and
is noted here only as an optional future cleanup, not a recommendation to act on now.

**Two counter-examples that bear directly on the advisory-vs-blocking decision**:

1. `specs/299_detect_plan_revision_during_implement/.return-meta.json`'s `modified_files` holds
   `["/home/benjamin/.config/nvim/specs/TODO.md","/home/benjamin/.config/nvim/specs/state.json"]`
   — **absolute** paths, in direct violation of the documented repo-relative-only contract.
   `grep -n "modified_files" agent-system/extensions/core/scripts/validate-return-meta.sh` returns
   nothing: there is no schema check on `modified_files`' path form today. An absolute-path entry
   will not `startswith`-match either a repo-relative `file_scope` entry or the new implicit
   repo-relative task-directory member, so a task that reports this way could still show a false
   excursion (or fail to show a true exemption) after this fix ships. This is a live,
   **unaddressed** source of predicate unreliability, independent of the one this task fixes.
2. The dispatch's cited live defect names `modified_files` firing on `research` and `plan`
   postflight with the phase's own report/plan path. `return-metadata-file.md`'s `modified_files`
   section states this field is *"Unused and absent for `research` and `plan` operations"* — and
   this is true in the current `.return-meta.json` corpus: four live `researched`-status tasks
   checked (273, 275, 363, 368) all show `modified_files: null` (absent). The exact symptom as
   described may therefore reflect an earlier state of this repository or of the research/plan
   agent contracts (the observation is dated 2026-09-30, in a *different* repository,
   `~/Projects/Logos/Verification`) rather than something currently reproducible verbatim via
   `modified_files` on this script's research/plan path. The underlying mechanism the dispatch is
   fixing is real and *is* independently demonstrated today on the **implement** phase (the
   `707_candidate` fixture above shows a task's own summary file legitimately appearing in
   `modified_files`). Because the excursion block runs unconditionally across all three phases
   (it is not gated on `dispatch_status`), and because the task's stated ACCEPTANCE criterion
   explicitly spans "research, plan and implement," the fix should be written phase-agnostically
   regardless of which phase currently happens to populate `modified_files` — this is both
   correctness and the literal acceptance wording, not an assumption to relax.

### External Resources

Not applicable — this is a purely internal shell/jq script change; no external library or
documentation research was needed.

## Recommendations

1. **Implicit scope member, computed once per invocation.** Immediately before WORK (h)'s existing
   `file_scope_json` read (or right after it), compute
   `task_dir_rel="${TASK_DIR#"$PROJECT_ROOT"/}"` (using the script's existing `$PROJECT_ROOT`) and
   splice `"${task_dir_rel}/"` into the `$fs` array the jq comprehension consumes — e.g. by
   building `file_scope_json` as `file_scope_json | jq --arg d "${task_dir_rel}/" '. + [$d]'`), so
   the existing `$p == $f or ($p | startswith($f))` predicate picks it up with zero changes to the
   matching logic. Keep the trailing slash, matching the `707_candidate` fixture's own convention,
   to avoid any (currently-impossible-by-padding, but cheap-to-avoid) string-prefix collision
   between differently-numbered task directories.
2. **Guard ordering**: ensure the implicit member is added even when the task's own declared
   `file_scope` is empty only if the check is also made to run unconditionally for that case —
   today the `length > 0` guard skips the whole block for an empty `file_scope`, and a task with
   zero declared scope already produces no advisory. Decide explicitly (and record) whether the
   implicit member should cause the check to now run even for an empty-`file_scope` task (closing
   a second blind spot) or whether that is deliberately left to task 165's existing,
   separately-ruled absent-`file_scope` posture. This research recommends **leaving the
   `length > 0` guard as-is** (do not widen trigger conditions) — task 165 already rules on
   absent-`file_scope` admission posture elsewhere, and widening this unrelated advisory's trigger
   condition in the same change risks scope creep the dispatch did not ask for.
3. **Whole task directory, not a subdirectory allowlist** — per the Findings' git-staging-parity
   argument. Record this choice and its one-sentence justification (parity with
   `git-staging-scope.md`'s existing whole-directory staging) in the script header next to the
   existing WORK (h) line, per the dispatch's explicit requirement that the ruling live there.
4. **Repoint task 270's dangling cross-reference.** Task 270
   (`jq_null_safety_audit_core_mutation_sites`) is itself terminal (`status: abandoned`, zero
   artifacts — confirmed via `specs/archive/state.json`'s `completed_projects` array, entry
   `project_number: 270`), so its own "RELATED, DELIBERATELY NOT MERGED" paragraph exists only as
   that archived entry's `description` string. The implementation phase should edit that string in
   `specs/archive/state.json` (a `specs/**` edit; task-number references are explicitly permitted
   there per `rules/no-task-references-in-deliverables.md`'s Exceptions list) to replace *"...and it
   was recorded separately"* with a pointer naming this task's resolution instead of the now-dead
   pointer to abandoned task 100. This is metadata housekeeping, not a code change, and carries no
   file_scope or shellcheck implications.
5. **Script-header documentation** (binding per dispatch ACCEPTANCE): add, alongside the existing
   WORK (h) line and the inline comment block at the check site, the implicit-scope-member
   behavior (item 1 above), the whole-directory ruling (item 3), and the Decision below on
   enforcement level — all co-located, matching the precedent task 165 set
   (`plan-format.md:328-336`'s advisory-first / promotion-criterion phrasing, transcribed almost
   verbatim there from the same pattern).
6. **Tests**: extend `test-orchestrate-cycle-postflight.sh` with (a) a fixture mirroring
   `707_candidate` but where `file_scope` does **not** include the task's own directory and
   `modified_files` includes only the task's own in-directory artifact path — asserting **zero**
   advisory after the fix (this is the regression test for the defect itself); (b) keep
   `707_candidate`'s existing out-of-directory `completely/unrelated/excursion.sh` case passing
   unchanged (the genuine-excursion demonstration case the ACCEPTANCE criterion requires); (c) a
   forced-dispatch-against-an-archived-task fixture (task directory under `specs/archive/...`)
   confirming the implicit member resolves from the archive path, not the active one.
7. Do **not** attempt to fix the `modified_files` absolute-path or validator gap found above in
   this change — it is a separate, already-named defect class (schema/validator coverage), and
   fixing it here would widen scope beyond the dispatch's narrow ask. Carry it forward only as
   input to the Decision below.

## Decisions

- **Scope of the implicit exemption**: the whole resolved task directory (`$TASK_DIR`, converted
  to its repo-relative form), not an enumerated allowlist of `reports/`, `plans/`, `summaries/`,
  `.dispatch/`, `.return-meta.json`, `.orchestrator-handoff.json`, `.decisions.json`. Justification:
  parity with `git-staging-scope.md`'s existing whole-directory (minus five named ephemeral
  exclusions) staging posture, and `return-metadata-file.md`'s own statement that
  within-task-directory paths are "harmless if listed" for staging purposes — the advisory should
  not be stricter than the commit pipeline it is advising about.
- **Enforcement level: stay advisory in this change; record the promotion criterion rather than
  defer the question.** The dispatch explicitly forbids promoting to blocking in the same change,
  and this research independently confirms that would be premature: a live, currently-unvalidated
  source of predicate unreliability exists today (the `specs/299_.../.return-meta.json` absolute-path
  counter-example above) with no schema check (`validate-return-meta.sh` does not inspect
  `modified_files`' path form). Blocking on a predicate with a known, unaddressed false-positive/
  false-exemption source would risk blocking correct work, which is exactly what the dispatch
  warns against. **Promotion criterion to record in the script header**: promote the advisory to a
  blocking gate once (a) this own-task-directory exemption has run with the current repository's
  active, non-abandoned task population — currently 45/47 (~96%) of which already carry a
  non-empty `file_scope`, matching the coverage level task 165 itself used as its own promotion
  evidence — for a bake-in period with zero recorded false-positive advisories, AND (b) a
  `validate-return-meta.sh` check (or equivalent) enforces that every `modified_files` entry is
  repo-relative, closing the counter-example found above. Until both hold, an excursion gate would
  sit on a predicate that can misfire for reasons unrelated to the genuine aggregator-edit signal
  it exists to catch.
- **Task 270 cross-reference repair**: restate the status at task 270's own (archived) description
  rather than leaving the dangling "recorded separately" pointer at abandoned task 100. Task 270
  remains out of scope for any code change in this task (its boundary note — "touching the same
  file is not a reason to bundle it" — still holds for the script itself; only the metadata text
  is touched).

## Risks & Mitigations

- **Risk**: the implicit member's repo-relative conversion (`${TASK_DIR#"$PROJECT_ROOT"/}`)
  silently produces a wrong string if `$TASK_DIR` does not actually begin with `$PROJECT_ROOT/`
  (e.g., a symlinked path, or a caller passing an already-divergent absolute path). *Mitigation*:
  this is the same assumption the script already relies on throughout (its own `--task-dir`
  normalization at lines 338-339 constructs `$TASK_DIR` from `$PROJECT_ROOT` precisely this way),
  so no new assumption is introduced; add a defensive fallback (log a WARN and skip the implicit
  member, never abort) if the stripped prefix is unchanged from the original, consistent with this
  script's existing "detection only, never fatal" posture for this whole WORK item.
- **Risk**: a future `modified_files` producer that reports absolute paths (as task 299 already
  does today) will not benefit from either the existing `file_scope` match or the new implicit
  exemption, producing a false excursion for its own in-directory artifacts. *Mitigation*: named
  explicitly in Decisions as the first half of the promotion criterion; not fixed by this task;
  the fix proposed here does not make this risk worse (it is already live and unaddressed today).
- **Risk**: widening the implicit exemption to run even when `file_scope` is empty (not
  recommended above) could interact unpredictably with task 165's separate absent-`file_scope`
  admission-posture ruling. *Mitigation*: explicitly recommended against in Recommendation 2;
  leave the existing `length > 0` guard untouched.

## Context Extension Recommendations

- **Topic**: the `modified_files` absolute-vs-relative path inconsistency (the task 299
  counter-example) and the absent `validate-return-meta.sh` coverage for it.
  **Gap**: no context file or lint currently documents or catches this; it was found only by
  direct inspection of a live `.return-meta.json`.
  **Recommendation**: a future task (not this one) should add a `modified_files` path-form check
  to `validate-return-meta.sh`, and that task is also the natural trigger point named in this
  report's promotion criterion above.

## Appendix

Searches/greps performed: `grep -n "excursion" agent-system/` (confirmed single live call site
plus two doc/test references); `grep -n "task_dirs\[" skill-orchestrate/SKILL.md`; `grep -n
"task_lookup_dir" -A 25 task-lookup-lib.sh`; `jq` queries against `specs/state.json` (file_scope
coverage: 45/47 active non-abandoned tasks, ~96%) and `specs/archive/state.json` (tasks 100, 165,
270 full description/status/artifacts); direct inspection of `.return-meta.json` for tasks
299, 272, 303 (modified_files path form) and 273, 275, 363, 368 (confirming `modified_files` is
absent on `researched`-status tasks today); `git log --oneline -- orchestrate-cycle-postflight.sh`
filtered for prior excursion/modified_files-related commits (task 143 introduced the excursion
block; task 252 touched unrelated `cycle_modified_files` loop-guard accumulation, not this check).

References: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (lines
1-120 header, 1419-1436 WORK (h)); `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`
(lines 36-108); `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (lines 160-220);
`agent-system/extensions/core/context/formats/return-metadata-file.md` (lines 420-500);
`agent-system/extensions/core/context/standards/git-staging-scope.md` (lines 1-40);
`agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (lines 1-40);
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (lines
1156-1208); `agent-system/extensions/core/context/formats/plan-format.md` (lines 320-336, the
advisory-first/promotion-criterion precedent).
