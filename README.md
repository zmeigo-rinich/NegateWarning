# NegateWarning

Аддон для **The Elder Scrolls Online**: выводит на экран предупреждение,
пока на игроке висит вражеский **Negate Magic / Suppression Field /
Absorption Field**.

An **Elder Scrolls Online** addon: shows an on-screen warning while an enemy
**Negate Magic / Suppression Field / Absorption Field** effect is active on
the player.

[Русский](#русский) · [English](#english)

---

## Русский

### Что это

Пока на игроке активен хотя бы один отслеживаемый эффект, на экране висит
предупреждение с текстом «Enemy Negate!!!». Оно ничего не перекрывает и не
требует действий: появилось при наложении — исчезло после спада.

### Требования

- The Elder Scrolls Online (PC/Mac).
- Библиотека [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)
  — без неё аддон падает при создании панели настроек.

### Установка

1. Скачать архив из Releases и распаковать в
   `Documents\Elder Scrolls Online\<live|liveeu>\AddOns\`.
   Внутри архива папка `NegateWarning`. Она должна называться **именно**
   так — от этого зависит путь к текстуре.
2. Убедиться, что `LibAddonMenu-2.0` лежит в `AddOns` и включён.
3. `/reloadui`.

Одновременно можно держать только одну версию аддона: имя у всех одно.

### Использование

Баннер появляется сам в момент наложения эффекта и исчезает через ~0,1 с
после его спада. Настраивать ничего не нужно.

Если баннер мешает — в панели настроек аддонов снять `Lock`, перетащить его
мышью и вернуть `Lock`. Позиция сохраняется для текущего персонажа на текущем
мегасервере. По умолчанию баннер смещён на 420 px ниже центра, чтобы не
перекрываться с AgonyWarning.

### Команды

| Команда | Действие |
|---|---|
| `/testnegatewarning` | справка и список отслеживаемых ID |
| `/testnegatewarning show` | показать баннер до команды `hide` |
| `/testnegatewarning hide` | скрыть и сбросить состояние |
| `/testnegatewarning debug` | лог эффектов и combat-событий по игроку |

### Как это работает

**Основной источник — `EVENT_EFFECT_CHANGED` по `unitTag == "player"`.**

- `GAINED` / `UPDATED` для отслеживаемого `abilityId` → запись в
  `ActiveEffects[effectSlot]`, баннер показан.
- `FADED` → запись удаляется **по `effectSlot`**, и только при расхождении
  слота — по `abilityId`. Так сделано потому, что событие спада может прийти
  с другим или нулевым ID.
- Пока в таблице есть хотя бы одна запись, баннер виден.

**Второй механизм — таймер по `endTime`.** После каждого изменения состояния
ставится `zo_callLater` на самый поздний известный `endTime` (+100 мс запаса).
Это страховка на случай, если `FADED` не придёт. Генерация
(`HideGeneration`) отменяет устаревшие таймеры.

**Антидребезг.** При исчезновении последнего эффекта баннер скрывается не
сразу, а через `HIDE_DELAY = 100` мс: повторное наложение не заставляет его
мигать.

**Сброс.** При смерти, загрузке и переходе между зонами состояние
очищается без задержки.

#### Ловушка с `endTime`

`EVENT_EFFECT_CHANGED` отдаёт `endTime` **в секундах**, а
`GetGameTimeMilliseconds()` — **в миллисекундах**. Именно из-за прямого
сравнения этих величин версии 1.0 и 1.1-beta «не работали»: эффект считался
уже истёкшим и вычищался при первом же `RefreshDisplay()`, баннер держался
только на событии `FADED`.

Правильно:

```lua
endTime = (endTime and endTime > 0) and (endTime * 1000) or 0,
```

#### Отслеживаемые ID

```lua
local TRACKED_ABILITIES = {
	{ id = 29824, label = "Negate Magic" },
	{ id = 47160, label = "Suppression Field" },
	{ id = 47168, label = "Absorption Field" },
	{ id = 51894, label = "NPC Negate Magic" },
}
```

Это ID **наложенного на игрока эффекта**, а не ID каста — они различаются.
`label` ни на что не влияет, только для лога.

Если после патча баннер перестал появляться: включить `debug`, встать в поле
негата и найти в чате строку

```
NW| change=1 slot=3 id=12345 name='Negate Magic' buffType=2 end=... tracked=no
```

Добавить `id` в `TRACKED_ABILITIES` с понятным `label` и сделать `/reloadui`.

#### Аварийный режим

Если `EVENT_EFFECT_CHANGED` для нужного эффекта вообще не приходит, можно
включить `USE_COMBAT_EVENT_FALLBACK = true`. Тогда баннер показывается по
`EVENT_COMBAT_EVENT` на фиксированные 10 секунд. Минус — возможны ложные
срабатывания. По умолчанию выключено.

### Константы

Всё оформление — в начале `NegateWarning.lua`:

| Константа | Значение | Смысл |
|---|---|---|
| `TEXT_WARNING` | `Enemy Negate!!!` | текст баннера, локализации нет |
| `FONT` | `$(MEDIUM_FONT)\|$(KB_48)\|thick-outline` | шрифт с чёрной обводкой |
| `TEXT_COLOR` | `{1, 0.3, 0.3, 1}` | красный |
| `ICON_SIZE` | `200` | размер картинки на экране, px |
| `BAR_WIDTH` / `BAR_HEIGHT` | `640` / `200` | только раскладка, фона нет |
| `HIDE_DELAY` | `100` | мс антидребезга |
| `END_TIME_GRACE` | `100` | мс запаса после конца эффекта |
| `BAR_DEFAULT_X` / `Y` | `0` / `-420` | смещение от центра экрана |

### Текстура

- Файл: `NegateWarning/negatecat.dds`, путь задан относительно `AddOns`.
- Формат: DDS DXT5 (BC3) с альфой, 256×256, с мипмапами.
- Исходник: PNG 368×368, обрезан по содержимому до 345×333 и
  отмасштабирован в 256×256.

Замена: подготовить PNG с прозрачным фоном, конвертировать в DDS DXT5,
размер — степень двойки, положить как `negatecat.dds`, `/reloadui`.
Если текстура не загрузилась, ESO молча не покажет картинку, но текст
продолжит работать.

### Ограничения

- ID эффекта может отличаться от ID каста; после патча список надо проверять.
- Часть эффектов не попадает в `EVENT_EFFECT_CHANGED` — тогда нужен
  combat-фоллбэк.
- При `endTime == 0` (бессрочный эффект) баннер висит до `FADED`.
- На очень светлой местности красный текст читается хуже — плашки нет
  намеренно.
- Тексты фиксированы, локализации нет.
- Позиция хранится отдельно для персонажа и мегасервера и не связана
  с AgonyWarning.

### Файлы

```
NegateWarning.lua   логика аддона
NegateWarning.txt   манифест
readme.txt          короткая инструкция (RU/EN), её видно в игре
negatecat.dds       текстура баннера
```

Готовые сборки — в Releases.

### История версий

| Версия | Что |
|---|---|
| 1.0 | первая версия: фиолетовая плашка, в игре не работала |
| 1.1-beta | изменено оформление баннера; не работала из-за `endTime` |
| 1.1-beta (verified) | исправлены `endTime`, список ID, шрифт и задержка; работала в игре |
| 1.2 | проверенная сборка + отдельный label для NPC Negate Magic (`51894`) |

---

## English

### What it is

While at least one tracked effect is active on the player, a warning with the
text `Enemy Negate!!!` is shown. It covers nothing important and needs no
action: it appears when the effect is applied and goes away when it fades.

### Requirements

- The Elder Scrolls Online (PC/Mac).
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)
  — without it the addon fails when creating the settings panel.

### Installation

1. Download the archive from Releases and unpack it into
   `Documents\Elder Scrolls Online\<live|liveeu>\AddOns\`.
   It contains the `NegateWarning` folder, which must keep **exactly** that
   name — the texture path depends on it.
2. Make sure `LibAddonMenu-2.0` is in `AddOns` and enabled.
3. `/reloadui`.

Only one version of the addon can be installed at a time: they share the
same name.

### Usage

The banner appears on its own when the effect is applied and disappears about
0.1 s after it fades. No configuration is needed.

To move it: open the addon settings, uncheck `Lock`, drag the banner with the
mouse and check `Lock` again. The position is saved per character and
megaserver. By default the banner sits 420 px below the screen center so it
does not overlap AgonyWarning.

### Commands

| Command | Action |
|---|---|
| `/testnegatewarning` | help and the tracked ID list |
| `/testnegatewarning show` | show the banner until `hide` |
| `/testnegatewarning hide` | hide and reset the state |
| `/testnegatewarning debug` | log effects and combat events for the player |

### How it works

**The main source is `EVENT_EFFECT_CHANGED` for `unitTag == "player"`.**

- `GAINED` / `UPDATED` for a tracked `abilityId` → an entry in
  `ActiveEffects[effectSlot]`, the banner is shown.
- `FADED` → the entry is removed **by `effectSlot`**, and only on a slot
  mismatch by `abilityId`. The fade event may report a different or zero
  ability ID.
- While the table has at least one entry, the banner is visible.

**The second mechanism is an `endTime` timer.** After every state change a
`zo_callLater` is scheduled for the latest known `endTime` (+100 ms grace).
It is a safety net in case `FADED` never arrives. The generation counter
(`HideGeneration`) cancels stale timers.

**Anti-flicker.** When the last effect disappears, the banner is hidden after
`HIDE_DELAY = 100` ms, so a re-applied effect does not make it blink.

**Reset.** On death, loading screen and zone change the state is cleared
immediately.

#### The `endTime` trap

`EVENT_EFFECT_CHANGED` reports `endTime` **in seconds**, while
`GetGameTimeMilliseconds()` returns **milliseconds**. Comparing them directly
is why 1.0 and 1.1-beta "did not work": the effect was considered already
expired and dropped on the first `RefreshDisplay()`, so the banner only
survived on the `FADED` event.

Correct:

```lua
endTime = (endTime and endTime > 0) and (endTime * 1000) or 0,
```

#### Tracked IDs

```lua
local TRACKED_ABILITIES = {
	{ id = 29824, label = "Negate Magic" },
	{ id = 47160, label = "Suppression Field" },
	{ id = 47168, label = "Absorption Field" },
	{ id = 51894, label = "NPC Negate Magic" },
}
```

These are the IDs of the **effect applied to the player**, not the cast IDs —
the two differ. `label` is never used for matching, only for the log.

If the banner stops appearing after a patch: enable `debug`, step into the
negate field and find the chat line

```
NW| change=1 slot=3 id=12345 name='Negate Magic' buffType=2 end=... tracked=no
```

Add the `id` to `TRACKED_ABILITIES` with a clear `label`, then `/reloadui`.

#### Emergency mode

If `EVENT_EFFECT_CHANGED` never fires for the effect, set
`USE_COMBAT_EVENT_FALLBACK = true`. The banner is then shown from
`EVENT_COMBAT_EVENT` for a fixed 10 seconds. Downside: possible false
positives. Off by default.

### Constants

All appearance settings live at the top of `NegateWarning.lua`:

| Constant | Value | Meaning |
|---|---|---|
| `TEXT_WARNING` | `Enemy Negate!!!` | banner text, no localization |
| `FONT` | `$(MEDIUM_FONT)\|$(KB_48)\|thick-outline` | font with black outline |
| `TEXT_COLOR` | `{1, 0.3, 0.3, 1}` | red |
| `ICON_SIZE` | `200` | on-screen picture size, px |
| `BAR_WIDTH` / `BAR_HEIGHT` | `640` / `200` | layout only, no background |
| `HIDE_DELAY` | `100` | anti-flicker delay, ms |
| `END_TIME_GRACE` | `100` | grace after the effect end, ms |
| `BAR_DEFAULT_X` / `Y` | `0` / `-420` | offset from the screen center |

### Texture

- File: `NegateWarning/negatecat.dds`, the path is relative to `AddOns`.
- Format: DDS DXT5 (BC3) with alpha, 256×256, with mipmaps.
- Source: a 368×368 PNG, cropped to content (345×333) and scaled to
  256×256.

To replace: prepare a PNG with a transparent background, convert to DDS DXT5,
size as a power of two, save as `negatecat.dds`, `/reloadui`. If the texture
fails to load, ESO silently skips the picture but the text keeps working.

### Limitations

- The effect ID may differ from the cast ID; the list needs checking after a
  patch.
- Some effects are not exposed through `EVENT_EFFECT_CHANGED` — the combat
  fallback is needed then.
- With `endTime == 0` (permanent effect) the banner stays until `FADED`.
- On very bright terrain the red text is harder to read — no plate by design.
- The texts are fixed, there is no localization.
- The position is stored per character and megaserver and is independent of
  AgonyWarning.

### Files

```
NegateWarning.lua   addon logic
NegateWarning.txt   manifest
readme.txt          short guide (RU/EN), shown in game
negatecat.dds       banner texture
```

Ready-to-install builds are attached to Releases.

### Version history

| Version | What |
|---|---|
| 1.0 | first release: purple plate, did not work in game |
| 1.1-beta | banner appearance changed; broken due to `endTime` |
| 1.1-beta (verified) | fixed `endTime`, ID list, font and delay; worked in game |
| 1.2 | verified build + a separate label for NPC Negate Magic (`51894`) |

---

Автор / Author: **Zmeigo Rinich**
