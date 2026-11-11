-- neotex.plugins.ai.shared.extensions.hook_identity_cli
--
-- Logic-free stdin/stdout bridge over hook_identity.lua, so a shell-based consumer (the
-- hook-registration-path lint) can resolve identities through the SAME single normative
-- definition the Lua-side merge/sweep mechanism uses, without a second implementation.
--
-- Protocol: reads "<type>\t<command>" lines from stdin (one hook registration per line, in
-- order), and writes exactly one line per input line to stdout: the resolved identity
-- ("<type>:<normalized_path>"), or an EMPTY line when the command is not identity-eligible
-- (nil). Output line count always equals input line count, in the same order -- a caller
-- that sees a mismatched count has caught a bridge defect, not an identity answer.
--
-- Runnable standalone, outside Neovim's normal startup, as:
--   nvim --headless --noplugin -u NONE -l <abs path to this file>
--
-- `dofile`s the sibling hook_identity.lua by its own absolute path (derived from this file's
-- own `arg[0]`-independent source location via debug.getinfo) rather than `require`, since a
-- bare `-l` invocation has no `neotex.*` runtimepath set up at all.

local this_file = debug.getinfo(1, "S").source:match("^@(.*)$")
local this_dir = this_file:match("^(.*)/[^/]+$")
local hook_identity = dofile(this_dir .. "/hook_identity.lua")

for line in io.lines() do
  local hook_type, command = line:match("^([^\t]*)\t(.*)$")
  local identity = nil
  if hook_type ~= nil then
    identity = hook_identity.identity(command, hook_type)
  end
  io.write((identity or "") .. "\n")
end
