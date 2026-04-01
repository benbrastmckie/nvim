<!-- CONTENT: ask-centered
     SLIDE_TYPE: ask
     LAYOUT: center
     COMPATIBLE_MODES: INVESTOR, LIGHTNING
     CONTENT_SLOTS: raise_amount, allocation_1, allocation_2, allocation_3, milestone
     ANIMATIONS: scale-in-pop for amount, v-clicks for allocation
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: center
---

# The Ask

<div
  v-motion
  :initial="{ scale: 0, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 300, damping: 20 } }"
  class="text-5xl font-bold text-[var(--slidev-accent)] mt-4"
>
[SLOT: raise_amount]
</div>

<v-clicks class="mt-8">

- [SLOT: allocation_1]
- [SLOT: allocation_2]
- [SLOT: allocation_3]

</v-clicks>

<div v-click class="mt-6 text-sm opacity-70">
[SLOT: milestone]
</div>

<!-- Speaker: State the amount clearly. Walk through allocation. Close with the milestone it enables. -->
