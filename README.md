# My visits

A single-screen Flutter app for iOS and Android using the supplied `FlakyTaskApi`.
Built with **Flutter 3.47.2 stable / Dart 3.13.2**. Implementation uses Flutter Hooks
for widget-local controllers and Riverpod `Notifier` for application state.

## Run

Requirements: Flutter 3.47.2 (or a compatible recent stable release), plus Xcode
and an iOS simulator, or Android Studio/Android SDK and an Android emulator or
device. Dependencies are pinned in `pubspec.lock`.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

To exercise a different deterministic failure sequence:

```sh
flutter run -d <device-id> --dart-define=API_SEED=7
```

A physical iOS device requires your own signing team in Xcode. Web and desktop
are not configured. To start an Android emulator and build a debug APK:

```sh
flutter emulators
flutter emulators --launch <android-emulator-id>
flutter run -d <android-device-id>
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Use

- Scroll for the next page; a footer provides loading, retry, and manual load states.
- Pull down to refresh. Existing results remain visible if refresh fails.
- Search sends the exact text to the API after 300ms; old results disappear as soon
  as the text changes. Clear search using the trailing control.
- Tap a task's circle to mark done/reopen. Pending changes are stored before sending.
- `Not saved · Retry` means the server rejected that attempt; the displayed status
  returns to the last confirmed value, while the intended status is retained.
- `Unconfirmed · Retry` means a response was lost. The desired status stays visible
  until an absolute-status retry confirms it. Retrying never blindly toggles it.
- Pending changes resume on launch/foreground. Failed/uncertain changes use explicit
  per-row retries. The header counts unsynced tasks across all searches.

Times use the device's timezone. For the Figma accessibility case, use a 320dp
viewport with 200% system text size; the golden test also verifies that exact case.

## Validate

```sh
flutter analyze
flutter test
flutter test integration_test/visits_flow_test.dart -d <device-id>
```

The native integration flow passes on the iPhone 18 Pro simulator (iOS 27.0)
and Pixel 9 Pro emulator (Android 17). Android debug APK compilation and
`flutter analyze` also pass.

The unit/widget suite covers stale searches and pages, pagination deduplication,
rapid toggles, rejected and ambiguous writes, storage failures/recovery, cold
controller restoration, malformed fields, real hit regions and visual snapshots.
The native integration test uses actual app-support storage and a fresh provider
scope, then retries against the supplied backend. This simulates app reconstruction;
it is not a test that force-kills the OS process.

Golden screenshots live in `test/goldens/`. They use bundled IBM Plex Sans fonts.
When intentionally changing the design, review the rendered images before updating
baselines with `flutter test --update-goldens`. Rasterization can differ across hosts;
these baselines were generated on macOS with the SDK above.

## Structure

- `lib/data/flaky_task_api.dart` — supplied backend; behavior left unchanged.
- `lib/data/visit_store.dart` — versioned JSON cache/outbox with flushed atomic replacement.
- `lib/visits/visit.dart` — parsed tasks and durable status intentions.
- `lib/visits/visits_controller.dart` — Riverpod state, request generations, serialized syncing.
- `lib/ui/` — Figma-derived styles, reusable rows and the Hooks/Riverpod screen.

Dependencies: `flutter_hooks` owns text/focus/scroll/animation/lifecycle state;
`hooks_riverpod` connects widgets to the testable notifier; `path_provider` locates
persistent app-support storage; `flutter_svg` renders the exact exported Figma SVGs;
`intl` formats local timestamps. No code generation or runtime font downloads.

## Limits and review

The backend resets its database on every app restart. The app retains the outbox
but treats confirmed server data normally; accepted changes can appear to reset
because this mock has no persistent server. Its source remains unchanged.

Cached search results may be incomplete while the API fails and are labelled as
saved data. File replacement protects against interrupted JSON writes; local
storage failure is explicitly blocking. A crash before the initial local write
finishes cannot be guaranteed durable. No background execution or multi-device
conflict protocol is claimed.
