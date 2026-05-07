-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

function LuckyGrabbag.Settings:Init(db, charDB)
    local S = LuckyGrabbag.Strings
    local SS = S.settings

    local panel = LuckySettings:NewRichPanel(S.addon.title, {
        addonFolder    = "Luckys_Grab_Bag",
        imagesRoot     = "images",
        recentVersions = { "1.7.0", "1.6.0", "1.5.0" },
    })
    self.category = panel.category

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() panel:Open() end

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.general)

        g:Toggle({
            label    = SS.devMode.label,
            desc     = SS.devMode.desc,
            checked  = db.devMode,
            image    = "general/dev-mode",
            onToggle = function(checked) db.devMode = checked end,
        })

        local minimapState = db.minimap or {}
        g:Toggle({
            label    = SS.minimapButton.label,
            desc     = SS.minimapButton.desc,
            checked  = not minimapState.hide,
            image    = "general/minimap-button",
            onToggle = function(checked)
                if LuckyGrabbag.minimapButton then
                    LuckyGrabbag.minimapButton:SetShown_Persisted(checked)
                end
            end,
        })

        local gbVersion    = C_AddOns.GetAddOnMetadata("Luckys_Grab_Bag", "Version") or "?"
        local utilsVersion = C_AddOns.GetAddOnMetadata("Luckys_Utils",    "Version") or "?"
        g:BottomSection(SS.sections.versionInfo)
        g:BottomLabel({ label = SS.grabbagVersion.label,    value = "v" .. gbVersion })
        g:BottomLabel({ label = SS.luckyUtilsVersion.label, value = "v" .. utilsVersion })
    end

    ---------------------------------------------------------------------------
    -- Vendors
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.vendors)

        g:Section(SS.sections.automation)

        g:Toggle({
            label    = SS.autoRepair.label,
            desc     = SS.autoRepair.desc,
            checked  = db.autoRepair,
            image    = "vendors/auto-repair",
            onToggle = function(checked) db.autoRepair = checked end,
        })

        g:Toggle({
            label    = SS.useGuildFunds.label,
            desc     = SS.useGuildFunds.desc,
            checked  = db.autoRepairUseGuildFunds,
            parent   = SS.autoRepair.label,
            onToggle = function(checked) db.autoRepairUseGuildFunds = checked end,
        })

        g:Section(SS.sections.purchasing)

        g:Toggle({
            label     = SS.confirmPurchase.label,
            desc      = SS.confirmPurchase.desc,
            checked   = db.showConfirmPurchase,
            image     = "vendors/confirm-purchase-overlay",
            imageSize = { 979, 340 },
            onToggle  = function(checked)
                db.showConfirmPurchase = checked
                LuckyGrabbag.ConfirmPurchase:ApplySetting()
            end,
        })

        g:Toggle({
            label     = SS.confirmPurchaseOnSide.label,
            desc      = SS.confirmPurchaseOnSide.desc,
            checked   = db.confirmPurchaseOnSide,
            parent    = SS.confirmPurchase.label,
            image     = "vendors/confirm-purchase",
            imageSize = { 1072, 431 },
            onToggle  = function(checked)
                db.confirmPurchaseOnSide = checked
                LuckyGrabbag.ConfirmPurchase:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Auction House
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.auctionHouse)

        g:Toggle({
            label     = SS.quickbuy.label,
            desc      = SS.quickbuy.desc,
            checked   = db.showQuickbuy,
            image     = "auction-house/craftsim-quickbuy",
            imageSize = { 330, 153 },
            requires  = LuckyGrabbag.Quickbuy and LuckyGrabbag.Quickbuy.requires,
            onToggle  = function(checked)
                db.showQuickbuy = checked
                db.showQuickbuyAutoDefault = false
                LuckyGrabbag.Quickbuy:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.testflightBuy.label,
            desc     = SS.testflightBuy.desc,
            checked  = db.showTestflightBuy,
            requires = LuckyGrabbag.TestflightBuy and LuckyGrabbag.TestflightBuy.requires,
            onToggle = function(checked)
                db.showTestflightBuy = checked
                db.showTestflightBuyAutoDefault = false
                LuckyGrabbag.TestflightBuy:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Crafting
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.crafting)

        g:Toggle({
            label    = SS.treatise.label,
            desc     = SS.treatise.desc,
            checked  = db.showTreatise,
            image    = "crafting/treatise",
            onToggle = function(checked) db.showTreatise = checked end,
        })

        g:Toggle({
            label     = SS.cookingButtons.label,
            desc      = SS.cookingButtons.desc,
            checked   = db.showCookingButtons,
            image     = "crafting/cooking-buttons",
            imageSize = { 307, 159 },
            onToggle  = function(checked) db.showCookingButtons = checked end,
        })

        g:Toggle({
            label    = SS.reagentMains.label,
            desc     = SS.reagentMains.desc,
            checked  = db.reagentMainsEnabled,
            image    = "crafting/reagent-mains",
            since    = "1.5.0",
            onToggle = function(checked) db.reagentMainsEnabled = checked end,
        })

        g:Toggle({
            label    = SS.reagentMainsCurrentExpOnly.label,
            desc     = SS.reagentMainsCurrentExpOnly.desc,
            checked  = db.reagentMainsCurrentExpOnly,
            parent   = SS.reagentMains.label,
            onToggle = function(checked) db.reagentMainsCurrentExpOnly = checked end,
        })

        g:Button({
            label    = SS.configureMains.label,
            desc     = SS.configureMains.desc,
            parent   = SS.reagentMains.label,
            onClick  = function() LuckyGrabbag.ReagentMains:OpenPopup() end,
        })
    end

    ---------------------------------------------------------------------------
    -- Inventory
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.inventory)

        g:Toggle({
            label     = SS.useItems.label,
            desc      = SS.useItems.desc,
            checked   = db.showUseItems,
            image     = "inventory/use-items-popup",
            imageSize = { 400, 119 },
            onToggle  = function(checked)
                db.showUseItems = checked
                LuckyGrabbag.UseItems:ApplySetting()
            end,
        })

        g:Toggle({
            label     = SS.useItemsCityOnly.label,
            desc      = SS.useItemsCityOnly.desc,
            checked   = db.useItemsCityOnly,
            parent    = SS.useItems.label,
            image     = "inventory/use-items-popup",
            imageSize = { 400, 119 },
            onToggle  = function(checked)
                db.useItemsCityOnly = checked
                LuckyGrabbag.UseItems:ApplySetting()
            end,
        })

        g:Section(SS.sections.wardrobe)

        g:Toggle({
            label    = SS.transmog.label,
            desc     = SS.transmog.desc,
            checked  = db.keepTransmogTab,
            since    = "1.6.0",
            onToggle = function(checked) db.keepTransmogTab = checked end,
        })
    end

    ---------------------------------------------------------------------------
    -- Combat
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.combat)

        g:Toggle({
            label     = SS.combatPrep.label,
            desc      = SS.combatPrep.desc,
            checked   = db.showCombatPrep,
            image     = "combat/combat-prep-window",
            imageSize = { 178, 167 },
            onToggle  = function(checked)
                db.showCombatPrep = checked
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.combatPrepReadyCheck.label,
            desc     = SS.combatPrepReadyCheck.desc,
            checked  = db.combatPrepReadyCheck,
            parent   = SS.combatPrep.label,
            onToggle = function(checked)
                db.combatPrepReadyCheck = checked
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Slider({
            label    = SS.pullTimerMythic.label,
            key      = "CombatPrepTimerMythic",
            desc     = SS.pullTimerMythic.desc,
            min      = 3,
            max      = 30,
            value    = db.combatPrepTimerMythic,
            suffix   = SS.pullTimerMythic.suffix,
            parent   = SS.combatPrep.label,
            onChanged = function(val)
                db.combatPrepTimerMythic = val
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Slider({
            label    = SS.pullTimerRaid.label,
            key      = "CombatPrepTimerRaid",
            desc     = SS.pullTimerRaid.desc,
            min      = 3,
            max      = 30,
            value    = db.combatPrepTimerRaid,
            suffix   = SS.pullTimerRaid.suffix,
            parent   = SS.combatPrep.label,
            onChanged = function(val)
                db.combatPrepTimerRaid = val
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Slider({
            label    = SS.breakTimer.label,
            key      = "CombatPrepBreakTimer",
            desc     = SS.breakTimer.desc,
            min      = 1,
            max      = 15,
            value    = db.combatPrepBreakTimer,
            suffix   = SS.breakTimer.suffix,
            parent   = SS.combatPrep.label,
            onChanged = function(val)
                db.combatPrepBreakTimer = val
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Toggle({
            label     = SS.rotationGlow.label,
            desc      = SS.rotationGlow.desc,
            checked   = db.showRotationGlow,
            image     = "combat/rotation-glow",
            imageSize = { 415, 91 },
            onToggle  = function(checked)
                db.showRotationGlow = checked
                LuckyGrabbag.RotationGlow:ApplySetting()
            end,
        })

        g:Button({
            label   = SS.kickMacro.label,
            desc    = SS.kickMacro.desc,
            since   = "1.5.0",
            onClick = function() LuckyGrabbag.KickMacro:Create() end,
        })
    end

    ---------------------------------------------------------------------------
    -- Delves
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.delves)

        g:Toggle({
            label    = SS.delveMap.label,
            desc     = SS.delveMap.desc,
            checked  = db.showDelveMap,
            image    = "delves/trovehunters-bounty-map",
            onToggle = function(checked)
                db.showDelveMap = checked
                LuckyGrabbag.DelveMap:ApplySetting()
            end,
        })

        g:Slider({
            label    = SS.delveMapMinLevel.label,
            key      = "DelveMapMinLevel",
            desc     = SS.delveMapMinLevel.desc,
            min      = 1,
            max      = 11,
            value    = db.delveMapMinLevel,
            parent   = SS.delveMap.label,
            onChanged = function(val)
                db.delveMapMinLevel = val
                LuckyGrabbag.DelveMap:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Interface
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.interface)

        g:Toggle({
            label    = SS.bonusRoll.label,
            desc     = SS.bonusRoll.desc,
            note     = SS.bonusRoll.note,
            checked  = charDB.bonusRollAutoDismiss,
            since    = "1.7.0",
            onToggle = function(checked) charDB.bonusRollAutoDismiss = checked end,
        })

        g:Toggle({
            label    = SS.bonusRollKeepInMythicPlus.label,
            desc     = SS.bonusRollKeepInMythicPlus.desc,
            checked  = charDB.bonusRollKeepInMythicPlus,
            parent   = SS.bonusRoll.label,
            onToggle = function(checked) charDB.bonusRollKeepInMythicPlus = checked end,
        })

        g:Toggle({
            label    = SS.bonusRollKeepInRaids.label,
            desc     = SS.bonusRollKeepInRaids.desc,
            checked  = charDB.bonusRollKeepInRaids,
            parent   = SS.bonusRoll.label,
            onToggle = function(checked) charDB.bonusRollKeepInRaids = checked end,
        })

        local raidKeyToField = {
            lfr    = "bonusRollKeepInLFR",
            normal = "bonusRollKeepInNormalRaid",
            heroic = "bonusRollKeepInHeroicRaid",
            mythic = "bonusRollKeepInMythicRaid",
        }
        g:MultiSelect({
            label     = SS.bonusRollRaidDifficulties.label,
            desc      = SS.bonusRollRaidDifficulties.desc,
            parent    = SS.bonusRollKeepInRaids.label,
            options   = {
                { key = "lfr",    label = SS.bonusRollRaidDifficulties.optLFR },
                { key = "normal", label = SS.bonusRollRaidDifficulties.optNormal },
                { key = "heroic", label = SS.bonusRollRaidDifficulties.optHeroic },
                { key = "mythic", label = SS.bonusRollRaidDifficulties.optMythic },
            },
            isChecked = function(key) return charDB[raidKeyToField[key]] end,
            onToggle  = function(key, checked) charDB[raidKeyToField[key]] = checked end,
        })

        g:Toggle({
            label    = SS.bonusRollKeepInDelve.label,
            desc     = SS.bonusRollKeepInDelve.desc,
            checked  = charDB.bonusRollKeepInDelve,
            parent   = SS.bonusRoll.label,
            onToggle = function(checked) charDB.bonusRollKeepInDelve = checked end,
        })

        g:Toggle({
            label    = SS.bonusRollKeepInDungeon.label,
            desc     = SS.bonusRollKeepInDungeon.desc,
            checked  = charDB.bonusRollKeepInDungeon,
            parent   = SS.bonusRoll.label,
            onToggle = function(checked) charDB.bonusRollKeepInDungeon = checked end,
        })

        g:Toggle({
            label    = SS.bonusRollKeepInHunts.label,
            desc     = SS.bonusRollKeepInHunts.desc,
            checked  = charDB.bonusRollKeepInHunts,
            parent   = SS.bonusRoll.label,
            onToggle = function(checked) charDB.bonusRollKeepInHunts = checked end,
        })
    end

    panel:Finalize()
end
