# Research Report: Task #698

**Task**: 698 - slice_build_task_set
**Started**: 2026-11-24T11:20:30Z
**Completed**: 2026-11-24T11:23:30Z
**Effort**: small (record creation and edge writing; no successor is implemented here)
**Dependencies**: None (695, the ruling, is completed)
**Sources/Inputs**: - `specs/decisions/slice-command-one-path-to-review.md` (the ruling); `specs/state.json` and `specs/archive/state.json`; the source store `agent-system/extensions/core/**` at `5b2db2a9b`; `commands/task.md`, `commands/revise.md`, `scripts/update-task-status.sh`, `scripts/state-write.sh`. No web sources were needed.
**Artifacts**: - specs/698_slice_build_task_set/reports/01_slice-build-task-set.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The ruling's six successors are confirmed as six needed new records: no record exists for any
  of them, and successor 4 cannot be `/revise 692` because 692 is `completed`.
- **Two ordering claims carried by the ruling and by this task's description are false against
  the live tree.** Successor 3 ("delete the inference route") is carried as "ordered after
  nothing; it has no caller". It now has a caller: 692 closed as written and wired
  `scripts/milestone-review-handoff.sh` to call `review-stack-prepare.sh`, and 690 re-pointed two
  context documents to cite that script as the live ref-plumbing implementation. Successor 3
  must be ordered after successor 4 (and so after successor 1).
- Three statuses in the ruling's verdict table have moved: 690 is `completed` (ruling: not
  started), 692 is `completed` (ruling: planned), 693 is `abandoned` and archived. Of 694's four
  edges, only the one onto 693 actually dangles; 691, 692 and 695 are satisfied.
- File-state figures in the description are confirmed, with two corrections: the handoff script
  is 366 lines, not the ruling's 299; and 2 of the 10 `review_base` lines in
  `repo-level-declarations.md` sit in the Overview (lines 16, 19), outside the section the ruling
  names for deletion (331 to 367).
- Recommended set: six new records and two description revisions, joined by fifteen edges, with
  the creation order S1, S6, S2, S4, S3, S5, then edges, then the revisions of 694 and 655.
- No edge-removal flag exists in `update-task-status.sh` (confirmed); removing 694's stale edges
  is a `state-write.sh` filter.

## Context & Scope

Scope is the task SET: which records to create, which to revise, their territory, their edges,
and the order of the writes. No successor is designed in detail or implemented. Every ordering
claim and figure in the task description was re-derived from `specs/state.json` and the source
store rather than carried. Paths below are relative to `agent-system/extensions/core/` unless
they start with `specs/`.

Successors are named S1 to S6 after the ruling's "Successors" table. `next_project_number` is
699 at the time of reading, so the records would be 699 to 704 if nothing else is created first;
the plan must read each allocated number back rather than assume it.

## Findings

### Codebase Patterns

#### Live status of every record the ruling names

Read from `specs/state.json` (`active_projects`) and `specs/archive/state.json` at `5b2db2a9b`.

| Record | Ruling read | Live | Consequence |
|---|---|---|---|
| 692 `handoff_prints_review_stack` | planned | **completed**, as written | Terminal; successor 4 needs a new record. Its work is the thing S4 now undoes |
| 693 `merge_command_stack_mode` | planned | **abandoned**, archived | Verdict applied. Not in `active_projects`, so an edge onto it dangles |
| 690 `milestone_ref_land_recreates_retired_ref` | not started | **completed** | Verdict applied; `milestone-ref-land.sh` and its suite are absent from the tree |
| 691, 695 | completed | completed | Unchanged |
| 697 `case_h_assertion_review_stack_refusal_arm` | not in ruling | completed | Retargeted Case H of `test-orchestrate-conclusion-roadmap.sh` to the handoff's refusal arm; S4 must retarget it again |
| 694 | not started; deps 691, 692, 693, 695 | not started; same deps; `roadmap_ext_blocked: true` | To revise and re-edge |
| 655 | not started; deps 513, 517, 553, 654, 657 | same; 517, 654, 657 completed; 513, 553 not started | To revise |
| 670, 671, 672, 674, 686 | hold | hold | The ruling's "abandon" verdict has not been applied. Outside this task's stated scope; noted only |

Neither 694 nor 655 has a `plans/` directory, so `/revise` takes its Description Update path for
both.

#### File-state figures, re-derived

