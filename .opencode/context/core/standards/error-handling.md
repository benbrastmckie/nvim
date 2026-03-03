# Error Handling Standard

**Purpose**: Comprehensive error handling patterns, formats, and recovery strategies for agents, subagents, and commands.

**Scope**: All error detection, handling, logging, and user communication across the system.

---

## Core Principles

### 1. Fail Gracefully

**ALWAYS** handle errors gracefully:
- Catch specific errors, not generic ones
- Provide clear, actionable error messages
- Include recovery instructions when possible
- Never expose internal implementation details
- Log errors with sufficient context for debugging

### 2. Fail Fast

**DETECT** errors early:
- Validate inputs before processing
- Check preconditions before operations
- Verify dependencies before delegation
- Test critical paths before execution

### 3. Fail Informatively

**COMMUNICATE** errors clearly:
- State what went wrong
- Explain why it happened (if known)
- Provide recovery steps
- Include relevant context (file paths, values, etc.)
- Reference documentation when applicable

### 4. Fail Safely

**PROTECT** system state:
- Use git safety commits before risky operations
- Rollback on failure when possible
- Log errors for post-mortem analysis
- Preserve user data and work
- Avoid cascading failures

---

## Error Format Standards

### User-Facing Error Messages

**Format**:
```
Error: {brief_description}

{detailed_explanation}

{recovery_instructions}

{additional_context}
```

**Example**:
```
Error: Task number required

The /research command requires a task number as the first argument.

Usage: /research TASK_NUMBER [PROMPT]

Examples:
- /research 197
- /research 197 'Focus on CLI integration'
```

### Warning Messages

**Format**:
```
Warning: {brief_description}

{explanation}

{recommendation}
```

**Example**:
```
Warning: Operation succeeded but git commit failed

Changes were successfully applied but could not be committed to git.

Manual commit required:
  git add Logos/Theory/Lattices.lean
  git commit -m "feat: Add lattice definitions"

Error: fatal: not a git repository
```

### Critical Error Messages

**Format**:
```
CRITICAL ERROR: {brief_description}

{explanation}

Manual recovery required:
{step_by_step_instructions}

{additional_help}
```

**Example**:
```
CRITICAL ERROR: Automatic rollback failed

Git reset failed during error recovery. Your working directory may be in an inconsistent state.

Manual recovery required:
1. Check git status: git status
2. Reset to safety commit: git reset --hard abc123
3. Clean untracked files: git clean -fd
4. Verify state: git status

Safety commit SHA: abc123

If issues persist, contact support with this error log.
```

---

## XML Error Handling Pattern

### Standard Structure

```xml
<error_handling>
  <error_type name="{error_type}">
    <detection>{How to detect this error}</detection>
    <handling>{How to handle this error}</handling>
    <recovery>{Recovery instructions for user}</recovery>
    <logging>{What to log to errors.json}</logging>
  </error_type>
</error_handling>
```

### Components

**`<detection>`**: Conditions that indicate this error
- Specific error codes or messages
- State conditions
- Validation failures
- Timeout conditions

**`<handling>`**: Internal error handling logic
- Immediate actions to take
- State cleanup required
- Rollback procedures
- Delegation to error handlers

**`<recovery>`**: User-facing recovery instructions
- Clear, actionable steps
- Manual recovery procedures
- Alternative approaches
- Contact information if needed

**`<logging>`**: Error logging requirements
- What to log to errors.json
- Log level (error, warning, critical)
- Context to include
- Correlation IDs or session IDs

---

## Common Error Types

### 1. Validation Errors

**When**: Input validation fails

```xml
<error_type name="validation_failure">
  <detection>
    - Required argument missing
    - Invalid argument format
    - Argument out of valid range
    - Type mismatch
  </detection>
  <handling>
    1. Identify which validation failed
    2. Return error immediately (fail fast)
    3. Include usage examples
    4. Do not proceed with operation
  </handling>
  <recovery>
    Error: {validation_error}
    
    {explanation_of_requirement}
    
    Usage: {command_syntax}
    
    Examples:
    - {example_1}
    - {example_2}
  </recovery>
  <logging>
    Log validation error with:
    - Command/function name
    - Invalid input value
    - Validation rule that failed
  </logging>
</error_type>
```

**Example**:
```
Error: Task number must be an integer

The task number argument must be a valid integer.

Got: 'abc'

Usage: /research TASK_NUMBER [PROMPT]
Example: /research 197
```

