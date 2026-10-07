-- Tests for neotex.plugins.ai.shared.extensions.merge: identity-based hook dedupe
-- Run with: nvim --headless -c "PlenaryBustedFile %"
--
-- Regression coverage for the production defect: merge_hook_event_array (and
-- normalize_hook_event_array) used to decide "already present?" via vim.deep_equal on the
-- whole {type, command} hook object. When a command string changed (e.g. the CWD-relative
-- stale form rewritten to the $CLAUDE_PROJECT_DIR-prefixed fixed form), the two objects no
-- longer compared equal, so the new entry was APPENDED BESIDE the stale one rather than
-- replacing it -- confirmed in production against a real already-deployed repo
-- (/home/benjamin/Philosophy/Papers/PossibleWorlds), where a redeploy left 21 stale
-- CWD-relative registrations coexisting with 15 newly-merged fixed ones.
--
-- These specs exercise the module's PUBLIC API only (M.merge_settings), via a scratch
-- settings.json file under vim.fn.tempname(), never the real .claude/ or agent-system/ trees
-- (except where explicitly noted: the propagation test reads the real, on-disk
-- core/merge-sources/settings-hooks.json fragment -- read-only -- to assert the six hooks
-- moved into it by this same change are present and correctly shaped).

local merge = require("neotex.plugins.ai.shared.extensions.merge")

--- Read a JSON file's hooks tree back out for assertions.
local function read_target(path)
  local lines = vim.fn.readfile(path)
  return vim.json.decode(table.concat(lines, "\n"))
end

--- Write a lua table to `path` as JSON (test fixture helper).
local function write_target(path, tbl)
  vim.fn.writefile({ vim.json.encode(tbl) }, path)
end

