# Implementation Plan: Forbid concurrent-writer history rewrites (rules/contracts + concurrency-gated hook predicate)

- **Task**: 139 - Forbid concurrent-writer history rewrites (rules/contracts) + concurrency-gated hook predicate (absorbed former task 140)
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/139_forbid_concurrent_writer_history_rewrites/reports/01_forbid-concurrent-writer-rewrites.md
- **Artifacts**: plans/01_forbid-concurrent-writer-rewrites.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Bare git history rewrites (`git commit --amend`, a HEAD-moving `git reset`) are forbidden nowhere
in the agent system, and all three existing layers that look like a prohibition are scoped by
*dirtiness of the working tree* while the real hazard is *concurrency of writers* — so every one
of them would have actively waved through the 2026-09-02 incident. This plan closes the policy
layer first (`rules/git-workflow.md`, `agents/general-implementation-agent.md`,
`context/contracts/recovery.md`), then adds a **second, independent, tree-state-blind predicate**
to `hooks/guard-destructive-git.sh` that refuses a history rewrite whenever a live dispatched
writer exists in this repo, then proves it with a clean-tree test fixture and a redeploy.

Definition of done: the four acceptance criteria of the contract layer hold; a bare
`git commit --amend` under a live foreign task lock is refused by the *deployed* hook copy with a
message pointing at the new rule section; `git-commit-scoped.sh`, solo use, pathspec unstaging,
and a commit message containing the literal text `--amend` all remain unblocked.

### Research Integration

The research report is adopted in full, with two corrections established while grounding this
plan:

1. **Adopted — item (d) retarget.** `agents/general-implementation-hard-agent.md` does not exist.
   The mis-scoped "while uncommitted changes exist" prohibition actually lives in
   `context/contracts/recovery.md`'s `## "Green" Means Fix Forward` section, which is the real
   edit target (Phase 3), together with the second restatement of the hook's guarded-command list
   inside the same file's rung (c).
2. **Adopted — predicate ordering is load-bearing.** The hook's clean-tree `exit 0` runs before
   every detector, so the new predicate must be spliced *above* it, not appended into the
   `MATCHED` chain (Phase 4). Appending it below is silent dead code.
3. **Correction to the report — `make_clean_repo` already exists.** The report states the test
   harness has only a dirty fixture; `scripts/tests/test-guard-destructive-git.sh` already ships
   both `make_dirty_repo` and `make_clean_repo`, plus `assert_allowed_clean`. Phase 5 therefore
   adds *concurrency-record* fixture helpers on top of the existing clean fixture, not a new
   clean fixture.
4. **Correction to the report — signal (B) cannot be reached via `task-lock.sh`.** The report
   recommends invoking `task-lock.sh session-list` from the hook. That is not viable:
   `task-lock.sh` sources `deploy-root-guard.sh`, which **exits 1 whenever the script is run from
   the source store**, and it anchors `PROJECT_ROOT` to its own `SCRIPT_DIR`, not to the caller's
   cwd. A hook calling it would (a) always fall back in source-store mode, so the primary path
   would never be exercised by the test suite, and (b) in deployed mode read the *real* repo's
   `specs/` regardless of the fixture's cwd, making every concurrency test non-hermetic and
   dependent on whatever `/orchestrate` run happens to be live. The plan therefore reads both
   record directories **directly and cwd-relatively** (`specs/*/.lock/holder.json` and
   `specs/.sessions/*.json`), inlining `task-lock.sh`'s own portable `age_minutes` idiom and
   `kill -0` pid floor. This keeps the exact liveness semantics the report recommended while
   using the hook's own already-present, cwd-relative `find specs -maxdepth 3` scan idiom.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied for this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- `git commit --amend` and non-hard (HEAD-moving) `git reset` appear in `rules/git-workflow.md`'s
  "Never Run" list with the concurrency qualifier.
- A sibling rule section, reachable from the uncommitted-work rule, records the incident, the
  concurrency-vs-dirtiness distinction, what is forbidden, and what stays permitted.
- `agents/general-implementation-agent.md` carries an explicit MUST NOT bullet routing all
  commits through `scripts/git-commit-scoped.sh`.
- `context/contracts/recovery.md` no longer scopes its git prohibition solely by tree dirtiness.
- `hooks/guard-destructive-git.sh` gains a second predicate that consults concurrency, never tree
  dirtiness, and refuses with a message pointing at the new rule section.
- Concrete verified cases: refused under a live foreign lock; permitted with no live writer;
  `git-commit-scoped.sh` permitted; a commit message containing `--amend` does not trigger;
  pathspec-only `git reset -- <path>` unstaging permitted.
- The change survives `.claude/` regeneration and fires from the deployed copy.

**Non-Goals**:
- Forbidding `--amend` unconditionally for single-session interactive use. The discriminating
  variable is a live concurrent writer, not the command.
