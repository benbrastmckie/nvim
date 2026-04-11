# Implementation Plan: Add Routing Blocks to 11 Extension Manifests

- **Task**: 402 - Add routing blocks to 11 extension manifests (doc-lint failures)
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/402_add_routing_blocks_to_extension_manifests/reports/01_extension-manifest-routing.md
- **Artifacts**: plans/01_add-routing-blocks.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/plan-format-enforcement.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a canonical three-bucket `routing` block (`research`, `plan`, `implement`) to each of 11 extension manifest.json files that currently fail `.claude/scripts/check-extension-docs.sh`. The research report has pre-computed exact per-extension JSON, so each edit is mechanical: insert the `routing` object between `provides` and `merge_targets` and validate JSON syntax. Work is grouped into three parallelizable batches by extension shape (single-skill, multi-skill with sub-routing, and null-task-type), followed by a final verification phase that runs the doc-lint script.

### Research Integration

The research report (`reports/01_extension-manifest-routing.md`) identifies the exact 11 failing manifests, documents the canonical three-bucket schema from compliant references (`epidemiology`, `founder`, `present`), and provides ready-to-paste JSON for each extension. All decisions (D1-D6) from the report are adopted verbatim: use three-bucket schema, route `plan` to core `skill-planner`, use extension name for null task_types, exclude user-only `skill-tag` from `web`, route `formal` implement to `skill-implementer`, and add sub-routing keys only for multi-skill extensions.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task unblocks the ROADMAP item for enabling CI doc-lint enforcement (per `specs/reviews/review-2026-04-10.md` lines 22-43, 79-80). It does not advance other roadmap items directly.

## Goals & Non-Goals

**Goals**:
- Add a valid `routing` block to each of the 11 failing manifests (filetypes, formal, latex, lean, memory, nix, nvim, python, typst, web, z3).
- Place `routing` between `provides` and `merge_targets` to match compliant examples.
- Ensure `bash .claude/scripts/check-extension-docs.sh` exits 0 with `PASS: all extensions OK`.
- Ensure every added manifest remains valid JSON (`jq empty` passes).

**Non-Goals**:
- Enabling CI doc-lint enforcement (separate roadmap item).
- Resolving the pre-existing WARN messages for `memory` and `present` README drift.
- Refactoring or renaming any extension skills.
- Modifying `.claude/extensions/*/manifest.json` files that already pass doc-lint (epidemiology, founder, present, etc.).
- Changing the doc-lint script itself or its validation rules.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error after manual edit | H | M | Run `jq empty <file>` after every edit; fix immediately before moving on. |
| Typo in skill name causing silent routing fallthrough | M | L | Copy skill names directly from research report JSON (already cross-referenced against `provides.skills`); optionally run `validate-wiring.sh` if present. |
| `routing` placed in wrong position within manifest | L | L | Always insert between `provides` and `merge_targets`, matching compliant references. |
| doc-lint still fails after edits (missed manifest) | M | L | Final phase runs the script; any FAIL triggers a targeted fix. |
| Unrelated manifest changes creep in | L | L | Limit each edit to inserting the `routing` block only; no other reformatting. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Single-skill extensions with bare task_type [COMPLETED]

**Goal**: Add `routing` blocks to the 6 simplest extensions: `latex`, `nix`, `nvim`, `python`, `typst`, `z3`. Each declares a bare task_type and has exactly one research + one implementation skill, so each routing block has three single-key buckets.

**Tasks**:
- [ ] Edit `.claude/extensions/latex/manifest.json` - insert `routing` block keyed by `latex` (research -> `skill-latex-research`, plan -> `skill-planner`, implement -> `skill-latex-implementation`).
- [ ] Edit `.claude/extensions/nix/manifest.json` - insert `routing` block keyed by `nix` (research -> `skill-nix-research`, plan -> `skill-planner`, implement -> `skill-nix-implementation`).
- [ ] Edit `.claude/extensions/nvim/manifest.json` - insert `routing` block keyed by `neovim` (research -> `skill-neovim-research`, plan -> `skill-planner`, implement -> `skill-neovim-implementation`).
- [ ] Edit `.claude/extensions/python/manifest.json` - insert `routing` block keyed by `python` (research -> `skill-python-research`, plan -> `skill-planner`, implement -> `skill-python-implementation`).
- [ ] Edit `.claude/extensions/typst/manifest.json` - insert `routing` block keyed by `typst` (research -> `skill-typst-research`, plan -> `skill-planner`, implement -> `skill-typst-implementation`).
- [ ] Edit `.claude/extensions/z3/manifest.json` - insert `routing` block keyed by `z3` (research -> `skill-z3-research`, plan -> `skill-planner`, implement -> `skill-z3-implementation`).
- [ ] Edit `.claude/extensions/web/manifest.json` - insert `routing` block keyed by `web` (research -> `skill-web-research`, plan -> `skill-planner`, implement -> `skill-web-implementation`); intentionally omit `skill-tag` (user-only).
- [ ] Run `jq empty` on each edited manifest to validate JSON.

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/latex/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/nix/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/nvim/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/python/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/typst/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/z3/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/web/manifest.json` - add `routing` block after `provides`

**Verification**:
- `jq empty .claude/extensions/{latex,nix,nvim,python,typst,z3,web}/manifest.json` returns 0 for all.
- `jq 'has("routing")' <each>` returns `true`.
- Per-manifest: `jq '.routing | keys' <file>` returns `["implement","plan","research"]`.

---

### Phase 2: Multi-skill extensions with sub-routing [COMPLETED]

**Goal**: Add `routing` blocks to the 2 multi-skill extensions with sub-routing keys: `formal` (4 research skills, implement falls back to `skill-implementer`) and `lean` (sub-routing for `lake` and `version` specialists).

**Tasks**:
- [ ] Edit `.claude/extensions/formal/manifest.json` - insert `routing` block with bare `formal` key and compound keys `formal:logic`, `formal:math`, `formal:physics` in research bucket; plan routes all to `skill-planner`; implement routes all to `skill-implementer` (per D5).
- [ ] Edit `.claude/extensions/lean/manifest.json` - insert `routing` block with bare `lean4` key plus compound `lean4:lake` and `lean4:version`; research routes lake/version to `skill-lake-repair` and `skill-lean-version`; implement routes those sub-keys to the same specialist skills and bare `lean4` to `skill-lean-implementation`.
- [ ] Run `jq empty` on each edited manifest.

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/formal/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/lean/manifest.json` - add `routing` block after `provides`

