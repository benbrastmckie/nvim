# MCP Server Ownership: Registration vs. Permission

**Purpose**: Answer, in one place, "where do I declare a new MCP server and where do I grant its
tools?"
**Audience**: Extension authors and anyone debugging why an MCP tool call prompts, or why a
configured server never appears.

---

## Overview

MCP tool availability rests on two independent axes. **Registration** is which file makes a
server exist and connect. **Permission** is which file grants its tools without a prompt. Neither
axis substitutes for the other: a registered-but-unpermitted server still prompts on every call,
and a permitted-but-unregistered server has no tools to grant permission for in the first place.
Getting one axis right while getting the other wrong looks like a working configuration until the
first tool call, so both must be verified independently.

---

## Registration

MCP servers register through exactly two files: `~/.claude.json` and `.mcp.json`.
Nothing else registers a server — see "Not registration" below. `~/.claude.json` itself carries
two internal scopes — **local** (per-project entries keyed under that project's own absolute
path, under `.projects["<abs path>"].mcpServers`, private to the machine) and **user** (top-level
`mcpServers`, applying across every project). Both scopes are sanctioned registration mechanisms
in this repo as of the per-project `lean-lsp` registration work: local scope is the correct
choice specifically when a server needs per-project computed arguments AND multiple instances of
that per-project configuration must coexist on the same machine at once (see `lean-lsp` below).
That leaves a three-way, actionable choice for extension authors:

1. **Project-scoped `.mcp.json`**, at the project root. A JSON file, in the same
   `mcpServers`-object shape as `~/.claude.json`, declaring servers usable only within this
   repository. This is the surface for extension-owned, repo-local servers.
2. **User-scope `~/.claude.json`** (its top-level `mcpServers` object), written by one of two
   sanctioned mechanisms:
   - **A host-level or home-manager activation block**, for servers with no per-project computed
     arguments. The activation block writes the server's `command`/`args`/`env` directly into
     `~/.claude.json`'s top-level `mcpServers` object once, outside of any single project's
     lifecycle. `playwright` is the worked example (see below).
   - **A setup script**, for a server that needs a single, machine-wide computed argument where
     only one project is ever open at a time. (No current worked example in this repo remains in
     this shape — `lean-lsp`, the prior occupant of this bullet, moved to local scope below once
     concurrent multi-project use overturned that assumption; see the invariant subsection.)
3. **Local-scope `~/.claude.json`** (`.projects["<abs project path>"].mcpServers`), for a server
   that needs PER-PROJECT computed arguments where MULTIPLE projects run concurrently on the same
   machine. `lean-lsp` is the worked example: each Lean project needs its own computed
   `LEAN_PROJECT_PATH`, and this machine routinely has several Lean projects open at once
   (including PR-review worktrees), so a single user-scope slot cannot hold more than one
   project's value at a time. Written automatically, per project, by a `SessionStart` hook
   (`lean-lsp-register-project.sh`, installed at USER level, not contributed through the lean
   extension's own `settings-fragment.json` — a per-repo hook only merges into a repository's OWN
   `.claude/settings.local.json`, which a freshly created worktree with no `.claude/` deploy at
   all never has; see `docs/architecture/extension-system.md`'s "Settings Merging" section for
   the user-level-vs-per-repo distinction this forces) that invokes a writer script
   (`lean/scripts/setup-lean-mcp.sh --scope project`) using the same detect-then-`jq`-merge
   shape as a user-scope setup script, just targeted at `.projects[<path>].mcpServers` instead of
   the top-level object, and preserving whatever the file already holds for every other project
   and server.

### Choosing a registration surface (the hybrid model)

Pick a surface by asking two questions in order:

1. **Does this server's usefulness end at this repository's boundary, and does it need no
   per-project computed arguments?** Yes to both → **project-scoped `.mcp.json`**. The server is
   extension-owned and repo-local; it has no reason to exist for any other project. This is the
   primary surface for new extension-declared servers going forward.
2. **Does it need per-project computed arguments?** No → **user scope** (a genuine machine
   capability, installed once, useful across every project regardless of which is open;
   `playwright` is the worked example — a Nix-built wrapper binary plus a machine-level browser
   cache, registered once via a home-manager activation block). Yes, AND multiple such projects
   run concurrently on this machine → **local scope**, written automatically per project by a
   `SessionStart` hook (`lean-lsp` is the worked example — see above). A per-project need where
   only ONE project is ever open at a time could in principle still use a user-scope setup script
   instead, but no current server in this repo is in that shape; default to local scope for any
   new per-project-computed-argument server unless a concrete single-project-at-a-time
   constraint is established first.

