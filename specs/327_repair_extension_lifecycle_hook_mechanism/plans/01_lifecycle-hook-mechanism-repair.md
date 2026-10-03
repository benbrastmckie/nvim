# Implementation Plan: Task #327

- **Task**: 327 - Repair the extension lifecycle hook mechanism: broken resolver schema, absent
  return-code channel, uninvoked verification stage
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (no dependency edge on the skeleton-plan follow-up work — deliberate,
  see Risks & Mitigations)
- **Research Inputs**: specs/327_repair_extension_lifecycle_hook_mechanism/reports/01_lifecycle-hook-mechanism-repair.md
- **Artifacts**: plans/01_lifecycle-hook-mechanism-repair.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The extension lifecycle hook mechanism in `agent-system/extensions/core/scripts/skill-base.sh`
is dead on four independent counts: its `task_type -> extension` resolver queries a
`.loaded_extensions` key that has never existed in the live `.claude-extensions.json` schema; its
hook-script path is built against a nested deploy layout that the deploy pipeline never produces;
a non-zero hook exit reaches no caller through any channel; and the `verification` stage's only
call site sits in a function nothing calls. This plan fixes all four in the source store
(`agent-system/extensions/core/`, never `.claude/**`), proves a declared hook actually fires with
a fixture-driven regression group, adds the rc-observability channel as a documented *addition*
to the existing non-blocking contract rather than a flip of it, and closes the validator blind
spot that let two shipped extensions declare dead hooks undetected. Done means: the `nix`
preflight hook fires, a non-zero hook exit is observable to the caller while every call site's
disposition stays non-blocking, the `verification` stage has a live call site on a path that runs
on every task, and `test-skill-base-lifecycle.sh` exercises the resolver against the real object
schema.

### Research Integration

The research report confirmed all three dispatch-named defects verbatim at the given line numbers
and discovered a fourth that is load-bearing for the acceptance criterion:

- **Finding 1** (`skill-base.sh` `skill_get_extension_dir`): `.loaded_extensions` is the sole
  surviving consumer of a dead key anywhere in the repo; the live file is
  `{extensions: {<name>: {...}}, version}` and per-extension entries carry **no** `task_type`
  field. `task_type` lives only in each extension's own `manifest.json`. A correct resolver needs
  a two-step join: active names from `.claude-extensions.json`, then each deployed
  `.claude/extensions/<name>/manifest.json`'s `.task_type`.
- **Finding 4 (new, load-bearing)**: `hook_path="${ext_dir}/${hook_script}"` assumes a
  `.claude/extensions/<name>/scripts/` subdirectory that does not exist for any loaded extension
  (`installed_dirs` is `[]` for all seven). Hook scripts deploy *flattened* into
  `.claude/scripts/`. Fixing Finding 1 alone leaves `hook_path` pointing at a nonexistent file,
  silently no-oped by the existing `[ -x ]` test — so the hook would still never fire. Phase 1
  therefore fixes Findings 1 and 4 together; neither alone satisfies acceptance.
- **Finding 2** (rc channel): re-confirmed as the function's last statement. The research's
  recorded Decision — rc becomes *observable*, every call site's disposition stays non-blocking,
  no opt-in blocking mode — is adopted verbatim by this plan (see Goals, and the Phase 2
  rationale for why returning the rc is additionally unsafe here).
- **Finding 3** (`verification` dead): re-confirmed. `command-gate-out.sh` calls the *different*
  function `skill_validate_task_artifacts()`, which contains no hook call. The research
  recommended wiring the stage there rather than resurrecting the callerless
  `skill_validate_artifact()`; this plan adopts that and refines the exact site (Phase 3).

Three additional facts were established directly during planning and are recorded here because
they change the shape of two phases:

1. **The three currently-dead hook scripts are benign.** `.claude/scripts/nix-preflight.sh`,
   `nix-context.sh`, and `nvim-context.sh` were read in full: each is a `command -v` / file-presence
   probe that prints to stdout/stderr and unconditionally `exit 0`. Both extensions also declare
   these scripts in `provides.scripts`, and all three are present and executable at
   `.claude/scripts/`. So the resolver fix makes them go live immediately with no behavioural
   hazard — this downgrades the "hooks suddenly start firing" risk from unknown to low, and is
   what makes Phase 1's end-to-end proof possible without any manifest edit.
2. **`command-gate-out.sh` has no `task_type` in scope at all** (`grep -n task_type` returns
   nothing). It takes `task_number`, `operation`, `session_id` positionally and derives
   `task_dir` from `specs/state.json`. The verification hook needs `task_type` as `$2`, so
   Phase 3 must add one `jq` read against `specs/state.json` — a detail the research did not
   surface and which otherwise would have been discovered mid-edit.
