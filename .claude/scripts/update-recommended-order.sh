#!/usr/bin/env bash
#
# update-recommended-order.sh - Manage the Recommended Order section in TODO.md
#
# Usage:
#   update-recommended-order.sh add TASK_NUM     - Insert task based on dependency position
#   update-recommended-order.sh remove TASK_NUM  - Remove task entry from section
#   update-recommended-order.sh refresh          - Regenerate entire section from state.json
#
# The Recommended Order section provides a topologically-sorted list of tasks
# based on their dependencies, with action hints derived from task status.
#
# Section format:
#   ## Recommended Order
#   1. **995** -> plan + implement (unblocks 988, 989, 997)
#   2. **996** -> research (independent)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TODO_FILE="${PROJECT_ROOT}/specs/TODO.md"
STATE_FILE="${PROJECT_ROOT}/specs/state.json"

# ============================================================================
# Helper Functions
# ============================================================================

# Check if TODO.md exists
check_todo_exists() {
    if [[ ! -f "$TODO_FILE" ]]; then
        echo "ERROR: TODO.md not found at $TODO_FILE" >&2
        return 1
    fi
}

# Check if state.json exists
check_state_exists() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "ERROR: state.json not found at $STATE_FILE" >&2
        return 1
    fi
}

# Get the line number where "## Recommended Order" section starts
# Returns 0 if section doesn't exist
get_section_start() {
    local line_num
    line_num=$(grep -n "^## Recommended Order" "$TODO_FILE" 2>/dev/null | head -1 | cut -d: -f1)
    echo "${line_num:-0}"
}

# Get the line number where the next ## section starts after Recommended Order
# Returns 0 if no next section (EOF)
get_section_end() {
    local start_line="$1"
    if [[ "$start_line" -eq 0 ]]; then
        echo "0"
        return
    fi

    local next_section
    next_section=$(tail -n +"$((start_line + 1))" "$TODO_FILE" | grep -n "^## " | head -1 | cut -d: -f1)

    if [[ -n "$next_section" ]]; then
        echo "$((start_line + next_section))"
    else
        echo "0"  # EOF
    fi
}

# Derive action hint from task status
# Returns: "research", "plan", "implement", or "complete"
get_action_hint() {
    local status="$1"
    case "$status" in
        not_started|researching)
            echo "research"
            ;;
        researched|planning)
            echo "plan"
            ;;
        planned|implementing|partial)
            echo "implement"
            ;;
        completed)
            echo "complete"
            ;;
        blocked)
            echo "blocked"
            ;;
        abandoned|expanded)
            echo "skip"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ============================================================================
# remove_from_recommended_order
# ============================================================================

remove_from_recommended_order() {
    local task_num="$1"

    check_todo_exists || return 1

    local section_start
    section_start=$(get_section_start)

    if [[ "$section_start" -eq 0 ]]; then
        # Section doesn't exist, nothing to remove
        echo "INFO: Recommended Order section not found, nothing to remove"
        return 0
    fi

    local section_end
    section_end=$(get_section_end "$section_start")

    # Check if task exists in section
    # Pattern: digits followed by . **TASK_NUM**
    if ! grep -q "^[0-9]\+\. \*\*${task_num}\*\*" "$TODO_FILE" 2>/dev/null; then
        echo "INFO: Task $task_num not found in Recommended Order section"
        return 0
    fi

    # Remove the line containing the task
    sed -i "/^[0-9]\+\. \*\*${task_num}\*\*/d" "$TODO_FILE"

    # Renumber remaining entries
    renumber_entries

    echo "Removed task $task_num from Recommended Order"
    return 0
}

