# Research Report: Task #167

**Task**: 167 - Guard LaTeX builds against the vimtex watcher: always-on rule first; shared guard
script and lifecycle wiring only if the rule proves insufficient
**Started**: 2026-09-28
**Completed**: 2026-09-28
**Effort**: Small (single rule-file edit + two pointer additions; no new mechanism)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (`agent-system/extensions/latex/**`, `agent-system/extensions/core/scripts/measure-eager-context.sh`, `agent-system/extensions/core/context/patterns/context-discovery.md`), `specs/state.json` (`file_scope` for task 167), a live empirical test of the harness's own `paths:` frontmatter auto-load mechanism run in this session
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own recommendation (widen `rules/latex.md`'s `paths:` glob, insert a
  "Continuous Build Safety" section above "Build Commands", repair the existing unconditional
  build advice, add a short pointer to `EXTENSION.md`, and cross-reference from
  `compilation-guide.md`) is confirmed as the right shape and is fully specified below with exact
  text ready for the plan/implement phases.
- **AC7 is answered empirically, not by inference.** I ran a live, in-session test of the harness's
  `paths:` auto-load mechanism using two already-deployed rules (`nix.md`, `neovim-lua.md`) as
  probes. Result: the auto-load fires on a **Read/Edit/Write tool call** whose path matches the
  glob; it does **not** fire on a **Bash command** that merely names (or even `cat`s) a matching
  path in its command string. See "AC7 — Empirical Verification" below for the exact test
  sequence and outcome.
- Consequence: the widened `paths:` glob on `rules/latex.md` will **not** catch the motivating
  incident's actual trigger (a bare `latexmk -pdf document.tex` Bash call in an ordinary editing
  conversation, with no Read/Edit/Write on the `.tex` path in that turn). The `EXTENSION.md`
  pointer (option b) is therefore **load-bearing, not merely belt-and-braces**, for exactly the
  scenario this task exists to fix.
- Per the task's "PATH REVIEW 2026-09-28 (fifth pass)" note, the three absorbed mechanism tasks
  (shared guard script, latex preflight wiring, core-level unconditional path) remain
  **conditional and NOT admitted this round**: admission requires both halves of a conjunction —
  AC7 showing the glob doesn't fire for Bash-only references (now confirmed true) **and** the
  `EXTENSION.md` pointer proving insufficient **in practice** (not yet knowable; no post-fix
  incident exists to judge by). I recommend leaving them out of this round's plan and flagging
  them as a documented "watch and re-admit" follow-up rather than speculatively implementing them.
- `specs/state.json`'s `file_scope` for task 167 includes two agent files
  (`latex-implementation-agent.md`, `latex-research-agent.md`) and `manifest.json` beyond the
  three files the dispatch text names. I checked all three: `latex-implementation-agent.md`
  restates the same unconditional build commands at four sites and should get one pointer (not
  four, to satisfy AC6/no-duplication); `latex-research-agent.md` contains no build commands and
  needs no edit; `manifest.json` needs no edit this round (the widened `paths:` list syntax
  requires no manifest change — see below).

## Context & Scope

Task 167 asks: make vimtex-watcher build-safety guidance always-in-effect for every agent/command
(not only `latex`-typed dispatches), by editing the LaTeX extension's existing deployed rule file
rather than adding a new mechanism. The task file (`.dispatch/8.md`) is unusually detailed and
already contains the option analysis, the acceptance criteria (AC1–AC7), and the exact commands
to use (AC1's `pgrep -af 'latexmk.*-pvc'`, AC3's isolated-build invocation). This research pass's
job was to (1) confirm the deployer's supported `paths:` frontmatter syntax for multiple globs,
(2) empirically resolve AC7 rather than assume it, and (3) produce ready-to-apply text for the
rule, the `EXTENSION.md` pointer, and the `compilation-guide.md` cross-reference, plus a
disposition for every file in the task's declared `file_scope`.