3. **`skill_validate_task_artifacts()` takes only `task_dir`** — it cannot pass five positional
   args to a hook. The live call site therefore belongs in `command-gate-out.sh` immediately
   after that function's invocation (where `task_number`/`session_id`/`operation` already are in
   scope), not inside the function. Phase 3 leaves the function's signature untouched.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included and `specs/ROADMAP.md` is neither read nor written by this plan.

## Goals & Non-Goals

**Goals**:
- `skill_get_extension_dir` resolves `task_type -> extension dir` against the real
  `.claude-extensions.json` object schema joined with each extension's own manifest `task_type`.
- `skill_run_extension_hook` resolves the hook script against the flat deployed
  `.claude/scripts/` location, so a declared hook is actually found and executed — proven with
  the `nix` preflight hook, which is dead today.
- A hook's exit code is observable to the caller through a documented global channel, and a
  non-zero exit additionally lands in the unified event store as a `deviation`.
- **Every existing call site's disposition stays non-blocking, unchanged.** This is a goal, not
  an incidental property: the mechanism keeps "exit non-zero -> warning, skill continues"
  exactly as `creating-extensions.md` documents it. The documentation change is an *addition*
  describing the new observability channel, never a rewrite of the non-blocking sentence.
- The `verification` stage gets a live call site on the gate-out path that runs for every task,
  rather than being retired.
- A declared-hook path that resolves to a missing or non-executable script produces a loud
  one-line NOTE instead of today's silent `return 0`.
- `test-skill-base-lifecycle.sh` covers the resolver against a fixture built in the REAL object
  schema, an end-to-end hook-fires case, and a non-zero-rc observability case; the two newly
  covered functions leave the suite's "Residual (uncovered)" footer.
- `check-extension-docs.sh` validates the top-level lifecycle `hooks` object's script paths
  against deployed reality for every extension, closing the blind spot that let `nix` and `nvim`
  ship dead hooks undetected.

**Non-Goals**:
- No opt-in per-stage blocking mode for hook failures. Recorded decision; revisit only with a
  concrete need.
- No retirement of the `verification` stage, and no change to the stage vocabulary
  (`preflight`, `context_injection`, `verification`, `postflight`), the five positional
  arguments, the no-environment-variables rule, or the uncaptured-stdout behaviour.
- No edits to `nix/manifest.json` or `nvim/manifest.json`. Basename resolution (Phase 1) accepts
  both the `scripts/`-prefixed form these manifests use and a bare filename, so neither manifest
  needs to change; normalizing them would be churn with no behavioural effect.
- No change to `skill_validate_artifact()`'s signature, and no new caller for it. It stays as-is
  (callerless, harmless); its hook call is removed only if Phase 3 concludes the duplicate site
  is actively confusing — see that phase's task list.
- No `.claude/**` edits of any kind. `.claude/` is a disposable deploy artifact regenerated from
  the source store; regenerating it is an operator action (`<leader>al` "Reload All", or
  `deploy-headless.sh`) deliberately left outside this task — see Phase 7.
- No adoption of the `verification` stage by any extension. No manifest anywhere declares one
  today; wiring the call site is forward-looking by design and does not block acceptance.
- No new test *file*. The coverage goes into the existing `test-skill-base-lifecycle.sh`, which
  is already registered in core's `manifest.json`; a new file would need manifest registration
  and a deploy to become runnable.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Three hooks that have never run start firing on every `nix`/`neovim` lifecycle stage | M | H (certain, by design) | Already de-risked: all three scripts were read in full and are `exit 0` console probes (see Research Integration, fact 1). Phase 1 additionally executes each one directly with the five real positional args and asserts exit 0 before closing. |
| The regression suite sources the **deployed** `skill-base.sh` first, which is stale immediately after a source-store edit — so new cases would silently exercise unchanged code | H | H | Phase 4's new group resolves source-store-first (the reverse of the suite default) and sources it in a subshell, printing an INFO line naming which copy it exercised. Precedent: the suite's existing stale-deploy harness guard, which exits 2 with an actionable message rather than reporting a misleading PASS. |
| Making the rc observable is later misread as license to block on it | M | M | Stated explicitly in three places: this plan's Goals, a code comment at the change site, and the `creating-extensions.md` addition. Phase 2 also keeps `return 0` as the function's literal last statement so the non-blocking property is structural, not conventional. |
| Returning the hook rc from the function would abort callers running under `set -e`, silently flipping the documented contract | H | H if attempted | Phase 2 does **not** return the rc. It is exposed through globals only, and the function returns 0 explicitly. |
| A future extension gains a nested `installed_dirs` layout, regressing flat `.claude/scripts/` resolution | L | L | Confirmed `installed_dirs` is `[]` for all seven loaded extensions — no such layout exists to regress. Phase 6's new validator rule is what would surface the regression if one ever appeared. |
| `orchestrate-batch-admit.sh` detects a `cross_batch` overlap on `skill-base.sh` with the skeleton-plan follow-up work and defers this task | M | L | Per the dispatch: dispatch this task alone, or alongside tasks whose `file_scope` excludes `skill-base.sh`. The regions are disjoint (resolver / rc channel / verification site vs. the completion-handoff path); if both land close together the later one rebases. The research additionally observed that work currently reads `completed` in `specs/state.json`, which if still true removes the overlap entirely — observational only, not a precondition. |
| Sibling task dispatched this same cycle touches the shared working tree | M | M | Territory discipline per the dispatch: re-read each file immediately before editing, stage only this task's own hunks with an explicit file list (never a directory or glob `git add`), never run `git-snapshot.sh` in its reverting default mode, and STOP and report any foreign commit or uncommitted modification after checking `git log`. The declared sibling's scope is `agent-system/extensions/books/**`, disjoint from every file here. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5, 6 | 3 |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Fix the resolver and the hook-script path [COMPLETED]

