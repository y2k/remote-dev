# Tasks

## 1. Generic backend composition

- [x] 1.1 Replace the specialized emulator header type with optional compact/icon button properties and the surfaceContainerLow theme role in `lib/components.ml`. Preserve ordinary button output and event mapping. Compose the header from existing row/column/button nodes in `Emulator.view`. Update serialization and lifecycle tests for the generic tree, including empty/unselected/selected/unavailable/returning/renamed devices and refresh errors. Verify `dune fmt && dune test && dune build`.

## 2. Generic Android rendering

- [x] 2.1 Remove the specialized model/parser/renderer and implement strict optional button properties, compact/icon rendering, generic row selection-group semantics and the additional theme role in existing Android files. Test malformed combinations, rejection of emulator_header, legacy buttons, generic events, appearance, and targets. Verify assemble and focused configured-device parser/appearance tests.
- [x] 2.2 Update header fixtures to use only row/column/button. Verify independent touch/accessibility/keyboard actions, no optimistic selection, busy/cancel/drag guards, pinned refresh, retained scroll, long names at 400 dp root width, both themes and scales 1.25/2.0, and unchanged preview/divider tests on the configured device.

## 3. Integration

- [x] 3.1 Run dune fmt/test/build, git diff --check, strict OpenSpec validation, Android assemble/lint/unit tests/androidTest compilation and the full configured-device instrumentation suite. Record fresh results for the generic implementation.
- [x] 3.2 Install compatible APK before restarting backend; verify live refresh and navigation, inspect new screenshots in `~/Desktop/remote-dev-emulator-header/composed`, and restore original theme/font scale. Read/source root `.envrc` and require ANDROID_SERIAL for every device command; use only that device. Use fixtures for unavailable live states and distinguish their evidence. Continue host checks if the configured device is unavailable.

## Historical evidence

The rejected specialized implementation passed 60/60 tests. Those results do not certify this revised composition; all revised tasks require fresh verification.

## Current verification

- Revised backend composition: dune fmt/test/build passed. Specialized backend node and Android renderer/model/parser removed; optional generic button properties implemented.
- After the user unlocked the device, the revised full instrumentation suite passed 60/60 in 125.535 seconds. Earlier Compose failures occurred while locked. Log: `/private/var/folders/vy/q595y6l936gggt042s884ww00000gn/T/opencode/composed-suite.log`.
- Android assemble/lint/unit tests/androidTest assembly passed; strict OpenSpec validation and git diff --check passed. The additional surfaceContainerLow role is covered in background/gap/border delta contracts.
- Compatible APK installed before backend restart. Live empty-list Refresh, navigation to remote-dev sessions and Back to directories verified. Original dark appearance and font scale 1.25 retained.
- Eight fixture screenshots (both themes, scales 1.25/2.0, normal/overflow) and live-dark.png inspected in `~/Desktop/remote-dev-emulator-header/composed`. Populated/selected/error/preview states use deterministic fixtures because no running emulator is available in the live list.
- Independent review found no actionable code issues; its stale verification-note finding is resolved here.