- Retroactive repair of the mislabeled commit `fd50fabfd` — a separate operator decision for when
  the branch is quiet.
- Any change to the existing dirty-tree destructive-command predicate or the over-staging
  predicate, including their exemption mechanics. Both keep their current behavior byte-for-byte.
- A third "warn but allow" response tier. The response is binary (`exit 2` / fall through),
  matching all seven existing detectors; no warn-tier precedent exists in this file.
- Widening the predicate to `git rebase`, `git filter-branch`, or `git push --force` (the latter
  is already forbidden by rule and by `pr-prohibition.md`).
- Hand-editing anything under `.claude/**`. The source store
  `agent-system/extensions/core/` is the sole edit target; `.claude/` changes only via redeploy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New predicate appended below the clean-tree `exit 0` and is silent dead code | H | M | Phase 4 moves `COMMAND_SCAN` construction above the clean-tree check and places the predicate between them; Phase 5's `assert_blocked_clean_with_foreign_lock` case fails loudly if the ordering is wrong (the fixture tree is deliberately clean) |
| Over-broad `git reset` matching breaks legitimate unstaging (`git reset -- <path>`, `git reset HEAD -- <path>`) | H | H | Predicate fires only on a HEAD-*moving* reset: a non-flag commit-ish token before any `--` separator, with bare `HEAD`/`@` explicitly exempted. Phase 5 pins all four allow-cases and four block-cases |
| Legitimate solo interactive `--amend` blocked because the operator's own `/orchestrate` session is registered live | M | M | Documented, auditable in-command override `GUARD_ALLOW_HISTORY_REWRITE=1` detected via `COMMAND_SCAN` (never via the hook's own environment), with an explicit "agents MUST NOT use this" note in the rule section and the hook header; pinned by a test case |
| Moving `COMMAND_SCAN` above the clean-tree exit accidentally also moves the over-staging detectors above it, changing their documented dirty-tree-only behavior | H | M | Phase 4 moves *only* the pure-string `COMMAND_SCAN` block; the clean-tree `exit 0` stays immediately above the over-staging detectors. Phase 5 re-runs the whole existing suite unchanged, including `assert_allowed_clean` |
| Liveness records unreadable (no `specs/`, no `jq`, unparseable timestamp) causes a hard refusal of every rewrite | M | M | Predicate fails **open** (falls through) on any read/parse failure, in the file's established `2>/dev/null || true` style; documented in the header as a deliberate posture for a net layered over a documented rule |
| Full redeploy in Phase 7 picks up a concurrent sibling task's half-finished source-store edit | M | M | Sibling file scopes were checked and none overlaps this task's footprint; use default (non-destructive resync) `deploy-headless.sh`, and verify with `check-deploy-freshness.sh` plus a targeted diff of the deployed copy of *this task's* files only |
| Adding "Never Run" bullets invalidates the positional phrase "all four bullets immediately above" in the "Enforced by" paragraph | M | H | Phase 1 inserts the new bullets *above* the over-staging group and replaces the fragile positional count with a non-positional reference |
| Sibling task edits `scripts/git-commit-scoped.sh` this same cycle | L | M | This task only *references* that script in prose; it is not in this task's file footprint and must not be edited here |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5, 6 | 4 |
| 4 | 7 | 2, 3, 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Rules Layer — Never Run bullets and the sibling rule section [COMPLETED]

