#!/usr/bin/env bash
# deploy-headless.sh - Regenerate a repo's .claude/ deploy tree without an interactive picker.
#
# Drives the manifest-driven extension loader (neotex.plugins.ai.shared.extensions.init's
# `manager`) headlessly -- the single deploy engine, reachable both interactively (the picker's
# entries) and from here. This is the ONLY engine as of the deploy-engine consolidation: the
# former glob+allow-list `load_all_globally` path (and the picker's separate "Reload All"
# unload-all/load-all reimplementation) have been retired onto `manager.resync_all` /
# `manager.wipe`, both of which this script now calls.
#
# Two modes:
#   (default, no flag)  Non-destructive resync. Force-loads `core` (bootstrapping it if this is
#                        the first deploy into TARGET_REPO, since a target that has only ever
#                        used the retired glob-based engine has no `core` entry in its
#                        project-root extension state yet -- see the "Bootstrap safety" note
#                        below), then force-resyncs every other currently-active extension via
#                        `manager.resync_all`. Never destructive; never removes anything.
#   --minimal-init DIR   Opt-in escape hatch for CI/container environments with no user nvim
#                        config: injects `--clean --cmd "set rtp+=DIR"` into the nvim invocation
#                        instead of the default `nvim --headless` (which loads init.lua and pays
#                        a full lazy.nvim plugin bootstrap). DIR is the nvim CONFIG directory
#                        (the directory init.lua would normally live in) -- for a consumer repo
#                        this is NOT the same as the deploy TARGET, so it is always explicit and
#                        never derived from TARGET; in CI, where the checkout IS the nvim config
#                        repo, the two coincide and DIR == TARGET. Default OFF: absent this flag,
#                        behavior is byte-for-byte unchanged (plain `nvim --headless`, same as
#                        before this flag existed). The extension manager has no plugin
#                        dependency, so `manager.load`/`manager.resync_all` need nothing from
#                        init.lua or lazy.nvim -- confirmed by a direct probe into a scratch
#                        clone before this flag was added. This flag is threaded through to the
#                        inline `verify-deploy.sh` call below (its own `--minimal-init DIR` --
#                        see that script's header for its two nvim call sites).
#   --wipe               Full destructive sequence via `manager.wipe`: snapshot
#                        settings.json/settings.local.json/.syncprotect-listed paths -> `rm -rf
#                        .claude` -> reload every formerly-active extension -> restore the
#                        snapshot as the merge base before re-applying settings fragments ->
#                        clear the snapshot staging directory. Refuses (exits 2, .claude left
#                        untouched) if the pre-wipe snapshot itself fails.
#
# Bootstrap safety (why the default mode is NOT a bare `manager.resync_all` call): the
# now-retired `load_all_globally` engine never wrote to a project's extension state file
# (`.claude-extensions.json`) -- it was a stateless glob+copy, not `manager`-driven. Every repo
# that has only ever been deployed via that engine (or via this very script, historically) has
# NO "core" entry in its `.claude-extensions.json`, so `manager.resync_all` alone -- which only
# resyncs extensions the state file already marks active -- would silently deploy nothing on
# such a repo's first post-consolidation run. Force-loading `core` unconditionally first closes
# this gap: it is a no-op-safe re-copy on a repo where core is already active, and a genuine
# bootstrap on one where it isn't.
#
# SAFETY: this overwrites deployed files under .claude/ with their source-store versions (and,
# under --wipe, deletes .claude/ entirely before rebuilding it). It must always be invoked
# deliberately -- never as a silent side effect of an unrelated operation. Files listed in
# .syncprotect are honored by the underlying copy engine and (--wipe only) additionally
# snapshotted/restored across the deletion. Exactly one automated caller is sanctioned to invoke
# this script as part of a larger operation: `skill-orchestrate`'s Stage MT-3 step 7 (the
# inter-cycle redeploy checkpoint) -- see context/patterns/regeneration-is-manual-only.md's
# `## Automated Exception` subsection for the full justification and its explicit "does not
# license any other automated caller" boundary. That subsection also documents this script's
# entry points, which were rewritten as part of the same consolidation this header describes.
#
# SELF-OVERWRITE HAZARD: bash reads a script incrementally by byte offset as it executes it, not
# by loading the whole file into memory upfront. The copy engine's write path overwrites an
# existing target file in place -- with no temp-then-rename indirection. When this script is
# invoked as `bash .claude/scripts/deploy-headless.sh` from inside the very repo it targets (the
# default: TARGET defaults to $(pwd)), the nvim subprocess it launches will overwrite this
# on-disk file mid-execution. A script whose top-level statements are read one at a time would
# resume reading at a stale byte offset into the NEW file content after that overwrite --
# undefined behavior, not merely "the rest of the old script still runs." The fix: this file's
# entire executable body is a single `main()` function, defined in full (and therefore fully
# parsed by bash) BEFORE any of it runs, invoked as the file's last physical command with
# nothing following it. Every exit path inside `main` calls `exit` explicitly -- never `return`
# followed by further top-level reads -- so no code path depends on bytes read after the
# overwrite could occur. Do not undo this structure by moving logic back to top level.
#
# Usage:
#   deploy-headless.sh [TARGET_REPO]         # resync (default): bootstrap-safe, non-destructive
#   deploy-headless.sh --wipe [TARGET_REPO]  # full destructive wipe+regenerate (see above)
#   deploy-headless.sh --dry-run [...]       # report what would run; deploy nothing
#   deploy-headless.sh --minimal-init DIR [TARGET_REPO]  # skip the lazy.nvim/init.lua bootstrap
#
# Exit codes:
#   0  deploy completed (artifact count reported) and verification (fast gates) passed
#   1  usage error, target is not a git repository, or nvim unavailable
#   2  the headless Neovim invocation failed, reported no result, or (--wipe only) the pre-wipe
#      snapshot was refused
#   3  the deploy itself landed, but the inline `verify-deploy.sh --skip-slow` run reported one
#      or more failures -- unlike 1 and 2, exit 3 means the tree WAS modified. See
#      context/patterns/regeneration-is-manual-only.md's
#      `### deploy-headless.sh's Inline Verification and Exit Code 3` subsection for the
#      fast-vs-full gate split and the current orchestrator-consumer interaction with this code.
#      Not emitted under --dry-run, which returns 0 before verification ever runs.
#
# THREE CONFOUNDS THAT ARE NOT THE SAME THING, made distinguishable below (this script's own
# RESULT= marker) and NEVER conflated in the exit code: "the deploy did not land" (1/2),
# "the deploy landed but a gate is red -- possibly pre-existing, this script does not know"
# (3), and "one or more OTHER, already-known consumer repos are behind the source store". The
# third is REPORT-ONLY and structurally CANNOT influence the exit code above: the post-deploy
# consumer-freshness check (via check-consumer-freshness.sh --stale-only) runs strictly after
# $verify_rc is already fixed, and its own result is unconditionally discarded with `|| true` --
# confirmed at runtime, not merely by reading the code (see the inline comment at that block).
# A caller that wants the consumer-staleness signal on its own reads the CONSUMERS_STALE=<n>
# marker below; it is never folded into 0/1/2/3.
set -euo pipefail

