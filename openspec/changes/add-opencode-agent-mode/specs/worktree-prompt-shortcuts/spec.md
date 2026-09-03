## MODIFIED Requirements

### Requirement: Advertise worktree prompt shortcuts
In Claude mode the selected-worktree document SHALL include interactive buttons labelled `/igor-pending-reviews` and `/igor-restart-mr-tests`. In OpenCode mode the selected-worktree document SHALL omit both Claude-specific shortcut buttons.

#### Scenario: Selected worktree is displayed
- **WHEN** the backend returns a selected-worktree document in Claude mode
- **THEN** the document contains buttons labelled `/igor-pending-reviews` and `/igor-restart-mr-tests`, each with an event object

#### Scenario: Selected worktree is displayed in OpenCode mode
- **WHEN** the backend returns a selected-worktree document in OpenCode mode
- **THEN** the document contains neither Claude-specific shortcut button