**Verification**:
- `jq empty` passes on both files.
- `jq '.routing.research | keys' .claude/extensions/formal/manifest.json` returns `["formal","formal:logic","formal:math","formal:physics"]`.
- `jq '.routing.research | keys' .claude/extensions/lean/manifest.json` returns `["lean4","lean4:lake","lean4:version"]`.
- All compound keys match the per-extension JSON in the research report.

---

### Phase 3: Null task_type extensions [COMPLETED]

**Goal**: Add `routing` blocks to the 2 extensions with `task_type: null` (`filetypes`, `memory`) using the extension name as the bare routing key (per D3).

**Tasks**:
- [ ] Edit `.claude/extensions/filetypes/manifest.json` - insert `routing` block keyed by `filetypes` plus compound keys `filetypes:document`, `filetypes:spreadsheet`, `filetypes:presentation`, `filetypes:scrape`, `filetypes:docx`; research and implement buckets route to the five filetype skills per the research report; plan bucket routes all keys to `skill-planner`.
- [ ] Edit `.claude/extensions/memory/manifest.json` - insert minimal `routing` block keyed by `memory` (research -> `skill-memory`, plan -> `skill-planner`, implement -> `skill-memory`).
- [ ] Run `jq empty` on each edited manifest.

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/filetypes/manifest.json` - add `routing` block after `provides`
- `.claude/extensions/memory/manifest.json` - add `routing` block after `provides`

**Verification**:
- `jq empty` passes on both files.
- `jq '.routing.research | keys | length' .claude/extensions/filetypes/manifest.json` returns 6 (one bare + five compound).
- `jq '.routing.research.memory' .claude/extensions/memory/manifest.json` returns `"skill-memory"`.

---

### Phase 4: Verification and doc-lint pass [COMPLETED]

**Goal**: Confirm all 11 manifests now satisfy `check-extension-docs.sh` and that no unrelated manifests were affected.

**Tasks**:
- [ ] Run `bash .claude/scripts/check-extension-docs.sh` and capture full output.
- [ ] Confirm exit code is 0 and output contains `PASS: all extensions OK` (pre-existing mtime WARN messages for `memory` and `present` READMEs are acceptable per research report).
- [ ] If any FAIL remains, identify the offending manifest, fix the `routing` block, and re-run.
- [ ] Run `bash .claude/scripts/validate-wiring.sh` if it exists, to confirm routing entries reference real skill directories.
- [ ] Run `jq empty .claude/extensions/*/manifest.json` across all extension manifests to confirm no regressions in sibling files.
- [ ] Spot-check one edited manifest (e.g. `latex`) and compare shape against `epidemiology/manifest.json` to confirm structural parity.

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only); may re-edit any failing manifest from phases 1-3 if issues found.

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh; echo $?` prints `0`.
- Output contains `PASS: all extensions OK`.
- No new FAIL messages beyond the pre-existing mtime WARNings (out of scope).
- `jq empty .claude/extensions/*/manifest.json` exits 0 across the board.

---

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 with `PASS: all extensions OK`.
- [ ] `jq empty .claude/extensions/*/manifest.json` exits 0 for every extension.
- [ ] For each of the 11 target manifests, `jq '.routing | keys | sort' <file>` returns `["implement","plan","research"]`.
- [ ] For each target manifest, `jq '.routing.plan | to_entries | all(.value == "skill-planner")' <file>` returns `true` (except `formal` which uses `skill-implementer` for implement; plan still routes to `skill-planner`).
- [ ] Manifest JSON field order has `routing` between `provides` and `merge_targets` (visual inspection or `jq 'keys_unsorted'`).
- [ ] `validate-wiring.sh` passes if present.

## Artifacts & Outputs

- 11 modified files: `.claude/extensions/{filetypes,formal,latex,lean,memory,nix,nvim,python,typst,web,z3}/manifest.json` each with a new top-level `routing` object.
- Implementation summary: `specs/402_add_routing_blocks_to_extension_manifests/summaries/01_add-routing-blocks-summary.md` (created by /implement postflight).
- Green `check-extension-docs.sh` run captured in the summary.

## Rollback/Contingency

Each manifest edit is independent and additive (inserts a new top-level key without touching existing ones). If any edit produces invalid JSON or breaks extension loading:

1. Revert the individual file with `git checkout -- .claude/extensions/<name>/manifest.json`.
2. Re-apply the routing block using the exact JSON from the research report, being careful with comma placement after the preceding `provides` block.
3. If multiple manifests are broken, revert the whole task with `git checkout -- .claude/extensions/` (scoped to extension manifests only).
4. If `check-extension-docs.sh` introduces new unexpected FAIL messages unrelated to the routing change, inspect the diff and narrow the fix; do not modify the doc-lint script.

Since no other files are touched, rollback has no cross-cutting impact on the agent system.
