-- neotex.plugins.ai.shared.extensions.hook_identity
--
-- The single normative definition of hook-registration IDENTITY -- "is this deployed hook
-- entry the same registration as that source-declared one" -- shared by merge.lua's dedup/
-- merge/orphan-sweep logic and the hook-registration-path lint's fragment-coverage check (via
-- the standalone CLI bridge, hook_identity_cli.lua). See hook_identity_fixtures.json for the
-- conformance corpus both consumers are pinned against.
--
-- WHY THIS EXISTS: merge.lua's original, narrower `hook_identity()` fixed a real production
-- defect -- a changed command string no longer compared `vim.deep_equal`, so a stale
-- registration survived beside its corrected replacement rather than being replaced -- but
-- recognized only a bare `.claude/hooks/NAME.sh`-shaped command. The hook-registration-path
-- lint independently grew its OWN, broader identity notion (`normalize_identity()`, covering
-- any directory-qualified `*.sh` invocation, not only `hooks/`), a documented divergence
-- (D4/D5 in lint-hook-registration-paths.sh). This module reconciles the two into exactly one
-- definition: a strict superset of merge.lua's old behavior (every previously-eligible command
-- is still eligible, now keyed on its full directory-qualified path rather than bare basename)
-- that agrees with the lint's D5 normalization rule.
--
-- ELIGIBILITY (when this returns a non-nil identity):
--   1. The command contains the substring `.claude/` (anywhere, any anchor -- bare
--      CWD-relative, `"$CLAUDE_PROJECT_DIR"`-prefixed, or any other absolute prefix):
--      eligible. The normalized path is everything after the LAST `.claude/` occurrence, up to
--      the end of the invoked `*.sh` token. This collapses every anchor variant of the same
--      `hooks/NAME.sh` hook to one identity -- the original production-defect fix, unchanged.
--   2. The command contains no `.claude/` substring at all, AND the invoked `*.sh` token is a
--      plain relative path (does not start with `/` or `~/`): eligible, normalized to the
--      token exactly as written (e.g. `"scripts/claude-ready-signal.sh"`). This is the new
--      case the lint's D5 rule already covers and merge.lua's old function did not.
--
-- INELIGIBILITY (nil -- the mandatory carve-out: a command this function returns nil for is
-- NEVER matched, moved, deduped, or swept by any caller; every caller falls through to exact
-- `vim.deep_equal` comparison instead):
--   - No `*.sh` invocation anywhere in the command (an inline shell snippet with no script
--     call, or an `mcpServers` entry's `"command": "npx"` value).
--   - A `~/`-anchored script path. This is a deliberate THIRD accepted anchor (alongside
--     `.claude/`-relative and `"$CLAUDE_PROJECT_DIR"`-prefixed) -- cwd-independent, and in
--     real, intentional use (`~/.config/nvim/scripts/claude-ready-signal.sh`). It names a
--     script outside the source store's own tree entirely and MUST NEVER be swept.
--   - An absolute (`/`-leading) script path that does NOT contain `.claude/`. This third
--     condition is not literally one of the two headline ineligibility rules this module was
--     commissioned to implement, but is REQUIRED by their shared purpose: no real source-store
--     script is ever registered via a bare absolute path outside `.claude/` -- every real
--     convention is `.claude/`-relative, `"$CLAUDE_PROJECT_DIR"`-prefixed, or the one
--     documented `~/` exception above. A bare absolute non-`.claude/` path is therefore,
--     definitionally, a user's own hand-written custom hook (e.g.
--     `/opt/mytools/my-custom-hook.sh --flag value`) -- exactly the case the mandatory
--     carve-out exists to protect. Treating it as eligible would let an unrelated valid_set
--     miss silently delete a user's own registration, the single most dangerous possible
--     regression in the sweep this module backs. See the dedicated survival spec in
--     merge_spec.lua and the matching fixture row in hook_identity_fixtures.json.
--
-- Pure Lua, no `vim.*` dependency: this module is loaded by the standalone CLI bridge
-- (hook_identity_cli.lua) via a bare `dofile`, outside Neovim, from the hook-path lint.

local M = {}

--- Resolve a hook registration's identity.
--- @param command string The hook's "command" field
--- @param hook_type string The hook's "type" field
--- @return string|nil identity "<type>:<normalized_path>", or nil when not identity-eligible
function M.identity(command, hook_type)
  if type(command) ~= "string" or type(hook_type) ~= "string" or command == "" then
    return nil
  end

  -- Rule 1: `.claude/` present anywhere -- normalize from the LAST occurrence, so multiple
  -- `.claude/` mentions in one command (rare, but possible inside a bash -c wrapper) resolve
  -- against the one nearest the actual invoked script.
  local last_end = nil
  local search_from = 1
  while true do
    local s, e = command:find(".claude/", search_from, true)
    if not s then
      break
    end
    last_end = e
    search_from = e + 1
  end

  if last_end then
    local rest = command:sub(last_end + 1)
    local path = rest:match("^([%w_%-%./]+%.sh)")
    if not path then
      return nil
    end
    return hook_type .. ":" .. path
  end

  -- Rule 2: no `.claude/` anywhere -- find the invoked `*.sh` token. Scans the whole command
  -- (via gmatch, keeping the LAST match) so a `bash -c '...'` wrapper's actually-invoked
  -- script is found regardless of nesting -- the "innermost invoked" requirement.
  local token = nil
  for candidate in command:gmatch("(%S+%.sh)") do
    token = candidate
  end
  if not token then
    return nil
  end

  if token:sub(1, 2) == "~/" then
    return nil
  end
  if token:sub(1, 1) == "/" then
    return nil
  end

  return hook_type .. ":" .. token
end

return M
