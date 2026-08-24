local _, ns = ...

local MainWindow = ns:RegisterModule("MainWindow", {})

local WINDOW_WIDTH = 940
local WINDOW_HEIGHT = 600
local SIDEBAR_WIDTH = 174
local MAP_WIDTH = 456
local MAP_HEIGHT = 342
local TILE_SIZE = 114
local MIN_WINDOW_SCALE = 0.75
local MAX_WINDOW_SCALE = 1.25
local MAX_ENCOUNTER_BUTTONS = 16
local MAX_MAP_PINS = 32
local MAX_LOOT_ROWS = 10
local TRASH_DROPS_KEY = "trash_drops"
local selectedColor = { 0.82, 0.58, 0.20 }

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

local function SetButtonHighlight(button, selected)
    if selected then
        button.background:SetColorTexture(selectedColor[1], selectedColor[2], selectedColor[3], 0.22)
        button.label:SetTextColor(1, 0.82, 0.38)
    else
        button.background:SetColorTexture(1, 1, 1, 0.035)
        button.label:SetTextColor(0.82, 0.82, 0.82)
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
        if left.levelMin == right.levelMin then
            return left.name < right.name
        end
        return left.levelMin < right.levelMin
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
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")

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
        MainWindow.frame:Hide()
    end)
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
    dungeonButton.label:SetPoint("TOPLEFT", 31, -7)
    dungeonButton.label:SetPoint("RIGHT", -31, 0)
    dungeonButton.label:SetJustifyH("CENTER")
    dungeonButton.label:SetTextColor(1, 0.82, 0.38)
    dungeonButton.range = dungeonButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dungeonButton.range:SetPoint("BOTTOM", 0, 6)
    dungeonButton.range:SetTextColor(0.55, 0.55, 0.55)
    self.dungeonButton = dungeonButton

    local previous = CreateFrame("Button", nil, dungeonButton)
    previous:SetPoint("LEFT", 5, 0)
    previous:SetSize(24, 32)
    previous.label = previous:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    previous.label:SetPoint("CENTER", -1, 0)
    previous.label:SetText("‹")
    previous.label:SetTextColor(0.78, 0.61, 0.25)
    previous:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    previous:SetScript("OnClick", function()
        MainWindow:CycleInstance(-1)
    end)

    local nextButton = CreateFrame("Button", nil, dungeonButton)
    nextButton:SetPoint("RIGHT", -5, 0)
    nextButton:SetSize(24, 32)
    nextButton.label = nextButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    nextButton.label:SetPoint("CENTER", 1, 0)
    nextButton.label:SetText("›")
    nextButton.label:SetTextColor(0.78, 0.61, 0.25)
    nextButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    nextButton:SetScript("OnClick", function()
        MainWindow:CycleInstance(1)
    end)

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
    self.mapHeading:SetPoint("TOPLEFT", 202, -62)
    self.mapHeading:SetTextColor(0.68, 0.68, 0.68)

    self.floorNext = CreateFrame("Button", nil, parent)
    self.floorNext:SetSize(18, 18)
    self.floorNext:SetPoint("TOPRIGHT", -280, -55)
    self.floorNext.label = self.floorNext:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.floorNext.label:SetPoint("CENTER")
    self.floorNext.label:SetText("›")
    self.floorNext:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    self.floorNext:SetScript("OnClick", function()
        MainWindow:CycleFloor(1)
    end)

    self.floorLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.floorLabel:SetPoint("RIGHT", self.floorNext, "LEFT", -3, 0)
    self.floorLabel:SetWidth(112)
    self.floorLabel:SetJustifyH("RIGHT")
    self.floorLabel:SetTextColor(0.58, 0.58, 0.58)

    self.floorPrevious = CreateFrame("Button", nil, parent)
    self.floorPrevious:SetSize(18, 18)
    self.floorPrevious:SetPoint("RIGHT", self.floorLabel, "LEFT", -3, 0)
    self.floorPrevious.label = self.floorPrevious:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.floorPrevious.label:SetPoint("CENTER")
    self.floorPrevious.label:SetText("‹")
    self.floorPrevious:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    self.floorPrevious:SetScript("OnClick", function()
        MainWindow:CycleFloor(-1)
    end)

    local map = CreateBackdropFrame("Frame", nil, parent)
    map:SetSize(MAP_WIDTH + 8, MAP_HEIGHT + 8)
    map:SetPoint("TOPLEFT", 198, -80)
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
        pin:SetHitRectInsets(-2, -16, -2, -2)
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
            MainWindow:SelectBoss(clicked.bossKey)
        end)
        pin:SetScript("OnEnter", function(entered)
            local instanceLoot = ns.Data.loot[MainWindow.selectedInstanceKey]
            local encounter = instanceLoot and instanceLoot[entered.bossKey]
            if not encounter then
                return
            end
            entered.ring:SetAlpha(entered.isSelected and 1 or 0.58)
            entered.ring:Show()
            GameTooltip:SetOwner(entered, "ANCHOR_RIGHT")
            GameTooltip:AddLine(encounter.name, 1, 0.82, 0.38)
            GameTooltip:AddLine("Click to view loot", 0.72, 0.72, 0.72)
            GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function(left)
            if not left.isSelected then
                left.ring:Hide()
            end
            GameTooltip:Hide()
        end)
        pin:Hide()
        self.mapPinRows[index] = pin
    end

    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 5, -9)
    note:SetText("Click a numbered marker to inspect its loot.")
    note:SetTextColor(0.48, 0.48, 0.48)
