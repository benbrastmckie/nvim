# Research Report: Task #139

**Task**: 139 - Forbid concurrent-writer history rewrites (rules/contracts) + concurrency-gated hook predicate (absorbed former task 140)
**Started**: 2026-09-28
**Completed**: 2026-09-28
**Effort**: research
**Dependencies**: None (siblings 162, 163, 244, 43, 199, 207, 167 dispatched concurrently this cycle; none overlap this task's file footprint — verified below)
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/{rules,context,agents,hooks,scripts})
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All four documentation/contract WORK items (a)-(c) target files that exist and match the
  dispatch's line-number citations almost exactly. **Item (d) does not**: `agents/general-
  implementation-hard-agent.md` does not exist anywhere in the source store (only
  `cslib-implementation-hard-agent.md` and `lean-implementation-hard-agent.md` exist, for
  domains that declare a hard-mode agent). The quoted "Recovery Ladder... while uncommitted
  changes exist" text actually lives in `context/contracts/recovery.md` (lines 19-26, "Green
  Means Fix Forward" section, loaded into hard-mode dispatch prompts via contract injection, not
  a per-domain agent file). This is the real edit target for item (d); planning must retarget it.
- The hook's current architecture (`hooks/guard-destructive-git.sh`) exits 0 immediately on a
  clean working tree (line 76-78), BEFORE any of the seven destructive-pattern detectors run.
  Since `--amend`/non-hard `reset` are non-destructive to the working tree and routinely run on
  a clean tree (immediately after a commit — exactly the incident scenario), **the new
  concurrency predicate must be spliced in ahead of that clean-tree early-exit**, not appended
  after it as a new detector in the existing MATCHED chain. This is the single most
  implementation-critical finding for the planner.
- Three concurrency-signal candidates were evaluated (task-lock liveness count, session-registry
  liveness, HEAD-movement tracking). **Recommended: reuse `task-lock.sh session-list`'s already-
  shipped two-signal (pid + heartbeat) liveness computation** (`session_liveness()`, feeding
  `cmd_session_list`'s `live`/`task_numbers` fields) rather than re-deriving lock-scanning logic
  in the hook. This registry is documented as having **zero readers today** ("the in-flight
  session registry is produced but not yet consumed" — `context/standards/orchestrator-runtime-
  files.md` line 49); this task would be its first consumer.
- Verified: `--amend` and `mixed` both still match zero times across `agent-system/extensions/
  core/{rules,context,agents}/` — confirms the dispatch's premise is current, not stale.
- No sibling task this cycle (162, 163, 244, 43, 199, 207, 167) declares file_scope overlapping
  any file this task touches or reads for context.

## Context & Scope

This is the research phase for a task that absorbed a second, formerly-separate task (140).
The combined scope is:
1. **Rules/contract layer** (original task 139 WORK a-d): add `--amend`/non-hard `reset` to
   `rules/git-workflow.md`'s "Never Run" list; add a sibling section on committed-history
   rewrites under concurrent writers; add a MUST-NOT bullet + `git-commit-scoped.sh` mandate to
   `general-implementation-agent.md`; correct the mis-scoped "while uncommitted changes exist"
   bullet.
2. **Hook/enforcement layer** (absorbed former task 140): give `guard-destructive-git.sh` a
   second, concurrency-gated predicate; update its header; update `context/standards/git-
   safety.md`; update `rules/git-workflow.md`'s "enforced by" framing; verify with concrete
   cases.

Both layers are in scope for this task's implementation phase; this report covers research for
both.

## Findings

### Codebase Patterns

#### 1. The hook (`hooks/guard-destructive-git.sh`, 303 lines) — verified against dispatch claims

- Header (lines 3-5) states the single-hazard premise exactly as quoted in the dispatch.
- Clean-tree exemption is real and is the FIRST live check after command extraction (lines
  76-78): `if [ -z "$(git status --porcelain 2>/dev/null)" ]; then exit 0; fi`. Everything below
  it — the argv-anchoring `COMMAND_SCAN` construction, the over-staging detectors, and the
  seven destructive-pattern detectors — is unreachable on a clean tree.
- `grep -c amend` and `grep -c mixed` against this file: 0 each. Confirmed current.
- The file already has a well-developed, reusable "scan a directory tree for the freshest
  fresh/live marker and act on it" idiom at lines 271-293 (the `.git-snapshot-marker` freshness
  scan: `find specs -maxdepth 3 -name ".git-snapshot-marker" ...` + timestamp comparison). A new
  concurrency-liveness scan can follow this exact shape rather than inventing a new one.
- `COMMAND_SCAN` (lines 80-123) is the argv-anchoring, quote-and-comment-stripped scan string
  every detector reads. The new `--amend`/`reset` detector MUST read `$COMMAND_SCAN`, not raw
  `$COMMAND`, to inherit the existing false-positive closure for a commit message containing the
  literal text "--amend" (design constraint explicitly named in the dispatch, and already
  solved generically by the existing machinery — no new work needed there beyond reusing it).
- Existing detector shape to imitate for `reset` (non-`--hard`): the file already detects
  `git reset ... --hard` via a single-line grep (line 201-204). A "non-hard reset" detector is
  the SAME segment-extraction idiom (`grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+reset[^;&|]*'`
  per-segment, as `restore`/`clean`/`checkout|switch` already do at lines 213-225, 228-244,
  253-265) with the hard-flag check inverted.