### Invariant: a command path must never resolve inside a repository's own `.claude/` tree

Whichever surface a server is registered on, its `command` (and any path-valued `args`) must
resolve to a stable location OUTSIDE any repository's own `.claude/` directory — never inside
one. `.claude/` is a disposable deploy artifact, wholesale-regenerated from the source store (see
`rules/source-store-deploy-boundary.md`); a hand-authored file placed there survives only until
the next regeneration or a fresh clone.

**The failure mode this invariant prevents**: an entry pointing into `.claude/` looks configured
— the JSON shape is valid, the file exists at the moment it was written — right up until the
deploy tree is regenerated or the repository is re-cloned, at which point the referenced file is
simply gone and the server fails at spawn with a silent `ENOENT`. Nothing about the failure names
its own cause: the error reports a missing file path, not "this command was never supposed to
live here." This is precisely the shape a hand-edit to `~/.claude.json` took once already —
a `lean-lsp` entry was pointed at a wrapper script inside a project's `.claude/scripts/`, the
tree was later regenerated without that hand-authored file, and every session in every project
relying on the (top-level, global) entry then failed at spawn with no indication the registered
path itself was the defect. Two positive examples already in this repo show the correct
alternative — a command path anchored at a stable, non-deploy location:

- `playwright` — a Nix-built wrapper binary at a fixed store/profile path, registered once via a
  home-manager activation block.
- `lean-lsp` — resolved via `uvx` (a package runner on `PATH`, not a path into any repository),
  with the per-project value carried entirely through the `LEAN_PROJECT_PATH` environment
  variable rather than through the command path itself.

**Trade-off record OVERTURNED by concurrency evidence, not merely revised**: this section
previously recorded `lean-lsp` as a single global (user-scope, top-level `mcpServers`) entry,
treating that as a limitation the repo had chosen to live with, with per-project local-scope
registration explicitly ruled out. That was wrong for this machine, and the evidence that
overturned it was observed live, not hypothesized: a session orchestrating in `BimodalLogic` held
a `lean-lsp` entry pointed at
`cslib` — the single global slot, last written by whichever session most recently ran the setup
script, silently answered every OTHER concurrent session's lean-lsp calls against the WRONG
project. This is not a cosmetic inconvenience; it is the most dangerous failure shape available,
because it connects successfully and returns a confident, plausible, WRONG answer rather than
failing visibly. This machine routinely runs several Lean projects at once — `cslib`,
`BimodalLogic`, and ephemeral PR-review worktrees such as `cslib-pr648` — so "switching which
project lean-lsp indexes requires re-running the setup script" was never a rare edge case here;
it was the steady state, silently wrong more often than not. `lean-lsp` is now registered per
project under LOCAL scope (`.projects[<path>].mcpServers`, see the Registration section above),
written automatically at session start by `lean-lsp-register-project.sh`, with the top-level
global entry retired entirely (its mere presence is itself now flagged as drift — see
`verify-lean-mcp.sh`'s inverted Check 9). An absent per-project entry fails LOUDLY (no lean-lsp
tool at all); that is strictly safer than a stale entry answering confidently for the wrong
project. **The invariant itself — a command path must never resolve inside a repository's own
`.claude/` tree — is completely unaffected by this reversal**: `lean-lsp` still resolves via
`uvx`, never a repository-relative path, at every scope. Only the SLOT the per-project env var
lives in changed (local instead of global); the invariant's own reasoning about command-path
stability was never the thing that was wrong.

### Grant permissions at the same scope where the server is registered

This is the governing rule the hybrid model depends on, and getting it backwards is the most
common way a configuration looks correct until the first tool call:

- **User-scope registration → grant in user scope**, in `~/.claude/settings.json`
  (`root-files/settings.json` in the source store). The server is reachable from any project, so
  its grant must be too.
- **Project-scope registration → grant in the owning extension's `settings-fragment.json`**, per
  the domain-specific/domain-agnostic split described under "Permission" below.

