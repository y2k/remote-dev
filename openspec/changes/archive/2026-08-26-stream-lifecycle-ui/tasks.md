## 1. Backend lifecycle streaming

- [x] 1.1 Run the pure root initialization and its load command before the server accepts connections, and verify the loaded result is stored without a lifecycle marker.
- [x] 1.2 Refactor command execution so the HTTP layer can render the model before and after an ordinary command, and verify a command error produces a final error document.
- [x] 1.3 Serve `GET /` as one current `application/json` UI document after startup initialization, and verify response status, media type, and unsupported-method handling.
- [x] 1.4 Stream ordinary command responses such as `back` and manual `load` as NDJSON while keeping command-free POST events as JSON, and verify both response formats with regression tests.
- [x] 1.5 Preserve the existing `run_claude` streaming path alongside ordinary command streaming, and verify Claude delta documents and stream failures still pass their tests.

## 2. Android response handling

- [x] 2.1 Replace the initial `POST load` request with `GET /`, and verify the first screen renders the current JSON UI document.
- [x] 2.2 Generalize NDJSON parsing to every UI request selected by response media type, and verify a streamed navigation response updates Compose state for every document and re-enables events on close.
- [x] 2.3 Keep manual refresh as the `load` event and verify it handles the backend's ordinary-command NDJSON response.

## 3. Contract verification

- [x] 3.1 Update README protocol documentation for startup initialization, initial `GET /`, POST events, and command NDJSON, and verify examples match the implemented media types and envelopes.
- [x] 3.2 Run `dune fmt` and `dune runtest`, and verify the complete OCaml test suite passes.
- [x] 3.3 Build or run the Android test target and verify the client tests for initial and streamed UI responses pass.