**Goal**: `rules/git-workflow.md` forbids concurrent-writer history rewrites, with the rationale
placed where a reader arriving at the uncommitted-work rule cannot miss it, and the "Enforced by"
framing kept in agreement with the hook.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/rules/git-workflow.md` immediately before editing (a
      sibling may have touched the shared tree). *(completed)*
- [x] In `### Never Run`, insert two bullets **immediately after the existing `git reset --hard`
      bullet and before the `git add -A` bullet** (placement is load-bearing — see the next task):
      one for `git commit --amend` and one for a HEAD-moving `git reset` (`--soft`/`--mixed`/bare,
      and `--hard` with a commit-ish), each carrying the concurrency qualifier ("while any other
      dispatched writer is live in this repo") and a pointer to the new section below. *(completed)*
- [x] Replace the fragile positional phrase `all four bullets immediately above` in the
      `**Enforced by guard-destructive-git.sh**` paragraph with a non-positional reference to the
      over-staging bullets by name. Add a second sentence to that paragraph naming the new
      concurrency-gated history-rewrite predicate and stating that, unlike the over-staging and
      destructive-command predicates, it does **not** consult tree dirtiness and has no
      snapshot-marker exemption. *(completed)*
- [x] Add a new `###` section titled `No History Rewrites While Another Writer Is Live`,
      positioned **immediately after** the `### No Destructive Git on Uncommitted Work` section
      and **before** `### Always Check Before Commit`. Content, in this order:
      (i) the rule: agents MUST NOT run bare `git commit --amend` or a HEAD-moving `git reset`
      while any other dispatched writer is live; all commits go through
      `.claude/scripts/git-commit-scoped.sh`;
      (ii) the incident record (observed 2026-09-02, five concurrent implementation agents
      committing to master; an amend intended for the agent's own commit rewrote a sibling's
      commit that had landed in between, preserving its tree and overwriting its message; a
      follow-up `git reset --mixed <own-sha>` rewound HEAD past three further legitimate commits
      and intermingled their changes; recovered via reflog with zero content lost; residual damage
      exactly one mislabeled commit message; evidence `539561c39` correct, `9c5b790b6` orphaned
      original, `fd50fabfd` tree-identical with the wrong message);
      (iii) the load-bearing distinction: **the predicate is concurrency of writers, not dirtiness
      of the tree** — both commands are non-destructive to the working tree, so every
      dirtiness-scoped guard waves them through; the uncommitted-work rule above structurally
      cannot fire on this hazard;
      (iv) what stays permitted: `git-commit-scoped.sh` (its internal git is invisible at the
      hook's observation boundary), solo interactive `--amend` with no live writer, bare
      `git reset`, `git reset -- <path>` and `git reset HEAD -- <path>` unstaging, and any commit
      message that merely contains the text `--amend`;
      (v) practical guidance for the incident's actual motive: a missing trailer or a wrong
      message on an already-pushed-or-shared commit is **left alone** — add a follow-up commit or
      record it; never amend to fix it under concurrency;
      (vi) enforcement pointer to `guard-destructive-git.sh`'s concurrency-gated predicate and
      the documented, auditable `GUARD_ALLOW_HISTORY_REWRITE=1` operator override, with an
      explicit statement that agents MUST NOT use that override. *(completed)*
- [x] Verify no task-number reference was introduced (this file is a deliverable outside
      `specs/**`): cite the commit shas and the 2026-09-02 date, never a task number. *(completed)*
- [x] Commit this file alone via `bash .claude/scripts/git-commit-scoped.sh`. *(completed)*
- [x] *(deviation: altered — discovered during Phase 7's redeploy verification (Gate 20, the
      orchestrator context budget lock): the full-detail version of item (iv) drove
      `rules/git-workflow.md` from 8,828 B to 13,166 B, pushing the eager-load total to 69,375 B
      against a hard-reviewed 65,950 B baseline, `orchestrator-context-budget.json`'s
      `eager_load.baseline_bytes` (must never be silently re-derived). Trimmed the new section in
      `rules/git-workflow.md` down to the rule statement, a one-sentence dirtiness-vs-concurrency
      distinction, a brief permitted-forms list, and an enforcement/override paragraph; relocated
      the full incident record, the complete permitted-forms list, and the practical guidance for
      the incident's actual motive to a new "No History Rewrites While Another Writer Is Live —
      Incident and Full Detail" section in `context/standards/git-workflow-narrative.md` (the
      established lazy-loaded companion this same file already uses for its
      "No Destructive Git on Uncommitted Work" sibling rule). This mirrors this codebase's own
      precedent, "split git-workflow.md into eager core plus lazy narrative companion". Final
      measured eager-load total: 65,949 B, 1 B under baseline. All content required by items
      (i)-(vi) above is still present, split across the two files rather than inlined in one;
      `git-safety.md`'s "A Second Hazard Class" section (Phase 6) also carries the full incident
      and design rationale independently.)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the `### Never Run` list currently holds 7 bullets whose
last 3 are the over-staging group, and that the `**Enforced by ...**` paragraph's "all four
bullets immediately above" already miscounts them (4 command *forms* across 3 bullets). Confirm by
re-reading the section before editing and counting the bullets in place; if the count differs,
keep the non-positional rewrite and adjust the described placement, do not preserve a positional
phrase.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - two `Never Run` bullets; de-positionalize
  and extend the "Enforced by" paragraph; new `### No History Rewrites While Another Writer Is
  Live` section

**Verification**:
- `grep -n 'commit --amend' agent-system/extensions/core/rules/git-workflow.md` returns a hit in
  the `Never Run` list and in the new section.
- `grep -n 'No History Rewrites While Another Writer Is Live'` returns exactly one `###` heading,
  and `grep -n '^### '` shows it between `No Destructive Git on Uncommitted Work` and
  `Always Check Before Commit`.
- `grep -c 'all four bullets immediately above'` returns 0.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence for this file.

---

### Phase 2: Agent Contract — MUST NOT bullet and git-commit-scoped.sh mandate [COMPLETED]

**Goal**: `general-implementation-agent.md` carries an explicit prohibition on bare history
rewrites and an explicit mandate to route every commit through `git-commit-scoped.sh`.

