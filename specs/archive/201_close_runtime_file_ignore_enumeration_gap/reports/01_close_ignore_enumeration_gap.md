# Research Report: Task #201

**Task**: 201 - Close runtime-file ignore enumeration gap
**Started**: 2026-09-09T20:00:00Z
**Completed**: 2026-09-09T20:12:00Z
**Effort**: small (per dispatch); scope is a sweep, not a single-line fix
**Dependencies**: None declared. Footprint overlap (non-blocking) with task 51, which is
`not_started` as of this research pass — task 201 can land first, no reconciliation needed now.
**Sources/Inputs**: Codebase (source store under `agent-system/extensions/core/`), git history,
live `check-runtime-file-tracking.sh` run, `shellcheck`.
**Artifacts**: - `specs/201_close_runtime_file_ignore_enumeration_gap/reports/01_close_ignore_enumeration_gap.md`
**Standards**: report-format.md, subagent-return.md, orchestrator-runtime-files.md,
shell-strict-mode.md

## Executive Summary

- Confirmed all three named enumeration sites are missing `.deploy-lock/`, exactly as the
  dispatch states: the standards file's "Consumer Repo Setup" gitignore block, both of
  `check-runtime-file-tracking.sh`'s lists (`EPHEMERAL_PROBES` / `b_patterns`), and (at the time
  the dispatch was written) the nvim repo's own root `/.gitignore`.
- The sweep in scope item (c) found **two more mutex directories with the identical gap**:
  `specs/.scope-lock/` and `specs/.commit-lock/` (both defined in `task-lock.sh`), plus one lock
  file, `specs/.errors.lock` (defined in `errors-append.sh`, sibling to the already-covered
  `specs/.events.lock`). `.commit-lock/` and `.errors.lock` are *already* in the nvim repo's own
  `.gitignore` (added ad hoc, out of band) but are absent from the standards file and from both
  of `check-runtime-file-tracking.sh`'s lists. `.scope-lock/` is missing from **all three sites**,
  same as `.deploy-lock/`.
