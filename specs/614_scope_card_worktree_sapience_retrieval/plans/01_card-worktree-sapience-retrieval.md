# Implementation Plan: Task #614

- **Task**: 614 - Resolve a SF-1 card worktree to its parent checkout so card sessions get repo-scoped Sapience retrieval without hook-injected context
- **Status**: [NOT STARTED]
- **Effort**: 7 hours
- **Dependencies**: None blocking (shares the sapience extension surface with tasks 615, 616, 617 -- see Risks)
- **Research Inputs**: specs/614_scope_card_worktree_sapience_retrieval/reports/01_card-worktree-sapience-retrieval.md
- **Artifacts**: plans/01_card-worktree-sapience-retrieval.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A SF-1 hub-runner card worktree currently resolves to no Sapience registration at all: the
SessionStart registration hook derives its project root from `git rev-parse --show-toplevel`,
which inside a linked worktree returns the throwaway worktree directory rather than the parent
checkout, so activation detection finds no `.claude-extensions.json` and nothing is registered.
This plan teaches the registration path (and the verifier's lockstep copy, and the three
`[repo:<slug>]` provenance sites) to resolve a linked worktree to its parent checkout, keyed on
the checkout path only; it adds regression coverage for the four worktree cases the dispatch
enumerates; and it records in the extension's own domain notes why the hook/permission-grant
channel must stay absent from a worktree. Definition of done: a worktree of a loaded checkout
resolves to the checkout's registration and the checkout's slug, a worktree of an unloaded
checkout registers nothing and retracts an existing entry, no worktree-keyed `~/.claude.json`
entry is ever created, the regression suite covers all four cases and passes, and the full gate
set is green.

### Research Integration

Three findings from the research report reshape the scope the dispatch anticipated:

1. **Claude Code's own `~/.claude.json` per-project lookup already resolves a linked worktree
   (at any nesting depth) to its checkout's `.projects[<checkout>]` entry** -- measured against
   fabricated `HOME` fixtures with key-order, unrelated-second-repo, no-entry, and non-git
   controls. Consequence: registration keys on the **checkout path only**. No worktree-keyed
   entry is ever written, which closes the dispatch's open question 2 (unbounded dead-entry
   accumulation) **by construction** -- there is nothing worktree-specific to retract, so no
   teardown mechanism is built. This is why no phase below adds one.
2. **`setup-sapience-mcp.sh` needs no change.** Its `--project PATH` contract is already
   path-opaque and calls `git` nowhere; handing it a checkout path is already within contract.
   It is correspondingly absent from every phase's file list below.
3. **The checkout path is not in the card session's environment.** `runner.py`'s `child_env()`
   passes only `SF1_HUB_CARD_DIR`; the checkout is known to the runner process as `cfg["repo"]`
   but is not propagated. The git derivation is therefore necessary, not a cheaper alternative
   foregone (dispatch open question 3, answered: no).

The detection test is the one the research measured correct at the checkout root, the worktree
root, a nested worktree subdirectory, and a non-git path: compare `git rev-parse --git-dir`
against `git rev-parse --git-common-dir`; equal (including both-failed on a non-git path) means
"not a linked worktree, behave exactly as today"; unequal means "linked worktree -- the common
dir's parent directory is the checkout". The same technique is already in production on this
machine in the SF-1 runner's own `guard_bound()`.

### Premise Re-Validation

