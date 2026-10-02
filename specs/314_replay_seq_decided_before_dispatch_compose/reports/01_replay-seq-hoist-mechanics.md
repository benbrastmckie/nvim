# Research Report: Task #314

**Task**: 314 - Make the unconsumed-dispatch replay decide its dispatch_seq BEFORE the seq is minted and before the dispatch file is composed
**Started**: 2026-10-02T00:00:00Z
**Completed**: 2026-10-02T00:00:00Z
**Effort**: medium
**Dependencies**: None (deliberately; see Batching Guidance in dispatch)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`, `scripts/tests/test-orchestrate-cycle-plan.sh`)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All line anchors cited in the dispatch's ROOT CAUSE / DELIVERABLE sections are confirmed
  against current source in the source store (`agent-system/extensions/core/scripts/`), with
  only cosmetic drift (e.g. mint block is at `:2541-2544` exactly as stated; `build_args` at
  `:2579`; `dispatch_file=` read-back at `:2649`; `orchestrate-build-dispatch.sh`'s
  `dispatch_file=` assignment at `:385` and `- dispatch_seq: ${dispatch_seq}` at `:400`; the
  hash-strip regex at `:2001`). Nothing here has moved since the dispatch was generated.
- The hoist (DELIVERABLE 1) is mechanically clean: both inputs the replay decision needs —
  `pending_dispatch_seed[$t]` (seeded at `:1237`, in an earlier loop) and `forced_this_cycle[$t]`
  (set at `:1697-1710`, also an earlier loop) — and `$g` (set at `:2507`, the very top of the
  per-task dispatch-building loop) are all available well before the lock acquire (`:2525`) and
  the mint (`:2541`). No ordering invariant in the section (i) comments is violated by hoisting;
  the forced-phase pop at `:2546-2548` reads `forced_this_cycle[$t]` but does not mutate it, so
  it has no dependency on, or interaction with, the replay decision.
- Recommended hoist shape: compute the decision (`_pd_replay`, `_pd_seq`, and the matched
  `_pd_phase`/`_pd_forced`/`_pd_dispatch_file` fields) ONCE, immediately before `:2541`, and
  branch the mint on it (replay: `task_dispatch_seq="$_pd_seq"`, no `mt_get counter+1`, no bump
  to `.dispatch_seq_counter`; non-replay: today's mint unchanged). The existing charging block
  at the original location (`:2766-2812`) keeps its current position (it needs `$dispatch_file`,
  which isn't known until `:2649`) but no longer recomputes the decision — it just branches on
  the already-computed `_pd_replay` flag. This reconciles DELIVERABLE 1 and 1b simultaneously:
  under a correct hoist, a replay never calls `mt_get counter+1` at all, so there is nothing to
  flush and nothing to leak — the durable/in-memory agreement holds by construction, exactly as
  DELIVERABLE 1b's closing paragraph asks for.
- DELIVERABLE 2's assertion belongs immediately after `dispatch_file=$(echo "$dispatch_json" |
  jq -r '.dispatch_file')` at `:2649-2650`, before Fix 2's identical-dispatch hash computation
  begins. It must parse the Identity block directly from the file (e.g. `grep -m1 '^- dispatch_seq:
  '`), never via `cycle_plan_dispatch_hash`, because that function's strip regex at `:2001`
  deliberately removes the `dispatch_seq`/`dispatch_start_ts` lines before hashing — using it
  for the consistency check would make the check vacuous by construction.
- DELIVERABLE 3's gap is real and precisely as described: Group 19 (`:2537` onward) stubs
  `orchestrate-build-dispatch.sh` with a two-line fake that emits `{dispatch_file: "/fake/...",
  model: ""}` — no `## Identity` block ever exists on disk for Group 19's cases, so no existing
  or trivially-added assertion there can read a composed file's `dispatch_seq` line without
  first changing what the stub writes.
- On the "currently-green assertion must be revised" instruction: the durable-guard-file
  assertion at `:2587` (`"the durable guard file's dispatch_seq_counter is unchanged by a
  replay"`) is checking the **durable** file, and that value (3 in the fixture) is unchanged by
  the replay both **before and after** the fix — `--flush-seq` is skipped on the replay branch
  in both the current code and the hoisted fix, so this specific assertion does not flip red→green
  and cannot by itself serve as DELIVERABLE 1b's demonstration. The actual leak lives in the
  **ephemeral in-memory** `mt_json.dispatch_seq_counter` (bumped to 4 by today's unconditional
  mint before the replay branch reverts only `.dispatch_seq[$t]`, never the counter) — a value
  the existing Group 19 case 1 never reads at all. See Decisions/Risks below for the argued
  revision this implies.

