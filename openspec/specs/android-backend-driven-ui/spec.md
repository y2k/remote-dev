# android-backend-driven-ui Specification

## Purpose

Provide a minimal Android client that retrieves a backend-defined UI tree and renders its supported elements with a persistent manual reload control.

## Requirements

### Requirement: Load backend-driven UI
The Android client SHALL request the UI document by sending `POST /` to the configured backend origin with the JSON envelope `{"event":{"type":"load"},"value":null}` when the screen first appears. The client SHALL render a valid supported UI document from the response and SHALL expose loading and transport or parse failure states.

#### Scenario: Initial load succeeds
- **WHEN** the screen first appears and the endpoint returns a valid supported UI document
- **THEN** the client renders the document content

#### Scenario: Load fails
- **WHEN** the endpoint cannot be reached or its response cannot be parsed as a supported UI document
- **THEN** the client displays an error while keeping pull-to-refresh and the `Refresh` menu item available

### Requirement: Manual reload control
The Android client SHALL send the `load` event envelope to `POST /` when the user pulls down at the beginning of the screen content or activates the single menu item labelled `Refresh`. The client SHALL NOT display a separate `Reload` or `Retry` button.

#### Scenario: User reloads the document
- **WHEN** the user pulls down while the screen content is at its beginning
- **THEN** the client sends the `load` event and replaces the displayed state with the returned UI document

#### Scenario: User selects Refresh
- **WHEN** the user activates the `Refresh` menu item
- **THEN** the client sends the `load` event and replaces the displayed state with the returned UI document

#### Scenario: Manual refresh is in progress
- **WHEN** a request initiated by pull-to-refresh or `Refresh` is in progress
- **THEN** the client displays the refresh indicator until the request finishes

### Requirement: Supported UI nodes
The Android client SHALL recursively render a `column` node from its `children` array in vertical order, SHALL recursively render a `row` node from its `children` array in horizontal order, SHALL render a `text` node from its `text` string, SHALL render a `button` node from its `label` string, and SHALL render an `input` node from its `label` and `event` object. An input node MAY include a `text` string that provides the field's initial value. A button MAY include an `event` object. The client SHALL treat each `event` object as opaque backend-defined JSON.

#### Scenario: Render a column
- **WHEN** a valid `column` node contains supported child nodes
- **THEN** the client renders those children in vertical order

#### Scenario: Render a row
- **WHEN** a valid `row` node contains supported child nodes
- **THEN** the client renders those children in horizontal order

#### Scenario: Render text
- **WHEN** a valid `text` node contains a text string
- **THEN** the client renders that string as text

#### Scenario: Render a button
- **WHEN** a valid `button` node contains a label
- **THEN** the client renders an enabled button with that label

#### Scenario: Render an input
- **WHEN** a valid `input` node contains a label and valid event object
- **THEN** the client renders an editable single-line field with that label

#### Scenario: Render an input with initial text
- **WHEN** a valid `input` node includes a `text` string
- **THEN** the client renders the editable field with that string as its initial value

#### Scenario: Activate a backend button
- **WHEN** the user activates a backend-defined button that has no event
- **THEN** the client performs no action

#### Scenario: Activate a button with an action
- **WHEN** the user activates a backend-defined button whose event is an object
- **THEN** the client sends `POST /` with that object in the `event` field and `null` in the `value` field

### Requirement: Submit input with hardware Enter
The Android client SHALL render an `input` node as a single-line editable text field using its required `label` string. When that field has focus and the user releases the hardware Enter key, the client SHALL send `POST /` with the node's required event object in the `event` field and the field's current value in the `value` field.

#### Scenario: Render an input
- **WHEN** a valid input node contains string `label` and object `event` fields
- **THEN** the client renders an editable single-line field with that label

#### Scenario: Submit with hardware Enter
- **WHEN** a focused input contains text and the user releases the hardware Enter key
- **THEN** the client sends exactly one event request containing that text in its `value` field

#### Scenario: Press another hardware key
- **WHEN** a focused input receives a hardware key other than Enter
- **THEN** the client does not send an event request

#### Scenario: Submit while an input action is in progress
- **WHEN** an event request is already in progress and the user releases Enter again
- **THEN** the client does not start another request

### Requirement: Preserve submitted input
The Android client SHALL retain the submitted input and its current value while its event request is in progress and if that request fails before a valid UI document is received.

#### Scenario: Input action is in progress
- **WHEN** the client is waiting for an input event response
- **THEN** the submitted field and its current value remain displayed while the client exposes the in-progress state

#### Scenario: Input action fails
- **WHEN** an input event request fails or returns an invalid UI document
- **THEN** the client displays the failure without discarding the submitted field or its current value

