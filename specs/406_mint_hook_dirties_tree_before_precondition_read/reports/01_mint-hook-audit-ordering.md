# Research Report: Task #406

**Task**: 406 - Mint hook dirties tree before precondition read
**Started**: 2026-10-14
**Completed**: 2026-10-14
**Effort**: medium
**Dependencies**: None (coordinates with, but does not depend on, the separate
`sweep_task_support_file_tracked_or_ignored` task, which owns `events.jsonl`'s
tracked-vs-ignored classification)
**Sources/Inputs**:
- Codebase: `scripts/lib/push-grant-lib.sh`, `scripts/events-append.sh`, `hooks/please-grant.sh`,
  `hooks/guard-git-push.sh`, `scripts/git-push-granted.sh`, `hooks/events-log-lifecycle.sh`,
  `skills/skill-tag/SKILL.md`, `scripts/tests/test-please-grant.sh`,
  `scripts/tests/test-guard-git-push.sh`, `context/formats/events-format.md`,
  `context/standards/push-consent-relay.md`
**Artifacts**:
- `specs/406_mint_hook_dirties_tree_before_precondition_read/reports/01_mint-hook-audit-ordering.md` (this report)
**Standards**: report-format.md, subagent-return.md

All file paths below are relative to the source-store root
`agent-system/extensions/core/` (confirmed as the edit target in the dispatch; the `.claude/`
deploy mirrors are read-only reflections and must never be hand-edited).

## Executive Summary

- The defect is real and precisely as described: `hooks/please-grant.sh` (a `UserPromptSubmit`
  hook, firing before `/tag`'s own command body) calls `pg_grant_mint`
  (`scripts/lib/push-grant-lib.sh:473`), which unconditionally calls
  `pg_events_append_observable --event-type push_grant_issued ...`
  (`push-grant-lib.sh:480-482`), which synchronously appends a line to the tracked
  `specs/events.jsonl` via `scripts/events-append.sh`. `skill-tag/SKILL.md` Step 1 then reads
  `git status --porcelain` and exits 1 on any non-empty result — guaranteed non-empty in any
  repo that tracks `specs/events.jsonl`, because the hook just wrote to it. **`/tag` cannot pass
  its own precondition in such a repo, in any invocation.**
- The secondary symptom is also confirmed and traced to its exact mechanism: `/tag`'s Step 6 raw
  `git push origin "$new_version"` is intercepted by `hooks/guard-git-push.sh` (a `PreToolUse`
  hook), which calls `pg_grant_consume` (`push-grant-lib.sh:492`), which **also** synchronously
  appends `push_grant_consumed` to `specs/events.jsonl` — before the actual `git push` tool call
  even runs. Every push therefore leaves the tree dirty immediately after pushing, forcing a
  sweep commit, which puts local 1 commit ahead of the just-pushed remote, which (per Step 2's
  `ahead == 0` rule) requires another push — which dirties the log again. This is a true loop,
  not merely "annoying," because each cycle re-enters the same synchronous-append code path.
- **Recommended direction: defer, not narrow.** Change `pg_grant_mint` and `pg_grant_consume` to
  write their audit payload to a new, already-self-ignored local buffer under
  `specs/.push-grant/` (which already carries a `.gitignore` of `*` via `pg_dir_ensure`) instead
  of calling `events-append.sh` directly. Add one new flush function that drains that buffer into
  `specs/events.jsonl` via the existing `events-append.sh`, and wire the flush into the
  **already-existing** `hooks/events-log-lifecycle.sh` Stop hook — the one point in the hook
  pipeline that is guaranteed to run only after the current turn's entire command body (and its
  precondition checks) has finished, and strictly before the next turn's `UserPromptSubmit`
  fires. This removes the self-inflicted, same-turn, structurally-unavoidable dirtying that makes
  `/tag` fail by its own hand, while making the audit's eventual appearance in `events.jsonl` an
  ordinary across-turn dirty-tree fact the operator handles the normal way (commit it), not a
  guaranteed-impossible precondition.
