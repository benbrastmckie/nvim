# Research Report: Task #216

**Task**: 216 - refactor_grant_implement_output_to_grants_dir
**Started**: 2026-03-16T12:00:00Z
**Completed**: 2026-03-16T12:30:00Z
**Effort**: 2-3 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of commands, skills, agents
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/implement` command routes by language but grant language is NOT in the core routing table
- The current `--finish` flag in `/grant` duplicates what `/implement` should do for grant tasks
- The design should add grant language routing to `/implement` via extension mechanism
- Grant-agent needs a new "assemble" workflow type (replacing "finish") triggered by `/implement`
- The output directory should be `grants/{NN}_{grant-slug}/` in project root

## Context and Scope

The goal is to remove the `--finish` flag from `/grant` and make `/implement N` the terminal command for grant tasks that:
1. Assembles all intermediate artifacts (drafts, budgets from `specs/{NNN}_{SLUG}/`)
2. Generates final grant output to `grants/{NN}_{grant-slug}/` directory

### Current Grant Workflow

```
/grant "Description"           -> Create task with language="grant"
/research N                    -> skill-grant (funder_research)
/plan N                        -> skill-planner
/grant N --draft ["prompt"]    -> skill-grant (proposal_draft)
/grant N --budget ["prompt"]   -> skill-grant (budget_develop)
/grant N --finish PATH         -> skill-grant (finish) -> REMOVED
/implement N                   -> ??? (currently unclear routing)
```

### Target Grant Workflow

```
/grant "Description"           -> Create task with language="grant"
/research N                    -> skill-grant (funder_research)
/plan N                        -> skill-planner
/grant N --draft ["prompt"]    -> skill-grant (proposal_draft)
/grant N --budget ["prompt"]   -> skill-grant (budget_develop)
/implement N                   -> skill-grant (assemble) -> grants/{NN}_{slug}/
```

## Findings

### 1. /implement Routing Architecture

The `/implement` command (`.claude/commands/implement.md`) uses language-based routing:

**Core Languages** (lines 68-73):
```markdown
| Language | Skill to Invoke |
|----------|-----------------|
| `general`, `meta`, `markdown` | `skill-implementer` |
| `formal`, `logic`, `math`, `physics` | `skill-implementer` |
```

**Extension Languages** (lines 75-77):
> When extensions are loaded (via `<leader>ac` in Neovim), additional language-specific skills become available. Extension skills follow the pattern `skill-{lang}-implementation` and are discovered automatically.

**Key Insight**: The `/implement` command does NOT currently have an explicit route for `grant` language. The extension mechanism expects a naming pattern like `skill-grant-implementation`, but the existing skill is just `skill-grant`.

### 2. Current skill-grant Routing

The `skill-grant/SKILL.md` routes five workflow types:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| funder_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| proposal_draft | planning | planned | [PLANNING] -> [PLANNED] |
| budget_develop | planning | planned | [PLANNING] -> [PLANNED] |
| **finish** | (no preflight change) | completed | -> [COMPLETED] |
| progress_track | (no change) | (no change) | (no change) |

The `finish` workflow:
- Takes `export_path` parameter (required)
- Collects all grant artifacts
- Validates required sections
- Exports to user-specified PATH
- Marks task as "completed"

### 3. Current grant.md Command Structure

The `/grant` command has these modes:

1. **Task Creation Mode**: `/grant "Description"` - Creates task with language="grant"
2. **Draft Mode** (`--draft`): Invokes skill-grant with workflow_type=proposal_draft
3. **Budget Mode** (`--budget`): Invokes skill-grant with workflow_type=budget_develop
4. **Finish Mode** (`--finish`): Invokes skill-grant with workflow_type=finish (TO BE REMOVED)
5. **Legacy Mode**: Deprecated workflow_type syntax

### 4. Current grant-agent Routing

The `grant-agent.md` handles these workflows:

```
grant-agent receives delegation
    |
    v
Parse workflow_type
    |
    +--- funder_research
    +--- proposal_draft
    +--- budget_develop
    +--- progress_track
```

Note: The `finish` workflow is mentioned in skill-grant but NOT explicitly shown in grant-agent's Stage 2 routing diagram. This suggests the finish workflow may be incomplete or was planned but not fully implemented.

### 5. Integration Design Options

**Option A: Add grant to /implement routing table**

Modify `/implement` to include:
```markdown
| `grant` | `skill-grant` (workflow_type=assemble) |
```

Pros:
- Direct routing, simple to implement
- No naming convention changes needed

Cons:
- Requires modifying core command for extension language
- Breaks the extension isolation pattern

**Option B: Create skill-grant-implementation wrapper** (RECOMMENDED)

Create a thin wrapper skill that:
1. Follows extension naming convention `skill-grant-implementation`
2. Delegates to skill-grant with workflow_type=assemble
3. Is discovered automatically by /implement

Pros:
- Follows extension conventions
- No core command modifications
- Clean separation of concerns

Cons:
- Additional indirection layer

**Option C: Let /implement detect grant language and route**

Have /implement check task language and dynamically route:
```
if language == "grant":
    invoke skill-grant with workflow_type=assemble
