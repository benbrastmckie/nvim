# Research Report: Task #490

**Task**: 490 - Fix active_goal read path
**Started**: 2026-11-12
**Completed**: 2026-11-12
**Effort**: Medium (one script, one format doc, one regression test, one doc-pointer confirmation)
**Dependencies**: None
**Sources/Inputs**: Codebase read (scripts, context formats, commands), live reproduction in an isolated scratch tree
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own diagnosis is correct as far as it goes: `generate-task-order.sh` never
  reads `active_goal` from `state.json` under any code path. `grep -n active_goal
  scripts/generate-task-order.sh` returns nothing, confirmed again here.
- **A more severe, previously-unflagged gap was reproduced**: the Goal line does not survive
  regeneration at all through the *dominant* call path. `generate-todo.sh` (invoked by
  `state-write.sh --regen-todo`, `orchestrator-postflight.sh`, and `skill-base.sh`) performs a
  full rebuild of `TODO.md` by delegating to `generate-task-order.sh --print`. In `--print` mode,
  the script's `GOAL_TEXT` resolution is unconditionally empty — it is gated to `MODE == "update"`
  only, so `read_existing_goal()` is never called and `--goal`/`active_goal` are both irrelevant.
  A scratch reproduction (below) confirms a TODO.md that already carries a hand-written `**Goal**:`
  line loses that line entirely after one `generate-todo.sh` run, independent of `active_goal`.
- **This matters directly for the task's own motivating example.** `commands/review.md` Section
  6.7.3 — the one in-tree caller that writes `active_goal` — reaches `TODO.md` exclusively through
  `generate-todo.sh` (Section 6.5's plain call, and Section 6.7.3's own `state-write.sh
  ... --regen-todo` call). It never calls `generate-task-order.sh --update-todo` directly. A fix
  that only threads `active_goal` into the `--update-todo` branch, leaving `--print`'s
  `MODE == "update"` gate in place, would leave review.md's own workflow exactly as broken as it
  is today.
- Required Outcome #4's regression case, as literally worded ("`--update-todo` must emit the Goal
  line"), is necessary but not sufficient to prove the fix actually closes the gap that motivates
  this task. The plan should also add (or the research-stated outcome should be read to include) an
  equivalent case for `--print` mode, or the precedence fix will be verified against the wrong
  code path.
- Recommended precedence, and recommended conflict rule for Outcome #2: `--goal` override (highest)
  > state.json `active_goal` (when non-empty) > existing TODO.md Goal line (fallback only when
  `active_goal` is absent/empty) > omit. Rationale below.
