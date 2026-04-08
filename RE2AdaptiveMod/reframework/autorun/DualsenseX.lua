-- DualsenseX RE2 Adaptive Triggers — Entry Point
-- Загружает модули по порядку: ядро → DSX → UI

local base = "reframework/autorun/DualsenseX/"

local function loadf(name)
    local p = base .. name
    local f, err = loadfile(p)
    if not f then
        print("[DualsenseX] FAILED: " .. p .. "  ERR: " .. tostring(err))
        return
    end
    print("[DualsenseX] Loaded: " .. p)
    return f()
end

loadf("weapon_equip_core.lua")
loadf("dsx_writer.lua")
loadf("weapon_equip_ui.lua")
