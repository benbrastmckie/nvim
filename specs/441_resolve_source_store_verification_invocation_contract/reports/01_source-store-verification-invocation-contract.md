# Research Report: Task #441

**Task**: 441 - Resolve source-store verification invocation contract
**Started**: 2026-10-17T00:00:00Z
**Completed**: 2026-10-17T00:00:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration (`agent-system/extensions/core/scripts/verify-deploy.sh`,
  `check-extension-docs.sh`, `sync-manifest-scripts.sh`, `deploy-root-guard.sh`,
  `generate-context-line-counts.sh`, `validate-context-index.sh`, `measure-eager-context.sh`)
- Direct empirical reproduction (ran all three named scripts from both the source-store path and
  the deployed `.claude/scripts/` path, including a full `verify-deploy.sh --skip-slow` pass,
  and diffed the outputs)
- The originating task's own artifacts (`specs/434_lint_and_fix_actionable_dead_command_references/progress/phase-3-progress.json`,
  `.../plans/01_lint-dead-command-recommendations.md`, `.../issues.jsonl`)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The refusal is real, but only for **two** of the three named scripts
  (`check-extension-docs.sh`, `sync-manifest-scripts.sh`); `verify-deploy.sh` runs correctly and
  byte-identically whether invoked from the source-store path or the deployed copy, confirmed by
  direct empirical reproduction (including a full `--skip-slow` run, diffed with zero
  differences). It was swept into the defect description because task 434's phase-3 verification
  *line* named all three scripts together as one bundle, not because `verify-deploy.sh` itself
  carries the guard.
- The refusal in the two affected scripts is **not load-bearing for correctness** — it is
  load-bearing only for diagnostic clarity. Empirically: (1) passing the correct repo root
  explicitly (`REPO_ROOT=$(pwd)` from the source-store directory) produces output byte-identical
  to the deployed-copy invocation; (2) even with a *wrong* root and the guard bypassed, the
  script's own `EXT_DIR` existence check still fails loudly (no silent false pass) — it just
  names a confusing nested path instead of explaining the real cause.
