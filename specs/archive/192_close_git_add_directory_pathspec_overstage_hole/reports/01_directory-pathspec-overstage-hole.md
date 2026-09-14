# Research Report: Task #192

**Task**: 192 - Close the directory-pathspec hole in guard-destructive-git.sh over-staging predicate
**Started**: 2026-09-09
**Completed**: 2026-09-09
**Effort**: Small (single-file predicate extension + 3 doc/test file updates)
**Dependencies**: None (no hard dependency; file-footprint overlap with the history-rewrite predicate task is noted below)
**Sources/Inputs**: Codebase read of `agent-system/extensions/core/hooks/guard-destructive-git.sh`, `context/standards/git-staging-scope.md`, `rules/git-workflow.md`, `scripts/tests/test-guard-destructive-git.sh`, `scripts/git-commit-scoped.sh`, `scripts/lint/lint-scoped-commit-boundary.sh`, `scripts/git-snapshot.sh`, `context/standards/shell-strict-mode.md`; repo-wide grep for `git add` call sites and `git-commit-scoped.sh` callers.
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and precisely scoped: `hooks/guard-destructive-git.sh`'s over-staging
  predicate (lines 120-134) checks only `-A`/`--all` and the bare `.` pathspec on a `git add`
  segment — a directory pathspec (`git add -- dir/`, `git add dir/`) passes untouched and stages
  every modified file under that directory, reproducing the over-staging harm the guard exists to
  prevent. This is exactly what happened live (commit `ea1a561c9`).
- **Recommended fix**: extend the existing per-token loop inside the `ADD_SEGMENTS` while-loop
  (same segment already isolated by the existing grep) with a trailing-slash check
  (`token` ends in `/`) as the primary detector — it alone satisfies every case named in the
  dispatch's ACCEPTANCE and fixture list (`dir/`, `-- dir/`, the live `FormalSystem/` incident).
  Recommend layering two additional, same-cost checks onto the same per-token loop as the
  "more general rule" the dispatch invites weighing: (1) a filesystem `[ -d "$token" ]` test to
  also catch a directory pathspec with **no** trailing slash (e.g. `git add somedir`), and (2) a
  glob-metacharacter test (`*`, `?`, `[`) to catch `git add src/*.lean`-shaped globs, explicitly
  named in the dispatch as the general rule's extra reach. None of the three checks fire on a
  token with no slash, no glob character, and no on-disk directory at that path — i.e. an
  ordinary explicit filename — so the sanctioned "explicit multi-file list" form
  (`git add -- a.lean b.lean`) is untouched.
- **Do NOT introduce a second, non-quote-stripped scan variable.** The dispatch's item (b)
  explicitly directs reuse of the existing `COMMAND_SCAN` argv-anchoring machinery. Reusing it
  has one accepted, pre-existing-shaped side effect worth documenting rather than fixing: the
  upfront quote-strip (`sed -e 's/"[^"]*"/""/g'`) replaces an entire quoted span with literal
  `""`, so a **quoted** directory pathspec (`git add -- "some/dir/"`) is invisible to every
  detector, old and new alike — the bare-dot check already has the identical blind spot today
  (`git add "."` is not caught either). This is not a new hole opened by this fix; it is an
  existing, structural consequence of the quote-strip that the header update (item (d)) should
  state plainly rather than silently omit.
- `git-commit-scoped.sh` — the sanctioned staging implementation every current call site uses —
  legitimately passes a directory pathspec (`"${task_dir}/"`) to its own **internal** `git add`.
  This does **not** collide with the new predicate: that internal `git add` runs as a subprocess
  of the wrapper script and never appears as the literal `tool_input.command` string the hook
  observes (identical to the existing, already-documented precedent for `git-snapshot.sh`'s
  internal `git add -A`, header lines 41-47). Verified by reading every current caller
  (`orchestrator-postflight.sh`, `orchestrate-cycle-postflight.sh`, `skill-git-workflow`, etc.) —
  none of them literally invokes raw `git add <dir>/` as a top-level Bash command; they all
  invoke `bash .../git-commit-scoped.sh ...` instead. The new predicate is therefore safe to add
  with **no exemption**, consistent with the dispatch's MUST NOT.
