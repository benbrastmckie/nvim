# Research Report: Task #458 - Teammate C (Critic) Findings

**Task**: Create legal-analysis-agent for critical legal feedback
**Date**: 2026-04-16
**Role**: Teammate C - Critic (gaps, risks, blind spots)
**Focus**: What are we missing? What could go wrong?

---

## Key Findings

### Finding 1: The scope of "thinks like a lawyer" is dangerously underspecified

"Thinks like a lawyer" is marketing language, not an agent specification. Attorneys differ radically by practice area: a patent litigator and a contracts transactional attorney apply entirely different analytical frameworks. The document `legal-ai-example.typ` is a product marketing document for litigation teams -- it makes specific claims about evidence law, discovery, expert testimony, and courtroom procedure. A general "legal critic" agent has no grounding in which legal frameworks apply.

The capability gap is concrete: to critique the document as a litigator would, the agent needs competence in:
- Rules of evidence (what constitutes admissible evidence, foundation requirements)
- Discovery rules (what can and cannot be claimed about discovery processes)
- Expert witness standards (Daubert/Frye and what constitutes qualified expert opinion)
- Legal ethics rules (what an attorney CAN promise to a client, duty of candor requirements)
- Malpractice doctrine ("reasonable care" standards in context)
- Regulatory law (EU AI Act, ABA opinion -- are the representations accurate?)

None of this is specified. An agent definition that just says "critique like an attorney" will produce confident-sounding but ungrounded feedback -- the same hallucination problem the document itself is criticizing.

### Finding 2: We are building on incomplete attorney feedback

The attorney said "There's more but I need time to go through it." We do not know what the attorney actually flagged. We are building an agent to do a job we cannot fully specify because we lack the complete expert input. This creates a real risk: the agent gets built around the partial feedback, the remaining attorney findings arrive later, and they identify issues the agent completely missed or worse, issues the agent's framing actively obscured.

Specific blind spots in the document that an attorney would likely flag (beyond what may have been raised already):

**Legal terminology misuse -- duty of candor:**
The document states (line 544): "This supports the attorney's duty of candor to the tribunal." The duty of candor (Model Rules 3.3) requires attorneys to disclose directly adverse legal authority and not make false statements to a court. Using it as a marketing frame for an AI tool's audit trail fundamentally mischaracterizes the rule. The duty is about what attorneys must NOT hide from judges -- it is not a quality-of-work standard that AI verification satisfies. An attorney reading this will find it legally illiterate.

**Misuse of "formally verified":**
The document repeatedly claims Logos produces "formally verified" conclusions. In computer science and logic, formal verification means mathematical proof of correctness relative to a specification. The document never explains what the formal system is, what the axioms are, or what "verified" means operationally. This is not a legal error per se, but a technical claim that attorneys will immediately probe: "Verified by what method? Against what formal system? What are the completeness and soundness guarantees?" The document cannot answer these questions. If an attorney asks "what does formally verified mean here?" the document's answer is circular.

**"But for" causation framing:**
The document describes a counterfactual causation argument (line 429-431) and then explains why it fails. This is the correct result, but the framing around "but for" causation is imprecise. The document treats counterfactual causation as if it is a discrete logical operation Logos performs. In legal doctrine, "but for" causation is one component of a multi-part causation analysis (factual cause, proximate cause, intervening cause, foreseeability). The document collapses this complexity without flagging it.

**Intentional fraud vs. fraudulent concealment distinction:**
At line 471, the document shifts "the theory from negligence (Theory B) to intentional fraud (Theory A)." In litigation, intentional fraud and fraudulent concealment are distinct causes of action with different elements, different statutes of limitations, and different pleading requirements (Rule 9(b) requires fraud be pled with particularity). The document uses "intentional fraud" loosely to mean "he knew and did it anyway," which an opposing counsel would immediately distinguish from a properly pled fraud claim.

**ABA Formal Opinion 512 characterization:**
The document states (line 631): "The ABA now requires attorneys to perform 'independent verification of all AI-generated outputs.'" This is a simplification that borders on mischaracterization. ABA Opinion 512 addresses competence and supervision obligations -- it does not use the phrase "independent verification of all AI-generated outputs" as a blanket mandate. The specific obligations depend on how AI is used, the jurisdiction's rules, and the nature of the work. Overstating this creates a false urgency.

