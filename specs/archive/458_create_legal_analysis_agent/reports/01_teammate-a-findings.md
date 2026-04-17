# Teammate A Findings: Legal Fundamentals for Legal-Analysis-Agent

**Research Angle**: Core legal fundamentals - what an AI agent needs to "think like a lawyer"
**Date**: 2026-04-16

---

## Key Findings

### 1. Arguments Are Not "Found" - They Are Constructed

This is perhaps the most fundamental error an AI can make about legal practice. The attorney feedback is precisely correct:

**The reality**: Party positions are known from Day 1. A client comes to an attorney and says "they breached the contract" or "I was injured by their negligence." The attorney's job is then to:
- **Find EVIDENCE** to support the known position (documents, witnesses, physical evidence)
- **Find LEGAL AUTHORITY** (statutes, case law, regulations) that supports the position
- **Construct ARGUMENTS** by applying that authority to the facts (via IRAC methodology)

An attorney never "discovers arguments" as if they were hidden objects waiting to be found. Arguments are built, constructed, developed, or formulated - based on facts the client provides and law the attorney researches. Saying an AI "found the best arguments" conflates three distinct activities:
- Factual investigation (finding evidence)
- Legal research (finding controlling law)
- Legal reasoning (constructing arguments from those inputs)

**Actionable rule for agent**: Flag any description of legal arguments being "found," "discovered," or "uncovered" as a fundamental conceptual error. Arguments are **constructed** from facts and law; only evidence and legal authority are "found."

### 2. Discovery Is a Strict Term of Art

**The reality**: "Discovery" in legal practice has one precise meaning - the formal pretrial process by which parties compel each other to exchange information. Under Federal Rules of Civil Procedure Rules 26-37, discovery consists of:

| Mechanism | Description |
|-----------|-------------|
| **Interrogatories** | Written questions answered under oath; 25 per party without court permission; 30-day response deadline |
| **Depositions** | Live oral testimony under oath, recorded; used to lock in testimony and assess credibility |
| **Requests for Production (RFP)** | Formal demands for documents, emails, electronically stored information (ESI) |
| **Requests for Admissions (RFA)** | Ask opposing party to admit/deny specific factual statements; admitted facts need no proof at trial |
| **Physical/Mental Examinations** | Court-ordered examinations when a party's condition is at issue |

Discovery happens in the **pretrial phase**, typically lasting 6-12 months. It prevents "trial by ambush" by ensuring both sides have equal access to relevant information before trial.

**What discovery is NOT**:
- A process of "finding what you missed"
- A synonym for "research"
- A general process of investigation
- Something done by a single party unilaterally

**Actionable rule for agent**: The word "discovery" in any legal document should only appear in its term-of-art sense. Flag uses of "discovery" that mean general investigation, research, or finding information as incorrect. The correct substitute is "investigation," "research," "fact-finding," or similar non-technical terms.

### 3. Case Evaluation Happens Long Before Trial - Not During Witness Examination

**The reality**: Attorneys evaluate case strength systematically and continuously from the moment they first speak with a client. "Stress testing" legal arguments is a real practice, but it occurs:
- **Before taking the case**: Initial merit assessment determines whether to accept representation
- **Immediately after engagement**: Attorneys analyze liability, evidence, and legal theory
- **Throughout pretrial preparation**: Arguments are refined as discovery produces new information
- **Before filing**: Rule 11 requires reasonable prefiling investigation

Key case evaluation factors before acceptance:
1. **Legal merit**: Are there valid legal grounds? Does controlling law support the position?
2. **Factual foundation**: Does evidence exist (or is it obtainable through discovery)?
3. **Risk assessment**: What are the opposing arguments? What counterclaims are possible?
4. **Financial viability**: Can the client afford litigation? Can the opponent pay a judgment?
5. **Ethical clearance**: No conflicts of interest, attorney competence in the area

**What does NOT happen**: Attorneys do not accept cases on hunches and then "stress test" arguments against witnesses at trial. Witness cross-examination serves a different purpose: to challenge opposing witnesses' credibility, lock in testimony, and advance your own narrative. An attorney "never asks a question to which he does not know the answer" - meaning trial examination is controlled, not exploratory.

**Actionable rule for agent**: Descriptions of case evaluation or argument stress-testing should be placed in pretrial/pre-filing context, not in the context of witness examination. Flag any description of argument evaluation that treats the trial itself as a discovery or evaluation mechanism.

### 4. Duty of Candor - Comprehensive Ethical Obligations

**ABA Model Rule 3.3 - Candor Toward the Tribunal** creates absolute prohibitions:

A lawyer **shall not knowingly**:
1. Make a **false statement of fact or law** to a tribunal, or fail to correct a previously made false statement
2. **Offer evidence the lawyer knows to be false** (including testimony from witnesses)
3. **Fail to disclose adverse controlling authority** in the controlling jurisdiction that has not been disclosed by opposing counsel

