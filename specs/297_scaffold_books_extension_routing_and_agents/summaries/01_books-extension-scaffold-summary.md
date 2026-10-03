# Implementation Summary: Task #297

- **Task**: 297 - Scaffold the books extension: manifest, routing, agents, skills, commands, rule and tests
- **Status**: [COMPLETED]
- **Started**: 2026-10-03
- **Completed**: 2026-10-03
- **Effort**: ~4 hours (plan estimated 10.5)
- **Dependencies**: None
- **Artifacts**: plans/01_books-extension-wiring.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  extension-slim-standard.md, agent-frontmatter-standard.md

## Overview

Built the complete `books` extension in the agent-system source store at
`agent-system/extensions/books/`, providing the `books` task type (plus a `books:certify`
compound sub-route) for authoring, certifying and documenting lean books per the
Logos/Verification repository's `docs/book-convention.md` design record. All eight plan phases
completed: manifest with two-block routing and narrow keyword overrides, four sonnet agents
(base + `--hard` pair), six skills, two commands (`/book`, `/certify`), a flattened-layout
`books` rule, one declared passthrough script with a 9-case fixture suite, and the four
registration/documentation files. The domain context corpus under `context/project/books/`
ships only as a navigation stub, per the dispatch's explicit non-goal (a separate dependent
task owns the full corpus).

## What Changed

- `agent-system/extensions/books/manifest.json` — new: `task_type: "books"`,
  `dependencies: ["core", "lean", "typst"]`, `provides` for all six categories, two routing
  blocks only (`routing_agents`, `routing_agents_hard` — no `routing`/`routing_hard`), 14
  narrow multi-word `keyword_overrides` tokens with no alias remap, three `merge_targets`
  (claudemd, index, opencode_json).
- `agent-system/extensions/books/agents/books-research-agent.md` — new: base research agent,
  `model: sonnet`.
- `agent-system/extensions/books/agents/books-implementation-agent.md` — new: base
  implementation agent, `model: sonnet`.
- `agent-system/extensions/books/agents/books-research-hard-agent.md` — new: H2/H3/H4 hard
  variant (cslib's H-set, not lean4's), `model: sonnet`.
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` — new: H2/H7/H9
  hard variant, `model: sonnet`.
- `agent-system/extensions/books/skills/skill-books-research/SKILL.md` — new.
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` — new; states
  explicitly that it also serves `books:certify` (no dedicated lifecycle skill for that
  sub-route, per Decision 3).
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` — new.
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` — new.
- `agent-system/extensions/books/rules/books.md` — new: six non-negotiables (facts-in-Lean/
  judgments-in-TOML, the `book.cert.json`-is-the-only-input boundary, the **flattened**
  book-directory layout, explicit per-module lakefile globs with the measured
  `bad import 'Books.Meta'` failure cited, the licence-header-then-`module` line order, and
  never-hand-edit-a-generated-artifact/never-author-a-computed-field).
- `agent-system/extensions/books/scripts/books-certify.sh` — new: resolve-and-passthrough
  wrapper around the consuming repository's `books/scripts/certify.sh`; forwards every flag
  except the acceptance-suite-only `--graph-from`, which it refuses with exit 2.
- `agent-system/extensions/books/scripts/tests/test-books-certify.sh` — new: 9 PASS, 0 FAIL
  across 3 fixture cases (driver present and args forwarded in order; driver absent with a
  loud, actionable exit-3 failure; `--graph-from` refused rather than forwarded).
- `agent-system/extensions/books/commands/book.md` — new: single-book developer loop
  (resolve → build → validate → environment-check), with an explicit out-of-scope statement
  for documentation reconciliation.
- `agent-system/extensions/books/commands/certify.md` — new: thin passthrough over
  `books-certify.sh`, options table limited to the real, re-verified flag set.
- `agent-system/extensions/books/skills/skill-books-build/SKILL.md`,
  `skills/skill-books-certify/SKILL.md` — new: direct-execution skills paired with the two
  commands.
- `agent-system/extensions/books/EXTENSION.md` — new, 52 lines (≤60 limit).
- `agent-system/extensions/books/README.md` — new, written after `manifest.json` so its mtime
  is newer; mentions both `/book` and `/certify`.
- `agent-system/extensions/books/index-entries.json` — new: one entry for
  `project/books/README.md`, `line_count: 19` (verified against `wc -l`), no forbidden keys.
- `agent-system/extensions/books/opencode-agents.json` — new: four agent entries (base pair +
  hard pair), each `prompt` pointing at the matching `agents/books-*-agent.md` file.
- `agent-system/extensions/books/context/project/books/README.md` — new: navigation stub only,
  per the dispatch's explicit non-goal for the domain corpus.

## Decisions

- Followed the plan's Research Integration section verbatim (Decisions 1-6 treated as fixed,
  not re-litigated): narrow 14-token `keyword_overrides` with no alias remap; `/reconcile` and
  its lifecycle/write-guard pieces NOT built here (spawned, not absorbed); `books:certify`
  routed but `books:document` deliberately omitted; all four agents `model: sonnet` with
  cslib's H-set (H2/H3/H4 research, H2/H7/H9 implementation); two commands
  (`/book` + `/certify`), each paired with a direct-execution skill; the **flattened**
  book-directory layout (confirmed live against the Logos/Verification repository — the
  `docs/`-nested examples found on disk are explicitly documented legacy/held books, not the
  current convention).
