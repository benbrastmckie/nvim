-- Neovim STT (Speech-to-Text) Plugin
-- Uses Vosk for offline speech recognition with context-aware Claude Code integration
--
-- Requirements:
--   - parecord (pulseaudio-utils or pipewire-pulse)
--   - vosk Python package with vosk-model-small-en-us
--   - ~/.local/bin/vosk-transcribe.py (transcription helper)
--   - Terminal with enhanced keyboard protocol (WezTerm, Kitty), so that Neovim
--     itself receives <C-'>: ctrl+punctuation has no legacy terminal encoding
--
-- Configuration (optional):
--   vim.g.stt_model_path = "~/.local/share/vosk/vosk-model-small-en-us"
--   vim.g.stt_record_timeout = 30  -- max seconds for recording
--   vim.g.stt_sample_rate = 16000  -- audio sample rate
--
-- Claude Code configuration (optional):
--   vim.g.stt_claude_ptt_key = "ctrl+k"      -- override the keystroke to send,
--                                            -- instead of reading keybindings.json
--   vim.g.stt_claude_voice_mode = "hold"     -- mode to request when voice mode is off
--   vim.g.stt_claude_ptt_style = "virtual_hold"  -- or "passthrough" to forward each event
--   vim.g.stt_claude_hold_timeout = 120      -- seconds before a virtual hold is capped
--
-- Usage:
--   <leader>vr - Start recording (which-key, if enabled)
--   <leader>vs - Stop recording and transcribe (which-key, if enabled)
--   <leader>vv - Toggle recording (which-key, if enabled)
--   <C-'>      - Unified dictation key (normal, insert, terminal modes)
--                In Claude Code buffers: forwarded to Claude Code as its own
--                  push-to-talk key. Tap to start recording, tap again to stop;
--                  the transcript lands in the prompt for editing rather than
--                  being sent.
--                  The key Neovim writes is read from ~/.claude/keybindings.json
--                  -- whichever keystroke is bound to voice:pushToTalk -- so the
--                  two halves have one source of truth. It must be a keystroke
--                  with a control-byte encoding (ctrl+<letter>, ctrl+[, and so
--                  on); :STTHealth names the link that is broken when one is not.
--                  Claude Code ends a hold-mode recording when key events STOP
--                  arriving (a 200ms timer re-armed by each event), not when the
--                  key is released -- which Neovim drops anyway. Neovim therefore
--                  repeats the keypress on a timer to hold the key down itself,
--                  making a tap gesture run through hold mode. That matters
--                  because Claude Code's own tap mode submits any transcript of
--                  three or more words, with no setting to prevent it.
--                  If Claude Code voice mode is off, the first press enables it.
--                In all other buffers: toggles Vosk STT recording/transcription
--
--   :STTClaudeVoice - send /voice to a Claude Code buffer to enable/disable voice mode
--   :STTHealth      - check Vosk dependencies and every link of the Claude Code chain
--
-- Global state:
--   vim.g.stt_recording - true when recording, false otherwise (for statusline)
--   vim.g.stt_claude_recording - true while a Claude Code virtual hold is active

local M = {}

-- State
local recording_job_id = nil
local recording_file = "/tmp/nvim-stt-recording.wav"
local is_recording = false

-- Configuration with defaults
local function get_config()
  return {
    model_path = vim.g.stt_model_path or vim.fn.expand("~/.local/share/vosk/vosk-model-small-en-us"),
    transcribe_script = vim.g.stt_transcribe_script or vim.fn.expand("~/.local/bin/vosk-transcribe.py"),
    record_timeout = vim.g.stt_record_timeout or 30,
    sample_rate = vim.g.stt_sample_rate or 16000,
    recording_file = vim.g.stt_recording_file or recording_file,
  }
end

local function notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("[STT] " .. msg, level)
end

local function command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Claude Code integration
local _session_manager_ok, _session_manager = pcall(require, "neotex.plugins.ai.claude.core.session-manager")

-- Claude Code's push-to-talk key lives in its own keybindings file, and Neovim
-- derives the bytes to write from that file rather than carrying a second copy
-- of the choice. One source of truth means the two halves cannot drift apart.
local CLAUDE_KEYBINDINGS_FILE = vim.fn.expand("~/.claude/keybindings.json")

-- The action a push-to-talk binding must name for this module to drive it.
local CLAUDE_PTT_ACTION = "voice:pushToTalk"

-- Used when keybindings.json names no key this module can deliver. ctrl+k is
-- one byte on the wire (0x0b) and is unbound in Claude Code's defaults.
local CLAUDE_PTT_FALLBACK_KEY = "ctrl+k"

--- Encode a Claude Code keystroke as the bytes a pty delivers for it.
---
--- Only the C0 control range is encodable. A pty carries ctrl+<letter> and
--- ctrl+<@, [, \, ], ^, _, ?> as a single byte, an encoding every terminal has
--- produced since ASCII. Every other ctrl combination -- ctrl+' among them --
--- exists only in the kitty keyboard protocol as a CSI-u sequence, and a
--- sequence written into a :terminal channel is decoded by whatever the embedded
--- program's input layer happens to do with it, which is not a contract. So this
--- function refuses anything it cannot express as a control byte, and the caller
--- reports the refusal rather than writing bytes that may be silently dropped.
---
--- @param keystroke string A keystroke in Claude Code's syntax, e.g. "ctrl+k"
--- @return string|nil bytes The wire encoding, or nil when there is none
--- @return string|nil reason Why it cannot be encoded, when bytes is nil
local function _legacy_ctrl_byte(keystroke)
  if type(keystroke) ~= "string" then
    return nil, "not a string"
  end
  if keystroke:find("%s") then
    return nil, "chords cannot be delivered as a single keypress"
  end
  local key = keystroke:match("^ctrl%+(.+)$") or keystroke:match("^control%+(.+)$")
  if not key then
    return nil, "only ctrl+<key> has a control-byte encoding"
  end
  if #key ~= 1 then
    return nil, "named keys have no control-byte encoding"
  end
  local lower = key:lower()
  if lower:match("%l") then
    return string.char(lower:byte() - 96), nil
  end
  local punctuation = {
    ["@"] = 0, ["["] = 27, ["\\"] = 28, ["]"] = 29,
    ["^"] = 30, ["_"] = 31, ["?"] = 127,
  }
  local byte = punctuation[key]
  if byte then
    return string.char(byte), nil
  end
  return nil, string.format("ctrl+%s reaches an application only as a CSI-u sequence", key)
end

--- Read the keystrokes Claude Code has bound to push-to-talk.
--- @return table bindings List of { key = string, context = string }
local function _claude_ptt_bindings()
  local found = {}
  local ok, lines = pcall(vim.fn.readfile, CLAUDE_KEYBINDINGS_FILE)
  if not ok or type(lines) ~= "table" then
    return found
  end
  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(decoded) ~= "table" or type(decoded.bindings) ~= "table" then
    return found
  end
  for _, group in ipairs(decoded.bindings) do
    if type(group) == "table" and type(group.bindings) == "table" then
      for key, action in pairs(group.bindings) do
        if action == CLAUDE_PTT_ACTION then
          table.insert(found, { key = key, context = group.context or "?" })
        end
      end
    end
  end
  table.sort(found, function(a, b) return a.key < b.key end)
  return found
end

--- Resolve the push-to-talk key this module will deliver, preferring a binding
--- Claude Code actually carries over the fallback.
--- @return string key The chosen keystroke
--- @return string source Where it came from, for the health report
--- @return table rejected Keystrokes found but not encodable: { key, reason }
local function _resolve_claude_ptt_key()
  local override = vim.g.stt_claude_ptt_key
  if type(override) == "string" and override ~= "" then
    return override, "vim.g.stt_claude_ptt_key", {}
  end
  local rejected = {}
  for _, binding in ipairs(_claude_ptt_bindings()) do
    local bytes, reason = _legacy_ctrl_byte(binding.key)
    if bytes then
      return binding.key, "keybindings.json", rejected
    end
    table.insert(rejected, { key = binding.key, reason = reason })
  end
  return CLAUDE_PTT_FALLBACK_KEY, "built-in fallback", rejected
end

-- Resolving re-reads keybindings.json, so the result is cached. A hold repeats
-- the keypress every 80ms, and the cache keys on everything the resolution
-- depends on -- the file's mtime AND the override -- so an edit to either takes
-- effect mid-session rather than waiting for a restart.
local _ptt_cache = { mtime = nil, override = nil, key = nil, bytes = nil, source = nil }

--- The bytes to write for one push-to-talk keypress.
--- @return string|nil bytes Wire encoding, or nil when none is available
--- @return string key The keystroke the bytes encode
--- @return string source Where that keystroke came from
local function _claude_ptt_sequence()
  local mtime = vim.fn.getftime(CLAUDE_KEYBINDINGS_FILE)
  local override = vim.g.stt_claude_ptt_key
  if _ptt_cache.mtime ~= mtime or _ptt_cache.override ~= override then
    local key, source = _resolve_claude_ptt_key()
    local bytes = _legacy_ctrl_byte(key)
    _ptt_cache = {
      mtime = mtime,
      override = override,
      key = key,
      bytes = bytes,
      source = source,
    }
  end
  return _ptt_cache.bytes, _ptt_cache.key, _ptt_cache.source
end

-- Claude Code persists voice mode in its own settings file, so Neovim can tell
-- whether voice mode is currently on and enable it on demand.
local CLAUDE_SETTINGS_FILE = vim.fn.expand("~/.claude/settings.json")

-- Mode used when Neovim has to enable voice mode itself. "hold" keeps the
-- transcript editable; "tap" always auto-submits once the transcript reaches
-- three words, which is not configurable in Claude Code.
local function _claude_voice_mode()
  return vim.g.stt_claude_voice_mode or "hold"
end

--- Read Claude Code's persisted settings.
--- @return table|nil settings Decoded settings table, or nil when unreadable
local function _claude_settings()
  local ok, lines = pcall(vim.fn.readfile, CLAUDE_SETTINGS_FILE)
  if not ok or type(lines) ~= "table" then
    return nil
  end
  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

--- Read Claude Code's persisted voice-mode state.
--- @return boolean|nil enabled True/false when known, nil when it cannot be read
local function _claude_voice_enabled()
  local decoded = _claude_settings()
  if not decoded then
    return nil
  end
  if type(decoded.voice) == "table" and decoded.voice.enabled ~= nil then
    return decoded.voice.enabled == true
  end
  if decoded.voiceEnabled ~= nil then
    return decoded.voiceEnabled == true
  end
  return nil
end

--- Read the voice mode Claude Code is actually configured for.
--- @return string|nil mode "hold", "tap", or nil when it cannot be read
local function _claude_active_voice_mode()
  local decoded = _claude_settings()
  if not decoded then
    return nil
  end
  if type(decoded.voice) == "table" and type(decoded.voice.mode) == "string" then
    return decoded.voice.mode
  end
  if type(decoded.voiceMode) == "string" then
    return decoded.voiceMode
  end
  return nil
end

local function _is_claude_code_buffer(bufnr)
  if _session_manager_ok then
    local ok, result = pcall(_session_manager.is_claude_buffer, bufnr)
    if ok and result then
      return true
    end
  end
  -- Fallback mirrors the bufname test used by _G.set_terminal_keymaps()
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name:match("claude") ~= nil or name:match("ClaudeCode") ~= nil
end

local function _claude_channel(bufnr)
  local channel = vim.b[bufnr].terminal_job_id
  if not channel or channel <= 0 then return nil end
  return channel
end

local uv = vim.uv or vim.loop

-- Virtual hold: Claude Code's hold mode ends a recording when key events stop
-- arriving (a 200ms timer re-armed by every event), not when the key is released.
-- Repeating the keypress on a timer therefore holds the key on the user's behalf,
-- giving a tap-to-start/tap-to-stop gesture that still runs through hold mode --
-- and so still leaves the transcript in the prompt instead of submitting it.
-- Tap mode cannot do this: it submits any transcript of three or more words.
local VIRTUAL_HOLD_INTERVAL_MS = 80
local VIRTUAL_HOLD_DEBOUNCE_MS = 250
local _virtual_hold = { timer = nil, bufnr = nil, started_at = 0 }
local _last_ptt_at = 0

local function _virtual_hold_active()
  return _virtual_hold.timer ~= nil
end

--- Stop holding the key; Claude Code finishes the recording ~200ms later.
local function _virtual_hold_stop()
  if _virtual_hold.timer then
    pcall(function()
      _virtual_hold.timer:stop()
      _virtual_hold.timer:close()
    end)
    _virtual_hold.timer = nil
  end
  _virtual_hold.bufnr = nil
  vim.g.stt_claude_recording = false
end

--- Begin holding the key down on a timer until stopped.
--- @param bufnr number Buffer handle of the Claude Code terminal
--- @param channel number Terminal job channel
--- @param sequence string Wire encoding of one push-to-talk keypress
--- @return boolean ok True when the hold started
local function _virtual_hold_start(bufnr, channel, sequence)
  _virtual_hold_stop()
  local timer = uv.new_timer()
  if not timer then
    return false
  end
  _virtual_hold.timer = timer
  _virtual_hold.bufnr = bufnr
  _virtual_hold.started_at = uv.now()
  vim.g.stt_claude_recording = true
  vim.fn.chansend(channel, sequence)

  local max_ms = (vim.g.stt_claude_hold_timeout or 120) * 1000
  timer:start(VIRTUAL_HOLD_INTERVAL_MS, VIRTUAL_HOLD_INTERVAL_MS, vim.schedule_wrap(function()
    if not _virtual_hold_active() then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      _virtual_hold_stop()
      return
    end
    if (uv.now() - _virtual_hold.started_at) > max_ms then
      _virtual_hold_stop()
      notify("Claude Code recording stopped at timeout", vim.log.levels.WARN)
      return
    end
    local ch = _claude_channel(bufnr)
    if not ch then
      _virtual_hold_stop()
      return
    end
    vim.fn.chansend(ch, sequence)
  end))
  return true
end

-- Suppress the voice-mode probe briefly after enabling it, so the key repeats of
-- a single held <C-'> do not each re-send the /voice command while Claude Code is
-- still writing its settings file.
local _voice_enable_sent_at = 0
local VOICE_ENABLE_GRACE_MS = 3000

--- Forward <C-'> to Claude Code as a push-to-talk keypress, enabling voice mode
--- first when Claude Code currently has it switched off.
--- @param bufnr number Buffer handle of the Claude Code terminal
--- @return boolean ok True when something was written to the terminal channel
local function _send_claude_ptt(bufnr)
  local channel = _claude_channel(bufnr)
  if not channel then return false end

  -- Refuse before writing anything. A keystroke with no wire encoding would be
  -- written as a sequence Claude Code may silently drop, which is the failure
  -- this check exists to make visible.
  local sequence, key = _claude_ptt_sequence()
  if not sequence then
    notify(string.format(
      "Claude Code push-to-talk key %s cannot be delivered through a terminal; run :STTHealth",
      tostring(key)), vim.log.levels.ERROR)
    return false
  end

  local within_grace = (vim.loop.now() - _voice_enable_sent_at) < VOICE_ENABLE_GRACE_MS
  if not within_grace and _claude_voice_enabled() == false then
    -- Voice mode is off. Turn it on; holding the key keeps sending repeats, and
    -- the next one starts recording now that voice mode is live.
    _voice_enable_sent_at = vim.loop.now()
    vim.fn.chansend(channel, "/voice " .. _claude_voice_mode() .. "\r")
    notify("Claude Code voice mode enabling -- hold <C-'> again to record", vim.log.levels.INFO)
    return true
  end

  -- Virtual hold only makes sense against Claude Code's hold mode; in tap mode a
  -- repeated keypress would toggle the recorder on and off instead.
  local style = vim.g.stt_claude_ptt_style or "virtual_hold"
  if style == "virtual_hold" and _claude_active_voice_mode() == "hold" then
    local now = uv.now()
    local since = now - _last_ptt_at
    _last_ptt_at = now
    -- Swallow key auto-repeat so physically holding the key is still one gesture.
    if since < VIRTUAL_HOLD_DEBOUNCE_MS then
      return true
    end
    if _virtual_hold_active() then
      _virtual_hold_stop()
    else
      _virtual_hold_start(bufnr, channel, sequence)
    end
    return true
  end

  vim.fn.chansend(channel, sequence)
  return true
end

--- Send the /voice slash command to toggle Claude Code voice mode on or off.
--- @param bufnr number Buffer handle of the Claude Code terminal
--- @return boolean ok True when the command was written to the terminal channel
local function _send_claude_voice(bufnr)
  local channel = _claude_channel(bufnr)
  if not channel then return false end
  vim.fn.chansend(channel, "/voice\r")
  return true
end

function M.start_recording()
  if is_recording then
    notify("Already recording! Press <leader>vs to stop.", vim.log.levels.WARN)
    return
  end

  local config = get_config()

  if not command_exists("parecord") then
    notify("parecord not found. Install pulseaudio-utils or pipewire-pulse.", vim.log.levels.ERROR)
    return
  end

  vim.fn.delete(config.recording_file)

  local cmd = {
    "parecord",
    "--channels=1",
    "--rate=" .. config.sample_rate,
    "--file-format=wav",
    config.recording_file
  }

  recording_job_id = vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code, _)
      is_recording = false
      vim.g.stt_recording = false
      recording_job_id = nil

      if exit_code == 0 or exit_code == 143 then
        M.transcribe_and_insert()
      else
        notify("Recording failed with exit code: " .. exit_code, vim.log.levels.ERROR)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        for _, line in ipairs(data) do
          if line ~= "" then
            notify("Recording stderr: " .. line, vim.log.levels.DEBUG)
          end
        end
      end
    end,
  })

  if recording_job_id > 0 then
    is_recording = true
    vim.g.stt_recording = true
    notify("[STT] Recording started", vim.log.levels.INFO)

    vim.defer_fn(function()
      if is_recording then
        notify("Recording timeout reached, auto-stopping", vim.log.levels.WARN)
        M.stop_recording()
      end
    end, config.record_timeout * 1000)
  else
    notify("Failed to start recording", vim.log.levels.ERROR)
  end
