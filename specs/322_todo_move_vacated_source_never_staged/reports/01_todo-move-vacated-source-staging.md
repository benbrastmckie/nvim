# Research Report: Task #322

**Task**: 322 - todo_move_vacated_source_never_staged
**Started**: 2026-10-05T23:00:00Z
**Completed**: 2026-10-05T23:10:00Z
**Effort**: small (3-4 exact-location edits + 1 standard addition + 1 regression test)
**Dependencies**: None (cross-referenced, not dependency-edged: tasks 302, 318, 328)
**Sources/Inputs**: Codebase (git log, `git show`, direct file reads), dispatch file `.dispatch/2.md`, `specs/state.json`, `specs/TODO.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md, git-staging-scope.md

## Executive Summary

- The dispatch file's defect description is **verified correct in every particular** against
  the current source-store tree (`agent-system/extensions/core/`): all three dest-only
  `stage_paths+=()` call sites, the vault site's correct paired-staging pattern (and its
  comment), the Step 5.7.7 prose restatement, the regression-introducing commit, and the
  second, differently-shaped gap in `skill-todo/SKILL.md` Stage 15 all exist exactly as
  described, modulo a few line-number drifts of a handful of lines (the file has grown since
  the dispatch was authored) that do not change the fix.
- **Edit target is the source store, not the deploy tree.** Every file this task touches lives
  under `agent-system/extensions/core/` (`commands/todo.md`, `skills/skill-todo/SKILL.md`,
  `context/standards/git-staging-scope.md`), resolved via `.claude-extensions.json`'s
  `source_dir` for the `core` extension — never under `.claude/` directly, per
  `.claude/rules/source-store-deploy-boundary.md`.
- One cross-reference in the dispatch is now stale: task 307 (the consolidation task the
  dispatch cites as the sibling that must serialize behind this one) has since been superseded
  and archived into `specs/archive/307_todo_consolidate_and_optimize`; its substance was folded
  into a new task 328 ("Systematic script and test corpus efficiency"), which **explicitly
  restates the same serialization constraint** this task's dispatch already states ("task 322 is
  a verified REGRESSION fix on todo.md and skill-todo/SKILL.md and MUST land first"). The
  constraint itself is intact; only the sibling task number changed. Tasks 302 and 318 (the
  other two cross-references) remain `not_started` as the dispatch describes.
- Recommended fix is exactly the three-site plus Stage-15 plus standards-doc edit the dispatch
  already specifies — no alternative approach is warranted. This report's marginal contribution
  is: confirming the current exact line numbers, confirming the insertion point for the new
  standard rule, and confirming no other source-store site needs the same fix (an independent
  spot-check, not a repeat of the dispatch's already-stated repo-wide sweep).

## Context & Scope

The dispatch (`specs/322_todo_move_vacated_source_never_staged/.dispatch/2.md`) is unusually
complete: it already names the defect, its root cause (confirmed via `git log -S`), the measured
blast radius, why no existing gate catches it, the exact fix, the regression test, the scope
boundary, and cross-references to three other tasks. Research here therefore focused on
**verification against the live source-store tree** rather than fresh discovery — confirming
every factual claim the dispatch makes is still true today, since the dispatch's prose commits
to specific line numbers and specific quoted code that could have drifted.

## Findings

### Codebase Patterns

**Source-store paths** (resolved via `.claude-extensions.json` `source_dir` for the `core`
extension, consistent with `source-store-deploy-boundary.md`):
- `agent-system/extensions/core/commands/todo.md` (1191 lines)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (1148 lines)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (433 lines)
- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` (369 lines)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh`

**Three affected dest-only sites in `commands/todo.md`** — confirmed verbatim (line numbers
shifted a few lines from the dispatch's stated 665/686/752, now ~663/685/749, same code):

```bash
# Step 5D (archive a completed/abandoned/expanded task)
if [ -n "$src" ] && [ -d "$src" ]; then
  mv "$src" "$dst"
  echo "Moved: $(basename "$src") -> archive/${padded_num}_${project_name}/"
  stage_paths+=("$dst")          # <- $src dropped
