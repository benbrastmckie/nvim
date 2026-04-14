# Teammate C (Critic) Research Findings: Task 428

**Role**: Critic -- gaps, contradictions, blind spots, and systemic issues
**Date**: 2026-04-14
**Scope**: Rules, context organization, CLAUDE.md accuracy, extension consistency, assumptions

---

## 1. Rules Critique

### 1.1 Direct Contradiction: Backup File Policy

**Severity**: HIGH | **Confidence**: HIGH

`rules/state-management.md` line 74 says:
> "4. Create backup of overwritten version"

`context/standards/git-safety.md` opens with:
> "Core Principle: Never create `.bak` files. Use git commits for safety."

These directly contradict each other. State-management.md tells agents to create backup files on inconsistency detection, while git-safety.md tells them never to create backup files. An agent following both rules simultaneously cannot know which to obey. This is the core of the "backup elimination" objective in task 428.

The contradiction is compounded by `context/repo/self-healing-implementation-details.md` which still contains shell script examples using `TODO.md.backup` and `state-template.json.backup`. The context document has never been updated to reflect the no-backup policy.

### 1.2 Broken Cross-Reference in artifact-formats.md

**Severity**: MEDIUM | **Confidence**: HIGH

`rules/artifact-formats.md` line 111 states:
> "Use count-aware format from `.claude/rules/state-management.md`"

But `rules/state-management.md` contains NO documentation of count-aware format. The actual documentation lives in `.claude/context/reference/state-management-schema.md` (which says "Use inline format for 1 artifact, multi-line list for 2+ artifacts"). The reference is simply wrong: it points to the rule that delegates to the schema, not to the schema itself.

### 1.3 Path Coverage Gaps in Rule Triggers

**Severity**: MEDIUM | **Confidence**: HIGH

Rule frontmatter path triggers are inconsistent:

| Rule | Path Pattern | Problem |
|------|-------------|---------|
| `error-handling.md` | `.claude/**/*` | Only triggers when editing .claude/ files -- but errors occur during specs/ operations too |
| `workflows.md` | `.claude/**/*` | Only triggers when editing .claude/ files -- but workflow should govern all command executions |
| `state-management.md` | `specs/**/*` | Correct -- state lives in specs/ |
| `git-workflow.md` | `["specs/**/*", ".claude/**/*"]` | Correctly covers both |
| `artifact-formats.md` | `specs/**/*` | Correct |
| `plan-format-enforcement.md` | `specs/**/plans/**` | Narrowest scope -- only triggers on plan files |

The error-handling and workflows rules should apply universally, not only when editing `.claude/` files. An agent running `/implement` that creates files in `specs/` would not have the error-handling rule in context unless it also happened to be editing `.claude/` files simultaneously.

### 1.4 Rules Are Aspirational, Not Enforceable

**Severity**: HIGH | **Confidence**: MEDIUM

The rule files describe desired behavior but provide no enforcement mechanism. Examples:

- `workflows.md` says "Every command follows this pattern" with a 3-step preflight/execute/postflight. But if a command skips preflight, nothing catches it. The rule is a style guide, not a constraint.
- `state-management.md` describes a "Two-Phase Update Pattern" but provides no atomic operation support. If an agent writes `state.json` then crashes before writing `TODO.md`, the "rule" to never partially update is violated with no recovery path defined here (recovery is scattered across error-handling.md and context files).
- `git-workflow.md` says "Do Not Commit" partial work, but there is no hook or validator enforcing this.

The only rule with any enforcement proximity is `plan-format-enforcement.md` (which functions as a checklist), but even this is self-verified by the agent creating the plan.

### 1.5 workflows.md is Dangerously Thin

**Severity**: MEDIUM | **Confidence**: HIGH

`rules/workflows.md` is only 31 lines (excluding frontmatter). It describes three phases and then says "For visual process diagrams, see .claude/context/reference/workflow-diagrams.md". This is a rule that entirely defers to a context document. If the context isn't loaded (it has no `always: true` and no agent condition), the rule is hollow. An agent reading only the rules/ directory would find almost no actionable content here.

---

## 2. Context Organization Critique

### 2.1 Deprecated File Still Indexed and Sized

**Severity**: HIGH | **Confidence**: HIGH

`context/orchestration/orchestrator.md` (873 lines) is marked **DEPRECATED** at the top since 2026-01-19 with a note to use `orchestration-core.md` and `orchestration-reference.md` instead. Yet `index.json` still lists it with:
- `line_count: 876` (stale count)
- Load condition: `agents: ["meta-builder-agent"], task_types: ["meta"]`

