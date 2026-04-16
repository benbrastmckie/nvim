---
description: Analyze memory vault health, score memories for maintenance, and run distillation operations
---

# Command: /distill

**Purpose**: Analyzes the memory vault, scores each memory on staleness/retrieval/size/duplication, generates a health report, and dispatches maintenance sub-modes (purge, merge, compress, refine, gc).
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-memory mode=distill (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

<argument_parsing>
  <step_1>
    Parse arguments with sub-mode priority:

    **Sub-Mode Dispatch** (first match wins):
    1. No arguments (bare invocation) -> Report mode (health report)
    2. `--purge` -> Purge mode (remove low-value memories) [placeholder - task 450]
    3. `--merge` -> Merge mode (combine duplicate memories) [placeholder - task 451]
    4. `--compress` -> Compress mode (reduce oversized memories) [placeholder - task 452]
    5. `--refine` -> Refine mode (improve memory quality) [placeholder - task 452]
    6. `--gc` -> Garbage collection (purge + merge + compress) [placeholder - task 452]
    7. `--auto` -> Automated distillation (all operations) [placeholder - task 452]

    **Additional Flags**:
    - `--dry-run` -> Show what would happen without making changes
    - `--verbose` -> Show detailed scoring breakdown per memory

    ```
    sub_mode = "report"  # default

    if "--purge" in $ARGUMENTS:
      sub_mode = "purge"
    elif "--merge" in $ARGUMENTS:
      sub_mode = "merge"
    elif "--compress" in $ARGUMENTS:
      sub_mode = "compress"
    elif "--refine" in $ARGUMENTS:
      sub_mode = "refine"
    elif "--gc" in $ARGUMENTS:
      sub_mode = "gc"
    elif "--auto" in $ARGUMENTS:
      sub_mode = "auto"

    dry_run = "--dry-run" in $ARGUMENTS
    verbose = "--verbose" in $ARGUMENTS
    ```
  </step_1>
</argument_parsing>

---

## Workflow Execution

<workflow_execution>
  <step_1>
    <action>Validate Sub-Mode Availability</action>
    <process>
      Check if the requested sub-mode is implemented:

      | Sub-Mode | Status | Task |
      |----------|--------|------|
      | report | Available | 449 (this task) |
      | purge | Placeholder | 450 |
      | merge | Placeholder | 451 |
      | compress | Placeholder | 452 |
      | refine | Placeholder | 452 |
      | gc | Placeholder | 452 |
      | auto | Placeholder | 452 |

      If sub-mode is a placeholder, display:
      ```
      /distill --{sub_mode} is not yet implemented.
      Currently available: /distill (health report)
      See tasks 450-452 for planned sub-mode implementations.
      ```
    </process>
  </step_1>

  <step_2>
    <action>Delegate to Memory Skill</action>
    <input>
      - skill: "skill-memory"
      - args: "mode=distill, sub_mode={sub_mode}, dry_run={dry_run}, verbose={verbose}"
    </input>
    <expected_return>
      {
        "status": "completed",
        "mode": "distill",
        "sub_mode": "report",
        "health_report": { ... },
        "scores": [ ... ],
        "memory_health": { ... }
      }
    </expected_return>
  </step_2>

  <step_3>
    <action>Present Results</action>
    <process>
      Report mode:
        - Display formatted health report
        - Show vault overview statistics
        - List maintenance candidates by category
        - Show health score with status indicator
        - Suggest next actions based on scores

      Other modes (when implemented):
        - Display operation summary
        - Show before/after metrics
        - Log operation to distill-log.json
        - Update memory_health in state.json
    </process>
  </step_3>

  <step_4>
    <action>Update State and Log</action>
    <process>
      After any distill operation:
      1. Update memory_health in specs/state.json
      2. Append operation entry to .memory/distill-log.json
      3. Git commit changes
    </process>
  </step_4>
</workflow_execution>

---

## Error Handling

<error_handling>
  <argument_errors>
    - Unknown flag -> "Unknown flag: {flag}. Available: --purge, --merge, --compress, --refine, --gc, --auto, --dry-run, --verbose"
    - Unimplemented sub-mode -> "Sub-mode not yet implemented. Currently available: /distill (health report)"
  </argument_errors>

  <execution_errors>
    - No memories found -> "No memories in vault. Use /learn to add memories first."
    - memory-index.json missing -> "Memory index not found. Run /learn to initialize."
    - memory-index.json stale -> Auto-regenerate via validate-on-read before scoring
    - Skill failure -> Return error details
  </execution_errors>
</error_handling>

---

## State Management

<state_management>
  <reads>
    - .memory/memory-index.json (scoring input)
    - .memory/10-Memories/*.md (validation, content analysis)
    - .memory/distill-log.json (operation history)
    - specs/state.json (current memory_health)
  </reads>

  <writes>
    - .memory/distill-log.json (operation log entries)
    - specs/state.json (memory_health field updates)
    - .memory/10-Memories/*.md (only for purge/merge/compress operations)
  </writes>
</state_management>
