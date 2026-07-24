local _, ns = ...

local string_format = string.format
local string_sub = string.sub
local string_upper = string.upper
local math_min = math.min
local math_abs = math.abs
local math_max = math.max
local math_floor = math.floor
local ipairs = ipairs

local MAIN_HAND_SLOT = INVSLOT_MAINHAND or 16
local OFF_HAND_SLOT = INVSLOT_OFFHAND or 17
local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"

function ns:GetMarkerIconMode()
    if not self.db then
        return "weapon"
    end

    local mode = string.lower(tostring(self.db.icon_mode or "weapon"))
    if mode ~= "weapon" and mode ~= "spark" then
        return "weapon"
    end

    return mode
end

function ns:GetSyncWindowSeconds()
    if not self.db then
        return 0.50
    end

    local window = self:Clamp(self.db.sync_window_seconds or 0.50, 0.05, 1.00)
    self.db.sync_window_seconds = window
    return window
end

function ns:GetMarkerBrightness()
    if not self.db then
        return 1.00
    end

    local brightness = self:Clamp(self.db.marker_brightness or 1.00, 0.30, 2.00)
    self.db.marker_brightness = brightness
    return brightness
end

function ns:GetWeaponIconTexture(slot_id)
    return GetInventoryItemTexture("player", slot_id)
end

