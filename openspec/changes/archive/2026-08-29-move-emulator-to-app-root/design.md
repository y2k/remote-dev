## Context

См. `proposal.md` и delta spec. Сейчас `Emulator` уже является самостоятельным TEA-компонентом, но `Worktree.model` владеет его model, `Worktree.msg` поднимает его messages, `Worktree.enter` запускает загрузку, а `Worktree.view` создаёт weighted row `[2, 1]`.

Корневой `Home` владеет только текущим `screen`; его `view` выбирает один page view, а переходы создают новую page model. `Cmd` представляет не более одной команды, но `Server.initialize` и dispatch уже рекурсивно выполняют цепочку commands до завершения.

## Goals / Non-Goals

**Goals:**
- Перенести TEA ownership эмулятора в `Home`, сохранив существующий самостоятельный `Emulator` без изменений его model/view/update.
- Иметь ровно один emulator model, который переживает все переходы между page screens.
- Использовать существующий weighted `row` как единственную корневую раскладку приложения.
- Завершать начальную загрузку эмуляторов и worktree до начала обслуживания HTTP-запросов.

**Non-Goals:**
- Не добавлять ручное обновление списка эмуляторов, фоновое обнаружение устройств или сохранение выбора между перезапусками backend.
- Не добавлять adaptive breakpoint, вертикальный fallback или схлопывание emulator pane на узком экране и в пустом или ошибочном состоянии.
- Не менять Android renderer, SDUI node shapes, screenshot endpoint или ADB runtime.
- Не вводить `Cmd.batch`, очередь commands или общий framework для нескольких root-компонентов.
- Не переносить модуль `Emulator` в отдельный OCaml-файл: смена владельца не требует нового compilation unit.

## Decisions

### `Home.state` владеет emulator model

`Home.state` будет содержать `{ screen; emulator }`, а `Home.msg` получит `Emulator_msg of Emulator.msg` для событий из постоянной правой панели. `Home.view` сначала построит mapped view любого текущего screen, затем вернёт `row ~weights:[2; 1]` из page view и `Components.map emulator_msg (Emulator.view emulator)`. Поскольку split находится выше разбора вариантов `screen`, будущие root screens автоматически получат ту же панель и фиксированную пропорцию независимо от viewport и emulator state.

Это оставляет page modules независимыми от глобальной панели и повторно использует уже работающий layout contract. Передача emulator model в каждый вариант `screen` отклонена: она дублировала бы состояние и потребовала бы переносить его при каждом переходе.

### Инициализация использует существующую command chain

`Home.init` создаст initial emulator model и запустит `Emulator.enter` через отдельный внутренний root message для bootstrap. Обработка результата обновит emulator model и вернёт command из `Worktrees.enter`. Существующий `Server.initialize` выполнит первый command, передаст message в `Home.dispatch`, а тот выполнит следующий command до `Cmd.none`.

Отдельный bootstrap message отделяет внутренний результат стартовой загрузки от обычного `Emulator_msg`, публикуемого в UI для `Select`. Расширение `Cmd` операцией batch отклонено: нужны только две одноразовые последовательные загрузки, а текущая command chain уже покрывает этот случай. Ограничение этой минимальной схемы: bootstrap предполагает, что обработка `Emulator.Loaded` не создаёт следующую emulator command; если это изменится, потребуется `Cmd.batch` или явная orchestration нескольких commands.

### Навигация меняет только `screen`

Helpers входа и page update будут сохранять поле `emulator` существующего root state. `Back`, выбор worktree, открытие/завершение создания worktree и page messages изменяют только `screen`; `Emulator_msg` изменяет только `emulator`. Поэтому выбор устройства не сбрасывается и повторный `Emulator.enter` при входе в worktree не запускается.

Альтернатива передавать emulator model через параметры каждого navigation helper отклонена там, где достаточно record update: сохранение root-поля должно быть структурно очевидным и не зависеть от конкретного перехода.

Глобальный выбор хранится только в `Home.state`: restart создаёт `Emulator.initial`, повторно загружает список и выбирает первое доступное устройство. Если выбранное устройство останавливается после startup, model и список не меняются; screenshot endpoint возвращает ошибку, а Android сохраняет окружающий UI. Автоматическая очистка выбора отклонена, поскольку без повторного discovery backend не знает устойчивого нового списка.

### `Worktree` снова становится обычным page component

Из `Worktree.model` удаляется поле `emulator`, из `Worktree.msg` — `Emulator_msg`, а из `enter` и `update` — child command routing. `Worktree.view` возвращает только прежнюю левую `column` с path, output, shortcuts и command input; веса и emulator view задаются один раз в `Home.view` для любого screen.

Модуль `Emulator` остаётся в `home_components.ml`: он по-прежнему самостоятельный компонент и теперь имеет одного потребителя на root-уровне. Перемещение файла не даёт поведенческой пользы и увеличивает diff.

### Проверки следуют новой границе ownership

OCaml-проверки должны подтвердить root weighted row для `Worktrees`, `New_worktree` и `Worktree`, прямой `Home.Emulator_msg` в правой панели и отсутствие emulator state/event внутри `Worktree`. Отдельная проверка command chain должна подтвердить загрузку эмуляторов, последующую загрузку worktree и сохранение выбранного emulator при навигации и Claude updates.

Android-проверки не меняются: клиент уже рекурсивно рендерит weighted row и считает backend events непрозрачными. README обновит описание момента загрузки и постоянной панели.

## Risks / Trade-offs

- [Последовательная начальная загрузка немного увеличивает startup time] -> Обе локальные команды и сейчас выполняются до полезной работы; не добавлять command concurrency без измеренной задержки.
- [Ошибка загрузки эмуляторов может помешать запуску загрузки worktree] -> Bootstrap обрабатывает и `Ok`, и `Error`, сохраняет emulator error и в обоих случаях возвращает `Worktrees.enter` command.
- [Навигационный переход случайно пересоздаст root state] -> Строить переходы через сохранение текущего `emulator` и проверить выбор устройства до и после каждого типа навигации.
- [Старые emulator button events содержат дополнительный `Worktree_msg` wrapper] -> UI публикует новые прямые root events; Android не хранит события после замены документа и трактует их непрозрачно.

## Migration Plan

1. Перенести emulator ownership и startup command chain в `Home`.
2. Удалить emulator composition из `Worktree` и обновить root/page проверки.
3. Обновить README, выполнить `dune fmt` и `dune test`.
4. Выпустить только backend: Android protocol не меняется. Для rollback вернуть emulator model и routing в `Worktree`; сохранённых данных и миграций нет.
