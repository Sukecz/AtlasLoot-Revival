local addonName, ns = ...

local Events = ns:RegisterModule("Events", {})
Events.frame = CreateFrame("Frame")

function Events:OnAddonLoaded(loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    ns.modules.Database:Initialize()
    ns.modules.MinimapButton:Initialize()
    ns.modules.SlashCommands:Initialize()
    self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    self.frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    self.frame:UnregisterEvent("ADDON_LOADED")
end

Events.frame:RegisterEvent("ADDON_LOADED")
Events.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        Events:OnAddonLoaded(...)
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        ns.modules.MainWindow:OnItemDataLoaded(...)
    end
end)
