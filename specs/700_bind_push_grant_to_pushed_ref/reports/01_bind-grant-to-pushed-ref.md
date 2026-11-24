# Research Report: Task #700

**Task**: 700 - Bind a push grant to the pushed ref
**Started**: 2026-11-24
**Completed**: 2026-11-24
**Effort**: small (two call sites plus matching test cases)
**Dependencies**: None (independent successor; shares `hooks/please-grant.sh` with the
`/merge`-removal successor, sequenced against it, not depended on by it)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/hooks/please-grant.sh`,
`scripts/lib/push-grant-lib.sh`, `hooks/guard-git-push.sh`, `scripts/git-push-granted.sh`,
`scripts/tests/test-please-grant.sh`, `scripts/tests/test-guard-git-push.sh`,
`context/patterns/ref-plumbing-landing.md`, `scripts/review-stack-prepare.sh`); the ruling
`specs/decisions/slice-command-one-path-to-review.md` ("Grants", "Successors" row 6, E7)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The HEAD-binding lives at exactly two call sites, both already named in the dispatch
  territory: the mint point in `hooks/please-grant.sh` (single `HEAD_SHA="$(git rev-parse HEAD
  ...)"` assignment, now at line 211) and the match point `pg_grant_find_match()` in
  `scripts/lib/push-grant-lib.sh` (single `head_sha="$(git rev-parse HEAD ...)"` assignment, now
  at line 453, compared at line 464). No third call site exists; `hooks/guard-git-push.sh` and
  `scripts/git-push-granted.sh` only ever pass a bare branch-name string through to these two
  functions and read no SHA themselves — neither needs a code change.
- The fix is narrow and symmetric: for `ACTION_CLASS=push_branch` only, resolve
  `refs/heads/${REF}`'s own commit instead of `HEAD` at both the mint point and the match point.
  Because a checked-out branch's `refs/heads/<name>` always equals `HEAD`, this one change
  simultaneously fixes the non-checked-out case and leaves the checked-out-branch case
  byte-for-byte unchanged — no `is this the checked-out branch` branch is needed in either file.
  `push_tag` (whose stored `REF` is always the literal pattern `refs/tags/*`, never a resolvable
  ref) and the six destructive classes (whose `REF` is always the checked-out branch or the
  `HEAD` sentinel) are excluded from the new resolution by gating strictly on
  `action_class = push_branch`, and are therefore provably unaffected.
- Research confirms neither `scripts/git-push-granted.sh` nor any context/standards document
  states the HEAD-binding as a textual fact needing correction — `file_scope` does not need
  extending beyond the five files the dispatch already names.

## Context & Scope

Today a push grant's `HEAD_SHA` field is bound, at mint time, to `git rev-parse HEAD` — not to
the commit of whatever ref the grant actually names — and is matched, at consume time, against
`git rev-parse HEAD` again. For a ref built by plumbing (a branch advanced by `git commit-tree` +
`git update-ref` without a checkout, per `context/patterns/ref-plumbing-landing.md`) and then
pushed while some *other* branch is checked out, this produces two failures the ruling states
under "Grants": (a) any commit on the checked-out branch inside the 600-second window kills the
grant even though the named ref never moved, and (b) the grant does not pin what gets pushed,
because the named ref can be rebuilt between the typed `/please` line and the actual push without
the match noticing.

This task's scope is successor 6 of the ruling's "Successors" table: bind the grant to the named
ref's own commit instead of `HEAD`, for a grant naming a ref other than the checked-out branch.
A grant for the checked-out branch must keep behaving exactly as it does today. The expiry
window (`PG_EXPIRY_WINDOW`, default 600s), the one-live-grant-at-a-time rule, and the
default-branch force bar are all explicitly unchanged. Out of scope: a typed `/slice push <id>`
minting path (successor 2) and a batch grant (successor 3) — `/please push <remote> <branch>`
already names any branch today, checked out or not, and this task changes only what such a
grant is *bound to*, never who can mint one or how. Also out of scope: the `/merge`-minting
branch of `please-grant.sh`, which is removed by the separate `/merge`-removal successor
(ordered after this one, sharing the same file).

