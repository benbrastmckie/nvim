# Implementation Plan: Task #263

- **Task**: 263 - Consent-gated git push: grant semantics and enforcement mechanism
- **Status**: [IMPLEMENTING]
- **Effort**: 17.5 hours
- **Dependencies**: 139 (completed/archived — its history-rewrite predicate in
  `hooks/guard-destructive-git.sh` must compose with Phase 5's grant check)
- **Research Inputs**: `specs/263_consent_gated_git_push/reports/01_consent-gated-push-design.md`
- **Artifacts**: plans/01_consent-gated-push-enforcement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, shell-script-testing.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`git push` is prohibited today by rule text alone — `rules/pr-prohibition.md` is documentation
with zero mechanical enforcement. This plan builds the missing enforcement and, in the same
change, opens exactly one narrow, target-bound consent gate through it: a single-use, HMAC-signed
grant token that only a literal human prompt submission can mint. The definition of done is that
a bare `git push` from an agent is mechanically blocked, that a push matching a fresh
human-minted grant succeeds and consumes that grant, that every unreadable/malformed/mismatched/
categorically-excluded case blocks, and that the consent is reconstructible from
`specs/events.jsonl` after the fact. The edit target throughout is
`agent-system/extensions/core/` — never `.claude/**`, which is a disposable deploy artifact.

### Research Integration

The research report settles the load-bearing design questions and this plan adopts them:
the mint path must be a `UserPromptSubmit` hook because any model-writable grant file is forgeable
by construction (report Finding 1, Design Question 1); the token binds action class + remote +
branch + sha + force-or-not, is single-use with a 600s expiry, and fails CLOSED on every read or
verify failure (Design Question 1); PR/MR creation and `/merge` stay fully user-only rather than
joining the gate (Design Question 2); both new hooks must be registered in **both**
`root-files/settings.json` (install-once, fresh deploys) and `merge-sources/settings-hooks.json`
(add-only merge, already-initialized repos), because those two files reach different populations
of consumer repos (Finding 2); grant state lives under `specs/`, never `.claude/`, which is
wipe-and-regenerate disposable (Finding 3); the `block-pr-submission.sh` header reference in
`guard-destructive-git.sh` is confirmed dead and gets deleted (Finding 4); `commands/README.md`
has no per-command table, so the absorbed "add a row there" instruction is dropped (Finding 5);
and `user_decision.options[]` entries are flat strings with no `description` field, so each
option string must be self-describing (Finding 6).

Three things this plan settles that the research left open or decided differently, each grounded
in a fact verified during planning:

1. **Where grant consumption happens.** The report's Design Question 4 put consumption in the
   hook. Planning found that `commands/merge.md` STEP 5 runs `git push -u origin HEAD` inline,
   `skills/skill-tag/SKILL.md` runs `git push origin $new_version`, and `cslib/commands/pr.md`
   (a different extension, outside this task's edit target) also pushes. A hook that blocked bare
   pushes unconditionally would break all three user-only flows. So: the hook validates and
   consumes a matching grant and allows that one push; `scripts/git-push-granted.sh` is the
   sanctioned explicit-argument wrapper that does the same validation for agents and for plan
   steps. Both share one library so there is exactly one implementation of mint/verify/consume.
   The hook's documented observation boundary (it only sees the top-level
   `tool_input.command`, never a push inside a wrapper subprocess) means the two paths cannot
   double-consume.
2. **How the pre-existing user-only push flows keep working.** `/merge`, `/tag` and cslib's
   `/pr` are themselves literal human prompt submissions, so the same tamper-resistant mint path
   covers them: the mint hook recognises those prefixes and mints a grant bound to the repo state
   at prompt time. No cslib edit is required, and no user-only flow changes behaviour.
3. **The categorical-exclusion boundary (deliberate divergence, see Decisions).** The report
   recommended excluding *all* pushes to the default branch. `rules/git-workflow.md`'s
   pre-existing "Never Run" bullet is specifically `git push --force` **to** main/master, not
   every push to master; and this repository's own working branch *is* master, so a blanket
   exclusion would make the mechanism unusable in the repo that hosts it. This plan excludes
   every force form on the default branch, bare `--force` anywhere, and every unbounded/bulk/
   deletion refspec — but admits a plain, non-force, git-verified fast-forward push of the
   default branch under a valid grant. This narrowing of the research recommendation is surfaced
   to the user as a non-blocking `user_decision`.

### Prior Plan Reference

No prior plan. This is round 01 for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Net-new mechanical enforcement: `git push` from an agent is blocked unless a valid, fresh,
  target-matching, human-minted grant exists — and the grant is consumed by that one push.
- A grant the model cannot mint (mint path is a `UserPromptSubmit` hook) and cannot forge
  (HMAC-SHA256 over the bound fields, key outside the repo) or overwrite (a tamper guard blocking
  `Write`/`Edit`/`Bash` writes to the grant directory and the key path).
- Fail-CLOSED everywhere: absent, unreadable, malformed, expired, mismatched, already-consumed, or
  unverifiable grant → block. An undeterminable default branch → treat as default branch → block
  force forms.
- Categorical exclusions checked *before* grant lookup, so an excluded push can never be
  authorized by any grant.
- A durable two-event audit trail (`push_grant_issued`, `push_grant_consumed`) via
  `scripts/events-append.sh`, carrying remote/branch/sha/force and the request text.
- The `/please` user-only command, its never-list, the narrowed `pr-prohibition.md` with its
  explicit exception, and a documented-consistent rule surface.
- The dispatch relay leg: a dispatched agent emits a `blocking: true` `user_decision` naming the
  exact push; a YES mints nothing and only tells the human the `/please` line to type.
- Existing behaviour unchanged when no grant mechanism is invoked, and every existing user-only
  push flow (`/merge`, `/tag`, cslib `/pr`) still works.

**Non-Goals**:
- Mechanically blocking `gh pr create` / `glab mr create`. PR/MR creation stays prohibited exactly
  as today (rule text, user-only commands), which is no regression. Adding it would require a
  second consumption surface inside `/merge`'s own PR-creation step; named as a follow-up.
- Folding `/merge` into the `/please` gate. It keeps its own purpose-built interactive flow.
- Confidentiality of the HMAC key. The guarantee is provenance ("this grant was minted by a real
  human prompt submission"), not secrecy — a same-user shell process can read anything the hook
  can read. Stated honestly in the code, the command doc, and the rule.
- Implementing a new `check-extension-docs.sh` rule for settings-registration parity. Rule P's
  `check_settings_merge_source_coverage()` sub-check already covers this (advisory lane).
- Editing any file under `.claude/**`, or any extension other than `core` (with the single
  exception of the redeploy step, which regenerates `.claude/` mechanically).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A write-capable tool other than Bash/Write/Edit (e.g. a future MCP filesystem-write server) bypasses the tamper guard and forges a grant | H | L | Document the guard's exact matcher coverage in its header and in `please.md`; state that wiring any new write-capable tool requires revisiting the matcher list. Not statically closeable — named, not glossed. |
| `UserPromptSubmit` does not carry the literal unexpanded `/please ...` text, or a subagent can trigger it | H | L | Phase 1 verifies both empirically before any hook ships, and records the result in the summary. The whole design rests on this; it is not assumed. |
| Phase 5's grant check disturbs task 139's history-rewrite predicate ordering in `guard-destructive-git.sh` | H | L | Insert strictly after both existing early exits and after the history-rewrite predicate, at the same structural point the snapshot-marker check already occupies. Re-run `test-guard-destructive-git.sh` unchanged as the regression witness. |
| A malformed or half-written grant is read as valid | H | L | Every parse step fails closed: missing field, non-numeric timestamp, bad HMAC, short read → "no grant". Phase 7 tests the malformed case explicitly. |
| `/merge` or `/tag` is typed and then cancelled, leaving a live 600s grant | M | M | The wrapper gains `--revoke`; `merge.md` and `skill-tag/SKILL.md` cancel paths call it. cslib `/pr` cannot be edited from here — residual 600s window stated in Decisions and named as a follow-up. |
| A push guard registered only in `root-files/settings.json` never reaches an already-initialized consumer repo (the live `guard-destructive-git.sh` gap) | H | M | Register both new hooks in both files, each as its own dedicated single-command matcher object (idempotent under object-level merge dedup), and close the pre-existing `guard-destructive-git.sh` gap in the same edit. |
| `skills/skill-orchestrate/SKILL.md` is 17 B under its 20,000 B ceiling; Phase 11 text pushes it over and verify-deploy Gate 20 refuses the redeploy | M | H | Phase 11 puts the relay contract in a context file and adds at most a pointer, then measures `wc -c` before and after and asserts ≤ 20,000 B as a phase gate. |
| Argv parsing misses a `git push` form (unusual flag ordering, quoted refspec) | H | M | Reuse `guard-destructive-git.sh`'s quote/comment-stripped `COMMAND_SCAN` technique verbatim rather than inventing a second scheme; inherit and document its known blind spot symmetrically; Phase 7 enumerates forms (bare, `-u`, `--set-upstream`, `--force`, `-f`, `--force-with-lease`, `--all`, `--tags`, `--mirror`, `--delete`, `:ref`). |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4, 5 | 1, 2 |
| 3 | 6, 7, 8 | 3, 4, 5 |
| 4 | 9 | 4, 6 |
| 5 | 10 | 9 |
| 6 | 11 | 10 |
| 7 | 12 | 11 |
| 8 | 13 | 6, 7, 8, 9, 10, 11, 12 |

Phases within the same wave can execute in parallel. Note the cross-task territory block in this
dispatch: siblings are live on this same working tree this cycle, so re-read every file
immediately before editing it and stage only this task's own hunks.

### Phase 1: Verify the mint-path assumptions and fix the dead header reference [IN PROGRESS]

**Goal**: Empirically confirm, before any hook is written, that `UserPromptSubmit` receives the
literal unexpanded prompt text and that a dispatched subagent can never trigger it — and clear the
confirmed-dead `block-pr-submission.sh` reference out of `guard-destructive-git.sh`.

**Tasks**:
- [x] Write a throwaway logging hook (in the scratchpad, not the source store) that appends
  `$(date +%s) $(jq -r '.prompt // "<none>"')` to a temp log, and register it temporarily in this
  repo's `.claude/settings.json` `UserPromptSubmit` array. *(completed)*
- [ ] Have the user type a literal `/please push origin some-branch` prompt; confirm the log line
  contains that exact unexpanded string (not an expanded command body, not a rewritten prompt).
  *(in progress — handoff: requested via SendMessage to "main"; no reply/log entry yet. Related
  fact confirmed in the meantime: an inter-agent SendMessage delivery to another session ALSO
  fires UserPromptSubmit there, but wrapped in `<agent-message from="...">...</agent-message>`
  tags — verified by sending a message whose body literally started with `/please push origin
  ...`: the logged `.prompt` value started with the wrapper tag, not literally with `/please`. A
  strict prefix-match mint grammar is therefore safe against this relay vector. Still need the
  literal human-typed case before fully closing this item.)*
- [x] Dispatch a throwaway subagent whose instructions literally begin with `/please push origin
  some-branch`; confirm the log records ZERO new invocations for that dispatch. *(completed: zero
  new log lines from the Agent-tool dispatch; the log only grew from the two SendMessage-to-main
  tests)*
- [ ] Record both observations (command, log contents, verdict) verbatim for the implementation
  summary. If either fails, STOP and report — the entire mint design rests on these two facts.
  *(in progress — subagent-isolation observation recorded above; human-typed observation pending)*
- [ ] Remove the temporary hook and its registration; confirm `.claude/settings.json` is back to
  its prior content. *(deviation: deferred — kept live so the human-typed test can still land;
  see progress file objective 4)*
- [x] In `hooks/guard-destructive-git.sh`, delete the line-20 sentence claiming it is "Modeled
  line-for-line on `.claude/hooks/block-pr-submission.sh`" (no such file exists in the source
  store or the deployed tree, and `manifest.json` has no `provides.hooks` entry for it) and
  replace it with a one-line pointer to the exit-2/stderr rationale already documented two lines
  below. *(completed: source-store copy confirmed clean via grep; test-guard-destructive-git.sh
  72/72 pass unmodified)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this phase asserts that `.claude/settings.json` can be temporarily edited and
restored without side effects, and that exactly one line (line 20) carries the dead reference. The
implementer confirms by `grep -n "block-pr-submission" hooks/guard-destructive-git.sh` returning a
single hit before the edit and zero after, and by `git diff` on `.claude/settings.json` being empty
after restoration.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - delete the dead
  `block-pr-submission.sh` lineage sentence, replace with a self-contained pointer

**Verification**:
- The temporary log shows the literal `/please ...` text for the human prompt.
- The temporary log shows no entry for the subagent dispatch.
- `grep -rn "block-pr-submission" agent-system/ .claude/` returns nothing.
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` still passes
  (comment-only edit, but run it as the witness).

---

### Phase 2: Grant token library — format, HMAC, expiry, matching, consumption [COMPLETED]

**Goal**: One library implementing every grant primitive, sourced by all three consumers (mint
hook, push guard, wrapper, destructive guard), so there is exactly one implementation of the
security-critical logic.

**Tasks**:
- [x] Create `scripts/lib/push-grant-lib.sh` with path constants: grant directory
  `specs/.push-grant/`, one grant file per mint named `grant-<epoch>-<rand>.kv`, and key path
  `${XDG_STATE_HOME:-$HOME/.local/state}/claude-agent-system/push-grant.key` (outside the repo, so
  a `.claude/` wipe or a fresh clone cannot destroy or expose it).
- [x] Implement `pg_key_ensure()`: create the key directory `0700` and the key `0600` from
  `od -An -N32 -tx1 /dev/urandom` on first use; refuse to proceed (return non-zero) if the key
  exists with looser-than-0600 permissions.
- [x] Implement `pg_grant_write()`: line-oriented KEY=VALUE (the `.git-snapshot-marker` precedent,
  extended) with required fields `VERSION=1`, `TIMESTAMP`, `ACTION_CLASS`
  (`push_branch`|`push_tag`), `REMOTE`, `REF`, `FORCE` (`0`|`lease`), `HEAD_SHA`, `REQUEST_TEXT`
  (base64, so free text cannot inject newlines), `MINT_SOURCE`
  (`please`|`merge`|`tag`|`pr`), and `HMAC` last. HMAC-SHA256 is computed with
  `openssl dgst -sha256 -hmac "$(cat key)"` over every preceding line verbatim; write via a
  `mktemp` + `mv` so no partial file is ever observable.
- [x] Implement `pg_grant_verify()`: recompute the HMAC and compare; return non-zero on any
  missing field, non-numeric `TIMESTAMP`, unknown `ACTION_CLASS`/`FORCE` value, `VERSION` other
  than `1`, unreadable file, or absent key. Every failure path returns "no grant", never "grant
  present".
- [x] Implement `pg_grant_fresh()` with `PG_EXPIRY_WINDOW=600` and the same `0 <= (NOW - TS) <=
  WINDOW` shape `guard-destructive-git.sh` uses for its 120s marker (a negative age — a
  future-dated grant — fails).
- [x] Implement `pg_default_branch()`: `git symbolic-ref --short refs/remotes/<remote>/HEAD`, else
  `git config --get init.defaultBranch`, else the literal set `{master, main}`. **If it cannot be
  determined, return the sentinel that makes the caller treat the target AS the default branch**
  (fail closed).
- [x] Implement `pg_categorical_excluded(action, remote, ref, force, flags)` returning the
  exclusion reason string, or empty. Excluded: bare `--force`/`-f` on any ref; any force form
  (including `--force-with-lease`) on the default branch; `--mirror`; `--all`; `--tags`;
  `--prune`; a deletion refspec (`--delete`, or a refspec whose source side is empty, `:ref`);
  any command with more than one refspec. These are checked BEFORE any grant lookup.
- [x] Implement `pg_grant_match(action, remote, ref, force)`: exact string equality on `REMOTE`
  and `REF`, exact equality on `ACTION_CLASS` and `FORCE`, and `HEAD_SHA` equal to
  `git rev-parse HEAD` at consumption time (so any commit made since the mint invalidates it).
  For `ACTION_CLASS=push_tag`, `REF` is the literal pattern `refs/tags/*` and matches any single
  tag ref (the tag does not exist yet when `/tag` is typed — documented in the header).
- [x] Implement `pg_grant_consume()`: pick the newest verifying, fresh, matching grant; `rm -f` it
  **before** returning success (delete-on-use, the `guard-destructive-git.sh` marker precedent);
  emit the `push_grant_consumed` audit event via `scripts/events-append.sh`
  (`--category success`, `--detail-json` with remote/ref/sha/force/mint_source/consumer).
- [x] Implement `pg_grant_revoke()`: delete every grant file, used by the wrapper's `--revoke`.
- [x] Implement `pg_dir_ensure()`: create `specs/.push-grant/` `0700` and write
  `specs/.push-grant/.gitignore` containing `*` on creation, so the directory is self-ignoring in
  every consumer repo with no `.gitignore` edit anywhere (the top-level repo `.gitignore` is NOT
  deployed from the source store — `root-files/.gitignore` lands at `.claude/.gitignore` and only
  covers paths inside it, verified during planning).
- [x] Header comment documenting: fail-closed direction; the divergence from
  `git-commit-scoped.sh`'s fail-OPEN mutex behaviour (a push guard must refuse, never proceed
  unserialized); and that the guarantee is grant PROVENANCE, not key confidentiality.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - new; all grant primitives

**Verification**:
- `bash -n` clean; `shellcheck` clean at the level the neighbouring `scripts/lib/*.sh` files pass.
- Ad-hoc driver in the scratchpad: mint a grant, verify it, flip one byte of the payload, confirm
  verify fails; truncate the file mid-line, confirm verify fails; set `TIMESTAMP` 700s in the past,
  confirm `pg_grant_fresh` fails; set it 60s in the future, confirm it fails.
- `pg_categorical_excluded` returns non-empty for each excluded form enumerated above.
- `specs/.push-grant/.gitignore` exists after `pg_dir_ensure` and `git status --porcelain
  specs/.push-grant` is empty.

---

### Phase 3: `/please` mint hook (UserPromptSubmit) [COMPLETED]

**Goal**: The one tamper-resistant mint path: a `UserPromptSubmit` hook that mints a grant only
from a literal human prompt, and mints nothing at all when the request is ambiguous.

**Tasks**:
- [x] Create `hooks/please-grant.sh`, reading stdin JSON and extracting `.prompt` exactly as
  `hooks/wezterm-task-number.sh` does (`jq -r '.prompt // ""'`).
- [x] Recognise four prefixes on the literal prompt, and nothing else: `/please`, `/merge`,
  `/tag`, `/pr`. Any other prompt exits 0 with no output and no grant.
- [x] `/please` grammar (the absorbed matching rule): mint only when the free text yields exactly
  one `(action_class, remote, ref, force)` tuple. Accept `push <remote> <branch>`,
  `push <branch> to <remote>`, `push tag <name> to <remote>`, with an optional
  `--force-with-lease`. On zero or multiple candidate tuples, mint NOTHING and write a one-line
  refusal to stdout (which Claude Code injects as prompt context) naming the accepted grammar.
- [x] `/merge`, `/tag`, `/pr` mint from repo state at prompt time: `REMOTE` = the current branch's
  configured upstream remote, else `origin`; `REF` = the current branch (or `refs/tags/*` for
  `/tag`); `FORCE=0`; `HEAD_SHA` = `git rev-parse HEAD`; `MINT_SOURCE` set accordingly. This is
  what keeps the three pre-existing user-only push flows working unchanged — including cslib's
  `/pr`, which needs no cslib edit.
- [x] Refuse to mint (and say so in stdout) when `pg_categorical_excluded` already rejects the
  requested tuple, so an excluded request never even produces a token.
- [x] Emit the `push_grant_issued` audit event (`--category milestone`, `--detail-json` with
  remote/ref/sha/force/mint_source and the request text).
- [x] On a successful mint, write one stdout line stating exactly what was granted (remote, ref,
  short sha, force-or-not, expiry seconds) and that the sanctioned path is
  `bash .claude/scripts/git-push-granted.sh`.
- [x] Revoke any pre-existing grants before minting a new one, so at most one grant is ever live.
- [x] Never exit non-zero: a `UserPromptSubmit` hook that fails must not block the user's prompt.
  All failures are reported in stdout and result in NO grant.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/hooks/please-grant.sh` - new; the mint hook

**Verification**:
- Piping `{"prompt":"/please push origin feature-x"}` produces exactly one grant file whose fields
  match, and one `push_grant_issued` line in `specs/events.jsonl`.
- Piping `{"prompt":"/please do the push thing"}` produces NO grant and a grammar refusal on
  stdout.
- Piping `{"prompt":"/please force push origin master"}` produces NO grant (categorically
  excluded).
- Piping `{"prompt":"what is git push"}` produces no grant and no output.
- Piping `{"prompt":"/merge"}` produces a grant bound to the current branch, `origin`, HEAD,
  `FORCE=0`, `MINT_SOURCE=merge`.
- A second mint deletes the first grant (at most one live).
- Hook exit status is 0 in every case above, including the refusals.

---

### Phase 4: Push guard hook + sanctioned wrapper [COMPLETED]

**Goal**: The enforcement pair. A `PreToolUse` hook that blocks every un-granted `git push` (and
every write to the grant/key paths), plus the explicit-argument wrapper that is the sanctioned
path agents are told to use.

**Tasks**:
- [x] Create `hooks/guard-git-push.sh`, registered on matcher `Bash|Write|Edit`, with a header
  documenting its two responsibilities and why they share one file (both derive their path
  constants from `push-grant-lib.sh`).
- [x] Responsibility A (`Bash`): build `COMMAND_SCAN` with the same quote/comment-stripping
  technique `guard-destructive-git.sh` uses (do not invent a second scheme; inherit and document
  its known blind spot symmetrically). Detect any `git push` invocation in any form. Extract
  remote, refspec and force flags from argv; when the command omits them, resolve them the way
  bare `git push` does (the current branch's configured upstream, else `origin` + current branch).
- [x] Order of checks, strictly: (1) is this a `git push`? (2) `pg_categorical_excluded` → `exit 2`
  with the exclusion reason, never reaching grant lookup; (3) `pg_grant_consume` → on success
  `exit 0` (allow, grant consumed, audit written); (4) otherwise `exit 2` with a stderr message
  naming the reason (no grant / expired / wrong target / HEAD moved / bad HMAC / malformed) and
  the sanctioned path (`/please push <remote> <branch>`, then
  `bash .claude/scripts/git-push-granted.sh`).
- [x] Responsibility B (`Write`/`Edit`, and `Bash` commands whose argv or redirection targets the
  grant dir or the key path): `exit 2` unconditionally — no grant, no snapshot, no override exempts
  a write to the grant store. Document explicitly that this closes the model's *write* channel for
  the matchers listed and that wiring any new write-capable tool requires revisiting the matcher
  list.
- [x] Block via `exit 2` + stderr, never `permissionDecision: deny` — the latter is
  documented-buggy for allow-listed `Bash(git:*)` commands (GH #4669, #13214, #18312), as
  `guard-destructive-git.sh`'s own header records.
- [x] Create `scripts/git-push-granted.sh`: `--remote <name> --ref <branch-or-tag>
  [--force-with-lease] [--tag] [--session <sid>] [--revoke] [--help]`. Shape it on
  `git-commit-scoped.sh`: `SCRIPT_DIR` resolution, `. lib/common.sh`,
  `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`, `. deploy-root-guard.sh`.
- [x] Wrapper semantics: refuse ambiguous or missing arguments rather than inferring them (the
  V2/V3/V4 precedent of refusing ambiguous input); run `pg_categorical_excluded` then
  `pg_grant_consume`; on success run the push with the exact flags the grant authorizes and no
  others; **fail CLOSED** on any lock/verify/read failure, with an explicit code comment stating
  this is a deliberate divergence from `git-commit-scoped.sh`'s fail-OPEN mutex behaviour and why.
- [x] `--revoke` deletes every live grant and exits 0 (used by `/merge` and `/tag` cancel paths).

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-git-push.sh` - new; push gating + grant/key tamper
  blocking
- `agent-system/extensions/core/scripts/git-push-granted.sh` - new; sanctioned push wrapper

**Verification**:
- `bash -n` clean on both; `--help` prints usage and exits non-zero per the repo convention.
- Hook, driven with `{"tool_input":{"command":"git push"}}` and no grant: `exit 2`, stderr names
  `/please` and the wrapper.
- Hook with a matching grant present: `exit 0`, grant file gone afterwards.
- Hook with `{"tool_input":{"command":"git push --force origin master"}}` and a valid grant:
  `exit 2` with the exclusion reason (exclusion precedes grant lookup).
- Hook with `{"tool_name":"Write","tool_input":{"file_path":"specs/.push-grant/grant-1.kv"}}`:
  `exit 2`.
- Wrapper with no grant: non-zero, no push attempted (verify with a bare local fixture remote).
- Wrapper with a valid grant against a fixture remote: push lands, grant consumed, one
  `push_grant_consumed` event appended.

---

### Phase 5: Grant check in `guard-destructive-git.sh` [COMPLETED]

**Goal**: Extend the existing destructive-git guard so a matched destructive action can be
authorized by a matching grant, consumed on use — with zero change to its no-grant behaviour and
zero change to the ordering of its existing gates.

**Tasks**:
- [x] Re-read `hooks/guard-destructive-git.sh` in full immediately before editing (siblings are
  live on this tree this cycle).
- [x] Insert the grant check at exactly one place: after the clean-tree early exit
  (`git status --porcelain` empty → `exit 0`), after the concurrency-gated history-rewrite
  predicate (task 139's, which keeps its own `exit 2` and its `GUARD_ALLOW_HISTORY_REWRITE=1`
  operator override), and at the same structural point the snapshot-marker freshness check already
  occupies — i.e. only once the hook has already decided the command would otherwise be blocked.
- [x] Extend the grant's `ACTION_CLASS` vocabulary in `push-grant-lib.sh` with the destructive
  classes the absorbed text names (`reset_hard`, `clean_fd`, `checkout_discard`,
  `restore_discard`, `stash_drop`), and have the mint hook accept them from `/please` with the
  same one-tuple-or-nothing grammar.
- [x] Preserve, untouched: the clean-tree early exit, the `COMMAND_SCAN` quote/comment stripping,
  and — critically — the over-staging detectors' **immunity**. A grant must NEVER exempt
  `git add -A`/`git add .`/a directory-or-glob pathspec/`git commit -am`, for the same asymmetry
  reason the snapshot marker cannot: a snapshot makes data loss recoverable, but over-staging is a
  scope problem no authorization makes acceptable. Assert this with a test, not a comment alone.
- [x] Record the composition with task 139's predicate in a header comment naming both predicates
  and their order.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts the grant check is a single insertion at one structural
point with no reordering of existing gates. The implementer confirms by `git diff --stat` on the
hook showing only additions plus the Phase 1 comment change, and by
`test-guard-destructive-git.sh` passing entirely unmodified before the Phase 8 additions are
written.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - add the grant check after the
  existing gates; header note on predicate composition
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` - extend `ACTION_CLASS` vocabulary
- `agent-system/extensions/core/hooks/please-grant.sh` - accept the destructive action classes

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` passes with the
  suite still unmodified (pure-addition witness).
- With a grant for `reset_hard` present, `git reset --hard` on a dirty fixture is allowed once and
  the grant is gone; a second attempt is blocked.
- With that same grant present, `git add -A` on a dirty fixture is still blocked (over-staging
  immunity).
- With no grant, every existing blocked form is still blocked with the same exit code and message.

---

### Phase 6: Manifest and settings registration (both templates) [COMPLETED]

**Goal**: Deploy and wire the new hooks and script so neither is silently inert — the exact failure
mode `check-extension-docs.sh` Rule H exists to catch for rules, and Rule P's merge-source
sub-check for hooks.

**Tasks**:
- [x] `manifest.json`: add `guard-git-push.sh` and `please-grant.sh` to `provides.hooks`; add
  `git-push-granted.sh` and `lib/push-grant-lib.sh` to `provides.scripts` following the existing
  entry convention for `lib/` paths.
- [x] `root-files/settings.json` (install-once; fresh deploys): add a `PreToolUse` entry with
  matcher `Bash|Write|Edit` running `bash .claude/hooks/guard-git-push.sh` as its own dedicated
  single-command matcher object, and a `UserPromptSubmit` entry running
  `bash .claude/hooks/please-grant.sh`, likewise its own object.
- [x] `merge-sources/settings-hooks.json` (add-only merge; already-initialized repos): add the same
  two entries, each as its own dedicated single-command matcher object — never appended into an
  existing shared `*` matcher's `hooks` array, so re-merges stay idempotent under object-level
  dedup.
- [x] Same edit, in-scope adjacent fix: add the missing `PreToolUse` / `Bash` entry for
  `guard-destructive-git.sh` to `merge-sources/settings-hooks.json`. Verified during planning:
  that hook is registered only in `root-files/settings.json`, so an already-initialized consumer
  repo can never receive it. Rule P's condition 3 suppresses the advisory in *this* repo only
  because the entry is already live here.
- [x] Do NOT wrap either new guard's command in `2>/dev/null || echo '{}'`. That idiom belongs to
  advisory hooks; a guard must be able to exit 2.
- [x] `jq empty` both settings files and the manifest after editing.

**Timing**: 0.75 hours

**Depends on**: 3, 4, 5

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts exactly four `provides` additions and five settings
entries (two new hooks × two files, plus the one adjacent `guard-destructive-git.sh` merge-source
fix). The implementer confirms by diffing the two settings files and re-reading `provides.hooks` /
`provides.scripts` with `jq` afterwards.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - `provides.hooks`, `provides.scripts` additions
- `agent-system/extensions/core/root-files/settings.json` - two new PreToolUse/UserPromptSubmit
  matcher objects
- `agent-system/extensions/core/merge-sources/settings-hooks.json` - the same two, plus the
  missing `guard-destructive-git.sh` Bash matcher

**Verification**:
- `jq empty` clean on all three files.
- `jq -r '.hooks.PreToolUse[].hooks[].command' ...` on both settings files lists
  `guard-git-push.sh`; `.hooks.UserPromptSubmit` lists `please-grant.sh`.
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` emits no new failure and no
  new advisory about either new hook.

---

### Phase 7: Tests — push guard, wrapper, exclusions, fail-closed [COMPLETED]

**Goal**: `scripts/tests/test-guard-git-push.sh`, covering the dispatch's verification items 1-5
and 7 as executable assertions, in the fixture-driven style of `test-guard-destructive-git.sh`.

**Tasks**:
- [x] Follow `context/standards/shell-script-testing.md` and the existing suite's shape:
  `pass()/fail()/info()`, integer counters, `mktemp -d` workdir with `trap EXIT` cleanup, exit 0 on
  all-pass / 1 on any-fail, hook driven as a real subprocess with a synthetic
  `{"tool_input":{"command":...}}` payload, asserting exit codes. The hook is never instrumented
  for testability.
- [x] A fixture self-check as the very first case (the existing suite's precedent): assert the
  fixture repo has a bare local remote and a non-default working branch, so no later BLOCK case
  can pass vacuously.
- [x] Cases: bare `git push` with no grant → blocked, stderr names the sanctioned path (item 1, 2);
  `git push` forms enumerated (`-u`, `--set-upstream`, explicit remote+branch, `HEAD`,
  `--force-with-lease`) each classified correctly.
- [x] Invalidation cases, one per predicate (item 3): expired (`TIMESTAMP` 700s old), wrong
  branch, wrong remote, HEAD moved since mint, force-vs-non-force mismatch, already-consumed.
- [x] Categorical-exclusion cases (item 4), each with an otherwise-valid grant present: bare
  `--force`, `--force-with-lease` on the default branch, `--mirror`, `--all`, `--tags`,
  `--delete`, `:ref` deletion, two refspecs.
- [x] Valid-grant success case (item 5): wrapper pushes to the fixture remote, remote ref moves,
  grant file gone, one `push_grant_consumed` event appended.
- [x] Fail-safe cases (item 7): grant file truncated mid-line; HMAC byte flipped; required field
  removed; `TIMESTAMP` non-numeric; key file absent; key file mode `0644`. Each must BLOCK.
- [x] Single-use case: re-write the consumed grant's exact bytes back to disk and confirm the
  second push is still refused (HEAD/consumption independence, per the research's
  "test it directly, not via the sha side door").
- [x] Tamper cases: `Write` and `Edit` payloads targeting the grant dir and the key path → blocked;
  a `Bash` payload redirecting into either → blocked.
- [x] Unchanged-default case (item 8): with no grant and no mechanism invoked, a non-push git
  command (`git status`, `git commit`) is untouched by the new hook.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` - new suite

**Verification**:
- Suite exits 0 with every case reporting PASS and the fixture self-check first.
- Deliberately breaking one guard branch (temporarily) makes the corresponding case FAIL — confirm
  the suite is not vacuous, then revert.
- The suite is auto-discovered by `scripts/tests/run-all.sh` (glob-based; no registration needed —
  confirm by running `run-all.sh` and seeing the suite named in its output).

---

### Phase 8: Tests — mint hook, forgery, and destructive-guard grant path [COMPLETED]

**Goal**: `scripts/tests/test-please-grant.sh` plus additive cases in
`test-guard-destructive-git.sh`, covering the mint path's integrity and the Phase 5 grant check.

**Tasks**:
- [x] `test-please-grant.sh`, same fixture style: `/please` grammar accepted forms each mint
  exactly one grant with the right fields; ambiguous/partial requests mint NOTHING and print the
  grammar; a categorically-excluded request mints nothing; a non-`/please` prompt mints nothing;
  the hook always exits 0.
- [x] Forged-grant case: write a syntactically perfect grant file by hand (no valid HMAC) and
  confirm the guard refuses it — the absorbed text's "forged grant file rejected" requirement,
  asserted rather than argued.
- [x] Mint-source cases: `/merge`, `/tag`, `/pr` each mint a grant bound to the fixture's current
  branch / `refs/tags/*`, `FORCE=0`, correct `MINT_SOURCE`.
- [x] At-most-one-live-grant case: two mints leave exactly one grant file.
- [x] Audit case: a mint appends exactly one `push_grant_issued` line whose `detail` carries
  remote, ref, sha and force (item 6: the record reconstructs WHAT was authorized, not merely that
  someone said yes).
- [x] Additive cases in `test-guard-destructive-git.sh`, appended without modifying or weakening
  any existing case: destructive grant allows one matched action and is consumed; a second attempt
  is blocked; no-grant behaviour byte-identical to today; **a destructive grant does not exempt any
  over-staging form**; the history-rewrite predicate still fires with a grant present for a
  different action class.
- [x] Record in the implementation summary that no existing assertion was changed (none asserts the
  old blanket prohibition — verified in research: matches for "push" in `scripts/tests/` are
  incidental), so nothing needed deliberate updating.

**Timing**: 1.5 hours

**Depends on**: 3, 5

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` - new suite
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - additive cases only

**Verification**:
- Both suites exit 0.
- `git diff` on `test-guard-destructive-git.sh` shows additions only — no existing case altered or
  deleted.
- The forged-grant case fails loudly if the HMAC check is temporarily disabled (non-vacuity check,
  then revert).

---

### Phase 9: `/please` command, never-list, and command-table rows [COMPLETED]

**Goal**: The user-only `/please` command the whole mechanism is fronted by, its hard-coded
never-list, and the documentation rows that make it discoverable.

**Tasks**:
- [x] Create `commands/please.md`, modelled on `commands/merge.md`'s structure and `commands/tag.md`'s
  "User Only: YES" warning-block convention: `description: ... (user-only)`, `argument-hint`,
  numbered `STEP` sections with "EXECUTE NOW" framing. `allowed-tools` includes `Bash(git:*)` and
  `AskUserQuestion`; it does NOT include `gh:*`/`glab:*` (push-only, per the PR-creation
  non-goal).
- [x] Flow: parse the literal request; show the exact command and its effect (for a push: local vs
  remote SHAs, commit count); confirm via `AskUserQuestion` before any irreversible step; prefer
  `--force-with-lease=<ref>:<observed remote sha>` over bare `--force`; execute only the literal
  request; push through `scripts/git-push-granted.sh`, never a bare `git push`.
- [x] State the caveat in the command itself: the grant proves the user typed `/please`, not that
  the command the agent then runs is the one meant — so the confirmation step is mandatory for
  anything irreversible.
- [x] Never-list, hard-coded as a refusal before anything else happens, refused regardless of
  wording: credential/secret access; deletion outside the repo; `.git` internals; disabling,
  editing or removing hooks or hook settings. State explicitly that this list is enforced by the
  command's own logic, not by a hook — the hooks exist to stop agents, and `/please` is
  user-invoked.
- [x] State that `/please` is never available to an agent: it is in no skill-to-agent mapping, and
  its mint path fires only on the human's own literal prompt, never on an expanded command body.
- [x] Add `please.md` to `manifest.json` `provides.commands`.
- [x] Mention `/please` in `agent-system/extensions/core/README.md`'s command table —
  `check-extension-docs.sh`'s `check_readme_vs_manifest()` **fails** if a command in
  `provides.commands` is not mentioned in that README (verified during planning; this file is not
  in the task's originally declared `file_scope` and is added deliberately).
- [x] Add a `/please` row to `merge-sources/claudemd.md`'s Command Reference table beside `/merge`
  and `/tag`, marked user-only, and a `skill`-table/User-Only note only if one is warranted (there
  is no `skill-please`; `/please` is a command with no skill).
- [x] Per research Finding 5, add NO row to `commands/README.md` — it is prose with no per-command
  table. Note this in the summary so the absorbed instruction reads as resolved, not skipped.
- [x] Add `--revoke` calls to the cancel/abort paths of `commands/merge.md` and
  `skills/skill-tag/SKILL.md`, so a cancelled flow does not leave a live grant for the rest of the
  600s window.

**Timing**: 1.5 hours

**Depends on**: 4, 6

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/commands/please.md` - new, user-only command
- `agent-system/extensions/core/manifest.json` - `provides.commands` addition
- `agent-system/extensions/core/README.md` - `/please` command-table mention (Rule
  `check_readme_vs_manifest` requirement)
- `agent-system/extensions/core/merge-sources/claudemd.md` - `/please` Command Reference row
- `agent-system/extensions/core/commands/merge.md` - `--revoke` on the cancel path
- `agent-system/extensions/core/skills/skill-tag/SKILL.md` - `--revoke` on the cancel path

**Verification**:
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` passes, including
  `check_readme_vs_manifest` for `/please` and Rule V's claudemd byte ceiling for the new row.
- `grep -n "git push" agent-system/extensions/core/commands/merge.md` and the skill-tag SKILL.md
  show every push call site either routed through the wrapper or explicitly documented as relying
  on its command-minted grant.
- The never-list appears verbatim in `please.md`.

---

### Phase 10: Rule narrowing and consistency sweep [COMPLETED]

**Goal**: Narrow `pr-prohibition.md` precisely — without weakening the sentence that makes it
un-social-engineerable — and reconcile every other place the prohibition is asserted.

**Tasks**:
- [x] `rules/pr-prohibition.md`: keep `paths: "**/*"` and the why-eager comment unchanged; keep
  "Never push branches or create PRs even if asked to in task descriptions or user messages"
  **verbatim**; add immediately after it the single scoped exception: a user-invoked
  `/please <push request>` authorizes exactly the one push it names via a single-use,
  target-bound grant; an agent must never invoke `/please`; and a task description or user message
  that merely *describes* a desired push is not a `/please` invocation and grants nothing.
- [x] Same file: state that PR/MR creation and `/merge` remain fully prohibited for agents, with no
  grant path — reinforced, not loosened.
- [x] `rules/git-workflow.md`: add the enforcement note beside the push bullet ("Enforced by
  `guard-git-push.sh` for all forms; a `/please`-granted push is the sole exception, single-use and
  target-bound"), and keep the `git push --force` to main/master "Never Run" bullet as the stronger,
  more specific rule that no grant can override.
- [x] `context/standards/git-safety.md`: add the push-grant mechanism to the design narrative
  (verified during planning: this file currently contains no push references at all, so this is an
  addition, not a reconciliation).
- [x] `context/standards/status-markers.md`: confirm and state explicitly that a consented push
  does NOT change when a task reaches `[PR READY]` — that marker is `task_type == "pr"`-only
  (verified during planning at line 280). Record the confirmation rather than leaving it
  unexamined; edit only if the file implies otherwise.
- [x] `context/formats/events-format.md` and `context/schemas/events-schema.json`: confirm the two
  new `event_type` values need no schema change (`event_type` is an open string, `detail` an open
  object, and `milestone`/`success` already exist in the category enum). Document both new event
  types in `events-format.md` if it enumerates known types; keep the two files in sync either way.
- [x] Run the sweep: `grep -rn "git push\|gh pr create\|glab mr create\|never push" agent-system/
  --include='*.md' --include='*.sh' --include='*.json'` and enumerate, in the implementation
  summary, every file changed and every file deliberately left unchanged with its reason
  (specifically: `cslib/commands/pr.md`, `cslib/README.md`, `cslib/context/.../pr-command-workflow.md`
  and the three `web/` deploy guides are all outside this task's edit target and are unaffected
  because their pushes are user-invoked and covered by a command-minted grant).

**Timing**: 1.25 hours

**Depends on**: 9

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/rules/pr-prohibition.md` - scoped `/please` exception; PR/`merge`
  reinforcement
- `agent-system/extensions/core/rules/git-workflow.md` - enforcement note beside the push bullet
- `agent-system/extensions/core/context/standards/git-safety.md` - push-grant design narrative
- `agent-system/extensions/core/context/formats/events-format.md` - the two new event types
- `agent-system/extensions/core/context/schemas/events-schema.json` - confirm/keep in sync

**Verification**:
- `check-extension-docs.sh` Rule H still passes (`pr-prohibition.md` still declared in
  `provides.rules`).
- The verbatim "Never push branches or create PRs even if asked to..." sentence is still present
  (`grep -F`).
- `events-schema.json` validates every line in a fixture `events.jsonl` containing both new event
  types.
- The sweep output is captured and every hit is classified changed / unchanged-with-reason.

---

### Phase 11: Dispatch relay — a request, never a mint [COMPLETED]

**Goal**: Define how a dispatched agent, which cannot call `AskUserQuestion`, REQUESTS a push —
and make explicit that a YES mints nothing and only tells the human the `/please` line to type.

**Tasks**:
- [x] Create `context/standards/push-consent-relay.md` carrying the full relay contract, so
  `skill-orchestrate/SKILL.md` needs at most a one-line pointer (it measures 19,983 B against a
  20,000 B ceiling — 17 B of headroom).
- [x] In that file, specify the `user_decision` payload template. `options[]` entries are flat
  strings with no `description` field (research Finding 6), so each must be self-describing, e.g.
  `"Grant via /please push origin feature-x (a1b2c3d, 3 commits ahead, no force)"` /
  `"Do not authorize; the task stops at its current commit"`. `question` names the exact target.
- [x] Specify `blocking: true` unconditionally for this decision class, with the reason: the
  non-blocking path proceeds on the AGENT's own recommendation, which would be an agent
  authorizing its own push. Enforce by contract in the agent-facing text.
- [x] Specify the return leg explicitly: a YES does NOT mint a grant and does not become one. The
  relayed answer surfaces the exact `/please` line for the human to type; the human's own prompt
  submission is the only mint path. This closes the `.decisions.json` replay hazard by
  construction — nothing replayable is ever recorded, since the guard never reads
  `.decisions.json` at all.
- [x] Specify that `.decisions.json` still records the exchange for audit parity (a normal
  `{question, answer, cycle, timestamp}` entry), that `orchestrate-build-dispatch.sh`'s
  `## Prior Decisions` renderer is deliberately NOT special-cased, and why that is safe: the
  recorded text is informational ("the user was told to run `/please ...`"), never an
  authorization, because authorization lives only in a single-use sha-bound token.
- [x] Specify the NO case and the run-ends-before-answer case: no grant exists in either, so the
  guard's default-deny alone guarantees no push, with no special-casing in the relay path.
- [x] Specify that a granted push never carries across a cycle: 600s expiry plus `HEAD_SHA`
  binding plus delete-on-use, consistent with Phase 2's one-push grant scope.
- [x] Add the pointer in `context/standards/user-decision-contract.md` (this case is already inside
  its enumerated qualifying shape 2 — "an external cost or risk the user must accept... an action
  outside this repository") and a one-line cross-reference in
  `context/formats/return-metadata-file.md`'s `user_decision` subsection.
- [x] Add at most a pointer line to `skills/skill-orchestrate/SKILL.md`, and offset it byte-for-byte *(deviation: altered — omitted; only 145 B headroom remained against the 20,000 B ceiling, concurrent siblings may also be touching this file this cycle, and the plan explicitly permits omission when the context file + user-decision-contract.md pointer are sufficient)*
  (or omit it entirely if the byte budget cannot absorb it — the context file plus the
  user-decision-contract pointer are sufficient). Measure `wc -c` before and after; the file MUST
  stay ≤ 20,000 B or verify-deploy Gate 20 refuses the redeploy.
- [x] Note in `docs/architecture/handoff-schema.md` that `user_decision` for this class is mirrored
  onto the handoff as for any other, and that no new handoff field is introduced.

**Timing**: 1.5 hours

**Depends on**: 10

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts `skill-orchestrate/SKILL.md` can absorb a pointer within
17 B, or none is added. The implementer confirms with `wc -c` before and after and treats
`> 20000` as a phase failure, not a warning.

**Files to modify**:
- `agent-system/extensions/core/context/standards/push-consent-relay.md` - new; the full relay
  contract
- `agent-system/extensions/core/context/standards/user-decision-contract.md` - pointer to the new
  contract
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - one-line cross-reference
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - byte-neutral pointer, or no
  change
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - mirroring note
- `agent-system/extensions/core/index-entries.json` - index entry for the new context file

**Verification**:
- `wc -c skills/skill-orchestrate/SKILL.md` ≤ 20000.
- `check-extension-docs.sh` Rules L/R/T pass: the new context file is indexed, not orphaned, and
  its `line_count` is accurate.
- `bash scripts/tests/test-orchestrate-cycle-postflight.sh` and
  `test-orchestrate-build-dispatch.sh` still pass unchanged (this phase adds no script behaviour).

---

### Phase 12: Relay tests, including the two-cycle no-inheritance test [NOT STARTED]

**Goal**: Prove the relay behaves as specified and that cycle N+1 inherits no standing permission.

**Tasks**:
- [ ] Add additive cases to `scripts/tests/test-orchestrate-cycle-postflight.sh`: a handoff/return-meta
  carrying a push-class `user_decision` with `blocking: true` sets `verdict="ask_user"`; postflight
  relays without resolving and writes no `.decisions.json` entry itself.
- [ ] Add additive cases to `scripts/tests/test-orchestrate-build-dispatch.sh`: the two-cycle test.
  Cycle N records a `{question, answer}` pair about a push in `.decisions.json`; cycle N+1's
  dispatch file is built and asserted to contain NO live authorization — concretely, that no grant
  file exists after the cycle-N push, and that the `## Prior Decisions` text present in the cycle
  N+1 dispatch cannot satisfy `pg_grant_consume` (assert directly: run the guard against a `git
  push` in that state and require `exit 2`).
- [ ] Add the NO-answer and run-ends-before-answer cases: no grant file exists, guard blocks, task
  state clean (no status change, no partial artifact).
- [ ] Assert `blocking: true` is what the relay path receives for this class; a `blocking: false`
  push-class decision is a contract violation the test names explicitly.

**Timing**: 1.25 hours

**Depends on**: 11

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - additive
  relay cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - additive
  two-cycle case

**Verification**:
- Both suites exit 0; `git diff` shows additions only.
- The two-cycle case fails loudly if the grant's delete-on-use is temporarily disabled
  (non-vacuity check, then revert).

---

### Phase 13: Redeploy, live-fire confirmation, and full gate set [NOT STARTED]

**Goal**: Confirm the hooks actually fire from the deployed copies (not just from the source store)
and that the whole repository gate set is green.

**Tasks**:
- [ ] Redeploy (`bash .claude/scripts/deploy-headless.sh`, or the picker's Reload All) and confirm
  `.claude/hooks/guard-git-push.sh`, `.claude/hooks/please-grant.sh`,
  `.claude/scripts/git-push-granted.sh` and `.claude/scripts/lib/push-grant-lib.sh` all exist and
  match their sources byte-for-byte.
- [ ] Confirm `.claude/settings.json` carries both new registrations after the redeploy.
- [ ] Confirm the generated `.claude/CLAUDE.md` shows the new `/please` Command Reference row.
- [ ] Live-fire, from the deployed copies: run a bare `git push --dry-run` against a scratch
  fixture remote with no grant and demonstrate the block (capture the stderr verbatim for the
  summary — the dispatch requires demonstrating the block, not asserting it). Then mint a grant by
  typing a literal `/please` prompt, run the wrapper, and demonstrate the push succeeding and the
  grant being consumed.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` — full suite green; no existing
  test weakened or deleted.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` (including Rule H and
  Rule P), plus the other `check-*.sh` lints the repo runs, all green.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh` green, specifically Gate 20's
  byte ceiling for `skill-orchestrate/SKILL.md`.
- [ ] Write the implementation summary recording: the Phase 1 empirical results; the categorical
  exclusion boundary as implemented; every swept file changed vs. deliberately unchanged; the
  statement that no existing test assertion was changed; and the residual risks (matcher coverage,
  cslib `/pr` cancel window, key readability).

**Timing**: 1 hour

**Depends on**: 6, 7, 8, 9, 10, 11, 12

**Verification Tier**: full

**Files to modify**:
- none planned (deploy outputs under `.claude/**` are generated, never hand-authored)

**Verification**:
- `run-all.sh`, `check-extension-docs.sh`, `verify-deploy.sh` all exit 0.
- Deployed-vs-source content drift checks (Rules F/I/O) report nothing new.
- The captured stderr from the live-fire block is in the summary.

## Testing & Validation

- [ ] Item 1: a bare `git push` from an agent is blocked by the hook, stderr naming the sanctioned
  path — demonstrated live from the deployed copy (Phase 13), not merely asserted.
- [ ] Item 2: a push with NO grant present is blocked (Phase 7).
- [ ] Item 3: each invalidation condition is separately tested — expired, wrong branch, wrong
  remote, HEAD moved, force mismatch, already consumed, bad HMAC (Phase 7).
- [ ] Item 4: each categorically excluded push is blocked EVEN WITH an otherwise-valid grant
  (Phase 7).
- [ ] Item 5: a push with a valid in-scope grant succeeds through the sanctioned wrapper (Phase 7,
  re-demonstrated live in Phase 13).
- [ ] Item 6: the audit record is written and carries remote, ref, sha, force and request text for
  both issuance and consumption (Phases 7, 8).
- [ ] Item 7: fail-safe direction is BLOCK — malformed, truncated, unreadable, absent-key and
  loose-key-mode cases all tested explicitly (Phase 7).
- [ ] Item 8: with no grant mechanism invoked, existing agent behaviour is unchanged (Phase 7
  non-push commands; Phase 8 destructive-guard no-grant parity).
- [ ] Item 9: `run-all.sh` green with no existing test weakened or deleted; no test asserted the
  old blanket prohibition, so none required deliberate updating — stated in the summary (Phases 8,
  13).
- [ ] Relay items: well-formed `blocking: true` `user_decision` with no push; `verdict="ask_user"`;
  NO and run-ends cases clean; two-cycle non-inheritance (Phase 12).
- [ ] `check-extension-docs.sh` Rule H and Rule P green; `verify-deploy.sh` Gate 20 green.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` (new)
- `agent-system/extensions/core/hooks/please-grant.sh` (new)
- `agent-system/extensions/core/hooks/guard-git-push.sh` (new)
- `agent-system/extensions/core/scripts/git-push-granted.sh` (new)
- `agent-system/extensions/core/commands/please.md` (new)
- `agent-system/extensions/core/context/standards/push-consent-relay.md` (new)
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` (new)
- Edits: `hooks/guard-destructive-git.sh`, `manifest.json`, `root-files/settings.json`,
  `merge-sources/settings-hooks.json`, `merge-sources/claudemd.md`, `README.md`,
  `commands/merge.md`, `skills/skill-tag/SKILL.md`, `rules/pr-prohibition.md`,
  `rules/git-workflow.md`, `context/standards/git-safety.md`,
  `context/standards/user-decision-contract.md`, `context/formats/return-metadata-file.md`,
  `context/formats/events-format.md`, `context/schemas/events-schema.json`,
  `docs/architecture/handoff-schema.md`, `index-entries.json`,
  `skills/skill-orchestrate/SKILL.md` (byte-neutral or unchanged), and three existing test suites
  (additive only)
- `specs/263_consent_gated_git_push/summaries/01_...-summary.md` at completion

## Decisions

1. **Consumption happens in two places sharing one library** — the hook (for a bare `git push`
   whose target matches a live grant) and the wrapper (the sanctioned explicit-argument path).
   Divergence from research Design Question 4's hook-only design, forced by the discovery that
   `/merge`, `/tag` and cslib `/pr` all run inline pushes that an unconditional block would break.
2. **The mint hook recognises `/please`, `/merge`, `/tag` and `/pr`** — all four are literal human
   prompt submissions, so the same tamper-resistant path covers the pre-existing user-only flows
   with zero cslib edits and no behaviour change.
3. **Categorical exclusions, narrowed from the research recommendation**: bare `--force` anywhere;
   any force form (including `--force-with-lease`) on the default branch; `--mirror`, `--all`,
   `--tags`, `--prune`, deletion refspecs, and multi-refspec pushes. A plain non-force push of the
   default branch IS grant-authorizable. Rationale: `rules/git-workflow.md`'s pre-existing "Never
   Run" is specifically force-to-master, and this repository's own working branch is master, so a
   blanket master exclusion would both exceed the rule being narrowed and make the mechanism
   unusable in the repo that hosts it. Git's own server-side non-fast-forward refusal covers the
   remaining case. **Surfaced to the user as a non-blocking `user_decision`** — if the user
   prefers the research's stricter blanket exclusion, Phase 2's `pg_categorical_excluded` is the
   single place to change.
4. **Grant store under `specs/.push-grant/`, self-ignoring** via a generated `.gitignore`
   containing `*`, because the top-level repo `.gitignore` is NOT deployed from the source store
   (`root-files/.gitignore` lands at `.claude/.gitignore`) — so no `.gitignore` edit is needed in
   any consumer repo.
5. **HMAC key outside the repo** at `${XDG_STATE_HOME:-$HOME/.local/state}/claude-agent-system/
   push-grant.key`, `0600`, because `.claude/` is wipe-and-regenerate disposable and an in-repo key
   would need its own ignore rule in every consumer repo.
6. **PR/MR creation stays rule-text-prohibited, not hook-blocked** (non-goal above), so `/merge`'s
   own `gh pr create` needs no second consumption surface. Named as a follow-up.
7. **`/please`'s never-list is command-level, not hook-enforced** — the hooks stop agents;
   `/please` is user-invoked. Stated in `please.md` so no future reader assumes otherwise.
8. **The pre-existing `guard-destructive-git.sh` merge-source registration gap is fixed here**
   rather than deferred, since Phase 6 edits that exact file and the fix is one object.

## Rollback/Contingency

Every phase is additive or comment-level except Phases 5, 9 and 10, which edit existing files.
Because a green sub-step is committed as it happens, rollback is per-commit `git revert` of the
task's own commits — not a working-tree discard. If a whole-tree rollback is genuinely required
(the only case that needs a snapshot), take it via the rollback rung in
`context/contracts/recovery.md`, including its out-of-scope override flag; never emit a bare
default-mode `git-snapshot.sh` as a routine precaution. For a durable checkpoint before Phase 5's
edit to the live `guard-destructive-git.sh`, use `--no-revert`, which is durable and does not
revert the working tree.

Highest-risk single point: Phase 6's registration. A wrong registration yields a silently inert
hook (no error anywhere), which is why Phase 13 confirms the hooks fire from the **deployed**
copies rather than trusting the source-store test runs. If the new push guard ever needs to be
disabled in an emergency, removing its two settings entries and redeploying restores exactly
today's behaviour (rule text only) with no other change — the grant library, wrapper and command
are inert without the registration.
