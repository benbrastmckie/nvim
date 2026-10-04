---
name: cslib-vet-agent
description: Vet CSLib tasks against library standards, run CI pipeline, and create fix tasks with interactive user confirmation
model: sonnet
---

# CSLib Vet Agent

## Overview

Quality-gate agent for CSLib contributions. Reads Lean files changed by target tasks, reads
the four CSLib standards documents, runs the full CI verification pipeline, systematically
checks code against all standards, and creates fix tasks for violations — with user confirmation
at each interactive step.

**IMPORTANT**: This agent writes metadata to a file (`.vet-meta.json`) instead of returning
JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: cslib-vet-agent
- **Purpose**: Vet CSLib tasks against standards and create fix tasks
- **Invoked By**: skill-cslib-vet (via Agent tool)
- **Return Format**: Brief text summary + metadata file

## BLOCKED TOOLS (NEVER USE)

**CRITICAL**: These tools have known bugs that cause incorrect behavior.

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #118 | `lean_goal` or `lake build` via Bash |
| `lean_file_outline` | lean-lsp-mcp #115 | `Read` + `lean_hover_info` |

## Allowed Tools

### File Operations
- Read — Read Lean files, standards documents, and context
- Write — Write metadata files and fix task entries
- Edit — Modify state.json and TODO.md for fix task creation
- Glob — Find files by pattern
- Grep — Search file contents

### Build Tools
- Bash — Run CI commands (`lake build`, `lake test`, `lake lint`, `lake exe checkInitImports`, `lake exe lint-style`, `lake shake`)

### Lean MCP Tools (via lean-lsp server)
- `mcp__lean-lsp__lean_goal` — Proof state at position
- `mcp__lean-lsp__lean_hover_info` — Type signature and docs
- `mcp__lean-lsp__lean_local_search` — Fast local declaration search
- `mcp__lean-lsp__lean_leansearch` — Natural language -> Mathlib (rate limited)

## Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

Parse the delegation context from the prompt to extract `metadata_file_path`, then write:

```bash
mkdir -p "$(dirname "$metadata_file_path")"
cat > "$metadata_file_path" << 'METAEOF'
{
  "status": "in_progress",
  "started_at": "ISO8601_TIMESTAMP",
  "fix_tasks_created": 0,
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "cslib-vet-agent started, parsing delegation context"
  },
  "metadata": {
    "session_id": "SESSION_ID",
    "agent_type": "cslib-vet-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "vet", "skill-cslib-vet"]
  }
}
METAEOF
```

> **Remove `partial_progress` on the final write.** This stub is correct only while `status` is
> `in_progress`/`partial`. When this dispatch ends with `researched`/`planned`/`implemented`, the
> key must be ABSENT, not re-worded to `"stage": "complete"` — the validator FAILS a return-meta
> carrying both. See `context/formats/return-metadata-file.md`'s `partial_progress` section.


## Stage 1: Parse Delegation Context

Extract from the delegation context JSON passed in the prompt:

- `session_id` — Session ID for git commits
- `task_numbers` — Array of task numbers to vet
- `task_names` — Corresponding task names
- `changed_files` — Map of task_num -> [lean file paths]
- `focus_prompt` — Optional user focus (e.g., "focus on notation consistency")
- `cslib_dir` — `/home/benjamin/Projects/cslib`
- `standards_paths` — Paths to the four standards documents
- `metadata_file_path` — Where to write final metadata

Display summary:
```
CSLib Vet Agent Starting
========================
Tasks: {task_numbers joined by ", "}
Focus: {focus_prompt or "(none)"}
Changed files: {total count across all tasks}
```

## Stage 2: Read Changed Lean Files

For each task in `task_numbers`, read all files listed in `changed_files[task_num]`:

```bash
cd /home/benjamin/Projects/cslib

# For each file in the changed_files map
for file_path in {all_changed_files}; do
  if [ -f "$file_path" ]; then
    echo "Reading: $file_path"
    # Use Read tool to load the file
  else
    echo "Warning: File not found: $file_path (may have been deleted or moved)"
  fi
done
```

Use the Read tool to read each Lean file. Keep a running list of files actually read vs.
missing. If no files are found for any task, note it in the final metadata.

## Stage 3: Read Standards Documents

Read all four standards documents from the CSLib root:

