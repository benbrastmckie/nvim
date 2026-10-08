<!-- Context: workflows/task-breakdown | Priority: high | Version: 2.0 | Updated: 2025-01-21 -->

# Task Breakdown Guidelines

## Quick Reference

**When to Use**: 4+ files, >60 min effort, complex dependencies, multi-step coordination

**Process**: Scope → Phases → Small Tasks (1-2h) → Dependencies → Estimates

**Template Sections**: Overview, Prerequisites, Tasks (by Phase), Testing Strategy, Total Estimate, Notes

**Best Practices**: Keep tasks small (1-2h), make dependencies clear, include verification, be realistic with estimates

---

## Purpose
Framework for breaking down complex tasks into manageable, sequential subtasks.

## When to Use
Reference this when:
- Task involves 4+ files
- Estimated effort >60 minutes
- Complex dependencies exist
- Multi-step coordination needed
- User requests task breakdown

## Breakdown Process

### 1. Understand the Full Scope
- What's the complete requirement?
- What are all the components needed?
- What's the end goal?
- What are the constraints?

### 2. Identify Major Phases
- What are the logical groupings?
- What must happen first?
- What can happen in parallel?
- What depends on what?

### 3. Break Into Small Tasks
- Each task should be 1-2 hours max
- Clear, actionable items
- Independently completable
- Easy to verify completion

### 4. Define Dependencies
- What must be done first?
- What can be done in parallel?
- What blocks what?
- What's the critical path?

### 5. Estimate Effort
- Realistic time estimates
- Include testing time
- Account for unknowns
- Add buffer for complexity

## Breakdown Template

