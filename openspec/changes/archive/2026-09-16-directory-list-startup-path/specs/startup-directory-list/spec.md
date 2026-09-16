## MODIFIED Requirements

### Requirement: Use the backend startup working directory
The application SHALL use the optional positional startup path as the directory-list root in both Claude and OpenCode modes. When omitted, the root SHALL default to the backend process working directory captured at startup. A relative path SHALL be resolved against that startup working directory and the resulting absolute root SHALL be retained for initial loading, refresh, display, and directory-row click paths. Listing SHALL NOT require a Git repository or a reachable agent service. An unreadable root SHALL follow the existing directory-component load-error behavior rather than fall back to the working directory.

#### Scenario: Start either agent mode
- **WHEN** the backend starts in either supported mode from directory `/projects` without a positional path
- **THEN** the directory-list root is `/projects`

#### Scenario: Claude has an explicit repository root
- **WHEN** the backend starts from `/projects` with `--agent claude /other/repository`
- **THEN** the directory-list root is `/other/repository`

#### Scenario: OpenCode has an explicit directory root
- **WHEN** the backend starts from `/projects` with `--agent opencode /other/projects`
- **THEN** the directory-list root is `/other/projects`

#### Scenario: Relative startup path
- **WHEN** the backend starts from `/projects` with positional path `team` in either supported mode
- **THEN** the displayed root and initial directory load use `/projects/team`
- **AND** a row for its immediate subdirectory `example` advertises the absolute click path `/projects/team/example`

#### Scenario: Refresh uses the selected root
- **WHEN** the backend started with a positional path and the client refreshes the directory screen
- **THEN** the list is reloaded from the absolute root captured for that path at startup

#### Scenario: Root is not a Git repository
- **WHEN** the selected startup root is a readable directory that is not a Git repository
- **THEN** it can display that directory's subdirectories without invoking Git or an agent service

#### Scenario: Explicit root cannot be read
- **WHEN** the supplied path is missing, is a regular file, or cannot be read as a directory
- **THEN** the backend remains available and the directory component displays the selected absolute root and a load error
- **AND** refresh retries that root without substituting the working directory
