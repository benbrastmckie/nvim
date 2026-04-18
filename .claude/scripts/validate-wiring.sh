#!/usr/bin/env bash
# validate-wiring.sh - Validate agent systems wiring integrity
# Usage: ./validate-wiring.sh [--claude|--opencode|--all]

# Don't exit on error - we want to report all issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
SYSTEM="${1:-all}"

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Validate skill -> agent wiring
validate_skill_agent() {
    local system_dir="$1"
    local skill_name="$2"
    local expected_agent="$3"

    local skill_file="$system_dir/skills/$skill_name/SKILL.md"
    if [[ ! -f "$skill_file" ]]; then
        log_fail "$skill_name: SKILL.md not found"
        return 1
    fi

    # Check if skill references the expected agent
    if grep -q "$expected_agent" "$skill_file" 2>/dev/null; then
        log_pass "$skill_name -> $expected_agent"
        return 0
    else
        log_fail "$skill_name: does not reference $expected_agent"
        return 1
    fi
}

# Validate agent file exists
validate_agent_exists() {
    local agents_dir="$1"
    local agent_name="$2"

    local agent_file="$agents_dir/$agent_name.md"
    if [[ -f "$agent_file" ]]; then
        log_pass "Agent exists: $agent_name"
        return 0
    else
        log_fail "Agent missing: $agent_name"
        return 1
    fi
}

# Validate index.json entries for an agent
validate_index_entries() {
    local system_dir="$1"
    local agent_name="$2"

    local index_file="$system_dir/context/index.json"
    if [[ ! -f "$index_file" ]]; then
        log_fail "index.json not found: $index_file"
        return 1
    fi

    local count
    count=$(jq -r "[.entries[] | select(.load_when.agents[]? == \"$agent_name\")] | length" "$index_file" 2>/dev/null || echo "0")

    if [[ "$count" -gt 0 ]]; then
        log_pass "index.json: $agent_name has $count entries"
        return 0
    else
        log_warn "index.json: $agent_name has 0 entries"
        return 0
    fi
}

# Validate index.json entries for a task_type
validate_task_type_entries() {
    local system_dir="$1"
    local task_type="$2"

    local index_file="$system_dir/context/index.json"
    if [[ ! -f "$index_file" ]]; then
        log_fail "index.json not found"
        return 1
    fi

    local count
    count=$(jq -r "[.entries[] | select(.load_when.task_types[]? == \"$task_type\")] | length" "$index_file" 2>/dev/null || echo "0")

    if [[ "$count" -gt 0 ]]; then
        log_pass "index.json: task_type '$task_type' has $count entries"
        return 0
    else
        log_warn "index.json: task_type '$task_type' has 0 entries (extension not loaded?)"
        return 0
    fi
}

# Validate context files exist on disk
validate_context_files() {
    local system_dir="$1"

    local index_file="$system_dir/context/index.json"
    if [[ ! -f "$index_file" ]]; then
        log_fail "index.json not found"
        return 1
    fi

    local missing=0
    while IFS= read -r path; do
        local full_path="$system_dir/context/$path"
        if [[ ! -f "$full_path" ]]; then
            log_fail "Missing context file: $path"
            ((missing++))
        fi
    done < <(jq -r '.entries[].path' "$index_file" 2>/dev/null)

    if [[ "$missing" -eq 0 ]]; then
        log_pass "All context files exist on disk"
        return 0
    else
        return 1
    fi
}

# Validate core system
validate_core_system() {
    local system_dir="$1"
    local system_name="$2"
    local agents_subdir="$3"

    echo ""
    log_info "Validating $system_name core system..."
    echo "----------------------------------------"

    # Check core agents exist
    log_info "Checking core agents..."
    validate_agent_exists "$system_dir/$agents_subdir" "general-research-agent"
    validate_agent_exists "$system_dir/$agents_subdir" "general-implementation-agent"
    validate_agent_exists "$system_dir/$agents_subdir" "planner-agent"
    validate_agent_exists "$system_dir/$agents_subdir" "meta-builder-agent"

    # Check core skills exist
    log_info "Checking core skills..."
    for skill in skill-researcher skill-implementer skill-planner skill-meta; do
        if [[ -d "$system_dir/skills/$skill" ]]; then
            log_pass "Skill exists: $skill"
        else
            log_fail "Skill missing: $skill"
        fi
    done

    # Check core rules exist
    log_info "Checking core rules..."
    for rule in artifact-formats.md error-handling.md git-workflow.md state-management.md workflows.md; do
        if [[ -f "$system_dir/rules/$rule" ]]; then
            log_pass "Rule exists: $rule"
        else
            log_fail "Rule missing: $rule"
        fi
    done

    # Check index.json integrity
    log_info "Checking index.json..."
    local entry_count
    entry_count=$(jq '.entries | length' "$system_dir/context/index.json" 2>/dev/null || echo "0")
    log_info "index.json has $entry_count entries"

    validate_context_files "$system_dir"

    # Check core agent context entries
    log_info "Checking core agent index entries..."
    validate_index_entries "$system_dir" "planner-agent"
    validate_index_entries "$system_dir" "general-implementation-agent"
    validate_index_entries "$system_dir" "meta-builder-agent"

    # Check core task_type routing
    log_info "Checking core task_type routing..."
    validate_task_type_entries "$system_dir" "meta"
}