| Claim carried | Live | Verdict |
|---|---|---|
| `commands/slice.md` does not exist; nothing names `/slice` or `slice_bar` in the store | absent; `grep -rlE '(^|[^a-zA-Z/.-])/slice\b|slice_bar'` over `agent-system/extensions` returns nothing | confirmed |
| `review-stack-prepare.sh` is 74 KB | 74,125 bytes, 1,572 lines; suite 63,760 bytes, 1,136 lines | confirmed |
| 10 `review_base` occurrences remain in `repo-level-declarations.md` | 10 lines (11 tokens): lines 16, 19, 331, 335, 357 to 360, 363, 364 | confirmed, but lines 16 and 19 are in the Overview, outside the section at 331 to 367 |
| The review-manifest row of `orchestrator-runtime-files.md` | present, line 69 | confirmed |
| `milestone-review-handoff.sh` is 299 lines | 366 lines; suite 399 lines | **moved** (692 added the stack call) |
| `commands/merge.md` 485 lines | 485 | confirmed |
| E7: 27 files mention `/merge` | 27 by the ruling's stated search | confirmed (24 in `core`, 2 in `cslib`, 1 in `approvals`) |
| `/merge` minting branch in `hooks/please-grant.sh` | lines 64 and 82 to 88 | confirmed |
| Grant matched against `git rev-parse HEAD` | `scripts/lib/push-grant-lib.sh` line 453; expiry default 600 at line 101 | confirmed |
| `milestone-ref-land.sh` and suite | absent; no reference to the name remains anywhere in the store | already deleted by 690 |
| Local `master` ahead of `origin/master` | 398 ahead, 0 behind (ruling: 344) | a real difference exists for S1's acceptance; 12 merged pull requests on the forge |

