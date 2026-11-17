# Implementation Plan: Task #627

- **Task**: 627 - Reap orphan sapience MCP registrations
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/627_reap_orphan_sapience_mcp_registrations/reports/01_reap-orphan-sapience-mcp.md
- **Artifacts**: plans/01_reap-orphan-sapience-mcp.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a cross-project `--reap` mode to the sapience MCP writer (`setup-sapience-mcp.sh`) that
deletes `.projects[<path>].mcpServers.sapience` for every `<path>` that is not a directory on
disk, and restructure the `SessionStart` hook so that reap pass runs on **every** session start,
independent of whether the current session's repo has a reachable `.claude-extensions.json`.
This closes the structural gap research confirmed from source: the hook's existing
register/remove logic is gated on finding that manifest at the CWD or git root, a precondition an
orphaned (deleted or renamed) project directory can never satisfy, so its entry leaks forever.
The reap pass is deliberately global and ungated, because the only session that can clean up
after a vanished repo is some *other*, still-living session.

### Research Integration

The research report settled the design decisions this plan executes, and they are adopted without
re-deriving them:

- **Where**: a new `--reap` mode on `setup-sapience-mcp.sh`, the writer — the single existing
  choke point for every `~/.claude.json` mutation (`process_write`, `process_remove`,
  `--retire-global` each do `mktemp` + whole-file `jq` + `mv`). The hook never edits the file
  itself; it only chooses which writer invocation to make.
- **When**: invoked unconditionally by the hook on every session start, placed before and
  independent of the `.claude-extensions.json` reachability branch.
- **Scope of a pass**: `del(.projects[$p].mcpServers.sapience)` only. Other servers on the same
  row (e.g. `lean-lsp`) survive; a row left with `"mcpServers": {}` is the accepted, explicitly
  documented end state, not a further cleanup target — deleting the whole project row would
  discard unrelated session/history/cost metadata.
- **Rejected alternatives** (recorded, not revisited): inlining reap in the hook (would make the
  hook the first direct `~/.claude.json` mutator, breaking the single-choke-point convention);
  promoting `verify-sapience-mcp.sh` from detect-only to fixer (its contract is explicitly
  single-project, `--project PATH`).

Two mechanics this plan adds on top of the report, found while reading the writer's own control
flow at planning time:

- **`--reap` must be a standalone action placed before interpreter resolution.**
  `setup-sapience-mcp.sh` resolves `INTERPRETER` at top level (`resolve_interpreter`, which
  `exit 1`s when neither a top-level entry nor `command -v python3` resolves) *after* the
  `--retire-global` short-circuit. A reap pass needs no interpreter at all, so it must
  short-circuit in the same place `--retire-global` does; placing it later would make the
  hook's reap call fail outright on a machine with no resolvable `python3`.
- **The hook's `jq`-present and writer-exists checks must move above the manifest-reachability
  branch**, since reap depends on both and must run even when the manifest is unreachable. The
  manifest branch then stops being an early `exit 0` and becomes a "skip the per-repo half"
  flag, with notice assembly at the end merging the (possibly absent) reap notice and the
  (possibly absent) per-repo notice into exactly one JSON line.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; `specs/ROADMAP.md` was not consulted.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch extracted from the task description was re-checked against
live state at planning time. Results, stated explicitly even where unchanged:

1. **"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/sapience/**`" — CONFIRMED.**
   `jq -r '.extensions.sapience.source_dir' .claude-extensions.json` returns
   `/home/benjamin/.config/nvim/agent-system/extensions/sapience`. All edit targets below are
   under it; no `.claude/**` path is named in any phase's `Files to modify`.
2. **"`~/.claude.json` carries `.projects["/home/benjamin/Projects/sapience-app"].mcpServers.sapience`"
   — NO LONGER TRUE, and this does not close the task.** Re-measured live: that row exists but
   carries `"mcpServers": {}` — no `sapience` subkey at all. The row was cleaned by some other
   means before the research pass (research recorded the same observation). Sweeping all 41
   project rows, **zero** rows currently carry a server for a path that is absent from disk, so
   the acceptance criterion "the stale entry is gone" is already satisfied and is a no-op rather
   than a reproducible repro. Treat the cited path as illustrative of the defect class.
   Consequence for this plan: live acceptance cannot demonstrate a reap; the discriminating
   evidence must be fixture-based (Phases 2-3), and the live checks (Phase 4) are regression
   checks that nothing *live* was wrongly reaped.
