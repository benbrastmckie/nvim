# Research Report

**Task**: 682 - Stop writing the Sapience token into the per-project MCP entry in ~/.claude.json
**Started**: 2026-11-21T00:00:00Z
**Completed**: 2026-11-21T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`,
  `hooks/sapience-mcp-register-project.sh`, `scripts/verify-sapience-mcp.sh`,
  `scripts/tests/test-sapience-mcp-registration.sh`,
  `context/project/sapience/domain/per-repo-scoping.md`
- Vendor payload: `~/.sapience/mcp.py`, `~/.sapience/sapience_upkeep.py`
- Companion repo (read-only, for cross-reference, not edited):
  `~/.dotfiles/modules/home/services/sapience.nix`, `~/.dotfiles/docs/sapience.md`,
  `~/.dotfiles/packages/sapience-flake/{lib/wrappers.nix,checks/register-mcp.nix}`,
  `~/.dotfiles/packages/sf1-hub-ben/`
- Local filesystem permission checks (`ls -la`) on `~/.sapience/config.json`,
  `/run/secrets/sapience_token`, `~/.config/sf1-hub-ben/{env,sapience-token}`, `~/.claude.json`
**Artifacts**:
- `specs/682_sapience_mcp_entry_carries_no_token/reports/01_remove-token-from-mcp-entry.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `~/.sapience/mcp.py` resolves its credential through exactly one module-level statement
  (`TOKEN = os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token') or ''`) that runs once at
  import time, before any CLI-flag dispatch. Every invocation shape the task names — the bare
  stdio server, `--briefing-text`, `--receipt`, `--effect-line` — executes this identical line,
  so **all four already fall back to `~/.sapience/config.json`'s `.token` with
  `SAPIENCE_TOKEN` unset**. No code path was found that requires the environment variable.
- `setup-sapience-mcp.sh`'s own `generate_sapience_config()` is the only place that currently
  puts `SAPIENCE_TOKEN` into the written entry at all, and it already does so conditionally
  (`if ($token | length) > 0`). The fix is to drop that conditional branch entirely — write
  `env: { SAPIENCE_HOST: $host }` only, always — rather than add a new fallback.
- This extension's own helper library (`scripts/lib/sapience-api-lib.sh`) already resolves its
  token the same way (env, else `config.json`) and is unaffected either way — confirming the
  env→config.json fallback is this extension's established pattern, not a new assumption.
- `verify-sapience-mcp.sh` check (b) currently *expects* `SAPIENCE_TOKEN` to be present whenever
  `config.json` carries a token (`EXPECTED_HAS_TOKEN=true` branch at
  `scripts/verify-sapience-mcp.sh:266-270`) and fails a token-absent entry in that case. This
  must be inverted: the canonical shape becomes "never present," and a token-bearing entry
  becomes the failure.
- `scripts/tests/test-sapience-mcp-registration.sh` already has "Case 7: token-absent fallback"
  (only covering the *no-token-in-config.json* branch). It has no case covering the symmetric,
  more important branch — a token **present** in `config.json` still must not appear in the
  written entry. That is the gap the task's item (4) asks to close, with a negative-control
  fixture.
- Every other on-disk location the token exists (`/run/secrets/sapience_token`,
  `~/.sapience/config.json` and its `.bak-*` siblings, `~/.config/sf1-hub-ben/{env,sapience-token}`)
  is `0400`/`0600`, owned by the user, and not committed to any repository in plaintext — the
  one git-tracked artifact, `~/.dotfiles/secrets/secrets.yaml`, holds it sops-encrypted. No
  world-readable or committed copy was found anywhere on this machine.
