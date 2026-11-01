# Tasks

## 1. Card protocol and typography roles

- [x] 1.1 Add the required-event `Card` component and `projectTitle`, `sessionTitle`, and `cardMeta` text roles in `lib/components.ml`, including recursive event mapping and JSON serialization. Extend `test/test_remote_dev.ml` to verify nested/tab-wrapped events, child order, role serialization, and unchanged existing-node output; run `dune fmt` and `dune test`.
- [x] 1.2 Add `UiNode.Card`, the three text roles, and strict card parsing in `MainActivity.kt`. Extend parser coverage in `BackendUiParserTest.kt` for valid nested cards, malformed or missing arrays, invalid descendants/styles, and old text documents; verify Android test compilation and run these focused cases on the configured device when available.

## 2. Native card rendering

- [x] 2.1 Render cards in `UiNodeContent.kt` using a native clickable surface with the design's explicit shape, colors, shadow, padding, minimum height, and vertical content gap. Define isolated card typography beside `ui/theme/Type.kt`; verify light/dark fill, geometry, text styles, and narrow-width wrapping at 125% font scale with focused Compose tests in `BackendUiParserTest.kt`.
- [x] 2.2 Connect card activation to the existing event callback and in-progress guard, with standard clipped ripple and one accessible action. Add Compose checks for title/metadata/padding taps, unchanged event payload, keyboard/accessibility activation, blocked requests, drag, and cancellation; verify each completed click emits once and scrolling emits nothing.

## 3. Project and session composition

- [x] 3.1 Replace directory buttons in `Directories.view` with cards containing `projectTitle`, retaining existing path events and 8 dp card spacing. Update backend assertions to verify names, order, unchanged root/error/empty states, OpenCode tab-scoped events, and Claude log-only behavior; run `dune fmt` and `dune test`.
- [x] 3.2 Replace session rows in `Sessions.view` with cards containing title, directory, and complete status text in that order, using 8 dp list spacing. Update backend tests to verify idle/busy/retry content, exact selection events, and creation/progress placement in the shared scrolling child; rerun session navigation, failure-retention, and creation coverage with `dune fmt` and `dune test`.

## 4. Integration verification

- [x] 4.1 Run host checks independently of device availability: `dune fmt`, `dune test`, `dune build`, and from `android/`, `./gradlew :app:assembleDebug :app:lintDebug :app:testDebugUnitTest :app:compileDebugAndroidTestKotlin`; verify successful results and `git diff --check`.
- [x] 4.2 Before every device-operation shell, read/source the repository-root `.envrc`, confirm nonempty `ANDROID_SERIAL`, and explicitly target that device. Install the updated client before running the updated backend; run the focused parser/card tests and relevant existing scrolling tests. If unavailable, record blocked device checks while retaining host-check results. Report the known divider baseline failure (issue #3) separately if encountered.
- [x] 4.3 On the configured device, verify project and session lists in both themes with long titles/paths/retry details at font scale 1.25. Capture four screenshots in a separate card-review folder and verify whole-card taps, scroll without selection, creation-control scrolling, Back/Refresh, and preserved two-pane layout; restore the original appearance and font scale afterward and record the evidence location.

## Verification evidence

- Host checks passed: `dune fmt`, `dune test`, `dune build`, Android assemble/lint/unit tests/instrumentation compilation, and `git diff --check`.
- Full configured-device suite: 49/50 passed. Only the previously reproduced `emulatorPanelSurfaceFillsAllocationAndPreservesPreview` color assertion fails (issue #3); all new card tests passed. Extended long-retry wrapping test passed separately in both themes.
- Live device verification: project-card padding opens its sessions; session-card padding opens that exact chat; scrolling does not select a card and moves the creation control out of view; scrolling back restores it; system Back and root Refresh retain navigation and the two-pane layout.
- Screenshots: `/Users/igor/Desktop/remote-dev-cards/projects-dark.png`, `projects-light.png`, `sessions-dark.png`, `sessions-light.png`. Additional `wrapping-dark.png` and `wrapping-light.png` are controlled renderer-test fixtures with long titles, paths, and retry details, not live session data.
- Device selected from repository `.envrc`: `192.168.0.11:5555`; original night mode `yes` and font scale `1.25` verified after checks.
- Independent whole-diff review found no correctness or scope issues.
