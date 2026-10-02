# Research Report: Task #277

**Task**: 277 - Make an unresolvable pathspec a hard error in git-commit-scoped.sh instead of a silent WARN-and-drop
**Started**: 2026-10-02
**Completed**: 2026-10-02
**Effort**: Small (script + one caller-side check; large audit surface but narrow fix)
**Dependencies**: None (the Move 2 isolation-forwarding dependency was dropped with part (a))
**Sources/Inputs**: Codebase (git-commit-scoped.sh, all call sites), git history, empirical
reproduction in scratch repos, specs/decisions/worktree-isolation-removal-verdict.md
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The literal bug described in the task's premise is already fixed.** A prior change (task
  226 phase 2, commit `94256557d`) added a post-filter V3 safety gate
  (`agent-system/extensions/core/scripts/git-commit-scoped.sh:318-326`) that already refuses with
  a loud `exit 2` when *every* positive pathspec entry drops as unmatched. I verified this
  empirically (see Findings) — it is not a reading of the comments, it is a reproduced result.
- **A different, still-live gap exists just next to it.** When *some but not all* positive
  pathspecs drop, and the surviving (matched) pathspecs happen to have no actual working-tree
  diff, `git commit` legitimately reports "nothing to commit" (exit 1) — and this exit code is
  **indistinguishable** from the fully benign case where *zero* pathspecs dropped and nothing
  changed anywhere. I reproduced both and the stdout/exit code are identical except for one WARN
  line on stderr that no caller inspects.
- Every caller in the codebase — the three live script call sites
  (`orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`) and the ~50 SKILL.md/agent
  `.md` documented bash snippets — wraps the invocation as `... || echo "WARN: ...(non-blocking)"`.
  Because of how `||` works, **any** nonzero exit (1, 2, or 3) collapses to exit 0 for the calling
  script's own control flow. This means a louder exit code from `git-commit-scoped.sh` alone does
  not change caller behavior unless at least one caller is changed to branch on `$?` explicitly.
- Recommended posture: a corrected form of option **(c)** — refuse (new distinct exit code) when
  **one or more positive pathspecs were dropped as unmatched AND the resulting commit attempt
  would otherwise produce zero commits** — not literally "100% dropped" as the task text phrases
  it, since the V3 gate already covers the 100%-dropped case and the literal reading leaves the
  demonstrated gap open. Options (a) and (b) are worse fits; see Decisions.

## Context & Scope

Task 277 was narrowed to part (b) only: making an unresolvable pathspec drop a hard error,
independent of the (now-moot, since per-dispatch worktree isolation was removed) worktree-
targeting part (a). The dispatch instructs: audit every call site first, then choose between
three postures (a)/(b)/(c), ranked by how small and auditable the refusal surface is, and add
regression tests. This report performs that audit and resolves the open question empirically
rather than by inference alone, since the task's own description of current behavior turned out
to be only partially accurate against the code as it stands today.

## Findings

### The script's current gates (read in full, `git-commit-scoped.sh:90-451`)

Four safety gates exist today, in this order: V3 pre-filter (exclude-only list refused, line
160-163) → ephemeral-exclude injection (textual pattern match on `specs/[0-9][0-9][0-9]_*/`,
lines 187-209, independent of filesystem state) → V5 contended-path refusal (`--task` opt-in
only, lines 212-271) → V2 three-way classification (matched / already-staged-deletion /
genuinely-unmatched-and-dropped, lines 283-316) → **V3 post-filter** (lines 318-326): refuses
with `exit 2` if, after dropping unmatched entries, zero positive pathspec entries remain.

### Empirical verification (three scratch-repo runs, not just reading)

I built three synthetic git repos (mirroring the existing test harness's `mktemp -d` +
copy-the-script pattern) and ran the real script against each:

1. **All three caller pathspecs unmatched** (`specs/999_nonexistent_task/`, `specs/TODO.md`,
   `specs/state.json` — none exist in the scratch repo, simulating a wrong-tree invocation where
   `specs/` does not exist at all): the script printed three WARN lines, then **`ERROR: ...zero
   positive pathspec entries remain... exit 2`**. No `git add`, no commit. This is the scenario
   the task's "THE DEFECT" section describes as returning silent success — it does not, today.
2. **Partial drop, but no real diff on the survivors** (`specs/999_nonexistent_task/` dropped;
   `specs/TODO.md` and `specs/state.json` exist and are already committed with identical
   content): the script printed one WARN line for the dropped path, then ran `git add` on the
   two survivors, found no diff, and printed `NOTE: Nothing to commit or git commit failed
   (non-blocking)` with **exit 1**.
