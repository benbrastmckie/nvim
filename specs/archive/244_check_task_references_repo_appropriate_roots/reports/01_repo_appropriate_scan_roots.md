# Research Report: Task #244

**Task**: 244 - check-task-references.sh: scan repo-appropriate roots instead of a hard-coded nvim-repo TREE_ROOTS list
**Started**: 2026-09-28T17:16:00Z
**Completed**: 2026-09-28T18:10:00Z
**Effort**: Medium (two scripts, one shared lib untouched, two docs, two new test suites)
**Dependencies**: None
**Sources/Inputs**: Codebase (scripts/, hooks/, context/standards/, rules/), live measurement of scan output against this repo
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md, shell-script-testing.md

## Executive Summary

- **check-task-references.sh's `TREE_ROOTS=(agent-system/extensions .opencode lua .memory)`
  encodes this repo's own layout and generalizes to nothing.** Recommend replacing the default
  scan with a plain repo-wide walk (`git ls-files`, filtered through the existing
  `is_exempt_path` — `specs/**` only) rather than a per-repo config file or nvim-layout
  detection. This is Option (a), coverage, not Option (b), carve-out.
- **Measured equivalence, not assumed**: a full repo-wide scan of this repo (git ls-files minus
  `specs/**`) produces **0 findings**, byte-identical to today's four-tree scan (also 0). The
  "same files flagged" requirement (1) is satisfied by direct measurement, not by argument.
- **The write-time hook already has no TREE_ROOTS problem.** `validate-no-task-references.sh`
  gates on whatever file path the tool call names, filtered only through `is_exempt_path`
  (`specs/**`) — it was never scoped to the four trees. Requirement (8)'s "must not drift"
  concern is resolved as a side effect of fixing the lint's default: after the fix, both
  consumers share exactly one scope predicate (`is_exempt_path`), closing a drift that existed
  in the *opposite* direction from what corroboration implied — the batch lint was narrower than
  the hook, not the other way around.
- **`validate-wiring.sh`'s absorbed defect (former task 256) is independent and narrow**: its
  `all` arm unconditionally validates both `.claude` and `.opencode` trees with no existence
  check, turning an absent `.opencode` (a normal, supported consumer configuration) into hard
  `[FAIL]` rows. Fix: an existence guard per tree root, printing `[SKIP]` (mirroring
  `check-task-references.sh`'s own `[SKIP] $label does not exist under $REPO_ROOT` precedent)
  instead of calling the two validate_* functions against a missing directory.
- **PATH_SCOPE's TREE_ROOTS membership check becomes unnecessary** once the default is
  repo-wide: any `PATH_SCOPE` under the repo (outside `specs/**`) is scannable by construction,
  closing requirement (3) without new validation logic.

## Context & Scope

This task absorbed a second, formerly-separate task (256) that targeted a related but
independent defect in `validate-wiring.sh`. Both live under one `file_scope` now:
`check-task-references.sh`, `task-reference-patterns.sh` (read-only — no changes expected),
`task-reference-exemptions.md`, `test-check-task-references.sh` (new), the hook
`validate-no-task-references.sh` (verify parity — no code change expected), the rule
`no-task-references-in-deliverables.md`, `validate-wiring.sh`, and `test-validate-wiring.sh`
(new).

Evidence for the check-task-references.sh defect comes from two independent consumer repos
(Verification, ModelChecker) hitting the same failure mode: a hard-coded four-tree list that
matches neither repo's actual source layout (`docs/`, `README.md`, `framed_channel/`, `nix/`,
`.github/` in one; `code/` in the other), so the lint silently scans nothing relevant while the
governing rule (`no-task-references-in-deliverables.md`) claims repo-wide reach.

Evidence for the validate-wiring.sh defect is a single measured incident in ModelChecker after a
consumer-local `.opencode/` deploy deletion: `all` went from 89 failures (100% attributable to
the stale `.opencode` arm, `.claude` side clean) to 15 failures (100% attributable to the now-
*absent* `.opencode` arm), while `--claude` alone reported 0 failures throughout.

## Findings

### Codebase Patterns

**`check-task-references.sh` (190 lines)**:
- `TREE_ROOTS=(agent-system/extensions .opencode lua .memory)` (line ~102) is the sole source of
  the defect. `scan_tree()` already has a `[[ ! -d "$enum_dir" ]]` guard that prints
  `"  [SKIP] $label does not exist under $REPO_ROOT"` and returns 0 — this is the exact
  precedent the absorbed validate-wiring.sh defect is asked to mirror.
