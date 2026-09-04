## Purpose

Defines the non-interactive OpenCode process contract for prompts and slash commands executed inside a selected Git worktree.

## ADDED Requirements

### Requirement: Execute an OpenCode prompt non-interactively
The system SHALL start a separate local `opencode run` process for each submitted prompt, SHALL use the selected worktree as its directory, and SHALL request JSON output. It SHALL deliver each completed textual part in emission order and SHALL use the normal locally configured OpenCode model and agent.

#### Scenario: OpenCode produces completed text
- **WHEN** OpenCode emits one or more valid JSON `text` events for a submitted prompt
- **THEN** the system delivers each completed text part in order through the existing NDJSON UI-document stream

#### Scenario: OpenCode emits no partial text events
- **WHEN** OpenCode produces only one completed textual part at the end of a run
- **THEN** the client receives that complete response without requiring token-level updates

### Requirement: Preserve the OpenCode input boundary
The system MUST pass the worktree path, prompt, command name, and command arguments as process arguments without shell interpretation.

#### Scenario: Prompt contains shell syntax
- **WHEN** an ordinary prompt contains whitespace, quotes, shell metacharacters, or starts with a hyphen
- **THEN** OpenCode receives the complete value as prompt text without executing any part through a shell

### Requirement: Execute OpenCode slash commands
When the submitted value after trimming starts with `/` followed by a non-whitespace command name, the system SHALL execute that name through OpenCode command mode and SHALL pass the remaining trimmed text as command arguments. A lone `/` SHALL remain an ordinary prompt. The system SHALL NOT retry a failed command as a prompt.

#### Scenario: Submit a slash command
- **WHEN** the user submits ` /review main ` in OpenCode mode
- **THEN** the system executes the OpenCode command `review` with `main` as its arguments

#### Scenario: Submit a lone slash
- **WHEN** the user submits `/`
- **THEN** the system sends `/` as an ordinary OpenCode prompt

#### Scenario: Submit an unknown command
- **WHEN** OpenCode reports that the submitted slash command is unknown
- **THEN** the system reports that execution failure without running a second prompt process

### Requirement: Auto-approve OpenCode permission requests
Every OpenCode invocation SHALL enable CLI auto approval so that each effective permission request in the `ask` state is approved once. Effective explicit deny rules SHALL remain in force, and the system SHALL NOT override the local OpenCode model, agent, or permission configuration.

#### Scenario: OpenCode requests permission
- **WHEN** an OpenCode run emits a permission request not rejected by an effective deny rule
- **THEN** the CLI approves that request once without waiting for interaction from the Android client

### Requirement: Report OpenCode process failure
Failure to start OpenCode or an unsuccessful OpenCode process exit SHALL report an ordinary prompt execution failure without terminating the backend.

#### Scenario: OpenCode exits unsuccessfully
- **WHEN** OpenCode exits with a non-zero status or is terminated by a signal after emitting valid protocol data
- **THEN** the prompt stream exposes an error and the backend remains available
