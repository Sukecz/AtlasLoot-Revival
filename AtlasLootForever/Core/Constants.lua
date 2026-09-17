local _, ns = ...

ns.Constants = {
    DISPLAY_NAME = "AtlasLoot Forever",
    VERSION = "0.1.0-dev",
    DATABASE_VERSION = 4,
    CLIENT_ERA = "era",
    CLIENT_TBC = "tbc",
}

-- Product selection is explicit. No unverified Forever client constant is guessed.
function ns.Constants.GetClientFlavor()
    return "forever"
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
