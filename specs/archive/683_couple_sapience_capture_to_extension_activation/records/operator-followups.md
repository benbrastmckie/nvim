# Operator Follow-Ups: Capture/Activation Coupling

This record names the two operator-owned follow-ups this implementation deliberately does not
perform itself (an agent in this repository never pushes, never runs the installer for real,
and never runs the vendor's interactive onboarding chooser), plus the one caveat the acceptance
test will visibly expose.

## Follow-Up 1: Refresh the User-Level Hook/Writer, Then Run the Acceptance Test

The `SessionStart` hook and its writer now live only in this repository's source store
(`agent-system/extensions/sapience/hooks/sapience-mcp-register-project.sh` and
`agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`) and in the regenerated
`.claude/` deploy tree. Neither is yet installed at the stable user-level path
(`$HOME/.claude/hooks/...`, `$HOME/.claude/scripts/...`) that every repository's `SessionStart`
hook actually invokes.

**Operator steps**:
1. Run `bash .claude/scripts/install-sapience-mcp-session-hook.sh` (without `--dry-run`) from
   this repository, to copy the updated hook and writer into `$HOME/.claude/{hooks,scripts}/`.
2. With the sapience extension loaded in `/home/benjamin/Projects/Sapience/sf1-engine` and that
   repository's own agent system reloaded, start a new session there. The hook should add
   `sf1-engine` to `sapience projects` as `enabled`.
3. Unload the sapience extension in that repository and start another new session. The hook
   should turn `sf1-engine` back to `disabled`.

This confirms the coupling end to end against the real vendor CLI and a real repository, which
no fixture-HOME test in this task can do.

## Follow-Up 2: Mirror the Diff Into `~/.dotfiles`

`~/.dotfiles/.claude/hooks/sapience-mcp-register-project.sh` and its companion writer were
byte-identical to this source store's copies before this implementation landed. They now
diverge: the `~/.dotfiles` copies do not yet carry the capture-coupling changes
(`--capture-set`, `--reap-capture`, the `GIT_ROOT`-keyed capture call, or the extended header
caveats).

**Operator step**: file a task in the `~/.dotfiles` repository to apply the equivalent diff to
its own copies of the hook and the writer, restoring byte-identity. This cannot be done from
this repository: `~/.dotfiles` is a different git repository, and per the source-store/deploy
boundary's task-siting rule, a task whose edit target is a path in that repository must be
created there, not here.

## The `folders` Caveat on the Acceptance Test

`/home/benjamin/Projects/Sapience/sf1-engine` is in neither `~/.sapience/config.json`'s
`capture.projects[]` list nor its legacy top-level `folders` list today. Running the acceptance
test above will show `sf1-engine` as `enabled` in `sapience projects` -- the coupling this
implementation adds -- but its transcripts stay ungated by `folders` until the operator runs the
vendor's own interactive onboarding chooser once, from a real terminal, to add `sf1-engine`'s
folder name to the saved selection. An `enabled: true` capture entry is not, by itself, evidence
that this repository's transcripts are being read; see
`agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`'s "The
`folders` Double-Gate" subsection for the full mechanism and why no safe, non-interactive,
single-writer path to grow `folders` exists.