This means every `/meta` command loads an 873-line deprecated file containing outdated patterns. This is the highest-priority dead weight in the context system.

### 2.2 index.json Violates Its Own Schema

**Severity**: MEDIUM | **Confidence**: HIGH

`index.json` has `"version": null`.
`index.schema.json` requires `"version"` to be a string matching pattern `^[0-9]+\\.[0-9]+\\.[0-9]+$` (semver).
`null` is not a string and does not match semver. The index file violates the schema it is supposed to conform to.

### 2.3 Duplicate Taxonomy: processes/ vs workflows/

**Severity**: MEDIUM | **Confidence**: HIGH

Both directories contain workflow documentation:
- `processes/research-workflow.md` (623 lines): "Detailed research workflow for conducting research"
- `workflows/command-lifecycle.md` (451 lines): Also describes research phase transitions

- `processes/planning-workflow.md`, `processes/implementation-workflow.md`: Detailed workflows
- `workflows/preflight-postflight.md` (589 lines): Also covers preflight/postflight

The distinction between "processes" (specific workflows for research/plan/implement) and "workflows" (general lifecycle patterns) is not obvious from the naming or the README. A meta-builder agent choosing where to place a new workflow document has no clear guidance.

### 2.4 Duplicate Taxonomy: orchestration/ vs architecture/

**Severity**: MEDIUM | **Confidence**: HIGH

- `orchestration/architecture.md` (757 lines): "System architecture"
- `architecture/system-overview.md` (492 lines): "High-level agent system architecture overview"

Two "architecture overview" files exist in different directories. Additionally:
- `docs/architecture/system-overview.md` (291 lines): A third system overview for users/developers

Three files named system-overview or architecture covering the same subject domain with different depths and audiences, but no clear naming convention to distinguish them.

### 2.5 Duplicate Pattern: templates/thin-wrapper-skill.md vs patterns/thin-wrapper-skill.md

**Severity**: LOW | **Confidence**: HIGH

Two files with the same name in different directories:
- `templates/thin-wrapper-skill.md` (273 lines)
- `patterns/thin-wrapper-skill.md` (204 lines)

Different sizes suggests divergent content. Unclear which is canonical. An agent generating a new thin-wrapper skill would load context from one but may not know about the other.

### 2.6 Orphaned Directory: schemas/

**Severity**: LOW | **Confidence**: HIGH

`context/schemas/` contains two non-markdown files (`frontmatter-schema.json`, `subagent-frontmatter.yaml`). The directory has ZERO `.md` files. The README says "schemas/ - JSON/YAML schemas for validation" but since the index only indexes `.md` files, schemas/ is effectively invisible to the context discovery system. Neither file appears in `index.json`.

### 2.7 Single-File Directories Are Not Justified

**Severity**: LOW | **Confidence**: HIGH

- `context/guides/` contains exactly 1 file (`extension-development.md`)
- `context/troubleshooting/` contains exactly 1 file (`workflow-interruptions.md`)

Single-file directories add navigation overhead without organizational benefit. The extension-development guide could live in `architecture/` or `reference/`, and workflow-interruptions could live in `workflows/`. The directories exist as category placeholders that never grew beyond 1 entry.

### 2.8 Preflight/Postflight Pattern Triple Coverage

**Severity**: MEDIUM | **Confidence**: HIGH

Three separate files cover preflight/postflight:
1. `orchestration/preflight-pattern.md` (217 lines)
2. `orchestration/postflight-pattern.md` (336 lines)
3. `workflows/preflight-postflight.md` (589 lines)

Total: 1,142 lines of preflight/postflight documentation across 3 files. Any update to this pattern would need to be applied consistently across all three.

### 2.9 Checkpoint System Has Both a Directory AND a Patterns File

**Severity**: LOW | **Confidence**: HIGH

- `checkpoints/` directory contains 4 files (gate-in, gate-out, commit, README): 391 total lines
- `patterns/checkpoint-execution.md` (252 lines): Also describes checkpoint execution

These represent two overlapping approaches to documenting the same concept. The README in checkpoints/ says "checkpoint system documentation index" but `patterns/checkpoint-execution.md` also documents checkpoint execution.

### 2.10 Top-Level Loose Files Are Inconsistent

**Severity**: LOW | **Confidence**: HIGH

Two `.md` files exist at the root of `context/` rather than in subdirectories:
- `routing.md` (43 lines): "Quick routing reference"
- `validation.md` (46 lines): "Validation quick reference"

