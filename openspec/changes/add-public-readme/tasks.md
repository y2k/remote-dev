## 1. Public Documentation

- [ ] 1.1 Create an English root `README.md` that explains `remote_dev`, its trusted-LAN-only security boundary, architecture, prerequisites, and GPL-3.0 license; verify every operational claim against the current OCaml and Android source.
- [ ] 1.2 Document backend startup, repository-root selection, Android debug build, and the two required backend-IP edits; verify the documented commands and file paths exist in the repository.

## 2. Interface And Validation

- [ ] 2.1 Document `POST /`, the JSON event envelope, and supported backend-defined UI node types; verify example field names and values against `lib/home.ml`, `lib/components.ml`, and the Android parser.
- [ ] 2.2 Run `dune test` and `./gradlew assembleDebug` from `android/`; verify both documented validation commands complete successfully.
