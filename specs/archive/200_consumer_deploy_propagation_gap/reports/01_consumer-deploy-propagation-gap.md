# Research Report: Task #200

**Task**: 200 - Close the consumer-repo deploy propagation gap that leaves fixed defects live in deployed trees
**Started**: 2026-09-17
**Completed**: 2026-09-17
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/**), git history (nvim + BimodalLogic repos), live measurement in ~/Projects/BimodalLogic
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- A pull-side, per-extension freshness detector (**tier 1**: `check-deploy-freshness.sh` +
  `scripts/lib/deploy-freshness-lib.sh`, backed by a `source_git_head` stamp `state.lua`'s
  `mark_loaded` already writes into `.claude-extensions.json` at every load) already exists and
  is already wired non-blockingly into `command-gate-in.sh`'s CHECKPOINT 1 — it is **not** true
  that "the only detector is opt-in and report-only" as the dispatch states; that description
  fits only **tier 3** (`check-consumer-freshness.sh`, gated behind `--consumer-report`).
- The reason the live incident still happened is a **granularity gap**, not a missing detector:
  tier 1 fires once per top-level command (`/research`, `/plan`, `/implement`, `/orchestrate`),
  printed to the top-level session's own stderr. An `/orchestrate` run spawns many
  agent/skill dispatches over its lifetime (one Task-tool call per phase/wave), and none of
  those individual dispatches — including the one that reads the stale
  `lean-implementation-agent.md` — ever sees the check re-run or its warning. The signal exists
  but never reaches the context that acts on the stale file.
- The per-extension comparison granularity (path-scoped `git log -1 -- <source_dir>` over the
  **whole extension directory**) already satisfies the "partial staleness within one tree must
  be caught" requirement — a single stale file under `agent-system/extensions/lean/` changes the
  recomputed head for the whole `lean` extension, exactly reproducing the fixture shape
  (`git-snapshot.sh` unchanged, `lean-implementation-agent.md` changed, one extension entry
  still reports STALE). No new fingerprint/hash mechanism is needed — reuse
  `deploy_freshness_status`/`deploy_freshness_stale_names` as-is.
- Measured cost: `check-deploy-freshness.sh` runs in **~130ms** against BimodalLogic's 7 deployed
  extensions (`time` measurement below) — negligible next to the ~10-minute, ~50-repo tier-3 walk
  task 180 correctly pulled off the blocking gate. Running the same per-repo, per-extension check
  at every skill dispatch (not just once per top-level command) does not reintroduce that
  regression: it is still one repo checking only itself, and the cost scales with this repo's own
  extension count (7), never with the size of the consumer fleet (8 registered consumers).
- **Recommendation**: adopt option (a) as primary, at a finer grain than the dispatch's own
  suggested location — call it directly from `skill_preflight_update` in
  `core/scripts/skill-base.sh` (confirmed to run once per skill/phase dispatch, i.e. once per
  Task-tool agent spawn, not once per top-level command) — combined with a scoped slice of (c):
  surface a `STALE`/`CANNOTVERIFY` result directly inside the dispatch file/brief the spawned
  agent itself reads (the same injection mechanism `orchestrate-build-dispatch.sh` already uses
  for `<memory-context>`), rather than only printing to the orchestrator's own stderr. Warn
  loudly by default; do not hard-block dispatch (see Risks & Mitigations for why).
- BimodalLogic's four cited call sites are **already identical to source as of today**
  (confirmed by direct `diff`, all four empty) — a redeploy happened there between 2026-09-09 and
  2026-09-16, independent of this task. The acceptance criterion's final verification step is
  effectively already satisfied; it should still be re-confirmed after implementation lands, but
  no drift-fixing redeploy remains to perform.

## Context & Scope

Researched the propagation-gap defect described in the dispatch: a source-store fix (task 176,
landed 2026-09-08) that stayed live/broken in a consumer repo's deployed tree
(`~/Projects/BimodalLogic`) a day later. The dispatch frames three candidate remedies —
(a) pull-side check, (b) whole-tree fingerprint, (c) actionable signal — and asks for a weighed
recommendation, a cost measurement, and a `shellcheck`-clean implementation, without reverting
task 180's opt-in tier-3 walk. This report covers detection/signalling design only; it does not
implement changes (that is the plan/implement phase's job) and does not re-fix the lean docs
(already correct at source, confirmed below).

## Findings

### Codebase Patterns

**Three-tier design already exists** (`agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`,
"Detecting When You're Stale" section):
- **Write side**: `state.lua`'s `mark_loaded` (the sole writer of `.claude-extensions.json`
  entries, called from `init.lua`'s `manager.load`) stamps `source_git_head` per extension on
  every load — the path-scoped revision (`git -C <source_dir> rev-parse --show-toplevel`, then
  `git log -1 --format=%H -- <source_dir>` against that toplevel), deliberately never the whole
  source repo's `HEAD` (so unrelated churn elsewhere doesn't false-positive an untouched
  extension).
- **Tier 1** (`agent-system/extensions/core/scripts/check-deploy-freshness.sh`): standalone,
  always-`exit 0`, non-blocking. Recomputes the same path-scoped revision per extension via the
  shared library and WARNs to stderr on mismatch. Invoked from `command-gate-in.sh`'s `gate_in`
  (CHECKPOINT 1, `agent-system/extensions/core/scripts/command-gate-in.sh:119-120`) with
  `bash .claude/scripts/check-deploy-freshness.sh 2>&1 || true`. Also has a **consecutive-ignore
  escalation**: a streak counter at `specs/.freshness-warn-streak.json` prints an extra banner
  once a WARN has fired on 5+ consecutive invocations — an existing precedent for "make an
  ignored non-blocking warning louder over time" that a future fix can reuse or extend.
- **Tier 2**: `update-task-status.sh`'s postflight backstop (blocking, per the shared library's
  header comment) — not examined in depth here since it is postflight, after the stale file was
  already read and acted on.
- **Tier 3** (`check-consumer-freshness.sh`): opt-in fleet-wide report, invoked from
  `deploy-headless.sh` only behind `--consumer-report`. This is the one genuinely "opt-in and
  report-only" detector; walks the registry at `context/reference/known-consumer-repos.json`
  (currently 8 registered consumers: `.dotfiles`, BimodalLogic, ModelChecker, PersonalWebsite,
  cslib, Logos/Theory, Logos/Hardware, PossibleWorlds paper).
- **Shared algorithm**: both tier 1 and tier 3 funnel through
  `scripts/lib/deploy-freshness-lib.sh`'s `_deploy_freshness_status_one` — one home for the
  comparison, exporting `deploy_freshness_stale_names` (tier 1's silent-unless-stale list) and
  `deploy_freshness_status` (three-way `STALE`/`FRESH`/`CANNOTVERIFY`, used by tier 3 and the
  blocking tier-2 backstop). No second algorithm needs to be invented for a tier-1-adjacent
  addition — this library is already the right unit to call.

**Where tier 1 actually fires vs. where the defect actually bites.** `command-gate-in.sh` is
sourced once per top-level command invocation (`/research N`, `/plan N`, `/implement N`,
`/revise N`, `/orchestrate N`) per its own docstring and the single `gate_in "$1" "$2"` call at
file end. Its CHECKPOINT-1 freshness check therefore runs **once**, at the very start of that
command. `skill-base.sh`'s `skill_preflight_update` (line 292), by contrast, runs once per
**skill dispatch** — i.e., once per phase/agent spawn within a long `/orchestrate` run (the
research skill, the plan skill, and each implementation skill/phase dispatch each call it
independently). A `lean-implementation-agent` Task-tool spawn reads its own deployed instruction
file directly; it never re-crosses `command-gate-in.sh`, and by the time it runs, the one WARN
line tier 1 printed (if it printed one at all — see below) is minutes-to-hours stale in the
orchestrating session's own transcript, not in the spawned subagent's context at all. This is
the concrete mechanism behind "detector exists, incident still happened": the gap is not
detection, it's **where the detection's output lands relative to where the stale file is read**.

**Dispatch-time context injection precedent.** `orchestrate-build-dispatch.sh` (confirmed to be
the script that builds files like this task's own `.dispatch/5.md`) already injects several
context blocks into the dispatch brief an agent reads before acting — `<memory-context>`, the
literature briefing, the hard-mode contract block, the effort block (grep for these markers at
lines documented in the script's own header comment). A `<deploy-freshness-context>`-shaped
block, built the same way from the consuming repo's own `.claude-extensions.json` via the
existing `deploy_freshness_stale_names` function, is a small, precedented addition rather than a
new injection mechanism.

### External Resources

Not applicable — this is a closed-repo mechanism question; no external documentation consulted.

### Live Verification (forensic reconstruction of the observed incident)

- Task 176's actual fix commit (path-scoped to the lean extension) is `5cccf8524`,
  2026-09-08 15:36:51 -0700 ("task 176 phase 1: correct the full-build caller sites"). The
  preceding path-scoped commit is `da686c915`, 2026-09-07 19:23:40 -0700.
- BimodalLogic's `.claude-extensions.json` (tracked in its own git history even though
  `.claude/` itself is gitignored there) shows a commit `e3a2c0f1a`, 2026-09-09 09:24:14 -0700,
  "sync: refresh .claude-extensions.json merge metadata", recording
  `source_git_head=da686c915...` for the `lean` extension — confirmed via `git merge-base
  --is-ancestor` to be **one commit behind** the actual fix, despite this sync happening roughly
  18 hours after the fix landed. This means even the redeploy/sync that *did* run around the
  time of the incident captured a state one step stale — evidence that manual/periodic
  redeploys are fragile even when they do happen close in time to a fix, reinforcing that a
  live, at-use-time check (option a) is more robust than relying on redeploy diligence alone.
- As of today (2026-09-17), BimodalLogic's `.claude-extensions.json` records
  `source_git_head=dcb7bf6c7...` for `lean`, which **matches** current source (`git log -1
  --format=%H -- agent-system/extensions/lean` in this repo returns the identical hash), and a
  direct `diff` of all four cited call sites (`lean-implementation-agent.md`,
  `lean-implementation-hard-agent.md`, `rules/lean4.md`, `skills/skill-lake-repair/SKILL.md`)
  against source is empty for all four. A redeploy already happened there since the incident,
  independent of this task — the acceptance criterion's final verification step is effectively
  already satisfied, though it should be re-confirmed once the chosen fix lands (the redeploy
  that fixed it predates the fix being validated by this task).
- Cost measurement: `time (bash .claude/scripts/check-deploy-freshness.sh . >/dev/null 2>&1)` in
  BimodalLogic (7 deployed extensions: core, filetypes, formal, lean, literature, memory, typst)
  → **real 0m0.133s**. This is the same script/library a `skill_preflight_update`-level call
  would reuse; cost scales with *this repo's own* extension count, not the size of the consumer
  fleet, so moving it from once-per-command to once-per-skill-dispatch multiplies a ~130ms cost
  by the number of dispatches in a session, not by 50 repos — categorically different from the
  tier-3 walk task 180 removed from the blocking path.

### Recommendations

1. **Primary (option a, refined location)**: call
   `deploy_freshness_stale_names`/`deploy_freshness_status` from `skill_preflight_update` in
   `core/scripts/skill-base.sh`, not only from `command-gate-in.sh`. This fires at the actual
   per-dispatch granularity where a stale file would be read, at the same ~130ms-class cost
   already measured for tier 1, with zero new comparison algorithm.
2. **Skip option (b)** as a *new* mechanism: the existing per-extension `source_git_head`
   comparison already operates at extension-directory granularity, which already catches a
   single stale file within an otherwise-fresh extension (confirmed by the `git-snapshot.sh`
   fresh / `lean-implementation-agent.md` stale contrast cited in the dispatch — both live under
   `core` and `lean` respectively, two *different* extensions, but the same reasoning applies
   within one extension: any one file's change moves the whole directory's path-scoped head).
   Building a second, redundant whole-tree/whole-extension fingerprint would duplicate work the
   library already does.
3. **Scoped slice of option (c)**: do not hard-block dispatch by default (see Risks below).
   Instead, make the *already-detected* signal reach the *already-spawned* agent by injecting a
   short, explicit warning block into the dispatch file/brief itself when
   `deploy_freshness_stale_names` for the task's own `task_type`-relevant extension(s) is
   non-empty — following the `orchestrate-build-dispatch.sh` precedent used for memory-context
   and literature-briefing injection. This directly closes the observed failure mode: the agent
   that would otherwise blindly follow a stale instruction file now sees, in its own context,
   "this deployed tree may be stale for extension X — verify before relying on documented
   commands from X."
4. Reuse the existing consecutive-streak escalation pattern (`specs/.freshness-warn-streak.json`)
   as a model if a louder default is wanted later; do not invent a second streak mechanism.

## Decisions

- Treat the dispatch's claim "the only detector is opt-in and report-only" as accurate for tier 3
  only; tier 1 is neither opt-in nor pure report-only-in-isolation (it does emit unconditionally)
  but it *is* effectively inert because of granularity, not opt-in-ness. The plan/implement phase
  should correct this framing rather than build on the premise that no pull-side check exists.
- Do not propose a new fingerprint/hash scheme (option b) as a standalone deliverable; the
  existing per-extension `source_git_head` mechanism already meets the partial-staleness
  detection bar the acceptance criterion asks for.
- Recommend warn-in-dispatch-brief over hard-block-dispatch as the default action (option c),
  reserving hard-block as a documented, deliberately-rejected-for-now alternative.

## Risks & Mitigations

- **Risk**: relocating the check into `skill_preflight_update` multiplies its invocation count
  across a session (once per skill dispatch instead of once per command). **Mitigation**:
  measured at ~130ms per invocation against this repo's own extension count (not the fleet); a
  multi-phase `/orchestrate` run pays this a handful of times, not 50x. Explicitly measure this
  again in the plan/implement phase against a realistic multi-dispatch session, per the
  acceptance criterion's "wall-clock cost is measured" requirement.
- **Risk**: hard-blocking dispatch on `STALE` could itself regress into the blocking-gate problem
  task 180 removed, and `CANNOTVERIFY` (missing jq/git, non-git source_dir, etc.) must never be
  conflated with `STALE` if any blocking behavior is ever added — the shared library already
  keeps these as distinct return values; any blocking logic must preserve that distinction.
  **Mitigation**: recommend warn-only-in-dispatch-brief as the default; do not implement a hard
  block in this task without a separate, explicit decision.
- **Risk**: the dispatch file injection point (`orchestrate-build-dispatch.sh`) only covers
  orchestrator-mode dispatches; a directly-invoked `/implement N` (non-orchestrate) skill run
  would still rely on `skill_preflight_update`'s own stderr output. **Mitigation**: the
  `skill_preflight_update` call is the base layer that covers both paths; the dispatch-brief
  injection is an orchestrate-mode enhancement on top, not a replacement.

## Context Extension Recommendations

- **Topic**: `regeneration-is-manual-only.md`'s "Detecting When You're Stale" section documents
  tiers 1–3 but does not document a per-skill-dispatch tier or the dispatch-brief injection
  pattern once implemented.
- **Gap**: no existing context file describes `orchestrate-build-dispatch.sh`'s
  context-injection points as a reusable pattern for future "surface X into the agent's own
  context" needs.
- **Recommendation**: once implemented, add a short subsection to
  `regeneration-is-manual-only.md` documenting the new per-dispatch check, and consider whether
  `orchestrate-build-dispatch.sh`'s injection points deserve their own pattern doc under
  `context/patterns/` for reuse beyond this task.

## Appendix

- Commands used: `git log`/`git show`/`git merge-base --is-ancestor` in both
  `/home/benjamin/.config/nvim` and `/home/benjamin/Projects/BimodalLogic`; `diff` of the four
  cited call sites; `time bash .claude/scripts/check-deploy-freshness.sh .` in BimodalLogic;
  `jq` queries against both repos' `.claude-extensions.json`.
- Files read: `agent-system/extensions/core/scripts/check-consumer-freshness.sh`,
  `.../check-deploy-freshness.sh`, `.../command-gate-in.sh`, `.../skill-base.sh` (structure),
  `.../lib/deploy-freshness-lib.sh`, `.../context/reference/known-consumer-repos.json`,
  `.../context/patterns/regeneration-is-manual-only.md` ("Detecting When You're Stale" section).
