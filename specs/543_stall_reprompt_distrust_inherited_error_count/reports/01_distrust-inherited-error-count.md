# Research Report: Task #543

**Task**: 543 - Tell the re-prompted dispatch to distrust the error count it inherited from the interrupting context
**Started**: 2026-11-16T18:22:00Z
**Completed**: 2026-11-16T19:05:00Z
**Effort**: low
**Dependencies**: 534 (declared in state.json; now `[COMPLETED]` — see Findings)
**Sources/Inputs**: Codebase (`orchestrate-cycle-postflight.sh`, `orchestrate-state-machine.md`, `test-orchestrate-cycle-postflight.sh`), `specs/state.json`, `specs/TODO.md`, git log
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All four remedy-emission sites named in the dispatch were located mechanically and confirmed
  verbatim: `stall_suspected` notice (script line 2374), its `recovery_declined_detail` sibling
  (line 1072), `stranded_suspected` notice (line 2414), and its `recovery_declined_detail`
  sibling (line 1074). No fifth site exists — a `grep -n "REMEDY:"` over the script returns
  exactly these four lines.
- The doc-side target (`orchestrate-state-machine.md`'s "Loop obligation" list, lines 1165-1180)
  is unmodified by any landed work and is exactly the four-item list the dispatch describes; its
  item 1 (foreground re-run) and item 2 (attribution) are present but neither states that the
  re-run's own output is the sole inventory nor that an inherited count is distrusted.
- Dependency task 534 (migrated as BimodalLogic `#770`, the record the dispatch's
  "DELIMITATION" section calls `not_started`) has since reached `[COMPLETED]` — its four phases
  landed in the same script and test file this task edits, most recently via `task 534: complete
  implementation`. The ordering concern that motivated the dependency edge no longer blocks this
  task; it narrows to "read 534's landed diff before editing the same lines," not "wait for it."
- A concrete, grep-testable wording is recommended below for all four sites plus the doc list,
  built around one shared, currently-unused phrase (`unverified and non-exhaustive`) so the
  acceptance criterion's agreement-on-substance check and the required test assertion can both
  key on it.
- Recommended asymmetry: both stall-flavoured sites and both `recovery_declined_detail` sites
  carry the addition (the latter in short form); the `stranded_suspected` *notice* is recommended
  to stay unchanged, because its own text already defers to the stall mechanism by name
  ("same mechanism as `stall_suspected`") rather than restating remedy instructions inline — so
  it inherits the addition by reference once the stall notice and the doc list carry it.

## Context & Scope

Scope is the three files already declared in this task's `file_scope` (confirmed verbatim against
`specs/state.json`): `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`, and
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`. The research
goal was to (a) mechanically re-derive the four emission sites and the doc anchor rather than
trust the dispatch's own line citations, (b) confirm the dependency task's actual landed state,
and (c) produce a concrete wording proposal that satisfies the five acceptance criteria and the
deliverable-prose constraints (no task-number references, no record-versioning language, no
originating measured counts or Lean particulars) so planning/implementation can proceed with
minimal further design work, consistent with this task's `effort: low` rating.

No web research was needed; this is a closed, self-contained prose/text edit to an existing
mechanism inside this repository.

## Findings

### Codebase Patterns

**All four emission sites, confirmed by mechanical search** (`grep -n "REMEDY:"` over the
script returns exactly these four matches, plus the two detector comment blocks that do not
themselves emit "REMEDY:" text):

1. `stall_suspected` notice — script line 2374 (inside the `stall_suspected=true` branch,
   lines 2367-2376). Ends: "...and to close every phase and write all three artifacts before
   returning. Do NOT charge this to failed_tasks without that re-prompt: the committed work is
   intact and only the wrap-up is missing."
2. Stall-flavoured `recovery_declined_detail` — script line 1072, inside the
   `rd_stall_corroborated` branch (lines 1045-1078, which also computes `rd_stall_commit_count`
   from `git log --since="@${dispatch_start_ts}"`). Ends: "...REMEDY: one re-prompt, foreground
   verification, do NOT charge to failed_tasks without that re-prompt."
3. `stranded_suspected` notice — script line 2414 (inside the `stranded_suspected=true` branch,
   lines 2410-2415). Ends: "...REMEDY: the lead routes this into the existing one-re-prompt relay
   (same mechanism as stall_suspected) -- stop this dispatch, run postflight, then issue a fresh
   dispatch at the same dispatch_seq. Do NOT charge this to failed_tasks without that re-prompt."
4. Strand-flavoured `recovery_declined_detail` — script line 1074, the `rd_strand_corroborated`
   branch of the same three-way conditional as site 2. Ends: "...REMEDY: one re-prompt at the
   same dispatch_seq, do NOT charge to failed_tasks without that re-prompt."

A third branch at line 1076 ("none found...this occurrence is not evidence of recoverable,
work-intact failure") is not a remedy-emission site — it fires only when neither corroboration
holds, so no re-prompt is being recommended there and it needs no addition.

**Structural observation relevant to where the addition should land**: sites 1 and 3 are
diagnostic `stderr` notices read by an operator/lead; sites 2 and 4 feed
`recovery_declined_detail`, which is subsequently threaded into `system-defect-record.sh
--message`, the loop-guard's `detected_defects[]` row, and `issue-record.sh --what-happened`
(lines 1092-1128). Per the doc's own "Where this actually runs" subsection, the literal text an
agent is re-prompted with is built by `skill-orchestrate/SKILL.md`'s Move 4 from the doc's
"Loop obligation" four-item list, not transcribed verbatim from these script notices — the
script notices are themselves advisory/diagnostic. `skill-orchestrate/SKILL.md` is outside this
task's `file_scope` and is not edited here; the doc list is therefore the one place whose edit
has a direct causal path to the actual re-prompt text, which is why acceptance criterion (3)
singles it out as carrying "the obligation" while the script-side criteria (1)-(2) are about
enumeration and notice-text agreement.

**Site 3's own text already defers rather than restates**: unlike the stall notice (site 1),
which spells out the four-step remedy inline ("re-run...in the FOREGROUND...and to close every
phase and write all three artifacts"), the strand notice says only "the lead routes this into
the existing one-re-prompt relay (same mechanism as `stall_suspected`)" — it names the mechanism
by reference and does not restate the instructions. Once the doc list (the actual source the
relay prompt is built from) and the stall notice both carry the addition, a reader of the strand
notice is pointed, by the notice's own wording, at a mechanism that already distrusts inherited
counts. This is the basis for the asymmetry recommendation below.

### Dependency Status (534 / migrated `#770`)

