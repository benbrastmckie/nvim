# Implementation Summary: Task #167

- **Task**: 167 - Guard LaTeX builds against the vimtex watcher: always-on rule first; shared
  guard script and lifecycle wiring only if the rule proves insufficient
- **Status**: [COMPLETED]
- **Started**: 2026-09-28T19:00:00Z
- **Completed**: 2026-09-29T02:08:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_continuous-build-safety-rule.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Corrected `agent-system/extensions/latex/rules/latex.md` -- the file that already fires on `.tex`
touches and was the proximate source of the harmful build advice during the motivating incident --
by widening its `paths:` glob, inserting an authoritative "Continuous Build Safety" section
carrying AC1-AC5 as literal commands, and repairing the two blocks that previously presented a bare
`latexmk -pdf`/`latexmk -c` as unconditional instructions. Added three non-duplicating pointers (the
eager `EXTENSION.md` merge source, the lazily-loaded `compilation-guide.md`, and the build-issuing
`latex-implementation-agent.md`) so the guidance reaches every channel without restating it. No new
mechanism, no new file, no manifest change -- the three absorbed mechanism tasks (shared guard
script, latex preflight wiring, task-type-independent core path) remain deliberately deferred.

## What Changed

- `agent-system/extensions/latex/rules/latex.md` -- widened `paths:` frontmatter from the scalar
  `"**/*.tex"` to the JSON-array form `["**/*.tex", "**/*.latexmkrc", "**/*.bib", "**/build/**"]`;
  inserted a new `## Continuous Build Safety` section immediately above `## Validation Checklist`
  (which itself precedes `## Build Commands`), carrying AC1 (`pgrep -af 'latexmk.*-pvc'` plus
  same-target/`-outdir` process check), AC2 (never contend: no build into the shared `-outdir`, no
  `latexmk -c`/`-C` against it, never kill/stop/restart the watcher), AC3 (let vimtex rebuild, or
  isolated build via `latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null document.tex`
  with the `-r /dev/null` / `.latexmkrc` `$failure_cmd` note), AC4 (report don't repair; user
  remedy is `:VimtexClean` then `:VimtexCompile`), and AC5 (classify exit 12 + clean log as
  contention, not a real LaTeX error, before rerunning). Repaired the `Validation Checklist`'s
  `Builds successfully with pdflatex` bullet and added a one-line gate above the `Build Commands`
  fenced block, both pointing at the new section.
- `agent-system/extensions/latex/EXTENSION.md` -- added a `### Build Safety` pointer subsection
  (6 lines) inside the existing `## LaTeX Extension` section, after `### Document Structure`. This
  is the load-bearing complement per the AC7 finding below: it is always in the eager session
  prefix regardless of task type or whether any path has been touched.
- `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md` -- added a
  cross-reference after the `-pvc` bullet list in `### Using latexmk with Preview`, before
  `### Editor Integration`, pointing at the rule's new section.
- `agent-system/extensions/latex/agents/latex-implementation-agent.md` -- added one pointer after
  `### Build Tools (via Bash)` (with the accurate parenthetical that this agent's own
  Read/Edit/Write on `.tex` already auto-loads the rule during normal execution), and gated
  `MUST DO` item 4 (previously an unconditional `Run \`latexmk -pdf\` to verify compilation`) to
  require the isolated build when a watcher owns the output directory.

## Decisions

- **Decision 1 (glob breadth, recall over precision)**: kept `**/build/**` in the widened glob
  rather than narrowing to specific extensions (`**/build/*.aux`, `*.log`, `*.fdb_latexmk`). A
  missed match silently reintroduces the incident this task closes; the cost of the broader glob
  is only that the rule occasionally auto-loads when an unrelated `build/` tree is touched under
  Read/Edit/Write -- never a behavior change for non-LaTeX work.
- **Decision 2 (verification is source-store static, not a redeploy)**: the dispatch's literal
  "verify by redeploying" instruction is not executable here for two independent reasons:
  `context/patterns/regeneration-is-manual-only.md` licenses exactly one automated caller of
  `deploy-headless.sh` (skill-orchestrate's Stage MT-3), and that carve-out is explicitly "not
  precedent"; and the latex extension is not active in this repository (no `.claude/rules/latex.md`,
  no CLAUDE.md "LaTeX Extension" section), so a default-mode deploy would resync nothing for it
  regardless. Verification instead replicated the deployer's own `normalize_paths_field` parse
  (`sed` extraction piped through `jq -r '.[]'`) and asserted the four resulting globs, heading
  order, literal AC text, and absence of the harmful unconditional text -- all directly against the
  source-store files.
