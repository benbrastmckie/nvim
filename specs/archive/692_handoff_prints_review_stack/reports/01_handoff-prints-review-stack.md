# Research Report: Task #692

- **Task**: 692 - Handoff prints the review stack
- **Started**: 2026-11-23T22:30:00Z
- **Completed**: 2026-11-23T23:10:00Z
- **Effort**: 1.5 hours (per parent plan's Phase 5 timing estimate)
- **Dependencies**: None declared
- **Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/milestone-review-handoff.sh`,
  `scripts/review-stack-prepare.sh`, `scripts/tests/test-milestone-review-handoff.sh`,
  `scripts/tests/test-review-stack-prepare.sh`, `scripts/tests/test-orchestrate-conclusion-roadmap.sh`,
  `scripts/lib/push-grant-lib.sh`), parent plan
  `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`
- **Artifacts**: `specs/692_handoff_prints_review_stack/reports/01_handoff-prints-review-stack.md` (this file)
- **Standards**: report-format.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  no-record-versioning-in-deliverables.md

## Executive Summary

- `review-stack-prepare.sh` already exposes exactly the two subcommands this phase needs:
  `cut --milestone <id>` (defaults its own `--stack-id` to the milestone id) and
  `show --stack-id <id>` (prints `PR N: branch=... base=... title=... body_path=...` plus a
  `/please push <remote> <branch>` line per entry and one trailing `/merge --stack <id>` line to
  stdout). `cut` refuses with a non-zero exit and a `REFUSED: review-stack-prepare.sh: <reason>: <message>`
  line on stderr via a direct `exit "$code"` (never inside a subshell), so the handoff can branch
  on `$?` alone.
- The minimal, non-speculative change is: in `milestone-review-handoff.sh`, after the summary
  file's per-task listing is written (today at lines 242-275), call `cut --milestone "$mid"`
  non-fatally, then on exit 0 call `show --stack-id "$mid"` and splice its stdout into the
  summary file and the stderr output in place of today's hardcoded two-line
  `/please push ${integration_branch}` / `/merge` block (lines 266-273 in the file write, 294-295
  on stderr); on any non-zero exit, keep the per-task listing, print the captured
  `REFUSED: ...` line, print `/please push ${integration_branch}` alone, and do not print
  `/merge`. One line stating a grant is bound to `HEAD` at mint time is added on both arms.
- **Scope-narrowing finding**: task 692's own declared `file_scope` is `milestone-review-handoff.sh`
  and its test file only -- narrower than the parent plan's Phase 5 "Files to modify" list, which
  also names `context/contracts/conclusion-stage.md`, `context/standards/git-workflow-narrative.md`,
  and an `index-entries.json` line-count reconciliation. Per this dispatch's own instruction, those
  three paths are out of scope for this record and need a separate one (recorded as an issue;
  see Decisions and Risks below).
- **Test collision found outside file_scope**: `scripts/tests/test-orchestrate-conclusion-roadmap.sh`
  Case H (around line 507) hard-asserts that milestone-review-handoff.sh's stderr contains both
  `/please push <branch>` AND a bare `/merge` line on a fully-done milestone. That sandbox never
  installs `review-stack-prepare.sh`, so under the required behavior the cut call there will
  always take the refusal path (script missing), which must print `/please push` alone and never
  `/merge` -- breaking that pre-existing assertion. This file is outside task 692's file_scope and
  needs its own record to update the assertion.

## Context & Scope

Researched: how to wire `milestone-review-handoff.sh` to `review-stack-prepare.sh`'s `cut`/`show`
subcommands per the parent plan's Phase 5 ("Handoff prints the stack"), scoped strictly to the
two files task 692 declares in `file_scope`
(`agent-system/extensions/core/scripts/milestone-review-handoff.sh` and
`agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh`). Phases 1-3 of the
parent plan are landed (review_base resolution/refusals, unit selection/ordering, cut+show+
record-request, 38 passing cases in `test-review-stack-prepare.sh`). Phase 4 (`restack`) is a
concurrent sibling's territory (task 691, same file_scope as `review-stack-prepare.sh` and its
test) and is irrelevant here: `show`'s already-landed output format does not depend on whether
`restack` exists.

Out of scope for this record (confirmed against the Territory block and the dispatch's own User
focus instruction): editing `review-stack-prepare.sh` itself, `commands/merge.md` (task 693's
file_scope), `context/contracts/conclusion-stage.md`, `context/standards/git-workflow-narrative.md`,
`index-entries.json`, and `scripts/tests/test-orchestrate-conclusion-roadmap.sh`.

## Findings

### The interface `cut`/`show` already present (landed, Phase 3)

- `review-stack-prepare.sh cut (--milestone ID | --batch SESSION | --tasks N,N,...) [--stack-id NAME] ...`
  -- for `--milestone ID`, `stack_id` defaults to `ID` itself
  (`scripts/review-stack-prepare.sh:321`). The handoff already has the milestone id in `$mid`
  (`milestone-review-handoff.sh:187`), so `cut --milestone "$mid"` needs no extra flag.
- Exit codes are real process exits, not subshell-local: `rsp_refuse()` (`review-stack-prepare.sh:146-150`)
  calls `exit "$code"` directly, and every resolver that can refuse is invoked as a plain
  statement (never wrapped in `"$(...)"`) specifically so that `exit` is not swallowed by a
  command-substitution subshell (comment at `review-stack-prepare.sh:152-155`). A caller can
  therefore capture `cut`'s combined output with `"$(... 2>&1)"` and read `$?` safely.
- On refusal, stderr carries exactly one line of the shape
  `REFUSED: review-stack-prepare.sh: <reason>: <message>` (`review-stack-prepare.sh:148`), where
  `<reason>` is one of the documented snake_case reason tokens (`review_base_undeclared`,
  `platform_gitlab_unsupported`, `task_unattributable`, etc. -- full table at
  `review-stack-prepare.sh:95-123`).
- `show --stack-id NAME` (no `--json`) prints, per manifest entry in order, to stdout:
  `PR N: branch=<b> base=<base> title=<t> body_path=<p>` then `  /please push <remote> <branch>`
  (`review-stack-prepare.sh:1073-1080`), then one trailing `/merge --stack <stack_id>`
  (`review-stack-prepare.sh:1081`); the "N entries need N grants" note goes to stderr only
  (`review-stack-prepare.sh:1082`). `show` itself refuses with exit 50 (`manifest_missing`) if
  `cut` was never run successfully for that stack id -- irrelevant on the success arm proposed
  below, since `show` is only called there after `cut` has already exited 0.

### Current handoff structure (both files in file_scope)

- `milestone-review-handoff.sh:242` opens `summary_path="specs/milestones/${mid}-review-handoff.md"`;
  the file is written unconditionally (lines 244-275), independent of `--dry-run` -- only the
  later `state-write.sh` call (lines 276-284) is gated by `dry_run`. The new cut/show call should
  follow this same precedent: run for real regardless of the handoff's own `--dry-run` flag,
  since `cut` has its own independent `--dry-run` (which would leave no manifest for `show` to
  read, an avoidable complication -- see Risks).
- The two hardcoded command lines appear twice: once inside the written `${summary_path}` file at
  `milestone-review-handoff.sh:272-273`, and once on stderr at `milestone-review-handoff.sh:294-295`.
  Both need to become conditional on the cut/show outcome.
- `${SCRIPT_DIR}/review-stack-prepare.sh` is the correct reference path, following the same
  co-located-script convention the file already uses for `STATE_WRITE="${SCRIPT_DIR}/state-write.sh"`
  (`milestone-review-handoff.sh:66`). The script exists on disk today at
  `agent-system/extensions/core/scripts/review-stack-prepare.sh` (1219 lines, executable).

### Test fixture precedent for a successful `cut` (reusable pattern, not in file_scope to edit but
safe to read)

`scripts/tests/test-review-stack-prepare.sh`'s `make_fixture_repo` (lines 49-75) establishes the
exact minimal fixture a successful `cut --milestone <id>` needs: a `file://` bare remote whose
path embeds `github.com/...` (so the substring-based platform detector resolves `github` without
a real network remote), and a `.claude-extensions.json` with `{"review_base": "basepoint"}` where
`basepoint` is a tag on an early commit distinct from the integration branch tip. This is directly
reusable inside `test-milestone-review-handoff.sh`'s own fixture builder: the existing "done"
fixture (`make_fixture_repo "yes"`, tasks 931/932 under milestone `M1`) already satisfies
`rsp_milestone_task_ids`'s read path (`review-stack-prepare.sh:293-299` reads
`.roadmap_milestones[] | select(.id == $mid) | .batches[].task_ids`, which is exactly the shape
already seeded at `test-milestone-review-handoff.sh:91`). Task 932 has no landing proof in that
fixture; `review-stack-prepare.sh`'s own fallback attribution (`rsp_fallback_attribution`,
`review-stack-prepare.sh:362-...`) uses the identical commit-subject-since-created convention
`task_review_line` already relies on, so `cut --milestone M1` against this fixture (once a
`review_base` tag and a `github.com`-shaped remote are added, and `review-stack-prepare.sh` plus
its `lib/` dependencies are installed into the sandbox) should succeed and produce two
independent single-task review units (931 and 932 do not share a path and no `dependencies` edge
exists between them in the fixture, so they form two separate connected components, each its own
chain of length one -- `show` will print two `PR N: ...` blocks).

