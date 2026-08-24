## 1. Claude Stream Processing

- [x] 1.1 Implement line-by-line `stream-json` processing and preserve the cwd/prompt argument boundary; verify with the existing fake `claude` executable that metadata is ignored and `text_delta` values `"Hel"` then `"lo"` reach the caller before successful completion.
- [x] 1.2 Extend the fake CLI cases so a final `result` does not duplicate streamed text, malformed JSON reports an error, and exit code `1` after a delta reports an error; verify with `dune test`.

## 2. Streaming Backend Response

- [x] 2.1 Emit compact UI snapshots for the cumulative outputs `"Hel"` and `"Hello"`; verify direct Home assertions preserve their order and emit an error snapshot after a failed stream.
- [x] 2.2 Verify the streaming HTTP path returns `application/x-ndjson` without `content-length` and writes one JSON line per snapshot, while existing non-`run_claude` assertions still return one `application/json` document; verify with `dune test`.
- [x] 2.3 Update the documented HTTP protocol to identify `run_claude` as an NDJSON response and retain the ordinary JSON contract for other events; verify the README matches the implemented media types.

## 3. Incremental Android Rendering

- [x] 3.1 Feed two NDJSON UI-document lines containing `"Hel"` and `"Hello"` into the Android stream reader; verify each line replaces displayed `ScreenState.Content` in arrival order.
- [x] 3.2 Verify controls remain disabled while the stream reader is open and become enabled only after EOF; retain the existing duplicate-submit Compose regression test and verify Android tests pass.

## 4. Validation

- [x] 4.1 Format OCaml changes and run the backend suite with `dune fmt && dune test`.
- [x] 4.2 Build the Android client with `./gradlew assembleDebug -PbackendHost=192.168.0.15` from `android/`.
