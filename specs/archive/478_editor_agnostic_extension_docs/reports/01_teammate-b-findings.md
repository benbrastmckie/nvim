# Teammate B Findings: Alternative Patterns and Prior Art

**Task 478**: Make extension core docs editor-agnostic and handle project-overview.md per-project generation

---

## Key Findings

### 1. Existing Guidance in This Repository (Already Partially Done)

The `claudemd.md` source already contains the right hint text:

```
**New repository setup**: If project-overview.md doesn't exist, see
`.claude/context/repo/update-project.md` for guidance on generating
project-appropriate documentation.
```

This appears in `extensions/core/merge-sources/claudemd.md` (line 28) and propagates to the
generated `.claude/CLAUDE.md`. However, this is **passive documentation** -- it requires Claude to
notice the missing file and consult the hint. The gap is that there is no active detection
mechanism and no clear instruction for Claude to create a task when the file is missing.

The `index.json` entry for `repo/project-overview.md` uses `"always": true`, meaning it is always
loaded regardless of agent or task type. This means **every Claude Code session** tries to load
this file -- if it is missing (in a non-nvim project after sync), Claude will see a broken
@-reference and no content.

### 2. The Four Files with Editor-Specific References

Found by scanning `.claude/extensions/`:

| File | Reference | Context |
|------|-----------|---------|
| `extensions/README.md` line 42 | `<leader>ac` | "Neovim: `<leader>ac` \| OpenCode: `<leader>ao`" -- already editor-agnostic! Shows the dual pattern |
| `extensions/core/context/repo/project-overview.md` line 11 | `<leader>ac` | "The extension picker (`<leader>ac`) triggers the loader..." -- nvim-specific prose |
| `extensions/core/context/guides/loader-reference.md` line 141 | `<leader>ac` | "Provides the extension browser launched from `<leader>ac`" -- nvim-specific table |
| `extensions/core/context/guides/extension-development.md` line 143 | `<leader>ac` | "Load via the extension picker (`<leader>ac`)" -- checklist item |
| `extensions/core/templates/extension-readme-template.md` line 50 | `<leader>ac` | "Loaded via `<leader>ac` in Neovim" -- template with explicit Neovim mention |

**Key observation**: `extensions/README.md` already uses a good pattern: it shows both bindings
side-by-side. The other four files use only the Neovim binding. The template explicitly says
"in Neovim," which is the worst offender.

---

## Alternative Approaches: Editor-Agnostic Documentation

### Approach A: Generic Prose (Simplest)

Replace `<leader>ac` with "the extension picker" everywhere. This is what the task description
suggests as the primary approach. Evidence that this works: the `extensions/README.md` already
shows the dual binding pattern -- but even better, the Loading Extensions section prose just says
"Extensions are loaded via the editor's extension picker." No keycode needed.

**Verdict**: Cleanest for context files that go to other projects. Context files are read by
Claude agents who don't need to know the keycode -- they need to know the _concept_.

### Approach B: Placeholder/Variable Substitution (More Complex)

Insert a `{EXTENSION_PICKER_KEY}` token during sync that gets substituted by the loader.

**Feasibility assessment** (from reading `loader.lua` via loader-reference.md):
- The loader's `copy_context_dirs()` and `copy_simple_files()` use plain file copy semantics --
  they read source bytes and write to target. There is no template substitution step.
- Adding substitution would require modifying `loader.lua` to post-process copied files.
- The merge.lua `generate_claudemd()` function also does concatenation, not substitution.
- This adds complexity to the loader for marginal benefit: agents don't need keycodes, and humans
  look at the actual editor, not the synced docs.

**Verdict**: Over-engineered for this use case. The loader was not designed for text substitution.
Adds complexity without value -- agents reading the context don't need to invoke the picker.

### Approach C: Loader-Side Stripping During Copy

Have the loader strip or replace editor-specific content blocks during copy (e.g., strip lines
matching `<leader>ac`).

**Feasibility**: Same constraint as Approach B -- the loader does plain file copies. Would require
a new "sanitize" step. Also fragile: hard to enumerate all editor-specific markers.

**Verdict**: Even more complex than B, with higher fragility.

### Approach D: Per-Editor Source Files

Maintain `project-overview.nvim.md` and `project-overview.md` (generic) separately, selecting
which to copy based on target system.

**Verdict**: Doubles the maintenance burden for each file. Not recommended.

**Recommended approach for editor-agnostic docs**: Approach A (generic prose). The four files
should simply drop keycodes and use "the extension picker" as generic language. This is what
`extensions/README.md`'s prose section already models.

---

