# Research Report: Task #249

**Task**: 249 - Restore the eager-context budget: trim the source-store rule to a lazy narrative rather than re-baselining
**Started**: 2026-09-22T19:14:20Z
**Completed**: 2026-09-22T19:45:00Z
**Effort**: small (single-file split, no logic changes)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/**), git history, live script execution (measure-eager-context.sh, verify-deploy.sh gate 20, test-verify-deploy-context-budget.sh)
**Artifacts**: - specs/249_restore_eager_context_budget/reports/01_eager-context-budget-trim.md
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md (this task's own subject)

## Executive Summary

- Confirmed live: `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` reports `TOTAL: 67003 B`, 1,053 B over `eager_load.baseline_bytes` (65,950 B) in `agent-system/extensions/core/context/config/orchestrator-context-budget.json`. This matches the dispatch's evidence exactly.
- Root cause confirmed via git history: commit `fd9d0286f` ("task 227 phase 1: rewrite the rule's target resolution") grew `rules/source-store-deploy-boundary.md`'s `## Correct Edit Target` section from two bullet points + a hardcoded-path example (2,746 B whole file) to a 5-step resolution procedure + an "unreachable source store" branch + a resolved-path example (4,443 B whole file, +1,697 B). The `## Exceptions` and `## Enforcement` sections were **not** touched by that commit — they were already present pre-growth at essentially their current size. The growth is entirely inside `## Correct Edit Target`.
- Recommended approach: apply the SAME rule -> lazy-narrative split already used twice in this codebase (`rules/git-workflow.md` -> `context/standards/git-workflow-narrative.md`; `rules/state-management.md` -> `context/reference/state-management-schema.md`). Keep `## Path Pattern`, `## Principle`, and a one-line `## Correct Edit Target` pointer eager (~1,496 B measured); move the 5-step procedure, the unreachable-source-store branch, the worked Before/After example, `## Exceptions`, and `## Enforcement` into a new lazily-loaded `context/standards/source-store-deploy-boundary-narrative.md`, referenced from the rule by a plain backticked path (never an `@`-import).
- Projected result: new rule file ≈1,496 B (was 4,443 B, -2,947 B). Projected new eager TOTAL = 67,003 - 2,947 = **64,056 B**, i.e. **1,894 B of headroom** under the 65,950 B baseline — well above "restore to exactly baseline," satisfying the dispatch's "aim for headroom, not par" instruction ahead of the two queued tasks that will add further eager bytes (git-workflow.md edit; pr-prohibition.md + claudemd.md edit).
- No re-baselining is needed or recommended: the trim alone clears the breach with margin, and the dispatch gates re-baselining behind a written justification this trim makes unnecessary.

## Context & Scope

Task 249 targets a single, precisely diagnosed regression: the eager-context byte budget gate
(`verify-deploy.sh` gate 20, backed by `context/config/orchestrator-context-budget.json`'s
`eager_load.baseline_bytes`) is failing because one eagerly-loaded rule file
(`rules/source-store-deploy-boundary.md`) grew 62% in a prior, unrelated task (task 227) without
the budget gate being run at completion time. The dispatch names the exact remedy shape
(rule -> lazy-narrative split, following two existing precedents) and gates the fallback
(re-baselining) behind explicit written justification. This report verifies the diagnosis,
designs and byte-measures the exact split, and confirms it clears the gate with headroom.

Scope is confined to `agent-system/extensions/core/rules/source-store-deploy-boundary.md` and a
new companion file under `agent-system/extensions/core/context/standards/`. Per the source-store
rule that is itself the subject of this task, all edits belong in
`agent-system/extensions/core/**`, never in the deployed `.claude/**` tree (confirmed:
`.claude-extensions.json`'s `extensions.core.source_dir` resolves to
`/home/benjamin/.config/nvim/agent-system/extensions/core`, which exists on disk).

## Findings

### Codebase Patterns

**The eager-load measurement pipeline** (`agent-system/extensions/core/scripts/measure-eager-context.sh`)
sums four channels: `parent_chain` (parent + repo CLAUDE.md), `claudemd` (predicted-assembled
`.claude/CLAUDE.md`), `at_import` (`@`-imports, currently 0 B), and `rules` (every eagerly-loaded
rule file — i.e. every `rules/*.md` lacking a `paths:` frontmatter gate, since a path-gated rule
loads only on matching file touch, not every session). Live run confirms:

```
SUBTOTAL	parent_chain	3046
SUBTOTAL	claudemd	33739
SUBTOTAL	at_import	0
SUBTOTAL	rules	30218
TOTAL	67003	16750
```

`rules/source-store-deploy-boundary.md` carries an explicit HTML comment inside the file
justifying why it has no `paths:` frontmatter (its only automated enforcement is a
PostToolUse, non-blocking hook — gating it on first path-touch would let the violating write land
before the agent ever saw the rule). That comment, and the deliberate eager-loading decision it
records, is preserved verbatim in this report's recommended trim — it is exactly the kind of
"must load on every session" justification the dispatch's re-baselining gate would otherwise
require, and it already exists in the file.

**The two existing rule -> lazy-narrative precedents**, read in full as the model:

| Eager rule (kept small) | Lazy companion (moved detail) |
|---|---|
| `rules/git-workflow.md` (8,828 B) | `context/standards/git-workflow-narrative.md` (5,082 B) |
| `rules/state-management.md` (3,850 B) | `context/reference/state-management-schema.md` (25,917 B) |

Both follow the same shape: the eager file keeps binding tables/lists/prohibitions an agent needs
*before* acting, and opens its companion-pointer with an explicit sentence naming what moved
("This is the lazily-loaded companion to `rules/X.md`. The eager core there carries ... This file
carries the reactive elaboration: ..."). The companion file is referenced by a plain backticked
path (e.g. `See context/standards/git-workflow-narrative.md for the sub-step granularity
definition...`), never an `@`-import — `@`-imports are themselves eager, so an `@`-import to the
companion would defeat the split entirely. This report's recommended narrative file mirrors that
exact shape and naming convention (`source-store-deploy-boundary.md` ->
`source-store-deploy-boundary-narrative.md`, parallel to `git-workflow.md` ->
`git-workflow-narrative.md`).

**Growth attribution, confirmed via `git show fd9d0286f~1:...`**: the pre-227 version of the rule
(2,746 B) already contained `## Path Pattern`, `## Principle`, `## Exceptions`, and `## Enforcement`
at essentially today's wording — only `## Correct Edit Target` differed, and only there, holding
two bullet points (hardcoded `agent-system/extensions/core/**` / `agent-system/extensions/<ext>/**`
paths) plus a hardcoded-path Before/After example. Commit `fd9d0286f` replaced that with the
5-step `.claude-extensions.json`-resolution procedure, the "If the source store is unreachable"
branch, and a resolved-path example — the entire +1,697 B is contained in that one section's
rewrite. This confirms the dispatch's attribution is exact and that `## Exceptions` /
`## Enforcement` are not "new growth" — they are pre-existing content that the dispatch's target
eager size (~1,200 B) nonetheless asks to relocate, in service of headroom rather than merely
reverting the regression.

### External Resources

Not applicable — this is a self-contained internal byte-budget/documentation-structure task with
no external dependency or library involved.

### Recommendations

**Recommended split** (measured against the live file, byte-exact):

1. **Trim `rules/source-store-deploy-boundary.md` to 1,496 B** (from 4,443 B), keeping:
   - The existing HTML comment explaining why the rule is deliberately eager (unchanged).
   - `## Path Pattern` (unchanged wording).
   - `## Principle` (unchanged wording).
   - A condensed `## Correct Edit Target` holding exactly the one-line resolution instruction the
     dispatch names ("Read `source_dir` from `<project-root>/.claude-extensions.json` and edit
     under it, at the path mirroring the deployed one — never hand-author under `.claude/**`
     directly.") plus one pointer sentence to the new companion file, naming everything that moved
     (procedure, unreachable-fallback, example, Exceptions, Enforcement) so a reader knows what to
     expect there.

   Verified draft (`/tmp/eager_draft2.md`, `wc -c` = 1,496):
   ```markdown
   # Source Store / Deploy Boundary

   <!-- Deliberately eager (no `paths:` frontmatter): this rule's only automated enforcement is a
   PostToolUse, non-blocking hook, so an agent gated on first path-touch would learn the rule only
   AFTER the violating write landed. Keeping it eager is a recorded decision from the
   context-loading audit (context/architecture/context-layers.md, eager-vs-lazy channels) — do not
   add a `paths:` glob here without first moving enforcement to a pre-write gate. -->

   ## Path Pattern

   Applies to: any write whose target path is `.claude/**` in a repository whose `.claude/` tree was
   produced by a deploy — i.e. any tree carrying a `<project-root>/.claude-extensions.json`. A
   target-path rule, not a content-scanning one, and repository-independent: it applies the same
   way wherever the system deploys.

   ## Principle

   `.claude/` in a deployed tree is a gitignored, disposable deploy artifact regenerated from a
   source store. Hand-authored files landing in `.claude/` are silently wiped by the next
   regeneration — the edit appears to succeed but has no lasting effect.

   ## Correct Edit Target

   Read `source_dir` from `<project-root>/.claude-extensions.json` and edit under it, at the path
   mirroring the deployed one — never hand-author under `.claude/**` directly. See
   `context/standards/source-store-deploy-boundary-narrative.md` for the resolution procedure, the
   unreachable-source-store fallback, a worked example, the Exceptions list, and the enforcement
   mechanism.
   ```

2. **Create `agent-system/extensions/core/context/standards/source-store-deploy-boundary-narrative.md`
   (3,921 B measured)**, carrying, verbatim (no wording changes — this is a relocation, not a
   rewrite, per acceptance criterion 5):
   - An opening companion-note paragraph naming what the eager core keeps vs. what this file
     elaborates (mirrors `git-workflow-narrative.md`'s opening paragraph shape).
   - `## Correct Edit Target — Full Resolution Procedure` (the exact 5 steps currently in the rule).
   - `### If the source store is unreachable` (unchanged).
   - `## Worked Example` (the exact Before/After block, unchanged).
   - `## Exceptions` (unchanged).
   - `## Enforcement` (unchanged, including the Known-limitation paragraph).

3. **No other file needs to change.** A grep across `agent-system/extensions/core/**/*.md` for
   `source-store-deploy-boundary` found references in `commands/meta.md`,
   `agents/general-implementation-agent.md`, `rules/pr-prohibition.md`,
   `context/patterns/system-defect-discrimination.md`, `context/patterns/mcp-server-ownership.md`,
   `merge-sources/claudemd.md`, `rules/no-task-references-in-deliverables.md`,
   `agents/meta-builder-agent.md`, and `context/architecture/context-layers.md`. All of these cite
   the rule by name/path only (never quoting or depending on its `## Correct Edit Target` prose),
   so none require edits — the rule's filename, `## Path Pattern`, and `## Principle` are
   unchanged, and its `source_dir`-resolution behavior is unchanged (relocated, not altered).

