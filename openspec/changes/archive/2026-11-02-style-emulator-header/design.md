# Design

## Context

Мотивация — `proposal.md`. После проверки первой реализации пользователь отклонил новый базовый компонент и выбрал композицию существующих контейнеров с минимальным расширением кнопок. Внешний вид и поведение из согласованных требований сохраняются.

`row` уже поддерживает weights, horizontalScroll, padding и gap. `column` поддерживает stretch и фон. `Emulator` остаётся TEA-компонентом на backend с прежними model/msg/update; Android не получает доменных данных об устройствах.

## Goals / Non-Goals

**Goals:** собрать всю геометрию шапки на backend; переиспользовать компактные и icon-only кнопки в любом экране; сохранить прежнюю кнопку при отсутствии новых полей.

**Non-Goals:** новый тип узла, универсальный toolbar/selection-strip, новые действия эмулятора, изменения preview, автоматический выбор или автопрокрутка.

## Decisions

### Approaches

Пользователь выбрал расширение `button` вместо обобщения шапки в `selection_strip`. Удаляем `emulator_header`, запись устройства в протоколе, её parser/mapping и `EmulatorHeaderContent.kt`. Базовые row/column не должны распознавать названия экранов или событий.

### Свойства button

- Необязательный `style`: `compact` либо `icon`; отсутствие сохраняет обычную кнопку.
- `selected`: необязательный boolean только у `compact`. Наличие включает selectable-семантику; отсутствие даёт обычное действие в компактном оформлении. Состояние определяется backend, без optimistic update.
- `icon`: обязательный для `style: icon`, сейчас поддерживает только `refresh`; у других вариантов запрещён. `label` служит описанием доступности и не рисуется. Иконка не определяет событие: `event` остаётся непрозрачным.
- Null, неверные типы, неизвестные значения и несовместимые сочетания отвергают документ. Прежняя опциональность event сохраняется.
- Compact: радиус 8, border 1 outlineVariant, min target 48, padding 8/4, естественная ширина однострочного текста, system 12/18 sp, zero letter spacing. Selected использует surfaceContainerHigh/onSurface/500, остальные surfaceContainer/onSurfaceVariant/400.
- Icon: target 48, rotate-right 18, прозрачный фон, onSurfaceVariant, clipping 8. Native ripple/focus и общий eventInProgress.

Строка с непосредственными дочерними кнопками с `selected` предоставляет selectable-group semantics. Это общее свойство композиции выбора, без доменных проверок числа выбранных устройств. За выбор единственного serial отвечает существующий backend.

### Композиция на backend

Чистая локальная функция шапки внутри `Emulator` возвращает column с gap 0 и stretch:

1. Row: background surfaceContainerLow, padding horizontal 12/vertical 4, gap 8, weights [1;0].
2. В первом слоте row horizontalScroll=true, gap 4 с compact-кнопками, label=name и selected по serial.
3. Второй слот — icon-кнопка refresh с label `Обновить список эмуляторов` и существующим Refresh event.
4. Под строкой — пустой row с background outlineVariant и bottom padding 1: разделитель высотой 1 dp. Нового примитива divider не требуется.

Для фона расширяется существующий enum theme roles значением surfaceContainerLow. Ошибка над шапкой, preview под ней, внешний padding 8, surface и 2:1 allocation сохраняются. Scroll state принадлежит существующему row и сохраняется при замене документа с прежней структурой.

### Спецификации и проверки

Заменить специализированный wire-контракт требованиями общих свойств button и расширением theme roles. Требования к внешнему виду шапки сохраняются. Старые проверки 60/60 относятся к отклонённой реализации; после переделки заново проверить parser, композицию, события, темы, масштаб, overflow и preview. Контракт `emulator_header` теперь должен отвергаться как неизвестный.

## Risks / Trade-offs

- Расширение общего button может затронуть прежние кнопки → сохранить defaults и проверить их прежний wire/renderer.
- Текст в горизонтальном scroll получает unbounded width → использовать конечную intrinsic-ширину подписи.
- Узкая правая треть → проверить pinned Refresh и прокрутку при 400 dp общей ширины и масштабе 2.0.
- Нет запущенных эмуляторов → populated/error состояния проверять fixtures, не запускать другие устройства.

## Migration Plan

Установить совместимый APK перед перезапуском backend. Выполнить host-checks независимо от adb, полный configured-device suite и визуальную проверку. Сохранить новые скриншоты отдельно, восстановить исходные theme/font scale. Откат — совместимая пара APK/backend, миграций данных нет.
