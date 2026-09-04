## Purpose

Keeps consecutive prompts on an open worktree screen in one explicit Claude or OpenCode conversation without persisting backend session state.

## ADDED Requirements

### Requirement: Continue the selected worktree session
The first prompt after opening a worktree SHALL create a new session with the startup-selected agent. Each later prompt submitted while that screen remains open SHALL explicitly resume the same session ID with the same agent and worktree path.

#### Scenario: Submit the first prompt
- **WHEN** a worktree screen has no captured session ID and the user submits a prompt
- **THEN** the system starts a new selected-agent session and captures the session ID reported by that run

#### Scenario: Submit a later prompt
- **WHEN** the open worktree screen has a captured session ID and the user submits another prompt
- **THEN** the system passes that exact ID to the selected CLI resume option

### Requirement: Scope continuation to the open screen
The backend SHALL retain the captured session ID only in the current selected-worktree state. Returning to the worktree list or restarting the backend SHALL discard that ID without deleting the CLI-owned session from local storage.

#### Scenario: Return and reopen a worktree
- **WHEN** the user returns to the list and selects the same worktree again
- **THEN** the next prompt starts a new session instead of resuming the previously captured ID

#### Scenario: Restart the backend
- **WHEN** the backend restarts after a session was captured
- **THEN** it does not recover or resume that session automatically

### Requirement: Render only the current response
Starting a prompt SHALL clear the previously rendered output while retaining the session ID, and the UI SHALL display only text produced for the current prompt rather than a conversation transcript.

#### Scenario: Continue after an earlier response
- **WHEN** the user submits a second prompt in the same session
- **THEN** the previous output is removed and the new response is rendered as it arrives

### Requirement: Preserve a captured session after execution failure
If a run reports a valid session ID before ending unsuccessfully, the backend SHALL retain that ID. If explicit resume later fails because the session is unavailable, the backend SHALL retain the ID until the user leaves the worktree screen and SHALL NOT automatically retry the prompt in a new session.

#### Scenario: First run fails after identifying its session
- **WHEN** the first run reports a session ID and later exits unsuccessfully
- **THEN** a subsequent prompt explicitly resumes the reported session

#### Scenario: Stored session is unavailable
- **WHEN** the selected CLI rejects the stored session ID
- **THEN** the UI reports the execution failure and no replacement session is started automatically

### Requirement: Enforce the agent session protocol
Every valid CLI JSON stream SHALL identify exactly one session. Malformed JSON, a successful run without a session ID, a different ID while resuming, or conflicting IDs within one run MUST terminate the backend as a fatal protocol violation. Correctly formed unknown JSON event types SHALL be ignored.

#### Scenario: Successful run omits its session ID
- **WHEN** the selected CLI exits successfully without reporting a session ID
- **THEN** the backend process terminates

#### Scenario: Resumed run reports another session
- **WHEN** a run started with an explicit session ID reports a different ID
- **THEN** the backend process terminates

#### Scenario: CLI emits malformed JSON
- **WHEN** a CLI stdout line is not valid JSON
- **THEN** the backend process terminates

#### Scenario: CLI emits an unknown event
- **WHEN** a CLI stdout line is valid JSON with an unrecognized event type and the run otherwise satisfies the session protocol
- **THEN** the system ignores that event and continues the run
