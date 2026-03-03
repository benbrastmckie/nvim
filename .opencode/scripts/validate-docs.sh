#!/bin/bash
# Documentation Validation Script
# Task 179 - Validates .opencode/ documentation integrity

set -e

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "Documentation Validation Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to report errors
report_error() {
    echo -e "${RED}ERROR:${NC} $1"
    ((ERRORS++))
}

# Function to report warnings
report_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
    ((WARNINGS++))
}

# Function to report success
report_success() {
    echo -e "${GREEN}OK:${NC} $1"
}

echo "1. Checking for .opencode_NEW references..."
OPENCODE_NEW_COUNT=$(grep -r "\.opencode_NEW" .opencode/ --include="*.md" 2>/dev/null | grep -v "documentation-maintenance.md" | grep -v "documentation-audit-checklist.md" | wc -l)
if [ "$OPENCODE_NEW_COUNT" -gt 0 ]; then
    report_error "Found $OPENCODE_NEW_COUNT references to .opencode_NEW (should be .opencode)"
    grep -r "\.opencode_NEW" .opencode/ --include="*.md" 2>/dev/null | grep -v "documentation-maintenance.md" | grep -v "documentation-audit-checklist.md" | head -5
else
    report_success "No .opencode_NEW references found"
fi
echo ""

echo "2. Checking for command/ vs commands/..."
COMMAND_COUNT=$(grep -r "command/" .opencode/ --include="*.md" 2>/dev/null | grep -v "commands/" | grep -v "typst-implementation-agent.md" | grep -v "output/" | grep -v "documentation-audit-checklist.md" | wc -l)
if [ "$COMMAND_COUNT" -gt 0 ]; then
    report_error "Found $COMMAND_COUNT references to command/ (should be commands/)"
    grep -r "command/" .opencode/ --include="*.md" 2>/dev/null | grep -v "commands/" | grep -v "typst-implementation-agent.md" | grep -v "output/" | grep -v "documentation-audit-checklist.md" | head -5
else
    report_success "No command/ references found"
fi
echo ""

echo "3. Checking for non-existent commands in QUICK-START.md..."
INVALID_COMMANDS=0
for cmd in "/lean-build" "/lean-test" "/lean-proof" "/theorem-research" "/mathlib-search"; do
    if grep -q "$cmd" .opencode/QUICK-START.md 2>/dev/null; then
        report_error "Found non-existent command: $cmd"
        ((INVALID_COMMANDS++))
    fi
done
if [ "$INVALID_COMMANDS" -eq 0 ]; then
    report_success "All commands in QUICK-START.md are valid"
fi
echo ""

echo "4. Checking for lean_diagnostic_messages in essential tools..."
if grep -q "lean_diagnostic_messages" .opencode/rules/lean4.md 2>/dev/null; then
    # Check if it's in the Essential Tools section
    if grep -A 10 "Essential Tools" .opencode/rules/lean4.md | grep -q "lean_diagnostic_messages"; then
        report_error "lean_diagnostic_messages found in Essential Tools (it's blocked)"
    else
        report_warning "lean_diagnostic_messages mentioned but not in Essential Tools"
    fi
else
    report_success "lean_diagnostic_messages not in essential tools list"
fi
echo ""

echo "5. Checking for ProofChecker references (excluding historical)..."
PROOFCHECKER_COUNT=$(grep -r "ProofChecker" .opencode/ --include="*.md" 2>/dev/null | grep -v "historical" | grep -v "documentation-maintenance.md" | grep -v "documentation-audit-checklist.md" | wc -l)
if [ "$PROOFCHECKER_COUNT" -gt 0 ]; then
    report_error "Found $PROOFCHECKER_COUNT ProofChecker references (should be Logos/Theory)"
    grep -r "ProofChecker" .opencode/ --include="*.md" 2>/dev/null | grep -v "historical" | grep -v "documentation-maintenance.md" | grep -v "documentation-audit-checklist.md" | head -5
else
    report_success "No incorrect ProofChecker references found"
