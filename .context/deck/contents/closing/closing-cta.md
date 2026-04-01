<!-- CONTENT: closing-cta
     SLIDE_TYPE: closing
     LAYOUT: center
     COMPATIBLE_MODES: INVESTOR, PARTNERSHIP, DEMO
     CONTENT_SLOTS: cta_headline, cta_description, next_step_1, next_step_2, contact_email
     ANIMATIONS: scale-in-pop for headline
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: center
---

<div
  v-motion
  :initial="{ scale: 0.8, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 300, damping: 25 } }"
>

# [SLOT: cta_headline]

<p class="text-lg opacity-80 mt-4">[SLOT: cta_description]</p>

</div>

<v-clicks class="mt-8">

- [SLOT: next_step_1]
- [SLOT: next_step_2]

</v-clicks>

<div v-click class="mt-6 text-sm opacity-50">
[SLOT: contact_email]
</div>

<!-- Speaker: End with energy. Clear next steps. Make it easy to follow up. -->
