## Purpose

Определяет обязательный неизменяемый выбор локального coding-agent CLI при старте backend и видимое поведение выбранного режима.

## ADDED Requirements

### Requirement: Select the agent at startup
The backend SHALL require exactly one lowercase `--agent claude|opencode` startup option. The repository root SHALL remain an optional positional argument and SHALL default to the backend process current working directory when omitted.

#### Scenario: Start in Claude mode
- **WHEN** the backend starts with `--agent claude`
- **THEN** it uses Claude as its agent for the lifetime of that process

#### Scenario: Start in OpenCode mode with the default root
- **WHEN** the backend starts with `--agent opencode` and no repository path
- **THEN** it uses OpenCode as its agent and uses the current working directory as the repository root

#### Scenario: Start without a valid agent
- **WHEN** the backend starts without `--agent` or with a value other than `claude` or `opencode`
- **THEN** startup fails with command-line usage information before serving requests

### Requirement: Keep the startup agent immutable
The backend MUST NOT provide a UI event, HTTP operation, or other runtime mechanism that changes the selected agent. In OpenCode mode the backend MUST NOT launch Claude CLI, including in response to an event that was not advertised by the current UI document.

#### Scenario: Use the selected agent for multiple prompts
- **WHEN** multiple prompts are submitted during one backend process
- **THEN** every prompt is executed by the agent selected at startup

#### Scenario: Receive an unadvertised creation event in OpenCode mode
- **WHEN** the backend was started with `--agent opencode` and receives a manually constructed worktree-creation event
- **THEN** it does not launch Claude CLI

### Requirement: Display the selected agent
Every backend-defined UI document SHALL display a static `Agent: Claude` or `Agent: OpenCode` label matching the startup mode and SHALL NOT render a control for changing it.

#### Scenario: Render any application screen
- **WHEN** the backend returns a worktree list, worktree creation, or selected-worktree document
- **THEN** the document displays the selected agent and no agent-selection control

### Requirement: Defer CLI availability failures to execution
The backend SHALL NOT run an agent executable availability or version preflight during startup. Failure to start the selected executable for a prompt SHALL follow the ordinary prompt execution failure path without terminating the backend.

#### Scenario: Selected executable is unavailable
- **WHEN** the backend has started and the selected agent executable cannot be started for a submitted prompt
- **THEN** the current prompt stream reports an execution error and the backend remains available
