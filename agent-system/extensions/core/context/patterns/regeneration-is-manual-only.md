# Regeneration: Interactive by Default, Headless When Driven Deliberately

## Overview

The `<leader>al` picker's `[Reload All]` (non-destructive force-resync) and `[Regenerate]`
(destructive wipe + rebuild) entries are the primary interactive mechanism that deploys the
extension source store (`agent-system/extensions/**`) into a consuming repo's gitignored
`.claude/` tree. Every deployed file under `.claude/` has a source under
`agent-system/extensions/**`; nothing under `.claude/` is hand-authored. Both entries -- and the
headless path below -- are backed by the same single manifest-driven engine
(`neotex.plugins.ai.shared.extensions`'s `manager.resync_all`/`manager.wipe`); there is no second,
independent sync mechanism to keep in sync with this one.

**CORRECTION.** An earlier revision of this document asserted that regeneration had *no*
headless, scripted, or CI equivalent, and instructed future work not to retread the question.
**That assertion was wrong, and it was load-bearing** -- it propagated into research findings,
implementation plans, and user-facing handoffs, each of which concluded that deployment could
only ever be a manual, user-owned step. A headless path exists, is straightforward, and is now
implemented as `scripts/deploy-headless.sh`.

## The Headless Path (verified)

`scripts/deploy-headless.sh` calls the manifest-driven engine's `manager` functions directly with
an explicit `confirm = false` option, rather than stubbing `vim.fn.confirm()` in front of an
interactive-only entry point (the technique this section originally documented, back when the
only bulk-sync engine was the picker-only, confirm-dialog-gated `load_all_globally`). That engine
has since been retired: the picker's `[Reload All]`/`[Regenerate]` entries and this script are
both direct `manager` callers now, with no confirm-stubbing indirection involved on either path.

```bash
# Default: bootstrap-safe, non-destructive force-resync of every active extension
bash .claude/scripts/deploy-headless.sh [TARGET_REPO]

# Full destructive wipe + rebuild (snapshot -> rm -rf .claude -> regenerate -> restore)
bash .claude/scripts/deploy-headless.sh --wipe [TARGET_REPO]
```

**Two-root convention.** `deploy-headless.sh` is *invoked* from a consuming repo root as
`.claude/scripts/deploy-headless.sh` -- the deployed copy, as shown above -- and is *referred to*
elsewhere in this document and throughout the source store by its extension-relative identifier,
`scripts/deploy-headless.sh`. A bare `scripts/deploy-headless.sh` is never a runnable path from a
repo root: it fails with **exit 127**, writing its diagnostic (`No such file or directory`) to
**stderr only** and nothing to stdout, so a caller that captures stdout alone, or checks exit
status loosely, sees what looks like a silent no-op rather than a failure. The one legitimate
exception is invoking from this repo's own root before any `.claude/` tree exists (the CI
bootstrap case): there, the source-store-relative form
`bash agent-system/extensions/core/scripts/deploy-headless.sh` is correct, as used by
`.github/workflows/check-extension-docs.yml`.

This was verified against a from-scratch scratch git repository: a fresh (no prior `.claude/`)
default-mode deploy correctly reconstructs the full tree, including subdirectory-declared
`provides.scripts`/`provides.hooks` entries -- the exact class of entry the retired engine
silently dropped on both a fresh deploy and a resync alike (see
`scripts/tests/test-deploy-propagation.sh`, whose Assertions A and B guard against a regression
of this exact defect). `--wipe` was verified to survive `settings.local.json` and every
`.syncprotect`-listed path **semantically** across the deletion -- value-for-value identical
under `jq -S`, with key/array reordering observed at the byte level in every sampled pair. See
`### Round-Trip Fidelity of settings.local.json (measured)` below for the full measurement.

Use `scripts/deploy-headless.sh` rather than open-coding an equivalent `manager` call -- it
resolves the repo root, refuses to run outside a git repository, holds the `specs/.deploy-lock`
mutex, and reports the artifact/extension count it deployed.

## When to Prefer Which

- **The interactive picker's `[Reload All]`/`[Regenerate]` entries** remain the right default for
  a human at a terminal. `[Regenerate]` (the destructive path) is gated behind a `vim.fn.confirm`
  yes/no dialog -- a genuine safeguard, since it deletes and rebuilds `.claude/` from scratch.
  `[Reload All]` (non-destructive) is gated behind its own submenu choice
  ("Reload All"/"Unload All"/"Step Through"/"Cancel") rather than a yes/no dialog, matching its
  lower-risk, non-destructive intent while still requiring an explicit selection.
- **`scripts/deploy-headless.sh`** is for scripted, CI, and agent-driven contexts where no human
  is present to answer a dialog. Its `--wipe` flag deliberately bypasses the interactive
  confirmation `[Regenerate]` would otherwise show, so it must be invoked explicitly and never as
  a silent side effect of an unrelated operation.

## Automated Exception: The Inter-Cycle Self-Modification Checkpoint

The sentence directly above -- `scripts/deploy-headless.sh` "must be invoked explicitly and never
as a silent side effect of an unrelated operation" -- is left byte-for-byte intact by this
subsection. It is not edited, weakened, or reworded here, matching this document's own
established correction-as-addition pattern (see the `**CORRECTION.**` block above): a constraint
that is no longer fully true is narrowed by a labeled, additive exception, never quietly rewritten
in place.

