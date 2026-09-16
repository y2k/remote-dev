## ADDED Requirements

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

## MODIFIED Requirements

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
