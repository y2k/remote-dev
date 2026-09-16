## ADDED Requirements

### Requirement: Icon-only voice input node
The client SHALL render a `voice_input` node as a standalone compact microphone icon button with a required opaque backend-defined JSON array `event`. The node SHALL expose no configurable visible text, label, or icon. A present `label` or `text` field SHALL cause a parse failure. The control SHALL provide an accessible action description and a touch target of at least 48 dp, without a visible caption. Voice input SHALL be usable wherever supported child nodes are accepted.

#### Scenario: Render voice input
- **WHEN** a document contains `{"@type":"voice_input","event":["VoiceResult"]}` as a container child
- **THEN** the client renders a compact microphone icon button without a visible caption and preserves the event unchanged
- **AND** the button has an accessible description and a touch target of at least 48 dp

#### Scenario: Reject configurable text
- **WHEN** a voice input node includes `label` or `text`, including an empty string or null
- **THEN** the client rejects the document as a parse failure

#### Scenario: Reject invalid event
- **WHEN** a voice input node omits `event` or supplies a value other than a JSON array
- **THEN** the client rejects the document as a parse failure

### Requirement: Hold to record and submit recognized text
With microphone permission granted, recognition available, and no UI event or voice operation in progress, pressing the voice button SHALL start a Russian-language speech recognition session. Releasing it SHALL request stopping capture if capture is still active and allow recognition to finish. The recognition service is allowed to finish a phrase before release, including during a pause; continuous capture until release is not guaranteed. The client SHALL NOT automatically restart recognition during the same hold. The client SHALL send one `POST /` event request per successful completed recording, only after both release and a non-empty final result, containing the unchanged node event and the first final recognition alternative as string `value`. It SHALL NOT send partial results or send a result before release. Recording and recognition-in-progress SHALL be visually distinguishable without a button caption. Responses SHALL use existing UI event response rendering.

#### Scenario: Hold and release
- **WHEN** the user presses an available voice button, speaks, and releases it
- **THEN** recognition starts on press and release requests stopping capture if it is still active
- **AND** the client indicates recognition in progress while waiting for a final result or failure
- **AND** a non-empty final result produces one request with the original event and recognized text in `value`

#### Scenario: Intermediate results
- **WHEN** recognition produces partial text while the button is held or recognition is finishing
- **THEN** no request is sent for that partial text

#### Scenario: Final result arrives before release
- **WHEN** the service returns a non-empty final result while the user is still holding the button
- **THEN** the client retains the first final recognition alternative without sending an event or starting another session
- **AND** releasing the button sends exactly one event with the retained text

#### Scenario: Service ends capture during a pause
- **WHEN** the recognition service ends capture during a pause before the user releases the button
- **THEN** the client does not restart capture during that hold
- **AND** it sends text only after both release and a non-empty final result

#### Scenario: Recognition is unavailable
- **WHEN** the device has no available speech recognition service
- **THEN** the voice button is unavailable and cannot start capture or send a voice event

#### Scenario: Recognition returns no text or fails
- **WHEN** the completed recording produces empty or whitespace-only text, or recognition fails
- **THEN** no backend event is sent and the control becomes available again
- **AND** a recognition failure is exposed to the user without adding a button caption

### Requirement: Voice input permission and cancellation
The client SHALL obtain microphone permission before capture. If permission is requested, granting it SHALL require a new press to start recording. Denial SHALL be exposed without capture or a backend event. Gesture cancellation, application backgrounding, removal or replacement of the active voice node, or the start of another UI event request SHALL cancel its pending voice operation and prevent any late result from being submitted. Cancellation SHALL also discard a final result retained before release. Microphone capture SHALL stop on cancellation. New voice recordings SHALL be unavailable while a voice operation (including waiting for release) or a UI event request is in progress; blocked actions SHALL NOT be queued.

