// Minimal Light Theme - Investor Pitch Deck Example
// Mock Startup: ClearView Analytics - Data Analytics for Startups
//
// Colors: Charcoal (#2d3748), Medium Gray (#4a5568), Blue (#3182ce)
// Typography: Montserrat headings, Inter body
// Best for: Data-focused, analytics, enterprise software

#import "@preview/touying:0.6.3": *
#import themes.simple: *

// Theme configuration - minimal light
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [ClearView Analytics],
    subtitle: [Real-time Metrics for High-Growth Startups],
    author: [James Park & Elena Vasquez],
    date: datetime.today(),
  ),
  config-colors(
    primary: rgb("#2d3748"),
    secondary: rgb("#4a5568"),
    neutral: rgb("#f7fafc"),
  ),
)

// Light background with subtle off-white
#set page(fill: rgb("#f7fafc"))

// Typography settings
#set text(font: "Inter", size: 30pt, fill: rgb("#1a202c"))
#show heading.where(level: 1): set text(font: "Montserrat", size: 48pt, weight: "bold", fill: rgb("#2d3748"))
#show heading.where(level: 2): set text(font: "Montserrat", size: 40pt, weight: "bold", fill: rgb("#2d3748"))

// Color palette
#let charcoal = rgb("#2d3748")
#let gray = rgb("#4a5568")
#let blue = rgb("#3182ce")
#let text-color = rgb("#1a202c")
#let bg = rgb("#f7fafc")

// ============================================================================
// SLIDE 1: Title
// ============================================================================
= ClearView Analytics

#align(center)[
  #text(size: 36pt, fill: gray)[
    Real-time Metrics for High-Growth Startups
  ]

  #v(2em)

  #text(size: 24pt, fill: rgb("#718096"))[
    Seed Round | Q1 2026
  ]
]

#speaker-note[
  "Thank you for meeting with us. I'm James Park, CEO of ClearView Analytics.
  We help startups understand their metrics in real-time so they can grow faster.
  Elena Vasquez, our CTO, previously led data infrastructure at Stripe."
]

// ============================================================================
// SLIDE 2: Problem
// ============================================================================
== The Problem

#v(0.5em)

#text(size: 36pt, weight: "bold", fill: charcoal)[
  Startups fly blind on metrics until it's too late
]

#v(1.5em)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 2em,
  align(center)[
    #text(size: 56pt, weight: "bold", fill: blue)[68%]
    #v(0.3em)
    #text(size: 20pt, fill: gray)[
      of startups don't know their real-time burn rate
    ]
  ],
  align(center)[
    #text(size: 56pt, weight: "bold", fill: blue)[3 weeks]
    #v(0.3em)
    #text(size: 20pt, fill: gray)[
      average lag in financial reporting
    ]
  ],
  align(center)[
    #text(size: 56pt, weight: "bold", fill: blue)[42%]
    #v(0.3em)
    #text(size: 20pt, fill: gray)[
      of Series A fails cite metrics blindspots
    ]
  ],
)

#speaker-note[
  "Here's the problem: 68 percent of startups don't know their real-time burn rate.
  Financial reporting lags by an average of 3 weeks.
  42 percent of Series A failures cite metrics blindspots as a contributing factor.
  Founders need real-time visibility, not monthly spreadsheets."
]

// ============================================================================
// SLIDE 3: Solution
// ============================================================================
== Our Solution

#v(0.5em)

#text(size: 36pt, weight: "bold", fill: charcoal)[
  One dashboard. Every metric. Real-time.
]

#v(1.5em)

#grid(
  columns: (1fr, 1fr),
  gutter: 3em,
  [
    #text(fill: blue, weight: "bold")[Connect]
    #v(0.5em)
    #text(size: 26pt)[
      Integrates with your existing tools in minutes:
      Stripe, QuickBooks, HubSpot, Mixpanel, and 50+ more
    ]

    #v(1em)

    #text(fill: blue, weight: "bold")[Automate]
    #v(0.5em)
    #text(size: 26pt)[
      No manual data entry. Metrics update automatically
      as transactions occur.
    ]
  ],
  [
    #text(fill: blue, weight: "bold")[Analyze]
    #v(0.5em)
    #text(size: 26pt)[
      Pre-built dashboards for MRR, CAC, LTV,
      runway, and cohort analysis
    ]

    #v(1em)

    #text(fill: blue, weight: "bold")[Alert]
    #v(0.5em)
    #text(size: 26pt)[
      Proactive notifications when metrics trend
      outside healthy ranges
    ]
  ],
)

#speaker-note[
  "ClearView connects to your existing tools - Stripe, QuickBooks, your CRM.
  Everything syncs automatically. No spreadsheets, no manual data entry.
  We provide pre-built dashboards for the metrics that matter.
  And we alert you when something needs attention."
]