But `orchestration/routing.md` (777 lines) covers routing in depth. Having a "quick reference" version at root implies it should be loadable for any agent needing quick routing info, but it only has `task_types: ["meta"]` in its load conditions. It's neither a proper root-level always-loaded document nor properly placed in a subdirectory.

---

## 3. CLAUDE.md Accuracy Issues

### 3.1 code-reviewer-agent Has No Skill Mapping

**Severity**: MEDIUM | **Confidence**: HIGH

The "Agents" table in CLAUDE.md lists `code-reviewer-agent` with purpose "Code quality assessment and review". But the "Skill-to-Agent Mapping" table above it does NOT list any skill that delegates to code-reviewer-agent. The `/review` command exists and uses model:opus, but it appears to execute inline (not via a skill->agent delegation). This is an architectural inconsistency: other commands delegate to skills which delegate to agents, but `/review` apparently bypasses the skill layer entirely.

### 3.2 CLAUDE.md References @.claude/README.md in Header

**Severity**: LOW | **Confidence**: HIGH

The opening paragraph says "For comprehensive documentation, see @.claude/README.md". This file exists (259 lines) and is valid. However, this is an ambiguous @ reference: does it mean the file is auto-loaded as context, or is it just a navigation note? The README is not listed in any context/index.json entry, so it won't be auto-loaded as context for agents.

### 3.3 Skill-to-Agent Mapping Lists "skill-planner" Separately

**Severity**: LOW | **Confidence**: MEDIUM

The CLAUDE.md documents `skill-planner -> planner-agent (opus)` as a core skill. The file exists at `skills/skill-planner/SKILL.md`. The mapping is accurate. However, the CLAUDE.md description of the skill table uses model column "opus" for planner but "-" (default) for implementer, which is correct. No issue here technically, but the pattern of noting model "opus" specifically in CLAUDE.md while agents declare their own model in frontmatter creates redundancy: if someone changes the planner-agent's model frontmatter, CLAUDE.md would be stale.

### 3.4 Stale Summary: "94+ context files"

**Severity**: LOW | **Confidence**: HIGH

CLAUDE.md says "94+ context files" in the task 428 description (this is in TODO.md/state.json, referencing task text). The actual count is 96 `.md` files (via find). This is slightly stale but close. More significantly, it says "15 extensions" but the actual count is 14 (`ls .claude/extensions/ | grep -v README.md` = 14 extension directories). The README.md in extensions/ is not an extension.

### 3.5 Context Import Section References Not Always Loaded

**Severity**: MEDIUM | **Confidence**: HIGH

CLAUDE.md has:
```
## Context Imports

Core context (always available):
- @.claude/context/repo/project-overview.md
- @.claude/context/meta/meta-guide.md
```

These files DO have `"always": true` in index.json. So the claim is technically accurate. However: `index.json` has `"version": null` (schema violation noted above) which could cause tools that validate the schema to fail, potentially preventing `always` loading from functioning correctly.

---

## 4. Extension Consistency Issues

### 4.1 memory Extension Has No agents Field, No rules Field

**Severity**: MEDIUM | **Confidence**: HIGH

