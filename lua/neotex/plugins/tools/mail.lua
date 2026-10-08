-----------------------------------------------------------
-- Email Integration for Neovim
--
-- Provides keybindings for email workflow integration:
-- - Open aerc in toggleterm floating window
-- - Background mail sync through the mail-sync wrapper
-- - notmuch search from within Neovim
--
-- This module works alongside the existing himalaya plugin
-- for a comprehensive email workflow.
--
-- Architecture:
--   - Launch gate: <leader>me runs a foreground, hook-free index reconcile
--     (`notmuch new --no-hooks`, ~0.2 s) and opens aerc as soon as it
--     completes. The gate never consults server-sync health.
--   - Sync pipeline: ALL server syncing routes through one backgrounded,
--     deduplicated, hook-ful `notmuch new` run. Its preNew hook invokes the
--     `mail-sync both` wrapper (the single sanctioned sync entry point;
--     this module never invokes an IMAP sync binary directly), and its
--     postNew hook retags freshly indexed `tag:new` mail. Pipeline failures
--     surface as warnings and never block the client.
--
-- Keybindings:
--   <leader>me - Open aerc email client (fast index reconcile, then quiet
--                background sync of all accounts)
--   <leader>mN - Sync all accounts (mail-sync both + notmuch, loud)
--   <leader>mn - Search mail with notmuch (telescope)
--
-- Note: the <leader>m* prefix is shared with the himalaya plugin (see
-- neotex/plugins/editor/which-key.lua). aerc/notmuch bindings use e/n/N to
-- avoid colliding with himalaya's f (change folder) and S (full sync).
--
-- Dependencies:
--   - aerc (terminal email client)
--   - notmuch (email indexer; its preNew hook runs `mail-sync both`)
--   - toggleterm.nvim (terminal integration)
-----------------------------------------------------------

-- Reconcile the notmuch index with the maildir on disk, without running any
-- pre/post hooks (so no server sync is triggered). This is the launch gate:
-- it completes in ~0.2 s on a settled maildir and reports success to
-- cb(boolean). Files first indexed here carry only tag:new until the
-- background hook-ful pass retags them (safety-neutral; see background
-- pipeline notes).
local function reconcile_index(cb)
  vim.fn.jobstart({ "notmuch", "new", "--no-hooks" }, {
    on_exit = function(_, code)
      cb(code == 0)
    end,
  })
end

-- Guard so repeated presses of <leader>me / <leader>mN never stack sync
-- pipelines: only one background run at a time, per Neovim instance.
local sync_in_flight = false

-- The single background sync pipeline, shared by <leader>me (quiet) and
-- <leader>mN (loud). Hook-ful `notmuch new` IS the pipeline: its preNew hook
-- runs `mail-sync both` (the canonical, flock-serialized wrapper for both
-- accounts), and its postNew hook retags any `tag:new` mail -- including
-- files first indexed by the hook-free launch gate. Failure semantics are
-- warn-never-block: aerc (if open) keeps reading a consistent index, and a
-- non-zero exit means the SYNC was unclean, not the index.
local function background_sync(loud)
  if sync_in_flight then
    if loud then
      vim.notify("Mail sync already running", vim.log.levels.INFO)
    end
    return
  end
  sync_in_flight = true
  if loud then
    vim.notify("Syncing all accounts (mail-sync both + notmuch)...", vim.log.levels.INFO)
  end
  vim.fn.jobstart({ "notmuch", "new" }, {
    on_exit = function(_, code)
      sync_in_flight = false
      if code == 0 then
        vim.notify("Mail sync + reindex complete", vim.log.levels.INFO)
      else
        vim.notify(
          "Background mail sync did not complete cleanly (exit " .. code .. "). "
            .. "aerc is unaffected and the notmuch index remains consistent. "
            .. "Inspect `mail-sync` output or retry with <leader>mN.",
          vim.log.levels.WARN
        )
      end
    end,
  })
end

