#!/usr/bin/env bash
# territory-contention-lib.sh - Sibling-territory payload construction and contended-path
# manifest production, extracted verbatim from orchestrate-cycle-plan.sh's
# orchestrate_cycle_plan_main() (Phase 4 of the script-corpus decomposition task).
#
# EXTRACTION METHOD, STATED EXPLICITLY (read this before touching anything below): the four
# functions below were nested function definitions INSIDE orchestrate_cycle_plan_main()'s own
# body, which the task's plan originally assumed meant every reference to a main()-scoped
# variable (`effective_group`, `session_id`, `new_cycle_count`, `CONTENDED_MANIFEST_DIR`,
# `PROJECT_ROOT`) would need converting to an explicit parameter before the code could safely
# move. That assumption does not hold for bash. Bash scopes `local` DYNAMICALLY (by call stack),
# not lexically (by textual nesting) -- a function defined in a separately-sourced file still
# sees a caller's `local` variables when invoked from within that caller's own execution, exactly
# as if it had remained textually nested. This was verified directly (two minimal fixtures, one
# with a scalar `local`, one with a `local -A` associative array, both sourced from a separate
# file and both correctly visible inside the callee) before this extraction was done. Of the five
# variables named above, only `effective_group` is actually function-local to
# orchestrate_cycle_plan_main() (`declare -A effective_group=()`, no `-g`, inside its body);
# `session_id` and `PROJECT_ROOT` are plain top-level script globals set before
# orchestrate_cycle_plan_main() is even defined, and `new_cycle_count`/`CONTENDED_MANIFEST_DIR`
# are bare (no `local`/`declare`) assignments inside the function body, which bash treats as
# ordinary globals. The code below is therefore a VERBATIM, byte-for-byte relocation of the
# original text (function bodies unchanged, no parameter list added, no explicit-argument
# threading introduced) -- the lowest-risk transformation available, and the one that makes the
# required byte-identical `--dry-run` diff a structural guarantee rather than something to verify
# painstakingly line by line. `source` this file from orchestrate-cycle-plan.sh AFTER
# `PROJECT_ROOT` is assigned (this file's own top-level `CONTENDED_MANIFEST_DIR="$PROJECT_ROOT/..."`
# assignment line depends on it) and BEFORE orchestrate_cycle_plan_main() is invoked; both
# functions below are called only from within that function's own execution, where
# `effective_group` is already a live local by dynamic scoping.
#
# This file complements, rather than re-derives, scripts/lib/file-scope-overlap.sh's
# `scopes_overlap`/`path_covered_by_scope` primitives: `_sibling_territory_classify_entry`'s
# glob-detection character class (`*[*?\[]*`) is the SAME transcription file-scope-overlap.sh's
# own header already names as one of three existing bash copies of that test (the others being
# that file's own `path_covered_by_scope` and `is_glob_entry`'s jq equivalent) -- moving this
# text here does not add a fourth copy, it relocates one of the three that already existed.
# `_paths_contend`'s directory/glob containment check is deliberately NOT swapped for
# `scopes_overlap` here: that would be a semantic change (`scopes_overlap` is Overlap, not
# Containment, per context/patterns/file-footprint-overlap.md's own Non-Goals section), which the
# behaviour-preserving mandate for this extraction forbids regardless of which primitive might be
# "more correct" in the abstract.
#
# ── Sibling territory (base mode AND hard mode; the task that carries concurrent-sibling
# territory into base-mode dispatch briefs) — a dispatch file is the ONLY channel that reaches a
# dispatched agent once it is running: a message sent to a live dispatch does not arrive until
# after it finishes (see context/patterns/dispatch-report-not-termination.md). Before this task,
# `--territory` was populated ONLY for a hard-mode implement candidate's own H1/H7 "which files do
# I own within my own plan" fact — cross-TASK concurrency within one batch (two DIFFERENT tasks
# dispatched the same cycle, onto the SAME shared working tree) was invisible to every dispatch,
# in every mode, because nothing computed or carried it. This section closes that gap: it builds a
# `concurrent_siblings` payload for EVERY dispatch this cycle builds, in EVERY mode, whenever the
# cycle schedules more than one task. A single-task cycle schedules no siblings, so
# `build_sibling_territory` returns the empty string and the resulting dispatch file is
# byte-identical to one built before this feature existed (the Phase 3 fixture's regression case).
#
# Payload shape (passed opaquely to orchestrate-build-dispatch.sh's own --territory flag, which
# already renders whatever JSON it is given under "## Territory" — see that script's own header;
# this script never re-implements that rendering):
#   {"concurrent_siblings": [{"task_number": N, "phase": "research"|"plan"|"implement",
#     "file_scope": [...]|null, "scope_declared": true|false,
#     "scope_granularity": "file"|"coarse"|"undeclared",
#     "entries": [{"path": "...", "granularity": "file"|"directory"|"glob"}, ...],
#     "note": "..."|null}, ...],
#    "concurrency_note": "..."}
#
# Granularity (Decision 3 of the originating plan): a `file_scope` entry is "directory" when it
# ends in "/" or already names an existing directory relative to the repo root, "glob" when it
# contains `*`, `?`, or `[`, else "file". A sibling's roll-up `scope_granularity` is "file" only
# when every entry is "file"; any directory/glob entry makes it "coarse"; an absent, null, or
# empty `file_scope` makes it "undeclared" — rendered explicitly, never dropped from the list, per
# Decision 3: a sibling with no declared scope is exactly the failure mode both incidents in this
# task's own description trace back to. A "coarse" or "undeclared" sibling's `note` field warns
# that it may touch any file (within its declared directory/glob, or anywhere at all when
# undeclared); a "file"-granularity sibling's `note` is `null`.
#
# Absent-file_scope ADMISSION POSTURE is explicitly NOT decided here (Decision 4): whether an
# absent or coarse `file_scope` should defer admission in the first place belongs to the separate,
# already-filed work scoped to `orchestrate-batch-admit.sh`'s own admission gate. This payload only
# REPRESENTS the absence/coarseness so a dispatched agent can see and react to it; this task
# consumes whatever that separate work rules and does not edit `orchestrate-batch-admit.sh`.
#
# aux_dispatch[] rows (built earlier, above, by orchestrate-build-aux-dispatch.sh — see the AUX
# EMISSION section) are DELIBERATELY EXCLUDED from `concurrent_siblings`, confirmed rather than
# assumed: that builder has no `--territory` plumbing at all, and every aux kind
# (blocker-research, drift-inspection, plan-revision, divergence-audit) is a short, single-purpose
# research/revision call that never loops over a task's own `file_scope` editing files the way an
# implement dispatch does — the file-collision risk this payload guards against does not apply to
# it. A future task may extend `--territory` plumbing to that builder; this one does not.
#
# Sequencing rationale (Decision 5) is deliberately GENERIC, never per-pair: nothing in this
# codebase computes non-idempotence between two specific tasks, so `concurrency_note` carries one
# fixed procedural instruction (re-read a shared file immediately before editing it, stage only
# this task's own hunks, never run a reverting git-snapshot.sh, treat a foreign-scope build
# failure as possibly a sibling's in-flight edit rather than your own regression, and STOP-and-
# report on foreign work only after a `git log` self-check) instead of a fabricated claim about
# which specific pair of tasks will actually collide.
#
# Over-inclusion is intentional (Decision 6): a dispatch file is built before later same-cycle
# siblings acquire their own locks, so a sibling later deferred by this same live loop may still
# be named here. The wording says "scheduled concurrently this cycle", never "running" — naming a
# sibling that ends up deferred is a false positive an agent can dismiss with one `git log` check;
# silently omitting one that IS running is the failure mode this whole task exists to close.
_sibling_territory_classify_entry() {
  # <path> -> echoes "file" | "directory" | "glob" (Decision 3's granularity vocabulary).
  local path="$1"
  case "$path" in
    */) echo "directory"; return ;;
    *[*?\[]*) echo "glob"; return ;;
  esac
  if [ -d "${PROJECT_ROOT}/${path}" ]; then
    echo "directory"
  else
    echo "file"
  fi
}