### Test collision outside file_scope (see Executive Summary)

`scripts/tests/test-orchestrate-conclusion-roadmap.sh` Case H (`build_sandbox`, lines 94-134,
and the assertion at line 507: `grep -q "/please push ${caseH_branch}\$" ... && grep -q "^  /merge"`)
builds a sandbox that copies `milestone-review-handoff.sh` but never copies
`review-stack-prepare.sh`. Once the handoff shells out to a script that is absent there, the
correct behavior (treating "script not found" as equivalent to a refusal, printing `/please push`
alone and never `/merge`) will fail Case H's current assertion, which requires both. This is a
real, currently-passing test outside task 692's `file_scope` that the overall Phase 5 work will
break; it is not listed in the parent plan's own Phase 5 "Files to modify", which only names
`conclusion-stage.md` and `git-workflow-narrative.md` as doc updates. Recorded via
`issue-record.sh` (class `test_collision`) rather than fixed here.

## Decisions

- **Treat "script not found" identically to a cut refusal.** `${SCRIPT_DIR}/review-stack-prepare.sh`
  may legitimately be absent in a test sandbox or an older deploy that has not yet picked up the
  sibling script; the handoff must never hard-fail in that case (it is advisory/non-fatal by
  design, exit 0 always). Guard with `[ -x "$rsp_script" ]` before invoking, and fall straight
  into the same refusal-arm branch (with a synthetic reason line) when it is missing.