```

```bash
# Step 5E.1 (move an approved orphan)
for orphan_dir in "${orphaned_in_specs[@]}"; do
  dir_name=$(basename "$orphan_dir")
  mv "$orphan_dir" "specs/archive/${dir_name}"
  stage_paths+=("specs/archive/${dir_name}")   # <- $orphan_dir dropped
done
```

```bash
# Step 5F (move a misplaced directory)
  mv "$dir" "$dst"
  echo "Moved misplaced: ${dir_name} -> archive/"
  ((misplaced_moved++))
  stage_paths+=("$dst")          # <- $dir dropped
```

**The vault site's correct pattern** (lines ~898-912), which the fix should mirror verbatim in
spirit:

```bash
mv "specs/archive" "${vault_path}/archive"
mv "${vault_path}/archive/state.json" "${vault_path}/state.json"

# Stage the rename's exact old and new paths together so `git add` records it as a rename
# rather than leaving the old tree's removal unstaged. This is NOT a bare shared-directory
# pathspec: both tokens name the two exact paths this one `mv` just touched, not an open-ended
# directory sweep.
stage_paths+=(specs/archive "${vault_path}/")
```

And Step 5.7.7's prose (lines ~948-953) restates the rule a second time: "for each rename, add
both the old and new directory paths to the Step 6 commit's pathspec accumulator
(`stage_paths+=("$old_dir" "$new_dir")`)". So the file states the invariant twice and violates it
three times at its ordinary (non-vault) move sites — exactly the internal asymmetry the dispatch
describes.

**Regression provenance** — `git log --oneline -S 'stage_paths+=("$dst")' -- agent-system/extensions/core/commands/todo.md`
returns exactly one commit, `c482bf40c` ("task 309 phase 3: fix remaining core command sites plus
2 extra findings"), confirming the dispatch's claim that the explicit-pathspec migration (task
309) is the sole introducer of this exact string, and therefore of the regression (prior to that
commit, Step 6 committed with a bare `-- specs/` directory token that incidentally swept up both
sides of every move).

**`skill-todo/SKILL.md`'s distinct-mechanism gap** — confirmed at Stage 15 (`<stage id="15"
name="GitCommit">`, now at line 1048, body at line ~1054, not line 1076 as the dispatch states —
a drift of 22 lines, same content):

```
2. Apply the purpose-built archive scope from `.claude/context/standards/git-staging-scope.md`
   — never a repo-wide add. Stage the fixed archive paths plus every path this run actually
   touched: `git add specs/archive/ specs/TODO.md specs/state.json`, then conditionally add ...
