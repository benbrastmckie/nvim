# Implementation Plan: Task #626

- **Task**: 626 - Wire /todo and /review to roadmap regeneration behind the shared preflight gate
- **Status**: [NOT STARTED]
- **Effort**: 4 hours
- **Dependencies**: 625 (completed), 436 (completed), 458 (completed)
- **Research Inputs**: specs/626_wire_todo_review_roadmap_regenerate/reports/01_wire-todo-review-roadmap.md
- **Artifacts**: plans/01_wire-todo-review-roadmap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`roadmap-integration.sh --regenerate` currently has two live callers (`/orchestrate`'s conclusion
stage and `roadmap-agent` via `skill-roadmap`), and `context/patterns/roadmap-update.md` records
the absence of a `/todo` and `/review` call as a deliberate open gap. This plan wires both
commands to `--regenerate` behind the shared preflight library's **interactive**
`AskUserQuestion` arm, records the postflight-legality ruling for the `/todo` call site, and
rewrites the caller contract so it names four live callers with each one's arm. Done means: both
commands classify `specs/ROADMAP.md` before writing, regenerate it, commit it in its own
`specs/ROADMAP.md`-only commit, the contract matches the code, and the full gate set passes on a
fresh deploy.

### Research Integration

The research report changed two premises and one framing, all of which this plan adopts:

- The wiring target for `/todo` is `agent-system/extensions/core/commands/todo.md`, **not**
  `skills/skill-todo/SKILL.md` — that skill was removed when the duplicated `/todo`
  implementation was consolidated, and the command file is now the sole implementation. This
  task's `file_scope` in `specs/state.json` still names the removed skill path; the plan edits
  the command file instead (see Decisions).
- `/review` is still the live wiring target: the strategic-brief work extended `/review` in place
  with a `--brief` mode rather than retiring it, and no `/orient` command exists.
- Deliverable 3's framing is corrected rather than merely answered: neither call site is governed
  by `context/standards/postflight-tool-restrictions.md`'s base tables at all, so neither needs
  the Move-5-shaped additive exception. Re-derived at plan-authoring time:
  `scripts/lint/lint-postflight-boundary.sh` scans only `SKILL.md` files under `.claude/skills`
  and `.claude/extensions` (its `find` at line 48) and skips any skill its
  `does_skill_delegate()` predicate rejects (line 161) — it never reads `commands/*.md`.

Insertion points were re-derived directly from the two command files rather than carried:
`commands/todo.md` runs `### 6. Git Commit` -> `### 6.5. Sync Repository Metrics` -> `### 7.
Output`, and Stage 6.5 already establishes both the "run after Step 6's commit" ordering
rationale and the "its own narrowly-scoped commit" precedent this wiring mirrors.
`commands/review.md` runs `### 6.7. Interactive Task Order Management` -> `### 7. Git Commit` ->
`### 8. Output`, and its `--brief` mode early-exits at Section 1.1 before reaching either.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context, so no roadmap item mapping is claimed
here. `specs/ROADMAP.md` is the *subject* of this task's wiring, not an input consulted for
sequencing.

## Goals & Non-Goals

**Goals**:
- `/todo` and `/review` each invoke `roadmap-integration.sh --regenerate`, each preceded by
  `scripts/lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md`, using the interactive
  `AskUserQuestion` approval arm on an `absent`/`unknown` verdict.
- Each new call site commits `specs/ROADMAP.md` alone, in its own separately-scoped
  `git-commit-scoped.sh` invocation, and degrades non-fatally.
- `context/patterns/roadmap-update.md` names four live callers with each one's
  interactive-vs-autonomous arm, and carries no claim that `/todo` or `/review` does not call the
  script.
- The postflight-legality ruling for the `/todo` call site is recorded durably in the standard
  whose scope it concerns.

**Non-Goals**:
- No change to `/review`'s `--brief` mode (Section 1.1): it early-exits before the Git Commit
  section this wiring touches.
- No new Move-5-shaped exception table in `context/standards/postflight-tool-restrictions.md`,
  and no change to its existing Allowed/Prohibited tables or to the Move 5 section.