- One inline template inside `git-staging-scope.md` itself (lines 163-190, explicitly marked "NOT
  the sanctioned implementation") shows a hand-rolled `git add "${stage_paths[@]}"` with a
  directory pathspec. If an agent ever copies that illustrative block and runs it as a raw Bash
  command instead of calling `git-commit-scoped.sh`, the new predicate will correctly block it —
  a desirable side effect, since that hand-rolled shape is exactly the bare-index-race/misattribution
  pattern `git-commit-scoped.sh` was built to close.

## Context & Scope

Researched the single hook file, its two governing doc/rule files, and its test fixture, per the
task's declared `file_scope`. Confirmed via repo-wide grep that no other script raw-invokes
`git add` with a directory pathspec as a literal top-level Bash command; the only raw `git add
-A` outside the hook itself is `git-snapshot.sh`'s internal subprocess call (already exempted by
construction, not by code) and test-fixture setup code in unrelated test files (`test-lint-scoped-commit-boundary.sh`,
`test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`,
`test-orchestrate-cycle-postflight.sh`) that spins up throwaway git repos for OTHER lints/tests
and never runs through this hook.

## Findings

### Codebase Patterns

**Current predicate structure** (`hooks/guard-destructive-git.sh` lines 108-157):
1. `COMMAND_SCAN` is built once, up front: quoted spans replaced with `""`/`''`, then `#`
   comments stripped to end-of-line. Every detector reads `COMMAND_SCAN`, never raw `$COMMAND`.
2. `ADD_SEGMENTS` isolates each `git add ...` occurrence via
   `grep -oE '(^|[;&|][[:space:]]*)git[[:space:]]+add[^;&|]*'`, then a `while IFS= read -r seg`
   loop tests each segment for (a) `-A`/`--all` via a hyphen-cluster regex, then (b) a bare `.`
   pathspec via `(^|[[:space:]])\.([[:space:]]|$)`. First match sets `OVERSTAGE_REASON` and
   `break`s.
3. `COMMIT_SEGMENTS` does the analogous thing for `-a`/`-am`/`--all` on `git commit`.
4. Over-staging blocks independently of, and before, the destructive-command chain — no
   snapshot-marker exemption applies to it (by design, per the header).

**The gap**: nothing in step 2 inspects the *pathspec tokens* of the segment at all — only
whole-segment regexes for the dot and the `-A`/`--all` flag cluster. A directory token
(`FormalSystem/`, `dir/`, bare `dir`) or a glob token (`src/*.lean`) never trips either regex.

