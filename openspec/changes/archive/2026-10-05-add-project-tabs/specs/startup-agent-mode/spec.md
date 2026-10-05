## MODIFIED Requirements

### Requirement: Defer CLI availability failures to execution
The backend SHALL NOT run an agent executable or OpenCode server availability/version preflight while parsing startup arguments. The startup directory-list screen and OpenCode tab UI SHALL NOT contact an agent service or invoke an agent executable. In Claude mode failure to start the CLI for a prompt SHALL follow the ordinary prompt execution failure path. In OpenCode mode failure to reach the server while loading or refreshing an OpenCode session list or selected session SHALL be displayed in that screen without terminating the backend.

#### Scenario: Selected executable is unavailable
- **WHEN** Claude mode has started and the `claude` executable cannot be started for a submitted prompt
- **THEN** the current prompt stream reports an execution error and the backend remains available

#### Scenario: OpenCode server is unavailable
- **WHEN** an active OpenCode session-list or selected-session screen cannot connect to `127.0.0.1:4096` during loading or refresh
- **THEN** that UI document reports the connection error and the backend remains available

#### Scenario: Startup without an OpenCode server
- **WHEN** OpenCode mode starts while `127.0.0.1:4096` is unavailable
- **THEN** the empty tab UI loads without contacting that server or displaying an OpenCode connection error
- **AND** creating a tab loads its project list independently of that server
