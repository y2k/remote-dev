# Tasks

## 1. Session creation control layout

- [x] 1.1 In `lib/home_components.ml`, move the folder-only creation button and its progress replacement into the beginning of the existing weighted session-list column, leaving the folder path in its current header. Verify both states precede the session rows or empty-state content and no creation control is added when `directory` is absent.
- [x] 1.2 Update `README.md` to describe the creation button scrolling with the session rows and becoming visible again at the top; verify the description matches the delta spec.
- [x] 1.3 Run `dune fmt`, `dune build`, and `dune test`, including the existing folder-session creation, failure, and Back-navigation checks in `test/test_folder_tabs.ml`; confirm all host-side checks pass independently of device availability.
- [x] 1.4 With `ANDROID_SERIAL=abf51f11` set before device operations, use only that device to verify that an overflowing session list scrolls the button out of view and back, that empty and failed loads retain the creation control, and that creation and Back still work. Confirm the pending label shares the button's list position. If the device is unavailable, record the device checks as blocked and continue host-side verification.

## Verification results

- `dune fmt`, `dune build`, `dune test`, and `git diff --check` passed.
- On `abf51f11`, Android layout inspection confirmed the creation button disappeared after scrolling the overflowing `remote-dev` session list and reappeared at the top. Creating one untitled empty session opened its chat; Back showed it in the list. No prompt was sent.
- A temporary empty folder showed the creation control and `No OpenCode sessions`. Running the test backend with an isolated missing service registration showed the load error and retained the creation control without a false empty state.
- The pending NDJSON document was inspected: `Creating session...` is the first child of the weighted session-list column. This transient state was verified in the backend response, not captured on the device.
- Test backend processes were stopped and the temporary folder removed. Independent code review reported no findings.
