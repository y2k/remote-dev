## MODIFIED Requirements

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