### 2. File Operation Errors

**When**: File read/write/delete operations fail

```xml
<error_type name="file_operation_failure">
  <detection>
    - File not found
    - Permission denied
    - Disk full
    - Invalid path
    - File locked
  </detection>
  <handling>
    1. Catch file system error
    2. Determine error type (not found, permission, etc.)
    3. Check if operation is critical or optional
    4. If critical: return error and stop
    5. If optional: log warning and continue
  </handling>
  <recovery>
    Error: Failed to {operation} file
    
    File: {file_path}
    Reason: {error_reason}
    
    {recovery_steps}
  </recovery>
  <logging>
    Log with:
    - Operation type (read/write/delete)
    - File path
    - Error message
    - Stack trace (if available)
  </logging>
</error_type>
```

**Example**:
```
Error: Failed to read file

File: specs/TODO.md
Reason: No such file or directory

Recovery:
1. Verify the file path is correct
2. Check if the file exists: ls -la specs/
3. Create the file if needed: touch specs/TODO.md
```

### 3. Delegation Errors

**When**: Subagent delegation fails

```xml
<error_type name="delegation_failure">
  <detection>
    - Subagent not found
    - Subagent timeout
    - Subagent returned error status
    - Invalid subagent response format
  </detection>
  <handling>
    1. Detect delegation failure type
    2. Log delegation error with context
    3. If retryable: attempt retry (max 1 retry)
    4. If not retryable: return error to user
    5. Include subagent name and task in error
  </handling>
  <recovery>
    Error: Subagent delegation failed
    
    Subagent: {subagent_name}
    Task: {task_description}
    Reason: {failure_reason}
    
    {recovery_instructions}
  </recovery>
  <logging>
    Log with:
    - Subagent name
    - Task description
    - Failure reason
    - Session ID
    - Retry attempts
  </logging>
</error_type>
```

**Example**:
```
Error: Subagent delegation failed

Subagent: @subagents/lean/proof-planner
Task: Generate proof plan for lattice theorem
Reason: Subagent timeout after 120 seconds

This may indicate:
- Complex task requiring more time
- Subagent stuck in infinite loop
- Resource constraints

Try:
1. Simplify the task
2. Break into smaller subtasks
3. Check subagent logs for details
```

### 4. Git Operation Errors

**When**: Git operations fail

```xml
<error_type name="git_failure">
  <detection>
    - git command returns non-zero exit code
    - git repository not found
    - git merge conflict
    - git authentication failure
  </detection>
  <handling>
    1. Determine if git operation is critical
    2. If safety commit: return error, don't proceed
    3. If final commit: log warning, return success
    4. If rollback: escalate to critical error
    5. Include git error message in response
  </handling>
  <recovery>
    {See specific git error types below}
  </recovery>
  <logging>
    Log with:
    - Git command executed
    - Exit code
    - Error output
    - Working directory state
  </logging>
</error_type>
```

**Specific Git Error Types**:

#### Safety Commit Failure
```
Error: Failed to create safety commit

Git status: {git_status}

This safety commit protects your work before making changes.

Recommendation:
1. Ensure git is configured: git config --list
2. Check working directory is clean: git status
3. Fix any git issues and retry
```

#### Final Commit Failure
```
Warning: Operation succeeded but git commit failed

Changes made:
- {change_1}
- {change_2}

Manual commit required:
  git add {files}
  git commit -m "{operation}: {description}"

Error: {git_error}
```

#### Rollback Failure
```
CRITICAL ERROR: Automatic rollback failed

Safety commit: {safety_commit_sha}

Manual recovery steps:
1. Check git status: git status
2. Reset to safety commit: git reset --hard {safety_commit_sha}
3. Clean untracked files: git clean -fd
4. Verify state: git status

Or restore from git reflog:
1. View reflog: git reflog
2. Find safety commit: {safety_commit_sha}
3. Reset: git reset --hard {safety_commit_sha}

Error: {git_error}
```

### 5. Timeout Errors

**When**: Operations exceed time limits

