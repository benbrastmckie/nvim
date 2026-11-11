# Research Report: Task #554

**Task**: 554 - file_scope external source store containment
**Started**: 2026-11-10T23:00:00Z
**Completed**: 2026-11-10T23:26:00Z
**Effort**: ~1.5 hours (research only)
**Dependencies**: None declared
**Sources/Inputs**: Codebase (this repository's `agent-system/extensions/core/**`), the BimodalLogic
  repository at `/home/benjamin/Projects/BimodalLogic` (read-only, for citation resolution and
  archived-task verification), `specs/state.json`, `specs/*/issues.jsonl`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both compounding causes named in the dispatch are confirmed, with direct, reproducible
  evidence, and they are genuinely two different defects sharing one symptom (the
  `git-commit-phase.sh` drop-and-warn message).
- Cause 1 (external source store) is real but **machine/deployment-relative**, not a defect in
  this repository's own layout: in this repository (nvim), `.claude-extensions.json`'s
  `core.source_dir` resolves to a path *inside* this repository's own git root, so the
  containment drop observed here for `agent-system/**` paths (task #444's 14 "scope excursion"
  rows, task #450's regenerated-metadata row) is caused by cause 2 and the addendum's
  regenerated-surface gap, **not** by an actually-external repository. In a *consumer* repository
  that deploys from this one (BimodalLogic, where task #846 and task #867 ran), the same
  `source_dir` value resolves to a path genuinely outside that repository's own git root —
  confirmed directly (`git rev-parse --show-toplevel` run from inside
  `agent-system/extensions/core` returns this repo's own root here, but BimodalLogic's own
  `.claude-extensions.json` points its `core.source_dir` at this exact absolute path, which sits
  outside BimodalLogic's root entirely). The fix must work for the general (any-consumer) case,
  not assume this repository's own coincidental containment.
- Cause 2 ($SD unexpanded token) is confirmed at its exact origin: a planner authored
  `$SD/scripts/...` as informal shorthand directly inside a plan's `Files to modify` backtick
  entries (verified in the archived plan for task #846 in BimodalLogic).
  `plan-file-scope-harvest.sh` is a pure text extractor with **no variable-expansion and no
  shape validation** — it harvested the literal `$SD/...` strings verbatim into `file_scope`,
  where they can never match anything. No script in the commit path defines `SD=`.
- This repository already contains a directly reusable precedent for the recommended design:
  `git-commit-scoped.sh`'s **V9** gate already classifies a pathspec resolving outside the
  repository root as a distinct case (`out_of_repo_dropped`, its own exit code, its own
  textually-distinct `WARN`), but that classification never reaches the *upstream*
  `git-commit-phase.sh` Containment Self-Check, which drops the same path earlier using the
  generic "not contained in this task's declared `file_scope`" wording — exactly the ambiguity
  design option (c) asks to resolve.
- Recommended direction: adopt a sanctioned, mechanically-expandable source-store marker for
  `file_scope`/`Files to modify` entries (closing cause 2 generally, not only for `$SD`), paired
  with an explicit second-repository commit step for any entry using that marker (option b), and
  a Site-2 pre-check that reuses V9's out-of-repository classification *before* testing
  containment, so a genuinely external path is never reported with the undeclared-scope message
  (option c). (b) and (c) are complementary, as the dispatch anticipates.
- Three open backlog records (#508, #517, #548) already own the adjacent "regenerated derived
  surfaces silently dropped" territory the addendum's second sample raises. This task's
  recommendation deliberately excludes that territory rather than re-litigating it.

## Context & Scope

This is a research-only dispatch for a `meta`-type task. The task was migrated from the
BimodalLogic repository (where it was project #847) under the cross-repo meta-task migration
ruling, and carries a later addendum folding in a second, larger citation sample from this
repository's own `/orchestrate` conclusion stage. The task's acceptance criteria require:

1. A task whose deliverable lives in an external source store either gets its source-store paths
   committed by a sanctioned mechanism, or gets a notice that unambiguously says so and names the
   repository.
2. An unexpanded-variable `file_scope` entry is either impossible to declare, or detected and
   reported, instead of silently matching nothing.
3. The existing excursion behavior for genuinely out-of-scope in-repo paths is unchanged, pinned
   by a test.
4. The edit lands under `agent-system/extensions/core/**`, reaching `.claude/**` only by deploy.

Scope for this research pass: establish the exact mechanics and origin points of both causes
(verified, not assumed), survey the existing, directly relevant precedent already built into this
source store (the V9/V10/Site-1/2/3 containment machinery, the `.claude/**` deployed-tree-refusal
pattern, and the `__WHOLE_TREE__` sentinel), and map the open-backlog boundary so a later plan
does not re-solve territory three other records already own.

Out of scope for this task (per the dispatch's own "Related Open Territory" note, confirmed
still open in this repository's `state.json`):
- `shared_extension_metadata_commit_containment` (#508, not_started) — whether
  `index-entries.json`/`manifest.json` belong in the engine-written-state allowlist, and the
  whole-file-rewrite provenance hazard in the `--write` sync tools.
- `stage_regenerated_derived_files_in_phase_commits` (#517, not_started) — the phase-commit
  obligation to re-run and stage a declared derived surface's generator.
- `plan_contingency_file_scope_and_containment_drop` (#548, not_started) — the Scope-Hypothesis
  harvesting gap, the generated-surfaces-no-phase-would-name gap, and a proposed
  `--allow-out-of-scope` flag for `git-commit-scoped.sh` for the *same-repository* undeclared-path
  case.

## Findings

### Codebase Patterns

**The containment pipeline, as it exists today (three sites, one shared predicate).**
`context/standards/git-staging-scope.md`'s "Three Containment sites, not one" section documents
the full architecture: Site 1 (`orchestrate-cycle-postflight.sh`, whole-task completion commit),
Site 2 (`git-commit-phase.sh`'s Phase-Commit Containment Self-Check, mid-dispatch phase commits —
the site that produced every citation in this task's dispatch), and Site 3 (`git-commit-scoped.sh`'s
V10 gate, reached by every `--task`-supplying caller including both other sites). All three test
the same predicate: one concrete path against one task's declared `file_scope`, widened by a
shared engine-written-state allowlist and each site's own task-directory member.

**Site 2's exact drop mechanics** (`git-commit-phase.sh`, read in full): for each
`files_touched` entry not matched by `is_contained()` against the (deployed-tree-stripped)
`file_scope_arr`, the script (a) emits `WARNING: ... dropping out-of-scope path '<f>' from phase
commit — not in task <N>'s declared file_scope`, (b) calls `issue-record.sh --class "scope
excursion"` with `--what-happened "git-commit-phase.sh dropped '<f>' from a phase commit pathspec:
not contained in this task's declared file_scope."` (the exact string the dispatch cites), and
(c) deposits `<f>` into `.return-meta.json`'s `proposed_file_scope` via
`propose_file_scope_addition()` (built by task #430, completed 2026-11-08). None of this is
sensitive to *why* containment failed — a genuinely-undeclared in-repo path, an unexpanded-token
entry, and a path pointing into a different repository entirely all produce the identical
wording and the identical remedy suggestion ("land it with a scoped follow-up commit").

**V9 already solves the classification half of cause 1, but only downstream, inside
`git-commit-scoped.sh`.** Reading `git-commit-scoped.sh`'s header and the V9 block directly: V9
resolves each positive pathspec's absolute directory via `realpath -m`, tests whether it falls
under the canonicalized `root_resolved` (`PROJECT_ROOT`), and — if not — drops it into its own
`out_of_repo_dropped` ledger (kept separate from the generic `dropped_pathspecs`/V10's
`containment_dropped`) with the message `WARN: git-commit-scoped.sh dropping out-of-repository
pathspec '<p>' (resolves outside <root_resolved>); this path will NOT be part of the commit.` —
textually distinct from both the V10 containment message and from Site 2's own message. V9 is
evaluated *before* V10/case-1 pathspec matching, precisely so an out-of-repository path is never
misclassified as "not in file_scope." **This exact distinction does not exist at Site 2.** Site 2
drops a path for being outside `file_scope` without ever asking whether the path is outside the
*repository* in the first place — so by the time an external-source-store path would reach V9's
own correct classification, Site 2 has already dropped it with the wrong (ambiguous) message and
it never reaches `git-commit-scoped.sh`/V9 at all.

**The `.claude/**` deployed-tree refusal is the directly applicable precedent for "detect and
reject a structurally-wrong `file_scope` entry rather than silently failing to match."**
Built by task #446 (completed 2026-11-09): `plan-file-scope-harvest.sh` runs a pure structural
prefix test (`^\.claude(/.*)?$`) over its merged harvest array, refuses any match with a loud
per-entry `>&2` warning, and still exits 0 with the surviving array (never blocks the harvest).
`git-commit-phase.sh`'s `propose_file_scope_addition()` refuses the same shape at deposit time,
and the Containment Self-Check strips the same shape from `file_scope_arr` before its splices
run. The `__WHOLE_TREE__` sentinel is the sanctioned escape hatch for the one case a real path
genuinely cannot express (a whole-tree regeneration claim) — it is a reserved, slashless token
every consumer (`plan-file-scope-harvest.sh`, `validate-artifact.sh`,
`scripts/lib/file-scope-overlap.sh`'s `whole_tree_claim_sentinel`, `orchestrate-batch-admit.sh`)
already recognizes and handles specially. This is the exact shape — a structural test, a loud
non-fatal warning, and (where a real claim exists) a reserved marker token — this task's design
space should reuse rather than reinvent.

### Verification of Cause 1 (external source store)

Direct verification, run in this repository:
```
$ jq -r '.extensions.core.source_dir' .claude-extensions.json
/home/benjamin/.config/nvim/agent-system/extensions/core
$ cd agent-system/extensions/core && git rev-parse --show-toplevel
/home/benjamin/.config/nvim
```
In *this* repository, `source_dir` resolves to a path inside this repository's own git root —
this repository is the canonical source store, not merely a consumer of one. `git ls-files
agent-system | head` confirms the directory is tracked here, not external.

Direct verification, run in BimodalLogic (the repository where task #846's and task #867's
citations actually occurred):
```
$ cd /home/benjamin/Projects/BimodalLogic && jq -r '.extensions.core.source_dir' .claude-extensions.json
/home/benjamin/.config/nvim/agent-system/extensions/core
```
The identical absolute path — but BimodalLogic's own repository root is
`/home/benjamin/Projects/BimodalLogic`, so this `source_dir` value is genuinely outside that
repository's git tree: a different git repository, exactly as the dispatch states. This confirms
cause 1 is a real, reproducible defect class for every *consumer* repository of this agent system
(any repository other than this one), while explaining why the same `agent-system/**` drops
observed *in this repository* (task #444's 14 citations, task #450's citation) are **not**
instances of cause 1 — they are undeclared-scope and regenerated-surface drops of an in-repo
path, the territory #508/#517/#548 already own.

Archived evidence for task #846 (`specs/archive/846_membership_based_task_number_allocation/issues.jsonl`
in BimodalLogic) shows the actual historical drop message carried a manually-appended
clarification the automated script does not itself produce — e.g. `"...dropped
'agent-system/extensions/core/manifest.json (external source store:
/home/benjamin/.config/nvim)' ..."`. A byte-for-byte `diff` between this repository's
`git-commit-phase.sh` and BimodalLogic's deployed copy is empty — the deployed script is
identical, and it contains no string `"external source store"` anywhere. This confirms the
annotation was added by the implementing agent's own manual issue-record call (or hand-edit of
the logged text) when it *noticed* the problem and went on to commit the six files directly in
this repository's own git history — not a feature of any current script. This matches the
dispatch's own account ("the dispatched agent noticed and committed the source store
separately") and confirms no sanctioned, mechanical second-repository commit path exists today.

### Verification of Cause 2 (unexpanded `$SD`)

The task #846 archive directory in BimodalLogic retains the plan that introduced the literal
token. `grep -n '\$SD' plans/*.md` in that task's archived directory returns 19 hits, all inside
backtick-delimited `Files to modify` entries and prose, e.g.:
```
- `$SD/scripts/lib/project-number-inuse.sh` — new file, shared jq definitions
- `$SD/manifest.json` — one new `provides.scripts` entry
```
`$SD` is never defined anywhere in this plan, nor in `git-commit-phase.sh`,
`update-task-status.sh`, or any other script on the commit path (`grep -rn '\$SD\b'` across
`agent-system/` returns zero hits outside this one plan and this task's own description). It is
informal, ad hoc shorthand a planner invented for "source directory," never a sanctioned
notation documented anywhere in `plan-format.md` or `planner-agent.md`.

`plan-file-scope-harvest.sh`'s `extract_paths()` awk routine is confirmed (read in full) to be a
pure substring extractor: it matches a `- \`...\`` list-item line, takes everything up to the
next backtick, and emits it verbatim as a harvested path. It performs **no shell expansion, no
shape validation, and no rejection of any token** other than the one existing `.claude/**`
structural-prefix test added by task #446. A literal `$SD/scripts/state-write.sh` string is
harvested exactly as typed and flows unchanged into `file_scope` via the `--file-scope-add`
write-back chain (`orchestrator-postflight.sh` / `update-task-status.sh` / `skill-base.sh`),
where it can never match any real path tested by `is_contained()` (an exact-match or
prefix-glob test against literal strings) — "those strings match nothing mechanically," exactly
as the dispatch states, confirmed by direct code reading rather than assumption.

### Related Open Territory (boundary confirmation)

Checked directly against `specs/state.json`: `shared_extension_metadata_commit_containment`
(#508), `stage_regenerated_derived_files_in_phase_commits` (#517), and
`plan_contingency_file_scope_and_containment_drop` (#548) are all `not_started` in this
repository's own backlog today. Their full descriptions were read in full; each owns a distinct,
non-overlapping surface of the same mechanism (see Context & Scope above for the one-line split).
None of the three mentions the genuinely-cross-repository case or the unexpanded-token case this
task owns; conversely, this task's two causes are absent from all three descriptions. The
boundary the dispatch draws holds up under direct reading, not just the dispatch's own assertion.

Two already-completed records are directly relevant prior art rather than overlapping open
territory: task #430 (`feed_undeclared_implement_paths_into_file_scope`) built the
`proposed_file_scope` deposit channel Site 2 already uses on every drop; task #446
(`close_the_plan_to_file_scope_reconciliation_gap`) built the exact `.claude/**`
structural-refusal pattern this task's cause-2 remedy should mirror, and documented (in
`git-staging-scope.md`'s "A third asymmetry, deliberately left open") that its own deployed-tree
strip is Site-2-only, a known, explicitly out-of-scope residual at Site 3 — a useful model for how
this task's own remedy should scope itself (land at the sites that matter for the observed
citations; name any residual explicitly rather than chasing full parity across all three sites in
one task).

## Decisions

- **Cause 1's scope is the general (any-consumer) case, not this repository's own layout.**
  Because `source_dir` resolution is per-machine/per-repository, a fix validated only against
  this repository (where `agent-system/**` happens to sit inside this repo's own root) would
  silently fail to address the actual citations, all of which occurred in a genuinely separate
  consumer repository. Any later plan must verify its fix against a fixture or scenario where
  `PROJECT_ROOT` and the resolved `source_dir` are genuinely disjoint, not merely against this
  repository's own tree.
- **Do not re-scope this task onto #508/#517/#548's territory.** The addendum's "regenerated
  surfaces" and "blast-radius derivation" material is real and well-evidenced, but it is a
  different defect (declared scope narrower than true mechanical scope, inside one repository)
  from either of this task's two named causes. A later plan should cite those three records
  rather than attempt to fold their remedies in here.
- **The $SD origin finding rules out "fix the harvester's grammar" as a sufficient remedy on its
  own.** Because the token was authored directly in a plan's prose by a planner with no
  sanctioned notation to reach for, a parser-only fix (e.g., expanding `$SD` specifically) would
  leave the actual gap — *no* sanctioned way to express a source-store path in a plan or in
  `file_scope` — open for the next ad hoc invention. The remedy should define and document a
  notation, not special-case one token spelling.

## Recommendations

1. **Define a sanctioned, reserved source-store marker for `file_scope` / `Files to modify`
   entries**, analogous in spirit to `__WHOLE_TREE__` but carrying a resolvable payload rather
   than being a bare sentinel — e.g. a fixed-prefix form such as
   `__SOURCE_STORE__:<extension>/<relative-path>` (exact spelling is a plan-stage decision; the
   property that matters is a fixed, grep-able prefix plus a `<extension>` segment resolvable
   through `.claude-extensions.json`'s per-extension `source_dir`). This single notation change
   closes cause 2 *generally* — the planner now has a real notation to reach for, so a future
   ad hoc `$SD`/`$FOO`/`${BAR}` invention has a documented alternative — and gives Site 2 a
   positive signal to detect ("this entry is a deliberate source-store claim") rather than only a
   negative one ("this entry matched nothing").
2. **Reject, don't silently harvest, any OTHER unexpanded-shell-variable-shaped token.** Add a
   structural test to `plan-file-scope-harvest.sh` (mirroring the existing `.claude/**` refusal:
   same stage, same loud-non-fatal-warning shape, same never-fails-the-harvest exit contract) for
   a bare `$VAR`/`${VAR}` pattern that is *not* the sanctioned marker from (1). This directly
   satisfies acceptance criterion 2 ("impossible to declare, or detected and reported") without
   requiring the harvester to recognize every possible ad hoc spelling by name — anything shaped
   like an unexpanded variable and not the one sanctioned marker is refused on sight.
3. **Give Site 2 (`git-commit-phase.sh`) an out-of-repository pre-check, reusing V9's own logic,
   before the `file_scope` containment test.** For each `files_touched` entry, resolve it against
   `PROJECT_ROOT` the same way V9 does (`realpath -m` on the entry's directory, test containment
   under the canonicalized root) *before* running `is_contained()` against `file_scope_arr`. A
   path that resolves outside `PROJECT_ROOT` should never reach the generic
   "not contained in this task's declared file_scope" message — this is design option (c),
   satisfied with reused logic rather than new logic.
4. **Resolve which repository an out-of-repository path belongs to, and either commit it there or
   name it unambiguously.** For a `files_touched` entry recognized by step (1)'s marker (or, for
   the retrofit case, any entry whose out-of-repository classification from step (3) also matches
   a known extension's `source_dir` in `.claude-extensions.json`), add an explicit second commit
   step: `git -C <source_dir_repo_root> add -- <relative-path>` followed by a commit in that
   repository, keeping the two commits' messages cross-referenced (this repository's commit names
   the companion source-store commit's repository and path; nothing more, since task numbers and
   record-versioning language are forbidden in the deliverable files themselves per
   `rules/no-task-references-in-deliverables.md`/`rules/no-record-versioning-in-deliverables.md`
   — this applies to the *implementation*, not to this report). If that second commit cannot be
   attempted (the marker's extension is unknown, `source_dir` does not exist on disk, or the
   resolved path is not inside a git working tree) or fails, fall back to a warning that **must**
   name the resolved repository path explicitly — satisfying acceptance criterion 1's second
   branch rather than silently reusing the ambiguous generic message. This directly implements
   the dispatch's own observation that options (b) and (c) are complementary.
5. **Pin acceptance criterion 3 with a regression fixture, not just inspection.** Add or extend a
   `test-git-commit-phase.sh` case asserting that a `files_touched` entry that is genuinely
   in-repository and genuinely outside the declared `file_scope` (no marker, resolves under
   `PROJECT_ROOT`) still produces today's exact drop-and-warn behavior and today's exact message
   — unchanged by any of (1)-(4) above.
6. **Scope the implementation narrowly to Site 2 plus the harvester**, following task #446's own
   precedent of leaving an explicitly-named residual at other sites rather than chasing full
   parity in one pass. Site 1 (`orchestrate-cycle-postflight.sh`) and Site 3's V10 gate
   (`git-commit-scoped.sh`) already have (or, for V9, structurally could reuse) comparable
   machinery; if a later plan chooses not to port the out-of-repository pre-check to all three
   sites in this task, it should name that residual explicitly (mirroring
   `git-staging-scope.md`'s own "third asymmetry, deliberately left open" wording) rather than
   leaving it implicit.

## Risks & Mitigations

- **Risk**: an auto-commit into a second, external repository is a meaningfully larger blast
  radius than today's drop-and-warn (it can fail for reasons unrelated to this repository —
  permissions, detached HEAD, a dirty unrelated file in that repository, concurrent writers).
  **Mitigation**: scope the second-repo commit to the *single named path* via an explicit
  pathspec (never a directory/glob add in the external repo either — the same
  under-stage-never-over-stage direction `git-staging-scope.md` already settles for this
  repository applies there too), and keep the fallback-to-unambiguous-warning path as the
  unconditional safety net per Recommendation 4 — a failed second-repo commit must never block or
  fail this repository's own commit.
- **Risk**: introducing a new marker syntax without updating `planner-agent.md` and
  `plan-format.md` reproduces the exact gap that created `$SD` — an undocumented convention a
  future planner either does not know about or reinvents differently. **Mitigation**: any plan
  implementing Recommendation 1 must update both files (and `validate-artifact.sh`'s authoring-
  shape checks, following task #446's precedent of adding an advisory `log_warn` for the
  anti-pattern) in the same phase that introduces the marker, not as a follow-up.
- **Risk**: scope creep into #508/#517/#548's territory, given how closely the addendum's
  evidence sits next to this task's own citations. **Mitigation**: the Decisions section above is
  explicit; a later plan should cite this report's territory-boundary finding rather than
  re-deriving it, and should file a dependency/territory edge to those three records if any
  concrete file overlap is discovered during planning (none was found during this research pass).
- **Risk**: `.claude-extensions.json` resolution is per-extension (`jq -r
  '.extensions.<name>.source_dir'`), and a top-level `jq -r '.source_dir'` returns `null` — a
  mistake the dispatch itself warns against and which this report independently re-confirmed by
  direct `jq` invocation. **Mitigation**: any implementation must resolve `source_dir`
  per-extension, keyed off the marker's `<extension>` segment, never via a top-level lookup.

## Context Extension Recommendations

- **Topic**: source-store containment and the external-repository commit boundary.
- **Gap**: `context/standards/git-staging-scope.md` documents the three Containment sites and
  the `.claude/**` deployed-tree-refusal pattern in detail, but has no section at all for "a
  `file_scope` entry whose correct home is a different repository entirely." This is a genuine
  documentation gap, not just an implementation gap — a future reader investigating a source-store
  drop has no pointer today.
- **Recommendation**: once this task's remedy lands, add a section to `git-staging-scope.md`
  (sibling to "Three Containment sites, not one" and the `.claude/**` strip) documenting the new
  marker, the out-of-repository pre-check at Site 2, and the second-repository commit mechanism —
  following the same documentation depth already given to the deployed-tree case so this becomes
  the fourth documented containment nuance rather than a second undocumented one.

## Appendix

Search queries / commands used (all run directly, not assumed):
- `jq -r '.extensions.core.source_dir' .claude-extensions.json` (this repository and
  BimodalLogic)
- `jq -r '.source_dir' .claude-extensions.json` (top-level null confirmation)
- `git rev-parse --show-toplevel` (run from `agent-system/extensions/core` and from repo root)
- `git ls-files agent-system | head`
- `grep -rn "scope excursion"` / direct `issues.jsonl` reads for tasks #444, #450, and (in
  BimodalLogic) the archived #846
- `grep -rn '\$SD\b'` across this repository's `agent-system/` tree (zero hits outside this
  task's own description) and across BimodalLogic's archived #846 plan (19 hits, all
  unexpanded)
- Full reads: `agent-system/extensions/core/scripts/git-commit-phase.sh` (584 lines),
  `scripts/plan-file-scope-harvest.sh` (header plus `extract_paths()`/deployed-tree-refusal
  stage), `scripts/git-commit-scoped.sh` (V9/V10 header and implementation), `scripts/lib/
  engine-written-state-paths-lib.sh`, `context/standards/git-staging-scope.md` (full file, 1030
  lines), `context/standards/source-store-deploy-boundary-narrative.md` (full file)
- `jq -r '.active_projects[] | select(.project_number==508 or 517 or 548) | .description'
  specs/state.json` for the open-territory boundary check
- Task #430 and #446 completion summaries, read in full, for prior-art precedent

References: dispatch file
`specs/554_file_scope_external_source_store_containment/.dispatch/14.md`; task directories
`specs/430_feed_undeclared_implement_paths_into_file_scope/`,
`specs/446_close_the_plan_to_file_scope_reconciliation_gap/`; BimodalLogic's archived
`specs/archive/846_membership_based_task_number_allocation/`.
