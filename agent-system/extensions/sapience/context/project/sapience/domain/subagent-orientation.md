# Subagent Orientation

## The Gap

Subagents receive no Sapience briefing. `SessionStart` (which drives `mcp.py --briefing-text`)
fires only for the root session, so every `/orchestrate` research/plan/implement dispatch begins
with no vault orientation at all -- it never sees "Your Sapience remembers..." the way an
interactive root session does.

## Why the Obvious Fix Cannot Work

The obvious fix is a manifest-declared lifecycle hook: a top-level `hooks.context_injection`
entry, the mechanism `nvim`/`nix` already use for their own domain-specific context injection.
This cannot work for Sapience, and the reason is structural, not a matter of degree.

`skill_get_extension_dir()` in `agent-system/extensions/core/scripts/skill-base.sh` resolves
which extension's lifecycle hooks fire for a given dispatch. It loops over every *active*
extension and returns the **first** one whose own manifest `task_type` field is a non-empty
string that equals the current task's own `task_type`:

```
[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]
```

Every one of `skill_run_extension_hook()`'s four call sites (preflight, context_injection,
verification, postflight) passes the *current dispatched task's own* `TASK_TYPE` as the argument
-- never a loop over "every loaded extension," and never a cross-cutting broadcast.

This extension declares no `task_type` (Sapience is not a domain to implement in -- a
research/plan/implement triple would route to agents with nothing to research). An extension
with no `task_type` can never be the first match for any task's `task_type`, for any task, of
any type, ever. A `hooks.context_injection` entry on this manifest would be structurally
unreachable, not merely a narrow or low-priority seam -- it is dead code from the moment it is
written.

## Why `nvim`/`nix` Succeed Where Sapience Cannot

`nvim-context.sh` and `nix-context.sh` are real, working examples of this exact hook firing. They
succeed only because each extension declares its own matching `task_type` (`"nvim"`, `"nix"`)
and its hook fires *only when a task of that specific type is dispatched* -- a narrow,
single-domain use that is the opposite of "every dispatch regardless of task type," which is
what Sapience orientation would need.

## Why Post-Task Observers Are Also the Wrong Shape

`creating-extensions.md`'s Post-Task Observers mechanism was built specifically because
lifecycle hooks cannot express "fire for every task regardless of its own `task_type`" --
observers resolve across every loaded extension rather than a single first-match. But observers
fire only from the orchestration cycle's own postflight stage, i.e. **after** a task reaches a
resting state. They cannot deliver a pre-work subagent briefing even if the `task_type`-matching
problem were somehow solved, because by the time an observer runs, the dispatch it would have
briefed has already finished.

## The Deliberate Alternative

No code change closes this gap. The deliberate resolution is:

1. **Session-level briefing stays as-is.** The root session's `SessionStart` ->
   `mcp.py --briefing-text` hook is the one orientation point this machine has, and it is
   already ambient -- this extension does not re-register it.
2. **An on-demand escape hatch, explicitly invoked.** When a subagent genuinely needs
   cross-session recall mid-task, it reaches for `sf1 "question"` or a direct `/v1/ask` call
   itself -- a deliberate, visible action, not a silent always-on injection.
3. **A single per-dispatch retrieval injection, repo-filtered, replacing rather than
   supplementing the local-vault injection.** The one existing cross-cutting,
   task-type-independent injection mechanism in this codebase (`<memory-context>`) is not an
   extension-declarable hook at all -- it is a hardcoded call written directly into core's own
   `orchestrate-build-dispatch.sh` Stage 3.5 `memory_context` block. That one call site now
   invokes `sapience-retrieve.sh`, a repo-tag-filtered `GET /v1/search` read emitting the same
   envelope shape the local-memory script produced, with the same failure-swallowing wrapper and
   `--clean` suppression unchanged -- see `per-repo-scoping.md` for the scoping mechanism, the
   script contracts, and the hazards (no delete API, unreviewed permanent writes, two
   differently-shaped vault populations). This is a single injection point, not a second one
   added alongside an existing local one: that one call site invokes either the local-memory
   vault or the Sapience vault, never both at once.

   **Amended by** `per-repo-scoping.md`, 2026-11-10: the alternative above and the "no
   per-dispatch, shell-invoked retrieval mechanism" framing in `vault-model.md` argued against
   exactly this shape. The accepted design builds it, accepting the per-dispatch network
   round-trip (measured at ~0.22s average) as the deliberate tradeoff, bounded by the hazards
   `per-repo-scoping.md` records.
