# Research Report: Task #361

**Task**: 361 - Reclassify bare `git stash` as destructive on a shared working tree
**Started**: 2026-10-07T00:00:00Z
**Completed**: 2026-10-07T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (rules/git-workflow.md, hooks/guard-destructive-git.sh,
  scripts/tests/test-guard-destructive-git.sh, scripts/lib/push-grant-lib.sh,
  hooks/please-grant.sh, scripts/git-snapshot.sh, context/standards/git-workflow-narrative.md)
**Artifacts**: - specs/361_reclassify_bare_git_stash_as_destructive/reports/01_reclassify-stash-destructive.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's carried evidence is confirmed, not merely assumed: `rules/git-workflow.md` line
  142 does carry `**Not blocked** ... git stash (push), git stash pop / git stash apply ...`, and
  `hooks/guard-destructive-git.sh` line 427 does guard only `stash drop`/`stash clear` under
  `DESTRUCTIVE_ACTION_CLASS="stash_drop"` — the guard protects an existing stash from deletion,
  never the tree from being reverted by the act of stashing it. Source-store and deployed copies
  of the guard are byte-identical (md5 `15f8ba3275f18ea83fb071fa41a0101e` both sides) — this is a
  genuine coverage gap, not deploy staleness.
- The fix is two-layered and ordered: amend the rule's rationale first (Item 1), then add a guard
  detector that implements the corrected rule (Item 2) under a **new** `DESTRUCTIVE_ACTION_CLASS`
  (Item 3) — the existing snapshot-marker/grant-consume escape hatch already generalizes to any
  class with no code change beyond registering the name (Item 5), **except** that
  `hooks/please-grant.sh`'s own mint-path grammar is a separate, hand-maintained `case` statement
  that does not auto-generalize — see Recommendations for why this is a second wiring point the
  dispatch's Item 5 wording does not explicitly name but the "no second escape hatch" intent
  implies must also be touched.
- Recommended new class name: `stash_revert` (parallels the effect-naming style of
  `checkout_discard`/`restore_discard`, pairs visually with `stash_drop`, and avoids the
  ambiguity of a `stash_push`-style name reading as "push to a remote").
- Item 7 verdict (recommended): **keep `git stash push -- <pathspec>` permitted.** A
  pathspec-scoped stash has the same bounded, path-owned risk profile as the already-permitted
  `git restore --staged <path>` and non-forced checkout/switch — it is not the whole-tree
  blast-radius hazard the incident exhibited.
- Item 8 verdict (recommended): **keep `git stash pop` / `git stash apply` permitted.** The data
  loss in the incident happened at the `git stash push`/bare-`git stash` step (the tree revert);
  `pop`/`apply` is the recovery step, and git's own 3-way-merge conflict behavior never silently
  discards content on a failed pop/apply — it refuses and leaves conflict markers or leaves the
  stash in place. The rule should say this explicitly rather than leave it implicit.
- A related, out-of-scope-but-worth-flagging finding: `scripts/git-snapshot.sh`'s own *default
  mode* runs `git stash push -u` internally as its own snapshot mechanism. This is
  subprocess-invisible to the guard (same invisibility argument as `git-commit-scoped.sh`'s
  internal git calls), so the new detector will not block it — consistent with the existing
  design pattern. But it means the sanctioned snapshot helper carries a narrower version of the
  *same* concurrency hazard this task is correcting (a later recovery pop could itself conflict
  under concurrent writers). This is not this task's territory (no second escape hatch, no
  snapshot-mechanism redesign), but the plan/implementation phase should record it as a known
  residual risk rather than silently absorb it.

## Context & Scope

Researched: the exact current text and line numbers of the defective rule and the
under-scoped guard; the guard's existing per-detector idiom (segment extraction via grep,
per-segment token scanning) so a new detector can follow it rather than invent a new style; the
grant/consume (`push-grant-lib.sh`, `please-grant.sh`) and snapshot-marker
(`scripts/git-snapshot.sh`) escape-hatch machinery the new class must plug into; the existing
test suite's structure and its current (now-to-be-flipped) baseline assertions for bare
`git stash`/`git stash pop`; and the eight scope items the dispatch requires a recorded verdict
on. No web research was needed — this is a closed, local-codebase correctness question about an
internal safety hook and its governing rule.

## Findings

### Codebase Patterns

