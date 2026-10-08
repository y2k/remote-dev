# Spec Delta

## MODIFIED Requirements

### Requirement: Log a directory click without changing state
In Claude mode, processing a directory-row click SHALL write one console log entry identifying the absolute path and return unchanged application state, without selection, navigation, directory reload, or agent execution. Path control characters SHALL be escaped so each click produces one log line. In OpenCode mode, a click on a currently listed directory in a tab's directory screen SHALL instead open that directory's OpenCode session list within that tab, preserving the common directory data and emulator state. A path not present in the advertised directory list SHALL NOT initiate session loading or creation.

#### Scenario: Click a directory
- **WHEN** the client activates `/projects/example` in Claude mode and the backend processes the event
- **THEN** the console receives one entry identifying the path
- **AND** the returned UI retains the same state without navigation, directory reload, or agent execution

#### Scenario: Repeat a click
- **WHEN** the backend processes two successive clicks on the same Claude directory row
- **THEN** it writes one entry for each click and retains the same state

#### Scenario: Directory name contains a line break
- **WHEN** the backend processes a Claude directory click whose path contains a line break
- **THEN** the log escapes the line break and contains the path within one line

#### Scenario: OpenCode directory selection
- **WHEN** the user activates `/projects/example` on a tab's directory screen
- **THEN** that tab displays the session list for `/projects/example` without creating another tab or a separate window
- **AND** the directory list and emulator state are preserved

#### Scenario: Unknown directory event
- **WHEN** an OpenCode directory click supplies a path absent from the current directory list
- **THEN** no OpenCode request is made and the tab remains unchanged

### Requirement: Refresh the directory component independently
Root Refresh on the standalone directory screen or an active OpenCode tab's directory screen SHALL reload and re-sort directories from the captured root. In OpenCode, Refresh with zero tabs SHALL perform no load, and Refresh on a session-list or chat screen SHALL refresh that screen rather than directories. Directory refresh SHALL preserve tabs, navigation and emulator state and SHALL NOT load worktrees or OpenCode sessions. Back on a directory screen SHALL keep the UI unchanged without an error. Directories SHALL load at initialization in Claude mode, when creating the first OpenCode tab from zero tabs, and on explicit directory-screen refresh, without polling. Additional tabs and tab selection SHALL reuse the common list. Emulator refresh SHALL remain independent.

#### Scenario: Directory set changes
- **WHEN** directories have been added, removed, or modified and root Refresh is sent on a directory screen
- **THEN** the common list reflects eligible directories in the existing order and limit
- **AND** tabs, navigation, selection and emulator state are preserved

#### Scenario: Back at startup
- **WHEN** the standalone directory screen or a tab's directory screen receives Back
- **THEN** it stays unchanged without a new error or directory reload

#### Scenario: Emulator-only refresh
- **WHEN** the user invokes the emulator panel's own refresh
- **THEN** the directory component and its last loaded entries remain unchanged

#### Scenario: Empty tab UI refresh
- **WHEN** root Refresh is received with zero tabs
- **THEN** the backend returns the complete empty tab UI without reading directories or creating a tab

#### Scenario: Session-screen refresh
- **WHEN** the active tab shows a session list or chat and receives root Refresh
- **THEN** only that screen's OpenCode data is reloaded and no directory scan occurs
