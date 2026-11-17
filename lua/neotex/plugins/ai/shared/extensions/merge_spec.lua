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

  -- Resolved relative to this spec file's own on-disk location (via debug.getinfo, the same
  -- arg[0]-independent idiom hook_identity_cli.lua uses) rather than vim.fn.getcwd(): the
  -- fixture now lives beside the spec as host_settings_fixture.json (recovered verbatim from
  -- commit fc8cca3f0, siting it exactly as hook_identity_fixtures.json already is), so it no
  -- longer depends on an archived specs/ task directory surviving on disk.
  local function read_host_fixture()
    local this_file = debug.getinfo(1, "S").source:match("^@(.*)$")
    local this_dir = this_file:match("^(.*)/[^/]+$")
    local path = this_dir .. "/host_settings_fixture.json"
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
      -- The only block under this event was pruned; that emptied `hooks` entirely, so the
      -- key is dropped rather than written as `[]`.
      assert.is_nil(result.hooks)
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
      -- Pruning the only event emptied `hooks`, so the key is dropped (never `[]`).
      assert.is_nil(result.hooks)
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

    local raw = table.concat(vim.fn.readfile(target_path), "\n")
    local result = vim.json.decode(raw)
    -- The whole event array was pruned, not left as {}; and with Stop gone the `hooks`
    -- object itself is empty, so the key is dropped rather than written as `[]` (Lua
    -- cannot encode an empty object, and Claude Code rejects `"hooks": []`).
    assert.is_nil(result.hooks)
    assert.is_nil(raw:match('"hooks"%s*:%s*%[%]'))
    vim.fn.delete(target_path)
  end)

  it("never writes `hooks` back as an empty array when every event is pruned", function()
    local target_path = vim.fn.tempname()
    vim.fn.writefile({
      vim.json.encode({
        model = "opus",
        hooks = {
          Stop = { { matcher = "*", hooks = { { type = "command", command = "bash .claude/hooks/a.sh" } } } },
          PreToolUse = { { matcher = "Bash", hooks = { { type = "command", command = "bash .claude/hooks/b.sh" } } } },
        },
      }),
    }, target_path)

    local ok, removed_count = merge.remove_orphaned_hook_registrations(target_path, {})
    assert.is_true(ok)
    assert.equals(2, removed_count)

    local raw = table.concat(vim.fn.readfile(target_path), "\n")
    assert.is_nil(raw:match('"hooks"%s*:%s*%[%]'))
    local result = vim.json.decode(raw)
    assert.is_nil(result.hooks)
    assert.equals("opus", result.model) -- untouched keys carried through
    vim.fn.delete(target_path)
  end)

  it("merge_settings self-heals a pre-existing `\"hooks\": []` left by an earlier run", function()
    local target_path = vim.fn.tempname()
    vim.fn.writefile({ '{"hooks": [], "model": "opus"}' }, target_path)

    local ok = merge.merge_settings(target_path, { permissions = { allow = { "Bash(echo:*)" } } })
    assert.is_true(ok)

    local raw = table.concat(vim.fn.readfile(target_path), "\n")
    assert.is_nil(raw:match('"hooks"%s*:%s*%[%]'))
    local result = vim.json.decode(raw)
    assert.is_nil(result.hooks)
    assert.equals("opus", result.model)
    vim.fn.delete(target_path)
  end)

  it(
    "M.restore_removed_hook_registrations (Phase 5's rollback-threading primitive) "
      .. "re-inserts every swept entry, recreating a pruned event array/matcher block",
    function()
      local target_path = vim.fn.tempname()
      local orphan_command = "bash .claude/hooks/zz-fully-orphaned-restore.sh"
      vim.fn.writefile({
        vim.json.encode({
          hooks = {
            Stop = {
              { matcher = "*", hooks = { { type = "command", command = orphan_command } } },
            },
          },
        }),
      }, target_path)

      local ok, removed_count, removed_entries = merge.remove_orphaned_hook_registrations(target_path, {})
      assert.is_true(ok)
      assert.equals(1, removed_count)
      local wiped = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
      -- The sweep emptied `hooks`, so the key is dropped entirely; restore recreates it.
      assert.is_nil(wiped.hooks)

      local restore_ok = merge.restore_removed_hook_registrations(target_path, removed_entries)
      assert.is_true(restore_ok)

      local restored = vim.json.decode(table.concat(vim.fn.readfile(target_path), "\n"))
      assert.equals(1, #restored.hooks.Stop)
      assert.equals("*", restored.hooks.Stop[1].matcher)
      assert.equals(orphan_command, restored.hooks.Stop[1].hooks[1].command)
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

  it(
    "requirement (c): merging the same fragment twice yields identical decoded content, "
      .. "and the second merge's tracked result now records (but does not re-insert) the "
      .. "already-present nested array item -- the deep_merge tracking fix applies uniformly, "
      .. "not only to permissions.allow",
    function()
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

      -- Before the deep_merge tracking fix, an array item already present in the target was
      -- neither re-inserted nor recorded, so the second merge's tracked result was empty and
      -- unmerging it was a true no-op. After the fix, deep_merge records EVERY fragment item
      -- regardless of pre-existence (see merge.lua's comment on the array arm), so that a
      -- re-merge on resync can still be retracted on unload -- this is the whole point of the
      -- fix, and it is not special-cased to permissions.allow: mcpServers.fixture.args is a
      -- nested array field reached through the SAME plain-array arm on this second merge
      -- (mcpServers.fixture itself already exists, so deep_merge recurses into it as "merged"
      -- rather than re-inserting it as "new_object"), so unmerging the second merge's tracked
      -- result now removes the previously-merged args item, leaving an empty array behind
      -- while the fixture entry's other fields survive untouched.
      merge.unmerge_settings(target_path, tracked2)
      local after_second_unmerge = read_target(target_path)
      assert.same({}, after_second_unmerge.mcpServers.fixture.args)
      assert.equals("stdio", after_second_unmerge.mcpServers.fixture.type)
      assert.equals("node", after_second_unmerge.mcpServers.fixture.command)
    end
  )

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

-- Coverage for the deep_merge tracking fix: `permissions.allow` (and the structurally
-- identical non-matcher `hooks` arrays) are dedup-before-track in `deep_merge`'s plain-array
-- arm, so an item already present in the target used to be neither re-inserted NOR recorded --
-- leaving `tracked[key].items` empty for it and `M.unmerge_settings` with nothing to remove.
-- Because `manager.resync_all` re-merges every already-loaded extension's fragment on every
-- reload, this made the tracking record go empty (and an unload retract nothing) after the
-- very first reload. These specs assert the fixed behavior directly: every fragment item is
-- now recorded regardless of pre-existence, `M.unmerge_settings`'s `opts.retained_fragments`
-- guard protects a grant a sibling extension's fragment still declares, and the selected
-- shape's accepted residual (a coinciding hand-added user grant IS removed on unload) is
-- asserted explicitly rather than left implicit.
describe("shared.extensions.merge permission array tracking", function()
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

  it("case 1 -- fresh merge: a fragment's permissions.allow array merges into a target with none, and tracked records every grant", function()
    local fragment = {
      permissions = {
        allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
      },
    }

    local ok, tracked = merge.merge_settings(target_path, fragment)
    assert.is_true(ok)

    local result = read_target(target_path)
    assert.same(fragment.permissions.allow, result.permissions.allow)
    assert.same(fragment.permissions.allow, tracked.permissions.children.allow.items)
  end)

  it(
    "case 2 -- re-merge over already-present grants: merging the same fragment a second time "
      .. "does not duplicate the target array, but the second merge's tracked result records "
      .. "every grant again rather than an empty array (the regression test for the defect)",
    function()
      local fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
        },
      }

      local ok1 = merge.merge_settings(target_path, fragment)
      assert.is_true(ok1)
      local first = read_target(target_path)

      local ok2, tracked2 = merge.merge_settings(target_path, fragment)
      assert.is_true(ok2)
      local second = read_target(target_path)

      -- No duplication.
      assert.same(first, second)
      assert.equals(2, #second.permissions.allow)

      -- Before the fix, deep_merge recorded a tracked item only when newly inserted, so the
      -- second merge's tracked.permissions.children.allow.items would be {} here -- exactly
      -- the empty record this task exists to eliminate.
      assert.same(fragment.permissions.allow, tracked2.permissions.children.allow.items)
    end
  )

  it(
    "case 3 -- unmerge after each: unmerge_settings with either the first merge's tracked "
      .. "result, or the SECOND merge's tracked result alone, returns permissions.allow to its "
      .. "pre-merge content (nil)",
    function()
      local fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
        },
      }

      -- First tracked result, applied alone.
      local ok1, tracked1 = merge.merge_settings(target_path, fragment)
      assert.is_true(ok1)
      merge.unmerge_settings(target_path, tracked1)
      local after_first = read_target(target_path)
      assert.is_nil(after_first.permissions)

      -- Merge twice, then unmerge with ONLY the second merge's tracked result -- it alone must
      -- be complete enough to retract the whole grant set, since it is the only record that
      -- would still exist after a resync re-merges an already-loaded extension. The wrapper
      -- "permissions" key itself survives as an empty object here (unlike the first scenario
      -- above): it was created fresh by the FIRST merge (tracked1.type == "new_object", which
      -- removes the key entirely on unmerge), but the SECOND merge instead recurses into it
      -- as "merged" (the key already existed by then), and a "merged" entry's own unmerge
      -- never deletes the wrapper key -- only its tracked children. The grants themselves are
      -- still fully retracted either way, which is what this task is about.
      local ok2 = merge.merge_settings(target_path, fragment)
      assert.is_true(ok2)
      local ok3, tracked2 = merge.merge_settings(target_path, fragment)
      assert.is_true(ok3)
      merge.unmerge_settings(target_path, tracked2)
      local after_second = read_target(target_path)
      assert.same({}, after_second.permissions.allow)
    end
  )

  it(
    "case 4 -- coinciding user grant: a hand-added grant equal to one the fragment declares IS "
      .. "removed on unload -- the selected shape's accepted residual, asserted explicitly "
      .. "rather than left as an oversight",
    function()
      write_target(target_path, {
        permissions = {
          allow = { "mcp__sapience__sapience" },
        },
      })

      local fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
        },
      }

      local ok, tracked = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)
      local merged = read_target(target_path)
      -- No duplication of the coinciding grant.
      assert.equals(2, #merged.permissions.allow)

      merge.unmerge_settings(target_path, tracked)
      local after_unmerge = read_target(target_path)
      -- ACCEPTED RESIDUAL: the hand-added grant is removed along with the fragment's own --
      -- shape (i) cannot distinguish "the user added this independently" from "this extension
      -- added it on an earlier load, and it is merely already present now". A grant meant to
      -- survive an unload belongs in .claude/settings.json, which no merge path touches.
      assert.same({}, after_unmerge.permissions.allow)
    end
  )

  it(
    "case 5 -- sibling-extension retention: opts.retained_fragments carrying a second "
      .. "extension's fragment that declares one of the same grants protects that grant from "
      .. "removal, while the rest are still retracted",
    function()
      -- Seed a pre-existing, unrelated grant so permissions.allow already exists before this
      -- merge -- the realistic shape (this repository's settings.local.json already carries
      -- grants from other extensions before sapience/nix/lean ever merge in), and the shape
      -- the retained-fragments guard is scoped to (the "appended" branch's per-item removal;
      -- see merge.lua's unmerge_settings doc comment for the "new_array"/"new_object" scope
      -- boundary this does not cover).
      write_target(target_path, {
        permissions = {
          allow = { "existing-other-grant" },
        },
      })

      local fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
        },
      }

      local ok, tracked = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      local sibling_fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience" },
        },
      }

      merge.unmerge_settings(target_path, tracked, { retained_fragments = { sibling_fragment } })

      local result = read_target(target_path)
      assert.same(
        { "existing-other-grant", "mcp__sapience__sapience" },
        result.permissions.allow
      )
    end
  )

  it(
    "case 6 -- hooks non-regression: a matcher-bearing hook event still produces "
      .. "type = hook_merged and round-trips as before, and a non-matcher hook event array "
      .. "(sapience's SessionStart shape) now records its blocks under 'appended' and is "
      .. "retracted by unmerge",
    function()
      -- Seed a pre-existing SessionStart block (another extension's or core's own hook) so
      -- this merge's SessionStart tracking is "appended", not "new_array" -- the shape
      -- measured live in this repository (sapience's SessionStart/SessionEnd/UserPromptSubmit/
      -- Stop all record "appended" with empty items today, never "new_array", because
      -- .claude/settings.local.json already carries other extensions' hook registrations
      -- before sapience ever merges in).
      write_target(target_path, {
        hooks = {
          SessionStart = {
            { hooks = { { type = "command", command = "echo pre-existing" } } },
          },
        },
      })

      local fragment = {
        hooks = {
          -- Matcher-bearing: routes through merge_hook_event_array, immune to the
          -- dedup-before-track defect (it tracks explicitly rather than skipping).
          PreToolUse = {
            {
              matcher = "Edit|Write",
              hooks = { { type = "command", command = "echo pretooluse" } },
            },
          },
          -- Non-matcher: is_hook_event_array rejects it (no `matcher` field on the block), so
          -- it falls through to the SAME plain-array arm permissions.allow uses.
          SessionStart = {
            { hooks = { { type = "command", command = "echo sessionstart" } } },
          },
        },
      }

      local ok, tracked = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      assert.equals("hook_merged", tracked.hooks.children.PreToolUse.type)
      assert.equals("appended", tracked.hooks.children.SessionStart.type)
      assert.same(fragment.hooks.SessionStart, tracked.hooks.children.SessionStart.items)

      local merged = read_target(target_path)
      assert.equals(1, #merged.hooks.PreToolUse)
      assert.equals(2, #merged.hooks.SessionStart)

      merge.unmerge_settings(target_path, tracked)
      local after_unmerge = read_target(target_path)
      -- The matcher-bearing PreToolUse block this merge appended wholesale is gone (leaving an
      -- empty array, not a deleted key: hook_merged's own unmerge never removes the per-event
      -- key itself); the non-matcher SessionStart block this merge appended is gone too,
      -- leaving only the pre-existing seeded one. Neither event key is deleted outright -- the
      -- "hooks" wrapper and SessionStart are "merged"/"appended" entries here (both already
      -- existed before this merge ran), which never delete the key, only its tracked contents.
      assert.same({}, after_unmerge.hooks.PreToolUse)
      assert.equals(1, #after_unmerge.hooks.SessionStart)
      assert.equals("echo pre-existing", after_unmerge.hooks.SessionStart[1].hooks[1].command)
    end
  )

  it(
    "case 7 -- narrowed fragment: merge a wide fragment, unmerge with that merge's own tracked "
      .. "data, then re-merge a narrower fragment -- the dropped (write-tool-shaped) items are "
      .. "gone and only the narrower set remains, pinning the exact sequence manager.load's "
      .. "forced-reload retraction block performs",
    function()
      -- Seed a pre-existing, empty permissions.allow so the wrapper key is tracked "merged"
      -- (recurse into children) rather than "new_object" (wholesale-removed on unmerge) -- the
      -- realistic shape: this repository's settings.local.json already has a permissions key
      -- from other extensions before sapience ever merges in (see case 5's own seeding note).
      write_target(target_path, { permissions = { allow = {} } })

      local wide_fragment = {
        permissions = {
          allow = {
            "mcp__sapience__sapience",
            "mcp__sapience__sapience_search",
            "mcp__sapience__sapience_remember",
            "mcp__sapience__sapience_wrapup",
          },
        },
      }

      local ok1, tracked1 = merge.merge_settings(target_path, wide_fragment)
      assert.is_true(ok1)
      assert.equals(4, #read_target(target_path).permissions.allow)

      merge.unmerge_settings(target_path, tracked1)
      assert.same({}, read_target(target_path).permissions.allow)

      local narrow_fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
        },
      }
      local ok2 = merge.merge_settings(target_path, narrow_fragment)
      assert.is_true(ok2)

      local final = read_target(target_path)
      assert.same(narrow_fragment.permissions.allow, final.permissions.allow)
    end
  )

  it(
    "case 8 -- sibling retention during narrowed-fragment retraction: the same unmerge-then-"
      .. "remerge sequence as case 7, but opts.retained_fragments carries a second extension's "
      .. "fragment that still declares one of the dropped grants -- that grant survives the "
      .. "unmerge step, so it is still present (deduped, not doubled) after the narrower "
      .. "fragment is re-merged",
    function()
      write_target(target_path, { permissions = { allow = {} } })

      local wide_fragment = {
        permissions = {
          allow = {
            "mcp__sapience__sapience",
            "mcp__sapience__sapience_remember",
            "mcp__sapience__sapience_wrapup",
          },
        },
      }

      local ok1, tracked1 = merge.merge_settings(target_path, wide_fragment)
      assert.is_true(ok1)

      local sibling_fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience_remember" },
        },
      }
      merge.unmerge_settings(target_path, tracked1, { retained_fragments = { sibling_fragment } })

      local after_unmerge = read_target(target_path)
      assert.same({ "mcp__sapience__sapience_remember" }, after_unmerge.permissions.allow)

      local narrow_fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience" },
        },
      }
      local ok2 = merge.merge_settings(target_path, narrow_fragment)
      assert.is_true(ok2)

      local final = read_target(target_path)
      assert.same(
        { "mcp__sapience__sapience_remember", "mcp__sapience__sapience" },
        final.permissions.allow
      )
    end
  )

  it(
    "case 9 -- hand-added survival: a grant present in the target but absent from EVERY tracked "
      .. "structure (never declared by any extension's fragment, coinciding or otherwise) "
      .. "survives the retraction untouched -- remove_tracked visits only keys present in the "
      .. "passed tracked structure, so an untracked grant is never a removal candidate",
    function()
      write_target(target_path, { permissions = { allow = {} } })

      local fragment = {
        permissions = {
          allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_remember" },
        },
      }
      local ok, tracked = merge.merge_settings(target_path, fragment)
      assert.is_true(ok)

      -- Hand-add a grant with NO relationship to the fragment at all -- not merged by this
      -- call, not present in `tracked` under any key.
      local target = read_target(target_path)
      table.insert(target.permissions.allow, "Bash(echo:*)")
      write_target(target_path, target)
      assert.equals(3, #read_target(target_path).permissions.allow)

      merge.unmerge_settings(target_path, tracked)

      local after_unmerge = read_target(target_path)
      assert.same({ "Bash(echo:*)" }, after_unmerge.permissions.allow)
    end
  )

  it(
    "M.unmerge_settings's pre_removal_snapshot (2nd return value) plus "
      .. "M.restore_retracted_sections undo the retraction exactly -- the rollback-threading "
      .. "pair manager.load's forced-reload retraction block uses when a subsequent re-merge "
      .. "fails: a failed forced load must leave the target exactly as it found it",
    function()
      write_target(target_path, {
        permissions = { allow = { "existing-other-grant" } },
        hooks = { SessionStart = { { hooks = { { type = "command", command = "echo pre" } } } } },
      })

      local wide_fragment = {
        permissions = {
          allow = {
            "mcp__sapience__sapience",
            "mcp__sapience__sapience_remember",
            "mcp__sapience__sapience_wrapup",
          },
        },
      }
      local ok1, tracked1 = merge.merge_settings(target_path, wide_fragment)
      assert.is_true(ok1)
      local before_retraction = read_target(target_path)

      local ok2, snapshot = merge.unmerge_settings(target_path, tracked1)
      assert.is_true(ok2)
      assert.is_not_nil(snapshot)
      assert.same({ "existing-other-grant" }, read_target(target_path).permissions.allow)

      -- Simulate the subsequent re-merge then failing: restore exactly what was retracted.
      local restore_ok = merge.restore_retracted_sections(target_path, snapshot)
      assert.is_true(restore_ok)
      assert.same(before_retraction.permissions, read_target(target_path).permissions)
      -- hooks (an untouched top-level key) is unaffected throughout.
      assert.same(before_retraction.hooks, read_target(target_path).hooks)
    end
  )
end)