3. **"the hook ... emits `{}` and exits 0 before reaching the removal branch at all" — CONFIRMED
   from source.** `hooks/sapience-mcp-register-project.sh:82-92` is the manifest-reachability
   branch whose `else` arm is `echo '{}'; exit 0`; the removal branch is at lines 125-139, after
   it. The diagnosis is exact: it is a precondition an orphan cannot satisfy, not a bug in the
   removal logic.
4. **"a project row carrying other servers (e.g. `lean-lsp`) keeps them" — the live file does
   contain such rows.** `/home/benjamin/Projects/BimodalLogic` carries both `lean-lsp` and
   `sapience`; `/home/benjamin/Projects/Logos/Theory`, `/home/benjamin/Projects/cslib` and
   `/home/benjamin/Projects/cslib-pr648` carry `lean-lsp` only. All four paths exist on disk, so
   none is a reap candidate today — but the mixed-server row is a real shape, and Phase 2's
   sharpest fixture case reproduces it against an absent path.
5. **"`verify-sapience-mcp.sh` still passes its (a)-(d) checks in this repository" — CONFIRMED
   as the research pass reported it**, including the pre-existing, unrelated (e) failure (the
   documented "loaded before the grant was narrowed to 7" residual). Acceptance requires only
   (a)-(d); Phase 4 re-runs it and compares against this same (a)-(d)-pass / (e)-fail baseline
   rather than demanding a clean exit 0.

## Goals & Non-Goals

**Goals**:

- A `--reap` action on `setup-sapience-mcp.sh` that removes `.projects[<path>].mcpServers.sapience`
  for every registered `<path>` absent from disk, touching no other key and honoring `--dry-run`
  and `--quiet`.
- The `SessionStart` hook invokes that reap pass on every session start, in every repository,
  independent of its own manifest-reachability and activation state.
- The hook's existing contract is preserved exactly: always exit 0; always exactly one line of
  valid JSON on stdout; never fails a session on missing `jq`, a missing writer, or an unwritable
  `~/.claude.json`.
- `test-sapience-mcp-registration.sh` gains discriminating cases for a registered-but-nonexistent
  project path, including the mixed-server row and the explicit `"mcpServers": {}` end state.
- The deployed tree is regenerated and the user-level installed hook/writer copies are refreshed,
  so the fix is live rather than source-only.

**Non-Goals**:

- A parallel reaper for the lean extension's identically-shaped `lean-lsp` triad (the same gap
  likely exists there; this task names only the sapience extension).
- Promoting `verify-sapience-mcp.sh` to a fixer, or widening it past its single-project,
  detect-only contract.
- Removing an emptied `"mcpServers": {}` object, or deleting a whole orphaned `.projects` row.
- Stat-based disambiguation of "absent" from "exists but inaccessible" (see Risks).
- Fixing `verify-sapience-mcp.sh` check (e)'s pre-existing, documented grant-count residual.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A path that exists but is unreadable/unmounted reads as absent via `[ -d ]` and is wrongly reaped | M | L | Accepted as a documented edge case, per the research decision: the entry is cheaply re-registered by the next session start in that repo (the hook's register branch), so the failure mode is self-healing rather than lossy. Documented inline in `process_reap` and in the domain doc (Phase 4) |
| Hook restructuring breaks the one-line-JSON contract on a path where neither half fires | H | M | Phase 3 adds an explicit case asserting exactly one parseable JSON line across every hook path, and the existing silence cases (11, 13, 14, 15, 26, 28) are re-run unchanged as the regression net |
| Reap runs before the writer-exists / `jq`-present guards and surfaces noise on every session | H | L | Phase 3 moves those two guards *above* the reap call, not below it; existing case 14 (missing writer is silent) is the mechanical check |
| Concurrent sessions reaping simultaneously | L | M | Inherits the pre-existing `mktemp` + whole-file `jq` + `mv` last-writer-wins profile that every other writer action already has; no new risk class introduced |
| Live acceptance is a no-op (no orphan exists today), so a vacuous implementation could appear to pass | M | M | Fixture cases carry the real evidence; Phase 2 states the discriminating assertion for each case, and Phase 4's live run is framed as a no-wrongful-reap regression check, not as proof the reaper works |
| A sibling task commits into this shared working tree mid-phase | M | M | Per-dispatch territory note: re-read each file immediately before editing, stage only this task's own files by explicit path, never a directory or glob add |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict serial chain: Phase 2
tests the mode Phase 1 creates, Phase 3 edits the same test file Phase 2 edits (so they must not
run concurrently), and Phase 4 documents and deploys all of it.

