# Research Report: Task #102

**Task**: 102 - review_extensions_populate_missing_resources
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of nvim/.claude/extensions/, Logos/Theory/.claude/, ModelChecker/.claude/, ProofChecker/.claude/
**Artifacts**: specs/102_review_extensions_populate_missing_resources/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The lean extension has the most gaps: empty commands/ and scripts/ directories (manifest promises lake.md, lean.md, setup-lean-mcp.sh, verify-lean-mcp.sh), and 18 missing context files
- The latex extension is missing 7 context files (standards/, templates/, tools/, and patterns/cross-references.md)
- The typst extension is missing 9 context files (standards/, patterns/, templates/)
- The z3 extension is missing 2 context files (domain/smt-patterns.md, patterns/bitvector-operations.md)
- The python extension is missing 2 context files (domain/model-checker-api.md, domain/theory-lib-patterns.md) and 1 patterns file (patterns/semantic-evaluation.md) -- though the domain files may be project-specific
- The logic and math research agents/skills from Logos/Theory and ProofChecker have no extension at all but are likely project-specific and out of scope
- The neovim extension is a stub (3 files only) but this is expected since neovim is the native domain of this config

## Context and Scope

This research compares all resources in the nvim/.claude/extensions/ directory against the source projects:
- **Logos/Theory** - Source for lean, latex, typst extensions
- **ModelChecker** - Source for z3, python extensions
- **ProofChecker** - Additional source for lean extensions

The comparison covers: commands, agents, skills, rules, context files, and scripts.

## Findings

### 1. Lean Extension Gaps

**Commands (CRITICAL - manifest mismatch)**:
The lean manifest.json declares `"commands": ["lake.md", "lean.md"]` but the `commands/` directory exists and is empty. Both commands exist in Logos/Theory and ProofChecker.

Missing commands:
- `commands/lake.md` - Run `lake build` with automatic error repair
- `commands/lean.md` - Manage Lean toolchain and Mathlib versions

**Scripts (manifest mismatch)**:
The lean manifest.json declares `"scripts": ["setup-lean-mcp.sh", "verify-lean-mcp.sh"]` but the `scripts/` directory exists and is empty. Both scripts exist in Logos/Theory and ProofChecker.

Missing scripts:
- `scripts/setup-lean-mcp.sh` - Set up lean-lsp MCP server
- `scripts/verify-lean-mcp.sh` - Verify lean-lsp MCP is working

**Context files (18 missing)**:
The lean extension has 5 context files. The source projects (Logos/Theory + ProofChecker) have 23. Missing:

| Category | File | Source |
|----------|------|--------|
| agents | agents/lean-implementation-flow.md | Logos/Theory, ProofChecker |
| agents | agents/lean-research-flow.md | Logos/Theory, ProofChecker |
| domain | domain/dependent-types.md | Logos/Theory, ProofChecker |
| domain | domain/key-mathematical-concepts.md | Logos/Theory, ProofChecker |
| domain | domain/lean4-syntax.md | Logos/Theory, ProofChecker |
| operations | operations/multi-instance-optimization.md | Logos/Theory, ProofChecker |
| processes | processes/end-to-end-proof-workflow.md | Logos/Theory, ProofChecker |
| processes | processes/project-structure-best-practices.md | Logos/Theory, ProofChecker |
| standards | standards/proof-conventions-lean.md | Logos/Theory, ProofChecker |
| standards | standards/proof-debt-policy.md | Logos/Theory, ProofChecker |
| standards | standards/proof-readability-criteria.md | Logos/Theory, ProofChecker |
| templates | templates/definition-template.md | Logos/Theory, ProofChecker |
| templates | templates/new-file-template.md | Logos/Theory, ProofChecker |
| templates | templates/proof-structure-templates.md | Logos/Theory, ProofChecker |
| tools | tools/aesop-integration.md | Logos/Theory, ProofChecker |
| tools | tools/leansearch-api.md | Logos/Theory, ProofChecker |
| tools | tools/loogle-api.md | Logos/Theory, ProofChecker |
| tools | tools/lsp-integration.md | Logos/Theory, ProofChecker |

**Agents and Skills**: Complete (lean-research-agent, lean-implementation-agent, skill-lean-research, skill-lean-implementation, skill-lake-repair, skill-lean-version all present).

**Rules**: Complete (lean4.md present).

### 2. LaTeX Extension Gaps

**Commands**: None declared in manifest, none in source projects are latex-specific (the general commands like implement/research handle latex routing).

