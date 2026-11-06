# Implementation Plan: Task #409

- **Task**: 409 - Advise on dirty file scope at admission
- **Status**: [IMPLEMENTING]
- **Effort**: 6.5 hours
- **Dependencies**: Ordered after the artifact-round task in this same batch, and after the
  whole-tree-regeneration scope-claim, cross-repo source-store gate-blindness, and
  shared-verify-deploy-gate-run tasks (territory edges only, declared in the dispatch — shared
  file territory, not logical prerequisites)
- **Research Inputs**: specs/409_advise_on_dirty_file_scope_at_admission/reports/01_dirty-scope-advisory-research.md
- **Artifacts**: plans/01_dirty-scope-advisory-admission.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a fourth additive, non-blocking advisory field — `dirty_scope_advisory` — to the admission
verdict `orchestrate-batch-admit.sh` produces, firing when a dispatch candidate's own declared
`file_scope` intersects the current dirty working tree, so an operator can commit a foreign hunk
separately before an implement dispatch's whole-file staging sweeps it into that task's own
commit. The field is carried through `orchestrate-cycle-plan.sh`'s per-cycle ledger and rendered
as Class J in `orchestrate-predispatch-review.sh`, following the converged shape the three
existing sibling advisories (`idle_overlap_advisory`, `absent_scope_advisory`,
`cross_session_hazard`) already share across exactly these three surfaces. Definition of done:
the field fires on a real dirty-tree intersection, is structurally absent otherwise, is covered by
presence/absence regression cases in both named suites, is documented in the two docs that track
every existing advisory, and the deployed tree is regenerated to `RESULT=landed_verify_clean`.

**All edits land in the source store** — `/home/benjamin/.config/nvim/agent-system/extensions/core/`
(re-resolved from `.claude-extensions.json`'s per-extension `source_dir` for `core`; there is no
top-level `source_dir` key). Never hand-author under `.claude/**`. Note the correction the
dispatch's migration note makes to the originating record: the two named regression suites live at
`core/scripts/`, **not** `core/scripts/tests/`.

### Research Integration

The research report's findings are adopted essentially intact, and every structural claim in it
was independently re-derived against the source store at plan-authoring time:

- **No new jq predicate is needed.** `scopes_overlap_first(own_scope; other_scope)` from
  `lib/file-scope-overlap.sh`'s `FILE_SCOPE_OVERLAP_JQ_DEFS` is already spliced verbatim into
  `orchestrate-batch-admit.sh`'s single `jq -n` program and answers the containment question
  directly when the dirty-path list is passed as the foreign scope.
