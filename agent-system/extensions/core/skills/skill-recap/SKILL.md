---
name: skill-recap
description: Speak a short prose recap of the latest /orchestrate run through piper, or print it. User-only command - agents cannot invoke.
allowed-tools: Bash
user-only: true
---

# Recap Skill (Direct Execution)

Direct execution skill backing `/recap`. This command is **user-only** - agents MUST NOT invoke
it.

## Never Autonomous

An orchestration never plays audio by itself. `/orchestrate`'s conclusion stage only writes a
recap file and recommends this command by name; nothing on the orchestration path ever invokes
piper, paplay, or any other audio sink. Speaking is always this separate, explicitly
user-invoked step, and this skill is the only thing that ever calls into the speak path.

## Agent Restrictions

**Agents MUST NOT invoke this skill.** This is enforced by:
- `user-only: true` in this file's frontmatter
- The explicit prohibition above and in `commands/recap.md`
- Omission from the Skill-to-Agent Mapping table in CLAUDE.md

## Execution

### Step 1: Speak (or print) the latest recap

Call the recap script's default speak mode directly — no arguments, no flags:

```bash
bash .claude/scripts/orchestrate-recap.sh
```

This single call does everything: it resolves the most recent recap (the latest written recap
file, or a mechanically recomposed one when none exists), prints the resolved text, and then
speaks it through piper unless `TTS_ENABLED=0`, piper, its voice model, or `paplay` is
unavailable — in every one of those cases the text is still printed and the call still exits
`0`. There is no second TTS engine on any path and no further logic for this skill to add; its
only job is making this one call.
