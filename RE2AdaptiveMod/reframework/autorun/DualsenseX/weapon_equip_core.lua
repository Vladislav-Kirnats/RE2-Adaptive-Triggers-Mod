-- weapon_equip_core.lua — Ядро: читает текущее оружие и патроны из RE2 Engine
-- Аналог RE4-версии, но вместо chainsaw.* используем app.ropeway.*
--
-- Цепочка доступа:
--   EquipmentManager (singleton) → getPlayerEquipment() → Equipment
--   Equipment.EquipWeapon → Arm/Gun → WeaponType, WpBulletCounter
--
-- Для Python-разработчика:
--   sdk.get_managed_singleton("Class") = аналог Class.get_instance() — получаем глобальный объект
--   obj:call("method") = аналог obj.method() — вызываем метод
--   obj:get_field("field") = аналог obj.field — читаем поле

local sdk = sdk
local re = re
local pcall = pcall
local tostring = tostring
local type = type

-- Как часто опрашиваем движок (каждые N тиков).
-- RE2 бежит на 60fps → ~10 опросов в секунду при POLL_INTERVAL=6
local POLL_INTERVAL = 6

-- Глобальный объект ядра — доступен другим модулям через _G.WeaponEquipCore
_G.WeaponEquipCore = _G.WeaponEquipCore or {}
local CORE = _G.WeaponEquipCore

CORE.config    = CORE.config or { enabled = true }
CORE.callbacks = CORE.callbacks or {}   -- список функций, вызываемых при смене оружия
CORE.last_info = CORE.last_info or nil  -- последнее состояние оружия
CORE.status    = CORE.status or {
    ready            = false,
    controller_found = false,
    weapon_name      = "None",
    weapon_type_raw  = -1,
    ammo             = 0,
    ammoMax          = 0,
}

-- Безопасный вызов: если метод упадёт, вернёт nil вместо краша всего мода
local function safe_call(obj, method, ...)
    if not obj then return nil end
    local ok, result = pcall(obj.call, obj, method, ...)
    if ok then return result end
    return nil
end

-- Безопасное чтение поля объекта
local function safe_field(obj, field_name)
    if not obj then return nil end
    local ok, result = pcall(obj.get_field, obj, field_name)
    if ok then return result end
    return nil
end

-----------------------------------------------------------------------
-- Таблица: WeaponType enum → категория оружия (для маппинга на профили DSX)
-- WPxxxx коды → человеческое имя и тип.
-- ВНИМАНИЕ: эту таблицу нужно будет заполнить/уточнить опытным путём!
-- Пока заполняем известные оружия RE2 по косвенным данным.
-----------------------------------------------------------------------
local WEAPON_INFO = {
    -- Hex Item ID → Decimal = наш WeaponType enum
    -- Подтверждено: MQ 11 = 0x15 = 21 ✓

    -- Пистолеты (Леон)
    [1]   = { name = "Matilda",                type = "hg" },       -- 0x01
    -- Пистолеты (Клэр)
    [2]   = { name = "M19",                    type = "hg" },       -- 0x02
    [3]   = { name = "JMB Hp3",                type = "hg" },       -- 0x03
    [4]   = { name = "Quickdraw Army",         type = "hg" },       -- 0x04
    -- Другие пистолеты
    [7]   = { name = "MUP",                    type = "hg" },       -- 0x07
    [8]   = { name = "Broom Hc",               type = "hg" },       -- 0x08
    [9]   = { name = "SLS 60",                 type = "hg" },       -- 0x09

    -- Дробовик
    [11]  = { name = "W-870",                  type = "sg" },       -- 0x0B

    -- SMG
    [21]  = { name = "MQ 11",                  type = "smg" },      -- 0x15
    [23]  = { name = "LE 5",                   type = "smg" },      -- 0x17

    -- Магнум
    [31]  = { name = "Lightning Hawk",         type = "mag" },      -- 0x1F

    -- Гранатомёт
    [42]  = { name = "GM 79",                  type = "gl" },       -- 0x2A

    -- Спецоружие
    [41]  = { name = "EMF Visualizer",         type = "none" },     -- 0x29
    [43]  = { name = "Chemical Flamethrower",  type = "special" },  -- 0x2B
    [44]  = { name = "Spark Shot",             type = "special" },  -- 0x2C

    -- Тяжёлое оружие
    [45]  = { name = "ATM-4",                  type = "gl" },       -- 0x2D
    [49]  = { name = "Anti-Tank Rocket",       type = "gl" },       -- 0x31
    [50]  = { name = "Minigun",                type = "smg" },      -- 0x32

    -- Нож
    [46]  = { name = "Combat Knife",           type = "knife" },    -- 0x2E
    [47]  = { name = "Combat Knife (Infinite)", type = "knife" },   -- 0x2F

    -- Гранаты (суб-оружие)
    [65]  = { name = "Hand Grenade",           type = "grenade" },  -- 0x41
    [66]  = { name = "Flash Grenade",          type = "grenade" },  -- 0x42

    -- Бонусное оружие (Samurai Edge)
    [82]  = { name = "Samurai Edge (Infinite)", type = "hg" },     -- 0x52
    [83]  = { name = "Samurai Edge (Chris)",   type = "hg" },       -- 0x53
    [84]  = { name = "Samurai Edge (Jill)",    type = "hg" },       -- 0x54
    [85]  = { name = "Samurai Edge (Albert)",  type = "hg" },       -- 0x55

    -- Infinite варианты
    [222] = { name = "ATM-4 (Infinite)",       type = "gl" },       -- 0xDE
    [242] = { name = "Anti-Tank Rocket (Inf)", type = "gl" },       -- 0xF2
    [252] = { name = "Minigun (Infinite)",     type = "smg" },      -- 0xFC
}

