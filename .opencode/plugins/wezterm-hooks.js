/**
 * WezTerm integration plugin for opencode - DEBUG VERSION 2
 * Focused on diagnosing wezterm-task-number.sh execution
 */
import { appendFileSync } from "fs";

const LOG = "/tmp/opencode-plugin-debug.log";
const log = (msg) => {
  try {
    appendFileSync(LOG, `[${new Date().toISOString()}] ${msg}\n`);
  } catch {}
};

export const WeztermHooksPlugin = async ({ $, directory }) => {
  const hookDir = `${directory}/.opencode/hooks`;
  log(`Plugin loaded. directory=${directory}`);
  log(`WEZTERM_PANE env=${process.env.WEZTERM_PANE ?? "NOT SET"}`);

  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await $`bash ${hookDir}/tts-notify.sh`.cwd(directory).quiet().nothrow();
        await $`bash ${hookDir}/wezterm-notify.sh`.cwd(directory).quiet().nothrow();
      } else if (
        event.type === "permission.asked" ||
        event.type === "question.asked"
      ) {
        await $`bash ${hookDir}/tts-notify.sh`.cwd(directory).quiet().nothrow();
      }
    },

    "chat.message": async (input, output) => {
      const textPart = output.parts?.find((p) => p.type === "text");
      const prompt = textPart?.text ?? "";
      log(`CHAT.MESSAGE prompt="${prompt.substring(0, 120)}"`);

      const hookInput = JSON.stringify({ prompt });

      // Capture stdout and stderr from wezterm-task-number.sh
      const result = await $`echo ${hookInput} | bash ${hookDir}/wezterm-task-number.sh`
        .cwd(directory).quiet().nothrow();
      log(`wezterm-task-number exit=${result.exitCode} stdout="${result.text().trim()}" stderr="${result.stderr.toString().trim()}"`);

      await $`bash ${hookDir}/wezterm-clear-status.sh`.cwd(directory).quiet().nothrow();
    },
  };
};
