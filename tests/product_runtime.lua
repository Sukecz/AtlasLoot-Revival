-- Simulated frame API: exercises real UI methods, not visual rendering.
local root = assert(arg[1])
local widgets = {}
local methods = {}
local function widget(name)
    local object = setmetatable({ name = name, shown = true, scripts = {} }, { __index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^[A-Z]") then
            error("Unimplemented frame method: " .. key)
        end
    end })
    if name then
        assert(not widgets[name], "duplicate named frame: " .. name)
        widgets[name] = object
    end
    return object
end
function methods:CreateTexture() return widget() end
function methods:CreateFontString() return widget() end
function methods:SetScript(event, handler) self.scripts[event] = handler end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:SetSize(width, height) self.width = width; self.height = height end
function methods:GetWidth() return self.width or 200 end
function methods:GetHeight() return self.height or 100 end
function methods:GetStringWidth() return #(tostring(self.text or "")) * 5 end
function methods:GetFrameLevel() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetName() return self.name end
function methods:GetThumbTexture() self.thumb = self.thumb or widget(); return self.thumb end
function methods:SetValue(value) self.value = value end
function methods:SetPoint(...) self.point = {...} end
function methods:GetPoint() return unpack(self.point or {"CENTER", UIParent, "CENTER", 0, 20}) end
function methods:EnableMouse(value) self.mouseEnabled = value end
for _, name in ipairs({"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetAllPoints",
    "SetColorTexture", "SetTextColor", "SetJustifyH", "SetJustifyV", "SetWordWrap", "SetFont", "SetFontObject",
    "SetFrameLevel", "SetClampedToScreen", "SetMovable", "RegisterForDrag", "RegisterForClicks",
    "EnableMouseWheel", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetThumbTexture",
    "SetOrientation", "SetHighlightTexture", "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture",
    "SetHitRectInsets", "SetClipsChildren", "SetVertexColor", "SetAlpha", "SetDesaturated", "SetScale",
    "SetAutoFocus", "ClearFocus", "SetFocus", "HighlightText", "ClearAllPoints", "SetChecked",
    "RegisterEvent", "UnregisterEvent", "SetToplevel", "SetFrameStrata", "SetResizable", "SetResizeBounds",
    "SetBlendMode", "SetCheckedTexture", "SetShadowColor", "SetShadowOffset"}) do
    methods[name] = function() end
end
function methods:SetFrameStrata(value) self.frameStrata = value end
function methods:SetToplevel(value) self.toplevel = value end
CreateFrame = function(_, name) return widget(name) end
UIParent = widget("UIParent")
Minimap = widget("Minimap")
GameTooltip = widget("GameTooltip")
UISpecialFrames = {}
SlashCmdList = {}
STANDARD_TEXT_FONT = "test-font"
GetItemInfo = function() return nil end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
local tbc = arg[2] == "tbc"
WOW_PROJECT_ID = tbc and WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 2

local function loadProduct(id, toc)
    local ns = {}
    for line in io.lines(root .. "/" .. id .. "/" .. toc) do
        if line ~= "" and not line:match("^##") then
            assert(loadfile(root .. "/" .. id .. "/" .. line:gsub("\\", "/")))(id, ns)
        end
    end
    ns.modules.Events:OnAddonLoaded(id)
    ns.modules.MainWindow:Create()
    return ns
end