**Verification path for the implementer**, using the acceptance criteria already stated in the
task description:
1. `bash .claude/scripts/measure-eager-context.sh --check` — expect `TOTAL: 64056 B` (or close;
   exact figure depends on final wording), comfortably under `baseline_bytes` 65,950 B.
2. `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — this
   suite's failing cases ("baseline fixture is not clean", "could not compute a safe eager-load
   pad amount") are both direct, deterministic consequences of `current_eager > baseline_bytes`
   (confirmed by reading the suite's own assertions at lines ~933-948 and ~170-180 of
   `test-verify-deploy-context-budget.sh`); once the live TOTAL is back under baseline, both clear
   without any change to the test file itself.
3. `bash .claude/scripts/verify-deploy.sh --skip-slow` gate 20 — the same `eager_load` sub-check
   the test suite exercises; clears for the same reason.
4. `run-all.sh` — the eager-context regression is documented as the sole red suite; no other
   change is introduced by this trim, so no other suite should be affected.
5. Behavioral equivalence — every sentence in the current rule is preserved verbatim, only
   relocated between the eager file and the new lazy companion; the prohibition, the exceptions,
   and the correct edit target are unchanged in substance.
6. Plain backticked reference — the draft rule text above references the companion file as
   `` `context/standards/source-store-deploy-boundary-narrative.md` ``, not an `@`-import.

## Decisions

- **Trim, do not re-baseline** — the dispatch's preferred remedy is achievable with substantial
  headroom (1,894 B), so the re-baselining fallback (which requires a written per-paragraph
  eager-necessity justification, a note-field bump, and an explicit headroom statement) is not
  triggered and should not be invoked.
- **Relocate `## Exceptions` and `## Enforcement` too, not just the 227-commit's growth** — although
  git history shows these two sections were not part of the regression, the dispatch's target
  eager size (~1,200 B, achieved here at 1,496 B) is reachable only by moving them as well, and the
  dispatch explicitly asks for headroom rather than a minimal revert. Keeping them lazy loses no
  information — they remain one hop away via the same plain backticked pointer pattern the two
  existing precedents use.
