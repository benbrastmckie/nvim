# Implementation Plan: Task #624

- **Task**: 624 - Make system-defect-record.sh able to attribute a dispatched-agent defect from a deploy-consumer repository
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None (both declared dependencies are closed and, per the research report, settled adjacent questions)
- **Research Inputs**: specs/624_defect_record_unresolvable_in_deploy_consumer/reports/01_signal-b-deploy-consumer-resolution.md
- **Artifacts**: plans/01_signal-b-deploy-consumer-resolution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`system-defect-record.sh`'s `--dispatched-agent` (Signal B) resolution globs
`$PROJECT_ROOT/agent-system/extensions/*/agents/NAME.md`, a subtree that exists only in the one
repository physically holding the source store; in any deploy consumer the glob cannot match and
the recorder refuses with exit 3, losing the defect to a non-fatal log line. This plan adds a
second resolution route through `.claude-extensions.json`'s per-extension `source_dir` — the same
indirection `rules/source-store-deploy-boundary.md` already prescribes for edit targets and
`deploy-root-guard.sh`'s self-correct path already trusts — while emitting the byte-identical
source-store-relative `resolved_path` string the existing glob produces, so the recursion guard,
the `defect_key` dedup identity, and the persisted `attributed_source_path` field are unchanged.
Done when the deployed recorder resolves a dispatched-agent name from a consumer-shaped tree, a
new fixture suite pins both that route and the unchanged glob route, and the full gate set is
green.

### Research Integration

Adopted wholesale from the research report: candidate direction 1 (`.claude-extensions.json` →
`source_dir`) is the fix; directions 2 (bare agent name) and 3 (deployed `.claude/agents/` path)
are rejected because each introduces a second, differently-shaped identity string and forks the
`defect_key`/recursion-guard key space per repository for what is conceptually one agent file.
The report's hard constraint — the resolved-path output shape must not change — is carried into
this plan as a verification criterion, not merely a note. The report's secondary
test-coverage recommendation is promoted to a required phase here (Phase 2), because the absence
of any `test-system-defect-record*.sh` suite is precisely why this failure mode reached a live
orchestration run unnoticed.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class claim in this dispatch's `## Description` was re-checked live during this
planning dispatch:

- **"glob at `system-defect-record.sh` around line 233"** — CONFIRMED exactly, not merely
  approximately: the glob
  `agent_matches=("$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md")`
  is at line 233 of `agent-system/extensions/core/scripts/system-defect-record.sh` (358 lines
  total); the `--dispatched-agent` branch opens at line 231 and the exit-3 acceptance `case`
  closes at line 246.
- **"exits 3 with that message from a consumer repo"** — CONFIRMED by live re-run this dispatch.
  Invoking `/home/benjamin/Projects/cslib/.claude/scripts/system-defect-record.sh
  --defect-class RECOVERY_DECLINED --dispatched-agent general-research-agent` produced
  `REFUSING: Signal B attribution unresolvable (attributed-path=''
  dispatched-agent='general-research-agent' did not resolve to a path under
  agent-system/extensions/**). Log only, no record.`; `/home/benjamin/Projects/cslib` has no
  `agent-system` directory at all (`ls` fails), confirming the structural, not incidental, cause.
- **"Observed in the wild twice in one orchestration run"** — NOT independently verifiable from
  durable stores, and that is itself consistent with the defect rather than evidence against it:
  a refused recording writes nothing, so no `events.jsonl`/`issues.jsonl`/`central-errors.jsonl`
  row exists to count. Searched this dispatch and found no durable trace. Treated as a
  non-load-bearing motivating observation; nothing in this plan's design depends on the figure
  being 2.
- **Repo-conditionality cross-check (new datum, supports the premise)** — this repository, which
  DOES hold the source store, carries 5 `RECOVERY_DECLINED` rows in `specs/events.jsonl`. The
  same detector therefore records successfully here and refuses in a consumer, exactly the
  repository-conditional behavior the description asserts.
- **"258 and 426 settled adjacent questions"** — accepted as re-confirmed by the research report's
  own Context & Scope check; not re-derived here.

