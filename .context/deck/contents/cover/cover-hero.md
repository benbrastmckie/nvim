<!-- CONTENT: cover-hero
     SLIDE_TYPE: cover
     LAYOUT: cover
     COMPATIBLE_MODES: INVESTOR, DEMO, PARTNERSHIP
     CONTENT_SLOTS: company_name, tagline, hero_image_url
     ANIMATIONS: v-motion scale entrance
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: cover
class: text-center
---

<div
  v-motion
  :initial="{ scale: 0.9, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1 }"
>

# [SLOT: company_name]

<p class="text-2xl opacity-80 mt-4">
[SLOT: tagline]
</p>

</div>

<style>
h1 { font-size: 4em; font-weight: 800; }
</style>

<!-- Speaker: Open strong. State company name and one-liner. Let the visual speak. -->
