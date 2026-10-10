# UI/UX review — 1.0.5

Reviewed on macOS 27 with the installed universal app, using screenshots and the accessibility tree. The native Settings toolbar, grouped forms, system colors, and menu-bar workflow are appropriate for a small macOS utility. The reported menu action crash was traced to creating a full-screen capture panel while AppKit was still dismissing the status menu. Overlay creation is now deferred until the menu action returns. A regression test opens and dismisses the panels without requesting screen access.

## Corrections

- Fixed a capture input regression introduced by making the initial overlay completely transparent. WindowServer routed clicks to the underlying app before a selection was drawn. The panel now has a 1% alpha input surface, explicitly accepts mouse input, and accepts the first click. A regression test queries WindowServer’s actual mouse-down target; it failed with the clear surface and passes with the fix. Another test sends a drag through the panel and verifies the resulting global rectangle and dismissal.

- Onboarding previously expanded to roughly 4,700 points high. Hosting views now use explicit window sizing, and onboarding has scrollable content with a fixed navigation footer. Both English onboarding pages and the Vietnamese permission page fit a 520 × 440 point content area.
- Shortcut recorders were absent from the accessibility tree. They now expose action-specific button labels and an accessibility press action, show keyboard focus, activate with Return or Space, cancel with Escape, and end recording when focus leaves. Return, Escape, and Tab navigation were checked in the installed app.
- Custom words now have explicit Remove buttons and focus the new input when Add Word is clicked. Stable row IDs and safe bindings prevent a crash when deleting the focused field. The exact add/focus/delete sequence was checked after correction.
- History empty messages overlay the list instead of appearing underneath an empty list. Searching with no matches has a native empty state. Copying a history entry gives clipboard feedback.
- The document-and-lens mark scales correctly in onboarding and About, and decorative marks are hidden from accessibility.
- User-facing settings use “Show capture results” and plain shortcut instructions. New copy is translated into Vietnamese.
- Result notifications measure wrapped text to avoid a fixed-height layout clipping translated messages. Capture keeps the display sharp and at full brightness. A system crosshair marks capture mode, the active drag area gets a translucent gray fill and contrasting edge, and a too-small selection reports that a larger area is needed. The capture surface contains no extra labels or controls. Result feedback fades after 1.6 seconds; actionable barcode feedback remains for five seconds.
- Unsupported regional OCR language codes now match the corresponding supported language before falling back to English, rather than the first alphabetical language.

## Scope and remaining manual checks

All six Settings tabs were inspected in English dark appearance; Vietnamese onboarding and Settings were inspected visually. The selection overlay creation and dismissal regression check passed, along with the OCR, QR barcode, image/PDF import, smart-link detection, shortcut mapping, collection, and text post-processing checks. A universal Release archive built successfully and its code signature was verified. This pass did not grant Screen Recording or Accessibility access, record private screen content, run a full VoiceOver session, or repeat multi-monitor/OCR coverage. The remaining capture, light appearance, history data, and assistive-technology scenarios are listed in TESTING.md.

The simplified capture flow follows TextSniper's documented start → select → paste sequence. Its installed capture overlay could not be inspected through UI automation: the app exposes no accessible window, and invoking the requested shortcut from Finder did not display the capture overlay. Verify the live overlay visually on the Mac.

Distribution remains Apple Development signed and not notarized; this UI update does not change that limitation.