`specs/state.json` declares `"dependencies": [534]` for task 543, and `specs/TODO.md` entry
"534. postflight writes detail-free blocking issue entry on partial returns" is marked
`**Status**: [COMPLETED]`, with the migration footer confirming it is the same record the
dispatch's "DELIMITATION" section cites as BimodalLogic `#770`
(`postflight_detail_free_blocking_partial_issue_entry`). The dispatch's description text
(written before 534 landed) states `#770 ... is not_started`; the git log at the top of this
session (`807a3ff16 task 534: complete implementation`, plus four phase commits) shows it has
since completed, entirely inside `orchestrate-cycle-postflight.sh` and its test file — the same
two files this task edits. `git log --oneline --all -- .../orchestrate-state-machine.md` shows no
`task 534` commit touching that doc, so the "Loop obligation" section read above is unaffected by
534's work. Practically: the dependency is now satisfied, not merely declared; the remaining
obligation is to read 534's landed diff (the classification/dedup logic it added around the
`partial)` arm, lines ~1000-1134 per the current file) before editing the same region, so this
task's edits compose with it rather than reverting or duplicating anything.

### Test Conventions

`test-orchestrate-cycle-postflight.sh`'s `run_sut` helper (defined ~line 165) captures both
`LAST_STDOUT` and `LAST_STDERR` from each dry-run invocation. The existing `stall_suspected`
coverage (Case S1, lines ~3565-3580) already runs the exact fixture needed — a commit landing
inside the dispatch window with no outcome recovered — and currently asserts only
`jqf '.stall_suspected' = true`. Nearby stderr-content assertions elsewhere in the suite follow
the pattern `if echo "$LAST_STDERR" | grep -q "<phrase>"; then common_test_pass ...; else
common_test_fail ...; fi` (e.g. lines 243, 297, 821, 973, 1041, 1553). No existing case asserts
on the "REMEDY:" text's *content* for either notice; the acceptance criterion's requirement that
the new test exercise more than "notice is non-empty" means Case S1 needs a new, additional
assertion block checking `LAST_STDERR` for the new clause's distinctive phrase — it does not
require a new fixture, since S1's existing fixture already produces the stall notice on stderr.

