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
predicate above -- has its body replaced wholly by `render_next()`'s output (see "Next Grammar"
below) under `--regenerate`, which already omits a batch whose members are all terminal (the
same per-batch logic the classic layout's `## Next` uses, so `--prune`'s now-deprecated alias
needs no separate stage-layout logic of its own). No section is invented,
no section is dropped, and no fixed per-section template is applied -- unlike the classic
layout's `assemble_roadmap`, the stage layout's `assemble_stage_roadmap` has no section list of
its own; it only replays whatever sections the file already had, in order.

## Authored vs. Generated

This table, and the Open work Grammar / Next Grammar sections below, describe the **classic**
layout's per-section behaviour. A stage layout has no `## Open work` section at all and no fixed
`## Next` header; its only generated content is the run-order section's coverage appendix, which
follows the same Next Grammar appendix rule below applied to that section's retained body
(see "Stage layout" above).

| Section | Class | State field |
|---------|-------|----------------|
| `## Goal` | authored-verbatim | — (whole section) |
| `## Gate state` | measured-by-hand | — (whole section; requires running checks, not reading state) |
| `## Next` | **generated**, wholly from state | `roadmap_batches[]` (batches, in array order) plus `roadmap_notes.next_preamble` / `.next_postamble` |
| `## Open work` | **generated**, wholly from state | `active_projects[]` (`title`, `status`, `dependencies`) plus `roadmap_annotation` / `roadmap_ext_blocked` plus `roadmap_notes.open_work_trailer` |
| `## Checks before and after every call` | authored-verbatim | — (whole section) |
| `## Settled decisions (do not re-litigate)` | authored-verbatim | — (whole section) |
| `## Standing rules` | authored-verbatim | — (whole section) |
| `## Unfiled observations (none worth a task yet)` | authored-verbatim | — (whole section) |

`authored-verbatim` and `measured-by-hand` sections are never rewritten by either mode; the
distinction is only *why* a human owns the text (prose vs. a measurement this task does not
compute). `## Next` and `## Open work` are rendered wholly from the state fields named above —
there is no retention parser anywhere in the path: nothing in `roadmap-integration.sh` reads
authored content back out of the file it is about to overwrite. A second consecutive
`--regenerate` is byte-identical, the same idempotence property the generator already held.

### Per-Section Ruling

Every section's disposition, settled explicitly rather than left implicit:

| Section | Ruling | Why |
|---|---|---|
| `## Goal` | authored-verbatim | A standing mission statement; no structured shape an agent would revise. |
| `## Gate state` | **cannot be generated at all** | Every bullet cites a freshly-run suite count, a probe result, or a lock-contention observation — measured by running checks, not derived from any field a state entry could hold. |
| `## Next` | generated | Sourced from `roadmap_batches` + `roadmap_notes.next_preamble`/`.next_postamble`; see `render_next()`. |
| `## Open work` | generated | Sourced from `active_projects` + `roadmap_annotation`/`roadmap_ext_blocked` + `roadmap_notes.open_work_trailer`; see `render_open_work()`. |
| `## Checks before and after every call` | authored-verbatim | A fixed procedural checklist; no per-item structured shape. |
| `## Settled decisions (do not re-litigate)` | authored-verbatim | Owner rulings; no per-task shape to generate from. |
| `## Standing rules` | authored-verbatim | Same shape as Settled decisions — owner-authored, not per-task. |
| `## Unfiled observations (none worth a task yet)` | authored-verbatim | A scratch list, deliberately unstructured. |

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
- Free-standing prose following the LAST fenced block (e.g. a `**342's hold**: ...` explanatory
  paragraph that is not itself inside a fence) is the **Open work trailer**, rendered from
  `roadmap_notes.open_work_trailer` (one paragraph per array entry) and appended after the
  freshly rebuilt blocks. `--prune` (a deprecated alias for `--regenerate`) renders the same way.
- Task line: `^(\d+) (\S+)\s{2,}(.+?)(\s{3}<- (.+))?$` — task number, one space, status token,
  padded with at least two spaces to a target column (minimum two when the token overflows the
  column), description, optional `   <- {annotation}` suffix.
- Within-block ordering: status-token class first (closed-vocabulary tokens before `blocked:N`
  tokens, ascending precedence order below), then task number ascending.
