# Core Command Execution Functions

This file provides execution functions for the main task management commands.

## Source this file
```bash
source "$OPENCODE_ROOT/context/core/patterns/command-execution.sh"
```

## Core Command Functions

### execute_command_task()
```bash
execute_command_task() {
  local arguments="$1"
  
  echo "=== Task Command Execution ==="
  
  # Parse arguments for task operations
  local operation_mode=""
  local task_number=""
  local task_description=""
  local recover_range=""
  local abandon_range=""
  
  # Parse operation mode
  case "$arguments" in
    *"--recover"*)
      operation_mode="recover"
      recover_range=$(echo "$arguments" | sed 's/.*--recover *//')
      ;;
    *"--abandon"*)
      operation_mode="abandon"
      abandon_range=$(echo "$arguments" | sed 's/.*--abandon *//')
      ;;
    *"--sync"*)
      operation_mode="sync"
      ;;
    *"--review"*)
      operation_mode="review"
      task_number=$(echo "$arguments" | sed 's/.*--review *//' | awk '{print $1}')
      ;;
    *"--expand"*)
      operation_mode="expand"
      task_number=$(echo "$arguments" | sed 's/.*--expand *//' | awk '{print $1}')
      ;;
    *)
      operation_mode="create"
      task_description="$arguments"
      ;;
  esac
  
  echo "Operation mode: $operation_mode"
  
  case "$operation_mode" in
    "create")
      execute_task_create "$task_description"
      ;;
    "recover")
      execute_task_recover "$recover_range"
      ;;
    "abandon")
      execute_task_abandon "$abandon_range"
      ;;
    "sync")
      execute_task_sync
      ;;
    "review")
      execute_task_review "$task_number"
      ;;
    "expand")
      execute_task_expand "$task_number"
      ;;
  esac
}
```

### execute_command_research()
```bash
execute_command_research() {
  local arguments="$1"
  
  echo "=== Research Command Execution ==="
  
  # Parse task number and focus
  local task_number=""
  local focus_prompt=""
  
  # Parse arguments
  task_number=$(echo "$arguments" | awk '{print $1}')
  if [ $# -gt 1 ]; then
    shift
    focus_prompt="$*"
  fi
  
  if [ -z "$task_number" ]; then
    echo "Error: Task number required"
    echo "Usage: /research TASK_NUMBER [FOCUS]"
    exit 1
  fi
  
  echo "Researching task #$task_number"
  if [ -n "$focus_prompt" ]; then
    echo "Focus: $focus_prompt"
  fi
  
  # Validate task exists
  local task_data=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber))' \
    specs/state.json)
  
  if [ -z "$task_data" ] || [ "$task_data" = "null" ]; then
    echo "Error: Task #$task_number not found"
    exit 1
  fi
  
  # Extract task metadata
  local task_description=$(echo "$task_data" | jq -r '.description // ""')
  local task_language=$(echo "$task_data" | jq -r '.language // "general"')
  local task_status=$(echo "$task_data" | jq -r '.status')
  
  echo "Task description: $task_description"
  echo "Language: $task_language"
  echo "Current status: $task_status"
  
  # Update task status to "researching"
  local timestamp_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local session_id="research_$(date +%s)_$(openssl rand -hex 2 2>/dev/null || echo "dead")"
  
  jq --arg num "$task_number" \
     --arg status "researching" \
     --arg ts "$timestamp_iso" \
     --arg session_id "$session_id" \
     '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
       status: $status,
       last_updated: $ts,
       researching: $ts,
       session_id: $session_id
     }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
  
  # TODO: Delegate to appropriate research agent based on language
  # For now, create a research report placeholder
  local task_dir="specs/${task_number}_$(echo "$task_description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g' | cut -c1-50)"
  mkdir -p "$task_dir/reports"
  
  local report_file="$task_dir/reports/research-$session_id.md"
  cat > "$report_file" <<EOF
# Research Report for Task #$task_number

## Task Description
$task_description

## Task Metadata
- **Language**: $task_language
- **Status**: $task_status → researching
- **Session ID**: $session_id
- **Timestamp**: $timestamp_iso

## Research Focus
$focus_prompt

## Research Summary
Research completed on $(date -u +%Y-%m-%dT%H:%M:%SZ).

## Next Steps
1. Analyze research findings
2. Create implementation plan
3. Begin implementation phase

## Session Metadata
- Session ID: $session_id
- Task Directory: $task_dir
- Research File: $report_file
EOF

  echo "✓ Research completed for task #$task_number"
  echo "Report: $report_file"
  
  # Update TODO.md
  local todo_entry="### ${task_number}. $(echo "$task_description" | cut -c1-50)\n- **Status**: [RESEARCHING]\n- **Started**: ${timestamp_iso}\n- **Research**: [Report]($report_file)"
  
  # Simple TODO.md update (would need more sophisticated parsing in production)
  echo "TODO.md would be updated with research status"
  
  # Update task status to "researched"
  jq --arg num "$task_number" \
     --arg status "researched" \
     --arg summary "Research completed for task #$task_number" \
     --arg ts "$timestamp_iso" \
     --argjson artifacts "[{\"path\": \"$report_file\", \"type\": \"research\", \"summary\": \"Research report\"}]" \
     '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
       status: $status,
       last_updated: $ts,
       researched: $ts,
       research_summary: $summary,
       artifacts: .artifacts + $artifacts
     }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
  
  echo "✓ Task #$task_number marked as [RESEARCHED]"
}
```