**Goal**: Make a declared hook actually resolve and execute. Fixes defect 1 (dead
`.loaded_extensions` query) and defect 4 (nested-deploy path assumption) together, since neither
alone makes a hook fire.

**Tasks**:
- [x] Re-measure before editing: locate `skill_get_extension_dir` and `skill_run_extension_hook`
      in `agent-system/extensions/core/scripts/skill-base.sh` by **function name**, not by the
      dispatch's line numbers (they will have moved). Record the current line ranges in the
      progress file.
- [x] Re-read the file immediately before the first edit (territory discipline — a sibling task
      is live on this working tree this cycle).
- [x] In `skill_get_extension_dir`: replace the `.loaded_extensions // [] | .[] | select(.task_type == $tt) | .name`
      query with a two-step join — enumerate active extension names via
      `.extensions | to_entries[] | select(.value.status=="active") | .key` (the already-correct
      object-schema pattern used at `measure-eager-context.sh`'s extension enumeration), then for
      each name read `.claude/extensions/<name>/manifest.json` and compare its own top-level
      `.task_type` against the requested `task_type`. Echo `.claude/extensions/<name>` on first
      match; echo nothing otherwise.
- [x] Preserve the existing early `return 0` when `.claude-extensions.json` is absent, and keep
      the resolver's bare-relative path convention (`.claude-extensions.json`,
      `.claude/extensions/<name>`) — the suite's fixture isolation depends on cwd-relative
      resolution.
- [x] In `skill_run_extension_hook`: keep `manifest="${ext_dir}/manifest.json"` exactly as-is
      (that half of the current resolution is correct), and change the hook-script half from
      `hook_path="${ext_dir}/${hook_script}"` to resolve against the flat deployed location —
      `.claude/scripts/$(basename "$hook_script")`. Add a short comment recording *why*: the
      deploy pipeline flattens `provides.scripts` into `.claude/scripts/`, so a manifest's
      `scripts/`-prefixed value mirrors the **source** layout and never the deployed one;
      basename resolution deliberately accepts both the prefixed and the bare form.
- [x] Replace the silent `[ ! -x "$hook_path" ] && return 0` no-op with a loud one-line stderr
      NOTE naming the hook stage, the declaring manifest, and the resolved path, then `return 0`.
      This is the exact failure mode that hid defect 4; a future hook-path typo must not get the
      same silent treatment.
- [x] Prove the end-to-end fix by hand before closing: from the repo root, source the edited
      source-store `skill-base.sh` in a subshell and confirm `skill_get_extension_dir nix`
      returns `.claude/extensions/nix` and `skill_get_extension_dir neovim` returns
      `.claude/extensions/nvim` (both return empty today).
- [x] Execute each of the three previously-dead hook scripts directly with the five real
      positional args (`.claude/scripts/nix-preflight.sh`, `nix-context.sh`, `nvim-context.sh`)
      and confirm each exits 0 — the live-firing safety check from Risks.
