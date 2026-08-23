## Why

IP-адрес backend сейчас дублируется в Kotlin-коде и Android network security config, поэтому смена сети требует несогласованных правок. Сборка должна получать адрес backend из единой локальной настройки и не выпускать APK без заданного адреса.

## What Changes

- Android-сборка получает `backendHost` из `local.properties`; `-PbackendHost` разово переопределяет локальное значение.
- Если `backendHost` не задан ни в одном источнике, Android-сборка завершается с понятной ошибкой.
- Формировать URL backend для Android-клиента из `backendHost` во время сборки вместо хранения IP в исходном Kotlin-коде.
- Формировать разрешение cleartext HTTP для того же хоста во время сборки вместо статического XML с IP.
- Документировать настройку `backendHost` в `local.properties` и разовый CLI override.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `android-backend-driven-ui`: Настройка origin development backend и разрешение cleartext HTTP должны использовать обязательный build-time хост вместо фиксированного IP.

## Impact

- Изменяются Android Gradle-конфигурация, `MainActivity.kt`, network security config и документация запуска Android-сборки.
- Новые зависимости, runtime-настройка и изменение протокола backend не требуются.
