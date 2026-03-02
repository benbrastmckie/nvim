# Implementation Plan: Task #102

**Task**: 102 - Review extensions and populate missing resources
**Date**: 2026-03-02
**Feature**: Complete extension population, structural restructuring, and formal/ extension creation
**Status**: [IMPLEMENTING]
**Estimated Hours**: 6-10 hours
**Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
**Research Reports**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
**Type**: meta
**Lean Intent**: false

## Overview

This plan addresses three categories of work identified across two research reports: (1) renaming `claudemd-section.md` to `EXTENSION.md` in all extensions and updating manifest references, (2) removing the neovim/ stub extension, (3) creating the formal/ extension consolidating logic, math, and physics resources, and (4) populating 39 missing context files plus 4 missing commands/scripts across the lean, latex, typst, z3, and python extensions. The work is organized into 8 phases with clear dependencies: structural changes first, then content population by extension, and finally the formal/ extension which is the largest single unit of work.

### Research Integration

Research Report 001 identified 43 total resource gaps across 5 extensions (22 lean, 7 latex, 9 typst, 2 z3, 3 python). It also identified manifest-vs-reality mismatches in the lean extension (declared commands/scripts that do not exist) and determined that logic, math, and physics domains were out of scope for extensions.

Research Report 002 revised the scope: (a) create a formal/ extension consolidating logic, math, and physics, (b) remove the neovim/ extension entirely, (c) rename claudemd-section.md to EXTENSION.md everywhere. Report 002 confirmed no Lua code changes are needed for the rename -- the extension loader reads filenames dynamically from manifest.json.

## Goals and Non-Goals

**Goals**:
- Rename all `claudemd-section.md` files to `EXTENSION.md` and update manifests
- Remove the neovim/ extension stub
- Create the formal/ extension with logic, math, and physics agents/skills/context
- Populate all 18 missing lean context files plus 2 commands and 2 scripts
- Populate all 7 missing latex context files
- Populate all 9 missing typst context files
- Populate all 2 missing z3 context files
- Populate 3 python context files (generalized from project-specific sources)
- Update all manifest.json files to accurately reflect provided resources
- Update all index-entries.json files with new context entries

**Non-Goals**:
- Modifying the extension loader Lua code (no changes needed)
- Adding new languages to the routing table (formal/ uses existing patterns)
- Creating implementation agents for the formal/ extension (research agents only)
- Syncing with upstream source projects after initial copy

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ProofChecker-specific references leak into copied files | Medium | High | Review and adapt each file during copy, replacing project-specific paths with generic placeholders |
| Logos-specific macros in latex standards are too project-specific | Low | Medium | Generalize logos-macros.md into generic-macros.md or omit and note in manifest |
| Python domain files are too ModelChecker-specific to generalize | Low | Medium | Create generalized versions focusing on patterns rather than specific APIs |
| Physics research agent lacks sufficient context for useful operation | Low | Low | Start minimal, document as extensible in README |
| Manifest mismatches persist after population | Medium | Low | Validate manifests against directory contents as final verification step |
| Extension loading breaks after rename | Medium | Low | Test load/unload cycle for each extension after rename |

## Implementation Phases

### Phase 1: Rename claudemd-section.md to EXTENSION.md [COMPLETED]

**Status**: [COMPLETED]
**Estimated effort**: 0.5 hours

**Objectives**:
1. Rename all 6 `claudemd-section.md` files to `EXTENSION.md` via git mv
2. Update all 6 `manifest.json` files to reference the new filename
3. Verify no Lua code references the old filename directly