The duty of candor is **not optional and cannot be waived by client instruction**. If a client insists on a false position, the attorney must withdraw. These duties continue through the conclusion of proceedings and override attorney-client confidentiality obligations (Rule 1.6) when necessary.

**ABA Model Rule 3.4 - Fairness to Opposing Party** prohibits:
- Unlawfully obstructing access to evidence
- Falsifying evidence or inducing witnesses to give false testimony
- Making frivolous discovery requests or failing to comply with discovery obligations

**Actionable rule for agent**: Any description of legal AI that implies attorneys can selectively hide unfavorable law, make strategic false statements, or choose whether to follow candor rules is fundamentally wrong. The duty of candor is a bright-line rule, not a sliding scale. Flag this immediately.

### 5. Meritorious vs. Frivolous Claims - Rule 3.1 and Rule 11

**ABA Model Rule 3.1** prohibits bringing proceedings unless there is "a basis in law and fact... that is not frivolous." An argument is meritorious if:
- There is a good faith factual basis (supported by evidence)
- There is a good faith legal basis (existing law, or good faith argument for extension/modification of law)
- The attorney has conducted reasonable pre-filing investigation

**Federal Rule 11** independently requires attorney certification that:
- Every filing is not made for improper purposes (harassment, delay, needless cost)
- Legal contentions are **warranted by existing law** or a nonfrivolous argument for extending/modifying law
- Factual contentions have **evidentiary support** or will likely have such support after reasonable discovery opportunity

**Critical nuance**: A case is not frivolous merely because:
- Facts are not yet fully substantiated (some evidence will come through discovery)
- The attorney expects to develop vital evidence through discovery
- The attorney believes the client's position will ultimately not prevail

A case IS frivolous if the attorney cannot make any good faith argument on the merits.

**Actionable rule for agent**: "Meritorious" is defined by facts and law - it is not a quality check that happens at filing like catching a typo. There is no "big reveal" moment where arguments are evaluated. Merit assessment is ongoing, professional, and based on legal standards. Flag any description that treats legal merit as a surprise discovery or a last-minute check.

### 6. Legal Reasoning Methodology - IRAC

How lawyers actually "think like a lawyer":

**IRAC framework** (the foundational method taught in law school and used in practice):
- **Issue**: Identify the precise legal question raised by the facts
- **Rule**: State the applicable law (statute, regulation, case law, common law principle)
- **Application**: Apply the rule to the specific facts of the case
- **Conclusion**: State the outcome the analysis supports

This framework is used for:
- Legal memoranda (internal case analysis)
- Briefs (arguments to courts)
- Judicial opinions (how judges decide cases)
- Client advice letters

Variants include CRAC (Conclusion-Rule-Application-Conclusion) and CREAC (Conclusion-Rule-Explanation-Application-Conclusion). All share the same core: **start with the legal question, identify governing law, apply law to facts, reach a conclusion.**

**Actionable rule for agent**: Arguments in legal documents should follow IRAC logic. Flag arguments that state conclusions without identifying the governing rule, or that apply facts to no identifiable legal standard. The rule always comes from an authoritative source - statute, case law, regulation - not from general principles.

### 7. The Adversarial System and Attorney Role

Attorneys are advocates, not investigators or truth-seekers in the neutral sense. The adversarial system is premised on:
- Each side presents its strongest version of the facts and law
- The court/jury decides between competing presentations
- The opposing party presents the counterargument

This means:
- Attorneys **zealously advocate** for client positions
- They are **not obligated to present both sides** (except adverse controlling authority under Rule 3.3)
- They can argue positions they personally disagree with
- They **may not knowingly lie** but can challenge, test, and question everything

**Actionable rule for agent**: Legal documents should reflect partisan advocacy within ethical bounds. An attorney arguing for a client is not "balanced" - they argue one side. However, they cannot fabricate law or facts. This is the distinction: **zealous advocacy within the bounds of honesty.**

---

## Recommended Approach for Legal-Analysis-Agent

The agent's system prompt should encode these principles as **critical error categories** to detect:

### Category 1: Terminology Errors
- "Discovery" used in any sense other than compelled pretrial exchange of information
- "Finding arguments" rather than constructing/building/developing arguments
- "Uncovering" or "revealing" legal positions that were known from the start

### Category 2: Process/Timeline Errors
- Case evaluation described as occurring at trial rather than pretrial
- Argument "stress testing" framed as witness examination rather than preparation
- Merit assessment described as a last-minute filing check rather than ongoing analysis
- Attorneys "accepting cases on hunches" without pre-evaluation

