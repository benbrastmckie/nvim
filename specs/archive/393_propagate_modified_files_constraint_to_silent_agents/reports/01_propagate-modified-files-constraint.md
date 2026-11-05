# Research Report: Task #393

**Task**: 393 - Propagate modified_files repo-relative-paths constraint to silent agents
**Started**: 2026-10-16
**Completed**: 2026-10-16
**Effort**: medium (10 agent files, mechanical once the pattern is fixed)
**Dependencies**: None (task 304's V9 containment gate in `git-commit-scoped.sh` is already landed
and independent of this propagation)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/*/agents/*implementation-agent.md`,
  `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`,
  `agent-system/extensions/core/context/contracts/no-task-references-bullet.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Re-ran the dispatch's grep: **exactly 10 of 14** implementation agents still never mention
  `modified_files` — `books`, `cslib`, `pr-review` (cslib), `latex`, `lean`, `python`, `rust`,
  `typst`, `web`, `z3`. The list has not changed since the task was filed.
- **Additional discovery beyond the dispatch's literal grep**: the dispatch's glob
  (`*implementation-agent.md`) does not match the 3 hard-mode implementation agents
  (`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`,
  `books-implementation-hard-agent.md`), all of which also have zero mentions of
  `modified_files` — the identical bug, just outside the pattern named in the dispatch. The
  existing lint's `IN_SCOPE_RELATIVE_PATHS` arrays for other bullets (Checks C/G/H) already treat
  all 3 as in-scope implementation agents, which supports folding them in. See Finding 1's "Scope
  note" and Recommendation 7.
- This repo already has a proven, in-use mechanism for exactly this kind of propagation:
  `lint-agent-contracts.sh` Checks C/G/H verify that a **literal copy** of a canonical bullet
  (sourced from a single fragment file such as `context/contracts/no-task-references-bullet.md`)
  appears in every in-scope agent body — because `@`-references inside an agent body do **not**
  auto-resolve when Claude Code spawns a subagent (proven empirically per
  `no-task-references-bullet.md`'s own "Generated-Copy Source, Not an `@`-Import" section). The
  fix for this task should follow that exact shape, not ad hoc per-file wording.
- None of the 10 silent agents maintain a progress file / `files_touched` accumulator (confirmed
  by grep) — they are structurally closer to `email-implementation-agent.md` (no progress file,
  flat run-list, no sum step) than to `general-implementation-agent.md`/`nix`/`neovim` (progress
  file, per-objective accumulation, sum step).
- `modified_files` is **not** a record of every artifact an implementation agent writes — the
  task directory (`specs/{NNN}_{SLUG}/**`) is already unconditionally staged by the `implement`
  commit scope. `modified_files` exists specifically for repo source files touched **outside**
  the task directory (e.g. a `.lean`/`.py`/`.rs`/`.tex`/`.ts` file, or, for `pr-review`, a minor
  code change applied from the research report). Any recommendation that tells an agent to list
  its own summary/plan path in `modified_files` would be a misreading of the contract.
- No per-agent runtime test fixtures exist for "does agent X emit a well-formed `modified_files`
  field" (these are LLM prompt files, not scripts) — the only existing automated verification
  surface is the static `lint-agent-contracts.sh` + `test-lint-agent-contracts.sh` fixture suite,
  which has no check for this field today and is the natural place to add one.

## Context & Scope

Task 393 (type `meta`) asks to add the `modified_files` repo-relative-paths constraint —
documented canonically in `context/formats/return-metadata-file.md`'s `### modified_files
(optional)` section (Path form / Granularity / Empty behavior / Provenance subsections) — to the
Critical Requirements / contract sections of every implementation agent that currently never
mentions the field, and to verify each agent still emits a well-formed field afterward. This
report scopes the implementation: which 10 files are in scope, what each currently lacks, what
mechanism to reuse to add it with minimal drift risk, and how to verify the change without an
agent-execution test harness.

Root cause (per the dispatch): task 304's incident (an absolute out-of-repository path in
`modified_files` aborting a whole scoped commit) was possible because the producing agent was
never shown the constraint — `git-commit-scoped.sh`'s V9 drop-and-warn containment gate (landed
in task 304) makes a violation non-destructive now, but does not stop violations from being
produced in the first place. This task closes that gap at the source: the agent prompts
themselves.

## Findings

### Codebase Patterns

**1. The 10-agent list, re-derived and confirmed:**

```
agent-system/extensions/books/agents/books-implementation-agent.md
agent-system/extensions/cslib/agents/cslib-implementation-agent.md
agent-system/extensions/cslib/agents/pr-review-implementation-agent.md
agent-system/extensions/latex/agents/latex-implementation-agent.md
agent-system/extensions/lean/agents/lean-implementation-agent.md
agent-system/extensions/python/agents/python-implementation-agent.md
agent-system/extensions/rust/agents/rust-implementation-agent.md
agent-system/extensions/typst/agents/typst-implementation-agent.md
agent-system/extensions/web/agents/web-implementation-agent.md
agent-system/extensions/z3/agents/z3-implementation-agent.md
```

(`grep -L 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md`, run fresh
2026-10-16 — unchanged from the dispatch's 2026-10-12 count.) The 4 already-compliant agents are
`core/general-implementation-agent.md`, `email/email-implementation-agent.md`,
`nix/nix-implementation-agent.md`, `nvim/neovim-implementation-agent.md`. Treat the 10 above as
authoritative for this task's literal scope; do not re-add or drop entries without re-running the
grep.

**Scope note — a real gap the dispatch's exact grep pattern does not reach.** The glob
`*implementation-agent.md` does not match filenames ending `-hard-agent.md` (it requires the
literal suffix `implementation-agent.md`, not just `agent.md`), so the three hard-mode
implementation agents —
`agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`,
`agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`, and
`agent-system/extensions/books/agents/books-implementation-hard-agent.md` — were never counted by
the dispatch's grep at all. Checked directly: all three have **zero** mentions of
`modified_files`, the identical bug this task exists to fix. This is a genuine instance of the
same root cause, just outside the literal pattern the dispatch named. Flagged here rather than
silently folded in or silently dropped — see Recommendation 7 below for the scope call this
leaves for the plan.

**2. All 10 are structurally similar and small-to-medium** (`z3`/`rust`/`python`/`latex`: ~230-255
lines; `books`/`typst`: ~300; `lean`: ~780; `cslib`: ~735; `web`: ~1009;
`pr-review`: ~464). Each has a consistent `Stage 6: Create Implementation Summary` ->
`Stage 7: Write Metadata File` -> `## Critical Requirements` (MUST DO / MUST NOT) shape. None of
the 10 reference `progress-file.md`'s `files_touched` field or maintain a per-objective
accumulator — confirmed by grep across all 10 (`progress.file|files_touched|progress-file.md`
returns zero hits on 8 of them; `cslib` and `lean` have incidental "progress file" prose unrelated
to `files_touched` tracking). This means the correct template to mirror is
**`email-implementation-agent.md`'s** no-progress-file shape (direct flat list, no sum step), not
`general-implementation-agent.md`/`nix`/`neovim`'s progress-file-accumulation shape.

**3. `pr-review-implementation-agent.md` is a genuine edge case worth flagging explicitly**: its
primary output (`pr-response.md`/`zulip-response.md`) lives under `specs/**` and needs no
`modified_files` entry (task-directory auto-staging already covers it), but its own description
says it "applies minor actionable code changes from the research report (if any)" — i.e. it *can*
touch real repo source files outside `specs/**`, which is exactly the case `modified_files` exists
for. It belongs in scope, with wording that makes clear the field is `[]` on the common
response-only run and populated only when a minor code change was actually applied.

**4. The exact reusable propagation mechanism already exists in this repo** —
`lint-agent-contracts.sh` (`agent-system/extensions/core/scripts/lint/`):
- Checks **C** (no-task-references bullet), **G** (plan-status-ownership bullet), and **H**
  (bounded-wait contract bullet) each: (a) read a canonical fragment file under
  `context/contracts/` or `context/patterns/`, (b) extract the exact expected text, (c) grep every
  in-scope agent file (an explicit, curated `IN_SCOPE_RELATIVE_PATHS` array — deliberately *not*
  mechanically derived, since "does this agent need the bullet" is a judgment call) for that exact
  text, (d) FAIL any in-scope file missing it.
- `test-lint-agent-contracts.sh` is a fixture-driven regression suite that builds a scratch repo
  tree and exercises the real lint script against positive/negative fixtures per check.
- `no-task-references-bullet.md` documents *why* this is the right shape: agent bodies are **not**
  `@`-import-resolved at subagent-spawn time (proven empirically, cited to
  `specs/989_agent_contract_normalization/reports/01_...md`), so the fix must be a **literal copy**
  in every agent body, kept in sync by the lint rather than by a shared `@`-import.
- The next available check letter is **L** — `A, B, C, E, F, G, H, I, J, K` are implemented; `D`
  is explicitly reserved/deferred (comment at line ~1020) for a different, unrelated lint
  (required-body-sections drift). `L` does not collide with `D`'s reservation.

**5. `modified_files`'s scope boundary, confirmed from `git-staging-scope.md`'s `implement`
section**: the `implement` commit stages the task directory (plan scope) **plus** `plan_path`
**plus** every entry of `modified_files`. The task directory — including every summary, plan, and
handoff the agent writes — is staged unconditionally regardless of `modified_files`. The field's
entire reason to exist is files *outside* that directory. This matters for how the propagated
wording should read: it must not imply the agent should list its own `specs/**` artifacts.

### External Resources

No external research was needed — this is a closed, in-repo propagation task with an existing
in-repo precedent mechanism.

## Decisions

- **In-scope set for this change**: exactly the 10 agents listed above, including
  `pr-review-implementation-agent.md` (edge case, included per Finding 3).
- **Template to mirror**: `email-implementation-agent.md`'s no-progress-file `modified_files`
  wording (flat list, no sum step), adapted per-agent — not `general-implementation-agent.md`'s
  progress-file-accumulation wording, since none of the 10 maintain a progress file.
- **Mechanism**: reuse the `lint-agent-contracts.sh` canonical-fragment pattern. Create one new
  fragment file (e.g. `context/contracts/modified-files-bullet.md`, mirroring
  `no-task-references-bullet.md`'s structure: Generated-Copy-Source-Not-an-@-Import section, the
  exact bullet text, a classification rule, placement instructions) and one new check,
  `check_l_modified_files_bullet`, added to `lint-agent-contracts.sh` and wired into the main
  invocation list alongside Checks A/B/C/E/F/G/H/I/J/K, with matching positive/negative fixtures
  added to `test-lint-agent-contracts.sh`.
- **Verification approach**: since these are prompt files with no agent-execution test harness,
  the static lint (extended with Check L) is the primary, repeatable verification. A manual dry
  run (actually dispatching one or two of the 10 agents end-to-end and inspecting their emitted
  `.return-meta.json`) is a reasonable spot-check but not required for all 10, and should not be
  treated as the primary gate — the dispatch's "its own test fixtures if any exist, or a manual
  dry run" instruction is satisfied by the lint-fixture route, which is strictly more repeatable.

## Recommendations

1. **Create `context/contracts/modified-files-bullet.md`** carrying: the literal MUST-DO bullet
   text to insert into each agent's Critical Requirements (paraphrasing
   `return-metadata-file.md`'s Path form / Granularity / Empty behavior facts: repo-relative,
   individual-file-path, never-omit-the-field-use-`[]`-when-empty), a short Stage-6/7 snippet
   agents without a progress file should follow (track on `Write`/`Edit` -> flat list -> emit as
   `modified_files` at Stage 7, no sum step — mirroring `email-implementation-agent.md`'s already
   -landed wording), and the classification rule (all 10 named agents are in scope; `pr-review`
   is in scope because it *can* touch non-`specs/**` files even though its common-case run does
   not).
2. **Propagate the literal bullet + Stage 6/7 wiring into each of the 10 agent files**, inserting:
   - a tracking instruction near each agent's existing Stage-4-equivalent "apply the change"
     step (where `Write`/`Edit` happens),
   - the `"modified_files": [...]` key in each agent's Stage 7 JSON example (currently absent from
     all 10 — e.g. `z3-implementation-agent.md`'s Stage 7 example shows only `status`/`artifacts`),
   - a new numbered MUST-DO bullet in each agent's `## Critical Requirements` list.
3. **Add `check_l_modified_files_bullet` to `lint-agent-contracts.sh`**, modeled directly on
   `check_c_no_task_references_bullet`, with its own `IN_SCOPE_RELATIVE_PATHS`-equivalent array
   containing at minimum the 10 target agents (the 4 already-compliant agents may also be added
   for regression coverage, since they already carry equivalent wording in their own voice — this
   is a judgment call for the plan to make explicit, since their wording is pointer-style rather
   than bullet-style and may not match a single literal string without adapting the check or the
   fragment to tolerate both forms).
4. **Add positive and negative fixtures to `test-lint-agent-contracts.sh`** for Check L, following
   the existing fixture pattern used for Checks C/G/H (a `compliant-agent.md`-style fixture that
   carries the bullet, and a negative fixture that omits it).
5. **Verify** via: (a) running the extended `test-lint-agent-contracts.sh` (expect all-pass), (b)
   running `lint-agent-contracts.sh` itself against the real repo tree post-edit (expect Check L to
   pass for all 10+ in-scope files), and (c) optionally one manual dry run — dispatch a trivial
   task through one of the 10 agents (e.g. `z3` or `rust`, the smallest files) and inspect the
   resulting `.return-meta.json` for a well-formed `modified_files` key.
6. The 4 already-compliant agents (`general`, `email`, `nix`, `neovim`) need no change.
7. **Scope call for the plan**: fold the 3 hard-mode agents (`cslib-implementation-hard-agent.md`,
   `lean-implementation-hard-agent.md`, `books-implementation-hard-agent.md`) into this task's
   edit set alongside the 10, since they carry the identical bug and the lint's own
   `IN_SCOPE_RELATIVE_PATHS` arrays already treat them as implementation agents for other bullets
   (Checks C/G/H). This widens the dispatch's literal 10-file grep to 13 files; flagged here as a
   recommendation rather than decided unilaterally, since the dispatch's own SCOPE line named only
   the 10. If folded in, Check L's in-scope array should include all 13 (plus, optionally, the 4
   already-compliant agents for regression coverage per Recommendation 3).

## Context Extension Recommendations

- **Topic**: the canonical-fragment-plus-lint-check propagation pattern (Checks C/G/H plus their
  fragment files) is used at least four times in this codebase but has no single guide
  documenting the general recipe for "how to add a new one."
- **Gap**: a future task needing to propagate a new MUST-DO/MUST-NOT bullet across a curated agent
  set has to reverse-engineer the pattern from reading `no-task-references-bullet.md` plus
  `lint-agent-contracts.sh`'s Check C implementation, as this report did.
- **Recommendation**: not required for this task, but a worthwhile follow-up —
  `context/guides/canonical-fragment-propagation-pattern.md` abstracting the fragment-file shape,
  the `IN_SCOPE_RELATIVE_PATHS` curation convention, the check-letter reservation convention (next
  available letter, `D` reserved/skipped), and the fixture-pair convention in
  `test-lint-agent-contracts.sh`.

## Appendix

Search queries / commands used:
- `grep -L 'modified_files' agent-system/extensions/*/agents/*implementation-agent.md` (re-derived
  the 10-agent list; matches dispatch's 2026-10-12 derivation exactly)
- `ls agent-system/extensions/*/agents/*implementation-agent.md` (confirmed 14 total matches)
- `grep -n -B3 -A25 'modified_files' agent-system/extensions/core/agents/general-implementation-agent.md`
- `grep -rn 'Path form\|Granularity\|Empty behavior' agent-system/extensions/` (located the
  canonical subsections in `context/formats/return-metadata-file.md`)
- `grep -n -B2 -A12 'modified_files' <nix|email|neovim>-implementation-agent.md` (compared the
  3 already-compliant non-general agents' wording)
- `grep -rn 'progress.file|files_touched|progress-file.md' <10 silent agents>` (confirmed none
  maintain a progress-file accumulator)
- `grep -rl 'modified_files' --include='test*' agent-system/extensions/*/scripts/tests/` and
  `find ... -iname '*implementation*'` under `scripts/tests` (confirmed no per-agent runtime test
  fixtures exist)
- Read `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (Checks A-K, letter
  reservation for D, Check C's full implementation) and
  `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` (the
  generated-copy-not-@-import precedent)
- Read `agent-system/extensions/core/context/standards/git-staging-scope.md`'s `implement` section
  (confirmed `modified_files`'s scope boundary relative to task-directory auto-staging)

References:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (`### modified_files
  (optional)` section, lines ~430-489)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` (`### implement` section,
  lines ~132-189)
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` (Checks C/G/H, lines
  ~297-369, 574-639, 640-710)
- `agent-system/extensions/core/context/contracts/no-task-references-bullet.md` (full file)
- `agent-system/extensions/email/agents/email-implementation-agent.md` (lines ~176-186, the
  no-progress-file `modified_files` template to mirror)
