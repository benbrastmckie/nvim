# Research Report: Task #538

**Task**: 538 - Bounded in-file block edits: index and assert, never string-splice
**Started**: 2026-11-17T23:02:00Z
**Completed**: 2026-11-17T23:20:00Z
**Effort**: small (guidance-only, no helper script)
**Dependencies**: None (the declared predecessor record, a jq-reserialization record, has already
landed; its siting decision is readable directly from the live file and no dependency edge
remains in `specs/state.json`)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/context/architecture/context-layers.md`,
  `agent-system/extensions/core/context/contracts/pre-edit-gate.md`,
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`,
  `agent-system/extensions/core/.claude-extensions.json`
- `specs/state.json` (task 538 record: `file_scope`, `dependencies`, `migrated_from`)
**Artifacts**:
- This report: `specs/538_bounded_block_edit_index_and_assert/reports/01_bounded-block-edit-guidance.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task's own `file_scope` already names the four files this change touches:
  `agent-system/extensions/core/context/patterns/bounded-block-edit.md` (new),
  `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/core/merge-sources/claudemd.md`, and
  `agent-system/extensions/core/agents/general-implementation-agent.md`. All four are source-store
  paths under `agent-system/extensions/core`, confirmed as that extension's `source_dir` in
  `.claude-extensions.json`.
- Siting branch (i) resolves to "create the new file": the predecessor jq-reserialization record
  extended `jq-escaping-workarounds.md` in place (its `## jq Rewrites Reflow Unrelated JSON
  Formatting` section) rather than creating a sibling pattern file, so per the dispatch's own
  resolution order this record creates `bounded-block-edit.md` rather than reusing that file.
- Siting branch (ii) is already resolved by the dispatch's own evidence and independently
  confirmed here by reading the live file: the sibling anchor record's guidance landed only inside
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` (a
  `**Section-anchoring rule for any multi-line plan-file edit**` paragraph after the Stage 4A
  marker-edit code fence, cross-referenced once more from Stage 4D). No core-extension home exists
  for it. This record's new file is therefore confirmed as the shared home: it should carry both
  halves, with the lean file's paragraph reduced to a pointer.
- `agents/general-implementation-agent.md`'s `## Context References` section is the correct,
  already-established referrer mechanism (a bulleted `@.claude/context/patterns/...md` line, each
  with a short "when to load" annotation) — the file already points at several sibling core
  patterns this way (`context-discovery.md`, `pre-edit-gate.md`, `subagent-continuation-loop.md`,
  `checkpoint-before-overflow.md`, `external-process-wait.md`,
  `plan-revision-notification.md`), so adding one more bullet is a same-shape, low-risk change.
- `index-entries.json` entries for `context/patterns/*.md` files share one concrete schema
  (`path`, `domain`, `subdomain`, `summary`, `line_count`, `keywords`, `topics`, `load_when`); the
  `jq-escaping-workarounds.md` entry is a directly usable template.
- No existing file in the `core` extension already states the "`Edit` tool with a unique
  `old_string` is itself a bounded, assert-on-match edit" framing, nor any line-indexed-splice
  recipe — confirmed by a repo-wide grep for `unique old_string` and `old_string.*unique` and
  `bounded.*assert-on-match`, all empty. This is genuinely new guidance, not a restatement.

## Context & Scope

This is a `meta` task whose entire deliverable is prose guidance in the agent-system source
store, plus the wiring (an index entry and at least one referrer) that makes the guidance
reachable. The task explicitly scopes out a helper script. The research question was narrow and
entirely resolvable by reading: (1) what did the predecessor (jq-reserialization) record actually
do, to resolve siting branch (i); (2) what state is the sibling anchor record's guidance actually
in, to resolve siting branch (ii); (3) what are the exact mechanical shapes (file format,
referrer format, index-entry schema) the implementation must reuse rather than invent. No web
research was needed or attempted — this is a pure agent-system/source-store question with the
answer already present in the live repository.

## Findings

### Codebase Patterns

**Task record (`specs/state.json`, `project_number: 538`)**:
- `file_scope`: `agent-system/extensions/core/context/patterns/bounded-block-edit.md`,
  `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/agents/general-implementation-agent.md`.
- `dependencies: []` — the predecessor jq-reserialization record (BimodalLogic #772,
  `jq_rewrite_reserializes_json_record_files`) is not represented as a live dependency edge in
  this repository's numbering space; `migrated_from.dropped_dependencies: [772]` confirms the edge
  was dropped at migration time because that referent is "completed, archived, or stays behind."
  Its outcome must therefore be read directly from the landed file rather than inferred from an
  edge, which is exactly what this research did.
- `status: "researching"` (this dispatch); `topic: "agent-system"`.

