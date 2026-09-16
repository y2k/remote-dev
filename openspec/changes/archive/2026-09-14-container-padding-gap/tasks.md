## 1. Backend composition and wire format

- [x] 1.1 Add `Padding.all`, `Padding.symmetric`, `Padding.only`, and `Gap.make` in `lib/components.ml`, with supported integer-range validation and optional container arguments; update direct constructor pattern matches and verify helper results and rejected dimensions in `test/test_remote_dev.ml`.
- [x] 1.2 Preserve padding and gap through nested event mapping and serialize the agreed objects, omitting unselected attributes; verify exact JSON, zero values, all theme roles, unchanged default documents, and mapped events with existing backend tests, then run `dune fmt` and `dune runtest`.

## 2. Android parsing and layout

- [x] 2.1 Extend the container models and shared parsing branch in `MainActivity.kt`; add parser checks in `BackendUiParserTest.kt` for defaults, complete objects, all supported colors, missing fields, nulls, fractional and out-of-range dimensions, coercible strings, and invalid colors; verify these tests pass.
- [x] 2.2 Apply logical padding after the container background and use the configured gap size with the existing `Arrangement.spacedBy` in `UiNodeContent.kt`; verify default geometry, independent sides, nested padding, zero/single/empty gaps, and LTR/RTL with Compose geometry tests.

## 3. Colored gap rendering

- [x] 3.1 Add current immediate-child boundary observation and `drawBehind` gap painting inside padding, resolving colors through the existing theme roles and observing weighted wrapper bounds rather than scrolled content; verify pixel and geometry tests for rows and columns with explicit backgrounds, unequal child sizes, transparent/matching colors, all theme roles, and unchanged dimensions when only color changes.
- [x] 3.2 Keep observed geometry and drawing current across child-size/count changes, document replacement, theme changes, and RTL changes; verify tests remove stale stripes, preserve padding pixels, and constrain painting to actual inner gaps, including narrow layouts.

## 4. Integrated verification

- [x] 4.1 Verify combined padding, colored gaps, weights, stretch, and scrolling using the 200 dp weighted-row example and a `[0,1,0]` scrolling column; assert original-child weight indexing, inner allocations, and unchanged scrolling and child interaction behavior in the existing Android test suite.
- [x] 4.2 Run `dune runtest` and, from `android/`, `./gradlew assembleDebug connectedDebugAndroidTest` using the configured backend host and an available Android device/emulator; verify the existing UI regression suite passes and inspect a nested padded/colored-gap layout in both themes and layout directions without changing production screen composition.

## 5. Approved panel-divider extension

- [x] 5.1 Add the shared `outlineVariant` theme role and use a 1 dp gap in `Home.view`, with dark color `#343A43` and the default light-theme role; verify backend root-layout serialization, all-role parser/rendering tests, full-height 1 dp divider pixels, and emulator preview interactions, then run `dune fmt`, `dune runtest`, and the Android tests.

## Verification record

Final verification: `dune fmt` and `dune runtest` passed; Android APKs built successfully. After Gradle UTP failed and MIUI background-activity permission was enabled, all 38 instrumentation tests passed directly on `abf51f11` using `adb -s abf51f11 shell am instrument -w io.y2k.remote_client.test/androidx.test.runner.AndroidJUnitRunner` with `ANDROID_SERIAL` exported to that device. The constrained-layout check now uses unclipped child positions and verifies allocated slots even for zero-sized children and overflowing minimum touch targets.
