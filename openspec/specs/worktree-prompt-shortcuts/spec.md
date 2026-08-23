# worktree-prompt-shortcuts Specification

## Purpose

Позволяет быстро подставить типовой prompt в поле команды выбранного worktree перед его явной отправкой.

## Requirements

### Requirement: Advertise worktree prompt shortcuts
The selected-worktree document SHALL include interactive buttons labelled `/igor-pending-reviews` and `/igor-restart-mr-tests`.

#### Scenario: Selected worktree is displayed
- **WHEN** the backend returns a document for a selected worktree
- **THEN** the document contains buttons labelled `/igor-pending-reviews` and `/igor-restart-mr-tests`, each with an event object

### Requirement: Populate the command input from a shortcut
The system SHALL replace the `Command2` input text with the selected shortcut's label and return the updated selected-worktree document.

#### Scenario: Pending reviews shortcut is activated
- **WHEN** the user activates `/igor-pending-reviews`
- **THEN** the returned document renders `Command2` with text `/igor-pending-reviews`

#### Scenario: Restart MR tests shortcut is activated
- **WHEN** the user activates `/igor-restart-mr-tests`
- **THEN** the returned document renders `Command2` with text `/igor-restart-mr-tests`

### Requirement: Initialize an empty command input
The selected-worktree document SHALL render `Command2` with an explicit empty text value when the worktree is first opened.

#### Scenario: Worktree opens
- **WHEN** a worktree is selected
- **THEN** the returned document renders `Command2` with an empty text string

### Requirement: Keep shortcut selection separate from command execution
The system SHALL NOT execute Claude when a prompt shortcut is activated; it SHALL execute Claude only after receiving the `Command2` input submission event with a string value.

#### Scenario: Shortcut is activated
- **WHEN** the user activates either prompt shortcut
- **THEN** the response contains the updated command input and no Claude output or execution error caused by that activation