- This single change also fixes the loop (symptom 3): a push's `push_grant_consumed` write goes
  to the same deferred buffer, so a push no longer dirties `events.jsonl` synchronously either.
  At most one flush-sized dirty diff appears per **turn** (not per push-attempt), which cannot
  loop the way "once per push, and every retry re-triggers it" did.
- The audit guarantee for an abandoned/refused/expired grant is preserved for free by this
  design: the buffered record is written at mint time regardless of what later happens to the
  grant file, and the Stop-hook flush drains it unconditionally — it needs no separate "is this
  grant abandoned" branch.
- Blast-radius re-measurement over the **full source store** (not just `.claude/skills/`, which
  only reflects the core extension) surfaced three more `git status --porcelain` occurrences the
  dispatch's narrower grep missed: `skill-orchestrate/SKILL.md`, `extensions/cslib/commands/pr.md`
  (twice), and `extensions/cslib/skills/skill-cslib-vet/SKILL.md` (twice). None of them is a hard
  refusal gate shaped like `/tag`'s Step 1 — see Findings for the per-occurrence read. The
  dispatch's conclusion ("no other command is broken today") holds, but by a more rigorous check
  than the one it described.

## Context & Scope

Researched: the exact code path from `UserPromptSubmit` mint through to `/tag`'s precondition
read; the secondary push/commit loop's mechanism; the existing audit-writing helpers and their
non-fatal-wrapper conventions; the existing fixture-test assertions that couple directly to the
current synchronous-write behavior; the full-source-store blast radius of
`git status --porcelain` usage; and precedent in this codebase for "enumerate and drain a
marker/buffer at a safe later point" (the Stop/SubagentStop hook's `.postflight-pending` marker
correlation logic), which the recommended fix mirrors rather than inventing a new pattern.

Explicitly out of scope per the dispatch's constraints: `scripts/lib/runtime-file-patterns.sh`
and `context/standards/orchestrator-runtime-files.md` (owned by the separate sweep task); any
`.gitignore`-based fix for `specs/events.jsonl` (considered and rejected by the dispatch itself —
it would hide the symptom without fixing the ordering class, and at least one consumer repo
deliberately commits this log).

## Findings

### Codebase Patterns

**The exact synchronous-write call chain (confirmed by direct read, not inference):**

1. `hooks/please-grant.sh` (`UserPromptSubmit`) recognizes `/tag` (line 67-69), sets
   `MINT_SOURCE=tag`, `ACTION_CLASS=push_tag`, and after categorical-exclusion checks calls
   `pg_grant_mint` (line 233).
2. `pg_grant_mint` (`push-grant-lib.sh:473-485`) writes the grant file (self-ignored, harmless)
   and then unconditionally calls `pg_events_append_observable --event-type push_grant_issued ...`
   (line 480-482) — a **direct, synchronous** call into `scripts/events-append.sh`, which appends
   one line to `specs/events.jsonl` (`events-append.sh:183-186`, `flock`-guarded but still a real
   write to a tracked file).
3. This entire sequence happens inside the `UserPromptSubmit` hook, i.e. strictly before
   `skill-tag/SKILL.md`'s command body (Step 1) ever runs.
4. `skill-tag/SKILL.md` Step 1 (line 73): `if [ -n "$(git status --porcelain)" ]; then ... exit 1`
   — reads tree state that step 2 already dirtied.

**The secondary loop's exact mechanism (also confirmed by direct read):**