```markdown
# Task Breakdown: {Task Name}

## Overview
{1-2 sentence description of what we're building}

## Prerequisites
- [ ] {Prerequisite 1}
- [ ] {Prerequisite 2}

## Tasks

### Phase 1: {Phase Name}
**Goal:** {What this phase accomplishes}
**Verification Tier:** {one of `prose`, `local`, `interface`, `full` -- see plan-format.md's
`## Verification Tiers` section; this is the phase-level tier, distinct from each task's own
item-level `**Verification:**` line below}
**Tier Justification:** {conditional -- required on every non-final phase, omitted on the final
phase; one sentence naming the specific covering check or the specific cross-cutting surface no
cheaper tier covers -- see plan-format.md's `## Verification Tiers` section}

- [ ] **Step 1.1:** {Description}
  - **Files:** {files to create/modify}
  - **Estimate:** {time estimate}
  - **Dependencies:** {none / task X}
  - **Verification:** {how to verify it's done}

- [ ] **Step 1.2:** {Description}
  - **Files:** {files to create/modify}
  - **Estimate:** {time estimate}
  - **Dependencies:** {step 1.1}
  - **Verification:** {how to verify it's done}

### Phase 2: {Phase Name}
**Goal:** {What this phase accomplishes}
**Verification Tier:** {one of `prose`, `local`, `interface`, `full`}
**Tier Justification:** {conditional -- required on every non-final phase, omitted on the final
phase; see plan-format.md's `## Verification Tiers` section}

- [ ] **Step 2.1:** {Description}
  - **Files:** {files to create/modify}
  - **Estimate:** {time estimate}
  - **Dependencies:** {phase 1 complete}
  - **Verification:** {how to verify it's done}

## Testing Strategy
- [ ] Unit tests for {component}
- [ ] Integration tests for {flow}
- [ ] Manual testing: {scenarios}

## Total Estimate
**Time:** {X} hours
**Complexity:** {Low / Medium / High}

## Notes
{Any important context, decisions, or considerations}
```

## Example Breakdown

```markdown
# Task Breakdown: User Authentication System

## Overview
Build authentication system with login, registration, and password reset.

## Prerequisites
- [ ] Database schema designed
- [ ] Email service configured

## Tasks

### Phase 1: Core Authentication
**Goal:** Basic login/logout functionality
**Verification Tier:** interface (new user model and login endpoint are called from multiple
route handlers, so verification spans the changed module plus its direct dependents)
**Tier Justification:** Build of `models/user.js` and `routes/auth.js` plus their enumerated
direct dependents (`controllers/auth.js`, the two route handlers that call the login endpoint)
covers the new signature; nothing beyond that one-hop set is touched.

- [ ] **Step 1.1:** Create user model and database schema
  - **Files:** `models/user.js`, `migrations/001_users.sql`
  - **Estimate:** 1 hour
  - **Dependencies:** none
  - **Verification:** Can create user in database

- [ ] **Step 1.2:** Implement password hashing
  - **Files:** `utils/password.js`
  - **Estimate:** 30 min
  - **Dependencies:** Step 1.1
  - **Verification:** Passwords are hashed, not plain text

- [ ] **Step 1.3:** Create login endpoint
  - **Files:** `routes/auth.js`, `controllers/auth.js`
  - **Estimate:** 1.5 hours
  - **Dependencies:** Step 1.1, 1.2
  - **Verification:** Can login with valid credentials

### Phase 2: Registration
**Goal:** New user registration
**Verification Tier:** local (registration endpoint and validation are confined to the auth
module; no externally visible signature changes)
**Tier Justification:** Lint/build of `routes/auth.js`, `controllers/auth.js`, and
`utils/validation.js` is the complete covering check; the new registration path adds no symbol
any other module calls.

- [ ] **Step 2.1:** Create registration endpoint
  - **Files:** `routes/auth.js`, `controllers/auth.js`
  - **Estimate:** 1 hour
  - **Dependencies:** Phase 1 complete
  - **Verification:** Can create new user account

- [ ] **Step 2.2:** Add email validation
  - **Files:** `utils/validation.js`
  - **Estimate:** 30 min
  - **Dependencies:** Step 2.1
  - **Verification:** Invalid emails rejected

### Phase 3: Password Reset
**Goal:** Users can reset forgotten passwords
**Verification Tier:** full (touches shared token generation, email delivery, and auth state
that other flows depend on -- the complete gate set runs for this phase)
**Tier Justification:** Touches shared token generation, email delivery, and auth state that
other flows (login, registration) depend on -- no cheaper tier's enumerated-dependent set covers
a shared, cross-flow surface this broad.

- [ ] **Step 3.1:** Generate reset tokens
  - **Files:** `utils/tokens.js`
  - **Estimate:** 1 hour
  - **Dependencies:** Phase 1 complete
  - **Verification:** Tokens generated and validated

- [ ] **Step 3.2:** Create reset endpoints
  - **Files:** `routes/auth.js`, `controllers/auth.js`
  - **Estimate:** 1.5 hours
  - **Dependencies:** Step 3.1
  - **Verification:** Can request and complete password reset

- [ ] **Step 3.3:** Send reset emails
  - **Files:** `services/email.js`
  - **Estimate:** 1 hour
  - **Dependencies:** Step 3.2
  - **Verification:** Reset emails sent successfully

## Testing Strategy
- [ ] Unit tests for password hashing
- [ ] Unit tests for token generation
- [ ] Integration tests for login flow
- [ ] Integration tests for registration flow
- [ ] Integration tests for password reset flow
- [ ] Manual testing: Complete user journey

## Total Estimate
**Time:** 8.5 hours
**Complexity:** Medium

## Notes
- Use bcrypt for password hashing (industry standard)
- Reset tokens expire after 1 hour
- Rate limit password reset requests
- Email service must be configured before Phase 3
- Phase 3 depends only on "Phase 1 complete" above, not on Phase 2 -- so under
  plan-format.md's `## Verification Tiers` final-phase definition (highest-numbered phase,
  transitively depending on *every* other phase) Phase 3 is NOT this example's final phase,
  despite being last-listed. That is exactly why its `full` tier is stated with a justification
  above rather than being exempt: this is the worked demonstration of a non-final phase
  legitimately declaring `full`.
```

## Best Practices

### Keep Tasks Small
- 1-2 hours maximum per task
- If larger, break it down further
- Each task should be completable in one sitting

### Make Dependencies Clear
- Explicitly state what must be done first
- Identify parallel work opportunities
- Note blocking dependencies

### Include Verification
- How do you know the task is done?
- What should work when complete?
- How can it be tested?

### Be Realistic with Estimates
- Include time for testing
- Account for unknowns
- Add buffer for complexity
- Better to overestimate than underestimate

### Group Related Work
- Organize by feature or component
- Keep related tasks together
- Make phases logical and cohesive

## Common Patterns

### Database-First Pattern
1. Design schema
2. Create migrations
3. Build models
4. Implement business logic
5. Add API endpoints
6. Write tests

### Feature-First Pattern
1. Define requirements
2. Design interface
3. Implement core logic
4. Add error handling
5. Write tests
6. Document usage

### Refactoring Pattern
1. Add tests for existing behavior
2. Refactor small section
3. Verify tests still pass
4. Repeat for next section
5. Clean up and optimize
6. Update documentation

## Quick Reference

**Good breakdown:**
- Small, focused tasks (1-2 hours)
- Clear dependencies
- Realistic estimates
- Verification criteria
- Logical phases

**Breakdown checklist:**
- [ ] All requirements captured
- [ ] Tasks are small and focused
- [ ] Dependencies identified
- [ ] Estimates are realistic
- [ ] Testing included
- [ ] Verification criteria clear
- [ ] Verification tier assigned per phase