- No change to `roadmap-integration.sh`, `scripts/lib/roadmap-preflight-lib.sh`, the two existing
  callers (`skill-roadmap/SKILL.md`, `context/contracts/conclusion-stage.md`), or
  `roadmap-format.md`'s Destructive-Overwrite Refusal.
- No `--prune` usage anywhere (deprecated alias).
- No edit to `specs/state.json`'s stale `file_scope` entry for this task (descriptive, not
  filesystem-validated; correcting it is not this task's deliverable).
- No dependency edges added for the co-batch/ordering overlaps named in the dispatch.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rewriting the caller contract with draft-history language ("previously two", "no longer", "gap now closed") violates `rules/no-record-versioning-in-deliverables.md` | M | H | Phase 4 states the current contract only; its verification greps the changed hunks for the forbidden phrasings |
| A task number leaks into a non-`specs/**` deliverable, violating `rules/no-task-references-in-deliverables.md` | M | M | Every phase cites durable anchors (filenames, section headings); Phase 5 runs the task-reference lint gate over the source store |
| Siting `/todo`'s regenerate before Stage 6.5's metrics probe would measure a worktree the run then changes again | M | M | Site the new stage after Stage 6.5, i.e. after Stage 6's archival commit, per Stage 6.5's own stated ordering rationale |
| Folding `specs/ROADMAP.md` into an existing multi-path commit blurs a renderer-owned file's history | M | M | Each call site gets its own `specs/ROADMAP.md`-only `git-commit-scoped.sh` invocation, committed only when the render actually changed the file |
| An unapproved scaffold write on an `absent`/`unknown` verdict | H | L | Scaffold runs only on explicit `AskUserQuestion` approval; on decline both commands skip `--regenerate` entirely and write nothing |
| File-territory collision with other open tasks on `commands/review.md` and `context/standards/postflight-tool-restrictions.md` | M | M | Keep each phase's edit to a single file and a single named insertion point, so a concurrent edit elsewhere in the same file rebases cleanly; stage only the exact paths each phase touched |

## Decisions

- **Deliverable 3 ruling (the recorded answer)**: the `/todo` call site is **postflight-legal
  as-is**, by virtue of being outside `context/standards/postflight-tool-restrictions.md`'s
  scope — not because it appears on an allowed-operations list. That standard's base tables, and
  `scripts/lint/lint-postflight-boundary.sh`'s enforcement of them, govern agent-delegating
  `SKILL.md` files; `commands/todo.md` delegates to no subagent anywhere in its flow, so there is
  no delegated-agent-work boundary for a postflight phase to protect. It therefore needs **no**
  narrowly-scoped additive exception of the kind the Move 5 conclusion-stage table carries: that
  exception exists because Move 5 is a distinct, later actor running after delegated work closed,
  a structural shape neither command has. The ruling is recorded durably in two places — one
  clarifying scope sentence in that standard's own Overview (Phase 1) and one sentence per new
  caller in the rewritten caller contract (Phase 4) — so a future reader does not re-derive it.
- **Both new callers use the interactive arm.** Both commands are user-invoked slash commands
  running in a live session with `AskUserQuestion` already in their `allowed-tools` frontmatter
  (re-derived at authoring time: `commands/todo.md` line 3, `commands/review.md` line 3), so an
  approver is present. The non-interactive degrade arm exists for `/orchestrate`'s autonomous
  conclusion stage, which has no approver; copying it here would ask nobody and skip silently.
- **Wiring target correction**: `agent-system/extensions/core/commands/todo.md`, not the removed
  `skills/skill-todo/SKILL.md` named in the dispatch's DELIVERABLE 1 and in this task's
  `file_scope`. The caller contract's own current text already names the command path, so the
  contract and the code agree on the target even before this task's edits.
- **Commit the roadmap render only when it changed.** `--regenerate` is idempotent, so both new
  call sites gate their commit on `specs/ROADMAP.md` actually differing, rather than attempting a
  no-op commit on every run.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Record the Postflight-Legality Ruling [NOT STARTED]

