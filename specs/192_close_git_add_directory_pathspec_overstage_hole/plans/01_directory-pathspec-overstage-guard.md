# Implementation Plan: Task #192

- **Task**: 192 - Close the directory-pathspec hole in guard-destructive-git.sh's over-staging predicate
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: None (soft file-footprint overlap with the sibling history-rewrite-predicate task; both edit `hooks/guard-destructive-git.sh`)
- **Research Inputs**: specs/192_close_git_add_directory_pathspec_overstage_hole/reports/01_directory-pathspec-overstage-hole.md
- **Artifacts**: plans/01_directory-pathspec-overstage-guard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the over-staging predicate in `agent-system/extensions/core/hooks/guard-destructive-git.sh`
so a `git add` pathspec that is a directory (`dir/`, `-- dir/`, or a no-slash on-disk directory)
or a glob (`src/*.lean`) is refused with the same no-exemption treatment the existing `-A` /
`--all` / bare-`.` forms already receive, while leaving the sanctioned explicit multi-file list
(`git add -- a.lean b.lean`) permitted. The new detector is a per-token loop layered into the
existing `ADD_SEGMENTS` while-loop, reading the already-built `COMMAND_SCAN` variable so
argv-anchoring, quote-stripping, and comment-stripping are reused rather than duplicated. Work is
test-first: fixture cases land RED against the unmodified hook, then the predicate turns them
GREEN, then the three prose enumeration sites (hook header, `git-staging-scope.md`,
`rules/git-workflow.md`) are brought into agreement, then the source store is redeployed and the
deployed copy verified to fire.

### Research Integration

Key findings carried into this plan:
- The gap is precise: the `ADD_SEGMENTS` loop (hook lines ~120-135) tests only whole-segment
  regexes for `-A`/`--all` and a bare `.`; it never inspects pathspec tokens at all.
- Recommended detector is a three-check per-token heuristic — trailing `/`, filesystem `[ -d ]`,
  and glob metacharacters (`*`, `?`, `[`) — all on the same loop at negligible cost. Exact
  pathspec-expansion counting was evaluated and rejected (subprocess cost, second
  quoting/escaping surface, no qualitative gain, and it does not fix the quoted blind spot either).
- None of the three checks fires on a plain literal filename, so the sanctioned explicit
  multi-file list stays permitted with no exemption flag or allowlist.
- `git-commit-scoped.sh` legitimately passes `"${task_dir}/"` to its own internal `git add`, but
  that runs as a subprocess and never appears in `tool_input.command`; the hook's literal
  observation boundary makes it structurally invisible (same precedent the header already
  documents for `git-snapshot.sh`). No exemption is needed and none is added.
- Accepted, pre-existing-shaped limitation: the upfront quote-strip erases quoted spans, so
  `git add -- "some/dir/"` is invisible to the new detector exactly as `git add "."` is invisible
  to the existing bare-dot check. This is documented in the header rather than silently omitted;
  the same quote-strip is what makes the required "commit message containing a directory-looking
  string" fixture pass with zero extra work.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied for this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Refuse `git add -- <dir>/` and `git add <dir>/` with a message naming the offending pathspec and
  pointing at the explicit-paths guidance, with no exemption mechanism.
- Extend coverage to the more general rule where it is free: a no-trailing-slash on-disk
  directory, and a glob pathspec.
- Keep the hook header's over-staging enumeration, `context/standards/git-staging-scope.md`, and
  `rules/git-workflow.md` in agreement with the implementation, including consistent "enforced by
  `guard-destructive-git.sh`" framing across both over-staging and destructive-command classes.
- Fixture coverage that is RED against the current script and GREEN after the fix.
- Shellcheck-clean under the file's existing Class A (`set -euo pipefail`) contract.

**Non-Goals**:
- No exemption mechanism, allowlist, or snapshot-marker carve-out for over-staging.
- No blocking of the sanctioned explicit multi-file list.
- No retroactive repair of commits `ea1a561c9` / `357212808`.
- No second, non-quote-stripped scan variable; no real shell tokenizer; no quoted-pathspec
  coverage.
