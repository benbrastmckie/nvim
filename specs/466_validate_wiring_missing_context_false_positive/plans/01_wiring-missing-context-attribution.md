# Implementation Plan: Task #466

- **Task**: 466 - validate-wiring.sh reports a context file missing when it exists
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: None (Stage 1.5 assessment: root-caused mechanically within this dispatch — see Overview)
- **Artifacts**: plans/01_wiring-missing-context-attribution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The 41 `Missing context file` failures were reproduced exactly, and the diagnosis in the task
description is wrong in an important way: **this is not a path-resolution defect, and none of the
41 are false positives in the resolution sense.** Every one of the 41 belongs to the `.opencode`
arm of a `--all` run, where the file genuinely does not exist. The validator's verdict about the
filesystem is correct; what is wrong is that its failure line prints only the index-relative path
with no indication of which deployed tree it was resolved against, so a reader spot-checks
`.claude/context/...`, finds the file, and concludes the validator is broken. The validator
trained a reader to dismiss it by being unattributable, not by being inaccurate.

Two defects therefore need fixing, and neither is the one originally hypothesized: (1) the
unattributed failure message in `validate_context_files`, and (2) a genuine, long-standing data
inconsistency in the committed `.opencode/context/index.json`, which carries 41 entries whose
backing files were never mirrored into that tree.

### Evidence (reproduction, this dispatch)

| Probe | Result |
|-------|--------|
| `validate-wiring.sh --claude` | 0 missing-context failures, `VALIDATION PASSED` |
| `validate-wiring.sh --opencode` | 41 missing-context failures |
| `validate-wiring.sh --all` | the same 41, `Failed: 41` |
| `.claude/context/project/memory/learn-usage.md` (and the other two spot-checks) | EXISTS |
| `.opencode/context/project/memory/learn-usage.md` (and the other two spot-checks) | MISSING |
| index entry counts | `.claude` 311, `.opencode` 150 (the two indexes differ) |
| `.opencode` index entries under `project/{memory,neovim,nix}/` | 41 total, 0 resolve on disk |
| entries outside those three subtrees that fail to resolve | none |
| `.opencode-extensions.json` | does not exist — memory/nix/nvim are not loaded for that tree |
| `deploy-headless.sh` references to `.opencode` | none; the tree is a committed, git-tracked frozen mirror nothing regenerates |
| other readers of `.opencode/context/index.json` | none in `agent-system/**` or `.claude/scripts/**` |
| other producers/consumers of the literal string `Missing context file` | exactly one producer (line 144), zero consumers |

The relevant code is `validate_context_files` in
`agent-system/extensions/core/scripts/validate-wiring.sh:131-155`; the failure line is line 144,
`log_fail "Missing context file: $path"`, which drops both `$system_dir` and the computed
`$full_path` from the message it emits.

### Decision: prune the dangling entries rather than mirror the files

The 41 entries describe context for the memory, nix and nvim extensions, routed to agents
(`nix-research-agent`, etc.) that the `.opencode` mirror does not carry, for extensions that tree
has no manifest for. Mirroring 41 context files into a frozen tree to satisfy entries for
extensions that are not loaded there would expand that tree's footprint to make a stale index
look correct. Pruning the entries makes the committed index agree with the committed tree, which
is the condition the check is actually asserting. A third option — teaching the validator to
downgrade an entry for an unloaded extension to `WARN` — is excluded by the task's non-goal
against lowering severity.

### Research Integration

No research report was dispatched for this round. The Stage 1.5 assessment resolved the question
with targeted `Read`/`Grep`/script-invocation probes inside this dispatch (table above): the
fault, its mechanism, and its blast radius are all mechanically established, so a research round
would have had nothing left to determine.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Every `Missing context file` failure names the deployed tree it was resolved against and the
  full path it looked for, so the verdict is auditable against disk without guessing.
- Per-tree missing/total counts are reported distinctly, so a genuine shortfall in one tree is
  never read as a verdict about the other.
- `.opencode/context/index.json` stops claiming 41 files the `.opencode` tree does not contain.
- `validate-wiring.sh --all` returns to green on this repository for the right reason (the index
  agrees with the tree), with the check still failing loudly on a genuinely absent file.
