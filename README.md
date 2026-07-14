# Stax — Flutter PDF Toolkit (Android)

Android-only port of the "deck" concept from the web prototype: one
flat, reorderable grid of pages spanning every loaded PDF, with merge,
extract, rotate, sign, protect, and scan-to-PDF built on top of it.

This build ships the **full `android/` Gradle project**, not just the
Dart source — so `flutter build apk` / `flutter run` should work
directly against a connected device or emulator once you fill in
`local.properties` (see below).

## ⚠️ Read this first

This was written in a sandbox with **no Flutter/Android SDK and no
network access**, so nothing here has actually been run through
`flutter pub get`, `flutter analyze`, `gradle`, or a real device. The
architecture and Gradle config are correct to the best of my
knowledge of current Flutter/AGP conventions, but treat it as a strong
first draft. Before you rely on it:

1. **Fill in `android/local.properties`** — copy
   `android/local.properties.example` to `android/local.properties`
   and point `sdk.dir` / `flutter.sdk` at your actual SDK installs.
   This file is machine-specific and gitignored.
2. **Generate the Gradle wrapper jar** — this repo includes
   `gradle/wrapper/gradle-wrapper.properties` (pins Gradle 8.7) but
   not the wrapper `.jar` binary itself, since binaries don't travel
   well through this format. Run `gradle wrapper` once inside
   `android/`, or just let `flutter build apk` regenerate it — the
   Flutter tool does this automatically on first build.
3. **Add launcher icons** — `mipmap/ic_launcher` is referenced in the
   manifest but no actual icon assets are included. Drop your own into
   `android/app/src/main/res/mipmap-*/` (Android Studio's Image Asset
   Studio is the fastest way) or the build will fail until you do.
4. **`flutter pub get`, then `flutter analyze`** — fix whatever the
   exact pinned package versions disagree with. Package APIs I
   referenced from memory and flagged below are the most likely
   source of mismatches:
   - **pdfrx**: `PdfDocument.openData()`, `page.render()`, and the
     resulting image object's PNG-encoding method are approximated —
     check `pdfrx`'s current API docs and adjust `page_thumbnail.dart`.
   - **syncfusion_flutter_pdf**: page rotation is set via
     `page.rotation = PdfPageRotateAngle...` in `pdf_service.dart` —
     confirm against the installed version.
   - **share_plus**: `SharePlus.instance.share(ShareParams(...))`
     reflects the v10 API; older versions use
     `Share.shareXFiles(...)`.
5. **Real device testing for camera** — emulators can fake a camera
   feed but won't tell you much about real scan quality or
   permissions edge cases (especially Android 13+'s granular media
   permissions).

## What's fully implemented

- **Deck state model** (`services/deck_provider.dart`) — add/remove
  files, reorder, rotate, select, export.
- **Merge & Extract** (`services/pdf_service.dart::buildPdf`) — one
  function backs both actions, matching the web prototype's single
  `exportPages()`.
- **Deck screen UI** (`screens/deck_screen.dart`) — drag-and-drop
  reorder via `LongPressDraggable`/`DragTarget` (no extra grid-reorder
  package needed), rotate/delete/select per card, bottom action bar.
- **Fill & Sign** (`screens/sign_screen.dart`) — signature pad,
  draggable placement overlay, flattened into the PDF on export.
- **Password protect** (`screens/password_screen.dart` +
  `PdfService.protect`) — AES-256 encryption, configurable print/copy
  permissions.
- **OCR** (`services/ocr_service.dart`) — on-device ML Kit text
  recognition, stamps an invisible searchable text layer over scanned
  page images.
- **Scan-to-PDF** (`services/scan_service.dart`,
  `screens/scan_screen.dart`) — camera capture, manual crop, contrast
  cleanup, multi-page capture assembled into one PDF.
- **Android plumbing**: full manifest (camera + storage permissions,
  `<queries>` block for Android 11+ visibility, FileProvider for
  `share_plus`), ProGuard rules keeping Syncfusion/ML Kit/pdfrx native
  classes intact under R8, light/dark launch themes matching the app's
  own color tokens, `minSdk 24` (required by ML Kit + camera).
- **Theme** (`theme/app_theme.dart`) — same indigo/teal tokens as the
  web prototype, light + dark.

## What's intentionally stubbed / flagged as Phase 2

- **Automatic edge detection & perspective correction** for scans.
  Doing this properly needs a native CV library (`opencv_dart`) or a
  platform channel to ML Kit's Document Scanner API — that's a spike
  of its own, not something to fake convincingly in source. Manual
  crop + contrast boost is implemented instead.
- **Form field detection** for fill & sign (checkboxes/dropdowns in
  existing AcroForms) — current flow is "stamp an image/text box
  anywhere," which covers most signing needs but not structured form
  filling. Syncfusion's `PdfForm` API supports this as a follow-up.
- **PDF → Office conversion** (Word/Excel/PPT) — per the original
  plan, this should be server-side (LibreOffice headless or a
  conversion API), not client-only, so it's out of scope here.
- **Compress** is a best-effort re-save (`PdfService.compress`); real
  gains usually need page-by-page image downsampling — good v1.1
  addition once the base app is verified.
- **Signing key**: `release` build type currently points at the debug
  signing config so `flutter build apk --release` works immediately.
  Generate your own upload keystore before publishing to Play Store
  and update `android/app/build.gradle`.

## Project layout

```
android/                       full Gradle project (see below)
lib/
  main.dart                    entry point, theme, provider wiring
  theme/app_theme.dart         color tokens (shared with the web app)
  models/deck_models.dart      SourceFile, DeckPage
  services/
    deck_provider.dart         app state: files + pages
    pdf_service.dart           merge/extract/rotate/protect/compress
    ocr_service.dart           on-device OCR + searchable-PDF builder
    scan_service.dart          camera capture + cleanup + assemble
  widgets/page_thumbnail.dart  pdfrx-backed page renderer
  screens/
    home_screen.dart           empty state, file picker, scan entry
    deck_screen.dart           the deck grid + merge/extract actions
    sign_screen.dart           fill & sign
    password_screen.dart       protect with password
    scan_screen.dart           camera capture flow
```

### Android scaffold included

```
android/
  build.gradle                 project-level Gradle config
  settings.gradle               plugin loader + module include
  gradle.properties
  local.properties.example      copy → local.properties, fill in SDK paths
  gradle/wrapper/gradle-wrapper.properties
  app/
    build.gradle                applicationId, SDK versions, signing
    proguard-rules.pro           keep rules for Syncfusion/ML Kit/pdfrx
    src/main/
      AndroidManifest.xml        permissions, FileProvider, <queries>
      kotlin/com/stax/app/MainActivity.kt
      res/
        values/styles.xml         light launch theme
        values-night/styles.xml   dark launch theme
        drawable/launch_background.xml, launch_background_dark.xml
        xml/file_paths.xml        FileProvider path config
```

## Suggested next steps, in order

1. Fill in `local.properties`, add launcher icons, run
   `flutter pub get`.
2. Get the deck screen (file load → thumbnail render → reorder →
   merge/extract) compiling and working on a real device — this is
   the spine everything else hangs off of.
3. Verify `PdfService.buildPdf`'s template-stamping approach preserves
   vector quality (not just images) on a real multi-page PDF.
4. Wire up sign → password → scan in that order, since each is
   additive and independently testable.
5. Add OCR once the rest is stable — it's the most expensive
   on-device operation and easiest to test in isolation.
6. Before Play Store submission: generate a real upload keystore,
   swap the release `signingConfig`, add proper launcher icons, and
   review Google's permissions declaration form for the `CAMERA` and
   media permissions.
