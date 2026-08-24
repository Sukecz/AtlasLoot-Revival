local _, ns = ...

ns.Constants = {
    DISPLAY_NAME = "AtlasLoot Revival",
    VERSION = "0.1.0-alpha.1",
    DATABASE_VERSION = 1,
    CLIENT_ERA = "era",
    CLIENT_TBC = "tbc",
}

function ns.Constants.GetClientFlavor()
    if WOW_PROJECT_BURNING_CRUSADE_CLASSIC
        and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        return ns.Constants.CLIENT_TBC
    end

    return ns.Constants.CLIENT_ERA
end
