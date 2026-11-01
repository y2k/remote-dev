# Tasks

> Implementation plan for `style-project-tabs`. Use the executing-plans skill for inline execution, or subagent-driven-development if the user selects delegated execution.

**Goal:** Render backend-defined project tabs in the approved Stitch style with accessible native actions and selected-tab reveal.

**Architecture:** OCaml retains the existing TEA model and update logic. A semantic `tab_strip` carries presentation data and opaque events; Android parses it and renders a self-contained Compose component.

**Tech Stack:** OCaml, Yojson, Dune, Kotlin, Jetpack Compose, Android VectorDrawable.

**Spec:** `design.md`, `specs/project-tabs/spec.md`, `specs/android-backend-driven-ui/spec.md` in this change directory.

## Global Constraints

- Work in the current main worktree; add no dependencies or generic styling framework.
- Preserve `Tab N`, backend ownership, existing tab lifecycle, page navigation and the common emulator panel.
- Use current theme roles, system 14/21 sp medium labels, a 2 dp top active indicator and separate targets at least 48 dp wide and high.
- Disable all tab actions during a request; forward unchanged arrays with null value.
- Read and source repository `.envrc` before every device operation, require nonempty `ANDROID_SERIAL`, and explicitly select that device. If unavailable, continue host checks and report pending device checks.

## Review Focus

- Malformed or ambiguous tab records must fail the whole document: covered in 2.1.
- Closing an inactive tab must not also select it: covered in 2.2 and existing backend lifecycle tests in 1.2.
- Refresh must not undo manual scrolling with unchanged selection: covered in 2.3.
- Scaled labels must not clip or overlap adjacent targets: covered in 2.1 and 3.2.
- Empty strips and deletion of the active last tab must retain usable addition and the expected neighbor: covered in 1.2, 2.3 and 3.2.

## 1. Semantic protocol and backend composition

**Files:** `lib/components.ml`, `lib/home_components.ml`, `test/test_remote_dev.ml`, `test/test_folder_tabs.ml`.

**Interfaces:** Produce `'event tab`, `Tab_strip of 'event tab list * 'event` and `tab_strip ~add_event tabs` with the exact fields in `design.md`. Consume existing `map`, `to_json`, and `Project_tabs.msg`.

- [x] 1.1 Add backend serialization and mapping assertions in `test/test_remote_dev.ml`, run `dune test` to observe the missing-node failure, implement the tab record/constructor plus `map` and `to_json` in `lib/components.ml`, and rerun `dune fmt && dune test && dune build`. Assert an empty `tabs` array, ordered records, exact camelCase wire fields, and wrapping of add/select/close events without changing identities or selection.
- [x] 1.2 Change backend view assertions to expect `tab_strip` instead of row/button structure and observe their failure with `dune test`. Update only `Project_tabs.view` composition; convert existing ids to strings, retain `Tab N`, advertise existing Create/Select/Close messages. Adapt action lookup helpers in `test/test_folder_tabs.ml` for semantic fields. Verify `dune fmt && dune test && dune build`, preserving existing close-neighbor, zero-tab, stale-action, generation and independent-navigation assertions.

## 2. Native tab rendering and interaction

**Files:** Create `android/app/src/main/java/io/y2k/remote_client/TabStripContent.kt`, `android/app/src/main/res/drawable/ic_close.xml`, `android/app/src/main/res/drawable/ic_add.xml`; modify `android/app/src/main/java/io/y2k/remote_client/MainActivity.kt`, `android/app/src/main/java/io/y2k/remote_client/UiNodeContent.kt` and `android/app/src/androidTest/java/io/y2k/remote_client/BackendUiParserTest.kt`.

**Interfaces:** Consume the wire format from task 1. Produce `UiTab`, `UiNode.TabStrip` and `@Composable TabStripContent(node: UiNode.TabStrip, onEvent: (UiEvent) -> Unit, eventInProgress: Boolean, modifier: Modifier = Modifier)` with fields from `design.md`; call it from the exhaustive `UiNodeContent` dispatch. Reuse the existing theme's `labelLarge` and event callback.