**`git-commit-scoped.sh` and its callers** (confirmed via `grep -rln "git-commit-scoped.sh"`):
every current call site in the dispatch pipeline (`orchestrator-postflight.sh`,
`orchestrate-cycle-postflight.sh`, `orchestrate-predispatch-review.sh`,
`orchestrate-batch-admit.sh`, `reconcile-task-status.sh`, `task-lock.sh`,
`general-implementation-agent.md`, `meta-builder-agent.md`, every `skill-*` doc that performs a
commit) invokes the wrapper script by path, never raw `git add`. The wrapper's own internal `git
add "${stage_paths[@]}"` (with `"${task_dir}/"` as a directory-shaped positive pathspec) is a
subprocess of that script and is structurally invisible to the PreToolUse hook, which only ever
observes the literal `tool_input.command` string of the top-level Bash call actually invoked
(e.g. `bash .claude/scripts/git-commit-scoped.sh --message ... -- "specs/192_.../"
"specs/TODO.md" "specs/state.json"`) — that literal string contains no `git[[:space:]]+add`
substring (`git-commit-scoped.sh` is one hyphenated token, not `git` + whitespace + `add`), so the
`ADD_SEGMENTS` grep never matches it at all. This mirrors the header's own documented precedent
for `git-snapshot.sh`'s internal `git add -A` (lines 41-47) exactly.

**The quote-strip blind spot** (pre-existing, not introduced by this fix): a quoted pathspec
argument to `git add` is erased by the upfront quote-strip before any detector runs. Today this
already means `git add "."` bypasses the existing bare-dot check; after this fix it will
additionally mean `git add -- "some/dir/"` bypasses the new directory check. This is a direct,
unavoidable consequence of reusing `COMMAND_SCAN` (which the dispatch's item (b) explicitly
directs) — the same quote-strip is what makes `git commit -m "fix -a bug"` and
`git commit -m "clean up some/dir/ later"` safely pass through (both required by the dispatch's
own fixture list, item (f)'s "a commit message containing a directory-looking string does not
trigger" case) — the entire quoted `-m` argument, including any embedded "git add
some/dir/"-looking prose, is replaced by `""` before the `ADD_SEGMENTS` grep ever runs, so this
case is already trivially satisfied with zero extra work. There is no way to keep that message
safety and also see inside a quoted `git add` pathspec using the same single quote-strip pass;
the dispatch does not ask for the quoted-pathspec case to be covered (every ACCEPTANCE/fixture
example is unquoted), so the correct move is to document the limitation in the header update
(item (d)), not to build a second scan variable to close it.

### Rule/Doc Enumeration Sites Needing Updates (item (d), (e))

- `hooks/guard-destructive-git.sh` header, lines 28-35: enumerates exactly the three current
  over-staging forms. Needs a fourth bullet for the directory/glob pathspec form, plus (per the
  finding above) an explicit note that a *quoted* over-broad pathspec is not caught, mirroring
  the file's own existing "Out of scope (deliberate, not an oversight)" precedent style (lines
  101-107) rather than silently claiming full coverage.
- `context/standards/git-staging-scope.md`, "Forbidden Operations" section (lines 192-208):
  lists `git add -A`, `git add .`, `git commit -am`, and bare unscoped `git commit`. Needs a
  fifth bullet for a directory/glob `git add` pathspec, worded to make clear the *sanctioned*
  explicit multi-file list (`git add -- a.lean b.lean`) is unaffected. This section currently has
  no explicit "enforced by the hook" cross-reference at all (only the destructive-command section
  of `git-workflow.md` states that); item (e) asks for the two files' "enforced by" framing to
  agree, so the natural fix is to add one short "enforced by `guard-destructive-git.sh`'s
  over-staging predicate" sentence here, matching the phrasing already used for the
  destructive-command class in `git-workflow.md`.
- `rules/git-workflow.md`, "Never Run" bullet list (currently: `git add -A`/`git add .`, `git
  commit -am`) has no bullet at all for a directory pathspec, and — like
  `git-staging-scope.md` — does not currently state that the over-staging bullets are
  hook-enforced (only the *destructive-command* section a few lines down says "This is enforced
  by the `guard-destructive-git.sh` PreToolUse Bash hook"). Add a directory/glob bullet, and add
  the same "enforced by guard-destructive-git.sh" framing to the over-staging bullets so both
  classes are described consistently — this is the concrete "'enforced by' framing" agreement
  item (e) names.

### External Resources

None consulted; this is a pure shell-hook/argv-parsing defect fully scoped to files already read
above. No external library or documentation applies.

### Recommendations

**Implementation shape** (for the planner to size/word precisely; illustrative, not literal
diff-ready code):

Inside the existing `ADD_SEGMENTS` `while` loop, after the current `-A`/bare-dot checks and
before `done`, add a third check that tokenizes `$seg` (plain word-splitting is adequate — the
file already relies on regex/word-level heuristics throughout, not a real shell tokenizer) and,
for each non-flag token (skip tokens starting with `-`, and the bare `--` separator):

1. If the token ends with `/` -> directory pathspec (trailing-slash form) -> set
   `OVERSTAGE_REASON` and break. This alone satisfies every ACCEPTANCE/fixture case named in the
   dispatch.
2. (Recommended extension, same loop, same cost) If `[ -d "$token" ]` is true -> directory
   pathspec with no trailing slash -> same treatment. Closes the fuller "resolves to a directory"
   framing from work item (a) beyond the literal trailing-slash examples.
3. (Recommended extension, same loop, same cost) If the token contains `*`, `?`, or `[` -> glob
   pathspec -> same treatment. This is the concrete mechanism for "the general form also catches
   globs" named in work item (a) (`git add src/*.lean`), without needing to actually invoke git
   to count how many files the pathspec would match.

None of the three checks touches a token that is an explicit, literal filename with no trailing
slash, no glob character, and no on-disk directory at that path — the sanctioned multi-file list
form stays permitted exactly as MUST NOT requires, with no exemption flag or allowlist needed.

**Justification for this "cheap heuristic" general form over literal "expands to more than one
file" counting**: computing the *exact* file-expansion count would require running something
like `git status --porcelain -- "$token"` per candidate token before the real `git add` runs,
adding subprocess cost and a second surface for pathspec-quoting/escaping bugs, for no
qualitative gain over the heuristic — every case the dispatch actually asks to cover (a bare
directory, a glob) is already fully and deterministically caught by the three cheap textual/
filesystem checks above, and the one case that is NOT caught (a quoted over-broad pathspec) would
not be caught by an exact-count approach either, since that approach still has to look at
`COMMAND_SCAN` (or introduce the same new non-quote-stripped scan variable the dispatch's item
(b) already tells us not to build) to find the token in the first place.

**Message/guidance (item (c))**: reuse the existing `OVERSTAGE_REASON` sentence shape (e.g.
`"git add <token> stages every file under that directory/pattern; stage explicit task-scoped
paths instead"`), naming the actual offending token so the agent sees exactly which argument
tripped the guard — mirroring how the `-A` and bare-dot messages already read.

**Test fixtures (item (f))**: the required four cases map directly onto
`test-guard-destructive-git.sh`'s existing `assert_blocked_dirty`/`assert_allowed_dirty` helpers
with zero new helper machinery needed:
- `assert_blocked_dirty "... git add -- dir/" "git add -- dir/"`
- `assert_blocked_dirty "... git add dir/" "git add dir/"`
- `assert_allowed_dirty "... explicit multi-file list" 'git add -- a.lean b.lean'`
- `assert_allowed_dirty "... commit message with directory-looking string" 'git commit -m "clean up some/dir/ later"'`
- (retained regression) confirm `git-commit-scoped.sh`'s own internal invocation shape is
  untouched — there is no existing test that drives `git-commit-scoped.sh` itself through this
  hook (correctly, since it never reaches the hook as literal text); no new test is needed for
  that non-interaction, but the report/plan should say explicitly why (see Findings above) rather
  than leave it unstated.
If the plan adopts the optional `[ -d ]` (no-trailing-slash) extension, that one case needs a
fixture that actually creates a directory inside `make_dirty_repo`'s repo before invoking `git
add dir` (no trailing slash) — a small, mechanical addition to the existing fixture helpers, not
a new pattern.

**Shellcheck**: `guard-destructive-git.sh` is Class A (`set -euo pipefail`) per
`context/standards/shell-strict-mode.md`; the new per-token loop must stay compatible with that
(guard any command whose failure is expected/tolerated, e.g. the `[ -d ... ]` test used only as
an `if` condition is already exempt from `errexit` by bash semantics). No class change needed.

## Decisions

- **Primary detector**: trailing-slash pathspec check. Fully satisfies the dispatch's stated
  ACCEPTANCE and fixture list on its own.
- **Recommended (not strictly required) extensions**: filesystem `-d` check (no-trailing-slash
  directories) and glob-metacharacter check (`*`, `?`, `[`), both layered onto the same per-token
  loop at negligible extra cost, directly answering work item (a)'s invitation to "consider the
  more general rule" and its explicit glob example — recommend the planner adopt both, since they
  cost nothing extra structurally and the dispatch names globs explicitly as in-scope for "the
  general rule."
- **Rejected**: exact pathspec-expansion counting (running git to count matched files per
  token) — materially more complex, no qualitative benefit over the heuristic given every named
  case is already covered, and does not fix the quoted-pathspec blind spot anyway.
- **Rejected**: a second, non-quote-stripped scan variable to see inside quoted pathspecs —
  contradicts the dispatch's explicit item (b) instruction to reuse `COMMAND_SCAN`, and would
  reopen the message-content false-positive class that machinery exists to close.
- **No exemption mechanism** for the new detector, consistent with the file's existing
  no-exemption stance for all over-staging forms and the dispatch's MUST NOT.

## Risks & Mitigations

- **Risk**: a quoted directory/glob pathspec (`git add -- "some/dir/"`) is not caught by this fix.
  **Mitigation**: document explicitly in the header (item (d)) and in this report (done above) as
  an accepted, pre-existing-shaped limitation, not a silent gap; it is symmetric with the
  bare-dot check's identical existing blind spot, so nothing regresses.
- **Risk**: the filesystem `-d` check could, in principle, behave differently depending on the
  hook's cwd versus the actual `git add` invocation's cwd. **Mitigation**: the hook already
  assumes cwd-equivalence for its `git status --porcelain` clean-tree check (same trust
  boundary); no new assumption is introduced.
- **Risk**: overlap with the sibling history-rewrite-predicate task, which also edits this same
  hook file. **Mitigation**: already called out by the dispatch itself (no hard dependency; the
  file-footprint admission gate serializes them; whichever lands second reconciles the header) —
  no action needed at research time beyond flagging it for the plan/implementation phase to watch.

## Context Extension Recommendations

None — `context/standards/git-staging-scope.md`, `rules/git-workflow.md`, and the hook's own
header are the complete, correct documentation surface for this predicate; this task's item (d)
and (e) already cover updating them. No new context file is warranted.

## Appendix

- Searches: repo-wide `grep -rn "git add"` across `scripts/`, `hooks/`, `agents/`, `skills/`
  (source store); `grep -rln "git-commit-scoped.sh"` across the same tree.
- Files read in full: `hooks/guard-destructive-git.sh`,
  `context/standards/git-staging-scope.md`, `rules/git-workflow.md`,
  `scripts/tests/test-guard-destructive-git.sh`, `scripts/git-commit-scoped.sh` (header/usage
  block), `context/standards/shell-strict-mode.md` (class definitions).
- Hook registration confirmed at `root-files/settings.json:51` (`bash .claude/hooks/guard-destructive-git.sh`)
  and manifest listing at `manifest.json:249` / test listing at `manifest.json:178`.