- [x] Commit this green sub-step before starting Phase 2.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that exactly **two** functions in one file need
changing, and that **three** deployed hook scripts exist and are executable. Confirm at
implementation time by (a) `grep -n 'loaded_extensions'` across the repo returning exactly the
one resolver hit before the edit and zero hits after, and (b) `ls -l` on the three
`.claude/scripts/` hook paths. A third affected function or a missing script invalidates the
hypothesis and must be recorded in the progress file before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - rewrite `skill_get_extension_dir`'s jq
  query as an object-schema + per-manifest `task_type` join; change
  `skill_run_extension_hook`'s `hook_path` to basename-resolve against `.claude/scripts/`;
  replace the silent non-executable skip with a loud NOTE.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/skill-base.sh` passes.
- `shellcheck` on the file reports no new findings relative to a pre-edit baseline capture.
- Sourced-subshell probe: `skill_get_extension_dir nix` -> `.claude/extensions/nix`;
  `skill_get_extension_dir neovim` -> `.claude/extensions/nvim`;
  `skill_get_extension_dir no-such-type` -> empty.
- `grep -c 'loaded_extensions' agent-system/extensions/core/scripts/skill-base.sh` is 0.
- Each of the three hook scripts exits 0 when invoked directly with five positional args.
- The repository's full gate set runs clean before the phase closes.

---

### Phase 2: Add the hook return-code channel [COMPLETED]

**Goal**: Make a hook's exit code observable to the caller without changing any call site's
non-blocking disposition.

**Tasks**:
- [x] Re-read `skill-base.sh` immediately before editing.
- [x] Introduce four uppercase globals, following the file's existing `SKILL_VALIDATE_*`
      convention and its documented unconditional-reset discipline:
      `SKILL_HOOK_LAST_RC` (the hook's exit code), `SKILL_HOOK_LAST_STATUS` (one of `ran`,
      `skipped_no_extension`, `skipped_no_manifest`, `skipped_not_declared`,
      `skipped_not_executable`), `SKILL_HOOK_LAST_NAME` (the stage), `SKILL_HOOK_LAST_PATH` (the
      resolved script path, empty when nothing resolved).
- [x] Reset all four **unconditionally at function entry**, before any early return, so a caller
      can never read a value left over from a prior invocation. Mirror the wording of
      `skill_validate_task_artifacts`'s existing reset comment rather than inventing a new one.
- [x] Set `SKILL_HOOK_LAST_STATUS` on every early-return path, so a skip is distinguishable from
      a clean run — this is the difference between "no hook declared" and "hook ran and
      succeeded", which today are indistinguishable.
- [x] Replace the `|| echo "...non-zero (non-blocking)"` trailing-`||` form with an explicit
      `set -e`-safe capture (`rc=0; "$hook_path" ... || rc=$?`), keeping the existing console
      WARNING byte-identical so live logs do not change shape.
- [x] On a non-zero rc, additionally emit one `_events_append_observable` row with
      `--event-type lifecycle_stage --category deviation`, `--checkpoint <hook_name>`, and a
      message naming the hook stage and exit code — mirroring how `skill_validate_artifact`
      already discriminates `_category` by status.
- [x] Make `return 0` the function's **literal last statement**, with a comment stating that the
      non-blocking disposition is deliberate and unchanged, and that returning the rc is
      specifically unsafe because a caller under `set -e` would abort mid-lifecycle — flipping
      the documented contract as a side effect.
- [x] Add a header-comment block documenting the four globals and the "observable, never
      blocking" contract, alongside the existing EXTENSION HOOKS contract block.
- [x] Leave all four existing call sites (`skill_preflight_update`, `skill_context_injection`,
      `skill_validate_artifact`, `skill_postflight_update`) **unmodified** — none inspects a
      return value today and none starts to.
- [x] Commit this green sub-step.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts that **four** `skill_run_extension_hook` call sites exist and that
**none** needs modifying. Confirm with `grep -n 'skill_run_extension_hook' ` on the file
(expecting four invocation lines plus the definition and comment references) and by reading each
call site to verify no return-value inspection. A fifth call site, or one that does inspect the
return value, invalidates the hypothesis.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - add the four `SKILL_HOOK_LAST_*`
  globals with unconditional entry reset and per-skip-path status values; replace the trailing-`||`
  invocation with an rc-capturing form; emit a `deviation` event on non-zero; explicit terminal
  `return 0`; document the channel in the EXTENSION HOOKS comment block.

**Verification**:
- `bash -n` and `shellcheck` clean (no new findings vs. baseline).
- Sourced-subshell probe with a throwaway `exit 0` hook: `SKILL_HOOK_LAST_RC` is `0`,
  `SKILL_HOOK_LAST_STATUS` is `ran`, function returns 0.
- Same probe with a throwaway `exit 3` hook: `SKILL_HOOK_LAST_RC` is `3`,
  `SKILL_HOOK_LAST_STATUS` is `ran`, the console WARNING still prints, and the function still
  returns 0.
- Probe for a `task_type` with no loaded extension: `SKILL_HOOK_LAST_STATUS` is
  `skipped_no_extension` and `SKILL_HOOK_LAST_RC` is unambiguously distinguishable from a real
  `0` exit.
- Second consecutive invocation after a non-zero one, against a `task_type` with no hook,
  reports a skip status and does not leak the prior `3`.
- Full gate set clean before close.

---

### Phase 3: Give the `verification` stage a live call site [COMPLETED]

**Goal**: Move the `verification` stage's invocation from the callerless
`skill_validate_artifact()` to the gate-out path that runs for every task.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/command-gate-out.sh` and the
      `skill_validate_task_artifacts` region of `skill-base.sh` immediately before editing.
- [x] Re-confirm the premise by measurement, not by inheritance:
      `grep -rln 'skill_validate_artifact\b'` across the repo should show only `skill-base.sh`
      and `test-skill-base-lifecycle.sh`. If a real caller has appeared since the research pass,
      stop and record it — the phase's premise would no longer hold.
