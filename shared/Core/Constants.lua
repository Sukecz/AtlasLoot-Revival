local _, ns = ...

ns.Constants = {
    DISPLAY_NAME = "__DISPLAY_NAME__",
    VERSION = "__VERSION__",
    DATABASE_VERSION = 4,
    CLIENT_ERA = "era",
    CLIENT_TBC = "tbc",
}

__CLIENT_FLAVOR_IMPLEMENTATION__

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
