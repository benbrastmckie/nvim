# Hard-Mode Routing: Contract-Injection Model

This document describes how `--hard` changes dispatch behavior today: by injecting
domain-specific behavioral contracts into the dispatch prompt via the manifest's `hard_contracts`
block, NEVER by resolving a different agent. `routing_agents_hard` — the former agent-level ladder
this document used to describe in full — is retired: every manifest that used to declare it
(`books`, `cslib`, `lean`) has had the block removed, and `command-route-agent.sh`'s own hard-mode
branch is collapsed away entirely (there is no longer an `if effort_flag == "hard"` conditional in
that script at all). `--hard` and standard-mode dispatches resolve the exact same `AGENT_NAME` for
every `(op, task_type)` pair, via the single `routing_agents` lookup both modes now share.

See `context/guides/manifest-routing-schema.md` for the full routing model (the single surviving
`routing_agents` block, core identification, the declared-not-derived agent-name rule, and the
`hard_contracts` block's own resolution mechanics in detail); this document focuses on what
`--hard` specifically changes and why, with a worked example per domain.

**Scope**: This document is the sole canonical home for the `--hard` contract-injection model.
CLAUDE.md's "Hard Mode" subsection carries only a pointer to this document (and to
`context/guides/manifest-routing-schema.md`). The rest of CLAUDE.md's "Hard Mode" section (What
Hard Mode Does, When to Use, Cost Impact, Composability, Per-Invocation Only) is unrelated to this
document's scope and is maintained directly in CLAUDE.md.

---

## Overview

When a command is invoked with `--hard`, two things happen, and only two:

1. **Agent resolution is UNCHANGED.** `command-route-agent.sh` resolves `AGENT_NAME` from
   `routing_agents` exactly as it would for a standard dispatch — `effort_flag` is passed through
   only as a `routing_trace` argument (so a trace log can still show which effort mode a dispatch
   ran under), never as a second lookup rung. There is no `-hard`-suffixed agent name anywhere in
   the source store any more.
2. **`orchestrate-build-dispatch.sh`'s Stage 3.5 injects behavioral contracts into the dispatch
   prompt.** For each phase (`research`/`plan`/`implement`), a fixed list of core contract
   basenames is the starting point; the manifest's `hard_contracts.{task_type}` array (resolved
   once via `routing_lookup_flat()`, the same 4-step non-core/core × exact/compound-base
   precedence `routing_agents` itself uses) then either `replace:`s a core entry in place or
   appends an additive entry after it. The resulting `<hard-mode-contracts>` block is what the
   dispatched agent actually reads differently under `--hard` — never a different agent body.

---

## Worked Example Per Domain

Each row shows the resolved `<hard-mode-contracts>` list for an `implement`-phase dispatch (core
starting list: `anti-analysis.md`, `wrap-up.md`, `recovery.md`, `phase-closure.md`,
`pre-edit-gate.md`):