**Settlement leverage claim:**
The document says (line 603): "You are presenting a proof, not an opinion." This conflates formal logical proof with legal argument. In a settlement negotiation, presenting a logical derivation from evidence does not carry the force of a court order or a mathematical theorem. Opposing counsel is free to dispute the premises, challenge the evidence foundation, or simply decline to settle. Calling it a "proof" in a legal context implies a level of compulsory authority it does not have.

**Malpractice insurance sidebar:**
The document implies (line 641-643) that a Logos audit trail "supports the defensibility of the work product and the insurability of the practice." Whether a specific tool satisfies the "reasonable care" standard in a malpractice claim is a factual and jurisdictional question -- it is not established by the tool's design. An attorney reading this will note that Logos cannot actually promise this; the claim would need to be tested in litigation.

### Finding 3: The boundary with legal-council-agent is not just overlapping -- it is structurally confused

The existing `legal-council-agent` does contract review research through Q&A. The proposed `legal-analysis-agent` does document critique. These sound distinct but share the same underlying capability: applying legal frameworks to assess a document.

The real distinction that needs to be encoded:
- legal-council-agent: User-provided contract, unknown legal issues, structured elicitation to discover what matters to the user
- legal-analysis-agent: Agent-initiated critique, known document type, systematic legal framework applied without user prompting

But this distinction breaks down in practice. If someone wants the legal-analysis-agent to critique a contract, what does it do differently from legal-council-agent? The only principled answer is that legal-analysis-agent applies legal frameworks proactively without asking what the user cares about -- but that makes it LESS useful for contract review, not more.

The agent specification needs a clear exclusion: "This agent does NOT review contracts or provide legal counsel. It critiques documents that make legal claims." If that boundary is not explicit, both agents will be invoked ambiguously and the routing will be unreliable.

### Finding 4: `/critic` is a poor command name for this use case

`/critic` as a command name implies generic critical feedback -- stylistic, argumentative, logical. It does not signal "legal analysis." A user wanting legal critique of a document will not intuit that `/critic --attorney` is the right command.

More specifically:
- `/critic` without flags does what, exactly? Style critique? Logic critique? The base command needs a coherent default behavior.
- The `--attorney` flag implies other flags exist or will exist. What are they? If the command is purely for legal analysis, the flag is redundant. If the command has non-legal uses, the relationship between the base and flagged behavior needs to be specified.
- There is potential confusion with future review-type commands. A `/review` command already exists in this system (for codebase analysis). A `/critic` command that reviews documents is adjacent territory.

A more precise name: `/analyze --legal` or `/critique --legal` or simply a dedicated `/legal-review` command. The name should make the legal purpose unambiguous from the command itself.

### Finding 5: AI cannot actually "think like a lawyer" in the ways that matter most

This is the deepest limitation and the one most likely to produce a misleading agent. The ways a human attorney catches errors in a document like this are not reasoning capabilities an AI reliably has:

- **Jurisdictional sensitivity**: A California attorney and a New York attorney will critique the same malpractice claim differently. An EU attorney will read the AI Act discussion differently from a US attorney. The document targets litigation teams generally -- which jurisdiction's standards apply?
- **Practitioner intuition about what courts actually do**: The claim that "ABA Opinion 512 requires X" can be technically accurate but practically misleading. Experienced attorneys know which requirements are enforced, which are ignored, and which jurisdictions diverge. An AI agent reading the rule text will miss this.
- **Knowledge currency**: Legal opinions, court sanctions statistics, and regulatory enforcement dates are cited specifically (1,174 cases, August 2, 2026). An AI agent may have stale information about these.
- **Knowing what you don't know**: A human attorney reading this document will flag claims they cannot verify and refuse to vouch for them. An AI agent has strong incentives (through training) to produce complete-sounding analysis rather than acknowledging genuine uncertainty.

The agent spec should explicitly constrain what the agent claims to assess: specific legal terminology errors, regulatory mischaracterizations, logical gaps in legal reasoning. It should NOT be framed as comprehensive legal review -- that framing will produce overconfident output.

---

## Recommended Approach

### 1. Narrow the agent scope explicitly

