# Research Report: Task #44

**Task**: 44 - slim_task_command_body
**Started**: 2026-08-17
**Completed**: 2026-08-17
**Effort**: ~1 hour
**Dependencies**: None blocking
**Sources/Inputs**: Codebase (agent-system/extensions/core/commands/task.md, todo.md, orchestrate.md; specs/archive/056_slim_todo_and_orchestrate_command_bodies/); git log
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `task.md`'s source-store body is now **39,403 B / 976 lines** (grown from the 37,465 B cited in
  the task description — later `.claude/**` additions since the sibling task's Aug-12 measurement
  added the file_scope advisory, mandatory topic assignment, and `--regen-todo` folding across
  several modes).
- The one prior attempt at this exact question — the sibling task recorded in
  `specs/archive/056_slim_todo_and_orchestrate_command_bodies/summaries/01_command-body-extraction-summary.md`
  — explicitly researched and **rejected** slimming `task.md`, on the grounds that it has no
  `## Notes`-style appendix or standalone fenced output template comparable to what `todo.md`/
  `orchestrate.md` had. That finding is correct as far as it goes, but it only tested `task.md`
  against the shape those two files have (single linear flow + one appendix region). It never
  tested the shape `task.md` actually has: **a dispatcher over six mutually exclusive modes**,
  of which the model's own prior message body loads all six on every invocation even though at
  most one executes.
- That structural difference is the real lever here, and it is much bigger than the sibling
  task's ~15% reductions: extracting the five non-default modes (Recover, Expand, Sync, Review,
  Abandon — **25,883 B, 65.7% of the file**) plus one illustrative sub-region inside Create Task
  Mode (worked-examples/edge-cases table, 1,707 B) leaves a command body of roughly **13,200 B**,
  a **~66% reduction**, versus the sibling task's 15%.
- The established mechanism — an imperative `READ <path>. <consequence>` pointer at the exact
  point of need, registered in `index-entries.json` under `load_when.commands` — transfers
  directly. `manifest.json` needs no edit (`.provides.context` already lists `patterns`
  wholesale). No internal cross-mode references need repointing (see Findings).
- The one new risk this task's own framing already anticipated: extracting a whole MODE (not a
  reference appendix) means the pointer target *is* the only specification of that mode's
  behavior, not supplementary material an agent could partially reconstruct from context. That
  raises the blast radius of a skipped or malformed READ from "degraded" to "unspecified
  operation" for that mode. See Risks & Mitigations.

## Context & Scope

Task 44 asks to slim `task.md`'s per-invocation body by moving reference material (long option
tables, worked examples, edge-case narratives) into lazily-loaded context files, while every mode
(`--recover`, `--expand`, `--sync`, `--abandon`, multi-task creation via `--review`) remains fully
specified — inline or via an explicit pointer the executing agent is instructed to follow. All
edits target `agent-system/extensions/core/**` (source store); `.claude/**` is the disposable
deploy artifact and is never hand-edited (`.claude/rules/source-store-deploy-boundary.md`).

The research focus asked for: (1) precise before/after measurement, (2) reference-vs-decision-logic
classification, (3) survey of the established lazy-pointer pattern elsewhere in the repo and
whether to follow or diverge from it, (4) risk of degrading a mode's execution by pointer-izing
it, (5) a concrete section-by-section disposition, and (6) a check of recent commits touching
`commands/` so recommendations build on current, not stale, content.

## Findings

### Recent commits touching `commands/` (currency check)

`git log --oneline -20 -- agent-system/extensions/core/commands/` shows the most recent activity
is task 17 (postflight `.return-meta.json` deletion sites across command files) and task 60
(idle-overlap advisory / `--allow-scope-collision` threading in `orchestrate.md`) — neither
touches `task.md`. The most recent `task.md`-specific work is task 61 phase 5 ("Create Task Mode
Step 6.5 advisory", `342729d2a`), already reflected in the file I read (Step 6.5's file_scope
advisory, lines 235-258). The content I measured and dispositioned below is current, not stale.

### Precise current measurement

```
wc -c agent-system/extensions/core/commands/task.md  -> 39,403 B (976 lines)
```

Per-mode byte breakdown (via `sed -n 'START,ENDp' | wc -c` on the ranges below — line numbers are
1-indexed `## `-heading anchors from a direct read of the file):

