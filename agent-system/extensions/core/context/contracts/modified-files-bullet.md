# Modified-Files Bullet (Canonical Fragment)

This file is the single authoritative source for the `modified_files` repo-relative-paths
constraint that in-scope implementation agents carry in their `## Critical Requirements` /
MUST-DO list, plus the matching track-on-write step in their development loop. It exists so the
wording has exactly one place to edit, instead of drifting independently across thirteen agent
files.

## Generated-Copy Source, Not an `@`-Import

**This fragment is a generated-copy source, read by a human or a lint script — it is NOT
`@`-imported into agent bodies at spawn time.** `@`-references inside an agent body do not
auto-resolve when Claude Code spawns a subagent — see
`context/contracts/no-task-references-bullet.md`'s "Generated-Copy Source, Not an `@`-Import"
section for the empirical finding this fragment reuses rather than re-proves. An agent body
carries a **literal copy** of both lines below; `lint-agent-contracts.sh` Check L keeps every
copy in sync by comparing it against this file at runtime, never against a hardcoded string
baked into the lint.

This is the same generated-copy-plus-lint shape `no-task-references-bullet.md` already
established (Checks C/G/H), applied here to a second constraint.

## The MUST-DO Bullet Text

Copy this exact text into the target agent's `**MUST DO**:` list, as the next sequential item:

```
Emit the top-level `modified_files` field in `.return-meta.json` on every dispatch: repo-relative paths only (never absolute), individual file paths only (never directory prefixes), paths inside this repository only, and `[]` when nothing was touched -- never omit the field -- per the "How Implementation Agents Populate modified_files" section of `.claude/context/formats/return-metadata-file.md`
```

## The Track-on-Write Line

Copy this exact text under the target agent's own apply-the-change step, inside its development
loop (or, for an agent without one, its code-change stage):

```
Track on write: at the moment of every `Write`/`Edit`, append that file's repo-relative path to this run's flat touched-paths list immediately -- never reconstruct the list from memory at the end of the run -- then emit the deduped list as `modified_files` at the metadata-writing stage
```

## Classification Rule: Which Agents Must Carry Both Lines

An agent MUST carry both lines **if and only if it is a dispatchable implementation agent that
writes `.return-meta.json` for an `implement` operation**. This is a decision, stated explicitly,
not an omission.

**In scope** (the thirteen agents this fragment is propagated into):
- `agent-system/extensions/books/agents/books-implementation-agent.md`
- `agent-system/extensions/books/agents/books-implementation-hard-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md`
- `agent-system/extensions/latex/agents/latex-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/python/agents/python-implementation-agent.md`
- `agent-system/extensions/rust/agents/rust-implementation-agent.md`
- `agent-system/extensions/typst/agents/typst-implementation-agent.md`
- `agent-system/extensions/web/agents/web-implementation-agent.md`
- `agent-system/extensions/z3/agents/z3-implementation-agent.md`

**Explicitly excluded** (already compliant, not edited, not in Check L's in-scope array):
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/email/agents/email-implementation-agent.md`
- `agent-system/extensions/nix/agents/nix-implementation-agent.md`
- `agent-system/extensions/neovim/agents/neovim-implementation-agent.md`

These four already document the constraint, in their own pointer-style or progress-file-sum
wording, authored before this fragment existed. Converting that established wording into this
fragment's literal bullet form is a uniformity decision with no defect behind it, so it is left
alone rather than edited to match.

None of the thirteen in-scope agents maintain a progress file or a `files_touched` accumulator,
so the track-on-write line above uses the flat run-list wording (track on write -> flat list ->
emit), not the progress-file-accumulation-plus-sum-step wording `general-implementation-agent`,
`nix`, and `neovim` use.

## Placement

- The **track-on-write line** goes under the agent's own apply-the-change step inside its
  development loop (or, for an agent without one, its code-change stage).
- The **MUST-DO bullet** goes as the next sequential item of the agent's existing
  `## Critical Requirements` `**MUST DO**:` list (or `**MUST DO** (base agent requirements,
  plus):` for a hard-mode agent phrased as a delta on its base agent).
- The `"modified_files"` key goes into the agent's own metadata JSON example, as a top-level
  sibling of `artifacts`, never nested inside `metadata` or `completion_data`.

Do not renumber or reword any surrounding bullet.

## Remit Boundary: Not an Artifact List

The `implement` commit scope stages the task directory (`specs/{NNN}_{SLUG}/`) unconditionally,
so `modified_files` exists for repo-tracked files touched **outside** the task directory. An
agent must not list its own summary or plan path to satisfy this field — paths under the task
directory are harmless if listed, but they are not the point of the field.

## What Check L Verifies Mechanically vs. Reads as Guidance

`lint-agent-contracts.sh` Check L mechanically verifies, per in-scope file:
- Both canonical lines above are present, verbatim (read from this fragment at runtime via
  `grep -F` on a distinctive anchor substring of each — never a hardcoded copy in the lint).
- A `"modified_files"` key is present somewhere in the file.

Everything else in this fragment — the classification rule, the placement rule, and the remit
boundary — is human-read guidance for the person or agent doing the propagation; the lint does
not and cannot verify correct placement or correct understanding of the remit boundary.
