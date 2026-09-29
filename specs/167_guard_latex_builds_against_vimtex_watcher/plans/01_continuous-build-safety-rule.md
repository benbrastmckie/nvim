# Implementation Plan: Task #167

- **Task**: 167 - Guard LaTeX builds against the vimtex watcher: always-on rule first; shared
  guard script and lifecycle wiring only if the rule proves insufficient
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/167_guard_latex_builds_against_vimtex_watcher/reports/01_vimtex-watcher-guard-rule.md
- **Artifacts**: plans/01_continuous-build-safety-rule.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The LaTeX extension's existing rule file already fires on the right trigger and currently
prescribes exactly the two commands that corrupted a shared build directory during the motivating
incident (`latexmk -pdf document.tex` and `latexmk -c`, with no watcher guard). This plan corrects
that file in place -- widening its `paths:` glob, inserting an authoritative "Continuous Build
Safety" section above the sections it constrains, and repairing the two blocks that currently read
as unconditional build instructions -- then adds three non-duplicating pointers to it (the eager
`EXTENSION.md` merge source, the lazily-loaded `compilation-guide.md`, and the agent that actually
issues build commands). No new mechanism, no new file, no manifest change. Done means AC1-AC7 are
each actionable from the rule text, the guidance exists in exactly one authoritative place, and
every file in the declared scope is either edited or recorded as reviewed-no-change.

### Research Integration

Three findings from `reports/01_vimtex-watcher-guard-rule.md` shape this plan materially:

1. **AC7 is already resolved empirically and does not need re-deriving.** A live minimal-pair test
   (identical file, identical content exposure, differing only in tool) established that the
   harness's `paths:` frontmatter auto-load fires on the **Read/Edit/Write** tool family and
   **never** on a Bash command -- not even one that `cat`s a matching file's content. Consequence:
   the widened glob structurally **cannot** cover the motivating incident's actual trigger (a bare
   `latexmk -pdf` Bash call with no Read/Edit/Write on a matching path in that turn). The
   `EXTENSION.md` pointer is therefore **load-bearing, not belt-and-braces**, and Phase 2 is not
   optional polish. The plan records this finding rather than re-testing it.
2. **Multi-glob `paths:` syntax needs no deployer change** and the dispatch text's claim that
   "every current rule in the source store uses a single-string `paths:` value" is factually wrong.
   The JSON-array-of-quoted-strings form is already deployed in four rules. Re-attested live during
   planning: `neovim-lua.md` parses to 3 globs and `git-workflow.md` to 2 via the deployer's own
   `normalize_paths_field` logic. Phase 1 uses that form directly.
3. **All four files in scope were individually dispositioned**, including the two the dispatch body
   never names. `latex-research-agent.md` contains zero build commands (`grep` returned 0 matches,
   re-confirmed during planning) and `manifest.json` needs no field change. Both are recorded as
   reviewed-no-change in Phase 4 so their `file_scope` membership is not later mistaken for an
   oversight.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Make `agent-system/extensions/latex/rules/latex.md` the single authoritative home for
  continuous-build safety guidance, with AC1-AC5 each actionable from literal commands (not
  paraphrases) in that file.
- Remove the unconditional framing from the rule's existing "Build Commands" and "Validation
  Checklist" blocks, so the file no longer instructs an agent to do the harmful thing.
- Widen the rule's `paths:` glob to cover the build/aux surfaces a compile command touches.
- Close the bare-Bash gap AC7 confirmed real with a short pointer in the eager `EXTENSION.md`
  merge source.
- Keep the lazily-loaded `compilation-guide.md` and the build-issuing
  `latex-implementation-agent.md` from contradicting the rule, via pointers only (AC6).
- Record every decision, every no-change disposition, and a concrete re-admission trigger for the
  deferred mechanism work.

**Non-Goals**:
- The three absorbed mechanism tasks (shared `latex-build-guard.sh`, latex preflight hook wiring,
  task-type-independent core path). See Decision 3 -- these stay deferred this round, and their
  core-side targets stay OUT of `file_scope`.
- Any edit under `.claude/**`. That tree is a disposable deploy artifact regenerated from source.
- Any edit to the PossibleWorlds paper repo's own `CLAUDE.md`. It is user-owned and explicitly
  out of scope; a pointer there is a follow-up suggestion for the summary only.