A `grep` over the script and the doc confirms the phrases `unverified`, `non-exhaustive`, and
`lower bound` do not currently appear anywhere in either file (one unrelated `unverified` hit, in
a different message about phase-count markers, line 1463) — so a phrase built from them is safe
to use as a unique grep anchor for the new test assertion and will not collide with existing
text.

## Recommendations

A concrete wording, satisfying the deliverable-prose constraints (durable anchors only; no
measured counts; no Lean particulars; stated as what the resumer does) and chosen so the script
and doc agree on substance via one shared phrase:

**1. `stall_suspected` notice (script line 2374) — carries the addition, inline.** Insert a
clause between the foreground-re-run parenthetical and the artifact-closing clause:

> "...never await a harness notification), to derive its failure inventory solely from that
> re-run's own output — treating any error count or list carried over from the interrupting
> context as unverified and non-exhaustive, a lower bound at best and never a stopping condition
> — and to close every phase and write all three artifacts before returning. Do NOT charge this
> to failed_tasks without that re-prompt: the committed work is intact and only the wrap-up is
> missing."

**2. Stall-flavoured `recovery_declined_detail` (script line 1072) — carries the addition, short
form**, per the dispatch's own allowance that this site "may carry a shorter form than the
notices, provided the shorter form still says the count is not to be trusted":

> "...REMEDY: one re-prompt, foreground verification with the failure inventory derived solely
> from that re-run — any inherited count is unverified and non-exhaustive — do NOT charge to
> failed_tasks without that re-prompt."

**3. `stranded_suspected` notice (script line 2414) — recommend leaving unchanged**, and
recording why in the completion summary: this notice's own text defers to "the existing
one-re-prompt relay (same mechanism as `stall_suspected`)" rather than restating remedy steps
inline, so once the stall notice and the doc's "Loop obligation" list (the actual source of the
relayed instructions, per the doc's own "Where this actually runs" subsection) carry the
addition, this notice already points a reader at a mechanism that distrusts inherited counts.
Duplicating the full clause here would restate, not add, information, and risks the two notices
drifting out of sync with each other over time where the doc list alone would not.

**4. Strand-flavoured `recovery_declined_detail` (script line 1074) — recommend carrying the
addition too, short form**, for symmetry with site 2 rather than site 3: unlike the strand
*notice*, this site is self-contained text with no "same mechanism as..." deferral, so leaving it
silent would mean a resumer reaching this specific message sees no distrust instruction at all
(contrast the strand notice, which does point elsewhere):

> "...REMEDY: one re-prompt at the same dispatch_seq, with the failure inventory derived solely
> from that re-run — any inherited count is unverified and non-exhaustive — do NOT charge to
> failed_tasks without that re-prompt."

**5. `orchestrate-state-machine.md`'s "Loop obligation" list (lines 1165-1180) — carries the
obligation as a new item**, inserted after the existing item 1 (renumbering the existing items 2-4
to 3-5; no record-versioning language, since this is simply inserting into a live list, not
narrating a prior version of it):

> "2. Treat any error count, error list, or 'only N failures remain' claim arriving with the
> re-prompt, or recoverable from the interrupting context, as unverified and non-exhaustive — a
> lower bound at best, never a stopping condition. The re-run's own output in step 1 is the sole
> failure inventory; completion is that re-run reporting clean (or a documented exclusion), never
> agreement with an inherited count."

This keeps the doc's existing item 1 (foreground re-run instruction) and item 2 (now item 3,
attribution-to-edits-or-pre-existing-breakage) untouched in substance, so the "Loop obligation"
list's other three obligations are not disturbed.

