# sf1-engine acceptance render: judgment

Inputs (read only, nothing written to that repository): `/home/benjamin/Projects/Sapience/sf1-engine`
`specs/state.json`, `specs/archive/state.json`, `specs/ROADMAP.md`, and `integration/design.md`
section 7 (branch `docs/repo-documentation`, read 2026-11-20).

How the copy was built:

1. `sf1-acceptance-store.json` is a copy of that store; the migration ran against a copy of
   its live roadmap (the copy became the generated file); `archive/state.json` is a copy of its archive (the renderer reads the archive
   beside the `--state` file).
2. The deployed `migrate-roadmap-to-milestones.sh` was run on the copy for real. Its accounting:
   classic layout; 7 flat batches -> 7 under `M1`; `primary_goals` +1, `rules` +10,
   `conventions` +9; 10 file lines and 19 `roadmap_notes` lines retained in
   `sf1-acceptance-retained-prose.md`; losslessness gate PASSED (30 source lines = 10 retained +
   20 in state). No item was over its bound.
3. `sf1-milestone-overlay.jq` replaced the single neutral milestone with M0 to M4. Titles, aims
   and gate text are from design.md 7.1 to 7.5. M0 is `closed` (2026-11-15, the date of the
   roadmap commit that first states "M0 is closed"). Batch assignment: the first four batches
   (instrument trust, inverse translator, dev shell, the M1 gate) under M1; the loader batch
   under M2; the guard-plus-port batch and the design.md write-back batch under M3; M4 none.
   This follows the research report's overlay. The M1 gate text omits design.md's sentence about
   hook time being measured and reported, because the `gate` field holds the criterion and that
   sentence says it does not by itself fail the gate.
4. `validate-state.sh` on the copy: Check 13 PASS, 0 failed. Rendered with
   `roadmap-integration.sh --regenerate --state ... --roadmap ...` into
   `sf1-acceptance-ROADMAP.md`; a second run reports `no content change`.

## Size

| | Lines | Bytes |
|---|---|---|
| Live hand-authored file | 188 | 41,618 |
| Generated file | 147 | 9,133 |

The generated file is 22% of the live one by bytes. Almost all of the difference is the
"Why this order" prose and the lead-in paragraphs of `## Next`, which now sit in the retained
file (19 `roadmap_notes` strings) and in each batch's unrendered `rationale`.

## Is status, progress and review state for every milestone visible in the first screen?

Yes. Lines 1 to 13 hold the goal and a five-row table: M0 closed 2026-11-15; M1 active, 1/6;
M2 planned, 0/1; M3 planned, 0/3; M4 planned; each with its review state and a link to its
section. A reviewer does not need to scroll to learn which milestone is live.

Two qualifications:

- The single goal is one 400-character line, so on a narrow terminal the table starts several
  wrapped lines down. It fits the 500 bound; it is still long for an intro bullet.
- Every review cell reads `none`. That is accurate (the store records no review state) but it
  means the review column carries no information in this render. Nothing in the system writes
  `review` today except a `/roadmap` judgment pass or a hand edit through `state-write.sh`.

## Does any milestone read empty while holding real work?

Yes: M4. It renders `planned -- no batches yet` and `-` in the table, while task 13
(`fit_task_workflow_to_sf1_memory`, the whole of M4) exists, on hold. Tasks 20 and 37 (design
item 1.12, dispatch memory) and task 19 (the held host-plugin half that blocks the M1 gate) are
likewise visible only in `### Open tasks in no batch` at the bottom, with no milestone named.

The cause is structural, not a rendering slip: a task belongs to a milestone only by being in
one of its batches, and a batch is a dispatch proposal. A held task that must never be
dispatched from this repository has no way to be attributed to a milestone without also being
proposed for dispatch. M0 shows the same thing from the other side: it is closed with `-` tasks
because its work predates the batch list.

## What a reviewer still cannot see

- **Which milestone an unbatched task belongs to** (above). This is the one gap that makes a
  milestone's progress figure misleading: M1 reads 1/6 while its gate is blocked by task 19,
  which is not counted in M1 at all; the only trace is the token `blocked:19,40` on task 10.
- **Review state**, until someone records it. The dashboard shows the field; no workflow fills it.
- **The dependency shape between milestones.** Order is array order. design.md's
  "M4 needs only M1 and can run beside M2 and M3" survives only as a clause in M4's aim.
- **Why the batches are in this order.** Deliberately not rendered; it is in state (`rationale`)
  and in the retained file. A reviewer who wants it has to open one of those.
- **What is dispatchable now**, as a sentence. The tokens carry it (batch 1 holds the only
  member not blocked on another task), but the live file's plain statement of it is gone.
- **M0's evidence.** A closed milestone is one line; the probe results stay in design.md 7.1.

Smaller observations:

- 40 of 147 lines are wider than 100 columns: bounded prose items (a goal, gates, rules,
  conventions) and member lines. The 100-column cut applies to a member's title only; a
  `roadmap_annotation` suffix is appended after it uncut, and this store's annotations run to
  about 130 characters.
- Member titles here are slugs (`m1_gate_task_workflow_end_to_end`) because most entries in this
  store carry no `title`. That is the store's content, not the renderer's.
- A batch shows `(1/3 done)` while its milestone shows `0/4 batches`; both are right, and the
  pair reads oddly at first.

## Judgment

The output serves a reviewer for the question it was built for: what state are the next
milestones in. That answer is on the first screen, the per-milestone gate text is the criterion
from the design document, and the file is a fifth of the size with nothing discarded.

It does not yet serve as a complete collaboration dashboard, for two reasons that are both
visible in this render rather than hypothetical: the review column is empty because nothing
populates it, and work that is held or owned elsewhere cannot be shown under the milestone it
belongs to, so M4 looks unstarted and unplanned when it is neither, and M1's count leaves out
the task blocking its gate. Both are follow-up design questions (a milestone-level list of
member tasks that are not dispatch proposals; a writer for `review`), not defects in what was
specified.