- Invoking `deploy-headless.sh`. See Decision 2.
- Any `manifest.json` field change, or any new script, hook, or agent file.

## Decisions

These are planner-side calls the research report explicitly left open. They are recorded here so
the implementer does not re-litigate them.

**Decision 1 -- keep `**/build/**` in the widened glob (recall over precision).** The report asked
for this to be an explicit call rather than a default. Chosen breadth:
`["**/*.tex", "**/*.latexmkrc", "**/*.bib", "**/build/**"]`. Rationale: a missed match silently
reintroduces the exact incident this task exists to close, whereas over-matching costs one ~100-line
rule occasionally auto-loading when a Read/Edit/Write touches an unrelated `build/` tree. The
narrower alternative (`**/build/*.aux`, `**/build/*.log`, `**/*.fdb_latexmk`) trades that recall
away for a precision gain with no behavioral upside. Recorded trade-off, not a silent default.

**Decision 2 -- verification is source-store static, NOT a redeploy.** The dispatch's scope boundary
says to "verify the change by redeploying and confirming the regenerated `.claude/rules/latex.md`
and the CLAUDE.md `extension_latex` section carry the new text." That instruction is not executable
by this task's implementer, for two independent reasons:
- `context/patterns/regeneration-is-manual-only.md` licenses exactly ONE automated caller of
  `scripts/deploy-headless.sh` (`skill-orchestrate`'s Stage MT-3 step 7, the inter-cycle redeploy
  checkpoint) and states the carve-out "is **not precedent**". An implementer calling it would be
  an out-of-policy new automated caller.
- The latex extension is **not active in this repository**: `.claude/rules/latex.md` does not exist
  here and `.claude/CLAUDE.md` carries no "LaTeX Extension" section (both confirmed during
  planning). A default-mode `deploy-headless.sh` run only resyncs already-active extensions, so it
  would deploy nothing for latex even if it were permitted. Activating the extension here would be
  a user-owned change to `.claude-extensions.json`, which is already dirty in the working tree.

Verification is therefore (i) static assertions against the source-store files and (ii) a mechanical
replication of the deployer's own frontmatter parse (attested live during planning -- see Phase 1's
verification). Redeploy happens through the normal manual/Stage MT-3 path, outside this task.

**Decision 3 -- the conditional mechanism phases are NOT admitted this round.** The fifth-pass path
review gates admission on a conjunction: AC7 showing the glob does not fire for Bash-only
references **AND** the `EXTENSION.md` pointer proving insufficient in practice. The first half is
now confirmed true; the second is not knowable yet -- it requires either a live recurrence after
this fix ships or a deliberate red-team test of prose compliance, neither of which this round can
manufacture. `file_scope` therefore stays at the four latex-extension files, and the core-side
targets stay out (re-admitting them would reclassify this task as self-modifying and collide with
the concurrent engine tasks). **Re-admission trigger, to be recorded in the summary**: if a
build-race incident recurs after this fix is deployed, re-open with the mechanism decision already
fully specified in the absorbed task text (stop-mechanism options a/b/c, restore-vs-report, and the
(i)/(ii)/both coverage-path decision). Escalation path of last resort, already analysed and
rejected as disproportionate for now: a PreToolUse Bash-matcher hook via a settings fragment, the
only mechanism that fires with certainty on a path-free `latexmk` Bash call.

