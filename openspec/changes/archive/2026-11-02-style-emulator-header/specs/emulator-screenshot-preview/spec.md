# Spec Delta

## ADDED Requirements

### Requirement: Compact emulator header
The panel SHALL show its available devices as a horizontal selector without an `Emulators` heading. Labels SHALL retain real device names or serial fallbacks. Only the available device matching the backend-selected serial SHALL be highlighted. Device order SHALL follow the loaded list. Refresh SHALL be pinned on the right outside the scrolling device group.

#### Scenario: No selection
- **WHEN** one or more devices are available but no serial has been selected
- **THEN** none is highlighted and the existing choose-emulator prompt is shown

#### Scenario: Selection is unavailable
- **WHEN** the selected serial is absent from the loaded list
- **THEN** none of the available device controls is highlighted and the existing unavailable placeholder remains

#### Scenario: Selected device returns or is renamed
- **WHEN** a refreshed list contains the selected serial with a changed name or position
- **THEN** that serial's control is highlighted with its current name and the preview follows the existing selection contract

#### Scenario: No devices
- **WHEN** the loaded list is empty
- **THEN** the header still contains Refresh and the existing no-running-emulators or selected-unavailable message remains below it

## MODIFIED Requirements

### Requirement: Manually refresh the emulator list
The emulator panel SHALL expose an icon-only refresh button with the accessible description `Обновить список эмуляторов` on every root application screen, including when there is no selection, the list is empty, the selected emulator is unavailable, or loading has failed. Activating it SHALL reload the running emulator list and return an updated UI without resetting the current application screen or changing the selected serial. The system SHALL NOT automatically refresh the list on a timer. Screenshot reloads SHALL NOT refresh the UI list. A failed list refresh SHALL preserve the last successfully loaded list and selected serial, show an error in the emulator panel, and allow retry. A successful refresh SHALL clear the previous loading error.

#### Scenario: Emulator appears after startup
- **WHEN** the application started without running emulators and the user presses the panel's refresh icon after an emulator starts
- **THEN** the panel lists the new device and prompts the user to select it, without selecting it automatically

#### Scenario: Refresh preserves an available selection
- **WHEN** the user refreshes and the selected serial remains available, even if list order or its display name changes
- **THEN** the same serial stays selected and its current display name and screenshot source are rendered

#### Scenario: Refresh is local to the emulator panel
- **WHEN** the user presses the emulator panel's refresh icon on any root screen
- **THEN** the updated UI retains the current screen and its state while updating the emulator panel

#### Scenario: Refresh fails and is retried
- **WHEN** a list refresh fails
- **THEN** the panel shows an error, retains the previous list and selected serial, and still exposes Refresh
- **AND** a successful retry replaces the list, clears the error, and retains the same selected serial

#### Scenario: Device changes without manual refresh
- **WHEN** a device appears or disappears after the list was loaded and the user does not press the panel's refresh icon
- **THEN** the UI list remains unchanged, including while screenshot requests continue
