## 1. Backend emulator access

- [x] 1.1 Add Runtime functions that list running `emulator-*` ADB devices and resolve their AVD names; verify OCaml tests assert the argv and parse multiple devices, name fallback, and an empty list.
- [x] 1.2 Add binary on-demand ADB screenshot capture without shell interpolation; verify OCaml tests assert the `adb -s <serial> exec-out screencap -p` argv, PNG bytes, and failed-process handling.
- [x] 1.3 Add the screenshot HTTP route with running-emulator revalidation, `image/png`, and `Cache-Control: no-store`; verify server tests cover successful PNG, unavailable serial, and an unknown route.

## 2. Backend-defined worktree preview

- [x] 2.1 Add the `image` component node with `src` and `label` serialization; verify an OCaml JSON assertion covers it inside mapped columns and rows.
- [x] 2.2 Load emulator choices when entering a worktree and retain the selected serial in its model; verify the streamed worktree document lists multiple emulator controls, selects one, and reports an empty list without an image node.
- [x] 2.3 Handle selecting another listed emulator without starting a new command; verify the returned document changes only the image source and remains a complete valid UI document.

## 3. Android image rendering

- [x] 3.1 Extend `UiNode` parsing for `image`; verify Android parser tests accept a single-slash backend-relative source and reject missing fields, wrong field types, absolute URLs, and `//` sources.
- [x] 3.2 Render an image from the configured backend origin using the existing Ktor client and platform bitmap APIs; verify a Compose test displays decoded PNG content and an image-specific error without replacing surrounding content on request failure.
- [x] 3.3 Refresh a rendered image every three seconds and cancel refresh when its source changes or it leaves composition; verify a coroutine or Compose test observes repeated image requests without a UI event request.

## 4. Verification and documentation

- [x] 4.1 Update the README UI-node and local-runtime documentation for emulator screenshots; verify its supported-node list and endpoint behavior match the delta specs.
- [x] 4.2 Run `dune fmt` and `dune test`, then run `./gradlew check -PbackendHost=192.168.0.15` from `android/`; verify all backend and Android checks pass.
