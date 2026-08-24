local _, ns = ...

local Database = ns:RegisterModule("Database", {})

local defaults = {
    schemaVersion = ns.Constants.DATABASE_VERSION,
    favorites = {},
    settings = {
        browser = {
            selectedContentType = "dungeon",
            selectedInstances = {},
        },
        window = {},
    },
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Database:Initialize()
    AtlasLootRevivalDB = AtlasLootRevivalDB or {}
    ApplyDefaults(AtlasLootRevivalDB, defaults)
    self.data = AtlasLootRevivalDB
end
