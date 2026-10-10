# Roadmap Format Standard

**Purpose**: Define `specs/ROADMAP.md`'s structure as a generation contract: which sections a
regenerate pass derives mechanically from `specs/state.json`, which it must retain byte-identical,
and the parsing patterns a reader or writer matches against.

---

## Placement

`specs/ROADMAP.md` is a single file at the repo's `specs/` root. It carries ordering, gates and
rulings only — per-task detail lives in `specs/TODO.md`. Finished work is **removed, not
archived**: no completion annotation, no history. The title is `# Roadmap`, followed by one
italic preamble paragraph stating the forward-only policy and the last-measured date.

## Section Order

The generator recognises two layouts, classified structurally by `detect_layout()` before either
write mode touches the file. A vocabulary matching neither is `unknown` and is refused loudly
(see "Destructive-Overwrite Refusal" below) rather than guessed at.

### Classic layout

Exactly eight `## ` sections, in this order, each matched by `^## {name}$` (the two sections with
a parenthetical suffix match on the literal header including the suffix):

| # | Header |
|---|--------|
| 1 | `## Goal` |
| 2 | `## Gate state` |
| 3 | `## Next` |
| 4 | `## Open work` |
| 5 | `## Checks before and after every call` |
| 6 | `## Settled decisions (do not re-litigate)` |
| 7 | `## Standing rules` |
| 8 | `## Unfiled observations (none worth a task yet)` |

A roadmap is `classic` iff every one of these eight literal headers is present (exact text
match). `--regenerate`/`--prune` rebuild `## Open work` and `## Next`'s generated parts per the
grammars below; every other section is `authored-verbatim`.

### Stage layout

A roadmap is `stage` iff it carries a header matching `^## Stage [0-9]+` AND some `## ` section's
body holds a fenced code block (a line consisting of three backticks, optionally followed by a
language tag such as `bash`) containing at least one line matching `^/orchestrate `. Detection is
structural, not an enumerated header list, deliberately: a hand-authored stage layout's own
header text has already been observed to drift by rename (e.g. `## Run order at a glance` ->
`## Next batches`; `## Stage 1 — Decidability of L⁺ (preempts everything)` ->
`## Stage 1 — Decidability of L⁺`) between one regenerate pass and the next.