**Siting branch (i) — did the predecessor create a sibling pattern file, or extend
`jq-escaping-workarounds.md`?**
`agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` (351 lines) carries a
`## jq Rewrites Reflow Unrelated JSON Formatting` section (lines 282-344) with: a conjunctive
trigger condition, a five-step copyable recipe (`git show HEAD:<path>` baseline -> text edit ->
independent jq computation -> `diff <(jq -S ...) <(jq -S ...)` assertion -> move into place), a
"Reopen condition" paragraph, and a "Not a general indictment of jq" scope-boundary paragraph.
`ls context/patterns/` confirms no sibling file (`jq-rewrite.md`, `json-reserialization.md`, or
similar) exists. This settles branch (i): the predecessor extended the existing file in place, so
per the dispatch's own resolution order this record must create the new file already declared in
its `file_scope` (`bounded-block-edit.md`) — a Markdown splice/assertion discipline does not
belong inside a file about jq pitfalls.

**Siting branch (ii) — has the sibling anchor record relocated into a core-extension home?**
`agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` lines
120-128 carry the paragraph verbatim:

> **Section-anchoring rule for any multi-line plan-file edit**: when an edit replaces or splices a
> whole section of a markdown plan file, anchor both ends on LINES that begin with heading markers
> (a line starting with two or three hash characters and a space), and search the end anchor
> FORWARD from the target section's own start line. Never anchor on a bare heading substring: the
> same text commonly recurs in prose earlier in the file (for example inside a Goals or Overview
> paragraph), and a whole-file match on it splices at the wrong place, duplicating the span between
> the two matches. The single-line phase-marker swap shown above is already safe by construction
> (the heading text plus its bracketed status marker is unique); this rule governs edits spanning
> from one heading to the next.

