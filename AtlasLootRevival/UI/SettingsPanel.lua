local _, ns = ...

local SettingsPanel = ns:RegisterModule("SettingsPanel", {})

local PANEL_WIDTH = 300
local PANEL_HEIGHT = 300
local markerOrder = { "small", "normal", "large" }

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function CreateBackdropFrame(frameType, parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame(frameType, nil, parent, template)
    if frame.SetBackdrop then
        frame:SetBackdrop(backdrop)
        frame:SetBackdropColor(0.025, 0.025, 0.025, 0.99)
        frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    end
    return frame
end

local function GetSettings()
    local database = ns.modules.Database.data
    return database and database.settings
end

local function CreateCheckbox(parent, label, top, callback)
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(20, 20)
    checkbox:SetPoint("TOPLEFT", 14, top)
    checkbox:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    checkbox:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    checkbox:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    checkbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    checkbox.label:SetText(label)
    checkbox:SetHitRectInsets(0, -checkbox.label:GetStringWidth() - 7, 0, 0)
    checkbox:SetScript("OnClick", function(clicked)
        callback(clicked:GetChecked() and true or false)
    end)
    return checkbox
end

local function CreateChoiceButton(parent, label, left)
    local button = CreateBackdropFrame("Button", parent)
    button:SetSize(82, 24)
    button:SetPoint("TOPLEFT", left, -174)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    return button
end

local function SetChoiceSelected(button, selected)
    if selected then
        button:SetBackdropColor(0.30, 0.21, 0.07, 0.98)
        button:SetBackdropBorderColor(0.82, 0.58, 0.20, 1)
        button.label:SetTextColor(1, 0.82, 0.38)
    else
        button:SetBackdropColor(0.055, 0.055, 0.055, 0.98)
        button:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        button.label:SetTextColor(0.82, 0.82, 0.82)
    end
end

function SettingsPanel:Create(parent, anchor)
    if self.frame then
        return
    end

    local panel = CreateBackdropFrame("Frame", parent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
    panel:SetFrameLevel(parent:GetFrameLevel() + 60)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, -14)
    title:SetText(ns.L.OPTIONS)
    title:SetTextColor(1, 0.82, 0.38)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(27, 27)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function()
        SettingsPanel:Hide()
    end)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 12, -40)
    divider:SetPoint("TOPRIGHT", -12, -40)
    divider:SetHeight(1)
    divider:SetColorTexture(0.25, 0.21, 0.12, 1)

    self.showMinimap = CreateCheckbox(panel, ns.L.SHOW_MINIMAP_BUTTON, -49,
        function(checked)
            ns.modules.MinimapButton:SetShown(checked, true)
        end)
    self.autoSelect = CreateCheckbox(panel, ns.L.AUTO_SELECT_INSTANCE, -79,
        function(checked)
            local settings = GetSettings()
            if settings then
                settings.browser.autoSelectCurrentInstance = checked
            end
        end)
    self.showDropEstimates = CreateCheckbox(panel, ns.L.SHOW_DROP_ESTIMATES, -109,
        function(checked)
            local settings = GetSettings()
            if settings then
                settings.browser.showDropEstimates = checked
            end
            ns.modules.MainWindow:RefreshLoot()
        end)

    local markerLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markerLabel:SetPoint("TOPLEFT", 15, -148)
    markerLabel:SetText(ns.L.MAP_MARKER_SIZE)
    markerLabel:SetTextColor(0.62, 0.62, 0.62)

    local markerLabels = {
        small = ns.L.MARKER_SMALL,
        normal = ns.L.MARKER_NORMAL,
        large = ns.L.MARKER_LARGE,
    }
    self.markerButtons = {}
    for index, markerSize in ipairs(markerOrder) do
        local button = CreateChoiceButton(panel, markerLabels[markerSize],
            14 + ((index - 1) * 89))
        button.markerSize = markerSize
        button:SetScript("OnClick", function(clicked)
            ns.modules.MainWindow:SetMapMarkerSize(clicked.markerSize, true)
            SettingsPanel:Refresh()
        end)
        self.markerButtons[markerSize] = button
    end

    local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", 15, -214)
    scaleLabel:SetText(ns.L.WINDOW_SCALE)
    scaleLabel:SetTextColor(0.62, 0.62, 0.62)

    self.scaleValue = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.scaleValue:SetPoint("TOPRIGHT", -15, -214)
    self.scaleValue:SetTextColor(1, 0.82, 0.38)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetPoint("TOPLEFT", 15, -232)
    slider:SetSize(270, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(0.75, 1.25)
    slider:SetValueStep(0.05)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 3, 0)
    track:SetPoint("RIGHT", -3, 0)
    track:SetHeight(4)
    track:SetColorTexture(0.24, 0.24, 0.24, 1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(16, 24)
    end
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value * 20) + 0.5) / 20
        SettingsPanel.scaleValue:SetText(string.format("%d%%",
            math.floor((value * 100) + 0.5)))
        if not SettingsPanel.refreshing then
            ns.modules.MainWindow:SetWindowScale(value)
            ns.modules.MainWindow:SavePosition()
        end
    end)
    self.scaleSlider = slider

    local reset = CreateBackdropFrame("Button", panel)
    reset:SetPoint("BOTTOMLEFT", 14, 14)
    reset:SetPoint("BOTTOMRIGHT", -14, 14)
    reset:SetHeight(25)
    reset.label = reset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    reset.label:SetPoint("CENTER")
    reset.label:SetText(ns.L.RESET_WINDOW)
    reset:SetScript("OnEnter", function()
        reset:SetBackdropBorderColor(0.82, 0.58, 0.20, 1)
        reset.label:SetTextColor(1, 0.82, 0.38)
    end)
    reset:SetScript("OnLeave", function()
        reset:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        reset.label:SetTextColor(1, 1, 1)
    end)
    reset:SetScript("OnClick", function()
        ns.modules.MainWindow:ResetPosition()
        SettingsPanel:Refresh()
    end)
    self.resetButton = reset

    panel:Hide()
    self.frame = panel
end

function SettingsPanel:Refresh()
    local settings = GetSettings()
    if not self.frame or not settings then
        return
    end

    self.refreshing = true
    self.showMinimap:SetChecked(settings.minimap.shown ~= false)
    self.autoSelect:SetChecked(settings.browser.autoSelectCurrentInstance ~= false)
    self.showDropEstimates:SetChecked(settings.browser.showDropEstimates ~= false)
    local markerSize = settings.map.markerSize or "normal"
    for key, button in pairs(self.markerButtons) do
        SetChoiceSelected(button, key == markerSize)
    end
    local windowScale = ns.modules.MainWindow.windowScale or 1
    self.scaleValue:SetText(string.format("%d%%",
        math.floor((windowScale * 100) + 0.5)))
    self.scaleSlider:SetValue(windowScale)
    self.refreshing = false
end

function SettingsPanel:Toggle()
    if not self.frame then
        return
    end
    if self.frame:IsShown() then
        self:Hide()
        return
    end

    local mainWindow = ns.modules.MainWindow
    if mainWindow.instanceMenu then
        mainWindow.instanceMenu:Hide()
    end
    if mainWindow.floorMenu then
        mainWindow.floorMenu:Hide()
    end
    if mainWindow.mapClusterMenu then
        mainWindow.mapClusterMenu:Hide()
    end
    if mainWindow.feedbackDialog then
        mainWindow.feedbackDialog.editBox:ClearFocus()
        mainWindow.feedbackDialog:Hide()
    end
    self:Refresh()
    self.frame:Show()
end

function SettingsPanel:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
