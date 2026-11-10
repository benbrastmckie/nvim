# Goal-State Context Hygiene Contract — Lean4/CSLib

This is a NEW standalone contract for the Lean4/CSLib formal domains. It does not override
a core baseline file — there is no core "context-hygiene.md" to extend. It packages four
discipline clauses that reduce the per-step context lean4/formal hard agents consume by
preventing large Lean goal states, whole-file reads, and irrelevant hypotheses from being
repeatedly pulled into the transcript.

**Motivation**: enormous goal-state dumps (full hypothesis lists, full file reads) pasted
into the transcript on every tactic step are a primary cause of context overflow in
multi-dispatch Lean tableau/proof work. This contract is preventive: it lowers the baseline
context a dispatch consumes. It is complementary to, not a replacement for,
`@.claude/context/patterns/context-exhaustion-detection.md`, which is reactive (detects
pressure and triggers a handoff after it has accumulated). Apply this contract's discipline
on every step; consult context-exhaustion-detection.md only once pressure is already building.

## Clause 1: Goal-State Query Discipline (MUST)

- MUST prefer a targeted `lean_goal` call at a specific line/column over a broad,
  unscoped query.
- MUST use `mcp__lean-lsp__lean_minimal_hypotheses` when only the hypotheses relevant to
  the next tactic are needed, instead of the full local-context dump from a raw `lean_goal`.
- MUST use `mcp__lean-lsp__lean_term_goal` when only the expected type is needed (no
  hypothesis context required).
- MUST summarize a returned goal state in 3 lines or fewer in the transcript rather than
  pasting the raw MCP tool output verbatim on every step.
- SHOULD re-query precisely by exact line/column rather than re-running a broad query to
  "recheck" a goal already summarized earlier in the same dispatch.

## Clause 2: File-Read Discipline (MUST)

- MUST use `Read` with an explicit `offset`/`limit` bounding the active proof's enclosing
  declaration plus a small margin (a few lines above/below), not the whole file.
- MUST NOT read an entire large `Theories/` or `Cslib/` file when only one declaration is
  relevant.
- MUST NOT re-read a region already read earlier in the same dispatch; rely on the earlier
  read's content or re-query a narrower range if state may have changed.
- `lean_file_outline` remains BLOCKED; `.claude/context/project/lean4/tools/blocked-mcp-tools.md`
  is the single source of truth for its block status — do not hardcode "blocked" logic here,
  consult that file. `Read` with `offset`/`limit` is the mandated substitute for outline-style
  navigation while the block is in effect.

## Clause 3: Hypothesis Pruning (SHOULD)

- SHOULD prefer `mcp__lean-lsp__lean_minimal_hypotheses` over the full hypothesis list
  returned by a raw `lean_goal` call whenever only a subset of hypotheses is relevant to the
  planned tactic.
- MUST NOT carry forward hypotheses irrelevant to the current tactic into later reasoning
  or later transcript summaries.
- When summarizing a goal state, list only the hypotheses the planned tactic actually
  references, not the full local context.

## Clause 4: Packaging and Cross-Reference

Clauses 1-3 are MUST/SHOULD rules, not suggestions. They apply to every lean4/formal hard
agent dispatch that queries proof state, reads Lean source, or reasons over hypotheses.

This contract is preventive hygiene: it bounds what enters context in the first place. It
is distinct from `@.claude/context/patterns/context-exhaustion-detection.md`,
which is reactive: it detects context pressure that has already accumulated and triggers a
handoff. Apply this contract continuously; consult context-exhaustion-detection.md when its
detection signals (tool call volume, re-read detection) fire despite this contract's
discipline.

## Enforcement

A dispatch is in violation of this contract if, after the fact, the transcript shows: (a) a
raw unsummarized `lean_goal` dump repeated more than once for the same position without new
information, (b) a whole-file `Read` of a `Theories/`/`Cslib/` file exceeding a few hundred
lines when only one declaration was needed, or (c) a hypothesis list carried into the
summary that the planned tactic never references. On detecting any of these during
self-review, correct the next step immediately: switch to `lean_minimal_hypotheses` or
`lean_term_goal`, bound the next `Read` with `offset`/`limit`, and drop irrelevant
hypotheses from the summary. This contract does not block progress — it constrains *how*
progress is queried and recorded.