3. **Fully benign, zero drops** (same two files, no third pathspec at all, no diff): identical
   output and **exit 1** to case 2, with no WARN line (the only textual difference).

Cases 2 and 3 are the live gap: at the exit-code level they are identical, yet case 2 is exactly
the false-success fingerprint the task is written to close (something real — the task directory
— was silently dropped and never staged, while the survivors contributed nothing), and case 3 is
the ordinary, must-remain-non-fatal "nothing changed" outcome every research/plan/implement
no-op commit relies on.

### Why option (c), read literally ("fatal only when EVERY pathspec dropped"), does not close
the demonstrated gap

The task phrases (c) as keying off the *drop count* (100% vs. partial). But the V3 post-filter
gate already handles the 100%-drop case via `exit 2`. The actual remaining risk, demonstrated in
case 2 above, is a *partial* drop combined with a commit that ends up empty anyway — which
"100%-dropped" framing does not cover. The fix needs to key off a different pair of signals:
**(count of dropped entries > 0) AND (the eventual `git commit` attempt would produce zero new
commits)**, not the drop count alone.

### Why option (a) is a weaker fit than it first appears

Option (a) proposes distinguishing "parent directory exists" (tolerable) from "parent directory
absent or path outside the repo" (hard error). I checked this against the actual historical
incident and the reproduction above: the discriminating entries are almost always
`specs/{NNN}_{slug}/`-shaped, whose *parent* is `specs/` itself — and `specs/` exists in **any**
repo deployed with this agent-system scaffold, including the wrong-tree BimodalLogic repository
the incident actually hit (per `specs/decisions/worktree-isolation-removal-verdict.md:51`, a
separate, real, scaffold-bearing repository, not an empty scratch directory). So "parent exists"
would be true in the wrong-tree case too, and (a) would **not** have caught the historical
incident. It also adds materially more logic (per-path parent-existence checks, with their own
edge cases for `:(exclude)` entries, symlinks, and already-tracked-but-deleted paths) for a
narrower payoff than (c).

### Why option (b) is the most invasive for the smallest marginal gain

Option (b) requires every caller to explicitly mark which of its pathspecs are optional. The
audit below shows roughly 50 distinct call sites (three live scripts plus ~47 SKILL.md/agent
`.md` documented bash snippets across core and extension skills). Changing the CLI contract to
require an opt-in marker on optional paths means touching (or at minimum auditing and
knowingly leaving stale) all of them, which is a much larger and harder-to-verify footprint than
(c) for a fix whose payoff is identical to (c)'s once (c) is corrected as above.

### Call-site audit

**Live script callers** (actual bash invoking the real script with real pathspecs, not prose):

| Call site | Pathspec shape | Can a legitimate entry be absent today? |
|---|---|---|
| `orchestrate-cycle-postflight.sh:1289` (WORK i, `stage_paths` built at line 1243) | `${TASK_DIR}/`, `specs/TODO.md`, `${STATE_FILE}` (both tracked, always exist), conditionally `$plan_path` (only appended when non-empty and phase=implement — already guarded), plus the agent's self-reported `modified_files[]` | Yes, via `modified_files[]`: an agent can self-report a path it did not actually touch (typo, stale report, or a file it deleted with a non-`git rm` `rm`). This is the "legitimate partial drop" shape the hard constraint protects. |
| `orchestrate-unwind-dispatch.sh:394` | `specs/state.json specs/TODO.md` only | No — both are permanently-tracked root files; this call site can never legitimately hit the drop path. |
| `agent-system/extensions/core/scripts/orchestrator-postflight.sh:552` | Same shape as `orchestrate-cycle-postflight.sh` | **This script has no live callers** (confirmed via repo-wide grep and corroborated by an explicit comment in `skill-base.sh:908-909`: "orchestrator-postflight.sh itself has no live callers"). Not a real audit target; mentioned for completeness only. |

**Documented bash snippets** (agent-executed, not script-executed; sampled across core lifecycle
and several extensions — `skill-lean-research`, `skill-lean-implementation`,
`general-implementation-agent.md`'s Green Sub-Step Commit and Phase Checkpoint Protocol,
`research-workflow.md`/`planning-workflow.md`/`implementation-workflow.md`): the canonical shape
is always `{task_dir}/` (a directory pathspec, always matches once the task directory exists —
confirmed task directories are created with `reports/`, `plans/`, `summaries/` subdirectories at
`/task` time) plus `specs/TODO.md` plus `specs/state.json` plus, optionally, a specific artifact
file path (`.return-meta.json`, a `plan_path`, or self-reported `modified_files`/`files_touched`
entries). The directory pathspec itself essentially never legitimately drops (it matches via
`[ -e "$p" ]` as long as the directory exists, which it does from task creation onward); the
genuinely-optional entries are always the *specific file* paths layered on top — exactly the
"artifact a phase legitimately did not write yet" shape the task names. General-implementation-
agent.md's Green Sub-Step Commit snippet (line 290) includes a literal `"{plan_path}"` template
placeholder in curly-brace form (matching the `{N}`/`{NNN}` documentation convention) rather than
a bash variable — a template-substitution bug if ever copied verbatim is a *separate*, pre-
existing minor risk worth flagging to the plan phase, but it is not part of this task's scope.