- **`git-snapshot.sh` is NOT an edit target.** Its dirty-tracked-paths computation (confirmed at
  `scripts/git-snapshot.sh:402-407`) is inline script logic with no extractable function, and its
  own comment resolves the dispatch's "and/or `--cached`" phrasing in the negative: `git diff
  --name-only HEAD` already covers staged and unstaged changes alike, so a second `--cached` pass
  is not needed. The script is cited as design precedent only. This resolves the dispatch's
  "possibly" qualifier on that surface to *no*.
- **Follow `whole_tree_claim`'s universal-merge placement**, not `cross_session_hazard`'s
  self-modifying-only scoping: like `whole_tree_claim`, the new check depends only on the
  candidate's own `file_scope`, so it applies uniformly. Confirmed: `+ $whole_tree_claim_frag`
  appears at exactly 8 merge sites.
- **Class J is the next free rendering letter** in `orchestrate-predispatch-review.sh` (A, B, C,
  C-admitted, D, D-admitted, E, F, G, H, H-admitted, I are taken), and Class I's single-block
  (no deferred/admitted split) style is the right model.
- **The one real gap**: neither named suite ever runs `git init` inside its `$TMPROOT`
  (independently confirmed: zero `git init` occurrences in either file, and none in
  `tests/test-orchestrate-batch-admit.sh` either), so a true-positive case needs a new
  fixture capability, not just new assertions.

**One correction to the research's Recommendation 7 (documentation convergence).** The research
flagged three docs for plan-time scope confirmation. Checked against actual sibling precedent:
`context/patterns/orchestrate-batch-results-template.md` contains **zero** references to
`absent_scope_advisory` or `cross_session_hazard` — only `idle_overlap_advisory` has a section
there, and it exists because that advisory has a `skill-orchestrate` Move 3 reporting instruction
behind it. The two later sibling advisories set the precedent that a new advisory does **not** get
a results-template section. That file is therefore excluded (see Non-Goals). The other two docs —
`docs/architecture/batch-admit-schema.md` and
`context/patterns/batch-orchestration-guardrails.md` — do track both later siblings precisely and
are included.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; ROADMAP.md was not consulted and is not
modified by this plan.

## Goals & Non-Goals

**Goals**:
- `orchestrate-batch-admit.sh` emits a `dirty_scope_advisory` object on every verdict for a
  candidate whose own declared `file_scope` intersects the dirty working tree, carrying the FULL
  list of intersecting paths plus a machine-templated `reason` naming the remedy.
- The advisory is strictly additive: it never defers a task, never excludes one from dispatch,
  never changes a `decision` or `defer_reason`, and never affects an exit code.
- `orchestrate-cycle-plan.sh` captures it in a `dirty_scope_ledger`, regardless of decision.
- `orchestrate-predispatch-review.sh` renders it as Class J, with an accurate zero-count line.
- Presence and absence regression cases exist in both `test-conflict-predicate.sh` and
  `test-four-tier-conflict.sh`, backed by a real git-repository fixture, plus a Class J rendering
  scenario in `tests/test-orchestrate-predispatch-review.sh`.
- The two docs that track every existing advisory gain the new field.
- The deployed `.claude/` tree is regenerated to `RESULT=landed_verify_clean`.

**Non-Goals**:
- **No `$schema` version bump.** The field stays `orchestrate-batch-admit-v7`. Both later sibling
  advisories landed additively without a bump, precisely because adding an optional field creates
  no new verdict *shape* a prior consumer would mis-bucket. Same reasoning applies here.
- **No `git-snapshot.sh` change.** Design precedent only (see Research Integration).
- **No untracked-file detection.** `git diff --name-only HEAD` reports tracked changes only; the
  observed incident was an edit to an already-tracked file, and `git-snapshot.sh`'s separate
  WARN-only `DIRTY_UNTRACKED` handling is a different, already-solved concern.
- **No second `--cached` pass.**
- **No glob-shaped-`file_scope` handling.** A glob entry is invisible to `scopes_overlap_first`
  by design; Class G already warns about that same blind spot. Not a gap this task introduces or
  closes.
- **No `context/patterns/orchestrate-batch-results-template.md` section** (see Research
  Integration for the precedent check).
- **No `skills/skill-orchestrate/SKILL.md` change.** Its Move 4 `.return-meta-multi` field list
  names `idle_overlap_ledger` only — neither later sibling ledger was added there. Same
  precedent.
- **No `tests/test-orchestrate-batch-admit.sh` change.** Not named by the dispatch; the two named
  suites carry the coverage obligation.
- **No promotion of this advisory to a blocking gate.** It is advisory by construction.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `batch-orchestration-guardrails.md` is ALSO in a concurrently-planning sibling task's declared `file_scope` (the dispatch's Territory block lists it for task 418) | H | H | Declare the path in this task's own `file_scope` so the admission gate serializes rather than excluding. At implement time: re-read the file immediately before editing, stage only this task's own hunks with an explicit file list (never a directory or glob add), and STOP and report any foreign commit or foreign uncommitted modification after checking `git log` to confirm it is not this task's own work. See `context/contracts/territory.md` (Cross-Task Territory). |
| Missing one of the 8 `+ $whole_tree_claim_frag` merge sites leaves the advisory silently absent on that one verdict shape | M | M | Phase 1 enumerates merge sites mechanically (`grep -c '+ \$whole_tree_claim_frag'`) and asserts the post-edit count of the new fragment equals it; Phase 4's presence case exercises the ordinary admit shape end-to-end. |
| `git diff` fails in a non-git `$PROJECT_ROOT` (which is what both suites' `$TMPROOT` is today) | L | H | `2>/dev/null` plus a default-`[]` fallback, identical to the existing degrade-safe `sessions_json`/`critical_expanded_json` pattern. The advisory then never fires — the correct conservative default for an informational field, and it keeps the existing cases 2.5/2.6/12 bit-for-bit unaffected. |
| The new fixture's `git init` leaks `.git` state if `$TMPROOT` cleanup is interrupted | L | L | Both suites already use `mktemp -d` plus a `trap cleanup EXIT` doing `rm -rf "$TMPROOT"`, which covers a nested `.git` identically to any other file. No new cleanup logic. |
| `$TMPROOT` is created under a `TMPDIR` that is itself inside a git repository, so `git -C` finds an unintended parent repo and the "clean tree" absence case sees foreign dirt | M | L | In the absence case, assert on a candidate whose `file_scope` namespace cannot intersect any real repository path (the suites' existing `gNN/`-style synthetic namespaces already have this property), rather than on an assumption that the tree is clean. |
| Disturbing the existing `idle_overlap_advisory` / `absent_file_scope` semantics, which a neighbouring task's acceptance criterion requires preserved | H | L | The change adds one fragment and merges it; it edits no existing fragment's computation or any `decision`/`defer_reason` logic. Phase 4 keeps cases 2.5/2.6 and case 12 unmodified as the bit-for-bit guard. |
| One subprocess (`git diff`) added per invocation | L | H | Negligible and O(1) per invocation, not per candidate — the script already shells out for `sessions_json` and `critical_expanded_json` once each. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Compute and merge `dirty_scope_advisory` in `orchestrate-batch-admit.sh` [COMPLETED]

**Goal**: The admission verdict carries the new advisory on every shape in the self-modifying and
ordinary branches, computed once per invocation from the candidate's own `file_scope` against the
dirty working tree.

**Tasks**:
- [x] Re-resolve `source_dir` for `core` from `/home/benjamin/.config/nvim/.claude-extensions.json`
      (per-extension key, no top-level key) and confirm it is
      `/home/benjamin/.config/nvim/agent-system/extensions/core`. *(completed)*
- [x] Record the pre-edit merge-site count: `grep -c '+ \$whole_tree_claim_frag' scripts/orchestrate-batch-admit.sh`
      (expected 8 — confirm, do not assume). *(completed: confirmed exactly 8)*
- [x] Add the bash-layer input next to the existing `sessions_json` / `critical_expanded_json`
      resolution (around `scripts/orchestrate-batch-admit.sh:698-710`): one
      `git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null` piped through
      `jq -R -s -c 'split("\n") | map(select(length > 0))'`, defaulting to `[]` on any failure,
      mirroring `sessions_json`'s degrade-safe shape verbatim. `PROJECT_ROOT` is already resolved
      via `common_repo_root` at `:565`. *(completed)*
- [x] Pass it to the single `jq -n` call as `--argjson dirty_paths "$dirty_paths_json"`, alongside
      the existing `--argjson sessions` / `--argjson critical_expanded` arguments. *(completed)*
- [x] Bind `$dirty_paths as $dirty` at the invocation-level binding block, alongside
      `$own_sid` / `$sess_list`. *(completed)*
- [x] Compute `$dirty_scope_frag` immediately after `($entry.file_scope) as $c_scope` is bound
      (`:854`) and at the same point `$c_has_whole_tree_claim` is computed, collecting EVERY
      intersecting path via `scopes_overlap_first($c_scope; [.])` per dirty path (or an equivalent
      single-pass intersection), emitting `{}` when the list is empty and
      `{dirty_scope_advisory: {dirty_paths: [...], reason: "..."}}` otherwise. The `reason` follows
      the existing machine-templated-sentence convention and names the remedy: commit the listed
      path(s) separately before this task's own commit sweeps them in. *(completed: reason text
      avoids apostrophes, since this text lands inside the single-quoted bash string holding the
      embedded jq program — an apostrophe there would terminate that string early)*
- [x] Merge `+ $dirty_scope_frag` at every site where `+ $whole_tree_claim_frag` already appears,
      and nowhere else — leaving it structurally absent on the three early-exit branches (unknown
      task, terminal status, absent `file_scope`), where `$c_scope` does not exist or is empty by
      construction. *(completed: all 8 sites, via sed on the exact `+ $whole_tree_claim_frag`
      pattern, which matched only genuine merge sites and no comment line)*
- [x] Extend the script's own header field-list comment (the block around `:195-212` documenting
      `idle_overlap_advisory` / `absent_scope_advisory` / `cross_session_hazard` /
      `whole_tree_claim`) with the new field and its presence rule. *(completed)*
- [x] Assert the post-edit count of `+ $dirty_scope_frag` equals the recorded pre-edit
      `whole_tree_claim_frag` count. *(completed: both 8)*
- [x] Confirm the `$schema` string is unchanged (`orchestrate-batch-admit-v7`). *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: 8 merge sites are asserted (the occurrences of `+ $whole_tree_claim_frag`,
measured at plan-authoring time against the source store). Confirm at implementation time with
`grep -c` BEFORE editing, and assert the new fragment's post-edit count matches whatever that
measurement actually returns — never the number written here.

**Tier Justification**: The verdict schema is consumed across several scripts, so the covering
check is the changed script plus its enumerated direct dependents:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh,test-conflict-predicate.sh,test-four-tier-conflict.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-suggest-next-batch.sh,test-orchestrate-unwind-dispatch.sh,test-force-phases.sh,test-orchestrate-context-growth.sh,test-lint-json-channel-discipline.sh`
(the exact set `suite_selection_select orchestrate-batch-admit.sh` resolves).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - new bash-layer `dirty_paths` input, new `--argjson` argument, new invocation-level binding, new `$dirty_scope_frag` computation, merge at every `whole_tree_claim_frag` site, header field-list comment entry

