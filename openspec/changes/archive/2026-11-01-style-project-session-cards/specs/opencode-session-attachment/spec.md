# Spec Delta

## ADDED Requirements

### Requirement: Session list cards
Each session row SHALL use the shared interactive card appearance, fill the list width, and have 8 dp separation from adjacent cards. It SHALL display the existing title as `sessionTitle`, and the directory and status as `cardMeta`, including complete retry details. It SHALL NOT add icons, badges, timestamps, a nested title button, or a separate Continue action.

#### Scenario: Display session states
- **WHEN** idle, busy, and retry sessions are listed
- **THEN** each card displays its title, directory, and existing status text, including the retry message
- **AND** status uses the same muted text treatment for all states

#### Scenario: Long session data
- **WHEN** a title, directory, or retry message exceeds the available width, including at 125% system font scale
- **THEN** every field wraps without truncation or horizontal scrolling and the card grows vertically

### Requirement: Preserve session selection and list controls with cards
Activating a session card SHALL select that exact session through its existing event. The list SHALL retain exact-folder filtering, newest-first ordering, the 20-session limit, Back and Refresh behavior, and failure retention. The creation control or its progress replacement SHALL remain before the cards in their shared vertical scrolling region.

#### Scenario: Tap secondary text or padding
- **WHEN** no event request is in progress and the user taps a session's directory, status, or card padding
- **THEN** the same session opens as when its title is activated, in the current tab

#### Scenario: Scroll the session list
- **WHEN** the user scrolls a list taller than its allocation
- **THEN** cards and the creation control or progress replacement scroll together
- **AND** the gesture does not select a session

#### Scenario: Refresh fails with loaded cards
- **WHEN** session refresh fails after a successful load
- **THEN** previous cards and folder context remain visible with the error and the existing retry and Back actions remain available