end

function M.stop_recording()
  if not is_recording or not recording_job_id then
    notify("Not currently recording", vim.log.levels.WARN)
    return
  end

  vim.fn.jobstop(recording_job_id)
  vim.g.stt_recording = false
  notify("[STT] Stopped recording", vim.log.levels.INFO)
end

function M.toggle_recording()
  if is_recording then
    M.stop_recording()
  else
    M.start_recording()
  end
end

function M.transcribe_and_insert()
  local config = get_config()

  if vim.fn.filereadable(config.recording_file) ~= 1 then
    notify("Recording file not found: " .. config.recording_file, vim.log.levels.ERROR)
    return
  end

  if vim.fn.filereadable(config.transcribe_script) ~= 1 then
    notify("Transcription script not found: " .. config.transcribe_script, vim.log.levels.ERROR)
    return
  end

  if not command_exists("python3") then
    notify("python3 not found", vim.log.levels.ERROR)
    return
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local current_buf = vim.api.nvim_get_current_buf()

  local cmd = {
    "python3",
    config.transcribe_script,
    config.recording_file,
    config.model_path,
  }

  local output_lines = {}

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        for _, line in ipairs(data) do
          if line ~= "" then
            notify("Transcription error: " .. line, vim.log.levels.ERROR)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code ~= 0 then
        notify("Transcription failed with exit code: " .. exit_code, vim.log.levels.ERROR)
        return
      end

      local text = table.concat(output_lines, " ")

      if text == "" then
        notify("No speech detected", vim.log.levels.WARN)
        return
      end

      vim.schedule(function()
        if vim.api.nvim_get_current_buf() == current_buf then
          local buftype = vim.api.nvim_get_option_value('buftype', { buf = current_buf })
          if buftype == 'terminal' then
            local channel = vim.b[current_buf].terminal_job_id
            if channel and channel > 0 then
              vim.fn.chansend(channel, text)
            else
              vim.fn.setreg('"', text)
              notify("Terminal channel unavailable, text saved to register", vim.log.levels.WARN)
            end
          else
            vim.api.nvim_win_set_cursor(0, cursor_pos)
            vim.api.nvim_put({text}, 'c', true, true)
          end
        else
          vim.fn.setreg('"', text)
          notify("Text saved to register: " .. string.sub(text, 1, 50) .. (string.len(text) > 50 and "..." or ""), vim.log.levels.INFO)
        end
      end)

      vim.fn.delete(config.recording_file)
    end,
  })
