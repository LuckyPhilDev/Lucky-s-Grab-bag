-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

function LuckyGrabbag.Settings:Init(db, charDB)
    local S = LuckyGrabbag.Strings
    local SS = S.settings

    local panel = LuckySettings:NewRichPanel(S.addon.title, {
        addonFolder    = "Luckys_Grab_Bag",
        imagesRoot     = "images",
        minVersion     = LuckyGrabbag.WHATS_NEW_MIN_VERSION,
        devMode        = {
            label    = SS.devMode.label,
            desc     = SS.devMode.desc,
            checked  = function() return db.devMode end,
            onToggle = function(checked) db.devMode = checked end,
        },
        minimapButton  = {
            label    = SS.minimapButton.label,
            desc     = SS.minimapButton.desc,
            checked  = function() return not (db.minimap or {}).hide end,
            onToggle = function(checked)
                if LuckyGrabbag.minimapButton then
                    LuckyGrabbag.minimapButton:SetShown_Persisted(checked)
                end
            end,
        },
    })
    self.category = panel.category

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function(msg)
        if strtrim(msg or ""):lower() == "decor" then
            LuckyGrabbag.DecorTracking:OpenList()
        else
            panel:Open()
        end
    end

    -- Dev Mode and the minimap button live in the title bar now, so General
    -- exists to host the What's New list.
    panel:Group(SS.groups.general)

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

        g:Toggle({
            label    = SS.autoSellJunk.label,
            desc     = SS.autoSellJunk.desc,
            checked  = db.autoSellJunk,
            since    = "1.14.0",
            onToggle = function(checked) db.autoSellJunk = checked end,
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

        g:Toggle({
            label    = SS.highlightTrackedDecor.label,
            desc     = SS.highlightTrackedDecor.desc,
            checked  = db.highlightTrackedDecor,
            since    = "1.20.0",
            onToggle = function(checked)
                db.highlightTrackedDecor = checked
                LuckyGrabbag.DecorTracking:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.decorAutoBuy.label,
            desc     = SS.decorAutoBuy.desc,
            checked  = db.decorAutoBuy,
            parent   = SS.highlightTrackedDecor.label,
            since    = "1.20.0",
            onToggle = function(checked)
                db.decorAutoBuy = checked
                LuckyGrabbag.DecorTracking:ApplySetting()
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
            label    = SS.questShopping.label,
            desc     = SS.questShopping.desc,
            checked  = db.questShopping,
            since    = "1.24.0",
            onToggle = function(checked)
                db.questShopping = checked
                LuckyGrabbag.QuestShopping:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.questShoppingAutoBuy.label,
            desc     = SS.questShoppingAutoBuy.desc,
            checked  = db.questShoppingAutoBuy,
            parent   = SS.questShopping.label,
            since    = "1.24.0",
            onToggle = function(checked) db.questShoppingAutoBuy = checked end,
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
            label    = SS.professionQuestAutoAccept.label,
            desc     = SS.professionQuestAutoAccept.desc,
            checked  = db.professionQuestAutoAccept,
            note     = SS.professionQuestAutoAccept.note,
            since    = "1.24.0",
            onToggle = function(checked) db.professionQuestAutoAccept = checked end,
        })

        g:Toggle({
            label    = SS.professionQuestAutoTurnIn.label,
            desc     = SS.professionQuestAutoTurnIn.desc,
            checked  = db.professionQuestAutoTurnIn,
            note     = SS.professionQuestAutoTurnIn.note,
            since    = "1.24.0",
            onToggle = function(checked) db.professionQuestAutoTurnIn = checked end,
        })

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
            label    = SS.autoTipAlt.label,
            desc     = SS.autoTipAlt.desc,
            checked  = db.autoTipAlt,
            since    = "1.10.0",
            onToggle = function(checked) db.autoTipAlt = checked end,
        })

        g:Toggle({
            label    = SS.spendToNextPerk.label,
            desc     = SS.spendToNextPerk.desc,
            checked  = db.spendToNextPerk,
            since    = "1.10.0",
            onToggle = function(checked) db.spendToNextPerk = checked end,
        })

        g:Toggle({
            label    = SS.recipeSearchFilter.label,
            desc     = SS.recipeSearchFilter.desc,
            checked  = db.searchSelectedExpansionOnly,
            since    = "1.19.4",
            onToggle = function(checked) db.searchSelectedExpansionOnly = checked end,
        })

        g:Toggle({
            label    = SS.concentrationView.label,
            desc     = SS.concentrationView.desc,
            checked   = db.showConcentration,
            since     = "1.12.0",
            image     = "crafting/concentration-view",
            imageSize = { 213, 243 },
            onToggle  = function(checked)
                db.showConcentration = checked
                LuckyGrabbag.ConcentrationView:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Auto-Deposit
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("Auto-Deposit")

        g:Section("Reagents")

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

        g:Toggle({
            label    = SS.warboundDepositLumber.label,
            desc     = SS.warboundDepositLumber.desc,
            checked  = db.warboundDepositLumber,
            since    = "1.11.0",
            onToggle = function(checked) db.warboundDepositLumber = checked end,
        })

        g:Section("Gear")

        g:Toggle({
            label    = SS.warboundAutoDeposit.label,
            desc     = SS.warboundAutoDeposit.desc,
            checked  = db.warboundAutoDepositEnabled,
            image    = "crafting/reagent-mains",
            since    = "1.11.0",
            onToggle = function(checked) db.warboundAutoDepositEnabled = checked end,
        })

        g:Toggle({
            label    = SS.warboundDepositArmor.label,
            desc     = SS.warboundDepositArmor.desc,
            checked  = db.warboundDepositArmor,
            parent   = SS.warboundAutoDeposit.label,
            onToggle = function(checked) db.warboundDepositArmor = checked end,
        })

        g:Toggle({
            label    = SS.warboundDepositWeapons.label,
            desc     = SS.warboundDepositWeapons.desc,
            checked  = db.warboundDepositWeapons,
            parent   = SS.warboundAutoDeposit.label,
            onToggle = function(checked) db.warboundDepositWeapons = checked end,
        })

        g:Toggle({
            label    = SS.warboundDepositTokens.label,
            desc     = SS.warboundDepositTokens.desc,
            checked  = db.warboundDepositTokens,
            parent   = SS.warboundAutoDeposit.label,
            onToggle = function(checked) db.warboundDepositTokens = checked end,
        })

        g:Section("Whitelist")

        g:Toggle({
            label    = SS.warboundItemWhitelist.label,
            desc     = SS.warboundItemWhitelist.desc,
            checked  = db.warboundItemWhitelist and true or false,
            parent   = SS.warboundAutoDeposit.label,
            since    = "1.11.0",
            onToggle = function(checked)
                if checked and not db.warboundItemWhitelist then
                    db.warboundItemWhitelist = {}
                end
            end,
        })

        g:Button({
            label    = SS.configureWhitelist.label,
            desc     = SS.configureWhitelist.desc,
            parent   = SS.warboundAutoDeposit.label,
            onClick  = function() LuckyGrabbag.WarboundAutoDeposit:OpenPopup() end,
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

        g:Toggle({
            label     = SS.massDelete.label,
            desc      = SS.massDelete.desc,
            checked   = db.massDelete,
            image     = "inventory/mass-delete",
            imageSize = { 782, 445 },
            since     = "1.22.0",
            onToggle  = function(checked) db.massDelete = checked end,
        })

        g:Toggle({
            label    = SS.mailSendAll.label,
            desc     = SS.mailSendAll.desc,
            checked  = db.mailSendAll,
            requires = LuckyGrabbag.MailSendAll and LuckyGrabbag.MailSendAll.requires,
            since    = "1.22.0",
            onToggle = function(checked) db.mailSendAll = checked end,
        })

        g:Toggle({
            label    = SS.enchantBadges.label,
            desc     = SS.enchantBadges.desc,
            checked  = db.showEnchantBadges,
            image     = "inventory/enchant-stat-badges",
            imageSize = { 109, 81 },
            since     = "1.15.0",
            onToggle = function(checked)
                db.showEnchantBadges = checked
                LuckyGrabbag.EnchantStats:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.enchantBadgesAH.label,
            desc     = SS.enchantBadgesAH.desc,
            checked  = db.enchantBadgesAH,
            parent   = SS.enchantBadges.label,
            onToggle = function(checked)
                db.enchantBadgesAH = checked
                LuckyGrabbag.EnchantStats:ApplySetting()
            end,
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

        g:Toggle({
            label    = SS.piPicker.label,
            desc     = SS.piPicker.desc,
            checked  = db.showPIPicker,
            since    = "1.13.0",
            onToggle = function(checked)
                db.showPIPicker = checked
                LuckyGrabbag.PowerInfusion:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.autoCombatLog.label,
            desc     = SS.autoCombatLog.desc,
            checked  = db.autoCombatLog,
            since    = "1.13.0",
            onToggle = function(checked)
                db.autoCombatLog = checked
                LuckyGrabbag.AutoCombatLog:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.autoCombatLogMythicPlus.label,
            desc     = SS.autoCombatLogMythicPlus.desc,
            checked  = db.autoCombatLogMythicPlus,
            parent   = SS.autoCombatLog.label,
            onToggle = function(checked)
                db.autoCombatLogMythicPlus = checked
                LuckyGrabbag.AutoCombatLog:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.autoCombatLogRaids.label,
            desc     = SS.autoCombatLogRaids.desc,
            checked  = db.autoCombatLogRaids,
            parent   = SS.autoCombatLog.label,
            onToggle = function(checked)
                db.autoCombatLogRaids = checked
                LuckyGrabbag.AutoCombatLog:ApplySetting()
            end,
        })

        local logRaidKeyToField = {
            lfr    = "autoCombatLogLFR",
            normal = "autoCombatLogNormalRaid",
            heroic = "autoCombatLogHeroicRaid",
            mythic = "autoCombatLogMythicRaid",
        }
        g:MultiSelect({
            label     = SS.autoCombatLogRaidDifficulties.label,
            desc      = SS.autoCombatLogRaidDifficulties.desc,
            parent    = SS.autoCombatLogRaids.label,
            options   = {
                { key = "lfr",    label = SS.autoCombatLogRaidDifficulties.optLFR },
                { key = "normal", label = SS.autoCombatLogRaidDifficulties.optNormal },
                { key = "heroic", label = SS.autoCombatLogRaidDifficulties.optHeroic },
                { key = "mythic", label = SS.autoCombatLogRaidDifficulties.optMythic },
            },
            isChecked = function(key) return db[logRaidKeyToField[key]] end,
            onToggle  = function(key, checked)
                db[logRaidKeyToField[key]] = checked
                LuckyGrabbag.AutoCombatLog:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.autoCombatLogCurrentSeason.label,
            desc     = SS.autoCombatLogCurrentSeason.desc,
            checked  = db.autoCombatLogCurrentSeasonOnly,
            parent   = SS.autoCombatLog.label,
            onToggle = function(checked)
                db.autoCombatLogCurrentSeasonOnly = checked
                LuckyGrabbag.AutoCombatLog:ApplySetting()
            end,
        })

        g:Button({
            label   = SS.kickMacro.label,
            desc    = SS.kickMacro.desc,
            since   = "1.5.0",
            onClick = function() LuckyGrabbag.KickMacro:Create() end,
        })

        g:Toggle({
            label    = SS.omniumFolio.label,
            desc     = SS.omniumFolio.desc,
            checked  = db.omniumFolioPerSpec,
            since    = "1.19.0",
            onToggle = function(checked)
                db.omniumFolioPerSpec = checked
                LuckyGrabbag.OmniumFolio:ApplySetting()
            end,
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
    -- Housing
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.housing)

        g:Toggle({
            label    = SS.blueprintTrackMissing.label,
            desc     = SS.blueprintTrackMissing.desc,
            checked  = db.blueprintTrackMissing,
            since    = "1.20.0",
            onToggle = function(checked)
                db.blueprintTrackMissing = checked
                LuckyGrabbag.DecorTracking:ApplySetting()
            end,
        })

        g:Toggle({
            label    = SS.blueprintImportHistory.label,
            desc     = SS.blueprintImportHistory.desc,
            checked  = db.blueprintImportHistory,
            since    = "1.22.1",
            onToggle = function(checked)
                db.blueprintImportHistory = checked
                LuckyGrabbag.BlueprintImportHistory:ApplySetting()
            end,
        })

        g:Button({
            label   = SS.openDecorList.label,
            desc    = SS.openDecorList.desc,
            onClick = function() LuckyGrabbag.DecorTracking:OpenList() end,
        })
    end

    ---------------------------------------------------------------------------
    -- Interface
    ---------------------------------------------------------------------------
    do
        local g = panel:Group(SS.groups.interface)

        g:Section(SS.sections.tooltips)

        -- Backed by the CVar itself, not saved variables: it already persists
        -- account-wide, and a mirror in the DB would only drift from it.
        g:Toggle({
            label    = SS.alwaysCompareItems.label,
            desc     = SS.alwaysCompareItems.desc,
            checked  = function() return C_CVar.GetCVar("alwaysCompareItems") == "1" end,
            since    = "1.19.4",
            onToggle = function(checked)
                C_CVar.SetCVar("alwaysCompareItems", checked and "1" or "0")
            end,
        })

        g:Section(SS.sections.wardrobe)

        g:Toggle({
            label    = SS.transmog.label,
            desc     = SS.transmog.desc,
            note     = SS.transmog.note,
            checked  = false,
            disabled = true,
            since    = "1.6.0",
            onToggle = function() end,
        })

        g:Toggle({
            label    = SS.trackTransmogSets.label,
            desc     = SS.trackTransmogSets.desc,
            note     = SS.trackTransmogSets.note,
            checked  = false,
            disabled = true,
            since    = "1.17.0",
            onToggle = function() end,
        })

        g:Toggle({
            label    = SS.bonusRoll.label,
            desc     = SS.bonusRoll.desc,
            note     = SS.bonusRoll.note,
            checked  = false,
            disabled = true,
            since    = "1.7.0",
            onToggle = function() end,
        })

        g:Toggle({
            label    = SS.bonusRollKeepInMythicPlus.label,
            desc     = SS.bonusRollKeepInMythicPlus.desc,
            checked  = charDB.bonusRollKeepInMythicPlus,
            parent   = SS.bonusRoll.label,
            onToggle = function(checked) charDB.bonusRollKeepInMythicPlus = checked end,
        })

        g:Slider({
            label     = SS.bonusRollMythicPlusMinLevel.label,
            key       = "BonusRollMythicPlusMinLevel",
            desc      = SS.bonusRollMythicPlusMinLevel.desc,
            min       = 2,
            max       = 10,
            value     = charDB.bonusRollMythicPlusMinLevel,
            parent    = SS.bonusRollKeepInMythicPlus.label,
            since     = "1.11.0",
            onChanged = function(val) charDB.bonusRollMythicPlusMinLevel = val end,
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

    local target = panel.whatsNewGroup
    if target then
        LuckyPromo:AddToRichGroup(target, "Luckys_Grab_Bag")
    end
end
