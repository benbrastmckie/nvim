# Research Report: Task #134

- **Task**: 134 - Close the tag-reachability gap so /tag never pushes a tag pointing at unpushed commits
- **Started**: 2026-09-03T00:00:00Z
- **Completed**: 2026-09-03T00:00:00Z
- **Effort**: ~1 hour (research)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/skills/skill-tag/SKILL.md` (canonical source, read in full)
  - `agent-system/extensions/core/commands/tag.md` (canonical source, read in full)
  - `specs/archive/131_tag_annotated_and_changelog_preflight/reports/01_tag-annotated-and-changelog-preflight.md` (prior art, read in full)
  - `specs/archive/131_tag_annotated_and_changelog_preflight/summaries/01_tag-annotated-changelog-preflight-summary.md` (prior art follow-up quote, read in full)
  - `.dispatch/4.md` for task 134 (dispatch contract, read in full)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed the defect exactly as described against the live source: `SKILL.md` Step 2
  (lines 90-104) computes only `behind` and never a symmetric `ahead`; Step 6 pushes the tag
  alone with no branch push.
- Resolved all five design questions the dispatch requires be decided deliberately (see
  Decisions). Net design: **REFUSE, placed in Step 2, using the `ahead` rev-list count (not a
  separate `merge-base` call), with no override flag.**
- Key finding that resolves design question 3 outright: `/tag` **always** tags `HEAD` (Step 6's
  `git tag -a "$new_version" -m "$tag_message"` has no commit-ish argument, and Step 4 reports
  `git rev-parse HEAD` as "the" commit). Given that invariant, `ahead == 0` is not a proxy for
  the CI's `git merge-base --is-ancestor` predicate — it is **mathematically identical** to it.
  This resolves design question 2's placement concern as well: a Step-2-placed check needs no
  tag ref, only `HEAD` vs `origin/$current_branch`, both already available before Step 6 creates
  anything.
- Discovered one adjacent edge case during analysis — a branch with no upstream at all (never
  pushed) also yields `remote_sha=""` and is silently treated today as "cannot determine, skip"
  (fail-open, same code path used when `git fetch` fails due to network issues). Recommend
  **not** hardening this case in this task; recorded as an explicit, reasoned scope boundary
  below rather than silently left unexamined.
- Concrete patch surface: `SKILL.md` Step 2 (add the `ahead` block + revise the closing "Git
  state: OK" message), `SKILL.md` Error Handling (new "Ahead of Remote" subsection next to
  "Behind Remote"), `commands/tag.md` (Workflow step 1 wording, Requirements bullet). No new
  flag, so the flag table in both files is unchanged.

## Context & Scope

Task 134 closes the third and last gate the reference `release.yml` preflight enforces that
`/tag` does not yet satisfy: that the tagged commit is reachable from `origin/<branch>`. The
first two gates (annotated tag, non-empty CHANGELOG entry) were closed by task 131, whose
research report explicitly deferred this one as a distinct follow-up (quoted verbatim in the
dispatch). This report resolves the five design questions the dispatch poses and hands the
planner a fully specified patch, without writing the implementation itself (research phase).

## Findings

### Codebase Patterns

**Current Step 2** (`SKILL.md:64-107`), the exact block this task extends:

```bash
# Check if local is behind remote
git fetch origin "$current_branch" --quiet 2>/dev/null || true
local_sha=$(git rev-parse HEAD)
remote_sha=$(git rev-parse "origin/$current_branch" 2>/dev/null || echo "")

if [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]; then
  # Check if we're behind
  behind=$(git rev-list --count "HEAD..origin/$current_branch" 2>/dev/null || echo "0")
  if [ "$behind" -gt 0 ]; then
    echo "Error: Local branch is $behind commit(s) behind remote."
    echo ""
    echo "Resolution: Pull latest changes with 'git pull' before tagging."
    exit 1
  fi
fi