## Findings

### Codebase Patterns

**Mint-time binding — `hooks/please-grant.sh`** (currently 253 lines). After all four
mint-source branches (`/please`, `/merge`, `/tag`, `/pr`) have set `ACTION_CLASS`, `REMOTE`,
`REF`, and `FORCE`, exactly one line computes the bound commit, unconditionally:

```
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)" || HEAD_SHA=""
[ -n "$HEAD_SHA" ] || exit_ok
```

(line 211, per the ruling's own citation — confirmed unchanged at this line.)

This value is passed straight into `pg_grant_mint "$ACTION_CLASS" "$REMOTE" "$REF" "$FORCE"
"$HEAD_SHA" ...` and is also used for the `SHORT_SHA` echoed back to the user. `REF` for
`/please push <remote> <branch>` is a free-text branch-name token parsed by the grammar (no
`refs/heads/` prefix); `REF` for `/merge`/`/pr` is always `git rev-parse --abbrev-ref HEAD`
(i.e. always the checked-out branch, by construction); `REF` for `/tag` is the literal pattern
`refs/tags/*` (the tag does not exist yet when `/tag` is typed); `REF` for the six destructive
classes is the checked-out branch name or the sentinel `HEAD` (detached). Only the `/please
push <remote> <branch>` and `/please push <branch> to <remote>` and `/please push <remote>
<branch>` grammar forms can ever produce a `push_branch` grant whose `REF` differs from the
checked-out branch — none of the other three mint sources can.

**Consume-time matching — `scripts/lib/push-grant-lib.sh`'s `pg_grant_find_match()`** (the
single function both `guard-git-push.sh` and `git-push-granted.sh` call into, via
`pg_grant_consume`). The relevant lines:

```
head_sha="$(git rev-parse HEAD 2>/dev/null)" || return 1
...
[ "$PG_F_HEAD_SHA" = "$head_sha" ] || continue
```

This runs once per candidate grant file in the loop, but `head_sha` itself is computed once,
before the loop, from `HEAD` unconditionally — it does not vary by the grant's own `ACTION_CLASS`
or `REF`, even though both are already caller-supplied parameters to this very function. This is
the exact second half of the HEAD-binding the ruling describes, and it is already parameterized
by everything the fix needs (`action_class`, `ref` are both in scope as local variables) — no
plumbing of a new parameter through any caller is required.

**Call-site survey — no third HEAD reference.** `hooks/guard-git-push.sh` computes `REMOTE`,
`REF`/`MATCH_REF`, `FORCE`, and `ACTION_CLASS` from the scanned `git push` argv (falling back to
`git rev-parse --abbrev-ref HEAD` only when no explicit refspec is given, i.e. a bare `git
push`), then calls `pg_grant_consume "$ACTION_CLASS" "$REMOTE" "$MATCH_REF" "$FORCE"
"guard-git-push.sh"` — it never reads or compares a SHA itself. `scripts/git-push-granted.sh`
is the same shape: it resolves `ACTION_CLASS`/`MATCH_REF` from its own `--ref`/`--tag` flags and
calls `pg_grant_consume` identically — no SHA read there either. Both files are therefore
spectators to the fix, not participants; their presence in the dispatch's `Territory` list is
explained by their test coverage (`test-guard-git-push.sh` exercises both) rather than by any
required code edit in either file.

