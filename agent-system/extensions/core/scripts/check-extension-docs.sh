#!/usr/bin/env bash
# check-extension-docs.sh
#
# Doc-lint script that iterates .claude/extensions/*/ and flags:
#   - missing README.md
#   - missing EXTENSION.md
#   - missing manifest.json
#   - manifest entries referencing nonexistent files (agents, skills, commands, rules, scripts,
#     context)
#   - rule files present in an extension's rules/ but absent from its provides.rules (reverse
#     direction: an unregistered rule never deploys and never reaches consuming repos)
#   - dangling .claude/context/contracts/*.md references in deployed skills/agents/rules that do
#     not resolve to an existing file in this project (project-wide, not per-extension)
#   - deployed .claude/scripts/<name> content drift from its extension-source counterpart, for
#     each manifest.provides.scripts entry where both copies exist (never-deployed extension-only
#     scripts are skipped, not failed)
#   - deployed .claude/rules/<name> content drift from its extension-source counterpart, for
#     each manifest.provides.rules entry where both copies exist (never-deployed extension-only
#     rules are skipped, not failed)
#   - README.md older than manifest.json (potential drift)
#   - commands listed in manifest but not mentioned in README.md
#   - deployed files under .claude/{agents,commands,context,scripts}/ that trace to ZERO
#     manifest.provides.<category> declaration in any extension ("every deployed file has a
#     source" gate; project-wide, not per-extension; severity controlled by ORPHAN_GATE_MODE)
#   - broken deployed symlinks under .claude/{agents,commands,skills}/ (install-extension.sh's
#     parallel symlink-deploy mechanism; distinct from the orphan checks above -- a dangling
#     symlink DOES have a declared source, its target path is simply wrong)
#   - CORE-extension (routing_exempt: true) deploy-drift/completeness ADVISORY lane: never-
#     deployed provides.scripts/provides.hooks entries, and root-files/settings.json hook
#     registrations missing from (or duplicated in) the deployed .claude/settings.json. This is
#     an ADVISORY lane, not a FAIL lane, by design -- see check_core_deploy_advisory's comment
#     for the rationale (a hard FAIL here would brick this gate for every caller until a user
#     performs the manual <leader>al regeneration this check exists to make visible).
#   - per-extension source `index-entries.json` `line_count` accuracy against `wc -l` of the
#     entry's own source file, INCLUDING unloaded extensions (source-level, not deployed-index-
#     level -- see generate-context-line-counts.sh, the companion regenerator; severity
#     controlled by INDEX_TRUTH_GATE_MODE)
#   - deployed `.claude/context/**/*.md` files with no entry in `.claude/context/index.json`
#     (project-wide, not per-extension; severity controlled by INDEX_TRUTH_GATE_MODE)
#   - per-extension source `index-entries.json` schema conformance against
#     context/index.schema.json's real field set: required keys present, forbidden keys
#     (description, tags, non-agents/commands/task_types/always load_when keys) absent, domain
#     value in the enum (source-level, per entry; severity controlled by
#     SCHEMA_CONFORMANCE_GATE_MODE)
#   - EXTENSION.md exceeding the 60-line limit from extension-slim-standard.md (severity
#     controlled by SCHEMA_CONFORMANCE_GATE_MODE)
#   - a shape-(a) claudemd merge source (manifest merge_targets.claudemd.source other than
#     "EXTENSION.md", e.g. core/literature's merge-sources/claudemd.md) exceeding its
#     per-extension byte ceiling declared in context/config/claudemd-size-budget.json (severity
#     controlled by SCHEMA_CONFORMANCE_GATE_MODE)
#
# Rule letter index (checks named "Rule X" in function comments below, in first-introduced
# order; unlettered checks are unnamed/structural and are not part of this index):
#   A - check_undeclared_skills            : skill dir on disk not in provides.skills
#   B - check_routing_consistency          : routing/routing_hard target not resolvable anywhere
#   C - check_routing_consistency          : routing/routing_hard target resolvable but not deployed
#   D - check_deployed_skill_agents        : deployed skill's subagent_type not in .claude/agents/
#   E - check_referenced_scripts_declared  : script referenced in docs but not in provides.scripts
#   F - check_deployed_script_drift        : deployed script content drift from extension source
#   G - check_dangling_contract_references : dangling .claude/context/contracts/*.md reference
#   H - check_undeclared_rules             : rule file on disk not in provides.rules
#   I - check_deployed_rule_drift          : deployed rule content drift from extension source
#   J - check_flat_category_orphans(agents)   : deployed agent with no provides.agents source
#   K - check_flat_category_orphans(commands) : deployed command with no provides.commands source
#   L - check_context_orphans              : deployed context file with no provides.context source
#   M - check_flat_category_orphans(scripts)  : deployed script with no provides.scripts source
#   N - check_broken_deployed_symlinks     : dangling install-extension.sh-created symlink
#   O - check_core_deploy_advisory         : core script/hook never deployed (ADVISORY, not FAIL)
#   P - check_settings_hook_registration_completeness : settings.json hook registration gap/dup
#       (ADVISORY, not FAIL; sub-check of O, core extension only)
#   Q - check_undeclared_scripts            : script file on disk not in provides.scripts
#   R - check_line_count_accuracy          : source index-entries.json line_count wrong/null/missing
#   S - check_deployed_index_orphans       : deployed context/*.md file with no index.json entry
#   T - check_index_entries_schema         : source index-entries.json entry violates index.schema.json's field set
#   U - check_extension_md_length          : EXTENSION.md exceeds the 60-line limit
#   V - check_claudemd_size_budget         : shape-(a) claudemd merge source exceeds its configured byte ceiling
#
# Exit codes:
#   0 - all extensions pass (Core Deploy-Drift Advisories, if any, do NOT affect this)
#   1 - one or more extensions have failures (or STRICT_CORE_DEPLOY=1 promoted an advisory)
#
# Usage:
#   bash .claude/scripts/check-extension-docs.sh
#   bash .claude/scripts/check-extension-docs.sh --quiet   (suppress info output; Core
#                                                            Deploy-Drift Advisories still print --
#                                                            see check_core_deploy_advisory)
#   STRICT_CORE_DEPLOY=1 bash .claude/scripts/check-extension-docs.sh
#       (promotes Core Deploy-Drift Advisories to real fail()-driven non-zero exits; intended for
#       a post-regeneration verification run, NOT the default/ordinary invocation)

set -uo pipefail

QUIET=0
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

# NOTE: the auto-detect below assumes BASH_SOURCE is deployed at .claude/scripts/<name> or
# .opencode/scripts/<name> (two directories under REPO_ROOT); it is valid only in a deploy tree.
# deploy-root-guard.sh now enforces this structurally on the computed-default path. Verification
# and any deliberate source-store invocation MUST pass an explicit REPO_ROOT=$(pwd) override,
# which intentionally bypasses the guard below -- the guard fires only when REPO_ROOT is unset.
[[ -n "${REPO_ROOT:-}" ]] || . "$(dirname "${BASH_SOURCE[0]}")/deploy-root-guard.sh" || exit 1
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EXT_DIR="${EXT_DIR:-$REPO_ROOT/agent-system/extensions}"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "ERROR: $EXT_DIR does not exist" >&2
  exit 1
fi

FAILURES=0
declare -A EXTENSION_STATUS

# Core Deploy-Drift Advisory lane (Rules O/P) -- see check_core_deploy_advisory for the
# FAIL-vs-ADVISORY rationale. Counted and reported SEPARATELY from FAILURES so ordinary
# invocations (including a concurrent sibling session's doc-lint gate run) keep their prior
# pass/fail verdict unchanged while the drift becomes impossible to miss.
DEPLOY_DRIFT_ADVISORIES=0
DEPLOY_DRIFT_ADVISORY_LINES=()
STRICT_CORE_DEPLOY="${STRICT_CORE_DEPLOY:-0}"

info() { [[ $QUIET -eq 0 ]] && echo "  $*"; }
fail() {
  echo "  FAIL: $*"
  FAILURES=$((FAILURES + 1))
  EXTENSION_STATUS["$CURRENT_EXT"]="FAIL"
}
# advisory(): the ADVISORY counterpart to fail(). Always printed (deliberately ignores --quiet --
# the whole point of this lane is that this class of issue must never again be silent), counted
# in DEPLOY_DRIFT_ADVISORIES (not FAILURES), and collected for the dedicated summary section.
# Never affects EXTENSION_STATUS or the exit code unless STRICT_CORE_DEPLOY=1.
advisory() {
  local msg="$*"
  echo "  ADVISORY: $msg"
  DEPLOY_DRIFT_ADVISORIES=$((DEPLOY_DRIFT_ADVISORIES + 1))
  DEPLOY_DRIFT_ADVISORY_LINES+=("$msg")
  if [[ "$STRICT_CORE_DEPLOY" == "1" ]]; then
    fail "$msg"
  fi
}

check_file() {
  local f="$1"
  local label="$2"
  if [[ ! -f "$f" ]]; then
    fail "$label missing ($f)"
    return 1
  fi
  if [[ ! -s "$f" ]]; then
    fail "$label is empty ($f)"
    return 1
  fi
  return 0
}

