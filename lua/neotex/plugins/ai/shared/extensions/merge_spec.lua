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

      -- The two documented paired hooks converge into their matcher block without ANY
      -- duplicate identity -- asserted against the fragment's OWN current hook count per
      -- matcher (not a frozen literal), since the live fragment has grown new, distinct hooks
      -- under the same "Bash" matcher since this spec was first written (e.g.
      -- validate-bounded-waiter.sh, validate-task-creation-audit.sh,
      -- validate-no-python-state-write.sh) -- those are correctly appended, not duplicates.
      local function fragment_hook_count(matcher)
        for _, block in ipairs(fragment.hooks.PreToolUse) do
          if block.matcher == matcher then
            return #block.hooks
          end
        end
        return 0
      end
      assert.equals(fragment_hook_count("Bash"), #result.hooks.PreToolUse[1].hooks)
      assert.equals(fragment_hook_count("Bash|Write|Edit"), #result.hooks.PreToolUse[2].hooks)
    end
  )
end)

-- Table-driven conformance coverage for hook_identity.lua, the single normative identity
-- definition shared by merge.lua (this module) and the hook-registration-path lint (via
-- hook_identity_cli.lua). The corpus (hook_identity_fixtures.json) is the shared pin both
-- consumers are tested against -- it is a test, not the definition; the definition lives in
-- hook_identity.lua alone (acceptance criterion 3).
describe("shared.extensions.merge hook_identity conformance corpus", function()
  local hook_identity = require("neotex.plugins.ai.shared.extensions.hook_identity")

  local function fixtures_path()
    return vim.fn.getcwd() .. "/lua/neotex/plugins/ai/shared/extensions/hook_identity_fixtures.json"
  end

  it("resolves every fixture row to its expected identity", function()
    local lines = vim.fn.readfile(fixtures_path())
    local corpus = vim.json.decode(table.concat(lines, "\n"))
    assert.is_true(#corpus.rows > 0)

    local saw_null_tilde = false
    local saw_null_no_sh = false

    for _, row in ipairs(corpus.rows) do
      local got = hook_identity.identity(row.command, row.type)
      -- vim.json.decode renders JSON null as the vim.NIL sentinel, not Lua nil.
      local expected = row.expected_identity
      if expected == vim.NIL then
        expected = nil
      end
      assert.equals(expected, got, row.note)

      if expected == nil and row.command:match("^bash ~/") then
        saw_null_tilde = true
      end
      if expected == nil and not row.command:find("%.sh") then
        saw_null_no_sh = true
      end
    end

    assert.is_true(saw_null_tilde, "corpus must contain a null row for a ~/-anchored command")
    assert.is_true(saw_null_no_sh, "corpus must contain a null row for a command with no *.sh invocation")
  end)

  it("still collapses the stale/fixed anchor pair of the same hooks/ hook to one identity", function()
    local stale = hook_identity.identity("bash .claude/hooks/guard-destructive-git.sh", "command")
    local fixed = hook_identity.identity(
      'bash "$CLAUDE_PROJECT_DIR"/.claude/hooks/guard-destructive-git.sh',
      "command"
    )
    local absolute = hook_identity.identity(
      "bash /home/benjamin/.config/nvim/.claude/hooks/guard-destructive-git.sh",
      "command"
    )
    assert.equals("command:hooks/guard-destructive-git.sh", stale)
    assert.equals(stale, fixed)
    assert.equals(stale, absolute)
  end)
end)

-- Coverage for M.remove_orphaned_hook_registrations: the orphan sweep for the `settings`
-- merge target, modeled on M.remove_orphaned_index_entries. Every spec here works against a
-- scratch settings.json under vim.fn.tempname(), using a valid_set built from the REAL,
-- on-disk core fragment (merge-sources/settings-hooks.json) plus root-files/settings.json's
-- own hooks -- the same two surfaces Phase 5's init.lua valid-set builder unions for this
-- target, and the same real source the Phase 1 fixtures were captured against.
describe("shared.extensions.merge orphan sweep for hook registrations", function()
  --- Build a valid_set (M.hook_valid_set_key -> true) from a settings-shaped fixture table,
  --- exactly as the real valid-set builder would from a loaded extension's own fragment/
  --- root-files hooks block.
  local function build_valid_set(...)
    local valid_set = {}
    for _, settings in ipairs({ ... }) do
      for event, event_array in pairs(settings.hooks or {}) do
        for _, block in ipairs(event_array) do
          for _, hook in ipairs(block.hooks) do
            local identity = merge.hook_identity(hook)
            if identity then
              valid_set[merge.hook_valid_set_key(event, block.matcher, identity)] = true
            end
          end
        end
      end
    end
    return valid_set
  end

  local function read_real_fragment()
    local path = vim.fn.getcwd() .. "/agent-system/extensions/core/merge-sources/settings-hooks.json"
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end

  local function read_real_root_files()
    local path = vim.fn.getcwd() .. "/agent-system/extensions/core/root-files/settings.json"
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end

  local function read_host_fixture()
    local path = vim.fn.getcwd()
      .. "/specs/369_orphan_sweep_for_removed_merge_target_entries/records/fixtures/host-settings.json"
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end

  it(
    "removes an undeclared registration (the host repo's real CWD-relative "
      .. "'bash scripts/claude-ready-signal.sh' orphan under SessionStart|startup)",
    function()
      local target_path = vim.fn.tempname()
      local fixture = read_host_fixture()
      vim.fn.writefile({ vim.json.encode(fixture) }, target_path)

      local valid_set = build_valid_set(read_real_fragment(), read_real_root_files())
      local ok, removed_count, removed_entries = merge.remove_orphaned_hook_registrations(target_path, valid_set)
      assert.is_true(ok)
      assert.equals(1, removed_count)
      assert.equals("SessionStart", removed_entries[1].event)
      assert.equals("startup", removed_entries[1].matcher)
      assert.equals("bash scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'", removed_entries[1].hook.command)

      local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
      local result_text = vim.json.encode(result)
      assert.is_nil(result_text:find("claude%-ready%-signal", 1, false))
      vim.fn.delete(target_path)
    end
  )

  it(
    "NEVER touches a hand-written hook command that invokes no source-store script "
      .. "(acceptance criterion 2 -- the single most dangerous possible regression)",
    function()
      local target_path = vim.fn.tempname()
      vim.fn.writefile({
        vim.json.encode({
          hooks = {
            Stop = {
              {
                matcher = "*",
                hooks = {
                  { type = "command", command = "bash /opt/mytools/my-custom-hook.sh --flag value" },
                },
              },
            },
          },
        }),
      }, target_path)

      -- A valid_set that resembles NOTHING in the target -- the worst case for this carve-out.
      local valid_set = {}
      local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, valid_set)
      assert.is_true(ok)
      assert.equals(0, removed_count)

      local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
      assert.equals(
        "bash /opt/mytools/my-custom-hook.sh --flag value",
        result.hooks.Stop[1].hooks[1].command
      )
      vim.fn.delete(target_path)
    end
  )

  it("NEVER touches a ~/-anchored script registration (the mandatory carve-out)", function()
    local target_path = vim.fn.tempname()
    local command = "bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"
    vim.fn.writefile({
      vim.json.encode({
        hooks = {
          SessionStart = {
            { matcher = "startup", hooks = { { type = "command", command = command } } },
          },
        },
      }),
    }, target_path)

    local valid_set = {} -- empty: the worst case
    local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, valid_set)
    assert.is_true(ok)
    assert.equals(0, removed_count)

    local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
    assert.equals(command, result.hooks.SessionStart[1].hooks[1].command)
    vim.fn.delete(target_path)
  end)

  it(
    "cross-matcher: removes a hook registered under a matcher the source no longer declares "
      .. "it under (the widened Notification matcher drift, ModelBuilder/Logos-Website shape)",
    function()
      local target_path = vim.fn.tempname()
      local stale_command = "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      vim.fn.writefile({
        vim.json.encode({
          hooks = {
            Notification = {
              {
                matcher = "permission_prompt|idle_prompt|elicitation_dialog",
                hooks = { { type = "command", command = stale_command } },
              },
            },
          },
        }),
      }, target_path)

      -- Source declares tts-notify.sh only under the NARROWER matcher.
      local valid_set = build_valid_set({
        hooks = {
          Notification = {
            {
              matcher = "permission_prompt|elicitation_dialog",
              hooks = { { type = "command", command = stale_command } },
            },
          },
        },
      })

      local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, valid_set)
      assert.is_true(ok)
      assert.equals(1, removed_count)

      local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
      assert.is_nil(result.hooks.Notification) -- the only block under this event was pruned
      vim.fn.delete(target_path)
    end
  )

  it(
    "cross-event: removes a hook registered under an event the source no longer declares it "
      .. "under (the Logos/Theory validate-no-task-references.sh PostToolUse drift)",
    function()
      local target_path = vim.fn.tempname()
      local stale_command = "bash .claude/hooks/validate-no-task-references.sh 2>/dev/null || echo '{}'"
      vim.fn.writefile({
        vim.json.encode({
          hooks = {
            PostToolUse = {
              { matcher = "Write|Edit", hooks = { { type = "command", command = stale_command } } },
            },
          },
        }),
      }, target_path)

      -- Source declares this hook only under PreToolUse|Write|Edit.
      local valid_set = build_valid_set({
        hooks = {
          PreToolUse = {
            { matcher = "Write|Edit", hooks = { { type = "command", command = stale_command } } },
          },
        },
      })

      local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, valid_set)
      assert.is_true(ok)
      assert.equals(1, removed_count)

      local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
      assert.is_nil(result.hooks.PostToolUse)
      vim.fn.delete(target_path)
    end
  )

  it("env and permissions sub-objects are byte-identical across a sweep that removes entries", function()
    local target_path = vim.fn.tempname()
    local fixture = read_host_fixture()
    local before_env = vim.json.encode(fixture.env)
    local before_permissions = vim.json.encode(fixture.permissions)
    vim.fn.writefile({ vim.json.encode(fixture) }, target_path)

    local valid_set = build_valid_set(read_real_fragment(), read_real_root_files())
    local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, valid_set)
    assert.is_true(ok)
    assert.is_true(removed_count > 0)

    local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
    assert.equals(before_env, vim.json.encode(result.env))
    assert.equals(before_permissions, vim.json.encode(result.permissions))
    vim.fn.delete(target_path)
  end)

  it("idempotency: a second sweep over the swept result removes 0 and does not rewrite the file", function()
    local target_path = vim.fn.tempname()
    local fixture = read_host_fixture()
    vim.fn.writefile({ vim.json.encode(fixture) }, target_path)

    local valid_set = build_valid_set(read_real_fragment(), read_real_root_files())
    local ok1, removed_count1 = merge.remove_orphaned_hook_registrations(target_path, valid_set)
    assert.is_true(ok1)
    assert.is_true(removed_count1 > 0)

    local mtime_before = vim.fn.getftime(target_path)
    local ok2, removed_count2 = merge.remove_orphaned_hook_registrations(target_path, valid_set)
    assert.is_true(ok2)
    assert.equals(0, removed_count2)
    assert.equals(mtime_before, vim.fn.getftime(target_path))
    vim.fn.delete(target_path)
  end)

  it("prunes an emptied matcher block and an emptied event array in the same write", function()
    local target_path = vim.fn.tempname()
    local orphan_command = "bash .claude/hooks/zz-fully-orphaned.sh"
    vim.fn.writefile({
      vim.json.encode({
        hooks = {
          Stop = {
            { matcher = "*", hooks = { { type = "command", command = orphan_command } } },
          },
        },
      }),
    }, target_path)

    local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, {})
    assert.is_true(ok)
    assert.equals(1, removed_count)

    local result = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
    assert.is_nil(result.hooks.Stop) -- the whole event array was pruned, not left as {}
    vim.fn.delete(target_path)
  end)