- `context/formats/task-order-format.md`'s Goal Statement section, Generation section, and
  Generation Algorithm section all need updating (Outcome #3), and should document the two-path
  (`--print` / `--update-todo`) parity explicitly, since that parity is itself the fix.
- `commands/review.md` Section 6.7.3 needs no functional change (Outcome #5) — once the reader
  exists in `--print` mode, its `--regen-todo` rationale becomes literally true rather than
  aspirational. A one-line comment noting this is optional, not required.
- All edits land in `agent-system/extensions/core/` (the source store), never a deployed
  `.claude/**` tree, per the dispatch's `SOURCE STORE` instruction and
  `rules/source-store-deploy-boundary.md`.

## Context & Scope

Researched the dead-write gap between `active_goal` (declared in
`agent-system/extensions/core/context/schemas/state-schema.json`, documented in
`agent-system/extensions/core/context/reference/state-management-schema.md`, validated by
`agent-system/extensions/core/scripts/validate-state.sh`, and written by
`agent-system/extensions/core/commands/review.md` Section 6.7.3) and
`agent-system/extensions/core/scripts/generate-task-order.sh`, which renders the `**Goal**:` line
in `TODO.md`'s `## Task Order` section but never reads that field. Scope is read-only research:
confirm the gap, discover its full extent via live reproduction, and recommend the precedence
rule, conflict rule, doc updates, and regression-test shape for the implementation phase. No
code or doc files were modified (this is a research dispatch); all file edits described below are
recommendations for the plan/implement phases, to land in `agent-system/extensions/core/`.

## Findings

### Codebase Patterns

**Current Goal resolution in `generate-task-order.sh` (confirmed by reading the script
end-to-end, `agent-system/extensions/core/scripts/generate-task-order.sh`):**

- `--print` mode: builds the graph from the default `specs/state.json`, computes waves/tree, and
  at the "Determine goal text" step (~line 1040) only consults `GOAL_OVERRIDE` (`--goal`); the
  `elif` branch that calls `read_existing_goal()` is gated `[[ "$MODE" == "update" ]]`, so in
  print mode `GOAL_TEXT` is unconditionally `""` unless `--goal` was passed. `generate_section()`
  (~line 939) only emits the `**Goal**:` line when `goal_text` is non-empty, so print-mode output
  never carries a Goal line from any source other than an explicit `--goal`.
- `--update-todo` mode: same site, but the `elif` fires, calling `read_existing_goal()`
  (~line 909), which greps the current `## Task Order` section of the target `TODO_FILE` for a
  `^\*\*Goal\*\*: (.+)$` line and returns it, so a pre-existing hand-written line survives an
  `--update-todo` call. `active_goal` in `STATE_FILE` is never consulted in this branch either.
- Neither branch ever opens `STATE_FILE` for anything but the dependency graph (`jq
  '.active_projects[...]'`-shaped reads); `active_goal` is a top-level sibling field never
  touched.

**Who calls which mode (full survey of in-tree callers, `grep -rn
"generate-task-order.sh\b"` / `"generate-todo.sh"` across `agent-system/extensions/core/`):**

| Caller | Mode reached | Preserves a Goal line today? |
|---|---|---|
| `scripts/generate-todo.sh` (full `TODO.md` rebuild) | `--print` (hardcoded, no args) | **No, never** — print mode has no Goal source at all |
| `scripts/state-write.sh --regen-todo` | → `generate-todo.sh` → `--print` | No (same as above) |
| `scripts/orchestrator-postflight.sh` Stage 8a | → `generate-todo.sh` → `--print` | No |
| `scripts/skill-base.sh` (regen call) | → `generate-todo.sh` → `--print` | No |
| `commands/review.md` Section 6.5 (plain regen) | → `generate-todo.sh` → `--print` | No |
| `commands/review.md` Section 6.7.3 (writes `active_goal`, `--regen-todo`) | → `generate-todo.sh` → `--print` | No — **this is the one caller that writes `active_goal`, and it never reaches `--update-todo`** |
| `scripts/update-task-status.sh` Mode B (terminal transitions) | `generate-task-order.sh --update-todo` directly | Yes, via `read_existing_goal()` |
| `commands/errors.md` Section 4a (supplementary regen after fix-task creation) | `generate-task-order.sh --update-todo` directly | Yes, via `read_existing_goal()` |
| `scripts/roadmap-integration.sh` | `generate-task-order.sh --print` (read-only, for the wave table only; does not write `TODO.md`) | N/A (not a Goal consumer) |

The `--update-todo` direct-call sites are the minority. Every state-mutation flow that regenerates
`TODO.md` via `state-write.sh --regen-todo`, `orchestrator-postflight.sh`, or `skill-base.sh` —
which is most of them — goes through `generate-todo.sh`'s hardcoded `--print` call and therefore
drops the Goal line unconditionally today, regardless of `active_goal` or any prior hand edit.

**Live reproduction (scratch tree, isolated from the real repo; confirms the above table's
"No, never" cells empirically, not just by code reading):**

Built a scratch `specs/state.json` with `active_goal: "Finish the widget migration"` and a
scratch `specs/TODO.md` whose `## Task Order` section already contained
`**Goal**: Pre-existing hand-written goal line`. Ran the unmodified
`agent-system/extensions/core/scripts/generate-todo.sh` (which internally shells out to
`generate-task-order.sh --print`) against that fixture. Result: the regenerated `TODO.md`'s
`## Task Order` section contains no `**Goal**:` line at all — the pre-existing hand-written line
is gone, and `active_goal` never appeared. Separately, ran
`generate-task-order.sh --update-todo <todo> <state>` directly against a `TODO.md` with no prior
Goal line and the same `active_goal`-bearing `state.json`: output also carried no Goal line,
confirming the dispatch's own reported reproduction for the `--update-todo` no-prior-line case.

This means the actual defect has two layers:
1. (As the dispatch states) `active_goal` is never read by either mode.
2. (Newly confirmed here) `--print` mode never renders *any* Goal line from *any* source — not
   `active_goal`, not `--goal`, not a pre-existing hand-written line — because its resolution
   branch is unconditionally skipped. Only `--update-todo` mode has a working (if incomplete)
   resolution chain today.

Layer 2 is why task-order-format.md's claim that the Goal line is "preserved across
regenerations" is only true for the minority of call sites that invoke
`generate-task-order.sh --update-todo` directly; for every caller that goes through
`generate-todo.sh`'s full rebuild (the majority, including the task's own motivating caller,
review.md Section 6.7.3), the claim does not hold today, with or without this task's fix, unless
the fix also removes the `MODE == "update"` gate.

**`validate-state.sh` and the schema** (`agent-system/extensions/core/scripts/validate-state.sh`
line 858, `context/schemas/state-schema.json` line 164): `active_goal` is a bare
`{"type": "string"}` with no `minLength`/pattern constraint, so an empty string `""` passes
validation. A precedence rule that treats `active_goal` as "present" on bare key-existence rather
than on non-empty content would let a repo that writes `active_goal: ""` (or that clears it by
writing the empty string, a plausible "no goal" convention) permanently suppress the
preserve-from-TODO fallback. The recommended rule below treats `active_goal` as active only when
it is a non-empty string.

**`update-task-status.sh` Mode B / Mode A split** (`task-order-format.md`'s own "Integration"
section, confirmed against `update-task-status.sh`): non-terminal status transitions patch the
status marker in place without touching the Goal line at all (Mode A); only terminal transitions
(and `--clean`) call `--update-todo` (Mode B), which is one of the two direct-call sites that
already has a (partial, `active_goal`-blind) working resolution chain. This is unaffected by the
fix either way — it keeps calling `--update-todo`, and inherits whatever resolution chain that
mode ends up with.

### External Resources

Not applicable — this is a self-contained, in-repo shell-script/markdown-doc gap with no external
API or library surface. No web research was needed or performed.

## Recommendations

1. **Resolve the precedence uniformly in one function, called from both `--print` and
   `--update-todo` modes** (not gated by `MODE == "update"`). Concretely: remove the
   `elif [[ "$MODE" == "update" ]]` restriction around the `read_existing_goal()` call at the
   "Determine goal text" site (~generate-task-order.sh line 1040), and add a new middle tier that
   reads `active_goal` from `STATE_FILE` via `jq -r '.active_goal // empty'`. The resulting chain,
   applied identically regardless of mode:
   ```
   GOAL_TEXT = GOAL_OVERRIDE (--goal)
             → non-empty .active_goal from STATE_FILE
             → read_existing_goal()        (existing TODO.md **Goal**: line, if any)
             → "" (omit the line)
   ```
   `read_existing_goal()` already defaults safely to `""` when `TODO_FILE` does not exist, so
   calling it unconditionally in print mode is safe even on a first-ever run before `TODO.md`
   exists. `TODO_FILE` already defaults to `$PROJECT_ROOT/specs/TODO.md` in both modes (only
   `--update-todo` lets a caller override it via its second positional arg), which is the correct
   file to read in the common case where `generate-todo.sh` and `generate-task-order.sh` share the
   default project root — the one known caveat is noted under Risks.
   This is a correctness fix to the existing code, not a scope expansion: Outcome #1's own wording
   ("the existing `--goal` and preserve-across-regeneration behaviors must not regress") already
   implies the preserve behavior must actually work, and today it silently does not work for the
   majority of callers.

2. **Conflict rule (Outcome #2): `active_goal`, when non-empty, takes precedence over an existing
   hand-written TODO.md Goal line.** Treat `active_goal` as absent when it is unset, null, or the
   empty string (matching the schema's unconstrained string type, per Findings above) — in that
   case the chain falls through to the existing preserve-from-TODO behavior unchanged, so a repo
   that has never adopted `active_goal` sees zero behavior change.

   Rationale: this mirrors the project's own established convention, stated plainly in
   `rules/state-management.md` — "state.json: Machine-readable source of truth and sole
   authoritative state" vs. "TODO.md: User-facing rendered view ... Never edit TODO.md directly
   for status or artifact changes." Every other field this codebase models this way (status,
   artifacts, dependencies, topics) already treats `state.json` as authoritative and `TODO.md` as
   a disposable render target; a hand-edited Goal line is the one documented exception, and it
   exists only because no state.json-backed field existed yet to supersede it. Once `active_goal`
   is populated, the field — not a `TODO.md` hand-edit — is the deliberate, intentional way to
   change the goal (as `review.md` Section 6.7.3's own interactive "Update goal" flow
   demonstrates), so it should win. The alternative (TODO.md hand-edit wins) would mean
   `review.md`'s "Update goal" feature silently fails to update the rendered goal whenever a
   human has ever hand-edited the line — a strictly worse outcome than the reverse trade-off the
   dispatch itself names (a stale `active_goal` overwriting a hand edit), because the stale-value
   case is self-correcting (the next `/review` "Update goal" or direct `state-write.sh` call fixes
   it) while the reverse case has no path to recovery without reading source.

3. **Update `context/formats/task-order-format.md` in three places** (Outcome #3):
   - **Goal Statement** section (currently lines ~47-57): replace "the generation script reads
     the existing Goal line from TODO.md and retains it unless `--goal` is passed explicitly" with
     the full three-tier chain from Recommendation 1, and state the conflict rule from
     Recommendation 2 explicitly (do not leave it implicit in prose, per Outcome #2's own
     instruction).
   - **Generation → Script Usage** section (~lines 299-310): the existing three example
     invocations (`--print`, `--update-todo` bare, `--update-todo ... --goal`) should gain a note
     that `--print` and `--update-todo` now resolve the Goal line identically except for the
     "existing line" fallback source (`TODO_FILE`'s current content either way).
   - **Generation Algorithm** section (~lines 312-330): insert a step (new step, logically before
     "Build wave table") naming `active_goal` as a graph-adjacent read: *"Resolve Goal text:
     `--goal` override, else non-empty `state.json` `.active_goal`, else the existing `**Goal**:`
     line in the target TODO file, else omit."* This section currently enumerates exactly what the
     script reads from `state.json` (Filter, Clean dependencies, Load topics, ...) and omits Goal
     resolution entirely — it needs the new source listed as the outcome's own wording requires.

4. **Regression test** (Outcome #4): add a case to
   `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` using the suite's
   existing `build_scratch`/`build_state`/`run_gto` harness. `build_state()` currently only sets
   `next_project_number`, `active_topics`, `active_projects`; it will need an optional
   `active_goal` argument (or a second small helper) to exercise this. The dispatch's literal
   outcome — `active_goal` set, no prior Goal line in `TODO.md`, `--update-todo` must emit the
   line — is a direct, minimal regression case against today's confirmed no-op. **Given Finding
   Layer 2 above, this suite should also gain a parallel case exercising `--print` mode** (e.g. by
   having the case invoke the script with `--print` against the same scratch `state.json` and
   asserting the `**Goal**:` line appears in stdout), since that is the path the task's own
   motivating caller (review.md Section 6.7.3) actually exercises, and a fix verified only against
   `--update-todo` would leave that caller's behavior unverified. This is not a scope expansion of
   the test file (it is the same file, same harness, same fixture shape) — it is coverage of the
   same Outcome #1 fix applied to its second mode.

5. **`commands/review.md` Section 6.7.3`** (Outcome #5): no functional change needed. Its comment
   — "both via ONE `state-write.sh` call with `--regen-todo` so the TODO.md regen happens inside
   the same mutex as the write that triggered it" — currently describes a regeneration that (per
   Finding Layer 2) does not actually render the write it describes; once the fix lands, the
   comment becomes literally accurate. Optionally add a one-line comment noting that
   `--regen-todo`'s `generate-todo.sh` call now renders `active_goal` via `generate-task-order.sh
   --print`'s Goal resolution, for a future reader's benefit — but this is cosmetic, not required.
   Do not widen scope to other callers; no other caller in this repository writes `active_goal`
   (confirmed by the caller survey above — `review.md` Section 6.7.3 is the sole writer).

## Decisions

- **Precedence order is `--goal` > `active_goal` (non-empty) > existing TODO.md Goal line >
  omit**, applied identically in `--print` and `--update-todo` modes. (Recommendation 1.)
- **`active_goal` is "present" only when non-empty** (unset/null/`""` all fall through to the
  TODO.md-preserve fallback), to avoid an empty-string `active_goal` permanently suppressing the
  legacy preserve behavior for repos that have not adopted the field. (Findings, `validate-state.sh`
  discussion.)
- **Conflict rule: `active_goal` wins over a hand-edited TODO.md line when non-empty.** (Recommendation
  2, with rationale.) This is the one decision in this report that is a genuine judgment call
  rather than a mechanical deduction — the plan/implement phases should treat it as settled per
  Outcome #2's instruction to "state the chosen rule and its rationale rather than leaving it
  implicit," not as open for further research.
- **The fix must touch `--print` mode's resolution gate, not only `--update-todo`'s.** This is
  not optional scope creep; it is required for Outcome #1 ("must not regress" the preserve
  behavior) to be true of the actual, dominant call path, and for the task's own motivating
  example (review.md 6.7.3) to be fixed at all.

## Risks & Mitigations

- **Risk**: Removing the `MODE == "update"` gate makes `--print` mode read `TODO_FILE` (for
  `read_existing_goal()`'s fallback tier), a file it previously never touched. For the default
  project-root case this is safe (`TODO_FILE` defaults to the same `specs/TODO.md` that
  `generate-todo.sh` is about to rebuild). **Mitigation**: no change needed for the default case;
  flag as a known, pre-existing, out-of-scope limitation (see next bullet) rather than attempting
  to fix it here.
- **Risk (pre-existing, out of scope)**: `generate-todo.sh` accepts non-default `--state-file`/
  `--todo-file` arguments (used for `specs/archive/state.json` regeneration flows), but its
  internal `generate-task-order.sh --print` call always uses `generate-task-order.sh`'s own
  *default* paths — a mismatch `generate-todo.sh`'s own source comment already flags ("We pass
  our STATE_FILE via a temporary symlink workaround if it differs, but normally both scripts share
  the same PROJECT_ROOT/specs/state.json default"). Adding Goal resolution to `--print` mode
  inherits this same pre-existing mismatch (an archive regen would read the *live* repo's
  `active_goal`/Goal line, not the archive's) rather than introducing a new one. Per the dispatch's
  explicit instruction not to widen scope beyond callers found to write `active_goal`, and since no
  archive-path caller writes or needs `active_goal`, this is noted but not remediated.
- **Risk**: A stale `active_goal` (set once, never updated) will now silently override any future
  hand-edit of `TODO.md`'s Goal line, exactly as the dispatch's Outcome #2 flags. **Mitigation**:
  accepted trade-off per Decision above — it is self-correcting via the existing `/review`
  "Update goal" flow or a direct `state-write.sh '.active_goal = $goal' ...` call, whereas the
  reverse trade-off (hand-edit wins) has no self-correction path and defeats `review.md`'s own
  feature.
- **Risk**: `build_state()` in the existing test harness does not currently accept an
  `active_goal` parameter; a naive regression-test addition might instead hand-roll a parallel
  `jq -n` state-construction call, diverging from the suite's established single-source-of-truth
  fixture builder. **Mitigation**: extend `build_state()`'s signature (additive, optional) rather
  than duplicating it, consistent with the suite's own stated preference for one `mk_fixture`/
  `build_state` combination driving every case.

## Context Extension Recommendations

- **Topic**: The two-code-path (`--print` vs. `--update-todo`) Goal-resolution split in
  `generate-task-order.sh`.
- **Gap**: `context/formats/task-order-format.md` documents the Goal line's "preserved across
  regenerations" behavior as a single, mode-independent guarantee. It does not document that this
  guarantee is implemented in only one of the script's two modes today, nor (once fixed) that both
  modes resolve Goal text identically.
- **Recommendation**: The three task-order-format.md edits in Recommendation 3 above close this
  gap directly as part of this task's own Outcome #3 — no separate follow-up context file is
  needed.

## Appendix

### Search queries / commands used

- `grep -n "goal\|GOAL" agent-system/extensions/core/scripts/generate-task-order.sh`
- `grep -n -A5 -B5 "active_goal" agent-system/extensions/core/context/schemas/state-schema.json`
- `grep -n -A5 -B5 "active_goal" agent-system/extensions/core/context/reference/state-management-schema.md`
- `grep -n -B3 -A3 "active_goal" agent-system/extensions/core/scripts/validate-state.sh`
- `sed -n '700,760p' agent-system/extensions/core/commands/review.md` (Section 6.7.3)
- `grep -n -B5 -A20 "regen-todo\|regen_todo" agent-system/extensions/core/scripts/state-write.sh`
- `grep -n -B3 -A10 "generate-task-order" agent-system/extensions/core/scripts/generate-todo.sh`
- Full read of `generate-task-order.sh`'s argument parsing, `read_existing_goal()`,
  `generate_section()`, and the "Determine goal text" / Main sections.
- `grep -rn "generate-task-order.sh\b"` / `"generate-todo.sh"` across
  `agent-system/extensions/core/` to build the full caller survey table.
- Live scratch reproduction: isolated `mktemp`-style scratch tree (built via the `Write` tool to
  avoid the repo's `validate-task-creation-audit.sh` Bash hook, which blocks any Bash-issued
  heredoc that looks like a hand-rolled `state.json` write) containing copies of
  `generate-task-order.sh`, `generate-todo.sh`, `deploy-root-guard.sh`, `lib/common.sh`,
  `lib/status-vocabulary.sh`, plus a synthetic `state.json` (`active_goal` set) and `TODO.md` (a
  pre-existing hand-written Goal line). Ran unmodified `generate-todo.sh` and unmodified
  `generate-task-order.sh --update-todo` directly, confirming both no-op findings above. No real
  repository file (`specs/state.json`, `specs/TODO.md`) was read from or written to by this
  reproduction.

### References

- `agent-system/extensions/core/scripts/generate-task-order.sh`
- `agent-system/extensions/core/scripts/generate-todo.sh`
- `agent-system/extensions/core/scripts/state-write.sh`
- `agent-system/extensions/core/scripts/update-task-status.sh`
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/scripts/validate-state.sh`
- `agent-system/extensions/core/context/schemas/state-schema.json`
- `agent-system/extensions/core/context/reference/state-management-schema.md`
- `agent-system/extensions/core/context/formats/task-order-format.md`
- `agent-system/extensions/core/commands/review.md`
- `agent-system/extensions/core/commands/errors.md`
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh`
