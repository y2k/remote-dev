## 1. Emulator component

- [x] 1.1 Add `Emulator.Refresh` using the existing load command and preserve `selected_emulator` in successful `Loaded` updates in `lib/home_components.ml`; update existing assertions in `test/test_remote_dev.ml` to verify startup has no selection, refresh executes discovery, and selection survives reordered, renamed, missing, empty, and restored device lists as well as failed refresh and successful retry.
- [x] 1.2 Render Refresh and available-device buttons independently of preview, with choose-emulator, no-running-emulators, and selected-emulator-unavailable states; verify component documents expose Refresh in every state, allow manual selection while the previous ID is absent, and emit an image only when the selected serial is available.

## 2. Root integration and verification

- [x] 2.1 Update bootstrap and preview-dependent tests to use explicit selection; exercise the emitted `Home.Emulator_msg Refresh` event through the existing server command-response path and verify refreshed documents retain the current screen and selected serial, preserve the root split, and recover preview when the same serial returns. Retain checks that navigation and screenshot requests do not update the UI list and backend restart clears selection.
- [x] 2.2 Run `dune fmt` and `dune test`; verify formatting and the existing backend suite pass, including emulator discovery, screenshot responses, and the new manual-refresh lifecycle checks.
