#!/usr/bin/env bash
# orchestrate-recover-message-findings.sh — Save a research subagent's message-borne findings as
# a clearly-tagged recovered artifact, for the exact case orchestrate-cycle-postflight.sh's
# `report_missing=true` output field names (D4): the dispatched agent returned its findings by
# message instead of writing its contract-mandated report file. This script never authorizes
# treating that message as a completed research report — it preserves the agent's own already-
# produced text verbatim so it is not silently lost, under a banner that says exactly what
# happened and why.
#
# WHY THIS SCRIPT, RATHER THAN THE LEAD WRITING THE FILE DIRECTLY: `skill-orchestrate/SKILL.md`'s
# own "MUST NOT (Postflight Boundary)" section forbids the orchestrator lead from authoring
# artifact content. This is a narrow, named exception to that boundary (see the boundary text
# itself): the lead captures the dispatched agent's own returned text verbatim to a local file,
# unedited, and this script — mechanical, not the lead's own judgment — owns naming, the
# recovered-content banner, and the never-clobber rule. Persisting a subagent's own
# already-produced text verbatim is preservation, not authorship.
#
# Usage:
#   orchestrate-recover-message-findings.sh --task-dir DIR --dispatch-seq N --message-file F \
#     --agent NAME --session SID [--dry-run]
#
# Naming: reads ${TASK_DIR}/.dispatch/${dispatch-seq}.md's own "## Artifact Round" section for
# `artifact_padded` and `output_dir` (the same fields orchestrate-build-dispatch.sh writes for
# every dispatch — see that script's own dispatch-file template). Falls back to `reports/` and
# `01` with a named WARN when the dispatch file is missing or the fields cannot be parsed (this
# is diagnostic, not fatal — the file is still written under the fallback name). The target file
# is `{output_dir}/{artifact_padded}_recovered-agent-message.md`; `output_dir` is resolved
# against the repo root when relative (the same convention orchestrate-cycle-postflight.sh's own
# artifact_path resolution uses). Never overwrites: if the target already exists and is
# non-empty, `-2`, `-3`, ... suffixes are tried until a free name is found.
#
# This script NEVER touches specs/state.json, .return-meta.json, or .orchestrator-handoff.json —
# it writes exactly one new report-directory file (or nothing, under --dry-run or on an empty
# message) and prints one JSON line. It is non-fatal to the caller's own loop by design: every
# defined outcome below exits 0.
#
# Output: one compact JSON line on stdout:
#   success:        {"recovered": true, "path": "<repo-relative path written>"}
#   empty message:  {"recovered": false, "reason": "EMPTY_MESSAGE"}
#   dry-run:        {"recovered": false, "reason": "DRY_RUN", "would_write": "<path>"}
#
# Exit codes: 0 always (see above) for every defined outcome reachable past argument parsing.
#   2 — usage error (a required flag missing, or an unrecognized flag).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

usage() {
  cat <<'USAGE'
Usage: orchestrate-recover-message-findings.sh --task-dir DIR --dispatch-seq N \
         --message-file F --agent NAME --session SID [--dry-run]
USAGE
}

task_dir_arg=""
dispatch_seq=""
message_file=""
agent_name=""
session_id=""
dry_run="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task-dir) task_dir_arg="${2:-}"; shift 2 ;;
    --dispatch-seq) dispatch_seq="${2:-}"; shift 2 ;;
    --message-file) message_file="${2:-}"; shift 2 ;;
    --agent) agent_name="${2:-}"; shift 2 ;;
    --session) session_id="${2:-}"; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: orchestrate-recover-message-findings.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$task_dir_arg" ] || [ -z "$dispatch_seq" ] || [ -z "$message_file" ] || \
   [ -z "$agent_name" ] || [ -z "$session_id" ]; then
  echo "ERROR: orchestrate-recover-message-findings.sh: --task-dir, --dispatch-seq, --message-file, --agent, and --session are all required." >&2
  usage >&2
  exit 2
fi

