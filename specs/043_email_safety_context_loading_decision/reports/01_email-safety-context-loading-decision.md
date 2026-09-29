# Research Report: Email Safety Context-Loading Decision

**Task**: 43 - Decide and implement how email safety context actually reaches agents (live defect: five inert safety pointers)
**Started**: 2026-09-29T00:16:27Z
**Completed**: 2026-09-29T00:45:00Z
**Effort**: 1-3 hours
**Dependencies**: 194 (archived/completed), 257 (archived/completed) — no blocking concerns
**Sources/Inputs**: Codebase exploration (`agent-system/extensions/email/**`, `.claude/CLAUDE.md`,
`.claude/settings.local.json`), prior audit report
(`specs/archive/036_audit_context_loading_efficiency/reports/01_team-research.md`)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Empirically verified**: none of the five domain files (`safety-invariants.md`,
  `wrapper-contracts.md`, `index-architecture.md`, `staleness-detection.md`,
  `archive-mode-risk.md`) are loaded automatically today, at any tier. The merged
  `EXTENSION.md` section in `.claude/CLAUDE.md` lists them as plain backticked paths (confirmed
  non-loading), consistent with the project-wide "lazy context loading" convention.
- **The critical finding**: this is not actually a live safety gap. The operationally
  load-bearing subset of `safety-invariants.md`'s content — the wrapper-only allowlist, the
  `$PATH` precondition, the propose→review→confirm→execute lifecycle, the mandatory human
  review gate, and the "MUST NOT" list — is independently **duplicated inline**, near-verbatim,
  in the bodies of all three consumers that actually need it at runtime:
  `skills/skill-email-cleanup/SKILL.md`, `skills/skill-email-sync/SKILL.md`, and
  `agents/email-implementation-agent.md`. Those bodies ARE genuinely eager at the point that
  matters — a skill/agent's own body is read in full when Claude Code invokes it (Skill tool /
  Agent tool), which is a materially different, and more relevant, eagerness tier than
  session-start `CLAUDE.md` `@`-import expansion. This is the tier that actually gates a
  mutation, since no mutation happens except via a dispatched `skill-email-cleanup`,
  `skill-email-sync`, or `email-implementation-agent` invocation.
- **Two further, fully mechanical, markdown-independent enforcement layers exist** and do not
  depend on any file being loaded at all: (1) `hooks/mail-guard.sh`, a PreToolUse hook
  (registered via `settings-fragment.json` → deployed into `.claude/settings.local.json`) that
  allowlists the five wrapper binaries and denies raw mutation patterns on every Bash call,
  regardless of what markdown context is present; (2) the nix-built wrapper binaries themselves,
  which bake in hash verification, the staleness gate, the `MAX_BATCH_SIZE` cap, and the
  confirm-manifest state machine — safety holds even if an agent (or a human) invokes a wrapper
  directly with no markdown context loaded at all.
