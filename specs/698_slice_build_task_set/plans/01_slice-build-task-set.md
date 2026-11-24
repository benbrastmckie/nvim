# Implementation Plan: Task #698

- **Task**: 698 - slice_build_task_set
- **Status**: [IMPLEMENTING]
- **Effort**: 3.75 hours
- **Dependencies**: None (the ruling's own record, `slice_command_design_and_consolidation`, is completed)
- **Research Inputs**: specs/698_slice_build_task_set/reports/01_slice-build-task-set.md
- **Artifacts**: plans/01_slice-build-task-set.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The ruling `specs/decisions/slice-command-one-path-to-review.md` names six successors that have
no task record, and two existing records (`stack_pr_redeploy_and_second_repo_demo`,
`branch_aware_orchestration_and_squash_landing`) whose descriptions rest on overturned ground.
This plan produces the task SET in the only shape an autonomous dispatch can produce it: a
creation-ready proposal packet for the six new records (full descriptions, territory, edges
keyed by slug, write order, pre-computed backlog-audit verdicts), one `follow_up_task` evidence
entry per candidate, the two description revisions performed directly through the sanctioned
mechanical route, and a foreground runbook that turns the packet into records and edges with no
further design work. Done means: the packet and runbook exist and validate, both descriptions
are revised, no new `active_projects` entry was written by the dispatch, and the state file
validates.

### Research Integration

Integrated from `reports/01_slice-build-task-set.md`:

- Six new records (S1 to S6), slugs, territory and what each description must say.
- Two ordering corrections against the ruling: S3 is ordered after S4 and S2 (it has a live
  caller in `scripts/milestone-review-handoff.sh`); S5 is ordered after S6, S4 and S3 as well
  as S1.
- The 655 edge runs from 655 onto S2, never from S2 onto 655.
- Fifteen edges; the "one real pull request" condition lives in S1's and S5's descriptions
  because no edge can express an operator action.
- No edge-removal flag exists; removal is a `state-write.sh` filter.

One research gap is closed here and changes the shape of the work; see `## Decisions`, D1.

### Premise Re-Validation

Each trigger-class line of the task description, checked at plan-authoring time against
`specs/state.json` and the source store at `692a89128`:

| Carried claim | Plan-time result |
|---|---|
| Six successors; five with no record, one (S4) that lost its owner | Confirmed. No record exists for any of the six; `handoff_prints_review_stack` is `completed` |
| S1 "ordered after nothing" | Confirmed |
| S2 after S1, "hard edge onto 655" | S2 after S1 confirmed. The 655 edge is reversed (655 after S2), per the report; not re-litigated here |
| S3 "ordered after nothing, independent of the build" | **False.** `grep -rl review-stack-prepare` over `agent-system/extensions` returns 11 files, including the live caller. S3 goes after S4 and S2 |
| `review-stack-prepare.sh` at 74 KB | Confirmed: 74,125 bytes |
| 10 `review_base` occurrences in `repo-level-declarations.md` | Confirmed: `grep -c` returns 10 lines |
| 692 closed as written and terminal | Confirmed: `completed` |
| E7: 27 files mention `/merge` | Confirmed by the ruling's own pattern: 27. ENUMERATION-UNVERIFIED by a second pattern; S5's own research re-enumerates |
| 694 renders EXT-BLOCKED; edges onto 692 and the abandoned 693 | Confirmed: `roadmap_ext_blocked: true`, `dependencies` `[691, 692, 693, 695]`; 693 is `abandoned` in the archive |
| `/revise` path for 694 and 655 | Description Update path for both. The checkable condition is "no plan file": 694 has no task directory; 655 has an EMPTY `plans/` directory (the report's "no `plans/` directory" is inexact for 655) |
| `commands/slice.md` absent; nothing names `/slice` or `slice_bar` | Confirmed: file absent, pattern returns 0 files |
| `milestone-review-handoff.sh` line count | 366 (report's figure; the ruling's 299 is stale) |
| `next_project_number` | 699 at authoring. A new record (696) appeared since the ruling; numbers are never hard-coded below |
| "No edge is writable until both endpoints exist" | Confirmed (`--depends-on-add` requires every predecessor in `active_projects`) |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context. The last roadmap maintenance pass
prioritized the `/slice` records; this plan's output is the input the next `/roadmap` pass needs
to batch them. `roadmap_ext_blocked` on 694 belongs to that pass and is not edited here.

## Goals & Non-Goals

**Goals**:
- A machine-readable proposal packet for S1 to S6 that a foreground session can create from
  without composing anything.
- One `follow_up_task` evidence entry per candidate, plus the same candidates rendered as a
  human-readable list in the runbook and the implementation summary.
- Revised descriptions on 694 and 655, written through `state-write.sh`.
- A foreground runbook covering creation, territory declaration, the fifteen edges, 694's edge
  replacement, and post-write validation.

**Non-Goals**:
- Creating any new `active_projects` entry from inside the dispatch (D1).
- Writing or removing any dependency edge from inside the dispatch (D2).
- Implementing, researching or planning any successor.
- Any edit under `agent-system/**` or `.claude/**`.
- Abandoning the five held records (670, 671, 672, 674, 686); that is on the ruling's operator
  worklist.
- Editing `roadmap_ext_blocked` or any roadmap entry.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The implementer reads the task description literally and creates records | H | M | D1 and Phase 4's verification assert the set of `project_number`s is unchanged against a Phase 1 baseline |
| The packet is produced but nobody runs the foreground step, leaving `/slice` un-orchestratable | H | M | The runbook is one ordered command list; `next_steps`, the summary and six `follow_up_task` entries all point at it |
| Revised 694 becomes dispatchable before its new predecessors exist | H | L | Its edges are not touched by the dispatch; the dangling edge onto 693 keeps it blocked until the runbook swaps edges in one step |
| Numbers drift between packet authoring and creation | M | H | Packet and descriptions cite slugs only; the runbook reads each allocated number back into a slug-to-number map |
| Backlog audit flags S4 against `handoff_prints_review_stack` or S3 against `restack_review_stack_when_parent_merges` | L | H | Expected; verdicts are pre-computed in Phase 2 and each description states that it reverses a closed deliverable |
| Concurrent writers to `specs/state.json` | M | M | Every write goes through `state-write.sh`; Phase 3 re-reads both descriptions immediately before writing |
| A description revision loses text a reader still needs | M | L | Phase 3 saves both pre-revision descriptions under `records/` before writing |

## Decisions

- **D1. The dispatch produces a proposal packet; it does not create records.** The task
  description directs creation "via /task". The section "Requesting a Proposal Packet, Not
  Filing, From an Autonomous Dispatch" of
  `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` binds
  any task description handed to an autonomous dispatch and names this as a forbidden shape:
  confirmed creation is foreground-only, `AskUserQuestion` is withheld from dispatched
  subagents, and `state-write.sh`'s audit-evidence gate admits a new entry only with a matching
  verdict or a human-authored `--audit-override`. The convention answers the question, so this
  is recorded as a decision and not raised as a `user_decision`. The required shape is followed:
  one `issue-record.sh` entry per candidate with `--suggested-channel follow_up_task`, and the
  same candidates as a human-readable list. The packet goes further than the minimum (complete
  descriptions, verdicts, runbook) so the foreground step is mechanical.
- **D2. No edge is written or removed by the dispatch.** Fourteen of the fifteen edges have an
  endpoint that does not exist yet. The only writable change is removing 694's edges onto 692
  and 693, and doing that alone would leave 694 with satisfied predecessors only and therefore
  dispatchable ahead of S1, S4 and S5. Removal and addition on 694 are one runbook step.
- **D3. The two description revisions ARE performed by the dispatch.** `commands/revise.md`
  names the route for a dispatched agent: the "For Description Update" block of
  `skills/skill-reviser/SKILL.md` Stage 7, a `state-write.sh` object-merge. Both revisions cite
  successors by slug, so they do not wait on creation.
- **D4. Report decisions carried unchanged**: S4 is a new record; S3 after S4 and S2; S5 after
  S1, S3, S4, S6; 655 after S2; 694 after S1 to S6; creation order S1, S6, S2, S4, S3, S5.
- **D5. Packet files live under `specs/698_slice_build_task_set/records/`**, the task-directory
  subdirectory already used for durable non-artifact records.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the Task-Set Proposal Packet [COMPLETED]

**Goal**: One JSON packet holding everything the six new records need, keyed by slug, with a
baseline of the live state it was authored against.

**Tasks**:
- [x] Record the baseline: `jq '[.active_projects[].project_number] | sort' specs/state.json`
      and `next_project_number`, written into the packet's `baseline` object. *(completed)*
- [x] Re-run the premise checks in the table above (statuses of 655, 690 to 695, 697; the
      `review-stack-prepare`, `/merge`, `/slice|slice_bar` greps; `wc` on the handoff script) and
      correct any figure that has moved before it enters a description. *(completed: all figures confirmed; 27 /merge files, 11 review-stack-prepare files, 10 review_base lines, handoff 366 lines; work branch now 400 ahead)*
- [x] Read the ruling's sections each description cites ("The command surface", "The mechanism",
      "Basis", "The size bar", "One survivor, and what is deleted", "Grants", "Constraints held",
      "Successors", "What is discarded") so each description quotes the ruling by section name. *(completed)*
- [x] Write `records/01_task-set-packet.json` with: `baseline`; `topic` (`core-agent-system`);
      `task_type` (`meta`); `creation_order` (`slice_command_build`,
      `bind_push_grant_to_pushed_ref`, `slice_bar_measurement_and_declaration`,
      `narrow_handoff_to_print_slice`, `delete_review_stack_inference_route`,
      `remove_merge_command`); a `proposals` array whose elements carry `id` (the slug),
      `title`, `description`, `file_scope` (source-store-relative paths spelled
      `agent-system/extensions/core/...`, no shell variable), and `depends_on_slugs`; and an
      `edges_onto_existing` object (`655` after `slice_bar_measurement_and_declaration`; `694`
      after all six, removing 692 and 693). *(deviation: altered — sixteen edges, not fifteen: narrow_handoff_to_print_slice after slice_bar_measurement_and_declaration added for shared index-entries.json; packet also carries successor_map and edge_count)*
- [x] Each description opens with the standard source-store paragraph and carries the points in
      the report's "What each description must say beyond its row", in particular: S1's
      acceptance is one real slice pushed by a typed grant and opened by the operator typing
      `/slice`, the implementing agent stops short and does not close the record; S3 names its
      live caller and Overview lines 16 and 19; S4 states it reverses a closed deliverable and
      retargets Case H; S5 carries the dispatch-time precondition that a pull request opened by
      `/slice` exists and names the three files in other extensions; S5's file list is marked
      for re-enumeration by its own research. *(completed)*
- [x] No description contains a successor's task number; cross-references use slugs. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The single touched path lies under `specs/**`, so no suite maps to it and the covering check is `jq empty` on the packet plus a diff read-through (plan-format.md `__FULL_SWEEP__` sub-case (a); the selector was not run because that sub-case fixes the answer for a `specs/**`-only set).

**Scope Hypothesis**: Six proposals and fifteen edges (eight among the new records, one onto
655, six onto 694), carried from `reports/01_slice-build-task-set.md`. Confirm by
`jq '.proposals | length'` and by counting `depends_on_slugs` plus `edges_onto_existing`; if the
re-run premise checks move an ordering, correct the packet and record the delta with
`issue-record.sh`.

**Files to modify**:
- `specs/698_slice_build_task_set/records/01_task-set-packet.json` - new; the proposal packet

**Verification**:
- `jq empty specs/698_slice_build_task_set/records/01_task-set-packet.json` exits 0.
- `jq '.proposals | length'` is 6; every `depends_on_slugs` entry names an `id` in the packet;
  the slug graph is acyclic (S1 and S6 have no predecessors).
- `grep -nE '\b(699|70[0-4])\b'` over the packet returns nothing inside any `description`.

---

### Phase 2: Audit the Proposals and Record Follow-Up Evidence [NOT STARTED]

**Goal**: Pre-compute the backlog-reconciliation verdicts the creation gate will demand, and
record each candidate in the channel the conclusion stage reads.

**Tasks**:
- [ ] Run `jq '.proposals' records/01_task-set-packet.json | bash
      .claude/scripts/audit-task-proposals.sh --proposals-file -` and save stdout to
      `records/01_audit-verdicts.ndjson`. Confirm each line's `.proposal.id` equals the slug.
- [ ] For every verdict other than `genuinely-new` and `scope-blind`, add a one-line disposition
      to the packet proposal's `audit_note` field (expected: S4 against
      `handoff_prints_review_stack`, S3 against `restack_review_stack_when_parent_merges`; both
      genuinely new work reversing a closed deliverable). Cite matched records by
      `project_name`.
