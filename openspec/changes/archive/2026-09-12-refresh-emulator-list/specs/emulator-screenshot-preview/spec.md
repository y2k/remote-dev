## MODIFIED Requirements

### Requirement: Select an emulator from the application root
The system SHALL load the running Android emulators when the backend application initializes and SHALL show an emulator panel on every current or future root application screen. The panel SHALL expose a selectable control for each available emulator, displaying its AVD name when available and otherwise its ADB serial. The system SHALL identify the selected emulator by ADB serial independently of the available list, SHALL initially have no selection, and SHALL select an emulator only through an explicit user selection. When the selected serial is available, the root view SHALL show its screenshot `image` node. When no selection exists, the panel SHALL show a choose-emulator prompt if devices are available, or a no-running-emulators message if the list is empty. When the selected serial is absent from the last successfully loaded list, the panel SHALL show a selected-emulator-unavailable placeholder and SHALL NOT emit its screenshot `image` node. The selected serial SHALL remain selected across list refreshes and navigation, even when absent, and SHALL NOT be persisted across backend restarts. Navigation SHALL NOT reload the emulator list.

#### Scenario: Worktree has several running emulators
- **WHEN** the application initializes while two Android emulators are running
- **THEN** every application screen shows a selectable control for each emulator and a choose-emulator prompt, with no selected emulator and no screenshot image

#### Scenario: User changes the selected emulator
- **WHEN** the user activates the control for a listed emulator on any application screen
- **THEN** the system stores its ADB serial as the selection and the returned UI document shows an `image` node whose `src` identifies that emulator

#### Scenario: No emulator is running
- **WHEN** the application initializes while no Android emulator is running
- **THEN** every application screen shows a clear no-running-emulators message and does not include an emulator screenshot image

#### Scenario: User navigates between application screens
- **WHEN** the user selects an emulator and then navigates to another application screen
- **THEN** the new screen keeps the same serial selected without reloading the emulator list, including when that serial is absent from the list

#### Scenario: Backend restarts
- **WHEN** the backend restarts after the user selected an emulator
- **THEN** the system reloads the running emulator list with no selection and does not restore or automatically replace the previous selection

#### Scenario: Selected emulator is absent while others are available
- **WHEN** a successful list refresh excludes the selected serial but includes other devices
- **THEN** the selected serial remains stored, the panel shows the unavailable placeholder without a screenshot image, and the other devices remain available for manual selection

#### Scenario: All emulators disappear
- **WHEN** a successful list refresh returns an empty list after an emulator was selected
- **THEN** the system retains the selected serial and shows the selected-emulator-unavailable placeholder without a screenshot image

#### Scenario: Selected emulator returns
- **WHEN** a successful list refresh includes the previously unavailable selected serial
- **THEN** the panel shows its screenshot image again without requiring another selection

### Requirement: Provide a current emulator screenshot
The backend SHALL serve a PNG screenshot for each `image` source it emits for a selected running emulator. The screenshot response SHALL prevent reuse of a stale cached response.

#### Scenario: Screenshot is requested for the selected emulator
- **WHEN** the Android client requests the emitted image source while that emulator remains available
- **THEN** the backend returns its current screen as `image/png` with a response directive that prevents caching

#### Scenario: Selected emulator becomes unavailable
- **WHEN** the Android client requests the emitted image source after that emulator is no longer available and before a successful manual list refresh detects its absence
- **THEN** the backend returns a non-success response without changing the selected serial or refreshing the UI list, and the client keeps the rest of the application UI visible
- **AND** a subsequent successful manual list refresh detecting the absence replaces the preview with the unavailable placeholder without requiring a backend restart

## ADDED Requirements

### Requirement: Manually refresh the emulator list
The emulator panel SHALL expose a `Refresh` button on every root application screen, including when there is no selection, the list is empty, the selected emulator is unavailable, or loading has failed. Activating it SHALL reload the running emulator list and return an updated UI without resetting the current application screen or changing the selected serial. The system SHALL NOT automatically refresh the list on a timer. Screenshot reloads SHALL NOT refresh the UI list. A failed list refresh SHALL preserve the last successfully loaded list and selected serial, show an error in the emulator panel, and allow retry. A successful refresh SHALL clear the previous loading error.

#### Scenario: Emulator appears after startup
- **WHEN** the application started without running emulators and the user presses the panel's Refresh button after an emulator starts
- **THEN** the panel lists the new device and prompts the user to select it, without selecting it automatically

#### Scenario: Refresh preserves an available selection
- **WHEN** the user refreshes and the selected serial remains available, even if list order or its display name changes
- **THEN** the same serial stays selected and its current display name and screenshot source are rendered

#### Scenario: Refresh is local to the emulator panel
- **WHEN** the user presses the emulator panel's Refresh button on any root screen
- **THEN** the updated UI retains the current screen and its state while updating the emulator panel

#### Scenario: Refresh fails and is retried
- **WHEN** a list refresh fails
- **THEN** the panel shows an error, retains the previous list and selected serial, and still exposes Refresh
- **AND** a successful retry replaces the list, clears the error, and retains the same selected serial

#### Scenario: Device changes without manual refresh
- **WHEN** a device appears or disappears after the list was loaded and the user does not press the panel's Refresh button
- **THEN** the UI list remains unchanged, including while screenshot requests continue