# Validate extensions loaded
validate_extensions_loaded() {
    local system_dir="$1"
    local system_name="$2"
    local agents_subdir="$3"

    echo ""
    log_info "Validating $system_name extension wiring (if loaded)..."
    echo "----------------------------------------"

    local extensions_file="$system_dir/extensions.json"
    if [[ ! -f "$extensions_file" ]]; then
        log_info "No extensions.json found - extensions not loaded"
        return 0
    fi

    # List loaded extensions
    local loaded
    loaded=$(jq -r '.extensions | keys[]' "$extensions_file" 2>/dev/null | tr '\n' ' ')
    log_info "Loaded extensions: ${loaded:-none}"

    # For each loaded extension, validate its wiring
    while IFS= read -r ext_name; do
        [[ -z "$ext_name" ]] && continue

        log_info "Validating extension: $ext_name"

        # Check extension agents exist
        case "$ext_name" in
            nvim)
                validate_agent_exists "$system_dir/$agents_subdir" "neovim-research-agent"
                validate_agent_exists "$system_dir/$agents_subdir" "neovim-implementation-agent"
                validate_index_entries "$system_dir" "neovim-research-agent"
                validate_language_entries "$system_dir" "neovim"
                ;;
            lean)
                validate_agent_exists "$system_dir/$agents_subdir" "lean-research-agent"
                validate_agent_exists "$system_dir/$agents_subdir" "lean-implementation-agent"
                validate_index_entries "$system_dir" "lean-research-agent"
                validate_language_entries "$system_dir" "lean4"
                ;;
            latex)
                validate_agent_exists "$system_dir/$agents_subdir" "latex-research-agent"
                validate_agent_exists "$system_dir/$agents_subdir" "latex-implementation-agent"
                validate_language_entries "$system_dir" "latex"
                ;;
            typst)
                validate_agent_exists "$system_dir/$agents_subdir" "typst-research-agent"
                validate_agent_exists "$system_dir/$agents_subdir" "typst-implementation-agent"
                validate_language_entries "$system_dir" "typst"
                ;;
            formal)
                validate_agent_exists "$system_dir/$agents_subdir" "formal-research-agent"
                validate_agent_exists "$system_dir/$agents_subdir" "logic-research-agent"
                validate_index_entries "$system_dir" "logic-research-agent"
                ;;
            *)
                log_info "Extension $ext_name: skipping detailed checks"
                ;;
        esac
    done < <(jq -r '.extensions | keys[]' "$extensions_file" 2>/dev/null)
}

# Main validation
main() {
    echo "========================================"
    echo "Agent Systems Wiring Validation"
    echo "========================================"

    if [[ "$SYSTEM" == "all" || "$SYSTEM" == "--all" || "$SYSTEM" == "--claude" ]]; then
        validate_core_system "$PROJECT_ROOT/.claude" ".claude" "agents"
        validate_extensions_loaded "$PROJECT_ROOT/.claude" ".claude" "agents"
    fi

    if [[ "$SYSTEM" == "all" || "$SYSTEM" == "--all" || "$SYSTEM" == "--opencode" ]]; then
        validate_core_system "$PROJECT_ROOT/.opencode" ".opencode" "agent/subagents"
        validate_extensions_loaded "$PROJECT_ROOT/.opencode" ".opencode" "agent/subagents"
    fi

    # Summary
    echo ""
    echo "========================================"
    echo "Validation Summary"
    echo "========================================"
    echo -e "Passed:   ${GREEN}$PASSED${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
    echo -e "Failed:   ${RED}$FAILED${NC}"
    echo ""

    if [[ "$FAILED" -gt 0 ]]; then
        echo -e "${RED}VALIDATION FAILED${NC}"
        exit 1
    elif [[ "$WARNINGS" -gt 0 ]]; then
        echo -e "${YELLOW}VALIDATION PASSED WITH WARNINGS${NC}"
        exit 0
    else
        echo -e "${GREEN}VALIDATION PASSED${NC}"
        exit 0
    fi
}

main "$@"
