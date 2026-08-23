## Why

На экране выбранного worktree уже отображаются две prompt-кнопки, но у них нет backend-событий, поэтому нажатие ничего не делает. Нужен быстрый способ подставить типовой prompt в поле `Command2` перед ручным запуском.

## What Changes

- Сделать `/igor-pending-reviews` и `/igor-restart-mr-tests` интерактивными backend-кнопками на экране выбранного worktree.
- По нажатию подставлять текст соответствующей кнопки в поле `Command2` и возвращать обновлённый UI-документ.
- Явно инициализировать поле `Command2` пустой строкой при открытии worktree.
- Сохранить запуск Claude только по отправке текста из поля `Command2`; нажатие shortcut-кнопки его не запускает.

## Capabilities

### New Capabilities

- `worktree-prompt-shortcuts`: Подстановка предопределённого prompt в поле команды выбранного worktree.

### Modified Capabilities

Нет.

## Impact

- Изменяется backend UI и обработка событий в `lib/home.ml`.
- Дополняются OCaml-проверки UI-документа и переходов состояния в `test/test_remote_dev.ml`.
- Android-клиент, HTTP envelope и зависимости не меняются.
