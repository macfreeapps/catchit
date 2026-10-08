# Catch It manual test checklist

Run the automated geometry and collection tests first:

```sh
xcodebuild -project CatchIt.xcodeproj -scheme CatchIt -configuration Debug test
```

## Capture and permission flow

- [ ] Start Catch It from Xcode. On first launch, review both onboarding pages, open Screen Recording settings, then continue.
- [ ] Click the status icon and choose **Catch Text**. Confirm each connected display dims and shows a crosshair; drag a rectangle and confirm recognized text is copied.
- [ ] Right-click the status icon and confirm capture starts without opening the menu.
- [ ] Option-click the status icon and confirm capture starts without opening the menu.
- [ ] Start capture and press **Escape**. Confirm it closes without changing the clipboard.
- [ ] Select an area containing no readable text. Confirm the HUD says **No text found** and the previous clipboard text remains unchanged.
- [ ] Revoke Screen Recording access in System Settings, attempt capture, and confirm Catch It shows a helpful alert with a working settings button. Re-enable access and relaunch.

## Displays and app surfaces

- [ ] Test on a Retina display and a non-Retina display. Check the selection dimensions, captured sharpness, and OCR output.
- [ ] Test with two displays. Make a selection on each display and confirm the correct display is captured.
- [ ] Test over a full-screen app and across multiple Spaces. Confirm the overlay appears above the app and cancels cleanly.
- [ ] Test the overlay and Settings in Light and Dark appearance.
- [ ] Select a small, high-density text region. Confirm the enlarged OCR path recognizes it without writing an image file.
- [ ] Pause a video frame or slideshow, use **Catch Same Area**, and confirm it reuses the prior display and rectangle.

## Formatting and recognition

- [ ] In **Settings → General**, enable **Keep line breaks**, capture multi-line text, and confirm lines remain separated.
- [ ] Turn **Keep line breaks** off. Capture wrapped prose containing a line-end hyphen and confirm it joins into a paragraph; verify an em dash remains intact.
- [ ] Capture a page with a clear two-column layout and confirm output reads the left column before the right.
- [ ] Capture a number list with isolated one-digit rows and confirm no digits are dropped.
- [ ] In **Settings → Recognition**, try a supported primary language with auto-detection off, then on. Try vertical Chinese, Japanese, or Korean text when available.
- [ ] Add a jargon term in **Settings → Custom Words** and confirm it appears in Vision’s custom-word list after saving.
- [ ] Enable **Code / symbols mode** and capture a code sample, URL, or identifier. Compare against normal language correction.
- [ ] During capture, press **L**, **A**, and **S** and verify the overlay chips change and the resulting capture uses those values.

## Barcode, links, clipboard, and speech

- [ ] Choose **Catch Barcode** and scan a QR code and a standard barcode. Confirm multiple values are copied one per line.
- [ ] Scan a text-only selection in barcode mode. Choose **Read text instead** in the HUD and confirm OCR output is copied.
- [ ] Scan a QR code containing a URL. Confirm it is displayed in the HUD with an **Open link** action, and is not launched while automatic link opening is off.
- [ ] Turn on **Open detected links automatically**, capture a URL, and confirm macOS opens the detected link in the default app. Turn the option off again.
- [ ] Enable **Additive Mode**, capture several snippets, and confirm the configured newline, blank-line, or space separator is used and the full collection survives quitting and reopening Catch It.
- [ ] Clear the collection, choose **Undo Clear Collection** within 30 seconds, and confirm the collection is restored. Confirm undo disappears after 30 seconds.
- [ ] Copy unrelated text in another app, clear Catch It’s collection, and confirm unrelated clipboard contents remain intact.
- [ ] Enable **Clear collection after I paste**. Confirm macOS asks for Accessibility access only at this point. Deny access and verify the feature stays off; then grant access, paste a collection into another app, and confirm Catch It clears it after the paste.
- [ ] Enable **Read text after capture**, choose an installed voice and rate, and capture text. Confirm speech starts, can be stopped from the menu or **Settings → Speech**, and the selected voice is used.
- [ ] Use **Capture and Speak** and verify it reads the new capture even when automatic reading is off.

## Imports and history

- [ ] Choose **Import from iPhone or iPad** and, with a nearby compatible device available, take a photo or scan a document. Confirm the imported image is OCRed and not saved by Catch It.
- [ ] Choose **Open Image or PDF…** and open a text image. Confirm its text is copied.
- [ ] Open a multi-page PDF in Preview as a reference, then use **Open Image or PDF…** to open the PDF in Catch It. Confirm page text is recognized in page order.
- [ ] Confirm **Save capture history** is off by default and no history window appears in the menu.
- [ ] Enable history, capture text, search for it in **History…**, click the result to copy it, then clear history and confirm entries are removed.

## Settings and lifecycle

- [ ] Record and change each shortcut in **Settings → Shortcuts**. Confirm the displayed modifier symbols match the key combination and the new shortcut works globally.
- [ ] Create a duplicate shortcut and confirm the settings page warns that shortcuts must be unique; resolve the conflict.
- [ ] Toggle **Launch Catch It at login** and confirm the setting reflects the macOS login-item status.
- [ ] Navigate each Settings tab with the keyboard and VoiceOver. Confirm controls have useful labels and hints.
- [ ] Quit and relaunch Catch It; confirm preferences and the last capture area are restored.
