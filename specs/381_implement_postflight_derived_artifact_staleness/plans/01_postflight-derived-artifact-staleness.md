# Implementation Plan: Task #381

- **Task**: 381 - Catch stale derived artifacts at implement postflight and never let containment leave HEAD inconsistent
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/381_implement_postflight_derived_artifact_staleness/reports/01_postflight-derived-artifact-staleness.md
- **Artifacts**: plans/01_postflight-derived-artifact-staleness.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a repository-extensible, build-free derived-artifact staleness mechanism to the agent
system's two implement-postflight engines, with zero hard-coded knowledge of any consumer
repo's components. A consumer repo declares a new top-level `derived_artifact_probes` key in
`.claude-extensions.json`; postflight then (a) runs each declared build-free `check_command`
before the status write and refuses to report `implemented` on a non-zero result, and (b) stops
treating a regenerated file under a declared derived-output directory as a file_scope excursion,
so it is committed with the change that caused it instead of being silently dropped. Done when
both engines carry the mechanism, a repo that declares nothing is byte-for-byte unaffected, the
evidence-shaped fixture ends red or fully committed, and the declaration point is documented.

### Research Integration

Findings integrated from `reports/01_postflight-derived-artifact-staleness.md`:

- **Ordering is the central obstacle** (Finding 1). In `orchestrate-cycle-postflight.sh` the
  status write (WORK (f), line ~1125) lands *hundreds of lines before* this cycle's own commit
  (WORK (i), line ~1755). The probe gate therefore must sit **before** WORK (f), and is
  evaluated against the working tree, not against a commit that does not yet exist. The literal
  phrase "after the agent's last commit" in the task description resolves, in this architecture,
  to "after the agent's edits are known, before postflight's own commit and status write."
- **The two GOAL halves are complementary, not redundant** (Finding 3). The derived-output
  exemption fixes only the half where the gate *did* run and the output *was* reported; only an
  independent declared probe catches the half where a component's gate never ran at all.
- **`.claude-extensions.json` is the declaration point** (Finding 4). Its Lua read/write path
  (`lua/neotex/plugins/ai/shared/extensions/state.lua`) round-trips the whole top-level table,
  so a hand-authored sibling key survives every load/unload/redeploy cycle. Re-verified at
  planning time: `jq keys` returns exactly `["extensions","version"]`, and `source_dir` is a
  per-extension absolute path. `project-overview.md` (free-form prose) and a per-task
  `state.json` field (task-scoped, not repo-scoped) were both rejected.
- **Extension lifecycle hooks are ruled out** (Finding 5): wrong scope (per-extension, not
  per-repo) and wrong disposition (unconditionally non-blocking, with no opt-in blocking mode).
  Core task types never reach `skill-base.sh` at all.
- **This is the first blocking staleness gate in the codebase** (Finding 7) — the file_scope
  excursion advisory, the extension lifecycle hooks, and `lean-challenge-snapshot.sh --check`
  are all deliberately advisory-only. Phase 5 states that departure and its justification
  explicitly so a future maintainer does not read the new gate as contradicting those
  deliberate prior decisions.
- **`postflight-tool-restrictions.md` currently forbids this command class** (Finding 6); it
  gains one narrowly-scoped Exceptions entry modeled on the existing D4 entry.
- **Test convention** (Finding 10): the existing `test-orchestrate-cycle-postflight.sh` sandbox
  pattern (`setup_sandbox`, `write_state`, `run_sut`, real collaborator scripts copied into a
  synthetic `$WORKDIR/.claude/scripts/` tree) is reused rather than a new harness. Verified at
  planning time: `run-all.sh` discovers suites by glob, so new test files need no registration
  in the runner itself — but `manifest.json`'s `provides.scripts` enumerates individual script
  paths (including `lib/` and `tests/`), so new scripts DO need an entry there.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- A documented, repo-level declaration point (`.claude-extensions.json`'s new top-level
  `derived_artifact_probes` key) for build-free staleness check commands and their derived-output
  directories.
- A blocking probe at implement postflight in **both** engines
  (`orchestrate-cycle-postflight.sh` and `command-gate-out.sh`): a non-zero declared
  `check_command` prevents the `implemented`/`completed` status write and resolves the cycle as
  `defer`, never `ok`.
- A derived-output exemption ahead of the file_scope excursion check, so a regenerated file
  under a declared derived-output prefix is staged with the change that caused it rather than
  dropped — HEAD never left internally inconsistent.
