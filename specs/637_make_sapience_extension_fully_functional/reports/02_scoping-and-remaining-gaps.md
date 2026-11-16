# Research Report: Task #637

**Task**: 637 - Make sapience extension fully functional
**Started**: 2026-11-15T00:00:00Z
**Completed**: 2026-11-15T00:00:00Z
**Effort**: medium
**Dependencies**: None (recommended: add 635, 636, 628 — see Decisions)
**Sources/Inputs**: - Codebase (agent-system/extensions/sapience/**), specs/TODO.md (tasks 627,
  628, 635, 636), seed report 01, live machine state (~/.sapience/*.json, ~/.sapience/*.py,
  systemd user timers, update.log)
**Artifacts**: - specs/637_make_sapience_extension_fully_functional/reports/02_scoping-and-remaining-gaps.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Three of the seed report's four functional gaps (F4/tagged-write reliability, F7/grant-count
  residual, and the capture-coupling half of F6) are **already fully scoped** by existing open
  tasks 635, 636, and 628, each carrying a complete GOAL/MEASURED EVIDENCE/SCOPE/ACCEPTANCE
  write-up ready for planning. Re-deriving that work inside 637 would duplicate it and risk the
  two task directories drifting apart.
- The fourth gap (F5/prompt-time injection scoping) is **not a local defect at all**: it is a
  vendor-owned foreclosure, already measured, documented, and accepted in
  `context/project/sapience/domain/injection-site-scoping.md`, with an Owner Action (vendor
  message) already drafted. `verify-sapience-context-scoping.sh`'s own header states that a
  `RESIDUAL_HOLDS` result is the **expected, already-accepted green state today** — not a
  failure condition 637 can close from this repository.
- One genuine gap has no current owner: *why* transcript capture (`extracted.json`/
  `pending_kos.jsonl`) stopped advancing after Nov 13, distinct from task 636's scope (which
  covers coupling `capture.projects[].enabled` to extension activation, not the stall itself).
  Live-machine evidence below narrows this to a likely manual-invocation gap rather than a code
  defect in this extension's source store.
- **Recommendation**: set task 637's dependencies to 635, 636, and 628 (not "expand into" them,
  not "absorb" them); append one new goal item to task 636 covering the capture-stall diagnosis
  (same source files, same source-store target, no new task needed); and close out 637's own
  remaining scope as verification-after-dependencies plus accepting the F5 residual as already
  resolved to the extent this repository can resolve it.

## Context & Scope

This is the second research artifact for task 637. A seed report
(`reports/01_seed-audit-findings.md`) already performed a live audit across six loaded
repositories and recorded seven findings (F1-F7) and seven research questions (RQ1-RQ7), each
claim labeled measured/inferred/not-checked. This report does not re-run that audit. It instead:

1. Reads the source-store files the four sub-goals in 637's description actually depend on
   (`sapience-remember.sh`, `verify-sapience-mcp.sh`, `settings-fragment.json`,
   `sapience-mcp-register-project.sh`, and the `context/project/sapience/domain/*.md` corpus).
2. Reads the full descriptions of the four overlapping open tasks (627, 628, 635, 636) from
   `specs/TODO.md`, since 637's own description explicitly defers the absorb/depend/expand
   decision to research.
3. Probes live machine state (`~/.sapience/config.json`, `update.log`, `cc-outbox`,
   `extracted.json` et al. mtimes, systemd user timers) to answer RQ5 (why capture stalled),
   which seed report F6 left open and no existing task's GOAL section actually covers.

Out of scope, per the task description: repairing the half-deployed `abood` repository.

## Findings

### Codebase Patterns

**F4 (tagged-write reliability) is task 635's exact scope.** 635's GOAL item (1) — anchor the
postflight write mechanically (e.g. a `sapience_notes` array in return metadata, consumed by a
completion-postflight script calling `sapience-remember.sh` once per note) — is the only
structural fix available: `context/project/sapience/domain/per-repo-scoping.md`'s "No Lifecycle
Hook" section already proves a manifest `hooks.postflight` entry can never fire for this
extension (it is typeless; `skill_get_extension_dir()`'s `[ -n "$ext_task_type" ]` test fails
unconditionally). 635's MEASURED EVIDENCE (a two-task `/orchestrate` run with zero
`sapience-remember.sh` invocations across 12 subagent transcripts) is a direct, independent
confirmation of seed-report F4's inferred cause.

**F7 (grant-count residual) is task 628's exact scope.** Reading `settings-fragment.json`
confirms it already grants exactly the 7 read-shaped tools and no write tools (lines 3-11); the
11-vs-7 residual in every healthy deployed repository is exactly what 628's MEASURED EVIDENCE
describes, and 628's SCOPE section already poses the two candidate fixes (teach the merge engine
retraction, coordinated with task 527's identical problem; or a one-time migration pass plus a
new verify-deploy.sh gate) and defers the choice to that task's own plan phase. Nothing here
changes that framing.

**F6's coupling half is task 636's GOAL item (2) exactly; its stall half is not covered by any
open task.** 636(b) states the measured fact (capture enabled for `.dotfiles`/`nvim`/`abood`/
`sapience-app`, disabled/absent for `BimodalLogic`/`sf1-engine` despite both having the extension
active) and its GOAL item (2) commits to a verifier check plus a coupling ruling. That closes the
"opt-in list disagrees with loaded repos" half of 637's goal 3. It does **not** address why
`extracted.json`/`pending_kos.jsonl`/`extract_yield.json` stopped advancing at all on Nov 13 —
636's own measured evidence (a) and (d) are about machine-wide hooks and the context-scoping
probe's reliability, not the extraction pipeline's liveness.

Live-machine evidence on the stall, gathered directly from `~/.sapience/`:

- `extracted.json`, `pending_kos.jsonl`, and `extract_yield.json` share the **identical** mtime
  (`1794600412` = 2026-11-13 12:06:52 PST) — all three were last written by one single
  invocation of whatever produces them, not three independent processes drifting apart.
- The vendor self-updater ran again the same day at 18:07 (`update.log`: "4 files updated" —
  `extract_local.py`, `sapience_capture.py`, `mcp.py`, `sapience_cli.py`) and twice more on
  Nov 14 ("auto-update: current", no files changed) — so the **code** self-update mechanism is
  still running; only the **content**-producing pipeline is stalled, and the stall's start
  predates the same-day code update by six hours, so the update is not obviously the trigger.
- `sapience_cli.py`'s live, per-turn transcript-capture path (`cc_capture`/`cc_flush`/
  `cc_outbox()`, lines 578-742) is a **separate** mechanism from the `extracted.json` population:
  it posts redacted per-turn summaries to `POST /v1/cc/turn` from a `~/.sapience/cc-outbox/`
  queue, gated on a server-driven `cc_sessions` flag in `cli-state.json`. That directory **does
  not exist** on this machine (`ls`: No such file or directory), consistent with this channel
  never having fired, but it is not the channel that populates `extracted.json`.
- No systemd user timer and no crontab exist for any sapience process (`systemctl --user
  list-timers --all` lists seven unrelated timers; `crontab -l` fails with "command not found").
  The only two scheduling mechanisms visible from this machine are the daily self-update check
  (confirmed still running) and whatever manually-invoked CLI verb produces `extracted.json`
  (`sapience sync`/`review`/`coverage`, per `review-gate-boundary.md`'s own naming) — and nothing
  on this machine re-invokes that verb automatically.

**Inference, not confirmed**: the stall is most consistent with a manual-invocation gap (nobody
has re-run the extraction verb since Nov 13), not a code regression in this repository's
extension or in the vendor client. This repository's extension source store declares no script
that drives `extracted.json` population at all — `sapience-retrieve.sh`/`sapience-remember.sh`
are the only two scripts this extension owns, and neither touches that pipeline.

**F5 (prompt-time injection scoping) is already closed out to the extent this repository can
close it.** `verify-sapience-context-scoping.sh`'s own header (lines 8-13) states plainly: *"A
'residual holds' result (project still ignored) is the EXPECTED, green state today ... that is
not a failure of this probe, it is confirmation of the measured gap."*
`injection-site-scoping.md`'s "The Ruling" section independently establishes that neither
candidate remedy (suppress the hooks, or label by source) is reachable from this repository:
suppression is rejected because it would cost the cross-corpus abstraction value the channel
exists for, and labeling is foreclosed because the endpoint's response carries no per-item
attribution to key a label on (Foreclosure 2). The file already carries a fully drafted Owner
Action (vendor message) as the only remaining lever. 637's description phrasing ("probe returns
RESIDUAL_HOLDS" as a condition to fix) reads as if this were an open code defect; it is not — see
the issue logged against this ambiguity.

### External Resources

Not applicable — this is a closed-corpus, codebase-internal and live-machine-state research task;
no external documentation beyond the vendor's own files (`~/.sapience/*.py`), which are
self-updating and out of this repository's edit authority.

## Recommendations

1. **Set task 637's dependencies to 635, 636, 628** rather than absorbing or expanding into them.
   "Expand into" does not fit mechanically: `state-management.md`'s `[EXPANDED]` transition is
   for dividing a task into subtasks that do not yet exist; 635/636/628 already exist as
   independently-created, already-detailed tasks. "Absorb" would mean discarding their
   already-complete GOAL/SCOPE/ACCEPTANCE write-ups and re-deriving the same analysis inside
   637's own artifacts, for no benefit and a real risk of the two trees drifting apart. "Depend"
   keeps each fix in the task that already owns its detailed design, and lets 637 serve its
   actual remaining purpose: confirming the four goals as a whole once its dependencies land, and
   owning the one gap (capture-stall diagnosis) none of them currently covers.
2. **Do not add a dependency edge on 627.** 627 (orphan MCP-registration reaper) is adjacent to
   F1, which 637's own description places out of scope (the `abood` repair). None of 637's four
   stated goals requires 627's reaper; treat it as a co-batch/ordering note only, per
   `batch-orchestration-guardrails.md`'s guidance against converting adjacency into a dependency
   edge.
3. **Append a capture-stall diagnosis item to task 636's GOAL section**, rather than filing a new
   task or folding it into 637 directly. 636 is still `[NOT STARTED]`, already touches the same
   source files (`per-repo-scoping.md`'s population-3 text, the capture-coupling verifier check),
   and is the task whose edit target already spans the capture-enablement surface. The new item
   should ask 636's plan phase to: (a) determine which CLI verb populates `extracted.json`/
   `pending_kos.jsonl` and confirm whether it is invoked only manually on this machine; (b) if
   so, record that "restoring" the stall is an operational action (re-run the verb) rather than a
   code defect, and decide whether recurring automation belongs in `~/.dotfiles` (this
   extension's own established pattern for machine-level, nix-side defaults — see 636's own
   description, "a companion task is filed in ~/.dotfiles for the nix-side default") rather than
   in this source store; (c) update `per-repo-scoping.md`'s population-3 text accordingly once
   the mechanism is confirmed, rather than inferred.
4. **Treat 637's goal 2 (F5) as already satisfied by existing documentation and verification**,
   not as an open code-change item. The remaining action (sending the drafted Owner Action
   message to the vendor) is a communication step outside this repository's filesystem, not a
   plan/implement deliverable. If the task's acceptance bar is read literally as "the probe
   returns something other than RESIDUAL_HOLDS," that bar cannot be met from this repository at
   all today; recommend rephrasing 637's own description to "confirmed as the accepted,
   documented residual; no further local action available" rather than carrying a goal this
   repository has no mechanism to close.
5. Once 635, 636, and 628 complete, 637's own remaining closing step is a verification pass: run
   `verify-sapience-mcp.sh` in each of the five healthy repositories (confirming check (e) now
   passes), confirm a newly-completed task in each repository produces a tagged note, and confirm
   636's new capture-coupling check reports agreement. This is a thin final phase, not a parallel
   re-implementation of 635/636/628's own work.

## Decisions

- **637 depends on 635, 636, and 628**; it does not absorb or expand into them. (Recommendation
  1-2 above.)
- **F5 requires no further local code change.** The vendor-owned foreclosure and its Owner Action
  are already fully documented; 637's own acceptance language referring to `RESIDUAL_HOLDS` as a
  defect to eliminate is treated as a description-level ambiguity (logged as an issue, class
  "design-record defect or ambiguity", severity minor), not as live scope.
- **The capture-stall diagnosis is new scope with no current owner**, and is sited as an addition
  to task 636 rather than a new task or as direct 637 scope, because 636 already owns the
  adjacent capture-coupling surface and the same source files.

## Risks & Mitigations

- **Risk**: wiring 637 to depend on 635/636/628 without also appending the capture-stall item to
  636 would leave that one gap permanently unowned. **Mitigation**: the append is a small,
  low-risk addition to an already-`[NOT STARTED]` task's description, not a structural change;
  it should happen before 636 enters planning.
- **Risk**: a future reader could mistake the live-machine evidence above (mtimes, absence of
  `cc-outbox/`, no systemd timer) as proof the stall is a vendor code regression rather than an
  operational gap. **Mitigation**: this report labels that reading as *inferred, not confirmed*,
  and recommends 636's plan phase determine the actual triggering verb before concluding either
  way.
- **Risk**: 628's and 635's own plans may independently touch `EXTENSION.md`/
  `per-repo-scoping.md` in overlapping ways once dispatched. **Mitigation**: both tasks already
  name their own file territory precisely in their existing descriptions; this is a normal
  co-batch/sequencing concern for the plan phase, not a new finding this report needs to resolve.

## Context Extension Recommendations

- **Topic**: capture-pipeline triggering mechanism (which CLI verb populates `extracted.json`/
  `pending_kos.jsonl`, and whether it is manual-only on this machine).
- **Gap**: `context/project/sapience/domain/per-repo-scoping.md`'s population-3 census describes
  *what* the transcript-extraction path is (`~/.sapience/upload.py`) but not *when* or *how
  often* it runs; no context file states whether it is scheduled or manual-only.
- **Recommendation**: once task 636's plan phase confirms the triggering mechanism (see
  Recommendation 3 above), add a short subsection to `per-repo-scoping.md` or a new
  `domain/capture-scheduling.md` stating it explicitly, so a future stall is diagnosed from
  documentation rather than re-measured from machine state as this report had to do.

## Appendix

### Search Queries / Commands Used

- `jq` reads of `.claude-extensions.json`, `settings-fragment.json`, `manifest.json`
- `Read` of `sapience-remember.sh`, `verify-sapience-mcp.sh`, `sapience-mcp-register-project.sh`,
  `per-repo-scoping.md`, `EXTENSION.md`, `review-gate-boundary.md`, `injection-site-scoping.md`,
  `verify-sapience-context-scoping.sh` (header)
- `grep -n "^### 627\|^### 628\|^### 635\|^### 636"` and a direct `Read` of `specs/TODO.md`
  lines 187-400 for the four overlapping tasks' full descriptions
- `ls -la ~/.sapience/`, `cat ~/.sapience/config.json | jq 'del(.token)'`, `tail -40
  ~/.sapience/update.log`, `crontab -l`, `systemctl --user list-timers --all`
- `stat -c '%Y %n' ~/.sapience/extracted.json ~/.sapience/pending_kos.jsonl
  ~/.sapience/extract_yield.json`
- `grep -n "^def \|^class "` over `~/.sapience/sapience_cli.py` and `sapience_capture.py`, and a
  targeted `Read` of `sapience_cli.py` lines 571-750 (`cc_capture`/`cc_flush`/`cc_outbox`)

### References

- `specs/637_make_sapience_extension_fully_functional/reports/01_seed-audit-findings.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
- `agent-system/extensions/sapience/context/project/sapience/domain/review-gate-boundary.md`
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh`
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
- `agent-system/extensions/sapience/EXTENSION.md`
- `specs/TODO.md` (tasks 627, 628, 635, 636)