- [x] 2.1 Add `parsesTabStripStrictly` and `tabStripAppearanceAndTargets`, observe their failures, then implement `UiTab`, `UiNode.TabStrip`, strict parsing, the renderer dispatch and vectors together so the sealed-node match remains exhaustive. Parser assertions cover valid empty/populated/nested strips and rejection of each missing/null/wrongly typed field, non-object entries, empty/duplicate ids, and zero/multiple selections. Appearance assertions cover both themes at scales 1.25/2.0, the 2 dp primary stripe, theme fills, untruncated labels and separate targets of at least 48 dp. Follow `design.md` spacing, 16 dp close/20 dp add icons and content-driven minimum height. Verify `./gradlew :app:compileDebugAndroidTestKotlin` and focused device tests; retain generic horizontal-row coverage.
- [x] 2.2 Add `tabStripActionsAreIndependentAndAccessible` and `tabStripBlocksBusyAndCancelledActions`, observe failures, and implement selectable-group/tab semantics plus independent native close/add buttons. Assert selected state, `Close Tab N` and `Add tab` descriptions, one exact event per action, no optimistic selection, no events for disabled/cancelled/dragged gestures, and null request values. Exercise focus traversal and Enter/Space with keyboard input mode enabled (the earlier card test required this). Verify focused instrumentation passes.
- [x] 2.3 Add `tabStripRevealsSelectionWithoutResettingScroll`: at 320 dp width render 12 tabs, append/select another, close it to select its neighbor, and replace a document with unchanged selection after manual scrolling. Assert reveal where the tab fits the viewport, unchanged scroll for same selected id, stationary add/content bounds, no extra events, and usable empty strip. Implement stable-id keyed tabs and post-measure reveal on initial display/selected-id change only; if a tab exceeds the viewport, reveal its beginning and allow scrolling to close. Verify focused instrumentation passes.

## 3. Integration verification

- [x] 3.1 Run `dune fmt`, `dune test`, `dune build`, `git diff --check`, and from `android/` run `./gradlew :app:assembleDebug :app:lintDebug :app:testDebugUnitTest :app:assembleDebugAndroidTest`. Run the configured-device instrumentation suite and record results; distinguish the previously known divider assertion (issue #3) from any new failure. Validate this change with `openspec validate style-project-tabs --strict`.
- [x] 3.2 Install the compatible APK/backend pair on the configured device and verify empty/single/many tabs, pinned add, automatic reveal, inactive close, active-neighbor close, last close, independent page navigation, Back/Refresh, preserved 8 dp pane inset, and the two-pane layout. Inspect both themes at scale 1.25 and text at 2.0. Save screenshots in `~/Desktop/remote-dev-tabs` for light/dark and overflow states, record evidence in this change, and restore the original system theme and font scale.

## Verification evidence

- Host: `dune fmt`, `dune test`, `dune build`, Android assemble/lint/unit tests/instrumentation compilation, strict change validation and `git diff --check` passed.
- Device `192.168.0.11:5555`, selected through repository `.envrc`: 54/55 instrumentation tests passed. Only the previously known `emulatorPanelSurfaceFillsAllocationAndPreservesPreview` failed (issue #3, expected -2235673 versus actual -2301466). All five new tab tests passed.
- Live checks: empty strip; creation through pinned add; session list in Tab 1 retained across switching; inactive close preserved selection/content; active close selected its neighbor; closing the last tab retained add; eight tabs overflowed and auto-revealed Tab 12; manual scrolling plus Refresh preserved scroll and selection. Back restored directories. The 8 dp end inset and 2:1 pane allocation remain intact.
- Screenshots, visually inspected: `/Users/igor/Desktop/remote-dev-tabs/empty-dark.png`, `tabs-dark.png`, `tabs-light.png`, `overflow-dark.png`, `overflow-light.png`, `tabs-light-200.png`.
- Original night mode `yes` and font scale `1.25` restored and verified. Compatible app/backend left running with one directory tab after removing extra test tabs.
- Independent whole-diff review found no actionable correctness, requirements or scope issues.

## Workflow follow-up

- Present the completed diff and verification results for review; commit when requested.
- Sync delta specs into main specs before archiving the completed change when requested.
