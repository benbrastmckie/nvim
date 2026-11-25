# Research Report: Task #669

**Task**: 669 - Add integration-branch admission and the isolation declaration
**Started**: 2026-11-23T09:26:03Z
**Completed**: 2026-11-23T09:32:55Z
**Effort**: Medium (one script edit site, one new library, two standards documents, one new suite)
**Dependencies**: 517, 541, 667, 668 (all completed)
**Sources/Inputs**: - `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (sections "R1, amended", "R2, amended", "R5, amended", "Isolation-off repositories", "Built-mechanism verdicts", "Cleanup and retention", "Successor tasks", "Edges"); `specs/decisions/branch-topology-and-landing-strategy.md` (R4); the source store under `agent-system/extensions/core/`; live `git` measurements in this repository at `d91ff2fc4`; a prototype admission predicate run against the live tree and fourteen scratch fixtures. No web source was needed.
**Artifacts**: - specs/669_integration_branch_admission_and_batch_worktree/reports/01_integration-branch-admission.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The admission gate has a clean, prose-free insertion point: `orchestrate-cycle-plan.sh` already
  emits a generic `stop` object that `skill-orchestrate` logs and routes to its conclusion moves
  for any reason string. A new stop reason needs no edit to either byte-ceiling file.
- The record's two-member state territory (`specs/` plus the declarations file) is measurably
  too small. Ordinary operation here also dirties `.memory/memory-index.json`, committed
  alongside the declarations file in every one of the four most recent `sync:`/`deploy:`
  commits. The recommended fixed set is `specs/`, `.claude-extensions.json`, `.memory/`.
- The record itself limits what an undeclaring repository gets: "A repository that declares
  nothing behaves as it does today, apart from the R1 branch check once `integration_branch` is
  declared." So both refusals arm only when `integration_branch` is declared; undeclared yields
  one named advisory and no refusal. This is where the record and the task description differ,
  and the record wins.
- Under that rule, this repository would be refused today if it declared the key: one sibling
  orchestration's uncommitted 37-line source-store edit and its derived index line-count sit
  outside any state territory. That is the gate working as ruled, and it is also the main
  operational cost; see Risks.
- The `worktree_isolation: batch` refusal is independent of everything else (no `git` needed)
  and should fire first.
- The batch record fits the existing "durable provenance, but untracked" disposition at
  `specs/.orchestration/batch/{session_id}.json`, out of the reaper's reach, with deferred
  fields grouped under an absent `isolation` object so adding them is a field write.
- Two inaccuracies in the task record need correcting at plan time: the `queue-check` gate is
  not in `orchestrate-cycle-plan.sh`, and the declared `file_scope` still names the worktree
  script that moved to the held task.

## Context & Scope

Researched: where admission can sit without adding prose to `skill-orchestrate/SKILL.md` (27,494
bytes) or `commands/orchestrate.md` (21,496 bytes); what the exact state-territory path set must
be; what admission does when `integration_branch` is undeclared; how the batch record should be
shaped, sited and registered; and how each element composes with task-lock, the session
registry, the orchestration queue and the batch width cap.

Out of scope by the narrowing: worktree creation, its siting, sparse checkout, the two-root
contract, landing, cleanup. Not researched.

Verified against isolation off only, as the description directs. `integration_branch` and
`worktree_isolation` are both undeclared in this repository (`jq keys .claude-extensions.json`
returns `extensions`, `version`), and this task declares neither.

## Findings

### Codebase Patterns

**1. Where the existing gates actually live.** The description says admission goes "beside the
existing lock probe and queue-check gates" in `orchestrate-cycle-plan.sh`'s preflight. Only one
of the two is there.

| Gate | Site | Once per |
|---|---|---|
| Blocking `queue-check` | `commands/orchestrate.md` lines 214-224, a bash block in the command file | invocation |
| `session-register`, `queue-register` | `skill-orchestrate/SKILL.md` lines 46-57 | invocation |
| Lock probe (`task-lock.sh check`) | `orchestrate-cycle-plan.sh` line 2188 | task, per cycle |
| Lock acquire | `orchestrate-cycle-plan.sh` line 2721 | task, per cycle |

The `queue-check` site cannot take the new gate, because that file is at its ceiling. The
cycle-plan script is the only admissible site, and it runs once per cycle, so the gate must make
itself once-per-invocation.

**2. The `stop` object is a generic channel.** `emit_and_exit()` (line 730) renders
`stop_reason`/`stop_message` into `{reason, message}`. `SKILL.md` line 124 reads: "If
`stop_json` is non-null: log `.reason`/`.message`, skip to Move 4". The named reasons there are
classified as success or partial, but the handling is by non-null, not by enum. A new reason
therefore reaches the operator verbatim and falls through to the conclusion moves, which release
the session entry and archive the queue record (`SKILL.md` line 389). No prose edit is needed.
Existing reasons, for naming consistency: `all_terminal`, `max_cycles`, `no_eligible_stuck`,
`max_infra_failures`, `convergence_guard`.

A stop composition builds no dispatch row, and `emit_and_exit()` writes the plan cache only when
at least one real dispatch row exists, so a refusal is never cached and a re-run re-evaluates.

**3. First-cycle detection is available without new state.** The script's multi-task state file
is session-scoped and created on first call. The batch record gives a sharper marker: admission
runs its full predicate when no batch record exists for this session, writes the record on
admit, and on every later cycle finds the record and skips the dirty test. That yields one
record per invocation by construction, which is item 4's requirement. Later cycles must skip the
dirty test regardless, because by then this invocation's own dispatches may have left
uncommitted work.

**4. The gate must sit before the first mutation.** `orchestrate_cycle_plan_main()` (line 850)
opens with the inter-cycle redeploy checkpoint, which can run `deploy-headless.sh`. Admission
must run before it, and after the plan-cache replay block (which exits early and can never fire
on a first call).

**5. `--dry-run` must stay mutation-free.** The header states dry-run "Mutates nothing". The
predicate is read-only and should run under dry-run and report its verdict through the same
`stop` object; the record write must be skipped.

**6. Dirty-tree prior art is advisory.** `orchestrate-batch-admit.sh` line 740 already computes
`git diff --name-only HEAD` and attaches a per-candidate `dirty_scope_advisory` where a
candidate's `file_scope` intersects it; the cycle-plan script files those in
`dirty_scope_ledger`. Nothing refuses on dirt today. The new gate is the first blocking use and
should reuse the same primitive so the two never disagree about what "dirty" means.

**7. Existing `integration_branch` readers.** Two, both inline, both with the advisory fallback
the description refers to: `milestone-ref-land.sh` line 146 and `milestone-review-handoff.sh`
line 75. Search pattern: `grep -rln 'integration_branch' agent-system/extensions --include=*.sh`
excluding `tests/`; cross-checked with `grep -rn '\.integration_branch'`, same two files.
Admission is the third reader. `repo-level-declarations.md` records "a second consumer is the
recorded trigger to promote it to `scripts/lib/`" for an inline reader, so a shared reader is
due. Both existing readers sit in the landing task's (673) `file_scope`, not this one; they
should be left alone here and migrated there.

**8. `repo-level-declarations.md` has no row for either key.** Its Overview enumerates three
schemas (`derived_artifact_probes`, `coupled_generated_surfaces`, `verification_scope`).
`worktree_isolation` appears nowhere in the source store as a key (the three textual hits are a
removal-guard in `test-askuserquestion-rehome.sh` matching
`task_selected_for_worktree_isolation` and `dispatch-worktree.sh`; neither new name collides).
`git-workflow-narrative.md` line 246 already describes the admission check as "a separate,
consumer-owned concern"; that sentence is the documentation-parity task's (675) to rewrite.

**9. The document's posture is fail-open, with one recorded exception.** Every schema carries a
fail-open-on-absence table. The single loud exception is a declared-but-unusable
`closing_gate`, justified as "a declared-but-unusable command never reads as a clean, empty
result". The `batch` refusal is the same shape and should cite that precedent by section name.

**10. Sandboxed suites constrain how the gate is delivered.** Most of
`test-orchestrate-cycle-plan.sh`'s 6,634 lines run in a non-`git` sandbox; one arm
(line 4882) makes the sandbox a real repository temporarily. Two consequences:

- A project root that is not a `git` work tree must skip the branch and dirty tests silently,
  or roughly thirty existing groups change behaviour.
- A new hard-sourced library must be added to every suite that copies an explicit library list
  beside the script. Two suites do: `test-orchestrate-cycle-plan.sh` (inline list, line 78) and
  `test-orchestrate-unwind-dispatch.sh` (`REQUIRED_LIB_SCRIPTS`). `test-force-phases.sh` copies
  `lib/*.sh` wholesale and needs no edit. Search: `grep -l 'orchestrate-cycle-plan.sh'
  scripts/tests/*.sh` filtered by a mention of `redeploy-checkpoint-lib.sh` gave four files;
  a second pattern (`task-classification-lib.sh`) gave three; reading the fourth
  (`test-redeploy-checkpoint-promotion.sh`) showed it sources a library directly and never
  sandboxes the script. The enumeration is two suites needing an edit, one of them outside the
  declared `file_scope`.

**11. Registration surfaces for new files.** `manifest.json`'s `provides.scripts` lists all 449
scripts including libraries and suites, so each new file needs an entry. `index-entries.json`
carries `line_count` for both standards documents (315 and 666 today, matching `wc -l`), so
editing them moves a derived value in a file outside the declared `file_scope`.

### Measurements

**M1. Blanket test versus scoped test, live tree.** `git diff --name-only HEAD` lists 29 paths.
Excluding `specs/`, `.claude-extensions.json` and `.memory/` leaves two:

```
agent-system/extensions/core/context/standards/git-staging-scope.md
agent-system/extensions/core/index-entries.json
```

The scoped query runs in 12 ms. The first path is a 37-line uncommitted edit; the second is a
one-line `line_count` change (1222 to 1259) for that same document, so it is derived dirt
caused by the first. Both fall inside the `file_scope` of a still-registered sibling
orchestration (`specs/.orchestration/queue/orch_1795400964_ec3249.json`, state `running`,
heartbeat 97 minutes old at measurement, one member task still `implementing`).

**M2. What ordinary operation dirties outside `specs/`.** The four most recent `sync:`/`deploy:`
commits (`1d7f1ed71`, `7e22cc1b0`, `f7722caf3`, `a67873b9c`) touch, outside `specs/`:

| Path | Commits (of 4) | Nature |
|---|---|---|
| `.claude-extensions.json` | 4 | deploy state; the record already names it |
| `.memory/memory-index.json` | 4 | memory retrieval counters; not named by the record |
| `agent-system/extensions/core/index-entries.json` | 3 | derived line counts; source-store owner only |
| two other extensions' `index-entries.json` | 1 | same |

`.memory/` is bookkeeping state written without any task editing it, in every repository that
has a memory vault. The `index-entries.json` files are different in kind: they exist only in a
repository that owns its source store, they change only when a context document changes, and
naming them would put a consumer-repository path into a deliverable. They are not state
territory.

**M3. Prototype predicate, scratch fixtures.** Script kept at
`/tmp/claude-1000/-home-benjamin--config-nvim/d68c911f-b4dd-4d06-a4bb-0e64b35ad336/scratchpad/admit-proto.sh`
(session-scoped; reproduce from the predicate in Recommendations if it is gone).

| # | Fixture | Verdict |
|---|---|---|
| 1 | declared, on branch, clean | admit |
| 2 | dirty only under `specs/` and `.memory/` | admit |
| 3 | plus an untracked file outside state territory | admit |
| 4 | staged new file outside state territory | refuse, names the path |
| 5 | staged rename | refuse, names the new path |
| 6 | working-tree deletion | refuse, names the path |
| 7 | on another branch | refuse, names both branches |
| 8 | detached `HEAD` | refuse |
| 9 | `worktree_isolation: "batch"` | refuse |
| 10 | `worktree_isolation: "on"` (unknown value) | refuse |
| 11 | `worktree_isolation: "off"` | admit |
| 12 | `integration_branch` undeclared | advisory, no refusal |
| 13 | unborn branch (no commit) | branch test passes; no dirty test possible |
| 14 | not a `git` work tree | skip |

Fixture 3 is deliberate: R1 says "tracked paths", and `git diff HEAD` reports tracked changes
and staged additions only. Fixture 8 needs `git symbolic-ref -q --short HEAD`; the two existing
readers use `git rev-parse --abbrev-ref HEAD`, which prints the literal `HEAD` when detached and
would compare that string against a branch name.

**M4. Primary-root resolution survives the deferred worktree.** From a linked worktree,
`git rev-parse --path-format=absolute --git-common-dir` returned the primary repository's
`.git` directory. A record sited under the primary tree's `specs/` is therefore reachable from
a future batch worktree without deriving any path, which is what R2 requires of it.

### External Resources

None consulted. Every question was answerable from the two decision records, the source store
and live `git`.

## Recommendations

**R-1. Site.** One function in the cycle-plan script, called after the plan-cache replay block
and before `orchestrate_cycle_plan_main`'s redeploy checkpoint. It sets `stop_reason` and
`stop_message` and calls `emit_and_exit`. No edit to `SKILL.md` or `commands/orchestrate.md`.

**R-2. Predicate, in this order.**

1. Read `worktree_isolation`. Absent or `"off"`: continue. `"batch"`: stop with
   `isolation_unimplemented`. Any other value, or a non-string: stop with the same reason and a
   message naming the bad value. This step needs no `git` and runs every cycle.
2. Not inside a `git` work tree: skip the rest, silently.
3. Read `integration_branch`. Undeclared, empty or non-string: print one advisory naming the
   key, the declarations file and the checked-out branch, on the first cycle only; no refusal;
   continue to the record write with `integration_branch_declared: false`.
4. Declared: compare with `git symbolic-ref -q --short HEAD`. Mismatch or detached: stop with
   `off_integration_branch`, naming both. This runs every cycle, since R1 says the primary tree
   is "never switched during orchestration".
5. Declared, first cycle only (no batch record for this session): `git diff --name-only -z HEAD`
   with the state territory excluded by pathspec. Non-empty: stop with `dirty_primary_tree`,
   listing every path.
6. Admit: write the batch record (not under `--dry-run`).

Suggested stop reasons: `isolation_unimplemented`, `off_integration_branch`,
`dirty_primary_tree`. The `isolation_unimplemented` message must name the held task by its slug,
`batch_worktree_creation_when_isolation_on`, never by number: deliverables under
`agent-system/` may not carry task numbers, and the amending record notes slugs are not
reassigned at a renumber.

**R-3. State territory, exact set.** Three repository-root-relative members, fixed in code and
stated in the schema document:

- `specs/` (the whole directory)
- `.claude-extensions.json`
- `.memory/` (the whole directory)

Carries no repository-specific path. `.claude/` needs no entry where it is ignored, and
untracked content is never tested. *Checked against the live corpus: with this set the live tree
reports two paths, both real source-store dirt (M1); with the record's two-member set it would
additionally report `.memory/memory-index.json` whenever retrieval counters have moved since the
last sync commit (clean at measurement time, dirty in 4 of the last 4 sync commits).*

**R-4. Undeclared behaviour.** Advisory only, both refusals disarmed, as the record's R5 and
"Isolation-off repositories" sections state. The verification criterion "refused at admission"
is then proven in a fixture that declares the key. The schema row should say in one sentence
that declaring `integration_branch` is what arms admission.

**R-5. Batch record.** Path `specs/.orchestration/batch/{session_id}.json`, resolved by a new
`runtime_batch_record_path` beside the four existing per-session resolvers in
`lib/runtime-file-patterns.sh`. Suggested shape:

```json
{
  "schema": 1,
  "session_id": "sess_...",
  "orchestration_id": "orch_... or null",
  "task_numbers": [1, 2],
  "admitted_at": "ISO-8601",
  "integration_branch": "name",
  "integration_branch_declared": true,
  "integration_tip_at_cut": "40-hex",
  "worktree_isolation": "off",
  "landing_proofs": []
}
```

- The deferred batch-branch name and absolute worktree path go under a single `isolation`
  object that is absent here. Adding it later is one field write and no existing reader changes;
  the registration row should say exactly that.
- `landing_proofs` is an empty array this task creates and never appends to. The landing task
  owns the element shape; this task should fix only that it is an append-only array keyed by
  task number, written under the existing `specs/.commit-lock` mutex R3 already names.
- `task_numbers` is recorded because a resumed batch gets a new session identity, and the held
  task's idempotence-on-resume will need to find an earlier record by membership.
- Disposition: the same third disposition the queue archive row has, durable provenance but
  untracked. The existing `**/.orchestration/` ignore pattern covers it, and the reaper's globs
  are literal filenames directly under `specs/.orchestration/` (lines 146-153 of
  `reap-session-runtime-files.sh`), so a subdirectory is out of its reach. No new ignore-pattern
  class member is needed.
- Written with the tmp-file-then-rename idiom the multi-task state file uses.
- Not written in a non-`git` project root.

**R-6. Delivery shape.** A new library, for example `scripts/lib/batch-admission-lib.sh`,
holding the two declaration readers, the predicate and the record writer, plus its own suite.
The landing, worktree and cleanup tasks all read or extend the record, which is the recorded
trigger for a shared library over an inline reader. The cycle-plan suite gains a small group
that runs the real script in a temporary `git` fixture, following the line-4882 precedent.

**R-7. `file_scope` to re-declare at plan time.**

| Change | Path | Why |
|---|---|---|
| remove | `scripts/batch-worktree.sh`, `scripts/tests/test-batch-worktree.sh` | belong to the held worktree task (686) after the narrowing |
| add | `scripts/lib/batch-admission-lib.sh`, `scripts/tests/test-batch-admission-lib.sh` (names illustrative) | R-6 |
| add | `scripts/lib/runtime-file-patterns.sh` | the path resolver |
| add | `scripts/tests/test-orchestrate-unwind-dispatch.sh` | its explicit library list (finding 10) |
| add | `index-entries.json` | `line_count` for both edited documents (finding 11) |

All under `agent-system/extensions/core/`. `manifest.json` is already declared. A redeploy
phase is required after the source-store edits.

**R-8. Schema rows.** Two new sections in `repo-level-declarations.md`, plus the Overview
sentence and See Also entries. Each states: type, values, default, which values are live, and
the fail-open table. `worktree_isolation` documents `batch` as declared but not implemented,
names the held task by slug, and cites the `closing_gate` exception as precedent for refusing
loudly. The state-territory list lives in the `integration_branch` section.

## Decisions

- Both refusals arm only when `integration_branch` is declared. Basis: the record's R5 and
  Option L1 text, which the description defers to.
- State territory is `specs/`, `.claude-extensions.json`, `.memory/`. Basis: M2.
- Source-store `index-entries.json` files are not state territory. Basis: repo-agnostic
  constraint, and they are derived from real edits.
- No exemption for dirt owned by a live sibling orchestration. Basis: R1 has none, and inventing
  one would weaken a ruled refusal. The refusal message should name the owning orchestration
  when a queue record's `file_scope` covers a dirty path, as a diagnostic only.
- An unknown `worktree_isolation` value refuses like `batch`. Basis: the same reasoning the
  description gives for `batch`, a repository must not ask for a mode and get silence.
- The dirty test runs on the first cycle of an invocation only; the branch test runs every cycle.
- No `user_decision` is raised. Every choice above is settled by the record or by measurement
  and is reversible inside the repository.
- The dispatch composer is not touched. Nothing a dispatched agent does depends on the record
  until the two-root work lands.

## Risks & Mitigations

- **A declaring repository serialises on stranded work.** M1 shows the live tree would be
  refused. Any orchestration with an implement dispatch mid-phase blocks the start of another in
  the same tree, and a crashed one blocks until someone commits or snapshots its leftovers. This
  is what R1 rules, and no repository is affected until it declares the key. Mitigation: the
  refusal lists every path and, where a queue record claims it, the owning orchestration, so the
  operator knows whether to wait or clean up. Not mitigated: the cost itself. If it proves too
  high in practice, the remedy is a dated amendment to the record, not a quiet exemption here.
- **The real-`git` arm of the cycle-plan suite.** It commits `specs` and `.claude` and then runs
  the script. With the key undeclared it gets an advisory line on standard error and no refusal.
  Any assertion on exact standard-error content there would need checking. Not checked in this
  dispatch.
- **Refusal after registration.** The session and queue entries are registered before the
  cycle-plan script runs. A refused invocation relies on the conclusion moves to release them.
  `SKILL.md` routes every non-null `stop` there, but a test should assert that a refused run
  leaves no live queue record.
- **Shared files with held and open tasks.** `orchestrate-cycle-plan.sh`, its suite,
  `orchestrator-runtime-files.md` and `manifest.json` are also in the held worktree task's
  scope, and `manifest.json` in the landing task's. The edges (686 and 673 both depend on 669)
  already order them.
- **Removal-guard test.** `test-askuserquestion-rehome.sh` fails if `dispatch-worktree.sh` or
  `task_selected_for_worktree_isolation` reappears under `agent-system/`. The names proposed
  here do not match; any renaming should keep clear of both strings.
- **`guard-destructive-git.sh` judges the primary tree.** Observed while building fixtures: a
  `git checkout -- <path>` aimed at a scratch repository was refused because this repository's
  tree is dirty. A suite for this task must build its fixtures without the discard forms
  (`git show HEAD:path > path` worked).

## Context Extension Recommendations

none (meta task)

## Appendix

**Queries and commands used**

- `grep -rln 'integration_branch\|worktree_isolation' agent-system/extensions/core`
- `grep -rn 'queue-check' agent-system/extensions/core` (files only), then line reads of
  `commands/orchestrate.md` 195-240 and `skills/skill-orchestrate/SKILL.md` 36-70, 108-132
- `git diff --name-only -z HEAD -- . ':(exclude)specs' ':(exclude).claude-extensions.json' ':(exclude).memory'`
- `git log -1500 --format='@@%s' --name-only` classified by subject prefix; `git show --name-only`
  on the four sync/deploy commits
- `jq` over `specs/.orchestration/queue/*.json` for `file_scope` membership of the dirty paths
- `git rev-parse --path-format=absolute --git-common-dir` from a linked scratch worktree
  (created and removed inside the session scratchpad)

**Key line references** (source store, at `d91ff2fc4`)

- `scripts/orchestrate-cycle-plan.sh`: 330 project root, 570-640 state-file defaults, 660-675
  plan-cache replay, 730 `emit_and_exit`, 850 main, 1319-1324 heartbeats, 2188 lock probe,
  2721 lock acquire
- `scripts/orchestrate-batch-admit.sh`: 740 dirty-path input
- `scripts/lib/runtime-file-patterns.sh`: 446-487 per-session path resolvers
- `scripts/reap-session-runtime-files.sh`: 146-153 reap globs
- `context/standards/orchestrator-runtime-files.md`: 43-46 the `.orchestration/` rows
- `scripts/milestone-ref-land.sh`: 146-149; `scripts/milestone-review-handoff.sh`: 75-78

**Issue log**: three entries recorded for this dispatch (one gate collision, one stale
description, one win).
