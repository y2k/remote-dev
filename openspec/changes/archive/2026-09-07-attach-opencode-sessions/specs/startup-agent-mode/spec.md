## MODIFIED Requirements

### Requirement: Select the agent at startup
The backend SHALL require exactly one lowercase `--agent claude|opencode` startup option. In Claude mode the repository root SHALL remain an optional positional argument and SHALL default to the backend process current working directory when omitted. In OpenCode mode any positional repository root SHALL be rejected because the connected server supplies each session directory.

#### Scenario: Start in Claude mode
- **WHEN** the backend starts with `--agent claude`
- **THEN** it uses Claude as its agent for the lifetime of that process and uses the current working directory as the repository root

#### Scenario: Start in Claude mode with an explicit root
- **WHEN** the backend starts with `--agent claude /path/to/repository`
- **THEN** it uses the supplied repository root

#### Scenario: Start in OpenCode mode with the default root
- **WHEN** the backend starts with `--agent opencode` and no repository path
- **THEN** it uses the local OpenCode server for the lifetime of that process

#### Scenario: Start OpenCode mode with a root
- **WHEN** the backend starts with `--agent opencode /path/to/repository`
- **THEN** startup fails with command-line usage information

#### Scenario: Start without a valid agent
- **WHEN** the backend starts without `--agent` or with a value other than `claude` or `opencode`
- **THEN** startup fails with command-line usage information before serving requests

### Requirement: Display the selected agent
Every backend-defined UI document SHALL display a static `Agent: Claude` or `Agent: OpenCode` label matching the startup mode and SHALL NOT render a control for changing it.

#### Scenario: Render any application screen
- **WHEN** the backend returns a worktree, worktree-creation, session-list, selected-session, or emulator document
- **THEN** the document displays the selected agent and no agent-selection control

### Requirement: Defer CLI availability failures to execution
The backend SHALL NOT run an agent executable or OpenCode server availability/version preflight while parsing startup arguments. In Claude mode failure to start the CLI for a prompt SHALL follow the ordinary prompt execution failure path. In OpenCode mode failure to reach the server while loading or refreshing sessions SHALL be displayed in the current UI document without terminating the backend.

#### Scenario: Selected executable is unavailable
- **WHEN** Claude mode has started and the `claude` executable cannot be started for a submitted prompt
- **THEN** the current prompt stream reports an execution error and the backend remains available

#### Scenario: OpenCode server is unavailable
- **WHEN** OpenCode mode has started and a session load cannot connect to `127.0.0.1:4096`
- **THEN** the current UI document reports the connection error and the backend remains available
