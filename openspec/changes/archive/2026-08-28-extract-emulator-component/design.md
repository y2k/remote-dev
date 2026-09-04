## Context

См. `proposal.md` для мотивации. Сейчас `Worktree.model`, `Worktree.msg`, `Worktree.view`, `Worktree.enter` и `Worktree.update` напрямую содержат состояние и переходы предпросмотра эмуляторов. Проект уже композиционно вкладывает Elm-компоненты через `Components.map` для view и `Cmd.map` для command, но внутри `Worktree` эта граница не проведена.

Существующий контракт `emulator-screenshot-preview` должен сохраниться. `Runtime` отвечает за ADB, а `Server` проверяет serial и отдаёт PNG; эти части не являются Elm-состоянием и не входят в рефакторинг.

## Goals / Non-Goals

**Goals:**
- Дать эмуляторному блоку собственные `model`, `msg`, `initial`, `view`, `enter` и `update`.
- Оставить `Worktree` ответственным только за размещение дочернего view и подъём дочерних messages и commands.
- Сохранить выбор первого эмулятора, проверку выбранного serial, пустое состояние, текст ошибки и image source.

**Non-Goals:**
- Не создавать отдельный экран или отдельный OCaml-файл.
- Не менять ADB-команды, screenshot endpoint, SDUI nodes или Android-клиент.
- Не добавлять обновление списка эмуляторов, новые actions или общую абстракцию для дочерних компонентов.

## Decisions

### Компонент остаётся в `Home_components`

Добавить `module Emulator` перед `Worktree` в `lib/home_components.ml`. Это соответствует текущей организации `New_worktree`, `Worktree` и `Worktrees` и не создаёт отдельный compilation unit ради одного локального потребителя.

Альтернатива с `lib/emulator_component.ml` отклонена: она увеличивает число файлов и публичных модулей, но не даёт изоляции сверх уже доступной границы OCaml module.

### `Emulator` владеет всем Elm-состоянием предпросмотра

`Emulator.model` хранит список `Runtime.emulator`, выбранный serial и ошибку загрузки. `Emulator.msg` содержит результат загрузки и выбор serial. `enter ()` возвращает initial model и command вызова `Runtime.load_emulators`; `update` сохраняет текущую логику выбора первого доступного эмулятора и игнорирования неизвестного serial.

`Emulator.view` строит существующие заголовок, кнопки, пустое состояние, ошибку и `image`. Ошибка ADB отображается внутри эмуляторного блока, чтобы родитель не разбирал дочерние messages или поля модели. Текст и возможность пользоваться остальной частью worktree сохраняются.

Альтернатива с хранением emulator error в `Worktree` отклонена: она заставляет родителя знать внутренние переходы дочернего компонента и оставляет разделение неполным.

### `Worktree` использует обычную TEA-композицию

`Worktree.model` заменяет поля `emulators` и `selected_emulator` одним полем типа `Emulator.model`. `Worktree.msg` заменяет `Loaded_emulators` и `Select_emulator` вариантом `Emulator_msg of Emulator.msg`.

`Worktree.view` поднимает события дочернего view через `Components.map`, а `Worktree.enter` и соответствующая ветка `Worktree.update` поднимают commands через `Cmd.map`. Отдельный универсальный helper не вводится, поскольку в `Worktree` есть только один дочерний компонент.

Derived JSON для кнопок выбора получит дополнительный тег `Emulator_msg`. Это допустимо: Android-клиент трактует backend event как непрозрачный JSON и возвращает его без разбора. Формат SDUI node и HTTP envelope не меняется.

### Проверки следуют новой границе

Переходы загрузки и выбора проверяются непосредственно через `Emulator.update`. Интеграционные проверки `Worktree` подтверждают, что дочерние события подняты до `Home.msg`, выбранный `image` остаётся тем же, а обновления Claude не сбрасывают emulator model.

Новые test helpers и отдельный test executable не нужны; достаточно адаптировать существующие assert-проверки в `test/test_remote_dev.ml`.

## Risks / Trade-offs

- [Дополнительный variant меняет внутреннее JSON-представление emulator button event] -> Проверить round-trip через derived `Home.msg`; Android уже обязан считать event непрозрачным.
- [При переносе можно потерять command загрузки при входе в worktree] -> Проверить, что `Worktree.enter` возвращает поднятый `Emulator.Loaded` после выполнения command.
- [Обновление одной части модели может случайно сбросить другую] -> Проверить сохранение emulator model при Claude messages и сохранение Claude-полей при emulator messages.
- [Параллельный change меняет те же тесты и `home_components.ml`] -> Реализовывать изменения отдельным diff и разрешать только фактические конфликты, не смешивая scope двух changes.

## Migration Plan

1. Выделить `Emulator` и подключить его к `Worktree` через существующие map-функции.
2. Адаптировать проверки моделей, messages и UI-документа.
3. Выполнить `dune fmt` и `dune test`.

Миграции данных и поэтапного выпуска нет. Откат ограничивается изменениями `home_components.ml` и соответствующих проверок.