**Verification**:
- The `--only` suite set above passes (every pre-existing case, including 2.5/2.6 and case 12,
  still green — the advisory must not fire spuriously in a non-git `$TMPROOT`).
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
  exits 0 (the repository's sanctioned shellcheck entry point, narrowed by pathspec — never the bare
  `shellcheck` binary).
- Manual probe from a repository root with a known dirty tracked file: a candidate whose
  `file_scope` contains that path produces a verdict with `dirty_scope_advisory.dirty_paths`
  naming it; a candidate whose `file_scope` does not produces a verdict with no
  `dirty_scope_advisory` key at all (`has("dirty_scope_advisory") == false`).
- `decision`, `defer_reason`, and the process exit code are byte-for-byte identical to a pre-edit
  run over the same inputs.

---

### Phase 2: Ledger the advisory in `orchestrate-cycle-plan.sh` [NOT STARTED]

**Goal**: The advisory is captured per cycle in a `dirty_scope_ledger`, regardless of the
candidate's decision.

**Tasks**:
- [ ] Re-read `scripts/orchestrate-cycle-plan.sh` immediately before editing (concurrent siblings
      are active on this tree this cycle).
- [ ] Add `dirty_scope_ledger` to the `mt_state_file` field-list header comment (the block around
      `:53-56` that already names `idle_overlap_ledger`, `absent_scope_ledger`,
      `cross_session_hazard_ledger`, `unrecognized_defer_reason_ledger`).
