# Research Report: Task #451

**Task**: 451 - Take the Lean Challenge snapshot in the plan phase, where it is still meaningful, instead of leaving it to an implement phase the status gate correctly refuses
**Started**: 2026-11-22T15:17:33Z
**Completed**: 2026-11-22T16:05:00Z
**Effort**: medium (one core plumbing fix plus one extension hook, both small; the depth is in verifying each hard constraint is already satisfied or genuinely needs code)
**Dependencies**: 385 (completed), 420 (completed), 435 (completed) — all three archived; none block planning
**Sources/Inputs**: direct read of the source store (agent-system/extensions/lean/**, agent-system/extensions/core/**), specs/state.json and specs/archive/385_.../ artifacts, docs/guides/creating-extensions.md
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Option (a) is viable and remains the right choice, but it is NOT sufficient by itself.** The
  dispatch's own evidence (nix/nvim precedent) only proves the `preflight` and `context_injection`
  hook stages fire in production. Direct re-derivation of `skill-base.sh` and
  `orchestrate-cycle-postflight.sh` shows the **`postflight` stage, as reached from
  `/orchestrate`'s own cycle (the only dispatch path for a lean4 plan — there is no
  skill-lean-plan), currently cannot fire for ANY extension**, lean included. This is a
  previously unidentified, generic core bug, not a lean-specific gap, and it is a true prerequisite
  for this task's own acceptance criteria.
- **The dispatch misnamed the fallback-option file.** Option (b) names
  `scripts/orchestrate-cycle-plan.sh`, but that script only *decides/composes* which tasks to
  dispatch; the actual per-task plan-phase status write and hook call happen in
  `scripts/orchestrate-cycle-postflight.sh` (`skill_postflight_update "$task_number" "plan" ...`
  at line 1314). `orchestrate-cycle-plan.sh` is not the right core file for either option.
- **Idempotence is already free.** `lean-challenge-snapshot.sh` already refuses (exit 73) to
  overwrite an existing manifest without `--force`. A postflight hook that invokes the script
  without `--force` inherits "refuse" as the re-plan behaviour with zero new code.
- **Inertness for both edge cases is already free.** Extension-hook task_type matching
  (`skill_get_extension_dir`) already makes the hook inert for non-lean4 tasks once the core fix
  lands; the zero-goal marker (settled by task 385, already landed/archived) already makes the
  script a side-effect-free exit 72 for a lean4 plan with no theorem deliverable. Neither needs
  new hook-side logic.
- **The consuming `--check` call site belongs on the same hook, discriminated by `$operation`.**
  `skill_run_extension_hook`'s signature already carries `$operation`, so one `postflight` hook
  registration can run the producing snapshot on `operation == "plan"` and the consuming
  `--check` on `operation == "implement"` — exactly the dispatch's own hint, now confirmed
  reachable only after the core fix above.
- **Recommended ruling on the promotion sub-question: decline promotion, record why.** Task 462
  (`lean_challenge_check_scope_limit`, status `not_started`) owns the false-ambiguity defect the
  dispatch itself names as a hard precondition for promoting `--check` to blocking. It has not
  landed. The design record's own "Gate Strength: Advisory Only" section also says promotion
  should wait for "evidence from real runs" — and until this task wires in the first-ever call
  site, there have been zero real runs to gather evidence from.

## Context & Scope

Researched: (1) whether the `postflight` extension-hook mechanism actually reaches a declared
hook when a lean4 task's plan phase is dispatched through `/orchestrate`'s own cycle (the only
dispatch path, since the lean extension provides no `skill-lean-plan`); (2) how
`lean-challenge-snapshot.sh`'s existing status gate, manifest-exists refusal, and zero-goal
marker interact with a hook that would call it automatically and non-force; (3) where the
consuming `--check` call site should live; (4) the state of the promotion sub-question's named
precondition (task 462) and the "evidence from real runs" test the design record itself sets.

All three declared dependencies (385, 420, 435) are archived/completed in `specs/state.json`
(confirmed via `specs/archive/{385,420,435}_*/`), so none block planning.

## Findings

### Codebase Patterns

**Manifest state, confirmed by direct read (2026-11-22):**
- `agent-system/extensions/lean/manifest.json` has no top-level `hooks` key at all (not null —
  absent), matching the dispatch's claim.
- `agent-system/extensions/nix/manifest.json` declares `hooks: {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`.
- `agent-system/extensions/nvim/manifest.json` declares `hooks: {"context_injection": "scripts/nvim-context.sh"}`.
- **Neither precedent extension declares a `postflight` hook.** The dispatch's claim that the
  hook mechanism is "live and proven... in production use by the nix extension (preflight,
  context_injection) and the nvim extension (context_injection)" is accurate as far as it goes,
  but it does not cover `postflight` — the one stage this task needs.

**`skill_run_extension_hook` (`agent-system/extensions/core/scripts/skill-base.sh:214`)**: resolves
the declared hook to `.claude/scripts/$(basename "$hook_script")`, confirms it is executable,
invokes it with `"$task_number" "$task_type" "$task_dir" "$session_id" "$operation"`, and always
`return 0` — a non-zero hook exit is a logged WARNING plus an `_events_append_observable`
deviation event, never a blocking failure. This satisfies the "hook MUST be non-blocking" hard
constraint for free, confirmed by direct read (not merely asserted).

**The `postflight` stage's call site is `skill_postflight_update` (`skill-base.sh:1010-1193`)**,
specifically line 1192: `skill_run_extension_hook "postflight" "$task_number" "${TASK_TYPE:-}" "${TASK_DIR:-}" "$session_id" "$operation"` — unconditional, placed after the `case "$status" in ... esac` block closes at line 1169, so it fires regardless of which status branch ran (including the clamp-skip and archive-skip paths).

**THE GAP**: `${TASK_TYPE:-}` is a global the function never sets itself — it must already be set
in the calling shell. For a skill's own `SKILL.md` bash block (e.g. `skill-nix-research`), this
works because `skill_validate_input` sets `TASK_TYPE` earlier in the *same* continuous bash
session. But a lean4 task's plan phase has no such skill layer: it dispatches through
`/orchestrate`'s own cycle, and the plan-phase postflight call is
`scripts/orchestrate-cycle-postflight.sh`, invoked fresh (`bash .claude/scripts/orchestrate-cycle-postflight.sh ...`) once per task from `skill-orchestrate/SKILL.md`'s dispatch loop (line ~236). A
repository-wide, case-sensitive, word-boundary grep (`grep -n "\bTASK_TYPE\b" scripts/orchestrate-cycle-postflight.sh`) returns **zero hits** — the script never sets the uppercase global at all. It
only has a *lowercase* local `task_type` variable (set from its own `--task-type` CLI flag at
line 367, itself populated by the dispatch loop's own `jq -r '... .task_type // "general"'`
query against `specs/state.json`).

Consequence: every one of the six `skill_postflight_update` call sites in
`orchestrate-cycle-postflight.sh` (lines 1285 `research`, 1314 `plan`, 1432/1537 `implement`,
1678 `plan` needs_research arm, 2261 `implement` partial) passes an **empty** task_type into
`skill_run_extension_hook`, which makes `skill_get_extension_dir("")` fail to match any real
extension (every extension's own manifest `task_type` is non-empty — `"lean4"`, `"nix"`,
`"neovim"`, etc.), so the hook silently resolves to `skipped_no_extension` every time. **No
`postflight` hook for ANY extension currently fires via this path, for ANY task_type, for ANY of
research/plan/implement.** This is a generic plumbing gap, not something specific to lean — and
it affects the *consuming* `--check` call (implement-phase postflight) exactly as much as the
*producing* snapshot call (plan-phase postflight), since both would ride the same hook stage.

**Confirmed precedent for the fix, already in production for a sibling stage.** The
`verification` hook stage has exactly the same shape of problem (a stage not always reached from
inside a continuous skill session) and it is *already solved*, in `command-gate-out.sh`: that
script resolves its own local `gate_out_task_type` via a direct `jq -r` query against
`specs/state.json` (line 100) and passes it **directly** as `skill_run_extension_hook`'s third
positional argument (line 342) — `skill_run_extension_hook "verification" "$task_number" "${gate_out_task_type}" "$task_dir" "$session_id" "$operation"` — bypassing the global entirely. `command-gate-out.sh`'s own comment confirms this is "the live call site for the 'verification' lifecycle stage... command-gate-out.sh runs for every task on every operation." The documented 6th argument to
`skill_postflight_update` (`task_dir_override`) is the same kind of fix for `TASK_DIR`, added
specifically because "`/orchestrate`'s own postflight call sites reach it" without running
`skill_validate_input" — but no equivalent override was ever added for `task_type`.

**Minimal fix, scoped and low-risk**: in `orchestrate-cycle-postflight.sh`, set
`TASK_TYPE="$task_type"` once, immediately after the existing `--task-type` CLI-flag parsing
(near line 367-400) — a single assignment, before any `skill_postflight_update` call site, so
every one of the six call sites inherits the correct value. This is **not** lean-specific
knowledge in core: it is a generic bridging fix that makes the already-intended-to-be-generic
postflight hook mechanism work for every extension's `postflight` hook, present or future — it
strengthens, rather than undermines, the dispatch's stated preference for option (a) (lean-local
logic, not core logic), because it is infrastructure plumbing, not domain logic.

**The dispatch names the wrong file for option (b).** `scripts/orchestrate-cycle-plan.sh`'s own
header states it only "DECIDES" which tasks to dispatch this cycle — "Everything from 'After all
Agent tool calls complete' onward (per-task postflight, commits...) is a separate... job." The
actual plan-phase status write + hook call is in `orchestrate-cycle-postflight.sh`. If option (b)
is ever chosen instead of (a), the gated call belongs there, not in `orchestrate-cycle-plan.sh`.
This task's current `file_scope` lists `orchestrate-cycle-plan.sh`; it should list
`orchestrate-cycle-postflight.sh` instead (see Recommendations).

**Idempotence/immutability is already implemented, not something to design.**
`lean-challenge-snapshot.sh` (lines ~1035-1039) already refuses with exit 73 — "snapshot refused
-- manifest already exists at $MANIFEST_PATH. Use --force to overwrite" — whenever
`$MANIFEST_PATH` exists and `--force` was not passed, independent of the status gate. A
postflight hook that invokes the script plainly (no `--force`) inherits exactly the "refuse"
re-plan behaviour the dispatch's hard constraint asks for, with zero new logic.

**Both inertness constraints are already satisfied by landed mechanisms, not new hook logic.**
- Non-lean task types: once the `TASK_TYPE` bridging fix lands, `skill_get_extension_dir`'s exact
  string-equality gate (`agent-system/extensions/core/docs/guides/creating-extensions.md`'s
  "Prerequisite: A Declared task_type" section) already makes the hook unreachable for any
  non-`lean4` task — no lean-side code needed.
- Zero-goal lean4 plans: task 385 (archived, `status: implemented`) already added the literal
  `<!-- lean-challenge-statements:none -->` marker recognition, reported as exit 72, a
  side-effect-free early exit before any manifest write, module assembly, or git commit (per
  `challenge-snapshot.md`'s "Zero-Goal Marker" and "`--compare`/Comparator disposition" bullets).
  A hook that unconditionally invokes the script for every lean4 plan-phase postflight, with no
  plan-content sniffing of its own, gets this inertness for free and lets the script's own
  existing, already-tested classification (R1 populated / zero-goal marker / malformed / R2
  legacy fallback) decide the outcome.

**`project_root` resolution is a genuinely open design point, not yet settled anywhere.** Every
call site in the lean toolchain requires `project_root` as an explicit, non-defaulted argument
(`lean-challenge-snapshot.sh`, `lean-comparator-run.sh --project-root`, and
`lean-src-roots.sh`'s own framing: "resolve the Lean source roots for THIS repo"). No existing
mechanism derives it from a task number or task_dir. The uniform, single-repo assumption already
baked into every existing caller (the plan file and the Lean sources live in the same git repo
that owns `specs/`) means the hook's correct default is simply `"."` (the cwd the hook itself
executes from, which — per `skill-base.sh`'s own ambient convention of resolving `specs/state.json`,
`.claude/scripts/...`, etc. relative to cwd throughout the whole lifecycle — is always the repo
root). This should be recorded explicitly as an assumption/limitation: a Lean project nested in a
subdirectory of the repo, or living in a separate repo from `specs/`, is NOT supported by this
hook and is out of scope.

**The consuming `--check` call site's natural home is the same hook, on `operation == "implement"`.**
`--check` mode branches off before the status gate (`if $CHECK_MODE; then do_check ...; exit $?; fi`
at line ~419-422) and is unaffected by task status, so it can safely run during any implement-phase
postflight. `do_check()` already exits 71 cleanly when the manifest is absent (line ~276-279) —
exactly the degraded-but-safe behaviour the dispatch describes as "today's" behaviour, now finally
exercised by a real caller for the first time.

**Manifest registration is a known trap, already hit once by task 385.** The deploy pipeline
flattens `manifest.json`'s `provides.scripts` array into `.claude/scripts/`; a new hook script
file dropped on disk without also being added to `provides.scripts` deploys nothing and the hook
resolves to `skipped_not_executable` with a loud stderr NOTE. Task 385's own summary records
hitting exactly this gap for its new test fixtures and needing a second `deploy-headless.sh` run.
The plan should budget for this: register the new hook script filename in both
`manifest.json.provides.scripts` AND `manifest.json.hooks.postflight`.

**Naming precedent**: `nix-preflight.sh` / `nix-context.sh` / `nvim-context.sh` use
`{domain}-{stage}.sh`. A consistent name for the new script would be `lean-postflight.sh`.

### External Resources

None consulted — this is a closed-corpus, single-repository design question fully resolved by
direct source-store reads; no external documentation applies.

## Recommendations

1. **File_scope correction**: add `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
   to this task's `file_scope` for the `TASK_TYPE="$task_type"` bridging fix (needed regardless of
   which of (a)/(b) is chosen, since it is what makes `skill_postflight_update`'s hook call ever
   resolve a non-empty task_type at all). The currently-declared `orchestrate-cycle-plan.sh` is the
   wrong file for option (b) and should be removed or replaced.
2. **Take option (a)**: add `extensions/lean/manifest.json`'s top-level `hooks.postflight`
   pointing at a new `scripts/lean-postflight.sh`, registered in `provides.scripts` too. Inside the
   hook script, discriminate purely on `$5` (`$operation`): `plan` → invoke
   `lean-challenge-snapshot.sh "$1" "."` (no `--force`); `implement` → invoke
   `lean-challenge-snapshot.sh --check "$1" "."`; anything else → no-op, exit 0. Let the snapshot
   script's own existing exit-code vocabulary (0/71/72/73) communicate everything; do not
   reimplement any plan-content classification in the hook.
3. **Decline promotion of `--check` to blocking**, and record the ruling (in
   `rules/plan-compliance.md`'s existing "ADVISORY ONLY" paragraph, with a one-line note of why)
   rather than silently leaving the sub-question unaddressed: task 462's false-ambiguity defect
   (its own stated hard precondition for promotion) has not landed, and the design record's own
   "Gate Strength: Advisory Only" section requires "evidence from real runs" that cannot exist
   before this task's first wiring of a `--check` call site.
4. Correct the stale repo-root-resolution comment in `lean-challenge-snapshot.sh` (~L96-100) that
   asserts the script "is not itself deployed as a Claude Code artifact" — it is, and is already
   listed in `provides.scripts`.

## Decisions

- **Re-plan / idempotence behaviour: REFUSE** (not version, not require-explicit-regeneration as a
  new mechanism) — this is already `lean-challenge-snapshot.sh`'s existing, tested behaviour
  (exit 73 on an existing manifest without `--force`); the plan should document this choice rather
  than build anything new for it.
- **Registration site: option (a)**, a `postflight` hook in `extensions/lean/manifest.json`,
  contingent on the core `TASK_TYPE` bridging fix described above. Option (b) is not recommended:
  it would hardcode lean-specific logic into core for no remaining benefit once the generic
  bridging fix is in place, and the dispatch itself only sanctions (b) "with the reason recorded"
  if (a) is "demonstrated unworkable" — it is not; it needs one small, generic, precedented
  companion fix, not a redesign.
- **Consuming `--check` call site: the same `postflight` hook, discriminated on `$operation == "implement"`** — not a separate call site inside the implementation agents, which would duplicate
  logic the hook mechanism already carries for free via its `$operation` argument.
- **Promotion sub-question: decline, record why** — advisory stance stays, pending task 462.

## Risks & Mitigations

- **Risk**: the core `TASK_TYPE` bridging fix is itself untested against this task's own territory
  edges — `orchestrate-cycle-postflight.sh` is a large (3000+ line), heavily-trafficked file shared
  by every task type's postflight. **Mitigation**: the fix is a single, additive variable
  assignment (`TASK_TYPE="$task_type"`) placed once, early, with no existing behaviour removed or
  altered for any caller that never relied on the (currently always-empty) global — verify with the
  existing `test-skill-base-lifecycle.sh` Group 5 hook tests plus a new assertion that a real
  `--task-type lean4` invocation of `orchestrate-cycle-postflight.sh` now resolves a non-empty
  `SKILL_HOOK_LAST_STATUS=ran` (or an appropriately-skipped status for a non-matching extension).
- **Risk**: once wired, EVERY qualifying lean4 plan-phase postflight will automatically create a
  real git commit in the *target Lean project's own history* (not `specs/`), where today this only
  happens when a human/agent deliberately runs the script. Two or more lean4 tasks landing plans in
  the same repo within the same `/orchestrate` cycle will each commit to that repo's HEAD in
  sequence (not concurrently, since dispatch is per-task), so no corruption is expected, but commit
  volume/noise in the target project's history increases structurally. **Mitigation**: document
  this as an expected, intentional side effect (it is the entire point of a trusted,
  git-immutable Challenge) in `challenge-snapshot.md`; no code mitigation is needed or requested by
  the dispatch.
- **Risk**: forgetting to register the new hook script in `manifest.json.provides.scripts` (not
  just `hooks.postflight`) silently deploys nothing. **Mitigation**: `check-extension-docs.sh`'s
  post-deploy completeness check already catches this class of gap (as task 385's own deviation
  record shows); budget for a second `deploy-headless.sh` run if it fires.

## Context Extension Recommendations

- **Topic**: extension lifecycle hooks, postflight stage reachability.
- **Gap**: `docs/guides/creating-extensions.md`'s "Lifecycle Hooks" section documents the
  `skill_run_extension_hook` mechanism and the task_type-match prerequisite in detail, but does not
  document that the `postflight` stage specifically depends on its caller pre-setting the
  `${TASK_TYPE:-}` global, nor that `/orchestrate`'s own cycle (`orchestrate-cycle-postflight.sh`)
  does not do so today (prior to this task's fix). A future extension author wiring a `postflight`
  hook with no other guidance would hit the same silent `skipped_no_extension` outcome this report
  diagnoses.
- **Recommendation**: once this task's core fix lands, add a short subsection to
  `docs/guides/creating-extensions.md`'s "Lifecycle Hooks" section (or a cross-reference to
  `command-gate-out.sh`'s verification-stage pattern) stating that a `postflight` hook requires the
  caller to have resolved and bridged `task_type` into the ambient `TASK_TYPE` global (or passed it
  directly, bypassing `skill_postflight_update`), with `orchestrate-cycle-postflight.sh`'s
  bridging line as the concrete example. This is not core/lean content, so it belongs in core's own
  docs, not in `challenge-snapshot.md`.

## Appendix

**Searches/reads performed** (all direct source-store reads, no web search):
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` (full read: status gate,
  manifest-exists refusal, `--check`/`do_check`, zero-goal exit 72, plan-file resolution, exit-code
  comment header)
- `agent-system/extensions/lean/manifest.json`, `agent-system/extensions/nix/manifest.json`,
  `agent-system/extensions/nvim/manifest.json` (top-level `hooks` key presence/absence)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_get_extension_dir`,
  `skill_run_extension_hook`, `skill_preflight_update`, `skill_postflight_update` — full bodies
  and surrounding comments)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (grep for `TASK_TYPE`,
  `task_type`, `skill_postflight_update` call sites; confirmed zero uppercase-global assignments)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (header only — confirmed it is a
  composer/decision script, not where postflight runs)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (`gate_out_task_type` resolution and
  direct `skill_run_extension_hook` call — the precedent fix pattern)
- `agent-system/extensions/core/docs/guides/creating-extensions.md`'s "Lifecycle Hooks" section
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` (Manifest
  Schema, Exit-Code Vocabulary, Gate Strength: Advisory Only, Zero-Goal Marker sections)
- `agent-system/extensions/lean/rules/plan-compliance.md` ("Mechanical check" / "ADVISORY ONLY"
  paragraphs)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (`--compare` preflight,
  `comparator_project_root` read from the manifest, not re-derived)
- `agent-system/extensions/lean/scripts/lean-src-roots.sh`, `lean-comparator-run.sh` (`project_root`
  always an explicit, non-defaulted argument; single-repo framing)
- `specs/state.json`, `specs/archive/385_lean4_plan_with_zero_lean_goals/`,
  `specs/archive/420_warn_plan_size_exceeds_cycle_budget/`,
  `specs/archive/435_reword_dead_lifecycle_command_prose_per_class/` (dependency resolution)
- `specs/state.json` entry for task 462 (`lean_challenge_check_scope_limit`, `not_started`) — full
  description read for the promotion-sub-question precondition
