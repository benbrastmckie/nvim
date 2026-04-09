# Teammate D Findings: Strategic Horizons for Voice Integration

## Role: Horizons Researcher
**Task 377**: Add ctrl-based keymap for triggering dictation in Neovim with Claude Code sidebar voice recording support
**Date**: 2026-04-08

---

## Key Findings

### Current State of Voice Integration

This Neovim configuration already has a mature STT foundation in place:

- **Existing STT plugin**: `lua/neotex/plugins/tools/stt/init.lua` — offline Vosk-based speech-to-text with full lifecycle (start/stop/toggle/transcribe-and-insert)
- **Existing keymaps**: `<leader>vr/vs/vv/vh` for recording, plus `<C-\>` in normal mode, `<C-'>` in terminal mode (specifically noted as "for Claude Code sidebar")
- **Centralized keymap architecture**: `lua/neotex/config/keymaps.lua` is the single source of truth for non-leader mappings; `which-key.lua` owns leader mappings
- **Existing TTS integration**: Claude Code hooks (`tts-notify.sh`) already provide audio output side; STT provides input side — the bidirectional voice loop is structurally present
- **Lualine infrastructure**: Custom `claude-status` and `claude-code` extensions already display AI state in the statusline; a recording indicator could follow the same pattern

### Ctrl Keymap Landscape (Occupied Slots)

The following `<C-*>` bindings are taken in normal mode:
`<C-c>`, `<C-CR>`, `<C-g>`, `<C-h/j/k/l>`, `<C-i>`, `<C-m>`, `<C-n>` (markdown-local), `<C-p>`, `<C-s>`, `<C-t>`, `<C-u>`, `<C-d>`, `<C-z>`, `<C-;>`

The following are **available** for a new dictation toggle:
`<C-'>`, `<C-\>`, `<C-q>`, `<C-e>`, `<C-a>`, `<C-b>`, `<C-f>`, `<C-r>` (insert-only by default), `<C-x>`, `<C-y>`, `<C-v>` (visual block — avoid), `<C-o>` (jump list — avoid)

Note: `<C-'>` is already mapped in terminal mode for Claude Code sidebar. `<C-\>` is already the normal-mode STT toggle. The task is likely about making `<C-\>` or `<C-'>` work **specifically** and reliably inside the Claude Code terminal sidebar, or adding a new dedicated ctrl binding that works consistently across all contexts (normal, insert, terminal).

### No ROAD_MAP.md Exists

No `specs/ROAD_MAP.md` was found. The project's direction must be inferred from the task history and CHANGE_LOG. The pattern visible in completed tasks shows a trajectory toward:
1. AI-assisted editing as the primary workflow (Claude Code integration)
2. Bidirectional voice interaction (TTS notifications + STT input)
3. Offline, privacy-preserving tools (Vosk, Piper — no cloud APIs)
4. Tight WezTerm/NixOS integration with system-level audio

---

## Strategic Recommendations

### 1. The Immediate Task Is Completing an Existing Vision

The existing `stt/init.lua` already defines `<C-\>` (normal) and `<C-'>` (terminal) as the ctrl-based dictation keymaps. The task is most likely about verifying these work correctly in the Claude Code sidebar context, fixing any gaps (e.g., the terminal-mode `<C-'>` implementation that temporarily exits insert mode), and possibly registering the bindings in `keymaps.lua` rather than in `stt/init.lua` to match the centralized architecture.

**Strategic recommendation**: Align the STT ctrl mappings with the centralized keymap pattern in `keymaps.lua`, not the ad-hoc approach in `stt/init.lua`. This creates a unified map for discovery and prevents future conflicts.

### 2. Future-Proof for API Evolution

The current implementation couples hard to `parecord` (PulseAudio) and `vosk`. Two risks:
- **PulseAudio deprecation**: NixOS is moving more systems to PipeWire-native; `parecord` already works via `pipewire-pulse` compatibility, but a future NixOS update could break this. Design the recording backend as an abstracted function so it can be swapped.
- **Vosk model drift**: Vosk models are static downloads; if a better small offline model emerges (Whisper.cpp, sherpa-onnx), the transcription script should be replaceable without touching the Neovim plugin.

**Strategic recommendation**: The `get_config()` function in `stt/init.lua` already supports `vim.g.*` overrides. This is the right pattern — extend it to support a `recording_backend` config option (`parecord` or `pipewire`) to handle future system changes gracefully.

