local _, ns = ...

local spell_name_api = C_Spell and C_Spell.GetSpellName or GetSpellInfo

local SWING_CONSUME_SPELLS = {}
local SWING_RESET_SPELLS = {}

local function tostring_or_nil(value)
    if value == nil then
        return "nil"
    end

    return tostring(value)
end

local function register_spell_names(target, ids, fallback_names)
    local index

    for index = 1, #ids do
        local spell_name = spell_name_api(ids[index])
        if spell_name then
            target[spell_name] = true
        end
    end

    for index = 1, #fallback_names do
        target[fallback_names[index]] = true
    end
end

register_spell_names(SWING_CONSUME_SPELLS, { 78, 845, 6807, 2973, 56815 }, {
    "Heroic Strike",
    "Cleave",
    "Maul",
    "Raptor Strike",
    "Rune Strike",
})

register_spell_names(SWING_RESET_SPELLS, { 1464 }, {
    "Slam",
})

local RANGED_AUTO_SHOT_SPELLS = {}
register_spell_names(RANGED_AUTO_SHOT_SPELLS, { 75, 5019 }, {
    "Auto Shot",
    "Shoot",
    "Shoot Bow",
    "Shoot Gun",
    "Shoot Crossbow",
})

function ns:HandleSwingResolved(is_offhand)
    local resolved_at = self:Now()
    local start_time = resolved_at - self:GetLatencyCompensation()
    local compensation = self:GetLatencyCompensation()
    local timer = self.state.timers.main

    if is_offhand and self.state.dual_wield then
        timer = self.state.timers.off
    end

    local drift_ms = self:GetTimerDriftMs(timer, resolved_at)

    self:RecordDriftSample(timer, drift_ms)

    self:UpdateWeaponSpeeds()

    if is_offhand and self.state.dual_wield then
        self:DebugPrint(string.format(
            "reset OH start=%.3f duration=%.3f compensation=%.3f driftMs=%s",
            start_time,
            self.state.timers.off.duration or 0,
            compensation,
            drift_ms and string.format("%.1f", drift_ms) or "n/a"
        ))
        self:RestartOffTimer(start_time)
        return
    end

    self:DebugPrint(string.format(
        "reset MH start=%.3f duration=%.3f compensation=%.3f driftMs=%s",
        start_time,
        self.state.timers.main.duration or 0,
        compensation,
        drift_ms and string.format("%.1f", drift_ms) or "n/a"
    ))
    self:RestartMainTimer(start_time)
end

