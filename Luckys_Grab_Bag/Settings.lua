-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

function LuckyGrabbag.Settings:Init(db)
    local panel = LuckySettings:NewRichPanel("Lucky's Grab-bag", {
        addonFolder = "Luckys_Grab_Bag",
        imagesRoot  = "images",
    })
    self.category = panel.category

    SLASH_LUCKYGB1 = "/grabbag"
    SlashCmdList["LUCKYGB"] = function() panel:Open() end

    ---------------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("General")

        g:Toggle({
            label    = "Dev Mode",
            desc     = "Development logging and diagnostics. Has no visible effect for regular users.",
            checked  = db.devMode,
            image    = "general/dev-mode",
            onToggle = function(checked) db.devMode = checked end,
        })

        local minimapState = db.minimap or {}
        g:Toggle({
            label    = "Minimap Button",
            desc     = "Show the Lucky's Grab-bag button on the minimap. Shift-drag to reposition it.",
            checked  = not minimapState.hide,
            image    = "general/minimap-button",
            onToggle = function(checked)
                if LuckyGrabbag.minimapButton then
                    LuckyGrabbag.minimapButton:SetShown_Persisted(checked)
                end
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Vendors
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("Vendors")

        g:Toggle({
            label    = "Auto Repair",
            desc     = "Automatically repair all damaged gear when you open a vendor that can repair.",
            checked  = db.autoRepair,
            image    = "vendors/auto-repair",
            onToggle = function(checked) db.autoRepair = checked end,
        })

        g:Toggle({
            label    = "Use Guild Funds",
            desc     = "Pay repair costs from the guild bank if your guild allows it. Falls back to your own gold otherwise.",
            checked  = db.autoRepairUseGuildFunds,
            parent   = "Auto Repair",
            onToggle = function(checked) db.autoRepairUseGuildFunds = checked end,
        })

        g:Toggle({
            label    = "Confirm Purchase",
            desc     = "When a currency confirmation popup appears at a vendor, shows a large tick button that clicks the confirm option. Right-click and drag to reposition.",
            checked  = db.showConfirmPurchase,
            image    = "vendors/confirm-purchase",
            onToggle = function(checked)
                db.showConfirmPurchase = checked
                LuckyGrabbag.ConfirmPurchase:ApplySetting()
            end,
        })

        g:Toggle({
            label    = "Overlay on Clicked Item",
            desc     = "Place the confirm button directly on top of the vendor item you clicked. When disabled, the button anchors next to the vendor window and can be dragged.",
            checked  = db.confirmPurchaseOverlay,
            parent   = "Confirm Purchase",
            image    = "vendors/confirm-purchase-overlay",
            onToggle = function(checked)
                db.confirmPurchaseOverlay = checked
                LuckyGrabbag.ConfirmPurchase:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Auction House
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("Auction House")

        g:Toggle({
            label    = "CraftSim Quickbuy",
            desc     = "Adds a button next to the Auction House. Each click purchases one row of items from your CraftSim crafting queue's shopping list.",
            checked  = db.showQuickbuy,
            image    = "auction-house/craftsim-quickbuy",
            requires = LuckyGrabbag.Quickbuy and LuckyGrabbag.Quickbuy.requires,
            onToggle = function(checked)
                db.showQuickbuy = checked
                db.showQuickbuyAutoDefault = false
                LuckyGrabbag.Quickbuy:ApplySetting()
            end,
        })

        g:Toggle({
            label    = "TestFlight Buy Next",
            desc     = "Adds a button next to the Auction House that steps through Auctionator's purchase workflow — selecting, buying, and confirming each item in turn.",
            checked  = db.showTestflightBuy,
            image    = "auction-house/testflight-buy",
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
        local g = panel:Group("Crafting")

        g:Toggle({
            label    = "Thalassian Treatise",
            desc     = "When you open the Warband Bank, automatically withdraws any Thalassian Treatises for your current professions that you haven't used this week.",
            checked  = db.showTreatise,
            image    = "crafting/treatise",
            onToggle = function(checked) db.showTreatise = checked end,
        })

        g:Toggle({
            label    = "Cooking Utility Buttons",
            desc     = "Adds a Campfire button (casts Basic Campfire) and a Chef's Hat toggle alongside the Cooking profession window.",
            checked  = db.showCookingButtons,
            image    = "crafting/cooking-buttons",
            onToggle = function(checked) db.showCookingButtons = checked end,
        })

        g:Toggle({
            label    = "Reagent Mains",
            desc     = "When you open the warband bank on a non-main character, reagents in categories assigned to other mains are deposited automatically.",
            checked  = db.reagentMainsEnabled,
            image    = "crafting/reagent-mains",
            onToggle = function(checked) db.reagentMainsEnabled = checked end,
        })

        g:Button({
            label    = "Configure mains…",
            desc     = "Open the reagent mains assignment window to choose which character handles each reagent category.",
            parent   = "Reagent Mains",
            onClick  = function() LuckyGrabbag.ReagentMains:OpenPopup() end,
        })
    end

    ---------------------------------------------------------------------------
    -- Inventory
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("Inventory")

        g:Toggle({
            label     = "Use Items Popup",
            desc      = "Floating buttons for Artisan's Consortium Payouts, Glimmers/Flickers of Midnight Knowledge, and Thalassian Treatises in your bags. Draggable, auto-hides when empty.",
            checked   = db.showUseItems,
            image     = "inventory/use-items-popup",
            imageSize = { 400, 119 },
            onToggle  = function(checked)
                db.showUseItems = checked
                LuckyGrabbag.UseItems:ApplySetting()
            end,
        })

        g:Toggle({
            label     = "Only in Cities",
            desc      = "Hide the Use Items popup when you're outside of rest areas (cities and inns).",
            checked   = db.useItemsCityOnly,
            parent    = "Use Items Popup",
            image     = "inventory/use-items-popup",
            imageSize = { 400, 119 },
            onToggle  = function(checked)
                db.useItemsCityOnly = checked
                LuckyGrabbag.UseItems:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Combat
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("Combat")

        g:Toggle({
            label    = "Combat Prep Window",
            desc     = "Floating window with pull timer and ready check buttons, shown when you're out of combat in a raid or Mythic+ dungeon. Right-click and drag to reposition.",
            checked  = db.showCombatPrep,
            image    = "combat/combat-prep-window",
            onToggle = function(checked)
                db.showCombatPrep = checked
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Toggle({
            label    = "Ready Check Button",
            desc     = "Show the ready check button on the combat prep window.",
            checked  = db.combatPrepReadyCheck,
            parent   = "Combat Prep Window",
            onToggle = function(checked)
                db.combatPrepReadyCheck = checked
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Slider({
            label    = "Pull Timer (Mythic+)",
            key      = "CombatPrepTimerMythic",
            desc     = "Countdown duration for the pull timer button when you're in a Mythic+ dungeon.",
            min      = 3,
            max      = 30,
            value    = db.combatPrepTimerMythic,
            suffix   = "s",
            parent   = "Combat Prep Window",
            onChanged = function(val)
                db.combatPrepTimerMythic = val
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Slider({
            label    = "Pull Timer (Raid)",
            key      = "CombatPrepTimerRaid",
            desc     = "Countdown duration for the pull timer button when you're in a raid.",
            min      = 3,
            max      = 30,
            value    = db.combatPrepTimerRaid,
            suffix   = "s",
            parent   = "Combat Prep Window",
            onChanged = function(val)
                db.combatPrepTimerRaid = val
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Slider({
            label    = "Break Timer Duration",
            key      = "CombatPrepBreakTimer",
            desc     = "Default duration for the break timer button on the combat prep window.",
            min      = 1,
            max      = 15,
            value    = db.combatPrepBreakTimer,
            suffix   = "m",
            parent   = "Combat Prep Window",
            onChanged = function(val)
                db.combatPrepBreakTimer = val
                LuckyGrabbag.CombatPrep:ApplySetting()
            end,
        })

        g:Toggle({
            label    = "Rotation Glow",
            desc     = "Animates the suggested next-cast spell on the Essential Cooldown Viewer. Requires the Essential Cooldown Viewer to be enabled in Edit Mode.",
            checked  = db.showRotationGlow,
            image    = "combat/rotation-glow",
            onToggle = function(checked)
                db.showRotationGlow = checked
                LuckyGrabbag.RotationGlow:ApplySetting()
            end,
        })
    end

    ---------------------------------------------------------------------------
    -- Delves
    ---------------------------------------------------------------------------
    do
        local g = panel:Group("Delves")

        g:Toggle({
            label    = "Trovehunter's Bounty Map",
            desc     = "Floating button to use your Trovehunter's Bounty Map when you're inside a delve that meets the minimum level. Right-click and drag to reposition.",
            checked  = db.showDelveMap,
            image    = "delves/trovehunters-bounty-map",
            onToggle = function(checked)
                db.showDelveMap = checked
                LuckyGrabbag.DelveMap:ApplySetting()
            end,
        })

        g:Slider({
            label    = "Minimum Delve Level",
            key      = "DelveMapMinLevel",
            desc     = "Only show the Bounty Map button in delves at or above this tier.",
            min      = 1,
            max      = 11,
            value    = db.delveMapMinLevel,
            parent   = "Trovehunter's Bounty Map",
            onChanged = function(val)
                db.delveMapMinLevel = val
                LuckyGrabbag.DelveMap:ApplySetting()
            end,
        })
    end
end