**The exact and only sanctioned automated call site**: `skill-orchestrate`'s Stage MT-3 step 7 --
the inter-cycle redeploy checkpoint. No other automated caller is sanctioned by this subsection.

**Why this is not a side effect of an unrelated operation**: the fix that triggers the checkpoint
is precisely the fix the checkpoint exists to make live. A dispatched task's commit at Stage MT-4
step 5.5 touching an orchestrator-critical path is the operation the redeploy is *for*, not an
operation the redeploy is merely alongside. The operation is not unrelated -- it is the operation
being corrected.

**Why this is not silent**: the checkpoint logs on fire (naming the matched critical paths it
detected), on success (naming the deployed artifact count and the `verify-deploy` pass), and on
failure (naming the failing gate and its exit code). An operator reading the run's output can
always distinguish "the checkpoint did not fire" from "it fired and passed" from "it fired and
failed."

**Why this is bounded**: the checkpoint is evidence-gated on actual `modified_files` overlapping a
declared critical path -- never an unconditional "always between cycles" trigger. It fires at most
once per critical path per invocation, via the idempotence guard. Any failure of either gate defers
the remainder of the invocation rather than proceeding past an unverified deploy.

**What this carve-out explicitly does NOT license**: no other automated caller may invoke
`scripts/deploy-headless.sh` without its own equivalent exception recorded in this same section. A
future reader must not read this subsection as general precedent for scripted deploys elsewhere in
the system -- it licenses exactly the one call site named above, nothing broader.

The full trigger, failure contract, sequencing, and idempotence-guard contract is recorded once,
authoritatively, in `context/patterns/batch-orchestration-guardrails.md`'s
`### The Inter-Cycle Redeploy Checkpoint` subsection. It is cross-referenced here, not restated.

## Automated Exception: The Postflight Completion-Deploy Gate

Additive to the deliberate-invocation sentence above, in the same shape as the Inter-Cycle
Self-Modification Checkpoint exception immediately above -- neither of those two constraints is
edited, weakened, or reworded here. This is the second and, as of this writing, LAST exception
this section records.

**The exact and only sanctioned automated call sites**: `scripts/command-gate-out.sh`'s
`rc == 6` branch (the single-task `/implement` completion path -- a point with no concurrency,
since it runs once per task after that task's own dispatch has already returned), and
`commands/implement.md` Step 4's batch-refusal trigger (the multi-task `/implement` completion
path -- already serial, since it runs once, after all of Step 3's parallel dispatches have
returned). No other automated caller is sanctioned by this subsection.

