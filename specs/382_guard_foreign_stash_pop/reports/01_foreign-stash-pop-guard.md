# Research Report: Task #382

**Task**: 382 - Refuse git stash pop/apply of a stash entry the session did not create
**Started**: 2026-10-14T00:00:00Z
**Completed**: 2026-10-14T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/hooks/guard-destructive-git.sh`, `agent-system/extensions/core/hooks/guard-git-push.sh`, `agent-system/extensions/core/hooks/please-grant.sh`, `agent-system/extensions/core/hooks/detect-noop-bash.sh`, `agent-system/extensions/core/scripts/lib/push-grant-lib.sh`, `agent-system/extensions/core/scripts/git-snapshot.sh`, `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`, `agent-system/extensions/core/context/standards/git-workflow-narrative.md`, `.claude/rules/git-workflow.md`, `agent-system/extensions/core/merge-sources/settings-hooks.json`, `agent-system/extensions/core/root-files/settings.json`
**Artifacts**:
- `specs/382_guard_foreign_stash_pop/reports/01_foreign-stash-pop-guard.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The mechanism git-workflow.md's GOAL asks for ("record the stash sha whenever the session's
  own `git stash push` succeeds, check the target's sha against that record") is buildable
  entirely on infrastructure that already exists in this codebase: a `PostToolUse` hook keyed
  to Claude Code's own native per-call session id (`CC_SESSION_ID`, already how
  `detect-noop-bash.sh` and `subagent-postflight.sh` scope per-session state) paired with a tiny
  addition to the existing `PreToolUse` guard (`guard-destructive-git.sh`).
- The recommended design diffs `git stash list` **before and after each whole Bash tool call**
  (not by pattern-matching the literal command text) to decide which stash commits this session
  created. This is deliberately NOT text-matching on `git stash push`, because it also has to
  cover `git-snapshot.sh`'s internal, subprocess-invisible stash creation (the sanctioned
  rollback flow the GOAL requires to keep working) — see Findings below for why a text-matching
  design would miss that case.
- A session-created entry is recorded in a per-`CC_SESSION_ID` ledger file under `.claude/tmp/`
  (the exact convention `detect-noop-bash.sh` already uses). `guard-destructive-git.sh`'s
  existing stash detector gains a `pop`/`apply` arm (today these two subcommands fall straight
  through, unmatched, to the end of the file) that resolves the target ref to a commit sha via
  `git rev-parse` and checks it against that ledger.
- A new `DESTRUCTIVE_ACTION_CLASS="stash_pop_foreign"` slots into the grant-check block that
  already exists in `guard-destructive-git.sh` (lines 550-577) with zero new plumbing beyond
  registering the class name in `push-grant-lib.sh`'s `PG_ACTION_CLASSES` and in
  `please-grant.sh`'s mint grammar — this directly satisfies the GOAL's "ask the user before
  applying a foreign entry" language using the identical consent primitive `/please` already
  provides for `stash_drop`/`stash_revert`.
- Recommended refusal message content, required fixture coverage, and the exact doc edits
  (`.claude/rules/git-workflow.md`'s "Not blocked" list; the narrative doc's Item 8 verdict) are
  detailed below.

## Context & Scope

**Incident being closed.** In the consumer repo `~/Projects/Logos/Verification` (2026-10-09), an
implementation agent ran `git stash push -- <path>` while diagnosing a test failure. Nothing was
stashed ("No local changes to save" — the path had no uncommitted changes relative to HEAD). The
agent then ran `git stash pop`. Since nothing of the agent's own was on the stack, the pop
applied and **dropped** `stash@{0}`, a pre-existing, unrelated WIP entry a different task/user had
left there. Net tree content happened to come out even, but the stash entry itself is gone,
recoverable (if at all) only via `git fsck --unreachable | grep commit` plus manual inspection.