- [ ] Add its `| .dirty_scope_ledger //= []` self-initializer alongside the three existing ones
      (around `:617-619`).
- [ ] Inside the existing per-row `while IFS= read -r row` loop (around `:1908-1927`), add a
      capture block mirroring the `absent_adv` / `cross_sess_hazard` blocks exactly:
      `jq -c 'if (.dirty_scope_advisory != null) then .dirty_scope_advisory else null end'`, then
      an `mt_set --argjson entry ... '.dirty_scope_ledger += [$entry]'` call carrying
      `{task, dirty_paths, cycle}`. Capture regardless of decision — the loop's own stated
      convention.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to one script with no externally visible signature
change (an additive, self-initializing ledger field), covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh`
plus `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - `mt_state_file` field-list comment entry, `//= []` initializer, per-row capture block

**Verification**:
- The two-suite `--only` run above passes.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
  exits 0.
- A cycle run over a candidate carrying the advisory leaves exactly one matching
  `dirty_scope_ledger` entry in the `mt_state_file`; a cycle with no carrier leaves the ledger as
  `[]` (present and empty, never absent).

---

### Phase 3: Render the advisory as Class J in `orchestrate-predispatch-review.sh` [NOT STARTED]

**Goal**: The pre-dispatch review surfaces the advisory as its own lettered class, with an
accurate zero-count line, and a regression scenario asserts the rendering.

**Tasks**:
- [ ] Re-read `scripts/orchestrate-predispatch-review.sh` immediately before editing.
- [ ] Confirm J is still the next free letter (A, B, C, C-admitted, D, D-admitted, E, F, G, H,
      H-admitted, I were taken at plan-authoring time).
- [ ] Add a Class J entry to the header's class-inventory comment block (around `:10-70`).
- [ ] Add a Class J extraction alongside Class I's (around `:600-611`):
      `select($v.dirty_scope_advisory != null)` with NO `decision` or `self_modifying` filter —
      the field is carried on admits and defers alike — relaying `task_number` and the advisory's
      `dirty_paths` verbatim.
