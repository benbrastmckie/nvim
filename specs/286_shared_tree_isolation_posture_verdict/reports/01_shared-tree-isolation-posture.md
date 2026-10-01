# Research Report: Task #286

**Task**: 286 - Shared-tree isolation posture verdict (rewrite the split verdict to a blanket verdict)
**Started**: 2026-09-30T00:00:00Z
**Completed**: 2026-09-30T00:00:00Z
**Effort**: Small (documentation-only, one section of one file)
**Dependencies**: None (decision record already closed; this task transcribes it)
**Sources/Inputs**: Codebase (target file, decision record, orchestrate-cycle-plan.sh), no web search needed
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The edit target is confirmed and singular: the `## Working-Tree and Build Isolation Posture`
  section of `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
  currently lines 1382–1533 (file is 1571 lines total). This is the source store, not
  `.claude/**` — already correctly named in the dispatch.
- The ground-truth verdict is fully recorded in `specs/decisions/worktree-isolation-removal-verdict.md`.
  No scoring or fact-finding remains to be done; this report maps that record onto exact surviving
  passages, exact new passages, and the one acceptance criterion the dispatch's "WHAT CHANGES"
  prose does not spell out in the same place as the rest: the `## Related Documents` entry (line
  1538–1542) currently names `dispatch-worktree.sh` as the *live* implementation of the posture
  this section states, and that framing must change even though the script itself is untouched.
- Two passages inside the current section are not named in the dispatch's survive/add lists at all
  — `### A Corrected Rationale for Hardlink-Over-Symlink` (1486–1509) and the second
  `### Deliberate Divergences` bullet on the PATH-shim wrapper (1527–1532) — and both need an
  explicit disposition call in the plan, documented below as open recommendations rather than
  silently resolved by this report.
- No other section of this file, and no other file's prose (only script *comments*, which this
  task does not touch), references the split verdict or its selection predicate — the blast radius
  is exactly the one section plus the one Related Documents bullet.

## Context & Scope

This is a documentation-only transcription task. `specs/decisions/worktree-isolation-removal-verdict.md`
already made and recorded the ruling; this task's job is to fold that ruling into the pattern
file's own section without re-deriving anything and without touching any script, test, or the
`dispatch-worktree.sh` layer itself (that removal is sequenced after a separate build-heavy
co-scheduling admission-rule task, per the decision record's Task Disposition table).

Scope boundaries confirmed by direct inspection:

- `agent-system/extensions/core/scripts/dispatch-worktree.sh` still exists, still implements
  `provision`/`path`/`release`/`prune`/`land`, and its own header still describes the (now
  superseded) split verdict. This task does not touch it.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` still carries the live
  `WORKTREE_ISOLATED_TASK_TYPES=("lean4" "cslib")` selection array and
  `task_selected_for_worktree_isolation()` (also referenced from
  `agent-system/extensions/core/scripts/tests/test-dispatch-isolation-fixture.sh`). This task does
  not unwire any of it. The decision record's "repurposed from 'isolate this' to 'do not
  co-schedule this'" language describes what the *separate*, not-yet-built build-heavy
  co-scheduling admission rule does with this same task-type list — not something this
  documentation-only task implements.
- No other prose file references the split verdict or selection predicate; only script
  *comments* in `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, and
  `test-orchestrate-cycle-plan.sh` cite "Working-Tree and Build Isolation Posture" / "split
  verdict" by name. Those are out of scope (they belong to the removal task) and this report
  flags them only so the implementer doesn't go looking for more prose to update.

## Findings

### Codebase Patterns

**Current section anatomy** (`batch-orchestration-guardrails.md:1382-1533`), by subsection and
disposition under the new verdict:

| Subsection | Lines | Disposition |
|---|---|---|
| Intro paragraph framing a "split verdict" question | 1382–1388 | Rewrite: no longer a question with two answers: state the blanket verdict up front |
| `### The Three Failure Modes` | 1389–1412 | **Survives verbatim** — taxonomy, not verdict |
| `### Why Mode 1b Is the Decisive Evidence` | 1413–1424 | **Survives verbatim** — reasoning, not verdict |
| `### Scoring Table` | 1426–1439 | **Survives, reframed as history** (keep the table; add framing sentence that it produced the now-superseded split verdict) |
| `### The Split Verdict and Its Selection Predicate` | 1441–1458 | **Replaced** by the blanket verdict + no-selection-predicate statement, the three-defect record, and the structural argument |
| `### Measurements That Informed the Verdict` | 1460–1484 | **Survives verbatim**, with a short added lead-in tying it explicitly to "cost was not the reason" |
| `### A Corrected Rationale for Hardlink-Over-Symlink` | 1486–1509 | **Not named by the dispatch either way** — see Decisions/Recommendations below |
| `### Deliberate Divergences`, bullet 1 (script-provisioned vs. harness-level) | 1513–1526 | **Survives, marked historical** per explicit dispatch instruction |
| `### Deliberate Divergences`, bullet 2 (PATH-shim) | 1527–1532 | **Not named by the dispatch either way**, but its content is also explicitly required to appear in the new Mode 2 section — see Decisions below (duplication risk) |
| `## Related Documents`, first bullet | 1538–1542 | **Must change** — currently presents `dispatch-worktree.sh` as the live implementation of this section's (soon-to-be-former) selection; acceptance criterion explicitly requires it stop doing that |

**Mode 2 mechanism pointer target**: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
has a documented header block (lines ~1979–1985) that already names
`WORKTREE_ISOLATED_TASK_TYPES=("lean4" "cslib")` as "the two REAL task_type string values that
family covers." The decision record's mode 2 ruling says this same array is "repurposed from
'isolate this' to 'do not co-schedule this'" by a *separate, not-yet-built* admission rule. The
dispatch for this task says the pointer added to `## Related Documents` should name
`orchestrate-cycle-plan.sh`'s own header as where that mechanism will live — it is a forward
pointer to an intended location, not a claim that the predicate is implemented there today. The
plan/implementation phase should word the pointer so it is true now (a stated intent on record)
without claiming a predicate exists before the admission-rule task lands.

### External Resources

None consulted — this is a closed-ruling transcription task entirely internal to this repository.
`specs/decisions/worktree-isolation-removal-verdict.md` is the sole authoritative source and was
read in full; see Context & Scope above for the confirmed facts extracted from it.

## Decisions

Explicit calls made during research, to remove ambiguity before planning:

1. **Replacement boundary**: the rewritten section runs from the `## Working-Tree and Build
   Isolation Posture` heading (line 1382) through the end of `### Deliberate Divergences` (line
   1533), immediately followed by the existing `## Related Documents` heading (1534) — i.e. the
   section-level boundary is unchanged; only its internal subsections change.
2. **`### Scoring Table` reframing**: keep the four-row table verbatim; add one lead sentence
   identifying it as the historical comparison that produced the now-superseded split verdict,
   per the dispatch's explicit "re-framed as history rather than deleted" instruction.
3. **`### A Corrected Rationale for Hardlink-Over-Symlink` (not named by the dispatch)**:
   recommend marking it historical with the same one-line treatment as the first Deliberate
   Divergences bullet, rather than deleting it. Rationale: it is reasoning about
   `dispatch-worktree.sh`'s own internal implementation choice (hardlink vs. symlink), and that
   script is not deleted by this task — the same "may be cited again" logic the dispatch applies
   to the specs/-staleness argument applies here. This is a recommendation for the plan phase to
   confirm, not a silently-resolved fact, because the dispatch text does not mention this
   subsection at all.
4. **`### Deliberate Divergences`, PATH-shim bullet (not named by the dispatch)**: the dispatch's
   "WHAT MUST BE ADDED" list requires the PATH-shim decline and its residual to appear in the new
   Mode 2 section. The existing second Deliberate Divergences bullet already states exactly this.
   Recommend merging it into the new Mode 2 section (stated once, where the dispatch asks for it)
   and dropping the now-duplicate standalone bullet, since by definition it is a decision made
   regardless of which isolation option is live, not a "divergence from Option 2" entailed by the
   worktree choice. Flagging as a recommendation, not a hard requirement, since the dispatch is
   silent on this specific bullet's fate and either placement satisfies the literal acceptance
   criteria.
5. **`## Related Documents` first bullet rewrite**: must stop presenting the
   provisioning/land/release lifecycle as the implementation this document currently selects.
   Recommend: state plainly that the posture above is now blanket shared-tree; that the
   `dispatch-worktree.sh` lifecycle implemented the now-superseded split verdict and remains in
   the tree pending a separately-sequenced removal task (so a reader who greps for it is not
   confused into thinking it vanished or is dead code with no explanation); and that the mode-1b
   contended-path refusal (`git-commit-scoped.sh`) and staging qualification
   (`context/standards/git-staging-scope.md`) citations are unchanged, since those mechanisms are
   unaffected by the isolation-posture change. Add the new pointer to
   `orchestrate-cycle-plan.sh`'s header for the mode 2 admission-rule mechanism in the same
   bullet or an adjacent one.
6. **No other file in this repository needs updating for this task.** Script comments in
   `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, and
   `test-orchestrate-cycle-plan.sh` that cite the split verdict by name are explicitly out of
   scope (they belong to the removal task), confirmed via repo-wide grep.

## Recommendations

- Implement the section rewrite exactly per the dispatch's WHAT-CHANGES / WHAT-MUST-SURVIVE /
  WHAT-MUST-BE-ADDED / WHAT-THIS-TASK-MUST-NOT-DO contract, using the subsection-by-subsection
  disposition table under Findings above as the direct work order.
  Draft structure for the implementer:
  1. Intro paragraph — state the blanket verdict and the no-selection-predicate rule directly
     (replaces the current "split verdict... scored below" framing).
  2. `### The Three Failure Modes` — unchanged.
  3. `### Why Mode 1b Is the Decisive Evidence` — unchanged.
  4. New subsection stating the verdict itself (shared tree, no predicate; concurrency safety
     rests on `file_scope`, dependency edges, and the five contention inputs) — replaces `### The
     Split Verdict and Its Selection Predicate`.
  5. New subsection: "Cost Was Not the Reason" — explicit disclaimer, citing the measurements
     block by name (not restating the numbers twice).
  6. New subsection: the three-defect record (table format mirrors the decision record's own
     table: destructive release on `nothing_to_land`; `git-commit-scoped.sh` false success inside
     a worktree; `lake-build-guard.sh` false green via the `cp -al` inode share), plus "no defect
     of any other origin was ever recorded against that dispatch path."
  7. New subsection: the structural argument (atomic-rename rebindability is per-writer, not
     per-clone; a truncate-in-place writer never gets it; the exclusion list is a hand-maintained
     enumeration; a layer whose correctness depends on unrelated scripts' ongoing discipline
     cannot be audited once and trusted).
  8. New subsection: Mode 2 ruling as a principle only — never co-schedule two build-heavy
     implement tasks in one cycle; mechanism pointer to `orchestrate-cycle-plan.sh`'s header, not
     restated here; the PATH-shim wrapper named and declined, with its residual stated (merging in
     the former second Deliberate-Divergences bullet's content per Decision 4 above).
  9. `### Scoring Table` — kept, reframed as history (Decision 2).
  10. `### Measurements That Informed the Verdict` — kept verbatim, with the added lead-in tying
      it to "cost was not the reason" (Decision 2/5 territory — a cross-reference, not a
      restatement).
  11. `### A Corrected Rationale for Hardlink-Over-Symlink` — kept, marked historical (Decision 3).
  12. `### Deliberate Divergences` — first bullet kept, marked historical, exactly as the dispatch
      requires; second bullet dropped or kept short-form per Decision 4 (plan phase's call).
- Update the `## Related Documents` first bullet per Decision 5. Confirm no other bullet in that
  list needs touching — `git-staging-scope.md`, `task-lock.md`, `file-footprint-overlap.md`, and
  the others are all mechanisms unaffected by the isolation-posture change.
- Run the no-task-reference-in-deliverables check against the edited file before closing out the
  implementation phase (the file is outside `specs/**`, so the rule applies in full); nothing in
  the proposed content above introduces a task-number citation.
- No script, test, or `dispatch-worktree.sh` edit belongs to this task — confirm the diff touches
  exactly one file (`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`)
  before marking the implementation phase complete.

## Risks & Mitigations

- **Risk**: silently dropping the two dispatch-silent passages (`A Corrected Rationale for
  Hardlink-Over-Symlink`, the PATH-shim Deliberate-Divergences bullet) instead of making an
  explicit call. **Mitigation**: Decisions 3 and 4 above make the call and state the rationale, so
  the plan phase inherits a reasoned default rather than an ambiguity, while still being free to
  override either call since the dispatch text itself did not constrain them.
- **Risk**: the `orchestrate-cycle-plan.sh` pointer added to `## Related Documents` could be
  misread as a claim that the build-heavy co-scheduling predicate already exists. **Mitigation**:
  Decision 5 above specifies this should read as a stated intent/pointer-to-future-home, not a
  claim of present implementation, since the admission-rule task is sequenced but not yet built.
- **Risk**: scope creep into the script comments (`orchestrate-cycle-plan.sh`,
  `orchestrate-cycle-postflight.sh`, `test-orchestrate-cycle-plan.sh`) that also mention the split
  verdict. **Mitigation**: explicitly out of scope per the dispatch's WHAT-THIS-TASK-MUST-NOT-DO
  clause (no unwiring of callers); confirmed via grep that no other *prose* file needs changes
  (Findings above).

## Context Extension Recommendations

None — task_type is `meta` and this is a self-contained documentation transcription against an
already-closed decision record; no new context-file gap was discovered.

## Appendix

- Files read in full: `specs/decisions/worktree-isolation-removal-verdict.md`,
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (target
  section, lines 1382–1571, plus header lines 1–11).
- Searches run: `grep -n "^#"` against the target file for section map; `grep -rn
  "Working-Tree and Build Isolation Posture\|split verdict"` repo-wide for cross-reference audit;
  `grep -n "lean4.*cslib"` against `orchestrate-cycle-plan.sh` and
  `orchestrate-batch-admit.sh` for the mode-2 mechanism's current/future home;
  `grep -rln "task_selected_for_worktree_isolation"` repo-wide to confirm the selection predicate
  is live only in `orchestrate-cycle-plan.sh` and its own test fixture.
- `.claude-extensions.json` consulted to confirm the dispatch's named edit path already is the
  source-store path (no `source_dir` indirection needed for this file).
