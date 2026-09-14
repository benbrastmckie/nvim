# Research Report: Task #142 — Orchestrator context budget: measure and lock

- **Task**: 142 - Orchestrator context budget: measure and lock
- **Started**: 2026-09-08T06:00:00Z
- **Completed**: 2026-09-08T06:36:00Z
- **Effort**: ~1 hour
- **Dependencies**: 88 (completed — single-task engine deleted, thin four-move loop landed)
- **Sources/Inputs**:
  - `specs/PATH.md` (authoritative Stage A status, "Budgets" section, measured figures)
  - `agent-system/extensions/core/scripts/measure-eager-context.sh` (read in full, executed `--check`)
  - `agent-system/extensions/core/scripts/verify-deploy.sh` (Gates 16, 17, 18, 19; `warn()`/`fail()`)
  - `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (redeploy-checkpoint call site)
  - `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` (findings-diff algorithm)
  - `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (output schema)
  - `agent-system/extensions/core/scripts/check-extension-docs.sh` + `context/config/claudemd-size-budget.json` (existing ceiling-config precedent)
  - `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` ("Inter-Cycle Redeploy Checkpoint")
  - `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (Context Flatness Guarantee, stale prose)
  - `.claude/skills/skill-orchestrate/SKILL.md`, `.claude/commands/orchestrate.md` (current deployed byte counts)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- All three orchestrator files 142 was filed against are already **well past their targets** as
  a side effect of Stage A landing in full (88 completed 2026-09-08, one dispatch before this
  one): `SKILL.md` is 15,830 B (target ≤20,000 B — already under), `commands/orchestrate.md` is
  15,812 B (target ≤8,000 B — still ~2x over), and `measure-eager-context.sh --check`'s own
  total is 62,985 B / ~15.7k tokens (well under PATH.md's ≤25k-token combined target). 142's
  real remaining job is **locking these numbers with gates**, not further cutting.
- A strong, directly-reusable precedent for "small config file + severity-gated check" already
  exists: `context/config/claudemd-size-budget.json` + `check_claudemd_size_budget()` in
  `check-extension-docs.sh`, gated by `SCHEMA_CONFORMANCE_GATE_MODE` (env-var `hard`/anything-else
  toggle). The new gate should copy this shape almost verbatim rather than invent a new one.
- `verify-deploy.sh` already has the warn/fail split needed (`warn()` at line ~168, established
  by Gate 16 for exactly this "not yet safe to hard-fail" situation) — no new severity mechanism
  is needed, only a third gate (Gate 20) using it.
- **Load-bearing landmine found**: the inter-cycle redeploy checkpoint
  (`orchestrate-cycle-plan.sh` ~L585-630) does **not** consult `verify-deploy.sh`'s exit code — it
  diffs the `--findings` line SET before vs. after a redeploy (`deploy_findings_snapshot` /
  `deploy_baseline_new_findings` in `deploy-baseline-lib.sh`), and both `warn()` and `fail()`
  emit indistinguishable `FINDING <gate> ...` lines into that set. A warn-tier finding whose text
  embeds a byte count that changes every run (exactly what "print the number on every run" asks
  for) would appear as a "new finding" on almost every redeploy and spuriously trip
  `defer_reason:"deploy_checkpoint"` — this is precisely the MUST-NOT-DAMAGE item ("the inter-cycle
  redeploy checkpoint") the dispatch calls out. `fail()` already solved this exact problem for its
  own callers via an optional 3rd argument that overrides the normalized finding text; the new
  gate must use the same pattern.
- No prior art exists anywhere in the repo for "promote a warning to hard failure once stable
  across N deploys" as an *automatic*, state-tracked mechanism. The one real precedent
  (`SCHEMA_CONFORMANCE_GATE_MODE`, `STRICT_CORE_DEPLOY`) is a **manual** env-var-default flip a
  human commits once real numbers justify it. Recommend the same manual pattern here rather than
  building new persisted-counter machinery — see Decisions below.
- A per-task-per-cycle lead context-growth estimate, built from the actual output schemas of
  `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`'s pointer prompt (quoted verbatim
  in `SKILL.md` Move 2), and `orchestrate-cycle-postflight.sh`, comes to **~850–1,010 B per task
  per cycle** (pointer prompt ~188 B + per-agent context object ~266 B + postflight JSON
  176–338 B + amortized share of one cycle's `plan_json`, ~220 B for a 3-task cycle) — consistent
  with PATH.md's "≤ ~1 KB (three JSON objects)" target and with the old
  "`.orchestrator-handoff.json` ≤ 400 tokens" framing in the state-machine doc, but broader in
  scope than what that doc's sentence actually measures (see Finding 5).

## Context & Scope

142's description carries a REVISED (2026-09-02) scope that supersedes the ORIGINAL description
in state.json — the revision narrows the task to four concrete work items and explicitly retires
scope items 1 ("remaining mutually-exclusive branch sections") from the original text, since task
88 (completed 2026-09-08, immediately before this dispatch) already deleted the single-task
engine and its Stage 3.6/3.6a team fan-out and Stage 5a/5b hard-mode branching entirely — grepping
the current `SKILL.md` for `3.6`, `team fan-out`, `Stage 5a`, `Stage 5b`, `--team` returns nothing.
This report researches only the REVISED scope's four items, using `file_scope`'s three named
files (`verify-deploy.sh`, `measure-eager-context.sh`, `orchestrate-state-machine.md`) as the
implementation surface.

I did not run `orchestrate-cycle-plan.sh` / `orchestrate-cycle-postflight.sh` for real against
live `state.json` — this research dispatch is itself running inside an active `/orchestrate`
cycle (dispatch_seq 3), and those scripts mutate locks, mint `dispatch_seq`, and write
`specs/.orchestrator-multi-state-*.json`; invoking them live would be a disruptive, out-of-scope
side effect. Item 3's per-cycle measurement below is a schema-accurate estimate built by
constructing representative JSON with `jq -n -c` from each script's own documented `# Output`
contract and measuring it with `wc -c`; the plan below recommends how to turn this into a real,
reproducible measured number during implementation without touching the live task graph.

