## 1. Public Documentation

- [x] 1.1 Create an English root `README.md` that explains `remote_dev`, its trusted-LAN-only security boundary, architecture, prerequisites, and GPL-3.0 license; verify every operational claim against the current OCaml and Android source.
- [x] 1.2 Document backend startup, repository-root selection, Android debug build, `android/local.properties` `backendHost`, and the `-PbackendHost` override; verify the documented commands and file paths exist in the repository.

## 2. Interface And Validation

- [x] 2.1 Document `POST /`, the JSON event envelope, and supported backend-defined UI node types; verify example field names and values against `lib/home.ml`, `lib/components.ml`, and the Android parser.
- [x] 2.2 Run `dune test` and `./gradlew assembleDebug -PbackendHost=192.168.0.15` from `android/`; verify both documented validation commands complete successfully.
