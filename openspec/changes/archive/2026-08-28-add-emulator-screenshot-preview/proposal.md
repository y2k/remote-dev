## Why

При удалённой работе с выбранным worktree разработчик не видит состояние локально запущенных Android-эмуляторов. Нужен компактный предпросмотр, который позволяет выбрать работающий эмулятор и наблюдать его экран без постоянной ручной съёмки.

## What Changes

- Показать на экране выбранного worktree список работающих Android-эмуляторов, выбор одного из них и его снимок экрана.
- Обновлять снимок выбранного эмулятора раз в три секунды, не перезагружая весь backend-defined UI-документ.
- Добавить минимальный SDUI node `image` для изображения с backend-relative `src` и текстовой меткой.
- Дать backend PNG endpoint для снимка выбранного подключённого эмулятора; снимок создаётся по запросу через локальный ADB.
- Показывать понятное состояние, когда работающих эмуляторов нет или снимок недоступен.

## Capabilities

### New Capabilities
- `emulator-screenshot-preview`: Выбор работающего Android-эмулятора и периодический просмотр его снимка на экране worktree.

### Modified Capabilities
- `android-backend-driven-ui`: Клиент принимает и отображает SDUI node `image` наряду с существующими поддерживаемыми node.

## Impact

- Затрагиваются `lib/runtime.ml`, `lib/server.ml`, `lib/home.ml`, `lib/home_components.ml` и `lib/components.ml`.
- Затрагиваются Android parser, Compose renderer и contract tests.
- Появляется локальный HTTP PNG endpoint; новые зависимости не требуются.
