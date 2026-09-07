# Deploy Orphan Detection

## What "orphan" means here

The declared-vs-deployed parity check (`verify_extension` / `verify-deploy.sh` gate 5) only ever
verifies in one direction: for every entry a manifest *declares*, is it present in the deploy
tree and does its content match? It never asks the reverse question: is every file *present* in
the deploy tree still declared by some active extension's manifest? A file that loses its
source-store owner -- because a commit deletes it from `agent-system/extensions/**` -- is
therefore invisible to gate 5 forever. The copy engine (`loader.copy_category`) is additive-only
by design: it never deletes a deployed file just because the source no longer has one. This
document is the exclusion contract for the reverse-direction detector (`verify.find_orphans`,
gate 13) that closes that gap, plus the measurement recipe used to derive it.

## Measurement recipe (clean scratch regenerate)

Reproduce this whenever the exclusion contract needs re-deriving or re-checking against a fresh
baseline:

```bash
# 1. Confirm the live tree is not already stale before trusting any measurement.
bash .claude/scripts/check-deploy-freshness.sh   # must exit 0

# 2. Clone the repo fresh (committed content ONLY -- no working-tree noise) and deploy into it.
git clone --no-local /home/benjamin/.config/nvim /path/to/scratch
cd /path/to/scratch
bash agent-system/extensions/core/scripts/deploy-headless.sh /path/to/scratch

# 3. Diff the live tree against the scratch-regenerated one.
cd /home/benjamin/.config/nvim
diff <(cd .claude && find . -type f | sort) <(cd /path/to/scratch/.claude && find . -type f | sort)
```

Every line prefixed `<` (present live, absent from the fresh regenerate) is either a real orphan
or falls into one of the noise classes below. There is no other possibility: the scratch clone
carries only what git has committed plus what a real `deploy-headless.sh` run produces, so
anything else present in the live tree got there some other way.

For the ghost `context/index.json` row check, run independently (not part of the file diff
above, since `context/index.json` itself is a merged/generated artifact excluded from the file
diff -- see below):

```python
# normalize() must match verify.lua's normalize_index_path exactly.
live_paths = { normalize(e["path"]) for e in live ".claude/context/index.json" entries }
declared_paths = union over every ACTIVE extension's agent-system/extensions/*/index-entries.json
                 of { normalize(e["path"]) for e in that file's entries }
ghosts = live_paths - declared_paths
```

"Active" means listed in `.claude-extensions.json` with `status: "active"` -- an inactive or
never-loaded extension's declarations do not count toward the declared set, matching
`manager.list_loaded`'s own scope.

## Exclusion classes (live-only, but NOT an orphan)

Every live-only path from the recipe above must land in exactly one of these classes, or it is a
real orphan. If a future run produces a live-only path that fits none of these, that is itself a
signal -- either a new legitimate noise source needs a new named class here, or it is a real
orphan and should be treated as one. Do not add a class to make a single anomalous path go away
without understanding which case it is.

| Class | Examples | Why it's not an orphan |
|---|---|---|
| **Runtime artifact** | `tmp/workflow-active-*`, `RESUME.md`, `scripts/__pycache__/*.pyc`, `scripts/literature-pyenv/venv/**` | Created or populated at execution time by running commands/hooks/scripts, not by the copy engine. `tmp/workflow-active-*` are session-lock files; `RESUME.md` is workflow resume state; `__pycache__`/`*.pyc` are Python bytecode caches; `scripts/literature-pyenv/venv/` is a Python virtualenv provisioned on first use by the declared script `literature-pyenv-provision.sh` itself -- the venv's contents are never part of any `provides.*` list. All of these are `.gitignore`d at the project root. |
| **Merged/generated artifact** | `context/index.json`, `CLAUDE.md`, `settings.json`, `settings.local.json`, `extensions/*/opencode-agents.json` (opencode targets) | Not copied file-for-file from a single source; assembled by the merge/index pipeline from every active extension's fragments (`index-entries.json` rows, `merge-sources/*.md` sections, `provides.*` declarations). Comparing these against any single extension's source tree is a category error -- there is no one source file for a scratch-clone diff to miss. |
| **`.syncprotect`-protected path** | `context/repo/project-overview.md` | Declared and present in the source store, but the copy engine's protected-path check causes it to be skipped even on an otherwise-fresh deploy (protection is unconditional on the *target* path existing in the protect list, not conditional on the target file already being present -- confirmed empirically: a from-scratch scratch clone with a committed `.syncprotect` never receives this file at all). This is expected: `.syncprotect` exists specifically so a per-repo customized file is never clobbered by a resync, and that guarantee has to hold on the very first deploy too, not just subsequent ones. |
| **Uncommitted source-store working-tree artifact** | anything present only because of an uncommitted local edit, added file, or in-flight agent's scratch output | A scratch clone (`git clone --no-local`) carries only committed content. A file that exists in the live source store but was never committed cannot appear in the scratch regenerate's declared set even though it is a perfectly legitimate, intentional in-progress addition. This class is why the recipe's step 1 (freshness check) matters: it does not catch this case, so a measurement taken mid-edit can misclassify a not-yet-committed real file as an orphan. When in doubt, check `git status` on the source-store paths under suspicion before treating a live-only file as class-real-orphan. |

