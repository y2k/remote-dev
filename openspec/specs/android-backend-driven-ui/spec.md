# android-backend-driven-ui Specification

## Purpose

Provide a minimal Android client that retrieves a backend-defined UI tree and renders its supported elements with a persistent manual reload control.

## Requirements

### Requirement: Load backend-driven UI
The Android client SHALL request the initial UI document with `GET /` to the configured backend origin when the screen first appears. The client SHALL render the valid supported UI document from the `application/json` response and SHALL expose loading and transport or parse failure states.

#### Scenario: Initial load succeeds
- **WHEN** the screen first appears and the endpoint returns a valid supported UI document
- **THEN** the client renders that document

#### Scenario: Load fails
- **WHEN** the endpoint cannot be reached or its response cannot be parsed as a supported UI document
- **THEN** the client displays an error while keeping pull-to-refresh and the `Refresh` menu item available

### Requirement: Render streamed UI documents for commands
The Android client SHALL read an `application/x-ndjson` UI-event response line by line and replace the displayed UI document for every valid complete document until the response closes.

#### Scenario: Navigation command streams UI documents
- **WHEN** a UI-event request returns `application/x-ndjson` with more than one complete document
- **THEN** the client renders each document in response order and permits the next UI event after the response closes

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

### Requirement: Supported UI nodes
The Android client SHALL recursively render a `column` node from its `children` array in vertical order, SHALL recursively render a `row` node from its `children` array in horizontal order, SHALL render a `text` node from its `text` string, SHALL render a `button` node from its `label` string, SHALL render an `input` node from its `label` and `event` object, and SHALL render an `image` node from its backend-relative `src` path and `label` string. A `column` or `row` node MAY include a `weights` array containing one non-negative finite number for each child. A weighted `column` SHALL fill the available height, measure zero-weight children at their content height, allocate the remaining height among positive-weight children in proportion to their weights, and allow each positive-weight child to scroll vertically when its content exceeds its allocation. A weighted `row` SHALL fill the available width, measure zero-weight children at their content width, and allocate the remaining width among positive-weight children in proportion to their weights. When `weights` is absent, the client SHALL preserve the existing content-sized layout for that node, except for the width behavior explicitly enabled by column `stretch`. An image `src` path SHALL begin with `/` and SHALL NOT begin with `//`; the client SHALL resolve it against the configured backend origin. An input node MAY include a `text` string that provides the field's initial value. A button MAY include an `event` object. The client SHALL treat each `event` object as opaque backend-defined JSON.

#### Scenario: Render a column
- **WHEN** a valid `column` node contains supported child nodes and omits `weights`
- **THEN** the client renders those children in vertical order using their content-sized heights

#### Scenario: Render a weighted column
- **WHEN** a valid `column` contains three children and `weights` of `[0, 1, 0]`
- **THEN** the client fills the available height, gives the first and third children their content heights, and gives the second child the remaining height

#### Scenario: Scroll a positive-weight column child
- **WHEN** the content of a positive-weight child is taller than its allocated area
- **THEN** the user can scroll that child vertically while zero-weight siblings remain in place

#### Scenario: Render a row
- **WHEN** a valid `row` node contains supported child nodes and omits `weights`
- **THEN** the client renders those children in horizontal order using their content-sized widths

#### Scenario: Render a weighted row
- **WHEN** a valid `row` node contains two children and `weights` of `[2, 1]`
- **THEN** the client fills the available row width and allocates two thirds to the first child and one third to the second child

#### Scenario: Render a weighted row with a zero weight
- **WHEN** a valid `row` contains two children and `weights` of `[0, 1]`
- **THEN** the client gives the first child its content width and gives the second child the remaining width

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

#### Scenario: Render an image
- **WHEN** a valid `image` node contains a string `src` path beginning with `/` but not `//` and a string `label` field
- **THEN** the client renders the image using the configured backend origin and exposes the label when the image cannot be displayed

#### Scenario: Activate a backend button
- **WHEN** the user activates a backend-defined button that has no event
- **THEN** the client performs no action

