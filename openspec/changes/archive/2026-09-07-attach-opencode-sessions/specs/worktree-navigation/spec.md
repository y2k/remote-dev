## MODIFIED Requirements

### Requirement: Return from a selected worktree
In Claude mode the backend SHALL handle the Back event while a worktree is selected by returning the worktree-list document with the available worktrees reloaded.

#### Scenario: Back from selected worktree
- **WHEN** the selected-worktree document is active in Claude mode and the backend receives Back
- **THEN** the response contains the reloaded worktree-list document

### Requirement: Do not render a worktree return button
In Claude mode the selected-worktree document SHALL NOT contain a backend-defined button that emits the Back event.

#### Scenario: Selected worktree is rendered
- **WHEN** the backend returns a selected-worktree document in Claude mode
- **THEN** the document contains no button that emits Back

### Requirement: Accept back at the worktree list
In Claude mode the backend SHALL accept Back while the worktree-list document is active without adding an error to that document.

#### Scenario: Back from worktree list
- **WHEN** the worktree-list document is active in Claude mode and the backend receives Back
- **THEN** the response remains a worktree-list document and does not add an error
