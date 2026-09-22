# Research Report: Task #252

**Task**: 252 - Port deploy-pending (exit 6) recovery into the batch postflight, and fix
`cycle_modified_files` accumulation on a refused postflight
**Started**: 2026-09-22T23:16:27Z
**Completed**: 2026-09-23T00:10:00Z
**Effort**: large (3 parts, cross-cutting two scripts and their shared library, plus two docs)
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/`), `specs/events.jsonl`,
`specs/.orchestrator-multi-state-sess_*.json` snapshots from the live run referenced in the
dispatch, git log
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

SOURCE STORE IS THE EDIT TARGET for every file this report names below:
`agent-system/extensions/core/` (never `.claude/**`).

## Executive Summary

- The dispatch's four "confirmed facts" are corroborated by direct code reading and by
  `specs/events.jsonl`/multi-state snapshots from the actual live run (task 249, session
  `sess_1790104446_f9923b`): a first `implement` postflight logged "completed" at 20:06:11 even
  though `update-task-status.sh` almost certainly refused it (exit 6), a **fresh** `implement`
  preflight fired 10 seconds later (re-dispatch against an already-done plan), and a
  `HANDOFF_STALE_OR_ABSENT` defect fired near the end after (inferred) manual
  `orchestrate-unwind-dispatch.sh` use — exactly Part 3's scenario.
- **Root cause of the missing recovery (Part 1)**: `orchestrate-cycle-postflight.sh`'s
  `implemented)` case arm calls `skill_postflight_update` **without capturing its return code**
  (no `|| rc=$?`), so `update-task-status.sh`'s exit 6 is silently discarded at exactly the layer
  the dispatch names. `skill_postflight_update` itself (in `skill-base.sh`) already captures the
  rc correctly and already annotates the task's `.return-meta.json` with
  `deploy_pending: true` on exit 6 — it just has no caller that acts on the annotation inside the
  batch loop.
- **The codebase already has a documented, load-bearing answer to Part 1's concurrency
  question**, and it argues against a literal "port the exit-6 branch into
  `orchestrate-cycle-postflight.sh`" reading of Part 1's title. Both
  `context/patterns/regeneration-is-manual-only.md` (the "Automated Exception" carve-outs) and
  `context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight Completion-Deploy
  Gate` subsection explicitly name this exact residual (labeled **D6**) and explicitly prescribe
  the fix: *"Widening Stage MT-3 step 7's trigger predicate from
  `orchestrator-critical-paths.json`'s critical-path keying to a broader
  `agent-system/extensions/**` predicate is the proper fix... not attempted by this mechanism."*
  Stage MT-3 step 7 **is** the existing Inter-Cycle Redeploy Checkpoint in
  `orchestrate-cycle-plan.sh` — the single already-sanctioned, already-serialized (no dispatch
  in flight) automated deploy-trigger site for `/orchestrate`. The docs also explicitly warn that
  adding a direct redeploy trigger *inside* per-task postflight would race the fail-open
  `specs/.deploy-lock` mutex, because Move 2 dispatches run genuinely in parallel (one message,
  multiple simultaneous Agent calls) even though Move 3 postflight itself loops **sequentially**
  over `dispatch[]` rows.
- **Recommended shape for Part 1** (an argued conclusion per the dispatch's own instruction, not
  a silent omission): do **not** add a new automated `deploy-headless.sh` trigger site to
  `orchestrate-cycle-postflight.sh`. Instead: (a) capture `skill_postflight_update`'s rc in the
  `implemented)` arm and log/handle it explicitly (still no new trigger — just visibility and
  correct bookkeeping, e.g. not treating a refused write as `implemented_gate_passed=true` for
  commit-message purposes); (b) widen the Inter-Cycle Redeploy Checkpoint's matching predicate in
  `orchestrate-cycle-plan.sh` (~line 747) so it fires on `deploy_pending_any` /
  any `agent-system/extensions/**` path in `cycle_modified_files`, not only on a match against
  `orchestrator-critical-paths.json`'s curated allowlist. This resolves the concurrency question
  by deferring to the checkpoint boundary — one of the three options the dispatch names as
  acceptable — and is fully backed by the codebase's own D6 residual note. If the plan instead
  chooses a literal port with its own new serialization (e.g., a per-cycle lock scoped to "after
  all this cycle's postflights, before the next cycle's dispatch"), that is also defensible, but
  it duplicates a mechanism the codebase already has and already names as the intended fix.
- `cycle_modified_files` accumulation (Part 2) at `orchestrate-cycle-postflight.sh`'s WORK (j)
  block (lines 1169-1176) is, on static reading, **not structurally gated** on
  `skill_postflight_update`'s return code today (`set -uo pipefail`, no `set -e`; the block runs
  unconditionally inside `if [ -z "$loop_guard_file" ]; then if is_live; then ...`). This is a
  genuine open question the plan/implementation should resolve empirically (see Findings ->
  Part 2 below) rather than assume: either the block already works and the dispatch's "aborts
  before" framing is a plausible-but-unverified hypothesis for the *mechanism*, or there is a
  subtler bug (e.g. cross-`/orchestrate`-invocation loss of the accumulator, since each fresh
  invocation starts a brand-new multi-state file with `cycle_modified_files: []`) that a literal
  "don't skip the block" fix would not by itself close.
- Test coverage gaps confirmed: `scripts/tests/test-postflight-deploy-gate.sh` (390 lines) covers
  the exit-6 refusal itself (case "overlap+stale exits 6") but has zero coverage of any
  *recovery*. `scripts/tests/test-orchestrate-cycle-postflight.sh` (1509 lines) has **zero**
  references to `cycle_modified_files` or `deploy_pending` anywhere — both files need new cases,
  per the dispatch's Acceptance #4, extending rather than duplicating these suites.
- Part 3's gap is real and precisely as scoped: `docs/architecture/orchestrate-state-machine.md`'s
  "Unwinding an Unconsumed Dispatch" section (lines 255-302) documents what
  `orchestrate-unwind-dispatch.sh` reverses and its refusal gate, but says nothing about what to
  run next; `skill-orchestrate/SKILL.md`'s pointer (lines 104-109) is equally silent.
  `reconcile-task-status.sh` (promotion of a stuck `implementing` task with a `summaries/*.md`
  artifact already on disk to `completed`) is exactly the sanctioned replay path, and its own
  header already documents this promotion table.

## Context & Scope

Researched the three parts of task 252's dispatch: (1) porting the exit-6 deploy-pending
recovery into the batch (`/orchestrate`) postflight path, with an explicit concurrency-posture
decision; (2) fixing `cycle_modified_files` accumulation so it survives a refused postflight
write; (3) documenting the `reconcile-task-status.sh` replay path after
`orchestrate-unwind-dispatch.sh`. All edits land in `agent-system/extensions/core/` (source
store), never `.claude/**`. Scope discipline per the dispatch: do not edit
`orchestrate-cycle-plan.sh` beyond what re-arming the checkpoint strictly requires, and do not
weaken the completion-deploy gate in `update-task-status.sh` itself.

## Findings

### Part 1 — Missing exit-6 recovery in the batch postflight

**The gap, precisely located.** `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`implemented)` case arm (~lines 763-788):

```bash
if skill_gate_completion_claim "$task_number" "$phases_completed" "$phases_total" \
     "$plan_markers_verified" "$notice_prefix"; then
  implemented_gate_passed=true
  if is_live; then
    skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn" "$TASK_DIR" "$clamp_mode"
    skill_orchestrate_propagate_completion "$task_number" "$task_type" "$TASK_DIR" \
      "$dispatch_start_ts" "${recover_json:-}" "$notice_prefix"
  ...
```

`skill_postflight_update`'s return value is discarded (no `|| rc=$?`), and `implemented_gate_passed`
was already set `true` by the *separate* phase-accounting gate (`skill_gate_completion_claim`)
before this call even runs — so a deploy-pending refusal at this point changes nothing about how
the rest of the script (commit message text at line 1105, `verdict` at line 963) treats the
outcome. This is corroborated by the actual live-run event trail for task 249
(`specs/events.jsonl`, session `sess_1790104446_f9923b`): `"Postflight stage completed for
implement (status: implemented)"` at `20:06:11`, followed by a fresh `"Preflight stage completed
for implement"` at `20:06:21` — a brand-new implement dispatch against a task whose plan was
already fully closed, exactly the re-dispatch loop the dispatch describes.

By contrast, `skill_postflight_update` itself (`scripts/skill-base.sh`, function starts line
839, returns line 999) already does the right thing internally: it captures
`update-task-status.sh`'s rc via `|| _postflight_rc=$?` inside its `researched|planned|implemented`
case arm, and on `_postflight_rc -eq 6` it best-effort-annotates the task's own
`.return-meta.json` with `deploy_pending: true` and
`deploy_pending_reason: "postflight completion-deploy gate refused (exit 6): ..."` (lines
~962-976), then `return "$_postflight_rc"` verbatim. **The annotation machinery already exists
and already fires correctly** — orchestrate-cycle-postflight.sh simply never reads it or reacts
to the non-zero return.

**`command-gate-out.sh`'s existing rc==6 handler** (lines ~153-211, the single-task path) is the
literal thing Part 1 says to port:
- Computes `gate_out_matched_paths` from `.return-meta.json`'s `modified_files` overlapping
  `agent-system/extensions/` for the log line.
- `deploy_findings_snapshot .claude/scripts/verify-deploy.sh` for a pre-redeploy baseline (from
  `scripts/lib/deploy-baseline-lib.sh`, sourced at the top of `command-gate-out.sh`).
- Runs `bash .claude/scripts/deploy-headless.sh`, captures its rc.
- Branch (a) rc 1/2: deploy did not land — no baseline consult, no retry, leave status as-is.
- Branch (b)/(c): `deploy_findings_snapshot` again (post), `deploy_baseline_new_findings` diff. A
  non-empty diff (b) refuses without retry; an empty diff (c) — the documented common case, given
  `deploy-headless.sh`'s universal exit 3 — announces a `[PRE-EXISTING VERIFY-DEPLOY FAILURE]`
  banner and retries the *same* `update-task-status.sh postflight ... "$status_token" ...` call
  **exactly once** (line 211's own comment: *"a second refusal after a successful redeploy is a
  real signal ... not re-attempted again"*).

**`deploy-baseline-lib.sh`** (`scripts/lib/deploy-baseline-lib.sh`, 165 lines) exports exactly
four functions, already the single shared home of the (a)/(b)/(c) contract for both existing
call sites (its own header states this explicitly — it existed specifically to stop
`command-gate-out.sh` and the Inter-Cycle checkpoint from drifting apart a second time):
`deploy_findings_snapshot`, `deploy_baseline_new_findings`,
`deploy_baseline_confirm_new_findings`, `deploy_baseline_unattributable_findings`. Any Part 1
implementation MUST reuse these (the dispatch already says so); do not reimplement.

**The concurrency question — already answered by the codebase's own architecture docs, not left
open.** This is the most load-bearing finding in this report. Two documents record the *identical*
residual task 252 exists to close, and both name the same prescribed fix:

1. `context/patterns/regeneration-is-manual-only.md` (`## Automated Exception: The Postflight
   Completion-Deploy Gate`, ~lines 116-170) lists **exactly two** sanctioned automated
   `deploy-headless.sh` trigger sites for this gate: `command-gate-out.sh`'s `rc == 6` branch
   (single-task `/implement`, "a point with no concurrency") and `commands/implement.md` Step 4's
   batch-refusal trigger (multi-task `/implement`, "already serial — it runs once, after all of
   Step 3's parallel dispatches have returned"). Immediately following, an **explicit
   non-exception** paragraph (~lines 134-142):

   > "An explicit non-exception, named so a later pass does not go looking for one:
   > `skill-orchestrate`'s Stage MT-3 step 7 is UNTOUCHED by this mechanism and needs no new
   > exception here — it remains covered exclusively by the Inter-Cycle Self-Modification
   > Checkpoint exception above. A task refused by the postflight completion-deploy gate under
   > `/orchestrate` defers loudly (via the `deploy_pending` marker `skill_postflight_update`
   > records into its `.return-meta.json`) rather than being redeployed by a THIRD trigger site;
   > widening Stage MT-3 step 7's own predicate is the proper fix for that residual and is named
   > as follow-up work in `context/patterns/batch-orchestration-guardrails.md`'s `### The
   > Postflight Completion-Deploy Gate` subsection, not attempted here."

   ("This is the second and, as of this writing, LAST exception this section records" — i.e. the
   doc's own count of "two" sanctioned sites for *this* gate is deliberate and load-bearing; this
   is almost certainly what the dispatch's "it currently says 'two'" refers to.)

2. `context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight Completion-Deploy
   Gate` subsection (lines 803-920) restates the same residual under the heading **"Residual —
   the `/orchestrate` path (D6, not fixed by this mechanism)"** (~lines 887-899):

   > "`/orchestrate` is covered by the backstop's refusal (a refused task simply stays
   > non-completed) but has NO serialized trigger of its own analogous to the two above; it
   > relies entirely on the pre-existing Inter-Cycle Redeploy Checkpoint mechanism documented
   > earlier in this file. A refused task under `/orchestrate` therefore defers loudly ... rather
   > than converging within that same invocation. **Widening Stage MT-3 step 7's trigger
   > predicate from `orchestrator-critical-paths.json`'s critical-path keying to a broader
   > `agent-system/extensions/**` predicate is the proper fix and is named here as explicit
   > follow-up work, not attempted by this mechanism** — it would change the meaning of a heavily
   > cross-referenced mechanism. (The cross-invocation durable ledger this predicate's *skip*
   > decision now consults ... already exists; widening WHICH cycles fire the checkpoint at all
   > remains the open, separate residual named here.)"

   The same subsection also states the concrete concurrency hazard of firing a redeploy from
   per-task postflight directly: *"a deploy fired from inside per-task postflight would race the
   fail-open `specs/.deploy-lock` mutex exactly as the Concurrency note above describes for the
   Inter-Cycle checkpoint — so the actual redeploy trigger is placed ONLY at the two already-
   serialized call sites."*

**Confirmed independently**: `SKILL.md`'s Move 2 (`### Move 2: Dispatch`, line 124) issues every
`dispatch[]`/`aux_dispatch[]` Agent call **in one message** — genuine, simultaneous parallel
dispatch, explicitly to avoid forcing sequential execution. Move 3 (`### Move 3: Postflight`,
line 162) runs "after ALL Agent calls from Move 2 complete (never interleaved with dispatch)"
and loops over `dispatch[]` rows **sequentially** in a single `while` loop — so no two tasks'
*postflights* race each other within one cycle, but a task's postflight-triggered redeploy could
still land while a *sibling* task's Move-2 agent session is mid-flight in the *next* cycle (the
dispatch's own "sibling tasks in the same wave may be mid-flight" framing is about cross-cycle,
not just same-cycle, overlap — an /orchestrate run typically has several tasks each spanning
several cycles).

**Where the Inter-Cycle Redeploy Checkpoint itself lives**: `orchestrate-cycle-plan.sh`, `## (k,
part 2) Inter-cycle redeploy checkpoint`, lines ~700-961 (the dispatch's own "around lines
700-810" cites the header comment block accurately). Key structure:
- Line 746-747: `cycle_modified_files_json=$(mt_get_json '.cycle_modified_files')`, guarded by
  `if [ "$cycle_modified_files_json" != "[]" ] ... && [ -f "$CRITICAL_PATHS_FILE" ]`.
- Lines 748-752: expands `orchestrator-critical-paths.json`'s `scope_roots` x `critical_paths`
  into `critical_expanded_json`, then computes `matched_json` = critical paths that overlap
  `cycle_modified_files` via `scopes_overlap_first` AND are not already in
  `deployed_critical_paths` (the idempotence guard). **This is the exact predicate the D6 note
  says needs widening** — it only matches the curated allowlist in
  `context/reference/orchestrator-critical-paths.json` (a short, explicit list — e.g.
  `skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`, `scripts/skill-base.sh`,
  `scripts/task-lock.sh`, `scripts/update-task-status.sh`, `scripts/orchestrate-batch-admit.sh`,
  `scripts/orchestrate-triage-classify.sh`, `scripts/reconcile-task-status.sh`, and more), not
  every file under `agent-system/extensions/**`. A `meta` task modifying some *other* file under
  the source store (very plausibly true for many `meta` tasks, and true for task 252 itself)
  would still not trip `matched_count -gt 0` even with `cycle_modified_files` fully populated —
  **Part 2 alone is necessary but may not be sufficient** to satisfy Acceptance #1/#2 for the
  general case; the checkpoint's predicate likely also needs the `deploy_pending_any` widening
  the code already partially supports (see next point).
- Lines 763-780: `deploy_pending_any` is **already computed** — it loops every task in the batch,
  reads each one's own `.return-meta.json` for `deploy_pending == true`
  (skill_postflight_update's own annotation from Part 1's missing-caller problem!), and if any
  task carries it, forces `deploy_ledger_decide`'s decision to `"run"` (bypassing the durable
  ledger's hash-based skip). **This machinery already exists and is already wired to the
  `deploy_pending` marker** — but it is consulted only *inside* the `if [ "$matched_count" -gt 0
  ]` branch, i.e. only after the narrower critical-path predicate has already matched. Widening
  the outer predicate (or adding `deploy_pending_any` as an independent OR-branch that reaches
  the ledger-decide/deploy body even when `matched_count` is 0) is the concrete, scoped code
  change the D6 note is pointing at.
- Line 959: `mt_set '.cycle_modified_files = []'` — unconditional reset for the next cycle,
  runs regardless of whether the checkpoint's inner body fired (the `if`/`else` at line ~936 is a
  full wrapper, not an early exit, specifically so "the trailing `cycle_modified_files` reset and
  `mt_save` below still run" per its own comment).

**Recommendation for the plan** (argued, not silent): given the codebase already documents this
exact residual and its prescribed fix, the strongest-evidenced Part 1 resolution is: capture and
correctly handle `skill_postflight_update`'s rc in `orchestrate-cycle-postflight.sh` (visibility
+ correct commit-message/verdict bookkeeping — no new redeploy trigger), fix Part 2's
accumulation, and widen the Inter-Cycle Redeploy Checkpoint's predicate in
`orchestrate-cycle-plan.sh` to also fire on `deploy_pending_any` independent of the narrow
critical-path match (or broaden `matched_json`'s own overlap test to
`agent-system/extensions/**` generally). This satisfies Acceptance #1 without adding a third
automated trigger site, requires no `regeneration-is-manual-only.md` carve-out count change
(the dispatch's own stated acceptable outcome), and should be called out explicitly in the plan
as the "argued conclusion" the dispatch requires — together with a short addition to
`context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight Completion-Deploy
Gate` subsection retiring the D6 "not fixed by this mechanism" framing (updating it to record
that task 252 closed it, and how) per Acceptance #3's documentation requirement. If the plan
instead prefers a literal port with a new lock, it should explicitly rebut this pre-existing
guidance rather than silently deviating from it.

### Part 2 — `cycle_modified_files` accumulation on a refused postflight

**Current code** (`orchestrate-cycle-postflight.sh`, WORK (j), lines 1136-1178):

```bash
if [ -z "$loop_guard_file" ]; then
  if is_live; then
    jq 'del(.plan_cache)' "$mt_state_file" > ...
    fresh_status=$(jq -r ... .status // "" ... "$STATE_FILE")
    jq --arg t "$task_number" --arg fs "${fresh_status:-}" '.current_statuses[$t] = $fs' ...
    if [ "$fresh_status" = "completed" ]; then ... completed_tasks ... fi
    if [ "$dispatch_status" = "failed" ] || [ "$dispatch_status" = "blocked" ] || \
       [ "$offschema_dispatch_status" = "true" ]; then ... failed_tasks ... fi
    # Accumulate modified_files into cycle_modified_files HERE (not re-read later) — the
    # scoped commit above may have already cleaned up ephemeral per-task files, and cleanup can
    # remove .return-meta.json before Stage MT-3 step 7's overlap computation would otherwise run.
    while IFS= read -r f; do
      [ -n "$f" ] && jq --arg f "$f" '.cycle_modified_files = ((.cycle_modified_files // []) + [$f] | unique)' \
        "$mt_state_file" > ... && mv ...
    done < <(jq -r '.modified_files[]? // empty' "${TASK_DIR}/.return-meta.json" 2>/dev/null)
    bash task-lock.sh release ...
  fi
fi
```

**Static-reading finding**: this block is gated only by `[ -z "$loop_guard_file" ]` (multi-task
engine) and `is_live` — not by `dispatch_status`, `verdict`, or `skill_postflight_update`'s rc.
The script has `set -uo pipefail` (confirmed via `grep -n '^set '`), **no `set -e`**, and
`skill_postflight_update` is called without `|| rc=$?` inside a plain `then` block, so its
non-zero return cannot itself abort the script under these shell options.
`git-commit-scoped.sh` (WORK (i), invoked just before WORK (j)) was checked for any
`.return-meta.json` deletion (`grep -n 'honest-index-rows\|rm -f\|\.return-meta'
git-commit-scoped.sh`) — it does not delete or move that file. No `rm` of any kind appears
anywhere in `orchestrate-cycle-postflight.sh` itself. On this reading, the accumulation loop
*should* run and read a still-present, still-populated `.return-meta.json` even when
`update-task-status.sh` refused the write.

**This does not contradict the dispatch's confirmed fact #4** so much as leave its precise
mechanism unresolved from static reading alone. Two non-exclusive candidate explanations worth
testing empirically before finalizing Part 2's fix:
1. **Cross-invocation loss.** Each fresh `/orchestrate` invocation starts a brand-new
   `.orchestrator-multi-state-sess_{id}.json` with `cycle_modified_files: []`
   (`orchestrate-cycle-plan.sh` initializes it fresh per session). If the refused cycle's own
   accumulation succeeded but the *same* `/orchestrate` invocation then exhausted its cycle
   budget or was otherwise stopped before a *subsequent* cycle-plan invocation consumed it, a
   later, separately-invoked `/orchestrate` (a genuinely new session) would start over with an
   empty accumulator — reproducing "cycle_modified_files was `[]`" when inspected, without any
   single-invocation control-flow bug at all. Evidence in favor: `specs/events.jsonl` shows
   multiple `session_stop` events for task 249 spanning 19:31 through 23:11 on the observed date,
   consistent with several separate invocations/resumptions rather than one continuous run; the
   final multi-state snapshot for that session (`sess_1790104446_f9923b`,
   `cycle_count: 4`, `cycle_modified_files: []`, `current_statuses.249: "completed"`) reflects
   the *post-manual-reconcile* end state, not the moment of the original refusal, so it cannot
   settle this by itself.
2. **A genuine intra-invocation gap not visible from this static read** — e.g. an interaction
   with the off-schema `*)` catch-all arm (line ~836) if the *second*, redundant re-dispatch
   (visible in the event trail 10 seconds after the first) produced malformed output (git log
   shows a `"task 249: orchestration dispatch off-schema"` commit from this exact incident),
   whose own `.return-meta.json` may legitimately have had no useful `modified_files` for *that*
   round even though the *first* round's accumulation had already run correctly.

**Recommendation**: implement the literal fix the dispatch names (ensure accumulation is not
skippable on a refused write — which, per the reading above, largely already holds structurally,
so this may reduce to a targeted regression test proving it) but do not treat that alone as
proven sufficient; add a small reproduction (a fixture-driven test in
`test-orchestrate-cycle-postflight.sh` that forces `update-task-status.sh`'s exit-6 branch and
asserts the multi-state file's `cycle_modified_files` is non-empty afterward, within a single
invocation) as the acceptance evidence for Acceptance #2 — "demonstrated end to end, not
asserted" applies here as much as to Acceptance #1. If that test passes against the *current*
code unmodified, the plan should say so explicitly rather than porting a redundant fix, and pivot
Part 2's actual work toward whichever of the two candidate mechanisms above the test reveals (most
likely: none needed intra-invocation, and the real fix is Part 1's checkpoint-predicate widening
consuming the value correctly once it's there).

### Part 3 — Documenting the replay path after an unwind

Confirmed gap. `docs/architecture/orchestrate-state-machine.md`'s `## Unwinding an Unconsumed
Dispatch` (lines 255-302) documents:
- What Move 1 mutates (six things: state.json preflight write, task lock, dispatch file,
  `dispatch_seq_counter`, `pending_dispatch`, multi-state file).
- `orchestrate-unwind-dispatch.sh <task_number> --session SID [--dry-run] [--commit]
  [--mt-state FILE]`'s refusal gate (5 conditions, all-must-hold).
- "By-hand only, never automatic" rationale (3 reasons).
- Explicit contrast with `reconcile-task-status.sh` ("that script demotes a task whose STATUS has
  gone stale relative to its own artifacts... `orchestrate-unwind-dispatch.sh` instead reverses
  one SPECIFIC prepared dispatch's own recorded mutations").

Nothing in this section, nor in `skills/skill-orchestrate/SKILL.md`'s pointer (lines 104-109,
inside the Move 1 section), says what to run *after* a successful unwind. The observed failure
mode — re-running `orchestrate-cycle-postflight.sh` directly opens a fresh dispatch window that
predates the existing (now-correct, already-consumed) handoff, producing `"ERROR: STALE HANDOFF"`
— is a structural consequence of the handoff-identity gate working as designed against a
timestamp the unwind never touches (an unwind restores `state.json`/lock/dispatch-file/dispatch
counter state, not `.orchestrator-handoff.json`'s own mtime relative to a *new* dispatch window).

`reconcile-task-status.sh` (header comment, lines 1-40+) is exactly the correct replay path per
its own documented purpose: *"Detects tasks stuck in in-flight states (researching, planning,
implementing, partial) when artifacts already exist on disk, then replays the missed postflight
to promote their status... summaries/*.md -> implement phase (implementing -> completed)."* This
is precisely the shape of an unwound-then-actually-complete task: state.json shows a non-terminal
status, but the summary artifact is already on disk from the (correctly unwound, but never
postflighted) prior work.

`orchestrate-unwind-dispatch.sh`'s own success path ends at its final line (399, `exit 0`) after
a single unconditional `echo "[orchestrate-unwind-dispatch] task $task_number unwound:
status/last_updated/session_id restored, ..."` (line 398) — a natural, low-risk place to append a
one-line printed hint naming `reconcile-task-status.sh <task_number> <session_id>` as the likely
next step, without growing this script into a behavioral change (per the dispatch's explicit
scope limit: "do not grow it into a behavioral change to the handoff-identity gate, which is
working as designed").

**Recommendation**: add a short subsection (or an appended paragraph) to
`docs/architecture/orchestrate-state-machine.md`'s "Unwinding an Unconsumed Dispatch" section
documenting: after a successful unwind, if the task's artifacts show work already completed
(e.g. a summary file exists), run `reconcile-task-status.sh <task_number> <session_id>` rather
than re-invoking `orchestrate-cycle-postflight.sh`/`/orchestrate` directly, since the latter opens
a fresh dispatch window the existing handoff will appear stale against. Mirror the pointer in
`skill-orchestrate/SKILL.md`'s Move 1 section. Add the one-line printed hint to
`orchestrate-unwind-dispatch.sh`'s success output.

## Codebase Patterns

- **Shared library, not duplicated logic**: `deploy-baseline-lib.sh` was created specifically
  because two call sites had drifted from re-implementing the same (a)/(b)/(c) algorithm; its own
  header explains this. Any new call site (or predicate widening) must consume this library, not
  add a third copy.
- **Fail-safe direction convention**: `deploy_baseline_unattributable_findings` is "deliberately
  fail-safe toward attributable" (never silently drops a finding it can't positively rule out);
  the D4 inconclusive-pass-through convention in the completion-deploy gate itself is likewise
  documented as "never the loud exit-5... since this backstop is UNCONDITIONAL." Any widened
  predicate in Part 1 should preserve this posture (prefer firing the checkpoint over silently
  not firing it).
- **`(a)/(b)/(c)` failure-contract vocabulary** recurs across `command-gate-out.sh`, the
  Inter-Cycle Redeploy Checkpoint, and the Postflight Completion-Deploy Gate doc — a single named
  contract the codebase is careful to keep referenced, not restated, everywhere it appears.
- **Idempotence guards**: `deployed_critical_paths` in the multi-state file prevents redeploying
  for the same critical path twice within one session; any predicate widening should extend
  (not bypass) this guard.
- **Printed-hint-not-behavior-change** pattern already used elsewhere for similarly scoped "tell
  the operator what to do next" additions (matches Part 3's own instruction to keep
  `orchestrate-unwind-dispatch.sh`'s change to "documentation plus at most a printed hint").

## Decisions

- Treat the dispatch's four "confirmed facts" as accurate for facts #1-#3 and the *symptom* half
  of fact #4 (cycle_modified_files was empty, checkpoint didn't fire); treat the *mechanism* half
  of fact #4 ("the refusal aborts before... the accumulation block") as a plausible hypothesis
  that the plan/implementation should verify with a targeted regression test rather than assume,
  per the Part 2 findings above.
- Surface the pre-existing D6 residual documentation as the primary evidence basis for Part 1's
  required "argued conclusion" on concurrency, since it independently and specifically names this
  exact scenario and prescribes a concrete fix (widen the Inter-Cycle Checkpoint's predicate)
  rather than a new trigger site.

## Risks & Mitigations

- **Risk**: implementing Part 1 as a literal, new `deploy-headless.sh` trigger inside
  `orchestrate-cycle-postflight.sh` would contradict `regeneration-is-manual-only.md`'s explicit
  "no other automated caller is sanctioned... a THIRD trigger site" language and would need its
  own new carve-out paragraph plus a new, from-scratch serialization mechanism (a lock most of
  the surrounding code already avoids by relying on Move 3's already-sequential per-cycle loop).
  **Mitigation**: prefer widening the existing checkpoint predicate (no new site, no count
  change to the "two" carve-out, no new lock needed — the checkpoint already runs at a point with
  no dispatch in flight).
- **Risk**: fixing Part 2's accumulation without also widening Part 1's checkpoint predicate
  would satisfy Acceptance #2 (`cycle_modified_files` non-empty) but not necessarily Acceptance #1
  (task reaches `completed` with no manual intervention), for any task whose modified files fall
  outside `orchestrator-critical-paths.json`'s curated list — which is the common case per the
  dispatch's own "BLAST RADIUS" framing. **Mitigation**: scope Part 1's predicate widening as
  in-scope work alongside Part 2, explicitly cross-referenced, rather than assuming Part 2 alone
  suffices.
- **Risk**: a regression test asserting the current WORK (j) block already runs unconditionally
  might reveal it does — making "fix cycle_modified_files accumulation" partly a no-op relative
  to the dispatch's literal framing. **Mitigation**: treat this as valuable negative evidence,
  not a reason to skip Part 2 — the plan should still add the regression test as permanent
  coverage (Acceptance #4 requires it), and reallocate any freed effort toward the Part 1
  predicate widening, which the evidence above suggests is the piece still actually missing.
- **Risk**: widening the checkpoint predicate too broadly (e.g., firing on any
  `agent-system/extensions/**` touch regardless of whether it is genuinely load-bearing) could
  increase redeploy frequency/cost. **Mitigation**: the existing durable ledger
  (`deploy_ledger_decide`, hash-based skip) and `deployed_critical_paths` idempotence guard
  already exist specifically to bound this; the widening should route through them, not bypass
  them.

## Context Extension Recommendations

- **Topic**: D6 residual closure. **Gap**: once task 252 lands, `batch-orchestration-
  guardrails.md`'s `### The Postflight Completion-Deploy Gate` subsection's "Residual — the
  `/orchestrate` path (D6, not fixed by this mechanism)" paragraph will be stale (it explicitly
  says "not attempted by this mechanism", "not attempted here" in two places).
  **Recommendation**: update that paragraph (and `regeneration-is-manual-only.md`'s mirrored
  "non-exception" paragraph if the resolution changes what it asserts) to record that task 252
  closed it, and how — this is also literally Acceptance #3's documentation requirement.

## Appendix

### Search queries / commands used
- `grep -n 'command-gate-out' orchestrate-cycle-postflight.sh` (confirms only a comment hit)
- `grep -n 'cycle_modified_files' orchestrate-cycle-postflight.sh orchestrate-cycle-plan.sh`
- `grep -n '^set ' orchestrate-cycle-postflight.sh skill-base.sh` (confirms no `set -e`)
- `grep -n 'skill_postflight_update' skill-base.sh orchestrate-cycle-postflight.sh`
- `grep -n 'deploy-pending\|refusing postflight\|stale relative to its source store'
  specs/events.jsonl`
- `jq '{cycle_modified_files, task_numbers, current_statuses, ...}'
  specs/.orchestrator-multi-state-sess_1790104446_f9923b.json` (task 249/245's session)
- `grep -n 'sanctioned\|carve-out' context/patterns/regeneration-is-manual-only.md`
- `sed -n '803,920p' context/patterns/batch-orchestration-guardrails.md`
- `cat context/reference/orchestrator-critical-paths.json`
- `grep -n 'pass "\|fail "' scripts/tests/test-postflight-deploy-gate.sh`
- `grep -n 'cycle_modified_files\|deploy_pending' scripts/tests/test-orchestrate-cycle-postflight.sh`
  (zero hits — confirms no existing coverage)

### Key file/line references
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`: `implemented)` arm
  ~763-788; WORK (i) scoped commit ~1073-1121; WORK (j) multi-state + accumulation 1136-1178;
  `set -uo pipefail` at line 132.
- `agent-system/extensions/core/scripts/skill-base.sh`: `skill_postflight_update()` 839-999,
  exit-6 annotation block ~962-976.
- `agent-system/extensions/core/scripts/command-gate-out.sh`: rc==6 handler ~153-211
  (single-retry comment at ~211).
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`: 165 lines, 4 exported
  functions at lines 90, 109, 118, 132.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`: Inter-Cycle Redeploy
  Checkpoint ~695-961; `deploy_pending_any` computation ~763-780; `cycle_modified_files` reset
  line 959.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`: two
  "Automated Exception" subsections ~78-170; non-exception paragraph ~134-142.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`:
  `### The Postflight Completion-Deploy Gate` 803-920, D6 residual ~887-905.
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`: curated
  critical-path allowlist.
- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh`: 399 lines, success
  message at line 398.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh`: promotion-table header
  comment lines 1-40+.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`: `## Unwinding
  an Unconsumed Dispatch` 255-302.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: Move 2 (parallel dispatch)
  line 124; Move 3 (sequential postflight loop) line 162; unwind pointer 104-109.
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh`: 390 lines,
  fixture-driven, `pass()`/`fail()`/`info()` pattern, source-store-first resolution for the two
  files under test.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`: 1509 lines,
  no existing `cycle_modified_files`/`deploy_pending` coverage.