#### Scenario: First use requests permission
- **WHEN** the user presses the button without microphone permission
- **THEN** the client requests permission without starting capture
- **AND** granting permission does not start capture until a new press

#### Scenario: Permission denied
- **WHEN** microphone permission is denied
- **THEN** the client exposes the denial and sends no event or audio capture request

#### Scenario: Cancel or leave
- **WHEN** a gesture is cancelled, the app goes into the background, or the active voice node is removed or replaced during capture or recognition
- **THEN** the operation is cancelled, microphone capture stops, and late results send no event

#### Scenario: Another event starts during capture
- **WHEN** a UI event request starts while a voice operation is pending
- **THEN** the voice operation is cancelled without queueing its result

#### Scenario: Cancel a retained result
- **WHEN** a final result has arrived before release and the gesture is cancelled or the active voice node is removed
- **THEN** the retained text is discarded and no voice event is sent

#### Scenario: Busy button
- **WHEN** a voice operation or a UI event request is already in progress and the user presses the voice button
- **THEN** no new recording starts and no action is queued

### Requirement: Voice input populates prompt fields
The Worktree screen SHALL place the voice button immediately to the right of the `Commands` input, and the OpenCode session screen SHALL place it immediately to the right of the `Prompt` input. Each input SHALL occupy the remaining row width while the voice control retains its compact 48 dp width. A successful voice result SHALL replace the entire corresponding input value through backend UI state and a returned UI document. It SHALL NOT execute a command or submit a prompt to an agent. The user SHALL be able to edit the resulting text and submit the current input with the existing Enter action.

#### Scenario: Fill Commands with speech
- **WHEN** a successful voice result is received from the button to the right of `Commands` on the Worktree screen
- **THEN** the returned UI displays the recognized text as the entire Commands input value
- **AND** no agent or command execution starts

#### Scenario: Fill Prompt with speech
- **WHEN** a successful voice result is received from the button to the right of `Prompt` on the OpenCode session screen
- **THEN** the returned UI displays the recognized text as the entire Prompt input value
- **AND** no prompt is submitted to OpenCode

#### Scenario: Replace a locally edited draft with a repeated result
- **WHEN** the user edits an input locally and a subsequent successful voice result equals the previously rendered server-side prompt
- **THEN** the returned UI replaces the local draft with that recognized text even though the server-side prompt value has not changed

#### Scenario: Edit and submit recognized text
- **WHEN** the user edits the voice-populated input and releases Enter while no event request is in progress
- **THEN** the existing submit action sends the current edited input value

#### Scenario: Render prompt row
- **WHEN** either prompt screen is rendered
- **THEN** its input and voice button share one row, with the button on the right at 48 dp width and the input filling the remaining width

## MODIFIED Requirements

### Requirement: Reject unsupported documents
The Android client SHALL treat missing required fields, invalid field types, a `column` or `row` whose `weights` is not an array of one non-negative finite number per child, and node types other than `column`, `row`, `text`, `button`, `input`, `image`, or `voice_input` as parse failures.

#### Scenario: Unsupported node type
- **WHEN** the document contains a node whose `@type` is not `column`, `row`, `text`, `button`, `input`, `image`, or `voice_input`
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid text content
- **WHEN** a `text` node is missing its required string field or the field has another type
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid row children
- **WHEN** a `row` node is missing its children array or contains a non-object child
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid row weights
- **WHEN** a `row` node has a `weights` value that is not an array, differs in length from `children`, or contains a non-number, non-finite number, or negative number
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid column weights
- **WHEN** a `column` node has a `weights` value that is not an array, differs in length from `children`, or contains a non-number, non-finite number, or negative number
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid input content
- **WHEN** an `input` node is missing its required string `label` or object `event` field, either field has another type, or its optional `text` field is present with a non-string type
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid image content
- **WHEN** an `image` node is missing its required string `src` or `label` field, either field has another type, or `src` is not a path beginning with `/` but not `//`
- **THEN** the client displays an error instead of partially rendering the document