- [ ] Add a `-- Class J: ... --` rendering section in Class I's single-block style (no
      deferred/admitted split: this field never changes a decision, so there is no
      negative-conflation to guard against). Unlike Classes E and I, it needs **no**
      `$session_id_explicit` gate — it consumes no session-registry input — so it is
      unconditionally available like Classes C and D. Keep the existing `$admit_checked` degraded
      guard.
- [ ] Write the zero-count line so it cannot be read as "never tested": along the lines of
      `0 findings (no candidate's file_scope intersects the currently dirty working tree).`
- [ ] Add a new Scenario to `scripts/tests/test-orchestrate-predispatch-review.sh` following the
      existing synthetic-NDJSON convention (see its Scenario 2 fixture, around `:148-154`): a
      literal `{"decision":"admit", ..., "dirty_scope_advisory":{...}}` stub row, asserting the
      Class J row renders and the zero-count line does NOT appear.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to the review composer plus its own dedicated suite,
with no externally visible signature change, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-predispatch-review.sh`
plus `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` over both edited paths (that one suite is the whole set `suite_selection_select
orchestrate-predispatch-review.sh` resolves).

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - header class-inventory comment entry, Class J extraction, Class J rendering section with zero-count line
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` - new Class J rendering scenario

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-predispatch-review.sh`
  passes, including every pre-existing scenario.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
  exits 0.
- The script still `exit 0`s on every path (it is report-only), and Classes A through I render
  unchanged.

---

### Phase 4: Presence/absence regression cases in both named suites [NOT STARTED]

**Goal**: Both dispatch-named suites exercise a real dirty-worktree intersection and its absence,
backed by a new git-repository fixture capability.

**Tasks**:
- [ ] Confirm the gap still holds: zero `git init` occurrences in both
      `scripts/test-conflict-predicate.sh` and `scripts/test-four-tier-conflict.sh`.
- [ ] In each suite's `$TMPROOT` builder (around `:52-70` and `:69-83` respectively), add after
      the existing script copies: `git init` at `$TMPROOT` (which is what
      `common_repo_root "$SCRIPT_DIR" 2` resolves to from
      `$TMPROOT/.claude/scripts/orchestrate-batch-admit.sh`, so it is the `$PROJECT_ROOT` the new
      `git -C` call reads), a local `user.email`/`user.name` so the commit cannot fail on a host
      with no global git identity, a baseline tracked file at a path one test candidate declares
      in its `file_scope`, and an initial commit of it.
- [ ] Add a PRESENCE case to each suite: make a real uncommitted edit to that baseline tracked
      file, invoke `orchestrate-batch-admit.sh`, and assert the candidate's verdict has
      `dirty_scope_advisory`, that its `dirty_paths` names that path, and that the verdict's
      `decision` is unchanged from what the same fixture yields with a clean tree.
- [ ] Add an ABSENCE case to each suite: assert `has("dirty_scope_advisory") == false` for a
      candidate whose `file_scope` lies entirely within that suite's synthetic namespace and so
      cannot intersect any real path — mirroring case 2.5/2.6's and case 12's existing
      presence/absence assertion structure.
- [ ] Leave cases 2.5, 2.6, and 12 textually unmodified: they are the bit-for-bit guard that the
      sibling advisories' semantics were not disturbed.
- [ ] Revert the uncommitted fixture edit (or scope it so later cases in the same suite are
      unaffected) before any subsequent case runs, so no case inherits a dirty fixture it did not
      ask for.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Both suites are asserted to lack any `git init` today (measured at
plan-authoring time: zero occurrences in each). Confirm with `grep -c 'git init'` on both files
before building the fixture; if either already initializes a repository, reuse it rather than
adding a second.

**Tier Justification**: The edit is confined to two self-contained test suites with no
externally visible signature change, covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-conflict-predicate.sh,test-four-tier-conflict.sh`
plus `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` over both edited suites.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - `$TMPROOT` git-repository fixture capability; one presence case and one absence case
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` - the same fixture capability; one presence case and one absence case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-conflict-predicate.sh,test-four-tier-conflict.sh`
  passes, with the new cases reported PASS and every pre-existing case still PASS.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/test-conflict-predicate.sh agent-system/extensions/core/scripts/test-four-tier-conflict.sh`
  exits 0.
- Each suite still cleans up fully: no `$TMPROOT` (and no nested `.git`) survives a run, including
  an interrupted one, via the existing `trap cleanup EXIT`.
- Each suite's exit code remains 0 on all-pass and 1 on any failure.

---

### Phase 5: Documentation convergence [NOT STARTED]

**Goal**: The two docs that track every existing advisory precisely gain the new field, so the
codebase's own convergence discipline is not broken by an undocumented fourth advisory.

**Tasks**:
- [ ] **Re-read `context/patterns/batch-orchestration-guardrails.md` immediately before editing**
      — it is in a concurrently-planning sibling task's declared `file_scope` this cycle. If a
      foreign commit or foreign uncommitted modification is present, STOP and report it after
      checking `git log` to confirm it is not this task's own work.
- [ ] Add a `dirty_scope_advisory` row to `docs/architecture/batch-admit-schema.md`'s Field
      Definitions table (around `:206-231`), matching the three sibling rows' shape: field name,
      type (`object`), presence rule (present on every verdict in the self-modifying and ordinary
      branches whose candidate's own `file_scope` intersects the dirty working tree; absent on
      every early-exit branch and whenever the intersection is empty), and the nested-key list
      (`dirty_paths` array, `reason` string).
- [ ] Add a worked example line to the same doc's examples block, matching the existing
      `absent_scope_advisory` / `cross_session_hazard` example lines.
- [ ] Add a Version History note stating the field is **additive with no `$schema` bump** (it
      adds no new verdict shape a prior consumer would mis-bucket), explicitly following the
      precedent the two later sibling advisories set.
- [ ] Add a row to `context/patterns/batch-orchestration-guardrails.md`'s Blocking vs. Advisory
      Classification Table (around `:289-300`) classifying the dirty-worktree check as ADVISORY,
      with a "Why" cell grounded in that section's own two-condition criterion: the harm of
      proceeding is a foreign hunk swept into a task commit — recoverable after the fact and
      requiring an operator's judgment about what to commit separately — not a silent
      concurrent-write corruption, so the condition is logged loudly rather than gated.
- [ ] Verify no task-number reference and no record-versioning language lands in either file
      (`.claude/rules/no-task-references-in-deliverables.md`,
      `.claude/rules/no-record-versioning-in-deliverables.md`). Cite durable anchors — field
      names, section headings, script names — never "task N". Note that the schema doc's existing
      `NEW in v7`-style labels are the file-format/schema version axis, a permitted durable axis,
      not record-versioning.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Exactly two docs are asserted to need the new field. This was measured, not
assumed: `orchestrate-batch-results-template.md` contains zero references to either later sibling
advisory, and `skill-orchestrate/SKILL.md` names only `idle_overlap_ledger`. Confirm at
implementation time by grepping for `absent_scope_advisory` and `cross_session_hazard` across
`agent-system/extensions/core/` and adding the new field wherever BOTH siblings already appear —
no more, no less.

**Tier Justification**: Both touched paths are source-store markdown with no executable surface,
so `suite_selection_select` returns the `__FULL_SWEEP__` sentinel and no suite covers them; the
honest covering check is therefore sub-case (b) — the diff read-through the `local` row
prescribes, plus
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(the repository root holding both a deployed `.claude/` tree and the source store).

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - Field Definitions row, worked example line, Version History note (additive, no `$schema` bump)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - Blocking vs. Advisory Classification Table row

**Verification**:
- The gate 3/4 invocation above passes (doc-lint and task-reference lint), and neither gate SKIPs
  — a SKIP on both would mean nothing was checked.
- The schema doc's Field Definitions table still renders as valid markdown with a consistent
  column count.
- `grep -n 'dirty_scope_advisory'` finds the field in both docs and in every script that carries
  it.
- `git status --short` shows only this task's own hunks staged on the shared guardrails file.

---

### Phase 6: Redeploy and full gate set [NOT STARTED]

**Goal**: The deployed `.claude/` tree reflects every source-store change and the complete gate
set is green.

**Tasks**:
- [ ] Confirm every prior phase is committed and the working tree holds no partial edit of this
      task's own.
- [ ] Run the redeploy with the bounded-wait idiom required by
      `context/patterns/external-process-wait.md` Rule 1 — `timeout 540 bash
      .claude/scripts/deploy-headless.sh`, with the Bash tool `timeout` parameter raised to
      600000 (not its 120000ms default) — and confirm it reports `RESULT=landed_verify_clean`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`), with no `--skip-slow` and no
      `--only-gate` narrowing.
