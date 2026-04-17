# Research Report: Task #458

**Task**: Create legal-analysis-agent for critical legal feedback
**Date**: 2026-04-16
**Mode**: Team Research (4 teammates)
**Session**: sess_1713308100_a7b3c1

## Summary

Four-teammate parallel research covering legal fundamentals, agent design patterns, critical gap analysis, and strategic direction. The research establishes (1) the core legal principles an attorney-critique agent must embody, (2) the concrete design for a `/critic` command and `legal-analysis-agent`, (3) significant risks including scope underspecification and incomplete attorney feedback, and (4) strategic positioning as the first adversarial/critical command in the founder extension.

## Key Findings

### 1. Legal Fundamentals the Agent Must Encode (Teammate A)

Five non-negotiable principles emerged from legal research:

**Arguments are constructed, not found.** Party positions are known from Day 1 ("they breached the contract" vs. "no they didn't"). Attorneys find *evidence* and *legal authority*, then *construct arguments* by applying law to facts via IRAC methodology. The phrase "finding arguments" conflates three distinct activities and is a fundamental conceptual error.

**Discovery is a strict term of art.** It means the formal pretrial compelled exchange of information between parties (FRCP Rules 26-37: interrogatories, depositions, document production, requests for admission). It is NOT a synonym for investigation, research, or "finding what you missed." Any non-technical use is a factual error.

**Case evaluation is continuous, not a filing checkpoint.** Attorneys evaluate case strength from initial client contact through trial. "Stress testing" happens in pretrial preparation, not during witness examination. Witness cross-examination tests credibility, not argument validity. Attorneys never ask a question at trial without knowing the answer.

**Duty of candor is absolute.** ABA Model Rule 3.3 prohibits knowingly false statements of fact or law, offering false evidence, and failing to disclose adverse controlling authority. This is a bright-line rule that cannot be waived by client instruction and overrides attorney-client confidentiality.

**Merit is ongoing professional judgment.** Rules 3.1 and 11 require good faith factual and legal bases confirmed through reasonable pre-filing investigation. "Meritorious" is not a quality check done at filing -- it is continuous professional judgment throughout the case lifecycle.

### 2. Agent Design: Immediate Critique, Not Forcing Questions (Teammate B)

The legal-analysis-agent is fundamentally different from legal-council-agent:

| Dimension | legal-council-agent | legal-analysis-agent |
|-----------|---------------------|----------------------|
| Trigger | Contract review Q&A | Document critique |
| Input | Forcing questions drive the work | Document provided upfront |
| Questions | 8+ mandatory forcing questions | 1 clarifying question max |
| Output | Research report for follow-on workflow | Immediate structured critique |
| Tone | Counsel gathering facts | Attorney identifying weaknesses |
| Use case | "Help me review this contract" | "What's wrong with this?" |

The agent should: (1) receive the document, (2) read it thoroughly, (3) ask ONE clarifying question about the user's primary concern, (4) perform deep critical analysis, (5) return structured critique with severity ratings and concrete redline suggestions.

Recommended output format: structured critique with Executive Summary, Critical/High/Medium issues each with Location, Problem, Risk, and Redline (exact replacement language), plus Attorney Escalation recommendation.

### 3. /critic as First Adversarial Command (Teammate D)

All 9 existing founder commands are constructive/generative. `/critic` fills a genuine capability gap as the first adversarial command. The flag-based dispatch architecture is strategically sound:

| Flag | Posture | For Phase 1? |
|------|---------|-------------|
| `--attorney` | Legal risk, liability, overstatement | Yes |
| `--investor` | Investment thesis weaknesses | Future |
| `--technical` | Feasibility, architecture holes | Future |
| `--competitor` | Competitive weaknesses | Future |

Key distinction resolving overlap concerns: `/legal` reviews *incoming* contracts you receive. `/critic --attorney` reviews *outgoing* materials you produce.

The command should operate as standalone immediate-mode (no task pipeline integration required). This matches the user's mental model of "get critical feedback now."

### 4. Specific Document Errors Beyond Attorney Feedback (Teammate C)

Beyond the attorney's flagged issues, the Critic identified additional problems in legal-ai-example.typ:

- **Line 544**: "duty of candor to the tribunal" used as a quality benchmark for AI outputs. The duty (Rule 3.3) is a prohibition on deception, not a work-quality standard.
- **Line 603**: "You are presenting a proof, not an opinion" conflates formal logical proof with legal argument. Opposing counsel has no obligation to accept it.
- **Line 631**: "The ABA now requires attorneys to perform 'independent verification of all AI-generated outputs'" may mischaracterize ABA Opinion 512, which addresses competence/supervision obligations more broadly.
- **Lines 455-471**: Five-step concealment reasoning conflates evidentiary analysis with legal conclusions. "Concealment established" is an evidentiary sufficiency assessment, not a logical proof.
- **Line 471**: "Intentional fraud" used loosely where legal doctrine distinguishes intentional fraud from fraudulent concealment (different elements, different statutes of limitations, Rule 9(b) particularity requirements).
- **"Formally verified"**: Used repeatedly without explaining the formal system, axioms, or completeness/soundness guarantees. Attorneys will probe this.