`/tag`'s Step 6 pushes with a bare `git push origin "$new_version"` (SKILL.md line 491), not
through `scripts/git-push-granted.sh`. This raw push is intercepted by `hooks/guard-git-push.sh`
(a `PreToolUse` hook on `Bash`), which classifies it as `push_tag` (lines 196-204 of that file)
and calls `pg_grant_consume` (line 213) **before the underlying tool call executes**.
`pg_grant_consume` (`push-grant-lib.sh:492-506`) deletes the grant file and then unconditionally
calls `pg_events_append_observable --event-type push_grant_consumed ...` (lines 502-504) — again
a direct, synchronous write to `specs/events.jsonl`. So immediately after a successful push, the
tree is dirty again; sweeping it with a commit puts local one commit ahead of the remote it just
pushed to; re-pushing that commit re-enters this exact same hook/append path. This matches the
dispatch's description of the Verification repository's two extra sweep commits precisely.

**Why `/please`, `/merge`, `/pr` are unaffected *today*:** all three share the identical mint
path (`pg_grant_mint`, same synchronous append), so the dirtying happens for them too — the
difference is purely that none of them currently gates on tree cleanliness the way `/tag`'s
Step 1 does. This is exactly why the dispatch frames this as a class bug: any future command that
adds a clean-tree precondition inherits the same guaranteed failure, independent of which of the
four mint prefixes triggered it.

**Existing non-fatal-wrapper precedent already in the codebase, worth reusing style from:**
`pg_events_append_observable` (`push-grant-lib.sh:460-469`) and
`hooks/events-log-lifecycle.sh`'s own `_events_append_observable` (lines 61-96) both already
establish "a missing/failing `events-append.sh` must never block the caller" as a convention.
The fix below extends this same posture one step further: not just "tolerate `events-append.sh`
failing," but "don't call it synchronously from the mint/consume path at all."

**Existing "enumerate-and-drain" precedent to mirror, not reinvent:**
`hooks/events-log-lifecycle.sh`'s `SubagentStop` path (lines 143-172) already enumerates every
`.postflight-pending` marker under `specs/`, correlates by `cc_session_id`, emits an event, and
implicitly treats the marker as the durable record of "something happened that needs auditing
later." The recommended fix below is structurally the same pattern applied to push-grant audit
records instead of postflight markers.

**Self-ignoring directory already available for the buffer:** `pg_dir_ensure`
(`push-grant-lib.sh:130-139`) already creates `specs/.push-grant/` with a `.gitignore` of literal
`*` on first use. A new buffer file living in this same directory (e.g.
`specs/.push-grant/.pending-audit.jsonl`) inherits this ignore rule for free — no new ignore rule
needs to be added anywhere, and `hooks/guard-git-push.sh`'s existing tamper-guard (Responsibility
B, lines 50-66 of that file) already blocks any Write/Edit or Bash reference to anything under
`${GRANT_DIR_PREFIX}/*`, so the new buffer file is automatically covered by the same
tamper-resistance the grant files themselves get, with zero additional wiring.

### Blast-Radius Re-Measurement (full source store)

The dispatch's own measurement method was "grepped across `.claude/skills/`" (the deployed core
extension only). Re-running the grep over the **full source store**, across every extension,
surfaces more occurrences than the dispatch's own number:

| File | Occurrence(s) | Shape | Mint-prefix relevant? |
|---|---|---|---|
| `extensions/core/skills/skill-tag/SKILL.md` | Step 1 | Hard refusal (`exit 1` on any dirt) | Yes — this is the broken one |
| `extensions/core/skills/skill-orchestrate/SKILL.md:309` | residue check | Explicitly "warn only, never commits" | No — `/orchestrate` is not one of the four mint prefixes (`/please`, `/merge`, `/tag`, `/pr`) |
| `extensions/cslib/commands/pr.md:577`, `:1858` | pre-commit checks | **Auto-commits** dirt (`git add -A && git commit`) before pushing, never refuses | Yes — `/pr` *is* a mint prefix, but this self-healing shape absorbs mint-time dirt into its own commit rather than gating on it |
| `extensions/cslib/commands/pr.md:1431` | new-file detection for a CI note | Not a cleanliness gate at all | N/A |
| `extensions/cslib/skills/skill-cslib-vet/SKILL.md:86`, `:366` | diff-scope / commit-decision | Decides whether to diff or commit, never refuses | No — `vet` is not a mint prefix |

