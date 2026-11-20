# Roadmap Entry Template

**Purpose**: The concise templates for the roadmap entries in `specs/state.json` — a
`roadmap_milestones` entry and a batch nested under it — giving both the *entry shape* (the JSON
object stored) and the *rendered shape* (the `specs/ROADMAP.md` lines it produces). See
`context/formats/roadmap-format.md` for the full generation contract, and
`context/reference/state-management-schema.md`'s Top-Level Fields table for the schema-level
field reference. This file is the single source for the anti-fluff bound; nothing restates it
elsewhere.

---

## Milestone Entry Shape

A `roadmap_milestones` array entry:

```json
{
  "id": "M2",
  "title": "Generated roadmap",
  "aim": "Render the whole roadmap from state so a reviewer reads milestone status in one screen.",
  "gate": "A second regenerate is byte-identical and the roadmap suites pass from the deployed tree.",
  "progress": { "status": "active", "note": "Renderer landed; migration pending" },
  "review": { "state": "in_review", "ref": "roadmap-milestones", "request": "#12", "updated": "2026-01-15" },
  "batches": []
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | Yes | 1-16 characters, `^[A-Za-z0-9][A-Za-z0-9._-]{0,15}$`, unique. The rendered anchor derives from it; keep it stable across retitles. |
| `title` | string | Yes | <= 80 characters. |
| `aim` | string | Yes | <= 300 characters. What the milestone aims to achieve, in one statement. |
| `gate` | string | No | <= 400 characters. The criterion that closes the milestone — the criterion itself, never a dated measurement against it. |
| `progress.status` | enum | Yes | `planned`, `active` or `closed`. |
| `progress.closed` | string | Iff closed | The closure date, `YYYY-MM-DD`. |
| `progress.note` | string | No | <= 140 characters, one line. |
| `review.state` | enum | Yes when `review` is present | `none`, `prepared`, `in_review`, `changes_requested`, `approved`, `merged`. |
| `review.ref`, `review.request`, `review.updated` | string | No | The branch or ref, the pull/merge request identifier or URL, and the date the state was recorded. |
| `batches` | array | Yes (may be empty) | Batch entries, below. |

**Array position is the milestone's order.** Batch and task done-counts are derived at render
time and are never stored. `review` is a stored decision, recorded by whoever changes the review
state; it is not fetched at render time, which is why `updated` exists.

## Batch Entry Shape

A `roadmap_milestones[].batches` array entry:

```json
{
  "task_ids": [41, 40],
  "description": "Make the roadmap generated and close the two costs that measurement surfaced",
  "rationale": "The roadmap's judgment lives in prose a generator would overwrite...",
  "flags": "--hard"
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `task_ids` | array of integers | Yes, non-empty | Member tasks, in the order rendered on the batch's `/orchestrate` line. |
| `description` | string | Yes | **Hard bound: <= 100 characters.** The anti-fluff field — see below. |
| `rationale` | string | No | Unbounded. The batch's full ordering reasoning, kept in state for the next judgment pass. It is not rendered. |
| `flags` | string | No | An authored CLI flag segment (e.g. `--hard`, `--hard --lit`) appended to the rendered `/orchestrate` line. |

**Array position is the batch's priority** within its milestone. There is no separate priority
field on a batch entry, and the per-task `priority` enum (`state-management-schema.md`'s Project
Entry Fields table) is never read for batch ordering — see that file's field ruling.

A store that has not run `scripts/migrate-roadmap-to-milestones.sh` holds the same batch entry
shape in a flat top-level `roadmap_batches` array; see `roadmap-format.md`'s Migration section.

## Rendered Shape

An open milestone renders as a section; each batch with an open member renders as one line plus
a fenced block:

```
<a id="milestone-m2"></a>
## M2: Generated roadmap

Render the whole roadmap from state so a reviewer reads milestone status in one screen.

- **Progress**: active -- 0/1 batches, 0/2 tasks done -- Renderer landed; migration pending
- **Review**: in_review on `roadmap-milestones`, #12 (updated 2026-01-15)
- **Gate**: A second regenerate is byte-identical and the roadmap suites pass from the deployed tree.

**Batch 1** -- Make the roadmap generated and close the two costs that measurement surfaced
```

followed by a fenced block holding `/orchestrate 41, 40 --hard` and one status line per member.
A batch whose members are all done is the single line `**Batch N** (done) -- {description}`; a
closed milestone is its heading plus one `Closed {date} ...` line (see `roadmap-format.md`'s
Part 2).

## The Anti-Fluff Rule

A batch `description` is **one line stating what the batch accomplishes and why those members
belong together** — never a paragraph, never a restatement of each member's own title. It is the
only batch prose a reader sees, so it carries the summary judgment; the full reasoning belongs in
`rationale`, not in a longer `description`.

**The bound is on `description` alone, not on a whole rendered line.** A long `task_ids` list
consumes real width on the `/orchestrate` line (eight task ids plus separators run past 50
characters on their own), so a whole-line bound would be unsatisfiable the moment a batch has
more than a few members. Bounding `description` alone keeps the check meaningful regardless of
batch size.

The same discipline applies to every bounded field: `aim`, `gate`, `progress.note`, and each
`primary_goals` and `roadmap_context` item is one statement. An item that needs more than its
bound belongs in a decision record, with a one-line pointer in the field.

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

- `context/formats/roadmap-format.md` — the full generation contract (section order, field
  bounds, the pruning ledger, the migration).
- `context/patterns/roadmap-update.md` — the per-mode caller contract.
- `context/reference/state-management-schema.md` — the `roadmap_milestones` / `primary_goals` /
  `roadmap_context` schema field reference.
