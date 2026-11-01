# project-tabs Specification

## Purpose

Позволяет управлять временными табами со списком проектов в OpenCode-режиме через интерфейс, полностью определяемый backend.

## Requirements

### Requirement: Start with no tabs and retain tabs in memory
In OpenCode mode the application SHALL start with zero tabs and no active tab. It SHALL display a `+` control and the shared emulator panel without a project list until a tab is created. Tab identities, order, and selection SHALL live only in backend process memory. Fetching or refreshing the UI and reconnecting the client SHALL preserve them; restarting the backend SHALL discard them.

#### Scenario: Initial empty state
- **WHEN** the OpenCode backend starts and the client loads the UI
- **THEN** the UI has zero tabs, a `+` control, the agent label and the shared emulator panel, and no project list

#### Scenario: Reload without restarting
- **WHEN** tabs exist and the client reloads, refreshes, or reconnects to the same backend process
- **THEN** the tab order and active selection remain unchanged

#### Scenario: Backend restart
- **WHEN** the backend restarts after tabs have been created
- **THEN** it starts with zero tabs again

### Requirement: Create and select tabs
Activating `+` SHALL append a tab displaying directories and make it active. Tabs SHALL have stable identities and default labels `Tab N`, numbered monotonically from 1 within a backend process without renumbering remaining tabs after deletion. Each tab SHALL offer a selection action and the active tab SHALL be visibly identified. Selecting a tab SHALL restore its current screen without loading data, invoking an agent, changing tab order, or changing the selected emulator. Tab controls SHALL remain reachable when the list exceeds its allocated space.

#### Scenario: Create two tabs
- **WHEN** the user creates two tabs from the empty state
- **THEN** `Tab 1` and `Tab 2` appear in creation order and `Tab 2` is active on the directory list

#### Scenario: Switch tabs
- **WHEN** the user selects `Tab 1` while `Tab 2` is active
- **THEN** `Tab 1` restores its directory, session-list, or chat screen without changing the emulator or tab order and without another load

#### Scenario: Create after deleting all tabs
- **WHEN** `Tab 1` and `Tab 2` have been deleted and the user creates another tab
- **THEN** the new active tab is labelled `Tab 3`

#### Scenario: Many tabs
- **WHEN** tab controls exceed their available layout space
- **THEN** the user can scroll horizontally to reach selection and deletion controls for every tab while the creation control stays visible

### Requirement: Horizontal tab strip
The application SHALL display tabs in a single horizontal strip above the active tab's content, in creation order, with selection and deletion controls for each tab. Overflow SHALL scroll horizontally within the left content pane rather than wrap onto multiple lines, form a vertical tab list, or extend into the emulator panel. The `+` control SHALL remain visible at the right of the strip outside its scrollable region, including when there are zero tabs. Scrolling the tab strip SHALL NOT scroll the tab content or change tab selection.

#### Scenario: Tabs fit the available width
- **WHEN** the tab controls fit within the strip
- **THEN** they appear on one horizontal line above the active directory, session-list, or chat screen with `+` on the right

#### Scenario: Overflowing strip
- **WHEN** the tabs exceed the available strip width
- **THEN** the user can scroll the tabs horizontally to reach every tab's selection and deletion controls
- **AND** `+` stays visible and the tab content and emulator panel remain in place

#### Scenario: Empty strip
- **WHEN** no tabs exist
- **THEN** `+` remains available at the right of the empty strip and no project list is displayed

### Requirement: Delete any tab
Each tab SHALL expose a deletion action that removes only that tab. Deleting an inactive tab SHALL preserve the active selection. Deleting the active tab SHALL select its next neighbor in creation order, or its previous neighbor if no next neighbor exists. Deleting the last tab SHALL leave zero tabs with `+` and the shared emulator panel still available. Deletion SHALL NOT delete project directories or OpenCode sessions. Actions targeting a tab that no longer exists SHALL leave tab state unchanged.

#### Scenario: Delete inactive tab
- **WHEN** the user deletes an inactive tab
- **THEN** only that tab disappears and the active tab remains selected

#### Scenario: Delete active middle tab
- **WHEN** `Tab 2` is active between `Tab 1` and `Tab 3` and is deleted
- **THEN** `Tab 3` becomes active

#### Scenario: Delete active last tab with a neighbor
- **WHEN** `Tab 2` is active after `Tab 1` and is deleted
- **THEN** `Tab 1` becomes active

#### Scenario: Delete the only tab
- **WHEN** the only remaining tab is deleted
- **THEN** no tab or project list is displayed, and `+` and the emulator panel remain available

#### Scenario: Stale tab action
- **WHEN** a selection or deletion event identifies a previously deleted tab
- **THEN** no other tab is selected or deleted

### Requirement: Display the common project list in each tab
Each tab SHALL initially display the existing directory list for the same captured startup root. Directory screens SHALL use the same last loaded entries and directory-load error, without independent per-tab directory snapshots. Creating the first tab from zero tabs SHALL load the list. Creating additional tabs or switching tabs SHALL reuse the current list. Selecting a listed directory SHALL open its session list within the same tab. Root Refresh SHALL reload only the active screen's data and return complete UI documents while preserving tab identities, order, selection and emulator state. With zero tabs, Refresh SHALL return the empty tab UI without a load. System Back SHALL navigate within the active tab and SHALL leave its directory screen unchanged.