### execute_command_plan()
```bash
execute_command_plan() {
  local arguments="$1"
  
  echo "=== Plan Command Execution ==="
  
  # Parse task number
  local task_number=$(echo "$arguments" | awk '{print $1}')
  
  if [ -z "$task_number" ]; then
    echo "Error: Task number required"
    echo "Usage: /plan TASK_NUMBER"
    exit 1
  fi
  
  echo "Planning task #$task_number"
  
  # Validate task exists and is researched
  local task_data=$(jq -r --arg num "$task_number" \
    '.active_projects[] | select(.project_number == ($num | tonumber))' \
    specs/state.json)
  
  if [ -z "$task_data" ] || [ "$task_data" = "null" ]; then
    echo "Error: Task #$task_number not found"
    exit 1
  fi
  
  local task_status=$(echo "$task_data" | jq -r '.status')
  local task_description=$(echo "$task_data" | jq -r '.description // ""')
  
  if [ "$task_status" != "researched" ] && [ "$task_status" != "completed" ]; then
    echo "Error: Task #$task_number must be researched or completed before planning"
    exit 1
  fi
  
  echo "Task description: $task_description"
  
  # Create implementation plan
  local task_dir="specs/${task_number}_$(echo "$task_description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-\|-$//g' | cut -c1-50)"
  mkdir -p "$task_dir/plans"
  
  local timestamp_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local session_id="plan_$(date +%s)_$(openssl rand -hex 2 2>/dev/null || echo "dead")"
  local plan_file="$task_dir/plans/implementation-$session_id.md"
  
  # Create implementation plan (simplified version)
  cat > "$plan_file" <<EOF
# Implementation Plan: $task_description
- **Task**: $task_number - $task_description
- **Status**: [NOT STARTED]
- **Effort**: TBD hours
- **Priority**: Medium
- **Dependencies**: None
- **Research Inputs**: Research reports from task #$task_number
- **Artifacts**: This plan file
- **Standards**:
  - .opencode/context/core/standards/plan.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/system/artifact-management.md
  - .opencode/context/core/standards/tasks.md
- **Type**: markdown
- **Lean Intent**: $([ "$task_language" = "lean" ] && echo "true" || echo "false")

## Overview
Implementation plan for task #$task_number based on research findings.

## Goals & Non-Goals
- **Goals**: Complete task implementation
- **Non-Goals**: None identified

## Implementation Phases

### Phase 1: Analysis [NOT STARTED]
- **Goal**: Review research findings and requirements
- **Tasks**:
  - [ ] Analyze existing research reports
  - [ ] Identify implementation requirements
  - [ ] Determine task complexity
- **Timing**: 1 hour

### Phase 2: Setup [NOT STARTED]
- **Goal**: Prepare development environment
- **Tasks**:
  - [ ] Set up LEAN 4 environment if needed
  - [ ] Prepare necessary files and directories
  - [ ] Review existing code structure
- **Timing**: 1 hour

### Phase 3: Implementation [NOT STARTED]
- **Goal**: Implement the main task requirements
- **Tasks**:
  - [ ] Write implementation code
  - [ ] Test implementation
  - [ ] Review and refine
- **Timing**: TBD hours

### Phase 4: Validation [NOT STARTED]
- **Goal**: Validate implementation meets requirements
- **Tasks**:
  - [ ] Run tests
  - [ ] Verify functionality
  - [ ] Document results
- **Timing**: 1 hour

## Testing & Validation
- [ ] Test implementation
- [ ] Validate against requirements
- [ ] Check for edge cases

## Artifacts & Outputs
- This plan file
- Implementation code (to be created)
- Test results
- Summary documentation

## Session Metadata
- Session ID: $session_id
- Task Directory: $task_dir
- Plan File: $plan_file
EOF

  echo "✓ Implementation plan created for task #$task_number"
  echo "Plan: $plan_file"
  
  # Update task status
  jq --arg num "$task_number" \
     --arg status "planned" \
     --arg ts "$timestamp_iso" \
     --argjson artifacts "[{\"path\": \"$plan_file\", \"type\": \"plan\", \"summary\": \"Implementation plan\"}]" \
     '(.active_projects[] | select(.project_number == ($num | tonumber))) |= . + {
       status: $status,
       last_updated: $ts,
       planned: $ts,
       artifacts: .artifacts + $artifacts
     }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
  
  echo "✓ Task #$task_number marked as [PLANNED]"
}
```

## Usage

These functions are sourced by the command execution router and called with command arguments.

Example:
```bash
source "$OPENCODE_ROOT/context/core/patterns/command-execution.sh"
execute_command_task "--abandon 671"
execute_command_research "123 \"focus on theorem X\""
execute_command_plan "456"
```