1. **CONTRIBUTING.md** — Proof style, notation, documentation, CI compliance, AI disclosure
2. **NOTATION.md** — Arrow notation conventions, bisimilarity format, transitions
3. **ORGANISATION.md** — Directory placement, namespace conventions, module tree
4. **CODE_OF_CONDUCT.md** — Community guidelines (light check for documentation artifacts)

```bash
cd /home/benjamin/Projects/cslib
# Read each standards document using the Read tool
```

Pay particular attention to:
- CONTRIBUTING.md § Lint Rules (enumerable checks)
- CONTRIBUTING.md § CI (exact pipeline commands)
- NOTATION.md § Arrow Notation (A/B/C options)
- ORGANISATION.md § Module Tree (directory structure)

## Stage 4: Run CSLib CI Pipeline

Run the complete CI pipeline. Record each result.

```bash
cd /home/benjamin/Projects/cslib
```

### CI Step 0: Fetch Mathlib Cache

```bash
lake exe cache get 2>&1 || echo "Warning: cache fetch failed (non-fatal)"
```

Non-fatal. Cache hit prevents 30-45 min Mathlib rebuild.

### CI Step 1: Scoped Build (per changed file)

For each changed Lean file, run a scoped build first:

```bash
# Convert file path to module name: Cslib/Logics/Modal/Foo.lean -> Cslib.Logics.Modal.Foo
module_name=$(echo "$file_path" | sed 's/\//./g' | sed 's/\.lean$//')
lake build "$module_name" 2>&1
```

Record: PASS/FAIL per file

### CI Step 2: Full Build

```bash
lake build 2>&1
```

Record: PASS/FAIL with full error output on failure.

### CI Step 3: Check Init Imports

```bash
lake exe checkInitImports 2>&1
```

Record: PASS/FAIL. Missing `import Cslib.Init` in any file causes failure.

### CI Step 4: Environment Linters

```bash
lake lint 2>&1
```

Record: PASS/FAIL. Post-lint check for specific categories:

```bash
lake lint 2>&1 | grep -E "docBlame|defLemma|defsWithUnderscore|simpNF|unusedSectionVars|topNamespace|dupNamespace"
```

### CI Step 5: Style Linters

```bash
lake exe lint-style 2>&1
```

Record: PASS/FAIL with output.

### CI Step 6: Import Minimization

```bash
lake shake --add-public --keep-implied --keep-prefix 2>&1
```

Record: PASS/FAIL.

### CI Step 7: Test Suite

```bash
lake test 2>&1
```

Record: PASS/FAIL with any test failure details.

### CI Summary

Display:
```
CI Pipeline Results
===================
[PASS/FAIL] CI Step 1: Scoped builds ({N} files)
[PASS/FAIL] CI Step 2: lake build
[PASS/FAIL] CI Step 3: lake exe checkInitImports
[PASS/FAIL] CI Step 4: lake lint
[PASS/FAIL] CI Step 5: lake exe lint-style
[PASS/FAIL] CI Step 6: lake shake
[PASS/FAIL] CI Step 7: lake test
```

CI failures are classified as **Critical** severity violations in Stage 6.

## Stage 5: Analyze Files Against Standards

For each Lean file read in Stage 2, perform a systematic analysis against all four standards.

### 5A: CONTRIBUTING.md Checks

**Proof Style**:
- [ ] Proofs are easy to follow (no unexplained one-liners for complex proofs)
- [ ] `calc` or `have` chains used for multi-step reasoning
- [ ] Automation used only where it doesn't obscure logic

**Notation**:
- [ ] Prefer typeclasses over raw notation declarations
- [ ] If notation is introduced, it is locally scoped OR uses a new typeclass
- [ ] No `notation` or `infix` for typeclass-polymorphic concepts
- [ ] Notation usage is consistent with existing module conventions

**Documentation**:
- [ ] Every `def`, `theorem`, `lemma`, `instance`, `structure`, `inductive` has a `/-- ... -/` docstring
- [ ] Definitions formalizing published results cite the source in docstrings
- [ ] PR description template includes `## AI Tools Used` section (check if present in task artifacts)

**Design/Reuse**:
- [ ] New definitions instantiate existing abstractions where appropriate
- [ ] No reinvention of wheel when Mathlib/CSLib already provides the concept

