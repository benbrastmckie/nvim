<!-- CONTENT: traction-chart
     SLIDE_TYPE: traction
     LAYOUT: default
     COMPATIBLE_MODES: INVESTOR, UPDATE
     CONTENT_SLOTS: chart_title, chart_description, growth_rate
     ANIMATIONS: v-click for description
     IMPORT: Copy directly into slides.md (replace mermaid with actual data)
     LAST_UPDATED: 2026-04-01
-->

---
layout: default
---

# [SLOT: chart_title]

```mermaid
graph LR
  subgraph Revenue Growth
    Q1["Q1"] --> Q2["Q2"]
    Q2 --> Q3["Q3"]
    Q3 --> Q4["Q4"]
  end
```

<div v-click class="mt-4 text-lg">
[SLOT: chart_description]
</div>

<div v-click class="mt-2 text-3xl font-bold text-[var(--slidev-accent)]">
[SLOT: growth_rate] growth
</div>

<!-- Speaker: Walk through the growth trajectory. Emphasize the trend, not individual data points. -->