- `{description}` is always rendered from `state.json`'s `title` (the sole source — there is no
  per-task description override), truncated with a trailing `...` so the rendered line (task
  number through description, excluding any `<- {annotation}` suffix) stays at or under 100
  characters.
- `{annotation}` (the `<- {text}` suffix) is rendered from the task entry's `roadmap_annotation`
  field, dropped entirely (no suffix) when absent.

## Status Tokens

A closed vocabulary with a precedence rule. The first matching row wins:

| Precedence | Token | Source |
|---|-------|--------|
| 1 | `HOLD` | `state.json` `status == "hold"` |
| 2 | `IN FLIGHT` | `status == "implementing"` |
| 3 | `BLOCKED` | `status == "blocked"` |
| 4 | `PARTIAL` | `status == "partial"` |
| 5 | `EXT-BLOCKED` | the task entry's `roadmap_ext_blocked` field (boolean, schema-backed) |
| 6 | `blocked:N[,M...]` | `dependencies[]` intersected with the non-terminal task set is non-empty; sorted ascending comma list |
| 7 | `ready` | `dependencies[]` intersected with the non-terminal task set is empty |

Rows 1-4 derive from the task's own `status`; rows 6-7 derive from `dependencies[]` and apply only
when none of rows 1-5 match. Row 5 is checked before the dependency filter because an
externally-blocked task may otherwise read `ready` or `blocked:N` against in-repo data alone.

## Next Grammar

This is now a **rendering contract**, not a parsing one: `render_next()` builds `## Next` from
`roadmap_batches` and `roadmap_notes`; nothing here is read back out of the existing file.

```
/orchestrate {task_list} {flags}   # {description}
```

- `roadmap_notes.next_preamble` paragraphs render first (one entry per paragraph), then a fence
  containing one line per `roadmap_batches` entry **in array order**: `{task_list}` is that
  entry's `task_ids` joined by `, `, `{flags}` is its optional authored CLI flag segment (e.g.
  `--hard`, `--hard --lit`), and `{description}` is its bounded `description` field (see
  `context/formats/roadmap-entry-template.md` for the <= 100-character bound and the worked
  example pair). Line shape: `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$`.
- A batch all of whose `task_ids` members are now terminal renders with that line **omitted
  entirely** — the behaviour `--prune` used to provide, now a property of rendering from live
  state rather than a separate pass. A batch with a mix of terminal and non-terminal members
  renders its still-live members only.
- Below the fence: `Why this order:` followed by one bullet per `roadmap_batches` entry carrying
  a non-empty `rationale` (a multi-paragraph `rationale` renders as one bullet with two-space-
  indented continuation lines); an entry with no `rationale` emits no bullet. Then
  `roadmap_notes.next_postamble` paragraphs.