- **Recommended decision: option (b)**, formalized and recorded, not merely asserted. The
  wrapper contracts (mechanical, two-layer enforcement) plus each consumer's own inlined,
  eagerly-loaded safety content already carry the enforcement. The five domain files —
  including `safety-invariants.md` itself — serve as deeper single-source-of-truth reference
  material (full derivation, edge cases, per-account detail) that an agent consults on demand via
  an explicit `Read` when it needs more than the inlined summary, exactly the "plain backticked
  path references resolved on demand" pattern this project already uses deliberately elsewhere.
  Making them eager (option a, or the (c) middle path of eager-loading just
  `safety-invariants.md`) would spend real, ongoing token budget (`safety-invariants.md` is
  ~5.5 KB alone; all five together ≈ 51 KB / ~13k tokens, matching the prior audit's estimate)
  on content that is already load-bearing-duplicated where it operationally matters.
- **What is missing today is documentation of this reasoning**, not enforcement. `EXTENSION.md`'s
  "Operating rules are non-negotiable — see `domain/safety-invariants.md` before any `email`
  work" line, read literally, implies an agent must go read that file — but no consumer file
  actually cites `safety-invariants.md` by name anywhere (verified: zero matches in
  `skills/`, `agents/`, `commands/`, only in `EXTENSION.md`, `README.md`, and a cross-reference
  inside `index-architecture.md`). This is the actual defect: not missing enforcement, but an
  undocumented and unverified assumption about where the enforcement lives, exactly as the prior
  audit (task-history item, `specs/archive/036_audit_context_loading_efficiency/`) flagged and
  deferred. This task's job is to close that loop by recording the verified decision.

## Context & Scope

Investigated what `skill-email-cleanup`, `skill-email-sync`, and `email-implementation-agent`
actually load today, empirically, to settle whether the five email safety context pointers need
to become eager, stay as documented-but-inert pointers with the enforcement recorded elsewhere,
or take a middle path. Scope was read-only investigation; per the dispatch constraints, any doc
edit targets `agent-system/extensions/email/**` (source store) and must avoid task-number
references outside `specs/**`.

## Findings

### Codebase Patterns

**Loading-tier taxonomy (the key distinction this task turns on)**:

1. **Session-start eager** — `.claude/CLAUDE.md`'s own `@`-imports (e.g. the root `## Context
   Imports` section's `@.claude/context/repo/project-overview.md`), resolved by the harness at
   conversation start. The merged `## Email Extension` section's "Context Pointers" list uses
   **plain backticked paths**, not `@`-prefixed ones — confirmed non-resolving, matching the
   project-wide "lazy context loading" note in the root `CLAUDE.md`'s Important Notes.
2. **Invocation-time eager** — a `SKILL.md` or agent-definition `.md` body is read in full when
   the Skill/Agent tool invokes it (this is exactly how this research agent's own "Custom Agent
   Instructions" reached this session — no separate load step). Any `@`-style reference **inside**
   such a body (e.g. `agents/email-implementation-agent.md`'s "Context References ... Load these
   on-demand using @-references:") is **not** harness-expanded — it is stylistic documentation,
   not Claude Code's native import syntax, and only takes effect if the agent later performs an
   explicit `Read`. Verified directly: this agent's own frontmatter lists `@`-prefixed context
   files (e.g. `return-metadata-file.md`) that were not present in this session until explicitly
   read via a tool call moments ago.
3. **On-demand** — a plain path cited in prose (`wrapper-contracts.md §7`, `see
   archive-mode-risk.md`) that an agent reads only if it decides it needs the fuller derivation.

The five email safety files sit at tier 3 relative to `EXTENSION.md`/`CLAUDE.md`. But
`wrapper-contracts.md`, `index-architecture.md`, `staleness-detection.md`, and
`archive-mode-risk.md` are all **also** cited inline, by name and section, from within the
tier-2 bodies (`skill-email-cleanup/SKILL.md`, `skill-email-sync/SKILL.md`,
`email-implementation-agent.md`) as "full rationale" pointers alongside an inlined operational
summary — e.g. `skill-email-cleanup/SKILL.md` inlines the folder-scoping query table with
"(see `domain/index-architecture.md`)" for the full verified-forms table, and inlines the
archive-mode extra gates with "(full rationale: `archive-mode-risk.md`)". This is a coherent,
intentional pattern: summary inlined at tier 2, full derivation available at tier 3 on demand.

**The one file that breaks the pattern**: `safety-invariants.md` is the *only* one of the five
never cited by name from any of the three consumers. Its content (wrapper-only allowlist,
two-layer enforcement, propose-review-confirm-execute, `$PATH` precondition, `MAX_BATCH_SIZE`,
`PLAN_EXPIRY_DAYS`, delete confidence threshold) is instead **directly duplicated**, not
pointed-to, in `email-implementation-agent.md`'s "WRAPPER-ONLY CONTRACT" section and
`skill-email-cleanup/SKILL.md`'s opening sections. `safety-invariants.md` today functions as a
synthesis/onboarding document (what a human or a new consumer would read first to understand the
whole contract in one place), not as a runtime dependency of any existing consumer.

**Mechanical enforcement, independent of any markdown**:
- `hooks/mail-guard.sh`: PreToolUse Bash-matcher hook. Denies patterns matching raw
  `himalaya message delete/move/send`, `himalaya template send`, `himalaya folder expunge`,
  `msmtp`, `secret-tool`, `rm ... Mail`; allows the five named binaries by substring match;
  passes through everything else with no decision. Deployed and registered: confirmed present in
  `.claude/settings.local.json`'s `hooks.PreToolUse` and `permissions.deny` (from
  `settings-fragment.json`'s merge target).
- The nix-built wrapper binaries (`~/.dotfiles modules/home/email/agent-tools.nix`, external to
  this repo): hash check, staleness gate, `MAX_BATCH_SIZE=50` cap, `PLAN_EXPIRY_DAYS=7` expiry,
  and the confirm-manifest state machine are compiled into the binaries themselves — this layer
  holds even for a human invoking a wrapper directly, with zero agent/markdown involvement.

### External Resources

None consulted — this is a pure codebase-verification task; no external documentation applies.

### Recommendations

Record the decision in the source store (`agent-system/extensions/email/**`), not merely leave
it implied. Concretely, for the implementation phase to carry out:

1. **In `EXTENSION.md`**, replace the bare "Operating rules are non-negotiable — see
   `domain/safety-invariants.md` before any `email` work" sentence (and the plain "Context
   Pointers" list) with wording that states the verified, deliberate loading model: the five
   files are reference material, not eager-loaded; the operationally load-bearing rules are
   duplicated inline in the three consumer files named above (each genuinely eager at its own
   invocation time), and further backed by the two mechanical layers (`mail-guard.sh` + the
   wrapper binaries themselves). Keep the pointer list (still useful for a human/auditor), but
   drop the misleading "see ... before any work" imperative framing, since no consumer actually
   performs that read.
2. **At the top of `context/project/email/domain/safety-invariants.md`**, add a short banner
   stating its actual role: single-source-of-truth synthesis for humans/future extension
   authors, cross-referenced (not loaded) by the operational files, which duplicate its
   load-bearing content directly. This prevents a future audit from re-flagging it as a "dead
   import" — its non-loading is now a documented, deliberate choice rather than an apparent
   defect.
3. **No content change needed** to `skill-email-cleanup/SKILL.md`, `skill-email-sync/SKILL.md`,
   or `email-implementation-agent.md` — their existing inline duplication already carries the
   enforcement; verified line-by-line against `safety-invariants.md`'s five sections
   (Wrapper-Only, Two-Layer Enforcement, Propose-Review-Confirm-Execute, Delete Is
   Himalaya-Level Only, `$PATH` Precondition) and all five are present, in substance, in at
   least one of the three consumer bodies.
4. Do **not** eager-load any of the five files (rejects option a and the (c) middle path):
   the cost (~13k tokens/session if all five; ~1.4k for `safety-invariants.md` alone) buys
   nothing not already present at the tier that actually gates mutation.

## Decisions

- **Chosen**: option (b) — the wrapper contracts (mechanical, two-layer) plus the three
  consumers' own inlined safety content already carry the enforcement. This is recorded as the
  task's research-phase decision; the implementation phase should encode it as the two doc edits
  in Recommendations #1–2 above, so a future audit finds the reasoning in place rather than
  re-litigating it.
- Rejected (a): eager-loading all five files — unjustified recurring token cost given verified
  duplication.
- Rejected (c): eager-loading only `safety-invariants.md` — same objection at smaller scale;
  its content is the most duplicated of the five, so it is the *weakest* candidate for eager
  promotion, not the strongest.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| The inline duplication in the three consumer files could drift out of sync with `safety-invariants.md` over time (two copies of the same rules, maintained separately) | Note this explicitly in the `safety-invariants.md` banner (Recommendation #2) so a future editor knows to check both places; consider (out of scope here) a lint that diffs key constants (`MAX_BATCH_SIZE`, `PLAN_EXPIRY_DAYS`, the delete confidence threshold) across the duplicated locations — flagged as a possible follow-up, not required by this task |
| A future new consumer (e.g. a hypothetical fourth email skill) might assume `safety-invariants.md` is "loaded automatically" per the old prose and skip the explicit read/duplication step | The `EXTENSION.md` rewrite (Recommendation #1) makes explicit that new consumers must duplicate or explicitly read the relevant safety content themselves — it is not ambient |

## Context Extension Recommendations

- **Topic**: Loading-tier taxonomy (session-start eager / invocation-time eager / on-demand)
- **Gap**: This distinction — that a `SKILL.md`/agent-definition body is itself an eager-load
  tier, distinct from and more relevant than `CLAUDE.md`'s own `@`-import tier — is not written
  down anywhere in `.claude/context/`. It resolved real ambiguity in this task and will recur for
  any future "is X context actually loaded?" question.
- **Recommendation**: Consider adding a short pattern doc (e.g.
  `context/patterns/context-loading-tiers.md`) codifying the three tiers found here, so future
  audits (like the one that deferred this exact question) have a shared vocabulary instead of
  re-deriving it each time.

## Appendix

### Search queries / commands used
- `jq '.active_projects[] | select(.project_number==43)' specs/state.json`
- `grep -rn "safety-invariants\|wrapper-contracts\|index-architecture\|staleness-detection\|archive-mode-risk" skills/ agents/ commands/` (in `agent-system/extensions/email/`)
- `grep -rln "safety-invariants" .` (in `agent-system/extensions/email/`, to find all referrers)
- Inspected: `EXTENSION.md`, `manifest.json`, `agents/email-implementation-agent.md`,
  `skills/skill-email-cleanup/SKILL.md`, `skills/skill-email-sync/SKILL.md`,
  `hooks/mail-guard.sh`, `settings-fragment.json`, deployed `.claude/settings.local.json`,
  deployed `.claude/CLAUDE.md`'s merged Email Extension section
- Prior-audit cross-check: `specs/archive/036_audit_context_loading_efficiency/reports/01_team-research.md` (findings F2/F3, recommendation P5 — this task is the direct follow-on)

### References
- `agent-system/extensions/email/EXTENSION.md`
- `agent-system/extensions/email/manifest.json`
- `agent-system/extensions/email/agents/email-implementation-agent.md`
- `agent-system/extensions/email/skills/skill-email-cleanup/SKILL.md`
- `agent-system/extensions/email/skills/skill-email-sync/SKILL.md`
- `agent-system/extensions/email/hooks/mail-guard.sh`
- `agent-system/extensions/email/settings-fragment.json`
- `agent-system/extensions/email/context/project/email/domain/safety-invariants.md`
- `agent-system/extensions/email/context/project/email/domain/wrapper-contracts.md`
- `agent-system/extensions/email/context/project/email/domain/index-architecture.md`
- `agent-system/extensions/email/context/project/email/domain/staleness-detection.md`
- `agent-system/extensions/email/context/project/email/domain/archive-mode-risk.md`
