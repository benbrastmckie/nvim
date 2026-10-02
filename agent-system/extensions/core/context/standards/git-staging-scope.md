# Git Staging Scope Contract

## Overview

This standard defines the operation-type commit-scope contract for the single-agent commit
pipeline (`/research`, `/plan`, `/implement`). It replaces repo-wide `git add -A` staging with
targeted, work-scoped staging so every commit contains only the files the operation actually
produced — never a concurrent session's stray edits.

This is the canonical authority referenced by `orchestrator-postflight.sh`, `skill-orchestrate`,
`general-implementation-agent`, `git-workflow.md`, and `skill-git-workflow`.

## Canonical Runtime-File Exclusion Set

Every task-directory `git add` in this contract considers the same fixed set of ephemeral runtime
files for exclusion, via git exclusion pathspecs (`:(exclude)...`) rather than an allowlist — an
allowlist would also silently drop legitimate durable content that live task directories carry
(`progress/`, `handoffs/`, `fixtures/`, `tests/`, `HANDOFF.md`), trading one silent-drop bug for
another. Exclusion pathspecs instead subtract exactly the ephemeral classes and nothing else. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and the rationale
(freshness-gate asymmetry) behind which files these are:

```bash
task_dir="specs/${padded_num}_${project_name}"
ephemeral_excludes=(
  ":(exclude)${task_dir}/.orchestrator-loop-guard"
  ":(exclude)${task_dir}/.orchestrator-churn-state.json"
  ":(exclude)${task_dir}/.drift-inspection.json"
  ":(exclude)${task_dir}/.lock/"
  ":(exclude)${task_dir}/.dispatch/"
)
```