#### Scenario: Activate a button with an action
- **WHEN** the user activates a backend-defined button whose event is an object
- **THEN** the client sends `POST /` with that object in the `event` field and `null` in the `value` field

### Requirement: Stretch column children horizontally
A `column` SHALL accept an optional boolean `stretch` field, defaulting to `false`. When `stretch` is `true`, the column and each immediate child SHALL occupy the full available width within the parent's layout bounds. Stretch SHALL NOT change text alignment or image aspect-ratio behavior. It SHALL NOT enable stretch recursively on descendants of an immediate child container. Stretch SHALL preserve the height allocation and scrolling rules of `weights`. When `stretch` is absent or `false`, the client SHALL preserve existing width behavior. A present non-boolean `stretch`, including null, SHALL cause a parse failure.

#### Scenario: Stretch ordinary children
- **WHEN** a column with `stretch: true` contains a button, input, and text within a bounded parent
- **THEN** the column and each child's layout area occupy the parent's available width while retaining their normal content-sized heights
- **AND** text retains its existing alignment

#### Scenario: Preserve default layout
- **WHEN** the same column omits `stretch` or sets it to `false`
- **THEN** its layout matches the existing behavior without forced full-width children

#### Scenario: Stretch within a narrower parent
- **WHEN** a stretching column is placed within a parent narrower than the screen
- **THEN** it and its immediate children fill that parent's available width without extending to the screen edges

#### Scenario: Stretch does not recursively enable itself
- **WHEN** a stretching column contains a row without weights and a column without stretch, each containing short buttons
- **THEN** both immediate child containers fill the outer column's width
- **AND** their buttons retain their own content-sized width

#### Scenario: Stretch a weighted column
- **WHEN** a stretching column has `weights: [0, 1, 0]` and overflowing content in the middle child
- **THEN** all three immediate children fill the available width
- **AND** the middle child scrolls within the remaining height while the first and last controls remain visible

#### Scenario: Reject invalid stretch
- **WHEN** a column's `stretch` field contains a string, number, null, array, or object
- **THEN** the client rejects the document as a parse failure

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

### Requirement: Serialize event requests
The Android client SHALL NOT start an event request while another event request is in progress.

#### Scenario: User activates another event while waiting
- **WHEN** the client is waiting for a response to an event request
- **THEN** it does not send another event request

### Requirement: Forward system Back navigation
The Android client SHALL submit the JSON event envelope `{"event":["Back"],"value":null}` when the user invokes the system Back button or Back gesture while no event request is in progress, and SHALL replace its backend-driven content with the successful response.

#### Scenario: User invokes system Back
- **WHEN** rendered backend-driven content is visible, no event request is in progress, and the user invokes system Back
- **THEN** the client sends exactly one `Back` event envelope to `POST /`

#### Scenario: Back response succeeds
- **WHEN** the `Back` event receives a valid supported UI document
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

### Requirement: Optional image tap event
An `image` node SHALL accept an optional `event` containing an opaque backend-defined JSON array, using the existing wire event representation. An image without `event` SHALL retain its display-only behavior. A present event that is not a JSON array, including null, SHALL cause a parse failure. The client SHALL preserve the image label as its content description.

#### Scenario: Parse an interactive image
- **WHEN** an otherwise valid image contains an event array
- **THEN** the client renders the image and retains that event unchanged for tap submission

#### Scenario: Preserve a display-only image
- **WHEN** an image omits event and the user taps it
- **THEN** no event request is sent and normal image polling continues

#### Scenario: Reject an invalid image event
- **WHEN** an image event is null, an object, string, number, or boolean
- **THEN** the client rejects the document as a parse failure

