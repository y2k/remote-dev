## MODIFIED Requirements

### Requirement: Return from a selected worktree
The backend SHALL handle an event envelope whose `event.type` is `back` while a worktree is selected by returning the worktree-list document represented by the list screen that was active immediately before that worktree was selected. The backend SHALL NOT reload the available worktrees for this return.

#### Scenario: Back from selected worktree
- **WHEN** the selected-worktree document is active and the backend receives a `back` event
- **THEN** the response contains the previously active worktree-list document without reloading available worktrees