check_manifest_entries() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # agents (file references)
  local agents
  agents=$(jq -r '.provides.agents[]? // empty' "$manifest" 2>/dev/null)
  for a in $agents; do
    if [[ ! -f "$ext_path/agents/$a" ]]; then
      fail "manifest agent entry missing on disk: agents/$a"
    fi
  done

  # skills (directory references with SKILL.md)
  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  for s in $skills; do
    if [[ ! -f "$ext_path/skills/$s/SKILL.md" ]]; then
      fail "manifest skill entry missing on disk: skills/$s/SKILL.md"
    fi
  done

  # commands (file references)
  local cmds
  cmds=$(jq -r '.provides.commands[]? // empty' "$manifest" 2>/dev/null)
  for c in $cmds; do
    if [[ ! -f "$ext_path/commands/$c" ]]; then
      fail "manifest command entry missing on disk: commands/$c"
    fi
  done

  # rules
  local rules
  rules=$(jq -r '.provides.rules[]? // empty' "$manifest" 2>/dev/null)
  for r in $rules; do
    if [[ ! -f "$ext_path/rules/$r" ]]; then
      fail "manifest rule entry missing on disk: rules/$r"
    fi
  done

  # scripts
  local scripts
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  for s in $scripts; do
    if [[ ! -f "$ext_path/scripts/$s" ]]; then
      fail "manifest script entry missing on disk: scripts/$s"
    fi
  done

  # context (file OR directory references, e.g. "README.md" or "contracts")
  #
  # Mirrors the agents/skills/commands/rules/scripts pattern above for the one manifest.provides
  # category previously left unchecked: context. A declared provides.context entry must exist on
  # disk under <ext_path>/context/<entry>; otherwise the extension's context never propagates
  # through the manifest-driven descriptor copier (loader.lua's M.copy_category, category
  # "context"), and downstream repos silently never receive it. Confirmed live in cslib's stale
  # `lean` extension copy.
  local context_entries
  context_entries=$(jq -r '.provides.context[]? // empty' "$manifest" 2>/dev/null)
  local ce
  for ce in $context_entries; do
    if [[ ! -e "$ext_path/context/$ce" ]]; then
      fail "manifest provides.context entry missing on disk: context/$ce"
    fi
  done
}

# Rule F: Deployed-vs-source content drift for manifest.provides.scripts entries.
#
# The manifest-driven descriptor copier (loader.lua's M.copy_category, category "scripts") uses
# line-array read/write semantics with no path substitution or templating, so a deployed script's
# content should always match its extension-source counterpart. If a script is later hotfixed
# directly in the deployed .claude/scripts/ copy (instead of the extension source), that fix
# silently regresses on the next sync. This check fails when a manifest.provides.scripts entry's
# deployed copy differs in content from its extension-source copy.
#
# CRITICAL: only compare when BOTH copies exist. Several extension-only scripts (e.g. the
# opposite-direction never-deployed zotero-*/cite-extract.sh/test-lit-pipeline.sh scripts) are
# intentionally absent from .claude/scripts/ -- an absent deployed copy is NOT drift and must be
# skipped (with an optional info note), never a FAIL.
check_deployed_script_drift() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local scripts
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  local s deployed source
  for s in $scripts; do
    deployed="$REPO_ROOT/.claude/scripts/$s"
    source="$ext_path/scripts/$s"

    if [[ ! -f "$deployed" ]]; then
      info "script not deployed, skipping drift check: $s"
      continue
    fi
    if [[ ! -f "$source" ]]; then
      # Already reported by check_manifest_entries; do not double-report here.
      continue
    fi

    if ! cmp -s "$deployed" "$source"; then
      fail "deployed script content drift (deployed != extension source): scripts/$s"
    fi
  done
}

# Rule I: Deployed-vs-source content drift for manifest.provides.rules entries.
#
# Mirrors check_deployed_script_drift (Rule F) for the rules category. Rules deploy by
# byte-for-byte copy from <extension>/rules/<name> to .claude/rules/<name> via the same sync
# mechanism as scripts. If a rule is later hotfixed directly in the deployed .claude/rules/
# copy (instead of the extension source), that fix silently regresses on the next sync.
#
# CRITICAL: only compare when BOTH copies exist. An extension's rules are not deployed in
# every consuming repo -- an absent deployed copy is NOT drift and must be skipped (with an
# info note), never a FAIL.
check_deployed_rule_drift() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local rules
  rules=$(jq -r '.provides.rules[]? // empty' "$manifest" 2>/dev/null)
  local r deployed source
  for r in $rules; do
    deployed="$REPO_ROOT/.claude/rules/$r"
    source="$ext_path/rules/$r"

    if [[ ! -f "$deployed" ]]; then
      info "rule not deployed, skipping drift check: $r"
      continue
    fi
    if [[ ! -f "$source" ]]; then
      # Already reported by check_manifest_entries; do not double-report here.
      continue
    fi

    if ! cmp -s "$deployed" "$source"; then
      fail "deployed rule content drift (deployed != extension source): rules/$r"
    fi
  done
}

# Rule P: root-files/settings.json hook-registration completeness (core extension only).
#
# Sub-check of Rule O (check_core_deploy_advisory), factored out for readability. Compares the
# hook-script basenames registered under each event in the extension SOURCE's
# root-files/settings.json against the same event in the DEPLOYED .claude/settings.json, and
# separately flags any duplicate registration within a single deployed event's hook-script
# basenames (e.g. the known duplicate claude-stop-notify.sh Stop-matcher artifact). Both classes
# are ADVISORY (see check_core_deploy_advisory) -- never a fail() unless STRICT_CORE_DEPLOY=1.
check_settings_hook_registration_completeness() {
  local ext_path="$1"
  local source_settings="$ext_path/root-files/settings.json"
  local deployed_settings="$REPO_ROOT/.claude/settings.json"

  [[ -f "$source_settings" ]] || return 0
  jq empty "$source_settings" 2>/dev/null || return 0

  if [[ ! -f "$deployed_settings" ]]; then
    advisory "deployed .claude/settings.json is missing entirely -- no hook registrations are live (regenerate via <leader>al 'Reload All', or bash .claude/scripts/deploy-headless.sh)"
    return 0
  fi
  jq empty "$deployed_settings" 2>/dev/null || return 0

  local events ev src_scripts dep_scripts s dup
  events=$(jq -r '.hooks // {} | keys[]' "$source_settings" 2>/dev/null)
  for ev in $events; do
    src_scripts=$(jq -r --arg e "$ev" '.hooks[$e][]?.hooks[]?.command // empty' "$source_settings" 2>/dev/null \
      | grep -oE '[A-Za-z0-9_.-]+\.sh' | sort -u)
    dep_scripts=$(jq -r --arg e "$ev" '.hooks[$e][]?.hooks[]?.command // empty' "$deployed_settings" 2>/dev/null \
      | grep -oE '[A-Za-z0-9_.-]+\.sh' | sort -u)

    for s in $src_scripts; do
      if ! grep -qxF "$s" <<< "$dep_scripts"; then
        advisory "settings.json hook registration missing for event '$ev': $s (source declares it, deployed .claude/settings.json does not -- regenerate via <leader>al 'Reload All', or bash .claude/scripts/deploy-headless.sh)"
      fi
    done

    dup=$(jq -r --arg e "$ev" '.hooks[$e][]?.hooks[]?.command // empty' "$deployed_settings" 2>/dev/null \
      | grep -oE '[A-Za-z0-9_.-]+\.sh' | sort | uniq -d)
    for s in $dup; do
      advisory "settings.json duplicate hook registration for event '$ev': $s appears more than once in the deployed .claude/settings.json Stop-matcher (or equivalent) array (add-only merge cannot remove this -- manual cleanup required)"
    done
  done

  check_settings_merge_source_coverage "$ext_path"
}