- The intended contract is **already option (a)** by the scripts' own design comments, just not
  realized by default: both scripts' headers explicitly document `REPO_ROOT=$(pwd) bash
  agent-system/extensions/core/scripts/<script>.sh` as "the" deliberate source-store invocation,
  and `check-extension-docs.sh`'s own repair-hint text already tells callers to run
  `sync-manifest-scripts.sh --write` "from the source store" — a command that currently fails
  without the undocumented environment-variable override.
- Recommendation: resolution (a) — make the default root resolution self-correcting (so no
  override or redeploy detour is needed), scoped to only the affected scripts, leaving
  `deploy-root-guard.sh`'s existing behavior for its ~115+ other callers completely unchanged.

## Context & Scope

Task 434 (phase 3) ran a verification line naming `verify-deploy.sh`, `check-extension-docs.sh`,
and `sync-manifest-scripts.sh` together, from the source-store path
(`agent-system/extensions/core/scripts/`), per that task's plan text. Two of the three refused
and the agent re-ran from `.claude/scripts/` instead, logging this as `issue` entry
`iss_1792247550805_oiTVgB` (class `gate/env`, severity `minor`). This task's job: determine
whether the refusal protects a real invariant, and converge the invocation contract on a
documented, single answer.

Scope is explicitly the three named scripts (plus whatever the research step surfaces as
directly relevant); no code changes happen in this research phase — findings below are to drive
the plan phase.

## Findings

### 1. `verify-deploy.sh` does not carry the refusal at all

`verify-deploy.sh` resolves its own `TARGET` from an explicit CLI argument or `$(pwd)` (line
456: `TARGET="${TARGET:-$(pwd)}"`), never from its own `BASH_SOURCE` location. It does not source
`deploy-root-guard.sh` (confirmed by `grep`; the two hits in the file are comments explaining
*why* a different gate, `validate-state.sh`, is deliberately invoked via its deployed copy — not
a dependency of `verify-deploy.sh` itself). Internally, every gate that shells out to a
source-store-conditioned script (gate 3 → `check-extension-docs.sh`, gate 4 →
`check-task-references.sh`) always invokes the **deployed** copy
(`$CLAUDE_DIR/scripts/<name>.sh`) explicitly, by design — this is correct, since
`verify-deploy.sh`'s entire purpose is checking that the deploy tree matches the source store.

Empirical confirmation: ran `bash agent-system/extensions/core/scripts/verify-deploy.sh
--only-gate 1 --quiet` and the deployed equivalent — identical `PASS` output, identical corpus
counts. Ran a full `bash ... verify-deploy.sh --skip-slow --quiet` from both paths and `diff`'d
the captured logs — zero differences, both exit 0.

Ground truth from task 434's own phase-3 progress record corroborates this precisely:
> "check-extension-docs.sh and sync-manifest-scripts.sh **both** refuse to run from the source
> store (their root-relative '../..' resolution assumes a deployed tree) and print an explicit
> error directing to run the deployed .claude/scripts/ copy instead."
(`specs/434_lint_and_fix_actionable_dead_command_references/progress/phase-3-progress.json:30`,
emphasis added — the record names exactly two scripts, not three.)

**Conclusion**: `verify-deploy.sh` needs no change. It was named in the dispatch because it
appeared in the same verification *line* as the other two in task 434's plan, not because it
shares the defect.

### 2. The guard mechanism and why it fires

`check-extension-docs.sh` and `sync-manifest-scripts.sh` both resolve their repo root as
`"$(dirname "${BASH_SOURCE[0]}")/../.."`, an expression that is correct only two directories
under the repo root (`.claude/scripts/` or `.opencode/scripts/`). From the source store
(`agent-system/extensions/core/scripts/`, four directories deep), the same expression silently
resolves to `agent-system/extensions/` instead of the repo root. `deploy-root-guard.sh`
(`agent-system/extensions/core/scripts/deploy-root-guard.sh`) exists specifically to turn that
wrong computation into a loud, explicit failure rather than letting the script proceed against a
bogus root — its own header states the rejected alternative explicitly: "Deliberately NOT `git
rev-parse --show-toplevel`, which would silently succeed by finding the true repo root and mask
the invocation error."

Both scripts already carry a documented, working bypass (both have a header comment reading,
verbatim, "Same REPO_ROOT-bypass pattern ... the deploy-root-guard only fires when REPO_ROOT is
unset, so a deliberate source-store invocation (`REPO_ROOT=$(pwd) bash
agent-system/extensions/core/scripts/<script>.sh`) works without tripping the guard" —
`check-extension-docs.sh:104-109`, `sync-manifest-scripts.sh:59-63`). This bypass is a
*documented design feature*, not an accident.

### 3. The guard is not load-bearing for correctness in these two scripts

Direct reproduction, from the source-store directory, with and without the override:

- `bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet` (no override) →
  refuses with the deploy-root-guard message, exit 1.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh --quiet`
  → runs to completion, exit 0, output byte-identical to `bash .claude/scripts/check-extension-docs.sh
  --quiet` (same advisory, same 23-extension PASS summary).
- Same pair of results for `sync-manifest-scripts.sh --check`.

Separately, simulating what would happen if the guard did not exist and the bad default root
were used anyway (`REPO_ROOT=.../agent-system/extensions bash check-extension-docs.sh`): the
script still fails loudly (`ERROR: .../agent-system/extensions/agent-system/extensions does not
exist`, exit 1) — it does **not** silently produce a false "PASS". The guard's real value here
is a *clearer* error message pointing at the actual cause, not preventing an otherwise-silent
wrong result. Per the dispatch's own instruction ("Do not remove a guard that is load-bearing
merely to make the ergonomics nicer; if it is load-bearing, (b) is the answer") — here the guard
is not load-bearing for correctness, so (a) is the evidence-backed answer, not (b).

### 4. The scripts' own repair-hint text already assumes (a)