**Goal**: Record, in the standard whose scope the question concerns, that its base tables and
their lint govern agent-delegating `SKILL.md` files — so the two new command-level call sites are
visibly out of scope rather than silently assumed to be.

**Tasks**:
- [ ] Confirm the two mechanical grounds still hold before writing:
      `grep -n 'find "\$PROJECT_ROOT/.claude/skills"' agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`
      and `grep -n 'does_skill_delegate' agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`.
- [ ] Add one clarifying sentence to `## Overview` in
      `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` stating
      that the Allowed/Prohibited tables below, and `scripts/lint/lint-postflight-boundary.sh`'s
      enforcement of them, are scoped to skills that delegate to a subagent via the Agent tool —
      and that a direct-execution command body that never delegates is outside that scope, so a
      generator or script call from such a body needs no additive exception.
- [ ] Keep the edit to `## Overview` only: do not touch the Allowed Operations, Prohibited
      Operations, Exceptions, or Conclusion Stage (Move 5) sections, and add no new table.
- [ ] Write no task number and no draft-history phrasing into the file.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this phase edits exactly one section (`## Overview`) of one file and adds no
table; confirm at implementation time with `git diff --stat` showing a single file and
`git diff -U0 -- agent-system/extensions/core/context/standards/postflight-tool-restrictions.md | grep -c '^+'`
showing a handful of added lines confined to the Overview hunk.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (no suite
maps a pure-guidance standards markdown file), so the covering check is the source-store gate
subset `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run alongside the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - one scope-clarifying sentence added to `## Overview`

**Verification**:
- Diff read-through confirming every changed hunk lies inside `## Overview` and is prose only.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 (doc-lint and task-reference lint; exit status checked, not a stdout diff).
- `grep -nE '\b(task [0-9]+|previously|no longer|formerly|supersedes)\b' agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
  returns no hit inside the added hunk.

---

### Phase 2: Wire `/todo` to `--regenerate` [NOT STARTED]

**Goal**: Add a roadmap-regeneration stage to `commands/todo.md` that classifies first, asks once
on `absent`/`unknown`, regenerates, and commits `specs/ROADMAP.md` alone.

**Tasks**:
- [ ] Re-confirm the insertion anchor: `grep -n '^### 6.5\.\|^### 7\. Output' agent-system/extensions/core/commands/todo.md`.
- [ ] Insert a new `### 6.6. Regenerate Roadmap` stage between `### 6.5. Sync Repository Metrics`
      and `### 7. Output`, with a short header note stating why it runs after Stage 6's archival
      commit and after Stage 6.5 (the same "do not measure or render a worktree this run is about
      to change again" rationale Stage 6.5's own header states).
- [ ] Step 6.6.1 — classify:
      `verdict="$(bash .claude/scripts/lib/roadmap-preflight-lib.sh classify specs/ROADMAP.md)"`.
      On `classic`/`stage`, proceed with no question asked and nothing written.
- [ ] Step 6.6.2 — on `absent`/`unknown`, one `AskUserQuestion` approval before any write, naming
      the verdict, what the mechanical skeleton write does, and (for `unknown`) that the existing
      file's content is preserved verbatim under `## Unfiled observations (none worth a task
      yet)`. On approval run `bash .claude/scripts/lib/roadmap-preflight-lib.sh scaffold specs/ROADMAP.md`
      and continue; on decline skip the regenerate entirely, write nothing, and record the skip
      for Stage 7's output.
- [ ] Step 6.6.3 — `bash .claude/scripts/roadmap-integration.sh --regenerate`, non-fatal on
      failure (`|| echo "Note: ... (non-fatal)" >&2`), per `rules/error-handling.md`'s
      non-blocking treatment.
- [ ] Step 6.6.4 — commit only if the render changed the file: gate on
      `git diff --name-only -- specs/ROADMAP.md` being non-empty, then one
      `bash .claude/scripts/git-commit-scoped.sh --message "todo: regenerate roadmap" --session "${session_id}" -- specs/ROADMAP.md`.
      State inline why `--honest-index-rows` and `--task` are inapplicable (a repo-wide render
      with no owning task number), mirroring Stage 6.5.3's existing wording.
- [ ] Step 6.6.5 — add `roadmap_regenerated` (true / false / skipped-pending-approval) to the
      tracked output fields and surface it in `### 7. Output`.