echo "Git state: OK (clean working tree, up-to-date with remote)"
```

Confirms the prior-art finding precisely: `git fetch` and `remote_sha` are already computed;
only the symmetric direction (`origin/$current_branch..HEAD`) is missing.

**Confirmed: `/tag` always tags `HEAD`.** Step 4 reports `git rev-parse HEAD` as the commit being
released; Step 6 (`SKILL.md:458`) runs `git tag -a "$new_version" -m "$tag_message"` with no
commit-ish argument, which defaults to `HEAD`. There is no code path in this skill that tags
anything other than the current `HEAD`. This is the load-bearing fact for design question 3.

**Existing disclose-then-optionally-skip pattern** (Step 3.5/3.6): print the full failure detail
unconditionally, then either `exit 1` or (if the matching `--skip-*` flag is set) a `WARNING:`
line — never suppress the disclosure. Both existing gates run unconditionally, including under
`--dry-run`, per the explicit comment at `SKILL.md:161-163`: "This step runs for every invocation
path — default, `--force`, and `--dry-run` alike — because it sits strictly before Step 5's
`--dry-run` `exit 0`." Step 2 already satisfies this same invariant by construction (it runs
before Step 3, which runs before Step 5) — no new plumbing is needed to keep the new check
`--dry-run`-safe.

### External Resources

No new external research was needed — the reference contract (ModelChecker's `release.yml`
preflight, `git merge-base --is-ancestor "${GITHUB_REF_NAME}" origin/master`) was already fully
captured by task 131's research and quoted verbatim in this task's dispatch. Re-verified it says
exactly what the dispatch quotes: ancestry of the *tagged commit* (not `HEAD` in the abstract)
from `origin/<branch>`.

### Recommendations

**Patch to `SKILL.md` Step 2** — insert immediately after the existing `behind` check, inside the
same `if [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]; then` guard (so it only
evaluates when a remote ref was actually resolved and differs from `HEAD`; see Decisions for why
the `remote_sha`-empty case is deliberately left alone):

```bash
  # Check if we're ahead (not fully pushed). This is not a proxy for the release preflight's
  # `git merge-base --is-ancestor <tag> origin/<branch>` check -- it is mathematically identical
  # to it, because Step 6 always tags HEAD with no commit-ish argument. HEAD is reachable from
  # origin/$current_branch iff every commit reachable from HEAD is also reachable from
  # origin/$current_branch, iff this count is zero. (If /tag ever gains the ability to tag a
  # non-HEAD commit-ish, this equivalence must be re-derived against that commit-ish instead.)
  ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null || echo "0")
  if [ "$ahead" -gt 0 ]; then
    echo "Error: Local branch is $ahead commit(s) ahead of remote (not fully pushed)."
    echo ""
    echo "A tag created now would point at a commit absent from origin/$current_branch. A"
    echo "consuming repo's release preflight (git merge-base --is-ancestor) would reject the"
    echo "tag AFTER it has already been pushed, requiring a delete-and-re-push to recover."
    echo ""
    echo "Resolution: Push the branch with 'git push origin $current_branch' before tagging."
    exit 1
  fi
```

And revise the closing success line to reflect the now-broader invariant, e.g.:

```bash
echo "Git state: OK (clean working tree, fully pushed, up-to-date with remote)"
```

**Patch to `SKILL.md` Error Handling** — add a new subsection immediately after "Behind Remote"
(mirroring its format exactly):

```
### Ahead of Remote (Not Fully Pushed)