end

--- Describe bytes as a reader can check them against a terminal reference.
--- @param bytes string
--- @return string
local function _describe_bytes(bytes)
  local parts = {}
  for i = 1, #bytes do
    table.insert(parts, string.format("0x%02x", bytes:byte(i)))
  end
  return table.concat(parts, " ")
end

--- Check every link between <C-'> and a Claude Code recording.
---
--- The press crosses four boundaries -- Neovim's keymap, the terminal channel,
--- Claude Code's keybindings file, and its voice settings -- and a break in any
--- one of them is silent at the key. Each is named here so a report points at
--- the link that failed instead of at the symptom.
---
--- @return table issues Messages for the broken links, empty when the chain holds
--- @return table notes Informational lines describing the working chain
function M.claude_health()
  local issues = {}
  local notes = {}

  local bindings = _claude_ptt_bindings()
  if vim.fn.filereadable(CLAUDE_KEYBINDINGS_FILE) ~= 1 then
    table.insert(issues, CLAUDE_KEYBINDINGS_FILE .. " not found - Claude Code has no "
      .. CLAUDE_PTT_ACTION .. " binding to drive")
  elseif #bindings == 0 then
    table.insert(issues, "no key bound to " .. CLAUDE_PTT_ACTION .. " in "
      .. CLAUDE_KEYBINDINGS_FILE)
  end

  local contexts = {}
  for _, binding in ipairs(bindings) do
    contexts[binding.context] = true
    table.insert(notes, string.format("bound: %s -> %s (context %s)",
      binding.key, CLAUDE_PTT_ACTION, binding.context))
  end
  if #bindings > 0 and not contexts["Chat"] and not contexts["Global"] then
    table.insert(issues, CLAUDE_PTT_ACTION
      .. " is bound outside the Chat and Global contexts, where the prompt never sees it")
  end

  local key, source, rejected = _resolve_claude_ptt_key()
  for _, entry in ipairs(rejected) do
    table.insert(issues, string.format(
      "%s is bound to %s but cannot be delivered from Neovim: %s",
      entry.key, CLAUDE_PTT_ACTION, entry.reason))
  end

  local bytes, reason = _legacy_ctrl_byte(key)
  if bytes then
    table.insert(notes, string.format("sending: %s as %s (from %s)",
      key, _describe_bytes(bytes), source))
  else
    table.insert(issues, string.format("push-to-talk key %s has no terminal encoding: %s",
      key, tostring(reason)))
  end

  if vim.fn.filereadable(CLAUDE_SETTINGS_FILE) ~= 1 then
    table.insert(issues, CLAUDE_SETTINGS_FILE .. " not found - voice mode state is unknown")
  else
    local enabled = _claude_voice_enabled()
    if enabled == false then
      table.insert(notes, "voice mode is off; the first press sends /voice "
        .. _claude_voice_mode() .. " to enable it")
    elseif enabled == nil then
      table.insert(issues, "voice mode state is unreadable in " .. CLAUDE_SETTINGS_FILE)
    else
      table.insert(notes, "voice mode is on")
    end

    local mode = _claude_active_voice_mode()
    if mode == nil then
      table.insert(issues, "voice.mode is unreadable in " .. CLAUDE_SETTINGS_FILE)
    elseif mode ~= "hold" then
      table.insert(issues, string.format(
        "voice.mode is %q; hold is required, since tap submits any transcript of three or more words",
        mode))
    else
      table.insert(notes, "voice.mode is hold, so the transcript lands in the prompt")
    end
  end

  return issues, notes