end

function MainWindow:CreateLootPanel(parent)
    local panel = CreateBackdropFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", 674, -55)
    panel:SetPoint("BOTTOMRIGHT", -12, 34)
    SetBackdropColor(panel, 0.035, 0.035, 0.035, 0.96)
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
    self.lootPrevious:SetPoint("TOPLEFT", 113, -67)
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
        row:SetPoint("TOPLEFT", 10, -94 - ((index - 1) * 40))
        row:SetPoint("TOPRIGHT", -10, -94 - ((index - 1) * 40))
        row:SetHeight(36)
        row.background = row:CreateTexture(nil, "BACKGROUND")
        row.background:SetAllPoints()
        row.background:SetColorTexture(1, 1, 1, 0.025)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(30, 30)
        row.icon:SetPoint("LEFT", 5, 0)
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
        row.name:SetPoint("RIGHT", -78, 0)
        row.name:SetJustifyH("LEFT")
        row.id = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.id:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
        row.id:SetPoint("RIGHT", -78, 0)
        row.id:SetJustifyH("LEFT")
        row.id:SetTextColor(0.45, 0.45, 0.45)
        row.chance = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.chance:SetPoint("RIGHT", -5, 0)
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
    self:CreateSidebar(content)
    self:CreateMap(content)
    self:CreateLootPanel(content)
    self:CreateResizeHandle(frame)

    local footer = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", 16, 14)
    footer:SetText(ns.L.STATUS_LIVE_QA)
    footer:SetTextColor(0.42, 0.42, 0.42)

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

function MainWindow:RefreshContentTypeButtons()
    for contentType, button in pairs(self.contentTypeButtons or {}) do
        SetButtonHighlight(button, contentType == self.selectedContentType)
    end
end

function MainWindow:RefreshSidebar()
    local instance = ns.Data.instances[self.selectedInstanceKey]
    local instanceLoot = instance and ns.Data.loot[instance.key]
    if not instance or not instanceLoot then
        return
    end

    self.dungeonButton.label:SetText(instance.name)
    self.dungeonButton.range:SetText(string.format(ns.L.LEVEL_RANGE,
        instance.levelMin, instance.levelMax))
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
    self.floorLabel:SetText(floorData.name)
    if #mapData.floors > 1 then
        self.floorLabel:Show()
        self.floorPrevious:Show()
        self.floorNext:Show()
    else
        self.floorLabel:Hide()
        self.floorPrevious:Hide()
        self.floorNext:Hide()
    end
    local tileCount = mapData.columns * mapData.rows
    for tileIndex, tile in ipairs(self.mapTiles) do
        if tileIndex <= tileCount then
            local folder = mapData.textureFolder
            tile:SetTexture("Interface\\WorldMap\\" .. folder .. "\\"
                .. folder .. floorData.index .. "_" .. tileIndex)
            tile:Show()
        else
            tile:Hide()
        end
    end

    self.mapPins = {}
    local pinSlot = 1
    for encounterIndex, bossKey in ipairs(instance.bosses) do
        local boss = instanceLoot[bossKey]
        if boss and boss.floor == floorData.index and boss.x and boss.y then
            local pin = self.mapPinRows[pinSlot]
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", self.mapCanvas, "TOPLEFT",
                boss.x * MAP_WIDTH, -(boss.y * MAP_HEIGHT))
            pin.bossKey = bossKey
            pin.number:SetText(encounterIndex)
            pin.isSelected = false
            pin.ring:Hide()
            pin:Show()
            self.mapPins[bossKey] = pin
            pinSlot = pinSlot + 1
        end
    end
    for index = pinSlot, #self.mapPinRows do
        local pin = self.mapPinRows[index]
        pin.bossKey = nil
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

