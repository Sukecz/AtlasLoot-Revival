local _, ns = ...

local MainWindow = ns:RegisterModule("MainWindow", {})

local WINDOW_WIDTH = 940
local WINDOW_HEIGHT = 600
local SIDEBAR_WIDTH = 174
local MAP_LEFT = 198
local MAP_WIDTH = 488
local MAP_HEIGHT = 366
local TILE_SIZE = 122
local MAP_OUTER_PADDING = 8
local MAP_LOOT_GAP = 12
local MAP_RIGHT = MAP_LEFT + MAP_WIDTH + MAP_OUTER_PADDING
local MAP_RIGHT_OFFSET = WINDOW_WIDTH - MAP_RIGHT
local LOOT_PANEL_LEFT = MAP_RIGHT + MAP_LOOT_GAP
local MIN_WINDOW_SCALE = 0.75
local MAX_WINDOW_SCALE = 1.25
local MAX_ENCOUNTER_BUTTONS = 16
local MAX_MAP_PINS = 32
local MAP_CLUSTER_DISTANCE = 30
local MAX_CLUSTER_BUTTONS = 16
local MAX_INSTANCE_MENU_BUTTONS = 16
local MAX_FLOOR_MENU_BUTTONS = 8
local MAX_LOOT_ROWS = 16
local LOOT_ROW_HEIGHT = 24
local LOOT_ROW_STEP = 25
local TRASH_DROPS_KEY = "trash_drops"
local selectedColor = { 0.82, 0.58, 0.20 }
local MAP_MARKER_STYLES = {
    small = { marker = 15, ring = 20, font = 11 },
    normal = { marker = 18, ring = 24, font = 12 },
    large = { marker = 21, ring = 28, font = 14 },
}

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function CreateBackdropFrame(frameType, name, parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame(frameType, name, parent, template)
    if frame.SetBackdrop then
        frame:SetBackdrop(backdrop)
    end
    return frame
end

local function SetBackdropColor(frame, red, green, blue, alpha)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(red, green, blue, alpha)
        frame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    end
end

local function GetItemDisplay(itemID)
    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return name, link, quality, icon
end

local function FormatDropChance(chance)
    local formatted = string.format("%.2f", chance)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
    return formatted
end

local function JoinQuestIDs(questIDs)
    local parts = {}
    for _, questID in ipairs(questIDs or {}) do
        table.insert(parts, tostring(questID))
    end
    return table.concat(parts, ", ")
end

local function SetTruncatedText(fontString, text)
    text = tostring(text or "")
    fontString:SetText(text)

    local availableWidth = fontString:GetWidth()
    if not availableWidth or availableWidth <= 0
        or fontString:GetStringWidth() <= availableWidth then
        return
    end

    local suffix = "..."
    local low = 0
    local high = #text
    while low < high do
        local midpoint = math.ceil((low + high) / 2)
        fontString:SetText(string.sub(text, 1, midpoint) .. suffix)
        if fontString:GetStringWidth() <= availableWidth then
            low = midpoint
        else
            high = midpoint - 1
        end
    end
    fontString:SetText(string.sub(text, 1, low) .. suffix)
end

local function SetButtonHighlight(button, selected)
    if selected then
        button.background:SetColorTexture(selectedColor[1], selectedColor[2], selectedColor[3], 0.22)
        button.label:SetTextColor(1, 0.82, 0.38)
    else
        button.background:SetColorTexture(1, 1, 1, 0.035)
        button.label:SetTextColor(0.82, 0.82, 0.82)
    end
end

local function ShowMapPinRing(pin, alpha)
    if pin.ring.SetDesaturated then
        pin.ring:SetDesaturated(pin.isCluster and true or false)
    end
    if pin.isCluster then
        pin.ring:SetVertexColor(0.12, 0.82, 1)
    else
        pin.ring:SetVertexColor(1, 1, 1)
    end
    pin.ring:SetAlpha(alpha or 1)
    pin.ring:Show()
end

function MainWindow:SetMapMarkerSize(markerSize, save)
    local style = MAP_MARKER_STYLES[markerSize] or MAP_MARKER_STYLES.normal
    markerSize = MAP_MARKER_STYLES[markerSize] and markerSize or "normal"
    self.markerSize = markerSize

    for _, pin in ipairs(self.mapPinRows or {}) do
        pin.marker:SetSize(style.marker, style.marker)
        pin.ring:SetSize(style.ring, style.ring)
        pin.number:SetFont(STANDARD_TEXT_FONT, style.font, "OUTLINE")
    end

    if save then
        local database = ns.modules.Database.data
        if database then
            database.settings.map.markerSize = markerSize
        end
    end
end

local function ClampWindowScale(scale)
    scale = tonumber(scale) or 1
    if scale < MIN_WINDOW_SCALE then
        return MIN_WINDOW_SCALE
    end
    if scale > MAX_WINDOW_SCALE then
        return MAX_WINDOW_SCALE
    end
    return scale
end

local function GetAvailableInstanceKeys(contentType)
    local flavor = ns.Constants.GetClientFlavor()
    local keys = {}
    for key, instance in pairs(ns.Data.instances) do
        if instance.clientFlavors[flavor]
            and instance.contentType == (contentType or "dungeon") then
            table.insert(keys, key)
        end
    end
    table.sort(keys, function(leftKey, rightKey)
        local left = ns.Data.instances[leftKey]
        local right = ns.Data.instances[rightKey]
        if left.levelMin ~= right.levelMin then
            return left.levelMin < right.levelMin
        end
        if left.levelMax ~= right.levelMax then
            return left.levelMax < right.levelMax
        end
        return left.name < right.name
    end)
    return keys
end

local function GetInstanceEntryKeys(instance)
    local keys = {}
    for _, bossKey in ipairs(instance.bosses) do
        table.insert(keys, bossKey)
    end
    table.insert(keys, TRASH_DROPS_KEY)
    return keys
end

function MainWindow:CreateTitle(parent)
    local titleBar = parent:CreateTexture(nil, "BACKGROUND")
    titleBar:SetPoint("TOPLEFT", 5, -5)
    titleBar:SetPoint("TOPRIGHT", -5, -5)
    titleBar:SetHeight(42)
    titleBar:SetColorTexture(0.08, 0.07, 0.055, 1)

    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 15, -12)
    icon:SetTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\minimap-icon.tga")

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 9, 1)
    title:SetText(ns.L.ADDON_NAME)
    title:SetTextColor(0.95, 0.75, 0.30)

    local version = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText("v" .. ns.Constants.VERSION)
    version:SetTextColor(0.48, 0.48, 0.48)

    local close = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -7, -7)
    close:SetScript("OnClick", function()
        if ns.modules.SettingsPanel then
            ns.modules.SettingsPanel:Hide()
        end
        MainWindow.frame:Hide()
    end)

    local settingsButton = CreateFrame("Button", nil, parent)
    settingsButton:SetSize(18, 18)
    settingsButton:SetPoint("RIGHT", close, "LEFT", -3, 0)
    settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
    settingsButton:SetScript("OnEnter", function(entered)
        GameTooltip:SetOwner(entered, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(ns.L.OPTIONS, 1, 0.82, 0.38)
        GameTooltip:Show()
    end)
    settingsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    settingsButton:SetScript("OnClick", function()
        ns.modules.SettingsPanel:Toggle()
    end)
    self.settingsButton = settingsButton
end

function MainWindow:CreateSidebar(parent)
    local panel = CreateBackdropFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 12, -55)
    panel:SetPoint("BOTTOMLEFT", 12, 34)
    panel:SetWidth(SIDEBAR_WIDTH)
    SetBackdropColor(panel, 0.035, 0.035, 0.035, 0.96)

    self.contentTypeButtons = {}
    local contentTypes = {
        { key = "dungeon", label = ns.L.DUNGEONS },
        { key = "raid", label = ns.L.RAIDS },
    }
    for index, contentType in ipairs(contentTypes) do
        local button = CreateFrame("Button", nil, panel)
        button:SetPoint("TOPLEFT", 8 + ((index - 1) * 79), -7)
        button:SetSize(77, 19)
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetPoint("CENTER")
        button.label:SetText(contentType.label)
        button.contentType = contentType.key
        button:SetScript("OnClick", function(clicked)
            MainWindow:SelectContentType(clicked.contentType)
        end)
        self.contentTypeButtons[contentType.key] = button
    end

    local dungeonButton = CreateFrame("Button", nil, panel)
    dungeonButton:SetPoint("TOPLEFT", 8, -30)
    dungeonButton:SetPoint("TOPRIGHT", -8, -30)
    dungeonButton:SetHeight(42)
    dungeonButton.background = dungeonButton:CreateTexture(nil, "BACKGROUND")
    dungeonButton.background:SetAllPoints()
    dungeonButton.background:SetColorTexture(selectedColor[1], selectedColor[2], selectedColor[3], 0.24)
    dungeonButton.label = dungeonButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonButton.label:SetPoint("TOPLEFT", 8, -6)
    dungeonButton.label:SetPoint("TOPRIGHT", -34, -6)
    dungeonButton.label:SetHeight(14)
    dungeonButton.label:SetJustifyH("CENTER")
    dungeonButton.label:SetJustifyV("TOP")
    dungeonButton.label:SetWordWrap(false)
    dungeonButton.label:SetTextColor(1, 0.82, 0.38)
    dungeonButton.range = dungeonButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeonButton.range:SetPoint("BOTTOM", 0, 6)
    dungeonButton.range:SetTextColor(0.55, 0.55, 0.55)
    dungeonButton.arrow = dungeonButton:CreateTexture(nil, "ARTWORK")
    dungeonButton.arrow:SetSize(22, 22)
    dungeonButton.arrow:SetPoint("RIGHT", -6, 0)
    dungeonButton.arrow:SetTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\dropdown-chevron.tga")
    dungeonButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    dungeonButton:SetScript("OnClick", function()
        MainWindow:ToggleInstanceMenu()
    end)
    self.dungeonButton = dungeonButton

    local instanceMenu = CreateBackdropFrame("Frame", nil, parent)
    instanceMenu:SetWidth(266)
    instanceMenu:SetPoint("TOPLEFT", dungeonButton, "TOPRIGHT", 6, 0)
    instanceMenu:SetFrameLevel(parent:GetFrameLevel() + 30)
    instanceMenu:SetClampedToScreen(true)
    SetBackdropColor(instanceMenu, 0.025, 0.025, 0.025, 0.99)
    instanceMenu:EnableMouseWheel(true)
    instanceMenu:SetScript("OnMouseWheel", function(_, delta)
        MainWindow:ScrollInstanceMenu(delta > 0 and -3 or 3)
    end)
    instanceMenu.title = instanceMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instanceMenu.title:SetPoint("TOPLEFT", 10, -9)
    instanceMenu.title:SetTextColor(1, 0.82, 0.38)
    instanceMenu.up = CreateFrame("Button", nil, instanceMenu)
    instanceMenu.up:SetPoint("TOPRIGHT", -31, -5)
    instanceMenu.up:SetSize(22, 22)
    instanceMenu.up:SetNormalTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\dropdown-chevron.tga")
    instanceMenu.up:GetNormalTexture():SetTexCoord(0, 1, 1, 0)
    instanceMenu.up:SetHighlightTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\dropdown-chevron.tga", "ADD")
    instanceMenu.up:GetHighlightTexture():SetTexCoord(0, 1, 1, 0)
    instanceMenu.up:SetScript("OnClick", function()
        MainWindow:ScrollInstanceMenu(-MAX_INSTANCE_MENU_BUTTONS)
    end)
    instanceMenu.down = CreateFrame("Button", nil, instanceMenu)
    instanceMenu.down:SetPoint("LEFT", instanceMenu.up, "RIGHT", 2, 0)
    instanceMenu.down:SetSize(22, 22)
    instanceMenu.down:SetNormalTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\dropdown-chevron.tga")
    instanceMenu.down:SetHighlightTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\dropdown-chevron.tga", "ADD")
    instanceMenu.down:SetScript("OnClick", function()
        MainWindow:ScrollInstanceMenu(MAX_INSTANCE_MENU_BUTTONS)
    end)
    instanceMenu.buttons = {}
    for index = 1, MAX_INSTANCE_MENU_BUTTONS do
        local button = CreateFrame("Button", nil, instanceMenu)
        button:SetPoint("TOPLEFT", 7, -30 - ((index - 1) * 23))
        button:SetPoint("TOPRIGHT", -7, -30 - ((index - 1) * 23))
        button:SetHeight(22)
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("LEFT", 7, 0)
        button.label:SetPoint("RIGHT", -59, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        button.range = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.range:SetPoint("RIGHT", -7, 0)
        button.range:SetWidth(48)
        button.range:SetJustifyH("RIGHT")
        button.range:SetTextColor(0.55, 0.55, 0.55)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetScript("OnClick", function(clicked)
            instanceMenu:Hide()
            MainWindow:SelectInstance(clicked.instanceKey)
        end)
        button:Hide()
        instanceMenu.buttons[index] = button
    end
    instanceMenu:Hide()
    self.instanceMenu = instanceMenu

    self.encounterHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.encounterHeading:SetPoint("TOPLEFT", 12, -88)
    self.encounterHeading:SetText(ns.L.ENCOUNTERS)
    self.encounterHeading:SetTextColor(0.62, 0.62, 0.62)

    self.encounterUp = CreateFrame("Button", nil, panel)
    self.encounterUp:SetPoint("TOPRIGHT", -31, -78)
    self.encounterUp:SetSize(18, 18)
    self.encounterUp.label = self.encounterUp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.encounterUp.label:SetPoint("CENTER")
    self.encounterUp.label:SetText("‹")
    self.encounterUp:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    self.encounterUp:SetScript("OnClick", function()
        MainWindow:ScrollEncounterList(-MAX_ENCOUNTER_BUTTONS)
    end)

    self.encounterDown = CreateFrame("Button", nil, panel)
    self.encounterDown:SetPoint("LEFT", self.encounterUp, "RIGHT", 2, 0)
    self.encounterDown:SetSize(18, 18)
    self.encounterDown.label = self.encounterDown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.encounterDown.label:SetPoint("CENTER")
    self.encounterDown.label:SetText("›")
    self.encounterDown:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    self.encounterDown:SetScript("OnClick", function()
        MainWindow:ScrollEncounterList(MAX_ENCOUNTER_BUTTONS)
    end)

    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        MainWindow:ScrollEncounterList(delta > 0 and -4 or 4)
    end)

    self.bossButtonRows = {}
    for index = 1, MAX_ENCOUNTER_BUTTONS do
        local button = CreateFrame("Button", nil, panel)
        button:SetPoint("TOPLEFT", 8, -102 - ((index - 1) * 25))
        button:SetPoint("TOPRIGHT", -8, -102 - ((index - 1) * 25))
        button:SetHeight(23)
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("LEFT", 28, 0)
        button.label:SetPoint("RIGHT", -5, 0)
        button.label:SetJustifyH("LEFT")
        button.number = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.number:SetPoint("LEFT", 9, 0)
        button.number:SetTextColor(0.58, 0.58, 0.58)
        button:SetScript("OnClick", function(clicked)
            MainWindow:SelectBoss(clicked.bossKey)
        end)
        button:Hide()
        self.bossButtonRows[index] = button
    end
