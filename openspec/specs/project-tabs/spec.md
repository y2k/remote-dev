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
Activating `+` SHALL append a tab and make it active. Tabs SHALL have stable identities and default labels `Tab N`, numbered monotonically from 1 within a backend process without renumbering remaining tabs after deletion. Each tab SHALL offer a selection action and the active tab SHALL be visibly identified. Selecting a tab SHALL preserve tab order and SHALL NOT invoke an agent or change the selected emulator. Tab controls SHALL remain reachable when the list exceeds its allocated space.

#### Scenario: Create two tabs
- **WHEN** the user creates two tabs from the empty state
- **THEN** `Tab 1` and `Tab 2` appear in creation order and `Tab 2` is active

#### Scenario: Switch tabs
- **WHEN** the user selects `Tab 1` while `Tab 2` is active
- **THEN** `Tab 1` becomes active and displays the project list without changing the emulator or tab order

#### Scenario: Create after deleting all tabs
- **WHEN** `Tab 1` and `Tab 2` have been deleted and the user creates another tab
- **THEN** the new active tab is labelled `Tab 3`

#### Scenario: Many tabs
- **WHEN** tab controls exceed their available layout space
- **THEN** the user can scroll horizontally to reach selection and deletion controls for every tab while the creation control stays visible

### Requirement: Horizontal tab strip
The application SHALL display tabs in a single horizontal strip above the active tab's project list, in creation order, with selection and deletion controls for each tab. Overflow SHALL scroll horizontally within the left content pane rather than wrap onto multiple lines, form a vertical tab list, or extend into the emulator panel. The `+` control SHALL remain visible at the right of the strip outside its scrollable region, including when there are zero tabs. Scrolling the tab strip SHALL NOT scroll the project list or change tab selection.

#### Scenario: Tabs fit the available width
- **WHEN** the tab controls fit within the strip
- **THEN** they appear on one horizontal line above the project list with `+` on the right

#### Scenario: Overflowing strip
- **WHEN** the tabs exceed the available strip width
- **THEN** the user can scroll the tabs horizontally to reach every tab's selection and deletion controls
- **AND** `+` stays visible and the project list and emulator panel remain in place

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
Each tab SHALL display the existing directory list for the same captured startup root. All tabs SHALL use the same last loaded entries and directory-load error, without independent per-tab snapshots. Creating the first tab from zero tabs SHALL load the list. Creating additional tabs or switching tabs SHALL display the current list without another filesystem read. Directory selection SHALL retain its existing log-only behavior without navigation or agent execution. A root Refresh with tabs present SHALL reload this common list and return complete UI documents while preserving tab identities, order, selection and emulator state. With zero tabs, Refresh SHALL return the empty tab UI without a directory load. System Back on the tab UI SHALL preserve tabs and selection.

#### Scenario: Same list across tabs
- **WHEN** two tabs exist and the common project list has been refreshed
- **THEN** switching between them displays the same updated entries and error state

#### Scenario: First tab cannot load projects
- **WHEN** the first tab is created and its directory load fails
- **THEN** the tab remains active and displays the existing directory error presentation, allowing retry through root Refresh

#### Scenario: Refresh remains client-neutral
- **WHEN** the user pulls to refresh or selects Refresh from the Android menu
- **THEN** the client sends the existing root Refresh event without a tab identifier and replaces the complete UI from the response
- **AND** the backend preserves tabs and selection while reloading the common list if tabs exist

#### Scenario: Back on tabs
- **WHEN** the tab UI receives system Back with zero or more tabs
- **THEN** tabs and selection remain unchanged

### Requirement: Backend owns tab behavior
The backend SHALL advertise tab controls through existing supported UI nodes and opaque events on the existing UI endpoint. The Android client SHALL NOT maintain a domain-level tab model or implement tab-specific navigation or refresh routing. The common emulator panel SHALL remain outside tab content with its existing selection and layout behavior.

#### Scenario: Tab event response
- **WHEN** a client submits an advertised create, select, or delete event
- **THEN** the backend returns the complete resulting UI using the existing JSON or NDJSON response protocol

#### Scenario: Emulator survives tab operations
- **WHEN** the user creates, selects, or deletes tabs, including the last tab
- **THEN** the loaded emulator list and selected emulator are preserved
