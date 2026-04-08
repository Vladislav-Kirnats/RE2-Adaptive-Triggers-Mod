-- dsx_writer.lua — Записывает команды для DualSenseX через файл payload.json
-- Читает профили триггеров из re2_config.lua через WeaponEquipCore

local io = io
local table = table
local pcall = pcall
local tostring = tostring
local os = os
local type = type

_G.DSXWriter = _G.DSXWriter or {}
local DSX = _G.DSXWriter

DSX.out_path     = nil
DSX.last_applied = 0
DSX.ready        = false

-----------------------------------------------------------------------
-- Найти payload.json
-----------------------------------------------------------------------
local function find_payload()
    local tries = {
        "DualSenseX/payload.json",
        "DualsenseX/payload.json",
        "reframework/data/DualSenseX/payload.json",
    }
    for _, path in ipairs(tries) do
        local f = io.open(path, "rb")
        if f then f:close(); return path end
    end
    return nil
end

DSX.out_path = find_payload()
DSX.ready = (DSX.out_path ~= nil)

-----------------------------------------------------------------------
-- Собрать JSON из таблицы инструкций
-----------------------------------------------------------------------
local function build(tbl)
    local parts = { '{"instructions":[' }
    for i, inst in ipairs(tbl) do
        parts[#parts + 1] = '{"type":' .. tostring(inst.type) .. ',"parameters":['
        local params = inst.parameters or {}
        for j, v in ipairs(params) do
            if type(v) == "number" then
                parts[#parts + 1] = v
            elseif type(v) == "boolean" then
                parts[#parts + 1] = v and "true" or "false"
            else
                parts[#parts + 1] = '"' .. tostring(v):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
            end
            if j < #params then parts[#parts + 1] = "," end
        end
        parts[#parts + 1] = "]}"
        if i < #tbl then parts[#parts + 1] = "," end
    end
    parts[#parts + 1] = "]}"
    return table.concat(parts)
end

-----------------------------------------------------------------------
-- Записать в файл
-----------------------------------------------------------------------
local function write_payload(text)
    if not DSX.out_path then return false end
    local f = io.open(DSX.out_path, "wb")
    if not f then return false end
    f:write(text)
    f:close()
    DSX.last_applied = os.time()
    return true
end

-----------------------------------------------------------------------
-- Сброс триггеров
-----------------------------------------------------------------------
function DSX.payload_reset()
    return build({
        { type = 1, parameters = { 0, 1, 0 } },
        { type = 1, parameters = { 0, 2, 0 } },
        { type = 2, parameters = { 0, 0, 0, 0 } },
        { type = 4, parameters = { 0, 1, 0 } },
        { type = 4, parameters = { 0, 2, 0 } },
    })
end

-----------------------------------------------------------------------
-- Словарь: строковое имя режима → числовой код DSX
-----------------------------------------------------------------------
local MODE_NAMES = {
    off           = 0,
    normal        = 0,
    gamecube      = 1,
    click         = 1,     -- алиас
    weapon        = 2,
    bow           = 3,
    galloping     = 4,
    semi_auto     = 5,
    auto_gun      = 6,
    machine       = 7,
    vibrate       = 8,
    vibration     = 8,     -- алиас
    choppy        = 9,
    very_soft     = 10,
    soft          = 11,
    medium        = 12,
    resistance    = 13,
    hard          = 13,    -- алиас
    very_hard     = 14,
    hardest       = 15,
    rigid         = 16,
}

-- Получить числовой код: принимает и число, и строку
local function resolve_mode(m)
    if type(m) == "number" then return m end
    if type(m) == "string" then return MODE_NAMES[m:lower()] or 0 end
    return 0
end

-----------------------------------------------------------------------
-- Конвертировать профиль из конфига в DSX-инструкции
-----------------------------------------------------------------------
local function profile_to_instructions(profile, cfg_settings)
    if not profile then return nil end
    local instructions = {}

    -- Конвертирует один триггер (l2=1, r2=2)
    local function add_trigger(trigger_num, t)
        if not t then return end
        local m = resolve_mode(t.mode)
        if m == 0 then
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, 0 } }
        elseif m == 13 or m == 14 or m == 15 then -- Resistance / Hard / VeryHard / Hardest
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, m, t.start or 0, t.force or 3 } }
        elseif m == 2 or m == 5 then -- Weapon / SemiAuto
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, m, t.start or 0, t.stop or 9, t.force or 8 } }
        elseif m == 3 then -- Bow
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, 3, t.start or 0, t.stop or 6, t.force or 8, t.snap or 8 } }
        elseif m == 8 then -- VibrateTrigger
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, 8, t.intensity or 20 } }
        elseif m == 1 then -- GameCube/Click
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, 1, t.start or 0, t.force or 8 } }
        elseif m == 6 then -- AutomaticGun
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, 6, t.start or 0, t.force or 8, t.frequency or 20 } }
        elseif m == 16 then -- Rigid (полная блокировка)
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, 16 } }
        else
            -- Для остальных режимов (soft, medium, choppy и т.д.) — простой вызов
            instructions[#instructions + 1] = { type = 1, parameters = { 0, trigger_num, m } }
        end
    end

    add_trigger(1, profile.l2)  -- L2
    add_trigger(2, profile.r2)  -- R2

    -- LED
    local led = profile.led
    if led then
        instructions[#instructions + 1] = { type = 2, parameters = { 0, led[1] or 0, led[2] or 0, led[3] or 0 } }
    end

    -- Trigger Threshold (type=4)
    local l2_thr = (cfg_settings and cfg_settings.default_l2_threshold) or 0
    local r2_thr = profile.r2_threshold or (cfg_settings and cfg_settings.default_r2_threshold) or 0
    instructions[#instructions + 1] = { type = 4, parameters = { 0, 1, l2_thr } }
    instructions[#instructions + 1] = { type = 4, parameters = { 0, 2, r2_thr } }

    return instructions
end

-----------------------------------------------------------------------
-- Применить профиль для текущего оружия
-----------------------------------------------------------------------
function DSX.apply_for_weapon(info)
    if not DSX.out_path then return end

    local CORE = _G.WeaponEquipCore
    local CFG = CORE and CORE.get_config and CORE.get_config() or {}
    local profiles = CFG.profiles or {}
    local settings = CFG.settings or {}

    -- Ищем профиль по типу оружия
    local weapon_type = info and info.type or "none"
    local profile = profiles[weapon_type] or profiles["default"]

    if not profile then
        write_payload(DSX.payload_reset())
        return
    end

    local instructions = profile_to_instructions(profile, settings)
    if not instructions then
        write_payload(DSX.payload_reset())
        return
    end

    -- Dry fire: если в магазине 0 патронов и в запасе тоже 0 → лёгкий клик
    if info.ammo and info.ammo == 0 and info.reserve ~= nil then
        local new_instructions = {}
        for _, inst in ipairs(instructions) do
            if inst.type == 1 and inst.parameters and inst.parameters[2] == 2 then
                -- R2 → GameCube (лёгкий мёртвый клик)
                new_instructions[#new_instructions + 1] = { type = 1, parameters = { 0, 2, 1, 0, 8 } }
            else
                new_instructions[#new_instructions + 1] = inst
            end
        end
        instructions = new_instructions
    end

    write_payload(build(instructions))
end

-----------------------------------------------------------------------
-- Перезагрузка конфига (кнопка в UI)
-----------------------------------------------------------------------
function DSX.reload_config()
    local CORE = _G.WeaponEquipCore
    if CORE and CORE.reload_config then
        CORE.reload_config()
    end
    -- Переприменить текущее оружие
    if CORE and CORE.last_info then
        pcall(function() DSX.apply_for_weapon(CORE.last_info) end)
    end
end

-----------------------------------------------------------------------
-- Подписка на смену оружия
-----------------------------------------------------------------------
if _G.WeaponEquipCore and _G.WeaponEquipCore.on_weapon_change then
    _G.WeaponEquipCore.on_weapon_change(function(info)
        pcall(function() DSX.apply_for_weapon(info) end)
    end)
end