**Why this was legal under the current rule.** `guard-destructive-git.sh`'s stash detector (its
`STASH_SUBCMD` case block, `agent-system/extensions/core/hooks/guard-destructive-git.sh:481-525`)
explicitly treats `pop`/`apply`/`list`/`show`/`branch`/`drop`/`clear`/`create`/`store` as "not
this detector's business" and falls through — i.e. unconditionally permitted, documented as
Item 8 in `.claude/rules/git-workflow.md`'s "Not blocked" list and justified at length in
`context/standards/git-workflow-narrative.md`'s "Item 8 verdict" paragraph (the safe-failure
argument: a conflicting pop/apply fails loudly rather than silently discarding). That argument is
correct for the *sibling-conflict* hazard it was written against, but it does not cover — and was
never asked to cover — the *wrong-identity* hazard this task closes: a pop that has nothing of
its own to apply still **succeeds** and still drops whatever foreign entry happens to be at the
top of the stack, because git has no way to know the caller "meant" to restore its own work
rather than someone else's.

**Scope of this research.** Design the detection/recording mechanism (GOAL explicitly delegates
"research picks the mechanism"), identify every file that needs to change, and specify the
fixture coverage the ACCEPTANCE criteria require. Implementation itself is out of scope for this
report; the SOURCE STORE IS THE EDIT TARGET directive (`agent-system/extensions/core/**`,
redeployed afterward) and the no-task-number-in-deliverables rule both apply to whatever
implementation phase follows and are called out below as constraints that phase inherits, not as
describing anything mutated here.

## Findings

### Current stash handling in `guard-destructive-git.sh`

