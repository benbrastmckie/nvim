# Research Report: Task #425

**Task**: 425 - State files dropped as file_scope excursions
**Started**: 2026-10-17T00:00:00Z
**Completed**: 2026-10-17T00:00:00Z
**Effort**: small (one ~6-line `jq`-array splice plus two-to-three new fixture cases)
**Dependencies**: None (task 440 independently researched and confirmed task 425 is a disjoint,
non-overlapping defect — different site, different language, different bug class; see Decisions)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (WORK (h)/(i)),
  `agent-system/extensions/core/scripts/git-commit-scoped.sh` (V10 containment guard),
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Live git history: `git log -S`/`git show --stat`/`git show <rev>:<path>` against task 170's own
  commits and `.return-meta.json` snapshots, and task 394's V10-landing commit
- `specs/440_fix_file_scope_glob_containment_predicate/reports/01_glob-containment-predicate-fix.md`
  (sibling task's own research, which independently confirms non-overlap with this task)
**Artifacts**:
- This report: `specs/425_state_files_dropped_as_file_scope_excursions/reports/01_state-files-excursion-predicate.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's root-cause location is confirmed exactly: `orchestrate-cycle-postflight.sh`'s
  WORK (h) excursion predicate (`effective_file_scope_json` / `excursions_json`, built around
  line 1599) has no allowlist for the two engine-written state files, so when a task's
  `.return-meta.json` reports `specs/TODO.md` and `specs/state.json` in its own `modified_files`
  array — which it routinely does in production (confirmed from task 170's own historical
  `.return-meta.json` snapshot) — both paths are classified as excursions.
- **Refinement to the dispatch's hypothesis, verified by direct code trace and by git
  archaeology against the cited live incident**: in the single-task commit path (WORK (i)), the
  two files are **not actually dropped from the commit**. `stage_paths` unconditionally
  prepends `specs/TODO.md` and `$STATE_FILE` (line ~1843, present since task 143, long before
  this defect's window) *before* the per-entry excursion loop runs; the loop's `continue` on a
  classified excursion only skips a *second*, redundant append — it never removes the two paths
  already queued. Checking out task 170's actual cycle-1 commit (`0a64d476e`, 2026-10-16
  06:26:25) confirms both `specs/TODO.md` and `specs/state.json` landed in that commit's diff,
  even though that same cycle's `.return-meta.json` (checked out at that revision) explicitly
  listed both paths in `modified_files` and the task's declared `file_scope` does not cover
  either — i.e. the "EXCURSION DROPPED" warning *did* fire for both files that cycle, but the
  files were committed anyway.
- **What the defect actually causes, confirmed**: a **false, misleading diagnostic** — the
  `EXCURSION DROPPED` stderr line (`orchestrate-cycle-postflight.sh:1861`) and the WORK (h)
  `ADVISORY` line (line 1603) both fire for `specs/TODO.md`/`specs/state.json` even though
  those files are, in fact, staged and committed via the separate unconditional carve-out. This
  inflates `excursion_dropped_count`'s stderr summary (line 1872) with two false positives on
  every cycle whose task declares a non-empty `file_scope`, and is exactly the noise the
  dispatch's Conclusion-stage channel (b) observed firing four times in one batch and used to
  spawn this task.
- **A real, separate latent-risk finding**: today's "no actual loss" guarantee rests entirely on
  the unconditional `stage_paths` carve-out at line 1843 — a different code path than the
  excursion predicate, with no comment documenting that it is deliberately covering for the
  predicate's own blind spot. No existing test exercises the realistic case (modified_files
  explicitly naming these two paths); a future edit that "simplifies" the carve-out away (it
  looks redundant once an allowlist exists) would silently reintroduce genuine data loss with
  nothing to catch it.
- `git-commit-scoped.sh`'s own V10 containment guard already carries the exact allowlist this
  task's predicate is missing (`containment_scope_arr+=("specs/TODO.md" "specs/state.json")`,
  landed whole-cloth in task 394's commit `727a374a5`) — direct, working precedent for the fix
  shape, at a sibling site `git-staging-scope.md` explicitly documents as NOT subsuming this
  one ("Site 1 is NOT subsumed by site 3: a postflight `modified_files` entry can be dropped by
  the postflight-sited filter BEFORE it is ever handed to `git-commit-scoped.sh` at all").

## Context & Scope

Scope is exactly the dispatch's: give the WORK (h)/(i) containment predicate in
`orchestrate-cycle-postflight.sh` an allowlist for the engine-written shared state files
(`specs/TODO.md`, `specs/state.json`) so they stop being flagged as excursions, while leaving the
predicate's drop-and-warn behavior fully intact for every other, genuine out-of-scope path. This
report also verifies (per the dispatch's own instruction, mirrored by task 440's parallel check)
that this defect is independent of the sibling glob-containment bug fixed in task 440.

Out of scope, noted but not pursued: the deeper question of whether `specs/TODO.md`/`state.json`
contention across *concurrent* tasks in the same batch (the V5 contended-path refusal in
`git-commit-scoped.sh`, unrelated to file_scope containment) could independently leave these
files dirty on disk in some other run — this is a different failure class (lock contention, not
excursion misclassification) and is not what this task's dispatch, or task 440's non-overlap
check, describes.

## Findings

### Codebase Patterns

**WORK (h) — the excursion classification** (`orchestrate-cycle-postflight.sh:1554-1606`):

```bash
meta_file="${TASK_DIR}/.return-meta.json"
modified_files_json=$(jq -c '.modified_files // []' "$meta_file" ...)
file_scope_json=$(jq -c --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .file_scope // []' "$STATE_FILE" ...)
...
if [ "$(echo "$file_scope_json" | jq 'length')" -gt 0 ] 2>/dev/null; then
  effective_file_scope_json="$file_scope_json"
  # (1) implicit own-task-directory splice
  # (2) derived-output-prefix splice (derived_probe_output_prefixes)
  excursions_json=$(jq -c -n --argjson mf "$modified_files_json" --argjson fs "$effective_file_scope_json" \
    '[$mf[] | select(. as $p | any($fs[]; . as $f | $p == $f or ($p | startswith($f))) | not)]' ...)
  ...
  if [ "$excursion_count" -gt 0 ]; then
    echo "... ADVISORY: task ${task_number} reported modified_files outside its declared file_scope: ..."
  fi
fi
```

`effective_file_scope_json` already widens the task's own declared `file_scope` with two
existing splices before the `startswith` comparison: the task's own directory (implicit member)
and any repo-declared derived-output prefixes (`derived_probe_output_prefixes`). There is no
third splice for the two fixed engine-written literals. The check is gated on
`file_scope_json` being non-empty — a task that declares no `file_scope` at all never triggers
this advisory (matches the existing "fail-open" test's framing), so the defect only manifests for
tasks that *do* declare a non-empty `file_scope`, which is the common case for implementation
tasks (confirmed: task 170 declares a 19-entry `file_scope`).

**WORK (i) — the per-cycle commit staging** (`orchestrate-cycle-postflight.sh:1841-1867`):

```bash
stage_paths=("${TASK_DIR}/" "$(dirname "$STATE_FILE")/TODO.md" "$STATE_FILE")
[ -n "${plan_path:-}" ] && [ "$phase" = "implement" ] && stage_paths+=("$plan_path")
...
while IFS= read -r f; do
  if [ -n "$f" ]; then
    modified_count=$((modified_count + 1))
    if jq -e --arg p "$f" 'any(.[]; . == $p)' <<<"$excursions_json" >/dev/null 2>&1; then
      excursion_dropped_count=$((excursion_dropped_count + 1))
      echo "... EXCURSION DROPPED: '${f}' is outside task ${task_number}'s declared file_scope — not staged for this cycle's commit ..." >&2
      continue
    fi
    stage_paths+=("$f")
  fi
done < <(jq -r '.[]? // empty' <<<"$modified_files_json")
```

`stage_paths` is seeded with `specs/TODO.md` and `$STATE_FILE` **unconditionally, before this
loop runs** (git-blamed to task 143, `d8d276556`, 2026-09-03 — six weeks before task 170's run
and task 394's V10 fix). When the loop later encounters `specs/TODO.md`/`specs/state.json` in
`modified_files_json` and finds them in `excursions_json` (because WORK (h) has no allowlist),
it prints the `EXCURSION DROPPED` line and `continue`s — skipping only a *second*, redundant
`stage_paths+=("$f")` for a path the array already contains. The files still reach
`git-commit-scoped.sh`'s `-- "${stage_paths[@]}"` call and are staged/committed normally.

**Empirical confirmation against the cited live incident** (task 170, cycle 1,
commit `0a64d476e`, 2026-10-16 06:26:25 — six weeks after the carve-out landed, and
*before* task 394's V10 fix (`727a374a5`, same day, 22:06:09) existed at all, so
`git-commit-scoped.sh` performed **no** containment filtering of its own at the time):

```
$ git show <rev>:<task-dir>/.return-meta.json | jq -c '.modified_files'
[...,"specs/TODO.md","specs/state.json"]
$ git show --stat <rev> | grep -i 'TODO.md\|state.json'
 specs/TODO.md   | 1 +
 specs/state.json| 8 +++++-
```

Both files were explicitly reported in `modified_files`, both would have matched `startswith`
against task 170's declared `file_scope` as excursions (triggering the warning), and both landed
in that same commit's diff. This directly confirms the "misleading diagnostic, not actual loss"
characterization for the single-task commit path, for the exact task and cycle the dispatch
cites as its "Confirmed live" evidence.

**Existing test coverage gap, confirmed by reading the suite directly.** Two existing blocks in
`test-orchestrate-cycle-postflight.sh` already pin that `specs/TODO.md`/`specs/state.json` are
committed via the unconditional carve-out — but neither ever places these two paths *inside*
`modified_files`, which is the one condition that actually triggers the `EXCURSION DROPPED`/
`ADVISORY` false positives:
- `"specs/ carve-out: TASK_DIR, TODO.md, state.json and the plan path are committed..."`
  (~line 1313): asserts both are committed when `file_scope` names neither — but that fixture's
  `.return-meta.json` lists only `["specs/713_candidate/summaries/01_x-summary.md"]` in
  `modified_files`, so `excursions_json` never contains either literal and no warning is
  exercised either way.
- `"Invariant: modified_files-vs-file_scope excursion never changes exit code or verdict"`
  (~line 1203) and `"Case (b): a genuinely undeclared file outside both scope and own
  directory..."` (~line 3249): both exercise a genuine, arbitrary excursion path (e.g.
  `completely/unrelated/excursion.sh`) and assert it IS dropped from the commit and left dirty —
  this is the correct, must-stay-intact behavior for a real excursion, and gives the exact
  harness shape (`commit_fixture`, `write_state`, `.return-meta.json` with `modified_files`,
  `run_sut`, then assert on `$LAST_STDERR` and `git show --name-only`) to extend.

No existing case sets `modified_files` to explicitly include `"specs/TODO.md"` and/or
`"specs/state.json"` the way task 170's real dispatch does — this is precisely the gap the
dispatch's VERIFY section asks to close.

**`git-commit-scoped.sh`'s V10 precedent** (`git-commit-scoped.sh:499`, landed whole-cloth in
task 394's commit `727a374a5`):

```bash
containment_scope_arr+=("specs/TODO.md" "specs/state.json")
```

This is the exact allowlist shape this task needs, at a sibling (but non-subsuming) containment
site. `git-staging-scope.md`'s "Three Containment sites, not one" section is explicit that this
V10 guard does **not** cover WORK (h)/(i)'s own drop: "Site 1 is NOT subsumed by site 3: a
postflight `modified_files` entry can be dropped by the postflight-sited filter BEFORE it is
ever handed to `git-commit-scoped.sh` at all, so V10 never sees a path site 1 already removed."
This doc passage was written before this task existed and already anticipated exactly this gap
in general terms (any excursion, not specifically naming these two literals) — it did not itself
claim the two state-file literals were already safe at site 1, and this report's trace shows
they are safe only via the separate, undocumented-as-intentional carve-out, not via any
awareness in the predicate itself.

### External Resources

Not applicable — this is a pure bash/jq predicate-logic gap local to this repository.

## Decisions

- **Task 425 is independent of task 440** — confirmed from both directions. Task 440's own
  research explicitly checked this relationship and concluded no overlap (different predicate
  language — `jq` `startswith` over literal paths here, vs. quoted-`case`-pattern glob matching
  for `/**`-suffixed entries there; different files; disjoint declared `file_scope`s; no shared
  helper function). This report's own trace corroborates: this task's fix point is entirely
  inside `orchestrate-cycle-postflight.sh`'s WORK (h) `jq` splice, never touching
  `is_contained_v10()`/`is_contained()`. No `dependencies[]` edge is needed either way.
- **The fix belongs in WORK (h)'s `effective_file_scope_json` splice, not in WORK (i)'s loop
  or in the unconditional `stage_paths` carve-out.** WORK (h) already has exactly this shape
  (two existing splices: implicit own-task-directory, derived-output prefixes) and is the single
  place that produces `excursions_json`, which both the `ADVISORY` message (WORK (h) itself) and
  the `EXCURSION DROPPED` message + `excursion_dropped_count` (WORK (i)) are driven by. Fixing it
  there silences both false positives at their one source, and needs no change to WORK (i)'s
  loop logic, the commit call, or the pre-existing unconditional carve-out (which should stay in
  place as a second, independent layer — see Risks).
- **The unconditional `stage_paths` carve-out stays, and should gain a one-line comment noting
  it is now reinforced by (not merely coincidentally overlapping with) WORK (h)'s own
  allowlist**, so a future reader does not mistake either one for sufficient on its own.
  Removing the carve-out is explicitly out of scope — it is the only thing currently guaranteeing
  "no real loss" today, and the dispatch's own instruction is to add an allowlist, not to
  consolidate or delete the existing defense.

## Recommendations

1. **Add a third splice to WORK (h)'s `effective_file_scope_json`**, in
   `orchestrate-cycle-postflight.sh`, immediately after the existing derived-output-prefix splice
   (around current line ~1586, before the `excursions_json=$(jq -c -n ...)` computation at
   ~line 1599):
   ```bash
   # Engine-written state-file exemption: specs/TODO.md and specs/state.json are written by
   # update-task-status.sh / this postflight on behalf of EVERY task, never declared in any
   # task's own file_scope -- mirrors git-commit-scoped.sh's own V10 allowlist (task 394) at a
   # sibling, non-subsuming containment site (see git-staging-scope.md's "Three Containment
   # sites" section).
   effective_file_scope_json=$(echo "$effective_file_scope_json" | jq -c '. + ["specs/TODO.md", "specs/state.json"]')
   ```
   This is a literal-path splice, matching the predicate's own `startswith`/exact-match
   semantics — no glob syntax is introduced, so it cannot interact with task 440's `/**` fix.
2. **Add a one-line comment at the `stage_paths=(...)` carve-out (WORK (i), ~line 1843)** noting
   it is reinforced by WORK (h)'s own allowlist, per the Decisions section above.
3. **Extend `test-orchestrate-cycle-postflight.sh`** with a new case, modeled directly on the
   existing "Invariant: modified_files-vs-file_scope excursion..." block (~line 1203) and the
   "specs/ carve-out" block (~line 1313), proving the three VERIFY requirements the dispatch
   names:
   - A task declares a non-empty `file_scope` that does NOT include `specs/TODO.md` or
     `specs/state.json`; `.return-meta.json`'s `modified_files` explicitly lists both (plus an
     in-scope file), matching real production reports. Assert: (a) zero `EXCURSION DROPPED`
     lines mentioning either path in `$LAST_STDERR`; (b) zero `ADVISORY` lines mentioning either
     path; (c) both paths present in `git show --name-only --format= HEAD`; (d) the commit's
     `excursion_dropped_count` summary line (if any genuine excursion also exists in the same
     fixture) counts only the genuine excursion, not these two.
   - Reuse (or add alongside) the existing genuinely-out-of-scope fixture (e.g. a case combining
     the real excursion from the existing "Invariant" block *with* `specs/TODO.md`/
     `specs/state.json` also present in the same `modified_files` array) to pin that the
     allowlist does not widen the predicate generally — the arbitrary excursion must still be
     dropped, warned, and left dirty on disk exactly as today, in the same run that correctly
     allowlists the two state files.
