# Plan-Revision Notification Pattern

**Created**: 2026-10-09
**Purpose**: Define, once, how a live `implement` dispatch becomes aware that the plan file it is
reading was rewritten in place by a concurrently co-dispatched `plan-revision` aux row — and what
each side of that race is obligated to do about it.
**Audience**: `reviser-agent` (the sentinel writer), `general-implementation-agent` and
`lean-implementation-agent` (the sentinel/re-read readers)
**Related**: `../contracts/pre-edit-gate.md`, `../contracts/territory.md` (Plan-Section
Territory), `file-metadata-exchange.md`

---

## The hazard

`orchestrate-cycle-plan.sh` can emit a `plan-revision` aux row for the same task and the same
cycle as that task's own `implement` row: mutual exclusion is asserted between aux *kinds*
(`drift-inspection` vs. `divergence-audit`), never between an aux row and the implement row for
the same task, and `skill-orchestrate/SKILL.md`'s Move 2 requires every `dispatch[]` and
`aux_dispatch[]` row be issued in one message. So `reviser-agent` can rewrite `plans/*.md` in
place while the implement agent is reading that same file, with nothing in either contract making
the implement agent aware the file changed underneath it. Observed cost: a production implement
dispatch excerpted one phase from the post-revision file and another from the pre-revision file,
reported an already-corrected plan bullet as uncorrected, and propagated that false claim into its
phase handoff and round summary before a retraction and two further plan revisions unwound it.

## The sentinel

Path: `{task_dir}/.plan-revised.json` (`{task_dir}` is the same absolute task directory every
dispatch file already carries as `task_dir`/`TASK_DIR_ABS`).

Fields:
- `revised_at` (integer, epoch seconds) — when the revision was written
- `dispatch_seq` (integer) — the revising aux dispatch's own `dispatch_seq`
- `reason` (string) — `blocker` or `drift`
- `plan_path` (string) — the plan file that was revised
- `summary` (string) — one sentence naming what changed

## The freshness rule

A sentinel is relevant to a reading dispatch if and only if `revised_at >= dispatch_start_ts`,
where `dispatch_start_ts` is that reading dispatch's own `## Identity` block value. Existence
alone is never the test. There is deliberately **no** consume-and-clear, acknowledgement, or
deletion step for this sentinel: an older sentinel (`revised_at < dispatch_start_ts`) is inert by
construction and so can never be forgotten into a false positive. Contrast this with
`orchestrate-cycle-plan.sh`'s `aux_consume_blocker_file` / `aux_consume_drift_file` pattern, which
is cross-cycle and orchestrator-mediated — this sentinel is intra-cycle and reader-mediated, so
the discipline that pattern needs (consuming a value exactly once before the next cycle can
re-decide on it) does not apply here.

## Writer obligation (reviser-agent)

After the revised plan is written and before returning, `reviser-agent` writes the sentinel. This
is unconditional: it is inert whenever no implement dispatch for the same task is live this
cycle, so the writer needs no knowledge of whether a sibling implement row exists. See
`reviser-agent.md`'s Stage 5c and `orchestrate-build-aux-dispatch.sh`'s `plan-revision` prompt arm
for the two sites that carry this obligation.

## Reader obligation (implementation agents)

Immediately before writing the first edit of a phase, re-read that phase's own section of the
plan file and check the sentinel for a relevant hit (per the freshness rule above). This is
narrowly scoped, deliberately: that phase's section only, once per phase, never the full plan — it
is not a license to re-read the whole plan on every step. On a hit, re-derive that phase's steps
and file list from the freshly re-read text rather than the earlier excerpt, and record the
observation (what changed, which phase) in the handoff and summary rather than silently
proceeding as if nothing happened. See `general-implementation-agent.md`'s Stage 4 and
`lean-implementation-agent.md`'s "Before Starting a Phase" section for the two sites that carry
this obligation.

## Which remedy carries which guarantee

The pre-write re-read is the **correctness guarantee**: it catches a tear that lands between two
reads before any sentinel is even written, which is exactly the failure mode the sentinel alone
cannot catch (the sentinel is write-after-the-fact; a read-then-write race can still complete
entirely inside the window before it exists). The sentinel is the **awareness/latency layer**: it
explains *why* the text changed and lets a reader who re-reads attribute the change to a specific
revision rather than wondering if it misread the file. Neither substitutes for the other, and the
sentinel by itself cannot prevent a stale write — only the re-read can.

## Adjacent mechanisms that are NOT coverage

- **The `--territory` payload's generic re-read-before-editing note**
  (`orchestrate-build-dispatch.sh`): governs re-reading the *target* files an agent is about to
  edit (the codebase it is implementing into), not the plan file that is instructing it. A plan
  revision changes the instructions, not a target file.
- **`../contracts/pre-edit-gate.md`**: validates a plan's *claims about the codebase* (a file
  list, a candidate count) against the tree at edit time. It never validates the plan file against
  its own later revision — the plan itself is its input, not its subject.
- **`../contracts/territory.md`'s Plan-Section Territory section**: governs concurrent *writers*
  splitting phases of one plan file between themselves. This hazard is one writer (`reviser-agent`)
  racing one stale *reader* (the implement agent), not two writers contending for the same section.
- **`file-metadata-exchange.md`**: the agent-to-orchestrator `.return-meta.json` return channel,
  consumed by postflight after a dispatch ends. It carries no live, within-cycle signal between two
  dispatches that are both still running.

## Design invariant for future edits

A dispatch-file line that carries plan freshness information MUST NOT be per-cycle-varying.
`orchestrate-cycle-plan.sh`'s `cycle_plan_dispatch_hash()` normalizes a composed implement
dispatch file by stripping exactly three known per-cycle-varying lines before hashing it, so the
IDENTICAL DISPATCH HALT can recognize two truly identical dispatches; a new varying line not added
to that strip pattern in the same change silently renders the halt inert (this already happened
once, between 2026-10-03 and its later repair, pinned by
`scripts/tests/test-orchestrate-cycle-plan.sh`'s "Group 27 Case F"). The reading agent's own first
read is therefore the correct freshness baseline, never dispatch-build time: the race window this
pattern closes is between the agent's own read and its own write, not between dispatch-build and
the read. The implement dispatch's `## Plan` block accordingly emits only a static
`revision_sentinel` path (a fixed interpolation of `TASK_DIR_ABS`, constant across cycles for a
given task) and fixed pointer prose — nothing derived from the plan file's content, mtime, size,
or hash.
