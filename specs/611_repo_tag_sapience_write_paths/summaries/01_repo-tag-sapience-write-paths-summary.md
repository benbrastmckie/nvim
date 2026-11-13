# Implementation Summary: Task #611

- **Task**: 611 - Repo-tag every Sapience write path the source store owns so untagged knowledge objects stop being created
- **Status**: [COMPLETED]
- **Started**: 2026-11-13T00:00:00Z
- **Completed**: 2026-11-13T02:51:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_repo-tag-sapience-write-paths.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The tagged write path (`scripts/sapience-remember.sh`, called from `EXTENSION.md`'s postflight
wrapup) already existed and worked before this task began. What was missing was everything that
makes that contract durable and checkable: two domain docs still described the superseded
untagged MCP-tool mechanism as current, two of the four MCP write tools carried no recorded
disposition, the vendor SessionStart nudge was countered only by inference, the standing rule
existed only as one prose sentence with no registered carrier, and the tagged provenance had
zero test coverage. This implementation closed all five gaps across four phases, ending with a
redeploy and a scoped verification pass.

## What Changed

- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md` -- corrected two stale passages that described the superseded `sapience_wrapup` call site as current; added a new `## Write-Tool Disposition` section recording an affirmative disposition for all four MCP write tools.
- `agent-system/extensions/sapience/context/project/sapience/domain/transcript-filter-ceiling.md` -- corrected the Conclusion's claim that an MCP tool call is the *only* path into the vault for orchestrated work; the surviving path is the direct script call, not an MCP tool call.
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` -- replaced the stale two-population Hazards claim with the measured four-population census (tagged; untagged-agent-reachable; untagged-vendor-owned; belongs-to-no-repository), stating for each whether it stays untagged and why.
- `agent-system/extensions/sapience/index-entries.json` -- repaired three line counts moved by the domain-doc edits, and updated two prose summaries to match the new content.
- `agent-system/extensions/sapience/EXTENSION.md` -- added an explicit counter-instruction naming and superseding the vendor SessionStart nudge, redirecting the finding to the bounded tagged path rather than merely suppressing it; stated the ruling's class (counter-instruction, not owner action, not accepted residual). File stays at 53 lines, within Rule U's 60-line ceiling.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` -- added a `build_scratch_remember` write-side fixture, a `run_remember` helper, and three new cases (10-12) asserting `[repo:<slug>]` in provenance, exact token redaction with no leak, and unconditional `explicit: true`, all driven with no `curl` stub since `--dry-run` never reaches the network. Widened the header comment to cover both scripts. Each new case was confirmed to fail for the right reason when its asserted property was broken in a disposable scratch copy.
- `agent-system/extensions/sapience/rules/sapience-write-path.md` -- new file: the standing, advisory rule stating the write-path contract, the discussing-vs-prescribing boundary with sanctioned sites named, the rejected-mechanization rationale and promotion criterion, and the accepted `settings-fragment.json` grant residual with its named escape valve.
- `agent-system/extensions/sapience/manifest.json` -- registered the new rule in `provides.rules`, in the same commit as its creation (Rule H).
- Deployed tree -- regenerated via `deploy-headless.sh` (gitignored, not tracked by git).

## Decisions

- Kept `settings-fragment.json`'s four-tool MCP grant intact per the prior-cycle `user_decision` answer, recording the residual and its promotion criterion in the new rule file rather than narrowing the grant (which would have left `core/context/patterns/mcp-server-ownership.md`'s worked example stale, and `core/` is outside this task's edit target).
- The SessionStart nudge is countered by a redirect, not a bare suppression: the counter-instruction in `EXTENSION.md` explicitly states the finding is held and surfaces through the bounded postflight pass, so nothing is lost.
- The standing rule (deliverable b) is advisory, not mechanized: the governed corpus is small (14 source-store files, 3 of which legitimately discuss the tools) and the only trusted mechanized shape for this false-positive class (marker suppression) is disproportionate for a corpus this size. A promotion criterion is named in the rule's own text.
- Phase 4's declared full-tier verification (`verify-deploy.sh`, unnarrowed) was discharged against the scoped `--only-gate 3,13` invocation per this dispatch's Batch Gate Deferral directive, because an unnarrowed run surfaced two pre-existing failures unrelated to this task (gate10 `validate-state.sh --deep` timeout; gate20 `skill-orchestrate/SKILL.md` budget ceiling), neither in this task's declared `file_scope`. The scoped gates (doc-lint, whole-tree orphan detection) cover everything this task actually touched and exit 0.

## Plan Deviations

- **Phase 4 verification** altered: the full, unnarrowed `verify-deploy.sh` criterion was discharged via `--skip-slow --only-gate 3,13` instead, per the dispatch's Batch Gate Deferral directive. See `progress/phase-4-progress.json`'s `deviations` array and the Phase 4 handoff for the full record. The full gate set still runs once for the whole `/orchestrate` batch invocation.

## Verification

- Build: N/A (markdown/shell, no build step)
- Tests: Passed -- `test-sapience-capture.sh` (35 assertions, 9 pre-existing read-side cases plus 3 new write-side cases) exits 0 both from the source store and from the deployed tree after redeploy. Each new case confirmed to fail correctly under inversion in a disposable scratch copy.
- Files verified: Yes -- `generate-context-line-counts.sh --check` exits 0; deployed `rules/sapience-write-path.md` is byte-identical to its source; `jq -r '.provides.rules[]'` lists the new rule; end-to-end `sapience-remember.sh --dry-run` (deployed) exits 0 with `[repo:nvim]`, `***REDACTED***`, and `explicit: true`.
- Scoped gate: `verify-deploy.sh --skip-slow --only-gate 3,13` exits 0 (doc-lint, whole-tree orphan detection). Full unnarrowed gate set deferred to the batch-level invocation per the dispatch's Batch Gate Deferral directive.

## Impacts

- Every instruction surface under `agent-system/extensions/sapience/**` now names only `scripts/sapience-remember.sh` as the prescribed write path; no surface prescribes an MCP write tool.
- Unreviewed write volume per completed task is unchanged (3-8 notes, postflight-only); no new call site was added and the two ruled-out tools (`sapience_handoff`, `sapience_adddoc`) gain none.
- A future untagged-write regression is now test-covered: breaking the provenance tag, the token redaction, or `explicit: true` in `sapience-remember.sh` fails the corresponding new test case.
- The sibling read-side task (owning no-read-side filter at the vendor hooks) can now proceed, since the writes it will filter are tagged.

## Follow-ups

- The `settings-fragment.json` four-tool grant residual remains: a stray proactive MCP call can still land a permanent, undeletable, untagged write. The named escape valve (a follow-up task narrowing the grant together with the `core/` worked-example update) is recorded in `rules/sapience-write-path.md` but not filed as a task here, since the prior-cycle `user_decision` chose to keep the grant intact for this task's scope.
- Gate10 (`validate-state.sh --deep` timeout) and gate20 (`skill-orchestrate/SKILL.md` budget ceiling over 25000B) were observed as unrelated pre-existing/concurrent-task failures during this task's redeploy verification; neither is in this task's `file_scope` and neither was addressed here.

## References

- Plan: `specs/611_repo_tag_sapience_write_paths/plans/01_repo-tag-sapience-write-paths.md`
- Research report: `specs/611_repo_tag_sapience_write_paths/reports/01_repo-tag-sapience-write-paths.md`
- Progress files: `specs/611_repo_tag_sapience_write_paths/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/611_repo_tag_sapience_write_paths/handoffs/phase-{1,2,3,4}-handoff-*.md`
