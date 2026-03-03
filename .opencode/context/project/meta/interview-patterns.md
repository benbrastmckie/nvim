# Interview Patterns for Meta-Programming

**Purpose**: Patterns for conducting effective interactive interviews during system building

**Version**: 1.0  
**Last Updated**: 2025-12-29

---

## Progressive Disclosure Pattern

Start with broad questions and progressively drill into specifics based on user responses.

### Stage Progression

1. **Broad Context** (Stage 2):
   - What is your domain?
   - What is the primary purpose?
   - Who are the target users?

2. **Specific Use Cases** (Stage 3):
   - What are the top 3-5 use cases?
   - What is the complexity of each?
   - What are the dependencies?

3. **Technical Details** (Stage 4-5):
   - How many agents are needed?
   - What integrations are required?
   - What state management is needed?

4. **Validation** (Stage 6):
   - Present comprehensive summary
   - Confirm understanding
   - Get explicit approval

### Benefits

- Reduces cognitive load on user
- Builds understanding incrementally
- Allows course correction early
- Ensures complete information capture

---

## Adaptive Questioning Pattern

Adjust question complexity and terminology based on user's technical level.

### Technical Level Detection

**Indicators of High Technical Level**:
- Uses technical jargon correctly
- Mentions specific tools/frameworks
- Describes architecture patterns
- Understands agent concepts

**Indicators of Low Technical Level**:
- Uses business terminology
- Focuses on outcomes, not implementation
- Asks clarifying questions about terms
- Needs examples for every question

### Question Adaptation

**For Technical Users**:
```
"What agent hierarchy do you envision? (e.g., orchestrator + subagents)"
"What context loading strategy? (eager vs. lazy)"
"What delegation depth limit? (default: 3)"
```

**For Non-Technical Users**:
```
"What tasks should the system help with?"
"What information does the system need to know?"
"What should happen when X occurs?"
```

---

## Example-Driven Questioning Pattern

Provide concrete examples for every question to clarify intent.

### Example Structure

```
Question: [Abstract question]

Examples:
- Example 1: [Concrete example from common domain]
- Example 2: [Concrete example from user's domain if known]
- Example 3: [Edge case or advanced example]
```

### Sample Questions with Examples

**Domain Purpose**:
```
What is the primary purpose of your system?

Examples:
- "Automate customer support ticket routing"
- "Generate and verify formal proofs"
- "Analyze and visualize sales data"
```

**Use Cases**:
```
What are your top use cases?

Examples:
- "Route incoming tickets to appropriate team based on content"
- "Prove theorems about temporal logic properties"
- "Generate weekly sales reports with trend analysis"
```

---

## Validation Checkpoint Pattern

Confirm understanding at key decision points before proceeding.

### Checkpoint Locations

1. **After Domain Gathering** (Stage 2):
   - Confirm domain type classification
   - Validate purpose understanding
   - Verify user personas

2. **After Use Case Identification** (Stage 3):
   - Confirm use case priorities
   - Validate complexity assessments
   - Verify dependencies

3. **After Architecture Design** (Stage 6):
   - Present complete architecture summary
   - Confirm all components
   - Get explicit approval to proceed

### Checkpoint Format

```
[CHECKPOINT]

Based on our conversation, I understand:
- Domain: [domain name]
- Purpose: [primary purpose]
- Users: [user personas]
- Use Cases: [top 3-5 use cases]

Is this correct? (yes/no/clarify)
```

---

## Error Recovery Pattern

Handle unclear or incomplete responses gracefully.

### Recovery Strategies

**For Unclear Responses**:
```
I want to make sure I understand correctly.
When you said "[user response]", did you mean:
A) [interpretation 1]
B) [interpretation 2]
C) Something else (please clarify)
```

**For Incomplete Responses**:
```
That's helpful! To complete the picture, I also need to know:
- [missing information 1]
- [missing information 2]
```

**For Contradictory Responses**:
```
I noticed a potential inconsistency:
- Earlier you mentioned: [statement 1]
- Now you mentioned: [statement 2]

Could you help me understand how these fit together?
```

---

## Context Building Pattern

Build shared context incrementally throughout the interview.

### Context Accumulation

1. **Initial Context** (Stage 1):
   - Explain meta-programming process
   - Set expectations
   - Establish terminology

2. **Domain Context** (Stage 2):
   - Capture domain vocabulary
   - Identify domain patterns
   - Build shared understanding

3. **Technical Context** (Stage 3-5):
   - Introduce technical concepts as needed
   - Link to domain context
   - Validate understanding

4. **Complete Context** (Stage 6):
   - Present unified architecture
   - Show how all pieces fit together
   - Confirm shared understanding

---

## Related Patterns

- **Architecture Principles**: `.opencode/context/core/standards/architecture-principles.md`
- **Domain Patterns**: `.opencode/context/core/standards/domain-patterns.md`
- **Agent Templates**: `.opencode/context/core/templates/agent-templates.md`

---

**Maintained By**: Logos/Theory Development Team
