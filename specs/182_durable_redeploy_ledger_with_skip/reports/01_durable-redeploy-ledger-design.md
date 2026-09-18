# Research Report: Task #182

- **Task**: 182 - Add a durable redeploy ledger with content-hash and recency skip to the checkpoint
- **Started**: 2026-09-18T00:00:00Z
- **Completed**: 2026-09-18T00:00:00Z
- **Effort**: 4 hours (per TODO.md estimate)
- **Dependencies**: Task 181 (completed — gate-depth/verdict-logic unification), Task 193 (completed), Task 213 (completed)
- **Sources/Inputs**: Codebase (orchestrate-cycle-plan.sh, deploy-baseline-lib.sh, deploy-freshness-lib.sh, batch-orchestration-guardrails.md, orchestrator-runtime-files.md, test-orchestrate-cycle-plan.sh), git history, specs/TODO.md, specs/archive/181
- **Artifacts**: reports/01_durable-redeploy-ledger-design.md (this report)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The Inter-Cycle Redeploy Checkpoint (`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  lines ~695-865) has NO cross-invocation memory today. Its only idempotence guard,
  `mt_state_file.deployed_critical_paths`, lives in a session-scoped file
  (`specs/.orchestrator-multi-state-{session_id}.json`, gitignored, reset to `[]` every
  `/orchestrate` invocation) and therefore cannot prevent a second, fresh `/orchestrate`
  invocation from re-running a full deploy+verify (observed cost: ~10 minutes) against content
  that was already deployed and verified clean moments earlier in a prior invocation.
- Task 181 (dependency, already completed) fixed the checkpoint's *verdict* logic (confirmation/
  attribution filters, depth-disagreement reporting) but explicitly did NOT build a
  cross-invocation ledger — it named that as split-out, owed follow-up work. That follow-up
  is what this task is scoped to build. **Important correction for planning**: the "its own
  task" quote in `batch-orchestration-guardrails.md` (line 706) that the dispatch text points at
  is NOT inside the "### The Inter-Cycle Redeploy Checkpoint" subsection — it is one section
  down, inside the sibling "### The Postflight Completion-Deploy Gate" subsection, and it refers
  to a *different*, still-unclaimed follow-up: widening Stage MT-3 step 7's trigger predicate
  from the curated critical-path list to a broader `agent-system/extensions/**` predicate. Do
  not conflate the two — task 182 must not attempt that widening; it only needs to add durable
  persistence to the EXISTING critical-path-keyed trigger.
- Two closely related, already-durable precedents exist in this codebase and should shape the
  design rather than be reinvented: (1) `.claude-extensions.json` (repo root, git-tracked)
  already carries a per-extension `source_git_head` — a durable "as of which commit was this
  content last deployed" hash, read via the existing, already-tested
  `scripts/lib/deploy-freshness-lib.sh` (`deploy_freshness_status`); (2) the
  `orchestrator-runtime-files.md` two-class tracking policy (ephemeral vs. durable-provenance)
  is the established framework this task's new ledger file must be slotted into — it does not
  cleanly fit either existing class and should be treated as a candidate third pattern
  (a durable, cross-invocation, content-addressed cache with no per-dispatch identity), decided
  explicitly during planning rather than left unclassified.
- The self-modifying-task class (the task's own edits are what change the critical-path content)
  cannot be served by a hash-equality skip alone, exactly as the dispatch text states — every
  cycle where such a task commits produces a NEW commit/hash. The recency-window or
  "this deploy already covers my own commit" attribution check is a structurally different
  mechanism from the hash-equality skip and both are needed; this report lays out the concrete
  data this second mechanism needs (a monotonic ordering between "content committed" and
  "content last successfully deployed+verified") and recommends git commit-order comparison
  over a bare timestamp recency window, with a timestamp recency window as a secondary/fallback
  signal, not the primary one — see Findings/Recommendations below for the reasoning.
- The existing Group 11 test harness in `scripts/tests/test-orchestrate-cycle-plan.sh` stubs
  `deploy-headless.sh` and `verify-deploy.sh` under a synthetic `$WORKDIR/.claude/scripts/`
  tree that is **not** a git repository. A git-commit-hash-based content identity (mirroring
  `deploy-freshness-lib.sh`'s approach) will need either a small `git init` fixture added to
  the Group 11 setup, or a git-independent content hash (e.g. `sha256sum` over the matched
  critical-path files) chosen specifically for testability. This is a concrete, low-risk
  implementation decision the plan should make explicitly, not discover mid-implementation.

## Context & Scope

Task 182 asks for a durable, cross-`/orchestrate`-invocation ledger recording {timestamp,
source-store content hash, verify outcome} for the last redeploy, so the Inter-Cycle Redeploy
Checkpoint can skip a redeploy when either (a) the source-store content targeted by the
checkpoint's trigger is unchanged since the last successful, clean deploy, or (b) that last
successful deploy is recent enough that re-running the ~10-minute deploy+verify pipeline again
this cycle is not justified. It must NOT become a disabled gate: a skip must always be backed by
positive ledger evidence, never by absence of evidence. It must also specifically handle the
self-modifying-task class (a task whose own `file_scope`/commits touch the orchestrator's own
critical scripts) with test coverage, since a naive hash-only skip provably cannot help that
class. The `context/patterns/batch-orchestration-guardrails.md` "### The Inter-Cycle Redeploy
Checkpoint" subsection must be updated to describe the new ledger contract and to correct the
existing "Idempotence guard" paragraph's characterization of `deployed_critical_paths` as
purely within-invocation. Test coverage additions land in
`scripts/tests/test-orchestrate-cycle-plan.sh`. All source edits land under
`agent-system/extensions/core/**` (never `.claude/**`).

## Findings

### Codebase Patterns

**The checkpoint's exact trigger and mutation points** (all in
`agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`):

- Trigger predicate (line ~731-745): `cycle_modified_files` (accumulated by the PRIOR cycle's
  postflight composer, consumed at the START of the current cycle — see the file's own
  "Inter-cycle redeploy checkpoint — timing note" comment above line 115) is compared, via
  `FILE_SCOPE_OVERLAP_JQ_DEFS`'s `scopes_overlap_first`, against the `scope_roots x
  critical_paths` expansion of `context/reference/orchestrator-critical-paths.json` (16 curated
  critical paths x 3 scope roots: `agent-system/extensions/core`, `.claude`, `.opencode`),
  filtered to exclude anything already in `mt_state_file.deployed_critical_paths`
  (within-invocation dedup). A non-empty `matched_json` AND `dry_run != "true"` fires the
  checkpoint.
- The checkpoint body (lines ~746-865) is the exact insertion point for a ledger consult:
  `pre_findings=$(deploy_findings_snapshot ...)` is the FIRST expensive call in the branch. A
  hash/recency skip must be checked and must short-circuit *before* this line (and before
  `bash "$SCRIPT_DIR/deploy-headless.sh"`), otherwise the expensive work the skip exists to
  avoid still runs.
- On both success branches (verify-clean and pre-existing-findings-proceed / branch (c)),
  `mt_set --argjson mp "$matched_paths_json" '.deployed_critical_paths = ((.deployed_critical_paths + $mp) | unique)'`
  is where the SESSION-scoped record is written today. A new durable-ledger write belongs
  alongside these calls (or immediately after the block, keyed off the same success
  determination), NOT inside `mt_set` (which targets `mt_state_file`, not a durable file).
- `matched_paths_json` (`echo "$matched_json" | jq -c '[.[].path]'`) is exactly the path list
  whose content should be hashed — but note it currently contains entries from ALL THREE scope
  roots (e.g. both `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` and
  `.claude/scripts/orchestrate-cycle-plan.sh`). Only the `agent-system/extensions/core/**`
  members are meaningful as a *source-store* content hash (the other two are the disposable
  deploy mirror and are never supposed to be hand-edited per
  `rules/source-store-deploy-boundary.md`); the plan should filter to that scope root before
  hashing, or hash the curated `critical_paths[].path` list resolved once against
  `agent-system/extensions/core` specifically (mirroring how `.claude-extensions.json`'s `core`
  entry's `source_dir` is exactly `agent-system/extensions/core`).
- `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"` (line 241) already resolves the repo root
  where `.claude-extensions.json` and `specs/` live — the natural anchor for wherever the new
  durable ledger file is placed.
- `dry_run` gating: every existing mutation in this script is gated on `dry_run != "true"`
  (`mt_save()` itself is a no-op under `--dry-run`). Any new ledger read may run under
  `--dry-run` (to preview a would-be skip in the dry-run table), but ledger WRITES must be
  gated the same way `deployed_critical_paths` already is, or `--dry-run` would corrupt durable
  state as a side effect of a report-only command.

**`deploy-baseline-lib.sh` (task 181's output, already sourced by this script)** exports
`deploy_findings_snapshot`, `deploy_baseline_new_findings`,
`deploy_baseline_confirm_new_findings`, `deploy_baseline_unattributable_findings` — this is the
vocabulary of "verify outcome" the ledger's `verify_outcome` field should be able to represent:
the checkpoint's own `verify_deploy_baseline_notices` entries already carry a rich shape
(`gate`, `pre_findings`/`post_findings`/`new_findings` counts, `post_exit`, `filtered`,
`flaky_count`/`flaky_findings`, `unrelated_count`/`unrelated_findings`, `blocking_count`), and
the `defer_ledger` entries carry `depth_disagreement`. The new durable ledger does not need to
duplicate this full detail — it needs enough to answer "was the last deploy at this content
clean enough to skip a repeat" — but its `verify_outcome` field should use a vocabulary
consistent with (ideally a strict subset/summary of) this existing one, not a new one invented
independently. A minimal recommended shape: one of `clean` (post-redeploy findings empty),
`pre_existing` (branch (c), findings existed before too), `filtered` (branch (c)-equivalent,
confirmed flaky/unrelated), or `blocking` (branch (b) — though a `blocking` outcome by
definition means the checkpoint deferred and control never reaches a "record success and
continue" point, so a `blocking` ledger entry would only ever be written, if at all, as a
negative/diagnostic record, never as skip-evidence).

**`deploy-freshness-lib.sh` (existing, unrelated consumer, NOT sourced by this checkpoint
today)** is the closest existing precedent for "durable content-hash-based freshness," and is
worth reusing/mirroring rather than reinventing:
- `deploy_freshness_status <repo_root> <extension_name>` returns `STALE`/`FRESH`/`CANNOTVERIFY`
  by recomputing `git -C <repo_toplevel> log -1 --format=%H -- <source_dir>` and comparing
  against `.claude-extensions.json`'s recorded `source_git_head` for that extension.
  `.claude-extensions.json`'s `core` entry's `source_dir` is exactly
  `agent-system/extensions/core` (verified: `jq '.extensions.core.source_git_head'
  .claude-extensions.json` returns a live commit hash, and the file is git-tracked — confirmed
  via the session's own git status showing it as a tracked, modified file, not an untracked
  one).
- This means "has anything changed in `agent-system/extensions/core` since the last deploy"
  is *already* a computed, tested, durable fact in this codebase, one `git log -1 --format=%H
  -- agent-system/extensions/core` away and one already-passing library function away.
  **Design option A** (recommended for evaluation in planning): reuse
  `deploy_freshness_status "$PROJECT_ROOT" "core"` as the CONTENT-HASH half of the skip
  decision (FRESH ⇒ nothing has changed in the whole `core` extension since the last deploy
  landed) and add the missing pieces — `verify_outcome` and a deploy timestamp — as new fields
  on `.claude-extensions.json`'s `core` entry (or a small sibling file keyed by the same
  `source_git_head`), rather than building an independent hash mechanism from scratch.
  Caveat: `.claude-extensions.json`'s `source_git_head` is scoped to the WHOLE `core`
  extension, not just the curated critical-path list, so it is a coarser (more conservative)
  hash than `matched_json`'s exact path set — it can only ever UNDER-skip (redeploy when a
  change landed outside the critical paths but inside `core`), never over-skip, which is the
  fail-safe direction this task's "do not disable the gate" mandate requires. **Design option
  B**: build an independent ledger scoped exactly to the checkpoint's own critical-path set,
  parallel to but separate from `.claude-extensions.json`. Both are legitimate; the tradeoff
  (coarser-but-reused vs. exact-but-new) should be an explicit planning decision, not an
  implementation-time default.
- `_deploy_freshness_status_one`'s CANNOTVERIFY fail-safe pattern (missing file, missing
  jq/git, non-git source_dir, empty computed head — never treated as either FRESH or STALE
  conclusively) is the right template for the new ledger's own read failure mode: an
  unreadable/malformed/missing ledger must read as "no evidence a skip is justified," i.e.
  behave exactly as if the checkpoint had never fired before (never as a silent skip and never
  as a silent forced redeploy-is-safe assumption either way — it must fall through to running
  the checkpoint normally).

**`orchestrator-runtime-files.md`'s two-class tracking policy** is the authoritative reference
for whether a new orchestrator runtime file should be git-tracked or gitignored, and this task's
new ledger does not cleanly fit either existing class:
- It is not "ephemeral, no freshness gate, corrupts state if git-restored" like
  `.orchestrator-multi-state-{session_id}.json` — the whole point is that its content (a hash +
  timestamp + outcome) is EXACTLY what it needs to be gated against, i.e. staleness IS the check
  itself, not an unchecked-trust hazard.
- It is not "per-dispatch audit trail" like `.return-meta.json`/`.orchestrator-handoff.json`
  either — it has no `dispatch_seq`/task identity, it is a single rolling record (or small
  append-only log) about the checkpoint's own history, not about one dispatch.
- It most resembles `.claude-extensions.json`'s `source_git_head`, which the tracking-policy
  doc does not enumerate at all (that file lives outside `specs/`, at the repo root, and is
  simply git-tracked application state, not itself part of the orchestrator-runtime-file
  taxonomy). If the plan creates an independent ledger file (Design Option B above) rather than
  extending `.claude-extensions.json`, it should be explicit in
  `orchestrator-runtime-files.md`'s Class Table about which class it belongs to (a strong
  argument exists for **durable, but NOT session-suffixed, and NOT git-tracked**: the ledger
  describes THIS machine's local `.claude/` deploy state, and `.claude/` itself is gitignored
  as a disposable local build artifact per `rules/source-store-deploy-boundary.md` — committing
  a ledger that describes one machine's local deploy history into shared git history would be
  describing state that is meaningless/misleading on a different clone or a different
  developer's machine, the same reasoning that keeps `.orchestrator-multi-state-*.json`
  gitignored). This reasoning favors a NEW gitignored-but-durable (not session-suffixed) file
  at, e.g., `specs/.orchestrator-deploy-ledger.json`, over extending `.claude-extensions.json`
  (which IS committed) — this is a real tension between "reuse existing tested machinery"
  (favors extending `.claude-extensions.json`) and "don't commit machine-local deploy history"
  (favors a new gitignored file) that the plan must resolve explicitly, not by default.

**The self-modifying-task class, concretely**: The checkpoint runs at the START of a cycle,
consuming the PRIOR cycle's `cycle_modified_files` (see the script's own "timing note" comment,
line ~115). A task whose implementation edits a critical path commits that edit at Stage MT-4
step 5.5, strictly before the checkpoint for the NEXT cycle can consult it (per the
"Sequencing" guarantee already documented in the guardrails doc). Within a single invocation,
`deployed_critical_paths`'s existing within-invocation dedup already prevents this exact path
from re-firing the checkpoint a second time in the SAME session even if a later cycle in that
same session touches it again (this is pre-existing, accepted behavior, not something task 182
changes). The actual failure mode this task must close is CROSS-invocation: the operator's
`/orchestrate` run ends (deferred, or the batch simply finishes), and is invoked again later
(fresh session, fresh `mt_state_file`, `deployed_critical_paths` resets to `[]`). If that new
invocation dispatches ANY task whose `cycle_modified_files` again overlaps the SAME critical
path — even one with zero actual content change since the last invocation's already-clean
deploy — the checkpoint fires a full, costly redeploy+verify again for content that provably has
not changed. A hash-equality skip DOES correctly handle this exact scenario (hash unchanged ⇒
skip) — this is the "ordinary case" the dispatch text refers to. The case a hash-equality skip
CANNOT handle is when the SAME self-modifying task's work spans multiple cycles/invocations and
each cycle's commit genuinely changes the critical-path content again (a new commit each time,
by construction) — here the hash always differs from the last-recorded ledger entry, so a
hash-only design redeploys every single cycle regardless of how recently the previous redeploy
succeeded. This is exactly where a recency/attribution mechanism is additionally required.
Recommend: prefer a git-commit-order check ("is the current critical-path-scoped git HEAD a
descendant of, or equal to, the commit the ledger last verified, AND was the delta introduced
entirely by the batch invocation currently running its own checkpoint" — closer to "the redeploy
that just landed already covers today's commit stream") over a bare wall-clock recency window,
because a pure recency window has no way to distinguish "this redeploy just happened and is
already covering my new commit" from "this redeploy happened five minutes ago against OLDER
content and a genuinely different, unverified change has landed since" — the dispatch's own
"DO NOT SIMPLY DISABLE THE GATE" mandate means a recency window used alone, without any
attribution to the specific commit(s) in question, risks becoming exactly a disabled gate with
extra steps. A defensible design combines both: the ledger's timestamp is used only as a
CAP (never skip if the last recorded successful deploy is older than some bound, regardless of
hash — protecting against silently trusting a very old record whose git-ancestor computation
might be expensive or ambiguous across rebases/history rewrites) while the actual go/no-go
decision for the self-modifying case is commit-ancestry-based, not clock-based.

### External Resources

No external web research was needed — this is a fully self-contained internal orchestration
mechanism with no external library/API surface. All relevant prior art is internal (see
Codebase Patterns above).

### Recommendations

1. **Insertion point**: add the ledger consult immediately after `matched_count -gt 0` is
   established and before `pre_findings=$(deploy_findings_snapshot ...)` (current line ~746).
   On a skip, emit a loud, evidence-naming stderr line (mirroring the existing banner style,
   e.g. `[orchestrate] REDEPLOY CHECKPOINT: skipped — ledger shows <hash> deployed clean at
   <timestamp>, unchanged since`) and do NOT touch `deployed_critical_paths` semantics — leave
   that field exactly as-is per the task's own framing ("decide whether it is subsumed or
   retained... do not silently redefine its semantics"); recommend RETAINING it unchanged for
   its narrower within-invocation role, since the new ledger operates at a different scope
   (cross-invocation) and collapsing them risks exactly the kind of silent semantic
   redefinition the task description warns against.
2. **Schema** (whichever file houses it): `{ "source_hash": "<git-commit-or-content-hash>",
   "hashed_paths": [...], "verified_at": "<ISO8601 or epoch>", "verify_outcome":
   "clean|pre_existing|filtered", "cycle_ref": "<optional: session_id/cycle_count for
   provenance, not for gating>" }`. Keep it minimal and single-record (a rolling "last known
   good" pointer) rather than an unbounded append-only log, unless the plan specifically wants
   history for diagnostics — an append-only log adds unbounded-growth housekeeping (reap
   scripts, size caps) that a single rolling record avoids entirely, and nothing in the task
   description asks for history, only "the last deploy record."
3. **Never write ledger evidence on a non-success outcome.** Only branches that currently
   update `deployed_critical_paths` (verify-clean, and the "proceeded despite findings" branch
   (c)/(c)-equivalent) may write a ledger entry recording a skip-eligible state. Branch (a)
   (deploy did not land) and branch (b) (blocking new finding) must never write ledger evidence
   — this is the direct enforcement of "a skip on no evidence is a disabled gate wearing a
   ledger's clothes."
4. **Test coverage additions to Group 11** (`scripts/tests/test-orchestrate-cycle-plan.sh`,
   after the existing case (a)-(k) sequence): (i) hash-unchanged skip — seed the ledger with a
   hash matching the current fixture content, assert `deploy-headless.sh`'s stub is NEVER
   invoked (add a call-count marker for it, mirroring `G11_CALL_MARKER`'s pattern for
   `verify-deploy.sh`) and the checkpoint proceeds without deferring; (ii) recency-window skip
   — seed a recent ledger timestamp with a DIFFERENT (changed) hash representing the
   self-modifying case, assert a skip still occurs via the recency/attribution path; (iii) no
   skip when genuinely stale — seed an old ledger entry with a changed hash, assert the full
   deploy+verify pipeline still runs; (iv) the named self-modifying-task acceptance criterion
   — simulate two consecutive fixture "invocations" (two separate calls into the SUT with a
   fresh `mt_state_file`/session but a PERSISTENT durable ledger file on disk between them,
   `cycle_modified_files` touching the same critical path both times with a new commit/hash the
   second time) and assert the second invocation does not incur a second full deploy+verify
   pipeline run. Since WORKDIR is not currently a git repository, either (a) add a scoped
   `git init` + commit sequence to the Group 11 setup specifically for hash computation, or
   (b) choose a git-independent content hash (e.g. `find <paths> | xargs sha256sum | sort |
   sha256sum`) precisely so Group 11's existing non-git fixture keeps working unmodified. Prefer
   option (b) unless the plan's chosen hash source is `.claude-extensions.json`'s
   `source_git_head` (Design Option A above), in which case git plumbing in the fixture is
   unavoidable and should be added deliberately, scoped narrowly to the new ledger test cases.
5. **Documentation**: update the "Idempotence guard" paragraph within "### The Inter-Cycle
   Redeploy Checkpoint" (guardrails.md, ~lines 594-601) to (a) correct/retain the existing
   within-invocation `deployed_critical_paths` description accurately (it is already accurate
   as written — the correction the task description asks for is about not overstating its
   scope, which the doc does not currently do; verify no accidental overstatement exists before
   editing), and (b) add a new subsection documenting the durable ledger's own contract: what it
   stores, where, its two skip conditions (hash-unchanged, recency/attribution for
   self-modifying tasks), and its fail-safe read behavior. Do NOT edit the "### The Postflight
   Completion-Deploy Gate" section's D6 residual note (~line 706) as part of this task — that
   note describes different, still-unclaimed follow-up work (trigger-predicate widening) that
   this task does not touch; if the plan chooses to touch that paragraph at all, it should only
   be to clarify that the two are distinct and neither subsumes the other, never to mark it
   resolved by this task.

## Decisions

- Confirmed (per prior task-description correction, re-verified against source): the checkpoint
  fires only via `orchestrate-cycle-plan.sh`'s own trigger predicate; `deployed_critical_paths`
  is genuinely within-invocation (lives in the session-suffixed `mt_state_file`) and is not
  touched or extended by this task's ledger — it is retained unchanged.
- Confirmed: dependencies 181, 193, and 213 are all `[COMPLETED]` in `specs/state.json`/TODO.md;
  no blocking prerequisite work remains outstanding.
- Confirmed: the "its own task" / `deployed_critical_paths` idempotence-backing-store quote the
  dispatch text points at belongs to a DIFFERENT, sibling section of the guardrails doc
  (Postflight Completion-Deploy Gate's D6 trigger-predicate-widening residual), not to the
  Inter-Cycle Redeploy Checkpoint section this task edits. This must not be conflated during
  planning or implementation.
- Left open for planning (explicit design decisions, not defaults): (a) reuse
  `.claude-extensions.json`/`deploy-freshness-lib.sh` (coarser, git-tracked, already-tested) vs.
  build an independent ledger file (exact-scoped, likely gitignored-but-durable, new); (b) git
  commit-hash vs. content-hash (e.g. sha256) as the hash source, driven partly by Group 11's
  current non-git test fixture; (c) single rolling record vs. bounded history; (d) exact
  recency-window constant/env-var name and default value (existing codebase convention:
  `${NAME:-default}` env-overridable seconds/minutes, e.g. `DEPLOY_LOCK_STALE_SEC=120`,
  `SESSION_REGISTRY_REAP_MIN=240` — a similarly-named constant, e.g.
  `DEPLOY_LEDGER_RECENT_SEC`, should follow this convention).

## Risks & Mitigations

- **Risk**: a hash scoped too broadly (e.g. the whole `agent-system/extensions/core` tree via
  `.claude-extensions.json` reuse) causes unnecessary redeploys for changes fully outside the
  checkpoint's own critical-path list. **Mitigation**: this is fail-safe in the correct
  direction (under-skips, never over-skips) per the "do not disable the gate" mandate; acceptable
  as a conservative default, and explicitly not a defect if chosen deliberately.
- **Risk**: a recency-window-only design without commit attribution degrades into a disabled
  gate for a busy multi-cycle self-modifying task (every cycle within the window silently
  proceeds regardless of what changed). **Mitigation**: prefer commit-ancestry/attribution over
  a bare recency window per the Recommendations section; if a bare recency window is chosen
  anyway for simplicity, it must be bounded tightly (minutes, not hours) and always paired with
  the existing confirmation/attribution filters from task 181 remaining live on any path that
  does NOT skip, so a skip is never the only safety net.
- **Risk**: the ledger file becomes stale evidence after an out-of-band manual redeploy/rollback
  (e.g. `git checkout` to an older commit, or a manual `deploy-headless.sh` run outside
  `/orchestrate`) that the ledger never observes. **Mitigation**: because the skip is
  hash-gated (not merely presence-gated), any content divergence — including a manual rollback —
  changes the computed hash and correctly forces a redeploy; only the recency/attribution path
  for the self-modifying case has residual exposure here, which argues further for bounding that
  window tightly.
- **Risk**: adding git plumbing to the Group 11 test fixture (if Design Option A / git-hash is
  chosen) could be a nontrivial addition given WORKDIR today has no `.git`. **Mitigation**:
  scope any `git init` addition narrowly to the new ledger test cases (mirroring how
  `test-deploy-freshness.sh` uses a dedicated `SOURCE_REPO` fixture rather than converting its
  whole WORKDIR), or avoid the issue entirely by choosing a git-independent content hash.

## Context Extension Recommendations

- **Topic**: Durable, cross-invocation, content-addressed orchestrator state (a candidate third
  class beyond `orchestrator-runtime-files.md`'s existing ephemeral/durable-provenance split).
- **Gap**: `orchestrator-runtime-files.md`'s Class Table has no entry type for "a small, durable,
  non-session-suffixed cache keyed by content identity rather than dispatch identity." This
  task's new ledger file (whichever shape is chosen) is the first instance of this pattern in
  the orchestrator runtime-file family.
- **Recommendation**: once the plan settles the ledger's file location and tracking
  disposition, add a Class Table row for it in `orchestrator-runtime-files.md` following the
  existing table's format, and consider naming the third class explicitly (e.g. "durable
  content cache") if a second instance of this pattern is anticipated; a single instance does
  not yet justify a new formal taxonomy entry beyond the table row itself.

## Appendix

### Search queries / commands used

- `jq` queries against `specs/state.json` and `specs/TODO.md` greps for dependency status
  (181, 193, 213 — all `[COMPLETED]`)
- `grep -n "deploy\|checkpoint\|verify_deploy_baseline_notices\|deployed_critical_paths"` over
  `orchestrate-cycle-plan.sh`
- Full read of `scripts/lib/deploy-baseline-lib.sh` and `scripts/lib/deploy-freshness-lib.sh`
- `grep -n "^#\{1,4\} "` heading map of `context/patterns/batch-orchestration-guardrails.md`,
  full read of "### The Inter-Cycle Redeploy Checkpoint" (lines 406-609) and "### The Postflight
  Completion-Deploy Gate" (lines 611-724)
- Full read of `context/standards/orchestrator-runtime-files.md`'s Class Table and rationale
  sections
- `jq -r '.extensions.core'` on `.claude-extensions.json`
- Read of `context/reference/orchestrator-critical-paths.json`
- Read of Group 11 fixture setup in `scripts/tests/test-orchestrate-cycle-plan.sh`
  (lines 1125-1200) and confirmation (via grep) that `test-deploy-freshness.sh` uses its own
  dedicated `git init`-based `SOURCE_REPO` fixture, distinct from the shared `WORKDIR`
- Read of `specs/archive/181_unify_redeploy_checkpoint_gate_depth/summaries/01_*-summary.md`
  "Follow-ups" section, confirming the D6 trigger-predicate-widening follow-up is distinct from
  this task's scope

### References

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (checkpoint implementation,
  lines ~695-865)
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`
- `agent-system/extensions/core/scripts/lib/deploy-freshness-lib.sh`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (lines
  406-724)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `.claude-extensions.json` (repo root)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (Group 11, lines
  1125-1400+)
- `specs/archive/181_unify_redeploy_checkpoint_gate_depth/summaries/01_unify-redeploy-checkpoint-gate-summary.md`
