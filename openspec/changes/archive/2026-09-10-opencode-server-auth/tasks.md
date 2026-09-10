## 1. HTTP authentication

- [x] 1.1 Declare the `base64` dependency in `dune-project` and `lib/dune`, update `dune.lock` and generated `remote_dev.opam`, and use `Base64.encode_exn` instead of the custom encoder; remove encoder-only tests and verify the existing authentication-header checks and build pass.
- [x] 1.2 Add environment-derived Basic authentication in `perform_http`, using a non-empty password and constant username `opencode`; verify captured HTTP requests for unset/empty passwords, ignored username environment, verbatim passwords, and both GET and POST operations including prompt, command, and abort. Isolate test environment changes and use synthetic credentials.
- [x] 1.3 Keep HTTP 401 on the existing failure path without including its response body or authentication data; verify a mocked 401 containing synthetic credentials produces a status-only error and inspect that credentials never enter UI state or logs.

## 2. Documentation and verification

- [x] 2.1 Update the OpenCode startup section in `README.md` to explain that the server and backend must inherit matching `OPENCODE_SERVER_PASSWORD` and the username is always `opencode`, including separate-terminal startup and the unset/empty behavior; verify the documented backend command remains `make run ARGS="--agent opencode"` and examples contain no real secrets.
- [x] 2.2 Run `dune fmt` and `make test` (including the build's unused-library check); verify formatting, build, and existing runtime/UI tests pass with the new authentication checks.