## Findings

### Finding 1 — Current byte counts vs. the two ceilings (re-measurement, WORK item 1)

| Surface | Original baseline (2026-09-02, per dispatch/PATH.md) | Current (measured this pass) | Ceiling (target) | Status |
|---|---|---|---|---|
| `skills/skill-orchestrate/SKILL.md` | 293,977 B | **15,830 B** | ≤ 20,000 B | **under ceiling** |
| `commands/orchestrate.md` | 46,874 B | **15,812 B** | ≤ 8,000 B | **~2x over ceiling** |
| `measure-eager-context.sh --check` total (CLAUDE.md chain + eager rules) | 63,973 B (~16k tokens) | **62,985 B (~15,746 tokens)** | part of ≤25k-token combined target | under combined target on its own |
| Combined eager load before first dispatch (SKILL.md + orchestrate.md + CLAUDE.md chain) | ~405 KB / ~100k tokens | **~94,627 B / ~23.1k tokens** | ≤ 25k tokens | **under combined target** |
| Lead-authored prompt text per cycle | 25-60 KB (task descriptions inlined) | **~188 B fixed pointer prompt per task** (Move 2, `SKILL.md`) | n/a (retired by 146) | **defect retired** |

`.claude/` and `agent-system/extensions/core/` are byte-identical for both orchestrator files
(`diff` not shown; sizes matched exactly in both trees), so the deploy tree is current and these
numbers are not stale. `SKILL.md`'s 15,830 B and the eager-chain total are both already inside
their targets; `commands/orchestrate.md` is the one number still over its ceiling. This directly
explains why the dispatch's WORK item 2 says "warn tier first" rather than "hard fail
immediately": a hard per-file ceiling on `orchestrate.md` today would fail on every single
`/orchestrate` invocation until further trimming lands, which is out of this task's narrowed
scope (142 is measure-and-lock, not further cutting).

### Finding 2 — Reusable precedent for the ceiling-config + severity-gate shape (WORK item 2)

`agent-system/extensions/core/context/config/claudemd-size-budget.json` is exactly the "small
config file in the source store" the dispatch asks for, already consumed by
`check_claudemd_size_budget()` in `check-extension-docs.sh:805` and wired into `verify-deploy.sh`
Gate 3. Its shape:

```json
{
  "_comment": "...derivation formula...",
  "extensions": { "core": { "ceiling_bytes": 19950, "measured_bytes": 18952, "measured_at": "2026-08-12", "derivation": "..." } },
  "default_ceiling_bytes": 8000,
  "default_ceiling_comment": "..."
}
```