### Requirement: Render action responses
The Android client SHALL expose a loading state while any backend-defined event is in progress and SHALL parse a successful response as a complete supported UI document.

#### Scenario: Action succeeds
- **WHEN** an event request returns a valid supported UI document
- **THEN** the client replaces the displayed backend-driven content with the returned document

#### Scenario: Action fails
- **WHEN** an event request cannot be completed or its response is not a supported UI document
- **THEN** the client displays an error while keeping pull-to-refresh and the `Refresh` menu item available

### Requirement: Reject unsupported documents
The Android client SHALL treat missing required fields, invalid field types, and node types other than `column`, `row`, `text`, `button`, or `input` as parse failures.

#### Scenario: Unsupported node type
- **WHEN** the document contains a node whose `@type` is not `column`, `row`, `text`, `button`, or `input`
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid text content
- **WHEN** a `text` node is missing its required string field or the field has another type
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid row children
- **WHEN** a `row` node is missing its children array or contains a non-object child
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid input content
- **WHEN** an `input` node is missing its required string `label` or object `event` field, either field has another type, or its optional `text` field is present with a non-string type
- **THEN** the client displays an error instead of partially rendering the document

### Requirement: Serialize event requests
The Android client SHALL NOT start an event request while another event request is in progress.

#### Scenario: User activates another event while waiting
- **WHEN** the client is waiting for a response to an event request
- **THEN** it does not send another event request

### Requirement: Forward system Back navigation
The Android client SHALL submit the JSON event envelope `{"event":{"type":"back"},"value":null}` when the user invokes the system Back button or Back gesture while no event request is in progress, and SHALL replace its backend-driven content with the successful response.

#### Scenario: User invokes system Back
- **WHEN** rendered backend-driven content is visible, no event request is in progress, and the user invokes system Back
- **THEN** the client sends exactly one `back` event envelope to `POST /`

#### Scenario: Back response succeeds
- **WHEN** the `back` event receives a valid supported UI document
- **THEN** the client replaces the rendered content with that document

### Requirement: Do not render a separate return control
The Android client SHALL NOT render a separate Android `Back` button for returning from a selected worktree.

#### Scenario: Selected worktree is displayed
- **WHEN** the backend returns a selected-worktree document without a `back` button
- **THEN** the client exposes system Back navigation without adding a visible return control

### Requirement: Configure development backend at build time
The Android build SHALL obtain `backendHost` from `local.properties`. A `-PbackendHost` Gradle property SHALL override that local value for one build. The produced client SHALL send backend requests to `http://<backendHost>:8080/`, where `<backendHost>` is the resolved value.

#### Scenario: Build with local backend host
- **WHEN** `local.properties` sets `backendHost=192.168.0.15` and a developer builds the Android client without `-PbackendHost`
- **THEN** the resulting client sends its backend requests to `http://192.168.0.15:8080/`

#### Scenario: Override local backend host
- **WHEN** `local.properties` sets `backendHost=192.168.0.15` and a developer builds with `-PbackendHost=192.168.0.42`
- **THEN** the resulting client sends its backend requests to `http://192.168.0.42:8080/`

#### Scenario: Build without configured backend host
- **WHEN** a developer starts an Android build without a non-empty `backendHost` in either source
- **THEN** the build fails before producing an APK and identifies `backendHost` as required

### Requirement: Restrict development cleartext traffic
The Android client SHALL permit cleartext HTTP traffic only to the `backendHost` configured for that build and SHALL NOT enable cleartext traffic globally for other destinations.

#### Scenario: Connect to the development backend
- **WHEN** the client requests `http://<backendHost>:8080/` using the host configured at build time
- **THEN** Android network security permits the cleartext connection

### Requirement: Authorize Android 17 local network access
The Android client SHALL declare `ACCESS_LOCAL_NETWORK` and SHALL obtain that runtime permission on Android 17 or higher before requesting the development endpoint.

#### Scenario: User grants local network access
- **WHEN** the client runs on Android 17 or higher and the user grants local network access
- **THEN** the client requests and renders the backend-driven UI

#### Scenario: User denies local network access
- **WHEN** the client runs on Android 17 or higher and the user denies local network access
- **THEN** the client displays an error without making the endpoint request and keeps pull-to-refresh and the `Refresh` menu item available

#### Scenario: User retries local network permission
- **WHEN** local network access is denied and the user pulls to refresh or activates the `Refresh` menu item
- **THEN** the client requests local network permission again without requesting the development endpoint first

#### Scenario: Client runs before Android 17
- **WHEN** the client runs on an Android version lower than 17
- **THEN** the client requests the development endpoint without showing the local network permission prompt
