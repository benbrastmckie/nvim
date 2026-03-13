# Research Report: Task #OC_200

**Task**: OC_200 - Review .opencode/ and .claude/ agent systems for feature gaps and improvements
**Started**: 2026-03-13T19:15:00Z
**Completed**: 2026-03-13T19:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: Direct codebase exploration of commands and skills directories
**Standards**: report-format.md

---

## Executive Summary

This focused research examines the `/fix` vs `/fix-it` command discrepancy and verifies feature parity between `.opencode/` and `.claude/` extensions. Key findings reveal a critical naming inconsistency and feature gap that requires standardization.

### Key Findings:
1. **Naming Inconsistency**: `.opencode/` uses `/fix` while `.claude/` uses `/fix-it`
2. **Feature Gap**: `.claude/` version has advanced features (topic grouping, QUESTION: support) missing from `.opencode/`
3. **Extensions Parity**: All extension commands are already synchronized between systems
4. **Skills Gap**: `.claude/` is missing `skill-tag` and `skill-todo` present in `.opencode/`

---

## Detailed Analysis

### 1. Fix Command Discrepancy

| Aspect | .opencode/ | .claude/ | Status |
|--------|-----------|----------|--------|
| **Command Name** | `/fix` | `/fix-it` | **INCONSISTENT** |
| **Command File** | `commands/fix.md` (105 lines) | `commands/fix-it.md` (304 lines) | Different sizes |
| **Skill Name** | `skill-fix` | `skill-fix-it` | **INCONSISTENT** |
| **Implementation** | 71 lines, basic | 1005 lines, advanced | **FEATURE GAP** |

#### Feature Comparison

| Feature | .opencode/fix | .claude/fix-it |
|---------|---------------|----------------|
| FIX: tag scanning | ✓ | ✓ |
| NOTE: tag scanning | ✓ | ✓ |
| TODO: tag scanning | ✓ | ✓ |
| QUESTION: tag scanning | ✗ | ✓ |
| Topic grouping for TODOs | ✗ | ✓ |
| Topic grouping for QUESTIONs | ✗ | ✓ |
| Dependency handling (learn-it → fix-it) | ✗ | ✓ |
| Content-based language detection | ✗ | ✓ |
| Interactive selection | ✓ | ✓ |

**Recommendation**: Standardize both systems on `/fix-it` with the advanced feature set.

---

### 2. Extensions Commands Parity Status

**VERIFIED**: All extension commands exist in both systems with identical content.

#### filetypes Extension

| Command | .opencode/ | .claude/ | Status |
|---------|-----------|----------|--------|
| `/convert` | ✓ | ✓ | Synchronized |
| `/deck` | ✓ | ✓ | Synchronized |
| `/slides` | ✓ | ✓ | Synchronized |
| `/table` | ✓ | ✓ | Synchronized |

**Location**: 
- `.opencode/extensions/filetypes/commands/`
- `.claude/extensions/filetypes/commands/`

#### memory Extension

| Command | .opencode/ | .claude/ | Status |
|---------|-----------|----------|--------|
| `/learn` | ✓ | ✓ | Synchronized |

**Location**:
- `.opencode/extensions/memory/commands/learn.md`
- `.claude/extensions/memory/commands/learn.md`

**Note**: Files are byte-identical between systems.

---

### 3. Core Skills Comparison

#### Skills in .opencode/ only