No other active task declares `git-commit-scoped.sh` or its test file in `file_scope` (confirmed
via the territory block in the dispatch and a fresh grep), so there is no coordination hazard
with concurrent siblings this cycle.

### The caller-side swallowing problem

Independent of which posture is chosen, **every** caller — live script or documented snippet —
uses the `cmd || echo "WARN: ...(non-blocking)"` idiom. In bash, `A || B` evaluates to `B`'s exit
status when `A` fails, which is `echo`'s exit status: 0. So regardless of whether
`git-commit-scoped.sh` exits 1, 2, 3, or a new distinguishing code, the calling script's own
control flow sees success and continues. A new "hard error" exit code is necessary but not
sufficient to prevent a repeat of the historical incident unless at least the in-scope live
caller(s) are changed to branch on `$?` and escalate specifically on the new code (e.g. write a
`blocked`/`partial` outcome, or re-raise loudly) rather than applying the same blanket
non-blocking warning to every nonzero exit. This is a plan-phase decision, not a research
finding to resolve here, but it must be named explicitly or the fix will be silently
ineffective in practice even though it is technically correct inside the script.

## Decisions

- **Adopt a corrected option (c)**: refuse with a distinct exit code when (count of pathspecs
  dropped as genuinely-unmatched > 0) AND (the eventual commit attempt stages/commits nothing at
  all) — not the task's literal "100% dropped" phrasing, which the empirical reproduction shows
  already handled by the existing V3 post-filter gate and does not cover the demonstrated
  residual gap.
- **Reject option (a)**: the parent-directory-exists heuristic would not have caught the actual
  historical incident (parent `specs/` exists in any scaffold-bearing repo) and adds
  materially more logic for a narrower, less robust payoff than (c).
- **Reject option (b)**: requires touching or auditing ~50 call sites to add an opt-in marker
  syntax; disproportionate footprint for the same payoff (c) achieves without any caller changes
  to the CLI contract.
- **Open question for planning**: whether to also update the two in-scope live script callers
  (`orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`) to branch on the new exit
  code distinctly from ordinary "nothing to commit," given the `|| echo WARN (non-blocking)`
  swallowing problem documented above. The task's declared `file_scope` names only
  `git-commit-scoped.sh` and its test file, so expanding into caller scripts is a scope decision
  the plan should make explicitly rather than inherit implicitly.

## Recommendations

1. Inside `git-commit-scoped.sh`, track a count of genuinely-unmatched (case-3) drops across the
   V2 classification loop (a simple counter alongside the existing `filtered_pathspecs`/
   `add_pathspecs` construction, lines 283-316).
