## 1. Backend layout document

- [x] 1.1 Extend the existing OCaml `Row` node and `row` helper with optional integer weights, preserve weights through `Components.map`, and emit `weights` only when present; verify component serialization covers weighted and unchanged unweighted rows.
- [x] 1.2 Recompose `Worktree.view` as a `[2, 1]` weighted row with all non-emulator content in the first child and the mapped `Emulator.view` in the second; verify worktree documents preserve this structure for selected, empty, and failed emulator states.

## 2. Android weighted rows

- [x] 2.1 Parse optional row weights into `UiNode.Row` and reject wrong types, count mismatches, and non-positive values; verify Android parser tests cover valid weighted rows, existing unweighted rows, and each invalid case.
- [x] 2.2 Render weighted rows at full available width with each child in a proportional weighted container while retaining the current unweighted path; verify a Compose test observes a 2:1 child-width ratio and existing input and image behavior still passes.

## 3. Documentation and verification

- [x] 3.1 Document the optional `row.weights` field and its proportional-width behavior in `README.md`; verify the example matches the emitted `[2, 1]` worktree document.
- [x] 3.2 Run `dune fmt` and `dune test`, then run `./gradlew spotlessCheck check assembleDebug connectedDebugAndroidTest -PbackendHost=192.168.0.15` from `android/`; verify backend tests, Android quality checks, the APK build, and connected Compose tests pass.
