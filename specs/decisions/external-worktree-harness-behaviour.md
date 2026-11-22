# Decision Record: Harness Behaviour for a Worktree Path Outside the Project Directory

This record states four measured harness behaviours against a scratch repository with a real
`git worktree` sited outside the repository and its parent directory. It is the measured
precondition `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (the
"amending record") names in its "Measured precondition" section: that record's R2 sites a batch
worktree outside the repository, in a per-user state directory, and defers the siting's
feasibility to these four measurements.

## Verdict

None of the four results refutes the siting. Two support it directly (file tools proceed for an
external path, and a dispatched subagent never implicitly roots itself at a worktree, so a
two-root design cannot rely on an ambient cwd switch and must carry the worktree path
explicitly, exactly as the amending record's R2 already requires). Two reconfirm, from a fresh
angle, gaps the amending record already owns as open and already assigns to named successor
work, rather than surfacing anything new that would change R2 itself. No `**Amended by**` note
is appended to the amending record.

## Attribution

Every result below was measured directly by a dispatched research agent, in one live session,
against a scratch repository and a real `git worktree` created for this purpose (never the
primary repository). One item inside measurement 1 could not be measured this way and is stated
as such, with a recommendation to put it to the user.

**Per-measurement label.** All four measurements are **agent-measured**; none is user-supplied:

1. File tools for a path outside the project directory — agent-measured (under `bypassPermissions`
   only; see "Residuals" for the one item that is neither agent-measured nor user-supplied).
2. Path-scoped rules for a path outside the project directory — agent-measured.
3. Hook working directory and PreToolUse/PostToolUse payload path — agent-measured.
4. Subagent working directory, start and reset — agent-measured, twice independently (this
   dispatch's own session, and a second, freshly spawned general-purpose subagent).

Nothing in this record is user-supplied as of this writing. See "Residuals" for the one
open item that needs the user.

## Evidence read

- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`, in full, for the
  "Measured precondition" section's exact wording and R2's siting.
- This repository's own hook registrations (`.claude/settings.json`, `.claude/settings.local.json`)
  and two hook scripts' source (`.claude/hooks/guard-destructive-git.sh`,
  `.claude/hooks/validate-no-task-references.sh`), read to find the mechanism each hook actually
  uses, before measuring it live.
- `.claude/scripts/tests/test-claude-refresh-matcher.sh`, read for the process-command-line
  shape its fixtures model as a "genuine claude CLI process."
- `.claude/docs/reference/standards/agent-frontmatter-standard.md`, read for the documented
  status of a per-agent permission-mode override.
- A sibling repository's own Nix-packaged `claude` launcher wrapper, read only to confirm that
  permission-mode flags are passed through unmodified by that wrapper rather than decided by it
  (no path or content from that repository is otherwise used here, per the repo-agnostic
  constraint this record is written under).

## Measurement 1: file tools (Read, Edit, Write) for a path outside the project directory

**Permission modes this system dispatches under.** Every dispatched agent in this system
(research, plan, implement, and any subagent one of those spawns) inherits its permission mode
from the root session rather than selecting one of its own: the per-agent frontmatter field for
this (`permissionMode`) is documented in this repository as "Unverified," and a subagent's own
`mode` parameter is "Deprecated; ignored. Subagents inherit the parent session's permission
mode." This dispatch's own session is, and reports itself as, running in `bypassPermissions`
mode (`claude --dangerously-skip-permissions`); a process-matcher test suite in this repository
models exactly that command line as "a genuine claude CLI process." No evidence of a second,
differently-moded launch path for a dispatched run was found in static configuration. On that
evidence, this system dispatches agents under exactly one permission mode in every run this
record could establish: `bypassPermissions`.

