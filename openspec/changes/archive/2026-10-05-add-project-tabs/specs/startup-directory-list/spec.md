## MODIFIED Requirements

### Requirement: Use the backend startup working directory
The application SHALL use the optional positional startup path as the directory-list root in both Claude and OpenCode modes. When omitted, the root SHALL default to the backend process working directory captured at startup. A relative path SHALL be resolved against that startup working directory and the resulting absolute root SHALL be retained for initial loading, refresh, display, and directory-row click paths. Listing SHALL NOT require a Git repository or a reachable agent service. An unreadable root SHALL follow the existing directory-component load-error behavior rather than fall back to the working directory. In OpenCode mode the root SHALL be captured at startup but SHALL first be read and displayed when the user creates a tab.

#### Scenario: Start either agent mode
- **WHEN** the backend starts in either supported mode from directory `/projects` without a positional path
- **THEN** the directory-list root is `/projects`

#### Scenario: Claude has an explicit repository root
- **WHEN** the backend starts from `/projects` with `--agent claude /other/repository`
- **THEN** the directory-list root is `/other/repository`

#### Scenario: OpenCode has an explicit directory root
- **WHEN** the backend starts from `/projects` with `--agent opencode /other/projects`
- **THEN** the captured directory-list root is `/other/projects` and is used when the first tab is created

#### Scenario: Relative startup path
- **WHEN** the backend starts from `/projects` with positional path `team` in either agent mode and its directory list is first loaded
- **THEN** the displayed root and initial directory load use `/projects/team`
- **AND** a row for its immediate subdirectory `example` advertises the absolute click path `/projects/team/example`

#### Scenario: Refresh uses the selected root
- **WHEN** the backend started with a positional path and the client refreshes the standalone directory screen or the tab UI with at least one tab
- **THEN** the list is reloaded from the absolute root captured for that path at startup

#### Scenario: Root is not a Git repository
- **WHEN** the selected startup root is a readable directory that is not a Git repository
- **THEN** its directory component can display that directory's subdirectories without invoking Git or an agent service

#### Scenario: Explicit root cannot be read
- **WHEN** a directory load is attempted for a supplied path that is missing, is a regular file, or cannot be read as a directory
- **THEN** the backend remains available and the directory component displays the selected absolute root and a load error
- **AND** refresh retries that root without substituting the working directory

### Requirement: Render a distinct directory component beside the emulator
In Claude mode the startup document SHALL render a distinct directory-list component as the left content pane and the existing emulator panel as the right pane. In OpenCode mode the startup document SHALL render an empty tab UI on the left; the directory component SHALL appear in the active tab only after a tab is created. Whenever displayed, the directory component SHALL display its root path and clickable directory-name rows, each advertising an event identifying that directory's absolute path. The layout SHALL retain the existing `2:1` content-to-emulator width ratio and themed divider. The initial document SHALL NOT display the worktree list or OpenCode session list. The emulator panel SHALL be common to all tabs.

#### Scenario: Render the startup document
- **WHEN** the initial directory load finishes in Claude mode
- **THEN** the document displays the directory component on the left and the emulator panel on the right
- **AND** directory rows offer no navigation or agent-execution action

#### Scenario: Render OpenCode startup and first tab
- **WHEN** OpenCode starts
- **THEN** the left pane contains zero tabs and a creation control with no directory component
- **AND** creating the first tab displays the directory component inside it beside the common emulator panel

#### Scenario: No emulator or emulator error
- **WHEN** the emulator panel is empty or reports an error
- **THEN** the directory component, or empty tab UI when no tab exists, remains visible in the left pane with the same layout ratio

### Requirement: Refresh the directory component independently
The root `Refresh` event on the standalone directory screen SHALL reload and re-sort directories from the captured root. On the OpenCode tab UI it SHALL reload the common directory list if at least one tab exists and SHALL perform no directory load if zero tabs exist. Refresh SHALL preserve tabs, active selection and emulator state and SHALL NOT load worktrees or OpenCode sessions. `Back` on these screens SHALL keep the UI unchanged without an error. Directory contents SHALL be read at initialization in Claude mode, when creating the first tab from zero tabs in OpenCode mode, and on applicable explicit root refresh, without a directory polling timer. Creating additional tabs or selecting a tab SHALL reuse the common list. The emulator panel's own refresh SHALL remain independent.

#### Scenario: Directory set changes
- **WHEN** directories have been added, removed, or given different modification times and the client sends root `Refresh` on a standalone directory screen or a tab UI with tabs
- **THEN** the resulting list reflects the current eligible directories in the specified order and limit
- **AND** tabs, selection, the selected emulator and loaded emulator list are preserved

#### Scenario: Back at startup
- **WHEN** the standalone directory screen or tab UI receives `Back`
- **THEN** it stays unchanged without a new error or directory reload

#### Scenario: Emulator-only refresh
- **WHEN** the user invokes the emulator panel's own refresh
- **THEN** the directory component and its last loaded entries remain unchanged

#### Scenario: Empty tab UI refresh
- **WHEN** root Refresh is received with zero tabs
- **THEN** the backend returns the complete empty tab UI without reading directories or creating a tab

### Requirement: Report directory load failures in the component
If reading the root or obtaining entry metadata fails during a directory load, the directory component SHALL display a load error and preserve its last successfully loaded entries. On an initial failure it SHALL show the root and error without claiming that the directory is empty. The backend SHALL remain available and root `Refresh` SHALL allow retry whenever the directory component is present. A successful retry SHALL replace the entries and clear the error. In OpenCode mode no directory load or directory error SHALL be shown before a tab is created, and a load failure SHALL NOT remove the created tab.

#### Scenario: Initial load fails
- **WHEN** the initial directory load in Claude mode or upon creating the first OpenCode tab fails
- **THEN** the document displays a directory error beside the emulator panel and the backend accepts subsequent requests
- **AND** an OpenCode tab created for this load remains active

#### Scenario: Refresh fails and retry succeeds
- **WHEN** a refresh fails after a successful directory load
- **THEN** the component retains the previous entries and displays the error
- **AND** a subsequent successful refresh replaces the entries and clears the error
