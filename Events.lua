local _, ns = ...

local spell_name_api = C_Spell and C_Spell.GetSpellName or GetSpellInfo

local SWING_CONSUME_SPELLS = {}
local SWING_RESET_SPELLS = {}

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

function ns:HandleSwingResolved(is_offhand)
    self:UpdateWeaponSpeeds()

    if is_offhand and self.state.dual_wield then
        self:RestartOffTimer()
        return
    end

    self:RestartMainTimer()
end

function ns:HandleCombatLogEvent()
    local _, subevent, _, source_guid, _, _, _, _, _, _, _, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10 = CombatLogGetCurrentEventInfo()

    if source_guid ~= self.state.player_guid then
        return
    end

    if subevent == "SWING_DAMAGE" then
        self:HandleSwingResolved(arg10)
        return
    end

    if subevent == "SWING_MISSED" then
        self:HandleSwingResolved(arg2)
        return
    end

    if subevent == "SPELL_CAST_SUCCESS" and arg2 and SWING_RESET_SPELLS[arg2] then
        self:DebugPrint("Reset swing from spell cast: " .. arg2)
        self:RestartMainTimer()
        return
    end

    if (subevent == "SPELL_DAMAGE" or subevent == "SPELL_MISSED") and arg2 and SWING_CONSUME_SPELLS[arg2] then
        self:DebugPrint("Consumed swing with spell: " .. arg2)
        self:RestartMainTimer()
    end
end

function ns:PLAYER_ENTERING_WORLD()
    self.state.player_guid = UnitGUID("player")
    self:UpdateWeaponSpeeds()
    self:RefreshBars(true)
end

function ns:PLAYER_EQUIPMENT_CHANGED()
    self:UpdateWeaponSpeeds()
    self:RefreshBars(true)
end

function ns:UNIT_INVENTORY_CHANGED(unit_token)
    if unit_token ~= "player" then
        return
    end

    self:UpdateWeaponSpeeds()
    self:RefreshBars(true)
end

function ns:UNIT_ATTACK_SPEED(unit_token)
    if unit_token ~= "player" then
        return
    end

    self:UpdateWeaponSpeeds()
end

function ns:COMBAT_LOG_EVENT_UNFILTERED()
    self:HandleCombatLogEvent()
end

function ns:ADDON_LOADED(loaded_addon)
    if loaded_addon ~= self.name then
        return
    end

    self:InitializeAddon()
end

local event_frame = CreateFrame("Frame")
event_frame:RegisterEvent("ADDON_LOADED")
event_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
event_frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
event_frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
event_frame:RegisterEvent("UNIT_ATTACK_SPEED")
event_frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
event_frame:SetScript("OnEvent", function(_, event, ...)
    local handler = ns[event]
    if handler then
        handler(ns, ...)
    end
end)