- A generated **coverage appendix** follows: any currently-dispatchable task (status not in the
  precedence table's rows 1-5, and `blocked:`/`ready` per row 6/7 evaluates `ready`) not named by
  any `roadmap_batches` entry, rendered as additional `/orchestrate` lines chunked at
  `--max-tasks` (default 8, matching `commands/orchestrate.md`'s `MAX_TASKS`) per wave. Header:
  `**Coverage appendix (uncovered tasks)**:`. Omitted entirely when empty. `covered_ids_json` is
  computed directly from `roadmap_batches[].task_ids`, not by re-parsing the rendered fence.
- A batch's `task_ids` MAY name tasks carrying `dependencies[]` edges among themselves:
  `/orchestrate` dispatches dependency-aware waves, so an intra-batch edge sequences the two
  tasks into successive waves rather than disqualifying either one. Whether a dependent joins
  its predecessor's batch is the author's (the `/roadmap` agent's) judgment; a dependency edge is
  never grounds for REMOVING a task from a batch. See
  `context/patterns/batch-orchestration-guardrails.md`'s Gate Catalogue, which already classifies
  an unmet predecessor as an ORDERING CONSTRAINT, cleared automatically once the predecessor
  reaches a terminal state.

## Generation

Generated by `scripts/roadmap-integration.sh`, three modes plus a composable flag:

- `--print` (default): emits the generated sections to stdout; mutates nothing. Structurally
  independent of the existing file's layout -- it never reads an existing `specs/ROADMAP.md`, so
  `detect_layout` and the refusal gate below do not apply to it.
- `--regenerate`: on a **classic** layout, rebuilds `## Open work` and `## Next` wholly from
  `state.json` (`render_open_work()` and `render_next()`); idempotent (a second consecutive run
  is byte-identical). On a **stage** layout, retains every section byte-for-byte except the
  run-order section's coverage appendix, which is stripped and freshly rebuilt; also idempotent.
- `--prune`: **deprecated alias** for `--regenerate`. A file rendered wholly from live state
  cannot accumulate terminal cruft — a batch or Open work line naming only terminal members is
  simply never rendered (see Next Grammar and Open work Grammar above) — so there is nothing left
  for a separate prune pass to remove. Prints one named stderr deprecation note, then dispatches
  to `--regenerate`. Still accepted, and the stderr marker's `pruned=` field is still present
  (always `0`), so every existing caller keeps working unchanged.
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

Now that `## Next` and `## Open work` are both wholly generated, this refusal is **more**
important than it was under the old retention-parser model, not less: with no authored content
left in the rendering path, a bad render's blast radius is the whole document rather than a
single mis-retained field, so refusing to guess at an unrecognised layout is the only thing
standing between a confident classification and overwriting a file this script cannot actually
round-trip.

**Settled layout ruling**: both recognised vocabularies are taught and round-tripped --
`classic` (the eight literal `CLASSIC_HEADERS`) and `stage` (a `## Stage N` header plus a fenced
`/orchestrate` block) -- and an unrecognised vocabulary is refused loudly rather than guessed at,
per the permanent property above. `specs/ROADMAP.md` in this repository presently classifies as
`classic`.

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

**`OUTCOME:` line (change-aware outcome reporting)**: the marker's six count fields are
byte-identical between a write that changed the file and a write that left it unchanged -- a
caller cannot tell them apart from the marker alone. Both write modes additionally emit one
named `OUTCOME:` line to stderr from `write_or_diff`, after the layout gate and immediately
before the marker, in one of four shapes:
```
OUTCOME: --regenerate rewrote {path} (layout=classic, content changed)
OUTCOME: --regenerate left {path} unchanged (layout=classic, no content change)
OUTCOME: --regenerate --dry-run diffed {path}; wrote nothing (layout=classic, content would change)
OUTCOME: --regenerate --dry-run diffed {path}; wrote nothing (layout=classic, no content change)
```
`--prune` emits the same four shapes with `--prune` substituted for `--regenerate`, and
`layout=stage` substituted when the file classifies as `stage`. This line never affects the exit
code. It is the answer to "what happened" that the marker's frozen count fields cannot give; the
marker still answers "how many" (tasks/topics/runs/pruned/retained). `--print` emits no
`OUTCOME:` line -- it never reads or writes an existing file, so it has no write outcome to
report. The absent-roadmap no-op (`NOTE: no roadmap tracked at ...`) and the `unknown`-layout
refusal (`ERROR: ... refuses to write ...`) both return before `write_or_diff` is reached, so
neither emits an `OUTCOME:` line either.

## Parsing Patterns Summary

| Element | Pattern |
|---------|---------|
| Section header | `^## (.+)$` |
| Open work block header | `^\*\*(.+) \((\d+)\)\*\*$` |
| Open work task line | `^(\d+) (\S+)\s{2,}(.+?)(\s{3}<- (.+))?$` |
| Status token | `HOLD\|IN FLIGHT\|BLOCKED\|PARTIAL\|EXT-BLOCKED\|blocked:[\d,]+\|ready` |
| Next Run line | `^/orchestrate ([\d, ]+)(\s+(-\S.*?))?(\s{3}# (.+))?$` |
| Coverage appendix header | `^\*\*Coverage appendix \(uncovered tasks\)\*\*:$` |
| Stderr marker | `^<!-- roadmap-generation mode=(\S+) tasks=(\d+) topics=(\d+) runs=(\d+) pruned=(\d+) retained=(\d+) -->$` |
| `OUTCOME:` line | `^OUTCOME: --(regenerate\|prune)( --dry-run diffed \| rewrote \| left )(.+?)(; wrote nothing\| unchanged)? \(layout=(classic\|stage), (content changed\|no content change\|content would change)\)$` |

## Related

- `.claude/context/patterns/roadmap-update.md` — the mode caller contract (who invokes which mode,
  when, and what each promises)
- `.claude/context/formats/task-order-format.md` — the structurally parallel sibling contract for
  TODO.md's generated `## Task Order` section; this file is modeled on its shape
- `.claude/scripts/roadmap-integration.sh` — the generator
