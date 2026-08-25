local _, ns = ...

local Database = ns:RegisterModule("Database", {})

local defaults = {
    schemaVersion = ns.Constants.DATABASE_VERSION,
    favorites = {},
    settings = {
        browser = {
            selectedContentType = "dungeon",
            selectedInstances = {},
            autoSelectCurrentInstance = true,
            showDropEstimates = true,
        },
        minimap = {
            angle = 225,
            shown = true,
        },
        map = {
            markerSize = "normal",
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

    if version < 3 then
        database.settings = type(database.settings) == "table" and database.settings or {}
        database.settings.browser = type(database.settings.browser) == "table"
            and database.settings.browser or {}
        database.settings.minimap = type(database.settings.minimap) == "table"
            and database.settings.minimap or {}
        database.settings.map = type(database.settings.map) == "table"
            and database.settings.map or {}
        if type(database.settings.browser.autoSelectCurrentInstance) ~= "boolean" then
            database.settings.browser.autoSelectCurrentInstance = true
        end
        if type(database.settings.browser.showDropEstimates) ~= "boolean" then
            database.settings.browser.showDropEstimates = true
        end
        if type(database.settings.minimap.shown) ~= "boolean" then
            database.settings.minimap.shown = true
        end
        if database.settings.map.markerSize ~= "small"
            and database.settings.map.markerSize ~= "normal"
            and database.settings.map.markerSize ~= "large" then
            database.settings.map.markerSize = "normal"
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