`check-extension-docs.sh`'s Rule Q repair hint (line 616) reads: `"-> repair: bash
scripts/sync-manifest-scripts.sh --write (from the source store; see that script's header)"` —
the tool's own self-generated remedy text already tells the caller to invoke the sibling script
"from the source store" directly, with no mention of the `REPO_ROOT=$(pwd)` incantation actually
required to make that invocation succeed. This is strong evidence the intended contract was
*already* "runs from the source store", not "must redeploy first" — the implementation simply
never followed through on its own stated intent at the point where it matters (the refusal
message itself).

### 5. The write side was already correct and was never the problem

`sync-manifest-scripts.sh` always reads and (`--write` mode) rewrites only the source-store
`agent-system/extensions/<ext>/manifest.json` files, by explicit design
(`sync-manifest-scripts.sh:24-27`, "WHY THE SOURCE STORE, NEVER THE DEPLOYED MANIFEST"). This is
correct per `rules/source-store-deploy-boundary.md` and is not part of the defect — the
split-brain is entirely on the *invocation* side (default execution pinned to the deploy path by
a path-arithmetic shortfall), not the write-target side (already correctly pinned to the source
store).

### 6. Three further scripts share the identical, undocumented-in-error-message pattern

`grep -rl "REPO_ROOT-bypass pattern" agent-system/extensions/core/scripts/` surfaces three more
scripts carrying the exact same sentence structure referencing `check-extension-docs.sh` as the
canonical precedent: `validate-context-index.sh`, `measure-eager-context.sh`, and
`generate-context-line-counts.sh`. Task 434 itself hit `generate-context-line-counts.sh --write`
too (confirmed by its plan: "...corrected `core/index-entries.json`'s `command-output.md`
`line_count` via `generate-context-line-counts.sh --write` (both run against the deployed
`.claude/` copy per their own root-requirement, writing back to the source store)" —
`specs/434.../plans/01_lint-dead-command-recommendations.md:299-302`). This task's dispatch scope
names only `check-extension-docs.sh` and `sync-manifest-scripts.sh` (plus the unaffected
`verify-deploy.sh`); the other three sharing the pattern are a related but out-of-scope
consistency gap for a future task to consider, not something this task's scope requires fixing.

## Decisions

- **`verify-deploy.sh` requires no change.** It does not carry the refusal; it was named in the
  dispatch only because it shared a verification line with the two scripts that do. The plan
  should document this explicitly (so a future reader does not re-litigate it) rather than
  modify the script.
- **The refusal in `check-extension-docs.sh` and `sync-manifest-scripts.sh` is incidental, not
  load-bearing**, per the empirical evidence in Finding 3. Resolution (a) — let them run from the
  source-store path by default — is the dispatch's "preferred" option and is the one the
  evidence supports.
- **The fix should be scoped to the two affected scripts only**, not to `deploy-root-guard.sh`
  itself, since that shared library is sourced by ~115+ other scripts whose own invariants were
  not examined by this research pass and must not be assumed to share the same "not load-bearing"
  conclusion.

## Recommendations

1. Give `check-extension-docs.sh` and `sync-manifest-scripts.sh` a self-correcting default root
   resolution instead of the current unconditional `../..` arithmetic, so that **no** manual
   override and **no** redeploy-then-invoke-elsewhere detour is required. A concrete, minimal
   shape: before falling through to the existing `deploy-root-guard.sh` sourcing line, attempt
   `git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel` and use that as
   `REPO_ROOT` if it succeeds; only fall back to today's path-arithmetic-plus-guard behavior if
   that call fails (e.g. a non-git checkout) — preserving the existing fail-loud safety net for
   that one edge case `deploy-root-guard.sh`'s own header worried about (masking a genuine
   invocation error), while fixing the common case. This can be a small, additive helper (e.g. a
   new function in `deploy-root-guard.sh`, called only by the two in-scope scripts) rather than a
   change to the guard's existing behavior for its other callers.
2. Once the self-correcting resolution lands, update the two header comments currently describing
   the `REPO_ROOT=$(pwd)` bypass (`check-extension-docs.sh:104-109`,
   `sync-manifest-scripts.sh:59-63`) to describe the new default behavior instead, and update the
   repair-hint text at `check-extension-docs.sh:616` to no longer imply an undocumented
   prerequisite.
