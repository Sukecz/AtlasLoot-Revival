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
        minimap = {
            angle = 225,
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

local function Migrate(database)
    local version = tonumber(database.schemaVersion) or 0

    if version < 2 then
        database.settings = type(database.settings) == "table" and database.settings or {}
        database.settings.minimap = type(database.settings.minimap) == "table"
            and database.settings.minimap or {}
        if type(database.settings.minimap.angle) ~= "number" then
            database.settings.minimap.angle = defaults.settings.minimap.angle
        end
    end

    database.schemaVersion = ns.Constants.DATABASE_VERSION
end

function Database:Initialize()
    AtlasLootRevivalDB = AtlasLootRevivalDB or {}
    Migrate(AtlasLootRevivalDB)
    ApplyDefaults(AtlasLootRevivalDB, defaults)
    self.data = AtlasLootRevivalDB
end