**Decision 4 -- one pointer in `latex-implementation-agent.md`, plus one repair.** That file
restates unconditional build commands at five sites. AC6 forbids five pointers. It gets exactly one
pointer, at the first site ("Build Tools (via Bash)"), **and** a gate on its `MUST DO` item 4
("Run `latexmk -pdf` to verify compilation") -- because that item is itself an unconditional
bare-build mandate in the strongest-lever section of the contract, so leaving it unqualified would
have the contract contradict the pointer three screens above it. The gate is a repair of harmful
text, not a second copy of the guidance.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Pointer text drifts into a second copy of the rule, violating AC6 | M | M | Phase 4 runs an explicit no-duplication sweep: each of the three pointer sites must contain a path reference to the rule's section and must NOT contain the literal `pgrep -af` detection command or the `-r /dev/null` isolated-build invocation |
| `**/build/**` fires on unrelated non-LaTeX `build/` trees, adding context noise | L | M | Accepted trade-off, recorded as Decision 1; cost is one small rule file occasionally auto-loading, never a behavior change for non-LaTeX work |
| The new section is inserted BELOW a block it is supposed to constrain, defeating "read before the commands it constrains" | M | L | Phase 1 verification asserts heading order by line number: `Continuous Build Safety` must precede BOTH `Validation Checklist` and `Build Commands` |
| A sibling task's concurrent edit is swept into this task's commit | M | M | Seven siblings are dispatched this same cycle on this shared tree, none sharing a file with this task's scope. Every phase re-reads its target immediately before editing and stages only named files -- never a directory or glob pathspec |
| Prose guidance remains skippable in a way a blocking mechanism is not | M | M | Inherent to the chosen option; this is precisely why the mechanism work is deferred-not-rejected, with the Decision 3 re-admission trigger recorded in the summary |
| Implementer attempts the dispatch's literal "verify by redeploying" step | L | M | Decision 2 states the prohibition and the substitute verification explicitly; Phase 4 asserts no `.claude/**` file was modified |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Authoritative Rule -- Widen Glob, Add Safety Section, Repair Unconditional Blocks [COMPLETED]

**Goal**: `agent-system/extensions/latex/rules/latex.md` carries AC1-AC5 as actionable literal
commands in a new "Continuous Build Safety" section positioned above the two blocks it constrains,
and neither of those blocks any longer reads as an unconditional build instruction.

**Tasks**:
- [x] Re-read the file immediately before editing (seven sibling tasks are live on this tree). *(completed)*
- [x] Replace the frontmatter `paths: "**/*.tex"` with the JSON-array form
      `paths: ["**/*.tex", "**/*.latexmkrc", "**/*.bib", "**/build/**"]` (Decision 1). Use the
      array form attested in `nvim/rules/neovim-lua.md` and `core/rules/git-workflow.md` -- quoted
      strings, comma-space separated, single line. *(completed: verified via jq parse, 4 globs)*
- [x] Insert a new `## Continuous Build Safety` section immediately ABOVE the existing
      `## Validation Checklist` heading. That position satisfies the "read before the commands it
      constrains" requirement for both repaired blocks, since `Validation Checklist` precedes
      `Build Commands` in this file. *(completed)*
- [x] In that section, carry all five behavioral points with literal commands, not paraphrases:
      AC1 detection via `pgrep -af 'latexmk.*-pvc'` plus the same-`.tex`/same-`-outdir` process
      check; AC2 the three never-do items (no build into the shared `-outdir`, no `latexmk -c`/`-C`
      against it, never kill/stop/restart the watcher); AC3 both non-contending paths -- let vimtex
      rebuild, or build isolated with
      `latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null document.tex` including the
      note that `-r /dev/null` bypasses the project `.latexmkrc` whose `$failure_cmd` appends the
      spurious "Build failed" entries; AC4 report-don't-repair, naming `:VimtexClean` then
      `:VimtexCompile` as the user's remedy; AC5 classify-before-rerunning, distinguishing exit 12
      plus a clean log (a contention signal) from a real LaTeX error (a `^!` line or a
      `file.tex:N:` file-line-error). *(completed)*
- [x] Repair `## Validation Checklist`: replace the `- [ ] Builds successfully with pdflatex`
      bullet with one that requires an isolated build and cross-references the new section. *(completed)*
- [x] Repair `## Build Commands`: add a single gating sentence above the existing fenced block
      pointing at the new section. Leave the commands inside the block unchanged -- they are
      correct once gated. *(completed)*
- [x] Commit this file alone with a task-scoped message. *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts (a) the widened glob has exactly 4 member globs, (b) the
file's current single `paths:` scalar is at line 2, and (c) `Validation Checklist` currently
precedes `Build Commands` so one insertion point serves both repairs. Confirm at implementation
time by re-reading the file and by the parse assertion below; (b) and (c) were true at planning
time but are line-number-anchored and may drift.

**Files to modify**:
- `agent-system/extensions/latex/rules/latex.md` - frontmatter glob widened; new
  `## Continuous Build Safety` section added; `## Validation Checklist` last bullet and
  `## Build Commands` preamble repaired

