## MODIFIED Requirements

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
- **WHEN** a valid `row` contains two children and `weights` of `[2, 1]`
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

## ADDED Requirements

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
