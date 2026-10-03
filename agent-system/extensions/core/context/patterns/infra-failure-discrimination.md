# Infrastructure-Failure vs. Work-Cycle Discrimination

Distinguishes an Agent-tool transport/API-layer failure from a genuine `/orchestrate` work
cycle, so the former is charged against a separate, capped `infra_failures` counter instead of
the work-cycle budget (`cycle_count` / `MAX_CYCLES`).

## Why there is no single mechanical signal

An Agent tool call is an LLM tool invocation, observed only at return time by the orchestrator's
own narration. The Move 3 bash that inspects `.orchestrator-handoff.json` runs strictly *after*
the Agent tool call has already returned — by the time bash executes, the distinguishing signal
(did the tool call itself fail at the transport/API layer, or did a subagent run and simply not
write a handoff?) has structurally already been lost to bash. There is no `$?`-style exit code
or bash-observable artifact that captures the tool-call-level outcome directly.

`skill_preflight_update` is written by the *caller* (the orchestrator) before dispatch, so its
presence proves nothing about whether the dispatched subagent ever ran — it is not usable as a
discriminating signal.

## Ordering relative to return-meta outcome recovery

This discrimination rule is **not** the first thing Move 3 tries inside a
missing/stale-handoff branch. Outcome recovery via `.return-meta.json`
(`scripts/orchestrate-recover-outcome.sh`, documented in
`docs/architecture/handoff-schema.md`'s "Outcome Channels" section) is attempted **first**: for
the writer that never produces a handoff by design (research, in any mode — not plan or
implement, which write one whenever `orchestrator_mode: true` regardless of hard/base mode), a
missing handoff is very often a genuine success, not a failure of any kind — infra or otherwise.
Only when
that recovery **also declines** (missing, stale, unparseable, `in_progress`, or non-success
`.return-meta.json`) does control fall through to the two-signal discrimination below. This
narrows *when* the discrimination fires — a corroborated success recovered above never reaches it
— without changing the rule itself: once reached, the classification below is unchanged.

## The two required signals

| Signal | Kind | Where set | Value meaning |
|--------|------|-----------|---------------|
| `dispatch_was_transport_error` | narrated LLM judgment | immediately after each Agent tool call returns | `true` only if the tool call itself returned a transport/API-layer error with **no subagent-authored text at all** |
| `meta_touched` | mechanical bash | Move 3 | `true` if `${TASK_DIR}/.return-meta.json` mtime `>= dispatch_start_ts` |

**Classification**: infra failure **iff** `dispatch_was_transport_error = true` **AND**
`meta_touched = false`. Every other combination preserves pre-existing behavior exactly (charge
a genuine work cycle).

**Positive transport-error indicators** (set `true`): `ENOTFOUND`, `EAI_AGAIN`, `ECONNREFUSED`,
`ECONNRESET`, `ETIMEDOUT`, TLS/handshake failures, a harness-level exception for the tool
invocation itself, or an API-layer error object (`overloaded_error`, `api_error`, 5xx) — **with
no subagent-authored text**.

**Negative indicator** (set `false`, charge the cycle): any subagent-authored text exists, *even
if that text itself describes an error the subagent hit* (e.g. "I hit a network error while
fetching X and am reporting partial findings"). That is the subagent narrating its own
experience — proof it ran.

**Either signal alone defaults to charging a genuine cycle.** This conservative default is the
whole point: a permissive rule that exempts on a single signal turns `MAX_CYCLES` into no cap at
all.

## Why `.return-meta.json` is the mechanical probe

Every agent following the early-metadata contract (see
[Early Metadata Pattern](early-metadata-pattern.md)) writes `specs/{NNN}_{SLUG}/.return-meta.json`
with `status: "in_progress"` **before any substantive work** (Stage 0). So an untouched
`.return-meta.json` — one whose mtime predates the dispatch window's `dispatch_start_ts` — is the
strongest available evidence that the subagent never reached its own first tool call.

**Accepted residual false-negative**: a subagent that writes early metadata and *then* dies to a
transport failure is charged a genuine cycle. This is a deliberately conservative choice: it is
safer to occasionally over-charge a rare edge case than to under-charge and let the exemption
path become a loophole.

## The counter and its cap

`infra_failures` is a per-run counter, `MAX_INFRA_FAILURES=3`, flat and identical across both of
`skill-orchestrate`'s effort-mode branches — not scaled with `MAX_CYCLES` (5 base vs. 13 hard),
because infra tolerance has no relationship to phase count. This matches this codebase's other
small-cap precedents (`MAX_BLOCKER_ESCALATIONS=2`, `MAX_DRIFT_INSPECTIONS=1`).

The counter imitates `burnout_signals_this_session`'s shape exactly: declared in the Stage 2
loop-guard init blob, persisted in `.orchestrator-loop-guard`, read back in **all three** init
paths (resume, fresh, lost-race), and incremented via read-modify-tmp-mv `jq`.

It deliberately **diverges** from `burnout_signals_this_session` on one point:
`burnout_signals_this_session` has no cap of its own, because its increments convert into
cycle-consuming dispatches (it feeds *into* the charged-cycle budget). `infra_failures`
increments deliberately do **not** consume cycle budget, so — unlike burnout — it MUST have an
explicit cap of its own, or the exemption path becomes an unbounded loop.

## Bound

Because an infra-exempt iteration does not increment `cycle_count`, the
`while [ "$cycle_count" -lt "$MAX_CYCLES" ]` condition alone does not advance on such an
iteration. The bound comes from a Stage 7 terminal check that runs at the end of **every**
cycle: once `infra_failures >= MAX_INFRA_FAILURES` the run exits `partial`.

Every iteration charges exactly one of the two counters; both are capped; no iteration charges
neither. The worst-case number of loop iterations in a single invocation is therefore:

```
MAX_CYCLES + MAX_INFRA_FAILURES
  = 5 + 3 = 8   (base mode)
  = 13 + 3 = 16 (hard mode)
```

## Terminal condition

On `infra_failures >= MAX_INFRA_FAILURES`, exit `partial` with a message *distinct* from the
`MAX_CYCLES` message, so a log reader can immediately tell "infra flakiness" apart from "ran out
of work budget". Do **not** fall through to also incrementing `cycle_count` — the cap's entire
purpose is to stay outside the work-cycle budget. Recovery is a fresh `/orchestrate` invocation,
not a consumed cycle.

## Failing safe

Every read of the two signals uses a bash defensive default chosen so a *forgotten* dispatch
site falls back to **charging**:

- `${dispatch_was_transport_error:-false}` — unset means "not infra".
- `${dispatch_start_ts:-9999999999}` — unset means the dispatch window's start is in the far
  future, so `meta_mtime >= window_start` is false, so `meta_touched=false` — which is the
  *permissive* direction on its own. It is safe **only** because it is joined by `AND` with
  `dispatch_was_transport_error` (which defaults to `false`). Both defaults together yield
  "charge".

**The implementer must not weaken the `AND` into an `OR` or a fallthrough.** Either signal alone
must default to charging a genuine work cycle.

## Related Documentation

- [Early Metadata Pattern](early-metadata-pattern.md) - the Stage 0 contract `meta_touched`
  relies on
- [MCP Tool Recovery](mcp-tool-recovery.md) - MCP tool call failure recovery; covers a different
  failure surface (MCP tool calls observed mid-execution, not Agent-tool transport failures
  observed only at return)
- [Error Handling Rule](../../rules/error-handling.md) - general error handling rules