4. **Apply the change in the source store** (`agent-system/extensions/core/scripts/
   orchestrate-cycle-postflight.sh` and its test file under `agent-system/extensions/core/
   scripts/tests/`), never under the deployed `.claude/**` tree, then redeploy via
   `deploy-headless.sh` per `rules/source-store-deploy-boundary.md`.
5. **No `dependencies[]` edge against task 440** — proceed independently.

## Risks & Mitigations

- **Risk**: widening `effective_file_scope_json` could be mistaken for license to add more
  "convenience" literals over time, eroding the predicate's precision. **Mitigation**: the
  dispatch's own scope is exactly two literals (`specs/TODO.md`, `specs/state.json`); the
  recommended comment cites the *reason* (engine-written-on-behalf-of-every-task), which should
  deter ad hoc future additions without an equally durable justification.
- **Risk**: a reviewer, seeing this report's finding that no actual commit-time loss currently
  occurs, concludes the fix is merely cosmetic and can be skipped. **Mitigation**: the
  Executive Summary and Decisions sections are explicit that (a) the false diagnostic is real,
  confirmed, and is what triggered this very task's creation, and (b) "no loss today" is a
  fragile property of a separate, undocumented carve-out — not a reason to leave the predicate
  itself wrong. The dispatch's own SCOPE section asks for the allowlist regardless.
