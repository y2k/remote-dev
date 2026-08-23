## Context

См. `proposal.md`. Backend запускается через `make run` и слушает `:8080`; его корень Git выбирается первым аргументом процесса или текущей директорией. Android build получает `backendHost` из `android/local.properties`; `-PbackendHost` переопределяет его для одного build. Gradle генерирует `BuildConfig.BACKEND_URL` и cleartext allowlist для выбранного host. Сервер выполняет `git worktree list` и запускает доступный в `PATH` Claude CLI в выбранном worktree.

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
- Показать настройку backend IP через `android/local.properties` и однократное переопределение `-PbackendHost=<IP-address>`. Это соответствует build-time configuration; Gradle синхронно генерирует URL и allowlist, поэтому ручные изменения Android source files не нужны.
- Выделить warning перед quick start: backend не аутентифицирует клиентов, принимает LAN HTTP и может выполнить prompt через локальный Claude CLI. Альтернатива, скрыть это в отдельном security разделе, отклонена как недостаточно заметная.
- Описать protocol кратко: `POST /`, envelope `{"event": {...}, "value": string|null}` и node types `column`, `row`, `text`, `button`, `input`. Полные требования остаются в OpenSpec, чтобы README не стал нормативной спецификацией.

## Risks / Trade-offs

- [README устареет при изменении build-time backend configuration или команд] → Ссылаться на `android/README.md` и конкретные source files и включить проверку примеров в review документации.
- [Пользователь может принять инструмент за production-сервис] → Явно обозначить single-user trusted-LAN scope и отсутствие аутентификации.
- [Claude CLI доступен не на всех development machines] → Указать его как обязательную предпосылку и сохранить CLI setup вне scope.