## Goals & Non-Goals

**Goals**:
- `--dispatched-agent NAME` resolves from any repository whose `.claude-extensions.json` records
  a reachable `source_dir`, including a consumer with no `agent-system/` subtree.
- The emitted `resolved_path` is byte-identical to what the existing glob produces for the same
  agent in the source-store-holding repository (`agent-system/extensions/<ext>/agents/NAME.md`).
- The existing glob route keeps working unchanged, including in a fixture whose root has a
  literal `agent-system/extensions/...` layout and no `.claude-extensions.json`.
- Exit 3 and its message survive unchanged for the genuinely unresolvable case (unknown agent
  name, or every `source_dir` unreachable on this machine).
- A dedicated regression suite pins all four behaviors; the suite is declared where the corpus
  requires declaration (manifest `provides.scripts`, `suite-classification.data`).

**Non-Goals**:
- `transform_deploy_to_source()` / the `--attributed-path` branch is NOT touched. The research
  report flags a latent misattribution risk there (every bare `.claude/X` maps to
  `extensions/core/X`, which would be wrong for the flat-merged `.claude/agents/` directory); no
  current call site passes such a path, and it is a different defect class (silent wrong
  attribution, not refusal). Out of scope, worth a separate record.
- No change to the recursion guard, the dedup rule, the detail payload, the defect-class enum, or
  any call site's non-fatal invocation convention.
- No "never refuse" fallback that records under a bare agent name — `system-defect-discrimination.md`
  prefers refusal-with-logging to an unattributed record, so the residual unresolvable case keeps
  exiting 3.
- `context/standards/shell-script-testing.md`'s stale prose figures ("151 suites today",
  "148 hinted rows"; 157 suites are discovered today) are NOT corrected here: the figures are
  unpinned prose that no script asserts, they were already stale before this task, and that file
  sits inside concurrent sibling 604's declared `file_scope`.
- `tests/suite-cost-hints.txt`, `tests/known-failures.txt`, and `tests/run-all.sh` are NOT
  touched. Suite discovery is by glob (`run-all.sh` scans `scripts/tests/test-*.sh`), so a new
  suite needs no registration there, and all three files sit inside concurrent sibling 586's
  declared `file_scope`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A recorded `source_dir` points at a moved/deleted checkout | M | M | Require `[ -d "$source_dir" ]` before use; a failing entry falls through to the next extension, then to the glob, then to exit 3 — never a crash |
| `set -euo pipefail` aborts the recorder on a jq failure over a malformed `.claude-extensions.json` | H | L | Every added jq call is written with an explicit `|| true` / `|| continue` fallback; a malformed manifest degrades to the pre-existing glob-then-refuse behavior |
| Two extensions ship an agent of the same bare name, making first-match-wins order-dependent | L | L | Pre-existing property of the current glob (`agent_matches[0]` wins); the fix preserves rather than introduces it. Documented in the script header, not silently relied on |
| New suite escapes the corpus's declaration requirements (manifest Rule Q, classification lint) | M | H if unmanaged | Phase 2 runs `sync-manifest-scripts.sh --write` and adds a `suite-classification.data` row in the same phase, and declares both files in its own `Files to modify` |
| Fixture suite cannot exercise the recorder from the source store (`deploy-root-guard.sh` refuses there) | M | H if unmanaged | Suite builds a `<workdir>/.claude/scripts`-shaped fixture and copies the subject plus its four sibling dependencies into it — the idiom `tests/test-deploy-root-guard.sh` already uses |
| A sibling task commits into the shared tree mid-phase | M | M | Per the dispatch Territory block: re-read before edit, stage explicit file lists only, never `git-snapshot.sh` in reverting mode, report any foreign commit rather than absorbing it |

## Decisions

- **Glob first, manifest second.** The `.claude-extensions.json` lookup is appended as a fallback
  *after* the existing glob rather than replacing or preceding it. The research report judged
  order immaterial for correctness (both routes yield the identical string whenever both match);
  glob-first is chosen because it leaves the source-store-holding repository's hot path and every
  existing `agent-system/`-shaped fixture bit-for-bit unchanged, and reaches the new jq work only
  on the path that currently refuses.
