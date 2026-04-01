<!-- CONTENT: market-tam-sam-som
     SLIDE_TYPE: market
     LAYOUT: default
     COMPATIBLE_MODES: INVESTOR, PARTNERSHIP
     CONTENT_SLOTS: market_title, tam_value, tam_desc, sam_value, sam_desc, som_value, som_desc, growth_rate
     ANIMATIONS: v-clicks staggered reveal
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: default
---

# [SLOT: market_title]

<div class="grid grid-cols-3 gap-6 mt-8">

<div v-click class="text-center p-4">
  <div class="text-3xl font-bold text-[var(--slidev-accent)]">[SLOT: tam_value]</div>
  <div class="text-sm font-semibold mt-1">TAM</div>
  <div class="text-xs opacity-60 mt-1">[SLOT: tam_desc]</div>
</div>

<div v-click class="text-center p-4">
  <div class="text-3xl font-bold text-[var(--slidev-accent)]">[SLOT: sam_value]</div>
  <div class="text-sm font-semibold mt-1">SAM</div>
  <div class="text-xs opacity-60 mt-1">[SLOT: sam_desc]</div>
</div>

<div v-click class="text-center p-4">
  <div class="text-3xl font-bold text-[var(--slidev-accent)]">[SLOT: som_value]</div>
  <div class="text-sm font-semibold mt-1">SOM</div>
  <div class="text-xs opacity-60 mt-1">[SLOT: som_desc]</div>
</div>

</div>

<div v-click class="mt-4 text-center text-sm opacity-70">
Market growing at [SLOT: growth_rate] CAGR
</div>

<!-- Speaker: Start big (TAM), narrow down. Show you understand your beachhead. -->