## Context & Scope

Research was scoped by the dispatch to: (a) re-verify the already-decided root cause and fix
shape against current source (not re-litigate it), (b) settle the mechanics of where exactly the
hoisted decision can sit and what else must move with it, (c) confirm the Group 19 test gap and
work out what the "argued revision" of the flagged assertion should actually say, since the
dispatch explicitly forbids silently weakening or deleting it. No alternative fix design was
considered (DELIVERABLE 1's option (a) is settled; the file-reuse alternative is explicitly
rejected in the dispatch on verified territory-staleness grounds, reconfirmed below).

## Findings

### Codebase Patterns

**Mint block, confirmed verbatim at the cited lines** (`orchestrate-cycle-plan.sh:2541-2544`):
```
task_dispatch_seq=$(mt_get '(.dispatch_seq_counter // 0) + 1')
task_dispatch_start_ts=$(date -u +%s)
mt_set --arg t "$t" --argjson ts "$task_dispatch_start_ts" --argjson seq "$task_dispatch_seq" \
  '.dispatch_start_ts[$t] = $ts | .dispatch_seq[$t] = $seq | .dispatch_seq_counter = $seq'
```
`.dispatch_seq_counter` is a single **global** scalar in the ephemeral per-run multi-state file
(`mt_json`) — not keyed per task — while the **durable** ledger
(`specs/{task}_.../.orchestrator-loop-guard`) is per-task. A replay's job is to make the global
mint either reuse a prior value (no new global consumption) or, when it does consume a new
global value, to durably record that against the task's own guard file via `--flush-seq`. The
dispatch's framing ("the minted seq IS the replayed seq") maps to: under a correct hoist, replay
never touches `mt_get counter+1` or `.dispatch_seq_counter` at all, so there is no new global
value to reconcile.

