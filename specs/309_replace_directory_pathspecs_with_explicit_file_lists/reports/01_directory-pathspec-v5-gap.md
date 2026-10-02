# Research Report: Task #309

**Task**: 309 - Replace directory pathspecs with explicit file lists at the three task-commit sites
**Started**: 2026-10-02T00:00:00Z
**Completed**: 2026-10-02T00:00:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase (`agent-system/extensions/core/scripts/git-commit-scoped.sh`, `hooks/guard-destructive-git.sh`, `scripts/orchestrate-cycle-plan.sh`, `context/reference/orchestrator-critical-paths.json`)
- `specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
- `specs/decisions/worktree-isolation-removal-reaffirmation.md`
- Full-tree grep across `agent-system/extensions/`
**Artifacts**:
- `specs/309_replace_directory_pathspecs_with_explicit_file_lists/reports/01_directory-pathspec-v5-gap.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **V5 confirmed to slip past a directory pathspec, by exact-string-equality design, and the
  three named call sites don't even invoke V5 in the first place.** `git-commit-scoped.sh`'s V5
  check (`git-commit-scoped.sh:239`) tests `jq ... '.contended // [] | any(.path == $p)'` — a
  literal string match between the caller's own pathspec token and a manifest `.path` entry. A
  bare `specs/` token can never equal a specific file path, so it can never trip V5 even if
  `--task` were passed. None of the three named call sites (nor most other `-- specs/` sites
  found below) pass `--task` at all, so V5 is not merely bypassed by this pattern — it is never
  consulted for these commits today.
- **No layer in the stack defends against this pattern.** Three independent checks were read in
  full and all three pass a directory pathspec through unexamined: `guard-destructive-git.sh`'s
  directory/glob detector (matches only the literal substring `git add`, never present in a
  `bash .../git-commit-scoped.sh ... -- specs/` invocation); `git-commit-scoped.sh`'s own V2
  classification (an on-disk directory is "Case 1 — matched", staged exactly like a file); and
  V5 itself (above). This is a three-layer gap, not a one-line oversight.
- **Scope correction (material): the dispatch's "three commit recipes" undercounts the actual
  footprint by more than 5x.** A full-tree grep for the literal trailing pathspec `-- specs/`
  found **17 occurrences across 3 extensions** (core: 12, epidemiology: 1, present: 4), not 3.
  All 17 are in the same hazard class as the three named sites. See Findings for the full list.
- **Widening fix scope to cover all 17 would not trip the self-modification admission gate.**
  None of the 17 files (nor a plausible new lint script/test) appear in
  `context/reference/orchestrator-critical-paths.json`'s `critical_paths` list — confirmed by
  reading the file directly. The SCOPE NOTE's "do not widen file_scope to include any critical
  path" constraint is satisfied regardless of whether the plan fixes 3 or all 17.
- **The existing `lint-scoped-commit-boundary.sh` cannot be reused unmodified for the new
  regression check** — it explicitly treats "ends in a trailing `-- <pathspec>`" as the
  *compliant* shape (that's its whole point: catching a bare `git commit` with no pathspec at
  all). A directory-shaped pathspec IS a trailing `-- <pathspec>`, so this lint's own classifier
  would mark every one of the 17 violation lines EXEMPT. A new, separate lint is required.

## Context & Scope

The task names three commit recipes that pass a bare `-- specs/` directory pathspec to
`git-commit-scoped.sh`: `skills/skill-git-workflow/SKILL.md:216`, `agents/meta-builder-agent.md:1496`,
and `skills/skill-meta/SKILL.md:287`. The stated hazard is the mode-1b bleed finding from
`specs/301_.../reports/02_worktree-isolation-reopened.md`: under concurrent `/orchestrate`
sessions sharing one working tree, a directory pathspec sweeps a sibling's in-progress,
uncommitted `specs/` artifact writes into the committing session's commit.

Two things were explicitly required before any remedy: (1) verify by reading code, not
assuming, whether `git-commit-scoped.sh`'s V5 per-path contention-claim check matches a
directory pathspec entry; (2) stay inside the declared `file_scope`
(`agent-system/extensions/core/skills/skill-git-workflow/SKILL.md`,
`agent-system/extensions/core/agents/meta-builder-agent.md`,
`agent-system/extensions/core/skills/skill-meta/SKILL.md` — confirmed via `specs/state.json`)
and never touch an orchestrator-critical-path file. This report additionally surfaces a
scope-accuracy finding (far more than three sites exist) that the planning phase needs to
resolve explicitly, since it changes the diff footprint by an order of magnitude.

## Findings

### Codebase Patterns

