#!/usr/bin/env bash
# task-ref-ok:begin test fixture: every "task N" string below is a synthetic project_number
# literal (10, 11, 20, 21, 30-38, 40, 41, 50, 60, 61, 70) fed to the lint under test as fake
# fixture data, or that lint's own echoed output text quoting one back -- never a citation of a
# real task in this system's own backlog. Category-6 analog (test fixtures for the thing under
# test need concrete digits; a placeholder would not match the lint's own numeric parsing and
# would silently disable the assertion).
#
# test-lint-roadmap-batch-proposals.sh - Fixture suite for
# scripts/lint/lint-roadmap-batch-proposals.sh, which reads the authored roadmap entries in
# specs/state.json: one firing and one clean fixture per kept finding ((a), (c), (f)), the
# rejected dependent-only finding's absence, the absence of any terminal-member finding (owned
# by validate-state.sh Check 13), a clean store, the flat-shape fallback, a closed milestone
# being skipped, the removed --roadmap flag, and the advisory exit-code contract.
#
# Structural model: test-lint-json-channel-discipline.sh's resolve-subject helper call
# (mode=deploy-tree-first) and WORKDIR-fixture conventions. Class B strict mode (`set -uo
# pipefail`, no `-e`): this suite accumulates a PASSED/FAILED counter across many independent
# cases and must keep going past an individual case's failure to report everything that's wrong.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LINT_SCRIPT="$(common_test_resolve_subject "lint-roadmap-batch-proposals.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-roadmap-batch-proposals.sh" \
  "$SCRIPT_DIR/../lint/lint-roadmap-batch-proposals.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0

common_test_workdir_init

run_lint() {
  # Usage: run_lint <state_path> [extra args...]
  local stdout_file stderr_file state="$1"
  shift
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$LINT_SCRIPT" --verbose --state "$state" "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

# write_state <path> <active_projects_json> <roadmap_milestones_json> [extra top-level jq]
write_state() {
  jq -n --argjson ap "$2" --argjson ms "$3" \
    '{active_projects: $ap, roadmap_milestones: $ms}'" ${4:-}" > "$1"
}
# one_ms <id> <batches_json> -- one active milestone
one_ms() {
  printf '[{"id":"%s","title":"T","aim":"A","progress":{"status":"active"},"batches":%s}]' "$1" "$2"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (a): the real observed failure -- two tasks sharing files under one component's
# certificate/ directory, one omitted from the batch.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (a): real observed failure (shared certificate/ territory, one omitted)"
write_state "$WORKDIR/a-fire.json" '[
  {"project_number":10,"status":"not_started","file_scope":["components/framed_channel/certificate/a.txt","components/framed_channel/certificate/b.txt","components/framed_channel/certificate/c.txt"]},
  {"project_number":11,"status":"not_started","dependencies":[10],"file_scope":["components/framed_channel/certificate/b.txt"]}
]' "$(one_ms M1 '[{"task_ids":[10],"description":"d"}]')"
run_lint "$WORKDIR/a-fire.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING (a)')" -eq 1 ] \
   && echo "$LAST_STDOUT" | grep -q '^\[milestone M1 batch 1\] FINDING (a): task 11 ' \
   && echo "$LAST_STDOUT" | grep -q 'in-batch task 10' \
   && echo "$LAST_STDOUT" | grep -q 'certificate/b.txt'; then
  common_test_pass "finding (a): one finding, labelled [milestone M1 batch 1], naming both tasks and the shared path"
else
  common_test_fail "finding (a): expected exactly one labelled FINDING (a) naming tasks 10/11 and certificate/b.txt" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# Clean: an omitted DEPENDENT with no territory overlap produces NO finding -- the rejected
# dependent-only finding stays absent.
common_test_info "Finding (a) clean: omitted dependent with no territory overlap"
write_state "$WORKDIR/a-clean.json" '[
  {"project_number":20,"status":"not_started","file_scope":["scripts/foo.sh"]},
  {"project_number":21,"status":"not_started","dependencies":[20],"file_scope":["scripts/bar.sh"]}
]' "$(one_ms M1 '[{"task_ids":[20],"description":"d"}]')"
run_lint "$WORKDIR/a-clean.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING')" -eq 0 ]; then
  common_test_pass "finding (a) clean: a dependency edge alone is never a finding"
else
  common_test_fail "finding (a) clean: expected zero findings" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (c): a nine-member batch exceeds MAX_TASKS=8; no trimmed batch is proposed. An
# eight-member batch is clean.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (c): nine-member batch exceeds MAX_TASKS=8, no trimmed batch proposed"
nine_tasks="$(jq -n -c '[range(30; 39) | {project_number: ., status: "not_started"}]')"
write_state "$WORKDIR/c-fire.json" "$nine_tasks" \
  "$(one_ms M2 '[{"task_ids":[30],"description":"small"},{"task_ids":[30,31,32,33,34,35,36,37,38],"description":"too big"}]')"