### Requirement: Submit a single image tap in source pixels
When a decoded image with an event receives a completed single tap and no UI event request is in progress, the client SHALL send exactly one `POST /` request containing the unchanged event and a string `value` encoding a JSON object with integer fields `x`, `y`, `width`, and `height`. Width and height SHALL describe the displayed source bitmap in pixels. Coordinates SHALL identify the tapped source pixel after accounting for the rendered image's scale and alignment, with `0 <= x < width` and `0 <= y < height`. Taps outside the painted image, taps before a bitmap is available, and cancelled or dragged gestures SHALL NOT submit a tap. Image taps SHALL use the existing event request serialization and response rendering behavior, without queueing taps made while another event is in progress.

#### Scenario: Tap a scaled image
- **WHEN** a 1080 by 1920 bitmap is painted at 270 by 480 and a single tap lands 135 pixels right and 240 pixels down from its painted top-left corner
- **THEN** one request carries the image event and a value encoding `{"x":540,"y":960,"width":1080,"height":1920}`

#### Scenario: Tap a centered image with margins
- **WHEN** the painted bitmap occupies only part of its layout bounds
- **THEN** a tap inside the bitmap is measured from its painted top-left corner
- **AND** a tap in an unpainted margin sends no event

#### Scenario: Another request is running
- **WHEN** the user taps an interactive image while another UI event request is in progress
- **THEN** no tap request is sent or queued for later

#### Scenario: Image has not loaded
- **WHEN** the image is showing loading or failure content without a decoded bitmap
- **THEN** tapping that content sends no image event

#### Scenario: User drags or cancels a gesture
- **WHEN** a pointer gesture is recognized as a drag or is cancelled before completion
- **THEN** it sends no image tap event

#### Scenario: Tap response arrives
- **WHEN** the backend returns UI documents for a tap and the same image source remains rendered
- **THEN** the client renders the documents through its existing event response handling
- **AND** continues the existing three-second image polling without an additional tap-triggered image request

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

### Requirement: Theme background for layout containers
The client SHALL accept an optional `background` string on `row` and `column` nodes. Its supported values SHALL be exactly `background`, `surface`, `surfaceContainer`, `primary`, `primaryContainer`, and `outlineVariant`, case-sensitive. The client SHALL resolve the role from its current theme and paint the container's layout bounds behind its children, including inter-child spacing. An omitted field SHALL leave the container transparent. The field SHALL NOT change layout measurements, spacing, stretch, weight allocation, scrolling, or descendant foreground and control colors. Descendant containers without their own background SHALL remain transparent; an explicitly colored descendant SHALL paint its own background.

#### Scenario: Resolve each supported role
- **WHEN** a valid row or column specifies any of the six supported background roles
- **THEN** its background uses the corresponding color from the client's current theme

#### Scenario: Follow the current appearance
- **WHEN** the same document is displayed in light and dark appearance
- **THEN** each background role resolves through the active appearance's theme rather than a color fixed in the document

#### Scenario: Preserve an uncolored container
- **WHEN** a row or column omits background
- **THEN** it adds no background fill and retains its existing layout behavior

#### Scenario: Paint bounds without changing layout
- **WHEN** background is added to a row or column using existing weights or column stretch
- **THEN** the fill covers that container's allocated bounds and inter-child spacing
- **AND** child measurements, spacing, weight allocation, stretch, and scrolling remain unchanged

#### Scenario: Preserve descendant colors
- **WHEN** a container with text and controls specifies background
- **THEN** the text and controls retain their existing foreground and control colors without automatic contrast adjustment

#### Scenario: Nested backgrounds
- **WHEN** a colored container includes one transparent child container and another with an explicit background
- **THEN** the parent fill remains visible through the transparent child's unpainted areas
- **AND** the explicitly colored child paints its own bounds with its selected theme role

### Requirement: Validate container background values
A present `background` on a row or column that is not one of the supported strings, including null, SHALL cause a document parse failure under the existing failure behavior rather than partial rendering or silent fallback.

#### Scenario: Reject invalid background
- **WHEN** a row or column provides an unknown role, differently cased role, RGB string, number, boolean, null, array, or object as background
- **THEN** the client rejects the document as a parse failure

