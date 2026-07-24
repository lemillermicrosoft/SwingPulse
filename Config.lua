local _, ns = ...

ns.defaults = {
    width = 220,
    height = 18,
    spacing = 6,
    scale = 1,
    alpha = 1,
    locked = false,
    show_offhand = true,
    latency_warning = true,
    compensate_latency = true,
    trace_ticks = false,
    debug = false,
    sync_window_seconds = 0.50,
    icon_mode = "weapon",
    marker_brightness = 1.00,
    main_marker_brightness = 1.00,
    off_marker_brightness = 1.00,
    color_preset = "ember",
    show_mh_text = false,
    show_oh_text = false,
    show_mid_text = false,
    show_diff_text = false,
    show_sync_text = false,
    point = {
        x = 0,
        y = -140,
    },
    colors = {
        active = { 0.92, 0.67, 0.17, 1 },
        ready = { 0.19, 0.79, 0.35, 1 },
        warning = { 0.90, 0.26, 0.18, 1 },
        background = { 0.07, 0.07, 0.09, 0.72 },
    },
}

ns.color_presets = {
    ember = {
        active = { 0.92, 0.67, 0.17, 1 },
        ready = { 0.19, 0.79, 0.35, 1 },
        warning = { 0.90, 0.26, 0.18, 1 },
        background = { 0.07, 0.07, 0.09, 0.72 },
    },
    tide = {
        active = { 0.18, 0.66, 0.88, 1 },
        ready = { 0.22, 0.82, 0.48, 1 },
        warning = { 0.95, 0.53, 0.18, 1 },
        background = { 0.05, 0.08, 0.11, 0.72 },
    },
    ash = {
        active = { 0.78, 0.78, 0.82, 1 },
        ready = { 0.44, 0.83, 0.57, 1 },
        warning = { 0.88, 0.33, 0.29, 1 },
        background = { 0.09, 0.09, 0.10, 0.78 },
    },
}

