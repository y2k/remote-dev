## MODIFIED Requirements

### Requirement: Start new worktree creation
When the backend startup agent is Claude, the system SHALL provide an interactive `New` button in the worktree-list document that opens the worktree creation UI. When the startup agent is OpenCode, the system SHALL omit that button and SHALL NOT advertise worktree creation.

#### Scenario: User opens creation UI
- **WHEN** the backend runs in Claude mode and the user sends the advertised `New` button event from the worktree-list document
- **THEN** the system returns a document with a branch-name input

#### Scenario: Worktree list is rendered in OpenCode mode
- **WHEN** the backend returns the worktree-list document in OpenCode mode
- **THEN** the document contains no `New` button or other advertised worktree-creation action