The E7 count is self-derived by one pattern only (the ruling's own); it was not cross-checked
with a second, differently shaped pattern. ENUMERATION-UNVERIFIED for the purpose of S5's
work-list: S5's own research must re-enumerate.

#### Ordering claims, re-derived

**S3 is not independent.** `grep -rl review-stack-prepare` over the store returns eleven files.
Beyond the script, its suite and their two registration rows (`manifest.json` lines 319 and 478,
`suite-classification.data` line 196), the live references are:

| File | What depends on the script |
|---|---|
| `scripts/milestone-review-handoff.sh` | Calls it (`rsp_script`, line 81; `cut` then `show`). A missing script takes the refusal arm (`script_missing`, line 262), so deletion degrades instead of crashing, but the success arm and its cases die |
| `scripts/tests/test-milestone-review-handoff.sh` | Cases for both arms; also the only suite outside the script's own that names `review_base` |
| `scripts/tests/test-orchestrate-conclusion-roadmap.sh` | 3 references (Case H, retargeted by 697) |
| `context/patterns/ref-plumbing-landing.md` (2), `context/standards/git-workflow-narrative.md` (1) | Cite the script as the live implementation of the ref-plumbing idiom (written by 690) |
| `context/standards/repo-level-declarations.md`, `context/standards/orchestrator-runtime-files.md` | The section and the row the ruling already lists |

So deleting the script before S4 narrows the handoff leaves a live caller pinned to its refusal
arm and two suites asserting behaviour that no longer exists; and deleting it before S1 leaves
`ref-plumbing-landing.md` with no live implementation to cite. S3 is ordered after S4, which is
after S1. S3's territory also grows by the two context documents.

**S4 undoes 692, and its suite territory is wider than the ruling's row.** The handoff today
writes `review.ref` (line 48), calls the stack builder, and prints `/please push` on the refusal
arm (lines 331, 360). `review.ref` is named in seven files:
`context/contracts/conclusion-stage.md`, `context/formats/roadmap-entry-template.md`,
`context/formats/roadmap-format.md`, `context/standards/git-workflow-narrative.md`, the handoff,
its suite, and `test-orchestrate-conclusion-roadmap.sh`. S4's territory is therefore the
ruling's three files plus `test-orchestrate-conclusion-roadmap.sh` and, for the dropped field,
the two roadmap format documents. `scripts/orchestrate-conclusion-roadmap.sh` itself names none
of these and needs no edit.

**Shared files that force edges** (unordered overlap gets an edge, per the batching rule):

| File | Records | Edge chosen |
|---|---|---|
| `hooks/please-grant.sh` | S5, S6 | S5 after S6. S6 is independent and is the ruling's "recommended first"; S5 waits on an operator action anyway |
| `scripts/milestone-review-handoff.sh`, its suite, `context/contracts/conclusion-stage.md`, `test-orchestrate-conclusion-roadmap.sh` (all in E7's 27) | S4, S5 | S5 after S4, so S5 does not rewrite `/merge` lines S4 removes |
| `scripts/review-stack-prepare.sh` and its suite (both in E7's 27) | S3, S5 | S5 after S3, so S5 does not rewrite files being deleted; its work-list drops to 25 |
| `context/standards/repo-level-declarations.md` | S2 (adds `slice_bar`), S3 (deletes `review_base`) | S3 after S2. S2 carries a capability; S3 is cleanup and already waits on S4 |
| `context/standards/git-workflow-narrative.md` | S3, S4, S5; also listed in 655's stale `file_scope` | Covered by S3 after S4 and S5 after S3. 655's listing is an over-claim its own description already flags |
| the new `/slice` script | S1, S2, and 655 once it wires generated paths into the count | S2 after S1; 655 after S2 (below) |
| `manifest.json`, `suite-classification.data` | S1 (adds rows), S3 (removes rows), S5 (removes `merge.md` row) | Covered transitively |

**The 655 edge.** The ruling's phrase is "a hard edge from the *accuracy* of the bar onto 655,
not from its existence". Read against "The size bar" ("until it exists every path counts and
prompt 2 says so"), S2 is buildable and correct-as-specified without 655. Making S2 depend on
655 would put the bar behind 513 and 553, both `not_started` with unfinished predecessors of
their own, which contradicts "not from its existence". The edge that expresses the ruling is
the reverse: 655 gains a dependency on S2, because 655's declaration is what the bar's line
count consumes and wiring it touches the script S2 owns. 655's existing edges onto 513 and 553
are left as they are; its description already says they are to be re-judged at plan time.

**The "one real pull request" precondition on S5 is not expressible as an edge.** An edge is
satisfied when its predecessor reaches `completed`. An agent cannot push or open a pull request
(`rules/pr-prohibition.md`), so S1's last acceptance step is the operator's. Two measures keep
the ruling's order: S1's description states that the record does not close on a green suite and
that its final step is operator-performed, with the opened pull request recorded in the series
file; and S5's description carries its own precondition, checkable at dispatch, that a pull
request opened by `/slice` exists. The edge S5 after S1 is still written.

#### Tooling for the writes

- **Create**: `commands/task.md` Create Task Mode. It has two interactive steps (topic
  assignment, and a backlog-audit confirmation that fires only on a non-`genuinely-new`
  verdict), allocates from `next_project_number`, writes through `state-write.sh`, and never
  sets `file_scope`. 698 carries topic `core-agent-system`.
- **Revise a description from a dispatched agent**: `commands/revise.md` states that a
  dispatched agent must not invoke `skill-reviser` directly and should follow the mechanical
  route in `skills/skill-reviser/SKILL.md` Stage 7, "For Description Update", which calls
  `state-write.sh`. `/revise` has no terminal-status abort, but 692 is not revised: its
  deliverable is built, and S4 is new work.
- **Add an edge**: `update-task-status.sh preflight <dependent> edge_only <session>
  --depends-on-add='[<predecessors>]'` for a `not_started` task. The positional number is the
  dependent. Every predecessor must exist in `active_projects`; the write refuses a cycle.
  Confirm afterwards with `orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json
  <numbers>`.
- **Declare territory**: `--file-scope-add=<json-array>` on the same script.
- **Remove an edge**: no flag exists (`grep` for `depends-on-remove` in
  `update-task-status.sh` and `state-write.sh` returns nothing). The route is a `state-write.sh`
  filter of the shape `(.active_projects[] | select(.project_number == 694) | .dependencies) |=
  (. - [692, 693])`.

### External Resources

None used. Every question was answerable from the ruling, the state file and the source store.

## Recommendations

### The task set

Six new records, all `task_type: meta`, topic `core-agent-system`. Each description opens with
the standard source-store paragraph (edit `agent-system/extensions/core/**`, redeploy with
`deploy-headless.sh`, no task numbers and no record-versioning language in deliverables) and
cites the ruling by section name.

| # | Proposed slug | Cites | Territory (`file_scope`) | Depends on |
|---|---|---|---|---|
| S1 | `slice_command_build` | "The command surface", "The mechanism", "Basis", "Successors" row 1 and the acceptance paragraph | new `commands/slice.md`; one new script and its suite; `manifest.json`; `scripts/tests/suite-classification.data` | nothing |
| S6 | `bind_push_grant_to_pushed_ref` | "Grants" item 1; E7 | `hooks/please-grant.sh`; `hooks/guard-git-push.sh`; `scripts/lib/push-grant-lib.sh`; their suites (`test-please-grant.sh`, `test-guard-git-push.sh`) | nothing |
| S2 | `slice_bar_measurement_and_declaration` | "The size bar" | the `/slice` script and suite; `context/standards/repo-level-declarations.md` | S1 |
| S4 | `narrow_handoff_to_print_slice` | "One survivor, and what is deleted" row 3; "Successors" row 4 | `scripts/milestone-review-handoff.sh`; `scripts/tests/test-milestone-review-handoff.sh`; `scripts/tests/test-orchestrate-conclusion-roadmap.sh`; `context/contracts/conclusion-stage.md`; `context/formats/roadmap-format.md`; `context/formats/roadmap-entry-template.md` | S1 |
| S3 | `delete_review_stack_inference_route` | "One survivor, and what is deleted" rows 2; "What is discarded" | `scripts/review-stack-prepare.sh`; its suite; `manifest.json`; `suite-classification.data`; `context/standards/repo-level-declarations.md` (the section and Overview lines 16 and 19); `context/standards/orchestrator-runtime-files.md` (row at line 69); `context/patterns/ref-plumbing-landing.md`; `context/standards/git-workflow-narrative.md` | S4, S2 |
| S5 | `remove_merge_command` | "One survivor" rows 4; "Constraints held"; E7 | `commands/merge.md`; `hooks/please-grant.sh`; `rules/pr-prohibition.md`; `rules/state-management.md`; `merge-sources/claudemd.md`; `templates/claudemd-header.md`; the remaining files of E7's list, re-enumerated at its own research | S1, S3, S4, S6 |

What each description must say beyond its row:

- **S1.** Acceptance is not a suite count. The record ends with one real slice of a real
  difference, pushed by a typed grant and opened as a pull request by the operator typing
  `/slice`; an implementing agent stops short of that step and returns without closing the
  record. The script contains no push and no forge call, and its suite asserts that statically.
  The shipped default bar (1,500 lines, 30 files, printed `default, unmeasured`) belongs here;
  measurement and the declaration are S2.
- **S2.** Declared `slice_bar` first, then the nearest-rank 75th percentile over at least five
  merged pull requests on the chosen target, then the default. Every path counts until the
  generated-path declaration exists, and the prompt says so. No number appears in a deliverable
  as a property of the system.
- **S3.** State plainly that the script has a live caller until S4 lands, and that the two
  context documents are re-pointed to the `/slice` script. Name the Overview lines.
- **S4.** New record, not a revision: the handoff keeps detecting a finished milestone once and
  drafting the summary; it prints the one line `/slice`; it drops the `review-stack-prepare.sh`
  call, both `/please push` lines and the `review.ref` write; `review.state` stays as its
  fired-once marker. Case H of `test-orchestrate-conclusion-roadmap.sh` is retargeted.
- **S5.** Dispatch precondition, checked before any edit: a pull request opened by `/slice`
  exists. The rule text changes the name `/merge` to `/slice` and nothing else. The two `cslib`
  files and `approvals/README.md` are in the 27 and sit in other extensions.
- **S6.** A grant for a ref other than the checked-out branch binds to that ref's commit instead
  of `HEAD`. Independent of `/slice`; lowers S1's acceptance cost in a repository with live
  orchestration.

### The edges

Fifteen edges (eight among the new records, one onto 655, six onto 694), written only after all six records exist:

- S2 after S1
- S4 after S1
- S3 after S4, S3 after S2
- S5 after S1, S5 after S3, S5 after S4, S5 after S6
- 655 after S2
- 694 after S1, S4, S5 (the ruling's "after 1, 4 and 5"), plus S2, S3 and S6 so doc parity and
  the line-count reconciliation run once, last

S1 and S6 have no predecessors and can be dispatched together at once; their territories do not
overlap. The longest chain is S1, S2, S3, S5, 694.

On 694, remove 692 and 693 from `dependencies` (693 is the edge that dangles; 692 is satisfied
but names a record whose deliverable S4 undoes). 691 and 695 are satisfied and may stay.

### The two revisions

- **694** (Description Update). Replace the whole body: it currently owns doc parity for
  `/merge` stack mode and a runbook ending in `/merge --stack`, both overturned. New scope: doc
  parity for `/slice` across `README.md`, `merge-sources/claudemd.md` and
  `docs/guides/user-guide.md`; redeploy and `index-entries.json` line-count reconciliation; the
  operator runbook for the slice route (N typed `/please push` lines, then `/slice`; grant
  count and window as they stand after S6); acceptance is one real slice pushed and opened by
  the operator in a second repository. Its `file_scope` already fits. Its
  `roadmap_ext_blocked` flag and annotation belong to the roadmap pass, not to this task.
- **655** (Description Update). Replace the "PRIORITY RAISED" paragraph, which grounds the
  record on S1, S2 and S4 of the slices record, with the ground the ruling gives: the
  generated-path declaration has a second consumer, the `/slice` bar's line count ("The size
  bar", "What is counted"), and until it exists every path counts. The rest of the description
  stands.

### Order of the writes

1. Create S1, S6, S2, S4, S3, S5, reading back each allocated number.
2. Add `file_scope` to each.
3. Write the edges among S1 to S6, then 655 after S2.
4. Revise 694; remove its edges onto 692 and 693; add its new edges.
5. Revise 655.
6. Regenerate `TODO.md`; run `validate-state.sh --deep` and the cycle-plan dry run over the
   eight records.

## Decisions

- Successor 4 is a new record. 692 is not revised.
- S3 is ordered after S4 and S2, overturning "ordered after nothing; independent of 1".
- S5 is ordered after S6, S4 and S3 as well as S1.
- The 655 edge runs from 655 onto S2, not from S2 onto 655.
- The "one real pull request" condition is carried in S1's and S5's descriptions, with the S5
  after S1 edge, since no edge can express an operator action.
- The five held records (670, 671, 672, 674, 686) are left untouched; their abandonment is on
  the ruling's operator worklist and is not part of this task's stated scope.

## Risks & Mitigations

- **S1 closes on a green suite.** Then S5's edge is satisfied without a pull request. Mitigation:
  S1's description forbids it and S5 carries its own dispatch-time check.
- **Interactive steps in `/task`.** Topic assignment and a possible backlog-audit prompt cannot
  be answered by a dispatched agent. The plan must settle the non-interactive route
  (`docs/reference/standards/multi-task-creation-standard.md` was not read in this pass) before
  the first create.
- **Backlog audit may flag S4 against the closed 692, or S3 against 691.** Expected; both are
  genuinely new work that reverses a closed deliverable, and the descriptions should say so.
- **Numbers drift.** Another session can allocate 699 first. Never hard-code a successor number
  in a description; cite slugs, as the ruling does.
- **Concurrent writers.** Other orchestrations are live in this repository; every write goes
  through `state-write.sh` or `update-task-status.sh`, never a hand-rolled `jq` rewrite.
- **The S3 after S2 choice delays cleanup behind the bar.** If the operator would rather delete
  first, the edge can be reversed with no other change, since the overlap is one document.

## Context Extension Recommendations

none (meta task)

## Appendix

Searches run, over `agent-system/extensions` unless stated:

- `grep -rlE '(^|[^a-zA-Z/.-])/merge\b'` (27 files); `grep -rln 'review-stack-prepare'` (11);
  `grep -rl 'review_base\|review-base'` (4); `grep -rl 'review\.ref\|review_ref'` in `core` (7);
  `grep -rln 'milestone-ref-land'` (0); `grep -rlnE '(^|[^a-zA-Z/.-])/slice\b|slice_bar'` (0).
- `wc -l` and `wc -c` on each named file; `grep -n` for line references in
  `hooks/please-grant.sh`, `scripts/lib/push-grant-lib.sh`, `scripts/milestone-review-handoff.sh`.
- `jq` over `specs/state.json` and `specs/archive/state.json` for status, dependencies,
  descriptions and completion summaries of 509, 513, 517, 553, 654, 655, 657, 669 to 674, 685,
  686, 690 to 698.
- `git rev-list --left-right --count origin/master...master`; `gh pr list --state merged`.

Not verified in this pass: the content of `skills/skill-reviser/SKILL.md` Stage 7 and of the
multi-task creation standard (both named by path only); whether the backlog audit will flag any
proposed record.
