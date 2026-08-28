local _, ns = ...

local SlashCommands = ns:RegisterModule("SlashCommands", {})

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd6a84bAtlasLoot Revival:|r " .. message)
end

local function GetCatalogStatus()
    local flavor = ns.Constants.GetClientFlavor()
    local dungeonCount = 0
    local raidCount = 0
    local encounterCount = 0
    local relationCount = 0
    for instanceKey, instance in pairs(ns.Data.instances) do
        if ns.Constants.SupportsInstanceFlavor(instance, flavor) then
            if instance.contentType == "raid" then
                raidCount = raidCount + 1
            else
                dungeonCount = dungeonCount + 1
            end
            local instanceLoot = ns.Data.loot[instanceKey] or {}
            for _, bossKey in ipairs(instance.bosses) do
                local boss = instanceLoot[bossKey]
                if boss then
                    encounterCount = encounterCount + 1
                    relationCount = relationCount + #boss.items
                end
            end
            local trashDrops = instanceLoot.trash_drops
            if trashDrops then
                relationCount = relationCount + #trashDrops.items
            end
        end
    end
    return string.format(ns.L.STATUS_READY, dungeonCount, raidCount,
        encounterCount, relationCount)
end

function SlashCommands:Handle(input)
    local command = string.lower((input or ""):match("^%s*(.-)%s*$"))

    if command == "" or command == "browse" then
        ns.modules.MainWindow:Toggle()
        return
    end

    if command == "status" then
        Print(GetCatalogStatus())
        return
    end

    if command == "reset" then
        ns.modules.MainWindow:ResetPosition()
        Print("Window position reset.")
        return
    end

    Print(ns.L.USAGE)
end

function SlashCommands:Initialize()
    SLASH_ATLASLOOTREVIVAL1 = "/atlaslootrevival"
    SLASH_ATLASLOOTREVIVAL2 = "/alr"
    SlashCmdList.ATLASLOOTREVIVAL = function(input)
        self:Handle(input)
    end
end