Most extensions have both `provides.agents` and `provides.rules`. The `memory` extension has:
- `provides.agents`: absent (not just empty, the key doesn't exist)
- `provides.rules`: absent

While this may be intentional (memory is a utility extension, not a domain extension), the inconsistent schema makes automated validation harder. Tools checking `manifest.provides.agents` would need nil-safety checks.

### 4.2 Two Extensions Have task_type: null

**Severity**: MEDIUM | **Confidence**: HIGH

Both `filetypes` and `memory` have `"task_type": null`. But both have routing tables (filetypes has 6 routing entries for `filetypes:*` sub-types, memory has `"memory"` routing entries). This creates a contradiction: how does the system route tasks with `task_type: null`? The routing tables suggest these extensions DO handle task types, but the `task_type` field says they don't.

The routing in `filetypes` uses `"filetypes"` as the key, so presumably the actual task_type would be `"filetypes"` -- but `manifest.task_type: null` signals to the loader that this extension provides no task type. This is either a loader convention that needs documentation or a genuine schema inconsistency.

### 4.3 present Extension Has No rules

**Severity**: LOW | **Confidence**: HIGH

`present/manifest.json` has `provides.rules: []` (empty array). This is different from memory/filetypes which omit the key. An empty array is the correct "none" value, but if the manifest schema requires rules to be present, the `memory` extension would fail validation. There's no consistent convention for "I have no rules" across extensions.

### 4.4 lean Extension Has Sub-Type Routing Not Documented in CLAUDE.md

**Severity**: LOW | **Confidence**: MEDIUM

The lean extension manifests routing for `lean4:lake` and `lean4:version` sub-types, but CLAUDE.md says only "Extension task types use bare values (e.g., `neovim`) or compound values (e.g., `present:grant`) for sub-routing." The specific sub-types for lean (`lean4:lake`, `lean4:version`) are not mentioned as examples and users would need to read the manifest directly to discover them. Discovery of sub-types requires reading 14 manifests -- there's no consolidated sub-type registry.

### 4.5 opencode_json merge_target Missing from lean Extension

**Severity**: LOW | **Confidence**: HIGH

Both `nvim` and `python` extensions have `merge_targets.opencode_json`. The `lean` extension also has it. But `memory` does NOT have `opencode_json` as a merge target. This inconsistency (memory-specific omission) may be intentional if memory is Claude-only, but it's undocumented.

---

## 5. Challenged Assumptions

### 5.1 "15 Subdirectories" Is Not Actually Flat

The README says the structure was "flattened" in Task 288, but 15 subdirectories with 96 files averaging ~6.4 files per directory is not flat -- it's a moderately deep tree. "Flattening" from a previous deeper structure doesn't mean the current structure is flat. The taxonomy has real boundary ambiguity problems (see sections 2.3-2.9).

### 5.2 index.json Approach Does Not Scale

With 96 entries today, the index is a 500+ line JSON file that every agent must query to discover context. If extensions grow to 30 (doubling from 15), and each adds ~10 context entries, the index would reach ~300+ entries and ~1500+ lines. The index.json approach has no pagination, no lazy loading of extension entries, and no TTL/invalidation mechanism. The "merge" approach (extension entries merged into the main index at load time) means a corrupted extension index could silently break the entire context discovery system.

### 5.3 Gate IN / Gate OUT Adds Ceremony Without Catching Real Errors

The checkpoint pattern is documented across 3 separate files totaling ~1,142 lines. But what does it actually prevent?
- GATE IN reads state and validates the task exists: an agent could do this inline
- GATE OUT updates status and commits: an agent could do this inline

There is no external enforcer. If a skill skips GATE IN, nothing triggers. The pattern functions as documentation of expected behavior, not as an architectural constraint. It's ceremony that evolved into documentation, but it requires agent discipline to function, which is the same requirement as "just follow the workflow guide."

### 5.4 Team Mode Skills Are Thin Orchestration Wrappers

`skill-team-research`, `skill-team-plan`, `skill-team-implement` are described as distinct skills. But their primary function is spawning N teammates and synthesizing their output -- which is an orchestration pattern, not domain logic. These could be flags handled by the orchestrator (`--team` is already a flag that routes to these skills). Having them as separate skills adds 3 more entries to the skill registry without adding distinct behavioral capabilities.

### 5.5 .syncprotect Is Documented Nowhere Except sync.lua Code

The `load_syncprotect` function in sync.lua (lines 379-407) reads `{project_dir}/{base_dir}/.syncprotect` where `base_dir` is `.claude`. This means the expected file location is `.claude/.syncprotect`. But task 428's description explicitly says it should be at the project root (e.g., `nvim/.syncprotect`), not inside `.claude/` which gets replaced during updates.

The code puts the file inside `.claude/` which gets overwritten on sync. This is a functional bug: creating a `.syncprotect` file at the documented location (`.claude/.syncprotect`) makes it a file that gets synced/overwritten, potentially defeating its purpose. There is zero documentation in any context file, CLAUDE.md, README.md, or rules about `.syncprotect` -- users must read sync.lua source code to understand the feature.

### 5.6 No Testing/Validation Mechanism for the Agent System

There is `scripts/validate-index.sh` and `scripts/check-extension-docs.sh` (referenced in CLAUDE.md), but:
- No test for whether rule path patterns actually match files they're intended for
- No test for whether skills correctly delegate to their documented agents
- No test for whether index.json conforms to index.schema.json (which it currently doesn't -- version: null)
- No integration test for a complete research/plan/implement lifecycle
- No way to detect when a context file is loaded that contains only deprecated instructions

The system documents self-healing and error recovery extensively but has no automated validation that the system itself is healthy.

---

## 6. Unanswered Questions

1. **When .syncprotect is inside .claude/, does a sync operation overwrite it?** If sync replaces `.claude/` contents, then a `.syncprotect` at `.claude/.syncprotect` would itself be overwritten -- making the feature self-defeating. Needs verification against sync.lua's file list scanning logic.

2. **What happens when both always:true AND agent conditions exist in load_when?** The query in CLAUDE.md uses `or` logic, so always:true would include the file regardless. But the `checkpoints/README.md` entry has `always: true` alongside empty arrays for agents/tasks/commands -- this redundant structure is fine but inconsistent with entries that only have `always: true`.

3. **Who rebuilds index.json when a new context file is added?** The README says "rebuilt by loader" but there's no clear trigger. The `core-index-entries.json` file (94 entries) suggests the loader appends to it. If someone manually adds a context file without updating index.json, it's effectively invisible to the system.

4. **How do users discover available sub-types for extensions?** The lean extension has `lean4:lake` and `lean4:version` sub-types. There's no registry, no help command, no consolidated list. Users must read 14 manifest files to find all available task types and sub-types.

5. **Why does orchestration/orchestrator.md (deprecated) still load for meta-builder-agent?** The file itself says to use orchestration-core.md and orchestration-reference.md instead. But it's still indexed and will be loaded for every /meta command, adding 873 lines of deprecated content to the agent's context.

6. **Is the git-workflow rule actually preventing bad commits?** The rule says "Do Not Commit partial work" but Claude Code's git hooks are separate from rule files. The rule only works if agents read and follow it -- there's no enforcement outside of agent behavior.

7. **What's the upgrade path when agent system format changes?** When frontmatter formats evolved (see frontmatter.md at 705 lines), were all existing agents/skills updated? There's no migration guide, no version field in skill/agent files, and no tooling to detect format drift.

---

## 7. Priority Issues (Ranked by Impact)

| Priority | Issue | Impact | Confidence |
|----------|-------|--------|------------|
| P1 | State-management rule says "create backup" but git-safety says "never create .bak files" -- direct contradiction governing all file operations | Agents cannot reliably follow both; agents generating backup files pollute the repo | HIGH |
| P2 | .syncprotect is placed inside .claude/ by sync.lua but .claude/ is overwritten during sync -- .syncprotect protection defeats itself | Functional bug; users who create .syncprotect get a false sense of protection | HIGH |
| P3 | orchestrator.md (deprecated, 873 lines) still loads for every /meta command | Wastes significant context budget on outdated patterns for every meta task | HIGH |
| P4 | index.json has "version": null which violates index.schema.json | Breaks schema validation; automated tools checking index validity would reject it | MEDIUM |
| P5 | 18 context entries reachable only by task_type (all "meta") -- no agent condition means they require active task_type querying | If orchestrator queries by agent name only (not task_type), 18 files are never loaded | MEDIUM |
| P6 | artifact-formats.md cross-references state-management.md for count-aware format, but the content is in state-management-schema.md | Agents following the reference find no content; stale pointer | MEDIUM |
| P7 | code-reviewer-agent has no skill in the skill-to-agent mapping (missing skill layer) | Architectural inconsistency; /review bypasses the delegation pattern | MEDIUM |
| P8 | processes/ and workflows/ directories have unclear taxonomy boundaries | Meta-builder agents placing new workflow docs may choose wrong directory | MEDIUM |
| P9 | thin-wrapper-skill.md exists in both templates/ and patterns/ with different sizes | Divergent canonical references; potential inconsistency in generated skills | LOW |
| P10 | schemas/ directory (context/schemas/) has 2 JSON/YAML files not indexed by index.json | Schema files invisible to context discovery; effectively orphaned | LOW |

---

## 8. Confidence Summary

| Finding | Confidence | Basis |
|---------|------------|-------|
| Backup policy contradiction | HIGH | Direct text comparison of two files |
| .syncprotect self-defeating location | HIGH | Code analysis of sync.lua load_syncprotect function |
| Deprecated orchestrator.md still indexed | HIGH | index.json entry + file self-declaration |
| index.json violates schema | HIGH | Schema requires semver string; index has null |
| Cross-reference error in artifact-formats | HIGH | State-management.md has no count-aware format docs |
| 18 task_type-only entries | HIGH | jq query result; all use task_type "meta" |
| code-reviewer-agent has no skill | HIGH | Skill directory listing + CLAUDE.md table comparison |
| Taxonomy confusion processes/ vs workflows/ | MEDIUM | Content comparison; boundaries are genuinely unclear |
| Team mode skills as orchestration wrappers | MEDIUM | Behavioral analysis; they could be orchestrator flags |
| No validation mechanism for agent system | HIGH | No test files found; validate-index.sh validates index only |
