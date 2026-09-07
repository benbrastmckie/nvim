# Implementation Plan: Task #153

- **Task**: 153 - lean_comparator_clean_room_runner
- **Status**: [NOT STARTED]
- **Effort**: 12 hours
- **Dependencies**: None in-repo. End-to-end acceptance additionally requires `landrun`,
  `lean4export` and the `comparator` binary, provisioned by a sibling `~/.dotfiles/` task
  outside this repository (see Phase 8 for the deferred-criteria protocol).
- **Research Inputs**: specs/153_lean_comparator_clean_room_runner/reports/01_lean-comparator-clean-room-runner.md
- **Artifacts**: plans/01_lean-comparator-clean-room-runner.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-script-testing.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build `agent-system/extensions/lean/scripts/lean-comparator-run.sh`, a wrapper CLI around the
upstream `leanprover/comparator` judge, plus its regression suite at
`agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` and the fixtures both
need. The script takes a project root, a Challenge module, a Solution module, a theorem-name
list and an axiom whitelist, materialises a clean-room checking environment, synthesises
Comparator's `config.json`, runs Comparator inside the README's mandated sandbox wrapper
serialised against `lake-build-guard.sh`, and emits a machine-readable verdict from one closed
category vocabulary. Definition of done: both a `verified` and a `statement_mismatch` verdict
demonstrated on real files, a transitively-hidden-axiom `axiom_violation` demonstrated, a
`comparator_unavailable` verdict that names the missing binary and its override variable and
exits distinguishably from a real rejection, and the clean-room trust chain written down with
its reasoning. The gate is ADVISORY ONLY: nothing this task produces may set
`verification_passed` false, downgrade status, or block completion.

### Research Integration

The research report (read in full) supplies four findings this plan is built on and which the
implementer must not re-derive:

1. **Comparator exposes only a binary exit code.** Every failure path surfaces as an uncaught
   `IO.userError` -> stderr `uncaught exception: <message>`, exit 1; every fixture's `test.json`
   confirms `exit_code: 1` for all failure categories. There is no structured output. The
   wrapper therefore owns 100% of verdict classification, via substring matching against the
   exact strings the report catalogues verbatim from `Comparator/Compare.lean` and
   `Comparator/Axioms.lean`. Phase 5 consumes that table directly.
2. **`lake-build-guard.sh` result-sharing is a correctness hazard at this call site.** Its
   `scope_key` hashes the lake *argument vector* (the `config.json` **path**, not its content)
   and its tree fingerprint covers `*.lean`/lakefile/`lean-toolchain` but **not** `config.json`.
   Two runs differing only in `permitted_axioms` or `theorem_names` are indistinguishable to the
   guard and a stale REPLAY would return the wrong verdict. `--no-share` is mandatory here, and
   the sibling `lean-sorry-census.sh`'s omission of it must NOT be copied.
3. **Fixture landscape.** `def_hole_axiom_issue` upstream is a ready-made transitively-hidden-
   axiom fixture and should be reused verbatim with attribution (Apache-2.0). No upstream fixture
   isolates a *pure same-kind statement weakening* — all of `simple_mismatch`,
   `simple_axiom_issue`, `simple_kind_mismatch` conflate a theorem-vs-axiom **kind** mismatch
   with the statement difference. One small custom fixture is required.
4. **Clean-room route.** The README's blessed fresh-checkout-plus-prebuilt-`.lake` route beats a
   scratch copy on both cost and precondition satisfaction; the reasoning and trust chain are
   fixed in Phase 1.

The report also left two vocabulary questions open for this plan; both are resolved in
Goals below and implemented in Phase 2.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found at `specs/ROADMAP.md`; no roadmap phases added.

## Goals & Non-Goals

**Goals**:

- A single executable `agent-system/extensions/lean/scripts/lean-comparator-run.sh` covering
  dispatch items (a) clean room, (b) sandbox invocation, (c) config synthesis, (d) cost control,
  (e) verdict.
