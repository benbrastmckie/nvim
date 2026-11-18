# Implementation Summary: Task #644

- **Task**: 644 - Leave a spoken-word recap at the end of an orchestration and recommend /recap to hear it
- **Status**: [COMPLETED]
- **Started**: 2026-11-18T02:00:00Z
- **Completed**: 2026-11-18T04:10:00Z
- **Effort**: ~2 hours
- **Dependencies**: 503, 526, 538, 558, 643 (all territory edges, not subject edges; all completed)
- **Artifacts**: plans/01_orchestration-recap-spoken.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

An `/orchestrate` run's conclusion stage now composes a short, speech-shaped prose recap at its
emission step (Step 6) and persists it to a session-keyed file under `specs/.orchestration/`,
recommending a new `/recap` command by name in its written output. `/recap` — a user-only,
direct-execution command — reads the most recent recap, speaks it through piper, and prints it;
when no recap file exists it recomposes one mechanically from durable orchestration metadata
rather than failing. Nothing on the orchestration path ever invokes piper, paplay, or any other
audio sink; speaking is always the separate, explicitly user-invoked `/recap` step. All five
plan phases are complete, the source store is the only edit target, and the deployed tree
reports `RESULT=landed_verify_clean` (41/41 gates).

## What Changed

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — added a fourth
  per-session resolver, `runtime_recap_path()`, mirroring its three siblings.
- `agent-system/extensions/core/scripts/orchestrate-recap.sh` — new two-mode script: `--write`
  persists a recap read from stdin; the default speak mode resolves the latest recap (or
  recomposes one, or falls back to a generic sentence), prints it, and speaks it through a
  backgrounded, timeout-bounded `piper | paplay` pipeline unless `TTS_ENABLED=0` or piper/paplay/
  the voice model is unavailable. Text reaches piper only via file redirection, never
  shell-interpolated.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recap.sh` — new nine-case
  regression suite (write round-trip, speak-with-file, recompose, generic fallback, malformed
  metadata, `TTS_ENABLED=0`, piper-absent, apostrophe/quote round-trip, paplay-absent), using a
  fully self-contained isolated-PATH harness.
- `agent-system/extensions/core/scripts/tests/suite-classification.data`,
  `agent-system/extensions/core/manifest.json` — registered the new script, suite, command, and
  skill.
- `agent-system/extensions/core/commands/recap.md`,
  `agent-system/extensions/core/skills/skill-recap/SKILL.md` — new user-only `/recap` command and
  its backing direct-execution skill.
- `agent-system/extensions/core/merge-sources/claudemd.md`,
  `agent-system/extensions/core/README.md` — Command Reference rows documenting `/recap`.
- `agent-system/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` — additive
  subsection documenting the new arbitrary-text speaking path alongside the existing
  fixed-vocabulary notification hook.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 6 amendment:
  composes and persists the recap between report rendering and the (unchanged) final marker
  deletion.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — added
  `orchestrate-recap.sh` (`--write` form) to the Move 5 Bash allowlist.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — one
  `### Next Steps` line recommending `/recap` by name.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — reviewed,
  dated eager-load baseline move (70,400 B -> 70,500 B) to accommodate the new Command Reference
  row.
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/nvim/index-entries.json` — regenerated line counts (Phase 5 redeploy).

## Decisions

- `/recap` is user-only, enforced via all three layers (frontmatter `user-only: true`, explicit
  agent-restriction text, omission from the Skill-to-Agent Mapping table) — a structural
  guarantee against a future chained dispatch reaching for it, not merely "nothing calls it today."
- One script with two modes (`--write` / speak), not two scripts, mirroring
  `orchestrate-suggest-next-batch.sh`'s existing shape.
- The orchestrate lead composes the recap prose at Step 6, where the wins/channel/next-batch data
  is already in hand; the script only stores and plays. The on-demand recompose branch is
  deliberately mechanical and lower-fidelity — an accepted fallback, not a gap in the primary path.
- No new `runtime-file-pattern` class array member — only a resolver function, since
  `specs/.orchestration/` is already covered directory-class.
- The recap file is JSON (`session_id`, `created_ts`, `text`), not bare text, so the recompose
  branch and any future reader can distinguish a real recap from a stale/truncated one.

## Plan Deviations

- **Phase 2**: added a `/recap` row to `agent-system/extensions/core/README.md` (not in the
  plan's Files-to-modify list) — required by `check-extension-docs.sh`'s rule that every
  manifest-declared command be mentioned in the extension README.
- **Phase 3**: added a ninth test case (paplay absent) beyond the plan's eight enumerated `Case:`
  bullets, to match the phase's own stated "nine-case" framing.
- **Phase 5**: moved `orchestrator-context-budget.json`'s `eager_load.baseline_bytes` (70,400 B
  -> 70,500 B) via a reviewed, dated entry, following that file's own established convention, to
  accommodate the new eager-loaded Command Reference row. Also discharged Phase 5's "run the
  complete gate set" task via the dispatch's Batch Gate Deferral scoped-narrowing directive
  rather than an independent unscoped `verify-deploy.sh` call (the full 41-gate-clean result came
  from `deploy-headless.sh`'s own pre-existing inline pass).

## Verification

- Build: N/A (shell/markdown/JSON, no build step)
- Tests: Passed — `test-orchestrate-recap.sh`, all 9 cases, both in source-store mode and against
  the deployed tree
- Files verified: Yes — `bash .claude/scripts/deploy-headless.sh` reports
  `RESULT=landed_verify_clean` (41/41 gates)
- All seven acceptance criteria demonstrated against the deployed tree (write/recap-file lands
  and is named in the results template; the recap is genuinely spoken through piper; recompose
  works when no recap file exists; piper-absent and `TTS_ENABLED=0` both print-and-exit-0 with no
  second engine; the Move 5 allowlist names the script; zero task-number references or
  record-versioning language introduced)

## Impacts

- An `/orchestrate` run now leaves a durable, session-keyed prose recap behind and points the
  user at `/recap` to hear it, with no change to the orchestration's own audio behavior (still
  silent, as before).
- A second, arbitrary-text TTS path now exists alongside the pre-existing fixed-vocabulary
  notification hook, sharing its `TTS_ENABLED`/`PIPER_VOICE` conventions and piper/paplay
  dependency, but with its own script and no shared code path.

## Follow-ups

- None required by this task's own acceptance bar. A future task could consider extending
  `/recap` with history browsing or a session-id argument, but both were explicitly ruled
  out-of-scope by this task's settled design decisions.

## References

- Plan: `specs/644_orchestration_recap_spoken_on_demand/plans/01_orchestration-recap-spoken.md`
- Research report: `specs/644_orchestration_recap_spoken_on_demand/reports/01_orchestration-recap-design.md`
- Progress files: `specs/644_orchestration_recap_spoken_on_demand/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/644_orchestration_recap_spoken_on_demand/handoffs/phase-{1..5}-handoff-*.md`
