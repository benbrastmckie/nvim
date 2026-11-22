# Implementation Plan: Task #451

- **Task**: 451 - Take the Lean Challenge snapshot in the plan phase, where it is still meaningful, instead of leaving it to an implement phase the status gate correctly refuses
- **Status**: [NOT STARTED]
- **Effort**: 5.25 hours
- **Dependencies**: None blocking (385, 420, 435 all archived; 462 `lean_challenge_check_scope_limit` is `not_started` and is a precondition on PROMOTION only, which this plan declines -- see Decisions)
- **Research Inputs**: specs/451_snapshot_lean_challenge_at_plan_time/reports/01_hook-registration-and-postflight-bridging.md
- **Artifacts**: plans/01_challenge-snapshot-observer-wiring.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/context/standards/artifact-management.md
  - .claude/context/reference/tasks.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Lean Challenge snapshot has no owner in the task lifecycle: nothing invokes
`lean-challenge-snapshot.sh`, so the only thing that ever asks for a snapshot is a plan that
writes "take the snapshot" into a phase body -- which by construction executes during IMPLEMENT,
exactly the status the script's exit-73 gate correctly refuses. This plan gives the snapshot a
real producing call site at the moment the status gate still admits it (the plan cycle's
postflight, where the persisted status is `planned`), and gives `--check` its first-ever
consuming call site on the implement side, by declaring a **post-task observer** in the lean
extension's manifest. Done means: a lean4 task whose plan carries a populated
`## Lean Challenge Statements` section gets a manifest under its own `challenge/` directory
without anyone asking, a later `--check` exits 0 instead of 71, the exit-73 gate and its
`PRE_IMPLEMENTATION_STATUSES` set are provably unchanged, and every ruling the originating
change request asked for is recorded in the design record rather than left implicit.

### Research Integration

The research report's structural diagnosis is adopted in full: the defect is that the producing
side is **unowned**, not mistimed, so `--check` has provided no value on any lean4 task to date.
Its rulings on idempotence (refuse -- inherited free from the script's existing exit-73
manifest-exists refusal), on both inertness constraints (non-lean task type; zero-theorem plan,
the latter already satisfied by the landed `<!-- lean-challenge-statements:none -->` marker and
its side-effect-free exit 72), on the manifest location (`specs/{NNN}_{SLUG}/challenge/manifest.json`,
settled and not relitigated), on `project_root` defaulting to `.` with the single-repo assumption
recorded explicitly, and on declining `--check` promotion are all carried into this plan.

