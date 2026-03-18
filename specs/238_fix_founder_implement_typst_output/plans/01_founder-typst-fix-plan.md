# Implementation Plan: Task #238

- **Task**: 238 - Fix founder extension /implement to generate typst files using templates
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: specs/238_fix_founder_implement_typst_output/reports/01_founder-typst-fix.md
- **Artifacts**: plans/01_founder-typst-fix-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The founder extension's /implement command generates markdown files but fails to produce typst/PDF output despite Phase 5 being documented in founder-implement-agent.md. The root cause is path resolution failures: the generated .typ files use relative imports (`#import "strategy-template.typ": *`) that fail when compiled from the `founder/` output directory. Additionally, the compilation command uses incorrect path mixing between the template directory and output location.

This plan fixes Phase 5 execution by generating self-contained typst files that inline necessary template functions, fixing the compilation command to use correct paths, and adding proper verification steps.

### Research Integration

Integrated findings from `specs/238_fix_founder_implement_typst_output/reports/01_founder-typst-fix.md`:
- Templates exist and are well-designed (verified)
- Phase 5 documented but not executing successfully
- Primary issue: relative import paths fail from `founder/` directory
- Secondary issues: compilation command path mixing, missing directory creation verification

## Goals & Non-Goals

**Goals**:
- Generate self-contained .typ files that compile without external imports
- Fix compilation command to produce PDFs in `founder/` directory
- Add proper error handling and verification steps
- Ensure Phase 5 executes reliably when typst is installed

**Non-Goals**:
- Redesigning typst template architecture
- Adding new report types
- Making PDF generation mandatory (markdown remains primary output)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Large inline templates bloat output | Low | Only inline required functions, not entire strategy-template |
| Typst syntax changes between versions | Low | Use stable Typst 0.11+ features only |
| PDF generation slows down implementation | Low | Phase 5 is optional; failures don't block task completion |

## Implementation Phases

### Phase 1: Fix Import Path Resolution [NOT STARTED]

**Estimated effort**: 1 hour

**Goal**: Modify founder-implement-agent.md Phase 5 to generate self-contained typst files instead of files with relative imports.

**Objectives**:
1. Replace relative import pattern with inline template content
2. Update the "Typst Content Generation Pattern" section
3. Document the self-contained approach

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Update Phase 5 content generation pattern

**Steps**:
1. Read the current Phase 5 specification (lines 235-337)
2. Replace the import-based pattern:
   ```typst
   #import "strategy-template.typ": *
   ```
   With inline pattern that embeds required template functions directly in generated file
3. Create minimal inline template section that includes:
   - Page setup (margins, fonts, headers/footers)
   - Essential typography rules
   - Key helper functions used (metric-callout, highlight-box, etc.)
4. Update the example generation pattern to show self-contained output

**Verification**:
- [ ] Generated .typ files contain no `#import` statements referencing external templates
- [ ] Generated .typ files include all necessary styling inline

---

### Phase 2: Fix Compilation Command [NOT STARTED]

**Estimated effort**: 30 minutes

**Goal**: Fix the typst compilation command to use correct paths.

**Objectives**:
1. Remove incorrect `cd "$template_dir"` that breaks relative paths
2. Use absolute paths consistently
3. Ensure output PDF goes to correct location

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Fix compilation commands in Phase 5

**Steps**:
1. Replace current compilation pattern:
   ```bash
   cd "$template_dir"
   typst compile "$(pwd)/$typst_file" "founder/${report_type}-${slug}.pdf"
   ```
   With correct pattern:
   ```bash
   # Compile from project root - no cd needed since file is self-contained
   typst compile "founder/${report_type}-${slug}.typ" "founder/${report_type}-${slug}.pdf"
   ```
2. Add explicit `--root .` flag if needed for any remaining relative references
3. Update error handling to capture compilation stderr for debugging

**Verification**:
- [ ] Compilation command runs from project root
- [ ] PDF output path is correct (`founder/{report-type}-{slug}.pdf`)

---

### Phase 3: Add Directory and Verification Steps [NOT STARTED]

**Estimated effort**: 30 minutes

**Goal**: Ensure proper directory creation and output verification.

