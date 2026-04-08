-- weapon_equip_ui.lua — UI панель в меню REFramework (Insert)
-- Показывает: текущее оружие, патроны, статус DSX, кнопки управления

local imgui = imgui
local os = os

local CORE = _G.WeaponEquipCore or {}
local DSX  = _G.DSXWriter or {}

-- Проверка: DSX недавно получал данные?
local function dsx_ok()
    if not DSX or not DSX.last_applied then return false end
    return (os.time() - DSX.last_applied) < 3
end

re.on_draw_ui(function()
    if imgui.tree_node("DualSenseX RE2 Status") then

        -- Вкл/Выкл
        local enabled = CORE.config and CORE.config.enabled or false
        local changed, new_val = imgui.checkbox("Enable Adaptive Triggers", enabled)
        if changed then
            if CORE.config then CORE.config.enabled = new_val end
            -- При выключении — сбрасываем триггеры в Normal
            if not new_val and DSX.payload_reset and DSX.out_path then
                local p = DSX.payload_reset()
                local f = io.open(DSX.out_path, "wb")
                if f then f:write(p); f:close() end
            end
        end

        imgui.separator()

        -- Кнопка перезагрузки профилей (без перезапуска игры)
        if imgui.button("Reload Trigger Configs") then
            if DSX.reload_mapping then
                DSX.reload_mapping()
                if CORE.last_info and DSX.apply_for_weapon then
                    DSX.apply_for_weapon(CORE.last_info)
                end
            end
        end

        imgui.separator()

        -- Статус подключения
        if DSX.out_path then
            imgui.text("Payload File: OK (" .. DSX.out_path .. ")")
        else
            imgui.text("Payload File: MISSING — check reframework/data/DualSenseX/payload.json")
        end

        if dsx_ok() then
            imgui.text("DSX Link: ACTIVE")
        else
            imgui.text("DSX Link: WAITING...")
        end

        imgui.separator()

        -- Информация о текущем оружии
        imgui.text("---- Current Weapon ----")
        local info = CORE.last_info
        if info and info.name then
            imgui.text("Weapon: " .. tostring(info.name))
            imgui.text("Type:   " .. tostring(info.type))
            imgui.text("ID:     " .. tostring(info.id))
            imgui.text("Ammo:   " .. tostring(info.ammo) .. " / " .. tostring(info.ammoMax))
        else
            imgui.text("Waiting for game...")
        end

        imgui.tree_pop()
    end
end)
