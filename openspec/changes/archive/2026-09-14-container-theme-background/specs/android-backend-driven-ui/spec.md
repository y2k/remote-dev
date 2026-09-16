## ADDED Requirements

### Requirement: Theme background for layout containers
The client SHALL accept an optional `background` string on `row` and `column` nodes. Its supported values SHALL be exactly `background`, `surface`, `surfaceContainer`, `primary`, and `primaryContainer`, case-sensitive. The client SHALL resolve the role from its current theme and paint the container's layout bounds behind its children, including inter-child spacing. An omitted field SHALL leave the container transparent. The field SHALL NOT change layout measurements, spacing, stretch, weight allocation, scrolling, or descendant foreground and control colors. Descendant containers without their own background SHALL remain transparent; an explicitly colored descendant SHALL paint its own background.

#### Scenario: Resolve each supported role
- **WHEN** a valid row or column specifies any of the five supported background roles
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
The backend UI composition API SHALL support selecting any of the five background roles independently for rows and columns. Serialization SHALL emit the selected role as the node's `background` string and SHALL omit the field when no background was selected. Mapping component events SHALL preserve selected backgrounds and existing layout attributes, including in nested containers.

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