describe("shared.extensions.merge hook identity dedupe", function()
  local scratch_dir
  local target_path

  before_each(function()
    scratch_dir = vim.fn.tempname()
    vim.fn.mkdir(scratch_dir, "p")
    target_path = scratch_dir .. "/settings.json"
  end)

  after_each(function()
    if scratch_dir and vim.fn.isdirectory(scratch_dir) == 1 then
      vim.fn.delete(scratch_dir, "rf")
    end
  end)

  it("converges a stale+fixed duplicate pair to exactly one (the fixed) entry", function()
    -- The exact observed production shape: guard-destructive-git.sh registered twice under
    -- PreToolUse/Bash, once stale (CWD-relative) and once already fixed.
    write_target(target_path, {
      hooks = {
        PreToolUse = {
          {
            matcher = "Bash",
            hooks = {
              { type = "command", command = "bash .claude/hooks/guard-destructive-git.sh" },
              {
                type = "command",
                command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh',
              },
            },
          },
        },
      },
    })

    local fragment = {
      hooks = {
        PreToolUse = {
          {
            matcher = "Bash",
            hooks = {
              {
                type = "command",
                command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh',
              },
            },
          },
        },
      },
    }

    local ok = merge.merge_settings(target_path, fragment)
    assert.is_true(ok)

    local result = read_target(target_path)
    local hooks = result.hooks.PreToolUse[1].hooks
    assert.equals(1, #hooks)
    assert.equals(
      'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh',
      hooks[1].command
    )
  end)

  it("replaces (does not append beside) an all-stale entry with the fixed one", function()
    write_target(target_path, {
      hooks = {
        PreToolUse = {
          {
            matcher = "Bash|Write|Edit",
            hooks = {
              { type = "command", command = "bash .claude/hooks/guard-git-push.sh" },
            },
          },
        },
      },
    })

    local fragment = {
      hooks = {
        PreToolUse = {
          {
            matcher = "Bash|Write|Edit",
            hooks = {
              {
                type = "command",
                command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-git-push.sh',
              },
            },
          },
        },
      },
    }

    local ok = merge.merge_settings(target_path, fragment)
    assert.is_true(ok)

    local result = read_target(target_path)
    local hooks = result.hooks.PreToolUse[1].hooks
    assert.equals(1, #hooks)
    assert.equals(
      'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-git-push.sh',
      hooks[1].command
    )
  end)

  it("is idempotent: an already-correct entry is untouched on repeat merge", function()
    local fixed_cmd = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-git-push.sh'
    write_target(target_path, {
      hooks = {
        PreToolUse = {
          { matcher = "Bash|Write|Edit", hooks = { { type = "command", command = fixed_cmd } } },
        },
      },
    })

    local fragment = {
      hooks = {
        PreToolUse = {
          { matcher = "Bash|Write|Edit", hooks = { { type = "command", command = fixed_cmd } } },
        },
      },
    }

    local ok1 = merge.merge_settings(target_path, fragment)
    assert.is_true(ok1)
    local after_first = read_target(target_path)

    local ok2 = merge.merge_settings(target_path, fragment)
    assert.is_true(ok2)
    local after_second = read_target(target_path)

    assert.equals(1, #after_first.hooks.PreToolUse[1].hooks)
    assert.same(after_first, after_second)
  end)

  it(
    "collapses a stale+fixed duplicate ALREADY SITTING in the target even when the fragment "
      .. "does not touch that hook (normalize_hook_event_array's own dedup)",
    function()
      -- Two separate matcher blocks sharing the SAME matcher string, each holding one half of
      -- the duplicate -- the defensive case normalize_hook_event_array (not
      -- merge_hook_event_array) is responsible for collapsing.
      write_target(target_path, {
        hooks = {
          Stop = {
            {
              matcher = "*",
              hooks = { { type = "command", command = "bash .claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'" } },
            },
            {
              matcher = "*",
              hooks = {
                {
                  type = "command",
                  command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo \'{}\'',
                },
              },
            },
          },
        },
      })

      -- Fragment's Stop block must be a NON-EMPTY hook-event array for
      -- is_hook_event_array() to route this key through the hook-merge branch at all (an
      -- empty array fails that predicate and falls through to the plain-array branch, which
      -- never calls normalize_hook_event_array). Giving it the SAME hook the target already
      -- has (in its fixed form) means merge_hook_event_array itself is a no-op here, isolating
      -- normalize_hook_event_array as the sole mechanism this assertion is testing.
      local fragment = {
        hooks = {
          Stop = {
            {
              matcher = "*",
              hooks = {
                {
                  type = "command",
                  command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo \'{}\'',
                },
              },
            },
          },
        },
      }

      local ok = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      local result = read_target(target_path)
      -- One matcher block (both "*" blocks collapsed into one by normalize), one hook (the
      -- stale+fixed pair collapsed to the fixed one).
      assert.equals(1, #result.hooks.Stop)
      assert.equals(1, #result.hooks.Stop[1].hooks)
      assert.equals(
        'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo \'{}\'',
        result.hooks.Stop[1].hooks[1].command
      )
    end
  )

  it(
    "NEVER touches a hand-written hook whose command does not invoke a .claude/hooks/*.sh path "
      .. "(the mandatory custom-hook carve-out)",
    function()
      local custom_cmd = "bash /opt/mytools/my-custom-hook.sh --flag value"
      write_target(target_path, {
        hooks = {
          PreToolUse = {
            { matcher = "Bash", hooks = { { type = "command", command = custom_cmd } } },
          },
        },
      })

      -- Fragment contributes a DIFFERENT custom (non-hooks-dir) command under the SAME matcher.
      -- Since neither is identity-eligible, both must simply coexist (exact vim.deep_equal
      -- fallback), exactly as before this change -- never collapsed, never replaced.
      local other_custom_cmd = "bash /opt/mytools/another-custom-hook.sh"
      local fragment = {
        hooks = {
          PreToolUse = {
            { matcher = "Bash", hooks = { { type = "command", command = other_custom_cmd } } },
          },
        },
      }

      local ok = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      local result = read_target(target_path)
      local hooks = result.hooks.PreToolUse[1].hooks
      assert.equals(2, #hooks)
      local commands = { hooks[1].command, hooks[2].command }
      table.sort(commands)
      local expected = { custom_cmd, other_custom_cmd }
      table.sort(expected)
      assert.same(expected, commands)
    end
  )

  it(
    "the six hooks moved into core/merge-sources/settings-hooks.json are present there and "
      .. "propagate into a target via an ordinary merge_settings call",
    function()
      -- Reads the REAL, on-disk fragment file (read-only) -- this is exactly the file
      -- process_merge_targets() reads and merges for the "core" extension on every resync.
      local fragment_path = vim.fn.getcwd()
        .. "/agent-system/extensions/core/merge-sources/settings-hooks.json"
      assert.equals(1, vim.fn.filereadable(fragment_path), "fragment file must exist on disk")
      local fragment_lines = vim.fn.readfile(fragment_path)
      local fragment = vim.json.decode(table.concat(fragment_lines, "\n"))

      write_target(target_path, { hooks = {} })

      local ok = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      local result = read_target(target_path)
      local all_commands = {}
      for _, event_array in pairs(result.hooks) do
        for _, block in ipairs(event_array) do
          for _, hook in ipairs(block.hooks) do
            table.insert(all_commands, hook.command)
          end
        end
      end
      local joined = table.concat(all_commands, "\n")

      local moved_hooks = {
        "log%-session%.sh",
        "memory%-nudge%.sh",
        "post%-command%.sh",
        "subagent%-postflight%.sh",
        "tts%-notify%.sh",
        "validate%-plan%-write%.sh",
      }
      for _, pattern in ipairs(moved_hooks) do
        assert.truthy(
          joined:match(pattern),
          "expected moved hook matching " .. pattern .. " to propagate into target"
        )
      end

      -- Zero CWD-relative registrations anywhere in the propagated result.
      assert.is_nil(joined:match("bash %.claude/hooks/"))
    end
  )

  it(
    "converges a reconstruction of the REAL observed production duplicate shape "
      .. "(guard-destructive-git.sh and guard-git-push.sh each stale+fixed, "
      .. "events-log-lifecycle.sh stale twice across Stop and SubagentStop) via the real core "
      .. "fragment, with zero CWD-relative survivors and no duplicates",
    function()
      -- NOTE: this reconstructs the duplicate shape from the operator's own reported counts
      -- against /home/benjamin/Philosophy/Papers/PossibleWorlds ("21 stale CWD-relative
      -- entries across 19 distinct hooks alongside 15 correct ones ... guard-destructive-git.sh
      -- at lines 142/147 and guard-git-push.sh at lines 168/173 ... events-log-lifecycle.sh
      -- appears stale twice"). The settings.json.bak this was meant to be copied from was not
      -- present on disk at verification time (confirmed absent by this agent); this fixture is
      -- a faithful reconstruction from the reported evidence, not the genuine file.
      write_target(target_path, {
        hooks = {
          PreToolUse = {
            {
              matcher = "Bash",
              hooks = {
                { type = "command", command = "bash .claude/hooks/guard-destructive-git.sh" },
                {
                  type = "command",
                  command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh',
                },
              },
            },
            {
              matcher = "Bash|Write|Edit",
              hooks = {
                { type = "command", command = "bash .claude/hooks/guard-git-push.sh" },
                {
                  type = "command",
                  command = 'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-git-push.sh',
                },
              },
            },
          },
          Stop = {
            {
              matcher = "*",
              hooks = {
                { type = "command", command = "bash .claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'" },
              },
            },
          },
          SubagentStop = {
            {
              matcher = "*",
              hooks = {
                { type = "command", command = "bash .claude/hooks/events-log-lifecycle.sh 2>/dev/null || echo '{}'" },
              },
            },
          },
        },
      })

      local before = read_target(target_path)
      local before_text = vim.json.encode(before)
      local _, before_stale_count = before_text:gsub("bash %.claude/hooks/", "")

      local fragment_path = vim.fn.getcwd()
        .. "/agent-system/extensions/core/merge-sources/settings-hooks.json"
      local fragment_lines = vim.fn.readfile(fragment_path)
      local fragment = vim.json.decode(table.concat(fragment_lines, "\n"))

      local ok = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      local result = read_target(target_path)
      local after_text = vim.json.encode(result)
      local _, after_stale_count = after_text:gsub("bash %.claude/hooks/", "")

      assert.is_true(before_stale_count > 0, "fixture must start with stale entries")
      assert.equals(0, after_stale_count)

      -- No duplicates: every (matcher, hook-script-identity) pair in the result appears once.
      local seen = {}
      local dup_found = nil
      for event_name, event_array in pairs(result.hooks) do
        for _, block in ipairs(event_array) do
          for _, hook in ipairs(block.hooks) do
            local name = hook.command:match("%.claude/hooks/([%w_%-]+%.sh)")
            if name then
              local key = event_name .. ":" .. block.matcher .. ":" .. name
              if seen[key] then
                dup_found = key
              end
              seen[key] = true
            end
          end
        end
      end
      assert.is_nil(dup_found, "expected no duplicate (event,matcher,hook) triples")

      -- The two documented paired hooks each converge to exactly one entry.
      assert.equals(1, #result.hooks.PreToolUse[1].hooks)
      assert.equals(1, #result.hooks.PreToolUse[2].hooks)
    end
  )
end)