**Measured, under `bypassPermissions`.** Created a scratch repository and a real `git worktree`
on a side branch outside the repository and its parent directory (siting mirrors R2's design).
Then, from this dispatch's own live session (project root unrelated to the scratch repository):

- `Read` on the worktree's `README.md` and its tracked `lua/existing.lua` -- both returned file
  content immediately, no prompt, no refusal.
- `Write` to a new file under the worktree's `lua/` directory, and `Edit` on the worktree's
  tracked `lua/existing.lua` -- both succeeded immediately, no prompt, no refusal, confirmed
  landed by `git status --porcelain`/`git diff` run inside the worktree afterward.

**One nuance measured in the same pass, not a refusal of location.** A first attempt at the
`Write` and the `Edit` above (content phrased as "task 668 measurement") was blocked by this
repository's own `Write|Edit`-matched content-validation PreToolUse hooks (`no task-number
citations in deliverables`), with the hook's own error message quoting the external path
verbatim. Rephrasing without the triggering text let both calls through cleanly. File tools
proceeding for an external path is therefore not the whole story: a registered content-gating
hook still fires, and can still block, for a file outside the project directory exactly as it
would for one inside it.

**Not measured, needs the user.** Whether file tools prompt or refuse for an external path under
a non-`bypassPermissions` mode (`default`, `plan`, `acceptEdits`) cannot be observed from a
dispatched agent: those modes' prompts require an interactive human response, and no evidence
of a dispatched run ever using one of those modes was found. If the user ever drives `/orchestrate`
(or any agent dispatch) from a session not started with `--dangerously-skip-permissions`, this
item needs the user to say so and, ideally, report what they see when a subagent's tool call
targets a path outside the project directory under that mode.

## Measurement 2: path-scoped rules (`.claude/rules/*.md` `paths:` frontmatter) for a path outside the project directory

**Measured.** This dispatch's own session already carries a path-scoped rule matching
`lua/**/*.lua` (this repository's own Neovim Lua rule). In one session, in order:

1. First touch of any path matching `lua/**/*.lua` this session: `Read` on the scratch worktree's
   tracked `lua/existing.lua` (the external path). No rule content was injected.
2. Very next touch of a path matching the same glob: `Read` on a path under this repository's own
   `lua/` directory (in-project). The rule's full content was injected as a system-reminder
   immediately, on that single touch -- including once on a nonexistent in-project path, before
   any successful in-project read, ruling out "the read succeeded" as the trigger.

Because the external touch came first in the session and still produced nothing, dedupe (a rule
shown once per session) cannot explain the external miss; the in-project touch that immediately
followed is what first triggered the reminder. Path-scoped rule matching did not fire for the
file outside the project directory, and fired on the very next matching touch once the file was
back inside the project directory.

**Structural note.** The scratch repository's own `.claude/rules/*.md` (written with the same
`paths:` frontmatter, for a parallel check) never had a chance to apply regardless of outcome:
a session's rule set loads once, from the project the session itself is rooted in, not from
whichever repository a touched file happens to belong to. For the real design this measurement
serves, that distinction does not matter -- a batch worktree is a worktree of the *same*
repository, so it carries the identical `.claude/rules/*.md` content as the primary tree. The
open question was purely whether the `paths:` glob still matches once the touched path's
location is outside the project root, and the two-touch comparison above answers it: no.

## Measurement 3: hook working directory and PreToolUse/PostToolUse payload path for a file outside the project directory

**Measured, payload path.** The same blocked `Write`/`Edit` calls from measurement 1 are direct
evidence here: the content-validation hook's own block message quoted the full, real, external
absolute path verbatim -- not rewritten, not relativized, not substituted with anything inside
the project tree. A `Write|Edit`-matched PreToolUse hook's payload carries the real external
path.

**Measured, hook working directory (Bash-matched hook).** Read `guard-destructive-git.sh`'s own
source first: its design note states it reads safety-relevant state "directly and cwd-relatively,"
explicitly contrasted with a library it declines to use because that library "anchors
PROJECT_ROOT to its own SCRIPT_DIR rather than the caller's cwd." That comment describes a
design choice, not a measurement, so it was tested live: the scratch worktree was committed to a
fully clean state (`git status --porcelain` empty), while the primary project tree was, and
stayed, genuinely dirty throughout (pre-existing, unrelated uncommitted changes). A single Bash
call, `cd <clean external worktree> && git reset --hard HEAD`, was issued. It was **blocked**,
citing "The working tree has uncommitted changes and this command would discard them" -- a
claim true of the primary tree and false of the actual `cd`-target tree. The hook's safety
decision is anchored to the primary project tree's own git status, independent of the Bash
command's own `cd` target.

This is the converse of, and reconfirms from the opposite direction, a result the amending
record already attributes to its own research input: a destructive command aimed at a dirty
worktree is wrongly *allowed* when the primary tree is clean; this measurement shows a safe
command aimed at a clean worktree is wrongly *blocked* when the primary tree is dirty. Both
directions are the same root mechanism, already named in the amending record as owned by its
cleanup and hooks successors, not a new gap.

**Corroborating, not independently re-measured.** Every hook in `.claude/settings.json` is
registered as `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/<script>.sh`, an absolute path templated
on the primary root -- confirming `$CLAUDE_PROJECT_DIR` is populated with the primary tree's root
in a hook's own environment regardless of which file or command a tool call targets, consistent
with the live result above.

**Not measured.** The hook subprocess's own raw OS-level `pwd` (as distinct from
`$CLAUDE_PROJECT_DIR` or whatever a given hook script resolves internally) was not independently
isolated. Doing so would have required adding temporary diagnostic instrumentation to this
machine's own live, personal `.claude/settings.local.json` mid-session; that was judged too
invasive for a measurement pass and was not attempted. The live result above already answers the
behavioural question this measurement exists to settle (hook decisions do not track the tool
call's actual target tree), so this residual does not change the verdict.

## Measurement 4: subagent working directory for a Bash tool call, start and reset

**Measured, twice, independently.** From this dispatch's own session: a bare `pwd` (no prior
`cd`) returned the primary project directory. A later Bash call ran `cd /tmp && pwd`, returning
`/tmp`. The very next, separate Bash call ran a bare `pwd` again, with no `cd`: it returned the
primary project directory again, not `/tmp`. A second, freshly spawned general-purpose subagent
(no shared context with this dispatch) was asked to run the same three-call sequence and
reported the identical pattern: primary project directory, then `/tmp`, then primary project
directory again.

A dispatched subagent starts in the primary project directory, and its Bash tool's working
directory resets, between separate tool calls, back to the primary project directory -- never to
wherever a prior call's `cd` left it, and never to a worktree, even though a real external
worktree existed for the whole of this measurement pass. This matches this harness's own
documented behaviour for an agent thread's Bash tool.

**Consequence for the design this measures.** Because a subagent's cwd always snaps back to the
primary tree between calls, no two-root mechanism can rely on an ambient cwd switch to reach the
batch worktree; the worktree's path must be carried explicitly (a dispatch-file field, a script
argument), exactly as the amending record's R2 and its two-root successor already require. This
measurement supports that requirement rather than complicating it.

**Not exercised.** The harness's own per-agent worktree option (an `isolation` parameter on the
agent-dispatch primitive, independent of the manually-managed `git worktree` this record
measures) was not invoked. The amending record's R5 keeps that option prohibited for this
design, and exercising it would measure a different mechanism than the one R2 relies on.

## Residuals

Two items were identified during measurement but not resolved by it. Neither changes the
verdict.

1. **File-tool behaviour for an external path under a non-`bypassPermissions` mode** (`default`,
   `plan`, `acceptEdits`). Not observable from a dispatched agent: those modes' prompts require an
   interactive human response, and no evidence of a dispatched run ever using one of those modes
   was found. The verdict does not turn on this residual because every dispatched run this record
   could establish ran under `bypassPermissions`, which was measured directly. As of this writing
   this item is still open and unanswered; it is re-relayed as a non-blocking `user_decision`
   rather than guessed.
2. **The hook subprocess's own raw OS-level `pwd`**, as distinct from `$CLAUDE_PROJECT_DIR` or
   whatever a given hook script resolves internally. Deliberately not isolated: doing so would
   have required adding temporary diagnostic instrumentation to this machine's own live, personal
   settings mid-session, judged too invasive for a measurement pass. The verdict does not turn on
   this residual because the live result already answers the behavioural question this
   measurement exists to settle (a Bash-matched hook's safety decision does not track the Bash
   command's own `cd` target; it tracks the primary tree), independent of what the subprocess's
   raw `pwd` happens to report.

## Appendix: exact commands and tool calls per measurement

- **Measurement 1 (file tools).** `Read` on the worktree's `README.md` and on its tracked
  `lua/existing.lua`. `Write` to a new file under the worktree's `lua/` directory. `Edit` on the
  worktree's tracked `lua/existing.lua`. All four issued from this dispatch's own live session
  (project root unrelated to the scratch repository), against a scratch repository and worktree
  sited outside the repository and its parent on a side branch.
- **Measurement 2 (path-scoped rules).** Two same-session `Read` touches of the `lua/**/*.lua`
  glob, in order: first the scratch worktree's tracked `lua/existing.lua` (the external path,
  including one touch of a nonexistent in-project path before any successful in-project read),
  second a path under this repository's own `lua/` directory (in-project).
- **Measurement 3 (hook cwd and payload path).** One Bash call: `cd <clean external worktree> &&
  git reset --hard HEAD`, issued while the external worktree was committed to a fully clean state
  and the primary project tree was, and stayed, genuinely dirty throughout. The blocked
  `Write`/`Edit` calls from measurement 1 supply the payload-path evidence (the content-validation
  hook's own block message quoting the full external path verbatim).
- **Measurement 4 (subagent cwd).** Three separate Bash calls, `pwd`, `cd /tmp && pwd`, `pwd`, run
  both in this dispatch's own session and in a freshly spawned, context-free general-purpose
  subagent given the identical three-call sequence.

## Provenance

- Amends nothing. No result refutes R2's siting in `batch-worktree-isolation-and-task-squash-landing.md`,
  so no dated amendment note is appended to that record's R2 or "Measured precondition" sections.
- All four measurements were produced in one dispatched research session, against a scratch
  repository and a real `git worktree` created and removed within that session; none was taken
  against the primary repository.