## Real orphans measured (baseline, 2026-08-24)

Re-confirmed against a fresh scratch regenerate while drafting this document, using the recipe
above:

- `context/orchestration/orchestration-validation.md`
- `context/orchestration/subagent-validation.md`
- `docs/architecture/architecture-spec.md`
- `docs/README.md`

Root cause (confirmed by git history, not inferred): commits `0e6245fd0` and `89eac9896`
(2026-08-09) deleted these four files from the source store and cleaned the source
`index-entries.json` rows for the two that had them, but the live deploy tree had captured all
four minutes earlier. The additive-only copy path has no mechanism to notice or remove them.

## Ghost `context/index.json` rows measured (baseline, 2026-08-24)

Using the ghost-row recipe above, against the union of all six active extensions'
`index-entries.json` files (`core`, `memory`, `email`, `nix`, `nvim`, `literature`):

- `orchestration/orchestration-validation.md`
- `orchestration/subagent-validation.md`

These are the same two files' index rows: their source-store `index-entries.json` declarations
were removed by the same two commits, but the merged `context/index.json` in the deploy tree
still carries the rows because index merge is additive-only in the same way file copy is.

## The direction decision: detect, never auto-delete

The copy engine and index merge stay additive-only by design. Nothing in this detector deletes a
deployed file or index row automatically. Deletion is a deliberate human (or explicitly-scoped
task) action: either targeted removal of the specific orphan paths, or a full
`deploy-headless.sh --wipe` regenerate when the drift is too broad to resolve file-by-file. The
detector's job stops at *reporting* -- gate 13 in `verify-deploy.sh` -- so that drift like this is
caught within one verification cycle instead of persisting silently for weeks, without changing
the safety property that a deploy never removes anything from a target repo on its own.

## Fail-time detail output (non-quiet, no `--findings` required)

Gate 13's failure branch in `verify-deploy.sh` prints every `ORPHAN_FINDING` line to the
operator-visible stderr stream unconditionally on failure -- not only when `--findings` is
passed. Before this, the gate's own hint text told the operator to "re-run without `--quiet` for
detail", but the per-finding lines were appended to the `--findings`-only `FINDINGS_LIST` array
and nowhere else, so a plain non-quiet re-run printed nothing beyond the aggregate "N finding(s)"
count -- the hint was false. The fix is additive only: the existing `--findings` `FINDINGS_LIST`
population is unchanged in shape (same `FINDING gate13 <detail>` entries), and no exit code or
`CHECKS`/`FAILURES` accounting changed. Gate 5 (`verify.lua`'s manifest-driven
declared-vs-deployed parity check) shared the identical suppress-and-extract shape and the same
false hint, and received the same fix in the same change. The measurement recipe above remains a
useful *classification* tool once a finding is known -- it is no longer the only way to learn a
finding occurred.

## See also

- `verify.lua`'s `M.find_orphans` (declared-set union across all loaded extensions, deployed-tree
  walk, exclusion predicates, ghost-index-row check).
- `init.lua`'s `manager.find_orphans` (resolves loaded extensions + `.syncprotect` and calls
  `verify.find_orphans` once for the whole tree).
- `verify-deploy.sh` gate 13 (shell surface, narrative and `--findings` modes).
- `scripts/tests/test-deploy-orphans.sh` (scratch-tree regression proving the gate fires on a
  planted orphan and stays silent on each exclusion class).