**Verification**:
- Replicate the deployer's own frontmatter parse (this exact command was attested live during
  planning against `neovim-lua.md` and `git-workflow.md`, which returned 3 and 2 globs
  respectively) and confirm it yields 4 lines:
  ```bash
  pr="$(sed -n '/^paths:/{s/^paths:[[:space:]]*//;p;q}' \
        agent-system/extensions/latex/rules/latex.md)"
  printf '%s' "$pr" | jq -r '.[]'   # expect exactly: **/*.tex, **/*.latexmkrc, **/*.bib, **/build/**
  ```
  A `jq` parse failure or a line count other than 4 fails this phase. This is the same
  `normalize_paths_field` branch (`[[ "$raw" == \[*\] ]]` -> `jq -r '.[]'`) that
  `measure-eager-context.sh` uses, so a pass here is a pass against the real consumer.
- Assert heading order by line number:
  `grep -n '^## \(Continuous Build Safety\|Validation Checklist\|Build Commands\)$'` must list
  `Continuous Build Safety` first.
- Assert each acceptance criterion's literal text is present: `pgrep -af 'latexmk.*-pvc'`,
  `-r /dev/null`, `:VimtexClean`, and the exit-12 classification language each `grep` non-empty.
- Assert the harmful unconditional text is gone: `grep -n 'Builds successfully with' ` returns no
  match.
- Diff read-through confirming every changed hunk lies in frontmatter or prose/markdown regions.

---

### Phase 2: Eager Pointer in the CLAUDE.md Merge Source [COMPLETED]

**Goal**: `EXTENSION.md` carries a short `### Build Safety` pointer so the guidance reaches the
eager session prefix whenever the latex extension is loaded -- independent of task type and
independent of any path having been touched, which is the one channel AC7 confirmed the widened
glob structurally cannot reach.

**Tasks**:
- [x] Re-read `agent-system/extensions/latex/EXTENSION.md` immediately before editing. *(completed)*
- [x] Add a `### Build Safety` subsection (3-4 lines) after the existing `### Document Structure`
      subsection. It must stay INSIDE the existing `## LaTeX Extension` section -- do not add a new
      `##` heading, which would break the `merge_targets.claudemd` `section_id: extension_latex`
      contract. *(completed: verified single `## ` heading remains)*
- [x] Content: state that a competing vimtex continuous-build watcher must be checked for before
      any `latexmk`/`pdflatex` build command, explicitly including outside a `latex`-typed task;
      reference `agent-system/extensions/latex/rules/latex.md`'s "Continuous Build Safety" section
      by path for the detection command and the non-contending build path; state that it is not
      restated here. *(completed)*
- [x] Keep it to a pointer. This text lands in the eager session prefix, which the system budgets
      via `measure-eager-context.sh` / `measure-eager-surface.sh`. *(completed: 6 lines total)*
- [x] Commit this file alone. *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/latex/EXTENSION.md` - new `### Build Safety` pointer subsection

**Verification**:
- The file still has exactly one `^## ` heading, and it is still `## LaTeX Extension`
  (`grep -c '^## '` returns 1) -- confirms the `section_id: extension_latex` merge contract is
  intact.
- The new subsection is `### Build Safety` and appears after `### Document Structure`
  (line-number comparison).
- The pointer names the rule file path and the exact section title `Continuous Build Safety`, and
  the added text is at most 6 lines (eager-budget discipline).
- No-duplication check: the added text contains neither `pgrep -af` nor `-r /dev/null`.

---

### Phase 3: Non-Contradiction Pointers in the Guide and the Build-Issuing Agent [COMPLETED]

**Goal**: The lazily-loaded compilation guide and the agent that actually issues build commands
both point at the rule instead of contradicting it, with the prose stated once (AC6).

**Tasks**:
- [x] Re-read both target files immediately before editing. *(completed)*
- [x] `compilation-guide.md`: insert a cross-reference directly after the existing `-pvc` bullet
      list in `## Continuous Compilation` / `### Using latexmk with Preview` (the bullets
      `- \`-pvc\`: Preview continuously...` and `- Works well with PDF viewers...`, at
      approximately lines 217-218), before `### Editor Integration`. Content: never start, stop, or
      race a second `latexmk` invocation against the same target while this is running; see the
      rule's "Continuous Build Safety" section for the detection command and the safe alternative;
      not restated here. *(completed)*