- Absolute genericity: no component name, script name, or repo path from any consumer repo
  appears anywhere in `agent-system/**`.
- Strict fail-open on absence: a repo declaring nothing (this repo included) takes
  byte-for-byte the same code path as today.

**Non-Goals**:

- No linkage model mapping a component's *source inputs* to the component it belongs to. Phase 3
  decides (see Decisions below) that every declared probe runs on every implement-phase
  postflight; probes are build-free by declaration, so probe selection buys nothing and would
  require exactly the cross-referencing the exemption half was found not to need.
- No change to the existing file_scope excursion *advisory* semantics for paths outside a
  declared derived-output prefix — drop-and-warn stays drop-and-warn there.
- No promotion of any other advisory drift check (file_scope excursions in general, extension
  lifecycle hooks, `lean-challenge-snapshot.sh --check`) to blocking.
- No changes inside any consumer repository, and no `derived_artifact_probes` declaration added
  to this repo's own `.claude-extensions.json`.
- No new opt-in blocking mode for the extension lifecycle hook mechanism.

## Decisions

Recorded here because they are ordinary planning judgment calls the research deliberately left
open, not research questions:

1. **Every declared probe runs on every implement-phase postflight** (no probe selection by
   touched path). Probes are build-free by declaration; selection would require the
   input-to-component linkage the research found unnecessary for the exemption half, and a
   selection bug fails silently in exactly the direction the evidence incident already
   demonstrated (a component whose gate never ran).
2. **Probe failure reuses the `deploy_pending_refusal` shape**, not a new verdict term: a new
   `derived_staleness_refusal` boolean, computed once before WORK (f), read in the `implemented)`
   status-write arm, the verdict `case`, and the commit-message `case`. Verdict resolves to
   `defer` (the task stays in-flight at `implementing`, the next cycle re-evaluates), never a
   fourth meaning for an existing term.
3. **One additive top-level output field** (`derived_staleness`, boolean) is appended to both
   final `jq -n` emits. Additive only — no existing consumer key changes shape, and no
   consumer-side change is required, since `verdict=defer` already carries the loop-control
   decision.
4. **Bounded probe execution**: each `check_command` runs via `timeout <bound> bash -c` from
   `PROJECT_ROOT`, with the same working directory and no privilege or environment an
   implementation agent does not already have. A timeout is a loud, named probe FAILURE (the
   repo declared a command that is not build-free), never a silent pass.
5. **Declaration-shape errors fail open, loudly.** An unparseable `.claude-extensions.json`, a
   missing `jq`, an absent key, or a malformed entry yields zero probes and zero prefixes plus a
   named WARNING — never a refusal, matching the existing `file_scope` length-guard posture.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Inserting a gate before WORK (f) in a 2128-line `set -u` script with load-bearing ordering commentary breaks an existing invariant | H | M | Isolate exactly as `deploy_pending_refusal` is isolated: one boolean, declared unconditionally before the `if`, computed once, read only in the three named sites. No new state threaded through other WORK sections. |
