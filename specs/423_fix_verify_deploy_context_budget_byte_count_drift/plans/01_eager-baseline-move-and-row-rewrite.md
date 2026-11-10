# Implementation Plan: Task #423

- **Task**: 423 - Fix verify-deploy context budget byte-count drift
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None (see Risks for the cross-owned gate 24 residual, which is NOT a blocking dependency)
- **Research Inputs**: specs/423_fix_verify_deploy_context_budget_byte_count_drift/reports/01_eager-budget-overage-attribution.md
- **Artifacts**: plans/01_eager-baseline-move-and-row-rewrite.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Resolve the Gate 20 eager-load baseline regression by route (b) — a reviewed, dated
`eager_load.baseline_bytes` move in
`agent-system/extensions/core/context/config/orchestrator-context-budget.json`, with a dated
justification entry appended to that field's own `note` history — after a fresh live
re-measurement. Then re-attribute (not delete) the `known-failures.txt` row for
`test-verify-deploy-context-budget.sh`, because the suite's baseline-fixture assertion is
`rc -eq 0` over a full `--max-cost moderate` verify-deploy run and a second, separately-owned
gate 24 finding keeps that one case red regardless of this task's fix. Two phases: the config
move, then the row rewrite plus the full gate set.

### Research Integration

The research report traced the full +3,294 B of eager growth since the last reviewed measurement
(commit `c75de9179`, 2026-10-18, 65,312 B measured under a 66,800 B baseline) to six specific
files — the sapience extension's entirely new `EXTENSION.md` (+2,065 B, a brand-new extension's
floor cost), `core/merge-sources/claudemd.md` (+734 B of genuinely new command rows and a
changed-mechanism rewrite), `lean/EXTENSION.md` (+387 B of bare pointer bullets), and small
stale-reference corrections in `literature`/`memory`/`nix` — and found no verbatim-duplicated
content left to relocate in any of them. Route (b) follows from that audit, matching the
2026-10-09 `/approve`-extension precedent recorded in the config's own `note`.

**Carried-figure re-validation (this planning dispatch, live, 2026-11-10)**:

| Claim | Source | Live re-check | Verdict |
|---|---|---|---|
| eager total 68,624 B; rules subtotal 30,689 B | dispatch `## Description` | `measure-eager-context.sh --check`: TOTAL 68,606 B, rules 30,671 B | **Stale by 18 B** — superseded; the report's own figure is the accurate one |
| eager total 68,606 B, 1,806 B over baseline | research report | TOTAL 68,606 B, `baseline_bytes` 66,800 | **Confirmed exactly** |
| current_eager 67,088 / baseline 66,100 | dispatch `## Description` (2026-10-16) | suite now reports current_eager 68,606 / baseline_bytes 66,800 | **Stale** — the dispatch's own re-measurement note already says so |
| suite fails 2 of 13 cases | dispatch + report | live: `11 passed, 2 failed` | **Confirmed** |
| `known-failures.txt` row at line 40, class `real-defect` | research report | `grep -n`: line 40, `real-defect` | **Confirmed** |
| baseline fixture failure is caused by the gate 20 overage | implied by both | the assertion is `baseline_rc -eq 0 && gate20_lines -le 1`; live verify-deploy FAILs **2 of 40** checks (gate20 **and** gate24) | **Incomplete** — see Risks; this is why the row is rewritten, not removed |
| `/ide` gate 24 findings are out of scope | research report | they are out of this task's *edit* scope (separately owned) but they are **not** out of its *verification* scope — they alone keep `baseline_rc=1` | **Corrected below** |
| gate 5 drift on `docs/guides/creating-extensions.md` | research report | did not reproduce in this dispatch's live suite run (not in the `--max-cost moderate` fixture battery) | **Not reproduced**; treated as absent, not relied on either way |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; ROADMAP.md was not
consulted and is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- Clear the Gate 20 sub-check B regression (`eager-load total over baseline`) by a reviewed,
  dated `eager_load.baseline_bytes` move derived from a **fresh** live measurement taken
  immediately before the edit.