**Rule text (`rules/git-workflow.md`, source-store line numbers re-derived and confirmed)**:
- Lines 113-120: the "Forbidden on a dirty tree" list (`git reset --hard`, `git checkout --
  <path>`, `git restore <path>` without `--staged`, `git clean -fd`, `git stash drop`/`clear`,
  forced checkout/switch).
- Lines 142-144: the defective allow-list —
  `**Not blocked** (do not discard uncommitted changes): git stash (push), git stash pop /
  git stash apply, git restore --staged <path>, and non-forced git checkout / git switch between
  branches.` The parenthetical is true for a solo tree and false under concurrent writers, exactly
  as the dispatch states.
- Lines 99-103 and 156-158 describe a **second**, unrelated predicate in the same hook
  (concurrency-gated history-rewrite for `--amend`/HEAD-moving `reset`) — orthogonal to this task,
  confirmed not to need any change here.

**Guard script (`hooks/guard-destructive-git.sh`, 513 lines, confirmed byte-identical to the
deployed `.claude/hooks/guard-destructive-git.sh` via `diff` and matching md5sums)**:
- Lines 372-447 are the `MATCHED`/`REASON`/`DESTRUCTIVE_ACTION_CLASS` detector chain, each
  detector following the same shape: extract same-command segments via
  `grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+<subcommand>[^;&|]*'` against `$COMMAND_SCAN`
  (quote/comment-stripped once, up front), then test each segment, setting
  `MATCHED=1`/`REASON=...`/`DESTRUCTIVE_ACTION_CLASS=...` and `break`ing on first match. The
  `clean -f -d` detector (lines 406-424, flag-presence via two independent `grep -qE` tests
  combined with `HAS_F`/`HAS_D`) and the forced-checkout/switch detector (lines 433-447,
  `grep -qE` for `-f`/`--force` inside each segment) are the two the dispatch names as the idiom
  to imitate for item 2 — both are simple per-segment flag/subcommand tests, not full tokenizers,
  which is the right complexity level for the new stash detector.
- The existing `stash drop`/`stash clear` detector (lines 427-431) uses a single `grep -qE`
  against the whole `$COMMAND_SCAN` (not even per-segment) since it only needs to recognize two
  fixed subcommand words — `git[[:space:]]+stash[[:space:]]+(drop|clear)\b`. A new detector for
  bare/`push` stash needs segment-level extraction (like the directory/glob `git add` detector,
  lines 309-347) because it must positively confirm the subcommand is `push` or absent, and
  separately confirm whether a `--` pathspec separator is present, which a single `grep -qE`
  cannot express cleanly.
- Lines 453-479: the **grant check** is generic over any `DESTRUCTIVE_ACTION_CLASS` string — it
  reads whatever value the detector chain set and calls
  `pg_grant_consume "$DESTRUCTIVE_ACTION_CLASS" "local" "$GRANT_REF" "0" "guard-destructive-git.sh"`.
  No hook-side code change is needed here beyond the new detector setting the class string; this
  confirms Item 5's instruction is satisfiable with zero new mechanism in this file.
- Lines 481-513: the snapshot-marker exemption is likewise unconditional on `DESTRUCTIVE_ACTION_CLASS`
  value — any `MATCHED=1` destructive command is exempted by a fresh marker, regardless of class.
  No change needed here either.

**Grant-class registry (`scripts/lib/push-grant-lib.sh`)**:
- Line 73: `PG_ACTION_CLASSES="push_branch push_tag reset_hard clean_fd checkout_discard
  restore_discard stash_drop"` — the single place `pg_grant_mint`/`pg_grant_verify` validate
  `ACTION_CLASS` membership against (line 364: `case " ${PG_ACTION_CLASSES} " in *" ${ac} "*) ;;
  *) return 1 ;; esac`). **The new class name must be appended to this string**, or
  `pg_grant_consume` will fail-closed (treat any minted grant for the new class as invalid) even
  if something else manages to mint one — this is the one additive line change needed in this
  file.
- Comment lines 38-42 already anticipate exactly this kind of Phase-5-style extension and name
  this file as "the single place that list is defined."