- [x] In `command-gate-out.sh`, read `task_type` for the task from `specs/state.json` with a
      single `jq` against the already-resolved project entry (the script currently has **no**
      `task_type` in scope at all), tolerating an absent value as empty rather than failing.
- [x] Add the `verification` hook invocation in `command-gate-out.sh` immediately after the
      existing `skill_validate_task_artifacts "$task_dir"` call, passing the five positional args
      from the variables already in scope there (`task_number`, the newly read `task_type`,
      `task_dir`, `session_id`, `operation`).
- [x] Leave `skill_validate_task_artifacts`'s signature unchanged — it takes only `task_dir` and
      cannot supply five args; this is why the call belongs at the call site, not inside the
      function.
- [x] Decide and record, in a one-line comment at the new site, whether
      `skill_validate_artifact()`'s now-duplicate hook call is left in place (harmless, still
      callerless) or removed. Default: **leave it**, and say so, so a reader does not mistake the
      duplication for an accident.
- [x] Add a comment at the new site stating the disposition explicitly: non-blocking, rc visible
      via `SKILL_HOOK_LAST_RC`, gate-out proceeds regardless.
- [x] Commit this green sub-step.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts that `skill_validate_artifact` still has **zero** callers outside
`skill-base.sh` and the lifecycle test suite, and that `command-gate-out.sh` has **zero**
occurrences of `task_type`. Confirm both with `grep` before editing; either count being different
invalidates the phase's premise and must be recorded before proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` - read `task_type` from
  `specs/state.json`; invoke the `verification` hook immediately after
  `skill_validate_task_artifacts`; comment the non-blocking disposition and the retained
  duplicate site.
- `agent-system/extensions/core/scripts/skill-base.sh` - comment-only cross-reference from
  `skill_validate_artifact`'s hook call to the new live site (prose; no behavioural change).

**Verification**:
- `bash -n` on both files; `shellcheck` clean vs. baseline.
- `grep -c 'skill_run_extension_hook "verification"'` across the source store is 2 (the retained
  dead site plus the new live one), or 1 if the implementer recorded a decision to remove the
  dead one.
- End-to-end: in an isolated fixture repo with a `verification` hook declared in a fixture
  extension manifest and a script under the fixture's `.claude/scripts/`, run the gate-out path
  and confirm the hook's stdout appears and `SKILL_HOOK_LAST_STATUS` reads `ran`.
- Gate-out on a task whose `task_type` has **no** loaded extension still completes normally with
  a `skipped_no_extension` status and no console noise beyond the existing report line.
- Full gate set clean before close.

---

### Phase 4: Regression coverage in `test-skill-base-lifecycle.sh` [COMPLETED]

**Goal**: Cover the resolver against the REAL object schema, prove a declared hook executes
end-to-end, and prove a non-zero exit is observable — the acceptance criterion's test leg.

**Tasks**:
- [x] Re-read the suite immediately before editing, including its header ISOLATION CONTRACT, its
      `build_fixture_repo()` / `build_deploy_gate_source_repo()` helpers, and its existing
      stale-deploy harness guard.
- [x] Add a new test group with its **own** source-store-first `skill-base.sh` resolution,
      sourced in a subshell so the suite-level sourced functions are untouched. Print one INFO
      line naming which copy the group exercised, and a short comment explaining the reversal:
      the functions under test are being changed in the source store, while the deployed copy is
      regenerated by an operator action outside this task's control, so a deploy-first resolution
      would silently exercise stale code and report a misleading PASS. Cite the suite's existing
      stale-deploy guard as the precedent for naming the exercised copy rather than guessing.
- [x] Build a hook fixture repo under the suite's `WORKDIR`: a `.claude-extensions.json` in the
      **real** object schema (`{version, extensions: {<name>: {status: "active", ...}}}`), a
      `.claude/extensions/<name>/manifest.json` carrying a top-level `task_type` and a `hooks`
      object, and a synthetic executable hook script under the fixture's `.claude/scripts/`.
      Reuse `build_deploy_gate_source_repo`'s *technique* for fabricating the extensions file,
      not its content (that fixture is purpose-built for the deploy-freshness gate).
- [x] Use a **synthetic** fixture hook script, not the real `nix-preflight.sh` — the real script
      probes host `nix` availability and would make the case environment-dependent. Prove the
      real `nix` hook separately via Phase 1's direct sourced-subshell probe, which is where the
      "prove it with the `nix` preflight hook" acceptance line is discharged.
