# Research Report: Task #205

**Task**: 205 - Replace the single-global lean-lsp entry with per-project scoped registration
written automatically at session start
**Started**: 2026-09-09T18:39:00Z
**Completed**: 2026-09-09T19:10:00Z
**Effort**: ~1 hour
**Dependencies**: 203 (COMPLETED — reconciled sanctioned single-global-entry shape), 204
(COMPLETED — wired WARN-only drift detection for that shape)
**Sources/Inputs**: Codebase (agent-system/extensions/core, agent-system/extensions/lean),
live `~/.claude.json`, specs/203 and specs/204 artifacts, extension-system.md architecture doc
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The registration surface this task needs already exists, live, unused, and empty:
  `~/.claude.json`'s `.projects[<abs-path>].mcpServers` is a real per-project object on every
  one of the ~30 registered project paths on this machine (confirmed by direct `jq` inspection),
  and every single one is currently `{}` — task 203 removed cslib's ad hoc override rather than
  formalizing the mechanism. Nothing needs to be invented at the config-file level; it needs to
  be written to, deliberately, by a new automatic writer.
- Task 203's own research report explicitly identified and named this exact fix (its "Option
  B": "extend `setup-lean-mcp.sh` ... to optionally write into `~/.claude.json`'s
  `.projects["<cwd>"].mcpServers` local scope ... and update `mcp-server-ownership.md` to
  document local scope as sanctioned") and flagged it as "a legitimate alternative" against the
  concurrent-project cost, before task 203 chose the single-global-entry "Option A" instead.
  Task 205 is that flagged alternative, now mandated by live concurrency evidence.
- A concrete, precedented mechanism for "a hook that runs automatically at session start" exists
  and is already in production use for an unrelated purpose: the **email** extension merges a
  native Claude Code `SessionStart`-sibling hook (`PreToolUse`) into `settings.json` via its own
  `settings-fragment.json`'s `hooks` key, backed by a script under its own `hooks/` directory
  declared in `provides.hooks`. `merge_settings()`'s `deep_merge` has purpose-built,
  matcher-aware merge logic for hook-event arrays (`SessionStart`, `PreToolUse`, etc.) — appending
  new matcher blocks or appending new hook entries into an existing matcher block, never
  duplicating. This is the mechanism the lean extension should use for the new automatic
  registration hook: its own `hooks/` script, wired via its own `settings-fragment.json`'s
  `hooks.SessionStart` (matcher `"startup"`, matching the existing core precedent for
  `log-session.sh`/`claude-ready-signal.sh`), rather than hand-editing core's global
  `settings.json` or `merge-sources/settings-hooks.json`.
- Task 204's implementation summary recorded a rejection of a `SessionStart` hook as an
  alternative wiring point — but that rejection was for a *different* problem (WARN-only drift
  *detection*, tied to *task type*, which a global per-session hook genuinely cannot target well:
  "fires once per session regardless of task type, misses lean work begun mid-session"). *This*
  task's mechanism is CWD/git-root *detection*-driven, not task-type-driven, and fires exactly
  once per real session start against whatever directory the session opened in — which is
  precisely right for "was this Lean project's registration written yet." The two decisions do
  not conflict; they answer different questions.
- All seven outstanding issues named in the task description map directly onto specific,
  already-read files; each is confirmed to currently enforce the single-global-entry model and
  will need a coordinated (not independent) fix, since `verify-lean-mcp.sh` Check 9 and
  `setup-lean-mcp.sh`'s write target are two sides of the same semantic flip.

## Context & Scope

Researched: the current single-global-entry lean-lsp registration mechanism end to end
(`setup-lean-mcp.sh`, `verify-lean-mcp.sh`, `lean-mcp-preflight-check.sh`,
`mcp-server-ownership.md`), the live `~/.claude.json` shape actually used by Claude Code for
per-project scope, the extension settings-merge architecture's support for adding a native
`SessionStart` hook from within an extension, and the immediately preceding tasks (203, 204)
whose artifacts recorded the exact trade-off this task now overturns. Out of scope for this
research pass (left for planning): the precise hook script's argument/exit contract, whether
`setup-lean-mcp.sh`'s CLI flags need new options or a new sibling script, and the exact new
fixture set's file layout.