**Conclusion**: the dispatch's claim that no other command is broken *today* holds, but it holds
for a different, more specific reason than "no other skill has this check" — `/pr` *does* have
`git status --porcelain` checks and *is* a mint prefix, yet is unaffected only because its checks
are shaped as "commit the dirt" rather than "refuse on dirt." This is worth recording explicitly
in the plan/implementation, because it means the class fix must not assume "only skill-tag has a
porcelain check" — it must assume "any future **refusal**-shaped porcelain check, on any mint
prefix, inherits this bug," which is the stronger and correct framing the dispatch already uses
in its SCOPE section.

### Test Coupling That Any Fix Must Address

`scripts/tests/test-please-grant.sh` (around line 223) and
`scripts/tests/test-guard-git-push.sh` (around line 294) both assert the audit line lands in
`specs/events.jsonl` via `tail -n1` **immediately** after calling the hook/wrapper, with no flush
step in between. A deferred-buffering fix will change this timing by design, so both existing
assertions need to be updated (either to call the new flush function first, or to assert against
the pending buffer instead of `events.jsonl` directly, with a *second* assertion that flushing
drains it into `events.jsonl`). This is not a reason to avoid the deferred direction — it is a
known, enumerable update, not a hidden regression risk, but it must be accounted for in the
implementation plan's test-touching scope.

## Recommendations

**Primary direction (recommended): defer the audit write, flush at Stop-hook time.**

1. In `scripts/lib/push-grant-lib.sh`, add a small buffer-write helper (e.g.
   `pg_audit_buffer(event_type, category, message, detail_json)`) that appends one JSON line to
   `specs/.push-grant/.pending-audit.jsonl` (created via the existing `pg_dir_ensure`, so it is
   self-ignored with zero new `.gitignore` edits anywhere). Guard the append with `flock` on a
   sibling lock file, mirroring `events-append.sh`'s own `flock` pattern exactly (same technique,
   new lock path, so no shared-lock contention with the real log).
2. Change `pg_grant_mint` (`push-grant-lib.sh:473-485`) to call `pg_audit_buffer` instead of
   `pg_events_append_observable` directly for `push_grant_issued`.
3. Change `pg_grant_consume` (`push-grant-lib.sh:492-506`) to call `pg_audit_buffer` instead of
   `pg_events_append_observable` directly for `push_grant_consumed`.
4. Add `pg_audit_flush()`: enumerate every line in `.pending-audit.jsonl` (if present), call the
   real `scripts/events-append.sh` for each (via the existing `pg_events_append_observable`
   non-fatal wrapper, unchanged), and only truncate/delete the buffer after every line has been
   successfully appended (fail-safe: never discard a pending record before its durable write
   succeeds). Carry the record's original mint/consume timestamp forward into the appended
   event's `detail` (e.g. `detail.recorded_at`) rather than silently backdating or silently
   omitting it — `events.jsonl`'s own `timestamp` field will then honestly reflect *flush* time
   (consistent with "lines are never reordered/mutated," since the flush is itself the one real
   append), while `detail.recorded_at` preserves the true moment the mint or consume happened.
   State this timestamp-semantics choice explicitly in the plan so it isn't rediscovered as a
   surprise later.
5. Wire one unconditional call to `pg_audit_flush` into `hooks/events-log-lifecycle.sh`, near the
   top, before the `AGENT_ID` branch (so it runs on both `Stop` and `SubagentStop`, harmlessly
   finding nothing in the common case where no mint happened this turn). This is the one point
   guaranteed to run after the current turn's entire command body — including any precondition
   check that command performs — and strictly before the next `UserPromptSubmit`. Source
   `push-grant-lib.sh` from this hook the same way it is already sourced elsewhere (guarded,
   never fatal if missing).
