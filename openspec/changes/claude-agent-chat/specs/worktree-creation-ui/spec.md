## REMOVED Requirements

### Requirement: Start new worktree creation
**Reason**: Worktree creation is removed from the Claude UI.
**Migration**: Prepare directories and launch agents on the computer; the application lists existing agents.

### Requirement: Accept a new branch name
**Reason**: The application no longer launches Claude to create worktrees.
**Migration**: Perform any worktree creation outside the application; existing directories remain intact.

### Requirement: Return from creation UI
**Reason**: The creation screen is retired.
**Migration**: Navigate only between the active-agent list and an enrolled agent chat.