- Append a dated justification entry to `eager_load.note`, recording the per-file attribution,
  the audit result (no redistributable duplication found), the before/after figures, and the
  resulting headroom — never a silent re-derivation.
- Leave `test-verify-deploy-context-budget.sh`'s `known-failures.txt` row truthful: rewritten to
  name the single residual cause and its owner, so `run-all.sh --fail-on-new` keeps reporting
  this suite as EXPECTED rather than NEW.

**Non-Goals**:
- Any route (a) trim-and-relocate. The research audit found no remaining duplicated content in
  the grown set; a second audit is not re-opened here.
- Editing the two `/ide` recommendation lines in
  `agent-system/extensions/memory/context/project/memory/memory-setup.md` and
  `memory-troubleshooting.md`. The built-in-command lint-exemption record explicitly rejected
  rewording as the fix, a separate record declares `agent-system/extensions/memory/context/` in
  its own `file_scope`, and a concurrent sibling this cycle declares
  `agent-system/extensions/memory/` at directory granularity.
- Changing `lint-dead-command-recommendations.sh`, its zero-tolerance no-allowlist policy, or
  `test-verify-deploy-context-budget.sh`'s own baseline assertion. All three belong to other
  records.
- Touching either per-file `ceiling_bytes` entry (`skills/skill-orchestrate/SKILL.md`,
  `commands/orchestrate.md`). Every precedent `note` entry scopes itself the same way.
- Any whole-tree redeploy (`deploy-headless.sh`). Two siblings are editing the source store this
  same cycle; regenerating the whole deployed tree would publish their in-flight edits.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A concurrent sibling grows the eager set between the fresh measurement and the commit. Sibling 499's declared scope includes `agent-system/extensions/sapience/EXTENSION.md` and `agent-system/extensions/memory/` (directory granularity) — **both eager-loaded** via their `merge_targets.claudemd.source` files | H | M | Re-measure immediately before the edit (Phase 1) and again at Phase 2 verification. If the total moved, re-derive once and amend the same dated `note` entry to state both figures — never leave a `baseline_bytes` that no measurement in the record supports |