end

function M.health()
  local config = get_config()
  local issues = {}

  if not command_exists("parecord") then
    table.insert(issues, "parecord not found - install pulseaudio-utils or pipewire-pulse")
  end

  if not command_exists("python3") then
    table.insert(issues, "python3 not found")
  end

  if vim.fn.filereadable(config.transcribe_script) ~= 1 then
    table.insert(issues, "Transcription script not found at " .. config.transcribe_script)
  end

  if vim.fn.isdirectory(config.model_path) ~= 1 then
    table.insert(issues, "Vosk model not found at " .. config.model_path)
  end

  local claude_issues, claude_notes = M.claude_health()
  for _, note in ipairs(claude_notes) do
    notify("Claude Code: " .. note, vim.log.levels.INFO)
  end
  vim.list_extend(issues, claude_issues)

  if #issues == 0 then
    notify("All dependencies satisfied!", vim.log.levels.INFO)
    return true
  else
    for _, issue in ipairs(issues) do
      notify("Issue: " .. issue, vim.log.levels.ERROR)
    end
    return false
  end
end

function M.setup(opts)
  opts = opts or {}

  if opts.model_path then
    vim.g.stt_model_path = opts.model_path
  end
  if opts.transcribe_script then
    vim.g.stt_transcribe_script = opts.transcribe_script
  end
  if opts.record_timeout then
    vim.g.stt_record_timeout = opts.record_timeout
  end
  if opts.sample_rate then
    vim.g.stt_sample_rate = opts.sample_rate
  end

  if opts.keymaps ~= false then
    if opts.keymaps == true then
      local keymap_opts = { noremap = true, silent = true }
      vim.keymap.set('n', '<leader>vr', M.start_recording, vim.tbl_extend("force", keymap_opts, { desc = "STT: Start recording" }))
      vim.keymap.set('n', '<leader>vs', M.stop_recording, vim.tbl_extend("force", keymap_opts, { desc = "STT: Stop recording" }))
      vim.keymap.set('n', '<leader>vv', M.toggle_recording, vim.tbl_extend("force", keymap_opts, { desc = "STT: Toggle recording" }))
      vim.keymap.set('n', '<leader>vh', M.health, vim.tbl_extend("force", keymap_opts, { desc = "STT: Health check" }))
    end
  end

  vim.api.nvim_create_user_command('STTStart', M.start_recording, { desc = 'Start STT recording' })
  vim.api.nvim_create_user_command('STTStop', M.stop_recording, { desc = 'Stop STT recording' })
  vim.api.nvim_create_user_command('STTToggle', M.toggle_recording, { desc = 'Toggle STT recording' })
  vim.api.nvim_create_user_command('STTHealth', M.health, { desc = 'Check STT dependencies' })

  vim.api.nvim_create_user_command('STTClaudeVoice', function()
    local bufnr = vim.api.nvim_get_current_buf()
    if not _is_claude_code_buffer(bufnr) then
      notify("Not a Claude Code buffer", vim.log.levels.WARN)
      return
    end
    _send_claude_voice(bufnr)
  end, { desc = 'STT: Toggle Claude Code voice mode' })

  -- <C-'> context-aware dictation
  -- Claude Code buffers: toggle voice mode (use Space for PTT)
  -- All other buffers: Vosk STT toggle

  vim.keymap.set('n', "<C-'>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    if _is_claude_code_buffer(bufnr) then
      _send_claude_ptt(bufnr)
    else
      M.toggle_recording()
    end
  end, {
    noremap = true,
    silent = true,
    desc = "STT: Toggle dictation (Ctrl-')"
  })

  vim.keymap.set('i', "<C-'>", function()
    M.toggle_recording()
  end, {
    noremap = true,
    silent = true,
    desc = "STT: Toggle dictation (insert mode, Ctrl-')"
  })

  vim.keymap.set('t', "<C-'>", function()
    local bufnr = vim.api.nvim_get_current_buf()
    if _is_claude_code_buffer(bufnr) then
      _send_claude_ptt(bufnr)
    else
      vim.cmd('stopinsert')
      M.toggle_recording()
      vim.schedule(function()
        vim.cmd('startinsert')
      end)
    end
  end, {
    noremap = true,
    silent = true,
    desc = "STT: Toggle dictation (terminal mode, Ctrl-')"
  })

end

return M
