-- dsx_writer.lua — Формирует JSON для DualSenseX и пишет в payload.json
-- Читает профили из RE2_CONFIG (re2_config.lua)
-- Строковые mode конвертируются в числа при отправке

local io = io
local table = table
local pcall = pcall
local tostring = tostring
local os = os

_G.DSXWriter = _G.DSXWriter or {}
local DSX = _G.DSXWriter

DSX.out_path = nil
DSX.last_applied = 0
DSX.last_write_time = 0
DSX.MIN_WRITE_INTERVAL = 0.05 -- 50мс — защита от спама (BSOD fix)
DSX.ready = false
DSX.last_info = nil
DSX.status = "INIT"

---------------------------------------------------------------
-- Конвертация строковых mode → числа DSX
---------------------------------------------------------------
local MODE_MAP = {
    off        = 0,
    click      = 1,   -- лёгкий щелчок (dry fire)
    weapon     = 2,   -- упор с сопротивлением (спуск пистолета)
    bow        = 3,   -- пружина + щелчок (тетива)
    soft       = 4,
    medium     = 5,
    very_hard  = 6,
    rigid      = 7,   -- полностью заблокирован
    hardest    = 7,
    vibration  = 8,   -- вибрация (автомат)
    auto_gun   = 8,
    choppy     = 9,
    semi_auto  = 2,   -- = weapon
    resistance = 13,  -- чистое сопротивление
    hard       = 13,
}

local function resolve_mode(mode_str)
    if type(mode_str) == "number" then return mode_str end
    if type(mode_str) == "string" then
        return MODE_MAP[mode_str:lower()] or 0
    end
    return 0
end

---------------------------------------------------------------
-- Поиск / создание payload.json
---------------------------------------------------------------
local function find_payload()
    local candidates = {
        "reframework/data/DualSenseX/payload.json",
        "DualSenseX/payload.json",
        "DualsenseX/payload.json",
    }
    for _, p in ipairs(candidates) do
        local f = io.open(p, "rb")
        if f then f:close(); return p end
    end
    local default_path = candidates[1]
    local f = io.open(default_path, "wb")
    if f then
        f:write("{}")
        f:close()
        return default_path
    end
    return nil
end

DSX.out_path = find_payload()
DSX.ready = (DSX.out_path ~= nil)

---------------------------------------------------------------
-- Ручная сборка JSON (без зависимости от json.dump_string)
---------------------------------------------------------------
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

---------------------------------------------------------------
-- Запись в файл (с throttle)
---------------------------------------------------------------
local function write_payload(text, force)
    if not DSX.out_path then return false end
    local now = os.clock()
    if not force and (now - DSX.last_write_time) < DSX.MIN_WRITE_INTERVAL then
        return false
    end
    local f = io.open(DSX.out_path, "wb")
    if not f then return false end
    f:write(text)
    f:close()
    DSX.last_write_time = now
    DSX.last_applied = os.time()
    return true
end