function ns:HandleCombatLogEvent()
    local _, subevent, _, source_guid, _, _, _, _, _, _, _, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 = CombatLogGetCurrentEventInfo()

    if source_guid ~= self.state.player_guid then
        return
    end

    if self:IsDebugEnabled() then
        if subevent == "SWING_DAMAGE" then
            self:DebugPrint(string.format(
                "clog %s amount=%s offhand=%s school=%s absorbed=%s crit=%s glancing=%s",
                subevent,
                tostring_or_nil(arg1),
                tostring_or_nil(arg10),
                tostring_or_nil(arg3),
                tostring_or_nil(arg7),
                tostring_or_nil(arg8),
                tostring_or_nil(arg9)
            ))
        elseif subevent == "SWING_MISSED" then
            self:DebugPrint(string.format(
                "clog %s miss=%s offhand=%s amountMissed=%s",
                subevent,
                tostring_or_nil(arg1),
                tostring_or_nil(arg2),
                tostring_or_nil(arg3)
            ))
        end
    end

    if subevent == "SWING_DAMAGE" then
        self:HandleSwingResolved(arg10)
        return
    end

    if subevent == "SWING_MISSED" then
        self:HandleSwingResolved(arg2)
        return
    end

    if subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED" then
        -- A landed ranged shot is definitive proof the player is in ranged mode,
        -- even if START_AUTOREPEAT_SPELL hasn't fired yet on this session.
        self.state.ranged_active = true
        if self:ShouldUseRangedMode() then
            self:HandleSwingResolved(false)
        end
        return
    end

    if subevent == "SPELL_CAST_SUCCESS" and arg2 and SWING_RESET_SPELLS[arg2] then
        self:DebugPrint("Reset swing from spell cast: " .. arg2)
        self:RestartMainTimer(self:Now() - self:GetLatencyCompensation())
        return
    end

    if (subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED") and arg2 and SWING_CONSUME_SPELLS[arg2] then
        self:DebugPrint("Consumed swing with spell: " .. arg2)
        self:RestartMainTimer(self:Now() - self:GetLatencyCompensation())
    end
end

function ns:PLAYER_ENTERING_WORLD()
    self.state.player_guid = UnitGUID("player")
    self:UpdateWeaponSpeeds()

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end

    self:RefreshBars(true)
end

function ns:PLAYER_EQUIPMENT_CHANGED()
    self:UpdateWeaponSpeeds()

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end

    self:RefreshBars(true)
end

function ns:UNIT_INVENTORY_CHANGED(unit_token)
    if unit_token ~= "player" then
        return
    end

    self:UpdateWeaponSpeeds()

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end

    self:RefreshBars(true)
end

function ns:UNIT_ATTACK_SPEED(unit_token)
    if unit_token ~= "player" then
        return
    end

    self:UpdateWeaponSpeeds()
end

function ns:START_AUTOREPEAT_SPELL()
    self.state.ranged_active = true
    self:UpdateWeaponSpeeds()

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end

    self:RefreshBars(true)
end

function ns:UNIT_SPELLCAST_SENT(unit_token, _, _, spell_name)
    if unit_token ~= "player" then
        return
    end

    if not spell_name or not RANGED_AUTO_SHOT_SPELLS[spell_name] then
        return
    end

    -- Casting Auto Shot / Shoot is definitive proof of ranged mode; prime the flag
    -- so the first shot of a session isn't dropped by a stale ShouldUseRangedMode().
    self.state.ranged_active = true

    if not self:ShouldUseRangedMode() then
        return
    end

    -- NOTE: do NOT restart the swing timer here. The cast SENT event fires
    -- before the projectile actually leaves the weapon, so resetting the bar
    -- now makes it look like the timer ends before the shot fires. The
    -- RANGE_DAMAGE / RANGE_MISSED combat-log branch is the ground-truth
    -- "shot landed" signal and is the only place we restart the timer.
    self:DebugPrint("ranged cast SENT: " .. spell_name)
end

function ns:UNIT_SPELLCAST_START(unit_token, _, spell_id)
    if unit_token ~= "player" then
        return
    end

    local spell_name = spell_id and spell_name_api(spell_id) or nil
    if not spell_name or not RANGED_AUTO_SHOT_SPELLS[spell_name] then
        return
    end

    self.state.ranged_active = true

    if not self:ShouldUseRangedMode() then
        return
    end

    -- See UNIT_SPELLCAST_SENT: priming ranged_active is the only work we do here.
    -- Ranged timer restarts belong to RANGE_DAMAGE / RANGE_MISSED, not to cast start.
    self:DebugPrint("ranged cast START: " .. spell_name)
end

function ns:STOP_AUTOREPEAT_SPELL()
    self.state.ranged_active = false
    self:UpdateWeaponSpeeds()

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end

    self:RefreshBars(true)
end

function ns:PLAYER_REGEN_DISABLED()
    if self.StartNickChallenge then
        self:StartNickChallenge(self:Now())
    end
end

function ns:COMBAT_LOG_EVENT_UNFILTERED()
    self:HandleCombatLogEvent()
end

function ns:ADDON_LOADED(loaded_addon)
    if loaded_addon ~= self.name then
        return
    end

    self:InitializeAddon()

    if self.RefreshIconTextures then
        self:RefreshIconTextures()
    end
end

local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
event_frame:RegisterEvent("UNIT_ATTACK_SPEED")
event_frame:RegisterEvent("START_AUTOREPEAT_SPELL")
event_frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
event_frame:RegisterEvent("UNIT_SPELLCAST_SENT")
event_frame:RegisterEvent("UNIT_SPELLCAST_START")
event_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
event_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
event_frame:SetScript("OnEvent", function(_, event, ...)
    local handler = ns[event]
    if handler then
        handler(ns, ...)
    end
end)