## MODIFIED Requirements

### Requirement: Supported UI nodes
The Android client SHALL recursively render a `column` node from its `children` array in vertical order, SHALL recursively render a `row` node from its `children` array in horizontal order, SHALL render a `text` node from its `text` string, SHALL render a `button` node from its `label` string, SHALL render an `input` node from its `label` and `event` object, and SHALL render an `image` node from its backend-relative `src` path and `label` string. A `row` node MAY include a `weights` array containing one positive number for each child; when present, the client SHALL fill the available row width and allocate that width among the children in proportion to their weights. When `weights` is absent, the client SHALL preserve the existing content-sized row layout. An image `src` path SHALL begin with `/` and SHALL NOT begin with `//`; the client SHALL resolve it against the configured backend origin. An input node MAY include a `text` string that provides the field's initial value. A button MAY include an `event` object. The client SHALL treat each `event` object as opaque backend-defined JSON.

#### Scenario: Render a column
- **WHEN** a valid `column` node contains supported child nodes
- **THEN** the client renders those children in vertical order

#### Scenario: Render a row
- **WHEN** a valid `row` node contains supported child nodes and omits `weights`
- **THEN** the client renders those children in horizontal order using their content-sized widths

#### Scenario: Render a weighted row
- **WHEN** a valid `row` node contains two children and `weights` of `[2, 1]`
- **THEN** the client fills the available row width and allocates two thirds to the first child and one third to the second child

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

### Requirement: Reject unsupported documents
The Android client SHALL treat missing required fields, invalid field types, a `row` whose `weights` is not an array of one positive number per child, and node types other than `column`, `row`, `text`, `button`, `input`, or `image` as parse failures.

#### Scenario: Unsupported node type
- **WHEN** the document contains a node whose `@type` is not `column`, `row`, `text`, `button`, `input`, or `image`
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid text content
- **WHEN** a `text` node is missing its required string field or the field has another type
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid row children
- **WHEN** a `row` node is missing its children array or contains a non-object child
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid row weights
- **WHEN** a `row` node has a `weights` value that is not an array, differs in length from `children`, or contains a non-number or non-positive number
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid input content
- **WHEN** an `input` node is missing its required string `label` or object `event` field, either field has another type, or its optional `text` field is present with a non-string type
- **THEN** the client displays an error instead of partially rendering the document

#### Scenario: Invalid image content
- **WHEN** an `image` node is missing its required string `src` or `label` field, either field has another type, or `src` is not a path beginning with `/` but not `//`
- **THEN** the client displays an error instead of partially rendering the document
