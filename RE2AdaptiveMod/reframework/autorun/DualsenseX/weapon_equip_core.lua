-- weapon_equip_core.lua — Ядро: читает текущее оружие и патроны из RE2 Engine
-- Callback-система (как в RE4 моде): on_weapon_change → dsx_writer

local sdk = sdk
local re = re
local pcall = pcall
local tostring = tostring

local POLL_INTERVAL = 6

_G.WeaponEquipCore = _G.WeaponEquipCore or {}
local CORE = _G.WeaponEquipCore

CORE.config = CORE.config or { enabled = true }
CORE.callbacks = CORE.callbacks or {}
CORE.last_info = CORE.last_info or nil
CORE.status = CORE.status or {
    ready = false,
    weapon_name = "None",
    weapon_type = "none",
    ammo = 0,
    reserve = 0
}

-- Безопасный вызов (без varargs в замыкании — безопасно для LuaJIT)
local function safe_call(f, ...)
    local ok, r = pcall(f, ...)
    if ok then return r end
    return nil
end

---------------------------------------------------------------
-- Таблица оружия RE2 (ID → name, type)
---------------------------------------------------------------
local WEAPONS = {}

local function load_weapon_table()
    local config = _G.RE2_CONFIG
    if config and config.weapons then
        WEAPONS = config.weapons
        return
    end
    -- Fallback: пробуем загрузить вручную
    local ok, chunk = pcall(loadfile, "reframework/data/DualSenseX/re2_config.lua")
    if ok and chunk then
        local ok2, data = pcall(chunk)
        if ok2 and type(data) == "table" then
            _G.RE2_CONFIG = data
            WEAPONS = data.weapons or {}
        end
    end
end

load_weapon_table()

---------------------------------------------------------------
-- Чтение оружия из RE2 Engine
---------------------------------------------------------------
local function get_weapon_id()
    local em = safe_call(sdk.get_managed_singleton, "app.ropeway.EquipmentManager")
    if not em then return nil end
    return safe_call(em.call, em, "get_CurrentWeaponType")
end

local function get_ammo_data()
    local em = safe_call(sdk.get_managed_singleton, "app.ropeway.EquipmentManager")
    if not em then return 0, 0 end
    local equipment = safe_call(em.call, em, "getPlayerEquipment")
    if not equipment then return 0, 0 end
    local gun = safe_call(equipment.get_field, equipment, "<EquipWeapon>k__BackingField")
    if not gun then return 0, 0 end

    local ammo = safe_call(gun.call, gun, "getBulletNumber") or 0
    local im = safe_call(sdk.get_managed_singleton, "app.ropeway.gamemastering.InventoryManager")
    local reserve = 0
    if im then
        reserve = safe_call(im.call, im, "getMainWeaponReloadableBullet") or 0
    end
    return ammo, reserve
end

---------------------------------------------------------------
-- Callback система
---------------------------------------------------------------
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

---------------------------------------------------------------
-- Хуки на выстрел
---------------------------------------------------------------
local gun_type = sdk.find_type_definition("app.ropeway.implement.Gun")
if gun_type then
    -- 1. Хук executeFire — kick эффект
    local fire_method = gun_type:get_method("executeFire")
    if fire_method then
        sdk.hook(fire_method,
            function(args)
                if _G.DSXWriter and _G.DSXWriter.on_fire then
                    _G.DSXWriter.on_fire()
                end
            end,
            function(retval) return retval end
        )
    end

    -- 2. Хук enableFire — rapid fire блокировка
    local enable_fire = gun_type:get_method("enableFire")
    if enable_fire then
        sdk.hook(enable_fire,
            function(args) end,
            function(retval)
                if _G.DSXWriter and _G.DSXWriter.should_block_fire then
                    if _G.DSXWriter.should_block_fire() then
                        -- Возвращаем false (в managed — через sdk.to_ptr)
                        return sdk.to_ptr(0)
                    end
                end
                return retval
            end
        )
    end
end

---------------------------------------------------------------
-- Главный цикл опроса
---------------------------------------------------------------
local tick = 0
local last_id = nil
local last_ammo_state = nil -- true=есть патроны, false=пусто
local heartbeat = 0

local function on_update()
    -- Тики каждый кадр (без throttle)
    if _G.DSXWriter then
        if _G.DSXWriter._tick_kick_restore then _G.DSXWriter._tick_kick_restore() end
        if _G.DSXWriter._tick_rapid_fire then _G.DSXWriter._tick_rapid_fire() end
    end

    tick = tick + 1
    if tick % POLL_INTERVAL ~= 0 then return end

    if not CORE.config.enabled then return end

    local id = get_weapon_id()

    local info
    if id then
        local w_data = WEAPONS[id] or { name = "Unknown (ID:" .. tostring(id) .. ")", type = "default" }
        local ammo, reserve = get_ammo_data()

        info = {
            id = id,
            name = w_data.name,
            type = w_data.type,
            ammo = ammo,
            reserve = reserve
        }
    else
        info = { id = "none", name = "No weapon", type = "none", ammo = 0, reserve = 0 }
    end

    -- Обновляем статус
    CORE.status.weapon_name = info.name
    CORE.status.weapon_type = info.type
    CORE.status.ammo = info.ammo
    CORE.status.reserve = info.reserve
    CORE.last_info = info

    -- Определяем нужно ли уведомлять
    local ammo_state = (info.ammo > 0)
    heartbeat = heartbeat + 1
    local force_pulse = (heartbeat > 10) -- периодический пульс

    if (info.id ~= last_id) or (ammo_state ~= last_ammo_state) or force_pulse then
        last_id = info.id
        last_ammo_state = ammo_state
        CORE.status.ready = true
        notify_all(info)
        if force_pulse then heartbeat = 0 end
    end
end

pcall(function() re.on_frame(on_update) end)