- The regression suite covers both directions: a present file produces no failure, and an absent
  file produces a failure attributed to its tree.

**Non-Goals**:
- Do not suppress, soften, or `WARN`-downgrade the missing-context check.
- Do not add a per-extension or per-path exemption list to the validator.
- Do not mirror extension context files into `.opencode/`, and do not revive `.opencode` as a
  deploy target.
- Do not touch the `.claude` arm's behavior, which is already correct.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A downstream consumer greps the literal `Missing context file: ` prefix and breaks on the new shape | M | L | Verified this dispatch: one producer, zero consumers across `agent-system/**` and `.claude/docs/**`. Re-run that grep at Phase 1 before editing, since a sibling may have added one. |
| Pruning the wrong entries silently shrinks the `.opencode` index | M | L | Prune by the exact predicate (path prefix `project/memory/`, `project/neovim/`, `project/nix/`), then assert the post-state: 109 entries remain, all resolve on disk, `jq` parses the file. |
| The `.opencode` prune is read as "making the validator quiet" | M | M | The commit and the Phase 3 verification record that the pruned entries were dangling in the tree being validated, with the 0-of-41-resolve measurement, not merely that the count went to zero. |
| A sibling task edits the same source-store scripts this cycle | M | L | Five siblings are dispatched this cycle; none declares `validate-wiring.sh`, its test suite, or `.opencode/**`. Re-read each file immediately before editing and stage only this task's own hunks. |
| Editing the deployed `.claude/scripts/validate-wiring.sh` instead of the source store | H | L | All script edits land under `agent-system/extensions/core/`; Phase 4 redeploys. `.opencode/**` is git-tracked and hand-maintained, so it is edited in place — it is not a deploy artifact and the source-store boundary rule does not reach it. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Attribute every missing-context failure to its deployed tree [COMPLETED]

**Goal**: `validate_context_files` emits failures a reader can check against disk without
inferring which tree was scanned, and reports per-tree missing/total counts distinctly.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-wiring.sh` and re-run
      `grep -rn "Missing context file" --include="*.sh" --include="*.md" --include="*.json" agent-system/ .claude/docs`
      to confirm the message still has no consumer. *(completed: re-grep reconfirmed exactly one
      producer, zero consumers)*
- [x] In `validate_context_files`, derive a tree label from the function's existing
      `$system_dir` argument (`system_label="$(basename "$system_dir")"`, yielding `.claude` or
      `.opencode`) — no new parameter, no call-site change. *(completed)*
- [x] Change the failure line to carry both the label and the resolved path, e.g.
      `log_fail "Missing context file [$system_label]: $path (expected at $full_path)"`. *(completed)*
- [x] Count total entries scanned alongside `missing`, and emit one `log_info` line per tree
      reporting `$missing of $total context index entries missing on disk`, so the two trees'
      shortfalls are reported as separate facts rather than one aggregate verdict. *(completed)*
- [x] Label the success line too (`log_pass "[$system_label] all $total context index entries resolve on disk"`),
      so a passing run states which tree passed. *(completed)*
- [x] Leave the `return 0`/`return 1` contract, the `jq` extraction, and every other function
      untouched. *(completed: verified only one call site of validate_context_files, signature
      and return contract unchanged)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
is the single suite `suite_selection_select` maps this path to, and the edit is confined to log
lines inside one function of one file with no signature or exit-code change.

**Scope Hypothesis**: exactly one `log_fail` call site (line 144) and one `log_pass` call site
(line 150) need changing, and no call site of `validate_context_files` needs changing; the
implementer confirms by grepping the function body for `log_` calls and the file for
`validate_context_files` invocations before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-wiring.sh` - tree-labelled missing-context
  failure line, full resolved path in the message, per-tree missing/total info line, labelled
  success line

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
  passes (the existing five cases are unaffected by the message change).