function ns:ApplyMarkerTexture(icon, slot_id, tint)
    if not icon then
        return
    end

    local mode = self:GetMarkerIconMode()
    local texture = nil

    if mode == "weapon" then
        texture = self:GetWeaponIconTexture(slot_id)
    end

    if texture then
        icon:SetTexture(texture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetBlendMode("ADD")
    else
        icon:SetTexture(SPARK_TEXTURE)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetBlendMode("ADD")
    end

    icon.spark_red = tint[1]
    icon.spark_green = tint[2]
    icon.spark_blue = tint[3]
    icon.spark_active_alpha = tint[4]
    icon.spark_inactive_alpha = tint[5]
end

function ns:RefreshIconTextures()
    if not self.ui then
        return
    end

    self:ApplyMarkerTexture(self.ui.main_icon, MAIN_HAND_SLOT, { 1.00, 0.94, 0.20, 0.98, 0.75 })
    self:ApplyMarkerTexture(self.ui.off_icon, OFF_HAND_SLOT, { 0.42, 0.70, 1.00, 0.82, 0.48 })
    self:UpdateBarVisibility()
end

local function create_bar(parent, global_name, label)
    local bar = CreateFrame("StatusBar", global_name, parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    bar.background = background

    local border_top = bar:CreateTexture(nil, "BORDER")
    border_top:SetColorTexture(0, 0, 0, 0.9)
    border_top:SetPoint("TOPLEFT", -1, 1)
    border_top:SetPoint("TOPRIGHT", 1, 1)
    border_top:SetHeight(1)

    local border_bottom = bar:CreateTexture(nil, "BORDER")
    border_bottom:SetColorTexture(0, 0, 0, 0.9)
    border_bottom:SetPoint("BOTTOMLEFT", -1, -1)
    border_bottom:SetPoint("BOTTOMRIGHT", 1, -1)
    border_bottom:SetHeight(1)

    local border_left = bar:CreateTexture(nil, "BORDER")
    border_left:SetColorTexture(0, 0, 0, 0.9)
    border_left:SetPoint("TOPLEFT", -1, 1)
    border_left:SetPoint("BOTTOMLEFT", -1, -1)
    border_left:SetWidth(1)

    local border_right = bar:CreateTexture(nil, "BORDER")
    border_right:SetColorTexture(0, 0, 0, 0.9)
    border_right:SetPoint("TOPRIGHT", 1, 1)
    border_right:SetPoint("BOTTOMRIGHT", 1, -1)
    border_right:SetWidth(1)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(label)
    bar.text = text

    return bar
end

local function create_checkbox(parent, label, point, offset_x, offset_y)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetPoint(point, parent, point, offset_x, offset_y)

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", checkbox, "RIGHT", 4, 1)
    text:SetText(label)
    checkbox.label = text

    return checkbox
end

local function create_slider(parent, label, min_value, max_value, step, offset_x, offset_y)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", offset_x, offset_y)
    slider:SetMinMaxValues(min_value, max_value)
    slider:SetValueStep(step)
    slider:SetWidth(220)

    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 6)
    text:SetText(label)
    slider.label = text

    local value_text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value_text:SetPoint("LEFT", slider, "RIGHT", 12, 0)
    value_text:SetWidth(64)
    value_text:SetJustifyH("LEFT")
    slider.value_text = value_text

    return slider
end

local function create_dropdown(parent, global_name, label, offset_x, offset_y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", offset_x, offset_y)
    text:SetText(label)

    local dropdown = CreateFrame("Frame", global_name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", offset_x - 16, offset_y - 18)
    UIDropDownMenu_SetWidth(dropdown, width)

    return dropdown
end

local function preset_display_name(name)
    name = tostring(name or "")
    if name == "" then
        return "Unknown"
    end

    return string_upper(string_sub(name, 1, 1)) .. string_sub(name, 2)
end

function ns:SavePosition()
    if not self.ui or not self.db then
        return
    end

    local frame = self.ui
    local parent = UIParent
    local frame_x = frame:GetCenter()
    local parent_x = parent:GetCenter()

    if not frame_x or not parent_x then
        return
    end

    local frame_y = select(2, frame:GetCenter())
    local parent_y = select(2, parent:GetCenter())

    self.db.point.x = math.floor((frame_x - parent_x) + 0.5)
    self.db.point.y = math.floor((frame_y - parent_y) + 0.5)
end

function ns:UpdateBarVisibility()
    if not self.ui or not self.db then
        return
    end

    local width = self.db.width
    local height = self.db.height

    self.ui.sync_bar:ClearAllPoints()
    self.ui.sync_bar:SetPoint("TOP", self.ui, "TOP", 0, 0)
    self.ui.sync_bar:SetSize(width, height)

    local icon_mode = self:GetMarkerIconMode()
    if icon_mode == "weapon" then
        local icon_size = math_max(22, math_floor(height * 1.35))
        self.ui.main_icon:SetSize(icon_size, icon_size)
        self.ui.off_icon:SetSize(icon_size, icon_size)
    else
        local spark_width = math_max(18, math_floor(height * 1.1))
        local spark_height = height + 12
        self.ui.main_icon:SetSize(spark_width, spark_height)
        self.ui.off_icon:SetSize(spark_width, spark_height)
    end

    self.ui.mid_marker:ClearAllPoints()
    self.ui.mid_marker:SetPoint("TOP", self.ui.sync_bar, "TOP", 0, 0)
    self.ui.mid_marker:SetPoint("BOTTOM", self.ui.sync_bar, "BOTTOM", 0, 0)

    if self.ui.mid_marker_glow then
        self.ui.mid_marker_glow:ClearAllPoints()
        self.ui.mid_marker_glow:SetPoint("TOP", self.ui.sync_bar, "TOP", 0, 1)
        self.ui.mid_marker_glow:SetPoint("BOTTOM", self.ui.sync_bar, "BOTTOM", 0, -1)
    end

    if self.ui.mid_label then
        self.ui.mid_label:ClearAllPoints()
        self.ui.mid_label:SetPoint("BOTTOM", self.ui.sync_bar, "TOP", 0, 2)
    end

    self.ui:SetSize(width, height)

    self:UpdateTextVisibility()

    if self.state.dual_wield then
        self.ui.off_icon:Show()
    else
        self.ui.off_icon:Hide()
    end
end

function ns:UpdateTextVisibility()
    if not self.ui or not self.db then
        return
    end

    if self.ui.main_icon_label then
        if self.db.show_mh_text then
            self.ui.main_icon_label:Show()
        else
            self.ui.main_icon_label:Hide()
        end
    end

    if self.ui.off_icon_label then
        if self.state.dual_wield and self.db.show_oh_text then
            self.ui.off_icon_label:Show()
        else
            self.ui.off_icon_label:Hide()
        end
    end

    if self.ui.mid_label then
        if self.db.show_mid_text then
            self.ui.mid_label:Show()
        else
            self.ui.mid_label:Hide()
        end
    end
end

function ns:UpdateIconDisplay(icon, timer, progress, is_active)
    if not icon or not self.ui or not self.db then
        return
    end

    local width = self.db.width
    local clamped = self:Clamp(progress, 0, 1)
    local offset = clamped * width

    icon:ClearAllPoints()
    icon:SetPoint("CENTER", self.ui.sync_bar, "LEFT", offset, 0)

    local red = icon.spark_red or 1
    local green = icon.spark_green or 1
    local blue = icon.spark_blue or 1
    local alpha
    local brightness = self:GetMarkerBrightness()

    if is_active then
        alpha = icon.spark_active_alpha or 1
    else
        alpha = icon.spark_inactive_alpha or 0.65
    end

    icon:SetVertexColor(
        self:Clamp(red * brightness, 0, 1),
        self:Clamp(green * brightness, 0, 1),
        self:Clamp(blue * brightness, 0, 1),
        self:Clamp(alpha * brightness, 0, 1)
    )
end

function ns:UpdateSyncBarDisplay(now)
    now = now or self:Now()

    local main_timer = self.state.timers.main
    local off_timer = self.state.timers.off
    local main_progress, main_remaining = self:GetTimerProgress(main_timer, now)
    local off_progress, off_remaining = self:GetTimerProgress(off_timer, now)

    self:TraceTimerTick(main_timer, main_progress, main_remaining, now)
    if self.state.dual_wield then
        self:TraceTimerTick(off_timer, off_progress, off_remaining, now)
    end

    self:UpdateIconDisplay(self.ui.main_icon, main_timer, main_progress, main_timer.active)

    if self.state.dual_wield then
        self.ui.off_icon:Show()
        self:UpdateIconDisplay(self.ui.off_icon, off_timer, off_progress, off_timer.active)
    else
        self.ui.off_icon:Hide()
    end

    self:UpdateTextVisibility()

    local red, green, blue, alpha
    local min_remaining = main_remaining
    local dual_active = self.state.dual_wield and main_timer.active and off_timer.active
    local sync_diff = dual_active and math_abs(main_remaining - off_remaining) or nil
    local sync_window = self:GetSyncWindowSeconds()
    local is_synced = dual_active and sync_diff and sync_diff <= sync_window

    if self.state.dual_wield then
        min_remaining = math_min(main_remaining, off_remaining)
    end

    if is_synced then
        red, green, blue, alpha = self:GetColor("ready")
    elseif dual_active then
        red, green, blue, alpha = self:GetColor("warning")
    elseif main_timer.active or (self.state.dual_wield and off_timer.active) then
        if self.db.latency_warning and min_remaining <= self:GetLatencyThreshold() then
            red, green, blue, alpha = self:GetColor("warning")
        else
            red, green, blue, alpha = self:GetColor("active")
        end
    else
        red, green, blue, alpha = self:GetColor("ready")
    end

    local main_value = main_timer.active and main_remaining or 0
    local off_value = off_timer.active and off_remaining or 0
    local shown_diff = sync_diff or math_abs(main_value - off_value)
    local sync_label = is_synced and "SYNC OK" or "SYNC OUT"
    local direction_label = "DIR --"

    if dual_active then
        if main_remaining < off_remaining then
            direction_label = "DIR MH first"
        elseif main_remaining > off_remaining then
            direction_label = "DIR OH first"
        else
            direction_label = "DIR even"
        end
    end

    local sections = {}
    if self.db.show_mh_text then
        sections[#sections + 1] = string_format("MH %.2f", main_value)
    end
    if self.state.dual_wield and self.db.show_oh_text then
        sections[#sections + 1] = string_format("OH %.2f", off_value)
    end
    if self.state.dual_wield and self.db.show_diff_text then
        sections[#sections + 1] = string_format("DIFF %.2f", shown_diff)
    end
    if self.state.dual_wield and self.db.show_sync_text then
        sections[#sections + 1] = sync_label
        sections[#sections + 1] = direction_label
    end
    local status_text = table.concat(sections, "  |  ")

    self.ui.sync_bar:SetStatusBarColor(red, green, blue, alpha)
    self.ui.sync_bar:SetValue(1)
    self.ui.sync_bar.background:SetColorTexture(self:GetColor("background"))
    self.ui.sync_bar.text:SetText(status_text)
end

function ns:RefreshBars(force)
    if not self.ui or not self.db then
        return
    end

    local now = self:Now()

    if force or self.ui.sync_bar:IsShown() then
        self:UpdateSyncBarDisplay(now)
    end
end

function ns:UpdateTicking()
    if not self.ui then
        return
    end

    if self:IsAnyTimerActive() then
        if self.ui.is_ticking then
            return
        end

        self.ui.elapsed = 0
        self.ui:SetScript("OnUpdate", function(frame, elapsed)
            frame.elapsed = frame.elapsed + elapsed
            if frame.elapsed < 0.02 then
                return
            end

            frame.elapsed = 0
            ns:RefreshBars(false)
        end)
        self.ui.is_ticking = true
        return
    end

    if self.ui.is_ticking then
        self.ui:SetScript("OnUpdate", nil)
        self.ui.is_ticking = false
        self:RefreshBars(true)
    end
end

function ns:ApplySettings()
    if not self.ui or not self.db then
        return
    end

    self.ui:ClearAllPoints()
    self.ui:SetPoint("CENTER", UIParent, "CENTER", self.db.point.x, self.db.point.y)
    self.ui:SetScale(self.db.scale)
    self.ui:SetAlpha(self.db.alpha)
    self.ui:EnableMouse(not self.db.locked)

    self:UpdateBarVisibility()

    if self.RefreshConfigPanel then
        self:RefreshConfigPanel()
    end
end

function ns:RefreshConfigPanel()
    local panel = self.config_panel
    if not panel or not self.db then
        return
    end

    panel.syncing = true

    panel.lock_checkbox:SetChecked(self.db.locked)
    panel.debug_checkbox:SetChecked(self.db.debug)
    panel.ticks_checkbox:SetChecked(self.db.trace_ticks)
    panel.mh_text_checkbox:SetChecked(self.db.show_mh_text)
    panel.oh_text_checkbox:SetChecked(self.db.show_oh_text)
    panel.mid_text_checkbox:SetChecked(self.db.show_mid_text)
    panel.diff_text_checkbox:SetChecked(self.db.show_diff_text)
    panel.sync_text_checkbox:SetChecked(self.db.show_sync_text)

    panel.width_slider:SetValue(self.db.width)
    panel.width_slider.value_text:SetText(string_format("%.0f", self.db.width))

    panel.height_slider:SetValue(self.db.height)
    panel.height_slider.value_text:SetText(string_format("%.0f", self.db.height))

    panel.scale_slider:SetValue(self.db.scale)
    panel.scale_slider.value_text:SetText(string_format("%.2f", self.db.scale))

    panel.sync_slider:SetValue(self:GetSyncWindowSeconds())
    panel.sync_slider.value_text:SetText(string_format("%.2fs", self.db.sync_window_seconds))

    panel.brightness_slider:SetValue(self:GetMarkerBrightness())
    panel.brightness_slider.value_text:SetText(string_format("%.2fx", self.db.marker_brightness))

    local icon_mode = self:GetMarkerIconMode()
    UIDropDownMenu_SetSelectedValue(panel.icon_dropdown, icon_mode)
    UIDropDownMenu_SetText(panel.icon_dropdown, icon_mode == "spark" and "Spark" or "Weapon")

    UIDropDownMenu_SetSelectedValue(panel.colors_dropdown, self.db.color_preset)
    UIDropDownMenu_SetText(panel.colors_dropdown, preset_display_name(self.db.color_preset))

    panel.syncing = false
end

function ns:CreateConfigPanel()
    if self.config_panel then
        return
    end

    local panel = CreateFrame("Frame", "SwingPulseConfigPanel", UIParent)
    panel:SetSize(360, 640)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(current)
        current:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(current)
        current:StopMovingOrSizing()
    end)

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.05, 0.05, 0.06, 0.95)

    local border_top = panel:CreateTexture(nil, "BORDER")
    border_top:SetColorTexture(0.92, 0.76, 0.30, 0.95)
    border_top:SetPoint("TOPLEFT", panel, "TOPLEFT", -1, 1)
    border_top:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 1, 1)
    border_top:SetHeight(1)

    local border_bottom = panel:CreateTexture(nil, "BORDER")
    border_bottom:SetColorTexture(0.92, 0.76, 0.30, 0.95)
    border_bottom:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -1, -1)
    border_bottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, -1)
    border_bottom:SetHeight(1)

    local border_left = panel:CreateTexture(nil, "BORDER")
    border_left:SetColorTexture(0.92, 0.76, 0.30, 0.95)
    border_left:SetPoint("TOPLEFT", panel, "TOPLEFT", -1, 1)
    border_left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -1, -1)
    border_left:SetWidth(1)

    local border_right = panel:CreateTexture(nil, "BORDER")
    border_right:SetColorTexture(0.92, 0.76, 0.30, 0.95)
    border_right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 1, 1)
    border_right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, -1)
    border_right:SetWidth(1)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12)
    title:SetText("SwingPulse Configuration")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Toggle with /swingpulse config or /sp ui")

    local close_top = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close_top:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)

    panel.lock_checkbox = create_checkbox(panel, "Lock Frame", "TOPLEFT", 16, -58)
    panel.lock_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.locked = current:GetChecked() and true or false
        ns:ApplyAllSettings()
    end)

    panel.debug_checkbox = create_checkbox(panel, "Debug Output", "TOPLEFT", 16, -84)
    panel.debug_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.debug = current:GetChecked() and true or false
    end)

    panel.ticks_checkbox = create_checkbox(panel, "Tick Trace", "TOPLEFT", 16, -110)
    panel.ticks_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.trace_ticks = current:GetChecked() and true or false
    end)

    panel.mh_text_checkbox = create_checkbox(panel, "Show MH Speed", "TOPLEFT", 16, -136)
    panel.mh_text_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.show_mh_text = current:GetChecked() and true or false
        ns:ApplyAllSettings()
    end)

    panel.oh_text_checkbox = create_checkbox(panel, "Show OH Speed", "TOPLEFT", 16, -162)
    panel.oh_text_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.show_oh_text = current:GetChecked() and true or false
        ns:ApplyAllSettings()
    end)

    panel.mid_text_checkbox = create_checkbox(panel, "Show MID Label", "TOPLEFT", 16, -188)
    panel.mid_text_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.show_mid_text = current:GetChecked() and true or false
        ns:ApplyAllSettings()
    end)

    panel.diff_text_checkbox = create_checkbox(panel, "Show Diff Speed", "TOPLEFT", 16, -214)
    panel.diff_text_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.show_diff_text = current:GetChecked() and true or false
        ns:ApplyAllSettings()
    end)

    panel.sync_text_checkbox = create_checkbox(panel, "Show Sync Status", "TOPLEFT", 16, -240)
    panel.sync_text_checkbox:SetScript("OnClick", function(current)
        if panel.syncing then
            return
        end

        ns.db.show_sync_text = current:GetChecked() and true or false
        ns:ApplyAllSettings()
    end)

    panel.width_slider = create_slider(panel, "Bar Width", 120, 480, 1, 18, -284)
    panel.width_slider:SetScript("OnValueChanged", function(current, value)
        local rounded = math_floor(value + 0.5)
        current.value_text:SetText(string_format("%.0f", rounded))

        if panel.syncing then
            return
        end

        ns.db.width = ns:Clamp(rounded, 120, 480)
        ns:ApplyAllSettings()
    end)

    panel.height_slider = create_slider(panel, "Bar Height", 10, 40, 1, 18, -340)
    panel.height_slider:SetScript("OnValueChanged", function(current, value)
        local rounded = math_floor(value + 0.5)
        current.value_text:SetText(string_format("%.0f", rounded))

        if panel.syncing then
            return
        end

        ns.db.height = ns:Clamp(rounded, 10, 40)
        ns:ApplyAllSettings()
    end)

    panel.scale_slider = create_slider(panel, "Frame Scale", 0.75, 2.0, 0.01, 18, -396)
    panel.scale_slider:SetScript("OnValueChanged", function(current, value)
        local rounded = math_floor((value * 100) + 0.5) / 100
        current.value_text:SetText(string_format("%.2f", rounded))

        if panel.syncing then
            return
        end

        ns.db.scale = ns:Clamp(rounded, 0.75, 2.0)
        ns:ApplyAllSettings()
    end)

    panel.sync_slider = create_slider(panel, "Sync Window", 0.05, 1.0, 0.01, 18, -450)
    panel.sync_slider:SetScript("OnValueChanged", function(current, value)
        local rounded = math_floor((value * 100) + 0.5) / 100
        current.value_text:SetText(string_format("%.2fs", rounded))

        if panel.syncing then
            return
        end

        ns.db.sync_window_seconds = ns:Clamp(rounded, 0.05, 1.0)
        ns:RefreshBars(true)
    end)

    panel.brightness_slider = create_slider(panel, "Marker Brightness", 0.30, 2.0, 0.01, 18, -504)
    panel.brightness_slider:SetScript("OnValueChanged", function(current, value)
        local rounded = math_floor((value * 100) + 0.5) / 100
        current.value_text:SetText(string_format("%.2fx", rounded))

        if panel.syncing then
            return
        end

        ns.db.marker_brightness = ns:Clamp(rounded, 0.30, 2.0)
        ns:RefreshBars(true)
    end)

    panel.icon_dropdown = create_dropdown(panel, "SwingPulseIconModeDropDown", "Marker Style", 16, -556, 128)
    UIDropDownMenu_Initialize(panel.icon_dropdown, function(current)
        local options = {
            { text = "Weapon", value = "weapon" },
            { text = "Spark", value = "spark" },
        }

        local index
        for index = 1, #options do
            local option = options[index]
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function(button)
                UIDropDownMenu_SetSelectedValue(current, button.value)
                if panel.syncing then
                    return
                end

                ns.db.icon_mode = button.value
                ns:RefreshIconTextures()
                ns:ApplyAllSettings()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    panel.colors_dropdown = create_dropdown(panel, "SwingPulseColorPresetDropDown", "Color Preset", 182, -556, 128)
    UIDropDownMenu_Initialize(panel.colors_dropdown, function(current)
        local options = {
            { text = "Ember", value = "ember" },
            { text = "Tide", value = "tide" },
            { text = "Ash", value = "ash" },
        }

        local index
        for index = 1, #options do
            local option = options[index]
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function(button)
                UIDropDownMenu_SetSelectedValue(current, button.value)
                if panel.syncing then
                    return
                end

                ns:ApplyColorPreset(button.value, true)
                ns:RefreshConfigPanel()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    local reset_button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset_button:SetSize(112, 22)
    reset_button:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 10)
    reset_button:SetText("Reset Defaults")
    reset_button:SetScript("OnClick", function()
        ns:ResetSettings()
        ns:RefreshConfigPanel()
    end)

    local help_button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    help_button:SetSize(84, 22)
    help_button:SetPoint("LEFT", reset_button, "RIGHT", 8, 0)
    help_button:SetText("Print Help")
    help_button:SetScript("OnClick", function()
        ns:PrintHelp()
    end)

    local close_button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    close_button:SetSize(70, 22)
    close_button:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 10)
    close_button:SetText("Close")
    close_button:SetScript("OnClick", function()
        panel:Hide()
    end)

    panel:Hide()

    self.config_panel = panel
