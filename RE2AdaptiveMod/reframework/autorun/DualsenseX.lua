-- DualsenseX RE2 Adaptive Triggers — Entry Point
-- Загружает конфиги из /data/ и модули из /autorun/

local autorun_base = "reframework/autorun/DualsenseX/"
local data_base    = "reframework/data/DualSenseX/"

local function loadf(path, name)
    local p = path .. name
    local f, err = loadfile(p)
    if not f then
        print("[DualsenseX] FAILED to load " .. p .. " | ERR: " .. tostring(err))
        return nil
    end
    print("[DualsenseX] OK: " .. p)
    return f()
end

-- 1. Загружаем конфиг (re2_config делает return {}, сохраняем в глобал)
_G.RE2_CONFIG = loadf(data_base, "re2_config.lua")

-- 2. Загружаем логику (порядок важен: core → writer → ui)
-- Core первый: он регистрирует on_weapon_change
-- Writer второй: он подписывается на callback из Core
-- UI последний: он читает состояние Core и Writer
loadf(autorun_base, "weapon_equip_core.lua")
loadf(autorun_base, "dsx_writer.lua")
loadf(autorun_base, "weapon_equip_ui.lua")

print("[DualsenseX] === RE2 Mod Loaded ===")