EXT_CONFIG_MODULE="neotex.plugins.ai.shared.extensions.config"
EXT_INIT_MODULE="neotex.plugins.ai.shared.extensions.init"

# specs/.deploy-lock/ fail-open mutex, mirroring the acquire/warn-and-proceed shape of
# specs/.commit-lock/ (see scripts/git-commit-scoped.sh). Implemented inline, WITHOUT sourcing
# scripts/task-lock.sh: this script is about to overwrite the deployed copy of task-lock.sh
# itself, so depending on it here would mean depending on the very file being replaced.
DEPLOY_LOCK_STALE_SEC="${DEPLOY_LOCK_STALE_SEC:-120}"

main() {
  local DRY_RUN=false
  local WIPE=false
  local TARGET=""
  local MINIMAL_INIT_DIR=""

  # _dh_result_and_exit <RESULT_token> <exit_code> - the single machine-readable outcome marker
  # this script emits before every exit path that follows a real deploy ATTEMPT (i.e. every
  # exit 1/2 below --dry-run's own early exit, and the two exit 0/3 paths at the very end). A
  # caller greps stdout/stderr for `RESULT=` rather than inferring the distinction from an exit
  # code plus log prose:
  #   RESULT=not_landed          -- exit 1 or 2: the deploy did not land (usage/environment
  #                                 error, or the headless nvim invocation itself failed).
  #   RESULT=landed_verify_clean -- exit 0: the deploy landed and verify-deploy.sh is clean.
  #   RESULT=landed_verify_red   -- exit 3: the deploy landed but verify-deploy.sh reported one
  #                                 or more findings (may be pre-existing; this script does not
  #                                 distinguish that -- see command-gate-out.sh / the inter-cycle
  #                                 redeploy checkpoint for the baseline-relative comparison that
  #                                 does).
  # NOT emitted under --dry-run (which returns 0 before any deploy is attempted) or --help
  # (which performs no deploy at all) -- consistent with this script's existing documented
  # "Not emitted under --dry-run" carve-out for exit 3.
  _dh_result_and_exit() {
    echo "[deploy-headless] RESULT=$1"
    exit "$2"
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --wipe) WIPE=true; shift ;;
      --minimal-init)
        if [ $# -lt 2 ] || [ -z "$2" ]; then
          echo "ERROR: --minimal-init requires a DIR argument (the nvim config directory)" >&2
          _dh_result_and_exit not_landed 1
        fi
        MINIMAL_INIT_DIR="$2"; shift 2
        ;;
      -h|--help)
        sed -n '2,91p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      -*)
        echo "ERROR: unknown flag: $1" >&2
        echo "Usage: deploy-headless.sh [--dry-run] [--wipe] [--minimal-init DIR] [TARGET_REPO]" >&2
        _dh_result_and_exit not_landed 1
        ;;
      *)
        if [ -n "$TARGET" ]; then
          echo "ERROR: more than one target given: '$TARGET' and '$1'" >&2
          _dh_result_and_exit not_landed 1
        fi
        TARGET="$1"; shift
        ;;
    esac
  done

  if [ -n "$MINIMAL_INIT_DIR" ] && [ ! -d "$MINIMAL_INIT_DIR" ]; then
    echo "ERROR: --minimal-init directory does not exist: $MINIMAL_INIT_DIR" >&2
    _dh_result_and_exit not_landed 1
  fi

  TARGET="${TARGET:-$(pwd)}"

  if [ ! -d "$TARGET" ]; then
    echo "ERROR: target is not a directory: $TARGET" >&2
    _dh_result_and_exit not_landed 1
  fi

  TARGET="$(cd "$TARGET" && pwd)"

  # Refuse to deploy into a non-repository. The deploy tree is gitignored-but-repo-scoped; running
  # this in an arbitrary directory would scatter 200+ files somewhere the user did not intend.
  if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
    echo "ERROR: not a git repository: $TARGET" >&2
    echo "Refusing to deploy the extension tree outside a repository." >&2
    _dh_result_and_exit not_landed 1
  fi

  if ! command -v nvim >/dev/null 2>&1; then
    echo "ERROR: nvim not found on PATH; cannot run the headless deploy." >&2
    _dh_result_and_exit not_landed 1
  fi

  # --- Mutex acquisition (attempted for both --dry-run and a live deploy; fail-open, non-blocking) ---
  # Ensure the parent specs/ directory exists first (non-atomic, harmless if it races with another
  # mkdir -p) so the leaf directory create below is the sole atomic-on-creation mutex primitive.
  mkdir -p "$TARGET/specs" 2>/dev/null || true
  local deploy_lock_dir="$TARGET/specs/.deploy-lock"
  local mutex_owned_here=false
  local mutex_status=""

  release_deploy_mutex() {
    if [ "$mutex_owned_here" = "true" ]; then
      rm -rf "$deploy_lock_dir" 2>/dev/null || true
      mutex_owned_here=false
    fi
  }
  trap release_deploy_mutex EXIT

  if mkdir "$deploy_lock_dir" 2>/dev/null; then
    { echo "pid=$$"; echo "claimed_at=$(date +%s)"; echo "session=${DEPLOY_SESSION:-unknown}"; } \
      > "$deploy_lock_dir/owner" 2>/dev/null || true
    mutex_owned_here=true
    mutex_status="acquired (this invocation, pid $$)"
  else
    local claimed_at="" age=999999
    claimed_at="$(grep -o 'claimed_at=[0-9]*' "$deploy_lock_dir/owner" 2>/dev/null | cut -d= -f2)" || true
    if [ -n "$claimed_at" ]; then
      age=$(( $(date +%s) - claimed_at ))
    fi
    if [ "$age" -gt "$DEPLOY_LOCK_STALE_SEC" ]; then
      echo "WARN: reclaiming stale specs/.deploy-lock mutex (age ${age}s > ${DEPLOY_LOCK_STALE_SEC}s threshold)." >&2
      rm -rf "$deploy_lock_dir" 2>/dev/null || true
      if mkdir "$deploy_lock_dir" 2>/dev/null; then
        { echo "pid=$$"; echo "claimed_at=$(date +%s)"; echo "session=${DEPLOY_SESSION:-unknown}"; } \
          > "$deploy_lock_dir/owner" 2>/dev/null || true
        mutex_owned_here=true
        mutex_status="acquired (reclaimed stale lock, age ${age}s)"
      else
        echo "WARNING: failed to acquire specs/.deploy-lock mutex even after stale reclaim attempt; proceeding unserialized (non-blocking, fail-open). A concurrent redeploy racing this one could corrupt the .claude/ tree." >&2
        mutex_status="not acquired (reclaim race lost); proceeding unserialized (fail-open)"
      fi
    else
      echo "WARNING: failed to acquire specs/.deploy-lock mutex (held, age ${age}s <= ${DEPLOY_LOCK_STALE_SEC}s threshold -- another session's deploy appears in progress); proceeding unserialized (non-blocking, fail-open). A concurrent redeploy racing this one could corrupt the .claude/ tree." >&2
      mutex_status="not acquired (held by other, age ${age}s); proceeding unserialized (fail-open)"
    fi
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "[deploy-headless] DRY RUN -- nothing will be written."
    echo "  target repo : $TARGET"
    echo "  deploy tree : $TARGET/.claude"
    if [ -d "$TARGET/.claude" ]; then
      echo "  tree exists : yes ($(find "$TARGET/.claude" -type f 2>/dev/null | wc -l) files present)"
    else
      echo "  tree exists : no (would be created)"
    fi
    echo "  deploy-lock : $mutex_status"
    if [ "$WIPE" = "true" ]; then
      echo "  would run   : nvim --headless -> manager.wipe() [DESTRUCTIVE: snapshot -> rm -rf .claude -> regenerate -> restore]"
    else
      echo "  would run   : nvim --headless -> manager.load('core', {force=true}) -> manager.resync_all()"
    fi
    exit 0
  fi

  # --- Pre-deploy line_count auto-repair (runs BEFORE the nvim deploy invocation below, so the
  # corrected SOURCE agent-system/extensions/*/index-entries.json is what gets copied into
  # .claude/context/index.json in THIS SAME run -- check-extension-docs.sh's Rule R never sees
  # drift in the inline verify-deploy.sh call that follows). Stops line_count from being a
  # hand-maintained, silently-driftable declaration: every deploy repairs it from `wc -l` first.
  #
  # Guarded on BOTH agent-system/extensions/ existing (a source-store checkout; a repo that has
  # only ever received a deployed .claude/ tree -- an ordinary consumer -- has no such directory)
  # AND the deployed regenerator itself existing (a tree too stale to carry it yet is a silent
  # no-op, matching check-consumer-freshness.sh's own guard convention a few lines below). This
  # call runs the DEPLOYED copy ($TARGET/.claude/scripts/...), not the source-store copy: the
  # regenerator's own deploy-root-guard.sh refuses to run from the source store (its "../.."
  # root computation is only valid two levels under a deployed scripts/ tree), and for a
  # self-deploy (TARGET == this repo) the deployed copy resolves REPO_ROOT back to $TARGET,
  # which correctly contains agent-system/extensions/ as a sibling of .claude/.
  #
  # Every repair is reported, never silent -- the validate-artifact.sh --fix / D-A
  # auto-repair-reporting precedent -- on BOTH the repaired and the clean path.
  local line_count_regen="$TARGET/.claude/scripts/generate-context-line-counts.sh"
  if [ -d "$TARGET/agent-system/extensions" ] && [ -f "$line_count_regen" ]; then
    local line_count_output line_count_rc=0
    line_count_output="$(bash "$line_count_regen" --write 2>&1)" || line_count_rc=$?

    local line_count_changed
    line_count_changed=$(printf '%s\n' "$line_count_output" | grep -oE '^Changed: [0-9]+' | grep -oE '[0-9]+' | head -1) || true
    line_count_changed="${line_count_changed:-0}"

    local line_count_exts
    line_count_exts=$(printf '%s\n' "$line_count_output" | grep -E ', [1-9][0-9]* changed$' | cut -d: -f1 | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null) || true
    line_count_exts="${line_count_exts:-[]}"

    echo "[deploy-headless] line_count auto-repair: ${line_count_changed} entry/entries corrected from wc -l (extensions: $(echo "$line_count_exts" | jq -r 'join(", ")' 2>/dev/null || echo "$line_count_exts"))."

    if [ "$line_count_rc" -ne 0 ]; then
      echo "[deploy-headless] WARNING: line_count auto-repair exited ${line_count_rc} -- a source file may be missing (this cannot be auto-repaired):" >&2
      printf '%s\n' "$line_count_output" | grep -i 'missing source' >&2 || true
    fi

    local line_count_category="milestone"
    [ "$line_count_changed" -gt 0 ] && line_count_category="deviation"

    local line_count_events="$TARGET/.claude/scripts/events-append.sh"
    if [ -f "$line_count_events" ]; then
      bash "$line_count_events" \
        --event-type index_line_count_auto_repair --category "$line_count_category" \
        --session "${SESSION_ID:-sess_$(date +%s)_deploy}" --checkpoint deploy_headless \
        --message "deploy-headless.sh line_count auto-repair: ${line_count_changed} entry/entries corrected from wc -l" \
        --detail-json "$(jq -n -c --argjson n "$line_count_changed" --argjson exts "$line_count_exts" '{corrected_count: $n, extensions: $exts}')" \
        >/dev/null 2>&1 || true
    fi
  fi

  echo "[deploy-headless] Deploying extension tree into $TARGET/.claude ..."
  echo "[deploy-headless] deploy-lock: $mutex_status"

  # `manager` derives project_dir from the explicit project_dir option below, never from
  # vim.fn.getcwd() implicitly -- cwd is still set to TARGET for module resolution consistency
  # with the rest of the headless invocation. stderr is kept: a require failure or Lua error
  # must remain visible rather than be swallowed.
  #
  # NVIM_ARGS: the base nvim invocation, extended by --minimal-init to `--clean --cmd "set
  # rtp+=DIR"` instead of the default plain `nvim --headless` (which loads init.lua and pays the
  # full lazy.nvim plugin bootstrap). Absent --minimal-init this array is unchanged from before
  # the flag existed, so default-mode behavior stays byte-for-byte identical.
  local -a NVIM_ARGS=(nvim --headless)
  if [ -n "$MINIMAL_INIT_DIR" ]; then
    NVIM_ARGS+=(--clean --cmd "set rtp+=${MINIMAL_INIT_DIR}")
  fi

  local output
  if [ "$WIPE" = "true" ]; then
    output=$(cd "$TARGET" && "${NVIM_ARGS[@]}" \
      -c "lua local ok1, ext_config = pcall(require, '${EXT_CONFIG_MODULE}'); local ok2, ext_init = pcall(require, '${EXT_INIT_MODULE}'); if not (ok1 and ok2) then print('DEPLOY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, wok, result = pcall(manager.wipe, {project_dir = '${TARGET}'}); if not pok then print('DEPLOY_ERROR call: ' .. tostring(wok)) elseif not wok then print('DEPLOY_ERROR wipe-refused: ' .. tostring(result)) elseif #result.failed > 0 then local msgs = {}; for _, f in ipairs(result.failed) do table.insert(msgs, f.name .. ': ' .. tostring(f.error)) end; print('DEPLOY_ERROR wipe-partial: ' .. table.concat(msgs, '; ')) else print('DEPLOY_COUNT=' .. tostring(#result.loaded)) end end" \
      -c "qa!" 2>&1) || true
  else
    output=$(cd "$TARGET" && "${NVIM_ARGS[@]}" \
      -c "lua local ok1, ext_config = pcall(require, '${EXT_CONFIG_MODULE}'); local ok2, ext_init = pcall(require, '${EXT_INIT_MODULE}'); if not (ok1 and ok2) then print('DEPLOY_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local bok, bsucc, berr = pcall(manager.load, 'core', {confirm = false, force = true, project_dir = '${TARGET}'}); if not bok then print('DEPLOY_ERROR bootstrap-call: ' .. tostring(bsucc)) elseif not bsucc then print('DEPLOY_ERROR bootstrap: ' .. tostring(berr)) else local rok, result = pcall(manager.resync_all, {project_dir = '${TARGET}'}); if not rok then print('DEPLOY_ERROR resync-call: ' .. tostring(result)) elseif #result.failed > 0 then local msgs = {}; for _, f in ipairs(result.failed) do table.insert(msgs, f.name .. ': ' .. tostring(f.error)) end; print('DEPLOY_ERROR resync-partial: ' .. table.concat(msgs, '; ')) else print('DEPLOY_COUNT=' .. tostring(#result.succeeded)) end end end" \
      -c "qa!" 2>&1) || true
  fi

  if echo "$output" | grep -q 'DEPLOY_ERROR'; then
    echo "ERROR: headless deploy failed." >&2
    echo "$output" | grep 'DEPLOY_ERROR' >&2
    _dh_result_and_exit not_landed 2
  fi

  local count
  count=$(echo "$output" | grep -o 'DEPLOY_COUNT=[0-9]*' | head -1 | cut -d= -f2) || true

  if [ -z "$count" ]; then
    echo "ERROR: headless deploy produced no result count; treating as failure." >&2
    echo "--- nvim output ---" >&2
    echo "$output" >&2
    _dh_result_and_exit not_landed 2
  fi

  if [ "$WIPE" = "true" ]; then
    echo "[deploy-headless] Wiped and regenerated $count extension(s) into $TARGET/.claude"
  else
    echo "[deploy-headless] Resynced $count extension(s) into $TARGET/.claude"
  fi

  echo "[deploy-headless] Verifying deploy (fast gates; shell test suite deferred) ..."
  # Verify outcome is captured into a variable rather than exiting directly from each branch, so
  # the guarded post-deploy consumer report below (both branches: it must run after the tree WAS
  # modified, whether verification passed or reported findings) can run before the script's
  # single final exit. Each branch below still exits with EXACTLY the same code it always did --
  # 0 or 3 -- this restructuring changes nothing about deploy-headless.sh's documented exit-code
  # contract (see the header's `# Exit codes:` block).
  local verify_rc=0
  local -a VERIFY_ARGS=(--skip-slow)
  if [ -n "$MINIMAL_INIT_DIR" ]; then
    VERIFY_ARGS+=(--minimal-init "$MINIMAL_INIT_DIR")
  fi
  if bash "$TARGET/.claude/scripts/verify-deploy.sh" "${VERIFY_ARGS[@]}" "$TARGET"; then
    echo "[deploy-headless] Verification passed."
    verify_rc=0
  else
    echo "[deploy-headless] ERROR: the deploy itself landed, but the tree fails verification (fast gates)." >&2
    echo "[deploy-headless] Re-run the full gate set for detail: bash $TARGET/.claude/scripts/verify-deploy.sh" >&2
    verify_rc=3
  fi

  # --- Post-deploy stale-consumer report (TIER 3, additive output only) -----------------------
  # This block reports only and MUST NOT deploy into, write to, or otherwise mutate any named
  # consumer repo -- see context/patterns/regeneration-is-manual-only.md's pull-only design,
  # which this call preserves intact (every consumer interaction below is a read of that
  # consumer's OWN .claude-extensions.json via check-consumer-freshness.sh). Fully guarded: only
  # runs when the deployed checker exists (a tree too stale to carry it yet is a silent no-op,
  # matching check-deploy-freshness.sh's own guard convention), and its own exit code can never
  # propagate into this script's exit code -- `|| true` below.
  #
  # CONFIRMED AT RUNTIME (not merely by static reading) that this block can never influence
  # $verify_rc or this script's exit code: $verify_rc is set above, BEFORE this block runs, and
  # is never reassigned below; consumer_report's own exit code is unconditionally absorbed by
  # `|| true`. A scratch-target run against this repo's own real (populated, several genuinely
  # STALE) consumer registry -- traced with `bash -x` -- showed `verify_rc` unchanged by this
  # block and the final `exit "$verify_rc"` firing with the value set above. Consumer staleness
  # is report-only and can NEVER change this script's exit code; CONSUMERS_STALE= below is the
  # machine-readable form of that same report, never a second vote on the exit code.
  local consumer_checker="$TARGET/.claude/scripts/check-consumer-freshness.sh"
  if [ -f "$consumer_checker" ]; then
    local consumer_report
    consumer_report="$(bash "$consumer_checker" --stale-only 2>&1)" || true
    local consumer_stale_count=0
    if [ -n "$consumer_report" ]; then
      consumer_stale_count=$(printf '%s\n' "$consumer_report" | grep -c .)
      echo ""
      echo "[deploy-headless] Known consumer repos now stale relative to the source store:"
      echo "$consumer_report"
      echo "[deploy-headless] Remedy: run 'bash .claude/scripts/deploy-headless.sh' IN EACH stale repo (this script never redeploys into a consumer)."
    fi
    echo "[deploy-headless] CONSUMERS_STALE=${consumer_stale_count}"
  fi

  if [ "$verify_rc" -eq 0 ]; then
    _dh_result_and_exit landed_verify_clean 0
  else
    _dh_result_and_exit landed_verify_red 3
  fi
}

main "$@"