---

### Phase 1: `--reap` mode in the writer [COMPLETED]

**Goal**: `setup-sapience-mcp.sh --reap` removes every `.projects[<path>].mcpServers.sapience`
whose `<path>` is not a directory on disk, touching nothing else, with `--dry-run` and `--quiet`
honored.

**Tasks**:

- [x] Add `REAP=false` alongside the existing `DRY_RUN`/`REMOVE`/`RETIRE_GLOBAL` flag block, and
      a `--reap` case to the argument parser. *(completed)*
- [x] Add a `process_reap()` function and dispatch it as a **standalone action short-circuit
      placed next to the existing `--retire-global` block — before the `PROJECT_PATH` default
      and before the top-level `resolve_interpreter`/`resolve_host`/`resolve_token` calls and the
      `log "Configuration:"` banner.** `--reap` needs no interpreter, and `resolve_interpreter`
      hard-`exit 1`s when none resolves; a later placement would make the hook's reap call fail
      on a machine with no resolvable `python3`. `--reap` ignores `--scope` and needs no
      `--project`. *(completed)*
- [x] Implement the body per the research report's mechanics: bail cleanly (`return 0`, `log`
      only) when `~/.claude.json` is absent; enumerate candidates with
      `jq -r '.projects | to_entries[] | select(.value.mcpServers.sapience != null) | .key'`;
      filter to `[ ! -d "$p" ]`; bail cleanly when the orphan set is empty; under `--dry-run`
      log each would-be reap and mutate nothing; otherwise `mktemp` + a single
      `reduce $paths[] as $p (.; del(.projects[$p].mcpServers.sapience))` + `mv`, matching the
      existing writer actions' mutation shape exactly. *(completed)*
- [x] Emit, per reaped path, a `log` line and — when `--quiet` — exactly one stdout line
      (`sapience: reaped orphaned entry for <path>`), mirroring `process_remove`'s
      `[ "$QUIET" = "true" ] && echo ...` convention so the hook can detect "something changed"
      by non-empty output exactly as it already does. *(completed)*
- [x] Guard the jq enumeration against an unparseable or `.projects`-less file (`2>/dev/null ||
      echo ""`), consistent with the file's existing defensive reads. *(completed)*
- [x] Add an inline comment recording the two deliberate decisions: an emptied `.mcpServers`
      becomes `{}` and is left that way (deleting the project row would discard unrelated
      session/history/cost metadata), and `[ -d ]` treats an inaccessible-but-existing directory
      as absent, accepted because the next session start in that repo re-registers it.
      *(completed)*
- [x] Extend the script's header `Options:` block and the numbered "The script will" list to
      document `--reap`, in the same voice as `--retire-global` (the header doubles as `--help`
      output via the `sed -n '2,/^$/p'` extraction, so the edit is user-visible). *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`
is the single suite `suite_selection_select` returns for this phase's only touched path, and the
edit adds a new standalone action without altering any existing code path's behavior.

**Scope Hypothesis**: this phase changes exactly one file, and asserts that the
`--retire-global` short-circuit at `setup-sapience-mcp.sh:122-144` sits before the top-level
`resolve_interpreter` call at line 207 (measured at planning time against the 390-line file).
Confirm by re-reading the file immediately before editing — a sibling task may have changed it —
and place the `--reap` short-circuit relative to the *constructs*, not those line numbers.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` - add `REAP` flag, `--reap`
  parser case, `process_reap()`, the standalone-action short-circuit, and the header/`--help`
  documentation for the new mode

**Verification**:

