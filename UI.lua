local _, ns = ...

local string_format = string.format
local math_min = math.min
local math_abs = math.abs
local math_max = math.max

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

    local spark_width = math_max(18, math.floor(height * 1.1))
    local spark_height = height + 12
    self.ui.main_icon:SetSize(spark_width, spark_height)
    self.ui.off_icon:SetSize(spark_width, spark_height)

    self.ui.mid_marker:ClearAllPoints()
    self.ui.mid_marker:SetPoint("TOP", self.ui.sync_bar, "TOP", 0, 0)
    self.ui.mid_marker:SetPoint("BOTTOM", self.ui.sync_bar, "BOTTOM", 0, 0)

    self.ui:SetSize(width, height)

    if self.state.dual_wield then
        self.ui.off_icon:Show()
    else
        self.ui.off_icon:Hide()
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

    if is_active then
        alpha = icon.spark_active_alpha or 1
    else
        alpha = icon.spark_inactive_alpha or 0.65
    end

    icon:SetVertexColor(red, green, blue, alpha)
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

    local red, green, blue, alpha
    local min_remaining = main_remaining
    local dual_active = self.state.dual_wield and main_timer.active and off_timer.active
    local sync_diff = dual_active and math_abs(main_remaining - off_remaining) or nil
    local sync_window = 0.08

    if self.state.dual_wield then
        min_remaining = math_min(main_remaining, off_remaining)
    end

    if dual_active and sync_diff <= sync_window then
        red, green, blue, alpha = self:GetColor("ready")
    elseif dual_active and main_remaining > off_remaining then
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

    local status_text
    if self.state.dual_wield then
        local main_value = main_timer.active and main_remaining or 0
        local off_value = off_timer.active and off_remaining or 0
        local shown_diff = sync_diff or math_abs(main_value - off_value)
        status_text = string_format("MH %.1f   |   OH %.1f   |   DIFF %.1f", main_value, off_value, shown_diff)
    else
        local main_value = main_timer.active and main_remaining or 0
        status_text = string_format("MH %.1f", main_value)
    end

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

    local mid_marker = frame.sync_bar:CreateTexture(nil, "ARTWORK")
    mid_marker:SetColorTexture(0.95, 0.95, 0.95, 0.95)
    mid_marker:SetWidth(2)
    frame.mid_marker = mid_marker

    local main_icon = frame.sync_bar:CreateTexture(nil, "OVERLAY")
    main_icon:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    main_icon:SetBlendMode("ADD")
    main_icon.spark_red = 1.00
    main_icon.spark_green = 0.94
    main_icon.spark_blue = 0.20
    main_icon.spark_active_alpha = 0.98
    main_icon.spark_inactive_alpha = 0.75
    frame.main_icon = main_icon

    local off_icon = frame.sync_bar:CreateTexture(nil, "OVERLAY")
    off_icon:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    off_icon:SetBlendMode("ADD")
    off_icon.spark_red = 0.42
    off_icon.spark_green = 0.70
    off_icon.spark_blue = 1.00
    off_icon.spark_active_alpha = 0.58
    off_icon.spark_inactive_alpha = 0.35
    frame.off_icon = off_icon

    self.ui = frame
    self:ApplySettings()
    self:RefreshBars(true)
end