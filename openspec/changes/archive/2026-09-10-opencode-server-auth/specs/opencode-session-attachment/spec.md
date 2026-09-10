## ADDED Requirements

### Requirement: Authenticate requests to the local OpenCode server
In OpenCode mode, the backend SHALL send HTTP Basic authentication on every request to `127.0.0.1:4096` when its own process environment contains a non-empty `OPENCODE_SERVER_PASSWORD`. The credentials SHALL use that password verbatim and the constant username `opencode`, regardless of any username environment variable. The backend SHALL omit the Authorization header when the password is unset or empty. The backend SHALL NOT expose credentials or the generated Authorization header in its UI documents or logs.

#### Scenario: Password with constant username
- **WHEN** the backend has a non-empty `OPENCODE_SERVER_PASSWORD`
- **THEN** every OpenCode request includes `Authorization: Basic <credentials>` using standard padded Base64 of `opencode:<password>` without line wrapping

#### Scenario: Username environment is ignored
- **WHEN** the backend has a non-empty password and a username environment variable is set
- **THEN** every OpenCode request still uses `opencode` as the username

#### Scenario: Coverage of reads and writes
- **WHEN** the backend lists sessions, loads session details or status, checks pending input, submits a prompt or command, or aborts a session with a configured password
- **THEN** each request includes the configured Basic authentication credentials

#### Scenario: Password is unavailable to the backend
- **WHEN** `OPENCODE_SERVER_PASSWORD` is unset or empty in the backend environment, regardless of the server environment
- **THEN** the backend sends no Authorization header

#### Scenario: Credentials are rejected
- **WHEN** the OpenCode server returns HTTP 401
- **THEN** the existing error-reporting path displays the failure and the backend remains available
- **AND** the backend does not include its credentials or generated Authorization header in UI documents or logs