# Sub-check of Rule O. Catches the specific, previously-unnoticed failure mode that let hook
# registrations sit undeployed indefinitely while every other signal looked healthy.
#
# root-files/settings.json is INSTALL-ONCE: the root_files category's descriptor-driven copier
# (loader.lua's M.copy_category, gated by CATEGORY_DESCRIPTORS.root_files.install_once) skips it
# whenever the target already exists, so anything added only there can never reach an
# already-initialized repo, no matter how many regenerations run. The file that DOES reach
# existing repos is the merge target declared in manifest.json (merge_targets.settings.source,
# i.e. merge-sources/settings-hooks.json).
#
# The sibling check above compares source-vs-deployed and would report such a hook as "missing
# from the deployed settings.json" with a remediation of "regenerate" -- advice that cannot work
# for an install-once addition. This check names the real remedy instead.
#
# THREE conditions must ALL hold before reporting. The third is what keeps this check useful
# rather than noisy: a hook may legitimately live only in root-files/settings.json if it predates
# the repos that consume it and is therefore already present in their deployed trees. Reporting
# those would emit ~9 permanent, unfixable advisories on a healthy repo and train readers to
# ignore the whole lane. Only a hook that is absent from the deployed tree AND has no merge-source
# route is genuinely stuck -- that is the defect class worth surfacing.
check_settings_merge_source_coverage() {
  local ext_path="$1"
  local source_settings="$ext_path/root-files/settings.json"
  local manifest="$ext_path/manifest.json"
  local deployed_settings="$REPO_ROOT/.claude/settings.json"

  [[ -f "$source_settings" ]] || return 0
  [[ -f "$manifest" ]] || return 0
  jq empty "$source_settings" 2>/dev/null || return 0

  local merge_rel merge_source
  merge_rel=$(jq -r '.merge_targets.settings.source // empty' "$manifest" 2>/dev/null)
  [[ -n "$merge_rel" ]] || return 0
  merge_source="$ext_path/$merge_rel"

  if [[ ! -f "$merge_source" ]]; then
    advisory "manifest declares merge_targets.settings.source=$merge_rel but that file does not exist -- no settings addition can reach an already-initialized repo"
    return 0
  fi
  jq empty "$merge_source" 2>/dev/null || return 0

  local root_scripts merge_scripts deployed_scripts s
  root_scripts=$(jq -r '.hooks // {} | to_entries[] | .value[]?.hooks[]?.command // empty' "$source_settings" 2>/dev/null \
    | grep -oE '[A-Za-z0-9_.-]+\.sh' | sort -u)
  merge_scripts=$(jq -r '.hooks // {} | to_entries[] | .value[]?.hooks[]?.command // empty' "$merge_source" 2>/dev/null \
    | grep -oE '[A-Za-z0-9_.-]+\.sh' | sort -u)

  # Absent deployed settings.json => treat nothing as already-live, so every uncovered hook is
  # genuinely stuck and gets reported. Fail-loud, not fail-silent.
  if [[ -f "$deployed_settings" ]] && jq empty "$deployed_settings" 2>/dev/null; then
    deployed_scripts=$(jq -r '.hooks // {} | to_entries[] | .value[]?.hooks[]?.command // empty' "$deployed_settings" 2>/dev/null \
      | grep -oE '[A-Za-z0-9_.-]+\.sh' | sort -u)
  else
    deployed_scripts=""
  fi

  for s in $root_scripts; do
    # Condition 2: no merge-source route.
    grep -qxF "$s" <<< "$merge_scripts" && continue
    # Condition 3: not already live in the deployed tree. A hook that predates the consuming
    # repos is already registered there and needs no merge route -- skip it.
    grep -qxF "$s" <<< "$deployed_scripts" && continue
    advisory "hook '$s' is registered ONLY in root-files/settings.json (install-once), has no entry in $merge_rel, and is NOT present in the deployed .claude/settings.json -- it can never arrive; add it to $merge_rel as its own single-command matcher object"
  done
}

# Rule O: core-extension (routing_exempt: true) deploy-drift/completeness ADVISORY lane (scope 6
# of the passive-signal-capture work). Extends the existing "not deployed -> info-skip" behavior
# of check_deployed_script_drift/check_deployed_rule_drift for the core extension specifically:
# a never-deployed provides.scripts or provides.hooks entry is baseline infrastructure present in
# every .claude/ tree by construction, so its absence is a meaningfully different (and worse)
# condition than "deployed but drifted" -- yet the prior info-skip line was easy to lose (and
# fully suppressed under --quiet), silently inverting that severity ordering.
#
# GUARDRAIL (binding, do not remove without re-reading the originating plan): core deploy drift
# is resolved by regenerating the deploy tree -- either interactively via <leader>al "Reload All"
# (or "Regenerate" for a full wipe+rebuild) or headlessly via scripts/deploy-headless.sh. (An
# earlier revision of this comment asserted there was no headless path; that was wrong. See
# context/patterns/regeneration-is-manual-only.md.) Regeneration is still an ACTION SOMEONE MUST
# TAKE rather than something this gate can assume has happened, and one advisory class -- a hook
# registered only in the install-once root-files/settings.json -- is not fixed by regenerating at
# all. This check therefore NEVER calls fail() by default for a core
# "not deployed" condition: doing so would hard-fail this doc-lint gate for EVERY caller until
# the user regenerates, including concurrent sibling sessions validating unrelated manifest
# changes via this same script, and every commit thereafter. It reports via advisory() instead --
# always printed (ignoring --quiet), counted separately from FAILURES, and summarized in its own
# section -- so the divergence is impossible to miss without ever blocking ordinary invocations.
# Set STRICT_CORE_DEPLOY=1 to promote these same advisories to real fail()-driven non-zero exits
# (e.g. a post-regeneration verification run asserting zero remaining core drift).
check_core_deploy_advisory() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local routing_exempt
  routing_exempt=$(jq -r '.routing_exempt // false' "$manifest" 2>/dev/null)
  [[ "$routing_exempt" == "true" ]] || return 0

  local scripts s deployed
  scripts=$(jq -r '.provides.scripts[]? // empty' "$manifest" 2>/dev/null)
  for s in $scripts; do
    deployed="$REPO_ROOT/.claude/scripts/$s"
    [[ -f "$deployed" ]] || advisory "core script never deployed: scripts/$s (regenerate via <leader>al 'Reload All', or bash .claude/scripts/deploy-headless.sh)"
  done

  local hooks h
  hooks=$(jq -r '.provides.hooks[]? // empty' "$manifest" 2>/dev/null)
  for h in $hooks; do
    deployed="$REPO_ROOT/.claude/hooks/$h"
    [[ -f "$deployed" ]] || advisory "core hook never deployed: hooks/$h (regenerate via <leader>al 'Reload All', or bash .claude/scripts/deploy-headless.sh)"
  done

  check_settings_hook_registration_completeness "$ext_path"
}

check_routing_block() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # Skip routing check if extension declares routing_exempt: true
  local routing_exempt
  routing_exempt=$(jq -r '.routing_exempt // false' "$manifest" 2>/dev/null)
  if [[ "$routing_exempt" == "true" ]]; then
    return 0
  fi

  # If manifest declares non-empty provides.skills, verify routing block exists
  local skill_count
  skill_count=$(jq -r '.provides.skills | length' "$manifest" 2>/dev/null)
  if [[ "$skill_count" -gt 0 ]]; then
    local has_routing
    has_routing=$(jq -r 'has("routing")' "$manifest" 2>/dev/null)
    if [[ "$has_routing" == "false" ]]; then
      fail "manifest declares $skill_count skill(s) but has no routing block"
    fi
  fi
}

# Rule A: Undeclared skill dirs in extension source not in provides.skills
check_undeclared_skills() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/skills" ]] || return 0

  for skill_dir in "$ext_path/skills/"/skill-*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    if ! jq -e --arg s "$skill_name" '.provides.skills[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>&1; then
      fail "skill dir on disk NOT in provides.skills: $skill_name"
    fi
  done
}

# Rule H: Undeclared rule files in extension source not in provides.rules.
#
# Reverse direction of check_manifest_entries' rules loop, which only validates that declared
# entries exist on disk. This catches the opposite bug: a rule file that exists on disk but was
# never added to provides.rules, so the manifest-driven descriptor copier (loader.lua's
# M.copy_category, category "rules") never deploys it and consuming repos silently never receive
# it. Mirrors check_undeclared_skills (Rule A) for the rules category.
#
# Motivating case: core/rules/pr-prohibition.md existed on disk, was absent from core's
# provides.rules, and was correspondingly absent from every consuming repo's .claude/rules/ --
# meaning the rule barring agents from creating PRs and pushing to remotes never propagated
# downstream. Because it was unregistered, the loader also never overwrote its deployed copy, so
# the live version silently accumulated 35 lines of content absent from the extension source.
check_undeclared_rules() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/rules" ]] || return 0

  local rule_file rule_name
  for rule_file in "$ext_path/rules/"*.md; do
    [[ -f "$rule_file" ]] || continue
    rule_name=$(basename "$rule_file")
    if ! jq -e --arg r "$rule_name" '.provides.rules[]? | select(. == $r)' \
        "$manifest" > /dev/null 2>&1; then
      fail "rule file on disk NOT in provides.rules: rules/$rule_name"
    fi
  done
}

