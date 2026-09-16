## ADDED Requirements

### Requirement: Optional image tap event
An `image` node SHALL accept an optional `event` containing an opaque backend-defined JSON array, using the existing wire event representation. An image without `event` SHALL retain its display-only behavior. A present event that is not a JSON array, including null, SHALL cause a parse failure. The client SHALL preserve the image label as its content description.

#### Scenario: Parse an interactive image
- **WHEN** an otherwise valid image contains an event array
- **THEN** the client renders the image and retains that event unchanged for tap submission

#### Scenario: Preserve a display-only image
- **WHEN** an image omits event and the user taps it
- **THEN** no event request is sent and normal image polling continues

#### Scenario: Reject an invalid image event
- **WHEN** an image event is null, an object, string, number, or boolean
- **THEN** the client rejects the document as a parse failure

### Requirement: Submit a single image tap in source pixels
When a decoded image with an event receives a completed single tap and no UI event request is in progress, the client SHALL send exactly one `POST /` request containing the unchanged event and a string `value` encoding a JSON object with integer fields `x`, `y`, `width`, and `height`. Width and height SHALL describe the displayed source bitmap in pixels. Coordinates SHALL identify the tapped source pixel after accounting for the rendered image's scale and alignment, with `0 <= x < width` and `0 <= y < height`. Taps outside the painted image, taps before a bitmap is available, and cancelled or dragged gestures SHALL NOT submit a tap. Image taps SHALL use the existing event request serialization and response rendering behavior, without queueing taps made while another event is in progress.

#### Scenario: Tap a scaled image
- **WHEN** a 1080 by 1920 bitmap is painted at 270 by 480 and a single tap lands 135 pixels right and 240 pixels down from its painted top-left corner
- **THEN** one request carries the image event and a value encoding `{"x":540,"y":960,"width":1080,"height":1920}`

#### Scenario: Tap a centered image with margins
- **WHEN** the painted bitmap occupies only part of its layout bounds
- **THEN** a tap inside the bitmap is measured from its painted top-left corner
- **AND** a tap in an unpainted margin sends no event

#### Scenario: Another request is running
- **WHEN** the user taps an interactive image while another UI event request is in progress
- **THEN** no tap request is sent or queued for later

#### Scenario: Image has not loaded
- **WHEN** the image is showing loading or failure content without a decoded bitmap
- **THEN** tapping that content sends no image event

#### Scenario: User drags or cancels a gesture
- **WHEN** a pointer gesture is recognized as a drag or is cancelled before completion
- **THEN** it sends no image tap event

#### Scenario: Tap response arrives
- **WHEN** the backend returns UI documents for a tap and the same image source remains rendered
- **THEN** the client renders the documents through its existing event response handling
- **AND** continues the existing three-second image polling without an additional tap-triggered image request