-----------------------------------------------------------------------
-- Получить Equipment игрока через EquipmentManager (singleton)
-----------------------------------------------------------------------
local function get_player_equipment()
    local em = sdk.get_managed_singleton("app.ropeway.EquipmentManager")
    if not em then return nil end
    return safe_call(em, "getPlayerEquipment")
end

-----------------------------------------------------------------------
-- Получить текущий WeaponType enum через EquipmentManager
-----------------------------------------------------------------------
local function get_current_weapon_type_enum()
    local em = sdk.get_managed_singleton("app.ropeway.EquipmentManager")
    if not em then return nil end
    return safe_call(em, "get_CurrentWeaponType")
end

-----------------------------------------------------------------------
-- Получить текущее оружие (Arm/Gun объект) из Equipment
-----------------------------------------------------------------------
local function get_equip_weapon(equipment)
    if not equipment then return nil end
    -- EquipWeapon — это текущее активное оружие (тип Arm или Gun)
    return safe_field(equipment, "<EquipWeapon>k__BackingField")
end

-----------------------------------------------------------------------
-- Прочитать патроны из объекта Gun
-- Gun наследует Arm и имеет get_WpBulletCounter() → float
-----------------------------------------------------------------------
local function get_ammo_from_gun(weapon)
    if not weapon then return 0, 0 end

    -- Способ 1: getBulletNumber() → int (текущие патроны в магазине)
    local current = safe_call(weapon, "getBulletNumber") or 0

    -- Способ 2: fallback на WpBulletCounter (float)
    if current == 0 then
        local bullet_counter = safe_call(weapon, "get_WpBulletCounter")
        if bullet_counter then
            current = math.floor(bullet_counter + 0.5)
        end
    end

    -- Макс патронов: getReloadableBulletNumber = сколько можно дозарядить
    -- Если можно дозарядить > 0, значит магазин не бесконечный
    local reloadable = safe_call(weapon, "getReloadableBulletNumber") or 0
    local max_ammo = current + reloadable

    return current, max_ammo
end

-----------------------------------------------------------------------
-- Собрать полную информацию о текущем оружии
-----------------------------------------------------------------------
local function get_weapon_info()
    local equipment = get_player_equipment()
    if not equipment then
        return { id = "none", name = "No Equipment", type = "none", ammo = 0, ammoMax = 0 }
    end

    -- WeaponType enum (число)
    local wt_enum = get_current_weapon_type_enum()
    local wt_val = wt_enum and tonumber(wt_enum) or 0

    -- Имя и тип из нашей таблицы
    local info_entry = WEAPON_INFO[wt_val]
    local weapon_name = info_entry and info_entry.name or ("WP[" .. tostring(wt_val) .. "]")
    local weapon_type = info_entry and info_entry.type or "unknown"

    -- BareHand (0) или Invalid (-1)
    if wt_val == 0 then
        return { id = 0, name = "Bare Hand", type = "none", ammo = 0, ammoMax = 0 }
    end
    if wt_val < 0 or wt_val == 4294967295 then
        return { id = "invalid", name = "None", type = "none", ammo = 0, ammoMax = 0 }
    end

    -- Читаем патроны из активного оружия
    local weapon_obj = get_equip_weapon(equipment)
    local ammo, ammo_max = get_ammo_from_gun(weapon_obj)

    return {
        id      = wt_val,
        name    = weapon_name,
        type    = weapon_type,
        ammo    = ammo,
        ammoMax = ammo_max,
    }
end

-----------------------------------------------------------------------
-- Главный цикл опроса
-----------------------------------------------------------------------
local tick = 0
local last_id = nil
local heartbeat = 0

-- Регистрация колбэка при смене оружия (используется dsx_writer)
function CORE.on_weapon_change(fn)
    if type(fn) == "function" then
        CORE.callbacks[#CORE.callbacks + 1] = fn
    end
end

local function notify_all(info)
    for _, cb in ipairs(CORE.callbacks) do
        pcall(cb, info)
    end
end

local function on_update()
    tick = tick + 1
    if tick % POLL_INTERVAL ~= 0 then return end
    if not CORE.config.enabled then return end

    local info = get_weapon_info()

    -- Обновляем статус для UI
    CORE.status.weapon_name    = info.name
    CORE.status.weapon_type_raw = info.id
    CORE.status.ammo           = info.ammo
    CORE.status.ammoMax        = info.ammoMax
    CORE.status.controller_found = (info.id ~= "none" and info.id ~= "invalid")
    CORE.last_info = info

    -- Пульс: даже без смены оружия, раз в ~60 тиков обновляем DSX
    -- (на случай изменения патронов — dry fire эффект)
    heartbeat = heartbeat + 1
    local force_pulse = (heartbeat > 10)

    if (info.id ~= last_id) or force_pulse then
        last_id = info.id
        CORE.status.ready = true
        notify_all(info)
        if force_pulse then heartbeat = 0 end
    end
end

-- Хук в главный цикл движка
pcall(function()
    re.on_application_entry("UpdateBehavior", on_update)
end)

CORE._internal = { poll = POLL_INTERVAL, weapon_info_table = WEAPON_INFO }
