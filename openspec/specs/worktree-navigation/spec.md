# worktree-navigation Specification

## Purpose

Определяет возврат из выбранного worktree к списку worktree через единое backend-событие.

## Requirements

### Requirement: Return from a selected worktree
The backend SHALL handle an event envelope whose `event.type` is `back` while a worktree is selected by returning the worktree-list document with the available worktrees reloaded.

#### Scenario: Back from selected worktree
- **WHEN** the selected-worktree document is active and the backend receives a `back` event
- **THEN** the response contains the reloaded worktree-list document

### Requirement: Do not render a worktree return button
The selected-worktree document SHALL NOT contain a backend-defined button that emits the `back` event.

#### Scenario: Selected worktree is rendered
- **WHEN** the backend returns a selected-worktree document
- **THEN** the document contains no button whose event type is `back`

### Requirement: Accept back at the worktree list
The backend SHALL accept a `back` event while the worktree-list document is active without adding an error to that document.

#### Scenario: Back from worktree list
- **WHEN** the worktree-list document is active and the backend receives a `back` event
- **THEN** the response remains a worktree-list document and does not add an error