run_lint "$WORKDIR/c-fire.json"
if [ "$LAST_EXIT" -eq 0 ] \
   && echo "$LAST_STDOUT" | grep -q '^\[milestone M2 batch 2\] FINDING (c): batch has 9 tasks, exceeds MAX_TASKS=8' \
   && ! echo "$LAST_STDOUT" | grep -q '/orchestrate '; then
  common_test_pass "finding (c): labelled [milestone M2 batch 2], and no /orchestrate line is proposed"
else
  common_test_fail "finding (c): expected a labelled FINDING (c) and no proposed /orchestrate line" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi
write_state "$WORKDIR/c-clean.json" "$nine_tasks" \
  "$(one_ms M2 '[{"task_ids":[30,31,32,33,34,35,36,37],"description":"exactly eight"}]')"
run_lint "$WORKDIR/c-clean.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING (c)')" -eq 0 ]; then
  common_test_pass "finding (c) clean: an eight-member batch is within the cap"
else
  common_test_fail "finding (c) clean: expected no FINDING (c)" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# No terminal-member finding: a completed member and an unresolvable member are validate-state.sh
# Check 13's to report, never this lint's.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "No terminal-member finding: completed and unresolvable members are not reported here"
write_state "$WORKDIR/no-d.json" '[
  {"project_number":40,"status":"completed"},
  {"project_number":41,"status":"abandoned"}
]' "$(one_ms M1 '[{"task_ids":[40,41,99999],"description":"d"}]')"
run_lint "$WORKDIR/no-d.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING')" -eq 0 ] \
   && ! echo "$LAST_STDOUT" | grep -qi 'terminal\|does not exist'; then
  common_test_pass "terminal and unresolvable members produce no finding from this lint"
else
  common_test_fail "expected zero findings for terminal/unresolvable members" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Finding (f): an unresolvable path cited in a bounded roadmap string field, labelled with the
# field's state path; scoped to those fields only.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Finding (f): unresolvable citation in bounded roadmap fields"
jq -n '{
  active_projects: [{project_number: 50, status: "not_started",
    roadmap_annotation: "see `specs/999998_no_such_dir/reports/annot.md`",
    description: "not a roadmap field: `specs/999998_no_such_dir/reports/ignored.md`"}],
  primary_goals: ["goal citing `specs/999998_no_such_dir/goal.md`"],
  roadmap_milestones: [{id: "M1", title: "T", aim: "aim citing `specs/999998_no_such_dir/aim.md`",
    gate: "gate citing `specs/999998_no_such_dir/gate.md`",
    progress: {status: "active", note: "note citing `specs/999998_no_such_dir/note.md`"},
    batches: [{task_ids: [50], description: "batch citing `specs/999998_no_such_dir/batch.md`",
               rationale: "unbounded, not scanned: `specs/999998_no_such_dir/rationale.md`"}]}],
  roadmap_context: {overview: ["o `specs/999998_no_such_dir/overview.md`"],
    rules: ["r `specs/999998_no_such_dir/rules.md`"],
    conventions: ["c `specs/999998_no_such_dir/conventions.md`"]}
}' > "$WORKDIR/f-fire.json"
run_lint "$WORKDIR/f-fire.json"
f_ok=true
for want in \
  '\[primary_goals\[0\]\] FINDING (f): cited path does not resolve: `specs/999998_no_such_dir/goal.md`' \
  '\[roadmap_milestones\[0\]\.aim\] FINDING (f): .*aim.md' \
  '\[roadmap_milestones\[0\]\.gate\] FINDING (f): .*gate.md' \
  '\[roadmap_milestones\[0\]\.progress\.note\] FINDING (f): .*note.md' \
  '\[roadmap_milestones\[0\]\.batches\[0\]\.description\] FINDING (f): .*batch.md' \
  '\[roadmap_context\.overview\[0\]\] FINDING (f): .*overview.md' \
  '\[roadmap_context\.rules\[0\]\] FINDING (f): .*rules.md' \
  '\[roadmap_context\.conventions\[0\]\] FINDING (f): .*conventions.md' \
  '\[active_projects\[project_number=50\]\.roadmap_annotation\] FINDING (f): .*annot.md'; do
  echo "$LAST_STDOUT" | grep -q "^$want" || { f_ok=false; common_test_info "missing: $want"; }
done
if [ "$LAST_EXIT" -eq 0 ] && $f_ok && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING (f)')" -eq 9 ]; then
  common_test_pass "finding (f): each of the nine bounded fields is scanned and labelled with its state path"
else
  common_test_fail "finding (f): expected exactly nine labelled FINDING (f) lines" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi
if ! echo "$LAST_STDOUT" | grep -q 'ignored.md\|rationale.md'; then
  common_test_pass "finding (f): fields outside the bounded roadmap set (task description, batch rationale) are not scanned"
else
  common_test_fail "finding (f): a field outside the bounded roadmap set was scanned" "stdout=$LAST_STDOUT"
fi

common_test_info "Finding (f) clean: bare basename, cross-repo path, placeholder, shell command"
write_state "$WORKDIR/f-clean.json" '[{"project_number":60,"status":"not_started"}]' \
  "$(one_ms M1 '[{"task_ids":[60],"description":"`ci.yml` `~/Projects/other/file.md` `/abs/path.md` `specs/{NNN}_x/a.md` `rm a/b`"}]')"
