# Teammate D (Horizons): Strategic Findings
# Task 392: Refactor Present Extension Commands

**Artifact**: 02_teammate-d-findings.md
**Teammate**: D (Horizons - Strategic Alignment and Vision)
**Date**: 2026-04-09
**Focus**: Long-term direction, creative approaches, cohesive product vision

---

## Key Findings

### 1. The Present Extension Is a Hidden Gem

After reading all five commands, the forcing-question context files, the talk library (45+ slide content templates, Vue components, two themes), and the grant domain knowledge files, the present extension is clearly the most domain-rich extension in the system. It has:

- A complete academic talk authoring system (5 modes, 45+ content templates, custom Vue components, 2 themes)
- A structured grant development workflow (budget forcing questions, narrative patterns, evaluation plans)
- A sophisticated multi-mode funding analysis framework (LANDSCAPE/PORTFOLIO/JUSTIFY/GAP)
- Timeline support for research project planning

But this richness is invisible. The five commands feel like five separate tools that happen to live in the same directory. No shared identity. No unified entry point. No cross-command awareness.

### 2. The `{extension}:{command}` Format Is the Right Vision

The task description mentions "task type designated by `{extension}:{command}` format." This is significant. It points toward a unified `present:grant`, `present:talk` identity where all five commands share:

- A common namespace (`present:`)
- Consistent interaction patterns (forcing questions -> task creation -> workflow)
- Cross-pollination (a grant task can seed a talk task; a funds analysis informs a budget)

Currently, the manifest routing already uses this format (`present:grant`, `present:budget`, etc.), but the commands themselves don't reflect it. The refactor is the opportunity to make the commands feel like they belong to the same product.

### 3. The Forcing-Question Framework Is the Core UX Pattern

The best commands here (budget, funds, talk) all use the same arc:
1. Ask essential questions before task creation
2. Store answers as `forcing_data` in task metadata
3. Resume later without re-asking

This is a strong pattern. It separates "intake" from "execution," keeps context persistent, and enables intelligent re-use. The two outliers are:

- **grant**: Has no pre-task forcing questions (just creates the task; questions happen in --draft and --budget modes). This means the task is created with minimal context.
- **timeline**: Has forcing questions, but runs them AFTER task creation (in the research stage), defeating the benefit of storing them pre-task.

The refactor should bring both into alignment.

### 4. /grant's Design Confirms Its Distinct Purpose

The grant command is legitimately different from the others. It's not just "create task, then research." It's a multi-phase authoring environment:
- `--draft`: Exploratory narrative drafting
- `--budget`: Budget development
- `--revise`: Revision task creation
- `--fix-it`: Scan for embedded tags

This complexity is appropriate for a grant, which spans months and multiple iterative cycles. But the lack of a Stage 0 pre-task intake is a gap. The user invokes `/grant "my project"` and gets a bare task with no stored context. Compare to `/funds "my project"` which asks 5 targeted questions and stores them.

**The fix**: Add pre-task forcing questions to `/grant` that gather the most critical intake:
- Funding mechanism (R01, R21, K-series...)
- Funder (NIH, NSF, Foundation...)
- Submission deadline
- Key specific aims (1-3 sentences)

This stored context would be available to every subsequent `--draft` and `--budget` invocation without re-asking.

### 5. /talk's Stage 0 Is Good but Missing Design Confirmation

The task description specifically calls out: "/talk: Plan agent presents choices of themes, content, and order to confirm design BEFORE proposing a plan."

Currently, `/talk` Stage 0 asks:
1. Talk type (CONFERENCE, SEMINAR, etc.)
2. Source materials
3. Audience context

This is good intake but it doesn't present choices. It asks "what do you need" rather than "here's what we're thinking, do you agree." The design confirmation step is missing.

**The vision**: After gathering source materials, the talk agent should:
1. Analyze available materials (file content, referenced tasks)
2. Propose a slide order and section emphasis based on talk type + content + audience
3. Offer theme choices (academic-clean vs clinical-teal, with brief description of each)
4. Ask: "Does this structure work? Any sections to expand, compress, or reorder?"

This transforms `/talk` from "tell us what you want" to "here's a draft plan - refine it." Much higher quality output.

### 6. /grant's Interactive Intake Is a Strategic Advantage

The task description calls out: "/grant: Begin with interactive questions to gather information, paths to content, regulatory materials, grant guidelines."

This is the right move. Currently `/grant` creates a bare task. Adding pre-task intake that specifically asks for:
- Path to specific aims page (if exists)
- Path to prior submission (if revision)
- Funder guidelines URL or document path
- Regulatory context (IRB requirements, vertebrate animals, human subjects)
- Key collaborators and sub-awardees

...would let the grant agent arrive at the first `--draft` session fully briefed. This is analogous to how a human research administrator would conduct an intake meeting before starting to write.

---

## Strategic Recommendations

### 1. Treat This Refactor as a Product Cohesion Milestone

The mechanical fixes (language unification, model normalization, Co-Authored-By) are necessary but not sufficient. The real opportunity here is to make these five commands feel like a cohesive suite. Concrete ways to express this:

