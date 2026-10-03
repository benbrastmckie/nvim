# Implementation Plan: Scaffold the books extension (wiring)

- **Task**: 297 - Scaffold the books extension: manifest, routing, agents, skills, commands, rule and tests
- **Status**: [IMPLEMENTING]
- **Effort**: 10.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/297_scaffold_books_extension_routing_and_agents/reports/01_books-extension-scaffold-research.md
- **Artifacts**: plans/01_books-extension-wiring.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  extension-slim-standard.md, agent-frontmatter-standard.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the `books` extension in the agent-system source store at
`agent-system/extensions/books/`, providing the `books` task type for authoring, certifying and
documenting lean books. This task owns WIRING only: manifest, four agents, six skills, two
commands, one rule, one passthrough script plus its test, and the four registration/doc files.
The domain context corpus under `context/project/books/` is a separate dependent task, so this
task ships only a navigation stub there and points at it with plain backticked paths.
Definition of done: every file below exists in the source store, and
`agent-system/extensions/core/scripts/check-extension-docs.sh` plus the index and wiring
validators run clean over the new extension.

### Research Integration

The research report's Decisions section is treated as fixed design and is not re-litigated:

- **Decision 1** — `keyword_overrides` is narrow and multi-word (the 14-token set measured live
  in Findings §2). The residual `.lean`-strong-anchor capture gap is **spawned, not absorbed**.
- **Decision 2** — `/reconcile`, its lifecycle hook and its write guard are **NOT built here**;
  the recommendation that they move into `books` is a follow-up to spawn.
- **Decision 3** — routing declares `books` and `books:certify` only; **`books:document` is
  deliberately omitted** (zero landed backing).
- **Decision 4** — `--hard` agent variants ARE authored; all four agents are `model: sonnet`;
  H-sets follow cslib's (H2/H3/H4 research; H2/H7/H9 implementation), not lean4's.
- **Decision 5** — `/book` (single-book developer loop) and `/certify` (graph-wide driver
  passthrough) are two commands, each paired with a direct-execution skill.
- **Decision 6** — the rule uses the **flattened** book-directory layout (`book.toml`,
  `book.cert.json`, `book.typ` side by side; no `docs/` segment). The dispatch's own grounding
  paragraph is stale on this point and must not be copied.
- Two routing blocks only (`routing_agents`, `routing_agents_hard`), per the dispatch's own
  SCOPE CORRECTION and confirmed as already the live shape of `cslib`/`lean`/`typst` on disk.

**One measured addition this plan makes to the research's recommendations.** Research
Recommendation 6 deliberately left "ship extension-local scripts or not" open for plan time, and
leaned toward zero. Measuring `check-extension-docs.sh`'s Rule E
(`check_referenced_scripts_declared`) settles it the other way: that check extracts every
`[A-Za-z0-9_-]+\.(sh|sql)\b` token from the extension's `commands/*.md`, `skills/*/SKILL.md`,
`agents/*.md`, `README.md` and `EXTENSION.md`, and hard-`fail`s on any token not declared in some
extension's `provides.scripts`/`provides.hooks` (basename-normalized; no allowlist, no severity
knob). A `/certify` command that shows its real invocation therefore cannot name the consuming
repository's `certify.sh` directly. Resolution adopted here: ship exactly ONE extension-local
script, a thin resolve-and-passthrough wrapper, declare it in `provides.scripts`, and have the
command docs name the wrapper. This simultaneously makes the dispatch's deliverable 7
(fixtures/tests under `scripts/tests/`) real rather than vacuous. Note that Rule E does **not**
scan `rules/`, so `rules/books.md` may name the consuming repo's SPDX header check directly, as
deliverable 5 asks.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no `roadmap_flag` was set, so no
roadmap phases are added and no roadmap file was consulted.

## Goals & Non-Goals