# Renumber entries in the Recommended Order section (1, 2, 3, ...)
renumber_entries() {
    local section_start
    section_start=$(get_section_start)

    if [[ "$section_start" -eq 0 ]]; then
        return 0
    fi

    local section_end
    section_end=$(get_section_end "$section_start")

    # Create temp file for processing
    local tmp_file
    tmp_file=$(mktemp)

    local counter=1
    local in_section=0
    local line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Check if we're entering the section
        if [[ "$line_num" -eq "$section_start" ]]; then
            in_section=1
            echo "$line" >> "$tmp_file"
            continue
        fi

        # Check if we're leaving the section
        if [[ "$section_end" -ne 0 && "$line_num" -ge "$section_end" ]]; then
            in_section=0
        fi

        if [[ "$in_section" -eq 1 && "$line" =~ ^[0-9]+\.\  ]]; then
            # Renumber this entry
            local rest
            rest=$(echo "$line" | sed 's/^[0-9]\+\. //')
            echo "${counter}. ${rest}" >> "$tmp_file"
            counter=$((counter + 1))
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$TODO_FILE"

    mv "$tmp_file" "$TODO_FILE"
}

# ============================================================================
# refresh_recommended_order - Regenerate entire section from state.json
# ============================================================================

# Build task data structure from state.json
# Outputs lines: TASK_NUM|STATUS|DEP1,DEP2,...
get_task_data() {
    check_state_exists || return 1

    # Extract non-terminal tasks with their status and dependencies
    # Use "| not" pattern per jq-escaping-workarounds.md
    jq -r '.active_projects[] |
        select(.status == "completed" | not) |
        select(.status == "abandoned" | not) |
        select(.status == "expanded" | not) |
        "\(.project_number)|\(.status)|\(.dependencies // [] | join(","))"
    ' "$STATE_FILE"
}