- **Resolution proven via the recursion-guard echo, not via an event write.** Phase 2's
  path-shape assertion feeds the fixture a `orchestrator-critical-paths.json` that marks the
  expected resolved path `recursion_guard: true`; the recorder then exits 0 printing
  `SUPPRESSED:recursion_guard` with the resolved path quoted verbatim in its stderr. This pins
  the exact resolved string without copying `events-append.sh`/`events-query.sh` and their
  transitive dependencies into the fixture, and without writing an event row anywhere.
- **No live recording call into another repository.** The original reproduction ran from
  `/home/benjamin/Projects/cslib`. A post-fix success there would append a junk `system_defect`
  row to that repository's own `specs/events.jsonl`. Phase 4 therefore attests the consumer case
  against a scratch consumer-shaped tree plus a read-only (`jq` + `test -f`) replay of the
  resolution steps against cslib's real `.claude-extensions.json`, never a recording invocation
  in a repository this task does not own.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the `.claude-extensions.json` resolution route [COMPLETED]

**Goal**: `--dispatched-agent NAME` resolves in a deploy consumer, emitting the unchanged
source-store-relative path shape, with exit 3 preserved for the genuinely unresolvable case.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/system-defect-record.sh` immediately before
      editing (concurrent siblings are live on this tree). *(completed)*
- [x] Add a helper beside `transform_deploy_to_source()` (e.g.
      `resolve_agent_via_extensions_manifest()`) that: returns empty unless
      `$PROJECT_ROOT/.claude-extensions.json` exists; enumerates
      `.extensions | to_entries[] | [.key, .value.source_dir]` with jq under an explicit
      failure fallback so `set -euo pipefail` cannot abort the recorder on a malformed manifest;
      for each entry with a non-empty `source_dir` that is an existing directory, tests
      `"$source_dir/agents/${NAME}.md"`; and on first match echoes exactly
      `agent-system/extensions/<key>/agents/<NAME>.md` — the source-store-relative string, never
      the absolute `source_dir`-based path. *(completed)*
- [x] In the `--dispatched-agent` branch (line 231 onward), call that helper only when the
      existing glob did not resolve, leaving the glob and its `agent_matches[0]` semantics
      untouched. *(completed)*
- [x] Leave the acceptance `case "$resolved_path" in agent-system/extensions/*)` gate, the exit-3
      message text, and the exit code unchanged. *(completed: verified by diff — these lines are
      untouched)*
- [x] Update this script's own header prose (the `--dispatched-agent` description around lines
      26-28) so "resolved mechanically ... by globbing the source store" also names the
      `.claude-extensions.json` `source_dir` route and the first-match-wins ordering. *(completed)*
- [x] Commit this phase's single file with an explicit pathspec. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase is hypothesized to touch exactly one file
(`system-defect-record.sh`) and to need no change outside its `--dispatched-agent` branch plus
its own header comment. Confirm at implementation time by re-reading lines 209-250 and
verifying the acceptance gate, the exit-3 message, and the `resolved_path` consumers below it
(recursion guard, `defect_key`, detail payload) are textually unmodified in the final diff.

**Tier Justification**: `suite_selection_select` over this phase's one path returns exactly
`test-handoff-dispatch-identity.sh`, `test-manifest-scripts-sync.sh`,
`test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-postflight.sh`,
`test-orchestrate-recover-message-findings.sh`, `test-validate-handoff-location.sh`, so the
covering check is `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-handoff-dispatch-identity.sh,test-manifest-scripts-sync.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-validate-handoff-location.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/system-defect-record.sh` - add the extensions-manifest
  source-store fallback inside the dispatched-agent branch, and update the header's resolver
  description

**Verification**:
- The covering suite list named in Tier Justification runs green.
- `bash -c '. agent-system/extensions/core/scripts/lib/common.sh'`-style syntax soundness:
  `bash -n agent-system/extensions/core/scripts/system-defect-record.sh` exits 0.
- `git diff` confirms no hunk falls outside the `--dispatched-agent` branch, the new helper, and
  the header comment.

---

### Phase 2: Regression suite for Signal B resolution [NOT STARTED]

**Goal**: a dedicated fixture suite pins consumer-route resolution, the exact resolved-path
string, the unchanged glob route, and the preserved exit-3 refusal — and is declared everywhere
the corpus requires.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-system-defect-record-signal-b.sh`,
      modelled structurally on `tests/test-deploy-root-guard.sh`: `common_test_repo_root`,
      `common_test_resolve_subject "system-defect-record.sh" "source-store" ...`,
      `common_test_declare_subject`, `common_test_workdir_init`, `common_test_pass`/`_fail`,
      exit 0/1/2 convention.
- [ ] Build each case's fixture as `<workdir>/<case>/.claude/scripts/` (so
      `common_repo_root "$SCRIPT_DIR" 2` resolves `PROJECT_ROOT` to `<workdir>/<case>` by pure
      path arithmetic, no git root needed) holding the resolved subject plus its four sibling
      dependencies — `deploy-root-guard.sh`, `lib/common.sh`, `lib/file-scope-overlap.sh` — and,
      where the case needs it, `<case>/.claude/context/reference/orchestrator-critical-paths.json`.
- [ ] Case (a) consumer route resolves: fixture root has a `.claude-extensions.json` whose
      `.extensions.core.source_dir` points at a throwaway `<case>/fake-store/core` containing
      `agents/fixture-probe-agent.md`, and NO `agent-system/` subtree. Fixture critical-paths
      file marks `agent-system/extensions/core/agents/fixture-probe-agent.md` as
      `recursion_guard: true`; assert exit 0, stdout `SUPPRESSED:recursion_guard`, and stderr
      quoting that exact path — pinning both resolution and the path shape.
- [ ] Case (b) non-core extension discrimination: same shape with the `source_dir` under a second
      extension key (e.g. `lean`), asserting the resolved path names that key, not `core`.
- [ ] Case (c) glob route unchanged: fixture root has a literal
      `<case>/agent-system/extensions/core/agents/fixture-probe-agent.md` and NO
      `.claude-extensions.json`; assert the identical resolved path, proving no regression.
- [ ] Case (d) refusal preserved: `.claude-extensions.json` present but `core.source_dir` points
      at a nonexistent directory, and no agents file anywhere; assert exit 3 and the unchanged
      `Signal B attribution unresolvable` message.
- [ ] Add one `suite-classification.data` row for the new suite (`unit` — the cases are
      self-contained fixtures spawning no nested orchestration), satisfying
      `lint/lint-unit-integration-boundary.sh`'s coverage-gap rule that an unclassified
      discovered suite is itself a violation.
- [ ] Run `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --write` to insert
      the new suite into `agent-system/extensions/core/manifest.json`'s `provides.scripts`, then
      `--check` to confirm clean; this is the generated surface `check-extension-docs.sh`'s
      Rule Q (gate 3) blocks on.
- [ ] Commit with an explicit three-file pathspec.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase is hypothesized to need exactly three files (the new suite,
`suite-classification.data`, `manifest.json`) and no edit to `run-all.sh`,
`suite-cost-hints.txt`, or `known-failures.txt`. The basis is that `run-all.sh` discovers suites
by globbing `scripts/tests/test-*.sh` and the hint/known-failure files are documented
advisory-only. Confirm at implementation time by running `run-all.sh` and checking the new suite
appears in the discovered set with no registration edit, and that
`sync-manifest-scripts.sh --check` reports clean after the `--write`.

**Tier Justification**: `suite_selection_select` over this phase's three paths returns the
`__FULL_SWEEP__` sentinel (the newly created file is unmappable until it exists), so no covering
suite is claimed; the honest covering checks are
`bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` for the generated
manifest surface and
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
for the Rule Q and task-reference surfaces, alongside the direct run recorded in this phase's
Verification criteria below.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-system-defect-record-signal-b.sh` - new
  fixture suite, cases (a)-(d)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one `unit` row for the
  new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` entry for the new suite,
  inserted by `sync-manifest-scripts.sh --write` (coupled generated surface, regenerated in this
  same phase because gate 3's Rule Q blocks on it)

**Verification**:
- The new suite exits 0 with all four cases passing when run directly.
- Case (a) and case (c) assert the *same* resolved-path string — the research report's hard
  constraint, pinned mechanically rather than by inspection.
- `sync-manifest-scripts.sh --check` exits 0.
- `verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` reports no new
  findings (note: a `--skip-slow`/`--only-gate` pass is never read as evidence that doc-sync pins
  hold — Phase 4 carries that).

---

### Phase 3: Sync the discrimination document's resolver prose [NOT STARTED]

**Goal**: the governing pattern document no longer describes the resolver as glob-only, so a
future caller reading it is not re-taught the defect.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
      around the "An agent-name → agent-file resolver for this already exists" paragraph
      (currently lines 254-258) immediately before editing.
- [ ] Rewrite that paragraph's mechanism sentence to name both routes — the
      `agent-system/extensions/*/agents/NAME.md` glob and the `.claude-extensions.json`
      `source_dir` lookup that serves a repository holding no source store — while keeping the
      exit-3-on-unresolvable and `--attributed-path`-wins-when-both-passed statements intact.
- [ ] State the current design only; do not narrate that the document previously said something
      else (`rules/no-record-versioning-in-deliverables.md`).
- [ ] Reference durable anchors (file and section names) rather than task numbers
      (`rules/no-task-references-in-deliverables.md`).
- [ ] Commit with an explicit single-file pathspec.

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase is hypothesized to touch exactly one paragraph in one file; the
basis is a grep for `glob` across every document that mentions `system-defect-record`
(`system-defect-discrimination.md`, `docs/architecture/orchestrate-cycle-postflight.md`,
`docs/reference/utility-scripts-inventory.md`, `context/patterns/regeneration-is-manual-only.md`,
`docs/architecture/orchestrate-state-machine.md`, `docs/architecture/handoff-schema.md`), which
hit the resolver mechanism only in `system-defect-discrimination.md`. Confirm at implementation
time by re-running that grep and checking no other document asserts glob-only resolution.

**Tier Justification**: `suite_selection_select` over this phase's one path returns the
`__FULL_SWEEP__` sentinel — a source-store, non-`specs/**` markdown file maps to no suite — so
the covering checks are the `prose` row's diff read-through plus
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(the repository root, which is simultaneously deploy consumer and source store, so neither gate
silently SKIPs).

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - resolver
  paragraph names both resolution routes

**Verification**:
- Diff read-through confirms every changed hunk is prose inside the resolver paragraph.
- `verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim` reports no new
  doc-lint or task-reference findings.
- The paragraph's description matches the shipped code: no claim of a route the script does not
  implement, and no omission of one it does.

---

### Phase 4: Deploy, attest end-to-end, and run the full gate set [NOT STARTED]

**Goal**: the *deployed* recorder — the copy every call site actually invokes — carries the fix,
resolves from a consumer-shaped tree, and the whole repository is green.

**Tasks**:
- [ ] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed `.claude/**` tree
      from the source store (this is a whole-tree regeneration; see the `__WHOLE_TREE__`
      declaration below).
- [ ] Confirm the deployed copy carries the fix: the new helper and the
      `.claude-extensions.json` reference are present in
      `.claude/scripts/system-defect-record.sh`, and the deployed
      `.claude/scripts/tests/test-system-defect-record-signal-b.sh` exists.
- [ ] Build a scratch consumer-shaped tree under the session scratchpad (a `.claude/` copied from
      the freshly deployed tree, a `.claude-extensions.json` whose `core.source_dir` points at
      this repository's real `agent-system/extensions/core`, no `agent-system/` subtree of its
      own, and an empty `specs/`), invoke its `.claude/scripts/system-defect-record.sh
      --defect-class RECOVERY_DECLINED --dispatched-agent general-research-agent`, and assert it
      no longer exits 3 — the end-to-end inverse of the reproduction recorded in this plan's
      Premise Re-Validation.
- [ ] Replay the resolution read-only against the original consumer repository without recording
      into it: `jq -r '.extensions.core.source_dir'
      /home/benjamin/Projects/cslib/.claude-extensions.json` followed by `test -f
      <that>/agents/general-research-agent.md`, confirming the exact lookup the fix performs
      succeeds there.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`, no
      `--only-gate`), and resolve any finding it reports.
- [ ] Record any issue or win encountered across all four phases via `issue-record.sh`, per the
      dispatch's Issue Log contract.

**Timing**: 0.75 hours

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that `deploy-headless.sh` is the only tree-wide write it
performs and that it introduces no new source-store edit of its own. Confirm at implementation
time with `git status --short` after the deploy: changes outside this task's declared
`file_scope` plus the regenerated `.claude/**` tree indicate either a gate repair to fold in
explicitly or a concurrent sibling's in-flight edit to report rather than absorb.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed
  tree; declared with the reserved sentinel so batch admission serializes this task against any
  other whole-tree-regenerating task rather than treating the scopes as disjoint. The deployed
  recorder and the deployed suite are regenerated artifacts covered by this sentinel, never
  hand-authored and never named as scope members in their own right

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with no findings — the complete gate set,
  including gate 3 doc-lint, gate 4 task-reference lint, gate 5 manifest/content-hash parity, and
  gate 8's full shell-suite battery, which now discovers and runs the new suite in both
  source-store and deployed mode.
- The scratch consumer invocation does not exit 3, and its emitted
  `detail.attributed_source_path` equals `agent-system/extensions/core/agents/general-research-agent.md`.
- The read-only cslib replay confirms the `source_dir` lookup resolves there.
- `git status --short` shows no unexplained modification outside this task's territory.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-system-defect-record-signal-b.sh`
      exits 0 with cases (a)-(d) all passing.
- [ ] Cases (a) and (c) assert an identical resolved-path string, mechanically pinning the
      research report's hard constraint that the output shape is unchanged across routes.
- [ ] Case (d) asserts the exit-3 message is unchanged for the genuinely unresolvable case.
- [ ] `bash agent-system/extensions/core/scripts/sync-manifest-scripts.sh --check` exits 0.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 with no findings.
- [ ] The scratch consumer-shaped invocation of the deployed recorder resolves rather than
      refusing.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/system-defect-record.sh` - `--dispatched-agent` branch
  gains the `.claude-extensions.json` → `source_dir` resolution route
- `agent-system/extensions/core/scripts/tests/test-system-defect-record-signal-b.sh` - new
  four-case regression suite (first dedicated coverage for this resolver)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row for
  the new suite
- `agent-system/extensions/core/manifest.json` - `provides.scripts` declaration for the new suite
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - resolver
  paragraph names both routes
- Regenerated deployed `.claude/**` tree (deploy artifact, not hand-authored)
- `specs/624_defect_record_unresolvable_in_deploy_consumer/summaries/01_*-summary.md` at
  completion

## Rollback/Contingency

Each phase commits exactly its own explicit file list, so reverting is a per-phase `git revert`
of that phase's commit — no snapshot needed and no working-tree discard involved. The fix is
purely additive (a fallback reached only on the path that currently refuses), so a partial
landing leaves the recorder behaving exactly as it does today rather than in a novel state: if
Phase 1 lands and later phases do not, the source-store repository is unaffected and consumers
gain resolution without the regression suite.

If a rollback must instead discard uncommitted work in the tree, that is a snapshot-then-rollback
procedure, not a bare precaution: follow `context/contracts/recovery.md`'s rollback rung for the
exact invocation shape, including its out-of-scope override flag, before running any destructive
git command. Never emit a reverting `git-snapshot.sh` as a routine start-of-phase checkpoint —
concurrent siblings are live on this tree this cycle, and a reverting snapshot would discard
their in-flight work.