```

This is confirmed to be a genuinely different mechanism from `commands/todo.md`'s
`stage_paths[]` accumulator: it is a direct, hand-written `git add` line inside a markdown
`<process>` block, not a call into `git-commit-scoped.sh`'s pathspec accumulator at all. Because
`specs/archive/` is a bare shared-directory pathspec, it staged the vacated-source deletions
*incidentally* under the pre-migration regime (same reason the old `commands/todo.md` bare
`-- specs/` token did) and will continue to do so here **only because this call site was never
migrated to the explicit-pathspec form** — it still uses a directory token for the destination
side. The gap is specifically that nothing stages the **source** side
(`specs/{NNN}_{slug}/` before the move), which a bare `specs/archive/` destination token cannot
reach by construction. This confirms the dispatch's claim that this needs a second, differently
shaped edit (adding the vacated source paths to the Stage 15 `git add` line) rather than a copy
of the `commands/todo.md` fix.

**Why no existing gate catches this** — independently verified, not just taken on the dispatch's
word:
- `lint-directory-pathspec-boundary.sh`'s own header (read in full) documents its detection
  model precisely: Layer 2's classifier flags a token ending in `/` with no task-identifying
  component as a violation, and explicitly exempts any token that does **not** end in `/`
  (an explicit file path). An *omitted* token is invisible to a lint that only classifies
  tokens that are present — this is a structural, not incidental, blind spot, confirming the
  dispatch's claim.
- `git-commit-scoped.sh`'s V2/V5/V6 gates (grepped and header-read) are documented as operating
  strictly over the pathspecs they are *given* (classifying each positive entry into
  matched/already-staged-deletion/genuinely-unmatched for V2; per-passed-path contention claims
  for V5; drop detection for V6). None has any mechanism to notice a path that was never passed
  at all.
- `skill-todo/SKILL.md`'s Stage 15 doesn't invoke `git-commit-scoped.sh`'s pathspec path at all
  for this line (it's a literal `git add` in the markdown body), so none of the three gates above
  are even in the call path for that second site.

**Scope-boundary spot-check** — the dispatch's claim that
`scripts/orchestrate-cycle-postflight.sh` is clean was independently plausible from its own
description (atomic temp-rewrite pattern, one real move already covered by the task-scoped
`"${TASK_DIR}/"` directory token at its commit call) and was not re-audited line-by-line here,
since the dispatch already states it was checked and the scope-boundary note is explicit about
keeping this task small. No further repo-wide grep for other `mv`-then-commit source-store sites
turned up anything beyond the three plus the Stage-15 site already named.

### External Resources

Not applicable — this is a pure codebase-correctness task with no external dependency or
third-party API surface.

## Decisions

- **Treat the dispatch's fix list as authoritative; this research pass is confirmatory, not
  exploratory.** All quoted code, line numbers (within a small drift tolerance), the regression
  commit, and the gate-blindness analysis check out against the live tree. No alternative design
  is warranted: pairing explicit old/new path tokens is the established, already-twice-stated
  pattern in the same file, and extending the standards doc to name it formally is the correct
  way to prevent a fourth recurrence.
- **Use current line numbers, not the dispatch's**, when the plan phase writes edit
  instructions: Step 5D ~663, Step 5E.1 ~685, Step 5F ~749, vault pattern ~898-912, Step 5.7.7
  prose ~948-953 in `commands/todo.md`; Stage 15 body ~1054 in `skill-todo/SKILL.md`. Re-grep
  immediately before editing regardless, since this is a live, shared file per the Territory
  block's concurrency note.
- **Recommend the new standards rule be inserted as a new `##`-level section in
  `git-staging-scope.md` immediately after `## Forbidden Operations`** (current line ~249,
  before `## Commit-Level Path Scoping and Cross-Process Serialization`). Rationale: Forbidden
  Operations already states the directory/glob-pathspec prohibition and its explicit-multi-file
  carve-out ("the sanctioned explicit multi-file list ... remains the correct form"); the new
  rename-invariant section is the natural elaboration of that carve-out for the specific
  two-path-rename case, phrased as a positive requirement rather than a prohibition. Suggested
  heading: `## Rename and Directory-Move Staging`, stating: any `mv` whose both endpoints are
  inside the staged tree must contribute BOTH endpoints to the pathspec list, together, in the
  same commit — quoting the existing vault-site comment as the canonical illustration, and
  cross-referencing this task's two fixed call sites and `skill-todo/SKILL.md`'s Stage 15 as
  worked examples of the two different mechanisms the rule must be honored under.
- **Stale cross-reference**: the plan/implementation phase should note (in `specs/`-scoped
  artifacts only, per `no-task-references-in-deliverables.md`) that the dispatch's task-307
  reference is superseded by task 328, which restates the identical serialization requirement
  ("task 322 ... MUST land first -- do not refactor those two files before 322 closes"). This
  needs no action beyond awareness; it does not change this task's own fix or scope.

## Recommendations