Define the agent as a "legal terminology and claims critic" not a "legal analyst." It checks:
- Whether legal terms are used with their correct doctrinal meaning
- Whether cited legal authorities (rules, opinions, statutes) are characterized accurately
- Whether claims about legal standards hold up to the plain text of those standards
- Whether logical arguments presented as legal arguments are actually valid

It explicitly does NOT:
- Provide jurisdiction-specific legal advice
- Assess overall litigation strategy
- Overlap with contract review (legal-council-agent's domain)

### 2. Complete the attorney review before building the agent

The actual attorney's complete feedback is the ground truth for what legal errors look like in this document type. Building the agent before that feedback arrives means building around a partial specification. At minimum, get the complete attorney feedback first and use it to define the agent's error taxonomy.

### 3. Separate the document fix from the agent build

The immediate practical need is: fix `legal-ai-example.typ`. The longer-term need is: an agent that catches these issues in future documents. These are separate tasks. Conflating them risks building an agent optimized for this document's specific errors rather than a general legal critic capability.

### 4. Specify what "attorney" means in the flag

`--attorney` is ambiguous. The flag should correspond to a specific attorney persona with defined expertise: litigation attorney, transactional attorney, regulatory counsel, etc. Each applies different frameworks. The document in question is a litigation product document -- the relevant persona is a litigator, not a contracts attorney. Make this specific.

### 5. Add an explicit confidence output to the agent

Because the agent will be wrong in ways users cannot easily detect, every critique item should carry an explicit confidence level and a statement of what would be needed to verify the claim. "This characterization of ABA Opinion 512 may be incomplete -- verify against the full opinion text" is more useful than a confident-sounding misstatement.

---

## Evidence / Examples

### Direct quotes from legal-ai-example.typ that are problematic:

1. **Line 544**: "This supports the attorney's duty of candor to the tribunal." -- Duty of candor is Model Rule 3.3, a prohibition on deception, not a quality benchmark for AI outputs.

2. **Line 603**: "You are presenting a proof, not an opinion." -- Legal settlement negotiations involve no such thing as a binding logical proof; opposing counsel has no obligation to accept it.

3. **Line 631**: "The ABA now requires attorneys to perform 'independent verification of all AI-generated outputs.'" -- ABA Opinion 512 addresses competence and supervision; it does not mandate "independent verification of all AI-generated outputs" as a blanket rule. The quote marks around that phrase imply it is a direct citation; it may not be.

4. **Line 629**: "As of Q2 2026, Logos is the only legal AI platform whose architecture natively satisfies these requirements." -- This is a market claim that would need to be substantiated; an attorney reviewing this as a potential client would ask for evidence and would be skeptical of any AI marketing claim of unique regulatory compliance.

5. **Lines 455-471**: The five-step reasoning chain establishing concealment conflates evidentiary analysis with legal conclusions. "Concealment established" as a conclusion from circumstantial evidence does not mean a fraud claim would succeed; it means there is evidence from which a jury could infer concealment. The document presents this as a logical proof when it is actually an evidentiary sufficiency assessment.

### Structural confusion with legal-council-agent:

legal-council-agent (line 10): "Contract review and negotiation counsel agent"
Proposed legal-analysis-agent: Critiques documents that make legal claims

If the document being critiqued IS a contract, the two agents' domains overlap completely. The routing logic must be able to distinguish "contract to be reviewed for the founder's benefit" from "document making legal claims to be assessed for accuracy." This distinction is not obvious and will be ambiguous in practice.

---

## Confidence Level

**Finding 1 (scope underspecified)**: High -- "thinks like a lawyer" is demonstrably not a specification.

**Finding 2 (incomplete attorney feedback)**: High -- the attorney explicitly said there is more to review; we do not have that feedback.

**Finding 3 (boundary with legal-council-agent)**: High -- the overlap is structural, not incidental.

**Finding 4 (command name)**: Medium -- naming is a judgment call, but the ambiguity is real.

**Finding 5 (AI limitations)**: High -- these are known limitations of current LLMs in legal reasoning contexts; the attorney feedback confirms the gap is real.

**Specific document errors identified**: Medium-high -- these are plausible mischaracterizations identifiable from the plain text, but the complete attorney feedback may reframe some of them.
