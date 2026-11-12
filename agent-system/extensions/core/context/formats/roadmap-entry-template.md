# Roadmap Entry Template

**Purpose**: The concise template for a `roadmap_batches` entry in `specs/state.json` — both the
*entry shape* (the JSON object a batch is stored as) and the *rendered shape* (the
`specs/ROADMAP.md` lines that entry produces). See `context/formats/roadmap-format.md` for the
full generation contract this template's rendered shape slots into, and
`context/reference/state-management-schema.md`'s Top-Level Fields table for the schema-level
field reference. This file is the single source for the anti-fluff bound; nothing restates it
elsewhere.

---

## Entry Shape

A `roadmap_batches` array entry:

```json
{
  "task_ids": [603, 602],
  "description": "Make the roadmap generated and close the two costs that measurement surfaced",
  "rationale": "The roadmap's judgment today lives only in prose a generator overwrites...",
  "flags": "--hard"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `task_ids` | array of integers | Yes, non-empty | Member tasks, in the order rendered on the batch's `/orchestrate` line. |
| `description` | string | Yes | **Hard bound: <= 100 characters.** The anti-fluff field — see below. |
| `rationale` | string | No | Unbounded. The lossless home for the batch's full "Why this order:" prose. Absent means no rationale bullet is rendered for this batch. |
| `flags` | string | No | An authored CLI flag segment (e.g. `--hard`, `--hard --lit`) appended to the rendered `/orchestrate` line. |

**Array position is the batch's priority.** There is no separate priority field on a batch entry,
and the per-task `priority` enum (`state-management-schema.md`'s Project Entry Fields table) is
never read for batch ordering — see that file's field ruling.

## Rendered Shape

Each `roadmap_batches` entry renders as one `/orchestrate` line inside `## Next`'s fence, plus
(when `rationale` is non-empty) one bullet under `Why this order:`:

```
/orchestrate {task_ids joined by ", "} {flags}   # {description}
```

```
Why this order:
- {rationale, as one bullet; a multi-paragraph rationale continues with two-space-indented lines}
```

A batch naming only now-terminal members is rendered with that line omitted entirely (see
`roadmap-format.md`'s Next Grammar) — the property `--prune` used to provide, now a property of
rendering from live state.

## The Anti-Fluff Rule

`description` is **one line stating what the batch accomplishes and why those members belong
together** — never a paragraph, never a restatement of each member's own title. It is the only
field a reader sees inline on the Run line, so it carries the summary judgment; the full
reasoning belongs in `rationale`, not in a longer `description`.

**The bound is on `description` alone, not on the whole rendered line.** A long `task_ids` list
already consumes real width on the Run line (eight task ids plus separators runs past 50
characters on its own), so a whole-line bound would be unsatisfiable the moment a batch has more
than a few members. Bounding `description` alone keeps the check meaningful regardless of batch
size, while the full original reasoning is preserved verbatim in `rationale` — nothing is lost,
the anti-fluff rule just refuses to let it spill onto the Run line.

### Worked Examples

**Compliant** (76 characters):

> Make the roadmap generated and close the two costs that measurement surfaced

One line. States what the batch accomplishes (make the roadmap generated) and why its members
belong together (closing the costs measurement surfaced for this batch). Under the bound.

**Non-compliant** (112 characters):

> Fixes the roadmap generator, the next-batch suggester, the backgrounding ceiling, and the memory-retrieval retry

Fails on two independent counts: it is 112 characters, over the 100-character bound, **and** it
restates each member's own title (four member titles strung together) rather than stating the
batch's own unifying judgment — exactly the two failure modes this rule exists to catch.

---

## Related

- `context/formats/roadmap-format.md` — the full generation contract (section grammar, the
  authored-vs-generated split, the per-section ruling for every non-batch section).
- `context/patterns/roadmap-update.md` — the per-mode caller contract.
- `context/reference/state-management-schema.md` — the `roadmap_batches` / `roadmap_notes`
  schema field reference.
