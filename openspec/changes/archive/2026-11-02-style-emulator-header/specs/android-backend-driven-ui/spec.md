# Spec Delta

## ADDED Requirements

### Requirement: Optional button presentation
A `button` SHALL accept optional `style` values `compact` and `icon`. An omitted style SHALL retain ordinary button behavior. `compact` MAY include a boolean `selected`; its presence SHALL expose selection semantics. `icon` SHALL require `icon: "refresh"` and use the required label as its accessible description without visible text. Events SHALL remain opaque and optional as for existing buttons.

#### Scenario: Reuse on another screen
- **WHEN** compact and icon buttons occur in any supported container with arbitrary backend events
- **THEN** their presentation and event submission follow those properties without interpreting emulator identities or actions

#### Scenario: Reject invalid presentation
- **WHEN** style, selected or icon is null or wrongly typed, style/icon is unknown, selected appears outside compact style, icon appears outside icon style, or icon style omits icon
- **THEN** the entire document fails parsing without coercion or partial rendering

### Requirement: Backend button presentation mapping
The backend SHALL support compact/icon button properties and SHALL preserve them when mapping events in nested containers. Omitted properties SHALL remain omitted, retaining the existing ordinary button wire format. The emulator header SHALL be composed exclusively from existing row, column and button nodes; the client SHALL reject `emulator_header` as unsupported.

#### Scenario: Map nested buttons
- **WHEN** buttons with presentation properties are mapped into root application messages
- **THEN** events receive the wrapper while label, style, icon and selected retain their values and omission states

### Requirement: Compact and icon button presentation
Compact buttons SHALL have 8 dp corners, a 1 dp outlineVariant border, padding 8/4 dp, and targets at least 48 dp. Single-line labels SHALL use system 12/18 sp with zero letter spacing and natural width. Selected buttons SHALL use surfaceContainerHigh/onSurface/500; others surfaceContainer/onSurfaceVariant/400. Icon buttons SHALL have a 48 dp target, 18 dp refresh vector, transparent background, onSurfaceVariant tint and 8 dp clipping.

#### Scenario: Standalone compact and icon buttons
- **WHEN** these buttons are rendered outside an emulator panel
- **THEN** their styling follows the same rules, grows for scaled text and uses the current theme

### Requirement: Generic button selection semantics
A row with immediate compact button children that specify selected SHALL expose a selectable group. Each such button SHALL report its own selected state without changing it optimistically. All styled buttons SHALL support native focus/ripple, keyboard and accessibility activation, one unchanged event with null value, and existing busy/cancel/drag guards.

#### Scenario: No selection
- **WHEN** a row contains compact buttons all specifying selected false
- **THEN** none is selected and activating one waits for a backend document to update selection

### Requirement: Emulator header theme and typography
The header SHALL use `surfaceContainerLow` with a 1 dp `outlineVariant` bottom divider. Device controls SHALL have 8 dp corners and 1 dp `outlineVariant` borders. Selected devices SHALL use `surfaceContainerHigh`, `onSurface`, and weight 500; others SHALL use `surfaceContainer`, `onSurfaceVariant`, and weight 400. Labels SHALL use system typography at 12/18 sp with zero letter spacing. All colors SHALL resolve through the current theme.

#### Scenario: Theme changes
- **WHEN** the same header is rendered in light and dark appearance
- **THEN** fills, borders, divider, and text resolve through that theme without changing geometry

### Requirement: Emulator header layout and overflow
The header SHALL fill its pane allocation with horizontal padding 12 dp and vertical padding 4 dp. Devices SHALL have horizontal padding 8 dp and a 4 dp gap. An 8 dp gap SHALL separate their scrolling group from a pinned refresh button. All actions SHALL have nonoverlapping targets at least 48 dp in each dimension. Labels SHALL remain single-line, horizontally scrollable without truncation, with height growing for scaled text.

#### Scenario: Many devices or long names
- **WHEN** device controls exceed the available width
- **THEN** horizontal scrolling reveals them without moving Refresh or preview and without sending an event

#### Scenario: Scaled text
- **WHEN** font scale is 1.25 or 2.0
- **THEN** labels have no vertical clipping, targets remain at least 48 dp, and controls stay within the pane

#### Scenario: Unchanged document selection
- **WHEN** the user manually scrolls the device group and a document replacement retains device identities and selection
- **THEN** the scroll position is retained rather than reset

### Requirement: Accessible emulator header actions
Devices SHALL expose their labels and selected state as a selectable group. Refresh SHALL be an 18 dp rotate-right vector icon with description `Обновить список эмуляторов`, `onSurfaceVariant` tint, transparent resting background, and 8 dp corner clipping. Actions SHALL support standard focus traversal, Enter/Space activation, and native ripple and focus indication.

#### Scenario: Keyboard and accessibility activation
- **WHEN** a device or Refresh is activated using the keyboard or accessibility
- **THEN** it sends the same single event as touch and device selection is identifiable

### Requirement: Emulator header event serialization
An available header action SHALL submit exactly one request containing its unchanged event array and null value. While a UI event request is in progress, all header actions SHALL be disabled without queueing. Cancelled gestures and scrolling SHALL NOT activate actions. Selection SHALL follow the backend document rather than change optimistically.

#### Scenario: Select and wait
- **WHEN** a user activates an unselected device
- **THEN** exactly its selection event is submitted and displayed selection changes only with a returned backend document

#### Scenario: Busy or cancelled actions
- **WHEN** a gesture is cancelled, becomes a scroll, or an action is attempted while a request is in progress
- **THEN** no event is sent or queued

