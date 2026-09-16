## ADDED Requirements

### Requirement: Graphite visual presentation
The Android client SHALL follow the system light/dark appearance setting. In dark appearance it SHALL use a graphite background `#14171C`, control surfaces `#1D222A`, and primary action accent `#82AAFF`. Ordinary backend-defined text SHALL use the theme's foreground color rather than its primary action color, with light foreground text in dark appearance and legible dark foreground text in light appearance. The application header SHALL retain the `remote_dev` title and visible `Refresh` action. Content SHALL have consistent outer spacing and rounded input fields, while preserving the existing two-pane ratio, screen navigation, and weighted scrolling behavior.

#### Scenario: Dark appearance
- **WHEN** the client renders backend content with system dark appearance enabled
- **THEN** the background, control surfaces, and primary actions use the graphite palette
- **AND** ordinary text is light foreground text rather than blue accent text
- **AND** the header displays `remote_dev` and an available Refresh action

#### Scenario: Light appearance
- **WHEN** the client renders backend content with system light appearance enabled
- **THEN** it uses a light theme with legible foreground text and controls rather than forcing a dark background

#### Scenario: Preserve layout while styling
- **WHEN** a session, worktree, or list screen is displayed with the new styling
- **THEN** content and emulator panes retain their existing two-to-one width ratio
- **AND** weighted content retains its scrolling behavior and navigation retains separate list and detail screens

### Requirement: Visible input submission action
Each input SHALL expose an arrow-shaped submit button within its rounded field. Activating it while no UI event request is in progress SHALL submit exactly one event request using the input's unchanged backend event and current locally edited value, with the same submission and response behavior as hardware Enter. The button SHALL have an accessible action description and a touch target of at least 48 dp. During a UI event request the button SHALL be disabled and SHALL NOT queue another submission. Existing hardware Enter submission, input preservation during requests and failures, and adjacent voice-input behavior SHALL remain available under their existing rules.

#### Scenario: Submit locally edited text
- **WHEN** the user edits an input and activates its arrow while no event request is in progress
- **THEN** exactly one request contains the input's backend event and current edited text in the value field

#### Scenario: Submit voice-populated text
- **WHEN** voice recognition populates a prompt, the user edits it, and activates its arrow
- **THEN** the request submits the edited text rather than the original recognition result

#### Scenario: Prevent duplicate submission
- **WHEN** a UI event request is in progress
- **THEN** the arrow is disabled and its activation sends or queues no request

#### Scenario: Preserve failed input
- **WHEN** an arrow-triggered input request fails before a valid UI document is received
- **THEN** the submitted field and text remain visible alongside the error under the existing input-preservation behavior

#### Scenario: Accessible submission control
- **WHEN** the input is rendered
- **THEN** assistive technology can identify the arrow as a submit action and its touch target is at least 48 dp

### Requirement: Readable shortcut button group
The Claude worktree shortcut buttons SHALL be arranged vertically with each button occupying its group's available width. Button order, labels, and events SHALL be preserved. At a 400 dp viewport width, this group SHALL NOT compress later buttons into narrow vertical strips, and the Commands input and voice control SHALL remain visible. The root content-to-emulator width ratio SHALL remain 2:1. Emulator Refresh and device-selection buttons SHALL retain their existing horizontal row.

#### Scenario: Narrow worktree screen
- **WHEN** a worktree screen is rendered in a 400 dp wide viewport
- **THEN** its two shortcuts appear one below the other across the left pane width
- **AND** the Commands input and microphone remain visible below them

#### Scenario: Emulator controls at any width
- **WHEN** the emulator panel is rendered with available devices
- **THEN** Refresh and each device-selection button appear in their existing horizontal row and order
- **AND** selection and refresh use their unchanged backend events