**Mint-path grammar (`hooks/please-grant.sh`) — a second wiring point the dispatch's Item 5 does
not name explicitly but its "reuse, don't invent a second escape hatch" intent implies**:
- Lines 136-168: destructive-class grants are minted from a **hand-written `case "$TEXT"` /
  regex** block, one arm per class (`reset_hard`, `clean_fd`, `stash_drop`,
  `checkout_discard` via a checkout/switch-force regex, `restore_discard` via a restore regex).
  This grammar is **not** driven by `PG_ACTION_CLASSES` — it is a second, independent, hand-
  maintained enumeration of the same five classes. Appending the new class to
  `PG_ACTION_CLASSES` alone does **not** make it mintable via `/please`; a human operator could
  still reach the new class's exemption only through the snapshot-marker route
  (`git-snapshot.sh`), never through `/please "stash the tree"`.
- Line 175's user-facing error text (`"Accepted destructive forms: ..."`) is also a hand-written
  list that would silently omit the new class unless updated.
- This is a judgment call for the plan, not dictated by the dispatch, but worth flagging loudly:
  leaving `please-grant.sh` untouched is not itself "a second escape hatch" (it would just mean
  the grant route is narrower than the snapshot-marker route for this one class), but it does
  leave the escape hatch **partially** wired rather than fully reused. Recommend extending
  `please-grant.sh`'s case block and its error-text line in the same phase, for parity with the
  other five classes, rather than leaving an asymmetric gap discovered only when a human tries
  `/please "git stash"` and gets "could not parse."

**Test suite (`scripts/tests/test-guard-destructive-git.sh`, 652 lines)**:
- Lines 194-196 currently assert the **opposite** of the corrected rule and will need to flip:
  ```
  assert_allowed_dirty "baseline: git stash (bare)"                  "git stash"
  assert_allowed_dirty "baseline: git stash pop"                     "git stash pop"
  ```
  Per the Item 8 verdict above, `git stash pop` (line 195) stays `assert_allowed_dirty` unchanged;
  only line 194 (`git stash` bare) needs to become `assert_blocked_dirty`. This existing line is
  itself the cleanest "fails pre-change, passes post-change" fixture Item 6 asks for — flipping
  its expectation demonstrates the RED-before/GREEN-after contrast directly, with no new fixture
  machinery needed, though additional NEW cases should be added alongside it (see Recommendations)
  for `git stash push`, `-u`/`--include-untracked`, and the pathspec-scoped exemption.
- Lines 557-642 are the additive "grant-check cases" section for the push-grant machinery,
  showing the exact pattern (`mint_destructive_grant_in`, `grant_count_in`, paired
  "allows-once-and-consumed" + "second-attempt-blocked" assertions) a parallel pair of cases for
  the new class should follow — e.g. mint a `stash_revert` grant, confirm `git stash` is allowed
  once and the grant file count drops to 0, then confirm a second bare `git stash` on freshly
  dirtied state is blocked again.
- The suite resolves `HOOK` via one relative path (line 30) that works identically in
  source-store and deployed layout — no new resolution logic needed for this task.

**Snapshot helper (`scripts/git-snapshot.sh`)** — read for the Item 5 escape-hatch-reuse context:
- Default mode's own internal mechanism is `git stash push -u` (confirmed at header comment
  lines 54-59 and 82-86) — i.e., the sanctioned snapshot primitive the guard already defers to
  *is itself* a bare, untracked-inclusive stash push. This is invisible to the hook (subprocess
  call, never `tool_input.command`), so it needs and gets no exemption carve-out — consistent
  with the existing `git-commit-scoped.sh`/`--branch`-mode `git add -A` precedent documented in
  the guard's own header comment (lines 76-82).

### External Resources

None consulted — this is a closed internal-tooling question with no external library or API
surface; all relevant material lives in the four files above plus the narrative doc.

## Decisions

- **Item 1 (rule amendment)**: confirmed necessary and scoped to `rules/git-workflow.md` lines
  113-144. Move bare `git stash` / `git stash push` (including `-u`) from the "Not blocked" list
  into the "Forbidden on a dirty tree" list, and rewrite the parenthetical rationale to state the
  concurrent-writer hazard (a stash reverts the tree; a later pop can be refused by a sibling's
  intervening write, leaving the only copy inside a stash entry) rather than the solo-tree "do not
  discard" framing. The full incident narrative (the measured evidence in the dispatch
  description) belongs in `context/standards/git-workflow-narrative.md`, mirroring how the
  existing "No History Rewrites While Another Writer Is Live" section already splits a one-
  sentence eager-core rule from a full incident writeup in the narrative file (narrative lines
  80-117) — the rule stays terse, the narrative carries the story.