The severity split it feeds into (`SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-hard}"`,
checked at `check-extension-docs.sh:662`) is an **env-var default a human flips**, not a
persisted, self-promoting counter — there is no code anywhere in this repo that counts
"consecutive deploys with the same warning" and auto-promotes severity. `STRICT_CORE_DEPLOY=1`
(same file, `check_core_deploy_advisory`) is the sibling pattern: advisories stay advisories
until a maintainer decides, by editing a default, that they should start failing.

`verify-deploy.sh` already carries the warn/fail primitive the new gate needs: `warn()`
(line ~168, added for Gate 16's "not yet safe to hard-fail" `routing_hard` migration notice)
increments `CHECKS` but never `FAILURES`, and mirrors `fail()`'s finding-text-override signature.
No new severity infrastructure is required — only a new gate (would be **Gate 20**, following
Gate 19's numbering) that calls `warn()` for the two per-file ceilings (since `orchestrate.md` is
still over its ceiling today) and can safely call `fail()` for the eager-load regression check
against the *original* 63,973 B baseline, since the current measured value (62,985 B) is already
comfortably under it — that specific sub-check has no "not yet true" problem the way the
per-file ceilings do. The dispatch's own phrasing ("fail above the recorded baseline... Warn
tier first" for the ceilings) supports reading these as two different initial severities, not
one blanket warn-everything gate; the plan should confirm this split explicitly rather than
default silently to warn-everything (which would silently forgo test-driving `fail()` on the one
check that's already safe to hard-fail).

### Finding 3 — Redeploy-checkpoint interaction is a real hazard, not a hypothetical (MUST NOT DAMAGE)

`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint (`context/patterns/batch-orchestration-guardrails.md`
§"The Inter-Cycle Redeploy Checkpoint", implemented at `orchestrate-cycle-plan.sh:585-630`) does
**not** gate on `verify-deploy.sh`'s exit code directly. It calls
`deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh"` (from `lib/deploy-baseline-lib.sh`)
both before and after a redeploy, which runs `verify-deploy.sh --findings --quiet` and greps every
`^FINDING ` line from stdout — **`warn()` and `fail()` both emit lines in that exact format**
(`FINDING $CURRENT_GATE $message`), indistinguishable to the grep. `deploy_baseline_new_findings`
then does `comm -13` between the pre- and post-redeploy finding sets; **any line present after
that wasn't present before** — including a brand-new WARN — reads as case (b), "a genuinely new
failure," and the checkpoint defers every remaining task in the batch
(`defer_reason:"deploy_checkpoint"`).

This matters directly for WORK item 2's "print the number on every run so drift direction is
visible" instruction: if the printed number is embedded in the *default* finding text passed to
`warn()`/`fail()` (i.e., the first argument, with no override), the finding line changes on
almost every invocation (byte counts drift by small amounts constantly), so it would register as
"new" on nearly every redeploy checkpoint regardless of whether anything actually regressed —
silently breaking the inter-cycle redeploy checkpoint's whole point (distinguishing genuinely new
problems from pre-existing ones). `fail()`'s own header comment already documents the fix for
this exact problem class ("used where the narrative message embeds a numeric count that must not
leak into the normalized finding"): pass a normalized, count-free string as the optional 3rd
argument, and put the actual byte count only in the human-readable stderr line (arg 1/2), which
`--findings` mode does not capture. The new gate must follow this convention for all three checks
(eager-load regression, both per-file ceilings) — this is the single most important
implementation constraint this research surfaced.

### Finding 4 — Volatile-file guard is already correct; no new work needed there

WORK item 2's third clause ("volatile files in the eager set remain an unconditional failure") is
already fully implemented in `measure-eager-context.sh` itself: a `VOLATILE_PATHS` deny-list
(`specs/TODO.md`, `specs/state.json`, `specs/errors.json`), an `is_volatile()` check inside
`add_record()` that emits a `FLAG:` line and increments `VOLATILE_HITS`, and the script's own
`--check` mode exits 1 whenever `VOLATILE_HITS -gt 0` — confirmed by reading the exit-code tail
of the script and by running `bash .claude/scripts/measure-eager-context.sh --check`, which
reported `Volatile-file hits: 0` and `CHECK PASSED`. The new Gate 20 in `verify-deploy.sh` should
simply call `measure-eager-context.sh --check` and treat **its own exit code** as an unconditional
`fail()` component (never `warn()`), separately from the byte-ceiling comparisons Gate 20 does on
top of that script's printed total — this keeps the volatile-file hard-fail semantics exactly as
strict as they are today, with zero new logic to write for that specific clause.

### Finding 5 — Per-cycle growth: schema-accurate estimate and the stale doc prose (WORK items 3 & 4)

Built directly from each script's own `# Output`/schema comments and the literal pointer-prompt
text quoted in `SKILL.md`'s Move 2 (not re-typed from memory):

| Component | Representative instance | Bytes |
|---|---|---|
| Move 2 pointer prompt (per task) | `"You are dispatched by /orchestrate for task 129, phase implement. Read specs/.../.dispatch/4.md first and execute it exactly; it names every input, output path and contract."` | 188 |
| Move 2 context object (per task) | `{task_number, orchestrator_mode, session_id, task_dir, handoff_path, dispatch_seq}` | 266 |
| Move 3 postflight JSON, ordinary case (per task) | `{task, phase, status, phases_completed, phases_total, verdict, halt, infra_exempt_cycle, aux_signal, note}` | 176 |
| Move 3 postflight JSON, `ask_user` case (per task) | same + `user_decision:{question, options, recommended, blocking}` | 338 |
| Move 1 `plan_json` (once per cycle; shown for a 3-task cycle) | `{cycle, dispatch:[3 rows], aux_dispatch:[], deferred:[1 row], blocked:[], stop:null}` | 658 (≈220/task amortized) |

Per-task-per-cycle total: **188 + 266 + 176(–338) + 220 ≈ 850–1,010 B**, matching PATH.md's
"≤ ~1 KB (three JSON objects)" Budget-table target (`specs/PATH.md` line ~203). This is a
schema-derived estimate, not a live measurement — WORK item 3 asks for either "a test or a
documented procedure," and the concrete, low-risk procedure this research recommends is: add a
`--dry-run` invocation of the real three-cycle-script chain against a disposable 3-task fixture
(mirroring the fixture patterns already used in `test-orchestrate-cycle-plan.sh` /
`test-orchestrate-build-dispatch.sh` / `test-orchestrate-cycle-postflight.sh`, all of which
already construct isolated `state.json`/task-dir fixtures rather than touching the real ones),
sum `wc -c` over the three scripts' actual stdout for that fixture run, and record the number in
this task's summary — turning the estimate above into a real measured one without touching live
orchestrator state. This is the "test or documented procedure" WORK item 3 calls for; a single
new fixture-based test is the cheaper of the two and produces a re-runnable number.

The stale prose is `docs/architecture/orchestrate-state-machine.md`'s `## Context Flatness
Guarantee` section (line 211), which still reads: *"The `.orchestrator-handoff.json` file is
≤ 400 tokens. The orchestrator context grows by only ~400 tokens per cycle, regardless of the
complexity of the delegated work."* Two problems: (1) `.orchestrator-handoff.json` is written by
the **dispatched agent**, and the lead never reads it directly on the normal path — Move 3 reads
`orchestrate-cycle-postflight.sh`'s compact JSON instead (the handoff is one of that script's own
inputs, consulted with mtime + `dispatch_seq` staleness gates, per
`docs/architecture/handoff-schema.md`'s "Context Flatness Constraint" section) — so citing the
handoff file's own size as the per-cycle growth figure conflates two different things measured at
two different points in the pipeline; (2) "~400 tokens per cycle" describes a single artifact's
size ceiling, not the sum of everything the lead actually accumulates per task per cycle (pointer
prompt + context object + postflight JSON + amortized plan JSON), which is closer to the ~850–1,010 B
range above (≈210–250 tokens at 4 B/token, actually *under* 400 tokens, so the qualitative claim
survives even though the mechanism cited is wrong). WORK item 4's fix: replace the paragraph's
citation of the handoff file's own size with the measured per-task-per-cycle total (once WORK item
3's fixture test produces a real number) and correct the mechanism description to name
`orchestrate-cycle-postflight.sh`'s output as what the lead actually reads, cross-referencing
`docs/architecture/orchestrate-cycle-postflight.md`'s existing (and already-accurate) "Context
Flatness: What Each Read Is Bounded To" section rather than duplicating it.

## Decisions

1. **Reuse the `claudemd-size-budget.json` + `check_extension_docs.sh` shape verbatim** for the
   new ceiling config (a new `context/config/orchestrator-context-budget.json` or similar,
   `ceiling_bytes` per named file + `default_ceiling_comment`-style derivation note) rather than
   inventing a new config format. Low risk: this shape is already deployed, tested, and understood.
2. **No new "N stable deploys" auto-promotion machinery.** Follow the `SCHEMA_CONFORMANCE_GATE_MODE`
   / `STRICT_CORE_DEPLOY` precedent: a single env-var-defaulted severity toggle per gate
   (`ORCHESTRATOR_BUDGET_GATE_MODE="${ORCHESTRATOR_BUDGET_GATE_MODE:-warn}"` or similar), flipped
   to `hard` by a human, in a follow-up commit, once `commands/orchestrate.md` is actually at or
   under 8,000 B. Building a persisted-counter "N consecutive deploys" mechanism would touch
   deploy-time state no other gate in this file maintains, is unneeded machinery for a decision a
   human can make in one line, and risks its own bugs in exactly the kind of critical-path script
   the MUST-NOT-DAMAGE list is protecting.
3. **Split severity within Gate 20 itself**: `fail()` for the eager-load-vs-original-baseline
   regression (already safely under baseline today), `warn()` for both per-file ceilings (one is
   still over). This reads as the more faithful implementation of the dispatch's literal wording
   than a single blanket warn-tier gate.
4. **Every `warn()`/`fail()` call in the new gate must pass a 3rd-argument normalized finding
   string with no embedded byte count**, per Finding 3. This is a hard constraint, not a style
   preference — skipping it breaks the inter-cycle redeploy checkpoint's new-vs-pre-existing
   distinction on almost every real redeploy.
5. **WORK item 3's probe should be a new fixture-based test**, following the existing
   `test-orchestrate-cycle-plan.sh`/`test-orchestrate-build-dispatch.sh`/
   `test-orchestrate-cycle-postflight.sh` fixture-isolation pattern, that runs the real
   three-script chain against a disposable 3-task fixture and sums `wc -c` over their stdout,
   rather than a documentation-only estimate — this repo's own standing rule 3
   ("verify by execution, not by reading," `specs/PATH.md` §Standing rules) directly favors an
   executable, re-runnable test over a written-down number.

## Recommendations

1. Add `context/config/orchestrator-context-budget.json` (source store) with `ceiling_bytes` for
   `skills/skill-orchestrate/SKILL.md` (20,000) and `commands/orchestrate.md` (8,000), plus the
   original eager-load baseline (63,973 B) for the regression check, mirroring
   `claudemd-size-budget.json`'s `_comment`/derivation-note style.
2. Add Gate 20 to `verify-deploy.sh`, following the exact structural pattern of Gates 17–19
   (source-store-only `[SKIP]` posture, `CURRENT_GATE="gate20"`, narrative + `--findings` output):
   call `measure-eager-context.sh --check` for the volatile-file hard-fail component (Finding 4);
   compare its printed total against the config's recorded baseline via `fail()` with a normalized
   3rd-arg finding text (Finding 3); compare `SKILL.md`/`orchestrate.md` sizes against the config's
   two per-file ceilings via `warn()`, same normalized-text requirement; print the live byte counts
   unconditionally to stderr via `say`/plain `echo` (never inside the `warn()`/`fail()` message
   itself) so "print the number on every run" is satisfied without polluting the findings diff.
3. Build a fixture test (new `test-orchestrate-context-budget.sh` or an addition to one of the
   three existing cycle-script test files) that runs a disposable 3-task cycle through
   `orchestrate-cycle-plan.sh` → (fixture dispatch) → `orchestrate-cycle-postflight.sh` and reports
   total bytes; record the resulting number in this task's implementation summary and in the
   corrected state-machine doc paragraph.
4. Rewrite `orchestrate-state-machine.md`'s `## Context Flatness Guarantee` paragraph to (a) name
   `orchestrate-cycle-postflight.sh`'s compact JSON as what the lead reads on the normal path
   (cross-reference `docs/architecture/orchestrate-cycle-postflight.md`'s existing accurate
   section instead of restating it) and (b) cite the measured per-task-per-cycle figure from
   Recommendation 3 in place of the "~400 tokens" handoff-file-size claim.
5. Exercise Gate 20 on two fixtures before declaring it green on the real tree, per the dispatch's
   own acceptance criterion ("exercised on a fixture that exceeds each ceiling"): one fixture
   copy of `orchestrate.md` padded past 8,000 B (expect `[WARN]`, exit 0, one finding line with
   normalized text) and one copy of `SKILL.md` padded past 20,000 B (same). Confirm neither
   fixture run flips `verify-deploy.sh`'s own exit code, and confirm a synthetic pre/post
   `deploy_findings_snapshot` diff around such a warn does **not** register as a new finding once
   the byte count is out of the finding text (validates Finding 3's fix directly).
6. Re-run `bash .claude/scripts/verify-deploy.sh` (full, not `--skip-slow`) and
   `bash .claude/scripts/measure-eager-context.sh --check` after Gate 20 lands, per PATH.md's
   still-open "Validation to run" item, and fold that into 142's acceptance ("Gate 19 green; full
   gate run green" — Gate 20 joins that same full-run requirement).

## Risks & Mitigations

- **Risk**: a literal reading of "fail above the recorded baseline" for the eager-load check
  could be implemented as unconditional `fail()` from day one, which is safe only because current
  measurements happen to be under baseline right now — a future legitimate CLAUDE.md/rules growth
  (e.g., a new extension's eager rule) would then hard-fail every deploy with no warn-first
  runway. **Mitigation**: still route it through the same `ORCHESTRATOR_BUDGET_GATE_MODE`-style
  toggle as the per-file ceilings (default can start at `hard` for this one check specifically
  per Decision 3, but the toggle should exist so a future maintainer can soften it without editing
  gate logic).
- **Risk**: the findings-diff interaction (Finding 3) is easy to miss in implementation review
  since `warn()`'s own header comment doesn't call out the redeploy-checkpoint consumer at all —
  only `fail()`'s header comment documents the "embeds a numeric count" pattern. **Mitigation**:
  this report's Finding 3/Decision 4 should be treated as a required implementation constraint,
  not an optional cleanup; Recommendation 5's fixture-diff exercise is the concrete verification.
- **Risk**: `commands/orchestrate.md` staying ~2x over its ceiling indefinitely under a permanent
  warn-only gate provides no forcing function to actually close the gap. **Mitigation**: out of
  142's narrowed scope (measure-and-lock, not further cutting) — flag as a Stage C/observations
  follow-up rather than pulling further orchestrate.md trimming into this task.

## Context Extension Recommendations

- **Topic**: severity-gate config-file pattern (ceiling JSON + env-var mode toggle).
- **Gap**: this pattern (demonstrated by `claudemd-size-budget.json` /
  `check_claudemd_size_budget()` / `SCHEMA_CONFORMANCE_GATE_MODE`) is not documented anywhere as a
  reusable convention — a future gate author would have to rediscover it by reading
  `check-extension-docs.sh` directly, as this research did.
- **Recommendation**: after 142 lands a second instance of this pattern, consider a short
  `context/patterns/` note naming both instances and the shape they share, so a third gate can
  cite a pattern doc instead of two prior gate implementations.

## Appendix

- `measure-eager-context.sh --check` run output (this pass): `TOTAL: 62985 B (15746 tokens est.)`,
  `Volatile-file hits: 0`, `CHECK PASSED`.
- `wc -c .claude/skills/skill-orchestrate/SKILL.md` → 15,830 (source-store copy identical).
- `wc -c .claude/commands/orchestrate.md` → 15,812 (source-store copy identical).
- Representative-JSON byte measurements (Finding 5) were produced with `jq -n -c '{...}' | wc -c`
  against each script's own documented output schema — reproducible by re-running the same `jq`
  invocations shown in Finding 5's table derivation.
- Real dispatch-file sizes sampled for context (not part of lead cost — read by the dispatched
  agent, not the lead): this task's own `.dispatch/3.md` is 7,163 B;
  `specs/archive/134_tag_branch_reachability_gate/.dispatch/*.md` samples ranged 8,349–8,488 B.