build_sibling_territory() {
  # build_sibling_territory <self_task> <sibling_task_number>...
  # Echoes the compact JSON object described in the header block above, or the empty string when
  # the sibling list is empty (caller skips the --territory flag entirely in that case — the
  # empty-value-skips-flag convention this script already uses everywhere else). Reuses
  # `lookup_project` (this script's own active+archive task lookup, defined above) rather than a
  # second hand-written jq query against $STATE_FILE — Finding 2/Rec 2 of the originating report:
  # no new discovery mechanism is needed.
  local self_t="$1"; shift
  local -a siblings=("$@")
  [ "${#siblings[@]}" -eq 0 ] && { printf ''; return 0; }

  local -a sibling_rows=()
  local s sib_phase sib_entry sib_scope_json sib_declared sib_gran sib_note path gran entries_json entry_json
  for s in "${siblings[@]}"; do
    # Defense in depth: every live call site already excludes $self_t from the list it builds,
    # but a self-referential entry here would be a confusing "you are your own sibling" payload,
    # so skip it defensively rather than trust every future call site to get the exclusion right.
    [ "$s" = "$self_t" ] && continue
    sib_phase="${effective_group[$s]:-unknown}"
    sib_entry=$(lookup_project "$s") || sib_entry=""
    if [ -z "$sib_entry" ] || [ "$sib_entry" = "null" ]; then
      sib_scope_json="null"
    else
      sib_scope_json=$(echo "$sib_entry" | jq -c '.file_scope // null')
    fi

    local -a sib_entries=()
    if [ "$sib_scope_json" = "null" ] || [ "$sib_scope_json" = "[]" ]; then
      sib_declared="false"
      sib_gran="undeclared"
      sib_note="No file_scope declared for this task -- it may touch any file in the repository."
    else
      sib_declared="true"
      sib_gran="file"
      while IFS= read -r path; do
        [ -z "$path" ] && continue
        gran=$(_sibling_territory_classify_entry "$path")
        [ "$gran" != "file" ] && sib_gran="coarse"
        sib_entries+=("$(jq -n -c --arg p "$path" --arg g "$gran" '{path: $p, granularity: $g}')")
      done < <(echo "$sib_scope_json" | jq -r '.[]')
      if [ "$sib_gran" = "coarse" ]; then
        sib_note="Declared file_scope includes a directory or glob entry -- this task may touch any file within it."
      else
        sib_note=""
      fi
    fi

    entries_json="[]"
    [ "${#sib_entries[@]}" -gt 0 ] && entries_json="[$(IFS=,; echo "${sib_entries[*]}")]"

    entry_json=$(jq -n -c --argjson t "$s" --arg p "$sib_phase" --argjson fs "$sib_scope_json" \
      --argjson decl "$([ "$sib_declared" = "true" ] && echo true || echo false)" \
      --arg g "$sib_gran" --argjson e "$entries_json" --arg note "$sib_note" \
      '{task_number: $t, phase: $p, file_scope: $fs, scope_declared: $decl, scope_granularity: $g,
        entries: $e, note: (if $note == "" then null else $note end)}')
    sibling_rows+=("$entry_json")
  done

  local siblings_json
  siblings_json="[$(IFS=,; echo "${sibling_rows[*]}")]"
  local note
  note='One or more sibling tasks are scheduled for dispatch THIS SAME /orchestrate cycle, on this same shared working tree. Before editing or committing any file: (1) re-read it immediately beforehand, in case a sibling has already changed it; (2) stage and commit only this task'"'"'s own hunks, never a directory or glob add; (3) never run git-snapshot.sh in its reverting default mode; (4) treat an unexpected build failure in a file outside your own file_scope as possibly a sibling'"'"'s in-flight edit, not necessarily your own regression; (5) if you observe a foreign commit, a foreign uncommitted modification, or a running build you did not start, STOP and report it -- after checking git log to confirm the work is not your own -- rather than proceeding or dismissing it as noise. See context/contracts/territory.md (Cross-Task Territory section) and context/patterns/dispatch-report-not-termination.md.'
  jq -n -c --argjson sibs "$siblings_json" --arg note "$note" '{concurrent_siblings: $sibs, concurrency_note: $note}'
}