**Tasks**:
- [x] Re-read the `**MUST NOT**:` list under `## Critical Requirements` in
      `agent-system/extensions/core/agents/general-implementation-agent.md` immediately before
      editing. *(completed)*
- [x] Append a new numbered bullet (item 10, after the current item 9) prohibiting bare
      `git commit --amend` and a HEAD-moving bare `git reset`, mandating
      `.claude/scripts/git-commit-scoped.sh` as the sole commit path (it serializes on the commit
      mutex and path-scopes staging), and cross-referencing
      `.claude/rules/git-workflow.md`'s `No History Rewrites While Another Writer Is Live` section
      in the same register the existing items 6-8 use for their rule cross-references. *(completed)*
- [x] Include the empirical support in one clause: in the motivating run, four of five concurrent
      agents used `git-commit-scoped.sh` exclusively and had zero incidents; the one that did not
      caused the entire incident. *(completed)*
- [x] Confirm the new bullet does not reference a task number (deliverable outside `specs/**`). *(completed)*
- [x] Commit this file alone via `git-commit-scoped.sh`. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - new MUST NOT item 10 in
  the `## Critical Requirements` list

**Verification**:
- `grep -n 'git-commit-scoped' agent-system/extensions/core/agents/general-implementation-agent.md`
  shows the new bullet alongside the pre-existing Stage 4B-iii and Phase Checkpoint references.
- The `**MUST NOT**:` list numbering is contiguous 1-10 with no duplicate numbers.
- The cross-referenced section title matches Phase 1's heading text exactly (no dangling anchor).

---

### Phase 3: Correct the Mis-Scoped Prohibition in recovery.md [COMPLETED]

**Goal**: the hard-mode recovery contract no longer scopes its git prohibition solely by tree
dirtiness, and its second restatement of the hook's guarded-command list does not drift out of
agreement with the hook.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/contracts/recovery.md` immediately before
      editing. *(completed)*
- [x] In `## "Green" Means Fix Forward`, **correct** (do not merely supplement) the sentence
      ending `— while uncommitted changes exist.` so the prohibition covers two independent
      hazard classes: discarding uncommitted work (the existing, dirtiness-scoped clause) **and**
      rewriting already-committed history (`git commit --amend`, a HEAD-moving `git reset`) while
      another writer is live, which is not conditioned on tree state at all. *(completed)*
- [x] Add one sentence naming the distinction explicitly (dirtiness of the tree vs. concurrency of
      writers) and pointing at `git-workflow.md`'s new section for the incident rationale. *(completed)*