### 5. Five Error Categories for Agent Detection (Teammate A)

The agent should systematically check for:

1. **Terminology errors**: Legal terms used incorrectly (e.g., "discovery" as investigation)
2. **Process/timeline errors**: Legal processes described in wrong context (e.g., case evaluation at trial)
3. **Ethical accuracy errors**: Duty of candor, Rule 11, merit assessment mischaracterized
4. **Reasoning framework errors**: Conclusions without governing rules, assertions without IRAC structure
5. **Role confusion errors**: Attorneys as neutral investigators, confusing advocate vs. judge roles

## Synthesis

### Conflicts Resolved

**1. Command naming**: Teammate C flagged `/critic` as ambiguous and suggested alternatives (`/analyze --legal`, `/critique --legal`, `/legal-review`). Teammates B and D supported `/critic` as a framework command with flag routing. **Resolution**: Keep `/critic` as the command name -- it correctly signals adversarial posture, and the `--attorney` flag provides domain specificity. The base command (no flag) should ask which critique mode to use, providing a coherent default.

**2. Scope of "thinks like a lawyer"**: Teammate C correctly identified this as underspecified. Teammate A provided the concrete specification: five error categories with actionable detection rules. **Resolution**: The agent should be scoped as a "legal terminology and claims critic" (per Teammate C's recommendation), operationalized through Teammate A's five error categories. NOT a comprehensive legal review.

**3. Framework generality vs. focus**: Teammate D proposed a broad multi-flag framework; Teammate C warned about scope creep. **Resolution**: Phase 1 builds only `--attorney` mode. The architecture should *support* future flags but not *implement* them. This means the command routing should use a dispatch pattern but only one agent exists initially.

### Gaps Identified

1. **Incomplete attorney feedback**: The attorney explicitly said "There's more." Building the agent on partial feedback risks missing error patterns. **Mitigation**: Design the agent's error taxonomy to be extensible. When remaining feedback arrives, add new detection patterns without restructuring.

2. **Jurisdictional sensitivity**: The agent cannot reliably apply jurisdiction-specific standards. **Mitigation**: Agent should flag jurisdiction-dependent claims and recommend verification rather than asserting correctness.

3. **Knowledge currency**: Legal statistics, enforcement dates, and regulatory interpretations change. **Mitigation**: Agent should flag time-sensitive claims (statistics, enforcement dates, "as of" claims) for currency verification.

4. **AI confidence calibration**: The agent will be wrong in ways users can't easily detect. **Mitigation**: Every critique item should carry a confidence level and a verification suggestion.

### Recommendations

1. **Create `legal-analysis-agent.md`** with:
   - Adversarial posture (assume document has problems, find them all)
   - Five error categories from Teammate A as detection framework
   - Structured critique output format from Teammate B
   - Confidence levels on each finding per Teammate C
   - `model: opus` for legal reasoning depth
   - Clear exclusion: "Does NOT review contracts or provide legal counsel"

2. **Create `/critic` command** with:
   - Standalone immediate-mode operation (no task pipeline)
   - Flag-based dispatch: `--attorney` routes to legal-analysis-agent
   - Input types: file path, text/prompt, or task number
   - One clarifying question maximum before analysis
   - Extensible dispatch for future `--investor`, `--technical` flags

3. **Create `skill-critic`** as thin wrapper skill to route between critic modes

4. **Update `manifest.json`** to register new agent, skill, and command

5. **Create `critical-analysis.md` context file** (optional) with attorney critique patterns and severity schema

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Legal fundamentals & error categories | completed | high |
| B | Agent design patterns & command architecture | completed | high |
| C | Critic: gaps, risks, blind spots | completed | high |
| D | Strategic horizons & extension fit | completed | high |

## References

### Legal Sources (Teammate A)
- ABA Model Rule 3.1: Meritorious Claims & Contentions
- ABA Model Rule 3.3: Candor Toward the Tribunal
- ABA Model Rule 3.4: Fairness to Opposing Party
- Federal Rules of Civil Procedure Rule 11
- FRCP Rules 26-37 (Discovery)
- ABA Formal Opinion 512
- IRAC Legal Reasoning Framework
- Stanford HAI peer-reviewed research on legal AI hallucination rates

### System Sources (Teammates B, D)
- Existing founder extension agents (14 agents reviewed)
- Existing founder extension commands (9 commands reviewed)
- Agent template at `.claude/context/templates/agent-template.md`
- Command structure at `.claude/context/formats/command-structure.md`
- Founder extension manifest at `.claude/extensions/founder/manifest.json`
