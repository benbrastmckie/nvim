# Approval Artifact Convention

This file records the persisted-review path, the task-keyed and no-task-keyed naming forms, the
instance-number collision rule, and the deliberately-tracked status of `specs/certificates/`.
It is a decided ruling, not a proposal.

## The Review Is a Persisted Artifact

The review `approve.sh --review` generates is a research-report-grade artifact the owner may
reread, diff against a later cycle, or open while answering. It is persisted at a predictable,
tracked path under `specs/certificates/<component>/` **in the consumer repository** (the
repository being approved — e.g. `Logos/Verification`), never under `${TMPDIR}` or any other
throwaway location. `approve.sh`'s own `--out` argument is the mechanism; the path and naming
convention below are this command's business, decided on this side of the boundary and passed
to `approve.sh` as an argument, not a change to `approve.sh` itself.

## Naming: Two Keyed Forms

Every review is keyed by **both** a stem and a two-digit instance counter, because multiple
approval cycles per task (or per taskless adhoc run) are expected and a later cycle must never
overwrite the record of an earlier one.

### Task-keyed form

```
specs/certificates/<component>/task-{N}-{II}.md
```

- `{N}` — the task number, **unpadded**, per the placeholder table in `artifact-formats.md`.
- `{II}` — a 2-digit zero-padded instance counter (see "Instance Numbering" below).
- The task number is taken from an explicit `--task N` flag only. `/approve` never infers or
  guesses a task number from context.

### No-task key, stated explicitly

```
specs/certificates/<component>/adhoc-{DATE}-{II}.md
```

- `{DATE}` — `YYYYMMDD`, mirroring the no-task date-keyed review identity already in use in
  this repository (`specs/reviews/review-{DATE}.md`, `.claude/commands/review.md`).
- `{II}` — the same 2-digit zero-padded instance counter.

**This is its own named form, not a degenerate case of the task-keyed one.** A taskless
approval cycle — for example, re-approving a batch of stale specifications with no task number
in `state.json` at all — is never expressed by an empty segment, a literal `"000"`, or a
borrowed/guessed task number. Absent an explicit `--task N`, `/approve` always uses the
`adhoc-{DATE}-{II}` form. This is the live case this task was written to cover: re-approving the
stale `framed_channel` specifications has no task entry anywhere.

## Instance Numbering

`{II}` is one more than the count of existing files matching the same key **stem** (`task-{N}-`
or `adhoc-{DATE}-`) already present in that component's `specs/certificates/<component>/`
directory, zero-padded to two digits. Consequences:

- A second approval cycle for the same task gets `task-{N}-02`, `-03`, ... and never overwrites
  `task-{N}-01`.
- Two taskless cycles run on the same date get `adhoc-{DATE}-01` and `adhoc-{DATE}-02` and
  cannot collide.
- The counter refuses rather than silently wrapping past `99` instances for one stem.

## Sidecars

Two sidecar files share the review's own stem, both durable provenance in the same tracked
directory:

- `<stem>.classification.json` — the diff classifier's output (per-item evidence kind,
  declaration delta, class, recommendation, confidence).
- `<stem>.presented.json` — exactly what was shown to the owner (the Discrepancies block, the
  per-item summary, the question and answer), independent of the review file's own `## Notes`.

## Tracked-Directory Ruling

`specs/certificates/` is a durable, consumer-repo-owned, **always-tracked** directory. It is
deliberately **not** a member of the ephemeral orchestrator-runtime-file class that
`scripts/lib/runtime-file-patterns.sh` enumerates and that `runtime_specs_ignore_block()`
renders into every consumer's generated `specs/.gitignore` managed block.

No pattern in that generated block matches `specs/certificates/` today: the block holds only
`**/`-prefixed dotfile/dot-directory patterns plus a root-scoped `/tmp/`, re-derived directly
from the function's own source at plan-authoring time. The requirement recorded here is
therefore a **durable record against future drift**, not a functional fix for a bug that exists
today.

**The generated block's pattern list MUST NOT be edited to add a `specs/certificates/`
negation.** Its output is pinned byte-for-byte to a fenced block in
`context/standards/orchestrator-runtime-files.md` and rendered into every consumer's
`specs/.gitignore` — a cosmetic addition there cascades into a byte-identical pinning-assertion
failure against every already-synced consumer. The mechanical guard against drift is instead a
test case asserting no generated pattern matches a `specs/certificates/**` path (see
`scripts/tests/test-approve-paths.sh`'s tracked-directory assertion) plus the header-comment
cross-reference added to `runtime-file-patterns.sh` itself, alongside its existing
`.orchestrator-handoff.json`/bare `.return-meta.json` durable-provenance exclusions.

## Citation

- No-task date-keyed review identity precedent: `agent-system/extensions/core/commands/review.md`
  (`specs/reviews/review-{DATE}.md`).
- Zero-padded instance-sequence convention precedent: `artifact-formats.md`'s `MM` sequence
  numbering (this convention reuses the same zero-padding idea at the instance-number position,
  not the artifact-type position).
- `specs/.gitignore` managed-block source of truth:
  `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`'s
  `runtime_specs_ignore_block()`.