#### 2. Test suite (`scripts/tests/test-guard-destructive-git.sh`)

- Built entirely on a **dirty**-tree fixture (`make_dirty_repo`); its own header explains why: on
  a clean tree or outside a git repo the hook exits 0 vacuously and every BLOCK-expecting case
  would pass for the wrong reason. **The new concurrency predicate's test cases are the inverse
  case**: they must run against a repo that is deliberately made **clean** (to prove the new
  predicate fires independently of the dirty-tree gate), which the existing fixture helper does
  not build — the harness needs a new `make_clean_repo`-shaped fixture alongside the existing
  dirty one, not merely new cases layered on the current fixture.
- Drives the hook as a real subprocess via synthetic PreToolUse JSON on stdin and asserts on exit
  code (2 = blocked, 0 = allowed); this pattern extends cleanly to the new predicate (fixture:
  create/don't-create a foreign live task lock, then assert exit code on a bare `--amend`).

#### 3. `rules/git-workflow.md` (source store) — matches dispatch citations closely

- Line 77 "Never Run" list: 6 bullets, none covering `--amend`/non-hard `reset` (confirmed).
- Line 93-97: "**Enforced by `guard-destructive-git.sh`**" paragraph — the "enforced by" framing
  the absorbed task's item (d) says must stay in agreement with the hook's actual predicates.
  This paragraph currently describes ONLY the four over-staging bullets; it does not yet mention
  the destructive-command class it sits right below, which is instead cross-referenced from
  inside the "No Destructive Git on Uncommitted Work" section itself (lines 102-105). Whichever
  of these two spots the new predicate's rule text lands in, the "enforced by" cross-reference
  needs a parallel update so the hook and the doc do not drift.
- Line 99 "No Destructive Git on Uncommitted Work" — title and framing structurally exclude
  already-committed history (confirmed per dispatch's argument). The natural sibling-section
  insertion point is immediately after this section (ends line 147, right before "### Always
  Check Before Commit" at line 150) — a reader arriving at the uncommitted-work rule hits the
  new section on the very next scroll.

#### 4. `agents/general-implementation-agent.md` — confirmed no existing prohibition

- `grep -c amend` / `grep -c "git reset"`: 0 each (confirmed, matches dispatch claim "carries no
  prohibition at all").
- `git-commit-scoped.sh` is already referenced twice as the sanctioned commit path (Stage 4B-iii
  "Green Sub-Step Commit", and the "Phase Checkpoint Protocol" step 5) — the mandate this task
  adds is a **MUST NOT** framing of an already-well-established **MUST** elsewhere in the same
  file; no new mechanism, just an explicit prohibition bullet.
- The natural insertion point is the **"MUST NOT" list under "Critical Requirements"** (currently
  9 numbered bullets, the file's existing catch-all prohibition list — see items 6-9 quoted
  below); a new bullet 10 reading approximately "MUST NOT run bare `git commit --amend` or
  non-`--hard` `git reset` — all commits go through `.claude/scripts/git-commit-scoped.sh`" fits
  this list's existing register and cross-referencing style exactly (bullet 6 already
  cross-references a rule file the same way: "see `.claude/rules/source-store-deploy-boundary.md`").

#### 5. `context/contracts/recovery.md` — the ACTUAL item-(d) target (not the file the dispatch names)

- Lines 19-26 ("## \"Green\" Means Fix Forward"): "They NEVER mean: `git reset`, `git checkout --
  <path>`, `git restore` (non-`--staged`), `git clean -fd`, `git stash drop`/`clear`, or any
  other operation that discards uncommitted changes to fall back to a prior commit — **while
  uncommitted changes exist**." This is word-for-word the mis-scoping the dispatch describes,
  just filed under a different name and location than the dispatch's item (d) expects.
- This file is loaded into **hard-mode** dispatch prompts only (line 10-17: "loaded exclusively
  via `skill-orchestrate`'s hard-mode contract injection... both effort modes' implement
  dispatches resolve through this one engine's H1 branch when `hard_mode` is true"), which
  matches the dispatch's framing of this correction as hard-mode-specific — it was simply
  authored as a shared contract file rather than a per-domain `*-hard-agent.md` file, because no
  `general-implementation-hard-agent.md` exists (general/meta/markdown task types have no
  hard-mode agent variant at all — CLAUDE.md's "Graceful fallback: commands without hard
  variants silently use standard behavior" is the documented reason no such file was ever
  created).
- Lines 77-82 restate the hook's guarded-command list a second time, inside rung (c)'s
  snapshot-first instructions ("`.claude/hooks/guard-destructive-git.sh` is a PreToolUse Bash
  hook that blocks `git reset --hard`, ..."). This second restatement will ALSO drift out of
  sync with the hook once the new predicate ships, exactly like `git-workflow.md`'s "enforced
  by" paragraph — a second, not-explicitly-named-in-dispatch touch point the planner should
  fold into item (d)'s correction pass since it sits in the very same file and section family.

#### 6. `context/standards/git-safety.md` (589 lines) — the absorbed item (c) target

- Already contains a "## Recovering an Unconsumed Dispatch" section (lines 37-51) that explains
  the hook's dirty-tree design choice in prose ("on a dirty tree shared with a concurrently
  dispatched task, git-based undo cannot distinguish 'revert my own stray write' from 'discard
  someone else's in-flight work'"). This is the natural location for the new hazard-class
  paragraph (concurrent-writer history rewrites), since it already discusses the hook's
  concurrency-adjacent design reasoning in the same file, one section away.

#### 7. Concurrency-signal candidates (the open design question the dispatch flags)

Three primitives were evaluated against the motivating incident (5 concurrent implementation
agents, same `/orchestrate` wave, same shared working tree, different task numbers):

**(A) Per-task lock liveness count — `specs/{NNN}_{SLUG}/.lock/holder.json`** (task-number-keyed,
`context/patterns/task-lock.md`).
- Each task directory's lock is independent; the incident's 5 agents would each hold their own
  task's lock simultaneously. A hook-side scan (`find specs -maxdepth 3 -name holder.json`,
  mirroring the existing `.git-snapshot-marker` scan idiom at lines 271-284 of the hook) counting
  **live** locks (fresh heartbeat AND `kill -0` on the recorded `pid` — the same pid-liveness
  floor `task-lock.sh` already applies at lines 828 and 1113) directly answers "is more than one
  task currently active in this repo?" without needing to identify which lock is "mine".
- Strength: self-contained, no identity correlation needed, matches the incident's actual
  mechanism (multiple simultaneously-held task-number locks) exactly, reuses an existing scan
  idiom already present in this same hook file.
- Weakness: a solo user who starts a second manual command (e.g. `/research` on a different task
  in a second terminal) while `/implement`-ing another would also trip this — which is arguably
  correct (that IS two concurrent writers to the same shared tree), not a false positive.

**(B) Session-registry liveness — `specs/.sessions/{session_id}.json`** (`task-lock.sh
session-register`/`session-list`, `context/patterns/task-lock.md`'s Session-Registry section).
- `task-lock.sh session-list` already emits NDJSON with a `live` boolean (computed by
  `session_liveness()`, the same two-signal pid+heartbeat logic as (A), factored out at line
  1441+ and shared with `cmd_session_reap`) and a `task_numbers` array per registered session —
  this is a MORE complete, already-battle-tested primitive than re-scanning `.lock/` directly,
  and per `context/standards/orchestrator-runtime-files.md` line 49 it is **produced today with
  zero consumers** ("a future reader-adder must add its own freshness/ownership checks together
  with the reader, not separately"). This task would be exactly that reader-adder.
- Complication: the registry is keyed by the agent-system's own `sess_{epoch}_{hex}` convention,
  registered by `skill-orchestrate` itself (bare, un-suffixed session_id, listing ALL task
  numbers dispatched that cycle in one entry — see `orchestrate-cycle-plan.sh` lines 90-97's
  documented "bare-vs-suffixed session_id invariant": implement-phase task-lock holders use the
  BARE session_id, so multiple concurrently-dispatched tasks in one cycle share one registry row
  with `task_numbers.length > 1`). This is a strong signal in its own right (no `.lock/`-scanning
  needed at all: `session-list | jq 'select(.live) | .task_numbers | length > 1'` suffices) but
  is a DIFFERENT namespace from the hook's own `.session_id` field on the PreToolUse payload,
  which is Claude Code's native session UUID (confirmed via `hooks/wezterm-preflight-status.sh`'s
  own comment: "Claude Code's native session UUID... never a different session's marker"). The
  hook cannot correlate its own native session_id to an agent-system `sess_*` row; it can only
  read the registry's aggregate liveness/count, not attribute it to "self" — which turns out not
  to matter for a pure liveness-count signal (see (A)'s same non-issue).
- Recommendation: prefer this reused primitive (`task-lock.sh session-list`) over re-scanning
  `.lock/` directly (A) — same conclusion, less new code, and it exercises a documented "not yet
  consumed" data path deliberately.

**(C) HEAD-movement tracking** (per-session last-known-commit-sha state).
- Most directly diagnostic of the exact incident mechanism (amend rewriting a commit that landed
  after the agent's own last commit) but requires NEW per-session state the hook does not
  currently keep anywhere (dispatch's own caveat). Higher implementation cost, no reusable
  existing primitive. Not recommended as the primary signal; could be a FUTURE refinement layered
  on top of (A)/(B) once those are shipped, not a blocker for this task.

**Recommendation for planning**: signal (B) (reuse `task-lock.sh session-list`'s liveness/
`task_numbers` count), falling back to (A)'s direct `.lock/` scan only if `task-lock.sh` is
unavailable at hook-execution time (mirroring the hook's own established graceful-degradation
style elsewhere in the file — e.g. `2>/dev/null` + `|| true` throughout).

#### 8. Response mechanism (block vs. warn)

The dispatch asks to "decide the response... these may differ per signal strength." Given
finding (7)'s liveness computation already distinguishes `live: true` (fresh pid+heartbeat) from
`stale-heartbeat`/`dead-pid`/`corrupt` (per `session_liveness()`'s four-way classification), the
natural split is: **hard refusal (exit 2)** when a genuinely live foreign task/session is found;
**no action** (not even a warning) when only stale/dead entries are found, since those carry no
present concurrency risk and a stale lock is already handled by the existing reap policy. This
avoids inventing a third "warn but allow" tier the dispatch left open but did not mandate, and
keeps the mechanism binary like every other predicate already in this file (all seven existing
detectors are exit-2-or-nothing, no warn tier precedent exists in this hook today).

### External Resources

Not applicable — this is a pure in-repo contract/hook design task; no external documentation was
consulted.

### Recommendations

1. **Item (d)'s real target is `context/contracts/recovery.md` lines 19-26**, not a
   `general-implementation-hard-agent.md` file (which does not exist for the general/meta/
   markdown task types this task's own agent belongs to). Planning must correct the dispatch's
   named path.
2. Splice the new concurrency predicate **before** the clean-tree exemption (currently lines
   76-78), or restructure so it runs unconditionally regardless of tree state — this is the
   single load-bearing ordering fact from finding (1).
3. Reuse `task-lock.sh session-list`'s already-shipped liveness computation (finding 7,
   candidate B) rather than re-implementing lock/pid scanning inline in the hook.
4. Insert the new rules/git-workflow.md sibling section immediately after "No Destructive Git on
   Uncommitted Work" (after line 147), and extend — not replace — the "enforced by" paragraph at
   lines 93-97.
5. Add the general-implementation-agent.md MUST-NOT bullet as item 10 in the existing
   "Critical Requirements" MUST-NOT list (currently ends at item 9, `agents/general-
   implementation-agent.md` lines ~806-816).
6. Also touch `context/contracts/recovery.md` lines 77-82 (the hook's guarded-command list is
   restated there a second time) while correcting item (d), to prevent the same "enforced by"
   drift the absorbed task's item (d) explicitly warns about for `git-workflow.md`.
7. Extend `scripts/tests/test-guard-destructive-git.sh` with a **clean-tree** fixture variant
   (the existing fixture is dirty-only by design) for the new predicate's test cases, per
   finding (2).
8. Place the new git-safety.md hazard-class paragraph inside or adjacent to the existing
   "Recovering an Unconsumed Dispatch" section (finding 6), which already discusses the hook's
   concurrency-adjacent reasoning.

## Decisions

- Recommend candidate (B) (session-registry liveness reuse) as the primary concurrency signal,
  with (A) (direct `.lock/` scan) as a documented fallback if `task-lock.sh` is unreachable.
  Deferred to planning: final choice is the planner's call, not fixed here — the dispatch itself
  reserves this as an open decision ("none pre-committed").
- Recommend binary block/no-action (exit 2 / exit 0) rather than a third warn-only tier, per
  finding (8), deferred to planning for final confirmation.

## Risks & Mitigations

- **Risk**: planning proceeds against the dispatch's literal `general-implementation-hard-
  agent.md` path, discovers it does not exist mid-implementation, and stalls. **Mitigation**:
  this report's finding (5) retargets it explicitly to `context/contracts/recovery.md`; planning
  should adopt that retarget directly rather than re-discovering it.
- **Risk**: the new predicate is appended after the existing clean-tree `exit 0` (the path of
  least resistance, mirroring every other detector's placement) and is silently dead code.
  **Mitigation**: finding (1)/recommendation (2) flags this explicitly; the implementation plan
  and its verification step must include a clean-tree `--amend`-under-foreign-lock test case
  that would fail loudly if this ordering mistake were made.
- **Risk**: reusing `task-lock.sh session-list` from inside a PreToolUse hook adds a jq + shell
  subprocess call to every Bash invocation's hook chain (performance/latency concern for a
  frequently-fired hook). **Mitigation**: the existing hook already runs `git status --porcelain`
  and (on the destructive-pattern path) a `find specs -maxdepth 3` scan per invocation; one more
  bounded subprocess call is consistent with the file's existing cost profile, and the new
  predicate only needs to run when the command actually matches `--amend`/`reset` syntax (i.e.
  it can be argv-gated first, and the registry read done only on a syntactic hit) — deferred to
  planning as an ordering detail within the new predicate's own logic.

## Context Extension Recommendations

- **Topic**: Session-registry consumers.
- **Gap**: `context/standards/orchestrator-runtime-files.md` line 49 documents the session
  registry as having no reader yet, with a note that "a future reader-adder must add its own
  freshness/ownership checks together with the reader, not separately." Once this task ships the
  hook as the first consumer, that row's "None in the source store today" claim becomes stale.
- **Recommendation**: the implementation plan should update that row (or add a note) once the
  hook becomes a live consumer, so this documented gap does not silently persist past this task.

## Appendix

- Search queries used: `grep -rn "Recovery Ladder"`, `grep -c amend`/`grep -c mixed` across
  `agent-system/extensions/core/{rules,context,agents}/`, `find . -iname "*general-
  implementation-hard*"`, `grep -rln "session-registry|\.task-locks"`.
- Files read in full or substantial part: `hooks/guard-destructive-git.sh`, `rules/git-
  workflow.md`, `agents/general-implementation-agent.md` (Stage 0-8 + Critical Requirements),
  `context/contracts/recovery.md` (full), `context/patterns/task-lock.md` (partial, Session-
  Registry sections), `scripts/task-lock.sh` (session-register/session-list/session_liveness
  regions), `scripts/git-commit-scoped.sh` (header), `context/standards/git-safety.md` (partial),
  `context/standards/orchestrator-runtime-files.md` (session-registry row), `scripts/tests/
  test-guard-destructive-git.sh` (header).
- Source store confirmed via `.claude-extensions.json`'s `source_dir` field:
  `/home/benjamin/.config/nvim/agent-system/extensions/core`.
