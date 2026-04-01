<!-- CONTENT: traction-metrics
     SLIDE_TYPE: traction
     LAYOUT: fact
     COMPATIBLE_MODES: INVESTOR, LIGHTNING, UPDATE
     CONTENT_SLOTS: metric_1_value, metric_1_label, metric_2_value, metric_2_label, metric_3_value, metric_3_label, context_note
     ANIMATIONS: metric-cascade (staggered v-motion)
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: fact
---

# Traction

<div class="grid grid-cols-3 gap-8 mt-8">
  <div v-motion :initial="{ scale: 0.8, opacity: 0, y: 40 }" :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 0 } }">
    <div class="text-4xl font-bold text-[var(--slidev-accent)]">[SLOT: metric_1_value]</div>
    <div class="text-sm opacity-70 mt-2">[SLOT: metric_1_label]</div>
  </div>
  <div v-motion :initial="{ scale: 0.8, opacity: 0, y: 40 }" :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 300 } }">
    <div class="text-4xl font-bold text-[var(--slidev-accent)]">[SLOT: metric_2_value]</div>
    <div class="text-sm opacity-70 mt-2">[SLOT: metric_2_label]</div>
  </div>
  <div v-motion :initial="{ scale: 0.8, opacity: 0, y: 40 }" :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 600 } }">
    <div class="text-4xl font-bold text-[var(--slidev-accent)]">[SLOT: metric_3_value]</div>
    <div class="text-sm opacity-70 mt-2">[SLOT: metric_3_label]</div>
  </div>
</div>

<div v-click class="mt-6 text-sm opacity-60 text-center">
[SLOT: context_note]
</div>

<!-- Speaker: Let the numbers speak. Pause between each metric reveal. End with context. -->