| Region | Lines | Bytes | % of file |
|---|---:|---:|---:|
| Frontmatter + CRITICAL warning + Mode Detection | 1-37 | 1,391 | 3.5% |
| **Create Task Mode** (default, no-flag invocation) | 38-281 | 11,511 | 29.2% |
| — of which: Transformation Examples table + Edge Cases + duplicate Action Verb Categories table | 85-109 | 1,707 | 4.3% |
| Recover Mode (`--recover`) | 282-382 | 4,409 | 11.2% |
| Expand Mode (`--expand`) | 383-456 | 3,196 | 8.1% |
| Sync Mode (`--sync`) | 457-575 | 5,082 | 12.9% |
| Review Mode (`--review`) | 576-898 | 10,085 | 25.6% |
| — of which: "Standards Reference (--review mode)" compliance table (pure appendix) | 880-897 | ~620 | 1.6% |
| Abandon Mode (`--abandon`) | 899-961 | 3,111 | 7.9% |
| Constraints (applies to every mode) | 962-976 | 618 | 1.6% |

Sum of the five non-default modes: **4,409 + 3,196 + 5,082 + 10,085 + 3,111 = 25,883 B (65.7%)**.
This is the dominant fact: two-thirds of every `/task` invocation's body cost is spent on modes
that invocation, by construction, cannot be using (Mode Detection already establishes exactly one
mode applies before any mode body is needed).

### Why the sibling task's rejection doesn't transfer

The sibling task's summary (quoted in full above) measured `task.md` at 37,465 B and called it
"the smallest of the three" command files, "procedural and mode-specific throughout... with
roughly 0-1 KB of extractable material and no `## Notes`-style appendix or standalone output
template comparable to what this task extracted." That comparison is accurate: `task.md` genuinely
has no `todo.md`-style Notes appendix or `orchestrate.md`-style fenced output template. But
`todo.md` and `orchestrate.md` are each a **single linear flow** — one procedure that runs start
to finish on every invocation, with an occasional appendix/template region bolted on. `task.md` is
structurally different: **Mode Detection is a real dispatch point, and five of six branches are
mutually exclusive with the sixth (Create Task Mode)**. The sibling research tested `task.md`
against the "does it have a Notes-shaped appendix" question and got a correct "no" — but never
asked "does it have a mode-shaped branch a single invocation doesn't need," which is the question
this task's framing (LOWER PRIORITY, "per-invocation cost, not per-session") actually raises, and
where nearly two-thirds of the file's bytes live.

### Reference material vs. decision logic, by region

