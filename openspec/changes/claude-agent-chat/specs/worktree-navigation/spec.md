## REMOVED Requirements

### Requirement: Return from a selected worktree
**Reason**: Claude selects active agents instead of worktrees.
**Migration**: Use Back from the selected agent chat to the refreshed active-agent list as specified by `claude-agent-chat`.

### Requirement: Do not render a worktree return button
**Reason**: The selected-worktree screen is retired.
**Migration**: Use system Back for selected conversations under `android-backend-driven-ui` and `claude-agent-chat`.

### Requirement: Accept back at the worktree list
**Reason**: The root screen is an agent list.
**Migration**: Back at the agent list remains a no-op under `claude-agent-chat`.