- [x] `latex-implementation-agent.md`: add ONE pointer immediately after the `### Build Tools (via
      Bash)` bullet list (approximately lines 46-50), per Decision 4. Content: check for a
      competing continuous-build watcher before running any of the listed commands, referencing
      `rules/latex.md`'s "Continuous Build Safety" section. Keep the accurate parenthetical that
      this agent's own `.tex` Read/Edit/Write calls auto-load that rule during normal plan
      execution -- this is the one agent for which the glob-based path is expected to suffice on
      its own. *(completed)*
- [x] `latex-implementation-agent.md`: gate `MUST DO` item 4 in `## Critical Requirements`, which
      currently reads `Run \`latexmk -pdf\` to verify compilation` -- an unconditional bare-build
      mandate in the contract's strongest-lever section. Qualify it to require the isolated build
      when a watcher owns the output directory, referencing the rule's section. Do NOT add four or
      five pointers at the other build sites (AC6). *(completed)*
- [x] Commit both files together (one coherent pointer change), staging them by explicit name. *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts that `latex-implementation-agent.md` restates build
commands at five sites (approximately lines 46-50, 56-70, 105, 143, 222) and receives exactly one
new pointer plus one repaired `MUST DO` item -- not five pointers. Confirm at implementation time
with `grep -c 'latexmk\|pdflatex'` before and after, and by asserting the added pointer text
appears exactly once. It also asserts `latex-research-agent.md` needs no edit; that is verified
independently in Phase 4.

**Files to modify**:
- `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md` - cross-reference
  after the `-pvc` bullet list in `### Using latexmk with Preview`
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` - one pointer after
  `### Build Tools (via Bash)`; `MUST DO` item 4 gated

**Verification**:
- Both files reference the exact section title `Continuous Build Safety`
  (`grep -c` returns >= 1 each).
- `compilation-guide.md`: the inserted text sits between the `-pvc` bullet list and
  `### Editor Integration` (line-number comparison), and the `## Continuous Compilation` heading is
  unchanged.
- `latex-implementation-agent.md`: the added pointer text appears exactly once
  (`grep -c` returns 1); `MUST DO` item 4 no longer reads as a bare unconditional
  `Run \`latexmk -pdf\``.
- No-duplication check: neither file contains `pgrep -af` or `-r /dev/null`.
- Diff read-through confirming every changed hunk lies in prose/markdown regions.

---

### Phase 4: Acceptance Sweep, No-Change Dispositions, and Decision Record [NOT STARTED]

**Goal**: AC1-AC7 are each demonstrably satisfied across the four edited/reviewed files, the two
no-change files are recorded as reviewed rather than overlooked, and the deferral decision plus its
re-admission trigger are written into the summary.

**Tasks**:
- [ ] AC6 no-duplication sweep across all three pointer sites: each must reference the rule's
      section by path/title, and none may carry the detection command or the isolated-build
      invocation.
- [ ] AC1-AC5 presence sweep: confirm each criterion's literal command or classification language
      appears in `rules/latex.md`, and confirm it appears there and nowhere else.
- [ ] AC7: record the empirical finding in the summary (auto-load fires on Read/Edit/Write only,
      never on Bash; the `EXTENSION.md` pointer is therefore load-bearing). Do not re-run the test
      -- it is already resolved in the research report with its exact test sequence.
- [ ] Record `agent-system/extensions/latex/agents/latex-research-agent.md` as reviewed, no change
      required -- verify with a zero-match grep for build commands.
- [ ] Record `agent-system/extensions/latex/manifest.json` as reviewed, no change required --
      verify it is untouched in `git diff`, so its `file_scope` membership does not read as an
      oversight.
- [ ] Assert no `.claude/**` file was modified by this task.
- [ ] Run the repo-wide task-reference lint; no task numbers may appear in any edited file (all
      four are outside `specs/**`).
- [ ] Write the summary recording: Decision 1 (glob breadth trade-off), Decision 2 (why no
      redeploy verification), Decision 3 (mechanism phases deferred + the concrete re-admission
      trigger + the settings-fragment PreToolUse hook as documented escalation of last resort),
      Decision 4 (one pointer plus one repair), and the out-of-scope follow-up suggestion that the
      PossibleWorlds paper repo's own `CLAUDE.md` "Build Workflow: Preventing Aux File Corruption"
      section warrants a pointer -- user-owned, not edited from this task.
