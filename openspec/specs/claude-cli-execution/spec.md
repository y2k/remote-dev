# claude-cli-execution Specification

## Purpose

Provide a synchronous boundary for sending one prompt to the locally installed Claude CLI in a selected working directory and receiving its textual response.

## Requirements

### Requirement: Execute a prompt non-interactively
The system SHALL execute the locally available Claude CLI non-interactively with the supplied prompt and SHALL return the complete standard output without modification after successful process completion.

#### Scenario: Claude CLI succeeds
- **WHEN** the Claude CLI exits successfully after receiving a prompt
- **THEN** the system returns the CLI standard output as text

### Requirement: Use the requested working directory
The system SHALL start the Claude CLI with the supplied directory as its process working directory.

#### Scenario: Working directory is valid
- **WHEN** the caller supplies an accessible directory
- **THEN** the Claude CLI process starts with that directory as its current working directory

#### Scenario: Working directory is unavailable
- **WHEN** the supplied directory does not exist or cannot be entered
- **THEN** the invocation reports failure to its caller without running Claude CLI

### Requirement: Preserve prompt argument boundaries
The system MUST pass the supplied prompt as a process argument without shell interpretation.

#### Scenario: Prompt contains shell syntax
- **WHEN** a prompt contains whitespace, quotes, or shell metacharacters
- **THEN** the system passes the complete value to the Claude CLI without executing any part of it as a shell command

#### Scenario: Prompt starts with a hyphen
- **WHEN** a prompt starts with `-`
- **THEN** the system passes it as the prompt rather than interpreting it as a CLI option

### Requirement: Use the local Claude environment
The system SHALL resolve `claude` through the server process `PATH` and SHALL use the CLI's normal local settings and permissions without enabling a dangerous permission bypass.

#### Scenario: Configured Claude CLI is available
- **WHEN** `claude` is available through the inherited `PATH`
- **THEN** the system runs it with its normal configured capabilities and built-in restrictions

### Requirement: Report process failure
The system SHALL raise a general exception instead of returning a result when the Claude CLI cannot be started or does not exit successfully.

#### Scenario: Claude CLI exits unsuccessfully
- **WHEN** the Claude CLI exits with a non-zero status or is terminated by a signal
- **THEN** the invocation reports failure to its caller

#### Scenario: Claude CLI is unavailable
- **WHEN** the Claude CLI executable cannot be started
- **THEN** the invocation reports failure to its caller
