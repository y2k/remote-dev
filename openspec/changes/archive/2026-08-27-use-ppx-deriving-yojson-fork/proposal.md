## Why

Released `ppx_deriving_yojson` requires project-local codec-и для стандартного `result`, хотя fork уже предоставляет эту поддержку как builtin PPX functionality. Использование fork устраняет workaround, сохраняя существующий JSON wire contract.

## What Changes

- Pin `ppx_deriving_yojson` to `y2k/ppx_deriving_yojson` through Dune Package Management and regenerate the committed lock directory at the resolved fork commit.
- Remove the application-local `result_to_yojson` and `result_of_yojson` helpers and their direct tests.
- Retain message round-trip coverage and verify malformed result payloads remain decode errors at the HTTP boundary.
- Preserve the `Ok`/`Error` JSON representation; error-detail text for malformed result input is not a stable contract.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `dune-package-management`: resolve `ppx_deriving_yojson` from the committed fork source instead of the released package archive.

## Impact

- Affects `dune-project`, `dune.lock`, `lib/home_components.ml`, and `test/test_remote_dev.ml`.
- Replaces the released PPX archive with a Git source locked to `b10a96d`.
- The fork qualifies generated standard `result` constructors, so they cannot conflict with an enclosing user-defined `Error` constructor.
- Keeps successful and failed result message JSON compatible; malformed result requests continue to receive HTTP 400 with an implementation-defined decode error.