| `task_type` | Resolved list | Mechanism |
|-------------|----------------|-----------|
| `lean4` | `lean4-anti-analysis.md` (replaces `anti-analysis.md`), `wrap-up.md`, `recovery.md`, `phase-closure.md`, `pre-edit-gate.md`, `lean4-context-hygiene.md` (additive), `lean4-sorry-discipline.md` (additive) | `hard_contracts.lean4` in lean's manifest |
| `cslib` | `anti-analysis.md` (unchanged — `cslib`'s one `replace:` targets `adversarial-verification.md`, which implement's core list does not include), `wrap-up.md`, `recovery.md`, `phase-closure.md`, `pre-edit-gate.md`, `lean4-context-hygiene.md` (additive, a deliberate cross-extension dependency — cslib's `--hard` dispatches edit Lean theorem files too) | `hard_contracts.cslib` in cslib's manifest |
| `books` | `anti-analysis.md`, `wrap-up.md`, `recovery.md`, `phase-closure.md`, `pre-edit-gate.md` (unchanged — books declares NO `hard_contracts` block; its own H2/H3/H4 content was judged duplicative of the generic core contracts and never extracted into an override) | miss — pure core list |
| `meta` (or any task_type no extension overrides) | `anti-analysis.md`, `wrap-up.md`, `recovery.md`, `phase-closure.md`, `pre-edit-gate.md` (unchanged — the generic path) | miss — pure core list |

The `meta` row is the regression check for a defect this document's own prior history caused: both
`core` and `lean` once declared the bare, unprefixed `provides.context: ["contracts"]` directory
entry, and the deploy copier's directory-level merge let lean's content silently clobber core's at
the shared `context/contracts/anti-analysis.md` path — so a `--hard` dispatch of ANY task type
read lean's proof-specific override by accident. The fix was the domain-prefixed basename
convention (`lean4-anti-analysis.md`, `cslib-adversarial-verification.md`, ...) documented in
`context/guides/manifest-routing-schema.md`'s "Override Contract Placement Convention"
subsection — not a change to the renderer or the deploy copier.

---

## "Extension Overrides Core" Rule (Still Applies, Now to `hard_contracts`)

`routing_lookup_flat()` scans non-core extension manifests before the core manifest, exactly like
`routing_agents`'s own `routing_lookup()`. If a non-core extension and the core manifest ever both
declared a `hard_contracts` entry for the same `task_type` (hypothetical — no such collision
exists today), the non-core extension's entry would win unconditionally. The core manifest is
identified by `.name == "core"`, never by `routing_exempt: true` (which `literature` and `slidev`
also set, for their own unrelated exemption semantics).

---

## Deployed `hard_contracts` Declarations (Current Inventory)

| Extension | `task_type` | Declares `hard_contracts`? | Override contracts |
|-----------|-------------|------------------------------|---------------------|
| `lean` | `lean4` | Yes | `lean4-anti-analysis.md`, `lean4-reference-grounding.md`, `lean4-adversarial-verification.md` (all `replace:`), `lean4-context-hygiene.md`, `lean4-sorry-discipline.md` (additive) |
| `cslib` | `cslib` | Yes | `cslib-adversarial-verification.md` (`replace:`), `lean4-context-hygiene.md` (additive, cross-extension) |
| `books` | `books` | No — deliberate | none; generic core contracts fully cover books' hard-mode behavior |

No extension declares `routing_agents_hard` any more — `grep -r routing_agents_hard
agent-system/extensions/*/manifest.json` returns nothing. The twelve files this migration retired
(six `-hard`-suffixed agents, six orphaned `-hard`-suffixed skill wrappers) are gone from the
source store entirely, along with every roster, index row, lint array, fixture, and illustrative
citation that named them.

---

## Orchestrate Hard Mode: One Engine, One Agent-Resolution Path

`skill-orchestrate` (invoked by `/orchestrate --hard`) resolves `AGENT_NAME` via
`command-route-agent.sh` — the shared `manifest-routing-lib.sh` ladder against `routing_agents`,
identically for every effort mode. There is no second routing block it reads for hard mode any
more. Base mode and hard mode share `orchestrate-cycle-plan.sh`'s `resolve_agent()` resolution
calls and diverge only on the `$hard_mode` variable (derived once per invocation from
`effort_flag == "hard"`), which gates Stage 3.5's `hard_contracts` injection and the H1/H4/H5/H6
behavioral techniques below — never which agent gets dispatched. See
`docs/architecture/orchestrate-state-machine.md` for the full mapping of which script now owns
each hard-mode technique. See `context/guides/manifest-routing-schema.md` for the full routing
model.

---

## What Hard Mode Does (Full Technique List)

Reactive companion to the eager core's one-line summary. Hard mode activates a set of
behavioral contracts and routing changes, distilled from high-complexity task orchestration
(the BimodalLogic per-phase-dispatch baseline: 9 H-techniques, measured outcome: 0 lines ->
2,400+ lines across 13 dispatches):

- **Anti-analysis (H2)**: Strict read budget, forbidden analysis-only outputs, defect bar enforcement
- **Reference grounding (H3)**: Source-to-implementation mapping with tier selection (literature/docs/code)
- **Adversarial verification (H4)**: Research output verified before plan dispatch
- **Divergence audit (H5)**: Three-strikes on any target triggers dedicated audit dispatch
- **Convergence policing (H6)**: Churn detection with per-target counters
- **Territory contracts (H7)**: Parallel dispatch with explicit file ownership
- **Phase sizing (H8)**: Each phase bounded to one agent run (~100-500 lines output)
- **Wrap-up discipline (H9)**: Orchestrator handoff JSON + incremental commits at every green milestone

All nine are core, generic contracts injected into every `--hard` dispatch regardless of
`task_type`; a domain's own `hard_contracts` entry only adds or replaces the DOMAIN-SPECIFIC
elaboration of these (e.g. lean4's formal-proof-specific H2 read-budget bar), never the base set.

## When to Use `--hard` (Full Criteria List)

Use `--hard` when one or more of the following apply:

1. **2+ plan versions exist** for the same task without convergence
2. **Previous dispatches produced analysis-only output** with no file writes (analysis-paralysis signal)
3. **Task involves formal verification** (lean4, z3) requiring faithful transcription of mathematical sources
4. **Task involves literature-based implementation** (paper to code, spec to implementation)
5. **Task has been in [IMPLEMENTING] for 3+ dispatch cycles** without phase completion
6. **Task description contains "deflection" or "stuck"** indicators in /errors output

## Cost Impact and Composability

| Mode | Cost Multiplier |
|------|----------------|
| Standard | 1x |
| `--hard` | ~3-5x |

- `--hard` works with model flags: `--hard --opus` uses Opus model with hard-mode contracts (also
  composable with `--fable`, e.g. `--hard --fable`)
- `--hard` works with extension-specific contract injection: an extension declares
  `hard_contracts` in its manifest to add or override behavioral contracts for its own
  `task_type`; declaring nothing (as `books` does) is a valid, deliberate choice, not a gap
- Graceful fallback: a `task_type` with no `hard_contracts` entry still receives the full set of
  generic core contracts under `--hard` — there is no "hard mode does nothing" failure mode
- Per-invocation only: there is no sticky hard mode or `effort_mode` field in `state.json`. Each
  invocation of `/orchestrate` must explicitly pass `--hard` to activate hard mode.

## Related Files

- `.claude/scripts/lib/manifest-routing-lib.sh` — Shared ladder implementation (`routing_lookup()`
  for `routing_agents`, `routing_lookup_flat()` for `hard_contracts`)
- `.claude/scripts/command-route-agent.sh` — Agent resolution (called from
  orchestrate-cycle-plan.sh's resolve_agent(), identical for every effort mode)
- `.claude/scripts/orchestrate-build-dispatch.sh` — Stage 3.5 builds the `<hard-mode-contracts>`
  block from the resolved `hard_contracts` list
- `.claude/extensions/lean/manifest.json` — Lean's `hard_contracts.lean4` declaration
- `.claude/extensions/cslib/manifest.json` — CSLib's `hard_contracts.cslib` declaration (not
  deployed in every repo; cslib must be loaded for this to apply)
- `context/guides/manifest-routing-schema.md` — Full routing model, including the
  `hard_contracts` block's resolution mechanics and the override-contract placement convention
