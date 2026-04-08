-----------------------------------------------------------------------
-- RE2 DualSense Adaptive Triggers — ГЛАВНЫЙ КОНФИГ
-- Все настройки в одном файле. Редактируй только этот файл.
-----------------------------------------------------------------------
--
-- РЕЖИМЫ ТРИГГЕРА (mode) — пиши словом:
--   "off"         — свободный триггер, без эффекта
--   "resistance"  — постоянное сопротивление (пружина)
--   "weapon"      — упор с сопротивлением (спуск пистолета)
--   "bow"         — пружина + щелчок (тетива, взвод курка)
--   "vibration"   — вибрация (автоматическая стрельба)
--   "click"       — лёгкий щелчок (используется для пустого магазина)
--   "rigid"       — полностью заблокирован
--   "soft"        — мягкий пресет
--   "medium"      — средний пресет
--   "hard"        — жёсткий (= resistance)
--   "very_hard"   — очень жёсткий
--   "hardest"     — максимально жёсткий
--   "semi_auto"   — полуавтоматический спуск
--   "auto_gun"    — автоматический спуск
--   "choppy"      — рывками
--
-- ПАРАМЕТРЫ:
--   start (0-9)     — где начинается эффект (0 = сразу)
--   stop (0-9)      — где заканчивается / точка щелчка
--   force (0-8)     — сила сопротивления (8 = максимум)
--   snap (0-8)      — сила щелчка (только для "bow")
--   intensity (0-255)— сила вибрации (только для "vibration")
--
-- LED: {R, G, B} — цвет подсветки контроллера (0-255)
--
-- r2_threshold (0-255) — порог: игра получит нажатие R2 только
--   когда триггер продавлен на эту долю. 0 = сразу, 180 = ~70% хода
--
-- rapid_fire (число) — сколько выстрелов за одно зажатие R2:
--   nil / не указано = поведение игры по умолчанию (не менять)
--   1 = строго один выстрел за нажатие (полуавтомат)
--   3 = очередь по 3 патрона
--   0 = без ограничений (полный автомат)
-----------------------------------------------------------------------

