-- neotex.plugins.ai.shared.extensions.verify
-- Post-load verification for extension integrity

local M = {}

-- Drives the manifest-driven category verification below (see verify_manifest_category):
-- loader.CATEGORY_DESCRIPTORS is Phase 2's single source of truth for how every provides.*
-- category maps declared entries to deployed paths, reused here rather than duplicating a
-- second hand-maintained category list.
local loader_mod = require("neotex.plugins.ai.shared.extensions.loader")

--- Verify that a file exists on disk
--- @param filepath string Path to file
--- @return boolean exists True if file exists
local function file_exists(filepath)
  return vim.fn.filereadable(filepath) == 1
end

--- Verify that a directory exists on disk
--- @param dirpath string Path to directory
--- @return boolean exists True if directory exists
local function dir_exists(dirpath)
  return vim.fn.isdirectory(dirpath) == 1
end

--- Normalize index entry path by stripping known bad prefixes
--- Mirrors the normalization in merge.lua so verification checks the same paths
--- @param path string Path to normalize
--- @return string normalized_path Path with bad prefixes stripped
local function normalize_index_path(path)
  -- Strip full extension path prefix: .claude/extensions/*/context/ or .opencode/extensions/*/context/
  path = path:gsub("^%.claude/extensions/[^/]+/context/", "")
  path = path:gsub("^%.opencode/extensions/[^/]+/context/", "")

  -- Strip partial context prefix
  path = path:gsub("^context/", "")

  -- Strip .claude/context/ or .opencode/context/ prefix
  path = path:gsub("^%.claude/context/", "")
  path = path:gsub("^%.opencode/context/", "")

  return path
end