- [ ] Confirm no `allowed-tools` frontmatter change is needed, on the ground that Stage 6.5 and
      Stage 6 already invoke `bash .claude/scripts/...` under the same frontmatter; record the
      finding either way rather than editing the list speculatively.
- [ ] Use `--regenerate` only; never `--prune`. Write no task number into the file.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase adds exactly one new `### 6.6.` stage plus one output field to
one file, touching no other stage; confirm with
`grep -c '^### ' agent-system/extensions/core/commands/todo.md` increasing by exactly 1 and
`git diff --stat` naming only `commands/todo.md`.

**Tier Justification**: `suite_selection_select` maps this path to
`test-assess-repo-health.sh`, `test-todo-archived-projects-scan.sh`, and
`test-todo-move-pair-staging.sh`, so the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-assess-repo-health.sh,test-todo-archived-projects-scan.sh,test-todo-move-pair-staging.sh`.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - new `### 6.6. Regenerate Roadmap` stage; one new output field in `### 7. Output`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-assess-repo-health.sh,test-todo-archived-projects-scan.sh,test-todo-move-pair-staging.sh`
  exits 0.
- `grep -n 'roadmap-preflight-lib.sh classify\|roadmap-integration.sh --regenerate' agent-system/extensions/core/commands/todo.md`
  shows the classify call textually before the regenerate call.
- `grep -n -- '--prune' agent-system/extensions/core/commands/todo.md` returns no hit.
- `grep -n 'git-commit-scoped.sh' agent-system/extensions/core/commands/todo.md` shows the new
  invocation staging `specs/ROADMAP.md` and nothing else.

---

### Phase 3: Wire `/review` to `--regenerate` [NOT STARTED]

**Goal**: Add the same classify-gated roadmap regeneration to `commands/review.md`'s main flow,
immediately before its existing Git Commit section, with its own `specs/ROADMAP.md`-only commit.

**Tasks**:
- [ ] Re-confirm the insertion anchor: `grep -n '^### 6.7\.\|^### 7\. Git Commit' agent-system/extensions/core/commands/review.md`.
- [ ] Insert a new `### 6.8. Regenerate Roadmap` section between `### 6.7. Interactive Task Order
      Management` and `### 7. Git Commit`, with a one-line note that it runs after task creation
      and Task Order management so the render reflects the state this run produced.
- [ ] Classify -> interactive `AskUserQuestion` on `absent`/`unknown` -> scaffold on approval ->
      `--regenerate`, using the identical step shape and wording as Phase 2's Steps 6.6.1-6.6.3
      (same library entry points, same approval content, same non-fatal degrade), reworded only
      for `/review`'s own context.
- [ ] Commit `specs/ROADMAP.md` alone in its own `git-commit-scoped.sh` invocation, gated on the
      file actually differing, with message `review: regenerate roadmap`. Do **not** add
      `specs/ROADMAP.md` to Section 7's existing `stage_paths` array.
- [ ] State explicitly in the new section that `--brief` mode (Section 1.1) early-exits before
      this point and therefore performs no roadmap write.
- [ ] Surface the outcome in `### 8. Output` as one line.
- [ ] Use `--regenerate` only; never `--prune`. Write no task number into the file.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: this phase adds exactly one new `### 6.8.` section plus one output line to
one file and leaves Section 7's `stage_paths` array unchanged; confirm with
`git diff -- agent-system/extensions/core/commands/review.md` showing no hunk inside the
`stage_paths=(` block.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (no suite
maps it), so the covering check is the source-store gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run alongside the `local` row's single-file lint/diff read-through.

**Files to modify**:
- `agent-system/extensions/core/commands/review.md` - new `### 6.8. Regenerate Roadmap` section; one new output line in `### 8. Output`

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0.
- `grep -n 'roadmap-preflight-lib.sh classify\|roadmap-integration.sh --regenerate' agent-system/extensions/core/commands/review.md`
  shows classify textually before regenerate, and both inside the new section.