### Requirement: Backend container background serialization
The backend UI composition API SHALL support selecting any of the six background roles independently for rows and columns. Serialization SHALL emit the selected role as the node's `background` string and SHALL omit the field when no background was selected. Mapping component events SHALL preserve selected backgrounds and existing layout attributes, including in nested containers.

#### Scenario: Serialize selected backgrounds
- **WHEN** the backend serializes a row or column with a selected background role
- **THEN** the node contains the corresponding supported `background` string

#### Scenario: Preserve existing wire documents
- **WHEN** the backend serializes containers without a selected background
- **THEN** their JSON has no background field and retains the existing representation

#### Scenario: Map events in colored containers
- **WHEN** the backend maps events in nested colored rows and columns before serialization
- **THEN** their background roles and layout attributes are preserved while events are mapped normally

### Requirement: Full-height themed emulator panel
On every screen containing the shared Emulators panel, the backend SHALL select `surface` for the panel's background and compose the panel to occupy its full allocated width and the full available content height. The fill SHALL include unused space below the panel's content, including when no emulator is selected, none are running, or an emulator error is displayed. In the current dark palette the fill SHALL be `#1D222A`; in light appearance it SHALL use that theme's `surface`. The panel SHALL preserve the existing 2:1 content-to-emulator width ratio, control order and horizontal control row, preview aspect ratio, image tap behavior, and descendant colors. The fill SHALL NOT alter screenshot pixels or extend into the application header or outer content margins.

#### Scenario: Short or empty emulator content
- **WHEN** the panel shows a short preview, a selection prompt, no running emulators, or an emulator error
- **THEN** its surface background spans the entire right-hand allocation to the bottom of the available content area, including unused space below the content

#### Scenario: Panel follows the theme
- **WHEN** a screen with the Emulators panel is rendered in dark or light appearance
- **THEN** the entire panel uses the active theme's surface color, with `#1D222A` in the current dark palette

#### Scenario: Preserve panel boundaries and interactions
- **WHEN** the themed panel displays an emulator preview and controls
- **THEN** the two panels retain their 2:1 width ratio and the emulator controls retain their existing horizontal order and actions
- **AND** the screenshot pixels, aspect ratio, and tap mapping remain unchanged
- **AND** the application header, outer margins, and descendant colors retain their existing appearance

### Requirement: Container padding
The client SHALL accept an optional `padding` object on `row` and `column` nodes containing required `start`, `top`, `end`, and `bottom` fields in whole non-negative dp. An omitted padding object SHALL mean zero on every side. Padding SHALL inset the children's layout area within the container's background. Start and end SHALL follow layout direction. Padding SHALL apply only to the declaring container and SHALL NOT implicitly configure descendants.

#### Scenario: Independent sides
- **WHEN** a container specifies `padding: {"start":16,"top":8,"end":4,"bottom":12}` with sufficient available space
- **THEN** its inner layout is inset by the corresponding values in dp, with start on the left in LTR and on the right in RTL
- **AND** the container background covers the padding

#### Scenario: Default and nested padding
- **WHEN** a padded container contains another container omitting padding
- **THEN** only the outer container adds padding and the inner container adds none

### Requirement: Configurable container gaps
The client SHALL accept an optional `gap` object on `row` and `column` nodes with a required whole non-negative `size` in dp and an optional `color` theme role. An omitted gap object SHALL mean size 4 dp with no color. Size SHALL control horizontal space between adjacent row children or vertical space between adjacent column children. Gaps SHALL exist only between immediate children, not before the first or after the last child. A zero gap SHALL add no space or painted stripe. Empty and single-child containers SHALL have no gaps.

#### Scenario: Set row and column spacing
- **WHEN** a row or column with three children specifies `gap: {"size":12}` and has enough space for that gap
- **THEN** exactly two transparent 12 dp gaps separate the children along the container's main axis

#### Scenario: Preserve old documents
- **WHEN** a row or column omits padding and gap
- **THEN** it retains the existing zero-padding layout with transparent 4 dp inter-child spacing