# Rule Q: Undeclared script files in extension source not in provides.scripts.
#
# Reverse direction of check_manifest_entries' scripts loop (declared-but-missing-on-disk) and
# distinct from both Rule E (check_referenced_scripts_declared, reference-driven, .sh/.sql-only)
# and Rule M (check_flat_category_orphans "scripts", deployed-file-driven -- structurally blind
# to a file that was never deployed in the first place because it was never declared). This
# check is disk-driven: it walks an extension's own scripts/ tree and flags any file present on
# disk that provides.scripts does not name, independent of whether anything references it or
# whether it has ever been deployed. A file that fails only this check never deploys at all.
#
# Matches by FULL RELATIVE PATH under scripts/, not basename, because provides.scripts entries
# legitimately carry a path prefix (e.g. literature's "tests/generate-test-fixtures.py"). Covers
# ALL regular file types -- provides.scripts already holds .sh, .py, .sql, and dotfile entries
# (see literature's ".zotero-title-sim.py") -- so this uses `git ls-files`, not `find` and not a
# `*.sh` glob. Enumerating from the git index (mirroring `_git_deployed_files()`'s own rationale
# above) naturally excludes gitignored runtime artifacts -- `__pycache__/`, virtualenvs, build
# caches -- without extra path filtering, since they were never tracked. `deprecated/` is exempt
# (superseded scripts intentionally left undeclared and undeployed); `tests/` is NOT exempt
# (literature declares its tests/*.py and tests/*.sh entries deliberately).
check_undeclared_scripts() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  [[ -d "$ext_path/scripts" ]] || return 0

  # Trailing-slash normalization: the caller's per-extension loop is `for ext_path in
  # "$EXT_DIR"/*/`, so ext_path carries a trailing slash. Left unstripped, the prefix-strip
  # below would build a double-slash prefix ("ext//scripts/") that never matches what
  # `git ls-files` returns, degrading this check to reporting every script in every extension
  # as undeclared.
  local ext_path_norm="${ext_path%/}"

  # `git ls-files` (run via `-C "$REPO_ROOT"`) always returns REPO_ROOT-relative paths,
  # regardless of whether the pathspec passed to it is absolute or relative -- a different
  # output shape than `find` returned (absolute, matching the pathspec's own form). The
  # prefix-strip below must therefore be re-derived against ext_path_norm's REPO_ROOT-relative
  # form, not reused unchanged from the absolute-path form.
  local ext_rel="${ext_path_norm#"$REPO_ROOT"/}"

  local script_file rel_path
  while IFS= read -r script_file; do
    [[ -f "$REPO_ROOT/$script_file" ]] || continue
    rel_path="${script_file#"$ext_rel"/scripts/}"

    case "$rel_path" in
      deprecated/*) continue ;;
    esac

    if ! jq -e --arg s "$rel_path" '.provides.scripts[]? | select(. == $s)' \
        "$manifest" > /dev/null 2>&1; then
      fail "script file on disk NOT in provides.scripts: scripts/$rel_path"
    fi
  done < <(git -C "$REPO_ROOT" ls-files "$ext_path_norm/scripts" | sort)
}

# INDEX_TRUTH_GATE_MODE controls severity for Rules R and S (the two checks this block
# introduces) -- a sibling to ORPHAN_GATE_MODE above, not an overload of it. These are
# materially different checks with their own remediation timeline: ORPHAN_GATE_MODE governs the
# "every deployed file has a manifest.provides source" family (Rules J/K/L/M/N), while
# INDEX_TRUTH_GATE_MODE governs the newer "the context index tells the truth" family (source
# line_count accuracy and deployed-index-orphan coverage) added once generate-context-line-counts.sh
# and the 14 previously-orphaned entries landed. Defaults to "hard" now that source-store
# remediation has already landed and a clean run was confirmed -- override to "advisory" only
# for temporary local debugging, never in committed config.
INDEX_TRUTH_GATE_MODE="${INDEX_TRUTH_GATE_MODE:-hard}"

index_truth_report() {
  local msg="$1"
  if [[ "$INDEX_TRUTH_GATE_MODE" == "hard" ]]; then
    fail "$msg"
  else
    info "ADVISORY (not yet blocking): $msg"
  fi
}

# Rule R: source index-entries.json line_count accuracy, per extension.
#
# Companion gate to generate-context-line-counts.sh: where that script is a manual/CI-invoked
# regenerator, this check is the automated tripwire that fires on every verify-deploy.sh run.
# Deliberately SOURCE-level, not deployed-index-level: it walks
# $EXT_DIR/<ext>/index-entries.json directly against $EXT_DIR/<ext>/context/<path>, so it catches
# drift in an extension that is not even currently loaded (the 94-null class documented in
# generate-context-line-counts.sh's header) -- something validate-context-index.sh, which only
# ever sees the deployed .claude/context/index.json of loaded extensions, structurally cannot
# see. Fails on a numeric mismatch, a null/absent line_count key, and a missing source file
# alike (matching the regenerator's own three-way classification).
check_line_count_accuracy() {
  local ext_path="$1"
  local index_file="$ext_path/index-entries.json"
  local context_dir="${ext_path%/}/context"

  [[ -f "$index_file" ]] || return 0
  jq -e '.entries' "$index_file" > /dev/null 2>&1 || return 0

  local entry_count path declared has_key full_path actual i
  entry_count=$(jq '.entries | length' "$index_file" 2>/dev/null) || return 0

  for ((i = 0; i < entry_count; i++)); do
    path=$(jq -r ".entries[$i].path" "$index_file")
    has_key=$(jq -r ".entries[$i] | has(\"line_count\")" "$index_file")
    declared=$(jq -r ".entries[$i].line_count" "$index_file")
    full_path="$context_dir/$path"

    if [[ ! -f "$full_path" ]]; then
      index_truth_report "Rule R: index-entries.json entry '$path' has no source file at context/$path"
      continue
    fi

    if [[ "$has_key" != "true" ]]; then
      index_truth_report "Rule R: index-entries.json entry '$path' is missing the line_count key -- remedy: bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write (deploy-headless.sh also runs this automatically before every deploy)"
      continue
    fi

    actual=$(wc -l < "$full_path")
    actual=${actual// /}
    if [[ "$declared" != "$actual" ]]; then
      index_truth_report "Rule R: index-entries.json entry '$path' line_count mismatch: declared $declared, actual $actual -- remedy: bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write (deploy-headless.sh also runs this automatically before every deploy)"
    fi
  done
}

# SCHEMA_CONFORMANCE_GATE_MODE controls severity for Rules T and U (the two checks this block
# introduces) -- a SIBLING to INDEX_TRUTH_GATE_MODE above, not an overload of it. Defaults to
# "hard" now that both follow-on remediation efforts -- the bulk index-entries.json schema
# migration (Rule T) and the EXTENSION.md slim-down (Rule U) -- have landed and a hard-mode dry
# run confirmed zero Rule T and zero Rule U findings across all 19 extensions (mirrors the
# ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE promotion precedent) -- override to "advisory" only
# for temporary local debugging, never in committed config.
SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-hard}"

schema_conformance_report() {
  local msg="$1"
  if [[ "$SCHEMA_CONFORMANCE_GATE_MODE" == "hard" ]]; then
    fail "$msg"
  else
    info "ADVISORY (not yet blocking): $msg"
  fi
}

# Rule T: source index-entries.json schema conformance, per extension, per entry.
#
# Hand-written jq conformance check against context/index.schema.json's real shape --
# deliberately not a new ajv/jsonschema dependency, following check_line_count_accuracy's own
# idiom. Flags: (a) any of path/domain/subdomain/summary/line_count missing; (b) a present
# 'description' or 'tags' key (both are schema-forbidden -- 'description' duplicates 'summary',
# 'tags' is a naming mismatch for 'keywords'); (c) a load_when key outside
# agents/commands/task_types/always (this deliberately also flags a present-but-empty
# 'languages'/'skills' array, since the goal is zero declarations, not merely zero non-empty
# ones); (d) a 'domain' value outside core/project/system.
check_index_entries_schema() {
  local ext_path="$1"
  local index_file="$ext_path/index-entries.json"

  [[ -f "$index_file" ]] || return 0
  jq -e '.entries' "$index_file" > /dev/null 2>&1 || return 0

  local entry_count i path domain has_subdomain has_summary has_line_count
  local has_description has_tags load_when_keys extra_keys key
  entry_count=$(jq '.entries | length' "$index_file" 2>/dev/null) || return 0

  for ((i = 0; i < entry_count; i++)); do
    path=$(jq -r ".entries[$i].path" "$index_file")
    domain=$(jq -r ".entries[$i].domain // \"\"" "$index_file")

    if [[ "$(jq -r ".entries[$i] | has(\"path\")" "$index_file")" != "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry [$i] is missing the path key"
    fi
    if [[ "$(jq -r ".entries[$i] | has(\"domain\")" "$index_file")" != "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' is missing the domain key"
    fi
    if [[ "$(jq -r ".entries[$i] | has(\"subdomain\")" "$index_file")" != "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' is missing the subdomain key"
    fi
    if [[ "$(jq -r ".entries[$i] | has(\"summary\")" "$index_file")" != "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' is missing the summary key"
    fi
    if [[ "$(jq -r ".entries[$i] | has(\"line_count\")" "$index_file")" != "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' is missing the line_count key"
    fi

    has_description=$(jq -r ".entries[$i] | has(\"description\")" "$index_file")
    if [[ "$has_description" == "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' has forbidden key 'description' (fold its detail into 'summary')"
    fi
    has_tags=$(jq -r ".entries[$i] | has(\"tags\")" "$index_file")
    if [[ "$has_tags" == "true" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' has forbidden key 'tags' (use 'keywords' instead)"
    fi

    load_when_keys=$(jq -r ".entries[$i].load_when // {} | keys[]" "$index_file" 2>/dev/null)
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      case "$key" in
        agents|commands|task_types|always) ;;
        *)
          schema_conformance_report "Rule T: index-entries.json entry '$path' has forbidden load_when key '$key' (allowed: agents, commands, task_types, always)"
          ;;
      esac
    done <<< "$load_when_keys"

    if [[ -n "$domain" && "$domain" != "core" && "$domain" != "project" && "$domain" != "system" ]]; then
      schema_conformance_report "Rule T: index-entries.json entry '$path' has domain '$domain' outside the enum (core, project, system)"
    fi
  done
}

# claudemd_source_for(): resolves the manifest's declared claudemd merge source for an extension.
# Prints the value of .merge_targets.claudemd.source, or an empty string if the key is absent.
#
# RATIONALE (why the manifest is the authority, and why both core/EXTENSION.md and
# slidev/EXTENSION.md were DELETED rather than trimmed): generate_claudemd() (core's
# merge.lua) builds CLAUDE.md by reading, for each loaded extension, whatever file
# merge_targets.claudemd.source names -- NOT an unconditionally-assumed "EXTENSION.md". Before
# this helper existed, both the required-file check below and Rule U (check_extension_md_length)
# hardcoded the filename "EXTENSION.md", so an extension whose manifest declares a DIFFERENT
# claudemd source (core, which merges from merge-sources/claudemd.md) or NO claudemd source at
# all (slidev, a context-only extension with zero skills/commands) was still forced to carry an
# EXTENSION.md and have it length-checked -- a file no code path ever reads. That is "dead
# conformance" work: effort spent trimming a file that was never live. A live audit at
# implementation time confirmed core/EXTENSION.md and slidev/EXTENSION.md were each a 100%
# content subset of that extension's own README.md, with zero references to either file from
# generate_claudemd()'s actual merge path -- so both were deleted outright, and this helper makes
# the checker's required-file/length-check gate manifest-authoritative instead of
# filename-authoritative. See core/docs/reference/standards/extension-slim-standard.md's
# "Resource-Only / Non-EXTENSION.md-Source Extensions" note and
# core/docs/guides/creating-extensions.md's resource-only extension pattern for the general case
# this generalizes.
claudemd_source_for() {
  local ext_path="$1"
  jq -r '.merge_targets.claudemd.source // empty' "$ext_path/manifest.json" 2>/dev/null
}

# Rule U: EXTENSION.md length limit, per extension.
#
# extension-slim-standard.md's 60-line maximum for EXTENSION.md was, until this rule, unenforced
# prose. Reports (never silently skips) when the file exceeds 60 lines; a missing EXTENSION.md is
# already covered by check_file's own required-file FAIL and is not double-reported here.
#
# Manifest-authoritative (see claudemd_source_for's rationale comment above): only length-checks
# an EXTENSION.md that is actually this extension's declared claudemd merge source. A file that
# happens to exist on disk but is not the designated source (e.g. a stray leftover) is not
# length-checked -- narrower than a blanket "every EXTENSION.md on disk" scan, by design.
check_extension_md_length() {
  local ext_path="$1"
  local ext_md="$ext_path/EXTENSION.md"
  local actual

  [[ -f "$ext_md" ]] || return 0
  [[ "$(claudemd_source_for "$ext_path")" == "EXTENSION.md" ]] || return 0

  actual=$(wc -l < "$ext_md")
  actual=${actual// /}
  if (( actual > 60 )); then
    schema_conformance_report "Rule U: EXTENSION.md is $actual lines, exceeding the 60-line limit"
  fi
}

# Rule V: shape-(a) claudemd merge source byte ceiling, per extension.
#
# Regression-prevention lever for the eager-CLAUDE.md-surface cut: without an enforced ceiling,
# a shape-(a) merge source (manifest merge_targets.claudemd.source pointing at something OTHER
# than "EXTENSION.md" -- today core and literature's merge-sources/claudemd.md) can silently
# regrow past its measured post-cut size with no lint signal, the same class of drift Rule U
# already prevents for shape-(b) EXTENSION.md files.
#
# Manifest-authoritative (same claudemd_source_for helper as Rule U): only budget-checks a source
# that is genuinely this extension's declared claudemd merge source, and only when that source is
# shape-(a) (non-empty and not "EXTENSION.md") -- shape-(b) extensions are Rule U's domain, not
# this rule's.
#
# The budget config is read from the SOURCE STORE ($EXT_DIR/core/context/config/), not the
# deployed tree: EXT_DIR already resolves to agent-system/extensions when this script runs (see
# EXT_DIR's own definition above), so no deploy of the config file is required for this rule to
# see current ceilings -- see claudemd-size-budget.json's own header comment for the full
# rationale and the derivation formula for each named ceiling.
check_claudemd_size_budget() {
  local ext_path="$1"
  local ext_name
  ext_name=$(basename "$ext_path")

  local source_rel
  source_rel=$(claudemd_source_for "$ext_path")
  [[ -n "$source_rel" && "$source_rel" != "EXTENSION.md" ]] || return 0

  local source_abs="$ext_path/$source_rel"
  [[ -f "$source_abs" ]] || return 0

  local budget_file="$EXT_DIR/core/context/config/claudemd-size-budget.json"
  [[ -f "$budget_file" ]] || return 0
  jq empty "$budget_file" 2>/dev/null || return 0

  local ceiling
  ceiling=$(jq -r --arg n "$ext_name" '.extensions[$n].ceiling_bytes // .default_ceiling_bytes // empty' "$budget_file" 2>/dev/null)
  [[ -n "$ceiling" ]] || return 0

  local actual
  actual=$(wc -c < "$source_abs")
  actual=${actual// /}

  if (( actual > ceiling )); then
    schema_conformance_report "Rule V: shape-(a) claudemd merge source '$source_rel' is $actual B, exceeding its configured ceiling of $ceiling B (see context/config/claudemd-size-budget.json)"
  fi
}

# Rules B + C: Routing target consistency and deployment
#
# Policy rationale (restored after a later sync reverted it from the stale extension-source
# copy; this restores it in both copies):
#   Both routing and routing_hard share the same deployment-dimension severity rule:
#     - FAIL if the extension is installed but the target is not deployed
#     - WARN (info) if the extension is not installed (expected undeployed state)
#   routing_hard adds ONE stricter requirement beyond the deployment dimension:
#     1. Source-grounding: the target must exist in some extension's SOURCE provides.skills
#   This rule deliberately downgraded the uninstalled-extension case for routing_hard from
#   FAIL to WARN: command-route-skill.sh does not implement routing_hard dispatch at all (it
#   takes 3 positional args and never reads .routing_hard), so the "unconditional dispatch"
#   rationale that previously justified FAIL here is false -- an uninstalled extension with a
#   source-grounded but undeployed routing_hard target is the expected state, not a live
#   correctness bug. A later sync from the stale extension-source copy reverted this
#   downgrade; the policy above restores it in both copies.
#   Rule B (resolvability): any routing or routing_hard target that does not exist in any
#   extension's provides.skills AND is not deployed is a FAIL (manifest typo/stale entry).
check_routing_consistency() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # Determine if this extension is "installed":
  # installed = at least one of its source skills appears in .claude/skills/ OR
  #             at least one of its source agents appears in .claude/agents/
  local installed=0
  if [[ -d "$ext_path/skills" ]]; then
    local sdir
    for sdir in "$ext_path/skills/"/*/; do
      [[ -d "$sdir" ]] || continue
      local sn
      sn=$(basename "$sdir")
      if [[ -d "$REPO_ROOT/.claude/skills/$sn" || -L "$REPO_ROOT/.claude/skills/$sn" ]]; then
        installed=1
        break
      fi
    done
  fi
  if [[ $installed -eq 0 && -d "$ext_path/agents" ]]; then
    local af
    for af in "$ext_path/agents/"*.md; do
      [[ -f "$af" ]] || continue
      local an
      an=$(basename "$af")
      if [[ -f "$REPO_ROOT/.claude/agents/$an" ]]; then
        installed=1
        break
      fi
    done
  fi

  # Helper: check if a skill target is resolvable (in any extension's provides.skills
  # OR deployed under .claude/skills/)
  target_resolvable() {
    local target="$1"
    # Check deployed first (fast path for cross-extension core skills)
    if [[ -d "$REPO_ROOT/.claude/skills/$target" || -L "$REPO_ROOT/.claude/skills/$target" ]]; then
      return 0
    fi
    # Check all extension manifests for provides.skills
    local m
    for m in "$EXT_DIR"/*/manifest.json; do
      [[ -f "$m" ]] || continue
      if jq -e --arg s "$target" '.provides.skills[]? | select(. == $s)' \
          "$m" > /dev/null 2>&1; then
        return 0
      fi
    done
    return 1
  }

  # --- routing targets ---
  local routing_targets
  routing_targets=$(jq -r '.routing // {} | to_entries[] | .value | to_entries[] | .value' \
    "$manifest" 2>/dev/null)
  local t base_t
  for t in $routing_targets; do
    # Routing values may use colon notation (e.g., skill-grant:assemble) where the part
    # before the colon is the actual skill name and the colon suffix is a sub-operation mode.
    # Strip the suffix for skill-resolution purposes.
    base_t="${t%%:*}"
    if [[ ! -d "$REPO_ROOT/.claude/skills/$base_t" && ! -L "$REPO_ROOT/.claude/skills/$base_t" ]]; then
      # Rule B: target not resolvable to any provides.skills and not deployed
      if ! target_resolvable "$base_t"; then
        fail "routing target not resolvable (not in any provides.skills, not deployed): $t"
      elif [[ $installed -eq 1 ]]; then
        # Rule C (routing, installed): deployed dimension violation
        fail "routing target not deployed (extension is installed): $t"
      else
        # Rule C (routing, uninstalled): warn only
        info "WARN: routing target not deployed (extension not installed): $t"
      fi
    fi
  done

  # --- routing_hard targets ---
  local hard_targets
  hard_targets=$(jq -r '.routing_hard // {} | to_entries[] | .value | to_entries[] | .value' \
    "$manifest" 2>/dev/null)
  for t in $hard_targets; do
    # Strip colon sub-operation suffix for skill-resolution (same as routing above)
    base_t="${t%%:*}"
    if [[ ! -d "$REPO_ROOT/.claude/skills/$base_t" && ! -L "$REPO_ROOT/.claude/skills/$base_t" ]]; then
      # Rule B: target not resolvable to any provides.skills and not deployed
      if ! target_resolvable "$base_t"; then
        fail "routing_hard target not resolvable (not in any provides.skills, not deployed): $t"
      elif [[ $installed -eq 1 ]]; then
        # Rule C (routing_hard, installed): deployment violation
        fail "routing_hard target not deployed (extension is installed): $t"
      else
        # Rule C (routing_hard, uninstalled): warn only. command-route-skill.sh does not
        # implement routing_hard dispatch at all, so an uninstalled extension with a
        # source-grounded but undeployed routing_hard target is expected, not a live bug
        # (restored here after the same stale-source-copy regression noted above).
        info "WARN: routing_hard target declared but not deployed (extension not installed): $t"
      fi
    fi
  done
}

# Rule D: Deployed skills must reference agents that exist
check_deployed_skill_agents() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  local skills
  skills=$(jq -r '.provides.skills[]? // empty' "$manifest" 2>/dev/null)
  local s
  for s in $skills; do
    local deployed_skill="$REPO_ROOT/.claude/skills/$s/SKILL.md"
    [[ -f "$deployed_skill" ]] || continue  # not deployed, skip

    # Extract subagent_type from SKILL.md body
    local agent_name
    agent_name=$(grep -o 'subagent_type: "[^"]*"' "$deployed_skill" 2>/dev/null \
      | head -1 | cut -d'"' -f2)
    [[ -z "$agent_name" ]] && continue      # direct-execution skill, no agent
    [[ "$agent_name" == "fork" ]] && continue  # fork pattern, not a named agent file

    if [[ ! -f "$REPO_ROOT/.claude/agents/${agent_name}.md" ]]; then
      fail "deployed skill $s references agent $agent_name NOT in .claude/agents/"
    fi
  done
}

check_readme_vs_manifest() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"
  local readme="$ext_path/README.md"

  # Compare mtimes: warn if README older than manifest (possible drift)
  if [[ -f "$readme" && -f "$manifest" ]]; then
    local readme_mtime manifest_mtime
    readme_mtime=$(stat -c %Y "$readme" 2>/dev/null || stat -f %m "$readme")
    manifest_mtime=$(stat -c %Y "$manifest" 2>/dev/null || stat -f %m "$manifest")
    if [[ "$readme_mtime" -lt "$manifest_mtime" ]]; then
      info "WARN: README.md older than manifest.json (possible drift)"
    fi
  fi

  # Commands listed in manifest must be mentioned in README.md
  if [[ -f "$readme" ]]; then
    local cmds
    cmds=$(jq -r '.provides.commands[]? // empty' "$manifest" 2>/dev/null)
    for c in $cmds; do
      local cmd_name="${c%.md}"
      if ! grep -q "/$cmd_name" "$readme"; then
        fail "command /$cmd_name listed in manifest but not mentioned in README.md"
      fi
    done
  fi
}

# Rule E: Scripts referenced in an extension's docs/skills/agents but NOT declared in the
# extension's own provides.scripts (reverse direction of check_manifest_entries, which only
# validates that declared entries exist on disk -- this catches the opposite bug: a script that
# exists and is referenced but was never added to the manifest, so it never gets deployed to a
# consuming repo). See the literature-discover.sh script-packaging bug (literature-discover.sh
# and 6 siblings were referenced but undeclared) for the motivating case.
check_referenced_scripts_declared() {
  local ext_path="$1"
  local manifest="$ext_path/manifest.json"

  # 1. Extract .sh/.sql filename tokens referenced in this extension's docs/skills/agents.
  # Strip http(s) URLs first so remote install-script references (e.g.
  # "https://astral.sh/uv/install.sh | sh", "https://elan.lean-lang.org/elan-init.sh") are not
  # mistaken for local extension scripts. The trailing \b prevents partial-word matches inside
  # unrelated identifiers that merely start with "sh"/"sql" after a dot (e.g. Python
  # `df.shape`, `wb.sheetnames`, `slide.shapes`, `vim.opt.shiftwidth`).
  local referenced
  referenced=$(
    {
      for f in "$ext_path"/commands/*.md "$ext_path"/skills/*/SKILL.md \
               "$ext_path"/agents/*.md "$ext_path/README.md" "$ext_path/EXTENSION.md"; do
        [[ -f "$f" ]] || continue
        sed -E 's#https?://[^[:space:]]+##g' "$f" 2>/dev/null \
          | grep -oE '[A-Za-z0-9_-]+\.(sh|sql)\b'
      done
    } | sort -u
  )
  [[ -z "$referenced" ]] && return 0

  # 2. Exclude names already owned/declared by the core extension, in EITHER
  # provides.scripts or provides.hooks (cross-referenced against core's own manifest) to avoid
  # false positives on core-owned scripts/hooks that other extensions legitimately mention by
  # name (e.g. literature-retrieve.sh, generate-todo.sh, lifecycle-notify.sh).
  local core_manifest="$EXT_DIR/core/manifest.json"
  local core_declared=""
  if [[ -f "$core_manifest" ]]; then
    core_declared=$(jq -r '(.provides.scripts // [])[]?, (.provides.hooks // [])[]?' \
      "$core_manifest" 2>/dev/null)
  fi

  # 3. Exclude names declared in ANY extension's provides.scripts (cross-extension
  # invocation is legitimate -- e.g. core's --lit integration code invokes literature's
  # already-packaged scripts by name via the shared flat .claude/scripts/ directory).
  local all_declared_scripts=""
  local m
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    all_declared_scripts+=$'\n'"$(jq -r '.provides.scripts[]? // empty' "$m" 2>/dev/null)"
  done

  # 4. Exclude names already declared in this extension's own provides.hooks (a script
  # legitimately mentioned in its own docs need not be in provides.scripts if it is already
  # tracked as a hook).
  local own_hooks
  own_hooks=$(jq -r '.provides.hooks[]? // empty' "$manifest" 2>/dev/null)

  # 5. Verdict: fail on any remaining referenced name not covered by any exclusion set.
  #
  # Basename-normalized exclusion sets (added alongside the exact-match sets above): the doc-text
  # extraction regex in step 1 can only ever capture a BARE filename (it stops at the last `/`),
  # but a subdirectory-scoped provides.scripts entry is declared with its path prefix (e.g.
  # `lib/phase-heading-patterns.sh`, `tests/test-foo.sh`). An exact-string comparison between the
  # two therefore always misses for any lib/tests/-subdirectory script mentioned by bare name in
  # prose -- a false positive on a correctly-declared script, discovered when
  # scripts/lib/phase-heading-patterns.sh became the first lib/ script ever referenced by name in
  # a SKILL.md/agent.md file. Comparing basenames closes this gap without weakening the check:
  # a name is still only excluded if SOME declared entry's basename matches it exactly.
  local core_declared_basenames all_declared_basenames own_hooks_basenames
  core_declared_basenames=$(while IFS= read -r _entry; do [[ -n "$_entry" ]] && basename "$_entry"; done <<< "$core_declared")
  all_declared_basenames=$(while IFS= read -r _entry; do [[ -n "$_entry" ]] && basename "$_entry"; done <<< "$all_declared_scripts")
  own_hooks_basenames=$(while IFS= read -r _entry; do [[ -n "$_entry" ]] && basename "$_entry"; done <<< "$own_hooks")

  local name
  for name in $referenced; do
    if grep -qxF "$name" <<< "$core_declared"; then
      continue
    fi
    if grep -qxF "$name" <<< "$all_declared_scripts"; then
      continue
    fi
    if grep -qxF "$name" <<< "$own_hooks"; then
      continue
    fi
    if grep -qxF "$name" <<< "$core_declared_basenames"; then
      continue
    fi
    if grep -qxF "$name" <<< "$all_declared_basenames"; then
      continue
    fi
    if grep -qxF "$name" <<< "$own_hooks_basenames"; then
      continue
    fi
    fail "script referenced in docs/skills/agents but NOT in provides.scripts: $name"
  done
}

# Rule G: Project-wide dangling .claude/context/contracts/*.md reference scan.
#
# NOT per-extension: deployed skills/agents/rules/commands across the WHOLE project may
# reference a specific contracts/*.md file by path (e.g. a hard-mode skill's SKILL.md citing
# `.claude/context/contracts/territory.md`). If the referenced path does not exist under this
# project's `.claude/` root, the reference is dangling -- this is the exact BimodalLogic/cslib
# defect: a downstream repo's hard-mode orchestrator referenced contracts absent from that
# repo's deployed layer because core's `provides.context` never registered `contracts` (fixed in
# Phase 1), so the contracts never propagated through the deploy tree. This check is reference-driven
# (only validates what deployed content actually cites in THIS project), never presence-driven,
# so a project that references nothing missing passes even if it lacks some contracts files
# entirely (e.g. a project not loading `lean`, correctly lacking lean-only contract overrides).
#
# Scoped strictly to `.claude/context/contracts/*.md`-shaped references per this rule's own
# Non-Goals below -- a broader generic `@.claude/...` dangling-path linter is deliberately NOT
# implemented here (left as a documented, disabled extension point below) to avoid false
# positives on legitimately extension-conditional references (e.g. lean-only context files
# referenced only from lean-scoped skills, which are correctly absent in non-lean projects).
check_dangling_contract_references() {
  local f ref refs
  for f in "$REPO_ROOT"/.claude/skills/*/SKILL.md \
           "$REPO_ROOT"/.claude/agents/*.md \
           "$REPO_ROOT"/.claude/rules/*.md \
           "$REPO_ROOT"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    refs=$(grep -oE '\.claude/context/contracts/[a-zA-Z0-9_-]+\.md' "$f" 2>/dev/null | sort -u)
    for ref in $refs; do
      if [[ ! -f "$REPO_ROOT/$ref" ]]; then
        fail "dangling contract reference in ${f#"$REPO_ROOT"/}: $ref"
      fi
    done
  done

  # Extension point (NOT enabled -- stretch goal; see the Non-Goals note above): a future generic
  # dangling-path scan could widen the pattern above to `@\.claude/[a-zA-Z0-9_/.-]+\.md`
  # broadly across the same file set. This is intentionally left unimplemented; wiring it in
  # without first auditing every extension-conditional `@.claude/...` reference in this repo
  # would produce false-positive FAILs on references that are valid only when a specific
  # extension is loaded.
}

# ---------------------------------------------------------------------------
# Rules J/K/L/M/N: "Every deployed file has a source" gate.
#
# Distinct direction from check_manifest_entries (declared-but-missing-on-source, per-extension)
# and check_undeclared_skills/check_undeclared_rules (Rules A/H, present-on-source-but-undeclared,
# per-extension). This block is project-wide: for each provides category not already covered
# end-to-end by a content-drift check (rules is already fully covered by
# check_deployed_rule_drift + check_undeclared_rules), find every deployed file under
# .claude/<category>/ that traces to ZERO manifest.provides.<category> declaration in ANY
# extension. A deployed-only orphan like this vanishes on a clean rebuild from source, since
# nothing in any extension's source tree would ever recreate it.
#
# ORPHAN_GATE_MODE controls severity for this whole block (orphan checks J/K/L/M AND the broken-
# symlink check N): "advisory" (info-only, does not increment FAILURES) during the remediation-
# verification window (this task's Phase 5), "hard" (fail, increments FAILURES) once promoted
# (this task's Phase 6). Promoted to "hard" by default now that Phases 1-4 remediation has landed
# and Phase 5 confirmed a clean (0 orphans, 0 broken symlinks) advisory run -- override to
# "advisory" only for temporary local debugging, never in committed config.
ORPHAN_GATE_MODE="${ORPHAN_GATE_MODE:-hard}"

orphan_report() {
  local msg="$1"
  if [[ "$ORPHAN_GATE_MODE" == "hard" ]]; then
    fail "$msg"
  else
    info "ADVISORY (not yet blocking): $msg"
  fi
}

# Enumeration method: git ls-files (not find), matching the research audit method -- naturally
# excludes gitignored runtime artifacts (literature-pyenv/venv/, __pycache__/) without extra
# path filtering, since they were never tracked.
_git_deployed_files() {
  local category="$1"
  git -C "$REPO_ROOT" ls-files ".claude/$category" 2>/dev/null
}

# Rules J/K/M: flat-category orphan check (agents, commands, scripts).
#
# "Flat" here means one directory level of the manifest-driven descriptor copier's `entry_kind =
# "file"` semantics (loader.lua's M.copy_category, categories agents/commands/scripts) -- but
# for scripts, an individual provides.scripts entry may itself contain a "/" (e.g.
# "lint/lint-postflight-boundary.sh", "tests/generate-test-fixtures.py"), so entries are matched
# by their full relative path under the category root, not by basename alone.
check_flat_category_orphans() {
  local category="$1"
  local rule_label="$2"

  # Build the declared set: union of every extension's provides.<category> entries (regardless
  # of whether that extension's own source file exists -- a missing source is already reported
  # by check_manifest_entries; this check only asks "does ANY manifest acknowledge this deployed
  # name").
  local declared=""
  local m
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    declared+=$'\n'"$(jq -r --arg c "$category" '.provides[$c][]? // empty' "$m" 2>/dev/null)"
  done

  local rel f full
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    full="$REPO_ROOT/$rel"
    # Symlinks are governed by check_broken_deployed_symlinks (Rule N), not this content-source
    # check -- explicit [[ -L ]] skip so a dangling symlink never reaches cmp/orphan logic here
    # and is never silently mistaken for an ordinary unsourced regular file either.
    [[ -L "$full" ]] && continue
    [[ -f "$full" ]] || continue
    f="${rel#.claude/$category/}"
    if ! grep -qxF "$f" <<< "$declared"; then
      orphan_report "$rule_label: deployed $category/$f traces to no provides.$category entry in any extension manifest"
    fi
  done < <(_git_deployed_files "$category")
}

# Rule L: context orphan check (recursive).
#
# provides.context entries are either a bare filename at context root (matches itself) or a
# directory name (deployed recursively, preserving substructure, via the manifest-driven
# descriptor copier's `entry_kind = "file_or_dir"` handling -- loader.lua's M.copy_category,
# category "context"). The
# declared set must therefore be expanded to individual FILES, not just top-level entry names,
# to correctly diff against a flat git-ls-files enumeration of .claude/context/. Multiple
# extensions may legitimately declare the same directory-name entry (e.g. both core and
# literature declare "guides") -- each extension's own files are unioned in, not overwritten.
#
# Excludes any file produced by a merge_targets entry whose target lives under .claude/context/
# (e.g. context/index.json, built from index-entries.json fragments across extensions) -- these
# are not produced by provides.context copy-deploy at all and must never be flagged.
check_context_orphans() {
  local declared_files=""
  local m ext_path entries e src rel_prefix

  # Build merge_targets exclusion set (paths relative to .claude/context/).
  local excludes=""
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    while IFS= read -r tgt; do
      [[ -z "$tgt" ]] && continue
      case "$tgt" in
        .claude/context/*)
          excludes+=$'\n'"${tgt#.claude/context/}"
          ;;
      esac
    done < <(jq -r '.merge_targets // {} | to_entries[]? | .value.target // empty' "$m" 2>/dev/null)
  done

  # Build the declared file-set across every extension's own context/ source tree.
  for m in "$EXT_DIR"/*/manifest.json; do
    [[ -f "$m" ]] || continue
    ext_path="$(dirname "$m")"
    entries=$(jq -r '.provides.context[]? // empty' "$m" 2>/dev/null)
    for e in $entries; do
      src="$ext_path/context/$e"
      if [[ -d "$src" ]]; then
        while IFS= read -r f; do
          rel_prefix="${f#"$ext_path"/context/}"
          declared_files+=$'\n'"$rel_prefix"
        done < <(find "$src" -type f 2>/dev/null)
      elif [[ -f "$src" ]]; then
        declared_files+=$'\n'"$e"
      fi
      # If neither exists on disk, check_manifest_entries already reports it; nothing to add here.
    done
  done

  local rel full f
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    full="$REPO_ROOT/$rel"
    [[ -L "$full" ]] && continue
    [[ -f "$full" ]] || continue
    f="${rel#.claude/context/}"
    if grep -qxF "$f" <<< "$excludes"; then
      continue
    fi
    if ! grep -qxF "$f" <<< "$declared_files"; then
      orphan_report "Rule L: deployed context/$f traces to no provides.context entry in any extension manifest"
    fi
  done < <(_git_deployed_files "context")
}