**1. V5's matching mechanism — exact string equality against `file_scope`-derived paths.**

`git-commit-scoped.sh:229-267` (the `--task`-opt-in contended-path check):

```bash
jq -e --arg p "$p" '.contended // [] | any(.path == $p)' "$manifest_file"
```

`$p` is the caller's own positive pathspec token, taken verbatim from the `-- <pathspec>...`
argument list (`git-commit-scoped.sh:234`, iterating `"${pathspecs[@]}"`). There is no prefix,
glob, or directory-containment test anywhere in this loop — only `==`. A token `specs/` will
never equal a manifest entry like `agent-system/extensions/core/scripts/foo.sh` or even a
specific `specs/{NNN}_{slug}/reports/bar.md` file path. **Confirmed: a directory pathspec slips
past V5 unconditionally, by construction, regardless of what the manifest contains.**

A second, independent reason V5 is irrelevant to these three (and the other 14 found) sites:
`orchestrate-cycle-plan.sh:build_contended_manifest` (lines 2247-2345) populates the manifest
exclusively from each concurrently-dispatched task's own `file_scope` array — i.e. source-store
paths a task declared it would edit. `specs/` artifact paths (the actual mode-1b casualty) are
essentially never declared in any task's `file_scope` (`file_scope` describes code/doc inputs
under edit, not the task's own output directory), so even a byte-for-byte file-path match would
rarely find anything to refuse on. The manifest mechanism and the mode-1b hazard are
structurally orthogonal; V5 was never going to be the fix for this class of bleed, with or
without the directory-pathspec defect.

Confirming the above is moot in practice for the three named sites: none of them pass `--task`
at all (`skill-git-workflow/SKILL.md:216`, `meta-builder-agent.md:1496`,
`skill-meta/SKILL.md:287` — all omit the flag), and `--task` is opt-in
(`git-commit-scoped.sh:14-27` header comment: "`--task <task_number>`: opt-in"). So V5 is not
merely ineffective here — **it is never invoked for these commits today.**

**2. The PreToolUse hook (`guard-destructive-git.sh`) also does not catch this pattern.**

