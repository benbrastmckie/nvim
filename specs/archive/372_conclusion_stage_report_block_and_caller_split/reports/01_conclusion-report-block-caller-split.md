# Research Report: Conclusion stage report block and roadmap-generator caller split

**Task**: 372 - Add the conclusion stage missing report block and name its roadmap-generator caller
**Started**: 2026-10-10T00:19:00Z
**Completed**: 2026-10-10T00:30:00Z
**Effort**: small
**Dependencies**: None (parallel-eligible with task 371; no dependencies[] edge)
**Sources/Inputs**: Codebase (agent-system/extensions/core/context/**, specs/TODO.md, git history)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **GAP 1 is already closed and requires no code/doc change.** The `### Conclusion` report
  block already exists in `orchestrate-batch-results-template.md` (added by commit `4e70e2239`,
  "task 273 phase 8", landed 2026-10-08, the same day as the originating `/orchestrate 739,740`
  run that discovered the gap). It covers all five items the task description enumerates. The
  source-store and deployed `.claude/` copies are byte-identical, so this is already deployed
  too. This task's work on GAP 1 is verification, not authorship.
- **GAP 2 is real and has two distinct parts, both still open.** (a) `roadmap-update.md` does
  not name the conclusion stage as a caller of `--regenerate`, even though
  `conclusion-stage.md`'s Step 5 already invokes it in production. (b) Neither `/todo` nor
  `/review` actually wires either generator mode to its own command — a pre-existing gap,
  independently confirmed still true by grepping both callers' own files.
- **A third, previously unnoticed inaccuracy**: `roadmap-update.md`'s own "No Live Caller Yet"
  section header and lead sentence are currently false, independent of today's task — the
  conclusion stage's Step 5 already calls `--regenerate` live, so `--regenerate` is NOT
  caller-less. Only `--prune` is. This needs correcting as part of closing GAP 2(a).
- **Recommended ruling for GAP 2(b)**: do not wire `/todo`/`/review` to the generator's other
  modes in this task. Record the ruling explicitly in `roadmap-update.md` instead of leaving it
  as a bare observation, per the task's own "do not wire a mode into a command merely to make a
  table symmetric" instruction.
- Discharging `conclusion-stage.md`'s "Two Flags For the User, Not Silent Edits" section means
  replacing its forward-looking "flagged, not resolved" framing with a short, current-state
  pointer into `roadmap-update.md`, and removing the now-vestigial "carry forward the two flags"
  instructions from Step 5 and the template's `{roadmap_flags}` placeholder.

## Context & Scope

Two independent documentation/contract gaps in `/orchestrate`'s conclusion stage (Move 5), both
surfaced by a real `/orchestrate 739,740 --lit --fable` run on 2026-10-08 in a sibling
repository. Neither requires `roadmap-integration.sh` itself to change (that is task 371's
scope, which touches a different file — the script — not `roadmap-update.md`, so there is no
file-level collision between the two parallel tasks).

File scope (set here, per the dispatch's "FILE SCOPE IS DELIBERATELY ABSENT" instruction):
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
- `agent-system/extensions/core/context/patterns/roadmap-update.md`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`

No other file needs editing. `scripts/roadmap-integration.sh`,
`scripts/git-commit-scoped.sh`, and the conclusion stage's channel/approval-ledger mechanics are
explicitly out of scope and untouched by every recommendation below.

## Findings

### Codebase Patterns

**GAP 1 — already resolved, verification only.**

`agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md:161-191`
already contains a `### Conclusion` subsection, rendered once per invocation from Move 5. Cross-
checking it against the task description's five enumerated items:

| Item | Present in current template? |
|------|-------------------------------|
| (i) wins summary | Yes — `**Wins**: {wins_summary}` |
| (ii) each channel's outcome + citations | Yes — `**Channel (a/b/c)**: {channel_X_outcome}` lines, each noting citations when approved |
| (iii) unknown-class tally | Yes — `**Unknown-class tally**: {unknown_classes_table}` |
| (iv) zero-contribution dispatch list | Yes — `**Zero-contribution dispatches**: {no_contribution_tasks_list}` |
| (v) two roadmap flags carried from Step 5 | Yes — `**Roadmap**: regenerated ...; {roadmap_flags}` |

`conclusion-stage.md`'s Step 6 pointer ("Render per
`context/patterns/orchestrate-batch-results-template.md`'s conclusion report block") already
resolves correctly to this block. `diff` between the source-store copy and the deployed
`.claude/` copy is empty — the fix is already live, not merely committed.

`git log` shows the block was added by commit `4e70e2239` ("task 273 phase 8: architecture and
command documentation", 2026-10-08 13:21:56 -0700), which bumped the template's own subsection
count comment from "ten" to "eleven". Backlog reconciliation in the task description already
identifies task 273 as "built the conclusion stage whose Step 5/Step 6 are defective here" — but
that same task's later phase (8) is what closed the defect, apparently on the same day the
originating run found it. The exact ordering (whether the `739,740` run predates or postdates
`13:21:56` that day) does not change the actionable conclusion: as of the current repository
state, the gap does not exist. No edit to the template is needed for GAP 1.

**GAP 2(a) — confirmed real.** `roadmap-update.md`'s "## Responsibility Split" section
(lines 10-19) describes `--regenerate` only as "the `/review`-shaped operation" and never
mentions the conclusion stage, even though `conclusion-stage.md`'s own executable Step 5
(lines 339-345) already invokes `bash .claude/scripts/roadmap-integration.sh --regenerate` in
production. The caller-split documentation is stale relative to the already-implemented stage
body.

**GAP 2(b) — confirmed still open.** Grepped both candidate caller files directly:
`skills/skill-todo/SKILL.md` and `commands/review.md` contain zero references to
`roadmap-integration.sh`. `roadmap-update.md`'s own "## No Live Caller Yet" section (lines
94-103) already states this and recommends filing a wiring follow-up, but stops short of a
decision — it only observes the gap, which is why the task's "DECIDE AND RECORD" instruction
still applies.

**A third finding, not named in the task description**: the "## No Live Caller Yet" header and
its opening sentence ("`roadmap-integration.sh` has no live caller: neither `/todo`'s skill ...
nor `/review` ... invokes either mode") are **currently false**, independently of anything this
task does. `conclusion-stage.md`'s Step 5 is already-implemented production code that calls
`--regenerate` on every `/orchestrate` invocation reaching Move 5. So `--regenerate` already has
exactly one live caller (the conclusion stage); only `--prune` remains caller-less. Fixing GAP
2(a) without also correcting this header would leave a direct contradiction in the same file:
one section naming the conclusion stage as a caller, a few lines later another section claiming
no live caller exists at all.

### External Resources

Not applicable — this is a pure documentation/contract-consistency task scoped entirely to three
files already read in full above; no external library or API is involved.

## Decisions

1. **GAP 1: verification only, no edit.** Do not re-add or restructure the `### Conclusion`
   block in `orchestrate-batch-results-template.md`. The plan/implementation phase should record
   this as a verified-closed item (e.g. a diff/grep check reproduced in the plan or summary),
   not re-author content that already satisfies the acceptance criterion.

2. **GAP 2(a): add the conclusion stage as a named caller.** Add a sentence to
   `roadmap-update.md`'s "## Responsibility Split" section, under the existing `--regenerate`
   bullet, naming `/orchestrate`'s conclusion stage (Move 5, Step 5) as a caller alongside
   `/review`, with a cross-reference to `context/contracts/conclusion-stage.md`'s Step 5. This
   is the uncontroversial, factual half the task description names.

3. **Correct the stale "No Live Caller Yet" section as part of the same edit.** Since fixing
   GAP 2(a) without touching this section would leave an internal contradiction (see Findings
   above), rewrite its header/lead sentence to reflect the actual split: `--regenerate` has
   exactly one live caller today (the conclusion stage); `--prune` has none. This is not scope
   creep — it is the same file, the same section family, and leaving it unedited would make the
   file self-contradictory the moment GAP 2(a)'s sentence is added next to it.

4. **GAP 2(b): closed by a recorded ruling, not by wiring.** Do not wire `/todo` to `--prune` or
   `/review` to `--regenerate` in this task. Rationale: (i) the task's own instruction is
   explicit — "do not wire a mode into a command merely to make a table symmetric"; (ii) this
   task's goal is narrowly a documentation/contract fix to the conclusion stage, not feature
   work on two unrelated commands; (iii) wiring either command is real behavior-changing work
   deserving its own research/plan, not a byproduct of a "small"-effort documentation task.
   Record the ruling explicitly in `roadmap-update.md`'s (corrected) "No Live Caller Yet"
   section: state plainly that the wiring gap is acknowledged and deliberately left open, and
   that a follow-up may be filed separately via `/task` or `/spawn` if and when a concrete
   operational need arises — not automatically by this task.

5. **Discharge `conclusion-stage.md`'s "Two Flags For the User, Not Silent Edits" section.**
   Replace its content (framed around two *unresolved* flags) with a short, current-state
   pointer: the caller split is documented in `roadmap-update.md` (cross-reference), and the
   `/todo`/`/review` wiring question is closed by the ruling recorded in that same file's "No
   Live Caller Yet" section. State this as the current design, not as a history of what used to
   be flagged (per `rules/no-record-versioning-in-deliverables.md`).

6. **Remove the now-vestigial "carry forward the two flags" instructions.** Once both flags are
   discharged per Decision 5, there is nothing live left for Step 5 to "carry forward" into
   Step 6, and nothing for the template's `{roadmap_flags}` placeholder to render. Edit:
   - `conclusion-stage.md` Step 5: drop the sentence "Carry forward, into Step 6's report, the
     two flags this stage's design surfaced ...".
   - `conclusion-stage.md` Step 6: drop "...and the two roadmap flags carried from Step 5" from
     the enumerated report contents.
   - `orchestrate-batch-results-template.md`'s `### Conclusion` block: simplify the `**Roadmap**`
     line to `**Roadmap**: regenerated (\`specs/ROADMAP.md\`).` — dropping the
     `{roadmap_flags}` placeholder and its explanatory clause, since both flags it referred to
     no longer exist as open items. If a future design surfaces a genuinely new flag, that is a
     fresh contract amendment at that time, not a reason to keep this placeholder live now.

## Recommendations

- Sequence the plan as: (1) verify GAP 1 is closed (no edit — a one-line check reproduced in the
  plan/summary is sufficient evidence); (2) edit `roadmap-update.md` for GAP 2(a) + the stale
  "No Live Caller Yet" correction + the GAP 2(b) ruling, in one pass since all three live in the
  same small file and are textually adjacent; (3) edit `conclusion-stage.md` to discharge the
  "Two Flags" section and drop the vestigial carry-forward instructions in Step 5/Step 6;
  (4) edit `orchestrate-batch-results-template.md`'s `**Roadmap**` line to match.
- Keep the acceptance criterion "the `/todo`//`review` unwired-mode question is ... closed by a
  recorded ruling" satisfied by Decision 4's explicit ruling text — do not let it stay an
  observation-only sentence, which is what currently exists and does not meet the "DECIDE"
  half of the instruction.
- Do not touch `agent-system/extensions/core/scripts/roadmap-integration.sh`,
  `skills/skill-todo/SKILL.md`, or `commands/review.md` — confirmed out of scope and consistent
  with task 371 owning the script and nobody owning a wiring change in this task.
- No dependency edge is needed against task 371: the two tasks' file scopes do not overlap
  (`roadmap-integration.sh` vs. `roadmap-update.md`/`conclusion-stage.md`/the results template).

## Risks & Mitigations

- **Risk**: removing the `{roadmap_flags}` placeholder from the template could be read as
  silently dropping observability the conclusion stage's design valued. **Mitigation**: the
  placeholder only ever referred to these two specific, now-discharged flags — it was never a
  generic "any future flag goes here" slot. The decisions section above states this explicitly
  so the plan/implementation phase does not need to re-derive it, and a future genuinely new
  flag gets its own contract amendment rather than reusing stale machinery.
- **Risk**: a reader might wonder why GAP 1's acceptance criterion ("the conclusion report block
  exists ... and Step 6's pointer resolves to it") is satisfied without any diff appearing in
  this task's own commit. **Mitigation**: the plan/summary should state verification explicitly
  (point at commit `4e70e2239` and the current byte-for-byte source/deployed match) so a future
  reader does not assume the block was silently never added.
- **Risk**: editing `roadmap-update.md`'s "No Live Caller Yet" header might collide with task
  371's own understanding of the file, if 371 reads it for context. **Mitigation**: the task
  description itself anticipates this ("if 371 lands first and alters which modes exist,
  re-read `roadmap-integration.sh`'s header before editing the caller contract") — re-read that
  script's header at implementation time to confirm `--regenerate`/`--prune` still mean what
  this report assumes before landing the edit.

## Context Extension Recommendations

- None. This is a narrowly-scoped contract/documentation fix fully covered by the three files
  already read; no new `.claude/context/` topic is warranted.

## Appendix

- Searches: `grep -in "conclusion"` over `orchestrate-batch-results-template.md` (source and
  deployed); `grep -rn "roadmap-integration.sh"` over `skills/skill-todo/SKILL.md`,
  `commands/review.md`; `git log --oneline -p` on `orchestrate-batch-results-template.md` and
  `roadmap-update.md`; `diff` between source-store and deployed template copies.
- Files read in full: `context/contracts/conclusion-stage.md`,
  `context/patterns/orchestrate-batch-results-template.md`,
  `context/patterns/roadmap-update.md`, relevant excerpt of `context/contracts/phase-closure.md`
  ("mandatory-attempt" section), relevant excerpt of
  `context/standards/postflight-tool-restrictions.md` ("Conclusion Stage (Move 5) Tool
  Restrictions" section).
- Git references: commit `4e70e2239` (task 273 phase 8, closed GAP 1); commit `71a50bdb9` (task
  273 phase 9, completed implementation of the conclusion stage); commit `59530e533` (task 306
  phase 6, authored `roadmap-update.md`).
