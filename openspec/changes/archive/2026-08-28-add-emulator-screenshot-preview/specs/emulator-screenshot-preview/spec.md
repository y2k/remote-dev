## Purpose

Позволяет разработчику наблюдать экран выбранного работающего Android-эмулятора во время работы с выбранным worktree без ручного снятия снимков.

## ADDED Requirements

### Requirement: Select an emulator from a worktree
The system SHALL show the running Android emulators in the selected worktree view and SHALL allow the user to select one. When at least one emulator is available, the view SHALL show an `image` node for the selected emulator; when the view first loads, the system SHALL select one available emulator. The system SHALL identify an emulator by its AVD name when available, otherwise by its ADB serial.

#### Scenario: Worktree has several running emulators
- **WHEN** the selected worktree view loads while two Android emulators are running
- **THEN** the UI document shows a selectable control for each emulator and an `image` node for one selected emulator

#### Scenario: User changes the selected emulator
- **WHEN** the user activates the control for another listed emulator
- **THEN** the returned UI document shows an `image` node whose `src` identifies that emulator

#### Scenario: No emulator is running
- **WHEN** the selected worktree view loads while no Android emulator is running
- **THEN** the UI document shows a clear no-running-emulators message and does not include an `image` node for an emulator screenshot

### Requirement: Provide a current emulator screenshot
The backend SHALL serve a PNG screenshot for each `image` source it emits for a selected running emulator. The screenshot response SHALL prevent reuse of a stale cached response.

#### Scenario: Screenshot is requested for the selected emulator
- **WHEN** the Android client requests the emitted image source while that emulator remains available
- **THEN** the backend returns its current screen as `image/png` with a response directive that prevents caching

#### Scenario: Selected emulator becomes unavailable
- **WHEN** the Android client requests the emitted image source after that emulator is no longer available
- **THEN** the backend returns a non-success response and the client keeps the rest of the worktree UI visible

### Requirement: Refresh the displayed screenshot
The Android client SHALL load an `image` node when rendered and SHALL reload its source every three seconds while that node remains rendered. Reloading an image SHALL NOT submit a backend UI event or replace the surrounding UI document.

#### Scenario: Screenshot refreshes in place
- **WHEN** an `image` node remains visible for at least three seconds
- **THEN** the client requests its source again and replaces only the rendered image with the newly received PNG

#### Scenario: Screenshot request fails
- **WHEN** an image source cannot be retrieved or decoded
- **THEN** the client displays an image-specific error using the node label and keeps the surrounding UI document interactive