- [ ] Record six entries, one per candidate, non-fatally:
      `bash .claude/scripts/issue-record.sh --task-dir <task_dir> --kind issue --class
      "follow-up task candidate" --severity none --phase implement --resolution open
      --suggested-channel follow_up_task --evidence-path
      specs/698_slice_build_task_set/records/01_task-set-packet.json --what-happened "<slug>:
      <one-sentence scope>; depends on <slugs>"`. If `--severity none` is refused for
      `kind: issue`, use `minor`.
- [ ] Record one further `follow_up_task` entry for the edge work on existing records (655 after
      S2; 694 re-edged), since it is also deferred to the foreground step.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Data-only appends under `specs/**` with no script edited: the selector maps `issues.jsonl` to suites that exercise its writers, which this phase does not change, so the covering check is `jq -c .` over `records/01_audit-verdicts.ndjson` and `issues.jsonl` parsing cleanly plus a read-through of the seven appended lines.

**Files to modify**:
- `specs/698_slice_build_task_set/records/01_audit-verdicts.ndjson` - new; six verdict lines
- `specs/698_slice_build_task_set/records/01_task-set-packet.json` - `audit_note` per proposal
- `specs/698_slice_build_task_set/issues.jsonl` - seven appended `follow_up_task` entries

**Verification**:
- `wc -l` on the verdicts file is 6 and every line parses.
- `jq -c 'select(.suggested_channel == "follow_up_task")' issues.jsonl | wc -l` is 7.
- `jq '[.active_projects[].project_number] | sort' specs/state.json` still equals the packet's
  baseline plus any number a concurrent session allocated (none attributable to this dispatch).

