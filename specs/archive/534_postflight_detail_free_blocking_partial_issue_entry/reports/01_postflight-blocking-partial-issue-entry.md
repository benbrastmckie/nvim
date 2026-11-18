# Research Report: Task #534

**Task**: 534 - Stop the orchestrate postflight from writing a detail-free blocking issue-log entry on every blocker-bearing partial return, and settle that entry's classification.
**Started**: 2026-11-16T17:28:00Z
**Completed**: 2026-11-16T17:34:00Z
**Effort**: medium
**Dependencies**: None (file_scope disjoint from the sibling null-resolution conclusion-stage record per the dispatch's "DO NOT ENCROACH" instruction)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, `validate-handoff.sh`, `issue-record.sh`, `tests/test-orchestrate-cycle-postflight.sh`), context docs (`context/formats/issue-log.md`, `context/contracts/conclusion-stage.md`, `context/standards/user-decision-contract.md`), git history (`git log -S`, `git show`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The naive `jq '(.blockers // []) | join("; ")'` that silently erroring on object-shaped
  `blockers[]` was already superseded by a map/if-object rendering expression, landed
  incidentally by an unrelated task (`task 304: orchestration paused (cycle 3)`, commit
  `83898819a`, confirmed by that task's own summary as "an unconnected `partial_blockers_detail`
  jq enhancement" from a sibling task in overlap set 184/263/273/279/284/285). The dispatch's
  described root cause (a raw `join("; ")` call erroring on objects) is **not the current state**
  of either the deployed copy or the source-store copy of this call site — re-deriving the
  described failure by running the dispatch's literal expression (not the current one) still
  reproduces the jq type error, confirming the fix's mechanism, but the call site has already
  moved past it.
- The incidental fix is **incomplete** against this task's own acceptance bar in two concrete
  ways: it omits `verbatim_goal` from the rendered prose (the refuted-goal text the dispatch
  singles out as the highest-value lost field), and it still carries `2>/dev/null`, so a future
  jq failure at this call site would still silently fall through to the fallback string with no
  visible trace.
- `test-orchestrate-cycle-postflight.sh`'s existing regression case for a blocker-bearing partial
  (fixture 830, `target`/`verbatim_goal`/`why_it_failed` on the blocker object) asserts the
  `state.json` status transition and the `aux_signal.blocker_desc` content, but never reads
  `issues.jsonl`'s `what_happened` — confirming the dispatch's claim that the suite is green
  while the narrative gap (now narrower, but still present for `verbatim_goal`) goes unchecked.
- Recommended classification settlement: keep `--severity blocking` unchanged (it meets the
  admission test exactly, by construction of the `if partial_blocker_count -gt 0` guard); replace
  the hard-coded `--class "environment"` with a new, honest, generic class value (the `class`
  field is a documented open enum — no `issue-log.md` edit is required to use a new value); add
  a write-time de-duplication check against the task's own `issues.jsonl` keyed on blocker
  identity (`phase`+`target`, normalized) before calling `issue-record.sh`; and drop the
  suppress-on-`user_decision` idea rather than implement it, for the reason recorded in
  Decisions below.

## Context & Scope

The dispatch (`.dispatch/1.md`) names one call site: the `partial)` arm of the dispatch-status
`case` statement in `orchestrate-cycle-postflight.sh`, which writes an `issues.jsonl` entry via
`issue-record.sh` whenever a `partial` dispatch outcome carries a non-empty handoff `blockers[]`.
Three separable concerns were in scope: (1) whether the rendered `what_happened` prose actually
carries the blocker detail, (2) the entry's `--class`/`--severity` classification, and (3) volume
— the same unresolved blocker being re-recorded, near-identically, on every subsequent partial
dispatch. The dispatch explicitly excludes `conclusion-stage.md`'s resolution-filter predicate,
`issue-record.sh`'s writer logic, and prose edits to `issue-log.md` from this record's territory,
reserving them for a sibling null-resolution record. All file reads below were done against the
source-store copy, `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (and
its sibling test file), per `.claude/rules/source-store-deploy-boundary.md`; the deployed
`.claude/scripts/orchestrate-cycle-postflight.sh` mirror was confirmed byte-identical at the
relevant lines.

## Findings

### Codebase Patterns

- **Current call-site state** (`orchestrate-cycle-postflight.sh`, `partial)` arm, immediately
  after the `skill_postflight_update` call that writes `status="partial"` to `state.json`):
  ```
  partial_blockers_detail=$(echo "${handoff:-null}" | jq -r '(.blockers // []) | map(if type == "object" then "phase \(.phase // ""): \(.target // "")" + (if (.what_was_tried // "") != "" then " | tried: \(.what_was_tried)" else "" end) + (if (.why_it_failed // "") != "" then " | failed: \(.why_it_failed)" else "" end) else tostring end) | join("; ")' 2>/dev/null)
  [ -z "$partial_blockers_detail" ] && partial_blockers_detail="partial outcome with ${partial_blocker_count} blocker(s) (detail unavailable)"
  issue_args=(--task-dir "$TASK_DIR" --kind issue --class "environment" \
    --severity blocking --phase implement --what-happened "$partial_blockers_detail" \
    --resolution open --suggested-channel follow_up_task --session "$session_id")
  ```
  This already discriminates object-shaped entries from scalars (`if type == "object" ... else
  tostring end`), so the specific jq type-error path the dispatch describes
  (`join("; ")` directly on an array of objects, erroring with "string (\"\") and object ...
  cannot be added", exit 5) is **not reachable from this expression as it stands today** — I
  re-ran the dispatch's literal `join("; ")` expression against a synthetic object-shaped
  `blockers[]` payload without `2>/dev/null` and confirmed the jq type error fires exactly as
  described; running the *current* expression against the same payload does not error and
  produces rendered prose. The provenance paragraph's two cited `issues.jsonl` entries
  (`iss_1791711671927_JbPqvi`, `iss_1791716590257_0MGDRu`) predate this fix landing in this
  repository — their fallback-string `what_happened` values were captured against the pre-fix
  expression, in the originating repository.
- **Git provenance of the incidental fix**: `git log -S 'if type == "object" then "phase' --
  agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` returns exactly one
  commit, `83898819a` ("task 304: orchestration paused (cycle 3)", 2026-10-12). That commit's own
  summary (`specs/304_out_of_repo_pathspec_aborts_whole_commit/summaries/01_*.md`) explicitly
  names this as collateral: "a sibling task (one of the declared overlap set
  184/263/273/279/284/285 on `orchestrate-cycle-postflight.sh`) landed a new, unrelated
  uncommitted edit to that file (an unconnected `partial_blockers_detail` jq enhancement) after
  this task's own redeploy" — i.e. an unrelated task's uncommitted edit got swept into task 304's
  commit under concurrent-batch load, a `cross-task ownership/territory` style collision recorded
  by task 304 itself at the time. No task record in this repository documents authorship of the
  rendering-expression change on its own terms.
- **Remaining gap in the rendering**: the object branch renders `phase`, `target`,
  `what_was_tried` (as `| tried: ...`), and `why_it_failed` (as `| failed: ...`), each guarded by
  a non-empty check for the optional ones — but it never references `.verbatim_goal`. The
  dispatch's own description of the lost detail calls out "the refuted goal statement verbatim"
  as the first and most important item ("exactly the content the log exists to preserve"). This
  field is present on every object-shaped blocker example seen in this codebase (the dispatch's
  provenance entries, and every synthetic `blockers[]` fixture in
  `test-orchestrate-cycle-postflight.sh`: lines 2142, 2204, 2328, 2426, 2481, 2509 all set
  `verbatim_goal`), so its omission from the render is a measured, not hypothetical, gap.
- **`2>/dev/null` still present**: unchanged from the dispatch's description. Because the current
  expression's `else tostring end` branch makes it total over any JSON array (no element shape can
  raise the specific type error any more), this stderr redirect is now close to a no-op in the
  common case — but it still means any *future* jq failure at this call site (a malformed
  `$handoff` payload, a jq engine error) degrades silently to the generic fallback string with no
  diagnostic trace, exactly the failure mode the dispatch flags as the thing that converted a
  fixable bug into an invisible one.
- **Test coverage gap, confirmed**: `test-orchestrate-cycle-postflight.sh`'s regression case for
  fixture 830 (`~` line 2328, `common_test_info "Regression: partial + non-empty blockers[]
  writes status=partial and records a handoff-derived blocker-research aux signal"`) sets a
  `blockers[]` entry with `target`, `verbatim_goal`, and `why_it_failed`, then asserts only
  `state.json .status`, `verdict`, `halt`, `aux_signal.kind`, `aux_signal.blocker_desc` (derived
  separately, from a *different* code path than the `issues.jsonl` write — WORK (k)'s aux-signal
  logic, not the `partial)` arm's `issue-record.sh` call), and `aux_pending` persistence. It never
  reads `$WORKDIR/specs/830_candidate/issues.jsonl` at all. I confirmed this by grepping the test
  file for `issues.jsonl`/`what_happened` near fixture 830 (lines 2328-2366) and finding no
  reference in that block — the nearest `issues.jsonl` assertions in the file belong to unrelated
  fixtures (I, I2, J1-J3, all keyed on `class == "orchestration defect"`, a different call site
  entirely — the `RECOVERY_DECLINED` arm, not the blocker-bearing `partial)` arm).
- **Schema confirmation**: `validate-handoff.sh` (lines 312-327) requires every `blockers[]`
  entry to carry `phase` and `target` (warns, does not refuse, when either is `"__MISSING__"`),
  matching the dispatch's description exactly. It imposes no requirement on `verbatim_goal`,
  `what_was_tried`, or `why_it_failed` — these are present-by-convention, not schema-enforced.
- **Severity admission test, checked against the actual guard**: the `partial)` arm's
  `issue-record.sh` call is reachable only inside `if [ "$partial_blocker_count" -gt 0 ]`, which
  is itself inside the `partial)` case — i.e. precisely when a `partial` dispatch is being
  recorded *because* it carries an unresolved blocker. `issue-log.md`'s Severity Scale admits
  `blocking` exactly when "work could not proceed at all ... the dispatch stalled or had to hand
  off because of it" — the guard condition is a direct instance of that admission test, not an
  approximation of it.
- **`class` is a documented open enum**: `issue-log.md`'s "Extensibility Rule" states
  `issue-record.sh` accepts any `--class` value outside the 16-class seed table with a stderr
  warning, never a refusal, and that promoting a recurring new value into the documented seed
  list is "a documentation change ... never an enforcement change in the writer." This means a
  call-site fix for the wrong `--class "environment"` default does **not** require editing
  `issue-log.md` at all — it can pass a new, honest literal straight through `issue-record.sh`,
  which is squarely inside this record's own file scope (the postflight script), not the sibling
  record's reserved territory (the writer script and the format document).
- **Established codebase precedent for "annotate, don't reclassify"**: fixtures (J1)/(J2)/(J3) in
  the same test file (a different call site — the `RECOVERY_DECLINED` arm) assert explicitly that
  `severity` and `class` stay fixed across two different underlying situations (a corroborating
  commit inside the dispatch window vs. none), while a `tags.stall_corroborated` field carries the
  discrimination. The comment at that call site reads "the annotation discriminates, it never
  reclassifies." This is directly applicable precedent for the volume/identity question (see
  Recommendations).
- **`user_decision` relay is structurally later than the `partial)` arm**: the `partial)` case
  arm is "WORK" ordered before "WORK (e): user_decision relay" (grep line 1697 vs. 1470 — the
  `partial)` arm fires first in the script's control flow). `user_decision_json` (line 1702
  onward) is computed by reading `.user_decision` off the handoff file and, failing that, off
  `.return-meta.json` — both are **read-only, idempotent reads with no side effects**, so nothing
  structurally prevents duplicating that same two-line read earlier, immediately before or inside
  the `partial)` arm, if a suppression check were wanted there.
- **No mechanical "answered" signal exists at this vantage point**: `user-decision-contract.md`
  states plainly that `user_decision` is "relayed, never resolved" by postflight — the postflight
  script's role is limited to surfacing the question via the `ask_user` verdict; it has no access
  to whether a human has since answered it (that answer, if given, surfaces later as a new
  dispatch's own `decisions_made` entry or a changed task state, never as a flag on this
  dispatch's `user_decision` payload). The *presence* of `user_decision` on the current return
  means "a question is being asked this cycle," not "a question was previously answered."
- **`issues.jsonl` is CAPTURE ONLY and never reaches the user mid-run** (`issue-log.md`'s "CAPTURE
  ONLY" section: "Nothing is surfaced to the user mid-run"). The `ask_user` verdict that carries
  `user_decision` to the actual user is a structurally separate channel. This matters for the
  suppression question: the two channels have different readers (the user sees `ask_user`; the
  conclusion stage reads `issues.jsonl`, later), so a concurrent `user_decision` relay does not,
  by itself, create any user-visible duplicate signal that suppressing the issue-log entry would
  remove.
- **Measured absence of the volume problem in this repository's live corpus**: I queried every
  `specs/*/issues.jsonl` for a `class == "environment" && severity == "blocking"` entry
  (`grep -rl '"class":"environment"' specs/*/issues.jsonl` and `jq` filter) and found none in this
  repository today — the duplicate-entry pattern the dispatch measured (two byte-identical
  `what_happened` entries differing only in `entry_id`/`timestamp`/`dispatch_seq`/`session_id`)
  exists only in the originating repository's migrated task (`ladder_model_cell_stabilization`,
  entries `iss_1791711671927_JbPqvi` / `iss_1791716590257_0MGDRu`), not currently reproducible
  against any live task directory here. The one `jq -s 'group_by(.what_happened) | ...'` hit
  found across all of `specs/*/issues.jsonl` (`specs/459_cross_task_traceability_and_changelog_verdict/issues.jsonl`,
  1 duplicate group) is unrelated to this call site. This does not weaken the case for a
  dedup fix (the mechanism that produces N-duplicates on repeated partial dispatches against one
  unresolved blocker is structural, not corpus-dependent), but no corpus-wide remediation of
  existing entries is implied or needed — the fix is purely prospective, at write time.

### External Resources

Not applicable — this is a closed, local-codebase defect with no external dependency or
third-party API surface.

## Recommendations

1. **Add `verbatim_goal` to the rendered prose.** Extend the object branch of the existing map
   expression to include `.verbatim_goal` (guarded the same way the optional fields already are:
   included only when non-empty), ordered first after `phase`/`target` since it is the dispatch's
   named highest-value field — e.g. `"phase {phase}: {target} — goal: {verbatim_goal}" + (tried
   clause) + (failed clause)`. This keeps the existing, already-tested shape for the two fields
   already rendered and adds exactly the one missing field, rather than redesigning the format.
2. **Remove `2>/dev/null` from this one jq substitution** (not the many other unrelated `2>/dev/null`
   uses elsewhere in the script), so a future jq failure at this call site prints to the script's
   own diagnostic stream (already routed via the entry-point `exec 3>&1 1>&2` redirect) instead of
   degrading silently to the fallback string. Because `set -uo pipefail` (no `-e`) governs this
   script, removing the redirect does not change control flow — the `[ -z ... ]` fallback guard
   still fires identically on empty output; only the visibility of *why* it was empty changes.
3. **Extend fixture 830 in `test-orchestrate-cycle-postflight.sh`**, in place (not a new fixture),
   to also read `$WORKDIR/specs/830_candidate/issues.jsonl` and assert that the recorded entry's
   `what_happened` contains the blocker's `target`, `verbatim_goal`, and `why_it_failed` text —
   mirroring the existing `aux_signal.blocker_desc` assertion pattern immediately below it in the
   same fixture. Show this assertion fails against the unmodified (pre-`verbatim_goal`) rendering
   first, per the dispatch's acceptance bar, before landing the fix.
4. **Replace `--class "environment"` with a new, honest, generic class value** — a literal such
   as `"unresolved task-domain blocker"` — passed straight through `issue-record.sh`'s open
   `--class` enum with no `issue-log.md` edit required (the Extensibility Rule explicitly
   sanctions this; promotion into the documented seed table is a separate, later, optional step).
   Document the choice with an inline comment at the call site explaining why `"environment"` was
   wrong (its admission test names "the local or CI environment," almost never true of a
   blocker-bearing partial) and why the honest answer is "unknown at this vantage point," not a
   guess. Do not attempt to derive `class` from the handoff mechanically — no field in the
   `blockers[]` object schema (`phase`, `target`, `verbatim_goal`, `what_was_tried`,
   `why_it_failed`) names a class, and guessing one from free-text `why_it_failed` would be
   unreliable pattern-matching dressed up as classification.
5. **Keep `--severity blocking` unchanged.** It is not merely defensible but exact: the call site
   is reachable only when `partial_blocker_count -gt 0` inside a `partial` dispatch outcome, which
   is definitionally "the dispatch ... had to hand off because of it." Reclassifying to reduce
   downstream channel volume would hide a real, correctly-classified signal — the dispatch's own
   caution applies directly here.
6. **Add a write-time de-duplication check keyed on blocker identity**, following the
   already-established "annotate, don't reclassify" precedent from the (J1)/(J2)/(J3) fixtures at
   the sibling `RECOVERY_DECLINED` call site: before calling `issue-record.sh`, read the task's
   own `issues.jsonl` (if it exists) and compute a normalized identity for the current blocker set
   (e.g. a hash or direct string match over `phase`+`target`, since those two fields are the only
   schema-guaranteed ones) against existing `class == <the new class value> && resolution == "open"`
   entries; skip the write when an open entry with the same identity already exists, rather than
   accumulating a count on the existing line (which `issue-log.md`'s own "append-only-by-line,
   never read-merge-rewrite" invariant forbids). This is a prospective behavior change confined
   entirely to the postflight script's own call site — it does not touch `issue-record.sh`,
   `issue-log.md`'s schema, or the conclusion-stage filter predicate, so it stays inside this
   record's declared file scope. The existing `tags.occurrence` convention (`issue-log.md`'s
   "Occurrence Collapse" section) is explicitly a different mechanism (for a caller that already
   knows a repeat count *before* its first call) and does not apply here; cite it only to
   distinguish it, not to reuse it.
7. **Do not implement suppression on `user_decision` presence.** See Decisions below for the
   reasoning; this is a considered drop, not an omission.

## Decisions

- **Severity stays `blocking`, with no change.** Argued on the admission test alone, per the
  dispatch's instruction: the guard condition that gates this call site is a direct instance of
  the `blocking` rung's own admission test, not an approximation needing a judgment call.
- **Class changes from `"environment"` to a new, undocumented-but-permitted open-enum value**
  (`"unresolved task-domain blocker"` recommended as the literal), with no edit to
  `issue-log.md`'s seed table — deferring that documentation promotion to a later, separate
  decision (optionally gated by a `--depends-on-add` edge against the sibling null-resolution
  record if a future revision of `issue-log.md` prose is judged necessary, per the dispatch's own
  instruction on that point). This settles classification question (1) without encroaching on the
  sibling record's reserved file scope (the writer script and the format document), since using
  a new open-enum value requires editing neither.
- **Suppression-on-`user_decision` is dropped, not implemented**, for two independent reasons,
  either of which is sufficient on its own: (a) no mechanical test for "answered" exists at the
  postflight's vantage point — `user_decision` is contractually "relayed, never resolved" by this
  script, so presence of the payload on the current return means "being asked now," not
  "previously answered," and a suppression gated on mere presence would not implement the
  suppression idea as stated; (b) `issues.jsonl` is CAPTURE ONLY and never reaches the user
  mid-run, while the `ask_user` verdict that carries `user_decision` to the user is a structurally
  separate channel with a different reader — so even the weaker, checkable condition ("suppress
  when `user_decision` is present this cycle, regardless of resolution") would not remove any
  user-visible duplicate signal, since the two channels were never duplicating each other from
  the user's point of view in the first place. The volume concern the suppression idea was really
  reaching for is the one addressed directly by Recommendation 6 (identity-keyed dedup), which
  does not depend on `user_decision` at all and has no "answered" ambiguity.
- **The ordering obstacle, while real, is not a reason to defer the dedup fix** — it only
  disqualifies the *suppression* idea specifically (which needed a true "answered" signal that
  does not exist); the identity-keyed dedup in Recommendation 6 needs no `user_decision` read at
  all and so has no ordering dependency on WORK (e).

## Risks & Mitigations

- **Risk**: a new, undocumented `--class` literal could be perceived as inconsistent with the
  seed-table-first convention other call sites follow. **Mitigation**: the Extensibility Rule is
  explicit that this is the sanctioned path for a genuinely new failure mode, and every other
  seed-class call site in this script continues unchanged — only this one call site's wrong
  default moves.
- **Risk**: the identity-keyed dedup check reads `issues.jsonl` from inside the postflight script,
  adding a new read dependency at a call site that currently has none. **Mitigation**: the file is
  the task's own, already-created-by-this-same-script file (lazily created, never gitignored per
  `issue-log.md`), so no new collaborator or lock discipline is introduced beyond what
  `issue-record.sh` itself already manages for the write side; the read is advisory (skip-or-write
  decision only) and failure to read (e.g. file absent) degrades to "write" (today's behavior),
  never to a hard failure.
- **Risk**: extending fixture 830 rather than adding a new fixture could make a future diff larger
  than expected if the dedup check (Recommendation 6) is implemented in the same phase, since a
  second, later partial dispatch against the same task would need a second fixture to exercise the
  skip path. **Mitigation**: scope the fixture-830 extension to the `what_happened`-content
  assertion only (per the dispatch's explicit acceptance bar); add the dedup skip-path assertion as
  a distinct, new fixture in the same phase rather than overloading fixture 830 further.
- **Risk**: removing `2>/dev/null` could, in principle, surface noisy jq diagnostics on an
  unrelated, pre-existing malformed-handoff edge case not previously visible. **Mitigation**: the
  current expression is total over any JSON value shape reachable from a schema-valid handoff
  (object or non-object elements both handled), so the only realistic trigger is a genuinely
  malformed `$handoff` payload — exactly the case where surfacing the diagnostic is the correct
  behavior, not a regression.

## Context Extension Recommendations

- **Topic**: open-enum `--class` values used outside the documented 16-class seed table.
- **Gap**: `issue-log.md`'s Extensibility Rule documents the *mechanism* (any value is accepted
  with a warning) but gives no example of a call site deliberately choosing an undocumented value
  on purpose, as opposed to an agent spontaneously inventing one during a dispatch. A future
  reader auditing `issues.jsonl` for class consistency has no single place to see which
  undocumented values are intentional, stable call-site choices (like the one this task
  introduces) versus one-off agent inventions.
- **Recommendation**: if a future revision of `issue-log.md` is made (gated, per this record's own
  scope boundary, behind a `--depends-on-add` edge against the sibling null-resolution record),
  consider a short "Intentional non-seed classes in active use" list alongside the seed table,
  naming the call site and the literal value, so the promotion decision mentioned in the
  Extensibility Rule has a concrete worklist to draw from.

## Appendix

### Search queries / commands used

- `grep -n "partial)\|partial_blockers_detail\|--class \"environment\"\|--severity blocking" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `git log --oneline --all -S'if type == "object" then "phase' -- agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `git show 83898819a -- agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `git show 83898819a:specs/304_out_of_repo_pathspec_aborts_whole_commit/summaries/01_out-of-repo-pathspec-containment-summary.md`
- `grep -n "verbatim_goal\|partial_blocker\|blocker-bearing\|what_happened" agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `grep -n "blockers\|phase\|target" agent-system/extensions/core/scripts/validate-handoff.sh`
- `for f in specs/*/issues.jsonl; do jq -s 'group_by(.what_happened) | map(select(length>1)) | length' "$f"; done`
- `grep -rl '"class":"environment"' specs/*/issues.jsonl`

### References

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (`partial)` arm, the
  rendering expression and the `issue-record.sh` call)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (fixture 830,
  and the (J1)/(J2)/(J3) annotate-don't-reclassify precedent)
- `agent-system/extensions/core/scripts/validate-handoff.sh` (blockers[] schema check)
- `agent-system/extensions/core/scripts/issue-record.sh` (open-enum `--class` contract)
- `agent-system/extensions/core/context/formats/issue-log.md` (Severity Scale, Seed Class Enum,
  Extensibility Rule, Occurrence Collapse, CAPTURE ONLY)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` (Filter Predicate — read
  for orientation only, not edited)
- `agent-system/extensions/core/context/standards/user-decision-contract.md` (producer-ownership
  and relay-never-resolve framing)
