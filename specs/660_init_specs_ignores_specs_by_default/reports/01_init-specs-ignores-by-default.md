# Research Report: Init specs ignores specs by default

**Task**: 660 - Init specs ignores specs by default
**Started**: 2026-11-20T01:58:00Z
**Completed**: 2026-11-20T02:40:00Z
**Effort**: ~1 hour
**Dependencies**: Task 658 (completed)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/init-specs.sh`,
`scripts/lib/runtime-file-patterns.sh`, `scripts/lib/specs-ignore-lib.sh`,
`scripts/check-runtime-file-tracking.sh`, `scripts/lib/deploy-baseline-lib.sh`), standards
(`context/standards/orchestrator-runtime-files.md`, `context/standards/git-staging-scope.md`),
task history (TODO.md entries 658, 659, 338, 618), and a live mechanical probe of
`git check-ignore` semantics in a scratch repo.
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The repository-level predicate this task needs already exists:
  `scripts/lib/specs-ignore-lib.sh`'s `specs_tree_is_gitignored()` (added by task 658) answers
  "is this repo's whole specs tree ignored?" via `git check-ignore -q -- specs`, run from the
  repo root. That function can only ever return true if a `.gitignore` **at or above the repo
  root** carries a rule matching the bare `specs` path — a rule inside `specs/.gitignore` itself
  cannot produce that result, confirmed live (see Findings). This is the load-bearing fact that
  shapes the whole design: the new default must write to the consumer's **repo-root**
  `.gitignore`, not merely extend `specs/.gitignore`'s existing managed block.
- The correct, safe gate for "is this a fresh repo" is **not** `specs_tree_is_gitignored()` (that
  answers a different question — whether a rule already exists) but a direct check of
  `git ls-files -- specs/`: non-empty means an existing consumer already tracks its specs tree
  and must be left alone; empty means nothing has ever been committed under `specs/` and the new
  default may apply.
- Recommended shape: `init-specs.sh` gains one new, idempotent step that (a) runs the
  `git ls-files -- specs/` check, (b) when empty, ensures the repo-root `.gitignore` carries a
  managed, sentinel-delimited block containing a single `/specs/` line (creating the file if
  absent), and (c) when non-empty, touches nothing outside `specs/.gitignore` — today's
  unchanged behavior. The existing `specs/.gitignore` ephemeral-class managed block (Step 5)
  keeps being written unconditionally in both cases.
- The inner ephemeral block is NOT made redundant by the new root-level ignore in any load-bearing
  sense for the *current* state of a freshly-adopting repo, but it becomes **functionally
  inert while the root-level `/specs/` line is in place**, and regains real effect the moment a
  consumer removes that line to opt back into tracking (see Findings — "Does the inner block
  become redundant?").
- This change directly interacts with the machinery task 658 built and task 659 is designed
  around: once a fresh repo's whole specs tree is root-ignored, `git-commit-scoped.sh`'s V13 gate
  and the new exit codes 8/9 are exactly what keeps `orchestrate-cycle-postflight.sh` from
  demoting a completed task to partial. Task 660 is the scenario that makes task 659's narrowed
  demotion-exception necessary in practice, not a separable concern — see Risks & Mitigations.
- A real gap outside this task's declared `file_scope`: `check-runtime-file-tracking.sh`'s Check C
  currently asserts, unconditionally, that `.orchestrator-handoff.json`/`.return-meta.json` are
  **never** ignored. Under the new default those two files ARE (deliberately) ignored for a fresh
  repo. Check C needs to become posture-aware (skip, or invert, when
  `specs_tree_is_gitignored()` is true) or it will fail on every freshly-bootstrapped repo. This
  script is not in task 660's `file_scope` (which lists only `init-specs.sh`,
  `runtime-file-patterns.sh`, and `orchestrator-runtime-files.md`) and should be either folded in
  at plan time (file_scope is descriptive, not filesystem-validated — see
  `state-management.md`) or spun out as an explicit follow-on.

## Context & Scope

Researched what it takes to make a brand-new consumer repository's `specs/` tree gitignored in
full by default, while leaving any repository that already tracks its `specs/` tree (the global
root, tracking 11,606 files as of this research) completely untouched by any deploy, redeploy, or
loader run. Scope was the three files named in this task's `file_scope`
(`scripts/init-specs.sh`, `scripts/lib/runtime-file-patterns.sh`,
`context/standards/orchestrator-runtime-files.md`), plus whatever adjacent machinery (task 658's
predicate library, the commit path's V13 gate, task 659's in-flight demotion-exception work, and
`check-runtime-file-tracking.sh`'s invariants) the change needs to stay consistent with.

Out of scope for this research: implementing an opt-in bulk-untrack flow for an already-tracked
consumer that wants to switch postures (addressed as a recommendation, not a design), and editing
any file outside the three named above (flagged as a gap where relevant).

## Findings

### Codebase Patterns

- **`init-specs.sh` today** (agent-system/extensions/core/scripts/init-specs.sh) runs six
  idempotent steps unconditionally: create `specs/`+`specs/archive/`, create
  `specs/state.json`/`specs/archive/state.json` if absent, create `specs/TODO.md` via
  `generate-todo.sh` if absent, write/refresh `specs/.gitignore`'s sentinel-delimited managed
  block from `runtime_specs_ignore_block()`, and untrack (`git rm --cached`, never a working-tree
  delete) any already-tracked file matching the ephemeral-class regex list. It **never writes to
  the repo-root `.gitignore`** — the header's Step 5 comment states this is "explicitly out of
  scope," on the grounds that the specs/-relative file can be delivered directly where a
  repo-root one "could not" (a `root_files` deploy-mechanism limitation that does not actually
  apply to `init-specs.sh`, since it runs directly in the consumer's own working tree, not
  through the deploy/loader path — see `orchestrator-runtime-files.md`'s "Consumer Repo Setup").
- **`runtime-file-patterns.sh`** is the single source of the 27-member ephemeral-class
  enumeration (lock files, loop guards, `.dispatch/`, etc.) and exports two block-renderers:
  `runtime_ignore_block()` (repo-root-relative, used by the optional hand-added legacy block
  documented in `orchestrator-runtime-files.md`) and `runtime_specs_ignore_block()`
  (`specs/`-relative, the one `init-specs.sh` actually writes). Deliberately excludes
  `.orchestrator-handoff.json` and the bare `.return-meta.json` — those are durable provenance.
- **`scripts/lib/specs-ignore-lib.sh`** (new in task 658, NOT in this task's `file_scope` but
  directly load-bearing for the design) exports `specs_tree_is_gitignored(repo_root)` and
  `path_is_gitignored(repo_root, path)`, both rc-based, fail-open-to-"not ignored" predicates
  built on `git check-ignore -q`. `specs_tree_is_gitignored` runs
  `git -C "$repo_root" check-ignore -q -- specs`. This is now the **single** place the commit
  path (`git-commit-scoped.sh`'s V13 gate, consumed by `orchestrate-cycle-postflight.sh` and
  `git-commit-phase.sh`) answers "does this repo ignore its specs tree."
- **Live mechanical probe** (scratch repo, this research session): a root `.gitignore` containing
  exactly `/specs/` makes `git check-ignore -q -- specs` exit 0 (confirms
  `specs_tree_is_gitignored` would report true) and makes every file written under `specs/`
  (e.g. `specs/foo.txt`) ignored too. Run against this actual repository's own root right now,
  `git check-ignore -q -- specs` exits 1 (not ignored) — consistent with the global root's
  tracked-11,606-files reference-case posture. **A rule confined to `specs/.gitignore` cannot
  produce the same result**: `check-ignore -q -- specs` is evaluated against the path `specs`
  relative to the repo root, and only a `.gitignore` at or above that level (i.e. the repo-root
  file) can match the bare directory entry itself. This is not a style choice; it is how
  `git check-ignore` resolves ancestor directories, and it is the exact mechanism task 658's
  predicate (and therefore the whole V13/exit-8/exit-9 commit path) already depends on.
- **`check-runtime-file-tracking.sh`** (not in `file_scope`) runs three checks: A (ephemeral
  patterns actually ignore their probes), B (no ephemeral-class file is tracked), and C
  (`.orchestrator-handoff.json`/`.return-meta.json` are **not** ignored — an unconditional
  assertion). `scripts/lib/deploy-baseline-lib.sh`'s governed-glob table already attributes any
  `*.gitignore`/`*.lock`/`*/000_probe/*` lint finding to the same four-file group
  (`runtime-file-patterns.sh`, `init-specs.sh`, `orchestrator-runtime-files.md`,
  `check-runtime-file-tracking.sh`) even though `check-runtime-file-tracking.sh` itself isn't in
  this task's `file_scope` — the baseline-attribution machinery already treats these four as one
  governing group.
- **Call sites**: `init-specs.sh` is invoked (via `bash .claude/scripts/init-specs.sh`, no `cd`)
  from `/task`, `/review`, `/orchestrate` (defensively), `skill-fix-it`, `skill-spawn`,
  `skill-project-overview`, and `meta-builder-agent` — all documented in
  `orchestrator-runtime-files.md`'s "Consumer Repo Setup" and all assuming CWD is already the
  repo root (the script itself writes `specs/state.json` etc. as plain relative paths, never
  resolving via `git rev-parse --show-toplevel`).
- **Related task history**: Task 658 (completed) built the ignored-specs predicate and the
  commit-path's non-failure exit codes (8/9), explicitly measured against a consumer repo
  (`sf1-engine`) that had *manually* added `specs/` to its root `.gitignore` and untracked 389
  files while leaving 604 on disk — i.e. task 658 was built anticipating exactly the posture this
  task (660) is about to make the *default* for new repos. Task 659 (open, same dependency on
  658) is about preventing `orchestrate-cycle-postflight.sh`'s demotion-on-commit-failure logic
  from firing when the per-cycle specs commit is a no-op because the tree is ignored — task
  659's own description explicitly anticipates "a gitignored specs tree" as the trigger condition.
  Task 338 (open, declared shared-but-not-blocking with 660) is a broader sweep of every
  task-support file's tracked/ignored classification across the whole `specs/` enumeration; it
  edits the same two files (`init-specs.sh`, `runtime-file-patterns.sh`) this task does, and the
  user's ruling requires whichever lands second to re-read the other's result.

### External Resources

Not applicable — this is a closed, codebase-internal mechanism with no external library or
documentation dependency; no web research was needed.

## Recommendations

1. **Detection**: add a direct check — `git ls-files -- specs/` (or, defensively, test
   `! git rev-parse --is-inside-work-tree` first, matching Step 6's existing guard) — immediately
   before the existing Step 5 `specs/.gitignore` logic. Non-empty output means "already tracks
   its specs tree" and the script takes exactly today's path (refresh `specs/.gitignore`'s
   ephemeral block only, touch nothing at the repo root). Empty output means "nothing tracked
   yet" and the new step below applies. Do not use `specs_tree_is_gitignored()` for this gate —
   that predicate answers "does a rule already exist," not "has anything ever been committed,"
   and a repo could in principle have an empty specs tree with no ignore rule at all (the
   from-scratch case this task is adding).
2. **New default write**: when the tree is empty, ensure the repo-root `.gitignore` (create if
   absent) carries its own sentinel-delimited managed block — mirroring the existing
   `specs/.gitignore` idiom but with a **distinct** sentinel pair (e.g.
   `# BEGIN managed block: specs-tree-ignore` / `# END managed block: specs-tree-ignore`) so it
   is never confused with the pre-existing, hand-added, optional legacy ephemeral-class block
   `orchestrator-runtime-files.md` already documents for the repo root — containing exactly one
   line, `/specs/`. This is the minimal, mechanically-verified (see Findings) way to make
   `specs_tree_is_gitignored()` report true, which is what wires the new default into task 658's
   commit-path machinery with zero further change.
3. **Keep Step 5 unconditional**: continue writing/refreshing `specs/.gitignore`'s existing
   27-member ephemeral-class managed block in both postures, exactly as today. It is the forward
   -compatible fallback for a consumer that later removes the new root-level `/specs/` line to
   opt back into tracking (see "Does the inner block become redundant?" below) — do not make
   Step 5 conditional on the new detection; that would add a reversal hazard for no benefit,
   since writing it is already a cheap no-op on a second run.
4. **Opt-in for an already-tracked consumer**: do not build an automatic bulk-untrack flag into
   `init-specs.sh` for this task. The risk profile (an automated path that could untrack an
   existing consumer's entire history, exactly the hazard this task's own description names as
   worse than the defect being fixed) outweighs the convenience. Instead, document the manual
   procedure in `orchestrator-runtime-files.md` (a short runbook: `git rm -r --cached specs/`,
   commit, add the root-level `/specs/` line, re-run `init-specs.sh`) and have `init-specs.sh`
   print a one-line, non-actionable hint pointing at that doc section when it detects an
   already-tracked tree, so the opt-in path is discoverable without being automated.
5. **Document the posture split in `orchestrator-runtime-files.md`**: add a short subsection next
   to "Consumer Repo Setup" stating, in the same declarative style as task 658's
   "Per-Operation Contract: Tracked vs. Gitignored `specs`" section in `git-staging-scope.md`,
   that a repo bootstrapped from empty by `init-specs.sh` now gets the whole `specs/` tree
   root-ignored by default, that a repo which already tracks `specs/` is never touched at the
   root, and the "inner block redundancy, with a future-reversal caveat" point from this report.
6. **Flag, don't silently fold in, the Check C conflict**: `check-runtime-file-tracking.sh`'s
   Check C (`.orchestrator-handoff.json`/`.return-meta.json` must never be ignored) will fail,
   by design, on every freshly-bootstrapped repo once this change lands, because those two files
   are now inside the root-ignored tree along with everything else. This script sits outside
   `file_scope` for 660; the plan phase should either (a) expand `file_scope` to include it and
   make Check C posture-aware (skip when `specs_tree_is_gitignored()` is true — the file-tracking
   audit for an ignored tree is a different, not-yet-designed question), or (b) explicitly record
   this as a known, deliberate follow-on gap in the plan and this report, rather than let the
   check start failing unexplained. Given `state-management.md`'s rule that `file_scope` is
   "descriptive/anticipated (not filesystem-validated)," (a) is the recommended choice if the
   plan's effort budget allows it in the same pass.

## Decisions

- The detection gate for "is this repo a fresh `specs/` bootstrap" is `git ls-files -- specs/`
  being empty, evaluated once near Step 5 — not `specs_tree_is_gitignored()`, which answers a
  different question (rule-exists, not ever-tracked).
- The new whole-tree ignore is implemented as a repo-root `.gitignore` managed block containing
  a single `/specs/` line, written only when the detection gate says "fresh," never when any file
  under `specs/` is already tracked. This is a hard requirement, not a style preference — it is
  the only placement that makes `git check-ignore -q -- specs` (and therefore
  `specs_tree_is_gitignored()`, and therefore the V13 commit-path gate) report the tree as
  ignored; a pattern added only inside `specs/.gitignore` cannot do this.
- The existing `specs/.gitignore` ephemeral-class managed block (Step 5) stays unconditional in
  both postures; it is not deleted, gated, or special-cased by the new logic.
- No automatic opt-in/bulk-untrack flow is recommended for this task; the opt-in path for an
  already-tracked consumer is a documented manual runbook, not new automation.

## Risks & Mitigations

- **Risk**: landing task 660 without task 659's narrowed demotion-exception in the same batch (or
  before it) means every first-time-bootstrapped repo's completing dispatch would see
  `orchestrate-cycle-postflight.sh`'s per-cycle specs commit resolve to task 658's new exit codes
  8/9 — which, per task 658's own summary, `orchestrate-cycle-postflight.sh` **already** handles
  with a dedicated `NOTE`-level, non-demoting arm (added as part of task 658's completed work).
  So this specific demotion hazard is, on inspection, already closed by 658's completed
  implementation; task 659's own description frames itself as about the *symptom already observed
  live* (pre-658) rather than a new hazard 660 would introduce. Residual risk is low, but the plan
  phase should re-confirm this by tracing the exact `case "$commit_rc"` arm in
  `orchestrate-cycle-postflight.sh` against a live fixture before treating it as closed, since
  this report's confirmation is read-based, not a fresh mechanical rerun.
- **Risk**: `check-runtime-file-tracking.sh` Check C regresses (starts failing) on every freshly
  bootstrapped repo once the root-level ignore lands, since it asserts the two durable-provenance
  files are never ignored — see Recommendation 6. Mitigation: expand file_scope or explicitly
  record as a deliberate, documented gap.
- **Risk**: a consumer's root `.gitignore` already has an unrelated, broader rule that happens to
  match `specs` (e.g. a wildcard), making `specs_tree_is_gitignored()` report true even though
  `init-specs.sh` never wrote anything — harmless (fail-open direction is correct either way) but
  worth a defensive idempotency note: the new Step should still check for its own sentinel before
  writing, exactly like Step 5 does for `specs/.gitignore`, so a second run never double-appends.
- **Risk**: task 338's broader sweep (shared territory, declared not-blocking) could re-touch the
  same two files this task edits with a different enumeration in mind. Mitigation already stated
  by the user's ruling: never co-admit both into one batch; whichever lands second re-reads the
  other's result rather than assuming its own enumeration is still accurate.
- **Risk**: a call site that runs `init-specs.sh` from a CWD that is not the actual repo root
  (none observed today, but not structurally prevented) would write the new root-level
  `.gitignore` block to the wrong location. Mitigation: no change needed beyond what Step 5
  already assumes — all seven documented call sites run from repo root — but the plan could
  consider resolving the target via `git rev-parse --show-toplevel` for the new write specifically,
  since getting the *wrong* root wrong is a more visible failure mode for a root-level file than
  for a `specs/`-relative one.

## Context Extension Recommendations

- **Topic**: posture-aware verification for the tracked/ignored specs-tree split.
- **Gap**: `context/standards/orchestrator-runtime-files.md`'s "Verification" section describes
  `check-runtime-file-tracking.sh`'s three checks as universal invariants; after this task lands
  there are two legitimate postures with different Check-C expectations, and no existing context
  file states that split for the *verification* layer (only `git-staging-scope.md`'s "Per-
  Operation Contract" states it for the *commit* layer, written by task 658).
- **Recommendation**: extend `orchestrator-runtime-files.md`'s own "Verification" section (this
  task's planned edit site already touches this file) with a short cross-reference to
  `git-staging-scope.md`'s "Per-Operation Contract: Tracked vs. Gitignored `specs`" section and a
  one-line statement of what Check C should mean in each posture, even if the mechanical fix to
  `check-runtime-file-tracking.sh` itself is deferred to a follow-on (see Recommendation 6).

## Appendix

- Search queries / commands used: `jq` queries against `specs/state.json` and
  `.claude-extensions.json`; `grep -rn "init-specs.sh"` across `agent-system/extensions/core`;
  reads of `init-specs.sh`, `runtime-file-patterns.sh`, `specs-ignore-lib.sh`,
  `check-runtime-file-tracking.sh`, `deploy-baseline-lib.sh`, and the relevant sections of
  `orchestrator-runtime-files.md` and `git-staging-scope.md`; a live scratch-repo probe of
  `git check-ignore -q -- specs` under a root `.gitignore` containing `/specs/`, and the same
  probe against this repository's own (tracked) root for contrast.
- References: `agent-system/extensions/core/scripts/init-specs.sh`,
  `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`,
  `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh`,
  `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`,
  `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`,
  `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `specs/658_ignored_specs_predicate_and_commit_path/summaries/01_ignored-specs-predicate-commit-path-summary.md`.