**Objectives**:
1. Add explicit directory creation before typst file write
2. Add verification that PDF was generated and is non-empty
3. Update error messages with installation guidance

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Enhance Phase 5 verification

**Steps**:
1. Ensure directory creation step explicitly creates `founder/`:
   ```bash
   mkdir -p "founder"
   ```
2. Add typst installation guidance in error message:
   ```bash
   if ! command -v typst &> /dev/null; then
     echo "WARNING: typst not installed. Install with: nix profile install nixpkgs#typst"
     echo "Phase 5 skipped - markdown report available at ${output_path}"
     # Mark phase [PARTIAL]
     return
   fi
   ```
3. Add PDF verification with size check:
   ```bash
   if [ ! -s "founder/${report_type}-${slug}.pdf" ]; then
     echo "ERROR: PDF not generated or is empty"
     echo "Typst source preserved at: founder/${report_type}-${slug}.typ"
     # Mark phase [PARTIAL]
     return
   fi
   ```

**Verification**:
- [ ] Directory `founder/` is created before file writes
- [ ] Clear error messages when typst not installed
- [ ] PDF existence and size verified after compilation

---

### Phase 4: Update Skill Postflight [NOT STARTED]

**Estimated effort**: 30 minutes

**Goal**: Ensure skill-founder-implement properly handles Phase 5 output in postflight.

**Objectives**:
1. Verify postflight checks for typst artifacts
2. Update artifact reporting to include .typ and .pdf files when present
3. Ensure partial Phase 5 completion doesn't block task success

**Files to modify**:
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` - Update postflight verification

**Steps**:
1. Review current postflight artifact detection
2. Add checks for `founder/{report-type}-{slug}.typ` and `.pdf` files
3. Include typst artifacts in completion metadata if present
4. Ensure task completes successfully even if Phase 5 is partial (typst not installed)

**Verification**:
- [ ] Skill postflight reports typst artifacts when they exist
- [ ] Task completes successfully with only markdown output (Phase 5 partial)
- [ ] Metadata includes correct artifact paths

---

### Phase 5: Testing and Verification [NOT STARTED]

**Estimated effort**: 30 minutes

**Goal**: End-to-end verification that typst output works correctly.

**Objectives**:
1. Verify typst is available in environment
2. Test complete workflow: /market -> /plan -> /implement
3. Confirm PDF output in `founder/` directory

**Files to modify**:
- None (testing only)

**Steps**:
1. Check typst installation:
   ```bash
   command -v typst && typst --version
   ```
2. If typst is available, run test workflow:
   - Create test founder task
   - Run /plan on task
   - Run /implement on task
   - Verify outputs exist in `founder/` directory
3. Verify generated .typ file:
   - Contains no external imports
   - Compiles successfully standalone
4. If typst not available:
   - Document that verification requires typst installation
   - Mark test as deferred

**Verification**:
- [ ] Typst installation verified or documented as missing
- [ ] Complete workflow produces `founder/{type}-{slug}.pdf` (if typst available)
- [ ] Generated .typ file is self-contained and compiles independently

## Testing & Validation

- [ ] Phase 5 generates .typ file in `founder/` directory
- [ ] Generated .typ file contains no `#import` statements
- [ ] Generated .typ file compiles successfully with `typst compile`
- [ ] PDF output appears in `founder/` directory
- [ ] Skill postflight reports typst artifacts correctly
- [ ] Task completes successfully when typst is not installed (graceful degradation)

## Artifacts & Outputs

- `plans/01_founder-typst-fix-plan.md` (this file)
- `summaries/02_founder-typst-fix-summary.md` (after implementation)
- Modified: `.claude/extensions/founder/agents/founder-implement-agent.md`
- Modified: `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`

## Rollback/Contingency

If the fix introduces issues:
1. Revert changes to founder-implement-agent.md and skill-founder-implement/SKILL.md
2. Phase 5 failures are non-blocking (markdown output is primary), so worst case is status quo
3. Keep relative import pattern as fallback if inline approach proves problematic

## Success Criteria

- [ ] /implement on founder tasks generates .typ and .pdf files when typst is installed
- [ ] Output files appear in `founder/` directory at project root
- [ ] Generated typst files are self-contained (no external imports)
- [ ] Clear error message when typst not installed
- [ ] Task completion not blocked by Phase 5 issues
