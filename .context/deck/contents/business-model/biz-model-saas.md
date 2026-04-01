<!-- CONTENT: biz-model-saas
     SLIDE_TYPE: business-model
     LAYOUT: default
     COMPATIBLE_MODES: INVESTOR, UPDATE
     CONTENT_SLOTS: arr_value, mrr_growth, churn_rate, arpu, cac, ltv
     ANIMATIONS: metric-cascade
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: default
---

# SaaS Metrics

<div class="grid grid-cols-3 gap-6 mt-8">

<div v-motion :initial="{ y: 40, opacity: 0 }" :enter="{ y: 0, opacity: 1, transition: { delay: 0 } }" class="text-center">
  <div class="text-3xl font-bold text-[var(--slidev-accent)]">[SLOT: arr_value]</div>
  <div class="text-sm opacity-70">ARR</div>
</div>

<div v-motion :initial="{ y: 40, opacity: 0 }" :enter="{ y: 0, opacity: 1, transition: { delay: 200 } }" class="text-center">
  <div class="text-3xl font-bold text-[var(--slidev-accent)]">[SLOT: mrr_growth]</div>
  <div class="text-sm opacity-70">MRR Growth</div>
</div>

<div v-motion :initial="{ y: 40, opacity: 0 }" :enter="{ y: 0, opacity: 1, transition: { delay: 400 } }" class="text-center">
  <div class="text-3xl font-bold text-[var(--slidev-accent)]">[SLOT: churn_rate]</div>
  <div class="text-sm opacity-70">Churn Rate</div>
</div>

</div>

<div class="grid grid-cols-3 gap-6 mt-6">

<div v-click class="text-center">
  <div class="text-xl font-semibold">[SLOT: arpu]</div>
  <div class="text-xs opacity-60">ARPU</div>
</div>

<div v-click class="text-center">
  <div class="text-xl font-semibold">[SLOT: cac]</div>
  <div class="text-xs opacity-60">CAC</div>
</div>

<div v-click class="text-center">
  <div class="text-xl font-semibold">[SLOT: ltv]</div>
  <div class="text-xs opacity-60">LTV</div>
</div>

</div>

<!-- Speaker: Top row is the headline. Bottom row supports the story. Emphasize growth trend. -->
