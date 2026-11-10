# Telemetry Guardrails

Binding design constraints for every sub-mode that consumes telemetry or event signal across
`/telemetry` (`--meta`, `--review`, `--dream`) and `/distill` (`--revise`, `--learn`). Stated
once here and cited by name from each sub-mode's own specification rather than restated five
times.

## The Four-Tier Source Model

Every telemetry-consuming sub-mode draws from up to four independent signal tiers. Each tier has
a distinct owner and a distinct structural blind spot — no tier can substitute for another.

### Tier 1: Claude Code OTel

Outcome signal: did an operation succeed or fail, and why. Enabled by
`CLAUDE_CODE_ENABLE_TELEMETRY=1`.

- `claude_code.tool_result` carries `success`, `error_type`, `duration_ms`, `decision_source`.
- Metrics: `claude_code.session.count`, `.token.usage`, `.cost.usage`,
  `.code_edit_tool.decision`, `.active_time.total`.
- Beta spans are available via `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1`.
- Prompt and response content is redacted unless explicitly opted into via
  `OTEL_LOG_USER_PROMPTS` / `OTEL_LOG_ASSISTANT_RESPONSES` / `OTEL_LOG_TOOL_DETAILS`.
- **Blind spot**: no concept of a task number, a phase, or a plan deviation. It is
  did-it-fail-and-why, and nothing task-, phase-, or plan-shaped.

### Tier 2: `events.jsonl`

Agent-system semantics and repo tag. Categories `deviation` / `blocker` / `milestone` /
`success`; `task` and `checkpoint` fields; the `cwd` field (repo tag, already implemented).