- **Do not thread the handoff's own `--dry-run` into `cut`.** `cut --dry-run` never writes a
  manifest, so a subsequent `show --stack-id` would refuse with `manifest_missing` (exit 50) even
  though `cut` itself "succeeded" (exit 0) in dry-run mode -- a success/failure mismatch between
  the two calls. The handoff's existing `--dry-run` flag already only gates the later
  `state-write.sh` call, not the summary-file write; running `cut`+`show` unconditionally (for
  real) keeps that same precedent and avoids inventing new dry-run semantics the phase description
  does not ask for. (No production caller passes `--dry-run` today --
  `orchestrate-conclusion-roadmap.sh:254` always calls with `--session SID` alone -- so this has
  no live-path consequence either way.)
- **Capture `cut`'s own stdout/stderr but never surface its `UNIT NN: ...` lines directly.** `cut`
  always prints `UNIT NN: tasks=... branch=... base=... end=...` lines to stdout before executing
  (`rsp_cut_print`, `review-stack-prepare.sh:831-842`), redundant with `show`'s later, more
  complete per-entry output. Capture the whole `cut` invocation only to recover its exit code and,
  on refusal, the one `REFUSED: ...` line (via `grep '^REFUSED:'`); do not print `cut`'s own
  stdout to the user.
- **The out-of-file_scope doc updates and test fix are each a separate record's responsibility,**
  not a reason to widen this task's own edits. Recorded as two `issue-record.sh` entries rather
  than actioned here.

