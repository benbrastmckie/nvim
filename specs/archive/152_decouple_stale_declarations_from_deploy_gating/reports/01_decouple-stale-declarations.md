# Research Report: Task #152

**Task**: 152 - Decouple stale declarations from deploy gating
**Started**: 2026-09-07
**Completed**: 2026-09-07
**Effort**: medium (two independent axes, each a targeted edit against well-understood code)
**Dependencies**: None (sibling task fixes the two live remaining `line_count` gate failures; this
task addresses the defect class)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/*.sh`,
`agent-system/extensions/core/context/patterns/*.md`, `lua/neotex/plugins/ai/shared/extensions/*.lua`),
`specs/state.json` task 152 description, `specs/errors.json`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- **Axis (a) — `line_count` drift**: `line_count` is NOT display-only. It is read by
  `validate-context-budgets.sh`, `validate-index.sh`, and `install-extension.sh` (the last as a
  `.line_count // 100` fallback during descriptor copy) to compute per-agent/per-task-type token
  budgets. Option (iii) "drop it" is therefore ruled out by the dispatch's own instruction to
  verify consumption first. The deployed `.claude/context/index.json` is a straight upsert-copy of
  each extension's source `index-entries.json` (`merge.lua`'s upsert-entries function) — deploy
  time performs no recomputation today, so nothing currently prevents a hand-edited declaration
  from silently drifting from the file it describes. `generate-context-line-counts.sh` already
  exists as a `wc -l`-based regenerator with `--check`/`--write` modes; it is presently invoked
  only manually. Recommendation: **option (i)/(ii) hybrid** — see Recommendation section below.
- **Axis (b) — batch-stall coupling**: The dispatch's root-cause narrative is fully confirmed by
  reading `orchestrate-cycle-plan.sh` directly (lines ~561-596): the inter-cycle redeploy
  checkpoint's baseline-tolerance branch (compare pre/post `verify-deploy.sh --findings`, proceed
  when 0 new) lives **only** inside the `if bash deploy-headless.sh; then ... else <unconditional
  defer> fi` success arm — the `else` arm has no baseline logic at all, so it fires the same
  unconditional defer for exit 3 (deploy landed, pre-existing verify failure) as for exit 1/2
  (deploy genuinely failed).
- **A working precedent for the exact fix already exists in this codebase**:
  `command-gate-out.sh`'s single-task postflight completion-deploy-gate handler (`rc == 6` branch,
  lines ~148-217) already implements the correct three-way split — `deploy-headless.sh` exit 1/2
  is branch (a) unconditional-refuse-no-retry; exit 3 (or 0) falls through to a pre/post
  `verify-deploy.sh --findings` baseline comparison, proceeding (branch c) when no new findings
  appear. `orchestrate-cycle-plan.sh`'s batch checkpoint is the one call site that does **not**
  yet mirror this pattern — porting `command-gate-out.sh`'s `gate_out_deploy_rc -eq 1 || -eq 2`
  vs.-else structure into the checkpoint's `else` branch is a small, targeted, well-precedented
  edit, not a redesign.
- **The "stale consumer repos" third confound does not currently reproduce** in `deploy-headless.sh`
  as written: its post-deploy `check-consumer-freshness.sh --stale-only` call is fully guarded
  (`|| true` on the command-substitution assignment) and never contributes to `verify_rc`/the
  script's own exit code. Static reading of the current script shows exit 3 has exactly one cause
  today (a non-clean inline `verify-deploy.sh --skip-slow` run) and exit 1/2 exactly one cause
  each (nvim invocation failure / bad wipe snapshot). This is a genuine research finding worth
  flagging to the planner: either (a) this confound was already fixed by task 93's guard and the
  dispatch text is describing a historical/pre-fix observation, or (b) there is a reproduction
  path not visible from static reading (e.g. `set -e` interaction, a different invocation context)
  that needs a runtime repro before the plan commits to "already handled." Recommend the plan
  phase spend one cheap step confirming which, rather than assuming either.
- Both `orchestrate-cycle-plan.sh` and `update-task-status.sh` are named in
  `context/reference/orchestrator-critical-paths.json` territory and are subject to the
  self-modification ordering gate per the dispatch's own constraint — the plan must expect a
  single-candidate-per-cycle admission constraint if this task's own implementation touches them
  alongside other in-flight self-modifying tasks.

## Context & Scope

Task 152 addresses the CLASS of defect exposed when three stale, hand-maintained `line_count`
integers in `index-entries.json` files caused `check-extension-docs.sh` Rule R to fail, which
failed `verify-deploy.sh` gate 3, which made `deploy-headless.sh` exit non-zero, which caused
`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint to defer an entire multi-task batch
— even though the existing pre-existing-baseline tolerance mechanism (built for exactly this
situation) was structurally unreachable because it lives inside the wrong branch. Two independent
axes are in scope: (a) stop hand-maintaining `line_count`; (b) decouple pre-existing/unrelated gate
health from task completion and batch progress, without making gates non-blocking wholesale.

## Findings

### Codebase Patterns

#### Axis (a): `line_count`

- **Declaration and check site**: `check-extension-docs.sh`'s Rule R
  (`check_line_count_accuracy`, line 616) walks every extension's SOURCE `index-entries.json`
  against `wc -l` of `context/<path>`, entirely independent of whether the extension is currently
  loaded — this is why even an unloaded extension's stale declaration (the literature entry in the
  dispatch) can fail the gate. Severity is controlled by `INDEX_TRUTH_GATE_MODE` (default `"hard"`,
  env-var overridable — line 594), a sibling to the pre-existing `ORPHAN_GATE_MODE` precedent for
  gradual promotion from advisory to hard once remediation lands (comment at line 651-660
  documents this promotion pattern explicitly and is a usable precedent for any interim rollout
  the plan wants).
- **Deployed copy**: `.claude/context/index.json` is generated by
  `lua/neotex/plugins/ai/shared/extensions/merge.lua`'s upsert-entries function (~line 495), which
  copies each source entry's fields verbatim (including `line_count`) into the deployed index —
  no recomputation happens at deploy time today. The doc comment at merge.lua:502 explicitly notes
  upsert (not skip-if-exists) exists specifically so "a regenerated `line_count`" CAN reach the
  deployed index on a later merge — i.e., the deploy pipeline already anticipates line_count being
  externally regenerated and re-synced, just not deriving it itself.
- **Regenerator**: `generate-context-line-counts.sh` already implements exactly the derivation
  logic needed — `--check` (report-only, matches Rule R's own logic) and `--write` (surgical,
  line-oriented `wc -l` correction of the SOURCE `index-entries.json`, deliberately avoiding a
  full `jq` pretty-print round-trip to keep diffs reviewable). This script is the natural
  mechanism for either option (i) or (ii); no new counting logic needs to be written.
- **Consumers, confirmed** (ruling out option iii "drop entirely"):
  - `validate-context-budgets.sh:156,190,200,213` — sums `line_count` per agent/task-type/always
    tier to compute token-budget reports (`* 8` tokens/line estimate).
  - `validate-index.sh:99,109,118,126` — same per-agent/per-task-type/always/total line-count
    sums, used for index validation budget checks.
  - `install-extension.sh:214,228` — `.line_count // 100` fallback when copying descriptors during
    install, meaning a missing/null `line_count` silently becomes a wrong-but-plausible `100`
    rather than an error — another argument for deriving rather than declaring, since a derived
    value can never be null.
  - `validate-context-index.sh:116,147` — schema/shape checks including `line_count` presence.
  - Several test files (`test-index-entries-schema.sh`, `test-conflict-predicate.sh`,
    `test-double-loading-check.sh`, `test-deploy-orphans.sh`) assert on `line_count` shape/values
    and would need updating under any of the three options.
- **The auto-repair-reporting precedent** (named in the dispatch): `skill-lifecycle.md`'s
  "In-Place `--fix` Mutation on the Gate-Out Path (D-A)" subsection documents `validate-artifact.sh
  --fix`'s non-blocking auto-repair of task metadata at `command-gate-out.sh`'s Stage 6a, with
  `command-gate-out.sh:236,260` reporting fix/error/warning counts unconditionally (repaired and
  clean alike) and appending an `artifact_auto_repair` row to `specs/events.jsonl` — never a silent
  in-place mutation. Any option (ii)-style auto-repair for `line_count` should follow this exact
  shape: report every repair, never mutate silently.

#### Axis (b): the batch-stall coupling

- **`orchestrate-cycle-plan.sh`, the actual defect site** (lines 561-596): the redeploy checkpoint
  captures `pre_findings` via `verify-deploy.sh --findings --quiet`, then:
  ```
  if bash "$SCRIPT_DIR/deploy-headless.sh" >&2; then
      # ... post_raw/post_findings captured, comm -13 against pre_findings ...
      # branch on new_findings empty (proceed + record verify_deploy_baseline_notices)
      # vs non-empty (defer)
  else
      deploy_exit=$?
      # UNCONDITIONAL defer — no baseline comparison at all
  fi
  ```
  Because `deploy-headless.sh` exits non-zero (3) whenever the inline `verify-deploy.sh
  --skip-slow` reports ANY failure — including one wholly unrelated to the current batch — the
  `else` branch fires and every remaining task is deferred via `deferred_deploy_checkpoint`,
  regardless of whether the failure is new or pre-existing. The baseline-tolerance mechanism (the
  `comm -13`/`new_findings`-empty branch) is real, tested logic that is simply unreachable from
  this path.
- **The precedent fix already exists**: `command-gate-out.sh`'s postflight completion-deploy-gate
  handler (`gate_out_rc == 6` branch) implements precisely the split axis (b) asks for:
  ```
  gate_out_pre_findings="$(_gate_out_deploy_findings)"       # captured BEFORE deploy
  gate_out_deploy_rc=0
  gate_out_deploy_log="$(bash deploy-headless.sh 2>&1)" || gate_out_deploy_rc=$?
  if [ "$gate_out_deploy_rc" -eq 1 ] || [ "$gate_out_deploy_rc" -eq 2 ]; then
      # Branch (a): deploy itself failed to land -- unconditional, no baseline consultation.
      # Comment: "Exit 3 is deliberately excluded from this branch"
  else
      # exit 0 OR exit 3 both fall through here
      gate_out_post_findings="$(_gate_out_deploy_findings)"
      # comm -13 diff -> branch (b) new findings: refuse; branch (c) all pre-existing: proceed loudly
  fi
  ```
  This is a byte-for-byte match for what the dispatch asks for on the batch path. The plan's most
  direct implementation is to restructure `orchestrate-cycle-plan.sh`'s `else` branch to capture
  `deploy_exit` from the `if`'s own condition (rather than branching purely on `if`/`else` truthy
  status) and apply the identical `-eq 1 || -eq 2` vs.-else split, reusing the SAME
  `pre_findings`/`post_findings`/`comm -13` variables the `then` branch already computes today
  (today only reachable on exit 0). `batch-orchestration-guardrails.md`'s "The Inter-Cycle Redeploy
  Checkpoint" subsection is the single authoritative doc for this contract and states the (a)/(b)/(c)
  three-branch shape already — its written contract already matches what `command-gate-out.sh`
  implements; only `orchestrate-cycle-plan.sh`'s code has not caught up. That same subsection's
  "Exit-2 resolution" rule (fold `verify-deploy.sh` exit 2 into the findings vocabulary as one
  sentinel `FINDING gate0 [SENTINEL] ...` line) is also already implemented in
  `command-gate-out.sh`'s `_gate_out_deploy_findings()` helper and should be reused/ported rather
  than reinvented.
- **`regeneration-is-manual-only.md`'s own text foresaw this exact follow-up**: its "The Stage MT-3
  step 7 collision" subsection (written when exit 3 was introduced) states verbatim: "A distinct
  exit code was chosen specifically so a follow-up task can route exit 3 through the existing
  baseline-comparison branches with a small, targeted edit rather than a redesign; that follow-up
  is not done by this correction. It would touch `skills/skill-orchestrate/SKILL.md` and
  `context/patterns/batch-orchestration-guardrails.md`." In practice, `SKILL.md`'s own Stage MT-3
  step 7 prose has since been collapsed into a single delegated call to
  `orchestrate-cycle-plan.sh` (SKILL.md line ~2336: "the inter-cycle redeploy checkpoint are now
  ONE call" to the script) — so the actual code edit target today is `orchestrate-cycle-plan.sh`
  itself, plus the doc update to `batch-orchestration-guardrails.md`'s branch-(a) wording (it
  currently reads "`deploy-headless.sh` failure" without explicitly scoping that to exit 1/2, which
  should be tightened once the code distinguishes them).
- **The "stale consumer repos" confound — NOT reproducible from static reading of current code**:
  `deploy-headless.sh`'s trailing block (lines ~296-315) calls
  `check-consumer-freshness.sh --stale-only` strictly AFTER `verify_rc` is already fixed at 0 or 3,
  captures its output as `consumer_report="$(bash "$consumer_checker" --stale-only 2>&1)" || true`
  (the `|| true` guards the assignment's own exit status), and the script's single trailing `exit
  "$verify_rc"` never references the consumer report or its exit code at all. `verify-deploy.sh`
  itself contains no consumer-freshness gate (grepped for "consumer"/"stale"/"fleet"/
  "check-consumer" — the only "consumer" hits are the unrelated "deploy consumer repo" SKIP-branch
  phrasing used by gates 5/6/7/9/11/12/13/15/17/18/19). This 3rd confound is therefore either (a)
  a pre-task-93 observation now already fixed by the `|| true` guard (git log shows the guard
  landed in "task 93 phase 4-5: post-deploy stale-consumer report"), or (b) something the plan
  phase should reproduce at runtime before committing effort to a fix that may already be a no-op.
  Recommend a cheap verification step in the plan (a scratch run of `deploy-headless.sh` against a
  target with a deliberately-stale registered consumer) before designing a distinguishing exit code
  for this cause.
- **Independent confirmation of the dispatch's stated `update-task-status.sh` exit 6 behavior**:
  `batch-orchestration-guardrails.md`'s "The Postflight Completion-Deploy Gate" subsection
  documents the exit-6 backstop as a check-only, per-task path-scoped freshness comparison
  (`deploy_freshness_status`), never a whole-repo verify-health check — consistent with the
  dispatch's claim that it "checks only per-task deploy FRESHNESS, not whole-repo verify health."
  This mechanism is a **sibling**, not the same code path, to the Inter-Cycle Redeploy Checkpoint;
  it already independently implements the identical (a)/(b)/(c) contract via
  `command-gate-out.sh` (single-task path) as described above. The multi-task batch path for this
  SAME exit-6 gate lives in `commands/implement.md` Step 4 (not `orchestrate-cycle-plan.sh`) and
  was out of this report's read budget to verify in full — worth a plan-phase glance since it may
  share the same "does it distinguish exit 1/2 vs exit 3" question independently of the redeploy
  checkpoint fix.

### External Resources

Not applicable — this is a pure internal-tooling/process defect with no external library or API
surface.

### Recommendations

**Axis (a) recommendation — hybrid (i)+(ii), not a bare pick of one option:**

Given `line_count` is genuinely consumed for budget math (ruling out iii), and the deployed index
is already a verbatim upsert-copy with no recomputation (meaning "derive purely at deploy time and
never declare it" would require either removing the field from the git-tracked
`index-entries.json` schema entirely — a bigger schema change touching `index.schema.json` and the
consumers listed above — or teaching `merge.lua` to recompute it during upsert, which only helps
loaded extensions and does not close Rule R's SOURCE-level, unloaded-extension check), the
most surgical fix that satisfies the acceptance criterion ("editing an indexed file and showing the
gate stays green without a manual declaration edit") is:

1. Wire `generate-context-line-counts.sh --write` as an explicit, reported auto-repair step,
   following the D-A precedent exactly: report every corrected entry (never silent), never run it
   silently as a side effect of an unrelated command. The natural trigger point is a dedicated
   `--fix` flag on `check-extension-docs.sh` itself (mirroring `validate-artifact.sh`'s existing
   `--fix` idiom the dispatch names), OR invoking `generate-context-line-counts.sh --write`
   explicitly inside `deploy-headless.sh`'s main() immediately before its inline `verify-deploy.sh`
   call, with its own diff/count echoed to the caller exactly as `command-gate-out.sh` already
   echoes `SKILL_VALIDATE_FIXES`. The latter is preferable: it means every regeneration
   self-heals `line_count` drift before Rule R ever evaluates, converting Rule R from "catches
   drift" to "catches ONLY a missing source file" (a case that genuinely cannot be auto-repaired
   and should keep failing loudly).
2. This is option (ii) in spirit (repair + report, matching the named precedent) but achieves
   option (i)'s stated goal ("stop hand-maintaining") in practice, since a human should never need
   to hand-edit `line_count` again if every deploy self-corrects it first.
3. Whichever mechanism is chosen must still leave the field declared and git-tracked (so
   `index.schema.json`'s required-key check and the four consumers above keep working unmodified)
   — this is deliberately NOT option (iii).

**Axis (b) recommendation:**

Port `command-gate-out.sh`'s already-working `gate_out_deploy_rc -eq 1 || -eq 2` vs.-else pattern
into `orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint (lines ~561-596), so that:
- exit 1/2 → branch (a), unconditional defer (unchanged behavior, now correctly scoped).
- exit 3 (or 0) → falls through to the EXISTING `post_raw`/`comm -13`/`new_findings` logic (today
  only reachable from the `if` success arm), producing branch (b) (new findings → defer) or branch
  (c) (all pre-existing → proceed + `verify_deploy_baseline_notices` entry), matching what already
  happens for exit 0.
Update `batch-orchestration-guardrails.md`'s branch-(a) prose to explicitly scope "deploy-headless.sh
failure" to exit 1/2 (it currently reads as unscoped, which is the ambiguity
`regeneration-is-manual-only.md` already flagged). Treat the third "stale consumer repo" confound
as a verify-then-decide item, not an assumed-broken one — see Findings above.

## Decisions

- `line_count` MUST remain a declared, consumed field — option (iii) is rejected on the evidence
  gathered (four real consumers, not merely display).
- The batch-checkpoint fix should reuse `command-gate-out.sh`'s existing (a)/(b)/(c) pattern rather
  than design a new one — this is both cheaper and keeps the two call sites' failure semantics in
  sync, which `batch-orchestration-guardrails.md` already claims (incorrectly, until this task
  lands) is the case for both.
- The "stale consumer" third confound needs a runtime check before the plan commits to a specific
  fix for it — static reading suggests it is already a non-issue.

## Risks & Mitigations

- **Self-modification ordering gate**: both `orchestrate-cycle-plan.sh` and `update-task-status.sh`
  are orchestrator-critical paths per the dispatch's own constraint. If this task's implementation
  is dispatched alongside another self-modifying task in the same `/orchestrate` batch, expect
  `orchestrate-batch-admit.sh`'s designated-candidate tie-breaker to admit only one per cycle —
  plan phases accordingly rather than assuming both this task and a sibling self-modifying task
  land in the same cycle.
- **Auto-repair dirtying the working tree**: an axis-(a) fix that writes to `index-entries.json`
  automatically during a check/deploy run risks surprising uncommitted diffs if triggered at the
  wrong time (e.g., mid-unrelated-edit). Mitigate by only ever writing inside an explicit,
  reported step (deploy or an explicit `--fix` invocation), never inside a bare read-only lint
  path, and by always echoing what changed (never silent), matching the D-A precedent.
- **Rule R's INDEX_TRUTH_GATE_MODE precedent**: if the axis-(a) fix needs a rollout period, the
  existing `INDEX_TRUTH_GATE_MODE=advisory` env var (and the documented `ORPHAN_GATE_MODE`
  promotion precedent) is a ready-made staged-rollout mechanism — no new infrastructure needed.

## Context Extension Recommendations

- **Topic**: `batch-orchestration-guardrails.md`'s branch-(a) wording ambiguity between
  `deploy-headless.sh`'s exit 1/2 vs exit 3.
  **Gap**: the doc currently describes branch (a) as firing on "`deploy-headless.sh` failure"
  without naming which exit codes qualify, while `command-gate-out.sh`'s code already
  distinguishes them correctly. This mismatch is exactly the ambiguity
  `regeneration-is-manual-only.md` already flagged for `SKILL.md`; it should be closed as part of
  this task's own doc updates, not left for a future task to rediscover.
  **Recommendation**: tighten `batch-orchestration-guardrails.md`'s "The Inter-Cycle Redeploy
  Checkpoint" branch-(a) sentence to read "exit 1 or 2" explicitly, matching
  `command-gate-out.sh`'s comment ("Exit 3 is deliberately excluded from this branch").

## Appendix

### Search queries / code paths inspected

- `agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule R, `check_line_count_accuracy`,
  `INDEX_TRUTH_GATE_MODE`)
- `agent-system/extensions/core/scripts/generate-context-line-counts.sh` (full header)
- `agent-system/extensions/core/scripts/validate-context-budgets.sh`,
  `validate-index.sh`, `install-extension.sh`, `validate-context-index.sh` (line_count consumer
  grep)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (full file — exit code contract,
  consumer-freshness guard)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (lines 540-600, the redeploy
  checkpoint)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (lines 140-230, the `rc == 6` handler
  and its `(a)/(b)/(c)` pattern)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (Exit Code 3
  subsection, Tier 1-3 staleness model)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (Inter-Cycle
  Redeploy Checkpoint, Postflight Completion-Deploy Gate subsections)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage MT-3 step 7 delegation to
  script)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (index.json upsert-entries function, ~line
  495-520)
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` (D-A `--fix` precedent)
- `specs/errors.json`, `specs/TODO.md`, `specs/state.json` (dispatch text cross-reference, no
  independent corroboration found for the "stale consumer" confound beyond the task description
  itself)
