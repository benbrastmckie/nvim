---
title: "When porting scripts between dual-system architectures (.claude/ and .opencode/)"
created: 2026-06-08
tags: [PATTERN]
topic: "task-633"  # task-ref-ok inline, category 7 (memory frontmatter provenance field)
source: "specs/633_port_core_script_infrastructure/summaries/01_core_script_infra-summary.md"
modified: 2026-06-08
retrieval_count: 0
last_retrieved: null
keywords:
  - script-porting
  - dual-system
  - dependency-order
  - path-substitution
  - claude-opencode
summary: "When porting scripts between dual-system architectures (.claude/ and .opencode/)"
status: tombstoned
tombstoned_at: 2026-09-18
tombstone_reason: "purge"
token_count: 261
---

# When porting scripts between dual-system architectures (.claude/ and .opencode/)

When porting scripts between dual-system architectures (.claude/ and .opencode/), use a dependency-driven phase ordering: (1) update stale shared-dependency scripts first (update-task-status.sh, update-plan-status.sh) since other scripts call into them, (2) port foundational scripts (skill-base.sh, command-gate-*, postflight-workflow.sh) since workflow/gateway scripts depend on them, (3) port gateway/wrapper scripts that depend on Phase 2, (4) port workflow scripts, (5) port review/validation scripts, (6) run global verification. Key substitutions: .claude/ -> .opencode/, .claude/context/ -> .opencode/context/, .claude/extensions/ -> .opencode/extensions/, Agent tool -> Task tool, CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS -> OPENCODE_EXPERIMENTAL_AGENT_TEAMS. Use sed for bulk path substitutions followed by manual grep for edge cases. Some scripts (orphan-detection.sh, archive-task.sh, issue-grouping.sh) are mostly path-independent and can be copied as-is.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