#### Scenario: Same list across tabs
- **WHEN** two tabs show directories and the common project list has been refreshed
- **THEN** switching between them displays the same updated entries and error state

#### Scenario: First tab cannot load projects
- **WHEN** the first tab is created and its directory load fails
- **THEN** the tab remains active and displays the existing directory error presentation, allowing retry through root Refresh

#### Scenario: Refresh remains client-neutral
- **WHEN** the user pulls to refresh or selects Refresh from the Android menu
- **THEN** the client sends the existing root Refresh event without a tab identifier and replaces the complete UI from the response
- **AND** the backend preserves tabs and selection while reloading directories, the selected folder's sessions, or the selected chat according to the active screen

#### Scenario: Back on tabs
- **WHEN** the tab UI receives system Back with zero tabs or while the active tab displays directories
- **THEN** tabs and selection remain unchanged
- **AND** Back in a chat returns to its folder's sessions and Back in a session list returns to directories

### Requirement: Backend owns tab behavior
The backend SHALL advertise tab controls through a semantic `tab_strip` node and opaque events on the existing UI endpoint. The Android client SHALL NOT maintain a domain-level tab model or implement tab-specific navigation or refresh routing. The common emulator panel SHALL remain outside tab content with its existing selection and layout behavior.

#### Scenario: Tab event response
- **WHEN** a client submits an advertised create, select, or delete event
- **THEN** the backend returns the complete resulting UI using the existing JSON or NDJSON response protocol

#### Scenario: Emulator survives tab operations
- **WHEN** the user creates, selects, or deletes tabs, including the last tab
- **THEN** the loaded emulator list and selected emulator are preserved

### Requirement: Preserve independent tab navigation
Each tab SHALL retain its selected directory, session list, selected session, and loaded chat state while inactive. Navigating in one tab SHALL NOT change another tab's screen. Closing a tab SHALL discard only its in-memory state without deleting or aborting OpenCode sessions. Restarting the backend SHALL discard all tab navigation state.

#### Scenario: Two independent chats
- **WHEN** the user opens a chat in one tab, opens a different folder in another tab, and switches back
- **THEN** the first tab restores its chat and loaded state, including any prompt draft and error, without reloading

#### Scenario: Close a chat tab
- **WHEN** the user closes a tab containing a busy session
- **THEN** the tab disappears using the existing neighbor-selection rules and no session deletion or abort request is sent

### Requirement: Route tab actions and results to their originating tab
Tab-content actions and operation results SHALL target their originating tab and applicable screen or session, never whichever tab happens to be active later. Results for a closed tab or replaced screen SHALL NOT change another screen or recreate a tab. The backend SHALL reject client-submitted internal load, creation, submission, and command-completion results.

#### Scenario: Background command completes after switching tabs
- **WHEN** a slash command started in tab A fails while tab B is active
- **THEN** the error belongs to the original session in tab A and tab B remains unchanged

#### Scenario: Result arrives after closing or navigating away
- **WHEN** an operation completes after its tab is closed or its target screen is replaced
- **THEN** it does not recreate the tab, navigate the user, or overwrite unrelated screen state

#### Scenario: Forged completion
- **WHEN** a client submits a nested internal session-created or session-loaded result
- **THEN** the backend rejects the event without changing state or issuing an OpenCode operation

### Requirement: Styled project tab controls
The project strip SHALL retain `Tab N` labels without the textual active marker `*`. Each tab SHALL expose separate selection and close actions; addition and closing SHALL use icons instead of text buttons. The strip SHALL use the shared Android tab-strip appearance and interaction contract while preserving existing creation, selection, closing, and navigation behavior.

#### Scenario: Render active and inactive tabs
- **WHEN** Tab 2 is active alongside Tab 1
- **THEN** both labels retain their numbers, only Tab 2 has the active treatment, and each has a separate close icon
- **AND** the add icon remains visible at the right of the strip, outside horizontal scrolling

#### Scenario: Close without selecting
- **WHEN** the user activates the close icon on inactive Tab 1
- **THEN** Tab 1 closes without being selected and the active tab's content is retained

#### Scenario: Close the last tab
- **WHEN** the only tab is closed
- **THEN** the strip retains its add icon, no tab is selected, and the shared emulator remains visible

### Requirement: Reveal the newly active tab
When the displayed active tab identity changes, the strip SHALL scroll horizontally as needed to reveal that tab without moving the content or pinned add action. Ordinary document refreshes with the same active identity SHALL NOT reset a user's horizontal scroll. Revealing a tab SHALL NOT submit another backend event.

#### Scenario: Add beyond the viewport
- **WHEN** creation appends and selects a tab beyond the visible strip
- **THEN** its selection and close controls become visible without a manual swipe

#### Scenario: Close active tab near the viewport edge
- **WHEN** closing the active tab selects an offscreen neighbor under the existing neighbor rules
- **THEN** the newly active tab is revealed

#### Scenario: Refresh after browsing the strip
- **WHEN** the user scrolls away from the active tab and a document refresh retains its identity
- **THEN** the strip does not jump back to that tab
