---
description: Assemble a Sapience vault update from local and vault state, then gate every outward write behind one approval picker
allowed-tools: Skill
argument-hint: [message text] | --message [Name] [text]
---

# Command: /sapience

**Purpose**: Prepares a draft update for the Sapience project bound to this repository, drawing
on both local repository state and read-only vault state, and optionally addresses a named
collaborator. The run always ends in exactly one approval picker before anything leaves the
machine — nothing is ever written autonomously.
**Layer**: 2 (Command File - Argument Parsing Agent)
**Delegates To**: skill-sapience (direct execution)

**Input**: $ARGUMENTS

---

## Argument Parsing

First-match-wins mode detection over `$ARGUMENTS`, split on whitespace:

1. `--message <Name> [text]` — the token immediately after `--message` does NOT itself start
   with `--` and is not empty: that token is `Name`; everything after it is `text`.
   -> `mode=message name={Name} text={text}`
2. `--message [text]` (bare — nothing follows `--message`, or the next token starts with `--`) ->
   `mode=message_picker text={text}` (`text` is whatever followed, possibly empty).
3. No `--message` anywhere, and `$ARGUMENTS` is empty -> `mode=default`.
4. No `--message` anywhere, and `$ARGUMENTS` is non-empty free text -> `mode=default
   text={$ARGUMENTS}`.

Any other `--`-prefixed flag in `$ARGUMENTS` is a loud refusal — report the unrecognized flag by
name and stop; never silently pass it through as free text.

## Delegation

Delegate to `skill-sapience` with the resolved mode and its arguments, exactly as
`skill-sapience`'s own Mode Contract table documents them:

- `mode=default [text={text}]`
- `mode=message name={Name} text={text}`
- `mode=message_picker text={text}`

## The One Guarantee This Surface Must Carry

Every mode above reaches the same single mandatory approval picker inside `skill-sapience`
before any write — this command file states that guarantee and nothing more; the pre-check
defaults, the literal-payload discipline, and the four candidate write surfaces are
`skill-sapience`'s own responsibility and
`agent-system/extensions/sapience/context/project/sapience/domain/command-draft-and-picker.md`'s
design record, not duplicated here.

This command names no MCP write tool and no script outside what `skill-sapience` itself already
declares through `provides.scripts`.