- A closed, named-once verdict vocabulary consumed by all later Comparator work. **Decision
  (resolves research open question 1)**: the dispatch's seven categories are extended by exactly
  one — `config_error` — and no more:

  | Verdict | Meaning | Exit code |
  |---------|---------|-----------|
  | `verified` | Comparator printed `Your solution is okay!` and exited 0 | 0 |
  | `statement_mismatch` | `Challenge and solution theorem statement do not match` **or** `Challenge and solution constant kind don't match` **or** `Const does not match between challenge and target` | 65 |
  | `axiom_violation` | `Illegal axiom detected: '<name>'` | 66 |
  | `kernel_rejected` | stdout marker `Lean default kernel rejects the solution` or `<kernel> kernel rejected the solution` | 67 |
  | `definition_hole_needs_human` | Comparator exited 0 **and** `definition_names` was non-empty | 68 |
  | `comparator_unavailable` | a required binary could not be resolved, or the sandbox wrapper is unusable | 69 |
  | `timeout` | the run exceeded `--timeout` | 70 |
  | `config_error` | `Const not found in challenge:` / `Const not found in solution:` — an authoring error, not a security finding | 71 |

  Usage errors exit 64 (matching `lean-sorry-census.sh`); 75-79 stays reserved for
  `lake-build-guard.sh` and must not be reused.
- **Decision (resolves research open question 2, and reconciles it with the dispatch)**:
  `statement_mismatch` absorbs the textually-distinguishable kind-mismatch and definition-hole-
  mismatch strings rather than splintering the vocabulary; the distinguishing string is preserved
  losslessly in a `reason_detail` field so no information is discarded.
