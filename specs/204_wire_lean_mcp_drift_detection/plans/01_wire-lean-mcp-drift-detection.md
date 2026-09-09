# Implementation Plan: Task #204

- **Task**: 204 - Wire verify-lean-mcp.sh into a moment where lean-lsp registration drift is actually caught
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: Task 203 (COMPLETED — reconciled the sanctioned registration shape; its changes to `verify-lean-mcp.sh` are already reflected below)
- **Research Inputs**: specs/204_wire_lean_mcp_drift_detection/reports/01_wire-verify-lean-mcp-preflight.md
- **Artifacts**: plans/01_wire-lean-mcp-drift-detection.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`core/scripts/verify-lean-mcp.sh` already diagnoses lean-lsp MCP registration drift correctly and
already names `setup-lean-mcp.sh` as the remedy — nothing ever invokes it, so a broken registration
sat undetected indefinitely. This plan supplies the missing invocation: a new thin, lean-owned
wrapper (`lean-mcp-preflight-check.sh`) that calls the existing verifier, stays silent both when
registration is correct and when the current directory is not a Lean project, and otherwise emits
one actionable message naming the remedy — invoked directly from the Stage 2 preflight block of the
four lean skills that dispatch to lean-lsp-using agents. Done means: a drifted registration is
detected at that moment and demonstrated against a fixture (not asserted), a correct registration
and a non-Lean repository each produce zero output, the added wall-clock cost is measured and
recorded, and every touched shell file is shellcheck clean.

### Research Integration

The research report determines the wiring point and the warn/block posture, and both are adopted
here without re-litigation:

- **Wiring point**: the lean extension's manifest has **no top-level `hooks` object**, and none of
  the four lean-lsp-using skills route Stage 2 through `skill_preflight_update` in `skill-base.sh`
  (`skill-lean-research` writes state.json via `state-write.sh`; the other three call
  `update-task-status.sh preflight` directly). A manifest `hooks.preflight` declaration for lean
  would therefore be **dead code**. The check is wired as a direct per-skill Stage 2 call instead.
  Rejected alternatives (with the research report's reasons): manifest `hooks.preflight` as-is
  (never invoked given the live call graph); dispatch-time invocation in
  `orchestrate-build-dispatch.sh` (invisible to directly-invoked `/research`, `/plan`, `/implement`);
  `SessionStart` hook (fires once per session for every repo and task type, misses lean work begun
  mid-session, and puts lean-specific logic in core's global `settings.json`).
- **WARN, never BLOCK**: lean4 work without lean-lsp is a real, accepted degraded mode (compiled
  probes). The wrapper always exits 0 and no call site treats its output as failure. The defect
  being fixed is *silence*, not *permissiveness* — an unactionable warning is what failed before, so
  every emitted message must name `setup-lean-mcp.sh`.
- **Verifier contract already changed under this task's feet** (task 203): command/args mismatches
  are now hard **FAIL** (exit 1), Check 3 rejects any `command` resolving inside a `.claude/` deploy
  tree, Check 9 rejects a project-scoped entry shadowing the global one, Check 7 (project path
  mismatch) is the sole **exit 2**, Check 8 (missing lakefile at the configured path) is warn-only.
  The originally-quoted `[WARN] Unexpected command` text in the task description is obsolete.
- **Measured baseline**: `verify-lean-mcp.sh --quiet` averaged ~30ms wall clock against the live
  183KB `~/.claude.json`; a bare single `jq` read of the same key is ~7ms. jq-only, no network, no
  repo walk, no server spawn.

**One deliberate refinement over the report's recommendation** (see Decisions): the wrapper makes a
single **non-quiet** invocation with output captured and discarded on success, rather than `--quiet`
plus a hypothetical second run. Same cost on the green path, same silence on the green path, but the
failure message can carry the verifier's own already-correct diagnosis line instead of a
lowest-common-denominator restatement of an exit code.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Give `verify-lean-mcp.sh` an automated caller at the moment a lean4 task is about to run.
- Emit an actionable, remedy-naming signal on drift; emit nothing at all on a correct registration
  or outside a Lean project.
- Keep the check to a jq-only read of a single `~/.claude.json` key, and measure/record the cost.
- Prove detection against a fixture reproducing the observed shape (a command path that does not
  exist on disk, inside a `.claude/` deploy tree), not by assertion.

**Non-Goals**:
- Changing `verify-lean-mcp.sh`'s own checks, exit codes, or its operator-facing loud "Could not
  detect Lean project path" error on manual invocation outside a Lean project.
- Re-litigating the sanctioned registration shape settled by the dependency task.
- Merging with, or pre-empting, the consumer-repo deploy-propagation work (`specs/200_*`) — that
  task is `[NOT STARTED]` with empty artifact directories, so there is no preflight mechanism there
  to reuse yet. Same architectural instinct, different subject (deployed-tree staleness vs. MCP
  registration drift).
- Migrating the lean skill family onto `context/patterns/skill-preflight-flow.md`'s shared
  Stage 2+3 block. That is the correct eventual home for this check (it would collapse four call
  sites into one manifest `hooks.preflight` declaration, exactly as nix already does), but it is a
  materially larger, separately-risky refactor touching postflight markers and monotonic-max
  clamping. Recorded as a follow-up in Phase 5, not undertaken here.
- Any block, gate, or repository scan on a hot path.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A malformed bash block in a `SKILL.md` Stage 2 breaks preflight for all lean4 tasks | H | L | The insert is a single self-contained `if [ -x ... ]` guard appended *after* each skill's existing, unmodified status-update call; no existing Stage 2 logic is reordered or edited. Phase 4 diffs each file to confirm only an addition |
| Wrapper message text couples to the verifier's output format and silently degrades if that text changes | M | M | Filter the captured output for `[FAIL]`/`[WARN]`/`Run setup-lean-mcp` lines; if the filter yields nothing, fall back to a generic one-liner that still names `setup-lean-mcp.sh`. Phase 2 covers the empty-filter fallback with its own fixture |
| Exit 2 (project path mismatch) fires legitimately whenever the operator works across two Lean projects, so a harsh message trains people to ignore it | M | H | Word exit 2 as informational ("lean-lsp currently indexes a different project") and distinct from exit 1 ("misregistered"), still naming the remedy. Phase 2 asserts the two messages differ |
| Wrapper's own Lean-project detection drifts from `verify-lean-mcp.sh`'s | M | L | Copy the detection verbatim (CWD `lakefile.lean`/`lakefile.toml`, else git root), with a header comment naming the lockstep requirement; Phase 2 fixture C covers the non-Lean case |
| Hand-editing `.claude/**` instead of the source store — the edit is silently wiped on next deploy | H | L | Every write target in this plan is under `agent-system/extensions/{lean,core}/**`. Phase 5 re-deploys and verifies the artifact appears in `.claude/scripts/` |
| shellcheck assumed absent from a non-interactive `$PATH` | L | L | Confirmed available: bare `shellcheck --version` resolves to 0.11.0 in this environment. No special invocation needed |
| Task numbers leak into a deliverable outside `specs/**` | M | M | The new script, its tests, the manifest, and the inventory doc must cite durable anchors (filenames, section headings) only. Phase 5 runs the repo-wide task-reference lint |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Author the lean-owned preflight wrapper [COMPLETED]

**Goal**: A new script that turns the existing verifier into something safe to call on a hot path —
silent on green, silent outside a Lean project, actionable on drift, never fatal.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/verify-lean-mcp.sh` and confirm the current
      exit-code map before writing any dispatch logic on it. Expected as of this plan: **exit 0** =
      valid; **exit 2** = Check 7 project-path mismatch only; **exit 1** = everything else (config
      absent, `lean-lsp` unregistered, command inside a `.claude/` tree, wrong command, wrong args,
      `LEAN_PROJECT_PATH` unset, configured path nonexistent, project-scoped shadow entry). If the
      map has changed again, update this plan's Phase 2 fixture expectations before proceeding.
- [x] Create `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`, `chmod +x`.
- [x] `set -euo pipefail` (Class A per `shell-strict-mode.md`: no counter idiom, not sourced).
- [x] Accept — and ignore — the five positional lifecycle args other hook scripts take
      (`task_number`, `task_type`, `task_dir`, `session_id`, `operation`), so the script can later be
      moved to a manifest `hooks.preflight` declaration without a signature change. Model the header
      on `agent-system/extensions/nix/scripts/nix-preflight.sh`.
- [x] **Lean-project pre-check first**: if neither `lakefile.lean` nor `lakefile.toml` exists in
      `$PWD`, and neither exists at `git rev-parse --show-toplevel`, `exit 0` immediately with no
      output. Copy this detection verbatim from `verify-lean-mcp.sh`, with a comment naming the
      lockstep requirement. This satisfies WORK item (d) without touching the verifier's own
      operator-facing loud error.
- [x] Locate the verifier at `.claude/scripts/verify-lean-mcp.sh` (its deployed path — confirmed
      present); if it is absent, `exit 0` silently (a deploy that predates it must not produce noise).
- [x] Invoke it **once**, non-quiet, capturing stdout+stderr and the exit status without tripping
      `-e` (`output=$(... ) || rc=$?` form). On `rc = 0`, print nothing and `exit 0`.
- [x] On non-zero: print one `[lean-mcp-preflight]` header line whose wording distinguishes
      `rc = 2` ("lean-lsp currently indexes a different Lean project") from all other non-zero rc
      ("lean-lsp MCP registration does not match the sanctioned form"), then the captured lines
      matching `^\[FAIL\]`, `^\[WARN\]`, or `^Run setup-lean-mcp`. If that filter yields nothing,
      print a single fallback line naming `setup-lean-mcp.sh` as the remedy. Every branch names
      `setup-lean-mcp.sh`.
- [x] `exit 0` unconditionally at the end — the contract is WARN, never BLOCK.
- [x] Header comment records: WARN-only contract, always-exit-0 guarantee, the detection-lockstep
      requirement, and the follow-up note that this belongs behind a manifest `hooks.preflight`
      declaration once the lean skills adopt `skill-preflight-flow.md`. No task numbers.
- [x] `shellcheck agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` — clean.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` - new file, the entire wrapper

**Verification**:
- shellcheck exits 0 with no output.
- Run from a non-Lean directory (e.g. this repo's root): exits 0, prints nothing.
- Run from `~/Projects/BimodalLogic` against the live config: exits 0 and prints a message naming
  `setup-lean-mcp.sh` (the live global entry currently points elsewhere, so a non-zero verifier rc
  is expected there today).

---

### Phase 2: Fixture-based regression suite proving detection [COMPLETED]

**Goal**: Demonstrate — not assert — that the observed drift shape is detected, that a correct
registration is silent, and that a non-Lean repository is silent.

**Tasks**:
- [x] Create `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh`, `chmod +x`.
- [x] Follow the core shell-test convention (`shell-script-testing.md`; model on the sibling
      `tests/test-lean-sorry-census.sh`): `set -uo pipefail` (Class B — counter idiom),
      `pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` counters, `mktemp -d` workdir with a
      `trap EXIT` cleanup, `exit 0` on all-pass / `exit 1` on any-fail.
- [x] Isolate every fixture by pointing `HOME` at a per-fixture temp dir holding a synthetic
      `.claude.json` — `verify-lean-mcp.sh` reads `"$HOME/.claude.json"` with no other override, so
      this needs no change to the verifier. Never read or assert against the real `~/.claude.json`.
- [x] Fixture A — **the observed shape**: a fixture Lean project dir (containing `lakefile.lean`,
      `git init`ed) plus a `.claude.json` whose `.mcpServers."lean-lsp".command` is an absolute path
      inside a `.claude/` tree that does not exist on disk (e.g.
      `<fixture>/repo/.claude/scripts/lean-lsp-mcp-wrapper.sh`). Assert: wrapper exit 0, output
      non-empty, output contains `setup-lean-mcp.sh`.
- [x] Fixture B — **correct registration**: `command: "uvx"`, `args: ["lean-lsp-mcp"]`,
      `env.LEAN_PROJECT_PATH` equal to the fixture project dir, no `.projects[...]` shadow entry.
      Assert: exit 0 and **empty** output.
- [x] Fixture C — **not a Lean project**: a git repo with no lakefile at CWD or git root (config
      contents irrelevant). Assert: exit 0 and empty output.
- [x] Fixture D — **project-path mismatch (exit 2 path)**: otherwise-correct entry whose
      `LEAN_PROJECT_PATH` points at a different existing Lean fixture dir. Assert: exit 0, output
      non-empty, contains `setup-lean-mcp.sh`, and **differs from fixture A's output** — the
      anti-vacuous guard proving the wrapper actually reads the verifier's exit code rather than
      printing one blanket message for all failures.
- [x] Fixture E — **fallback path**: stub a `verify-lean-mcp.sh` on the resolved path that exits 1
      with output containing none of `[FAIL]`/`[WARN]`/`Run setup-lean-mcp`. Assert: exit 0, output
      non-empty and still contains `setup-lean-mcp.sh` (the generic fallback line fired).
- [x] Run the suite; all fixtures pass.
- [x] Falsifiability check: temporarily neutralize the wrapper's failure branch (make it print
      nothing on non-zero rc), confirm fixtures A, D, and E **FAIL** while B and C still pass, then
      restore. Record this in the suite header as the mutation check.
- [x] `shellcheck` the suite — clean.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: five fixtures (A–E) are hypothesized sufficient to cover the acceptance bar
(drift detected / correct silent / non-Lean silent / exit-2 distinguished / text-coupling fallback).
Confirm at implementation time by mapping each acceptance clause in the task description to a named
fixture; add fixtures if any clause is uncovered, and record the final count in the summary.

**Files to modify**:
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` - new regression suite

**Verification**:
- `bash agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` exits 0 with all
  fixtures PASS.
- The mutation check above showed A/D/E failing before the fix and passing after — recorded, not
  claimed.

---

### Phase 3: Measure and record the added wall-clock cost [COMPLETED]

**Goal**: Turn WORK item (c) from an intention into a recorded number, for all three paths the check
can take.

**Tasks**:
- [x] Time the wrapper (5 runs each, report the mean) in three scenarios: (i) non-Lean directory
      (early-exit path — expect a few ms: one or two `test`s plus one `git rev-parse`); (ii) a Lean
      project with a correct registration (full verifier run, output discarded); (iii) a Lean project
      with a drifted registration (full verifier run plus message synthesis).
- [x] Compare against the recorded baselines: `verify-lean-mcp.sh --quiet` ~30ms, a bare single `jq`
      read ~7ms. Confirm the wrapper adds no measurable overhead of its own beyond one `git rev-parse`.
- [x] Confirm by inspection that the executed path performs no repository walk, no network call, and
      no MCP server spawn.
- [x] Record the three figures in the wrapper's header comment (one line) and in the implementation
      summary. No task numbers in the script header.
- [x] If scenario (ii) exceeds ~100ms on this machine, stop and record it as a finding rather than
      wiring the call sites — a check that expensive on a hot path is one that gets disabled.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` - header comment gains the
  measured-cost line

**Verification**:
- Three measured means recorded, each traceable to a reproducible timing command in the summary.
- Scenario (ii) is within the same order of magnitude as the ~30ms verifier baseline.

---

### Phase 4: Wire the call sites and register the script for deploy [NOT STARTED]

**Goal**: The check actually runs at the moment a lean4 task is about to dispatch — and the script
actually reaches `.claude/scripts/` on deploy.

**Tasks**:
- [ ] Append the invocation to **Stage 2 (Preflight Status Update)** of each lean SKILL.md that
      dispatches to a lean-lsp-using agent, immediately after that skill's existing, unmodified
      status-update call:
      `agent-system/extensions/lean/skills/skill-lean-research/SKILL.md` (whose Stage 2 uses
      `state-write.sh`), `.../skill-lean-research-hard/SKILL.md`, `.../skill-lean-implementation/SKILL.md`,
      `.../skill-lean-implementation-hard/SKILL.md` (the latter three use
      `update-task-status.sh preflight`).
- [ ] Use one self-contained, existence-guarded block per file, worded identically across all four:
      an `if [ -x .claude/scripts/lean-mcp-preflight-check.sh ]` guard wrapping a
      `bash .claude/scripts/lean-mcp-preflight-check.sh || true` call, with a one-line comment stating
      the WARN-only contract. Do not reorder or edit any existing Stage 2 content.
- [ ] Explicitly leave `skill-lake-repair` and `skill-lean-version` untouched — both are
      direct-execution skills with no lifecycle preflight and no lean-lsp usage.
- [ ] Do **not** add a top-level `hooks` object to `agent-system/extensions/lean/manifest.json`. It
      would be inert given the current call graph and would falsely imply the nix mechanism is live
      for lean.
- [ ] Add `lean-mcp-preflight-check.sh` and `tests/test-lean-mcp-preflight-check.sh` to
      `agent-system/extensions/lean/manifest.json`'s `provides.scripts` array (both entries are
      relative to the extension's `scripts/` dir, matching how `lean-sorry-census.sh` and its test
      are already listed).
- [ ] `git diff` each of the six touched files and confirm every hunk is a pure addition.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: exactly four SKILL.md files require the call site. Confirm at implementation
time with `grep -rln 'lean-research-agent\|lean-implementation-agent' agent-system/extensions/lean/skills/*/SKILL.md`
before editing; if that set is not exactly the four named above, reconcile and record the discrepancy
rather than editing the four blindly.

**Files to modify**:
- `agent-system/extensions/lean/skills/skill-lean-research/SKILL.md` - Stage 2 gains the guarded call
- `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md` - same
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` - same
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` - same
- `agent-system/extensions/lean/manifest.json` - `provides.scripts` gains two entries

**Verification**:
- `jq -e '.provides.scripts | index("lean-mcp-preflight-check.sh")' agent-system/extensions/lean/manifest.json`
  succeeds, and the same for the test path.
- `jq empty agent-system/extensions/lean/manifest.json` — valid JSON.
- All four Stage 2 blocks contain exactly one occurrence of the guarded call, byte-identical across files.
- No diff hunk removes or reorders pre-existing Stage 2 lines.

---

### Phase 5: Documentation, deploy verification, and final gates [NOT STARTED]

**Goal**: The inventory stops claiming the verifier has no automated caller, the artifact actually
lands in a deploy tree, and every repo-wide gate is green.

**Tasks**:
- [ ] Update the `verify-lean-mcp.sh` entry in
      `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — remove
      "Invoked manually by an operator; no automated caller by design" and name the new automated
      caller and the moment it fires. Durable anchors only, no task numbers.
- [ ] Add an inventory entry for `lean-mcp-preflight-check.sh` describing its WARN-only,
      always-exit-0 contract, its silent non-Lean-project path, and its measured cost.
- [ ] Record the follow-up (migrate the four lean skills onto `skill-preflight-flow.md`, then replace
      the four inline calls with a single manifest `hooks.preflight` declaration pointing at this same
      script) in the inventory entry and the script header — as a durable-anchor note, not a task
      reference. Optionally raise it with `/task` after this task lands.
- [ ] Run `shellcheck` over both new shell files and confirm clean per `shell-strict-mode.md`.
- [ ] Re-run the regression suite end to end after all edits.
- [ ] Deploy/reload this repository's extension set and confirm the new script appears at
      `.claude/scripts/lean-mcp-preflight-check.sh` with the executable bit (note: the lean extension
      is not currently loaded in this repo, so verify in a repo that loads it, or verify the manifest
      entry resolves during a dry-run deploy — record which was done).
- [ ] Run the repo-wide task-reference lint (`scripts/check-task-references.sh`) and confirm no new
      occurrence outside `specs/**`.
- [ ] Confirm no file under any `.claude/**` tree was hand-edited (`git status` shows changes only
      under `agent-system/**` and `specs/**`).

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - revised
  `verify-lean-mcp.sh` entry plus a new entry for the wrapper

**Verification**:
- `grep -n "no automated caller" agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
  returns nothing for the `verify-lean-mcp.sh` entry.
- `shellcheck` clean on both new scripts; regression suite exits 0.
- `check-task-references.sh` reports no new violations.
- `git status --short` shows no modifications under any `.claude/` path.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` exits 0,
      every fixture PASS.
- [ ] Fixture A (a `command` path inside a `.claude/` tree that does not exist on disk) produces
      non-empty output naming `setup-lean-mcp.sh` — the acceptance bar's "demonstrated, not asserted".
- [ ] Fixture B (correct registration) produces byte-empty output.
- [ ] Fixture C (non-Lean repository) produces byte-empty output and exit 0.
- [ ] Fixture D's message differs from fixture A's (exit-2 vs exit-1 branches are genuinely distinct).
- [ ] Mutation check recorded: fixtures A/D/E fail against a neutralized wrapper.
- [ ] Three wall-clock measurements recorded (non-Lean early exit / correct registration / drifted).
- [ ] `shellcheck` clean on `lean-mcp-preflight-check.sh` and its test suite.
- [ ] `jq empty` passes on the modified lean manifest; both new `provides.scripts` entries present.
- [ ] No task-number references introduced outside `specs/**`.
- [ ] No hand-edits under any `.claude/**` tree.

## Artifacts & Outputs

- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh` (new)
- `agent-system/extensions/lean/scripts/tests/test-lean-mcp-preflight-check.sh` (new)
- `agent-system/extensions/lean/manifest.json` (modified — `provides.scripts`)
- `agent-system/extensions/lean/skills/skill-lean-research/SKILL.md` (modified — Stage 2)
- `agent-system/extensions/lean/skills/skill-lean-research-hard/SKILL.md` (modified — Stage 2)
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` (modified — Stage 2)
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` (modified — Stage 2)
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (modified)
- `specs/204_wire_lean_mcp_drift_detection/summaries/01_*-summary.md` (implementation summary,
  carrying the three measured cost figures and the confirmed fixture count)

## Rollback/Contingency

Every change is additive and confined to the source store. To revert: delete the two new files under
`agent-system/extensions/lean/scripts/`, revert the two `provides.scripts` entries in the lean
manifest, revert the single appended block in each of the four `SKILL.md` files, and revert the
inventory doc edits — then re-deploy. Because the wrapper is existence-guarded at every call site and
always exits 0, a partially-reverted state (script removed but call sites still present, or vice
versa) is itself harmless: the guard skips a missing script silently, and an orphaned script is
simply never invoked. No state, config, or `~/.claude.json` mutation is performed anywhere in this
plan, so there is nothing to restore outside the repository.