- Enumeration goes through `git -C "$REPO_ROOT" ls-files "$enum_path"`, so `.git` internals are
  never walked and anything gitignored (including `.claude/`, confirmed gitignored at
  `/home/benjamin/.config/nvim/.gitignore:1-5`) is automatically excluded — no special-casing
  needed for the deploy tree.
- `PATH_SCOPE` (an optional positional arg) is currently validated against `TREE_ROOTS` membership
  and exits 2 if it falls outside all four — this is requirement (3)'s defect.
- Per-finding print format is `"  $rel:$finding"` where `$finding` is `grep -n`'s `LINE:content`
  — i.e. `"  path:line:content"`. **This format must be preserved**: `verify-deploy.sh` gate 4
  (line ~417) greps non-quiet output for `^  [^:]+:[0-9]+:` to build its `FINDING gate4 ...` list.
  Any redesign of the reporting/grouping structure must keep this exact leading two-space,
  colon-separated shape for finding lines.
- `verify-deploy.sh` gate 4 only runs when `$TARGET/agent-system/extensions` exists — i.e. it
  **only ever exercises the source-store repo** (this repo), never a deploy consumer. This
  substantially de-risks the redesign: the one automated caller of `check-task-references.sh`
  always runs it against exactly the repo whose equivalence was measured at 0/0.

