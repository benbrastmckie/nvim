# Implementation Plan: Task #693

- **Task**: 693 - Merge command stack mode
- **Status**: [IMPLEMENTING]
- **Effort**: 1.3 hours
- **Dependencies**: None declared. Design-dependent on the stack-PR-submission record's Phases
  1-3 (landed) and Phase 5 (body files), which this mode consumes read-only through
  `review-stack-prepare.sh show --json`.
- **Research Inputs**: specs/693_merge_command_stack_mode/reports/01_merge-command-stack-mode.md
- **Artifacts**: plans/01_merge-stack-mode.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a stack mode to the `/merge` command's documented contract: `--stack <stack id>`, `--only NN`
and `--retarget` alongside the existing `--draft`, driving PR creation from a prepared review
stack's manifest instead of from the current branch. The whole deliverable is one markdown file
in the core extension's source store (`commands/merge.md`), authored as a new `## Stack Mode`
section gated behind `--stack` in argument parsing, leaving every line of the existing
single-branch STEP 1-7 flow untouched. A second phase redeploys the source store so the deployed
`.claude/commands/merge.md` reflects it.

### Research Integration

The research report settled four questions that would otherwise have been implementation-time
guesses, and each shapes a task below:

- **The platform refusal is not a separate step.** `review-stack-prepare.sh`'s fixed RESOLUTION
  phase (integration branch -> review base -> remote -> platform, exit codes 10-13, 20, 30-32)
  runs before any subcommand body, so one `show --stack-id NAME --json` call checked for a
  non-zero exit discharges both "read the manifest" and "refuse a platform PD9 does not support".
  The step list below collapses them into one step rather than inventing a hand-rolled platform
  check in `merge.md`.
- **The grant revocation is already proven in this very file.** The parent record's Phase 6 Scope
  Hypothesis (can the command revoke the prompt-minted grant, perhaps by sourcing
  `scripts/lib/push-grant-lib.sh` and calling `pg_grant_revoke`?) resolves affirmatively and more
  cheaply than the hypothesis assumed: `merge.md`'s existing STEP 4 Cancel branch already runs
  `bash .claude/scripts/git-push-granted.sh --revoke`, and that wrapper calls `pg_grant_revoke`
  and exits 0 unconditionally. Stack mode calls the identical wrapper. No `allowed-tools` change,
  no library sourcing, and the hypothesis's fallback ("leave the grant to expire, and state in
  `merge.md` that stack mode leaves an unused grant live") is not needed and must not be written.
- **`entries[]` is already bottom-up.** The manifest writer emits entries in final stack order
  (ordinal 1 is the bottom), so stack mode iterates the array as given; it derives no ordering of
  its own.
- **`ordinal` is a bare JSON integer, but the user types a zero-padded `NN`.** The zero padding
  exists only inside the `branch`/`body_path` strings. `--only 02` must therefore be compared to
  `ordinal: 2` numerically, never as a string.

Verified independently against live state for this plan: the manifest object is written at
`review-stack-prepare.sh:1048`/`:1052` with exactly the fields the report names
(`{stack_id, remote, integration_branch, review_base, entries:[{ordinal, tasks, branch, base,
commit, parent_commit, title, body_path, state, request}]}`); `git-push-granted.sh` carries
`--revoke` and calls `pg_grant_revoke`; `show` and `record-request NN URL --stack-id NAME` are
live subcommands; `suite_selection_select "agent-system/extensions/core/commands/merge.md"`
returns `__FULL_SWEEP__` alone.

### Premise Re-Validation (Carried-Figure Discipline)

Each flagged description line, checked against live state rather than assumed:

1. **"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/\*\*"** — CONFIRMED
   unchanged. `jq -r '.extensions.core.source_dir' .claude-extensions.json` resolves to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`. Both file_scope paths mirror
   deployed paths under it.
2. **The duplicated "THIS RECORD OWNS PHASE 4 ONLY" (restack) paragraph** — CONFIRMED an
   expansion artifact, and ignored in full. This task's `file_scope` in `specs/state.json` is
   exactly `agent-system/extensions/core/commands/merge.md` and
   `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` — no script path. The
   dispatch Territory block assigns `scripts/review-stack-prepare.sh` and its suite to a
   concurrent sibling's exclusive scope. Nothing in this plan touches that script.
3. **"USER-ONLY, AND THE PROHIBITION STILL BINDS"** — CONFIRMED unchanged. `rules/pr-prohibition.md`
   prohibits agent `gh pr create`, agent `git push`, and autonomous `/merge` invocation, with the
   single user-invoked `/please` push exception. Stack mode adds no agent-reachable path: it is
   documented prose in a user-only command, it pushes nothing, and its tip-mismatch branch stops
   and names the `/please push` for the operator to type rather than running it.

Additionally checked, because the parent plan's own figures are load-bearing here: the
`--only-gate 3,4` Tier Justification invocation. `verify-deploy.sh`'s TARGET_REPO contract states
that a source-store directory can never be TARGET (gate0 exits 2 before gate selection), and that
the repo root is the only directory that is simultaneously deploy consumer and source store. The
parent plan's invocation already passes `"$(git rev-parse --show-toplevel)"`, so it is correct as
written and is reproduced verbatim below. Gate 3 is the doc-lint
(`check-extension-docs.sh --quiet`); gate 4 is the task-reference lint
(`check-task-references.sh --quiet`).

### Prior Plan Reference

No prior plan for this record. The stack-PR-submission record's plan at
`specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md` is the
authoritative design record (PD1-PD12) and its Phase 6 section was read in full; its task list,
timing (1 hour), verification tier (`local`) and Tier Justification are carried forward here
rather than re-derived. Effort calibration from that record: its closed phases ran at roughly one
phase per dispatch, so a 2-phase shape for a one-file deliverable is deliberately conservative.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no `roadmap_flag` is
set, so no roadmap consultation applies.

### Domain Plan-Authoring Gotchas

Queried `.claude/context/index.json` for a `project/**` entry whose `load_when.task_types[]`
contains `meta` and whose keywords/topics name `plan-authoring`: zero hits (the only two
`plan-authoring` entries are scoped to `task_types: ["lean4"]`). This is the normal case for this
task type, not a gap.

## Goals & Non-Goals

**Goals**:

- `commands/merge.md` documents `--stack <stack id>`, `--only NN` and `--retarget` in its
  frontmatter `argument-hint` and its `## Options` table.
- A new `## Stack Mode` section documents the mode's steps in the dispatch's own order: revoke the
  prompt-minted grant; read and platform-gate the manifest in one `show --json` call; one approval
  prompt listing every PR with its head and base; then per entry bottom-up, remote-tip
  confirmation, open-PR lookup, creation from the manifest's head/base/title/body file, and URL
  recording.
- Stack mode states that the remote and every branch name come from the manifest alone, never from
  a default — concretely: the words `origin` and `main` do not appear anywhere in the stack-mode
  steps.
- Stack mode contains no push step, and its tip-mismatch branch names the `/please push` for the
  operator to type.
- `## Agent Restrictions` states that stack mode is user-only on the same ground as single-branch
  mode.
- The single-branch mode's text (STEP 1-7's bodies, `## Platform Flag Mapping`, the existing
  `## Options` rows, `## Output`, `## Troubleshooting`) is unchanged.
- The source store's change is deployed, so `.claude/commands/merge.md` reflects it.

**Non-Goals**:

- Any edit to `scripts/review-stack-prepare.sh` or its test suite. That script is a concurrent
  sibling's exclusive territory and is consumed here strictly as a read-only, already-landed API
  (`show --json`, `record-request`, its exit codes). The description's duplicated Phase 4
  (restack) paragraph is out of scope entirely.
- Any edit to `skills/skill-git-workflow/SKILL.md`. It is in this task's declared `file_scope`,
  so it is declared here rather than silently skipped: research found it carries no merge-mode
  wiring at all (its sole "merge" occurrence is an unrelated bullet, "Implementation completed -
  Final verification before merge"), and the Phase 6 deliverable needs no hook there —
  `record-request` writes a gitignored `specs/.orchestration/` file that the script performs
  itself, not a commit this skill stages. The scope entry is retained defensively; no edit is
  planned. If implementation discovers a genuine hook, it is declared before editing, not widened
  into mid-dispatch.
- Any edit to `agent-system/extensions/core/README.md` (line 43's command table) or
  `agent-system/extensions/core/merge-sources/claudemd.md` (line 116's command table). Both are
  outside this task's declared `file_scope`. Neither blocks a gate: gate 3's
  `check_readme_vs_manifest()` requires only that each `provides.commands` name appear as
  `/<name>` in the extension README, and `/merge` already does (README line 43) — no new command
  is added, only a mode. A one-line usage-column refresh in those two tables is a legitimate
  follow-up for a record whose scope includes them.
- Making stack mode work on GitLab. PD9 scopes the whole stack flow to GitHub, and
  `review-stack-prepare.sh`'s own resolution refuses GitLab (exit 30). `## Platform Flag Mapping`
  stays single-branch-only and untouched.
- Implementing the behaviour as a script. The deliverable is the command's documented contract;
  its live behaviour is operator-owed (PD11) and cannot be agent-verified.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A partial edit leaves the argument hint, options table and step list disagreeing — which is precisely this phase's own verification criterion | M | M | Phase 1 is one green sub-step covering all four edit sites in the file; the phase is not committed at an intermediate state where the table names a flag no section documents |
| A concurrent sibling edits `commands/merge.md` between the read and the write | H | L | Siblings' declared scopes are `review-stack-prepare.sh` / `milestone-review-handoff.sh` and their suites — disjoint from this file. Still: re-read `commands/merge.md` immediately before editing, stage only this file, never a directory or glob add, never `git-snapshot.sh` in its reverting default mode |
| `verify-touched.sh` on a prose-only `.md` path escalates to the whole free-cost-class battery (`suite_selection_select` returns `__FULL_SWEEP__`), costing minutes and risking an auto-backgrounded call | M | H | Use the narrow `verify-deploy.sh --skip-slow --only-gate 3,4 <repo root>` invocation as Phase 1's covering check, and leave the complete gate set to the orchestration close rather than paying a full sweep twice |
| `--only NN` naively string-matched against the manifest's integer `ordinal` silently selects nothing | M | M | Phase 1 task list requires the step text to state the numeric comparison explicitly (strip leading zeros, e.g. `$((10#$only))`, or an `--argjson` numeric jq compare) |
| The words `origin` or `main` leak into the stack-mode steps by copy-paste from the single-branch flow | M | M | Phase 1's own verification is a literal `grep` for both words bounded to the new section |
| Redeploy regenerates the whole `.claude/` tree while siblings are in flight | M | M | Phase 2 declares `` `__WHOLE_TREE__` `` so the admission dimension can serialize it against a sibling's own regeneration; the deployed tree is gitignored and produces no commit of its own |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Stack mode in `commands/merge.md` [NOT STARTED]

**Goal**: `commands/merge.md` documents a complete, internally consistent `--stack` mode that
pushes nothing and takes every ref from the manifest, with the single-branch mode's text
untouched.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/commands/merge.md` in full immediately before
      editing (sibling concurrency; see Risks). Treat the whole-file edit below as this phase's
      single green sub-step under the default per-substep commit mode: any narrower split would
      commit a state where the options table names a flag no section documents, which is exactly
      what this phase's own verification criterion forbids.
- [ ] Extend the frontmatter `argument-hint` to
      `"[--draft] [--stack STACK_ID] [--only NN] [--retarget] [--assignee USER] [--label LABEL] [--reviewer USER]"`.
      Leave `description`, `allowed-tools` and `model` as they are — `Bash(git:*), Bash(gh:*),
      Bash(glab:*), AskUserQuestion` already covers `git ls-remote`, `gh pr list`, `gh pr create`,
      `gh pr edit` and the approval prompt, so no widening is needed.
- [ ] Add three rows to the `## Options` table, after `--draft` and before `--assignee USER`:
      `--stack <stack id>` (run stack mode against a prepared review stack's manifest; default
      none), `--only NN` (stack mode: act on that one entry's ordinal only; default all entries),
      `--retarget` (stack mode: change an open PR's base when it differs from the manifest's;
      default false). Do not touch the existing seven rows and do not touch
      `## Platform Flag Mapping` — stack mode is GitHub-only by PD9 and uses no GitLab column.
- [ ] In STEP 1 (Parse Arguments), add the three flags to the tracked-flag list and add an early
      dispatch line: when `--stack` is present, skip STEP 2-7 entirely and run `## Stack Mode`
      instead. State that `--only` and `--retarget` are meaningful only with `--stack`.
- [ ] Add a new top-level `## Stack Mode` section after STEP 7 and before `## Examples`, opening
      with a statement that the remote, the review base and every branch name come from the
      manifest alone and never from a default, and that this mode pushes nothing.
- [ ] Write its steps in this order. (1) Revoke the prompt-minted grant first, before anything
      else: `bash .claude/scripts/git-push-granted.sh --revoke` — the same wrapper STEP 4's Cancel
      branch already uses; this mode pushes nothing, so the grant must not linger for its expiry
      window. (2) Read and platform-gate the manifest in ONE call:
      `bash .claude/scripts/review-stack-prepare.sh show --stack-id <stack id> --json`; on a
      non-zero exit, surface that script's own named refusal (its review-base, remote and platform
      exit codes) and STOP — no retry, no fallback to a default remote or base. Note that this one
      call also discharges "refuse a platform PD9 does not support", because that script's
      resolution phase runs before any subcommand body. (3) Show ONE approval prompt via
      `AskUserQuestion` listing every entry's head (`branch`) and base (`base`) before touching
      any entry, with a Cancel option that stops without creating anything.
- [ ] Write the per-entry loop: iterate `entries[]` in array order (already bottom-up — ordinal 1
      is the bottom of the stack — so derive no ordering of your own). When `--only NN` was given,
      skip entries whose `ordinal` does not match numerically; state explicitly that the user's
      `NN` may be zero-padded while `ordinal` is a bare integer, so the comparison strips leading
      zeros (`$((10#$only))`) or uses a numeric jq compare, never a string match.
- [ ] For each selected entry, in order: confirm the remote tip with
      `git ls-remote <remote from manifest> refs/heads/<branch from manifest>` and compare it to
      that entry's `commit`; on mismatch or absence, STOP and print the exact `/please push` line
      for the operator to type, and never push. Then look for an open PR on that head with
      `gh pr list --state open --head <branch> --json number,baseRefName,url`. When there is none,
      create one with `gh pr create --head <branch> --base <base> --title <title> --body-file
      <body_path>`, taking all four values from the manifest entry. Record the URL with
      `bash .claude/scripts/review-stack-prepare.sh record-request <ordinal> <url> --stack-id <stack id>`.
- [ ] Document `--retarget`: for each entry with an open PR whose live `baseRefName` differs from
      the manifest's `base`, run `gh pr edit <number> --base <base from manifest>`; state that the
      forge may already have retargeted it itself when the parent's branch was deleted, so a
      no-op is an expected outcome rather than an error.
- [ ] Add a short `### Stack Mode` example block under `## Examples` (`/merge --stack <stack id>`,
      `/merge --stack <stack id> --only 02`, `/merge --stack <stack id> --retarget`) for
      discoverability. Leave every existing example, and all of `## Output` and
      `## Troubleshooting`, exactly as they are — those document single-branch mode.
- [ ] Append one sentence to `## Agent Restrictions`: stack mode is user-only on the same ground
      as single-branch mode, and no agent may invoke `/merge --stack` either.
- [ ] Confirm no task-number reference and no record-versioning language entered the file
      (`rules/no-task-references-in-deliverables.md`,
      `rules/no-record-versioning-in-deliverables.md`): refer to the stack flow by its command and
      script names, never by a task number, and describe the mode as it now is, never as a change
      from an earlier state of the file.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Three asserted figures, each a hypothesis to confirm against the live file
immediately before editing, not a fact to act on: `commands/merge.md` stands at 485 lines; its
`## Options` table carries 7 rows and its `## Execution` section carries STEP 1-7, with
`## Agent Restrictions` near the end; and `commands/merge.md` is the only file this phase touches
— `skills/skill-git-workflow/SKILL.md` (in `file_scope`), the core `README.md` command table and
`merge-sources/claudemd.md`'s command table are all deliberately EXCLUDED, and no task above
requires any of them. Confirm by re-reading the file and by `grep -c '^| ' ` on the options table
before the first edit; if the live shape differs, adapt the insertion points rather than the
scope.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` alone for
`agent-system/extensions/core/commands/merge.md` (verified live), so no dedicated suite exists and
the specific covering check is the doc-lint and task-reference gates:
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 "$(git rev-parse --show-toplevel)"`.

**Files to modify**:

- `agent-system/extensions/core/commands/merge.md` - frontmatter `argument-hint`; three
  `## Options` rows; STEP 1's flag list and stack-mode dispatch line; a new `## Stack Mode`
  section; a `### Stack Mode` example block; one appended sentence in `## Agent Restrictions`

**Verification**:

- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 "$(git rev-parse --show-toplevel)"`
  exits 0. (Treat exit 2 and exit 3 as not-a-pass: exit 2 means the selection attested to nothing,
  exit 3 means the complete gate set is already owed to a batch-gate stage.)
- A read-through confirms the documented contract is internally consistent: every flag in the
  frontmatter `argument-hint` has an `## Options` row, and every stack-mode flag has a step that
  uses it.
- Stack mode contains no push step, and every `gh` call takes its head and base from the manifest.
- `grep -nE '\borigin\b|\bmain\b'` bounded to the `## Stack Mode` section returns nothing.
- `git diff` on the file shows no change inside STEP 1's body beyond the added flags and the
  dispatch line, and no change at all to STEP 2-7, `## Platform Flag Mapping`, the pre-existing
  `## Options` rows, `## Output` or `## Troubleshooting`.
- `bash .claude/scripts/check-task-references.sh` reports no finding for this file.

---

### Phase 2: Redeploy and close [NOT STARTED]

**Goal**: The deployed `.claude/commands/merge.md` reflects the source store, and this record's
verification obligation is discharged or explicitly deferred.

**Tasks**:

- [ ] Redeploy the source store: `bash .claude/scripts/deploy-headless.sh` from the repository
      root (resync, the bootstrap-safe non-destructive default — not `--wipe`).
- [ ] Confirm the deployed copy matches: diff `.claude/commands/merge.md` against
      `agent-system/extensions/core/commands/merge.md`, or read the redeploy's own inline
      verification result. The deployed tree is gitignored, so this produces no commit of its own.
- [ ] Run the scoped touched-path check over this record's one touched path and record its result.
      Prefer the narrow gate invocation (`verify-deploy.sh --skip-slow --only-gate 3,4
      "$(git rev-parse --show-toplevel)"`) over a bare `verify-touched.sh` run on this path: a
      prose-only `.md` path with no mapped suite triggers that script's OWED-NOT-PAID fallback and
      escalates to the entire free-cost-class battery, which costs minutes and may auto-background
      the call.
- [ ] Under `/orchestrate`, defer the complete gate set explicitly to the orchestration close
      (Move 4) rather than invoking the full battery here; state that deferral in the handoff.
      Outside an orchestration, run the complete set directly instead.
- [ ] Record this record's issue-log entries for the dispatch, or attest explicitly that there was
      nothing to record.

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, which regenerates the entire deployed
  `.claude/` tree; the sentinel is declared so the admission dimension can serialize it against a
  concurrent sibling's own regeneration

**Verification**:

- `deploy-headless.sh` exits 0 and `.claude/commands/merge.md` is byte-identical to the source
  store's copy.
- The scoped touched-path check over `agent-system/extensions/core/commands/merge.md` passes
  (equivalently, the gate 3,4 invocation above exits 0).
- The complete gate set is explicitly deferred to the orchestration close and that deferral is
  stated in the handoff — the full battery is owed once per orchestration invocation and is not
  forgiven, only deferred.

## Testing & Validation

- [ ] `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 "$(git rev-parse --show-toplevel)"`
      exits 0 (gate 3 doc-lint, gate 4 task-reference lint).
- [ ] The documented contract is internally consistent: frontmatter `argument-hint`, `## Options`
      table and the stack-mode step list name the same flags.
- [ ] The single-branch mode's text is unchanged, confirmed by reading `git diff`.
- [ ] `origin` and `main` appear nowhere in the stack-mode steps.
- [ ] No push step and no agent-reachable PR-creation path is introduced; `/merge` remains
      user-only and `rules/pr-prohibition.md` continues to bind unchanged.
- [ ] `.claude/commands/merge.md` matches the source store after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/commands/merge.md` with a `## Stack Mode` section and the three
  new flags documented.
- A regenerated deployed `.claude/` tree (gitignored; no commit).
- This record's summary artifact at completion.

## Rollback/Contingency

The whole deliverable is one markdown file's content. To revert: `git revert` the phase-1 commit
(or `git checkout HEAD~1 -- agent-system/extensions/core/commands/merge.md` if nothing has landed
on top of it), then redeploy with `bash .claude/scripts/deploy-headless.sh`. No script, schema,
state file or test suite is modified, so nothing else can be left half-applied. If a concurrent
sibling has touched the file in the meantime — which their declared scopes say they will not —
stop and report the foreign modification rather than reverting over it, per the dispatch's
concurrency note.