**Why no "is this the checked-out branch" branch is needed.** `refs/heads/<name>` for whichever
branch is currently checked out is, by git's own definition, the exact object `HEAD` resolves
to. So resolving `refs/heads/${REF}` unconditionally (for `push_branch` only) reproduces today's
`HEAD`-bound value exactly when `REF` happens to be the checked-out branch, and produces the
*correct*, previously-missing value when it is not. The fix is therefore a single substitution
at each of the two call sites — gated on `action_class = push_branch` so `push_tag` (whose `REF`
field, `refs/tags/*`, is not a resolvable ref at all — the tag does not exist pre-push) and the
destructive classes (whose `REF` is always already the checked-out branch or the `HEAD`
sentinel, confirmed by `please-grant.sh`'s destructive-class branch and `guard-destructive-git.sh`'s
call sites at lines 417/714) fall straight through to the existing `git rev-parse HEAD` path,
unchanged:

```
# mint (please-grant.sh), replacing the single HEAD_SHA assignment:
if [ "$ACTION_CLASS" = "push_branch" ]; then
  BOUND_SHA="$(git rev-parse --verify --quiet "refs/heads/${REF}" 2>/dev/null)" || BOUND_SHA=""
  [ -n "$BOUND_SHA" ] || exit_ok    # ref doesn't exist locally -- fail closed, no grant
  HEAD_SHA="$BOUND_SHA"
else
  HEAD_SHA="$(git rev-parse HEAD 2>/dev/null)" || HEAD_SHA=""
  [ -n "$HEAD_SHA" ] || exit_ok
fi

# match (pg_grant_find_match, push-grant-lib.sh), replacing the single head_sha assignment:
if [ "$action_class" = "push_branch" ]; then
  head_sha="$(git rev-parse --verify --quiet "refs/heads/${ref}" 2>/dev/null)" || head_sha=""
else
  head_sha="$(git rev-parse HEAD 2>/dev/null)" || head_sha=""
fi
[ -n "$head_sha" ] || return 1
```

This is illustrative, not a prescribed diff — the implementing plan owns the exact edit, variable
naming, and comment placement.

**`refs/heads/` is the right namespace to resolve against.** `context/patterns/ref-plumbing-landing.md`
documents the `commit-tree` + `update-ref` idiom generically; its worked implementation,
`scripts/review-stack-prepare.sh`, advances refs exclusively under `refs/heads/${out_branch}`
(lines 1011, 1027, 1038, 1395) — the same namespace an ordinary branch and an ordinary `git push
<remote> <branch>` already use. A plumbing-built ref destined for `/please push <remote>
<branch>` therefore already lives at `refs/heads/<branch>` by the time it is typed, consistent
with resolving `refs/heads/${REF}` directly with no second fallback form. (`review-stack-prepare.sh`
itself is deleted by a separate, independent successor — cited here only as evidence for the
namespace convention, not as a dependency.)

**Grant file field name (`HEAD_SHA`) is a naming artifact, not a blocker.** The grant file's
`HEAD_SHA=` field (written by `pg_grant_write`, read by `pg_grant_verify` into `PG_F_HEAD_SHA`)
is referenced by that literal name in `push-grant-lib.sh`, `please-grant.sh`,
`test-please-grant.sh` (field assertions and a fixture literal `HEAD_SHA=${sha}`), and the audit
event's `detail.sha` key (`events-format.md` documents it generically as `sha`, not `HEAD_SHA`).
Nothing outside these already-territory files reads or writes the literal field name. Renaming
it (e.g. to `BOUND_SHA`) is possible but not required by the ruling — see Decisions.

### External Resources

Not applicable — this is a pure shell/git mechanism change internal to one extension; no
external library or API is involved.

## Recommendations

- Apply the two-call-site substitution above, gated on `action_class = push_branch`, in
  `hooks/please-grant.sh` and `pg_grant_find_match()` in `scripts/lib/push-grant-lib.sh`. No
  change to `hooks/guard-git-push.sh` or `scripts/git-push-granted.sh` is needed; their presence
  in the dispatch's territory is for test coverage, not a code edit.