---------------------------------------------------------------
-- Конвертация профиля (l2/r2/led/threshold) → instructions[]
---------------------------------------------------------------
local function profile_to_instructions(profile)
    local instructions = {}

    -- L2 (прицеливание)
    if profile.l2 then
        local m = resolve_mode(profile.l2.mode)
        if m == 0 then
            -- Off — просто выключаем
            table.insert(instructions, { type = 1, parameters = {0, 1, 0} })
        elseif m == 8 then
            -- Vibration: {controller, trigger, 8, frequency}
            table.insert(instructions, { type = 1, parameters = {
                0, 1, m, profile.l2.intensity or 20
            }})
        elseif m == 3 then
            -- Bow — mode + start + stop + force + snap
            table.insert(instructions, { type = 1, parameters = {
                0, 1, m,
                profile.l2.start or 0,
                profile.l2.stop or 6,
                profile.l2.force or 4,
                profile.l2.snap or 4
            }})
        elseif m == 2 then
            -- Weapon — mode + start + stop + force
            table.insert(instructions, { type = 1, parameters = {
                0, 1, m,
                profile.l2.start or 0,
                profile.l2.stop or 9,
                profile.l2.force or 4
            }})
        else
            -- Resistance и другие — mode + start + force
            table.insert(instructions, { type = 1, parameters = {
                0, 1, m,
                profile.l2.start or 0,
                profile.l2.force or 0
            }})
        end
    end

    -- R2 (стрельба)
    if profile.r2 then
        local m = resolve_mode(profile.r2.mode)
        if m == 0 then
            table.insert(instructions, { type = 1, parameters = {0, 2, 0} })
        elseif m == 8 then
            -- Vibration: {controller, trigger, 8, frequency}
            -- frequency (intensity) = частота вибрации (0-255)
            table.insert(instructions, { type = 1, parameters = {
                0, 2, m, profile.r2.intensity or 20
            }})
        elseif m == 3 then
            -- Bow
            table.insert(instructions, { type = 1, parameters = {
                0, 2, m,
                profile.r2.start or 0,
                profile.r2.stop or 6,
                profile.r2.force or 4,
                profile.r2.snap or 4
            }})
        elseif m == 2 then
            -- Weapon
            table.insert(instructions, { type = 1, parameters = {
                0, 2, m,
                profile.r2.start or 0,
                profile.r2.stop or 9,
                profile.r2.force or 4
            }})
        elseif m == 1 then
            -- Click
            table.insert(instructions, { type = 1, parameters = {
                0, 2, m,
                profile.r2.start or 0,
                profile.r2.force or 8
            }})
        else
            -- Resistance и другие
            table.insert(instructions, { type = 1, parameters = {
                0, 2, m,
                profile.r2.start or 0,
                profile.r2.force or 0
            }})
        end
    end

    -- LED (подсветка)
    if profile.led then
        table.insert(instructions, { type = 2, parameters = {
            0, profile.led[1] or 0, profile.led[2] or 0, profile.led[3] or 0
        }})
    end

    -- R2 Threshold (порог нажатия / мёртвая зона)
    -- type=4 — TriggerThreshold в DSX
    if profile.r2_threshold then
        table.insert(instructions, { type = 4, parameters = {
            0, 2, profile.r2_threshold
        }})
    end

    return instructions
end

---------------------------------------------------------------
-- Слияние основного профиля с empty (empty переопределяет поля)
---------------------------------------------------------------
local function merge_with_empty(profile)
    if not profile.empty then return profile end
    local merged = {}
    -- Копируем основной профиль
    for k, v in pairs(profile) do
        if k ~= "empty" then merged[k] = v end
    end
    -- Переопределяем полями из empty
    for k, v in pairs(profile.empty) do
        merged[k] = v
    end
    return merged
end

---------------------------------------------------------------
-- Получить профиль для оружия
---------------------------------------------------------------
local function get_profile(info)
    local config = _G.RE2_CONFIG
    if not config or not config.profiles then return nil end
    return config.profiles[info.type] or config.profiles["default"]
end

---------------------------------------------------------------
-- Применить профиль (запись в payload.json)
---------------------------------------------------------------
function DSX.apply_for_weapon(info)
    if not DSX.out_path then return end

    -- Не перезаписывать если сейчас идёт kick эффект
    if DSX._kick_frames_left and DSX._kick_frames_left > 0 then return end

    local profile = get_profile(info)
    if not profile then
        write_payload(DSX.payload_reset(), true)
        return
    end

    -- Если магазин пуст — используем empty профиль
    local active_profile = profile
    if info.ammo and info.ammo == 0 then
        if profile.empty then
            active_profile = merge_with_empty(profile)
        else
            -- Дефолтный dry fire: меняем только R2 на click
            active_profile = {}
            for k, v in pairs(profile) do active_profile[k] = v end
            active_profile.r2 = { mode = "click", start = 0, force = 8 }
        end
    end

    local ok, instructions = pcall(profile_to_instructions, active_profile)
    if ok and instructions then
        write_payload(build(instructions), true)
    end
end

---------------------------------------------------------------
-- Preset payloads
---------------------------------------------------------------
function DSX.payload_reset()
    return build({
        { type = 1, parameters = {0, 1, 0} },
        { type = 1, parameters = {0, 2, 0} },
        { type = 2, parameters = {0, 0, 0, 0} },
    })
end

