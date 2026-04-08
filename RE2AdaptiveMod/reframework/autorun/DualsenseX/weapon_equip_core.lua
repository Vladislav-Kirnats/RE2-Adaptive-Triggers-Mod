-- weapon_equip_core.lua — Ядро: читает текущее оружие и патроны из RE2 Engine
--
-- Все настройки (оружия, профили, дедзоны) загружаются из re2_config.lua
-- Этот файл НЕ нужно редактировать для добавления оружия.

local sdk = sdk
local re = re
local pcall = pcall
local tostring = tostring
local type = type

-----------------------------------------------------------------------
-- Загрузка конфига
-----------------------------------------------------------------------
local CONFIG_PATH = "reframework/data/DualSenseX/re2_config.lua"

local function load_config()
    local f, err = loadfile(CONFIG_PATH)
    if not f then
        print("[DualsenseX] CONFIG ERROR: " .. tostring(err))
        return nil
    end
    local ok, cfg = pcall(f)
    if not ok or type(cfg) ~= "table" then
        print("[DualsenseX] CONFIG ERROR: invalid format")
        return nil
    end
    return cfg
end

local CFG = load_config() or { settings = {}, profiles = {}, weapons = {} }

local POLL_INTERVAL = (CFG.settings and CFG.settings.poll_interval) or 6

-- Глобальный объект ядра
_G.WeaponEquipCore = _G.WeaponEquipCore or {}
local CORE = _G.WeaponEquipCore

CORE.config    = CORE.config or { enabled = true }
CORE.callbacks = CORE.callbacks or {}
CORE.last_info = CORE.last_info or nil
CORE.status    = CORE.status or {
    ready            = false,
    controller_found = false,
    weapon_name      = "None",
    weapon_type_raw  = -1,
    ammo             = 0,
    ammoMax          = 0,
}

-- Перезагрузка конфига (вызывается из UI кнопкой)
function CORE.reload_config()
    local new_cfg = load_config()
    if new_cfg then
        CFG = new_cfg
        POLL_INTERVAL = (CFG.settings and CFG.settings.poll_interval) or 6
        print("[DualsenseX] Config reloaded")
    end
    return CFG
end

-- Доступ к конфигу для других модулей
function CORE.get_config() return CFG end

-----------------------------------------------------------------------
-- Безопасные вызовы RE Engine
-----------------------------------------------------------------------
local function safe_call(obj, method, ...)
    if not obj then return nil end
    local ok, result = pcall(obj.call, obj, method, ...)
    if ok then return result end
    return nil
end

local function safe_field(obj, field_name)
    if not obj then return nil end
    local ok, result = pcall(obj.get_field, obj, field_name)
    if ok then return result end
    return nil
end

-----------------------------------------------------------------------
-- Чтение состояния из RE2 Engine
-----------------------------------------------------------------------
local function get_player_equipment()
    local em = sdk.get_managed_singleton("app.ropeway.EquipmentManager")
    if not em then return nil end
    return safe_call(em, "getPlayerEquipment")
end

local function get_current_weapon_type_enum()
    local em = sdk.get_managed_singleton("app.ropeway.EquipmentManager")
    if not em then return nil end
    return safe_call(em, "get_CurrentWeaponType")
end

local function get_equip_weapon(equipment)
    if not equipment then return nil end
    return safe_field(equipment, "<EquipWeapon>k__BackingField")
end

local function get_ammo_info()
    local im = sdk.get_managed_singleton("app.ropeway.gamemastering.InventoryManager")
    if not im then return 0, 0 end

    local current = safe_call(im, "getMainWeaponRemainingBullet") or 0
    local reserve = safe_call(im, "getMainWeaponReloadableBullet") or 0

    return current, reserve
end

