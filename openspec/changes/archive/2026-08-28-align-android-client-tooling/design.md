## Context

См. `proposal.md` для мотивации. В `android/` один прикладной модуль, а version catalog и корневой Gradle build уже являются единственными точками для общих plugins и зависимостей. В проекте-источнике `client/` используются тот же Gradle wrapper, `Spotless` с `ktfmt`, `detekt` и Compose rules.

## Goals / Non-Goals

**Goals:**

- Сделать конфигурацию форматирования и `detekt` в `android/` эквивалентной клиенту-источнику.
- Сохранить версии используемых Android-зависимостей и добавить quality-tooling из version catalog источника.
- Сделать `spotlessCheck` и `detekt` частью `./gradlew check`.

**Non-Goals:**

- Не добавлять runtime-зависимости, которые используются только модулями отсутствующего в `android/` клиента-источника.
- Не менять HTTP/UI-протокол, Android runtime-код или структуру модулей.
- Не изменять версии уже используемых Android-зависимостей в рамках этой change.

## Decisions

### Существующий Android catalog сохраняет версии runtime-зависимостей

Версии уже используемых Android-зависимостей в `gradle/libs.versions.toml`, включая AGP, Kotlin, Compose BOM, AndroidX, Ktor и test dependencies, сохраняются. Версии `detekt`, Compose rules, `ktfmt` и `Spotless` добавляются из `/Users/igor/Projects/remote_android_development/client/gradle/libs.versions.toml`.

Понижение Ktor до версии источника отклонено, потому что `android/` использует `io.ktor.utils.io.readLine`, отсутствующий в Ktor `3.3.3`. Полное копирование catalog также отклонено, поскольку добавит неиспользуемые runtime-библиотеки и plugin aliases для отсутствующих модулей.

### Root build управляет quality tooling

`Spotless` применяется в корневом Android build и форматирует `app/src/**/*.kt` и существующие Kotlin Gradle scripts через `ktfmt(...).kotlinlangStyle()`. `detekt` объявляется в version catalog, применяется ко всем subprojects и читает единый `android/detekt.yml`; внешний `io.nlopez.compose.rules:detekt` подключается к `detektPlugins`.

Это повторяет модель источника и автоматически связывает `spotlessCheck` с root `check`, а module-level `detekt` с проверками Android-модуля. Локальная конфигурация в `app/build.gradle.kts` отклонена, поскольку при добавлении модулей она дублирует общие правила.

### Правила detekt копируются без расширений

`android/detekt.yml` активирует только `Compose.ComposableParamOrder`, `coroutines.SuspendFunSwallowedCancellation` и `style.DataClassShouldBeImmutable`, как в источнике. Не добавляются baseline и дополнительные правила: существующие нарушения должны быть исправлены или отформатированы перед включением checks.

## Risks / Trade-offs

- [`detekt 2.0.0-alpha.6` является prerelease] → сохранять выбранную источником версию и не выполнять несогласованный upgrade в этой change.
- [`ktfmt` может переформатировать существующий Kotlin и Gradle Kotlin DSL] → сначала запустить `spotlessApply`, затем зафиксировать получившиеся изменения и проверить `spotlessCheck`.
- [Android build требует `backendHost`] → выполнять compilation/build verification с явным `-PbackendHost`.
- [Android lint требует явный `includeSubdomains`] → генерировать `includeSubdomains="false"`, чтобы сохранить доступ только к заданному host.

## Migration Plan

1. Добавить quality-tooling в version catalog и root Gradle configuration, затем добавить `detekt.yml`.
2. Явно сохранить ограничение network security config одним host через `includeSubdomains="false"`.
3. Применить форматирование к target files.
4. Запустить quality checks и debug build с явным `backendHost`.
5. При несовместимости вернуть прежние version entries и удалить quality-tooling configuration одним changeset.