---------------------------------------------------------------
-- Kick (отдача при выстреле)
-- Читает profile.kick из конфига — полноценный профиль
-- duration = сколько кадров БЕЗ ВЫСТРЕЛА до восстановления
-- Каждый выстрел обновляет таймер (для автоматов)
---------------------------------------------------------------
DSX._kick_frames_left = 0
DSX._kick_active = false

function DSX.kick()
    local info = DSX.last_info
    if not info then return end

    local profile = get_profile(info)
    if not profile or not profile.kick then return end

    local duration = profile.kick.duration or 3

    -- Если уже в кике — просто обновляем таймер (для автоматов)
    if DSX._kick_active then
        DSX._kick_frames_left = duration

        return
    end

    -- Первый выстрел — собираем kick-профиль и пишем
    local kick_profile = {}
    for k, v in pairs(profile) do
        if k ~= "empty" and k ~= "kick" then kick_profile[k] = v end
    end
    for k, v in pairs(profile.kick) do
        if k ~= "duration" then kick_profile[k] = v end
    end

    local ok, instructions = pcall(profile_to_instructions, kick_profile)
    if ok and instructions then
        write_payload(build(instructions), true)
        DSX._kick_frames_left = duration
        DSX._kick_active = true
    end
end

-- Таймер восстановления после кика (вызывается каждый кадр)
function DSX._tick_kick_restore()
    if DSX._kick_frames_left <= 0 then return end
    DSX._kick_frames_left = DSX._kick_frames_left - 1
    if DSX._kick_frames_left == 0 then
        DSX._kick_active = false
        DSX._rapid_fire_count = 0  -- отпустил триггер — сброс счётчика
        if DSX.last_info then
            pcall(DSX.apply_for_weapon, DSX.last_info)
        end
    end
end

---------------------------------------------------------------
-- On Fire (вызывается из хука executeFire)
-- Считает выстрелы + kick
---------------------------------------------------------------
DSX._rapid_fire_count = 0
DSX._rapid_fire_cooldown = 0
local RAPID_FIRE_RESET_FRAMES = 15 -- ~250мс при 60fps

function DSX.on_fire()
    local info = DSX.last_info
    if not info then return end

    local profile = get_profile(info)
    if not profile then return end

    -- Считаем выстрел
    if profile.rapid_fire and profile.rapid_fire > 0 then
        DSX._rapid_fire_count = DSX._rapid_fire_count + 1
        DSX._rapid_fire_cooldown = RAPID_FIRE_RESET_FRAMES
    end

    -- Kick (отдача)
    pcall(DSX.kick)
end

---------------------------------------------------------------
-- Should Block Fire (вызывается из хука enableFire)
-- Возвращает true если лимит выстрелов исчерпан
---------------------------------------------------------------
function DSX.should_block_fire()
    local info = DSX.last_info
    if not info then return false end

    local profile = get_profile(info)
    if not profile then return false end

    if profile.rapid_fire and profile.rapid_fire > 0 then
        if DSX._rapid_fire_count >= profile.rapid_fire then
            return true
        end
    end
    return false
end

-- Таймер сброса rapid_fire (вызывается каждый кадр из core)
function DSX._tick_rapid_fire()
    if DSX._rapid_fire_cooldown <= 0 then return end
    DSX._rapid_fire_cooldown = DSX._rapid_fire_cooldown - 1
    if DSX._rapid_fire_cooldown == 0 and DSX._rapid_fire_count > 0 then
        print("[DSX] rapid_fire: RESET (trigger released)")
        DSX._rapid_fire_count = 0
    end
end

---------------------------------------------------------------
-- Регистрация callback из Core
---------------------------------------------------------------
if _G.WeaponEquipCore and _G.WeaponEquipCore.on_weapon_change then
    _G.WeaponEquipCore.on_weapon_change(function(info)
        DSX.last_info = info
        DSX._rapid_fire_count = 0  -- сброс при смене оружия/патронов
        pcall(DSX.apply_for_weapon, info)
    end)
end

---------------------------------------------------------------
-- Публичные функции
---------------------------------------------------------------
function DSX.force_sync()
    if DSX.last_info then
        pcall(DSX.apply_for_weapon, DSX.last_info)
    end
end

DSX.status = DSX.ready and "READY" or "NO PAYLOAD FILE"
