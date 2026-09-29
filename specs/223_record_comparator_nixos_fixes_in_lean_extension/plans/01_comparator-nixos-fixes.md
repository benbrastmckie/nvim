# Implementation Plan: Record Comparator-on-NixOS Fixes in the Lean Extension

- **Task**: 223 - Record comparator nixos fixes in lean extension
- **Status**: [NOT STARTED]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/223_record_comparator_nixos_fixes_in_lean_extension/reports/01_comparator-nixos-fixes.md
- **Artifacts**: plans/01_comparator-nixos-fixes.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Transcribe four already-proven Comparator-on-NixOS fixes out of the `framed_channel` reference
implementation and into the lean extension's **source store**
(`/home/benjamin/.config/nvim/agent-system/extensions/lean`, never `.claude/**`), so a Comparator
run works on this host: a new landrun shim carrying the `TMPDIR`/git-library/ELF-interpreter
grants Comparator's own sandbox omits, pinned-toolchain PATH ordering (plus the elan-wrapper
unwrapping that makes it executable under Landlock), an outer landrun around `lake env` and
Comparator itself, and a git-remote pre-flight probe that stops Lake from deleting
`.lake/packages/<dep>`. Four further findings are documentation-only (the lean4export panic on a
Challenge-absent `permitted_axioms` entry, `lake update --keep-toolchain`, the batched-Lean4Lean
earlyoom incident, and the outer-landrun rationale) and land in `comparator-integration.md` with a
short operator pointer in `comparator-guide.md`. A separate absorbed scope adds a Lean dependency-
tracing recipe as a new lean4 pattern file. The round closes with a `.claude/` redeploy.

### Research Integration

The report maps every fix to its source and target and makes three findings this plan is built
around:

- **Fix 2 (`lake env comparator config.json`) needs no code change.** Both branches of
  `run_sandboxed()` already produce that exact command line — the guard branch because
  `lake-build-guard.sh build ... -- env <comparator> config.json` prepends `lake` itself. What is
  missing is the *diagnosis* that Fix 2 only reaches a working `lake` once Fix 1 lands, so the
  four fixes are ordered, not independent.
- **Fixes 3 and 4 are one implementation unit** — the reference adds the `TMPDIR` override and the
  git `--rox` grants in a single `landrun-shim.sh` pass, because `COMPARATOR_LANDRUN` is the only
  injection point into an argument vector Comparator builds internally.
- **No real `lean4export`/`nanoda_bin` on this host**, so acceptance is stub-based regression
  coverage, following the suite's own already-established Case E1/E2 skip-with-explicit-report
  convention rather than re-litigating it.

**Reference drift confirmed at plan time — the report's paths and line numbers are stale.** The
reference scripts have moved to `framed_channel/scripts/` (`recheck-comparator.sh`,
`comparator-configs.sh`) and `framed_channel/scripts/lib/recheck-revs.sh`; only
`framed_channel/recheck/landrun-shim.sh` is where the report says. The live shim has also **grown
three mechanisms the report does not mention**: an ELF-interpreter `--rox` grant (on NixOS
`lake`'s interpreter is nix-ld, which `landrun -ldd` does not discover, so the exec of `lake` is
denied without it), a `RECHECK_LAKE_DIR` PATH prepend performed *inside the shim* because
`lake env` reorders `PATH`, and a `RECHECK_EXTRA_RWX` multi-grant hook. `recheck-comparator.sh`
additionally detects that the pinned toolchain's `lake` is a `#!` script wrapper and symlinks
`lake.orig` into a private dir. Every phase below therefore re-reads the live reference file
rather than trusting the report's quoted lines.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in this dispatch (`roadmap_path` absent, `roadmap_flag` not set).

## Goals & Non-Goals

**Goals**:
- `lean-comparator-run.sh` carries Fix 1 (pinned-toolchain PATH ordering, including elan-wrapper
  unwrapping), Fixes 3+4 (via a new shim it points `COMPARATOR_LANDRUN` at), the outer landrun
  hardening, and a git-remote pre-flight probe.
