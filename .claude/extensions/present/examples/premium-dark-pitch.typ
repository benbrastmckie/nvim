// Premium Dark Theme - Investor Pitch Deck Example
// Mock Startup: NeuralShield - Enterprise AI Security Platform
//
// Colors: Dark Charcoal (#1a1a2e), Deep Blue-Black (#16213e), Gold (#d4a574)
// Typography: Montserrat headings, Inter body (light text on dark)
// Best for: Premium products, luxury brands, sophisticated tech

#import "@preview/touying:0.6.3": *
#import themes.simple: *

// Theme configuration - dark mode
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [NeuralShield],
    subtitle: [AI-Powered Threat Detection for Enterprise Security],
    author: [Alex Rivera & Dr. Priya Sharma],
    date: datetime.today(),
  ),
  config-colors(
    primary: rgb("#d4a574"),
    secondary: rgb("#e2e8f0"),
    neutral: rgb("#1a1a2e"),
  ),
)

// Dark background
#set page(fill: rgb("#0f0f1a"))

// Typography settings - light text on dark background
#set text(font: "Inter", size: 30pt, fill: rgb("#e2e8f0"))
#show heading.where(level: 1): set text(font: "Montserrat", size: 48pt, weight: "bold", fill: rgb("#d4a574"))
#show heading.where(level: 2): set text(font: "Montserrat", size: 40pt, weight: "bold", fill: rgb("#d4a574"))

// Color palette
#let gold = rgb("#d4a574")
#let light-text = rgb("#e2e8f0")
#let dark-bg = rgb("#0f0f1a")
#let card-bg = rgb("#1a1a2e")
#let secondary-bg = rgb("#16213e")

// ============================================================================
// SLIDE 1: Title
// ============================================================================
= NeuralShield

#align(center)[
  #text(size: 36pt, fill: light-text)[
    AI-Powered Threat Detection for Enterprise Security
  ]

  #v(2em)

  #text(size: 24pt, fill: rgb("#94a3b8"))[
    Series A | Q1 2026
  ]
]

#speaker-note[
  "Good morning. I'm Alex Rivera, CEO of NeuralShield.
  We're building the next generation of enterprise security using adversarial AI.
  My co-founder Dr. Priya Sharma and I previously built the threat intelligence
  platform at CrowdStrike."
]

// ============================================================================
// SLIDE 2: Problem
// ============================================================================
== The Problem

#text(size: 36pt, weight: "bold", fill: gold)[
  Traditional security can't keep pace with AI-powered attacks
]

#v(1em)

- *AI-generated phishing* increased 1,200% in 2025
- *Average breach cost*: \$4.9M per incident
- *Detection time*: 277 days average (attackers move in hours)

#v(1em)

#block(
  fill: secondary-bg,
  radius: 8pt,
  inset: 16pt,
  width: 100%,
)[
  #text(size: 24pt, fill: rgb("#fbbf24"))[
    *Recent Headlines*: Fortune 100 breached via AI-crafted spear phishing.
    Attackers used deepfake audio to authorize \$25M wire transfer.
  ]
]

#speaker-note[
  "The threat landscape has fundamentally changed. AI-generated attacks are up
  12x in the past year. The average breach costs nearly 5 million dollars.
  And here's the critical gap: attackers move in hours, but detection takes
  277 days on average. Traditional tools simply cannot keep up."
]

// ============================================================================
// SLIDE 3: Solution
// ============================================================================
== Our Solution

#text(size: 36pt, weight: "bold", fill: gold)[
  Fight AI with AI: Adversarial defense that evolves with threats
]

#v(1em)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1.5em,
  block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(60%),
  )[
    #align(center)[
      #text(size: 36pt, fill: gold)[1]
      #v(0.5em)
      #text(fill: gold)[*Detect*]
      #v(0.3em)
      #text(size: 22pt, fill: light-text)[
        Real-time analysis of network behavior
      ]
    ]
  ],
  block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(60%),
  )[
    #align(center)[
      #text(size: 36pt, fill: gold)[2]
      #v(0.5em)
      #text(fill: gold)[*Predict*]
      #v(0.3em)
      #text(size: 22pt, fill: light-text)[
        AI models anticipate attack patterns
      ]
    ]
  ],
  block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(60%),
  )[
    #align(center)[
      #text(size: 36pt, fill: gold)[3]
      #v(0.5em)
      #text(fill: gold)[*Neutralize*]
      #v(0.3em)
      #text(size: 22pt, fill: light-text)[
        Automated response in milliseconds
      ]
    ]
  ],
)

