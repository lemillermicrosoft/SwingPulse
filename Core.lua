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
    ranged_active = false,
    ranged_weapon = false,
    active_count = 0,
    nick = {
        title_enabled = false,
        armed = false,
        active = false,
        started_at = 0,
        ends_at = 0,
        next_sample_at = 0,
        next_feedback_at = 0,
        total_samples = 0,
        synced_samples = 0,
    },
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
local math_floor = math.floor
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

function ns:IsDebugEnabled()
    return self.db and self.db.debug
end

function ns:Now()
    return GetTime() or 0
end

function ns:EnsureNickState()
    local nick = self.state and self.state.nick

    if type(nick) ~= "table" then
        nick = {}
        self.state.nick = nick
    end

    if nick.title_enabled == nil then
        nick.title_enabled = false
    end

    if nick.armed == nil then
        nick.armed = false
    end

    if nick.active == nil then
        nick.active = false
    end

    nick.started_at = tonumber(nick.started_at) or 0
    nick.ends_at = tonumber(nick.ends_at) or 0
    nick.next_sample_at = tonumber(nick.next_sample_at) or 0
    nick.next_feedback_at = tonumber(nick.next_feedback_at) or 0
    nick.total_samples = tonumber(nick.total_samples) or 0
    nick.synced_samples = tonumber(nick.synced_samples) or 0

    return nick
end

function ns:GetLatencyThreshold()
    if not self.db or not self.db.latency_warning then
        return 0
    end

    local _, _, home_ms, world_ms = GetNetStats()
    local threshold_ms = math_max(home_ms or 0, world_ms or 0)

    return self:Clamp(threshold_ms / 1000, 0.05, 0.40)
end

function ns:GetLatencyCompensation()
    if not self.db or self.db.compensate_latency == false then
        return 0
    end

    local _, _, home_ms, world_ms = GetNetStats()
    local round_trip_ms = math_max(home_ms or 0, world_ms or 0)

    return self:Clamp(round_trip_ms / 2000, 0, 0.20)
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
    timer.last_trace_bucket = nil

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

function ns:TraceTimerTick(timer, progress, remaining, now)
    if not timer or not timer.active or not self:IsDebugEnabled() or not (self.db and self.db.trace_ticks) then
        return
    end

    local trace_bucket = math_floor((remaining * 10) + 0.0001)

    if timer.last_trace_bucket == trace_bucket then
        return
    end

    timer.last_trace_bucket = trace_bucket
    now = now or self:Now()
    self:DebugPrint(string.format(
        "tick %s t=%.3f progress=%.3f remaining=%.3f expires=%.3f",
        timer.label,
        now,
        progress,
        remaining,
        timer.expires_at
    ))
end

function ns:GetTimerDriftMs(timer, observed_time)
    if not timer then
        return nil
    end

    observed_time = observed_time or self:Now()
    local reference_expire = timer.expires_at

    if not reference_expire or reference_expire <= 0 then
        return nil
    end

    return (observed_time - reference_expire) * 1000
end

function ns:RecordDriftSample(timer, drift_ms)
    if not timer or not drift_ms then
        return
    end

    local stats = timer.drift_stats
    if not stats then
        stats = {
            count = 0,
            sum = 0,
            min = nil,
            max = nil,
        }
        timer.drift_stats = stats
    end

    stats.count = stats.count + 1
    stats.sum = stats.sum + drift_ms

    if not stats.min or drift_ms < stats.min then
        stats.min = drift_ms
    end

    if not stats.max or drift_ms > stats.max then
        stats.max = drift_ms
    end

    if (stats.count % 5) == 0 then
        local average = stats.sum / stats.count
        self:DebugPrint(string.format(
            "drift %s samples=%d avg=%.1fms min=%.1fms max=%.1fms",
            timer.label,
            stats.count,
            average,
            stats.min,
            stats.max
        ))
    end
end

function ns:IsAnyTimerActive()
    local nick = self:EnsureNickState()
    return self.state.active_count > 0 or nick.active
end

function ns:HasRangedWeaponEquipped()
    local slot_id = (INVSLOT_RANGED) or 18
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot_id)
    if not link then
        return false
    end

    if not GetItemInfo then
        return true
    end

    local _, _, _, _, _, _, subtype = GetItemInfo(link)
    if not subtype then
        return true
    end

    subtype = string.lower(subtype)
    if subtype:find("bow") or subtype:find("gun") or subtype:find("crossbow") or subtype:find("thrown") then
        return true
    end

    return false
end

function ns:ShouldUseRangedMode()
    if not self.state.ranged_active then
        return false
    end

    local mode = (self.db and self.db.ranged_mode) or "auto"
    if mode == "off" then
        return false
    end

    return self:HasRangedWeaponEquipped()
end

function ns:UpdateWeaponSpeeds()
    local main_timer = self.state.timers.main
    local off_timer = self.state.timers.off

    self.state.ranged_weapon = self:HasRangedWeaponEquipped()

    if self:ShouldUseRangedMode() then
        local ranged_speed = UnitRangedDamage and select(1, UnitRangedDamage("player")) or 0
        if ranged_speed and ranged_speed > 0 then
            main_timer.duration = ranged_speed
        end

        self.state.dual_wield = false
        self:ResetTimer(off_timer, false)

        if self.UpdateBarVisibility then
            self:UpdateBarVisibility()
        end

        return
    end

    local main_speed, off_speed = UnitAttackSpeed("player")

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
end

function ns:RestartMainTimer(start_time)
    self:StartTimer(self.state.timers.main, self.state.timers.main.duration, start_time)

    if self.RefreshBars then
        self:RefreshBars(true)
    end
end

function ns:RestartOffTimer(start_time)
    self:StartTimer(self.state.timers.off, self.state.timers.off.duration, start_time)

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
    self:EnsureNickState()
    self:CreateUI()
    self:RegisterSlashCommands()
    self.state.player_guid = UnitGUID("player")
    self:UpdateWeaponSpeeds()
    self:ApplyAllSettings()
    self.initialized = true
end

ns.unpack = table_unpack