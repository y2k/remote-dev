## 1. Backend composition contract

- [x] 1.1 Extend `lib/components.ml` with `Border.make ~color width`, optional `border` and `corner_radius` on both containers, dimension validation, event mapping, and omission-preserving JSON serialization. Extend `test/test_remote_dev.ml` to verify both containers, all existing color roles, independent attributes, explicit zeros, invalid dimensions, and preservation of nested layout attributes and mapped events; run `dune fmt` and verify these assertions pass with the backend test suite.

## 2. Android parsing and rendering

- [x] 2.1 Extend container models and parsing in `MainActivity.kt` using existing dimension and theme-role validation. Add cases to `BackendUiParserTest.kt` verifying omitted defaults, zero and maximum dimensions, all roles, required border fields, and rejection of malformed values including invalid colors on zero-width borders. Verify the parser cases pass on `abf51f11` using the device-selection procedure in section 3.
- [x] 2.2 Apply a shared outer shape with native Compose border, background, and positive-radius clipping in `UiNodeContent.kt`, preserving the existing size/padding/gap modifier order and skipping border drawing at width zero. Add rendering assertions to `BackendUiParserTest.kt` for rows and columns: square/rounded borders above child backgrounds, clipping of child images or fills without a border, radius clamping, light/dark theme colors, and omission/zero behavior. Verify geometry and pixel assertions pass on `abf51f11`.

## 3. Integration verification

- [x] 3.1 Add a focused decorated-layout regression case covering a weighted row and a stretching weighted column with padding, colored gaps, nested containers, and scrolling. Verify decoration preserves measured child bounds, the 200 dp row's two 80 dp allocations, and scrolling while clipping descendant drawing and retaining the visible border; run this with the existing `BackendUiParserTest` suite.
- [x] 3.2 Run backend checks (`dune build @unused-libs` and `dune test`) and the Android instrumentation suite. Before any adb or testing command, set `export ANDROID_SERIAL=abf51f11`; verify that device is available with `adb -s abf51f11 get-state`, then run `./android/gradlew --no-daemon -p android :app:connectedDebugAndroidTest` with the same exported serial. Stop testing and report the blocker if `abf51f11` is unavailable; never use another device or emulator. Record results and confirm that existing undecorated-container checks still pass.

## Verification results

- `dune fmt`, `dune build @unused-libs`, and `dune test`: passed.
- `ANDROID_SERIAL=abf51f11` with `:app:connectedDebugAndroidTest`: 40 tests passed, zero failures or skips, including existing undecorated-container checks.
- `git diff --check`: passed.