else:
    use standard routing table
```

Pros:
- No new files needed
- Works with existing skill-grant

Cons:
- Special-case logic in core command
- Extension pattern violation

## Recommendations

### Recommended Approach: Option A with Extension Table

The cleanest approach is to:

1. **Update EXTENSION.md** to declare grant routing for /implement
2. **Have /implement check extension manifests** for language routing
3. **Add "assemble" workflow** to skill-grant (replacing finish)
4. **Update grant-agent** to handle assemble workflow

This keeps the extension pattern but allows extensions to declare their /implement routing.

### Implementation Plan

#### Phase 1: Remove Finish Mode from /grant command

**File**: `.claude/extensions/present/commands/grant.md`

Remove sections:
- Lines 19-20: `| Finish | /grant N --finish PATH ["prompt"] | Export materials to PATH |`
- Lines 265-328: Entire "## Finish Mode (--finish)" section
- Lines 141-143: Update "Recommended workflow" output to remove step 5

Update recommended workflow to:
```
1. /research {N} - Research funders and requirements
2. /plan {N} - Create proposal plan
3. /grant {N} --draft - Draft narrative sections
4. /grant {N} --budget - Develop budget
5. /implement {N} - Assemble final grant materials
```

#### Phase 2: Update skill-grant Routing Table

**File**: `.claude/extensions/present/skills/skill-grant/SKILL.md`

1. Remove `finish` from workflow type validation (lines 107-113)
2. Remove `finish` from status mapping (lines 143-150)
3. Remove `finish` from postflight mapping (lines 329-334)
4. Remove `finish` from artifact linking (lines 377-380)
5. Remove `finish` from commit actions (lines 427-430)

Add `assemble` workflow type:
- Triggered by /implement on grant tasks
- Does NOT take export_path parameter (uses standard grants/ directory)
- Success status: completed
- Creates output in `grants/{NN}_{grant-slug}/`

#### Phase 3: Update grant-agent Workflows

**File**: `.claude/extensions/present/agents/grant-agent.md`

1. Remove `finish` from workflow routing diagram (lines 148-163)
2. Add `assemble` workflow:
```
+--- assemble
     Tools: Read + Write + Glob
     Output: grants/{NN}_{grant-slug}/
        - narrative.md (assembled from drafts)
        - budget.md (assembled from budgets)
        - checklist.md (submission checklist)
```

3. Update status values table (line 359-364) to replace `finish` with `assemble`

#### Phase 4: Update EXTENSION.md Documentation

**File**: `.claude/extensions/present/EXTENSION.md`

1. Remove references to `--finish` flag
2. Update command reference to show `/implement N` as final step
3. Update "Recommended Workflow" section
4. Update "Core Command Integration" table to show /implement routing

#### Phase 5: Enable /implement Grant Routing

**Two sub-options**:

**5a. Add to manifest.json** (preferred):
Add routing declaration to manifest:
```json
{
  "routing": {
    "implement": {
      "grant": "skill-grant:assemble"
    }
  }
}
```

Then update /implement to check extension manifests.

**5b. Document manual routing**:
Document that /implement should check task language and invoke skill-grant with assemble workflow when language="grant".

### Output Directory Structure

The `assemble` workflow creates:
```
grants/{NN}_{grant-slug}/
  |-- narrative.md         # Complete proposal narrative
  |-- budget.md            # Complete budget with justification
  |-- budget.csv           # Optional: spreadsheet format
  |-- checklist.md         # Submission checklist
  |-- appendices/          # Optional: supporting documents
```

Where `{NN}` is the task number (unpadded) and `{grant-slug}` is derived from the project_name.

## Files to Modify (Summary)

| File | Changes |
|------|---------|
| `commands/grant.md` | Remove Finish Mode section, update recommended workflow |
| `skills/skill-grant/SKILL.md` | Replace `finish` with `assemble` in all routing tables and case statements |
| `agents/grant-agent.md` | Replace `finish` with `assemble` workflow, add assemble execution logic |
| `EXTENSION.md` | Update documentation, remove --finish references |
| `manifest.json` | (Optional) Add routing declaration for /implement |
| `.claude/commands/implement.md` | (Optional) Add grant language routing or extension manifest check |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing grant tasks | Tasks using --finish should be rare; document migration path |
| Extension routing complexity | Start with explicit routing in /implement, migrate to manifest later |
| Missing intermediate artifacts | Add validation in assemble workflow to check for required drafts/budgets |

## Appendix

### Search Queries Used

- `Glob: **/implement.md` - Located /implement command
- `Grep: language.*routing` - Understood routing patterns
- `Read: skill-grant/SKILL.md` - Analyzed workflow types
- `Read: grant-agent.md` - Understood agent workflows
- `Read: EXTENSION.md` - Reviewed documentation requirements