The dispatch description's hard claim -- "[the response] carries no per-item attribution a local
wrapper could filter or label by, so this channel cannot be scoped from this side at all" --
was checked against both the prior artifact and live state and is **unchanged**:
`context/project/sapience/domain/injection-site-scoping.md` records it as Foreclosure 2 ("No
per-item attribution exists to label by, even if a filter did exist"), and the research report's
Channel-1 section confirms the structural claim without weakening it. Nothing in this plan
relaxes it; Phase 5 records it as the reason the hook channel stays deliberately absent from a
worktree.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Resolve a linked git worktree to its parent checkout in the registration hook and the
  verifier's lockstep detection copy, deciding activation and the registration key from the
  checkout.
- Keep the `[repo:<slug>]` provenance slug identical whether derived from a worktree or from its
  checkout, on both the read side (`sapience-retrieve.sh`) and the write side
  (`sapience-remember.sh`), so a worktree query and a checkout query address the same objects.
- Preserve the bidirectional register/remove contract across the worktree case.
- Add a verifier check and four regression cases covering the worktree scenarios.
- Record the two-channel asymmetry (MCP retrieval wanted, hook injection deliberately absent) in
  the extension's own domain notes.

**Non-Goals**:
- No change to `setup-sapience-mcp.sh` (already path-opaque -- research finding 2).
- No worktree-keyed `~/.claude.json` entry, and therefore no teardown/retraction mechanism for
  one (research finding 1).
- No edit to `~/.local/state/sf1-hub-ben/hub/runner/bin/runner.py` or anything else outside this
  repository's filesystem -- vendor/nix-packaged, out of scope under
  `rules/source-store-deploy-boundary.md`'s task-siting rule.
- No attempt to make `sapience_search` reachable from inside the runner's own automated card-exec
  subprocess, which passes `--strict-mcp-config --mcp-config '{"mcpServers": {}}'` and refuses
  every MCP server before `~/.claude.json` is consulted. This gap is named and recorded, not
  closed.
- No extension of the merge engine, hooks, or permission grants into a worktree -- the hazard
  this task deliberately preserves.
- No change to `settings-fragment.json`'s grant set (concurrently owned by task 615).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future reader "fixes" the missing hooks/grants in a worktree, reopening the unscoped cross-repo injection hazard | H | M | Phase 5's `per-repo-scoping.md` section states the asymmetry and the reason explicitly, as a prohibition rather than a known gap |
| The `--strict-mcp-config` caveat is silently dropped and acceptance criterion 1 is declared met against a session shape the runner never uses | H | M | Phase 6 names the exact session shape criterion 1 is verified under, and Phase 5 records the caveat in the domain notes |
| The resolution block drifts between its copies (the hook must stay self-contained; see Decisions) | M | M | Phase 4 adds a mechanical lockstep case comparing the marker-delimited block across every copy, replacing today's prose-only "keep in lockstep" comment |
| A degraded/partial install (old installed hook, new source hook) breaks a session | H | L | The block is inlined, adding no new file the installer must copy; the hook's always-exit-0, always-one-line-JSON contract is unchanged and re-asserted by regression case 15 |
| `--git-dir`/`--git-common-dir` behaves unexpectedly under an unmeasured topology (bare repo, submodule boundary) | M | L | Inequality is the only trigger; any shape it does not recognize as a worktree degrades to today's `--show-toplevel` behavior, i.e. "unchanged", not "broken". Phase 4 case (d) pins the no-op fallback |
| Source-store edits without redeploy fail verify-deploy gate 5 (content-hash equality) | M | H | Phase 6 schedules the whole-tree regeneration and declares the `__WHOLE_TREE__` claim |
| Concurrent sapience-extension tasks (615, 616, 617) touch adjacent files | M | M | This plan touches no file those tasks own (`settings-fragment.json`, grant retraction); Phase 6's full gate run is the reconciliation point |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 1, 2, 3 |
| 4 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Worktree-aware checkout resolution in the registration hook [NOT STARTED]

**Goal**: The SessionStart registration hook resolves a linked worktree to its parent checkout
and decides activation, the extensions-file location, and the `--project` key from that
checkout.

**Tasks**:
- [ ] Verify the measured truth table against a live scratch fixture before writing code: create
      a disposable `git init` checkout plus `git worktree add --detach`, and confirm
      `git rev-parse --git-dir` vs `--git-common-dir` differ at the worktree root and at a nested
      worktree subdirectory, are equal at the checkout root, and both fail on a non-git path.
      Note which form `--git-common-dir` returns (relative at the checkout root, absolute from a
      worktree) -- the implementation must absolutize before comparing or taking the parent.
- [ ] Add a marker-delimited `resolve_checkout_toplevel` helper to
      `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`, inlined (not
      sourced -- see Decisions), bracketed by a begin/end marker comment pair naming the lockstep
      obligation. Contract: given a directory (default `.`), echo the parent checkout's toplevel
      for a linked worktree, the `--show-toplevel` result otherwise, and return non-zero with no
      output on a non-git path.
- [ ] Replace the existing `GIT_ROOT="$(git rev-parse --show-toplevel ...)"` line (currently at
      line 48) with a call to the helper, leaving every downstream branch -- the
      `.claude-extensions.json` CWD/git-root lookup, `PROJECT_PATH`, the writer invocation, the
      `HAS_EXISTING_ENTRY` probe, and the removal branch -- structurally unchanged.
- [ ] Update the hook's header comment block to state that the git root is the parent checkout
      for a linked worktree, and that registration is keyed on the checkout exclusively.
- [ ] Confirm by inspection that the `.claude-extensions.json`-at-CWD branch still wins over the
      git-root branch, so a worktree that genuinely carries its own extensions file is unaffected.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` is the suite `suite_selection_select` returns for this phase's only script path, and it already exercises the hook's six registration paths (cases 10-15).

**Scope Hypothesis**: exactly one `git rev-parse --show-toplevel` call site exists in this file
(line 48 as of authoring); the implementer confirms with
`grep -n "show-toplevel" agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh`
before editing and reports any additional site rather than silently editing only the first.

**Files to modify**:
- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` - add the
  marker-delimited checkout-resolution helper; derive `GIT_ROOT` from it; update the header

**Verification**:
- `bash -n` and `shellcheck` clean on the edited hook.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` passes (pre-existing cases 10-15 unchanged).
- Manual fixture exercise: from a worktree of a loaded checkout fixture (fabricated `HOME`,
  never the real `~/.claude.json`), the hook registers under the **checkout's** key and writes no
  worktree-keyed entry.

---

### Phase 2: Lockstep copy in the verifier, plus a worktree check [NOT STARTED]

**Goal**: `verify-sapience-mcp.sh` resolves a worktree the same way the hook does, and reports a
new named check asserting that a worktree carries none of the extension's hooks or permission
grants.

**Tasks**:
- [ ] Copy the Phase 1 marker-delimited helper byte-for-byte into
      `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` and derive `GIT_ROOT`
      (currently line 98) from it, preserving the file's existing "kept in lockstep with
      sapience-mcp-register-project.sh's own copy" comment and extending it to name the markers.
- [ ] Add check **(f)**: when the detected project root was resolved from a linked worktree,
      assert that the worktree itself carries no `.claude/settings.local.json` with any
      `mcp__sapience__*` permission grant and none of the five Sapience hook keys. Report it by
      name like the existing checks; when the CWD is not a worktree, log a skip line rather than
      passing vacuously.
- [ ] Extend the script's header `Checks (each reported by name)` block with (f), and state in
      the usage/comment text that the detected project path is the parent checkout for a worktree.
- [ ] Leave checks (a)-(e) untouched -- in particular check (e)'s grant count, which task 615
      owns.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` is the suite `suite_selection_select` returns for this phase's only script path, and it carries the verifier cases (20-24).

**Scope Hypothesis**: the verifier's detection block is a single copy at lines 96-106 and
checks are lettered (a)-(e) today, so the new check is (f); the implementer confirms both with
`grep -n "show-toplevel\|^# Check (" agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`
before editing.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - lockstep helper copy;
  worktree-derived `GIT_ROOT`; new check (f); header update

**Verification**:
- `bash -n` and `shellcheck` clean.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` passes.
- Run the verifier from the repository root: checks (a)-(e) report exactly as before, and (f)
  logs its not-a-worktree skip line.
- Run the verifier from a worktree fixture of a loaded checkout: the expected project path it
  prints is the **checkout's**, and (f) passes.

---

### Phase 3: Slug consistency across the three `[repo:<slug>]` provenance sites [NOT STARTED]

**Goal**: The repo slug a worktree derives is identical to the slug its checkout derives, on the
read side, the write side, and the scoping probe -- so a worktree-originated write and a
worktree-originated query address the same `[repo:<slug>]` objects the checkout does.

**Tasks**:
- [ ] Copy the Phase 1 marker-delimited helper byte-for-byte into
      `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` and derive `repo_toplevel`
      (currently line 101) from it before `basename`, preserving every existing empty-value guard
      and exit code.
- [ ] Apply the identical change to `agent-system/extensions/sapience/scripts/sapience-remember.sh`
      (currently line 121). This is the write side: an untreated worktree would tag an object
      `[repo:<throwaway-worktree-name>]`, which neither the checkout's nor the worktree's query
      can ever retrieve. Acceptance criterion 1 ("receives only knowledge objects carrying the
      checkout's `[repo:<slug>]` provenance tag") cannot hold if the two sides disagree, which is
      why the write side is in scope here even though the research named only the read side.
- [ ] Apply the identical change to
      `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` (currently
      line 101, with its line 103 bare-`git` fallback), whose header states it mirrors
      `sapience-remember.sh`'s resolution -- the mirror must stay true.
- [ ] Update the three sites' slug-derivation comments to say "basename of the parent checkout's
      git toplevel" rather than "basename of the git toplevel".

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel over this phase's combined paths -- no single suite covers the set, because the scoping probe maps to none -- so the covering checks are `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 22 /home/benjamin/.config/nvim` (shellcheck lint) plus the fixture comparison below confirming the read and write sides derive one identical slug.

**Scope Hypothesis**: exactly three slug-derivation sites exist in this extension outside the
test tree (retrieve, remember, context-scoping); the implementer re-runs
`grep -rn "rev-parse --show-toplevel" agent-system/extensions/sapience/ --include=*.sh` after
Phases 1-2 land and confirms only these three remain untreated, reporting any fourth rather than
leaving it.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` - resolve the checkout toplevel before taking its basename as the slug
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` - same resolution, so the write tag matches the read filter
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` - same resolution, keeping its documented mirror of the write-side script true

**Verification**:
- `bash -n` and `shellcheck` clean on all three.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-capture.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-context-growth.sh` passes.
- Fixture comparison: in a scratch checkout named `fixture-repo` with a worktree named
  `C-3-20261113120000`, each script's derived slug is `fixture-repo` from both locations
  (instrument via the script's own dry/echo path or a sourced extraction of the helper -- do not
  issue a live `POST`/`GET` against the vault from a fixture).

---

### Phase 4: Regression coverage for the worktree cases [NOT STARTED]

**Goal**: `test-sapience-mcp-registration.sh` covers the four worktree scenarios the dispatch
enumerates, plus a mechanical guard that the resolution block has not drifted between its copies.

**Tasks**:
- [ ] Add a worktree fixture builder alongside the existing `git init -q` repo fixtures: a
      checkout with `.claude-extensions.json`, plus `git worktree add --detach` of it. Guard the
      whole block on `git worktree` being usable, degrading to an `info` skip line in the suite's
      existing idiom rather than a failure.
- [ ] Case (a): a worktree of a **loaded** checkout registers an entry keyed on the **checkout's**
      path, with no entry keyed on the worktree path, and emits an `additionalContext` notice.
- [ ] Case (b): a worktree of an **unloaded** checkout registers nothing and is silent (`{}`).
- [ ] Case (c): an existing checkout-keyed entry is **retracted** when the checkout's
      `.claude-extensions.json` flips to inactive, exercised from inside the worktree -- the
      bidirectional contract surviving the worktree path.
- [ ] Case (d): a worktree-shaped path that is not a git worktree (and a plain non-git directory)
      is a silent, error-free no-op.
- [ ] Case (e): after cases (a)-(d), assert the fixture `~/.claude.json` carries **exactly** the
      checkout key and **no** worktree-derived key -- the mechanical form of acceptance
      criterion 4.
- [ ] Case (f): lockstep guard -- extract the marker-delimited block from every copy (the hook,
      the verifier, and the three Phase 3 scripts) and assert all are byte-identical; fail naming
      the divergent file. This replaces the prose-only "keep in lockstep" comment with a check.
- [ ] Extend the suite's header case inventory with the new case numbers and one-line
      descriptions, matching the existing numbered-comment convention.

**Timing**: 1.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` is the suite `suite_selection_select` returns for this phase's only path, and it is the edited file itself.

**Scope Hypothesis**: the suite currently ends at case 24 with a Class B counter-idiom harness and
a single `mktemp -d` workdir, so the new cases append as 25+; the implementer confirms the
highest existing case number with `grep -n "^# Case\|Case 2[0-9]" ` on the file before numbering.

**Files to modify**:
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - worktree
  fixture builder and the six new cases; header inventory update

**Verification**:
- `bash -n` and `shellcheck` clean.
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0
  with every new case PASS and no pre-existing case regressed.
- Discriminative check (the suite's existing mutation-check idiom): temporarily revert the hook's
  helper call to the bare `--show-toplevel` form in a scratch copy and confirm cases (a), (c) and
  (e) FAIL against it -- proving the new cases depend on the fix rather than passing vacuously.
  Restore the scratch copy afterwards; do not commit it.

---

### Phase 5: Record the two-channel asymmetry in the domain notes [NOT STARTED]

**Goal**: `per-repo-scoping.md` states why MCP retrieval is deliberately made to reach a worktree
while the hook/permission-grant channel is deliberately left absent, so a future reader does not
"fix" the missing hooks and reopen the unscoped-injection hazard.

**Tasks**:
- [ ] Add a `## Worktree Resolution and the Two-Channel Asymmetry` section to
      `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`,
      placed after `## The MCP-Registration Triad` and before `## Hazards`.
- [ ] State Channel 2 (MCP retrieval): registration keys on the parent checkout; Claude Code's
      own `~/.claude.json` per-project lookup resolves a worktree to that checkout entry, so no
      worktree-keyed entry is created and none needs retracting at teardown.
- [ ] State Channel 1 (hook-injected context): absent from a worktree by construction (hooks and
      grants reach a repo only through `settings-fragment.json` merged into that repo's own
      `.claude/settings.local.json`, and a fresh worktree has no `.claude/` tree), and
      deliberately kept absent -- cross-reference `injection-site-scoping.md`'s Foreclosure 2,
      which establishes that the response carries no per-item attribution a local wrapper could
      filter or label by, so this channel cannot be scoped from this side at all. Phrase it as a
      prohibition on extending the merge engine into worktrees, not as a known gap awaiting a fix.
- [ ] Record the `--strict-mcp-config` caveat: the SF-1 runner's own automated card-exec
      subprocess passes `--strict-mcp-config` with an empty `--mcp-config` and therefore sees zero
      MCP servers regardless of registration; the fix is necessary and sufficient for every other
      session shape in that worktree, and the automated subprocess's own gap is vendor-owned,
      out-of-repo, and deliberately not closed.
- [ ] Reconcile the coupled generated surface: run
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` (or the
      equivalent `--check` first) so this file's `line_count` entry in
      `agent-system/extensions/sapience/index-entries.json` (240 at authoring time) matches the
      edited file.
- [ ] Carry no task-number references and no record-versioning language in either file (both lie
      outside `specs/**`).

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel over this phase's combined paths (the domain note maps to no suite), so the covering check is `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` per the source-store markdown sub-case, together with the index reconciliation check named below.

**Scope Hypothesis**: `per-repo-scoping.md` exists with a `## The MCP-Registration Triad` section
and a `## Hazards` section, and its `index-entries.json` row declares `line_count: 240` matching
the file's current length -- all confirmed at authoring time. If the insertion point has moved by
the time this phase runs, the implementer places the section before `## Hazards` and reports the
divergence rather than creating a second triad section.

**Files to modify**:
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - new
  two-channel-asymmetry section with the `--strict-mcp-config` caveat
- `agent-system/extensions/sapience/index-entries.json` - the coupled `line_count` this edit
  moves, regenerated in this same phase

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes (doc-lint and task-reference lint).
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` reports no
  drift for the sapience extension.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-index-entries-schema.sh` passes.
- Read-through confirming the section names the prohibition and the caveat explicitly, not as
  open questions.

---

### Phase 6: Live acceptance verification, regeneration, and the full gate set [NOT STARTED]

**Goal**: Every acceptance criterion is verified against live state rather than inferred, the
deployed tree is reconciled with the source store, and the complete gate set is green.

**Tasks**:
- [ ] Install the updated hook and writer to their stable user-level paths by running
      `bash agent-system/extensions/sapience/scripts/install-sapience-mcp-session-hook.sh` from
      the source store (the installer resolves both sources relative to its own location, so this
      installs the edited hook without any deploy).
- [ ] Criterion 1: from a real linked worktree of this loaded checkout, start a session whose
      invocation does **not** pass `--strict-mcp-config` with an empty `--mcp-config`, call
      `sapience_search`, and confirm every returned object carries this checkout's
      `[repo:<slug>]` provenance tag; confirm a second repository's tagged object is absent.
      Record the exact session shape used, and record that the runner's own automated card-exec
      subprocess is excluded by its own flags (out of scope, see Phase 5's caveat).
- [ ] Criterion 2: in that same worktree session, inspect the **live merged settings** for the
      session (not the worktree's directory listing) and confirm no Sapience hook fires and no
      `mcp__sapience__*` permission grant is present. Run `verify-sapience-mcp.sh` from the
      worktree and confirm its check (f) reports this.
- [ ] Criterion 3: confirm against a worktree of an unloaded checkout that nothing registers, and
      that an existing entry is retracted once its checkout unloads (fixture-level is sufficient;
      Phase 4's cases are the durable form).
- [ ] Criterion 4: tear down the worktree and confirm `~/.claude.json` carries no entry keyed on
      the worktree path -- by construction none was ever written, so this is a confirmation, not
      a cleanup.
- [ ] Criterion 5: `bash -n` and `shellcheck` clean on every edited script, and the full
      regression suite passes.
- [ ] Regenerate the deployed tree so gate 5's content-hash equality holds for this task's
      source-store edits.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Criterion 7: confirm no task-number reference and no record-versioning language landed in
      any file outside `specs/**` (gate 4 covers the task-reference half; read the domain-note
      diff for the versioning half).

**Timing**: 1.5 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Scope Hypothesis**: this phase's `__WHOLE_TREE__` entry reflects an expected redeploy driven by
gate 5's source-store/deployed content-hash comparison; the implementer confirms the need by
running the gate set first and regenerating only if gate 5 reports drift attributable to this
task's edits, reporting the outcome either way.

**Files to modify**:
- `__WHOLE_TREE__` - whole-tree regeneration of the deployed `.claude/` tree so gate 5's
  content-hash equality holds for this task's source-store edits

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` -- the complete gate set, all gates green (no
  `--skip-slow`, no `--only-gate` narrowing; a narrowed pass does not discharge this phase).
- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` exits 0.
- `bash agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` exits 0 from the
  repository root, and from a worktree reports the checkout as the expected project path with
  check (f) passing.
- Each of acceptance criteria 1-7 recorded with the evidence that establishes it, naming the
  session shape used for criterion 1.

---

## Testing & Validation

- [ ] `bash -n` clean on all five edited shell scripts and the test suite.
- [ ] `shellcheck` clean on all five edited shell scripts and the test suite.
- [ ] `test-sapience-mcp-registration.sh` exits 0, with the four worktree cases, the
      no-dead-entry case, and the lockstep case passing.
- [ ] The discriminative check in Phase 4 confirms the new cases fail against the pre-fix hook.
- [ ] `verify-sapience-mcp.sh` exits 0 from the repository root and from a worktree, reporting
      check (f).
- [ ] `generate-context-line-counts.sh --check` reports no drift.
- [ ] `verify-deploy.sh` (complete gate set) passes.
- [ ] Live acceptance criteria 1-4 verified from a real worktree session, with the session shape
      recorded.

## Artifacts & Outputs

- `agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` (worktree-aware)
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` (lockstep + check (f))
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` (checkout-keyed slug)
- `agent-system/extensions/sapience/scripts/sapience-remember.sh` (checkout-keyed slug)
- `agent-system/extensions/sapience/scripts/verify-sapience-context-scoping.sh` (checkout-keyed slug)
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` (six new cases)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` (two-channel asymmetry)
- `agent-system/extensions/sapience/index-entries.json` (reconciled `line_count`)
- `specs/614_scope_card_worktree_sapience_retrieval/summaries/01_card-worktree-sapience-retrieval-summary.md`

## Decisions

- **The resolution block is inlined at each site, not sourced from a shared library.** The
  registration hook is installed to `~/.claude/hooks/` and must run correctly in a repository
  with no `.claude/` deploy at all; a sourced library would become a third file the installer
  must copy, and a partially-updated install (old installer, new hook) would break a session the
  hook's contract promises never to fail. Inlining keeps the hook self-contained at the cost of
  five copies, and Phase 4's lockstep case converts that cost into a mechanically checked
  invariant rather than a prose promise.
- **The write side (`sapience-remember.sh`) is in scope even though the research named only the
  read side.** A worktree-originated write tagged with the throwaway worktree name is invisible
  to every subsequent query, from the checkout and the worktree alike, which would defeat
  acceptance criterion 1's "only knowledge objects carrying the checkout's `[repo:<slug>]`
  provenance tag" in the other direction.
- **No teardown/retraction mechanism for worktree entries is built**, because none is ever
  written (research finding 1). The dispatch anticipated this mechanism might be needed; the
  measurement eliminated the need rather than deferring it.

## Rollback/Contingency

All phases are additive edits to seven files plus a regenerated index entry, each committed per
green sub-step, so the ordinary recovery is to revert the specific commit for the failing phase.

If a genuine rollback of uncommitted work becomes necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact `git-snapshot.sh` invocation shape
(including its out-of-scope override flag) before running any destructive git command -- never a
bare precautionary `git-snapshot.sh` as a routine start-of-phase checkpoint. For an ordinary
defensive checkpoint before the Phase 6 regeneration, use the `--no-revert` form instead.

Behavioral contingency: every change is gated on worktree detection returning "linked worktree".
Any topology the `--git-dir`/`--git-common-dir` comparison does not recognize falls through to
today's `--show-toplevel` behavior, so the worst case for an unanticipated repository shape is
the current (pre-fix) behavior, not a new failure.