- [ ] Confirm the deployed copies of all six edited files match the source store byte-for-byte
      (the deploy's own verify step covers this; confirm it reported clean rather than assuming).
- [ ] If the batch-level gate stage applies to this dispatch, record in the phase's verification
      notes that the full set was run here rather than deferred.

**Timing**: 1 hour

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: Six source-store files are asserted as this task's total footprint (one
per Phase 1-3 script plus two suites plus two docs, less the overlap). Confirm at implementation
time against `git diff --name-only` over this task's own commits; a seventh touched file means
either a sibling's edit or an unplanned widening, and must be reconciled before the deploy, not
after.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, an implicit scope claim over the entire deployed tree; declared via the reserved sentinel per plan-format.md's whole-tree-claim declaration rule

The deployed `.claude/` tree is regenerated by this phase and is deliberately NOT listed as a
path entry above: it is a disposable deploy artifact, never hand-authored, and the reserved
sentinel already expresses the claim over it. A glob-shaped entry such as `.claude/**` would be
harvested verbatim into this task's `file_scope`, where it is invisible to overlap-based collision
detection (the Class G blind spot) while still appearing to declare something.

**Verification**:
- `deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` passes the complete gate set it aggregates — every
  gate, including gate 3 (doc-lint), gate 4 (task-reference lint), and gate 8 (the full
  `tests/run-all.sh` shell-suite battery) — with no `--skip-slow` and no `--only-gate` narrowing.