end

function ns:ToggleConfigPanel()
    if not self.config_panel then
        self:CreateConfigPanel()
    end

    if self.config_panel:IsShown() then
        self.config_panel:Hide()
        return
    end

    self:RefreshConfigPanel()
    self.config_panel:Show()
    self.config_panel:Raise()
end

function ns:CreateUI()
    if self.ui then
        return
    end

    local frame = CreateFrame("Frame", "SwingPulseFrame", UIParent)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(current)
        if ns.db and not ns.db.locked then
            current:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(current)
        current:StopMovingOrSizing()
        ns:SavePosition()
        ns:ApplySettings()
    end)

    frame.sync_bar = create_bar(frame, "SwingPulseSyncBar", "")
    frame.sync_bar:SetValue(1)

    local mid_marker_glow = frame.sync_bar:CreateTexture(nil, "ARTWORK")
    mid_marker_glow:SetColorTexture(1.00, 1.00, 1.00, 0.30)
    mid_marker_glow:SetWidth(6)
    frame.mid_marker_glow = mid_marker_glow

    local mid_marker = frame.sync_bar:CreateTexture(nil, "OVERLAY")
    mid_marker:SetColorTexture(1.00, 1.00, 1.00, 0.98)
    mid_marker:SetWidth(3)
    frame.mid_marker = mid_marker

    local mid_label = frame.sync_bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mid_label:SetText("MID")
    mid_label:SetTextColor(1, 1, 1, 0.92)
    mid_label:SetShadowOffset(1, -1)
    mid_label:SetShadowColor(0, 0, 0, 1)
    frame.mid_label = mid_label

    local main_icon = frame.sync_bar:CreateTexture(nil, "OVERLAY")
    main_icon:SetTexture(SPARK_TEXTURE)
    main_icon:SetBlendMode("ADD")
    main_icon.spark_red = 1.00
    main_icon.spark_green = 0.94
    main_icon.spark_blue = 0.20
    main_icon.spark_active_alpha = 0.98
    main_icon.spark_inactive_alpha = 0.75
    frame.main_icon = main_icon

    local main_icon_label = frame.sync_bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    main_icon_label:SetPoint("CENTER", main_icon, "CENTER", 0, 0)
    main_icon_label:SetText("MH")
    main_icon_label:SetTextColor(1, 1, 1, 0.95)
    main_icon_label:SetShadowOffset(1, -1)
    main_icon_label:SetShadowColor(0, 0, 0, 1)
    frame.main_icon_label = main_icon_label

    local off_icon = frame.sync_bar:CreateTexture(nil, "OVERLAY")
    off_icon:SetTexture(SPARK_TEXTURE)
    off_icon:SetBlendMode("ADD")
    off_icon.spark_red = 0.42
    off_icon.spark_green = 0.70
    off_icon.spark_blue = 1.00
    off_icon.spark_active_alpha = 0.58
    off_icon.spark_inactive_alpha = 0.35
    frame.off_icon = off_icon

    local off_icon_label = frame.sync_bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    off_icon_label:SetPoint("CENTER", off_icon, "CENTER", 0, 0)
    off_icon_label:SetText("OH")
    off_icon_label:SetTextColor(1, 1, 1, 0.95)
    off_icon_label:SetShadowOffset(1, -1)
    off_icon_label:SetShadowColor(0, 0, 0, 1)
    frame.off_icon_label = off_icon_label

    self.ui = frame
    self:RefreshIconTextures()
    self:ApplySettings()
    self:RefreshBars(true)
end
