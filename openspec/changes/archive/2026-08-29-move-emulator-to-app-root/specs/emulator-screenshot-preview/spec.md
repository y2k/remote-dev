## MODIFIED Requirements

### Requirement: Select an emulator from the application root
The system SHALL load the running Android emulators once when the backend application initializes, SHALL show the emulator selector and preview on every current or future root application screen, and SHALL allow the user to select one global emulator. When at least one emulator is available, the root view SHALL show an `image` node for the selected emulator and SHALL initially select one available emulator. The system SHALL identify an emulator by its AVD name when available, otherwise by its ADB serial. The selected emulator SHALL remain selected while the user navigates between application screens, SHALL NOT cause the emulator list to reload during navigation, and SHALL NOT be persisted across backend restarts.

#### Scenario: Worktree has several running emulators
- **WHEN** the application initializes while two Android emulators are running
- **THEN** every application screen shows a selectable control for each emulator and an `image` node for one selected emulator

#### Scenario: User changes the selected emulator
- **WHEN** the user activates the control for another listed emulator on any application screen
- **THEN** the returned UI document shows an `image` node whose `src` identifies that emulator

#### Scenario: No emulator is running
- **WHEN** the application initializes while no Android emulator is running
- **THEN** every application screen shows a clear no-running-emulators message and does not include an `image` node for an emulator screenshot

#### Scenario: User navigates between application screens
- **WHEN** the user selects an emulator and then navigates to another application screen
- **THEN** the new screen keeps the same emulator selected without reloading the emulator list

#### Scenario: Backend restarts
- **WHEN** the backend restarts after the user selected an emulator
- **THEN** the system reloads the running emulator list and selects one currently available emulator without restoring the previous selection

### Requirement: Provide a current emulator screenshot
The backend SHALL serve a PNG screenshot for each `image` source it emits for a selected running emulator. The screenshot response SHALL prevent reuse of a stale cached response.

#### Scenario: Screenshot is requested for the selected emulator
- **WHEN** the Android client requests the emitted image source while that emulator remains available
- **THEN** the backend returns its current screen as `image/png` with a response directive that prevents caching

#### Scenario: Selected emulator becomes unavailable
- **WHEN** the Android client requests the emitted image source after that emulator is no longer available
- **THEN** the backend returns a non-success response, keeps the same emulator selected without reloading the list, and the client keeps the rest of the application UI visible until the backend restarts

### Requirement: Place emulator beside application content
Every current or future root application screen SHALL display its screen-specific content in a left pane occupying two thirds of the available width and SHALL display the complete emulator block in a right pane occupying one third of the available width. The root layout SHALL retain this fixed ratio regardless of viewport width and SHALL NOT collapse or reflow based on the selected-emulator, no-running-emulators, or emulator-error state.

#### Scenario: Selected emulator is available
- **WHEN** any application screen displays a running emulator
- **THEN** the screen-specific content occupies the left two thirds while the emulator selector and image occupy the right third

#### Scenario: No emulator is available
- **WHEN** any application screen has no running emulator
- **THEN** the screen-specific content remains in the left two thirds and the no-running-emulators state remains in the right third

#### Scenario: Emulator loading fails
- **WHEN** loading the emulator list produces an error
- **THEN** the screen-specific content remains in the left two thirds and the emulator error remains in the right third

#### Scenario: Application uses a narrow viewport
- **WHEN** any application screen is rendered in a narrow or portrait viewport
- **THEN** the screen-specific content remains in the left two thirds and the emulator block remains in the right third

#### Scenario: Application adds another root screen
- **WHEN** the backend displays a root screen introduced after this requirement
- **THEN** that screen uses the same left-content and right-emulator root layout

## RENAMED Requirements

- FROM: `### Requirement: Select an emulator from a worktree`
- TO: `### Requirement: Select an emulator from the application root`
- FROM: `### Requirement: Place emulator beside worktree content`
- TO: `### Requirement: Place emulator beside application content`