**6. Test addition.** Extend Case S1 (around script-test line 3580, immediately after the
existing `stall_suspected (S1)` pass/fail block, reusing the same `$LAST_STDERR` already captured
by that case's `run_sut` call — no new fixture needed) with:

```bash
if echo "$LAST_STDERR" | grep -q "unverified and non-exhaustive"; then
  common_test_pass "stall_suspected (S1b): the re-prompt notice distrusts an inherited error count"
else
  common_test_fail "stall_suspected (S1b): expected the inherited-count-distrust clause on stderr, got: $LAST_STDERR"
fi
```

This satisfies acceptance criterion (4) — it asserts on the specific new clause's content, not
merely on notice non-emptiness — and requires no new test fixture since Case S1's existing
fixture already produces the stall notice.

**7. Deploy discipline.** Per the dispatch's acceptance criterion (5) and the source-store/deploy
boundary rule, edit only the three `agent-system/extensions/core/**` files above, then redeploy
(`bash .claude/scripts/deploy-headless.sh`) before declaring the task complete; the mirrored
`.claude/**` copies must never be hand-edited.

## Decisions

- Treat task 534's dependency as satisfied (it is `[COMPLETED]`), not as a blocking wait; the
  remaining obligation is to read its landed diff in the shared files before editing, per
  `.claude/CLAUDE.md`'s batching/overlap guidance, not to re-check its status repeatedly.
- Recommend the asymmetric treatment of the two `stranded_suspected`-flavoured sites: leave the
  *notice* (line 2414) unchanged with a recorded reason (acceptance criterion (2) explicitly
  permits this); extend the strand-flavoured `recovery_declined_detail` (line 1074) with the
  short-form addition, for symmetry with its stall-flavoured sibling rather than with the strand
  notice.
- Use "unverified and non-exhaustive" (plus "lower bound at best" / "never a stopping condition")
  as the shared phrase anchoring script/doc substance agreement and the new test's grep target,
  confirmed absent from both files today so it introduces no false-positive collision.
- Insert the doc's new obligation as a new item 2 (renumbering the existing three items to 3-5)
  rather than as a trailing clause appended to item 1, so the obligation reads as a distinct,
  independently-checkable instruction in the relayed prompt rather than a buried qualifier.

## Risks & Mitigations

- **Risk**: duplicating the addition into the `stranded_suspected` notice as well, producing two
  slightly different phrasings of the same remedy that could drift apart over future edits.
  **Mitigation**: the recommendation above deliberately leaves that one site unchanged and
  explains why in the completion summary, satisfying acceptance criterion (2) without
  introducing a second copy to maintain.
- **Risk**: the new test assertion colliding with unrelated existing stderr text if a generic
  phrase (e.g. "not trusted") were chosen. **Mitigation**: verified via `grep` that the chosen
  anchor phrase does not currently appear anywhere in the script or the doc.
- **Risk**: editing the same script region 534 just finished (lines ~1000-1134, the
  `recovery_declined_detail` corroboration block) without reading its landed diff first, risking
  a silent revert of 534's classification/dedup work. **Mitigation**: flagged explicitly above;
  implementation should `git show` or diff task 534's four phase commits against the current
  file before editing lines 1072/1074.

## Context Extension Recommendations

- **Topic**: cross-repo task migration leaving stale "is not_started" claims in a record's own
  description text once the cited dependency completes after migration.
- **Gap**: no existing context file documents that a migrated record's inline references to a
  sibling task's status (as plain prose, not a live field) can go stale between migration and
  implementation, and that the live `state.json`/`TODO.md` status should be re-checked rather
  than trusted from the record text — this task's own dispatch text is a concrete instance.
  `context/patterns/cross-repo-task-migration.md` documents the migration mechanics but not this
  specific staleness mode of a migrated description's prose.
- **Recommendation**: a short addendum to `context/patterns/cross-repo-task-migration.md` (or a
  cross-reference from it to `context/standards/record-version-exemptions.md`) noting that a
  migrated record's description may cite a sibling task's status as of migration time, and that
  implementers should re-derive the sibling's current status from `state.json`/`TODO.md` rather
  than the record's own prose, exactly as this report's Findings section did.

## Appendix

Search queries / commands used:
- `grep -n "STALL SUSPECTED\|STRAND SUSPECTED\|stall_suspected\|stranded_suspected\|recovery_declined_detail\|REMEDY" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `grep -n "Abandoned Wrap-Up\|Loop obligation" agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `grep -n "STALL SUSPECTED\|stall_suspected\|STRAND SUSPECTED\|stranded_suspected\|REMEDY" agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `grep -n "LAST_STDERR\|^run_sut()" agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `grep -n "unverified\|non-exhaustive\|lower bound" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `python3 -c "..."` reads of `specs/state.json` for task 543's dependency field and task 534's
  completed status
- `git log --oneline --all -- agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `git log --oneline --all --grep="^task 534"`

References: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (lines
1045-1078, 2328-2415, 2489-2520); `agent-system/extensions/core/docs/architecture/
orchestrate-state-machine.md` (lines 1121-1246); `agent-system/extensions/core/scripts/tests/
test-orchestrate-cycle-postflight.sh` (lines 165-180, 3544-3641); `specs/state.json` (task 543
and task 534 records); `specs/TODO.md` (task 534 entry, line 5805).