- `bash agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh --help` lists `--reap`
  and exits 0.
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` is
  green (the source-store suite resolves the writer relative to its own directory, so it exercises
  the just-edited copy with no deploy needed) — every pre-existing case, including the mutation
  check, still passes.
- An ad hoc fixture check against a throwaway `HOME` (an absent-path row plus a present-path row):
  `--dry-run --reap` mutates nothing, `--reap` removes only the absent row's `sapience` key.
- `bash -n` on the edited script.

---

### Phase 2: writer-level `--reap` test cases [COMPLETED]

**Goal**: the suite carries discriminating coverage for a registered-but-nonexistent project
path, including the sharpest shapes: a mixed-server orphan row and the explicit emptied-object
end state.

**Tasks**:

- [x] Append a new writer-level case block after the existing final case, following the file's
      established fixture idiom (a per-case `HOME`/project pair under `$WORKDIR`, `jq -n` fixture
      construction, `pass`/`fail` with the asserted values echoed on failure). *(completed:
      placed after the mutation-check block, before the Phase 3 hook cases, as cases 31-34 plus
      a discrimination check)*
- [x] Case: an orphan row (path never created on disk) carrying **both** `sapience` and
      `lean-lsp`. After `--reap`: `sapience` absent, `lean-lsp` present and byte-identical on the
      same row. This is the discriminating assertion for the "touch only the sapience key"
      constraint. *(completed: case 31)*
- [x] Case: a row whose path **does** exist survives `--reap` untouched (no false-positive reap
      of a live project), asserted in the same fixture as the orphan case so one `--reap`
      invocation proves both directions at once. *(completed: case 31, same fixture/invocation)*
- [x] Case: an orphan row whose only server is `sapience`. After `--reap`, assert
      `.mcpServers == {}` **explicitly** — not merely an absent `sapience` key, and not a deleted
      project row. This is the mechanical form of the "handled explicitly rather than abandoned"
      requirement. *(completed: case 32)*
- [x] Case: `--reap --dry-run` mutates nothing, asserted by `md5sum` before/after, mirroring
      existing case 4's pattern. *(completed: case 33)*
- [x] Case: an unrelated top-level key and an unrelated non-`sapience` project row both survive a
      reap byte-for-byte, mirroring existing case 8's key-preservation idiom. *(completed: case 34)*
- [x] Extend the file's header case-list comment with the new case numbers and one-line
      descriptions, in the existing numbered style. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh`
is the single suite `suite_selection_select` returns for this phase's only touched path, and the
edit is additive test content with no production surface.

**Scope Hypothesis**: this phase adds five new cases to one file, numbered sequentially after the
suite's current highest case (30, measured at planning time — the lockstep guard). Confirm the
current highest case number by re-reading the file's header comment and its final case block
immediately before editing, and number from whatever is actually there.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - append the
  `--reap` writer-level case block and extend the header case list

**Verification**:

- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0
  with the new cases reported `[PASS]` and the pre-existing count unchanged in the summary line.
- Discrimination check (run, not assumed): with `process_reap`'s `[ ! -d "$p" ]` filter inverted
  by hand in a throwaway copy of the writer, the new mixed-server and emptied-object cases FAIL —
  proving they depend on the real filter rather than passing vacuously. Revert the throwaway copy;
  do not commit it.
- `bash -n` on the edited suite.

---

### Phase 3: unconditional reap pass in the SessionStart hook [NOT STARTED]

**Goal**: the hook invokes `--reap` on every session start regardless of manifest reachability or
activation state, while preserving its always-exit-0 / exactly-one-JSON-line / never-fail-a-session
contract.

**Tasks**:

- [ ] Re-read `hooks/sapience-mcp-register-project.sh` in full, then restructure its control flow:
      move the `command -v jq` guard and the `WRITER` existence guard **above** the
      `.claude-extensions.json` reachability branch (both are preconditions of the reap pass), and
      leave the marker-delimited `sapience-worktree-checkout-resolution` block byte-identical —
      the suite's lockstep case asserts it matches four other copies exactly.
- [ ] Convert the reachability branch's `else` arm from `echo '{}'; exit 0` into a
      `HAVE_PROJECT=false` flag with `PROJECT_PATH=""`/`EXTENSIONS_FILE=""` initialized, so the
      per-repo half is skipped rather than exiting. Under `set -uo pipefail` every later
      reference to those variables must be guarded by the flag.
- [ ] Insert the reap invocation after both guards and before the per-repo half:
      `REAP_OUTPUT="$(bash "$WRITER" --reap --quiet 2>&1)"`, with its own `rc`, degrading silently
      on a nonzero exit or empty output exactly as the existing writer invocations do.
- [ ] Guard the per-repo register/remove half behind `$HAVE_PROJECT`, leaving its internal
      `IS_ACTIVE` / `HAS_EXISTING_ENTRY` logic otherwise unchanged — and remove its two interior
      `echo '{}'; exit 0` early returns in favor of "contribute no notice", so a reap notice is
      never swallowed by the per-repo half deciding it has nothing to say.
- [ ] Replace the single-`NOTICE` tail with notice assembly over an array: collect the reap
      notice (when reap produced output) and the per-repo notice (when the writer wrote
      something), then emit `{}` when the array is empty, or one
      `jq -cRs '{additionalContext: .}'` line built from `printf '%s\n' "${NOTICES[@]}"` when it
      is not — so either, both, or neither firing still yields exactly one JSON line. Keep the
      existing `|| echo '{}'` fallback on the `jq` call and the terminal `exit 0`.