// ============================================================================
// SLIDE 4: Traction
// ============================================================================
== Traction

#v(0.5em)

#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  gutter: 1.5em,
  align(center)[
    #text(size: 44pt, weight: "bold", fill: blue)[\$420K]
    #v(0.3em)
    #text(size: 18pt, fill: gray)[ARR]
  ],
  align(center)[
    #text(size: 44pt, weight: "bold", fill: blue)[180]
    #v(0.3em)
    #text(size: 18pt, fill: gray)[Customers]
  ],
  align(center)[
    #text(size: 44pt, weight: "bold", fill: blue)[15%]
    #v(0.3em)
    #text(size: 18pt, fill: gray)[MoM Growth]
  ],
  align(center)[
    #text(size: 44pt, weight: "bold", fill: blue)[92%]
    #v(0.3em)
    #text(size: 18pt, fill: gray)[Retention]
  ],
)

#v(1.5em)

#line(length: 100%, stroke: 0.5pt + rgb("#e2e8f0"))

#v(1em)

*Customer Profile*: Series Seed to Series B startups, \$500K-\$20M revenue

*Notable Users*: 12 YC companies, 8 Techstars graduates

#speaker-note[
  "We launched 10 months ago and have 420K ARR with 180 customers.
  We're growing 15 percent month over month with 92 percent retention.
  Our sweet spot is Seed to Series B startups.
  12 YC companies use ClearView for their board reporting."
]

// ============================================================================
// SLIDE 5: Why Us / Why Now
// ============================================================================
== Why Us / Why Now

#v(0.5em)

#grid(
  columns: (1fr, 1fr),
  gutter: 3em,
  [
    #text(fill: blue, weight: "bold", size: 32pt)[Why Now]

    #v(1em)

    - API economy enables real-time integration
    - VC expectations for data-driven founders
    - Spreadsheet fatigue hitting critical mass
    - Remote work demands shared dashboards
  ],
  [
    #text(fill: blue, weight: "bold", size: 32pt)[Why Us]

    #v(1em)

    - Team: Built Stripe's analytics platform
    - Product: Setup in 10 minutes, not 10 weeks
    - Focus: Built for startups, not enterprises
    - Community: 2,000+ founders in Slack group
  ],
)

#speaker-note[
  "The API economy makes this possible now. Every tool has an API.
  VCs expect data-driven decision making from day one.
  We built Stripe's internal analytics - we know this problem deeply.
  And we're laser-focused on startups, not trying to serve enterprises."
]

// ============================================================================
// SLIDE 6: Business Model
// ============================================================================
== Business Model

#v(0.5em)

#grid(
  columns: (1fr, 1fr),
  gutter: 3em,
  [
    #text(fill: blue, weight: "bold", size: 28pt)[Pricing Tiers]

    #v(1em)

    #table(
      columns: (1fr, 1fr),
      stroke: 0.5pt + rgb("#e2e8f0"),
      inset: 12pt,
      [*Starter*], [\$99/mo],
      [*Growth*], [\$299/mo],
      [*Scale*], [\$799/mo],
    )

    #v(0.5em)

    *Average*: \$195/month (\$2,340 ACV)
  ],
  [
    #text(fill: blue, weight: "bold", size: 28pt)[Unit Economics]

    #v(1em)

    #table(
      columns: (1fr, 1fr),
      stroke: 0.5pt + rgb("#e2e8f0"),
      inset: 12pt,
      [*Gross Margin*], [88%],
      [*CAC*], [\$180],
      [*LTV*], [\$4,200],
      [*Payback*], [2.3 months],
    )

    *LTV:CAC*: 23:1
  ],
)

#speaker-note[
  "We have three pricing tiers from 99 to 799 per month.
  Average customer pays about 200 per month.
  88 percent gross margins with a 23 to 1 LTV to CAC ratio.
  Payback period is just over 2 months - extremely capital efficient."
]

// ============================================================================
// SLIDE 7: Market Opportunity
// ============================================================================
== Market Opportunity

#v(0.5em)

