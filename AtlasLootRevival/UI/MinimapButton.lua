local _, ns = ...

local MinimapButton = ns:RegisterModule("MinimapButton", {})

local BUTTON_SIZE = 32
local ICON_SIZE = 20
local MINIMAP_RADIUS = 80
local DEFAULT_ANGLE = 225

local function NormalizeAngle(angle)
    angle = tonumber(angle) or DEFAULT_ANGLE
    return angle % 360
end

local function Atan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 then
        return math.atan(y / x) - math.pi
    elseif y > 0 then
        return math.pi / 2
    elseif y < 0 then
        return -math.pi / 2
    end

    return 0
end

function MinimapButton:SetAngle(angle, save)
    angle = NormalizeAngle(angle)
    self.angle = angle

    if self.button then
        local radians = math.rad(angle)
        self.button:ClearAllPoints()
        self.button:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(radians) * MINIMAP_RADIUS,
            math.sin(radians) * MINIMAP_RADIUS)
    end

    if save then
        local database = ns.modules.Database.data
        if database then
            database.settings.minimap.angle = angle
        end
    end
end

function MinimapButton:UpdateDragPosition()
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    local scale = UIParent:GetEffectiveScale()
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local angle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))
    self:SetAngle(angle, true)
end

function MinimapButton:Create()
    if self.button or not Minimap then
        return
    end

    local button = CreateFrame("Button", "AtlasLootRevivalMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetClampedToScreen(true)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\minimap-icon.tga")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnEnter", function(entered)
        GameTooltip:SetOwner(entered, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns.Constants.DISPLAY_NAME, 1, 0.82, 0)
        GameTooltip:AddLine("Left-click to toggle", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            MinimapButton.justDragged = false
        end
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" and not MinimapButton.justDragged then
            ns.modules.MainWindow:Toggle()
        end
        MinimapButton.justDragged = false
    end)
    button:SetScript("OnDragStart", function(dragged)
        MinimapButton.justDragged = true
        GameTooltip:Hide()
        dragged:SetScript("OnUpdate", function()
            MinimapButton:UpdateDragPosition()
        end)
    end)
    button:SetScript("OnDragStop", function(dragged)
        dragged:SetScript("OnUpdate", nil)
        MinimapButton:UpdateDragPosition()
    end)

    self.button = button
    self.icon = icon
    self:SetAngle(ns.modules.Database.data.settings.minimap.angle, false)
end

function MinimapButton:Initialize()
    self:Create()
end