fi
echo ""

echo "6. Checking for ARCHITECTURE.md references..."
ARCH_COUNT=$(grep -r "ARCHITECTURE\.md" .opencode/ --include="*.md" 2>/dev/null | grep -v "documentation-audit-checklist.md" | wc -l)
if [ "$ARCH_COUNT" -gt 0 ]; then
    report_error "Found $ARCH_COUNT ARCHITECTURE.md references (file doesn't exist)"
    grep -r "ARCHITECTURE\.md" .opencode/ --include="*.md" 2>/dev/null | grep -v "documentation-audit-checklist.md" | head -5
else
    report_success "No ARCHITECTURE.md references found"
fi
echo ""

echo "7. Checking component counts..."
CMD_COUNT=$(ls .opencode/commands/*.md 2>/dev/null | wc -l)
SKILL_COUNT=$(find .opencode/skills -name "SKILL.md" 2>/dev/null | wc -l)
AGENT_COUNT=$(ls .opencode/agent/subagents/*.md 2>/dev/null | wc -l)

echo "   Commands: $CMD_COUNT (expected: 15)"
echo "   Skills: $SKILL_COUNT (expected: 20)"
echo "   Agents: $AGENT_COUNT (expected: 14)"

if [ "$CMD_COUNT" -ne 15 ]; then
    report_warning "Command count mismatch: $CMD_COUNT vs 15"
fi
if [ "$SKILL_COUNT" -ne 20 ]; then
    report_warning "Skill count mismatch: $SKILL_COUNT vs 20"
fi
if [ "$AGENT_COUNT" -ne 14 ]; then
    report_warning "Agent count mismatch: $AGENT_COUNT vs 14"
fi
echo ""

echo "8. Checking orchestrator.md name field..."
if [ -f ".opencode/agent/orchestrator.md" ]; then
    ORCH_NAME=$(grep "^name:" .opencode/agent/orchestrator.md | head -1)
    if echo "$ORCH_NAME" | grep -q "orchestrator"; then
        report_success "Orchestrator has correct name field: $ORCH_NAME"
    else
        report_error "Orchestrator has incorrect name field: $ORCH_NAME (should be orchestrator)"
    fi
else
    report_error "orchestrator.md not found"
fi
echo ""

echo "9. Checking for LEAN 4 capitalization..."
LEAN4_COUNT=$(grep -r "LEAN 4" .opencode/ --include="*.md" 2>/dev/null | wc -l)
if [ "$LEAN4_COUNT" -gt 0 ]; then
    report_warning "Found $LEAN4_COUNT 'LEAN 4' references (should be 'Lean 4')"
    grep -r "LEAN 4" .opencode/ --include="*.md" 2>/dev/null | head -3
else
    report_success "No 'LEAN 4' capitalization issues found"
fi
echo ""

echo "10. Checking for emojis..."
EMOJI_COUNT=$(grep -rE "[🚀⚡🎯✨🔧📊💡📝🔍⚠️✅❌🎉🔥⭐🎨💻🌐📚🔗💾🔒🔑🎮🎲]" .opencode/ --include="*.md" 2>/dev/null | wc -l)
if [ "$EMOJI_COUNT" -gt 0 ]; then
    report_warning "Found $EMOJI_COUNT emoji references"
    grep -rE "[🚀⚡🎯✨🔧📊💡📝🔍⚠️✅❌🎉🔥⭐🎨💻🌐📚🔗💾🔒🔑🎮🎲]" .opencode/ --include="*.md" 2>/dev/null | head -3
else
    report_success "No emojis found in documentation"
fi
echo ""

echo "=========================================="
echo "Validation Complete"
echo "=========================================="
echo ""
echo "Results:"
echo -e "  Errors: ${RED}$ERRORS${NC}"
echo -e "  Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed! Documentation is healthy.${NC}"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}Documentation has warnings but no critical errors.${NC}"
    exit 0
else
    echo -e "${RED}Documentation has critical errors that need immediate attention.${NC}"
    exit 1
fi
