# Research Report: Task #254

**Task**: 254 - Implement chapter-quality-check.sh with its test harness, then wire the standard
and checker into the typst agents, skills, manifest and index
**Started**: 2026-09-24T20:00:21Z
**Completed**: 2026-09-24T20:20:00Z
**Effort**: ~30 minutes
**Dependencies**: Task 253 (produced the chapter-quality standard) — complete
**Sources/Inputs**: Codebase exploration (agent-system/extensions/typst/**, agent-system/extensions/core/context/standards/**)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The specification (`context/project/typst/standards/chapter-quality.md`, 336 lines) is complete,
  already produced by the dependency task, and defines exactly 15 rules across four dimensions,
  each with an explicit `[BLOCKING|ADVISORY / MECHANICAL|JUDGED]` tag. This is the literal rule
  inventory the new checker must transcribe — no invention needed, no gaps found.
- The precedent script (`scripts/typst-element-lint.sh`, 341 lines + a 331-line test suite) is a
  complete, directly reusable structural template: PURPOSE/CHECKS/SEVERITY-SPLIT/ELEMENT-
  INVENTORY/LIMITATIONS header, single-pass-per-file AWK program emitting a `SEVERITY\tcheck\t...`
  protocol parsed by a bash loop, `[--verbose] [--help] PATH...` CLI, exit codes `{0,1,2}`.
  `chapter-quality-check.sh` should mirror this shape closely, not invent a second one.
- Two of the standard's own rules (1.2 path existence, 1.3 citation-key resolution) are
  MECHANICAL and BLOCKING and must be implemented **directly** by this checker — they are
  distinct from the two checks the standard explicitly defers to a *consuming repository's*
  local `typst/scripts/` (name-resolution, chapter-source coverage), which this checker must
  **not** implement. Conflating these two categories is the most likely design mistake; the
  research findings section below states the distinction explicitly with the rule numbers.
- Placement is already fully owned and mechanically enforced by `typst-element-lint.sh` check 1
  (BLOCKING). The new checker must invoke/compose with that script for placement, not
  re-implement it — the standard's own `## Deferrals and Ownership` section states this
  explicitly for Rule 3.4's sibling concern.
- The new script and its test belong to Shell Strict-Mode Class B (`set -uo pipefail`, counter-
  idiom, "report everything" — same class as `typst-element-lint.sh` and its test), per
  `context/standards/shell-strict-mode.md`'s admission test.
- A genuine open design question, not resolved by any existing file: how `chapter-quality-check.sh`
  determines "the live tree" / "the repository's `.bib` file" for Rules 1.2/1.3, since the CLI
  takes a `.typ` file/directory PATH, not a repo root, and bib filenames are not fixed
  (`references.bib` is only an example in `patterns/bibliography.md`). See Findings below.
- The typst extension is **not currently loaded** in this repo's `.claude-extensions.json`
  (only `core, email, literature, memory, nix, nvim` are active). `deploy-headless.sh`'s default
  resync only touches currently-active extensions, so acceptance criterion 8 ("the deploy
  reproduces them into .claude/ cleanly") cannot be verified by a plain default-mode
  `deploy-headless.sh` run here — see Risks below for the scratch-repo alternative already
  proven by `test-deploy-propagation.sh`.

## Context & Scope

Task 254 bundles two deliberately phase-separated concerns (per the dispatch/task description):

- **Phase Group A**: `agent-system/extensions/typst/scripts/chapter-quality-check.sh` and its test
  harness at `agent-system/extensions/typst/scripts/tests/test-chapter-quality-check.sh`. Touches
  `scripts/` only; verified by running the checker and its tests.
- **Phase Group B**: wiring — `manifest.json`, `index-entries.json`,
  `agents/typst-implementation-agent.md`, `agents/typst-research-agent.md`,
  `skills/skill-typst-implementation/SKILL.md`, `EXTENSION.md`. Verified by deploy/contract
  reading, not by running the checker.

This research covers both groups: the specification content to transcribe, the precedent shape to
mirror, the six wiring sites and their exact precedent (the element-lint wiring already present in
the same files), and the deploy-verification constraint that Phase Group B's acceptance criterion
will run into.

The edit target is the source store (`agent-system/extensions/typst/`), never `.claude/**`, per
`rules/source-store-deploy-boundary.md`.

## Findings

### Codebase Patterns

#### The specification: `context/project/typst/standards/chapter-quality.md` (336 lines)

Four dimensions, 15 rules, every rule dual-tagged. Full inventory (rule — axis1/axis2):

| Dimension | Rule | Statement (short) | Axis 1 | Axis 2 |
|---|---|---|---|---|
| SOURCE GROUNDING | 1.1 | Every substantive claim traces to a cited source | BLOCKING | JUDGED |
| SOURCE GROUNDING | 1.2 | Every backticked path resolves against the live tree | BLOCKING | MECHANICAL |
| SOURCE GROUNDING | 1.3 | Every `@key` citation resolves in `bibliography.bib` | BLOCKING | MECHANICAL |
| SOURCE GROUNDING | 1.4 | No hand-typed count/version/hash not derived from a cited source | BLOCKING | JUDGED |
| SOURCE GROUNDING | 1.5 | Every `CONFIRM` comment is well-formed (non-empty payload after `CONFIRM:`) | BLOCKING | MECHANICAL |
| ANTI-FLUFF DENSITY | 2.1 | Claim-to-word ratio meets a stated threshold (**unreviewed**) | ADVISORY | MECHANICAL |
| ANTI-FLUFF DENSITY | 2.2 | Every `==`/`===` section states a reader need in opening prose | ADVISORY | JUDGED |
| ANTI-FLUFF DENSITY | 2.3 | Hedging/filler phrases flagged against a seed list (**unreviewed, extensible**) | ADVISORY | MECHANICAL |
| PRESENTATION CLARITY | 3.1 | Every notation symbol/glossary term defined before first use | BLOCKING | JUDGED |
| PRESENTATION CLARITY | 3.2 | Heading depth bounded at `===` (no level-4+) | BLOCKING | MECHANICAL |
| PRESENTATION CLARITY | 3.3 | Paragraph length bounded (**unreviewed** threshold) | ADVISORY | MECHANICAL |
| PRESENTATION CLARITY | 3.4 | Every non-obvious concept has an accompanying example/figure | ADVISORY | JUDGED |
| OPEN-QUESTION HONESTY | 4.1 | Every speculative claim explicitly marked (`Speculative:` tag) | BLOCKING | JUDGED |
| OPEN-QUESTION HONESTY | 4.2 | Open questions collected in a dedicated, discoverable location | BLOCKING | JUDGED |
| OPEN-QUESTION HONESTY | 4.3 | No future-tense claim stated as settled fact | BLOCKING | JUDGED |

Counts: 10 BLOCKING / 5 ADVISORY; 8 JUDGED / 7 MECHANICAL. The ADVISORY set is entirely inside
ANTI-FLUFF DENSITY plus Rules 3.3 and 3.4 — **no ANTI-FLUFF rule is ever BLOCKING**, and the
standard states this at both the dimension-preamble level and per-rule, which the checker's
header should mirror (acceptance criterion 4 of the dispatch).

**MECHANICAL rules the checker implements directly** (7): 1.2, 1.3, 1.5, 2.1, 2.3, 3.2, 3.3.
**JUDGED rules the checker emits as structured reviewer prompts** (8): 1.1, 1.4, 2.2, 3.1, 3.4,
4.1, 4.2, 4.3.

Two of the MECHANICAL rules (2.1, 2.3) carry an explicit "unreviewed" disclosure and a
requirement that the checker "report the threshold it used alongside the finding" — this mirrors
`typst-element-lint.sh`'s own `ITEM_THRESHOLD`/`DENSITY_FLOOR` pattern (declared as named
constants near the top of the script, reported inline in the WARN message text).

**Rule 3.2 is BLOCKING and formalizes an existing convention** (`standards/document-structure.md`'s
heading-depth rule), unlike the other ADVISORY-threshold MECHANICAL rules — worth flagging in the
checker's header comment as the one MECHANICAL rule with a pre-observed textual anchor, matching
how the standard itself explains the distinction.

#### The `## Interface Contract for Repo-Local Checks` section — the deferral this checker must respect

The standard explicitly names exactly two checks that belong to a *consuming repository's own*
`typst/scripts/`, not to this checker: the **name-resolution check** (does every identifier that
purports to name a repo-local Typst function/variable/module actually resolve) and the
**chapter-source coverage check** (has every chapter file the repo's build includes been checked
at least once). Both get a shared finding-record shape (`{dimension, rule: "local:<name>",
severity, location, message}`) that this checker's own output should structurally match for the
findings it *does* own, even though it never emits `local:*` findings itself.

**This is easy to conflate with Rules 1.2/1.3 above, which look superficially similar** (both
involve "does this string resolve against the live tree") but are explicitly this standard's own
rules, not repo-local deferrals: Rule 1.2 is about arbitrary backtick-delimited path-shaped
tokens in prose (any repo path a chapter's prose cites, not specifically a Typst
function/module identifier), and Rule 1.3 is about `@key` citation resolution against a
`.bib` file. Neither is named in the Interface Contract section as a repo-local deferral. The
plan should state this distinction explicitly to avoid either omitting 1.2/1.3 (mistaking them
for repo-local) or duplicating the name-resolution/coverage checks (mistaking them for in-scope).

#### `scripts/typst-element-lint.sh` — the structural precedent (341 lines)

Concrete conventions to mirror, confirmed by direct read:
- Header block: `# script-name.sh - one-line purpose.` then `# PURPOSE.`, `# CHECKS.`
  (numbered, each tagged BLOCKING/ADVISORY inline), `# SEVERITY SPLIT (do not change without a
  documented review pass...)`, `# ELEMENT INVENTORY. Sourced verbatim from ... Do not invent a
  second, divergent ... list here -- if the standard's inventory changes, update ... in the same
  commit`, `# KNOWN LIMITATIONS`, `# CLI.`, `# EXIT CODES.`, and a strict-mode admission-class
  comment citing `context/standards/shell-strict-mode.md`'s Class B admission test verbatim.
- `set -uo pipefail` (Class B, no `-e`).
- `PATHS=()` arg loop supporting `--verbose|-v`, `--help|-h`, `--`, then positional PATH...;
  `-*` unknown option -> usage + exit 2; empty PATHS -> exit 2; nonexistent path -> exit 2.
- File/dir resolution: a file path is used directly; a directory is `find "$p" -type f -name
  '*.typ' -print0 | sort -z` (recursive, deterministic order).
- Single AWK program (heredoc, `read -r -d '' AWK_PROGRAM <<'AWKEOF' ... AWKEOF`) does the
  per-file, per-line pass and emits a `SEVERITY\tcheck\tfile\tf1\tf2\tf3\tf4\n` protocol on
  stdout; a bash `while IFS=$'\t' read -r ...` loop formats colored `[FAIL]/[WARN]/[INFO]`
  output and increments `TOTAL_FAILURES`/`TOTAL_WARNINGS` counters.
- Line pre-processing before any check: strip `"..."` string contents, strip `// ...` comment
  tails, then trim leading/trailing whitespace — this stripped/trimmed line (`trimmed`) is what
  every regex match runs against, not the raw line.
- Final summary block: `Files checked:`, `Failures:`, `Warnings:`, then a colored
  PASSED/PASSED-WITH-WARNINGS/FAILED banner; `exit 1` iff `TOTAL_FAILURES > 0`, else `exit 0`
  regardless of warning count.

#### `scripts/tests/test-typst-element-lint.sh` — the test-harness precedent (331 lines)

- `set -uo pipefail`, `SCRIPT_DIR` resolved via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`,
  `LINT="${SCRIPT_DIR}/../typst-element-lint.sh"` (relative path to the sibling script under
  test, source-store-relative).
- `PASSED=0`/`FAILED=0` + `pass()`/`fail()`/`info()` helpers exactly matching
  `context/standards/shell-script-testing.md`'s mandated naming.
- `WORKDIR="$(mktemp -d)"` + `trap 'rm -rf "$WORKDIR"' EXIT`; every fixture is an inline heredoc
  written into `$WORKDIR` — no committed fixture files, per the "Fixture convention" (inline
  heredocs, never resolve against the live tree).
- `assert_exit`/`assert_contains`/`assert_not_contains` helper functions parameterized by case
  name, wrapping the raw comparison and printing the actual output on failure (`info()` lines).
- Each case is a short heredoc `.typ` fixture + one invocation + 1-3 assertions, covering: silent
  compliant case, each BLOCKING-fires case, each ADVISORY-fires case, an explicit "warnings-only
  still exits 0" case (the Constraint-2-style non-vacuity guard this task's dispatch mirrors),
  CLI-contract cases (no PATH, bad PATH, `--help`), and a directory-scan case.
- Final: `echo "$PASSED passed, $FAILED failed"`; `exit 0` iff `FAILED == 0`, else `exit 1`.

The new `test-chapter-quality-check.sh` should reuse this exact shape (path resolution, helper
functions, mktemp+trap fixture pattern, final PASSED/FAILED summary), with the dispatch's three
required demonstrations layered on top: a blocking finding -> non-zero exit; an advisory-only run
-> exit 0 while still printing the advisory findings; a judged rule -> its structured reviewer
prompt. A fourth case explicitly proving no ANTI-FLUFF finding can ever flip the exit code
(acceptance criterion 4) is a natural extension of the existing "warnings-only" case pattern.

#### `manifest.json` (78 lines) — registration precedent

`provides.scripts` currently:
```json
"scripts": [
  "typst-element-lint.sh",
  "tests/test-typst-element-lint.sh"
],
```
New entries add cleanly as two more array elements:
`"chapter-quality-check.sh"`, `"tests/test-chapter-quality-check.sh"` — matching the existing
subdirectory-qualified convention for the test (`tests/...`, not a separate `provides.tests`
array — confirmed by `shell-script-testing.md`'s own "Registration" section: test scripts are
ordinary `provides.scripts` entries, subdirectory-qualified).

#### `index-entries.json` (551 lines, 26 existing entries) — registration precedent

Every entry: `path` (relative to `context/`, e.g. `"project/typst/standards/..."`), `line_count`
(actual line count — `chapter-quality.md` is 336 lines, confirmed via `wc -l`), `load_when.agents`
(array of bare agent names, no `.md`), `load_when.task_types` (`["typst"]` for every existing
entry), `domain` (`"project"` throughout), `subdomain` (`"typst"` throughout), `summary`
(one sentence), `keywords` (3-6 short strings). The closest sibling precedent is
`semantic-element-usage.md`'s entry (line 287-307): `load_when.agents: ["typst-implementation-agent"]`
only (research agent excluded there). For `chapter-quality.md`, the dispatch explicitly requires
`typst-research-agent.md` to load the standard at its Stage 2 (so research work is calibrated to
the bar), and `typst-implementation-agent.md` needs it to interpret checker findings during
Stage 4C/5 — so this new entry's `load_when.agents` should include **both**
`typst-implementation-agent` and `typst-research-agent`, matching the shape already used by
`patterns/cross-references.md`, `standards/textbook-standards.md`,
`standards/typst-style-guide.md`, and `standards/package-usage.md` (all four-way: both agents,
both listed).

#### `agents/typst-implementation-agent.md` (256 lines) — the exact wiring precedent (element-lint)

Three sites the dispatch names, each with an exact existing element-lint analog to mirror for the
chapter-quality checker:

1. **Stage 4C per-phase self-review** (lines 92-116): the "Mechanical placement/density lint"
   sub-bullet runs `bash .claude/scripts/typst-element-lint.sh --verbose {changed .typ file}` for
   every phase-touched `.typ` file, states the placement-FAIL blocking rule, and states the
   WARN-must-be-reported rule — directly beneath a prose "Structural self-review" sub-bullet that
   it explicitly does not replace ("alongside... never replacing it").
2. **Stage 5 whole-document final verification** (lines 144-158): runs the same lint
   `--verbose {every .typ file touched by this task}` alongside (never replacing) `typst compile`,
   with the same placement-FAIL-is-blocking / WARN-reported-not-dropped language.
3. **Critical Requirements numbered list** (lines 227-256): MUST DO item 7 states the lint
   obligation at both stages explicitly; MUST NOT items 7-8 restate the two placement/tracking
   content prohibitions the lint mechanically enforces.

The chapter-quality checker's wiring should add parallel bullets/items at all three sites (not
replace the element-lint ones — both checkers coexist), following the dispatch's instruction that
a blocking finding is a blocking condition at both stages and advisory findings are reported in
the summary's Verification section. Note the CLI path convention used in this file:
`.claude/scripts/typst-element-lint.sh` (the **deployed** path, not the source-store path) — the
implementation agent operates against a deployed `.claude/` tree, so the new checker's wiring text
should use `.claude/scripts/chapter-quality-check.sh` for consistency, matching the established
convention in this same file rather than a source-store path.

#### `agents/typst-research-agent.md` (161 lines) — Stage 2 context-loading site

Stage 2 ("Analyze Task and Load Context") currently just says "Identify research topic and
determine research questions" with no explicit context-file loading instruction — this agent's
current context loading is entirely index-driven (via `load_when`), not named inline in the
agent file's own prose the way `typst-implementation-agent.md`'s element-lint wiring is. The
dispatch's instruction ("make the standard a loadable context file at its Stage 2 context-loading
step") is most directly satisfied by the `index-entries.json` `load_when.agents` addition alone
(finding above) — this already makes the standard auto-loadable for `typst-research-agent` via
the standard index-driven mechanism, without requiring a second, redundant inline mention. If the
plan chooses to also add an explicit Stage 2 sentence naming the standard (for discoverability
parity with how other agents' Stage 2 sections read), that is additive, not required by any
existing precedent in this file.

#### `skills/skill-typst-implementation/SKILL.md` (139 lines) — "reflect the new verification step"

The skill is a thin wrapper; its own "MUST NOT (Document Structure)" section (lines 94-112)
already states it applies specifically to the Stage 5b self-execution fallback path (the one path
that can author `.typ` content without passing through the agent's own Stage 4C), and is
explicitly kept "in correspondence" with the agent's own MUST NOT items 7-8. The
chapter-quality-check wiring's natural landing site is the same Stage 5b self-review paragraph
(lines 62-68, "Self-review before writing metadata... re-read every `.typ` section... against
`context/project/typst/standards/semantic-element-usage.md`") — extended (or paralleled) to also
apply `chapter-quality.md`'s rules when Stage 5b touches chapter content, plus a corresponding
addition to the "MUST NOT (Document Structure)" list's cross-reference sentence.

#### `EXTENSION.md` (39 lines) — merge-source precedent

The final line already advertises the element lint in exactly the pattern to mirror:
```
- Element-placement/density lint: `bash .claude/scripts/typst-element-lint.sh --verbose FILE...`
  (mechanical backstop for `standards/semantic-element-usage.md`'s Universal Placement Rule;
  placement findings block, item-count and density findings are advisory-only)
```
A new bullet for the chapter-quality checker should follow this exact shape: command line,
one-line description of what it backstops, and the blocking/advisory split summary.

**Tension worth flagging to the plan, not resolved here**: `EXTENSION.md`'s `### Scope` section
(lines 5-9) states "Content-creation work (proofs, theorems, chapters, textbook prose) routes to
`lean4`, `formal`, or `general` as appropriate, not to `typst`." The dispatch nonetheless requires
wiring the chapter-quality gate into `typst-implementation-agent` (not a content-authoring agent)
as a pre-completion gate for "content tasks," stating this is "the behavioural change this task
exists to deliver." This is the dispatch's explicit, literal instruction and should be followed
as written; the apparent tension with the Scope paragraph is a documentation question (whether
`typst-implementation-agent` is now also expected to gate chapter content it did not author, or
whether the gate is meant for whichever agent — `lean4`/`formal`/`general` — actually authors
chapter prose in a consuming repo) that the plan or a follow-up may want to note, but resolving
the extension's scope boundary is outside this task's six named wiring files and file_scope.

### Shell Convention Compliance

- **Strict mode**: both new scripts are Class B (`set -uo pipefail`) per
  `context/standards/shell-strict-mode.md` — they accumulate a findings/PASSED-FAILED count
  across multiple checks and must keep scanning after the first finding to produce an accurate
  summary, exactly the same admission-test outcome already recorded for
  `typst-element-lint.sh`/`test-typst-element-lint.sh` themselves.
- **Test location**: `scripts/tests/test-chapter-quality-check.sh` is correct per
  `context/standards/shell-script-testing.md`'s scope-based location rule (narrow, single-script
  suite -> `scripts/tests/`), matching the sibling `test-typst-element-lint.sh` and the dispatch's
  own stated path.
- **Mutation-check note**: `shell-script-testing.md`'s "Mutation checks for regex-shaped fixes"
  section is about locking in a *fix* to a pre-existing pattern bug — not applicable here since
  this is new-script authorship, not a regex fix, but worth remembering if any MECHANICAL rule's
  regex needs correction after the "review pass against real chapters" the standard requires
  before promoting an ADVISORY rule to BLOCKING.

### External Resources

None consulted — this is a wholly internal, spec-driven implementation task with a complete
in-repo specification and a complete in-repo structural precedent; no external documentation was
needed or relevant.

## Decisions

- The rule inventory table above is the authoritative transcription source for the plan's Phase
  Group A; the plan should reference rule numbers (1.1-4.3) directly rather than re-deriving them
  from the standard a second time.
- Rules 1.2 and 1.3 are implemented directly by this checker; the two Interface-Contract checks
  (name-resolution, chapter-source coverage) are NOT implemented here — this distinction should be
  stated explicitly in the new script's own header, the same way `typst-element-lint.sh`'s header
  explains its own scope boundary.
- New scripts are Class B strict mode, matching the sibling scripts exactly.
- `index-entries.json`'s new entry lists both `typst-implementation-agent` and
  `typst-research-agent` in `load_when.agents`.

## Risks & Mitigations

- **Repo-root / bib-file resolution for Rules 1.2/1.3 is an open design question.** The CLI takes
  a `.typ` file/directory PATH, not an explicit repo root, and `patterns/bibliography.md` treats
  `references.bib` as an example filename, not a fixed convention (the actual filename is
  whatever a document's `#bibliography("...")` call names). Mitigation: the plan should specify a
  resolution strategy up front — e.g., resolve the git repo root via
  `git rev-parse --show-toplevel` from each checked file's directory (mirroring how other scripts
  in this codebase resolve `REPO_ROOT`), and locate the `.bib` file either by globbing for the
  first `*.bib` under that root or by extracting the filename argument from a `#bibliography(...)`
  call if one is discoverable in the checked file or its includes. Document whichever choice is
  made as a KNOWN LIMITATION if it is not fully general (e.g., "assumes exactly one `.bib` file
  under the repo root" or "does not resolve `#include`-transitive bibliography declarations").
- **Acceptance criterion 8 ("the deploy reproduces them into .claude/ cleanly") cannot be verified
  by a plain `deploy-headless.sh` run in this repo**, because the `typst` extension is not among
  this repo's currently-active extensions (`.claude-extensions.json` lists only `core, email,
  literature, memory, nix, nvim`), and `deploy-headless.sh`'s default (non-`--wipe`) mode only
  force-resyncs currently-active extensions plus `core`. Mitigation: follow the proven pattern in
  `scripts/tests/test-deploy-propagation.sh` (a scratch `mktemp -d` git repo, real
  `deploy-headless.sh`, real Lua `manager.load`/`manager.resync_all` engine) to load the `typst`
  extension into a throwaway target and inspect the result there, rather than attempting to load
  `typst` permanently into this repo's own `.claude-extensions.json`. `deploy-headless.sh` itself
  is not prohibited from being run deliberately for this kind of verification —
  `context/patterns/regeneration-is-manual-only.md`'s "Automated Exception" restriction applies to
  *automated pipeline trigger sites* (`skill-orchestrate`, `command-gate-out.sh`), not to a
  deliberate, explicit verification invocation the task's own acceptance criteria call for.
- **JSON schema drift risk**: `index-entries.json` and `manifest.json` are both flat, hand-edited
  JSON with no schema file found in this extension directory (only the "matching the shape of
  existing standards entries" convention). Mitigation: after editing, `jq .` both files to confirm
  well-formedness before considering Phase Group B complete, matching the pattern implied by
  `tests/test-index-entries-schema.sh` existing elsewhere in `core/`.

## Context Extension Recommendations

- **Topic**: none identified as requiring a new context file. The existing
  `shell-strict-mode.md` and `shell-script-testing.md` standards already fully cover the new
  scripts' conventions; the chapter-quality standard already fully specifies the rule content.
  This is a meta task implementing an already-fully-specified interface, not one that surfaces new
  undocumented domain knowledge.

## Appendix

### Files read

- `agent-system/extensions/typst/context/project/typst/standards/chapter-quality.md` (336 lines, full read)
- `agent-system/extensions/typst/scripts/typst-element-lint.sh` (341 lines, full read)
- `agent-system/extensions/typst/scripts/tests/test-typst-element-lint.sh` (331 lines, full read)
- `agent-system/extensions/typst/manifest.json` (78 lines, full read)
- `agent-system/extensions/typst/index-entries.json` (551 lines, full read)
- `agent-system/extensions/typst/agents/typst-implementation-agent.md` (256 lines, full read)
- `agent-system/extensions/typst/agents/typst-research-agent.md` (161 lines, full read)
- `agent-system/extensions/typst/skills/skill-typst-implementation/SKILL.md` (139 lines, full read)
- `agent-system/extensions/typst/EXTENSION.md` (39 lines, full read)
- `agent-system/extensions/typst/context/project/typst/patterns/bibliography.md` (grep only, `.bib`/citation-syntax lines)
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` (full read)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (full read)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (full read)
- `specs/253_typst_chapter_quality_standard/summaries/01_chapter-quality-standard-summary.md` (full read)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (header, ~160 lines)
- `context/patterns/regeneration-is-manual-only.md` (grep for "Automated Exception"/"sanctioned")
- `.claude-extensions.json` (loaded extensions list)
- `specs/state.json` (task 254 entry: `file_scope`, `dependencies`, `description`)

### Commands run

- `find agent-system/extensions/typst -maxdepth 3 -type f`
- `jq -r '.active_projects[] | select(.project_number==254)' specs/state.json`
- `wc -l` on the standard, the element-lint script, and its test
- `find agent-system -iname "shell-strict-mode.md" -o -iname "shell-script-testing.md"`
- `grep -rn "chapter" agent-system/extensions/typst/EXTENSION.md agent-system/extensions/typst/agents/*.md agent-system/extensions/typst/skills/*/SKILL.md`
- `jq -r '.extensions | keys' .claude-extensions.json`
- `grep -n "Automated Exception|sanctioned|does not license|scratch|typst" agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
