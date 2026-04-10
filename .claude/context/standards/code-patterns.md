<!-- Context: standards/code | Priority: critical | Version: 2.0 | Updated: 2025-01-21 -->
# Code Standards

## Quick Reference

**Core Philosophy**: Modular, Functional, Maintainable
**Golden Rule**: If you can't easily test it, refactor it

**Critical Patterns** (use these):
- [PASS] Pure functions (same input = same output, no side effects)
- [PASS] Immutability (create new data, don't modify)
- [PASS] Composition (build complex from simple)
- [PASS] Small functions (< 50 lines)
- [PASS] Explicit dependencies (dependency injection)

**Anti-Patterns** (avoid these):
- [FAIL] Mutation, side effects, deep nesting
- [FAIL] God modules, global state, large functions

---

## Core Philosophy

**Modular**: Everything is a component - small, focused, reusable
**Functional**: Pure functions, immutability, composition over inheritance
**Maintainable**: Self-documenting, testable, predictable

## Principles

### Modular Design
- Single responsibility per module
- Clear interfaces (explicit inputs/outputs)
- Independent and composable
- < 100 lines per component (ideally < 50)

### Functional Approach
- **Pure functions**: Same input = same output, no side effects
- **Immutability**: Create new data, don't modify existing
- **Composition**: Build complex from simple functions
- **Declarative**: Describe what, not how

### Component Structure
```
component/
├── index.js      # Public interface
├── core.js       # Core logic (pure functions)
├── utils.js      # Helpers
└── tests/        # Tests
```

## Patterns

### Pure Functions
```javascript
// [PASS] Pure
const add = (a, b) => a + b;
const formatUser = (user) => ({ ...user, fullName: `${user.firstName} ${user.lastName}` });

// [FAIL] Impure (side effects)
let total = 0;
const addToTotal = (value) => { total += value; return total; };
```

### Immutability
```javascript
// [PASS] Immutable
const addItem = (items, item) => [...items, item];
const updateUser = (user, changes) => ({ ...user, ...changes });

// [FAIL] Mutable
const addItem = (items, item) => { items.push(item); return items; };
```

### Composition
```javascript
// [PASS] Compose small functions
const processUser = pipe(validateUser, enrichUserData, saveUser);
const isValidEmail = (email) => validateEmail(normalizeEmail(email));

// [FAIL] Deep inheritance
class ExtendedUserManagerWithValidation extends UserManager { }
```

### Declarative
```javascript
// [PASS] Declarative
const activeUsers = users.filter(u => u.isActive).map(u => u.name);

// [FAIL] Imperative
const names = [];
for (let i = 0; i < users.length; i++) {
  if (users[i].isActive) names.push(users[i].name);
}
```

## Naming

- **Files**: lowercase-with-dashes.js
- **Functions**: verbPhrases (getUser, validateEmail)
- **Predicates**: isValid, hasPermission, canAccess
- **Variables**: descriptive (userCount not uc), const by default
- **Constants**: UPPER_SNAKE_CASE

## Error Handling

```javascript
// [PASS] Explicit error handling
function parseJSON(text) {
  try {
    return { success: true, data: JSON.parse(text) };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// [PASS] Validate at boundaries
function createUser(userData) {
  const validation = validateUserData(userData);
  if (!validation.isValid) {
    return { success: false, errors: validation.errors };
  }
  return { success: true, user: saveUser(userData) };
}
```

## Dependency Injection

```javascript
// [PASS] Dependencies explicit
function createUserService(database, logger) {
  return {
    createUser: (userData) => {
      logger.info('Creating user');
      return database.insert('users', userData);
    }
  };
}

// [FAIL] Hidden dependencies
import db from './database.js';
function createUser(userData) { return db.insert('users', userData); }
```

## Anti-Patterns

[FAIL] **Mutation**: Modifying data in place
[FAIL] **Side effects**: console.log, API calls in pure functions
[FAIL] **Deep nesting**: Use early returns instead
[FAIL] **God modules**: Split into focused modules
[FAIL] **Global state**: Pass dependencies explicitly
[FAIL] **Large functions**: Keep < 50 lines

## Best Practices

[PASS] Pure functions whenever possible
[PASS] Immutable data structures
[PASS] Small, focused functions (< 50 lines)
[PASS] Compose small functions into larger ones
[PASS] Explicit dependencies (dependency injection)
[PASS] Validate at boundaries
[PASS] Self-documenting code
[PASS] Test in isolation

**Golden Rule**: If you can't easily test it, refactor it.
# Essential Patterns - Core Development Guidelines

## Quick Reference

**Core Philosophy**: Modular, Functional, Maintainable

**Critical Patterns**: Error Handling, Validation, Security, Logging, Pure Functions

**ALWAYS**: Handle errors gracefully, validate input, use env vars for secrets, write pure functions, keep outputs text-only (no emojis)

**NEVER**: Expose sensitive info, hardcode credentials, skip input validation, mutate state, include emojis in artifacts or command output

**Language-agnostic**: Apply to all programming languages

---

## Overview

This file provides essential development patterns that apply across all programming languages. For detailed standards, see:
- `../standards/code.md` - Modular, functional code patterns
- `../standards/patterns.md` - Language-agnostic patterns
- `../standards/tests.md` - Testing standards
- `../standards/docs.md` - Documentation standards
- `../standards/analysis.md` - Analysis framework

---

## Core Philosophy

**Modular**: Everything is a component - small, focused, reusable
**Functional**: Pure functions, immutability, composition over inheritance
**Maintainable**: Self-documenting, testable, predictable

---

## Critical Patterns

### 1. Pure Functions

**ALWAYS** write pure functions:
- Same input = same output
- No side effects
- No mutation of external state
- Predictable and testable

### 2. Error Handling

**ALWAYS** handle errors gracefully:
- Catch specific errors, not generic ones
- Log errors with context
- Return meaningful error messages
- Don't expose internal implementation details
- Use task-type-specific error handling mechanisms (try/catch, Result, error returns)

### 3. Input Validation

**ALWAYS** validate input data:
- Check for null/nil/None values
- Validate data types
- Validate data ranges and constraints
- Sanitize user input
- Return clear validation error messages

### 4. Security

**NEVER** expose sensitive information:
- Don't log passwords, tokens, or API keys
- Use environment variables for secrets
- Sanitize all user input
- Use parameterized queries (prevent SQL injection)
- Validate and escape output (prevent XSS)

### 5. Logging

**USE** consistent logging levels:
- **Debug**: Detailed information for debugging (development only)
- **Info**: Important events and milestones
- **Warning**: Potential issues that don't stop execution
- **Error**: Failures and exceptions

### 6. Text-only Output

- Do not include emojis in command or agent outputs, artifacts, templates, or logs.
- Use explicit status markers and textual cues instead.
- Ensure templates and examples avoid emoji glyphs.

---

## Code Structure Patterns

### Modular Design
- Single responsibility per module
- Clear interfaces (explicit inputs/outputs)
- Independent and composable
- < 100 lines per component (ideally < 50)

### Functional Approach
- **Pure functions**: Same input = same output, no side effects
- **Immutability**: Create new data, don't modify existing
- **Composition**: Build complex from simple functions
- **Declarative**: Describe what, not how

### Component Structure
```
component/
├── index.js      # Public interface
├── core.js       # Core logic (pure functions)
├── utils.js      # Helpers
└── tests/        # Tests
```

---

## Anti-Patterns to Avoid

**Code Smells**:
- Mutation and side effects
- Deep nesting (> 3 levels)
- God modules (> 200 lines)
- Global state
- Large functions (> 50 lines)
- Hardcoded values
- Tight coupling

**Security Issues**:
- Hardcoded credentials
- Exposed sensitive data in logs
- Unvalidated user input
- SQL injection vulnerabilities
- XSS vulnerabilities

---

## Testing Patterns

**ALWAYS** write tests:
- Unit tests for pure functions
- Integration tests for components
- Test edge cases and error conditions
- Aim for > 80% coverage
- Use descriptive test names

**Test Structure**:
```
describe('Component', () => {
  it('should handle valid input', () => {
    // Arrange
    const input = validData;
    // Act
    const result = component(input);
    // Assert
    expect(result).toBe(expected);
  });
  
  it('should handle invalid input', () => {
    // Test error cases
  });
});
```

---

## Documentation Patterns

**ALWAYS** document:
- Public APIs and interfaces
- Complex logic and algorithms
- Non-obvious decisions
- Usage examples

**Use clear, concise language**:
- Explain WHY, not just WHAT
- Include examples
- Keep it up to date
- Use consistent formatting

---

## Language-Specific Implementations

These patterns are language-agnostic. For task-type-specific implementations:

**TypeScript/JavaScript**: See project context for Next.js, React, Node.js patterns
**Python**: See project context for FastAPI, Django patterns
**Go**: See project context for Go-specific patterns
**Rust**: See project context for Rust-specific patterns

---

## Quick Checklist

Before committing code, verify:
- [ ] Pure functions (no side effects)
- [ ] Input validation
- [ ] Error handling
- [ ] No hardcoded secrets
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] No security vulnerabilities
- [ ] Code is modular and maintainable
- [ ] No emojis in outputs, logs, or artifacts

---

## Additional Resources

For more detailed guidelines, see:
- `../standards/code.md` - Comprehensive code standards
- `../standards/patterns.md` - Detailed pattern catalog
- `../standards/tests.md` - Testing best practices
- `../standards/docs.md` - Documentation guidelines
- `../standards/analysis.md` - Code analysis framework
- `../workflows/review.md` - Code review process
