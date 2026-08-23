## Context

См. `proposal.md`. Backend запускается через `make run` и слушает `:8080`; его корень Git выбирается первым аргументом процесса или текущей директорией. Android-клиент имеет фиксированный development URL `http://192.168.0.15:8080/`, а cleartext allowlist ограничен тем же IP. Сервер выполняет `git worktree list` и запускает доступный в `PATH` Claude CLI в выбранном worktree.

## Goals / Non-Goals

**Goals:**

- Дать новому разработчику воспроизводимый путь от зависимостей до работающего Android-клиента.
- Документировать фактический JSON event contract без создания второго источника истины для поведения.
- Сделать trust boundary заметной до запуска приложения.

**Non-Goals:**

- Изменение `dune-project`, Android-конфигурации, runtime-настроек или HTTP API.
- Замена фиксированного development адреса на конфигурацию.
- Публикация production deployment guide.

## Decisions

- Создать один корневой `README.md` на английском языке. Он соответствует публичной аудитории и не дублирует детали в отдельных документах; отдельные guides не нужны для текущего объёма.
- Описать запуск только существующими интерфейсами: `make build`, `make run ARGS=/path/to/repository`, `dune test` и `./gradlew assembleDebug` из `android/`. Не добавлять scripts или wrapper commands ради документации.
- Показать изменение backend IP как два связанных ручных шага: URL в `MainActivity.kt` и allowlist в `network_security_config.xml`. Это отражает текущую реализацию и предотвращает ошибочное ожидание runtime configuration.
- Выделить warning перед quick start: backend не аутентифицирует клиентов, принимает LAN HTTP и может выполнить prompt через локальный Claude CLI. Альтернатива, скрыть это в отдельном security разделе, отклонена как недостаточно заметная.
- Описать protocol кратко: `POST /`, envelope `{"event": {...}, "value": string|null}` и node types `column`, `row`, `text`, `button`, `input`. Полные требования остаются в OpenSpec, чтобы README не стал нормативной спецификацией.

## Risks / Trade-offs

- [README устареет при изменении fixed backend IP или команд] → Ссылаться на конкретные source files и включить проверку примеров в review документации.
- [Пользователь может принять инструмент за production-сервис] → Явно обозначить single-user trusted-LAN scope и отсутствие аутентификации.
- [Claude CLI доступен не на всех development machines] → Указать его как обязательную предпосылку и сохранить CLI setup вне scope.