\`\`\`
=== Validating Git State ===

Error: Local branch is 36 commit(s) ahead of remote (not fully pushed).

A tag created now would point at a commit absent from origin/main. A consuming repo's
release preflight (git merge-base --is-ancestor) would reject the tag AFTER it has already
been pushed, requiring a delete-and-re-push to recover.

Resolution: Push the branch with 'git push origin main' before tagging.
\`\`\`
```
(The `36 commit(s)` figure deliberately echoes the real incident number from the task
description, matching how "Behind Remote"'s own example uses a concrete, plausible count.)

**Patch to `commands/tag.md`**:
- Workflow list item 1: "Validate Git State: Check for clean working tree, branch fully pushed,
  and up-to-date with remote" (currently omits the pushed half entirely).
- Requirements section: add a bullet — "Local branch has no commits ahead of `origin/<branch>`
  (fully pushed) — a consuming repo's release preflight requires the tagged commit to be
  reachable from `origin/<branch>`."
- No flag-table change (see Decisions, design question 5: no new flag).

No changes are needed to Step 5's `--dry-run` "Would execute:" block, since the chosen design is
REFUSE (not auto-push) — there is no new action to preview, only an earlier hard-stop that
already runs (via Step 2's unconditional placement) before Step 5 is ever reached.

## Decisions

Each of the dispatch's five design questions, resolved and recorded (not defaulted):

1. **REFUSE, not auto-push.** Matches the dispatch's own default recommendation. Pushing a
   branch is an outward-facing action with materially different risk than pushing a tag — the
   whole reason `/tag` is user-only is that deployment timing is a human decision, and silently
   publishing unreviewed commits as a side effect of a tag command would undermine that boundary.
   The remedy (`git push origin $current_branch`) is one command, so REFUSE imposes negligible
   friction relative to the risk auto-push would introduce.

2. **Placement: Step 2**, immediately after the existing `behind` check, reusing `remote_sha`
   and the same guard. The dispatch's own reconciliation concern (Step 2 runs before the tag ref
   exists) turns out not to bind: the chosen predicate (see #3) only ever needs `HEAD` and
   `origin/$current_branch`, both already resolved at Step 2, so there is no ordering conflict
   with design question 3's answer.

3. **Exact predicate, not merely an accepted proxy.** Use the `ahead` rev-list count
   (`git rev-list --count "origin/$current_branch..HEAD"`), symmetric with the existing `behind`
   check's style and reusing the same already-fetched `remote_sha`. This is deliberately **not**
   framed as "an accepted proxy with the divergence documented" — research confirms `/tag` always
   tags `HEAD` (Step 6 passes no commit-ish; Step 4 reports `git rev-parse HEAD` as the release
   commit), so `ahead == 0` is provably equivalent to
   `git merge-base --is-ancestor HEAD origin/$current_branch`, not an approximation of it. A
   separate `git merge-base --is-ancestor` call was considered and rejected: it would cost an
   extra process invocation for a boolean where the rev-list count already gives the same answer
   with a useful integer for the error message, and it would be no more "exact" given the
   HEAD-only invariant. The recorded assumption for future maintainers: if `/tag` ever gains the
   ability to tag a non-`HEAD` commit-ish, this equivalence breaks and the check must be
   re-derived against that commit-ish rather than `HEAD`.

4. **`--dry-run` truthfulness: satisfied by placement, no new preview text needed.** Because the
   design is REFUSE (not auto-push), there is no new command for the dry-run "Would execute:"
   block to misrepresent. Step 2 already runs unconditionally before Step 5's `--dry-run` early
   exit (same invariant Steps 3.5/3.6 already rely on), so the new check is `--dry-run`-safe by
   construction, not by any added special-casing.

5. **No override flag.** Unlike a version or changelog mismatch — which can reflect a legitimate
   judgment call the operator is entitled to override — an ahead-of-remote branch has exactly one
   safe remedy (`git push origin $current_branch`) with no legitimate reason to bypass it: doing
   so would deliberately reproduce the exact incident this task exists to prevent. Adding a
   `--skip-branch-push-check` flag would hand back the footgun this task removes. Recorded
   explicitly per the dispatch's instruction to justify "no flag" rather than omit it silently.

6. **Scope boundary (not one of the five numbered questions, but discovered during analysis and
   recorded per the same "decide deliberately" standard):** a branch with **no upstream at all**
   (never pushed even once) also produces `remote_sha=""`, which today silently skips the whole
   `behind`/`ahead` block — the exact same code path used when `git fetch` fails for network
   reasons (line 91's `2>/dev/null || true`). These two situations are indistinguishable from
   `remote_sha` alone: "definitely no remote branch" and "couldn't tell, fetch failed" look
   identical. Hardening this would require an additional network round-trip
   (e.g. `git ls-remote --exit-code origin "$current_branch"`) to disambiguate, which is a more
   invasive change than the symmetric `ahead` check this task's dispatch scopes. **Decision: do
   not fix this in task 134.** It is a pre-existing fail-open posture (consistent with the
   `git fetch ... || true` on the very next line), not a regression this task introduces, and
   fixing it well requires a different mechanism than "reuse `behind`/`remote_sha`." Left as an
   explicitly named, reasoned non-goal rather than silently out of scope.

## Risks & Mitigations

- **Diverged branch (both ahead and behind > 0)**: the existing `behind` check's `exit 1` fires
  first, so the user sees only the "behind" message on a diverged branch, not both. This
  preserves existing sequential-check behavior (mirrors how Step 3.5/3.6 already run to
  independent completion but Steps as a whole gate sequentially) and is a reasonable ordering —
  pulling to resolve "behind" is a prerequisite step the user must do before "ahead" can even be
  correctly assessed.
- **Message-string drift between `SKILL.md`'s dry-run preview and Step 6's real commands**: not
  applicable here since no new command needs previewing (see Decision #4).
- **Doc drift** (`commands/tag.md` silently falling out of sync with `SKILL.md`): task 131
  already established the dual-file update discipline this task should follow; the specific
  lines to change are given above.

## Context Extension Recommendations

None. This task's scope is fully covered by the existing `agent-system/extensions/core/skills/
skill-tag/` and `commands/tag.md` pair; no new context file is warranted for a two-file,
single-skill patch of this size.

## Appendix

- Search queries / commands used: `find specs -iname '*131*'` (located the archived prior-art
  task at `specs/archive/131_tag_annotated_and_changelog_preflight/`), full reads of
  `SKILL.md` (727 lines) and `commands/tag.md` (82 lines), `jq` against `specs/state.json` to
  confirm task 134's recorded description and artifact state.
- Referenced line numbers are as of this research pass (`SKILL.md` at the commit current when
  this report was written); the planner/implementer should re-anchor against the checked-out
  file rather than trusting these numbers verbatim.