- Root cause confirmed structurally, not just anecdotally: the gitignore pattern `**/.lock/`
  only matches a directory literally named `.lock`. Every mutex directory using a *different*
  name (`.scope-lock`, `.commit-lock`, `.deploy-lock`) is invisible to that one glob line, so
  each had to be (and wasn't reliably) added as its own separate pattern.
- **The historically-tracked `specs/.deploy-lock/owner` file described in the dispatch has
  already been untracked**, in commit `cf51ce8bb` ("meta: untrack deploy mutex swept in by an
  earlier specs/ pathspec", 2026-09-09 06:05:45 -0700), by a session that ran concurrently with
  this task's dispatch generation. Important nuance for the plan/implementation phase: that
  commit used a plain `git rm` (deleting the file from the working tree entirely), **not**
  `git rm --cached` (which the dispatch's "HANDLE WITH CARE" section and
  `check-runtime-file-tracking.sh`'s own remediation text both specify). No deploy was in flight
  at commit time or at research time (verified via `ps aux`), so no live mutex was actually
  destroyed here — but the *procedure* used deviated from the documented-correct one. The
  Acceptance criterion's "untrack via `git rm --cached`... with the on-disk file left intact" is
  therefore already moot for `.deploy-lock/` specifically (nothing is tracked, nothing is on
  disk) — implementation should verify-and-note this rather than re-run an untrack that has
  nothing left to do.
- A live precedent for scope (d)'s "single source" question already exists in this codebase:
  `scripts/lib/task-reference-patterns.sh` is sourced by both a lint script and a write-time
  hook specifically so two consumers cannot drift on one pattern set. The same shape (a
  `scripts/lib/runtime-file-patterns.sh`-style array, sourced by `check-runtime-file-tracking.sh`
  for both Check A and Check B) is directly applicable, though the markdown "Consumer Repo
  Setup" gitignore block cannot literally `source` a bash lib — that block will still need a
  provable-agreement mechanism (a diff check, or an explicit cross-reference) rather than a
  common `source` line.
- `check-runtime-file-tracking.sh` shellcheck is **not currently clean**: one pre-existing
  finding (`SC2034`, unused `YELLOW` variable) exists independent of this task's changes. The
  acceptance criterion ("shellcheck clean") will require resolving this too, or the check will
  fail after this task's edits for a reason unrelated to the edits themselves.
- Two additional specs/-rooted, runtime-created dotfile families were found during the sweep
  that resemble the documented class but sit closer to its edges — `specs/.eager-context-snapshot-{ts}.json`
  (an opt-in `--write` diagnostic snapshot from `measure-eager-context.sh`, never auto-invoked)
  and the already-gitignored-but-standards-undocumented `.dispatch/`, `.postflight-pending`,
  `.stale-loop-guard-*.json`, `.stale-churn-state-*.json`, `.exhausted-loop-guard-*.json`,
  `.git-snapshot-marker`, `untracked-backup-*/`. These are flagged as candidates, not asserted
  in-scope fixes — see Findings for the reasoning on each, since forcing them all in risks
  scope creep beyond what this task's ACCEPTANCE section asks for.

## Context & Scope

The task is a documentation/lint-coverage defect: `specs/.deploy-lock/` (a `mkdir`-based mutex
directory created by `deploy-headless.sh`) is absent from the standards doc, the lint script
that is supposed to catch tracked-ephemeral-file leaks, and (at dispatch time) the consumer
repo's own `.gitignore`. The live proof is a specific historical commit
(`96fb00a40e872f7226c434e481309ef9ef0198fe`) that tracked `specs/.deploy-lock/owner` while a
live deploy process held the mutex.

Scope per the dispatch: (a) fix the standards file, (b) fix both of
`check-runtime-file-tracking.sh`'s lists and any mirroring test fixture, (c) sweep for every
other mutex/lock/runtime artifact under `specs/` and fix any further gaps found, (d) decide
whether the three enumerations should derive from one source and implement if proportionate
(else document why not, with cross-reference comments). Explicit MUST NOT: never add
`.orchestrator-handoff.json` / `.return-meta.json` to any ignore list; never attempt to deliver
a repo-root `.gitignore` from the source store (the `root_files` deploy-target mismatch is
already documented and correct — not to be "fixed").

## Findings

### Codebase Patterns

**Site 1 — `context/standards/orchestrator-runtime-files.md`, "Consumer Repo Setup" block**
(`agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`, lines
272–309). The fenced gitignore block a consumer is told to hand-paste contains:

```
**/.lock/
**/.orchestrator-loop-guard
**/.continuation-loop-guard
**/.orchestrator-churn-state.json
**/.postflight-loop-guard
**/.orchestrator-multi-state*.json
**/.drift-inspection.json
**/.return-meta-*.json
**/.events.lock
**/.sessions/
**/.freshness-warn-streak.json
```

Missing (confirmed by grep against the whole file): `.deploy-lock/`, `.scope-lock/`,
`.commit-lock/`, `.errors.lock`. Also missing (see "Borderline / not asserted in-scope" below):
`.dispatch/` — notably, the file's own "Class Table" a few dozen lines earlier *does* list
`.dispatch/{seq}.md` as **Ephemeral**, so the block already contradicts the table within the
same file, independent of this task's `.deploy-lock` finding.

**Site 2 — `scripts/check-runtime-file-tracking.sh`**
(`agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`). Two arrays:

- `EPHEMERAL_PROBES` (Check A, ignore-coverage; lines ~31–45): 13 representative paths, none for
  `.deploy-lock/`, `.scope-lock/`, `.commit-lock/`, or `.errors.lock`.
- `b_patterns` (Check B, tracked-file scan; lines ~83–92): 11 regex patterns, same four gaps.

Live-demonstrated: running `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
against this repo right now (no tracked `.deploy-lock` exists any more) reports
`PASS — all three checks passed` — consistent with the dispatch's framing that the lint is
blind to this whole sub-class, not merely "would have caught it if the file were still
tracked." The script cannot detect a tracked `.deploy-lock/`, `.scope-lock/`, `.commit-lock/`,
or `.errors.lock` today, tracked or not, because none of the four appears in either array.

**Site 3 — the nvim repo's own root `/.gitignore`**. At dispatch-generation time this was
missing `.deploy-lock/` (per the dispatch text). At research time (now), `.gitignore` already
carries `**/.commit-lock/` and `**/.errors.lock` (added out of band, presumably manually or by
an unrelated session) but still lacks `**/.deploy-lock/` and `**/.scope-lock/` entirely. So this
site currently has a *different* two-of-four gap than the other two sites' four-of-four gap —
the three sites are not just individually incomplete, they are incomplete in different, mutually
inconsistent ways, which is itself evidence for the "derive from one source" question in scope
(d): right now there is no way to look at any one file and know the true membership of the
class.

### Sweep Results (scope item (c))

Grepped every extension's `scripts/*.sh` for `specs/\.[A-Za-z0-9_-]+` literals. Full result set
maps to the following dispositions:

| Path | Origin | Currently in .gitignore? | Currently in standards Class Table / gitignore block? | Currently in check script? | Disposition |
|------|--------|---------------------------|----------------------------------------------------------|------------------------------|--------------|
| `specs/.deploy-lock/` | `deploy-headless.sh` | No | No | No | **Fix (named in dispatch)** |
| `specs/.scope-lock/` | `task-lock.sh` `cmd_scope_acquire`/`cmd_scope_release` (cross-task `file_scope` overlap mutex) | No | No | No | **Fix (found by sweep)** |
| `specs/.commit-lock/` | `task-lock.sh` `cmd_commit_acquire` / `git-commit-scoped.sh` (serializes the git add+commit pair) | Yes (`**/.commit-lock/`) | No | No | **Fix (found by sweep)** |
| `specs/.errors.lock` | `errors-append.sh` (`flock` around append-only error store, sibling to `.events.lock`) | Yes (`**/.errors.lock`) | No | No | **Fix (found by sweep)** |
| `specs/.events.lock` | `events-append.sh` | Yes | Yes | Yes | Already correct |
| `specs/.sessions/` | `task-lock.sh` session registry | Yes | Yes | Yes | Already correct |
| `specs/.orchestrator-multi-state-*.json` | `skill-orchestrate` multi-task batch | Yes | Yes | Yes | Already correct |
| `specs/.return-meta-multi-*.json` | multi-task return-meta variant | Yes (`.return-meta-*.json`) | Yes | Yes | Already correct |
| `specs/.freshness-warn-streak.json` | `check-deploy-freshness.sh` | Yes | Yes | Yes | Already correct |

Task-lock.sh's own header comments (lines ~53–58, ~150–170) explicitly name `.scope-lock/` and
`.commit-lock/` as siblings of the per-task `.lock/` mechanism ("a second, independent mutex
directory... added below"), confirming these are first-class members of the exact same mutex
class the dispatch describes, produced by the exact same subsystem (`task-lock.sh`) that
produces the already-covered `.lock/`.

**Test fixtures that mirror the enumeration** (scope (b)'s "any test fixture that mirrors
them"): `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` and
`test-deploy-propagation.sh` both embed a verbatim copy of the (currently 11-line) canonical
gitignore block into a scratch repo's `.gitignore`, explicitly so that scratch repo represents "a
properly-onboarded consumer for gate14 (`check-runtime-file-tracking.sh`)'s ignore-coverage
check." Both harnesses invoke `deploy-headless.sh` against that scratch repo and treat a non-zero
exit as a hard failure; `deploy-headless.sh` in turn runs `verify-deploy.sh`, whose gate 14 is
exactly `check-runtime-file-tracking.sh`. **This is a real, load-bearing coupling, not a
hypothetical one**: if `check-runtime-file-tracking.sh`'s `EPHEMERAL_PROBES` gains
`.deploy-lock/` / `.scope-lock/` / `.commit-lock/` / `.errors.lock` without these two fixtures'
embedded `.gitignore` also gaining the matching patterns, gate 14's Check A will newly FAIL
inside these two test harnesses (deploy exit code 3, "landed_verify_red"), breaking both
previously-green tests as a side effect of this task's fix. These two fixtures **must** be
updated in lockstep with `check-runtime-file-tracking.sh`.

### Borderline candidates found during the sweep (not asserted in-scope)

These surfaced from the same grep sweep but sit outside the dispatch's tight framing
(mutex/lock directories and files with "no freshness gate on read" that a script writes at
`specs/` root or per-task root). Recorded for the plan phase to explicitly accept or reject
rather than silently drop:

- **`specs/.eager-context-snapshot-{ISO8601}.json`** (`measure-eager-context.sh --write`): an
  opt-in, human-invoked diagnostic snapshot for later before/after comparison. Not written by
  any automated orchestrator path (no caller in the source store today), not read back with
  "unconditional trust" the way the documented ephemeral class is — its whole purpose is a
  timestamped point-in-time record for a human to diff against later, structurally closer to
  the standards file's already-documented "deliberately excluded... preserve evidence" class
  (`.stray-handoff-{timestamp}.json`, `.stale-loop-guard-{ts}.json`) than to the mutex/loop-guard
  ephemeral class. No file of this shape exists in the repo today. Recommend explicit exclusion
  with a one-line rationale note (matching the existing "Not classified here" paragraph's
  style) rather than silent omission, so a future auditor doesn't have to re-derive the same
  conclusion.
- **`.dispatch/{seq}.md`, `.postflight-pending`, `.stale-loop-guard-*.json`,
  `.stale-churn-state-*.json`, `.exhausted-loop-guard-*.json`, `.git-snapshot-marker`,
  `untracked-backup-*/`**: all already correctly gitignored in the nvim repo's actual
  `/.gitignore` (confirmed by direct read), and (except `.dispatch/`, which the Class Table
  already lists) mostly documented elsewhere (checkpoint-before-overflow.md for
  `.git-snapshot-marker`/`untracked-backup-*/`; the "Not classified here" paragraph for the
  `.stale-*`/`.exhausted-*` trio). `.dispatch/` is the one genuine same-file inconsistency
  (Class Table lists it as Ephemeral; the Consumer Repo Setup block omits it) and is a
  legitimate, low-risk fix-while-there candidate since it is the same file, same section, and
  the dispatch's own point (d) about "provably agree[ing]" would otherwise leave this one
  self-contradiction standing. The rest are pre-existing, correctly-functioning gaps between
  this one standards file's self-declared scope and the repo's actual `.gitignore` superset;
  fixing them is not what this dispatch asks for and risks exceeding the stated ACCEPTANCE
  bar. Recommend leaving them alone unless the plan phase decides `.dispatch/`'s
  same-file self-contradiction is worth a one-line, near-zero-risk fix alongside the mutex work.

### External Resources

None consulted — this is a pure codebase-internal documentation/lint-coverage task with no
external API or library surface.

### Recommendations

1. **Standards file** (`context/standards/orchestrator-runtime-files.md`): add `.deploy-lock/`,
   `.scope-lock/`, `.commit-lock/`, `.errors.lock` to the "Consumer Repo Setup" gitignore block,
   each with a Class Table row (mirroring the existing `.lock/`/`.events.lock` rows: writer,
   reader, cleanup site, disposition = Ephemeral). Use `task-lock.sh`'s own header comments
   (lines ~53–58, ~150–170, ~569–570) as the writer/reader source for `.scope-lock/` and
   `.commit-lock/`; use `errors-append.sh` line ~105 for `.errors.lock`; use
   `deploy-headless.sh` lines ~139–271 for `.deploy-lock/`.
2. **`check-runtime-file-tracking.sh`**: add matching entries to both `EPHEMERAL_PROBES` (a
   representative probe path per new class — a file inside `.deploy-lock/`/`.scope-lock/`/
   `.commit-lock/` since they are directories like `.lock/`, and a bare `specs/.errors.lock`
   path like `specs/.events.lock`) and `b_patterns` (matching regexes, following the existing
   `/\.lock/` directory-pattern precedent for the three new directories).
3. **Test fixtures**: update the embedded `.gitignore` heredoc in both
   `tests/test-deploy-orphans.sh` and `tests/test-deploy-propagation.sh` with the same four new
   patterns, in lockstep with step 1/2 — otherwise both harnesses newly fail via gate 14 the
   moment `check-runtime-file-tracking.sh`'s probes are widened.
4. **Consumer `.gitignore` (this repo)**: add `**/.deploy-lock/` and `**/.scope-lock/` (the two
   entries genuinely missing here; `.commit-lock/` and `.errors.lock` are already present).
   Consider — since it is the same section and a one-line, zero-risk addition — also adding
   `**/.dispatch/` if the plan phase agrees it's worth closing that specific same-file Class
   Table/gitignore-block contradiction while already editing this block for the four new
   entries; not required by ACCEPTANCE, but proportionate given it's the identical file/section.
5. **Untracking**: `specs/.deploy-lock/owner` requires no further action — it is already
   untracked and already absent from disk (commit `cf51ce8bb`, verified no deploy in flight at
   or since that commit). The ACCEPTANCE line about untracking via `git rm --cached` "at a
   moment when no deploy is in flight, with the on-disk file left intact" is satisfied
   in effect (nothing tracked, nothing on disk) but not in the *documented procedure* (a plain
   `git rm` was used instead of `--cached`, which happened to be harmless only because no deploy
   was live). Recommend the implementation phase note this explicitly rather than re-issue a
   redundant `git rm --cached` against a path that no longer exists, and flag the plain-`git rm`
   deviation for whoever reviews commit `cf51ce8bb`'s originating session. `.scope-lock/`,
   `.commit-lock/`, `.errors.lock` have never been tracked (confirmed via `git ls-files`), so no
   untracking action is needed for them — only the ignore-list and lint-coverage fixes.
6. **Scope (d) — single source**: precedent exists for the *script-pair* half of this problem:
   `scripts/lib/task-reference-patterns.sh` is `source`d by both `check-task-references.sh` and
   `hooks/validate-no-task-references.sh` specifically so the two never drift (see
   `rules/no-task-references-in-deliverables.md`'s own citation of this file as "the mechanical
   source of truth"). The same shape applies cleanly to `check-runtime-file-tracking.sh`'s two
   internal lists (`EPHEMERAL_PROBES` and `b_patterns` could both be derived from one array in a
   new `scripts/lib/runtime-file-patterns.sh`, closing the risk that a future addition updates
   Check A's probes but not Check B's regexes, or vice versa — note this is a **real, already-
   demonstrated risk**: today's `EPHEMERAL_PROBES` and `b_patterns` are not 1:1 by construction
   despite covering the same 11 items, they just happen to agree by discipline). The markdown
   "Consumer Repo Setup" block is a different kind of artifact (hand-pasted prose, not sourced
   code) and cannot mechanically `source` that lib; recommend the plan decide between (i) a
   lightweight doc-sync check (in the spirit of `check-extension-docs.sh`'s existing drift
   detection for other doc/script pairs in this repo) that asserts the fenced block's pattern
   set matches the lib's array, or (ii) accepting the dispatch's documented fallback — an
   explicit cross-reference comment at each of the three sites pointing at the other two — if a
   full doc-sync check is judged disproportionate for a fenced markdown block. Either choice
   satisfies scope (d)'s "decide and record."
7. **Shellcheck**: `check-runtime-file-tracking.sh` currently has one pre-existing shellcheck
   finding unrelated to this task (`SC2034`, unused `YELLOW`). Since ACCEPTANCE requires
   "shellcheck clean," the plan should either remove the unused `YELLOW` declaration or wire it
   into an actual color use (check whether any planned new FAIL/WARN line should use yellow for
   a "borderline" state) — deferring this pre-existing warning risks an accidental
   acceptance-criterion failure that looks like it was caused by this task's edits when it
   predates them.

## Decisions

- Treat `.scope-lock/`, `.commit-lock/`, `.errors.lock` as in-scope "further gaps found" under
  scope item (c), on the strength of `task-lock.sh`'s own comments explicitly naming
  `.scope-lock/`/`.commit-lock/` as siblings of the already-covered `.lock/` mechanism, and
  `.errors.lock`'s direct structural identity with the already-covered `.events.lock` (same
  `flock`-guard shape, sibling append-only store).
- Treat `specs/.eager-context-snapshot-*.json` as a documented exclusion candidate, not a fix —
  it does not match the "read back with no freshness gate" hazard the whole class exists to
  guard against, and no instance of the file exists in the repo today.
- Treat the six other already-gitignored-but-standards-undocumented patterns
  (`.dispatch/`, `.postflight-pending`, the `.stale-*`/`.exhausted-*` trio,
  `.git-snapshot-marker`, `untracked-backup-*/`) as out of this task's scope except optionally
  `.dispatch/`, which is a same-file, same-section, already-tabled internal contradiction the
  plan may choose to close opportunistically; the rest already live correctly in
  `.gitignore` and are documented in other standards files, so folding them in here would exceed
  ACCEPTANCE without a corresponding live-proof justification the way `.deploy-lock/` has.
- Do not attempt to re-run `git rm --cached` against `specs/.deploy-lock/owner` — it no longer
  exists in the index or on disk; document the already-completed (if procedurally imperfect)
  untracking instead.

## Risks & Mitigations

- **Risk**: widening `check-runtime-file-tracking.sh`'s probes without updating
  `test-deploy-orphans.sh` / `test-deploy-propagation.sh`'s embedded `.gitignore` breaks both
  tests. **Mitigation**: update both fixtures in the same change; re-run both test scripts (they
  invoke a real headless deploy, so this is a genuine end-to-end check, not just a lint pass) to
  confirm still green after the change — the dispatch's ACCEPTANCE bar ("demonstrated, not
  asserted") applies equally well here.
- **Risk**: task 51 (not yet started) will later relocate these same session-scoped runtime
  files and rewrite the same three enumerations, potentially reintroducing or restructuring the
  gaps this task closes. **Mitigation**: none needed now since task 51 is `not_started` — task
  201 lands first per the dispatch's own footprint-note logic; no action required beyond what
  the footprint note itself already prescribes for whichever task lands second (not this one).
- **Risk**: adding new Class Table rows and gitignore-block entries by hand, in three separate
  files, without the scope-(d) single-source mechanism, reproduces exactly the kind of
  independent-drift defect this task is fixing. **Mitigation**: scope (d)'s recommendation
  above (shared lib for the two script-internal lists at minimum; explicit decision-and-record
  either way for the markdown block) directly addresses this.

## Context Extension Recommendations

- **Topic**: shellcheck baseline state of `agent-system/extensions/core/scripts/*.sh`.
- **Gap**: no existing context file records which scripts have pre-existing, accepted
  shellcheck findings (like `check-runtime-file-tracking.sh`'s `SC2034`) versus which are
  expected to be fully clean. A task that touches a script and is told "shellcheck clean" has no
  way to know in advance whether that means "clean as a whole file" or "clean relative to a
  pre-existing baseline."
- **Recommendation**: not urgent enough to justify a new context file for this one task; note
  for a future `/meta` pass if this ambiguity recurs across other shellcheck-gated tasks.

## Appendix

### Search queries / commands used

- `grep -n "Consumer Repo Setup" -A 60 .../orchestrator-runtime-files.md`
- `grep -n -i "lock\|mutex\|.sessions\|commit-lock\|deploy-lock\|task-lock" .../orchestrator-runtime-files.md`
- `sed -n '25,60p' / '272,330p' .../orchestrator-runtime-files.md` (Class Table, Consumer Repo Setup)
- `grep -n "deploy-lock\|DEPLOY_LOCK" .../deploy-headless.sh`
- `grep -n "commit-lock\|COMMIT_LOCK" .../git-commit-scoped.sh`
- `grep -n "specs/\.|\.lock\b" .../task-lock.sh`
- `grep -rn "errors\.lock" .../errors-append.sh`
- `sed -n '1,120p' / '120,150p' .../check-runtime-file-tracking.sh` (EPHEMERAL_PROBES, b_patterns, Check C)
- `grep -rln "EPHEMERAL_PROBES\|b_patterns\|check-runtime-file-tracking"` (found the two test fixtures)
- `sed -n '60,110p' tests/test-deploy-orphans.sh`, `sed -n '85,115p' tests/test-deploy-propagation.sh`
- `git log --oneline --all -- specs/.deploy-lock`, `git show cf51ce8bb --stat`, `git log -1 --format="%ci" cf51ce8bb`
- `ps aux | grep -i "deploy-headless"` (confirmed no live deploy at research time)
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (live PASS, demonstrating current blindness)
- `grep -rhoE 'specs/\.[A-Za-z0-9_-]+' agent-system/extensions/*/scripts/**/*.sh | sort -u` (full sweep for scope (c))
- `grep -n "eager-context-snapshot" ...`, `sed -n '1,40p'/'100,140p' measure-eager-context.sh`
- `jq -r '.active_projects[] | select(.project_number==51)' specs/state.json` (task 51 status check)
- `shellcheck agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` (pre-existing SC2034)
- `diff .claude/... agent-system/extensions/core/...` (confirmed deployed copies already in sync with source store for both target files)

### References

- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh`
- `agent-system/extensions/core/scripts/tests/test-deploy-propagation.sh`
- `agent-system/extensions/core/scripts/deploy-headless.sh`
- `agent-system/extensions/core/scripts/task-lock.sh`
- `agent-system/extensions/core/scripts/errors-append.sh`
- `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` (single-source precedent)
- `agent-system/extensions/core/scripts/measure-eager-context.sh`
- `.gitignore` (repo root)
- Commit `96fb00a40e872f7226c434e481309ef9ef0198fe` (the live-proof tracked commit)
- Commit `cf51ce8bb04b582fbcccc3d318a648abc2657d90` (the already-performed, procedurally-imperfect untrack)
