# Tasks

## 1. Align prompt controls

- [x] 1.1 Enable the existing `center_vertically` property on the OpenCode prompt row in `lib/home_components.ml`; verify with `dune fmt`, `dune build`, and `dune test`.
- [x] 1.2 Visually verify matching send and microphone button centers on the device selected by the repository-root `.envrc`; report if that device is unavailable.
- [x] 1.3 Review the implementation and fix all obvious or important findings; verify the diff is limited to the intended alignment and existing input events remain intact.
