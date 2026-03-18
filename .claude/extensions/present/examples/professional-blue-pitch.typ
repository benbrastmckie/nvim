// Professional Blue Theme - Investor Pitch Deck Example
// Mock Startup: SafeAI Labs - AI Safety Research Company
//
// Colors: Deep Navy (#1a365d), Medium Blue (#2c5282), Sky Blue (#4299e1)
// Typography: Montserrat headings, Inter body
// Best for: Fintech, enterprise B2B, professional services

#import "@preview/touying:0.6.3": *
#import themes.simple: *

// Theme configuration
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [SafeAI Labs],
    subtitle: [Building Reliable AI Systems for Critical Infrastructure],
    author: [Dr. Sarah Chen & Marcus Thompson],
    date: datetime.today(),
  ),
  config-colors(
    primary: rgb("#1a365d"),
    secondary: rgb("#2c5282"),
    neutral: rgb("#f8fafc"),
  ),
)

// Typography settings
#set text(font: "Inter", size: 30pt, fill: rgb("#1a202c"))
#show heading.where(level: 1): set text(font: "Montserrat", size: 48pt, weight: "bold", fill: rgb("#1a365d"))
#show heading.where(level: 2): set text(font: "Montserrat", size: 40pt, weight: "bold", fill: rgb("#1a365d"))

// Accent styling
#let accent = rgb("#4299e1")
#let primary = rgb("#1a365d")
#let secondary = rgb("#2c5282")

// ============================================================================
// SLIDE 1: Title
// ============================================================================
= SafeAI Labs

#align(center)[
  #text(size: 36pt, fill: secondary)[
    Building Reliable AI Systems for Critical Infrastructure
  ]

  #v(2em)

  #text(size: 24pt, fill: rgb("#64748b"))[
    Seed Round | Q1 2026
  ]
]

#speaker-note[
  "Thank you for your time today. I'm Sarah Chen, CEO of SafeAI Labs.
  We're building the safety layer that makes AI deployable in critical infrastructure.
  My co-founder Marcus Thompson and I previously led AI safety research at DeepMind."
]

// ============================================================================
// SLIDE 2: Problem
// ============================================================================
== The Problem

#text(size: 36pt, weight: "bold", fill: primary)[
  AI systems fail unpredictably in critical environments
]

#v(1em)

- *72% of enterprises* have halted AI deployments due to reliability concerns
- *\$4.2B lost* in 2025 from AI-related system failures
- Regulatory pressure mounting: EU AI Act requires safety verification

#v(1em)

#block(
  fill: rgb("#fef3c7"),
  radius: 8pt,
  inset: 16pt,
  width: 100%,
)[
  #text(size: 24pt, fill: rgb("#92400e"))[
    *Real Example*: A major hospital's AI diagnostic system misclassified
    23 critical cases in one week, causing \$12M in liability exposure.
  ]
]

#speaker-note[
  "Here's the core problem: AI systems are powerful but unpredictable.
  72 percent of enterprises we surveyed have stopped or paused AI deployments.
  The EU AI Act now requires formal safety verification for high-risk systems.
  Without reliable AI safety tools, enterprises can't deploy with confidence."
]

// ============================================================================
// SLIDE 3: Solution
// ============================================================================
== Our Solution

#text(size: 36pt, weight: "bold", fill: primary)[
  SafeGuard: Real-time AI reliability monitoring and intervention
]

#v(1em)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1.5em,
  block(
    fill: accent.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 36pt)[1]
      #v(0.5em)
      *Monitor*
      #v(0.3em)
      #text(size: 22pt)[
        Real-time anomaly detection across model outputs
      ]
    ]
  ],
  block(
    fill: accent.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 36pt)[2]
      #v(0.5em)
      *Verify*
      #v(0.3em)
      #text(size: 22pt)[
        Formal safety bounds with mathematical guarantees
      ]
    ]
  ],
  block(
    fill: accent.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 36pt)[3]
      #v(0.5em)
      *Intervene*
      #v(0.3em)
      #text(size: 22pt)[
        Automatic fallback when confidence drops
      ]
    ]
  ],
)