- [ ] Update the hook's header comment block: the reap pass, why it is ungated (an orphan can
      never host the session that would clean it up), and that it runs before the reachability
      branch.
- [ ] Add a hook-level case: a fixture `HOME` whose `.claude.json` carries an orphan row, with the
      hook invoked from a directory that has **no reachable `.claude-extensions.json` at all** —
      exactly the path that previously exited early. Assert the orphan's `sapience` key is gone
      and the output is a single parseable JSON object carrying `additionalContext`.
- [ ] Add a hook-level case: an orphan row *and* an active current repo in the same fixture — one
      invocation reaps the orphan, registers the current repo, and still emits exactly one JSON
      line mentioning both actions.
- [ ] Re-run the pre-existing hook and worktree silence cases unchanged as the regression net
      (the already-correct session, inactive-with-no-entry, missing-writer, one-line-JSON, and
      the worktree cases including the exact-keys and lockstep assertions).

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: the restructuring changes the hook's externally observed stdout contract,
consumed both by the harness and by the suite's hook/worktree cases spanning two files, and
`bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` — the single
suite `suite_selection_select` returns for both touched paths — is the enumerated dependent that
covers it.

**Scope Hypothesis**: this phase asserts the hook is a 156-line file whose reachability branch
(lines 82-92), `jq` guard (94-98) and writer guard (106-114) sit in that order, and that the
suite's silence-asserting cases are 11, 13, 14, 15, 26 and 28 (all measured at planning time).
Confirm by re-reading both files immediately before editing; if a sibling has moved anything,
restructure relative to the constructs rather than those line numbers, and re-derive which cases
assert `{}` by grepping the suite for the `= '{}'` comparisons.

**Files to modify**:

- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` - hoist the `jq` and
  writer guards, add the ungated reap invocation, convert the reachability bail-out to a flag,
  replace the notice tail with array-based assembly, update the header contract comment
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - add the two
  hook-level reap cases and extend the header case list

**Verification**:

- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0:
  the new hook cases pass AND every pre-existing silence case still passes unchanged.
- Contract spot-check, run directly: invoke the hook from `/tmp` (no manifest reachable, fixture
  `HOME` with no orphans) and confirm stdout is exactly `{}`, one line, exit 0; repeat with `jq`
  masked off `PATH` and with the fixture writer removed, confirming `{}` and exit 0 in both.
- `printf '%s' "$OUT" | jq -e .` succeeds for every hook invocation exercised above (the
  one-parseable-line invariant).
- `bash -n` on both edited files.

---

### Phase 4: documentation, redeploy, and live verification [NOT STARTED]

**Goal**: the new mode is documented where a future reader will find it, the deployed tree and the
user-level installed copies carry the fix, and the full gate set plus the live verifier are green.

**Tasks**:

- [ ] Update the writer's row in the extension's README file inventory table so it names the
      cross-project reap alongside registers/repairs/removes, and the hook's row so it names the
      ungated reap pass.
- [ ] Add a paragraph to `per-repo-scoping.md`'s "The MCP-Registration Triad" subsection (in the
      writer and hook bullets, plus a short prose paragraph after the "One-session-start removal
      lag" note) describing the `--reap` mode, the "any living session can clean up any other
      repo's orphan" rationale, the sapience-key-only scope, the accepted emptied-`{}` end state,
      and the accepted `[ -d ]` inaccessible-directory edge case. Per research, there is no
      numbered risk list in this file to extend — add it as prose/`## Hazards` content, matching
      the existing unnumbered structure.
- [ ] Redeploy the source store with `bash .claude/scripts/deploy-headless.sh` so the deployed
      `.claude/` tree (including the deployed copy of the suite that `run-all.sh` discovers)
      carries the change.
- [ ] Refresh the user-level installed copies by re-running the idempotent installer
      (`bash agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh`),
      which re-copies the hook and writer to `$HOME/.claude/{hooks,scripts}/`. Without this the
      fix is source-only: the live `SessionStart` hook runs from the installed copy, not from the
      repo.
- [ ] Run `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` and confirm
      checks (a)-(d) still pass, with (e) still failing for the pre-existing, documented
      grant-count reason recorded in Premise Re-Validation item 5 — compare against that
      baseline rather than demanding exit 0.
