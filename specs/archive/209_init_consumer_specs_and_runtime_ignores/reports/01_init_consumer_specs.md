# Research Report: Task #209

**Task**: 209 - Set up a fresh repo specs/ state and runtime-file ignore rules automatically
**Started**: 2026-09-17
**Completed**: 2026-09-17
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/**), live repo state (.gitignore, specs/state.json)
**Artifacts**: - specs/209_init_consumer_specs_and_runtime_ignores/reports/01_init_consumer_specs.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` is the canonical 16-member
  ephemeral-file class and already exports everything a new setup script needs
  (`runtime_ignore_block()`, `RUNTIME_FILE_B_REGEX`, `runtime_file_dir_basename_for_hit()`).
  `specs/tmp/` is confirmed missing from it (item d).
- `scripts/state-write.sh` has an `--init` mode built for "fresh-create" targets, but it
  **unconditionally refuses (exit 1) to target the default live `specs/state.json` path** — this
  is a hard, by-design guard, not an oversight. A new `init-specs.sh` cannot call
  `state-write.sh --init` against `specs/state.json`; it must write that file directly (with its
  own existence guard), while it **can** safely use `--init --state-file specs/archive/state.json`
  for the archive target (non-default path, exactly what `--init` was built for) provided the
  script still guards existence itself, since `--init` overwrites an existing target.
- `check-runtime-file-tracking.sh` Check B (tracked-ephemeral-file detection) **already fails
  independent of gitignore coverage** — it scans `git ls-files` directly. Item (h) in the dispatch
  appears to already be satisfied by code shipped 2026-09-09 (task 201), predating the task's
  2026-09-14 amendment. Check A already works with any applicable `.gitignore`, including a
  `specs/.gitignore`, since `git check-ignore -q` resolves ignore rules at every directory level —
  so item (f) is mostly a messaging/doc fix, not a logic change. Item (g) (untrack already-tracked
  files) is genuinely new work with no prior art.
- Five call sites independently read `next_project_number` from `specs/state.json` before task
  creation and are candidates for the new init call (item c): `commands/task.md` (primary),
  `commands/review.md`, `skills/skill-fix-it/SKILL.md`, `skills/skill-project-overview/SKILL.md`,
  `skills/skill-spawn/SKILL.md`, and `agents/meta-builder-agent.md`. `/orchestrate` and `/spawn`'s
  parent-task lookup both require a task to already exist in `specs/state.json`, so they are not
  realistic "first touch" sites, though `/orchestrate` was explicitly named in the dispatch.
- The `specs/tmp/claude-tts-notify.log` writer is confirmed:
  `agent-system/extensions/core/hooks/tts-notify.sh` and
  `agent-system/extensions/core/scripts/lifecycle-notify.sh`, both with
  `LOG_FILE="specs/tmp/claude-tts-notify.log"`. This repo's own root `.gitignore` already
  hand-carries `/specs/tmp` (root-relative, not `**/`-prefixed) as a precedent for the pattern
  form to add to the lib.

## Context & Scope

Researched the mechanics needed to implement all eight WORK items (a)-(h) in the dispatch: a new
idempotent `specs/` bootstrap script, `specs/.gitignore` generation from the existing
runtime-file-patterns lib, call-site wiring across every command/skill/agent that can be the first
to touch `specs/` in a fresh consumer repo, the missing `specs/tmp/` pattern, doc updates, and
check-script changes (both the pre-existing Check A/B and the new untrack step).

## Findings

### Codebase Patterns

**Canonical runtime-file list** (`agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`):
16 members, each with a parallel-array record: `RUNTIME_FILE_IDS`, `RUNTIME_FILE_PATTERNS` (the
`**/`-prefixed gitignore line), `RUNTIME_FILE_PROBES` (concrete `git check-ignore` target),
`RUNTIME_FILE_B_REGEX` (tracked-file grep pattern), `RUNTIME_FILE_IS_DIR` /
`RUNTIME_FILE_DIR_BASENAME` (directory-class flag + basename for `git rm -r --cached`
remediation). `runtime_ignore_block()` emits the exact fenced block used both by
`orchestrator-runtime-files.md`'s "Consumer Repo Setup" section and by
`scripts/tests/test-deploy-orphans.sh`/`test-deploy-propagation.sh`'s scratch-repo `.gitignore`
seeding. A markdown-vs-lib byte-identity test (`test-runtime-file-tracking.sh` Case 3) pins the
doc block to the lib — any new script that writes `specs/.gitignore` should source this lib rather
than hand-copy the block, and any pattern-list edit (e.g. adding `specs/tmp/`) must be made here
once, not in multiple places.

Fourteen of sixteen patterns are `**/`-prefixed (matching per-task scratch under any
`specs/{NNN}_{SLUG}/...`); the remaining root-scoped members (`.sessions/`, `.events.lock`,
`.freshness-warn-streak.json`, `.deploy-lock/`, `.scope-lock/`, `.commit-lock/`, `.errors.lock`)
also use `**/`-prefixed patterns even though they only ever occur at the `specs/` root — this
repo's convention is `**/` even for root-only members, so that the same block works whether pasted
into a repo-root `.gitignore` (where `**/x` matches `specs/x` and everywhere else) or, per item
(b), converted into a `specs/`-relative `specs/.gitignore` (where the leading `specs/` segment is
simply dropped, e.g. `**/.events.lock` -> `**/.events.lock` unchanged, or a root-scoped member
written without `**/` at all — either form matches the same file from inside `specs/.gitignore`).

**`specs/tmp/claude-tts-notify.log` writer, confirmed** (item d): both
`agent-system/extensions/core/hooks/tts-notify.sh:31` and
`agent-system/extensions/core/scripts/lifecycle-notify.sh:35` set
`LOG_FILE="specs/tmp/claude-tts-notify.log"`. This repo's own hand-maintained root `.gitignore`
already carries `/specs/tmp` (line ~11, root-relative form, *not* `**/`-prefixed) — added ad hoc,
outside the lib. Recommend adding `tmp` as a 17th class member (directory-class,
`RUNTIME_FILE_DIR_BASENAME="tmp"`), matching this repo's own precedent form rather than a blanket
`**/tmp/` (which risks silently ignoring a legitimately-named `specs/{NNN}_{SLUG}/tmp/` a task
creates on purpose — the writer here is always rooted at the `specs/` top level, never per-task).

**`state-write.sh --init` refuses the default state path — a hard, by-design block** (critical for
item a): `scripts/state-write.sh` supports `--init` ("Constructs a fresh target from null input
... for fresh-create sites (e.g. an archive reinit) that have nothing to read yet"), but the script
normalizes both the requested `--state-file` and the default `specs/state.json` via `realpath -m`
and **unconditionally exits 1** when they match:
```
Error: --init refuses to target the default live state file (...); --init is for archive/vault
targets only. Pass an explicit --state-file naming a non-default target.
```
(`state-write.sh:342`). This means `init-specs.sh` cannot call `state-write.sh --init` (or any
mode of `state-write.sh`) to create the live `specs/state.json` — it must write that file directly
(e.g. `mktemp` + heredoc + atomic `mv`), guarded by its own `[ ! -f specs/state.json ]`
existence check for the "MUST NOT overwrite" contract. By contrast, `specs/archive/state.json` is
a non-default target and `--init` is explicitly designed for exactly this case ("an archive
reinit") — `init-specs.sh` *can* use `state-write.sh --init --state-file specs/archive/state.json`
there, but must still guard existence itself first, since `--init` silently overwrites an existing
non-default target (only a stderr note, no refusal) and the dispatch's non-destructive contract is
stricter than that default behavior.

**Schema-valid minimal `specs/state.json`**
(`agent-system/extensions/core/context/schemas/state-schema.json`): only `next_project_number`
(integer >= 1) and `active_projects` (array) are `required`; `active_topics` is
"documented-optional, confirmed live." A minimal fresh file matching the dispatch's spec is:
```json
{"next_project_number": 1, "active_projects": [], "active_topics": []}
```
`specs/archive/state.json`'s live shape in this repo has top-level keys `archived_projects` and
`completed_projects` (no separate `abandoned_projects` key observed) — archive/state.json is
deliberately *not* validated against the same schema (see
`context/reference/state-management-schema.md`'s single-source note), so a fresh
`{"archived_projects": [], "completed_projects": []}` is a reasonable minimal shape, but this
should be double-checked against whatever reads `specs/archive/state.json` (recover mode in
`task.md`, `/todo`'s archival writer) before finalizing the exact key set in the plan phase.

**`specs/TODO.md` generation**: `generate-todo.sh` builds the whole file (frontmatter + Task Order
+ Tasks sections) purely from `specs/state.json` via `--state`/`--todo` flags and an atomic
mktemp+mv write; it runs fine against a fresh `active_projects: []` state (producing an
effectively-empty task list) and requires no pre-existing `TODO.md`. `init-specs.sh` should call
this script rather than hand-generate `TODO.md`, keeping the format in one place.

**Call sites reading `next_project_number` directly from `specs/state.json` before task creation**
(item c) — each is a "first specs touch" candidate:
| Site | Location |
|------|----------|
| `commands/task.md` | Step 1, `next_num=$(jq -r '.next_project_number' specs/state.json)` (~line 48) |
| `commands/review.md` | Follow-up task creation, Step 8 (~line 583-585) |
| `skills/skill-fix-it/SKILL.md` | Step 8.1 "Get Next Task Number" (~line 250-253) |
| `skills/skill-project-overview/SKILL.md` | Step 5.1 "Read Current State" (~line 279-282) |
| `skills/skill-spawn/SKILL.md` | ~line 260-263, "Get the next available task numbers" |
| `agents/meta-builder-agent.md` | `base_num = next_project_number from state.json` (~line 724), plus a `CreateTasks` step referenced from `commands/meta.md` |

`/orchestrate` (`commands/orchestrate.md`) and `/spawn`'s parent-task lookup
(`skills/skill-spawn/SKILL.md` earlier step, ~line 45-51) both read
`.active_projects[] | select(.project_number == $num)` for a task number that **must already
exist** — by construction this requires `specs/state.json` (and the referenced task) to already be
present, so neither is a realistic first-touch site in a genuinely fresh repo, even though
`/orchestrate` was named in the dispatch's example list. A defensive (idempotent, cheap) call at
the top of `orchestrate.md`/`command-gate-in.sh` would be harmless but is lower-priority than the
five task-creation sites above. `command-gate-in.sh` itself (sourced by research/plan/implement/
revise/orchestrate) unconditionally assumes `specs/state.json` exists and a task is already in it
— it is not a viable single choke point for this fix, since by the time it runs a task must
already have been created via one of the five sites above.

**Check A (`check-runtime-file-tracking.sh`) already works with `specs/.gitignore`** (item f):
Check A calls `git check-ignore -q "$probe"` per probe path — this resolves *any* applicable
`.gitignore` file at any directory level (root, `specs/.gitignore`, etc.), so a repo covered only
by a new `specs/.gitignore` already passes Check A with zero logic changes. The only stale part is
the human-facing failure message, which currently says "add the missing pattern(s) to the repo
root .gitignore" (`check-runtime-file-tracking.sh:80-81`) — this should be reworded to mention
`specs/.gitignore` (or the new setup script) as the primary remediation, per item (e)/(f).

**Check B already fails on ANY tracked ephemeral file, independent of ignore coverage** (item h):
Check B (`check-runtime-file-tracking.sh:86-114`) scans `git ls-files` directly against
`RUNTIME_FILE_B_REGEX` and reports a `FAIL` with a concrete `git rm --cached`/`git rm -r --cached`
remediation line for every hit — it never consults `.gitignore` state at all. Git history shows
this shape was shipped in commit `8695facc8` ("task 201 phase 3: rewire check-runtime-file-tracking.sh
onto the lib"), 2026-09-09, five days *before* task 209's 2026-09-14 "SECOND OBSERVATION" amendment
that specified item (h). This strongly suggests item (h) is **already satisfied by the current
implementation** and the plan phase should verify this with a fixture (tracked ephemeral files
present, `specs/.gitignore` covering them, confirm Check B still FAILs) rather than write new
detection logic — only the untracking *action* (item g) is missing, not the *detection*.

**Item (g) (untrack-already-tracked sweep) has no prior art**: no script in
`agent-system/extensions/core/scripts/` currently runs `git rm --cached`/`git rm -r --cached`
against the runtime-file class; `git-commit-scoped.sh` has no such step either. This is genuinely
new work. The remediation logic to reuse (loop `RUNTIME_FILE_B_REGEX` against `git ls-files`,
resolve directory-class hits via `runtime_file_dir_basename_for_hit()`) already exists verbatim in
Check B's *print-only* form and can be adapted to *execute* `git rm --cached`/`git rm -r --cached`
instead of just printing the command — the dispatch requires this stay non-deleting (never
`rm -rf` the working copy) and must explicitly exclude `.orchestrator-handoff.json` and bare
`.return-meta.json` (already true by construction, since neither matches any
`RUNTIME_FILE_B_REGEX` entry — Check C separately guards these two files are never *ignored*).

**Deploy path (`deploy-headless.sh`) never touches `specs/`**: its header describes exactly two
modes (default resync, `--wipe`), both scoped to regenerating `.claude/` from the source store;
`specs/` is out of scope entirely today. Calling `init-specs.sh` from deploy would be new,
additive behavior — safe on an already-initialized repo (no-op, since the script must guard
existence) but a real behavior change on a repo's very first deploy. `.syncprotect` protects
listed paths from deploy's file-copy engine and its `--wipe` snapshot/restore; it has no
established relationship to `specs/` today (its documented purpose is protecting hand-edited
`.claude/**`/root files during regeneration). If deploy is made to call `init-specs.sh`, respecting
`.syncprotect` would mean skipping the call (or skipping specific generated paths) if
`specs/.gitignore` (or `specs/state.json`) is itself listed there — an edge case the plan phase
should decide on rather than assume.

**This repo's own root `.gitignore`** already hand-carries the full runtime-file block (see
`.gitignore:1-58`) plus `/specs/tmp` — confirming both that the lib's block is the right thing to
generate, and that this specific repo (being the source store itself, not a "consumer") does not
need a `specs/.gitignore` for its own operation; the new setup script's target audience is a
foreign consumer repo with no existing coverage at all, exactly as observed in
`~/Projects/Logos/Verification`.

### External Resources

None consulted — this is a fully internal, codebase-only defect (no external API/library
involved).

### Recommendations

1. **New script**: `agent-system/extensions/core/scripts/init-specs.sh`. Sources
   `lib/runtime-file-patterns.sh`. Steps, each individually guarded by existence checks so the
   whole script is idempotent and a no-op on a second run:
   - Create `specs/`, `specs/archive/` (`mkdir -p`).
   - If `specs/state.json` absent: write the minimal schema-valid JSON directly (atomic
     mktemp+mv), NOT via `state-write.sh` (which refuses `--init` against this exact path by
     design — see Findings above).
   - If `specs/archive/state.json` absent: either write directly (for symmetry/simplicity) or via
     `state-write.sh --init --state-file specs/archive/state.json` (the case `--init` was built
     for) — plan phase should pick one and state why, but either way guard existence first since
     `--init` itself does not.
   - If `specs/TODO.md` absent (or always, since it's a pure derivation): call
     `generate-todo.sh` rather than hand-writing it.
   - Write/refresh `specs/.gitignore` from `runtime_ignore_block()`, converted to
     `specs/`-relative patterns (add the new `tmp` member here too, once added to the lib).
     Decide managed-block-with-markers vs. own-the-whole-file (dispatch item b asks for a
     justified choice) — a marked block (e.g. `# BEGIN/END runtime-file-patterns.sh managed
     block`) is the safer default since it survives user additions and mirrors no precedent
     conflict; owning the whole file is simpler but would clobber any user-added `specs/`-local
     ignore rule on refresh.
   - Item (g): find-and-untrack sweep — `git ls-files` against `RUNTIME_FILE_B_REGEX`, run
     `git rm --cached`/`git rm -r --cached` (never plain `rm`) for each hit, explicitly
     skip/never-match `.orchestrator-handoff.json`/bare `.return-meta.json` (already excluded by
     construction), leave the result staged for the caller's own scoped commit (do not commit
     inside `init-specs.sh` itself — callers already own their own commit step, e.g.
     `task.md` Step 7).
2. **Call sites** (item c): insert a call to `init-specs.sh` immediately before each of the six
   `next_project_number`-reading sites listed in Findings (`task.md` Step 1, `review.md`'s
   follow-up creation, `skill-fix-it/SKILL.md` 8.1, `skill-project-overview/SKILL.md` 5.1,
   `skill-spawn/SKILL.md`, `meta-builder-agent.md`'s task-creation step). Treat `/orchestrate`
   as optional/defensive given it cannot realistically be a first-touch site.
3. **`runtime-file-patterns.sh`** (item d): add a 17th member `tmp` (id `"tmp"`, pattern
   matching this repo's own root-relative `/specs/tmp` precedent rather than a blanket `**/tmp/`,
   directory-class, basename `"tmp"`), and regenerate `orchestrator-runtime-files.md`'s pinned
   fenced block to match (the byte-identity test will catch a forgotten regen).
4. **`orchestrator-runtime-files.md`** (item e): rewrite "Consumer Repo Setup" to state the
   `specs/` ignore rules are now installed automatically by `init-specs.sh` (called from the
   sites in #2), and that only the repo-root `.gitignore` `specs/.sessions/`-class coverage (per
   the file's own existing rationale for why `.sessions/` needs root-level coverage) remains a
   manual, one-time step — state this precisely rather than leaving the whole block as manual.
5. **`check-runtime-file-tracking.sh`** (items f/h): reword Check A's failure message to mention
   `specs/.gitignore` (no logic change needed — `git check-ignore -q` already honors it). Verify,
   rather than reimplement, that Check B already fails on tracked files regardless of ignore
   coverage (confirmed true today); add a fixture case proving it rather than new code.
6. **Fixture tests**: extend `scripts/tests/test-runtime-file-tracking.sh` (or a new
   `test-init-specs.sh` alongside `test-deploy-orphans.sh`/`test-deploy-propagation.sh`) covering:
   a scratch repo with no `specs/` at all (full bootstrap), a second `init-specs.sh` run (true
   no-op), and the item-(g)/ADDED ACCEPTANCE scenario (committed `.commit-lock/`, `.events.lock`,
   `.lock/holder.json`, `.dispatch/1.md`, `.orchestrator-loop-guard`, and a multi-state file all
   get `git rm --cached`, staying on disk, with `git status --porcelain -- specs/` empty after the
   next scoped commit + lock release).

## Decisions

- `init-specs.sh` must write `specs/state.json` directly rather than through `state-write.sh`,
  because `state-write.sh --init` is hard-refused against the default live path by design.
- `specs/archive/state.json` may use `state-write.sh --init --state-file ...` (its intended use
  case) but still needs an explicit existence guard in `init-specs.sh`, since `--init` alone
  overwrites silently (stderr note only).
- Item (h) does not require new detection code in `check-runtime-file-tracking.sh` — Check B
  already fails on any tracked ephemeral file regardless of gitignore coverage (shipped
  2026-09-09, predating the amendment that specified this requirement). Plan should verify with a
  fixture, not implement anew.
- `/orchestrate` and `/spawn`'s parent-task-lookup path are not realistic first-touch sites (both
  require a pre-existing task number) and should be treated as low-priority/optional relative to
  the five task-creation call sites.

## Risks & Mitigations

- **Risk**: a blanket `**/tmp/` pattern for `specs/tmp/` could silently hide a legitimately-named
  per-task `tmp/` directory. **Mitigation**: use the root-scoped form (matching this repo's own
  `/specs/tmp` precedent), not `**/tmp/`.
- **Risk**: writing `specs/.gitignore` as a fully-owned file (no managed-block markers) could
  clobber a consumer's hand-added local ignore rule on a later `init-specs.sh` refresh.
  **Mitigation**: use a marked managed block, appending/preserving anything outside it.
- **Risk**: calling `init-specs.sh` from `deploy-headless.sh` changes deploy's scope (today
  strictly `.claude/`-only) and interacts with `.syncprotect` in an undefined way.
  **Mitigation**: treat as a separate, explicitly-justified decision in the plan rather than a
  default; the six call sites in commands/skills/agents already cover every documented
  first-touch path without deploy's involvement.
- **Risk**: task 51 ("Move session state files out of specs root") depends on task 209 and edits
  the same `runtime-file-patterns.sh` / `orchestrator-runtime-files.md` files. **Mitigation**: no
  conflict today (task 51 is `[NOT STARTED]`); whichever plan lands second should re-check
  `specs/.gitignore` generation covers any relocated paths, per the dispatch's own COORDINATION
  note.

## Context Extension Recommendations

- **Topic**: consumer-repo bootstrap for the task-management system.
- **Gap**: no existing context file documents "what a genuinely fresh consumer repo needs before
  `/task` can run" as a single narrative — the information is scattered across `task.md`,
  `state-schema.json`, and `orchestrator-runtime-files.md`.
- **Recommendation**: once `init-specs.sh` exists, consider a short
  `context/patterns/consumer-repo-bootstrap.md` pointer (or fold into
  `orchestrator-runtime-files.md`'s "Consumer Repo Setup" section, per item e) describing the
  full bootstrap contract in one place, so future call-site additions (item c) have one canonical
  reference rather than re-deriving the site list.

## Appendix

### Search queries / commands used

- `find agent-system/extensions/core -iname "runtime-file-patterns.sh" -o -iname
  "check-runtime-file-tracking.sh" -o -iname "orchestrator-runtime-files.md"`
- `grep -n "next_project_number" -B3 -A3` across `commands/*.md`, `skills/*/SKILL.md`,
  `agents/meta-builder-agent.md`
- `git log --format='%h %ad %s' --date=short -- .../check-runtime-file-tracking.sh`
- `grep -rn "claude-tts-notify\|specs/tmp"` across `agent-system/`
- Read `scripts/state-write.sh` header (the `--init`/`--state-file` contract section) in full
- Read `context/schemas/state-schema.json`, `context/standards/orchestrator-runtime-files.md`,
  `commands/task.md` (Create Task Mode steps 1-8), `scripts/check-runtime-file-tracking.sh`,
  `scripts/lib/runtime-file-patterns.sh`, `scripts/generate-todo.sh` header,
  `scripts/deploy-headless.sh` header

### References

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh`
- `agent-system/extensions/core/scripts/state-write.sh`
- `agent-system/extensions/core/scripts/generate-todo.sh`
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`
- `agent-system/extensions/core/context/schemas/state-schema.json`
- `agent-system/extensions/core/commands/task.md`, `review.md`, `orchestrate.md`, `meta.md`
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md`,
  `skill-project-overview/SKILL.md`, `skill-spawn/SKILL.md`
- `agent-system/extensions/core/agents/meta-builder-agent.md`
- `agent-system/extensions/core/hooks/tts-notify.sh`,
  `agent-system/extensions/core/scripts/lifecycle-notify.sh`
- `/home/benjamin/.config/nvim/.gitignore` (this repo's own hand-maintained root ignore file)
- `specs/TODO.md` entries #209, #51