- [x] Cover these cases, `cd`-ing into the fixture repo so the functions' bare-relative paths
      resolve there and never into the real tree:
      - resolver hit: `skill_get_extension_dir <fixture task_type>` returns the fixture extension dir;
      - resolver miss: an unknown `task_type` returns empty;
      - resolver miss: an extension whose `status` is not `active` is not matched;
      - resolver safety: no `.claude-extensions.json` at all returns empty and exits 0;
      - hook fires: a declared hook whose script sits at the fixture's `.claude/scripts/` writes
        its sentinel, `SKILL_HOOK_LAST_STATUS` is `ran`, `SKILL_HOOK_LAST_RC` is 0;
      - prefixed-path tolerance: the same case with the manifest value written as
        `scripts/<name>.sh` resolves identically (this is the form `nix`/`nvim` actually use);
      - rc observable: a hook exiting non-zero sets `SKILL_HOOK_LAST_RC` to that code while the
        function still returns 0;
      - reset discipline: a subsequent skipped invocation does not leak the prior non-zero rc;
      - loud skip: a declared hook whose script is absent or non-executable emits the NOTE on
        stderr and still returns 0.
- [x] Remove `skill_get_extension_dir` and `skill_run_extension_hook` from the suite's
      "Residual (uncovered by this suite...)" footer, leaving the remaining residuals intact.
- [x] Confirm the suite's real-tree contamination guard still passes — the new group must leave
      no new mark on the real `specs/` tree relative to the pre-run baseline.
- [x] Commit once the suite passes.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts **nine** new cases in **one** existing file, with **no** new test
file and therefore **no** `manifest.json` registration. Confirm by `grep -n
'test-skill-base-lifecycle.sh' agent-system/extensions/core/manifest.json` returning the existing
registration, and by the suite's own `Results: N passed` line increasing by at least nine. If a
new file turns out to be necessary after all, its `manifest.json` registration becomes a required
additional task and must be recorded.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - new hook-mechanism
  group with source-store-first subshell resolution, a real-object-schema
  `.claude-extensions.json` fixture, nine cases, and an updated residuals footer.

**Verification**:
- `bash -n` on the suite; `shellcheck` clean vs. baseline.
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0 with
  every pre-existing case still passing and the nine new cases passing.
- Mutation check: temporarily revert the resolver's jq query to the old `.loaded_extensions`
  form in a scratch copy and confirm the new resolver cases FAIL — a test that cannot fail
  against the known-broken code proves nothing. Restore immediately; never commit the scratch
  revert.
- The suite's contamination guard passes (`real specs/ tree status is unchanged`).
- `grep -c 'skill_get_extension_dir' ` in the residuals footer block is 0.

---

### Phase 5: Document the rc-observability addition [COMPLETED]

**Goal**: Bring `creating-extensions.md` into agreement with the repaired mechanism — as an
addition to the Hook Execution Contract, never a rewrite of the documented non-blocking default.

**Tasks**:
- [x] Re-read the Hook Schema / Hook Execution Contract / Lifecycle Stage Mapping sections of
      `agent-system/extensions/core/docs/guides/creating-extensions.md` immediately before
      editing.
- [x] Leave the existing "Exit non-zero: warning logged (non-blocking, skill continues)" sentence
      **verbatim and in place**. Nothing about it is now false.
- [x] Add, directly beneath it, a short subsection documenting the observability channel: the
      four `SKILL_HOOK_LAST_*` globals, what each holds, the unconditional-reset-at-entry
      guarantee, the `deviation` event emitted on a non-zero exit, and an explicit sentence
      stating that observability is **not** blocking and that no call site's disposition changed.
- [x] Document the hook-script **path resolution rule**, which the guide currently gets wrong by
      implication: a `hooks` value's basename is resolved against the deployed
      `.claude/scripts/` directory, so the script **must also be declared in
      `provides.scripts`** to be deployed at all, and a `scripts/`-prefixed value is accepted but
      only mirrors the source layout. This is the trap that made two shipped extensions'
      hooks dead.
- [x] Update the Lifecycle Stage Mapping table's `verification` row: its "Called From" becomes
      the gate-out call site added in Phase 3, not `skill_validate_artifact()`.
- [x] Note that a declared hook whose script does not resolve now produces a loud NOTE rather
      than a silent skip, and that missing hook keys and an absent `.claude-extensions.json` are
      still silently skipped (unchanged).
- [x] Cite file paths and function names only — **no task-number references** anywhere in this
      file, per `rules/no-task-references-in-deliverables.md`. Refer to the skeleton-plan
      follow-up work by title if it needs mentioning at all (it should not).
- [x] Commit.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts **three** sections of one guide need touching (Hook Schema, Hook
Execution Contract, Lifecycle Stage Mapping) and that the non-blocking sentence needs **zero**
changes. Confirm by diff review: the diff must contain no deletion of that sentence.

**Files to modify**:
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - add an rc-observability
  subsection and the hook-script path-resolution rule; correct the `verification` row's
  "Called From"; document the loud unresolved-script NOTE.

**Verification**:
- Diff read-through confirms every changed hunk is prose/markdown with no code or compile
  surface, and that the "non-blocking, skill continues" sentence is present and unmodified.
- `bash .claude/scripts/check-task-references.sh` (or the repo-wide task-reference lint) reports
  no new occurrences for this file.