Its **registration recommendation is superseded**, on evidence re-derived at plan time. The report
recommended a `postflight` lifecycle hook plus a core `TASK_TYPE="$task_type"` bridging fix in
`orchestrate-cycle-postflight.sh`. Two facts found at plan time defeat that route and make a
third option strictly better; both are detailed under Decisions below. The report's own
"Context Extension Recommendations" item (document the postflight `TASK_TYPE` precondition in
core's `creating-extensions.md`) is consequently dropped as already-satisfied: that document
already carries the gap at its "Observers vs. Lifecycle Hooks" section.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation
was performed and no roadmap phases are included.

## Premise Re-Validation

Every figure the dispatch flagged under Carried-Figure Discipline was re-derived by direct read of
the source store on 2026-11-22, at plan time. Results, stated explicitly even where they only
confirm the description:

| Carried claim | Verdict | Re-derived fact |
|---|---|---|
| Source store is the edit target (`agent-system/extensions/{lean,core}/**`) | **CONFIRMED** | `.claude-extensions.json` resolves both `source_dir` values to `/home/benjamin/.config/nvim/agent-system/extensions/{lean,core}` |
| `lean-challenge-snapshot.sh` hard-codes `PRE_IMPLEMENTATION_STATUSES="not_started researching researched planning planned"` | **CONFIRMED verbatim** | line 1004; consumed by the gate loop at line 1021 |
| Status-gate refusal is exit 73 | **CONFIRMED** | `exit 73` at line 1032 (status gate) and line 1046 (manifest-exists refusal) |
| `--check` exits 71 when no manifest exists | **CONFIRMED** | `do_check()` (line 271) exits 71 at the `[ ! -f "$manifest_path" ]` branch. Note the exit-code table in `challenge-snapshot.md` describes 71 only as "Config error -- identifier-set mismatch", which is narrower than the code's actual uses of 71; Phase 4 widens that row |
| `extensions/lean/manifest.json` has a top-level `hooks` value of `null` | **CORRECTED** | The key is **absent entirely**, not null. Top-level keys are: `dependencies, description, hard_contracts, merge_targets, name, provides, routing_agents, task_type, version`. (`provides.hooks` exists and is a different, file-copy field: `["lean-lsp-register-project.sh"]`) |
| Hook mechanism is in production use by nix (preflight, context_injection) and nvim (context_injection) | **CONFIRMED**, and the report's sharpening holds: **neither declares `postflight`** | `nix/manifest.json` -> `{"preflight": ..., "context_injection": ...}`; `nvim/manifest.json` -> `{"context_injection": ...}` |
| The postflight hook call passes `"${TASK_TYPE:-}"`, which `orchestrate-cycle-postflight.sh` never sets | **CONFIRMED** | `skill-base.sh:1193`; `grep -c '\bTASK_TYPE\b' orchestrate-cycle-postflight.sh` = **0** |
| ...and the same is true of `TASK_DIR` (research report's framing) | **CORRECTED** | `TASK_DIR` **is** set, as an uppercase global, at `orchestrate-cycle-postflight.sh:439-440`. Only `TASK_TYPE` is missing |
| The hook mechanism is non-blocking by construction | **CONFIRMED** | `skill_run_extension_hook` (`skill-base.sh:214`) always `return 0` |
| `lean-challenge-snapshot.sh` IS deployed and IS listed in `provides.scripts`, contradicting its own comment | **CONFIRMED on both halves** | present in `provides.scripts`; the contradicting comment is at line **97** ("`itself deployed as a Claude Code artifact -- see manifest.json`", the second line of a sentence beginning on line 96) |
| The advisory stance is asserted in exactly three places that must move together | **CONFIRMED, all three exist** | `lean-challenge-snapshot.sh:25` (`GATE STRENGTH:` header block), `rules/plan-compliance.md:61` (`ADVISORY ONLY`), `challenge-snapshot.md:157` (`## Gate Strength: Advisory Only`) |
| 462's false-ambiguity defect is unlanded, so promotion's precondition is unmet | **CONFIRMED** | `specs/state.json`: project 462 `lean_challenge_check_scope_limit`, status `not_started` |
| 385 / 420 / 435 are archived and do not block | **CONFIRMED** | none present in `active_projects` |

**Carried-unverified, by nature.** The incident narratives and measured costs from
BimodalLogic:#761 (three Goal signatures hand-diffed) and Logos/Theory:358 (13 Goals identifiers,
four pinned null-state signatures plus `sound_c4-c7` and `valid_m1/m2`) happened in other
repositories and are **not re-measurable from here**. They are carried as motivation only; no
phase below depends on either figure being exact.

## Goals & Non-Goals

**Goals**:
- Give the snapshot a producing call site that fires while the persisted status is still
  `planned`, so the exit-73 gate is made *irrelevant* rather than weakened.
- Give `--check` its first consuming call site, on the implement side of the same seam.
- Make the wiring provably inert for a non-lean4 task and for a lean4 plan that commits to no
  theorem, and provably non-blocking on the plan phase.
- Record, in the design record and the rule, every ruling the originating change request asked
  for: the registration site and why, the re-plan behaviour, the `--check`
  advisory-vs-blocking verdict, the `project_root` single-repo limitation, and the new
  structural side effect on the target project's git history.
- Correct the two now-false claims in `lean-challenge-snapshot.sh`'s own header comments.

**Non-Goals**:
- Weakening the exit-73 status gate, narrowing `PRE_IMPLEMENTATION_STATUSES`, or adding an
  automatic `--force` anywhere. Explicitly out of bounds.
- Relitigating the manifest location (`specs/{NNN}_{SLUG}/challenge/manifest.json`) or the
  R1-vs-R2 extraction decision. Both settled.
- Promoting `--check` to a blocking gate. Declined with reasons recorded -- see Decisions.
- Editing ANY file under `agent-system/extensions/core/**`. This plan touches zero core files;
  see Decisions for why the research report's core bridging fix is not performed.
- Adding a `--check` call site inside `lean-implementation-agent.md` or
  `lean-implementation-hard-agent.md`. The observer serves both sides from one registration, so
  neither agent file is declared in any phase's `Files to modify`.
- Fixing the `postflight` lifecycle-hook `TASK_TYPE` gap. Real, generic, and out of scope here;
  recorded as a finding for a separate record rather than carried by this one.
- Supporting a Lean project nested below the repo root, or living in a different repository from
  the `specs/` tree that drives it. Recorded as a stated limitation, not implemented.

**Authoring constraint on every file below.** Every file landing under `agent-system/**` is a
deliverable: it MUST carry no task-number references (`.claude/rules/no-task-references-in-deliverables.md`)
and no record-versioning language -- no "previously", "no longer", "formerly", "supersedes",
"v1"/"v2" labels (`.claude/rules/no-record-versioning-in-deliverables.md`). Both are permitted in
THIS plan and anywhere else under `specs/**`. Phases 1-4 each state the current design on its own
merits; where a phase corrects a now-false claim, it REPLACES the sentence rather than annotating
its history.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The observer script is created on disk but never added to `manifest.json`'s `provides.scripts`, so it deploys nothing and resolves as `missing_script` -- a silent no-op with only a deviation event | H | M | Phase 2 uses `sync-manifest-scripts.sh --check` then `--write` (the sanctioned derive-from-disk repair) rather than hand-editing the array, and Phase 3 does not accept until a real invocation is observed post-deploy. `check-extension-docs.sh` Rule Q independently detects an undeclared script |
| Observer resolution silently matches nothing (typo in `task_type`, malformed `observers` block) | H | L | `check-extension-docs.sh` Rule X validates the block's shape and rejects stray keys; Phase 3 pins resolution with `run-task-observers.sh --dry-run`, which prints one `would invoke observer ... matched_on=<k>` line per match and invokes nothing |
| The snapshot's git commit into the TARGET Lean project exceeds the observer's `timeout_seconds`, producing a timeout (rc 124) and no manifest | M | M | Declare `timeout_seconds: 120` rather than inheriting the 30s default, and record the reasoning in the design record. A timeout is already the correct degraded outcome (warning plus no manifest), not a failure |
| Every qualifying lean4 plan cycle now commits to the target project's own git history automatically, where today that happens only on deliberate human invocation -- commit volume in that history increases structurally | M | H (by design) | This is the intended mechanism, not a defect: a Challenge the agent can rewrite certifies nothing, and git is the immutability anchor. Phase 4 documents it as an expected, intentional side effect. No code mitigation |
| Task 462 (`not_started`) declares three of this plan's files (`lean-challenge-snapshot.sh`, its test suite, `challenge-snapshot.md`) in its own `file_scope` | M | M | 462 is not in this cycle's `concurrent_siblings` set, so there is no in-cycle contention. Phase 4's edits to `lean-challenge-snapshot.sh` are confined to two comment regions (lines ~25-30 and ~96-100), which do not touch the `--check` body 462 will rework |
| Four sibling tasks (398, 463, 504, 537) are dispatched this same cycle on this same tree; 504 declares `core/context/formats/plan-format.md` and 537 declares `lean/agents/lean-implementation-agent.md` | M | M | No declared path of this plan appears in any sibling's `file_scope` (checked entry by entry). Per the dispatch's concurrency note, re-read every file immediately before editing, stage only this task's own hunks by explicit file list, and never run `git-snapshot.sh` in its reverting default mode |
| The observer fires only under `/orchestrate`'s own cycle -- a lean4 plan produced by `/revise` or a standalone dispatch gets no snapshot | L | M | Accepted and recorded as a limitation in Phase 4. `/orchestrate` is the only dispatch path for a lean4 plan today (the lean extension provides no plan skill), so the gap is latent rather than live |

## Decisions

- **Registration site: a post-task OBSERVER declared in `extensions/lean/manifest.json`'s
  `observers` object, matched on `task_type: "lean4"`.** This is neither of the dispatch's two
  options, and it supersedes the research report's recommendation of option (a). Two facts
  re-derived at plan time decide it:

  1. **The `postflight` lifecycle hook cannot fire on this path without a core edit that core's
     own documentation forbids.** `docs/guides/creating-extensions.md`'s "Observers vs. Lifecycle
     Hooks" section already records the `TASK_TYPE` gap the research report rediscovered, and
     carries an explicit directive against the exact repair the report proposed: *"Do not 'fix'
     this by plumbing `TASK_TYPE` through the postflight hook as a substitute."* That directive's
     stated rationale concerns a topic-grouped seam rather than our `task_type`-equality case, so
     it is not on its own terms a prohibition on our use -- but with a strictly better route
     available, editing a heavily-trafficked core script against the grain of its own guide is
     not justified.
  2. **The observer seam has no such gap, and already does exactly what this task needs.** Its
     one invocation site is `orchestrate-cycle-postflight.sh`'s completion path, where it is
     passed the correctly-resolved **local** `task_type` (not the empty `TASK_TYPE` global) and a
     freshly-read `persisted_status`. Its own call-site comment records that it is *"deliberately
     NOT gated on dispatch_status/have_outcome/research_gate_failed"* -- so it fires once per
     dispatch for research, plan and implement alike, gated on `is_live` only.

  Measured against the dispatch's own criteria, the observer wins on every axis: it is
  extension-local (the dispatch's stated preference), needs **zero** core edits (where option (b)
  needed a core edit and option (a) needed one too, once the gap is accounted for), is advisory
  and non-blocking **by explicit written contract** rather than by inheritance ("an observer can
  never change task status, never fail a dispatch, never block"; its return code is recorded as
  one `task_observer_run` event and otherwise ignored), is bounded by a `timeout`, and is already
  proven in production by the books extension's `books-observe.sh` plus its own
  `tests/test-books-observe.sh`. It also discriminates on a BETTER key than the lifecycle hook's
  `$operation`: `$6 resting_status` is the very status the exit-73 gate evaluates, so producing
  only on `planned` can never fight the gate.

  Option (a) is therefore not "demonstrated unworkable" so much as demonstrated unnecessary, and
  option (b) is moot. The dispatch's instruction to record the reason is discharged here and
  again in the design record at Phase 4.

- **The core `TASK_TYPE` postflight-hook gap is NOT fixed by this plan.** It is real, generic, and
  affects every extension's `postflight` hook on the `/orchestrate` path. But no goal of this task
  needs it once the observer route is taken, and `creating-extensions.md` already documents the
  gap for the next author. Fixing it belongs to its own record, with its own test coverage of the
  six `skill_postflight_update` call sites it would change. This plan touches no core file.

- **Re-plan / idempotence behaviour: REFUSE.** Not version, not require-explicit-regeneration.
  This is already `lean-challenge-snapshot.sh`'s tested behaviour -- exit 73 on an existing
  manifest without `--force`, evaluated independently of the status gate -- so an observer that
  invokes the script plainly inherits "refuse" with zero new logic. The immutability mechanism is
  load-bearing: a Challenge the agent can silently overwrite certifies nothing. Phase 3 pins this
  in both directions and Phase 4 records it.

- **`--check` advisory-vs-blocking: PROMOTION DECLINED, verdict stays ADVISORY.** The deliverable
  the change request asked for is a recorded ruling, and this is it, on two independent grounds.
  (i) The dispatch names 462's false-ambiguity defect as a hard precondition for promotion; 462 is
  `not_started`, so a blocking check could fail on a correct tree because a research prototype
  under `specs/` declares a pinned name -- worse than no check. (ii) `challenge-snapshot.md`'s own
  "Gate Strength: Advisory Only" section conditions promotion on *"evidence from real runs"*, and
  until this plan lands the first-ever `--check` call site there have been **zero** real runs to
  gather evidence from. Declining is therefore not deferral by default: promoting now would
  invert the order the design record itself sets. Phase 4 records the ruling at all three sites
  that assert the stance, so they continue to agree.

- **`project_root` defaults to `.`, with the single-repo assumption stated rather than hidden.**
  Every existing caller in the lean toolchain takes `project_root` as an explicit, non-defaulted
  argument and assumes the Lean project and the `specs/` tree share one git repository. The
  observer runs with the repo root as its working directory, which is exactly what
  `lean-challenge-snapshot.sh`'s own CWD convention requires, so `.` is correct for that layout
  and wrong for any other. Phase 1 passes `.` explicitly; Phase 3 pins the CWD convention; Phase 4
  records the limitation as a limitation.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author the Challenge observer and its regression suite [NOT STARTED]

**Goal**: A new `lean-challenge-observe.sh` that discriminates purely on its sixth positional
argument (`resting_status`) -- producing a snapshot on `planned`, running `--check` on the
implement-side statuses, and no-op on everything else -- plus a suite that proves that
discrimination by direct invocation, before any manifest or deploy work exists.

**Tasks**:
- [ ] Create `agent-system/extensions/lean/scripts/lean-challenge-observe.sh`, modelled
      structurally on `agent-system/extensions/books/scripts/books-observe.sh` (the live observer
      precedent). Header must state the six-positional-argument contract verbatim
      (`$1 task_number  $2 task_type  $3 topic  $4 task_dir  $5 session_id  $6 resting_status`)
      and the advisory/non-blocking contract.
- [ ] Implement the status discrimination as a single `case "$6" in` block:
      `planned)` -> invoke `lean-challenge-snapshot.sh "$1" "."` with **no** `--force`;
      `implementing|partial|pr_ready|completed)` -> invoke `lean-challenge-snapshot.sh --check "$1" "."`;
      `*)` -> no-op. Resolve the snapshot script by basename against `.claude/scripts/`, the same
      resolution contract `run-task-observers.sh` itself uses for the observer.
- [ ] Reimplement no plan-content classification in the observer. Let the snapshot script's own
      exit-code vocabulary (0 / 65 / 71 / 72 / 73) carry every outcome; the observer echoes the
      code to stderr for the captured event and nothing more.
- [ ] Make every live-mode path `exit 0` unconditionally, whatever the snapshot script returned --
      matching `books-observe.sh`'s own rule that the only non-zero exit is a usage error in the
      observer's own arguments.
- [ ] Guard against a missing snapshot script: if `.claude/scripts/lean-challenge-snapshot.sh` is
      absent or not executable, emit one stderr NOTE and exit 0. Never fail.
- [ ] Create `agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh`, modelled
      on `agent-system/extensions/books/scripts/tests/test-books-observe.sh` (pass/fail counters,
      `mktemp -d` workdir with a `trap EXIT` cleanup, a stub snapshot script on the resolution path
      so no real git commit occurs).
- [ ] Assert in that suite: `planned` invokes the snapshot WITHOUT `--force` (grep the stub's
      recorded argv for the absence of `--force`); each of `implementing`, `partial`, `pr_ready`,
      `completed` invokes it WITH `--check`; `researched`, `planning`, `blocked`, `abandoned` and
      an unknown value each invoke it zero times; a stub that exits 73 still leaves the observer's
      own exit code 0; a missing stub still leaves it 0.
- [ ] Assert that the observer passes `.` as `project_root` and relies on its inherited working
      directory, so the single-repo assumption is pinned in a test rather than only in prose.
- [ ] `chmod +x` both new files.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Two new files, zero modified files, and `suite_selection_select` over both
paths returns the sentinel alone because neither file exists yet. Confirm at implementation time
by re-running the selector AFTER the suite file is created -- it will then map
`tests/test-lean-challenge-observe.sh` to itself, changing the measured output for this phase and
for Phase 3. That shift is expected, not a contradiction of this hypothesis. The claim that
`books-observe.sh` and `test-books-observe.sh` are usable structural models is carried from this
plan's own plan-time read of `agent-system/extensions/books/`; re-read both before copying any
idiom, since neither is pinned.

**Tier Justification**: `suite_selection_select` over both paths returns `__FULL_SWEEP__` alone --
neither file exists yet, so no suite covers them and none is claimed here -- and the covering
check is `bash agent-system/extensions/core/scripts/verify-touched.sh` over both paths together
with the `local` row's own diff read-through.

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-challenge-observe.sh` - CREATE. The observer: status discrimination on `$6`, always exit 0, no plan-content classification of its own.
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` - CREATE. Direct-invocation regression suite against a stub snapshot script.

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` exits 0 with
  every assertion above passing, and its own output names the count of assertions run.
- `bash -n` on both new files, plus `shellcheck` if available, exit clean.
- Both files are executable (`test -x`).
- No real `git commit` occurred during the suite run: `git -C . status --porcelain` and
  `git -C . log -1 --format=%H` are unchanged across the run.

---

### Phase 2: Register the observer and derive `provides.scripts` [NOT STARTED]

**Goal**: The observer is declared in the lean manifest with a validated `observers` block and a
non-default timeout, and both new scripts reach `provides.scripts` through the sanctioned
derive-from-disk repair rather than a hand edit.

**Tasks**:
- [ ] Add an `observers` object to `agent-system/extensions/lean/manifest.json` with a single key
      `lean-challenge-observe`: `script` = `scripts/lean-challenge-observe.sh`, `task_type` =
      `lean4`, `timeout_seconds` = `120`. Declare **no** `topic` key -- this seam is
      `task_type`-keyed by design, and Rule X rejects any key outside the allowed set.
- [ ] Record the `timeout_seconds: 120` choice in the manifest's own adjacent context only if the
      schema admits it; otherwise carry the reasoning to Phase 4's design-record edit instead of
      inventing a manifest key Rule X will reject.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` and read
      its report: it should name both Phase 1 files as undeclared.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` to derive
      `provides.scripts` from the tracked `scripts/` tree, then re-run `--check` and confirm it is
      clean.
- [ ] Confirm the top-level `hooks` key is still **absent** from the lean manifest. This plan adds
      no lifecycle hook; a stray `hooks` object would be an unintended second seam.
- [ ] Review the resulting `manifest.json` diff hunk by hunk before staging, and stage that one
      file by explicit path.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Exactly one modified file (`manifest.json`), with the `observers` object
added and `provides.scripts` gaining exactly two entries. Confirm at implementation time by
`git diff --stat` naming one file, and by diffing the `provides.scripts` array length before and
after `--write` (expected delta: +2). If `--write` reorders or removes unrelated entries, stop and
report rather than accepting a wider diff.

**Tier Justification**: `manifest.json` is consumed by enumerated direct dependents beyond the
lean extension -- observer resolution, routing, deploy and manifest-sync -- and
`bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/lean/manifest.json`
covers that whole mapped set, which it resolves and runs itself rather than from any subset named
here.

**Files to modify**:
- `agent-system/extensions/lean/manifest.json` - add the `observers.lean-challenge-observe` block; `provides.scripts` gains both Phase 1 scripts via `sync-manifest-scripts.sh --write`.

**Verification**:
- `jq -e '.observers["lean-challenge-observe"] | .script and .task_type' agent-system/extensions/lean/manifest.json`
  exits 0, and `jq -r '.observers["lean-challenge-observe"].timeout_seconds'` prints `120`.
- `jq -e 'has("hooks") | not' agent-system/extensions/lean/manifest.json` exits 0 (no lifecycle
  hook was added).
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports Rule X and Rule Q
  clean for the lean extension, checked on its exit status and not only on absent output.
- `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits clean.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/lean/manifest.json`
  exits 0.

---

### Phase 3: Deploy, then pin end-to-end firing and the untouched gate [NOT STARTED]

**Goal**: With the observer deployed, prove it actually fires for a lean4 task at `planned`,
prove it is inert for a non-lean task type, prove a failing observer cannot fail the plan phase,
and pin that this plan changed nothing about the exit-73 gate, `PRE_IMPLEMENTATION_STATUSES`, or
`--force`'s incident-shaped warning.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree, so
      `.claude/scripts/lean-challenge-observe.sh` exists and is executable. Confirm both with
      `test -x`; a `missing_script` or `not_executable` observer skip is the exact silent failure
      this step exists to rule out.
- [ ] Budget for a second `deploy-headless.sh` run if `check-extension-docs.sh` fires on
      registration completeness after the first.
- [ ] Extend `agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` with a
      resolution assertion driven by `run-task-observers.sh --dry-run`: for
      `--task-type lean4 --status planned` it prints exactly one
      `would invoke observer lean-challenge-observe (...) matched_on=...` line and invokes
      nothing.
- [ ] Add the inertness assertion on the same path: `--task-type general` and `--task-type nix`
      each resolve **zero** observer matches for this extension, so the observer is unreachable
      for a non-lean4 task.
- [ ] Add the non-blocking assertion: an observer script forced to exit non-zero, and one forced
      to hang past its timeout, each leave `run-task-observers.sh` exiting 0 -- so a plan phase
      can never fail because a snapshot could not be taken.
- [ ] Add the CWD assertion: the observer resolves `specs/` relative to the working directory it
      inherits, and is invoked from the repo root that owns `specs/`.
- [ ] Extend `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` with
      regression pins, each asserted on the script's own exit status:
      (i) `PRE_IMPLEMENTATION_STATUSES` still equals `not_started researching researched planning planned`
      exactly -- assert against the literal string, not a substring;
      (ii) a snapshot attempted at status `implementing` still exits 73;
      (iii) `--force` still emits its incident-shaped warning;
      (iv) the re-plan refusal in **both** directions -- a second plain invocation against an
      existing manifest exits 73 and leaves the manifest byte-identical, while the same invocation
      with `--force` overwrites it and warns.
- [ ] Add the acceptance pin the symptom actually names: after a `planned`-status observer run
      produces a manifest, a subsequent `--check` exits **0** rather than 71.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Two modified test suites plus one whole-tree regeneration, and
`suite_selection_select` over the two suite paths measured `test-lean-challenge-snapshot.sh` as
the only mapped suite at plan time -- because `tests/test-lean-challenge-observe.sh` did not yet
exist. Confirm at implementation time by re-running the selector over both paths once Phase 1 has
landed; it is expected to name both suites then. The byte-identical-manifest assertion in task
(iv) assumes the manifest write is deterministic for a fixed input; confirm by running the refused
invocation twice and comparing hashes, and if it is not deterministic, pin the refusal via the
exit code and an unchanged mtime instead.

**Tier Justification**: This phase invokes whole-tree regeneration via `deploy-headless.sh`, whose
blast radius is every deployed artifact in `.claude/**` -- a cross-cutting surface no module- or
interface-scoped check covers, which is why the sentinel `` `__WHOLE_TREE__` `` is declared below
alongside the two real paths.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` - add the end-to-end resolution, inertness, non-blocking and CWD assertions.
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` - add the gate-unchanged, `--force`-warning, re-plan-both-directions and `--check`-exits-0 pins.
- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, an implicit scope claim over the entire deployed tree that no real declared path can express.

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` and
  `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` both exit 0,
  with every assertion above reported as run rather than skipped.
- `test -x .claude/scripts/lean-challenge-observe.sh` succeeds.
- `bash .claude/scripts/run-task-observers.sh --task 451 --task-type lean4 --topic "" --task-dir specs/451_snapshot_lean_challenge_at_plan_time --session plan-verify --status planned --dry-run`
  prints exactly one `would invoke observer lean-challenge-observe` line and exits 0.
- The same command with `--task-type general` prints no such line and exits 0.
- `git diff --stat` over the lean extension names only the two declared suite files; the deployed
  tree is gitignored and contributes nothing to the commit.
- `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh`
  exits 0. The complete gate set is NOT run here -- it is owed once per orchestration invocation
  and is deferred to the orchestration close, per Phase 5.

---

### Phase 4: Record every ruling, and correct the two now-false header claims [NOT STARTED]

**Goal**: The design record and the rule state the current design on its own merits -- where the
snapshot is produced, where `--check` is consumed, what a re-plan does, why promotion is declined,
what `project_root` assumes, and what the new commit-volume side effect is -- and
`lean-challenge-snapshot.sh`'s own header stops asserting two things that are no longer true.

**Tasks**:
- [ ] In `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`, add a
      section naming the producing call site: the `lean-challenge-observe` observer, invoked from
      `orchestrate-cycle-postflight.sh`'s completion path, discriminating on `resting_status`, and
      producing a snapshot only at `planned` -- the one plan-cycle resting status the exit-73 gate
      already admits, so the producing site never fights the gate.
- [ ] In the same file, name the consuming call site (the same observer at the implement-side
      statuses) and record why the observer seam was chosen over a `postflight` lifecycle hook or
      a core call: extension-local, zero core edits, advisory and non-blocking by written
      contract, bounded by `timeout`, and discriminating on the very status the gate evaluates.
- [ ] Record the re-plan ruling in that file: REFUSE, inherited from the existing exit-73
      manifest-exists refusal, because a Challenge the agent can silently overwrite certifies
      nothing. State that `--force` remains the only override and remains incident-shaped.
- [ ] Record the `timeout_seconds: 120` choice and its reason (the snapshot commits into the
      target project's git history, which can exceed the 30-second default on a loaded host; a
      timeout degrades to a warning plus no manifest, which is the correct failure mode).
- [ ] Record the `project_root` limitation plainly: the observer passes `.` and inherits the repo
      root as its working directory, so a Lean project nested below the repo root, or living in a
      different repository from the `specs/` tree, is not supported by this seam.
- [ ] Record the structural side effect: every qualifying lean4 plan cycle now commits a Challenge
      into the target project's own history automatically. State it as the intended immutability
      mechanism, not a defect.
- [ ] Record the `/orchestrate`-only reach: the observer's single invocation site means a lean4
      plan produced outside `/orchestrate`'s own cycle gets no snapshot.
- [ ] Widen that file's exit-code table row for `71` so it covers `do_check()`'s manifest-absent
      and unreadable-trust-anchor uses, not only the identifier-set mismatch it currently names.
- [ ] Amend the `## Gate Strength: Advisory Only` section (confirmed present at line 157) to
      record the ruling: promotion is DECLINED, on the two grounds in this plan's Decisions
      section -- 462's unlanded false-ambiguity defect, and the section's own "evidence from real
      runs" test, which this seam's first-ever call site has not yet had the chance to satisfy.
      Keep the advisory verdict itself unchanged.
- [ ] In `agent-system/extensions/lean/rules/plan-compliance.md`, amend the `ADVISORY ONLY`
      paragraph (confirmed present at line 61) to note that `--check` now has a real call site and
      that its verdict is nonetheless retained as advisory, with the reason in one line. Leave the
      existing escalation route (mark the phase `[BLOCKED]` and raise it; never quietly edit the
      recorded Challenge) exactly as written.
- [ ] In `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`, replace the false
      clause at line 97 -- which asserts the script "is not itself deployed as a Claude Code
      artifact -- see manifest.json" -- with the correct statement: it IS listed in
      `provides.scripts` and IS deployed executable into consumer trees. Keep the surrounding CWD
      convention, which is accurate and load-bearing, intact. Re-derive the line number before
      editing; the sentence begins on the preceding line.
- [ ] In the same file's `GATE STRENGTH:` header block (confirmed present at line 25), replace the
      clause asserting the script is "a standalone CLI, not wired into any completion gate by this
      script or by anything else in this source tree". Half of it is now false and half is still
      true, so state both precisely: it IS invoked by the `lean-challenge-observe` observer, and it
      is still wired into no completion gate, because an observer's return code is recorded as an
      event and otherwise ignored.
- [ ] Both edits to `lean-challenge-snapshot.sh` are comment-only. Do not touch the status gate,
      `PRE_IMPLEMENTATION_STATUSES`, `do_check()`, or any executable line.
- [ ] Declare `index-entries.json` below but do NOT hand-edit its `line_count`: this phase moves
      `challenge-snapshot.md`'s line count, and Phase 5 reconciles the derived value with the
      sanctioned generator.
- [ ] State every ruling on its own merits. No task numbers and no record-versioning language in
      any of these four files.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Four declared files, of which `lean-challenge-snapshot.sh` is edited in
exactly two comment regions (around lines 25-30 and 96-100) and `index-entries.json` is declared
but not hand-edited in this phase. Confirm at implementation time with
`git diff -- agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`, checking that every
changed hunk lies inside a `#` comment region and that no executable line moved. All four line
citations (25, 61, 97, 157) were re-derived at plan time from the source store, but line numbers
drift -- re-derive each before editing rather than trusting the number.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over the
four declared paths covers the edit -- every changed hunk is a comment, a prose line, or a
generated numeric field -- and it resolves and runs the whole mapped suite set itself rather than
any subset named here.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` - EXISTS (221 lines, confirmed at plan time). Add the producing/consuming call sites, the registration rationale, the re-plan ruling, the timeout reasoning, the `project_root` and `/orchestrate`-only limitations, the commit-volume side effect; widen the exit-71 row; record the declined promotion in `## Gate Strength: Advisory Only`. If the file is absent at implementation time, stop and report rather than recreating it -- the design record is the durable carrier for every ruling above and has no substitute.
- `agent-system/extensions/lean/rules/plan-compliance.md` - EXISTS (97 lines, confirmed at plan time). Amend the `ADVISORY ONLY` paragraph to note the new call site and the retained advisory verdict. If absent at implementation time, record the ruling in the design record alone and report the gap.
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` - EXISTS (confirmed at plan time). Comment-only: correct the deployment claim near line 97 and the standalone-CLI claim in the `GATE STRENGTH:` block near line 25. If either clause is already absent or already corrected at implementation time, skip that edit and say so rather than inventing a target.
- `agent-system/extensions/lean/index-entries.json` - EXISTS, and carries `line_count: 221` for `project/lean4/domain/challenge-snapshot.md`. Declared here because this phase moves that derived quantity; `check-extension-docs.sh` Rule R is advisory in this repository (no `pre-commit` hook is installed, verified at plan time), so the regeneration itself is permitted to land in Phase 5.

**Verification**:
- `git diff -- agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` shows changed
  hunks confined to `#` comment lines, and `bash -n` on the script exits clean.
- `grep -c "not itself deployed\|itself deployed as a Claude Code artifact" agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
  returns 0.
- `grep -n "PRE_IMPLEMENTATION_STATUSES=" agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
  still prints the unchanged literal
  `PRE_IMPLEMENTATION_STATUSES="not_started researching researched planning planned"`.
- `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` exits 0 --
  comment edits broke nothing.
- `bash .claude/scripts/check-task-references.sh` over the four declared paths reports no
  task-number occurrence, checked on exit status.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md agent-system/extensions/lean/rules/plan-compliance.md agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh agent-system/extensions/lean/index-entries.json`
  exits 0.

---

### Phase 5: Reconcile the derived index and close [NOT STARTED]

**Goal**: The `index-entries.json` line count Phase 4 moved is reconciled with the sanctioned
generator, the deployed tree matches the source store, and the task closes with its scoped
touched-path evidence plus an explicit deferral of the complete gate set to the orchestration
close.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh` to derive
      `line_count` for every indexed lean context file, including the one Phase 4 moved.
- [ ] Confirm the only `index-entries.json` change is the `line_count` for
      `project/lean4/domain/challenge-snapshot.md`; a wider diff means something else moved and
      should be reported, not accepted.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the
      source store, so `.claude/**` matches every Phase 1-4 edit.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm Rules Q,
      R and X are all clean for the lean extension, on exit status.
- [ ] Confirm the acceptance criterion the whole task exists for, end to end: a lean4 task at
      status `planned` with a populated `## Lean Challenge Statements` section produces a manifest
      under its own `challenge/` directory via the observer, and a later `--check` exits 0 rather
      than 71.
- [ ] Record this dispatch's issues and wins via `issue-record.sh` as they arise, and attest
      explicitly in the handoff if there was genuinely nothing to record.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: One modified file (`index-entries.json`, one `line_count` field) plus one
whole-tree regeneration. Confirm with `git diff --stat`, expecting exactly one tracked file
changed, and with `git diff -- agent-system/extensions/lean/index-entries.json` showing a single
numeric field moving. If the generator rewrites unrelated entries' formatting, report the wider
diff rather than committing it silently.

**Files to modify**:
- `agent-system/extensions/lean/index-entries.json` - reconcile the `line_count` for `project/lean4/domain/challenge-snapshot.md` via `generate-context-line-counts.sh`. EXISTS and already carries that entry.
- `__WHOLE_TREE__` - this phase runs `deploy-headless.sh`, an implicit scope claim over the entire deployed tree.

**Verification**:
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh` exits 0, and a
  second run of it produces no further diff (the value has converged).
- `jq -r '.entries[] | select(.path == "project/lean4/domain/challenge-snapshot.md") | .line_count' agent-system/extensions/lean/index-entries.json`
  equals `wc -l < agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0 for the lean
  extension with Rules Q, R and X clean.
- Every suite this task touched passes:
  `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` and
  `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` each exit 0.
- **In-dispatch obligation under `/orchestrate`**:
  `bash .claude/scripts/verify-touched.sh agent-system/extensions/lean/index-entries.json agent-system/extensions/lean/manifest.json agent-system/extensions/lean/scripts/lean-challenge-observe.sh agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md agent-system/extensions/lean/rules/plan-compliance.md agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh`
  exits 0 over this task's complete touched set.
- **The complete gate set is deferred to the orchestration close**, not run as this phase's own
  criterion: it is owed once per `/orchestrate` invocation and is discharged at the
  once-per-invocation batch gate stage. Under a standalone, non-orchestrated run of this plan with
  no orchestration close to defer to, this phase instead runs
  `bash .claude/scripts/verify-deploy.sh` directly.

---

## Testing & Validation

- [ ] The observer invokes the snapshot WITHOUT `--force` at `planned`, and with `--check` at
      `implementing`, `partial`, `pr_ready` and `completed`.
- [ ] The observer is a no-op at `researched`, `planning`, `blocked`, `abandoned` and any
      unrecognized status.
- [ ] The observer resolves zero matches for `task_type` values other than `lean4` -- inert for a
      non-lean task.
- [ ] A lean4 plan carrying the `<!-- lean-challenge-statements:none -->` zero-goal marker yields
      the script's side-effect-free exit 72 and no manifest, with no new classification logic in
      the observer.
- [ ] A non-zero observer exit, and an observer that hangs past its `timeout_seconds`, each leave
      `run-task-observers.sh` exiting 0 -- a plan phase can never fail because a snapshot could not
      be taken.
- [ ] `PRE_IMPLEMENTATION_STATUSES` still equals its exact original literal, asserted against the
      whole string rather than a substring.
- [ ] A snapshot attempted at status `implementing` still exits 73, and `--force` still emits its
      incident-shaped warning.
- [ ] Re-plan behaviour pinned in both directions: a second plain invocation against an existing
      manifest exits 73 and leaves the manifest unchanged; the same invocation with `--force`
      overwrites it and warns.
- [ ] After a `planned`-status observer run, a subsequent `--check` exits 0 rather than 71 -- the
      acceptance criterion the originating symptom names.
- [ ] The observer resolves `specs/` relative to its inherited working directory and passes the
      target project root explicitly, pinned in a test rather than only in prose.
- [ ] `check-extension-docs.sh` Rules Q, R and X all clean for the lean extension.
- [ ] No file under `agent-system/**` gained a task-number reference or record-versioning
      language.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-challenge-observe.sh` (new) -- the observer.
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` (new) -- its
  regression suite, covering discrimination, inertness, non-blocking behaviour and the CWD
  convention.
- `agent-system/extensions/lean/manifest.json` -- the `observers.lean-challenge-observe`
  declaration plus two derived `provides.scripts` entries.
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` -- gate-unchanged,
  `--force`-warning, re-plan-both-directions and `--check`-exits-0 pins.
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` -- the
  recorded rulings: registration site and rationale, re-plan refusal, declined promotion,
  timeout reasoning, `project_root` and `/orchestrate`-only limitations, commit-volume side
  effect, widened exit-71 row.
- `agent-system/extensions/lean/rules/plan-compliance.md` -- the retained advisory verdict, with
  the new call site noted.
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` -- two corrected header
  claims, comment-only.
- `agent-system/extensions/lean/index-entries.json` -- reconciled `line_count`.
- A regenerated `.claude/**` deployed tree (gitignored, not a committed artifact).

## Rollback/Contingency

The work is additive and separable, so rollback is per-phase rather than wholesale:

- **Phases 1-2** (the new observer and its registration): remove the `observers` object from
  `manifest.json`, re-run `sync-manifest-scripts.sh --write` to drop the two derived
  `provides.scripts` entries, delete the two new script files, and redeploy. The seam disappears
  completely and the snapshot script returns to having no caller -- the exact state before this
  work, with nothing else disturbed.
- **Phase 3** (test extensions and deploy): revert the two suite files to their previous committed
  contents and redeploy. The deployed tree is gitignored and regenerable, so it needs no separate
  rollback.
- **Phase 4** (recorded rulings and comment corrections): revert the three prose/comment files.
  Every edit there is documentation or a comment; none changes behaviour, so reverting carries no
  functional risk.
- **Phase 5** (derived index): re-run `generate-context-line-counts.sh` after any revert above, so
  the derived `line_count` converges on whatever the reverted files actually are.

If a genuine rollback of uncommitted work is needed at any point, take the snapshot first using
the invocation shape in `context/contracts/recovery.md`'s rollback rung -- including its
out-of-scope override flag for a deliberate whole-tree revert -- and only then run the destructive
command. Do not emit a bare reverting `git-snapshot.sh` as a routine start-of-phase checkpoint; for
an ordinary defensive checkpoint before risky work, use `--no-revert`, which is durable without
reverting the working tree.

**Contingency if the observer proves unreachable in practice.** If Phase 3's dry-run resolution
assertion fails for a reason that registration cannot fix, do not fall back to weakening the
exit-73 gate or adding an automatic `--force`. The sanctioned fallback order is: (1) re-check
`provides.scripts` and the deployed `.claude/scripts/` copy, since `missing_script` and
`not_executable` are the two most likely causes and both are registration defects rather than
design defects; (2) if the seam itself is genuinely unusable, mark the phase `[BLOCKED]`, record
the finding, and raise the core `postflight` lifecycle-hook `TASK_TYPE` gap as its own record --
which is the honest predecessor this plan's Decisions section already identifies, not a change to
smuggle into this one.
