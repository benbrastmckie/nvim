# Foreground Creation Runbook: the `/slice` Build Task Set

This runbook turns `records/01_task-set-packet.json` into six task records and sixteen
dependency edges. It was written by the `slice_build_task_set` implementation dispatch, which
created no record and wrote no edge: confirmed task creation is a foreground-only operation
(`docs/reference/standards/multi-task-creation-standard.md`, "Requesting a Proposal Packet, Not
Filing, From an Autonomous Dispatch").

**Who may run it.** The operator, or an agent session acting as a foreground surface with the
operator's confirmation of section 2 in that same session. A dispatched subagent may not.
Nothing here pushes, opens a pull request or closes a record. The closing step of
`slice_command_build` and every push stay the operator's (`rules/pr-prohibition.md`).

**Inputs** (all under `specs/698_slice_build_task_set/records/`):

| File | Holds |
|---|---|
| `01_task-set-packet.json` | six proposals keyed by slug: title, full description, `file_scope`, `depends_on_slugs`, `audit_note`; `creation_order`; `edges_onto_existing`; the state baseline |
| `01_audit-verdicts.ndjson` | one backlog-audit verdict line per slug, as the creation gate requires |
| `01_prior-descriptions.json` | the pre-revision entries of 694 and 655 |

Ruling: `specs/decisions/slice-command-one-path-to-review.md`.

## 1. The candidates

Topic `core-agent-system`, type `meta`. Paths are relative to `agent-system/extensions/core/`.
"Ruling #" is the row of the ruling's "Successors" table.

| Order | Slug | Ruling # | Scope | Territory | Ordered after |
|---|---|---|---|---|---|
| 1 | `slice_command_build` | 1 | The `/slice` script (`check`, `build`, `status`), the series file, `commands/slice.md` with both prompts and the open step, the suite. Acceptance: one real slice pushed by a typed grant and opened by the operator typing `/slice`; the implementing agent stops short and does not close the record | `commands/slice.md` (new), `manifest.json`, `scripts/tests/suite-classification.data`; the new script and suite once named | nothing |
| 2 | `bind_push_grant_to_pushed_ref` | 6 | A grant for a ref other than the checked-out branch binds to that ref's commit instead of `HEAD` | `hooks/please-grant.sh`, `hooks/guard-git-push.sh`, `scripts/lib/push-grant-lib.sh`, `scripts/tests/test-please-grant.sh`, `scripts/tests/test-guard-git-push.sh` | nothing |
| 3 | `slice_bar_measurement_and_declaration` | 2 | The declared `slice_bar` key and the nearest-rank 75th-percentile measurement; every path counts until a generated-path declaration exists | `commands/slice.md`, `context/standards/repo-level-declarations.md`, `index-entries.json`; the `/slice` script and suite | `slice_command_build` |
| 4 | `narrow_handoff_to_print_slice` | 4 | The handoff prints the one line `/slice`; drops the `review-stack-prepare.sh` call, the `/please push` lines and the `review.ref` write. Reverses the closed `handoff_prints_review_stack` deliverable | `scripts/milestone-review-handoff.sh`, its suite, `scripts/tests/test-orchestrate-conclusion-roadmap.sh`, `context/contracts/conclusion-stage.md`, `context/formats/roadmap-format.md`, `context/formats/roadmap-entry-template.md`, `index-entries.json` | `slice_command_build`, `slice_bar_measurement_and_declaration` |
| 5 | `delete_review_stack_inference_route` | 3 | Delete `review-stack-prepare.sh` and its suite, the `review_base` section and its two Overview sentences, the review-manifest row; re-point two context documents | the two deleted files, `manifest.json`, `suite-classification.data`, `context/standards/repo-level-declarations.md`, `context/standards/orchestrator-runtime-files.md`, `context/patterns/ref-plumbing-landing.md`, `context/standards/git-workflow-narrative.md`, `index-entries.json` | `narrow_handoff_to_print_slice`, `slice_bar_measurement_and_declaration` |
| 6 | `remove_merge_command` | 5 | Delete `commands/merge.md`, remove the `merge` minting branch, rewrite every remaining reference to `/slice`. Dispatch precondition: a pull request opened by `/slice` exists | 24 paths in the packet, three of them in the `approvals` and `cslib` extensions; re-enumerated by its own research | `slice_command_build`, `delete_review_stack_inference_route`, `narrow_handoff_to_print_slice`, `bind_push_grant_to_pushed_ref` |

Edges onto existing records:

- `branch_aware_orchestration_and_squash_landing` (655) gains a dependency on
  `slice_bar_measurement_and_declaration`.
- `stack_pr_redeploy_and_second_repo_demo` (694) loses its edges onto 692 and the abandoned 693
  and gains one onto each of the six new records.

Sixteen edges: nine among the new records, one onto 655, six onto 694.

**Where this differs from the ruling and from this task's own plan.**

- Ruling: successor 3 "ordered after nothing; it has no caller". False against the tree:
  `scripts/milestone-review-handoff.sh` calls the script. It is ordered after the handoff
  record and the bar record.
- Ruling: successor 2 has a hard edge onto 655. The edge is written the other way (655 after the
  bar record), because the ruling makes the bar's *accuracy*, not its existence, wait on 655.
- Ruling: successor 4 is "692, revised". 692 is `completed`, so it is a new record.
- Ruling: successor 5 after 1. It is also after the three records that edit files it rewrites.
- Plan: fifteen edges. The sixteenth, `narrow_handoff_to_print_slice` after
  `slice_bar_measurement_and_declaration`, exists only because both reconcile
  `index-entries.json`. It carries no design meaning; drop its line in section 5 to leave the
  two records overlapping on that one file, or reverse it.
- Ruling: `skills/skill-git-workflow/SKILL.md` names `/merge`. The ruling's own search finds no
  such mention there; it is left out of `remove_merge_command`'s territory.

**Audit disposition.** No proposal is `genuinely-new`. Each drew 200 to 300 verdicts, because
every description opens with the shared source-store paragraph and the matcher's semantic pass
is recall-biased. No match is a duplicate. Two are reversals of closed deliverables and are
stated as such in their descriptions: `narrow_handoff_to_print_slice` against
`handoff_prints_review_stack`, and `delete_review_stack_inference_route` against
`restack_review_stack_when_parent_merges`. Read each proposal's reasoning with:

```bash
jq -r '.proposals[] | "\(.id)\n  \(.audit_note)\n"' specs/698_slice_build_task_set/records/01_task-set-packet.json
```

Open records outside this set that share one file with a proposal are named in those notes
(for example `previous_work_section_in_generated_roadmap` shares two files with the handoff
record). No edge is proposed for them; sequence them at dispatch.

## 2. Confirmation owed before creating anything

The foreground surface shows the operator section 1 and asks one question covering the set:
create these six records, in this order, with these edges? The operator may drop a record, drop
or reverse the two territory-only edges (S4 after S2; S3 after S2), or cancel. One confirmation
stands in for the six per-task backlog-audit prompts `commands/task.md` Create Task Mode would
otherwise raise: that is its documented pre-resolved-audit route (Step 5.5, "Non-interactive
caller escape valve"), with the verdict file as the evidence. Create nothing on anything other
than an explicit yes.

## 3. Pre-flight

Run from the repository root, on the integration branch, with no orchestration mid-write on
`specs/state.json`.

```bash
R=specs/698_slice_build_task_set/records
PKT=$R/01_task-set-packet.json
VER=$R/01_audit-verdicts.ndjson
source .claude/scripts/lib/common.sh
SID="$(common_session_id)"

# No record with any of the six slugs may exist yet. Expect no output.
jq -r --slurpfile p $PKT '.active_projects[] | select(.project_name as $n | $p[0].creation_order | index($n)) | "\(.project_number) \(.project_name) ALREADY EXISTS"' specs/state.json

# 655 and 694 must still be not_started with the dependencies the packet recorded.
jq -c '.active_projects[] | select(.project_number == 655 or .project_number == 694) | {project_number, status, dependencies}' specs/state.json
jq -c '.baseline.dependencies' $PKT
```

Stop if a slug already exists, or if 655 or 694 has left `not_started` or changed its
dependencies. `next_project_number` may have moved since the baseline; that is expected and no
command below assumes a number.

## 4. Create the six records

One write per record, in `creation_order`. Each write is the Step 6 write of
`commands/task.md` Create Task Mode, with three differences that the packet makes possible: the
slug is fixed to the packet's `id` (the verdict file is keyed by it), the number comes from
`--allocate-into`, and `file_scope` is written with the entry. `file_scope` is a creation-time
field; `update-task-status.sh --file-scope-add` is refused outside a research, plan or
implement postflight, so it cannot be added afterwards by that route.

```bash
: > /tmp/slice-set-map.tsv
for slug in $(jq -r '.creation_order[]' $PKT); do
  desc="$(jq -r --arg s "$slug" '.proposals[] | select(.id == $s) | .description' $PKT)"
  fs="$(jq -c --arg s "$slug" '.proposals[] | select(.id == $s) | .file_scope' $PKT)"
  bash .claude/scripts/state-write.sh \
    '.active_projects = [{project_number: $new_num, project_name: $slug, status: "not_started",
       task_type: "meta", description: $desc, topic: $topic, file_scope: $fs,
       created: $ts, last_updated: $ts}] + .active_projects' \
    --allocate-into new_num --session-id "$SID" \
    --arg slug "$slug" --arg topic core-agent-system --arg desc "$desc" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson fs "$fs" \
    --audit-verdict "$VER" --regen-todo || { echo "STOP: create failed for $slug"; break; }
  num="$(jq -r --arg s "$slug" '.active_projects[] | select(.project_name == $s) | .project_number' specs/state.json)"
  bash .claude/scripts/manage-topics.sh set "$num" core-agent-system || { echo "STOP: topic set failed for $num"; break; }
  printf '%s\t%s\n' "$slug" "$num" >> /tmp/slice-set-map.tsv
done
cat /tmp/slice-set-map.tsv     # six lines; this is the slug-to-number map
n() { awk -F'\t' -v s="$1" '$1 == s {print $2}' /tmp/slice-set-map.tsv; }
```

These six commands were run with `--dry-run` against the live state file when this runbook was
written and each returned 0, so the filter, the bindings and the audit-evidence gate are known
to pass. If a write stops part-way, the records already created stay; re-run the loop for the
remaining slugs only.

Each description says "add them to file_scope" for files its own plan names (the `/slice`
script and suite above all). That happens through the ordinary plan postflight, not here.

## 5. Write the edges among the new records, and 655

The positional number is the dependent; the array is its predecessors. Every predecessor must
already exist, which section 4 guarantees. A cycle is refused at write time.

```bash
dep() { bash .claude/scripts/update-task-status.sh preflight "$1" edge_only "$SID" --depends-on-add="$2"; }

dep "$(n slice_bar_measurement_and_declaration)" "[$(n slice_command_build)]"
dep "$(n narrow_handoff_to_print_slice)"         "[$(n slice_command_build),$(n slice_bar_measurement_and_declaration)]"
dep "$(n delete_review_stack_inference_route)"   "[$(n narrow_handoff_to_print_slice),$(n slice_bar_measurement_and_declaration)]"
dep "$(n remove_merge_command)"                  "[$(n slice_command_build),$(n delete_review_stack_inference_route),$(n narrow_handoff_to_print_slice),$(n bind_push_grant_to_pushed_ref)]"
dep 655                                          "[$(n slice_bar_measurement_and_declaration)]"
```

That is ten edges: 1 + 2 + 2 + 4 among the new records, and one onto 655. To drop the
territory-only edge named in section 1, write the second line with `slice_command_build` alone.

## 6. Re-edge 694, in one step

Removing 692 and 693 alone would leave 694 with satisfied predecessors only (691, 695) and
therefore dispatchable ahead of the build. Run both commands together; do not stop between
them. No edge-removal flag exists, so the removal is a `state-write.sh` filter.

```bash
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == 694) | .dependencies) |= (. - [692, 693])' \
  --session-id "$SID" \
&& dep 694 "[$(n slice_command_build),$(n bind_push_grant_to_pushed_ref),$(n slice_bar_measurement_and_declaration),$(n narrow_handoff_to_print_slice),$(n delete_review_stack_inference_route),$(n remove_merge_command)]"
```

Six edges, for sixteen in all. 694's `roadmap_ext_blocked` flag is the roadmap pass's to clear.

## 7. Validate

```bash
bash .claude/scripts/generate-todo.sh
bash .claude/scripts/validate-state.sh --deep
bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --state-file specs/state.json \
  $(cut -f2 /tmp/slice-set-map.tsv) 655 694

# Edge count among the new records: expect 9.
NEW="[$(cut -f2 /tmp/slice-set-map.tsv | paste -sd,)]"
jq --argjson new "$NEW" '[.active_projects[] | select(.project_number as $p | $new | index($p)) | (.dependencies // [])[]] | length' specs/state.json
# Edges from 655 and from 694 onto the new records: expect 1 and 6.
jq -c --argjson new "$NEW" '.active_projects[] | select(.project_number == 655 or .project_number == 694) | {project_number, dependencies, onto_new: ([.dependencies[] as $d | select($new | index($d))] | length)}' specs/state.json
```

Expected: `validate-state.sh --deep` shows no new failure (22 passed, 10 warnings, 0 failed at
the time of writing); the first count is 9; 655's dependencies are its former five plus the bar
record; 694's are 691, 695 and the six new numbers. Commit
`specs/state.json` and `specs/TODO.md` by the usual scoped route (never a whole-tree stage),
then run `/roadmap` so the eight records are batched.

## 8. What is dispatchable, and what stays the operator's

- `slice_command_build` and `bind_push_grant_to_pushed_ref` have no predecessors and share no
  file: dispatch them together, first. The longest chain after them is
  `slice_bar_measurement_and_declaration`, `narrow_handoff_to_print_slice`,
  `delete_review_stack_inference_route`, `remove_merge_command`, then 694.
- `slice_command_build` does not close on a green suite. Its implementing agent returns with
  the record open and the lines to type. The operator pushes one slice with a typed
  `/please push` and opens it with `/slice`; only then is the record closed.
- `remove_merge_command` checks for that pull request before it edits anything and returns
  blocked without one, whatever its edges say.
- 694's acceptance is one real slice pushed and opened by the operator in a second repository.
- Not part of this runbook: abandoning the five held records (670, 671, 672, 674, 686), which
  is on the ruling's own operator worklist.