- **Risk**: a new fixture that only loosely checks for "no warning containing excursion.sh"
  could pass accidentally if the warning wording changes. **Mitigation**: follow the existing
  test file's own pattern of asserting on the literal `EXCURSION DROPPED`/`ADVISORY` substrings
  plus the specific path, exactly as every existing case in this suite already does.

## Context Extension Recommendations

None — `git-staging-scope.md`'s "Three Containment sites, not one" section already documents
the general shape of this gap (site 1 not subsumed by site 3); no new context file is needed.
A plan may choose to add one sentence there noting the WORK (h) allowlist once landed, but that
is an editorial nicety, not a coverage gap.

## Appendix

- Commands used: `grep -n` sweeps of `orchestrate-cycle-postflight.sh` for
  `excursions_json`/`modified_files_json`/`EXCURSION`/`STATE_FILE`/`TODO.md`;
  `git log --oneline -S` against both `git-commit-scoped.sh`'s V10 literal and
  `orchestrate-cycle-postflight.sh`'s `stage_paths=` line to date-anchor both carve-outs;
  `git show --stat`/`git show <rev>:<path> | jq` against task 170's cycle-1 commit and its
  contemporaneous `.return-meta.json`; `git log --format='%ci %h %s' -1 <sha>` to establish
  commit-time ordering between task 170's cycle-1 commit and task 394's V10 landing; a read of
  `test-orchestrate-cycle-postflight.sh`'s full `info "..."` case index and three representative
  blocks in full.
- References: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (WORK (h)
  ~lines 1554-1606, WORK (i) ~lines 1841-1872); `agent-system/extensions/core/scripts/
  git-commit-scoped.sh` (V10, ~lines 467-539); `agent-system/extensions/core/context/standards/
  git-staging-scope.md` ("Three Containment sites, not one"); `agent-system/extensions/core/
  scripts/tests/test-orchestrate-cycle-postflight.sh` (~lines 1203, 1268, 1313, 3218-3360);
  `specs/440_fix_file_scope_glob_containment_predicate/reports/01_glob-containment-predicate-fix.md`.
