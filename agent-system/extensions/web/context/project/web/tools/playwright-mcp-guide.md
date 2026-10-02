# Playwright MCP Guide

Browser automation for web-implementation-agent via the `mcp__playwright__*` tool set. The
server is registered at user scope (see
`@.claude/context/patterns/mcp-server-ownership.md` for the registration/permission model) and
connected, exposing 24 `browser_*` tools.

## When to Drive a Browser

Driving a real browser is a heavier verification step than `pnpm build` -- reach for it only
when the plan actually needs one of these:

- **Screenshot / visual verification of a running app**: confirming a page renders correctly,
  a layout doesn't break at a viewport size, or a visual regression is fixed. Requires `pnpm dev`
  (or an equivalent running server) plus `browser_navigate` and `browser_snapshot` (preferred) or
  `browser_take_screenshot`.
- **Console and network inspection for debugging**: chasing a client-side error, a failed fetch,
  or an unexpected request, where static analysis or a build log can't show it. Use
  `browser_console_messages` and `browser_network_requests` after `browser_navigate`.
- **End-to-end UI checks**: verifying an interactive flow actually works end-to-end (a form
  submits, a menu opens, navigation lands on the right page) rather than just type-checking.
  Combine `browser_navigate`, `browser_click`, `browser_type`, `browser_find`, and
  `browser_wait_for`.

**Do NOT use Playwright** for anything `pnpm build` or `pnpm check` verifies on its own
(TypeScript errors, missing imports, build failures) -- that is strictly cheaper and doesn't need
a browser at all. Only reach for Playwright when the implementation plan explicitly includes a
visual-verification, browser-debugging, or end-to-end UI-check step.

## Tool Reference (24 tools)

| Category | Tools |
|---|---|
| Navigation | `browser_navigate`, `browser_navigate_back` |
| Page state | `browser_snapshot`, `browser_take_screenshot` |
| Interaction | `browser_click`, `browser_type`, `browser_fill_form`, `browser_hover`, `browser_drag`, `browser_drop`, `browser_select_option`, `browser_press_key` |
| Finding / waiting | `browser_find`, `browser_wait_for` |
| Viewport / tabs | `browser_resize`, `browser_tabs`, `browser_close` |
| Dialogs | `browser_handle_dialog` |
| Debugging | `browser_console_messages`, `browser_network_request`, `browser_network_requests` |
| Escape hatches (unsafe tier) | `browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe` |

There is no `browser_verify_text_visible` tool. Map that intent onto real tools instead:

- To assert an element is present/visible right now: `browser_find`.
- To assert text becomes visible within a timeout (e.g. after an async action): `browser_wait_for`.

## Permission Tiers -- Unprompted vs. Prompting

Of the 24 tools, only 9 are allowlisted, in user-scope `~/.claude/settings.json` (written by a
home-manager activation block in a separate configuration repository), and therefore run without
an interactive permission prompt today:

`browser_navigate`, `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`,
`browser_network_requests`, `browser_click`, `browser_type`, `browser_find`, `browser_wait_for`.

The remaining 15 tools -- including `browser_navigate_back`, `browser_fill_form`,
`browser_hover`, `browser_drag`, `browser_drop`, `browser_select_option`, `browser_press_key`,
`browser_resize`, `browser_tabs`, `browser_close`, `browser_handle_dialog`,
`browser_network_request` (singular), and the three escape hatches
`browser_evaluate`, `browser_file_upload`, `browser_run_code_unsafe` -- are not allowlisted and
will interrupt an autonomous run with a permission prompt.

**Never write a plan step or a verification instruction that depends on `browser_evaluate`,
`browser_file_upload`, or `browser_run_code_unsafe`.** These three are deliberately excluded from
the always-allow list because they run arbitrary code or read arbitrary local files -- the
enumeration in user-scope `~/.claude/settings.json` is intentional, not an oversight to "fix" by
widening it.
Depending on one of them reintroduces the autonomous-run stall the permission split exists to
prevent. Prefer the 9 unprompted tools for anything a plan can be satisfied with; treat every
other tool (prompting but not one of the three escape hatches) as usable only when a human is
present to clear the prompt.

## Usage Conditions

- Prefer accessibility snapshots (`browser_snapshot`) over screenshots
  (`browser_take_screenshot`) -- lower token cost, and more directly useful for asserting
  structure and text content than an image.
- Only invoke Playwright tools when the implementation plan includes a visual-verification,
  browser-debugging, or end-to-end UI-check step -- see "When to Drive a Browser" above.
- Do not use Playwright for anything `pnpm build` alone can verify.