# Get tasks that depend on a given task
get_dependents() {
    local task_num="$1"

    jq -r --arg tn "$task_num" '.active_projects[] |
        select(.status == "completed" | not) |
        select(.status == "abandoned" | not) |
        select(.status == "expanded" | not) |
        select(.dependencies // [] | map(tostring) | index($tn)) |
        .project_number
    ' "$STATE_FILE" 2>/dev/null
}

# Perform topological sort using Kahn's algorithm
# Returns task numbers in topological order (dependencies first)
topological_sort() {
    local -A in_degree  # task -> number of unresolved dependencies
    local -A dependents # task -> space-separated list of tasks that depend on it
    local -a all_tasks  # all task numbers
    local -a queue      # tasks with no unresolved dependencies
    local -a sorted     # output order

    # Build the graph
    while IFS='|' read -r task_num status deps; do
        [[ -z "$task_num" ]] && continue

        all_tasks+=("$task_num")
        in_degree[$task_num]=0

        # Parse dependencies
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra dep_array <<< "$deps"
            for dep in "${dep_array[@]}"; do
                [[ -z "$dep" ]] && continue
                # Only count dependency if the dependency is also in active tasks
                # (it might be completed already)
                in_degree[$task_num]=$((${in_degree[$task_num]} + 1))
                dependents[$dep]="${dependents[$dep]:-} $task_num"
            done
        fi
    done < <(get_task_data)

    # Re-count in_degree only for dependencies that are in our active set
    # This ensures completed dependencies don't block tasks
    for task_num in "${all_tasks[@]}"; do
        local real_degree=0
        # Get this task's dependencies from state
        local deps
        deps=$(jq -r --arg tn "$task_num" '.active_projects[] |
            select(.project_number == ($tn | tonumber)) |
            .dependencies // [] | .[]' "$STATE_FILE" 2>/dev/null)

        for dep in $deps; do
            # Check if dep is still in all_tasks (not completed)
            for active in "${all_tasks[@]}"; do
                if [[ "$active" == "$dep" ]]; then
                    real_degree=$((real_degree + 1))
                    break
                fi
            done
        done
        in_degree[$task_num]=$real_degree
    done

    # Initialize queue with tasks having in_degree 0
    for task_num in "${all_tasks[@]}"; do
        if [[ "${in_degree[$task_num]}" -eq 0 ]]; then
            queue+=("$task_num")
        fi
    done

    # Process queue
    while [[ ${#queue[@]} -gt 0 ]]; do
        # Pop first element
        local current="${queue[0]}"
        queue=("${queue[@]:1}")
        sorted+=("$current")

        # Decrease in_degree for dependents
        for dependent in ${dependents[$current]:-}; do
            [[ -z "$dependent" ]] && continue
            in_degree[$dependent]=$((${in_degree[$dependent]} - 1))
            if [[ "${in_degree[$dependent]}" -eq 0 ]]; then
                queue+=("$dependent")
            fi
        done
    done

    # Check for cycles
    if [[ ${#sorted[@]} -ne ${#all_tasks[@]} ]]; then
        echo "WARNING: Circular dependencies detected, some tasks may be missing" >&2
    fi

    # Output sorted tasks
    printf '%s\n' "${sorted[@]}"
}

# Generate a single entry line for the Recommended Order section
generate_entry() {
    local position="$1"
    local task_num="$2"

    local status
    status=$(jq -r --arg tn "$task_num" '.active_projects[] |
        select(.project_number == ($tn | tonumber)) | .status' "$STATE_FILE")

    local action
    action=$(get_action_hint "$status")

    # Get dependents (tasks that this task unblocks)
    local dependents_list
    dependents_list=$(get_dependents "$task_num" | tr '\n' ',' | sed 's/,$//')

    local notes
    if [[ -n "$dependents_list" ]]; then
        notes="unblocks $dependents_list"
    else
        notes="independent"
    fi

    echo "${position}. **${task_num}** -> ${action} (${notes})"
}

# Find the line after ## Tasks section for inserting Recommended Order
find_tasks_section_end() {
    local tasks_start
    tasks_start=$(grep -n "^## Tasks" "$TODO_FILE" 2>/dev/null | head -1 | cut -d: -f1)

    if [[ -z "$tasks_start" || "$tasks_start" -eq 0 ]]; then
        # No Tasks section, return end of file
        wc -l < "$TODO_FILE"
        return
    fi

    # Find the next ## section after Tasks
    local next_section
    next_section=$(tail -n +"$((tasks_start + 1))" "$TODO_FILE" | grep -n "^## " | head -1 | cut -d: -f1)

    if [[ -n "$next_section" ]]; then
        echo "$((tasks_start + next_section - 1))"
    else
        wc -l < "$TODO_FILE"
    fi
}

refresh_recommended_order() {
    check_todo_exists || return 1
    check_state_exists || return 1

    # Get topologically sorted tasks
    local -a sorted_tasks
    mapfile -t sorted_tasks < <(topological_sort)

    if [[ ${#sorted_tasks[@]} -eq 0 ]]; then
        echo "INFO: No active non-terminal tasks found"
        return 0
    fi

    # Generate new section content
    local new_content
    new_content="## Recommended Order"$'\n'$'\n'

    local position=1
    for task_num in "${sorted_tasks[@]}"; do
        [[ -z "$task_num" ]] && continue
        new_content+="$(generate_entry "$position" "$task_num")"$'\n'
        position=$((position + 1))
    done

    # Check if section already exists
    local section_start
    section_start=$(get_section_start)

    if [[ "$section_start" -eq 0 ]]; then
        # Section doesn't exist, insert before ## Tasks or at end
        local insert_line
        insert_line=$(find_tasks_section_end)

        # Insert the new section
        local tmp_file
        tmp_file=$(mktemp)

        head -n "$insert_line" "$TODO_FILE" > "$tmp_file"
        echo "" >> "$tmp_file"
        echo -n "$new_content" >> "$tmp_file"
        tail -n +"$((insert_line + 1))" "$TODO_FILE" >> "$tmp_file"

        mv "$tmp_file" "$TODO_FILE"
        echo "Created Recommended Order section with ${#sorted_tasks[@]} tasks"
    else
        # Section exists, replace its contents
        local section_end
        section_end=$(get_section_end "$section_start")

        local tmp_file
        tmp_file=$(mktemp)

        # Copy everything before section
        head -n "$((section_start - 1))" "$TODO_FILE" > "$tmp_file"

        # Write new section content
        echo -n "$new_content" >> "$tmp_file"

        # Copy everything after section
        if [[ "$section_end" -ne 0 ]]; then
            tail -n +"$section_end" "$TODO_FILE" >> "$tmp_file"
        fi

        mv "$tmp_file" "$TODO_FILE"
        echo "Refreshed Recommended Order section with ${#sorted_tasks[@]} tasks"
    fi

    return 0
}

# ============================================================================
# add_to_recommended_order - Insert task based on dependency position
# ============================================================================

# Get the position (line number within entries) of a task in Recommended Order
# Returns 0 if task not found
get_entry_position() {
    local task_num="$1"

    local section_start
    section_start=$(get_section_start)

    if [[ "$section_start" -eq 0 ]]; then
        echo "0"
        return
    fi

    # Find the line with this task and extract its position number
    local pos
    pos=$(grep "^[0-9]\+\. \*\*${task_num}\*\*" "$TODO_FILE" 2>/dev/null | sed 's/\. .*//')
    echo "${pos:-0}"
}

# Count entries in Recommended Order section
count_entries() {
    local section_start
    section_start=$(get_section_start)

    if [[ "$section_start" -eq 0 ]]; then
        echo "0"
        return
    fi

    local section_end
    section_end=$(get_section_end "$section_start")

    local count
    if [[ "$section_end" -eq 0 ]]; then
        # Section goes to EOF - count from section_start to end
        count=$(tail -n +"$((section_start + 1))" "$TODO_FILE" | grep -c "^[0-9]\+\. \*\*" 2>/dev/null)
    else
        # Count entries between section_start and section_end
        count=$(sed -n "$((section_start + 1)),$((section_end - 1))p" "$TODO_FILE" 2>/dev/null | grep -c "^[0-9]\+\. \*\*" 2>/dev/null)
    fi

    # Ensure we return a valid number
    echo "${count:-0}"
}

add_to_recommended_order() {
    local task_num="$1"

    check_todo_exists || return 1
    check_state_exists || return 1

    # Check if task exists in state.json
    local task_exists
    task_exists=$(jq --arg tn "$task_num" '.active_projects[] | select(.project_number == ($tn | tonumber))' "$STATE_FILE" 2>/dev/null)

    if [[ -z "$task_exists" ]]; then
        echo "ERROR: Task $task_num not found in state.json" >&2
        return 1
    fi

    # Check if section exists - create if not
    local section_start
    section_start=$(get_section_start)

    if [[ "$section_start" -eq 0 ]]; then
        # Create empty section first, then add
        local insert_line
        insert_line=$(find_tasks_section_end)

        local tmp_file
        tmp_file=$(mktemp)

        head -n "$insert_line" "$TODO_FILE" > "$tmp_file"
        echo "" >> "$tmp_file"
        echo "## Recommended Order" >> "$tmp_file"
        echo "" >> "$tmp_file"
        tail -n +"$((insert_line + 1))" "$TODO_FILE" >> "$tmp_file"

        mv "$tmp_file" "$TODO_FILE"
        section_start=$(get_section_start)
    fi

    # Check if task already in section (idempotent)
    if grep -q "^[0-9]\+\. \*\*${task_num}\*\*" "$TODO_FILE" 2>/dev/null; then
        echo "INFO: Task $task_num already in Recommended Order section"
        return 0
    fi

    # Get task's dependencies
    local -a deps
    mapfile -t deps < <(jq -r --arg tn "$task_num" '.active_projects[] |
        select(.project_number == ($tn | tonumber)) |
        .dependencies // [] | .[]' "$STATE_FILE" 2>/dev/null)

    # Find the latest position of any dependency in the section
    local max_dep_pos=0
    for dep in "${deps[@]}"; do
        [[ -z "$dep" ]] && continue
        local dep_pos
        dep_pos=$(get_entry_position "$dep")
        if [[ "$dep_pos" -gt "$max_dep_pos" ]]; then
            max_dep_pos=$dep_pos
        fi
    done

    # Determine insert position
    local insert_pos
    if [[ "$max_dep_pos" -gt 0 ]]; then
        # Insert after the last dependency
        insert_pos=$((max_dep_pos + 1))
    else
        # No dependencies in section, append to end
        local entry_count
        entry_count=$(count_entries)
        insert_pos=$((entry_count + 1))
    fi

    # Generate the entry
    local entry
    entry=$(generate_entry "$insert_pos" "$task_num")

    # Insert at the correct position
    local section_end
    section_end=$(get_section_end "$section_start")

    local tmp_file
    tmp_file=$(mktemp)

    local line_num=0
    local entry_num=0
    local in_section=0
    local inserted=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Check if we're entering the section
        if [[ "$line_num" -eq "$section_start" ]]; then
            in_section=1
            echo "$line" >> "$tmp_file"
            continue
        fi

        # Check if we're leaving the section
        if [[ "$section_end" -ne 0 && "$line_num" -ge "$section_end" ]]; then
            # Before leaving, check if we need to insert at end
            if [[ "$in_section" -eq 1 && "$inserted" -eq 0 ]]; then
                echo "$entry" >> "$tmp_file"
                inserted=1
            fi
            in_section=0
        fi

        if [[ "$in_section" -eq 1 && "$line" =~ ^[0-9]+\.\  ]]; then
            entry_num=$((entry_num + 1))

            # If this is the insert position, insert before
            if [[ "$entry_num" -eq "$insert_pos" && "$inserted" -eq 0 ]]; then
                echo "$entry" >> "$tmp_file"
                inserted=1
            fi

            # Renumber this entry (it shifts by 1 after insert)
            local rest
            rest=$(echo "$line" | sed 's/^[0-9]\+\. //')
            if [[ "$inserted" -eq 1 ]]; then
                echo "$((entry_num + 1)). ${rest}" >> "$tmp_file"
            else
                echo "${entry_num}. ${rest}" >> "$tmp_file"
            fi
        else
            echo "$line" >> "$tmp_file"
        fi
    done < "$TODO_FILE"

    # If we never inserted (appending to end of empty or end of section)
    if [[ "$inserted" -eq 0 ]]; then
        # Insert before the last line if section goes to EOF
        # Need to handle this specially
        # Actually, we need to insert at the end of the section
        mv "$tmp_file" "$TODO_FILE"

        # Re-read and insert at end of section content (before empty lines or next section)
        section_start=$(get_section_start)
        section_end=$(get_section_end "$section_start")

        tmp_file=$(mktemp)
        line_num=0
        in_section=0
        inserted=0
        local last_entry_line=0

        while IFS= read -r line; do
            line_num=$((line_num + 1))

            if [[ "$line_num" -eq "$section_start" ]]; then
                in_section=1
            fi

            if [[ "$section_end" -ne 0 && "$line_num" -ge "$section_end" ]]; then
                in_section=0
            fi

            if [[ "$in_section" -eq 1 && "$line" =~ ^[0-9]+\.\  ]]; then
                last_entry_line=$line_num
            fi

            echo "$line" >> "$tmp_file"
        done < "$TODO_FILE"

        # Insert after last entry
        if [[ "$last_entry_line" -gt 0 ]]; then
            local tmp_file2
            tmp_file2=$(mktemp)
            head -n "$last_entry_line" "$tmp_file" > "$tmp_file2"
            echo "$entry" >> "$tmp_file2"
            tail -n +"$((last_entry_line + 1))" "$tmp_file" >> "$tmp_file2"
            mv "$tmp_file2" "$TODO_FILE"
            rm -f "$tmp_file"
        else
            # No entries yet, insert after section header + blank line
            local tmp_file2
            tmp_file2=$(mktemp)
            head -n "$((section_start + 1))" "$tmp_file" > "$tmp_file2"
            echo "$entry" >> "$tmp_file2"
            tail -n +"$((section_start + 2))" "$tmp_file" >> "$tmp_file2"
            mv "$tmp_file2" "$TODO_FILE"
            rm -f "$tmp_file"
        fi
    else
        mv "$tmp_file" "$TODO_FILE"
    fi

    echo "Added task $task_num to Recommended Order at position $insert_pos"
    return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 {add|remove|refresh} [TASK_NUM]" >&2
        return 1
    fi

    local command="$1"
    shift

    case "$command" in
        add)
            if [[ $# -lt 1 ]]; then
                echo "Usage: $0 add TASK_NUM" >&2
                return 1
            fi
            add_to_recommended_order "$1"
            ;;
        remove)
            if [[ $# -lt 1 ]]; then
                echo "Usage: $0 remove TASK_NUM" >&2
                return 1
            fi
            remove_from_recommended_order "$1"
            ;;
        refresh)
            refresh_recommended_order
            ;;
        *)
            echo "Unknown command: $command" >&2
            echo "Usage: $0 {add|remove|refresh} [TASK_NUM]" >&2
            return 1
            ;;
    esac
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
