-- weapon_equip_ui.lua — UI панель в меню REFramework (Insert)
-- Статус, Force Sync, Reload Profiles, Enable/Disable

local imgui = imgui
local os = os

re.on_draw_ui(function()
    local CORE = _G.WeaponEquipCore
    local DSX  = _G.DSXWriter

    if imgui.tree_node("DualSenseX RE2 Mod") then

        -- Статус модуля
        local core_ready = CORE and CORE.status and CORE.status.ready
        imgui.text("Core:   " .. (core_ready and "READY" or "WAITING..."))
        imgui.text("Writer: " .. (DSX and DSX.status or "NOT LOADED"))

        -- Путь payload.json
        if DSX and DSX.out_path then
            imgui.text("File:   " .. DSX.out_path)
        end

        -- Последняя запись
        if DSX and DSX.last_applied and DSX.last_applied > 0 then
            local ago = os.time() - DSX.last_applied
            imgui.text("Last write: " .. ago .. "s ago")
        end

        imgui.separator()

        -- Информация об оружии
        if CORE and CORE.last_info then
            local info = CORE.last_info
            imgui.text("Weapon:  " .. tostring(info.name))
            imgui.text("Type:    " .. tostring(info.type))
            imgui.text("Ammo:    " .. tostring(info.ammo) .. " / " .. tostring(info.reserve))

            if info.ammo == 0 then
                imgui.text("STATE: EMPTY (Dry Fire)")
            else
                imgui.text("STATE: ACTIVE")
            end
        else
            imgui.text("Waiting for game data... (Equip a weapon)")
        end

        imgui.separator()

        -- Кнопки управления
        if imgui.button("Force Sync Triggers") then
            if DSX and DSX.force_sync then
                DSX.force_sync()
                print("[DualSenseX] Force sync!")
            else
                print("[DualSenseX] Writer not ready")
            end
        end

        if imgui.button("Reload Profiles (weapon_dsx.lua)") then
            if DSX and DSX.reload_mapping then
                DSX.reload_mapping()
                print("[DualSenseX] Profiles reloaded!")
                -- Сразу применяем к текущему оружию
                if DSX.force_sync then DSX.force_sync() end
            end
        end

        if imgui.button("Reset Triggers (Off)") then
            if DSX and DSX.payload_reset then
                local io_mod = io
                local reset = DSX.payload_reset()
                if DSX.out_path then
                    local f = io_mod.open(DSX.out_path, "wb")
                    if f then
                        f:write(reset)
                        f:close()
                        print("[DualSenseX] Triggers reset to OFF")
                    end
                end
            end
        end

        -- Debug: rapid fire + kick
        imgui.separator()
        if DSX then
            imgui.text("Kick active: " .. tostring(DSX._kick_active or false))
            imgui.text("Kick frames: " .. tostring(DSX._kick_frames_left or 0))
            imgui.text("Rapid count: " .. tostring(DSX._rapid_fire_count or 0))
            imgui.text("Rapid cooldown: " .. tostring(DSX._rapid_fire_cooldown or 0))
        end

        -- Enable/Disable
        imgui.separator()
        if CORE and CORE.config then
            local changed, new_val = imgui.checkbox("Enabled", CORE.config.enabled)
            if changed then
                CORE.config.enabled = new_val
                if not new_val and DSX and DSX.payload_reset and DSX.out_path then
                    local f = io.open(DSX.out_path, "wb")
                    if f then f:write(DSX.payload_reset()); f:close() end
                    print("[DualSenseX] Disabled — triggers reset")
                end
            end
        end

        imgui.tree_pop()
    end
end)
