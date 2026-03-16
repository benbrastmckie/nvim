# YC Pitch Deck Structure and Design Principles

This document encodes Y Combinator's recommended pitch deck structure and design principles for investor presentations, based on YC Library articles.

## Slide Structure (9+1 Slides)

### Slide 1: Title
**Purpose**: Company introduction

**Required Content**:
- Company name
- One-line description (what you do, in plain language)
- Optional: Company logo (minimal branding)

**Guidelines**:
- The description should be understandable by someone outside your industry
- Avoid jargon, buzzwords, or technical terms
- Example: "Stripe: Online payments for internet businesses"

---

### Slide 2: Problem
**Purpose**: Establish the pain point you solve

**Required Content**:
- Clear articulation of the problem
- Impact on real people or businesses
- Supporting data (statistics, stories, or examples)

**Guidelines**:
- Make the problem relatable and concrete
- Use specific examples over abstract descriptions
- If possible, quantify the problem's impact
- Avoid: Starting with your solution

---

### Slide 3: Solution
**Purpose**: Show how your product addresses the problem

**Required Content**:
- Brief description of your solution
- How it directly addresses the problem from slide 2
- Concrete benefits (not features)

**Guidelines**:
- Keep it simple - one core idea
- Focus on outcomes, not technical implementation
- Show the "before and after" transformation
- Avoid: Feature lists, technical architecture

---

### Slide 4: Traction
**Purpose**: Demonstrate momentum and validation

**Required Content**:
- Key metrics displayed as a chart or graph
- Context for the metrics (what they mean)
- Growth rate if applicable

**Guidelines**:
- Use visual representation (line chart, bar chart)
- Highlight the trend, not just current numbers
- Include time context (monthly, weekly)
- Good metrics: Revenue, users, engagement, retention
- Avoid: Vanity metrics without business meaning

**Layout Note**: This slide typically uses a prominent chart/graph as the visual centerpiece.

---

### Slide 5: Unique Advantage / Why Now
**Purpose**: Explain your differentiation and timing

**Required Content**:
- What makes your approach unique
- Why this solution is possible/needed now
- Competitive advantage or insight

**Guidelines**:
- Focus on sustainable advantages (not easily copied)
- Explain market timing (regulatory changes, technology shifts)
- Show unique insight that others have missed
- Avoid: Generic claims like "we're faster/cheaper/better"

---

### Slide 6: Business Model
**Purpose**: Show how you make money

**Required Content**:
- Revenue streams
- Pricing strategy (or planned pricing)
- Unit economics if available

**Guidelines**:
- Keep it simple - one or two revenue streams
- Show early results if you have them
- Make the path to scale obvious
- Avoid: Complex multi-revenue-stream models

---

### Slide 7: Market Opportunity
**Purpose**: Show the size of your opportunity

**Required Content**:
- Total Addressable Market (TAM)
- Clean visual representation of market size
- Segmentation if relevant (TAM -> SAM -> SOM)

**Guidelines**:
- Use credible data sources
- Show bottom-up calculations if possible
- Make the opportunity feel large but achievable
- Avoid: Top-down "if we get 1% of the market" logic

**Layout Note**: This slide typically uses a simple visual (concentric circles, bar chart) to convey scale.

---

### Slide 8: Team
**Purpose**: Show why you are the team to execute

**Required Content**:
- Founders with names and titles
- Relevant experience or qualifications
- Key hires if applicable

**Guidelines**:
- Focus on relevant domain expertise
- Include previous startup experience if applicable
- Show complementary skill sets
- Avoid: Full resumes or lengthy bios

**Layout Note**: This slide typically uses a two-column layout with photos (optional) and brief bios.

---

### Slide 9: The Ask
**Purpose**: State your fundraising goal

**Required Content**:
- Amount you are raising
- How funds will be allocated
- Key milestones you will achieve

**Guidelines**:
- Be specific about the amount
- Show 3-4 major allocation categories
- Milestones should be achievable in 12-18 months
- Avoid: Vague descriptions like "for growth"

---

### Slide 10: Closing (Optional)
**Purpose**: Contact information and Q&A prompt

**Required Content**:
- Contact email or website
- Thank you / Q&A invitation

**Guidelines**:
- Keep it minimal
- No need to repeat company name/logo
- Can be combined with The Ask if space permits

---

## Three Design Principles (Kevin Hale, YC)

### 1. Legibility

**Definition**: Content is readable by everyone in the room, including "old people in the back row with bad eyesight."

**Implementation**:
- Large, bold fonts (minimum 24pt for body text, 40pt+ for titles)
- High contrast (dark text on light background, or vice versa)
- Simple, straightforward font choices (sans-serif preferred)
- Place key text at top of slides (F-pattern reading)
- Avoid small labels, fine print, or detailed charts

**Test**: Can someone in the back row read every word?

### 2. Simplicity

**Definition**: Each slide communicates one idea clearly.

**Implementation**:
- One idea per slide
- Remove excessive explanations and caveats
- No animations, transitions, or distracting design
- Limit to 5-7 key ideas across the entire deck
- Use whitespace deliberately

**Test**: Can you state the slide's message in one sentence?

### 3. Obviousness

**Definition**: Slides are understood at a glance without explanation.

**Implementation**:
- Test with strangers who should "immediately" grasp the idea
- Make ideas explicit, not implicit
- Use familiar formats and conventions
- Label everything clearly
- Avoid inside jokes or references

**Test**: Would a stranger understand this in 3 seconds?

---

## Anti-Patterns (Things to Avoid)

### Visual Anti-Patterns
- **Screenshots**: Break all three design rules (illegible, complex, non-obvious)
- **Excessive branding**: Logo on every slide, gradient backgrounds
- **Memes and humor**: Rarely translates, distracts from message
- **Information overload**: Too many bullet points, too much text
- **Videos/screencasts**: Risky without careful consideration
- **Complicated layouts**: Multi-column text, overlapping elements

### Content Anti-Patterns
- **Jargon**: Industry-specific terms, acronyms without explanation
- **Feature lists**: Instead of benefits and outcomes
- **Defensive language**: "Of course, this might not work, but..."
- **Future promises**: Unachieved milestones presented as fact
- **Competitive comparison tables**: Often backfire

### Structural Anti-Patterns
- **Too many slides**: More than 10-12 loses attention
- **Burying the lede**: Key message on slide 8 instead of slide 2
- **No clear ask**: Leaving investors unsure what you want
- **Appendix overload**: 50 appendix slides signal lack of focus

---

## Key Philosophy

> "Investors invest in teams not slides. Your slides should make your ideas more clear."

The deck is a communication tool, not the pitch itself. Focus on:
1. Clarity over comprehensiveness
2. Memorability over detail
3. 5-7 key ideas people should remember

---

## Related Context

- See `touying-pitch-deck-template.md` for the Typst template implementing this structure
- See `presentation-slides.md` for general slide generation patterns
