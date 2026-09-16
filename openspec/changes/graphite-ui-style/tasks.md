## 1. Visual styling

- [x] 1.1 Configure the graphite dark palette in the existing Material theme and render ordinary backend text with the foreground color; verify the specified background, surface and action colors in dark appearance and readable controls in system light appearance.
- [x] 1.2 Coordinate the existing top bar, 12 dp horizontal content padding, and rounded input surfaces as described in design.md; visually verify the title and Refresh remain visible, nested spacing does not accumulate, and both panes retain their 2:1 layout.

## 2. Input submission

- [x] 2.1 Add an accessible arrow submit action inside the shared input renderer using its current local value and existing callback; verify one click submits the unchanged event and edited text, the control has a minimum 48 dp target, and it is disabled during a request.
- [x] 2.2 Extend the existing BackendUiParserTest checks for arrow submission of an edited draft, duplicate blocking, and draft preservation without a replacement document; run these checks alongside existing hardware Enter, voice draft replacement, and weighted-layout tests using connectedDebugAndroidTest with a configured backendHost.

## 3. Integration verification

- [x] 3.0 Replace the content-sized Worktree shortcut row with a stretching column; verify backend tests preserve button order/events, run `dune fmt` and `dune test`, and visually confirm readable shortcut buttons in a 400 dp viewport with the existing 2:1 pane ratio. Preserve the original Emulator row as explicitly requested in the subsequent user correction.
- [x] 3.1 Build the Android debug client with assembleDebug and the configured backendHost; inspect Branch, Commands, and Prompt in light/dark appearance and narrow/wide windows, including long text and the keyboard, confirming the arrow and existing microphone remain usable and weighted transcript scrolling still works. Record results and any device-dependent verification blocker.

### Verification results — 2026-09-14

- Subsequent user correction: restored the Emulator controls to their original horizontal row and removed the vertical-emulator assertion. The earlier fixed-emulator screenshots below describe the superseded iteration; Worktree shortcuts remain vertical.

- `./gradlew assembleDebug connectedDebugAndroidTest installDebug` passed with the local configured backendHost: 30 instrumented tests passed on the Android 17 Tablet AVD, including arrow submission, duplicate blocking, draft preservation, Enter, voice draft replacement, and weighted layout/scrolling.
- Inspected the actual OpenCode Prompt and Claude Branch/Commands screens in system light and dark appearance, at 2560x1600 and an 800x1600 viewport. Prompt scrolling retained its input; a long locally edited draft and the emulator's floating IME left submit and microphone visible. No agent prompt or worktree creation was submitted during inspection.
- Visual checks confirmed the graphite palette, foreground text, rounded inputs, header, and readable light-theme input surface. The native Android arrow resource initially rendered as a triangle; the final version uses a small vector drawable. Microphone container colors now follow the graphite theme.
- Initial task 3.1 blocker: at 800x1600 the content-sized emulator button row and Commands shortcut row compress later buttons into tall vertical strips; shortcuts occupy almost all available chat height. The user approved expanding this change to fix these groups; task 3.0 captures that work before completing verification.
- Resolved by task 3.0: `dune fmt` and `dune test` passed, including button-group order/event assertions. Re-inspected the final Commands/Emulator layout at 400 dp in both themes and at the original tablet width. Buttons are readable, the chat area retains available space, and Commands plus microphone remain visible; activating a shortcut populated Commands without submitting it. Final screenshots: `graphite-buttons-fixed-{dark,light,wide}.png`. No remaining verification blocker.
- Screenshots are temporary `graphite-*.png` files under `/var/folders/yn/rfk_wf_941g9wdgstvd2g1_80000gn/T/opencode/`. The temporary backend processes were stopped and the AVD's original size, dark appearance, and hardware-keyboard IME setting restored.