return {

    ---------------------------------------------------------------
    -- ГЛОБАЛЬНЫЕ НАСТРОЙКИ
    ---------------------------------------------------------------
    settings = {
        default_r2_threshold = 180,    -- порог R2 по умолчанию
        default_l2_threshold = 0,      -- порог L2 (прицел, обычно 0)
        poll_interval = 6,             -- частота опроса (6 ≈ 10 раз/сек)
    },

    ---------------------------------------------------------------
    -- ПРОФИЛИ ТРИГГЕРОВ ПО ТИПУ ОРУЖИЯ
    ---------------------------------------------------------------
    profiles = {

        default = {
            l2 = { mode = "resistance", start = 0, force = 3 },
            r2 = { mode = "off" },
            led = { 0, 0, 0 },
            r2_threshold = 0,
        },

        -- ПИСТОЛЕТЫ: тугой спуск, один выстрел за нажатие
        hg = {
            l2 = { mode = "off"},
            r2 = { mode = "weapon", start = 0, stop = 9, force = 8 },
            led = { 0, 120, 255 },          -- синий
            r2_threshold = 223,
            rapid_fire = 1,                 -- строго полуавтомат
        },

        -- ДРОБОВИК: один выстрел за нажатие
        sg = {
            l2 = { mode = "resistance", start = 0, force = 6 },
            r2 = { mode = "bow", start = 0, stop = 6, force = 8, snap = 8 },
            led = { 255, 40, 40 },          -- красный
            r2_threshold = 200,
            rapid_fire = 1,                 -- один выстрел
        },

        -- МАГНУМ: один выстрел за нажатие
        mag = {
            l2 = { mode = "resistance", start = 0, force = 6 },
            r2 = { mode = "bow", start = 3, stop = 9, force = 8, snap = 8 },
            led = { 180, 0, 255 },          -- фиолетовый
            r2_threshold = 220,
            rapid_fire = 1,                 -- один выстрел
        },

        -- SMG: зажал = стреляет очередью
        smg = {
            l2 = { mode = "off"},
            r2 = { mode = "vibration", start = 6, stop = 9, intensity = 20 },
            led = { 255, 140, 0 },          -- оранжевый
            r2_threshold = 200,
            -- rapid_fire не указан = поведение по умолчанию (автомат)
        },

        -- ГРАНАТОМЁТ: тяжёлое оружие, плавный спуск
        gl = {
            l2 = { mode = "resistance", start = 0, force = 8 },
            r2 = { mode = "resistance", start = 0, force = 4 },
            led = { 0, 255, 0 },            -- зелёный
            r2_threshold = 180,
        },

        -- СПЕЦОРУЖИЕ (Sparkshot, Огнемёт)
        special = {
            l2 = { mode = "resistance", start = 0, force = 4 },
            r2 = { mode = "weapon", start = 2, stop = 8, force = 5 },
            led = { 0, 255, 255 },          -- голубой
            r2_threshold = 150,
        },

        -- НОЖ: минимальное сопротивление
        knife = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "off" },
            led = { 255, 255, 255 },        -- белый
            r2_threshold = 0,
        },

        -- ГРАНАТЫ: тяжёлый бросок
        grenade = {
            l2 = { mode = "resistance", start = 0, force = 8 },
            r2 = { mode = "resistance", start = 0, force = 4 },
            led = { 0, 255, 0 },            -- зелёный
            r2_threshold = 100,
        },

        -- НЕТ ОРУЖИЯ
        none = {
            l2 = { mode = "off" },
            r2 = { mode = "off" },
            led = { 0, 0, 0 },
            r2_threshold = 0,
        },
    },

    ---------------------------------------------------------------
    -- ТАБЛИЦА ОРУЖИЯ RE2
    -- [ID] = { name = "Название", type = "тип_из_profiles" }
    --
    -- Чтобы добавить: допиши строку, type = ключ из profiles
    ---------------------------------------------------------------
    weapons = {
        -- Пистолеты
        [1]   = { name = "Matilda",                 type = "hg" },
        [2]   = { name = "M19",                     type = "hg" },
        [3]   = { name = "JMB Hp3",                 type = "hg" },
        [4]   = { name = "Quickdraw Army",          type = "hg" },
        [7]   = { name = "MUP",                     type = "hg" },
        [8]   = { name = "Broom Hc",                type = "hg" },
        [9]   = { name = "SLS 60",                  type = "hg" },
        [82]  = { name = "Samurai Edge (Infinite)", type = "hg" },
        [83]  = { name = "Samurai Edge (Chris)",    type = "hg" },
        [84]  = { name = "Samurai Edge (Jill)",     type = "hg" },
        [85]  = { name = "Samurai Edge (Albert)",   type = "hg" },

        -- Дробовик
        [11]  = { name = "W-870",                   type = "sg" },

        -- SMG
        [21]  = { name = "MQ 11",                   type = "smg" },
        [23]  = { name = "LE 5",                    type = "smg" },

        -- Магнум
        [31]  = { name = "Lightning Hawk",          type = "mag" },

        -- Гранатомёт
        [42]  = { name = "GM 79",                   type = "gl" },

        -- Спецоружие
        [41]  = { name = "EMF Visualizer",          type = "none" },
        [43]  = { name = "Chemical Flamethrower",   type = "special" },
        [44]  = { name = "Spark Shot",              type = "special" },

        -- Тяжёлое оружие
        [45]  = { name = "ATM-4",                   type = "gl" },
        [49]  = { name = "Anti-Tank Rocket",        type = "gl" },
        [50]  = { name = "Minigun",                 type = "smg" },

        -- Нож
        [46]  = { name = "Combat Knife",            type = "knife" },
        [47]  = { name = "Combat Knife (Infinite)", type = "knife" },

        -- Гранаты
        [65]  = { name = "Hand Grenade",            type = "grenade" },
        [66]  = { name = "Flash Grenade",           type = "grenade" },

        -- Infinite варианты
        [222] = { name = "ATM-4 (Infinite)",        type = "gl" },
        [242] = { name = "Anti-Tank Rocket (Inf)",  type = "gl" },
        [252] = { name = "Minigun (Infinite)",      type = "smg" },
    },
}