## Findings

### Codebase Patterns

**Multi-glob `paths:` syntax is already an established, deployed pattern — no deployer change
needed.** Contrary to the dispatch text's claim that "every current rule in the source store uses
a single-string `paths:` value," a `grep` across every `agent-system/extensions/*/rules/*.md`
frontmatter block found three existing multi-glob rules using exactly the JSON-array-of-quoted-
strings form:

```
agent-system/extensions/core/rules/git-workflow.md:   paths: ["specs/**/*", ".claude/**/*"]
agent-system/extensions/nvim/rules/neovim-lua.md:     paths: ["lua/**/*.lua", "after/**/*.lua", "*.lua"]
agent-system/extensions/web/rules/web-astro.md:       paths: ["src/**/*.astro", "src/**/*.ts", "src/**/*.tsx"]
agent-system/extensions/nix/rules/nix.md:             paths: ["**/*.nix"]
```

`agent-system/extensions/core/scripts/measure-eager-context.sh:414` (its comment, and the
`rule_matches_rep_paths` logic that follows it) independently documents and parses both forms:
"`paths:` may be a scalar (possibly quoted) or a JSON-array-style value, both on a single line in
this codebase." So the widened `rules/latex.md` frontmatter can use this list form directly, with
zero manifest.json change and zero deployer/loader change.

**`agent-system/extensions/core/context/patterns/context-discovery.md`'s "Rule Loading: Two
Independent Paths" section** is the authoritative description of the mechanism: "Claude Code
auto-loads a rule file into session context whenever a touched/referenced path matches its own
YAML `paths:` frontmatter glob." This phrasing ("touched/referenced") is ambiguous between
"any tool call whose arguments happen to contain a matching path string" and "a Read/Edit/Write
tool call on a matching path specifically" — which is exactly the ambiguity AC7 asks to resolve
empirically rather than assume.

### AC7 — Empirical Verification (load-bearing finding)

I ran a live test in this exact session, using two already-deployed rules that had not yet fired
in this conversation as clean probes (so a positive result could not be attributed to residual
context from an earlier, unrelated trigger):

1. **Bash, path referenced only as a string** — ran `echo "probe: referencing a path string
   flake.nix..." >/dev/null`. `nix.md` (`paths: ["**/*.nix"]`) did **not** fire.