| Rounding to the next 100 B leaves ~94 B of headroom — the same thin margin the 2026-10-18 entry recorded as "no durable headroom" before the gate re-fired | M | H | Follow the established convention anyway (do **not** over-round: a generous round masks a real future regression) and state the thin margin explicitly in the new `note` entry so the next reader sees it was a known, accepted consequence |
| A jq/python rewrite of the config reflows all 23 lines, burying a 3-value change in a whole-file diff | M | M | Use targeted `Edit` string replacements on the three literal values and the `note` string's tail. Do not pipe the file through jq or `json.dump` (see `context/patterns/jq-escaping-workarounds.md`'s reflow section) |
| An unescaped `"` in the appended `note` prose makes the config unparseable, silently breaking every Gate 20 run | H | L | Use backticks/single quotes in the appended prose; validate with `python3 -m json.tool` before declaring the phase green |
| The rewritten `known-failures.txt` row cites a bare task number, violating `no-task-references-in-deliverables.md` (the file's own header restates this prohibition) | M | M | Name the owner by durable mechanism anchor — the built-in-command exemption question for `lint-dead-command-recommendations.sh`'s zero-tolerance no-allowlist policy, and the two `/ide` sites by filename — never by task number |
| Removing the row (as the dispatch description instructs) while one case still fails would make `run-all.sh --fail-on-new` report this suite as a NEW failure | M | H | Deliberate, documented deviation: rewrite the row instead of removing it. Phase 2 states the condition under which a future dispatch may remove it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-measure and move the eager-load baseline with a dated note entry [COMPLETED]

**Goal**: `measure-eager-context.sh --check`'s fresh TOTAL sits at or under
`eager_load.baseline_bytes`, with the move justified by a dated entry appended to the config's
own `note` field.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/config/orchestrator-context-budget.json` from
      disk immediately before editing (sibling-concurrency discipline — a sibling may have
      touched it since this plan was written), and confirm `git status --short` shows it
      unmodified by anyone else. *(completed: git status --short showed it clean before editing)*
- [x] Take a fresh live measurement from the repo root:
      `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`.
      Record the `TOTAL: <N> B` figure and the four `SUBTOTAL` lines verbatim; this figure, not
      any figure carried in this plan or in the report, is what the edit is derived from.
      *(completed: TOTAL 68606 B; parent_chain 2982, claudemd 34953, at_import 0, rules 30671 —
      matches the planning-time figure exactly)*
- [x] Compute the new baseline: the fresh TOTAL rounded **up to the next 100 B** (the convention
      every prior `note` entry follows). Do not round further. *(completed: 68606 -> 68700)*
- [x] Edit `eager_load.baseline_bytes` (currently `66800`), `eager_load.measured_bytes`
      (currently `65312`, set to the fresh TOTAL), and `eager_load.measured_at` (currently
      `"2026-10-18"`, set to today's date) with three targeted `Edit` string replacements on
      lines 18-20. Do not rewrite the file through jq or a JSON dumper.
      *(completed: baseline_bytes=68700, measured_bytes=68606, measured_at=2026-11-10)*
- [x] Append a dated entry to the end of the `eager_load.note` string (line 21, immediately
      before its closing quote), in the voice and shape of the nine entries already there. It
      must state: the date; that this is a **route (b)** reviewed, dated baseline move, not a
      trim; the per-file attribution (the sapience extension's entirely new `EXTENSION.md` as a
      brand-new extension's floor cost, plus the `core`/`lean`/`literature`/`memory`/`nix`
      additions — new command rows, bare pointer bullets, and stale-reference corrections); that
      a full audit of the newly-grown content found no verbatim-duplicated content left to
      relocate, following the 2026-10-09 `/approve`-extension precedent; the before/after
      figures (prior baseline, fresh measured TOTAL, new baseline) and the resulting headroom;
      that the margin is thin and the gate is expected to re-fire on the next ordinary eager
      addition, which is its design intent; and that both per-file `ceiling_bytes` entries
      remain unmoved, this move being scoped to `eager_load` only. Use backticks or single
      quotes — never a `"` — inside the appended prose. *(completed: tenth note entry dated
      2026-11-10 appended, using backticks only)*
- [x] Validate the file parses: `python3 -m json.tool <path> >/dev/null` (or
      `jq -e . <path> >/dev/null`), and confirm
      `jq -r '.eager_load.baseline_bytes' <path>` reads back the intended integer.
      *(completed: python3 -m json.tool OK; jq readback = 68700)*
- [x] Do **not** copy the edited config into the deployed `.claude/` tree and do not redeploy.
      Gate 20 resolves this config at
      `$TARGET/agent-system/extensions/core/context/config/orchestrator-context-budget.json`
      (`verify-deploy.sh:1777`) — the source store, never the deployed copy — so the source edit
      alone is what every gate and every measurement in this plan reads. The deployed copy goes
      stale until the next ordinary deploy, which is this repo's normal steady state.
      *(completed: deployed .claude/ copy left untouched; no redeploy run)*
- [x] Commit this green sub-step, staging the single source config path explicitly. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: the fresh TOTAL is expected to read 68,606 B (confirmed live during this
planning dispatch), making the new baseline 68,700 B with ~94 B of headroom — but this is a
hypothesis, not a fact: the dispatch's own figure was already 18 B stale, and two siblings with
eager-loaded files in their declared scopes are active this cycle. Confirm by reading the fresh
`TOTAL:` line in this phase's own measurement output and deriving the rounding from that number
alone; if it differs, the derived baseline and the `note` entry's figures change with it.

**Tier Justification**: `suite_selection_select` over this phase's only tracked path
(`agent-system/extensions/core/context/config/orchestrator-context-budget.json`) returns exactly
`test-verify-deploy-context-budget.sh`, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
is the cheapest check that covers this edit.

**Files to modify**:
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - `eager_load.baseline_bytes` moved to the freshly-measured TOTAL rounded up to the next 100 B; `measured_bytes`/`measured_at` refreshed; a dated route-(b) justification entry appended to `note`