- **Preserve the HTML "why eager" comment verbatim** — it is exactly the kind of eager-necessity
  justification a re-baselining path would otherwise have to write from scratch, and it documents
  a real constraint (PostToolUse-only enforcement) that will matter to any future maintainer
  deciding whether to add a `paths:` gate to this rule.
- **New companion filename**: `source-store-deploy-boundary-narrative.md`, placed in
  `context/standards/` (matching `git-workflow-narrative.md`'s location and `-narrative.md` suffix
  convention) rather than `context/reference/` (the `state-management-schema.md` precedent, which
  uses a `-schema.md` suffix for a longer, more reference-table-like document). The source-store
  content is procedural/narrative in character (a numbered procedure, a fallback branch, a worked
  example, an enforcement narrative), matching the `standards/`+`narrative` precedent more closely
  than the `reference/`+`schema` one.

## Risks & Mitigations

- **Risk**: a future task grows `rules/git-workflow.md` (task 139, queued) or
  `rules/pr-prohibition.md`/`merge-sources/claudemd.md` (task 224, queued) enough to re-breach the
  budget even after this trim. **Mitigation**: this report's 1,894 B headroom is a deliberate
  buffer per the dispatch's "aim for headroom, not par" instruction; it does not guarantee immunity
  from unknown future growth amounts, but it is the maximum headroom achievable from this task's
  in-scope file without touching `## Path Pattern`/`## Principle` (which the dispatch does not
  authorize trimming) or the two named eager contributors outside this task's `file_scope`.
