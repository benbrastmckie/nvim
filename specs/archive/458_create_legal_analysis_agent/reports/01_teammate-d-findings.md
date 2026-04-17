# Teammate D Findings: Strategic Direction for Legal Analysis Agent

**Task**: 458 - Create legal-analysis-agent for critical legal feedback
**Role**: Teammate D (Horizons) - Long-term alignment and strategic direction
**Date**: 2026-04-16

---

## Key Findings

### 1. The /critic Gap in the Founder Extension

The current founder extension provides 9 commands that are all **constructive/generative** in nature:
- `/market` - Build market research
- `/analyze` - Build competitive analysis
- `/strategy` - Build go-to-market strategy
- `/legal` - Build contract review
- `/project` - Build project timelines
- `/sheet` - Build financial spreadsheets
- `/finance` - Build financial models
- `/deck` - Build pitch decks
- `/meeting` - Build meeting agendas

**There is no critical/adversarial command.** Every existing command helps the founder *build* something. `/critic` would be the first command that *tears something down* (constructively). This is a genuine capability gap -- the founder extension has no way to stress-test output before presenting it to the world.

### 2. /critic as a Framework, not a Single-Purpose Tool

The `--attorney` flag in the task description implies a flag-based dispatch architecture. This is strategically correct. The evidence from the existing system supports a general `/critic` framework:

**Pattern from /analyze (LANDSCAPE|DEEP|POSITION|BATTLE modes)**:
- Same command, different analytical lenses
- Mode selection at invocation time via forcing question

**Pattern from /legal (REVIEW|NEGOTIATE|TERMS|DILIGENCE modes)**:
- Same command, different legal postures

`/critic` should follow the same convention: one command, multiple domain lenses selectable via flags:

| Flag | Agent Posture | Target Documents |
|------|--------------|-----------------|
| `--attorney` | Legal risk, liability, overstatement | Marketing copy, pitch decks, claims |
| `--investor` | Investment thesis weaknesses, skeptical VC | Business plans, decks, financials |
| `--technical` | Feasibility, architecture holes, tech debt | Technical specs, architecture docs |
| `--competitor` | Competitive weaknesses, positioning holes | Go-to-market strategy, positioning |
| `--regulator` | Compliance gaps, regulatory exposure | Product descriptions, marketing |

Starting with `--attorney` is correct -- it's the most immediately useful for Logos' legal-AI marketing material. The framework should be designed to accept additional modes later without architectural changes.

### 3. Relationship to Existing Commands -- No Overlap

The concern about overlap with `/legal` and `/analyze` is resolved cleanly:

| Command | Posture | Primary Input | Output |
|---------|---------|--------------|--------|
| `/legal` | Advisory, collaborative | Contract documents | Contract analysis, negotiation strategy |
| `/analyze` | Research, intelligence | Market/competitors | Competitive landscape, positioning |
| `/critic --attorney` | Adversarial, critical | *Your own* documents | Risk assessment, liability flags |

The key distinction: `/legal` reviews *incoming* contracts you receive. `/critic --attorney` reviews *outgoing* materials you produce. These serve opposite purposes and do not overlap.

### 4. The legal-analysis-agent vs. legal-council-agent Distinction

The current `legal-council-agent` is contract-focused:
- Asks about contract parties, financial exposure, governing law
- Produces contract analysis reports
- Escalates to human attorneys based on deal value

The proposed `legal-analysis-agent` should be *document critique* focused:
- Reviews marketing claims for legal accuracy and overstatement risk
- Identifies potential liability in how capabilities are described
- Flags regulatory exposure in product descriptions
- Checks pitch deck claims against known legal constraints for legal AI

These are complementary, not redundant. Both agents belong in the extension.

### 5. The Logos Meta-Usefulness Angle

The user is building Logos, a legal AI product. The `legal-analysis-agent` is doubly useful:

**Direct utility**: Catch legal risk in Logos' own marketing materials before presenting to customers, investors, or press. Slides that claim "Logos performs attorney-quality analysis" could trigger unauthorized practice of law concerns. An attorney-posture agent would catch this.

**Product validation**: The agent's critique patterns mirror what Logos itself should do. Running `/critic --attorney` on Logos' own documentation is a form of dogfooding -- using an agent that reasons the way Logos reasons, applied to Logos' own claims.

**Broader reuse**: Once established, `legal-analysis-agent` can review:
- Term sheets before sending to investors
- Job descriptions for compliance issues
- Website copy for regulatory accuracy
- Any founder-produced document that carries legal weight

### 6. Extension Architecture Fit

The new agent fits cleanly into the existing manifest pattern:

**New artifacts needed**:
- `agents/legal-analysis-agent.md` (new agent, analogous to `legal-council-agent.md`)
- `commands/critic.md` (new command)
- `skills/skill-critic/SKILL.md` (new skill, thin wrapper like `skill-legal`)

