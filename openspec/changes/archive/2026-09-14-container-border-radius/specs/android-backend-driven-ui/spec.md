## ADDED Requirements

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