- Re-verified the landed/unlanded boundary directly against `~/Projects/Logos/Verification`
  before writing any command or rule text: `books-tool` exposes exactly `validate`/`check`/
  `levels`/`--help` (no `approve-guarantees`/`book-health` subcommands); `certify.sh`'s real
  flag set is `--no-build`, `--check`, `--no-shake`, `--no-write`, `--only NAME`,
  `--graph-from FILE` (acceptance-suite-only, deliberately not exposed), `-h`/`--help`;
  `books/tool/approve-guarantees.sh` and `books/tool/book-health.sh` do not exist on disk.
- Rule E (`check_referenced_scripts_declared`) required rewriting every bare `certify.sh`,
  `approve-guarantees.sh` and `book-health.sh` token across the four agent files into prose
  ("the certify driver under `books/scripts/`", "the approve-guarantees script", "the
  book-health script") — confirmed by direct `grep` against the regex the lint itself uses,
  not by inspection alone.

## Plan Deviations

- **Phase 8, Testing & Validation**: `shellcheck` could not be run — the binary in this
  environment's `$PATH` points at a nix store path (`shellcheck-0.11.0-bin`) that no longer
  exists. `bash -n` passed clean on both `scripts/books-certify.sh` and its test, and the
  9-case fixture suite exits 0. This is an environment limitation, not a finding against the
  script; recorded in `progress/phase-8-progress.json`.
- **Phase 8**: `check-extension-docs.sh` had to be invoked from the deployed `.claude/scripts/`
  tree rather than the source-store copy, which refuses to run outside a deployed tree by its
  own design (confirmed via its own error message). No plan-scope change, just the correct
  invocation path.
- No other deviations — implementation followed the plan phase-by-phase.

## Verification

- Build: N/A (no compiled artifact for a wiring-only extension).
- Tests: `bash agent-system/extensions/books/scripts/tests/test-books-certify.sh` — 9 passed,
  0 failed.
- `jq -e .` parses `manifest.json`, `index-entries.json`, `opencode-agents.json`: all three OK.
- `bash -n` clean on both shell files; `shellcheck` unavailable (see Plan Deviations).
- `check-extension-docs.sh` (deployed-tree invocation): `books PASS`. Two unrelated `[core]`
  FAILs observed (`scripts/command-gate-out.sh`, `scripts/skill-base.sh` deployed-content
  drift) — both files are in sibling task 327's declared `file_scope` for this same
  `/orchestrate` cycle; reported, not fixed, per the dispatch's explicit instruction not to
  touch core on this task's own authority.
- `validate-index.sh` / `validate-wiring.sh`: zero `books`-attributable findings in either
  (confirmed by `grep -i books` over each script's full output).
- `detect_task_type` 7-row table (3 positive book rows + 4 unchanged negatives) reproduced
  exactly against both the Phase 1 manifest and the finished Phase 8 manifest.
- `check-task-references.sh agent-system/extensions/books/`: 0 occurrences.
- `git status --short -- .claude/`: no `books`-related entries.
- Files verified: Yes — every file listed under "What Changed" exists on disk.

## Impacts

- A `books` task created with an unambiguous multi-word description (naming `book.toml`,
  `book_layer`, etc.) now routes correctly to the new extension instead of falling through to
  `general`.
- A `books` description naming a `.lean` file, or `mathlib`/`lean4`, is still captured by the
  `lean4` strong anchor ahead of any extension's keywords — this is the residual, structural
  gap recorded as added scope to spawn against core's `task-type-detect.sh`, not touched here.
- The extension is not yet installed in any consuming repository's `.claude-extensions.json`
  (the user's own follow-up action, explicitly out of this task's scope).

## Follow-ups

1. Spawn: amend core's `scripts/lib/task-type-detect.sh` strong-anchor step (or add a `books`
   strong anchor ahead of `lean4`'s) so a description naming a `.lean` file, `book.toml`,
   `book_layer` or `book.cert.json` is not captured unconditionally by the `lean4` anchor.
2. Spawn: move the already-scoped reconciliation work (a `/reconcile` command and skill, a
   lifecycle postflight docs-stage hook, a write guard, a `/review` Book-health section, and
   five fixtures) out of the typst/lean extensions and into `books`, once that work is next
   revised. Referred to here by title and deliverables only, never by task number.
3. Add a `books:document` routing sub-route and its docs-stage skill once the certifier's docs
   stage, the documentation queue JSON, and the guarantee-approval/book-health scripts land.
4. Author the `context/project/books/**` domain corpus (already a separate dependent task) and
   extend `index-entries.json` accordingly.
5. The user's own action: enable the extension in a consuming repository via its
   `.claude-extensions.json` loader picker.

## References

- `specs/297_scaffold_books_extension_routing_and_agents/plans/01_books-extension-wiring.md`
- `specs/297_scaffold_books_extension_routing_and_agents/reports/01_books-extension-scaffold-research.md`
- `specs/297_scaffold_books_extension_routing_and_agents/progress/phase-8-progress.json`
- `agent-system/extensions/typst/`, `agent-system/extensions/lean/`,
  `agent-system/extensions/cslib/` (structural precedents)