- **Risk**: relocating text could accidentally change meaning (acceptance criterion 5 prohibits
  this). **Mitigation**: the recommended lazy-file content above is an exact copy of the current
  rule's `## Correct Edit Target` procedure/fallback/example plus `## Exceptions`/`## Enforcement`
  — verified by diffing the draft against the live file content read in full during this research
  (no wording changed, only relocated and re-headed for the companion file's own top-level
  structure).
- **Risk**: a plain backticked reference could later be "upgraded" to an `@`-import by a
  well-meaning future edit, silently re-eagering the content and reopening this exact regression.
  **Mitigation**: acceptance criterion 6 already names this hazard explicitly; the implementer
  should keep the reference as prose (`See \`path\` for ...`), matching the two existing precedents
  exactly, neither of which uses `@`-import syntax for its companion.

## Context Extension Recommendations

- **Topic**: eager-context budget regression prevention at task-completion time.
- **Gap**: task 227 (the commit that caused this regression) completed without the budget gate
  (`measure-eager-context.sh --check` / `verify-deploy.sh` gate 20) being run, even though it
  edited a file the gate explicitly measures. There is no documented convention instructing an
  implementer to re-run the eager-budget check specifically when a `rules/*.md` file (or any file
  in the `claudemd`/`parent_chain`/`at_import` channels) is touched, as distinct from the general
  "run verify-deploy.sh" guidance.
- **Recommendation**: not creating a task per this agent's Stage 4.5 instructions (context gaps
  are documented, not auto-tasked), but noting it here since it directly explains how this
  regression happened silently: a targeted reminder (e.g. in
  `context/standards/git-staging-scope.md` or wherever rule-file edits are guided) that any edit
  touching an eagerly-loaded file should re-run the eager-budget check before completion could
  close this recurrence path. Left for a maintainer or a future `/meta` task to decide.

## Appendix

- Search queries / commands used:
  - `python3 -c "...json.load(open('.claude-extensions.json'))..."` — resolved `core` `source_dir`.
  - `find specs/249_restore_eager_context_budget -maxdepth 3 -type f` — confirmed task dir state.
  - `wc -c` on `rules/source-store-deploy-boundary.md`, `rules/git-workflow.md`,
    `context/standards/git-workflow-narrative.md`, `rules/state-management.md`,
    `context/reference/state-management-schema.md` — precedent byte measurements.
  - `cat .claude/context/config/orchestrator-context-budget.json` — baseline/note field.
  - `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` — live TOTAL 67,003 B
    confirmation, full per-channel breakdown.
  - `grep -n "baseline_bytes\|TOTAL" scripts/verify-deploy.sh` — gate 20 comparison logic location.
  - `sed -n '1,250p' scripts/tests/test-verify-deploy-context-budget.sh` — read the fixture/case
    logic in full, confirming both currently-failing assertions trace to
    `current_eager > baseline_bytes`.
  - `git log --oneline --follow -- .../rules/source-store-deploy-boundary.md` and
    `git show fd9d0286f --stat` / `git show fd9d0286f~1:...` — growth attribution to a single
    commit and section.
  - `grep -rn "source-store-deploy-boundary" --include="*.md" -l .` — cross-reference sweep for
    files that might need updating (none do).
  - Drafted and byte-measured (`wc -c`) two candidate eager-rule trims and the full lazy-companion
    file content in the scratchpad before recommending the final versions above.