```xml
<error_type name="timeout">
  <detection>
    - Operation exceeds configured timeout
    - Subagent doesn't respond within limit
    - External API call times out
  </detection>
  <handling>
    1. Cancel ongoing operation if possible
    2. Log timeout event with duration
    3. Return timeout error to user
    4. Suggest alternatives or retry
  </handling>
  <recovery>
    Error: Operation timed out
    
    Operation: {operation_name}
    Timeout: {timeout_duration} seconds
    
    This may indicate:
    - Task is too complex
    - System is under heavy load
    - External dependency is slow
    
    Try:
    - Simplify the task
    - Retry the operation
    - Break into smaller steps
  </recovery>
  <logging>
    Log timeout event with:
    - Operation name
    - Configured timeout
    - Actual duration
    - Session ID
  </logging>
</error_type>
```

### 6. Dependency Errors

**When**: Required dependencies are missing or unavailable

```xml
<error_type name="dependency_failure">
  <detection>
    - Required tool not found in PATH
    - Required file missing
    - Required service unavailable
    - MCP server not configured
    - API endpoint unreachable
  </detection>
  <handling>
    1. Detect which dependency is missing
    2. Check if dependency is required or optional
    3. If required: return error immediately
    4. If optional: log warning and use fallback
    5. Provide installation/setup instructions
  </handling>
  <recovery>
    Error: Required dependency not available
    
    Dependency: {dependency_name}
    Required for: {operation_name}
    
    Setup instructions:
    {installation_steps}
    
    Verification:
    {verification_command}
  </recovery>
  <logging>
    Log with:
    - Dependency name
    - Operation requiring it
    - Detection method
  </logging>
</error_type>
```

**Example**:
```
Error: Lean MCP server not available

The Lean proof assistant requires the MCP server to be configured.

Setup instructions:
1. Verify .mcp.json exists: cat .mcp.json
2. Check server configuration:
   {
     "mcpServers": {
       "lean": {
         "command": "lean",
         "args": ["--server"]
       }
     }
   }
3. Test server: lean --version

Verification:
  lean --server --help
```

### 7. State Errors

**When**: System state is invalid or inconsistent

```xml
<error_type name="state_error">
  <detection>
    - State file corrupted
    - State file missing required fields
    - State version mismatch
    - Concurrent modification detected
  </detection>
  <handling>
    1. Attempt to load backup state
    2. If backup valid: restore and continue
    3. If no backup: initialize fresh state
    4. Log state error with details
    5. Notify user of state recovery
  </handling>
  <recovery>
    Error: System state error
    
    Issue: {state_issue}
    
    Recovery action taken:
    {recovery_action}
    
    {user_action_required}
  </recovery>
  <logging>
    Log with:
    - State file path
    - Error details
    - Recovery action taken
    - Backup used (if any)
  </logging>
</error_type>
```

### 8. Parse Errors

**When**: Parsing structured data fails

```xml
<error_type name="parse_error">
  <detection>
    - JSON parse failure
    - YAML parse failure
    - Markdown frontmatter invalid
    - XML malformed
  </detection>
  <handling>
    1. Identify parse error location (line/column)
    2. Extract context around error
    3. Suggest fix if pattern is recognized
    4. Return detailed error with context
  </handling>
  <recovery>
    Error: Failed to parse {format}
    
    File: {file_path}
    Line: {line_number}
    Column: {column_number}
    
    Error: {parse_error_message}
    
    Context:
    {code_context}
    
    {suggested_fix}
  </recovery>
  <logging>
    Log with:
    - File path
    - Format type
    - Error location
    - Error message
  </logging>
</error_type>
```

---

## Error Handling in Code

### JavaScript/TypeScript

```javascript
// [PASS] Explicit error handling with Result type
function parseJSON(text) {
  try {
    return { success: true, data: JSON.parse(text) };
  } catch (error) {
    return { 
      success: false, 
      error: error.message,
      context: { input: text.substring(0, 100) }
    };
  }
}

// [PASS] Validate at boundaries
function createUser(userData) {
  const validation = validateUserData(userData);
  if (!validation.isValid) {
    return { 
      success: false, 
      errors: validation.errors,
      message: 'User data validation failed'
    };
  }
  
  try {
    const user = saveUser(userData);
    return { success: true, user };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      message: 'Failed to save user'
    };
  }
}

// [PASS] Async error handling
async function fetchData(url) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      return {
        success: false,
        error: `HTTP ${response.status}: ${response.statusText}`,
        statusCode: response.status
      };
    }
    const data = await response.json();
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      message: 'Network request failed'
    };
  }
}
```

### Python

