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
-- r2_threshold (0-255) — порог нажатия R2. 0 = сразу, 180 = ~70% хода
--
-- kick (таблица) — эффект отдачи при выстреле (опционально)
--   Такой же формат как основной профиль (r2, led, и т.д.)
--   duration — кадров без выстрела до восстановления основного профиля
--   Если kick не указан — выстрел без отдачи
--
-- empty (таблица) — профиль для пустого магазина (опционально)
--   Переопределяет поля основного профиля когда ammo == 0
--
-- rapid_fire — 1 = один выстрел за нажатие, 0/nil = без ограничений
-----------------------------------------------------------------------

return {

    ---------------------------------------------------------------
    -- ГЛОБАЛЬНЫЕ НАСТРОЙКИ
    ---------------------------------------------------------------
    settings = {
        default_r2_threshold = 180,
        default_l2_threshold = 0,
        poll_interval = 6,
    },

    ---------------------------------------------------------------
    -- ПРОФИЛИ ТРИГГЕРОВ ПО ТИПУ ОРУЖИЯ
    ---------------------------------------------------------------
    profiles = {

        default = {
            l2 = { mode = "off" },
            r2 = { mode = "off" },
            led = { 0, 0, 0 },
            r2_threshold = 0,
        },

        -- ПИСТОЛЕТЫ (Matilda, M19, JMB, SLS, Samurai Edge)
        -- Классический спуск с упором, лёгкая отдача
        hg = {
            l2 = { mode = "resistance", start = 0, force = 0 },
            r2 = { mode = "weapon", start = 0, stop = 7, force = 6 },
            led = { 0, 120, 255 },          -- синий
            r2_threshold = 200,
            rapid_fire = 1,
            kick = {
                l2 = { mode = "vibration", intensity = 20 },
                r2 = { mode = "vibration", intensity = 50 },
                duration = 3,
            },
            empty = {
                r2 = { mode = "click", start = 0, force = 4 },
                led = { 100, 100, 100 },
            },
        },

        -- ДРОБОВИК (W-870)
        -- Тугая помпа, мощный щелчок, сильная отдача
        sg = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "bow", start = 0, stop = 6, force = 6, snap = 5 },
            led = { 255, 40, 40 },          -- красный
            r2_threshold = 190,
            rapid_fire = 1,
            kick = {
                l2 = { mode = "vibration", intensity = 50 },
                r2 = { mode = "vibration", intensity = 100 },
                duration = 5,
            },
            empty = {
                r2 = { mode = "click", start = 0, force = 4 },
                led = { 50, 0, 0 },
            },
        },

        -- МАГНУМ (Lightning Hawk)
        -- Тяжёлый взвод курка, мощная отдача
        mag = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "bow", start = 2, stop = 7, force = 7, snap = 6 },
            led = { 180, 0, 255 },          -- фиолетовый
            r2_threshold = 200,
            rapid_fire = 1,
            kick = {
                l2 = { mode = "vibration", intensity = 50 },
                r2 = { mode = "vibration", intensity = 100 },
                duration = 4,
            },
            empty = {
                r2 = { mode = "click", start = 0, force = 4 },
                led = { 60, 0, 80 },
            },
        },

        -- MQ 11 — помедленнее LE 5
        mq11 = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "bow", start = 2, stop = 5, force = 4, snap = 6 },
            led = { 255, 140, 0 },          -- оранжевый
            r2_threshold = 170,
            kick = {
                l2 = { mode = "vibration", intensity = 6 },
                r2 = { mode = "vibration", intensity = 15 },
                duration = 6,
            },
            empty = {
                r2 = { mode = "off" },
                led = { 80, 50, 0 },
            },
        },

        -- LE 5 — быстрее MQ 11
        le5 = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "bow", start = 2, stop = 5, force = 4, snap = 6 },
            led = { 200, 160, 0 },          -- тёмно-жёлтый
            r2_threshold = 170,
            kick = {
                l2 = { mode = "vibration", intensity = 10 },
                r2 = { mode = "vibration", intensity = 25 },
                duration = 6,
            },
            empty = {
                r2 = { mode = "off" },
                led = { 80, 60, 0 },
            },
        },

        -- MINIGUN
        -- Лёгкий спуск (кнопка), постоянная средняя тряска
        minigun = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "resistance", start = 0, force = 2 },
            led = { 255, 200, 0 },          -- жёлтый
            r2_threshold = 100,
            kick = {
                l2 = { mode = "vibration", intensity = 15 },
                r2 = { mode = "vibration", intensity = 40 },
                duration = 30,              -- мотор "дышит" каждые 30 кадров
            },
        },

        -- ГРАНАТОМЁТ (GM 79)
        -- Плавный тяжёлый спуск, сильная отдача
        gl = {
            l2 = { mode = "resistance", start = 0, force = 6 },
            r2 = { mode = "resistance", start = 0, force = 5 },
            led = { 0, 255, 0 },            -- зелёный
            r2_threshold = 180,
            rapid_fire = 1,
            kick = {
                l2 = { mode = "vibration", intensity = 50 },
                r2 = { mode = "vibration", intensity = 100 },
                led = { 255, 255, 0 },      -- жёлтая вспышка
                duration = 4,
            },
        },

        -- РАКЕТНИЦА (ATM-4, Anti-Tank Rocket)
        -- Тяжёлое сопротивление, максимальная отдача
        rocket = {
            l2 = { mode = "resistance", start = 0, force = 6 },
            r2 = { mode = "resistance", start = 0, force = 6 },
            led = { 255, 60, 0 },           -- красно-оранжевый
            r2_threshold = 200,
            rapid_fire = 1,
            kick = {
                l2 = { mode = "vibration", intensity = 70 },
                r2 = { mode = "vibration", intensity = 120 },
                led = { 255, 0, 0 },        -- красная вспышка
                duration = 5,
            },
        },

        -- ОГНЕМЁТ (Chemical Flamethrower)
        -- Плавный вентиль, постоянная лёгкая тряска пока льёт
        flamethrower = {
            l2 = { mode = "resistance", start = 0, force = 3 },
            r2 = { mode = "resistance", start = 0, force = 3 },
            led = { 255, 80, 0 },           -- оранжевый
            r2_threshold = 120,
        },

        -- SPARK SHOT
        -- Средний спуск, резкий разряд
        sparkshot = {
            l2 = { mode = "resistance", start = 0, force = 1 },
            r2 = { mode = "weapon", start = 2, stop = 7, force = 5 },
            led = { 0, 200, 255 },          -- электро-голубой
            r2_threshold = 160,
            kick = {
                l2 = { mode = "vibration", intensity = 30 },
                r2 = { mode = "vibration", intensity = 50 },
                duration = 4,
            },
        },

        -- НОЖ (Combat Knife)
        -- Свободный триггер, без kick
        knife = {
            l2 = { mode = "off" },
            r2 = { mode = "off" },
            led = { 255, 255, 255 },        -- белый
            r2_threshold = 0,
            empty = {
                r2 = { mode = "off" },
            },
        },

        -- ГРАНАТЫ (Hand Grenade, Flash Grenade)
        -- Сопротивление броска, без kick (бросок, не выстрел)
        grenade = {
            l2 = { mode = "off" },
            r2 = { mode = "resistance", start = 0, force = 4 },
            led = { 0, 255, 0 },            -- зелёный
            r2_threshold = 100,
            empty = {
                r2 = { mode = "resistance", start = 0, force = 4 },
            },
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
        [21]  = { name = "MQ 11",                   type = "mq11" },
        [23]  = { name = "LE 5",                    type = "le5" },

        -- Магнум
        [31]  = { name = "Lightning Hawk",          type = "mag" },

        -- Гранатомёт
        [42]  = { name = "GM 79",                   type = "gl" },

        -- Спецоружие (отдельные профили)
        [41]  = { name = "EMF Visualizer",          type = "none" },
        [43]  = { name = "Chemical Flamethrower",   type = "flamethrower" },
        [44]  = { name = "Spark Shot",              type = "sparkshot" },

        -- Ракетницы
        [45]  = { name = "ATM-4",                   type = "rocket" },
        [49]  = { name = "Anti-Tank Rocket",        type = "rocket" },

        -- Minigun
        [50]  = { name = "Minigun",                 type = "minigun" },

        -- Нож
        [46]  = { name = "Combat Knife",            type = "knife" },
        [47]  = { name = "Combat Knife (Infinite)", type = "knife" },

        -- Гранаты
        [65]  = { name = "Hand Grenade",            type = "grenade" },
        [66]  = { name = "Flash Grenade",           type = "grenade" },

        -- Infinite варианты
        [222] = { name = "ATM-4 (Infinite)",        type = "rocket" },
        [242] = { name = "Anti-Tank Rocket (Inf)",  type = "rocket" },
        [252] = { name = "Minigun (Infinite)",      type = "minigun" },
    },
}
