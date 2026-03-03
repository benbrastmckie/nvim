# .opencode System Quick Start

## System Status: FULLY FUNCTIONAL

The .opencode/ system has been successfully overhauled and is now ready for Lean 4 theorem proving workflows.

## Key Improvement

**BEFORE**: Commands failed with "poetry: command not found"  
**AFTER**: All commands execute through robust bash infrastructure

## How to Use

### Basic Commands
```bash
# Task management
/task --help                    # Show task options
/task "Create new task"           # Create a new task
/research TASK_NUMBER              # Research a task
/plan TASK_NUMBER                # Create implementation plan
/implement TASK_NUMBER           # Implement a task

# Lean 4 specific commands
/lake --help                     # Lake build system
/lean --check                    # Check Lean toolchain
/lean --upgrade                  # Upgrade Mathlib
```

### Examples

#### Create a Lean 4 Task
```bash
/task "Prove continuity theorem in Logos layer" --priority high --language lean
```

#### Research with Lean Tools
```bash
/research 456 "Focus on Mathlib's continuity module"
```

#### Build and Test Lean 4 Project
```bash
/lake --clean          # Clean and rebuild
/lake --max-retries 3  # Build with auto-retry
```

## System Architecture

### Command Execution Flow
```
Command → execute-command.sh → Command Definition → Bash Execution
```

### Agent Delegation
```
Command → Skill → Agent → Return → Command completes
```

### Context Loading
```
Command Type → Context Files → Specialized Knowledge
```

## Key Components

### Command Infrastructure
- **execute-command.sh**: Main router for all commands
- **command-execution.sh**: Core execution patterns
- **lean-command-execution.sh**: Lean 4 specific functions

### Lean 4 Integration
- **Lake Build System**: Automatic project building
- **Mathlib Search**: LeanSearch and Loogle integration
- **Proof Development**: Interactive Lean 4 proof editing
- **Verification**: Automated proof checking

### Context Organization
- **Lean 4 Standards**: Coding conventions and best practices
- **Theorem Library**: Existing proofs and definitions
- **Tool Integration**: Mathlib, LeanSearch, LSP guides

## Success Indicators

### Command Execution
- No more "poetry: command not found" errors
- All commands route correctly to bash scripts
- Comprehensive error handling

### Lean 4 Workflows  
- Lake build system integration
- Mathlib search functionality
- Interactive proof development
- Automated proof verification

### System Integration
- All components work together seamlessly
- Agent delegation chains functional
- Task state management synchronized

## Documentation

- **Full Guide**: `.opencode/README.md`
- **Architecture**: `.opencode/docs/architecture/system-overview.md`
- **Command Reference**: `.opencode/commands/README.md`
- **Context Index**: `.opencode/context/index.md`

## Ready for Production

The .opencode/ system is now production-ready for Lean 4 theorem proving and formal verification workflows.

**First Commands to Try**:
1. `/task --help` - Explore task management
2. `/lake --help` - Test Lean integration
3. `/research 673 --help` - Test research workflows

All commands now execute successfully through the new bash infrastructure, providing a robust foundation for Lean 4 development and theorem proving.