- **Blind spot**: per-repo file only; no cross-repo aggregation exists (see the "Cross-Repo
  Signal Limitation" section below).

### Tier 3: `history.jsonl`

The durable global prompt spine: roughly 23,758 prompts spanning 7 months across 33 projects at
last measurement. Each line carries `display`, `timestamp`, `project` (an absolute cwd), and
`sessionId`. Outlives transcripts — this is the tier to use once a transcript has rolled out of
its retention window.

- **Blind spot**: prompt-level record only. No outcome signal, no phase/task structure.

### Tier 4: Transcripts and `.meta.json` Sidecars

A 30-day replay and bootstrap window. The sidecar itself is minimal — `agentType`,
`description`, `toolUseId`, `spawnDepth` — and carries no session id and no outcome field, so all
replay value lives in the paired `.jsonl` transcript.

- **Blind spot**: 30-day window only; once a transcript rolls out, only `history.jsonl`'s
  prompt-level record and the task's own archived `specs/` artifacts remain.

## The Evaluator-Outside-the-Loop Rule

**Propose-then-human-review. NEVER auto-apply.** No sub-mode may treat its own prior output as
primary evidence; every proposal must trace to a source tier.

This rule exists because of a documented anti-pattern: an agent ran 220+ autonomous loops and
began fabricating metrics once its own optimistic summaries became the next loop's input. Once a
loop's evidence is its own prior conclusion rather than a source tier, the loop has no external
check and drifts toward whatever is easiest to claim. Every mutating sub-mode's `AskUserQuestion`
gate is the structural guard against this — it is non-negotiable, not a configurable option.

## The Six Failure Modes (Design Checklist)

Walk this checklist against every new sub-mode specification before considering it done:

1. **Stale-default bias** — does the sub-mode keep recommending a default that newer evidence
   contradicts?
2. **Implementation drift toward simpler solutions under pressure** — does time or context
   pressure push the sub-mode toward a shallower answer than the evidence supports?
3. **Memory degradation absent persistent artifacts** — does the sub-mode's output leave a
   durable record, or does its reasoning evaporate at session end?
4. **Over-optimism on noisy signals** — does the sub-mode treat a thin or noisy signal as
   confirmed fact?
5. **Weak domain knowledge** — does the sub-mode assume domain expertise it has not actually
   grounded in a source tier?
6. **Poor scientific taste** — does the sub-mode chase a plausible-sounding but unverified
   narrative over the evidence actually available?

## The ~70% v1 Miss-Rate Expectation

Design for iteration, not one-shot precision. The closest documented precedent — keyword-based
friction detection — self-reports catching only 20-30% of real friction on a first pass. Treat a
~70% miss rate on `--revise` classification and `--meta` pattern discovery as an expected v1
outcome, not evidence of failure. Ship this expectation explicitly in each new sub-mode's own
description so a low v1 hit rate reads as expected, not as a defect.

## The No-New-Hygiene-Below-~100-Entries Constraint

The vault currently holds 19 memories, roughly 2,616 tokens, with a single operator and mostly
static facts. This is far below the scale at which additional hygiene automation pays for itself.
The six existing hygiene sub-modes (`report`/`purge`/`merge`/`compress`/`refine`/`gc`/`auto`) are
frozen at their current behavior; do not propose new hygiene automation until the vault
materially exceeds this scale.

## The `gen_ai.*` Borrowing Rule

Borrow the following names as a **citation vocabulary only**, never as top-level `events.jsonl`
field names:

- `gen_ai.operation.name`
- `gen_ai.provider.name`
- `gen_ai.request.model`
- `gen_ai.usage.input_tokens`
- `gen_ai.usage.output_tokens`
- `error.type`

These dotted names are used as literal keys **only inside the already-open `detail` object**,
and only when the payload is explicitly citing OTel-derived evidence — e.g. a `--revise`
correlation event whose `detail` carries `{"gen_ai.usage.input_tokens": 1200, "error.type":
"ENOENT"}` next to the existing evidence citation. Top-level `events.jsonl` fields keep flat
`snake_case` always; `cc_session_id` is the one new top-level field this redesign adds (see
`context/formats/events-format.md`'s "Claude Code OTel Correlation" section), and no `gen_ai.*`
name is ever promoted to a top-level field.

Do not build a span/trace system or collector infrastructure. Borrowing the vocabulary is the
entire scope of this rule.

## The Cross-Repo Script Invocation Discipline

`sapience-retrieve.sh`, `sapience-remember.sh`, `events-query.sh`, and `events-append.sh`
resolve `PROJECT_ROOT` from the literal invocation string (`BASH_SOURCE[0]`), not from any
explicit root argument. The mandatory invocation form for any new sub-mode call site is:

```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
cd "$GLOBAL_ROOT" && bash .claude/scripts/{name}.sh ...
```

chained in a single Bash tool call. Two prohibitions follow directly from this mechanism:

1. **Never invoke these four scripts by absolute path.** An absolute-path invocation silently
   defeats cwd-based `PROJECT_ROOT` resolution — it always reads whatever the absolute path
   points at, ignoring `$GLOBAL_ROOT` entirely.
2. **Never rely on a `cd` issued in an earlier, separate Bash invocation.** A subagent's Bash
   working directory does not persist across tool calls; the `cd` and the script invocation must
   be chained in the same call.

## The `sess_*` Dead End

The agent system mints its own session ids (`sess_{timestamp}_{random}`) at command GATE IN.
Claude Code never sees these ids — they exist purely within the agent-system's own bookkeeping.
Claude Code's session id is a UUIDv4 in an entirely different id space, generated by Claude Code
itself and exposed on hook stdin as `.session_id`. No structural link exists between the two id
spaces, and none should be invented; `cc_session_id` (the join key to OTel) always carries
Claude Code's own UUID, never the agent-system's `sess_*` value. This dead end was investigated
and closed — do not re-propose a `sess_*`-based join.

## The Cross-Repo Signal Limitation

`events.jsonl` is a per-repo file. `events-query.sh`'s `--repo` filter operates *within* one
file only — it does not aggregate signal across the multiple repos this agent system runs in.
Any sub-mode invoked from a single `$GLOBAL_ROOT` sees only that repo's own event store. This is
a documented residual limit and a candidate follow-up; it is explicitly out of scope for this
redesign and must be stated in the affected sub-mode's own flag description, not only in
commentary.

## The OSS-Tooling Position

No existing open-source tool performs the full mine-to-propose loop these sub-modes implement.
Reuse existing transcript/usage parsers (e.g. `ccusage`, `claude-code-log` parsing approaches)
where a parser is genuinely needed, rather than writing one from scratch. None of these existing
parsers extract success/failure signal — which is precisely why Tier 1 (OTel) owns that half of
the seam, and why a sub-mode needing outcome evidence must go to OTel rather than trying to infer
it from a transcript parse.

## Related Documentation

- [Events Format](../formats/events-format.md) — the OTel ↔ `events.jsonl` seam and field
  ownership contract
- `skills/skill-telemetry/SKILL.md` — the shared sub-mode skeleton and per-sub-mode
  specifications for `--meta`, `--review` and `--dream`, the three sub-modes this file was
  written for
- The memory extension's own distillation skill also cites this file for its own
  telemetry-consuming sub-modes (`--revise`, `--learn`)
