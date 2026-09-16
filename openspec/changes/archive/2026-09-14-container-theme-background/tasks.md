## 1. Backend composition and wire format

- [x] 1.1 Add the five-role `theme_color` type and optional background to row/column constructors, event mapping, and JSON serialization in `lib/components.ml`; update existing constructor pattern matches. Extend `test/test_remote_dev.ml` to verify all role strings for both containers, field omission, and preservation through nested event mapping with weights/stretch. Run `dune fmt` and `make test`.

## 2. Android parsing and rendering

- [x] 2.1 Add the five-role enum and optional background fields to the Android container model, and strict parsing in the shared row/column branch in `MainActivity.kt`. Extend `BackendUiParserTest.kt` for both node types, all roles, omission, unknown/case-mismatched/RGB strings, and invalid JSON types including null; verify those tests pass on a connected device or emulator.
- [x] 2.2 Resolve roles from the active Material theme and apply `Modifier.background` to existing row/column layouts in `UiNodeContent.kt`. Add focused Compose assertions in the existing test file for light/dark role resolution, transparent and explicitly colored nested containers, painted inter-child gaps, unchanged text/control colors, and unchanged bounds/scrolling with weights and stretch. Verify these assertions pass without adding dependencies or changing the palette.

## 3. Emulator panel composition

- [x] 3.1 Set `Surface` background and existing `weights:[0;0]` on the outer two-child column in `Emulator.view` in `lib/home_components.ml` to fill available height while retaining content-sized children. Extend backend checks for selected, unselected, empty, and error states, preserving the root 2:1 ratio and control events/order; run `dune fmt` and `make test`.
- [x] 3.2 Verify the actual emulator panel composition in a bounded two-pane Compose test: the surface fill reaches the right pane's full width and bottom edge for short/empty content and a preview, resolves in both themes, and leaves header/margins, child colors, image aspect ratio, and tap mapping unchanged. Reuse existing layout/image assertions and confirm the focused checks pass on a connected device or emulator.

## 4. Integration verification

- [x] 4.1 Run `./android/gradlew --no-daemon -p android :app:connectedDebugAndroidTest` against a connected device or emulator to verify the extended contract alongside existing layout and interaction checks; confirm documents without a background field still render and inspect the full-height Emulators surface on a backend-served screen in light and dark appearance.
