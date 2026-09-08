# worktree-chat-layout Specification

## Purpose

Keeps the selected worktree's streamed response usable without allowing growing output to displace its command controls from the visible screen.

## Requirements

### Requirement: Keep worktree command controls visible
In Claude mode the selected-worktree document SHALL place its response area in the positive-weight region of a full-height weighted column and SHALL assign content-sized zero weights to its heading, path, prompt shortcuts, and command input so those controls remain visible while the response grows.

#### Scenario: Response fits in the available area
- **WHEN** the selected Claude worktree displays a response shorter than its positive-weight region
- **THEN** the response occupies that region and the command input and prompt shortcuts remain visible

#### Scenario: Response exceeds the available area
- **WHEN** the selected Claude worktree displays a response taller than its positive-weight region
- **THEN** the response area scrolls vertically without moving the command input or prompt shortcuts out of view

#### Scenario: OpenCode mode omits prompt shortcuts
- **WHEN** the backend runs in OpenCode mode
- **THEN** it renders session screens instead of the selected-worktree layout and reserves no height for Claude prompt shortcuts
