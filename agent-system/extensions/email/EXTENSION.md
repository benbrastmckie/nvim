## Email Extension

This project includes AI-assisted email triage over Himalaya/notmuch via the email extension.
All mutation goes through five nix-built wrapper binaries; the extension itself never calls
`himalaya`/`notmuch`/`msmtp` directly. Operating rules are non-negotiable — they are enforced
mechanically by `hooks/mail-guard.sh` plus the wrapper binaries' own baked-in checks, and carried
inline in each email skill/agent body at its own invocation time; the domain files below are
on-demand reference material, not ambient context loaded before `email` work.

### Task-Type Routing

| Task Type | Research | Plan | Implement | Agent |
|-----------|----------|------|-----------|-------|
| `email` | general-research-agent (direct) | planner-agent (direct) | skill-email-implementation | email-implementation-agent (sonnet) |

Direct-execution skills (no agent dispatch):

| Skill | Purpose |
|-------|---------|
| skill-email-cleanup | `/email` triage: default 50-step mode, `--all` whole-mailbox mode, `--archive` scope |
| skill-email-sync | `/email --sync` human-confirmed `mbsync` reconcile to the account's server |

### Commands

| Command | Description |
|---------|-------------|
| `/email` | Default safer mode: bounded 50-step census -> classify -> review -> confirmed archive/delete pass; repeated runs step forward via the durable `+proposed-*` tag cursor |
| `/email --all` | Whole-mailbox mode: chunked backgrounded classify sweep, ONE consolidated sender/domain bucket approval, transparent ≤50-per-action execute drain |
| `/email --archive` | Scope flag (composable): operate on the account's archive folder with extra-caution gates and a per-account pilot gate before full scale |
| `/email --sync [channel]` | Human-confirmed `mbsync` reconcile pushing a completed cleanup to the account's server; channel defaults from the account, never auto-chained |
| `/email --account <gmail\|logos>` / `/email --logos` | Account selector (default `gmail`). Composable with any of the above. Both accounts are live; an unknown value is rejected loudly, never a silent fallback |

### Context Pointers (read-on-demand reference, not eager-loaded)

These five paths are deliberately plain (never promoted to `@`-imports): the enforcement lives
in `hooks/mail-guard.sh`, the wrapper binaries themselves, and the inline copies in
`agents/email-implementation-agent.md`, `skills/skill-email-cleanup/SKILL.md`,
`skills/skill-email-sync/SKILL.md`, and `skills/skill-email-implementation/SKILL.md` — the full
evidence for that claim is the enforcement-coverage map in `safety-invariants.md`'s own
"Role and Loading Model" section. A future new email skill or agent must inline or explicitly
`Read` the safety content it depends on; nothing below reaches it ambiently.

- `.claude/context/project/email/domain/safety-invariants.md`
- `.claude/context/project/email/domain/wrapper-contracts.md`
- `.claude/context/project/email/domain/index-architecture.md`
- `.claude/context/project/email/domain/staleness-detection.md`
- `.claude/context/project/email/domain/archive-mode-risk.md`
