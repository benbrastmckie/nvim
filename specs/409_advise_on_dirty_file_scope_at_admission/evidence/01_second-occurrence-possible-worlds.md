# Second Measured Occurrence: Dirty file_scope Swept by a Concurrent Session

Recorded from an `/orchestrate` run in `~/Philosophy/Papers/PossibleWorlds`
(session `sess_1792017749_2aa886`, task 172, three cycles: research, plan, implement).
This is an independent second occurrence of the behaviour this task's own OBSERVED
section describes, on the **same file** and involving the **same sibling session**.

## Why it corroborates rather than repeats

This task's OBSERVED section records session `sess_1792011444_1dfb46` (task 173,
implement dispatch 3) sweeping a one-line `cor:saturation-finite` edit into a task
commit on `JPL/possible_worlds.tex`. The run below is a *different* task in the
*same* repository, whose dispatch overlapped that same session's tail — so the
hazard is now measured twice on one file, from both sides of the collision.

## What was observed

1. **Dirty file_scope at every dispatch boundary, growing between them.** The user's
   uncommitted diff on `JPL/possible_worlds.tex` measured 3+/2- at research, 5+/4-
   across three hunks (lines 1947-2010) at plan, and four hunks (lines 1947-2088:
   Appendix intro, `def:id` prose, language description, O-Cons gloss) at
   implementation start. None of the hunks lay at the task's own edit sites. Nothing
   warned before any of the three dispatches.

2. **The pre-dispatch review did not surface it.** `orchestrate-predispatch-review.sh`
   ran with all eight classes reporting, and the only finding on this task was
   Class F/H (`file_scope` is `missing_key`) — an absent-scope advisory, not a
   dirty-scope one. The task carried no `file_scope` at admission; it was widened to
   `JPL/possible_worlds.tex` only later, by the research phase's own postflight
   (`--file-scope-add`). So at the moment the advisory this task proposes would have
   been most useful, the task's declared scope was empty, and the dirty path became
   known to the engine only after the first dispatch had already completed.

   **Design consequence for this task:** an advisory that intersects the dirty
   worktree with `file_scope` alone is silent in exactly this case. The intersection
   needs a fallback for an absent/empty `file_scope` — for instance intersecting
   against the dirty set itself and naming it as unscoped, which the existing
   `absent_scope_advisory` already detects independently at the same admission point.

3. **A concurrent session swept this dispatch's own hunks.** Commit `dd49eb3d`
   (task 173, session `sess_1792011444_1dfb46`, its late wrap-up) landed between this
   dispatch's Phase 5 and Phase 6 commits and absorbed two of this dispatch's
   then-uncommitted hunks: a proof-level review comment in `JPL/possible_worlds.tex`
   and 24 lines of plan edits. Its own `.tex` edits were confined to the
   `def:strongest` region (lines 2240-2337), so the sweep was purely a whole-file
   staging artifact, not an overlapping edit. HEAD was re-verified clean afterwards
   and nothing was lost; only the provenance of the two hunks is misattributed. No
   history rewrite was attempted.

   This is the mirror image of the OBSERVED case: there, a dispatch swept the user's
   hunk; here, a dispatch swept *another dispatch's* hunk. Both reduce to whole-file
   staging with no containment check, which is the companion task
   `394_file_scope_containment_chokepoint_for_scoped_commit` rather than this one.

4. **The workaround held, and cost a decision.** The plan anticipated the dirty tree
   and made a separate labelled carry commit (`4e00e00c`) of the user's four hunks
   after the baseline build passed and before any task edit, so all eight task
   commits on the paper stayed pure. Reaching that required a `user_decision` relayed
   at plan postflight; because it was marked non-blocking, the loop resolved it on the
   agent's own recommendation rather than asking the operator. An admission-time
   advisory would have put the same information in front of the operator one dispatch
   earlier, when committing the hunk separately was still free.

## Source citations

Issue-log entries in
`~/Philosophy/Papers/PossibleWorlds/specs/172_align_paper_logics_with_minimal_lean_axiom_sets/issues.jsonl`:

| entry_id | class | What it records |
|----------|-------|-----------------|
| `iss_1792018723670_HO4te5` | territory | Live edits during research; a commit landed mid-session and a further hunk appeared after it |
| `iss_1792019049980_FgonSM` | territory | Dirty diff grew 3+/2- to 5+/4- between the research and plan dispatches |
| `iss_1792019929786_657Zoi` | territory | Four user hunks present at implementation start; carry-commit decision recorded |
| `iss_1792021816254_Mamvl5` | territory | Foreign commit `dd49eb3d` swept two of this dispatch's uncommitted hunks |

All four are severity `minor`, `resolution` null (implicit open).