## Findings

### Codebase Patterns

**Registration surface, confirmed live and empty.** `jq '.mcpServers' ~/.claude.json` shows a
single global `lean-lsp` entry (currently pointed at `/home/benjamin/Projects/BimodalLogic`,
left there per task 203's own summary note "read this before using lean-lsp next"). Every
registered project path — `jq -r '.projects | keys[]'` lists ~30, including
`/home/benjamin/Projects/cslib` and `/home/benjamin/Projects/BimodalLogic` — has a `mcpServers`
key on its project object (confirmed via `jq '.projects[<path]"] | keys'`), and
`jq -r '.projects | to_entries[] | select(.value.mcpServers != null) | .key'` returns nearly
every path, but `jq '.projects[<path>].mcpServers'` on cslib, BimodalLogic, and a random sample
(`ProofChecker`) all return `{}`. This is the exact surface `mcp-server-ownership.md` calls
"local scope" and states plainly "nothing here writes to the local scope" — it is real,
first-class Claude Code config, just currently unwritten-to by anything in this repo.

**`setup-lean-mcp.sh`** (`agent-system/extensions/core/scripts/setup-lean-mcp.sh`) detects the
enclosing Lean project via `lakefile.lean`/`lakefile.toml` at CWD or git root (already handles
both markers, per the task description's premise), then unconditionally reads/writes
`.mcpServers."lean-lsp"` at the **top level** of `~/.claude.json` only. Its idempotency check
(added by task 203) is already whole-entry (command+args+env), not field-by-field — this
discipline must be preserved/reused for whichever per-project write path is added, per issue #2.

**`verify-lean-mcp.sh`** (`agent-system/extensions/core/scripts/verify-lean-mcp.sh`) Check 9
reads `.projects[$path].mcpServers."lean-lsp"` and hard-**FAILs** if it exists non-null,
explicitly framed as "shadow entry" drift under "the single-global-entry model (Option A)", with
remedy text `jq 'del(.projects["$path"].mcpServers."lean-lsp")'`. This is precisely the check
issue #1 says must be rewritten, not relaxed: under per-project scope the presence of a correct
project-scoped entry becomes the expected PASS state, and the drift conditions become "absent
project-scoped entry" or "project-scoped entry present but with a wrong/stale path" (Checks 6-8's
existing path-match and lakefile-marker logic can likely be reused against whichever entry is
authoritative for the CWD, once Check 9's target and framing flip).

**`lean-mcp-preflight-check.sh`** (`agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`)
is a thin WARN-only wrapper that invokes `verify-lean-mcp.sh` once, non-quiet, and forwards
`[FAIL]`/`[WARN]`/remedy lines on non-zero exit; it never inspects the config directly. Its
"always exit 0" contract (issue #4) is unaffected by *what* verify-lean-mcp.sh checks — only the
remedy text that flows through it changes meaning (it currently says "remove the project-scoped
override" and must instead say something like "the project-scoped entry is missing/stale, run
setup-lean-mcp.sh" once Check 9 inverts).

**`mcp-server-ownership.md`** (`agent-system/extensions/core/context/patterns/mcp-server-ownership.md`)
records, under "Invariant: a command path must never resolve inside a repository's own
`.claude/` tree," a "Trade-off recorded" paragraph stating project scope for lean-lsp is "a
deliberate non-goal here" and citing "the task's `user_decision` record" (task 203's). This is
the exact paragraph issue #3 requires revising, with the concurrency evidence from this task's
description (a session in BimodalLogic silently holding cslib's path) replacing the recorded
rationale. The separate, unrelated invariant in the same document (command path must never
resolve inside `.claude/`) is orthogonal and must be left untouched, as the task explicitly
requires.

**cslib's retired override (issue #6).** Task 203's summary confirms cslib previously had a
project-scoped override at `.projects["/home/benjamin/Projects/cslib"].mcpServers` pointing at a
hand-authored wrapper script (`~/Projects/cslib/.claude/scripts/lean-lsp-mcp-wrapper.sh`, deleted
that task, md5sum-archived first) — i.e. the override's *intent* (project-scoped correctness)
was right and only its *implementation* (a command path resolving inside a disposable
`.claude/` deploy tree, forbidden by the separate invariant above) was wrong. Re-establishing
cslib (and every other active Lean project — BimodalLogic confirmed, plus any current PR
worktrees such as the cslib-pr648 named in the task description) under the new mechanism should
use the same `uvx lean-lsp-mcp` command/args shape already sanctioned, just written to the
per-project location instead of (or in addition to) top-level.

**File-location split (issue #7).** Both `setup-lean-mcp.sh` and `verify-lean-mcp.sh` currently
live under `agent-system/extensions/core/scripts/`, declared in **core's** `manifest.json`
`provides.scripts`, while `lean-mcp-preflight-check.sh` lives under
`agent-system/extensions/lean/scripts/`, declared in **lean's** manifest. Grepping the whole
`agent-system/` tree for callers of the two core-owned scripts finds references only inside the
lean extension's own docs/scripts and inside core's own manifest/docs — nothing in core itself
depends on lean-lsp being registered. `mcp-server-ownership.md` itself frames
`core/scripts/setup-lean-mcp.sh` as *the* worked example of its general "user scope, per-project
computed arguments needed" mechanism — so moving these scripts to the lean extension (a
plausible resolution of issue #7) would also require revising that doc's own worked-example
location reference, not just the manifests.

### External Resources / Mechanism for "automatic at session start"

**Two distinct hook systems exist in this repo and must not be conflated.** (a) An internal,
agent-system-specific lifecycle-hook mechanism (`manifest.json` top-level `hooks` object; stages
`preflight`/`context_injection`/`verification`/`postflight`; executed by `skill-base.sh` only
during a *skill's* dispatch) — this is what the nix extension uses and what task 204 declined to
introduce for lean (no top-level `hooks` object in lean's manifest today). (b) Claude Code's own
**native** hook system, configured entirely inside `settings.json`'s top-level `hooks` object
(`SessionStart`, `PreToolUse`, `Stop`, etc.), fired by the harness itself independent of any
skill. The task's "written automatically at session start" requirement calls for (b), not (a) —
"session start" is a harness-level event, not a skill lifecycle stage.

**Confirmed precedent for an extension adding a native hook via its own settings-fragment.json**:
the **email** extension's `settings-fragment.json` merges a `hooks.PreToolUse` block calling its
own `hooks/mail-guard.sh` (declared via `provides.hooks: ["mail-guard.sh"]` in its manifest) —
this is a real, currently-deployed pattern, not merely documented capability. `merge.lua`'s
`deep_merge`/`merge_hook_event_array` functions specifically recognize "hook-event arrays" (any
array of `{matcher, hooks}` blocks) and merge them **by matcher** — appending new hook entries
into an existing same-matcher block, or appending a whole new matcher block — rather than via
generic array-append/dedup. This means an extension's own `settings-fragment.json` can safely add
a **new** `SessionStart` matcher block (e.g. its own dedicated matcher, or reusing `"startup"`)
without needing to touch or duplicate core's existing `SessionStart` entries
(`wezterm-clear-task-number.sh` on `"*"`, `log-session.sh`/`claude-ready-signal.sh` on
`"startup"`), and the merge survives being unloaded cleanly (`unmerge_settings()` uses the same
tracked-entry bookkeping already exercised for `permissions.allow`).

**Matcher choice precedent**: core's own `SessionStart` block already uses matcher `"startup"`
for exactly the "run once, on a genuine fresh session start" semantics
(`log-session.sh`, `claude-ready-signal.sh`, per
`agent-system/extensions/nvim/context/project/neovim/guides/neovim-integration.md`), as opposed
to `"*"` (fires on `startup`, `resume`, and `clear`/`compact` alike, used only by
`wezterm-clear-task-number.sh`, whose job is specifically to reset UI state on *any* re-entry).
Since a Lean project's path does not change across a resume/clear within the same working
directory, `"startup"` is the matcher that matches this task's actual need (write once per fresh
session against whatever directory it opened in) without redundant re-writes on every
clear/compact.

### Recommendations

1. **Registration target**: write to `~/.claude.json`'s `.projects[<abs-project-path>].mcpServers."lean-lsp"`,
   using the exact same whole-entry canonical shape (`uvx`/`["lean-lsp-mcp"]`/`LEAN_LOG_LEVEL`/`LEAN_PROJECT_PATH`)
   `setup-lean-mcp.sh` already generates, reusing `generate_lean_lsp_config()`'s logic rather than
   duplicating it. Planning should decide whether the top-level global entry is retired entirely,
   kept as a fallback for non-Lean-CWD sessions, or left alone as a separate, now-vestigial
   concern — the task description's "confirm during planning" note applies here.
2. **Automatic writer**: a new script under a lean-owned `hooks/` directory (mirroring the
   email extension's `hooks/mail-guard.sh` precedent), wired via lean's own
   `settings-fragment.json` `hooks.SessionStart` (matcher `"startup"`), declared in lean's
   manifest `provides.hooks`. It should reuse (not reimplement) `setup-lean-mcp.sh`'s detection
   and config-generation logic — planning should decide whether that means the hook script
   shells out to `setup-lean-mcp.sh` with a new `--project-scope`-style flag, or whether
   `setup-lean-mcp.sh` itself gains an automatic-detect-and-write-to-project-scope default
   behavior callable both interactively and from the hook.
3. **`verify-lean-mcp.sh` Check 9 rewrite**: invert to fail on a *missing or stale*
   project-scoped entry for a detected Lean project's CWD, rather than failing on its *presence*.
   Preserve Checks 1-8's existing command/args/`.claude`-boundary/lakefile-marker logic, redirected
   at whichever entry (project-scoped, once that's authoritative) is being verified.
4. **`lean-mcp-preflight-check.sh`**: no contract change (still WARN-only, always exit 0) but its
   remedy-text pass-through will automatically reflect whatever `verify-lean-mcp.sh` now emits —
   confirm no hardcoded "shadow entry"/"remove the override" string exists elsewhere in the
   wrapper itself (a search found none; it only filters `[FAIL]`/`[WARN]`/`Run setup-lean-mcp`
   lines generically).
5. **Fixture suite**: extend using the same mutation/falsifiability discipline already
   established in `test-lean-mcp-preflight-check.sh` (fixture HOME sandboxes, a neutralizing
   mutation check proving fixtures are actually discriminative) — new fixtures needed for: two
   concurrently-registered projects each resolving correctly, a fresh worktree of an
   already-registered repo (should register independently, not inherit/collide with the parent
   repo's entry), and the inverted Check 9 semantics (both the new-PASS and new-FAIL directions).
6. **File-location migration (issue #7)**: if planning decides to move `setup-lean-mcp.sh`/
   `verify-lean-mcp.sh` into the lean extension now that registration becomes lean-specific and
   per-project, `mcp-server-ownership.md`'s own worked-example path reference needs a matching
   edit, and both core's and lean's `manifest.json` `provides.scripts` arrays need updating in
   the same change (moving a script without updating both manifests breaks deploy).

## Decisions

- None made at research time beyond confirming the mechanism inventory above — this task's
  description explicitly reserves the registration-surface and file-split calls for planning
  ("Recommended mechanism, to be confirmed during planning" / issue #7's "Assess whether this
  split is still correct").

## Risks & Mitigations

- **Two-writer collision**: if the top-level global entry is retained alongside per-project
  entries, a future operator manually running `setup-lean-mcp.sh` (no per-project flag) could
  re-introduce global-entry drift that no longer matters functionally (per-project takes
  precedence) but could confuse `verify-lean-mcp.sh`'s reporting. Mitigation: planning should
  decide explicitly whether the global entry is retired, and if kept, what (if anything)
  `verify-lean-mcp.sh` should say about it.
- **Hook write races**: two Claude Code sessions starting concurrently in the *same* project
  directory both firing the SessionStart hook could race on `~/.claude.json`'s temp-file-then-`mv`
  write pattern already used by `setup-lean-mcp.sh` (atomic rename mitigates partial writes, but
  a lost-update between two concurrent read-modify-write cycles is still possible since both
  writes are idempotent to the *same* canonical value, this is low-severity — worst case is a
  redundant write, not corruption).
- **Acceptance demonstration cost**: the task's stated acceptance bar (two-plus Lean projects
  open concurrently, each returning a real lean-lsp result proven against project-unique
  evidence) requires genuinely spawning two fresh sessions during verification, mirroring task
  203's own acceptance methodology (fresh `claude -p` sessions in BimodalLogic and cslib) — this
  is a real-world verification step, not something a fixture alone can substitute for.

## Context Extension Recommendations

- **Topic**: Native Claude Code `SessionStart` (and other harness-level) hooks contributed by an
  extension via `settings-fragment.json`'s `hooks` key.
- **Gap**: `docs/architecture/extension-system.md`'s "Settings Merging" section documents only
  the `permissions` merge case; the email extension already exercises the `hooks` merge case in
  production, but no doc names it as a sanctioned pattern for hook contribution (only for
  permission grants).
- **Recommendation**: after this task lands, extend the "Settings Merging" section (or add a
  worked example alongside `mcp-server-ownership.md`) with the email extension's `hooks.PreToolUse`
  + `provides.hooks` pairing as the canonical "how an extension adds a native hook" pattern, since
  this task will likely be the second real usage of it.

## Appendix

### Search queries / commands used

- `find . -iname "*lean-mcp*"`, `find . -iname "mcp-server-ownership*"`
- `jq '.mcpServers'`, `jq -r '.projects | keys[]'`, `jq '.projects[<path>].mcpServers'`,
  `jq '.projects[<path>] | keys'` against live `~/.claude.json`
- `grep -rl "SessionStart" agent-system/`
- `jq '.hooks'` on `agent-system/extensions/core/root-files/settings.json`
- `cat agent-system/extensions/core/merge-sources/settings-hooks.json`
- `grep -rln "settings-fragment" agent-system/extensions/core/`
- Read of `lua/neotex/plugins/ai/shared/extensions/merge.lua` (`deep_merge`,
  `merge_hook_event_array`, `normalize_hook_event_array`, `merge_settings`)
- `cat agent-system/extensions/email/settings-fragment.json`,
  `jq '.provides.hooks' agent-system/extensions/email/manifest.json`
- `grep -rln "setup-lean-mcp.sh\|verify-lean-mcp.sh" agent-system/extensions/`
- Read of `specs/203_.../summaries/01_...-summary.md`, `specs/204_.../summaries/01_...-summary.md`,
  `specs/203_.../reports/01_...md` (Option A/B trade-off section)

### References

- `agent-system/extensions/core/scripts/setup-lean-mcp.sh`
- `agent-system/extensions/core/scripts/verify-lean-mcp.sh`
- `agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`
- `agent-system/extensions/core/context/patterns/mcp-server-ownership.md`
- `agent-system/extensions/email/settings-fragment.json`, `agent-system/extensions/email/hooks/mail-guard.sh`
- `agent-system/extensions/core/merge-sources/settings-hooks.json`,
  `agent-system/extensions/core/root-files/settings.json`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- `specs/203_reconcile_lean_lsp_mcp_registration/reports/01_reconcile-lean-lsp-registration.md`
  (Option A/B trade-off)
- `specs/203_reconcile_lean_lsp_mcp_registration/summaries/01_reconcile-lean-lsp-registration-summary.md`
- `specs/204_wire_lean_mcp_drift_detection/summaries/01_wire-lean-mcp-drift-detection-summary.md`
  (SessionStart-for-drift-detection rejection, distinguished above)
