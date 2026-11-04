#!/usr/bin/env bash
# validate-task-creation-audit.sh
# PreToolUse hook, registered on matcher "Bash" -- the Bash-matcher command-text family
# (guard-destructive-git.sh, guard-git-push.sh), never the Write|Edit content-scanner family.
#
# PURPOSE (narrow and structural): Phase 5's audit-evidence gate inside `scripts/state-write.sh`
# refuses a `specs/state.json` write that introduces a new `active_projects` entry with no
# recorded `--audit-verdict`/`--audit-override`. That gate can only see writes that actually go
# THROUGH `state-write.sh`. This hook is the structural backstop against the obvious bypass:
# reverting to a raw `jq ... > <staging> && mv <staging> specs/state.json` (or an equivalent
# direct overwrite) that mutates `active_projects` without ever calling the sanctioned writer at
# all -- which Phase 5's gate, no matter how thorough, cannot observe. This hook forces the write
# through the place that performs the check; it does NOT re-implement the audit-verdict check
# itself (no verdict parsing, no corpus comparison) -- that is Phase 5's gate's job alone.
#
# DETECTION MODEL: a two-part structural test over the Bash command TEXT (same quote-strip,
# comment-strip COMMAND_SCAN technique guard-destructive-git.sh/guard-git-push.sh already use --
# reused verbatim here, not re-derived):
#   1. Does the scanned command text contain a WRITE-SHAPE targeting a `state.json`-named path
#      (an overwrite/append redirect `>`/`>>` whose target names `state.json`/`state.tmp`/
#      `state.json.tmp`, a `mv ... state.json` relocation, an in-place `sed -i` targeting
#      `state.json`, or a `tee` writing to `state.json`)?
#   2. Does the scanned command text also mention `active_projects` (the array Phase 5's gate
#      governs)?
# Both must hold for a refusal. A command matching neither, or matching only one, is allowed --
# in particular, a plain `jq '...' specs/state.json` with no write-shape at all (printing to
# stdout, or redirected to `/dev/null`) is a READ and is never blocked, and a write-shape that
# never mentions `active_projects` (e.g. a different top-level field) is outside this hook's
# declared scope and is left to Phase 5's gate / the state-writer-boundary lint.
#
# ALLOWED unconditionally: a command whose scanned text already contains the literal substring
# `state-write.sh` anywhere -- it is presumed routed through the sanctioned writer, which is
# where Phase 5's own gate applies. This hook never re-checks that presumption; a caller that
# merely NAMES `state-write.sh` in an unrelated comment while ALSO hand-rolling a bypass write in
# the same command string would slip through -- see the False-Negative Surface paragraph below.
#
# FALSE-NEGATIVE SURFACE (stated explicitly, this is a BACKSTOP, never the primary gate): this is
# a regex-only, command-TEXT scanner. It CANNOT catch a variable-indirected write (the path or
# filter built into a shell variable on an earlier line and only referenced here), a sufficiently
# obfuscated `jq` invocation (e.g. piped through `base64 -d` first), a write performed by a
# script this hook has no reason to suspect, or any bypass that never literally spells
# `active_projects` and a `state.json`-shaped write target in the SAME scanned command string.
# Phase 5's gate inside `state-write.sh` is the primary, structurally complete defense (it has
# full pre/post-transform JSON visibility and is evadable only by bypassing `state-write.sh`
# entirely -- which is exactly the narrow case this hook exists to catch).
#
# Blocks via exit code 2 + stderr (not `permissionDecision: deny`, which is documented-buggy for
# allow-listed `Bash(git:*)`-style commands per the GH issues guard-destructive-git.sh's own
# header names for the identical reason).

set -uo pipefail

INPUT=$(cat) || true
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""

[ "$TOOL_NAME" = "Bash" ] || exit 0
[ -n "$COMMAND" ] || exit 0