| A declared `check_command` is a raw shell string run by postflight | H | L | Decision 4: `timeout <bound> bash -c` from `PROJECT_ROOT`, no elevated capability, documented as running with exactly the implementation agent's own privilege. |
| A slow or flaky declared probe turns every implement postflight into a blocking wait | M | M | Decision 4's hard bound; a timeout is a probe failure attributed to the repo's declaration, and `context/patterns/external-process-wait.md`'s discipline is cited in the docs phase. |
| Fixing only the multi-task engine leaves `command-gate-out.sh` silently uncovered | H | M | Phase 4 is a separate, non-optional phase with its own fixture in Phase 6. |
| `agent-system/extensions/core/index-entries.json` and `manifest.json` are shared, already-dirty files that concurrent sibling tasks may touch | M | M | Re-read immediately before editing; stage only this task's own hunks with an explicit file list, never a directory or glob add (territory contract). |
| The new gate is read as contradicting the documented advisory-only convention | M | H | Phase 5 states the departure and its justification (the evidence's billed CI cost) explicitly in both the standards exception and the new declaration doc. |
| The deployed `.claude/` tree is already stale for `core` and `lean` | M | H | Phase 6 ends with a bounded redeploy (`timeout 540 bash .claude/scripts/deploy-headless.sh`, Bash tool timeout raised to 600000) and a post-redeploy gate run. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 5 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 2 and 3 are deliberately serialized
despite both depending only on Phase 1: they edit the same file
(`orchestrate-cycle-postflight.sh`), so they are a sequence, not a parallel pair.

---

### Phase 1: Declaration schema and reader library [COMPLETED]

**Goal**: One sourced-never-executed library that resolves the new `derived_artifact_probes`
declaration from `.claude-extensions.json`, fails open loudly on every malformed or absent
shape, and is covered by its own unit suite before any consumer exists.

**Tasks**:
- [x] Create `scripts/lib/derived-artifact-probe-lib.sh`, modelled structurally on
      `scripts/lib/deploy-freshness-lib.sh` (sourced, never executed; header stating the
      contract, the fail-open posture, and the list of consumers). *(completed)*
- [x] Implement `derived_probe_entries <repo_root>`: emits a compact JSON array of validated
      entries, each `{component, check_command, derived_output_dirs}`. Drops a malformed entry
      (missing `check_command`, non-array `derived_output_dirs`, non-string member) with a named
      WARNING on stderr rather than aborting. *(completed)*
- [x] Implement `derived_probe_output_prefixes <repo_root>`: emits a compact JSON array of every
      declared `derived_output_dirs` member across all entries, each normalized to a
      trailing-slash, repo-root-relative prefix (the exact shape WORK (h)'s existing
      `startswith` comparison already consumes). *(completed)*
- [x] Implement `derived_probe_run_all <repo_root> <notice_prefix>`: runs each entry's
      `check_command` under `timeout <bound> bash -c`, cwd `PROJECT_ROOT`; returns 0 when every
      probe exits 0, non-zero when any probe exits non-zero or times out; emits one named line
      per failing probe naming the component, the command, and the exit code. *(completed)*
- [x] Define the bound as a single named constant at the top of the library with a comment
      stating Decision 4's rationale. *(completed)*
- [x] Guarantee the absent/empty cases: no `.claude-extensions.json`, no `jq`, absent key, or
      `[]` all yield `[]` / `[]` / rc 0 with no probe executed and no stderr noise beyond the
      one explanatory line reserved for genuinely malformed input. *(completed)*
- [x] Create `scripts/tests/test-derived-artifact-probe-lib.sh` covering: absent file; absent
      key; empty array; one well-formed entry; two entries; malformed entry dropped with warning;
      prefix normalization (with and without trailing slash); a passing probe; a failing probe; a
      probe that exceeds the bound. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-derived-artifact-probe-lib.sh` covers the new library in full — it has no consumer yet in this phase, so no other suite can observe it.

**Scope Hypothesis**: Two new files and no edits to existing files; confirm at implementation time that no existing script already defines a symbol named `derived_probe_*` (`grep -rn "derived_probe" agent-system/extensions/`) before committing to these names.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh` - new sourced library (entries, prefixes, run-all; fail-open)
- `agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` - new unit suite

**Verification**:
- `bash agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh` is never executed directly; `bash -n` parses clean and `shellcheck` is clean.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-derived-artifact-probe-lib.sh` exits 0 with every listed case asserted.
- Sourcing the library in a repo whose `.claude-extensions.json` carries no new key produces `[]`, `[]`, rc 0 and executes nothing.

---

### Phase 2: Derived-output exemption in the multi-task engine [COMPLETED]

**Goal**: A regenerated file under a declared derived-output prefix is never classified as a
file_scope excursion, so WORK (i) stages it with the change that caused it instead of dropping
it — closing the "HEAD inconsistent" half of GOAL (2).

**Tasks**:
- [x] Source `lib/derived-artifact-probe-lib.sh` at the top of
      `orchestrate-cycle-postflight.sh` alongside the libraries already sourced there.
- [x] In WORK (h), after the existing implicit own-task-directory splice into
      `effective_file_scope_json`, add a second splice of every
      `derived_probe_output_prefixes` member — the minimal, symmetrical change the research
      named, requiring no source-to-output cross-referencing. *(completed)*
- [x] Preserve the existing `length > 0` guard on the declared `file_scope` untouched: a task
      with no declared `file_scope` still gets no advisory and no exemption, exactly as today. *(completed)*
- [x] Emit one named informational line when the splice actually widens the comparison set,
      naming the prefixes added, so the exemption is auditable rather than silent (the
      `--honest-index-rows` spirit the research identified as the precedent). *(completed)*
- [x] Verify by reading WORK (i) that the already-ORDER-DEPENDENT `$excursions_json` consumption
      needs no change: a path exempted here simply never appears in `excursions_json` and is
      staged by the existing loop. *(completed)*
- [x] Re-read `orchestrate-cycle-postflight.sh` immediately before editing (concurrent-sibling
      territory contract) and stage only this phase's own hunks. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-postflight-deploy-gate.sh` builds and exercises the one changed script end-to-end through its real call graph, and the edit changes no interface any other file reads.

**Scope Hypothesis**: Exactly one file edited, in exactly two regions (the source block and the WORK (h) `effective_file_scope_json` construction); confirm with `grep -n "effective_file_scope_json" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` that the construction is still the single site the research found (3 occurrences, all in WORK (h)) before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - source the new library; second `effective_file_scope_json` splice for declared derived-output prefixes; one named audit line

**Verification**:
- `bash -n` and `shellcheck` clean on the changed script.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-postflight-deploy-gate.sh` exits 0 — every existing assertion still passes, demonstrating the no-declaration path is unchanged.
- A manual one-off sandbox run with a synthetic declaration shows a path under the declared prefix absent from the `ADVISORY:` excursion list and present in the staged set.

---

### Phase 3: Blocking staleness probe in the multi-task engine [COMPLETED]

**Goal**: Declared build-free probes run before the status write; any non-zero result prevents
the `implemented`/`completed` transition and resolves the cycle as `defer` — the GOAL (1) half
that catches a component whose gate never ran at all.

**Tasks**:
- [x] Declare `derived_staleness_refusal="false"` unconditionally in WORK (f)'s preamble, beside
      `deploy_pending_refusal`, with a header comment distinguishing the three now-adjacent
      questions: phase accounting (`implemented_gate_passed`), whether the write was refused
      (`deploy_pending_refusal`), and whether derived outputs are stale (this flag). *(completed)*
- [x] Immediately before WORK (f)'s `case "$dispatch_status"`, and only for
      `phase = implement`, call `derived_probe_run_all`; on non-zero set
      `derived_staleness_refusal=true` and emit one named `DERIVED-STALENESS:` line stating
      which components failed and that the task is being left in-flight. *(completed)*
- [x] In the `implemented)` arm, gate the status write on `derived_staleness_refusal != true`:
      when refused, skip `skill_postflight_update` entirely (leaving state.json at
      `implementing`) and emit the named explanation. `skill_gate_completion_claim` is still
      called unconditionally so `implemented_gate_passed` remains a real decision in the output. *(completed)*
- [x] Record the refusal non-fatally via `issue-record.sh` (`--kind issue --severity costly
      --phase implement`), mirroring the `deploy_pending_refusal` call site's shape and its
      narrow "record only the genuine anomaly" posture. *(completed: used class "derived artifact staleness", open/extensible per issue-record.sh's lenient class validation)*
- [x] In the verdict `case`'s `implemented)` arm, extend the existing predicate so a refusal
      resolves `verdict="defer"` (the task stays in-flight; the next cycle re-evaluates), not
      `ok`. *(completed)*
- [x] In WORK (i)'s commit-message `case`'s `implemented)` arm, extend the same predicate so a
      refusal produces the existing `orchestration paused (cycle N)` message rather than
      `complete implementation`. *(completed)*
- [x] Append `derived_staleness` as one additive boolean field to **both** final `jq -n` emits
      (the `user_decision` branch and the plain branch), leaving every existing key untouched. *(completed)*
- [x] Honour `--dry-run`: the probe is a read-only check and runs under both modes (matching
      `skill_gate_completion_claim`'s own posture), but no status write is attempted under
      dry-run either way. *(completed)*
- [x] Re-read the file immediately before editing and stage only this phase's own hunks. *(completed)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: the new `derived_staleness` output key and the widened `verdict=defer` condition are externally visible on this script's stdout JSON contract, so the enumerated direct dependents' suites must build too: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-postflight-deploy-gate.sh,test-orchestrate-cycle-plan.sh`.