- [ ] Capture live `~/.claude.json` evidence before and after the first post-install reap-bearing
      invocation: the set of `.projects` keys carrying `.mcpServers.sapience`, and the
      `lean-lsp`-only rows, must be identical (zero orphans exist today, so a correct reaper is a
      no-op here — this is the no-wrongful-reap regression check, not proof the reaper works,
      which Phases 2-3 own).

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the documentation surface is exactly two files — the
extension README's file inventory table and `per-repo-scoping.md`'s MCP-Registration Triad
subsection — and that `per-repo-scoping.md` carries no numbered risk list to extend (measured at
planning time; it has an unnumbered `## Hazards` section instead). Confirm by grepping both files
for `setup-sapience-mcp` and for a numbered risk enumeration before editing; if a third surface
names the writer's modes, update it in this phase and record the addition.

**Files to modify**:

- `agent-system/extensions/sapience/README.md` - writer and hook rows in the file inventory table
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - the
  MCP-Registration Triad subsection: `--reap`, its rationale, scope, and accepted edge cases
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:

- The complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`) is green, including Gate 8's shell-suite
  battery with the extended `test-sapience-mcp-registration.sh`.
- `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` is green
  against the **deployed** copy (post-deploy), confirming the deploy actually carried the edits.
- `verify-sapience-mcp.sh` (a)-(d) pass, matching the recorded baseline.
- `diff` of the before/after live `.projects` server-key census shows no change (no wrongful reap).
- `$HOME/.claude/hooks/sapience-mcp-register-project.sh` and
  `$HOME/.claude/scripts/setup-sapience-mcp.sh` are byte-identical to their source-store
  originals (`cmp`), proving the installer refresh landed.

---

## Testing & Validation

- [ ] `test-sapience-mcp-registration.sh` exits 0 from the source store (Phases 1-3) and from the
      deployed tree via `run-all.sh --only` (Phase 4).
- [ ] The new writer-level cases prove: `sapience` reaped from an orphan row; `lean-lsp` preserved
      on that same row; a live path untouched; `.mcpServers == {}` explicitly asserted;
      `--reap --dry-run` byte-for-byte inert; unrelated keys preserved.
- [ ] The new hook-level cases prove: an orphan is reaped from a session with no reachable
      `.claude-extensions.json` (the previously unreachable path); reap and per-repo registration
      in one invocation still emit exactly one JSON line.
- [ ] Every pre-existing silence case still passes unchanged: already-correct session,
      inactive-with-no-entry, missing writer, one-line-JSON, and the worktree cases including the
      exact-keys and byte-identical-lockstep assertions.
- [ ] Hook contract spot-checks: exit 0 and a single `{}` line with no manifest reachable, with
      `jq` absent, and with the writer absent.
- [ ] The discrimination check in Phase 2 (inverted `[ ! -d ]` filter) was actually run and the
      new cases observed to fail under it.
- [ ] `bash .claude/scripts/verify-deploy.sh` green; `verify-sapience-mcp.sh` (a)-(d) pass.
- [ ] Live `~/.claude.json` server-key census unchanged across the change.

## Artifacts & Outputs

- `--reap` mode on `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`.
- Restructured, reap-invoking `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`.
- Extended `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`.
- Updated `agent-system/extensions/sapience/README.md` and
  `context/project/sapience/domain/per-repo-scoping.md`.
- A regenerated `.claude/` deploy tree and refreshed `$HOME/.claude/{hooks,scripts}/` copies.
- An implementation summary under `specs/627_reap_orphan_sapience_mcp_registrations/summaries/`.

## Rollback/Contingency

- Each phase commits separately per the commit-per-green-substep mandate, so any single phase is
  revertable in isolation via its own commit.
- The riskiest change is Phase 3's hook restructuring. If it misbehaves live, the cheapest
  containment is to revert that one commit and re-run
  `install-sapience-mcp-session-hook.sh`, which re-copies the reverted hook over the installed
  copy; the writer's `--reap` mode is then simply never invoked and is inert.
- `install-sapience-mcp-session-hook.sh --remove` removes the installed hook and writer entirely,
  restoring pre-task session behavior without touching the repository.
- `~/.claude.json` is outside the repository and is not covered by git. Before Phase 4's live
  installer run and first reap-bearing invocation, copy it aside
  (`cp ~/.claude.json ~/.claude.json.bak-627`) so a wrongful reap is restorable; remove the copy
  once Phase 4's census diff is confirmed empty.
- Before any intentional rollback that a guard would otherwise block, take a snapshot first
  (`bash .claude/scripts/git-snapshot.sh 627`). For an ordinary defensive checkpoint mid-phase,
  use `--no-revert`.
