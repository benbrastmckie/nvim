-- Shared Typst helper: project root, main-file detection and project-wide pin state.
--
-- Single source of truth for "which document is this" across the Typst ftplugin
-- (after/ftplugin/typst.lua), typst-preview.nvim (lua/neotex/plugins/text/typst-preview.lua)
-- and the tinymist LSP integration. Main-file detection is content-aware: a chapter file
-- resolves to the root document that actually `#include`s/`#import`s it, rather than to
-- whichever root-level `.typ` file happens to sort first alphabetically.

local M = {}

-- Subdirectory names treated as "this file is a chapter, look for a container document".
local SUBDIR_NAMES = { "chapters", "sections", "parts", "includes", "content" }

-- Project-wide pin state, keyed by normalized project root.
local pins = {}

-- Last main-file value sent to each tinymist client via `pinMain`, keyed by client id.
-- Avoids re-sending the same pin on every BufEnter.
local last_sent = {}

-- Guard so `setup_autocmds()` only creates the augroup once per Neovim session, even
-- though the ftplugin file runs once per buffer.
local autocmds_ready = false

-- Per-(candidate path) cache of file content, invalidated on mtime change.
local content_cache = {}

--- Escape Lua pattern magic characters in a literal string.
---@param s string
---@return string
local function escape_pattern(s)
  return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

--- Normalize a root directory path for use as a `pins` table key.
---@param root string
---@return string
local function normalize_root(root)
  local p = vim.fn.fnamemodify(root, ":p")
  return (p:gsub("/$", ""))
end

--- Read a file's content, memoized per (path, mtime) via vim.uv.fs_stat.
---@param path string
---@return string|nil
local function read_cached(path)
  local ok_stat, stat = pcall(vim.uv.fs_stat, path)
  if not ok_stat or not stat then
    return nil
  end
  local mtime = stat.mtime.sec * 1000000000 + stat.mtime.nsec
  local cached = content_cache[path]
  if cached and cached.mtime == mtime then
    return cached.content
  end

  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    return nil
  end
  local content = table.concat(lines, "\n")
  content_cache[path] = { mtime = mtime, content = content }
  return content
end

--- Find the first (sorted) `*.typ` file in `dir` whose content `#include`s/`#import`s `rel`.
---@param dir string Directory to scan (not recursive)
---@param rel string Path of the includee, relative to `dir` (e.g. "chapters/foo.typ")
---@return string|nil
local function find_includer(dir, rel)
  local candidates = vim.fn.glob(dir .. "/*.typ", false, true)
  table.sort(candidates)

  local escaped = escape_pattern(rel)
  local include_pat = '#include%s+"' .. escaped .. '"'
  local import_pat = '#import%s+"' .. escaped .. '"'

  for _, candidate in ipairs(candidates) do
    local content = read_cached(candidate)
    if content and (content:find(include_pat) or content:find(import_pat)) then
      return candidate
    end
  end
  return nil
end

--- Walk upward from `start_dir` looking for `typst.toml` or `.git`. At each directory
--- level, `typst.toml` is checked before `.git`, so a nearer `.git` still wins over a
--- farther `typst.toml`, but a `typst.toml` found at the same level as `.git` wins.
---@param start_dir string
---@return string|nil
local function find_root_marker(start_dir)
  local dir = start_dir
  while dir and dir ~= "" do
    local toml = dir .. "/typst.toml"
    if vim.fn.filereadable(toml) == 1 then
      return dir
    end
    if vim.fn.isdirectory(dir .. "/.git") == 1 or vim.fn.filereadable(dir .. "/.git") == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end
  return nil
end

--- Resolve the project root for `path`. Always returns a string.
---
--- Priority: `TYPST_ROOT` env var, else the directory of the nearest `typst.toml` or
--- `.git` found upward from `path`'s directory, else `path`'s own directory.
---@param path string
---@return string
function M.project_root(path)
  local env_root = vim.env.TYPST_ROOT
  if env_root and env_root ~= "" then
    return env_root
  end

  local start_dir = vim.fn.fnamemodify(path, ":h")
  local marker_dir = find_root_marker(start_dir)
  if marker_dir then
    return marker_dir
  end

  return start_dir
