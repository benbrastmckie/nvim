# Implementation Summary: Task #192

- **Task**: 192 - Close the directory-pathspec hole in guard-destructive-git.sh's over-staging predicate
- **Status**: [COMPLETED]
- **Started**: 2026-09-09T00:00:00Z
- **Completed**: 2026-09-09T01:10:00Z
- **Effort**: ~1 hour
- **Dependencies**: None (soft file-footprint overlap with the sibling history-rewrite-predicate task; both edit `hooks/guard-destructive-git.sh` — no conflict was encountered, header was unchanged between phases)
- **Artifacts**: plans/01_directory-pathspec-overstage-guard.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

Closed the directory-pathspec hole in `guard-destructive-git.sh`'s over-staging predicate:
`git add -- <dir>/`, `git add <dir>/`, a no-trailing-slash on-disk directory, and a glob
pathspec now all refuse on a dirty tree with the same no-exemption treatment as the existing
`-A`/`--all`/bare-`.` forms, while the sanctioned explicit multi-file list stays permitted. Work
was test-first: fixtures landed RED against the unmodified hook (4 failures), then a per-token
detector turned them GREEN (50/50 passing), then four prose enumeration sites were reconciled,
then the source store was redeployed and the deployed copy verified to fire against a live
smoke test.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — added a
  directory/glob over-staging fixture section: 4 BLOCK cases (`git add -- dir/`, `git add dir/`,
  a real on-disk no-trailing-slash directory, `git add src/*.lean`) and 3 ALLOW cases (explicit
  multi-file list, plain single file, a directory-looking string inside a commit message).
  Recorded RED against the unmodified hook before the fix.
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — added a per-token
  directory/glob pathspec check inside the existing `ADD_SEGMENTS` loop: strips the leading
  `git add` (and any captured `;`/`&`/`|` separator) via `sed`, splits the remainder with
  `read -ra` (never unquoted word-splitting, to avoid the shell's own pathname expansion
  silently consuming a literal glob token), skips flag tokens, and refuses on a trailing `/`,
  `[ -d "$token" ]`, or a `*`/`?`/`[` glob metacharacter. Refusal message names the offending
  token and repeats the "stage explicit task-scoped paths instead" guidance. Header enumeration
  extended to four over-staging forms plus a note on the quoted-pathspec blind spot (symmetric
  with the pre-existing bare-dot blind spot).
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added the
  directory/glob bullet to "Forbidden Operations", an "Enforced by `guard-destructive-git.sh`"
  paragraph naming which four forms the hook mechanically blocks, and a note near the
  hand-rolled template that its `git add "${stage_paths[@]}"` line is now correctly blocked as a
  raw top-level Bash command (use `git-commit-scoped.sh` instead).
- `agent-system/extensions/core/rules/git-workflow.md` — added the directory/glob bullet to
  "Never Run" and the matching "Enforced by `guard-destructive-git.sh`" framing sentence.
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` — added the same
  directory/glob bullet to its own "Never Run" enumeration (not in the dispatch's original list;
  see Plan Deviations).
- `agent-system/extensions/core/index-entries.json` — regenerated `line_count` for
  `standards/git-staging-scope.md` (333 -> 352) via `generate-context-line-counts.sh --write`.
- `.claude/**` — regenerated via `deploy-headless.sh` (disposable deploy artifact, not
  hand-edited).

## Decisions

- Implemented the more general three-check rule (trailing slash, `[ -d ]`, glob metacharacters)
  rather than the narrower trailing-slash-only rule, per the plan's research integration —
  negligible extra cost, no false-positive risk on the sanctioned explicit multi-file list.
- Used `read -ra` on the token-stripped segment rather than unquoted `for tok in $seg_rest`, to
  prevent the shell's own pathname expansion from silently consuming a literal glob token
  (e.g. `src/*.lean`) before the detector's own glob-metacharacter check could see it.
- Left the quoted-pathspec blind spot open by design (documented in the header), symmetric with
  the pre-existing bare-dot check's identical blind spot — closing it would require a second,
  non-quote-stripped scan variable, explicitly out of scope.

## Plan Deviations

- **Task 3 (additional item, not numbered in the original plan)**: found and updated a fourth
  over-staging enumeration site, `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md`'s
  "Never Run" section, which mirrors `rules/git-workflow.md`'s bullet-per-form enumeration
  exactly and would have misdescribed the guard if left unchanged. The plan's own Phase 3 Scope
  Hypothesis explicitly directed adding a fourth site if the grep found one enumerating the
  over-staging forms.

## Verification

- Build: N/A (shell hook, no build step)
- Tests: Passed — `test-guard-destructive-git.sh` reports 50 passed, 0 failed against both the
  source-store and the deployed copy (byte-identical, confirmed via `diff`)
- Files verified: Yes
- Shellcheck: Clean on both `guard-destructive-git.sh` and `test-guard-destructive-git.sh`
  (`nix run nixpkgs#shellcheck`, no findings)
- `validate-context-index.sh`: PASSED, 0 errors, 0 warnings (220 entries checked)
- Live smoke test against the deployed hook: `git add -- somedir/` exits 2 with the pathspec
  named in the message; `git add -- a.lean b.lean` exits 0
- `settings.json` registration confirmed unchanged (`bash .claude/hooks/guard-destructive-git.sh`)

## Impacts

- Closes the specific class of harm observed live in the dispatch's motivating incident
  (commits `ea1a561c9` / `357212808`, not retroactively repaired per the plan's explicit
  non-goal): a directory or glob `git add` pathspec can no longer silently absorb a concurrent
  dispatch's uncommitted work on a shared working tree.
- `git-commit-scoped.sh` and its callers are unaffected — its own internal `git add` runs as a
  subprocess and never appears in the hook's `tool_input.command` observation boundary (same
  structural-invisibility precedent already documented for `git-snapshot.sh`).
- The sanctioned explicit multi-file list (`git add -- a.lean b.lean`) remains the only
  compliant multi-file staging form; agents following the guard's own refusal-message guidance
  are unaffected.

## Follow-ups

- None. The known quoted-pathspec blind spot (`git add -- "some/dir/"`) is a documented,
  by-design limitation symmetric with the pre-existing bare-dot check, not a follow-up item.
- The sibling history-rewrite-predicate task (also editing `guard-destructive-git.sh`) should
  re-read the header before landing, per this plan's own risk mitigation.

## References

- specs/192_close_git_add_directory_pathspec_overstage_hole/plans/01_directory-pathspec-overstage-guard.md
- specs/192_close_git_add_directory_pathspec_overstage_hole/reports/01_directory-pathspec-overstage-hole.md
- agent-system/extensions/core/hooks/guard-destructive-git.sh
- agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh
- agent-system/extensions/core/context/standards/git-staging-scope.md
- agent-system/extensions/core/rules/git-workflow.md
