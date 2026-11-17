# Research Report: Task #627

**Task**: 627 - Reap orphan sapience mcp registrations
**Started**: 2026-11-17T09:25:12Z
**Completed**: 2026-11-17T10:15:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/sapience/**), live `~/.claude.json`, live `verify-sapience-mcp.sh` run, `specs/state.json`/`specs/TODO.md`
**Artifacts**: - specs/627_reap_orphan_sapience_mcp_registrations/reports/01_reap-orphan-sapience-mcp.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The task description's cited "measured evidence" (`/home/benjamin/Projects/sapience-app` as a
  stale `~/.claude.json` entry) has already been cleaned up by some other means — re-measured
  during this pass, that row now carries `"mcpServers": {}`. This does not close the task: the
  general structural gap the hook cannot reach is unchanged and unaddressed. Treat the cited
  path as illustrative of the defect class, not as a currently-reproducible repro.
- The structural gap is real and confirmed by reading the hook's own source
  (`hooks/sapience-mcp-register-project.sh`): its bidirectional register/remove logic is gated
  entirely on finding a reachable `.claude-extensions.json` at the CURRENT session's CWD or git
  root. A project whose directory was deleted or renamed can never again start a session there,
  so its row in `~/.claude.json` can never be visited by that branch of the hook — it leaks
  forever, independent of whether the repo it belonged to still loads the extension.
- **Decision (recorded)**: add a new `--reap` mode to `setup-sapience-mcp.sh` (the writer) that
  sweeps every `.projects[<path>].mcpServers.sapience` entry in `~/.claude.json` and removes just
  the `sapience` subkey for any `<path>` that is not a directory on disk, leaving every other key
  (other project settings, other MCP servers such as `lean-lsp`) untouched. The `SessionStart`
  hook invokes this reap pass unconditionally, on every session start in every repository —
  independent of whether the CURRENT repo activates sapience — because the whole point is to let
  some *other*, still-living session clean up after a repo that can no longer clean up after
  itself.
- `verify-sapience-mcp.sh` stays unchanged (single-project, detect-only by design); promoting it
  to a global multi-project fixer would widen its documented scope for no benefit once the
  writer owns `--reap` and the hook calls it automatically.

## Context & Scope

Researched the per-project Sapience MCP registration triad
(`agent-system/extensions/sapience/{hooks/sapience-mcp-register-project.sh,
scripts/setup-sapience-mcp.sh, scripts/verify-sapience-mcp.sh,
scripts/tests/test-sapience-mcp-registration.sh}`) to determine where and how to add a reaper
pass that removes `.projects[<path>].mcpServers.sapience` entries whose `<path>` no longer
exists on disk, per the task's SCOPE section. Per `rules/source-store-deploy-boundary.md`, the
edit target resolved via `.claude-extensions.json`'s `.extensions.sapience.source_dir` is
`/home/benjamin/.config/nvim/agent-system/extensions/sapience` — the source store, never the
deployed `.claude/` mirror. Redeploy via `deploy-headless.sh` happens at implementation time,
not during research.

Out of scope for this report (left to the plan/implement phases): writing the actual code
changes; this report establishes the design decision and the concrete mechanics so planning can
proceed directly to phased implementation without re-deriving them.

## Findings

### Codebase Patterns

**The writer already owns every `~/.claude.json` mutation; the hook never edits the file
directly.** `setup-sapience-mcp.sh` is the single choke point: `process_write`, `process_remove`,
and the standalone `--retire-global` action each do a `mktemp` + whole-file `jq` + `mv`, and the
hook (`sapience-mcp-register-project.sh`) only ever decides *which* writer invocation to make,
then shells out to it (`bash "$WRITER" --project "$PROJECT_PATH" --scope project [--remove]
--quiet`). A new reap capability belongs in the writer for exactly this reason — it is the
existing convention, not a new one, and keeps the "whole-file jq merge, preserve every other
key" invariant (setup-sapience-mcp.sh header, item 4) in the one place that already owns it.

**The hook's activation detection is the actual defect, confirmed from source.**
`hooks/sapience-mcp-register-project.sh` lines 82–92:

```bash
if [ -f ".claude-extensions.json" ]; then
    PROJECT_PATH="$(pwd)"
    EXTENSIONS_FILE="$(pwd)/.claude-extensions.json"
elif [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.claude-extensions.json" ]; then
    PROJECT_PATH="$GIT_ROOT"
    EXTENSIONS_FILE="$GIT_ROOT/.claude-extensions.json"
else
    # No .claude-extensions.json reachable at all: cannot determine activation. Silent, exit 0.
    echo '{}'
    exit 0
fi
```

This branch can only ever run **in a session whose CWD is inside the orphaned project** — which
is precisely the session that can no longer exist once the directory is gone or renamed. The
removal branch further down (`$HAS_EXISTING_ENTRY` + `! $IS_ACTIVE` → `--remove`) is unreachable
for an orphan by construction: it depends on first reaching line 100's `jq -r
'.extensions.sapience.status'` read against a file that, for an orphan, cannot be found at all.
This confirms the task's own diagnosis exactly — it is not a bug in the removal logic itself, it
is a precondition (a live, reachable project directory) that an orphan can never satisfy.

**No existing precedent for cross-project reaping.** The lean extension's parallel
per-project triad (`agent-system/extensions/lean/{hooks/lean-lsp-register-project.sh,
scripts/setup-lean-mcp.sh, scripts/verify-lean-mcp.sh}`) has the identical structural gap and no
reaper of its own — `grep -rn "reap\|orphan\|stale.*entry\|nonexistent" agent-system/extensions/lean/scripts/*.sh
agent-system/extensions/lean/hooks/*.sh` returns only a docstring comment, no implementation.
There is nothing to port; the design below is novel to this codebase, not an adaptation of an
existing pattern. (A corresponding gap likely exists for lean too, but extending the fix there is
out of scope for this task per its own file-scope framing — it names only the sapience extension.)

**Measured state of `~/.claude.json` at research time** (6 rows carry `.mcpServers.sapience`,
cross-checked against `[ -d <path> ]`):

| Project path | Exists on disk | Other MCP servers on the row |
|---|---|---|
| `/home/benjamin/.dotfiles` | yes | none |
| `/home/benjamin/.config/nvim` | yes | none |
| `/home/benjamin/Projects/BimodalLogic` | yes | `lean-lsp` |
| `/home/benjamin/Projects/Sapience/sf1-engine` | yes | none |
| `/home/benjamin/Projects/Sapience/sapience-app` | yes | none |
| `/home/benjamin/Projects/Sapience/sapience-pitch` | yes | none |

No row in the live file is currently orphaned (the cited `/home/benjamin/Projects/sapience-app`
row exists but already carries `"mcpServers": {}` — no `sapience` subkey at all, i.e. already
reaped by some other means before this research pass). This repository's own row
(`/home/benjamin/.config/nvim`) passes `verify-sapience-mcp.sh` checks (a)–(d) right now (live
run, 2026-11-17):

```
[PASS] (a) sapience extension active for /home/benjamin/.config/nvim
[PASS] (b) project-scoped sapience entry for /home/benjamin/.config/nvim matches the canonical shape
[PASS] (c) both installed user-level files exist and are executable
[PASS] (d) SessionStart entry present in /home/benjamin/.claude/settings.json
[FAIL] (e) merged .../settings.local.json has 11/7 sapience grants ...
```

Check (e)'s failure is the documented, pre-existing "loaded before the grant was narrowed to 7"
residual (`verify-sapience-mcp.sh`'s own NOTE text) — unrelated to this task, and the acceptance
criterion only requires (a)–(d), which already pass and must keep passing after this change.

**No existing "Risk N" enumeration to extend.** The hook's own comment references "Risk 6 in
this extension's domain docs," but `per-repo-scoping.md` (the domain doc this points at) has no
numbered risk list — only an unnumbered `## Hazards` section. The plan/implement phase should
either add this as a new `## Hazards` bullet there, under "The MCP-Registration Triad" section,
or leave a forward reference; either is consistent with existing structure, there is no numbered
list to renumber.

**No context-index gap requiring a new file.** `setup-sapience-mcp.sh`, the hook, and the test
file are all already declared in `manifest.json`'s `provides.scripts` — adding a mode to an
existing script needs no new manifest entry or deploy registration.

### External Resources

Not applicable — this is a self-contained shell/jq design question internal to the existing
triad; no external library or API research was needed.

## Recommendations

**Where the reap pass lives — `--reap` mode on `setup-sapience-mcp.sh`.** Of the task's three
named alternatives:

1. **New `--reap` mode in `setup-sapience-mcp.sh` (recommended).** Consistent with the existing
   "writer owns every `~/.claude.json` mutation" convention above. Testable in isolation exactly
   like the writer's existing `--remove`/`--retire-global` actions (cases 5–6 in the test file
   already follow this shape).
2. **Reap logic inlined directly in the hook.** Rejected — it would be the *first* place the
   hook mutates `~/.claude.json` itself rather than delegating to the writer, breaking the single
   choke-point convention for no benefit (the hook already shells out to the writer for every
   other mutation it causes).
3. **Promote `verify-sapience-mcp.sh` from detect-only to fix.** Rejected — that script is
   explicitly documented and designed as a **single-project** check (`--project PATH`, "Verifies
   the full per-project activation surface for THAT project"); a cross-project orphan sweep does
   not fit its per-project contract and would require either a second, incompatible mode or a
   parallel global-scan code path duplicating what the writer would otherwise own. Leave it
   unchanged.

**When the reap pass runs — unconditionally, on every `SessionStart`, independent of the current
repo's own activation state.** This is the subtle half of the decision: the reap sweep must NOT
be gated behind "this repo is active" (the existing `$IS_ACTIVE` branch), because an orphaned
project can never again host the session that would otherwise trigger its own cleanup. The fix
must be triggered by *some other, still-living* session — any session, anywhere, since the hook
is already a user-level `SessionStart` entry firing for every Claude Code session on the machine
(confirmed: `$HOME/.claude/settings.json`'s hook command resolves via `$HOME`, not
`$CLAUDE_PROJECT_DIR`). Concretely, restructure the hook so the reap call happens before — and
independent of — the existing `.claude-extensions.json`-reachability branch, gated only on the
two preconditions that branch already shares (jq present, writer installed):

```bash
# after the existing jq-present and WRITER-exists checks, before the .claude-extensions.json
# reachability branch:
REAP_OUTPUT="$(bash "$WRITER" --reap --quiet 2>&1)"
# ... collect into the same additionalContext notice the per-repo register/remove branch below
# already builds, merging via printf '%s\n' over an array of notice fragments rather than a
# single string, so either, both, or neither branch firing still yields exactly one JSON line.
```

The per-current-repo register/remove logic (the existing `$IS_ACTIVE` branch) is otherwise
unchanged; only the final notice-assembly needs to merge the reap notice with the (possibly
absent) per-repo notice into the one required JSON line.

**Mechanics of `--reap` itself:**

```bash
process_reap() {
    [ -f "$CLAUDE_CONFIG" ] || { log "No ~/.claude.json found, nothing to reap."; return 0; }
    local paths removed=()
    paths=$(jq -r '.projects | to_entries[] | select(.value.mcpServers.sapience != null) | .key' \
        "$CLAUDE_CONFIG" 2>/dev/null || echo "")
    while IFS= read -r p; do
        [ -n "$p" ] && [ ! -d "$p" ] && removed+=("$p")
    done <<< "$paths"
    [ ${#removed[@]} -eq 0 ] && { log "No orphaned sapience entries found."; return 0; }
    $DRY_RUN && { for p in "${removed[@]}"; do log "[DRY RUN] Would reap $p"; done; return 0; }
    local paths_json; paths_json=$(printf '%s\n' "${removed[@]}" | jq -R . | jq -s .)
    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --argjson paths "$paths_json" \
        'reduce $paths[] as $p (.; del(.projects[$p].mcpServers.sapience))' \
        "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"
    for p in "${removed[@]}"; do
        log "Reaped orphaned sapience entry for $p (path no longer exists on disk)"
        [ "$QUIET" = "true" ] && echo "sapience: reaped orphaned entry for $p"
    done
}
```

This satisfies every constraint in the task's SCOPE paragraph:

- **Touches only the `sapience` key**: `del(.projects[$p].mcpServers.sapience)` never touches
  `.projects[$p].mcpServers.<anything-else>` (e.g. `lean-lsp` on a BimodalLogic-shaped row) or
  any other field on the project row (history/cost/session metadata, as seen on the live
  `/home/benjamin/Projects/sapience-app` row).
- **A row left with no servers is handled explicitly, not abandoned silently**: after `del()`,
  `.mcpServers` becomes `{}` if sapience was the only server — exactly the shape already observed
  live on `/home/benjamin/Projects/sapience-app`. Document this inline as the deliberate decision
  (leave the empty object; do not delete the whole project row, which would discard unrelated
  session history/cost metadata unrelated to this task) rather than leaving it an implicit,
  unremarked side effect.
- **Preserves the hook's contract**: `--reap --quiet` is just another writer invocation captured
  via `$(...)` the same way `--remove --quiet` already is — no new failure mode, same
  `2>&1`-swallowing, same "writer failure degrades to silent `{}`" fallback path if its output is
  empty or its exit is nonzero.

**Test coverage to add** (satisfies "gains a case covering a registered-but-nonexistent project
path"): extend `scripts/tests/test-sapience-mcp-registration.sh` with a new case block (numbered
sequentially after case 30) covering:
1. A fixture row whose path does not exist and carries **both** `sapience` and `lean-lsp` →
   after `--reap`, `sapience` is gone and `lean-lsp` survives on the same row (proves the
   "touch only sapience" constraint against the sharpest case: an orphan that also carries an
   unrelated server).
2. A fixture row whose path **does** exist → survives `--reap` untouched (no false-positive
   reaping of a live project).
3. A fixture row whose path does not exist and `sapience` is its only server → after `--reap`,
   `.mcpServers == {}` explicitly asserted (not an absent key, not a deleted row).
4. `--dry-run --reap` mutates nothing (mirrors existing case 4's pattern for the write path).

## Decisions

- Reap lives in `setup-sapience-mcp.sh` as a new `--reap` mode, not in the hook and not in
  `verify-sapience-mcp.sh`.
- The hook invokes `--reap` unconditionally on every `SessionStart`, before/independent of the
  current repo's own `.claude-extensions.json`-reachability check — not gated on
  `$IS_ACTIVE` for the current repo.
- Scope of a single reap pass is strictly the `sapience` subkey; other MCP servers on an
  otherwise-orphaned row (e.g. `lean-lsp`) are left untouched, and an emptied `.mcpServers: {}`
  is the accepted, explicitly-documented end state rather than a further cleanup target.
- `verify-sapience-mcp.sh` is not modified — its per-project, detect-only contract stays as is.

## Risks & Mitigations

- **`[ -d "$path" ]` false positive on a permission-denied-but-existing directory.** A directory
  that exists but is inaccessible to the current user reads as "missing" and would be wrongly
  reaped. Mitigation: accept as a documented, low-probability edge case consistent with the
  existing design's general posture (the writer already treats `~/.claude.json` races and
  partial failures as acceptable via the existing `mktemp`+`mv` pattern); not worth a stat-based
  disambiguation given the triad's existing risk tolerance elsewhere.
- **Concurrent sessions calling `--reap` at the same time.** The existing `mktemp` + whole-file
  `jq` + `mv` pattern is already last-writer-wins under concurrency for every other writer
  action (`process_write`, `process_remove`, `--retire-global`); `--reap` inherits the identical,
  pre-existing risk profile rather than introducing a new one.
- **Running a global sweep on every session start, everywhere.** Cost is a handful of `jq` reads
  plus one `[ -d ]` test per currently-registered sapience project (6 today) — negligible given
  the hook already shells out to the writer on every session in an active repo today.

## Context Extension Recommendations

- **Topic**: sapience MCP-registration orphan handling.
- **Gap**: `per-repo-scoping.md`'s "The MCP-Registration Triad" subsection documents the writer,
  hook, installer, and verifier but has no mention of cross-project orphan reaping (there was
  none to document before this task).
- **Recommendation**: once implemented, add a short paragraph to that subsection (and, if a
  numbered risk list is introduced elsewhere, a `## Hazards` bullet) describing the `--reap`
  mode and the "any session can clean up any other repo's orphan" design rationale, so a future
  reader does not have to re-derive it from source the way this report did.

## Appendix

- Search queries / inspections used: direct `Read` of
  `hooks/sapience-mcp-register-project.sh`, `scripts/setup-sapience-mcp.sh`,
  `scripts/verify-sapience-mcp.sh`, `scripts/tests/test-sapience-mcp-registration.sh`; `jq`
  queries against the live `~/.claude.json` (`.projects | to_entries[] | select(.value.mcpServers.sapience != null)`)
  cross-checked with `[ -d ]` per path; `grep -rn "reap\|orphan\|stale.*entry\|nonexistent"` across
  both the sapience and lean extension script/hook directories; a live run of
  `verify-sapience-mcp.sh` in this repository.
- References: `.claude-extensions.json` (`source_dir` resolution),
  `rules/source-store-deploy-boundary.md`, `agent-system/extensions/sapience/manifest.json`
  (`provides.scripts`), `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`.
