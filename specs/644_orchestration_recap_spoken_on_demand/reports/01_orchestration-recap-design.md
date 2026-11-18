# Research Report: Task #644

**Task**: 644 - Orchestration recap spoken on demand
**Started**: 2026-11-18T06:47:00Z
**Completed**: 2026-11-18T07:20:00Z
**Effort**: medium
**Dependencies**: #503, #526, #538, #558, #643 (all territory edges, not subject edges — see dispatch)
**Sources/Inputs**: Codebase (core and nvim source stores), dispatch grounding, live file reads
**Artifacts**: - specs/644_orchestration_recap_spoken_on_demand/reports/01_orchestration-recap-design.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Every grounding claim in the dispatch was re-confirmed live and holds exactly as stated: Move
  5 Step 6 of `conclusion-stage.md` is the sole emission site and also deletes the conclusion
  pending marker as its own final action; `postflight-tool-restrictions.md`'s Move 5 Bash
  allowlist is a single named-script enumeration that needs `orchestrate-recap.sh` added
  verbatim; `runtime-file-patterns.sh` already exposes three sibling path resolvers
  (`runtime_mt_state_path`, `runtime_return_meta_multi_path`,
  `runtime_conclusion_pending_marker_path`) whose pattern a fourth, `runtime_recap_path`, should
  follow exactly; `/recap` is free of collision in both `core/commands/` and `core/scripts/`.
- One refinement beyond the dispatch's framing: the recap file needs **no new
  `RUNTIME_FILE_PATTERNS` array member**. It lives under `specs/.orchestration/`, which the
  existing `orchestration` (19th) member's `**/.orchestration/` directory-class pattern already
  gitignores — the same reasoning that lib's own header comment already applies to
  `orchestrator-multi-state`/`return-meta-suffixed` and to the conclusion-approval ledger file
  (`.conclusion-approval-{session_id}.json`, confirmed to rely on the same directory coverage).
  Only a new resolver *function* is needed, not a new array entry.
- `tts-notify.sh`'s `speak()` helper interpolates its message into a single-quoted shell string
  (`printf '%s' '${message}' | piper ...`), which is safe only because every existing caller
  passes a closed, punctuation-free vocabulary ("Tab N", "Tab N done", lifecycle status words).
  A recap is free-form prose that will contain apostrophes and other shell metacharacters; the
  new speaking path must not reuse that exact interpolation shape — it needs an injection-safe
  invocation (stdin/arg-array, never string-interpolated single-quoting).
- Recommended architecture: one new script, `orchestrate-recap.sh`, with two modes — `--write`
  (called from Move 5 Step 6, persists a pre-composed recap text to
  `specs/.orchestration/.recap-{session_id}.json`) and the default/`--speak` mode (called by
  `/recap`, which locates the latest recap file by mtime, falls back to a mechanical recompose
  from the latest `.return-meta-multi-{session_id}.json` when none exists, and either pipes to
  `piper | paplay` or prints the text, per `TTS_ENABLED`/binary/model availability). `/recap`
  should be marked `user-only: true`, mirroring `skill-tag`'s three-layer enforcement, precisely
  *because* it is the structural guarantee that backs the dispatch's BINDING "orchestration
  never plays audio by itself" constraint — not because of any business-timing rationale.

## Context & Scope

Task 644 adds a short, speech-shaped spoken recap to the end of an `/orchestrate` run: the
conclusion stage (Move 5) writes a recap file and recommends a new `/recap` command by name in
its final written output; `/recap`, run later and only on explicit user request, speaks that
recap through piper, or recomposes one mechanically when no file exists (an older run, or one
that died before Move 5 Step 6 ran), or prints the text when no TTS engine is available. Four
design decisions were already settled by the user before this dispatch (command name `/recap`;
both write-at-end and recompose-on-demand; latest-run-only, no session argument, no `--list`;
print-as-text fallback, no espeak-ng) and are binding, not reopened here. This research's job,
per the dispatch, was to confirm current file state against the dispatch's grounding and design
the concrete fix — not to re-derive facts the dispatch already supplied.

Five dependencies (#503, #526, #558, #538, #643) are declared solely as territory edges (shared
edit paths), not subject edges; #526 in particular must not be touched beyond the one shared
guide file it overlaps with — this task does not absorb #526's event-announcement work.

## Findings

### Codebase Patterns

