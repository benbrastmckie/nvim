# Research Report: Task #335

**Task**: 335 - Promote the modified_files-vs-file_scope excursion advisory into a staging-time
gate, so the per-cycle commit stops carrying paths the advisory already named
**Started**: 2026-10-08
**Completed**: 2026-10-08
**Effort**: medium
**Dependencies**: 284 (completed — own-task-directory exemption; see Findings)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`scripts/orchestrator-postflight.sh`, `scripts/skill-base.sh`,
`context/standards/git-staging-scope.md`, `context/reference/orchestrator-critical-paths.json`,
`scripts/tests/test-orchestrate-cycle-postflight.sh`), `specs/state.json`, prior-art task
artifacts (165, 284, 336), `scripts/git-commit-scoped.sh`'s exit-code contract (read-only, not
edited)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both halves of the defect are confirmed, at CURRENT (not the dispatch's stale) line numbers:
  WORK (h)'s excursion computation is `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1445-1478`
  (sets `excursions_json`, logs the ADVISORY, never gates); WORK (i)'s staging loop is at
  `:1706-1764` (re-reads `.modified_files[]` from the same `.return-meta.json`, ignores
  `excursions_json` entirely). The file has grown to 2008 lines (dependency 284 added header
  prose and three test fixtures after this task's description was authored).
- Both variables WORK (i) needs (`excursions_json`, `modified_files_json`) are already in scope
  at the WORK (i) site: the script is one flat top-level sequence (only `usage()` and `is_live()`
  are functions), so no plumbing/threading is required — only a drop-filter at the existing
  per-line read loop.
- Dependency 284 already did the hard, fail-positive-prone part: it spliced the task's own
  resolved directory into the comparison (`effective_file_scope_json`), and already recorded,
  verbatim in the header, the "stay advisory" ruling plus a two-part promotion criterion. This
  task's job is narrower than it may first appear: make WORK (i) consult the verdict 284 already
  computes correctly, not redesign the predicate.
- Fail-open is already structural, not something to add: when a task's declared `file_scope` is
  empty, WORK (h)'s `if length>0` guard never runs, so `excursions_json` stays its default `'[]'`
  — WORK (i) consulting that default drops nothing. No new guard is needed for work item (4); it
  falls out of reusing the existing variable.
- The `specs/` carve-out is also structural, not something to add: `TASK_DIR`, `TODO.md`,
  `STATE_FILE`, and `plan_path` are appended to `stage_paths` in a separate statement
  (`:1712-1713`) BEFORE the `modified_files` loop, and the excursion filter only ever applies
  inside that loop. These four are never tested for containment and never will be, under the
  recommended design.
- **Found a load-bearing test currently asserting the PRE-fix behavior as an invariant**:
  `scripts/tests/test-orchestrate-cycle-postflight.sh`'s "excursion never changes exit code or
  verdict" block (`~:1158-1178`) feeds a `modified_files` entry
  (`completely/unrelated/excursion.sh`) that **does not exist on disk** in its fixture. Because
  the path is absent, `git-commit-scoped.sh`'s own V2 gate already silently drops it today
  (genuinely-unmatched-path tolerance) — the test currently cannot distinguish "dropped by this
  task's new filter" from "dropped by git-commit-scoped.sh's pre-existing unmatched-path
  tolerance" either way. To make the synthesised regression fixture this task's acceptance
  criteria requires (fails before, passes after), the fixture must create a REAL file at the
  excursion path so there is something to actually commit-or-not-commit, and the assertion must
  move from "ADVISORY logged" to "the excursion path is absent from the commit's tree /
  present-but-uncommitted on disk" while "the rest of modified_files IS committed."
- The sibling phase-commit-staging task (filed alongside this one, already landed by the time of
  this research) ruled on the identical Containment-vs-Overlap distinction one layer down (inside
  each implementation agent's own phase-commit recipe) and recorded working terminology this task
  should reuse for consistency: "Containment predicate," "drop-and-warn, never refuse the whole
  commit," "fail OPEN on a missing/malformed `file_scope`," and a non-fatal `issue-record.sh
  --class "scope excursion"` call. Its own concrete block is
  `agent-system/extensions/core/agents/general-implementation-agent.md`'s
  `#### Phase-Commit Containment Self-Check` heading — a durable, non-task-numbered anchor to
  cite from this task's own header pointer (per Work Item 7).
- `scripts/orchestrator-postflight.sh` is confirmed orphaned by three independent sources
  (`skill-base.sh:991` and `:1185`, `context/reference/state-management-schema.md:288`, and a
  repo-wide grep finding zero invocation sites, only comment cross-references). Work Item (3)'s
  stated default — do not add the gate to dead code — holds; recommend explicitly declining that
  extension with the orphan status as the stated reason.
- The out-of-repository-pathspec task (304) is confirmed `not_started` with no artifacts — its
  predicate has not landed, so this task must not pre-empt it; the "load-bearing interaction"
  section's instruction ("if it has not, do not pre-empt its predicate") is satisfied by doing
  nothing with it beyond this acknowledgment.
- `git-commit-scoped.sh`'s exit-code contract (0/1/2/3/4, gates V2/V3/V5/V6, plus a V7 post-add
  verification) is read-only context for this task — confirmed NOT on the admission-gate
  registry and confirmed out of this task's `file_scope`. The recommended design (filter
  `stage_paths` upstream, inside `orchestrate-cycle-postflight.sh`, before calling
  `git-commit-scoped.sh`) never touches that contract: the script simply never sees a dropped
  path, so none of V2/V3/V6 are even exercised by it.

## Context & Scope

**What was researched**: the exact current-line-number shape of WORK (h) and WORK (i) in
`orchestrate-cycle-postflight.sh` (post-284, since the dispatch's cited line numbers are stale by
its own admission); whether the fail-open and specs/-carve-out requirements need new code or fall
out of reuse; the existing test suite's current excursion-related fixtures and whether they
already assert the post-fix shape or the pre-fix one; the two task-284/165 prior-art rulings this
task is instructed to mirror; the sibling phase-commit-staging task's landed ruling and
terminology; the orphan status of `orchestrator-postflight.sh`; and the not-started status of the
out-of-repository-pathspec task this task must not pre-empt.

**Constraints carried over from the dispatch** (restated for anyone reading this report without
the dispatch file): source-store edit target only
(`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`scripts/tests/test-orchestrate-cycle-postflight.sh`,
`context/standards/git-staging-scope.md` — exactly task 335's declared `file_scope`, confirmed
directly from `specs/state.json`); no change to `git-commit-scoped.sh` itself (a specific,
possibly-needed exit-code extension is a FOLLOW-UP only, constrained by the out-of-repository-
pathspec task's ownership of that contract); no redefinition of what `file_scope` means or how it
is harvested; no fix to the own-task-directory false positive (dependency 284's completed work);
no work on the phase-commit staging surface (the sibling task's, already completed).

## Findings

### Codebase Patterns

**WORK (h), current location**: `orchestrate-cycle-postflight.sh:1445-1478`.

```bash
# ─── WORK (h): modified_files vs file_scope excursion advisory (detection only) ────────────────
meta_file="${TASK_DIR}/.return-meta.json"
modified_files_json=$(jq -c '.modified_files // []' "$meta_file" 2>/dev/null) || modified_files_json='[]'
file_scope_json=$(jq -c --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .file_scope // []' "$STATE_FILE" 2>/dev/null) || file_scope_json='[]'
task_dir_rel="${TASK_DIR#"$PROJECT_ROOT"/}"
excursions_json='[]'
if [ "$(echo "$file_scope_json" | jq 'length')" -gt 0 ] 2>/dev/null; then
  effective_file_scope_json="$file_scope_json"
  if [ -n "$task_dir_rel" ] && [ "$task_dir_rel" != "$TASK_DIR" ]; then
    spliced_fsj=$(echo "$file_scope_json" | jq -c --arg d "${task_dir_rel}/" '. + [$d]' 2>/dev/null) && effective_file_scope_json="$spliced_fsj"
  else
    echo "${notice_prefix} WARNING: TASK_DIR ('${TASK_DIR}') is not PROJECT_ROOT-relative as expected — skipping the implicit own-task-directory file_scope member for this advisory only (declared file_scope is still compared as-is)." >&2
  fi
  excursions_json=$(jq -c -n --argjson mf "$modified_files_json" --argjson fs "$effective_file_scope_json" \
    '[$mf[] | select(. as $p | any($fs[]; . as $f | $p == $f or ($p | startswith($f))) | not)]' 2>/dev/null) || excursions_json='[]'
  excursion_count=$(echo "$excursions_json" | jq 'length' 2>/dev/null) || excursion_count=0
  if [ "$excursion_count" -gt 0 ]; then
    echo "${notice_prefix} ADVISORY: task ${task_number} reported modified_files outside its declared file_scope: $(echo "$excursions_json" | jq -c '.')  (detection only — no gate, no exit-code, no verdict effect)." >&2
  fi
fi
```

`excursions_json` and `modified_files_json` are plain top-level shell variables (no function
boundary anywhere between here and WORK (i) — the whole script is a flat sequence apart from the
two helper functions `usage()` and `is_live()`), so they are directly readable, unmodified, 240+
lines later.

**WORK (i), current location**: `orchestrate-cycle-postflight.sh:1706-1764`.

```bash
# ─── WORK (i): per-task scoped commit ───────────────────────────────────────────────────────────
if is_live && [ "$research_gate_failed" != "true" ]; then
  stage_paths=("${TASK_DIR}/" "$(dirname "$STATE_FILE")/TODO.md" "$STATE_FILE")
  [ -n "${plan_path:-}" ] && [ "$phase" = "implement" ] && stage_paths+=("$plan_path")
  meta_file="${TASK_DIR}/.return-meta.json"
  modified_count=0
  while IFS= read -r f; do
    if [ -n "$f" ]; then
      stage_paths+=("$f")
      modified_count=$((modified_count + 1))
    fi
  done < <(jq -r '.modified_files[]? // empty' "$meta_file" 2>/dev/null)

  if [ "$modified_count" -eq 0 ]; then
    echo "[postflight] WARNING: no modified_files reported for task #${task_number}; source-file changes NOT committed automatically. Review and commit manually." >&2
  fi
  ...
  bash "${SCRIPT_DIR}/git-commit-scoped.sh" \
    --message "$commit_message" --session "$session_id" --honest-index-rows "$task_number" \
    --task "$task_number" -- "${stage_paths[@]}" \
    || echo "${notice_prefix} WARNING: commit failed for task ${task_number} (non-blocking) — proceeding to lock release." >&2
```

`--task "$task_number"` is already present at this call site (confirms the dispatch's own claim
that the V5 contended-path lease IS consulted here — it simply has no manifest entry for a path
no task declares, per the sibling task's own direct-trace finding below).

**The four `specs/`-carve-out entries (`TASK_DIR`, TODO.md, STATE_FILE, plan_path) are appended in
a SEPARATE statement, before the `modified_files` loop.** Any filter implementation that operates
only inside the `while IFS= read -r f; do ... done < <(jq ... .modified_files[])` loop
structurally cannot touch these four — they are never candidates for the excursion comparison
and the acceptance criterion "the specs/ carve-out... stay green" is satisfied by construction,
not by an added conditional.

**Fail-open is likewise structural.** `excursions_json='[]'` is the variable's own initialization,
BEFORE the `if length>0` guard. A task with no declared `file_scope` (or an empty array) never
enters that `if`, so `excursions_json` keeps its `'[]'` default. WORK (i) subtracting
`excursions_json` from the staged set therefore subtracts nothing for such a task — it commits
exactly as it does today, with no new guard required for Work Item (4). Confirms the dispatch's
instruction to "match that posture" by simply not re-deriving a parallel guard.

### Prior-Art Rulings (Dependency 284 and Related Completed Tasks)

**Task 284** (completed, this task's sole dependency) is the one that produced the current WORK
(h) shape above. Its summary records two rulings verbatim in the script header (both already
present in the code read above, confirming they are durable, not merely summarized):
1. The own-task-directory exemption covers the WHOLE directory, by parity with the commit
   pipeline's own whole-directory staging — "this advisory should not be stricter about a task's
   own tree than the thing it is advising about."
2. Enforcement stays advisory in dependency 284's own change, with a two-part promotion criterion
   recorded verbatim: (a) a bake-in period with zero false-positive advisories (284 measured ~96%
   coverage at ruling time), AND (b) a schema check enforcing `modified_files` paths are
   repo-relative (closing the absolute-path counter-example, which the own-directory fix cannot
   correct). **This task is squarely what (a)'s bake-in period was waiting to be promoted INTO**
   — 284's own header text frames the channel's continued advisory-only status as provisional,
   not as a standing objection to ever gating on it. This task's own recorded ruling (Work Item 2)
   should read as the promotion decision 284 explicitly deferred, not as a departure from it.

**Task 165** (completed, `admission_posture_for_absent_file_scope`) is the cited prior art for
"fail open where `file_scope` is absent" (Work Item 4). Its ruling split cross-batch absence
(stays advisory) from in-batch absence (becomes blocking) at the ADMISSION layer — a different
layer than this task's STAGING layer, but the posture precedent ("a concurrency/scope guard
degrading on absent `file_scope` must fail open, never block, until a recorded promotion
criterion is met") is the one this task's dispatch invokes, and this task's design already
satisfies it structurally as shown above.

**The sibling phase-commit-staging task** (filed alongside this one; archived/completed by
research time, slug `phase_commit_staging_has_no_scope_check`) ruled on the SAME
Containment-vs-Overlap distinction one layer down — inside each of fifteen implementation
agents' own phase-commit recipe, not at this postflight layer. Its report traced
`build_contended_manifest()` directly (`scripts/lib/territory-contention-lib.sh:231-309`) and
confirmed, by code read rather than inference, the exact claim this task's dispatch makes: a path
enters the V5 contention manifest only when **two or more** tasks' declared `file_scope` name it;
a path **no** task declares is never written into any manifest, under any `--task` value, so
`--task` alone cannot be the whole fix — it addresses a different hazard (concurrent same-file
dispatch between two tasks that both declare the path), not the undeclared-path hazard this
task's defect is. The sibling task's landed terminology (reusable here for consistency):
"Containment predicate" (one concrete path vs. one task's own scope, as distinct from the
Overlap-family `--task` check), "drop-and-warn, never refuse the whole commit," "fail OPEN on a
missing/malformed/unreadable/erroring `file_scope`," and a non-fatal `issue-record.sh --class
"scope excursion"` call recording the drop. Its durable, non-task-numbered anchor for Work Item
7's required pointer: `agent-system/extensions/core/agents/general-implementation-agent.md`'s
`#### Phase-Commit Containment Self-Check` heading (and that file's own cross-reference to the
constrained `git-commit-scoped.sh` follow-up, coordinated with the out-of-repository-pathspec
task). The sibling task's own report independently confirms this task's framing: "the mid-dispatch
asymmetry is real and load-bearing: a phase commit has no postflight in scope... so the fix cannot
be sited in `orchestrate-cycle-postflight.sh` — that is [this postflight task's] layer, and [this
task's] own description concedes it cannot reach this surface either." The two tasks are
deliberately complementary, not overlapping: this task owns the postflight-cycle-commit surface,
the sibling owns the phase-commit surface, and git-commit-scoped.sh's own mechanical chokepoint is
left as a coordinated follow-up by both.

### `orchestrator-postflight.sh` Orphan Status (Work Item 3)

Confirmed orphaned by three independent sources, not merely the stale comment the dispatch itself
flagged for re-confirmation:
- `scripts/skill-base.sh:991`: "orchestrator-postflight.sh itself has no live callers."
- `scripts/skill-base.sh:1185`: "the orphaned orchestrator-postflight.sh."
- `context/reference/state-management-schema.md:288`: "its only writer,
  `scripts/orchestrator-postflight.sh`, had no live callers."
- A repo-wide grep for `orchestrator-postflight.sh` across every `.sh`/`.md` file in the source
  store finds only comment cross-references and historical "formerly ran inline here" notes (e.g.
  `git-commit-scoped.sh:47`, `batch-orchestration-guardrails.md:314`: "Zero references anywhere in
  `skills/skill-orchestrate/SKILL.md`... this script belongs to a different command's postflight,
  not MT dispatch") — zero invocation sites (no `bash .../orchestrator-postflight.sh` call
  anywhere).

Its own Stage 9 (lines ~505-530 as currently laid out) assembles `stage_paths` the identical way
WORK (i) does and has no excursion computation of its own — confirmed by direct read. The stated
default holds: a gate in dead code is not worth the edit. Recommend Work Item (3) be recorded as
explicitly declined, with the orphan status (and its three independent sources) as the stated
reason, rather than silently skipped.

### Out-of-Repository-Pathspec Task (304) — Load-Bearing Interaction Check

Confirmed `not_started`, with `dependencies: [184, 263, 273, 284, 285, 302]` and no artifacts in
its own task directory. Its predicate (repository containment) has not landed, so this task
proceeds on the file_scope-membership predicate alone, composing nothing from it — satisfying the
dispatch's explicit instruction not to pre-empt an unlanded predicate. Note the dependency graph
itself: 304 depends on 284 (this task's own dependency), so 304 is guaranteed to run no earlier
than this task could have; no reverse hazard exists.

### Test Suite: an Existing Case Asserts Pre-Fix Behavior as an Invariant

`scripts/tests/test-orchestrate-cycle-postflight.sh`'s block titled "Invariant: the excursion
advisory never changes exit code or verdict" (around line 1158 at research time; candidate
`707_candidate`) is the one existing fixture most directly relevant to this task, and it needs
MODIFICATION, not just a neighboring addition:

```bash
cat > "$WORKDIR/specs/707_candidate/.return-meta.json" <<'EOF'
{"status":"implemented", ...,
 "modified_files":["specs/707_candidate/summaries/01_x-summary.md","completely/unrelated/excursion.sh"]}
EOF
...
if [ "$LAST_EXIT" -eq 0 ] && [ "$(jqf '.verdict')" = "ok" ]; then
  pass "invariant: an excursion outside file_scope still exits 0 with verdict=ok (detection only)"
...
if echo "$LAST_STDERR" | grep -q "ADVISORY.*excursion.sh"; then
  pass "invariant: the excursion is actually logged (the check is not silently inert)"
```

`completely/unrelated/excursion.sh` is **never created on disk** in this fixture's `$WORKDIR`.
Today, this means WORK (i) stages a nonexistent path, which `git-commit-scoped.sh`'s own V2 gate
(unmatched-pathspec classification) already silently drops with a warning — the commit still
succeeds with exit 0/verdict=ok regardless of whether this task's new filter runs or not, because
nothing is actually being committed-or-not at that path either way. **This fixture as written
cannot distinguish pre-fix from post-fix behavior for the one thing this task changes
(whether the excursion path is ever included in `stage_paths` at all)** — it can only keep
verifying exit-code/verdict stability (which the recommended drop-and-commit design does
preserve) and that the ADVISORY is still logged (also preserved, since WORK (h) is untouched).

To build the "synthesised postflight-shaped regression fixture that fails before the change and
passes after" the acceptance criteria require, the excursion path needs to actually exist on disk
in the fixture (e.g. `echo x > "$WORKDIR/completely/unrelated/excursion.sh"`, committed into the
fixture's initial `commit_fixture` baseline so there is a real pre-existing file for a real edit
to be observable against), and the new assertion needs to check the COMMIT CONTENTS — e.g. `git
show --stat HEAD` or `git diff HEAD~1 HEAD --name-only` inside `$WORKDIR` — confirming the
excursion path is ABSENT from the commit's changed-file list while the summary path IS present.
Today (pre-fix) that new assertion would fail, because WORK (i) stages and commits the excursion
path unconditionally; after the recommended fix it passes. The existing exit-code/verdict/ADVISORY
assertions in this block should be kept (they remain true under the recommended design) and the
new containment assertion added alongside them in the same fixture, rather than as a wholly
separate case — it is the same scenario, just checking the staging outcome the pre-existing
assertions never tested.

### Design Space for Work Item (2)'s Ruling

Three candidates were named in the dispatch; here is what each costs, re-derived from the code
read above rather than restated:

1. **Drop the excursion paths and commit the rest** (recommended). Filter `modified_files_json`
   against `excursions_json` (both already in scope) before the `while` loop appends to
   `stage_paths`, so an excursion path is simply never passed to `git-commit-scoped.sh`. Zero
   interaction with that script's exit-code contract — it never sees the dropped path, so V2/V3/V6
   are not exercised differently than today. Matches `git-staging-scope.md`'s own recorded
   "under-stage, never over-stage" fail-safe direction, and matches the sibling phase-commit
   task's own ruling at its layer (same predicate, same drop-and-warn posture, just one layer
   earlier in the pipeline).
2. **Refuse the commit outright.** Rejected by the dispatch's own framing (recommended-against)
   and by this research: it would turn a detection-only channel directly into a hard failure
   with NO opt-out, on a predicate dependency 284 itself still calls provisional pending its
   own promotion criterion — inconsistent with every fail-open precedent (165, the sibling
   task's fail-open clause) this codebase has established for scope/concurrency guards.
3. **Widen `file_scope` and proceed.** Explicitly out of scope — "What `file_scope` means; how it
   is harvested... is out of scope. This task makes staging honour the existing contract, it does
   not redefine it."

Candidate 1 is the only one consistent with every constraint found above: it needs no
`git-commit-scoped.sh` change, it reuses rather than re-derives WORK (h)'s verdict (Work Item 1),
it degrades to a no-op when `file_scope` is absent (Work Item 4) with no new code, and it leaves
the `specs/` carve-out and zero-`modified_files` cases structurally untouched (Work Item 5).

### `git-commit-scoped.sh` Exit-Code Contract (Read-Only Context)

Mirrored here from `git-staging-scope.md`'s own "Exit-Code Contract and Safety Gates" subsection,
confirmed current against the script and NOT this task's `file_scope`:

| Exit | Meaning |
|------|---------|
| 0 | Commit created |
| 1 | Nothing to commit, or commit failed after lock retry |
| 2 | Usage error, or V3 degenerate-pathspec refusal, or `git add` itself failed |
| 3 | V5 contended-path refusal (`--task` only) |
| 4 | V6: a positive pathspec was dropped as genuinely unmatched AND the commit produced nothing |

Gates V2 (unmatched-path classification), V3 (degenerate-pathspec refusal), V5 (contended-path
lease), V6 (partial-drop-with-nothing-committed), and V7 (post-add index-state verification,
documented in the script's own header) are all pre-existing and untouched by the recommended
design. If a future ruling concludes the Candidate-1 drop needs a DIFFERENT signal than silent
omission (e.g. a distinguishable exit code for "a commit succeeded but dropped a file_scope
excursion"), that is explicitly the out-of-repository-pathspec task's exit-code contract to
extend — recorded here as a FOLLOW-UP, not performed by this task, per the dispatch's own scope
note.

## Decisions

- Recommend implementing Work Item (2)'s ruling as drop-and-commit (Candidate 1 above), consistent
  with the dispatch's own stated starting hypothesis, the sibling phase-commit task's parallel
  ruling, and `git-staging-scope.md`'s existing fail-safe direction.
- Recommend Work Item (3) be recorded as explicitly DECLINED (not silently skipped), citing the
  three independent orphan-status sources found above as the reason, rather than re-stating the
  dispatch's own "orphan status still holds" language as if newly discovered.
- Recommend reusing the sibling phase-commit task's terminology ("Containment predicate,"
  "drop-and-warn," "fail OPEN") in this task's own header ruling prose, for a single consistent
  vocabulary across the two layers that independently arrived at the same predicate.
- Recommend the existing `707_candidate` "excursion never changes exit code or verdict" fixture be
  MODIFIED (real on-disk excursion file, new commit-contents assertion) rather than left alone and
  supplemented by an unrelated new case — it is testing the same scenario the new acceptance
  criterion needs, just missing the one assertion that would show the fix. New fixtures are still
  needed for: absent-file_scope fail-open (reusing an existing no-`file_scope` candidate shape
  like `708_candidate`, but with a modified_files entry that WOULD be an excursion if `file_scope`
  were declared, confirming it is NOT dropped), the `specs/` carve-out (confirming
  `TASK_DIR`/TODO.md/STATE_FILE/plan_path are never excursion-tested even when `file_scope`
  excludes them structurally — they are appended outside the loop, so this is more a
  documentation-of-invariant case than a new code path), and the zero-`modified_files` case
  (already covered by the pre-existing "no modified_files reported" warning path — confirm it is
  untouched, do not duplicate it).
- Recommend `context/standards/git-staging-scope.md` record the new behavior in a new subsection
  (candidate placement: adjacent to "Fail-Safe Direction," since the new behavior is a refinement
  of exactly that direction) rather than inside the existing V2/V3/V5/V6/V7 gate table — those
  gates all live inside `git-commit-scoped.sh` itself, and this task's change is sited one layer
  above that script, in the caller. The new subsection should carry: the dated 2026-10-04
  empirical observation (ten Typst files, nine outside declared `file_scope`), stated accurately
  as a PHASE commit (not a postflight commit) per the dispatch's own qualifier — explicitly NOT
  claiming this new gate would have caught it — and a forward pointer to the sibling task's own
  phase-commit-layer ruling for the surface this task's gate structurally cannot reach.

## Recommendations

1. **Work Item 1** (consult, don't recompute): in WORK (i)'s `while IFS= read -r f; do ... done <
   <(jq -r '.modified_files[]? // empty' "$meta_file")` loop, add a per-entry membership test
   against `excursions_json` (e.g. `jq -e --arg p "$f" '... any(.[]; . == $p) ...' <<<
   "$excursions_json"`) and skip appending to `stage_paths` (with a loud, non-silent warning
   naming the dropped path) when the entry is a member. Do not re-read `.return-meta.json` a
   second time for this — `modified_files_json` is already the parsed array WORK (h) produced
   from the same file in the same run; iterate that instead of re-invoking `jq -r
   '.modified_files[]?'` against the file a second time, closing the literal "independently
   re-reads the SAME `.modified_files[]`" defect the dispatch names.
2. **Work Item 2**: implement Candidate 1 (drop-and-commit) as derived above; record the ruling
   and its reason in the script's WORK (h)/(i) header prose, naming the promotion-criterion
   language from dependency 284 as satisfied by this very task (the bake-in period dependency 284
   deferred to is this task's own trigger).
3. **Work Item 3**: record as explicitly declined; cite the three-source orphan-status evidence
   above rather than re-deriving it at implementation time.
4. **Work Item 4**: no new code needed — confirm via a regression fixture (not new production
   code) that an absent/empty `file_scope` still commits every reported `modified_files` entry
   unfiltered, proving the structural fail-open claim rather than merely asserting it.
5. **Work Item 5**: no new code needed for the `specs/` carve-out or the zero-`modified_files`
   warning path — both are structurally untouched by a filter sited inside the `modified_files`
   loop. Add/confirm regression coverage proving this, not new production logic.
6. **Work Item 6**: modify the existing `707_candidate` excursion fixture (give the excursion path
   a real on-disk file; assert on commit contents, not just exit-code/verdict/ADVISORY-presence)
   plus the three additional fixtures enumerated in Decisions above, landing all cases in
   `scripts/tests/test-orchestrate-cycle-postflight.sh` per the dispatch's own naming.
7. **Work Item 7**: state the phase-commit non-coverage explicitly in the script header, pointing
   at `agent-system/extensions/core/agents/general-implementation-agent.md`'s `#### Phase-Commit
   Containment Self-Check` heading as the concrete, durable, non-task-numbered anchor for the
   surface this gate cannot reach (per `no-task-references-in-deliverables.md`, the pointer must
   name a file/heading, never a task number, outside `specs/**`).
8. Update `context/standards/git-staging-scope.md` per the Decisions section's placement
   recommendation, with accurate phase-commit provenance on the empirical observation (explicitly:
   "this commit was NOT produced by this script... no claim is made that this gate would have
   prevented it").
9. Run `shellcheck -x` on the edited script against its own pre-change baseline (this environment's
   `shellcheck` binary was unreachable at research time — a broken Nix store path, not a codebase
   issue — so the implementation phase must establish and diff against the baseline itself rather
   than trust this report's inability to run it).

## Risks & Mitigations

- **Risk**: filtering inside the `while` loop silently changes `modified_count`'s semantics (today
  it counts every reported entry; after the fix, should it count only non-excursion entries, or
  still count all reported entries with a separate excursion counter?). This affects whether the
  pre-existing "no modified_files reported" warning could ever MIS-fire when every reported entry
  happens to be an excursion (zero actually staged, but `modified_count` nonzero under the "count
  all reported" reading). **Mitigation**: keep `modified_count` counting every reported entry
  (preserves the existing zero-`modified_files` warning's meaning — "nothing was reported," not
  "nothing was staged") and track dropped-excursion count separately for the new warning line;
  this is an implementation-time decision, not a research gap, since both readings are internally
  consistent — flagging it here so the plan makes the choice explicitly rather than by accident.
- **Risk**: the modified `707_candidate` fixture's new commit-contents assertion needs the
  fixture's baseline commit (`commit_fixture`) to include the excursion file so `git diff
  HEAD~1 HEAD` (or equivalent) has a real prior state to compare against, not a bare "file exists
  untracked" state. **Mitigation**: create and commit the excursion file as part of the fixture's
  existing `commit_fixture` call (the same call that already commits `specs/TODO.md` and
  `specs/state.json` today), then separately verify the sandboxed commit the SUT (the postflight
  script under test) itself performs does not touch it.
- **Risk**: reusing `excursions_json` assumes WORK (h) and WORK (i) stay co-located in one flat
  script with no function boundary between them. If a future refactor moves either into a
  function, the variable would need explicit threading (a parameter or a global declared
  `declare -g`). **Mitigation**: not a concern for this task (no such refactor is in scope or
  planned), but worth a one-line header comment noting the ordering dependency so a future editor
  does not silently break it by reordering WORK (h) after WORK (i) or wrapping either in a
  function.

## Context Extension Recommendations

- **Topic**: Containment vs. Overlap terminology is now independently re-derived at two layers
  (this task's postflight layer, and the sibling task's phase-commit-recipe layer) with converging
  but not identically-worded rulings.
- **Gap**: no single context file states "Containment" and "Overlap" as the two named predicate
  families once, for both layers to point at — each ruling currently restates the distinction
  inline in its own host file/header.
- **Recommendation**: a future task could extract a short shared definition (referenced from
  `file-footprint-overlap.md`, which the sibling task's report already cites as defining these
  terms) so both this task's header and the sibling's `#### Phase-Commit Containment Self-Check`
  heading cite one canonical definition instead of two independently-worded restatements. Not
  blocking for this task — both existing restatements are accurate — but worth flagging as the
  kind of drift the "a reader of this document is not left to open the script for it" pattern
  elsewhere in this codebase (e.g. `git-staging-scope.md`'s own exit-code-table mirroring) exists
  to prevent.

## Appendix

- Searches/reads performed: direct `sed -n`/`grep -n` reads of
  `orchestrate-cycle-postflight.sh` (header, WORK (h) at :1445-1478, WORK (i) at :1706-1764),
  `orchestrator-postflight.sh` (:505-550), `skill-base.sh` (:985-995, :1180-1190),
  `context/standards/git-staging-scope.md` (full file, 564 lines),
  `context/reference/orchestrator-critical-paths.json` (full file),
  `scripts/tests/test-orchestrate-cycle-postflight.sh` (:1155-1230 and a targeted grep for the
  `70[5-9]_candidate`/`71[5-7]_candidate` fixture shapes).
- Task-state reads: `specs/state.json`'s `active_projects[] | select(.project_number==335)` (full
  description, `file_scope`, `dependencies: [284]`); task 284's summary/report (completed); task
  165's summary (completed, archived); task 304's state entry (`not_started`, no artifacts); task
  336's (the sibling phase-commit task) summary and report (completed, archived).
- `shellcheck` was present in `$PATH` by name but its resolved Nix store binary was missing on
  this machine at research time (`No such file or directory`) — flagged in Recommendations as an
  implementation-time environment check, not treated as a finding about the codebase.
