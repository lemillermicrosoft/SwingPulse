local _, ns = ...

local string_format = string.format

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

    local show_offhand = self.db.show_offhand and self.state.dual_wield
    local width = self.db.width
    local height = self.db.height
    local spacing = self.db.spacing

    self.ui.main_bar:ClearAllPoints()
    self.ui.main_bar:SetPoint("TOP", self.ui, "TOP", 0, 0)
    self.ui.main_bar:SetSize(width, height)

    self.ui.off_bar:ClearAllPoints()
    self.ui.off_bar:SetPoint("TOP", self.ui.main_bar, "BOTTOM", 0, -spacing)
    self.ui.off_bar:SetSize(width, height)

    if show_offhand then
        self.ui.off_bar:Show()
        self.ui:SetSize(width, (height * 2) + spacing)
    else
        self.ui.off_bar:Hide()
        self.ui:SetSize(width, height)
    end
end

function ns:UpdateBarDisplay(bar, timer, now)
    now = now or self:Now()

    local progress, remaining = self:GetTimerProgress(timer, now)
    local red, green, blue, alpha

    if timer.active then
        if self.db.latency_warning and remaining <= self:GetLatencyThreshold() then
            red, green, blue, alpha = self:GetColor("warning")
        else
            red, green, blue, alpha = self:GetColor("active")
        end

        bar.text:SetText(string_format("%s %.1f", timer.label, remaining))
    else
        red, green, blue, alpha = self:GetColor("ready")
        bar.text:SetText(timer.label)
    end

    bar:SetStatusBarColor(red, green, blue, alpha)
    bar:SetValue(progress)
    bar.background:SetColorTexture(self:GetColor("background"))
end

function ns:RefreshBars(force)
    if not self.ui or not self.db then
        return
    end

    local now = self:Now()

    if force or self.ui.main_bar:IsShown() then
        self:UpdateBarDisplay(self.ui.main_bar, self.state.timers.main, now)
    end

    if self.ui.off_bar:IsShown() then
        self:UpdateBarDisplay(self.ui.off_bar, self.state.timers.off, now)
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

    frame.main_bar = create_bar(frame, "SwingPulseMainBar", self.state.timers.main.label)
    frame.off_bar = create_bar(frame, "SwingPulseOffBar", self.state.timers.off.label)

    self.ui = frame
    self:ApplySettings()
    self:RefreshBars(true)
end