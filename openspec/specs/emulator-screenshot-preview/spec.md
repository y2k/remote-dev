# emulator-screenshot-preview Specification

## Purpose

Позволяет разработчику наблюдать экран выбранного работающего Android-эмулятора во время работы с выбранным worktree без ручного снятия снимков.

## Requirements

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

### Requirement: Refresh the displayed screenshot
The Android client SHALL load an `image` node when rendered and SHALL reload its source every three seconds while that node remains rendered. Reloading an image SHALL NOT submit a backend UI event or replace the surrounding UI document.

#### Scenario: Screenshot refreshes in place
- **WHEN** an `image` node remains visible for at least three seconds
- **THEN** the client requests its source again and replaces only the rendered image with the newly received PNG

#### Scenario: Screenshot request fails
- **WHEN** an image source cannot be retrieved or decoded
- **THEN** the client displays an image-specific error using the node label and keeps the surrounding UI document interactive

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

### Requirement: Forward a preview tap to its selected emulator
The backend SHALL attach a tap event identifying the preview's ADB serial to the selected available emulator's image node. A valid tap event SHALL execute one single tap at the supplied source-pixel coordinates on that serial. Before executing input, the backend SHALL validate the payload as integer coordinates and positive integer bitmap dimensions, require `0 <= x < width` and `0 <= y < height`, and require that the event serial is both selected and present in the last successfully loaded emulator list. It SHALL NOT redirect a stale event to a different selected device. It SHALL NOT send input for invalid or stale events. The selected serial, application screen, and emulator list SHALL remain unchanged by a tap.

#### Scenario: Tap the selected preview
- **WHEN** the selected available emulator's image receives a valid tap event
- **THEN** exactly one single tap is executed at the supplied coordinates on that emulator
- **AND** the current application screen, emulator list, and selection are retained

#### Scenario: Selection changed before an event arrived
- **WHEN** a tap event identifies emulator A but emulator B is now selected
- **THEN** no input is sent to either emulator

#### Scenario: Target is no longer listed or selected
- **WHEN** a tap event targets a serial absent from the last successfully loaded list or there is no selected emulator
- **THEN** no emulator input is sent

#### Scenario: Invalid tap payload
- **WHEN** the tap payload is malformed, lacks required fields, has non-integer fields, has non-positive dimensions, or contains coordinates outside the supplied bitmap bounds
- **THEN** no emulator input is sent and the failure is exposed to the client

### Requirement: Report emulator tap failures without disrupting the preview
If an attempted emulator tap fails, including when a listed emulator has stopped, the system SHALL display an error in the emulator panel while preserving the application screen, selected serial, emulator list, and screenshot source. The system SHALL allow another tap after the request completes and SHALL clear the previous tap error after a successful tap. A tap SHALL NOT trigger automatic emulator-list refresh or an additional screenshot request; existing three-second screenshot polling SHALL continue.

#### Scenario: Emulator stops before input is executed
- **WHEN** the emulator is still selected and listed but the input command fails because it has stopped
- **THEN** the panel displays the input failure without changing the selected serial or refreshing the list
- **AND** the surrounding application remains available after the request completes

#### Scenario: Retry succeeds
- **WHEN** another tap succeeds after an input failure
- **THEN** the previous input error is cleared and screenshot polling continues on its normal schedule

#### Scenario: Successful tap does not request an immediate screenshot
- **WHEN** the emulator accepts a tap
- **THEN** its visual result is shown on a subsequent regular screenshot refresh without a tap-triggered screenshot request