An explicit non-exception, named so a later pass does not go looking for one:
`skill-orchestrate`'s Stage MT-3 step 7 is UNTOUCHED by this mechanism and needs no new exception
here -- it remains covered exclusively by the Inter-Cycle Self-Modification Checkpoint exception
above. A task refused by the postflight completion-deploy gate under `/orchestrate` defers loudly
(via the `deploy_pending` marker `skill_postflight_update` records into its `.return-meta.json`)
rather than being redeployed by a THIRD trigger site; widening Stage MT-3 step 7's own predicate
is the proper fix for that residual and is named as follow-up work in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight Completion-Deploy
Gate` subsection, not attempted here.

**Why this is not a side effect of an unrelated operation**: exactly as the exception above
argues for its own single call site, the fix that triggers each of these two redeploys is
precisely the fix each redeploy exists to make live -- a task whose OWN commit touched
`agent-system/extensions/**` is the operation these two sites correct, not an operation they run
alongside.

**Why this is not silent**: each call site logs on fire (naming the refusing task number and,
for the single-task path, the specific matched `agent-system/extensions/**` path(s)), on success
(naming the deployed extension count and the verify-deploy outcome), and on failure (naming the
failing branch -- (a) deploy did not land, (b) a new finding, or (c) pre-existing findings only --
and the relevant exit code). An operator reading either call site's output can always distinguish
"the gate did not fire" from "it fired and the redeploy succeeded" from "it fired and the redeploy
failed."

**Why this is bounded**: both sites are evidence-gated on the SAME check-only backstop inside
`scripts/update-task-status.sh` observing an actual `modified_files`-to-`agent-system/extensions/**`
overlap AND provable staleness -- never an unconditional "always redeploy" trigger. Each site
fires at most once per its own invocation (a gate-out call for the single-task path; a Step 4 run
for the multi-task batch path) and re-attempts the refused transition(s) at most once after a
successful redeploy; a second refusal after that redeploy is a real signal, surfaced loudly, never
retried again within the same invocation.

**What this carve-out explicitly does NOT license**: identical in force to the exception above --
no other automated caller may invoke `scripts/deploy-headless.sh` without its own equivalent
exception recorded in this same section. This subsection licenses exactly the two call sites named
above, nothing broader, and is **not precedent**: a future automated caller, including any future
widening of `skill-orchestrate`'s own trigger, still needs its own exception recorded here.

The full trigger predicate, the check-only contract, the conclusiveness convention, exit 6's
ordering-constraint semantics, and the shared (a)/(b)/(c) baseline contract are recorded once,
authoritatively, in `context/patterns/batch-orchestration-guardrails.md`'s `### The Postflight
Completion-Deploy Gate` subsection. It is cross-referenced here, not restated.

### `deploy-headless.sh`'s Inline Verification and Exit Code 3

Narrow, don't silently rewrite: the correction below is additive to this subsection's own
contract above, the same way this subsection was additive to the deliberate-invocation sentence
it narrows. Prior to this correction, `deploy-headless.sh` ended every non-dry-run invocation by
*echoing* `verify-deploy.sh`'s invocation command rather than running it -- reachable only by a
human typing the command by hand. `deploy-headless.sh` now runs
`verify-deploy.sh --skip-slow "$TARGET"` inline, in `main()`'s shared trailing block, on every
non-dry-run deploy (both the default resync branch and `--wipe`), with its output streamed
directly to the caller.

**The exit-code contract.** A non-dry-run `deploy-headless.sh` now exits `3` -- distinct from `1`
(usage error) and `2` (the headless nvim invocation failed, or `--wipe`'s pre-wipe snapshot was
refused) -- when the deploy itself landed but the inline verification run reported one or more
failures. Exit 3 means the tree WAS modified, unlike 1 and 2. `--dry-run` never reaches
verification at all: it returns 0 at its own earlier branch, before the trailing block that calls
`verify-deploy.sh` runs.

**The fast/full gate split.** The inline call passes `--skip-slow`, a `verify-deploy.sh` flag
that skips gate 8 (the shell test suite runner, `tests/run-all.sh`) only -- every other gate still
runs. Gate 8 alone was measured at 117.9s of the script's ~2.8min total run, so `--skip-slow`
drops the inline cost to roughly 50-70s. The full gate set, including gate 8, remains available on
demand by running `verify-deploy.sh` with no flag -- `deploy-headless.sh`'s exit-3 failure message
names that exact command.

**The Stage MT-3 step 7 collision -- DONE.** `skill-orchestrate/SKILL.md`'s deploy-failure branch
was written as "Non-zero exit (1 or 2) -> defer unconditionally ... with NO baseline consultation
whatsoever". Exit 3 sat outside that parenthetical enumeration but inside the leading "Non-zero
exit" phrase, so the step's behavior on exit 3 was ambiguous, and the most likely reading routed
it through the unconditional-defer branch -- bypassing the pre/post `--findings` baseline
comparison the checkpoint's other branches exist to consult. The consequence: a pre-existing
failure that baseline comparison is designed to tolerate would instead defer every remaining task,
every cycle. A distinct exit code was chosen specifically so a follow-up task can route exit 3
through the existing baseline-comparison branches with a small, targeted edit rather than a
redesign -- **that follow-up has now landed**: `scripts/orchestrate-cycle-plan.sh`'s inter-cycle
redeploy checkpoint (the live implementation `skill-orchestrate/SKILL.md`'s Stage MT-3 step 7
delegates to -- the prose has since collapsed into a single delegated call, so the live edit
target was `scripts/orchestrate-cycle-plan.sh`, not `skills/skill-orchestrate/SKILL.md` itself)
now captures `deploy-headless.sh`'s exit code explicitly, excludes ONLY exit 1/2 from the
baseline comparison, and falls through to it for exit 0 and exit 3 alike -- matching
`context/patterns/batch-orchestration-guardrails.md`'s "### The Inter-Cycle Redeploy Checkpoint"
subsection, which is the authoritative statement of the contract this paragraph only summarizes.

**The live consequence, disclosed rather than discovered in production.** As of this correction,
doc-lint (gate 3, a *fast* gate -- `--skip-slow` does not hide it) reports pre-existing issues in
this repo's own source store, and gate 8 (deferred inline, but not by a full `verify-deploy.sh`
run) has pre-existing failing suites. Both predate this correction and are unrelated to it. The
practical effect: every `deploy-headless.sh` invocation exits 3 until those pre-existing failures
are fixed. That is the intended behavior -- surfacing a previously-invisible condition is the
whole point of wiring verification in -- not a regression introduced here. The sanctioned interim
response, until the pre-existing failures are fixed, is to inspect the named failure and fix it;
reverting the inline call is not the sanctioned response merely because it now reports truthfully.

**Additive and opt-in: a post-deploy consumer-freshness report.** After the verify-deploy call
above (on BOTH the exit-0 and exit-3 branches — both mean the tree WAS modified),
`deploy-headless.sh` additionally calls `scripts/check-consumer-freshness.sh --stale-only`, but
ONLY when `--consumer-report` is passed explicitly — default OFF. When run, it is fully guarded
(only when the deployed checker exists; its own exit code can never propagate into
`deploy-headless.sh`'s own exit code). This is purely additive output — see the "Tier 3"
subsection under `## Detecting When You're Stale` below for the full design — and does NOT
change the 0/1/2/3 exit-code contract documented above in any way. Confirmed at RUNTIME (not
merely by static reading) that this guard holds, via a traced scratch-target deploy against this
repo's own real, populated consumer registry. The walk was moved off the blocking `/orchestrate`
inter-cycle redeploy checkpoint path because it is report-only and no caller reads its output —
absent `--consumer-report` the checkpoint pays none of the walk's wall-clock cost.

**The `RESULT=`/`CONSUMERS_STALE=` marker vocabulary — the caller-facing contract for three
outcomes that are NOT the same thing.** `deploy-headless.sh` emits exactly one
`[deploy-headless] RESULT=<token>` line before its final exit, so a caller can read the outcome
without parsing prose or re-deriving it from the exit code alone:
- `RESULT=not_landed` — exit 1 or 2: the deploy did not land at all.
- `RESULT=landed_verify_clean` — exit 0: the deploy landed and `verify-deploy.sh` is clean.
- `RESULT=landed_verify_red` — exit 3: the deploy landed but `verify-deploy.sh` reported one or
  more findings. `deploy-headless.sh` itself does not distinguish a pre-existing finding from a
  newly-introduced one at this layer — that distinction is exactly what
  `context/patterns/batch-orchestration-guardrails.md`'s "### The Inter-Cycle Redeploy Checkpoint"
  baseline comparison (and `command-gate-out.sh`'s identical rc==6 handler) exist to make, one
  layer up.

Separately, `[deploy-headless] CONSUMERS_STALE=<n>` reports the count of stale/cannot-verify rows
from the consumer-freshness check above — the third confound (deploy did not land / deploy
landed with a red gate / OTHER, already-known consumer repos are behind). This marker is
opt-in: it is emitted ONLY when `--consumer-report` is passed (and, as before, only when the
deployed checker exists) — absent that flag, the line is never printed at all. When emitted, it
is report-only, by construction can never influence `RESULT=` or the exit code (see the
confirmed-at-runtime guard immediately above), and exists purely so a caller that opts in does
not have to count non-empty report lines by hand.

**`line_count` is now derived at deploy time, never hand-edited.** Before the nvim deploy
invocation, `deploy-headless.sh` runs the deployed `generate-context-line-counts.sh --write`
against `$TARGET`, guarded on `$TARGET/agent-system/extensions` existing (an ordinary consumer
repo, with no source-store checkout, silently no-ops here) and on the deployed regenerator itself
existing (a bootstrap-first-ever deploy silently no-ops too, matching
`check-consumer-freshness.sh`'s own guard convention). Every repair is reported, never silent —
the `validate-artifact.sh --fix` / D-A auto-repair-reporting precedent — on both the repaired and
the clean path, and a durable `index_line_count_auto_repair` row is appended to
`specs/events.jsonl` via `events-append.sh`. The declared `line_count` field itself is NOT
removed: `validate-context-budgets.sh`, `validate-index.sh`, `validate-context-index.sh`, and
`install-extension.sh` all read it for token-budget math, so it remains a real, consumed field —
only its maintenance burden moves from a human's editor to this pre-deploy repair step.
`check-extension-docs.sh`'s Rule R (the drift tripwire) is unchanged in behavior; its mismatch and
missing-key failure messages now additionally name the remedy command for a reader running the
lint standalone, outside a deploy.

## What This Means for Automation

- **Source-store edits still do not deploy themselves.** Edits under
  `agent-system/extensions/**` are the durable, version-controlled truth; the deployed `.claude/`
  tree reflects them only after a regeneration -- interactive or headless -- actually runs.
- **A stale deployed tree remains an expected state**, and doc-lint's core deploy-drift lane
  (`check-extension-docs.sh`) surfaces it. What has changed is the remedy: drift is now
  resolvable by a script, not only by a human at a keyboard.
- **Verifying deployed behavior still takes two gates**: the regeneration, then real usage for
  anything hook-driven. Inspecting source-store code alone never establishes either. Use
  `scripts/verify-deploy.sh` for the first gate; the second requires actual command invocations.

## Detecting When You're Stale

The staleness described throughout this document was never a loader defect. `loader.lua`'s
`copy_category` force-overwrites every declared file on every load; `installed_files` is
write-only bookkeeping that no code path ever consults as a copy gate; `manager.resync_all` calls
`manager.load(force = true)` with zero diffing. Regeneration is deliberately pull-only by design
-- a consuming repo's `.claude/` tree freezes at its last manual reload with no ambient signal
when the source store moves on. What follows is the detection half that closes that silence,
without touching the copy engine at all.

**The write side.** `state.lua`'s `mark_loaded` (the single writer of every
`.claude-extensions.json` entry, called from `init.lua`'s `manager.load`) stamps a
`source_git_head` field alongside the pre-existing `source_dir` field on every load. The value is
the path-scoped source-store revision -- `git -C <source_dir> rev-parse --show-toplevel`, then
`git log -1 --format=%H -- <source_dir>` against that toplevel -- never the source-store repo's
whole `HEAD`. Path-scoping is deliberate: it prevents unrelated churn elsewhere in the source
store from firing a false warning for an extension whose own files haven't moved.

**The read side.** `scripts/check-deploy-freshness.sh` is a small, standalone, always-`exit 0`
script invoked non-blockingly from `command-gate-in.sh`'s `gate_in` (CHECKPOINT 1, the one path
every ordinary command already crosses), guarded on the deployed checker's own existence so a
tree too stale to carry it yet is a silent no-op. For each extension entry carrying both fields,
it recomputes the same path-scoped revision and, on mismatch, prints one WARN line to stderr
naming the stale extension and the regeneration remedy (`deploy-headless.sh`, or the picker's
`[Reload All]`/`[Regenerate]`), plus a pointer to `verify-deploy.sh --findings` for per-file
detail. It never blocks, aborts, retries, or auto-redeploys anything.

**Why silence, not a "cannot verify" notice, is correct.** The checker prints nothing at all --
not even a summary line -- in every case where staleness cannot be established: a missing
`source_git_head` (every deploy from before this fix), a `source_dir` that no longer exists or
sits outside any git repository, or a recomputed revision that comes back empty. "Unknown" must
never read as either "confirmed fresh" or an alarm; a notice for the unverifiable case would
train users to distinguish two silences by memory, which is worse than one silence.

**Limitations, by design.** The signal is commit-granular, not per-file: a deploy taken from a
dirty source-store working tree stays technically "fresh" by this check even after that dirty
edit is later committed and its `HEAD` moves on, until the next reload restamps it. It is also
single-machine: `source_dir` is an absolute, machine-local path, so a relocated checkout or a
foreign machine's source store falls into the same "cannot verify, stay silent" branch as a
missing field. Neither limitation is a defect to fix here -- `verify-deploy.sh`'s eleven
content-diffing gates remain the deep-dive companion for per-file drift; this check is the
preflight-cheap companion that tells a user regeneration is worth running at all.

**A now-three-tier staleness model.** `check-deploy-freshness.sh` is TIER 1: silent, advisory,
CHECKPOINT-1-only (its one sanctioned advisory caller, `command-gate-in.sh`), ALWAYS exits 0,
and is never a gate -- everything described in this section above. TIER 2 is the postflight
completion-deploy gate inside `scripts/update-task-status.sh` (the "## Automated Exception: The
Postflight Completion-Deploy Gate" subsection above): BLOCKING, evidence-gated on a task's own
`modified_files` actually overlapping `agent-system/extensions/**`, and reachable only at
postflight/`implement` time. TIER 3, described in full immediately below, is the source-repo-
initiated fleet report: opt-in, reports the WHOLE known consumer fleet, and is the only tier that
looks outside this repo at all. All three tiers share ONE comparison algorithm, factored into
`scripts/lib/deploy-freshness-lib.sh` -- tier 1 sources its `deploy_freshness_stale_names`
function, tiers 2 and 3 both source its `deploy_freshness_status` function -- so "is the deploy
stale" is computed exactly once, not reimplemented per tier. Tier 1's always-exit-0 contract must
never be mistaken for a gate; tier 2 is the gate; tier 3 is opt-in and reports only.

### Tier 3 (fleet report, source-repo-initiated, opt-in)

Tiers 1 and 2 above both answer "is THIS repo's own deployed tree stale relative to the source
store" -- a repo checking itself. Neither has any visibility into the fleet of OTHER repos that
also consume this source store; each of those consumer repos pulls independently and freezes at
whatever it last reloaded, with no ambient signal back to this repo when it falls behind. Tier 3
closes that visibility gap, from the source-repo side, without inverting the pull-only
architecture this document establishes: it never writes to, deploys into, or otherwise mutates
any consumer repo. Every consumer interaction is a read of that consumer's own
`.claude-extensions.json`.

**The registry.** `context/reference/known-consumer-repos.json` is a small, git-tracked,
hand-maintained JSON file naming this source store's known consumer repos (`consumers[]`, each
`{path, note}`) and a short list of `discover_roots[]` for the reconciliation mode below. It also
deploys into every consumer's own `.claude/context/reference/` directory, because
`manifest.json`'s `provides.context` declares `reference` as a whole directory entry -- that
deployed copy is purely informational and is never authoritative for any consumer's own
behavior; the file's own top-of-file `_comment` field states this. The registry is deliberately
NOT derived by a routine filesystem scan on every invocation -- explicit registration means a
temporarily-unreachable consumer (renamed, on another disk, not yet cloned on this machine)
never silently drops out of the audit, unlike a scan would.

**The report.** `scripts/check-consumer-freshness.sh` reads the registry and, for each
registered consumer, enumerates that repo's OWN recorded extensions and calls
`deploy_freshness_status(repo_path, ext_name)` per extension (the registry stores only a path,
never a duplicated per-extension list). Unlike tier 1's deliberate silence, this is an
explicitly-invoked audit command whose entire value is completeness: it reports EVERY registered
entry, including `MISSING` (path absent), `NOEXTSTATE` (no `.claude-extensions.json` there yet),
and `CANNOTVERIFY` rows tier 1 would silently omit. `--stale-only` prints only non-fresh rows
(used by the deploy-headless.sh hook below); `--discover` runs the bounded reconciliation scan
described next. Exit codes: `0` no registered consumer is stale, `1` at least one is, `2`
registry missing/unparseable or a usage error -- callers that must never be affected are expected
to invoke it guarded (`... || true`), the same convention `command-gate-in.sh` already uses for
tier 1.

**`--discover` reconciliation.** The registry is itself a smaller, bounded version of the same
staleness-of-knowledge problem this document is about: a new consumer that never gets registered
stays invisible to the primary report path forever. `--discover` scans `discover_roots[]` for
on-disk `.claude-extensions.json` files whose `source_dir` traces back to this repo, diffs the
result against the registry, and prints `UNREGISTERED` (found on disk, not registered) or
`REGISTERED-BUT-ABSENT` (registered, not found by this scan -- informational, never
auto-removed) lines, plus the exact JSON object to add for each `UNREGISTERED` hit. It never
edits the registry itself. This is the expensive path the registry exists to avoid paying
routinely -- manual/occasional only, and never called from `deploy-headless.sh`.

**The post-deploy hook.** `deploy-headless.sh`'s trailing verification block (see
`### deploy-headless.sh's Inline Verification and Exit Code 3` above) additionally calls
`check-consumer-freshness.sh --stale-only`, but ONLY when `--consumer-report` is passed
explicitly (default OFF) -- on both the exit-0 and exit-3 branches when it does run, fully
guarded so its own outcome can never affect `deploy-headless.sh`'s exit code. A deploy in this
repo with `--consumer-report` ends by naming which known consumers are now stale relative to
what was just deployed -- entirely additive output, changing nothing about the 0/1/2/3 contract.
Absent that flag (the default), the walk does not run at all, which is deliberate: it is
report-only and no automated caller reads its output, so it was moved off the blocking
`/orchestrate` inter-cycle redeploy checkpoint path to remove its wall-clock cost from that
critical path.

**The tier-1 consecutive-ignore escalation.** A per-repo tier-1 WARN nobody acts on is not
functioning as a warning. `check-deploy-freshness.sh` now tracks a consecutive-invocation streak
counter at `<repo_root>/specs/.freshness-warn-streak.json` (ephemeral runtime file -- see
`context/standards/orchestrator-runtime-files.md`'s class table): incremented on every run that
fires at least one WARN, reset (file deleted) the moment a run fires none. At streak `>= 5`, an
additional escalated banner is printed naming the consecutive count and the remedy, on top of
(never instead of) the existing per-extension WARN lines; below the threshold, output is
byte-identical to before this feature existed. The counter is a consecutive
COMMAND-INVOCATION count, not wall-clock days, since the check only ever fires on an invocation.
A `CANNOTVERIFY` result also resets the counter, inheriting tier 1's existing deliberate
collapse of FRESH and CANNOTVERIFY into the same silence rather than introducing a third
distinction. This escalation remains **exit-0 and non-blocking** -- tier 2 already provides the
blocking backstop for this repo's own commits, and a cross-repo blocking mechanism would have no
enforcement lever anyway (this repo cannot compel a consumer's own commands to run).

### Tier 1, refined: the per-dispatch surface and dispatch-brief injection

**The gap this closes.** Tier 1 above already detects staleness non-blockingly, but only once
per top-level command (`command-gate-in.sh`'s CHECKPOINT 1) and only onto the orchestrating
session's own stderr. A stale extension can therefore be WARNed about at the top of a session
and then, several dispatches later, a spawned agent still reads the stale documented behavior of
that extension's deployed files -- the WARN never reached the context that actually acts on the
stale content. This is a placement/granularity gap in an existing, correctly-designed detector,
not a missing detector: no new comparison algorithm was needed, and none was added.

**The fix: re-fire the SAME comparison at per-dispatch granularity.** `core/scripts/skill-base.sh`
sources `scripts/lib/deploy-freshness-lib.sh` (the same two-candidate resolution order it already
uses for `common.sh` and `task-lookup-lib.sh`) and exposes a thin wrapper,
`skill_deploy_freshness_stale_names`, around that library's existing `deploy_freshness_stale_names`
function. `skill_preflight_update` -- the function every research/plan/implement dispatch calls
once per skill/agent dispatch, confirmed live at `orchestrate-cycle-plan.sh`'s per-task
live-dispatch loop and at every direct (non-orchestrate) skill call site that reaches
`skill_preflight_update` -- calls this wrapper unconditionally and, when the result is
non-empty, emits a loud, named WARN block to stderr: the stale extension names, the statement
that a fresh-looking file elsewhere in the SAME deployed tree does not mean the tree is current
(the partial-staleness trap -- see below), and the `deploy-headless.sh` redeploy remedy, never a
hand-patch instruction. Every failure mode -- library not resolvable at either candidate path, no
`.claude-extensions.json`, missing `jq`/`git`, or a genuinely fresh tree -- degrades to silence
and `skill_preflight_update` always returns 0, exactly mirroring `check-deploy-freshness.sh`'s
own always-exit-0 contract. This call site deliberately never touches
`specs/.freshness-warn-streak.json`: that counter is a consecutive-COMMAND-invocation count owned
exclusively by `check-deploy-freshness.sh`, and a per-dispatch call site incrementing it would
corrupt its documented meaning.

**The orchestrate-mode enhancement layered on top: dispatch-brief injection.** Because a WARN on
the orchestrating session's own stderr still never reaches a SPAWNED agent's own context,
`orchestrate-build-dispatch.sh`'s Stage 3.5 (the same stage that already computes
`memory_context`, `lit_context`, and `hard_contracts_block`) reuses the identical
`skill_deploy_freshness_stale_names` call -- never re-deriving the library call a second time --
and, when the list is non-empty, emits a `<deploy-freshness-context>` block into the generated
dispatch file, following the exact same "build a variable, emit only when non-empty" pattern
those other blocks already use. A dispatch built when nothing is stale is byte-identical to one
built before this feature existed. This is a orchestrate-mode-ONLY enhancement on top of the
per-dispatch base layer above, not a replacement for it: a directly-invoked skill run (outside
`/orchestrate`) still gets the `skill_preflight_update` stderr WARN, but never the injected
dispatch-file block, since only `orchestrate-build-dispatch.sh` builds a dispatch file at all.

**The partial-staleness trap, named explicitly in both surfaces.** The incident motivating this
refinement involved a deployed tree where one file (`git-snapshot.sh`) was byte-identical to
source while a different file in the SAME tree
(`lean-implementation-agent.md`) was months stale -- an operator who spot-checked the first file
correctly concluded "this repo's deploy is fresh" and, from that true premise about ONE file,
wrongly generalized to the whole tree. Both the stderr WARN and the injected dispatch-file block
say this in words: a fresh-looking file elsewhere in the same deployed tree does not imply the
tree is current, because staleness here is computed **per extension**, not per whole-tree.

**Rejected alternatives, and why.**
- **A new whole-tree content-hash or manifest-digest fingerprint.** Rejected as redundant: the
  existing per-extension, path-scoped `source_git_head` comparison (`git log -1 --format=%H --
  <source_dir>`) already operates at extension-directory granularity, so a single changed file
  inside an otherwise-untouched extension already moves the recomputed revision for that
  extension. A dedicated regression fixture (a two-file extension with only one file changed,
  alongside a second, wholly-untouched extension in the same consumer tree) pins this directly:
  the changed-file extension reads `STALE`, the untouched one reads `FRESH`, and
  `deploy_freshness_stale_names` lists exactly the former. Building a second whole-tree
  fingerprint mechanism would duplicate detection work the library already does, for no
  additional coverage.
- **Hard-blocking or refusing a dispatch on a `STALE` result.** Rejected for now: this would
  recreate the same class of cost/unactionability problem the tier-3 fleet walk's removal from
  the blocking path was meant to solve, and would additionally require preserving the
  `STALE`-vs-`CANNOTVERIFY` distinction carefully at a blocking call site (tier 2's postflight
  gate already does this correctly for this repo's own commits; a preflight block would need the
  same care). Recorded as a deliberately-rejected-for-now alternative, not implemented. If a
  future need justifies it, tier 2's own gate is the nearer precedent to extend, not a new
  mechanism at this call site.
- **Restoring the tier-3 fleet-wide walk to a blocking path.** Explicitly out of scope; the
  opt-in `--consumer-report` design (see above) stays exactly as it is. The per-dispatch surface
  in this section answers a different question ("is THIS repo's OWN deploy stale, at the moment a
  dispatch is about to read from it") than tier 3 ("which OTHER repos in the known-consumer
  fleet have fallen behind"), and the two are not substitutes for each other.

**Why this is not just another warning nobody acts on.** The tier-1 consecutive-ignore
escalation above remains the sanctioned model for a louder default if the per-dispatch WARN
itself turns out to be insufficiently actionable over time; no second, competing escalation
mechanism was introduced here. The distinguishing feature of this refinement is placement, not
volume: the signal now lands inside the SAME context the dispatched agent reads to decide what
to do next, at the moment that context is being assembled -- which is the specific gap that
allowed a previously-fixed, previously-closed defect to remain live and misleading in a
consumer's deployed tree indefinitely.

## Merge Semantics That Regeneration Cannot Fix

Two deploy behaviors are structural and survive any number of regenerations:

- **Install-once root files.** `settings.json` and `settings.local.json` are listed in
  `INSTALL_ONCE_ROOT_FILES`; the `root_files` category's descriptor-driven copier
  (`loader.lua`'s `M.copy_category`, keyed by `CATEGORY_DESCRIPTORS.root_files.install_once`)
  skips them entirely once the target exists. Anything added only to `root-files/settings.json`
  can therefore never reach an already-initialized repo. Additions intended for existing repos
  belong in `merge-sources/settings-hooks.json`, which is what the merge step actually reads.
- **Add-only, object-granularity dedup.** The merge compares whole matcher objects via
  `vim.deep_equal` and only declines to add -- it never removes. A duplicate command entry
  already present in a deployed tree survives every future merge and requires manual removal.
  Fresh trees are unaffected: a first-time deploy produces exactly one entry.

The practical consequence for authors: register each new hook as its **own dedicated
single-command matcher object**. That shape is idempotent across re-merges, whereas appending a
command into an existing shared matcher makes that object non-equal to the source and causes its
siblings to be registered twice.

### Round-Trip Fidelity of settings.local.json (measured)

A prior single observation recorded a content-lossy `--wipe` merge: a dropped `hooks.PreToolUse`
block and a dropped `mcpServers` block. Two independent re-check rounds have since measured the
round-trip fidelity of `settings.local.json` across `--wipe` empirically, rather than relying on
the code-reading claim this document previously asserted.

**Measurement**: 24 `--wipe` invocations across 12 wipe-pairs, run against an isolated scratch
copy of the repository (never the live deploy tree) in the most recent round, plus 3 pairs from
an earlier round -- **15 pairs cumulative**. Each pair was compared three ways: semantic equality
(`jq -S`, recursively sorted keys, then hashed), an explicit structural presence check on
`hooks.PreToolUse`, `hooks.Stop`, `mcpServers`, `permissions.allow`, `permissions.deny`, and
`enabledMcpjsonServers` (validated against a positive control -- synthetic deletion of
`hooks.PreToolUse` and `mcpServers` -- before its "0 dropped" result was trusted), and spot-check
raw byte diffs.

**Result**: 0 of 15 cumulative pairs showed any dropped key, array element, or block. Every
observed difference across all pairs was pure key/array **reordering**, attributable to Lua
`pairs()` iteration nondeterminism across process runs -- semantically identical under `jq -S`,
never byte-identical. The most recent round additionally varied the pre-existing
`settings.local.json` state across six variants (baseline, extra permissions, reversed/scrambled
key order, ~2.5x bloated content, a minimal file stripped to only `hooks` and `mcpServers`, and a
pre-seeded duplicate `PreToolUse` matcher block deliberately exercising the matcher-merge/dedup
code path) and found no correlation between pre-existing state and loss.

**Candidate root cause for the original observation**: commit `1692e33e8` moved the settings
snapshot restoration in `manager.regenerate` to run *before* the extension reload loop; the
pre-fix ordering (restore-after-load) would produce exactly the observed failure shape by letting
the reload loop's own settings-fragment merges get clobbered by a later restore. The measured
sampling above ran entirely against the post-fix code, and its 0/15 result is consistent with
that fix being effective.

**Known limitation**: all sampling was strictly serial, against an idle target, in a single
process. The `specs/.deploy-lock` mutex `--wipe` and non-destructive regeneration both acquire is
fail-open/non-blocking by design (the same acquire/warn-and-proceed shape as
`specs/.commit-lock`) -- see `deploy-headless.sh` and
`context/patterns/batch-orchestration-guardrails.md`, which already document that a genuinely
concurrent `--wipe` "could corrupt the `.claude/` tree." A `--wipe` racing another `--wipe`, or a
`--wipe` racing a concurrent hand-edit of `settings.local.json`, on the same target is **outside**
what this measurement covers, and remains an untested, narrower hypothesis distinct from the
plain-repeated-wipe question this measurement answers.

Full methodology, per-pair results, and the positive-control validation are recorded in the
originating research report,
`specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`.

## Root-Resolution Guard for Core Scripts

Any core script under `agent-system/extensions/core/scripts/` that resolves its repo root as
`"$(cd "${SCRIPT_DIR}/../.." && pwd)"` is correct ONLY once deployed (`.claude/scripts/` or
`.opencode/scripts/`, two levels under the repo root). Run from the source store, the same
expression silently resolves to `agent-system/extensions/` and proceeds against a bogus root.
Every such script MUST source the shared guard immediately after that root computation:
`. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1` -- the trailing `|| exit 1` is required
because several core scripts do not use `set -e`, so a bare `source` of a missing/failing
helper would otherwise print an error and continue unguarded. `deploy-root-guard.sh` validates
its own `BASH_SOURCE[0]` location structurally (no filesystem I/O) against exactly two accepted
deploy-tree grandparents, `.claude` and `.opencode` -- never hardcode just one. Do NOT use
`git rev-parse --show-toplevel` as a substitute: it would silently succeed by finding the true
repo root, masking the invocation-context error this guard exists to surface.

## Related Documentation

- `scripts/deploy-headless.sh` -- scripted regeneration for non-interactive contexts
- `scripts/verify-deploy.sh` -- checks a deployed tree against its source store
- `scripts/check-deploy-freshness.sh` -- the non-blocking staleness check documented in
  `## Detecting When You're Stale` above
- `lua/neotex/plugins/ai/shared/extensions/state.lua` -- `mark_loaded`'s `source_git_head` write
  side backing the same section
- `scripts/tests/test-deploy-freshness.sh` -- fixture suite pinning both directions and every
  silent-skip branch of the freshness check
- `specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`
  -- the empirical `--wipe` round-trip-fidelity measurement backing the
  `### Round-Trip Fidelity of settings.local.json (measured)` subsection above
- `docs/guides/creating-extensions.md` -- extension authoring guide (manifest schema, file
  templates, deployment categories)
- `scripts/check-extension-docs.sh` -- doc-lint gate; its core deploy-drift lane surfaces
  never-deployed core scripts/hooks
- `context/patterns/batch-orchestration-guardrails.md` -- the authoritative inter-cycle redeploy
  checkpoint contract (trigger, failure contract, sequencing, idempotence guard) that this
  document's `## Automated Exception` subsection reconciles against the deliberate-invocation
  constraint above; also the authoritative home of `### The Postflight Completion-Deploy Gate`,
  which this document's second `## Automated Exception` subsection reconciles the same way
- `scripts/lib/deploy-freshness-lib.sh` -- the shared freshness-comparison algorithm both tiers
  of the two-tier staleness model above source (`deploy_freshness_stale_names` for tier 1,
  `deploy_freshness_status` for tier 2)
- `scripts/tests/test-postflight-deploy-gate.sh` -- fixture suite pinning the postflight
  completion-deploy gate's six conclusiveness branches, the check-only contract, and the
  no-worse-than-baseline verification tier this task's own dogfooded completion demonstrates
- `scripts/check-consumer-freshness.sh` -- the TIER 3 source-repo-initiated fleet freshness
  report and `--discover` reconciliation mode, documented in full in the "Tier 3" subsection
  above
- `context/reference/known-consumer-repos.json` -- the git-tracked known-consumer registry Tier
  3 reads
- `scripts/tests/test-consumer-freshness.sh` -- fixture suite pinning Tier 3's report
  classification, exit codes, `--stale-only`/`--discover` behavior, and the no-write invariant
  against consumer repos
- `scripts/lib/deploy-baseline-lib.sh` -- the shared `deploy_findings_snapshot` /
  `deploy_baseline_new_findings` algorithm both `command-gate-out.sh` and
  `orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint source, so the two cannot
  re-diverge
- `scripts/generate-context-line-counts.sh` -- the `wc -l` regenerator `deploy-headless.sh` now
  runs (guarded, `--write`) before every deploy, backing the `line_count` auto-repair paragraph
  above