**Scope Hypothesis**: Exactly one file, in six regions (WORK (f) preamble, the pre-`case` probe call, the `implemented)` arm, the verdict `case`, the commit-message `case`, and both final emits); confirm the two `deploy_pending_refusal` read sites are still at the verdict `case` and the commit-message `case` only (`grep -n "deploy_pending_refusal"`, expecting 5 occurrences) before mirroring the predicate.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - `derived_staleness_refusal` flag, pre-WORK-(f) probe call, gated `implemented)` status write, issue record, verdict and commit-message predicates, additive output field

**Verification**:
- `bash -n` and `shellcheck` clean on the changed script.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh,test-postflight-deploy-gate.sh,test-orchestrate-cycle-plan.sh` exits 0.
- A sandbox run with a declaration whose `check_command` exits non-zero emits `verdict: "defer"`, `persisted_status: "implementing"`, `derived_staleness: true`, and an `orchestration paused` commit message.
- The same sandbox with no declaration emits `verdict: "ok"` and `derived_staleness: false`, with the probe never executed.

---

### Phase 4: Single-task engine parity [NOT STARTED]

**Goal**: `command-gate-out.sh` (the `/implement`-run-directly path) carries the same blocking
probe ahead of its own `update-task-status.sh` call, so the mechanism is generic across the whole
system rather than only the engine the evidence happened to hit.

**Tasks**:
- [ ] Source `lib/derived-artifact-probe-lib.sh` in `command-gate-out.sh` beside the libraries
      already sourced there (`deploy-baseline-lib.sh`).
- [ ] After `status_token` is resolved and before the defensive-correction
      `update-task-status.sh` call, run `derived_probe_run_all` when
      `status_token = implement`; on non-zero, emit one named `[gate-out] DERIVED-STALENESS:`
      line stating which components failed and that the status is being left at
      `$current_status`, then skip the transition — the same shape the existing exit-4
      phase-accounting refusal and exit-6 deploy-pending branches already use.
- [ ] Do not trigger a redeploy, a retry, or any other recovery from this branch: a stale
      derived artifact is the agent's work to fix forward, not an infrastructure condition.
- [ ] Leave every other gate-out behaviour (artifact validation, the `verification` extension
      hook, the events row) untouched and still running.
- [ ] Create `scripts/tests/test-gate-out-derived-staleness.sh` covering: no declaration
      (transition proceeds exactly as today); declaration with all probes passing (transition
      proceeds); declaration with one probe failing (transition skipped, status unchanged, named
      line emitted); a non-`implement` `status_token` with a failing probe (probe not run,
      transition proceeds).

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh` exercises the one changed script through its real call graph, and the edit adds no symbol any other file reads.