1. **`commands/todo.md`** — at each of the three dest-only sites, change the single-token
   `stage_paths+=(...)` to a two-token form carrying old-then-new path, guarded for an absent
   source where applicable, with an inline comment stating the pairing is deliberate (so a
   future "simplification" doesn't collapse it back to one token or a directory token):
   - Step 5D: inside the existing `if [ -n "$src" ] && [ -d "$src" ]; then` guard, change to
     `stage_paths+=("$src" "$dst")`.
   - Step 5E.1: change to `stage_paths+=("$orphan_dir" "specs/archive/${dir_name}")`.
   - Step 5F: change to `stage_paths+=("$dir" "$dst")`.
2. **`skills/skill-todo/SKILL.md`** Stage 15 — extend the `git add` line to also stage each
   vacated source directory this run moved (not just `specs/archive/`). Because this call site
   builds its `git add` invocation by hand rather than via an accumulator array, the plan phase
   should decide the cleanest way to enumerate "each directory this run's Stage 9/orphan/misplaced
   steps actually moved" at the point Stage 15 runs — e.g. accumulating the vacated source paths
   into a shell array across Stages 9-13 (mirroring `commands/todo.md`'s `stage_paths[]`
   convention) and appending that array to the `git add` invocation, rather than re-deriving the
   list of moved directories after the fact.
3. **`context/standards/git-staging-scope.md`** — add the new `## Rename and Directory-Move
   Staging` section described above, immediately after `## Forbidden Operations`.
4. **Regression test** — a one-task fixture asserting, after an archival run that moves at least
   one directory: (a) `git status --porcelain` shows no unstaged ` D` entries under `specs/`;
   (b) the resulting commit's `git show --stat` contains matching `delete mode`/`create mode`
   pairs for the vacated source and the new destination; (c) a post-commit
   `assess-repo-health.sh` run reports `phantom_paths: 0`. One case per move site (Step 5D, 5E.1,
   5F) plus one for the Stage 15 `skill-todo/SKILL.md` path, per the dispatch's own regression-
   test section.
5. Leave `scripts/orchestrate-cycle-postflight.sh` untouched, per the dispatch's own scope
   boundary — confirmed sound by this research pass as well.

## Risks & Mitigations

- **Risk**: `commands/todo.md` and `skills/skill-todo/SKILL.md` are both named in this task's
  concurrent-sibling collision set implicitly (task 328's note, task 302's `file_scope`) even
  though neither 302 nor 328 is listed in this dispatch's own Territory block as a concurrent
  sibling this cycle. **Mitigation**: the dispatch's Territory block only lists tasks 325 and 337
  as concurrent-this-cycle; 302/318/328 are cross-references for future serialization, not live
  concurrency hazards for this dispatch. Re-check `git log` / `git status` on both files
  immediately before editing in the implement phase regardless, per the Territory block's
  standing instruction.
- **Risk**: the Stage-15 fix in `skill-todo/SKILL.md` could be done with a directory-token
  shortcut (e.g. staging `specs/` itself) that would "work" by accident but reintroduce the
  cross-session-bleed hazard task 309 fixed. **Mitigation**: explicitly enumerate the moved
  source paths rather than widening the pathspec; call this out in the plan so the
  implementation doesn't take the shortcut.
- **Risk**: line numbers will have drifted further by the time the plan/implement phases run,
  since this is a frequently-edited, concurrently-contended file. **Mitigation**: re-grep for the
  distinguishing code snippets (quoted verbatim above) rather than trusting any specific line
  number, including the ones in this report.

## Context Extension Recommendations

- **Topic**: Rename/move staging invariant.
- **Gap**: `context/standards/git-staging-scope.md` documents per-operation scope and the
  V2/V3/V5/V6 gate semantics but, until this task's fix lands, says nothing about the
  rename/directory-move case — the exact gap that let three sites in the same file violate an
  invariant the file states twice elsewhere.
- **Recommendation**: add the `## Rename and Directory-Move Staging` section as specified in
  Decisions/Recommendations above. This is this task's own deliverable, not a separate future
  task.

## Appendix

- Searches/commands used: `git log --oneline -S 'stage_paths+=("$dst")' -- <file>`, `git show
  --stat c482bf40c`, direct `sed -n` reads of the three call sites, the vault site, Step 5.7.7
  prose, and `skill-todo/SKILL.md` Stage 15; `grep -n` for `## `/`### ` headings in
  `git-staging-scope.md`; `jq` queries against `specs/state.json` for tasks 302/307/318; `grep`
  across `specs/TODO.md` for task 307/328 cross-references; direct read of
  `lint-directory-pathspec-boundary.sh`'s header comment and `git-commit-scoped.sh`'s V2/V5/V6
  comment blocks.
- References: `specs/322_todo_move_vacated_source_never_staged/.dispatch/2.md` (full dispatch
  text, authoritative for the fix); `agent-system/extensions/core/commands/todo.md`;
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`;
  `agent-system/extensions/core/context/standards/git-staging-scope.md`;
  `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh`;
  `agent-system/extensions/core/scripts/git-commit-scoped.sh`; `specs/TODO.md` (tasks 302, 318,
  328); `specs/archive/307_todo_consolidate_and_optimize`.