Every `## ` section in a stage layout is retained **byte-for-byte**, in its original order, with
one exception: the **run-order section** -- the first section whose body matches the fenced-block
predicate above -- has its coverage appendix (see "Next Grammar" below) stripped and
freshly rebuilt by `--regenerate`, and has terminal task ids dropped from its Run lines by
`--prune` (the same per-line logic the classic layout's `## Next` uses). No section is invented,
no section is dropped, and no fixed per-section template is applied -- unlike the classic
layout's `assemble_roadmap`, the stage layout's `assemble_stage_roadmap` has no section list of
its own; it only replays whatever sections the file already had, in order.

## Authored vs. Generated

This table, and the Open work Grammar / Next Grammar sections below, describe the **classic**
layout's per-section behaviour. A stage layout has no `## Open work` section at all and no fixed
`## Next` header; its only generated content is the run-order section's coverage appendix, which
follows the same Next Grammar appendix rule below applied to that section's retained body
(see "Stage layout" above).

| Section | Class | Retention key |
|---------|-------|----------------|
| `## Goal` | authored-verbatim | — (whole section) |
| `## Gate state` | measured-by-hand | — (whole section; requires running checks, not reading state) |
| `## Next` | mixed: generated skeleton + authored-retained prose | `next:run:{i}:rationale`, `next:why-this-order` |
| `## Open work` | generated, with per-task authored overrides | `task:{N}:description`, `task:{N}:annotation`, `task:{N}:ext-blocked` |
| `## Checks before and after every call` | authored-verbatim | — (whole section) |
| `## Settled decisions (do not re-litigate)` | authored-verbatim | — (whole section) |
| `## Standing rules` | authored-verbatim | — (whole section) |
| `## Unfiled observations (none worth a task yet)` | authored-verbatim | — (whole section) |

`authored-verbatim` and `measured-by-hand` sections are never rewritten by either mode; the
distinction is only *why* a human owns the text (prose vs. a measurement this task does not
compute). A `generated`/`mixed` section's authored sub-parts are extracted by a retention parser
(mirroring `generate-task-order.sh`'s `read_existing_goal`) before the section is rebuilt, then
re-spliced in.

## Open work Grammar

One fenced block per topic, in `active_topics` order (state.json top-level array), with
append-extras for a topic present on a task but absent from `active_topics` (own block, appended
after the curated topics, one-time stderr warning — mirrors `task-order-format.md` rule 7). A
task with no `topic` field at all falls into a trailing `Uncategorized` block, same fallback as
`task-order-format.md`:

```
**{Topic Title} ({count})**
```
{task lines}
```
```

- Block header: `^\*\*(.+) \((\d+)\)\*\*$` — `{Topic Title}` is the topic's kebab-case slug with
  hyphens replaced by spaces and only its first character capitalized (sentence case, matching
  the live file: `core-agent-system` -> `Core agent system`, `orchestrator` -> `Orchestrator` —
  **not** `task-order-format.md`'s per-word title case), `{count}` is the number of non-terminal
  tasks in the block.
- Any free-standing authored prose following the LAST fenced block (e.g. a `**342's hold**: ...`
  explanatory paragraph that is not itself inside a fence) is an **Open work trailer**: retained
  verbatim by `--regenerate` (appended after the freshly rebuilt blocks) and left untouched by
  `--prune` (which only ever edits lines inside a fence).
- Task line: `^(\d+) (\S+)\s{2,}(.+?)(\s{3}<- (.+))?$` — task number, one space, status token,
  padded with at least two spaces to a target column (minimum two when the token overflows the
  column), description, optional `   <- {annotation}` suffix.
- Within-block ordering: status-token class first (closed-vocabulary tokens before `blocked:N`
  tokens, ascending precedence order below), then task number ascending.
- `{description}` is the authored override at `task:{N}:description` when present, else
  `state.json`'s `title`, truncated with a trailing `...` so the rendered line (task number
  through description, excluding any `<- {annotation}` suffix) stays at or under 100 characters.
- `{annotation}` (the `<- {text}` suffix) is the authored override at `task:{N}:annotation`,
  dropped entirely (no suffix) when absent.

## Status Tokens

A closed vocabulary with a precedence rule. The first matching row wins:

| Precedence | Token | Source |
|---|-------|--------|
| 1 | `HOLD` | `state.json` `status == "hold"` |
| 2 | `IN FLIGHT` | `status == "implementing"` |
| 3 | `BLOCKED` | `status == "blocked"` |
| 4 | `PARTIAL` | `status == "partial"` |
| 5 | `EXT-BLOCKED` | authored override at `task:{N}:ext-blocked`; **no schema support** — never derived, always retained verbatim from the existing file when present |
| 6 | `blocked:N[,M...]` | `dependencies[]` intersected with the non-terminal task set is non-empty; sorted ascending comma list |
| 7 | `ready` | `dependencies[]` intersected with the non-terminal task set is empty |

Rows 1-4 derive from the task's own `status`; rows 6-7 derive from `dependencies[]` and apply only
when none of rows 1-5 match. Row 5 is checked before the dependency filter because an
externally-blocked task may otherwise read `ready` or `blocked:N` against in-repo data alone.

## Next Grammar

```
/orchestrate {task_list}   # {rationale}
```

- Fenced block, one line per batch: `^/orchestrate ([\d, ]+)(\s{3}# (.+))?$`. `{rationale}` is
  authored, retained at `next:run:{i}:rationale` (`{i}` = 0-based line position).
- Below the fence: `Why this order:` followed by a bullet list, entirely authored, retained
  verbatim at `next:why-this-order`.
- A generated **coverage appendix** follows: any currently-dispatchable task (status not in the
  precedence table's rows 1-5, and `blocked:`/`ready` per row 6/7 evaluates `ready`) not named by
  any retained Run line, rendered as additional `/orchestrate` lines chunked at `--max-tasks`
  (default 8, matching `commands/orchestrate.md`'s `MAX_TASKS`) per wave. Header:
  `**Coverage appendix (uncovered tasks)**:`. Omitted entirely when empty.

## Generation

Generated by `scripts/roadmap-integration.sh`, three modes plus a composable flag:

- `--print` (default): emits the generated sections to stdout; mutates nothing. Structurally
  independent of the existing file's layout -- it never reads an existing `specs/ROADMAP.md`, so
  `detect_layout` and the refusal gate below do not apply to it.
- `--regenerate`: on a **classic** layout, rebuilds `## Open work` and `## Next`'s generated
  parts wholly from state, retaining every authored key above; idempotent (a second consecutive
  run is byte-identical). On a **stage** layout, retains every section byte-for-byte except the
  run-order section's coverage appendix, which is stripped and freshly rebuilt; also idempotent.
- `--prune`: narrower — on a **classic** layout, drops terminal tasks from `## Open work` and
  drops a whole Run line once every task it names is terminal, without re-rendering the coverage
  appendix. On a **stage** layout, applies the same Run-line-dropping rule to the run-order
  section's body only; every other section (there is no `## Open work` to prune) is untouched.
- `--dry-run` (composable with the two write modes): prints a diff, writes nothing.

Reuse ledger: `generate-task-order.sh --print`'s `**Dependency Waves**:` table supplies wave
membership (consumed as a subprocess, never sourced — see that script's own file-scope execution
model); `state.json` supplies `project_number`/`status`/`title`/`topic`/`dependencies`/
`hold_reason`/`active_topics` directly; `scripts/lib/status-vocabulary.sh` anchors the status enum
used to exclude the terminal set (`completed`, `abandoned`, `expanded`). No wave/DAG algorithm is
reimplemented; per-task `blocked:`/`ready` derivation is a one-pass filter, the same shape as
`generate-task-order.sh`'s `get_active_tasks()`.

### Destructive-Overwrite Refusal (permanent property)

Before either write mode touches the file, `detect_layout` classifies it as `classic`, `stage`,
or `unknown`. On `unknown`, both `--regenerate` and `--prune` refuse: a named reason on stderr
(listing the file's actual `## ` headers and the two recognised vocabularies), a non-zero exit,
and **no write attempted** -- `--dry-run` or not. This is a permanent property of the generator,
not a transitional guard pending wider layout support: a vocabulary this script cannot
round-trip is never guessed at or silently overwritten with a fixed template, however the
recognised vocabulary set grows in the future.

### Stderr Marker and Failure Diagnostics

Every invocation that reaches mode dispatch -- i.e. passes argument validation -- prints one
always-present machine-readable stderr marker, on success AND on failure:
```
<!-- roadmap-generation mode=M tasks=N topics=T runs=R pruned=P retained=A -->
```
This never affects the exit code — it is a diagnostic, not a failure signal. `--help` and a
usage/argument-validation error (an unknown flag, a missing `--state` file, a malformed
`--max-tasks`) happen BEFORE mode dispatch and print only their own message; the marker and this
section do not apply to them. A failure after that point (including, but not limited to, the
`unknown`-layout refusal above) additionally emits one named stderr line first:
```
ERROR: roadmap-integration.sh failed (mode=M) at line L: exit status N
```
The marker's six-field shape is frozen (see Parsing Patterns Summary below); a refusal or a crash
is diagnosed via this separate `ERROR:` line, never by adding a field to the marker itself.

## Parsing Patterns Summary

| Element | Pattern |
|---------|---------|
| Section header | `^## (.+)$` |
| Open work block header | `^\*\*(.+) \((\d+)\)\*\*$` |
| Open work task line | `^(\d+) (\S+)\s{2,}(.+?)(\s{3}<- (.+))?$` |
| Status token | `HOLD\|IN FLIGHT\|BLOCKED\|PARTIAL\|EXT-BLOCKED\|blocked:[\d,]+\|ready` |
| Next Run line | `^/orchestrate ([\d, ]+)(\s{3}# (.+))?$` |
| Coverage appendix header | `^\*\*Coverage appendix \(uncovered tasks\)\*\*:$` |
| Stderr marker | `^<!-- roadmap-generation mode=(\S+) tasks=(\d+) topics=(\d+) runs=(\d+) pruned=(\d+) retained=(\d+) -->$` |

## Related

- `.claude/context/patterns/roadmap-update.md` — the mode caller contract (who invokes which mode,
  when, and what each promises)
- `.claude/context/formats/task-order-format.md` — the structurally parallel sibling contract for
  TODO.md's generated `## Task Order` section; this file is modeled on its shape
- `.claude/scripts/roadmap-integration.sh` — the generator