- A direct run from the source-store repo root shows every missing-context failure naming
  `.opencode` and its full path: `bash .claude/scripts/validate-wiring.sh --all 2>&1 | grep "Missing context file" | head -3`
  (run after Phase 4's redeploy for the deployed copy; before that, invoke the test harness's
  fixture copy, since `deploy-root-guard.sh` requires the running script's parent-of-parent to be
  literally `.claude` or `.opencode`).
- `bash -n agent-system/extensions/core/scripts/validate-wiring.sh` is clean.

---

### Phase 2: Add a both-directions fixture to the regression suite [NOT STARTED]

**Goal**: the suite proves the acceptance criterion in both directions — an index entry whose
file exists yields no failure, and an index entry whose file is absent yields a failure
attributed to the tree that lacks it.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh`, reusing its
      existing `build_fixture` / `run_wiring` / `common_test_pass` harness rather than adding a
      second fixture model.
- [ ] Add a case (f): in a `.claude`-only fixture, write `context/index.json` with two entries —
      one whose file is created on disk, one whose file is deliberately absent — and assert the
      run reports exactly one `Missing context file` line, that the line names the absent entry's
      path, that it names `.claude`, and that it does NOT name the present entry.
- [ ] Add a case (g): the attribution case. Build the `opencode-only` fixture (the suite's
      existing case-(d) transformation), give its index one present and one absent entry, and
      assert the failure line names `.opencode` — proving a reader can tell which tree failed.
- [ ] Assert the per-tree count line from Phase 1 appears with the expected `1 of 2` shape.
- [ ] Extend the file's header comment to state what cases (f) and (g) cover, matching the
      existing per-case comment style.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
is the same single covering suite, and the edit adds cases to that suite file alone with no
change to any script under test.

**Scope Hypothesis**: the existing `build_fixture` helper suffices for both new cases with no
change to it or to `run_wiring`; the implementer confirms by constructing case (f) first and only
then deciding whether case (g) needs a helper tweak.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` - cases (f) and (g),
  header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
  reports all seven cases passing, exit 0.
- Negative control: temporarily revert Phase 1's label from the message and confirm case (g)
  FAILS, proving the new case actually tests attribution rather than passing vacuously. Restore
  the label afterwards and re-run to green.

---

### Phase 3: Prune the dangling entries from the .opencode context index [NOT STARTED]

**Goal**: `.opencode/context/index.json` stops listing 41 context files that tree does not
contain, so the check's genuine finding is resolved at its source rather than silenced.

**Tasks**:
- [ ] Re-read `.opencode/context/index.json` immediately before editing (git-tracked,
      hand-maintained, concurrent siblings active).
- [ ] Re-measure the predicate before acting: confirm 41 entries match path prefix
      `project/memory/`, `project/neovim/`, or `project/nix/`, that 0 of them resolve under
      `.opencode/context/`, and that no entry outside those three prefixes fails to resolve.
- [ ] Remove exactly those entries, preserving the file's single top-level `entries` key, its key
      ordering within each surviving entry, and its formatting conventions.
- [ ] Confirm the post-state: `jq` parses the file, 109 entries remain, and every remaining
      entry's `path` resolves to a file under `.opencode/context/`.
- [ ] Record in the phase's progress note that the pruned entries were dangling (0 of 41
      resolving) and that `.opencode` carries no extensions manifest for memory/nix/nvim, so the
      prune resolves a real inconsistency rather than quieting a check.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
plus a direct `validate-wiring.sh --opencode` run covers this edit completely, because the file
is a data file with exactly one reader — verified this dispatch that nothing else in
`agent-system/**` or `.claude/scripts/**` reads `.opencode/context/index.json`.

**Scope Hypothesis**: exactly 41 entries are dangling and all of them lie under the three named
prefixes, leaving 109 that all resolve; the implementer confirms by re-running the
resolve-every-entry loop both before and after the edit and comparing the counts, rather than
trusting these numbers.

**Files to modify**:
- `.opencode/context/index.json` - remove the 41 entries under `project/memory/`,
  `project/neovim/`, `project/nix/` whose files are absent from that tree