#align(center)[
  #grid(
    columns: (1fr, 1fr, 1fr),
    gutter: 2em,
    [
      #block(
        width: 100%,
        inset: 20pt,
      )[
        #align(center)[
          #text(size: 44pt, weight: "bold", fill: blue)[\$8.2B]
          #v(0.3em)
          #text(size: 18pt, fill: charcoal)[*TAM*]
          #v(0.2em)
          #text(size: 14pt, fill: gray)[Business Intelligence]
        ]
      ]
    ],
    [
      #block(
        width: 100%,
        inset: 20pt,
      )[
        #align(center)[
          #text(size: 44pt, weight: "bold", fill: blue)[\$1.8B]
          #v(0.3em)
          #text(size: 18pt, fill: charcoal)[*SAM*]
          #v(0.2em)
          #text(size: 14pt, fill: gray)[SMB/Startup segment]
        ]
      ]
    ],
    [
      #block(
        width: 100%,
        inset: 20pt,
      )[
        #align(center)[
          #text(size: 44pt, weight: "bold", fill: blue)[\$180M]
          #v(0.3em)
          #text(size: 18pt, fill: charcoal)[*SOM*]
          #v(0.2em)
          #text(size: 14pt, fill: gray)[5-year target]
        ]
      ]
    ],
  )
]

#v(1em)

#line(length: 100%, stroke: 0.5pt + rgb("#e2e8f0"))

#v(0.5em)

#text(size: 22pt)[
  *Calculation*: 600K funded startups globally x 30% addressable x \$1,000 avg spend = \$180M
]

#speaker-note[
  "Business intelligence is an 8 billion dollar market.
  Our segment - SMBs and startups - is 1.8 billion.
  We're targeting 180 million in 5 years based on 600,000 funded startups worldwide."
]

// ============================================================================
// SLIDE 8: Team
// ============================================================================
== Team

#v(0.5em)

#grid(
  columns: (1fr, 1fr),
  gutter: 3em,
  [
    #text(fill: blue, weight: "bold", size: 28pt)[James Park]

    CEO & Co-founder

    #v(0.5em)

    #text(size: 22pt, fill: text-color)[
      - Product Lead, Stripe Dashboard (4 years)
      - Built metrics used by 100K+ businesses
      - Stanford MBA, Berkeley CS undergrad
      - 2x founder (1 acquired)
    ]
  ],
  [
    #text(fill: blue, weight: "bold", size: 28pt)[Elena Vasquez]

    CTO & Co-founder

    #v(0.5em)

    #text(size: 22pt, fill: text-color)[
      - Staff Engineer, Stripe Data (5 years)
      - Architected real-time analytics pipeline
      - MS Computer Science, MIT
      - Contributor to Apache Kafka
    ]
  ],
)

#v(1em)

*Team*: 8 full-time, 6 engineers (all ex-Stripe, ex-Segment, ex-Mixpanel)

#speaker-note[
  "James led the Stripe Dashboard product that serves 100,000+ businesses.
  Elena built Stripe's real-time data infrastructure.
  Our team of 8 includes 6 engineers, all from top analytics companies.
  We've built this exact product before - at scale."
]

// ============================================================================
// SLIDE 9: The Ask
// ============================================================================
== The Ask

#v(0.5em)

#align(center)[
  #text(size: 48pt, weight: "bold", fill: charcoal)[
    Raising \$3M Seed
  ]
]

#v(1.5em)

#grid(
  columns: (1fr, 1fr),
  gutter: 3em,
  [
    #text(fill: blue, weight: "bold", size: 26pt)[Use of Funds]

    #v(0.5em)

    #grid(
      columns: (auto, 1fr),
      gutter: 8pt,
      [60%], [Engineering (scale platform)],
      [25%], [Sales & marketing],
      [10%], [Customer success],
      [5%], [Operations],
    )
  ],
  [
    #text(fill: blue, weight: "bold", size: 26pt)[18-Month Milestones]

    #v(0.5em)

    - \$2M ARR (5x growth)
    - 800 customers
    - Enterprise tier launch
    - 25 new integrations
  ],
)

#v(1em)

#align(center)[
  #text(size: 22pt, fill: gray)[
    *Committed*: \$1.2M from Y Combinator, FundersClub, angel syndicate
  ]
]

#speaker-note[
  "We're raising 3 million dollars at seed.
  60 percent goes to engineering to scale the platform.
  In 18 months, we'll hit 2 million ARR with 800 customers.
  We have 1.2 million already committed from YC and FundersClub."
]

// ============================================================================
// SLIDE 10: Thank You
// ============================================================================
== Thank You

#v(1em)

#align(center)[
  #text(size: 48pt, weight: "bold", fill: charcoal)[
    ClearView Analytics
  ]

  #v(0.5em)

  #text(size: 32pt, fill: gray)[
    Metrics clarity for founders
  ]

  #v(2em)

  #text(size: 28pt, fill: text-color)[
    james\@clearview.io

    clearview.io
  ]

  #v(1em)

  #text(size: 20pt, fill: rgb("#718096"))[
    Demo available | Product roadmap in appendix
  ]
]

#speaker-note[
  "Thank you for your time. We'd love to show you a live demo.
  Founders deserve real-time visibility into their business.
  We're building the dashboard every startup should have."
]