Line 177 cross-references the same rule once more from Stage 4D ("Plan-file marker edits here
follow the same forward-search anchoring rule stated after Stage 4A's marker code fence."). A
repository-wide grep for this paragraph's distinctive phrase ("Section-anchoring rule") returns
only this one file. No core-extension home exists. This confirms the dispatch's own stated
conclusion (branch (ii)) directly from the live file, independent of the dispatch's narrative: the
rule is real, correct, and currently reachable only from the lean implementation-flow file — which
a plan-authoring dispatch never reads, exactly the audience-reach gap the dispatch names.

**Referrer mechanism (`agents/general-implementation-agent.md`)**: the `## Context References`
section (lines 21-36) is a flat bullet list of `@.claude/context/....md` paths, each with a short
clause naming when to load it — some "(always load)", some "when X", some "Use with
agent=...,phase=...". Existing sibling-core-pattern bullets already present:
`context-discovery.md`, `pre-edit-gate.md` (a `context/contracts/` file, same bullet-list
mechanism per `context-layers.md`'s "Contracts directory" finding), `subagent-continuation-loop.md`,
`context-exhaustion-detection.md`, `checkpoint-before-overflow.md`, `external-process-wait.md`,
`plan-revision-notification.md`. This is the dispatch's "already points at sibling core patterns"
claim, confirmed directly. Adding one more bullet for `bounded-block-edit.md` is the same-shape
change the dispatch calls for; `agents/planner-agent.md` is confirmed excluded (not referenced
anywhere in this agent's file, and the dispatch names a prior exclusion precedent on the same
ground — the plan-format blocked-decision-gate record already claims that path).

**`index-entries.json` schema** (`agent-system/extensions/core/index-entries.json`, a single
top-level `entries` array): the `jq-escaping-workarounds.md` entry is a directly reusable
template:
```json
{
  "path": "patterns/jq-escaping-workarounds.md",
  "domain": "core",
  "subdomain": "patterns",
  "summary": "Workarounds for jq escaping issues and whole-file re-serialization of record formatting",
  "line_count": 351,
  "keywords": ["patterns", "jq", "escaping", "reserialization", "record-files", "formatting"],
  "topics": ["troubleshooting"],
  "load_when": {"agents": [], "task_types": [], "commands": ["/meta"]}
}
```
A second useful template, for the `load_when.agents` shape specifically, is
`patterns/checkpoint-before-overflow.md`'s entry: `"load_when": {"agents":
["general-implementation-agent"], "task_types": []}`. 175 total entries exist in the file today;
`line_count` on every `context/patterns/*.md` entry inspected matches the live file's line count
exactly (confirmed for `jq-escaping-workarounds.md`: entry says 351, `wc -l` says 351), so the
implementer must recompute `line_count` from the file as actually landed, not estimate it here.

**`merge-sources/claudemd.md`** (the root `CLAUDE.md` generator source): the existing `## jq
Command Safety` section (lines 250-268) is the closest precedent for a short, pointer-only section
that states the rule inline and defers full detail to the pattern file (`Full documentation:
.claude/context/patterns/jq-escaping-workarounds.md`). This record's `file_scope` includes this
file, consistent with reaching the plan-author/broad audience via a similarly short pointer rather
than restating the recipe.

**Siting layer** (`context/architecture/context-layers.md`'s decision tree, lines 38-55): "Agent
system pattern (orchestration, format, workflow)? -> `.claude/context/`" confirms
`context/patterns/` (not `context/contracts/` or `context/standards/`) is the correct directory
for this kind of guidance — consistent with both the predecessor's and the sibling's own choices.

**Novelty check**: a repo-wide grep for `unique old_string`, `old_string.*unique`, and
`bounded.*assert-on-match` across `context/` and `agents/` in the `core` extension returned no
matches. The "Edit tool with a unique `old_string` is itself a bounded, assert-on-match edit"
framing, and the three-part line-indexed-and-assert recipe, are not restatements of anything
already landed.

### External Resources

None consulted — this is a pure internal agent-system siting and content question with no
external-library or best-practices dimension; the dispatch itself supplies the complete technical
content (the three-part discipline, the trigger condition, the git-recovery nuance) as prose to be
transcribed into guidance form, not researched from outside sources.

## Decisions

- **New file, not an extension of `jq-escaping-workarounds.md`**: siting branch (i) resolves to
  creating `agent-system/extensions/core/context/patterns/bounded-block-edit.md`, per the
  dispatch's own resolution order and the confirmed fact that the predecessor extended the jq file
  in place rather than creating a sibling.
- **This record's file is the shared home for both halves**: siting branch (ii) is confirmed
  resolved (no core-extension home exists for the sibling anchor record's guidance). The new file
  should therefore carry the anchor rule (as a direct relocation/pointer of the lean paragraph
  quoted above, never a reword or re-derivation) alongside this record's own assertion-and-index
  discipline, and the lean implementation-flow paragraph should be reduced to a short pointer at
  its current location rather than left as the sole copy. This is guidance for the plan, not an
  edit performed during research — the lean file is outside this record's `file_scope` and
  touching it would require either widening `file_scope` or treating the existing paragraph as
  already-correct prose to point at without moving, per the dispatch's own "the SITING..." note
  only discusses files already in `file_scope`.
- **Referrer target confirmed as `agents/general-implementation-agent.md`'s `## Context
  References` bullet list** — the mechanism already in active use for sibling core patterns, no
  new mechanism needed.
- **`index-entries.json` entry follows the `jq-escaping-workarounds.md`/
  `checkpoint-before-overflow.md` template shape** — `domain: "core"`, `subdomain: "patterns"`,
  `load_when.agents: ["general-implementation-agent"]`, with `line_count` computed from the file
  as actually written (not before).

## Recommendations

1. **Create `agent-system/extensions/core/context/patterns/bounded-block-edit.md`** structured
   like `jq-escaping-workarounds.md` (trigger condition -> copyable recipe -> reopen condition ->
   scope boundary -> references), covering, per the dispatch's ACCEPTANCE criteria:
   - The conjunctive trigger condition (bounded block inside a line-structured file, AND a
     string-slice reconstruction mechanism), with at least one concrete file shape named (a phase
     inside a plan file).
   - The anchor rule, relocated from (not re-derived from) the lean implementation-flow
     paragraph quoted in Findings above, generalized to any line-structured text file rather than
     only Lean plan files, with the lean file's own copy reduced to a pointer at its existing
     location.
   - The three-part recipe: (1) index by line, not by character-offset slice; (2) bound the
     range by an explicit terminator and assert the pre-state before writing, aborting on
     mismatch; (3) assert a post-state structural invariant (e.g. a heading count) immediately
     after the write, in the same breath, not as optional later verification.
   - The `Edit`-tool-with-unique-`old_string` first-choice framing, stated before any scripted
     path, with the scripted/line-indexed path's earning condition (repetitive/mechanical edits
     impractical to enumerate as `Edit` calls) named explicitly.
   - The `git show HEAD:<path>` recovery nuance: a plain write, not a destructive git operation,
     no `guard-destructive-git.sh` interaction, available on a dirty tree — citing
     `.claude/rules/git-workflow.md` for the destructive-git rules themselves rather than
     restating them.
   - An explicit "what this guidance does not say" boundary paragraph (no blanket
     anti-script, no "always use Edit") mirroring `jq-escaping-workarounds.md`'s "Not a general
     indictment of jq" paragraph in shape.
   - A reopen condition for the "no helper script" scope decision, naming the retyped-recipe
     signal, mirroring the jq file's own reopen-condition paragraph.
   - No task-number or issue-entry-ID citations anywhere in the new file's prose (deliverable
     hygiene), and no record-versioning language narrating this record's own draft history.
2. **Add one `## Context References` bullet to `agents/general-implementation-agent.md`**,
   same-shape as the existing sibling-pattern bullets, naming when to load it (a bounded in-file
   block edit via string-slicing is in play) so a reader unfamiliar with the term "slice-and-splice"
   still reaches it from that file (dispatch ACCEPTANCE item 6).
3. **Add one `index-entries.json` entry** for `patterns/bounded-block-edit.md` using the
   `jq-escaping-workarounds.md`/`checkpoint-before-overflow.md` template shape, with `line_count`
   and `keywords` computed from the file exactly as landed (not estimated ahead of writing it).
4. **Add a short pointer section to `merge-sources/claudemd.md`**, same shape as the existing
   `## jq Command Safety` section's one-line `Full documentation:` pointer, so the broader
   CLAUDE.md-reading audience can find the new guidance without the full recipe duplicated there.
5. **Do not re-edit `agent-system/extensions/lean/...lean-implementation-flow.md` as part of this
   record's own `file_scope`-bound edits** unless `file_scope` is explicitly widened first via
   `update-task-status.sh` (per the dispatch's own instruction); the plan should state the
   relocation/pointer intent as a recommendation for whichever record or follow-up performs it, or
   widen `file_scope` and perform it here if the plan judges that the cheaper, single-record path.
6. **Redeploy and verify** via `bash .claude/scripts/deploy-headless.sh`, confirming
   `RESULT=landed_verify_clean`, as the final implementation step (dispatch ACCEPTANCE item 8).

## Risks & Mitigations

- **Risk**: widening scope to re-derive or reword the already-correct lean anchor rule instead of
  relocating/pointing at it verbatim. **Mitigation**: the exact paragraph text is quoted in full
  in Findings above; the implementer should copy it (or move it) rather than re-paraphrase it.
- **Risk**: `index-entries.json`'s `line_count`/`keywords` drifting from the file as landed if
  computed before the file is finalized. **Mitigation**: compute both only after the new pattern
  file's content is final, as a last implementation step before the index-entries edit, per
  dispatch ACCEPTANCE item 7.
- **Risk**: accidentally touching `agents/planner-agent.md`, which is deliberately excluded
  from this record's `file_scope` (claimed by the plan-format blocked-decision-gate record).
  **Mitigation**: the plan should state explicitly that the implementer-path referrer
  (`general-implementation-agent.md`) is the sole referrer added by this record, and that any
  future need for a `planner-agent.md` line requires a new serializing dependency edge, not an
  edit here.
- **Risk**: hand-editing the deployed `.claude/**` mirror instead of the source store (the
  deploy-freshness-context note flags the `core` extension's deployed tree as stale relative to
  this source store right now). **Mitigation**: every edit targets
  `agent-system/extensions/core/...` paths exclusively, per `.claude/rules/source-store-deploy-boundary.md`,
  followed by `bash .claude/scripts/deploy-headless.sh` to regenerate and verify the deployed tree.

## Context Extension Recommendations

None. This task's own deliverable is itself the context extension (`bounded-block-edit.md` plus
its wiring); no further undocumented topic was discovered during this research that falls outside
the task's own scope.

## Appendix

Search queries / commands used:
- `jq`/`python3 -c` queries against `specs/state.json` to recover task 538's `project_number`-keyed
  record (`active_projects` list, keyed by `project_number`, not `number`).
- `grep -n` across `specs/TODO.md` to cross-check the task-description text against the dispatch
  file's verbatim copy.
- `wc -l` and `grep -n` against
  `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` to resolve siting
  branch (i) and confirm its line count.
- `ls context/patterns/` to confirm no sibling jq/reserialization pattern file exists.
- `grep -n "Section-anchoring rule\|anchor"` and a full `Read` of lines 90-189 of
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` to
  resolve siting branch (ii) and transcribe the anchor-rule paragraph verbatim.
- `grep -n` against `agents/general-implementation-agent.md`'s `## Context References` section and
  a full `Read` of its header/Stage-0 region to confirm the referrer mechanism.
- `python3 -c` queries against `index-entries.json` to extract the `jq-escaping-workarounds.md`
  and `checkpoint-before-overflow.md` entries as schema templates, and to confirm `line_count`
  agreement with the live file.
- `grep -n` against `merge-sources/claudemd.md` for the `## jq Command Safety` section as a
  pointer-section precedent.
- `grep -n "patterns/\|contracts/\|standards/\|Where to store"` against
  `context/architecture/context-layers.md` to confirm `context/patterns/` as the correct directory
  per the five-layer storage decision tree.
- Repo-wide `grep -rln "unique old_string\|old_string.*unique\|bounded.*assert-on-match"` over
  `context/` and `agents/` in the `core` extension to confirm novelty (no existing matches).

References:
- `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/index-entries.json`
- `agent-system/extensions/core/merge-sources/claudemd.md`
- `agent-system/extensions/core/context/architecture/context-layers.md`
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
- `.claude/rules/git-workflow.md`
- `.claude/rules/source-store-deploy-boundary.md`