**Context files (7 missing)**:
The latex extension has 3 context files. Source projects have 10.

| Category | File | Source |
|----------|------|--------|
| patterns | patterns/cross-references.md | Logos/Theory, ProofChecker, ModelChecker |
| standards | standards/document-structure.md | Logos/Theory, ProofChecker, ModelChecker |
| standards | standards/latex-style-guide.md | Logos/Theory, ProofChecker, ModelChecker |
| standards | standards/logos-macros.md | Logos/Theory, ProofChecker (project-specific?) |
| standards | standards/notation-conventions.md | Logos/Theory, ProofChecker |
| templates | templates/subfile-template.md | Logos/Theory, ProofChecker |
| tools | tools/compilation-guide.md | Logos/Theory, ProofChecker, ModelChecker |

Note: The extension has `patterns/document-structure.md` but source projects have `standards/document-structure.md` -- these may be different files or a misplacement.

**Agents and Skills**: Complete.
**Rules**: Complete (latex.md present).

### 3. Typst Extension Gaps

**Commands**: None (correct).

**Context files (9 missing)**:
The typst extension has 3 context files. Source projects have 12.

| Category | File | Source |
|----------|------|--------|
| patterns | patterns/cross-references.md | Logos/Theory, ProofChecker, ModelChecker |
| patterns | patterns/fletcher-diagrams.md | Logos/Theory, ProofChecker |
| patterns | patterns/rule-environments.md | Logos/Theory, ProofChecker |
| standards | standards/document-structure.md | Logos/Theory, ProofChecker, ModelChecker |
| standards | standards/dtt-foundation-standard.md | Logos/Theory, ProofChecker (may be project-specific) |
| standards | standards/notation-conventions.md | Logos/Theory, ProofChecker, ModelChecker |
| standards | standards/textbook-standards.md | Logos/Theory, ProofChecker |
| standards | standards/typst-style-guide.md | Logos/Theory, ProofChecker, ModelChecker |
| templates | templates/chapter-template.md | Logos/Theory, ProofChecker, ModelChecker |

**Agents and Skills**: Complete.
**Rules**: No rules directory and no rules declared in manifest. Source projects have no typst-specific rule file either, so this is consistent.

### 4. Z3 Extension Gaps

**Commands**: None (correct).

**Context files (2 missing)**:

| Category | File | Source |
|----------|------|--------|
| domain | domain/smt-patterns.md | ModelChecker |
| patterns | patterns/bitvector-operations.md | ModelChecker |

**Agents and Skills**: Complete.
**Rules**: None in manifest or source projects.

### 5. Python Extension Gaps

**Commands**: None (correct).

**Context files (3 missing, 2 possibly project-specific)**:

| Category | File | Source | Notes |
|----------|------|--------|-------|
| domain | domain/model-checker-api.md | ModelChecker | Project-specific API |
| domain | domain/theory-lib-patterns.md | ModelChecker | Project-specific patterns |
| patterns | patterns/semantic-evaluation.md | ModelChecker | Project-specific |

Note: All 3 missing files are ModelChecker-specific (model-checker-api, theory-lib-patterns, semantic-evaluation). The extension already has the generic python resources (code-style.md, testing-patterns.md). These domain files may not be appropriate for a generic python extension since they describe the ModelChecker application specifically.

**Agents and Skills**: Complete.
**Rules**: No python-specific rules in ModelChecker either.

### 6. Neovim Extension (Context)

The neovim extension is a stub (manifest.json, claudemd-section.md, index-entries.json only). This is expected because neovim is the native domain of this repository -- its agents, skills, rules, and context live in the main `.claude/` directory, not in the extensions system.

However, the manifest declares providing agents, skills, rules, and context that don't exist in the extension directory. This manifest-vs-reality mismatch should be noted but is a design decision rather than a gap.

### 7. Resources Out of Scope

The following resources exist in source projects but are NOT appropriate for the extension system:

- **logic/ and math/ context domains** (Logos/Theory, ProofChecker) - These are highly project-specific academic domains
- **physics/ context domain** (Logos/Theory, ProofChecker) - Project-specific
- **logic-research-agent and math-research-agent** (Logos/Theory, ProofChecker) - Project-specific
- **skill-logic-research and skill-math-research** (Logos/Theory, ProofChecker) - Project-specific
- **merge.md command** (Logos/Theory, ProofChecker) - GitLab-specific, not language-related
- **team skills** (skill-team-implement, skill-team-plan, skill-team-research) - Core orchestration, not extension material
- **hooks** - Project-specific runtime hooks
- **core context/** - Shared orchestration infrastructure, not extension material
- **ModelChecker-specific python domain files** - Application-specific API documentation

### 8. Potentially Project-Specific Files

Some files in source projects may be too project-specific for a generic extension:
- `latex/standards/logos-macros.md` - Logos project macros
- `latex/standards/sn-article-requirements.md` - Springer Nature article format (ModelChecker)
- `typst/standards/dtt-foundation-standard.md` - Dependent type theory standard
- `lean4/standards/proof-conventions-lean.md` vs `proof-conventions.md` - ProofChecker has both
- Python domain files from ModelChecker

## Recommendations

### Priority 1: Fix Manifest Mismatches (lean extension)
The lean manifest declares commands and scripts that don't exist. Either:
- (A) Copy lake.md, lean.md from Logos/Theory to `extensions/lean/commands/`
- (B) Copy setup-lean-mcp.sh, verify-lean-mcp.sh from Logos/Theory to `extensions/lean/scripts/`
- These should be adapted to be project-agnostic (remove Logos/Theory-specific paths)

### Priority 2: Fill Lean Context Gaps (18 files)
Copy and adapt the 18 missing context files from Logos/Theory to the lean extension. Filter out any project-specific content (e.g., references to specific Logos modules).

### Priority 3: Fill LaTeX Context Gaps (7 files)
Copy generic latex context from source projects. Skip `logos-macros.md` if it is too project-specific, or generalize it.

### Priority 4: Fill Typst Context Gaps (9 files)
Copy generic typst context. Consider whether `dtt-foundation-standard.md` is too project-specific.

### Priority 5: Fill Z3 Context Gaps (2 files)
Copy `domain/smt-patterns.md` and `patterns/bitvector-operations.md` from ModelChecker.

### Priority 6: Python Extension Decision
Decide whether `model-checker-api.md`, `theory-lib-patterns.md`, and `semantic-evaluation.md` should be generalized or skipped since they are ModelChecker-specific.

### Priority 7: Update Manifests
After populating files, update each `manifest.json` to accurately reflect what is provided.

## Decisions

- The neovim extension should remain a stub since neovim resources live in the main `.claude/` directory
- logic/, math/, physics/ context domains are project-specific and should NOT become extensions
- The merge.md command is GitLab-specific, not language-specific, and should not go in any extension
- Team skills are core orchestration infrastructure, not extension material

## Risks and Mitigations

- **Risk**: Copying files verbatim from source projects may include project-specific paths or references
  - **Mitigation**: Review and adapt each file during implementation, replacing project-specific references with generic placeholders
- **Risk**: Some context files may become stale if source projects update them
  - **Mitigation**: Document the source project origin in each file header; consider a sync mechanism
- **Risk**: Manifest mismatches cause confusion about what an extension actually provides
  - **Mitigation**: Validate manifests against actual directory contents as part of implementation

## Gap Summary Table

| Extension | Commands | Scripts | Agents | Skills | Rules | Context Files | Total Gaps |
|-----------|----------|---------|--------|--------|-------|---------------|------------|
| lean      | 2        | 2       | 0      | 0      | 0     | 18            | 22         |
| latex     | 0        | 0       | 0      | 0      | 0     | 7             | 7          |
| typst     | 0        | 0       | 0      | 0      | 0     | 9             | 9          |
| z3        | 0        | 0       | 0      | 0      | 0     | 2             | 2          |
| python    | 0        | 0       | 0      | 0      | 0     | 3 (debatable) | 3          |
| neovim    | N/A      | N/A     | N/A    | N/A    | N/A   | N/A           | 0 (stub)   |
| **TOTAL** | **2**    | **2**   | **0**  | **0**  | **0** | **39**        | **43**     |

## Appendix

### Search Strategy
1. Listed all files in each extension directory under `.claude/extensions/`
2. Listed all files in each source project's `.claude/` directory
3. Compared category by category: commands, agents, skills, rules, context, scripts
4. Cross-referenced manifest.json declarations against actual directory contents
5. Categorized gaps as critical (manifest mismatch), standard (missing context), or out-of-scope

### Source Projects Examined
- `/home/benjamin/Projects/Logos/Theory/.claude/` - Primary source for lean, latex, typst
- `/home/benjamin/Projects/ModelChecker/.claude/` - Primary source for z3, python
- `/home/benjamin/Projects/ProofChecker/.claude/` - Secondary source for lean (confirms Logos/Theory patterns)
