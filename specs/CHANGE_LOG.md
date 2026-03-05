# Change Log

All notable changes to the OpenCode system.

## Format

Each entry includes:
- Date
- Task number and name
- Type of change
- Brief description

---

### 2026-03-05

**Task OC_142: implement_knowledge_capture_system**
- Status: completed
- Type: meta
- Summary: Implemented comprehensive knowledge capture system with three integrated features

**Changes:**
1. **Renamed /learn to /fix** (clean-break, NO backwards compatibility)
   - Removed: .opencode/commands/learn.md
   - Removed: .opencode/skills/skill-learn/
   - Created: .opencode/commands/fix.md
   - Created: .opencode/skills/skill-fix/
   - Updated: All documentation references across codebase
   - Migration: Use `/fix` instead of `/learn`

2. **Added task mode to /remember**
   - New syntax: `/remember --task OC_N`
   - Scans task artifacts (reports/, plans/, summaries/, code/)
   - Interactive artifact selection with multiSelect
   - 5-category classification taxonomy:
     * [TECHNIQUE] - Reusable method or approach
     * [PATTERN] - Design or implementation pattern  
     * [CONFIG] - Configuration or setup knowledge
     * [WORKFLOW] - Process or procedure
     * [INSIGHT] - Key learning or understanding
     * [SKIP] - Not valuable for memory

3. **Enhanced /todo with skill-todo**
   - Extracted embedded logic into dedicated skill
   - Added automatic CHANGE_LOG.md updates on archival
   - Added memory harvest suggestions from completed task artifacts
   - Interactive memory creation from task insights

**Breaking Changes:**
- `/learn` command completely removed (use `/fix` instead)
- No aliases, fallbacks, or backwards compatibility
- Muscle memory will need retraining

**Artifacts:**
- .opencode/commands/fix.md - New command (renamed from learn.md)
- .opencode/skills/skill-todo/SKILL.md - New skill definition
- .opencode/skills/skill-fix/SKILL.md - New skill (renamed from skill-learn)
- .opencode/commands/remember.md - Updated with --task mode
- .opencode/skills/skill-remember/SKILL.md - Updated with task mode
- specs/CHANGE_LOG.md - New changelog file

**Documentation Updated:**
- .opencode/commands/README.md
- .opencode/README.md
- .opencode/docs/guides/user-guide.md
- .opencode/docs/guides/component-selection.md
- .opencode/docs/guides/documentation-audit-checklist.md

---
