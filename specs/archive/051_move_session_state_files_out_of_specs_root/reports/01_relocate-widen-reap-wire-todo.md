# Research Report: Task #51

**Task**: 51 - Move session runtime files out of the specs root and make the reap path run
**Started**: 2026-09-29T22:50:00Z
**Completed**: 2026-09-29T23:20:00Z
**Effort**: Medium (Parts 2+3 are small/contained; Part 1 is large and mostly out-of-scope)
**Dependencies**: Task 143 (completed, archived), Task 209 (completed, archived) — both
foundational (dispatch_seq/handoff gating and `init-specs.sh`/runtime-ignore-lib respectively);
neither blocks this task.
**Sources/Inputs**: Codebase (agent-system/extensions/core source store), live repo measurement
(`specs/` root file census, `git ls-files`, `git check-ignore`, `check-runtime-file-tracking.sh`
run)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The gitignore side is already correct and complete.** `scripts/lib/runtime-file-patterns.sh`'s
  `**/.orchestrator-multi-state*.json` and `**/.return-meta-*.json` glob patterns (bash-glob
  semantics, not literal-hyphen matching) already cover ALL THREE "superseded naming
  generations" named in the task (un-suffixed, dot-separator, `.prev-` variant) — verified by
  direct pattern reasoning and by `check-runtime-file-tracking.sh` passing all three checks
  clean right now. **The defect is entirely in `reap-session-runtime-files.sh`'s own literal
  bash-array glob** (`specs/.orchestrator-multi-state-*.json`, requiring a literal hyphen), which
  is narrower than the gitignore pattern it was modeled on. This narrows Part (2) to a one-file
  fix, fully inside the declared `file_scope`.
- **Part (3) (wiring reap into `/todo`) is fully achievable inside the declared `file_scope`.**
  `skill-refresh/SKILL.md` Steps 4.5/4.6 are an exact, ready-to-port reference implementation for
  both required calls (`reap-session-runtime-files.sh` and `task-lock.sh session-reap`), and
  `skill-todo/SKILL.md`'s stage numbering (`<stage id="N" name="...">`) confirms the suggested
  hook point is real and available: Stages 11-14 sit between Stage 10 (`ArchiveTasks`) and Stage
  15 (`GitCommit`), and the full stage pipeline runs on every non-`--dry-run` invocation
  regardless of whether any task was actually archived — exactly the "runs far more often, runs
  unconditionally" property the task needs.
- **Part (1) (relocation) is NOT achievable inside the declared `file_scope`.** The actual
  writers of `specs/.orchestrator-multi-state-{sid}.json` / `specs/.return-meta-multi-{sid}.json`
  live in `skills/skill-orchestrate/SKILL.md`, `scripts/orchestrate-cycle-plan.sh`,
  `scripts/orchestrate-cycle-postflight.sh`, and `scripts/orchestrate-unwind-dispatch.sh` — none
  of which are in this task's `file_scope` (and three of the four sit inside task 265's declared
  `file_scope` for a *different* task dispatched this same cycle, or are otherwise untouched by
  any concurrent sibling — see Territory Conflict note below). See `proposed_file_scope` in the
  returned metadata for the precise touch-list if the plan chooses to do Part 1 this round.
- **New finding, not named in the task text**: `specs/.meta-return-sess_1790273700_meta01.json`
  is a **currently git-tracked** (`git ls-files` hit, committed at `a38456608`/`f3bded704`, clean
  against HEAD) file of the fully-orphaned "meta-return" naming class the task calls out (it
  names only the bare `.meta-return.json`, already removed). This suffixed sibling was never
  caught because "meta-return" has never been one of the 18 canonical class members in
  `runtime-file-patterns.sh`, so `check-runtime-file-tracking.sh`'s Check B does not scan for it
  at all — a coverage gap, not merely a stale-file gap.