# ── Contended-path manifest producer (working-tree/build isolation posture decision record,
# "Narrower Staging-Layer Alternative" -- option 3(ii)'s cheap precondition) ─────────────────────
# Mechanically derives, for THIS cycle only, the set of paths two or more concurrently-dispatched
# tasks are contending for -- no agent cooperation, reusing the SAME per-task file_scope +
# granularity classification `build_sibling_territory` already computes above
# (`_sibling_territory_classify_entry`'s "file"|"directory"|"glob" vocabulary), per this phase's
# own Scope Hypothesis (confirmed: that helper already carries every input this producer needs --
# per-task `file_scope`, granularity, and the set of tasks dispatched this cycle -- so nothing new
# is derived here). git-commit-scoped.sh (a later phase) reads this manifest at commit time to
# refuse staging a still-contended path a live sibling holds a claim on; this producer only writes
# the manifest, never itself gates or refuses anything.
#
# A path is CONTENDED when it appears in the declared `file_scope` of two or more tasks dispatched
# this same cycle; a directory/glob entry contends with any path beneath it (or matching it, for a
# glob). Skipped entirely for a single-task cycle (no contention is possible) and, structurally,
# under --dry-run too -- this function is only ever called from the live-only half below, which
# --dry-run's own emit_and_exit return never reaches; a --dry-run cycle therefore performs no
# manifest write or removal of its own, matching this phase's own "byte-identical in both cases"
# requirement. Every dispatched task shares the one working tree, so every task with a declared
# `file_scope` participates in contention accounting -- including a build-heavy implement task;
# there is no working-tree-isolation exclusion.
CONTENDED_MANIFEST_DIR="$PROJECT_ROOT/specs/.contention-manifest"