AtlasLootRevivalDB = { schemaVersion = 4, favorites = { [123] = true }, settings = {
    window = { point = "CENTER", x = 17, y = 24, scale = 0.9 },
    browser = { selectedInstances = { dungeon = "stratholme" } },
} }
local revival = loadProduct("AtlasLootRevival", tbc and "AtlasLootRevival_TBC.toc" or "AtlasLootRevival.toc")
local forever = loadProduct("AtlasLootForever", "AtlasLootForever.toc")
assert(revival.modules.MainWindow.frame.frameStrata == "MEDIUM")
assert(revival.modules.MainWindow.frame.toplevel == true)
assert(forever.modules.MainWindow.frame.frameStrata == "MEDIUM")
assert(forever.modules.MainWindow.frame.toplevel == true)
assert(AtlasLootRevivalDB ~= AtlasLootForeverDB, "products must not share saved settings")
assert(AtlasLootRevivalDB.favorites[123] and not AtlasLootForeverDB.favorites[123])
assert(AtlasLootRevivalDB.settings.window.scale == 0.9)
assert(revival.modules.MainWindow.selectedInstanceKey == "stratholme")
assert(SLASH_ATLASLOOTREVIVAL2 == "/alr" and SLASH_ATLASLOOTFOREVER2 == "/alf")
assert(BINDING_HEADER_ATLASLOOTREVIVAL == "AtlasLoot Revival")
assert(BINDING_HEADER_ATLASLOOTFOREVER == "AtlasLoot Forever")
assert(forever.Constants.GetClientFlavor() == "forever")
local window = forever.modules.MainWindow
assert(not window.contentTypeButtons.raid.shown, "empty raid catalog must be hidden")
assert(window.feedbackLink.mouseEnabled == false, "Forever must not link to Revival comments")
local baseline, announced = 0, 0
for key, instance in pairs(forever.Data.instances) do
    assert(instance.contentType == "dungeon" and instance.clientFlavors.forever)
    window:SelectInstance("stratholme")
    window:ScrollLootList(3)
    window:SelectInstance(key)
    if instance.verificationStatus == "announced" then
        announced = announced + 1
        assert(not instance.map and not instance.mapID and not instance.instanceID)
        assert(#instance.bosses == 0 and next(forever.Data.loot[key]) == nil)
        assert(not window.selectedBossKey and not window.selectedFloor)
        assert(window.mapEmptyText.shown and window.emptyLootText.shown)
        assert(window.emptyLootText.text == forever.L.DUNGEON_DETAILS_PENDING)
        assert(not window.floorButton.shown and not window.lootScrollbar.shown)
        assert(window.feedbackLink.label.text == forever.L.FOREVER_ANNOUNCED)
        for _, row in ipairs(window.lootRows) do assert(not row.shown and not row.itemID) end
        for _, pin in ipairs(window.mapPinRows) do assert(not pin.shown) end
        for _, tile in ipairs(window.mapTiles) do assert(not tile.shown) end
        for _, button in ipairs(window.bossButtonRows) do assert(not button.shown) end
        window:ToggleFloorMenu()
        window:SelectFloor(2)
        window:OnItemDataLoaded(123)
    else
        baseline = baseline + 1
        assert(instance.verificationStatus == "vanillaBaseline")
        assert(instance.map and not window.mapEmptyText.shown)
        assert(window.selectedBossKey and window.feedbackLink.label.text == forever.L.FOREVER_BASELINE)
        assert(revival.Data.instances[key].map.textureFolder == instance.map.textureFolder)
        for _, boss in pairs(forever.Data.loot[key]) do
            for _, item in ipairs(boss.items) do
                assert(not item.dropChances, "unverified Era rates must not become Forever estimates")
                assert(not item.clientFlavors or item.clientFlavors.forever)
            end
        end
    end
end
assert(baseline == 20 and announced == 9)
window:SelectInstance("wailing_caverns")
assert(window.mapTiles[1].shown and window.lootRows[1].shown, "baseline must restore after an empty dungeon")
assert(revival.modules.MainWindow.selectedInstanceKey == "stratholme", "Forever must not change Revival selection")
assert(AtlasLootRevivalDB.settings.browser.selectedInstances.dungeon == "stratholme")
local count = 0
for key, instance in pairs(revival.Data.instances) do
    revival.modules.MainWindow:SelectInstance(key)
    assert(revival.modules.MainWindow.selectedInstanceKey == key)
    assert(not revival.modules.MainWindow.mapEmptyText.shown)
    if instance.difficulties and instance.difficulties.heroic then
        revival.modules.MainWindow:SelectDifficulty("heroic")
        assert(revival.modules.MainWindow.selectedDifficulty == "heroic")
        revival.modules.MainWindow:SelectDifficulty("normal")
    end
    count = count + 1
end
assert(count == (tbc and 52 or 27), "Revival catalog changed")
assert(revival.modules.MainWindow.contentTypeButtons.raid.shown)
print("Product isolation and UI transitions passed for " .. (tbc and "TBC" or "Era")
    .. " (simulated API, not live rendering).")