### 3. Design for Claude Code API Evolution

Claude Code's sidebar is currently a terminal buffer (`buftype=terminal`). Voice integration via terminal-mode keymaps is fragile because:
- Terminal keymaps bypass Neovim's normal keymap handling
- `<C-\><C-n>` is a reserved escape in terminal mode (exit to normal) — this is why `<C-'>` was chosen instead
- If Claude Code moves to a non-terminal sidebar (e.g., a dedicated buffer type), the `t` mode keymaps would break

**Strategic recommendation**: The implementation should detect the sidebar context programmatically (check `vim.bo.filetype == "claude-code"`) and route accordingly, rather than relying solely on terminal mode. A buffer-local normal-mode mapping for Claude Code buffers would be more robust long-term.

### 4. Context-Aware Dictation Is a High-Value Future Feature

The current STT inserts text at cursor position unconditionally. For the Claude Code sidebar, the natural behavior would be to compose and send a voice message — not just insert text. This is the largest gap between current implementation and ideal UX.

**Strategic recommendation**: Add a context detection layer:
- If the current buffer is `filetype == "claude-code"`, dictation should: transcribe -> append to input area -> (optionally) send
- If in a code buffer, dictation inserts at cursor (current behavior)
- If in a markdown/prose buffer, dictation inserts at cursor with sentence capitalization

This context awareness is the difference between a keymap shortcut and a truly voice-integrated workflow.

---

## Adjacent Opportunities

### Short-term (Next 1-3 tasks)

1. **Statusline recording indicator**: The lualine already has custom extensions for Claude Code status. Adding a recording state indicator (`[REC]` or pulsing icon) in `lualine_c` when `is_recording` is true would provide essential feedback during the ~2-5 second delay between start and stop. This follows the exact same pattern as `neotex.util.claude-status`.

2. **which-key registration for `<C-\>`**: The normal-mode `<C-\>` STT toggle is currently set directly in `stt/init.lua` outside the `setup()` flow. It should be documented in `keymaps.lua` alongside other global ctrl mappings for discoverability.

### Medium-term (3-6 months)

3. **Voice for commit messages**: The git commit workflow (via `keymaps.lua` + Claude Code) could benefit from voice input. A dedicated `<C-'>` binding in fugitive/diffview buffers could dictate commit messages directly.

4. **Voice for code comments**: Insert mode `<C-'>` could trigger dictation for inline documentation — speak a comment, it gets inserted as `-- <transcribed text>` or `// <transcribed text>` based on filetype.

5. **Whisper.cpp migration path**: `whisper.cpp` (C++ implementation of OpenAI Whisper) now runs offline on CPU with better accuracy than Vosk small models. The transcription script abstraction in `get_config()` makes this a simple swap. Worth researching as a quality upgrade.

### Long-term (6-12 months)

6. **Multi-modal input for Claude Code**: As Claude Code gains more capabilities, voice + visual context (screenshot of current buffer state) could allow natural language code editing commands — "refactor the function on line 23 to use error handling." This is where voice becomes transformative rather than just a text input shortcut.

7. **Voice Neovim commands**: A "command mode by voice" feature — say "find files" to trigger Telescope, "toggle terminal" to open ToggleTerm — would extend the voice paradigm beyond text input to navigation. This is technically feasible by mapping transcribed phrases to Neovim commands, though it requires higher accuracy transcription.

8. **Session-aware voice**: Integrating with the existing claude session manager (`neotex.plugins.ai.claude.core.session-manager`) so that voice input is automatically associated with the correct Claude Code session when multiple sessions are open.

---

## Confidence Level

**Overall confidence**: High

**Rationale**:
- The existing codebase was fully read and the current STT implementation is well-understood
- The ctrl keymap inventory was derived from actual source files, not documentation
- The strategic recommendations follow directly from the existing architecture patterns
- The adjacent opportunities are grounded in existing plugin patterns (lualine extensions, session manager) that already demonstrate the required infrastructure

**Uncertainty areas** (medium confidence):
- Whether `<C-'>` reliably works in the Claude Code terminal buffer across different terminal emulators (only WezTerm is documented as tested)
- Whether Claude Code's sidebar buffer type will remain `terminal` in future versions
- The performance characteristics of Whisper.cpp on this specific system (NixOS + the user's hardware is unknown)