- `grep -n 'ROADMAP.md' agent-system/extensions/core/commands/review.md` shows no occurrence
  inside Section 7's `stage_paths` accumulation.
- `grep -n -- '--prune' agent-system/extensions/core/commands/review.md` returns no hit.

---

### Phase 4: Rewrite the Caller Contract [NOT STARTED]

**Goal**: Make `context/patterns/roadmap-update.md` describe the four live callers and their arms,
with no surviving claim that `/todo` or `/review` does not call the script.

**Tasks**:
- [ ] Enumerate the stale claims before editing:
      `grep -n "two live callers\|Neither \`/todo\`\|does not call this script\|acknowledged as an" agent-system/extensions/core/context/patterns/roadmap-update.md`.
- [ ] Rewrite `## Live Callers` as a four-entry list, each naming its caller, its invocation
      point, its commit surface, and its arm: `/orchestrate`'s conclusion stage (Move 5, Step 5)
      — non-interactive arm; `roadmap-agent`'s Write Contract via `skill-roadmap/SKILL.md` Stage 1
      — interactive arm; `/todo` (`commands/todo.md`, Stage 6.6) — interactive arm; `/review`
      (`commands/review.md`, Section 6.8) — interactive arm.
- [ ] Remove the sentence asserting that neither `/todo` nor `/review` invokes the script, and
      correct the `## Responsibility Split` bullet that states `/review`'s own command body does
      not call it.
- [ ] Replace the Ruling paragraph with the current contract, stated positively: all four callers
      are wired, each behind the Preflight Obligation, and any future write-mode caller inherits
      that same obligation plus the interactive-vs-autonomous arm choice determined by whether an
      approver is present on its own surface.
- [ ] Add one sentence recording the Phase 1 ruling: both command-level callers are
      direct-execution surfaces outside `context/standards/postflight-tool-restrictions.md`'s
      scope, so neither carries a Move-5-shaped additive exception.
- [ ] Update `## Preflight Obligation`'s parenthetical arm examples so the interactive arm names
      all three of its callers.
- [ ] Keep `--prune`'s deprecated-alias paragraph and the Destructive-Overwrite Refusal hard
      constraint intact.
- [ ] Write the current design only: no "previously", "no longer", "formerly", "the gap is now
      closed", "supersedes", or any other draft-history phrasing, and no task number.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Scope Hypothesis**: the stale-claim enumeration above is expected to return three distinct
locations (the `## Responsibility Split` bullet, the `two live callers` line, and the
`Neither /todo ... nor /review` sentence) plus the Ruling paragraph; treat that count as a
hypothesis and act on whatever the grep actually returns at implementation time, correcting every
hit rather than only three.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this path (no suite
maps a pure-guidance pattern markdown file), so the covering check is the source-store gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run alongside the `prose` row's diff read-through.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - `## Live Callers` rewritten to four callers with arms; `## Responsibility Split` bullet corrected; Ruling paragraph replaced; `## Preflight Obligation` arm examples extended

**Verification**:
- `grep -n "two live callers\|Neither \`/todo\`\|does not call this script\|acknowledged as an" agent-system/extensions/core/context/patterns/roadmap-update.md`
  returns no hit.
- `grep -nE '\b(previously|no longer|formerly|supersedes|gap is now closed)\b' agent-system/extensions/core/context/patterns/roadmap-update.md`
  returns no hit.
- `grep -n 'commands/todo.md\|commands/review.md' agent-system/extensions/core/context/patterns/roadmap-update.md`
  shows both named as live callers with an arm.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0.

---

### Phase 5: Deploy and Full Acceptance Verification [NOT STARTED]

**Goal**: Regenerate the deployed tree from the edited source store and prove the complete gate
set passes with all four callers wired and the contract matching the code.