- Keep the on-disk field name `HEAD_SHA` as-is rather than renaming it. A rename ripples into
  `push-grant-lib.sh`'s write/verify functions, every grant-field assertion in
  `test-please-grant.sh`, and the fixture literal at line 333 of that suite, for a label-only
  change with no behavioral benefit; the field still holds *a* commit SHA, just not always
  `HEAD`'s. If the plan phase prefers the clearer name, scope it as a pure rename pass separate
  from the behavior change, so a suite failure can never be attributed to the wrong cause.
- Add a one-line clarifying comment at both call sites (and optionally at the grant-file-format
  header comment in `push-grant-lib.sh`, around line 29) stating that `HEAD_SHA` is "the bound
  ref's own commit for `push_branch`, `HEAD` for every other action class" — this is the one
  piece of the mechanism a future reader cannot re-derive from the field name alone.
- Resolve the ref via `git rev-parse --verify --quiet "refs/heads/${REF}"` with no second
  fallback form (no bare `"$REF"` attempt). This matches the one namespace plumbing-built refs
  are already documented to use (`ref-plumbing-landing.md`, `review-stack-prepare.sh`'s own
  `refs/heads/${out_branch}` sites) and keeps the fail-closed direction: an unresolvable `REF`
  at mint time must refuse to mint, not fall back to some other interpretation.
- `file_scope` does not need extending: `scripts/git-push-granted.sh` needs no change (confirmed
  above), and no document under `context/standards/` or `context/formats/` states the
  HEAD-binding as a textual claim that becomes false under this fix (see Appendix, search 3).

## Decisions

- **Scope the fix to `action_class = push_branch` only, with no separate "is REF the
  checked-out branch" branch.** Resolving `refs/heads/${REF}` unconditionally for `push_branch`
  subsumes the checked-out-branch case for free (it resolves to the same SHA `HEAD` would), so
  a second conditional would be redundant complexity, not a correctness requirement.
- **Do not rename the `HEAD_SHA` grant-file field.** Stated under Recommendations above; recorded
  here as a decision because the plan phase could reasonably choose the opposite and should be
  able to see this was considered and rejected on diff-size grounds, not overlooked.
- **No change to `hooks/guard-git-push.sh` or `scripts/git-push-granted.sh`.** Both are
  call-site spectators (see Findings); their listing in the dispatch's `Territory` is explained
  by test coverage, not a required edit, and the implementing plan should not budget a code
  change there.
- **`push_tag` and the six destructive classes are excluded by construction**, not by an
  explicit exemption list that could drift — the `action_class = push_branch` gate is the only
  place the new behavior can ever activate, and every other class's existing `REF` value (a
  wildcard pattern, or the checked-out branch/`HEAD` sentinel) already makes the old and new
  logic coincide even if the gate were somehow removed.

## Risks & Mitigations

- **Risk**: a future minting path (e.g. the out-of-scope `/slice push <id>` successor) supplies
  a `REF` that is a full ref path (`refs/heads/foo`) rather than a bare branch name, breaking
  the `refs/heads/${REF}` concatenation into `refs/heads/refs/heads/foo`.
  **Mitigation**: not a defect in this record's own fix — `/please push <remote> <branch>` has
  always taken a bare name (confirmed by its grammar's regex captures, which never include a
  leading `refs/`), and this task does not touch or extend the grammar. Flag it for whichever
  successor adds a new mint path, rather than defending against it preemptively here.
- **Risk**: a ref that exists locally but has never been pushed (first push of a brand-new
  plumbing-built branch) still resolves fine via `git rev-parse --verify`, so no new risk there;
  but a `REF` typo that happens to collide with an unrelated, already-existing local branch name
  would now mint a grant bound to that unrelated branch's commit instead of failing loudly.
  **Mitigation**: this is no worse than today's behavior under a typo (today it silently mints
  against `HEAD`, which is equally a wrong-but-successful mint) — the grant still fails at
  consume time once the real push targets a ref whose commit does not match, so the fail-closed
  property is preserved end to end, just at a different step.
