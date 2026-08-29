local _, ns = ...

ns.Constants = {
    DISPLAY_NAME = "AtlasLoot Revival",
    VERSION = "0.2.1",
    DATABASE_VERSION = 4,
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

function ns.Constants.SupportsInstanceFlavor(instance, flavor)
    if not instance then
        return false
    end

    if instance.clientFlavors and instance.clientFlavors[flavor] then
        return true
    end

    return flavor == ns.Constants.CLIENT_TBC
        and instance.contentExpansion ~= "tbc"
end
