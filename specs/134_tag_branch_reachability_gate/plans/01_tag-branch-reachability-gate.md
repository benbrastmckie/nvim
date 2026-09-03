# Implementation Plan: Task #134

- **Task**: 134 - Close the tag-reachability gap so /tag never pushes a tag pointing at unpushed commits
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/134_tag_branch_reachability_gate/reports/01_tag-branch-reachability-gate.md
- **Artifacts**: plans/01_tag-branch-reachability-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/tag`'s Step 2 ("Validate Git State") computes only `behind=$(git rev-list --count "HEAD..origin/$current_branch")` and never the symmetric `ahead`, so tagging from a branch with unpushed commits produces a pushed tag pointing at a commit absent from `origin/<branch>` -- which a consuming repo's `release.yml` preflight rejects via `git merge-base --is-ancestor` only *after* the tag is already public. This plan adds a REFUSE gate to Step 2 that reuses the fetch and `remote_sha` already computed there, documents the new failure mode in SKILL.md's Error Handling section, keeps `commands/tag.md` in sync, and verifies the fix behaviorally against a real local origin rather than by inspection. Done means: a branch ahead of its remote hard-stops before any tag is created (including under `--dry-run`), and a tag produced by a passing run literally satisfies `git merge-base --is-ancestor "$new_version" "origin/$current_branch"`.

### Research Integration

All five dispatch design questions were resolved in the research report and are treated here as settled inputs, not re-opened:

1. **REFUSE, not auto-push** -- pushing a branch is outward-facing and `/tag` is user-only precisely because publication timing is a human decision; the remedy is one command.
2. **Placement: Step 2**, inside the existing `if [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]` guard, immediately after the `behind` check.
3. **Exact predicate, not a proxy** -- research confirmed `/tag` always tags `HEAD` (Step 6 runs `git tag -a "$new_version" -m "$tag_message"` with no commit-ish; Step 4 reports `git rev-parse HEAD` as the release commit), so `ahead == 0` is *mathematically identical* to `git merge-base --is-ancestor HEAD origin/$current_branch`, not an approximation. The HEAD-only invariant is recorded as a maintenance assumption in the inline comment.
4. **`--dry-run` truthfulness satisfied by placement** -- REFUSE adds no new command, so the "Would execute:" block is unchanged; Step 2 already runs strictly before Step 5's `--dry-run` early exit.
5. **No override flag** -- an ahead-of-remote branch has exactly one safe remedy and no legitimate bypass; a `--skip-*` flag would hand back the footgun. Both flag tables therefore stay unchanged.

The report also recorded a reasoned scope boundary: a branch with **no upstream at all** yields the same `remote_sha=""` as a failed `git fetch` and is indistinguishable from it without an extra network round-trip. That pre-existing fail-open posture is deliberately not changed here (see Non-Goals).

### Prior Plan Reference

No prior plan for this task. Prior *art* is task 131 (annotated tag + changelog preflight), which closed the reference gate's first two assertions and explicitly filed this third one as a follow-up; its dual-file update discipline (SKILL.md + commands/tag.md together) and its disclose-then-optionally-skip error style are the conventions this plan follows.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add an `ahead`-of-remote REFUSE gate to `agent-system/extensions/core/skills/skill-tag/SKILL.md` Step 2, reusing the fetch and `remote_sha` already computed there.
- Make the failure message actionable and self-explaining: state the count, why it matters (the consuming repo's preflight rejects the tag *after* it is pushed), and the exact remedy (`git push origin $current_branch`).
- Record the HEAD-only invariant that makes the `ahead` count equivalent to the CI's ancestry predicate, so a future maintainer who adds non-HEAD tagging knows the equivalence must be re-derived.
- Document the new failure mode in SKILL.md's Error Handling section, next to "Behind Remote" and matching its format.
- Keep `agent-system/extensions/core/commands/tag.md` in sync (Workflow step 1, Requirements list) so the command doc does not contradict the skill.
- Verify behaviorally against a real local origin, including the literal `git merge-base --is-ancestor` assertion the CI gate uses.

**Non-Goals**:
- No auto-push of the branch (design question 1, decided: REFUSE).
- No `--skip-*` override flag; no change to either file's flag table (design question 5).
- No change to Step 5's `--dry-run` "Would execute:" block (design question 4 -- nothing new to preview).
- No hardening of the never-pushed / fetch-failed `remote_sha=""` fail-open path (recorded scope boundary in the research report).
- No check for the reference workflow's fourth assertion (tagged `release.yml` matching origin's copy) -- workflow-content-specific, out of scope for a repo-agnostic skill.
- No coupling to any repository's branch name: `$current_branch` throughout, never a literal `master`/`main`.
- No change to `/tag`'s user-only status or the agent prohibition.
- No edits to any deployed `.claude/skills/skill-tag/SKILL.md`; regenerating the deploy tree from the source store is a separate, user-driven reload.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Edit lands in a deployed `.claude/**` copy instead of the source store, and is silently wiped on next regeneration | H | M | Phase 1 opens the file by its `agent-system/extensions/core/...` path only; Phase 4 greps the repo to confirm no `.claude/**` file was modified |
| Error-message text in SKILL.md's Error Handling example drifts from the actual `echo` lines in Step 2 | M | M | Phase 2 copies the strings from the Phase 1 diff verbatim rather than paraphrasing, and depends on Phase 1 so the source strings already exist |
| Diverged branch (both ahead and behind) surfaces only the "behind" error | L | H | Accepted and documented: the existing `behind` check exits first, and pulling is a genuine prerequisite before "ahead" can be correctly assessed. Phase 4 case (c) asserts this ordering explicitly rather than leaving it untested |
| New check accidentally placed after Step 5's `--dry-run` early exit, making `--dry-run` under-report | H | L | Placement is inside Step 2, structurally before Step 3; Phase 4 case (d) exercises `--dry-run` on an ahead branch and asserts a non-zero exit |
| `commands/tag.md` left contradicting SKILL.md | M | M | Phase 3 is a required phase, not an optional tidy-up; Phase 4's checklist reads both files |
| Shell syntax error introduced in a markdown-embedded block (no compiler catches it) | M | L | Phase 4 extracts every fenced `bash` block from SKILL.md and runs `bash -n` over it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the ahead-of-remote gate to SKILL.md Step 2 [COMPLETED]

**Goal**: `/tag` hard-stops with an actionable message when the current branch has commits not present on `origin/$current_branch`.

**Tasks**:
- [x] Open `agent-system/extensions/core/skills/skill-tag/SKILL.md` and re-anchor on Step 2's `### Step 2: Validate Git State` heading (do not trust the research report's line numbers). *(completed)*
- [x] Inside the existing `if [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]; then` guard, immediately after the `behind` block's closing `fi`, add the `ahead` block: `ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null || echo "0")`, then `if [ "$ahead" -gt 0 ]` -> error + `exit 1`. *(completed)*
- [x] Write the error body to state all three things: the count (`Local branch is $ahead commit(s) ahead of remote (not fully pushed).`), the consequence (a tag created now points at a commit absent from `origin/$current_branch`; the consuming repo's `git merge-base --is-ancestor` preflight rejects it *after* the push, requiring delete-and-re-push), and the remedy (`Resolution: Push the branch with 'git push origin $current_branch' before tagging.`). *(completed)*
- [x] Add the inline comment recording the HEAD-only invariant: the `ahead` count is identical to (not a proxy for) the CI's ancestry predicate *because* Step 6 tags HEAD with no commit-ish, and the equivalence must be re-derived if `/tag` ever gains non-HEAD tagging. *(completed)*
- [x] Update the closing success line to `echo "Git state: OK (clean working tree, fully pushed, up-to-date with remote)"`. *(completed)*
- [x] Confirm no other Step 2 behavior changed: the dirty-tree check, the detached-HEAD check, the `git fetch ... || true`, and the `behind` check are all untouched. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly one edit site (Step 2's fenced bash block) plus one string change (the "Git state: OK" line) in one file. Confirm at implementation time by grepping the file for `rev-list --count` and `Git state: OK` and checking each hit is accounted for; if a second Step-2-like block exists anywhere in the file, stop and reconcile before editing.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` - Step 2 bash block: new `ahead` check and revised success message.

**Verification**:
- Extract Step 2's fenced bash block to a temp file and run `bash -n` on it.
- Re-read the edited block and confirm the `ahead` check sits *inside* the `remote_sha` guard and *after* the `behind` check's `fi`.
- Confirm no literal branch name (`master`, `main`) appears in the added lines -- `$current_branch` only.
- Confirm the changed path is under `agent-system/extensions/core/`, not `.claude/`.

---

### Phase 2: Document the new failure mode in SKILL.md Error Handling [COMPLETED]

**Goal**: The Error Handling section shows the ahead-of-remote failure exactly as a user will see it, adjacent to the existing "Behind Remote" entry.

**Tasks**:
- [x] Add a `### Ahead of Remote (Not Fully Pushed)` subsection immediately after the existing `### Behind Remote` subsection. *(completed)*
- [x] Fill the fenced example with the literal output of a failing run: the `=== Validating Git State ===` header, then the exact `echo` strings added in Phase 1 with `$ahead` and `$current_branch` rendered as concrete values (use the real incident's count and a plausible branch name, mirroring how "Behind Remote" uses a concrete `3 commit(s)`). *(completed)*
- [x] Diff the example strings against the Phase 1 `echo` lines character-for-character; any divergence is a defect in this phase, not an acceptable paraphrase. *(completed)*
- [x] Confirm the surrounding Error Handling entries (`Dirty Working Tree`, `Behind Remote`, `Tag Already Exists`, the version/changelog entries) are unmodified. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` - Error Handling section: new subsection.

**Verification**:
- Every changed hunk lies inside a markdown heading or fenced example block (no executable surface touched in this phase).
- Each `echo`-derived line in the new example has a matching source line in Step 2's bash block.

---

### Phase 3: Sync commands/tag.md with the new requirement [COMPLETED]

**Goal**: The command doc states the fully-pushed requirement so it cannot silently contradict the skill.

**Tasks**:
- [x] Update Workflow item 1 to name all three Step 2 conditions: clean working tree, branch fully pushed, up-to-date with remote. *(completed)*
- [x] Add a Requirements bullet for the new gate, explaining *why* (a consuming repo's release preflight requires the tagged commit to be reachable from `origin/<branch>`), in the same explanatory style as the existing version/changelog bullets. *(completed)*
- [x] Leave the flag table unchanged and confirm it -- no flag was added (research decision 5). *(completed)*
- [x] Leave the Warning, Examples, and Agent Restrictions sections unchanged. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly two edit sites in `commands/tag.md` (Workflow item 1, Requirements list) and zero changes to the flag table. Confirm at implementation time with `git diff --stat` on that file and a read-through of the resulting diff hunks; more than two hunks means the scope estimate was wrong and needs reconciling before the phase closes.

**Files to modify**:
- `agent-system/extensions/core/commands/tag.md` - Workflow item 1, Requirements list.

**Verification**:
- `git diff` on the file shows changes only in the Workflow and Requirements sections.
- The flag table is byte-identical to its pre-edit state.

---

### Phase 4: Behavioral smoke test and final consistency gate [COMPLETED]

**Goal**: Prove the gate behaves correctly against a real git remote and that a passing run's tag literally satisfies the CI predicate.

**Tasks**:
- [x] Extract every fenced `bash` block from the edited SKILL.md into a scratch file and run `bash -n` over each; all must parse. *(completed: 12 fenced bash blocks extracted, all pass bash -n)*
- [x] Build a throwaway fixture in the scratchpad directory (never inside this repository): a bare repo acting as `origin`, plus a clone with a commit history, so `origin/<branch>` is a real ref. *(completed: bare origin + clone fixture built in scratchpad)*
- [x] Drive Step 2's logic against the fixture in four states and assert the outcome of each: **(a)** branch fully pushed -> passes, prints the revised "fully pushed" success line; **(b)** branch ahead -> exits non-zero with the ahead message naming the correct count and branch; **(c)** branch behind -> exits non-zero with the *behind* message (confirming the existing check still fires first, including on a diverged branch that is both ahead and behind); **(d)** each of (a)-(c) again with `--dry-run` -> the gate still fires, because Step 2 precedes Step 5's early exit. *(completed: (a) pass, (b) ahead exit1, (c) behind exit1 fires first on diverged, (d) dry_run=true does not change Step2 outcome for any state)*
- [x] For case (a), complete the tag creation and assert `git merge-base --is-ancestor "$new_version" "origin/$current_branch"` returns 0 -- the literal reference-gate assertion, not a stand-in. *(completed: git merge-base --is-ancestor v0.0.1-test origin/main exit=0)*
- [x] Confirm the `$ahead` count rendered in case (b)'s message equals the fixture's actual unpushed-commit count. *(completed: ahead=5 matched actual unpushed commit count)*
- [x] Run `git status --short` and confirm no file under `.claude/` was modified and no fixture artifacts leaked into the repository. *(completed: git status --short shows no .claude/ modification; fixture confined to scratchpad)*
- [x] Read SKILL.md and `commands/tag.md` end to end once more and confirm they agree: same conditions, same remedy, no flag added in either. *(completed: SKILL.md and commands/tag.md agree on conditions, remedy, and absence of override flag)*

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts four behavioral cases times the `--dry-run` variant, and that every fenced `bash` block in SKILL.md parses. Confirm the block count at implementation time by counting ```` ```bash ```` fences rather than assuming; if a block fails `bash -n` for a pre-existing reason unrelated to this task, record that explicitly rather than silently excluding it.

**Files to modify**:
- None (verification only). Fixtures live in the scratchpad directory and are not committed.

**Verification**:
- All extracted bash blocks pass `bash -n`.
- Cases (a)-(d) each produce the asserted exit status and message.
- `git merge-base --is-ancestor "$new_version" "origin/$current_branch"` succeeds for the case (a) tag.
- Working tree contains only the two intended source-store file changes.

---

## Testing & Validation

- [x] `bash -n` passes on every fenced bash block extracted from `agent-system/extensions/core/skills/skill-tag/SKILL.md`. *(completed)*
- [x] Fully-pushed branch: Step 2 passes and prints `Git state: OK (clean working tree, fully pushed, up-to-date with remote)`. *(completed)*
- [x] Ahead branch: non-zero exit; message names the correct commit count, the correct branch, the consequence, and the `git push origin $current_branch` remedy. *(completed)*
- [x] Behind branch: non-zero exit with the pre-existing behind message (unchanged behavior). *(completed)*
- [x] Diverged branch (ahead and behind): behind message fires first -- documented, asserted ordering. *(completed)*
- [x] `--dry-run` under each of the three branch states: the gate fires identically; `--dry-run` never reports success where a real run would refuse. *(completed)*
- [x] A tag created by a passing run satisfies `git merge-base --is-ancestor "$new_version" "origin/$current_branch"`. *(completed)*
- [x] No `--skip-*` flag exists for this gate in either SKILL.md or `commands/tag.md`. *(completed)*
- [x] No file under any `.claude/` directory was modified. *(completed)*

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-tag/SKILL.md` -- Step 2 `ahead` gate, revised success message, new `Ahead of Remote (Not Fully Pushed)` Error Handling subsection.
- `agent-system/extensions/core/commands/tag.md` -- Workflow item 1 wording, new Requirements bullet.
- `specs/134_tag_branch_reachability_gate/summaries/01_tag-branch-reachability-gate-summary.md` -- implementation summary (written at implement time).

## Rollback/Contingency

Both edits are additive and confined to two files in the source store. To revert: `git revert` the phase commits, or `git checkout <pre-change-sha> -- agent-system/extensions/core/skills/skill-tag/SKILL.md agent-system/extensions/core/commands/tag.md`. No state, schema, or deployed artifact is mutated, so reverting restores the prior behavior exactly (the pre-existing fail-open posture on an unresolvable `origin/<branch>` is unchanged by this work in either direction). If Phase 4 reveals the gate misfires on a legitimate release, the correct response is to fix the predicate, not to add a bypass flag -- an override was considered and rejected in research.
