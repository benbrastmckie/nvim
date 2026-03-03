# Domain Patterns for System Generation

**Purpose**: Common domain patterns and their typical agent/context structures

**Version**: 1.0  
**Last Updated**: 2025-12-29

---

## Development Domain Pattern

**Characteristics**: Code generation, testing, build, deployment workflows

### Typical Use Cases

- Code generation and refactoring
- Test authoring and execution
- Build validation and type checking
- Deployment automation
- Code review and quality assurance

### Recommended Agent Structure

```
development-orchestrator
├── coder-agent (code generation)
├── tester-agent (test authoring)
├── build-agent (build validation)
├── reviewer-agent (code review)
└── deployer-agent (deployment)
```

### Context Organization

```
context/development/
├── coding-standards.md
├── testing-patterns.md
├── build-processes.md
└── deployment-workflows.md
```

### Integration Points

- Version control (git)
- Build systems (make, cmake, cargo, npm)
- Test frameworks (pytest, jest, lean)
- CI/CD platforms (GitHub Actions, Jenkins)

---

## Business Domain Pattern

**Characteristics**: E-commerce, support, marketing, content management

### Typical Use Cases

- Customer support ticket routing
- Product catalog management
- Marketing campaign automation
- Content creation and publishing
- Order processing and fulfillment

### Recommended Agent Structure

```
business-orchestrator
├── support-agent (ticket routing, responses)
├── catalog-agent (product management)
├── marketing-agent (campaign automation)
├── content-agent (content creation)
└── order-agent (order processing)
```

### Context Organization

```
context/business/
├── customer-personas.md
├── product-categories.md
├── support-workflows.md
└── marketing-templates.md
```

### Integration Points

- CRM systems (Salesforce, HubSpot)
- E-commerce platforms (Shopify, WooCommerce)
- Email marketing (Mailchimp, SendGrid)
- Analytics (Google Analytics, Mixpanel)

---

## Hybrid Domain Pattern

**Characteristics**: Data engineering, product management, analytics

### Typical Use Cases

- Data pipeline orchestration
- ETL workflow automation
- Analytics report generation
- Product roadmap planning
- Feature prioritization

### Recommended Agent Structure

```
hybrid-orchestrator
├── data-agent (pipeline orchestration)
├── analytics-agent (report generation)
├── planning-agent (roadmap planning)
└── prioritization-agent (feature prioritization)
```

### Context Organization

```
context/hybrid/
├── data-schemas.md
├── analytics-metrics.md
├── planning-frameworks.md
└── prioritization-criteria.md
```

### Integration Points

- Data warehouses (Snowflake, BigQuery)
- BI tools (Tableau, Looker)
- Project management (Jira, Linear)
- Data pipelines (Airflow, Prefect)

---

## Formal Verification Domain Pattern (Logos/Theory-Specific)

**Characteristics**: Proof systems, theorem proving, verification

### Typical Use Cases

- Formal proof development
- Theorem verification
- Proof search and automation
- Metalogic reasoning
- Proof library management

### Recommended Agent Structure

```
verification-orchestrator
├── proof-developer (proof authoring)
├── proof-verifier (verification)
├── proof-searcher (automation)
├── metalogic-reasoner (metalogic)
└── library-manager (proof library)
```

### Context Organization

```
context/verification/
├── proof-patterns.md
├── verification-strategies.md
├── automation-tactics.md
└── library-organization.md
```

### Integration Points

- Proof assistants (Lean 4, Coq, Isabelle)
- LSP servers (lean-lsp-mcp)
- Proof libraries (Mathlib, Archive)
- Verification tools (SMT solvers)

---

## Domain Type Detection

### Development Indicators

- Keywords: code, test, build, deploy, refactor, review
- Tools: git, make, npm, cargo, pytest, jest
- Artifacts: source files, test files, build configs

### Business Indicators

- Keywords: customer, product, order, campaign, ticket, support
- Tools: CRM, e-commerce, email, analytics
- Artifacts: customer data, product catalogs, marketing content

### Hybrid Indicators

- Keywords: data, pipeline, analytics, roadmap, feature, metric
- Tools: data warehouse, BI, project management, ETL
- Artifacts: data schemas, reports, roadmaps

### Formal Verification Indicators

- Keywords: proof, theorem, verify, formal, logic, tactic
- Tools: Lean, Coq, Isabelle, SMT solvers
- Artifacts: proof files, theorem libraries, verification reports

---

## Agent Count Guidelines

### Simple Domains (1-3 agents)

- Single clear purpose
- Few use cases (1-3)
- Minimal integrations
- Example: Simple task tracker

### Moderate Domains (4-7 agents)

- Multiple related purposes
- Several use cases (4-7)
- Some integrations
- Example: E-commerce system

### Complex Domains (8+ agents)

- Many diverse purposes
- Numerous use cases (8+)
- Extensive integrations
- Example: Enterprise platform

---

## Context File Guidelines

### Minimal Context (1-3 files)

- Simple domain with clear boundaries
- Well-understood patterns
- Minimal domain-specific knowledge

### Standard Context (4-7 files)

- Moderate complexity
- Some domain-specific patterns
- Moderate knowledge requirements

### Extensive Context (8+ files)

- High complexity
- Many domain-specific patterns
- Significant knowledge requirements

---

## Related Patterns

- **Interview Patterns**: `.opencode/context/core/workflows/interview-patterns.md`
- **Architecture Principles**: `.opencode/context/core/standards/architecture-principles.md`
- **Agent Templates**: `.opencode/context/core/templates/agent-templates.md`

---

**Maintained By**: Logos/Theory Development Team
