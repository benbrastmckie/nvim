# Research Report: Task #668

**Task**: 668 - Measure Claude Code harness behaviour for a worktree outside the project directory
**Started**: 2026-11-22
**Completed**: 2026-11-22
**Effort**: small (one measurement pass, no build)
**Dependencies**: 667 (research input), per the task's own edges
**Sources/Inputs**:
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (the amending record)
- A scratch git repository and a real `git worktree`, created and removed within this session
- This repository's own hook scripts and settings registrations, read as source
- This dispatch's own live session, used directly as the measurement subject
**Artifacts**:
- `specs/decisions/external-worktree-harness-behaviour.md` (the measurement record; the task's deliverable)
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- All four harness behaviours the amending record's "Measured precondition" section names were
  measured live, against a scratch repository and a real `git worktree` sited outside the
  repository and its parent directory.
- None of the four results refutes the R2 siting. No `**Amended by**` note was appended to the
  amending record.
- File tools (Read, Edit, Write) proceed, with no prompt and no refusal, for a path outside the
  project directory under `bypassPermissions` -- the one permission mode this system's dispatched
  agents could be shown to run under -- but a content-validation PreToolUse hook still fires and
  can still block a Write/Edit there, exactly as it would inside the project.
- Path-scoped `.claude/rules/*.md` frontmatter does not apply to a file outside the project
  directory: a live A/B touch of the identical glob, external-path first, showed no reminder for
  the external touch and an immediate one for the very next in-project touch.
- A `Write|Edit`-matched PreToolUse hook's payload carries the real external absolute path
  verbatim. A `Bash`-matched hook's safety decision (`guard-destructive-git.sh`) is anchored to
  the primary project tree's own git status, not to the Bash command's own `cd` target --
  measured live by blocking a destructive command aimed at a provably clean external worktree,
  because the unrelated primary tree was dirty.
- A dispatched subagent starts in the primary project directory, and its Bash tool's cwd resets
  to the primary project directory between separate calls -- never to a worktree -- confirmed
  twice, independently, including by a freshly spawned, context-free subagent.
- One item (file-tool behaviour under a non-`bypassPermissions` interactive mode) could not be
  measured from a dispatched agent and is named explicitly for the user.

## Context & Scope

The amending record rules that a batch worktree is sited "outside the repository and its parent,
in a per-user state directory," and states plainly that this siting "rests on harness behaviour
that has not been measured," naming four specific behaviours as a precondition every two-root
successor task waits on. This task's whole scope is those four measurements, taken live, with a
deliverable under `specs/decisions/` rather than any build: "This task edits no script. It
builds nothing under agent-system/**." The standing constraints additionally require every
measured behaviour to be read against a repository with isolation declared off (no worktree, no
batch branch), which is this repository's own actual state throughout the measurement, and
require the deliverable to stay repo-agnostic (no literal branch name, no consumer-repo path).

Scope explicitly excludes: building the worktree-siting mechanism itself (669's scope), building
any two-root consumer fix (670-675's scope), and re-deriving anything the prior task's research
report already measured in scratch fixtures (the primary-tree-anchored `guard-destructive-git.sh`
defect and the `git-commit-scoped.sh` exit-code behaviour under a worktree edit) -- those are
cited, not repeated.

## Findings

### Codebase Patterns

- Every hook in `.claude/settings.json` and `.claude/settings.local.json` is registered as
  `bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/<script>.sh` -- an absolute path templated on the
  primary project root, present in the hook subprocess's own environment regardless of which
  file or command a tool call targets.
- `.claude/hooks/validate-no-task-references.sh` parses a PreToolUse payload that carries, at
  minimum, `.tool_input.file_path`, `.cwd`, and `.session_id`; its own header states its
  file-path resolution is "independent of the tool's cwd," and it is exempt for any path under
  `specs/**`/`.memory/**` -- which is why this task's own deliverable, written under
  `specs/decisions/`, needed no exemption marker despite citing task numbers freely.
- `.claude/hooks/guard-destructive-git.sh`'s own design note contrasts two root-resolution
  styles directly: it reads safety-relevant state "directly and cwd-relatively," naming a
  library it declines to use specifically because that library "anchors PROJECT_ROOT to its own
  SCRIPT_DIR rather than the caller's cwd." The live measurement below shows the hook's actual
  destructive-command safety check does not, in practice, track a Bash command's own `cd`
  target either -- it tracks the primary tree.
- `.claude/docs/reference/standards/agent-frontmatter-standard.md` marks the one documented
  per-agent permission-mode override field, `permissionMode`, as "Unverified."
- `.claude/scripts/tests/test-claude-refresh-matcher.sh` models `claude --dangerously-skip-permissions`
  as the command line of "a genuine claude CLI process" in its own fixtures.

### External Resources

No external documentation was consulted; this measurement is entirely about this system's own,
locally observable harness behaviour, taken live rather than from vendor documentation.

### Live Measurements

Each of the four behaviours named in the amending record's "Measured precondition" section is
measured and attributed in full in `specs/decisions/external-worktree-harness-behaviour.md`,
including the exact tool calls/commands that produced each result. Summarized:

1. **File tools for an external path.** Read/Write/Edit all proceed (no prompt, no refusal)
   under `bypassPermissions`, subject to ordinary content-validation hooks that fire regardless
   of location. Other permission modes could not be measured from a dispatched agent.
2. **Path-scoped rules for an external path.** Do not apply; a live same-session A/B touch of the
   identical glob (external first, in-project second) shows the reminder firing only for the
   in-project touch.
3. **Hook cwd / payload path for an external file.** The payload carries the real external path
   verbatim (Write/Edit-matched hook). A Bash-matched hook's safety decision is anchored to the
   primary tree regardless of the Bash command's own `cd` target -- shown by blocking a safe
   command aimed at a provably clean external worktree because the unrelated primary tree was
   dirty.
4. **Subagent cwd, start and reset.** Starts in, and resets between Bash calls to, the primary
   project directory -- never a worktree -- confirmed twice independently.

## Decisions

- No `**Amended by**` note is appended to `batch-worktree-isolation-and-task-squash-landing.md`.
  Every measured result either supports R2's siting directly or reconfirms, from a new angle, a
  gap that record already owns and already assigns to a named successor -- none of the four
  results makes the siting itself wrong.
- The measurement record is written as a standalone file under `specs/decisions/`
  (`external-worktree-harness-behaviour.md`) rather than as edits to the amending record, since
  nothing in it is an amendment.
- The one unmeasurable item (file-tool prompt behaviour for an external path under a
  non-`bypassPermissions` interactive mode) is named explicitly rather than guessed at, per the
  dispatch's own instruction to return a user-facing question rather than assume.

## Recommendations

- Proceed with the two-root successor work (669-675) on the basis that R2's siting is
  unrefuted. No successor needs to change its approach because of this measurement.
- Carry the worktree/batch path explicitly through the dispatch file and script arguments, never
  through an assumed cwd, consistent with measurement 4's result and with R2/670's existing
  design.
- Put the one unmeasured item (file-tool prompt behaviour for an external path under a
  non-`bypassPermissions` interactive mode) to the user before any successor treats that mode as
  out of scope; see `.return-meta.json`'s `user_decision`.
- When building the hooks successor (671), treat `guard-destructive-git.sh`'s primary-tree
  anchoring (both directions: wrongly permissive on a dirty-worktree/clean-primary pairing, and
  wrongly blocking on a clean-worktree/dirty-primary pairing, the latter measured fresh here) as
  the single mechanism to fix, not two.

## Risks & Mitigations

- **Risk**: a human-driven, non-`bypassPermissions` `/orchestrate` invocation exists and was
  simply not found in this repository's static configuration, which would mean dispatched
  subagents under it inherit a prompting mode this record could not observe.
  **Mitigation**: named as a `user_decision` item rather than assumed away; see
  `.return-meta.json`.
- **Risk**: the `guard-destructive-git.sh` primary-tree-anchoring finding (measured here from the
  "safe worktree wrongly blocked" direction) could be read as a new defect requiring an
  amendment. **Mitigation**: the amending record already owns the general mechanism (its own
  defect 1) and already assigns closure to its cleanup and hooks successors; this measurement
  adds the converse direction as corroborating evidence for those successors, not a new finding
  that changes R2.
- **Risk**: a transient scratch-repository setup step (`git add -A` inside a heredoc) was itself
  blocked by `guard-destructive-git.sh`'s over-staging guard, and a subsequent chained command's
  failed `cd` silently fell through to the live primary repository, where a throwaway worktree
  and branch were briefly, really created. **Mitigation**: caught immediately via
  `git worktree list`/`git branch --list`, removed with `git worktree remove --force` and
  `git branch -D`, and confirmed via `git status --porcelain` that the primary repository's
  dirty-file set was unchanged before and after. Logged via `issue-record.sh`.

## Context Extension Recommendations

- **Topic**: hook cwd/payload mechanics for a two-root (primary tree + batch worktree) design.
- **Gap**: no existing context file states, in one place, that a `Bash`-matched PreToolUse hook's
  safety decisions are anchored to the primary tree regardless of a command's own `cd` target,
  or that a `Write|Edit`-matched hook's payload carries the real external path verbatim. Today
  this is scattered across hook source comments and the amending record's defect table.
- **Recommendation**: when the hooks successor (671) is built, consider folding this record's
  measurement 3 into whatever context file documents the two-root hook contract, so a future
  hook author does not have to re-derive it from source.

## Appendix

### Search queries / commands used

- `git status --porcelain`, `git worktree list`, `git branch --list` (orientation and cleanup)
- `grep -rn "permissionMode\|bypassPermissions\|dangerously-skip-permissions"` across
  `.claude/scripts`, `.claude/docs`, `.claude/context`
- `git init` / `git worktree add -b <branch> <external path>` (scratch fixture construction)
- `Read`/`Write`/`Edit` tool calls against the scratch worktree's files (measurement 1)
- Two same-session `Read` calls against `lua/**/*.lua`-matching paths, one external and one
  in-project, in that order (measurement 2)
- `cd <clean external worktree> && git reset --hard HEAD` as a single Bash call (measurement 3)
- `pwd`; `cd /tmp && pwd`; `pwd` as three separate Bash calls, run both in this dispatch and in a
  freshly spawned, context-free general-purpose subagent (measurement 4)

### References

- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
- `specs/decisions/external-worktree-harness-behaviour.md`
- `.claude/hooks/guard-destructive-git.sh`
- `.claude/hooks/validate-no-task-references.sh`
- `.claude/scripts/tests/test-claude-refresh-matcher.sh`