- **Decision (definition holes)**: `definition_hole_needs_human` is emitted as the top-level
  verdict (honouring the dispatch's "name them once, here"), and carries
  `underlying_verdict: verified` so the kernel/statement/axiom guarantees Comparator *did*
  establish remain visible rather than being hidden behind a different name. This reconciles the
  dispatch's category list with the research report's modifier-field recommendation.
- Loud degradation everywhere: a missing binary is a reported verdict naming the binary and its
  override variable, never a skipped check that reads as a pass.
- A regression suite following `test-lean-sorry-census.sh` conventions, with fixtures reused
  from upstream's Apache-2.0 `tests/projects/` shape.
- A written design record capturing the clean-room trust chain, verdict-string table, and
  version-coupling caveat, so the eventual hard-gate-promotion task need not re-clone upstream.

**Non-Goals**:

- Wiring Comparator into `lean-implementation-agent`'s Final Verification Stage, or into any
  other gate. The GATE STRENGTH DECISION is binding and already made: advisory first, promotion
  is a separate later decision on evidence from real runs.
- Solving constraint C1 (who authors `Challenge.lean`, and what plan-format field carries an
  intended *statement* rather than an identifier). This runner is given a Challenge/Solution/
  config already materialised; the authoring question belongs to a sibling task.
- Provisioning `landrun`, `lean4export`, `nanoda_bin` or `comparator` themselves — a sibling
  `~/.dotfiles/` task owns that.
- Any edit under `.claude/**`. That tree is a disposable deploy artifact; all work targets
  `agent-system/extensions/**` per `rules/source-store-deploy-boundary.md`.
- Building a second concurrency guard. `lake-build-guard.sh` is reused as-is and is not modified.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Stale `lake-build-guard.sh` REPLAY returns a verdict computed under a different `config.json` body | H | M | Always pass `--no-share` to the guard; Phase 4 asserts this in the test suite, not just in a comment |
| Verdict misclassification from upstream changing its message strings | H | M | Classification table lives in one function with the upstream source file and string quoted beside each arm; unmatched-but-nonzero exit falls through to a loud `comparator_unavailable`-distinct generic failure rather than being silently bucketed as `verified` |
| `lean4export` built against Comparator's own v4.34.0-rc2 silently mis-exports a target project on a different Lean version (C3) | H | M | Never default `COMPARATOR_LEAN4EXPORT` to a path inside a Comparator checkout; resolve via PATH or explicit override only, and record the coupling in the Phase 1 design record |
| End-to-end acceptance impossible today (all three binaries missing on this host) | M | H | Phase 8 reports deferred criteria explicitly and honestly rather than claiming a pass; `fake-landrun.sh` covers what it can |
| Cost blowup from a Mathlib-dependent double build (C4) | M | M | `--timeout` with a `timeout` verdict; opt-in standalone script never wired into a per-iteration loop; clean room reuses a prebuilt `.lake` rather than rebuilding from source |
| Script left off `manifest.json` `provides.scripts` and therefore never deployed | M | M | Phase 8 makes the manifest edit an explicit, verified step |
| Nesting the two `systemd-run` wrappers (README security wrapper, guard `--memory-bound`) compounds failure modes | L | M | Do not pass `--memory-bound`; README wrapper is OUTER, guard is INNER, as the research recommends |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 6 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |
| 5 | 7 | 5, 6 |
| 6 | 8 | 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Design record — clean-room decision, trust chain, verdict contract [NOT STARTED]

**Goal**: Write the decision down with its reasoning before any code encodes it, satisfying the
dispatch's explicit acceptance criterion that "the clean-room decision in (a) is written down
with its reasoning, including what is trusted and why, not left implicit in the code", and
closing the research report's flagged zero-coverage context gap.

**Tasks**:
- [ ] Create `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`.
- [ ] Record the **clean-room decision**: fresh `git worktree add` of the target project at the
      exact commit to be checked, taken BEFORE the runner is ever invoked with an untrusted
      Solution, with `.lake/` populated by `lake exe cache get` in that same fresh worktree
      before the Solution file is written into it.
- [ ] Record the **alternatives evaluated and rejected**: a scratch copy without a prebuilt
      `.lake` (forces a full in-sandbox rebuild, compounding C4, and satisfies README
      precondition 2 no better than the cache route); `git clone --depth 1` (does not share the
      object store, so is slower to create and discard per run than a worktree).
- [ ] Record the **trust chain explicitly**: "trusted" for the reused `.lake` means the cache is
      the project's own published build artifacts fetched over its normal cache-server pipeline,
      under the same trust the operator already extends to every ordinary `lake build` of that
      project — i.e. NOT a stronger boundary than the project's existing supply chain. Quote the
      README's own caveat that this is acceptable "if you trust the cache to not be modified as
      to, e.g. contain different definitions from the one you would expect".
- [ ] Record the **verdict-string table** verbatim (upstream source file per row), the closed
      eight-value verdict vocabulary, and the exit-code assignment from Goals above.
- [ ] Record the **C3 version-coupling caveat**: Comparator's own toolchain is
      `leanprover/lean4:v4.34.0-rc2` and its lakefile pulls `lean4export` at `rev = "master"`
      built against that toolchain; `lean4export` must instead match the TARGET project's
      `lean-toolchain`, so `COMPARATOR_LEAN4EXPORT` must never default to a Comparator-checkout
      path.
- [ ] Record the **guard `--no-share` correctness requirement** with its scope_key/fingerprint
      reasoning, and the wrapper nesting order (README `systemd-run` OUTER, guard INNER, no
      `--memory-bound`).
- [ ] Record the binding **advisory-only gate strength decision** and that promotion is a
      separate later decision.
- [ ] Add the new file to the lean extension's context index if the extension maintains one
      (`index-entries.json`), matching the surrounding entries' shape.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` - new
- `agent-system/extensions/lean/context/index-entries.json` - new entry, if the file exists

**Verification**:
- File exists and covers all seven recorded items above.
- No task-number references appear in it (`rules/no-task-references-in-deliverables.md`; this
  file lives outside `specs/**`).
- No `.claude/**` path was written.

---

### Phase 2: Runner skeleton — CLI, binary resolution, verdict emitter [NOT STARTED]

**Goal**: A runnable `lean-comparator-run.sh` that parses its arguments, resolves its three
external binaries, and can emit every verdict in the closed vocabulary — including a correct
`comparator_unavailable` — before any Comparator run exists.

**Tasks**:
- [ ] Create `agent-system/extensions/lean/scripts/lean-comparator-run.sh` with a header comment
      block matching `lean-sorry-census.sh`'s style (purpose, usage, output shape, exit codes).
- [ ] Implement CLI: `--project-root`, `--challenge-module`, `--solution-module`,
      `--theorems <comma-list>`, `--permitted-axioms <comma-list>`, `--definitions <comma-list>`
      (optional), `--timeout <seconds>`, `--keep-workdir`, `--json`. Usage error -> exit 64.
- [ ] Implement binary resolution honouring `COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`,
      `COMPARATOR_NANODA` (upstream's own variable names, carried through, not invented here),
      plus a `COMPARATOR_BIN` for the comparator binary itself, each falling back to `PATH`.
      Never default `COMPARATOR_LEAN4EXPORT` to a Comparator-checkout path (C3).
- [ ] Implement the `comparator_unavailable` path: on any unresolved binary, emit a verdict whose
      message names BOTH the missing binary and the environment variable that would override it,
      and exit 69 — distinguishable from every real-rejection code.
- [ ] Implement the verdict emitter: one function taking `(verdict, reason_detail,
      underlying_verdict, message)` and producing the machine-readable record (key: value lines
      by default, JSON under `--json`), then exiting with the code from the Goals table.
- [ ] Reuse the guard's `have_systemd_run()` probe pattern (a real
      `systemd-run --user --scope --quiet --collect -- true` invocation, not `command -v`) as a
      usability check; an unusable `systemd-run` is `comparator_unavailable`, not a silent
      unsandboxed fallback.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The verdict vocabulary is asserted to be exactly eight values with the
exit codes in the Goals table, and 75-79 is asserted to be reserved by `lake-build-guard.sh`.
Confirm at implementation time by grepping `lake-build-guard.sh` for its own reserved-band
comment and its `exit 7[5-9]` sites before fixing this script's codes; if the band differs from
the report's finding, re-pick codes and update the Phase 1 design record in the same commit.

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - new

**Verification**:
- `bash -n` clean; `shellcheck` clean if available.
- Invoking with no arguments exits 64 with usage text.
- With `COMPARATOR_BIN=/nonexistent`, the script emits `comparator_unavailable`, names both
  `comparator` and `COMPARATOR_BIN`, and exits 69.

---

### Phase 3: Clean room materialisation and config synthesis [NOT STARTED]

**Goal**: Implement dispatch items (a) and (c) — materialise a checking environment in which the
Solution has not previously been compiled, and generate a `config.json` matching Comparator's
`structure Config` schema.

**Tasks**:
- [ ] Implement clean-room materialisation per the Phase 1 decision: `git worktree add` of the
      target project into a `mktemp -d` workdir at the requested commit (default `HEAD`), with a
      `trap EXIT` cleanup honouring `--keep-workdir`.
- [ ] Populate `.lake/` in the fresh worktree via `lake exe cache get` (skipped with a loud
      notice when the project has no cache target), BEFORE the Solution module is placed.
- [ ] Copy the target project's `lean-toolchain` into the workdir so the Comparator run uses the
      TARGET project's Lean version, not Comparator's (C3).
- [ ] Synthesise the lakefile when the project does not already declare `Challenge`/`Solution` as
      `lean_lib` targets, reusing upstream `runtests.lean`'s exact generated shape
      (`name = "comparatortest"`, two `[[lean_lib]]` blocks named `Solution` and `Challenge`).
- [ ] Synthesise `config.json` with `challenge_module`, `solution_module`, `theorem_names`,
      `permitted_axioms`, and `definition_names` when `--definitions` was passed. Do not emit
      `enable_nanoda` and a non-empty `external_kernels` together — Comparator throws if both are
      set; make that a usage error (exit 64) rather than letting Comparator discover it.
- [ ] When `definition_names` is non-empty, record that the eventual result requires additional
      (potentially human) verification, carrying the README's concrete gaming example
      (`def ChallengeSolution : Prop := sorry` answered with `:= RiemannHypothesis` and closed by
      `rfl`) into the emitted message text, not just a code comment.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - clean-room + config functions

**Verification**:
- Against a throwaway git repo fixture, the workdir is created, is a distinct path from the
  project root, and contains no build products attributable to a prior Solution compile.
- Emitted `config.json` parses under `python3 -c 'import json,sys;json.load(open(sys.argv[1]))'`
  and contains exactly the keys Comparator's `structure Config` declares.
- `--keep-workdir` leaves the directory; its absence removes it.

---

### Phase 4: Sandbox invocation, guard serialisation, timeout [NOT STARTED]

**Goal**: Implement dispatch items (b) and (d) — emit the README's mandated `systemd-run` form,
nest the shared build guard inside it, and bound the run's cost.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/lake-build-guard.sh`'s contract (subcommands,
      exit-code band, `--no-share`, `--dir`) before writing the call, per dispatch item (d)'s
      "read that guard's contract before inventing a second one".
- [ ] Resolve the guard via `LEAN_COMPARATOR_RUN_GUARD_BIN`, defaulting to the `dirname`-relative
      sibling `lake-build-guard.sh`, exactly as `lean-sorry-census.sh` resolves it (the two ship
      from different source-store extensions and are literal siblings only post-deploy).
- [ ] Emit the README's wrapper verbatim in shape:
      `systemd-run --property=RestrictAddressFamilies=~AF_UNIX --user --pty -E PATH="$PATH"
      --working-directory <workdir> -- bash -c '<inner>'`, where `<inner>` is
      `lake-build-guard.sh build --dir <workdir> --no-share -- env <comparator> config.json`.
- [ ] **Always pass `--no-share`** — a correctness requirement here, not a performance choice,
      because the guard's `scope_key` hashes the argument vector (the config.json *path*) and its
      fingerprint excludes `config.json`'s content. Do NOT pass `--memory-bound`.
- [ ] Implement the three-way degradation branch mirroring `lean-sorry-census.sh`: guard present /
      guard absent but `lake` present (ungated invocation with a loud stderr warning) / `lake`
      absent (`comparator_unavailable`). Never a silent skip.
- [ ] Implement `--timeout` (default: pick a value and justify it in the header comment) wrapping
      the whole invocation; expiry emits the `timeout` verdict and exits 70.
- [ ] Capture stdout and stderr separately into workdir files for Phase 5 to classify, preserving
      the raw text for the emitted message.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - invocation + guard + timeout

**Verification**:
- With a stub guard on `PATH`, the constructed command line contains `--no-share` and does NOT
  contain `--memory-bound`; assert this on the captured command line, not by reading the source.
- With a stub comparator that sleeps past the timeout, the verdict is `timeout` and exit is 70.
- With the guard absent and `lake` present, a loud warning is printed and the run still proceeds.

---

### Phase 5: Verdict classification [NOT STARTED]

**Goal**: Implement dispatch item (e) — recover the closed verdict vocabulary from Comparator's
unstructured stdout/stderr, since Comparator itself exposes only a binary exit code.

**Tasks**:
- [ ] Implement one `classify_verdict()` function matching, in priority order (most specific
      first), with the upstream source file quoted beside each arm:
      - stdout `Your solution is okay!` + exit 0 -> `verified`
      - stdout `Lean default kernel rejects the solution` or `<kernel> kernel rejected the
        solution` -> `kernel_rejected`
      - stderr `Illegal axiom detected: '<name>'` -> `axiom_violation`
      - stderr `Const not found in challenge:` / `Const not found in solution:` ->
        `config_error`
      - stderr `Challenge and solution theorem statement do not match:` ->
        `statement_mismatch` with `reason_detail=statement`
      - stderr `Challenge and solution constant kind don't match:` -> `statement_mismatch`
        with `reason_detail=kind`
      - stderr `Const does not match between challenge and target` -> `statement_mismatch`
        with `reason_detail=const_closure` (note in a comment that this one string covers two
        distinct upstream call sites and cannot distinguish hole-itself from transitive-dependency
        mismatch)
- [ ] Fall through: a non-zero exit matching no arm emits a loud unclassified failure that is
      NOT `verified` and NOT `comparator_unavailable`, carrying the raw stderr. Failing closed
      here is mandatory — the dispatch's whole point is that a check which cannot say "no" is not
      a checker.
- [ ] Overlay `definition_hole_needs_human` when the run classified as `verified` and
      `definition_names` was non-empty, emitting `underlying_verdict: verified` alongside it.
- [ ] Check the `Your solution is okay!` marker in addition to exit 0, not instead of it (the
      stronger positive signal, per the research report).

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - `classify_verdict()`

**Verification**:
- Feeding each catalogued message string through the classifier as canned stdout/stderr yields
  the expected verdict and exit code for all eight categories.
- An unrecognised non-zero-exit stderr yields a non-`verified` result.

---

### Phase 6: Test fixtures [NOT STARTED]

**Goal**: Assemble the fixture tree the suite needs, reusing upstream's Apache-2.0 shape rather
than inventing one, and authoring only the single fixture upstream genuinely lacks.

**Tasks**:
- [ ] Create `agent-system/extensions/lean/scripts/tests/fixtures/comparator/` and vendor
      upstream `scripts/fake-landrun.sh` verbatim with an Apache-2.0 attribution header naming
      `leanprover/comparator` as the source (an argument-swallowing shim that execs its trailing
      command unsandboxed after discarding recognised landrun flags, printing its loud
      `WARNING: THIS IS NOT REAL LANDRUN!` line).
- [ ] Vendor `def_hole_axiom_issue` (Challenge.lean, Solution.lean, config.json, test.json) with
      attribution — the ready-made transitively-hidden-axiom fixture required by the acceptance
      criterion that the violation be reached TRANSITIVELY, not via a literal `axiom` line.
- [ ] Vendor `simple_match` with attribution as the `verified`-direction fixture.
- [ ] Author ONE new fixture, `statement_weakened/`, because no upstream fixture isolates a pure
      same-kind statement weakening (all of `simple_mismatch`, `simple_axiom_issue`,
      `simple_kind_mismatch` conflate a theorem-vs-axiom kind mismatch with it). Shape:
      Challenge `theorem comm (n m : Nat) : n + m = m + n := sorry`; Solution
      `theorem comm (n m : Nat) (h : n = m) : n + m = m + n := by omega` — same declaration kind,
      added hypothesis, strictly weaker, hits the statement-mismatch arm without touching the
      kind-mismatch path.
- [ ] Adopt upstream's `test.json` (`{"exit_code": N}`) oracle shape per fixture so the suite can
      be data-driven rather than one function per case — but record this repo's own verdict-name
      expectation alongside the exit code, since this wrapper's codes are not Comparator's.
- [ ] Write a short `fixtures/comparator/README.md` recording provenance, upstream commit, and
      the licence of each vendored file.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly four fixture directories (`simple_match`,
`def_hole_axiom_issue`, `statement_weakened`, plus the vendored `fake-landrun.sh`) suffice for
the dispatch's acceptance criteria. Confirm at implementation time by walking the acceptance list
in the dispatch and checking each criterion maps to a fixture; if a criterion has no fixture, add
one and update this list rather than narrowing the criterion.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/fake-landrun.sh` - new
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/simple_match/*` - new
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/def_hole_axiom_issue/*` - new
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/statement_weakened/*` - new
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/README.md` - new

**Verification**:
- Every vendored file carries attribution and the upstream commit id.
- Each fixture directory contains Challenge.lean, Solution.lean, config.json and an oracle file.
- `bash -n` clean on the vendored `fake-landrun.sh`.

---

### Phase 7: Regression suite [NOT STARTED]

**Goal**: `test-lean-comparator-run.sh` following `test-lean-sorry-census.sh` conventions,
including its anti-vacuous-test discipline.

**Tasks**:
- [ ] Create `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` with the
      established convention: header comment stating what each fixture group discriminates,
      `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` counters, `mktemp -d` workdir with
      `trap EXIT` cleanup, exit 0 all-pass / exit 1 any-fail, `SCRIPT_DIR`-relative tool
      resolution.
- [ ] Cases for verdict classification driven by canned stdout/stderr through the classifier —
      one per category, all eight.
- [ ] Cases for `comparator_unavailable`: each of the four binaries missing in turn, asserting the
      message names both the binary and its override variable and that exit 69 differs from every
      rejection code.
- [ ] Cases for guard routing: stub guard asserting `--no-share` present and `--memory-bound`
      absent on the captured command line; guard-absent + lake-present degradation; lake-absent
      `comparator_unavailable`.
- [ ] Case for `timeout` using a stub comparator that outlives `--timeout`.
- [ ] **Anti-vacuous-test guard** (carrying `test-lean-sorry-census.sh`'s own discipline): at
      least two cases must assert the tool's output DIFFERS from a naive/degraded implementation
      on the same input — specifically, that a naive "exit code 1 means rejected, full stop"
      classifier and this script's classifier disagree on the `axiom_violation` vs
      `config_error` fixtures, proving the classification is doing work.
- [ ] Skip-with-explicit-report (never silent pass) for any case requiring the real `comparator`
      or `lean4export` binaries when those are absent, printing which acceptance criterion is
      thereby deferred.

**Timing**: 2 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` - new

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` exits 0.
- `bash agent-system/extensions/lean/scripts/tests/test-lean-sorry-census.sh` still exits 0 (no
  regression in the sibling suite).
- Deliberately breaking one classifier arm makes the suite exit 1 (mutation check).

---

### Phase 8: Manifest wiring, acceptance evidence, deferred-criteria report [NOT STARTED]

**Goal**: Make the script actually deployable, and record honestly which acceptance criteria are
proven and which are deferred to the sibling provisioning task.

**Tasks**:
- [ ] Add `scripts/lean-comparator-run.sh` and `scripts/tests/test-lean-comparator-run.sh` (and
      the fixture tree, if the manifest schema tracks non-script assets) to
      `agent-system/extensions/lean/manifest.json`'s `provides.scripts`. A script left off this
      list is never deployed to `.claude/scripts/` and is therefore invisible to the agent.
- [ ] Verify the manifest still parses (`python3 -m json.tool`) and that a deploy/sync dry run,
      if one exists, lists the new files.
- [ ] Run the acceptance demonstrations and capture their output:
      - `verified` on `simple_match`
      - `statement_mismatch` on `statement_weakened`
      - `axiom_violation` on `def_hole_axiom_issue` (transitive, not a literal `axiom` line)
      - `comparator_unavailable` naming binary + override var, exiting distinguishably
- [ ] For any demonstration that cannot run because `landrun`/`lean4export`/`comparator` are
      absent on this host, state explicitly WHICH criterion is deferred and to WHAT (the sibling
      `~/.dotfiles/` provisioning work) — never report it as a pass. Consider, and record a
      decision on, whether building `comparator` + `lean4export` locally is feasible within
      budget (neither depends on Mathlib and `lake`/`lean`/`elan` are present) versus deferring.
- [ ] Confirm no file under `.claude/**` was written at any point in this task.
- [ ] Confirm no task-number reference appears in any deliverable outside `specs/**`.

**Timing**: 1 hour

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: Two manifest entries are asserted sufficient. Confirm at implementation time
by reading the manifest's existing `provides` schema — if fixtures require their own array or a
directory-glob entry, add it rather than assuming the two script paths cover the tree.

**Files to modify**:
- `agent-system/extensions/lean/manifest.json` - `provides.scripts` entries

**Verification**:
- `python3 -m json.tool agent-system/extensions/lean/manifest.json` succeeds.
- Both new paths appear in `provides.scripts`.
- `git status --short` shows no modifications under `.claude/`.
- `bash .claude/scripts/check-task-references.sh` (or equivalent repo lint) reports no new
  violations.

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` (if available) clean on `lean-comparator-run.sh`,
      `test-lean-comparator-run.sh`, and the vendored `fake-landrun.sh`.
- [ ] `test-lean-comparator-run.sh` exits 0 with every non-deferred case passing.
- [ ] `test-lean-sorry-census.sh` still exits 0 (sibling-suite regression check).
- [ ] Mutation check: breaking one classifier arm makes the suite fail.
- [ ] All eight verdict categories reachable and each maps to its documented exit code.
- [ ] `comparator_unavailable` exit code is distinct from every rejection code, verified by
      asserting the numeric codes differ, not by inspection.
- [ ] Both acceptance directions demonstrated on real files: a `verified` pass AND a
      `statement_mismatch` rejection. A checker that can only ever say one thing is not a checker.
- [ ] Transitive `axiom_violation` demonstrated via `def_hole_axiom_issue` (not a literal
      `axiom` line, which the existing grep already catches).
- [ ] `manifest.json` parses and lists the new files.
- [ ] No `.claude/**` file modified; no task-number reference outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-comparator-run.sh`
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh`
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/` (fake-landrun.sh,
  `simple_match/`, `def_hole_axiom_issue/`, `statement_weakened/`, README.md)
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`
- `agent-system/extensions/lean/manifest.json` (modified: two `provides.scripts` entries)
- `agent-system/extensions/lean/context/index-entries.json` (modified, if present)
- Execution summary at `specs/153_lean_comparator_clean_room_runner/summaries/01_*.md` recording
  which acceptance criteria are proven and which are deferred.

## Rollback/Contingency

Every deliverable except the two modified files is a new, additive file under
`agent-system/extensions/lean/`; nothing existing is rewritten. Rollback is
`git revert` of the task's phase commits, or deleting the new paths and reverting the
`manifest.json` and `index-entries.json` edits. No production behaviour depends on the new script
until a separate, later task wires it into a gate — the binding advisory-only decision guarantees
that a defective runner cannot fail a build, downgrade a status, or block a completion in the
interim. If Phase 3's worktree approach proves unworkable against a real target project, the
documented fallback is a scratch copy with an explicit loud notice that C4 cost is higher and the
Phase 1 design record must be amended in the same commit rather than left describing a route the
code no longer takes.