## MODIFIED Requirements

### Requirement: Theme background for layout containers
The client SHALL accept an optional `background` string on `row` and `column` nodes. Its supported values SHALL be exactly `background`, `surface`, `surfaceContainer`, `surfaceContainerLow`, `primary`, `primaryContainer`, and `outlineVariant`, case-sensitive. The client SHALL resolve the role from its current theme and paint the container's layout bounds behind its children, including inter-child spacing. An omitted field SHALL leave the container transparent. The field SHALL NOT change layout measurements, spacing, stretch, weight allocation, scrolling, or descendant foreground and control colors. Descendant containers without their own background SHALL remain transparent; an explicitly colored descendant SHALL paint its own background.

#### Scenario: Resolve each supported role
- **WHEN** a valid row or column specifies any of the seven supported background roles
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

### Requirement: Backend container background serialization
The backend UI composition API SHALL support selecting any of the seven background roles independently for rows and columns. Serialization SHALL emit the selected role as the node's `background` string and SHALL omit the field when no background was selected. Mapping component events SHALL preserve selected backgrounds and existing layout attributes, including in nested containers.

#### Scenario: Serialize selected backgrounds
- **WHEN** the backend serializes a row or column with a selected background role
- **THEN** the node contains the corresponding supported `background` string

#### Scenario: Preserve existing wire documents
- **WHEN** the backend serializes containers without a selected background
- **THEN** their JSON has no background field and retains the existing representation

#### Scenario: Map events in colored containers
- **WHEN** the backend maps events in nested colored rows and columns before serialization
- **THEN** their background roles and layout attributes are preserved while events are mapped normally

### Requirement: Theme-colored gap painting
A gap color SHALL accept exactly the case-sensitive roles `background`, `surface`, `surfaceContainer`, `surfaceContainerLow`, `primary`, `primaryContainer`, and `outlineVariant`, resolved through the active client theme. An omitted color SHALL leave the gap transparent. A colored gap SHALL paint the actual inter-child region across the full inner cross-axis extent, above the container background but behind the children. It SHALL NOT paint padding, outer edges, unused trailing space, or child layout areas. Changing only the gap color SHALL NOT change layout or descendant colors. Nested containers SHALL paint only their own gaps.

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

### Requirement: Uniform themed container border
The client SHALL accept an optional `border` object on `row` and `column` nodes with required `width` and `color` fields. Width SHALL be whole non-negative dp. Color SHALL accept exactly the case-sensitive theme roles `background`, `surface`, `surfaceContainer`, `surfaceContainerLow`, `primary`, `primaryContainer`, and `outlineVariant`, resolved through the active theme. A positive width SHALL paint a solid uniform border around the entire perimeter inside the container's outer layout bounds, above its background and children. An omitted border or width zero SHALL paint no line, including no hairline. Border SHALL NOT add padding or change measurements, child positions, gap geometry, stretch, weights, or scrolling allocation. Existing padding SHALL determine the inset of children independently of border width.

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

### Requirement: Full-height themed emulator panel
On every screen containing the shared Emulators panel, the backend SHALL select `surface` for the panel's background and compose the panel to occupy its full allocated width and the full available content height. The fill SHALL include unused space below the panel's content, including when no emulator is selected, none are running, or an emulator error is displayed. In both appearances the fill SHALL resolve through the current theme's `surface`. The panel SHALL preserve the existing 2:1 content-to-emulator width ratio, preview aspect ratio, image tap behavior, and descendant colors outside the styled header. The header SHALL arrange devices in loaded order with Refresh pinned on the right. The fill SHALL NOT alter screenshot pixels or extend into the application header or outer content margins.

#### Scenario: Short or empty emulator content
- **WHEN** the panel shows a short preview, a selection prompt, no running emulators, or an emulator error
- **THEN** its surface background spans the entire right-hand allocation to the bottom of the available content area, including unused space below the content

#### Scenario: Panel follows the theme
- **WHEN** a screen with the Emulators panel is rendered in dark or light appearance
- **THEN** the panel background uses the active theme's surface color, with the header using its specified theme roles

#### Scenario: Preserve panel boundaries and interactions
- **WHEN** the themed panel displays an emulator preview and controls
- **THEN** the two panels retain their 2:1 width ratio and the header shows devices in loaded order with Refresh on the right and unchanged actions
- **AND** the screenshot pixels, aspect ratio, and tap mapping remain unchanged
- **AND** the application header, outer margins, and descendant colors outside the styled header retain their existing appearance

### Requirement: Readable shortcut button group
The Claude worktree shortcut buttons SHALL be arranged vertically with each button occupying its group's available width. Button order, labels, and events SHALL be preserved. At a 400 dp viewport width, this group SHALL NOT compress later buttons into narrow vertical strips, and the Commands input and voice control SHALL remain visible. The root content-to-emulator width ratio SHALL remain 2:1. Emulator controls SHALL use the styled horizontal header with scrolling device selection and Refresh pinned on the right.

#### Scenario: Narrow worktree screen
- **WHEN** a worktree screen is rendered in a 400 dp wide viewport
- **THEN** its two shortcuts appear one below the other across the left pane width
- **AND** the Commands input and microphone remain visible below them

#### Scenario: Emulator controls at any width
- **WHEN** the emulator panel is rendered with available devices
- **THEN** devices appear in loaded order in a horizontally scrollable group with Refresh pinned on the right
- **AND** selection and refresh use their unchanged backend events