#speaker-note[
  "SafeGuard is a three-part system. First, we monitor AI outputs in real-time.
  Second, we verify predictions against formal safety bounds.
  Third, we automatically intervene when the AI operates outside safe parameters.
  Think of it as seatbelts and airbags for AI systems."
]

// ============================================================================
// SLIDE 4: Traction
// ============================================================================
== Traction

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1.5em,
  block(
    fill: primary.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: primary)[\$1.2M]
      #v(0.5em)
      #text(size: 20pt, fill: secondary)[ARR]
    ]
  ],
  block(
    fill: primary.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: primary)[8]
      #v(0.5em)
      #text(size: 20pt, fill: secondary)[Enterprise Customers]
    ]
  ],
  block(
    fill: primary.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: primary)[340%]
      #v(0.5em)
      #text(size: 20pt, fill: secondary)[YoY Growth]
    ]
  ],
)

#v(1em)

*Notable Customers*
- Regional healthcare system (3 hospitals, 400+ daily AI decisions)
- Fortune 500 financial services company (fraud detection)
- Defense contractor (autonomous systems verification)

#speaker-note[
  "We launched 18 months ago and have grown to 1.2 million ARR.
  Eight enterprise customers including a Fortune 500 financial services company.
  Our YoY growth is 340 percent, driven entirely by inbound demand.
  Healthcare and financial services are our primary verticals."
]

// ============================================================================
// SLIDE 5: Why Us / Why Now
// ============================================================================
== Why Us / Why Now

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Why Now*

    #v(0.5em)

    - EU AI Act enforcement begins 2026
    - Enterprise AI adoption at inflection point
    - Recent high-profile AI failures driving demand
    - No incumbent solutions for runtime safety
  ],
  [
    *Why Us*

    #v(0.5em)

    - Team: 15+ years combined AI safety research
    - IP: 3 patents on formal verification methods
    - First-mover: Only runtime solution in market
    - Network: Advisors from OpenAI, Anthropic, Google
  ],
)

#speaker-note[
  "The EU AI Act creates mandatory compliance starting in 2026.
  This is the seatbelt moment for AI - safety features become required, not optional.
  Our team pioneered the formal verification approach at DeepMind.
  We have three patents pending and advisory relationships with every major AI lab."
]

// ============================================================================
// SLIDE 6: Business Model
// ============================================================================
== Business Model

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Revenue Model*

    #v(0.5em)

    - *Platform fee*: \$120K/year base
    - *Usage tier*: \$0.001 per inference monitored
    - *Professional services*: Custom integration

    #v(1em)

    *Average Contract*: \$180K ACV
  ],
  [
    *Unit Economics*

    #v(0.5em)

    - *Gross margin*: 78%
    - *CAC*: \$45K (enterprise sales)
    - *LTV*: \$540K (3-year retention)
    - *Payback*: 9 months

    #v(1em)

    *LTV:CAC Ratio*: 12:1
  ],
)

#speaker-note[
  "Our business model is SaaS plus usage. Base platform fee of 120K annually.
  Usage charges scale with the number of AI inferences we monitor.
  Our average contract is 180K with 78 percent gross margins.
  LTV to CAC ratio of 12 to 1 with 9-month payback periods."
]

// ============================================================================
// SLIDE 7: Market Opportunity
// ============================================================================
== Market Opportunity

#align(center)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    gutter: 2em,
    block(
      fill: primary.lighten(85%),
      radius: 50%,
      width: 200pt,
      height: 200pt,
    )[
      #align(center + horizon)[
        #text(size: 32pt, weight: "bold", fill: primary)[\$48B]
        #v(0.3em)
        #text(size: 18pt, fill: secondary)[TAM]
        #v(0.2em)
        #text(size: 14pt, fill: rgb("#64748b"))[Enterprise AI Market]
      ]
    ],
    block(
      fill: secondary.lighten(80%),
      radius: 50%,
      width: 160pt,
      height: 160pt,
    )[
      #align(center + horizon)[
        #text(size: 28pt, weight: "bold", fill: primary)[\$12B]
        #v(0.3em)
        #text(size: 16pt, fill: secondary)[SAM]
        #v(0.2em)
        #text(size: 13pt, fill: rgb("#64748b"))[High-risk AI systems]
      ]
    ],
    block(
      fill: accent.lighten(75%),
      radius: 50%,
      width: 120pt,
      height: 120pt,
    )[
      #align(center + horizon)[
        #text(size: 24pt, weight: "bold", fill: primary)[\$2.4B]
        #v(0.3em)
        #text(size: 14pt, fill: secondary)[SOM]
        #v(0.2em)
        #text(size: 12pt, fill: rgb("#64748b"))[5-year target]
      ]
    ],
  )
]

