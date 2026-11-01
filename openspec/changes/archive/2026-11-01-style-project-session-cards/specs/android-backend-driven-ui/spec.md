# Spec Delta

## ADDED Requirements

### Requirement: Interactive card wire format
The client SHALL accept a `card` node with required `children` and `event` arrays. Children SHALL be recursively parsed supported UI nodes; event SHALL remain opaque backend-defined JSON. Missing or wrongly typed fields, including null, SHALL reject the whole document. Cards SHALL be accepted wherever a supported child node is accepted.

#### Scenario: Parse a card
- **WHEN** a document contains `{"@type":"card","event":["Select","s1"],"children":[{"@type":"text","text":"Session","style":"sessionTitle"}]}`
- **THEN** the client retains the event and renders the card with its text child

#### Scenario: Reject malformed cards
- **WHEN** a card omits children or event, either field is not an array, or a child is invalid
- **THEN** the entire document fails parsing rather than rendering partially

### Requirement: Shared card appearance
Cards SHALL use the active theme's `surfaceContainerLow`, 12 dp corners, 12 dp internal padding on every side, no border, and a subtle 1 dp shadow. Children SHALL appear vertically with 2 dp gaps. Cards SHALL fill their allocated width, have at least 48 dp height, and grow to fit wrapped content. Card-specific colors SHALL take precedence over generic graphite control-surface colors.

#### Scenario: Light and dark cards
- **WHEN** the same card is displayed in light and dark appearance
- **THEN** its fill resolves to the current theme's `surfaceContainerLow` (`#F5F7FA` light and `#181C20` dark in the current palette)
- **AND** geometry remains unchanged with no border or first-card accent

#### Scenario: Narrow card with scaled text
- **WHEN** card content wraps within a narrow allocation at 125% font scale
- **THEN** the card grows in height while retaining padding and its allocated width

### Requirement: Card activation
A card SHALL expose one accessible click action and standard Android ripple clipped to its rounded shape. A completed click anywhere inside its visible bounds SHALL submit exactly one event with the unchanged event array and null value. While an event request is in progress, activation SHALL be disabled and SHALL NOT send or queue requests. Cancelled gestures and scrolling drags SHALL NOT activate a card.

#### Scenario: Activate padding
- **WHEN** no request is in progress and a completed tap lands inside card padding
- **THEN** one request carries that card's event and a null value

#### Scenario: Prevent accidental activation
- **WHEN** a user scrolls from a card, cancels a gesture, or taps while an event is in progress
- **THEN** no card event is sent or queued

#### Scenario: Accessible activation
- **WHEN** the card is focused through accessibility or keyboard navigation
- **THEN** its text identifies one actionable card and activating it uses the same event as touch

### Requirement: Card text roles
Text nodes SHALL additionally accept `projectTitle`, `sessionTitle`, and `cardMeta` style values. Titles SHALL use system typography at 17 sp with 22 sp line height, weight 500 and 600 respectively, and `onSurface`. Metadata SHALL use 12/18 sp, weight 400, and `onSurfaceVariant`. All three SHALL use zero letter spacing and wrap without truncation. Existing styles and the omitted-style body default SHALL retain their behavior.

#### Scenario: Render card typography
- **WHEN** text specifies any of the three card roles
- **THEN** its size, line height, weight, and foreground follow that role in both themes using the system font without downloads

#### Scenario: Preserve older text documents
- **WHEN** text omits style or uses body, heading, caption, or code
- **THEN** its rendering retains its existing typography and foreground behavior

#### Scenario: Reject invalid style
- **WHEN** text style is null, a non-string, differently cased, or unknown
- **THEN** the whole document fails parsing

### Requirement: Backend card event composition
The backend SHALL serialize cards with their ordered children and event arrays. Mapping component events SHALL transform card events and recursively map descendant events while preserving text roles and child order. Existing nodes SHALL retain their serialized representation.

#### Scenario: Map a card into a tab
- **WHEN** a component card event is wrapped with tab identity and generation
- **THEN** the serialized card contains the wrapped event and unchanged ordered text content and roles

## MODIFIED Requirements

### Requirement: Reject unsupported documents
The Android client SHALL treat missing required fields, invalid field types, a `column` or `row` whose `weights` is not an array of one non-negative finite number per child, and node types other than `column`, `row`, `text`, `button`, `input`, `image`, `voice_input`, or `card` as parse failures.

#### Scenario: Unsupported node type
- **WHEN** the document contains a node whose `@type` is not `column`, `row`, `text`, `button`, `input`, `image`, `voice_input`, or `card`
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