- `check-deploy-freshness.sh` no longer reports `core` as stale.
- A real `/orchestrate` admission probe on this repository (which has a dirty tracked tree) shows
  the advisory firing and Class J rendering end-to-end, with no task deferred or excluded by it
  and the exit code unaffected.

---

## Testing & Validation

- [ ] `dirty_scope_advisory` present, with every intersecting path listed, on a verdict whose
      candidate's `file_scope` intersects the dirty tree.
- [ ] Field structurally absent (`has(...) == false`) when the intersection is empty, and on all
      three early-exit branches.
- [ ] `decision`, `defer_reason`, the admitted/deferred partition, and the process exit code are
      byte-for-byte unchanged from a pre-edit run over identical inputs — the advisory-only
      requirement.
- [ ] Degrades to no-advisory (never an error) when `$PROJECT_ROOT` is not a git repository.
- [ ] `$schema` remains `orchestrate-batch-admit-v7`.
- [ ] `dirty_scope_ledger` captures the advisory regardless of decision, and initializes to `[]`.
- [ ] Class J renders a real finding, and its zero-count line appears only on a genuine
      tested-negative.
- [ ] Pre-existing cases 2.5, 2.6, and 12 remain PASS and textually unmodified.
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits 0 over all five
      edited shell files (the sanctioned entry point, checked by exit status — never the bare
      `shellcheck` binary and never a stdout diff against a baseline).
- [ ] Full `verify-deploy.sh` gate set green after the redeploy.
- [ ] No task-number reference and no record-versioning language in any file landing under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` (modified)
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (modified)
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` (modified)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (modified)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (modified)
- Regenerated `.claude/` deploy tree (deploy artifact, not hand-authored)
- `specs/409_advise_on_dirty_file_scope_at_admission/summaries/01_*-summary.md` (at completion)

## Rollback/Contingency

Every phase is independently revertible: the change adds one fragment and merges it at existing
sites, touching no existing fragment's computation and no decision logic, so reverting Phase 1's
commit alone restores the prior verdict schema exactly and leaves Phases 2/3's consumers inert
(their `select(... != null)` filters simply never match, the same way
`orchestrate-predispatch-review.sh` was already inert toward an unrecognized `defer_reason` before
the v6 extension).

If the working tree must be reverted rather than a commit reverted, this is a genuine rollback,
not a precautionary checkpoint: use the invocation shape in `context/contracts/recovery.md`'s
rollback rung, including its out-of-scope override flag where the revert deliberately reaches
beyond this task's declared `file_scope`. Do not emit a bare `git-snapshot.sh` in its default
reverting form as a routine start-of-phase step; for an ordinary defensive checkpoint before
risky work, use `--no-revert`, which is durable without reverting the working tree.

If the redeploy in Phase 6 does not reach `RESULT=landed_verify_clean`, do NOT hand-patch any
file under `.claude/**` to force it green — that masks the divergence instead of fixing it. Fix
the source store and redeploy.