**Verification**:
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  reports a TOTAL at or under the new `baseline_bytes`, and `Volatile-file hits: 0` /
  `CHECK PASSED`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
  no longer emits
  `[FAIL] could not compute a safe eager-load pad amount`; the three `case5:` pad assertions
  (`exactly one [FAIL] line for eager-load total`, `exactly one FINDING gate20 line for
  eager-load-over-baseline`, `eager-load-over-baseline finding text is digit-free`) now run and
  pass, since the pad block is only reached when `current_eager -le baseline_bytes`.
- The suite's `[FAIL] baseline fixture is not clean` line is **expected to persist** at this
  phase, with its detail reduced from two findings to one (`FINDING gate24 ... /ide has no
  definition file`, twice) and the `FINDING gate20 ... eager-load total over baseline` line gone.
  Observing that reduction — not a fully green suite — is this phase's pass condition for that
  case; Phase 2 records it.
- `python3 -m json.tool` parses the edited config; `diff` shows the deployed copy identical.

---

### Phase 2: Re-attribute the known-failures row and run the full gate set [NOT STARTED]

**Goal**: `known-failures.txt`'s row for this suite states the single real residual cause and a
durable owner anchor, and the complete gate set introduces no finding beyond the pre-existing,
separately-owned set.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/known-failures.txt` from disk
      (sibling-concurrency discipline) and locate the `test-verify-deploy-context-budget.sh` row.
      Expected at line 40; if the line number moved, operate on the row matched by basename, not
      by line number.
- [ ] Rewrite that row's `reason` and `owner` fields in place, keeping the basename and the
      `real-defect` category. The new `reason` must state: the eager-load/baseline case is fixed
      (naming the new baseline and the date of the move, pointing at
      `orchestrator-context-budget.json`'s own `eager_load.note` entry as the record); the single
      remaining failing case is the baseline-fixture-clean assertion, which requires `rc -eq 0`
      from a full `--max-cost moderate` verify-deploy run and therefore cannot pass while gate 24
      reports the two `/ide` recommendation findings in
      `agent-system/extensions/memory/context/project/memory/memory-setup.md` and
      `memory-troubleshooting.md`; and that those two lines are correct as written and are owned
      elsewhere. The `owner` must be a durable anchor — the built-in-command exemption question
      for `lint-dead-command-recommendations.sh`'s zero-tolerance no-allowlist policy — with **no
      task number anywhere in the row** (the file's own header at lines 12-16 restates that
      prohibition and `no-task-references-in-deliverables.md` governs it, this file living under
      `agent-system/extensions/**`).
- [ ] State in the row (or keep it implicit only if the row would otherwise exceed its
      neighbours' length) the removal condition: this row becomes removable once gate 24 reports
      no finding against the fixture, at which point the suite reaches `rc -eq 0` and goes fully
      green with no further change to the budget config.
- [ ] Do **not** copy the edited row into the deployed `.claude/scripts/tests/known-failures.txt`
      and do not redeploy. The manifest is matched by suite basename, so a deployed-mode
      `run-all.sh` keeps annotating this suite as EXPECTED from the stale copy; only the row's
      prose is briefly out of date, until the next ordinary deploy.
- [ ] Run the complete gate set and compare against the pre-existing finding set recorded below,
      not against an absolute zero.
- [ ] Commit this green sub-step with an explicit file list.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: three located claims, each verified live during planning and each requiring
re-confirmation at implementation time rather than trust: (1) the
`test-verify-deploy-context-budget.sh` row sits at `known-failures.txt` line 40 with category
`real-defect` — confirm by `grep -n test-verify-deploy-context-budget
agent-system/extensions/core/scripts/tests/known-failures.txt` and operate on the matched row,
never on a hard-coded line number; (2) `suite_selection_select` returns exactly five covering
suites for this plan's two tracked paths — confirm by re-running it over both paths and matching
the `--only` list verbatim; (3) the pre-existing finding set is exactly the two gate 24 `/ide`
lines — confirm from this phase's own full gate run, and if a third pre-existing finding appears
that is demonstrably not attributable to this task's two edits, record it in the phase evidence
and in the issue log rather than silently widening the accepted baseline.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - the `test-verify-deploy-context-budget.sh` row's `reason` and `owner` rewritten to re-attribute the residual failure to the cross-owned gate 24 `/ide` findings; category stays `real-defect`; row not removed

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh,test-gate8-expected-new-distinction.sh,test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh`
  — the five suites `suite_selection_select` returns for this plan's two tracked paths. The four
  `known-failures.txt` consumers must be green; `test-verify-deploy-context-budget.sh` must show
  the single documented residual failure (the baseline-fixture-clean case) and no other.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings` (the complete gate set,
  no `--skip-slow`, no `--only-gate`), read **baseline-relative**: the
  `FINDING gate20 orchestrator context budget: eager-load total over baseline` line must be gone,
  and no finding may appear that is not in the pre-existing set measured live during planning:
  the two `FINDING gate24 ... /ide has no definition file` lines
  (`memory-setup.md:93`, `memory-troubleshooting.md:34`). Any other new finding — including a
  gate 5 content-differs-from-source line naming either file this plan edits — is this task's own
  regression and must be resolved before the phase closes. The run's own exit status will remain
  non-zero for as long as gate 24 reports those two findings; that non-zero status is therefore
  the expected, pre-existing outcome here rather than a pass signal to be waited for, and the
  pass condition is the finding-set comparison above plus the confirmed absence of the gate 20
  line. Capture the exit status explicitly (`rc=$?`) and record it in the phase's evidence rather
  than discarding it.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
  re-run one final time: TOTAL still at or under `baseline_bytes`. If a sibling landed eager
  growth during this task, re-derive once per Phase 1's final task and amend the same `note`
  entry rather than leaving an unsupported figure.
- `bash .claude/scripts/validate-artifact.sh specs/423_fix_verify_deploy_context_budget_byte_count_drift/plans/01_eager-baseline-move-and-row-rewrite.md plan`
  passes (plan-format compliance for this artifact).

---

## Testing & Validation

- [ ] Fresh `measure-eager-context.sh --check` TOTAL at or under the new `baseline_bytes`, with
      `CHECK PASSED` and zero volatile-file hits.
- [ ] `orchestrator-context-budget.json` parses as JSON and `eager_load.baseline_bytes` reads
      back the intended integer.
- [ ] The new `eager_load.note` entry is dated, states route (b), names the per-file attribution,
      gives before/after figures from the implementation-time measurement, and acknowledges the
      thin resulting headroom.
- [ ] `test-verify-deploy-context-budget.sh`'s pad-amount case is green and its three `case5:`
      pad assertions now run.
- [ ] The four `known-failures.txt`-covering suites are green after the row rewrite.
- [ ] The full gate set introduces no finding beyond the two pre-existing gate 24 `/ide` lines.
- [ ] No bare task number appears in either edited `agent-system/**` file.

## Artifacts & Outputs

- Edited `agent-system/extensions/core/context/config/orchestrator-context-budget.json`
  (`eager_load` only).
- Edited `agent-system/extensions/core/scripts/tests/known-failures.txt` (one row's `reason` and
  `owner`).
- No deployed-tree (`.claude/**`) change and no redeploy: Gate 20 reads the source store
  directly, so none is needed.
- An implementation summary recording the implementation-time measured TOTAL, the derived
  baseline, and the residual gate 24 dependency.

## Rollback/Contingency

Both edits are small, text-local, and fully captured in two commits. To revert: `git revert` the
phase commits, or restore the two files from `HEAD` (`git checkout <sha> -- <paths>`). No
generated artifact, no deployed-tree change, and no schema migration is involved, so there is
nothing else to undo.

If the fresh measurement at implementation time shows the TOTAL already **at or under** the
current 66,800 B baseline (a sibling having trimmed the eager set first), the baseline move is
unnecessary: skip the `baseline_bytes` change, refresh `measured_bytes`/`measured_at` only, record
in the `note` that the overage resolved without a move, and proceed to Phase 2 unchanged.

If a sibling's in-flight edit makes the full gate run in Phase 2 unreadable (findings churning
between runs against files outside this task's `file_scope`), stop and report rather than
chasing them — per this dispatch's Territory block and
`context/patterns/dispatch-report-not-termination.md`.