- No changes to `git-commit-scoped.sh` or its callers.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New detector false-positives on the sanctioned explicit multi-file list, leaving agents no compliant staging form | H | L | Dedicated ALLOW fixture (`git add -- a.lean b.lean`) plus a plain-filename control; all three checks are token-shape-specific and cannot match a bare filename |
| A path-looking string inside a commit message trips the detector | M | L | Reuse `COMMAND_SCAN` (quote/comment stripped) exactly as item (b) directs; dedicated ALLOW fixture for the message case |
| Quoted directory pathspec still passes | M | H (by design) | Documented explicitly in the header update as an accepted, pre-existing-shaped limitation symmetric with the bare-dot check; nothing regresses |
| `[ -d "$token" ]` evaluates against the hook's cwd rather than the real invocation's cwd | L | L | Same trust boundary the hook's existing `git status --porcelain` check already assumes; no new assumption introduced |
| Header conflict with the sibling history-rewrite-predicate task editing the same file | M | M | File-footprint admission gate serializes the two; whichever lands second reconciles the header (re-read the header before editing) |
| Edits land in `.claude/**` and are wiped by the next regeneration | H | L | Source store `agent-system/extensions/core/**` is the sole edit target; `.claude/**` is touched only via redeploy in Phase 4 |
| `index-entries.json` `line_count` drift after editing a context standard | L | M | Regenerate/validate line counts in Phase 3 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add RED fixture cases to the guard test suite [COMPLETED]

**Goal**: Encode every ACCEPTANCE case from the dispatch's item (f) as fixtures in
`agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`, and confirm the
BLOCK-expecting ones fail (RED) against the unmodified hook so the suite is proven to be testing
the real defect rather than passing vacuously.

**Tasks**:
- [x] Read the existing suite's helper contract (`make_dirty_repo`, `run_hook_in`,
      `assert_blocked_dirty`, `assert_allowed_dirty`) and its section-comment conventions *(completed)*
- [x] Add a new clearly-labelled section for the directory/glob over-staging cases, following the
      existing "Phase N defect cases" comment style *(completed)*
- [x] BLOCK cases: `git add -- dir/`, `git add dir/`, and (if the `[ -d ]` extension is adopted in
      Phase 2) a no-trailing-slash on-disk directory case, plus a glob case `git add src/*.lean` *(completed)*
- [x] For the no-trailing-slash case only, add a small helper (or an inline `mkdir` step) that
      creates a real directory inside the fixture repo before invoking the hook, since `[ -d ]` is
      a filesystem test — mechanical extension of `make_dirty_repo`, not a new pattern *(completed: inline mkdir, no new helper)*
- [x] ALLOW cases: `git add -- a.lean b.lean` (sanctioned explicit multi-file list);
      `git commit -m "clean up some/dir/ later"` (directory-looking string in a message);
      a plain single-file `git add foo.txt` control *(completed)*
- [x] Run the suite against the UNMODIFIED hook and record which cases are RED vs. already GREEN,
      in a section comment mirroring the file's existing "Recorded RED set" convention *(completed: 46 passed, 4 failed as expected)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes roughly 5-7 new fixture cases in exactly one file
(`scripts/tests/test-guard-destructive-git.sh`) and that the existing
`assert_blocked_dirty`/`assert_allowed_dirty` helpers suffice for all but the no-trailing-slash
case. Confirm at implementation time by reading the helper definitions before writing cases; if a
case needs machinery beyond a `mkdir` inside the fixture repo, revisit rather than inventing a new
helper pattern.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` - new fixture section
  for directory/glob over-staging cases plus the ALLOW controls

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` runs to
  completion and reports failures ONLY for the new BLOCK-expecting directory/glob cases
- Every pre-existing case still passes (no regression introduced by the fixture additions)
- Each new ALLOW case passes against the unmodified hook (they must be GREEN both before and after)

---

### Phase 2: Extend the over-staging predicate and its header enumeration [COMPLETED]

**Goal**: Turn the Phase 1 RED cases GREEN by adding a per-token directory/glob check to the
existing `ADD_SEGMENTS` loop, with a pathspec-naming refusal message, and update the file header's
over-staging enumeration so the file no longer misdescribes itself.

**Tasks**:
- [x] Re-read the header (over-staging enumeration block) before editing, in case the sibling
      history-rewrite-predicate task has already landed and changed it *(completed: unchanged since Phase 1)*
- [x] Inside the existing `ADD_SEGMENTS` `while` loop, after the `-A`/bare-dot checks, add a
      per-token pass over the segment: skip the leading `git add` words, any token starting with
      `-`, and the bare `--` separator *(completed)*
