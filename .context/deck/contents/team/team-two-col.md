<!-- CONTENT: team-two-col
     SLIDE_TYPE: team
     LAYOUT: two-cols
     COMPATIBLE_MODES: INVESTOR, PARTNERSHIP
     CONTENT_SLOTS: founder_1_name, founder_1_role, founder_1_bio, founder_2_name, founder_2_role, founder_2_bio
     ANIMATIONS: v-motion slide-in-below per column
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: two-cols
---

# Team

<div v-motion :initial="{ y: 60, opacity: 0 }" :enter="{ y: 0, opacity: 1 }" class="mt-8">

### [SLOT: founder_1_name]
**[SLOT: founder_1_role]**

[SLOT: founder_1_bio]

</div>

::right::

<div v-motion :initial="{ y: 60, opacity: 0 }" :enter="{ y: 0, opacity: 1, transition: { delay: 200 } }" class="mt-16">

### [SLOT: founder_2_name]
**[SLOT: founder_2_role]**

[SLOT: founder_2_bio]

</div>

<!-- Speaker: Focus on relevant experience. Why is this team uniquely qualified? -->