**Files to modify**:
- `.claude/extensions/lean/claudemd-section.md` -> `.claude/extensions/lean/EXTENSION.md` (git mv)
- `.claude/extensions/latex/claudemd-section.md` -> `.claude/extensions/latex/EXTENSION.md` (git mv)
- `.claude/extensions/neovim/claudemd-section.md` -> `.claude/extensions/neovim/EXTENSION.md` (git mv)
- `.claude/extensions/python/claudemd-section.md` -> `.claude/extensions/python/EXTENSION.md` (git mv)
- `.claude/extensions/typst/claudemd-section.md` -> `.claude/extensions/typst/EXTENSION.md` (git mv)
- `.claude/extensions/z3/claudemd-section.md` -> `.claude/extensions/z3/EXTENSION.md` (git mv)
- `.claude/extensions/lean/manifest.json` - Change `"source": "claudemd-section.md"` to `"source": "EXTENSION.md"`
- `.claude/extensions/latex/manifest.json` - Same change
- `.claude/extensions/neovim/manifest.json` - Same change
- `.claude/extensions/python/manifest.json` - Same change
- `.claude/extensions/typst/manifest.json` - Same change
- `.claude/extensions/z3/manifest.json` - Same change

**Steps**:
1. For each of the 6 extensions (lean, latex, neovim, python, typst, z3):
   a. Run `git mv .claude/extensions/{name}/claudemd-section.md .claude/extensions/{name}/EXTENSION.md`
   b. Edit `manifest.json` to change `merge_targets.claudemd.source` from `"claudemd-section.md"` to `"EXTENSION.md"`
2. Verify no Lua files reference `claudemd-section.md` directly (research-002 confirmed this -- functions use config.source from manifest)
3. Test that the extension picker still lists all extensions correctly

**Verification**:
- `find .claude/extensions/ -name "claudemd-section.md"` returns no results
- `find .claude/extensions/ -name "EXTENSION.md"` returns 6 results
- All 6 `manifest.json` files contain `"source": "EXTENSION.md"`
- `grep -r "claudemd-section" .claude/extensions/*/manifest.json` returns no results

---

### Phase 2: Remove neovim/ Extension [COMPLETED]

**Status**: [COMPLETED]
**Estimated effort**: 0.25 hours

**Objectives**:
1. Delete the neovim/ extension directory entirely
2. Verify no other extensions depend on it

**Files to delete**:
- `.claude/extensions/neovim/EXTENSION.md` (renamed in Phase 1)
- `.claude/extensions/neovim/index-entries.json`
- `.claude/extensions/neovim/manifest.json`
- `.claude/extensions/neovim/` (directory)

**Steps**:
1. Verify no other extension manifest lists "neovim" in its `dependencies` array (research-002 confirmed all have `"dependencies": []`)
2. Remove the directory: `rm -rf .claude/extensions/neovim/`
3. Verify the directory no longer exists