---

### Phase 3: Revise the Descriptions of 694 and 655 [NOT STARTED]

**Goal**: Both existing records rest on the ruling's ground, cited by slug, with their edges
untouched.

**Tasks**:
- [ ] Confirm both targets exist and are `not_started` with no plan file
      (`jq` on `specs/state.json`; `ls specs/655_*/plans` is empty; 694 has no directory). If
      either has gained a plan file or left `not_started`, do not write: record the finding
      with `issue-record.sh`, move that record's revision into the runbook as an operator step,
      and continue with the other.
- [ ] Save both current descriptions to `records/01_prior-descriptions.json` (keys `694`,
      `655`) before any write.
- [ ] 694: replace the body. Keep the source-store paragraph. New scope: doc parity for
      `/slice` across `README.md`, `merge-sources/claudemd.md` and `docs/guides/user-guide.md`;
      redeploy with the bounded-wait idiom and `index-entries.json` line-count reconciliation;
      the operator runbook for the slice route (the typed `/please push` lines, then `/slice`;
      grant count and window as they stand after `bind_push_grant_to_pushed_ref`), sited in
      `docs/guides/user-guide.md`; acceptance is one real slice pushed and opened by the
      operator in a second repository. State that it runs after all six successors, named by
      slug, and that its predecessors are to be re-edged by the foreground runbook.
