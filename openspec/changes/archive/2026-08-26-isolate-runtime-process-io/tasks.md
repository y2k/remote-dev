## 1. Runtime Process Boundary

- [x] 1.1 Add one process-line streaming effect and its Unix production handler in `Runtime`, ensuring the handler closes the process channel when a line callback raises; verify `dune build` succeeds.
- [x] 1.2 Route `load_worktrees` and `stream_claude` through the effect while retaining their command construction, parsing, callbacks, and non-zero-status failures; verify the runtime tests cover successful output, non-zero exit, and malformed Claude JSON.

## 2. Production Handler Contexts

- [x] 2.1 Install the Unix handler around the server execution started by `main.ml`; verify worktree loading does not raise an unhandled effect during application initialization.
- [x] 2.2 Install the Unix handler inside the `Eio.Domain_manager.run` callback that streams Claude output; verify the HTTP streaming path can receive a Claude delta without an unhandled effect.

## 3. Isolated Tests

- [x] 3.1 Replace the temporary Claude executable, filesystem setup, and environment mutation in `test_runtime` with a synchronous fake effect handler; verify the existing delta, failure, and malformed-JSON assertions pass without spawning a process.
- [x] 3.2 Add fake-handler coverage for `load_worktrees` porcelain parsing and unsuccessful process status; verify the expected worktree records and failure behavior.

## 4. Verification

- [x] 4.1 Run `dune fmt` and `dune runtest`; verify formatting succeeds and the complete test suite passes.
