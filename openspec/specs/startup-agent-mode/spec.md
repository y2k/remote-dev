# startup-agent-mode Specification

## Purpose

Определяет обязательный неизменяемый выбор coding-agent provider при старте backend и видимое поведение выбранного режима.

## Requirements

### Requirement: Select the agent at startup
The backend SHALL require exactly one lowercase `--agent claude|opencode` startup option. Both modes SHALL accept at most one optional positional directory path, defaulting to the backend process working directory at startup. This path SHALL select the startup directory-list root. In Claude mode it SHALL also serve as the repository root. In OpenCode mode it SHALL NOT override session directories or restrict the all-server session list; the connected server SHALL continue supplying each session directory. Multiple positional paths SHALL be rejected with command-line usage information.

#### Scenario: Start in Claude mode
- **WHEN** the backend starts with `--agent claude`
- **THEN** it uses Claude as its agent for the lifetime of that process and uses the current working directory as the repository root and directory-list root

#### Scenario: Start in Claude mode with an explicit root
- **WHEN** the backend starts with `--agent claude /path/to/repository`
- **THEN** it uses the supplied path as the repository root and directory-list root

#### Scenario: Start in OpenCode mode with the default root
- **WHEN** the backend starts with `--agent opencode` and no directory path
- **THEN** it uses the local OpenCode server for the lifetime of that process and uses the startup working directory as the directory-list root

#### Scenario: Start OpenCode mode with a root
- **WHEN** the backend starts with `--agent opencode /path/to/projects`
- **THEN** startup accepts the path and uses it as the directory-list root
- **AND** OpenCode session directories and all-server session-list scope remain server-defined

#### Scenario: Start without a valid agent
- **WHEN** the backend starts without `--agent` or with a value other than `claude` or `opencode`
- **THEN** startup fails with command-line usage information before serving requests

#### Scenario: Duplicate agent option
- **WHEN** the backend is given more than one `--agent` option
- **THEN** startup fails with command-line usage information before serving requests

#### Scenario: Multiple positional paths
- **WHEN** the backend starts in either supported mode with two positional paths
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
- **WHEN** the backend returns a directory-list, worktree, worktree-creation, session-list, selected-session, or emulator document
- **THEN** the document displays the selected agent and no agent-selection control

### Requirement: Defer CLI availability failures to execution
The backend SHALL NOT run an agent executable or OpenCode server availability/version preflight while parsing startup arguments. The startup directory-list screen SHALL NOT contact an agent service or invoke an agent executable. In Claude mode failure to start the CLI for a prompt SHALL follow the ordinary prompt execution failure path. In OpenCode mode failure to reach the server while loading or refreshing an OpenCode session list or selected session SHALL be displayed in that screen without terminating the backend.

#### Scenario: Selected executable is unavailable
- **WHEN** Claude mode has started and the `claude` executable cannot be started for a submitted prompt
- **THEN** the current prompt stream reports an execution error and the backend remains available

#### Scenario: OpenCode server is unavailable
- **WHEN** an active OpenCode session-list or selected-session screen cannot connect to `127.0.0.1:4096` during loading or refresh
- **THEN** that UI document reports the connection error and the backend remains available

#### Scenario: Startup without an OpenCode server
- **WHEN** OpenCode mode starts with a readable directory root while `127.0.0.1:4096` is unavailable
- **THEN** the directory screen loads without contacting that server or displaying an OpenCode connection error
