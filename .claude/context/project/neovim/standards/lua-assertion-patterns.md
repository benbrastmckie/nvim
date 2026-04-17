# Lua Testing Assertion Patterns

When testing string pattern matching with `string:match()`, use the correct assertion types.

## Correct Patterns
- **Match success**: `assert.is_not_nil(str:match("pattern"))` - Tests if pattern found
- **Match failure**: `assert.is_nil(str:match("pattern"))` - Tests if pattern not found

## Incorrect Patterns (DO NOT USE)
- `assert.is_true(str:match("pattern"))` - WRONG: match returns string/nil, not boolean
- `assert.is_false(str:match("pattern"))` - WRONG: match returns string/nil, not boolean

## Rationale

Lua's `string:match()` returns:
- The matched substring (truthy string) if pattern found
- `nil` if pattern not found
- Never returns boolean `true` or `false`

Using `is_true`/`is_false` with `string:match()` causes test failures because:
- `assert.is_true("matched")` fails - expects boolean true, gets string
- `assert.is_false(nil)` fails - expects boolean false, gets nil

## Code Examples

Correct:
```lua
local result = "test string"
assert.is_not_nil(result:match("test"))      -- Verifies match found
assert.is_nil(result:match("missing"))       -- Verifies match not found
```

Incorrect:
```lua
local result = "test string"
assert.is_true(result:match("test"))         -- FAILS: returns "test", not true
assert.is_false(result:match("missing"))     -- FAILS: returns nil, not false
```

Reference: See `scan_spec.lua:203-204` for established codebase pattern.
