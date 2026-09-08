## MODIFIED Requirements

### Requirement: Manual reload control
The Android client SHALL send the provider-neutral root Refresh event when the user pulls down at the beginning of the screen content or activates the single menu item labelled `Refresh`. The client SHALL NOT display a separate `Reload` or `Retry` button.

#### Scenario: User reloads the document
- **WHEN** the user pulls down while the screen content is at its beginning
- **THEN** the client sends Refresh and replaces the displayed state with the returned UI document

#### Scenario: User selects Refresh
- **WHEN** the user activates the `Refresh` menu item
- **THEN** the client sends Refresh and replaces the displayed state with the returned UI document

#### Scenario: Manual refresh is in progress
- **WHEN** a request initiated by pull-to-refresh or `Refresh` is in progress
- **THEN** the client displays the refresh indicator until the request finishes

### Requirement: Forward system Back navigation
The Android client SHALL submit the JSON event envelope `{"event":["Back"],"value":null}` when the user invokes the system Back button or Back gesture while no event request is in progress, and SHALL replace its backend-driven content with the successful response.

#### Scenario: User invokes system Back
- **WHEN** rendered backend-driven content is visible, no event request is in progress, and the user invokes system Back
- **THEN** the client sends exactly one `Back` event envelope to `POST /`

#### Scenario: Back response succeeds
- **WHEN** the `Back` event receives a valid supported UI document
- **THEN** the client replaces the rendered content with that document
