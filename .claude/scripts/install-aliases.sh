#!/usr/bin/env bash
#
# install-aliases.sh - Install Claude Code refresh and cleanup aliases
#
# This script adds helpful aliases to your shell configuration:
#   - claude-refresh: Show orphaned process status
#   - claude-refresh-force: Force terminate orphaned processes
#   - claude-cleanup: Preview directory cleanup (dry-run)
#   - claude-cleanup-force: Force cleanup with 8-hour threshold
#   - claude-cleanup-all: Clean everything except safety margin
#
# Usage: ./install-aliases.sh [--uninstall]

set -euo pipefail

# Detect shell config file
detect_shell_config() {
    # Check for common shell config files
    if [ -n "${ZSH_VERSION:-}" ] || [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
        if [ -f "$HOME/.zshrc" ]; then
            echo "$HOME/.zshrc"
            return
        fi
    fi

    if [ -n "${BASH_VERSION:-}" ] || [ "$SHELL" = "/bin/bash" ] || [ "$SHELL" = "/usr/bin/bash" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            echo "$HOME/.bashrc"
            return
        fi
    fi

    # Fallback checks
    for config in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$config" ]; then
            echo "$config"
            return
        fi
    done

    echo ""
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFRESH_SCRIPT="$SCRIPT_DIR/claude-refresh.sh"
CLEANUP_SCRIPT="$SCRIPT_DIR/claude-cleanup.sh"

# Alias block markers
ALIAS_START="# >>> Claude Code refresh aliases >>>"
ALIAS_END="# <<< Claude Code refresh aliases <<<"

# Generate alias block
generate_aliases() {
    cat << EOF
$ALIAS_START
# Show orphaned process status
alias claude-refresh='$REFRESH_SCRIPT'

# Force terminate orphaned processes
alias claude-refresh-force='$REFRESH_SCRIPT --force'

# Comprehensive ~/.claude/ directory cleanup (dry-run preview)
alias claude-cleanup='$CLEANUP_SCRIPT --dry-run'

# Force cleanup with 8-hour default
alias claude-cleanup-force='$CLEANUP_SCRIPT --force --age 8'

# Clean slate - remove everything except safety margin (interactive confirmation)
alias claude-cleanup-all='$CLEANUP_SCRIPT --age 0'
$ALIAS_END
EOF
}

# Check if aliases already installed (check both old and new markers)
check_installed() {
    local config="$1"
    if grep -q "$ALIAS_START" "$config" 2>/dev/null; then
        return 0  # installed (new style)
    fi
    if grep -q "Claude Code cleanup aliases" "$config" 2>/dev/null; then
        return 0  # installed (old style)
    fi
    return 1  # not installed
}

# Install aliases
install_aliases() {
    local config="$1"

    if check_installed "$config"; then
        echo "Aliases already installed in $config"
        echo "Run with --uninstall first to reinstall."
        exit 0
    fi

    echo "" >> "$config"
    generate_aliases >> "$config"

    echo "Aliases installed in $config"
    echo ""
    echo "Available aliases:"
    echo "  claude-refresh        - Show orphaned process status"
    echo "  claude-refresh-force  - Force terminate orphaned processes"
    echo "  claude-cleanup        - Preview directory cleanup (dry-run)"
    echo "  claude-cleanup-force  - Force cleanup with 8-hour threshold"
    echo "  claude-cleanup-all    - Clean everything except safety margin"
    echo ""
    echo "Run 'source $config' or start a new shell to use the aliases."
}

# Uninstall aliases (handles both old and new markers)
uninstall_aliases() {
    local config="$1"

    if ! check_installed "$config"; then
        echo "Aliases not found in $config"
        exit 0
    fi

    # Remove new style alias block
    sed -i "/$ALIAS_START/,/$ALIAS_END/d" "$config"

    # Remove old style alias block (for migration)
    sed -i '/# >>> Claude Code cleanup aliases >>>/,/# <<< Claude Code cleanup aliases <<</d' "$config"

    echo "Aliases removed from $config"
}

# Main
UNINSTALL=false
for arg in "$@"; do
    case $arg in
        --uninstall)
            UNINSTALL=true
            ;;
        --help|-h)
            echo "Usage: $0 [--uninstall]"
            echo ""
            echo "Installs Claude Code refresh aliases to your shell config."
            echo ""
            echo "Options:"
            echo "  --uninstall  Remove previously installed aliases"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

# Find shell config
SHELL_CONFIG=$(detect_shell_config)

if [ -z "$SHELL_CONFIG" ]; then
    echo "Error: Could not detect shell configuration file."
    echo "Please manually add the aliases to your shell config."
    echo ""
    echo "Aliases to add:"
    generate_aliases
    exit 1
fi

echo "Detected shell config: $SHELL_CONFIG"

if $UNINSTALL; then
    uninstall_aliases "$SHELL_CONFIG"
else
    install_aliases "$SHELL_CONFIG"
fi