## Recommendations

1. In `milestone-review-handoff.sh`, replace lines 266-275 (the `"## Next Step"` ... closing
   `} > "$summary_path"` block) so that everything through `"## Review Unit"`'s own closing
   content is still written with `>`, then compute the cut/show outcome, then append (`>>`) one
   of two blocks:
   - **Success** (`cut` exits 0): capture
     `show_output="$("${rsp_script}" show --stack-id "$mid" 2>/dev/null)"`; write a `## Review Stack`
     section containing `show_output` verbatim inside a fenced block, replacing today's
     `## Next Step` two-line block entirely.
   - **Refusal / script missing** (`cut` exits non-zero, or `[ ! -x "$rsp_script" ]`): keep a
     `## Next Step` section; print the captured `REFUSED: ...` line (or a synthetic
     "review-stack-prepare.sh not found" line when the script is absent); then
     `/please push ${integration_branch}` alone, with no `/merge` line.
   - On both arms, append one line naming the `HEAD`-binding fact (confirmed against
     `scripts/lib/push-grant-lib.sh`: a grant's `HEAD_SHA` is fixed at mint time
     (`pg_grant_write`/`pg_grant_mint`, lines 325-346, 594-606) and must equal current `HEAD` to be
     consumed (`pg_grant_find`-style match at line 464), so a commit in between invalidates it) --
     e.g. "A grant is bound to HEAD at the time it is typed; a commit by another session in
     between means typing the grant again."
