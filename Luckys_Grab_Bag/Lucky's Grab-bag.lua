-- Lucky's Grab-bag: A collection of small quality-of-life features.
LuckyGrabbag = LuckyGrabbag or {}

local ADDON_NAME = "Luckys_Grab_Bag"

local DB_DEFAULTS = {
    devMode              = false,
    showTreatise         = false,
    showCookingButtons   = true,
    showUseItems         = true,
    useItemsCityOnly     = false,
    showDelveMap         = true,
    delveMapMinLevel     = 8,
    showCombatPrep       = false,
    combatPrepReadyCheck = false,
    combatPrepTimer      = 10,
    combatPrepBreakTimer = 5,
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
            db.showQuickbuy = LuckyDeps:IsEnabled(LuckyGrabbag.Quickbuy.requires.addon)
        end

        -- Re-evaluate showTestflightBuy automatically until the user explicitly changes it.
        if db.showTestflightBuyAutoDefault ~= false then
            db.showTestflightBuy = LuckyDeps:IsEnabled(LuckyGrabbag.TestflightBuy.requires.addon)
        end

        LuckyGrabbag.db = db

        LuckyGrabbag.Settings:Init(db)
        LuckyGrabbag.Quickbuy:Init(db)
        LuckyGrabbag.TestflightBuy:Init(db)
        LuckyGrabbag.Treatise:Init(db)
        LuckyGrabbag.Cooking:Init(db)
        LuckyGrabbag.UseItems:Init(db)
        LuckyGrabbag.DelveMap:Init(db)
        LuckyGrabbag.CombatPrep:Init(db)

        -- Minimap button
        LuckyGrabbag.minimapButton = LuckyMinimap:Create({
            name    = "LuckyGrabbagMinimapButton",
            icon    = "Interface\\Icons\\INV_Misc_Bag_36",
            dbKey   = "minimap",
            db      = db,
            onClick = function(_, mouseBtn)
                if mouseBtn == "MiddleButton" then
                    db.devMode = not db.devMode
                    local state = db.devMode and "ON" or "OFF"
                    print(LuckyGrabbag.PREFIX .. " Dev mode " .. state)
                else
                    LuckySettings:Open(LuckyGrabbag.Settings.category)
                end
            end,
            tooltip = function(tt)
                tt:AddLine(LuckyUI.WC.goldPrimary .. "Lucky's Grab-bag" .. LuckyUI.WC.reset)
                tt:AddLine(" ")
                tt:AddLine("Left-click: Open settings", 0.91, 0.86, 0.78)
                tt:AddLine("Right-click: Open settings", 0.91, 0.86, 0.78)
                tt:AddLine("Middle-click: Toggle dev mode", 0.91, 0.86, 0.78)
                tt:AddLine("Shift+drag: Move button", 0.54, 0.49, 0.42)
            end,
        })

        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end)
