---
paths: "**/*.lean"
---

# Lean 4 Development Rules

## CRITICAL: Blocked MCP Tools

**DO NOT call**: `lean_diagnostic_messages` (hangs), `lean_file_outline` (unreliable)

Use `lean_goal` + `lake build` instead (detached, guarded — see
`context/project/lean4/operations/long-builds.md`).

## Essential MCP Tools

| Tool | Purpose |
|------|---------|
| `lean_goal` | Proof state at position - MOST IMPORTANT |
| `lean_hover_info` | Type signatures + docs |
| `lean_completions` | IDE autocomplete |
| `lean_local_search` | Fast local declaration search |
| `lean_verify` | Axiom check + source scan (use fully qualified name) |
| `lean_multi_attempt` | Test tactics without editing - use BEFORE applying edits |

## Search Tools (Rate Limited)

| Tool | Rate | Query Style |
|------|------|-------------|
| `lean_leansearch` | 3/30s | Natural language |
| `lean_loogle` | 3/30s | Type pattern |
| `lean_leanfinder` | 10/30s | Semantic concept |
| `lean_state_search` | 3/30s | Goal -> closing lemmas |
| `lean_hammer_premise` | 3/30s | Goal -> simp/aesop hints |

## Search Decision Tree

1. "Does X exist locally?" -> `lean_local_search`
2. "Lemma that says X" -> `lean_leansearch`
3. "Type pattern match" -> `lean_loogle`
4. "Lean name for concept" -> `lean_leanfinder`
5. "What closes this goal?" -> `lean_state_search`

## Workflow Pattern

1. After finding name: `lean_local_search` -> verify, `lean_hover_info` -> signature
2. During proof (inner loop): `lean_goal` constantly; `lean_multi_attempt` BEFORE editing; `lean_verify` for axiom/sorry check
3. After editing a step: `lean_goal` to confirm; `lean_verify` if axiom safety needed
4. Phase-end: `bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build Module.Name`
   (scoped), detached via `Bash(run_in_background: true)`; fall back to the unscoped form if
   module name unknown
5. Final verification only: `bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- build`
   (full project), same detached, guarded invocation

## Common Tactics

Automation: `simp`, `aesop`, `omega`, `ring`, `decide`
Structure: `intro`, `apply`, `exact`, `constructor`, `cases`, `induction`
Rewriting: `rw`, `simp only`, `conv`

## Build Commands

Every build runs detached via `Bash(run_in_background: true)`, routed through the shared build
guard, with an explicit `--timeout` — never as a plain foreground `lake build`. A plain foreground
call can livelock: the tool's own cap kills it mid-module, a killed build caches no `.olean`, and
the next attempt restarts at the same module. See
`context/project/lean4/operations/long-builds.md` for the full contract; this section does not
restate it.

Canonical invocation shape:
```bash
bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- <lake-subcommand> [args]
# e.g. -- build Module.Name
```

Un-piped capture form:
```bash
bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- <lake-subcommand> [args] > <log> 2>&1; GUARD_EXIT=$?
```
or read the guard's own `result` subcommand. See
`context/project/lean4/operations/long-builds.md`'s "Reading the build's verdict" for the full
evidence hierarchy and the pipe-exit-code prohibition; this section does not restate either.

Prefer scoped: `-- Module.Name` | Full project: `-- build` (no module) | Clean: `lake clean` then the
guarded build.

**When to use each**:
- Scoped (`Module.Name`) -- phase-end verification; does less work, not categorically safer. A
  single module can already exceed the foreground cap on its own, and the guard's lock is
  project-granular regardless of scope.
- Unscoped (full project) -- final verification only (after all phases complete)

**The guard's mutex is real but opt-in -- route every `lake` invocation through it.** The build
guard implements a genuine `flock`-based lock: it serializes concurrent builds against the same
project and lets a waiter replay an already-completed matching result instead of launching a
redundant one. What it does NOT do is intercept a bare `lake` call -- participation is opt-in by
construction, so any process that invokes `lake` directly (including a project-local script this
agent system does not own and cannot edit) bypasses the lock entirely and can collide with a
guarded build running at the same time. The consequence of that collision is a **lost build, not
a corrupted one** -- see the working-tree and build isolation posture decision record
(`context/patterns/batch-orchestration-guardrails.md`) for the concurrency evidence this is drawn
from. Two obligations follow: route every `lake` invocation an agent makes through
`lake-build-guard.sh build ...`, never bare `lake`; and treat an unexplained build failure during
concurrent work on the same project as *possible* guard bypass by another process, not
automatically your own regression -- check for a competing unguarded `lake` before assuming the
code is wrong.

## Literature Fidelity

When a literature source (paper, textbook, proof sketch) is referenced in the task or plan:

- **Follow the source step-by-step** -- do not seek shortcuts or alternative proofs
- **FORBIDDEN**: Using `simp`/`omega`/`aesop` to bypass steps the literature handles explicitly
- **FORBIDDEN**: Abandoning the literature's approach after a single tactic failure
- **FORBIDDEN**: Mixing literature steps with novel steps without flagging the deviation
- **Escalation**: Re-read source -> try alternative Lean encodings -> check for unstated lemmas -> flag gap to user
- **No literature referenced?** First-principles mode: all tactics and strategies permitted freely

See `literature-fidelity-policy.md` for full policy, anti-pattern catalog, and escalation protocol.

## Vacuous Definitions (PROHIBITED)

The following definition patterns are **strictly prohibited** and are semantically equivalent to `sorry`. They create no real proof obligation and will be caught by the Zero-Debt Verification Gate.

### Prohibited Patterns

```lean
-- def variants
def Foo := True
def Foo := Unit
def Foo := trivial
def Foo := Trivial
noncomputable def Foo := True

-- theorem variants
theorem Foo := True
theorem Foo := trivial
theorem Foo := Trivial

-- lemma variants
lemma Foo := True
lemma Foo := trivial
lemma Foo := Trivial

-- instance variants
instance Foo := trivial
instance Foo := True
```

### Why These Are Prohibited

- `def X := True` compiles but proves nothing about `X`'s actual semantics
- `theorem X := trivial` only type-checks when the goal is literally `True`, not the real goal
- These patterns paper over inability to implement by substituting a semantically empty placeholder
- They are indistinguishable from `sorry` in terms of proof value: the definition exists but the intent is unfulfilled

### What to Do Instead

If you cannot implement `X`:
1. Mark the phase **[BLOCKED]** in the plan file
2. Document the blocker with what was tried, what goal state was reached, and what is needed to unblock
3. Return `status: "partial"` with `requires_user_review: true`
4. **Do NOT create `def X := True` or any vacuous placeholder**

The Escalation Protocol in `lean-implementation-agent.md` specifies the exact procedure.
