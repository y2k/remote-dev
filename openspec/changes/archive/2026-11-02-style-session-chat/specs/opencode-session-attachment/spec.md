# Spec Delta

## ADDED Requirements

### Requirement: Selected session header presentation
The selected OpenCode chat SHALL group its title, full directory path, and current status in a separate rounded, padded, themed header. The header SHALL use the existing system-font typography and remain outside transcript scrolling. Long values SHALL wrap rather than truncate.

#### Scenario: Display session context
- **WHEN** an OpenCode chat is displayed
- **THEN** its header shows the selected session's title, directory, and status together
- **AND** retry status retains its full existing detail and an untitled session retains `Без названия`

#### Scenario: Long context at increased font scale
- **WHEN** the title or path exceeds the available width at 125% system font scale
- **THEN** the header wraps the complete values without horizontal scrolling or truncation

### Requirement: Role-separated chat messages
Each user and assistant text message SHALL appear in its own rounded, padded block with a separate role label, respectively `Вы` and `OpenCode`. User blocks SHALL be offset to the right with an accent background; assistant blocks SHALL be offset to the left with a neutral background. The complete original text and conversation order SHALL be preserved using the existing system font in both themes.

#### Scenario: Mixed conversation
- **WHEN** a conversation contains user and assistant messages, including consecutive messages of the same role
- **THEN** every message retains its own role label and block in the original order
- **AND** role names are not prepended to the message body

#### Scenario: Long and multiline messages
- **WHEN** a message contains Cyrillic, line breaks, or a path longer than the available width
- **THEN** the text wraps within its block, preserves its content and line breaks, and remains accessible through vertical scrolling

#### Scenario: Theme change
- **WHEN** the client renders the chat in light or dark mode
- **THEN** the blocks use themed accent and neutral backgrounds with readable text and distinguishable roles

### Requirement: Styled chat preserves controls and scrolling
The styled transcript SHALL occupy the remaining chat height and scroll independently of the header and existing prompt and voice-input controls. Styling SHALL preserve session action events, pending-input notices, errors, and busy-only Stop behavior. Message blocks and the header SHALL NOT introduce actions or fabricated metadata.

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