run_lint "$WORKDIR/f-clean.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING (f)')" -eq 0 ] \
   && echo "$LAST_STDERR" | grep -q 'skipped 1 bare-basename candidate(s) and 2 cross-repository candidate(s)'; then
  common_test_pass "finding (f) clean: both false-positive classes are skipped and counted, never reported"
else
  common_test_fail "finding (f) clean: expected zero FINDING (f) lines and the skip counts" "exit=$LAST_EXIT stdout=$LAST_STDOUT stderr=$LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Clean store, empty store, flat fallback, closed milestone.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Clean store: no findings, scan line reports the milestone shape"
write_state "$WORKDIR/clean.json" '[
  {"project_number":60,"status":"not_started","file_scope":["a/one.sh"]},
  {"project_number":61,"status":"not_started","file_scope":["a/two.sh"]}
]' "$(one_ms M1 '[{"task_ids":[60],"description":"one"},{"task_ids":[61],"description":"two"}]')"
run_lint "$WORKDIR/clean.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -qx 'Scan complete. shape=milestones batches=2 findings=0'; then
  common_test_pass "clean store: 'Scan complete. shape=milestones batches=2 findings=0'"
else
  common_test_fail "clean store: expected a zero-finding scan line" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

echo '{"active_projects": []}' > "$WORKDIR/empty.json"
run_lint "$WORKDIR/empty.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -qx 'Scan complete. shape=none batches=0 findings=0'; then
  common_test_pass "empty store: completes with shape=none, zero batches, zero findings"
else
  common_test_fail "empty store: expected shape=none and zero findings" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

common_test_info "Flat fallback: a store with no roadmap_milestones key is linted from roadmap_batches"
jq -n '{active_projects: [
    {project_number: 10, status: "not_started", file_scope: ["x/shared.txt"]},
    {project_number: 11, status: "not_started", file_scope: ["x/shared.txt"]}],
  roadmap_batches: [{task_ids: [10], description: "flat"}]}' > "$WORKDIR/flat.json"
run_lint "$WORKDIR/flat.json"
if [ "$LAST_EXIT" -eq 0 ] \
   && echo "$LAST_STDOUT" | grep -q '^\[batch 1\] FINDING (a): task 11 ' \
   && echo "$LAST_STDOUT" | grep -qx 'Scan complete. shape=flat batches=1 findings=1'; then
  common_test_pass "flat fallback: finding labelled [batch 1], scan line reports shape=flat"
else
  common_test_fail "flat fallback: expected a [batch 1] finding and shape=flat" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

common_test_info "Closed milestone: its batches are not linted"
write_state "$WORKDIR/closed.json" '[
  {"project_number":10,"status":"completed","file_scope":["x/shared.txt"]},
  {"project_number":11,"status":"not_started","file_scope":["x/shared.txt"]},
  {"project_number":70,"status":"not_started","file_scope":["y/other.txt"]}
]' '[{"id":"M0","title":"T","aim":"A","progress":{"status":"closed","closed":"2026-01-01"},"batches":[{"task_ids":[10],"description":"closed work"}]},
     {"id":"M1","title":"T","aim":"A","progress":{"status":"active"},"batches":[{"task_ids":[70],"description":"open work"}]}]'
run_lint "$WORKDIR/closed.json"
if [ "$LAST_EXIT" -eq 0 ] && echo "$LAST_STDOUT" | grep -qx 'Scan complete. shape=milestones batches=1 findings=0'; then
  common_test_pass "closed milestone: only the open milestone's batch is scanned"
else
  common_test_fail "closed milestone: expected batches=1 findings=0" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Interface: the rendered file is not an input (no --roadmap flag); a missing state file is a
# usage error; the lint never needs specs/ROADMAP.md to exist.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Interface: --roadmap is not accepted; missing state is exit 2"
run_lint "$WORKDIR/clean.json" --roadmap "$WORKDIR/no-such-ROADMAP.md"
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -q 'unknown argument: --roadmap'; then
  common_test_pass "interface: --roadmap is rejected as an unknown argument (exit 2)"
else
  common_test_fail "interface: expected exit 2 on --roadmap" "exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
run_lint "$WORKDIR/does-not-exist.json"
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -q 'state file not found'; then
  common_test_pass "interface: a missing state file is a usage error (exit 2)"
else
  common_test_fail "interface: expected exit 2 on a missing state file" "exit=$LAST_EXIT stderr=$LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Advisory contract: exit code is 0 even with findings present. Pinned mechanically here (every
# sibling lint exits 1 on a violation; this one never does).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Advisory contract: exit code is 0 with findings present"
run_lint "$WORKDIR/a-fire.json"
if [ "$LAST_EXIT" -eq 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'FINDING')" -ge 1 ]; then
  common_test_pass "advisory contract: exit 0 with findings present"
else
  common_test_fail "advisory contract: expected exit 0 with at least one finding present" "exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
# task-ref-ok:end