- `comparator-integration.md` replaces its unexplained `lake: Permission denied` paragraph with
  the diagnosed root cause, and records the shim mechanism, the lean4export panic and its
  `axiom_violation`-as-expected-pass handling, the `lake update --keep-toolchain` pitfall, the
  batched-Lean4Lean earlyoom caveat, and the outer-landrun decision.
- `comparator-guide.md` gains a short operator pointer for hand-constructed `permitted_axioms`.
- `test-lean-comparator-run.sh` gains stub-based regression cases for the new mechanisms.
- A new `context/project/lean4/patterns/dependency-tracing.md` reproduces the four probe shapes
  and the `#print axioms` caveat, wired into the lean4 context index.
- `.claude/` is redeployed from the source store afterwards.

**Non-Goals**:
- Provisioning `lean4export` or `nanoda_bin` on this host (tracked by a sibling `~/.dotfiles/`
  effort); a real end-to-end Comparator run is therefore out of reach and its deferral is
  reported, never silently passed.
- Patching Comparator upstream. Every fix is a wrapper/environment workaround.
- Building a Lean4Lean/leanchecker kernel-replay sibling script. The earlyoom finding is recorded
  as forward-looking guidance for it, not implemented.
- Editing anything under `.claude/**` by hand (rules/source-store-deploy-boundary.md).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling task owns `agent-system/extensions/lean/manifest.json` (declared in this cycle's territory block) | M | H | Re-read `manifest.json` immediately before the Phase 1 edit; stage that one file by explicit path only, never a directory pathspec; if a foreign modification is present, STOP and report per the dispatch's concurrency note |
| Report's cited reference paths/line numbers are stale (confirmed) | M | H | Every phase re-reads the live reference file by name; line numbers are never used as the anchor |
| No real `landrun`/`lean4export`/`nanoda_bin` on this host | M | H | Stub-based coverage asserting argv construction and shim wiring; reuse the suite's Case E1/E2 skip-with-explicit-report convention and state the deferred criteria in the summary |
| New shim not added to `manifest.json` `provides.scripts` would silently not deploy | H | M | Phase 1 adds the manifest entry in the same phase as the script; Phase 7 verifies the deployed path exists after redeploy |
| Shim/`lake-build-guard.sh` interaction changes the `--no-share` correctness argument | M | L | Re-read the guard's `scope_key` contract before touching `run_sandboxed()`; the shim is invoked *by Comparator* via `COMPARATOR_LANDRUN`, not by the guard, so no interaction is expected — confirm, do not assume |
| Toolchain resolution run too early resolves the caller's toolchain, not the worktree's | M | M | Resolve after `clean_room_setup` completes, against `$WORKDIR` |
| Doc edits citing "task 32"/"task 36" would violate rules/no-task-references-in-deliverables.md | M | M | Cite durable anchors only (file names, section headings, measured dates) in every file outside `specs/**` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 6 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Landrun shim script (Fixes 3 + 4) [NOT STARTED]

**Goal**: A new source-store sibling script that Comparator can be pointed at via
`COMPARATOR_LANDRUN`, which execs the real `landrun` with Comparator's own argv unchanged plus the
grants its internal sandbox omits.

**Tasks**:
- [ ] Read `~/Projects/Logos/Verification/framed_channel/recheck/landrun-shim.sh` in full (the
      live file, not the report's excerpt) and `scripts/recheck-comparator.sh`'s `confined()` and
      `run_room()` for how the shim is handed its environment.
- [ ] Create `agent-system/extensions/lean/scripts/lean-comparator-landrun-shim.sh`: a header
      comment stating it is INTERNAL (exec'd by Comparator, never run by hand), `-h`/`--help`
      answered without side effects, then `TMPDIR=$PWD/.lake/tmp` (`mkdir -p`) as `--env`, one
      `--rox` per `ldd`-reported shared library of the realpath'd `git` binary, and the
      ELF-interpreter `--rox` grant for `lake` via `readelf -l` (guarded on `readelf` being
      present) — the nix-ld case `landrun -ldd` does not discover.
- [ ] Give the shim a `LEAN_COMPARATOR_RUN_REAL_LANDRUN` override for the real `landrun` path,
      following this extension's established `LEAN_COMPARATOR_RUN_GUARD_BIN` test-seam naming, so
      the shim is testable with no real `landrun` present.
- [ ] Give the shim an optional argv log env var (the reference's `RECHECK_SHIM_LOG` equivalent,
      named per this extension's convention) so Phase 4 can assert on logged argv rather than by
      reading source.
- [ ] Carry the reference's `RECHECK_LAKE_DIR` equivalent: a PATH prepend performed *inside the
      shim* because `lake env` reorders `PATH` — record that reason in a comment.
- [ ] `chmod +x` the new script.
- [ ] Re-read `manifest.json`, then add `lean-comparator-landrun-shim.sh` to
      `provides.scripts` immediately after the existing `lean-comparator-run.sh` entry.
- [ ] `bash -n` the new script; run `shellcheck` if available.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts exactly one new script file plus one `provides.scripts`
array entry. Confirm at implementation time that no other manifest block (e.g. a separate hooks or
root-files list) also needs the new path, by grepping `manifest.json` for the sibling
`lean-comparator-run.sh` string and checking every block it appears in.

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-landrun-shim.sh` - new file, the shim
- `agent-system/extensions/lean/manifest.json` - add the shim to `provides.scripts`

**Verification**:
- `bash -n scripts/lean-comparator-landrun-shim.sh` exits 0.
- `bash scripts/lean-comparator-landrun-shim.sh --help` prints the header and exits 0 with no
  filesystem side effects.
- `python3 -c "import json;json.load(open('manifest.json'))"` succeeds and the new path is present
  in `provides.scripts`.

---

### Phase 2: Runner PATH ordering, lake unwrapping, TMPDIR, shim wiring (Fix 1) [NOT STARTED]

**Goal**: `lean-comparator-run.sh` resolves the target project's pinned toolchain `bin/`, puts it
first on the `PATH` it hands into the sandbox, hands Landlock something it can actually execute
instead of the elan shim, and points `COMPARATOR_LANDRUN` at Phase 1's shim.

**Tasks**:
- [ ] Re-read `run_sandboxed()` and `clean_room_setup()` in
      `agent-system/extensions/lean/scripts/lean-comparator-run.sh`, and re-read
      `lake-build-guard.sh`'s `scope_key` contract to confirm the shim introduces no interaction
      with `--no-share`'s correctness argument (the design record already instructs this).
- [ ] Add a toolchain-resolution helper that runs `lean --print-prefix` **inside `$WORKDIR`**
      (after `clean_room_setup` completes) so it reflects the worktree's own `lean-toolchain`, and
      derives `<prefix>/bin`.
- [ ] Handle the elan-wrapper case: if `<toolchain bin>/lake` begins `#!`, prefer a `lake.orig`
      beside it, symlinked into a private per-run dir that goes first on PATH; if neither exists,
      emit `comparator_unavailable` naming the wrapper rather than failing opaquely later.
- [ ] Change `run_sandboxed()`'s `env_flags` `PATH=` value to `<lake dir>:<toolchain bin>:<git
      dirname>:$PATH` (toolchain first), matching the reference's ordering.
- [ ] `mkdir -p "$WORKDIR/.lake/tmp"` and forward `TMPDIR` into the sandbox; the shim also derives
      it from `$PWD/.lake/tmp`, which holds because `systemd-run --working-directory "$WORKDIR"`
      is already passed.
- [ ] Repoint `COMPARATOR_LANDRUN` from `$LANDRUN_PATH` to the resolved shim path, resolved with
      the same overridable dirname-relative-sibling pattern `GUARD_BIN` already uses; forward the
      real `landrun` path to the shim via its `LEAN_COMPARATOR_RUN_REAL_LANDRUN` seam.
- [ ] Update the script's header comment block where it describes `COMPARATOR_LANDRUN` as pointing
      at `landrun` directly.
- [ ] `bash -n`; run the existing suite to confirm no pre-existing case regressed.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - toolchain PATH resolution, lake
  unwrapping, TMPDIR, `COMPARATOR_LANDRUN` repoint, header comment

**Verification**:
- `bash -n scripts/lean-comparator-run.sh` exits 0.
- `bash scripts/tests/test-lean-comparator-run.sh` still reports every pre-existing case as PASS
  (Cases U0-U4, G1-G3, V1-V11, AV1) with E1/E2 skipped as before; exit 0.
- Case G1's captured guard argv still contains `--no-share` and omits `--memory-bound`.

---

### Phase 3: Outer landrun hardening and git-remote pre-flight probe [NOT STARTED]

**Goal**: Confine every process of the run — including `lake env` and Comparator itself, which run
*outside* Comparator's own sandbox — to the clean-room worktree and `/dev` with no network, and
fail loudly before Lake can delete a dependency it cannot re-clone.

**Tasks**:
- [ ] Re-read `recheck-comparator.sh`'s `confined()` for the live outer-landrun argument vector
      (`--best-effort --rox / --rw /dev --rwx <room>`, plus the explicit `--env` passthrough list)
      and its stated rationale ("a hardening this script adds, not a deviation").
- [ ] Add the outer `landrun` layer inside the existing `systemd-run` wrapper in
      `run_sandboxed()`, preserving `--no-share` and the guard/fallback branch structure; use
      `--best-effort` for the same reason the reference does (strict mode refuses to start below
      the newest Landlock ABI the installed landrun knows).
- [ ] Enumerate the `--env` passthrough names explicitly (`PATH`, `HOME`, `TMPDIR`,
      `COMPARATOR_LANDRUN`, `COMPARATOR_LEAN4EXPORT`, the shim's own seams) — landrun drops
      everything not named.
- [ ] Add a git-remote pre-flight probe: run `git -C <pkg> remote get-url origin` under the same
      grants before the main run; on failure emit `comparator_unavailable` naming the affected
      package and the reason (Lake would otherwise treat the failure as a changed package URL and
      delete `.lake/packages/<dep>`).
- [ ] Keep `landrun`'s absence non-fatal in the same shape the script already treats a missing
      guard: a loud warning and a degraded-but-proceeding run, never a silent skip.
- [ ] `bash -n`; re-run the existing suite.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` - outer landrun layer in
  `run_sandboxed()`, git-remote pre-flight probe, degraded-path warning

**Verification**:
- `bash -n scripts/lean-comparator-run.sh` exits 0.
- `bash scripts/tests/test-lean-comparator-run.sh` exits 0 with every pre-existing case PASS.
- A pre-flight failure path is reachable: with a stub `git` that exits non-zero on
  `remote get-url`, the runner emits `comparator_unavailable` (exit 69) naming the package.

---

### Phase 4: Regression cases for the new mechanisms [NOT STARTED]

**Goal**: Stub-based cases proving PATH ordering, shim wiring, the shim's own grants, and the
pre-flight probe — asserted from logged argv, never by reading the source.

**Tasks**:
- [ ] Re-read `test-lean-comparator-run.sh`'s house style (the `pass`/`fail`/`info`/`skip`
      helpers, the Case G1-G3 stub-argv-log pattern, the isolated-PATH technique from Case U4).
- [ ] Add a PATH-ordering case: a stub `lake` at a "toolchain bin" path plus a non-executable
      "elan shim" stand-in earlier on `PATH`; assert the invocation resolves the toolchain-bin one.
- [ ] Add an elan-wrapper case: `<toolchain bin>/lake` as a `#!` script with a `lake.orig` beside
      it; assert the private-dir symlink is what lands first on the sandbox `PATH`.
- [ ] Add a shim-wiring case: assert `COMPARATOR_LANDRUN` in the captured environment points at
      `lean-comparator-landrun-shim.sh`, not at the raw resolved `landrun` path.
- [ ] Add a shim-grants case: invoke the shim directly with a stub `git`/`ldd` pair and a stub
      real `landrun` (via `LEAN_COMPARATOR_RUN_REAL_LANDRUN`); assert the logged argv carries the
      `TMPDIR` override, at least one `--rox` library grant, and Comparator's own arguments
      unchanged and in order.
- [ ] Add a pre-flight-probe case: stub `git` failing `remote get-url origin` yields
      `comparator_unavailable` (exit 69) naming the package.
- [ ] Add an anti-vacuous mutation check for at least one new assertion, following Case AV1 and
      the existing `axiom_violation` mutation check: break the mechanism in a copy of the script
      and confirm the new case then FAILS.
- [ ] Extend the suite's header comment block to name the new concern group, and extend the
      Case E1/E2 skip text if any new criterion is deferred for want of a real binary.
- [ ] Add nothing to `manifest.json` (the test file is already listed).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts six new cases plus one mutation check. Confirm at
implementation time by counting the new `pass`/`fail` case labels actually added; if a mechanism
turns out to be unobservable through a stub (e.g. the ELF-interpreter grant on a host without
`readelf`), record it as an explicit `skip` naming the deferred criterion rather than dropping the
case silently or inflating the count.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` - new cases, extended
  header comment, extended skip reporting

**Verification**:
- `bash scripts/tests/test-lean-comparator-run.sh` exits 0; every new case reports PASS or an
  explicitly-worded SKIP, never a silent omission.
- The mutation check demonstrates at least one new assertion is non-vacuous.

---

### Phase 5: Design record and operator guide [NOT STARTED]

**Goal**: `comparator-integration.md` states the diagnosed root cause and every documentation-only
finding; `comparator-guide.md` gains the one operator-facing pointer it needs.

**Tasks**:
- [ ] Rewrite the "Binary Provisioning Status (as measured 2026-09-07, mid-implementation)"
      section's `lake: Permission denied (os error 13)` paragraph: the cause is that a bare `PATH`
      lookup inside the sandbox resolves the elan shim, which landrun cannot execute — not a
      missing grant in Comparator's own `Main.lean`. Supersede the "Comparator's own internal
      concern" framing explicitly, and state that the invocation form `lake env comparator
      config.json` only reaches a working `lake` once the PATH ordering lands, so the fixes are
      ordered, not independent.
- [ ] Add a new subsection documenting the landrun-shim mechanism: why `COMPARATOR_LANDRUN` is the
      only injection point, the `TMPDIR`-inside-`.lake` grant (bv_decide writes SAT files to
      `/tmp`, which the sandbox makes read-only) and that it introduces no new write access, the
      git shared-library `--rox` grants and the `.lake/packages/<dep>` deletion they prevent, and
      the ELF-interpreter grant for nix-ld.
- [ ] Extend the "Verdict Vocabulary" section's `axiom_violation` row and add a subsection for the
      lean4export panic: naming a Challenge-absent axiom in `permitted_axioms` makes lean4export
      panic (`Constant ... not found in environment`, exit 134) while exporting the Challenge side;
      the working handling is to permit only the trusted axioms and require the exact
      `Illegal axiom detected: '<helper>'` rejection as that config's **expected pass**, which
      still proves statement equality (Comparator checks statements before axiom membership) but
      not kernel acceptance.
- [ ] Add the `lake update --keep-toolchain` pitfall under "Env Var / Binary Resolution and the C3
      Version-Coupling Caveat": in a tool-pinning package a plain `lake update` silently adopts
      the tool's own newer `lean-toolchain`, so every later build targets the wrong Lean; the
      defense is a coherence check comparing `lean-toolchain` files and grepping each built binary
      for the target project's `lean --githash`.
- [ ] Add the batched-Lean4Lean caveat, framed explicitly as not applicable to this script's own
      single in-process Comparator invocation but load-bearing for any future kernel-replay
      sibling: a batched whole-package run reached 19 GB RSS and was killed by `earlyoom`, which
      also SIGTERM'd an unrelated concurrent `lean`; run one module per process.
- [ ] Record the outer-landrun hardening as a deliberate design decision in the "Sandbox
      Invocation and Guard Nesting" section, with its rationale (never trust Lake package
      management with more than the room it is confined to) and the git pre-flight probe.
- [ ] Add the new reference paths to the "References" section
      (`framed_channel/scripts/recheck-comparator.sh`,
      `framed_channel/scripts/comparator-configs.sh`,
      `framed_channel/scripts/lib/recheck-revs.sh`, `framed_channel/recheck/landrun-shim.sh`).
- [ ] Add a one-to-two-sentence pointer in `comparator-guide.md` for an operator hand-constructing
      `permitted_axioms`, referencing the new design-record subsection by heading; do not
      restructure the file (it deliberately omits implementation detail).
- [ ] Cite durable anchors only — file names, section headings, measured dates. No "task N"
      references in either file (rules/no-task-references-in-deliverables.md).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` -
  diagnosed root cause, shim subsection, lean4export panic, `--keep-toolchain`, earlyoom caveat,
  outer-landrun decision, references
- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md` - one operator
  pointer to the new design-record subsection

**Verification**:
- Every changed hunk is prose; no code fence claims behavior the Phase 1-3 scripts do not have
  (spot-check each asserted flag name and env var against the scripts).
- `bash .claude/scripts/check-task-references.sh` (or the repo's equivalent lint) reports no new
  task-number reference in either file.
- Every cross-reference heading named in `comparator-guide.md` exists verbatim in
  `comparator-integration.md`.

---

### Phase 6: Lean dependency-tracing recipe [NOT STARTED]

**Goal**: A new lean4 pattern file answering "does X depend on Y?" mechanically, harvested from
working probes rather than re-derived, with the `#print axioms` trap stated up front.

**Tasks**:
- [ ] Read the probes at
      `~/Projects/BimodalLogic/specs/archive/549_trace_decide_dependency_on_vacuous_run_theorems/probes/`
      — note they have moved into `specs/archive/`, not the path the task description gives:
      `DepTrace.lean`, `DepTrace2.lean`, `RevDep.lean`, `Widen.lean`, `Ax.lean`, `Exists.lean`,
      and `probe-evidence.md`. Harvest; do not re-derive.
- [ ] Create `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md`
      opening with the load-bearing caveat: `#print axioms` is not a dependency tracer — in the
      observed case a decision procedure, its soundness theorem, and the vacuous theorem under
      suspicion all reported the same `[propext, Classical.choice, Quot.sound]`, so an axiom check
      answers "is this sound?" and never "what does this rest on?".
- [ ] Reproduce the four probe shapes as self-contained adaptable templates: (1) forward
      transitive closure via `Expr.getUsedConstants` over both type and value, iterated to a fixed
      point from a named entry point then intersected with a suspect set; (2) the module-index
      variant counting hits attributable to a target module; (3) the whole-environment reverse
      dependency scan ("what would break if I deleted this?"); (4) the import-closure check
      distinguishing "unused" from "unavailable".
- [ ] Record the two operational notes: run probes with `lake env lean` against existing oleans
      rather than a full `lake build` (the observed trace needed no rebuild), and resolve
      declarations by name, never by line number, because line numbers in a report go stale.
- [ ] Add an `index-entries.json` entry for the new path, modeled on the existing
      `project/lean4/patterns/tactic-patterns.md` entry (same `load_when` agents/task_types shape,
      accurate `line_count`, `domain`/`subdomain`, summary, keywords).
- [ ] Add a one-line pointer in `EXTENSION.md` beside the existing
      `patterns/mcp-fallback-table.md` line, following the single-statement-plus-pointer
      convention rather than restating the recipe.
- [ ] The file must be usable without access to the originating repository: no path in it is the
      sole carrier of a probe's content.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` - new file
- `agent-system/extensions/lean/index-entries.json` - index entry for the new pattern file
- `agent-system/extensions/lean/EXTENSION.md` - one-line pointer

**Verification**:
- All four probe shapes are present as templates a reader can adapt with no access to
  `~/Projects/BimodalLogic`.
- The `#print axioms` caveat appears before the first template, with the concrete observation that
  three declarations at different dependency depths reported identical axioms.
- `python3 -c "import json;json.load(open('index-entries.json'))"` succeeds and the new path is
  present; `line_count` matches `wc -l` of the new file.
- No task-number reference in any of the three files.

---

### Phase 7: Redeploy `.claude/` and close the round [NOT STARTED]

**Goal**: The source-store changes reach the deploy tree, and the full gate set passes.

**Tasks**:
- [ ] Run the lean extension's full test set from the source store:
      `bash agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` plus the
      sibling lean tests, and the repo's shell-test runner if it covers them.
- [ ] Redeploy: `bash .claude/scripts/deploy-headless.sh` (resolving the invocation from
      `.claude-extensions.json`'s `source_dir`), then `bash .claude/scripts/verify-deploy.sh`.
- [ ] Confirm `.claude/scripts/lean-comparator-landrun-shim.sh` exists and is executable
      post-deploy, and that `.claude/context/project/lean4/patterns/dependency-tracing.md` landed.
- [ ] Re-run the deployed test suite from `.claude/scripts/tests/` to confirm the deployed copy
      passes as the source copy did.
- [ ] Verify no file under `.claude/**` was hand-edited during this task (`git status` shows only
      deploy-generated changes there, and `.claude/` is gitignored).
- [ ] Commit each phase's work with the `task {N}: ...` convention, staging by explicit file path
      only — never a directory or glob pathspec, per this cycle's concurrency note.

**Timing**: 0.75 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- none planned (deploy regenerates `.claude/**`; no hand edits there)

**Verification**:
- `verify-deploy.sh` exits 0.
- The deployed test suite exits 0 with the same case results as the source-store run.
- Both new deployed paths exist.

---

## Testing & Validation

- [ ] `bash -n` clean on both scripts; `shellcheck` clean if available.
- [ ] `test-lean-comparator-run.sh` exits 0, with every pre-existing case still PASS.
- [ ] New cases cover PATH ordering, elan-wrapper unwrapping, shim wiring, shim grants
      (`TMPDIR` + at least one `--rox`), and the git pre-flight probe.
- [ ] At least one new assertion is proven non-vacuous by a mutation check.
- [ ] Every criterion not achievable for want of a real `landrun`/`lean4export`/`nanoda_bin` is
      reported as an explicit SKIP naming what is deferred — never a silent pass.
- [ ] `manifest.json` and `index-entries.json` both parse as JSON and carry the new paths.
- [ ] No task-number references in any file outside `specs/**`.
- [ ] `verify-deploy.sh` exits 0 after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-comparator-landrun-shim.sh` (new)
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` (modified)
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` (modified)
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` (modified)
- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md` (modified)
- `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` (new)
- `agent-system/extensions/lean/manifest.json`, `index-entries.json`, `EXTENSION.md` (wiring)
- Regenerated `.claude/` deploy tree
- `specs/223_record_comparator_nixos_fixes_in_lean_extension/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase is a scoped, per-file commit, so any single phase reverts with `git revert` of its own
commit without disturbing the others. The source store is git-tracked; `.claude/` is a
regenerable deploy artifact, so a bad deploy is recovered by re-running `deploy-headless.sh` from a
good source-store commit, never by hand-editing `.claude/**`.

If Phase 2 or 3 cannot be made to pass the existing suite, stop at Phase 1 plus Phases 5-6 (the
shim and all documentation are independently valuable and independently verifiable) and report the
runner changes as `[BLOCKED]` with the failing case named — do not weaken an existing assertion to
make a new mechanism fit.

If a concurrent sibling task is found to have modified `manifest.json` or any lean-extension file
in this scope, STOP and report rather than merging or reverting a foreign change.