return {
  -- Toggleterm for aerc integration
  {
    "akinsho/toggleterm.nvim",
    keys = {
      {
        "<leader>me",
        function()
          local Terminal = require("toggleterm.terminal").Terminal
          local function open_aerc()
            local aerc = Terminal:new({
              cmd = "aerc",
              direction = "float",
              float_opts = {
                border = "curved",
                width = function()
                  return math.floor(vim.o.columns * 0.9)
                end,
                height = function()
                  return math.floor(vim.o.lines * 0.85)
                end,
              },
              on_open = function(term)
                vim.cmd("startinsert!")
                -- Close with q in normal mode
                vim.keymap.set("n", "q", function()
                  term:close()
                end, { buffer = term.bufnr, noremap = true, silent = true, desc = "Close mail terminal" })
              end,
            })
            aerc:toggle()
          end

          -- Launch barrier (decision record:
          -- ~/Mail/.claude/context/project/email/domain/index-architecture.md).
          -- The gate marker is "foreground index reconcile completed": a
          -- hook-free `notmuch new --no-hooks` run to completion before aerc
          -- opens. That is exactly the invariant aerc needs -- a notmuch index
          -- reconciled with the maildir on disk (Xapian reader-vs-writer
          -- serialization makes mid-reindex reads unsafe, so the reconcile is
          -- foreground and completes first).
          -- The gate is explicitly DECOUPLED from server-sync health: it never
          -- consults sync exit codes and never shells out to external
          -- freshness checkers. Those signals can be permanently wedged by
          -- faults orthogonal to read-safety (e.g. a duplicate-UID collision
          -- on one channel, or a false-STALE freshness reading), and a launch
          -- gate keyed to them refuses the client forever while the index
          -- itself is perfectly readable.
          -- Server syncing happens after the open, in the background pipeline.
          --
          -- Lock semantics (verified empirically): if another writer holds the
          -- notmuch write lock, `notmuch new` WAITS for it rather than exiting
          -- non-zero -- the gate then opens aerc as soon as the writer
          -- finishes. The background pipeline does NOT hold the lock during
          -- its long preNew (mail-sync) phase, only during its brief indexing
          -- phase, so waits are sub-second in practice. The deferred notice
          -- below keeps a rare longer wait from being silent.
          local gate_done = false
          vim.defer_fn(function()
            if not gate_done then
              vim.notify(
                "Waiting on the notmuch index (another indexer holds the write lock). "
                  .. "aerc opens as soon as the reconcile completes.",
                vim.log.levels.INFO
              )
            end
          end, 2000)
          reconcile_index(function(ok)
            gate_done = true
            if not ok then
              vim.notify(
                "aerc launch deferred: notmuch reindex failed (another indexer may be mid-write). "
                  .. "Retry <leader>me in a moment.",
                vim.log.levels.WARN
              )
              return
            end
            open_aerc()
            background_sync(false)
          end)
        end,
        desc = "Open aerc email client (fast index reconcile, sync in background)",
      },
      {
        "<leader>mN",
        function()
          background_sync(true)
        end,
        desc = "Sync all accounts (mail-sync both + notmuch)",
      },
    },
  },

  -- Telescope notmuch integration (optional)
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      {
        "<leader>mn",
        function()
          -- Simple notmuch search using Telescope's grep_string as template
          local pickers = require("telescope.pickers")
          local finders = require("telescope.finders")
          local conf = require("telescope.config").values
          local actions = require("telescope.actions")
          local action_state = require("telescope.actions.state")

          local notmuch_search = function(opts)
            opts = opts or {}
            pickers
              .new(opts, {
                prompt_title = "Notmuch Search",
                finder = finders.new_async_job({
                  command_generator = function(prompt)
                    if not prompt or prompt == "" then
                      return { "notmuch", "search", "--format=text", "tag:inbox" }
                    end
                    return { "notmuch", "search", "--format=text", prompt }
                  end,
                  entry_maker = function(entry)
                    -- Parse notmuch search output
                    -- Format: thread:XXX date subject
                    local thread_id = entry:match("^thread:([%w]+)")
                    return {
                      value = entry,
                      display = entry,
                      ordinal = entry,
                      thread_id = thread_id,
                    }
                  end,
                }),
                sorter = conf.generic_sorter(opts),
                attach_mappings = function(prompt_bufnr, map)
                  actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection and selection.thread_id then
                      -- Open aerc with the thread
                      vim.notify("Selected: " .. selection.value, vim.log.levels.INFO)
                    end
                  end)
                  return true
                end,
              })
              :find()
          end

          notmuch_search()
        end,
        desc = "Search mail with notmuch",
      },
    },
  },
}