## Alternative Approaches: project-overview.md Detection

### Pattern Analysis from Industry Tools

**Scaffolding tools (Yeoman, Create React App, Angular CLI)**:
- These tools use an _interactive prompting_ pattern: when configuration is missing, they ask the
  user interactively before proceeding. The standard library is `Inquirer.js` (Node) or
  `click.prompt()` (Python).
- **Applicability**: Claude Code agents can use `AskUserQuestion` for similar interactive prompting,
  but the question is _when_ to trigger it, not _how_.

**CLI tools with missing config detection (Task/Taskfile, Claude Task Master)**:
- Common pattern: detect-and-warn with fallback defaults. "Configuration file not found at derived
  root... Using defaults."
- The tool continues operating but logs a warning. More aggressive tools create a `--init` command
  that generates a starter config.
- **Applicability**: The agent could operate with degraded context but warn -- similar to the
  existing hint text. The gap is the hint is passive.

**AI agent documentation tools (Red Hat TechDocs, Packmind)**:
- An emerging 2024-2025 pattern: AI agents that scan repositories, detect documentation gaps, and
  automatically generate the necessary structure and initial content. The detection is done at
  session start as a preflight check.
- **Applicability**: This is exactly the target pattern. The preflight check for
  `project-overview.md` maps directly to this pattern.

### Three Detection Mechanism Patterns

**Pattern 1: Sentinel File (Always-Load Rule)**

The `index.json` already marks `repo/project-overview.md` as `"always": true`. This means the
absence is already detectable: if the @-reference in CLAUDE.md fails to resolve, or if a preflight
bash check fails (`[ -f .claude/context/repo/project-overview.md ]`), Claude knows to act.

The simplest implementation: add a guard in `claudemd.md` that instructs Claude what to do when
the file is missing:

```markdown
**Project-specific structure**: See `.claude/context/repo/project-overview.md` for details.
If that file does not exist yet, use `/task` to create a task for generating it by following
`.claude/context/repo/update-project.md`.
```

This is already partially present -- the existing text says "see update-project.md" but does not
tell Claude to create a task. The enhancement is instructing Claude to create a task proactively
rather than just pointing at a doc.

**Confidence**: High. This is the lowest-cost change with high reliability.

**Pattern 2: Hook-Based Detection**

A `post-command.sh` hook or a preflight script that runs `[ -f .claude/context/repo/project-overview.md ]`
and emits a warning when the file is missing. The hook could write a marker that Claude checks.

**Feasibility**: The loader already has hooks (`log-session.sh`, `post-command.sh`, etc.). Adding
a `check-project-overview.sh` hook is mechanically straightforward. However, hooks run outside
Claude's context window -- they can write to files, but Claude would need to explicitly read those
files to act on them.

The existing `memory-nudge.sh` hook is a good analogy: it writes a nudge file that Claude reads
during preflight. A similar `project-overview-nudge.sh` could write a flag file.

**Confidence**: Medium. Works but adds a hook file + a new reading step in preflight patterns.
More moving parts than the claudemd.md text approach.

**Pattern 3: Always-Load Rule File**

Create a new rule file (auto-applied by CLAUDE.md) that contains the detection logic as a
behavioral instruction. Claude reads rules automatically; a rule saying "if
`.claude/context/repo/project-overview.md` does not exist, create a task for it" would be acted on
without the user doing anything.

Example rule (`.claude/rules/project-overview-check.md`):
```markdown
## Project Overview Check

When starting any session, check if `.claude/context/repo/project-overview.md` exists using Bash.
If it does not exist:
1. Inform the user that project-overview.md is missing
2. Offer to create a task: `/task "Generate project-overview.md for this repository"`
3. Reference `.claude/context/repo/update-project.md` for the generation process
```

**Feasibility**: Rules are auto-applied by Claude Code via the `.claude/rules/` directory. This
would fire on every session. However, it adds overhead to every session including sessions in the
nvim project where project-overview.md always exists.

**Alternative**: Make this a conditional rule only loaded when `project-overview.md` is absent --
but there is no mechanism for conditional rule loading based on file existence.

**Confidence**: Medium. Clean pattern but fires universally, including projects that already have
the file.

---

## Recommended Approach (Synthesis)

### For Editor-Agnostic Language

**Use generic prose everywhere in the four offending files.** Replace `<leader>ac` and "in Neovim"
with "the extension picker". This matches what the extensions/README.md prose section already does.
The pattern is: "Load via the extension picker" with no keycode.

The `extension-readme-template.md` needs the most attention because it explicitly says "in Neovim"
-- this is what will propagate to new extensions' READMEs. Change the template first.

