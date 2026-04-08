-- dsx_writer.lua — Записывает команды для DualSenseX через файл payload.json
-- Этот модуль НЕ зависит от конкретной игры — он универсальный.
-- Формат DSX: {"instructions":[{type:N, parameters:[...]}, ...]}
--
-- Типы инструкций DSX:
--   type=1 — управление триггером
--     parameters[1] = controllerIndex (0 = первый контроллер)
--     parameters[2] = какой триггер (1=L2, 2=R2)
--     parameters[3] = режим триггера:
--         0  = Normal (выкл)
--         1  = GameCube (лёгкий клик)
--         2  = Weapon (упор с сопротивлением)
--         3  = Bow (пружина с щелчком)
--         8  = VibrateTrigger (вибрация)
--         13 = Resistance (постоянное сопротивление)
--     parameters[4+] = зависят от режима (start, end, force, snap...)
--
--   type=2 — LED подсветка контроллера
--     parameters = [controllerIndex, R, G, B]
--
--   type=3 — haptics/вибрация (on/off)

local io = io
local table = table
local string = string
local pcall = pcall
local tostring = tostring
local os = os

_G.DSXWriter = _G.DSXWriter or {}
local DSX = _G.DSXWriter

local PAYLOAD_CANDIDATE = "DualSenseX/payload.json"
local MAPPING_NAME = "weapon_dsx.lua"

DSX.out_path     = nil
DSX.mapping      = {}
DSX.last_applied = 0
DSX.ready        = false

-----------------------------------------------------------------------
-- Найти файл payload.json (DSX его мониторит)
-----------------------------------------------------------------------
local function find_payload()
    -- Пробуем несколько путей
    local tries = {
        "DualSenseX/payload.json",
        "DualsenseX/payload.json",
        "reframework/data/DualSenseX/payload.json",
    }
    for _, path in ipairs(tries) do
        local f = io.open(path, "rb")
        if f then
            f:close()
            return path
        end
    end
    return nil
end

DSX.out_path = find_payload()
DSX.ready = (DSX.out_path ~= nil)

-----------------------------------------------------------------------
-- Собрать JSON строку из таблицы инструкций
-- (без зависимости от json-библиотеки — собираем вручную)
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
-- Записать payload в файл
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
-- Payload для сброса триггеров (всё в Normal)
-----------------------------------------------------------------------
function DSX.payload_reset()
    return build({
        { type = 1, parameters = { 0, 1, 0 } },        -- L2: Normal
        { type = 1, parameters = { 0, 2, 0 } },        -- R2: Normal
        { type = 2, parameters = { 0, 0, 0, 0 } },     -- LED: off
    })
end

-----------------------------------------------------------------------
-- Загрузить маппинг оружие→профиль из weapon_dsx.lua
-----------------------------------------------------------------------
local function load_mapping()
    DSX.mapping = {}
    if not DSX.out_path then return DSX.mapping end

    local base = DSX.out_path:match("^(.*)[/\\]payload%.json$")
    local tries = {
        base and (base .. "/" .. MAPPING_NAME),
        base and (base .. "\\" .. MAPPING_NAME),
        "reframework/data/DualSenseX/" .. MAPPING_NAME,
        "DualSenseX/" .. MAPPING_NAME,
        MAPPING_NAME,
    }

    for _, p in ipairs(tries) do
        if p then
            local fh = io.open(p, "rb")
            if fh then
                local src = fh:read("*a")
                fh:close()
                local chunk = load(src)
                if chunk then
                    local ok, ret = pcall(chunk)
                    if ok and type(ret) == "table" then
                        -- Нормализуем ключи в lowercase
                        local norm = {}
                        for k, v in pairs(ret) do
                            norm[tostring(k):lower()] = v
                        end
                        DSX.mapping = norm
                        return DSX.mapping
                    end
                end
            end
        end
    end
    return DSX.mapping
end

-----------------------------------------------------------------------
-- Найти профиль для оружия по info {name, type, id}
-- Приоритет: type:xxx → id → подстрока имени → default
-----------------------------------------------------------------------
local function find_mapping_for_info(info)
    if not info then return nil end
    local type_l = info.type and tostring(info.type):lower():gsub("%s", "") or nil
    local id_l   = info.id and tostring(info.id) or nil
    local name_l = info.name and tostring(info.name):lower() or nil

    -- 1. По типу: "type:hg", "type:sg" и т.д.
    if type_l and DSX.mapping["type:" .. type_l] then
        return DSX.mapping["type:" .. type_l]
    end
    if type_l and DSX.mapping[type_l] then
        return DSX.mapping[type_l]
    end

    -- 2. По числовому ID
    if id_l and DSX.mapping[id_l] then
        return DSX.mapping[id_l]
    end

    -- 3. По подстроке имени
    if name_l then
        for key, v in pairs(DSX.mapping) do
            if key ~= "default" and name_l:find(key, 1, true) then
                return v
            end
        end
    end

    -- 4. Фоллбэк
    return DSX.mapping["default"]
end

-----------------------------------------------------------------------
-- Применить профиль триггеров для текущего оружия
-- info = {id, name, type, ammo, ammoMax}
-----------------------------------------------------------------------
function DSX.apply_for_weapon(info)
    if not DSX.out_path then return end
    local mapping = find_mapping_for_info(info)

    if not (mapping and mapping.instructions) then
        write_payload(DSX.payload_reset())
        return
    end

    local instructions_to_build = mapping.instructions

    -- Dry Fire: если патроны = 0, а магазин непустой → лёгкий мёртвый клик на R2
    if info.ammo and info.ammo == 0 and info.ammoMax and info.ammoMax > 0 then
        instructions_to_build = {}
        for _, inst in ipairs(mapping.instructions) do
            if inst.type == 1 and inst.parameters and inst.parameters[2] == 2 then
                -- R2 → заменяем на GameCube mode (лёгкий клик = пустой магазин)
                table.insert(instructions_to_build, { type = 1, parameters = { 0, 2, 1, 0, 8 } })
            else
                table.insert(instructions_to_build, inst)
            end
        end
    end

    write_payload(build(instructions_to_build))
end

-----------------------------------------------------------------------
-- Подписываемся на смену оружия из weapon_equip_core
-----------------------------------------------------------------------
if _G.WeaponEquipCore and _G.WeaponEquipCore.on_weapon_change then
    _G.WeaponEquipCore.on_weapon_change(function(info)
        if not next(DSX.mapping) then load_mapping() end
        pcall(function() DSX.apply_for_weapon(info) end)
    end)
end

function DSX.reload_mapping() load_mapping() end
load_mapping()
