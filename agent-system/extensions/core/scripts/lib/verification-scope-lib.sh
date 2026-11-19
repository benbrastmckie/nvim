#!/usr/bin/env bash
# verification-scope-lib.sh - Single home of the repo-declared `verification_scope` reader: a
# repository's own touched-path-verification topology (which directory tree(s) a scoped run
# covers, where a project's own non-core-authored suites live, and which resolver backend to
# invoke), read from a hand-authored sibling key in <repo_root>/.claude-extensions.json. See
# context/standards/repo-level-declarations.md's "The verification_scope Entry Schema" section
# for the full schema writeup; this header states only the contract this library itself commits
# to.
#
# Sourced (never executed) -- modelled structurally on
# scripts/lib/derived-artifact-probe-lib.sh's `_derived_probe_load_entries_json` fail-open shape:
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Never calls `exit` -- every function below always returns 0.
#   - Every internal variable/function is prefixed `_vsl_`. The public surface
#     (`verification_scope_*` functions) is this library's contract and is never unset.
#
# Declaration point:
#
#   {
#     "verification_scope": {
#       "tree_roots": ["<repo-root-relative dir>", ...],
#       "project_suite_roots": ["<repo-root-relative dir>", ...],
#       "resolver": {
#         "command": "<a single shell command string, or omitted for the default backend>",
#         "compose": "union" | "replace"
#       },
#       "project_gates": ...,
#       "closing_gate": "<a single shell command string emitting ^FINDING -prefixed lines, or omitted>"
#     }
#   }
#
# `project_gates` is still a RESERVED field name on this same object (owned by the
# project-sources narrowing record; see repo-level-declarations.md) -- this library does not read
# or validate it, so a future reader adding it does not need to touch this file. `closing_gate`
# is NO LONGER reserved-but-unread: function (e) below is its reader, added once the
# orchestration-close record actually needed it (see repo-level-declarations.md's "Decisions
# Settled" section).
#
# Five exported functions:
#
#   (a) verification_scope_tree_roots <repo_root> - prints one repo-root-relative tree root per
#       line. Default (undeclared/malformed): the single resolved repository root (today's
#       behaviour -- a scoped run covers exactly the one tree it is invoked against).
#
#   (b) verification_scope_project_suite_roots <repo_root> - prints one repo-root-relative
#       project-suite root per line. Default: empty (no project-owned suites outside the deploy
#       tree).
#
#   (c) verification_scope_resolver_command <repo_root> - prints the declared resolver backend's
#       command string, or nothing (empty output, rc 0) when undeclared -- "nothing declared"
#       means "use the default backend", the caller's (suite-resolver-lib.sh's) job to interpret,
#       never this library's.
#
#   (d) verification_scope_resolver_compose <repo_root> - prints exactly one of "union" or
#       "replace". Default (undeclared, malformed, or no resolver.command at all): "union" --
#       i.e. today's behaviour (the default backend alone) is the degenerate case of "union with
#       nothing declared", so this default is safe even when no backend is declared at all.
#
#   (e) verification_scope_closing_gate <repo_root> - prints the declared `closing_gate` command
#       string, or nothing when undeclared/not a string. Default (undeclared, malformed): no
#       declared closing gate; the caller's own default (`verify-deploy.sh`) applies.
#
# Fail-open posture (absolute, no exceptions -- same table shape as
# derived-artifact-probe-lib.sh's own): a missing .claude-extensions.json, a missing `jq`, an
# absent `verification_scope` key, or a malformed entry all yield the stated defaults above, NEVER
# a block and NEVER a hard failure. A repo that declares nothing is byte-for-byte unaffected. The
# ONE deliberate exception to this absolute posture lives in the CONSUMER
# (`scripts/orchestrate-batch-gate.sh`), not here: a declared-but-UNUSABLE `closing_gate` command
# (nonzero exit, no parseable `FINDING ` line) is a loud failure at that call site, never a
# silent empty-findings pass -- this library's own job stays limited to "declared or not,
# string or not", never to validating the command's own runtime behavior.
#
# Consumers:
#   - scripts/verify-touched.sh (the entry point; reads (a)-(d))
#   - scripts/lib/suite-resolver-lib.sh (the declared-backend invocation; reads (c) and (d))
#   - scripts/report-suite-coverage.sh (the coverage report; reads (a))
#   - scripts/orchestrate-batch-gate.sh (the orchestration-close stage; reads (e))

