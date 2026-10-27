# Spec Delta

## MODIFIED Requirements

### Requirement: Create a session in the selected folder
The session-list screen SHALL show a button labelled «Создать новую сессию» above its rows, inside the same vertical scrolling area as the rows rather than pinned outside it. During creation, its replacement progress label SHALL occupy the same position in that scrolling area. Activating it SHALL create one OpenCode session in that folder and open its empty chat in the same tab, without an intermediate form or automatic prompt. Creation SHALL use discovered V2 service authentication and preserve the returned identity. Missing title SHALL display as «Без названия»; missing agent and model SHALL remain unset.

#### Scenario: Create from a populated or empty list
- **WHEN** the user activates the creation button and the server accepts creation
- **THEN** the tab opens the returned session's empty chat with a prompt input
- **AND** the server receives the selected folder as the creation context and no prompt is submitted

#### Scenario: Return after creation
- **WHEN** the user presses Back after successful creation
- **THEN** the new session is present in that folder's loaded list, retaining the 20-session limit

#### Scenario: Creation fails
- **WHEN** the server rejects creation or cannot be reached
- **THEN** the tab stays on the folder's session list with an error, retains loaded rows, and allows explicit retry
- **AND** no fabricated session or chat is opened and no automatic creation retry occurs

#### Scenario: Scroll past the creation button and return
- **WHEN** the session list overflows its viewport and the user scrolls down far enough to pass the creation button
- **THEN** the button moves with the session rows and leaves the viewport rather than remaining pinned
- **AND** scrolling back to the top reveals the button before the first session row

#### Scenario: Creation is in progress
- **WHEN** session creation is pending
- **THEN** the button is replaced by the progress label within the shared scrolling area above the rows

#### Scenario: Empty or failed session load
- **WHEN** the folder has no sessions or its initial session load fails
- **THEN** the creation button remains available at the start of the scrolling area above any empty-state content
- **AND** a failed load is still displayed as an error rather than a successful empty list