case "$task_dir_arg" in
  /*) TASK_DIR="$task_dir_arg" ;;
  *) TASK_DIR="${PROJECT_ROOT}/${task_dir_arg}" ;;
esac

notice_prefix="[orchestrate-recover-message-findings]"

# ─── Empty-message short-circuit ────────────────────────────────────────────────────────────────
# Whitespace-only counts as empty: `[ -s ]` alone would treat a file of pure newlines as non-empty.
if [ ! -f "$message_file" ] || [ -z "$(tr -d '[:space:]' < "$message_file" 2>/dev/null)" ]; then
  echo "${notice_prefix} message file '${message_file}' is missing or empty (whitespace-only) — nothing to recover." >&2
  jq -n -c '{recovered: false, reason: "EMPTY_MESSAGE"}'
  exit 0
fi

# ─── Naming: read the dispatch file's own Artifact Round section ──────────────────────────────
dispatch_file="${TASK_DIR}/.dispatch/${dispatch_seq}.md"
artifact_padded=""
output_dir=""
if [ -f "$dispatch_file" ]; then
  # Narrow, line-oriented parse of the "## Artifact Round" section this task's own dispatch files
  # already carry (see orchestrate-build-dispatch.sh's template) — never a prose read of anything
  # else in the file.
  artifact_padded=$(sed -n '/^## Artifact Round/,/^## /{/^- artifact_padded:/p;}' "$dispatch_file" \
    | head -1 | sed -E 's/^- artifact_padded:[[:space:]]*//' | tr -d '[:space:]')
  output_dir=$(sed -n '/^## Artifact Round/,/^## /{/^- output_dir:/p;}' "$dispatch_file" \
    | head -1 | sed -E 's/^- output_dir:[[:space:]]*//' | tr -d '[:space:]')
fi
if [ -z "$artifact_padded" ] || [ -z "$output_dir" ]; then
  echo "${notice_prefix} WARN: could not resolve artifact_padded/output_dir from '${dispatch_file}' (missing file or unparseable Artifact Round section) — falling back to 'reports/' and '01'." >&2
  [ -z "$artifact_padded" ] && artifact_padded="01"
  [ -z "$output_dir" ] && output_dir="${task_dir_arg%/}/reports"
fi

output_dir="${output_dir%/}"
case "$output_dir" in
  /*) resolved_output_dir="$output_dir" ;;
  *) resolved_output_dir="${PROJECT_ROOT}/${output_dir}" ;;
esac

# ─── Never-clobber target resolution ────────────────────────────────────────────────────────────
base_name="${artifact_padded}_recovered-agent-message"
target_path="${resolved_output_dir}/${base_name}.md"
suffix=1
while [ -s "$target_path" ]; do
  suffix=$((suffix + 1))
  target_path="${resolved_output_dir}/${base_name}-${suffix}.md"
done

if [ "$dry_run" = "true" ]; then
  echo "${notice_prefix} [dry-run] would write recovered findings to ${target_path} — no write performed." >&2
  jq -n -c --arg p "$target_path" '{recovered: false, reason: "DRY_RUN", would_write: $p}'
  exit 0
fi

mkdir -p "$resolved_output_dir"

timestamp="$(common_timestamp_iso)"
{
  echo "# Recovered Research Findings (from agent message)"
  echo ""
  echo "> **This is NOT a completed research report.** The dispatched agent"
  echo "> (\`${agent_name}\`) did not write its contract-mandated report file for this dispatch;"
  echo "> the text below is its final returned message, saved here verbatim so the findings are"
  echo "> not lost. It has not been reviewed, edited, or verified as a substitute for the missing"
  echo "> report."
  echo ">"
  echo "> - **Agent**: \`${agent_name}\`"
  echo "> - **Session**: \`${session_id}\`"
  echo "> - **Dispatch seq**: \`${dispatch_seq}\`"
  echo "> - **Recovered at**: ${timestamp}"
  echo ""
  echo "## Verbatim Agent Message"
  echo ""
  cat "$message_file"
} > "$target_path"

echo "${notice_prefix} Recovered message-borne findings written to ${target_path}." >&2

# Emit a repo-relative path when the resolved target lives under PROJECT_ROOT, matching the
# convention artifact-formats.md documents for artifacts[0].path elsewhere in this codebase.
case "$target_path" in
  "${PROJECT_ROOT}/"*) out_path="${target_path#"${PROJECT_ROOT}"/}" ;;
  *) out_path="$target_path" ;;
esac

jq -n -c --arg p "$out_path" '{recovered: true, path: $p}'
exit 0
