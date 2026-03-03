# LEAN Command Execution Integration

This file integrates the LEAN-specific command functions with the core command execution system.

## Source this file
```bash
source "$OPENCODE_ROOT/context/core/patterns/command-execution.sh"
source "$OPENCODE_ROOT/context/core/patterns/lean-command-execution.sh"
source "$OPENCODE_ROOT/context/core/patterns/core-command-execution.sh"
```

## Function Registration

Register LEAN-specific commands with the execution router:

```bash
# Register LEAN command functions
execute_lean_command() {
  local command_name="$1"
  local arguments="$2"
  
  case "$command_name" in
    "lean-build")
      execute_lean_command_lean_build "$arguments"
      ;;
    "lean-test")
      execute_lean_command_lean_test "$arguments"
      ;;
    "lean-proof")
      execute_lean_command_lean_proof "$arguments"
      ;;
    "theorem-research")
      execute_lean_command_theorem_research "$arguments"
      ;;
    "proof-verify")
      execute_lean_command_proof_verify "$arguments"
      ;;
    "mathlib-search")
      execute_lean_command_mathlib_search "$arguments"
      ;;
    *)
      echo "Error: Unknown LEAN command: $command_name"
      return 1
      ;;
  esac
}
```