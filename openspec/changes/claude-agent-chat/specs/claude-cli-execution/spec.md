## REMOVED Requirements

### Requirement: Execute a prompt non-interactively
**Reason**: The application sends input to an existing enrolled agent rather than launching `claude --print`.
**Migration**: Use the public channel message contract in `claude-agent-chat`.

### Requirement: Use the requested working directory
**Reason**: The existing agent owns its working directory; the application does not start its prompt process.
**Migration**: Display discovery metadata and route messages by verified session identity.

### Requirement: Preserve prompt argument boundaries
**Reason**: Prompts are no longer subprocess arguments.
**Migration**: `claude-agent-chat` requires literal message delivery without shell or option interpretation.

### Requirement: Use the local Claude environment
**Reason**: The prompt-execution boundary is retired; enrollment and agent launch belong to the user.
**Migration**: Resolve discovery through local PATH and preserve the enrolled agent's permissions; never enable permission bypass.

### Requirement: Report process failure
**Reason**: There is no application-owned prompt process whose exit defines a chat result.
**Migration**: Report discovery errors and integration/delivery failures in the UI under `claude-agent-chat`.

### Requirement: Report and resume the Claude session
**Reason**: Session selection must not spawn or resume another Claude process.
**Migration**: Select a verified existing enrolled session; unavailable sessions remain unavailable until the user connects them on the computer.