- [ ] 655: replace only the "PRIORITY RAISED" paragraph with the ruling's ground: the
      generated-path declaration has a second consumer, the `/slice` bar's line count ("The size
      bar", "What is counted"); until it exists every path counts and the prompt says so; it is
      ordered after `slice_bar_measurement_and_declaration`. Everything from "=== ORIGINAL
      DESCRIPTION BELOW" onward stays byte-identical.
- [ ] Write each with the Stage 7 "For Description Update" block of
      `skills/skill-reviser/SKILL.md` (`state-write.sh` object-merge of `description` and
      `last_updated`, `--session-id`, `--arg desc`, `--argjson num`, `--regen-todo`). Pass the
      description from a file via `--arg desc "$(cat file)"`; never hand-roll a `jq` rewrite.
- [ ] Regenerate the roadmap, which renders truncated descriptions:
      `bash .claude/scripts/roadmap-integration.sh --regenerate`.
- [ ] Do not touch `dependencies`, `file_scope`, `roadmap_ext_blocked` or `status` on either
      record.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is two `description` fields in one state file plus its two generated renders, with no script edited: the selector maps `specs/state.json` to the many suites that exercise its writers, none of whose subjects change here, so the covering check is `bash .claude/scripts/validate-state.sh --deep` on the state file and a `git diff` read-through of the renders.

**Scope Hypothesis**: Exactly two `active_projects` entries change, in `description` and
`last_updated` only, and `specs/ROADMAP.md` moves only on lines rendering those two records.
Confirm with `git diff --stat` and a `jq` comparison of both entries against
`records/01_prior-descriptions.json` with `description` and `last_updated` deleted.

**Files to modify**:
- `specs/state.json` - `description` and `last_updated` on two records
- `specs/TODO.md` - generated render, via `--regen-todo`
- `specs/ROADMAP.md` - generated render, via `roadmap-integration.sh --regenerate`
- `specs/698_slice_build_task_set/records/01_prior-descriptions.json` - new; pre-revision text

**Verification**:
- `bash .claude/scripts/validate-state.sh --deep` reports no new failure against a run taken
  before the phase.
- 694's `dependencies` is still `[691, 692, 693, 695]`; 655's is unchanged.
- 655's description from "=== ORIGINAL DESCRIPTION BELOW" onward is byte-identical to the saved
  copy.
- Neither revised description contains `/merge --stack`, "PRIORITY RAISED", or a successor's
  task number.