**Verification**:
- `jq '.entries | length' .opencode/context/index.json` returns 109.
- A resolve-every-entry loop over `.opencode/context/index.json` reports zero unresolved paths.
- `bash .claude/scripts/validate-wiring.sh --opencode` reports zero `Missing context file`
  failures (the deployed copy is unchanged by this phase, so this probe is valid before the
  Phase 4 redeploy).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
  still passes.

---

### Phase 4: Redeploy and verify the full gate set [NOT STARTED]

**Goal**: the source-store changes reach the deployed tree, and the repository's complete gate
set is green with `validate-wiring.sh --all` passing for the right reason.

**Tasks**:
- [ ] Redeploy via `bash agent-system/extensions/core/scripts/deploy-headless.sh` so
      `.claude/scripts/validate-wiring.sh` and `.claude/scripts/tests/test-validate-wiring.sh`
      match the source store.
- [ ] Confirm the deployed copies are byte-identical to their source-store counterparts.
- [ ] Run `bash .claude/scripts/validate-wiring.sh --all` and confirm zero
      `Missing context file` failures and `VALIDATION PASSED`.
- [ ] Prove the check still fails loudly end-to-end: temporarily move one real
      `.claude/context/**` file listed in `.claude/context/index.json` aside, re-run `--claude`,
      confirm a failure line naming `.claude` and the full path, restore the file, re-run to
      green.
- [ ] Run the complete gate set and confirm green.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/` tree
- `.claude/scripts/validate-wiring.sh` - regenerated from source store (deploy output, not a
  hand edit)
- `.claude/scripts/tests/test-validate-wiring.sh` - regenerated from source store (deploy output,
  not a hand edit)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, green.
- `bash .claude/scripts/validate-wiring.sh --all` exits 0 with `VALIDATION PASSED` and zero
  `Missing context file` lines.
- The move-aside/restore probe above produced a `.claude`-attributed failure with a full path,
  then returned to green.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-wiring.sh`
      passes with the two new cases included.
- [ ] Case (g) was shown to fail against an unlabelled message and pass against the labelled one
      (negative control, Phase 2).
- [ ] `bash .claude/scripts/validate-wiring.sh --all` exits 0; `--claude` and `--opencode` each
      report zero missing-context failures.
- [ ] Every entry in both `.claude/context/index.json` (311) and
      `.opencode/context/index.json` (109) resolves to a file on disk.
- [ ] A genuinely absent context file still produces a loud, tree-attributed failure and a
      non-zero exit (Phase 4 move-aside probe).
- [ ] `bash .claude/scripts/verify-deploy.sh` is green.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-wiring.sh` — tree-attributed missing-context
  reporting with per-tree counts
- `agent-system/extensions/core/scripts/tests/test-validate-wiring.sh` — cases (f) and (g)
  covering both directions
- `.opencode/context/index.json` — 41 dangling entries removed, 109 all-resolving entries remain
- Regenerated `.claude/` deploy tree

## Rollback/Contingency

Each phase is a small, independently revertible change, and the three source-of-truth files are
all git-tracked, so `git revert` of the per-phase commits restores the prior state; a redeploy
afterwards restores the deployed copies. If the `.opencode` prune proves wrong — for instance if
a reason surfaces to revive `.opencode` as a deploy target carrying extension context — Phase 3
reverts on its own without disturbing Phases 1, 2 and 4, since the validator fix and its fixtures
do not depend on the prune. If Phase 1's message change turns out to break an unanticipated
consumer, the label can be moved into a trailing parenthetical while keeping the original
`Missing context file: $path` prefix intact, preserving attribution without changing the prefix.

## Territory Note

Five sibling tasks are dispatched this cycle. None declares
`agent-system/extensions/core/scripts/validate-wiring.sh`,
`agent-system/extensions/core/scripts/tests/test-validate-wiring.sh`, or `.opencode/**`, so no
scope overlap exists and no dependency edge is required. The backlog note's conditional edge was
checked: the record declaring `scripts/tests/test-validate-wiring.sh` is `completed`, so there is
no open task to serialize against even though Phase 2 edits that file. Phase 4's
whole-tree regeneration is declared with the `__WHOLE_TREE__` sentinel so it serializes against
any other whole-tree-claim task.
