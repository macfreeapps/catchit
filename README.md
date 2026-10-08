# Catch It

Catch It is a native macOS menu-bar utility for copying text or barcode contents from a selected screen area. It uses ScreenCaptureKit and Apple Vision locally, with no third-party runtime packages.

## Build and run

### Install a release

Download `CatchIt-1.0.0-universal.dmg` from [GitHub Releases](https://github.com/macfreeapps/catchit/releases/latest), open it, and drag **Catch It** to Applications. Catch It requires macOS 14 or later and supports Apple Silicon and Intel Macs.

This release is signed with an Apple Development certificate and is not notarized by Apple. If macOS blocks the first launch, open **System Settings → Privacy & Security** and choose **Open Anyway** for Catch It. The certificate expires on 28 June 2027; because the signature has no secure timestamp, a new build may be needed after that date.

### Build from source

1. Open `CatchIt.xcodeproj` in Xcode and run the **CatchIt** scheme on macOS 14 or later.
2. On first launch, read the short permission and privacy walkthrough.
3. Click the Catch It status icon and choose **Catch Text**, or press **Control–Option–Space**.
4. Drag a rectangle over text. Press **Escape** to cancel. The result is copied as plain text.
5. If macOS requests Screen Recording access, allow Catch It in **System Settings → Privacy & Security → Screen Recording**, then quit and reopen the app.

Build and run the unit tests from Terminal:

```sh
xcodebuild -project CatchIt.xcodeproj -scheme CatchIt -configuration Debug build
xcodebuild -project CatchIt.xcodeproj -scheme CatchIt -configuration Debug test
```

`project.yml` is the XcodeGen specification. After changing the project structure, regenerate with `xcodegen generate`. XcodeGen is optional for normal Xcode builds.

## Menu and shortcuts

| Action | Default shortcut |
| --- | --- |
| Catch Text | Control–Option–Space |
| Catch Barcode | Control–Option–B |
| Catch Same Area | Control–Option–R |
| Toggle Additive Mode | Control–Option–A |
| Clear Collection | Control–Option–K |
| Capture and Speak | Control–Option–Shift–Space |
| Stop Speaking | Control–Option–Escape |

Shortcuts are configurable in **Settings → Shortcuts**. During a screen selection, press **L** to toggle line breaks, **A** to toggle additive mode, and **S** to toggle speak-after-capture. Right-clicking or Option-clicking the menu-bar icon starts text capture immediately.

## Features

- Captures the selected screen area from every connected display using ScreenCaptureKit and OCRs the image with Vision.
- Keeps recognized line breaks by default. Optional paragraph joining uses line geometry, spacing, column detection, whitespace cleanup, and line-end hyphen repair.
- Localizes the interface in English and Vietnamese, following the preferred macOS language when available. OCR uses Vision’s runtime-supported language list, automatic language detection, custom words, and a code/symbol mode. Select Chinese, Japanese, or Korean as the primary language for vertical CJK text.
- Reads QR codes and barcodes. When a code is not found, the HUD offers an OCR fallback.
- Supports a persistent additive clipboard collection, configurable separators, a 30-second Undo Clear action, and optional clear-after-paste.
- Remembers the previous area for another capture, reads text aloud, and detects URLs, email addresses, and phone numbers.
- Imports an image or PDF through **Open Image or PDF…**; PDF pages are rendered in memory before OCR. An optional searchable history stores recognized text in `~/Library/Application Support/Catch It/history.json`.
- Offers Continuity Camera from the status menu. The system can send a photo or scanned document from a nearby iPhone or iPad for OCR.

## Permissions and privacy

Screen Recording access is required for screen capture. Catch It opens a helpful alert if macOS denies a capture and provides a button to the correct System Settings pane. Captured screen images and imported images are processed in memory and discarded.

The app makes no network requests, and includes no analytics or telemetry. Opening detected links is off by default; when enabled, Catch It asks macOS to open the detected URL in the user’s default app. History is off by default and saves recognized text only after the user enables it. The project is not sandboxed for local development.

Accessibility access is requested only when **Clear collection after I paste** is enabled. Catch It uses it to observe Command–V and clear the collection shortly after a paste. If access is denied, the setting remains off and ordinary capture continues to work.

## Dependencies and licenses

- Runtime: Apple SwiftUI, AppKit, Carbon, ScreenCaptureKit, Vision, PDFKit, AVFoundation, ServiceManagement, and ApplicationServices. These are Apple system frameworks; no third-party runtime packages are linked or bundled.
- Project generation only: [XcodeGen](https://github.com/yonaskolb/XcodeGen), MIT license. XcodeGen is optional and is not included in the app.
- The app icon is an original document-and-lens design included in `CatchIt/Resources/CatchIt.icns`.