- **Consistent Stage 0**: All five commands should have pre-task forcing questions. The questions differ by domain, but the arc is identical.
- **Cross-command linking**: When creating a talk task, offer to link to an existing grant task ("Should this talk draw from an existing grant? If so, task #?"). When creating a budget task, offer to link to a grant task.
- **Shared vocabulary in output**: All commands should use consistent output headers (`[Grant]`, `[Budget]`, `[Talk]`, etc.) and consistent "Next Steps" format.

### 2. Add Grant Intake as the Highest-Value Enhancement

Of all the creative proposals here, adding pre-task forcing questions to `/grant` delivers the most value per line of code. Currently the grant command is also the most complex and the most used (it's the original command the others were modeled after). Bringing it to the same intake quality as `/funds` and `/budget` closes the biggest UX gap.

### 3. Implement Design Confirmation for /talk

The design confirmation step is a creative differentiator. Academic researchers presenting their work often struggle with structure and emphasis. Having the system propose a slide order—and ask for confirmation before building—is qualitatively different from just executing instructions. This is the feature most likely to generate "wow this is actually useful" moments.

Implementation sketch:
```
Stage 0.4 (new): Design Proposal
After gathering source materials and audience context, agent analyzes and proposes:

"Based on your [CONFERENCE] talk for [computational biology] audience with [15 min limit]:

Proposed structure:
1. Title (1 slide)
2. Clinical motivation - gap framing (2 slides)
3. Methods overview (2 slides)
4. Primary results: survival curves (2 slides)
5. Secondary results: subgroup analysis (1 slide)
6. Discussion and limitations (2 slides)
7. Conclusions (1 slide)
8. Acknowledgments/questions (1 slide)

Proposed theme: academic-clean (formal, high contrast, suitable for projectors)

Does this work? What would you change?"
```

### 4. Enable Progressive Context Disclosure

Currently each command is stateless at invocation. The forcing_data pattern starts to address this, but it could go further. Consider:

- When `/grant N --draft` is invoked, load and display the forcing_data gathered at task creation: "Working from: R01, NIH NIGMS, submitted Feb 2027, aims focused on protein folding. Proceed?"
- When `/talk N` is invoked (task number), summarize the source materials and design confirmation already stored.

This is "progressive context disclosure" -- the system accumulates knowledge and confirms its understanding at each step rather than silently proceeding.

### 5. Unified Utility: The Forcing-Question Framework

The budget, funds, and timeline commands all have domain-specific forcing question frameworks documented in separate context files. These frameworks share a common structure:
- One question at a time
- Push-back patterns for vague answers
- Data quality assessment
- Mode-specific question routing

This pattern could be extracted as a shared `forcing-question-framework.md` context file that all present commands reference. Not a code abstraction—a documentation pattern. Each command's questions are still domain-specific, but the framework (quality assessment rubric, push-back patterns, abandonment handling) is shared.

---

## Creative Proposals

### A. The "Talk Architect" Mode for /talk

Instead of presenting one proposed structure, offer two alternatives:
- **Approach A**: Methods-forward (show how before what was found)
- **Approach B**: Results-forward (lead with impact, reveal methods as needed)

Let the user choose. This mirrors how experienced scientific communicators think about structure. Different audiences (basic scientists vs clinicians) prefer different arcs.

### B. Grant-to-Talk Pipeline

Allow `/talk` to accept `task:N` as a source material where task N is a grant task. The talk agent would read the grant's draft narratives, aims, and research context to synthesize a talk that presents the grant's science. This makes the two commands genuinely synergistic.

Example: `/talk "Presentation of my R01 results" → source_materials: ["task:400"]` would pull from task 400's grant drafts, reports, and aims to build a talk.

### C. Funder-Type Detection for /grant

When the user provides a funder URL or document path during pre-task intake, the grant agent could detect the funder type and pre-populate the funder category (NIH, NSF, Foundation, etc.) — eliminating one manual question for users who come with a specific opportunity in mind. This is particularly useful for early-career researchers who copy-paste a FOA (Funding Opportunity Announcement) URL and don't yet know the vocabulary.

### D. Budget-to-Grant Auto-Link

When `/budget "description"` creates a task, offer to link it to an existing grant task: "Is this budget for an existing grant task? If so, enter task number or 'no'." This creates a parent-child relationship in metadata, so the budget agent has access to the grant's aims and narrative without re-asking.

---

## Confidence Level: High

The evidence base is strong:

- All five command files read in full
- Forcing question frameworks for budget and funds read in full
- Talk library structure and context files surveyed
- Grant domain knowledge (funder types, proposal components, writing standards) sampled
- Existing research report (01_refactor-present-commands.md) read in full
- Manifest.json, EXTENSION.md, and the agent system architecture understood

The mechanical refactor needs (language unification, model normalization) are clearly correct and well-scoped. The enhancement recommendations (grant intake, talk design confirmation) are grounded in the user's stated vision and fill identified gaps in the current commands. The creative proposals (grant-to-talk pipeline, talk architect mode) are additive and do not conflict with the core refactor.

The one area of lower confidence: whether the "design confirmation" step in /talk should be synchronous (ask before task creation, as Stage 0.4) or asynchronous (propose in the research phase after analyzing source materials). Asynchronous is richer (agent has actually analyzed content) but breaks the Stage 0 pattern. The synchronous version is simpler but may feel premature. The planner should decide.