- [ ] Commit the summary.

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the task's full scope is four files, of which exactly two
are recorded as reviewed-no-change (`latex-research-agent.md`, `manifest.json` -- the latter being a
scope entry from `specs/state.json` rather than from the dispatch body). Confirm at implementation
time with `git diff --name-only`, which must list only the four edited paths plus `specs/**`
artifacts.

**Files to modify**:
- `specs/167_guard_latex_builds_against_vimtex_watcher/summaries/01_continuous-build-safety-rule-summary.md` -
  new; carries the decision record, the AC1-AC7 dispositions, and the re-admission trigger

**Verification**:
- `grep -c 'Continuous Build Safety'` returns >= 1 in each of `EXTENSION.md`,
  `compilation-guide.md`, and `latex-implementation-agent.md`.
- `grep -rn 'pgrep -af' agent-system/extensions/latex/` matches `rules/latex.md` and nothing else.
- `grep -rn -- '-r /dev/null' agent-system/extensions/latex/` matches `rules/latex.md` and nothing
  else.
- `grep -cn 'latexmk\|pdflatex\|pvc' agent-system/extensions/latex/agents/latex-research-agent.md`
  returns 0.
- `git diff --name-only` lists no path under `.claude/` and does not list
  `agent-system/extensions/latex/manifest.json`.
- `bash .claude/scripts/check-task-references.sh` passes (or reports no new violations in the four
  edited paths).
- `bash .claude/scripts/validate-artifact.sh` passes on this plan and on the summary.
- The summary contains all four decisions and the re-admission trigger.

## Testing & Validation

- [ ] The widened `paths:` value parses to exactly 4 globs through the deployer's own
      `normalize_paths_field` branch (`jq -r '.[]'` on the bracketed raw value).
- [ ] `## Continuous Build Safety` precedes both `## Validation Checklist` and `## Build Commands`
      in `rules/latex.md`.
- [ ] AC1-AC5 each traceable to literal text in `rules/latex.md` (not a paraphrase).
- [ ] The two previously unconditional blocks in `rules/latex.md` are gated; the string
      `Builds successfully with` is gone.
- [ ] `EXTENSION.md` still has exactly one `^## ` heading (`## LaTeX Extension`), preserving the
      `section_id: extension_latex` merge contract.
- [ ] AC6: the detection command and the isolated-build invocation appear in `rules/latex.md` only.
- [ ] `latex-implementation-agent.md` carries exactly one new pointer and a gated `MUST DO` item 4.
- [ ] `latex-research-agent.md`: zero build-command matches, recorded as no-change.
- [ ] `manifest.json`: absent from `git diff --name-only`, recorded as no-change.
- [ ] No file under `.claude/**` modified.
- [ ] No task-number reference in any of the four edited files.
- [ ] AC7's finding and the Decision 3 re-admission trigger are both recorded in the summary.

## Artifacts & Outputs

- `specs/167_guard_latex_builds_against_vimtex_watcher/plans/01_continuous-build-safety-rule.md`
  (this file)
- `specs/167_guard_latex_builds_against_vimtex_watcher/summaries/01_continuous-build-safety-rule-summary.md`
- `agent-system/extensions/latex/rules/latex.md` (modified -- authoritative guidance)
- `agent-system/extensions/latex/EXTENSION.md` (modified -- eager pointer)
- `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md` (modified --
  cross-reference)
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` (modified -- one pointer,
  one repair)

## Rollback/Contingency

All four targets are prose/markdown files with no compile or elaboration surface, each committed in
its own phase-scoped commit, so rollback is per-file and needs no working-tree snapshot: revert the
offending commit, or restore the single file from `HEAD~1` with `git checkout <sha> -- <path>`
naming the path explicitly.

Because seven sibling tasks are dispatched on this same working tree this cycle, do NOT reach for a
whole-tree rollback. If one does become genuinely necessary, follow
`context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
shape, including its out-of-scope override flag -- never a bare default-mode `git-snapshot.sh` call
as a precautionary checkpoint.

Contingency if Phase 1's frontmatter parse assertion fails (the array form is rejected by the real
loader despite the four attested precedents): fall back to keeping the scalar `paths: "**/*.tex"`
unchanged and rely on the Phase 2 eager pointer alone, which AC7 already established is the
load-bearing channel for the motivating incident. Record the fallback and its reason in the
summary; the rule-text repairs in Phase 1 stand regardless of the glob outcome.