**Move 5 / conclusion-stage.md — confirmed structure.** `agent-system/extensions/core/context/contracts/conclusion-stage.md`'s "## The Executable Stage Body" has exactly Steps 1-7 (numbered
non-linearly: Step 7 is positioned in the text between Steps 5 and 6 because its output must
exist before Step 6 renders it, but it executes before Step 6). Step 6 ("Report") is confirmed
as the **sole emission site** for the combined report, rendered per
`context/patterns/orchestrate-batch-results-template.md`'s `### Conclusion` / `### Next Steps`
blocks, and its own final action deletes the conclusion-stage pending marker:

```bash
source .claude/scripts/lib/runtime-file-patterns.sh
rm -f "$(runtime_conclusion_pending_marker_path specs "$session_id")"
```

This is exactly where a new "compose and persist the recap" sub-action belongs: after the
report text is composed (so the recap can draw on the same wins/channel-outcome/suggested-next-
batch data) and before the marker deletion (which remains the step's last action).

**Move 5's allowed Bash surface — confirmed closed list.**
`context/standards/postflight-tool-restrictions.md`'s "Conclusion Stage (Move 5) Tool
Restrictions" section names a single `Bash` row enumerating every script this stage may invoke:
`orchestrate-conclusion-aggregate.sh`, `events-append.sh`, `generate-todo.sh`,
`orchestrate-conclusion-roadmap.sh`, `orchestrate-suggest-next-batch.sh`, `git-commit-scoped.sh`,
and the `lib/runtime-file-patterns.sh` path-resolver call for marker deletion. `orchestrate-
recap.sh` is confirmed absent from this row; the dispatch's claim that adding it is required for
the conclusion stage's call to be in-contract is verified correct, and is a direct, mechanical
one-line addition to that row.

**`runtime-file-patterns.sh` — confirmed resolver family, and the no-new-array-member
refinement.** The lib currently exports three per-session path resolvers, all taking
`(specs_dir, session_id)`:

- `runtime_mt_state_path` → `.orchestrator-multi-state-{session_id}.json`
- `runtime_return_meta_multi_path` → `.return-meta-multi-{session_id}.json`
- `runtime_conclusion_pending_marker_path` → `.conclusion-pending-{session_id}.json`

Each resolver's own comment states it needs "no new runtime-file-pattern class member" because
`specs/.orchestration/` is already covered, directory-class, by the `orchestration` (19th)
array member's `**/.orchestration/` pattern. `orchestrate-conclusion-aggregate.sh`'s header
independently confirms the same reasoning for its own ledger file,
`.conclusion-approval-{session_id}.json`, describing it as relying on "the existing
`**/.orchestration/` ephemeral, gitignored runtime-file class" rather than carrying its own
array entry. A fourth resolver, `runtime_recap_path(specs_dir, session_id)` →
`.recap-{session_id}.json`, should be added following this exact precedent: no new
`RUNTIME_FILE_IDS`/`RUNTIME_FILE_PATTERNS`/probe/regex entries, just the new function appended
after `runtime_conclusion_pending_marker_path`.

Live confirmation that these files persist and are mtime-sortable: `specs/.orchestration/`
currently holds 11 `.return-meta-multi-{session_id}.json` files spanning Nov 13-17, the most
recent being `.return-meta-multi-sess_1794980176_60fcdb.json` (Nov 17 22:49) — this is the exact
mechanism `/recap`'s "latest run" resolution and its mechanical-recompose fallback should use:
find the newest `.recap-*.json` (or, absent one, the newest `.return-meta-multi-*.json`) by
mtime under `specs/.orchestration/`.

**`tts-notify.sh` — confirmed closed vocabulary and confirmed quoting hazard.**
`agent-system/extensions/core/hooks/tts-notify.sh` only ever speaks "Tab N" / "Tab N STATUS" /
"Tab N done" from a fixed lifecycle vocabulary; it takes no arbitrary text argument, confirming
the dispatch's claim that it cannot serve this task. Its `speak()` helper:

```bash
(timeout 10s bash -c "printf '%s' '${message}' | piper --model '${PIPER_VOICE}' --output_file - --quiet 2>/dev/null | paplay 2>/dev/null" &) || true
```

interpolates `$message` inside single quotes inside a *second* `bash -c` string. This is safe
only because every caller passes punctuation-free, apostrophe-free text ("Tab N", a lifecycle
status word). A recap is free-form prose ("the run's conclusion", "didn't fail", etc.) and
**must not** reuse this exact shape — an apostrophe or embedded single quote would break the
quoting and could, in the worst case, allow unintended shell interpretation of recap content
sourced from task artifacts. The new recap-speaking path should pass the message via a file or
heredoc/stdin to `piper` without re-interpolating it into a quoted shell string (e.g. write the
recap text to a temp file and `piper ... < "$tmpfile"`, or use an array-form `bash -c` with the
message passed as `"$1"` rather than string-substituted into the script text). The
`TTS_ENABLED=0` disable convention and the non-blocking backgrounded `piper | paplay` shape
(`( ... &) || true`) should otherwise be reused as-is, per the dispatch's own instruction.

**Piper invocation and voice model — confirmed.**
`agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` confirms the
documented invocation (`echo TEXT | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx
--output_file - | paplay`), `PIPER_VOICE` as the override variable, and
`~/.local/share/piper/en_US-lessac-medium.onnx` as the default — identical to `tts-notify.sh`'s
own `PIPER_VOICE` default. `packages/piper-voices.nix` (confirmed present at
`~/.dotfiles/packages/piper-voices.nix`, the NixOS configuration repository, not this one) is the
provisioning source cited by the guide; this repository does not itself provision the voice
model, it only documents and consumes it.

**`/recap` name — confirmed free.** `ls agent-system/extensions/core/commands/` and `ls
agent-system/extensions/core/scripts/` both confirm no existing `recap` file in either
directory as of this research pass.

**Command Reference table and skills — confirmed format and precedent.** `CLAUDE.md`'s Command
Reference table (sourced from `agent-system/extensions/core/merge-sources/claudemd.md`) lists
`/tag` and `/please` as user-only entries; both have a companion skill with `user-only: true` in
YAML frontmatter (`skill-tag`), or no skill at all and a hook-based mint mechanism (`/please`).
`skill-tag/SKILL.md`'s own "Agent Restrictions" section states the three-layer enforcement this
task should mirror for `/recap`:

1. **Frontmatter flag**: `user-only: true` in the skill's YAML.
2. **Documentation**: an explicit "Agents MUST NOT invoke" statement in the skill and command
   files.
3. **No agent mapping**: absent from CLAUDE.md's Skill-to-Agent Mapping table.

`skill-refresh/SKILL.md` and `commands/refresh.md` confirm the non-user-only direct-execution
pattern (`allowed-tools: Bash, Read, Glob, AskUserQuestion` in frontmatter, no agent dispatch,
runs inline) that a `/recap`-as-not-user-only alternative would otherwise follow — relevant to
weigh against the ruling below.

**Permission surface — advisory finding, not a blocker.** `root-files/settings.json`'s
`permissions.allow` list does not carry explicit `Bash(piper:*)`/`Bash(paplay:*)` entries, nor a
blanket `.claude/scripts/*` entry; existing direct-execution skills (`skill-refresh`,
`skill-tag`) already invoke arbitrary scripts without a matching explicit allow entry, so this
is consistent with existing practice and not a new gap this task introduces. Not pursued further
since it does not block the design and matches the existing precedent exactly.

### External Resources

No external web research was needed; piper/paplay CLI behavior is already fully documented in
this repository's own TTS guide and confirmed against the live `tts-notify.sh` implementation.

## Decisions

- **The recap file needs a new resolver function, not a new `RUNTIME_FILE_PATTERNS` array
  member.** `specs/.orchestration/`'s existing directory-class gitignore pattern already covers
  any file placed under it, confirmed by the precedent the lib's own comments and
  `orchestrate-conclusion-aggregate.sh`'s approval-ledger file already establish. Add
  `runtime_recap_path(specs_dir, session_id)` → `${specs_dir}/.orchestration/.recap-${session_id}.json`
  to `runtime-file-patterns.sh`, mirroring `runtime_conclusion_pending_marker_path` exactly.
- **`orchestrate-recap.sh` needs two modes, not one script per direction.** A `--write` mode
  (Move 5 Step 6's call, persisting a pre-composed recap string) and a default/`--speak` mode
  (the `/recap` command's call, which locates-or-recomposes-and-speaks-or-prints). This mirrors
  the existing pattern of `orchestrate-suggest-next-batch.sh` carrying both a propose-only and a
  `--write-edges` mode in one script, rather than splitting into two files.
- **The recap's prose must be composed by the orchestrator (the lead itself), not synthesized by
  a bash script.** Step 6 already has the wins/channel-outcome/suggested-next-batch data in
  hand when it renders the markdown report; the orchestrator should compose the parallel
  speech-shaped prose (what landed, what failed, the single most useful next action) itself and
  pass it to `orchestrate-recap.sh --write` for persistence — the script's job is storage and
  playback mechanics, never natural-language synthesis. The `--speak` mode's **recompose**
  branch (used only when no recap file exists) is necessarily mechanical/templated instead,
  since no LLM is in the loop when `/recap` runs standalone — lower quality than an
  orchestrator-composed recap is an accepted trade-off for that fallback path specifically, not
  a gap in the primary path.
- **`/recap` should be `user-only: true`, mirroring `skill-tag`'s three-layer enforcement.** The
  rationale is distinct from `skill-tag`'s business-timing reasoning: the dispatch's BINDING
  constraint is that the orchestration must never play audio by itself. Marking `/recap`
  user-only is the structural guarantee for that constraint — it ensures no present or future
  agent code path (a chained dispatch, a conclusion-stage follow-up, a future skill) can invoke
  `/recap` and cause autonomous audio playback, rather than relying solely on "nothing currently
  calls it." Apply all three enforcement layers: `user-only: true` frontmatter on the new skill,
  an explicit "Agents MUST NOT invoke" statement in both the skill and command files, and
  omission from CLAUDE.md's Skill-to-Agent Mapping table.
- **The quoting shape in `tts-notify.sh`'s `speak()` must not be reused verbatim** for the new
  recap-speaking path, because recap text is free-form prose rather than a closed,
  punctuation-free vocabulary. Use a file/stdin-based piper invocation instead of re-
  interpolating the message into a single-quoted inner shell string.

## Recommendations

1. **`runtime-file-patterns.sh`**: add `runtime_recap_path(specs_dir, session_id)`, no new array
   member, following the three existing per-session resolvers' exact shape and placement
   (appended after `runtime_conclusion_pending_marker_path`).
2. **New script `scripts/orchestrate-recap.sh`**:
   - `--write --session SID --text "..."` (or stdin): writes
     `{session_id, created_ts, text}` JSON to `runtime_recap_path`'s resolved path. Called only
     from Move 5 Step 6.
   - Default / `--speak`: resolve the latest recap by mtime under `specs/.orchestration/`
     (`.recap-*.json`); if absent, mechanically recompose a short prose string from the latest
     `.return-meta-multi-*.json` (tasks succeeded/failed, roadmap/suggested-next-batch line) via
     the same mtime-latest resolution logic already proven live in this research pass. Then: if
     `TTS_ENABLED=0`, print text and exit 0; if `piper` absent or `$PIPER_VOICE` file absent,
     print text and exit 0 (no espeak-ng fallback, per settled decision 4); otherwise pipe to
     `piper | paplay`, backgrounded non-blocking, using a file/stdin-based invocation (not
     `tts-notify.sh`'s single-quote interpolation shape) so prose punctuation is handled safely.
   - `--help`.
3. **`postflight-tool-restrictions.md`**: add `orchestrate-recap.sh` (its `--write` form only) to
   the Move 5 Bash allowlist row, verbatim alongside the existing named scripts.
4. **`conclusion-stage.md`**: amend Step 6's prose to instruct the orchestrator to compose the
   speech-shaped recap text alongside the markdown report and call
   `orchestrate-recap.sh --write` before the step's existing final action (marker deletion).
5. **`orchestrate-batch-results-template.md`**: add a line to `### Next Steps` (unconditional,
   since the recap is written every invocation) recommending `/recap` by name, e.g. "Hear a
   spoken recap of this run: `/recap`" — analogous in placement to the existing "Re-run failed
   tasks" line.
6. **New command `commands/recap.md` + new skill `skills/skill-recap/SKILL.md`**: `user-only:
   true` frontmatter, `allowed-tools: Bash` (no agent dispatch — direct execution, mirroring
   `skill-refresh`/`skill-tag`'s inline-execution shape), explicit "Agents MUST NOT invoke"
   documentation, and a call into `orchestrate-recap.sh`'s speak mode. Omit from CLAUDE.md's
   Skill-to-Agent Mapping table; add a `/recap` row to the Command Reference table marked
   `(user-only)`, matching `/tag`/`/please`'s existing row shape.
7. **Source-store boundary**: every file above lives under `agent-system/extensions/core/**`
   (and the one guide-citation touch stays read-only against `agent-system/extensions/nvim/**`).
   Edit at the source paths, never under `.claude/**`, then redeploy via
   `bash .claude/scripts/deploy-headless.sh` and confirm `RESULT=landed_verify_clean` before
   closing the implementation phase.
8. **No file under `agent-system/**` should carry a task-number reference or record-versioning
   language** (acceptance criterion 7) — straightforward given none of the new/edited content
   needs either; the plan should include this as an explicit per-file check item rather than an
   assumption.

## Risks & Mitigations

- **Risk**: reusing `tts-notify.sh`'s exact quoting shape for free-form prose could break on an
  apostrophe or quote character in a recap sentence, or (in the worst case) let recap content
  influence shell parsing. **Mitigation**: use a file/stdin-based piper invocation in the new
  script, never a re-interpolated single-quoted inner-shell string (see Decisions above).
- **Risk**: the mechanical recompose-on-demand fallback (no recap file found) could read stale
  or malformed `.return-meta-multi-*.json` content if the latest one belongs to a run that
  crashed mid-write. **Mitigation**: the script should validate the JSON parses and contains the
  expected `metadata` keys before using it, falling back to a minimal generic sentence ("no
  recent orchestration summary is available") rather than failing non-zero — acceptance
  criterion 3 requires recompose to succeed, not merely attempt.
- **Risk**: marking `/recap` user-only without also auditing whether any *existing* mechanism
  (e.g. a hook, a future `--hard` contract, or a chained command) could invoke a user-only
  command indirectly. **Mitigation**: the three-layer enforcement already defends against the
  documented attack surface (agent dispatch, skill-to-agent mapping); no additional surface was
  found live in this research pass, but the plan should restate the BINDING "orchestration
  never plays audio by itself" constraint explicitly in the new skill/command files themselves,
  not only in the task description, so a future reader of those files alone sees the constraint.

## Context Extension Recommendations

- **Topic**: per-session ephemeral runtime files that intentionally need *no* freshness gate on
  read (the `.orchestration/`-directory-covered class).
- **Gap**: `context/standards/orchestrator-runtime-files.md` documents the two-class
  (ephemeral/durable) policy and `runtime-file-patterns.sh`'s role as its single source of
  truth, but does not currently call out, as a standalone callable pattern, "a new per-session
  resolver needs no new array member when it lives under an already-directory-covered path" —
  this fact currently lives only in scattered header comments (the `orchestration` member's own
  comment, and `orchestrate-conclusion-aggregate.sh`'s header). A short cross-reference note in
  `orchestrator-runtime-files.md` pointing future authors at this precedent (rather than each
  discovering it independently, as this research pass had to) would save a repeat of this exact
  confirmation step.
- **Recommendation**: add one short paragraph to `orchestrator-runtime-files.md`'s "Consumer
  Repo Setup" or class-table section naming this precedent and its two known instances
  (`.conclusion-approval-{session_id}.json`, and now `.recap-{session_id}.json`), so a future
  fourth file in this family is added the same way without re-deriving the reasoning.

## Appendix

### Search queries / commands used

- `ls`/`cat` on `specs/644_.../`, `.return-meta.json`, `.dispatch/13.md`
- `jq -r '.extensions.core.source_dir, .extensions.nvim.source_dir' .claude-extensions.json`
- Full read of `conclusion-stage.md`'s "## The Executable Stage Body" (Steps 1-7)
- Full read of `postflight-tool-restrictions.md`'s "Conclusion Stage (Move 5)" section
- Full read of `orchestrate-batch-results-template.md`'s `### Conclusion`/`### Next Steps` blocks
- Full read of `runtime-file-patterns.sh` (array membership, header comments, all four
  resolver functions)
- `cat agent-system/extensions/core/hooks/tts-notify.sh`
- `cat agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` (head)
- `find` for `piper-voices.nix` (confirmed present only in the dotfiles repo, not this one)
- `ls specs/.orchestration/` (confirmed persisted, mtime-sortable `.return-meta-multi-*.json`
  files spanning Nov 13-17)
- `grep` for `recap` across `commands/` and `scripts/` (confirmed free)
- Headers of `commands/tag.md`, `skills/skill-tag/SKILL.md`, `commands/please.md`,
  `commands/refresh.md`, `skills/skill-refresh/SKILL.md`
- `python3 -c "..."` to enumerate `root-files/settings.json`'s `permissions.allow`/`deny` lists
- Full read of `report-format.md`'s "Required Section Headings (verbatim)" section

### References

- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh`
- `agent-system/extensions/core/hooks/tts-notify.sh`
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh`
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh`
- `agent-system/extensions/core/skills/skill-tag/SKILL.md`
- `agent-system/extensions/core/skills/skill-refresh/SKILL.md`
- `agent-system/extensions/core/commands/tag.md`, `please.md`, `refresh.md`
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
- `.claude/rules/source-store-deploy-boundary.md`