- **Item 3 (class name)**: recommend `stash_revert`. Rejected alternative: `stash_push` (reads as
  "push to a remote," which this class has nothing to do with, and the hazard is the *effect*
  — reverting the tree — not the specific subcommand spelling, since bare `git stash` with no
  subcommand is an equally-matched implicit-push form).
- **Item 7 (pathspec-scoped stash)**: recommend **keep permitted**. A `git stash push --
  <pathspec>` only reverts the named path(s), the same bounded-blast-radius shape as the
  already-permitted `git restore --staged <path>` and non-forced checkout/switch. Blocking it
  would deny agents the one stash form that is both safe and useful (isolating one file's edits
  without touching siblings' files), directly contradicting the territory-contract model (H7)
  this codebase already uses for concurrent dispatch.
- **Item 8 (`stash pop`/`apply`)**: recommend **keep permitted**, with the rule text made
  explicit about why: the incident's data-loss moment was the stash *push*, not the pop. A pop
  or apply that would overwrite local changes is refused by git itself and leaves the stash
  intact (or leaves conflict markers, never a silent discard) — this is the same "safe failure"
  shape already relied on elsewhere in the rule (e.g. non-forced checkout/switch between
  branches staying permitted for the identical reason).

## Recommendations

1. **Amend the rule first** (Item 1) exactly as decided above, before touching the guard, so the
   guard change implements a stated contract rather than diverging from one undocumented.
2. **New guard detector**, placed in the existing `MATCHED=0` chain (anywhere among the existing
   detectors at lines 372-447; order among mutually-exclusive detectors does not matter), modeled
   on the directory/glob `git add` detector's per-segment-then-per-token shape (lines 309-347)
   rather than the single `grep -qE` shape used for `stash drop`/`clear`, because it must
   distinguish three things per segment: (a) the subcommand is `push` or absent (bare) — not
   `pop`/`apply`/`list`/`show`/`branch`/`drop`/`clear`; (b) whether a `--` pathspec separator with
   at least one trailing token is present (Item 7 exemption — allow); (c) otherwise block, setting
   `DESTRUCTIVE_ACTION_CLASS="stash_revert"` and a `REASON` string that will feed the refusal
   message. The `-u`/`--include-untracked` forms need no special casing beyond making sure the
   segment-extraction regex's trailing `[^;&|]*` already captures them (it does, as written for
   every existing detector) — the risk being guarded against is purely "did this segment's first
   non-flag token come after `git stash` and is it `push` or nothing," not the presence of `-u`
   itself.
3. **Register the class**: append `stash_revert` to `PG_ACTION_CLASSES` in
   `scripts/lib/push-grant-lib.sh` line 73 — the one mechanical change needed for the existing
   generic grant-check block in the guard to accept it.
4. **Extend `please-grant.sh`'s mint grammar** (lines 144-175) with a new arm recognizing a
   stash-grant request text (e.g. `"git stash"`/`"stash"`/`"git stash push"`/`"stash push"`),
   setting `ACTION_CLASS="stash_revert"` and the same `REMOTE="local"`/`REF`/`FORCE="0"` sentinel
   pattern the other four destructive arms already use (lines 161-167), and add it to the
   user-facing accepted-forms text at line 175. This was not explicitly named by the dispatch but
   is needed for the grant route to be as usable for this class as for the other five — otherwise
   the only way to pre-authorize this exemption remains the snapshot-marker route.