The stash detector (lines 436-528) already classifies every `git stash ...` invocation by
sub-command. `drop`/`clear` block unconditionally (hazard: `stash_drop`). Bare/whole-tree
`stash`/`stash push` with no pathspec blocks under a dirty tree (hazard: `stash_revert`,
justified by the *concurrent-writer* incident documented in the narrative doc's "Bare git stash
Incident" section — a different, already-fixed incident from this task's). A pathspec-scoped
`git stash push -- <path>` is explicitly exempted (Item 7) because its blast radius is bounded to
named paths. `pop`/`apply` (along with `list`/`show`/`branch`/`create`/`store`) fall into a
`continue` arm with no handling at all — this is the exact gap this task closes.

### Why the mechanism must not be "text-match the stash push command"

`git-snapshot.sh` — the sanctioned, documented recovery helper whose rollback flow the GOAL
requires to "keep working" — creates its own stash entries from **inside a subprocess**:
default mode runs `git stash push -u -m "git-snapshot-${TASK_NUM}-${TS}"`
(`agent-system/extensions/core/scripts/git-snapshot.sh:496`), and `--no-revert` mode runs
`git stash create` + `git stash store`
(`agent-system/extensions/core/scripts/git-snapshot.sh:464-472`). From the hook's observation
point, the literal Bash command the agent ran is `bash .claude/scripts/git-snapshot.sh ...` — the
internal `git stash push`/`git stash create` text is **never visible** to
`guard-destructive-git.sh`. This exact invisibility is already documented and accepted
elsewhere in the same file (the `git add -A` note at lines 79-85, and the `git-commit-scoped.sh`
note at lines 97-98) and is called out as a "known residual risk" specifically for
`git-snapshot.sh`'s internal stash in `context/standards/git-workflow-narrative.md`'s final
paragraph of the "Bare git stash Incident" section. A design that records ownership by
pattern-matching the literal command text (e.g. "this command's argv was `git stash push --
<path>`, therefore record its resulting sha") would correctly cover direct agent-issued stash
pushes but would **not** cover `git-snapshot.sh`'s internal stash — reproducing the very
residual risk the GOAL asks to close, for exactly the sanctioned recovery flow that must keep
working.

### Recommended mechanism: whole-call stash-set diffing, not command-text matching

Diff the **set of stash commit shas** immediately before and immediately after each Bash tool
call, regardless of what that call's command text was. Any sha present after the call that was
not present before it was created by this call, by construction — whether the call's literal
text was `git stash push -- foo.txt` or `bash .claude/scripts/git-snapshot.sh 382`. This closes
the `git-snapshot.sh` gap with zero special-casing of that script, and it also naturally handles
the "push saved nothing, then pop" shape from the incident: a `git stash push -- <path>` that
stashes nothing leaves the before/after sha sets identical, so nothing gets recorded as
session-owned, so the following `pop` (which resolves to the pre-existing foreign entry) is
correctly refused.

**Two cooperating hook changes, both already-precedented shapes in this codebase:**

1. **`guard-destructive-git.sh` (PreToolUse, existing file) gains a one-line prelude**: before
   any of its existing early exits, with `CC_SESSION_ID` read from stdin's top-level
   `.session_id` (the same field `events-log-lifecycle.sh` and `subagent-postflight.sh` already
   read and validate against `^[A-Za-z0-9_-]+$` before using it in a path —
   `agent-system/extensions/core/hooks/detect-noop-bash.sh`'s session-id-safety check is the
   closest precedent to copy verbatim), write `git stash list --format=%H` to a per-session
   "pre" file, e.g. `.claude/tmp/stash-pre-<CC_SESSION_ID>` (state dir overridable via an env var
   the same way `NOOP_BASH_STATE_DIR` overrides `detect-noop-bash.sh`'s state dir, so tests never
   write into the source store's own `tmp/`). This runs unconditionally for every Bash call this
   hook already sees — it does not depend on recognizing stash-related command text.

2. **A new PostToolUse hook, `record-stash-provenance.sh`**, registered on the `PostToolUse`
   `"Bash"` matcher. This matcher **already exists** and already carries exactly one hook today
   — `detect-noop-bash.sh`, wired in
   `agent-system/extensions/core/merge-sources/settings-hooks.json`'s `hooks.PostToolUse` array
   (note: `root-files/settings.json`, the deployed copy this repo's dispatch-time
   `<deploy-freshness-context>` flagged as stale for the `core` extension, does not yet show this
   `Bash` PostToolUse matcher at all — confirming the staleness warning was accurate and that the
   merge-source file, not the deployed copy, is the one to read/edit). The new hook: reads
   `CC_SESSION_ID` the same way; reads the "pre" file guard-destructive-git.sh just wrote for
   this exact call; computes the current `git stash list --format=%H` as "post"; for every sha in
   "post" that is not in "pre", appends it to a per-session **owned ledger**,
   `.claude/tmp/stash-owned-<CC_SESSION_ID>`. Because each call's "pre" snapshot already reflects
   every prior call's results, a sha is only ever appended once — no separate de-duplication pass
   is required, though a defensive `grep -qxF` guard before appending costs nothing.

3. **`guard-destructive-git.sh`'s stash `case` block** (line 481) splits `pop|apply` out of the
   existing `list|show|branch|drop|clear|create|store` fall-through arm into their own handling:
   resolve the target ref (first non-flag token after the subcommand, skipping `-q`/`--quiet`/
   `--index`; default `stash@{0}` when none is given — matching how bare `git stash pop`/`apply`
   behave), resolve it to a commit sha via `git rev-parse "<ref>" 2>/dev/null`, and look it up in
   the owned ledger (`grep -qxF`). Found → fall through unblocked, exactly as today. Unresolvable
   ref → also fall through unblocked (nothing destructive can happen; git will itself error on
   an invalid ref, which is not a data-loss case this guard needs to intervene in). Resolvable
   but **not** in the ledger → set `MATCHED=1`, `DESTRUCTIVE_ACTION_CLASS="stash_pop_foreign"`,
   and a `REASON` naming the hazard, feeding the *existing* downstream flow unchanged (grant
   check, then snapshot-marker exemption, then the final `BLOCKED` message/`exit 2`).

### Reusing the existing consent-gate primitive for "ask the user"

The GOAL's closing clause — "ask the user before applying a foreign entry" — maps directly onto
the grant mechanism `push-grant-lib.sh` already implements and `guard-destructive-git.sh` already
calls (the "Grant check" block at lines 550-577, which is generic over
`DESTRUCTIVE_ACTION_CLASS` and needs no new code to accept a new class name). Two registration
points, both already documented as a matched pair by cross-reference comments in the existing
code:

- `push-grant-lib.sh:78`, `PG_ACTION_CLASSES` — add `stash_pop_foreign` to the space-separated
  list (validation: `pg_grant_mint`/`pg_grant_verify` fail closed on any unregistered name).
- `please-grant.sh:152-168`'s destructive-form `case "$TEXT"` block, plus its accepted-forms
  error text at line 186 — add a recognized phrase (e.g. `"git stash pop"`/`"stash pop"`/
  `"git stash apply"`/`"stash apply"`) that sets `ACTION_CLASS="stash_pop_foreign"`, mirroring
  `stash_drop`'s/`stash_revert`'s existing arms exactly (same `REMOTE="local"`,
  `REF=<current branch or HEAD>`, `FORCE="0"` sentinel shape — no remote/force concept applies).

This gives a human a one-time `/please stash pop` / `/please stash apply` grant path for the
*legitimate* foreign-pop case (e.g. a human operator recovering a `git-snapshot.sh` entry left
over from an earlier, different session/dispatch of the same task — see the cross-session caveat
below) without inventing a second consent mechanism.

### A scoping caveat worth surfacing, not solving, here

The GOAL's phrasing ("the target entry was created by the same **session**") and this report's
`CC_SESSION_ID`-keyed design both scope ownership to one Claude Code native session. A task that
spans multiple `/orchestrate` dispatches gets a fresh `CC_SESSION_ID` per dispatch, so a stash a
`git-snapshot.sh` run created in one dispatch's session would read as "foreign" to a *later*
dispatch's session attempting the documented recovery pop. This is not a gap the mechanism
accidentally introduces — it is the literal, explicit scope the GOAL specifies — and the grant
path above already gives a legitimate, auditable escape hatch for exactly this case (consistent
with the GOAL's own "ask the user" fallback). It is flagged here as a planning-time judgment
call, not resolved by this report: a wider "same task" scope (keyed to the task directory, or to
`git-snapshot.sh`'s own `git-snapshot-<task>-<ts>` stash message convention, rather than to
`CC_SESSION_ID`) is a plausible alternative the plan phase may choose instead, trading "survives
a dispatch boundary" against "scoped exactly as narrowly as the GOAL text states."

### Test fixture coverage needed

`agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` already has
`assert_allowed_dirty` cases asserting **unconditional** allowance of `git stash apply` (line
208-209) and `git stash pop` (line 217) — both now wrong under the new rule and must be rewritten
to supply a session id and exercise both the owned and foreign paths. Its `run_hook_in` helper
(`cd "$repo" && jq -n --arg c "$cmd" '{tool_input: {command: $c}}' | bash "$HOOK"`) builds a
payload with **no** top-level `session_id` field at all — it must gain a parameter for one, since
the new ownership check depends on it. Needed fixtures, directly off the three ACCEPTANCE
sentences:

1. **Session-created entry pop passes**: in a fixture repo, with a session id threaded through
   both the push call and the pop call, run `git stash push -- tracked.txt` (real, non-empty
   diff) then `git stash pop` — expect exit 0.
2. **Foreign entry pop/apply refused, including the exact incident shape**: seed the fixture repo
   with a stash entry created *without* going through the hook's own session machinery (e.g. a
   raw `git -C "$repo" stash push -m preexisting`, simulating another user/task's WIP), then run
   `git stash push -- tracked.txt` with nothing actually dirty at that path ("No local changes to
   save") under a tracked session id, then `git stash pop` under that same session id — expect
   exit 2, and assert (via a post-check, not via the hook's exit code) that the pre-existing
   entry is still present in `git stash list` afterward, i.e. that the refusal actually prevented
   the drop rather than merely returning the wrong code on an already-mutated tree.
3. **`git-snapshot.sh` rollback unaffected**: run `git-snapshot.sh <task>` (default mode) against
   a dirty fixture under a tracked session id — the real script, not a stub, since the point
   being tested is specifically that its *internal*, subprocess-invisible stash push is captured
   — then run the exact `git stash pop <STASH_REF>` the script printed, same session id — expect
   exit 0.
4. A fourth, regression-shaped case worth adding alongside the above: the same foreign-pop
   fixture but with **no** `session_id` field in the payload at all (mirroring every pre-existing
   case in the suite) — this must still refuse, so a missing/absent session id can never be
   read as "nothing to check against, so allow" (fail-closed, matching
   `push-grant-lib.sh`'s documented fail-closed posture rather than `detect-noop-bash.sh`'s
   fail-open one, since the two hooks protect different things: a missed nudge is harmless, a
   missed data-loss refusal is not).

A companion unit-style test for the new `record-stash-provenance.sh` hook itself (independent of
`guard-destructive-git.sh`) should assert: a Bash call that creates a new stash entry appends
exactly one new line to the owned ledger; a Bash call that creates no new stash entry (including
the "push saved nothing" shape) appends nothing; a missing/unreadable "pre" file is treated as
"record nothing new" rather than "everything currently present is newly owned" (fail-closed in
the safe direction — see the ownership-ledger write-up above).

### Documentation updates required

- `.claude/rules/git-workflow.md`'s "Not blocked" list (source: wherever this rule's
  merge-source lives in `agent-system/extensions/core/`) currently reads `git stash pop`/
  `git stash apply` (permitted)" unconditionally — this needs to become conditional language
  ("permitted only for a stash entry this session created; a foreign entry requires a `/please`
  grant").
- `context/standards/git-workflow-narrative.md`'s "Item 8 verdict, extended reasoning" paragraph
  needs a new paragraph (not a rewrite of the existing safe-failure argument, which remains
  correct for the sibling-conflict hazard it was written against) stating the *new*,
  wrong-identity hazard this task closes and pointing at this task's own incident evidence. The
  existing "Known residual risk — `git-snapshot.sh`'s own internal stash" paragraph should be
  updated to note that the new provenance mechanism resolves the subprocess-invisibility gap for
  *this* purpose specifically (session-scoped pop authorization) while leaving the concurrent-
  writer hazard that paragraph originally describes unchanged (a different hazard, not fixed by
  this task).

## Decisions

- **Ownership mechanism is whole-Bash-call stash-set diffing (before/after `git stash list
  --format=%H`), not literal command-text matching.** Rationale: command-text matching cannot see
  `git-snapshot.sh`'s internal stash creation (subprocess-invisible to the hook), and the GOAL
  requires that sanctioned flow to keep working. Diffing is agnostic to which command created the
  new entry.
- **Session scoping key is Claude Code's native `CC_SESSION_ID`** (stdin's top-level
  `.session_id`), the same key `detect-noop-bash.sh` and `subagent-postflight.sh` already use for
  per-session hook state — not a new identity scheme.
- **The "ask the user" fallback for a foreign pop reuses the existing push-grant primitive**
  (`push-grant-lib.sh` + `please-grant.sh` + `guard-destructive-git.sh`'s existing, class-generic
  grant-check block) rather than inventing a second consent mechanism. New action class name:
  `stash_pop_foreign`.
- **An unresolvable target ref is not blocked** (falls through unmatched) — git will itself
  refuse a genuinely bad ref, and this guard only needs to intervene where a silent, successful
  data-loss operation is otherwise possible.
- **A missing/absent `session_id` on the hook payload must be treated as "nothing is owned"
  (fail-closed), never as "no check to perform."** This is the one place this design deliberately
  diverges from `detect-noop-bash.sh`'s fail-open convention, because the two hooks protect
  different failure directions (a missed advisory nudge vs. a missed data-loss refusal).
- **The cross-dispatch (multi-session, same task) recovery case is left to the `/please` grant
  path rather than widened into the automatic-ownership check.** This matches the GOAL's own
  literal "same session" wording; a plan may reasonably choose a wider scope instead (see the
  caveat above), but that is a planning-time choice, not settled here.

## Recommendations

1. Add the one-line session-scoped "pre" snapshot write to the top of
   `agent-system/extensions/core/hooks/guard-destructive-git.sh` (before its existing early
   exits), reusing `detect-noop-bash.sh`'s session-id-safety check and state-dir-override
   convention verbatim rather than inventing a new one.
2. Add `agent-system/extensions/core/hooks/record-stash-provenance.sh` as a new `PostToolUse`
   `"Bash"`-matcher hook, registered in
   `agent-system/extensions/core/merge-sources/settings-hooks.json`'s `hooks.PostToolUse` array
   (alongside the existing `detect-noop-bash.sh` entry) and added to `manifest.json`'s file list
   the same way `detect-noop-bash.sh` is listed (both its hook-file line and its test-file line).
3. Split `pop|apply` out of `guard-destructive-git.sh`'s stash `case` fall-through arm
   (currently line ~482) into ownership-checking logic as described in Findings, producing
   `DESTRUCTIVE_ACTION_CLASS="stash_pop_foreign"` on a resolvable-but-unowned target.
4. Register `stash_pop_foreign` in `push-grant-lib.sh:78`'s `PG_ACTION_CLASSES` and in
   `please-grant.sh`'s destructive-form `case` block (plus its accepted-forms error text),
   mirroring `stash_drop`/`stash_revert`'s existing arms.
5. Extend the final `BLOCKED` stderr block in `guard-destructive-git.sh` (currently lines
   603-627) with a `stash_pop_foreign`-specific branch naming `git stash show -p stash@{N}` for
   inspection and the `/please stash pop`/`/please stash apply` grant path, per the GOAL's exact
   guidance language.
6. Update the four fixtures enumerated in Findings (plus the companion
   `record-stash-provenance.sh` unit test) in
   `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`, including rewriting
   its two now-incorrect unconditional-allow assertions for `pop`/`apply` and adding a
   `session_id` parameter to `run_hook_in`.
7. Update `.claude/rules/git-workflow.md`'s "Not blocked" list and
   `context/standards/git-workflow-narrative.md`'s Item 8 verdict and residual-risk paragraphs as
   described in Findings' "Documentation updates required" subsection.
8. Carry forward, unresolved, the cross-dispatch scoping caveat (Findings/Decisions above) as an
   explicit open question for the plan phase to settle one way or the other, rather than letting
   it default silently to the narrower same-`CC_SESSION_ID` reading.

## Risks & Mitigations

- **Risk**: diffing `git stash list` on every single Bash call adds a small, constant per-call
  cost. **Mitigation**: `git stash list` is O(stash-entry-count) and typically empty or tiny;
  this is the same cost class already paid by the hook's existing `git status --porcelain` check
  on every call.
- **Risk**: a crash or race between the PreToolUse "pre" write and the PostToolUse "post" read
  could leave a stale or missing "pre" file. **Mitigation**: treat a missing/unreadable "pre" file
  as "record nothing new" (fail toward under-recording, which only ever produces an extra,
  recoverable refusal — never a false ownership grant).
- **Risk**: the message-free, sha-only ownership ledger grows unboundedly within a very long
  session. **Mitigation**: out of scope for correctness (ledger entries are one line of a 40-
  character hex sha each; even thousands of entries are negligible), but the plan phase may want
  to note the ledger lives under the already-ephemeral, session-scoped `.claude/tmp/` namespace
  and is never read back across sessions, so it needs no explicit cleanup beyond what already
  reclaims that directory.
- **Risk**: widening scope later (the cross-dispatch caveat) if decided differently than this
  report's default could require re-deriving ownership from `git-snapshot.sh`'s own stash-message
  convention (`git-snapshot-<task>-<ts>`) instead of/in addition to the session ledger. **Mitigation**:
  flagged explicitly above as a planning-time choice so it is not discovered as a surprise during
  implementation.

## Context Extension Recommendations

- **Topic**: per-session hook state conventions (state-dir location, `CC_SESSION_ID` validation,
  test-isolation env-var override).
- **Gap**: this pattern is currently documented only inline, per-hook, in `detect-noop-bash.sh`'s
  own header comment and `subagent-postflight.sh`'s correlation comments — there is no single
  `context/standards/` page naming it as a reusable hook-authoring convention, which this report
  had to reconstruct by reading two separate hook files.
- **Recommendation**: a short `context/standards/hook-session-state.md` (or an addition to an
  existing hooks-authoring doc, if one exists) stating the convention once: `.claude/tmp/
  <purpose>-<CC_SESSION_ID>`, the `^[A-Za-z0-9_-]+$` safety check before first use in a path, and
  the env-var override name pattern for test isolation — so the next hook needing per-session
  state (this one included) does not have to re-derive it by reading `detect-noop-bash.sh`.

## Appendix

- Search queries / exploration: direct file reads of `guard-destructive-git.sh`,
  `guard-git-push.sh`, `please-grant.sh`, `push-grant-lib.sh`, `git-snapshot.sh`,
  `detect-noop-bash.sh`, `log-session.sh`, `test-guard-destructive-git.sh`, and
  `git-workflow-narrative.md`; `grep`/`jq` probes of `root-files/settings.json` vs.
  `merge-sources/settings-hooks.json` to confirm which carries the live `PostToolUse` `"Bash"`
  matcher (the merge source does; the deployed copy, flagged stale by this dispatch's own
  `<deploy-freshness-context>`, does not).
- No web search was needed: this is a self-contained hook-design question answerable entirely
  from the existing codebase's own established patterns.
