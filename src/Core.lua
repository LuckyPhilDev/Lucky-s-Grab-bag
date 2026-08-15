-- Lucky's Grab-bag: A collection of small quality-of-life features.
LuckyGrabbag = LuckyGrabbag or {}

local ADDON_NAME = "Luckys_Grab_Bag"

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addonLoaded)
    if event == "ADDON_LOADED" and addonLoaded == ADDON_NAME then
        LuckyGrabbagDB = LuckyGrabbagDB or {} ---@diagnostic disable-line: lowercase-global
        LuckyGrabbagCharDB = LuckyGrabbagCharDB or {} ---@diagnostic disable-line: lowercase-global
        local db = LuckyGrabbagDB
        local charDB = LuckyGrabbagCharDB

        -- Migrate legacy single combat prep pull timer into mythic/raid split.
        if db.combatPrepTimer ~= nil then
            if db.combatPrepTimerMythic == nil then db.combatPrepTimerMythic = db.combatPrepTimer end
            if db.combatPrepTimerRaid == nil then db.combatPrepTimerRaid = db.combatPrepTimer end
            db.combatPrepTimer = nil
        end

        -- Migrate confirmPurchaseOverlay (overlay-on-item) → confirmPurchaseOnSide (inverted).
        if db.confirmPurchaseOverlay ~= nil then
            if db.confirmPurchaseOnSide == nil then
                db.confirmPurchaseOnSide = not db.confirmPurchaseOverlay
            end
            db.confirmPurchaseOverlay = nil
        end

        for key, default in pairs(LuckyGrabbag.DB_DEFAULTS) do
            if db[key] == nil then
                db[key] = default
            end
        end

        for key, default in pairs(LuckyGrabbag.CHAR_DB_DEFAULTS or {}) do
            if charDB[key] == nil then
                charDB[key] = default
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
        LuckyGrabbag.charDB = charDB

        LuckyGrabbag.Settings:Init(db, charDB)
        LuckyGrabbag.AutoRepair:Init(db)
        LuckyGrabbag.AutoSellJunk:Init(db)
        LuckyGrabbag.Quickbuy:Init(db)
        LuckyGrabbag.TestflightBuy:Init(db)
        LuckyGrabbag.Treatise:Init(db)
        LuckyGrabbag.ReagentMains:Init(db)
        LuckyGrabbag.WarboundAutoDeposit:Init(db)
        LuckyGrabbag.Cooking:Init(db)
        LuckyGrabbag.UseItems:Init(db)
        LuckyGrabbag.DelveMap:Init(db)
        LuckyGrabbag.CombatPrep:Init(db)
        LuckyGrabbag.RotationGlow:Init(db)
        LuckyGrabbag.PowerInfusion:Init(db, charDB)
        LuckyGrabbag.AutoCombatLog:Init(db)
        LuckyGrabbag.ConfirmPurchase:Init(db)
        LuckyGrabbag.Transmog:Init(db)
        LuckyGrabbag.TransmogSets:Init(db)
        LuckyGrabbag.WorkOrderAltTip:Init(db)
        LuckyGrabbag.BonusRoll:Init(charDB)
        LuckyGrabbag.InstanceDiag:Init(db)
        LuckyGrabbag.ProfessionSpendToPerk:Init(db)
        LuckyGrabbag.ConcentrationView:Init(db)
        LuckyGrabbag.RecipeSearchFilter:Init(db)
        LuckyGrabbag.EnchantStats:Init(db)
        LuckyGrabbag.OmniumFolio:Init(db, charDB)
        LuckyGrabbag.DecorTracking:Init(db)

        -- Minimap button
        LuckyGrabbag.minimapButton = LuckyMinimap:Create({
            name    = "LuckyGrabbagMinimapButton",
            tocname = "Luckys_Grab_Bag",
            icon    = "Interface\\AddOns\\Luckys_Utils\\Media\\promo-grab-bag.tga",
            dbKey   = "minimap",
            db      = db,
            onClick = function(_, mouseBtn)
                if mouseBtn == "MiddleButton" then
                    db.devMode = not db.devMode
                    LuckyGrabbag.InstanceDiag:Refresh()
                    local S = LuckyGrabbag.Strings
                    local state = db.devMode and S.minimap.devModeOn or S.minimap.devModeOff
                    print(LuckyGrabbag.PREFIX .. " " .. S.minimap.devModePrefix .. state)
                else
                    LuckySettings:Open(LuckyGrabbag.Settings.category)
                end
            end,
            tooltip = function(tt)
                local S = LuckyGrabbag.Strings
                tt:AddLine(LuckyUI.WC.goldPrimary .. S.minimap.tooltipTitle .. LuckyUI.WC.reset)
                tt:AddLine(" ")
                tt:AddLine(S.minimap.leftClick, 0.91, 0.86, 0.78)
                tt:AddLine(S.minimap.rightClick, 0.91, 0.86, 0.78)
                tt:AddLine(S.minimap.middleClick, 0.91, 0.86, 0.78)
                tt:AddLine(S.minimap.shiftDrag, 0.54, 0.49, 0.42)
            end,
        })

        eventFrame:UnregisterEvent("ADDON_LOADED")
    end
end)
