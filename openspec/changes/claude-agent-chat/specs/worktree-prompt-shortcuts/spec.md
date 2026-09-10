## REMOVED Requirements

### Requirement: Advertise worktree prompt shortcuts
**Reason**: The selected-worktree command screen is replaced by enrolled-agent chat; channel text does not promise terminal slash-command execution.
**Migration**: Submit chat messages through the enrolled channel; run terminal-only commands on the computer.

### Requirement: Populate the command input from a shortcut
**Reason**: The old shortcut buttons and `Command2` input are retired with their screen.
**Migration**: Use the chat composer directly.

### Requirement: Initialize an empty command input
**Reason**: Worktree selection and its command input no longer exist.
**Migration**: Open the existing conversation and use its chat composer without starting a new session.

### Requirement: Keep shortcut selection separate from command execution
**Reason**: The application no longer starts a Claude command process from this screen.
**Migration**: Only explicit message submission sends channel text; UI selection does not launch Claude.
