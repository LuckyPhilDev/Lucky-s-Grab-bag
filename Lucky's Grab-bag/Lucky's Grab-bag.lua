-- Lucky's Grab-bag: A collection of small quality-of-life features.
LuckyGrabbag = LuckyGrabbag or {}

local ADDON_NAME = "Lucky's Grab-bag"

local DB_DEFAULTS = {
    devMode      = false,
    showQuickbuy = true,
}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addonLoaded)
    if event == "ADDON_LOADED" and addonLoaded == ADDON_NAME then
        LuckyGrabbagDB = LuckyGrabbagDB or {} ---@diagnostic disable-line: lowercase-global
        local db = LuckyGrabbagDB

        for key, default in pairs(DB_DEFAULTS) do
            if db[key] == nil then
                db[key] = default
            end
        end

        LuckyGrabbag.Settings:Init(db)
        LuckyGrabbag.Quickbuy:Init(db)

        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end)
