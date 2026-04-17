# Workflow Interruption Troubleshooting Guide

## Overview

This guide addresses common workflow interruption issues in the agent orchestration system, particularly around skill-to-subagent delegation and postflight operations.

## Background

Claude Code has known limitations with nested skill execution (GitHub Issue #17351):
- Nested skills return to the main session instead of the invoking skill
- This causes workflow interruptions requiring manual "continue" input

The solution implemented uses:
1. **Skill-internal postflight** - Skills handle all postflight operations before returning
2. **File-based metadata exchange** - Agents write metadata to files instead of console JSON
3. **SubagentStop hooks** - Hooks block premature termination when postflight is pending

## Common Issues and Fixes

### Issue 1: "Continue" Prompt Appears

**Symptom**: After a subagent completes, workflow pauses asking user to "continue".

**Likely Causes**:
1. Skill is not creating postflight marker before invoking subagent
2. SubagentStop hook is not configured
3. Hook script has errors

**Diagnostic Steps**:
```bash
# Check if hook is configured
jq '.hooks.SubagentStop' .claude/settings.json

# Check if hook script exists and is executable
ls -la .claude/hooks/subagent-postflight.sh

# Check hook logs
cat .claude/logs/subagent-postflight.log
```

**Fix**:
1. Ensure skill creates marker before subagent invocation:
```bash
# Ensure task directory exists
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-name",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending"
}
EOF
```

2. Verify hook is in settings.json:
```json
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/subagent-postflight.sh"
          }
        ]
      }
    ]
  }
}
```

---

### Issue 2: Infinite Loop / Workflow Stuck

**Symptom**: Workflow keeps repeating without completing, or seems stuck.

**Likely Causes**:
1. Loop guard counter exceeded
2. `stop_hook_active` flag not being checked
3. Marker file not being cleaned up

**Diagnostic Steps**:
```bash
# Find and check loop guard counter
guard=$(find specs -maxdepth 3 -name ".postflight-loop-guard" -type f | head -1)
[ -n "$guard" ] && cat "$guard"

# Find and check marker file
marker=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)
[ -n "$marker" ] && cat "$marker" | jq .

# Check if stop_hook_active is set
[ -n "$marker" ] && jq '.stop_hook_active' "$marker"
```

**Immediate Fix** (Emergency):
```bash
# Stop the loop by removing all orphaned markers
find specs -maxdepth 3 -name ".postflight-pending" -delete
find specs -maxdepth 3 -name ".postflight-loop-guard" -delete
```

**Permanent Fix**:
1. Verify skill removes marker after postflight:
```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
```

2. Verify loop guard is working (max 3 continuations)

---

### Issue 3: Metadata File Not Found

**Symptom**: Skill fails with "metadata file not found" error after subagent returns.

**Likely Causes**:
1. Agent didn't write metadata to file
2. Wrong file path used
3. Agent returned JSON to console instead of file

**Diagnostic Steps**:
```bash
# Check expected path
task_num=259
task_slug=$(jq -r --argjson num "$task_num" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
echo "Expected: specs/${task_num}_${task_slug}/.return-meta.json"

# Check if file exists
ls -la "specs/${task_num}_${task_slug}/.return-meta.json"
```

**Fix**:
1. Check agent instructions include:
   - "Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`"
   - "Return brief text summary, NOT JSON"

2. Verify agent loaded correct context:
   - `@.claude/context/formats/return-metadata-file.md`

---

### Issue 4: JSON Appears in Console Output

**Symptom**: Agent returns JSON block that gets printed to console instead of being parsed.

**Likely Causes**:
1. Agent instructions still say "return JSON"
2. Agent didn't load new metadata file format documentation
3. Incomplete migration

**Fix**:
1. Update agent instructions to include:
   - "**CRITICAL**: Return a brief text summary (3-6 bullet points), NOT JSON"
   - "**DO NOT return JSON to the console**. The skill reads metadata from the file."

2. Update context references in agent:
```markdown
**Always Load**:
- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema
```

---

### Issue 5: Status Not Updating

**Symptom**: Task status doesn't change after operation completes.

**Likely Causes**:
1. Skill postflight not running
2. state.json update failing
3. TODO.md update failing

**Diagnostic Steps**:
```bash
# Check state.json status
jq --argjson num 259 '.active_projects[] | select(.project_number == $num) | {status, last_updated}' specs/state.json

# Check TODO.md marker
grep -A 5 "### 259\." specs/TODO.md | head -6
```

**Fix**:
1. Check skill is reading metadata file correctly
2. Verify jq commands are correct (see `.claude/context/patterns/file-metadata-exchange.md`)
3. Ensure skill has Write tool access for TODO.md updates

---

### Issue 6: Git Commit Failing

**Symptom**: Changes not committed, but operation otherwise completes.

**Note**: Git commit failure is **non-blocking** by design. The operation should still complete successfully.

**Diagnostic Steps**:
```bash
# Check git status
git status

# Check for uncommitted changes
git diff --stat
```

**Fix**:
1. Manually commit if needed:
```bash
git add -A
git commit -m "task {N}: {action}

Session: {session_id}
```

---

### Issue 7: Hook Not Firing

**Symptom**: SubagentStop hook doesn't seem to execute.

**Diagnostic Steps**:
```bash
# Check hook configuration
jq '.hooks.SubagentStop' .claude/settings.json

# Check hook script permissions
ls -la .claude/hooks/subagent-postflight.sh

# Check hook output
bash .claude/hooks/subagent-postflight.sh
```

**Fix**:
1. Ensure hook is executable:
```bash
chmod +x .claude/hooks/subagent-postflight.sh
```

2. Verify settings.json configuration includes SubagentStop hook

3. Restart Claude Code session (hooks loaded on startup)

---

## Emergency Recovery Procedures

### Full Reset

If workflow is completely stuck:

1. **Stop Claude Code** (Ctrl+C)

2. **Clean up marker files**:
```bash
# Clean all orphaned postflight markers (older than 1 hour recommended)
find specs -maxdepth 3 -name ".postflight-pending" -delete
find specs -maxdepth 3 -name ".postflight-loop-guard" -delete
find specs -name ".return-meta.json" -delete
```

3. **Verify state is consistent**:
```bash
# Check state.json is valid
jq empty specs/state.json && echo "Valid JSON"

# Check for any tasks stuck in transitional states
jq '.active_projects[] | select(.status == "researching" or .status == "planning" or .status == "implementing") | {project_number, status}' specs/state.json
```

4. **Restart Claude Code**

5. **Manually fix stuck tasks** if needed:
```bash
# Reset stuck task to previous valid state
jq '(.active_projects[] | select(.project_number == 259)) |= . + {status: "not_started"}' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

### Partial Rollback

If one skill is failing but others work:

1. **Identify failing skill** from error logs

2. **Revert skill file** to previous version:
```bash
git checkout HEAD~1 -- .claude/skills/skill-problematic/SKILL.md
```

3. **Document workaround** in CLAUDE.md:
```markdown
**Known Issue**: skill-problematic uses old pattern, requires manual continue
```

---

## Monitoring and Logging

### Enable Hook Logging

The hook script writes logs to `.claude/logs/subagent-postflight.log`:

```bash
# View recent log entries
tail -50 .claude/logs/subagent-postflight.log

# Watch logs in real-time
tail -f .claude/logs/subagent-postflight.log
```

### Log Format

```
[2026-01-18T10:00:00+00:00] Postflight marker found
[2026-01-18T10:00:00+00:00] Loop guard incremented to 1
[2026-01-18T10:00:00+00:00] Blocking stop: Postflight pending...
[2026-01-18T10:00:01+00:00] No postflight marker, allowing stop
```

---

## Related Documentation

- `.claude/context/patterns/postflight-control.md` - Marker file protocol
- `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- `.claude/hooks/subagent-postflight.sh` - Hook script implementation
- `.claude/settings.json` - Hook configuration
