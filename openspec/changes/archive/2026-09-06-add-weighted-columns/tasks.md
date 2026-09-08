## 1. Backend layout documents

- [x] 1.1 Extend the OCaml `Column` node and `column` helper with optional integer weights, preserve them through `Components.map`, and serialize `weights` only when present; verify component assertions cover weighted, zero-weight, and unchanged unweighted columns.
- [x] 1.2 Recompose `Worktree.view` as a stable weighted column whose output has positive weight and whose error, heading/path, shortcuts, and input have zero weight; verify Claude, OpenCode, empty-output, long-output, and error documents keep controls outside the output region.
- [x] 1.3 Give the worktree list an explicit weighted scroll region so removing Android's global scroll preserves long-list navigation; verify the emitted worktree-list document assigns positive weight only to the growing list.

## 2. Android weighted layouts

- [x] 2.1 Parse optional weights for both `column` and `row`, accept finite non-negative numbers including zero, and reject wrong types, count mismatches, non-finite values, and negatives; verify parser tests cover each valid and invalid case.
- [x] 2.2 Render weighted columns at full available height with content-sized zero-weight children and independently scrollable positive-weight children, and render zero-weight rows with the same content-size semantics; verify Compose tests cover height allocation, manual overflow scrolling, zero-weight controls, and existing row proportions.
- [x] 2.3 Replace the global document scroll with a bounded full-height content container while retaining content-sized loading and error indicators; verify instrumentation tests show the worktree input remains visible with overflowing output and current root screens still render and refresh.

## 3. Documentation and verification

- [x] 3.1 Document `column.weights`, shared zero-weight semantics, and positive column-child scrolling in `README.md`; verify examples match the worktree document emitted by the backend.
- [x] 3.2 Run `dune fmt` and `dune test`, then run `./gradlew spotlessCheck check assembleDebug connectedDebugAndroidTest -PbackendHost=192.168.0.15` from `android/`; verify backend tests, Android checks, the APK build, and connected Compose tests pass.