- **Decision 3 (mechanism phases deferred, not admitted this round)**: the three absorbed tasks
  (shared `latex-build-guard.sh`, latex preflight hook wiring, task-type-independent core path)
  stay out of scope. Their admission gate is a conjunction -- AC7 showing the glob does not fire for
  Bash-only references AND the `EXTENSION.md` pointer proving insufficient in practice. The first
  half is now confirmed true (see AC7 below); the second is not knowable without either a live
  recurrence after this fix ships or a deliberate red-team test of prose compliance. **Re-admission
  trigger**: if a build-race incident recurs after this fix is deployed, re-open with the mechanism
  decision already fully specified in the absorbed task text (stop-mechanism options
  process-termination / editor-remote-control / detect-and-refuse, the restore-vs-report decision,
  and the agent-contract-mandate vs. core-level-unconditional-check vs. both coverage-path
  decision). The documented escalation path of last resort, already analysed and rejected as
  disproportionate for now, is a PreToolUse Bash-matcher hook via a settings fragment -- the only
  mechanism that fires with certainty on a path-free `latexmk` Bash call.
- **Decision 4 (one pointer plus one repair in the build-issuing agent)**:
  `latex-implementation-agent.md` restates build commands at five sites; AC6 forbids five pointers.
  It received exactly one pointer (after `### Build Tools (via Bash)`) plus a gate on `MUST DO`
  item 4, which was itself an unconditional bare-build mandate in the contract's strongest-lever
  section and would otherwise have contradicted the pointer three screens above it.

## AC1-AC7 Disposition

- AC1-AC5: each carried as literal, non-paraphrased text in `rules/latex.md`'s new
  "Continuous Build Safety" section; verified present there and confirmed absent everywhere else
  in the extension (`pgrep -af`, `-r /dev/null`, `:VimtexClean`, and the exit-12 classification
  language each match only `rules/latex.md`).
- AC6 (no duplication): confirmed by direct grep sweep -- all three pointer sites (`EXTENSION.md`,
  `compilation-guide.md`, `latex-implementation-agent.md`) reference the rule's section by title
  and contain neither the detection command nor the isolated-build invocation.
- **AC7 (verify the trigger, do not assume it)**: already empirically resolved during planning via
  a live minimal-pair test (identical file/content exposure, differing only in tool): the harness's
  `paths:` frontmatter auto-load fires on the Read/Edit/Write tool family and **never** on a Bash
  command, not even one that `cat`s a matching file's content. Consequence: the widened glob
  structurally cannot cover the motivating incident's actual trigger (a bare `latexmk -pdf` Bash
  call with no Read/Edit/Write on a matching path that turn). The `EXTENSION.md` pointer is
  therefore **load-bearing, not belt-and-braces** -- it is the one channel that reaches an agent
  who never touches a matching path via Read/Edit/Write before issuing the build command.

## Plan Deviations

- None (implementation followed plan)

## Impacts

- Every agent and command that loads the latex extension (not only `latex`-typed dispatches) now
  carries continuous-build safety guidance in its eager session prefix via `EXTENSION.md`, closing
  the exact gap the motivating incident exposed.
- Any Read/Edit/Write touch on a `.tex`, `.latexmkrc`, `.bib`, or `build/**` path now auto-loads the
  full detection/non-contention/report/classify guidance from `rules/latex.md`.
- The lazily-loaded `compilation-guide.md` and the build-issuing `latex-implementation-agent.md` no
  longer contradict the rule; both point at it instead of restating or omitting the guard.
- No behavior change for non-LaTeX work: the glob widening only affects auto-load triggering for
  paths already scoped to LaTeX build/document surfaces.

## Follow-ups

- The PossibleWorlds paper repo's own `CLAUDE.md` already documents this exact race under
  "Build Workflow: Preventing Aux File Corruption" from the latexmk side. A short pointer there to
  the now-corrected extension rule would be a natural follow-up, but that file is user-owned and
  outside this source store -- not edited from this task.
- If a build-race incident recurs after this fix is deployed and observed in practice, re-open the
  three absorbed mechanism tasks using Decision 3's re-admission trigger and the already-recorded
  option analysis (their text is preserved verbatim in the dispatch history for this task).

## References

- `specs/167_guard_latex_builds_against_vimtex_watcher/plans/01_continuous-build-safety-rule.md`
- `specs/167_guard_latex_builds_against_vimtex_watcher/reports/01_vimtex-watcher-guard-rule.md`
- `agent-system/extensions/latex/rules/latex.md`
- `agent-system/extensions/latex/EXTENSION.md`
- `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`
- `agent-system/extensions/latex/agents/latex-implementation-agent.md`