#### Scenario: No separator slots
- **WHEN** a container has fewer than two children or specifies a zero-size gap
- **THEN** it paints no gap stripe and allocates no gap space for those cases

### Requirement: Theme-colored gap painting
A gap color SHALL accept exactly the case-sensitive roles `background`, `surface`, `surfaceContainer`, `primary`, `primaryContainer`, and `outlineVariant`, resolved through the active client theme. An omitted color SHALL leave the gap transparent. A colored gap SHALL paint the actual inter-child region across the full inner cross-axis extent, above the container background but behind the children. It SHALL NOT paint padding, outer edges, unused trailing space, or child layout areas. Changing only the gap color SHALL NOT change layout or descendant colors. Nested containers SHALL paint only their own gaps.

#### Scenario: Explicit background and gap color
- **WHEN** a padded column has `background: "surface"` and `gap: {"size":8,"color":"primary"}`
- **THEN** its padding retains the surface fill and each gap is a primary-colored horizontal stripe across the inner width
- **AND** children retain their own foreground and background colors

#### Scenario: Row stripe with unequal children
- **WHEN** a row contains children of different heights and a colored gap
- **THEN** the gap stripe spans the full inner row height without making that height grow

#### Scenario: Transparent or matching gap color
- **WHEN** a container sets a background and omits gap color
- **THEN** the background is visible through the gap
- **AND** explicitly choosing the same theme role for gap and background produces the same gap appearance

#### Scenario: Follow theme and document updates
- **WHEN** the theme, child dimensions, child count, layout direction, or document changes
- **THEN** colored gaps use the current theme and current adjacent-child boundaries without retaining stripes from the previous layout

### Requirement: Spacing composes with existing layout allocation
Padding and gap size SHALL participate in the existing row and column layout: weights SHALL continue to reference only the original children and distribute remaining inner main-axis space after fixed-size children and gaps. Column stretch SHALL fill the inner width after padding. Existing positive-weight column-child scrolling SHALL remain within that child's allocation. Gap painting SHALL use the actual space produced by layout and SHALL remain within the inner container bounds when constraints leave less room than requested; it SHALL NOT force overflow to preserve the requested stripe size.

#### Scenario: Weighted row
- **WHEN** a 200 dp wide row has 10 dp start and end padding, two equally weighted children, and a 20 dp gap
- **THEN** each child receives 80 dp width and the gap occupies the 20 dp between them

#### Scenario: Stretch and scroll inside padding
- **WHEN** a padded stretching column has weights `[0,1,0]`, a custom gap, and overflowing content in its middle child
- **THEN** all child allocations fill the inner width and the middle child scrolls within the height remaining after padding, gaps, and fixed children
- **AND** changing gap color does not change those allocations or scrolling behavior

#### Scenario: Constrained gap
- **WHEN** the available inner main-axis space cannot accommodate the requested gap size
- **THEN** the client uses its normal constrained layout behavior and paints only actual inter-child space within the inner bounds

### Requirement: Validate container spacing fields
Present padding and gap fields SHALL be objects, not null. Padding SHALL contain all four sides; gap SHALL contain size. Each dimension SHALL be a JSON integer from 0 through 2147483647; negative, fractional, out-of-range, string, boolean, null, array, and object dimensions SHALL cause a document parse failure. A present gap color SHALL be one of the supported theme-role strings; null, unknown roles, differently cased roles, RGB strings, and other types SHALL cause a document parse failure. Failure SHALL use the existing whole-document parse-failure behavior.

#### Scenario: Reject malformed dimensions
- **WHEN** either container supplies a non-object padding or gap, a missing required dimension, or an invalid dimension value
- **THEN** the client rejects the document rather than coercing the value or partially rendering it

#### Scenario: Reject invalid gap color
- **WHEN** either container supplies `gap.color` as null, `"Primary"`, `"#FF8800"`, an unknown role, or a non-string value
- **THEN** the client rejects the document