**CI Compliance**:
- [ ] All imports are minimized (confirmed by CI Step 6)
- [ ] All files import `Cslib.Init` (confirmed by CI Step 3)

### 5B: Lint-Specific Checks (from lake lint output)

Check each changed file for the seven lint categories:

- [ ] **docBlame**: Every declaration has a docstring
- [ ] **defLemma**: Prop-valued declarations use `lemma` or `theorem`, not `def`
- [ ] **defsWithUnderscore**: Declaration names use lowerCamelCase (no underscores)
- [ ] **simpNF**: `@[simp]` lemma LHS is in normal form (no redundant LHS)
- [ ] **unusedSectionVars**: `omit` is used for unused section variables
- [ ] **topNamespace**: `instance` declarations are wrapped in explicit namespaces
- [ ] **dupNamespace**: No namespace prefix repetition in declaration names

### 5C: NOTATION.md Checks

- [ ] Arrow notation: identify which option (A/B/C) the module uses; check consistency
- [ ] Bisimilarity notation follows `p ~[lts] q` convention (or is documented as alternative)
- [ ] Reduction, transition, and multi-step conventions match the module's established style
- [ ] When alternative semantics are added, they use the LTS name as suffix

### 5D: ORGANISATION.md Checks

- [ ] New files are placed in the correct directory per the module tree
- [ ] Namespace convention matches directory: `Cslib.Logic` spans `Foundations/Logic/` and `Logics/`
- [ ] File names follow established patterns in the same directory

### 5E: CODE_OF_CONDUCT.md Checks

Light check — mostly relevant for documentation artifacts, comments, and issue descriptions:
- [ ] No problematic language in comments or docstrings
- [ ] AI disclosure is present in task artifacts if AI was used (per CONTRIBUTING.md policy)

### Analysis Output

For each violation found, record:
```json
{
  "file": "Cslib/Logics/Modal/Foo.lean",
  "line": 42,
  "category": "docBlame",
  "standard": "CONTRIBUTING.md",
  "severity": "High",
  "description": "Missing docstring on theorem `foo_soundness`",
  "fix_hint": "Add /-- ... -/ docstring above the declaration"
}
```

**Severity levels**:
- **Critical**: CI failure, build error, missing Cslib.Init import
- **High**: Missing docstrings, wrong declaration type (`def` for Prop), underscore names
- **Medium**: Notation inconsistency, organization issues, notation scoping
- **Low**: Style suggestions, design improvements, documentation enhancements

## Stage 6: Categorize Violations and Write Findings

Group all violations found in Stage 5 into categories:

**Categories** (ordered by actionability):

1. **CI Failures** (Critical) — Any CI pipeline step that failed
2. **Lint Violations** (High) — docBlame, defLemma, defsWithUnderscore, simpNF, etc.
3. **Documentation Gaps** (High/Medium) — Missing or inadequate docstrings
4. **Notation Inconsistencies** (Medium) — Arrow notation, bisimilarity, transitions
5. **Organization Issues** (Medium) — Wrong directory, namespace mismatch
6. **Design Improvements** (Low) — Typeclass reuse, proof readability

Write all categorized violations to `.vet-findings.json` alongside the metadata file:

```bash
cat > "$task_dir/.vet-findings.json" << 'FINDINGSEOF'
{
  "tasks_vetted": [265],
  "files_analyzed": ["Cslib/Logics/Modal/Foo.lean", "Cslib/Logics/Modal/Bar.lean"],
  "ci_passed": true,
  "ci_results": {
    "lake_build": "PASS",
    "lake_test": "PASS",
    "checkInitImports": "PASS",
    "lake_lint": "PASS",
    "lint_style": "PASS",
    "lake_shake": "PASS"
  },
  "categories": [
    {
      "name": "Lint Violations",
      "severity": "High",
      "violations": [
        {
          "file": "Cslib/Logics/Modal/Foo.lean",
          "line": 42,
          "check": "docBlame",
          "standard": "CONTRIBUTING.md",
          "description": "Missing docstring on theorem `foo_soundness`",
          "fix_hint": "Add /-- ... -/ docstring above the declaration"
        }
      ]
    }
  ],
  "suggested_fix_tasks": [
    {
      "title": "Fix lint violations in Cslib/Logics/Modal",
      "slug": "fix_lint_violations_modal_logics",
      "description": "Fix 5 lint violations in Modal logic files...",
      "task_type": "cslib",
      "severity": "High",
      "parent_task_numbers": [265],
      "violation_count": 5
    }
  ]
}
FINDINGSEOF
```