end

function MainWindow:CreateMap(parent)
    self.mapHeading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.mapHeading:SetPoint("TOPLEFT", MAP_LEFT + 4, -62)
    self.mapHeading:SetTextColor(0.68, 0.68, 0.68)

    local floorButton = CreateFrame("Button", nil, parent)
    floorButton:SetSize(232, 24)
    floorButton:SetPoint("TOPRIGHT", -MAP_RIGHT_OFFSET, -55)
    floorButton.background = floorButton:CreateTexture(nil, "BACKGROUND")
    floorButton.background:SetAllPoints()
    floorButton.background:SetColorTexture(selectedColor[1], selectedColor[2], selectedColor[3], 0.12)
    floorButton.label = floorButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    floorButton.label:SetPoint("LEFT", 9, 0)
    floorButton.label:SetPoint("RIGHT", -104, 0)
    floorButton.label:SetJustifyH("LEFT")
    floorButton.label:SetWordWrap(false)
    floorButton.counter = floorButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    floorButton.counter:SetPoint("RIGHT", -42, 0)
    floorButton.counter:SetWidth(48)
    floorButton.counter:SetJustifyH("RIGHT")
    floorButton.counter:SetTextColor(1, 0.82, 0.38)
    floorButton.arrow = floorButton:CreateTexture(nil, "ARTWORK")
    floorButton.arrow:SetSize(24, 24)
    floorButton.arrow:SetPoint("RIGHT", -7, 0)
    floorButton.arrow:SetTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\dropdown-chevron.tga")
    floorButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    floorButton:SetScript("OnClick", function()
        MainWindow:ToggleFloorMenu()
    end)
    floorButton:SetScript("OnEnter", function(entered)
        local instance = ns.Data.instances[MainWindow.selectedInstanceKey]
        if instance and #instance.map.floors > 1 then
            GameTooltip:SetOwner(entered, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(string.format(ns.L.MULTI_FLOOR_TOOLTIP,
                #instance.map.floors), 1, 0.82, 0.38)
            GameTooltip:AddLine(ns.L.CLICK_TO_CHOOSE_FLOOR, 0.72, 0.72, 0.72)
            GameTooltip:Show()
        end
    end)
    floorButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    floorButton:Hide()
    self.floorButton = floorButton

    local floorMenu = CreateBackdropFrame("Frame", nil, parent)
    floorMenu:SetWidth(220)
    floorMenu:SetPoint("TOPRIGHT", floorButton, "BOTTOMRIGHT", 0, -3)
    floorMenu:SetFrameLevel(parent:GetFrameLevel() + 30)
    floorMenu:SetClampedToScreen(true)
    SetBackdropColor(floorMenu, 0.025, 0.025, 0.025, 0.99)
    floorMenu.buttons = {}
    for index = 1, MAX_FLOOR_MENU_BUTTONS do
        local button = CreateFrame("Button", nil, floorMenu)
        button:SetPoint("TOPLEFT", 7, -7 - ((index - 1) * 23))
        button:SetPoint("TOPRIGHT", -7, -7 - ((index - 1) * 23))
        button:SetHeight(22)
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("LEFT", 7, 0)
        button.label:SetPoint("RIGHT", -48, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        button.counter = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.counter:SetPoint("RIGHT", -7, 0)
        button.counter:SetWidth(38)
        button.counter:SetJustifyH("RIGHT")
        button.counter:SetTextColor(0.58, 0.58, 0.58)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetScript("OnClick", function(clicked)
            floorMenu:Hide()
            MainWindow:SelectFloor(clicked.floorIndex)
        end)
        button:Hide()
        floorMenu.buttons[index] = button
    end
    floorMenu:Hide()
    self.floorMenu = floorMenu

    local map = CreateBackdropFrame("Frame", nil, parent)
    map:SetSize(MAP_WIDTH + MAP_OUTER_PADDING, MAP_HEIGHT + MAP_OUTER_PADDING)
    map:SetPoint("TOPLEFT", MAP_LEFT, -80)
    SetBackdropColor(map, 0.015, 0.015, 0.015, 1)
    self.map = map

    local canvas = CreateFrame("Frame", nil, map)
    canvas:SetSize(MAP_WIDTH, MAP_HEIGHT)
    canvas:SetPoint("CENTER")
    canvas:SetClipsChildren(true)
    self.mapCanvas = canvas

    self.mapTiles = {}
    for tileIndex = 1, 12 do
        local column = (tileIndex - 1) % 4
        local row = math.floor((tileIndex - 1) / 4)
        local tile = canvas:CreateTexture(nil, "ARTWORK")
        tile:SetSize(TILE_SIZE, TILE_SIZE)
        tile:SetPoint("TOPLEFT", column * TILE_SIZE, -(row * TILE_SIZE))
        tile:SetVertexColor(0.88, 0.88, 0.88)
        self.mapTiles[tileIndex] = tile
    end

    self.mapPinRows = {}
    for index = 1, MAX_MAP_PINS do
        local pin = CreateFrame("Button", nil, canvas)
        pin:SetSize(22, 22)
        pin:SetHitRectInsets(0, 0, 0, 0)
        pin:SetFrameLevel(canvas:GetFrameLevel() + 5)
        local marker = pin:CreateTexture(nil, "ARTWORK")
        marker:SetSize(18, 18)
        marker:SetPoint("CENTER")
        marker:SetTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\boss-marker.tga")
        pin.marker = marker
        local ring = pin:CreateTexture(nil, "OVERLAY")
        ring:SetSize(24, 24)
        ring:SetPoint("CENTER")
        ring:SetTexture("Interface\\AddOns\\AtlasLootRevival\\assets\\boss-marker-ring.tga")
        ring:SetBlendMode("ADD")
        ring:Hide()
        pin.ring = ring
        local number = pin:CreateFontString(nil, "OVERLAY")
        number:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        number:SetPoint("LEFT", pin, "RIGHT", 2, 0)
        number:SetTextColor(1, 0.82, 0.32)
        number:SetShadowColor(0, 0, 0, 1)
        number:SetShadowOffset(1, -1)
        pin.number = number
        pin:SetScript("OnClick", function(clicked)
            if clicked.bossKeys and #clicked.bossKeys > 1 then
                MainWindow:ShowMapClusterMenu(clicked)
            elseif clicked.bossKeys and clicked.bossKeys[1] then
                if MainWindow.mapClusterMenu then
                    MainWindow.mapClusterMenu:Hide()
                end
                MainWindow:SelectBoss(clicked.bossKeys[1])
            end
        end)
        pin:SetScript("OnEnter", function(entered)
            local instanceLoot = ns.Data.loot[MainWindow.selectedInstanceKey]
            if not instanceLoot or not entered.bossKeys or not entered.bossKeys[1] then
                return
            end
            ShowMapPinRing(entered, entered.isSelected and 1 or 0.88)
            GameTooltip:SetOwner(entered, "ANCHOR_RIGHT")
            if #entered.bossKeys > 1 then
                GameTooltip:AddLine(string.format(ns.L.SHARED_LOCATION,
                    #entered.bossKeys), 1, 0.82, 0.38)
                for bossIndex, bossKey in ipairs(entered.bossKeys) do
                    local encounter = instanceLoot[bossKey]
                    if encounter then
                        GameTooltip:AddLine(string.format("%d. %s",
                            entered.encounterIndexes[bossIndex], encounter.name),
                            0.92, 0.92, 0.92)
                    end
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(ns.L.CLICK_TO_CHOOSE, 0.72, 0.72, 0.72)
            else
                local encounter = instanceLoot[entered.bossKeys[1]]
                GameTooltip:AddLine(encounter.name, 1, 0.82, 0.38)
                GameTooltip:AddLine(ns.L.CLICK_TO_VIEW_LOOT, 0.72, 0.72, 0.72)
            end
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function(left)
            if not left.isSelected then
                if left.isCluster then
                    ShowMapPinRing(left, 0.82)
                else
                    left.ring:Hide()
                end
            end
            GameTooltip:Hide()
        end)
        pin:Hide()
        self.mapPinRows[index] = pin
    end

    local clusterMenu = CreateBackdropFrame("Frame", nil, parent)
    clusterMenu:SetWidth(224)
    clusterMenu:SetFrameLevel(parent:GetFrameLevel() + 30)
    clusterMenu:SetClampedToScreen(true)
    SetBackdropColor(clusterMenu, 0.025, 0.025, 0.025, 0.98)
    clusterMenu.title = clusterMenu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clusterMenu.title:SetPoint("TOPLEFT", 10, -9)
    clusterMenu.title:SetText(ns.L.CHOOSE_ENCOUNTER)
    clusterMenu.title:SetTextColor(1, 0.82, 0.38)
    local closeCluster = CreateFrame("Button", nil, clusterMenu, "UIPanelCloseButton")
    closeCluster:SetSize(26, 26)
    closeCluster:SetPoint("TOPRIGHT", -2, -2)
    closeCluster:SetScript("OnClick", function()
        clusterMenu:Hide()
    end)
    clusterMenu.buttons = {}
    for index = 1, MAX_CLUSTER_BUTTONS do
        local button = CreateFrame("Button", nil, clusterMenu)
        button:SetPoint("TOPLEFT", 7, -31 - ((index - 1) * 22))
        button:SetPoint("TOPRIGHT", -7, -31 - ((index - 1) * 22))
        button:SetHeight(21)
        button.number = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.number:SetPoint("LEFT", 5, 0)
        button.number:SetWidth(24)
        button.number:SetJustifyH("RIGHT")
        button.number:SetTextColor(1, 0.82, 0.38)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:SetPoint("LEFT", button.number, "RIGHT", 8, 0)
        button.label:SetPoint("RIGHT", -5, 0)
        button.label:SetJustifyH("LEFT")
        button.label:SetWordWrap(false)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetScript("OnClick", function(clicked)
            clusterMenu:Hide()
            MainWindow:SelectBoss(clicked.bossKey)
        end)
        button:Hide()
        clusterMenu.buttons[index] = button
    end
    clusterMenu:Hide()
    self.mapClusterMenu = clusterMenu

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 5, -9)
    note:SetText(ns.L.MAP_HINT)
    note:SetTextColor(0.48, 0.48, 0.48)

    local database = ns.modules.Database.data
    local mapSettings = database and database.settings.map or {}
    self:SetMapMarkerSize(mapSettings.markerSize or "normal", false)
end

function MainWindow:CreateLootPanel(parent)
    local panel = CreateBackdropFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", LOOT_PANEL_LEFT, -55)
    panel:SetPoint("BOTTOMRIGHT", -12, 34)
    SetBackdropColor(panel, 0.035, 0.035, 0.035, 0.96)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        MainWindow:ScrollLootList(delta > 0 and -4 or 4)
    end)
    self.lootPanel = panel

    self.bossTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.bossTitle:SetPoint("TOPLEFT", 13, -15)
    self.bossTitle:SetPoint("TOPRIGHT", -13, -15)
    self.bossTitle:SetJustifyH("LEFT")
    self.bossTitle:SetTextColor(1, 0.82, 0.38)

    self.bossMeta = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.bossMeta:SetPoint("TOPLEFT", self.bossTitle, "BOTTOMLEFT", 0, -5)
    self.bossMeta:SetTextColor(0.52, 0.52, 0.52)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", 12, -63)
    divider:SetPoint("TOPRIGHT", -12, -63)
    divider:SetHeight(1)
    divider:SetColorTexture(0.25, 0.21, 0.12, 1)

    self.lootHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.lootHeading:SetPoint("TOPLEFT", 13, -76)
    self.lootHeading:SetText(ns.L.LOOT)
    self.lootHeading:SetTextColor(0.62, 0.62, 0.62)

    self.dropChanceHeading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.dropChanceHeading:SetPoint("TOPRIGHT", -14, -76)
    self.dropChanceHeading:SetText(ns.L.DROP_CHANCE_HEADING)
    self.dropChanceHeading:SetTextColor(0.62, 0.62, 0.62)

    self.lootPrevious = CreateFrame("Button", nil, panel)
    self.lootPrevious:SetPoint("TOPLEFT", 94, -67)
    self.lootPrevious:SetSize(18, 18)
    self.lootPrevious.label = self.lootPrevious:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.lootPrevious.label:SetPoint("CENTER")
    self.lootPrevious.label:SetText("‹")
    self.lootPrevious:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    self.lootPrevious:SetScript("OnClick", function()
        MainWindow:ScrollLootList(-MAX_LOOT_ROWS)
    end)

    self.lootNext = CreateFrame("Button", nil, panel)
    self.lootNext:SetPoint("LEFT", self.lootPrevious, "RIGHT", 2, 0)
    self.lootNext:SetSize(18, 18)
    self.lootNext.label = self.lootNext:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.lootNext.label:SetPoint("CENTER")
    self.lootNext.label:SetText("›")
    self.lootNext:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    self.lootNext:SetScript("OnClick", function()
        MainWindow:ScrollLootList(MAX_LOOT_ROWS)
    end)

    self.lootRows = {}
    for index = 1, MAX_LOOT_ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetPoint("TOPLEFT", 9, -94 - ((index - 1) * LOOT_ROW_STEP))
        row:SetPoint("TOPRIGHT", -9, -94 - ((index - 1) * LOOT_ROW_STEP))
        row:SetHeight(LOOT_ROW_HEIGHT)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(1, 1, 1, 0.025)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 0)
        row.name:SetPoint("TOPRIGHT", -50, 0)
        row.name:SetHeight(12)
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("TOP")
        row.name:SetWordWrap(false)
        row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.meta:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 0)
        row.meta:SetPoint("BOTTOMRIGHT", -50, 0)
        row.meta:SetHeight(10)
        row.meta:SetJustifyH("LEFT")
        row.meta:SetJustifyV("BOTTOM")
        row.meta:SetWordWrap(false)
        row.meta:SetTextColor(0.45, 0.45, 0.45)
        row.chance = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.chance:SetPoint("RIGHT", -4, 0)
        row.chance:SetWidth(42)
        row.chance:SetJustifyH("RIGHT")
        row.chance:SetTextColor(0.92, 0.72, 0.30)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row:SetScript("OnEnter", function(entered)
            if entered.itemID then
                GameTooltip:SetOwner(entered, "ANCHOR_LEFT")
                GameTooltip:SetHyperlink("item:" .. entered.itemID)
                if entered.category == "questObjective" then
                    GameTooltip:AddLine(" ")
                    if entered.questIDs and #entered.questIDs > 1 then
                        GameTooltip:AddLine(string.format(ns.L.QUEST_OBJECTIVE_MULTI_TOOLTIP,
                            JoinQuestIDs(entered.questIDs)), 1, 0.82, 0.38)
                    else
                        GameTooltip:AddLine(string.format(ns.L.QUEST_OBJECTIVE_TOOLTIP,
                            entered.questID or entered.questIDs[1]), 1, 0.82, 0.38)
                    end
                elseif entered.category == "startsQuest" then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format(ns.L.STARTS_QUEST_TOOLTIP,
                        entered.questID), 1, 0.82, 0.38)
                end
                if entered.turnInToken then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(ns.L.TURN_IN_TOKEN_TOOLTIP, 1, 0.82, 0.38)
                end
                if entered.factionAvailability == "alliance" then
                    GameTooltip:AddLine(ns.L.ALLIANCE_ONLY, 0.45, 0.65, 1)
                elseif entered.factionAvailability == "horde" then
                    GameTooltip:AddLine(ns.L.HORDE_ONLY, 1, 0.35, 0.25)
                end
                if entered.dropChance then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(string.format(ns.L.DROP_CHANCE_TOOLTIP,
                        FormatDropChance(entered.dropChance)), 0.92, 0.72, 0.30)
                elseif entered.isTrashDrop and entered.dropChanceStatus then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(ns.L.DROP_VARIES_TOOLTIP, 0.72, 0.72, 0.72)
                elseif entered.dropChanceStatus then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(ns.L.DROP_PENDING_TOOLTIP, 0.72, 0.72, 0.72)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(clicked)
            if clicked.itemLink and HandleModifiedItemClick then
                HandleModifiedItemClick(clicked.itemLink)
            end
        end)
        row:Hide()
        self.lootRows[index] = row
    end

    self.emptyLootText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.emptyLootText:SetPoint("TOPLEFT", 16, -105)
    self.emptyLootText:SetPoint("TOPRIGHT", -16, -105)
    self.emptyLootText:SetJustifyH("LEFT")
    self.emptyLootText:SetText(ns.L.NO_NOTABLE_LOOT)
    self.emptyLootText:SetTextColor(0.52, 0.52, 0.52)
    self.emptyLootText:Hide()

end

function MainWindow:CreateResizeHandle(parent)
    local handle = CreateFrame("Button", nil, parent)
    handle:SetSize(22, 22)
    handle:SetPoint("BOTTOMRIGHT", -3, 3)
    handle:SetFrameLevel(parent:GetFrameLevel() + 20)
    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    handle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            MainWindow:BeginScaling()
        end
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            MainWindow:EndScaling()
        end
    end)
    handle:SetScript("OnUpdate", function()
        MainWindow:UpdateScaling()
    end)
    handle:SetScript("OnEnter", function(entered)
        GameTooltip:SetOwner(entered, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(ns.L.RESIZE_HINT, 1, 0.82, 0.38)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.resizeHandle = handle
end

function MainWindow:SetWindowScale(scale)
    scale = ClampWindowScale(scale)
    self.windowScale = scale
    if not self.frame then
        return
    end
    self.frame:SetSize(WINDOW_WIDTH * scale, WINDOW_HEIGHT * scale)
    if self.content then
        self.content:SetScale(scale)
    end
end

function MainWindow:BeginScaling()
    if not self.frame or self.isScaling then
        return
    end

    local left = self.frame:GetLeft()
    local top = self.frame:GetTop()
    if left and top then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end

    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    self.scaleStartX = cursorX / uiScale
    self.scaleStartY = cursorY / uiScale
    self.scaleStartValue = self.windowScale or 1
    self.isScaling = true
end

function MainWindow:UpdateScaling()
    if not self.isScaling then
        return
    end
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        self:EndScaling()
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetEffectiveScale()
    cursorX = cursorX / uiScale
    cursorY = cursorY / uiScale
    local horizontalScale = self.scaleStartValue + ((cursorX - self.scaleStartX) / WINDOW_WIDTH)
    local verticalScale = self.scaleStartValue - ((cursorY - self.scaleStartY) / WINDOW_HEIGHT)
    local horizontalDelta = math.abs(horizontalScale - self.scaleStartValue)
    local verticalDelta = math.abs(verticalScale - self.scaleStartValue)
    self:SetWindowScale(horizontalDelta >= verticalDelta and horizontalScale or verticalScale)
end

function MainWindow:EndScaling()
    if not self.isScaling then
        return
    end
    self.isScaling = false
    self:SavePosition()
end

function MainWindow:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "AtlasLootRevivalMainFrame", UIParent)
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(window)
        window:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(window)
        window:StopMovingOrSizing()
        MainWindow:SavePosition()
    end)
    self.frame = frame

    self:RestorePosition()

    local content = CreateBackdropFrame("Frame", nil, frame)
    content:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    content:SetPoint("TOPLEFT")
    content:SetScale(self.windowScale or 1)
    SetBackdropColor(content, 0.025, 0.025, 0.025, 0.99)
    self.content = content

    self:CreateTitle(content)
    ns.modules.SettingsPanel:Create(content, self.settingsButton)
    self:CreateSidebar(content)
    self:CreateMap(content)
    self:CreateLootPanel(content)
    self:CreateResizeHandle(frame)

    local feedbackDialog = CreateBackdropFrame("Frame", nil, content)
    feedbackDialog:SetSize(500, 126)
    feedbackDialog:SetPoint("CENTER", content, "CENTER", 0, 5)
    feedbackDialog:SetFrameLevel(content:GetFrameLevel() + 50)
    feedbackDialog:SetClampedToScreen(true)
    SetBackdropColor(feedbackDialog, 0.025, 0.025, 0.025, 0.99)
    feedbackDialog.title = feedbackDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    feedbackDialog.title:SetPoint("TOPLEFT", 16, -15)
    feedbackDialog.title:SetText(ns.L.FEEDBACK_COPY_TITLE)
    feedbackDialog.title:SetTextColor(1, 0.82, 0.38)
    feedbackDialog.body = feedbackDialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    feedbackDialog.body:SetPoint("TOPLEFT", feedbackDialog.title, "BOTTOMLEFT", 0, -7)
    feedbackDialog.body:SetText(ns.L.FEEDBACK_COPY_BODY)
    feedbackDialog.body:SetTextColor(0.68, 0.68, 0.68)
    feedbackDialog.editBox = CreateFrame("EditBox", nil, feedbackDialog, "InputBoxTemplate")
    feedbackDialog.editBox:SetPoint("BOTTOMLEFT", 16, 16)
    feedbackDialog.editBox:SetPoint("BOTTOMRIGHT", -16, 16)
    feedbackDialog.editBox:SetHeight(28)
    feedbackDialog.editBox:SetAutoFocus(false)
    feedbackDialog.editBox:SetFontObject("GameFontHighlight")
    feedbackDialog.editBox:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
        feedbackDialog:Hide()
    end)
    feedbackDialog.editBox:SetScript("OnEnterPressed", function(editBox)
        editBox:HighlightText()
    end)
    feedbackDialog.editBox:SetScript("OnTextChanged", function(editBox, userInput)
        if userInput then
            editBox:SetText(ns.L.FEEDBACK_URL)
            editBox:HighlightText()
        end
    end)
    local closeFeedback = CreateFrame("Button", nil, feedbackDialog, "UIPanelCloseButton")
    closeFeedback:SetPoint("TOPRIGHT", -3, -3)
    closeFeedback:SetScript("OnClick", function()
        feedbackDialog.editBox:ClearFocus()
        feedbackDialog:Hide()
    end)
    feedbackDialog:Hide()
    self.feedbackDialog = feedbackDialog

    local feedbackLink = CreateFrame("Button", nil, content)
    feedbackLink:SetPoint("BOTTOMLEFT", 14, 7)
    feedbackLink:SetPoint("BOTTOMRIGHT", -34, 7)
    feedbackLink:SetHeight(18)
    feedbackLink.label = feedbackLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    feedbackLink.label:SetAllPoints()
    feedbackLink.label:SetText(ns.L.STATUS_LIVE_QA)
    feedbackLink.label:SetTextColor(0.52, 0.58, 0.60)
    feedbackLink.label:SetJustifyH("LEFT")
    feedbackLink:SetScript("OnEnter", function(entered)
        feedbackLink.label:SetTextColor(0.20, 0.82, 1)
        GameTooltip:SetOwner(entered, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(ns.L.FEEDBACK_TITLE, 1, 0.82, 0.38)
        GameTooltip:AddLine(ns.L.FEEDBACK_BODY, 0.82, 0.82, 0.82, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns.L.FEEDBACK_CLICK, 0.20, 0.82, 1)
        GameTooltip:Show()
    end)
    feedbackLink:SetScript("OnLeave", function()
        feedbackLink.label:SetTextColor(0.52, 0.58, 0.60)
        GameTooltip:Hide()
    end)
    feedbackLink:SetScript("OnClick", function()
        MainWindow:ShowFeedbackDialog()
    end)
    self.feedbackLink = feedbackLink

    table.insert(UISpecialFrames, frame:GetName())
    local database = ns.modules.Database.data
    local browserSettings = database and database.settings.browser or {}
    self.selectedContentType = browserSettings.selectedContentType == "raid"
        and "raid" or "dungeon"
    self.selectedInstances = browserSettings.selectedInstances or {}
    self.instanceOrder = GetAvailableInstanceKeys(self.selectedContentType)
    if #self.instanceOrder == 0 then
        self.selectedContentType = "dungeon"
        self.instanceOrder = GetAvailableInstanceKeys(self.selectedContentType)
    end
    self:RefreshContentTypeButtons()
    local rememberedInstance = self.selectedInstances[self.selectedContentType]
    local rememberedData = rememberedInstance and ns.Data.instances[rememberedInstance]
    local flavor = ns.Constants.GetClientFlavor()
    if not rememberedData or not rememberedData.clientFlavors[flavor]
        or (rememberedData.contentType or "dungeon") ~= self.selectedContentType then
        rememberedInstance = nil
    end
    local initialInstance = rememberedInstance
        or (ns.Data.instances.wailing_caverns and "wailing_caverns")
        or self.instanceOrder[1]
    self:SelectInstance(initialInstance)
    frame:Hide()
end

function MainWindow:ShowFeedbackDialog()
    if not self.feedbackDialog then
        return
    end
    if self.instanceMenu then
        self.instanceMenu:Hide()
    end
    if self.floorMenu then
        self.floorMenu:Hide()
    end
    if ns.modules.SettingsPanel then
        ns.modules.SettingsPanel:Hide()
    end
    self.feedbackDialog:Show()
    self.feedbackDialog.editBox:SetText(ns.L.FEEDBACK_URL)
    self.feedbackDialog.editBox:SetFocus()
    self.feedbackDialog.editBox:HighlightText()
end

function MainWindow:RefreshContentTypeButtons()
    for contentType, button in pairs(self.contentTypeButtons or {}) do
        SetButtonHighlight(button, contentType == self.selectedContentType)
    end
end

function MainWindow:RefreshInstanceMenu()
    local menu = self.instanceMenu
    if not menu then
        return
    end
    local order = self.instanceOrder or GetAvailableInstanceKeys(self.selectedContentType)
    local visibleCount = math.min(#order, MAX_INSTANCE_MENU_BUTTONS)
    local maxOffset = math.max(0, #order - MAX_INSTANCE_MENU_BUTTONS)
    self.instanceMenuOffset = math.max(0,
        math.min(self.instanceMenuOffset or 0, maxOffset))
    menu:SetHeight(37 + (visibleCount * 23))
    local title = self.selectedContentType == "raid"
        and ns.L.SELECT_RAID or ns.L.SELECT_DUNGEON
    if #order > MAX_INSTANCE_MENU_BUTTONS then
        local firstVisible = self.instanceMenuOffset + 1
        local lastVisible = math.min(#order,
            self.instanceMenuOffset + MAX_INSTANCE_MENU_BUTTONS)
        title = string.format("%s  %d–%d / %d", title,
            firstVisible, lastVisible, #order)
    end
    menu.title:SetText(title)
    if #order > MAX_INSTANCE_MENU_BUTTONS then
        menu.up:Show()
        menu.down:Show()
    else
        menu.up:Hide()
        menu.down:Hide()
    end
    for index, button in ipairs(menu.buttons) do
        local instanceKey = order[self.instanceMenuOffset + index]
        local instance = instanceKey and ns.Data.instances[instanceKey]
        if instance then
            button.instanceKey = instanceKey
            button.label:SetText(instance.name)
            button.range:SetText(string.format("%d–%d", instance.levelMin, instance.levelMax))
            SetButtonHighlight(button, instanceKey == self.selectedInstanceKey)
            button:Show()
        else
            button.instanceKey = nil
            button:Hide()
        end
    end
end

function MainWindow:ScrollInstanceMenu(delta)
    local order = self.instanceOrder or GetAvailableInstanceKeys(self.selectedContentType)
    local maxOffset = math.max(0, #order - MAX_INSTANCE_MENU_BUTTONS)
    local nextOffset = math.max(0,
        math.min((self.instanceMenuOffset or 0) + delta, maxOffset))
    if nextOffset ~= self.instanceMenuOffset then
        self.instanceMenuOffset = nextOffset
        self:RefreshInstanceMenu()
    end
end

function MainWindow:ToggleInstanceMenu()
    local menu = self.instanceMenu
    if not menu then
        return
    end
    if menu:IsShown() then
        menu:Hide()
        return
    end
    if self.floorMenu then
        self.floorMenu:Hide()
    end
    if self.mapClusterMenu then
        self.mapClusterMenu:Hide()
    end
    local order = self.instanceOrder or GetAvailableInstanceKeys(self.selectedContentType)
    local selectedIndex = 1
    for index, instanceKey in ipairs(order) do
        if instanceKey == self.selectedInstanceKey then
            selectedIndex = index
            break
        end
    end
    local maxOffset = math.max(0, #order - MAX_INSTANCE_MENU_BUTTONS)
    self.instanceMenuOffset = math.max(0,
        math.min(selectedIndex - math.ceil(MAX_INSTANCE_MENU_BUTTONS / 2), maxOffset))
    self:RefreshInstanceMenu()
    menu:Show()
end

function MainWindow:RefreshFloorMenu()
    local menu = self.floorMenu
    local instance = ns.Data.instances[self.selectedInstanceKey]
    if not menu or not instance then
        return
    end
    local floors = instance.map.floors
    menu:SetHeight(14 + (#floors * 23))
    for index, button in ipairs(menu.buttons) do
        local floor = floors[index]
        if floor then
            button.floorIndex = floor.index
            button.label:SetText(floor.name)
            button.counter:SetText(string.format("%d / %d", index, #floors))
            SetButtonHighlight(button, floor.index == self.selectedFloor)
            button:Show()
        else
            button.floorIndex = nil
            button:Hide()
        end
    end
end

function MainWindow:ToggleFloorMenu()
    local menu = self.floorMenu
    local instance = ns.Data.instances[self.selectedInstanceKey]
    if not menu or not instance or #instance.map.floors < 2 then
        return
    end
    if menu:IsShown() then
        menu:Hide()
        return
    end
    if self.instanceMenu then
        self.instanceMenu:Hide()
    end
    if self.mapClusterMenu then
        self.mapClusterMenu:Hide()
    end
    self:RefreshFloorMenu()
    menu:Show()
end

function MainWindow:RefreshSidebar()
    local instance = ns.Data.instances[self.selectedInstanceKey]
    local instanceLoot = instance and ns.Data.loot[instance.key]
    if not instance or not instanceLoot then
        return
    end

    self.dungeonButton.label:SetText(instance.name)
    self.dungeonButton.label:SetFont(STANDARD_TEXT_FONT,
        #instance.name > 18 and 10 or 12, "")
    if instance.contentType == "raid" then
        self.dungeonButton.range:SetText(string.format(ns.L.RAID_LEVEL,
            instance.levelMax))
    else
        self.dungeonButton.range:SetText(string.format(ns.L.LEVEL_RANGE,
            instance.levelMin, instance.levelMax))
    end
    local entryKeys = GetInstanceEntryKeys(instance)
    local maxOffset = math.max(0, #entryKeys - MAX_ENCOUNTER_BUTTONS)
    self.sidebarOffset = math.max(0, math.min(self.sidebarOffset or 0, maxOffset))
    local firstVisible = self.sidebarOffset + 1
    local lastVisible = math.min(#entryKeys, self.sidebarOffset + MAX_ENCOUNTER_BUTTONS)
    if #entryKeys > MAX_ENCOUNTER_BUTTONS then
        self.encounterHeading:SetText(string.format("%s  %d–%d / %d",
            ns.L.ENCOUNTERS, firstVisible, lastVisible, #entryKeys))
        self.encounterUp:Show()
        self.encounterDown:Show()
    else
        self.encounterHeading:SetText(ns.L.ENCOUNTERS)
        self.encounterUp:Hide()
        self.encounterDown:Hide()
    end
    self.bossButtons = {}
    for index, button in ipairs(self.bossButtonRows) do
        local encounterIndex = self.sidebarOffset + index
        local bossKey = entryKeys[encounterIndex]
        local boss = bossKey and instanceLoot[bossKey]
        if boss then
            button.bossKey = bossKey
            button.label:SetText(boss.name)
            button.number:SetText(bossKey == TRASH_DROPS_KEY and "•" or encounterIndex)
            button:Show()
            self.bossButtons[bossKey] = button
        else
            button.bossKey = nil
            button:Hide()
        end
    end
end

function MainWindow:ShowMapClusterMenu(pin)
    local menu = self.mapClusterMenu
    local instanceLoot = ns.Data.loot[self.selectedInstanceKey]
    if not menu or not instanceLoot or not pin.bossKeys or #pin.bossKeys < 2 then
        return
    end
    if menu:IsShown() and menu.pin == pin then
        menu:Hide()
        menu.pin = nil
        return
    end

    menu.pin = pin
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", pin, "BOTTOMRIGHT", 5, 5)
    menu:SetHeight(39 + (#pin.bossKeys * 22))
    for index, button in ipairs(menu.buttons) do
        local bossKey = pin.bossKeys[index]
        local encounter = bossKey and instanceLoot[bossKey]
        if encounter then
            button.bossKey = bossKey
            button.number:SetText(pin.encounterIndexes[index] .. ".")
            button.label:SetText(encounter.name)
            button:Show()
        else
            button.bossKey = nil
            button:Hide()
        end
    end
    menu:Show()
end

function MainWindow:BuildMapClusters(instance, instanceLoot, floorIndex)
    local points = {}
    for encounterIndex, bossKey in ipairs(instance.bosses) do
        local boss = instanceLoot[bossKey]
        if boss and boss.floor == floorIndex and boss.x and boss.y then
            table.insert(points, {
                x = boss.x,
                y = boss.y,
                bossKey = bossKey,
                encounterIndex = encounterIndex,
            })
        end
    end

    local parents = {}
    for index = 1, #points do
        parents[index] = index
    end
    local function Find(index)
        while parents[index] ~= index do
            parents[index] = parents[parents[index]]
            index = parents[index]
        end
        return index
    end
    local function Union(left, right)
        local leftRoot = Find(left)
        local rightRoot = Find(right)
        if leftRoot ~= rightRoot then
            parents[rightRoot] = leftRoot
        end
    end
    local distanceSquared = MAP_CLUSTER_DISTANCE * MAP_CLUSTER_DISTANCE
    for left = 1, #points do
        for right = left + 1, #points do
            local deltaX = (points[left].x - points[right].x) * MAP_WIDTH
            local deltaY = (points[left].y - points[right].y) * MAP_HEIGHT
            if (deltaX * deltaX) + (deltaY * deltaY) <= distanceSquared then
                Union(left, right)
            end
        end
    end

    local clustersByRoot = {}
    local clusters = {}
    for index, point in ipairs(points) do
        local root = Find(index)
        local cluster = clustersByRoot[root]
        if not cluster then
            cluster = {
                x = 0,
                y = 0,
                bossKeys = {},
                encounterIndexes = {},
            }
            clustersByRoot[root] = cluster
            table.insert(clusters, cluster)
        end
        cluster.x = cluster.x + point.x
        cluster.y = cluster.y + point.y
        table.insert(cluster.bossKeys, point.bossKey)
        table.insert(cluster.encounterIndexes, point.encounterIndex)
    end
    for _, cluster in ipairs(clusters) do
        cluster.x = cluster.x / #cluster.bossKeys
        cluster.y = cluster.y / #cluster.bossKeys
    end
    return clusters
end

function MainWindow:RefreshMap()
    local instance = ns.Data.instances[self.selectedInstanceKey]
    local instanceLoot = instance and ns.Data.loot[instance.key]
    if not instance or not instanceLoot then
        return
    end

    self.mapHeading:SetText(ns.L.MAP .. "  /  " .. instance.name)
    local mapData = instance.map
    local floorIndex = self.selectedFloor or 1
    local floorData = mapData.floors[floorIndex] or mapData.floors[1]
    self.selectedFloor = floorData.index
    if #mapData.floors > 1 then
        self.floorButton.label:SetText(floorData.name)
        self.floorButton.counter:SetText(string.format("%d / %d",
            floorData.index, #mapData.floors))
        self.floorButton:Show()
        self:RefreshFloorMenu()
    else
        self.floorButton:Hide()
        self.floorMenu:Hide()
    end
    local tileCount = mapData.columns * mapData.rows
    for tileIndex, tile in ipairs(self.mapTiles) do
        if tileIndex <= tileCount then
            local folder = mapData.textureFolder
            local fileName
            if mapData.tileFilePattern == "tileIndexOnly" then
                fileName = folder .. tileIndex
            else
                fileName = folder .. (floorData.textureIndex or floorData.index) .. "_" .. tileIndex
            end
            tile:SetTexture("Interface\\WorldMap\\" .. folder .. "\\" .. fileName)
            tile:Show()
        else
            tile:Hide()
        end
    end

    if self.mapClusterMenu then
        self.mapClusterMenu:Hide()
        self.mapClusterMenu.pin = nil
    end

    local coordinateGroupOrder = self:BuildMapClusters(instance,
        instanceLoot, floorData.index)

    self.mapPins = {}
    local pinSlot = 1
    for _, group in ipairs(coordinateGroupOrder) do
        if pinSlot <= #self.mapPinRows then
            local markerX = math.max(12,
                math.min(MAP_WIDTH - 42, group.x * MAP_WIDTH))
            local markerY = math.max(12,
                math.min(MAP_HEIGHT - 12, group.y * MAP_HEIGHT))
            local pin = self.mapPinRows[pinSlot]
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", self.mapCanvas, "TOPLEFT",
                markerX, -markerY)
            pin.bossKeys = group.bossKeys
            pin.encounterIndexes = group.encounterIndexes
            pin.isCluster = #group.bossKeys > 1
            if #group.bossKeys > 1 then
                pin.number:SetText("")
                ShowMapPinRing(pin, 0.82)
            else
                pin.number:SetText(group.encounterIndexes[1])
                pin.ring:Hide()
            end
            pin.isSelected = false
            pin:Show()
            for _, bossKey in ipairs(group.bossKeys) do
                self.mapPins[bossKey] = pin
            end
            pinSlot = pinSlot + 1
        end
    end
    for index = pinSlot, #self.mapPinRows do
        local pin = self.mapPinRows[index]
        pin.bossKeys = nil
        pin.encounterIndexes = nil
        pin.isCluster = nil
        pin.ring:Hide()
        pin:Hide()
    end
end

function MainWindow:SelectContentType(contentType)
    if contentType ~= "dungeon" and contentType ~= "raid" then
        return
    end
    local order = GetAvailableInstanceKeys(contentType)
    if #order == 0 then
        return
    end
    if self.instanceMenu then
        self.instanceMenu:Hide()
    end
    if self.selectedContentType == contentType then
        return
    end
    self.selectedContentType = contentType
    self.instanceOrder = order
    self:RefreshContentTypeButtons()
    local selected = self.selectedInstances and self.selectedInstances[contentType]
    self:SelectInstance(selected or order[1])
end

function MainWindow:SelectInstance(instanceKey)
    local instance = instanceKey and ns.Data.instances[instanceKey]
    local flavor = ns.Constants.GetClientFlavor()
    if not instance or not instance.clientFlavors[flavor] then
        return
    end

    if self.instanceMenu then
        self.instanceMenu:Hide()
    end
    if self.floorMenu then
        self.floorMenu:Hide()
    end

    self.selectedInstanceKey = instanceKey
    self.selectedContentType = instance.contentType or "dungeon"
    self.selectedInstances = self.selectedInstances or {}
    self.selectedInstances[self.selectedContentType] = instanceKey
    local database = ns.modules.Database.data
    if database then
        database.settings.browser = database.settings.browser or {}
        database.settings.browser.selectedContentType = self.selectedContentType
        database.settings.browser.selectedInstances = self.selectedInstances
    end
    self.instanceOrder = GetAvailableInstanceKeys(self.selectedContentType)
    self:RefreshContentTypeButtons()
    self.sidebarOffset = 0
    self.selectedFloor = instance.map.floors[1].index
    self:RefreshSidebar()
    self:RefreshMap()
    self:SelectBoss(instance.bosses[1])
end

function MainWindow:GetCurrentInstanceKey()
    local instanceID
    if type(UnitPosition) == "function" then
        local _, _, _, positionInstanceID = UnitPosition("player")
        if positionInstanceID and positionInstanceID ~= 0 then
            instanceID = positionInstanceID
        end
    end
    if not instanceID and type(GetInstanceInfo) == "function" then
        local _, instanceType, _, _, _, _, _, infoInstanceID = GetInstanceInfo()
        if instanceType == "party" or instanceType == "raid" then
            instanceID = infoInstanceID
        end
    end
    if not instanceID or instanceID == 0 then
        return nil
    end

    local flavor = ns.Constants.GetClientFlavor()
    local selected = self.selectedInstanceKey and ns.Data.instances[self.selectedInstanceKey]
    if selected and selected.instanceID == instanceID and selected.clientFlavors[flavor] then
        return self.selectedInstanceKey
    end

    for _, contentType in ipairs({ "dungeon", "raid" }) do
        local remembered = self.selectedInstances and self.selectedInstances[contentType]
        local rememberedInstance = remembered and ns.Data.instances[remembered]
        if rememberedInstance and rememberedInstance.instanceID == instanceID
            and rememberedInstance.clientFlavors[flavor] then
            return remembered
        end
    end

    local fallback
    for _, contentType in ipairs({ "dungeon", "raid" }) do
        for _, instanceKey in ipairs(GetAvailableInstanceKeys(contentType)) do
            if ns.Data.instances[instanceKey].instanceID == instanceID then
                fallback = instanceKey
            end
        end
    end
    return fallback
end

function MainWindow:SelectCurrentInstance()
    local instanceKey = self:GetCurrentInstanceKey()
    if not instanceKey then
        return false
    end
    self:SelectInstance(instanceKey)
    return true
end

function MainWindow:ScrollEncounterList(delta)
    local instance = ns.Data.instances[self.selectedInstanceKey]
    if not instance then
        return
    end
    local entryKeys = GetInstanceEntryKeys(instance)
    if #entryKeys <= MAX_ENCOUNTER_BUTTONS then
        return
    end
    local maxOffset = #entryKeys - MAX_ENCOUNTER_BUTTONS
    local nextOffset = math.max(0, math.min((self.sidebarOffset or 0) + delta, maxOffset))
    if nextOffset ~= self.sidebarOffset then
        self.sidebarOffset = nextOffset
        self:RefreshSidebar()
        if self.selectedBossKey and self.bossButtons[self.selectedBossKey] then
            SetButtonHighlight(self.bossButtons[self.selectedBossKey], true)
        end
    end
end

function MainWindow:SelectFloor(floorIndex)
    local instance = ns.Data.instances[self.selectedInstanceKey]
    if not instance or #instance.map.floors < 2 then
        return
    end
    local selectedFloor
    for _, floor in ipairs(instance.map.floors) do
        if floor.index == floorIndex then
            selectedFloor = floor.index
            break
        end
    end
    if not selectedFloor then
        return
    end
    if self.floorMenu then
        self.floorMenu:Hide()
    end
    self.selectedFloor = selectedFloor
    self:RefreshMap()
    if self.selectedBossKey then
        self:SelectBoss(self.selectedBossKey, true)
    end
end

function MainWindow:SelectBoss(bossKey, keepFloor)
    local instanceKey = self.selectedInstanceKey or "wailing_caverns"
    local boss = ns.Data.loot[instanceKey] and ns.Data.loot[instanceKey][bossKey]
    if not boss then
        return
    end
    if self.mapClusterMenu then
        self.mapClusterMenu:Hide()
        self.mapClusterMenu.pin = nil
    end
    if boss.kind ~= "trashDrops" and not keepFloor
        and boss.floor and boss.floor ~= self.selectedFloor then
        self.selectedFloor = boss.floor
        self:RefreshMap()
    end
    if self.selectedBossKey ~= bossKey then
        self.lootOffset = 0
    end
    self.selectedBossKey = bossKey
    local instance = ns.Data.instances[instanceKey]
    for encounterIndex, key in ipairs(GetInstanceEntryKeys(instance)) do
        if key == bossKey then
            local offset = self.sidebarOffset or 0
            if encounterIndex <= offset then
                self.sidebarOffset = encounterIndex - 1
                self:RefreshSidebar()
            elseif encounterIndex > offset + MAX_ENCOUNTER_BUTTONS then
                self.sidebarOffset = encounterIndex - MAX_ENCOUNTER_BUTTONS
                self:RefreshSidebar()
            end
            break
        end
    end
    self.bossTitle:SetText(boss.name)
    local kind = boss.kind == "rare" and ns.L.RARE or (boss.kind == "event" and ns.L.EVENT or "Boss")
    local meta
    if boss.kind == "trashDrops" then
        kind = ns.L.TRASH_DROPS
        meta = ns.L.TRASH_DROPS_META
    else
        meta = string.format("%s  •  NPC %d", kind, boss.npcID)
    end
    if boss.locationScope == "preInstance" then
        meta = meta .. "  •  " .. ns.L.PRE_INSTANCE
    end
    if boss.factionAvailability == "alliance" then
        meta = meta .. "  •  " .. ns.L.ALLIANCE_ONLY
    elseif boss.factionAvailability == "horde" then
        meta = meta .. "  •  " .. ns.L.HORDE_ONLY
    end
    if boss.availability == "scourgeInvasion"
        or boss.availability == "scourgeInvasionOnly" then
        meta = meta .. "  •  " .. ns.L.SCOURGE_INVASION
    elseif boss.availability == "pyramidEvent" then
        meta = meta .. "  •  " .. ns.L.PYRAMID_EVENT
    elseif boss.availability == "pyramidEventOptionalHostile" then
        meta = meta .. "  •  " .. ns.L.PYRAMID_EVENT .. " / " .. ns.L.OPTIONAL_HOSTILE
    elseif boss.availability == "summonedWithMalletOfZulFarrak"
        or boss.availability == "summonedQuestEvent"
        or boss.availability == "summonedWithOmokksHeadAndRoughshodPike" then
        meta = meta .. "  •  " .. ns.L.SUMMONED
    elseif boss.availability == "tier0_5QuestEvent"
        or boss.availability == "tier05Summon"
        or boss.availability == "tier0_5BrazierSummon"
        or boss.availability == "phase6LegendaryQuestSummon"
        or boss.availability == "classQuestSummon"
        or boss.availability == "warlockEpicMountSummon" then
        meta = meta .. "  •  " .. ns.L.QUEST_SUMMON
    elseif boss.availability == "ringOfLawRandomBoss" then
        meta = meta .. "  •  " .. ns.L.RING_OF_LAW
    elseif boss.availability == "darkCofferEvent" then
        meta = meta .. "  •  " .. ns.L.DARK_COFFER
    elseif boss.availability == "darkKeeperKeyEvent" then
        meta = meta .. "  •  " .. ns.L.DARK_KEEPER
    elseif boss.availability == "grimGuzzlerEvent" then
        meta = meta .. "  •  " .. ns.L.GRIM_GUZZLER
    elseif boss.availability == "summonersTombEvent" then
        meta = meta .. "  •  " .. ns.L.SUMMONERS_TOMB
    elseif boss.availability == "emperorEncounter" then
        meta = meta .. "  •  " .. ns.L.EMPEROR_ENCOUNTER
    elseif boss.availability == "postboxEvent" then
        meta = meta .. "  •  " .. ns.L.POSTBOX_EVENT
    elseif boss.availability == "blacksmithingPlansTrigger" then
        meta = meta .. "  •  " .. ns.L.PLANS_TRIGGER
    elseif boss.availability == "tobaccoBoxSummon" then
        meta = meta .. "  •  " .. ns.L.TOBACCO_BOX
    elseif boss.availability == "slaughterSquareGauntlet" then
        meta = meta .. "  •  " .. ns.L.GAUNTLET_EVENT
    elseif boss.availability == "blackrockStadiumEvent" then
        meta = meta .. "  •  " .. ns.L.STADIUM_EVENT
    elseif boss.availability == "emberseerRuneEvent" then
        meta = meta .. "  •  " .. ns.L.RUNE_EVENT
    elseif boss.availability == "rookeryEggEvent" then
        meta = meta .. "  •  " .. ns.L.ROOKERY_EVENT
    elseif boss.availability == "orbOfDominationEggEvent" then
        meta = meta .. "  •  " .. ns.L.ORB_EVENT
    elseif boss.availability == "lordVictorNefariusEvent" then
        meta = meta .. "  •  " .. ns.L.NEFARIUS_EVENT
    elseif boss.availability == "majordomoSummon" then
        meta = meta .. "  •  " .. ns.L.SUMMONED
    elseif boss.availability == "runeExtinguishingEvent" then
        meta = meta .. "  •  " .. ns.L.RUNE_EVENT
    elseif boss.availability == "optionalEncounter" then
        meta = meta .. "  •  " .. ns.L.OPTIONAL_ENCOUNTER
    elseif boss.availability == "eightWaveEncounter" then
        meta = meta .. "  •  " .. ns.L.WAVE_EVENT
    elseif boss.availability == "edgeOfMadnessRotation" then
        meta = meta .. "  •  " .. ns.L.ROTATING_ENCOUNTER
    elseif boss.availability == "gongSummon"
        or boss.availability == "natPaglesMuddyChurningLureSummon" then
        meta = meta .. "  •  " .. ns.L.SUMMONED
    elseif boss.availability == "optionalSpeakerEvent" then
        meta = meta .. "  •  " .. ns.L.SPEAKER_EVENT
    elseif boss.availability == "sharedTwinEncounter" then
        meta = meta .. "  •  " .. ns.L.SHARED_ENCOUNTER
    elseif boss.availability == "eruptionDanceEncounter" then
        meta = meta .. "  •  " .. ns.L.ERUPTION_DANCE
    elseif boss.availability == "deathknightUnderstudyControlEvent" then
        meta = meta .. "  •  " .. ns.L.CONTROL_EVENT
    elseif boss.availability == "feugenStalaggPolarityEvent" then
        meta = meta .. "  •  " .. ns.L.POLARITY_EVENT
    elseif boss.availability == "livingAndDeadSideWaveEvent" then
        meta = meta .. "  •  " .. ns.L.WAVE_EVENT
    elseif boss.availability == "multiPhaseFinalEncounter" then
        meta = meta .. "  •  " .. ns.L.MULTI_PHASE
    elseif boss.availability == "sharedFourHorsemenChest" then
        meta = meta .. "  •  " .. ns.L.SHARED_CHEST
    end
    if boss.positionPrecision == "eventAnchor" then
        meta = meta .. "  •  " .. ns.L.MAP_EVENT_ANCHOR
    elseif boss.positionPrecision == "routeAnchor" then
        meta = meta .. "  •  " .. ns.L.MAP_ROUTE_ANCHOR
    elseif boss.kind ~= "trashDrops" and boss.locationScope ~= "preInstance"
        and (not boss.x or not boss.y) then
        meta = meta .. "  •  " .. ns.L.MAP_POSITION_PENDING
    end
    self.bossMeta:SetText(meta)

    for key, button in pairs(self.bossButtons) do
        SetButtonHighlight(button, key == bossKey)
    end
    for _, pin in ipairs(self.mapPinRows) do
        local containsSelectedBoss = false
        for _, pinBossKey in ipairs(pin.bossKeys or {}) do
            if pinBossKey == bossKey then
                containsSelectedBoss = true
                break
            end
        end
        if containsSelectedBoss then
            pin.isSelected = true
            ShowMapPinRing(pin, 1)
            pin.number:SetTextColor(1, 0.92, 0.55)
        else
            pin.isSelected = false
            if pin.isCluster then
                ShowMapPinRing(pin, 0.82)
            else
                pin.ring:Hide()
            end
            pin.number:SetTextColor(1, 0.82, 0.32)
        end
    end
    self:RefreshLoot()
end

function MainWindow:ScrollLootList(delta)
    local instanceLoot = ns.Data.loot[self.selectedInstanceKey]
    local boss = self.selectedBossKey and instanceLoot and instanceLoot[self.selectedBossKey]
    if not boss or #boss.items <= MAX_LOOT_ROWS then
        return
    end
    local maxOffset = math.max(0, #boss.items - MAX_LOOT_ROWS)
    local nextOffset = math.max(0, math.min((self.lootOffset or 0) + delta, maxOffset))
    if nextOffset ~= self.lootOffset then
        self.lootOffset = nextOffset
        self:RefreshLoot()
    end
end

function MainWindow:RefreshLoot()
    local instanceKey = self.selectedInstanceKey or "wailing_caverns"
    local instanceLoot = ns.Data.loot[instanceKey]
    local boss = self.selectedBossKey and instanceLoot and instanceLoot[self.selectedBossKey]
    if not boss then
        return
    end
    local maxOffset = math.max(0, #boss.items - MAX_LOOT_ROWS)
    self.lootOffset = math.max(0, math.min(self.lootOffset or 0, maxOffset))
    local firstVisible = self.lootOffset + 1
    local lastVisible = math.min(#boss.items, self.lootOffset + MAX_LOOT_ROWS)
    if #boss.items > MAX_LOOT_ROWS then
        self.lootHeading:SetText(string.format("%s  %d–%d / %d",
            ns.L.LOOT, firstVisible, lastVisible, #boss.items))
        self.lootPrevious:Show()
        self.lootNext:Show()
    else
        self.lootHeading:SetText(ns.L.LOOT)
        self.lootPrevious:Hide()
        self.lootNext:Hide()
    end
    local database = ns.modules.Database.data
    local browserSettings = database and database.settings.browser or {}
    local showDropEstimates = browserSettings.showDropEstimates ~= false
    self.dropChanceHeading:SetText(showDropEstimates
        and ns.L.DROP_CHANCE_HEADING or ns.L.TYPE_HEADING)
    if boss.kind == "trashDrops" then
        self.emptyLootText:SetText(ns.L.NO_NOTABLE_TRASH_DROPS)
    else
        self.emptyLootText:SetText(ns.L.NO_NOTABLE_LOOT)
    end
    if #boss.items == 0 then
        self.emptyLootText:Show()
    else
        self.emptyLootText:Hide()
    end
    local flavor = ns.Constants.GetClientFlavor()
    for index, row in ipairs(self.lootRows) do
        local entry = boss.items[self.lootOffset + index]
        if entry then
            local itemID = entry.itemID
            local name, link, quality, icon = GetItemDisplay(itemID)
            row.itemID = itemID
            row.itemLink = link
            row.category = entry.category
            row.questID = entry.questID
            row.questIDs = entry.questIDs
            row.factionAvailability = entry.factionAvailability
            row.turnInToken = entry.turnInToken
            row.dropChance = showDropEstimates and entry.dropChances
                and entry.dropChances[flavor] or nil
            row.dropChanceStatus = showDropEstimates and entry.dropChanceStatus or nil
            row.isTrashDrop = boss.kind == "trashDrops"
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            SetTruncatedText(row.name,
                name or string.format(ns.L.LOADING_ITEM, itemID))
            local color = quality and ITEM_QUALITY_COLORS[quality]
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(0.70, 0.70, 0.70)
            end
            local factionLabel = row.factionAvailability == "alliance" and "Alliance"
                or (row.factionAvailability == "horde" and "Horde" or nil)
            local itemMeta = {}
            if row.turnInToken then
                table.insert(itemMeta, ns.L.TURN_IN_TOKEN)
            end
            if factionLabel then
                table.insert(itemMeta, factionLabel)
            end
            row.meta:SetText(table.concat(itemMeta, "  •  "))
            if row.category == "questObjective" then
                row.chance:SetText(ns.L.QUEST_ITEM)
                row.chance:SetTextColor(1, 0.82, 0.38)
            elseif row.category == "startsQuest" then
                row.chance:SetText(ns.L.STARTS_QUEST)
                row.chance:SetTextColor(1, 0.82, 0.38)
            elseif row.dropChance then
                row.chance:SetText(string.format(ns.L.DROP_CHANCE,
                    FormatDropChance(row.dropChance)))
                row.chance:SetTextColor(0.92, 0.72, 0.30)
            elseif row.isTrashDrop and row.dropChanceStatus then
                row.chance:SetText(ns.L.DROP_VARIES)
                row.chance:SetTextColor(0.62, 0.62, 0.62)
            elseif row.dropChanceStatus then
                row.chance:SetText(ns.L.DROP_PENDING)
                row.chance:SetTextColor(0.62, 0.62, 0.62)
            else
                row.chance:SetText("—")
            end
            row:Show()
        else
            row.itemID = nil
            row.itemLink = nil
            row.category = nil
            row.questID = nil
            row.questIDs = nil
            row.factionAvailability = nil
            row.turnInToken = nil
            row.dropChance = nil
            row.dropChanceStatus = nil
            row.isTrashDrop = nil
            row:Hide()
        end
    end
end

function MainWindow:OnItemDataLoaded(itemID)
    if not self.frame or not self.frame:IsShown() then
        return
    end
    local instanceKey = self.selectedInstanceKey or "wailing_caverns"
    local instanceLoot = ns.Data.loot[instanceKey]
    local boss = self.selectedBossKey and instanceLoot and instanceLoot[self.selectedBossKey]
    if not boss then
        return
    end
    for _, entry in ipairs(boss.items) do
        if entry.itemID == itemID then
            self:RefreshLoot()
            return
        end
    end
end

function MainWindow:SavePosition()
    local database = ns.modules.Database.data
    if not database or not self.frame then
        return
    end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    database.settings.window = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
        scale = self.windowScale or 1,
    }
end

function MainWindow:RestorePosition()
    local database = ns.modules.Database.data
    local position = database and database.settings.window
    self:SetWindowScale(position and position.scale or 1)
    self.frame:ClearAllPoints()
    if position and position.point then
        self.frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
end

function MainWindow:ResetPosition()
    local database = ns.modules.Database.data
    if database then
        database.settings.window = {}
    end
    if self.frame then
        self:SetWindowScale(1)
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
end

function MainWindow:Toggle()
    self:Create()
    if self.frame:IsShown() then
        if self.instanceMenu then
            self.instanceMenu:Hide()
        end
        if self.floorMenu then
            self.floorMenu:Hide()
        end
        if self.feedbackDialog then
            self.feedbackDialog.editBox:ClearFocus()
            self.feedbackDialog:Hide()
        end
        if ns.modules.SettingsPanel then
            ns.modules.SettingsPanel:Hide()
        end
        self.frame:Hide()
    else
        local database = ns.modules.Database.data
        local browserSettings = database and database.settings.browser or {}
        if browserSettings.autoSelectCurrentInstance ~= false then
            self:SelectCurrentInstance()
        end
        self.frame:Show()
        self:RefreshLoot()
    end
end

function MainWindow:IsImplemented()
    return true
end