**Goals**:
- A complete, lint-clean `books` extension in the source store with the `books` task type.
- Two-block routing (`routing_agents`, `routing_agents_hard`) keyed on `books` and `books:certify`.
- Four agents (base + `--hard` pair, all `model: sonnet`), six skills, two commands, one rule.
- One passthrough script plus its fixture test under `scripts/tests/`.
- A `books`-scoped rule carrying the non-negotiables against the **current** design record.
- `EXTENSION.md` (≤60 lines), `README.md`, `index-entries.json`, `opencode-agents.json`.
- Task-type detection that routes unambiguous book descriptions to `books` without capturing any
  `lean4`, `cslib`, `typst` or `pr` task.

**Non-Goals**:
- The domain context corpus under `context/project/books/**` beyond a navigation stub (separate
  dependent task).
- `/reconcile`, its lifecycle postflight hook, its write guard, the `/review` Book-health section
  (owned by the already-scoped reconciliation work; moving it into `books` is a follow-up).
- Editing `agent-system/extensions/core/scripts/lib/task-type-detect.sh` or any other file outside
  `agent-system/extensions/books/**`.
- `routing` and `routing_hard` blocks (retired by the in-flight routing-ladder collapse).
- A `books:document` sub-route or any docs-stage skill (no landed backing).
- Any hand-authored file under `.claude/**`.
- Enabling the extension in the Verification repo's `.claude-extensions.json` (the user's action).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The Verification repo's `books/` tooling changed again since research (writer and shell driver landed the same day research ran) | M | H | Phase 1 re-verifies the landed/unlanded boundary against the live tree before any command or doc text is written; every capability claim in `/book`, `/certify` and `EXTENSION.md` must trace to that re-verification, not to the report |
| Rule E hard-fails on a bare `<name>.sh` token in `agents/`, `skills/`, `commands/`, `README.md` or `EXTENSION.md` | H | H | Only the declared wrapper may be named by bare filename in those five locations; consuming-repo scripts are referred to by directory plus prose there, and by name only in `rules/books.md` (not scanned). Phase 8 runs the lint to confirm |
| `provides.context: ["project/books"]` fails the lint's on-disk check because the corpus is a separate task | H | H | Phase 1 ships `context/project/books/README.md` as a navigation stub (wiring, not corpus) so the declaration is honest and resolvable; the dependent task extends it |
| Over-broad `books` keywords capture other extensions' tasks, since `books` sorts first among all 21 extension directories and first match is final | H | M | Keyword set is restricted to the 14 multi-word/underscored tokens measured in research Findings §2; Phases 1 and 8 both re-run the 7-row detection table including the negative rows |
| `index-entries.json` `line_count` drifts from `wc -l`, or carries a forbidden key (`description`, `tags`, `tier`) | M | M | Phase 7 computes `line_count` with `wc -l` at authoring time; Phase 8's lint check is the gate |
| `README.md` older than `manifest.json` triggers the lint's drift warning | L | M | Phase 7 writes `README.md` after `manifest.json`; Phase 8 verifies mtime ordering and re-touches if needed |
| Copying the dispatch's stale `docs/` book-directory layout into the rule | M | M | Decision 6 is called out explicitly in the Overview and in Phase 4's tasks; Phase 4 verification greps the rule for a `docs/book` path |
| Sibling task dispatched this same cycle touches `agent-system/extensions/core/scripts/**` | M | M | That sibling's file scope and this task's are disjoint; never edit core here, re-read before any shared-file operation, stage only this task's own paths, never a directory or glob `git add` |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6 | 1, 5 |
| 4 | 7 | 2, 3, 4, 5, 6 |
| 5 | 8 | 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Skeleton, manifest, and task-type detection [COMPLETED]

**Goal**: The extension directory exists with a complete, honest `manifest.json`, and task-type
detection is measured to route book descriptions to `books` without capturing any other
extension's tasks.