| Skill | Purpose | Recommendation |
|-------|---------|----------------|
| `skill-fix` | Basic tag scanning | **Deprecate** - use skill-fix-it |
| `skill-learn` | Memory vault tasks | Keep in memory extension |
| `skill-tag` | Semantic version tagging | **Port to .claude/** |
| `skill-todo` | Task archiving workflow | **Port to .claude/** |

#### Skills in .claude/ only

| Skill | Purpose | Recommendation |
|-------|---------|----------------|
| `skill-fix-it` | Advanced tag scanning | **Port to .opencode/** |
| `skill-status-sync` | Atomic status updates | Keep (core utility) |

#### Skills in Both Systems

| Skill | .opencode/ | .claude/ | Status |
|-------|-----------|----------|--------|
| skill-git-workflow | ✓ | ✓ | Synchronized |
| skill-implementer | ✓ | ✓ | Synchronized |
| skill-meta | ✓ | ✓ | Synchronized |
| skill-orchestrator | ✓ | ✓ | Synchronized |
| skill-planner | ✓ | ✓ | Synchronized |
| skill-refresh | ✓ | ✓ | Synchronized |
| skill-researcher | ✓ | ✓ | Synchronized |

---

### 4. System-Specific Differences (Intentional)

These differences are **architecturally required** and should be preserved:

| Component | .opencode/ | .claude/ |
|-----------|-----------|----------|
| Root config | `AGENTS.md` | `CLAUDE.md` |
| Settings file | `.opencode/settings.local.json` | `.claude/settings.local.json` |
| Context index | `.opencode/context/index.json` | `.claude/context/index.json` |
| Agent directory | `agent/` (with subagents/) | `agents/` (flat) |
| Merge target | `opencode_md` | `claudemd` |

---

### 5. Recommended Changes

#### High Priority (Fix Standardization)

1. **Rename in .opencode/**:
   - `commands/fix.md` → `commands/fix-it.md`
   - `skills/skill-fix/` → `skills/skill-fix-it/`
   - Update command content to use `/fix-it`

2. **Port skill-fix-it features to .opencode/**:
   - Copy `.claude/skills/skill-fix-it/SKILL.md` content
   - Preserve all topic grouping logic
   - Preserve QUESTION: tag support
   - Preserve dependency handling

3. **Update orchestrator references**:
   - Change `skill-fix` → `skill-fix-it` in `.opencode/skills/skill-orchestrator/SKILL.md`

#### Medium Priority (Feature Parity)

4. **Port skill-tag to .claude/**:
   - Copy `.opencode/skills/skill-tag/` directory
   - Update references in `.claude/CLAUDE.md`

5. **Port skill-todo to .claude/**:
   - Copy `.opencode/skills/skill-todo/` directory
   - Update references in `.claude/CLAUDE.md`

#### Low Priority (Cleanup)

6. **Remove deprecated skill-fix**:
   - After migration, remove `.opencode/skills/skill-fix/`
   - Update any remaining references

---

### 6. Files Requiring Changes

#### .opencode/ Changes

| File | Action | Description |
|------|--------|-------------|
| `commands/fix.md` | Rename + Update | Change to fix-it.md with full feature set |
| `skills/skill-fix/` | Rename | Change to skill-fix-it/ |
| `skills/skill-fix-it/SKILL.md` | Create/Update | Port from .claude/ version |
| `skills/skill-orchestrator/SKILL.md` | Edit | Update skill name reference |
| `AGENTS.md` | Edit | Update command reference |

#### .claude/ Changes

| File | Action | Description |
|------|--------|-------------|
| `skills/skill-tag/` | Create | Port from .opencode/ |
| `skills/skill-todo/` | Create | Port from .opencode/ |
| `CLAUDE.md` | Edit | Add skill-to-agent mappings |

---

## Conclusion

The primary gap requiring immediate attention is the `/fix` vs `/fix-it` discrepancy. The `.claude/` system has the more mature implementation with topic grouping, QUESTION: support, and dependency handling. Standardizing on `/fix-it` in both systems will:

1. Eliminate user confusion between command names
2. Provide consistent advanced features across both systems
3. Simplify documentation and training

Extensions are already at parity - no changes needed for `filetypes/` or `memory/` extensions.

**Next Step**: Proceed with implementation plan to standardize on `/fix-it` and port missing skills.

---

## Appendix: Verification Commands

Commands used to verify findings:

```bash
# Compare command files
diff .claude/commands/fix-it.md .opencode/commands/fix.md

# Compare skill directories
ls -la .claude/skills/skill-fix-it/
ls -la .opencode/skills/skill-fix/

# Verify extension parity
diff .claude/extensions/filetypes/commands/convert.md .opencode/extensions/filetypes/commands/convert.md
diff .claude/extensions/memory/commands/learn.md .opencode/extensions/memory/commands/learn.md

# Check skill counts
ls .claude/skills/ | wc -l
ls .opencode/skills/ | wc -l
```