**The failure mode this rule prevents**: a project-scope grant only helps projects where that
specific extension happens to be loaded. Every other project's calls to that server's tools fall
back to an interactive prompt — and in a headless run, a prompt cannot be answered, so the call is
DENIED outright. This is exactly why an autonomous run can stall on a tool call that works fine
interactively elsewhere: the server is registered somewhere reachable, but the grant was written
to the wrong scope for the run's actual project.

**Worked pair**: `lean-lsp` is the in-repo positive control — registered per-project in LOCAL
scope (`~/.claude.json`'s `.projects[<path>].mcpServers`) and granted via a `mcp__lean-lsp__*`
wildcard in USER-scope `~/.claude/settings.json`. This is not a scope mismatch: a permission
grant in `~/.claude/settings.json` applies to every session on the machine regardless of which
scope actually registered the server that session resolves to, so the same single wildcard grant
covers lean-lsp correctly whether it was previously a single global entry or is now a per-project
local one. `playwright` is a second worked example, now corrected to match the rule it once
violated: registered in user scope, with its 9-tool safe-tier enumeration (see the "Carve-out"
subsection below) granted directly in `~/.claude/settings.json` — written by the same
home-manager activation block, in a separate configuration repository, that registers the server
— and with zero playwright entries left in any extension's `settings-fragment.json`. Every
project reaches the grant regardless of which extensions happen to be loaded, because the grant
now lives at the same scope as the registration, exactly as this section prescribes. The
asymmetry this passage once recorded (grant confined to the `web` and `present` extensions'
`settings-fragment.json` files, with zero entries in `~/.claude/settings.json` itself) has been
corrected, not merely noted.

### Workspace trust (a real friction cost, not a blocker)

Claude Code v2.1.196 added a workspace-trust gate for `.mcp.json`: a fresh clone (or any
not-yet-trusted workspace) requires a one-time interactive approval before a project-scoped server
is used, and a cloned repository cannot approve its own servers — there is no way to pre-authorize
trust from inside the repo itself. **Once a workspace is trusted, project-scoped servers are fully
reachable by dispatched subagents** — directly demonstrated, twice, including via the
general-research-agent class this system actually dispatches, with the permission pre-granted so
permission was not a confound. There is no categorical subagent access barrier to project scope.

This makes the trust step a real, honest friction cost of the hybrid model relative to pure user
scope — user-scope registration is never gated by a per-server approval — but it is a one-time
setup cost, not a per-call or per-session obstacle, and it is not a reason to avoid project scope
for repo-local servers.

### The session-start snapshot trap

A session's tool registry is a snapshot taken at startup. **An already-running session cannot see
a server added to `.mcp.json` after that session started** — and this affects the MAIN session
identically to any subagent; it is not a subagent-specific limitation. This snapshot effect is
exactly what produced the original wrong conclusion that subagents cannot reach project-scoped
servers: the server was reachable, but the session used to test it had already started before the
server was added.

**Anyone re-verifying registration or reachability MUST use a fresh session (or `claude -p`),
never an already-running one.** Testing from a stale session reproduces the same false negative
every time, regardless of how correctly the server is registered or permitted.

**Measured for a `SessionStart`-hook write specifically** (the per-project `lean-lsp`
registration hook, `lean-lsp-register-project.sh`): a hook's OWN write, performed during that
same session's startup, is NOT reliably visible within that same session — confirmed
empirically, not assumed, by running three sequential fresh sessions in a previously-unregistered
directory. The session whose own hook invocation performed the write still resolved lean-lsp
calls against the WRONG (stale/global) configuration; only a subsequent fresh session saw the
just-written entry. This is the same snapshot effect as the paragraph above, just triggered by a
hook's write instead of a manual edit, and it is why the hook always emits an `additionalContext`
restart notice on every write rather than assuming same-session visibility (see
`lean-lsp-register-project.sh`'s own header for the mechanism).

### Not registration

An `mcpServers` key inside `settings.json` or `settings.local.json` — and therefore inside an
extension's `settings-fragment.json`, which merges into one of those two files — has **no
effect**. Claude Code never reads those files for server definitions; it reads only the two
surfaces above, `~/.claude.json` (user scope) and project-scoped `.mcp.json`. This is an
empirically verified fact, not an inference from documentation silence:

- **Evidence shape**: running `claude mcp list` shows only servers registered via one of those two
  surfaces as `Connected`. A server whose only declaration is an `mcpServers` block in a settings
  file does not appear in the list at all — it is absent, not present-but-failing-to-connect.
  Absence is the tell: a misconfigured-but-registered server would still show up (as `Failed` or
  similar); a settings-declared server shows up nowhere because the file was never consulted for
  registration.
- **Doc-side corroboration**: the settings-file schema documents only `enabledMcpjsonServers`,
  `disabledMcpjsonServers`, `enableAllProjectMcpServers`, `allowedMcpServers`,
  `deniedMcpServers`, and `allowManagedMcpServersOnly`. Every one of these keys approves, denies,
  or scopes servers that are defined *elsewhere*; none of them defines a server.

A `manifest.json` `mcp_servers` field is equally inert for the same reason: nothing in the loader
reads it to write `~/.claude.json`. Extension `settings-fragment.json` files must not declare
`mcpServers` — the block is dead weight that misleads a future reader into thinking it registers
something.

---

## Permission

Once a server is registered, its tools still need a `permissions.allow` grant to be callable
without an interactive prompt. Ownership of that grant follows the domain boundary:

- **Domain-specific grants** (`mcp__{server}__*`, scoped to tools only one extension's agents
  use) belong in that extension's own `settings-fragment.json`.
- **Domain-agnostic grants** (tools every loaded configuration needs regardless of which
  extensions are present, such as `Read`/`Write`/`Bash(git:*)`) belong in core's
  `root-files/settings.json`.

A domain-specific `mcp__{server}__*` grant living in core's settings is a boundary violation even
if it happens to work today — it survives the extension being unloaded, misrepresents core as
domain-aware, and duplicates a grant that belongs entirely to the owning extension.

### Wildcard over enumeration

Prefer a single wildcard (`"mcp__{server}__*"`) over enumerating each tool the server exposes.
An enumeration silently under-grants as the server's tool surface grows — every new tool the
server adds requires a matching edit to the enumeration, and a missed edit reintroduces prompting
for that one tool with no error to signal the gap. A wildcard cannot drift: it grants whatever the
server exposes, today or after an upgrade, with one line to maintain.

The lean-lsp server is the worked example of enumeration drift, now corrected: its permission
grant was once duplicated three ways — a wildcard in core's `root-files/settings.json`, a 21-entry
enumeration in lean's own `settings-fragment.json`, and a dead `mcpServers` registration block
also in lean's fragment — none of which needed to coexist. That end state has been reached: one
`mcp__lean-lsp__*` wildcard lives in lean's own fragment, core's `root-files/settings.json` carries
no lean entries, and the dead `mcpServers` block is gone.

### Carve-out: safe/unsafe tool splits require enumeration

The wildcard preference above assumes every tool a server exposes is equally fine to
always-allow. When a server intentionally splits its own tool surface into a safe/always-allow
tier and an unsafe/always-prompt tier, a wildcard cannot express that split — it grants
everything, collapsing the two tiers into one. Enumeration is **required** here, not merely
tolerated.

The worked example is user-scope `~/.claude/settings.json`, which enumerates exactly the 9 safe
`mcp__playwright__browser_*` tools (navigate, snapshot, take_screenshot, console_messages,
network_requests, click, type, find, wait_for) and deliberately omits `browser_evaluate`,
`browser_file_upload`, and `browser_run_code_unsafe` from every allow list. Those three tools must
keep prompting: `browser_evaluate` and `browser_run_code_unsafe` run arbitrary code, and
`browser_file_upload` reads arbitrary local files onto a page. Collapsing the enumeration into a
`mcp__playwright__*` wildcard — the same simplification legitimately applied to `lean-lsp` above —
would silently re-grant all three and reopen an arbitrary-execution and file-upload hole.

**Accepted cost, stated honestly**: this enumeration inherits exactly the drift weakness the
"Wildcard over enumeration" section above describes — a newly added safe Playwright tool will
prompt until this list is updated to include it. That is the deliberate price of keeping the
unsafe tier prompting; it is not an oversight to "fix" by wildcarding. Keeping the enumeration in
exactly one place (user scope) rather than three is what this document's own correction
(see "Grant permissions at the same scope where the server is registered" above) was for: a single
list to update instead of several copies that could silently diverge.

---

## Composition

A tool is usable without a prompt only when **both** axes hold at once: its server shows
`Connected` in `claude mcp list`, **and** an active `permissions.allow` entry matches its tool
name. The two failure shapes point to different fixes:

| Symptom | Registration | Permission | Fix |
|---|---|---|---|
| Connected, but every call prompts | OK (`Connected`) | Missing or non-matching grant | Add/correct the `mcp__{server}__*` entry at the SAME scope as registration — the owning extension's `settings-fragment.json` for project-scope, `~/.claude/settings.json` for user-scope |
| Granted, but the tool is simply absent | Missing (not in `~/.claude.json` or project-scoped `.mcp.json`) | Present but moot | Register the server on the appropriate surface — project-scoped `.mcp.json`, a user-scope activation block, or a user-scope setup script — a permission grant cannot conjure a server that was never connected |

Checking only one axis and concluding "it's configured" is the recurring mistake this document
exists to prevent — always verify both.

---

## Decision procedure

Follow top to bottom when adding a new server:

1. **Pick a scope first**, per "Choosing a registration surface" above: project scope (repo-local,
   no per-project computed arguments) → project-scoped `.mcp.json`; no per-project computed
   arguments needed at all → user scope; per-project computed arguments with multiple such
   projects live on the machine concurrently → local scope.
2. **Pick a registration mechanism within that scope.**
   - Project scope: add the server to the project root's `.mcp.json`.
   - User scope: a host-level or home-manager activation block.
   - Local scope: a `SessionStart` hook, installed at USER level (never contributed through an
     extension's per-repo `settings-fragment.json` — see the Registration section's local-scope
     bullet above for why), that invokes a writer script targeting
     `.projects[<path>].mcpServers` — mirroring `lean-lsp-register-project.sh` /
     `lean/scripts/setup-lean-mcp.sh --scope project`.
3. **Write the permission grant in USER scope regardless of registration scope** (see "Grant
   permissions at the same scope where the server is registered" above and the `lean-lsp` Worked
   Pair note): a `~/.claude/settings.json` wildcard grant (`"mcp__{server}__*"`) applies to every
   session on the machine no matter which scope registered the server that session resolves to.
   Project-scope registration is the one exception — grant in the owning extension's
   `settings-fragment.json` instead. Never core's settings, and never an enumeration — unless the
   server needs a safe/unsafe split (see "Carve-out" above).
4. **Verify both axes from a fresh session** (never an already-running one — see "The
   session-start snapshot trap" above): run `claude mcp list` and confirm the server shows
   `Connected`, then make one real tool call and confirm it does not prompt.

### Small facts worth knowing

- **Grant form**: `"mcp__{server}__*"` (with the trailing wildcard) is a valid grant. Bare
  `"mcp__{server}"` (no tool suffix) is NOT — it grants nothing.
- **Omission behavior differs by run mode**: a tool call whose permission is absent from every
  `permissions.allow` prompts interactively in an interactive session, but is DENIED outright in a
  headless run — there is no one to answer the prompt. This is the mechanism behind the
  playwright stall described above.
- **HTTP servers need an explicit `type`**: as of Claude Code v2.1.202, an HTTP-transport MCP
  server declared without an explicit `"type"` field fails fast at connection time. Always set
  `"type"` explicitly for HTTP servers.

---

## Registration vs. Reachability

Both axes above — Registration and Permission — answer whether a server is *configured*. Neither
answers whether it is *running right now, for this project*. That is a third, independent
question, and a project can pass every registration and permission check while still having no
live server to answer a tool call.

**The general concept**: registration tells you a server *would* connect if asked; reachability
tells you a server *is* connected right now. A correctly registered project — every check in the
Registration section above passes, the entry is well-formed, the permission grant matches —
passes silently even when no server process is actually running for it. Only reachability
determines the evidence tier a dispatched agent is actually operating under: whether its first
real tool call will be answered by a live index, or will come back in a state that looks like
"nothing found" but actually means "nothing was asked." This distinction applies to any
per-project MCP server this codebase registers under local scope (see "Choosing a registration
surface" above), not only `lean-lsp` — any server whose registration is per-project and whose
process lifecycle is independent of registration state is subject to the same gap. `lean-lsp`
is the one with a concrete implementation: `lean-mcp-preflight-check.sh --dispatch-block` (see
`agent-system/extensions/lean/scripts/lean-mcp-preflight-check.sh`) checks registration via
`verify-lean-mcp.sh`, then — only once registration is confirmed — separately probes for a live
`lean-lsp-mcp` process bound to this project's own path via `/proc/<pid>/environ`, and reports a
three-state reachability tier (`reachable` / `not_reachable` / `unknown`) into the dispatch file
before the agent's first tool call. No other per-project server in this repo has an equivalent
reachability probe yet; this is recorded as a gap, not a precedent to copy mechanically — build
one only when a server's per-project registration state can diverge from its running state in a
way that would otherwise go unnoticed, the same way `lean-lsp`'s did.

**A cheap manual diagnostic tell, stated generally (not automated probe logic)**: when a compiled
or cached artifact might be stale relative to its source, check a field that is *defined as a
projection of another field in the same declaration*. If field `X` is defined as a projection of
field `Y` — `X := (Y).1` or equivalent — then a cached artifact cannot possibly resolve `X`
without first resolving `Y`: they are the same compiled unit. If a query shows `X` resolving while
`Y` does not, the artifact being queried and its purported source provably came from different
revisions. This one check distinguishes "the cache is inconsistent" from "the code is broken" —
the two most easily confused diagnoses when a probe reports an unexpected failure against a
project with any compiled or hashed on-disk cache. This is recorded here as a manual sanity check
an agent or operator can apply by hand; it is deliberately **not** implemented as automated probe
logic in this task's scope, and it is a distinct concern from build-cache replay correctness
(tracked separately — see `lake-build-guard.sh`'s stale-content-addressed-store detection, a
different failure mechanism in the same general neighborhood: a build silently reusing a cached
result across a differently-scoped build rather than a language server silently indexing a stale
cache). The motivating incident that surfaced this tell is recorded as `err_20261002080500`.

---

## Known gaps

**Retirement (deliberate, four extensions).** `epidemiology` (`rmcp`), `filetypes` (`openpyxl`,
`superdoc`), and `founder` (`firecrawl`, `sec-edgar`) previously carried dead `mcpServers` blocks
declaring these five servers in their own `settings-fragment.json` files. Those blocks are
deleted, along with founder's five orphaned `mcp__firecrawl__*` / `mcp__sec-edgar__*` permission
grants that pointed at them. This is a **deliberate retirement, not an oversight** — these five
servers are not being migrated to functioning registration. Reviving any of them requires a fresh
registration decision under the hybrid model above (pick a scope, register there, grant at that
same scope), not a revival of the deleted block.

**Migration (distinct from retirement, one extension).** `nix`'s dead block — which declared the
server under the trap name `mcp-nixos` — is likewise deleted. Registration *moved*, rather than
being retired: a home-manager activation block in a separate NixOS configuration repository
registers the server under the name `nixos`. This is verified against the live server: running
`uvx mcp-nixos` exposes exactly two tools, `nix` and `nix_versions`, matching the two
`mcp__nixos__nix` / `mcp__nixos__nix_versions` grants this repo retains in
`agent-system/extensions/nix/settings-fragment.json`. **Do not** delete those two grants, and
**do not** "fix" the deleted block by reinstating it under the name `mcp-nixos` — that name would
produce `mcp__mcp-nixos__*` tools, breaking both existing grants and every doc cross-reference
that assumes the `nixos` name.

**Remaining gap.** `memory` (`obsidian-memory`) still carries a dead `mcpServers` block in its own
`settings-fragment.json` and is untouched by the retirement/migration above — it is a genuine,
still-open gap, not yet resolved either way.

**Second dead surface (corrected).** Five extensions — `filetypes`, `founder`, `lean`, `memory`,
and `nix` — additionally carried the identical dead declaration in their `manifest.json`
`mcp_servers` field. This was an independent second surface: a `manifest.json` `mcp_servers`
field is equally inert (see "Not registration" above). The field has been deleted from all five
manifests; nothing reads it to write `~/.claude.json`, so the deletion changes no behavior.

---

## Related Documentation

- [Permission Configuration Guide](../../docs/guides/permission-configuration.md) — the guide an
  author reaches for when writing a `permissions.allow` entry; carries a summary of the same
  registration/permission split with a link back here.
- [Extension System Architecture](../../docs/architecture/extension-system.md) — Settings Merging
  section, covering how `settings-fragment.json` merges into `settings.json` at load time.
- [Creating Extensions](../../docs/guides/creating-extensions.md) — the extension-authoring guide,
  including the manifest field reference for `mcp_servers`.
- [MCP Tool Recovery Pattern](mcp-tool-recovery.md) — defensive handling for MCP tool call
  failures once a server is registered and permitted; its "Tool Unavailable" symptom links back
  here for the registration-scope check.
