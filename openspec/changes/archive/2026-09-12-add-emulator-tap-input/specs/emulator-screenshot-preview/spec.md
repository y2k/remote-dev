## ADDED Requirements

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