**Tasks**:
- [ ] `bash .claude/scripts/deploy-headless.sh` (default non-destructive resync) to regenerate
      `.claude/**` from the edited source store.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--only-gate`, no
      `--skip-slow`), and confirm exit 0.
- [ ] Re-run the library's own consumer-discovery command and confirm both new consumers appear:
      `grep -rl 'roadmap-preflight-lib.sh' agent-system/extensions/core` now lists
      `commands/todo.md` and `commands/review.md` alongside the existing hits.
- [ ] Confirm the caller count is consistent across the deployed tree:
      `grep -rn 'roadmap-integration.sh --regenerate' .claude/commands .claude/skills .claude/context .claude/agents`
      shows the four wired call sites and no stale "two callers" claim.
- [ ] Confirm no new context file was created, so `index-entries.json` and the generated
      `context/index.json` need no new entry (every edited path already has its entry).
- [ ] `bash .claude/scripts/validate-state.sh specs/state.json` exits 0 (no roadmap-integrity
      regression).
- [ ] Idempotence sanity check:
      `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run` reports no content
      change against the committed `specs/ROADMAP.md`.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: the deployed-tree grep is expected to show exactly four `--regenerate` call
sites (the two pre-existing callers plus the two added by Phases 2 and 3) and the consumer-discovery
grep exactly two new `roadmap-preflight-lib.sh` consumers; both counts are hypotheses this phase's
own grep steps confirm, and a different result means an unwired or double-wired call site to
investigate rather than a count to adjust silently.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree deploy regeneration (`deploy-headless.sh`), which rewrites the entire deployed tree

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 — the complete gate set this repository
  aggregates, run unnarrowed (no `--only-gate`, no `--skip-slow`).
- `bash .claude/scripts/validate-state.sh specs/state.json` exits 0.
- `grep -rl 'roadmap-preflight-lib.sh' agent-system/extensions/core` includes both
  `commands/todo.md` and `commands/review.md`.
- `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run` reports no content change.

---

## Testing & Validation

- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 on a freshly deployed tree (Phase 5).
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-assess-repo-health.sh,test-todo-archived-projects-scan.sh,test-todo-move-pair-staging.sh`
      exits 0 (Phase 2).
- [ ] Both new call sites classify before they regenerate, textually confirmed by grep in each
      command file.
- [ ] Neither new call site stages anything but `specs/ROADMAP.md` in its own commit, and neither
      adds `specs/ROADMAP.md` to a pre-existing multi-path `stage_paths` array.
- [ ] `--prune` appears in neither command file.
- [ ] `context/patterns/roadmap-update.md` carries no stale caller claim and no draft-history
      phrasing.
- [ ] No task-number reference appears in any of the four edited deliverable files (covered by
      `verify-deploy.sh`'s task-reference lint gate).

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - scope-clarifying Overview sentence (the recorded Deliverable 3 ruling)
- `agent-system/extensions/core/commands/todo.md` - `### 6.6. Regenerate Roadmap` stage
- `agent-system/extensions/core/commands/review.md` - `### 6.8. Regenerate Roadmap` section
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - four-caller contract with per-caller arms
- Regenerated `.claude/**` deploy tree (Phase 5; not a committed artifact — gitignored)
- `specs/626_wire_todo_review_roadmap_regenerate/summaries/01_wire-todo-review-roadmap-summary.md` (written at implementation completion)

## Rollback/Contingency

Each phase is one file and one named insertion point, so the cheapest rollback is per-phase: fix
forward on the single file the failing phase touched, per `rules/error-handling.md`'s
fix-forward direction and `context/contracts/recovery.md`'s first rung. Because every phase
commits on its own, reverting one phase is a targeted revert of that phase's commit, not a
working-tree discard.

If a genuine rollback of uncommitted work becomes necessary, take the snapshot first using the
invocation shape `context/contracts/recovery.md`'s rollback rung specifies (including its
out-of-scope override flag for the deliberate whole-tree case) before running any destructive git
command — never a bare precautionary snapshot at the start of a phase.

If Phase 5's full gate set fails on something the deploy itself introduced rather than on this
task's edits, re-run `bash .claude/scripts/deploy-headless.sh` and re-verify before attributing
the failure to a source-store edit; `specs/ROADMAP.md` is regenerable from `state.json` at any
time via `--regenerate`, so no roadmap content is ever at risk from a failed phase.