Its directory/glob pathspec detector (`hooks/guard-destructive-git.sh:312-330`) explicitly
operates on the literal Bash command text, stripping a leading `git add` token before testing
each remaining token (`hooks/guard-destructive-git.sh:312-317`: "Strip the leading `git add`
... and test each remaining pathspec token"). None of the 17 call sites found below type
`git add` in the Bash tool invocation — they all type `bash .../git-commit-scoped.sh --message
... -- specs/`. The hook's own header already documents a related blind spot for quoted
pathspecs; this is the same class of blind spot, one level further removed: the hook has no
visibility into what a wrapper script does internally with an argument that was never typed as
`git add` at the call site.

**3. `git-commit-scoped.sh`'s own V2 classification does not special-case a directory either.**

`git-commit-scoped.sh:291-293`:
```bash
if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
  # Case 1 — matched: present on disk, or already tracked.
  filtered_pathspecs+=("$p"); add_pathspecs+=("$p")
```
`[ -e "$p" ]` is true for a directory exactly as it is for a file (bash's `-e` test does not
distinguish). A `specs/` token is therefore "Case 1 — matched" and flows straight into
`git add -- "${add_pathspecs[@]}"`, which recursively stages everything git considers modified
under `specs/`. There is no V-numbered gate anywhere in this script that rejects a
directory-shaped positive pathspec entry.

**Net conclusion on the research question**: the primitive (`git-commit-scoped.sh`) cannot
compensate for a wide call site, confirmed at all three layers that could plausibly have caught
it (PreToolUse hook, V2 classification, V5 contention check). This matches the dispatch's stated
expectation exactly, now backed by direct code citations rather than assumption.

### Scope-Accuracy Finding: 17 sites, not 3

A full-tree grep for the exact trailing pathspec `-- specs/` (the literal anti-pattern named in
the task) found 17 occurrences, not 3:

**Core (12)** — all under `agent-system/extensions/core/`:
| File | Line(s) | Recipe |
|---|---|---|
| `skills/skill-git-workflow/SKILL.md` | 216 | generic "Task Commit" (named in dispatch) |
| `agents/meta-builder-agent.md` | 1496 | Stage 6 (named in dispatch) |
| `skills/skill-meta/SKILL.md` | 287 | postflight commit block (named in dispatch) |
| `commands/task.md` | 259 | Step 7, task creation |
| `commands/task.md` | 893 | review/spawn follow-up-task commit |
| `commands/todo.md` | 993, 999, 1002, 1005, 1008, 1011, 1014 | Step 6 archival commit + 6 message-variant examples |

**Epidemiology (1)**: `agent-system/extensions/epidemiology/commands/epi.md:325` (Step 5, task creation)

**Present (4)**: `agent-system/extensions/present/commands/grant.md:223` (task creation),
`grant.md:476` (CHECKPOINT 2 revision commit), `slides.md:323` (Step 5, task creation),
`timeline.md:227` (task creation)

All 17 share the identical shape: `--message ... --session ... -- specs/` with zero `--task`
usage, i.e. the same unprotected mode-1b exposure as the three named sites — a concurrently
dispatched task's in-progress `specs/{N}_{slug}/` artifact writes can be swept into any of these
commits. The `todo.md` case is structurally different in intent (an archival commit is *meant*
to span many tasks' rows in one commit — see its own comment at `todo.md:983-985`, "This archival
operation legitimately spans many tasks' rows in one commit") but is not thereby exempt from the
mode-1b hazard: "spans many tasks' *committed* rows" and "sweeps in another session's
*uncommitted* in-flight writes" are different claims, and only an explicit file list (enumerating
`specs/TODO.md`, `specs/state.json`, and the specific archived task directories) distinguishes
them.

Related but distinct (not counted above, flagged for awareness only): several lean/founder/web/
epi/present recipes pass a **task-scoped** directory pathspec, e.g.
`-- "specs/${padded_num}_${project_name}/reports/"` (`skill-web-research/SKILL.md:201`,
`skill-founder-spreadsheet/SKILL.md:266`, and similarly in `skill-legal`, `skill-analyze`,
`skill-market`, `skill-meeting`, `skill-strategy`, `skill-financial-analysis`,
`skill-epi-research/SKILL.md:225`, `skill-lean-research/SKILL.md:218`,
`skill-lean-research-hard/SKILL.md:209`) or `-- "${task_dir}/" ...`
(`skill-founder-plan/SKILL.md:197`, `skill-consult/SKILL.md:201`,
`skill-deck-plan/SKILL.md:459`, `skill-slide-planning/SKILL.md:378`,
`skill-slide-critic/SKILL.md:439`, `skill-timeline/SKILL.md:319`, `skill-grant/SKILL.md:521`,
`founder-implement-agent.md:255,286,316,371,430`). These are narrower (confined to one task's own
directory, so a cross-TASK bleed is impossible) but still technically violate the "explicit file
list" rule and could in principle sweep an in-progress *intra-task* write (e.g. a partially
written summary in the same task's own `summaries/`). The dispatch's description and evidence
base are specific to the bare top-level `-- specs/` pattern (which spans every task, including
every other session's), so this report treats the task-scoped-directory pattern as out of scope
for this task and recommends it as a separate follow-up rather than folding it in here.

### Self-modification admission gate — confirmed non-trip for all 17

`context/reference/orchestrator-critical-paths.json`'s `critical_paths` array was read in full.
It lists 16 entries, all `scripts/*.sh`, `skills/skill-orchestrate/SKILL.md`,
`commands/orchestrate.md`, or `context/{patterns,reference}/*` self-reference files. None of the
17 files found above (`task.md`, `todo.md`, `epi.md`, `grant.md`, `slides.md`, `timeline.md`,
`meta-builder-agent.md`, `skill-git-workflow/SKILL.md`, `skill-meta/SKILL.md`), and no plausible
new lint script path under `scripts/lint/`, appears on that list. Notably, `git-commit-scoped.sh`
itself is also *not* on the critical-path list. Widening `file_scope` to cover all 17 sites (plus
a new lint script and its test) would not trip the self-modification admission gate — the SCOPE
NOTE's actual constraint ("do not widen file_scope to include any critical path") is satisfied at
either the 3-site or 17-site scope.

### External Resources

Not applicable — this is a pure source-store code-reading task; no external documentation was
consulted.

## Decisions

- **V5 does not, and structurally cannot, defend against a directory pathspec.** This is settled
  by direct code reading (three citations above), not inference. No further verification needed.
- **The existing `lint-scoped-commit-boundary.sh` is the wrong vehicle to extend for the new
  regression check.** Its Layer-1 classifier (`classify_line`) treats *any* line ending in a
  trailing `-- <pathspec>` as the compliant/exempt shape — exactly the shape every one of the 17
  violation lines has. Extending it would require inverting its own stated contract. A new,
  separate lint script (mirroring its file structure: broad candidate pattern, structural
  classifier, file-level allowlist, `--verbose`/`--quiet` flags, matching exit codes) is the
  correct design, paired with a new test file mirroring
  `tests/test-lint-scoped-commit-boundary.sh`'s both-polarity fixture model.
- **Scope of the fix (3 vs. 17 sites) is left to the planning phase** — this report documents the
  full, verified inventory and confirms widening is safe against the self-mod gate, but the
  choice between "fix the 3 named sites and allowlist the other 14 with inline justification" and
  "fix all 17 now" is a planning-time tradeoff (diff size vs. a regression lint that fails on day
  one), not a research-time one.

## Recommendations

1. **Fix the three named sites** (`skill-git-workflow/SKILL.md:216`, `meta-builder-agent.md:1496`,
   `skill-meta/SKILL.md:287`) by replacing `-- specs/` with an explicit file list naming exactly
   the files each recipe actually touches (at minimum `specs/TODO.md` and `specs/state.json`;
   each of these three recipes also touches a specific task directory's artifacts — enumerate
   those too, mirroring the already-correct pattern used by e.g.
   `skill-founder-plan/SKILL.md:197`: `-- "${task_dir}/" ...` is itself a directory and shares the
   same defect, so prefer `consult.md`'s own multi-file style or enumerate the concrete artifact
   paths the recipe just wrote).
2. **Decide explicitly on the other 14 sites** found in this report (9 more in core:
   `task.md` x2, `todo.md` x7; 5 in other extensions: `epi.md`, `grant.md` x2, `slides.md`,
   `timeline.md`). Recommend fixing all of them in this task or a tightly-scoped sibling, since
   the regression check in point 3 will otherwise fail immediately against 14 known violations
   the moment it is added — an allowlist-with-justification is the fallback if fixing all 14 is
   judged too large for this task's "small" effort estimate.
3. **Add a new, separate lint** (e.g. `scripts/lint/lint-directory-pathspec-boundary.sh`)
   detecting a bare-directory trailing pathspec passed to `git-commit-scoped.sh` — not an
   extension of `lint-scoped-commit-boundary.sh`, per the Decisions section above. Candidate
   detection shape: flag a `git-commit-scoped.sh` invocation (multi-line or single-line) whose
   final positive pathspec token matches a directory-only pattern (ends in `/` with no filename
   component, e.g. `specs/`, `"${task_dir}/"`, `"specs/${padded_num}_.../reports/"`), using the
   same two-layer model (broad candidate regex + structural classifier) as the existing lint, so
   a legitimately-quoted multi-file list (`-- a.md b.md`) is never flagged. Pair with a
   both-polarity fixture test mirroring `test-lint-scoped-commit-boundary.sh`.
4. **Do not attempt to fix this inside `git-commit-scoped.sh` itself as a substitute for fixing
   call sites** — several legitimate call sites intentionally pass a task-scoped directory today
   (the "related but distinct" list above), so a blanket internal rejection of any directory
   pathspec would break those sites too; that is a larger, separate redesign outside this task's
   SCOPE NOTE (`git-commit-scoped.sh` is not in `file_scope` and is not named in the task
   description).

## Context Extension Recommendations

- **Topic**: directory-pathspec anti-pattern detection
- **Gap**: `context/standards/git-staging-scope.md` documents the "under-stage, never
  over-stage" principle and `.claude/rules/git-workflow.md` already forbids a directory `git add`
  pathspec, but neither currently cross-references the specific `-- specs/`-to-`git-commit-
  scoped.sh` call-site pattern as a recurring instance of that same prohibition. Once the new
  lint from Recommendation 3 exists, consider a one-line cross-reference from
  `git-staging-scope.md` to it, mirroring how it already names `lint-scoped-commit-boundary.sh`.
- **Recommendation**: defer to the implementation phase; not a blocking gap for this task.

## Appendix

### Search queries used
- `grep -rn -- '-- specs/$' agent-system/extensions/` (primary inventory)
- `grep -n "V5|contention" agent-system/extensions/core/scripts/git-commit-scoped.sh`
- `grep -n "critical_path|CRITICAL_PATH" agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- Direct reads: `git-commit-scoped.sh` (full), `hooks/guard-destructive-git.sh` (targeted),
  `orchestrate-cycle-plan.sh:build_contended_manifest`,
  `context/reference/orchestrator-critical-paths.json` (full)

### References
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (lines 60-90 header, 212-267 V5,
  280-312 V2 classification)
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (lines 43-70, 299-330)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (lines 2247-2345)
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` (full)
- `agent-system/extensions/core/scripts/tests/test-lint-scoped-commit-boundary.sh` (header)
- `specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
- `specs/decisions/worktree-isolation-removal-reaffirmation.md`
- `specs/state.json` (task 309 entry: declared `file_scope`)