- **Risk**: the destructive-guard suite (`test-guard-destructive-git.sh`) is not in this
  dispatch's territory and was not re-read in full; if a future change widened
  `pg_grant_find_match`'s gate condition carelessly, a destructive class could silently pick up
  the new resolution path. **Mitigation**: the recommended gate (`action_class = push_branch`)
  is an allow-list, not a deny-list of destructive names, so no destructive class can reach the
  new branch without itself being named `push_branch` — structurally impossible given
  `PG_ACTION_CLASSES`'s fixed vocabulary.

## Context Extension Recommendations

- **Topic**: push-grant mint/match contract's SHA semantics.
- **Gap**: `context/standards/git-safety.md` (line ~126, "binds the exact action class, remote,
  branch/tag, commit SHA, and force-or-not") and `context/standards/push-consent-relay.md`
  (line ~76, "bound to the commit SHA ... at the moment of minting") both describe the grant's
  SHA binding in terms general enough to remain true after this change, but neither states which
  commit that SHA is for a non-checked-out `push_branch` grant versus every other case. A future
  reader of either document has no way to learn the distinction without reading
  `push-grant-lib.sh` itself.
- **Recommendation**: once this task's fix lands, add one clarifying sentence to
  `git-safety.md`'s existing paragraph (not a new section) stating the `push_branch`/ref-bound
  vs. every-other-class/`HEAD`-bound split. Not required for this task's own acceptance bar; a
  follow-up documentation touch, not a new task.

## Appendix

### Search queries used

1. `grep -n "HEAD_SHA\|rev-parse HEAD\|HEAD.*at consume\|matched against.*HEAD" ...` across
   `hooks/please-grant.sh`, `hooks/guard-git-push.sh`, `scripts/lib/push-grant-lib.sh`,
   `scripts/git-push-granted.sh` — located the exact two call sites.
2. `grep -n "pg_grant_consume\b"` across the whole `agent-system/extensions/core` tree —
   confirmed exactly three callers (`guard-git-push.sh:218`, `guard-destructive-git.sh:417,714`,
   `git-push-granted.sh:98`), none of which read a SHA themselves.
3. `grep -rln "HEAD_SHA\|matched against.*HEAD\|bound to HEAD"` and a targeted per-file grep for
   `HEAD\b` across `context/standards/push-consent-relay.md`, `context/standards/git-safety.md`,
   `context/standards/git-workflow-narrative.md`, `context/formats/events-format.md`,
   `context/contracts/conclusion-stage.md`, `commands/merge.md`, `commands/please.md`,
   `skills/skill-tag/SKILL.md` — none state the HEAD-binding as a textual claim needing
   correction; `file_scope` confirmed not to need extending.
4. Read of `scripts/tests/test-please-grant.sh` and `scripts/tests/test-guard-git-push.sh`
   (fixture helpers, existing assertions) — confirmed every existing test case's `REF` is either
   the checked-out branch (`feature-x`) or an unrelated-remote/wrong-branch negative case; no
   existing case exercises a *valid* grant for a non-checked-out ref, confirming this is new
   territory, not a regression risk against an existing assertion.
5. Read of `context/patterns/ref-plumbing-landing.md` and `scripts/review-stack-prepare.sh`'s
   `update-ref` call sites — confirmed plumbing-built refs live under `refs/heads/`, the same
   namespace the resolution logic targets.

### References

- `specs/decisions/slice-command-one-path-to-review.md` — "Grants" (numbered items 1-3),
  "Successors" row 6, "E7. `/merge` and the push grant".
- `agent-system/extensions/core/hooks/please-grant.sh` (253 lines).
- `agent-system/extensions/core/hooks/guard-git-push.sh` (227 lines).
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` (652 lines).
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` (350 lines).
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` (492 lines).
- `agent-system/extensions/core/scripts/git-push-granted.sh` (115 lines, unchanged).
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md`.