# Same quote-strip (sed -z, slurp mode) then comment-strip (line mode) as
# guard-destructive-git.sh/guard-git-push.sh -- see guard-destructive-git.sh's header for the
# full rationale; not re-derived here.
COMMAND_SCAN=$(printf '%s' "$COMMAND" \
  | sed -z -e 's/"[^"]*"/""/g' -e "s/'[^']*'/''/g" \
  | sed -e 's/\(^\|[[:space:]]\)#.*$//')

# Allowed unconditionally: a command already routed through the sanctioned writer.
if printf '%s' "$COMMAND_SCAN" | grep -qF "state-write.sh"; then
  exit 0
fi

# Part 1: write-shape targeting a state.json-named path.
WRITE_SHAPE=false
if printf '%s' "$COMMAND_SCAN" | grep -qE '(^|[;&|])[[:space:]]*mv[[:space:]].*state\.json'; then
  WRITE_SHAPE=true
fi
if printf '%s' "$COMMAND_SCAN" | grep -qE '>>?[[:space:]]*[^[:space:];&|]*state\.(json|tmp|json\.tmp)([[:space:]]|$)'; then
  WRITE_SHAPE=true
fi
if printf '%s' "$COMMAND_SCAN" | grep -qE '(^|[;&|])[[:space:]]*sed[[:space:]].*-i[a-zA-Z0-9._]*[[:space:]].*state\.json'; then
  WRITE_SHAPE=true
fi
if printf '%s' "$COMMAND_SCAN" | grep -qE '(^|[;&|])[[:space:]]*tee[[:space:]].*state\.json'; then
  WRITE_SHAPE=true
fi

[ "$WRITE_SHAPE" = true ] || exit 0

# Part 2: the write-shape command also mentions active_projects -- the array Phase 5's gate
# governs. Scanned against the RAW $COMMAND, deliberately NOT $COMMAND_SCAN: the hazardous
# mention is almost always INSIDE the quoted jq filter argument itself (e.g.
# '.active_projects += [...]'), which COMMAND_SCAN's quote-strip erases by design for the
# git-family guards (where the hazard is argv STRUCTURE, not quoted text). Here the opposite is
# true -- "active_projects" appearing anywhere in the command, quoted or not, is real signal, and
# there is no comparable false-positive risk from scanning the raw text for this one literal
# field name (unlike a git subcommand name, which a commit message could coincidentally quote).
# A write-shape targeting state.json that never mentions active_projects at all (e.g. a
# hand-rolled edit to some other top-level field) is outside this hook's declared scope.
if ! printf '%s' "$COMMAND" | grep -qF "active_projects"; then
  exit 0
fi

echo "BLOCKED: this Bash command appears to write to a state.json-shaped path while mentioning" >&2
echo "'active_projects', without routing through scripts/state-write.sh." >&2
echo "" >&2
echo "Every specs/state.json write that creates or mutates an active_projects entry must go" >&2
echo "through scripts/state-write.sh -- the single mutex-guarded writer whose audit-evidence" >&2
echo "gate (--audit-verdict FILE / --audit-override REASON) is the ONLY place a new task" >&2
echo "creation is checked against the backlog-reconciliation requirement (Multi-Task Creation" >&2
echo "Standard, Component 4b). A hand-rolled jq-stage-then-mv (or equivalent) bypasses that gate" >&2
echo "entirely -- it is invisible to it, not merely unchecked by it." >&2
echo "" >&2
echo "Remedy: route this write through state-write.sh, e.g.:" >&2
echo "  bash .claude/scripts/state-write.sh '<jq filter>' --session-id \"\$SESSION_ID\" \\" >&2
echo "    [--allocate-into NAME] [--audit-verdict FILE | --audit-override REASON]" >&2
echo "See scripts/audit-task-proposals.sh for generating the audit verdict, and" >&2
echo "context/patterns/backlog-reconciliation.md for the full contract." >&2
echo "" >&2
echo "This is a structural BACKSTOP only (command-text scanning), not the primary gate -- a" >&2
echo "variable-indirected or sufficiently obfuscated write can evade it; the primary defense is" >&2
echo "state-write.sh's own audit-evidence gate." >&2
exit 2