- [x] For each remaining (pathspec) token, set `OVERSTAGE_REASON` and `break` when: (1) the token
      ends with `/`; (2) `[ -d "$token" ]` is true; (3) the token contains `*`, `?`, or `[` *(completed)*
- [x] Word-splitting on the segment is adequate and consistent with the file's existing
      regex/word-level heuristics — do NOT introduce a tokenizer, and do NOT introduce a second
      non-quote-stripped scan variable *(completed: used `read -ra` on $seg_rest, no tokenizer, no second scan variable)*
- [x] Compose the refusal message in the existing `OVERSTAGE_REASON` sentence shape, naming the
      offending token verbatim and repeating the "stage explicit task-scoped paths instead"
      guidance the `-A` branch gives *(completed)*
- [x] Add a fourth bullet to the header's over-staging enumeration for the directory/glob pathspec
      form *(completed)*
- [x] Add a short header note, in the style of the file's existing "Out of scope (deliberate, not
      an oversight)" block, stating that a *quoted* over-broad pathspec is not caught — symmetric
      with the bare-dot check's identical existing blind spot *(completed)*
- [x] Keep the no-exemption stance explicit: the new form joins the same class the header already
      says a snapshot marker must NEVER exempt *(completed: header now says "these four forms")*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the change is confined to one file and to the existing
`ADD_SEGMENTS` loop plus the header comment block — no new function, no new scan variable, no
change to the `COMMIT_SEGMENTS` detector or the destructive-command chain. Confirm with
`git diff --stat` on the source store before committing; a diff touching a second detector or
introducing a new top-level variable means the scope hypothesis was wrong and needs review.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - per-token directory/glob check in
  the `ADD_SEGMENTS` loop; new refusal message; header over-staging enumeration + quoted-pathspec
  limitation note

**Verification**:
- Full test suite green: `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh`
  reports 0 failures, including every Phase 1 case and every pre-existing case
- `shellcheck agent-system/extensions/core/hooks/guard-destructive-git.sh` is clean under the
  file's Class A (`set -euo pipefail`) contract per `context/standards/shell-strict-mode.md`
- Manual spot-check of the stderr text: the refusal names the actual offending pathspec token
- Header enumeration now lists four over-staging forms and matches the implementation exactly

---

### Phase 3: Reconcile the rule and standard enumerations [NOT STARTED]

**Goal**: Bring `context/standards/git-staging-scope.md` and `rules/git-workflow.md` into
agreement with the implemented predicate, including consistent "enforced by
`guard-destructive-git.sh`" framing for the over-staging class.

**Tasks**:
- [ ] `context/standards/git-staging-scope.md`, "Forbidden Operations": add a bullet for a
      directory or glob `git add` pathspec, worded so the sanctioned explicit multi-file list is
      visibly unaffected
- [ ] Same file: add a short "enforced by `guard-destructive-git.sh`'s over-staging predicate"
      sentence, matching the phrasing `git-workflow.md` already uses for the destructive-command
      class
- [ ] `rules/git-workflow.md`, "Never Run": add a directory/glob `git add` bullet, and add the same
      "enforced by `guard-destructive-git.sh`" framing to the over-staging bullets so both classes
      read consistently
- [ ] Note in `git-staging-scope.md` (near the illustrative hand-rolled template that shows
      `git add "${stage_paths[@]}"` with a directory pathspec) that running that template's
      `git add` as a raw top-level Bash command is now correctly blocked, and that
      `git-commit-scoped.sh` is the sanctioned path — do not delete the template
- [ ] Regenerate context line counts and validate the index:
      `bash .claude/scripts/generate-context-line-counts.sh` (or equivalent) then
      `bash .claude/scripts/validate-context-index.sh`, so
      `agent-system/extensions/core/index-entries.json`'s `line_count` for
      `standards/git-staging-scope.md` does not drift

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly three prose enumeration sites need changing
(the hook header handled in Phase 2, `git-staging-scope.md`, `rules/git-workflow.md`) plus one
generated `line_count`. Confirm before editing with
`grep -rn "git add -A\|git add \." agent-system/extensions/core/{rules,context,agents,skills}`;
if a fourth site enumerates the over-staging forms, add it to this phase rather than leaving it
inconsistent.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - directory/glob bullet in
  Forbidden Operations; "enforced by" framing; hand-rolled-template note