**Scope Hypothesis**: Two files (one edit, one new); confirm at implementation time that `command-gate-out.sh` still has exactly one defensive-correction `update-task-status.sh` call site reached for `status_token = implement` (`grep -n "update-task-status.sh" agent-system/extensions/core/scripts/command-gate-out.sh`, expecting the two known sites — the primary and the post-redeploy retry) and that the gate is placed ahead of the primary one only.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` - source the library; blocking probe ahead of the defensive-correction status write for `status_token = implement`
- `agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh` - new suite for the four cases above

**Verification**:
- `bash -n` and `shellcheck` clean on both files.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-gate-out-self-attribution.sh` exits 0.
- The no-declaration case asserts the identical status transition and identical stdout as before the change.

---

### Phase 5: Standards, documentation, and registration [NOT STARTED]

**Goal**: The declaration point is documented, the new blocking gate is named as a conscious
departure from the advisory-only convention, the postflight command prohibition carries an
explicit narrowly-scoped exception, and every new file is registered so it deploys and is
discoverable.

**Tasks**:
- [ ] Add one new entry to `context/standards/postflight-tool-restrictions.md`'s `## Exceptions`
      section, sibling to the existing D4 entry: the declared, build-free `check_command` is the
      sole sanctioned exception to the Bash "Verification is agent work" prohibition, scoped to
      exactly the command string the repo declared — never an open-ended "any build-free
      command" — and naming both call sites.
- [ ] Create `context/standards/repo-level-declarations.md` documenting, generically: that
      `.claude-extensions.json`'s top level is open to hand-authored sibling keys beyond
      `extensions`/`version`; why the Lua read/write path preserves them; the
      `derived_artifact_probes` entry schema (`component`, `check_command`,
      `derived_output_dirs`); the fail-open-on-absence guarantee; the bounded-execution and
      privilege posture (Decision 4, citing `context/patterns/external-process-wait.md`'s
      discipline); and an explicit statement that this is the system's first *blocking*
      staleness gate, with the justification (a wasted, billed CI run) and an explicit note that
      no other advisory drift check is promoted by analogy.
