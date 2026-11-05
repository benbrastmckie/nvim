-- neotex.plugins.ai.shared.extensions.repo_registry
-- Cross-repo registry of which repositories `<leader>al` has loaded extensions into, and which
-- extensions each repo has loaded. Consumed by the `Global Update` picker entry so it can reload
-- every registered repo's own loaded-extension set without the operator having to visit each
-- repo individually.
--
-- INVESTIGATION NOTE (recorded before writing code, per this phase's task list): no
-- repo-registration mechanism exists anywhere in lua/neotex/plugins/ai/ prior to this module --
-- re-confirmed by grep at implementation time (`grep -rni "global update\|repo registration\|
-- register.*repo\|registered_repos" lua/neotex/plugins/ai/`), matching the research report's own
-- finding. This is a new module, not an extension of an interim one.
--
-- STORAGE LOCATION (decided and documented here): a single global JSON file under the
-- established `stdpath("data") .. "/neotex-ai"` shared-data convention (see
-- `lua/neotex/plugins/ai/shared/picker/ai-tool-picker.lua`'s `data_dir`), NOT a per-project file
-- -- the registry's whole purpose is to span projects, so it must live somewhere every project
-- can reach regardless of which repo nvim is currently running in.
--
-- SCHEMA: { repos = { [absolute_project_dir] = { extensions = {name1, name2, ...},
--   last_seen = "<ISO8601>" }, ... } }. `extensions` is kept as a sorted array (not a set) so the
-- on-disk file is diff-friendly and deterministic across repeated writes.
--
-- HOST-REPO EXCLUSION (decided and documented here): the host repo -- i.e. this very
-- `~/.config/nvim` tree, identified via `vim.fn.stdpath("config")` -- is deliberately NEVER
-- registered. Loading an extension into the host repo is the normal "local development on the
-- agent system itself" case, not a "deploy to another project" case, and registering it would
-- make `Global Update` (run FROM this same repo) recurse into itself -- resyncing the repo it is
-- already running in a second time, redundantly, as part of its own cross-repo loop. Any other
-- repo, including ones nested under the host repo's own working tree, is registered normally.

local M = {}

local data_dir = vim.fn.stdpath("data") .. "/neotex-ai"
local registry_file = data_dir .. "/extension-repo-registry.json"

--- Resolve the host repo's canonical directory (no trailing slash). Exposed as a local rather
--- than computed inline so `M.is_host_repo` and tests can agree on exactly one definition.
--- @return string host_dir
local function host_dir()
  return vim.fn.resolve(vim.fn.stdpath("config"))
end

--- Whether `project_dir` IS the host repo (see HOST-REPO EXCLUSION above).
--- @param project_dir string Absolute project directory
--- @return boolean
function M.is_host_repo(project_dir)
  if not project_dir or project_dir == "" then
    return false
  end
  return vim.fn.resolve(project_dir) == host_dir()
end

--- Read the registry from disk. Never raises: a missing, unreadable, or corrupt file yields the
--- empty structure rather than an error, since the registry is best-effort bookkeeping, never a
--- load-blocking dependency.
--- @return table registry { repos = { [project_dir] = { extensions = {...}, last_seen = ... } } }
function M.read()
  local empty = { repos = {} }
  if vim.fn.filereadable(registry_file) ~= 1 then
    return empty
  end
  local ok_read, lines = pcall(vim.fn.readfile, registry_file)
  if not ok_read or not lines or #lines == 0 then
    return empty
  end
  local ok_decode, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" or type(decoded.repos) ~= "table" then
    return empty
  end
  return decoded
end

--- Write the registry to disk atomically (temp file + rename, mirroring
--- `merge.lua`'s `generate_opencode_json` atomic-write pattern). Never raises.
--- @param registry table Registry table to persist
--- @return boolean success
--- @return string|nil error Error message on failure, nil on success
local function write(registry)
  local ok_mkdir = pcall(vim.fn.mkdir, data_dir, "p")
  if not ok_mkdir then
    return false, "repo_registry: failed to create data directory " .. data_dir
  end

  local ok_encode, encoded = pcall(vim.json.encode, registry)
  if not ok_encode then
    return false, "repo_registry: failed to encode registry JSON"
  end

  local temp_path = registry_file .. ".tmp." .. tostring(os.time())
  local ok_write = pcall(vim.fn.writefile, { encoded }, temp_path)
  if not ok_write then
    return false, "repo_registry: failed to write temporary file"
  end

  local rename_ok = os.rename(temp_path, registry_file)
  if not rename_ok then
    -- Fallback: direct write (mirrors generate_opencode_json's own fallback).
    local ok_direct = pcall(vim.fn.writefile, { encoded }, registry_file)
    if not ok_direct then
      return false, "repo_registry: failed to write registry file"
    end
  end

  return true, nil
end

--- Register (or update) one repo's loaded-extension set after an extension successfully loads.
--- Non-fatal by design: callers (manager.load) must never fail a load because a registry write
--- failed -- see the hook site's own comment for how this contract is honored.
--- @param project_dir string Absolute project directory that just had an extension loaded into it
--- @param extension_name string Name of the extension that was loaded
--- @return boolean success True if the registry was updated and persisted
--- @return string|nil error Error message on failure (structured, never raised)
function M.upsert(project_dir, extension_name)
  vim.validate({
    project_dir = { project_dir, "string" },
    extension_name = { extension_name, "string" },
  })

  if M.is_host_repo(project_dir) then
    -- Deliberately not registered -- see HOST-REPO EXCLUSION above.
    return true, nil
  end

  local registry = M.read()
  local resolved = vim.fn.resolve(project_dir)
  local entry = registry.repos[resolved] or { extensions = {} }

  local already_present = false
  for _, name in ipairs(entry.extensions) do
    if name == extension_name then
      already_present = true
      break
    end
  end
  if not already_present then
    table.insert(entry.extensions, extension_name)
    table.sort(entry.extensions)
  end
  entry.last_seen = os.date("!%Y-%m-%dT%H:%M:%SZ")

  registry.repos[resolved] = entry

  local ok, err = write(registry)
  if not ok then
    vim.schedule(function()
      vim.notify(
        "Warning: extension repo registry write failed (non-fatal, load still succeeded): "
          .. tostring(err),
        vim.log.levels.WARN
      )
    end)
  end
  return ok, err
end

--- List every registered repo.
--- @return table rows Array of { project_dir = string, extensions = {name, ...},
---   last_seen = string }
function M.list()
  local registry = M.read()
  local rows = {}
  local dirs = {}
  for project_dir, _ in pairs(registry.repos) do
    table.insert(dirs, project_dir)
  end
  table.sort(dirs)
  for _, project_dir in ipairs(dirs) do
    local entry = registry.repos[project_dir]
    table.insert(rows, {
      project_dir = project_dir,
      extensions = entry.extensions or {},
      last_seen = entry.last_seen,
    })
  end
  return rows
end

--- Remove every registered row whose directory no longer exists on disk. Reachable rows are
--- left untouched.
--- @return table removed Array of project_dir strings that were pruned
function M.prune_unreachable()
  local registry = M.read()
  local removed = {}
  for project_dir, _ in pairs(registry.repos) do
    if vim.fn.isdirectory(project_dir) ~= 1 then
      table.insert(removed, project_dir)
    end
  end
  if #removed > 0 then
    for _, project_dir in ipairs(removed) do
      registry.repos[project_dir] = nil
    end
    table.sort(removed)
    write(registry)
  end
  return removed
end

return M
