function ns.Constants.GetClientFlavor()
    if WOW_PROJECT_BURNING_CRUSADE_CLASSIC
        and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        return ns.Constants.CLIENT_TBC
    end

    return ns.Constants.CLIENT_ERA
end
