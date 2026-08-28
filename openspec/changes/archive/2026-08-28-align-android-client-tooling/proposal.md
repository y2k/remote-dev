## Why

Android-модуль не использует единые автоматические проверки форматирования и статического анализа, хотя настройки эталонного Android-клиента уже определены. Нужны те же проверки и зафиксированные версии зависимостей, чтобы Android-сборка была согласована с клиентом-источником.

## What Changes

- Добавить `Spotless` с `ktfmt` и стилем `kotlinlangStyle()` для Kotlin-кода и Gradle Kotlin DSL Android-модуля.
- Добавить `detekt`, Compose rules и существующую конфигурацию из клиентского проекта-источника; включить заданные правила `ComposableParamOrder`, `SuspendFunSwallowedCancellation` и `DataClassShouldBeImmutable`.
- Сохранить версии уже используемых Android-зависимостей и добавить версии новых quality tools из `/Users/igor/Projects/remote_android_development/client`.
- Включить форматирование и статический анализ в стандартный Gradle lifecycle `check`.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет.

## Impact

- Затрагиваются `android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/gradle/libs.versions.toml` и новый `android/detekt.yml`.
- Меняется только build tooling Android-клиента; его HTTP/UI-протокол, runtime-поведение и публичные OpenSpec requirements не меняются.
- Добавляются build-time зависимости `com.diffplug.spotless`, `dev.detekt` и `io.nlopez.compose.rules:detekt`.
