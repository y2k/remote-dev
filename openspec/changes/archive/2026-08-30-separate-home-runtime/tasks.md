## 1. Root TEA component

- [x] 1.1 Hoist the nested root component to the `Home` compilation-unit level, rename its `state` type to `model`, retain the generated message codecs and existing transitions, and verify component assertions compile against `Home.*` without `Home.Home.*`.
- [x] 1.2 Remove request parsing, global state, command execution, document serialization, streaming coordination, and dead helpers from `lib/home.ml`; verify the file exposes only the root TEA model/message/init/view/update behavior and its navigation helpers.

## 2. Server runtime ownership

- [x] 2.1 Move the `Atomic Home.model`, request decoder, document encoder, state transition, command-chain dispatch, initialization, and reset test seam into `Server`; verify existing synchronous and Eio HTTP paths use the shared server-owned helpers and preserve response status, content type, and document assertions.
- [x] 2.2 Move Claude request recognition and incremental output/error dispatch into the server streaming path; verify the existing Claude stream checks preserve cwd/prompt selection, accumulated output documents, and error documents.

## 3. Callers and verification

- [x] 3.1 Update repository callers and `test/test_remote_dev.ml` to use `Home.*` for component behavior and `Server.*` for session/transport behavior; verify no `Home.Home.*` or removed `Home` runtime-helper references remain.
- [x] 3.2 Run `dune fmt` and `dune test`; verify all component composition, JSON round-trip, command-chain, HTTP, emulator, worktree, and streaming checks pass without protocol changes.