6. `pg_grant_revoke` (`push-grant-lib.sh:510-518`) must **not** be changed to flush or append
   anything — it only ever deletes the live grant `.kv` file. The buffered `push_grant_issued`
   record for that grant was already written at mint time and is untouched by revocation, so it
   is still drained by the next Stop-hook flush. **State this explicitly as the mechanism that
   answers SCOPE item 2** ("record of a minted-but-unconsumed grant is still recoverable"):
   revocation deletes the grant *token*, never the audit *record*; an abandoned, refused, or
   expired grant's `push_grant_issued` line reaches `specs/events.jsonl` exactly the same way a
   consumed one does — through the same unconditional flush, with no special-casing needed for
   "this grant was never used."
7. Update the two existing test assertions identified above to call `pg_audit_flush` (or
   simulate the Stop hook) before reading `tail -n1 events.jsonl`.
8. Add the regression test the dispatch's ACCEPTANCE section asks for: a fixture-driven case in
   `scripts/tests/test-please-grant.sh` that (a) mints a `/tag`-shaped grant in a fixture repo
   that already has one commit (so `specs/events.jsonl` would track if it existed), (b) asserts
   `git status --porcelain` is **empty** immediately after the mint (pinning the ordering fix
   directly, independent of `skill-tag` itself, since the skill body is markdown-prose, not an
   executable test target), and (c) separately asserts the pending buffer now holds the record
   and `events.jsonl` does not yet. A second case in the same spirit for
   `test-guard-git-push.sh`, covering `pg_grant_consume`'s own deferral.

**Fallback (if deferral proves infeasible — the dispatch explicitly permits this as the
narrower, inferior alternative): teach `skill-tag/SKILL.md` Step 1 to filter its own
`git status --porcelain` output, excluding only the literal path `specs/events.jsonl`, before
deciding dirty-or-clean.** This is strictly inferior for three reasons already implied by the
dispatch and corroborated by this research: (a) it fixes only `/tag`, not the class — any future
skill adding its own refusal-shaped porcelain check (including, per the blast-radius table above,
a tightened `/pr`) inherits the bug fresh; (b) it does nothing for the secondary push/commit loop,
which would need an entirely separate, differently-shaped fix (e.g. the same literal-path
filtering applied to `/tag`'s `ahead == 0` check, which only partially addresses the loop since
other commands' pushes would still dirty the log); (c) it does not generalize to a consumer repo
that gitignores `specs/events.jsonl` differently or tracks additional push-grant-adjacent files
later. Adopt this only if the Stop-hook flush point is found, during planning or implementation,
to be unreliable in some environment this system must support (no such unreliability was found
during this research — `hooks/events-log-lifecycle.sh` is already registered on both `Stop` and
`SubagentStop` in `root-files/settings.json` and already performs equivalent-shaped deferred work
today).

## Decisions

- **Edit target confirmed**: all three implicated files resolve under the `core` extension's
  `source_dir`, `agent-system/extensions/core/`, exactly as the dispatch recorded. No further
  resolution needed.
- **Gitignoring `specs/events.jsonl` is out of scope**, per the dispatch's own constraint; this
  research did not revisit that decision and recommends against revisiting it here — it is the
  other task's call, and the deferred-write fix stands on its own regardless of how that
  classification eventually lands (restated from the dispatch, not a new decision of this
  report).
- **This report does not modify `scripts/lib/runtime-file-patterns.sh` or
  `context/standards/orchestrator-runtime-files.md`**, per the dispatch's constraint; verified
  neither was touched during this research pass (no edits were made at all — this is a research
  dispatch).
- **Recommended adoption**: the deferred/buffered-write direction (Recommendations, primary),
  not the Step-1-filename-filter fallback. Reason: it fixes the class (SCOPE item 1's explicit
  ask), fixes the secondary loop in the same mechanism (SCOPE item 3) rather than needing a
  second, differently-shaped fix, and preserves the audit guarantee for an abandoned grant by
  construction rather than by a special case (SCOPE item 2). The planning phase should record its
  own final adoption call against this recommendation, per the dispatch's ACCEPTANCE criterion
  ("whichever direction was adopted is recorded with its reason") — this report provides that
  reasoning but the formal adoption record belongs in the plan artifact.

## Risks & Mitigations

- **Risk**: changing `pg_grant_mint`/`pg_grant_consume` to stop calling `events-append.sh`
  directly could silently drop the audit trail if the new flush point is ever skipped (e.g. a
  Claude Code version that stops firing `Stop` reliably, or a session that crashes before `Stop`
  fires). **Mitigation**: the buffer file is durable, append-only, and on-disk independent of any
  hook firing — a crashed session simply leaves pending records for the *next* session's Stop (or
  a future maintenance sweep) to drain; nothing is lost unless the buffer file itself is deleted,
  which is no worse than `specs/events.jsonl` itself being deleted today. Recommend also exposing
  a manual drain path (e.g. `pg_audit_flush` callable directly, or wired into `/distill` or
  `/refresh`'s existing sweep machinery) as defense-in-depth, though this is not required to meet
  the dispatch's ACCEPTANCE criteria and can be deferred to the implementation phase's judgment.
- **Risk**: the two existing fixture tests' assertions will fail immediately once the write path
  changes, unless updated in the same pass. **Mitigation**: already identified precisely (file
  and line) in Findings; the implementation plan should treat updating both as in-scope, not as
  a surprise discovered mid-implementation. Logged as an issue-log entry during this research
  pass.
- **Risk**: a flush at Stop-hook time still dirties the tracked file eventually, so a *second*,
  immediate `/tag` retry in the same session (before any commit happens) will still fail Step 1 —
  by design, this is now an ordinary dirty-tree situation rather than a structural impossibility,
  but it is worth stating explicitly so the acceptance testing doesn't mistake "a retry without
  committing first still fails" for a regression. **Mitigation**: document this explicitly in the
  plan/summary language the dispatch's ACCEPTANCE criterion already allows for ("skill-tag Step 1
  passes in a repository that tracks specs/events.jsonl" — true for the first, un-retried
  invocation per turn, which is the failure mode actually reported).

