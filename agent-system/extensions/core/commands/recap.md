---
description: Speak a short prose recap of the latest /orchestrate run through piper, or print it (user-only)
allowed-tools: Bash
---

# Command: /recap

**Purpose**: Hears (or reads) a short, speech-shaped prose recap of the most recent
`/orchestrate` run — what landed, what failed if anything, and the single most useful next
action.
**User Only**: YES - Agents MUST NOT invoke this command.
**Layer**: 1 (Direct execution)
**Delegates To**: skill-recap (Direct execution skill)

---

## Never Autonomous

An orchestration never plays audio by itself. The conclusion stage only WRITES a recap file and
RECOMMENDS this command by name in its final written output; speaking is always this separate,
explicitly user-invoked step. `/recap` is the only thing that ever calls into the speak path.

---

## Usage

```
/recap
```

No arguments. Reads the most recent orchestration's recap only — there is no session-id
argument and no history-browsing mode.

## Behavior

1. If a recap file exists for the most recent `/orchestrate` run, its text is used.
2. Otherwise, a recap is recomposed mechanically from the most recent run's durable metadata,
   rather than failing.
3. The resolved text is always printed.
4. The text is then spoken through piper, unless `TTS_ENABLED=0` is set, piper (or its voice
   model) is unavailable, or `paplay` is unavailable — in every one of those cases this command
   still prints the text and exits successfully. There is no second TTS engine on any path.

---

## Agent Restrictions

**Agents MUST NOT invoke /recap**. This is enforced by:
- `user-only: true` in skill frontmatter
- Explicit prohibition in this command file and in `skill-recap`
- No agent mapping in CLAUDE.md
