local addon_name, ns = ...

ns = ns or {}
_G.SwingPulse = ns

ns.name = addon_name
ns.initialized = false
ns.db = ns.db or nil
ns.ui = ns.ui or nil
ns.state = ns.state or {
    player_guid = nil,
    dual_wield = false,
    active_count = 0,
    timers = {
        main = {
            key = "main",
            label = "MH",
            active = false,
            start_time = 0,
            duration = 0,
            expires_at = 0,
        },
        off = {
            key = "off",
            label = "OH",
            active = false,
            start_time = 0,
            duration = 0,
            expires_at = 0,
        },
    },
}

local math_max = math.max
local math_min = math.min
local pairs = pairs
local table_unpack = unpack or table.unpack
local type = type

function ns:Clamp(value, minimum, maximum)
    value = tonumber(value)
    if not value then
        return minimum
    end

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end

function ns:CloneTable(source)
    local copy = {}

    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = self:CloneTable(value)
        else
            copy[key] = value
        end
    end

    return copy
end

function ns:MergeDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return target
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = self:CloneTable(value)
            else
                self:MergeDefaults(target[key], value)
            end
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function ns:Print(message)
    local prefix = "|cff7dd67dSwingPulse|r"
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. " " .. tostring(message))
end

function ns:DebugPrint(message)
    if self.db and self.db.debug then
        self:Print("[debug] " .. tostring(message))
    end
end

function ns:Now()
    return GetTime() or 0
end

function ns:GetLatencyThreshold()
    if not self.db or not self.db.latency_warning then
        return 0
    end

    local _, _, home_ms, world_ms = GetNetStats()
    local threshold_ms = math_max(home_ms or 0, world_ms or 0)

    return self:Clamp(threshold_ms / 1000, 0.05, 0.40)
end

function ns:GetColor(key)
    local colors = self.db and self.db.colors
    local color = colors and colors[key]

    if not color then
        return 1, 1, 1, 1
    end

    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

function ns:RecountActiveTimers()
    local active_count = 0

    if self.state.timers.main.active then
        active_count = active_count + 1
    end

    if self.state.dual_wield and self.state.timers.off.active then
        active_count = active_count + 1
    end

    self.state.active_count = active_count

    if self.UpdateTicking then
        self:UpdateTicking()
    end
end

function ns:ResetTimer(timer, keep_duration)
    if not timer then
        return
    end

    timer.active = false
    timer.start_time = 0
    timer.expires_at = 0

    if not keep_duration then
        timer.duration = 0
    end

    self:RecountActiveTimers()
end

function ns:StartTimer(timer, duration, start_time)
    if not timer then
        return
    end

    duration = tonumber(duration) or 0
    if duration <= 0 then
        self:ResetTimer(timer, false)
        return
    end

    start_time = tonumber(start_time) or self:Now()
    timer.active = true
    timer.start_time = start_time
    timer.duration = duration
    timer.expires_at = start_time + duration

    self:RecountActiveTimers()
end

function ns:GetTimerProgress(timer, now)
    if not timer then
        return 1, 0
    end

    now = now or self:Now()

    if timer.duration <= 0 then
        return 1, 0
    end

    if not timer.active then
        return 1, 0
    end

    local remaining = math_max(timer.expires_at - now, 0)
    local progress = 1 - (remaining / timer.duration)

    if remaining <= 0 then
        timer.active = false
        self:RecountActiveTimers()
        progress = 1
    end

    return self:Clamp(progress, 0, 1), remaining
end

function ns:IsAnyTimerActive()
    return self.state.active_count > 0
end

function ns:UpdateWeaponSpeeds()
    local main_speed, off_speed = UnitAttackSpeed("player")
    local main_timer = self.state.timers.main
    local off_timer = self.state.timers.off

    if main_speed and main_speed > 0 then
        main_timer.duration = main_speed
    end

    if off_speed and off_speed > 0 then
        self.state.dual_wield = true
        off_timer.duration = off_speed
    else
        self.state.dual_wield = false
        self:ResetTimer(off_timer, false)
    end

    if self.UpdateBarVisibility then
        self:UpdateBarVisibility()
    end

    self:DebugPrint(string.format("Weapon speeds updated: main=%.3f off=%s", main_timer.duration or 0, off_speed and string.format("%.3f", off_speed) or "n/a"))
end

function ns:RestartMainTimer()
    self:StartTimer(self.state.timers.main, self.state.timers.main.duration)

    if self.RefreshBars then
        self:RefreshBars(true)
    end
end

function ns:RestartOffTimer()
    self:StartTimer(self.state.timers.off, self.state.timers.off.duration)

    if self.RefreshBars then
        self:RefreshBars(true)
    end
end

function ns:ApplyAllSettings()
    if self.ApplySettings then
        self:ApplySettings()
    end

    if self.RefreshBars then
        self:RefreshBars(true)
    end
end

function ns:InitializeAddon()
    if self.initialized then
        return
    end

    self:InitializeDatabase()
    self:CreateUI()
    self:RegisterSlashCommands()
    self.state.player_guid = UnitGUID("player")
    self:UpdateWeaponSpeeds()
    self:ApplyAllSettings()
    self.initialized = true
end

ns.unpack = table_unpack