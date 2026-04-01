<!-- CONTENT: ask-milestone
     SLIDE_TYPE: ask
     LAYOUT: default
     COMPATIBLE_MODES: INVESTOR, UPDATE
     CONTENT_SLOTS: raise_amount, use_of_funds, milestone_1, milestone_1_date, milestone_2, milestone_2_date, milestone_3, milestone_3_date
     ANIMATIONS: v-clicks for milestones
     IMPORT: Copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->

---
layout: default
---

# The Ask

<div class="text-4xl font-bold text-[var(--slidev-accent)]">
[SLOT: raise_amount]
</div>

<div v-click class="mt-2 text-lg opacity-80">
[SLOT: use_of_funds]
</div>

<div class="mt-8">

### Milestones

<v-clicks>

- **[SLOT: milestone_1_date]**: [SLOT: milestone_1]
- **[SLOT: milestone_2_date]**: [SLOT: milestone_2]
- **[SLOT: milestone_3_date]**: [SLOT: milestone_3]

</v-clicks>

</div>

<!-- Speaker: Amount first, then what it buys. Milestones show you have a plan. -->