**This is a CANDIDATE array, not an unconditionally-injected one.** Naming a path already covered
by `.gitignore` in an explicit `:(exclude)...` pathspec entry makes `git add` treat it as an
EXPLICITLY-NAMED ignored path and refuse the WHOLE add ("The following paths are ignored by one
of your .gitignore files") whenever that path currently exists on disk — a held task lock's
`.lock/` directory is the case that surfaces this in practice, but all four candidates reproduce
the identical abort if present and gitignored. An ignored path swept up IMPLICITLY by a bare
directory pathspec (no exclude entry naming it) is, by contrast, silently skipped by `git add`
with no error — gitignore coverage alone is already sufficient to keep it out. `git-commit-scoped.sh`,
the sanctioned implementation of this contract (see "Commit-Level Path Scoping and Cross-Process
Serialization" below), therefore injects each candidate as an explicit `:(exclude)...` entry only
when `git check-ignore -q` reports it is NOT already covered by `.gitignore`. In a repo that has
applied the full ephemeral `.gitignore` block (including this one), the post-injection pathspec
list carries **zero** of these four entries — exclusion is delivered by `.gitignore` alone. In an
under-configured consumer repo lacking that block, all four candidates are injected verbatim,
identical to this contract's pre-conditional behavior. See
`context/standards/orchestrator-runtime-files.md`'s "This gitignore coverage is the primary,
sufficient control" statement — this conditional-injection behavior is the mechanical expression
of that already-settled position: gitignore coverage is primary, this exclusion set is
defense-in-depth for a repo that has not yet applied it, not the primary control itself.

**`.orchestrator-handoff.json` and `.return-meta.json` are deliberately NOT in this set.** They
are durable provenance under the settled policy in `orchestrator-runtime-files.md` — staging them
is intended, not an oversight to fix later.

Every scope below extends this same array rather than re-deriving its own exclusion list —
extend it here once if a future audit adopts another ephemeral class.

## Per-Operation Scope

### `research`

No commit is created. `do_git_commit=false` for the `research` operation type in
`orchestrator-postflight.sh`. This is unchanged by this contract — research was already safe.

### `plan`

Stage:

```
specs/{padded}_{slug}/ "${ephemeral_excludes[@]}"
specs/TODO.md
specs/state.json
```

No dependency on agent self-report — the plan operation only ever touches files under the task
directory plus the two shared index files. The exclusion pathspecs above still apply: a plan
dispatch can run inside an in-flight `/orchestrate` loop and must not sweep in the loop guard,
churn state, drift-inspection scratch file, or a `.lock/` directory.

### `implement`

Stage the `plan` scope above (task directory with the same exclusions), PLUS:

```
{plan_path}                      # the plan file itself (may have phase status edits)
{each entry of modified_files}   # agent self-reported source files touched (see below)
```

`modified_files` is an optional `string[]` field in the agent's `.return-meta.json` (see
`.claude/context/formats/return-metadata-file.md`). It is populated by
`general-implementation-agent` (and other implementation agents) as they `Write`/`Edit` files
during execution — see `.claude/context/formats/progress-file.md`'s `files_touched` field for the
per-objective accumulation mechanism that feeds it.

### Concurrency Qualifier: Targeted Staging Is Necessary But Not Sufficient

Everything above (explicit whole-path staging, never a directory or glob pathspec) remains the
sanctioned staging form and remains **fully sufficient against over-broad staging** — nothing
here widens or narrows that predicate. It addresses accidentally picking up more files than an
operation intended. It does **not**, by itself, address a narrower and different hazard:
**two concurrently dispatched tasks both holding uncommitted edits to the same shared file.**
Path granularity is the file — an explicit-path `git add` cannot subdivide a file by author — so
a dispatch that stages a shared file by its correct, explicit whole path can still carry a
sibling's still-uncommitted lines into its own commit, silently and without any staging mistake
on either side. This has been observed in production: a single shared markdown file carrying a
sibling task's rows inside an otherwise-correctly-scoped commit, and separately, a multi-task
batch where several dispatches' correctly-scoped commits each swept up a different task's
in-flight edits to shared files, attributing that content to the wrong task's commit history.

The remedy for this hazard lives at a different layer than staging-path discipline: a
first-claim contended-path lease enforced inside `git-commit-scoped.sh` itself (refusing to stage
a path a live sibling dispatch is concurrently contending for, rather than trying to stage it more
carefully), or, for a task type whose builds are expensive enough to warrant it, per-dispatch
working-tree isolation. See the working-tree and build isolation posture decision record
(`context/patterns/batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation
Posture" section) for the full scoring of both remedies against this and the other concurrent-
dispatch failure modes. That document and this one are cross-referenced deliberately: this
document defines what a single dispatch stages; that one decides what protects a shared file
across dispatches.

## Multi-Task Application

In multi-task `/orchestrate`, the `research`/`plan`/`implement` scopes above apply **once per
task**, keyed to that task's own directory and its own `.return-meta.json` — never unioned across
tasks into a single combined commit. A union commit cannot be reverted per task. Concretely: MT
mode's per-task postflight loop (`orchestrate-cycle-postflight.sh`, called from `skill-orchestrate`'s Move 3) issues one scoped
commit per task per phase transition, reusing this same contract with `task_dir` and
`modified_files` resolved from that task's own state — never a sibling task's.

`--honest-index-rows` is required at every site staging `specs/state.json` or `specs/TODO.md`,
because those shared, wholesale-regenerated index files legitimately carry other tasks' current
rows in the same commit — including at the MT per-task commit site, which stages both files on
every task's commit.

## Fail-Safe Direction

**Under-stage, never over-stage.**

If `modified_files` is absent, empty, or the agent did not report it, the postflight pipeline
MUST fall back to staging only the fixed task-directory paths (`specs/{padded}_{slug}/`,
`specs/TODO.md`, `specs/state.json`, and the plan path for `implement`) and print a **loud,
non-silent warning**:

```
[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually.
```

In multi-task application (see "Multi-Task Application" above), the same warning is emitted per
task with the task number appended (`no modified_files reported for task #{task_num}; ...`) — this
is the only sanctioned wording; a second, differently-worded convention MUST NOT be introduced.

It is always acceptable to leave source-file changes uncommitted for the user to review and
stage manually. It is never acceptable to reach for `git add -A` to "catch everything" — that
silently pulls in unrelated concurrent-session changes.

## Reference Template (canonical scoped-staging pattern)

This is the canonical, proven scoped-staging pattern — reuse it verbatim rather than
reinventing scoped staging:

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/reports/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete research

Session: ${session_id}
"
```

For `implement`, extend the same pattern with the plan path, `modified_files`, and the canonical
exclusion set (this template stages the whole task directory, unlike the research example
above, so the exclusions are required here). **This inline template is illustrative of the
overall staging shape only — it is NOT the sanctioned implementation.**
`agent-system/extensions/core/scripts/git-commit-scoped.sh` is the sanctioned implementation
(see "Commit-Level Path Scoping and Cross-Process Serialization" below) and applies the
`git check-ignore`-gated conditional injection documented in "Canonical Runtime-File Exclusion
Set" above — a caller reading only this template and reproducing the unconditional `git add
"${ephemeral_excludes[@]}"` shape shown here verbatim would reintroduce the `.lock/`-present
abort hazard that conditional injection exists to close. Prefer invoking
`git-commit-scoped.sh` directly over hand-rolling this template's `git add`/`git commit` pair —
running the template's `git add "${stage_paths[@]}"` line as a raw top-level Bash command is now
correctly BLOCKED by `guard-destructive-git.sh` on a dirty tree, since `${task_dir}/` is a
directory pathspec (see "Forbidden Operations" above); `git-commit-scoped.sh` is the sanctioned
path precisely because its own internal `git add` runs as a subprocess, never as the literal
top-level `tool_input.command` the hook observes (the same structural-invisibility precedent
`guard-destructive-git.sh`'s header documents for `git-snapshot.sh`):

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"
ephemeral_excludes=(
  ":(exclude)${task_dir}/.orchestrator-loop-guard"
  ":(exclude)${task_dir}/.orchestrator-churn-state.json"
  ":(exclude)${task_dir}/.drift-inspection.json"
  ":(exclude)${task_dir}/.lock/"
  ":(exclude)${task_dir}/.dispatch/"
)
stage_paths=(
  "${task_dir}/"
  "${ephemeral_excludes[@]}"
  "specs/TODO.md"
  "specs/state.json"
  "$plan_path"
)
# Append each self-reported modified file
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file")

git add "${stage_paths[@]}"
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}
"
```

## Forbidden Operations

The following are forbidden in the commit pipeline and any agent/skill that stages files for a
task-scoped commit:

- `git add -A`
- `git add .`
- A **directory or glob `git add` pathspec** (e.g. `git add -- some/dir/`, `git add some/dir`,
  `git add src/*.lean`) — stages every modified file the pathspec expands to, the identical
  over-staging harm as `git add -A`/`git add .` in a narrower disguise. The sanctioned explicit
  multi-file list (e.g. `git add -- a.lean b.lean`) is unaffected and remains the correct form.
- `git commit -am` (implicitly stages all tracked-file modifications)
- A **bare, unscoped `git commit`** (no trailing `-- <pathspec>...`) — see "Commit-Level Path
  Scoping and Cross-Process Serialization" below. Even when staging was correctly narrowed by
  this contract, a bare commit still commits the ENTIRE shared index, not just what was just
  staged, so a concurrently-dispatched agent's staged-but-uncommitted work gets swept into
  whichever agent commits next.

These commands stage (or commit) more than the operation actually produced, which can silently
include a concurrent session's stray edits, unrelated in-progress work, or accidental file
changes that have nothing to do with the current operation.

**Enforced by `guard-destructive-git.sh`**: the first four bullets above (`git add -A`/`--all`,
`git add .`, a directory-or-glob `git add` pathspec, and `git commit -a`/`-am`/`--all`) are
enforced mechanically, not just by convention — `.claude/hooks/guard-destructive-git.sh`'s
over-staging predicate blocks all four on a dirty working tree via exit 2, with NO
snapshot-marker exemption (see that hook's header for the data-loss vs. scope-pollution
rationale). The bare-unscoped-commit bullet is not part of that predicate; it is enforced by
`git-commit-scoped.sh` always naming its pathspec, per "Commit-Level Path Scoping and
Cross-Process Serialization" below.

## Commit-Level Path Scoping and Cross-Process Serialization

Staging narrowly is necessary but not sufficient: a narrowed `git add` followed by a **bare**
`git commit` still commits the entire shared index, because `git commit` with no pathspec commits
everything currently staged — including anything a concurrently-dispatched agent staged into the
same shared index but has not yet committed. This was a real, observed defect (two implementation
agents each reported their own phase commits swept into a concurrent session's commit message).

The fix has two parts, both mandatory for every commit site in the dispatch pipeline:

1. **Every `git commit` MUST name its pathspec**: `git commit -m "..." -- <pathspec>...`, using
   the same paths (plus the canonical exclusion set) that were just staged. A bare `git commit`
   is now a Forbidden Operation (see above), on the same footing as `git add -A`.
2. **The `git add` + `git commit` pair MUST be serialized** through the `specs/.commit-lock/`
   mutex (`task-lock.sh`'s `commit-acquire`/`commit-release` verbs — see
   `context/patterns/task-lock.md`'s Scope-Mutex CLI section for the full contract). Path-scoping
   alone converts misattribution into a DIFFERENT failure: two simultaneous scoped commits race on
   git's own `index.lock`, and one fails outright. Serializing the add+commit pair removes that
   race without reintroducing misattribution.

`agent-system/extensions/core/scripts/git-commit-scoped.sh` is the single sanctioned
implementation of both parts. Every commit site in the dispatch pipeline invokes it rather than
re-deriving this pattern inline — the pattern drifted once already when it was left to eleven
near-duplicate call sites (nine of eleven never received the canonical exclusion set after it was
added to this document), and a single shipped helper is what stops that recurring.

Two non-obvious safety rules, discovered empirically and enforced inside the helper rather than
left for each caller to rediscover:

- **An exclude-only pathspec list commits WIDER than a bare commit, not narrower.** `git commit --
  ":(exclude)some/path"` with no positive pathspec entry commits everything except the excluded
  path — the opposite of the intended narrowing. A degenerate `stage_paths` (e.g. an empty task
  directory variable) would silently turn the fix into a worse bug. `git-commit-scoped.sh` refuses
  to run (no `git add`, no commit) if the pathspec list contains zero positive entries, both
  before and after path validation.
- **An unmatched path in the commit pathspec aborts the WHOLE commit.** `git commit -- <paths
  including one git cannot match>` fails with `error: pathspec '...' did not match any file(s)
  known to git` and commits nothing at all — worse than `git add`'s equivalent failure, which
  today is already guarded by the postflight pipeline. `git-commit-scoped.sh` validates each
  positive pathspec and drops unmatched entries with a loud warning rather than aborting the
  entire commit.

### Exit-Code Contract and Safety Gates

`git-commit-scoped.sh`'s own header documents its full exit-code table and safety-gate labels
(V2, V3, V5, V6); this subsection mirrors that table here so a reader of this document is not
left to open the script for it.

| Exit code | Meaning |
|-----------|---------|
| `0` | Commit created. |
| `1` | "Nothing to commit" (identical to a bare `git commit`'s own exit code), or the `git commit` itself failed after the bounded `index.lock` retry. Non-blocking — matches every call site's existing `|| echo "NOTE: Nothing to commit..."` fallback. |
| `2` | Usage error, or the V3 degenerate-pathspec refusal (an exclude-only list, or every positive pathspec dropped by V2 — refused before any `git add`/`git commit`), or `git add` itself failed for one or more staged paths. |
| `3` | Contended-path refusal (V5, `--task` only): a positive pathspec entry is listed as contended in the cycle manifest AND currently claimed by ANOTHER live task. Refused before any `git add`; nothing staged. Never emitted when `--task` is omitted. |
| `4` | The V6 refusal below: one or more positive pathspecs were dropped as genuinely unmatched AND the commit attempt produced no commit. |

Gate labels, in the same voice as the script header:

- **V2** — an unmatched path in the commit pathspec aborts the whole commit in bare git; this
  script classifies each positive pathspec into matched / already-staged-deletion / genuinely
  unmatched, dropping only the third case with a loud warning.
- **V3** — an exclude-only pathspec list (or a positive list that fully degenerates to one after
  V2 filtering) commits WIDER than a bare commit, not narrower; refused outright before any
  `git add`/`git commit`.
- **V5** — explicit-path staging alone does not protect against CONCURRENT same-file dispatch;
  `--task` opts a caller into a per-path first-claim lease against the cycle-scoped contention
  manifest.
- **V6** — a PARTIAL pathspec drop (some, not all, positive entries hit V2's genuinely-unmatched
  case) is indistinguishable from the ordinary, benign "nothing changed" no-op once the survivors
  themselves carry no diff: both land on exit `1`, differing only in a stderr `WARN:` line that no
  current caller inspects. (V3 above already refuses the OTHER half of this gap — every positive
  pathspec dropped; V6 covers what V3 does not.) When at least one pathspec was dropped AND the
  commit attempt produced no commit, this script now exits `4` with a loud `ERROR:` naming every
  dropped path instead of falling through to the generic `NOTE:`. The predicate deliberately does
  NOT try to distinguish "nothing to commit" from "git commit genuinely failed" by parsing commit
  output — both sub-cases are already nonzero and already swallowed identically by every current
  caller, so splitting them buys nothing and adds a dependency on git's own wording.

**Recorded caller-escalation residual**: every current call site wraps the invocation as
`cmd || echo "WARN: ...(non-blocking)"`. Because bash's `A || B` yields `B`'s exit status
regardless of `A`'s own code, ANY nonzero exit from the script — `1`, `2`, `3`, or the new `4` —
already collapses to success for the caller's own control flow. Landing the V6 gate therefore
makes a script-level failure louder and more diagnosable (a named `ERROR:` and a distinct exit
code, in place of an indistinguishable generic `NOTE:`) but does not, by itself, change what any
caller does next. A caller that wants to halt or branch on exit `4` must replace its `|| echo`
idiom with an explicit `$?` check — a separate, deliberately out-of-scope change from this fix;
see the script's own header for the same note.

## Required Review Flow

Before any commit in the pipeline, prefer to surface what is about to be committed:

```bash
git status --short
git diff --staged
```

After a targeted commit, the postflight pipeline runs `git status --porcelain` and logs a
warning if the working tree is still non-empty — this surfaces (rather than hides) any gap
between what was staged and what actually changed.

## State-Write Serialization and Honest Commit Messages

This scoped-staging rule governs WHAT gets staged for a commit; it does not, by itself, say
anything about ordering the underlying writes to the shared files it stages. `specs/state.json`
in particular is mutated by several independent read-modify-write round trips per postflight run
(status update, artifact-number increment, completion-data writes, memory-candidate propagation,
artifact linking), each of which reads the file, transforms it, and writes it back —  a shape
that is only ever safe against a SINGLE writer at a time. `orchestrator-postflight.sh` now
brackets that entire read-modify-write-plus-`TODO.md`-regen window (its Stages 7 through 8a) in
the `specs/.scope-lock/` mutex documented in `task-lock.md`'s "Scope-Mutex CLI" section, so two
concurrent postflight runs on DIFFERENT tasks can no longer interleave their state.json writes
and silently lose one session's update.

**Correction to an earlier version of this section**: this serialization was previously described
as stopping at the state-write window, with `git add`/`git commit` (Stage 9 and later) deliberately
left "explicitly outside the mutex... a slower git/TTS/cleanup tail carries no data-integrity risk
worth serializing." That reasoning was sound when the only committer was a single sequential
postflight process, but concurrent multi-task dispatch invalidated it: two simultaneously
dispatched agents' `git add` + bare `git commit` pairs on the shared index is exactly the
misattribution defect "Commit-Level Path Scoping and Cross-Process Serialization" above describes.
Stage 9 still stays outside the **state-write** mutex (`specs/.scope-lock/`, released before
Stage 8b) — that boundary is unchanged and still correct, since state.json's read-modify-write
concern is unrelated to committing. But Stage 9 now runs INSIDE a second, distinct **commit**
mutex (`specs/.commit-lock/`, via `git-commit-scoped.sh`) for the whole duration of its `git add` +
`git commit` pair. Both statements are true simultaneously: "outside the state-write mutex" and
"inside the commit mutex" describe two different, non-overlapping critical sections guarded by two
different mutexes — see `task-lock.md`'s two-mutex documentation for why one mutex could not serve
both.

Because the staging rule above still allows `specs/state.json` and `specs/TODO.md` to legitimately
carry OTHER tasks' current rows in a given commit (they are shared, wholesale-regenerated index
files — see Per-Operation Scope above), `orchestrator-postflight.sh`'s Stage 9 now also runs a
staged-diff scan immediately after `git add` and before `git commit`: it compares the just-staged
`specs/state.json` against `HEAD`'s, entry-by-entry on parsed `active_projects` records (never a
raw `+`/`-` line diff, which would miss a changed field sitting inside an unchanged
`project_number` context line), and appends a body line naming every OTHER task whose index rows
the commit carries — e.g. `Also carries current index rows for tasks: 42, 57`. This does not
change staging scope or serialization; it makes an already-legitimate outcome (a commit
mentioning one task while its diff includes other tasks' current index rows) honestly labeled
rather than silently attributed to the named task alone. The scan is entirely failure-tolerant:
any error (missing `HEAD` file on a first commit, unparseable JSON, no staged `state.json`) omits
the addendum and falls through to the plain commit message — it must never break a commit.

## Related Documentation

- `.claude/context/formats/return-metadata-file.md` — `modified_files` field schema, and its
  "Multiple Sequential Writers" subsection for the read-modify-write invariant a later writer to
  `.return-meta.json` (e.g. the orchestrator postflight stage) MUST follow
- `.claude/context/formats/progress-file.md` — `files_touched` per-objective field
- `.claude/scripts/orchestrator-postflight.sh` — Stage 9 execution site
- `.claude/scripts/git-commit-scoped.sh` — the single sanctioned implementation of commit-level
  path scoping plus commit-mutex serialization (see "Commit-Level Path Scoping and Cross-Process
  Serialization" above)
- `.claude/rules/git-workflow.md` — Never Run list and Commit Scope section
- `.claude/skills/skill-git-workflow/SKILL.md` — canonical documentation front
- `.claude/context/patterns/task-lock.md` — the `specs/.scope-lock/` scope-mutex CLI
  (`scope-acquire`/`scope-release`) that brackets the state.json read-modify-write window
  referenced above, AND the sibling `specs/.commit-lock/` commit-mutex CLI
  (`commit-acquire`/`commit-release`) that `git-commit-scoped.sh` uses to serialize commits
- `.claude/context/standards/orchestrator-runtime-files.md` — the two-class ephemeral/durable
  policy the canonical exclusion set above implements, with the full freshness-gate rationale
- `.claude/scripts/orchestrate-cycle-postflight.sh` — the per-task commit site
  that applies the "Multi-Task Application" scope above once per task
- `.claude/docs/architecture/orchestrate-state-machine.md` — MT Mode's Commit Granularity
  subsection, and `.claude/context/patterns/batch-orchestration-guardrails.md` — hazard 2's
  retirement record
- `.claude/scripts/lint/lint-scoped-commit-boundary.sh` — the mechanical guardrail against
  regrowth of the raw `git add` + bare `git commit -m` anti-pattern this doc describes; wired as
  `verify-deploy.sh` gate 17
- `.claude/scripts/lint/lint-directory-pathspec-boundary.sh` — the complementary mechanical
  guardrail against the OPPOSITE failure mode: a `git-commit-scoped.sh` call that correctly ends
  in a trailing pathspec, but that pathspec is itself a bare SHARED directory (e.g. `-- specs/`
  or `-- .memory/`) rather than the explicit file list this doc's per-operation scopes require.
  It deliberately does not flag the sanctioned task-scoped directory form (`-- "${task_dir}/"`,
  `-- "specs/${padded_num}_${slug}/reports/"`) described above. **Not yet** wired as a
  `verify-deploy.sh` gate: the natural wiring point (`verify-deploy.sh` gate 17, alongside its
  sibling) is itself an orchestrator-critical path, and the task that introduced this lint was
  scoped to exclude touching any critical path — see that task's summary for the follow-up