2. Mirror the same three-way branch (success / refusal / missing-script) in the stderr block
   (today's lines 286-296), replacing the hardcoded `  /please push ${integration_branch}` /
   `  /merge` pair (lines 294-295) with the same success-arm `show_output` or refusal-arm
   `/please push` alone, plus the same `HEAD`-binding line.
3. In `test-milestone-review-handoff.sh`:
   - Extend `install_scripts` (lines 38-47) to also copy `review-stack-prepare.sh` into the
     sandbox (`cp "$SCRIPT_DIR/../review-stack-prepare.sh" "$d/.claude/scripts/review-stack-prepare.sh"`),
     since `lib/*` is already copied wholesale and covers its dependencies
     (`batch-admission-lib.sh`, `task-lookup-lib.sh`).
   - Add a new fixture builder (reusing `make_fixture_repo "yes"` as its base, following
     `test-review-stack-prepare.sh`'s `make_fixture_repo` pattern) that tags an early commit
     `basepoint`, declares `.claude-extensions.json` with `{"review_base": "basepoint"}`, and adds
     a `file://` remote whose path embeds `github.com/...`. Add a new case asserting: the written
     `${mid}-review-handoff.md` contains `PR 1: branch=...` / `PR 2: branch=...` lines (or however
     many connected components the two unlinked tasks produce), a `/please push` line per entry,
     one trailing `/merge --stack M1` line, and the `HEAD`-binding line; and that the old two-line
     `/please push ${BRANCH}` + bare `/merge` block is gone.
   - Rewrite Case 3 ("literal-command output", lines ~189-199) to assert the refusal-arm shape
     instead: since the suite's default fixtures declare no `review_base`, `cut` will refuse there
     (`review_base_undeclared`, exit 10) -- assert a `REFUSED: review-stack-prepare.sh:
     review_base_undeclared:` line, `/please push ${BRANCH}` present, and no bare `/merge` line
     anywhere in the output.
   - Keep Case 10's static push/ref-writing-call check (lines ~320-335) unchanged; the new calls
     to `review-stack-prepare.sh cut`/`show` do not contain any of the forbidden literal strings
     it greps for.
4. File a follow-up task (or amend the parent plan to add) for: `context/contracts/conclusion-stage.md`
   and `context/standards/git-workflow-narrative.md` prose updates describing the new printed
   behavior, the `index-entries.json` line-count reconciliation those doc edits require, and the
   `test-orchestrate-conclusion-roadmap.sh` Case H assertion fix -- none of which are in task 692's
   `file_scope`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `cut`'s own `UNIT NN: ...` stdout lines leak into the printed output if captured carelessly (e.g. `2>&1` merged into what gets shown to the user) | M | M | Capture `cut`'s combined output only for exit-code/refusal-reason extraction; only ever surface `show`'s dedicated stdout to the user/file. |
| A missing `review-stack-prepare.sh` (older deploy, or a sandbox that doesn't install it, as in `test-orchestrate-conclusion-roadmap.sh`) is treated as a hard error instead of advisory | H | M | Explicit `[ -x "$rsp_script" ]` guard before invoking; treat absence as the refusal arm with a named reason, never a script abort (the whole function must stay exit-0-always per its own contract). |
| Threading `--dry-run` into `cut` causes a spurious `show` refusal (`manifest_missing`) even though `cut` itself exited 0 | M | L (no caller uses `--dry-run` today) | Do not thread `--dry-run` through; run `cut`/`show` unconditionally regardless of the handoff's own dry-run flag (see Decisions). |
| `test-orchestrate-conclusion-roadmap.sh` Case H breaks once this phase lands, even though it is outside task 692's `file_scope` | M | H (certain, given the sandbox never installs `review-stack-prepare.sh`) | Out of scope for this record by design; filed as an issue and named explicitly in Recommendations item 4 so the next record/phase picks it up rather than discovering it as a surprise test failure. |
| The handoff's own `resolve_integration_branch` (lines 171-183) and `review-stack-prepare.sh`'s independent `rsp_resolve_integration_branch` could diverge on an edge case (two separately-implemented branch resolvers over similar but not identical inputs) | L | L | Not exercised by any fixture seen in this research; worth a note in the implementation's own verification step if the two ever disagree in practice, but not a blocker for this phase. |

## Context Extension Recommendations

None -- `context/standards/orchestrator-runtime-files.md` already documents the manifest/body-file
class (landed Phase 3), and no new undocumented pattern was discovered that isn't already covered
by this report's own Decisions/Recommendations.

## Appendix

Search queries / commands used:
- `grep -n "^### Phase" specs/685_.../plans/01_stack-pr-submission.md` to locate Phase 5's text.
- `grep -n "rsp_show_stack()\|rsp_refuse()\|rsp_milestone_task_ids()\|rsp_gather_selection()"` over
  `scripts/review-stack-prepare.sh` to read the exact `show`/refusal/selection mechanics.
- `grep -rn "milestone-review-handoff.sh" agent-system/extensions/core` to find every call site and
  test file touching the handoff's printed output.
- `grep -rln "please push\|^  /merge\|/merge --stack" scripts/tests/ context/` to find every test
  asserting on the handoff's literal command output, narrowing to the one real collision
  (`test-orchestrate-conclusion-roadmap.sh` Case H).
- Read `scripts/lib/push-grant-lib.sh` (`pg_grant_write`, `pg_grant_mint`, `HEAD_SHA` matching) to
  confirm the exact HEAD-binding mechanism before wording the new printed line.

References:
- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` (lines 58-66, 171-296)
- `agent-system/extensions/core/scripts/review-stack-prepare.sh` (lines 95-123, 146-160, 293-299,
  317-343, 1062-1083)
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` (lines 1-100,
  189-199)
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` (lines 39-100)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` (lines 60-134,
  484-531)
- `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`
  (lines 490-544)