- [x] In rung (c) step 1, extend the restated hook command list ("blocks `git reset --hard`, ...
      on a dirty tree via `exit 2` unless a fresh snapshot marker exists") with the new predicate,
      stating that it is tree-state-blind and has no snapshot-marker exemption — so this second
      restatement stays in agreement with the hook after Phase 4. *(completed)*
- [x] Confirm no task-number reference was introduced. *(completed)*
- [x] Commit this file alone via `git-commit-scoped.sh`. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts exactly two touch points in this file (the
`## "Green" Means Fix Forward` sentence and rung (c) step 1's hook-list restatement). Confirm with
`grep -n 'uncommitted changes exist\|guard-destructive-git' context/contracts/recovery.md` before
editing and handle every hit found, not only these two.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/recovery.md` - corrected fix-forward
  prohibition scoping; extended hook-command restatement in rung (c)

**Verification**:
- `grep -n 'while uncommitted changes exist'` no longer shows an *unqualified* prohibition; the
  surviving clause is explicitly one of two named hazard classes.
- `grep -n 'amend' context/contracts/recovery.md` returns hits in both touch points.
- The file still reads correctly as a hard-mode-injected contract (rung (a)'s statement remains
  quotable in standard mode, per the file's own header note).

---

### Phase 4: The Concurrency-Gated History-Rewrite Predicate [COMPLETED]

**Goal**: `guard-destructive-git.sh` refuses a history rewrite whenever a live dispatched writer
exists, independently of tree state, without altering any existing predicate's behavior.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/hooks/guard-destructive-git.sh` immediately before
      editing. *(completed)*
- [x] **Restructure (ordering is load-bearing)**: move the pure-string `COMMAND_SCAN` construction
      block (quote-strip via `sed -z`, then comment-strip) to sit immediately after the empty-
      `$COMMAND` early exit and **above** the clean-tree `exit 0`. Move nothing else. The
      clean-tree `exit 0` must remain immediately above the over-staging detectors so those, and
      the destructive-pattern chain, keep their documented dirty-tree-only behavior unchanged.
      *(completed)*
- [x] Insert the new predicate between `COMMAND_SCAN` and the clean-tree exit, as a
      **syntactic-gate-first** block so no filesystem scan is paid unless the command actually
      matches:
      - **Gate A, amend**: a `git commit` segment (existing `(^|[;&|][[:space:]]*)git[[:space:]]+commit[^;&|]*`
        extraction idiom) containing `--amend` as a real argv token.
      - **Gate B, HEAD-moving reset**: a `git reset` segment carrying a non-flag commit-ish token
        that appears **before** any `--` separator, with bare `HEAD` and bare `@` explicitly
        exempted (they do not move HEAD). Reuse the per-segment `read -ra` token-walk idiom the
        directory/glob `git add` detector already uses, so a literal glob or path token is
        inspected rather than expanded. This deliberately also covers `git reset --hard <sha>`,
        which the existing dirty-tree predicate exempts on a clean tree.
      - Both gates read `$COMMAND_SCAN`, never raw `$COMMAND`, inheriting the existing
        false-positive closure for a commit message containing the literal text `--amend`.
      *(completed)*
- [x] Add the operator override: if `$COMMAND_SCAN` contains `GUARD_ALLOW_HISTORY_REWRITE=1`,
      fall through. Detect it **in the scan string only** — never from the hook's own environment,
      which the caller's inline assignment does not reach — so the override is always visible and
      auditable in the transcript. Comment it as operator-only, agents-MUST-NOT. *(completed)*
- [x] Implement `history_rewrite_live_writer()`: a cwd-relative liveness scan over both record
      families, following the file's existing `find specs -maxdepth 3` marker-scan idiom:
      - `find specs -maxdepth 3 -name holder.json -type f` (per-task locks, written by
        `command-gate-in.sh`/`orchestrate-cycle-plan.sh` for every operation, not just implement)
      - `specs/.sessions/*.json` (the in-flight session registry)
      - A record is **live** when its `pid` is numeric and `kill -0 "$pid"` succeeds **and** its
        `heartbeat_at` is within the freshness window. Inline `task-lock.sh`'s portable
        `age_minutes` idiom verbatim (`date -u -d` with the `date -u -j -f "%Y-%m-%dT%H:%M:%SZ"`
        BSD fallback, `999999` on parse failure). Introduce one local constant
        `HISTORY_REWRITE_LIVE_MIN="${HISTORY_REWRITE_LIVE_MIN:-30}"`, matching
        `TASK_LOCK_STALE_MIN`'s default and semantics.
      - **Do not source or invoke `task-lock.sh`**: it sources `deploy-root-guard.sh` (which
        `exit 1`s from the source store) and anchors `PROJECT_ROOT` to its own `SCRIPT_DIR`, not
        the caller's cwd — both fatal for a cwd-relative, hermetically testable hook. Record this
        reason in a comment so a later reader does not "simplify" it back.
      - Fail **open** (return non-live) on a missing `specs/`, missing `jq`, unreadable record, or
        unparseable timestamp, in the file's established `2>/dev/null || true` style.
      - Threshold: **one or more** live records refuses. This is deliberate and documented — the
        hook cannot correlate its own native Claude Code session UUID to an agent-system
        `sess_*` identity, so it cannot exclude "self"; a dispatched agent's own lock is itself
        proof that it is running under orchestration, where the new rule forbids bare rewrites
        outright. A genuinely solo interactive operator has no live lock and no live registry
        entry, so the explicit non-goal is preserved.
      *(completed: parse failure returns via `continue` — skip the record — rather than a named
      999999 sentinel; functionally identical fail-open behavior, verbatim `date -u -d` /
      `date -u -j -f` fallback chain inlined directly rather than wrapped in a same-named helper)*
- [x] Refuse with `exit 2` + stderr (never `permissionDecision: deny`, per the file's header
      warning), naming: the matched form, that the refusal is due to a live concurrent writer and
      not tree state, `.claude/scripts/git-commit-scoped.sh` as the sanctioned path,
      `.claude/rules/git-workflow.md`'s `No History Rewrites While Another Writer Is Live` section
      for the rationale, and the operator override with its agents-MUST-NOT caveat. *(completed)*
- [x] Rewrite the header comment block, which currently documents a single-hazard design: state
      both hazard classes, that the new predicate runs **before** the clean-tree exemption and
      consults concurrency rather than dirtiness, the two record families and the liveness rule,
      the fail-open posture, the one-or-more threshold with its can't-identify-self rationale, the
      override, and why `git-commit-scoped.sh` needs no special case (the existing
      observation-boundary argument applies unchanged). *(completed)*
- [x] `bash -n` the file, then `shellcheck` it if available, and commit it alone via
      `git-commit-scoped.sh`. *(completed: bash -n passed; shellcheck not installed in this
      environment)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - `COMMAND_SCAN` relocation above
  the clean-tree exit; new concurrency-gated history-rewrite predicate; rewritten header block

**Verification**:
- `bash -n agent-system/extensions/core/hooks/guard-destructive-git.sh` exits 0.
- Reading the file top-to-bottom, the order is: `COMMAND` extraction -> `COMMAND_SCAN` ->
  new predicate -> clean-tree `exit 0` -> over-staging detectors -> `MATCHED` chain ->
  snapshot-marker exemption.
- `grep -n 'deploy-root-guard\|task-lock.sh' hooks/guard-destructive-git.sh` shows only the
  explanatory comment, never an invocation.
- Manual smoke test from the repo root (which currently has live locks): a synthetic payload for
  `git commit --amend --no-edit` exits 2; the same command with the override prefix exits 0;
  `git commit -m "note about --amend"` exits 0; `git reset -- foo.txt` exits 0.
- Phase 5's suite is the authoritative gate; this phase's smoke test is not a substitute for it.

---

### Phase 5: Clean-Tree Concurrency Test Cases [COMPLETED]

**Goal**: the new predicate's behavior is pinned by hermetic fixture-driven cases that would fail
loudly if the predicate were placed below the clean-tree exemption or matched too broadly.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
      immediately before editing. Note that `make_clean_repo` and `assert_allowed_clean` already
      exist; build on them rather than adding a parallel clean fixture. *(completed)*
- [x] Add `add_live_lock <repo> <task_number>`: writes
      `<repo>/specs/{NNN}_{slug}/.lock/holder.json` with `pid` set to a genuinely live pid
      (`$$` of the test process) and `heartbeat_at` stamped now in the
      `%Y-%m-%dT%H:%M:%SZ` form the hook parses. *(completed)*
- [x] Add `add_stale_lock <repo> <task_number>`: same shape but with a long-past `heartbeat_at`
      and a pid that is not alive, to prove staleness filtering. *(completed: dead pid produced
      via fork-then-reap `dead_pid()` helper rather than a hardcoded sentinel, to avoid any
      dependency on the test host's actual process table)*
- [x] Add `add_live_session <repo>`: writes `<repo>/specs/.sessions/sess_test.json` with a live
      pid, fresh heartbeat, and a multi-entry `task_numbers` array — the incident's own shape.
      *(completed)*
- [x] Add `assert_blocked_clean <label> <command>` and `assert_allowed_clean_with <label> <command>
      <fixture-fn>` helpers in the existing `run_hook_in`/exit-code style, all operating on a
      **clean** repo so the dirty-tree gate cannot be what produces the result. *(completed:
      both helpers additionally take the fixture-fn as an explicit third argument, plus optional
      trailing fixture-args, e.g. `assert_blocked_clean <label> <cmd> add_live_lock 139` — needed
      since several distinct fixtures (live lock, live session, stale lock, no record) are each
      exercised through both helpers)*
- [x] Add a fixture self-check, mirroring the existing dirty self-check: assert the concurrency
      fixture repo's `git status --porcelain` is **empty**, so a BLOCK result cannot be credited to
      the dirty-tree path. *(completed: required adding a committed `.gitignore` for `specs/` in
      `make_concurrency_repo` — without it, the fixture's own `specs/.lock/holder.json` file
      showed up as an untracked path and the self-check failed for the wrong reason; caught and
      fixed by the self-check itself, exactly as designed)*
- [x] Add the block cases (clean tree + a live foreign lock): `git commit --amend`,
      `git commit --amend --no-edit`, `git reset --mixed abc1234`, `git reset abc1234`,
      `git reset --soft HEAD~1`, `git reset HEAD~2`, `git reset --hard abc1234`; and the same
      under `add_live_session` instead of a lock. *(completed)*
- [x] Add the allow cases: no concurrency record at all (`git commit --amend` permitted — the
      explicit non-goal); only a stale/dead record; `bash .claude/scripts/git-commit-scoped.sh ...`;
      `git commit -m "mention --amend in the message"`; a multi-line `-m` message containing
      `--amend`; `git reset` bare; `git reset -- foo.txt`; `git reset HEAD -- foo.txt`;
      `git reset HEAD`; and the `GUARD_ALLOW_HISTORY_REWRITE=1 git commit --amend` override.
      *(completed)*
- [x] Re-run the **entire** existing suite unchanged and confirm every pre-existing case still
      passes — especially `exemption: clean tree allows a destructive command`, which proves the
      `COMMAND_SCAN` relocation did not drag the other detectors above the clean-tree exit.
      *(completed: 72 passed, 0 failed; additionally did the one-off ordering confirmation from
      the Verification section below — temporarily reverting the relocation made exactly the 9
      new block cases fail, then restored)*
- [x] Commit this file alone via `git-commit-scoped.sh`. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts roughly 8 new block cases and 11 new allow cases on top
of the existing suite. Confirm the real totals by running the suite and reading its PASSED count
before and after; the enumerated list above is the floor, not a cap — add any case the
implementation reveals as load-bearing.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - concurrency fixture
  helpers, clean-tree assertion helpers, fixture self-check, new block/allow cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` exits 0 with
  zero `[FAIL]` lines, run from the source store (`HOOK` resolves to
  `../../hooks/guard-destructive-git.sh`).
- The new fixture self-check reports the concurrency fixture tree as clean.
- Temporarily reverting only the `COMMAND_SCAN` relocation (locally, not committed) makes the new
  block cases fail — a one-off confirmation that the cases actually exercise the ordering, then
  restore.

---

### Phase 6: Standards Documentation — New Hazard Class and First Registry Consumer [COMPLETED]

**Goal**: the standards layer describes the new hazard class and the chosen signal, and the
session registry is no longer documented as having no readers.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/standards/git-safety.md` immediately before
      editing. *(completed)*
- [x] Add a section adjacent to the existing `## Recovering an Unconsumed Dispatch` (which already
      reasons about the guard's concurrency-adjacent design) covering: the second hazard class
      (rewriting already-committed history under concurrent writers), why the dirty-tree design
      cannot address it, the chosen signal (live per-task lock holders and live session-registry
      entries, `kill -0` pid plus heartbeat freshness, cwd-relative direct reads), the
      one-or-more threshold and its can't-identify-self rationale, the binary `exit 2` response
      with no warn tier, the fail-open posture, and the operator override. *(completed)*
- [x] Re-read `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` and
      update the `specs/.sessions/{session_id}.json` row's Consumed-by cell: it is no longer
      "None in the source store today" — `hooks/guard-destructive-git.sh`'s concurrency-gated
      history-rewrite predicate is its first consumer, and it reads the entries directly
      (cwd-relative, with its own pid+heartbeat freshness check) rather than via
      `task-lock.sh session-list`, with the reason recorded. *(completed)*
- [x] Confirm neither file gained a task-number reference. *(completed)*
- [x] Commit both files together via `git-commit-scoped.sh` with an explicit two-path list.
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-safety.md` - new hazard-class section
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` -
  `specs/.sessions/{session_id}.json` row Consumed-by cell

**Verification**:
- `grep -n 'amend' context/standards/git-safety.md` returns the new section.
- `grep -n 'None in the source store today' context/standards/orchestrator-runtime-files.md` no
  longer matches the `.sessions` row (the `.return-meta-multi` row's own equivalent wording is
  untouched).
- The described signal matches Phase 4's shipped implementation, field for field.

---

### Phase 7: Redeploy and Confirm Survival [COMPLETED]

**Goal**: every change reaches `.claude/` through regeneration, and the deployed hook copy
actually fires.

**Tasks**:
- [x] Confirm all of Phases 1-6 are committed and the working tree carries no uncommitted edits
      to this task's files. *(completed: also caught and fixed a Phase 1 eager-context-budget
      overshoot during this confirmation pass — see Phase 1's deviation note)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` in its default (non-destructive resync) mode.
      *(completed: first run surfaced the eager-load Gate 20 [FAIL] plus two pre-existing
      literature-extension findings unrelated to this task; second run after the Phase 1 trim-fix
      shows Gate 20 [PASS] (65,949 B / 65,950 B baseline) with only the two unrelated
      literature-extension findings remaining)*
- [x] Run `bash .claude/scripts/check-deploy-freshness.sh` and confirm no STALE row for this
      task's files. *(completed: the WARN it reports is for the whole 'core' extension, driven by
      sibling tasks' in-flight source-store edits (task-reference-exemptions.md,
      orchestrate-predispatch-review.sh, its test, manifest.json) outside this task's file_scope;
      this task's own 8 files are confirmed byte-identical between source and deployed below)*
- [x] Diff the deployed copy of each changed file against its source-store counterpart
      (`.claude/hooks/guard-destructive-git.sh`, `.claude/rules/git-workflow.md`,
      `.claude/agents/general-implementation-agent.md`, `.claude/context/contracts/recovery.md`,
      `.claude/context/standards/git-safety.md`,
      `.claude/context/standards/orchestrator-runtime-files.md`,
      `.claude/context/standards/git-workflow-narrative.md`,
      `.claude/scripts/tests/test-guard-destructive-git.sh`) and confirm each is identical.
      *(completed: all 8 files identical)*
- [x] Run the test suite from the **deployed** path
      (`bash .claude/scripts/tests/test-guard-destructive-git.sh`, where `HOOK` resolves to
      `.claude/hooks/guard-destructive-git.sh`) and confirm it exits 0 — this is what proves the
      predicate fires from the deployed copy, not only from the source store. *(completed: 72
      passed, 0 failed; also confirmed a live manual smoke test against `.claude/hooks/
      guard-destructive-git.sh` directly: bare `--amend` refused with exit 2, pointing at
      `.claude/rules/git-workflow.md`'s new section)*
- [x] Run `bash .claude/scripts/validate-wiring.sh` (read-only; a sibling task owns that file this
      cycle, so do not edit it) and confirm no new failure attributable to these changes.
      *(completed: 41 pre-existing failures, all missing `project/neovim/**`/
      `project/memory/README.md` context files unrelated to this task's footprint; every check
      naming `general-implementation-agent`/`git-workflow.md` reports PASS)*
- [x] Commit any deploy-side bookkeeping the deploy itself produced, scoped, via
      `git-commit-scoped.sh`; do not stage unrelated sibling-task changes to the shared tree.
      *(completed: no deploy-side bookkeeping was produced beyond the Phase 1 trim-fix commit
      already made above; nothing further to commit here)*

**Timing**: 0.75 hours

**Depends on**: 2, 3, 5, 6

**Verification Tier**: full

**Files to modify**:
- (none hand-edited) `.claude/**` regenerated by `deploy-headless.sh`

**Verification**:
- `bash .claude/scripts/tests/test-guard-destructive-git.sh` exits 0 with zero `[FAIL]` lines.
- `diff` between each source-store file and its deployed counterpart is empty.
- `grep -n 'No History Rewrites While Another Writer Is Live' .claude/rules/git-workflow.md`
  matches, confirming the rule text survived regeneration.
- `git status --short` shows no stray staged path outside this task's footprint.

---

## Testing & Validation

- [x] Source-store suite: `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
      exits 0, all pre-existing cases still passing. *(completed: 72 passed, 0 failed)*
- [x] Deployed suite: `bash .claude/scripts/tests/test-guard-destructive-git.sh` exits 0.
      *(completed: 72 passed, 0 failed)*
- [x] Acceptance, contract layer: `git commit --amend` and a HEAD-moving `git reset` appear in
      `rules/git-workflow.md`'s `Never Run` list with the concurrency qualifier; the rationale sits
      immediately after the uncommitted-work section; `general-implementation-agent.md` carries the
      `git-commit-scoped.sh` mandate; `recovery.md` no longer scopes its prohibition solely by tree
      dirtiness. *(completed)*
- [x] Acceptance, enforcement layer: bare `--amend` under a live foreign lock on a **clean** tree
      is refused; the same command with no live writer is permitted; a `git-commit-scoped.sh`
      invocation is permitted; a commit message containing the literal `--amend` (single- and
      multi-line) does not trigger; `git reset -- <path>` unstaging is permitted. *(completed:
      pinned by Phase 5's 72-case suite plus a live manual smoke test in Phase 7)*
- [x] `bash -n` clean on both modified shell files; `shellcheck` clean if available. *(completed:
      both exit 0; shellcheck not installed in this environment)*
- [x] `bash .claude/scripts/check-task-references.sh` reports no new occurrence in any file this
      task touched outside `specs/**`. *(completed: 0 unexempted occurrences repo-wide)*
- [x] `bash .claude/scripts/validate-wiring.sh` shows no new failure. *(completed: 41 pre-existing
      failures, all missing `project/neovim/**`/`project/memory/README.md` context files
      unrelated to this task; every check naming this task's files reports PASS)*

## Artifacts & Outputs

- `specs/139_forbid_concurrent_writer_history_rewrites/plans/01_forbid-concurrent-writer-rewrites.md` (this plan)
- `specs/139_forbid_concurrent_writer_history_rewrites/summaries/01_forbid-concurrent-writer-rewrites-summary.md` (at implementation)
- `agent-system/extensions/core/rules/git-workflow.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/context/contracts/recovery.md`
- `agent-system/extensions/core/hooks/guard-destructive-git.sh`
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
- `agent-system/extensions/core/context/standards/git-safety.md`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- Regenerated `.claude/` counterparts of each of the above

## Rollback/Contingency

- Each phase commits exactly one file (Phase 6 commits two) through
  `.claude/scripts/git-commit-scoped.sh`, so any single phase is reverted with a scoped
  `git revert` of its own commit followed by a redeploy — no working-tree discard is involved and
  no snapshot is needed.
- The only behavioral risk is the hook. If the new predicate misfires in practice, the minimal
  containment is to revert Phase 4's commit and redeploy; the contract-layer phases are prose and
  stand on their own without it.
- A less drastic containment, if the block is correct but inconveniently timed, is the documented
  in-command `GUARD_ALLOW_HISTORY_REWRITE=1` operator override, or raising
  `HISTORY_REWRITE_LIVE_MIN` — neither requires a code change.
- This plan needs no `git-snapshot.sh` step. Should a genuine whole-tree rollback become
  unavoidable, follow `context/contracts/recovery.md`'s rollback rung (rung (c)) for the exact
  invocation shape, including its `--allow-out-of-scope` override for the deliberate whole-tree
  case; never emit a bare default-mode `git-snapshot.sh` as a routine checkpoint.