- `grep -n 'skill_validate_artifact' ` in the stage-mapping table returns nothing (the
  `verification` row now names the live site).
- The documented globals' names match the implementation exactly — cross-check by grepping both
  files for `SKILL_HOOK_LAST_`.

---

### Phase 6: Close the validator blind spot in `check-extension-docs.sh` [NOT STARTED]

**Goal**: Make the lint catch a lifecycle `hooks` value that cannot resolve once deployed — the
blind spot that let `nix` and `nvim` ship dead hooks undetected by any existing check.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/check-extension-docs.sh`, specifically its
      Rule letter index, its `advisory()` vs. `fail()` lanes, `check_core_deploy_advisory`'s
      FAIL-vs-ADVISORY rationale comment, and the per-extension dispatch loop.
- [ ] Add a new rule function checking, **for every extension** (not just `routing_exempt: true`
      core — `nix` and `nvim` are neither), that each top-level `hooks.<stage>` value's basename
      resolves to an existing, executable file under `.claude/scripts/`, and that the same
      basename is declared in `provides.scripts`. Model the deployment-presence check on
      `check_core_deploy_advisory`'s existing `deployed="$REPO_ROOT/.claude/scripts/$s"` pattern.
- [ ] Validate the stage names too: a `hooks` key outside
      `{preflight, context_injection, verification, postflight}` can never fire and must be
      reported.
- [ ] Choose the **advisory** lane, not `fail()`, for the not-deployed condition, and record the
      reason in the function's header comment: a source-store edit legitimately precedes a
      deploy, so failing on undeployed-but-declared would hard-fail this gate for every caller
      until the operator regenerates — the exact reasoning `check_core_deploy_advisory` already
      records. A bad **stage name** or a hook absent from `provides.scripts`, by contrast, is a
      manifest authoring error that no deploy can fix, so those use `fail()`.
- [ ] Register the new rule in the Rule letter index comment with the next unused letter (`V` is
      the current last; confirm by reading the index rather than assuming) and add it to the
      per-extension dispatch loop next to the other manifest-entry checks.
- [ ] Add a one-line note that this rule is about the **top-level `hooks` object** (lifecycle
      hooks) and explicitly not about `provides.hooks` (the Claude-Code-native settings-hook
      file-copy array), so the two are never conflated by a future reader.
- [ ] Run the gate across all extensions and confirm the result on real data: with Phase 1's fix
      in place and all three hook scripts deployed and declared, `nix` and `nvim` should produce
      **no** new advisories or failures. If either does, that is a real finding to record, not a
      test to loosen.
- [ ] Commit.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts that **two** extensions (`nix`, `nvim`) declare a top-level `hooks`
object and **zero** declare a `verification` hook, and that the next free Rule letter is `W`.
Confirm with `jq -r 'select(.hooks) | .name' ` across every `agent-system/extensions/*/manifest.json`
and by reading the Rule letter index's last entry. A third hooks-declaring extension, or a
different next letter, invalidates the hypothesis.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - new all-extensions lifecycle-
  `hooks` path/stage-name validation rule, split across the advisory lane (not deployed) and the
  fail lane (bad stage name, or not declared in `provides.scripts`); Rule letter index entry;
  dispatch-loop registration.

**Verification**:
- `bash -n` and `shellcheck` clean vs. baseline.
- `bash .claude/scripts/check-extension-docs.sh` exits 0 with no new advisories or failures for
  `nix` or `nvim`.
- Negative probes against a throwaway fixture manifest: a `hooks` value whose basename is not
  under `.claude/scripts/` produces exactly one advisory; a bogus stage name produces exactly one
  failure; a hook basename absent from `provides.scripts` produces exactly one failure. Each
  probe must also be shown to pass once corrected.
- The Rule letter index's new entry matches the function's actual name and lane.

---

### Phase 7: Integration verification and acceptance walk-through [NOT STARTED]

**Goal**: Confirm every acceptance clause end-to-end on the integrated change set, and state
plainly what remains an operator action.

**Tasks**:
- [ ] Walk the dispatch's four acceptance clauses one at a time, recording concrete evidence for
      each in the progress file:
      1. a declared hook fires — evidence: Phase 1's sourced-subshell probe against the real
         `nix` preflight hook, plus Phase 4's fixture hook-fires case;
      2. a non-zero exit is observable under the decided disposition — evidence: Phase 4's rc
         case, plus the recorded decision (observable, never blocking) and its three
         documentation sites;
      3. the `verification` stage has a live call site — evidence: Phase 3's gate-out invocation
         and its fixture end-to-end case;
      4. the suite covers the resolver against the REAL object schema — evidence: Phase 4's
         fixture shape and its mutation check.
- [ ] Run the repository's full gate set once over the integrated change set.
- [ ] Run the three directly affected suites explicitly:
      `test-skill-base-lifecycle.sh`, `test-gate-out-repair-reporting.sh` (it covers
      `skill_validate_task_artifacts` and the gate-out report leg Phase 3 edits next to), and
      `check-extension-docs.sh`.
- [ ] Run a repo-wide `shellcheck` over the four changed shell files and compare against the
      pre-edit baseline.
- [ ] Run the task-reference lint and confirm no task-number references entered any source-store
      file.
- [ ] State explicitly, in the implementation summary, that the deployed `.claude/` tree is
      **not** updated by this task: `.claude/**` is a disposable deploy artifact and
      regeneration (`<leader>al` "Reload All", or `deploy-headless.sh`) is an operator action
      deliberately left outside this change — the more so because a sibling task is live on this
      working tree this cycle and a regeneration would sweep in its in-flight edits. Until that
      regeneration happens, the repaired mechanism is live in the source store only.
- [ ] Commit the final green state.

**Timing**: 0.5 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts **four** acceptance clauses and **three** directly affected test
suites, and **zero** files needing modification. Confirm the clause count against the dispatch's
own Acceptance section, and the suite list by `grep -rln 'skill_validate_task_artifacts\|skill_run_extension_hook\|skill_get_extension_dir' agent-system/extensions/core/scripts/tests/`
— an additional suite referencing a changed function must be run too. Any file modified in this
phase is an unplanned defect fix and invalidates the zero-files hypothesis; record it rather than
absorbing it silently.

**Files to modify**:
- none planned (verification-only phase; any file touched here is a defect found during the
  acceptance walk-through and must be recorded as such)

**Verification**:
- Each of the four acceptance clauses has a named, recorded piece of evidence.
- Full gate set exits clean.
- All three named suites exit 0.
- `shellcheck` shows no new findings across the four changed shell files.
- Task-reference lint clean.
- `git status --short` shows only this task's own intended files as modified; any foreign
  modification is reported, not committed (territory discipline).

---

## Testing & Validation

- [ ] `bash -n` passes on all four changed shell files.
- [ ] `shellcheck` reports no new findings on any changed shell file relative to a captured
      pre-edit baseline.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0,
      with the nine new hook-mechanism cases passing and every pre-existing case still passing.
- [ ] The new resolver cases provably FAIL against the old `.loaded_extensions` query (mutation
      check in Phase 4) — a test that cannot fail against the known-broken code is not coverage.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` exits 0
      (regression guard for the gate-out region Phase 3 edits).
- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with no new advisories or failures
      for `nix` or `nvim`, and the three negative fixture probes behave as specified.
- [ ] The lifecycle suite's real-tree contamination guard passes (no new mark on the real
      `specs/` tree).
- [ ] `skill_get_extension_dir nix` -> `.claude/extensions/nix` and
      `skill_get_extension_dir neovim` -> `.claude/extensions/nvim` from the edited source-store
      copy; both return empty before the change.
- [ ] Each of `.claude/scripts/nix-preflight.sh`, `nix-context.sh`, `nvim-context.sh` exits 0
      when invoked with the five real positional args.
- [ ] Task-reference lint reports no task-number occurrences in any source-store file written by
      this task.
- [ ] Repository full gate set clean.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/skill-base.sh` — repaired resolver, flat-deploy hook path
  resolution, loud unresolved-script NOTE, four `SKILL_HOOK_LAST_*` globals with unconditional
  entry reset, `deviation` event on non-zero exit, explicit terminal `return 0`.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — `task_type` read plus the live
  `verification` hook call site.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — new
  hook-mechanism group (nine cases) with a real-object-schema fixture; two functions removed from
  the residuals footer.
- `agent-system/extensions/core/docs/guides/creating-extensions.md` — rc-observability
  subsection, hook-script path-resolution rule, corrected `verification` stage mapping.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — new all-extensions lifecycle-
  `hooks` validation rule with its Rule letter index entry.
- `specs/327_repair_extension_lifecycle_hook_mechanism/summaries/01_*-summary.md` —
  implementation summary recording the acceptance evidence and the deliberately deferred
  `.claude/` regeneration.

## Rollback/Contingency

All work is confined to five files in one source-store directory and is committed per green
sub-step, so any single phase can be reverted with a targeted `git revert` of its own commit
without disturbing the others. There is no data migration, no schema change, and no state.json
mutation to undo.

The one behavioural change that reaches live runs is the three `nix`/`neovim` hooks firing for the
first time. If any of them turns out to misbehave in a way the Phase 1 direct-execution check did
not surface, the narrowest rollback is to revert Phase 1's commit alone, which returns the
resolver to its (dead) prior behaviour and re-silences every hook — the other phases are inert
without it.

Working-tree-discarding rollback should not be needed. If one becomes necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag. Do **not** take a bare reverting
`git-snapshot.sh` as a routine precaution — a sibling task is live on this working tree this
cycle, and the reverting default would discard its in-flight edits. Use `--no-revert` if a
durable non-reverting checkpoint is wanted before Phase 1.