end)

-- Coverage for the merge_targets.mcp mechanism: a project-scoped .mcp.json is merged and
-- unmerged through the SAME M.merge_settings/M.unmerge_settings primitive the settings path
-- already uses (see lua/neotex/plugins/ai/shared/extensions/init.lua's `mcp` branches). These
-- specs assert the four requirements the mechanism must satisfy directly against that shared
-- primitive, using the file's existing temp-path fixture conventions.
describe("shared.extensions.merge .mcp.json fragment shape", function()
  local scratch_dir
  local target_path

  before_each(function()
    scratch_dir = vim.fn.tempname()
    vim.fn.mkdir(scratch_dir, "p")
    target_path = scratch_dir .. "/.mcp.json"
  end)

  after_each(function()
    if scratch_dir and vim.fn.isdirectory(scratch_dir) == 1 then
      vim.fn.delete(scratch_dir, "rf")
    end
  end)

  it("requirement (a): a merged entry retains its explicit \"type\": \"stdio\" field verbatim", function()
    local fragment = {
      mcpServers = {
        fixture = {
          type = "stdio",
          command = "node",
          args = { "fixture-server.js" },
        },
      },
    }

    local ok = merge.merge_settings(target_path, fragment)
    assert.is_true(ok)

    local result = read_target(target_path)
    assert.equals("stdio", result.mcpServers.fixture.type)
    assert.equals("node", result.mcpServers.fixture.command)
  end)

  it("requirement (d): a hand-written mcpServers entry already in the target survives, unmodified, after the merge", function()
    write_target(target_path, {
      mcpServers = {
        ["hand-written"] = {
          type = "stdio",
          command = "my-own-server",
        },
      },
    })

    local fragment = {
      mcpServers = {
        fixture = {
          type = "stdio",
          command = "node",
          args = { "fixture-server.js" },
        },
      },
    }

    local ok = merge.merge_settings(target_path, fragment)
    assert.is_true(ok)

    local result = read_target(target_path)
    assert.equals("stdio", result.mcpServers["hand-written"].type)
    assert.equals("my-own-server", result.mcpServers["hand-written"].command)
    assert.equals("stdio", result.mcpServers.fixture.type)
  end)

  it("requirement (c): merging the same fragment twice yields identical decoded content and the second merge's tracked result adds nothing new", function()
    local fragment = {
      mcpServers = {
        fixture = {
          type = "stdio",
          command = "node",
          args = { "fixture-server.js" },
        },
      },
    }

    local ok1 = merge.merge_settings(target_path, fragment)
    assert.is_true(ok1)
    local first = read_target(target_path)

    local ok2, tracked2 = merge.merge_settings(target_path, fragment)
    assert.is_true(ok2)
    local second = read_target(target_path)

    assert.are.same(first, second)
    -- deep_merge only adds keys/items not already present, so re-merging an unchanged
    -- fragment adds nothing new: unmerging the SECOND merge's tracked result must be a
    -- true no-op (the file is unchanged), since nothing it tracked was actually new.
    merge.unmerge_settings(target_path, tracked2)
    local after_second_unmerge = read_target(target_path)
    assert.are.same(second, after_second_unmerge)
  end)

  it("requirement (b): unmerge_settings with the first merge's tracked data removes the extension's own server and leaves the hand-written entry intact", function()
    write_target(target_path, {
      mcpServers = {
        ["hand-written"] = {
          type = "stdio",
          command = "my-own-server",
        },
      },
    })

    local fragment = {
      mcpServers = {
        fixture = {
          type = "stdio",
          command = "node",
          args = { "fixture-server.js" },
        },
      },
    }

    local ok, tracked = merge.merge_settings(target_path, fragment)
    assert.is_true(ok)

    merge.unmerge_settings(target_path, tracked)

    local result = read_target(target_path)
    assert.is_nil(result.mcpServers.fixture)
    assert.equals("my-own-server", result.mcpServers["hand-written"].command)
  end)
end)
