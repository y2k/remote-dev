## ADDED Requirements

### Requirement: Report and resume the Claude session
Each Claude JSON stream SHALL report its session ID to the caller. A first prompt SHALL create a new session, and a later prompt for the same open worktree screen SHALL explicitly resume the captured session ID while retaining the existing working-directory, prompt-boundary, local-settings, and permission behavior.

#### Scenario: Claude starts a new conversation
- **WHEN** the caller supplies no session ID for a prompt
- **THEN** Claude starts a new session and the invocation reports its ID

#### Scenario: Claude continues a conversation
- **WHEN** the caller supplies the ID captured from an earlier prompt on the same open worktree screen
- **THEN** Claude resumes that exact session before processing the new prompt