- [ ] Add reciprocal pointers: from `docs/guides/creating-extensions.md`'s Lifecycle Hooks
      section (stating that hooks are the wrong vehicle for a repo-level declaration and naming
      the new doc), and from `lib/derived-artifact-probe-lib.sh`'s header.
- [ ] Register the new context file in `index-entries.json` with `domain: core`,
      `subdomain: standards`, an accurate `line_count`, keywords, and `on_demand: true`.
- [ ] Add the three new script paths to `manifest.json`'s `provides.scripts`
      (`lib/derived-artifact-probe-lib.sh`, `tests/test-derived-artifact-probe-lib.sh`,
      `tests/test-gate-out-derived-staleness.sh`), preserving the array's existing sort order.
- [ ] Use no task-number references anywhere under `agent-system/**`; cite durable anchors
      (filenames, section headings) only.
- [ ] Re-read `index-entries.json` and `manifest.json` immediately before editing — both are
      shared, already-dirty files — and stage only this phase's own hunks with an explicit file
      list.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core` is the honest covering check for a source-store markdown-and-manifest edit with no mapped test suite (doc-lint plus the task-reference lint, with the explicit source-store `TARGET` rather than the no-argument form), run together with a diff read-through of each prose hunk.

**Scope Hypothesis**: Five files, one of them new; confirm at implementation time that `provides.context` still lists `standards` as a whole directory (so the new markdown file needs no `provides.context` entry) with `jq -r '.provides.context' agent-system/extensions/core/manifest.json`.

**Files to modify**:
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - one new narrowly-scoped Exceptions entry
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` - new doc: declaration point, entry schema, fail-open guarantee, execution posture, advisory-to-blocking departure and its justification
- `agent-system/extensions/core/docs/guides/creating-extensions.md` - pointer from Lifecycle Hooks to the new doc, stating why hooks are the wrong vehicle
- `agent-system/extensions/core/index-entries.json` - entry for the new context file
- `agent-system/extensions/core/manifest.json` - three new `provides.scripts` paths

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core` exits 0 with no new findings.
- `jq -e . agent-system/extensions/core/index-entries.json` and `jq -e . agent-system/extensions/core/manifest.json` both parse.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo-wide lint) reports no new occurrence under `agent-system/**`.
- Diff read-through confirms every changed hunk is prose or a JSON array member, with no stray edit outside the enumerated regions.

---

### Phase 6: Acceptance fixtures, full gate, and redeploy [NOT STARTED]

**Goal**: The evidence-shaped incident is reproduced as a fixture that now ends red or fully
committed, the no-declaration regression case is pinned, and the whole change is gated and
deployed.

**Tasks**:
- [ ] Extend `scripts/tests/test-orchestrate-cycle-postflight.sh` using its existing
      `setup_sandbox`/`write_state`/`commit_fixture`/`run_sut` pattern (synthetic names only —
      "candidate #N", never a task-number reference) with the evidence-shaped fixture: two
      declared components, an identity input of both changed, one component's derived output
      regenerated and reported in `modified_files` **outside** the declared `file_scope`, the
      other component's `check_command` failing with nothing regenerated. Assert the dispatch
      ends `verdict: "defer"` with `derived_staleness: true` and `persisted_status:
      "implementing"`, and that the regenerated file was **staged**, not `EXCURSION DROPPED`.
- [ ] Add the complementary fixture where every declared probe passes: the regenerated
      derived-output file is staged with its cause and the dispatch ends `verdict: "ok"` — the
      "every affected certificate committed" branch of the acceptance criterion.
- [ ] Add the regression fixture: a repo declaring no `derived_artifact_probes` key at all
      produces byte-for-byte the pre-change outcome (same verdict, same excursion advisory, same
      dropped-path behaviour, `derived_staleness: false`, probe never executed).
- [ ] Confirm the single-task engine's equivalent coverage landed in Phase 4's suite; if the
      cross-engine shape is not asserted there, add it rather than relying on parity by
      assumption.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`), including Gate 8's full shell
      suite battery via `scripts/tests/run-all.sh`.
- [ ] Redeploy with the bounded-wait idiom: `timeout 540 bash
      .claude/scripts/deploy-headless.sh` with the Bash tool `timeout` parameter raised to
      600000 (the dispatch's deploy-freshness context reports `core` and `lean` already stale);
      then re-run the gate set and compare findings against the pre-redeploy baseline.
- [ ] Record any issue or win encountered during this phase via `issue-record.sh` as it arises.

**Timing**: 2 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: Three new fixtures in one existing suite, plus at most one assertion added to the Phase 4 suite; confirm at implementation time whether Phase 4's suite already asserts the cross-engine shape (`grep -n "derived" agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh`) before adding a fourth case, and confirm the sandbox helper names are still `setup_sandbox`/`write_state`/`commit_fixture`/`run_sut` rather than trusting this plan's reading of them.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - evidence-shaped fixture, all-probes-pass fixture, no-declaration regression fixture
- `agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh` - cross-engine assertion if not already covered by Phase 4

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 (the complete gate set it aggregates, Gate 8's full `scripts/tests/run-all.sh` battery included) — no `--skip-slow` and no `--only-gate` narrowing for this phase's own closure.
- The three new fixtures each pass, and the regression fixture's assertions are literal equality against the pre-change outcome, not a looser shape check.
- `timeout 540 bash .claude/scripts/deploy-headless.sh` lands, and the post-redeploy `verify-deploy.sh` run introduces no new finding relative to the pre-redeploy baseline.
- `bash .claude/scripts/check-deploy-freshness.sh` no longer reports `core` stale.

---

## Testing & Validation

- [ ] `test-derived-artifact-probe-lib.sh` passes: absent file, absent key, empty array,
      one entry, two entries, malformed entry dropped, prefix normalization, passing probe,
      failing probe, over-bound probe.
- [ ] `test-orchestrate-cycle-postflight.sh` passes in full, including the three new fixtures
      and every pre-existing assertion.
- [ ] `test-gate-out-derived-staleness.sh` passes: no declaration, all pass, one failing,
      non-`implement` token.
- [ ] `test-postflight-deploy-gate.sh` and `test-orchestrate-cycle-plan.sh` pass unchanged
      (the additive output field breaks no consumer).
- [ ] ACCEPTANCE (evidence shape): an identity input of two components changed, only one gate
      run, regenerated certificate outside `file_scope` → the phase ends red (`verdict: defer`,
      status left `implementing`) or with every affected derived file committed.
- [ ] ACCEPTANCE (regression): a repo declaring no probe is byte-for-byte unaffected.
- [ ] ACCEPTANCE (docs): `context/standards/repo-level-declarations.md` names
      `.claude-extensions.json`'s `derived_artifact_probes` key as the declaration point, and is
      reachable from `index-entries.json` and from `creating-extensions.md`.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 before and after the redeploy.
- [ ] No task-number reference anywhere under `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-derived-artifact-probe-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-gate-out-derived-staleness.sh` (new)
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` (new)
- Edits: `orchestrate-cycle-postflight.sh`, `command-gate-out.sh`,
  `test-orchestrate-cycle-postflight.sh`, `postflight-tool-restrictions.md`,
  `docs/guides/creating-extensions.md`, `index-entries.json`, `manifest.json`
- A redeployed `.claude/` tree (regenerated artifact, not a source edit)
- `specs/381_implement_postflight_derived_artifact_staleness/summaries/01_*-summary.md` at
  completion

## Rollback/Contingency

Each phase is one commit, so the ordinary contingency is `git revert` of the offending phase
commit — the new mechanism is strictly additive and fails open, so reverting any single phase
leaves the system in its pre-change behaviour rather than a half-wired state. Phases 2 and 3
share one file and must be reverted newest-first if both are rolled back.

If uncommitted work must be discarded to reach a known-good tree, that is a genuine rollback:
take the snapshot first per `context/contracts/recovery.md`'s rollback rung (including its
out-of-scope override flag for a deliberate whole-tree case), then run the destructive command.
For an ordinary defensive checkpoint before the Phase 3 edit — the riskiest hunk, inside a
2128-line `set -u` script — use the durable non-reverting form
`bash .claude/scripts/git-snapshot.sh 381 --no-revert` instead.

If the blocking gate proves to misfire in practice, the minimal de-risking step is to leave
Phases 1, 2, 5 in place (the exemption and the documented declaration point are independently
valuable and non-blocking) and revert only Phases 3 and 4, reducing the mechanism to
detection-plus-exemption without a refusal.
