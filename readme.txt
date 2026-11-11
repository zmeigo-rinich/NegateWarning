NegateWarning 1.2
=================

Короткая инструкция. Подробности - в README.md в корне проекта.
Short guide. For details see README.md in the repository root.

Русский
=======

Предупреждение на экране, пока на игроке висит вражеский
Negate Magic / Suppression Field / Absorption Field.

УСТАНОВКА
  1. Скопировать папку NegateWarning в
     Documents\Elder Scrolls Online\<live|liveeu>\AddOns\
     Папка должна называться именно NegateWarning.
  2. Нужна библиотека LibAddonMenu-2.0.
  3. /reloadui

НАСТРОЙКА
  Баннер появляется и исчезает сам. Чтобы подвинуть: открой настройки
  аддонов, сними Lock, перетащи баннер мышью и верни Lock - позиция
  запомнится для текущего персонажа.

КОМАНДЫ
  /testnegatewarning          справка
  /testnegatewarning show     показать баннер
  /testnegatewarning hide     скрыть баннер
  /testnegatewarning debug    лог эффектов (для поиска ID)

ЕСЛИ НЕ РАБОТАЕТ
  Включи /testnegatewarning debug, встань в поле негата и посмотри
  строки вида:

      NW| change=1 slot=3 id=12345 name='Negate Magic' ... tracked=no

  ID из строки с нужным name добавь в список TRACKED_ABILITIES в начале
  NegateWarning.lua и сделай /reloadui.


English
=======

An on-screen warning while an enemy Negate Magic / Suppression Field /
Absorption Field effect is active on you.

INSTALL
  1. Copy the NegateWarning folder into
     Documents\Elder Scrolls Online\<live|liveeu>\AddOns\
     The folder must be named exactly NegateWarning.
  2. LibAddonMenu-2.0 is required.
  3. /reloadui

SETUP
  The banner shows and hides by itself. To move it: open the addon
  settings, uncheck Lock, drag the banner, check Lock again - the
  position is saved for the current character.

COMMANDS
  /testnegatewarning          help
  /testnegatewarning show     show the banner
  /testnegatewarning hide     hide the banner
  /testnegatewarning debug    log effects (to find IDs)

IF IT DOES NOT WORK
  Run /testnegatewarning debug, step into the negate field and look for
  lines like:

      NW| change=1 slot=3 id=12345 name='Negate Magic' ... tracked=no

  Add the ID from the line with the right name to TRACKED_ABILITIES at
  the top of NegateWarning.lua, then /reloadui.
