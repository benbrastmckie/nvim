/**
 * WezTerm integration plugin for opencode
 *
 * Provides:
 * - TTS notification when opencode finishes (session.idle)
 * - TTS notification when opencode needs input (permission.asked, question.asked)
 * - WezTerm amber tab indicator when opencode is waiting (session.idle)
 * - WezTerm task number/action display when workflow commands run (command.execute.before)
 * - WezTerm status clear when user responds (command.execute.before)
 *
 * Hook mapping (opencode event -> Claude Code equivalent):
 *   session.idle          -> Stop
 *   permission.asked      -> Notification/permission_prompt
 *   question.asked        -> Notification/elicitation_dialog
 *   command.execute.before -> UserPromptSubmit (for task number detection)
 *
 * NOTE: .opencode/settings.json hooks (Stop, UserPromptSubmit, Notification,
 * SessionStart) are Claude Code format and are ignored by opencode. This plugin
 * is the opencode equivalent.
 */
export const WeztermHooksPlugin = async ({ $, directory }) => {
  const hookDir = `${directory}/.opencode/hooks`;

  // Debounce TTS: multiple session.idle events fire when interrupting
  // (one per sub-agent). Only fire TTS once per burst.
  let lastTtsMs = 0;
  const TTS_DEBOUNCE_MS = 3000;

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        const now = Date.now();
        if (now - lastTtsMs < TTS_DEBOUNCE_MS) return;
        lastTtsMs = now;
        // Opencode finished responding - TTS + wezterm amber tab
        await $`bash ${hookDir}/tts-notify.sh`.cwd(directory).quiet().nothrow();
        await $`bash ${hookDir}/wezterm-notify.sh`.cwd(directory).quiet().nothrow();
      } else if (
        event.type === "permission.asked" ||
        event.type === "question.asked"
      ) {
        // Opencode needs input or is asking a question - TTS only
        await $`bash ${hookDir}/tts-notify.sh`.cwd(directory).quiet().nothrow();
      }
    },

    // Fires before a slash command executes - gives command name and arguments
    "command.execute.before": async (input, _output) => {
      const { command, arguments: args } = input;

      // Reconstruct prompt format expected by wezterm-task-number.sh
      // The script reads stdin JSON with a .prompt field matching /research N etc.
      const fakePrompt = `/${command} ${args ?? ""}`;
      const hookInput = JSON.stringify({ prompt: fakePrompt });

      await $`echo ${hookInput} | bash ${hookDir}/wezterm-task-number.sh`
        .cwd(directory).quiet().nothrow();

      // Clear the wezterm amber status since user submitted a new command
      await $`bash ${hookDir}/wezterm-clear-status.sh`
        .cwd(directory).quiet().nothrow();
    },
  };
};
