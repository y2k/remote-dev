## REMOVED Requirements

### Requirement: Continue the selected worktree session
**Reason**: Selecting an agent opens its existing conversation instead of creating a new one and resuming it per prompt.
**Migration**: Send messages to the selected enrolled session through its public channel.

### Requirement: Scope continuation to the open screen
**Reason**: Conversation identity belongs to the external agent rather than the lifetime of a worktree screen.
**Migration**: Back or backend restart discards UI state without deleting, restarting, or resuming the external conversation.

### Requirement: Render only the current response
**Reason**: The accepted chat scope includes prior user and assistant text history.
**Migration**: Preserve the conversation and reconcile new text with saved history under `claude-agent-chat`.

### Requirement: Preserve a captured session after execution failure
**Reason**: The prompt subprocess and captured-resume state are retired.
**Migration**: Preserve the displayed conversation and input on disconnect, disable sending, and never automatically replay a message or resume an agent.

### Requirement: Enforce the agent session protocol
**Reason**: The application no longer consumes a per-prompt `--print` stream; external integration failure must not terminate the backend.
**Migration**: Validate public discovery/channel/hook input at its trust boundary and report unavailable or ambiguous connections without routing messages to another session.
