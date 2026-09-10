## MODIFIED Requirements

### Requirement: Select the agent at startup
The backend SHALL require exactly one lowercase `--agent claude|opencode` startup option. Claude mode SHALL discover active agents across projects. Its legacy optional positional repository root SHALL remain accepted, defaulting to the process working directory when omitted, but SHALL NOT filter agents or determine a selected conversation's directory. In OpenCode mode any positional repository root SHALL be rejected because the connected server supplies each session directory.

#### Scenario: Start in Claude mode
- **WHEN** the backend starts with `--agent claude`
- **THEN** it uses Claude for the lifetime of the process and loads the unfiltered active-agent list

#### Scenario: Start in Claude mode with an explicit root
- **WHEN** the backend starts with `--agent claude /path/to/repository`
- **THEN** startup accepts the legacy argument and lists agents across all projects

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
- **WHEN** the backend returns an agent-list, chat, OpenCode session, or emulator document
- **THEN** the document displays the selected agent and no agent-selection control

### Requirement: Defer CLI availability failures to execution
The backend SHALL NOT run an agent executable or OpenCode server availability/version preflight while parsing startup arguments. In Claude mode failure to execute agent discovery SHALL appear in the current UI without terminating the backend. In OpenCode mode failure to reach the server while loading or refreshing sessions SHALL be displayed in the current UI document without terminating the backend.

#### Scenario: Selected executable is unavailable
- **WHEN** Claude mode has started and `claude agents --json` cannot be executed
- **THEN** the agent-list UI reports the error and the backend remains available

#### Scenario: OpenCode server is unavailable
- **WHEN** OpenCode mode has started and a session load cannot connect to `127.0.0.1:4096`
- **THEN** the current UI document reports the connection error and the backend remains available
