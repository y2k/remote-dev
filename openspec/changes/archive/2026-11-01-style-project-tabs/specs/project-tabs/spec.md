# Spec Delta

## MODIFIED Requirements

### Requirement: Backend owns tab behavior
The backend SHALL advertise tab controls through a semantic `tab_strip` node and opaque events on the existing UI endpoint. The Android client SHALL NOT maintain a domain-level tab model or implement tab-specific navigation or refresh routing. The common emulator panel SHALL remain outside tab content with its existing selection and layout behavior.

#### Scenario: Tab event response
- **WHEN** a client submits an advertised create, select, or delete event
- **THEN** the backend returns the complete resulting UI using the existing JSON or NDJSON response protocol

#### Scenario: Emulator survives tab operations
- **WHEN** the user creates, selects, or deletes tabs, including the last tab
- **THEN** the loaded emulator list and selected emulator are preserved

## ADDED Requirements

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