**Tasks**:
- [x] Re-verify the landed/unlanded boundary in `~/Projects/Logos/Verification` with bounded,
      targeted reads (not a survey): the real flag set accepted by `books/scripts/certify.sh`;
      the subcommands `books-tool` actually exposes; the presence or absence of
      `books/tool/approve-guarantees.sh`, `books/tool/book-health.sh`, and the certifier docs
      stage; the current `passes` array in a real `book.cert.json`. Record the findings in the
      implementation progress notes; every later phase's capability claims cite them. *(completed)*
- [x] Create `agent-system/extensions/books/{agents,skills,commands,rules,scripts/tests,context/project/books}/`. *(completed)*
- [x] Write `context/project/books/README.md` as a navigation stub only: what the `books` task
      type covers, and that the domain corpus is authored by a separate dependent task. Do not
      author domain content here. *(completed)*
- [x] Write `manifest.json`: `name: "books"`, `version: "1.0.0"`, a one-line `description`,
      `task_type: "books"`, `dependencies: ["core", "lean", "typst"]`. *(completed)*
- [x] `provides`: the four agent filenames, the six skill directory names, `["book.md",
      "certify.md"]`, `["books.md"]`, `context: ["project/books"]`,
      `scripts: ["books-certify.sh", "tests/test-books-certify.sh"]`, `hooks: []`. *(completed)*
- [x] `routing_agents`: `research.books` -> `books-research-agent`, `plan.books` ->
      `planner-agent`, `implement.books` -> `books-implementation-agent`, each key duplicated for
      `books:certify` mapping to the same agent (the `lean4:lake` precedent).
      `routing_agents_hard`: `research.books` -> `books-research-hard-agent`,
      `implement.books` -> `books-implementation-hard-agent` (no hard plan key — plan always goes
      to `planner-agent`). Author NO `routing` and NO `routing_hard` block. *(completed)*
- [x] `keyword_overrides.books.keywords`: the 14 measured tokens `book.toml`, `book_layer`,
      `book_export`, `book module`, `book.cert.json`, `layer matrix`, `certified unit`,
      `book_ledger`, `book_axioms`, `book_requires`, `book_policy`, `book_assume`,
      `book_not_claimed`, `books-tool`. `aliases: []` (no alias remap — unlike cslib, `books`
      must not steal a weak-signal `lean4` resolution). *(completed)*
- [x] `merge_targets`: `claudemd` (source `EXTENSION.md`, target `.claude/CLAUDE.md`,
      `section_id: "extension_books"`), `index` (`index-entries.json` ->
      `.claude/context/index.json`), `opencode_json` (`opencode-agents.json` -> `opencode.json`).
      No `settings` target. *(completed)*
- [x] Re-run detection: source `agent-system/extensions/core/scripts/lib/task-type-detect.sh` and
      call `detect_task_type` against the real `specs/state.json` and the real
      `agent-system/extensions` directory for all seven rows of research Findings §2 — the three
      positive book rows AND the four negative rows (`lean4` via `.lean`, `typst`, `pr`, Mathlib).
      Confirm no negative row changed. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: 14 keyword tokens and a 7-row detection table are asserted. Confirm at
implementation time by running `detect_task_type` for every row and comparing against research
Findings §2's recorded outputs; if any negative row flips, narrow the offending token rather than
accepting the new result.

**Files to modify**:
- `agent-system/extensions/books/manifest.json` - new: full manifest, two routing blocks only
- `agent-system/extensions/books/context/project/books/README.md` - new: navigation stub so
  `provides.context` resolves on disk

