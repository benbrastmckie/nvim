# Implementation Plan: Task #637

- **Task**: 637 - Make the sapience extension fully functional across loaded repositories
- **Status**: [NOT STARTED]
- **Effort**: 4.75 hours
- **Dependencies**: 628, 635, 636 (all three now `[COMPLETED]`)
- **Research Inputs**: specs/637_make_sapience_extension_fully_functional/reports/02_scoping-and-remaining-gaps.md, specs/637_make_sapience_extension_fully_functional/reports/01_seed-audit-findings.md
- **Artifacts**: plans/02_cross-repo-closeout-verification.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

All three dependency tasks (628, 635, 636) have landed, so three of this task's four goals now
have a deployed mechanism and the remaining work is to prove each one reaches every loaded
repository, convert the one unmechanized claim ("tagged postflight writes fire reliably in every
loaded repo") into a standing verifier check, and record in the durable design corpus the two
facts this task's own description states as open defects but which are measurably not defects of
this source store. One new mechanism is built (a postflight tagged-write reachability check in
`verify-sapience-mcp.sh`); everything else is measurement, documentation, and a five-repository
redeploy-and-sweep.

### Research Integration

The research report's central ruling — depend on 628/635/636 rather than absorb or expand into
them — is already reflected in `specs/state.json` (`dependencies: [628, 635, 636]`), and all
three are complete. Three of its findings are carried directly into this plan:

- **Goal 2 (prompt-time injection scoping) is a vendor-owned foreclosure, not a local defect.**
  `verify-sapience-context-scoping.sh`'s own header and
  `domain/injection-site-scoping.md`'s "The Ruling" section both establish that neither candidate
  remedy is reachable from this repository, and that a `residual holds` verdict is the expected
  green state. Phase 3 writes that disposition into the file's own
  "Verifying This Residual Is Still Current" section so a future reader does not re-read the
  probe's green verdict as a failure; Phase 1 probe-confirms the verdict with the N-repeat
  agreement rule 636 added.
- **The capture-extraction stall has an operational cause and an out-of-repository owner.** The
  research inferred a manual-invocation gap; this planning pass confirmed the mechanism directly:
  `sapience review|sync|coverage|backfill` dispatch to `~/.sapience/extract_local.py` through the
  nix-provided `sapience` launcher, and the only scheduling lever is
  `services.sapience.backgroundSync` in `~/.dotfiles/modules/home/services/sapience.nix`, which
  defaults to `false` with a recorded cost rationale ("Extraction spends real money or real CPU on
  every run"). Nothing in this source store drives that pipeline. Phase 3 documents the
  mechanism; Phase 4 surfaces the enable-or-leave choice to the user, since it is theirs.
- **The capture/activation list disagreement already has a ruling.** 636 ruled that this source
  store stops at `verify-sapience-mcp.sh`'s check (i) and does not write
  `capture.projects[].enabled`, because `~/.dotfiles` already owns a capture-map writer. This plan
  does not reopen that ruling; Phase 1 records the measured disagreement set and Phase 4 reports
  it as a named, owned residual.

The research's one open recommendation that is NOT carried forward is appending the capture-stall
item to task 636's description: 636 completed before that append happened, so the item is picked
up here instead (Phase 3), which is where it now has no other owner.

### Prior Plan Reference

No prior plan for this task. Three completed sibling plans were read for effort calibration and
structure: `specs/628_retract_sapience_write_tool_grants/plans/01_retract-sapience-write-grants.md`
supplies the five-repository baseline/redeploy/fingerprint-diff shape this plan reuses in Phases 1
and 4 (its Phase 1 at 0.75h and Phase 5 at 1h are the direct calibration for this plan's own
Phases 1 and 4), and `specs/636_sapience_activation_surface_scoping_gaps/plans/01_activation-surface-scoping-gaps.md`
supplies the verifier-check-plus-fixture-cases shape Phase 2 follows for check (j).

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:

- Convert "tagged postflight writes fire in every loaded repo" from a one-off audit claim into a
  standing, mechanical per-repo check (`verify-sapience-mcp.sh` check (j)), covering both the
  sapience-owned write scripts and the two core call sites that invoke them.
- Prove, by measurement recorded in a `records/` artifact, that in every reachable loaded
  repository: check (e) now passes at seven grants, the postflight tagged-write path reaches a
  correctly `[repo:<slug>]`-tagged request body, and check (i) reports its capture/activation
  verdict.
- Document the capture-extraction triggering mechanism and its out-of-repository scheduling owner
  in `domain/per-repo-scoping.md`, so a future freshness gap is diagnosed from documentation
  rather than re-measured from machine state.
- State the three `verify-sapience-context-scoping.sh` outcomes' dispositions explicitly in
  `domain/injection-site-scoping.md`, so the accepted-residual verdict is not re-read as a defect.
- Surface to the user the two remaining levers that are genuinely theirs and lie outside this
  repository: enabling scheduled extraction, and enabling capture for the two active-but-not-
  captured repositories.

**Non-Goals**:

- Repairing `~/Projects/abood` (explicitly out of scope per the task description; it is on hold and
  still carries the four write-tool grants and no deployed postflight script).
- Writing `capture.projects[].enabled` from this source store — 636 ruled against it and this plan
  does not reopen that ruling.
- Editing anything under `~/.dotfiles` (a separate repository; its sapience module and the
  scheduling decision are sited there under `rules/source-store-deploy-boundary.md`'s task-siting
  rule).
- Running `sapience sync` to drain the stalled extraction queue. That uploads transcript-derived
  content and spends real money or CPU per the module's own rationale; it is the user's call, not
  an implementation step (Phase 4 raises it, non-blocking).
- Eliminating the `residual holds` verdict from `verify-sapience-context-scoping.sh`. No local
  change can alter it; the only lever is the already-drafted vendor ask.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Check (j) asserts content of two CORE-owned scripts from a SAPIENCE verifier, coupling the two extensions | M | H | This coupling is the point: a repo whose core deploy predates the postflight wiring is exactly the state in which tagged writes silently never fire, and no sapience-only check can see it. Phase 2 records the coupling as a deliberate decision inside the check's own comment block and makes the failure message name the remedy (redeploy), rather than leaving a reader to infer why a sapience check reads core files. |
| A loaded repository is unreachable or dirty at Phase 1 or Phase 4 | M | L | All five were reachable during this planning pass. Each is treated as an independent read-and-deploy target, no git operation is run in any of them, and an unreachable repository is recorded as an explicit exclusion via `issue-record.sh` and named in the summary rather than silently skipped. |
| The cross-repo dry-run probe writes to the vault by accident | H | L | The probe runs `postflight-sapience-notes.sh --dry-run`, which forwards `--dry-run` to every `sapience-remember.sh` call; that path prints the token-redacted request body and exits 0 **without issuing a request** (`sapience-remember.sh`, `--dry-run` branch). Phase 3's probe asserts on the printed `provenance` string only, and the plan names no non-dry-run invocation anywhere. |
| `postflight-sapience-notes.sh` refuses to run from the source store (`deploy-root-guard.sh`) | M | M | Already accounted for: the probe invokes each repository's **deployed** copy at `<repo>/.claude/scripts/postflight-sapience-notes.sh`, never the source-store path. Phase 2's new check (j) likewise reads the deployed tree rather than invoking a guarded script. |
| Editing two `context/project/sapience/domain/*.md` files desynchronizes `index-entries.json`'s `line_count`, which a gate checks | M | H | Phase 3 declares `agent-system/extensions/sapience/index-entries.json` in its own `Files to modify` and runs `generate-context-line-counts.sh --write` in the same phase, rather than deferring reconciliation to Phase 4. |
| Check (j) makes a previously-green fixture in `test-sapience-mcp-registration.sh` fail (as check (h) did to case 20 during 636) | M | M | Phase 2's task list includes re-running the whole suite and repairing any all-green fixture the new check newly fails, treating that repair as expected work rather than a deviation. |
| The acceptance bar as literally worded ("probe returns RESIDUAL_HOLDS" read as a defect; "capture sync is restored") cannot be met from this repository | M | H | Both are re-read explicitly in Phase 1's records file, with the measured reason and the named owner for each, and both are reported as such in the completion summary rather than claimed closed. Phase 4 raises the two user-owned levers as a non-blocking `user_decision`. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Pin the cross-repo closeout baseline [NOT STARTED]

**Goal**: Record, in one durable records file, the measured pre-change state of all four goals
across every loaded repository, so Phase 4 can diff against it and so the two acceptance bars that
cannot be met locally are re-read on the record before any code changes.

**Tasks**:

- [ ] Create `specs/637_make_sapience_extension_fully_functional/records/01_cross-repo-closeout-evidence.md`.
- [ ] For each of the five healthy loaded repositories (`/home/benjamin/.config/nvim`,
      `/home/benjamin/.dotfiles`, `/home/benjamin/Projects/BimodalLogic`,
      `/home/benjamin/Projects/Sapience/sf1-engine`,
      `/home/benjamin/Projects/Sapience/sapience-app`), record: the `mcp__sapience__*` grant count
      and sorted grant list from `.claude/settings.local.json`; whether
      `.claude/scripts/postflight-sapience-notes.sh` and `.claude/scripts/sapience-remember.sh`
      exist and are executable; and the occurrence count of `postflight-sapience-notes.sh` in both
      `.claude/scripts/orchestrate-cycle-postflight.sh` and
      `.claude/scripts/reconcile-task-status.sh`.
- [ ] Run `bash .claude/scripts/verify-sapience-mcp.sh` in each of the five repositories and record
      each check's verdict verbatim, with check (e) and check (i) called out by name.
- [ ] Run `bash .claude/scripts/verify-sapience-context-scoping.sh --repeat 3` once in this
      repository and record the verdict. A unanimous `residual holds` is the expected green result;
      record `inconclusive` as-is if that is what comes back, and do not retry more than once.
- [ ] Record `~/.sapience/config.json`'s `hooks` value and its full `capture.projects[]`
      path-prefix/`enabled` table, and the mtimes of `~/.sapience/extracted.json`,
      `~/.sapience/pending_kos.jsonl`, and `~/.sapience/extract_yield.json`. Name the set of
      repositories that have the extension active but capture not enabled.
- [ ] Record the confirmed extraction-trigger mechanism as a baseline fact for Phase 3 to document:
      the `sapience` launcher's `review|sync|coverage|backfill|pending|projects` subcommands
      dispatch to `~/.sapience/extract_local.py`; `services.sapience.backgroundSync` in
      `~/.dotfiles/modules/home/services/sapience.nix` defaults to `false` and is set nowhere, so
      `sapience-sync.timer` is defined but not installed; and no systemd user timer or crontab
      entry for any sapience process exists on this machine.
- [ ] Re-read the two acceptance bars that cannot be met from this repository, with the reason and
      the owner for each, in their own subsection: goal 2's `RESIDUAL_HOLDS` bar (vendor-owned
      foreclosure; only lever is the drafted vendor ask) and goal 3's "capture sync is restored"
      bar (manual-by-design extraction, scheduling owned by `~/.dotfiles`'s sapience module; the
      `enabled` list writer likewise, per 636's recorded ruling).
- [ ] Record via `bash .claude/scripts/issue-record.sh` any repository that is unreachable, and name
      the exclusion in the records file.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase writes exactly one `specs/**` records file and otherwise runs
only read-only probes (`jq`, `grep -c`, `stat`, and two read-only verifier scripts), so the `prose`
row's diff read-through plus `bash .claude/scripts/check-task-references.sh` over the new records
file is the full covering check (`suite_selection_select` returns `__FULL_SWEEP__` for a `specs/**`
path, and `validate-artifact.sh` accepts only `report`/`plan`/`summary`, not a `records/` file).

**Scope Hypothesis**: Five healthy loaded repositories are in scope, all five were reachable during
this planning pass, and `~/Projects/abood` is a sixth loaded repository deliberately excluded (on
hold, out of scope by the task description). The implementer re-checks reachability per repository
at probe time and records any exclusion explicitly rather than restating this count as fact.

**Files to modify**:

- `specs/637_make_sapience_extension_fully_functional/records/01_cross-repo-closeout-evidence.md` - new file; the full pre-change baseline and the two re-read acceptance bars

**Verification**:

- The records file exists, is non-empty, and carries one result block per repository probed plus an
  explicit exclusion line for every repository not probed.
- `bash .claude/scripts/check-task-references.sh` reports no new finding (the records file lives
  under `specs/**`, where task-number references are exempt, so this is a regression guard on the
  rest of the tree rather than on the new file).
- Diff read-through confirms the phase changed nothing outside `specs/**`.

---

### Phase 2: Add check (j) — postflight tagged-write reachability [NOT STARTED]

**Goal**: Make "the tagged postflight write path is actually reachable in this repository" a
standing, named verifier check with fixture coverage, so a repo whose deploy predates the
postflight wiring is detected rather than discovered by the absence of notes weeks later.

**Tasks**:

- [ ] Add check (j) to `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`,
      positioned after check (i), asserting against the resolved project's **deployed** tree (the
      same tree check (e) already reads, never the source store): that
      `.claude/scripts/postflight-sapience-notes.sh` and `.claude/scripts/sapience-remember.sh`
      both exist and are executable, and that `.claude/scripts/orchestrate-cycle-postflight.sh` and
      `.claude/scripts/reconcile-task-status.sh` each contain at least one
      `postflight-sapience-notes.sh` invocation.
- [ ] Make check (j) FAIL (not warn) when any of those four conditions is unmet, with a message
      naming which one failed and naming the remedy explicitly as a redeploy
      (`deploy-headless.sh`), and SKIP when no deployed tree is reachable for the resolved project
      — mirroring check (e)/(f)'s existing skip convention rather than inventing a second one.
- [ ] Record inside check (j)'s own comment block why a sapience verifier reads two core-owned
      scripts: a core deploy predating the postflight wiring is precisely the state in which tagged
      writes silently never fire, and no sapience-only assertion can observe it.
- [ ] Extend the `--help` / header check inventory in the same file with check (j)'s one-line
      description, matching the existing (a)-(i) entries' form.
- [ ] Add fixture cases to
      `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` covering:
      all four conditions met (pass); each of the two scripts missing or non-executable (fail);
      each core call site present-but-unwired (fail); and no deployed tree (skip). Use
      `grep -c`'s own exit-1-on-zero-match behavior carefully — capture its stdout into a variable
      with `|| true` rather than an `|| echo 0` fallback, which double-prints on a clean zero-match
      run.
- [ ] Run the suite from the source store
      (`bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`,
      which exercises the edited sibling copy via its own `VERIFIER_SRC` path) and repair any
      pre-existing all-green fixture that the new check newly fails, exactly as check (h)'s
      addition required of case 20.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: Both edits are confined to `verify-sapience-mcp.sh` and its own fixture
suite with no externally visible signature change, and the covering check is the suite that targets
that exact script: `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh`
(equivalently `bash .claude/scripts/tests/run-all.sh --only test-sapience-mcp-registration.sh` once
redeployed in Phase 4).

**Scope Hypothesis**: Check (j) is expected to add roughly 45-60 lines to a 500-line script and
4-6 new fixture cases numbered from 48 upward in a 1088-line suite, and to require no
`manifest.json` change (no new file is created). The implementer confirms the actual case numbering
against the suite's own current tail and confirms `manifest.json` needs no edit by re-running
`sync-manifest-scripts.sh` in its read-only form rather than assuming it.

**Files to modify**:

- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` - new check (j) after check (i), plus its header/`--help` inventory entry
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` - new fixture cases for check (j); repair of any all-green fixture the new check newly fails

**Verification**:

- `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` passes
  with every case green, including the new ones.
- `bash .claude/scripts/verify-sapience-mcp.sh` run in this repository reports check (j) as PASS
  (this repository's deployed tree satisfies all four conditions today — confirmed during planning).
- `bash -n agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` and
  `shellcheck` on both edited scripts report no new finding.

---

### Phase 3: Document the capture-extraction trigger and the residual-probe dispositions [NOT STARTED]

**Goal**: Put the two measured facts this task's description frames as open defects into the durable
design corpus, so each is diagnosed from documentation rather than re-measured from live machine
state as both research rounds had to do.

**Tasks**:

- [ ] Add a `### Capture Scheduling and the Manual-Only Trigger` subsection to
      `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`,
      immediately after the existing `### Capture/Activation Reconciliation` subsection (confirmed
      present at that file's tail during planning). State: which verbs drive extraction
      (`sapience review|sync|coverage|backfill`, dispatching to `~/.sapience/extract_local.py`
      through the nix-provided launcher); that extraction is manual-by-design, with the module's own
      cost rationale; that `services.sapience.backgroundSync` in
      `~/.dotfiles/modules/home/services/sapience.nix` (default `false`) and its
      `sapience-sync.timer` are the only scheduling lever and live outside this source store; and
      the consequence — a gap in `extracted.json`/`pending_kos.jsonl` freshness is not a defect of
      this extension and no script here drives that pipeline.
- [ ] Cross-reference that new subsection from the adjacent `### Capture/Activation Reconciliation`
      subsection's existing `~/.dotfiles` siting sentence, so the two out-of-repository capture
      concerns (who writes `enabled`, who schedules extraction) read as one coherent boundary
      rather than two unrelated notes.
- [ ] Rewrite `## Verifying This Residual Is Still Current` in
      `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md`
      (confirmed present, currently five lines) to state each of the three probe outcomes' standing
      disposition by name: `residual holds` is the expected green result and confirms the measured
      foreclosure rather than reporting a failure; `residual lifted` means the vendor ask landed and
      the Ruling above should be revisited; `inconclusive` means re-run. Name the `--repeat N`
      unanimous-agreement rule as the reason a single-run verdict is not relied on.
- [ ] State in that same rewritten section that no change available to this repository can move the
      verdict, naming the two already-recorded foreclosures as the reason, so a future reader does
      not open a defect against a green probe.
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --write` and confirm
      `agent-system/extensions/sapience/index-entries.json` now carries the edited files' actual
      line counts.
- [ ] Re-read both edited files for forbidden language: no task-number references and no
      record-versioning phrasing ("previously", "no longer", "formerly") anywhere in content
      landing under `agent-system/**`.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every edit lands in markdown prose plus one generated JSON line-count
field, with zero executable surface, and the covering check is the generator that owns the derived
field — `bash .claude/scripts/generate-context-line-counts.sh` reporting zero corrections on a
second pass — plus a diff read-through confirming each hunk lies inside prose.

**Scope Hypothesis**: Two context files are in scope, both confirmed present during planning with
the named target sections intact (`### Capture/Activation Reconciliation` at `per-repo-scoping.md`'s
tail; `## Verifying This Residual Is Still Current`, currently five lines, at
`injection-site-scoping.md`'s tail), and both carry an `index-entries.json` `line_count` entry that
this phase must reconcile. The implementer re-confirms both section headings exist before editing;
if either has moved or been renamed since, the edit attaches to the section that actually owns the
subject matter and the records file notes the divergence rather than creating a duplicate section.

**Files to modify**:

- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` - new `### Capture Scheduling and the Manual-Only Trigger` subsection and the adjacent cross-reference
- `agent-system/extensions/sapience/context/project/sapience/domain/injection-site-scoping.md` - rewritten `## Verifying This Residual Is Still Current` section
- `agent-system/extensions/sapience/index-entries.json` - `line_count` reconciled for both edited context files, in this same phase, because the line-count check is commit-blocking

**Verification**:

- A second `bash .claude/scripts/generate-context-line-counts.sh` pass reports zero entries
  corrected.
- `bash .claude/scripts/check-task-references.sh` reports no new finding for either edited file.
- Diff read-through confirms both new/rewritten sections state the mechanism and its owner without
  naming any task number and without narrating the document's own draft history.

---

### Phase 4: Redeploy, sweep all five repositories, and close the acceptance criteria [NOT STARTED]

**Goal**: Land check (j) and both documentation changes in every reachable loaded repository, prove
each of the four goals' disposition by measurement recorded beside its Phase 1 baseline, and raise
the two remaining user-owned levers.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` against this repository
      first, then once per out-of-tree target with that repository root as `TARGET_REPO`, for the
      five repositories Phase 1 recorded as reachable. Do not pass `--wipe`. Capture each run's
      output.
- [ ] In each redeployed repository, run `bash .claude/scripts/verify-sapience-mcp.sh` and record
      every check's verdict beside its Phase 1 baseline. Check (j) must PASS in all five; check (e)
      must report seven grants and five hooks in all five.
- [ ] In each redeployed repository, run the tagged-write reachability probe end to end: create a
      scratch task directory holding a minimal `.return-meta.json` with a two-element
      `sapience_notes` array, invoke that repository's **deployed**
      `.claude/scripts/postflight-sapience-notes.sh --task-dir <scratch> --task 637 --dry-run`, and
      assert the printed request body carries the correct `[repo:<slug>]` provenance for that
      repository. Remove the scratch directory afterward. Issue no non-dry-run call anywhere.
- [ ] Record the capture/activation verdict per repository from check (i), and restate the
      active-but-not-captured set with its named owner (`~/.dotfiles`, per 636's recorded ruling).
- [ ] Append to `records/01_cross-repo-closeout-evidence.md` a per-goal disposition block: goal 1
      (tagged writes) — mechanism deployed and probe-confirmed per repository, now covered by a
      standing check; goal 2 (injection scoping) — accepted vendor-owned residual, probe-verified,
      disposition now documented; goal 3 (capture) — list disagreement owned by `~/.dotfiles`,
      extraction manual-by-design with its scheduling lever named; goal 4 (check (e)) — passing at
      seven grants in all five repositories.
- [ ] Set a non-blocking `user_decision` on `.return-meta.json` (mirrored into
      `.orchestrator-handoff.json`) covering the two levers that are the user's alone and lie
      outside this repository: whether to enable scheduled extraction
      (`services.sapience.backgroundSync` in `~/.dotfiles`, which spends real money or CPU per run)
      or leave extraction on-request, and whether to enable capture for the two active-but-not-
      captured repositories. Recommend the conservative option (leave both as they stand, since
      both spend money or upload transcript-derived content and neither is required by any goal
      this plan closes) and proceed on it.
- [ ] Record one result line per repository including every exclusion, and record a win or issue
      entry via `bash .claude/scripts/issue-record.sh` reflecting how the sweep actually went.

**Timing**: 1.25 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Scope Hypothesis**: Five repositories are in scope for the redeploy and the sweep, and all five
were reachable during this planning pass. The implementer re-checks reachability per repository at
deploy time against Phase 1's recorded set, reports any repository Phase 1 already excluded as an
explicit exclusion rather than silently dropping it, and states each acceptance claim over the
repositories actually swept.

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, which regenerates the entire deployed `.claude/` tree in each target repository; the reserved sentinel declares that whole-tree claim, which no real declared path can express
- `agent-system/extensions/sapience/index-entries.json` - reconcile any `line_count` the redeploy's own auto-repair pass reports as still drifted
- `specs/637_make_sapience_extension_fully_functional/records/01_cross-repo-closeout-evidence.md` - append the post-change per-repo results and the four per-goal disposition blocks beside their baselines

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` passes in this repository — the complete gate set, with
  no `--skip-slow` and no `--only-gate` narrowing.
- `bash .claude/scripts/tests/run-all.sh` passes the full battery, with
  `test-sapience-mcp-registration.sh` green including check (j)'s new cases.
- `bash .claude/scripts/verify-sapience-mcp.sh` reports check (j) PASS and check (e) at seven
  grants and five hooks in each of the five repositories swept.
- The dry-run probe's printed body carries the expected `[repo:<slug>]` provenance in each of the
  five repositories, and no non-dry-run write was issued (confirmed by the absence of any
  `sapience-remember.sh` invocation without `--dry-run` in the phase's own command history).

---

## Testing & Validation

- [ ] `bash agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` — all
      cases green, including check (j)'s new fixtures (Phase 2).
- [ ] `bash .claude/scripts/generate-context-line-counts.sh` — zero entries corrected on a second
      pass (Phase 3).
- [ ] `bash .claude/scripts/check-task-references.sh` — no new finding for either edited context
      file (Phase 3).
- [ ] `bash .claude/scripts/verify-deploy.sh` — full gate set passes in this repository (Phase 4).
- [ ] `bash .claude/scripts/tests/run-all.sh` — full suite battery passes (Phase 4).
- [ ] `bash .claude/scripts/verify-sapience-mcp.sh` — checks (a)-(j) report their expected verdicts
      in each of the five swept repositories (Phases 1 and 4).
- [ ] `bash .claude/scripts/verify-sapience-context-scoping.sh --repeat 3` — returns a unanimous
      verdict, recorded as-is (Phase 1).

## Artifacts & Outputs

- `specs/637_make_sapience_extension_fully_functional/records/01_cross-repo-closeout-evidence.md` —
  baseline, post-change sweep, and the four per-goal disposition blocks.
- `specs/637_make_sapience_extension_fully_functional/summaries/02_cross-repo-closeout-verification-summary.md` —
  completion summary, stating explicitly which acceptance bars were closed mechanically and which
  are reported as owned residuals.
- Check (j) in `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh`, with fixture
  coverage.
- The new capture-scheduling subsection in `domain/per-repo-scoping.md` and the rewritten
  residual-verification section in `domain/injection-site-scoping.md`.
- A non-blocking `user_decision` covering the two out-of-repository levers.

## Rollback/Contingency

Phases 1 and 4's records-file content is additive within `specs/**` and carries no rollback
concern. Phase 2's and Phase 3's edits are confined to four source-store files and one generated
`line_count` field; each phase commits as its own green sub-step, so reverting either is a single
`git revert` of that phase's commit followed by `bash agent-system/extensions/core/scripts/deploy-headless.sh`
to regenerate the deployed tree from the reverted source store. Phase 4's redeploy is idempotent
and performs no git operation in any out-of-tree repository, so a failed sweep in one repository is
recorded as an exclusion and re-attempted without affecting the others; if check (j) proves to fail
in a repository for a reason the plan did not anticipate, the phase halts, records the finding via
`issue-record.sh`, and reports the repository as an exclusion rather than weakening the check to
make the sweep green.