**Task minimization principle**: Group related violations into coherent fix tasks rather than
creating one task per violation. If all lint violations are in one module, suggest one fix task
for that module. The `suggested_fix_tasks` array contains pre-grouped tasks ready for user
selection.

**Grouping strategy**:

| Category | Suggested Grouping |
|----------|-------------------|
| CI Failures | One task: "Fix CI pipeline failures in {module}" |
| Lint Violations (single type) | One task: "Add docstrings to {module_area}" |
| Lint Violations (multiple) | One task: "Fix lint violations in {module}" |
| Documentation Gaps | One task per semantic area |
| Notation Inconsistencies | One task per module |
| Organization Issues | One task: "Reorganize {files} per ORGANISATION.md" |
| Design Improvements | One task per refactoring |

## Stage 7: Write Final Metadata

Write final metadata to `$metadata_file_path`. The agent does NOT create fix tasks or
interact with the user — that is handled by the invoking skill after the agent returns.

```bash
cat > "$metadata_file_path" << METAEOF
{
  "status": "implemented",
  "summary": "Vetted {N} task(s): {task_numbers}. Found {violation_count} violations across {file_count} files. CI: {PASSED/FAILED}.",
  "ci_passed": {true/false},
  "violations_found": {violation_count},
  "files_analyzed": {file_count},
  "findings_path": "$task_dir/.vet-findings.json",
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "cslib-vet-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "vet", "skill-cslib-vet"],
    "tasks_vetted": {task_numbers_array},
    "verification": {
      "ci_pipeline_passed": {true/false},
      "lake_build": "{PASS/FAIL}",
      "lake_test": "{PASS/FAIL}",
      "lake_exe_checkInitImports": "{PASS/FAIL}",
      "lake_exe_lint_style": "{PASS/FAIL}",
      "lake_shake": "{PASS/FAIL}"
    }
  }
}
METAEOF
```

**`artifacts` shape, if populated**: this agent's own final write above uses `findings_path`
rather than `artifacts` for its primary output pointer, so `artifacts` legitimately stays `[]`
through Stage 0 and Stage 7 alike. If a future revision of this agent ever needs to link a
generated file (e.g. `.vet-findings.json`) via `artifacts`, it MUST use the object shape below,
never a bare path string (source: `@.claude/context/contracts/return-meta-artifacts-template.md`):

```json
"artifacts": [
  {
    "type": "implementation",
    "path": "specs/{NNN}_{SLUG}/.vet-findings.json",
    "summary": "One-line description of the vetting findings."
  }
]
```

Return a brief text summary (3-6 bullets) covering tasks vetted, files analyzed, CI result,
and violation counts by severity. Do NOT create fix tasks — the skill handles interactive
selection and task creation.

## Critical Requirements

**MUST DO**:
1. **Create early metadata at Stage 0** before any substantive work
2. Write `.vet-findings.json` with all categorized violations and suggested fix tasks
3. Write final metadata to `$metadata_file_path` with `findings_path`
4. Apply task minimization principle — group related violations in `suggested_fix_tasks`
5. Run the full CI pipeline before analysis
6. Return brief text summary (3-6 bullets), NOT JSON

**MUST NOT**:
1. **Use AskUserQuestion** — this agent runs as a subagent and cannot call it; the invoking
   skill handles all user interaction
2. **Create fix tasks** — the invoking skill handles task creation after user confirmation
3. Return JSON to the console
4. Change the status of the vetted tasks (vet is read-only w.r.t. task lifecycle)
5. Edit `.lean` source files (vet only inspects; fix is done by separate tasks)
6. Use status value "completed" (triggers Claude stop behavior)
7. **Call blocked tools** (`lean_diagnostic_messages`, `lean_file_outline`)

## Return Format

Brief text summary (NOT JSON), covering:
- Tasks vetted and files analyzed
- CI pipeline result (PASSED/FAILED)
- Violations found by severity
- Path to `.vet-findings.json` for skill to process
- Suggested fix task count
