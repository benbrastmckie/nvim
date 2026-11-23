# Research Report

**Task**: 693 - Merge command stack mode
**Started**: 2026-11-23T22:23:42Z
**Completed**: 2026-11-23T22:50:00Z
**Effort**: 1 hour (per parent plan's Phase 6 timing estimate)
**Dependencies**: None (declared); design-dependent on the parent record's Phases 1-3 and 5
**Sources/Inputs**:
- `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md` (Decisions PD1-PD12, Phase 6 section)
- `agent-system/extensions/core/commands/merge.md` (current live file, full read)
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` (manifest schema, resolution order, exit codes; read-only — out of this record's file_scope)
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` (read-only check for merge-mode wiring)
- `agent-system/extensions/core/scripts/git-push-granted.sh`, `scripts/lib/push-grant-lib.sh`
- `agent-system/extensions/cslib/commands/pr.md` (precedent for `gh pr list`/`gh pr create` head/base usage; not importable per PD2, read for pattern only)
- `rules/pr-prohibition.md`, `rules/source-store-deploy-boundary.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- This record owns **Phase 6 only** ("`/merge` stack mode"). The description's duplicated Phase
  4 paragraph (restack in `review-stack-prepare.sh`) belongs to the sibling record whose
  `file_scope` names that script (confirmed: this task's own `file_scope` in `specs/state.json`
  is exactly `agent-system/extensions/core/commands/merge.md` and
  `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` — no script path). That
  paragraph was ignored for all research below.
- The manifest `review-stack-prepare.sh show --stack-id NAME --json` prints has a fixed, already
  landed shape: `{stack_id, remote, integration_branch, review_base, entries: [{ordinal, tasks,
  branch, base, commit, parent_commit, title, body_path, state, request}]}`. Stack mode's "head"
  is each entry's `branch` field; "base" is `base`; PR title/body come from `title`/`body_path`.
- The platform refusal ("refuse a platform PD9 does not support") is **already discharged by
  the `show` call itself** — `review-stack-prepare.sh`'s resolution order runs integration
  branch -> review base -> remote -> platform before any subcommand body executes, so a single
  `show --stack-id NAME --json` invocation, checked for a non-zero exit, covers both "read the
  manifest" and "refuse an unsupported platform" in one step.
- The Phase 6 Scope Hypothesis (can the command revoke the prompt-minted push grant?) is
  **already answered affirmatively by the live file**: `merge.md`'s existing STEP 4 Cancel
  branch already runs `bash .claude/scripts/git-push-granted.sh --revoke`. Stack mode's first
  step should call the identical wrapper, not source `push-grant-lib.sh` directly — no
  `allowed-tools`/frontmatter change is needed for this step.
- `skills/skill-git-workflow/SKILL.md` — named in this task's own `file_scope` — currently
  carries **no merge-mode wiring at all**; its sole "merge" occurrence is an unrelated bullet
  ("Implementation completed - Final verification before merge"). Research found no hook stack
  mode needs to reach there. Flagged for the planner per the dispatch's own instruction ("declare
  it before editing it rather than widening scope mid-dispatch").
- Recommended approach: add the three flags to `merge.md`'s frontmatter `argument-hint` and
  options table; add a new "Stack Mode" section with its own numbered steps (parallel to but
  separate from the existing single-branch STEP 1-7), gated on `--stack` being present, leaving
  every single-branch line untouched; extend "Agent Restrictions" with one added sentence.

## Context & Scope

Researched the exact deliverable for Phase 6 of the stack-PR-submission plan — adding
`--stack <stack id>`, `--only NN`, and `--retarget` modes to the `/merge` command — without
touching anything in the duplicated Phase 4 paragraph (restack logic in
`review-stack-prepare.sh`), which is out of this record's `file_scope` and owned by a sibling
dispatch (task territory names `agent-system/extensions/core/scripts/review-stack-prepare.sh`
and its test suite as that sibling's exclusive scope).

Scope boundary confirmed three ways: (1) the dispatch's own `User focus` instruction states the
rule explicitly; (2) `specs/state.json`'s `file_scope` array for this task number lists only
`commands/merge.md` and `skill-git-workflow/SKILL.md`; (3) the Territory block names
`review-stack-prepare.sh` and its test suite as sibling tasks' file scope, not this one's.

## Findings

### Codebase Patterns

**Current `merge.md` structure** (full file read): YAML frontmatter
(`description`/`allowed-tools`/`argument-hint`/`model`), a `## Syntax`, `## Options` table,
`## Platform Flag Mapping` table, `## Prerequisites`, then `## Execution` with STEP 1-7
(`Parse Arguments` -> `Detect Platform` -> `Validate Branch` -> `User Approval` -> `Push to
Origin` -> `Create PR/MR` -> `Report Results`), followed by `## Examples`, `## Output`,
`## Troubleshooting`, `## Agent Restrictions`, `## Related Commands`. `allowed-tools` is
`Bash(git:*), Bash(gh:*), Bash(glab:*), AskUserQuestion` — broad enough to cover every git/gh
call stack mode needs (git ls-remote, gh pr list/create/edit); no frontmatter widening appears
necessary.

**Push-grant revocation precedent** (already in the live file, STEP 4 Cancel handler):
```bash
bash .claude/scripts/git-push-granted.sh --revoke
```
`git-push-granted.sh --revoke` calls `pg_grant_revoke` (in `scripts/lib/push-grant-lib.sh`) and
deletes every live grant, exiting 0 unconditionally. This is the sanctioned, already-proven path
— stack mode's "revoke the prompt-minted grant" step should call it exactly this way, first,
before anything else in stack mode runs.

**Manifest schema** (from `review-stack-prepare.sh`'s `rsp_cut_execute`/`rsp_show_stack`,
read-only reference — this script is NOT in this record's edit scope):
```json
{
  "stack_id": "...", "remote": "...", "integration_branch": "...", "review_base": "...",
  "entries": [
    {"ordinal": 1, "tasks": [691, 692], "branch": "review/<stack>/01-<slug>",
     "base": "<review_base ref, or the branch below it>", "commit": "<sha>",
     "parent_commit": "<sha>", "title": "...", "body_path": "specs/.orchestration/reviews/<stack>/01-body.md",
     "state": "prepared", "request": ""}
  ]
}
```
`entries[]` is already in bottom-up stack order (ordinal 1 is the bottom of the stack); no
re-sorting is needed in `/merge --stack` — iterating the array in order already satisfies
"bottom-up."  `ordinal` is a bare JSON integer (not zero-padded); the zero-padded `NN` the user
types for `--only NN` appears only in the `branch`/`body_path` strings (`%02d`-formatted, from
`rsp_cut_plan`). The command must therefore compare `--only`'s argument to `ordinal` with
leading zeros stripped (e.g. `$((10#$only))` or an `--argjson`-numeric jq compare), not as a
literal string match against the manifest's `ordinal` field.

**Platform/resolution order is already enforced by `show` itself.** `review-stack-prepare.sh`'s
header documents a fixed RESOLUTION phase that every subcommand (including `show`) runs before
its own body: integration branch -> review base (PD1, exit 10-13) -> remote (exit 20) ->
platform (PD9, exit 30-32: `platform_gitlab_unsupported`, `platform_unrecognized_host`,
`platform_push_url_mismatch`). A single
`bash .claude/scripts/review-stack-prepare.sh show --stack-id NAME --json` call, checked for a
non-zero exit and the script's own named stderr reason, is therefore sufficient for *both*
"read the manifest" and "refuse a platform PD9 does not support" — they are not two separate
steps to hand-implement in `merge.md`, just one call plus an exit-code check.

**Remote-tip confirmation**: `git ls-remote <remote> refs/heads/<branch>` against the manifest's
`remote` and each entry's `branch`, compared to that entry's `commit` field, is exactly what the
dispatch and plan ask for — no new script support needed; this is a direct git CLI call, already
covered by the existing `Bash(git:*)` allowed-tools entry.

**Open-PR lookup and creation precedent** (from `agent-system/extensions/cslib/commands/pr.md`,
read for pattern only — PD2 rules out importing any of its code):
```bash
gh pr list --state open --head "<branch>" --json number,headRefName,baseRefName,url
```
and `gh pr create --head <branch> --base <base> --title <t> --body-file <path>` — `gh pr create
--head` does not require the branch to be locally checked out, only pushed to the same-repo
remote (which stack mode's preceding `git ls-remote` tip check already confirms). This matches
`review-stack-prepare.sh`'s own constraint (PD6/PD9) that it never runs `git checkout`/`git
switch` — stack mode must not either. `--retarget` maps to `gh pr edit <number> --base <new
base>` for any open entry whose live PR base differs from the manifest's `base`.

**No merge-mode wiring exists yet in `skill-git-workflow/SKILL.md`.** Full-file grep for "merge"
found exactly one hit, an unrelated bullet ("Implementation completed - Final verification
before merge"). This file is nonetheless in this task's declared `file_scope`, presumably
anticipating that `/merge` stack-mode commits (if any) might need scoped-staging guidance there.
Research found no such hook required by the Phase 6 deliverable as described — `record-request`
writes are a `.orchestration/` (gitignored) mutation the script itself performs, not a commit
`skill-git-workflow` stages. Flagged rather than assumed away, per the dispatch's own
instruction to declare before editing.

**No PR submission from stack mode.** PD9 confirms GitHub-only, head and base behind the same
URL; PD11 states the actual push/forge-write is operator-owed and cannot be agent-verified.
`rules/pr-prohibition.md` is unaffected in substance — this record only documents a new
*user-only* mode of an already user-only command; no new agent-reachable path is introduced.

**Verification tier**: confirmed no dedicated test suite targets `commands/merge.md` beyond the
general-purpose doc-lint/task-reference gates (gate 3, gate 4 in `verify-deploy.sh`) — matches
the plan's own Tier Justification (`suite_selection_select` returns `__FULL_SWEEP__` alone for
this path). `test-mcp-merge-target.sh` exists but is unrelated (MCP merge-target config, not
this command).

### External Resources

None consulted beyond this repository and its own prior design record; the task is entirely
specified by the parent plan's PD1-PD12 and Phase 6 section, plus the live state of the two
files in scope.

## Recommendations

1. **Frontmatter**: extend `argument-hint` to
   `"[--draft] [--stack STACK_ID] [--only NN] [--retarget] [--assignee USER] [--label LABEL] [--reviewer USER]"`
   and add three rows to the `## Options` table (`--stack <stack id>`, `--only NN`,
   `--retarget`), leaving every existing row and the `## Platform Flag Mapping` table untouched
   (stack mode is GitHub-only by PD9 and does not use the GitLab column).
2. **New top-level section**, e.g. `## Stack Mode`, inserted after `## Execution`'s single-branch
   STEP 1-7 (or gated as an early branch inside STEP 1's argument parsing: "if `--stack` is
   present, skip STEP 2-7 and run Stack Mode instead"). Steps, in the dispatch's own order:
   1. Revoke the prompt-minted grant: `bash .claude/scripts/git-push-granted.sh --revoke`.
   2. Read + platform-gate the manifest in one call:
      `bash .claude/scripts/review-stack-prepare.sh show --stack-id <stack id> --json`; on
      non-zero exit, surface the script's own named refusal (review_base/remote/platform exit
      codes) and STOP — do not retry, do not fall back to a default remote/base.
   3. Show ONE approval prompt (`AskUserQuestion`) listing every entry's `branch` (head) and
      `base`, before touching any entry.
   4. Per entry, **in manifest array order** (already bottom-up, per `ordinal`): if `--only NN`
      was given, skip entries whose `ordinal` (leading zeros stripped) does not match.
      - `git ls-remote <remote> refs/heads/<branch>` and compare to the entry's `commit`; on
        mismatch/absence, STOP and print the exact `/please push <remote> <branch>` to type —
        never push it.
      - `gh pr list --state open --head <branch> --json number,baseRefName,url` to look for an
        existing open PR on that head.
      - If none: `gh pr create --head <branch> --base <base> --title <title> --body-file
        <body_path>`; record the URL with
        `bash .claude/scripts/review-stack-prepare.sh record-request <ordinal> <url> --stack-id <stack id>`.
      - If `--retarget` and an open PR's base differs from the manifest's `base`: `gh pr edit
        <number> --base <base>`; note in output that the forge may already have retargeted it
        itself if the parent branch was deleted.
   5. State explicitly, near the top of this new section, that the remote and every branch name
      come from the manifest alone, never from `origin`/`main` defaults — this is also this
      phase's own verification criterion ("the words `origin` and `main` do not appear in the
      stack-mode steps").
3. **`## Agent Restrictions`**: append one sentence — stack mode is user-only on the same ground
   as single-branch mode; no agent may invoke `/merge --stack` either.
4. **`skill-git-workflow/SKILL.md`**: based on this research, no edit appears necessary for the
   Phase 6 deliverable as scoped. Recommend the plan state this explicitly (a one-line
   "no change needed; file_scope retained defensively" note) rather than silently leaving it
   untouched with no record — satisfies the dispatch's "declare it... rather than widening scope
   mid-dispatch" instruction without actually widening anything.
5. Leave `## Examples`/`## Output`/`## Troubleshooting` for single-branch mode exactly as they
   are; optionally add one new `### Stack Mode` example block under `## Examples` for
   discoverability (not required by the phase's own verification criteria, but cheap and
   consistent with the file's existing style).

## Decisions

- Confirmed via `specs/state.json` that this task's `file_scope` is exactly `commands/merge.md`
  and `skill-git-workflow/SKILL.md` — the duplicated Phase 4 (restack) paragraph in the
  description is out of scope and was not researched further than identifying it as such.
- Treated `review-stack-prepare.sh`'s `show --json`, `record-request`, and exit-code contract as
  fixed, read-only API surface for this record (per "LANDED AND NOT TO BE REDONE" in the
  description) — no changes to that script are proposed or implied by any recommendation above.
- Treated cslib's `/pr` command (`agent-system/extensions/cslib/commands/pr.md`) as pattern
  reference only, consistent with PD2's "nothing in cslib `/pr` is importable as code."

## Risks & Mitigations

- **Risk**: hand-rolling the bottom-up ordering assumption. **Mitigation**: confirmed by reading
  `rsp_cut_plan` that `entries[]` is written in final stack order (`nn` incremented per unit in
  final order), so no re-derivation of bottom-up order is needed in `merge.md` — just iterate
  the array as given.
- **Risk**: `--only NN` ordinal matching against a zero-padded user-typed value. **Mitigation**:
  documented above (strip leading zeros before numeric compare); flag this explicitly in the
  plan so the implementer doesn't naively string-match "02" against `ordinal: 2`.
- **Risk**: scope creep into `review-stack-prepare.sh` while investigating manifest shape.
  **Mitigation**: all reads of that script in this report are read-only citations of its
  documented, already-landed contract; no edit to it is proposed here, and the sibling task
  owns it exclusively per Territory.
- **Risk**: an agent path accidentally becoming push/PR-reachable. **Mitigation**: every
  recommended step above is phrased as `/merge`-only prose (user-invoked), matching the
  existing file's `allowed-tools`/"Agent Restrictions" pattern; `rules/pr-prohibition.md`
  continues to bind regardless of this new mode.

## Context Extension Recommendations

- **Topic**: gh CLI head/base usage without a local checkout (`gh pr create --head`, `gh pr list
  --head`, `gh pr edit --base`) for stack/manifest-driven PR flows.
- **Gap**: no existing context file documents this pattern generally (only embedded, prose-only
  precedent inside `agent-system/extensions/cslib/commands/pr.md`, which is explicitly
  non-importable per PD2).
- **Recommendation**: if a second stack/manifest-driven command surface is ever added, consider
  a small shared context note (e.g. under `context/patterns/`) documenting the
  "`gh pr` without checkout" idiom, so it is not re-derived from cslib's `/pr` prose each time.
  Not created now — one call site does not yet justify a new context file.

## Appendix

- Searches: `grep -n` over `review-stack-prepare.sh` for subcommand/exit-code documentation,
  manifest-writing (`rsp_cut_execute`), `show`/`record-request` bodies, platform refusal
  strings, `PLAN_NN` zero-padding; `grep -n` over `skill-git-workflow/SKILL.md` and `merge.md`
  for "merge"; `grep -rn` over `agent-system/` for `gh pr list|create|edit`/`--body-file`
  precedent.
- `jq -r '.extensions.core.source_dir' .claude-extensions.json` ->
  `/home/benjamin/.config/nvim/agent-system/extensions/core` (source-store resolution, per
  `rules/source-store-deploy-boundary.md`; no edits made in this dispatch, research only).
- `python3`/`jq` reads of `specs/state.json` to confirm this task's own `file_scope`.
