# Research Report: Task #567

**Task**: 567 - Port git-commit-phase.sh's deployed-tree containment strip into git-commit-scoped.sh's V10 resolution block
**Started**: 2026-11-22
**Completed**: 2026-11-22
**Effort**: small (single, well-bounded script edit plus two test-suite edits)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/git-commit-phase.sh`, `git-commit-scoped.sh`,
  their test suites, `agent-system/extensions/core/context/standards/git-staging-scope.md`
**Artifacts**:
- `specs/567_port_containment_strip_to_git_commit_scoped/reports/01_port-containment-strip.md` (this report)
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- The source-store copy to edit is `agent-system/extensions/core`, resolved via
  `.claude-extensions.json`'s `extensions.core.source_dir`. `.claude/scripts/*` is a deploy
  mirror; edits there would be silently wiped on next regeneration.
- Site 2's deployed-tree strip (`git-commit-phase.sh`, inside its Containment Self-Check) is a
  small, self-contained loop that drops every `file_scope_arr` entry equal to
  `.claude`/`.claude/` or prefixed `.claude/`, with a `warn()` call per stripped entry, followed by
  a non-emptiness re-test that falls through to the existing fail-open path if nothing survives.
  It is a pure string-prefix test, never a filesystem check.
- Site 3's V10 resolution in `git-commit-scoped.sh` populates `containment_scope_arr` from the
  task's raw declared `file_scope` (lines ~567-573) and *then* immediately widens it with the
  own-task-directory, engine-written-state, and derived-output splices, all gated behind one
  `if [ "${#containment_scope_arr[@]}" -gt 0 ]` guard (line 575). The strip must be spliced in
  between those two points — after the raw read, before the non-emptiness guard — to exactly
  mirror Site 2's ordering (strip, then test for emptiness, so the existing splices stay inside
  the guard unmoved).
- The within-dispatch `proposed_file_scope_lookup` annotation mechanism that sits alongside the
  Site-2 strip is explicitly **not** part of this port — the dispatch description and the
  standards doc's own abandoned-union note confine this task to the strip only.
- Verification path: `test-git-commit-phase.sh` Case 26 already runs through the *real*
  `git-commit-scoped.sh` (it is copied, not stubbed, into the fixture repo), so once the port
  lands, Case 26 can upgrade its narrowed "Site 2 only" assertions to the same full end-to-end
  shape Case 18 already uses (rc, `git show`, whether `src/a.txt`/`.claude`-declared path land).
  A new `test-git-commit-scoped.sh` Z-case (continuing the Z1-Z18 V10 series, i.e. Z19) is needed
  to pin the Site-3 behavior directly, since no existing Z-case uses a `.claude/`-only
  `file_scope`. Case 20's idempotence fixture is untouched by this change (it dirties
  `other/outside.txt`, not a `.claude/` path) and should simply be re-run as a non-regression
  check, not modified.

## Context & Scope

This task closes a documented, deliberately-left-open residual: `context/standards/
git-staging-scope.md`'s "Three Containment sites, not one" section states explicitly that "the
deployed-tree strip and the within-dispatch `proposed_file_scope` lookup are site-2-only," and
that "a `file_scope` carrying a bare `.claude/` entry is therefore stripped ... at site 2, but
V10's own `containment_scope_arr` resolution at site 3 still reads that same bare `.claude/` entry
unstripped." The same section names this task's own intended remedy verbatim: "a future task to
close by porting the SAME strip into site 3's V10 resolution block."

Scope, per the dispatch: `git-commit-scoped.sh` and its test suite. The companion
`test-git-commit-phase.sh` is touched only for verification (restoring Case 26's narrowed
assertion, re-checking Case 20), not for behavior changes — `git-commit-phase.sh` itself already
carries the strip and needs no edit.

## Findings

### Codebase Patterns

**Source-store resolution.** `.claude-extensions.json`'s `extensions.core.source_dir` resolves to
`/home/benjamin/.config/nvim/agent-system/extensions/core`. Both `.claude/scripts/git-commit-
{phase,scoped}.sh` and `agent-system/extensions/core/scripts/git-commit-{phase,scoped}.sh` exist
on disk (deploy mirror vs. source store respectively); this task's edits belong exclusively in
the `agent-system/extensions/core/` copies (and their `scripts/tests/` counterparts), per
`rules/source-store-deploy-boundary.md`.

**Site 2's exact strip block** — `git-commit-phase.sh`, inside the Containment Self-Check, after
`file_scope_arr` is populated from `specs/state.json` and after the (deliberately non-admitting)
`proposed_file_scope_lookup` is built, but *before* the non-emptiness `if` guard that triggers the
own-task-directory / engine-written-state / derived-output splices:

```bash
_fsa_stripped=()
for _fsa_entry in "${file_scope_arr[@]}"; do
  case "$_fsa_entry" in
    .claude|.claude/|.claude/*)
      warn "stripped deployed-tree file_scope entry '${_fsa_entry}': never a legitimate file_scope member (see rules/source-store-deploy-boundary.md); declare a whole-deployed-tree claim with the \`__WHOLE_TREE__\` sentinel instead"
      ;;
    *)
      _fsa_stripped+=("$_fsa_entry")
      ;;
  esac
done
file_scope_arr=("${_fsa_stripped[@]}")

if [ "${#file_scope_arr[@]}" -gt 0 ]; then
  ... # own-task-directory, engine-written-state, derived-output splices unchanged
```

This is a pure structural prefix test on the string (`.claude`, `.claude/`, or `.claude/*`),
never a filesystem/existence check, and it fires unconditionally for every declared entry
regardless of whether the path actually exists on disk.

**Site 3's exact splice point** — `git-commit-scoped.sh`, inside its V10 effective-scope
resolution block (comment header: "V10 effective-scope resolution (--task opt-in only..."):

```bash
containment_scope_arr=()
if [ -n "$contention_task_number" ] && [ -f "specs/state.json" ]; then
  task_entry_json=""
  if source "${SCRIPT_DIR}/lib/task-lookup-lib.sh" 2>/dev/null; then
    task_entry_json="$(task_lookup_entry "$contention_task_number" "specs/state.json" 2>/dev/null)" || task_entry_json=""
  fi

  if [ -n "$task_entry_json" ]; then
    file_scope_json="$(echo "$task_entry_json" | jq -c '.file_scope // empty' 2>/dev/null)" || file_scope_json=""
    if [ -n "$file_scope_json" ] && [ "$file_scope_json" != "null" ] && [ "$file_scope_json" != "[]" ] \
       && echo "$file_scope_json" | jq -e 'type == "array" and (all(.[]; type == "string"))' >/dev/null 2>&1; then
      while IFS= read -r s; do
        [ -n "$s" ] && containment_scope_arr+=("$s")
      done < <(echo "$file_scope_json" | jq -r '.[]' 2>/dev/null)

      # <-- THE STRIP BELONGS HERE: after raw population, before the non-emptiness guard below.

      if [ "${#containment_scope_arr[@]}" -gt 0 ]; then
        # own-task-directory, engine-written-state, derived-output splices — unchanged
        ...
```

The insertion point is precisely between the `done < <(... jq -r '.[]' ...)` loop (raw population,
mirroring Site 2's own `file_scope_arr+=("$s")` loop) and the
`if [ "${#containment_scope_arr[@]}" -gt 0 ]; then` guard (mirroring Site 2's identical guard).
Porting the strip means re-running the same `case` loop over `containment_scope_arr` at that point
and reassigning it to the stripped result — `git-commit-scoped.sh` has no `warn()` helper
function; every other V10/V9/V13 warning in this script is an inline `echo "WARN: git-commit-
scoped.sh ..." >&2`, so the ported strip's warning should follow that same inline convention
rather than introducing a `warn()` call this script does not otherwise have.

**Naming collision note**: Site 2 names its loop variables `_fsa_stripped`/`_fsa_entry`
(underscore-prefixed, scoped to that function/script's own internal convention). Site 3 uses
`containment_scope_arr` as the variable being built, not `file_scope_arr`; a direct copy-paste
must rename the loop target/source variable to `containment_scope_arr`, not leave it referencing
`file_scope_arr` (which does not exist in `git-commit-scoped.sh`).

**No issue-record.sh call for the strip itself.** Site 2's strip only calls `warn()` per stripped
entry — it does not call `issue-record.sh`. This is consistent with the strip operating on the
*scope definition itself* (which entries are legitimate scope members), not on a *candidate path*
being tested against that scope (which is what triggers `issue-record.sh --class "scope
excursion"` elsewhere in both scripts). The port should preserve this: warn only, no
`issue-record.sh` call, for parity with Site 2 and because the strip is evaluated once per
invocation on the declared scope, not once per tested pathspec.

### Documentation needing an update after the code change

`context/standards/git-staging-scope.md`'s "A third asymmetry, deliberately left open" paragraph
(in the "Three Containment sites, not one" section) explicitly states the strip is "site-2-only"
and that Site 3 "still reads that same bare `.claude/` entry unstripped." Once the port lands,
this paragraph becomes stale and must be revised to state the strip is now ported to Site 3 too,
while the paragraph's *second* claim (`proposed_file_scope_lookup` is site-2-only) remains
correct and should be preserved, not deleted — only the deployed-tree-strip half of that
paragraph is being closed by this task, not the within-dispatch-lookup half. The adjacent "Named
residuals, recorded explicitly rather than chased to parity in one pass" section should also be
checked for any cross-reference to this same residual.

### Test Suite: Verification Path

**`test-git-commit-phase.sh` is the right place to restore Case 26's full assertion.**
`build_repo()` (the fixture constructor every case in that suite uses) copies the *real*
`git-commit-scoped.sh` from the source store into `<repo>/.claude/scripts/git-commit-scoped.sh`
and `chmod +x`'s it — it is never a stub in this suite. Case 26 (lines ~1081-1123) currently
asserts only that Site 2's own Containment Self-Check fails open (no drop warning, nothing
proposed into `proposed_file_scope`) and explicitly documents, in its own header comment, that it
deliberately does *not* assert the end-to-end commit outcome because Site 3 was unpatched. Once
the port lands, that comment's premise is resolved and the test should additionally assert (mirroring
Case 18's own style): `rc=0`, `git show --name-only` contains `src/a.txt` (the file the fixture
dirties), and no `WARNING: ... dropping out-of-scope path` appears anywhere in `$out26` — i.e. the
`.claude/`-only declared scope now fails open at *both* sites, end to end.

**`test-git-commit-scoped.sh` needs a new, dedicated V10 case.** The Z1-Z18 series (all driven by
the `build_repo_with_scope <task_number> <project_name> [file_scope_json]` fixture helper) is the
existing V10 regression suite for this script; no existing Z-case declares a `.claude/`-only
`file_scope`. A new case (continuing the sequence as Z19) should call
`build_repo_with_scope 999 probe '[".claude/"]'`, then commit `specs/999_probe/a.txt` (and
optionally the out-of-task-directory sibling `specs/998_sibling/out.txt` that same helper already
seeds, to prove the scope is fully disabled rather than merely still containing the task
directory) with `--task 999`, and assert `rc=0`, both land in `HEAD` via `git show`, and no V10
`WARN: ... dropping out-of-scope pathspec` appears — the same "check fully disabled" shape Z9
already asserts for `--task` omitted, but reached here via scope-strips-to-empty rather than via
omitting `--task` at all.

**Case 20 in `test-git-commit-phase.sh` needs no code change, only a re-run.** Case 20's fixture
dirties `other/outside.txt` (a genuine, non-`.claude` out-of-scope path) and asserts the repeated
drop appends to `proposed_file_scope` exactly once — this is the idempotence regression the
rejected admit-via-union design broke (per the "WITHIN-DISPATCH proposed_file_scope LOOKUP
(PART B)" header subsection and the dispatch description's own citation). Because this task ports
only the strip — never the `proposed_file_scope` lookup/union — Case 20's own mechanism is
untouched by this change. The dispatch's instruction to "re-check" it is a regression-safety
verification step for the implementation phase (run the full suite, confirm Case 20 still passes
unmodified), not a hint that Case 20 itself needs editing.

## Recommendations

1. In `git-commit-scoped.sh`'s V10 resolution block, immediately after the `while IFS= read -r s;
   do ... done` loop that populates `containment_scope_arr` from `file_scope_json` and immediately
   before the `if [ "${#containment_scope_arr[@]}" -gt 0 ]; then` guard, insert a strip loop that
   mirrors Site 2's `case "$_fsa_entry" in .claude|.claude/|.claude/*) ... ; *) ... ;; esac`
   pattern, operating on and reassigning `containment_scope_arr`, with an inline
   `echo "WARN: git-commit-scoped.sh stripped deployed-tree file_scope entry '...' ..." >&2`
   per stripped entry (matching this script's existing inline-echo convention, not Site 2's
   `warn()` helper, which this script does not define).
2. Update `context/standards/git-staging-scope.md`'s "A third asymmetry, deliberately left open"
   paragraph to record the closure: the deployed-tree strip is no longer site-2-only; only the
   `proposed_file_scope_lookup` annotation mechanism remains site-2-only. Do not delete the
   paragraph — revise it in place, preserving the still-true half.
3. Restore Case 26's full end-to-end assertion in `test-git-commit-phase.sh`, upgrading its
   comment to drop the "deliberately NOT asserted here" framing and adding the `rc=0` / `git show`
   / no-drop-warning checks Case 18 already models.
4. Add a new Z19 case to `test-git-commit-scoped.sh` using
   `build_repo_with_scope 999 probe '[".claude/"]'`, asserting the scope fails open end-to-end
   (both the task-directory path and the sibling out-of-task-directory path land, no V10 drop
   warning).
5. Re-run the full `test-git-commit-phase.sh` suite (including Case 20) after the Site-3 change
   lands, as a non-regression check — no code change to Case 20 itself is expected or warranted.

## Decisions

- Confirmed scope is strip-only: the within-dispatch `proposed_file_scope_lookup`/annotation
  mechanism is explicitly excluded from this port, per both the dispatch description and the
  standards doc's own citation of the rejected admit-via-union design.
- Confirmed the correct edit targets are the `agent-system/extensions/core/` source-store copies
  of `git-commit-scoped.sh` and `test-git-commit-scoped.sh`/`test-git-commit-phase.sh`, never the
  `.claude/scripts/` deploy mirror.

## Risks & Mitigations

- **Risk**: pasting Site 2's loop verbatim without renaming `file_scope_arr`/`_fsa_entry` to
  `containment_scope_arr`/a locally-scoped equivalent would reference an undefined variable in
  `git-commit-scoped.sh`. **Mitigation**: the Findings section above states the exact variable
  rename required.
- **Risk**: using Site 2's `warn()` call verbatim would fail — `git-commit-scoped.sh` has no such
  helper function. **Mitigation**: use this script's own inline `echo "WARN: git-commit-scoped.sh
  ..." >&2` convention instead, as shown in the Findings section.
- **Risk**: placing the strip inside (rather than before) the `if [ "${#containment_scope_arr[@]}"
  -gt 0 ]` guard would mean the strip never runs when there is exactly one entry and it is
  `.claude/` (the guard would already be false before the strip could empty it) — actually in this
  specific case the guard is evaluated on the *unstripped* array, so a `.claude/`-only array of
  length 1 would pass the length check and enter the block with a now-stale, unstripped
  `.claude/` entry still present, defeating the strip. **Mitigation**: the strip must run strictly
  before the guard, exactly as Site 2 orders it (strip, then test length) — this is called out
  explicitly in Recommendation 1 and the code excerpt above.

## Context Extension Recommendations

- **Topic**: Containment-site parity tracking.
- **Gap**: `context/standards/git-staging-scope.md`'s "Three Containment sites, not one" section
  has accumulated several per-site asymmetry call-outs (own-task-directory member, derived-output
  prefix, deployed-tree strip, within-dispatch lookup) across multiple separate tasks, each
  recorded as its own prose paragraph. There is no single table cross-referencing which of the
  (now four) widening/narrowing mechanisms apply at which of the three sites.
- **Recommendation**: after this task lands, consider adding a small summary table to that
  section (mechanism x site x status) so a future task closing the next residual does not need to
  re-derive current coverage by reading the full prose history.

## Appendix

- Search queries / commands used: `find` for `git-commit-phase.sh`/`git-commit-scoped.sh` and
  their test files; `jq -r '.extensions.core.source_dir'` on `.claude-extensions.json`; `grep -n`
  for `V10`, `deployed-tree`, `containment_scope_arr`, `is_contained_v10`, `.claude` across both
  scripts; targeted `Read` of `git-staging-scope.md`'s "Three Containment sites, not one" section
  and the V10 gate-label entry; targeted `Read` of both test files' Case 26/Case 20 and Z1-Z18
  blocks.
- References: `agent-system/extensions/core/scripts/git-commit-phase.sh`,
  `agent-system/extensions/core/scripts/git-commit-scoped.sh`,
  `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`,
  `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `.claude/rules/source-store-deploy-boundary.md`.