- `agent-system/extensions/core/rules/git-workflow.md` - directory/glob bullet in Never Run;
  "enforced by" framing on the over-staging bullets
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` for the edited
  context standard

**Verification**:
- `grep -n "directory" agent-system/extensions/core/context/standards/git-staging-scope.md` and the
  corresponding grep on `rules/git-workflow.md` both show the new bullets
- `bash .claude/scripts/validate-context-index.sh` reports no `line_count` drift
- Read-back check: the four over-staging forms named in the hook header, in
  `git-staging-scope.md`, and in `git-workflow.md` are the same four, with no fifth form implied
  anywhere
- No task-number references introduced outside `specs/**`

---

### Phase 4: Redeploy and verify the deployed hook fires [NOT STARTED]

**Goal**: Regenerate the `.claude/` deploy tree from the source store and confirm the extended
predicate actually fires from the deployed copy that `settings.json` registers, closing the
dispatch's ACCEPTANCE requirement.

**Tasks**:
- [ ] Run the headless deploy: `bash .claude/scripts/deploy-headless.sh` (non-destructive resync)
- [ ] Confirm the deployed `.claude/hooks/guard-destructive-git.sh` contains the new detector
      (diff or grep against the source-store copy)
- [ ] Run the deployed test suite copy (`.claude/scripts/tests/test-guard-destructive-git.sh`) and
      confirm it is green — the suite's relative `HOOK` path resolves in both source-store and
      deployed mode by design
- [ ] Live smoke test in a throwaway dirty repo: pipe a synthetic PreToolUse payload for
      `git add -- somedir/` into the deployed hook and confirm exit 2 with the pathspec named,
      and for `git add -- a.lean b.lean` confirm exit 0
- [ ] Confirm `settings.json`'s registration still points at
      `bash .claude/hooks/guard-destructive-git.sh` (unchanged; verify, do not edit)

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None in the source store; this phase regenerates `.claude/**` via the sanctioned deploy engine
  only (never hand-edited)

**Verification**:
- `diff agent-system/extensions/core/hooks/guard-destructive-git.sh .claude/hooks/guard-destructive-git.sh`
  shows no substantive divergence
- `bash .claude/scripts/tests/test-guard-destructive-git.sh` reports 0 failures
- Live smoke test: deployed hook exits 2 on `git add -- somedir/` with the pathspec in the stderr
  message, and exits 0 on the explicit multi-file list

---

## Testing & Validation

- [ ] `git add -- <dir>/` is refused, with the offending pathspec named in the message
- [ ] `git add <dir>/` is refused, with the offending pathspec named in the message
- [ ] A no-trailing-slash on-disk directory pathspec is refused (if the `[ -d ]` extension is adopted)
- [ ] A glob pathspec (`git add src/*.lean`) is refused
- [ ] `git add -- a.lean b.lean` (explicit multi-file list) is permitted
- [ ] A commit message containing a directory-looking string does not trigger the detector
- [ ] `git-commit-scoped.sh` invocations remain unblocked (structurally, by the observation
      boundary — recorded as reasoning in the plan/summary, no new test needed)
- [ ] Every pre-existing case in `test-guard-destructive-git.sh` still passes
- [ ] `shellcheck` clean on the edited hook
- [ ] Fixture BLOCK cases were verified RED against the unmodified hook before the fix
- [ ] Deployed copy verified to fire after redeploy

## Artifacts & Outputs

- Modified `agent-system/extensions/core/hooks/guard-destructive-git.sh` (predicate + header)
- Modified `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` (fixtures)
- Modified `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Modified `agent-system/extensions/core/rules/git-workflow.md`
- Regenerated `agent-system/extensions/core/index-entries.json` line count
- Regenerated `.claude/` deploy tree (disposable artifact, not committed as hand-authored work)
- Implementation summary under `specs/192_close_git_add_directory_pathspec_overstage_hole/summaries/`

## Rollback/Contingency

Each phase is committed separately with scoped staging via `git-commit-scoped.sh`, so reverting is
a single `git revert` of the offending commit. If the new detector proves to false-positive on a
form not anticipated here, the correct response is to narrow the detector (e.g. drop the `[ -d ]`
or glob check, keeping the trailing-slash check that alone satisfies ACCEPTANCE) — never to add an
exemption mechanism, which the dispatch explicitly forbids. If the redeploy in Phase 4 surfaces a
divergence, re-run `deploy-headless.sh` rather than hand-editing `.claude/**`.
