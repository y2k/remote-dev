# Spec Delta

## MODIFIED Requirements

### Requirement: Load backend-driven UI
The Android client SHALL request the initial UI document with `GET /` to the configured backend origin when the screen first appears. The client SHALL render the valid supported UI document from the `application/json` response and SHALL expose loading and transport or parse failure states.

#### Scenario: Initial load succeeds
- **WHEN** the screen first appears and the endpoint returns a valid supported UI document
- **THEN** the client renders that document

#### Scenario: Load fails
- **WHEN** the endpoint cannot be reached or its response cannot be parsed as a supported UI document
- **THEN** the client displays an error while keeping pull-to-refresh available

### Requirement: Manual reload control
The Android client SHALL send the provider-neutral root Refresh event when the user pulls down at the beginning of the screen content. The client SHALL NOT display a client-owned `Refresh` menu item or a separate `Reload` or `Retry` button. Backend-defined refresh controls SHALL retain their existing behavior.

#### Scenario: User reloads the document
- **WHEN** the user pulls down while the screen content is at its beginning
- **THEN** the client sends Refresh and replaces the displayed state with the returned UI document

#### Scenario: User selects Refresh
- **WHEN** the user looks for the former global `Refresh` menu item
- **THEN** that client-owned action is absent and manual document refresh is available through pull-to-refresh instead

#### Scenario: Manual refresh is in progress
- **WHEN** a request initiated by pull-to-refresh is in progress
- **THEN** the client displays the refresh indicator until the request finishes

### Requirement: Render action responses
The Android client SHALL expose a loading state while any backend-defined event is in progress and SHALL parse a successful response as a complete supported UI document.

#### Scenario: Action succeeds
- **WHEN** an event request returns a valid supported UI document
- **THEN** the client replaces the displayed backend-driven content with that document

#### Scenario: Action fails
- **WHEN** an event request cannot be completed or its response is not a supported UI document
- **THEN** the client displays an error while keeping pull-to-refresh available

### Requirement: Authorize Android 17 local network access
The Android client SHALL declare `ACCESS_LOCAL_NETWORK` and SHALL obtain that runtime permission on Android 17 or higher before requesting the development endpoint.

#### Scenario: User grants local network access
- **WHEN** the client runs on Android 17 or higher and the user grants local network access
- **THEN** the client requests and renders the backend-driven UI

#### Scenario: User denies local network access
- **WHEN** the client runs on Android 17 or higher and the user denies local network access
- **THEN** the client displays an error without making the endpoint request and keeps pull-to-refresh available

#### Scenario: User retries local network permission
- **WHEN** local network access is denied and the user pulls to refresh
- **THEN** the client requests local network permission again without requesting the development endpoint first

#### Scenario: Client runs before Android 17
- **WHEN** the client runs on an Android version lower than 17
- **THEN** the client requests the development endpoint without showing the local network permission prompt

### Requirement: Graphite visual presentation
The Android client SHALL follow the system light/dark appearance setting. In dark appearance it SHALL use a graphite background `#14171C`, control surfaces `#1D222A`, and primary action accent `#82AAFF`. Ordinary backend-defined text SHALL use the theme's foreground color rather than its primary action color, with light foreground text in dark appearance and legible dark foreground text in light appearance. The client SHALL NOT render the application header with the `remote_dev` title and global `Refresh` action or reserve space for it. Content SHALL occupy the freed height while respecting system safe drawing insets. Content SHALL have consistent outer spacing and rounded input fields, while preserving the existing two-pane ratio, screen navigation, and weighted scrolling behavior.

#### Scenario: Dark appearance
- **WHEN** the client renders backend content with system dark appearance enabled
- **THEN** the background, control surfaces, and primary actions use the graphite palette
- **AND** ordinary text is light foreground text rather than blue accent text
- **AND** no application header with `remote_dev` and global Refresh is displayed

#### Scenario: Light appearance
- **WHEN** the client renders backend content with system light appearance enabled
- **THEN** it uses a light theme with legible foreground text and controls rather than forcing a dark background

#### Scenario: Preserve layout while styling
- **WHEN** a session, worktree, or list screen is displayed with the new styling
- **THEN** content and emulator panes retain their existing two-to-one width ratio
- **AND** weighted content retains its scrolling behavior and navigation retains separate list and detail screens

#### Scenario: Reclaim header space in every screen state
- **WHEN** the client displays loading, content, a request failure, or a local-network permission error in either appearance
- **THEN** there is no application header or blank space reserved for it
- **AND** the screen content uses the freed height within system safe drawing insets
