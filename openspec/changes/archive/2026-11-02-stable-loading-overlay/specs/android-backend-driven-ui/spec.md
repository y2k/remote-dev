# Spec Delta

## ADDED Requirements

### Requirement: Loading indication preserves content geometry
While backend content is displayed, the Android client SHALL show an indeterminate linear loading indicator over its top edge during an event request. Showing or hiding this indicator SHALL NOT change the position or size allocated to the backend content. The indicator SHALL remain visible throughout streamed responses until the request finishes.

#### Scenario: Request starts and finishes
- **WHEN** an event request starts and then finishes with the same UI document
- **THEN** the indicator appears and disappears without moving or resizing the displayed content

#### Scenario: Streamed response
- **WHEN** an event request delivers multiple UI documents before closing
- **THEN** the indicator remains visible until the request ends without consuming content layout space

#### Scenario: Failed request
- **WHEN** an event request fails while existing content is displayed
- **THEN** the indicator disappears and the existing error presentation and retained content remain available
- **AND** removing the indicator itself does not change content geometry
