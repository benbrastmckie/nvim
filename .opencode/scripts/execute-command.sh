#!/usr/bin/env bash
#
# execute-command.sh - Command execution router for .opencode system
# Usage: execute-command.sh COMMAND_NAME [ARGUMENTS...]
#
# This script routes slash commands to appropriate command definitions
# and executes them using bash, replacing the missing Python entry point
#

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
  echo "Usage: execute-command.sh COMMAND_NAME [ARGUMENTS...]"
  echo ""
  echo "Available commands:"
  ls .opencode/commands/*.md | sed 's/\.opencode\/command\///g' | sed 's/\.md$//g' | sort
  exit 1
fi

command_name="$1"
shift
arguments="$@"

# Command directory and file
command_dir=".opencode/command"
command_file="${command_dir}/${command_name}.md"

# Validate command exists
if [ ! -f "$command_file" ]; then
  echo "Error: Command '$command_name' not found at $command_file"
  echo "Available commands:"
  ls "$command_dir"/*.md | sed 's/\.opencode\/command\///g' | sed 's/\.md$//g' | sort
  exit 1
fi

# Extract command description from frontmatter
command_description=$(grep -A1 '^description:' "$command_file" | tail -1 | sed 's/.*: *//' | sed 's/"//g')

echo "=== Executing Command: $command_name ==="
echo "Description: $command_description"
echo "Arguments: $arguments"
echo ""

# Set environment variables for the command
export COMMAND_NAME="$command_name"
export ARGUMENTS="$arguments"
export OPENCODE_ROOT=".opencode"

# Execute command based on its type
case "$command_name" in
  "task"|"research"|"plan"|"implement"|"revise"|"review"|"meta"|"learn"|"refresh"|"convert"|"errors"|"todo")
    # Core workflow commands - execute with full context
    "task"|"research"|"plan"|"implement"|"revise"|"review"|"meta"|"learn"|"refresh"|"convert"|"errors"|"todo")
    echo "Loading context for $command_name..."
    exec <(echo "#! /usr/bin/env bash"; echo "set -euo pipefail"; echo ""; echo "# Command: $command_name"; echo "# Arguments: $arguments"; echo ""; echo "# Load command definition and execute"; echo "source \"$OPENCODE_ROOT/context/core/patterns/command-integration.sh\""; echo "execute_lean_command \"$command_name\" \"$arguments\"")
    ;;
  "lean-build"|"lean-test"|"lean-proof"|"theorem-research"|"proof-verify"|"mathlib-search")
    echo "Loading LEAN context for $command_name..."
    exec <(echo "#! /usr/bin/env bash"; echo "set -euo pipefail"; echo ""; echo "# Command: $command_name"; echo "# Arguments: $arguments"; echo ""; echo "# LEAN 4 specific execution"; echo "source \"$OPENCODE_ROOT/context/core/patterns/command-integration.sh\""; echo "execute_lean_command \"$command_name\" \"$arguments\"")
    ;;
  *)
    echo "Error: Unknown command type '$command_name'"
    echo "Supported command types:"
    echo "  Core workflows: task, research, plan, implement, revise, review, meta, learn, refresh, convert, errors, todo"
    echo "  LEAN-specific: lean-build, lean-test, lean-proof, theorem-research, proof-verify, mathlib-search"
    exit 1
    ;;
esac