**Verification**:
- `ls .claude/extensions/neovim/` returns "No such file or directory"
- `grep -r "neovim" .claude/extensions/*/manifest.json` shows no dependency references (only the lean manifest's description mentioning "prover" is expected)
- Extension picker lists 5 extensions (lean, latex, python, typst, z3) -- neovim is gone

---

### Phase 3: Populate Lean Extension [COMPLETED]

**Status**: [COMPLETED]
**Estimated effort**: 1.5 hours

**Objectives**:
1. Create 2 missing commands (lake.md, lean.md) adapted from ProofChecker
2. Create 2 missing scripts (setup-lean-mcp.sh, verify-lean-mcp.sh) adapted from ProofChecker
3. Create 18 missing context files adapted from ProofChecker
4. Update lean manifest.json to accurately reflect all resources
5. Update lean index-entries.json with new context file entries

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/`

**Files to create**:

Commands (adapted from ProofChecker):
- `.claude/extensions/lean/commands/lake.md` - Lake build with error repair (from ProofChecker/.claude/commands/lake.md)
- `.claude/extensions/lean/commands/lean.md` - Lean toolchain management (from ProofChecker/.claude/commands/lean.md)

Scripts (adapted from ProofChecker):
- `.claude/extensions/lean/scripts/setup-lean-mcp.sh` - Lean MCP server setup (from ProofChecker/.claude/scripts/setup-lean-mcp.sh)
- `.claude/extensions/lean/scripts/verify-lean-mcp.sh` - Lean MCP verification (from ProofChecker/.claude/scripts/verify-lean-mcp.sh)

Context files (18, adapted from ProofChecker/.claude/context/project/lean4/):
- `.claude/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
- `.claude/extensions/lean/context/project/lean4/agents/lean-research-flow.md`
- `.claude/extensions/lean/context/project/lean4/domain/dependent-types.md`
- `.claude/extensions/lean/context/project/lean4/domain/key-mathematical-concepts.md`
- `.claude/extensions/lean/context/project/lean4/domain/lean4-syntax.md`
- `.claude/extensions/lean/context/project/lean4/operations/multi-instance-optimization.md`
- `.claude/extensions/lean/context/project/lean4/processes/end-to-end-proof-workflow.md`
- `.claude/extensions/lean/context/project/lean4/processes/project-structure-best-practices.md`
- `.claude/extensions/lean/context/project/lean4/standards/proof-conventions-lean.md`
- `.claude/extensions/lean/context/project/lean4/standards/proof-debt-policy.md`
- `.claude/extensions/lean/context/project/lean4/standards/proof-readability-criteria.md`
- `.claude/extensions/lean/context/project/lean4/templates/definition-template.md`
- `.claude/extensions/lean/context/project/lean4/templates/new-file-template.md`
- `.claude/extensions/lean/context/project/lean4/templates/proof-structure-templates.md`
- `.claude/extensions/lean/context/project/lean4/tools/aesop-integration.md`
- `.claude/extensions/lean/context/project/lean4/tools/leansearch-api.md`
- `.claude/extensions/lean/context/project/lean4/tools/loogle-api.md`
- `.claude/extensions/lean/context/project/lean4/tools/lsp-integration.md`

**Files to modify**:
- `.claude/extensions/lean/manifest.json` - Verify commands and scripts arrays match actual files
- `.claude/extensions/lean/index-entries.json` - Add entries for all 18 new context files

**Steps**:
1. Read each source file from ProofChecker
2. Adapt content to be project-agnostic:
   - Replace ProofChecker-specific paths (`Theories/`, `docs/`, etc.) with generic placeholders (`{project_theories_dir}/`, etc.)
   - Remove references to specific ProofChecker modules or theorems
   - Keep Mathlib MCP tool integration (lean_leansearch, lean_loogle, lean_leanfinder) as these are universal
   - Keep general Lean4 patterns and conventions
3. Create each file in the lean extension directory structure
4. For commands: remove ProofChecker-specific error handling paths, keep generic lake build patterns
5. For scripts: replace hardcoded paths with `$PROJECT_ROOT` variable patterns
6. Update index-entries.json with entries for all new context files, following the existing entry format
7. Validate manifest.json accurately declares all resources

**Verification**:
- All 22 new files exist and contain adapted content
- `find .claude/extensions/lean/ -type f | wc -l` shows increase from current count (14) to 36
- `grep -r "ProofChecker" .claude/extensions/lean/` returns no results
- `grep -r "Logos" .claude/extensions/lean/` returns no results
- manifest.json `provides.commands` lists `["lake.md", "lean.md"]` (already does)
- manifest.json `provides.scripts` lists `["setup-lean-mcp.sh", "verify-lean-mcp.sh"]` (already does)
- index-entries.json parses as valid JSON with new entries

---

### Phase 4: Populate LaTeX Extension [COMPLETED]

**Status**: [COMPLETED]
**Estimated effort**: 0.75 hours

**Objectives**:
1. Create 7 missing context files adapted from Logos/Theory and ModelChecker
2. Update latex index-entries.json with new context entries
3. Resolve the document-structure.md placement (extension has patterns/, source has standards/)

**Source**: `/home/benjamin/Projects/Logos/Theory/.claude/context/project/latex/`

**Files to create** (adapted from Logos/Theory):
- `.claude/extensions/latex/context/project/latex/patterns/cross-references.md` - Cross-reference patterns
- `.claude/extensions/latex/context/project/latex/standards/document-structure.md` - Document structure standards
- `.claude/extensions/latex/context/project/latex/standards/latex-style-guide.md` - LaTeX style guide
- `.claude/extensions/latex/context/project/latex/standards/notation-conventions.md` - Mathematical notation conventions
- `.claude/extensions/latex/context/project/latex/standards/custom-macros.md` - Custom macro patterns (generalized from logos-macros.md)
- `.claude/extensions/latex/context/project/latex/templates/subfile-template.md` - Subfile template
- `.claude/extensions/latex/context/project/latex/tools/compilation-guide.md` - Compilation workflow guide

**Files to modify**:
- `.claude/extensions/latex/index-entries.json` - Add entries for all 7 new context files

**Steps**:
1. Read each source file from Logos/Theory
2. Adapt content to be project-agnostic:
   - For `logos-macros.md`: Generalize into `custom-macros.md` covering LaTeX macro definition patterns without Logos-specific commands
   - For `document-structure.md`: Place in standards/ (matching source project structure)
   - For notation-conventions: Remove Logos-specific mathematical notation, keep general LaTeX math conventions
   - Keep general LaTeX patterns and compilation advice
3. Create each file in the latex extension directory
4. Update index-entries.json with new entries
5. Verify the existing `patterns/document-structure.md` file content does not conflict with the new `standards/document-structure.md` -- if they cover different topics, keep both; if redundant, consolidate

**Verification**:
- All 7 new files exist and contain adapted content
- `grep -r "Logos" .claude/extensions/latex/` returns no results (or only in generic context)
- `grep -r "logos" .claude/extensions/latex/` returns no results for project-specific references
- index-entries.json parses as valid JSON with new entries
- Total context files: 3 existing + 7 new = 10

---

### Phase 5: Populate Typst Extension [COMPLETED]

**Status**: [COMPLETED]
**Estimated effort**: 0.75 hours

**Objectives**:
1. Create 9 missing context files adapted from Logos/Theory
2. Update typst index-entries.json with new context entries

**Source**: `/home/benjamin/Projects/Logos/Theory/.claude/context/project/typst/`

**Files to create** (adapted from Logos/Theory):
- `.claude/extensions/typst/context/project/typst/patterns/cross-references.md` - Cross-reference patterns
- `.claude/extensions/typst/context/project/typst/patterns/fletcher-diagrams.md` - Fletcher diagram patterns
- `.claude/extensions/typst/context/project/typst/patterns/rule-environments.md` - Inference rule environments
- `.claude/extensions/typst/context/project/typst/standards/document-structure.md` - Document structure standards
- `.claude/extensions/typst/context/project/typst/standards/notation-conventions.md` - Notation conventions
- `.claude/extensions/typst/context/project/typst/standards/textbook-standards.md` - Textbook authoring standards
- `.claude/extensions/typst/context/project/typst/standards/typst-style-guide.md` - Typst style guide
- `.claude/extensions/typst/context/project/typst/standards/type-theory-foundations.md` - Type theory foundations (generalized from dtt-foundation-standard.md)
- `.claude/extensions/typst/context/project/typst/templates/chapter-template.md` - Chapter template

**Files to modify**:
- `.claude/extensions/typst/index-entries.json` - Add entries for all 9 new context files

**Steps**:
1. Read each source file from Logos/Theory
2. Adapt content to be project-agnostic:
   - For `dtt-foundation-standard.md`: Generalize into `type-theory-foundations.md` covering dependent type theory conventions for typst documents broadly, not just Logos/Theory specific DTT
   - For `textbook-standards.md`: Remove Logos-specific chapter references, keep general typst textbook patterns
   - For `fletcher-diagrams.md`: Keep as-is -- Fletcher is a general Typst package, not project-specific
   - For `notation-conventions.md`: Remove project-specific notation, keep general typst math conventions
3. Create each file in the typst extension directory
4. Update index-entries.json with new entries

**Verification**:
- All 9 new files exist and contain adapted content
- `grep -r "Logos" .claude/extensions/typst/` returns no results for project-specific references
- `grep -r "ProofChecker" .claude/extensions/typst/` returns no results
- index-entries.json parses as valid JSON with new entries
- Total context files: 3 existing + 9 new = 12

---

### Phase 6: Populate Z3 and Python Extensions [NOT STARTED]

**Status**: [NOT STARTED]
**Estimated effort**: 0.75 hours

**Objectives**:
1. Create 2 missing z3 context files adapted from ModelChecker
2. Create 3 missing python context files generalized from ModelChecker
3. Update both index-entries.json files

**Source**: `/home/benjamin/Projects/ModelChecker/.claude/context/project/`

**Z3 files to create** (adapted from ModelChecker):
- `.claude/extensions/z3/context/project/z3/domain/smt-patterns.md` - SMT solving patterns
- `.claude/extensions/z3/context/project/z3/patterns/bitvector-operations.md` - Bitvector operation patterns

**Python files to create** (generalized from ModelChecker):
- `.claude/extensions/python/context/project/python/domain/application-api-patterns.md` - Generalized from model-checker-api.md: patterns for structuring Python application APIs
- `.claude/extensions/python/context/project/python/domain/library-patterns.md` - Generalized from theory-lib-patterns.md: patterns for building Python domain-specific libraries
- `.claude/extensions/python/context/project/python/patterns/semantic-evaluation.md` - Generalized: tree-walking evaluation patterns for Python interpreters/evaluators

**Files to modify**:
- `.claude/extensions/z3/index-entries.json` - Add entries for 2 new context files
- `.claude/extensions/python/index-entries.json` - Add entries for 3 new context files

**Steps**:
1. Read each source file from ModelChecker
2. For z3 files: Adapt to remove ModelChecker-specific constraint generation patterns while keeping general SMT and bitvector patterns
3. For python files: Significantly generalize:
   - `model-checker-api.md` -> `application-api-patterns.md`: Extract the architectural patterns (command pattern, factory pattern, etc.) without ModelChecker-specific classes
   - `theory-lib-patterns.md` -> `library-patterns.md`: Extract patterns for building domain-specific Python libraries
   - `semantic-evaluation.md`: Keep tree-walking evaluation as a general pattern, remove ModelChecker-specific AST nodes
4. Create each file
5. Update both index-entries.json files

**Verification**:
- All 5 new files exist and contain generalized content
- `grep -r "ModelChecker" .claude/extensions/z3/` returns no results
- `grep -r "ModelChecker" .claude/extensions/python/` returns no results
- Both index-entries.json files parse as valid JSON
- Z3 total context files: 3 existing + 2 new = 5
- Python total context files: 3 existing + 3 new = 6

---

### Phase 7: Create formal/ Extension [NOT STARTED]

**Status**: [NOT STARTED]
**Estimated effort**: 2.5 hours

**Objectives**:
1. Create the formal/ extension directory structure
2. Create manifest.json, EXTENSION.md, and index-entries.json
3. Copy and adapt 2 agents from ProofChecker (logic-research-agent, math-research-agent)
4. Create 1 new agent (physics-research-agent)
5. Copy and adapt 2 skills from ProofChecker (skill-logic-research, skill-math-research)
6. Create 1 new skill (skill-physics-research)
7. Copy and adapt 34 context files from ProofChecker (18 logic + 14 math + 2 physics)

**Source**: `/home/benjamin/Projects/ProofChecker/.claude/`

**Directory structure to create**:
```
.claude/extensions/formal/
  manifest.json
  EXTENSION.md
  index-entries.json
  agents/
    logic-research-agent.md
    math-research-agent.md
    physics-research-agent.md
  skills/
    skill-logic-research/SKILL.md
    skill-math-research/SKILL.md
    skill-physics-research/SKILL.md
  context/
    project/
      logic/
        README.md
        domain/
          bilateral-propositions.md
          bilateral-semantics.md
          counterfactual-semantics.md
          kripke-semantics-overview.md
          lattice-theory-concepts.md
          mereology-foundations.md
          metalogic-concepts.md
          proof-theory-concepts.md
          spatial-domain.md
          task-semantics.md
          topological-foundations-domain.md
        processes/
          modal-proof-strategies.md
          proof-construction.md
          temporal-proof-strategies.md
          verification-workflow.md
        standards/
          naming-conventions.md
          notation-standards.md
          proof-conventions.md
      math/
        README.md
        algebra/
          groups-and-monoids.md
          rings-and-fields.md
        category-theory/
          basics.md
          cauchy-completion.md
          enriched-categories.md
          lawvere-metric-spaces.md
          monoidal-categories.md
          profunctors.md
        foundations/
          dependent-type-theory.md
        lattice-theory/
          bilattice-theory.md
          lattices.md
        order-theory/
          monoidal-posets.md
          partial-orders.md
        topology/
          scott-topology.md
          topological-spaces.md
      physics/
        README.md
        dynamical-systems/
          dynamical-systems.md
```

**Files to create (metadata)**:
- `.claude/extensions/formal/manifest.json` - Extension manifest with formal language, 3 agents, 3 skills, 3 context domains
- `.claude/extensions/formal/EXTENSION.md` - CLAUDE.md section for formal reasoning language routing
- `.claude/extensions/formal/index-entries.json` - Context index entries for all 34 context files

**Files to create (agents, adapted from ProofChecker)**:
- `.claude/extensions/formal/agents/logic-research-agent.md` - Logic research agent (adapted from ProofChecker, ~700 lines)
- `.claude/extensions/formal/agents/math-research-agent.md` - Math research agent (adapted from ProofChecker, similar size)
- `.claude/extensions/formal/agents/physics-research-agent.md` - Physics research agent (NEW, modeled after math-research-agent, smaller scope)

**Files to create (skills, adapted from ProofChecker)**:
- `.claude/extensions/formal/skills/skill-logic-research/SKILL.md` - Logic research skill wrapper
- `.claude/extensions/formal/skills/skill-math-research/SKILL.md` - Math research skill wrapper
- `.claude/extensions/formal/skills/skill-physics-research/SKILL.md` - Physics research skill wrapper (NEW)

**Files to create (context, 34 files adapted from ProofChecker)**:
- Logic domain (11): bilateral-propositions.md, bilateral-semantics.md, counterfactual-semantics.md, kripke-semantics-overview.md, lattice-theory-concepts.md, mereology-foundations.md, metalogic-concepts.md, proof-theory-concepts.md, spatial-domain.md, task-semantics.md, topological-foundations-domain.md
- Logic processes (4): modal-proof-strategies.md, proof-construction.md, temporal-proof-strategies.md, verification-workflow.md
- Logic standards (3): naming-conventions.md, notation-standards.md, proof-conventions.md
- Logic README (1)
- Math algebra (2): groups-and-monoids.md, rings-and-fields.md
- Math category-theory (6): basics.md, cauchy-completion.md, enriched-categories.md, lawvere-metric-spaces.md, monoidal-categories.md, profunctors.md
- Math foundations (1): dependent-type-theory.md
- Math lattice-theory (2): bilattice-theory.md, lattices.md
- Math order-theory (2): monoidal-posets.md, partial-orders.md
- Math topology (2): scott-topology.md, topological-spaces.md
- Math README (1)
- Physics dynamical-systems (1): dynamical-systems.md
- Physics README (1)

**Steps**:
1. Create the full directory tree under `.claude/extensions/formal/`
2. Create `manifest.json` following the template from research-002:
   - name: "formal", version: "1.0.0"
   - language: "formal"
   - provides: 3 agents, 3 skills, 3 context domains
   - merge_targets: EXTENSION.md (using new naming), index-entries.json
3. Create `EXTENSION.md` with:
   - Language routing section for `formal` language
   - Skill-to-agent mapping table
   - Sub-domain routing guidance (logic, math, physics keywords)
   - Context import references
4. Create `index-entries.json` with entries for all 34 context files
5. Adapt `logic-research-agent.md` from ProofChecker:
   - Remove ROAD_MAP.md reflection pattern
   - Remove ProofChecker-specific directory paths (Theories/, docs/)
   - Replace project-specific patterns with generic patterns
   - Keep Mathlib MCP tool integration
   - Keep 7-stage execution flow structure
   - Update context paths to extension-relative format
6. Adapt `math-research-agent.md` from ProofChecker with same adaptations
7. Create `physics-research-agent.md`:
   - Model after math-research-agent structure
   - Smaller scope matching minimal physics context
   - Include dynamical systems domain
   - Note future expansion areas in agent description
8. Adapt `skill-logic-research/SKILL.md` from ProofChecker:
   - Remove ProofChecker-specific validation
   - Keep agent delegation pattern
   - Update agent reference to extension path
9. Adapt `skill-math-research/SKILL.md` with same adaptations
10. Create `skill-physics-research/SKILL.md` modeled after math-research skill
11. Copy and adapt all 34 context files from ProofChecker:
    - For each file: read source, remove project-specific references, write to extension
    - Context files are domain knowledge and should be largely project-agnostic already
    - READMEs should be updated to describe extension context rather than ProofChecker context
12. Create or update README.md files for logic/, math/, physics/ directories

**Verification**:
- `find .claude/extensions/formal/ -type f | wc -l` shows ~40 files (34 context + 3 agents + 3 skills + 3 metadata)
- `jq '.' .claude/extensions/formal/manifest.json` parses successfully
- `jq '.' .claude/extensions/formal/index-entries.json` parses successfully
- `grep -r "ProofChecker" .claude/extensions/formal/` returns no results
- `grep -r "Theories/" .claude/extensions/formal/` returns no results
- All 3 agent files contain complete agent definitions with frontmatter
- All 3 skill files contain SKILL.md with proper delegation patterns

---

### Phase 8: Validation and Manifest Reconciliation [NOT STARTED]

**Status**: [NOT STARTED]
**Estimated effort**: 0.5 hours

**Objectives**:
1. Validate every manifest.json accurately reflects its extension's actual contents
2. Validate every index-entries.json parses correctly and references real files
3. Verify extension system integrity end-to-end
4. Verify no remaining claudemd-section.md references
5. Verify no project-specific references leaked through

**Files to check**:
- `.claude/extensions/lean/manifest.json` - Verify all provides arrays match actual files
- `.claude/extensions/latex/manifest.json` - Same
- `.claude/extensions/typst/manifest.json` - Same
- `.claude/extensions/z3/manifest.json` - Same
- `.claude/extensions/python/manifest.json` - Same
- `.claude/extensions/formal/manifest.json` - Same
- All 6 `index-entries.json` files - Verify entries reference existing files

**Steps**:
1. For each of the 6 remaining extensions (lean, latex, typst, z3, python, formal):
   a. Read manifest.json
   b. Verify each entry in `provides.agents` has a corresponding file in `agents/`
   c. Verify each entry in `provides.skills` has a corresponding directory in `skills/`
   d. Verify each entry in `provides.commands` has a corresponding file in `commands/`
   e. Verify each entry in `provides.scripts` has a corresponding file in `scripts/`
   f. Verify each entry in `provides.rules` has a corresponding file in `rules/`
   g. Verify each entry in `provides.context` has a corresponding directory in `context/`
   h. Verify `merge_targets.claudemd.source` points to `EXTENSION.md` and the file exists
   i. Verify `merge_targets.index.source` points to `index-entries.json` and the file exists
2. Run global searches for leaked project references:
   - `grep -r "ProofChecker" .claude/extensions/`
   - `grep -r "Logos" .claude/extensions/`
   - `grep -r "ModelChecker" .claude/extensions/`
   - `grep -r "claudemd-section" .claude/extensions/`
3. Verify the neovim/ extension directory no longer exists
4. Run `jq '.' .claude/extensions/*/manifest.json` to validate all JSON
5. Run `jq '.' .claude/extensions/*/index-entries.json` to validate all JSON
6. Produce a summary table of all extensions with file counts

**Verification**:
- All manifest.json files parse as valid JSON
- All index-entries.json files parse as valid JSON
- No manifest references non-existent files
- No leaked project-specific references
- neovim/ directory does not exist
- Total extension count: 6 (lean, latex, typst, z3, python, formal)
- Summary table shows correct file counts per extension

## Dependencies

Phase dependencies (linear with one parallel opportunity):
```
Phase 1 (rename) -> Phase 2 (remove neovim)
Phase 2 -> Phase 3 (lean)
Phase 2 -> Phase 4 (latex)     [parallel with 3, 5, 6]
Phase 2 -> Phase 5 (typst)     [parallel with 3, 4, 6]
Phase 2 -> Phase 6 (z3+python) [parallel with 3, 4, 5]
Phase 2 -> Phase 7 (formal)    [parallel with 3, 4, 5, 6]
Phases 3-7 -> Phase 8 (validation)
```

Phases 1 and 2 must execute sequentially (rename before remove). Phases 3-7 can execute in any order after Phase 2. Phase 8 must execute last.

## Testing and Validation

- [ ] All 6 claudemd-section.md files renamed to EXTENSION.md
- [ ] All 6 manifest.json files reference EXTENSION.md
- [ ] neovim/ extension directory removed
- [ ] Lean extension: 22 new files (2 commands + 2 scripts + 18 context)
- [ ] LaTeX extension: 7 new context files
- [ ] Typst extension: 9 new context files
- [ ] Z3 extension: 2 new context files
- [ ] Python extension: 3 new context files
- [ ] formal/ extension: ~40 files (3 metadata + 3 agents + 3 skills + 34 context)
- [ ] All manifest.json files validate against actual directory contents
- [ ] All index-entries.json files parse as valid JSON
- [ ] No project-specific references (ProofChecker, Logos, ModelChecker) in any extension
- [ ] No claudemd-section.md references remain
- [ ] Extension picker shows 6 extensions

## Artifacts and Outputs

- 6 renamed EXTENSION.md files (replacing claudemd-section.md)
- 6 updated manifest.json files
- 22 new lean extension files (commands, scripts, context)
- 7 new latex context files
- 9 new typst context files
- 2 new z3 context files
- 3 new python context files
- ~40 new formal/ extension files (agents, skills, context, metadata)
- 6 updated index-entries.json files
- 1 new formal/ index-entries.json file

Total new files: ~83
Total modified files: ~12
Total deleted: 3 (neovim/ extension)

## Rollback/Contingency

All changes are additive file operations (creates, renames, deletes) tracked by git. Rollback strategy:
- **Phase 1**: `git mv EXTENSION.md claudemd-section.md` for each extension, revert manifest changes
- **Phase 2**: Restore neovim/ from git history: `git checkout HEAD -- .claude/extensions/neovim/`
- **Phases 3-7**: Delete newly created files; no existing files are modified (only new files created and index-entries.json/manifest.json updated)
- **Full rollback**: `git checkout HEAD -- .claude/extensions/` restores the entire extensions directory to its pre-implementation state
