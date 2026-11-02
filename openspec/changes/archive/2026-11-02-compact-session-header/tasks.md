# Tasks

## 1. Compact session header

- [x] 1.1 Replace the four-line `Session.header` with the variant-A horizontal title/status/details composition using existing components; verify the default document omits `OpenCode session` and the directory while preserving tab-strip output and the existing transcript/input regions.
- [x] 1.2 Add per-session details state and a local toggle event, rendering the full directory below the compact row; verify collapsed initialization, repeated toggling, refresh retention, tab-local state, unchanged server-held prompt/messages, and `Cmd.none` in focused existing backend tests.
- [x] 1.3 Update affected assertions in `test/test_folder_tabs.ml` and other existing session tests, plus the header description and example in `README.md`; verify they describe the compact header and optional details without asserting the removed caption or permanent path.
- [x] 1.4 Run `dune fmt`, `dune build`, and `dune test`; resolve failures introduced by this change and record the results regardless of Android device availability.

## 2. Device verification and review

- [x] 2.1 Read and source the repository-root `.envrc`, require nonempty `ANDROID_SERIAL`, and use only that device to capture before/after screenshots of the same selected chat; verify identical tab geometry and controls, increased transcript height, visible original composer, and working details toggle. Save screenshots together and open their folder in Finder. If the device is unavailable, record the blocked device checks.
- [x] 2.2 On that device, verify header wrapping and details accessibility at 125% font scale, plus transcript scrolling and visibility of the composer; restore the original font scale afterward and confirm idle/busy/retry and attention states through appropriate existing fixtures or tests.
- [x] 2.3 Review the implementation against the delta spec and approved variant A, fix all obvious or important findings, and rerun checks affected by those fixes; verify no tab, emulator-pane, message-style, or base-component changes entered the diff.

## 3. Requested vertical centering

- [x] 3.1 Add opt-in `centerVertically` to the existing row protocol and renderer, enable it only for the session header, and update documentation; verify default compatibility and boolean parsing, then run host checks and build the Android APK.
- [x] 3.2 Deploy to the `.envrc` device, verify matching vertical centers of title/status/details and unchanged tab geometry, capture a screenshot, and review the diff for unrelated changes.

## Verification results

- Vertical-centering follow-up: host checks and Android debug/test builds passed; `BackendUiParserTest#parsesOptionalVerticalCentering` passed on the configured device. UI layout reports y=319 for title, status, and details text centers. Tab/add/close/composer bounds remain identical. Updated APK and backend are running; screenshot saved as `6 — Выравнивание по центру.png` in the comparison folder.

- `dune fmt`, `dune build`, `dune test`, `git diff --check`, and `openspec validate compact-session-header --strict` passed.
- The new folder-tab regression first failed because the directory was always visible; it passes with local toggling, no HTTP calls, refresh retention, and tab switching. Existing busy/retry, Stop, error, and pending-input tests pass.
- Device: `192.168.0.11:5555`, original font scale `1.25`, physical density `360`. The same session in `Tab 2` was reopened after the backend restart.
- Transcript viewport grew from y=591..1379 (788 px) to y=391..1379 (988 px): +200 px, approximately 25%. Tab label, close control, add control, and composer bounds are identical before/after.
- Details were shown and hidden by device taps; transcript scrolling left the header and composer stationary. For a wrapping stress check, density was temporarily set to 600 with font scale still 1.25: title and status wrapped, and details and composer remained visible. Density was reset and confirmed at 360; font scale remained 1.25 throughout.
- Screenshots are in `~/Desktop/RemoteDev — A до и после`, opened in Finder. The emulator panel's loaded data changed after refresh; its implementation and geometry were not modified.
- Diff review found no remaining important issues in scope: changes are limited to the existing Session component, relevant tests, README, and this OpenSpec change.