end

--- Pin `file` as the main file for the project rooted at `root`.
---@param root string
---@param file string
function M.pin(root, file)
  pins[normalize_root(root)] = file
end

--- Clear the pin for the project rooted at `root`.
---@param root string
function M.unpin(root)
  pins[normalize_root(root)] = nil
end

--- Return the pinned main file for `root`, or nil if unpinned.
---@param root string
---@return string|nil
function M.pinned(root)
  return pins[normalize_root(root)]
end

--- Resolve the main `.typ` file for `current_file`.
---
--- Resolution order:
--- 1. The project pin, if set and readable.
--- 2. `current_file` itself, if it is not inside a recognized chapter subdirectory.
--- 3. Content-aware: the first (sorted) `.typ` file one level up that `#include`s/
---    `#import`s `current_file`.
--- 4. Name-based candidates (`main.typ`, `index.typ`, `document.typ`, `{dirname}.typ`).
--- 5. The alphabetically first `.typ` file one level up.
--- 6. `current_file` (last resort).
---@param current_file string
---@return string
function M.main_file(current_file)
  if not current_file or current_file == "" then
    return current_file
  end

  local root = M.project_root(current_file)
  local pinned = M.pinned(root)
  if pinned and vim.fn.filereadable(pinned) == 1 then
    return pinned
  end

  local current_dir = vim.fn.fnamemodify(current_file, ":h")
  local parent_name = vim.fn.fnamemodify(current_dir, ":t")
  if not vim.tbl_contains(SUBDIR_NAMES, parent_name) then
    return current_file
  end

  local parent_dir = vim.fn.fnamemodify(current_dir, ":h")
  local rel = parent_name .. "/" .. vim.fn.fnamemodify(current_file, ":t")

  local includer = find_includer(parent_dir, rel)
  if includer then
    return includer
  end

  local name_candidates = {
    parent_dir .. "/main.typ",
    parent_dir .. "/index.typ",
    parent_dir .. "/document.typ",
    parent_dir .. "/" .. vim.fn.fnamemodify(parent_dir, ":t") .. ".typ",
  }
  for _, candidate in ipairs(name_candidates) do
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end

  local typ_files = vim.fn.glob(parent_dir .. "/*.typ", false, true)
  if #typ_files > 0 then
    table.sort(typ_files)
    return typ_files[1]
  end

  return current_file
end

--- Compute the expected PDF output path for a main `.typ` file.
---@param main_file string
---@return string
function M.pdf_path(main_file)
  return vim.fn.fnamemodify(main_file, ":r") .. ".pdf"
end

--- Resolve the main file for `bufnr` and send `tinymist.pinMain` to every attached
--- `tinymist` client whose last-sent value differs, so tinymist is always pinned to the
--- resolved main file -- whether that resolution came from an explicit `pin()` or from
--- content-aware detection. Keeping tinymist pinned at all times (rather than only while
--- explicitly pinned) is what makes `exportPdf = "onSave"` export the main document's PDF
--- instead of a stray per-chapter one.
---@param bufnr integer|nil defaults to the current buffer
function M.sync_pin(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == "" then
    return
  end

  local main = M.main_file(file)

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "tinymist" })) do
    if last_sent[client.id] ~= main then
      local ok = pcall(function()
        client:exec_cmd({ command = "tinymist.pinMain", arguments = { main } }, { bufnr = bufnr })
      end)
      if ok then
        last_sent[client.id] = main
      end
    end
  end
end

--- Create the autocmds that keep tinymist's pin in sync: on `LspAttach` (so a fresh or
--- restarted tinymist client, e.g. after `:LspRestart`, is immediately pinned) and on
--- `BufEnter` of a `.typ` buffer (so switching chapters keeps the project-wide pin
--- current). Idempotent: only the first call creates the augroup.
function M.setup_autocmds()
  if autocmds_ready then
    return
  end
  autocmds_ready = true

  local group = vim.api.nvim_create_augroup("NeotexTypstPin", { clear = true })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client and client.name == "tinymist" then
        last_sent[client.id] = nil
        M.sync_pin(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*.typ",
    callback = function(args)
      M.sync_pin(args.buf)
    end,
  })
end

return M