# Rule S: deployed-index-orphan check, project-wide.
#
# Distinct direction from Rule L (check_context_orphans, which asks "does every deployed context
# file trace to a provides.context source declaration"): this rule asks "does every deployed
# context MARKDOWN file have an entry in .claude/context/index.json" -- a file can pass Rule L
# (it has a declared source and deploys correctly) while still being invisible to the index's
# dynamic load_when discovery mechanism. Scoped to *.md only, deliberately: schema files
# (index.schema.json), templates, and other non-markdown context assets legitimately have no
# index entry and must never be flagged here.
#
# Deliberately does NOT use _git_deployed_files (git ls-files): in this repository .claude/ is
# entirely gitignored (blanket `/.claude/` in .gitignore, no tracked exceptions under
# .claude/context/), so `git ls-files .claude/context` unconditionally returns zero results here
# -- confirmed empirically while building this rule, by placing a scratch file and observing it
# absent from `git ls-files` output despite `git status --ignored` correctly showing it. Reusing
# _git_deployed_files would make this rule (and, latently, Rule L before it) silently vacuous in
# this repo: it would iterate an always-empty set and never fail regardless of real orphans.
# Enumerates the actual filesystem instead (`find ... -name "*.md"`), which sees every deployed
# file regardless of git-tracking status and is safe from the runtime-cache-noise concern
# _git_deployed_files's own comment cites (literature-pyenv/venv/__pycache__ contain no .md
# files, so the *.md filter already excludes them without needing git's tracked-only view).
check_deployed_index_orphans() {
  local context_dir="$REPO_ROOT/.claude/context"
  local index_file="$context_dir/index.json"
  [[ -d "$context_dir" ]] || return 0
  [[ -f "$index_file" ]] || return 0

  local indexed_paths
  indexed_paths=$(jq -r '.entries[].path' "$index_file" 2>/dev/null)

  local full f
  while IFS= read -r full; do
    [[ -z "$full" ]] && continue
    f="${full#"$context_dir"/}"
    if ! grep -qxF "$f" <<< "$indexed_paths"; then
      index_truth_report "Rule S: deployed context/$f has no entry in .claude/context/index.json"
    fi
  done < <(find "$context_dir" -type f -name "*.md" 2>/dev/null | sort)
}