```python
# [PASS] Explicit error handling
def parse_json(text: str) -> dict:
    try:
        return {"success": True, "data": json.loads(text)}
    except json.JSONDecodeError as e:
        return {
            "success": False,
            "error": str(e),
            "line": e.lineno,
            "column": e.colno
        }

# [PASS] Custom exceptions
class ValidationError(Exception):
    def __init__(self, message: str, errors: list):
        self.message = message
        self.errors = errors
        super().__init__(self.message)

def create_user(user_data: dict) -> dict:
    errors = validate_user_data(user_data)
    if errors:
        raise ValidationError("User data validation failed", errors)
    
    try:
        user = save_user(user_data)
        return {"success": True, "user": user}
    except Exception as e:
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to save user"
        }
```

### Lean 4

```lean
-- [PASS] Error handling with Option
def safeDivide (n m : Nat) : Option Nat :=
  if m = 0 then
    none
  else
    some (n / m)

-- [PASS] Error handling with Except
def parseNat (s : String) : Except String Nat :=
  match s.toNat? with
  | some n => Except.ok n
  | none => Except.error s!"Failed to parse '{s}' as natural number"

-- [PASS] Error handling with custom error type
inductive ParseError
  | invalidFormat (msg : String)
  | outOfRange (value : Int) (min max : Int)
  | missingField (field : String)

def parseConfig (json : Json) : Except ParseError Config :=
  match json.getObjVal? "timeout" with
  | none => Except.error (.missingField "timeout")
  | some val =>
    match val.getNat? with
    | none => Except.error (.invalidFormat "timeout must be a number")
    | some n =>
      if n < 1 || n > 3600 then
        Except.error (.outOfRange n 1 3600)
      else
        Except.ok { timeout := n }
```

---

## Error Logging

### Log Levels

**ERROR**: Operation failed, user action required
- Validation failures
- File operation failures
- Delegation failures
- Critical errors

**WARNING**: Operation succeeded with issues
- Final commit failures (changes applied)
- Optional dependency missing (fallback used)
- Deprecated feature usage

**INFO**: Normal operation events
- Operation started
- Operation completed
- State transitions

**DEBUG**: Detailed diagnostic information
- Variable values
- Execution paths
- Performance metrics

### Error Log Format

**File**: `.opencode/logs/errors.json`

**Structure**:
```json
{
  "timestamp": "2025-12-29T10:30:45.123Z",
  "level": "error",
  "type": "validation_failure",
  "message": "Task number must be an integer",
  "context": {
    "command": "/research",
    "input": "abc",
    "session_id": "sess_123",
    "user": "developer"
  },
  "stack_trace": "...",
  "recovery_attempted": false
}
```

**Required Fields**:
- `timestamp`: ISO 8601 timestamp
- `level`: error | warning | info | debug
- `type`: Error type from standard list
- `message`: Human-readable error message

**Optional Fields**:
- `context`: Relevant context (command, file, session, etc.)
- `stack_trace`: Stack trace if available
- `recovery_attempted`: Whether automatic recovery was tried
- `recovery_success`: Whether recovery succeeded
- `user_notified`: Whether user was notified

---

## Error Recovery Strategies

### 1. Automatic Retry

**When**: Transient failures (network, timeout)

```xml
<recovery_strategy name="automatic_retry">
  <conditions>
    - Network timeout
    - Temporary service unavailability
    - Rate limit (with backoff)
  </conditions>
  <implementation>
    1. Detect retryable error
    2. Wait with exponential backoff
    3. Retry operation (max 3 attempts)
    4. If all retries fail: return error to user
  </implementation>
  <limits>
    - Max retries: 3
    - Backoff: 1s, 2s, 4s
    - Total timeout: 10s
  </limits>
</recovery_strategy>
```

### 2. Fallback Strategy

**When**: Optional features fail

```xml
<recovery_strategy name="fallback">
  <conditions>
    - Optional dependency unavailable
    - Enhanced feature fails
    - External service down
  </conditions>
  <implementation>
    1. Detect feature failure
    2. Log warning
    3. Use fallback implementation
    4. Notify user of degraded functionality
  </implementation>
  <example>
    Primary: Use MCP Lean server for proof checking
    Fallback: Use basic syntax validation
    Notification: "Warning: Advanced proof checking unavailable, using basic validation"
  </example>
</recovery_strategy>
```

### 3. Rollback Strategy

**When**: Partial operation failure