### Category 3: Ethical Accuracy Errors
- Implying candor obligations are optional or strategic
- Describing attorneys as choosing whether to disclose adverse authority
- Suggesting attorneys can make knowingly false statements for strategic purposes
- Describing Rule 11 compliance as optional or catch-as-catch-can

### Category 4: Reasoning Framework Errors
- Conclusions stated without governing legal rules
- "Arguments" that are mere assertions rather than law-applied-to-facts
- Legal analysis that doesn't distinguish between facts and law
- Treating legal positions as discovered rather than constructed

### Category 5: Role Confusion Errors
- Treating attorneys as neutral investigators
- Describing attorneys as seeking "truth" rather than advocating positions
- Confusing the attorney's role with the judge's role
- Suggesting attorneys must present opposing arguments

---

## Evidence/Examples

### Concrete Errors from Attorney Feedback

**Error 1**: "The AI found the best arguments for your case"
- **Problem**: Arguments are not found. The client's position is known ("I was not negligent"). Arguments are constructed by: (a) gathering facts/evidence, (b) researching controlling law, (c) applying law to facts via IRAC.
- **Corrected**: "The AI researched controlling legal authority and constructed arguments based on the facts of your case"

**Error 2**: "The discovery process helped reveal what was missed"
- **Problem**: Discovery is a term of art meaning compelled exchange between parties. It does not mean "finding things."
- **Corrected**: "The investigation revealed additional evidence" or "The pretrial research identified additional issues"

**Error 3**: "Arguments are stress-tested against witnesses at examination"
- **Problem**: Cases are evaluated before trial, before filing, and continuously throughout pretrial. Witness examination tests witness credibility, not argument validity.
- **Corrected**: "Arguments are evaluated during pretrial case assessment" or "Argument strength is assessed through research, mock arguments, and consultation"

**Error 4**: "The AI catches frivolous arguments before filing - like a grammar checker"
- **Problem**: There is no "big reveal" or catching mechanism at filing. Merit is an ongoing professional judgment, not a quality control checkpoint.
- **Corrected**: "The AI assists attorneys in evaluating whether arguments satisfy the good faith basis required under Rule 3.1 and Rule 11"

---

## Confidence Level: High

The legal principles researched here are well-established, codified in the ABA Model Rules of Professional Conduct, and reinforced by Federal Rules of Civil Procedure. The attorney feedback aligns precisely with these foundational principles. Sources include:
- ABA Model Rules (Rules 3.1, 3.3, 3.4)
- Federal Rules of Civil Procedure Rule 11
- IRAC methodology (foundational law school/bar exam curriculum)
- Legal practice guides on discovery, case evaluation, and trial preparation

The confidence is high because these are not evolving areas of law - they reflect core, established principles of legal ethics and procedure that have been stable for decades.

---

## Sources Consulted

- [Rule 3.1: Meritorious Claims & Contentions - ABA](https://www.americanbar.org/groups/professional_responsibility/publications/model_rules_of_professional_conduct/rule_3_1_meritorious_claims_contentions/)
- [Rule 3.3: Candor Toward the Tribunal - ABA](https://www.americanbar.org/groups/professional_responsibility/publications/model_rules_of_professional_conduct/rule_3_3_candor_toward_the_tribunal/)
- [Rule 11 - Federal Rules of Civil Procedure - LII Cornell](https://www.law.cornell.edu/rules/frcp/rule_11)
- [Discovery (law) - Wikipedia](https://en.wikipedia.org/wiki/Discovery_(law))
- [Legal Discovery Explained: Process & Rules - Spellbook](https://www.spellbook.legal/briefs/legal-discovery)
- [IRAC - Legal Reasoning - ABA](https://www.americanbar.org/groups/law_students/resources/student-lawyer/student-essentials/legal-reasoning-its-all-about-irac/)
- [Ultimate Guide to ABA Model Rule 3.1 - Number Analytics](https://www.numberanalytics.com/blog/ultimate-guide-aba-model-rule-3-1)
- [Litigation Stress Testing - Alan Ripka](https://alanripka.com/litigation-stress-testing-how-attorneys-pressure-test-cases-before-trial/)
- [Duty to Disclose Adverse Legal Authority - ABA Journal](https://www.abajournal.com/magazine/article/duty-to-disclose-adverse-legal-authority)
- [How Attorneys Evaluate Your Legal Matter - Mallon Lonnquist](https://mallon-lonnquist.com/blog/how-attorneys-evaluate-your-legal-matter/)
- [AI Hallucinations in Legal Practice - Stanford HAI](https://hai.stanford.edu/news/ai-trial-legal-models-hallucinate-1-out-6-or-more-benchmarking-queries)
- [Reasonable Prefiling Investigation - Rule 11 - Finnegan](https://www.finnegan.com/en/insights/articles/reasonable-prefiling-investigation-and-the-test-for-rule-11-the.html)