**`scripts/lib/task-reference-patterns.sh` (90 lines, read-only for this task)**: exports
`TASK_PATTERN`, `PHASE_PATTERN`, `is_exempt_path` (specs/** only), `strip_exempt_regions`
(marker-based content exemption). Both `check-task-references.sh` and
`hooks/validate-no-task-references.sh` source it and define no pattern/exemption logic of their
own — already a single source of truth. No changes needed here; the fix is entirely in how
`check-task-references.sh` *enumerates files*, not in what counts as exempt.

**`hooks/validate-no-task-references.sh` (132 lines)**: a PreToolUse hook keyed on the file path
of the current Write/Edit call, not on any enumerated tree list. Its only scope filter is
`is_exempt_path "$FILE"` (line 80) — i.e. it already treats "everything outside `specs/**`" as
in-scope, for whatever repo it happens to run in. **No code change is needed here.** The
`file_scope` inclusion of this file is for verification (confirming it stays in agreement) and
because requirement (8) explicitly calls it out as the second pattern-library consumer, not
because it needs editing.

**Measured equivalence** (this repo, 2026-09-28):
```
$ REPO_ROOT=$(pwd) bash check-task-references.sh --quiet
  agent-system/extensions: 0 occurrence(s)
  .opencode: 0 occurrence(s)
  lua: 0 occurrence(s)
  .memory: 0 occurrence(s)
PASS: 0 unexempted task-reference occurrences across 4 tree(s)

$ (repo-wide git-ls-files walk, same is_exempt_path/strip_exempt_regions/pattern pipeline, minus specs/)
TOTAL=0
```
Both are 0. Requirement (1) ("the nvim repo's scan result is equivalent to today's — same files
flagged") is satisfied by measurement: an empty set is trivially equal to an empty set, and nothing
in this repo's non-`specs/` tree would newly surface once scope widens.

This repo's top-level git-tracked entries beyond the current four `TREE_ROOTS` include: `after/`,
`.context`, `docs/`, `init.lua`, `init.lua.backup`, `lazy-lock.json`, `README.md`, `scripts/`,
`snippets/`, `spell/`, `templates/`, `CLAUDE.md`, `.pylintrc`, `pyrightconfig.json`,
`.sync-exclude`, `.syncprotect`, `.claude-extensions.json`, `.gitignore`, `.github`. None of them
currently carry an unexempted task-number citation, so widening scope to all of them costs
nothing today and closes the exact gap the two consumer-repo incidents demonstrated.

**`validate-wiring.sh` (312 lines)**:
- `main()` (lines 275-312) unconditionally calls `validate_core_system` +
  `validate_extensions_loaded` against `"$PROJECT_ROOT/.claude"` when `SYSTEM` is
  `all`/`--all`/`--claude`, and against `"$PROJECT_ROOT/.opencode"` when `all`/`--all`/`--opencode`
  — with no existence check on either directory. `validate_agent_exists`,
  `validate_index_entries`, and `validate_context_files` all read files under the given
  `system_dir` and emit `log_fail` (not skip) when a file is absent, which is exactly right when
  the tree is *present but broken*, but wrong when the tree is *not deployed at all*.
- Fix: guard each arm on `[[ -d "$PROJECT_ROOT/.claude" ]]` / `[[ -d "$PROJECT_ROOT/.opencode" ]]`
  before calling the two validate_* functions; print a `[SKIP]`-style `log_info` line (mirroring
  `check-task-references.sh`'s `"[SKIP] $label does not exist under $REPO_ROOT"` wording) when
  absent, so the exit status (driven by `$FAILED`) reflects only trees actually present.
- **Confirmed SAFE (re-verified, not just trusted)**: `deploy-root-guard.sh` and
  `validate-state.sh` both match the *running script's own path* against
  `*/.claude/scripts/` or `*/.opencode/scripts/` (deploy-root-guard.sh line 18-19;
  validate-state.sh line 238) — an absent *sibling* tree is irrelevant to either check.
  `hooks/validate-handoff-location.sh` matches a `specs/(OC_)?[0-9]+_.../...` path-shape regex
  (line 65) with zero reference to a `.opencode` directory's existence. All three are correctly
  out of scope for this defect.
- Deployment must be a real `.claude/scripts/` or `.opencode/scripts/` tree (`deploy-root-guard.sh`
  requires the parent-of-parent directory name to literally be `.claude` or `.opencode`, no
  env-var override) — this constrains how a fixture test for this script must be built (see
  Testing below).

### External Resources

None consulted — this is a purely internal shell-scripting/repo-layout defect with no external
API or library surface.

### Recommendations

**check-task-references.sh — Option (a), coverage, chosen over Option (b), carve-out.**
Requirement (7) explicitly asks research to weigh declaring consumer source trees out of scope
in the rule text instead of fixing the scanner. Recommend against that: the measured-0/0
equivalence means fixing the scanner costs nothing in this repo, and the two independent
consumer-repo incidents are exactly the failure mode a repo-wide default eliminates by
construction (no future repo layout can "not match" a scan of everything). A carve-out would
require rewriting `no-task-references-in-deliverables.md`'s "the entire repository EXCEPT
specs/**" principle into something narrower and repo-specific, which is a bigger, more permanent
documentation liability than the one-time cost of verifying 0/0 equivalence here.

Concretely:
1. Replace the default (no-`PATH_SCOPE`) branch's enumeration: instead of iterating
   `TREE_ROOTS`, enumerate `git -C "$REPO_ROOT" ls-files` once, repo-wide, and run every
   non-`specs/**` file (via the existing `is_exempt_path`) through the existing
   `strip_exempt_regions` / pattern-match pipeline. `scan_tree()`'s per-directory-existence
   `[[ ! -d ]]` guard is no longer needed for the default path (the repo root always exists);
   keep it for `PATH_SCOPE` mode (a scope argument naming a directory that doesn't exist should
   still print the existing `[SKIP]` line rather than erroring).
2. Collapse the four-line `TREE_COUNT`/`REPORT_KEYS` per-tree summary into a single repo-wide
   count for the default path (e.g. `"repo (excluding specs/): N occurrence(s)"`), OR — a cheaper
   change with no reporting-shape churn — keep per-tree reporting but derive `TREE_ROOTS`
   dynamically as the sorted list of top-level git-tracked entries minus `specs`. Either is
   compatible with requirement (1)'s equivalence; the plan phase should pick based on how much
   the existing multi-line summary format is depended on elsewhere (grep confirms nothing outside
   this script keys off the specific `"agent-system/extensions: N occurrence(s)"` line text — see
   Appendix). Recommend the simpler single-count form given no such dependency exists.
3. `PATH_SCOPE` validation: drop the `TREE_ROOTS`-membership check entirely (requirement 3). The
   only remaining input-validation concern is a `PATH_SCOPE` that resolves to (or under)
   `specs/**` — since `is_exempt_path` will make such a scan trivially report 0 findings anyway,
   no special-case rejection is needed; the existing generic "does not exist" `[SKIP]` and 0-count
   PASS output already handle it gracefully. This keeps the exit-code contract unchanged (2 stays
   reserved for genuine usage/environment errors: missing library, missing git, unknown flag,
   extra arguments).
4. Preserve the exact `"  $rel:$finding"` per-finding line format (leading two spaces, no colon
   in `$rel`) — `verify-deploy.sh` gate 4 depends on it.
5. **No change to `scripts/lib/task-reference-patterns.sh`** — `is_exempt_path` already is the
   single correct scope predicate; the fix is entirely in what `check-task-references.sh` feeds
   through it.
6. **No change to `hooks/validate-no-task-references.sh`** — already scope-correct. Requirement
   (8)'s "must not drift" is satisfied as a byproduct: once the lint's only remaining scope filter
   is `is_exempt_path`, both consumers share that one predicate and cannot silently diverge again
   (any future exemption-scope change happens in the shared lib and is inherited by both, or not
   at all).

**Documentation updates** (requirement 5):
- `context/standards/task-reference-exemptions.md`'s "## Enforcement" section (lines 64-67)
  currently reads: *"Three layers. `specs/**` is the ONLY exempt tree — `agent-system/extensions/**`,
  `.opencode/**`, `lua/**`, and `.memory/**` are all deliverables subject to this rule."* and (line
  69) *"scans every git-tracked file under the four deliverable tree roots above."* Both sentences
  must be rewritten to describe the repo-wide-minus-`specs/**` scan (no more "four deliverable tree
  roots" framing) — this is the one place in the file_scope that literally asserts the old
  four-root model as settled fact rather than as historical color.
- `rules/no-task-references-in-deliverables.md` — no factual change needed to its own text (it
  already says "the entire repository EXCEPT `specs/**/*`..."); it was the *lint* that fell short
  of the rule's own claim, not the rule's wording. It stays in `file_scope` per the dispatch note
  ("the rule file itself is a deliverable, which is why it is now in file_scope") in case the plan
  phase decides a cross-reference or clarifying note is warranted once the lint catches up, but no
  correction to its substantive claim is expected.

**validate-wiring.sh** (requirement set from absorbed task 256):
1. Guard both the `.claude` and `.opencode` arms in `main()` on directory existence; print a
   `[SKIP]`-style line (via `log_info`, matching the `"[SKIP] ..."` wording precedent) instead of
   calling `validate_core_system`/`validate_extensions_loaded` when absent.
2. No changes needed to `deploy-root-guard.sh`, `validate-state.sh`, or
   `hooks/validate-handoff-location.sh` — all three re-verified SAFE (see Findings above).
3. Add a regression test (`test-validate-wiring.sh`) covering a consumer layout with `.claude`
   present and `.opencode` absent, asserting: (a) a `[SKIP]` line naming `.opencode`, not a
   `[FAIL]` line; (b) no `[FAIL]` line mentions `.opencode` at all; (c) the exit code depends only
   on the `.claude` side's outcome.

## Decisions

- **Option (a) chosen over Option (b)** for check-task-references.sh: fix the scanner to be
  repo-wide-minus-`specs/**`, do not carve out a documented exception. Rationale: measured 0/0
  equivalence in this repo plus two independent consumer-repo failures of the exact shape a
  repo-wide default eliminates by construction.
- **No per-repo config file and no nvim-layout detection.** A plain `git ls-files` walk already
  respects `.gitignore` (so `.claude/`, build artifacts, etc. are excluded by construction in any
  repo that gitignores its own deploy tree and generated output) and needs no repo-specific
  branching. This is simpler to maintain than either alternative the dispatch description
  floated, and it is the option that produces the measured 0/0 equivalence directly.
- **`task-reference-patterns.sh` and `validate-no-task-references.sh` require no code changes.**
  The shared lib's `is_exempt_path` is already the correct, sole scope predicate; the hook already
  consumes only that predicate. The fix is confined to `check-task-references.sh`'s file
  enumeration.
- **`validate-wiring.sh`'s fix is independent of the check-task-references.sh fix** and touches a
  disjoint code path (existence guards in `main()`, not pattern/exemption logic) — both land in
  this task but can be implemented and tested as two separate, non-interacting changes within one
  plan.

## Risks & Mitigations

- **Risk**: widening the default scan could surface latent violations in this repo's newly-
  included trees (docs, README, init.lua, etc.), breaking requirement (1). **Mitigation**:
  already measured at 0/0 (see Findings) — no latent violations exist today. The plan/implement
  phase should re-run the equivalence check once more immediately before landing the change (cheap,
  ~1 command) to catch any drift introduced by concurrent sibling tasks in this same orchestrate
  cycle.
- **Risk**: a future repo with large committed vendored/generated directories (checked-in
  `vendor/`, `node_modules/`, etc.) could produce scan noise or false positives once scope is
  repo-wide. **Mitigation**: `git ls-files` already excludes anything gitignored, which is the
  normal way such directories are kept out of version control; if a future repo commits such a
  directory anyway, `is_exempt_path` remains the single, already-documented extension point to add
  a path-level exemption — no new mechanism needed, just a new case arm in one function.
- **Risk**: `verify-deploy.sh` gate 4's `FINDING gate4` parsing breaks if the per-finding print
  format changes. **Mitigation**: explicitly called out above as a preserve-verbatim constraint;
  not touched by this recommendation regardless of which reporting-shape option (single count vs.
  dynamic per-top-level-entry) the plan phase picks.
- **Risk**: `validate-wiring.sh`'s `[SKIP]` fix could mask a *genuine* regression where `.opencode`
  should exist (this very repo, where the frozen mirror stays in place) but was accidentally
  deleted. **Mitigation**: out of scope for this narrow fix per the dispatch note's explicit
  "Explicitly OUT of scope" list (no `.opencode` reference removal, no frozen-mirror policy
  changes); the SKIP is the same class of "absence is a normal supported configuration" signal
  `check-task-references.sh` already gives for `lua` in a non-nvim repo, and this repo's own CI/
  verify-deploy path is unaffected since it always has both trees present.

## Context Extension Recommendations

- **Topic**: repo-wide vs. tree-scoped lint defaults.
- **Gap**: no existing standards doc states the general principle "a lint/gate script consumed by
  multiple repos of differing layout should default to the widest safe scope (repo-wide minus a
  documented exempt set), not a hard-coded list of this repo's own directories." This defect class
  (TREE_ROOTS encoding the nvim repo's own layout) could recur in a future script.
- **Recommendation**: consider adding a short subsection to
  `context/standards/task-reference-exemptions.md` or a new cross-cutting standard capturing this
  principle, once this fix lands, so a future script author has a named precedent to follow rather
  than re-discovering it via a third consumer-repo incident.

## Appendix

### Search queries / commands used

- `git ls-files | cut -d/ -f1 | sort -u` — enumerate this repo's top-level tracked entries.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`
  — baseline (four-tree) scan result: 0 findings.
- Inline repro of a repo-wide `git ls-files` walk through `is_exempt_path` /
  `strip_exempt_regions` / `TASK_PATTERN`/`PHASE_PATTERN` (sourced from
  `scripts/lib/task-reference-patterns.sh` unmodified) — repo-wide scan result: 0 findings.
- `grep -rn "check-task-references\|TREE_ROOTS"` across `agent-system/extensions/core/scripts/`,
  `context/`, `rules/` — located every consumer of the script and confirmed
  `verify-deploy.sh` gate 4 is the only automated caller, source-store-only.
- `grep -n "\.opencode"` in `deploy-root-guard.sh`, `validate-state.sh`,
  `validate-handoff-location.sh` — re-verified all three SAFE per the dispatch note's own claim.
- Read `test-validate-no-task-references.sh` and `test-deploy-verify-wiring.sh` in full as the two
  structural templates for the two new test suites this task's `file_scope` requires
  (`test-check-task-references.sh`, `test-validate-wiring.sh`) — both follow
  `shell-script-testing.md`'s `pass()`/`fail()`/`info()` + `mktemp -d` + trap-cleanup convention;
  `test-deploy-verify-wiring.sh` specifically demonstrates building a throwaway consumer-shaped
  git fixture repo (`mkdir -p "$FIXTURE/.claude"; git init -q "$FIXTURE"; ...`), which is the
  right structural model for both new suites here (a consumer-repo-shaped fixture for
  check-task-references.sh; a `.claude`-present/`.opencode`-absent fixture for
  validate-wiring.sh, noting `deploy-root-guard.sh` requires the fixture's script copy to sit at
  `<fixture>/.claude/scripts/validate-wiring.sh`, mirroring how `test-deploy-verify-wiring.sh`
  places its target scripts).

### References

- `agent-system/extensions/core/scripts/check-task-references.sh`
- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh`
- `agent-system/extensions/core/hooks/validate-no-task-references.sh`
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md`
- `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`
- `agent-system/extensions/core/scripts/validate-wiring.sh`
- `agent-system/extensions/core/scripts/deploy-root-guard.sh`
- `agent-system/extensions/core/scripts/lib/common.sh`
- `agent-system/extensions/core/scripts/verify-deploy.sh` (gate 4)
- `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (test template)
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` (fixture-repo template)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (test location/naming
  convention)
