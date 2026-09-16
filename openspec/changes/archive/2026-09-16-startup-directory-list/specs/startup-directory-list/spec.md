## Purpose

Показывает при запуске приложения до десяти недавно изменённых непосредственных подкаталогов рабочей директории backend в отдельной области слева от эмулятора.

## ADDED Requirements

### Requirement: Use the backend startup working directory
The application SHALL use the backend process working directory captured at startup as the directory-list root in both Claude and OpenCode modes. A Claude positional repository-root argument SHALL NOT override this root. Listing SHALL NOT require a Git repository or a reachable agent service.

#### Scenario: Start either agent mode
- **WHEN** the backend starts in either supported mode from directory `/projects`
- **THEN** the directory-list root is `/projects`

#### Scenario: Claude has an explicit repository root
- **WHEN** the backend starts from `/projects` with `--agent claude /other/repository`
- **THEN** the directory-list root remains `/projects`

#### Scenario: Root is not a Git repository
- **WHEN** the backend starts from a readable directory that is not a Git repository
- **THEN** it can display that directory's subdirectories without invoking Git or an agent service

### Requirement: Show the ten most recently modified immediate directories
The directory list SHALL contain at most ten real immediate subdirectories of its root, ordered by each directory's own filesystem modification time descending. Equal modification times SHALL be ordered by name using case-sensitive bytewise ascending comparison. Hidden directories SHALL be included. Files and symbolic links SHALL be excluded. The application SHALL NOT recursively inspect descendants to determine activity. It SHALL display each selected directory's name and SHALL display an explicit empty state when there are no eligible directories.

#### Scenario: More than ten directories
- **WHEN** the root contains twelve eligible directories with distinct modification times
- **THEN** the list contains exactly the ten newest directories in descending modification-time order

#### Scenario: Fewer than ten directories
- **WHEN** the root contains three eligible directories
- **THEN** the list contains all three in the specified order

#### Scenario: Equal modification times
- **WHEN** eligible directories have equal modification times, including at the tenth-entry boundary
- **THEN** name ordering determines their stable order and which entries are included

#### Scenario: Files, links, and nested directories
- **WHEN** the root contains a file, a symbolic link to a directory, a hidden real directory, and a real directory containing nested directories
- **THEN** only the hidden real directory and the immediate real directory are eligible from those entries
- **AND** nested directories are not separate rows and their timestamps do not affect sorting

#### Scenario: Empty list
- **WHEN** the root contains no eligible directories
- **THEN** the component states that there are no subdirectories

### Requirement: Render a distinct directory component beside the emulator
The startup document SHALL render a distinct directory-list component as the left content pane and the existing emulator panel as the right pane in both agent modes. The directory component SHALL display its root path and clickable directory-name rows, each advertising an event identifying that directory's absolute path. The layout SHALL retain the existing `2:1` content-to-emulator width ratio and themed divider. The initial document SHALL NOT display the worktree list or OpenCode session list alongside the directory list.

#### Scenario: Render the startup document
- **WHEN** the initial directory load finishes in either agent mode
- **THEN** the document displays the directory component on the left and the emulator panel on the right
- **AND** directory rows offer no navigation or agent-execution action

#### Scenario: No emulator or emulator error
- **WHEN** the emulator panel is empty or reports an error
- **THEN** the directory component remains visible in the left pane with the same layout ratio

### Requirement: Log a directory click without changing state
When the backend processes a click event advertised by a directory row, it SHALL write one console log entry identifying the clicked directory's absolute path. It SHALL return a UI document with unchanged application state, including directory entries, errors, and emulator state. A click SHALL NOT select or highlight a directory, navigate, reload directories, or invoke an agent. Path control characters SHALL be escaped in the log so that one click produces one log line.

#### Scenario: Click a directory
- **WHEN** the client activates the row for `/projects/example` and the backend processes its click event
- **THEN** the backend console receives one log entry identifying `/projects/example`
- **AND** the returned UI retains the same screen and state without navigation, directory reload, or agent execution

#### Scenario: Repeat a click
- **WHEN** the backend processes two successive clicks on the same directory row
- **THEN** it writes one log entry for each click and retains the same application state

#### Scenario: Directory name contains a line break
- **WHEN** the backend processes a click on a directory whose name contains a line break
- **THEN** the log escapes the line break and contains the path within one log line

### Requirement: Refresh the directory component independently
The root `Refresh` event on the directory screen SHALL reload and re-sort directories from the captured root. It SHALL preserve emulator state and SHALL NOT load worktrees or OpenCode sessions. `Back` on this screen SHALL keep the screen unchanged without an error. Directory contents SHALL be read at backend initialization and explicit refresh, without a directory polling timer.

#### Scenario: Directory set changes
- **WHEN** directories have been added, removed, or given different modification times and the client sends root `Refresh`
- **THEN** the resulting list reflects the current eligible directories in the specified order and limit
- **AND** the selected emulator and loaded emulator list are preserved

#### Scenario: Back at startup
- **WHEN** the directory screen receives `Back`
- **THEN** it stays on the directory screen without a new error or directory reload

#### Scenario: Emulator-only refresh
- **WHEN** the user invokes the emulator panel's own refresh
- **THEN** the directory component and its last loaded entries remain unchanged

### Requirement: Report directory load failures in the component
If reading the root or obtaining entry metadata fails, the directory component SHALL display a load error and preserve its last successfully loaded entries. On an initial failure it SHALL show the root and error without claiming that the directory is empty. The backend SHALL remain available and root `Refresh` SHALL allow retry. A successful retry SHALL replace the entries and clear the error.

#### Scenario: Initial load fails
- **WHEN** the startup root cannot be read
- **THEN** the initial document displays a directory error beside the emulator panel and the backend accepts subsequent requests

#### Scenario: Refresh fails and retry succeeds
- **WHEN** a refresh fails after a successful directory load
- **THEN** the component retains the previous entries and displays the error
- **AND** a subsequent successful refresh replaces the entries and clears the error