**Manifest additions**:
```json
"provides": {
  "agents": [..., "legal-analysis-agent.md"],
  "skills": [..., "skill-critic"],
  "commands": [..., "critic.md"]
},
"routing": {
  "research": {
    "founder:critic": "skill-critic"
  }
}
```

The `/critic` command does NOT need to integrate with the `/research`/`/plan`/`/implement` pipeline in the initial implementation. A simpler `--quick`-style standalone mode (like `analyze --quick`) is appropriate for an adversarial critique tool. Critics give feedback immediately; they don't need research phases.

### 7. Strategic Risk: Scope Creep vs. Focused Implementation

The main strategic risk is building too general a framework too early. Recommended phasing:

**Phase 1 (Task 458)**: Build `legal-analysis-agent` + `/critic --attorney` only. Prove the adversarial critique pattern works. Keep the command narrow.

**Phase 2 (future task)**: Generalize to full `/critic` framework with multiple flag modes. Add `--investor`, `--technical`, etc. as the use case proves out.

This avoids the trap of over-engineering a framework for flags that may never be used.

---

## Recommended Approach

### Architecture Decision: Standalone Command (not task-integrated)

Unlike `/legal` and `/analyze` which integrate with the task system for long research workflows, `/critic` should operate as a **direct critique tool**:

```
/critic --attorney /path/to/document.md
/critic --attorney "Review the legal claims in legal-ai-example.typ"
```

The critic produces output immediately -- no task creation, no research/plan/implement pipeline. This matches the user's mental model of "get critical feedback now." The forcing question pattern is appropriate (what specifically to critique, what persona to adopt), but the output is a critique report, not a research artifact for downstream planning.

### Agent Design: Adversarial Posture is Critical

The `legal-analysis-agent` must adopt a genuinely critical posture. Its default behavior should be:
1. Assume the document contains problems
2. Look for problems systematically (liability, overstatement, regulatory, IP)
3. Report every issue found, not just the most serious ones
4. Never soften critique with excessive qualifiers

This is the opposite of the `legal-council-agent`'s collaborative, advisory posture.

### Key Output Structure

The agent should produce a structured critique with:
- **Risk Summary**: High/Medium/Low overall risk rating
- **Flagged Claims**: Each problematic statement with specific risk type
- **Liability Analysis**: What specific legal exposure each issue creates
- **Recommended Revisions**: Exact replacement language for each flag
- **Escalation Assessment**: Whether human attorney review is needed for this document

---

## Evidence and Examples

### Evidence: Existing flag pattern in founder commands

From `legal.md` modes (REVIEW|NEGOTIATE|TERMS|DILIGENCE) -- the extension already uses mode flags extensively. Adding `--attorney` as a critic flag follows established conventions.

### Evidence: Standalone vs. task-integrated patterns

The `--quick` flag on both `/legal` and `/analyze` provides standalone mode without task creation. `/critic` should use this pattern by default (no `--quick` needed -- it's always immediate output mode).

### Evidence: Gap in adversarial coverage

All 9 existing commands are constructive. Zero existing commands adopt an adversarial or critical posture. The gap is real and documented by reading every command file.

### Evidence: Logos-specific value

The trigger for this task is reviewing `legal-ai-example.typ`. Legal AI marketing materials are legally sensitive because:
1. Claims about AI performing legal analysis can trigger unauthorized practice of law
2. Marketing to law firms requires accuracy about what AI can/cannot do
3. Investors will scrutinize legal AI founders more carefully on regulatory exposure

An attorney-posture agent reviewing Logos marketing copy before each investor meeting is high-value for low-cost.

---

## Confidence Level

**Overall: High**

- Architecture fit: High confidence. The agent/skill/command pattern is well-established; a new tuple follows exactly the same structure as the 14 existing agents.
- Standalone vs. task-integrated: High confidence. Critique is synchronous feedback, not a multi-phase research workflow.
- /critic as framework with flags: Medium confidence. Correct strategically, but the scope of Phase 1 should stay narrow (--attorney only).
- Logos meta-usefulness: High confidence. The use case is direct and the ROI is clear.
- Phase 2 generalization: Medium confidence. Worth designing for but not worth building now.

---

## Open Questions for Other Teammates

1. **For Teammate A (technical implementation)**: What forcing questions should `legal-analysis-agent` ask before critiquing a document? Does it need to know the intended audience (investors vs. customers vs. regulators)?

2. **For Teammate B (legal domain knowledge)**: What are the specific legal risk categories that matter most for a legal AI product's marketing? Unauthorized practice of law? False advertising? Privacy claims?

3. **For Teammate C (patterns)**: Should the critique output go into a file (like `founder/critique-{datetime}.md`) or just print to the terminal? What's the right artifact format for a critique?
