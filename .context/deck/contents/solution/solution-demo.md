<!-- CONTENT: solution-demo
     SLIDE_TYPE: solution
     LAYOUT: image-right
     COMPATIBLE_MODES: INVESTOR, DEMO, LIGHTNING
     CONTENT_SLOTS: solution_headline, solution_desc, key_differentiator, screenshot_url
     ANIMATIONS: v-click for text, image always visible
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: image-right
image: [SLOT: screenshot_url]
---

# [SLOT: solution_headline]

<div v-click class="mt-4">
[SLOT: solution_desc]
</div>

<div v-click class="mt-6 p-4 rounded-lg bg-[var(--slidev-accent)] bg-opacity-10">
<span class="font-bold text-[var(--slidev-accent)]">[SLOT: key_differentiator]</span>
</div>

<!-- Speaker: Show don't tell. Point to the screenshot. Emphasize the key differentiator. -->