## Context Extension Recommendations

- **Topic**: deferred/buffered audit writes for hook-originated, tracked-file-touching side
  effects.
- **Gap**: `context/formats/events-format.md` documents the schema and the synchronous
  `events-append.sh` contract thoroughly, but has no section on the specific hazard of appending
  from a `UserPromptSubmit` or `PreToolUse` hook ahead of a command's own precondition read, nor
  on the buffer-then-flush pattern this report recommends.
- **Recommendation**: once the fix lands, add a short subsection to
  `context/formats/events-format.md` (or a new `context/patterns/` file) documenting the
  buffer-then-flush pattern as the sanctioned way for any future hook that both (a) fires ahead
  of a command body and (b) needs to record something durably, to avoid reintroducing this exact
  class of bug. This is a documentation follow-up, not something this research report creates
  itself.

## Appendix

- Search queries / commands used: direct `Read` of every implicated file in full; `grep -rln
  "git status --porcelain"` across `extensions/*/skills/`, `extensions/*/commands/`, and
  `extensions/*/scripts/` (excluding `tests/`) for the blast-radius re-measurement; `grep -n
  "push_grant_issued\|push_grant_consumed\|events.jsonl\|nested"` over both existing test files to
  locate the coupled assertions; `grep -rln "deferred\|buffer\|pending_event\|events.pending\|flush"`
  to confirm no existing deferred-write mechanism already exists for this log that could be
  reused as-is.
- Files read in full: `scripts/lib/push-grant-lib.sh`, `scripts/events-append.sh`,
  `hooks/please-grant.sh`, `skills/skill-tag/SKILL.md`, `scripts/git-push-granted.sh`,
  `hooks/guard-git-push.sh` (relevant sections), `hooks/events-log-lifecycle.sh` (relevant
  sections), `context/standards/push-consent-relay.md`, `context/formats/events-format.md`
  (relevant sections), both test files' relevant sections.
