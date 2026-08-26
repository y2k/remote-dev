# claude-output-streaming Specification

## Purpose

Позволяет Android-клиенту видеть накапливающийся текстовый ответ Claude до завершения запущенной команды.

## Requirements

### Requirement: Stream Claude UI documents
При успешном событии `run_claude` система SHALL возвращать `application/x-ndjson` response. Каждая непустая строка response SHALL быть одним компактным, полным backend-defined JSON UI-документом с текстом ответа Claude, накопленным на момент её отправки.

#### Scenario: Claude produces text in multiple deltas
- **WHEN** Claude выдаёт несколько текстовых дельт для одного запущенного prompt
- **THEN** сервер отправляет UI-документ после каждой дельты в том же порядке, а `output` каждого следующего документа содержит все предыдущие и новую дельту

#### Scenario: Claude completes without an error
- **WHEN** Claude успешно завершает prompt после одной или нескольких текстовых дельт
- **THEN** сервер завершает NDJSON response после последнего UI-документа

### Requirement: Render streamed UI documents incrementally
Android-клиент SHALL читать NDJSON response для `run_claude` построчно и заменять отображаемый UI-документ каждым корректным полученным документом до закрытия response.

#### Scenario: Client receives a streamed document
- **WHEN** клиент получает полную непустую строку NDJSON response
- **THEN** клиент парсит строку как UI-документ и немедленно обновляет отображаемое Compose state

#### Scenario: Stream finishes
- **WHEN** NDJSON response закрывается
- **THEN** клиент завершает отправку события и снова разрешает последующие UI-события

### Requirement: Preserve non-streaming UI events
Система SHALL возвращать единственный `application/json` UI-документ для каждого допустимого UI-события, которое не запускает обычную UI-команду и не запускает Claude output stream.

#### Scenario: Client loads or navigates
- **WHEN** клиент отправляет допустимое событие `select_worktree`, `set_prompt`, `new_worktree` или `create_worktree`, не запускающее команду
- **THEN** сервер возвращает один полный UI-документ с `application/json`

### Requirement: Surface streaming execution failure
Если запуск Claude не может завершиться успешно после начала streaming response, сервер SHALL отправить финальный UI-документ с ошибкой и затем завершить response.

#### Scenario: Claude exits unsuccessfully during a stream
- **WHEN** Claude завершается с ошибкой после начала `run_claude` response
- **THEN** клиент получает финальный UI-документ с сообщением об ошибке и возвращается в состояние, допускающее новое событие