### Requirement: Backend spacing composition and serialization
The backend composition API SHALL support equal-sided padding, independent horizontal and vertical padding, selectively specified sides with unspecified sides defaulting to zero, and a gap size with optional existing theme color. Both container constructors SHALL accept these settings. Helpers SHALL reject dimensions outside the supported integer range. Serialization SHALL emit selected padding as one object with all four fields and selected gap as one object with size and, only when selected, color. Unselected padding and gap SHALL be omitted. Mapping component events SHALL preserve spacing, backgrounds, weights, and stretch in nested containers.

#### Scenario: Normalize padding helpers
- **WHEN** backend code selects equal padding of 12, symmetric horizontal 16 and vertical 8, or only top 8 and bottom 16
- **THEN** serialization respectively emits sides `(12,12,12,12)`, `(16,8,16,8)`, or `(0,8,0,16)` in start/top/end/bottom order

#### Scenario: Serialize gap settings
- **WHEN** backend code selects a gap of 8 with primary color or a gap of 12 without color
- **THEN** serialization respectively emits `{"size":8,"color":"primary"}` or `{"size":12}` as the node's gap

#### Scenario: Preserve defaults and mapped events
- **WHEN** backend code maps events in nested containers with a mixture of selected and omitted spacing attributes
- **THEN** selected spacing and other layout attributes are preserved, omitted attributes remain absent, and events are mapped normally

### Requirement: Themed divider between content and emulator panels
Every screen using the shared content-and-emulator layout, including the session list and chat, SHALL use a 1 dp vertical gap in `outlineVariant` between the two panels. The divider SHALL span the full available inner content height without extending into the application header or outer margins. In dark appearance `outlineVariant` SHALL be `#343A43`; light appearance SHALL use the standard light-theme outlineVariant color. The two panels SHALL retain their 2:1 allocation of the remaining width and existing interactions.

#### Scenario: Session list and chat divider
- **WHEN** the session list or chat is displayed beside the emulator panel
- **THEN** a 1 dp themed divider separates them for the full available content height
- **AND** the panel width ratio, preview aspect ratio, image taps, and scrolling remain intact

#### Scenario: Switch divider appearance
- **WHEN** the appearance changes between dark and light
- **THEN** the divider changes between `#343A43` and the standard light-theme outlineVariant color without changing its width

### Requirement: Uniform themed container border
The client SHALL accept an optional `border` object on `row` and `column` nodes with required `width` and `color` fields. Width SHALL be whole non-negative dp. Color SHALL accept exactly the case-sensitive theme roles `background`, `surface`, `surfaceContainer`, `primary`, `primaryContainer`, and `outlineVariant`, resolved through the active theme. A positive width SHALL paint a solid uniform border around the entire perimeter inside the container's outer layout bounds, above its background and children. An omitted border or width zero SHALL paint no line, including no hairline. Border SHALL NOT add padding or change measurements, child positions, gap geometry, stretch, weights, or scrolling allocation. Existing padding SHALL determine the inset of children independently of border width.

#### Scenario: Render both container borders
- **WHEN** a row or column specifies `border: {"width":2,"color":"outlineVariant"}`
- **THEN** a solid 2 dp border follows all four outer edges inside the container bounds using the current outlineVariant color
- **AND** switching appearance resolves the color through the new theme

#### Scenario: Border does not consume space
- **WHEN** a 200 dp wide row with 10 dp start and end padding, a 20 dp gap, and two equally weighted children gains a 2 dp border
- **THEN** both children retain 80 dp width and their original positions
- **AND** the border overlays the perimeter without adding an automatic content inset

#### Scenario: Omitted or zero border
- **WHEN** a container omits border or specifies a valid border with width zero
- **THEN** no border line is painted and its layout remains unchanged