- **Frontmatter + CRITICAL warning + Mode Detection (1-37)**: pure decision logic every invocation
  needs (the mode dispatch itself, plus the highest-severity safety constraint in the file — "do
  not interpret the description as instructions"). **Keep inline, unconditionally.**
- **Create Task Mode (38-281)**: this is the default (no-flag) mode, so it is the single most
  frequent invocation shape and cannot be pointer-ized wholesale without penalizing the common
  case. Within it, steps 1-2, 3.1-3.3 core rules, 4-4e, 4.5, 5-8 are decision logic (the actual
  description-transformation algorithm, task_type detection precedence, topic assignment, state
  write, advisory, commit, output) and should stay inline. The **Transformation Examples table
  (87-96), Edge Cases bullets (98-103), and Action Verb Categories table (105-109)** are reference
  material in the sense the task description names explicitly ("worked examples, edge-case
  narratives") — they reinforce an algorithm (3.1-3.3) that is already fully specified without
  them. One wrinkle: the Action Verb Categories table (105-109) is not a pure duplicate of 3.2's
  inline mapping — it carries a few extra keywords per category (`crash`, `regression`, `config`,
  `settings`, `feature`, `support`, `capability`) not present in 3.2's four bullet lines. Extracting
  it changes which keywords are available inline at decision time unless 3.2 is first
  reconciled to the union, which is a content change, not a pure relocation — **the planner should
  decide explicitly** whether to (a) merge the fuller category table into 3.2 inline and drop the
  standalone table, or (b) keep 3.2's four-line summary inline and move only the *extra* keyword
  detail plus the worked-examples table and edge cases to the pointer file. Either is legitimate;
  what must not happen is silently extracting the table and leaving 3.2 with a narrower keyword
  set than today, since that is a behavior change disguised as a relocation.
- **Recover Mode, Expand Mode, Sync Mode, Review Mode, Abandon Mode**: each is decision logic
  *for that mode*, but irrelevant reference weight for every invocation not using that mode.
  Recommend whole-mode extraction (see Recommendations) — this is the disposition that produces
  the ~66% reduction, and it is a legitimate reading of "decision logic... an invocation actually
  needs": an invocation that took the Create-mode branch never needs Sync Mode's decision logic
  at all, so from that invocation's perspective Sync Mode's body is exactly the kind of
  unconditionally-loaded, conditionally-relevant weight the task description is asking to remove.
- **Review Mode's "Standards Reference (--review mode)" subsection (880-897)**: a compliance
  table pointing at `multi-task-creation-standard.md` — pure appendix, same shape as the Notes
  sections task 56 extracted, and doubly so once Review Mode itself is pointer-ized (it would
  travel with the rest of Review Mode into its own file rather than needing separate treatment).

### The established pattern, and how far this task should diverge from it

Both existing precedents (`orchestrate.md`'s `## Batch Orchestrate Results` fence and `todo.md`'s
`## Notes` section, task 56, commits `588cab9c5` / `398bc8cbd`) share one mechanism:

1. Move the region verbatim into `agent-system/extensions/core/context/patterns/{command}-{topic}.md`.
2. Replace it in the command body with an imperative pointer using the **deployed** path form
   (`.claude/context/patterns/...`, not the source-store `context/patterns/...` form) and language
   that passes a "passive vs. imperative" test — must read as "READ this now / MUST follow", never
   "see also" or "for more detail". Concrete precedent wording:
   - `todo.md`: "**Reference material**: the archival-status definitions... live in
     `.claude/context/patterns/todo-archival-reference.md`. READ that file before executing any of
     those steps."
   - `orchestrate.md`: "**Consolidated Output**: READ `.claude/context/patterns/
     orchestrate-batch-results-template.md` now and emit the batch results using that template.
     The template MUST be followed exactly — its per-section rendering conditions are part of the
     contract, not commentary."
3. Register the new file in `index-entries.json` with `load_when.commands: ["/task"]` (mirroring
   the `["/todo"]` / `["/orchestrate"]` entries already present), no `manifest.json` edit needed
   (`patterns/` is already listed wholesale under `.provides.context`).
4. Repoint any internal cross-reference that pointed at the now-relocated prose.

This mechanism transfers to `task.md` without modification for step 1-3. The divergence is scope:
task 56 always extracted a *sub-region within an always-executing flow* (the reference appendix
supplements decision logic that stays put); this task's biggest win is extracting *entire modes*
(the "decision logic" and the "reference material" are the same content, because the whole mode
only matters when that mode is the one dispatched). That's a legitimate reading of the task
description, but it is a new use of the pointer mechanism, not a mechanical repeat of the
precedent, and it deserves the explicit risk treatment below rather than being applied on
pattern-matching alone.

### Internal cross-references (repointing check)

Grepped both directions for any place one mode's prose depends on another mode's now-relocatable
prose:

- Review Mode (line 234, "use the Create Task jq pattern") and Expand Mode (line 147, "using the
  Create Task jq pattern") both name Create Task Mode by reference rather than restating its jq
  pattern. **No repointing is needed for these**: Create Task Mode stays inline in the main
  command body under the disposition below (it's the default mode), so by the time an agent has
  been dispatched into Review Mode or Expand Mode's separate file, it already read Create Task
  Mode's steps as part of the always-loaded main body, before ever following the mode-specific
  pointer. The reference resolves without modification.
  - **Caveat for the planner/implementer**: this only holds if Create Task Mode is not itself
    fully pointer-ized. If a future revision moves Create Task Mode's own body out too, these two
    cross-references become dangling and must be repointed at that time — flagging this explicitly
    since it's an implicit dependency the current disposition relies on.
  - **A local micro-fix worth doing while pointer-izing Expand/Review Mode**: the phrase "the
    Create Task jq pattern" — which is fine as an in-file reference today — should probably read
    "the Create Task Mode jq pattern in `.claude/commands/task.md`'s Create Task Mode section" (or
    similar) once Expand/Review Mode's prose lives in a *separate* file, so a reader who opened
    only `expand-mode.md`/`review-mode.md` (e.g. via `index-entries.json` discovery, not via the
    command dispatch) isn't left wondering what "Create Task" refers to. This is a small wording
    tweak at the extraction site, not a new pointer.
- Recover Mode and Abandon Mode's internal "Step 1 / Step 2" comments are local to their own
  jq blocks (archive-then-active two-step writes) — no cross-mode dependency, no repointing needed.
- No mode references Sync Mode's content, and Sync Mode references no other mode.

## Recommendations

Concrete section-by-section disposition (bytes are current-content bytes being relocated, not
including each destination file's own short preamble):

| Command-body region | Disposition | Destination |
|---|---|---|
| Frontmatter, CRITICAL warning, Mode Detection (1-37) | Keep inline, unchanged | — |
| Create Task Mode steps 1-2, 3.1-3.3 core rules, 4-4e, 4.5, 5-8 (~9,804 B after the sub-extraction below) | Keep inline, unchanged | — |
| Create Task Mode: Transformation Examples table, Edge Cases, Action Verb Categories (85-109, 1,707 B) | Extract; planner decides merge-vs-relocate for the category-table keyword discrepancy (see Findings) | New: `context/patterns/task-description-transformation-examples.md` |
| Recover Mode (282-382, 4,409 B) | Extract whole mode | New: `context/patterns/task-recover-mode.md` |
| Expand Mode (383-456, 3,196 B) | Extract whole mode | New: `context/patterns/task-expand-mode.md` |
| Sync Mode (457-575, 5,082 B) | Extract whole mode | New: `context/patterns/task-sync-mode.md` |
| Review Mode (576-898, 10,085 B, including its own Standards Reference appendix) | Extract whole mode | New: `context/patterns/task-review-mode.md` |
| Abandon Mode (899-961, 3,111 B) | Extract whole mode | New: `context/patterns/task-abandon-mode.md` |
| Constraints (962-976, 618 B) | Keep inline, unchanged — applies to every mode including whichever one was just pointer-ized into | — |

Pointer placement and wording, per the existing "passive/imperative" test from task 56: site each
mode's pointer at the Mode Detection dispatch table (28-36) rather than leaving a bare `##
{Mode} Mode (--flag)` heading with nothing under it — e.g.:

```
- `--recover RANGES` → Recover tasks from archive. READ
  `.claude/context/patterns/task-recover-mode.md` now and follow it exactly.
- `--expand N [prompt]` → Expand task into subtasks. READ
  `.claude/context/patterns/task-expand-mode.md` now and follow it exactly.
- `--sync` → Sync TODO.md with state.json. READ
  `.claude/context/patterns/task-sync-mode.md` now and follow it exactly.
- `--review N` → Review task completion status. READ
  `.claude/context/patterns/task-review-mode.md` now and follow it exactly.
- `--abandon RANGES` → Archive tasks. READ
  `.claude/context/patterns/task-abandon-mode.md` now and follow it exactly.
- No flag → Create new task with description (Create Task Mode below, inline).
```

Each extracted file's opening line should restate, in one sentence, that it is the complete and
only specification for that mode (mirroring the `orchestrate.md` "MUST be followed exactly"
framing) — not "additional detail" phrasing, to keep the imperative/passive distinction sharp
given the higher stakes of whole-mode extraction (see Risks below). Each new file also needs an
`index-entries.json` entry with `load_when.commands: ["/task"]`, following the exact shape of the
`todo-archival-reference.md` / `orchestrate-batch-results-template.md` entries shown above.
`manifest.json` needs no edit.

Net effect estimate: command body shrinks from 39,403 B to roughly **13,000-13,400 B** (~66%
reduction — five short pointer blocks replacing 25,883 B of mode bodies, plus one short pointer
replacing the 1,707 B example/edge-case sub-region, with Create Task Mode, Constraints, and Mode
Detection otherwise untouched). The five new mode files total roughly the same ~25,883 B plus
per-file preambles; the sixth new file (examples) is ~1,700 B plus preamble. Actual post-edit
byte counts should be re-measured by the implementer against the shipped wording, per the task's
own instruction to record before/after bytes in the implementation summary — the estimate above
is directional, not a substitute for that measurement.

## Risks & Mitigations

- **Primary risk (the one this task's own framing calls out)**: for a reference-appendix
  extraction (task 56's precedent), a skipped or garbled READ degrades execution — the agent still
  has the surrounding procedural steps and can often muddle through with generic knowledge (e.g.
  guess at a jq escaping workaround). For a **whole-mode** extraction, the pointer target *is* the
  entire specification for that mode. If the agent fails to follow the pointer (treats it as
  optional, the Read tool call errors, or the file is stale/missing), the result is not degraded
  execution but **unspecified execution** — e.g. Abandon Mode's exact two-step mutex-guarded
  archive-then-remove jq sequence, or Recover Mode's legacy-vs-padded directory-format handling,
  simply would not exist in context at all, and a model asked to "archive task N" with no other
  guidance could invent a plausible-looking but non-conforming jq sequence.
  - *Mitigation*: use the strongest available imperative framing at both the pointer site (Mode
    Detection table) and the destination file's own opening line (mirroring `orchestrate.md`'s
    "MUST be followed exactly"), so there is no ambiguity that this is the operative
    specification, not supplementary material. This is already the precedent's convention: apply
    it, don't soften it, for the higher-stakes whole-mode case.
- **Cross-reference risk**: addressed under Findings above — Review/Expand Mode's "Create Task jq
  pattern" references resolve today without repointing (Create Task Mode stays inline), but that
  is an implicit dependency on Create Task Mode never being fully pointer-ized later; flag this in
  the plan so a future editor doesn't break it silently.
- **Discovery/staleness risk**: five new files (six counting the examples extraction) all need
  `index-entries.json` entries; missing one doesn't break `/task` execution (the command-body
  pointer is what drives the runtime READ, not the index), but it does mean other flows relying on
  `context-discovery.md`'s index-based search won't surface the file. Low severity, straightforward
  to verify against the existing two entries as a template.
- **Keyword-table discrepancy risk**: called out under Findings — extracting the Action Verb
  Categories table without reconciling 3.2's inline four-line summary would silently narrow the
  keyword set Create Task Mode uses at decision time on every invocation (a behavior change, not a
  pure relocation, and one that would violate the task's explicit "do not change command
  behavior" constraint). The plan/implementation must resolve this explicitly, not extract the
  table verbatim without checking it against 3.2 first.
- **Measurement risk**: the task explicitly requires recording before/after bytes in the
  implementation summary, following task 56's own measurement-table convention (see that
  precedent's `## Measurement Table` section) — the implementer should reproduce that table shape,
  not just state a percentage.

## Decisions

- Recommend whole-mode extraction for Recover, Expand, Sync, Review, and Abandon modes (the
  disposition table above), diverging from the sibling task's narrower "reference-region-only"
  reading of the pattern, because `task.md`'s dispatcher shape makes mode-level extraction both
  legitimate under the task's own "decision logic an invocation actually needs" framing and far
  more impactful (~66% vs. ~15%) than a reference-region-only pass would be.
- Recommend Create Task Mode's Transformation Examples/Edge Cases/Action Verb Categories
  sub-region be extracted too, but flag the Action Verb Categories keyword-set discrepancy against
  3.2 as a planner decision point rather than resolving it here, since resolving it silently would
  cross from relocation into a behavior change.
- Recommend keeping Mode Detection and Constraints unconditionally inline in all cases, since both
  apply regardless of which mode a given invocation dispatches to, and Constraints in particular
  carries the file's hard-stop/scope-restriction safety net.

## Context Extension Recommendations

- None beyond the five (or six, including the examples file) new `context/patterns/*.md` files
  this task's own implementation will create and register — no gap in *existing* context
  documentation was found; this section notes the task's own planned additions, not a residual
  documentation debt discovered incidentally.

## Appendix

- Searches: `git log --oneline -20 -- agent-system/extensions/core/commands/`; `git show --stat`
  and full diffs for `588cab9c5` (orchestrate.md extraction) and `398bc8cbd` (todo.md extraction);
  direct read of `agent-system/extensions/core/commands/task.md` (full 976 lines); `wc -c`/`sed`
  byte-range measurements per mode; `jq` inspection of `manifest.json` `.provides.context` and
  `index-entries.json` entries for the two existing pattern files; grep for cross-mode references
  within `task.md`.
- Key artifact read: `specs/archive/056_slim_todo_and_orchestrate_command_bodies/summaries/01_command-body-extraction-summary.md`
  (the sibling task's own rejection of slimming `task.md`, and the measurement/pattern precedent
  this task builds on).