5. **Refusal message** (append to the block at lines 505-513, mirroring its existing style):
   name all three alternatives verbatim —
   `git show HEAD:<path>` (read the committed version), `git diff HEAD -- <path>` (read the
   uncommitted diff without touching the tree), and copying the file(s) of interest to a
   scratchpad location (e.g. the task's own `specs/{NNN}_{SLUG}/` directory or `/tmp`) before
   proceeding — plus the existing `git-snapshot.sh`/`/please` pointers already used by the
   sibling blocks.
6. **Test suite additions** (`scripts/tests/test-guard-destructive-git.sh`):
   - Flip line 194 (`git stash` bare) from `assert_allowed_dirty` to `assert_blocked_dirty`; leave
     line 195 (`git stash pop`) unchanged.
   - Add new `assert_blocked_dirty` cases: `git stash push`, `git stash -u`, `git stash
     --include-untracked`, `git stash push -u`.
   - Add new `assert_allowed_dirty` cases (Item 7 exemption): `git stash push -- foo.txt`,
     `git stash push -u -- foo.txt bar.txt`.
   - Add an `assert_allowed_dirty` case for `git stash apply` alongside the existing `pop` case,
     for parity (currently untested as its own case).
   - Add a grant-check pair for `stash_revert` mirroring lines 583-593/595-603 (mint, consume
     once, confirm blocked again on a second dirtying).
7. **Narrative doc**: add the incident writeup (the dispatch's measured-evidence section,
   re-verified rather than copied verbatim) to `context/standards/git-workflow-narrative.md`,
   following the existing "No History Rewrites While Another Writer Is Live — Incident and Full
   Detail" section's shape (narrative lines 80-117) as the template.

## Risks & Mitigations

- **Risk**: a detector that is too permissive on the pathspec-scoped exemption (e.g. matching any
  trailing `--` even when preceded by `-u` with no actual path tokens) could re-open the
  whole-tree hazard under a crafted command. **Mitigation**: require at least one non-flag token
  after the `--` separator (mirroring the `git add` glob/dir detector's `read -ra` token-walk
  idiom), not merely the presence of `--` itself.
- **Risk**: forgetting the `please-grant.sh` grammar update (point 4 above) leaves the grant route
  silently unusable for this class while the snapshot-marker route works — an asymmetry a future
  agent could mistake for "the grant system doesn't support this," wasting time. **Mitigation**:
  call this out explicitly in the plan as a required sub-step, not an optional nice-to-have.
- **Risk**: `git-snapshot.sh`'s own internal `git stash push -u` (default mode) carries a narrower
  version of the same concurrency hazard this task is fixing for direct agent use — a recovery
  pop from that internal stash could itself be refused under a sibling's intervening write.
  **Mitigation**: explicitly out of scope per the dispatch's non-goals (no second escape hatch,
  no snapshot-mechanism redesign); record as a known residual risk in the narrative doc rather
  than silently absorbing it, for a future task to pick up if it recurs.
- **Risk**: the rule's new rationale text could be written in a way that still invites a
  "`git stash` is fine, it's reversible" misreading if the concurrency hazard isn't stated
  plainly. **Mitigation**: the amended parenthetical should name the specific failure mode (a
  later `git stash pop` can be refused by a sibling's write, stranding the changes inside a stash
  entry) rather than a vaguer "can be risky under concurrency."

## Context Extension Recommendations

- **Topic**: Destructive-guard `DESTRUCTIVE_ACTION_CLASS` registry is split across two
  independently-maintained enumerations (`PG_ACTION_CLASSES` in `push-grant-lib.sh` and the
  `case` grammar in `please-grant.sh`).
- **Gap**: Neither file's header comment cross-references the other as "the second place this
  list must also be updated" — `push-grant-lib.sh`'s own header (lines 38-42) claims to be "the
  single place that list is defined," which is true for *validation* but not for *mintability*
  via `/please`.
- **Recommendation**: when this task's plan touches `please-grant.sh`, also add a one-line
  cross-reference comment in both files pointing at each other, so a future sixth class addition
  does not rediscover this asymmetry the hard way.

## Appendix

- Search queries / commands used: `grep -n "stash\|Not blocked\|destructive"
  rules/git-workflow.md`; `diff`/`md5sum` of source-store vs. deployed
  `guard-destructive-git.sh`; full reads of `guard-destructive-git.sh`,
  `test-guard-destructive-git.sh`, `git-workflow-narrative.md`; targeted `grep -n` passes over
  `push-grant-lib.sh` and `please-grant.sh` for `ACTION_CLASS`/`PG_ACTION_CLASSES`/grant
  mint-and-consume function signatures; header read of `scripts/git-snapshot.sh` for its internal
  stash mechanism.
- References: `agent-system/extensions/core/rules/git-workflow.md`,
  `agent-system/extensions/core/hooks/guard-destructive-git.sh`,
  `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`,
  `agent-system/extensions/core/scripts/lib/push-grant-lib.sh`,
  `agent-system/extensions/core/hooks/please-grant.sh`,
  `agent-system/extensions/core/scripts/git-snapshot.sh`,
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md`.
