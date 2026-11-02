# Spec Delta

## ADDED Requirements

### Requirement: Optional vertical centering in rows
The client SHALL accept an optional boolean `centerVertically` on `row` nodes. When true, all children, including weighted children, SHALL align to the row's vertical center. Omitted or false SHALL preserve top alignment. Invalid values SHALL cause a parse failure. Width allocation, wrapping, and row height SHALL retain their existing behavior.

#### Scenario: Center mixed-height children
- **WHEN** a row sets `centerVertically` to true and contains text and a taller button
- **THEN** the text and button share a vertical center, including when weighted text wraps

#### Scenario: Preserve existing rows
- **WHEN** a row omits `centerVertically` or sets it to false
- **THEN** its children retain top alignment

#### Scenario: Reject invalid centering values
- **WHEN** `centerVertically` is present with a non-boolean value, including null
- **THEN** the document is rejected under the existing parse-failure behavior