**Verification**:
- `jq -e . agent-system/extensions/books/manifest.json` parses.
- `jq -e '.routing | not' ` and `jq -e '.routing_hard | not'` both true (no retired blocks).
- Every `provides` entry resolves to an existing path (the lint's own check, previewed by hand).
- All seven detection rows reproduce their expected task type.

---

### Phase 2: Agents [COMPLETED]

**Goal**: Four agent definitions whose `name:` frontmatter matches the manifest's routing targets
exactly.

**Tasks**:
- [x] `agents/books-research-agent.md` — frontmatter `name: books-research-agent`, a one-line
      `description`, `model: sonnet`. Body follows `typst/agents/typst-research-agent.md`'s
      structure (Overview, Dispatch File, Context References, Execution Flow stages, metadata
      file contract, Critical Requirements). *(completed)*
- [x] `agents/books-implementation-agent.md` — same shape, modeled on
      `typst/agents/typst-implementation-agent.md`. *(completed)*
- [x] `agents/books-research-hard-agent.md` — H-technique prose per cslib's research hard agent:
      H2 (anti-analysis), H3 (reference grounding against the design record), H4 (adversarial
      verification). `model: sonnet` — the hard variant never changes tier from its base. *(completed)*
- [x] `agents/books-implementation-hard-agent.md` — H2, H7 (territory contracts), H9 (wrap-up
      discipline). `model: sonnet`. *(completed)*
- [x] All four reference domain context as plain backticked paths
      (`context/project/books/...`), never `@`-imports, and note that the corpus is authored by a
      separate task so a missing file is expected today. *(completed)*
- [x] Rule E compliance: in these four files, do not write any bare `<name>.sh` token other than
      `books-certify.sh`. Name consuming-repo scripts by their directory plus prose. *(completed)*

**Timing**: 1.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: exactly four agent files, all `model: sonnet`. Confirm by diffing each
file's `name:` value against the manifest's routing target strings, and by `grep -c '^model: sonnet'`
across `agents/`.

**Files to modify**:
- `agent-system/extensions/books/agents/books-research-agent.md` - new
- `agent-system/extensions/books/agents/books-implementation-agent.md` - new
- `agent-system/extensions/books/agents/books-research-hard-agent.md` - new
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md` - new

**Verification**:
- Every `name:` in `agents/*.md` appears in `provides.agents` and in a routing block value.
- `grep -oE '[A-Za-z0-9_-]+\.(sh|sql)\b' agents/*.md` yields nothing but `books-certify.sh`.
- No `@`-prefixed context import appears in any of the four files.

---

### Phase 3: Lifecycle skills [COMPLETED]

**Goal**: The four lifecycle skills (research/implementation base pair plus `--hard` variants),
each dispatching to the matching Phase 2 agent.

**Tasks**:
- [x] `skills/skill-books-research/SKILL.md` — frontmatter `name`, `description` ending "Invoke
      for books research tasks.", and a body modeled on `skill-typst-research/SKILL.md`;
      `subagent_type: books-research-agent`. *(completed)*
- [x] `skills/skill-books-implementation/SKILL.md` — `subagent_type: books-implementation-agent`. *(completed)*
- [x] `skills/skill-books-research-hard/SKILL.md` — modeled on `skill-cslib-research-hard`;
      `subagent_type: books-research-hard-agent`. *(completed)*
- [x] `skills/skill-books-implementation-hard/SKILL.md` —
      `subagent_type: books-implementation-hard-agent`. *(completed)*
- [x] No lifecycle skill is created for the `books:certify` sub-route — it reuses the base pair
      per Decision 3. State this once, in the implementation skill's body, so a later reader does
      not read the sub-route as unimplemented. *(completed)*
- [x] Rule E compliance as in Phase 2. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: exactly four lifecycle skill directories, each with a single `SKILL.md`.
Confirm by comparing `ls skills/` against `provides.skills` minus the two direct-execution skills
added in Phase 6.

**Files to modify**:
- `agent-system/extensions/books/skills/skill-books-research/SKILL.md` - new
- `agent-system/extensions/books/skills/skill-books-implementation/SKILL.md` - new
- `agent-system/extensions/books/skills/skill-books-research-hard/SKILL.md` - new
- `agent-system/extensions/books/skills/skill-books-implementation-hard/SKILL.md` - new

**Verification**:
- Every `subagent_type` named in these four files exists as an `agents/*.md` `name:`.
- Every skill directory on disk is listed in `provides.skills` (the lint's Rule A direction).

---

### Phase 4: The books rule [COMPLETED]

**Goal**: One `books`-scoped rule carrying the non-negotiables, written against the current
(flattened) design record.

**Tasks**:
- [x] `rules/books.md` with `paths:` frontmatter matching book directories, book modules and
      manifests: `["**/books/**", "**/Book.lean", "**/Book/*.lean"]`. *(completed)*
- [x] Content, each stated as a non-negotiable with its measured failure mode:
      (1) facts in Lean, judgments in TOML, everything else computed — a code module carries only
      `@[book_export]` (no kind argument) and one `book_layer <layer>` line; the six `book_*` fact
      commands belong to the book module, and the certifier warns on one found in a code module;
      (2) `book.cert.json` sits directly in the book directory and is the only input of every
      non-Lean tool;
      (3) the **flattened** book-directory layout — `book.toml`, `book.cert.json` and `book.typ`
      side by side, never `docs/book.typ`; a multi-file `docs/` entry remains legal but is not the
      modelled case;
      (4) explicit per-module lakefile `globs`, NEVER `Books.+` — cite the measured
      `bad import 'Books.Meta'` failure that follows from two packages claiming the `Books` root;
      (5) licence-header-then-`module` line order as a **structural** invariant (the header
      comment within the first three lines; in a `module` file the comment is line 1 and `module`
      line 2, because a comment parses ahead of the `module` keyword), pointing at the consuming
      repository's own SPDX convention for the exact header text rather than hardcoding it;
      (6) never hand-edit a generated certificate or a generated Typst fragment, and never author
      a computed field. *(completed)*
- [x] Name the consuming repo's SPDX header check by filename here if useful — `rules/` is not
      scanned by Rule E. *(completed)*
- [x] No task-number references anywhere in the file; cite file paths, decision numbers and
      script names. *(completed)*

**Timing**: 1.0 hour

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: six non-negotiables in one file. Confirm by grepping the finished file for a
heading or bolded lead-in per item and counting six.

**Files to modify**:
- `agent-system/extensions/books/rules/books.md` - new

**Verification**:
- `grep -n 'docs/book' rules/books.md` returns only the explicitly-marked legacy/exception
  mention, never a prescriptive path.
- `grep -nE 'Books\.\+' rules/books.md` appears only inside the prohibition.
- `bash .claude/scripts/check-task-references.sh` (or the equivalent repo lint) reports no
  task-number reference in the new file.
- The rule filename appears in `provides.rules`.

---

### Phase 5: Certify passthrough script and its test [COMPLETED]

**Goal**: One extension-local wrapper that resolves and invokes the consuming repository's book
certification driver, with a fixture test, so `/certify` can name a declared script and Rule E
passes.

**Tasks**:
- [x] `scripts/books-certify.sh` — resolve the repository root, locate the certification driver
      under the repo's `books/scripts/`, pass every argument through verbatim, and fail loudly
      with an actionable message when the driver is absent (the extension may be loaded in a repo
      that has no books tooling). Pass through only the flags Phase 1 re-verified as real;
      deliberately do not expose the acceptance-suite-only graph-injection flag. *(completed)*
- [x] Mirror the lean/typst script conventions: `#!/usr/bin/env bash`, `set -euo pipefail`, a
      header comment block stating purpose and exit codes, and no interactive prompts. *(completed)*
- [x] `scripts/tests/test-books-certify.sh` — fixture cases: driver present and invoked with
      arguments forwarded in order; driver absent and the loud failure path taken with a non-zero
      exit; the suppressed flag rejected rather than silently forwarded. Follow the style of
      `lean/scripts/tests/test-*.sh`. *(completed)*
- [x] Confirm both paths are already declared in `provides.scripts` from Phase 1. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: one wrapper plus one test file, with three fixture cases. Confirm by running
the test and reading its case count in the output.

**Files to modify**:
- `agent-system/extensions/books/scripts/books-certify.sh` - new
- `agent-system/extensions/books/scripts/tests/test-books-certify.sh` - new

**Verification**:
- `bash -n` on both files.
- `shellcheck` clean (or no new findings relative to the lean/typst suites' accepted baseline).
- `bash agent-system/extensions/books/scripts/tests/test-books-certify.sh` exits 0 with all cases
  reported.

---

### Phase 6: Commands and direct-execution skills [COMPLETED]

**Goal**: `/book` and `/certify` as two commands with non-overlapping scope, each paired with a
direct-execution skill.

**Tasks**:
- [x] `commands/book.md` — single-book developer loop, modeled on `lean/commands/lake.md`'s
      step-numbered inline-bash structure: resolve the named book's `book.toml`, build its module
      scope, run the manifest validator, then the environment-walk check against the built library
      directory. State explicitly, in the command body, that full documentation reconciliation is
      OUT of its scope and owned elsewhere — report it, never silently skip it. *(completed)*
- [x] `commands/certify.md` — thin passthrough over `books-certify.sh`, with an options table
      carrying only the flags Phase 1 re-verified. Explain in one line why certification is a
      separate command from `/book`: it is a graph-wide, dependency-ordered operation over many
      books, not a single-book concern. *(completed)*
- [x] `skills/skill-books-build/SKILL.md` — direct-execution skill paired with `/book`, its
      `description` ending "Invoke for /book command." *(completed)*
- [x] `skills/skill-books-certify/SKILL.md` — paired with `/certify`, description ending
      "Invoke for /certify command." *(completed)*
- [x] Rule E compliance: `books-certify.sh` is the only bare `<name>.sh` token permitted in these
      four files. *(completed)*
- [x] Confirm both command filenames and both skill directory names are already in `provides`. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 5

**Verification Tier**: interface

**Scope Hypothesis**: two commands and two direct-execution skills; `/certify`'s options table
matches the driver's real flag set. Confirm the flag set against Phase 1's recorded
re-verification, not against the research report's snapshot.

**Files to modify**:
- `agent-system/extensions/books/commands/book.md` - new
- `agent-system/extensions/books/commands/certify.md` - new
- `agent-system/extensions/books/skills/skill-books-build/SKILL.md` - new
- `agent-system/extensions/books/skills/skill-books-certify/SKILL.md` - new

**Verification**:
- `grep -ohE '[A-Za-z0-9_-]+\.(sh|sql)\b' commands/*.md skills/skill-books-{build,certify}/SKILL.md
  | sort -u` yields exactly `books-certify.sh`.
- Every flag in `certify.md`'s options table appears in `books-certify.sh`'s passthrough handling.
- `commands/book.md` contains an explicit out-of-scope statement about documentation
  reconciliation.

---

### Phase 7: EXTENSION.md, README.md, index entries, opencode registration [COMPLETED]

**Goal**: The four registration and documentation files, all consistent with what the previous
phases actually shipped.

**Tasks**:
- [x] `EXTENSION.md`, **at most 60 lines** (lint-enforced): routing table, skill-to-agent mapping,
      the two commands, a `### Scope` section stating that authoring or mathematically verifying
      the underlying Lean content is out of scope for `books` (it routes to `lean4`/`cslib`), and a
      short, explicit note that a `books` task whose description names a `.lean` file will be
      captured by the `lean4` strong anchor and must be created with an explicit
      `--task-type books`. Plain backticked context pointers only. *(completed)*
- [x] `README.md`, written AFTER `manifest.json` so its mtime is newer: extension overview,
      directory map, and an explicit mention of both `/book` and `/certify` (the lint flags a
      manifest command absent from the README). *(completed)*
- [x] `index-entries.json` — a single entry for `project/books/README.md` with `line_count`
      computed by `wc -l` at authoring time. Required keys only (`path`, `domain: "project"`,
      `subdomain: "books"`, `summary`, `line_count`, plus `load_when` and `keywords`); the
      forbidden keys `description`, `tags` and `tier` must not appear. The dependent corpus task
      adds the rest. *(completed)*
- [x] `opencode-agents.json` — four `agent` entries following `typst/opencode-agents.json`'s
      shape, each `prompt` pointing at `{file:.claude/agents/books-*-agent.md}` and each tool set
      matching the agent's actual needs. *(completed)*
- [x] Rule E compliance in `README.md` and `EXTENSION.md` as in Phase 2. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 2, 3, 4, 5, 6

**Verification Tier**: interface

**Scope Hypothesis**: `EXTENSION.md` ≤60 lines; exactly one index entry; exactly four opencode
agent entries. Confirm with `wc -l EXTENSION.md`, `jq '.entries | length'`, and
`jq '.agent | keys | length'`.

**Files to modify**:
- `agent-system/extensions/books/EXTENSION.md` - new, ≤60 lines
- `agent-system/extensions/books/README.md` - new, mentions both commands, mtime after manifest
- `agent-system/extensions/books/index-entries.json` - new, one schema-conformant entry
- `agent-system/extensions/books/opencode-agents.json` - new, four agent entries

**Verification**:
- `wc -l < EXTENSION.md` is at most 60.
- `jq -e '.entries[0].line_count'` equals `wc -l < context/project/books/README.md`.
- `jq -e '[.entries[] | has("description") or has("tags") or has("tier")] | any | not'` is true.
- Both `/book` and `/certify` appear in `README.md`.
- Every opencode `prompt` path corresponds to a real `agents/*.md` file.

---

### Phase 8: Lint, wiring and detection gate [NOT STARTED]

**Goal**: The whole extension passes the repository's own extension gates, and detection is
re-measured on the finished manifest.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and resolve every
      finding attributable to `books`. Do NOT edit that script or any other core file — a sibling
      task is dispatched against `agent-system/extensions/core/scripts/check-extension-docs.sh`
      this same cycle; treat a failure inside core's own files as possibly that sibling's in-flight
      edit and report it rather than fixing it here.
- [ ] Run `bash agent-system/extensions/core/scripts/validate-index.sh` and
      `bash agent-system/extensions/core/scripts/validate-wiring.sh`; resolve `books` findings.
- [ ] Confirm `README.md` is newer than `manifest.json`; if a later manifest edit inverted the
      order, re-touch `README.md` with a substantive edit rather than a bare `touch`.
- [ ] Re-run the full 7-row `detect_task_type` table against the finished manifest and confirm it
      matches Phase 1's result (the manifest may have changed since).
- [ ] Confirm nothing was written under `.claude/**` by this task:
      `git status --short -- .claude/` shows no new `books` artifacts.
- [ ] Confirm no task-number reference landed in any file under
      `agent-system/extensions/books/**`.

**Timing**: 0.75 hours

**Depends on**: 7

**Verification Tier**: full

**Scope Hypothesis**: the lint, index and wiring validators all report zero `books`-attributable
failures. Confirm by reading each run's output; an INFO/WARN about `books` not being deployed
(the extension is intentionally not installed in this repo) is expected and is not a failure.

**Files to modify**:
- `agent-system/extensions/books/manifest.json` - only if a validator finding requires it
- `agent-system/extensions/books/README.md` - only if a validator finding or mtime ordering
  requires it

**Verification**:
- `check-extension-docs.sh` reports no FAIL for the `books` extension.
- `validate-index.sh` and `validate-wiring.sh` report no `books` failures.
- All seven detection rows match Phase 1.
- `git status --short -- .claude/` is empty of `books` files.

## Testing & Validation

- [ ] `jq -e .` parses `manifest.json`, `index-entries.json` and `opencode-agents.json`.
- [ ] `bash -n` and `shellcheck` clean on `scripts/books-certify.sh` and its test.
- [ ] `bash agent-system/extensions/books/scripts/tests/test-books-certify.sh` exits 0.
- [ ] `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no `books` FAIL
      (notably Rule A skills, Rule B/C routing targets, Rule E referenced scripts, Rule U
      EXTENSION.md 60-line limit, the `provides.*` on-disk checks, and the `index-entries.json`
      `line_count`/schema checks).
- [ ] `bash agent-system/extensions/core/scripts/validate-index.sh` and `validate-wiring.sh` clean
      for `books`.
- [ ] `detect_task_type` reproduces all seven rows (3 positive book rows, 4 unchanged negatives).
- [ ] No file under `agent-system/extensions/books/**` contains a task-number reference.
- [ ] No file was created or modified under `.claude/**`.

## Artifacts & Outputs

Nineteen new files, all under `agent-system/extensions/books/`:

- `manifest.json`
- `agents/books-research-agent.md`, `agents/books-implementation-agent.md`,
  `agents/books-research-hard-agent.md`, `agents/books-implementation-hard-agent.md`
- `skills/skill-books-research/SKILL.md`, `skills/skill-books-implementation/SKILL.md`,
  `skills/skill-books-research-hard/SKILL.md`, `skills/skill-books-implementation-hard/SKILL.md`,
  `skills/skill-books-build/SKILL.md`, `skills/skill-books-certify/SKILL.md`
- `commands/book.md`, `commands/certify.md`
- `rules/books.md`
- `scripts/books-certify.sh`, `scripts/tests/test-books-certify.sh`
- `EXTENSION.md`, `README.md`, `index-entries.json`, `opencode-agents.json`
- `context/project/books/README.md` (navigation stub only)

Plus the task summary under `specs/297_scaffold_books_extension_routing_and_agents/summaries/`.

**Follow-ups to spawn, never absorbed into this task**:
1. Amend core's task-type detection (`scripts/lib/task-type-detect.sh`) so a description naming a
   `.lean` file, `book.toml`, `book_layer` or `book.cert.json` is not captured unconditionally by
   the `lean4` strong anchor ahead of every extension's own `keyword_overrides`.
2. Move the already-scoped reconciliation work — the `/reconcile` command and skill, the lifecycle
   postflight docs-stage hook, the write guard, the `/review` Book-health section and its five
   fixtures — out of the typst and lean extensions and into `books`. Refer to it by title and
   deliverables only.
3. Add the `books:document` routing sub-route and any docs-stage skill once the certifier's docs
   stage, the documentation queue JSON, and the guarantee-approval and book-health scripts land.
4. Author the `context/project/books/**` domain corpus (already a separate dependent task) and
   extend `index-entries.json` accordingly.

## Rollback/Contingency

Every phase creates new files inside a single new directory and touches nothing outside
`agent-system/extensions/books/**`, so contingency is straightforward: the extension is not
deployed, not listed in any repo's `.claude-extensions.json`, and `routing_agents` entries for an
uninstalled extension are an INFO-level lint note rather than a failure. A partial landing is
therefore inert — it cannot misroute an existing task or break another extension.

- To abandon the whole task: remove `agent-system/extensions/books/` entirely. Nothing else
  references it.
- To back out a single phase: revert that phase's own commit. Phases are independently
  committed per the commit-per-green-substep mandate.
- If a working-tree rollback that discards uncommitted changes is genuinely needed, follow
  `context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
  shape, including its out-of-scope override flag. Do not emit a bare reverting snapshot call as a
  routine start-of-phase precaution; for an ordinary defensive checkpoint before risky work use
  the non-reverting form instead.
- The one cross-cutting risk is `keyword_overrides`: because `books` sorts first among all
  extension directories and first match is final, an over-broad token silently captures other
  extensions' tasks. If that is observed after landing, the minimal fix is to narrow or remove the
  offending token in `manifest.json` alone — no other file needs to change.
