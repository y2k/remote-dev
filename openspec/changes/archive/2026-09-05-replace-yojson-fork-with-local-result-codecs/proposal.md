## Why

Проект зависит от собственного Git fork `ppx_deriving_yojson` только ради встроенной поддержки стандартного `result`. Официальный `ppx_deriving_yojson` уже позволяет предоставить эти codec-и через соглашение имён, поэтому небольшой локальный модуль устраняет сопровождение fork без изменения JSON-протокола.

## What Changes

- Заменить Git pin `y2k/ppx_deriving_yojson` на официальный release `ppx_deriving_yojson` из package repository.
- Добавить отдельный локальный модуль с `result_to_yojson` и `result_of_yojson` и импортировать его там, где PPX выводит codec-и для сообщений с `result`.
- Сохранить представление `Ok value` как `["Ok", value]`, а `Error value` как `["Error", value]`.
- Восстановить прямые проверки ручных codec-ов и оставить существующие проверки message round-trip и malformed result input.
- Перегенерировать committed `dune.lock` стандартной командой Dune.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `dune-package-management`: заменить требование разрешать fork на требование использовать официальный release `ppx_deriving_yojson` без Git pin.

## Impact

- Затрагиваются `dune-project`, `dune.lock`, новый модуль в `lib/`, `lib/home_components.ml` и `test/test_remote_dev.ml`.
- Публичные функции message codec-ов и JSON wire format не меняются.
- Новые зависимости не добавляются; существующее имя PPX и stanza `(pps ppx_deriving_yojson ...)` сохраняются.
