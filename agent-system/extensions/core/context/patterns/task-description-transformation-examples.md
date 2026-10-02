# Task Description Transformation Examples

This file holds the Transformation Examples table and Edge Cases bullets that illustrate `/task`
(`commands/task.md`) Create Task Mode's description-improvement algorithm, steps 3.1-3.3. It was
extracted verbatim from that step's former inline body. The algorithm in 3.1-3.3 is fully
specified without this material — it is reference material reinforcing the algorithm with worked
examples, not part of the algorithm itself. Read it before applying steps 3.1-3.3 to a
non-obvious input.

---

   **Transformation Examples**:

   | Input | Output | Transformation Applied |
   |-------|--------|------------------------|
   | `prove_sorries_in_coherentconstruction` | `Prove sorries in CoherentConstruction` | Slug expansion + CamelCase preserved |
   | `bug in modal evaluator` | `Fix bug in modal evaluator` | Verb inference (Fix) + capitalize |
   | `documentation for new API` | `Update documentation for new API` | Verb inference (Update) |
   | `tests for validation module` | `Add tests for validation module` | Verb inference (Add) |
   | `new caching layer` | `Implement new caching layer` | Verb inference (Implement default) |
   | `Update TODO.md header metrics` | `Update TODO.md header metrics` | No change (already well-formed) |
   | `Fix the race condition in handlers` | `Fix the race condition in handlers` | No change (starts with verb) |
   | `implement_option_b_canonical_models` | `Implement option b canonical models` | Slug expansion |

   **Edge Cases**:
   - Input with quotes: `Add "hello world" test` -> No change to quoted content
   - Input with file path: `Fix bug in src/config/lsp.lua` -> Preserve path exactly
   - Input with version: `Update to python v3.12` -> Preserve version identifier
   - Input with issue ref: `Fix #123 memory leak` -> Preserve issue reference
   - CamelCase preserved: `prove_CoherentConstruction_complete` -> `Prove CoherentConstruction complete`