**Loop-entry order** (`:2506-2541`): `for t in "${probed_dispatch_post_h1[@]}"; do` at `:2506`,
`g="${effective_group[$t]}"` at `:2507` — i.e. phase is known at the very first line of the loop
body, far before the lock-acquire block at `:2525-2537` and the mint at `:2541`. Both
`pending_dispatch_seed[$t]` (populated at `:1237`, inside an earlier, separate `for t in
"${task_args[@]}"` loop keyed off the durable guard file's `--seed` output) and
`forced_this_cycle[$t]` (populated at `:1697-1710`, inside yet another earlier `for t in
"${eligible_tasks[@]}"` loop) are fully populated arrays by the time the dispatch-building loop
even starts. There is no scoping or ordering obstacle to reading either one as early as
immediately after `:2507`.

**Replay decision, confirmed verbatim at `:2764-2786`** (dispatch cited `:2771-2786`; the actual
`_pd_forced_this_cycle` assignment that feeds it starts two lines earlier at `:2769`):
```bash
_pd_forced_this_cycle="${forced_this_cycle[$t]:-false}"
_pd_replay=false
if [ -n "${pending_dispatch_seed[$t]:-}" ]; then
  _pd_phase=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.phase // ""')
  _pd_forced=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.forced // false')
  _pd_dispatch_file=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.dispatch_file // ""')
  if [ "$_pd_phase" = "$g" ] && [ "$_pd_forced" = "$_pd_forced_this_cycle" ] && \
     [ -n "$_pd_dispatch_file" ] && [ -f "$_pd_dispatch_file" ]; then
    _pd_replay=true
  fi
fi
if [ "$_pd_replay" = "true" ]; then
  _pd_seq=$(printf '%s' "${pending_dispatch_seed[$t]}" | jq -r '.seq')
  mt_set --arg t "$t" --argjson seq "$_pd_seq" '.dispatch_seq[$t] = $seq'
  task_dispatch_seq="$_pd_seq"
  ...
else
  ...
  bash "$SCRIPT_DIR/orchestrate-loop-guard-init.sh" --flush-seq "$task_dir_abs" "$task_dispatch_seq" >/dev/null 2>&1 || true
  ...
fi
```
Confirmed: `--flush-seq` is called **only** in the `else` (non-replay) branch — DELIVERABLE 1b's
claim that the replay branch "deliberately never calls `--flush-seq`" holds exactly as stated.
None of the inputs this block reads (`pending_dispatch_seed[$t]`, `forced_this_cycle[$t]`, `$g`)
depend on anything computed between `:2507` and `:2764` — specifically not on the lock acquire,
not on `task_dispatch_start_ts`, not on the forced-phase pop, and not on `skill_preflight_update`.
The only things this block currently also touches that genuinely cannot move early are the
charging side effects that need `$dispatch_file` (`--record-pending`'s JSON payload embeds `$df`)
— those stay where they are.

**`orchestrate-build-dispatch.sh` confirmed** at the cited lines: `dispatch_file=
"${dispatch_dir}/${dispatch_seq}.md"` at `:385`, and the Identity-block writer's `- dispatch_seq:
${dispatch_seq}` line at `:400`. Filenames are seq-derived exactly as DELIVERABLE 1b states, so a
re-minted value that collides with a previously-used-but-never-flushed seq silently overwrites
that orphaned file on disk.

**Hash-strip confirmed** at `:1997-2001` (`cycle_plan_dispatch_hash`): `grep -v -E '^- dispatch_seq:
[0-9]+$|^- dispatch_start_ts: [0-9]+$'` before `sha256sum`. DELIVERABLE 2's assertion must read
the field directly off the file (not via this helper), and must run as its own independent check
— it has no interaction with the hash guard either way, since it runs on the dispatch file
immediately after composition while the hash guard runs on the same file for an unrelated
purpose (churn detection); neither needs to know about the other.

**Group 19 test gap confirmed**: `scripts/tests/test-orchestrate-cycle-plan.sh:2537-2542` installs
```bash
cat > "$WORKDIR/.claude/scripts/orchestrate-build-dispatch.sh" <<'EOF'
#!/usr/bin/env bash
proj_num="$1"; phase="$2"
jq -n -c --arg f "/fake/${proj_num}-${phase}.md" '{dispatch_file: $f, model: ""}'
EOF
```
This stub never writes a file at `/fake/...md` at all (that path doesn't exist on disk) and the
JSON it emits has no Identity block to inspect even in principle. Every subsequent Group 19
assertion (`:2572-2687`) reads only `$g19_guard_file` (the durable `.orchestrator-loop-guard`)
and `$g19_mt_state_1`/`_2`/etc. (the ephemeral multi-state JSON) — confirmed by inspection, no
assertion anywhere in Group 19 greps a composed dispatch file's content. This is exactly the
blind spot the dispatch names: the one artifact whose Identity-block value is the thing an agent
and the postflight actually consume is never inspected.

**Two sibling assertions use near-identical wording but are not affected and need no change**:
- Group 18 (`:2471`, in-session **plan_cache** replay, a different mechanism entirely — it
  short-circuits composition before any mint happens at all when nothing was dispatched since
  the last identical composition within the same session; genuinely unaffected by this task's
  defect, confirmed by reading the plan_cache comment block at `:578-698`).
- Group 24 case 2 (`:3294`, end-to-end with the REAL `orchestrate-build-dispatch.sh` installed by
  Group 21) asserts the **durable** counter stays at 8 after a replay — also true both before and
  after the fix, for the same reason given below for Group 19 case 1's durable check. Group 24's
  focus is the `prior_*` pre-image fields, not the Identity-seq consistency this task targets, so
  it is out of this task's scope and should be left alone.

### External Resources

Not applicable — this is a pure codebase mechanics task with no external API/library surface.

## Decisions

- **Hoist boundary**: insert the replay decision (the `_pd_replay`/`_pd_seq`/`_pd_phase`/
  `_pd_forced`/`_pd_dispatch_file` computation, currently at `:2764-2776`) immediately before the
  mint comment at `:2541`, i.e. after the lock-acquire block closes (`:2537`) and before section
  (i). Do not hoist it earlier than the lock acquire; there is no need to, and lock-acquire
  failures already `continue` the loop before reaching either point, so placing the decision
  after the acquire costs nothing and keeps the diff minimal.
- **Mint becomes branch-conditional**: on `_pd_replay=true`, set `task_dispatch_seq="$_pd_seq"`
  and write only `.dispatch_start_ts[$t] = $ts | .dispatch_seq[$t] = $seq` (reusing `$_pd_seq`),
  explicitly WITHOUT touching `.dispatch_seq_counter`. On `_pd_replay=false`, keep today's three-
  field mint exactly as-is. This is what makes DELIVERABLE 1b's "agree by construction" claim
  literally true: no `mt_get counter+1` call ever executes on the replay path, so there is no
  minted-but-discarded value to leak.
- **Charging block (`:2766-2812`) keeps its current position** but stops recomputing the
  decision — it reads the already-computed `_pd_replay` (and, on the replay branch, the
  already-known `$_pd_seq` for its log line) rather than re-deriving them. This is necessary
  because `--record-pending`'s JSON payload needs `$dispatch_file`, only known after the compose
  call at `:2639/2649`, which itself must run with the already-decided (hoisted) seq.
- **DELIVERABLE 2 assertion placement**: immediately after `:2650` (`dispatch_model_json`
  assignment), before the Fix 2 hash block begins (`:2653` onward). Parse via
  `grep -m1 '^- dispatch_seq: ' "$dispatch_file" | sed 's/^- dispatch_seq: //'` (or equivalent),
  compare against the in-memory `$task_dispatch_seq` bash variable (not a fresh `mt_get` — by
  this point in the hoisted design `$task_dispatch_seq` and `mt_json.dispatch_seq[$t]` are
  already identical, so comparing against the bash variable is sufficient and avoids a redundant
  read). On mismatch: push to `out_deferred_rows` with an explicit reason string and `continue`,
  matching the existing idiom used for the `build_exit -ne 0` case three lines above it
  (`:2645-2648`).
- **Group 19 case 1's existing durable-counter assertion (`:2587`) should be KEPT, not deleted**,
  because it remains a true and relevant fact post-fix (the durable file genuinely stays
  unchanged on a replay, by design — `--flush-seq` is correctly never called when nothing new was
  minted). What needs to change is the *comment/reasoning accompanying it* plus a **new,
  additional** assertion next to it that reads the **ephemeral** `mt_json.dispatch_seq_counter`
  (via `$g19_mt_state_1`, already in scope at that point in the test) and asserts it is also
  unchanged at 3 — not bumped to 4. That additional assertion is the one that actually
  demonstrates the fix: it reads 4 against current (unfixed) source and 3 after the hoist.
  The accompanying comment should say, in substance: *the durable-file check alone is necessary
  but not sufficient — it was already true under the pre-fix code (because `--flush-seq` really
  is skipped on replay in both versions), so on its own it gave false assurance that the replay
  path was correctly handled, while the actual leak was invisible to it because it lived in the
  ephemeral in-memory counter that later feeds both the composed dispatch file and the next
  invocation's re-seed.* This is the "argued correction" DELIVERABLE 3 and ACCEPTANCE #7 require:
  the prior assertion is not false, but its framing ("no extra --flush-seq" ⇒ "correctly
  handled") is corrected to "necessary but insufficient," with the sufficiency gap closed by the
  new in-memory-counter assertion plus the Identity-block assertion below.
- **Group 19's stub must change to make the Identity-block check possible.** The two-line fake in
  `orchestrate-build-dispatch.sh`'s stub (`:2538-2541`) needs to actually write a file containing
  a `## Identity` section with a real `- dispatch_seq: ${3:-N}` line reflecting whatever seq was
  passed to it as an argument (the real script receives `--seq N` in `build_args`; the stub would
  need to accept and echo it back into the written file, the same way the REAL script does at
  `:400`), rather than emitting an opaque `/fake/...md` path that is never created. This is the
  minimal change that lets a new Group 19 assertion `grep` the composed file's Identity block
  instead of only the state files.

## Recommendations

1. Implement the hoist exactly as scoped in Decisions above: decision block moves to just before
   `:2541`; mint becomes a two-way branch; downstream charging block unchanged in position, just
   stops recomputing.
2. Implement the DELIVERABLE 2 post-compose assertion at the exact insertion point identified
   above, using a direct `grep` of the Identity line (never the hash helper), comparing against
   the in-memory `task_dispatch_seq` variable.
3. Extend Group 19 case 1 with exactly two additions: (a) make the stub emit a real Identity
   block so the composed file can be inspected, and assert the composed file's `dispatch_seq`
   line equals `task_dispatch_seq`/`dispatch_seq[1901]`; (b) add the new ephemeral-counter
   assertion (`mt_json.dispatch_seq_counter` from `$g19_mt_state_1` stays at 3) alongside a
   revised comment on the existing durable-counter assertion explaining the necessary-but-
   insufficient framing, per the argued-correction requirement.
4. Treat the "handoff's seq check" and "`.return-meta.json`'s seq check" fourth/fifth legs named
   in ACCEPTANCE #1 and in DELIVERABLE 3's "ALL FOUR agree" instruction as requiring a plan-time
   decision (flagged below under Risks) rather than resolving it unilaterally here: those two
   checks are postflight-side behavior that task 315 owns separately per this dispatch's own
   "share no files with this task" statement, and `test-orchestrate-cycle-plan.sh` has no
   existing machinery that invokes or fixtures `orchestrate-cycle-postflight.sh`, handoffs, or
   `.return-meta.json`. The plan should decide between: (a) Group 19 extends only the two
   plan-side legs (dispatch file Identity + `mt_json.dispatch_seq[$t]`) and the report/test
   comment explicitly cross-references task 315 for the other two legs, or (b) Group 19
   additionally fabricates minimal handoff/`.return-meta.json` fixtures and replicates (inline,
   without touching postflight.sh itself) the same seq-equality comparison postflight performs,
   to literally demonstrate all four agree within this task's own file_scope.
5. Do not touch Group 18 or Group 24 — both were confirmed unaffected and already correct.

## Risks & Mitigations

- **Scope ambiguity on "ALL FOUR agree" (ACCEPTANCE #1 / DELIVERABLE 3).** Two of the four legs
  (handoff, `.return-meta.json`) are mechanically postflight-side and this task's own file_scope
  does not include `orchestrate-cycle-postflight.sh` or its tests (that's task 315's territory,
  confirmed in the Territory block). Mitigation: the plan phase must explicitly pick option (a)
  or (b) from Recommendation 4 above before implementation starts, rather than discovering the
  ambiguity mid-implementation. Recorded here so the planner does not need to re-derive it.
- **Vacuous-pass risk on the new assertions (ACCEPTANCE #6).** Because the stub change
  (Decision/Recommendation 3a) is new test-fixture code, it is possible to write a stub that
  always echoes back whatever seq it's told to use, which would make the new Identity-check
  assertion pass trivially regardless of whether the hoist is correct, UNLESS the test is run
  against **current, unfixed source** first and observed to fail (mismatch: file says 4, state
  says 3) before the fix lands. Mitigation: implementation must run the extended Group 19 against
  unfixed source and confirm a genuine FAIL (not an error/skip) before applying the hoist, exactly
  as ACCEPTANCE #6 demands ("demonstrated, not asserted").
- **Shellcheck/strict-mode compliance** (`context/standards/shell-strict-mode.md`,
  ACCEPTANCE #8) — both files already pass today; the diff is additive (new variables, a new
  conditional branch, a new grep-based check) and should introduce no new unquoted expansions or
  unset-variable risks if the existing file's own quoting conventions (visible throughout the
  excerpts above — `"${forced_this_cycle[$t]:-false}"`, `--arg`/`--argjson` for all jq interop)
  are followed mechanically.

## Context Extension Recommendations

- **Topic**: the global-vs-per-task scope of `dispatch_seq_counter`.
- **Gap**: no existing context file documents that `mt_json.dispatch_seq_counter` is a single
  global scalar shared across all tasks in one `/orchestrate` run, while its durable persistence
  (`.orchestrator-loop-guard`'s `dispatch_seq_counter` field) is per-task. This distinction is
  load-bearing for understanding the counter-leak mechanics in DELIVERABLE 1b and was not
  immediately obvious from the dispatch text alone — it had to be reconstructed from the `mt_get`/
  `mt_set` call shapes (no `--arg t` on the counter itself vs. `--arg t "$t"` on `dispatch_seq[$t]`).
- **Recommendation**: a short addition to whatever existing doc covers the multi-state ledger
  (likely near `context/patterns/...` or inline in `orchestrate-cycle-plan.sh`'s own header
  comment, which already documents the field list at `:50`) noting this global/per-task split
  explicitly, so a future reader doesn't have to re-derive it from the jq argument shapes.

## Appendix

- Searches: `grep -n` for `dispatch_seq_counter`, `task_dispatch_seq`, `pending_dispatch_seed\[`,
  `forced_this_cycle\[`, `cycle_plan_dispatch_hash()`, `Group 19`/`Group 18`/`Group 24` markers,
  and `dispatch_file=` across `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`, and
  `scripts/tests/test-orchestrate-cycle-plan.sh`, all within
  `agent-system/extensions/core/scripts/` (the source store; `.claude/scripts/` is the disposable
  deploy copy and was not edited or treated as authoritative, per
  `context/standards/source-store-deploy-boundary-narrative.md`).
- Files read: `orchestrate-cycle-plan.sh` (targeted ranges: 1160-1240, 1690-1720, 1975-2010,
  2500-2700, 2740-2833), `orchestrate-build-dispatch.sh` (380-410),
  `scripts/tests/test-orchestrate-cycle-plan.sh` (2400-2480, 2528-2605, 3190-3300).

## Argued correction, as implemented

Recorded at Phase 5, after implementation, per ACCEPTANCE #7 and the D1/D2 rulings this report
settled at plan time. This section states the FINAL wording as it actually landed in
`scripts/tests/test-orchestrate-cycle-plan.sh`'s Group 19 case 1, so the report and the test
comment agree.

**D1 rulings, confirmed as implemented.** Option (b)-minimal landed exactly as settled: Leg 1
(composed dispatch file's Identity `dispatch_seq`) and Leg 2 (`mt_json.dispatch_seq[1901]`) are
direct assertions; Leg 3 fabricates `.return-meta.json` with its `dispatch_seq` read FROM the
composed file (not the state file) and invokes the real, unmodified
`orchestrate-recover-outcome.sh`; Leg 4 replicates `orchestrate-cycle-postflight.sh`'s own
handoff-seq equality predicate inline over a fabricated handoff seq likewise read from the
composed file. All four legs now sit together in Group 19 case 1, with an explicit comment
explaining why the group reads the composed file at all (every prior assertion in it read only
state files, which is exactly why a file-vs-state disagreement shipped green).

**D2 ruling, confirmed as implemented.** The comment beside Leg 3 records that Legs 3/4 stand in
for a literal `state.json` transition because `update-task-status.sh` is stubbed to a bare
`exit 0` in this suite, and that `recovered=true` is the mechanical precondition
`orchestrate-cycle-postflight.sh` gates its own transition attempt on (`have_outcome=false`
otherwise attempts none).

**The flagged durable-counter assertion, argued as a correction rather than silently
relaxed.** The pre-existing assertion ("the durable guard file's dispatch_seq_counter is
unchanged by a replay (no extra `--flush-seq`)") is KEPT, not deleted or weakened — it remains
TRUE both before and after the fix, because `--flush-seq` really is skipped on a replay in both
versions. Its comment was revised to state explicitly that this truth is NECESSARY BUT NOT
SUFFICIENT: on its own it gave false assurance that the replay path's seq bookkeeping was sound,
when the actual leak (DELIVERABLE 1b) lived in the EPHEMERAL in-memory
`mt_json.dispatch_seq_counter` — bumped by this task's root-cause defect's unconditional
mint-then-discard, and read by neither this nor any prior Group 19 assertion. The new
ephemeral-counter assertion added in Phase 1 (`mt_json.dispatch_seq_counter` stays at 3, not 4,
after a replay) closes that sufficiency gap.

**One correction to this report's own Finding 3, discovered during Phase 2 implementation (not
a D1/D2 ruling, but recorded here for completeness).** This report's Finding 3 identified the
counter leak as living in the ephemeral counter, not the durable file — correct, and confirmed
by the implementation. What this report did NOT anticipate is that the plan's own literal
instruction to "move [the replay predicate] verbatim; do not restructure the predicate" was
insufficient: hoisting the decision ahead of Fix 2's identical-dispatch halt check (an ordering
change the hoist unavoidably makes) exposed a genuine collision between the replay-reuse
mechanism and Fix 2's own within-run streak guard, verified with a standalone repro harness
against Group 28. The implemented predicate adds one necessary guard condition — a durable
replay is honored only when `mt_json.last_dispatch_hash[$t]` is empty, i.e. this session has not
already dispatched this task this run — restoring the in-session/cross-invocation boundary the
code's own pre-existing header comments already drew in intent. See the plan's Phase 2 deviation
note and `scripts/orchestrate-cycle-plan.sh`'s own comment at the hoisted decision block for the
full reasoning. A second, narrower discovery in Phase 3 (the test suite's pre-existing
`/fake/...` stub convention being incompatible with DELIVERABLE 2's file-content read, and two
further test-assertion corrections it required in Group 18 and the budget group) is recorded in
the plan's Phase 3 deviation note rather than duplicated here.
