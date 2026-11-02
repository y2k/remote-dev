# Tasks

## 1. Compose the selected-session presentation

- [x] 1.1 Group session context into the themed header in `lib/home_components.ml` using existing containers and text roles; update affected assertions in `test/test_remote_dev.ml` and verify full title, path, retry detail, and untitled fallback remain present with `dune test`.
- [x] 1.2 Compose separate role-labelled message blocks with the agreed backgrounds, spacing, radii, and weighted horizontal offsets; document the fixed-width shortcut with a `ponytail:` comment. Update existing transcript assertions to verify exact body text, separate labels, order, consecutive same-role messages, and refresh replacement; run `dune test`.
- [x] 1.3 Preserve the weighted transcript region and existing input/voice row, pending notice, errors, and Stop events. Update affected layout assertions and verify existing action and tab-routing tests pass. Update the selected-session example in `README.md` to match the resulting document structure and check it against serialized output.

## 2. Integration verification and review

- [x] 2.1 Run `dune fmt`, `dune test`, `dune build`, and `git diff --check`; resolve failures attributable to this change and record the results. Host-side checks must run regardless of device availability.
- [x] 2.2 Read and source the repository-root `.envrc`, require nonempty `ANDROID_SERIAL`, and use only that device for visual checks. Inspect the composed chat in both themes at 125% font scale with long Cyrillic/multiline text, long paths, an empty conversation, and overflowing history; verify role offsets, readable contrast, full text, stationary header/input, and unchanged actions. Capture evidence and restore device theme/font settings; report a device blocker if unavailable rather than using another device.
- [x] 2.3 Review the implementation against the delta spec and design, fix all obvious or important findings, rerun checks affected by fixes, and record any remaining limitations before marking the change complete. Verify no new base components, protocol fields, or unrelated behavior were introduced.

## Workflow follow-up

- When archiving is requested, sync the delta into the main specification first, then archive the completed change.
