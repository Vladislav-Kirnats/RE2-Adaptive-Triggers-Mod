-- weapon_dsx.lua — Профили адаптивных триггеров для RE2 Remake
--
-- Ключи маппинга (приоритет поиска):
--   "type:xxx" → по типу оружия из weapon_equip_core
--   "id"       → по числовому WeaponType enum
--   "name"     → по подстроке имени
--   "default"  → фоллбэк
--
-- Параметры DSX инструкций (type=1, управление триггером):
--   parameters = {controllerIndex, trigger, mode, ...}
--   trigger: 1=L2 (прицел), 2=R2 (стрельба)
--   mode:
--     0  = Normal (выкл, триггер свободный)
--     1  = GameCube (лёгкий клик — используем для dry fire)
--     2  = Weapon (упор: start, end, force)
--     3  = Bow (пружина с щелчком: start, end, force, snap)
--     8  = VibrateTrigger (вибрация: intensity)
--     13 = Resistance (постоянное сопротивление: start, force 0-8)

return {

    --===============================================================
    -- DEFAULT (фоллбэк для неизвестного оружия)
    --===============================================================
    default = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 3 } },  -- L2: Resistance 37.5%
            { type = 1, parameters = { 0, 2, 0 } },          -- R2: Normal
            { type = 2, parameters = { 0, 0, 0, 0 } },       -- LED: off
            { type = 4, parameters = { 0, 1, 0 } },           -- L2 Trigger Threshold: 0
            { type = 4, parameters = { 0, 2, 0 } },           -- R2 Trigger Threshold: 0
        }
    },

    --===============================================================
    -- ПИСТОЛЕТЫ (Matilda, JMB Hp3, SLS 60, Quickdraw Army)
    -- L2: лёгкое сопротивление при прицеливании
    -- R2: тяжёлый спуск — чувствуешь каждый выстрел
    -- R2 Threshold: 180 — выстрел только после продавливания
    --===============================================================
    ["type:hg"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 3 } },      -- L2: Resistance force=3
            { type = 1, parameters = { 0, 2, 2, 0, 9, 8 } },    -- R2: Weapon mode, max force
            { type = 2, parameters = { 0, 0, 120, 255 } },       -- LED: Blue
            { type = 4, parameters = { 0, 2, 180 } },            -- R2 Threshold: 180/255
        }
    },

    --===============================================================
    -- ДРОБОВИК (W-870)
    -- L2: среднее сопротивление (тяжёлое оружие)
    -- R2: пружина с щелчком — ощущение помпового действия
    --===============================================================
    ["type:sg"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 6 } },      -- L2: Resistance force=6
            { type = 1, parameters = { 0, 2, 3, 0, 6, 8, 8 } },  -- R2: Bow, heavy snap
            { type = 2, parameters = { 0, 255, 40, 40 } },        -- LED: Red
            { type = 4, parameters = { 0, 2, 200 } },             -- R2 Threshold: 200/255
        }
    },

    --===============================================================
    -- МАГНУМ (Lightning Hawk)
    -- L2: тяжёлое сопротивление
    -- R2: максимально тугой щелчок — мощный выстрел
    --===============================================================
    ["type:mag"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 6 } },      -- L2: Resistance force=6
            { type = 1, parameters = { 0, 2, 3, 0, 8, 8, 8 } },  -- R2: Bow, MAX force+snap
            { type = 2, parameters = { 0, 180, 0, 255 } },        -- LED: Purple
            { type = 4, parameters = { 0, 2, 220 } },             -- R2 Threshold: 220/255
        }
    },

    --===============================================================
    -- SMG (MQ 11, LE 5, Minigun)
    -- L2: лёгкое сопротивление
    -- R2: вибрация — ощущение автоматической стрельбы
    --===============================================================
    ["type:smg"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 2 } },      -- L2: Resistance force=2
            { type = 1, parameters = { 0, 2, 8, 20 } },          -- R2: VibrateTrigger
            { type = 2, parameters = { 0, 255, 140, 0 } },        -- LED: Orange
            { type = 4, parameters = { 0, 2, 0 } },               -- R2 Threshold: 0 (авто нужен лёгкий)
        }
    },

    --===============================================================
    -- ГРАНАТОМЁТ (GM 79, ATM-4)
    -- L2: максимальное сопротивление (тяжёлое оружие)
    -- R2: среднее сопротивление — плавный спуск
    --===============================================================
    ["type:gl"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 8 } },      -- L2: Resistance MAX
            { type = 1, parameters = { 0, 2, 13, 0, 4 } },      -- R2: Resistance force=4
            { type = 2, parameters = { 0, 0, 255, 0 } },          -- LED: Green
            { type = 4, parameters = { 0, 2, 180 } },             -- R2 Threshold: 180/255
        }
    },

    --===============================================================
    -- СПЕЦОРУЖИЕ (Sparkshot, Chemical Flamethrower)
    -- L2: среднее сопротивление
    -- R2: Weapon mode с средней силой
    --===============================================================
    ["type:special"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 4 } },      -- L2: Resistance force=4
            { type = 1, parameters = { 0, 2, 2, 2, 8, 5 } },    -- R2: Weapon, medium
            { type = 2, parameters = { 0, 0, 255, 255 } },        -- LED: Cyan
            { type = 4, parameters = { 0, 2, 150 } },             -- R2 Threshold: 150/255
        }
    },

    --===============================================================
    -- НОЖ
    -- L2: минимальное сопротивление
    -- R2: обычный (нож = быстрые удары)
    --===============================================================
    ["type:knife"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 13, 0, 1 } },      -- L2: Resistance minimal
            { type = 1, parameters = { 0, 2, 0 } },              -- R2: Normal
            { type = 2, parameters = { 0, 255, 255, 255 } },      -- LED: White
            { type = 4, parameters = { 0, 2, 0 } },               -- R2 Threshold: 0
        }
    },

    --===============================================================
    -- НЕТ ОРУЖИЯ / ГОЛЫЕ РУКИ
    --===============================================================
    ["type:none"] = {
        instructions = {
            { type = 1, parameters = { 0, 1, 0 } },              -- L2: Normal
            { type = 1, parameters = { 0, 2, 0 } },              -- R2: Normal
            { type = 2, parameters = { 0, 0, 0, 0 } },           -- LED: off
            { type = 4, parameters = { 0, 1, 0 } },               -- L2 Threshold: 0
            { type = 4, parameters = { 0, 2, 0 } },               -- R2 Threshold: 0
        }
    },

}
