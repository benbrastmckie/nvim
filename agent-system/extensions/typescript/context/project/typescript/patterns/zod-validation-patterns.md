# Zod Validation Patterns

Generic [Zod](https://zod.dev/) schema vocabulary for validating and parsing untrusted or
loosely-typed data (config files, API responses, environment variables, CLI arguments) into
precisely-typed values. Framework-agnostic: nothing below depends on any particular runtime,
bundler, or UI library.

## Why Zod (or an Equivalent Runtime Validator)

TypeScript's type system is erased at compile time — it guarantees nothing about values that
cross a runtime boundary (JSON parsed from a file, a fetch response, `process.env`, user input).
A runtime validator closes that gap: it checks a value against a schema at runtime and, on
success, narrows the TypeScript type to match. Treat `JSON.parse(...) as MyType` as a type-safety
violation whenever the parsed value did not originate from code the same compilation unit
controls — assert nothing you have not validated.

## Core Primitives

```typescript
import { z } from 'zod';

// Enum values -- a fixed, closed set of string literals
z.enum(['draft', 'published', 'archived']);

// Coerce an incoming string/number into a Date
z.coerce.date();

// URL validation
z.string().url();

// Constrained strings -- length bounds
z.string().min(1).max(200);

// Nested objects
z.object({
  width: z.number(),
  height: z.number(),
});

// Discriminated unions -- a tagged-union schema keyed on a literal field
z.discriminatedUnion('type', [
  z.object({ type: z.literal('text'), content: z.string() }),
  z.object({ type: z.literal('image'), src: z.string(), alt: z.string() }),
]);
```

## Deriving a Static Type from a Schema

Never hand-author a parallel `interface`/`type` for a value a Zod schema already describes —
derive it with `z.infer`, so the static type and the runtime check cannot drift apart:

```typescript
const UserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.enum(['admin', 'member']),
});

type User = z.infer<typeof UserSchema>;
```

## Parsing vs. Safe-Parsing

- `schema.parse(value)` throws a `ZodError` on failure — use it only where a caller already
  expects to catch or let the error propagate (e.g. startup-time config validation, where a
  malformed config should fail loudly and immediately).
- `schema.safeParse(value)` returns a discriminated `{ success: true, data }` /
  `{ success: false, error }` result — use it at any boundary where a validation failure is an
  expected, recoverable outcome (a form submission, an optional API field) rather than a defect.

```typescript
const result = UserSchema.safeParse(candidate);
if (!result.success) {
  // result.error.issues: each a { path, message } pair naming exactly what failed
  return { ok: false, issues: result.error.issues };
}
const user = result.data; // typed as User
```

## Composing Schemas

- `.extend({...})` adds fields to an object schema without redeclaring the base.
- `.partial()` makes every field optional (useful for a PATCH-style update payload).
- `.merge(otherSchema)` combines two object schemas into one.
- `.transform(fn)` reshapes a validated value (e.g. trimming a string, computing a derived
  field) as part of the same parse call, so the transformed shape is still type-checked.

## Common Pitfalls

- Defining a schema for `.min()`/`.max()` bounds that do not match the bounds enforced
  elsewhere (a database column length, a form's HTML `maxlength`) creates a split source of
  truth; prefer deriving both from one constant where possible.
- `z.coerce.*` is permissive by design (it will coerce `"0"` to `0`, `""` to `NaN`, etc.) —
  use it only for fields genuinely expected to arrive as loosely-typed strings (e.g. env vars,
  query-string parameters), not as a substitute for correctly-typed input elsewhere.
- A discriminated union's literal tag must be present and correctly typed on every branch;
  a missing `z.literal(...)` on one branch silently falls through to the wrong variant's parse
  error rather than a clear "unknown discriminator" message.
