# Research Report: Task 402

- **Task**: 402 - Add routing blocks to 11 extension manifests (doc-lint failures)
- **Started**: 2026-04-10T00:00:00Z
- **Completed**: 2026-04-10T00:00:00Z
- **Effort**: Small (mechanical JSON edits across 11 files)
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/scripts/check-extension-docs.sh` (doc-lint execution)
  - `.claude/extensions/epidemiology/manifest.json` (compliant reference)
  - `.claude/extensions/founder/manifest.json` (compliant reference)
  - `.claude/extensions/present/manifest.json` (compliant reference)
  - `.claude/extensions/filetypes/EXTENSION.md` (for skill purpose mapping)
  - `.claude/CLAUDE.md` (extension routing documentation)
  - `.claude/docs/reference/standards/extension-slim-standard.md`
  - `.claude/docs/guides/adding-domains.md`
  - `specs/reviews/review-2026-04-10.md` (issue source)
- **Artifacts**:
  - `specs/402_add_routing_blocks_to_extension_manifests/reports/01_extension-manifest-routing.md`
- **Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- Exactly 11 extension manifests fail `check-extension-docs.sh` because they declare non-empty `provides.skills` but lack a top-level `routing` key.
- The doc-lint check is structural only: `jq 'has("routing")'` at the top level. Any object keyed `routing` will pass.
- Compliant manifests (`epidemiology`, `founder`, `present`) use a three-bucket schema: `routing.research`, `routing.plan`, `routing.implement`, each mapping task-type keys (bare `task_type` and `task_type:sub` forms) to skill names.
- All failing extensions already declare a `task_type` string (except `filetypes` and `memory`, which are `null` and need a synthetic task-type key).
- Recommended plan syncs routing with the pattern used by `present/` (research -> domain research skill, plan -> `skill-planner` or a domain planner, implement -> domain implementation skill).
- This task unblocks a roadmap item to enable CI doc-lint enforcement (per review recommendations).

## Context & Scope

**What is being evaluated**: The 11 extension manifest.json files flagged by `.claude/scripts/check-extension-docs.sh` as missing a `routing` block. This is a meta task that modifies `.claude/extensions/*/manifest.json` files.

**Constraint**: The doc-lint check (lines 109-123 of `check-extension-docs.sh`) performs only a shallow presence check:

```bash
has_routing=$(jq -r 'has("routing")' "$manifest")
if [[ "$has_routing" == "false" ]]; then
  fail "manifest declares $skill_count skill(s) but has no routing block"
fi
```

So any valid `routing` object passes doc-lint. However, the review's recommendation (and the convention from compliant manifests) is that the routing block be semantically correct so that extension load-time routing actually dispatches to the declared skills.

**Source of the issue**: `specs/reviews/review-2026-04-10.md` section "Extension manifest routing blocks missing" (lines 24-43), which classifies this as a High Priority issue and notes it blocks the CI doc-lint roadmap item.

## Findings

### Canonical Routing Block Schema

Extracted from `.claude/extensions/epidemiology/manifest.json` (a minimal, fully compliant reference):

```json
"routing": {
  "research": {
    "epi": "skill-epi-research",
    "epi:study": "skill-epi-research",
    "epidemiology": "skill-epi-research"
  },
  "plan": {
    "epi": "skill-planner",
    "epi:study": "skill-planner",
    "epidemiology": "skill-planner"
  },
  "implement": {
    "epi": "skill-epi-implement",
    "epi:study": "skill-epi-implement",
    "epidemiology": "skill-epi-implement"
  }
}
```

Key conventions observed across `epidemiology/`, `founder/`, and `present/`:

1. Three top-level buckets: `research`, `plan`, `implement` (matching the `/research`, `/plan`, `/implement` commands).
2. Each bucket is an object keyed by task-type string, valued by skill name.
3. Bare `task_type` (e.g. `"epi"`) maps to the default skill for that bucket.
4. Sub-routing keys use compound `task_type:sub` form (e.g. `"epi:study"`, `"founder:market"`, `"present:grant"`), as described in `.claude/CLAUDE.md` ("Extension task types use bare values ... or compound values ... for sub-routing").
5. The `plan` bucket may route to `skill-planner` (the core planning skill) if the extension does not provide its own planner skill (e.g. `epidemiology`, `present`), or to a dedicated planner (e.g. `founder` -> `skill-founder-plan`).
6. `research` and `implement` buckets typically map to extension-provided skills, not core fallbacks.

### doc-lint Check Behavior

From `.claude/scripts/check-extension-docs.sh` lines 109-123:

- Triggered only when `provides.skills | length > 0`.
- Passes when `jq 'has("routing")'` returns `true` at the top level.
- Does not validate bucket structure, key coverage, or skill-name resolution.
- Failures appear in the script's summary table as `FAIL` with message: `manifest declares N skill(s) but has no routing block`.

### The 11 Failing Manifests

Verified by running the script on 2026-04-10. Path format: `.claude/extensions/{name}/manifest.json`.

| # | Extension | task_type | Skills (count) | Skills |
|---|-----------|-----------|----------------|--------|
| 1 | filetypes | `null` | 5 | skill-filetypes, skill-spreadsheet, skill-presentation, skill-scrape, skill-docx-edit |
| 2 | formal | `formal` | 4 | skill-formal-research, skill-logic-research, skill-math-research, skill-physics-research |
| 3 | latex | `latex` | 2 | skill-latex-implementation, skill-latex-research |
| 4 | lean | `lean4` | 4 | skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version |
| 5 | memory | `null` | 1 | skill-memory |
| 6 | nix | `nix` | 2 | skill-nix-research, skill-nix-implementation |
| 7 | nvim | `neovim` | 2 | skill-neovim-research, skill-neovim-implementation |
| 8 | python | `python` | 2 | skill-python-research, skill-python-implementation |
| 9 | typst | `typst` | 2 | skill-typst-research, skill-typst-implementation |
| 10 | web | `web` | 3 | skill-web-implementation, skill-web-research, skill-tag |
| 11 | z3 | `z3` | 2 | skill-z3-research, skill-z3-implementation |

Exact paths:

- `.claude/extensions/filetypes/manifest.json`
- `.claude/extensions/formal/manifest.json`
- `.claude/extensions/latex/manifest.json`
- `.claude/extensions/lean/manifest.json`
- `.claude/extensions/memory/manifest.json`
- `.claude/extensions/nix/manifest.json`
- `.claude/extensions/nvim/manifest.json`
- `.claude/extensions/python/manifest.json`
- `.claude/extensions/typst/manifest.json`
- `.claude/extensions/web/manifest.json`
- `.claude/extensions/z3/manifest.json`

### Per-Extension Recommended Routing Entries

Each entry below proposes the `routing` object to add. Task-type keys follow the bare + compound pattern. Where an extension does not provide a dedicated planner skill, `plan` routes to the core `skill-planner`. Where the extension's `task_type` is `null`, the extension name is used as the routing key (matching how users would specify `--task-type`).

#### filetypes

task_type: `null` (use extension name `filetypes` as routing key). Multi-skill domain with sub-routing by file format, matching the `EXTENSION.md` skill-agent table.

```json
"routing": {
  "research": {
    "filetypes": "skill-filetypes",
    "filetypes:document": "skill-filetypes",
    "filetypes:spreadsheet": "skill-spreadsheet",
    "filetypes:presentation": "skill-presentation",
    "filetypes:scrape": "skill-scrape",
    "filetypes:docx": "skill-docx-edit"
  },
  "plan": {
    "filetypes": "skill-planner",
    "filetypes:document": "skill-planner",
    "filetypes:spreadsheet": "skill-planner",
    "filetypes:presentation": "skill-planner",
    "filetypes:scrape": "skill-planner",
    "filetypes:docx": "skill-planner"
  },
  "implement": {
    "filetypes": "skill-filetypes",
    "filetypes:document": "skill-filetypes",
    "filetypes:spreadsheet": "skill-spreadsheet",
    "filetypes:presentation": "skill-presentation",
    "filetypes:scrape": "skill-scrape",
    "filetypes:docx": "skill-docx-edit"
  }
}
```

#### formal

task_type: `formal`. Research-only extension (no `-implementation` skills); `implement` reuses the research skills or falls back to `skill-implementer`.

```json
"routing": {
  "research": {
    "formal": "skill-formal-research",
    "formal:logic": "skill-logic-research",
    "formal:math": "skill-math-research",
    "formal:physics": "skill-physics-research"
  },
  "plan": {
    "formal": "skill-planner",
    "formal:logic": "skill-planner",
    "formal:math": "skill-planner",
    "formal:physics": "skill-planner"
  },
  "implement": {
    "formal": "skill-implementer",
    "formal:logic": "skill-implementer",
    "formal:math": "skill-implementer",
    "formal:physics": "skill-implementer"
  }
}
```

#### latex

task_type: `latex`.

```json
"routing": {
  "research": {
    "latex": "skill-latex-research"
  },
  "plan": {
    "latex": "skill-planner"
  },
  "implement": {
    "latex": "skill-latex-implementation"
  }
}
```

#### lean

task_type: `lean4`. Includes specialist skills `skill-lake-repair` and `skill-lean-version` for lake/version sub-domains.

```json
"routing": {
  "research": {
    "lean4": "skill-lean-research",
    "lean4:lake": "skill-lake-repair",
    "lean4:version": "skill-lean-version"
  },
  "plan": {
    "lean4": "skill-planner",
    "lean4:lake": "skill-planner",
    "lean4:version": "skill-planner"
  },
  "implement": {
    "lean4": "skill-lean-implementation",
    "lean4:lake": "skill-lake-repair",
    "lean4:version": "skill-lean-version"
  }
}
```

#### memory

task_type: `null` (use extension name `memory` as routing key). Single-skill extension; `skill-memory` handles all phases.

```json
"routing": {
  "research": {
    "memory": "skill-memory"
  },
  "plan": {
    "memory": "skill-planner"
  },
  "implement": {
    "memory": "skill-memory"
  }
}
```

#### nix

task_type: `nix`.

```json
"routing": {
  "research": {
    "nix": "skill-nix-research"
  },
  "plan": {
    "nix": "skill-planner"
  },
  "implement": {
    "nix": "skill-nix-implementation"
  }
}
```

#### nvim

task_type: `neovim`.

```json
"routing": {
  "research": {
    "neovim": "skill-neovim-research"
  },
  "plan": {
    "neovim": "skill-planner"
  },
  "implement": {
    "neovim": "skill-neovim-implementation"
  }
}
```

#### python

task_type: `python`.

```json
"routing": {
  "research": {
    "python": "skill-python-research"
  },
  "plan": {
    "python": "skill-planner"
  },
  "implement": {
    "python": "skill-python-implementation"
  }
}
```

#### typst

task_type: `typst`.

```json
"routing": {
  "research": {
    "typst": "skill-typst-research"
  },
  "plan": {
    "typst": "skill-planner"
  },
  "implement": {
    "typst": "skill-typst-implementation"
  }
}
```

#### web

task_type: `web`. `skill-tag` is a user-only deployment skill and should not be exposed via automatic routing (see `.claude/CLAUDE.md` "User-Only Skills"); it is intentionally omitted from the routing map.

```json
"routing": {
  "research": {
    "web": "skill-web-research"
  },
  "plan": {
    "web": "skill-planner"
  },
  "implement": {
    "web": "skill-web-implementation"
  }
}
```

#### z3

task_type: `z3`.

```json
"routing": {
  "research": {
    "z3": "skill-z3-research"
  },
  "plan": {
    "z3": "skill-planner"
  },
  "implement": {
    "z3": "skill-z3-implementation"
  }
}
```

### Placement Within Manifest

In all compliant examples, `routing` appears as a sibling of `provides`, immediately following the `provides` block and before `merge_targets`. Keep this ordering for consistency.

### Verification Method

After edits, re-running `bash .claude/scripts/check-extension-docs.sh` should produce `PASS: all extensions OK` (exit 0). The 2 pre-existing WARN messages (`memory` and `present` README drift) are mtime warnings, not failures, and are out of scope for this task.

## Decisions

- **D1**: Use the three-bucket schema (`research`, `plan`, `implement`) from the compliant examples rather than inventing a new shape. The doc-lint check only requires presence, but routing parity with `present/`, `founder/`, and `epidemiology/` is required for run-time correctness.
- **D2**: Route `plan` to core `skill-planner` for every failing extension. None of the 11 failing extensions provide a dedicated planner skill; this mirrors how `epidemiology/` and `present/` route plans.
- **D3**: For extensions with `task_type: null` (`filetypes`, `memory`), use the extension name as the routing key. This matches how `--task-type` arguments would be specified on the command line.
- **D4**: Exclude `skill-tag` from `web/` routing because it is marked user-only in `.claude/CLAUDE.md`.
- **D5**: For `formal/` (research-only extension with no implementation skills), route `implement` to core `skill-implementer` rather than leaving the bucket empty, to ensure command dispatch does not fail if an implement task is created.
- **D6**: Add compound sub-routing keys only where the extension has multiple specialist skills (`filetypes`, `formal`, `lean`, `founder`-style). Single-skill extensions use only the bare task-type key.

## Recommendations

Prioritized for the implementation plan:

1. **High / Mechanical**: Add `routing` blocks to the 11 manifests using the per-extension JSON above. Each manifest edit is independent; they can be applied in any order.
2. **High / Verification**: After all edits, run `bash .claude/scripts/check-extension-docs.sh` and confirm `PASS: all extensions OK` with exit 0.
3. **Medium / Validation**: Run `bash .claude/scripts/validate-wiring.sh` (if present) to confirm the routing entries reference real skill directories. Cross-check each `skill-*` value against `.claude/extensions/{ext}/skills/{skill}/SKILL.md`.
4. **Low / Follow-up (out of scope)**: Once this task is complete, the review recommends landing the CI doc-lint roadmap item (currently blocked by these failures).

## Risks & Mitigations

- **Risk**: Adding a `routing` block that references a nonexistent skill. **Mitigation**: Every skill name in the per-extension JSON above was cross-referenced against the manifest's `provides.skills` list (or the core skills `skill-planner`, `skill-implementer`). Validate with `validate-wiring.sh` after edits.
- **Risk**: Breaking JSON syntax when editing manifests manually. **Mitigation**: Use `jq empty` on each file after edit; the doc-lint script already validates JSON before the routing check.
- **Risk**: Wrong task-type key causing silent routing fallthrough at run time. **Mitigation**: Each bare task-type key matches the manifest's declared `task_type` field (or extension name when null). Load the extension via `<leader>ac` and test a dispatch if confidence is needed.
- **Risk**: Ordering of keys in JSON (cosmetic). **Mitigation**: Place `routing` between `provides` and `merge_targets`, matching all three compliant examples.

## Appendix

### doc-lint command

```bash
bash .claude/scripts/check-extension-docs.sh
```

Current output:
```
FAIL: 11 issue(s) found
```

Target output after implementation:
```
PASS: all extensions OK
```

### Key references

- Doc-lint script: `.claude/scripts/check-extension-docs.sh` lines 109-123 (routing check), lines 156-183 (iteration loop).
- Routing schema source: `.claude/extensions/epidemiology/manifest.json` lines 25-41 (minimal reference); `.claude/extensions/founder/manifest.json` lines 46-86 (multi-sub-type reference); `.claude/extensions/present/manifest.json` lines 16-41 (mixed-planner reference).
- System documentation: `.claude/CLAUDE.md` "Task-Type-Based Routing" and "Extension Skills" sections.
- Standards: `.claude/docs/reference/standards/extension-slim-standard.md` (EXTENSION.md content; confirms routing tables are the primary purpose of extension manifests/docs).
- Issue source: `specs/reviews/review-2026-04-10.md` lines 22-43, 79-80.

### Commands used during research

```bash
bash .claude/scripts/check-extension-docs.sh
jq '{name, task_type, skills: .provides.skills}' .claude/extensions/{ext}/manifest.json
jq '{task_type, commands: .provides.commands}' .claude/extensions/{ext}/manifest.json
```