---

### Phase 4: Write the Foreground Creation Runbook and Verify the Set [NOT STARTED]

**Goal**: A single ordered command list that turns the packet into six records and fifteen
edges, and proof that the dispatch itself created nothing.

**Tasks**:
- [ ] Write `records/01_creation-runbook.md` with: (a) the candidate list in human-readable
      form (slug, one-line scope, territory, predecessors, audit disposition); (b) the
      confirmation the foreground surface owes the operator before creating; (c) creation in
      `creation_order`, each via `commands/task.md` Create Task Mode with topic
      `core-agent-system` and `--audit-verdict records/01_audit-verdicts.ndjson`, reading the
      allocated number back into a slug-to-number map; (d) `update-task-status.sh preflight
      <n> edge_only <session> --file-scope-add=<array>` per record; (e) the eight edges among
      the new records and 655 after S2, each as `update-task-status.sh preflight <dependent>
      edge_only <session> --depends-on-add='[...]'`; (f) 694 in one step: the `state-write.sh`
      filter removing 692 and 693, immediately followed by `--depends-on-add` for all six;
      (g) `generate-todo.sh`, `validate-state.sh --deep`, and
      `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json <eight numbers>`;
      (h) the note that S1 and `bind_push_grant_to_pushed_ref` are dispatchable together first.
- [ ] State in the runbook that an agent session may run it only as a foreground surface with
      the operator's confirmation, and that S1's closing step and every push stay the
      operator's (`rules/pr-prohibition.md`).
- [ ] Re-check the packet against live state: baseline numbers, statuses of 655 and 694, and
      that no record with any of the six slugs now exists.
- [ ] Confirm the dispatch added no `active_projects` entry and changed no `dependencies`
      array: compare `[.active_projects[] | {project_number, dependencies}]` at `HEAD` of the
      pre-implementation commit against the working tree.
- [ ] In the implementation summary, render the candidate list again, state that record
      creation and all fifteen edges are owed by a foreground step, and name the runbook path.
      Set `next_steps` to point at the runbook.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- `specs/698_slice_build_task_set/records/01_creation-runbook.md` - new; the foreground runbook

**Verification**:
- Scoped touched-path check for this dispatch (every touched path is under `specs/**`):
  `jq empty` on the packet, `jq -c .` on the verdicts file,
  `bash .claude/scripts/validate-state.sh --deep`, and a `git diff` read-through of
  `specs/state.json`, `specs/TODO.md` and `specs/ROADMAP.md`.
- The complete gate set is deferred to the orchestration close (the batch gate stage); it is
  not run independently by this phase. In a standalone, non-orchestrated run, run
  `bash .claude/scripts/verify-deploy.sh` directly instead.
- Every slug in the runbook's commands appears in the packet; every one of the fifteen edges
  appears exactly once.
- The set of `project_number`s and every `dependencies` array are unchanged by this task's
  commits.

## Testing & Validation

- [ ] `records/01_task-set-packet.json` parses, holds six proposals, and its slug graph is
      acyclic.
- [ ] `records/01_audit-verdicts.ndjson` holds six lines whose `.proposal.id` values are the six
      slugs.
- [ ] Seven `follow_up_task` entries exist in `issues.jsonl`.
- [ ] 694 and 655 carry revised descriptions; their edges, territory and status are unchanged.
- [ ] `validate-state.sh --deep` shows no new failure.
- [ ] No new `active_projects` entry is attributable to this task.

## Artifacts & Outputs

- `specs/698_slice_build_task_set/records/01_task-set-packet.json`
- `specs/698_slice_build_task_set/records/01_audit-verdicts.ndjson`
- `specs/698_slice_build_task_set/records/01_prior-descriptions.json`
- `specs/698_slice_build_task_set/records/01_creation-runbook.md`
- Revised `description` on two records in `specs/state.json`, with `specs/TODO.md` and
  `specs/ROADMAP.md` regenerated
- `specs/698_slice_build_task_set/summaries/01_slice-build-task-set-summary.md`

**Owed after this task, by a foreground surface**: the six records, their `file_scope`, and all
fifteen edges, exactly as the runbook lists them.

## Rollback/Contingency

The packet, verdicts and runbook are new files; discard them by reverting their commits. A
description revision is restored by re-running the same Stage 7 `state-write.sh` block with the
text saved in `records/01_prior-descriptions.json`, then `--regen-todo` and
`roadmap-integration.sh --regenerate`; no working-tree rollback is involved. If a concurrent
session has rewritten either description between the save and the write, stop, keep the saved
copy, and record the collision with `issue-record.sh` instead of overwriting.
