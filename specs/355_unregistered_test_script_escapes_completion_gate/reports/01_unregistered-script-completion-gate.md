# Research Report: Task #355

**Task**: 355 - Unregistered test script escapes the completion gate
**Started**: 2026-10-08T00:00:00Z
**Completed**: 2026-10-08T00:00:00Z
**Effort**: medium
**Dependencies**: None (territory-serialized after the honest-session-liveness task per this
  dispatch's edge; no work dependency)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/check-extension-docs.sh`,
  `verify-deploy.sh`, `deploy-headless.sh`, `command-gate-out.sh`,
  `scripts/lib/deploy-baseline-lib.sh`, `scripts/lib/redeploy-checkpoint-lib.sh`,
  `orchestrate-cycle-plan.sh`, `reconcile-task-status.sh`
- Git history: commits `a9061bd85`, `2119f4154`, `eec4e5838` (task 343 incident),
  `7042e09da`/`58e503358`/`52a344332` (task 300 self-correction), `3ca09d17d`/`21006e4f4`/
  `b7d1d9376` (deploy-baseline-lib.sh provenance), `07182ad94` (Rule Q provenance)
- Docs: `context/patterns/batch-orchestration-guardrails.md`'s "Inter-Cycle Redeploy Checkpoint"
  section
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The suspected mechanism is **confirmed, with an important correction**: the reconcile/checkpoint
  completion path genuinely verifies less than a mid-implementation redeploy, but NOT because
  `check-extension-docs.sh` is skipped or because the comparison is count-based. Gate 3
  (`check-extension-docs.sh`) runs in both paths, and the pre/post comparison has been a correct
  `comm -13` **set-difference over FINDING-line identities** since 2026-10-03 (commit `3ca09d17d`),
  three days before the task-343 incident. The `pre=11 post=2 new=0` line quoted in this task's
  provenance is that exact, already-identity-based branch's own diagnostic output — it is not
  evidence of count-based comparison, it is evidence the comparison classified the finding
  "temporally pre-existing."
- **The real mechanism**: `check-extension-docs.sh`'s `EXT_DIR` always resolves to the
  **source store** (`agent-system/extensions/`), in this repo, even when invoked via the deployed
  copy — so its Rule Q finding ("script file on disk NOT in `provides.scripts`") depends only on
  what is committed to the source store, never on what the redeploy itself changes. A task's new,
  unregistered script is committed to the source store during implementation — one or more cycles
  before the checkpoint ever runs its own pre-snapshot. By the time the checkpoint takes
  `pre_findings`, the violation is *already* present; it is therefore never "new" relative to
  that checkpoint's own narrow measurement window, so it always lands in the clean/"proceed, it
  predates this redeploy" branch — regardless of whether the violation is causally attributable
  to the very task this checkpoint's reconcile pass is about to mark `[COMPLETED]`.
- Task 300 avoided this fate not because its completion path verified more strictly, but because
  its plan ran deploy-headless.sh / verify-deploy.sh directly, mid-implementation, as an ordinary
  phase step (git history: phase 7 "narrow file_scope, regenerate, and run the full gate set",
  followed immediately by phase 7.1/7.2 fixing the registration) — a **raw, unfiltered**
  `check-extension-docs.sh fail()`, with no baseline-tolerance applied, because that call site is
  not one of the two baseline-consulting call sites at all.
- `provides.scripts` is **not deliberately curated** today: every tracked, non-`deprecated/`
  script file in every extension's `scripts/` tree is already present in that extension's
  `provides.scripts` array (verified empirically, zero exceptions across all extensions). This
  removes the main objection to automating it.
- `provides.agents`, `provides.commands`, and `provides.context` have **no equivalent disk-driven,
  pre-deploy check** at all (only `provides.scripts` [Rule Q], `provides.rules` [Rule H], and
  `provides.skills` [Rule A] do). A newly-added, unregistered agent/command/context file shares
  this exact escape today, with no existing Rule to even catch it mid-implementation the way
  Rule Q caught task 300's script.
- Recommended fix: **(a) automate `provides.scripts` derivation** (safe, since no curation
  exists) **plus (b) a narrower, attribution-based completion-time fix** — extend the existing
  attribution filter's reach to the "temporally pre-existing" branch for findings that match the
  *completing task's own* `modified_files`/`file_scope`, so a defect this task itself just
  introduced can never hide behind "it predates my own redeploy." (c) documentation alone is
  rejected as the sole fix, consistent with the dispatch's own framing.

## Context & Scope

This is a meta-task investigating a process defect: a missing `provides.scripts` manifest entry
for a new `scripts/tests/*.sh` file can reach `[COMPLETED]` undetected when the owning task's
postflight routes through the inter-cycle redeploy checkpoint / post-deploy reconcile path,
whereas the identical defect is caught (and self-corrected) when a task's own implementation
phase redeploys directly. The research traced the full gate chain (`check-extension-docs.sh` ->
`verify-deploy.sh` gate 3 -> `deploy-baseline-lib.sh` -> `orchestrate-cycle-plan.sh`'s checkpoint
and `command-gate-out.sh`'s `rc==6` handler -> `reconcile-task-status.sh`) using direct code
reading plus git history of the two concrete incidents (task 343 escaped; task 300 self-corrected)
named in this task's provenance. No web research was needed; this is entirely an internal
process/gate-design question.

## Findings

### Codebase Patterns

**Rule Q already exists and is correct in isolation** (`check-extension-docs.sh`,
`check_undeclared_scripts`, added 2026-07-27, commit `07182ad94`, well before the 2026-10-06
incident). It walks `git ls-files "$ext_path/scripts"` for each extension and `fail()`s on any
tracked file whose path (relative to `scripts/`) is absent from that extension's
`provides.scripts` array, exempting only `deprecated/*`. This is gate 3 of `verify-deploy.sh`,
which is **not** deferred by `--skip-slow` (only gate 8, the full shell-test battery, is deferred).

**`EXT_DIR` resolves to the source store, always, in this repo**
(`check-extension-docs.sh:109-111`): `REPO_ROOT` defaults to
`$(dirname "${BASH_SOURCE[0]}")/../..`, and `EXT_DIR="$REPO_ROOT/agent-system/extensions"`. When
gate 3 invokes the *deployed* copy (`$CLAUDE_DIR/scripts/check-extension-docs.sh`), `BASH_SOURCE`
is that deployed path, so `REPO_ROOT` still resolves to this same repo's root (since this repo is
both the source-store owner and its own deploy target) — `EXT_DIR` is **always**
`agent-system/extensions`, never `.claude/extensions`. Consequently Rule Q's verdict is a pure
function of the source-store git state and is completely insensitive to whether a deploy has run
at all.

**`provides.scripts` genuinely controls deployment** (`skill-base.sh:231`: "The deploy pipeline
flattens manifest.provides.scripts into `.claude/scripts/`") and is also what Rule W/X's "will
never deploy, regardless of regeneration" language depends on. This is a real reason to be
cautious about blind automation — but:

**`provides.scripts` is empirically NOT curated today.** For every extension with a `scripts/`
directory, `comm -23 <(git ls-files .../scripts | strip-prefix) <(jq '.provides.scripts[]')`
(excluding `deprecated/*`) returns **empty** — every tracked script, including every file under
`scripts/tests/`, is already declared. There is no existing precedent for deliberately excluding
a tracked, non-deprecated script from `provides.scripts`. Rule Q itself is presumably what keeps
this invariant intact today (it would `fail()` the moment a gap appeared) — except, per this
task's own provenance, when the gap's *detection* routes through the baseline-tolerant completion
path, which is exactly the hole this task is investigating.

**The baseline comparison is identity-based, not count-based, and predates the incident**
(`scripts/lib/deploy-baseline-lib.sh`, extracted in commit `3ca09d17d` "task 152 phase 1", dated
2026-10-03 — three days before the 2026-10-06 task-343/300 incident; confirmation/attribution
filters added later the same day in `21006e4f4`/governing-source map in `b7d1d9376`).
`deploy_findings_snapshot` captures `verify-deploy.sh --findings --quiet` output, one `FINDING `
line per violation; `deploy_baseline_new_findings` is `comm -13` (post minus pre) over those
*lines*, not a count. The diagnostic `pre=$(... grep -c .) post=$(... grep -c .) new=0` line
(`orchestrate-cycle-plan.sh:1032`) is printed **only inside the branch where the `comm -13`
diff was already empty** — i.e. it is evidence of correct identity-based classification into
"temporally pre-existing," not evidence of a count-only algorithm. The exact "pre=11 post=2 new=0"
wording quoted in this task's provenance matches this branch's log format verbatim.

**The structural blind spot**: `context/patterns/batch-orchestration-guardrails.md`'s own design
doc states the philosophy explicitly: branch (c) ("findings ALL already present in the
pre-redeploy baseline, OR confirmed flaky/unrelated") extends "from *temporally* pre-existing
(identical in both snapshots) to *causally* unattributable" — but the confirmation+attribution
filter pair is applied **only to the candidate-new branch** (post-present, pre-absent). The
*temporally*-pre-existing branch (comm -13 empty) proceeds with **zero** attribution check, by
explicit design, to avoid blocking a whole batch on unrelated old red gates. For a check whose
subject lives purely in the source store (Rule Q, and by extension Rule H/rules, Rule G/dangling
contract refs, any future disk-driven source-store rule), "temporally pre-existing relative to
this checkpoint's own pre/post pair" and "committed by the very task this checkpoint is about to
complete" are **indistinguishable** by this mechanism, because the source store does not change
between the checkpoint's `pre_findings` and `post_findings` calls (only `deploy-headless.sh`'s
copy-to-`.claude/` step runs in between). `command-gate-out.sh`'s `rc==6` handler
(`command-gate-out.sh:176-250`) shares the identical algorithm (sourcing the same
`deploy-baseline-lib.sh`), minus the confirm/attribute filters (deliberately, per its own
comment: an operator is present at single-task completion, so no automatic filtering is applied
there) — so it has the identical temporally-pre-existing blind spot, just reached without any
filtering step at all.

**Why task 300 self-corrected and task 343 did not** (both confirmed via git history, not
inference): task 300's plan phase 7 ("narrow file_scope, regenerate, and run the full gate set")
ran `deploy-headless.sh`/`verify-deploy.sh` directly as an ordinary implementation step — a call
site with **no** baseline comparison applied at all, so the raw `fail()` printed directly to the
agent's own tool output, and phases 7.1/7.2 fixed it before any commit reached a baseline-tolerant
gate. Task 343's own postflight hit `command-gate-out.sh`'s `rc==6` (deploy-pending, stale)
refusal (commit `a9061bd85`, `.return-meta.json`: `"deploy_pending_reason": "postflight
completion-deploy gate refused (exit 6): ..."`) — the retry inside that same handler either did
not land or re-refused, leaving the task paused; the **next cycle's** inter-cycle redeploy
checkpoint then ran the deploy and reconcile (commit `2119f4154`, six minutes after the pause),
by which time the Rule Q violation (committed well before either gate ran) was indistinguishable
from any other "old, pre-existing, unrelated" red finding. `eec4e5838` (62 minutes later)
hand-fixed the registration, confirming the escape with the exact FAIL text Rule Q produces.

**Other `provides.*` arrays — the escape is wider than scripts.** The check-extension-docs.sh
rule index (its own header comment) shows a disk-driven, pre-deploy, undeclared-file check exists
for exactly three of the six `provides.*` categories:

| Category | Disk-driven pre-deploy check | Deployed-orphan check (post-deploy only) |
|---|---|---|
| `provides.scripts` | Rule Q (`check_undeclared_scripts`) | Rule M |
| `provides.rules` | Rule H (`check_undeclared_rules`) | Rule I (drift, not orphan) |
| `provides.skills` | Rule A (`check_undeclared_skills`) | — |
| `provides.agents` | **none** | Rule J (`check_flat_category_orphans(agents)`) |
| `provides.commands` | **none** | Rule K (`check_flat_category_orphans(commands)`) |
| `provides.context` | **none** | Rule L (`check_context_orphans`) |

The orphan checks (J/K/L) are the ones Rule M's own comment calls "structurally blind to a file
that was never deployed in the first place because it was never declared" — a file that is never
declared also never deploys, so there is no orphan to detect; the orphan check only catches a
file that WAS declared once and then de-listed while the deployed copy lingers. A brand-new,
unregistered agent, command, or context file has **no Rule-Q-equivalent today** and would not
even be caught by a task-300-style mid-implementation redeploy, let alone a reconcile-path
completion — it simply silently never deploys, with no fail() anywhere in the chain.

### External Resources

Not applicable — this is an internal process/gate design question with no external library or
documentation dependency.

## Decisions

- **The "finding COUNTS vs. IDENTITIES" framing in this task's provenance is REFUTED as the root
  cause.** The comparison has been identity-based (`comm -13` over FINDING-line text) since
  2026-10-03, predating the incident by three days. No change to count-vs-identity comparison
  shape is needed or recommended.
- **The suspected mechanism (reconcile path verifies less than mid-implementation redeploy) is
  CONFIRMED**, with the precise mechanism being the temporally-pre-existing-vs-causally-
  unattributable gap in the baseline philosophy, not verification suppression. This gap is a
  property of **any** source-store-resident, disk-driven check reached only through
  `command-gate-out.sh`'s `rc==6` handler or `orchestrate-cycle-plan.sh`'s inter-cycle checkpoint
  — it is not specific to `provides.scripts`.
- **`provides.scripts` is not deliberately curated** (verified empirically across every
  extension); candidate fix (a) — deriving it automatically from `scripts/`'s tracked file list,
  mirroring `index-entries.json`'s wholesale-directory convention, exempting `deprecated/*` the
  same way Rule Q already does — is SAFE to adopt and removes the authoring burden entirely for
  this category.
- **Fix (a) alone does not close the general escape.** Automating `provides.scripts` closes this
  one category's instance, but the identical temporally-pre-existing blind spot remains open for
  every other disk-driven check reached via the same two call sites (Rule H/rules today; any
  future Rule for agents/commands/context if added). A completion-time fix (b) is still required
  as defense-in-depth, scoped narrowly: extend attribution checking (the existing
  `deploy_baseline_unattributable_findings` machinery) to also run against the temporally
  pre-existing branch, using the **completing task's own** `modified_files`/`file_scope` (already
  available at both call sites) as the attribution set — a pre-existing finding that positively
  names an identifier matching this specific task's own files should remain blocking even though
  it is temporally pre-existing relative to the checkpoint's narrow window. This is additive to
  the existing filter design (same fail-safe-toward-blocking direction: absence of an identifier
  never clears a finding), not a replacement of it.
- **Fix (c) (documentation alone) is rejected as a sole fix**, consistent with the dispatch's own
  framing — acceptable only alongside (a) and/or (b). Given (a) is being adopted, (c) becomes
  largely moot for the scripts case specifically, but the extension-authoring guidance should
  still note that `provides.agents`/`provides.commands`/`provides.context` remain hand-maintained
  with no disk-driven safety net (see below), since (a) is scoped to scripts only in this task's
  acceptance criteria.
- **The other `provides.*` arrays DO share a version of the escape**: `provides.agents`,
  `provides.commands`, and `provides.context` have no Rule-Q/A/H-equivalent disk-driven check at
  all today, which is a strictly worse gap than the scripts case (no detection at any point in
  the lifecycle, not merely a detection-but-waved-through-at-completion gap). This task's own
  `file_scope`/acceptance is scoped to the scripts case; closing the agents/commands/context gap
  is recommended as a **separate follow-up task**, not folded into this one, since it requires
  designing three new Rules (or a generalized one) rather than fixing an existing one.

## Recommendations

1. **Automate `provides.scripts`** (candidate fix (a)): replace the hand-maintained array with a
   directory-derived list (every tracked file under each extension's `scripts/`, excluding
   `deprecated/*`), either by having the manifest loader treat `provides.scripts` as
   computed/ignored-if-present, or by adding a `--write` repair mode to
   `check-extension-docs.sh`/a dedicated script (the `generate-context-line-counts.sh --write`
   precedent this task's dispatch names). Recommend landing this as the primary fix: it removes
   the authoring burden entirely and is empirically safe (zero curation exceptions found).
2. **Close the completion-time blind spot** (candidate fix (b), narrow form): extend
   `deploy_baseline_unattributable_findings`'s attribution logic to also screen the "temporally
   pre-existing" branch at both call sites (`command-gate-out.sh`'s `rc==6` handler and
   `orchestrate-cycle-plan.sh`'s checkpoint's per-task reconcile step), using the completing
   task's own `modified_files` as the attribution set, so a finding this task itself caused can
   never hide behind "it predates my own redeploy." This generalizes past `provides.scripts` to
   protect every other disk-driven, source-store-resident check (Rule H today; any future rule)
   through the same two call sites.
3. **Pin the regression with a fixture** targeting whichever of (1)/(2) lands: a scenario where a
   new `scripts/tests/test-*.sh` is added to the source store without a `provides.scripts` entry,
   committed, and then completed via the reconcile/`rc==6` path — this must fail the chosen gate.
   `scripts/tests/test-deploy-baseline-lib.sh` (unit-level, identity/attribution logic) and
   `scripts/tests/test-orchestrate-cycle-plan.sh` (Group 28/29-style checkpoint-branch fixtures)
   are the two existing suites with direct precedent for this shape; no dedicated
   `test-check-extension-docs.sh` exists today, so Rule Q itself has no direct fixture coverage
   either — worth adding alongside whichever fix lands.
4. **Open a follow-up task** for the `provides.agents`/`provides.commands`/`provides.context` gap
   identified above (no disk-driven pre-deploy check exists for any of the three) — out of this
   task's `file_scope`/acceptance, but a materially real escape in its own right, arguably worse
   than the scripts case since it has no detection point at all today, not even a task-300-style
   mid-implementation catch.
5. Keep `--skip-verify`/the `landed_verify_skipped` exit 4 exactly as designed — it is not part of
   this defect. It suppresses only `deploy-headless.sh`'s own *redundant* internal verify at the
   two call sites that already take their own independent baseline-compared pair; the actual gap
   is in the baseline philosophy's pre-existing branch, not in verification suppression.

## Risks & Mitigations

- **Risk**: automating `provides.scripts` derivation could silently change deploy behavior if a
  future author genuinely needs to exclude a tracked, non-deprecated script. **Mitigation**:
  preserve an explicit opt-out mechanism (e.g. a `provides.scripts_exclude` array, or extend the
  `deprecated/` convention to a general exclusion marker) rather than removing curation
  capability outright; today's empirical finding (zero such cases) does not guarantee none will
  ever arise.
- **Risk**: extending attribution checking to the temporally-pre-existing branch could
  (re-)introduce the batch-deferral-on-unrelated-finding problem the existing design deliberately
  avoided. **Mitigation**: scope the new attribution check strictly to the *completing task's
  own* `modified_files`/`file_scope` (never the whole batch's `cycle_modified_files`, which is
  already used for the candidate-new branch) — a finding attributable to a DIFFERENT task in the
  same batch must still be waved through as before; only self-attribution should newly block.
- **Risk**: a fixture pinning this exact scenario could itself be fragile against future
  refactors of `deploy-baseline-lib.sh`/`redeploy-checkpoint-lib.sh` (both already mid-refactor
  per their own header comments, e.g. the Phase 6 script-corpus decomposition). **Mitigation**:
  assert on behavior (the specific FINDING text and the resulting task status), not on internal
  function names or line counts.

## Context Extension Recommendations

- **Topic**: `provides.agents`/`provides.commands`/`provides.context` lack disk-driven pre-deploy
  checks.
- **Gap**: `context/patterns/batch-orchestration-guardrails.md` and
  `check-extension-docs.sh`'s own rule-letter index fully document the scripts/rules/skills
  disk-driven checks (Q/H/A) but do not flag that agents/commands/context have no analogous rule
  — a future extension author adding a new agent or command file has no documented warning that
  it needs manual registration and no gate to catch a miss, at any point in the lifecycle.
- **Recommendation**: once the follow-up task (Recommendation 4 above) designs the new Rule(s),
  add them to the rule-letter index in `check-extension-docs.sh` and cross-reference from
  `docs/guides/creating-extensions.md`'s manifest schema section.

## Appendix

- Key commits inspected: `07182ad94` (Rule Q origin, 2026-07-27), `3ca09d17d`/`21006e4f4`/
  `b7d1d9376` (deploy-baseline-lib.sh identity/confirm/attribution, 2026-10-03), `a9061bd85`
  (task 343 paused, deploy_pending_reason recorded), `2119f4154` (task 343 completed via
  post-deploy reconcile), `eec4e5838` (task 343 manual fix, exact FAIL text quoted), `7042e09da`/
  `58e503358`/`52a344332` (task 300 phase 7/7.1/7.2 self-correction sequence).
- Files read in full or substantially: `check-extension-docs.sh` (header, Rule Q, EXT_DIR
  resolution), `verify-deploy.sh` (gate 3 invocation), `deploy-headless.sh` (`--skip-verify`
  contract), `command-gate-out.sh` (`rc==6` handler, lines ~176-250), `orchestrate-cycle-plan.sh`
  (lines ~920-1145, the full three-branch checkpoint), `scripts/lib/deploy-baseline-lib.sh` (all
  four exported functions), `scripts/lib/redeploy-checkpoint-lib.sh` (post-deploy reconcile loop),
  `reconcile-task-status.sh` (promotion predicate), `skill-base.sh` (deploy-pipeline-flattens
  comment).
- Verification commands run: `comm -23` diffs of `git ls-files .../scripts` against
  `jq '.provides.scripts[]'` for every extension (all empty, confirming no curation); `grep -n`
  sweeps for `provides.scripts` usage, Rule-letter index extraction, and `--skip-verify`/
  `pre=11 post=2` log-format cross-checks against the dispatch's quoted text.
