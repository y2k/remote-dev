# Engineering Approach

- Implement only the behavior explicitly required now. Do not add speculative features, abstractions, configuration, extension points, or architecture for possible future needs.
- Keep work within the task's stated scope. Track additional problems or improvements discovered along the way as separate GitHub issues instead of expanding the current task.
- Prefer deleting code, reusing existing code, the standard library, and native platform features. Choose the smallest clear change that works.
- Do not handle hypothetical edge cases. Add handling only for an explicit requirement, a reproduced failure, or a trust-boundary risk involving security or data loss.
- Do not introduce dependencies or boilerplate when a direct implementation is sufficient.
- Mark an intentional shortcut with a `ponytail:` comment that states its limit and when it should be revisited.

# Server-Defined UI

- Implement server-defined UI on the OCaml backend using The Elm Architecture (TEA): `model`, `msg`, a pure `view`, and `update`.
- When composing server-defined UI, prefer self-contained components for distinct sections. Components do not need separate files.

# Testing

- Run checks appropriate to the change.
- Host-side checks that do not interact with an Android device (such as `dune test`, `dune build`, and `dune fmt`) do not require a connected device. Do not gate them on adb availability or device status.

## Android Device Testing

- These restrictions apply only to commands that interact with an Android device: installation, instrumentation tests, UI checks, screenshots, and other adb operations.
- Use only the device with ID `abf51f11`. Do not launch or use other devices or emulators.
- Before device operations, set `export ANDROID_SERIAL=abf51f11`. For tools that do not honor it, select the device explicitly (for example, `adb -s abf51f11`).
- If this device is unavailable, stop only device-dependent checks. Continue applicable host-side checks and report which device checks could not run.