--- Read JSON file
--- @param filepath string Path to JSON file
--- @return table|nil data Parsed JSON or nil on error
local function read_json(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return nil
  end

  local ok, result = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end

  return result
end

--- Recursively scan a directory for files. Mirrors loader.lua's private helper of the same
--- name; kept as an independent local copy rather than requiring loader.lua to export it, since
--- this is the only other consumer and the two are simple enough to stay correct independently.
--- @param dir string Directory path
--- @return table files Array of relative file paths
local function scan_directory_recursive(dir)
  local files = {}

  if vim.fn.isdirectory(dir) ~= 1 then
    return files
  end

  local all_files = vim.fn.glob(dir .. "/**/*", false, true)
  for _, filepath in ipairs(all_files) do
    if vim.fn.isdirectory(filepath) ~= 1 then
      table.insert(files, filepath:sub(#dir + 2))
    end
  end

  -- Also check for top-level files (glob **/* doesn't match them)
  local top_files = vim.fn.glob(dir .. "/*", false, true)
  for _, filepath in ipairs(top_files) do
    if vim.fn.isdirectory(filepath) ~= 1 then
      local rel_path = filepath:sub(#dir + 2)
      local found = false
      for _, f in ipairs(files) do
        if f == rel_path then
          found = true
          break
        end
      end
      if not found then
        table.insert(files, rel_path)
      end
    end
  end

  return files
end

--- Compute a sha256 content hash for a file, using the SAME line-array semantics
--- `loader.lua`'s `copy_file` itself copies with (`vim.fn.readfile`/`writefile`, not a raw byte
--- stream). `writefile()` unconditionally appends a trailing newline after the last line unless
--- called with the `"b"` binary flag, which `copy_file` does not use -- so a source file that
--- itself lacks a final trailing newline is faithfully (by this copy engine's own definition)
--- deployed with one added. Hashing raw bytes would make that a false-positive "differs from
--- source" finding on every such file after a completely clean deploy (confirmed empirically:
--- `context/formats/frontmatter.md` in this repo lacks a final newline and reproduced exactly
--- this false positive before this fix). Hashing the same line-joined content the copy engine
--- itself reads/writes makes a faithfully-copied file hash identically while still catching any
--- REAL content divergence (verified: a deliberately-staled skill file with an appended line
--- still hashes differently).
--- @param filepath string Path to file
--- @return string|nil hash Hex sha256 digest of the line-joined content, or nil if unreadable
local function file_hash(filepath)
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil
  end
  local ok, lines = pcall(vim.fn.readfile, filepath)
  if not ok or lines == nil then
    return nil
  end
  return vim.fn.sha256(table.concat(lines, "\n"))
end

--- Enumerate every leaf (source_path, target_path, rel_path, entry_name) a manifest category
--- declares, driven entirely by `loader.CATEGORY_DESCRIPTORS` -- Phase 2's single source of
--- truth for how each `provides.*` category maps declared entries to deployed paths. Mirrors
--- `loader.copy_category`'s own traversal (file / dir / file_or_dir) exactly, without performing
--- any copy, so a future category (or a non-core extension declaring one of the 11 existing
--- categories) is covered by construction rather than by a second hand-maintained list.
--- @param category string A key of `loader.CATEGORY_DESCRIPTORS` with a `list_key` (i.e. one of
---   the 11 `provides.*`-keyed categories -- excludes the `manifest`/`data` special cases)
--- @param manifest table Extension manifest
--- @param source_dir string Extension source directory
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param opts table|nil { agents_subdir } -- agents' target subdir varies by config (OpenCode)
--- @return table leaves Array of { rel_path, source_path, target_path, entry_name }
local function walk_category_leaves(category, manifest, source_dir, target_dir, opts)
  opts = opts or {}
  local leaves = {}
  local descriptor = loader_mod.CATEGORY_DESCRIPTORS[category]
  if not descriptor or not descriptor.list_key then
    return leaves
  end
  if not manifest.provides or not manifest.provides[descriptor.list_key] then
    return leaves
  end

  local target_category_name = descriptor.target_subdir
  if category == "agents" and opts.agents_subdir then
    target_category_name = opts.agents_subdir
  end
  local target_category_dir = target_category_name == "" and target_dir
    or (target_dir .. "/" .. target_category_name)
  local source_category_dir = source_dir .. "/" .. descriptor.source_subdir

  for _, entry_name in ipairs(manifest.provides[descriptor.list_key]) do
    if descriptor.entry_kind == "dir" then
      -- skills: each entry is a directory, recursively enumerated.
      local source_entry_dir = source_category_dir .. "/" .. entry_name
      local target_entry_dir = target_category_dir .. "/" .. entry_name
      if vim.fn.isdirectory(source_entry_dir) == 1 then
        for _, file_rel in ipairs(scan_directory_recursive(source_entry_dir)) do
          table.insert(leaves, {
            rel_path = target_category_name .. "/" .. entry_name .. "/" .. file_rel,
            source_path = source_entry_dir .. "/" .. file_rel,
            target_path = target_entry_dir .. "/" .. file_rel,
            entry_name = entry_name,
          })
        end
      end
    elseif descriptor.entry_kind == "file_or_dir" then
      -- context/docs: an entry may itself be a directory or a flat file.
      local source_entry_path = source_category_dir .. "/" .. entry_name
      local target_entry_path = target_category_dir .. "/" .. entry_name
      if vim.fn.isdirectory(source_entry_path) == 1 then
        for _, file_rel in ipairs(scan_directory_recursive(source_entry_path)) do
          table.insert(leaves, {
            rel_path = target_category_name .. "/" .. entry_name .. "/" .. file_rel,
            source_path = source_entry_path .. "/" .. file_rel,
            target_path = target_entry_path .. "/" .. file_rel,
            entry_name = entry_name,
          })
        end
      elseif vim.fn.filereadable(source_entry_path) == 1 then
        table.insert(leaves, {
          rel_path = target_category_name .. "/" .. entry_name,
          source_path = source_entry_path,
          target_path = target_entry_path,
          entry_name = entry_name,
        })
      end
    else
      -- "file": flat per-entry (agents/commands/rules/scripts/hooks/systemd/templates/
      -- root_files). rel_path for root_files (target_category_name == "") is the bare
      -- filename, matching loader.copy_category's own rel_path construction exactly.
      local rel_path = target_category_name == "" and entry_name or (target_category_name .. "/" .. entry_name)
      table.insert(leaves, {
        rel_path = rel_path,
        source_path = source_category_dir .. "/" .. entry_name,
        target_path = target_category_dir .. "/" .. entry_name,
        entry_name = entry_name,
      })
    end
  end

  return leaves
end

--- Resolve, for every deployed leaf declared by two or more of the given active extensions, which
--- one actually owns it at deploy time -- i.e. which declarer's copy is the one really on disk
--- after `loader.copy_file`'s unconditional overwrite. `extensions` MUST already be in deploy
--- order (the same dependency-topological order `manager.compute_deploy_order` produces); this
--- function contains no ordering logic of its own and simply lets a later entry's declaration of
--- a `rel_path` overwrite an earlier one's, mirroring `copy_file`'s own last-write-wins semantics
--- exactly.
---
--- Resolution is strictly per leaf `rel_path`, never per manifest directory entry: a file core
--- ships under `contracts/` that lean does not ship stays core-owned even though the `contracts`
--- directory entry itself is declared by both manifests (lean's declaration simply never
--- produces that particular leaf).
---
--- A leaf whose `source_path` is not actually readable is never recorded, so a
--- declared-but-absent source can never claim ownership away from an extension that really ships
--- the file.
---
--- Covers the same category set the hash check covers -- every `loader.CATEGORY_DESCRIPTORS`
--- entry with a `list_key`, excluding `data` (project-root target, out of scope for this
--- deploy-tree walk) -- driven off that single source of truth exactly as `walk_category_leaves`
--- and `M.find_orphans` already are, so a future category is covered by construction.
--- @param extensions table Array of { name, source_dir, manifest } in DEPLOY ORDER (earliest
---   first, i.e. `manager.compute_deploy_order`'s return value)
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param opts table|nil { agents_subdir } -- agents' target subdir varies by config (OpenCode)
--- @return table map { [rel_path] = { owner = extension_name, source_path = string } }
function M.build_ownership_map(extensions, target_dir, opts)
  opts = opts or {}
  local map = {}
  for _, ext in ipairs(extensions) do
    if ext.manifest then
      for category, descriptor in pairs(loader_mod.CATEGORY_DESCRIPTORS) do
        if descriptor.list_key and category ~= "data" then
          for _, leaf in ipairs(walk_category_leaves(category, ext.manifest, ext.source_dir, target_dir, opts)) do
            if vim.fn.filereadable(leaf.source_path) == 1 then
              map[leaf.rel_path] = { owner = ext.name, source_path = leaf.source_path }
            end
          end
        end
      end
    end
  end
  return map
end

--- Verify one manifest-declared category for declared-vs-deployed parity (presence) plus
--- content-hash equality, driven entirely by `walk_category_leaves` above.
---
--- Exemptions:
---   - Install-once entries (root_files' settings.json/settings.local.json) are exempt from
---     hash equality: a target repo is expected to customize them, and a deployed copy
---     diverging from the source-store version is by design, not a finding.
---   - `.syncprotect`-listed paths are exempt from BOTH presence and hash checks: a protected
---     path is deliberately never overwritten by the copy engine, so a stale or customized
---     deployed copy is expected there too.
---   - Cross-extension non-owner: when `opts.ownership` resolves a leaf's owner to an extension
---     OTHER than `opts.extension_name`, the hash comparison is skipped (that leaf's deployed
---     content is correctly compared against the owner's copy when the owner itself is verified,
---     not against this non-owner's). The suppressed declaration is reported in
---     `result.overridden`, never silently dropped and never treated as an error. Omitting
---     `opts.ownership`, or a leaf with no recorded owner, preserves today's exact behavior --
---     the owner is always compared, with "owner" defaulting to "whoever declares it" when no
---     ownership map is supplied.
---
--- `file_hash` itself is not modified by this: ownership resolution only changes which source
--- file's hash the comparison reads from; `file_hash`'s line-joined hashing semantics (see its
--- own doc comment) remain the sole hashing contract.
--- @param category string
--- @param manifest table
--- @param source_dir string
--- @param target_dir string
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}
--- @param opts table|nil { agents_subdir, ownership = map|nil, extension_name = string|nil }
--- @return table result { checked, missing = {rel_path,...}, hash_mismatch = {rel_path,...},
---   protected = {rel_path,...}, overridden = {{rel_path=, owner=},...} }
local function verify_manifest_category(category, manifest, source_dir, target_dir, protected_paths, opts)
  protected_paths = protected_paths or {}
  opts = opts or {}
  local descriptor = loader_mod.CATEGORY_DESCRIPTORS[category]
  local result = { checked = 0, missing = {}, hash_mismatch = {}, protected = {}, overridden = {} }

  for _, leaf in ipairs(walk_category_leaves(category, manifest, source_dir, target_dir, opts)) do
    result.checked = result.checked + 1
    if protected_paths[leaf.rel_path] then
      table.insert(result.protected, leaf.rel_path)
    elseif not file_exists(leaf.target_path) then
      table.insert(result.missing, leaf.rel_path)
    else
      -- Owner-gating site: ownership resolution changes only WHICH source the hash comparison
      -- below reads from (this extension's own vs. skipped entirely in favor of the owner's own
      -- verification pass) -- it never touches `file_hash` itself, whose line-joined semantics
      -- remain the sole hashing contract (see `file_hash`'s own doc comment).
      local owned_by = opts.ownership and opts.ownership[leaf.rel_path]
      if owned_by and opts.extension_name and owned_by.owner ~= opts.extension_name then
        table.insert(result.overridden, { rel_path = leaf.rel_path, owner = owned_by.owner })
      else
        local install_once_exempt = descriptor and descriptor.install_once
          and descriptor.install_once[leaf.entry_name]
        if not install_once_exempt then
          local source_hash = file_hash(leaf.source_path)
          local target_hash = file_hash(leaf.target_path)
          if source_hash and target_hash and source_hash ~= target_hash then
            table.insert(result.hash_mismatch, leaf.rel_path)
          end
        end
      end
    end
  end

  return result
end

-- Exposed for the scratch-tree regression harness / direct inspection outside verify_extension's
-- aggregate report.
M.verify_manifest_category = verify_manifest_category

--- Verify all agent files referenced by extension skills exist
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param config table Extension system configuration
--- @return table results Verification results with missing_agents array
local function verify_agents(manifest, target_dir, config)
  local results = {
    checked = 0,
    missing = {},
  }

  if not manifest.provides or not manifest.provides.agents then
    return results
  end

  -- Determine agent directory location
  local agents_dir = target_dir .. "/" .. (config.agents_subdir or "agents")

  for _, agent_name in ipairs(manifest.provides.agents) do
    results.checked = results.checked + 1
    local agent_path = agents_dir .. "/" .. agent_name
    if not file_exists(agent_path) then
      table.insert(results.missing, agent_name)
    end
  end

  return results
end

--- Verify all skill directories exist
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory
--- @return table results Verification results
local function verify_skills(manifest, target_dir)
  local results = {
    checked = 0,
    missing = {},
  }

  if not manifest.provides or not manifest.provides.skills then
    return results
  end

  local skills_dir = target_dir .. "/skills"

  for _, skill_name in ipairs(manifest.provides.skills) do
    results.checked = results.checked + 1
    local skill_path = skills_dir .. "/" .. skill_name
    if not dir_exists(skill_path) then
      table.insert(results.missing, skill_name)
    end
  end

  return results
end

--- Verify all rule files exist
--- @param manifest table Extension manifest
--- @param target_dir string Target base directory
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}
--- @return table results Verification results
local function verify_rules(manifest, target_dir, protected_paths)
  protected_paths = protected_paths or {}
  local results = {
    checked = 0,
    missing = {},
    protected = {},
  }

  if not manifest.provides or not manifest.provides.rules then
    return results
  end

  local rules_dir = target_dir .. "/rules"

  for _, rule_name in ipairs(manifest.provides.rules) do
    results.checked = results.checked + 1
    local rule_path = rules_dir .. "/" .. rule_name
    if protected_paths["rules/" .. rule_name] then
      table.insert(results.protected, rule_name)
    elseif not file_exists(rule_path) then
      table.insert(results.missing, rule_name)
    end
  end

  return results
end

--- Verify context files referenced in extension index-entries.json exist
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}
--- @return table results Verification results
local function verify_context(extension_dir, target_dir, protected_paths)
  protected_paths = protected_paths or {}
  local results = {
    checked = 0,
    missing = {},
    protected = {},
  }

  local index_path = extension_dir .. "/index-entries.json"
  local index_data = read_json(index_path)

  if not index_data or not index_data.entries then
    return results
  end

  local context_dir = target_dir .. "/context"

  for _, entry in ipairs(index_data.entries) do
    results.checked = results.checked + 1
    local normalized_path = normalize_index_path(entry.path)
    local context_path = context_dir .. "/" .. normalized_path
    if protected_paths["context/" .. normalized_path] then
      table.insert(results.protected, entry.path)
    elseif not file_exists(context_path) then
      table.insert(results.missing, entry.path)
    end
  end

  return results
end

--- Verify extension content was included in the generated CLAUDE.md/OPENCODE.md/AGENTS.md
--- CLAUDE.md is a computed artifact (generated by generate_claudemd), so we check for
--- the presence of the extension's source fragment content rather than section markers.
--- @param extension_name string Extension name
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory
--- @param config table Extension system configuration
--- @param manifest table|nil Extension manifest (used to find actual merge target)
--- @return boolean injected True if extension content is present
local function verify_section_injection(extension_name, extension_dir, target_dir, config, manifest)
  local merge_key = config.merge_target_key

  -- Find the merge target declaration for this extension
  if not manifest or not merge_key or not manifest.merge_targets or not manifest.merge_targets[merge_key] then
    -- No merge target declared; nothing to verify
    return true
  end

  local mt = manifest.merge_targets[merge_key]

  -- Determine the target file path
  local main_md_path = target_dir .. "/../" .. mt.target

  if not file_exists(main_md_path) then
    return false
  end

  -- Read the source fragment that should have been included
  local source_path = extension_dir .. "/" .. mt.source
  if not file_exists(source_path) then
    -- Source doesn't exist; can't verify
    return true
  end

  local source_file = io.open(source_path, "r")
  if not source_file then
    return true
  end
  local source_content = source_file:read("*all")
  source_file:close()

  if not source_content or source_content == "" then
    return true
  end

  -- Extract first non-empty line from source as a fingerprint
  local fingerprint = nil
  for line in source_content:gmatch("[^\r\n]+") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      fingerprint = trimmed
      break
    end
  end

  if not fingerprint then
    return true
  end

  local target_file = io.open(main_md_path, "r")
  if not target_file then
    return false
  end
  local target_content = target_file:read("*all")
  target_file:close()

  return target_content:find(fingerprint, 1, true) ~= nil
end

--- Verify merged index.json has extension entries
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory
--- @return boolean merged True if entries were merged
local function verify_index_merge(extension_dir, target_dir)
  local ext_index_path = extension_dir .. "/index-entries.json"
  local ext_index = read_json(ext_index_path)

  if not ext_index or not ext_index.entries or #ext_index.entries == 0 then
    -- No entries to merge
    return true
  end

  local main_index_path = target_dir .. "/context/index.json"
  local main_index = read_json(main_index_path)

  if not main_index or not main_index.entries then
    return false
  end

  -- Check if at least one extension entry is in main index
  -- Normalize the extension path since merge.lua normalizes paths during append
  local first_ext_path = normalize_index_path(ext_index.entries[1].path)
  for _, entry in ipairs(main_index.entries) do
    if entry.path == first_ext_path then
      return true
    end
  end

  return false
end

--- Verify that manifest.provides.agents matches the extension's opencode-agents.json fragment
--- @param extension_dir string Extension source directory
--- @param ext_manifest table Extension manifest
--- @return table result {passed = boolean, missing_from_fragment = table, missing_from_manifest = table}
local function verify_opencode_json_merge(extension_dir, ext_manifest)
  local result = {
    passed = true,
    missing_from_fragment = {},
    missing_from_manifest = {},
  }

  if not ext_manifest.provides or not ext_manifest.provides.agents then
    return result
  end

  -- Read opencode-agents.json fragment
  local agents_json_path = extension_dir .. "/opencode-agents.json"
  local fragment = read_json(agents_json_path)

  -- Extract agent names from fragment (handle both {agent = {...}} and bare {...} formats)
  local fragment_agent_names = {}
  if fragment then
    local source_agents = fragment.agent or (type(fragment) == "table" and not vim.isarray(fragment) and fragment) or {}
    for name, _ in pairs(source_agents) do
      table.insert(fragment_agent_names, name)
    end
  end

  -- Extract agent names from manifest.provides.agents by stripping "-agent.md" suffixes
  local manifest_agent_names = {}
  for _, agent_file in ipairs(ext_manifest.provides.agents) do
    local agent_name = agent_file:gsub("%-agent%.md$", "")
    table.insert(manifest_agent_names, agent_name)
  end

  -- Build sets for symmetric difference
  local fragment_set = {}
  for _, name in ipairs(fragment_agent_names) do
    fragment_set[name] = true
  end
  local manifest_set = {}
  for _, name in ipairs(manifest_agent_names) do
    manifest_set[name] = true
  end

  -- Agents in manifest but not in fragment
  for _, name in ipairs(manifest_agent_names) do
    if not fragment_set[name] then
      table.insert(result.missing_from_fragment, name)
      result.passed = false
    end
  end

  -- Agents in fragment but not in manifest
  for _, name in ipairs(fragment_agent_names) do
    if not manifest_set[name] then
      table.insert(result.missing_from_manifest, name)
      result.passed = false
    end
  end

  return result
end

--- Perform full verification of a loaded extension
--- @param extension_name string Extension name
--- @param extension_dir string Extension source directory
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param config table Extension system configuration
--- @param protected_paths table|nil Set of protected relative paths {[path] = true}; defaults to {}
--- @param opts table|nil { ownership = map|nil } -- a deploy-order-resolved cross-extension
---   ownership map (see `M.build_ownership_map`); omitting it (or passing `{}`) preserves
---   today's exact behavior -- every declared leaf is compared against ITS OWN source,
---   `overridden` stays empty, and no category's `passed`/`status` is affected by ownership.
--- @return table verification Verification report
function M.verify_extension(extension_name, extension_dir, target_dir, config, protected_paths, opts)
  protected_paths = protected_paths or {}
  opts = opts or {}
  local manifest_path = extension_dir .. "/manifest.json"
  local manifest = read_json(manifest_path)

  local verification = {
    extension = extension_name,
    status = "passed",
    agents = { passed = true },
    skills = { passed = true },
    rules = { passed = true },
    context = { passed = true },
    section = { passed = true },
    index = { passed = true },
    opencode_json = { passed = true },
    -- Populated below by the manifest-driven parity + content-hash pass; declared here upfront
    -- for a stable report shape even before that pass runs.
    commands = { passed = true },
    scripts = { passed = true },
    hooks = { passed = true },
    docs = { passed = true },
    templates = { passed = true },
    systemd = { passed = true },
    root_files = { passed = true },
    errors = {},
  }

  if not manifest then
    verification.status = "failed"
    table.insert(verification.errors, "Cannot read manifest.json")
    return verification
  end

  -- Verify manifest was copied to target
  local target_manifest_path = target_dir .. "/extensions/" .. extension_name .. "/manifest.json"
  if not file_exists(target_manifest_path) then
    verification.status = "failed"
    table.insert(verification.errors, "Missing target manifest: " .. target_manifest_path)
  end

  -- Verify agents
  local agent_results = verify_agents(manifest, target_dir, config)
  if #agent_results.missing > 0 then
    verification.agents = {
      passed = false,
      checked = agent_results.checked,
      missing = agent_results.missing,
    }
    for _, agent in ipairs(agent_results.missing) do
      table.insert(verification.errors, "Missing agent: " .. agent)
    end
  end

  -- Verify skills
  local skill_results = verify_skills(manifest, target_dir)
  if #skill_results.missing > 0 then
    verification.skills = {
      passed = false,
      checked = skill_results.checked,
      missing = skill_results.missing,
    }
    for _, skill in ipairs(skill_results.missing) do
      table.insert(verification.errors, "Missing skill: " .. skill)
    end
  end

  -- Verify rules
  local rule_results = verify_rules(manifest, target_dir, protected_paths)
  if #rule_results.missing > 0 then
    verification.rules = {
      passed = false,
      checked = rule_results.checked,
      missing = rule_results.missing,
    }
    for _, rule in ipairs(rule_results.missing) do
      table.insert(verification.errors, "Missing rule: " .. rule)
    end
  end

  -- Verify context files
  local context_results = verify_context(extension_dir, target_dir, protected_paths)
  if #context_results.missing > 0 then
    verification.context = {
      passed = false,
      checked = context_results.checked,
      missing = context_results.missing,
    }
    -- Only include first 5 missing context files to avoid verbose output
    for i, ctx in ipairs(context_results.missing) do
      if i <= 5 then
        table.insert(verification.errors, "Missing context: " .. ctx)
      elseif i == 6 then
        table.insert(verification.errors, "... and " .. (#context_results.missing - 5) .. " more missing context files")
        break
      end
    end
  end

  -- Verify extension content is present in the generated config file
  local section_ok = verify_section_injection(extension_name, extension_dir, target_dir, config, manifest)
  if not section_ok then
    verification.section = { passed = false }
    local merge_key = config.merge_target_key
    local actual_target = (manifest and merge_key and manifest.merge_targets and manifest.merge_targets[merge_key])
      and manifest.merge_targets[merge_key].target
      or config.config_file
    table.insert(verification.errors, "Section '" .. (config.section_prefix or "extension_") .. extension_name .. "' not injected into " .. actual_target)
  end

  -- Verify index merge
  local index_ok = verify_index_merge(extension_dir, target_dir)
  if not index_ok then
    verification.index = { passed = false }
    table.insert(verification.errors, "Index entries not merged into context/index.json")
  end

  -- Verify opencode.json fragment-to-manifest consistency (only for opencode targets)
  local is_opencode_target = target_dir:find("%.opencode") ~= nil
  local has_opencode_merge = manifest.merge_targets and manifest.merge_targets.opencode_json
  local opencode_json_result = is_opencode_target and has_opencode_merge and verify_opencode_json_merge(extension_dir, manifest)
  if opencode_json_result and not opencode_json_result.passed then
    verification.opencode_json = {
      passed = false,
      missing_from_fragment = opencode_json_result.missing_from_fragment,
      missing_from_manifest = opencode_json_result.missing_from_manifest,
    }
    for _, name in ipairs(opencode_json_result.missing_from_fragment) do
      table.insert(verification.errors, "Agent '" .. name .. "' in manifest but missing from opencode-agents.json")
    end
    for _, name in ipairs(opencode_json_result.missing_from_manifest) do
      table.insert(verification.errors, "Agent '" .. name .. "' in opencode-agents.json but missing from manifest")
    end
  end

  -- Content-hash equality overlay for the 4 already-covered categories above (agents/skills/
  -- rules/context): a stale deployed file can be presence-correct (the hand-written checkers
  -- above find nothing missing) while its content has drifted from the source store -- e.g. a
  -- deployed skill definition edited or left behind by a prior partial sync. This does not
  -- duplicate the missing-detection above (that stays driven by the hand-written checkers, whose
  -- `context` variant reads the richer index-entries.json source); it only adds a hash_mismatch
  -- field alongside each category's existing report when content differs.
  local hash_only_categories = { "agents", "skills", "rules", "context" }
  for _, category in ipairs(hash_only_categories) do
    local cat_result = verify_manifest_category(
      category, manifest, extension_dir, target_dir, protected_paths,
      { agents_subdir = config.agents_subdir, ownership = opts.ownership, extension_name = extension_name }
    )
    if #cat_result.hash_mismatch > 0 then
      verification[category].passed = false
      verification[category].hash_mismatch = cat_result.hash_mismatch
      for _, rel in ipairs(cat_result.hash_mismatch) do
        table.insert(verification.errors, "Content differs from source: " .. rel)
      end
    end
    if #cat_result.overridden > 0 then
      verification[category].overridden = cat_result.overridden
    end
  end

  -- Full declared-vs-deployed parity plus content-hash equality for the 7 previously-uncovered
  -- categories, driven by loader.CATEGORY_DESCRIPTORS (Phase 2's single source of truth) rather
  -- than a hand-maintained list, so a future category -- or one a non-core extension declares --
  -- is covered by construction.
  local uncovered_categories = { "commands", "scripts", "hooks", "docs", "templates", "systemd", "root_files" }
  for _, category in ipairs(uncovered_categories) do
    local cat_result = verify_manifest_category(
      category, manifest, extension_dir, target_dir, protected_paths,
      { ownership = opts.ownership, extension_name = extension_name }
    )
    verification[category] = { passed = true, checked = cat_result.checked }
    if #cat_result.missing > 0 then
      verification[category].passed = false
      verification[category].missing = cat_result.missing
      -- Cap detail to the first 5 entries, matching the context checker's convention above, to
      -- avoid a verbose errors[] list on a broad drift.
      for i, rel in ipairs(cat_result.missing) do
        if i <= 5 then
          table.insert(verification.errors, "Missing " .. category .. ": " .. rel)
        elseif i == 6 then
          table.insert(verification.errors, "... and " .. (#cat_result.missing - 5) .. " more missing " .. category .. " files")
          break
        end
      end
    end
    if #cat_result.hash_mismatch > 0 then
      verification[category].passed = false
      verification[category].hash_mismatch = cat_result.hash_mismatch
      for i, rel in ipairs(cat_result.hash_mismatch) do
        if i <= 5 then
          table.insert(verification.errors, "Content differs from source: " .. rel)
        elseif i == 6 then
          table.insert(verification.errors, "... and " .. (#cat_result.hash_mismatch - 5) .. " more content differences in " .. category)
          break
        end
      end
    end
    if #cat_result.overridden > 0 then
      verification[category].overridden = cat_result.overridden
    end
  end

  -- Determine overall status
  if #verification.errors > 0 then
    verification.status = "warnings"
  end

  -- Critical failures change status to failed
  if not verification.agents.passed or not verification.skills.passed then
    verification.status = "failed"
  end

  return verification
end

-- ─────────────────────────────────────────────────────────────────────────────────────────────
-- Whole-tree orphan detection (reverse direction from verify_extension above).
--
-- verify_extension (and the manifest-category checks it drives) only ever verify declared ->
-- deployed: for each entry a manifest declares, is it present and hash-identical? A file that
-- loses its source-store owner (deleted from agent-system/extensions/** without a corresponding
-- deploy-tree cleanup) is invisible to that direction forever, because the copy engine
-- (loader.copy_category) is additive-only by design and never deletes on its own.
-- M.find_orphans below answers the reverse question: what is present in the deployed tree that
-- NO active extension declares? DETECTION ONLY -- this function never deletes anything, and the
-- additive-only copy/merge semantics are deliberately preserved regardless of what it finds. See
-- context/patterns/deploy-orphan-detection.md for the full exclusion contract (the classes
-- checked below), the measurement recipe used to derive it, and the direction decision.
-- ─────────────────────────────────────────────────────────────────────────────────────────────

--- Runtime artifacts: created or populated at execution time (hooks, scripts, provisioning),
--- never by the copy engine, so they cannot be part of any declared set by construction.
--- @param rel string Deploy-tree-relative path
--- @return boolean
local function is_runtime_artifact(rel)
  if rel:match("^tmp/workflow%-active%-") then
    return true
  end
  if rel == "RESUME.md" then
    return true
  end
  -- session-acquired lock written by the scheduled-task mechanism at execution time
  -- (contents: sessionId, pid, acquiredAt) -- never by the copy engine.
  if rel == "scheduled_tasks.lock" then
    return true
  end
  if rel:match("__pycache__/") or rel:match("%.pyc$") then
    return true
  end
  -- literature extension's Python virtualenv, provisioned on first use by the declared script
  -- literature-pyenv-provision.sh itself -- the venv's own contents are never declared.
  if rel:match("^scripts/literature%-pyenv/venv/") then
    return true
  end
  return false
end

-- Merged/generated artifacts: assembled by the merge/index pipeline from every active
-- extension's fragments rather than copied file-for-file from a single source, so comparing
-- against any one extension's declared set is a category error, not a drift.
local MERGED_GENERATED_PATHS = {
  ["context/index.json"] = true,
  ["CLAUDE.md"] = true,
  ["settings.json"] = true,
  ["settings.local.json"] = true,
}

--- @param rel string Deploy-tree-relative path
--- @return boolean
local function is_merged_generated(rel)
  if MERGED_GENERATED_PATHS[rel] then
    return true
  end
  -- opencode targets only: extensions/{name}/opencode-agents.json is assembled from the
  -- manifest's agents list, not copied from a source file of the same name.
  if rel:match("^extensions/[^/]+/opencode%-agents%.json$") then
    return true
  end
  return false
end

--- Whole-tree, all-extensions orphan detection. The declared set is the UNION across every
--- extension in `extensions` -- computed once, not per-extension -- because one extension's
--- undeclared file is routinely another extension's declared file; per-extension detection would
--- be incorrect by construction. Reuses `walk_category_leaves` (Phase 2's single source of
--- truth for how each `provides.*` category maps declared entries to deployed paths) for every
--- `list_key`-bearing category, and adds the `manifest` category's special case explicitly since
--- `walk_category_leaves` skips it (no `list_key`). The `data` category is deliberately excluded:
--- its entries deploy under the project root, not `target_dir` (see
--- `loader.CATEGORY_DESCRIPTORS.data.target_is_project_root`), so it is out of scope for a
--- detector walking `target_dir` and calling `walk_category_leaves` on it would error (no
--- `target_subdir` to build a target path from).
--- @param target_dir string Target base directory (.claude or .opencode)
--- @param extensions table Array of { name, source_dir, manifest } for ALL loaded extensions
--- @param protected_paths table|nil Set of `.syncprotect`-protected relative paths {[path]=true}
--- @param opts table|nil { agents_subdir } -- agents' target subdir varies by config (OpenCode)
--- @return table result { orphans = {rel,...}, ghost_index_entries = {path,...}, checked = n,
---   excluded = { runtime_artifact = n, merged_generated = n, syncprotect_protected = n } }
function M.find_orphans(target_dir, extensions, protected_paths, opts)
  protected_paths = protected_paths or {}
  opts = opts or {}

  -- 1. Declared set: union across all extensions of every list_key category's leaves, plus the
  --    manifest special case.
  local declared = {}
  for _, ext in ipairs(extensions) do
    if ext.manifest then
      for category, descriptor in pairs(loader_mod.CATEGORY_DESCRIPTORS) do
        if descriptor.list_key and category ~= "data" then
          for _, leaf in ipairs(walk_category_leaves(category, ext.manifest, ext.source_dir, target_dir, opts)) do
            declared[leaf.rel_path] = true
          end
        end
      end
      declared["extensions/" .. ext.name .. "/manifest.json"] = true
    end
  end

  -- 2. Walk the deployed tree and subtract the declared set, classifying every remainder into
  --    an exclusion class or, failing that, an orphan.
  local deployed = scan_directory_recursive(target_dir)
  local orphans = {}
  local excluded = { runtime_artifact = 0, merged_generated = 0, syncprotect_protected = 0 }
  for _, rel in ipairs(deployed) do
    if not declared[rel] then
      if protected_paths[rel] then
        excluded.syncprotect_protected = excluded.syncprotect_protected + 1
      elseif is_runtime_artifact(rel) then
        excluded.runtime_artifact = excluded.runtime_artifact + 1
      elseif is_merged_generated(rel) then
        excluded.merged_generated = excluded.merged_generated + 1
      else
        table.insert(orphans, rel)
      end
    end
  end
  table.sort(orphans)

  -- 3. Ghost context/index.json rows: live entries whose normalized path is declared by no
  --    active extension's index-entries.json, normalized the same way merge.lua and the checks
  --    above already normalize (normalize_index_path).
  local ghost_index_entries = {}
  local live_index = read_json(target_dir .. "/context/index.json")
  if live_index then
    local live_entries = live_index.entries or live_index
    local declared_index_paths = {}
    for _, ext in ipairs(extensions) do
      local ext_index = read_json(ext.source_dir .. "/index-entries.json")
      if ext_index then
        local entries = ext_index.entries or ext_index
        for _, e in ipairs(entries) do
          if e.path then
            declared_index_paths[normalize_index_path(e.path)] = true
          end
        end
      end
    end
    for _, e in ipairs(live_entries) do
      if e.path and not declared_index_paths[normalize_index_path(e.path)] then
        table.insert(ghost_index_entries, e.path)
      end
    end
  end
  table.sort(ghost_index_entries)

  return {
    orphans = orphans,
    ghost_index_entries = ghost_index_entries,
    checked = #deployed,
    excluded = excluded,
  }
end

--- Format verification report for display
--- @param verification table Verification report
--- @return string formatted Formatted report string
function M.format_report(verification)
  local lines = {}

  local status_icon = verification.status == "passed" and "[OK]"
    or verification.status == "warnings" and "[WARN]"
    or "[FAIL]"

  table.insert(lines, string.format("%s Extension: %s", status_icon, verification.extension))

  if verification.status ~= "passed" then
    for _, err in ipairs(verification.errors) do
      table.insert(lines, "  - " .. err)
    end
  end

  return table.concat(lines, "\n")
end

--- Notify user of verification results
--- @param verification table Verification report
function M.notify_results(verification)
  local msg = M.format_report(verification)

  if verification.status == "passed" then
    vim.notify(msg, vim.log.levels.INFO, { title = "Extension Verified" })
  elseif verification.status == "warnings" then
    vim.notify(msg, vim.log.levels.WARN, { title = "Extension Warnings" })
  else
    vim.notify(msg, vim.log.levels.ERROR, { title = "Extension Verification Failed" })
  end
end

return M