- **Recommendation**: plan Parts 2+3 as the primary, fully-in-scope deliverable (matching the
  task's own "acceptance-critical" framing of Part 3), and treat Part 1 (relocation) either as a
  scope-widened sub-phase of this same round (via the `proposed_file_scope` below) or as an
  explicitly deferred follow-up — do not silently drop it without saying so, since the task
  description still names it as in-scope.

## Context & Scope

Task 51 has three parts: (1) relocate `specs/.orchestrator-multi-state-{sid}.json` and
`specs/.return-meta-multi-{sid}.json` out of the `specs/` root; (2) close the reaper's glob
coverage gap across four naming generations plus three fully-orphaned shapes; (3) wire the
existing, working reaper into `/todo` (the task's own evidence: the reaper cleared 41/41 files on
first run, but nothing calls it except a manual `/refresh`, so litter grows unbounded — 25 -> 48
-> 67 -> 73 stranded files in this repo alone across three measurements between 2026-09-08 and
today). The task explicitly ranks part (3) as "the acceptance-critical deliverable, not... the
third of three equals."

This research measured the *current, live* state of this repo (not just read the task's
evidence-refresh prose) to confirm every claim before recommending an implementation path, and
traced every writer/reader/doc-mention of the two singleton files to determine the true blast
radius of Part 1 against the task's actually-declared `file_scope`.

## Findings

### Codebase Patterns

**Live litter census (this repo, right now)**: 73 stranded files at `specs/` root — 40
`.orchestrator-multi-state-sess_*.json`, 32 `.return-meta-multi-sess_*.json`, and 1
`.meta-return-sess_1790273700_meta01.json` (oldest: 2026-09-07). Zero instances of the
un-suffixed, dot-separator, or `.prev-` naming generations exist in this repo today — those were
observed in the *other* four affected repos (BimodalLogic, cslib, ModelChecker, PersonalWebsite),
consistent with the task's "affected repos" list. All 73 files are correctly gitignored already
(`specs/.gitignore`'s managed block, generated by `init-specs.sh` from
`runtime_specs_ignore_block()`) — confirmed they never appear in `git status --porcelain`. The
growth is a pure filesystem-litter problem, not a git-tracking problem, which is exactly why
`check-runtime-file-tracking.sh` reports all-green even as the count climbs.

**Part 2 root cause, precisely located**: `runtime-file-patterns.sh`'s canonical gitignore
pattern `**/.orchestrator-multi-state*.json` uses shell-glob `*` (zero-or-more, no literal
character required), so it already matches all four shapes named in the task: bare
`.orchestrator-multi-state.json`, hyphen-suffixed (current) `.orchestrator-multi-state-{sid}.json`,
dot-separator `.orchestrator-multi-state.{sid}.json`, and `.prev-` `.orchestrator-multi-state.prev-{sid}.json`.
Same reasoning applies to `**/.return-meta-*.json` for the return-meta-multi family, and this
pattern *also* already covers `.return-meta-meta.json` / `.return-meta-meta-sess_{sid}.json` (both
start with `.return-meta-`). Only `.meta-return.json` (reversed word order) falls outside every
existing pattern — see the new-orphan finding below.

By contrast, `scripts/reap-session-runtime-files.sh`'s own candidate array
(`"$PROJECT_ROOT"/specs/.orchestrator-multi-state-*.json "$PROJECT_ROOT"/specs/.return-meta-multi-*.json`)
is a literal bash pathname-expansion glob requiring the literal substring `-multi-` /
`-state-` immediately before the wildcard. It does **not** match bare, dot-separator, or `.prev-`
`.orchestrator-multi-state...json`, nor bare `.return-meta-multi.json` (no writer for any of
these exists today — confirmed by grep across `agent-system/` and `.claude/` for every literal
shape; the current, sole live writer path in `skill-orchestrate/SKILL.md`,
`orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, and `orchestrate-unwind-dispatch.sh`
always uses the hyphen-suffixed, session_id-bearing form). **Fix**: widen this one script's
candidate array to the same four shapes the gitignore pattern already tolerates — this is a
one-file change fully inside `file_scope` (`agent-system/extensions/core/scripts/reap-session-runtime-files.sh`).
Recommend widening the glob (defensive, permanent, cheap) rather than a separate one-shot
migration script, since the existing gitignore coverage means no new tracking risk is introduced
by widening, and it protects every consumer repo (not just a one-time sweep of this one).

**The three fully-orphaned shapes** (`.return-meta-meta.json`, `.return-meta-meta-sess_{sid}.json`,
`.meta-return.json`) have zero writer and zero reader anywhere in `agent-system/` or `.claude/`
today — confirmed by exhaustive grep. None currently exist on disk in this repo except the
`.meta-return-sess_*.json` sibling below. Recommend a **one-shot cleanup** (delete any existing
stragglers across the five affected repos) rather than permanent reap-glob coverage, since with
zero live writer there is no ongoing accumulation risk to guard against — permanent glob entries
for a dead naming convention are needless surface area. (`.return-meta-meta*.json` is already
gitignore-covered incidentally by the `return-meta-suffixed` pattern; only `.meta-return.json`'s
reversed word order falls outside all patterns.)

**New finding — a currently tracked, currently undetected orphan**:
`specs/.meta-return-sess_1790273700_meta01.json` is tracked by git right now (`git ls-files` hit,
`git status --porcelain` empty against it, committed in `a38456608`/`f3bded704` — a `/meta` task-
creation flow's old return-file convention, since retired from `skill-meta/SKILL.md`, whose
current version writes no such file). Its content also uses `"status": "completed"` for a
skill-status field — the exact forbidden value `return-metadata-file.md` calls out (`"Never use
'completed' - it triggers Claude stop behavior"`), further evidence this is a genuinely dead,
pre-convention artifact, not a live schema. Because "meta-return" (word order: meta before
return) has never been one of the 18 canonical members in `runtime-file-patterns.sh`,
`check-runtime-file-tracking.sh`'s Check B never scans for it — running the check live confirms a
clean PASS despite this tracked file's existence. This is a **coverage gap** in the verification
tooling itself, not just a leftover file, and should be remediated with `git rm --cached` (not
`rm -f`, since deleting the working-tree copy alone would leave it staged-for-deletion,
uncommitted) plus a decision on whether "meta-return" is worth adding as a 19th class member or
handled purely as a one-shot untrack-and-delete.

### Part 3: wiring reap into `/todo` — a ready-made reference implementation exists

`skill-refresh/SKILL.md` already implements exactly the two calls Part 3 asks for, as Steps 4.5
and 4.6 (lines 207-263), immediately following Step 4's `task-lock.sh reap` (stale task `.lock`
dirs):

- **Step 4.5** (`Reap Stale Session-Scoped Orchestration Files`): calls
  `reap-session-runtime-files.sh` (or `--dry-run`), echoing its output verbatim, gated on the
  same `dry_run` boolean already parsed by that skill's Step 1.
- **Step 4.6** (`Reap Stale Session Registry Entries`): calls `task-lock.sh session-reap` (or
  `--dry-run`), echoing its output verbatim.

Both are non-interactive, threshold-only (`ORCHESTRATOR_SESSION_REAP_MIN`, default 240 min;
`SESSION_REGISTRY_REAP_MIN`, default 240 min — both already satisfy the task's "honor the
existing threshold" requirement with zero code change needed), and run only on explicit
invocation (never on `/refresh`'s hourly `claude-refresh.timer` cadence, which is `--dry-run`
only). This is a direct, portable template for `/todo`.

`skill-todo/SKILL.md` uses `<stage id="N" name="...">` tags (not markdown headers — a `grep
"^###"` search finds nothing; `grep "<stage id="` finds all 17). The stage list confirms the
task's suggested hook point is real: `<stage id="10" name="ArchiveTasks" checkpoint=...>`
(line 434) through `<stage id="15" name="GitCommit">` (line 977), with Stages 11
(`UpdateRoadmap`), 12 (`UpdateREADME`), 13 (`UpdateChangelog`), 14 (`CreateMemories`) in between.
Stage 8 (`DryRunOutput`) is the **only** early-exit point (`dry_run = true` -> display preview,
"Exit after display") — every non-dry-run invocation falls through Stages 9 through 16
unconditionally, including when `archivable_tasks[]` is empty (Stage 10's loop is naturally
zero-iteration-safe). This confirms a new stage inserted between 10 and 15 — e.g. `<stage
id="14.5" name="ReapRuntimeFiles">` — runs on every live `/todo` call regardless of archival
volume, matching the task's premise that `/todo`'s *frequency* (not its archival action) is what
makes it the right trigger. `--dry-run` mode naturally skips the new stage too, exactly mirroring
Stage 10's own archival execution not running under `--dry-run` — no special-casing needed.

Stage 15 (`GitCommit`)'s existing staging is a **fixed, explicit path list**
(`git add specs/archive/ specs/TODO.md specs/state.json` plus conditional
`CHANGE_LOG.md`/`ROADMAP.md`/`README.md`/`.memory/`), never a `specs/`-wide add — so under normal
operation the reap's deletions (all on already-gitignored paths) require **zero git interaction**
and land in no commit at all, which is the correct, cheap behavior. The task's phrase "so reaped
paths land in the same commit" is best read as sequencing (report the reap alongside the
archival summary in one `/todo` invocation), not a literal git-staging requirement — except for
the edge case above, where a stray tracked file needs `git rm --cached` and *would* need to ride
the same Stage 15 commit if the plan chooses to remediate it there.

Stage 16 (`OutputResults`) has a well-defined bullet-list summary format (archived counts,
deferred, directory ops, roadmap/readme/changelog updates, memory harvest, active tasks
remaining) that a new "Runtime file reap" bullet slots into cleanly, following the same
verbatim-echo convention Step 4/4.5/4.6 already establish in `skill-refresh/SKILL.md`.

`commands/todo.md` (the user-facing doc, 1077 lines) mirrors `skill-todo/SKILL.md` in prose and
will need a parallel documentation update, matching how `commands/refresh.md` documents its own
Steps 4/4.5/4.6 in three short subsections ("Stale Task Locks" implied, "Stale Session-Scoped
Orchestration Files", "Stale Session Registry Entries" — lines 140-180) — a direct template to
adapt.

### Part 1: relocation — full blast radius, mostly outside `file_scope`

The task's declared `file_scope` for task 51 is:
```
agent-system/extensions/core/scripts/reap-session-runtime-files.sh
agent-system/extensions/core/scripts/task-lock.sh
agent-system/extensions/core/skills/skill-todo/
agent-system/extensions/core/context/standards/orchestrator-runtime-files.md
agent-system/extensions/core/scripts/check-runtime-file-tracking.sh
```

This fully covers Parts 2 and 3. It does **not** cover any of the actual **writers** of the two
singleton files, which is where relocation's real work is:

| File | Role | In `file_scope`? |
|------|------|-------------------|
| `skills/skill-orchestrate/SKILL.md` (~line 92: `mt_state_file=`; ~line 269: `.return-meta-multi-${session_id}.json` write) | Writer (both files) | No |
| `scripts/orchestrate-cycle-plan.sh` (~line 495: `mt_state_file=`) | Writer/reader | No |
| `scripts/orchestrate-cycle-postflight.sh` (~line 317: `mt_state_file=`) | Writer/reader | No |
| `scripts/orchestrate-unwind-dispatch.sh` (~line 300: `mt_state_file=`) | Reader | No |
| `scripts/lib/runtime-file-patterns.sh` | Canonical pattern/probe lib | No (likely **no change needed** — see below) |
| `commands/refresh.md`, `commands/orchestrate.md`, `docs/architecture/orchestrate-state-machine.md`, `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/orchestrate-batch-results-template.md`, `context/formats/return-metadata-file.md`, `skills/skill-refresh/SKILL.md` | Prose path mentions | No |
| `scripts/test-session-runtime-files.sh` | Test fixture with literal paths | No |
| `scripts/reap-session-runtime-files.sh`, `context/standards/orchestrator-runtime-files.md`, `scripts/check-runtime-file-tracking.sh` | Reaper/docs/verification | **Yes** |

**One favorable technical detail narrows the blast radius**: every gitignore pattern involved
(`**/.orchestrator-multi-state*.json`, `**/.return-meta-*.json`) is `**/`-prefixed, which matches
at *any* depth — so relocating the files into a new subdirectory (e.g.
`specs/.orchestration/.orchestrator-multi-state-{sid}.json`, mirroring the existing
`specs/.sessions/{session_id}.json` precedent already in the codebase for the session registry)
while keeping the **same basename** requires **no change** to `runtime-file-patterns.sh`'s
patterns, and (by the same reasoning) likely no change to `check-runtime-file-tracking.sh`'s
probe paths either, since `git check-ignore -q` on any path with a matching basename succeeds
regardless of the specific directory chosen for the probe. This means the lib and the
verification script are probably no-ops for a same-basename relocation — the real cost is
entirely in updating the four writer/reader code sites plus the ~7 doc-only mentions and one test
fixture, none of which this task's `file_scope` reaches.

**Territory note**: sibling task 265 (concurrently dispatched this cycle) declares `file_scope`
including `scripts/orchestrate-cycle-plan.sh` and `docs/architecture/orchestrate-state-machine.md`
— two of the exact files Part 1's relocation would need to touch. Any plan that widens task 51's
scope to include Part 1 this round should check task 265's live status before touching either
file, per the territory contract (re-read immediately before editing, stage only this task's own
hunks).

## Decisions

- Recommend fixing Part 2 by widening `reap-session-runtime-files.sh`'s own candidate glob array
  to the four `.orchestrator-multi-state`/`.return-meta-multi` naming generations (not a
  migration script), since the gitignore side already tolerates all four and no live writer
  produces the three superseded shapes any more.
- Recommend treating the three fully-dead orphans (`.return-meta-meta.json`,
  `.return-meta-meta-sess_{sid}.json`, `.meta-return.json`) plus the newly-found tracked
  `.meta-return-sess_1790273700_meta01.json` sibling as a one-shot cleanup
  (`git rm --cached` for the tracked one, `rm -f` for any untracked stragglers in other repos),
  not a permanent reap/gitignore addition, given zero live writer.
- Recommend Part 3 be implemented by porting `skill-refresh/SKILL.md` Steps 4.5/4.6 verbatim into
  a new `skill-todo/SKILL.md` stage between Stage 10 (`ArchiveTasks`) and Stage 15 (`GitCommit`)
  — e.g. `<stage id="14.5" name="ReapRuntimeFiles">` — plus a Stage 16 summary bullet and a
  `commands/todo.md` documentation update mirroring `commands/refresh.md`'s existing three
  subsections.
- Part 1 (relocation) should be explicitly ruled on by the plan rather than silently dropped: either
  request the `file_scope` widening named in `proposed_file_scope` below and do it this round
  (checking task 265's live status on the two overlapping files first), or explicitly defer it to
  a follow-up task/round and say so in the plan, consistent with the task's own "acceptance-
  critical" framing that ranks Part 3 above Parts 1/2.

## Risks & Mitigations

- **Risk**: doing Part 1 without widening `file_scope` would require editing files no
  concurrent-dispatch guard authorizes, and risks colliding with sibling task 265's declared
  territory on two files. **Mitigation**: use `proposed_file_scope` (below) to make the ask
  explicit to the planner/orchestrator rather than editing out-of-scope files silently.
- **Risk**: the tracked `.meta-return-sess_1790273700_meta01.json` file needs `git rm --cached`,
  not a plain filesystem delete, or it will reappear as a staged deletion needing its own commit.
  **Mitigation**: call this out explicitly in the plan/implementation phase rather than treating
  it identically to the untracked litter.
- **Risk**: a new `/todo` reap stage that is not gated identically to `skill-refresh`'s
  `dry_run` boolean could accidentally reap during a `/todo --dry-run` preview or during an
  in-flight batch run. **Mitigation**: reuse the exact `dry_run` boolean already parsed by
  `skill-todo/SKILL.md` Stage 1, and rely on the pre-existing `ORCHESTRATOR_SESSION_REAP_MIN`/
  `SESSION_REGISTRY_REAP_MIN` thresholds unchanged — no new threshold logic needed.

## Context Extension Recommendations

- **Topic**: `check-runtime-file-tracking.sh` coverage gap for non-canonical dead-convention
  litter (e.g. `.meta-return-sess_*.json`).
- **Gap**: `orchestrator-runtime-files.md`'s Class Table and the 18-member lib have no entry for
  fully-orphaned, zero-writer historical conventions that were nonetheless committed to git
  before being retired — Check B only scans the 18 canonical members, so a tracked file of a
  dead, unlisted convention passes silently.
- **Recommendation**: either add a narrow 19th "known-dead-convention" class to the lib purely
  for Check B tracking detection (no gitignore pattern needed, since it will never be written
  again), or note in `orchestrator-runtime-files.md` that a retired convention's litter must be
  hunted down manually via `git log --all --diff-filter=A -- '**/.{old-name}*'` rather than relying
  on the automated check.

## Appendix

### Search queries / commands used

- `jq` queries against `specs/state.json` for task 51's own entry, `file_scope`, and dependencies
  143/209 (both completed and archived: `mt_handoff_staleness_and_dispatch_seq_gates`,
  `init_consumer_specs_and_runtime_ignores`).
- `grep -rn "orchestrator-multi-state"` / `"return-meta-multi"` / `"meta-return"` /
  `"return-meta-meta"` across `agent-system/extensions/core/` to enumerate every writer, reader,
  and doc mention.
- Live census: `ls -la specs/`, counted by shape (`.orchestrator-multi-state-*.json` = 40,
  `.return-meta-multi-*.json` = 32, `.meta-return-sess_*.json` = 1; zero bare/dot-separator/`.prev-`
  instances in this repo).
- `git status --porcelain`, `git check-ignore -v`, `git ls-files`, `git log --oneline --all --`,
  `git diff HEAD --` against `specs/.meta-return-sess_1790273700_meta01.json` to establish it is
  tracked, unmodified against HEAD, and committed in `a38456608`/`f3bded704`.
- `bash agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` — live run, all
  three checks pass clean despite the tracked orphan (confirms the coverage-gap finding).
- Read in full: `scripts/reap-session-runtime-files.sh`, `scripts/lib/runtime-file-patterns.sh`,
  `context/standards/orchestrator-runtime-files.md`, `scripts/check-runtime-file-tracking.sh`,
  relevant sections of `skills/skill-todo/SKILL.md` (stage list + Stages 3, 8, 9, 14, 15, 16),
  `skills/skill-refresh/SKILL.md` (Steps 4-4.6), `commands/refresh.md` (reap documentation
  sections), `commands/todo.md` (header/structure).

### Reference

- `agent-system/extensions/core/scripts/reap-session-runtime-files.sh`
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
- `agent-system/extensions/core/skills/skill-todo/SKILL.md`
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/commands/refresh.md`
- `agent-system/extensions/core/commands/todo.md`
- `agent-system/extensions/core/scripts/task-lock.sh`
