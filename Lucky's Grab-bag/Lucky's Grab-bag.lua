-- Lucky's Grab-bag: A collection of small quality-of-life features.
LuckyGrabbag = LuckyGrabbag or {}

local ADDON_NAME = "Lucky's Grab-bag"

local DB_DEFAULTS = {
    devMode            = false,
    showTreatise       = true,
    showCookingButtons = true,
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

        -- Re-evaluate showQuickbuy automatically until the user explicitly changes it.
        if db.showQuickbuyAutoDefault ~= false then
            db.showQuickbuy = LuckyGrabbag.Dependencies.IsEnabled(LuckyGrabbag.Quickbuy.requires.addon)
        end

        LuckyGrabbag.db = db

        LuckyGrabbag.Settings:Init(db)
        LuckyGrabbag.Quickbuy:Init(db)
        LuckyGrabbag.Treatise:Init(db)
        LuckyGrabbag.Cooking:Init(db)

        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end)