#speaker-note[
  "NeuralShield fights AI with AI. Our platform has three components:
  Detection - we analyze network behavior in real-time using transformer models.
  Prediction - we anticipate attack patterns before they execute.
  Neutralization - automated response kicks in within milliseconds.
  We've reduced detection time from months to minutes."
]

// ============================================================================
// SLIDE 4: Traction
// ============================================================================
== Traction

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1.5em,
  block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(70%),
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: gold)[\$4.8M]
      #v(0.5em)
      #text(size: 20pt, fill: light-text)[ARR]
    ]
  ],
  block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(70%),
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: gold)[23]
      #v(0.5em)
      #text(size: 20pt, fill: light-text)[Enterprise Customers]
    ]
  ],
  block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(70%),
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: gold)[99.7%]
      #v(0.5em)
      #text(size: 20pt, fill: light-text)[Detection Rate]
    ]
  ],
)

#v(1em)

*Customer Highlights*
- 3 Fortune 500 financial institutions
- Top-10 US healthcare system (2.5M patient records protected)
- Government contractor with FEDRAMP authorization

#speaker-note[
  "We launched 24 months ago and reached 4.8 million ARR.
  23 enterprise customers including 3 Fortune 500 banks.
  Our detection rate is 99.7 percent - the industry average is 62 percent.
  We recently received FEDRAMP authorization for government sales."
]

// ============================================================================
// SLIDE 5: Why Us / Why Now
// ============================================================================
== Why Us / Why Now

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #text(fill: gold)[*Why Now*]

    #v(0.5em)

    - Generative AI weaponized by attackers
    - Legacy SIEM tools overwhelmed
    - Cyber insurance costs up 300%
    - Board-level security mandates
  ],
  [
    #text(fill: gold)[*Why Us*]

    #v(0.5em)

    - Built CrowdStrike's threat intel (Alex)
    - ML PhD, adversarial networks expert (Priya)
    - Proprietary training data: 50B threat events
    - Only platform with predictive capabilities
  ],
)

#speaker-note[
  "Timing is critical. Generative AI has been weaponized by attackers.
  Traditional SIEM tools were never designed for this scale or sophistication.
  Cyber insurance premiums are up 300 percent - security is a board-level issue.
  We have the team, the data, and the technology to solve this."
]

// ============================================================================
// SLIDE 6: Business Model
// ============================================================================
== Business Model

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #text(fill: gold)[*Revenue Model*]

    #v(0.5em)

    - *Platform license*: \$250K/year base
    - *Per-endpoint*: \$15/month per protected asset
    - *Incident response*: \$50K retainer

    #v(1em)

    *Average Contract*: \$380K ACV
  ],
  [
    #text(fill: gold)[*Unit Economics*]

    #v(0.5em)

    - *Gross margin*: 82%
    - *CAC*: \$85K (enterprise sales)
    - *LTV*: \$1.5M (4-year avg retention)
    - *Payback*: 7 months

    #v(1em)

    *LTV:CAC Ratio*: 18:1
  ],
)

#speaker-note[
  "Enterprise security commands premium pricing. Our base platform is 250K annually.
  Per-endpoint charges scale with customer size.
  Average contract is 380K with 82 percent gross margins.
  LTV to CAC of 18 to 1 - exceptional for enterprise security."
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
      fill: card-bg,
      radius: 50%,
      width: 200pt,
      height: 200pt,
      stroke: 2pt + gold,
    )[
      #align(center + horizon)[
        #text(size: 32pt, weight: "bold", fill: gold)[\$156B]
        #v(0.3em)
        #text(size: 18pt, fill: light-text)[TAM]
        #v(0.2em)
        #text(size: 14pt, fill: rgb("#94a3b8"))[Global Cybersecurity]
      ]
    ],
    block(
      fill: card-bg,
      radius: 50%,
      width: 160pt,
      height: 160pt,
      stroke: 2pt + gold.lighten(30%),
    )[
      #align(center + horizon)[
        #text(size: 28pt, weight: "bold", fill: gold)[\$42B]
        #v(0.3em)
        #text(size: 16pt, fill: light-text)[SAM]
        #v(0.2em)
        #text(size: 13pt, fill: rgb("#94a3b8"))[AI-powered security]
      ]
    ],
    block(
      fill: card-bg,
      radius: 50%,
      width: 120pt,
      height: 120pt,
      stroke: 2pt + gold.lighten(50%),
    )[
      #align(center + horizon)[
        #text(size: 24pt, weight: "bold", fill: gold)[\$8B]
        #v(0.3em)
        #text(size: 14pt, fill: light-text)[SOM]
        #v(0.2em)
        #text(size: 12pt, fill: rgb("#94a3b8"))[5-year target]
      ]
    ],
  )
]

