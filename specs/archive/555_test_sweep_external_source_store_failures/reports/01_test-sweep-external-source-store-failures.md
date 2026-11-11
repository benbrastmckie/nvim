# Research Report: Test Sweep External Source Store Failures

**Task**: 555 - Test sweep external source store failures
**Started**: 2026-11-10
**Completed**: 2026-11-10
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/**`), live `run-all.sh` executions in both the nvim repository and an external consumer repository, `known-failures.txt`, `.claude-extensions.json`, the `state_counter_archive_numbering_reconciliation` record (read for its masking-of-new-findings argument)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- The 24/26/156 figures in the dispatch description are stale. Re-running `run-all.sh` with no
  filter in the actual repro environment (a consumer repository whose `.claude-extensions.json`
  resolves the `core` extension to an external `source_dir`) now shows **37 of 174 suites
  failing (2 EXPECTED baseline, 35 NEW)** — both the total suite count and the failure count have
  grown since the original measurement.
- Of the originally-named 8 suites, only **6 are actually caused by the external-source-store
  condition**: `test-askuserquestion-rehome.sh`, `test-deploy-propagation.sh`,
  `test-routing-resolution.sh`, `test-update-task-status.sh`,
  `test-lint-dead-command-recommendations.sh`, `test-manifest-scripts-sync.sh`. Each fails with an
  environment error or an explicit "`agent-system/extensions` does not exist" / "enumeration
  yielded an empty set" message, traced to a hardcoded `$REPO_ROOT/agent-system/extensions/...`
  path with no fallback.
- The other 2 named suites, `test-gate-cache-lib.sh` and `test-orchestrate-build-aux-dispatch.sh`,
  are **misattributed**: they fail identically (same case numbers, same messages) in the nvim
  repository, which has a local `agent-system/` tree. Their failure is unrelated to source-store
  topology.
- The remaining ~29 NEW failures in the consumer repo (10 of which reproduce identically in nvim)
  form a separate, currently-live regression cluster around deploy/gate/orchestrate-postflight
  machinery. This is out of scope for this task and should not be folded into its fix.
- A mechanism to resolve the real source-store directory from a consumer repo already exists and
  is proven to work both ways (self-referentially in nvim and externally in the consumer repo):
  `jq -r '.extensions.core.source_dir' .claude-extensions.json`. A sibling helper,
  `deploy-freshness-lib.sh`'s `_deploy_freshness_status_one`, already reads exactly this key via
  `jq` and falls open (never hard-fails) when it is absent or the directory does not exist.
  Recommendation: extend the 6 confirmed suites (and the `lint-dead-command-recommendations.sh`
  script one of them exercises) to resolve `agent-system/extensions` through this same
  indirection before falling back to today's bare `$REPO_ROOT/agent-system/extensions` guess,
  rather than adding them to `known-failures.txt`.

## Context & Scope

The task asks for an independent re-derivation of a prior measurement (run-all.sh: 26 of 156
suites failing, 2 of which are the repo's own known-failures baseline) and a design-space
evaluation for the remaining cause: a repository whose `core` extension's source store is
resolved externally via `.claude-extensions.json` rather than present locally under
`agent-system/extensions/`.

This repository (where the fix must land, per the source-store/deploy-boundary rule) is itself
both the canonical source-store owner for the `core` extension AND, via its own
`.claude-extensions.json`, a consumer that resolves `core`'s `source_dir` to itself
(`/home/benjamin/.config/nvim/agent-system/extensions/core`). It therefore cannot reproduce the
external-source-store symptom locally: `agent-system/extensions/` exists here with full content
and deep git history. Reproducing and counting the actual symptom required running the same
test suites in a second, external repository whose own `.claude-extensions.json` resolves the
`core` extension's `source_dir` to this same nvim path but which itself has no local
`agent-system/` directory — exactly the shape described by the dispatch. Both repositories were
used read-only: no file in the external repository was modified by this research.

## Findings

### Independently re-derived counts

**In the external consumer repository** (the true repro environment): `run-all.sh --jobs auto`
with no filter discovers **174** suites, of which **137 pass** and **37 fail** (2 against the
`known-failures.txt` baseline, 35 newly red). This is a materially different count from the
26/156 figures originally cited
on both axes — the total suite count has grown (more suites exist now than at the original
measurement) and the failure count has grown even faster.

**In this repository** (nvim, local-source-store case): the same sweep discovers **175** suites,
of which **162 pass** and **13 fail** (2 against the baseline, 11 newly red). None of the 6
confirmed external-source-store suites (see below) appear in this list — they pass here, as
expected, since the condition they depend on (`agent-system/extensions` existing under the git
toplevel) is true in this repository.

### The confirmed external-source-store cause (6 suites, not 8)

Each of the following fails in the external consumer repo with an explicit, diagnosable
environment error, and passes in this repository:

| Suite | Failure mode in the consumer repo | Root hardcoded path |
|---|---|---|
| `test-askuserquestion-rehome.sh` | exit 2, "required file not found" | `STANDARD_PATH`/`TEMPLATE_PATH`/`LINT_PATH`/`SKILL_META_PATH`/`INTERVIEW_PATH`/`SKILL_SPAWN_PATH`/`SKILL_FIXIT_PATH`, each built as `$REPO_ROOT/agent-system/extensions/core/...` with no deployed-tree or source_dir fallback — unlike this same file's own `AGENT_FILES` scan, which already falls back to `$REPO_ROOT/.claude/agents/*.md` |
| `test-deploy-propagation.sh` | exit 2, "core manifest not found" | `MANIFEST="$REPO_ROOT/agent-system/extensions/core/manifest.json"`, no fallback (this suite genuinely needs the PRE-deploy manifest as ground truth to verify the deploy step, so a deployed-tree fallback would be circular; it needs `source_dir` indirection specifically) |
| `test-routing-resolution.sh` | exit 2, "expected file not found" | hardcoded lookup of `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` |
| `test-update-task-status.sh` | exit 2, "source-store override file missing" | hardcoded lookup of `agent-system/extensions/core/scripts/update-task-status.sh` |
| `test-lint-dead-command-recommendations.sh` | exit 1, 6 of 12 assertions fail; the lint script itself prints "valid-command enumeration yielded an empty set under `.../agent-system/extensions`" | the defect is in the SCRIPT UNDER TEST, `lint-dead-command-recommendations.sh`, not only its test — the enumeration root is hardcoded to `agent-system/extensions` |
| `test-manifest-scripts-sync.sh` | exit 1, 18 of 19 assertions pass; the one failure is exactly the no-`REPO_ROOT`-override assertion, with output "`ERROR: .../agent-system/extensions does not exist`" | `sync-manifest-scripts.sh`'s `EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"` default |

These numbers match the dispatch description's own count for `test-manifest-scripts-sync.sh`
(18 of 19 pass) exactly, and the general shape for the other 5 (exit 2 environment errors from a
hardcoded path), confirming that part of the description is accurate.

**The shared choke point**: every one of these suites or the script it tests resolves
`REPO_ROOT` via `common_test_repo_root` (depth-independent `git rev-parse --show-toplevel`),
which correctly returns the consumer repo's own toplevel — then assumes
`$REPO_ROOT/agent-system/extensions` exists under it. `deploy-root-guard.sh`'s opt-in
self-correction path (used by `sync-manifest-scripts.sh` and others) makes this assumption
explicit: it accepts a `git rev-parse --show-toplevel` candidate as `REPO_ROOT` **only when
`agent-system/extensions` exists directly under it** — by design, so that it can distinguish a
genuine invocation error from a legitimate source-store run. In a repo whose source store is
external, this acceptance test can never pass, so the guard always falls through to its refusal
message, and every script layered on the same assumption fails the same way.

### The two misattributed suites

`test-gate-cache-lib.sh` (4 of 28 cases fail: case9, case10, case11, case15 — "implementation
digest was not deterministic or was a sentinel", "registry-row edit did not change the
implementation digest", "a scripts/lib/ perturbation did not change the implementation digest",
"composite key was not deterministic") and `test-orchestrate-build-aux-dispatch.sh` (1 of 22
cases fails: "plan-revision's model did not resolve to opus (got: )") were named among the
dispatch's "confirmed directly" set of 7. Both were re-run directly in this repository, which has
a local `agent-system/` tree — and both fail with the exact same case numbers and the exact same
messages here as in the consumer repo. A suite whose failure is caused by a missing
`agent-system/extensions` directory cannot fail identically in a repository where that directory
is present; this is a machine-checked refutation of their inclusion in "the remaining 24 all
trace to ONE cause." They belong to the separate regression cluster below instead.

### A separate, larger, out-of-scope regression cluster

Beyond the 6 confirmed suites, the consumer repo's 37 failures include ~29 more that were not
named in the dispatch description at all. Ten of these reproduce byte-for-byte in this
repository too (`test-deploy-baseline-lib.sh`, `test-double-loading-check.sh`,
`test-gate-cache-lib.sh`, `test-gate-registry-resolution.sh`,
`test-lint-unit-integration-boundary.sh`, `test-orchestrate-build-aux-dispatch.sh`,
`test-orchestrate-cycle-postflight.sh`, `test-orchestrate-predispatch-review.sh`,
`test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`), clustering around
deploy/gate/orchestrate-postflight machinery. Since this repository has a local source store, the
cause cannot be source-store topology; something else is currently red across both repositories.
This cluster is a separate concern from the external-source-store cause this task names, and
folding it into this task's fix would both overrun the task's declared scope and conflate two
unrelated defect classes in one commit. It is recorded in this task's issue log and is a
candidate for its own follow-up task.

### An existing reusable resolution mechanism

`agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh`'s internal
`_deploy_freshness_status_one` function already reads
`jq -r --arg n "$name" '.extensions[$n].source_dir // empty' .claude-extensions.json`, checks
`[ -d "$source_dir" ]`, and falls open (never hard-fails) on any miss. This is proven to resolve
correctly in both directions already: in this repository it resolves `core`'s `source_dir` to
itself; in the consumer repo it resolves to this same nvim path. No new indirection mechanism is
needed — the existing `.claude-extensions.json` `source_dir` key, read the same way this library
already reads it, is sufficient ground truth for every one of the 6 confirmed suites, including
`test-deploy-propagation.sh`, which specifically needs genuine pre-deploy source content (a
deployed-tree fallback would be circular for that one suite, since it exists to verify the deploy
step itself).

### Why this matters (pointer, not re-derivation)

The same masking pathology — a permanently-red sweep whose exit code cannot discriminate a
genuinely new failure from a standing, expected one — is the argument already made for
`validate-state.sh` in the existing `state_counter_archive_numbering_reconciliation` record. That
argument is not re-derived here; see that record for the full reasoning. The evidence in this
report (167 total/137 passed/37 failed in the consumer repo, with the exit code unable to tell a
reader that 29 of those 37 are neither the known baseline nor the named external-source-store
cause) is a fresh, concrete instance of exactly that pathology, independent of its prior
statement.

## Decisions

- Treat only the 6 confirmed suites as this task's remediation target. The 2 misattributed
  suites and the ~29-strong unrelated cluster are explicitly out of scope and should not be
  touched under this task's fix.
- Favor design option (a) (teach the suites to resolve the source store) over (b) (recognized
  SKIP) or (c) (extend `known-failures.txt`) for all 6 confirmed suites, since a working
  resolution mechanism (`.claude-extensions.json`'s `source_dir`, already read the same way by
  `deploy-freshness-lib.sh`) exists and is proven to resolve correctly in both topologies tested.
  Option (c) was rejected specifically because `known-failures.txt` is repo-wide and
  mode-insensitive (`basename`, not a full path, "since discovery paths differ between
  source-store and deployed mode") — marking these 6 suites "known-failing" there would also
  silence them in this repository, where they currently pass and must keep passing as a real
  regression signal.
- Option (b) (SKIP with a reason) remains the correct degrade path specifically for the case
  `.claude-extensions.json`'s `source_dir` key is itself absent or unresolvable (e.g. a consumer
  repo that has not declared it, or a `source_dir` path that does not exist on the current
  machine) — never a silent pass, and distinct from today's hard environment-error exit.

## Recommendations

- For `test-askuserquestion-rehome.sh`: extend `STANDARD_PATH`, `TEMPLATE_PATH`, `LINT_PATH`,
  `SKILL_META_PATH`, `INTERVIEW_PATH`, `SKILL_SPAWN_PATH`, and `SKILL_FIXIT_PATH` with the same
  two-tier resolution this file's own `AGENT_FILES` scan already uses (source-store path, then a
  deployed-tree candidate under `.claude/`), since these are reference docs/skills whose deployed
  copy is a faithful mirror of the source.
- For `test-routing-resolution.sh` and `test-update-task-status.sh`: resolve their hardcoded
  `agent-system/extensions/core/scripts/...` lookups through `.claude-extensions.json`'s
  `source_dir` (or the already-deployed copy, whichever is semantically appropriate per suite),
  using the same `jq -r '.extensions.core.source_dir // empty'` read `deploy-freshness-lib.sh`
  already performs, falling open to a loud, reason-carrying SKIP if that also fails to resolve.
- For `test-lint-dead-command-recommendations.sh`: fix the enumeration root in
  `lint-dead-command-recommendations.sh` itself (not only its test fixture), since the defect is
  in the script under test.
- For `test-manifest-scripts-sync.sh`/`sync-manifest-scripts.sh`: give `EXT_DIR`'s default a
  `source_dir`-resolved fallback before its current bare `$REPO_ROOT/agent-system/extensions`
  guess, and consider teaching `deploy-root-guard.sh`'s self-correction acceptance test itself to
  also accept "a `.claude-extensions.json` at `$REPO_ROOT` resolves `core.source_dir` to an
  existing directory" as an alternative to "`agent-system/extensions` exists directly under
  `$REPO_ROOT`" — this would fix the shared choke point once for every caller that opts into the
  guard's self-correction, rather than once per caller.
- For `test-deploy-propagation.sh`: resolve `MANIFEST` through the `source_dir` indirection
  specifically (not a deployed-tree fallback), since this suite's entire purpose is comparing the
  deployed tree against the true pre-deploy source.
- Do not expand this task's fix to the 2 misattributed suites or the ~29-suite unrelated cluster;
  spawn or file those separately once this task's own fix lands, so the exit-code-discrimination
  goal this task targets is not entangled with an unrelated, currently-active regression.
- Before closing this task, re-run `run-all.sh` with no filter in the external consumer repo
  again and confirm the 6 confirmed suites move off the NEW list (ideally into PASS, matching this
  repository's own result for them today).

## Risks & Mitigations

- **Risk**: a consumer repo's `.claude-extensions.json` may be missing, stale, or point to a
  `source_dir` that does not exist on the current machine (a different host than the one that
  authored it). **Mitigation**: every suggested resolver call falls open (never hard-fails) on a
  miss, matching `deploy-freshness-lib.sh`'s existing contract — the suite should degrade to
  today's loud environment error or an explicit SKIP-with-reason, never a silent pass.
- **Risk**: conflating the 6 confirmed suites with the 2 misattributed ones or the unrelated
  cluster could make a future fix appear complete (count-wise) while leaving the actual named
  cause unaddressed, or could cause an unrelated regression to be accidentally silenced under this
  task's authority. **Mitigation**: the per-suite table above is the explicit boundary; any
  implementation phase should verify against it directly rather than against the raw failing-count
  delta.
- **Risk**: the unrelated ~29-suite cluster may grow or shrink before a follow-up task addresses
  it, making any count cited here stale quickly (as happened to the original 26/156 figures).
  **Mitigation**: this report deliberately avoids proposing a fix for that cluster and instead
  records it as an issue for separate triage, consistent with this task's own instruction not to
  trust inherited counts without re-deriving them.

## Context Extension Recommendations

- **Topic**: per-extension source-store resolution for shell test suites.
- **Gap**: no existing context file documents the `.claude-extensions.json` `source_dir` +
  `deploy-freshness-lib.sh`-style fall-open read as the sanctioned pattern for a test suite that
  needs source-store content in a repo where the source store is external. The pattern exists in
  code (`deploy-freshness-lib.sh`) but is not named anywhere a suite author would find it before
  hardcoding a bare `$REPO_ROOT/agent-system/extensions/...` path.
- **Recommendation**: add a short pattern note (e.g. under
  `context/standards/shell-script-testing.md` or a new `context/patterns/` file) naming this
  resolution order explicitly: source-store path -> `.claude-extensions.json` `source_dir` ->
  deployed-tree mirror (where semantically valid) -> loud SKIP with reason, so a future suite
  does not reintroduce this same choke point.

## Appendix

- Search queries / commands used: `jq -r '.extensions.core.source_dir' .claude-extensions.json`
  (both repositories); `bash .claude/scripts/tests/run-all.sh --jobs auto` (both repositories,
  full sweep); direct invocation of each of the 8 originally-named suites in both repositories;
  `grep -rn "common_test_repo_root"`, `grep -rn "CANNOT_COMPUTE"`,
  `grep -rn "source_dir" agent-system/extensions/core/scripts/lib/*.sh`.
- References: `agent-system/extensions/core/scripts/lib/common.sh` (`common_test_repo_root`,
  `common_test_resolve_candidate`, `common_test_resolve_subject`),
  `agent-system/extensions/core/scripts/deploy-root-guard.sh` (self-correction acceptance test),
  `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh` (existing `source_dir`
  reader), `agent-system/extensions/core/scripts/sync-manifest-scripts.sh`,
  `agent-system/extensions/core/scripts/tests/test-askuserquestion-rehome.sh`,
  `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`,
  `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`,
  `agent-system/extensions/core/scripts/tests/test-update-task-status.sh`,
  `agent-system/extensions/core/scripts/tests/test-lint-dead-command-recommendations.sh`,
  `agent-system/extensions/core/scripts/tests/test-manifest-scripts-sync.sh`,
  `.claude/scripts/tests/known-failures.txt`.