# _paths_contend <path_a> <gran_a> <path_b> <gran_b> -- true (rc 0) when two DECLARED file_scope
# entries overlap: identical strings, or either side is a "directory" entry that is a literal
# path-prefix of the other, or either side is a "glob" entry the other matches (bash's own glob
# semantics via `case`, consistent with how file_scope globs are documented/authored elsewhere).
_paths_contend() {
  local pa="$1" ga="$2" pb="$3" gb="$4"
  [ "$pa" = "$pb" ] && return 0
  if [ "$ga" = "directory" ]; then
    case "$pb" in "${pa%/}"/*) return 0 ;; esac
  fi
  if [ "$gb" = "directory" ]; then
    case "$pa" in "${pb%/}"/*) return 0 ;; esac
  fi
  if [ "$ga" = "glob" ]; then
    # shellcheck disable=SC2254  # $pa is deliberately unquoted here -- it IS the glob pattern.
    case "$pb" in $pa) return 0 ;; esac
  fi
  if [ "$gb" = "glob" ]; then
    # shellcheck disable=SC2254  # $pb is deliberately unquoted here -- it IS the glob pattern.
    case "$pa" in $pb) return 0 ;; esac
  fi
  return 1
}

build_contended_manifest() {
  # build_contended_manifest <task_number>...  -- the FULL set of tasks dispatched this cycle
  # (probed_dispatch_post_h1). Writes (or removes) $CONTENDED_MANIFEST_DIR/${session_id}.json --
  # one file per session, OVERWRITTEN every cycle (never merged across cycles), matching the
  # existing `specs/.commit-lock/`/`specs/.scope-lock/` ephemeral-runtime-path convention.
  local -a tasks=("$@")
  local manifest_path="$CONTENDED_MANIFEST_DIR/${session_id}.json"

  if [ "${#tasks[@]}" -lt 2 ]; then
    # Single-task (or zero-task) cycle: contention is structurally impossible. Actively remove
    # any manifest a PRIOR, larger cycle in this same session left behind, rather than merely
    # skipping the write -- a stale manifest naming tasks no longer in flight this cycle would be
    # a silent false-positive source for git-commit-scoped.sh's later refusal check.
    rm -f "$manifest_path" 2>/dev/null || true
    return 0
  fi

  local -A path_granularity=()
  local -A path_declarers=()   # path -> space-joined, deduped task numbers that declare it
  local ct ct_entry ct_scope_json path gran

  for ct in "${tasks[@]}"; do
    ct_entry=$(lookup_project "$ct") || ct_entry=""
    { [ -z "$ct_entry" ] || [ "$ct_entry" = "null" ]; } && continue
    ct_scope_json=$(echo "$ct_entry" | jq -c '.file_scope // []')
    case "$ct_scope_json" in ''|'null'|'[]') continue ;; esac
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      gran=$(_sibling_territory_classify_entry "$path")
      path_granularity["$path"]="$gran"
      case " ${path_declarers[$path]:-} " in
        *" $ct "*) : ;;
        *) path_declarers["$path"]="${path_declarers[$path]:-} $ct" ;;
      esac
    done < <(echo "$ct_scope_json" | jq -r '.[]')
  done

  local -a unique_paths=()
  if [ "${#path_granularity[@]}" -gt 0 ]; then
    unique_paths=("${!path_granularity[@]}")
  fi
  if [ "${#unique_paths[@]}" -eq 0 ]; then
    rm -f "$manifest_path" 2>/dev/null || true
    return 0
  fi

  local -a manifest_rows=()
  local p q gp gq tasks_union dq
  for p in "${unique_paths[@]}"; do
    gp="${path_granularity[$p]}"
    tasks_union="${path_declarers[$p]}"
    for q in "${unique_paths[@]}"; do
      [ "$p" = "$q" ] && continue
      gq="${path_granularity[$q]}"
      if _paths_contend "$p" "$gp" "$q" "$gq"; then
        for dq in ${path_declarers[$q]}; do
          case " $tasks_union " in
            *" $dq "*) : ;;
            *) tasks_union="$tasks_union $dq" ;;
          esac
        done
      fi
    done

    local -a uniq_tasks=()
    local tk uniq_probe
    for tk in $tasks_union; do
      uniq_probe=""
      [ "${#uniq_tasks[@]}" -gt 0 ] && uniq_probe=" $(printf '%s ' "${uniq_tasks[@]}")"
      case "$uniq_probe" in
        *" $tk "*) : ;;
        *) uniq_tasks+=("$tk") ;;
      esac
    done

    if [ "${#uniq_tasks[@]}" -ge 2 ]; then
      local sorted_tasks tasks_json
      sorted_tasks=$(printf '%s\n' "${uniq_tasks[@]}" | sort -n)
      tasks_json=$(printf '%s\n' "$sorted_tasks" | jq -R 'select(length > 0) | tonumber' | jq -sc '.')
      manifest_rows+=("$(jq -n -c --arg p "$p" --arg g "$gp" --argjson tk "$tasks_json" \
        '{path: $p, tasks: $tk, granularity: $g}')")
    fi
  done

  if [ "${#manifest_rows[@]}" -eq 0 ]; then
    rm -f "$manifest_path" 2>/dev/null || true
    return 0
  fi

  mkdir -p "$CONTENDED_MANIFEST_DIR"
  local generated_at contended_json tmp_manifest
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  contended_json="[$(IFS=,; echo "${manifest_rows[*]}")]"
  tmp_manifest="$(mktemp "${CONTENDED_MANIFEST_DIR}/.tmp.XXXXXX")"
  jq -n -c --arg sid "$session_id" --argjson cyc "$new_cycle_count" --arg gen "$generated_at" \
    --argjson c "$contended_json" \
    '{session_id: $sid, cycle: $cyc, generated_at: $gen, contended: $c}' > "$tmp_manifest"
  mv "$tmp_manifest" "$manifest_path"
  echo "[orchestrate] Contended-path manifest: ${#manifest_rows[@]} path(s) contended across ${#tasks[@]} dispatched task(s) this cycle -- $manifest_path" >&2
}
