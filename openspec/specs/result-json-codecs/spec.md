# result-json-codecs Specification

## Purpose

Обеспечивает надёжное JSON-представление результатов операций в сообщениях UI без исключений при их кодировании или разборе.

## Requirements

### Requirement: Serialize result values
The system SHALL serialize a successful result as a two-element JSON array whose first element is `"Ok"` and whose second element is the success value encoded by its supplied codec. The system SHALL serialize an error result identically with `"Error"` and the error value encoded by its supplied codec.

#### Scenario: Serialize a successful result
- **WHEN** a UI message containing an `Ok` result is serialized
- **THEN** the result payload is represented as `["Ok", value]` and serialization completes without an exception

#### Scenario: Serialize an error result
- **WHEN** a UI message containing an `Error` result is serialized
- **THEN** the result payload is represented as `["Error", value]` and serialization completes without an exception

### Requirement: Deserialize result values
The system SHALL deserialize a two-element JSON array tagged `"Ok"` or `"Error"` by applying the corresponding supplied payload codec. The system SHALL return a decode error, rather than raise an exception, for an unrecognized tag, an invalid array shape, or an invalid payload.

#### Scenario: Deserialize a successful result
- **WHEN** the system receives `["Ok", value]` with a value accepted by the success codec
- **THEN** it produces an `Ok` result containing the decoded value

#### Scenario: Reject an invalid result representation
- **WHEN** the system receives a result JSON value with an unknown tag, invalid shape, or payload rejected by its codec
- **THEN** it returns a decode error without raising an exception