### For project-overview.md Missing Detection

**Two-change approach** (complementary, not competing):

1. **Enhance the claudemd.md instruction** (zero-cost, highest confidence): Change the existing
   passive hint to an active instruction. Current text says "see update-project.md". Add: "If the
   file does not exist, create a task to generate it by running `/task "Generate project-overview.md"`
   and following update-project.md." This makes Claude's behavior deterministic without adding
   files.

2. **Exclude project-overview.md from core extension sync** (separate concern): Remove
   `repo/project-overview.md` from the `provides.context` list in the core extension's
   `manifest.json` so it is not overwritten when the core extension is synced to a new project. The
   file should be project-specific, not core-extension-provided. The `update-project.md` guide
   already explains how to generate it.

   This is the cleaner long-term solution: project-overview.md lives only in the target project, is
   never synced from the core extension, and when absent, the enhanced claudemd.md instruction tells
   Claude to create a task.

**The key insight**: The existing `update-project.md` guide + the existing claudemd.md hint already
form 80% of the solution. The gap is:
- The hint is passive ("see this doc") not active ("create this task")
- project-overview.md should not be in the core extension's `provides.context` at all (it belongs
  to the project, not to the extension)

---

## Evidence and Examples

### Existing Pattern in this Repo (extensions/README.md)

```markdown
## Loading Extensions
Extensions are loaded via the editor's extension picker:
- Neovim: `<leader>ac` | OpenCode: `<leader>ao`
```

This shows the right model for the few places where a keycode IS needed (user-facing docs, not
agent context): show both editors side-by-side. But for agent context files (`context/repo/`,
`context/guides/`), no keycodes are needed at all.

### Existing Passive Hint (merge-sources/claudemd.md line 28)

```markdown
**New repository setup**: If project-overview.md doesn't exist, see
`.claude/context/repo/update-project.md` for guidance on generating project-appropriate documentation.
```

Enhancement: add explicit task creation instruction.

### Industry Pattern: Red Hat TechDocs Agent (2025)

> "An AI agent can help documentation keep pace with the SDLC by intelligently scanning
> repositories, detecting gaps, and automatically generating the necessary TechDocs structure
> and initial content."

This validates the preflight-check-and-create-task pattern as a recognized 2024-2025 best practice.

### Industry Pattern: Yeoman Generators

Yeoman generators use Inquirer.js `prompting()` lifecycle hooks to detect missing config and ask
users interactively before generating. The Claude equivalent is: detect missing file in preflight,
use AskUserQuestion, then create task if user confirms.

---

## Confidence Levels

| Finding | Confidence |
|---------|-----------|
| Four files contain `<leader>ac` | High (verified by grep) |
| Generic prose replacement is correct approach for agent context | High |
| project-overview.md should be excluded from core sync | High |
| Enhancing claudemd.md passive hint to active task instruction | High |
| Placeholder/substitution approach is over-engineered | High |
| Hook-based detection is viable but adds complexity | Medium |
| Always-load rule file approach works but fires universally | Medium |

---

## Files Identified for Change

1. `/home/benjamin/.config/nvim/.claude/extensions/core/context/repo/project-overview.md`
   - Line 11: Replace `<leader>ac` with "the extension picker"
   - This file itself may need to be excluded from core extension sync (it's nvim-specific content)

2. `/home/benjamin/.config/nvim/.claude/extensions/core/context/guides/loader-reference.md`
   - Line 141: Replace `<leader>ac` with "the extension picker"

3. `/home/benjamin/.config/nvim/.claude/extensions/core/context/guides/extension-development.md`
   - Line 143: Replace `<leader>ac` with "the extension picker"

4. `/home/benjamin/.config/nvim/.claude/extensions/core/templates/extension-readme-template.md`
   - Line 50: Replace "Loaded via `<leader>ac` in Neovim" with "Loaded via the extension picker"

5. `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md`
   - Line 28: Enhance passive hint to include task creation instruction

6. `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json`
   - Consider removing `repo/project-overview.md` (or the entire `repo` directory) from
     `provides.context` so it is not overwritten during sync

7. `/home/benjamin/.config/nvim/.claude/extensions/core/index-entries.json`
   - The `repo/project-overview.md` entry has `"always": true` -- if the file is excluded from
     sync, this entry should either be removed from the core extension's index-entries.json or
     changed to not fire when the file is absent.

**Note**: Files in `.claude/context/` (not `.claude/extensions/core/context/`) are runtime
copies. Edits should target the extension source files. The runtime copies are regenerated on
loader sync.
