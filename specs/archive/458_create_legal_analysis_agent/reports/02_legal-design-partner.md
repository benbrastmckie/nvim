# Research Report: Task #458 (Round 2)

**Task**: 458 - Create legal-analysis-agent
**Started**: 2026-04-16T12:00:00Z
**Completed**: 2026-04-16T12:15:00Z
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**:
- Round 1 team research (4 teammates): `specs/458_create_legal_analysis_agent/reports/01_team-research.md`
- Product document: `/home/benjamin/Projects/Logos/Vision/shared/strategy/03-applications/legal-ai-example.typ`
- Existing agent: `.claude/extensions/founder/agents/legal-council-agent.md`
- Existing agents: analyze-agent.md, strategy-agent.md (pattern references)
- Web research: Stanford Legal Design Lab, IE Design Thinking + Legal Services, arxiv legal reasoning challenges, attorney perspectives on legal AI
**Artifacts**:
- `specs/458_create_legal_analysis_agent/reports/02_legal-design-partner.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Round 1 framed the agent as an adversarial critic that finds errors. The user's reframing shifts it to a **collaborative design partner** that embodies legal thinking to improve product descriptions.
- The core capability is not "what's wrong with this document" but "here is how an attorney would understand what you wrote, and here is how to say it so attorneys recognize what you mean."
- The agent should use a **translation model**: user states what the product does, the agent translates into terms attorneys recognize, then identifies where the document's language diverges from that translation.
- The `/critic` command name is wrong for this purpose. The agent should be invoked via a new command or flag that signals collaborative consultation, not adversarial critique.
- The agent's five error categories from Round 1 remain valid but should be reframed as **translation gaps** rather than mistakes -- the document describes real capabilities but uses the wrong professional vocabulary to convey them.
- The agent needs domain knowledge about how attorneys actually think, organized around reasoning modes (IRAC, case evaluation, evidence-based reasoning) rather than error taxonomies.

## Context & Scope

### What Changed Between Round 1 and Round 2

Round 1 treated the task as "build an agent that finds legal errors in documents." The user clarified that the agent's purpose is fundamentally different:

> "A design partner who embodies legal ways of thinking... helps construct and refine the user's Legal AI system design... a collaborator who can say 'attorneys don't think about it that way' and suggest how to reframe."

This changes the agent from a **critic** to a **consultant**. The difference is not cosmetic:

| Dimension | Critic (Round 1) | Design Partner (Round 2) |
|-----------|-------------------|--------------------------|
| Posture | Adversarial: assume problems exist | Collaborative: understand intent, improve expression |
| Input model | Document provided for review | Ongoing dialogue about product design |
| Output model | Structured critique with severity ratings | Reframing suggestions with attorney perspective |
| Question style | 1 clarifying question max | Socratic dialogue to understand what the product actually does |
| Success metric | All errors found | Product description that attorneys recognize as accurate |
| Relationship | One-shot review | Ongoing design partnership |

### The Product Being Designed

The document `legal-ai-example.typ` describes Logos Legal AI, a formally verified legal reasoning system. It is a sales/marketing document targeting litigation partners. The document's core claims:

1. Logos encodes complete case representations (facts, disputes, evidence, timeline)
2. Logos reasons from representations to conclusions via auditable logical steps
3. Logos constructs and compares competing theories of the case
4. Logos provides counterfactual, causal, temporal, epistemic, normative, and probabilistic reasoning
5. Every conclusion is formally verified with transparent proof chains

The attorney feedback showed these claims are not wrong in substance -- they describe genuine capabilities -- but they use legal concepts incorrectly, creating a disconnect between what attorneys read and what the product does.

### Boundary with legal-council-agent

The legal-council-agent reviews **incoming contracts the user receives**. It uses forcing questions to extract contract context and produces risk assessments. Its domain is "help me understand this contract."

The legal-analysis-agent reviews **outgoing materials the user produces** -- specifically, product descriptions, marketing materials, and design documents for a legal AI system. Its domain is "help me describe my product in ways that align with how attorneys think."

There is no overlap. They operate on different inputs, in different directions, for different purposes.

## Findings

### How Attorneys Actually Think (Design-Relevant Patterns)

Research confirms five reasoning patterns that the agent must internalize -- not to detect errors, but to serve as a translation layer between product capabilities and attorney expectations.

**1. Reasoning by example and analogy, not from first principles.**
Attorneys reason from case to case. They classify new situations by comparing them to prior cases. A product that claims to "reason from first principles" or "prove conclusions" must explain how its outputs relate to the way attorneys actually build arguments -- through precedent, analogy, and application of rules to facts (IRAC). The agent should ask: "When you say Logos 'proves' X, what is the analogous process in legal practice? How would an attorney arrive at the same conclusion?"

**2. Evidence is evaluated, not verified.**
Attorneys assess evidence by weighing credibility, relevance, and sufficiency against a burden of proof. They do not "verify" evidence in a mathematical sense. The document's repeated use of "formally verified" describes a real capability but uses language that does not map to any process attorneys recognize. The agent should help reframe: "What attorneys do is evaluate whether evidence meets a standard (preponderance, clear and convincing, beyond reasonable doubt). How does Logos's verification relate to that evaluation process?"

**3. Judgment is discretionary, not algorithmic.**
Legal reasoning involves open-textured terms ("reasonable," "material," "good faith") that require contextual judgment. Research from arxiv confirms that "the probabilistic nature of LLMs conflicts with law's principled, choice-driven nature." The same applies to formally verified systems -- attorneys need to understand where Logos exercises judgment-like functions and where it defers to the attorney. The agent should probe: "Where in this description are you claiming Logos makes judgments that attorneys would expect to make themselves?"

**4. The task is not the job.**
Attorney at Work research emphasizes that legal work is not a sequence of discrete tasks but an integrated practice of "helping clients make decisions under conditions of risk, uncertainty, time pressure and incomplete facts." Product descriptions that decompose legal work into tasks (upload, assess, discover, prepare, report) risk presenting the tool as a replacement for professional judgment rather than a support for it. The agent should flag: "This five-phase workflow reads as if Logos does the lawyer's job. How do you make clear that attorneys direct the process?"

**5. Arguments are constructed through professional judgment, not discovered by analysis.**
This was identified in Round 1 but its design implication is now clearer. When the document says Logos "finds" arguments or "discovers" concealment, it implies the tool does work that attorneys consider the core of their professional identity -- the exercise of judgment in constructing a theory of the case. The agent should reframe: "Attorneys construct theories. Logos provides the evidential foundation and reasoning infrastructure that supports that construction. How can the description honor that distinction?"

### Legal Design Thinking Frameworks

Research into legal design thinking (Stanford Legal Design Lab, IE Business School) reveals principles directly applicable to the agent's design:

**Human-centered, not system-centered.** Legal design starts from the user's (attorney's) perspective and works backward to the technology. The agent should embody this: begin with "what does the attorney need to do?" and then ask "how does the product support that?"

**Emotional resonance alongside utility.** Legal design practitioners note that "teams should discuss the emotional resonance of a value proposition as much as they discuss utility." Attorneys have deep professional identity tied to their reasoning skills. Product descriptions that inadvertently diminish that identity (by claiming the tool "does" what attorneys do) will generate resistance even if the claims are technically accurate.

**Iterative and collaborative.** Design thinking is "non-linear and ongoing." The agent should not produce a one-shot critique but engage in iterative refinement -- understanding what the user intends to convey, offering a legal-professional perspective, and helping refine the language together.

### Common Legal AI Product Misrepresentations

Web research surfaces five patterns that legal AI products commonly get wrong when describing their capabilities to attorneys:

1. **Claiming to replace judgment.** Attorneys value the tool that helps them exercise better judgment, not the tool that exercises judgment for them. "AI excels at handling repetitive legal tasks; human lawyers bring essential empathy, strategic thinking, and ethical decision-making."

2. **Task decomposition without professional context.** Describing legal work as a pipeline of discrete operations (retrieve, analyze, draft) misses that attorneys work holistically -- "the job itself is broader than the tasks."

3. **Verification language that does not map to legal standards.** "Formally verified" is meaningful in computer science but maps to no recognized legal standard. Attorneys verify by checking citations, reading the underlying authority, and exercising judgment about applicability.

4. **Overstating completeness.** Claims like "complete case representation" or "all inferences" trigger skepticism from practitioners who know that legal cases are inherently incomplete and evolving.

5. **Speed as the primary value proposition.** Research shows "faster is not the same as better" and that "the time saved generating drafts is consumed verifying them." Attorneys want accuracy and reliability, not speed.

### Specific Document Translation Opportunities

Applying the design partner lens to `legal-ai-example.typ`, the following are not "errors" but **translation opportunities** -- places where the document describes genuine capabilities using language that attorneys would interpret differently:

| Document Language | Attorney Reading | Design Partner Reframing |
|---|---|---|
| "find the argument" (line 327) | Arguments are constructed, not found | "surface the evidence and reasoning that supports constructing..." |
| "discovery" (section headers, lines 428, 436) | Formal pretrial process (FRCP 26-37) | Use "analysis" or "investigation" when meaning Logos's analytical process |
| "formally verified" (throughout) | No legal equivalent; triggers "prove what?" | "auditable reasoning chain" or "transparent logical steps that can be inspected" |
| "concealment established" (line 465) | Legal conclusion requiring elements under specific doctrine | "evidence consistent with deliberate concealment" -- frame as evidentiary assessment, not legal conclusion |
| "proof, not an opinion" (line 603) | Opposing counsel has no obligation to accept any proof | "documented reasoning grounded in specific evidence" |
| "duty of candor" as quality benchmark (line 544) | Rule 3.3 is a prohibition on deception, not a work-quality standard | Frame as: "supports the attorney's ability to comply with disclosure obligations" |
| Five-phase workflow (sections 1-5) | Reads as if Logos does the lawyer's job | Reframe each phase as attorney-directed with Logos as infrastructure |
| "ABA now requires" (line 631) | May mischaracterize Opinion 512's scope | Verify exact language; frame as "consistent with the competence obligations Opinion 512 addresses" |

### Agent Design: From Critic to Design Partner

The agent should be structured around a **translation and reframing** workflow rather than an error-detection workflow:

**Step 1: Understand intent.** Ask what the user is trying to convey to attorneys. Do not assume the document is wrong -- assume it describes something real but in the wrong professional vocabulary.

**Step 2: Translate to attorney perspective.** For each claim or description, articulate how an attorney would interpret the language. Identify where the attorney's interpretation diverges from the user's intent.

**Step 3: Suggest reframing.** Offer alternative language that preserves the product's actual capabilities while using vocabulary attorneys recognize. Explain why the reframing matters.

**Step 4: Probe deeper.** Ask follow-up questions about what the product actually does in the areas where translation is most difficult. Sometimes the disconnect reveals genuine design questions, not just language issues.

**Step 5: Validate consistency.** Check that reframed language is internally consistent across the document and does not introduce new inaccuracies.

### Command Design: Not /critic

The `/critic` command name signals adversarial review. The user's reframing calls for collaborative consultation. Three options:

**Option A: New command `/consult --legal`**
- Aligns with the "design partner" metaphor
- `--legal` flag signals the domain; future flags (`--technical`, `--investor`) provide the same extensibility Round 1 proposed for `/critic`
- Downside: "consult" is generic

**Option B: New flag on existing `/review` command: `/review --legal`**
- Leverages existing command infrastructure
- Downside: `/review` is currently a codebase review tool with different semantics

**Option C: Dedicated `/attorney` command**
- Clear, unambiguous signal
- No flag dispatching needed for Phase 1
- Extensible later via modes (as `/legal` uses REVIEW/NEGOTIATE/TERMS/DILIGENCE)
- Downside: may be confused with `/legal`

**Recommendation: Option A (`/consult --legal`).** This is the most extensible and accurately describes the interaction pattern. The `--legal` flag routes to `legal-analysis-agent`. Future flags route to other design-partner agents (investor perspective, technical architecture review, etc.). The command name "consult" correctly frames the interaction as collaborative rather than adversarial.

However, if the user prefers the adversarial `/critic` framing from Round 1, the agent design should still work -- it would simply shift tone from "let me help you say this better" to "here is what an attorney would challenge." The underlying knowledge and reframing capabilities are identical.

## Decisions

1. **Agent purpose**: Design partner that embodies legal thinking for product design feedback, not an error-detection critic
2. **Interaction model**: Socratic dialogue (understand intent, translate, reframe) rather than one-shot structured critique
3. **Error categories retained but reframed**: Round 1's five categories become "translation gap categories" rather than error types
4. **Command recommendation**: `/consult --legal` over `/critic --attorney`, pending user preference
5. **No overlap with legal-council-agent**: Different inputs (outgoing vs. incoming), different purposes (product design vs. contract review)

## Recommendations

1. **Create `legal-analysis-agent.md`** with:
   - Design partner posture: collaborative, Socratic, iterative
   - Legal reasoning knowledge: IRAC, case-based reasoning, evidence evaluation, burden of proof, professional judgment
   - Translation workflow: understand intent -> attorney perspective -> reframe -> probe -> validate
   - Five translation gap categories (adapted from Round 1's error categories)
   - Input: file path to document, description of product capability, or design question
   - Output: reframing suggestions with attorney perspective explanations, follow-up questions
   - `model: opus` for depth of legal reasoning
   - Context references: legal-frameworks.md (reuse from legal-council), new legal-reasoning-patterns.md

2. **Create command** (name TBD pending user preference) with:
   - Collaborative consultation posture
   - Flag-based domain routing (legal for Phase 1)
   - Input types: file path, inline text, or task number
   - Iterative dialogue support (not one-shot)
   - No task pipeline requirement (standalone immediate-mode)

3. **Create `legal-reasoning-patterns.md` context file** containing:
   - How attorneys reason (IRAC, analogy, precedent)
   - How attorneys evaluate evidence (burden of proof, credibility, sufficiency)
   - How attorneys construct arguments (theory of the case, narrative)
   - Common vocabulary mismatches between technical and legal descriptions
   - The five translation gap categories with detection heuristics

4. **Update `manifest.json`** to register new agent, skill, and command

5. **Defer multi-flag framework** to future tasks. Phase 1 builds only the legal design partner mode.

## Risks & Mitigations

- **Risk**: Agent becomes a generic "rewrite my text" tool without genuine legal reasoning depth.
  **Mitigation**: Ground agent in specific legal reasoning frameworks (IRAC, evidence evaluation, burden of proof) and require it to explain *why* attorneys would read something differently, not just suggest alternative text.

- **Risk**: User expects the agent to catch all legal inaccuracies, but it is an AI simulating legal thinking, not an attorney.
  **Mitigation**: Agent should explicitly state it models how attorneys think but does not replace attorney review. Include confidence levels and verification suggestions.

- **Risk**: Overlap confusion with legal-council-agent for users who do not read the distinction.
  **Mitigation**: Clear scope statement in agent metadata. `/legal` help text should reference the distinction.

- **Risk**: Command naming bikeshed delays implementation.
  **Mitigation**: Implement as `/consult --legal` with clear documentation that the command name can be changed. Focus on agent quality, not command naming.

## Appendix

### Search Queries Used
- "legal design thinking legal technology product development consulting framework 2025 2026"
- "what attorneys actually want from legal AI tools common misrepresentations legal tech 2025 2026"
- "legal technology consultant how attorneys think reason evaluate cases design partner approach"
- "IRAC legal reasoning framework applied to product design legal AI system evaluation"
- "legal design design partner law firm collaboration product development user-centered attorney workflow"
- "attorney perspective legal AI product description mistakes how lawyers actually work legal tech gap reality"

### Web Sources Consulted
- [Stanford Legal Design Lab](https://www.legaltechdesign.com/) - Human-centered legal design methodology
- [IE Insights: Design Thinking + Legal Services](https://www.ie.edu/insights/articles/design-thinking-legal-services/) - Design thinking frameworks for legal
- [Challenges for Generative AI in Legal Reasoning (arxiv)](https://arxiv.org/html/2508.18880v2) - Structural gaps between AI and legal reasoning
- [AI in Law Practice: The Task Is Not the Job (Attorney at Work)](https://www.attorneyatwork.com/ai-in-law-practice-the-task-is-not-the-job/) - Attorney perspective on task decomposition
- [Legal AI Unfiltered (National Law Review)](https://natlawreview.com/article/legal-ai-unfiltered-16-tech-leaders-ai-replacing-lawyers-billable-hour-and) - Attorney expectations from legal AI
- [ABA: Top Six AI Legal Issues](https://www.americanbar.org/groups/law_practice/resources/law-technology-today/2025/ai-legal-issues-and-concerns-for-legal-practitioners/) - Professional concerns about AI in law
- [NPR: Penalties stack up as AI spreads through the legal system](https://www.npr.org/2026/04/03/nx-s1-5761454/penalties-stack-up-ai-spreads-through-legal-system) - AI hallucination sanctions landscape
- [Treehouse Innovation: Design thinking for law firms](https://treehouseinnovation.com/legal-transformation-practice/) - Human-centered design in legal transformation

### Codebase Files Examined
- `specs/458_create_legal_analysis_agent/reports/01_team-research.md` (Round 1 synthesis)
- `specs/458_create_legal_analysis_agent/reports/01_teammate-{a,b,c,d}-findings.md` (Round 1 teammate reports)
- `/home/benjamin/Projects/Logos/Vision/shared/strategy/03-applications/legal-ai-example.typ` (target document)
- `.claude/extensions/founder/agents/legal-council-agent.md` (boundary agent)
- `.claude/extensions/founder/agents/analyze-agent.md` (agent pattern reference)
- `.claude/extensions/founder/agents/strategy-agent.md` (agent pattern reference)
- `.claude/extensions/founder/commands/legal.md` (existing legal command)
- `specs/ROADMAP.md` (project roadmap)