2. After the `git commit` attempt (lines 428-443), if `commit_exit` is nonzero (the existing
   "nothing to commit" path) **and** the drop counter is greater than zero, emit a new, clearly
   distinguished exit code (e.g. `exit 4`, since 0-3 are already documented and spoken for) with
   a loud `ERROR:` line naming every dropped path, distinct from today's generic `NOTE: Nothing
   to commit or git commit failed (non-blocking)`. When the drop counter is zero, preserve
   today's exact exit-1 behavior and message — the hard constraint that pathspecs-all-resolve
   callers see no behavior change.
3. Update the script's header-comment exit-code table (lines 53-62) to document the new code.
4. Decide, and record the decision explicitly in the plan, whether `orchestrate-cycle-
   postflight.sh` and `orchestrate-unwind-dispatch.sh` need a `$?`-specific branch to escalate on
   the new code rather than their current blanket `|| echo WARN`. Given both are named in the
   dispatch's territory as uncontended and the task's own hard constraint is about the *script's*
   behavior, the minimal-scope answer is to fix the script now and let callers adopt the new
   code in a follow-up if the plan phase judges in-scope caller changes too large; either way,
   state the choice rather than leaving it implicit.
5. Pin the chosen posture as an explicit, named assertion (per the dispatch's instruction) —
   e.g. a dedicated comment block analogous to the existing V2/V3/V5 "Safety gates" header
   section, labeled for cross-reference in tests and future readers (the next free label in that
   numbering is V6, following the V5 contended-path gate already present).
6. Add to `test-git-commit-scoped.sh` (currently T1-T10, `build_repo`/`add_ephemeral`/
   `run_commit` harness) three new cases, verified via `git log`/exit code exactly like the
   existing T1-T10 (never exit-code-only):
   - **New case A** (wholly-empty stage from 100% drop): confirms the *existing* V3 post-filter
     behavior (exit 2, no commit) is unchanged by this task's change — a regression guard for
     behavior that already exists but has no dedicated test today.
   - **New case B** (the actual gap this task closes): one pathspec dropped, survivors have no
     real diff — must now exit with the new distinguishing code, no commit created.
   - **New case C** (legitimate partial drop that must keep succeeding): one pathspec dropped
     (e.g. a not-yet-produced artifact file), but a survivor DOES have a real diff (e.g.
     `specs/TODO.md` or `specs/state.json` actually changed) — must still create the commit
     exactly as before, proving the hard constraint holds.
7. Re-run `test-lint-scoped-commit-boundary.sh` after the change (no code path in this fix alters
   the `-- <pathspec>` invocation shape the lint checks for, so it is expected to remain green,
   but the dispatch explicitly calls out verifying this).

## Risks & Mitigations

- **Risk**: a new exit code alone gives a false sense of the defect being closed, since every
  current caller swallows it identically to exit 1 via `|| echo WARN`. **Mitigation**:
  Recommendation 4 above — name this explicitly as a plan-phase scope decision rather than
  letting it default to "fixed" when only the script changed.
- **Risk**: miscounting "genuinely dropped" to include already-staged-deletions (case 2) would
  make routine `git mv`/`git rm` commits spuriously fail. **Mitigation**: the counter must only
  increment in the case-3 branch (`git-commit-scoped.sh:310-312`), never case 2
  (`git-commit-scoped.sh:297-308`), which this report's reproduction did not need to touch but
  the plan/implementation phase must preserve carefully — a one-line placement error would
  silently break the deletion-commit path the V2 three-way split exists to protect.
- **Risk**: choosing a reused exit code (1, 2, or 3) for the new condition instead of a fresh one
  would make it indistinguishable from an existing documented meaning to any caller that already
  branches on exit code (none do today, but the V5 `--task` contended-path refusal already
  reserves 3, and repurposing 1 defeats the entire point). **Mitigation**: use a previously-
  unused code (4) and document it in the header table.

## Context Extension Recommendations

- **Topic**: git-commit-scoped.sh's exit-code contract is documented only in the script's own
  header comment, not in `context/standards/git-staging-scope.md`'s "Commit-Level Path Scoping"
  section.
- **Gap**: a reader consulting the standards doc (rather than the script source) would not learn
  about the V2/V3/V5 gates or their exit codes at all; that section currently only narrates the
  two original defects (misattribution, unmatched-pathspec-aborts-everything) without the current
  gate numbering or codes.
- **Recommendation**: once this task's fix lands, add a short exit-code table to
  `git-staging-scope.md`'s "Commit-Level Path Scoping and Cross-Process Serialization" section
  mirroring the script header's, so the standards doc and the script do not drift the way the
  canonical exclusion set itself drifted across nine of eleven call sites before this script was
  introduced (per that section's own history note).

## Appendix

### Search queries / commands used

- `grep -rln "git-commit-scoped\.sh" --include="*.sh" --include="*.md" agent-system/ .claude/` —
  full textual reference inventory (docs + code)
- `grep -n "git-commit-scoped\.sh" agent-system/extensions/core/scripts/*.sh` — live script
  callers only
- `grep -rn "git-commit-scoped\.sh" agent-system/extensions/*/skills/*/SKILL.md agent-system/extensions/*/agents/*.md` —
  extension-level documented snippets (~50 hits)
- `git log --oneline -- agent-system/extensions/core/scripts/git-commit-scoped.sh` — history of
  the script, identifying commit `94256557d` (task 226 phase 2) as the origin of the V3
  post-filter gate
- Three scratch-repo empirical reproductions under `mktemp -d`, each copying the real
  `git-commit-scoped.sh` + `deploy-root-guard.sh` + `task-lock.sh` + `lib/common.sh`, mirroring
  `test-git-commit-scoped.sh`'s own harness pattern, run with `set +e` to capture exit codes
  directly

### References

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (lines 90-451, full read)
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (T1-T10 harness pattern)
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `specs/decisions/worktree-isolation-removal-verdict.md` (line 51: historical incident
  description; line 173: task 277's narrowing disposition)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (lines 1238-1296)
- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh` (lines 389-398)
- `agent-system/extensions/core/agents/general-implementation-agent.md` (Green Sub-Step Commit,
  Phase Checkpoint Protocol)
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md`