3. Add a one-line note to `verify-deploy.sh`'s own header or to the three scripts' relationship
   documentation stating plainly that `verify-deploy.sh` is unaffected by this contract and
   intentionally always targets the deployed copies of its sub-checks — closing the loop so a
   future reader does not re-discover Finding 1 from scratch.
4. Leave `validate-context-index.sh`, `measure-eager-context.sh`, and
   `generate-context-line-counts.sh` untouched for this task; note them in the plan as a related,
   explicitly out-of-scope consistency gap suitable for a follow-up task once (if) the chosen
   pattern from recommendation 1 proves out on the two in-scope scripts.
5. Per the dispatch's blanket constraint, any new or edited file under `agent-system/**` produced
   by the plan/implementation phases must avoid task-number references and record-versioning
   language (e.g. no "this used to require REPO_ROOT=$(pwd)" framing — state the current,
   self-correcting behavior only).

## Risks & Mitigations

- **Risk**: `git rev-parse --show-toplevel` could resolve to an unexpected root in an unusual
  checkout layout (e.g. the nvim config repo nested inside another git repo, or a submodule).
  *Mitigation*: scope the change to only the two named scripts (not the shared
  `deploy-root-guard.sh` used by ~115+ other callers), and keep today's existing guard as the
  fallback path when the git call fails or returns something that doesn't contain an
  `agent-system/extensions` directory — matching the "deploy consumer" skip precedent
  `verify-deploy.sh`'s own gates already use elsewhere.
- **Risk**: scope creep into the three sibling scripts sharing the same pattern (Finding 6).
  *Mitigation*: Recommendation 4 explicitly defers them to a follow-up task; the plan should not
  fold them in without a separate, deliberate scope decision.

## Context Extension Recommendations

- **Topic**: REPO_ROOT resolution patterns across `agent-system/extensions/core/scripts/`.
- **Gap**: there is no single context file documenting which of the ~120 `deploy-root-guard.sh`
  callers structurally require deploy-time-generated state versus which (like the two in this
  task) only need to locate two parallel source/deploy trees that already coexist in the same
  repo. This research pass had to re-derive that distinction empirically per-script.
- **Recommendation**: once this task's fix lands, consider a short addition to
  `context/patterns/regeneration-is-manual-only.md` (which already documents the
  "Redeploy-Remedy Emission Sites" and root-resolution guard obligations) naming the
  self-correcting-root pattern as the preferred shape for any *new* script in this category,
  rather than defaulting to the plain guard.

## Appendix

- Search/verification commands used:
  - `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 1 --quiet` vs. the
    deployed equivalent
  - `bash .../verify-deploy.sh --skip-slow --quiet` (both paths) + `diff` on captured logs
  - `bash .../check-extension-docs.sh --quiet` (no override, fails) vs.
    `REPO_ROOT=$(pwd) bash .../check-extension-docs.sh --quiet` (succeeds, matches deployed output)
  - `bash .../sync-manifest-scripts.sh --check` (no override, fails) vs.
    `REPO_ROOT=$(pwd) bash .../sync-manifest-scripts.sh --check` (succeeds, matches deployed output)
  - `REPO_ROOT=<wrong-root> bash .../check-extension-docs.sh --quiet` (simulates "no guard"
    scenario — confirms a loud, non-silent failure either way)
  - `grep -rln "REPO_ROOT-bypass pattern" agent-system/extensions/core/scripts/`
  - `grep -rl "deploy-root-guard.sh" agent-system/extensions/core/scripts/` (blast-radius check,
    ~120 hits)
- Key files read: `agent-system/extensions/core/scripts/deploy-root-guard.sh` (full),
  `check-extension-docs.sh` (header + Rule Q region), `sync-manifest-scripts.sh` (header),
  `verify-deploy.sh` (header, gates 3/4, TARGET resolution, `deploy-root-guard` comment mentions),
  `specs/434_lint_and_fix_actionable_dead_command_references/progress/phase-3-progress.json`,
  `specs/434_lint_and_fix_actionable_dead_command_references/plans/01_lint-dead-command-recommendations.md`,
  `specs/434_lint_and_fix_actionable_dead_command_references/issues.jsonl`.