#v(1em)

#text(size: 24pt)[
  *Bottom-up*: 50K enterprises deploying high-risk AI x \$48K average safety spend = \$2.4B SOM
]

#speaker-note[
  "The enterprise AI market is 48 billion dollars.
  Our serviceable market is 12 billion - high-risk AI systems requiring verification.
  We're targeting 2.4 billion in the next 5 years based on 50,000 enterprises
  with an average 48K annual safety spend."
]

// ============================================================================
// SLIDE 8: Team
// ============================================================================
== Team

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Dr. Sarah Chen*

    CEO & Co-founder

    #text(size: 22pt)[
      - Former AI Safety Lead, DeepMind (6 years)
      - PhD in Formal Methods, MIT
      - Published 40+ papers on AI verification
      - Led safety certification for 3 production systems
    ]
  ],
  [
    *Marcus Thompson*

    CTO & Co-founder

    #text(size: 22pt)[
      - Former Principal Engineer, Anthropic
      - MSc Computer Science, Stanford
      - Built monitoring systems at scale (10B+ events/day)
      - Open source maintainer, PyTorch Safety
    ]
  ],
)

#v(1em)

*Key Advisors*: Dr. Stuart Russell (Berkeley), Dario Amodei (Anthropic), Jeff Dean (Google)

#speaker-note[
  "I spent six years leading AI safety research at DeepMind.
  Marcus built Anthropic's internal monitoring infrastructure.
  Between us, we have 15 years of direct AI safety experience.
  Our advisors include Stuart Russell and leadership from both Anthropic and Google."
]

// ============================================================================
// SLIDE 9: The Ask
// ============================================================================
== The Ask

#align(center)[
  #text(size: 48pt, weight: "bold", fill: primary)[
    Raising \$8M Series A
  ]
]

#v(1em)

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Use of Funds*

    #v(0.5em)

    - 50% Engineering (ML + Platform)
    - 25% Go-to-market expansion
    - 15% Customer success
    - 10% Operations
  ],
  [
    *18-Month Milestones*

    #v(0.5em)

    - \$5M ARR (4x growth)
    - 25 enterprise customers
    - SOC 2 Type II certification
    - EU AI Act compliance toolkit
  ],
)

#v(1em)

#align(center)[
  #block(
    fill: accent.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #text(size: 24pt, fill: primary)[
      *Current investors*: Sequoia Scout, Quiet Capital, AI Grant
    ]
  ]
]

#speaker-note[
  "We're raising 8 million dollars to scale the team and expand go-to-market.
  Half goes to engineering - we need to build faster as demand grows.
  In 18 months, we'll reach 5 million ARR with 25 enterprise customers.
  We'll also achieve SOC 2 and launch our EU AI Act compliance toolkit."
]

// ============================================================================
// SLIDE 10: Thank You
// ============================================================================
== Thank You

#align(center)[
  #v(1em)

  #text(size: 48pt, weight: "bold", fill: primary)[
    SafeAI Labs
  ]

  #v(0.5em)

  #text(size: 32pt, fill: secondary)[
    Making AI Safe for Critical Infrastructure
  ]

  #v(2em)

  #text(size: 28pt)[
    sarah\@safeailabs.com

    safeailabs.com
  ]

  #v(1em)

  #text(size: 22pt, fill: rgb("#64748b"))[
    Appendix slides available for deep dives
  ]
]

#speaker-note[
  "Thank you for your time. I'm happy to answer questions.
  We have appendix slides on technical architecture, competitive landscape,
  and detailed financial projections."
]
