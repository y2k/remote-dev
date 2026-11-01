# Spec Delta

## ADDED Requirements

### Requirement: Project directory cards
The directory component SHALL render each listed directory as a full-width interactive card with 8 dp between cards. Each card SHALL display only its existing directory name as a `projectTitle`, without a nested title button, icon, added path, or selected accent. It SHALL use the shared card appearance and preserve the existing root, error, empty-state, ordering, and limit behavior.

#### Scenario: Render loaded directories
- **WHEN** the component displays eligible directories
- **THEN** every directory is a card with its name, including the first entry without special highlighting
- **AND** the existing root path remains outside the cards

#### Scenario: Long directory name
- **WHEN** a name exceeds the available width, including at 125% system font scale
- **THEN** it wraps and the card grows vertically without truncation or horizontal scrolling

### Requirement: Activate a project card
Activating any point within a directory card's visible bounds SHALL submit that directory's existing absolute-path event once. OpenCode SHALL open the folder's session list in the current tab; Claude SHALL retain its existing log-only behavior. Scrolling and disabled-during-request behavior SHALL follow the shared card interaction contract.

#### Scenario: Tap card padding in OpenCode
- **WHEN** no request is in progress and the user taps padding inside a listed directory card in OpenCode mode
- **THEN** that folder's session list opens in the current tab without changing the emulator or other tabs

#### Scenario: Tap a card in Claude mode
- **WHEN** no request is in progress and the user activates a directory card in Claude mode
- **THEN** the existing directory event logs the absolute path once without navigation or agent execution