local function tokenize(message)
    local args = {}

    for token in string.gmatch(message or "", "%S+") do
        args[#args + 1] = token
    end

    return args
end

function ns:InitializeDatabase()
    if type(_G.SwingPulseDB) ~= "table" then
        _G.SwingPulseDB = {}
    end

    self.db = _G.SwingPulseDB
    local had_main_brightness = self.db.main_marker_brightness ~= nil
    local had_off_brightness = self.db.off_marker_brightness ~= nil
    self:MergeDefaults(self.db, self.defaults)

    local legacy_brightness = self:Clamp(self.db.marker_brightness or 1.00, 0.30, 2.00)
    self.db.marker_brightness = legacy_brightness

    if not had_main_brightness then
        self.db.main_marker_brightness = legacy_brightness
    end

    if not had_off_brightness then
        self.db.off_marker_brightness = legacy_brightness
    end

    if not self.color_presets[self.db.color_preset] then
        self.db.color_preset = self.defaults.color_preset
    end

    self:ApplyColorPreset(self.db.color_preset, true)
end

function ns:ApplyColorPreset(preset_name, silent)
    local preset = self.color_presets[preset_name]
    if not preset then
        if not silent then
            self:Print("Unknown color preset: " .. tostring(preset_name))
        end

        return false
    end

    self.db.color_preset = preset_name
    self.db.colors = self:CloneTable(preset)

    if self.ApplyAllSettings then
        self:ApplyAllSettings()
    end

    if not silent then
        self:Print("Color preset set to " .. preset_name .. ".")
    end

    return true
end

function ns:ResetSettings()
    _G.SwingPulseDB = self:CloneTable(self.defaults)
    self.db = _G.SwingPulseDB
    self:ApplyColorPreset(self.db.color_preset, true)
    self:ApplyAllSettings()
    self:UpdateWeaponSpeeds()
    self:Print("Settings reset to defaults.")
end

function ns:SetLocked(locked)
    self.db.locked = not not locked
    self:ApplyAllSettings()
    self:Print(self.db.locked and "Frame locked." or "Frame unlocked. Drag with left mouse button to move.")
end

function ns:SetSize(width, height)
    self.db.width = self:Clamp(width, 120, 480)
    self.db.height = self:Clamp(height, 10, 40)
    self:ApplyAllSettings()
    self:Print(string.format("Size set to %dx%d.", self.db.width, self.db.height))
end

function ns:SetScale(scale)
    self.db.scale = self:Clamp(scale, 0.75, 2.0)
    self:ApplyAllSettings()
    self:Print(string.format("Scale set to %.2f.", self.db.scale))
end

function ns:ToggleDebug()
    self.db.debug = not self.db.debug
    self:Print(self.db.debug and "Debug output enabled." or "Debug output disabled.")
end

function ns:SetSyncWindow(seconds)
    self.db.sync_window_seconds = self:Clamp(seconds, 0.05, 1.00)

    if self.RefreshBars then
        self:RefreshBars(true)
    end

    self:Print(string.format("Sync window set to %.2fs.", self.db.sync_window_seconds))
end

function ns:SetIconMode(mode)
    mode = string.lower(tostring(mode or ""))
    if mode ~= "weapon" and mode ~= "spark" then
        self:Print("Usage: /swingpulse icon <weapon|spark>")
        return
    end

    self.db.icon_mode = mode

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end

    self:ApplyAllSettings()
    self:Print("Marker icon mode set to " .. mode .. ".")
end

function ns:SetMarkerBrightness(target, value)
    if value == nil then
        value = target
        target = "all"
    end

    target = string.lower(tostring(target or "all"))
    value = self:Clamp(value, 0.30, 2.00)

    if target == "all" then
        self.db.marker_brightness = value
        self.db.main_marker_brightness = value
        self.db.off_marker_brightness = value
    elseif target == "mh" or target == "main" then
        self.db.main_marker_brightness = value
    elseif target == "oh" or target == "off" then
        self.db.off_marker_brightness = value
    else
        self:Print("Usage: /swingpulse bright <0.30-2.00> or /swingpulse bright <mh|oh|all> <0.30-2.00>")
        return
    end

    self:ApplyAllSettings()
    self:Print(string.format(
        "Marker brightness - MH: %.2fx, OH: %.2fx.",
        self.db.main_marker_brightness,
        self.db.off_marker_brightness
    ))
end

function ns:PrintHelp()
    self:Print("Commands: lock, unlock, size <w> <h>, scale <n>, sync <seconds>, icon <weapon|spark>, bright <0.30-2.00>|<mh|oh|all> <0.30-2.00>, colors <ember|tide|ash>, text <mh|oh|mid|all> [on|off|toggle], reset, debug, ticks, config")
end

function ns:SetTextVisibility(target, mode)
    target = string.lower(tostring(target or ""))
    mode = string.lower(tostring(mode or "toggle"))

    if target ~= "mh" and target ~= "oh" and target ~= "mid" and target ~= "all" then
        self:Print("Usage: /swingpulse text <mh|oh|mid|all> [on|off|toggle]")
        return
    end

    if mode ~= "on" and mode ~= "off" and mode ~= "toggle" then
        self:Print("Usage: /swingpulse text <mh|oh|mid|all> [on|off|toggle]")
        return
    end

    local apply_mode = function(current)
        if mode == "on" then
            return true
        end

        if mode == "off" then
            return false
        end

        return not current
    end

    if target == "mh" or target == "all" then
        self.db.show_mh_text = apply_mode(self.db.show_mh_text)
    end

    if target == "oh" or target == "all" then
        self.db.show_oh_text = apply_mode(self.db.show_oh_text)
    end

    if target == "mid" or target == "all" then
        self.db.show_mid_text = apply_mode(self.db.show_mid_text)
    end

    self:ApplyAllSettings()

    self:Print(string.format(
        "Text labels - MH: %s, OH: %s, MID: %s",
        self.db.show_mh_text and "on" or "off",
        self.db.show_oh_text and "on" or "off",
        self.db.show_mid_text and "on" or "off"
    ))
end

function ns:RegisterSlashCommands()
    if self.slash_registered then
        return
    end

    SLASH_SWINGPULSE1 = "/swingpulse"
    SLASH_SWINGPULSE2 = "/sp"
    SlashCmdList.SWINGPULSE = function(message)
        local args = tokenize(message)
        local command = string.lower(args[1] or "")

        if command == "" or command == "help" then
            ns:PrintHelp()
            return
        end

        if command == "lock" then
            if args[2] == "on" then
                ns:SetLocked(true)
            elseif args[2] == "off" then
                ns:SetLocked(false)
            else
                ns:SetLocked(not ns.db.locked)
            end

            return
        end

        if command == "unlock" then
            ns:SetLocked(false)
            return
        end

        if command == "size" then
            local width = tonumber(args[2])
            local height = tonumber(args[3])

            if not width or not height then
                ns:Print("Usage: /swingpulse size <width> <height>")
                return
            end

            ns:SetSize(width, height)
            return
        end

        if command == "scale" then
            local scale = tonumber(args[2])
            if not scale then
                ns:Print("Usage: /swingpulse scale <number>")
                return
            end

            ns:SetScale(scale)
            return
        end

        if command == "sync" then
            local seconds = tonumber(args[2])
            if not seconds then
                ns:Print("Usage: /swingpulse sync <seconds>")
                return
            end

            ns:SetSyncWindow(seconds)
            return
        end

        if command == "icon" then
            local mode = string.lower(args[2] or "")
            if mode == "" then
                ns:Print("Usage: /swingpulse icon <weapon|spark>")
                return
            end

            ns:SetIconMode(mode)
            return
        end

        if command == "bright" or command == "brightness" then
            local target = args[2]
            local value = tonumber(args[2])

            if value then
                ns:SetMarkerBrightness("all", value)
                return
            end

            value = tonumber(args[3])
            if not value then
                ns:Print("Usage: /swingpulse bright <0.30-2.00> or /swingpulse bright <mh|oh|all> <0.30-2.00>")
                return
            end

            ns:SetMarkerBrightness(target, value)
            return
        end

        if command == "colors" then
            local preset_name = string.lower(args[2] or "")
            if preset_name == "" then
                ns:Print("Usage: /swingpulse colors <ember|tide|ash>")
                return
            end

            ns:ApplyColorPreset(preset_name, false)
            return
        end

        if command == "text" then
            local target = string.lower(args[2] or "")
            local mode = string.lower(args[3] or "toggle")

            if target == "" then
                ns:Print("Usage: /swingpulse text <mh|oh|mid|all> [on|off|toggle]")
                return
            end

            ns:SetTextVisibility(target, mode)
            return
        end

        if command == "config" or command == "ui" then
            if ns.ToggleConfigPanel then
                ns:ToggleConfigPanel()
            end

            return
        end

        if command == "reset" then
            ns:ResetSettings()
            return
        end

        if command == "debug" then
            ns:ToggleDebug()
            return
        end

        if command == "ticks" then
            local mode = string.lower(args[2] or "")

            if mode == "on" then
                ns.db.trace_ticks = true
                ns:Print("Tick trace enabled.")
                return
            end

            if mode == "off" then
                ns.db.trace_ticks = false
                ns:Print("Tick trace disabled.")
                return
            end

            ns.db.trace_ticks = not ns.db.trace_ticks
            ns:Print(ns.db.trace_ticks and "Tick trace enabled." or "Tick trace disabled.")
            return
        end

        ns:PrintHelp()
    end

    self.slash_registered = true
end