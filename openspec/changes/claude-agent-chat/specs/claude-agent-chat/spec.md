## Purpose

Позволяет с телефона находить активных Claude-агентов всех проектов и общаться с явно подключёнными сессиями через публичную интеграцию, сохраняя существующий разговор.

## ADDED Requirements

### Requirement: List active Claude agents across projects
In Claude mode the system SHALL list the entries returned by the locally installed `claude agents --json` without a directory filter or inclusion of completed sessions. Each entry SHALL display its available name or identifier, working directory, reported status, and chat availability. Interactive and background entries SHALL be eligible for display. Missing optional metadata SHALL NOT fabricate a status or imply an enrolled connection.

#### Scenario: Agents from multiple projects
- **WHEN** discovery returns active agents from different directories
- **THEN** the root screen lists all returned agents, regardless of the backend launch directory or legacy positional root

#### Scenario: No active agents
- **WHEN** discovery succeeds with an empty array
- **THEN** the screen shows an empty-agent state without an error or creation control

#### Scenario: Discovery fails
- **WHEN** the executable is unavailable, fails, or returns invalid required data
- **THEN** the UI reports the failure, preserves the last confirmed list if one exists, and remains available for refresh

### Requirement: Enable chat only for an enrolled session
The system SHALL enable chat only for an explicitly enrolled, currently connected Claude session identified unambiguously through public Channels and Hooks interfaces. Setup and Claude launch SHALL be performed on the computer. The application MUST NOT attach through private protocols, embed a terminal, spawn or resume Claude to satisfy selection, or match a connection by working directory alone.

#### Scenario: Enrolled agent is selected
- **WHEN** the user selects an active agent with a verified matching integration connection
- **THEN** the system opens that existing conversation without starting another Claude process

#### Scenario: Agent has no integration
- **WHEN** a discovered agent has no verified connection
- **THEN** its row indicates that it is not connected to the application and offers no chat action

#### Scenario: Connection identity changes
- **WHEN** a connection no longer unambiguously identifies the selected conversation
- **THEN** the system disables sending instead of routing input using the agent name or directory

### Requirement: Render existing text history and live replies
The selected chat SHALL display existing user messages and assistant text responses, including messages submitted from the computer terminal, and SHALL update with new assistant text before a long response finishes. Completed history and intermediate text SHALL converge without duplicating or losing logical messages. Detailed tool arguments and results SHALL NOT be included in the ordinary conversation feed. The conversation area SHALL scroll while the composer remains visible.

#### Scenario: Select an existing conversation
- **WHEN** an enrolled session with prior terminal conversation is selected
- **THEN** its available user and assistant text history is displayed in conversation order

#### Scenario: Live output becomes persisted history
- **WHEN** an assistant response is displayed incrementally and later becomes available in saved history
- **THEN** the final response appears once in its conversation position and prior messages remain visible

#### Scenario: Another prompt is submitted
- **WHEN** the user submits another message to the selected agent
- **THEN** the previous conversation remains displayed rather than being cleared for the new response

### Requirement: Send messages without interrupting the agent
The system SHALL send submitted text to the selected enrolled session through its public channel. Sending SHALL NOT wait for the agent to finish a turn before returning control to the user. A busy agent's message SHALL be presented as awaiting processing only when supported by observed delivery state. The application SHALL NOT provide a current-turn interrupt or substitute session termination for interruption. User text SHALL NOT be executed as a host shell command.

#### Scenario: Agent is busy
- **WHEN** text is successfully passed to the selected busy agent's channel
- **THEN** the UI indicates that it was passed to the channel and awaits processing, while navigation and further input remain usable without ending the agent's current turn

#### Scenario: Text contains shell syntax
- **WHEN** submitted text contains quotes, shell metacharacters, or a leading hyphen
- **THEN** it is transmitted as message content without interpretation as a host shell command or CLI option

### Requirement: Report uncertain delivery without automatic retry
The system SHALL distinguish observed channel handoff from confirmed processing and from unknown delivery. A successful notification write MUST NOT be presented as proof that Claude received or processed the message. The system SHALL retain text needed for a user-initiated retry and SHALL NOT automatically replay a message after a transport failure or reconnection.

#### Scenario: Failure after possible handoff
- **WHEN** a connection fails after a message might have been passed to the channel but processing cannot be confirmed
- **THEN** the UI reports unknown delivery, retains the text, and does not resend it automatically

#### Scenario: User explicitly retries
- **WHEN** the user chooses to resend retained text after reconnecting
- **THEN** the system treats that action as a new explicit submission without asserting that the earlier attempt was not processed

### Requirement: Answer permissions and questions remotely
For an enrolled session the system SHALL show pending tool permission requests and user questions, including available choices, and accept the user's corresponding decision through documented public interfaces. Every response MUST be bound to the selected session and the still-pending request. Project trust and MCP consent SHALL remain local. The system MUST NOT enable a permission bypass or treat ordinary channel text as permission consent.

#### Scenario: Tool permission request
- **WHEN** the connected session requests approval for a tool operation
- **THEN** the UI shows the operation requiring consent and offers explicit allow and deny actions for that request

#### Scenario: Question with choices
- **WHEN** the connected session asks a supported user question with choices
- **THEN** the UI presents the question and supported answers and delivers the selected answer to that question

#### Scenario: Request already answered locally
- **WHEN** a user attempts to answer a request that was resolved in the terminal
- **THEN** the stale action does not approve or answer a different request and the UI reconciles with the current pending state

### Requirement: Authenticate remote control and local enrollment
Only an authenticated application client SHALL be allowed to submit messages or permission/question responses. The backend SHALL accept connection identity and hook updates only from verified local integration participants and SHALL validate their session and request association. Integration credentials SHALL NOT be exposed in UI documents or error messages. Organization policy rejection SHALL NOT be bypassed.

#### Scenario: Unauthenticated control request
- **WHEN** an unauthenticated client attempts to submit a message or permission response
- **THEN** no message or decision reaches Claude

#### Scenario: Forged session association
- **WHEN** an unverified participant claims the identity of an enrolled session
- **THEN** the claim does not enable chat or redirect that session's messages or decisions

### Requirement: Preserve the chat on disconnection
When the selected integration disconnects or the agent exits, the UI SHALL retain displayed conversation and draft text, disable sending and unavailable decision actions, and show the known reason or an explicit unknown connection state. Recovery SHALL NOT start or resume an agent or replay messages.

#### Scenario: Selected agent disconnects
- **WHEN** the selected connection is lost while a conversation and draft are visible
- **THEN** those contents remain visible and sending is disabled with a connection indication

#### Scenario: Backend connection is lost
- **WHEN** the Android client cannot refresh or submit to the backend
- **THEN** it preserves its displayed chat and input and reports the transport failure without claiming successful submission

### Requirement: Navigate the agent list and remove worktree actions
Back from a selected Claude chat SHALL return to a reloaded active-agent list; Back at that list SHALL leave it active without error. Refresh SHALL reload the current list or selected chat data. No separate return button is required. Claude UI SHALL NOT offer worktree creation, worktree selection, agent launch, or agent resume. Retired worktree events MUST NOT create processes or alter directories.

#### Scenario: Return after completion
- **WHEN** the selected agent completes and the user goes Back
- **THEN** the refreshed list reflects active discovery and excludes that agent if it is no longer returned

#### Scenario: Old creation event is submitted
- **WHEN** a stale client submits an old worktree-creation event
- **THEN** no worktree is created and no Claude process is launched