describe("shared.extensions.merge orphan sweep for MCP permission grants", function()
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

  it("extract_mcp_prefix recognizes the mcp__<server>__ shape and rejects non-MCP strings", function()
    assert.equals("mcp__sapience__", merge.extract_mcp_prefix("mcp__sapience__sapience_search"))
    assert.equals("mcp__nixos__", merge.extract_mcp_prefix("mcp__nixos__nix"))
    assert.is_nil(merge.extract_mcp_prefix("Bash(echo:*)"))
    assert.is_nil(merge.extract_mcp_prefix("Read(//home/user/**)"))
    assert.is_nil(merge.extract_mcp_prefix(42))
  end)

  it(
    "removes a grant left behind by a now-narrowed fragment (the real defect this task fixes): "
      .. "the deployed file carries 4 sapience grants, the valid set names only 2, and the "
      .. "watched prefix is mcp__sapience__ -- the sweep removes exactly the 2 absent from the "
      .. "valid set and leaves everything else untouched",
    function()
      write_target(target_path, {
        permissions = {
          allow = {
            "mcp__sapience__sapience",
            "mcp__sapience__sapience_search",
            "mcp__sapience__sapience_remember",
            "mcp__sapience__sapience_wrapup",
            "Bash(echo:*)",
          },
        },
      })

      local valid_set = { ["mcp__sapience__sapience"] = true, ["mcp__sapience__sapience_search"] = true }
      local watched_prefixes = { ["mcp__sapience__"] = true }

      local ok, removed_count, removed_items =
        merge.remove_orphaned_mcp_permission_grants(target_path, valid_set, watched_prefixes)
      assert.is_true(ok)
      assert.equals(2, removed_count)
      table.sort(removed_items)
      assert.same({ "mcp__sapience__sapience_remember", "mcp__sapience__sapience_wrapup" }, removed_items)

      local result = read_target(target_path)
      table.sort(result.permissions.allow)
      assert.same(
        { "Bash(echo:*)", "mcp__sapience__sapience", "mcp__sapience__sapience_search" },
        result.permissions.allow
      )
    end
  )

  it(
    "never touches a grant under an UNWATCHED mcp prefix -- no currently-loaded extension "
      .. "declares anything under mcp__other__, so the sweep leaves it alone even though it is "
      .. "absent from valid_set, matching the hook sweep's own fail-safe direction (incomplete "
      .. "or absent information about a namespace is never a reason to act on it)",
    function()
      write_target(target_path, {
        permissions = {
          allow = { "mcp__sapience__sapience_remember", "mcp__other__something" },
        },
      })

      local valid_set = {}
      local watched_prefixes = { ["mcp__sapience__"] = true }

      local ok, removed_count, removed_items =
        merge.remove_orphaned_mcp_permission_grants(target_path, valid_set, watched_prefixes)
      assert.is_true(ok)
      assert.equals(1, removed_count)
      assert.same({ "mcp__sapience__sapience_remember" }, removed_items)

      local result = read_target(target_path)
      assert.same({ "mcp__other__something" }, result.permissions.allow)
    end
  )

  it("is idempotent: a second sweep over the swept result removes nothing further", function()
    write_target(target_path, {
      permissions = {
        allow = { "mcp__sapience__sapience", "mcp__sapience__sapience_remember" },
      },
    })

    local valid_set = { ["mcp__sapience__sapience"] = true }
    local watched_prefixes = { ["mcp__sapience__"] = true }

    local ok1, removed_count1 =
      merge.remove_orphaned_mcp_permission_grants(target_path, valid_set, watched_prefixes)
    assert.is_true(ok1)
    assert.equals(1, removed_count1)

    local ok2, removed_count2 =
      merge.remove_orphaned_mcp_permission_grants(target_path, valid_set, watched_prefixes)
    assert.is_true(ok2)
    assert.equals(0, removed_count2)
  end)

  it(
    "M.restore_removed_mcp_permission_grants (the rollback-threading primitive) re-appends every "
      .. "swept grant, recreating permissions.allow if the sweep left it absent entirely",
    function()
      write_target(target_path, {
        permissions = { allow = { "mcp__sapience__sapience_remember" } },
      })

      local valid_set = {}
      local watched_prefixes = { ["mcp__sapience__"] = true }
      local ok, removed_count, removed_items =
        merge.remove_orphaned_mcp_permission_grants(target_path, valid_set, watched_prefixes)
      assert.is_true(ok)
      assert.equals(1, removed_count)
      assert.same({}, read_target(target_path).permissions.allow)

      local restore_ok = merge.restore_removed_mcp_permission_grants(target_path, removed_items)
      assert.is_true(restore_ok)
      assert.same({ "mcp__sapience__sapience_remember" }, read_target(target_path).permissions.allow)
    end
  )
end)