```xml
<recovery_strategy name="rollback">
  <conditions>
    - Multi-step operation fails mid-way
    - File operation fails after changes
    - Git operation fails
  </conditions>
  <implementation>
    1. Create safety checkpoint before operation
    2. Execute operation steps
    3. If any step fails:
       a. Rollback to checkpoint
       b. Log rollback event
       c. Return error to user
    4. If rollback fails: escalate to critical error
  </implementation>
  <example>
    Operation: Update multiple files
    Safety: Git safety commit
    Failure: File 3 of 5 fails to write
    Rollback: git reset --hard {safety_commit}
    Result: All changes reverted, user notified
  </example>
</recovery_strategy>
```

### 4. Graceful Degradation

**When**: Non-critical features fail

```xml
<recovery_strategy name="graceful_degradation">
  <conditions>
    - Optional validation fails
    - Enhancement unavailable
    - Optimization fails
  </conditions>
  <implementation>
    1. Detect non-critical failure
    2. Log warning
    3. Continue with core functionality
    4. Inform user of limitation
  </implementation>
  <example>
    Operation: Generate proof with optimization
    Failure: Optimization step fails
    Degradation: Generate proof without optimization
    Notification: "Warning: Proof optimization unavailable, generated basic proof"
  </example>
</recovery_strategy>
```

### 5. User Intervention

**When**: Automatic recovery not possible

```xml
<recovery_strategy name="user_intervention">
  <conditions>
    - Critical dependency missing
    - Configuration invalid
    - Manual decision required
  </conditions>
  <implementation>
    1. Detect unrecoverable error
    2. Provide detailed error message
    3. Include step-by-step recovery instructions
    4. Offer alternative approaches if available
    5. Wait for user action
  </implementation>
  <example>
    Error: Git repository not initialized
    Message: "Error: Not a git repository"
    Instructions:
      1. Initialize git: git init
      2. Configure git: git config user.name "..."
      3. Retry operation
  </example>
</recovery_strategy>
```

---

## Error Handling Checklist

### For Agents/Subagents

- [ ] All error types documented in `<error_handling>` section
- [ ] Each error type has detection, handling, recovery, logging
- [ ] User-facing error messages are clear and actionable
- [ ] Recovery instructions are step-by-step
- [ ] Errors are logged with sufficient context
- [ ] Critical errors trigger appropriate escalation
- [ ] Rollback strategy defined for risky operations
- [ ] Timeout handling implemented for long operations

### For Commands

- [ ] Input validation with clear error messages
- [ ] Usage examples included in validation errors
- [ ] Missing argument errors specify what's required
- [ ] Invalid format errors show expected format
- [ ] Not found errors suggest verification steps
- [ ] All error paths tested

### For Code

- [ ] Explicit error handling (try/catch, Result types)
- [ ] Specific error catching (not generic Exception)
- [ ] Errors logged with context
- [ ] User-facing errors don't expose internals
- [ ] Async operations handle errors
- [ ] Resource cleanup in error paths (finally blocks)
- [ ] Error types documented

---

## Testing Error Handling

### Test Categories

**1. Expected Errors**
- Invalid input
- Missing required arguments
- File not found
- Permission denied

**2. Edge Cases**
- Empty input
- Null/undefined values
- Extremely large input
- Special characters

**3. System Errors**
- Disk full
- Network timeout
- Service unavailable
- Out of memory

**4. Recovery Testing**
- Retry logic
- Fallback mechanisms
- Rollback procedures
- State restoration

### Test Template

```yaml
name: error-handling-{error_type}
description: Test {error_type} handling

input:
  command: {command}
  arguments: {invalid_arguments}

expected_behavior:
  - Error detected
  - Clear error message returned
  - Recovery instructions provided
  - Error logged
  - System state unchanged (or rolled back)

validation:
  - Error message matches format
  - Contains recovery steps
  - No internal details exposed
  - Appropriate log entry created
```

---

## References

**Related Standards**:
- `.opencode/context/core/standards/patterns.md` - Error handling patterns
- `.opencode/context/core/standards/code.md` - Code error handling
- `.opencode/context/core/standards/git-safety.md` - Git error handling
- `.opencode/context/core/standards/subagent-structure.md` - Subagent error handling
- `.opencode/context/core/standards/command-structure.md` - Command error handling

**Examples**:
- `.opencode/commands/research.md` - Command error handling
- `.opencode/agent/subagents/lean/proof-planner.md` - Subagent error handling

---

## Version

**Version**: 1.0.0  
**Last Updated**: 2025-12-29  
**Status**: Active