function MainWindow:CycleFloor(delta)
    local instance = ns.Data.instances[self.selectedInstanceKey]
    if not instance or #instance.map.floors < 2 then
        return
    end

    local floorCount = #instance.map.floors
    self.selectedFloor = ((self.selectedFloor - 1 + delta) % floorCount) + 1
    self:RefreshMap()
    if self.selectedBossKey then
        self:SelectBoss(self.selectedBossKey, true)
    end
end

function MainWindow:CycleInstance(delta)
    local order = self.instanceOrder or GetAvailableInstanceKeys(self.selectedContentType)
    if #order < 2 then
        return
    end

    local currentIndex = 1
    for index, key in ipairs(order) do
        if key == self.selectedInstanceKey then
            currentIndex = index
            break
        end
    end
    local nextIndex = ((currentIndex - 1 + delta) % #order) + 1
    self:SelectInstance(order[nextIndex])
end

function MainWindow:SelectBoss(bossKey, keepFloor)
    local instanceKey = self.selectedInstanceKey or "wailing_caverns"
    local boss = ns.Data.loot[instanceKey] and ns.Data.loot[instanceKey][bossKey]
    if not boss then
        return
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
    if boss.kind ~= "trashDrops" and (not boss.x or not boss.y) then
        meta = meta .. "  •  " .. ns.L.MAP_POSITION_PENDING
    end
    self.bossMeta:SetText(meta)

    for key, button in pairs(self.bossButtons) do
        SetButtonHighlight(button, key == bossKey)
    end
    for key, pin in pairs(self.mapPins) do
        if key == bossKey then
            pin.isSelected = true
            pin.ring:SetAlpha(1)
            pin.ring:Show()
            pin.number:SetTextColor(1, 0.92, 0.55)
        else
            pin.isSelected = false
            pin.ring:Hide()
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
    self.dropChanceHeading:SetText(ns.L.DROP_CHANCE_HEADING)
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
            row.dropChance = entry.dropChances and entry.dropChances[flavor]
            row.dropChanceStatus = entry.dropChanceStatus
            row.isTrashDrop = boss.kind == "trashDrops"
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(name or string.format(ns.L.LOADING_ITEM, itemID))
            local color = quality and ITEM_QUALITY_COLORS[quality]
            if color then
                row.name:SetTextColor(color.r, color.g, color.b)
            else
                row.name:SetTextColor(0.70, 0.70, 0.70)
            end
            local factionLabel = row.factionAvailability == "alliance" and "Alliance"
                or (row.factionAvailability == "horde" and "Horde" or nil)
            if row.questIDs then
                row.id:SetText(string.format("Item %d  •  Quests %s%s",
                    itemID, JoinQuestIDs(row.questIDs),
                    factionLabel and ("  •  " .. factionLabel) or ""))
            elseif row.questID then
                row.id:SetText(string.format("Item %d  •  Quest %d%s", itemID, row.questID,
                    factionLabel and ("  •  " .. factionLabel) or ""))
            else
                row.id:SetText("Item " .. itemID)
            end
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
        self.frame:Hide()
    else
        self:SelectCurrentInstance()
        self.frame:Show()
        self:RefreshLoot()
    end
end

function MainWindow:IsImplemented()
    return true
end