# Rule N: broken deployed symlink health check (distinct from the has-a-source orphan checks
# above). install-extension.sh is a separate, parallel deploy mechanism from provides.*
# copy-deploy: it creates real symlinks under .claude/{agents,commands,skills}/ pointing back
# into an extension's source tree. A dangling one of these technically DOES have a
# manifest-declared source (the extension does declare the agent/command/skill) -- the symlink's
# *target path* is simply wrong, most often because install-extension.sh's hardcoded relative
# path math no longer matches the current depth of the source-store root relative to
# .claude/{agents,commands,skills}/ (the exact regression repaired in this task's Phase 1).
# Surfaced as its own check with its own message so a future reader is pointed at
# install-extension.sh's relative-path math, not a missing extension source.
check_broken_deployed_symlinks() {
  local dir f
  for dir in "$REPO_ROOT/.claude/agents" "$REPO_ROOT/.claude/commands" "$REPO_ROOT/.claude/skills"; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*; do
      [[ -L "$f" ]] || continue
      if [[ ! -e "$f" ]]; then
        orphan_report "Rule N: broken deployed symlink ${f#"$REPO_ROOT"/} -- target does not resolve; likely install-extension.sh relative-path drift (see its rel_path construction), not a missing extension source"
      fi
    done
  done
}