-----------------------------------------------------------------------
-- Собрать информацию о текущем оружии (используя конфиг)
-----------------------------------------------------------------------
local function get_weapon_info()
    local equipment = get_player_equipment()
    if not equipment then
        return { id = "none", name = "No Equipment", type = "none", ammo = 0, reserve = 0 }
    end

    local wt_enum = get_current_weapon_type_enum()
    local wt_val = wt_enum and tonumber(wt_enum) or 0

    if wt_val == 0 then
        return { id = 0, name = "Bare Hand", type = "none", ammo = 0, reserve = 0 }
    end
    if wt_val < 0 or wt_val == 4294967295 then
        return { id = "invalid", name = "None", type = "none", ammo = 0, reserve = 0 }
    end

    -- Ищем в конфиге
    local weapons = CFG.weapons or {}
    local info_entry = weapons[wt_val]
    local weapon_name = info_entry and info_entry.name or ("WP[" .. tostring(wt_val) .. "]")
    local weapon_type = info_entry and info_entry.type or "unknown"

    local ammo, reserve = get_ammo_info()

    return {
        id      = wt_val,
        name    = weapon_name,
        type    = weapon_type,
        ammo    = ammo,       -- патроны в магазине
        reserve = reserve,    -- запас патронов
    }
end

-----------------------------------------------------------------------
-- Rapid Fire: ограничение выстрелов за нажатие R2
-- Устанавливает EnableRapidFireNumber на объекте Gun
-----------------------------------------------------------------------
-----------------------------------------------------------------------
-- Rapid Fire: ограничение выстрелов за нажатие R2
-- Перехватываем executeFire через sdk.hook.
-- Логика: считаем выстрелы. Если лимит достигнут — блокируем.
-- Сброс через таймер: если executeFire не вызывался 10+ тиков — R2 отпущен.
-----------------------------------------------------------------------
_G._rf_count = 0
_G._rf_limit = nil
_G._rf_blocked = false
_G._rf_last_fire = 0
_G._rf_tick = 0
_G._rf_cooldown = 60  -- ~600мс при 100 тиков/сек

local function update_rapid_fire_limit(weapon_type)
    local profiles = CFG.profiles or {}
    local profile = profiles[weapon_type]
    if profile and profile.rapid_fire and profile.rapid_fire > 0 then
        _G._rf_limit = profile.rapid_fire
    else
        _G._rf_limit = nil
    end
    _G._rf_count = 0
    _G._rf_blocked = false
end

local function rapid_fire_tick()
    _G._rf_tick = _G._rf_tick + 1
    if _G._rf_blocked and (_G._rf_tick - _G._rf_last_fire) > _G._rf_cooldown then
        _G._rf_count = 0
        _G._rf_blocked = false
    end
end

local gun_type = sdk.find_type_definition("app.ropeway.implement.Gun")
if gun_type then
    local execute_fire = gun_type:get_method("executeFire")
    if execute_fire then
        sdk.hook(
            execute_fire,
            function(args)
                if not _G._rf_limit then return end
                if not CORE.config.enabled then return end

                if _G._rf_blocked then
                    _G._rf_last_fire = _G._rf_tick  -- продлеваем пока жмут
                    return sdk.PreHookResult.SKIP_ORIGINAL
                end

                _G._rf_count = _G._rf_count + 1
                _G._rf_last_fire = _G._rf_tick
                if _G._rf_count >= _G._rf_limit then
                    _G._rf_blocked = true
                end
            end,
            function(retval) return retval end
        )
    end
end

-----------------------------------------------------------------------
-- Главный цикл
-----------------------------------------------------------------------
local tick = 0
local last_id = nil
local heartbeat = 0

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
    rapid_fire_tick()  -- обновляем таймер сброса каждый тик

    tick = tick + 1
    if tick % POLL_INTERVAL ~= 0 then return end
    if not CORE.config.enabled then return end

    local info = get_weapon_info()

    CORE.status.weapon_name     = info.name
    CORE.status.weapon_type_raw = info.id
    CORE.status.ammo            = info.ammo
    CORE.status.ammoMax         = info.reserve
    CORE.status.controller_found = (info.id ~= "none" and info.id ~= "invalid")
    CORE.last_info = info

    heartbeat = heartbeat + 1
    local force_pulse = (heartbeat > 10)

    if (info.id ~= last_id) or force_pulse then
        if info.id ~= last_id then
            pcall(update_rapid_fire_limit, info.type)
        end
        last_id = info.id
        CORE.status.ready = true
        notify_all(info)
        if force_pulse then heartbeat = 0 end
    end
end

pcall(function()
    re.on_application_entry("UpdateBehavior", on_update)
end)

CORE._internal = { poll = POLL_INTERVAL }