- A second, unrelated writer exists in the companion dotfiles repo
  (`~/.dotfiles/packages/sapience-flake/lib/wrappers.nix`'s `sapience-register-mcp`) that *does*
  still write `SAPIENCE_TOKEN` into a top-level `.mcpServers.sapience` entry when one is
  resolvable — but it is not wired into `modules/home/services/sapience.nix` (no reference to
  it in that file) and is therefore dead/orphaned code on this machine, not a live second
  write path. It is out of this task's territory (a different repository) and is flagged here
  as a context gap, not fixed.

## Context & Scope

The task's build items (1)-(6) map to the investigation below:

1. Whether every `mcp.py` code path the MCP entry reaches resolves the token from
   `config.json` with `SAPIENCE_TOKEN` unset.
2. Whether the entry can therefore be written with `SAPIENCE_HOST` only, with existing entries
   migrated in place, idempotently, on the next `SessionStart` registration.
3. Whether `verify-sapience-mcp.sh` check (b) needs to invert its token-presence expectation.
4. What a regression test asserting "no value in the entry equals the configured token" (plus
   negative control) looks like, given the existing test file's structure.
5. Where `per-repo-scoping.md` should state the token's locations and the "never copy it here"
   boundary.
6. Whether every other on-machine location holding the token is non-world-readable and
   uncommitted, and who owns each.

Scope is the five files named in the dispatch's Territory: `scripts/setup-sapience-mcp.sh`,
`hooks/sapience-mcp-register-project.sh`, `scripts/verify-sapience-mcp.sh`,
`scripts/tests/test-sapience-mcp-registration.sh`, `context/project/sapience/domain/per-repo-scoping.md`
— all under `agent-system/extensions/sapience/` in this repository, the correctly-sited source
store for this edit per `.claude/rules/source-store-deploy-boundary.md`'s Task Siting rule.
`~/.sapience/mcp.py` itself is vendor-owned, mutable, self-updating state (per
`~/.dotfiles/docs/sapience.md`'s "do not fix the payload into a derivation" note) and is read-only
input to this research, never an edit target.

## Findings

### Codebase Patterns

**`setup-sapience-mcp.sh`'s `generate_sapience_config()`** (lines 339-351) is the sole writer of
the per-project entry's shape:

```
jq -n --arg command "$INTERPRETER" --arg script "$MCP_PY" --arg host "$HOST" --arg token "$TOKEN" \
    '{ type: "stdio", command: $command, args: [$script],
       env: ({ SAPIENCE_HOST: $host } + (if ($token | length) > 0 then { SAPIENCE_TOKEN: $token } else {} end)) }'
```

`$TOKEN` is resolved by `resolve_token()` (lines 312-322) from `~/.sapience/config.json`'s
`.token` field — the writer already prefers reading the token out of `config.json` over
accepting one from its own caller's environment; the fix at item (2) is simply removing the
`(if ($token|length)>0 then {SAPIENCE_TOKEN:$token} else {}end)` branch so the entry's `env` is
always exactly `{SAPIENCE_HOST: $host}`.

`process_write()`'s existing "whole-entry comparison and replacement" behavior (lines 410-465,
doc comment at 407-409) is precisely the mechanism item (2) needs for "migrate existing entries
in place on the next SessionStart registration, idempotently": because the entry is compared
and replaced as a whole (`entries_match=$(jq -n --argjson a "$existing_entry" --argjson b
"$canonical_entry" '$a == $b')`), a currently-token-bearing entry will simply be judged
"diverges from the sanctioned shape" the first time the writer runs after the fix and replaced
wholesale with the token-free canonical shape — no new migration code is needed. The
bidirectional `SessionStart` hook (`hooks/sapience-mcp-register-project.sh`) already invokes
this writer unconditionally on every session start for an active repo (line 167:
`bash "$WRITER" --project "$PROJECT_PATH" --scope project --quiet`), which is exactly the
"next SessionStart registration" the task names.

**`~/.sapience/mcp.py`'s token resolution is a single, shared module-level statement**, read
during this research (lines 34-44):

```python
def _saved_config():
    try:
        return json.load(open(os.path.join(os.path.expanduser('~'), '.sapience', 'config.json')))
    except Exception:
        return {}
_CFG  = _saved_config()
HOST  = (os.environ.get('SAPIENCE_HOST') or _CFG.get('host') or DEFAULT_HOST).rstrip('/')
TOKEN = os.environ.get('SAPIENCE_TOKEN') or _CFG.get('token') or ''
```

This runs once, at import, before `sys.argv` is ever inspected (CLI-flag dispatch happens later,
in the `if __name__ == '__main__':` block). Consequently every invocation shape named in the
task's build item (1) — the bare stdio server (no flags, the shape the MCP entry's
`command`/`args` spawn), `--briefing-text` (the `SessionStart` hook wired by
`sapience_upkeep.py`'s `wire_hooks()`, line 168), `--receipt` (`SessionEnd`, line 169), and
`--effect-line` (`Stop`, line 170) — executes the identical `TOKEN` assignment and falls back to
`config.json` identically when `SAPIENCE_TOKEN` is unset. **No divergent code path was found.**
`os.path.expanduser('~')` resolves via the passwd database when `HOME` is unset (not only via
the `HOME` env var), so this fallback holds even in a maximally stripped spawn environment,
independent of whatever environment-merging behavior the MCP client applies when spawning the
stdio server.

One narrow, out-of-the-named-four diagnostic path is worth flagging rather than silently passing
over: `mcp.py`'s `registered_tokens()` (lines 1887-1901), used by the `sapience status` CLI
command, reads `~/.claude.json`'s **top-level** `.mcpServers.sapience.env.SAPIENCE_TOKEN` — not
the per-project `.projects[path].mcpServers.sapience` entry this task concerns. Since the
top-level entry was already retired on this machine (per `setup-sapience-mcp.sh`'s and
`verify-sapience-mcp.sh`'s header comments — "the former machine-wide home-manager activation
has been retired, and registration is per-project only"), this diagnostic already reads `''`
for the Claude Code row regardless of what this task does to the per-project entry. Removing the
per-project token causes no regression here because this diagnostic was never looking at the
per-project entry to begin with; it is a pre-existing vendor-side staleness, not something this
task introduces or must fix.

**`verify-sapience-mcp.sh` check (b)** (lines 237-287) currently computes
`EXPECTED_HAS_TOKEN=true` whenever `~/.sapience/config.json` carries a non-empty `.token`
(lines 266-270), then fails when `ACTUAL_HAS_TOKEN` (`jq '.env | has("SAPIENCE_TOKEN")'`)
doesn't match. This is the exact inversion the task's item (3) names: the canonical shape must
become `EXPECTED_HAS_TOKEN` always `false`, and the mismatch message changed to name token
presence (not absence) as the defect — "entry carries a token; remedy: re-run the writer" — so a
regression is caught the same way a stale command/host already is.

**`scripts/tests/test-sapience-mcp-registration.sh`** already contains "Case 7: token-absent
fallback" (lines 268-282 approx.), asserting no `SAPIENCE_TOKEN` key when `config.json` carries
no token — but this is the branch that was never risky. The task's item (4) — "a test that a
registered entry contains no value equal to the configured token, with a negative control on a
fixture entry that does" — needs a **new** case, because today's suite has no coverage at all
for the branch that matters: `config.json` *does* carry a token. The negative control the task
asks for is naturally the current (soon-to-be-wrong) behavior: a hand-built fixture entry that
*does* embed the configured token value, asserted to be correctly flagged as non-canonical, so
the new assertion is proven to actually discriminate rather than vacuously pass. The file's own
header comment (lines 7-40) is a numbered case manifest per phase ("Writer cases (Phase 2):
... (7) Token-absent fallback ..."); a new case slots in as case 9's successor or is appended to
the existing numbered list, following the file's own convention of updating the header comment
alongside the new case body.

**`context/project/sapience/domain/per-repo-scoping.md`** currently says almost nothing about
the token specifically — a `grep` across the file surfaces only three incidental mentions (line
41 in an unrelated keyword-extraction description, line 44 about a different token on a
different subsystem, and line 105 about a request-body redaction). The task's item (5) — "state
in per-repo-scoping.md where the token lives and where it must never be copied" — is net-new
content, not a correction of something already stated incorrectly. The document's existing
"Hazards" section (heading at line 251) and "The MCP-Registration Triad" section (heading at
line 137) are the two natural homes: the Triad section already documents the writer/hook/
installer/verifier quartet in detail and is where a reader would look for "how does the entry
get its fields," while Hazards is where the document already collects numbered risk statements
like "there is no delete API."

### External Resources (companion repository, read-only cross-reference)

The `~/.dotfiles` repository (NOT in this task's territory; read for context only, never
edited) independently documents the same env→`config.json` fallback and the same per-repo
model: `~/.dotfiles/docs/sapience.md` states "the token... never enters the Nix store or this
repo -- every client falls back to `~/.sapience/config.json` when `SAPIENCE_TOKEN` is unset" and
names "the per-project registration writer (installed by the sapience extension, invoked by the
durable [SessionStart hook])" as the live mechanism — i.e. `setup-sapience-mcp.sh` and
`sapience-mcp-register-project.sh`, confirming this task's two in-scope scripts are indeed the
sole live per-project writer/hook pair on this machine.

A second writer, `~/.dotfiles/packages/sapience-flake/lib/wrappers.nix`'s
`sapience-register-mcp` (backed by a Nix check, `checks/register-mcp.nix`), still embeds the
token in a **top-level** `.mcpServers.sapience` entry whenever `config.json` carries one
(`register-mcp.nix`'s own test: "`--print` picks the token up from `config.json` when there is
one" asserts `entry.env.SAPIENCE_TOKEN` equals the stored token). `grep` across
`modules/home/services/sapience.nix` for any reference to this wrapper (`wrappers.`,
`register-mcp`, `sapienceRegisterMcp`) returns nothing — the function exists in the flake's
library and has a passing check, but is not invoked by the home-manager module that is actually
applied on this machine. This matches `setup-sapience-mcp.sh`'s own header note that "this
machine's home-manager activation no longer writes a top-level `.mcpServers.sapience` entry:
`modules/home/services/sapience.nix`'s `sapienceMcpServer` block and its `registerMcpServer`
option have been retired." The wrapper is therefore dead code (reachable only via its own Nix
check, never via an activated module path) rather than a live, undiscovered second write-path —
but it is a latent hazard if ever re-wired, and belongs to a different repository, so it is
reported here rather than fixed.

## Recommendations

1. **`setup-sapience-mcp.sh`**: in `generate_sapience_config()`, remove the `--arg token "$TOKEN"`
   plumbing and the `(if ($token|length)>0 then {SAPIENCE_TOKEN:$token} else {}end)` branch;
   write `env: { SAPIENCE_HOST: $host }` unconditionally. `resolve_token()` and its call site
   can be deleted outright (nothing else in this script consumes `$TOKEN`). No new migration
   logic is needed — `process_write()`'s existing whole-entry-replacement comparison already
   treats a token-bearing existing entry as "diverges from the sanctioned shape" and replaces it
   wholesale, so the very next `SessionStart` registration in a repo that already has an entry
   self-migrates it, idempotently, for free.
2. **`verify-sapience-mcp.sh`**: invert check (b)'s `EXPECTED_HAS_TOKEN` to a constant `false`
   (drop the `config.json`-token-presence branch that currently sets it `true`), and change the
   mismatch wording so a token-bearing entry is reported as the defect ("entry carries a token in
   `env.SAPIENCE_TOKEN`; remedy: re-run `setup-sapience-mcp.sh --scope project` to replace it
   with the token-free canonical shape") rather than the current "token presence mismatch"
   phrasing that assumes presence is sometimes correct.
3. **`scripts/tests/test-sapience-mcp-registration.sh`**: add a new case asserting that, given a
   `config.json` fixture carrying a known token value, the written entry contains that value
   nowhere (not in `env`, and defensively checked via a whole-entry `jq` scan rather than only
   the `env.SAPIENCE_TOKEN` key, in case a future change relocated it) — paired with a negative
   control: a hand-built fixture `~/.claude.json` entry that DOES embed the token, asserted to
   be correctly flagged non-canonical by the writer's own existing-entry comparison (or, for a
   verifier-level test, by `verify-sapience-mcp.sh`'s now-inverted check (b)). Update the file's
   header-comment case manifest alongside the new case body, matching its existing convention.
4. **`context/project/sapience/domain/per-repo-scoping.md`**: add a short, named subsection (a
   natural location is immediately after "The MCP-Registration Triad," or as a new entry in
   "Hazards") stating plainly: the token's durable homes are `/run/secrets/sapience_token`
   (sops-nix, 0400, owned by the `~/.dotfiles` repository) and `~/.sapience/config.json` (0600,
   owned by the vendor payload / `sapience-bootstrap`); it must never be copied into
   `~/.claude.json` (any scope) because that file is both frequently inspected in plaintext
   (`jq .projects[...]`, `claude mcp get`) and within reach of Sapience's own transcript-capture
   path, so a copy there is a secret that can round-trip into the vault it is meant to
   authenticate against. Name `~/.dotfiles` as the owner of the sops secret and `config.json`'s
   repair/seeding logic, consistent with this document's existing convention of naming the owning
   repository for anything outside `agent-system/extensions/sapience/`'s own control (see its
   existing "Token shape repair in `config.json` | This repo" framing cross-referenced from
   `~/.dotfiles/docs/sapience.md`).
5. Record the dead `sapience-register-mcp` wrapper (`~/.dotfiles/packages/sapience-flake/lib/wrappers.nix`)
   as a follow-up note for a future `~/.dotfiles`-sited task, not fixed here — it is out of this
   task's territory and currently unreachable from any applied module, so there is no live
   regression to close today, but a future re-wiring of `sapienceMcpServer`/`registerMcpServer`
   would reintroduce exactly the hazard this task closes in the per-project writer.

## Decisions

- Treat `~/.sapience/mcp.py` as read-only vendor payload throughout (per
  `~/.dotfiles/docs/sapience.md`'s explicit "do not fix the payload into a derivation" note) —
  the fix is entirely on the writer/verifier/test/doc side of the triad, never a vendor-file edit.
- Confirmed, by direct inspection of `~/.sapience/mcp.py`, that no measured code path requires
  `SAPIENCE_TOKEN` to be present in the environment; the task's conditional build step "(2) if
  all do, write SAPIENCE_HOST only" therefore applies unconditionally — there is no "(2) else"
  branch to design for.
- Scoped the dotfiles-repo `sapience-register-mcp` finding to a reported follow-up rather than a
  remediation, per the Territory contract (this dispatch's territory is
  `agent-system/extensions/sapience/` in this repository only) and per the Task Siting rule
  (a task whose edit target is a source-store path belonging to `~/.dotfiles` must be sited in
  that repository, which this dispatch is not).

## Risks & Mitigations

- **Risk**: the MCP client's environment-merge behavior when spawning the stdio server
  (whether `env` in the entry *replaces* or *overlays* the inherited process environment) was
  not independently verified by launching a fresh session during this research pass. **Mitigation**:
  this risk is structurally contained regardless of the answer, because `mcp.py`'s `config.json`
  read (`os.path.expanduser('~')`) resolves via the passwd database even with `HOME` absent from
  the spawn environment, and no other part of the four named code paths was found to depend on
  an inherited variable for token resolution. The implementation phase should still add one
  smoke-test invocation (e.g. `env -i HOME="$HOME" python3 ~/.sapience/mcp.py --statusline`) to
  make this verification explicit and mechanical rather than inferred.
- **Risk**: a regressed future edit to `setup-sapience-mcp.sh` or a new call site could
  reintroduce `SAPIENCE_TOKEN` into the entry without the existing test suite catching it, since
  today's Case 7 only exercises the token-absent-in-`config.json` branch. **Mitigation**: this is
  exactly recommendation 3 above (the new case with its negative control) — implementing it
  closes this gap directly.
- **Risk**: an operator-run `~/.dotfiles` `sapience-register-mcp --print`/apply, if ever rewired
  into `sapienceMcpServer`, would reintroduce a token-bearing **top-level** entry independent of
  anything this task changes in the per-project writer. **Mitigation**: out of this task's
  territory; flagged as a follow-up (Recommendation 5) rather than mitigated here.

## Context Extension Recommendations

- **Topic**: Token locations and copy-boundary for the Sapience credential.
- **Gap**: `per-repo-scoping.md` documents the per-project MCP-registration mechanism in detail
  but says nothing, anywhere in the file, about where the underlying credential itself durably
  lives or the specific hazard of copying it into `~/.claude.json`.
- **Recommendation**: add the subsection described in Recommendation 4 above during the
  implementation phase (this is the task's own item (5), not a separate follow-up task).

## Appendix

### Search Queries / Commands Used

- `grep -n "TOKEN\|getenv\|environ\|config.json\|SAPIENCE_TOKEN\|SAPIENCE_HOST" ~/.sapience/mcp.py`
- `grep -rn "SAPIENCE_TOKEN" ~/.bashrc ~/.zshrc ~/.profile ~/.config/environment.d/*.conf ~/.dotfiles`
- `grep -rln "SAPIENCE_TOKEN\|sapienceMcpServer\|sapience" ~/.dotfiles`
- `grep -n "registerMcpServer\|sapienceMcpServer\|sapience-register-mcp" ~/.dotfiles/modules/home/services/sapience.nix` (no output — confirmed unreferenced)
- `ls -la /run/secrets/sapience_token ~/.sapience/config.json* ~/.config/sf1-hub-ben/ ~/.claude.json`
- Direct reads: `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh`,
  `hooks/sapience-mcp-register-project.sh`, `scripts/verify-sapience-mcp.sh` (lines 200-330),
  `scripts/lib/sapience-api-lib.sh`, `~/.sapience/mcp.py` (lines 1-60, 1870-1930),
  `context/project/sapience/domain/per-repo-scoping.md` (lines 137-330),
  `~/.dotfiles/docs/sapience.md`, `~/.dotfiles/modules/home/services/sapience.nix`,
  `~/.dotfiles/packages/sapience-flake/{lib/wrappers.nix,checks/register-mcp.nix}`

### References

- `agent-system/extensions/sapience/scripts/setup-sapience-mcp.sh` (writer; lines 296-507 are the
  token/host resolution and entry-generation logic this task's fix targets)
- `agent-system/extensions/sapience/scripts/verify-sapience-mcp.sh` (lines 237-287, check (b))
- `agent-system/extensions/sapience/scripts/tests/test-sapience-mcp-registration.sh` (header
  manifest lines 7-40; existing Case 7 near line 268)
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
- `~/.sapience/mcp.py` (vendor payload; read-only)