2. **Bash, actually reading a real matching file's content via `cat`** — ran
   `cat /home/benjamin/.config/nvim/lua/neotex/bootstrap.lua | head -20` (a real, existing file
   matching `neovim-lua.md`'s `lua/**/*.lua` glob). `neovim-lua.md` did **not** fire, even though
   the file's content was actually read and displayed via Bash.
3. **The dedicated `Read` tool, same exact file** — called `Read` on
   `/home/benjamin/.config/nvim/lua/neotex/bootstrap.lua` immediately after step 2. The full
   content of `neovim-lua.md` was injected as a system-reminder attached to that tool result.

This is a clean minimal pair: identical file, identical content exposure, differing only in
which tool touched it. **Conclusion: the `paths:` auto-load fires on the Read/Edit/Write tool
family, not on Bash commands, regardless of whether the Bash command's argument names a matching
path or even reads that path's content through the shell.**

Applied to task 167's motivating incident: an agent that runs `latexmk -pdf document.tex` via
Bash, without any Read/Edit/Write call on `document.tex` (or any file matching the widened glob)
earlier in that same turn/session, will **not** get `rules/latex.md` auto-loaded no matter how the
frontmatter glob is widened. This is precisely the gap option (b) (the `EXTENSION.md` pointer) is
meant to close, and this finding upgrades it from "residual gap coverage" to **the primary
mechanism for the bare-Bash-invocation case** — the glob widening still matters (it covers
`.bib`/`.latexmkrc`/build-dir edits made via Edit/Write, and it covers the common case where an
agent did just Read/Edit the `.tex` file before building), but it does not, and structurally
cannot, cover a bare Bash-only build call.

### Recommendations — Exact Text

**1. `agent-system/extensions/latex/rules/latex.md` (PRIMARY edit)**

Widen the frontmatter:

```
---
paths: ["**/*.tex", "**/*.latexmkrc", "**/*.bib", "**/build/**"]
---
```

Trade-off to record, not silently resolve: `**/build/**` is intentionally broad (LaTeX projects
put `-outdir`/`-auxdir` under a `build/` directory by convention, but that convention isn't
enforced, and `build/` is also a generic directory name used by non-LaTeX toolchains). The cost of
over-matching is small (one more ~100-line rule occasionally auto-loaded when a Read/Edit/Write
touches an unrelated `build/` tree) but non-zero. A narrower alternative
(`**/build/*.aux`, `**/build/*.log`, `**/*.fdb_latexmk`) trades recall for precision. I recommend
keeping `**/build/**` as specified in the dispatch (recall matters more here — a missed match
silently reintroduces the exact incident), but the planner should make this call explicitly
rather than by default.

Insert a new section **above** "## Build Commands" (placed after "## Source File Formatting" and
its subsections, before "## Common Patterns" — anywhere above "## Build Commands" satisfies the
dispatch's "read before the commands it constrains" requirement; I recommend directly above
"## Validation Checklist" so both repaired sections are adjacent):

```markdown
## Continuous Build Safety

**Before running any `latexmk`/`pdflatex`/`xelatex`/`lualatex` command, check for a competing
continuous-build watcher** — typically vimtex's `latexmk -pvc`, started by the user's editor, not
by you:

    pgrep -af 'latexmk.*-pvc'

Also check for any `latexmk`/`pdflatex` process whose arguments name the same `.tex` file or the
same `-outdir`/`-auxdir` you are about to build into.

**If a watcher is running, do not contend with it:**
- Never run a build into the shared `-outdir` (commonly `build/`) the watcher owns.
- Never run `latexmk -c` or `latexmk -C` against that shared directory.
- Never kill, stop, or restart the watcher yourself.

**Use a non-contending path instead:**
- The watcher already rebuilds on save — for a routine edit, just make the edit and let vimtex
  recompile. No build command is needed at all.
- To verify compilation yourself, build into an isolated scratch directory instead of the shared
  one. `-r /dev/null` bypasses the project `.latexmkrc`, whose `$failure_cmd` is what appends the
  spurious "Build failed" log entries this contention produces:

      SCRATCH="$(mktemp -d)"
      latexmk -pdf -outdir="$SCRATCH" -auxdir="$SCRATCH" -r /dev/null document.tex

  Inspect `$SCRATCH/document.log` for the real result, then discard `$SCRATCH`.

**Report, do not repair.** If the shared build directory looks broken (missing PDF, empty `.aux`,
"Build failed" entries in its compile log), tell the user to run `:VimtexClean` then
`:VimtexCompile`. Do not attempt repairs against the shared directory yourself.

**Classify a nonzero exit code before rerunning anything.** A `latexmk` exit code of 12 (or
bibtex/aux complaints such as "I found no \citation commands") alongside a CLEAN log — no `^!`
line, no `file.tex:N:` file-line-error — is a contention signal, not a LaTeX error. Rerunning
against the shared directory only compounds the race; use the isolated build above instead.
```

Repair "## Validation Checklist" (replace the last bullet):

```markdown
- [ ] Compiles cleanly in an isolated build (see "Continuous Build Safety" above) — never claim
      success from a build run against a directory a continuous watcher owns
```

Repair "## Build Commands" (add one line above the fenced block, change nothing else — the
commands themselves are fine once gated):

```markdown
## Build Commands

These commands assume no continuous-build watcher owns the target's output directory — see
"Continuous Build Safety" above before running any of them.

    ```bash
    ...(existing block unchanged)...
    ```
```

**2. `agent-system/extensions/latex/EXTENSION.md` (COMPLEMENT — pointer only, per AC6)**

Add a short subsection (I suggest under "### Document Structure" or as its own subsection right
after it):

```markdown
### Build Safety

Before running any `latexmk`/`pdflatex` build command — including outside a `latex`-typed task —
check for a competing vimtex continuous-build watcher first. See
`agent-system/extensions/latex/rules/latex.md`'s "Continuous Build Safety" section for the
detection command and the non-contending build path; it is not restated here.
```

This lands in the eager `CLAUDE.md` "LaTeX Extension" section (`merge_targets.claudemd`,
`section_id: extension_latex`) whenever the latex extension is loaded, independent of task type,
independent of any path having been touched — closing exactly the gap AC7 confirmed the widened
glob cannot reach.

**3. `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`**

This file is lazily loaded (task-typed, per `index-entries.json`'s `load_when.task_types:
["latex"]`), so it can't substitute for (1)/(2), but per the dispatch it must not contradict them.
Insert directly after the existing `-pvc` bullet list in "## Continuous Compilation" /
"### Using latexmk with Preview" (currently at compilation-guide.md:213–217):

```markdown
- `-pvc`: Preview continuously, recompile on changes
- Works well with PDF viewers that auto-refresh

**Never start, stop, or race a second `latexmk` invocation against the same target while this is
running.** See `agent-system/extensions/latex/rules/latex.md`'s "Continuous Build Safety" section
for the detection command and the safe alternative build path — not restated here.
```

**4. `agent-system/extensions/latex/agents/latex-implementation-agent.md`** (in `file_scope`,
not named in the dispatch body)

This is the agent that actually issues build commands. It restates the same unconditional
commands at four sites: the "### Build Tools (via Bash)" bullet list (~line 47-50), the
"Compilation Sequences" block (~line 56-70), a numbered-steps mention (~line 105), and a
verification-step block (~line 143, ~222). Per AC6 (no duplication), add **one** pointer at the
first site rather than four:

```markdown
### Build Tools (via Bash)
- `pdflatex` - Single-pass PDF compilation
- `latexmk -pdf` - Full automated build
- `bibtex` / `biber` - Bibliography processing
- `latexmk -c` - Clean auxiliary files

Before running any of the above, check for a competing continuous-build watcher — see
`rules/latex.md`'s "Continuous Build Safety" section (this agent's own `.tex` Read/Edit/Write
calls load that rule automatically before any build is attempted).
```

The parenthetical is accurate and worth keeping: because this agent's Allowed Tools require
Read/Edit/Write on `.tex` files as part of any real plan execution, the rule *will* auto-load for
this agent's normal workflow (unlike the bare-Bash gap AC7 identified for ad hoc, non-latex-typed
conversations) — this is the one agent where the glob-based path (mechanism (a)) is expected to
actually be sufficient on its own, with the `EXTENSION.md` pointer as pure defense-in-depth here.

**5. `agent-system/extensions/latex/agents/latex-research-agent.md`** — no build commands present
(`grep -n "latexmk\|pdflatex\|pvc"` returned zero matches). No edit needed; note this in the plan
as "reviewed, no change required" so the file_scope entry isn't mistaken for an oversight.

**6. `agent-system/extensions/latex/manifest.json`** — no edit needed this round. The widened
`paths:` list syntax requires no manifest field (confirmed above via `git-workflow.md` /
`neovim-lua.md` / `nix.md` precedent, needing no `provides.*` registration change); no new hook,
script, or agent is being added this round (those are the conditional/deferred mechanism tasks).
Verify this file is unchanged when closing the task, so a `git diff` on it isn't a surprise.

## Decisions

- **AC7 resolved empirically**: the harness's `paths:` frontmatter auto-load fires on
  Read/Edit/Write tool calls only, never on Bash argument/content matching. Recorded above with
  the exact test sequence so this doesn't need re-deriving later.
- **Conditional mechanism tasks (shared guard script, latex preflight wiring, core-level
  unconditional path) are NOT admitted this round.** The fifth-pass review's admission
  conjunction has one half satisfied (AC7 gap confirmed real) and one half unknowable right now
  (whether the `EXTENSION.md` pointer proves insufficient *in practice* — that requires either a
  live recurrence after this fix ships, or a deliberate red-team test of an agent's actual
  compliance with prose-only guidance, neither of which this research pass can manufacture).
  Recommend the plan close this task on the rule + two pointers, and separately note in the
  summary/report a concrete trigger for re-admitting the conditional phases: *if a build-race
  incident recurs after this fix is deployed*, re-open with the mechanism-decision research
  already fully specified in the absorbed task text (options a/b/c for the stop mechanism,
  restore-vs-report, and the (i)/(ii)/both coverage-path decision for non-`latex`-typed tasks).
- **`**/build/**` glob breadth** is a recorded trade-off (recall over precision), not a silent
  default — see Recommendations item 1.
- **Single pointer, not four**, in `latex-implementation-agent.md`, to satisfy AC6.

## Risks & Mitigations

- **Risk**: widened glob's `**/build/**` fires on unrelated non-LaTeX `build/` directories,
  adding minor eager-context noise. **Mitigation**: accepted trade-off, recorded above; the cost
  is one small rule file occasionally auto-loaded, not a behavior change for non-LaTeX work.
- **Risk**: the `EXTENSION.md` pointer is prose an agent can skip, since — per this task's own
  root-cause finding — the *existing* rule text was not silent in the original incident, it was
  actively followed and gave the wrong instruction. Fixing the instruction closes that specific
  failure mode, but prose guidance in general remains skippable in a way a blocking mechanism
  is not. **Mitigation**: this is exactly why the conditional mechanism tasks exist as a documented
  escalation path rather than being discarded; they are deferred, not rejected.
- **Risk**: `**/build/**` could match this same repository's own `agent-system/extensions/*/scripts`
  or `.claude/` build/deploy artifacts if any are ever named `build/`. **Mitigation**: checked —
  no such directory currently exists in this repo's tree at the depth searched; not a live
  concern, flagged only for future awareness.

## Context Extension Recommendations

None. The existing `context/project/latex/tools/compilation-guide.md` gating
(`load_when.task_types: ["latex"]`) is correct and deliberate per option (d)'s rejection — it
should stay lazy; only the rule and the `EXTENSION.md` merge source need to be eager, and both are
addressed above.

## Appendix

- Search queries/commands used: `grep -rln '^paths:' agent-system/extensions/*/rules/*.md`;
  `grep -n "pvc" agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`;
  `grep -n "Rule Loading: Two Independent Paths" -A 40 agent-system/extensions/core/context/patterns/context-discovery.md`;
  `jq -r '.active_projects[] | select(.project_number==167) | .file_scope' specs/state.json`.
- Empirical AC7 test commands (in order): `echo "probe..." >/dev/null`; `find .../lua -maxdepth 2
  -name "*.nix"` (none found, redirected probe to an existing `.lua` file instead);
  `cat /home/benjamin/.config/nvim/lua/neotex/bootstrap.lua | head -20` (Bash, no trigger);
  `Read` tool on the same file (triggered `neovim-lua.md` in full).
- Files read in full: `agent-system/extensions/latex/rules/latex.md`,
  `agent-system/extensions/latex/EXTENSION.md`,
  `agent-system/extensions/latex/context/project/latex/tools/compilation-guide.md`,
  `agent-system/extensions/latex/manifest.json`,
  `agent-system/extensions/latex/agents/latex-implementation-agent.md` (first 70 lines +
  targeted greps), `agent-system/extensions/latex/agents/latex-research-agent.md` (grep only, no
  matches), `agent-system/extensions/core/scripts/measure-eager-context.sh` (relevant section).
