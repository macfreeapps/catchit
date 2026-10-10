# UI/UX review — 1.0.2

Reviewed on macOS 27 with the installed universal app, using screenshots and the accessibility tree. The native Settings toolbar, grouped forms, system colors, and menu-bar workflow are appropriate for a small macOS utility. The reported menu action crash was traced to creating a full-screen capture panel while AppKit was still dismissing the status menu. Overlay creation is now deferred until the menu action returns. A regression test opens and dismisses the panels without requesting screen access.

## Corrections

- Onboarding previously expanded to roughly 4,700 points high. Hosting views now use explicit window sizing, and onboarding has scrollable content with a fixed navigation footer. Both English onboarding pages and the Vietnamese permission page fit a 520 × 440 point content area.
- Shortcut recorders were absent from the accessibility tree. They now expose action-specific button labels and an accessibility press action, show keyboard focus, activate with Return or Space, cancel with Escape, and end recording when focus leaves. Return, Escape, and Tab navigation were checked in the installed app.
- Custom words now have explicit Remove buttons and focus the new input when Add Word is clicked. Stable row IDs and safe bindings prevent a crash when deleting the focused field. The exact add/focus/delete sequence was checked after correction.
- History empty messages overlay the list instead of appearing underneath an empty list. Searching with no matches has a native empty state. Copying a history entry gives clipboard feedback.
- The document-and-lens mark scales correctly in onboarding and About, and decorative marks are hidden from accessibility.
- User-facing settings use “Show capture results” and plain shortcut instructions. New copy is translated into Vietnamese.
- Result notifications measure wrapped text to avoid a fixed-height layout clipping translated messages. Feedback remains visible for three seconds; notifications with actions remain for eight seconds.
- Unsupported regional OCR language codes now match the corresponding supported language before falling back to English, rather than the first alphabetical language.

## Scope and remaining manual checks

All six Settings tabs were inspected in English dark appearance; Vietnamese onboarding and Settings were inspected visually. The selection overlay creation and dismissal regression check passed, along with all eight existing unit tests (nine total). A universal Release archive built successfully and its code signature was verified. This pass did not grant Screen Recording or Accessibility access, record private screen content, run a full VoiceOver session, or repeat multi-monitor/OCR coverage. The remaining capture, light appearance, history data, and assistive-technology scenarios are listed in TESTING.md.

Distribution remains Apple Development signed and not notarized; this UI update does not change that limitation.
