# Spec Delta

## ADDED Requirements

### Requirement: Semantic tab strip wire format
The client SHALL accept a `tab_strip` node wherever supported child nodes are accepted. It SHALL require a `tabs` array and an opaque `addEvent` array. Every tab SHALL require a unique nonempty string `id`, string `label`, boolean `selected`, and opaque arrays `selectEvent` and `closeEvent`. Empty strips SHALL have no selection; nonempty strips SHALL have exactly one selected tab.

#### Scenario: Parse a populated strip
- **WHEN** a strip contains two valid tab records with one selected
- **THEN** order, identities, labels, selected state and all event arrays are retained

#### Scenario: Parse an empty strip
- **WHEN** a strip has `tabs: []` and a valid `addEvent`
- **THEN** it renders only the add action

#### Scenario: Reject malformed strip
- **WHEN** a required field is missing, null, or wrongly typed, a tab is not an object, an identity is empty or duplicated, or a nonempty strip has zero or multiple selections
- **THEN** the entire document fails parsing without partial rendering or coercion

### Requirement: Backend tab strip event mapping
The backend SHALL serialize tab strips with their ordered records and required fields. Component event mapping SHALL transform addition, selection, and closing events while retaining identities, labels, selection and order. Existing nodes SHALL retain their representation.

#### Scenario: Map strip into application events
- **WHEN** a strip is mapped into the enclosing application's message type
- **THEN** all three kinds of event receive that wrapper and the displayed state is unchanged

### Requirement: Tab strip theme and typography
The strip SHALL use `surfaceContainerLow` and a 1 dp `outlineVariant` bottom divider. The selected tab SHALL use `surface`, a 2 dp top line and label in `primary`; inactive labels and icons SHALL use `onSurfaceVariant` on a transparent tab background. Labels SHALL use system typography at 14/21 sp, weight 500, zero letter spacing. These roles SHALL resolve through the current light or dark theme.

#### Scenario: Switch theme
- **WHEN** the same strip is rendered in light and dark appearance
- **THEN** its geometry stays unchanged and its fills, divider, indicator and text resolve to the active theme roles
- **AND** the selected tab has no textual star marker, bottom accent underline, or surrounding accent border

### Requirement: Tab strip geometry and icons
Selection, closing and addition SHALL have separate, nonoverlapping targets at least 48 dp wide and high. Labels SHALL remain single-line without truncation; overflowing tabs SHALL scroll horizontally. Strip height SHALL grow for scaled text. Close and add SHALL be vector icons of 16 dp and 20 dp respectively. The strip SHALL stay within its allocated pane with addition pinned at the right outside scrolling.

#### Scenario: Scale text
- **WHEN** font scale is 1.25 or 2.0
- **THEN** labels are readable without vertical clipping, all targets retain their minimum size, and overflow remains horizontal

#### Scenario: Scroll overflowing tabs
- **WHEN** tabs exceed the available width and the user drags the strip
- **THEN** tabs move without selecting or closing, while the add action and page content remain stationary

### Requirement: Accessible tab actions
The strip SHALL expose a selectable group with labelled tab selection targets and selected state. Close buttons SHALL be described as `Close <label>` and addition as `Add tab`. Standard focus traversal and Enter/Space activation SHALL be available. Native ripple and focus indication SHALL identify the specific action without merging selection and closing into a single action.

#### Scenario: Activate with keyboard or accessibility
- **WHEN** a selection, close, or add target receives standard keyboard or accessibility activation
- **THEN** it performs the same single action as touch and assistive technology can distinguish selection from closing

### Requirement: Tab action request serialization
An available tab action SHALL submit exactly one request with its unchanged event array and null value. While any UI event request is in progress, select, close and add SHALL be disabled and SHALL NOT send or queue events. Cancelled gestures and scrolling SHALL NOT activate an action. Selection SHALL follow the next backend document rather than change optimistically.

#### Scenario: Close target is independent
- **WHEN** a completed tap lands on the close target
- **THEN** exactly the close event is sent, without also sending selection

#### Scenario: Disabled and cancelled actions
- **WHEN** an action is attempted during a request, or a gesture is cancelled or becomes a scroll
- **THEN** no event is sent or queued

## MODIFIED Requirements

### Requirement: Reject unsupported documents
The Android client SHALL treat missing required fields, invalid field types, a `column` or `row` whose `weights` is not an array of one non-negative finite number per child, and node types other than `column`, `row`, `text`, `button`, `input`, `image`, `voice_input`, `card`, or `tab_strip` as parse failures.

#### Scenario: Unsupported node type
- **WHEN** the document contains a node whose `@type` is not `column`, `row`, `text`, `button`, `input`, `image`, `voice_input`, `card`, or `tab_strip`
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