# _vsl_load_scope_json <repo_root> -- stdout: the raw (unvalidated) `verification_scope` object
# from <repo_root>/.claude-extensions.json, or "{}" for every absence/cannot-parse case. Never
# signals failure; every caller below treats the output as the object to read fields from.
_vsl_load_scope_json() {
  local repo_root="$1"
  local state_file="${repo_root}/.claude-extensions.json"

  if [ ! -f "$state_file" ] || ! command -v jq >/dev/null 2>&1; then
    echo "{}"
    return 0
  fi

  local json
  json="$(cat "$state_file" 2>/dev/null)"
  if [ -z "$json" ] || ! echo "$json" | jq -e . >/dev/null 2>&1; then
    echo "{}"
    return 0
  fi

  local raw
  raw="$(echo "$json" | jq -c '.verification_scope // {} | if (type == "object") then . else {} end' 2>/dev/null)"
  if [ -z "$raw" ]; then
    echo "{}"
    return 0
  fi
  echo "$raw"
  return 0
}

# verification_scope_tree_roots <repo_root>
# Prints one repo-root-relative tree root per line. Default: the resolved repo_root itself
# (repo-root-relative form: "."), when the key is absent, malformed, or declares an empty array.
verification_scope_tree_roots() {
  local repo_root="${1:?verification_scope_tree_roots: repo_root required}"
  local scope_json roots_json count
  scope_json="$(_vsl_load_scope_json "$repo_root")"
  roots_json="$(echo "$scope_json" | jq -c '.tree_roots // null' 2>/dev/null)"

  if ! echo "$roots_json" | jq -e 'type == "array" and (all(.[]; type == "string" and length > 0))' >/dev/null 2>&1; then
    echo "."
    return 0
  fi
  count="$(echo "$roots_json" | jq 'length' 2>/dev/null)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  if [ "$count" -eq 0 ]; then
    echo "."
    return 0
  fi
  echo "$roots_json" | jq -r '.[]'
  return 0
}

# verification_scope_project_suite_roots <repo_root>
# Prints one repo-root-relative project-suite root per line. Default: empty output (no project
# suites declared outside the deploy tree).
verification_scope_project_suite_roots() {
  local repo_root="${1:?verification_scope_project_suite_roots: repo_root required}"
  local scope_json roots_json
  scope_json="$(_vsl_load_scope_json "$repo_root")"
  roots_json="$(echo "$scope_json" | jq -c '.project_suite_roots // null' 2>/dev/null)"

  if ! echo "$roots_json" | jq -e 'type == "array" and (all(.[]; type == "string" and length > 0))' >/dev/null 2>&1; then
    return 0
  fi
  echo "$roots_json" | jq -r '.[]'
  return 0
}

# verification_scope_resolver_command <repo_root>
# Prints the declared resolver backend command string, or nothing when undeclared/malformed.
verification_scope_resolver_command() {
  local repo_root="${1:?verification_scope_resolver_command: repo_root required}"
  local scope_json cmd
  scope_json="$(_vsl_load_scope_json "$repo_root")"
  cmd="$(echo "$scope_json" | jq -r '.resolver.command // ""' 2>/dev/null)"
  [ -n "$cmd" ] && printf '%s\n' "$cmd"
  return 0
}

# verification_scope_resolver_compose <repo_root>
# Prints exactly one of "union" or "replace". Default: "union".
verification_scope_resolver_compose() {
  local repo_root="${1:?verification_scope_resolver_compose: repo_root required}"
  local scope_json compose
  scope_json="$(_vsl_load_scope_json "$repo_root")"
  compose="$(echo "$scope_json" | jq -r '.resolver.compose // "union"' 2>/dev/null)"
  case "$compose" in
    union|replace) printf '%s\n' "$compose" ;;
    *) printf '%s\n' "union" ;;
  esac
  return 0
}

# verification_scope_closing_gate <repo_root>
# Prints the declared `closing_gate` command string, or nothing (empty output, rc 0) when
# undeclared, empty, or not a string -- "nothing declared" means "no repository-specific closing
# gate; the caller's own default (verify-deploy.sh) applies", exactly the same absence contract
# `verification_scope_resolver_command` already uses for `resolver.command`. This is the first
# reader `closing_gate` has had since it was reserved on this object -- see
# context/standards/repo-level-declarations.md's "Decisions Settled" section for the field's own
# resolution and `scripts/orchestrate-batch-gate.sh` for the consumer.
verification_scope_closing_gate() {
  local repo_root="${1:?verification_scope_closing_gate: repo_root required}"
  local scope_json cmd
  scope_json="$(_vsl_load_scope_json "$repo_root")"
  cmd="$(echo "$scope_json" | jq -r 'if (.closing_gate | type) == "string" then .closing_gate else "" end' 2>/dev/null)"
  [ -n "$cmd" ] && printf '%s\n' "$cmd"
  return 0
}
