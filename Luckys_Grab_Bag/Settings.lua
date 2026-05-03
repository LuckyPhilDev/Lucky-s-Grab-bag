-- Lucky's Grab-bag: Settings panel
LuckyGrabbag = LuckyGrabbag or {}
LuckyGrabbag.Settings = {}

function LuckyGrabbag.Settings:Init(db)
    local panel = LuckySettings:NewRichPanel("Lucky's Grab-bag", {
        addonFolder    = "Luckys_Grab_Bag",
        imagesRoot     = "images",
        recentVersions = { "1.5.0", "1.4.0" },
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
            desc     = "Shows the Grab-bag button on the minimap. Shift-drag to move.",
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

        g:Section("Automation")

        g:Toggle({
            label    = "Auto Repair",
            desc     = "Automatically repair all damaged gear when you open a vendor that can repair.",
            checked  = db.autoRepair,
            image    = "vendors/auto-repair",
            onToggle = function(checked) db.autoRepair = checked end,
        })

        g:Toggle({
            label    = "Use Guild Funds",
            desc     = "Pays from the guild bank when allowed, otherwise your own gold.",
            checked  = db.autoRepairUseGuildFunds,
            parent   = "Auto Repair",
            onToggle = function(checked) db.autoRepairUseGuildFunds = checked end,
        })

        g:Section("Purchasing")

        g:Toggle({
            label    = "Confirm Purchase",
            desc     = "Shows a large tick button on vendor currency-confirmation popups. Right-click drag to move.",
            checked  = db.showConfirmPurchase,
            image    = "vendors/confirm-purchase",
            onToggle = function(checked)
                db.showConfirmPurchase = checked
                LuckyGrabbag.ConfirmPurchase:ApplySetting()
            end,
        })

        g:Toggle({
            label    = "Overlay on Clicked Item",
            desc     = "Pins the tick button on top of the clicked item. When off, it floats next to the vendor and is draggable.",
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
            desc     = "Adds a button next to the Auction House. Each click buys one row from your CraftSim shopping list.",
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
            desc     = "Withdraws unused Thalassian Treatises for your professions when you open the warband bank.",
            checked  = db.showTreatise,
            image    = "crafting/treatise",
            onToggle = function(checked) db.showTreatise = checked end,
        })

        g:Toggle({
            label    = "Cooking Utility Buttons",
            desc     = "Adds Campfire and Chef's Hat buttons next to the Cooking window.",
            checked  = db.showCookingButtons,
            image    = "crafting/cooking-buttons",
            onToggle = function(checked) db.showCookingButtons = checked end,
        })

        g:Toggle({
            label    = "Reagent Mains",
            desc     = "Deposits reagents into the warband bank that belong to a different character.",
            checked  = db.reagentMainsEnabled,
            image    = "crafting/reagent-mains",
            since    = "1.5.0",
            onToggle = function(checked) db.reagentMainsEnabled = checked end,
        })

        g:Button({
            label    = "Configure mains…",
            desc     = "Assign reagent categories to characters.",
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
            desc      = "Floating buttons for Payouts, Glimmers/Flickers, and Treatises in your bags. Draggable; hides when empty.",
            checked   = db.showUseItems,
            image     = "inventory/use-items-popup",
            imageSize = { 400, 119 },
            onToggle  = function(checked)
                db.showUseItems = checked
                LuckyGrabbag.UseItems:ApplySetting()
            end,
        })

        g:Toggle({
            label     = "Only while rested",
            desc      = "Hides the popup outside rest areas.",
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
            desc     = "Pull timer and ready check buttons in raids and Mythic+. Shows out of combat. Right-click drag to move.",
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
            desc     = "Pull countdown length in Mythic+.",
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
            desc     = "Pull countdown length in raids.",
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
            desc     = "Default break length.",
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
            desc     = "Animates the next-cast spell on the Essential Cooldown Viewer. Enable the viewer in Edit Mode.",
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

    panel:Finalize()
end