#v(1em)

#text(size: 24pt)[
  *Bottom-up*: 20K large enterprises x \$400K avg security AI spend = \$8B SOM
]

#speaker-note[
  "Global cybersecurity is 156 billion dollars.
  AI-powered security is 42 billion and growing 25 percent annually.
  Our 5-year target is 8 billion - 20,000 enterprises spending 400K on AI security."
]

// ============================================================================
// SLIDE 8: Team
// ============================================================================
== Team

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #text(fill: gold)[*Alex Rivera*]

    CEO & Co-founder

    #text(size: 22pt)[
      - VP Threat Intelligence, CrowdStrike (7 years)
      - Built Falcon threat detection engine
      - Previously: NSA Cyber Command
      - MS Computer Science, Carnegie Mellon
    ]
  ],
  [
    #text(fill: gold)[*Dr. Priya Sharma*]

    CTO & Co-founder

    #text(size: 22pt)[
      - PhD ML/Adversarial Networks, Stanford
      - Research Scientist, Google Brain (4 years)
      - 25+ papers, 8,000+ citations
      - IEEE Security Best Paper Award
    ]
  ],
)

#v(1em)

*Key Hires*: CISO (ex-JPMorgan), VP Sales (ex-Palo Alto Networks)

#speaker-note[
  "Alex built CrowdStrike's threat intelligence from the ground up.
  Priya is one of the world's leading researchers in adversarial machine learning.
  We've hired senior leadership from JPMorgan and Palo Alto Networks.
  This team has the expertise to win in enterprise security."
]

// ============================================================================
// SLIDE 9: The Ask
// ============================================================================
== The Ask

#align(center)[
  #text(size: 48pt, weight: "bold", fill: gold)[
    Raising \$25M Series A
  ]
]

#v(1em)

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    #text(fill: gold)[*Use of Funds*]

    #v(0.5em)

    - 40% R&D (next-gen models)
    - 35% Sales & marketing
    - 15% Customer success
    - 10% G&A
  ],
  [
    #text(fill: gold)[*18-Month Milestones*]

    #v(0.5em)

    - \$15M ARR (3x growth)
    - 60 enterprise customers
    - Launch predictive threat platform
    - International expansion (UK, DACH)
  ],
)

#v(1em)

#align(center)[
  #block(
    fill: card-bg,
    radius: 8pt,
    inset: 16pt,
    stroke: 1pt + gold.lighten(70%),
  )[
    #text(size: 24pt, fill: light-text)[
      *Lead investor*: Andreessen Horowitz | *Existing*: Lightspeed, Greylock
    ]
  ]
]

#speaker-note[
  "We're raising 25 million at Series A to accelerate growth.
  40 percent goes to R&D - we need to stay ahead of evolving threats.
  In 18 months, we'll triple revenue to 15 million ARR and expand internationally.
  Andreessen is leading with participation from Lightspeed and Greylock."
]

// ============================================================================
// SLIDE 10: Thank You
// ============================================================================
== Thank You

#align(center)[
  #v(1em)

  #text(size: 48pt, weight: "bold", fill: gold)[
    NeuralShield
  ]

  #v(0.5em)

  #text(size: 32pt, fill: light-text)[
    The Future of Enterprise Security
  ]

  #v(2em)

  #text(size: 28pt)[
    alex\@neuralshield.io

    neuralshield.io
  ]

  #v(1em)

  #text(size: 22pt, fill: rgb("#94a3b8"))[
    Technical deep-dive and competitive analysis in appendix
  ]
]

#speaker-note[
  "Thank you for your time. Security is a board-level concern now.
  NeuralShield gives enterprises the AI-powered defense they need.
  I'm happy to answer questions or dive into the technical architecture."
]