### Requirement: Container corner radius and content clipping
The client SHALL accept an optional `cornerRadius` dimension on `row` and `column`, in whole non-negative dp, independently of border and background. Omission SHALL mean zero. A positive radius SHALL round all four corners equally on the container's outer bounds and SHALL apply the same outer shape to its background, border, and clipping of all descendant drawing, including colored gaps and child backgrounds or images. The effective radius SHALL be at most half the smaller outer dimension. The border SHALL follow this shape inside the bounds and remain visible above children. Radius SHALL NOT alter layout measurements or implicitly set descendant radius attributes. Omitted or zero radius SHALL retain square corners and SHALL NOT introduce new content clipping.

#### Scenario: Rounded container with a border
- **WHEN** a row or column has a background, a border, and `cornerRadius: 12`
- **THEN** the background and border share a 12 dp outer corner shape where dimensions permit
- **AND** descendant drawing is clipped to that shape without changing child allocation

#### Scenario: Radius without border or background
- **WHEN** a container has `cornerRadius: 12`, no border or background, and a child image or colored child reaching its outer corners
- **THEN** the child's drawing outside the rounded shape is clipped and the ancestor behind those corners remains visible

#### Scenario: Preserve square defaults
- **WHEN** a container omits cornerRadius or specifies zero
- **THEN** it retains square corners and its existing content-overflow behavior, with any border drawn inside the rectangular bounds

#### Scenario: Clamp radius to container size
- **WHEN** a 40 dp by 20 dp container specifies `cornerRadius: 100`
- **THEN** its effective outer radius is 10 dp and its layout remains 40 dp by 20 dp

#### Scenario: Rounded weighted column
- **WHEN** a padded stretching column with weights `[0,1,0]`, colored gaps, and an overflowing middle child gains a border and positive radius
- **THEN** the child allocations, gap positions, and middle-child scrolling remain unchanged
- **AND** all descendant drawing remains clipped to the outer rounded shape while the border remains visible

### Requirement: Validate container border and radius
A present border SHALL be an object containing both width and color. Border width and a present cornerRadius SHALL each be JSON integers in `0..2147483647`, using the same dimension rules as container spacing. Missing required border fields, null or non-object border, negative, fractional, out-of-range or non-integer dimensions, and null, unknown or non-string color roles SHALL cause the existing whole-document parse failure rather than coercion or partial rendering.

#### Scenario: Reject malformed decoration
- **WHEN** either container specifies border as null, an array, a scalar, or an object missing width or color
- **THEN** the document is rejected as a parse failure

#### Scenario: Reject invalid dimensions
- **WHEN** border.width or cornerRadius contains `-1`, `1.5`, `1.0`, `2147483648`, a string, boolean, null, array, or object
- **THEN** the document is rejected as a parse failure

#### Scenario: Reject invalid color even for zero width
- **WHEN** a border color is null, `"Primary"`, `"#FF8800"`, an unknown role, or a non-string value, including with width zero
- **THEN** the document is rejected as a parse failure

### Requirement: Backend border and radius composition
The backend composition API SHALL support optional uniform border width and required existing theme color, and optional independent corner radius, on both container constructors. It SHALL reject dimensions outside `0..2147483647`. Serialization SHALL emit selected borders as `border: {"width": <integer>, "color": <role>}` and selected radii as `cornerRadius: <integer>`, including explicitly selected zeros, and SHALL omit unselected attributes. Mapping events SHALL preserve these attributes together with backgrounds, padding, gaps, weights, stretch, and nested child structure.

#### Scenario: Serialize selected decoration
- **WHEN** the backend selects a 2 dp outlineVariant border and a 12 dp radius for a row or column
- **THEN** serialization emits `"border":{"width":2,"color":"outlineVariant"}` and `"cornerRadius":12`

#### Scenario: Preserve omission and explicit zero
- **WHEN** containers select neither attribute, only radius zero, or a valid zero-width border
- **THEN** serialization respectively omits both attributes, emits cornerRadius zero without border, or emits the zero-width border with its selected color

#### Scenario: Map nested decorated containers
- **WHEN** backend events are mapped in nested rows and columns with a mixture of omitted and selected decoration attributes
- **THEN** events are mapped normally and every decoration and existing layout attribute retains its value and omission state
