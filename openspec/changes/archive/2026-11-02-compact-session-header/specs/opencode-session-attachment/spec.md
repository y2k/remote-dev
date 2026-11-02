# Spec Delta

## MODIFIED Requirements

### Requirement: Render the selected session transcript
Selecting a session SHALL load its V2 messages by server-supplied session ID and display title, status, and all user and assistant text in conversation order across all pages, with the full directory available through session details. User `text` and assistant textual `content` SHALL be rendered; other message types and non-text content SHALL NOT be rendered. A missing title SHALL display as `Без названия` without renaming the OpenCode session.

#### Scenario: Session has a conversation
- **WHEN** the selected session contains user and assistant text
- **THEN** the screen displays all such text under its role in conversation order

#### Scenario: Session contains tool parts
- **WHEN** the transcript also contains tools, reasoning, or system records
- **THEN** these records are not rendered as conversation text

#### Scenario: Selected session is no longer available
- **WHEN** refresh returns `SessionNotFoundError`
- **THEN** the backend returns to the session list with an error and does not select a replacement

#### Scenario: Transcript spans multiple pages
- **WHEN** more messages exist than fit in one response
- **THEN** refresh includes all pages in ascending conversation order without duplicated boundary messages
- **AND** an empty terminal page is accepted even if the preceding page supplied a next cursor

#### Scenario: Session has no title or defaults yet
- **WHEN** a session omits title, agent, and model
- **THEN** it remains selectable and readable with title `Без названия` and no fabricated agent or model

### Requirement: Selected session header presentation
The selected OpenCode chat SHALL show a compact horizontal header with its title, current status, and a session-details control outside transcript scrolling. It SHALL omit the `OpenCode session` caption and hide the directory by default. It SHALL use existing system-font typography, preserve full title and retry text by wrapping when necessary, and leave the existing tab strip unchanged.

#### Scenario: Display session context
- **WHEN** an OpenCode chat is displayed
- **THEN** its compact header shows the selected session's title, status, and details control in one horizontal row
- **AND** retry status retains its full existing detail and an untitled session retains `Без названия`
- **AND** no standalone `OpenCode session` caption or directory row occupies height by default
- **AND** the title, status, and details control are vertically centered within the row

#### Scenario: Long context at increased font scale
- **WHEN** the title or retry text exceeds the available width at 125% system font scale
- **THEN** the full value wraps within its allocated header region without horizontal scrolling or truncation
- **AND** the details control remains operable

#### Scenario: Existing tabs remain intact
- **WHEN** a selected session uses the compact header
- **THEN** tab labels, dimensions, spacing, placement, selection, close and add controls remain unchanged
- **AND** the session title stays below the tab strip rather than replacing a tab label

### Requirement: Styled chat preserves controls and scrolling
The styled transcript SHALL occupy the remaining chat height and scroll independently of the header and existing prompt and voice-input controls. Styling SHALL preserve session action events, pending-input notices, errors, and busy-only Stop behavior. Message blocks SHALL NOT introduce actions or fabricated metadata; the header SHALL add only the session-details toggle.

#### Scenario: Overflowing conversation
- **WHEN** the transcript exceeds the available chat height
- **THEN** scrolling reveals its messages while the header and prompt controls remain stationary
- **AND** the prompt submission and voice-input actions retain their existing behavior

#### Scenario: Empty conversation
- **WHEN** the selected session has no messages
- **THEN** the header and prompt controls remain available without fabricated messages or timestamps

#### Scenario: Session needs attention
- **WHEN** the selected chat has an error, pending input, or busy status
- **THEN** existing errors and pending-input notices remain visible and Stop is offered only for busy status
- **AND** the styled message blocks do not expose permission or question-answer controls

## ADDED Requirements

### Requirement: Toggle selected session details
The chat SHALL provide a `Сведения` control that reveals the complete selected-session directory below the compact header and can hide it again. Details SHALL start collapsed when opening a session, survive refresh and tab switching for that open chat, and belong only to that chat. Toggling details SHALL preserve server-held prompt and transcript state without sending an OpenCode request.

#### Scenario: Reveal and hide directory
- **WHEN** the user activates `Сведения` in a newly opened chat
- **THEN** the full directory appears below the compact row, wrapping as needed
- **AND** activating the control again hides it and returns the height to the transcript

#### Scenario: Refresh or switch tabs
- **WHEN** the user refreshes a chat with details expanded or switches away and back
- **THEN** that chat retains its expanded state and reflects current session data
- **AND** other chats retain their own details state

#### Scenario: Toggle without reloading the session
- **WHEN** the user toggles session details
- **THEN** server-held prompt and transcript state remain intact and no OpenCode request is made