echo "Checking .claude/extensions/ documentation..."
echo

for ext_path in "$EXT_DIR"/*/; do
  ext_name=$(basename "$ext_path")
  CURRENT_EXT="$ext_name"
  EXTENSION_STATUS["$ext_name"]="PASS"

  echo "[$ext_name]"

  # Required files
  check_file "$ext_path/manifest.json" "manifest.json"
  check_file "$ext_path/README.md" "README.md"

  # EXTENSION.md is required only when the manifest names it as the claudemd merge source (see
  # claudemd_source_for's rationale comment near Rule U). When merge_targets.claudemd is absent
  # entirely, emit an advisory (never a silent skip) unless the extension is genuinely
  # resource-only (zero skills and zero commands) -- distinguishes an accidental omission from an
  # intentional design.
  if [[ -f "$ext_path/manifest.json" ]] && jq empty "$ext_path/manifest.json" 2>/dev/null; then
    ext_claudemd_source=$(claudemd_source_for "$ext_path")
    if [[ "$ext_claudemd_source" == "EXTENSION.md" ]]; then
      check_file "$ext_path/EXTENSION.md" "EXTENSION.md"
    elif [[ -z "$ext_claudemd_source" ]]; then
      ext_skill_count=$(jq -r '(.provides.skills // []) | length' "$ext_path/manifest.json" 2>/dev/null)
      ext_cmd_count=$(jq -r '(.provides.commands // []) | length' "$ext_path/manifest.json" 2>/dev/null)
      if [[ "${ext_skill_count:-0}" -gt 0 || "${ext_cmd_count:-0}" -gt 0 ]]; then
        advisory "manifest has no merge_targets.claudemd but declares $ext_skill_count skill(s)/$ext_cmd_count command(s) -- confirm this is intentional (resource-only extensions should declare none) or add merge_targets.claudemd"
      fi
    fi
    # else: claudemd_source names a file other than "EXTENSION.md" (e.g. core's
    # merge-sources/claudemd.md) -- that file's own required-file/length checking is out of
    # scope for this rule; its existence is governed by merge_targets.claudemd itself.
  fi

  # Manifest entry validation (only if manifest exists and is valid)
  if [[ -f "$ext_path/manifest.json" ]]; then
    if jq empty "$ext_path/manifest.json" 2>/dev/null; then
      check_manifest_entries "$ext_path"
      check_deployed_script_drift "$ext_path"
      check_routing_block "$ext_path"
      check_undeclared_skills "$ext_path"
      check_undeclared_rules "$ext_path"
      check_undeclared_scripts "$ext_path"
      check_line_count_accuracy "$ext_path"
      check_index_entries_schema "$ext_path"
      check_extension_md_length "$ext_path"
      check_claudemd_size_budget "$ext_path"
      check_deployed_rule_drift "$ext_path"
      check_routing_consistency "$ext_path"
      check_deployed_skill_agents "$ext_path"
      check_readme_vs_manifest "$ext_path"
      check_referenced_scripts_declared "$ext_path"
      check_core_deploy_advisory "$ext_path"
    else
      fail "manifest.json is not valid JSON"
    fi
  fi

  if [[ "${EXTENSION_STATUS[$ext_name]}" == "PASS" ]]; then
    info "OK"
  fi
  echo
done

# Project-wide checks (not scoped to a single extension).
CURRENT_EXT="project-wide"
EXTENSION_STATUS["project-wide"]="PASS"
echo "[project-wide]"
check_dangling_contract_references
check_flat_category_orphans "agents" "Rule J"
check_flat_category_orphans "commands" "Rule K"
check_context_orphans
check_deployed_index_orphans
check_flat_category_orphans "scripts" "Rule M"
check_broken_deployed_symlinks
if [[ "${EXTENSION_STATUS[project-wide]}" == "PASS" ]]; then
  info "OK"
fi
echo

# Core Deploy-Drift Advisory summary (Rules O/P) -- ALWAYS printed when non-empty, regardless of
# --quiet, and deliberately placed BEFORE the pass/fail Summary table so it reads as its own
# section, not a footnote. This block is purely informational and does NOT affect FAILURES or
# the exit code unless STRICT_CORE_DEPLOY=1 (in which case the underlying advisory() calls above
# already routed into fail()/FAILURES themselves).
if [[ "$DEPLOY_DRIFT_ADVISORIES" -gt 0 ]]; then
  echo "====================================="
  echo "Core Deploy-Drift Advisory (informational -- does NOT affect the PASS/FAIL verdict below)"
  echo "====================================="
  for line in "${DEPLOY_DRIFT_ADVISORY_LINES[@]}"; do
    echo "  - $line"
  done
  echo
  echo "$DEPLOY_DRIFT_ADVISORIES advisory item(s) found. Resolve by regenerating the deploy tree,"
  echo "either interactively (<leader>al -> 'Reload All', or 'Regenerate' for a full wipe+rebuild)"
  echo "or headlessly:"
  echo "    bash .claude/scripts/deploy-headless.sh"
  echo "Then confirm with: bash .claude/scripts/verify-deploy.sh"
  echo "Note: advisories naming an install-once file (root-files/settings.json) are NOT fixed by"
  echo "regenerating -- follow their instruction to add the entry to the merge source instead."
  echo "Set STRICT_CORE_DEPLOY=1 to treat these as hard failures (e.g. post-regeneration verification)."
  echo
fi

# Summary table
echo "====================================="
echo "Summary"
echo "====================================="
printf "%-15s %s\n" "Extension" "Status"
printf "%-15s %s\n" "---------" "------"
for ext in "${!EXTENSION_STATUS[@]}"; do
  printf "%-15s %s\n" "$ext" "${EXTENSION_STATUS[$ext]}"
done | sort
echo

if [[ "$FAILURES" -gt 0 ]]; then
  echo "FAIL: $FAILURES issue(s) found"
  exit 1
else
  echo "PASS: all extensions OK"
  exit 0
fi
